--!nonstrict
-- CharacterWindow — «Книга героя» на арте Humble Gift «Paper UI System».
-- Четыре вкладки-закладки на одном столе:
--   Снаряжение [I/Tab] — сумка по категориям, кукла с 6 слотами + быстрый
--                        предмет, карточка выбранного предмета с действиями;
--   Герой [C]          — класс, уровень, характеристики, летопись, классы;
--   Журнал [J]         — сюжетные задания, выполненные, фрагменты архива;
--   Древо [T]          — древо талантов своего класса (Windows/TalentPage, приложение В);
--                        лента: «ДРЕВО ВОИНА» / «ДРЕВО МАГА».
-- Данные: StationApi.character.get() (InventoryService.characterState),
-- древо — StationApi.talents (TalentService).
-- Открывает StationController (станция Inventory, ctx.tab = "gear"|"hero"|"journal"|"talents").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiAssets = require(Shared.Config.UiAssets)
local Items = require(Shared.Config.Items)
local Armor = require(Shared.Config.Armor)
local Binds = require(Shared.Config.Binds)
local UiNet = require(Shared.Net.UiNet)

local Lib = script.Parent.Parent.Lib
local Bus = require(Lib.Bus)
local PixelUi = require(Lib.PixelUi)
local PaperUi = require(Lib.PaperUi)
local ChestVisual = require(Lib.ChestVisual)
local ItemView = require(Lib.ItemView)
local UiFx = require(Lib.UiFx)
local UiSound = require(Lib.UiSound)
local UiMotion = require(Lib.UiMotion)
local WindowBase = require(Lib.WindowBase)
local TalentPage = require(script.Parent.TalentPage)

local CharacterWindow = {}

-- Вкладки сумки окна: как Items.Categories, плюс «Сундуки» второй вкладкой
-- (сундуки этажей лежат в сумке и открываются в долине — ChestRevealController).
local BAG_CATEGORIES = {}
for i, cat in ipairs(Items.Categories) do
	table.insert(BAG_CATEGORIES, cat)
	if i == 1 then
		table.insert(BAG_CATEGORIES, { id = "chests", name = "Сундуки", chestIcon = "f1_gold" })
	end
end

local P = PaperUi.colors
local player = Players.LocalPlayer
local win, ctx
local refs: any = {}
local state: any = {
	tab = "gear",
	category = "all",
	selectedKey = nil,
	confirmKey = nil,
	data = nil,
	list = {},
	yaw = 0,
	journalTab = "story",
	journalKey = nil,
	quests = nil,
}

local TABS = {
	{ id = "gear", name = "Снаряжение", action = "Inventory", title = "СНАРЯЖЕНИЕ" },
	{ id = "hero", name = "Герой", action = "Hero", title = "КНИГА ГЕРОЯ" },
	{ id = "journal", name = "Журнал", action = "Journal", title = "ЖУРНАЛ" },
	{ id = "talents", name = "Древо", action = "Talents", title = "ДРЕВО ТАЛАНТОВ" },
}

-- Заголовок ленты: у «Древа» — древо своего класса («ДРЕВО ВОИНА», «ДРЕВО МАГА»).
local function tabTitle(spec): string
	if spec.id == "talents" then
		return TalentPage.title()
	end
	return spec.title
end

-- Слоты куклы: id, подпись, x, y (дизайн-пиксели), категория пустого слота, силуэт.
-- Клетки 100 × 100 (было 84), шаг 128 — под 3D-витрины; framing — рамка манекена брони.
local DOLL_SIZE = 100
local DOLL = {
	{ id = "helm", name = "Шлем", x = 612, y = 160, category = "armor", empty = "eqEmpty_helm", framing = "head" },
	{ id = "armor", name = "Доспех", x = 612, y = 288, category = "armor", empty = "eqEmpty_chest", framing = "torso" },
	{ id = "amulet", name = "Амулет", x = 612, y = 416, category = "accessories", empty = "it_amuletSilver" },
	{ id = "sword", name = "Оружие", x = 888, y = 160, category = "weapons", empty = "it_sword" },
	{ id = "ring", name = "Кольцо", x = 888, y = 288, category = "accessories", empty = "it_ringSilver" },
	{ id = "soul", name = "Душа", x = 888, y = 416, category = "souls", empty = "it_soul" },
}

local REASONS = {
	full = "Здоровье и так полное",
	cooldown = "Ещё рано — идёт откат",
	["charges-full"] = "Заряды лечения полны",
	empty = "Предмет закончился",
	dead = "Герой без сознания",
	equipped = "Сначала снимите предмет",
	["no-quick"] = "Быстрый слот пуст",
	["bad-request"] = "Слишком быстро",
}

local PORTRAITS = { ["Ольгерд"] = "npc1", ["Феофан"] = "npc2", ["Дед Ефим"] = "npc3" }

local function keyName(action: string): string
	local binding = Binds.get(action)
	if typeof(binding) == "EnumItem" and binding.EnumType == Enum.KeyCode then
		return binding.Name
	end
	return ""
end

local function clear(frame)
	if not frame then
		return
	end
	for _, c in ipairs(frame:GetChildren()) do
		if not c:IsA("UIBase") then
			c:Destroy()
		end
	end
end

local function layer(parent, name: string, z: number?)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = z or 5
	frame.Parent = parent
	return frame
end

local function centered(parent, text, size, color, y, props, font)
	local label = (font or PaperUi.text)(parent, text, size, color, {
		Position = UDim2.fromOffset(16, y),
		Size = UDim2.new(1, -32, 0, size + 10),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	return PaperUi.apply(label, props)
end

-- Подсказка в точке холста (ошибки, «+1 зелье»).
local function toast(text: string, color: Color3?)
	if not win or not refs.fx then
		return
	end
	UiFx.floatText(refs.fx, text, Vector2.new(1280, 560), color or P.green, 24)
end

-- ===== модель предметов =====

-- Комплект брони — один предмет; в клетке шлема куклы рисуется шлем, в остальных — доспех.
local function armorIcon(item, slotId: string?)
	local material = (item.rarityId == "common" or item.rarityId == nil) and "eqLeather_" or "eqIron_"
	return material .. (slotId == "helm" and "helm" or "chest")
end

local function weaponEntry(w)
	return {
		key = "W" .. tostring(w.key or w.index or "eq"),
		kind = "weapon",
		category = "weapons",
		name = w.name or "Оружие",
		typeName = w.typeName,
		rarityId = w.rarityId or "common",
		pixelIcon = (w.typeId and UiAssets.WeaponIcon[w.typeId]) or "sword",
		level = w.level or 1,
		maxLevel = w.maxLevel or 1,
		equipped = w.equipped == true,
		isNew = w.isNew,
		raw = w,
	}
end

local function buildList(data)
	local list = {}
	if not data then
		return list
	end
	local gear = data.gear or {}
	local chests = data.chests
	for _, stack in ipairs(chests and chests.stacks or {}) do
		table.insert(list, {
			key = "K" .. tostring(stack.key),
			kind = "chest",
			category = "chests",
			name = stack.name or "Сундук",
			rarityId = stack.grade == "gold" and "legendary" or "common",
			chestDesign = stack.key,
			count = stack.count or 1,
			raw = stack,
		})
	end
	for _, w in ipairs(gear.items or {}) do
		table.insert(list, weaponEntry(w))
	end
	for _, a in ipairs(gear.armorItems or {}) do
		table.insert(list, {
			key = "A" .. tostring(a.key),
			kind = "armor",
			category = "armor",
			name = a.name or "Броня",
			rarityId = a.rarityId or "common",
			icon = armorIcon(a),
			level = a.level or 1,
			maxLevel = a.maxLevel or 1,
			equipped = a.equipped == true,
			raw = a,
		})
	end
	for _, c in ipairs(data.accessories or {}) do
		table.insert(list, {
			key = "C" .. tostring(c.uid),
			kind = "accessory",
			category = "accessories",
			name = c.name,
			rarityId = c.rarityId or "common",
			icon = c.icon,
			equipped = c.equipped == true,
			raw = c,
		})
	end
	local hasMaterials = false
	for _, b in ipairs(data.bag or {}) do
		hasMaterials = hasMaterials or b.kind == "material"
		table.insert(list, {
			key = "B" .. tostring(b.key or b.id),
			kind = b.kind == "material" and "material" or "bag",
			category = b.category or "materials",
			name = b.name or b.id,
			rarityId = b.rarityId or "common",
			icon = b.icon or "it_star",
			count = b.count or 1,
			equipped = b.quick == true,
			raw = b,
		})
	end
	-- Старый сервер без InventoryService: материалы из gearState.
	if not hasMaterials then
		for _, m in ipairs(gear.materials or {}) do
			table.insert(list, {
				key = "M" .. tostring(m.id),
				kind = "material",
				category = "materials",
				name = m.name or m.id,
				rarityId = "common",
				icon = m.id == "rusty_iron" and "it_ingot" or "it_dust",
				count = m.count or 1,
				raw = { id = m.id, desc = "Материал. Пригодится в долине." },
			})
		end
	end
	for _, s in ipairs(gear.souls or {}) do
		table.insert(list, {
			key = "S" .. tostring(s.id),
			kind = "soul",
			category = "souls",
			name = s.name or "Душа",
			rarityId = s.rarityId or "epic",
			icon = "it_soul",
			count = s.count or 1,
			raw = s,
		})
	end
	return list
end

local function filtered()
	local out = {}
	for _, item in ipairs(state.list) do
		if state.category == "all" or item.category == state.category then
			table.insert(out, item)
		end
	end
	return out
end

local function findItem(key)
	for _, item in ipairs(state.list) do
		if item.key == key then
			return item
		end
	end
	return nil
end

local function selectedItem()
	local items = filtered()
	for _, item in ipairs(items) do
		if item.key == state.selectedKey then
			return item
		end
	end
	state.selectedKey = items[1] and items[1].key or nil
	return items[1]
end

local function categoryCount(id: string): number
	local n = 0
	for _, item in ipairs(state.list) do
		if id == "all" or item.category == id then
			n += 1
		end
	end
	return n
end

local function power(): number
	return state.data and state.data.gear and state.data.gear.power or 0
end

-- ===== витрина персонажа =====

local function cloneAvatar(world)
	if refs.avatar then
		refs.avatar:Destroy()
		refs.avatar = nil
	end
	local character = player.Character
	local model
	if character then
		local archivable = character.Archivable
		character.Archivable = true
		model = character:Clone()
		character.Archivable = archivable
	end
	if not model then
		return
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local _, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(0, 2.2 + size.Y / 2, 0) * CFrame.Angles(0, math.rad(180 + 15), 0))
	model.Parent = world
	refs.avatar = model
	refs.avatarBase = model:GetPivot()
end

local function buildViewport(parent)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Showcase"
	vp.BackgroundTransparency = 1
	vp.Active = true
	vp.Position = UDim2.fromOffset(630, 140)
	vp.Size = UDim2.fromOffset(340, 520)
	vp.ZIndex = 4
	vp.Ambient = Color3.fromRGB(120, 110, 100)
	vp.LightColor = Color3.fromRGB(255, 236, 210)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
	vp.Parent = parent
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local template = ReplicatedStorage:FindFirstChild("UiStages") and ReplicatedStorage.UiStages:FindFirstChild("InventoryStage")
	if template then
		local stage = template:Clone()
		stage:PivotTo(CFrame.new())
		stage.Parent = world
	else
		-- простой каменный постамент (цвета — как у бумажного стола)
		for _, spec in ipairs({ { 11.2, 1.2, Color3.fromRGB(120, 92, 70) }, { 9.4, 2.2, Color3.fromRGB(160, 128, 96) } }) do
			local p = Instance.new("Part")
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(spec[2], spec[1], spec[1])
			p.CFrame = CFrame.new(0, spec[2] / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
			p.Color = spec[3]
			p.Anchored = true
			p.Parent = world
		end
	end
	refs.world = world
	cloneAvatar(world)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	-- Кадр по фактическим габаритам манекена: броня и рост целиком в кадре
	-- при любой экипировке (раньше камера смотрела в грудь и резала ноги).
	local avatar = world:FindFirstChildOfClass("Model")
	local ok, bboxCF, bboxSize = pcall(function()
		return avatar:GetBoundingBox()
	end)
	if ok and bboxCF and bboxSize.Y > 0.5 then
		local center = bboxCF.Position
		local half = math.max(bboxSize.Y, bboxSize.X * 1.4) / 2
		local dist = half / math.tan(math.rad(camera.FieldOfView / 2)) * 1.14
		camera.CFrame = CFrame.lookAt(center + Vector3.new(0, bboxSize.Y * 0.04, -dist), center)
	else
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 6.4, -16), Vector3.new(0, 4.2, 0))
	end
	camera.Parent = vp
	vp.CurrentCamera = camera
	local dragging, lastX = false, 0
	local conns = {}
	table.insert(conns, vp.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, lastX = true, input.Position.X
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			state.yaw += (input.Position.X - lastX) * 0.01
			lastX = input.Position.X
		end
	end))
	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		if not dragging then
			state.yaw += dt * 0.15
		end
		if refs.avatar and refs.avatar.Parent then
			refs.avatar:PivotTo(refs.avatarBase * CFrame.Angles(0, state.yaw, 0))
		end
	end))
	win:onCleanup(function()
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
	end)
	return vp
end

-- Облик пересобирает сервер: ждём новый ArmorLook и обновляем витрину.
local function recloneAfterArmor()
	local character = player.Character
	if not character or not refs.world then
		return
	end
	local lookBefore = character:GetAttribute("ArmorLook")
	task.spawn(function()
		local waited = 0
		while waited < 2 and character:GetAttribute("ArmorLook") == lookBefore do
			waited += task.wait(0.05)
		end
		task.wait(0.1)
		if win and refs.world and refs.world.Parent then
			cloneAvatar(refs.world)
		end
	end)
end

-- ===== снаряжение: рендер =====
local renderGear
local renderBag
local renderDoll
local renderDetail

local function reload(keepKey: boolean?)
	local before = power()
	local data = ctx and ctx.api.character.get()
	if not data then
		warn("[CharacterWindow] сервер не вернул данные персонажа")
		return false
	end
	state.data = data
	state.list = buildList(data)
	if not keepKey then
		state.selectedKey = nil
	end
	state.confirmKey = nil
	if win then
		renderGear()
		local after = power()
		if refs.power and after ~= before then
			UiFx.countUp(refs.power, before, after, 0.7, "СИЛА %d")
		end
	end
	return true
end

local function selectItem(key, category)
	if category and state.category ~= "all" and state.category ~= category then
		state.category = category
	end
	state.selectedKey = key
	state.confirmKey = nil
	renderBag()
	renderDetail()
end

-- ===== витрины предметов (3D) =====

-- Сетка сумки: 4 витрины в ряд (было 6 значков по 78).
local GRID = { cols = 4, cell = 120, step = 128, left = 6 }
local LIGHT_INK = Color3.fromRGB(255, 240, 210)
local LIGHT_GOLD = Color3.fromRGB(255, 214, 110)
local DARK_STROKE = Color3.fromRGB(30, 20, 14)

-- Что стоит в витрине: оружие и броня — модели, сундук — его арт, остальное — значок.
-- opts: z, spin, drag, framing (броня), iconSize, big (крупная карточка).
local function caseContent(window, item, opts)
	opts = opts or {}
	local z = opts.z or 10
	local raw = item.raw or {}
	if item.kind == "weapon" then
		return ItemView.weapon(window, { id = raw.id, typeId = raw.typeId }, { ZIndex = z }, {
			spin = opts.spin, drag = opts.drag, spinSpeed = 0.6,
		})
	elseif item.kind == "armor" and raw.setId then
		-- пока сервер собирает манекен комплекта — бумажный значок брони
		local placeholder = item.icon and PaperUi.itemIcon(window, item.icon, UDim2.fromScale(0.5, 0.5), opts.iconSize or 64,
			{ ZIndex = z, ImageTransparency = 0.35 })
		return ItemView.armor(window, raw.setId, { ZIndex = z }, {
			framing = opts.framing or "full", spin = opts.spin, drag = opts.drag,
			onReady = function()
				if placeholder then
					placeholder:Destroy()
				end
			end,
		})
	elseif item.chestDesign then
		return ChestVisual.image(window, item.chestDesign, opts.big and "art" or "icon", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(opts.big and 0.92 or 0.78, opts.big and 0.8 or 0.78),
			ZIndex = z,
		}, opts.spin and { spin = true } or nil)
	end
	local size = opts.iconSize or 64
	if item.icon then
		return PaperUi.itemIcon(window, item.icon, UDim2.fromScale(0.5, 0.5), size, { ZIndex = z })
	elseif item.pixelIcon then
		return PixelUi.icon(window, item.pixelIcon, UDim2.new(0.5, -size / 2, 0.5, -size / 2), size, { ZIndex = z })
	end
	return nil
end

-- Светлая подпись поверх бархата витрины (читается и на светлой, и на тёмной редкости).
local function caseLabel(parent, text: string, size: number, color: Color3, props)
	local label = PaperUi.bold(parent, text, size, color, props)
	label.TextStrokeColor3 = DARK_STROKE
	label.TextStrokeTransparency = 0.15
	return label
end

-- Подсказка с именем над витриной (сетка без подписей — имя видно при наведении).
local function showTip(anchor, item)
	if not win or not refs.fx or not anchor.Parent then
		return
	end
	if refs.tip then
		refs.tip:Destroy()
		refs.tip = nil
	end
	local canvas = win.canvas
	local k = canvas.AbsoluteSize.X / 1600
	if k <= 0 then
		return
	end
	local rel = (anchor.AbsolutePosition - canvas.AbsolutePosition) / k
	local size = anchor.AbsoluteSize / k
	local kind = item.raw and item.raw.typeName or (item.kind == "armor" and (item.raw and item.raw.slotName or "Броня")) or nil
	local width = math.clamp((utf8.len(item.name or "") or 10) * 11 + 40, 180, 360)
	local tip = PaperUi.image(refs.fx, "plate", {
		Name = "Tip",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(rel.X + size.X / 2, rel.Y - 6),
		Size = UDim2.fromOffset(width, kind and 62 or 40),
		ZIndex = 41,
	}, { scale = 2 })
	PaperUi.bold(tip, item.name or "Предмет", 20, PaperUi.rarityInk[item.rarityId] or P.ink, {
		Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 42,
	})
	if kind then
		PaperUi.italic(tip, ("%s · %s"):format(UiAssets.RarityName[item.rarityId] or "Обычное", kind), 16, P.ink2, {
			Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 42,
		})
	end
	refs.tip = tip
end

local function hideTip(anchor)
	if refs.tip and (not anchor or refs.tipAnchor == anchor) then
		refs.tip:Destroy()
		refs.tip = nil
	end
end

-- Клетка сумки / куклы: витрина + модель + ★, ×N, галочка «надето», «новое».
local function itemCell(parent, pos: UDim2, size: number, item, selected: boolean, onClick, opts)
	opts = opts or {}
	local case = ItemView.case(parent, pos, Vector2.new(size, size), item.rarityId, { z = opts.z or 9, glow = 0.5 })
	local z = case.z
	caseContent(case.window, item, {
		z = z, spin = selected, framing = opts.framing or "full", iconSize = size >= 110 and 64 or 48,
	})
	case.setSelected(selected)
	local small = size < 110
	if item.level and item.level > 1 then
		caseLabel(case.holder, "★" .. item.level, small and 16 or 19, LIGHT_GOLD, {
			Position = UDim2.fromOffset(small and 8 or 11, small and 5 or 8), Size = UDim2.fromOffset(60, 22), ZIndex = z + 3,
		})
	end
	if item.count and item.count > 1 then
		caseLabel(case.holder, "×" .. item.count, small and 17 or 20, LIGHT_INK, {
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(80, 24),
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = z + 3,
		})
	end
	if item.equipped then
		PaperUi.image(case.holder, "icCheck", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 2, 0, -2),
			Size = UDim2.fromOffset(small and 24 or 32, small and 24 or 32), ZIndex = z + 4,
		}, { noSlice = true })
	end
	if item.isNew then
		PaperUi.image(case.holder, "dot", {
			Position = UDim2.fromOffset(-2, -2), Size = UDim2.fromOffset(14, 14),
			ImageColor3 = Color3.fromRGB(220, 70, 60), ZIndex = z + 4,
		}, { noSlice = true })
	end
	if selected then
		PaperUi.brackets(case.holder, size, z + 5)
	end
	local hit = PaperUi.hit(case.holder, z + 8)
	hit.MouseEnter:Connect(function()
		UiSound.play("ui_hover")
		case.setHover(true)
		refs.tipAnchor = case.holder
		showTip(case.holder, item)
	end)
	hit.MouseLeave:Connect(function()
		if not selected then
			case.setHover(false)
		end
		hideTip(case.holder)
	end)
	hit.Activated:Connect(function()
		UiSound.play("ui_click")
		hideTip()
		onClick()
	end)
	return case
end

function renderBag()
	local body = refs.bagBody
	hideTip()
	clear(body)
	if not body then
		return
	end
	PaperUi.bold(body, "СУМКА", 30, P.green, {
		Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 36), TextXAlignment = Enum.TextXAlignment.Center,
	})
	local step = math.min(64, math.floor(524 / #BAG_CATEGORIES))
	local catSize = step - 4
	for i, cat in ipairs(BAG_CATEGORIES) do
		local active = state.category == cat.id
		local slot = PaperUi.slot(body, UDim2.fromOffset(18 + (i - 1) * step, 54), catSize, {
			icon = cat.icon,
			custom = cat.chestIcon and function(holder, _, z)
				return ChestVisual.image(holder, cat.chestIcon, "icon", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.48),
					Size = UDim2.fromOffset(32, 32),
					ZIndex = z,
				})
			end or nil,
			iconSize = 32,
			selected = active,
			dim = not active and categoryCount(cat.id) == 0,
			z = 8,
			onClick = function()
				state.category = cat.id
				state.selectedKey = nil
				state.confirmKey = nil
				state.gridScroll = nil
				renderBag()
				renderDetail()
			end,
		})
		if active then
			slot.base.ImageColor3 = Color3.fromRGB(255, 244, 214)
		end
	end
	local catName = "Всё"
	for _, cat in ipairs(BAG_CATEGORIES) do
		if cat.id == state.category then
			catName = cat.name
		end
	end
	local items = filtered()
	PaperUi.bold(body, ("%s · %d"):format(catName, #items), 22, P.ink2, {
		Position = UDim2.fromOffset(24, 116), Size = UDim2.new(1, -48, 0, 28),
	})
	PaperUi.divider(body, UDim2.fromOffset(20, 146), 520, 7)

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(16, 164)
	grid.Size = UDim2.fromOffset(528, 568)
	grid.ScrollBarThickness = 8
	grid.ScrollBarImageColor3 = P.green
	grid.ZIndex = 8
	grid.Parent = body
	-- Витрины 4 × N: 3D-модель оружия и брони, как в сундуке (Lib/ItemView).
	local cells = math.max(GRID.cols * 4, math.ceil(#items / GRID.cols) * GRID.cols)
	grid.CanvasSize = UDim2.fromOffset(0, math.ceil(cells / GRID.cols) * GRID.step + 12)
	local current = selectedItem()
	for k = 1, cells do
		local item = items[k]
		local pos = UDim2.fromOffset(GRID.left + ((k - 1) % GRID.cols) * GRID.step, 6 + ((k - 1) // GRID.cols) * GRID.step)
		if item then
			itemCell(grid, pos, GRID.cell, item, current ~= nil and item.key == current.key, function()
				selectItem(item.key)
			end)
		else
			local empty = PaperUi.slot(grid, pos, GRID.cell, { z = 9 })
			empty.base.ImageTransparency = 0.55
		end
	end
	-- после перерисовки (выбор, «надеть») сетка остаётся там, где её прокрутили
	if state.gridScroll then
		grid.CanvasPosition = Vector2.new(0, state.gridScroll)
	end
	grid:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		state.gridScroll = grid.CanvasPosition.Y
	end)
end

-- Предмет, надетый в слот куклы.
local function dollItem(slotId: string)
	local data = state.data
	if not data then
		return nil
	end
	if slotId == "sword" then
		for _, item in ipairs(state.list) do
			if item.kind == "weapon" and item.equipped then
				return item
			end
		end
	elseif slotId == "helm" or slotId == "armor" then
		-- Обе клетки показывают надетый комплект (шлем и доспех идут вместе).
		for _, item in ipairs(state.list) do
			if item.kind == "armor" and item.equipped then
				if slotId == "helm" then
					local copy = table.clone(item)
					copy.icon = armorIcon(item.raw, "helm")
					return copy
				end
				return item
			end
		end
	elseif slotId == "amulet" or slotId == "ring" then
		for _, item in ipairs(state.list) do
			if item.kind == "accessory" and item.equipped and item.raw.slot == slotId then
				return item
			end
		end
	elseif slotId == "soul" then
		local eq = data.gear and data.gear.equipped
		local soul = eq and eq.soul
		if type(soul) == "table" then
			local id = tostring(soul.id or soul.name or "soul")
			return findItem("S" .. id) or { key = nil, kind = "soul", name = soul.name or "Душа", rarityId = soul.rarityId or "epic", icon = "it_soul" }
		end
	elseif slotId == "quick" then
		local quickId = data.quickItem
		if quickId then
			return findItem("Bb" .. quickId) or findItem("B" .. quickId)
		end
	end
	return nil
end

function renderDoll()
	local holder = refs.doll
	clear(holder)
	if not holder then
		return
	end
	local specs = table.clone(DOLL)
	table.insert(specs, { id = "quick", name = "Быстрый [" .. keyName("UseItem") .. "]", x = 612, y = 544, category = "consumables", empty = "it_potionRed" })
	for _, spec in ipairs(specs) do
		local item = dollItem(spec.id)
		local function open()
			if item and item.key then
				state.category = item.category or spec.category
				state.gridScroll = nil
				selectItem(item.key)
			else
				state.category = spec.category
				state.selectedKey = nil
				state.confirmKey = nil
				state.gridScroll = nil
				renderBag()
				renderDetail()
			end
		end
		if item then
			-- надетое — в витрине: оружие моделью, шлем и доспех — манекен комплекта крупно
			-- в кукле всё надето — галочка лишняя
			local shown = table.clone(item)
			shown.equipped = false
			shown.isNew = false
			itemCell(holder, UDim2.fromOffset(spec.x, spec.y), DOLL_SIZE, shown, false, open, { z = 8, framing = spec.framing })
		else
			local slot = PaperUi.slot(holder, UDim2.fromOffset(spec.x, spec.y), DOLL_SIZE, {
				empty = spec.empty,
				z = 8,
				onClick = open,
			})
			slot.base.ImageTransparency = 0.25
		end
		-- Маг: «Шляпа» и «Накидка» вместо «Шлем» и «Доспех».
		local slotLabel = (spec.id == "helm" or spec.id == "armor") and Armor.slotName(spec.id, player:GetAttribute("ClassName")) or spec.name
		PaperUi.bold(holder, slotLabel, 18, P.paper, {
			Position = UDim2.fromOffset(spec.x - 30, spec.y + DOLL_SIZE + 2),
			Size = UDim2.fromOffset(DOLL_SIZE + 60, 24),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeColor3 = P.woodDark,
			TextStrokeTransparency = 0.2,
			ZIndex = 9,
		})
	end

	local _, label = PaperUi.ribbon(holder, UDim2.fromOffset(638, 678), 324, ("СИЛА %d"):format(power()), { height = 60, textSize = 27, z = 8 })
	refs.power = label
	local delta = state.data and state.data.gear and state.data.gear.powerDelta
	PaperUi.italic(holder, delta and delta > 0 and ("+%d с лучшим оружием"):format(delta) or "", 19, P.paper, {
		Position = UDim2.fromOffset(600, 736), Size = UDim2.fromOffset(400, 26),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9,
		TextStrokeColor3 = P.woodDark, TextStrokeTransparency = 0.35,
	})

	local gear = state.data and state.data.gear or {}
	local eq = gear.equipped or {}
	local armorStats = gear.armorStats or {}
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local chips = {
		{ "Урон", tostring(eq.damage or (eq.now and eq.now.damage) or 0) },
		{ "Крит", ("%d%%"):format(eq.crit or (eq.now and eq.now.crit) or 0) },
		{ "Здоровье", tostring(math.floor(humanoid and humanoid.MaxHealth or 100)) },
		{ "Броня", tostring(armorStats.totalArmor or armorStats.armor or 0) },
	}
	for i, chip in ipairs(chips) do
		local x = 606 + (i - 1) * 98
		PaperUi.image(holder, "square", {
			Position = UDim2.fromOffset(x, 766), Size = UDim2.fromOffset(92, 80), ZIndex = 8,
		}, { scale = 1 })
		PaperUi.text(holder, chip[1], 17, P.ink2, {
			Position = UDim2.fromOffset(x, 772), Size = UDim2.fromOffset(92, 24),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9,
		})
		PaperUi.bold(holder, chip[2], 25, P.ink, {
			Position = UDim2.fromOffset(x, 800), Size = UDim2.fromOffset(92, 32),
			TextXAlignment = Enum.TextXAlignment.Center, TextScaled = false, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 9,
		})
	end
end

-- ===== карточка: действия =====

local function afterEquip(item)
	UiSound.play("forge_strike", { pitch = 1.4, volume = 0.6 })
	UiFx.flash(UiAssets.Rarity[item.rarityId] or P.gold, 0.3, 0.3)
	if item.kind == "armor" then
		Bus.emit("sfx", { name = "armorEquip" })
		recloneAfterArmor()
	end
	reload(true)
end

local function equipGear(item)
	local result = ctx.api.inventory.equip(item.raw)
	if result == nil or (type(result) == "table" and result.ok == false) then
		UiSound.play("error")
		toast("Не удалось надеть", P.red)
		return
	end
	afterEquip(item)
end

local function report(result, okText: string?)
	if result and result.ok then
		if okText then
			toast(okText, P.green)
		end
		return true
	end
	UiSound.play("error")
	toast(REASONS[result and result.reason or ""] or "Не получилось", P.red)
	return false
end

local function useItem(item)
	local result = ctx.api.character.use(item.raw.id)
	if report(result, result and result.text or nil) then
		UiSound.play("reward_pop")
		reload(true)
	end
end

local function toggleQuick(item)
	local result = ctx.api.character.setQuick(if item.raw.quick then nil else item.raw.id)
	if report(result, item.raw.quick and "Быстрый слот пуст" or ("В быстрый слот: " .. item.name)) then
		reload(true)
	end
end

local function toggleAccessory(item)
	local result
	if item.equipped then
		result = ctx.api.character.unequipAccessory(item.raw.slot)
	else
		result = ctx.api.character.equipAccessory(item.raw.uid)
	end
	if report(result) then
		afterEquip(item)
	end
end

local function salvage(item)
	if state.confirmKey ~= item.key then
		state.confirmKey = item.key
		renderDetail()
		return
	end
	state.confirmKey = nil
	local result = ctx.api.character.salvage(item.raw.uid)
	if report(result, ("+%d пыли эха"):format(result and result.dust or item.raw.salvage or 0)) then
		UiSound.play("echo_absorb")
		state.selectedKey = nil
		reload(false)
	end
end

-- ===== карточка: разметка =====

-- Строки характеристик: крупнее (21/23), при 6+ строках — плотнее, чтобы влезли кнопки.
local function statRows(body, rows, y: number)
	local step = #rows >= 6 and 33 or 37
	for i, r in ipairs(rows) do
		local ry = y + (i - 1) * step
		PaperUi.text(body, r[1], 21, P.ink2, { Position = UDim2.fromOffset(36, ry), Size = UDim2.fromOffset(230, 30) })
		PaperUi.bold(body, r[2], 23, r[3] or P.ink, {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -36, 0, ry),
			Size = UDim2.fromOffset(290, 30), TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end
	return y + #rows * step
end

local function note(body, text: string, y: number, color: Color3?, height: number?)
	if not text or text == "" then
		return y
	end
	PaperUi.italic(body, text, 19, color or P.ink2, {
		Position = UDim2.fromOffset(36, y), Size = UDim2.new(1, -72, 0, height or 52),
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
	})
	return y + (height or 52)
end

local function buttons(body, first, second)
	local made = {}
	for i, spec in ipairs({ first, second }) do
		if spec then
			made[i] = PaperUi.button(body, UDim2.fromOffset(28, i == 1 and 600 or 672), UDim2.fromOffset(504, 64), spec[1], spec[2], {
				disabled = spec.disabled,
				tone = spec.tone,
				textSize = 25,
				z = 9,
			})
		end
	end
	return made
end

local function compareText(item)
	local raw = item.raw
	if item.kind == "weapon" and not item.equipped then
		local eq = state.data.gear and state.data.gear.equipped
		local mine = raw.damage or (raw.now and raw.now.damage) or 0
		local theirs = eq and (eq.damage or (eq.now and eq.now.damage)) or 0
		local d = mine - theirs
		if d ~= 0 then
			return ("%s%d урона к надетому"):format(d > 0 and "+" or "−", math.abs(d)), d > 0 and P.greenLight or P.red
		end
		return "Урон как у надетого", P.ink2
	elseif item.kind == "accessory" and not item.equipped then
		local other = state.data.equippedAccessories and state.data.equippedAccessories[raw.slot]
		if other then
			return ("Заменит: %s (%s)"):format(other.name, other.statsText or ""), P.ink2
		end
		return "Слот «" .. (raw.slotName or "") .. "» свободен", P.greenLight
	end
	return nil
end

-- Шапка карточки: большая витрина с моделью (крутится сама и мышью), справа имя,
-- редкость и тип, звёзды. Ниже — характеристики с y = DETAIL_TOP.
local DETAIL_TOP = 252
local function detailHead(body, item, kindText: string)
	local case = ItemView.case(body, UDim2.fromOffset(24, 22), Vector2.new(212, 212), item.rarityId,
		{ z = 7, glow = 0.65, round = 10, plinth = item.kind == "armor" })
	caseContent(case.window, item, { z = case.z, spin = true, drag = true, framing = "full", iconSize = 128, big = true })
	PixelUi.pop(case.holder)
	local name = PaperUi.bold(body, item.name or "Предмет", 29, PaperUi.rarityInk[item.rarityId] or P.ink, {
		Position = UDim2.fromOffset(252, 26), Size = UDim2.fromOffset(284, 72),
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	PixelUi.pop(name)
	PaperUi.italic(body, ("%s · %s"):format(UiAssets.RarityName[item.rarityId] or "Обычное", kindText), 20, P.ink2, {
		Position = UDim2.fromOffset(252, 104), Size = UDim2.fromOffset(284, 52),
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
	})
	if item.level and item.maxLevel and item.maxLevel > 1 then
		PixelUi.stars(body, UDim2.fromOffset(252, 162), item.level, item.maxLevel, 22)
	end
	if item.equipped then
		PaperUi.bold(body, "НАДЕТО", 18, P.greenLight, {
			Position = UDim2.fromOffset(252, 196), Size = UDim2.fromOffset(200, 24),
		})
	end
	PaperUi.divider(body, UDim2.fromOffset(24, 236), 512, 7)
end

local function weaponDetail(body, item)
	local raw = item.raw
	detailHead(body, item, raw.typeName or "Оружие")
	local rows = {
		{ "Урон", tostring(raw.damage or (raw.now and raw.now.damage) or "—") },
		{ "Крит", ("%d%%"):format(raw.crit or (raw.now and raw.now.crit) or 0) },
		{ "Скорость", ("×%.1f"):format(raw.speed or 1) },
		{ "Эхо", ("%d/%d"):format(raw.echoes or 0, raw.cost and raw.cost.echoes or 0) },
	}
	if raw.ability then
		table.insert(rows, { "Способность", raw.ability, P.green })
	end
	if type(raw.soul) == "table" then
		table.insert(rows, { "Душа", tostring(raw.soul.name or "есть"), P.green })
	end
	local y = statRows(body, rows, DETAIL_TOP) + 8
	local text, color = compareText(item)
	if text then
		y = note(body, text, y, color, 30)
	end
	local ready = raw.cost and (raw.echoes or 0) >= raw.cost.echoes
	note(body, ready and ("Эха хватает — можно ковать ★" .. ((raw.level or 1) + 1)) or "Повторки оружия превращаются в эхо.", y, ready and P.greenLight or P.faint)
	local inHub = player:GetAttribute("Zone") ~= "Floor"
	buttons(body, {
		item.equipped and "УЖЕ НАДЕТО" or "НАДЕТЬ",
		function()
			equipGear(item)
		end,
		disabled = item.equipped,
	}, {
		inHub and "КУЗНЯ ЭХА" or "КУЗНЯ — В ДОЛИНЕ",
		function()
			ctx.close()
			task.delay(0.3, function()
				Bus.emit("openStation", { name = "Forge" })
			end)
		end,
		disabled = not inHub,
	})
end

local function armorDetail(body, item)
	local raw = item.raw
	detailHead(body, item, raw.slotName or "Броня")
	local nextHp = raw.nextHealth and (" → %d"):format(raw.nextHealth) or ""
	local nextRed = raw.nextReduction and (" → %s%%"):format(tostring(raw.nextReduction)) or ""
	local armorRows = {
		{ "Броня", ("+%d"):format(raw.armor or 0) },
		{ "Здоровье", ("+%d%s"):format(raw.health or 0, nextHp) },
		{ "Снижение урона", ("%s%%%s"):format(tostring(raw.reduction or 0), nextRed) },
		{ "Эхо", ("%d/%d"):format(raw.echoes or 0, raw.cost and raw.cost.echoes or 0) },
	}
	-- Шляпа и накидка мага: мана (растёт с ★) и её восстановление.
	if raw.mana then
		local nextMana = raw.nextMana and (" → %d"):format(raw.nextMana) or ""
		local regen = raw.manaRegen and (" · %.1f/с"):format(raw.manaRegen) or ""
		table.insert(armorRows, 3, { "Мана", ("+%d%s%s"):format(raw.mana, nextMana, regen) })
	end
	local cost = raw.cost
	if cost and cost.materials then
		table.insert(armorRows, { cost.materialName or "Материал", ("%d/%d"):format(raw.materialHave or 0, cost.materials) })
	end
	local y = statRows(body, armorRows, DETAIL_TOP) + 8
	if raw.passive then
		y = note(body, ("Пассивка «%s»: %s"):format(raw.passive.name or "", raw.passive.description or ""), y,
			raw.equipped and P.greenLight or P.ink2, 76)
	end
	local ready = cost and (raw.echoes or 0) >= cost.echoes and (raw.materialHave or 0) >= (cost.materials or 0)
	note(body, ready and ("Кузнец поднимет до ★%d"):format((raw.level or 1) + 1)
		or (cost and ("★ поднимает кузнец: повторка комплекта (эхо) и %s с этажа %d."):format(cost.materialName or "материал", cost.floor or raw.floor or 1)
			or "Комплект на потолке редкости."), y, ready and P.greenLight or P.faint)
	-- Ковать можно только в долине, у кузнеца (окно Кузни).
	local inHub = player:GetAttribute("Zone") ~= "Floor"
	buttons(body, {
		item.equipped and "УЖЕ НАДЕТО" or "НАДЕТЬ",
		function()
			equipGear(item)
		end,
		disabled = item.equipped,
	}, {
		not inHub and "КУЗНЕЦ — В ДОЛИНЕ" or "К КУЗНЕЦУ",
		function()
			ctx.close()
			task.delay(0.2, function()
				Bus.emit("openStation", { name = "Forge" })
			end)
		end,
		disabled = not inHub,
	})
end

local function accessoryDetail(body, item)
	local raw = item.raw
	detailHead(body, item, raw.slotName or "Аксессуар")
	local rows = {}
	local stats = raw.stats or {}
	if stats.health then
		table.insert(rows, { "Здоровье", ("+%d"):format(stats.health) })
	end
	if stats.armor then
		table.insert(rows, { "Броня", ("+%d"):format(stats.armor) })
	end
	if stats.damage then
		table.insert(rows, { "Урон", ("+%d%%"):format(math.floor(stats.damage * 100 + 0.5)) })
	end
	local y = statRows(body, rows, DETAIL_TOP) + 8
	y = note(body, raw.desc or "", y, P.ink2, 56)
	local text, color = compareText(item)
	if text then
		note(body, text, y, color, 52)
	end
	local confirming = state.confirmKey == item.key
	buttons(body, {
		item.equipped and "СНЯТЬ" or "НАДЕТЬ",
		function()
			toggleAccessory(item)
		end,
	}, {
		confirming and ("ТОЧНО? +%d ПЫЛИ"):format(raw.salvage or 0) or ("РАЗОБРАТЬ (+%d пыли)"):format(raw.salvage or 0),
		function()
			salvage(item)
		end,
		tone = "red",
		disabled = item.equipped,
	})
end

local function bagDetail(body, item)
	local raw = item.raw
	local catName = "Предмет"
	for _, cat in ipairs(Items.Categories) do
		if cat.id == item.category then
			catName = cat.name
		end
	end
	detailHead(body, item, catName)
	local rows = { { "Количество", ("×%d"):format(item.count or 1) } }
	if raw.useText then
		table.insert(rows, { "Действие", raw.useText, P.green })
	end
	if raw.cooldown and raw.cooldown > 0 then
		table.insert(rows, { "Откат", ("%d с"):format(math.ceil(raw.cooldown)), P.red })
	end
	local y = statRows(body, rows, DETAIL_TOP) + 8
	y = note(body, raw.desc or "", y, P.ink2, 80)
	if item.kind == "material" then
		note(body, "Материалы тратятся в долине — в кузне и у мастеров.", y, P.faint)
		return
	end
	if raw.canQuick then
		note(body, raw.quick and ("В быстром слоте — клавиша " .. keyName("UseItem")) or "Можно положить в быстрый слот.", y, raw.quick and P.greenLight or P.faint)
	end
	local isRead = item.category == "valuables"
	buttons(body, raw.usable and {
		isRead and "ПРОЧИТАТЬ" or "ИСПОЛЬЗОВАТЬ",
		function()
			useItem(item)
		end,
	} or nil, raw.canQuick and {
		raw.quick and "УБРАТЬ ИЗ СЛОТА" or "В БЫСТРЫЙ СЛОТ",
		function()
			toggleQuick(item)
		end,
	} or nil)
end

local function soulDetail(body, item)
	detailHead(body, item, "Душа")
	local y = statRows(body, {
		{ "Количество", ("×%d"):format(item.count or 1) },
		{ "Осколки души", tostring(state.data.gear and state.data.gear.soulStacks or 0) },
	}, DETAIL_TOP) + 8
	note(body, "Души вставляются в оружие в Кузне эха. Повторки становятся осколками.", y, P.ink2, 80)
end

-- Сундук этажа: большой арт, откуда он, что внутри, ОТКРЫТЬ (в долине).
local function chestDetail(body, item)
	local raw = item.raw
	local gold = raw.grade == "gold"
	local designId = item.chestDesign or raw.key
	PaperUi.image(body, "ring224", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.fromOffset(240, 240), ImageTransparency = 0.35, ZIndex = 7,
	}, { noSlice = true })
	local art = ChestVisual.image(body, designId, "art", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 134),
		Size = UDim2.fromOffset(224, 192),
		ZIndex = 9,
	}, { spin = true })
	PixelUi.pop(art)
	PaperUi.bold(body, item.name or "Сундук", 28, gold and (PaperUi.rarityInk.legendary or P.gold) or P.ink, {
		Position = UDim2.fromOffset(24, 236), Size = UDim2.new(1, -48, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	PaperUi.italic(body, ("%s · этаж %d · %s"):format(gold and "Золотой сундук" or "Сундук этажа", raw.floor or 1, raw.floorName or ""), 18, P.ink2, {
		Position = UDim2.fromOffset(24, 272), Size = UDim2.new(1, -48, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	PaperUi.divider(body, UDim2.fromOffset(24, 304), 512, 7)

	local chest = Items.Chest
	local rolls = gold and chest.bossRolls or chest.rolls
	local armorText = Armor.canWear(player:GetAttribute("ClassName")) and "1 комплект, своя редкость" or "—"
	local accessoryChance = gold and chest.bossAccessoryChance or chest.accessoryChance
	local y = statRows(body, {
		{ "В сумке", ("×%d"):format(item.count or 1) },
		{ "Оружие", "под ваш класс", P.green },
		{ "Броня", armorText },
		{ "Припасы", ("%d–%d"):format(rolls[1], rolls[2]) },
		{ "Аксессуар", ("шанс %d%%"):format(math.floor((accessoryChance or 0) * 100 + 0.5)) },
	}, 316) + 4
	note(body, raw.text or "", y, P.ink2, 56)

	local inHub = player:GetAttribute("Zone") ~= "Floor"
	local key = raw.key
	buttons(body, {
		inHub and ((item.count or 1) > 1 and ("ОТКРЫТЬ · ×%d"):format(item.count) or "ОТКРЫТЬ") or "ОТКРЫТЬ — В ДОЛИНЕ",
		function()
			ctx.close()
			task.delay(0.3, function()
				Bus.emit("chestReveal", { key = key, fromBag = true })
			end)
		end,
		disabled = not inHub,
	})
end

local EMPTY_HINTS = {
	all = "Сумка пуста. Сундуки этажей наполнят её.",
	chests = "Сундуки этажей летят сюда сами: секретные комнаты, ответвления, мини-боссы — и золотой за босса. Открываются в долине.",
	weapons = "Оружие, которым вы владеете, появится здесь.",
	armor = "Комплект брони лежит в каждом сундуке этажа вместе с оружием.",
	accessories = "Амулеты и кольца изредка лежат в сундуках. У боссов — чаще.",
	consumables = "Зелья и еда — из сундуков. Положите лучшее в быстрый слот.",
	materials = "Материалы появятся после добычи.",
	souls = "Души появятся после победы над боссами.",
	valuables = "Записки и хроники рассказывают о прошлом долины.",
}

function renderDetail()
	local body = refs.detailBody
	clear(body)
	if not body then
		return
	end
	if not state.data then
		centered(body, "Не удалось загрузить снаряжение", 24, P.red, 80, nil, PaperUi.bold)
		centered(body, "Закройте книгу и откройте её снова.", 19, P.ink2, 124, nil, PaperUi.italic)
		return
	end
	local item = selectedItem()
	if not item then
		centered(body, "Пусто", 30, P.green, 80, nil, PaperUi.bold)
		local hint = EMPTY_HINTS[state.category] or ""
		if state.category == "armor" then
			local names = Armor.SlotNames[player:GetAttribute("ClassName") or "warrior"]
			hint = names and names.hint or hint
		end
		centered(body, hint, 22, P.ink2, 130, { TextWrapped = true, Size = UDim2.new(1, -80, 0, 110), Position = UDim2.fromOffset(40, 130) }, PaperUi.italic)
		return
	end
	if item.kind == "weapon" then
		weaponDetail(body, item)
	elseif item.kind == "armor" then
		armorDetail(body, item)
	elseif item.kind == "accessory" then
		accessoryDetail(body, item)
	elseif item.kind == "soul" then
		soulDetail(body, item)
	elseif item.kind == "chest" then
		chestDetail(body, item)
	else
		bagDetail(body, item)
	end
end

function renderGear()
	renderBag()
	renderDoll()
	renderDetail()
end

local function buildGearPage(page)
	local left = PaperUi.sheet(page, UDim2.fromOffset(40, 118), UDim2.fromOffset(560, 748), { kind = "sheet", z = 3 })
	refs.bagBody = layer(left, "Body", 6)
	PaperUi.drop(left, 0)
	-- круг-подложка за куклой
	PaperUi.image(page, "ring224", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(800, 400),
		Size = UDim2.fromOffset(336, 336), ImageTransparency = 0.15, ZIndex = 2,
	}, { noSlice = true })
	refs.viewport = buildViewport(page)
	refs.doll = layer(page, "Doll", 7)
	local right = PaperUi.sheet(page, UDim2.fromOffset(1000, 118), UDim2.fromOffset(560, 748), { kind = "sheetAlt", z = 3, tilt = 1.2 })
	refs.detailBody = layer(right, "Body", 6)
	PaperUi.drop(right, 0.06)
end

-- ===== вкладка «Герой» =====

local function renderHero(page)
	clear(page)
	local hero = state.data and state.data.hero
	local left = PaperUi.sheet(page, UDim2.fromOffset(40, 118), UDim2.fromOffset(470, 748), { kind = "sheet", z = 3 })
	local mid = PaperUi.sheet(page, UDim2.fromOffset(526, 118), UDim2.fromOffset(548, 748), { kind = "sheetAlt", z = 3, tilt = 0.8 })
	local right = PaperUi.sheet(page, UDim2.fromOffset(1090, 118), UDim2.fromOffset(470, 748), { kind = "sheet", z = 3, tilt = 1.4 })
	PaperUi.drop(left, 0)
	PaperUi.drop(mid, 0.05)
	PaperUi.drop(right, 0.1)
	if not hero then
		local body = layer(mid, "Body", 6)
		centered(body, "Книга героя недоступна", 26, P.red, 90, nil, PaperUi.bold)
		centered(body, "Сервер не прислал данные героя (нужен InventoryService).", 19, P.ink2, 136, { TextWrapped = true, Size = UDim2.new(1, -60, 0, 60), Position = UDim2.fromOffset(30, 136) }, PaperUi.italic)
		return
	end

	-- слева: класс, уровень, опыт, летопись
	local lb = layer(left, "Body", 6)
	PaperUi.image(lb, hero.classId == "warrior" and "hero1" or "hero2", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(235, 24), Size = UDim2.fromOffset(112, 112), ZIndex = 8,
	}, { noSlice = true })
	centered(lb, hero.className or "Герой", 32, P.green, 140, nil, PaperUi.bold)
	centered(lb, "Класс героя", 18, P.ink2, 178, nil, PaperUi.italic)
	PaperUi.image(lb, "ring80", { Position = UDim2.fromOffset(28, 218), Size = UDim2.fromOffset(80, 80), ZIndex = 7 }, { noSlice = true })
	PaperUi.bold(lb, tostring(hero.level or 1), 30, P.ink, {
		Position = UDim2.fromOffset(28, 218), Size = UDim2.fromOffset(80, 76), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9,
	})
	PaperUi.bold(lb, ("Уровень %d из %d"):format(hero.level or 1, hero.maxLevel or 1), 22, P.ink, {
		Position = UDim2.fromOffset(124, 222), Size = UDim2.fromOffset(320, 30),
	})
	local maxed = (hero.level or 1) >= (hero.maxLevel or 1)
	local ratio = maxed and 1 or ((hero.xpNext or 0) > 0 and (hero.xp or 0) / hero.xpNext or 0)
	local bar = PaperUi.bar(lb, UDim2.fromOffset(124, 260), UDim2.fromOffset(312, 32), 0, "xp", 8)
	bar:set(ratio, maxed and "МАКС." or ("%d / %d"):format(hero.xp or 0, hero.xpNext or 0), true)
	PaperUi.divider(lb, UDim2.fromOffset(24, 318), 422, 7)
	PaperUi.bold(lb, "ЛЕТОПИСЬ", 24, P.green, {
		Position = UDim2.fromOffset(0, 338), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center,
	})
	for i, entry in ipairs(hero.chronicle or {}) do
		local y = 382 + (i - 1) * 58
		PaperUi.strip(lb, UDim2.fromOffset(24, y), UDim2.fromOffset(422, 48), {
			kind = "stripPlain", text = entry.label, right = tostring(entry.value or 0), knobIcon = entry.icon, textSize = 18,
		})
	end

	-- середина: характеристики
	local mb = layer(mid, "Body", 6)
	PaperUi.bold(mb, "ХАРАКТЕРИСТИКИ", 26, P.green, {
		Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 32), TextXAlignment = Enum.TextXAlignment.Center,
	})
	PaperUi.divider(mb, UDim2.fromOffset(24, 60), 500, 7)
	for i, row in ipairs(hero.rows or {}) do
		local y = 76 + (i - 1) * 54
		PaperUi.bold(mb, row.label or "", 20, P.ink, { Position = UDim2.fromOffset(32, y), Size = UDim2.fromOffset(330, 26) })
		if row.hint and row.hint ~= "" then
			PaperUi.italic(mb, row.hint, 15, P.faint, { Position = UDim2.fromOffset(32, y + 24), Size = UDim2.fromOffset(360, 20), TextTruncate = Enum.TextTruncate.AtEnd })
		end
		PaperUi.bold(mb, tostring(row.value or "—"), 22, P.green, {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -32, 0, y + 6),
			Size = UDim2.fromOffset(150, 30), TextXAlignment = Enum.TextXAlignment.Right,
		})
		if i < #(hero.rows or {}) then
			local line = Instance.new("Frame")
			line.BorderSizePixel = 0
			line.BackgroundColor3 = P.line
			line.BackgroundTransparency = 0.6
			line.Position = UDim2.fromOffset(32, y + 50)
			line.Size = UDim2.new(1, -64, 0, 1)
			line.ZIndex = 7
			line.Parent = mb
		end
	end

	-- справа: классы
	local rb = layer(right, "Body", 6)
	PaperUi.bold(rb, "КЛАССЫ", 26, P.green, {
		Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 32), TextXAlignment = Enum.TextXAlignment.Center,
	})
	for i, class in ipairs(hero.classes or {}) do
		local y = 66 + (i - 1) * 222
		local card = PaperUi.sheet(rb, UDim2.fromOffset(20, y), UDim2.fromOffset(430, 206), { kind = "sheetPlain", back = false, z = 7, scale = 0.5 })
		local cb = layer(card, "Body", 9)
		local portrait = PaperUi.image(cb, i == 1 and "hero1" or "hero2", {
			Position = UDim2.fromOffset(14, 16), Size = UDim2.fromOffset(84, 84), ZIndex = 10,
		}, { noSlice = true })
		if not class.ready then
			portrait.ImageTransparency = 0.5
		end
		PaperUi.bold(cb, class.name or "Класс", 24, class.ready and P.ink or P.faint, {
			Position = UDim2.fromOffset(110, 14), Size = UDim2.fromOffset(300, 30),
		})
		PaperUi.italic(cb, class.blurb or "", 16, P.ink2, {
			Position = UDim2.fromOffset(110, 46), Size = UDim2.fromOffset(304, 62), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		})
		PaperUi.text(cb, ("Здоровье %s · Броня %s · Урон %s"):format(tostring(class.health or "—"), tostring(class.armor or "—"), tostring(class.weaponDamage or "—")), 16, P.ink, {
			Position = UDim2.fromOffset(16, 116), Size = UDim2.fromOffset(400, 22),
		})
		PaperUi.text(cb, ("Рывков %s · Мана %s · Скорость %s"):format(tostring(class.dodgeCharges or "—"), tostring(class.mana or 0), tostring(class.walkSpeed or "—")), 16, P.ink, {
			Position = UDim2.fromOffset(16, 142), Size = UDim2.fromOffset(400, 22),
		})
		if class.current then
			PaperUi.image(cb, "icCheck", { Position = UDim2.fromOffset(306, 160), Size = UDim2.fromOffset(32, 32), ZIndex = 11 }, { noSlice = true })
			PaperUi.bold(cb, "ВЫБРАН", 18, P.green, { Position = UDim2.fromOffset(344, 162), Size = UDim2.fromOffset(84, 28), ZIndex = 11 })
		elseif not class.ready then
			PaperUi.image(cb, "icLock", { Position = UDim2.fromOffset(330, 160), Size = UDim2.fromOffset(28, 28), ZIndex = 11 }, { noSlice = true })
			PaperUi.bold(cb, "СКОРО", 18, P.red, { Position = UDim2.fromOffset(362, 160), Size = UDim2.fromOffset(70, 28), ZIndex = 11 })
		else
			PaperUi.italic(cb, "Сменить — у алтаря в долине", 15, P.greenLight, { Position = UDim2.fromOffset(16, 172), Size = UDim2.fromOffset(400, 22) })
		end
	end
end

-- ===== вкладка «Журнал» =====
local renderJournal

local function loadQuests()
	local tab = state.journalTab
	local result = ctx.api.board.get(tab == "done" and "done" or tab)
	state.quests = result and result.quests or {}
end

-- Названия цепочек достижений для заголовков-разделителей.
local ACHV_CHAINS = {
	parries = "Парирования",
	damageDealt = "Урон врагам",
	enemiesKilled = "Победы над врагами",
}

local function journalEntries()
	local entries = {}
	for _, q in ipairs(state.quests or {}) do
		table.insert(entries, { key = "q" .. tostring(q.id), quest = q })
	end
	return entries
end

local function questDetail(body, q)
	PaperUi.italic(body, q.chapter or "Задание", 20, P.ink2, { Position = UDim2.fromOffset(40, 26), Size = UDim2.fromOffset(600, 26) })
	local title = PaperUi.bold(body, q.title or "", 36, P.green, { Position = UDim2.fromOffset(40, 54), Size = UDim2.fromOffset(620, 44), TextTruncate = Enum.TextTruncate.AtEnd })
	PixelUi.pop(title)
	PaperUi.divider(body, UDim2.fromOffset(32, 106), 840, 7)
	-- заказчик
	PaperUi.image(body, "ring112", { Position = UDim2.fromOffset(40, 128), Size = UDim2.fromOffset(112, 112), ZIndex = 7 }, { noSlice = true })
	PaperUi.image(body, PORTRAITS[q.giver or ""] or "npc4", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(96, 184), Size = UDim2.fromOffset(64, 64), ZIndex = 9,
	}, { noSlice = true })
	PaperUi.bold(body, q.giver or "", 18, P.ink, {
		Position = UDim2.fromOffset(16, 244), Size = UDim2.fromOffset(160, 24), TextXAlignment = Enum.TextXAlignment.Center,
	})
	PaperUi.italic(body, table.concat(q.quote or {}, " "), 21, P.ink2, {
		Position = UDim2.fromOffset(180, 132), Size = UDim2.fromOffset(680, 120), TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	-- прогресс
	PaperUi.bold(body, "ПРОГРЕСС", 18, P.faint, { Position = UDim2.fromOffset(40, 290), Size = UDim2.fromOffset(200, 24) })
	local goal = math.max(q.goal or 1, 1)
	local bar = PaperUi.bar(body, UDim2.fromOffset(40, 318), UDim2.fromOffset(824, 32), 0, "xp", 8)
	bar:set((q.progress or 0) / goal, ("%d / %d"):format(q.progress or 0, goal), true)
	local y = 370
	if q.steps and #q.steps > 0 then
		for i, step in ipairs(q.steps) do
			local column = (i - 1) % 2
			local row = (i - 1) // 2
			local sx, sy = 40 + column * 420, y + row * 40
			PaperUi.image(body, step.done and "icCheck" or "dotRing", {
				Position = UDim2.fromOffset(sx, sy + 4), Size = UDim2.fromOffset(24, 24), ZIndex = 8,
			}, { noSlice = true })
			PaperUi.text(body, step.text or "", 19, step.done and P.green or P.ink, {
				Position = UDim2.fromOffset(sx + 34, sy), Size = UDim2.fromOffset(370, 30),
			})
		end
		y += math.ceil(#q.steps / 2) * 40 + 14
	end
	-- награды
	PaperUi.bold(body, "НАГРАДА", 18, P.faint, { Position = UDim2.fromOffset(40, y), Size = UDim2.fromOffset(200, 24) })
	for i, reward in ipairs(q.rewards or {}) do
		local rx = 40 + (i - 1) * 200
		PaperUi.image(body, "square", { Position = UDim2.fromOffset(rx, y + 30), Size = UDim2.fromOffset(186, 60), ZIndex = 7 }, { scale = 1 })
		PixelUi.icon(body, reward.icon or "coin", UDim2.fromOffset(rx + 12, y + 42), 36, { ZIndex = 9 })
		PaperUi.bold(body, reward.text or "", 20, P.ink, { Position = UDim2.fromOffset(rx + 56, y + 46), Size = UDim2.fromOffset(124, 28), ZIndex = 9 })
	end
	if q.state == "done" then
		PaperUi.seal(body, UDim2.fromOffset(770, 600), 110, "ВЫПОЛНЕНО", P.green, 14)
	elseif q.state == "locked" then
		PaperUi.italic(body, "Глава ещё закрыта — выполните предыдущие задания Гильдии.", 20, P.faint, {
			Position = UDim2.fromOffset(40, 676), Size = UDim2.fromOffset(824, 30), TextXAlignment = Enum.TextXAlignment.Center,
		})
	elseif q.action == "take" then
		PaperUi.button(body, UDim2.fromOffset(204, 664), UDim2.fromOffset(496, 56), "ВЗЯТЬ ЗАДАНИЕ", function(button)
			local result = ctx.api.board.turnIn(q.id)
			if not result or not result.ok then
				UiSound.play("error")
				return
			end
			button:setDisabled(true)
			PaperUi.stamp(body, UDim2.fromOffset(770, 600), 110, "ВЗЯТО", P.green, 14)
			task.delay(0.9, function()
				if win and state.tab == "journal" then
					loadQuests()
					renderJournal()
				end
			end)
		end, { textSize = 22, z = 9 })
	elseif q.state == "ready" then
		PaperUi.italic(body, "Задание выполнено — вернитесь к заказчику.", 20, P.greenLight, {
			Position = UDim2.fromOffset(40, 676), Size = UDim2.fromOffset(824, 30), TextXAlignment = Enum.TextXAlignment.Center,
		})
	end
end

local function fragmentDetail(body, fragment)
	PaperUi.italic(body, "Архив памяти", 20, P.ink2, { Position = UDim2.fromOffset(40, 26), Size = UDim2.fromOffset(600, 26) })
	-- даже ненайденной странице пишем её название и источник: игрок видит,
	-- ЧТО ищет и ГДЕ оно водится, а не безымянный «неизвестный фрагмент»
	local title = fragment.owned and (fragment.title or "Фрагмент") or (fragment.title or "Фрагмент") .. " — страница не найдена"
	PaperUi.bold(body, title, 36, fragment.owned and P.green or P.faint, {
		Position = UDim2.fromOffset(40, 54), Size = UDim2.fromOffset(820, 44), TextTruncate = Enum.TextTruncate.AtEnd,
	})
	PaperUi.divider(body, UDim2.fromOffset(32, 106), 840, 7)
	PaperUi.image(body, fragment.owned and "book" or "bookMark", {
		Position = UDim2.fromOffset(40, 132), Size = UDim2.fromOffset(77, 96), ZIndex = 8,
	}, { noSlice = true })
	PaperUi.italic(body, fragment.owned and (fragment.text or "") or "Страница ещё не найдена. Фрагменты архива приносят боссы этажей за сюжетные задания.", 22,
		fragment.owned and P.ink or P.faint, {
			Position = UDim2.fromOffset(160, 132), Size = UDim2.fromOffset(700, 480), TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
	if not fragment.owned and fragment.source then
		PaperUi.bold(body, "ИСТОЧНИК", 18, P.faint, { Position = UDim2.fromOffset(40, 620), Size = UDim2.fromOffset(200, 24) })
		PaperUi.text(body, fragment.source, 21, P.ink, { Position = UDim2.fromOffset(40, 648), Size = UDim2.fromOffset(820, 30) })
	end
end

function renderJournal()
	local page = refs.pages and refs.pages.journal
	clear(page)
	if not page then
		return
	end
	if not state.quests then
		loadQuests()
	end
	local left = PaperUi.sheet(page, UDim2.fromOffset(40, 118), UDim2.fromOffset(600, 748), { kind = "sheet", z = 3 })
	local right = PaperUi.sheet(page, UDim2.fromOffset(656, 118), UDim2.fromOffset(904, 748), { kind = "sheetAlt", z = 3, tilt = 0.9 })
	local lb = layer(left, "Body", 6)
	local rb = layer(right, "Body", 6)

	for i, spec in ipairs({ { "story", "Сюжет" }, { "achv", "Достижения" }, { "tasks", "Поручения" }, { "done", "Выполнено" } }) do
		PaperUi.strip(lb, UDim2.fromOffset(20 + (i - 1) * 146, 24), UDim2.fromOffset(140, 48), {
			text = spec[2], active = state.journalTab == spec[1],
			knobIcon = spec[1] == "done" and "icCheckS" or (spec[1] == "story" and "icHomeS" or nil), textSize = 16,
			onClick = function()
				if state.journalTab ~= spec[1] then
					UiSound.play("page_turn", { volume = 0.7 })
					state.journalTab = spec[1]
					state.journalKey = nil
					loadQuests()
					renderJournal()
				end
			end,
		})
	end
	local entries = journalEntries()
	local archive = state.data and state.data.archive or { fragments = {}, owned = 0, total = 0 }
	local selected
	for _, e in ipairs(entries) do
		if e.key == state.journalKey then
			selected = e
		end
	end
	for _, f in ipairs(archive.fragments or {}) do
		if "f" .. f.id == state.journalKey then
			selected = { key = "f" .. f.id, fragment = f }
		end
	end
	if not selected and entries[1] then
		selected = entries[1]
		state.journalKey = selected.key
	end

	-- Список заданий в едином с доской стиле: тёмная панель, пергаментные
	-- строки, зелёные заголовки глав/цепочек, замки на закрытых.
	local C = UiAssets.Colors
	PixelUi.panel(lb, UDim2.fromOffset(8, 82), UDim2.fromOffset(584, 396))
	local list = Instance.new("ScrollingFrame")
	list.Name = "Quests"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(24, 98)
	list.Size = UDim2.fromOffset(552, 364)
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = C.green
	list.ZIndex = 8
	list.Parent = lb
	if #entries == 0 then
		centered(list, state.journalTab == "done" and "Выполненных заданий пока нет." or (state.journalTab == "achv" and "Достижений пока нет." or "Новых заданий нет. Загляните к жителям долины."), 19, C.grey, 140,
			{ TextWrapped = true, Size = UDim2.new(1, -40, 0, 60), Position = UDim2.fromOffset(20, 140) }, PaperUi.italic)
	end
	local y, lastSection = 0, nil
	for i, e in ipairs(entries) do
		local q = e.quest
		local section = nil
		if state.journalTab == "story" and q.chapter then
			section = q.chapter
		elseif state.journalTab == "achv" and q.stat then
			section = ACHV_CHAINS[q.stat] or q.chapter
		elseif state.journalTab == "tasks" and q.section then
			section = q.section
		end
		if section and section ~= lastSection then
			PixelUi.text(list, section, 16, C.green, {
				Position = UDim2.fromOffset(0, y + 4), Size = UDim2.fromOffset(540, 22), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9,
			})
			y += 30
			lastSection = section
		end
		local locked = q.state == "locked"
		local done = q.state == "done"
		local note = PixelUi.parch(list, UDim2.fromOffset(0, y), UDim2.fromOffset(540, 56))
		note.BackgroundTransparency = locked and 0.45 or 0
		note.ZIndex = 9
		PixelUi.text(note, q.title or "", 16, locked and C.grey or C.ink, { Position = UDim2.fromOffset(16, 5), Size = UDim2.fromOffset(300, 20), ZIndex = 11 })
		local ratio = (q.goal or 1) > 0 and math.min((q.progress or 0) / q.goal, 1) or 0
		local barColor = q.state == "ready" and C.gold or (done and C.grey) or C.green
		PixelUi.progress(note, UDim2.fromOffset(16, 30), UDim2.fromOffset(210, 14), ratio, barColor, {
			track = C.ink, trackTransparency = 0.72, trackStroke = C.ink2,
		})
		local progressText = q.state == "done" and "готово"
			or (locked and "закрыто")
			or (q.action == "take" and "НОВОЕ")
			or ("%d/%d"):format(q.progress or 0, q.goal or 1)
		PixelUi.text(note, progressText, 16, locked and C.grey or C.ink, { Position = UDim2.fromOffset(232, 26), Size = UDim2.fromOffset(110, 20), ZIndex = 11 })
		PixelUi.icon(note, q.rewardIcon or "coin", UDim2.fromOffset(392, 12), 32, { ZIndex = 11 })
		if q.action == "take" then
			local stamp = Instance.new("Frame")
			stamp.BackgroundTransparency = 1
			stamp.Position = UDim2.fromOffset(438, 10)
			stamp.Size = UDim2.fromOffset(90, 36)
			stamp.ZIndex = 10
			stamp.Parent = note
			local st = Instance.new("UIStroke")
			st.Color = Color3.fromRGB(190, 50, 40)
			st.Thickness = 3
			st.Parent = stamp
			PixelUi.text(stamp, "ВЗЯТЬ!", 16, Color3.fromRGB(190, 50, 40), { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11 })
		elseif q.category == "achv" then
			local trophy = PixelUi.icon(note, "trophy", UDim2.fromOffset(444, 8), 40, { ZIndex = 11 })
			trophy.ImageColor3 = done and Color3.fromRGB(255, 214, 120) or Color3.fromRGB(120, 112, 104)
		elseif locked then
			PixelUi.icon(note, "lock", UDim2.fromOffset(446, 10), 36, { ZIndex = 11 })
		elseif done then
			PixelUi.piece(note, "check", { Position = UDim2.fromOffset(446, 12), Size = UDim2.fromOffset(32, 32), ZIndex = 11 })
		end
		local hit = Instance.new("TextButton")
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 14
		hit.Parent = note
		hit.Activated:Connect(function()
			if locked then
				UiSound.play("error")
				return
			end
			UiSound.play("paper_slide", { volume = 0.6 })
			state.journalKey = e.key
			renderJournal()
		end)
		y += 62
	end
	list.CanvasSize = UDim2.fromOffset(0, y + 8)

	PaperUi.divider(lb, UDim2.fromOffset(24, 484), 552, 7)
	PaperUi.bold(lb, ("АРХИВ %d/%d"):format(archive.owned or 0, archive.total or 0), 24, P.green, {
		Position = UDim2.fromOffset(0, 504), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center,
	})
	for i, f in ipairs(archive.fragments or {}) do
		local column = (i - 1) % 7
		local row = (i - 1) // 7
		PaperUi.slot(lb, UDim2.fromOffset(30 + column * 78, 546 + row * 78), 70, {
			icon = f.owned and "it_bookBlue" or "it_bookRed",
			dim = not f.owned,
			selected = selected and selected.key == "f" .. f.id,
			z = 8,
			onClick = function()
				state.journalKey = "f" .. f.id
				renderJournal()
			end,
		})
	end
	if (archive.total or 0) == 0 then
		centered(lb, "Фрагменты архива появятся с сюжетом.", 18, P.faint, 560, nil, PaperUi.italic)
	end

	if selected and selected.quest then
		questDetail(rb, selected.quest)
	elseif selected and selected.fragment then
		fragmentDetail(rb, selected.fragment)
	else
		centered(rb, "Записей нет", 30, P.green, 120, nil, PaperUi.bold)
		centered(rb, "Задания появятся после разговора с жителями.", 20, P.ink2, 170, nil, PaperUi.italic)
	end
end

-- ===== вкладки =====

function CharacterWindow.currentTab()
	return win and state.tab or nil
end

local TAB_ORDER = { gear = 1, hero = 2, journal = 3, talents = 4 }

-- Перелистывание: текущие листы уходят в сторону и гаснут, новые приходят
-- с другой стороны и «ложатся» на стол; закладка подпрыгивает, лента-заголовок
-- меняет надпись, шуршит бумага. Вперёд по закладкам — листаем влево, назад — вправо.
function CharacterWindow.selectTab(tab: string)
	if not win then
		return
	end
	hideTip()
	local spec
	for _, t in ipairs(TABS) do
		if t.id == tab then
			spec = t
		end
	end
	if not spec then
		return
	end
	local prev = state.tab
	state.tab = tab
	local dir = (prev and TAB_ORDER[prev] and TAB_ORDER[tab] < TAB_ORDER[prev]) and -1 or 1
	for _, t in ipairs(TABS) do
		refs.tabs[t.id]:setActive(t.id == tab)
		if t.id ~= tab and t.id ~= prev then
			refs.pages[t.id].Visible = false
		end
	end
	UiMotion.punch(refs.tabs[tab].holder, 0.1, 0.22)
	-- лента: старая надпись гаснет, новая проявляется с толчком
	local title = refs.title
	if prev then
		PixelUi.tween(title, 0.08, { TextTransparency = 1 })
		task.delay(0.09, function()
			if title.Parent and state.tab == tab then
				title.Text = tabTitle(spec)
				PixelUi.tween(title, 0.14, { TextTransparency = 0 })
				UiMotion.punch(title.Parent, 0.06, 0.2)
			end
		end)
	else
		title.Text = tabTitle(spec)
		PixelUi.pop(title)
	end

	if prev and prev ~= tab and refs.pages[prev] then
		UiMotion.pageOut(refs.pages[prev], dir)
		UiSound.play(dir > 0 and "page_turn" or "page_back")
	else
		UiSound.play("tab_select")
	end
	local page = refs.pages[tab]
	page.Visible = true
	if tab == "gear" then
		renderGear()
	elseif tab == "hero" then
		renderHero(page)
	elseif tab == "journal" then
		state.quests = nil
		renderJournal()
	elseif tab == "talents" then
		TalentPage.render(page, {
			api = ctx.api,
			fx = refs.fx,
			toast = toast,
			animate = true,
		})
	end
	if prev and prev ~= tab then
		UiMotion.pageIn(page, dir, 0.08)
		task.delay(0.2, function()
			if state.tab == tab then
				UiSound.play("paper_slide")
			end
		end)
	end
end

-- ===== открытие =====

local function fitSafeArea()
	local safeAreaScale = Instance.new("UIScale")
	safeAreaScale.Name = "SafeAreaScale"
	safeAreaScale.Parent = win.canvas
	local function fit()
		local camera = workspace.CurrentCamera
		local rootScale = win.root:FindFirstChildOfClass("UIScale")
		if not camera or not rootScale then
			return
		end
		-- Верхнюю панель Roblox уже учитывает PixelUi.screen (корень ниже и меньше на её
		-- высоту). Вторая компенсация здесь уменьшала книгу на ~6% и сдвигала вниз — та же
		-- ошибка, что убрали в InventoryWindow 05.11. Книга — во весь холст.
		safeAreaScale.Scale = 1
		win.canvas.Position = UDim2.fromScale(0.5, 0.5)
	end
	local viewportConnection
	local function watchCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
			viewportConnection = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
		end
		fit()
	end
	watchCamera()
	local cameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	win:onCleanup(function()
		cameraConnection:Disconnect()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
	end)
end

local function buildWallet(canvas)
	-- Четыре закладки (24..776) и лента (784..1172): кошелёк уже — 1180..1486.
	PaperUi.image(canvas, "plate", {
		Position = UDim2.fromOffset(1180, 24), Size = UDim2.fromOffset(306, 60), ZIndex = 8,
	}, { scale = 2 })
	for index, spec in ipairs({ { "coin", "Gold" }, { "ingot", "IronCount" }, { "dust", "EchoDust" } }) do
		local x = 1192 + (index - 1) * 98
		PixelUi.icon(canvas, spec[1], UDim2.fromOffset(x, 38), 28, { ZIndex = 10 })
		local value = PaperUi.bold(canvas, tostring(player:GetAttribute(spec[2]) or 0), 21, P.ink, {
			Position = UDim2.fromOffset(x + 32, 38), Size = UDim2.fromOffset(64, 30), ZIndex = 10,
			TextScaled = false, TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local connection = player:GetAttributeChangedSignal(spec[2]):Connect(function()
			local before = tonumber(value.Text) or 0
			local after = player:GetAttribute(spec[2]) or 0
			UiFx.countUp(value, before, after, 0.5, "%d")
		end)
		win:onCleanup(function()
			connection:Disconnect()
		end)
	end
end

function CharacterWindow.open(context)
	ctx = context
	refs = {}
	state.category = state.category or "all"
	if type(context.data) == "table" and type(context.data.category) == "string" then
		state.category = context.data.category
		state.selectedKey = nil
	end
	state.confirmKey = nil
	state.quests = nil
	win = WindowBase.new("KlinokCharacter", { onClose = context.close, wallet = false, order = 40 })
	win.vignette.BackgroundTransparency = 0.78
	win.closeButton.Visible = false
	fitSafeArea()
	local canvas = win.canvas

	PaperUi.desk(canvas, UDim2.fromOffset(16, 100), UDim2.fromOffset(1568, 784), 1)
	refs.fx = layer(canvas, "Fx", 40)

	refs.tabs, refs.pages = {}, {}
	for i, t in ipairs(TABS) do
		local page = layer(canvas, "Page_" .. t.id, 2)
		page.Visible = false
		refs.pages[t.id] = page
		refs.tabs[t.id] = PaperUi.strip(canvas, UDim2.fromOffset(24 + (i - 1) * 190, 26), UDim2.fromOffset(182, 48), {
			text = t.name, knobText = keyName(t.action), textSize = 19, z = 9,
			onClick = function()
				if state.tab ~= t.id then
					CharacterWindow.selectTab(t.id)
				end
			end,
		})
	end
	local _, title = PaperUi.ribbon(canvas, UDim2.fromOffset(784, 10), 388, "", { height = 76, textSize = 28, z = 10 })
	refs.title = title
	-- Свободные очки древа — красная печать на закладке «Древо».
	do
		local tab = refs.tabs.talents
		-- сургучная печать: красный круг с бумажной каймой и белой цифрой
		local badge = Instance.new("Frame")
		badge.Name = "TalentBadge"
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.new(1, -14, 0, 4)
		badge.Size = UDim2.fromOffset(28, 28)
		badge.BackgroundColor3 = P.red
		badge.BorderSizePixel = 0
		badge.ZIndex = 12
		badge.Parent = tab.holder
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = badge
		local rim = Instance.new("UIStroke")
		rim.Color = P.paper
		rim.Thickness = 2
		rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rim.Parent = badge
		local count = PaperUi.bold(badge, "", 16, Color3.new(1, 1, 1), {
			Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, -1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13,
		})
		local function update()
			local free = player:GetAttribute("TalentFree") or 0
			badge.Visible = free > 0
			count.Text = free > 9 and "9+" or tostring(free)
		end
		update()
		local connection = player:GetAttributeChangedSignal("TalentFree"):Connect(update)
		win:onCleanup(function()
			connection:Disconnect()
		end)
	end
	buildWallet(canvas)
	PaperUi.roundButton(canvas, UDim2.fromOffset(1498, 20), 64, "icClose", context.close, { z = 12 })

	state.data = nil
	state.list = {}
	local data = context.api.character.get()
	if data then
		state.data = data
		state.list = buildList(data)
	else
		warn("[CharacterWindow] сервер не вернул данные персонажа")
	end
	buildGearPage(refs.pages.gear)

	-- Сумка меняется на сервере (подбор из сундука, использование быстрого
	-- предмета) — книга обновляется сама, пока открыта.
	local remote = UiNet.find("BagChanged")
	if remote then
		local pending = false
		local connection = remote.OnClientEvent:Connect(function()
			if pending then
				return
			end
			pending = true
			task.delay(0.15, function()
				pending = false
				if win and state.tab == "gear" then
					reload(true)
				end
			end)
		end)
		win:onCleanup(function()
			connection:Disconnect()
		end)
	end

	local chestConnection = player:GetAttributeChangedSignal("ChestsStored"):Connect(function()
		task.delay(0.2, function()
			if win and state.tab == "gear" then
				reload(true)
			end
		end)
	end)
	win:onCleanup(function()
		chestConnection:Disconnect()
	end)

	local first = context.tab or "gear"
	if not TAB_ORDER[first] then
		first = "gear"
	end
	state.tab = nil
	CharacterWindow.selectTab(first)
	if first == "gear" and refs.power then
		UiFx.countUp(refs.power, 0, power(), 0.6, "СИЛА %d")
	end
	return win
end

function CharacterWindow.close()
	TalentPage.close()
	if win then
		win:destroy()
		win = nil
	end
	refs = {}
	state.quests = nil
end

return CharacterWindow