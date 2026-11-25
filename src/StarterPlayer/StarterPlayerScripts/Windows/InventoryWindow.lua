--!nonstrict
-- InventoryWindow — Снаряжение. В центре персонаж игрока на светящемся
-- постаменте (ViewportFrame, крутится мышью), вокруг 6 слотов экипировки,
-- слева вкладки всех категорий и сетка, справа карточка предмета.

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiAssets = require(Shared.Config.UiAssets)
local Armor = require(Shared.Config.Armor)

local Lib = script.Parent.Parent.Lib
local Bus = require(Lib.Bus)
local PixelUi = require(Lib.PixelUi)
local UiFx = require(Lib.UiFx)
local UiSound = require(Lib.UiSound)
local WindowBase = require(Lib.WindowBase)

local InventoryWindow = {}

local C = UiAssets.Colors
local player = Players.LocalPlayer
local win, ctx
local refs: any = {}
local state: any = { tab = 1, selected = 1, data = nil, yaw = 0 }

local TABS = {
	{ "Оружие", "weapons" },
	{ "Броня", "armor" },
	{ "Аксессуары", "accessories" },
	{ "Зелья", "potions" },
	{ "Души", "souls" },
	{ "Материалы", "materials" },
}
local EQUIP = {
	{ "helm", "Шлем", 536, 220 }, { "armor", "Доспех", 536, 364 }, { "amulet", "Амулет", 536, 508 },
	{ "sword", "Оружие", 976, 220 }, { "ring", "Кольцо", 976, 364 }, { "whirl", "Душа", 976, 508 },
}

local function clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		c:Destroy()
	end
end

local function paperImage(parent, image, props)
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Image = image
	label.ScaleType = Enum.ScaleType.Stretch
	label.Parent = parent
	return PixelUi.apply(label, props)
end

local function paperText(parent, text, size, color, props)
	local label = PixelUi.text(parent, text, size or 18, color or Color3.fromRGB(66, 48, 32), props)
	label.FontFace = Font.fromEnum(Enum.Font.Garamond)
	if parent:IsA("GuiObject") then
		label.ZIndex = math.max(label.ZIndex, parent.ZIndex + 1)
	end
	return label
end

local function paperPanel(parent, position, size, z)
	local holder = Instance.new("Frame")
	holder.Name = "PaperPanel"
	holder.BackgroundTransparency = 1
	holder.Position = position
	holder.Size = size
	holder.ZIndex = z or 3
	holder.Parent = parent
	local image = paperImage(holder, UiAssets.Paper.Panel, {
		Size = UDim2.fromScale(1, 1),
		ZIndex = z or 3,
	})
	image.ScaleType = Enum.ScaleType.Slice
	image.SliceCenter = Rect.new(28, 26, 628, 198)
	return holder
end

local function paperSlot(parent, position, size, iconName, rarityId, dim)
	local holder = Instance.new("Frame")
	holder.Name = "PaperSlot"
	holder.BackgroundTransparency = 1
	holder.Position = position
	holder.Size = UDim2.fromOffset(size, size)
	holder.ZIndex = 6
	holder.Parent = parent
	local art = paperImage(holder, UiAssets.Paper.Slot, {
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
	})
	art.ScaleType = Enum.ScaleType.Fit
	if rarityId then
		local ring = Instance.new("Frame")
		ring.BackgroundTransparency = 1
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.new(1, -8, 1, -8)
		ring.ZIndex = 7
		ring.Parent = holder
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = ring
		local stroke = Instance.new("UIStroke")
		stroke.Color = UiAssets.Rarity[rarityId] or Color3.fromRGB(64, 148, 112)
		stroke.Thickness = 2
		stroke.Parent = ring
	end
	if iconName then
		local iconSize = math.floor(size * 0.52)
		local icon = PixelUi.icon(holder, iconName,
			UDim2.new(0.5, -iconSize / 2, 0.5, -iconSize / 2), iconSize, { ZIndex = 8 })
		icon.ImageTransparency = dim and 0.6 or 0
	end
	return holder
end

local function paperButton(parent, position, size, text, onClick, opts)
	opts = opts or {}
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = position
	holder.Size = size
	holder.ZIndex = opts.z or 7
	holder.Parent = parent
	local face = paperImage(holder, opts.banner and UiAssets.Paper.Banner or UiAssets.Paper.Item, {
		Size = UDim2.fromScale(1, 1),
		ZIndex = holder.ZIndex,
	})
	if opts.banner then
		face.ImageColor3 = opts.active and Color3.new(1, 1, 1) or Color3.fromRGB(195, 184, 162)
	else
		face.ScaleType = Enum.ScaleType.Slice
		face.SliceCenter = Rect.new(24, 18, 568, 126)
	end
	local label = paperText(holder, text, opts.textSize or 18, opts.active and Color3.fromRGB(35, 101, 78) or Color3.fromRGB(66, 48, 32), {
		Size = UDim2.new(1, -12, 1, -6),
		Position = UDim2.fromOffset(6, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = holder.ZIndex + 1,
	})
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = holder.ZIndex + 2
	hit.Parent = holder
	hit.Activated:Connect(function()
		if onClick then
			UiSound.play("ui_click")
			onClick()
		end
	end)
	return { holder = holder, face = face, label = label }
end

local function categoryItems()
	if not state.data then
		return {}
	end
	if state.tab == 1 then
		return state.data.items or {}
	elseif state.tab == 2 then
		return state.data.armorItems or {}
	elseif state.tab == 5 then
		return state.data.souls or {}
	elseif state.tab == 6 then
		return state.data.materials or {}
	end
	return {}
end

local function categoryIcon(item)
	if state.tab == 2 or item.kind == "armor" then
		return item.slot == "helm" and "helm" or "armor"
	elseif state.tab == 5 then
		return "soul"
	elseif state.tab == 6 then
		return item.id == "rusty_iron" and "ingot" or "dust"
	end
	return (item.typeId and UiAssets.WeaponIcon[item.typeId]) or "sword"
end

-- Копия персонажа на постаменте. Зовётся при открытии и после смены брони.
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
	if model then
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
end

-- ===== витрина персонажа =====
local function buildViewport(canvas)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Showcase"
	vp.BackgroundColor3 = Color3.fromRGB(233, 216, 184)
	vp.BackgroundTransparency = 0
	vp.Active = true
	vp.Position = UDim2.fromOffset(484, 144)
	vp.Size = UDim2.fromOffset(632, 728)
	vp.ZIndex = 2
	vp.Ambient = Color3.fromRGB(90, 100, 120)
	vp.LightColor = Color3.fromRGB(200, 225, 255)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
	vp.Parent = canvas
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.fromRGB(247, 235, 208), Color3.fromRGB(196, 166, 124))
	g.Parent = vp
	local world = Instance.new("WorldModel")
	world.Parent = vp
	-- постамент: шаблон из ReplicatedStorage.UiStages.InventoryStage или простой из деталей
	local template = ReplicatedStorage:FindFirstChild("UiStages") and ReplicatedStorage.UiStages:FindFirstChild("InventoryStage")
	if template then
		local stage = template:Clone()
		stage:PivotTo(CFrame.new())
		stage.Parent = world
	else
		for _, spec in ipairs({ { 14, 0.8, Color3.fromRGB(70, 74, 84) }, { 11.2, 1.6, Color3.fromRGB(100, 106, 118) }, { 9.2, 2.2, Color3.fromRGB(130, 136, 148) } }) do
			local p = Instance.new("Part")
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(spec[2], spec[1], spec[1])
			p.CFrame = CFrame.new(0, spec[2] / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
			p.Color = spec[3]
			p.Anchored = true
			p.Parent = world
		end
		for k = 0, 23 do
			local a = k / 24 * math.pi * 2
			local rune = Instance.new("Part")
			rune.Size = Vector3.new(0.7, 0.1, 0.25)
			rune.Material = Enum.Material.Neon
			rune.Color = Color3.fromRGB(111, 227, 255)
			rune.CFrame = CFrame.new(math.cos(a) * 4.2, 2.25, math.sin(a) * 4.2) * CFrame.Angles(0, -a + math.pi / 2, 0)
			rune.Anchored = true
			rune.Parent = world
		end
	end
	refs.world = world
	cloneAvatar(world)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 7.5, -19), Vector3.new(0, 5.6, 0))
	camera.Parent = vp
	vp.CurrentCamera = camera
	-- поворот мышью / пальцем + медленное вращение
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
end

-- ===== правая карточка =====
local renderArmorDetail
local renderGrid
local renderEquip

local function renderDetail()
	local body = refs.detail
	clear(body)
	local tab = TABS[state.tab]
	local items = categoryItems()
	local item = items[state.selected]
	if not state.data then
		paperText(body, "Не удалось загрузить инвентарь", 22, Color3.fromRGB(142, 55, 42), {
			Position = UDim2.fromOffset(20, 64), Size = UDim2.new(1, -40, 0, 64), TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		paperText(body, "Закройте окно и попробуйте открыть его снова.", 18, Color3.fromRGB(106, 83, 58), {
			Position = UDim2.fromOffset(24, 136), Size = UDim2.new(1, -48, 0, 52), TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		return
	end
	if not item then
		local hints = {
			weapons = "Оружие, которым вы владеете, появится здесь.",
			armor = "Шлемы и доспехи выпадают из сундуков этажей. Сундук босса — всегда.",
			accessories = "В текущей версии игры аксессуары ещё не добавлены.",
			potions = "В текущей версии игры зелья ещё не добавлены.",
			souls = "Души появятся после победы над боссами.",
			materials = "Материалы появятся после добычи.",
		}
		paperText(body, tab[1], 28, Color3.fromRGB(54, 91, 72), {
			Position = UDim2.fromOffset(18, 38), Size = UDim2.new(1, -36, 0, 44),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local names = Armor.SlotNames[player:GetAttribute("ClassName") or "warrior"]
		if tab[2] == "armor" and names then
			hints.armor = names.hint
		end
		paperText(body, hints[tab[2]], 19, Color3.fromRGB(106, 83, 58), {
			Position = UDim2.fromOffset(30, 104), Size = UDim2.new(1, -60, 0, 90),
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
		})
		if state.tab == 5 then
			paperText(body, ("Осколки души: %d"):format(state.data.soulStacks or 0), 20, Color3.fromRGB(54, 91, 72), {
				Position = UDim2.fromOffset(20, 218), Size = UDim2.new(1, -40, 0, 36),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		end
		return
	end

	local rarityId = item.rarityId or item.rarity
	local itemCard = paperImage(body, UiAssets.Paper.Item, {
		Position = UDim2.fromOffset(12, 16), Size = UDim2.new(1, -24, 0, 116), ZIndex = 5,
	})
	itemCard.ScaleType = Enum.ScaleType.Slice
	itemCard.SliceCenter = Rect.new(24, 18, 568, 126)
	paperSlot(body, UDim2.fromOffset(24, 28), 88, categoryIcon(item), rarityId)
	paperText(body, item.name or item.id or "Предмет", 23, UiAssets.Rarity[rarityId] or Color3.fromRGB(66, 48, 32), {
		Position = UDim2.fromOffset(126, 35), Size = UDim2.new(1, -146, 0, 40), TextWrapped = true,
	})
	paperText(body, UiAssets.RarityName[rarityId] or (tab[1]), 17, Color3.fromRGB(106, 83, 58), {
		Position = UDim2.fromOffset(128, 77), Size = UDim2.new(1, -148, 0, 26),
	})

	if state.tab == 2 then
		renderArmorDetail(body, item)
		return
	end

	if state.tab ~= 1 then
		local quantity = item.count or 1
		paperText(body, ("Количество: %d"):format(quantity), 21, Color3.fromRGB(54, 91, 72), {
			Position = UDim2.fromOffset(26, 160), Size = UDim2.new(1, -52, 0, 38),
		})
		if state.tab == 5 then
			paperText(body, ("Осколки души: %d"):format(state.data.soulStacks or 0), 19, Color3.fromRGB(106, 83, 58), {
				Position = UDim2.fromOffset(26, 206), Size = UDim2.new(1, -52, 0, 34),
			})
		end
		return
	end

	PixelUi.stars(body, UDim2.new(0, 128, 0, 108), item.level or 1, item.maxLevel or 1, 20)
	local rows = {
		{ "Урон", tostring(item.damage or "—") }, { "Крит", ("%d%%"):format(item.crit or 0) },
		{ "Скорость", ("x%.1f"):format(item.speed or 1) }, { "Эхо", ("%d/%d"):format(item.echoes or 0, item.cost and item.cost.echoes or 0) },
	}
	if item.ability then
		table.insert(rows, { "Способн.", item.ability })
	end
	for i, r in ipairs(rows) do
		local y = 160 + (i - 1) * 34
		paperText(body, r[1], 18, Color3.fromRGB(106, 83, 58), { Position = UDim2.fromOffset(24, y), Size = UDim2.fromOffset(150, 26) })
		paperText(body, r[2], 18, Color3.fromRGB(66, 48, 32), {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, y),
			Size = UDim2.fromOffset(210, 26), TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
	local ready = item.cost and (item.echoes or 0) >= item.cost.echoes
	local hintY = 160 + #rows * 34 + 8
	paperText(body, ready and ("Эха хватает — можно ковать ★" .. ((item.level or 1) + 1)) or "Повторки оружия превращаются в эхо.", 17,
		ready and Color3.fromRGB(54, 110, 82) or Color3.fromRGB(106, 83, 58), {
			Position = UDim2.fromOffset(18, hintY), Size = UDim2.new(1, -36, 0, 54),
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
		})
	paperButton(body, UDim2.fromOffset(20, 584), UDim2.new(1, -40, 0, 56), item.equipped and "УЖЕ НАДЕТО" or "НАДЕТЬ", function()
		if not item.equipped then
			InventoryWindow.equip(item)
		end
	end, { textSize = 20 })
	-- Кузня — только в долине: на этаже окно-сцена оставило бы героя без защиты.
	local inHub = player:GetAttribute("Zone") ~= "Floor"
	paperButton(body, UDim2.fromOffset(20, 652), UDim2.new(1, -40, 0, 56), inHub and "КУЗНЯ ЭХА" or "КУЗНЯ — В ДОЛИНЕ", function()
		if inHub then
			ctx.close()
			task.wait(0.3)
			Bus.emit("openStation", { name = "Forge" })
		end
	end, { textSize = 20 })
end

-- ===== сетка =====
function renderGrid()
	local grid = refs.grid
	clear(grid)
	local items = categoryItems()
	local supported = state.tab == 1 or state.tab == 2 or state.tab == 5 or state.tab == 6
	local cellCount = supported and math.max(20, #items) or 0
	local rows = math.ceil(cellCount / 4)
	grid.CanvasSize = UDim2.fromOffset(0, rows * 112)
	if cellCount == 0 then
		paperText(grid, state.data and "Для этой категории пока нет игровых предметов." or "Инвентарь недоступен.", 18,
			Color3.fromRGB(106, 83, 58), {
				Position = UDim2.fromOffset(16, 200), Size = UDim2.new(1, -32, 0, 72),
				TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
			})
	end
	for k = 1, cellCount do
		local x = ((k - 1) % 4) * 104
		local y = ((k - 1) // 4) * 112
		local item = items[k]
		local cell = Instance.new("Frame")
		cell.BackgroundTransparency = 1
		cell.Position = UDim2.fromOffset(x, y)
		cell.Size = UDim2.fromOffset(92, 108)
		cell.ZIndex = 6
		cell.Parent = grid
		local rarityId = item and (item.rarityId or item.rarity)
		paperSlot(cell, UDim2.fromOffset(4, 0), 84, item and categoryIcon(item) or nil, rarityId)
		if item then
			local name = item.name or item.id or "Предмет"
			paperText(cell, name, 13, Color3.fromRGB(66, 48, 32), {
				Position = UDim2.fromOffset(0, 84), Size = UDim2.fromOffset(92, 22),
				TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 10,
			})
			if item.count and item.count > 1 then
				paperText(cell, "×" .. item.count, 15, Color3.fromRGB(35, 101, 78), {
					AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 2),
					Size = UDim2.fromOffset(36, 20), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 10,
				})
			elseif item.level and (state.tab == 1 or state.tab == 2) then
				paperText(cell, "★" .. item.level, 14, Color3.fromRGB(156, 100, 34), {
					Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(36, 20), ZIndex = 10,
				})
			end
			if item.equipped or k == state.selected then
				local outline = Instance.new("UIStroke")
				outline.Color = item.equipped and Color3.fromRGB(54, 132, 91) or Color3.fromRGB(204, 148, 62)
				outline.Thickness = 2
				outline.Parent = cell
			end
			local hit = Instance.new("TextButton")
			hit.BackgroundTransparency = 1
			hit.Text = ""
			hit.Size = UDim2.fromScale(1, 1)
			hit.ZIndex = 12
			hit.Parent = cell
			hit.Activated:Connect(function()
				state.selected = k
				renderGrid()
				renderDetail()
			end)
		end
	end
end

function renderEquip()
	local holder = refs.equip
	clear(holder)
	local eq = state.data and state.data.equipped
	local slots = state.data and state.data.slots or {}
	for _, spec in ipairs(EQUIP) do
		local armorItem = (spec[1] == "helm" or spec[1] == "armor") and slots[spec[1]] or nil
		local filled = (spec[1] == "sword" and eq ~= nil) or (spec[1] == "whirl" and eq and eq.soul ~= nil) or armorItem ~= nil
		local icon = spec[1]
		local rarityId = filled and eq and eq.rarityId or nil
		if spec[1] == "sword" and eq then
			icon = UiAssets.WeaponIcon[eq.typeId] or "sword"
		elseif spec[1] == "whirl" and filled then
			icon = "soul"
		elseif armorItem then
			rarityId = armorItem.rarityId
		end
		local slotFrame = paperSlot(holder, UDim2.fromOffset(spec[3], spec[4]), 88, icon, rarityId, not filled)
		if armorItem then
			-- Клик по слоту брони открывает вкладку «Броня» с этим предметом.
			local hit = Instance.new("TextButton")
			hit.BackgroundTransparency = 1
			hit.Text = ""
			hit.Size = UDim2.fromScale(1, 1)
			hit.ZIndex = 12
			hit.Parent = slotFrame
			hit.Activated:Connect(function()
				if refs.selectTab then
					refs.selectTab(2)
				end
				for k, entry in ipairs(state.data.armorItems or {}) do
					if entry.key == armorItem.key then
						state.selected = k
					end
				end
				renderGrid()
				renderDetail()
			end)
			if (armorItem.level or 1) > 1 then
				paperText(slotFrame, "★" .. armorItem.level, 14, Color3.fromRGB(156, 100, 34), {
					Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(36, 20), ZIndex = 10,
				})
			end
		end
		local slotLabel = (spec[1] == "helm" or spec[1] == "armor") and Armor.slotName(spec[1], player:GetAttribute("ClassName")) or spec[2]
		paperText(holder, slotLabel, 17, Color3.fromRGB(66, 48, 32), {
			Position = UDim2.fromOffset(spec[3] - 40, spec[4] + 94),
			Size = UDim2.fromOffset(168, 24), TextXAlignment = Enum.TextXAlignment.Center,
		})
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local armorStats = state.data and state.data.armorStats or {}
	local stats = { { "Урон", tostring(eq and eq.damage or 0) }, { "Крит", ("%d%%"):format(eq and eq.crit or 0) },
		{ "HP", tostring(math.floor(humanoid and humanoid.MaxHealth or 100)) },
		{ "Броня", ("%d · −%d%%"):format(armorStats.totalArmor or armorStats.armor or 0, armorStats.reduction or 0) },
		{ "Осколки", tostring(state.data and state.data.soulStacks or 0) } }
	for i, s in ipairs(stats) do
		local chip = paperPanel(holder, UDim2.fromOffset(516 + (i - 1) * 120, 760), UDim2.fromOffset(112, 76), 5)
		paperText(chip, s[1], 15, Color3.fromRGB(106, 83, 58), {
			Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center,
		})
		paperText(chip, s[2], 19, Color3.fromRGB(66, 48, 32), {
			Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center,
		})
	end
	refs.power.Text = state.data and ("СИЛА %d"):format(state.data.power or 0) or "СИЛА —"
	refs.powerDelta.Text = state.data and ((state.data.powerDelta and state.data.powerDelta > 0) and
		("+%d с новым оружием"):format(state.data.powerDelta) or "") or "Данные недоступны"
end


-- ===== карточка брони =====
local function upgradeArmor(item)
	local result = ctx.api.inventory.upgradeArmor and ctx.api.inventory.upgradeArmor(item)
	if not result or not result.ok then
		UiSound.play("error")
		return
	end
	UiSound.play("forge_success")
	UiFx.flash(UiAssets.Rarity[item.rarityId] or C.gold, 0.35, 0.3)
	local refreshed = ctx.api.inventory.get()
	if refreshed then
		local before = state.data.power or 0
		state.data = refreshed
		renderGrid()
		renderDetail()
		renderEquip()
		local after = state.data.power or 0
		if after ~= before then
			UiFx.countUp(refs.power, before, after, 0.7, "СИЛА %d")
		end
	end
end

function renderArmorDetail(body, item)
	PixelUi.stars(body, UDim2.new(0, 128, 0, 108), item.level or 1, item.maxLevel or 1, 20)
	local nextHp = item.nextHealth and (" → %d"):format(item.nextHealth) or ""
	local nextRed = item.nextReduction and (" → %s%%"):format(tostring(item.nextReduction)) or ""
	local rows = {
		{ "Слот", item.slotName or "—" },
		{ "Броня", ("+%d"):format(item.armor or 0) },
		{ "Здоровье", ("+%d%s"):format(item.health or 0, nextHp) },
		{ "Снижение урона", ("%s%%%s"):format(tostring(item.reduction or 0), nextRed) },
		{ "Эхо", ("%d/%d"):format(item.echoes or 0, item.cost and item.cost.echoes or 0) },
	}
	-- Шляпа и накидка мага: мана (растёт с ★) и её восстановление.
	if item.mana then
		local nextMana = item.nextMana and (" → %d"):format(item.nextMana) or ""
		local regen = item.manaRegen and (" · %.1f/с"):format(item.manaRegen) or ""
		table.insert(rows, 4, { "Мана", ("+%d%s%s"):format(item.mana, nextMana, regen) })
	end
	for i, r in ipairs(rows) do
		local y = 160 + (i - 1) * 34
		paperText(body, r[1], 18, Color3.fromRGB(106, 83, 58), { Position = UDim2.fromOffset(24, y), Size = UDim2.fromOffset(170, 26) })
		paperText(body, r[2], 18, Color3.fromRGB(66, 48, 32), {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, y),
			Size = UDim2.fromOffset(190, 26), TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
	local y = 160 + #rows * 34 + 6
	if item.setBonus then
		paperText(body, ("Набор %s"):format(item.setName or ""), 18,
			item.setActive and Color3.fromRGB(54, 110, 82) or Color3.fromRGB(106, 83, 58), {
				Position = UDim2.fromOffset(18, y), Size = UDim2.new(1, -36, 0, 26),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		paperText(body, item.setBonus .. (item.setActive and " — активен" or ""), 16,
			item.setActive and Color3.fromRGB(54, 110, 82) or Color3.fromRGB(106, 83, 58), {
				Position = UDim2.fromOffset(18, y + 26), Size = UDim2.new(1, -36, 0, 64),
				TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
			})
		y += 94
	end
	local ready = item.cost and (item.echoes or 0) >= item.cost.echoes
	paperText(body, ready and ("Эха хватает — можно вплавить ★" .. ((item.level or 1) + 1) .. (" за %d золота"):format(item.cost.gold or 0))
		or (item.cost and "Повторки брони превращаются в эхо." or "Предмет на потолке редкости."), 16,
		ready and Color3.fromRGB(54, 110, 82) or Color3.fromRGB(106, 83, 58), {
			Position = UDim2.fromOffset(18, y), Size = UDim2.new(1, -36, 0, 48),
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
		})

	paperButton(body, UDim2.fromOffset(20, 584), UDim2.new(1, -40, 0, 56), item.equipped and "УЖЕ НАДЕТО" or "НАДЕТЬ", function()
		if not item.equipped then
			InventoryWindow.equip(item)
		end
	end, { textSize = 20 })
	-- Вплавить эхо можно только в долине: на этаже окно оставило бы героя без защиты.
	local inHub = player:GetAttribute("Zone") ~= "Floor"
	local label = not inHub and "ВПЛАВИТЬ — В ДОЛИНЕ" or (ready and "ВПЛАВИТЬ ЭХО" or "НЕ ХВАТАЕТ ЭХА")
	paperButton(body, UDim2.fromOffset(20, 652), UDim2.new(1, -40, 0, 56), label, function()
		if inHub and ready then
			upgradeArmor(item)
		end
	end, { textSize = 20 })
end

function InventoryWindow.equip(item)
	if not item or not item.index or not state.data then
		return
	end
	local before = state.data.power or 0
	local result = ctx.api.inventory.equip(item)
	if result == nil then
		warn("[InventoryWindow] не удалось сменить экипированное оружие")
		return
	end
	UiSound.play("forge_strike", { pitch = 1.4, volume = 0.6 })
	if item.kind == "armor" then
		Bus.emit("sfx", { name = "armorEquip" })
		-- Облик пересобирает сервер: ждём новый ArmorLook и обновляем витрину.
		local character = player.Character
		if character and refs.world then
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
	end
	UiFx.flash(UiAssets.Rarity[item.rarityId] or C.gold, 0.3, 0.3)
	local refreshed = ctx.api.inventory.get()
	if not refreshed then
		warn("[InventoryWindow] оружие сменено, но инвентарь не удалось обновить")
		return
	end
	state.data = refreshed
	state.selected = 1
	renderGrid()
	renderDetail()
	renderEquip()
	local after = state.data.power or 0
	if after ~= before then
		UiFx.countUp(refs.power, before, after, 0.7, "СИЛА %d")
	end
end

function InventoryWindow.open(context)
	ctx = context
	refs = {}
	state.tab, state.selected = 1, 1
	win = WindowBase.new("KlinokInventory", { onClose = context.close, wallet = false, order = 40 })
	win.vignette.BackgroundTransparency = 0.78
	win.closeButton.Visible = false
	local safeAreaScale = Instance.new("UIScale")
	safeAreaScale.Name = "SafeAreaScale"
	safeAreaScale.Parent = win.canvas
	-- Верхнюю панель уже учитывает PixelUi.screen (корень меньше на её высоту).
	-- Раньше здесь была вторая компенсация — она сдвигала книгу вниз и резала низ.
	local function fitCanvasToSafeArea()
		safeAreaScale.Scale = 1
		win.canvas.Position = UDim2.new(0.5, 0, 0.5, 0)
	end
	fitCanvasToSafeArea()
	local viewportConnection
	local function watchCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
			viewportConnection = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitCanvasToSafeArea)
		end
		fitCanvasToSafeArea()
	end
	watchCamera()
	local cameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	win:onCleanup(function()
		cameraConnection:Disconnect()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
	end)
	paperPanel(win.canvas, UDim2.fromOffset(18, 78), UDim2.fromOffset(1564, 800), 1)
	buildViewport(win.canvas)
	state.data = context.api.inventory.get()
	if not state.data then
		warn("[InventoryWindow] сервер не вернул данные инвентаря")
	end

	paperImage(win.canvas, UiAssets.Paper.Banner, {
		Position = UDim2.fromOffset(556, 8), Size = UDim2.fromOffset(488, 132), ZIndex = 8,
	})
	paperText(win.canvas, "ИНВЕНТАРЬ", 29, Color3.fromRGB(54, 91, 72), {
		Position = UDim2.fromOffset(585, 34), Size = UDim2.fromOffset(430, 42),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 10,
	})
	paperText(win.canvas, "Снаряжение и добыча", 18, Color3.fromRGB(106, 83, 58), {
		Position = UDim2.fromOffset(585, 75), Size = UDim2.fromOffset(430, 28),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 10,
	})

	local wallet = paperPanel(win.canvas, UDim2.fromOffset(1056, 40), UDim2.fromOffset(440, 68), 8)
	local walletValues = {}
	for index, spec in ipairs({ { "coin", "Gold" }, { "ingot", "IronCount" }, { "dust", "EchoDust" } }) do
		local x = 14 + (index - 1) * 140
		PixelUi.icon(wallet, spec[1], UDim2.fromOffset(x, 19), 26, { ZIndex = 10 })
		walletValues[index] = paperText(wallet, tostring(player:GetAttribute(spec[2]) or 0), 19, Color3.fromRGB(66, 48, 32), {
			Position = UDim2.fromOffset(x + 32, 18), Size = UDim2.fromOffset(92, 28), ZIndex = 10,
		})
		local connection = player:GetAttributeChangedSignal(spec[2]):Connect(function()
			walletValues[index].Text = tostring(player:GetAttribute(spec[2]) or 0)
		end)
		win:onCleanup(function()
			connection:Disconnect()
		end)
	end
	local close = Instance.new("TextButton")
	close.Name = "PaperClose"
	close.BackgroundColor3 = Color3.fromRGB(177, 82, 62)
	close.Position = UDim2.fromOffset(1520, 88)
	close.Size = UDim2.fromOffset(44, 44)
	close.Text = "×"
	close.TextColor3 = Color3.fromRGB(255, 246, 224)
	close.TextSize = 32
	close.FontFace = Font.fromEnum(Enum.Font.Garamond)
	close.ZIndex = 12
	close.Parent = win.canvas
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = close
	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = Color3.fromRGB(105, 61, 43)
	closeStroke.Thickness = 2
	closeStroke.Parent = close
	close.Activated:Connect(context.close)

	refs.power = paperText(win.canvas, "", 30, Color3.fromRGB(54, 91, 72), {
		Position = UDim2.fromOffset(484, 146), Size = UDim2.fromOffset(632, 38),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5,
	})
	refs.powerDelta = paperText(win.canvas, "", 17, Color3.fromRGB(68, 126, 84), {
		Position = UDim2.fromOffset(484, 180), Size = UDim2.fromOffset(632, 26),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5,
	})

	local equip = Instance.new("Frame")
	equip.BackgroundTransparency = 1
	equip.Size = UDim2.fromScale(1, 1)
	equip.ZIndex = 3
	equip.Parent = win.canvas
	refs.equip = equip

	local left = paperPanel(win.canvas, UDim2.fromOffset(24, 144), UDim2.fromOffset(456, 728), 4)
	PixelUi.slideIn(left, -1, 0)
	refs.tabs = {}
	for i, tab in ipairs(TABS) do
		local column = (i - 1) % 3
		local row = (i - 1) // 3
		local button = paperButton(left, UDim2.fromOffset(12 + column * 142, 12 + row * 48),
			UDim2.fromOffset(136, 44), tab[1], function()
			refs.selectTab(i)
			renderGrid()
			renderDetail()
		end, { banner = true, active = i == 1, textSize = 16, z = 6 })
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(54, 132, 91)
		stroke.Thickness = 2
		stroke.Enabled = i == 1
		stroke.Parent = button.holder
		refs.tabs[i] = { face = button.face, label = button.label, stroke = stroke }
	end
	-- Переключить вкладку (кнопки вкладок и клик по слоту брони).
	refs.selectTab = function(i)
		for k, entry in ipairs(refs.tabs) do
			entry.face.ImageColor3 = k == i and Color3.new(1, 1, 1) or Color3.fromRGB(195, 184, 162)
			entry.label.TextColor3 = k == i and Color3.fromRGB(35, 101, 78) or Color3.fromRGB(66, 48, 32)
			entry.stroke.Enabled = k == i
		end
		state.tab = i
		state.selected = 1
	end
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "ItemGrid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(20, 112)
	grid.Size = UDim2.fromOffset(416, 596)
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = Color3.fromRGB(83, 135, 105)
	grid.ZIndex = 5
	grid.Parent = left
	refs.grid = grid

	local right = paperPanel(win.canvas, UDim2.fromOffset(1176, 144), UDim2.fromOffset(400, 728), 4)
	PixelUi.slideIn(right, 1, 0.05)
	local detail = Instance.new("Frame")
	detail.BackgroundTransparency = 1
	detail.Size = UDim2.fromScale(1, 1)
	detail.ZIndex = 5
	detail.Parent = right
	refs.detail = detail

	renderGrid()
	renderDetail()
	renderEquip()
	if state.data then
		UiFx.countUp(refs.power, 0, state.data.power or 0, 0.6, "СИЛА %d")
	end
	return win
end

function InventoryWindow.close()
	if win then
		win:destroy()
		win = nil
	end
end

return InventoryWindow
