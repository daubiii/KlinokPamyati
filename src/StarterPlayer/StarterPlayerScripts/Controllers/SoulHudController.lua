--!nonstrict
-- SoulHudController (клиент) — души в бою.
-- Блок душ в нижней связке HUD (справа от HP, рывка и фляги) и их анимации:
--   • души мобов (стаки забега): крупный шар с заполнением, «ДУШИ 27/40»,
--     бонус «+27% урона» и строка «+16% атаки · +10% бега»; наведение мыши
--     (ПК) или касание (телефон) открывает разбор: откуда растёт урон;
--   • души боссов: два гнезда над блоком — активная [2] с перезарядкой и
--     пассивная; пустое гнездо тусклое, подпись «победи босса этажа»;
--   • выпадение и поглощение: огонёк вылетает из павшего врага, взлетает,
--     по дуге летит в героя, вспышка поглощения, затем огонёк летит в шар
--     на экране, шар подпрыгивает, «+1», бонус урона вспыхивает белым;
--     душа босса крупнее, цвета редкости, зависает над телом и летит в своё
--     гнездо; при смерти и в конце забега души развеиваются из шара.
-- Данные: атрибуты игрока SoulStacks, SoulStacksMax, SoulDmgTalent, SoulDmgMult
-- (ProgressionService.publish), SoulActive, SoulPassive (AbilityService);
-- событие SoulReceived {name, rarity}; у врагов — EnemyHealth / EnemyType.
-- Опора в HUD — PixelHudController.anchors() (раскладка v3).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Binds = require(Shared.Config.Binds)
local Progression = require(Shared.Config.Progression)
local UiAssets = require(Shared.Config.UiAssets)
local Net = require(Shared.Net.Net)

local Lib = script.Parent.Parent.Lib
local PixelUi = require(Lib.PixelUi)
local UiSound = require(Lib.UiSound)
local AbilityController = require(script.Parent.AbilityController)
local PixelHudController = require(script.Parent.PixelHudController)
local TouchControls = require(script.Parent.TouchControls)

local SoulHudController = {}

local player = Players.LocalPlayer
local C = UiAssets.Colors
local SOUL = C.mem
local GOLD = C.gold
local LOSS = C.red or Color3.fromRGB(229, 72, 77)
local MAX_ORBS = 6 -- огоньков от одной пачки убийств (остальное — числом «+N»)
local MAX_FLYING = 12 -- огоньков в полёте одновременно; сверх — просто обновляем шар

-- Каталог душ боссов (Loot.BossSouls) и иконки гнёзд из атласа HUD.
local SOULS = {}
do
	local ok, Loot = pcall(require, Shared.Config.Loot)
	if ok and type(Loot) == "table" and type(Loot.BossSouls) == "table" then
		for key, soul in pairs(Loot.BossSouls) do
			if type(soul) == "table" then
				local id = soul.id or (type(key) == "string" and key) or nil
				if id then
					SOULS[id] = soul
				end
			end
		end
	end
end
local SOUL_ICON = { guard_verdict = "verdict", gate_barrier = "barrier", rusty_stance = "helm" }

local ui: any = {}
local state = { stacks = nil, hover = false, pinned = false, pinnedAt = 0, flying = 0 }
local recent = {} -- недавние гибели врагов (новые — первыми): { pos, t }
local tracked = setmetatable({}, { __mode = "k" })

local function keyName(action: string): string
	local ok, binding = pcall(Binds.get, action)
	if ok and typeof(binding) == "EnumItem" and binding.EnumType == Enum.KeyCode then
		local names = { One = "1", Two = "2", Three = "3", Four = "4" }
		return names[binding.Name] or binding.Name
	end
	return "2"
end

local function pct(value: number): number
	return math.floor(value * 100 + 0.5)
end

local function rootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- Те же формулы, что в MeleeService: (стаки + «Сила душ») × «Голод душ».
local function bonuses()
	local stacks = player:GetAttribute("SoulStacks") or 0
	local baseMax = Progression.maxStacks(0)
	local max = player:GetAttribute("SoulStacksMax") or baseMax
	local capBonus = math.max(max - baseMax, 0)
	local base = Progression.stackBonuses(stacks, capBonus) or {}
	local talent = player:GetAttribute("SoulDmgTalent") or 0
	local mult = player:GetAttribute("SoulDmgMult") or 1
	return {
		stacks = stacks,
		max = max,
		capBonus = capBonus,
		base = base.damage or 0,
		talent = talent,
		mult = mult,
		damage = ((base.damage or 0) + talent) * mult,
		attackSpeed = base.attackSpeed or 0,
		moveSpeed = base.moveSpeed or 0,
	}
end

-- ===== разбор урона =====

local function refreshPanel(b)
	if not ui.panel or not ui.panel.Visible then
		return
	end
	b = b or bonuses()
	local one = Progression.stackBonuses(1, b.capBonus) or {}
	local lines = {
		("Души мобов: %d из %d"):format(b.stacks, b.max),
		("Урон от душ: +%d%% (по %.1f%% за душу)"):format(pct(b.base), (one.damage or 0) * 100),
	}
	if b.talent > 0.0005 then
		table.insert(lines, ("Сила душ (древо): +%d%%"):format(pct(b.talent)))
	end
	if math.abs(b.mult - 1) > 0.001 then
		table.insert(lines, ("Голод душ (дар этажа): x%.2f"):format(b.mult))
	end
	table.insert(lines, ("Итого к урону: +%d%%"):format(pct(b.damage)))
	table.insert(lines, ("Скорость атаки +%d%%, бег +%d%%"):format(pct(b.attackSpeed), pct(b.moveSpeed)))
	if b.capBonus > 0 then
		table.insert(lines, ("Предел душ +%d (Прилив душ)"):format(b.capBonus))
	end
	table.insert(lines, "Сгорают при смерти и в конце забега")
	local active = SOULS[player:GetAttribute("SoulActive") or ""]
	local passive = SOULS[player:GetAttribute("SoulPassive") or ""]
	table.insert(lines, active and ("Душа босса [%s]: %s"):format(keyName("Ability2"), tostring(active.name)) or "Активная душа босса: пусто")
	table.insert(lines, passive and ("Пассивная: %s"):format(tostring(passive.name)) or "Пассивная душа босса: пусто")
	for index, label in ipairs(ui.lines) do
		label.Text = lines[index] or ""
	end
	ui.panel.Size = UDim2.fromOffset(320, 20 + #lines * 18)
end

local function setPanel(visible: boolean)
	if not ui.panel or ui.panel.Visible == visible then
		return
	end
	ui.panel.Visible = visible
	if visible then
		refreshPanel()
		PixelUi.pop(ui.panel)
	end
end

-- ===== построение блока =====

local function socket(parent, x: number, key)
	local slot = PixelUi.slot(parent, UDim2.fromOffset(x, 0), 48, nil, { z = 5 })
	slot:setIcon("soul")
	if slot.icon then
		slot.icon.ImageTransparency = 0.7
	end
	local shade = Instance.new("Frame")
	shade.Name = "Cooldown"
	shade.BorderSizePixel = 0
	shade.BackgroundColor3 = Color3.fromRGB(10, 6, 4)
	shade.BackgroundTransparency = 0.35
	shade.AnchorPoint = Vector2.new(0, 1)
	shade.Position = UDim2.new(0, 6, 1, -6)
	shade.Size = UDim2.new(1, -12, 0, 0)
	shade.ZIndex = 9
	shade.Parent = slot.holder
	local count = PixelUi.label(slot.holder, "", 16, C.bone, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 10,
	})
	if key then
		local tag = PixelUi.piece(slot.holder, "parchClean", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 5, 1, 5),
			Size = UDim2.fromOffset(22, 20),
			ZIndex = 11,
		})
		PixelUi.text(tag, key, 12, C.ink, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 12,
		})
	end
	return { slot = slot, shade = shade, count = count, id = false }
end

local function build(anchors)
	local block = Instance.new("Frame")
	block.Name = "Souls"
	block.BackgroundTransparency = 1
	block.Size = UDim2.fromScale(1, 1)
	block.ZIndex = 20
	block.Parent = anchors.souls
	ui.block = block

	-- шар душ мобов: заполнение снизу вверх = стаки / предел, аура растёт со стаками
	local orb = PixelUi.slot(block, UDim2.fromOffset(0, 4), 64, "secret", { z = 5 })
	orb:setIcon("soul")
	ui.orb = orb
	ui.aura = PixelUi.glow(orb.holder, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(104, 104), SOUL, 1)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = SOUL
	fill.BackgroundTransparency = 0.5
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.new(0, 8, 1, -8)
	fill.Size = UDim2.new(1, -16, 0, 0)
	fill.ZIndex = 5
	fill.Parent = orb.holder
	ui.fill = fill
	ui.count = PixelUi.label(orb.holder, "0", 24, C.bone, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.fromOffset(64, 28),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 12,
	})
	ui.maxTag = PixelUi.label(orb.holder, "МАКС", 12, GOLD, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(64, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 12,
	})
	ui.title = PixelUi.label(block, "ДУШИ 0/40", 16, SOUL, {
		Position = UDim2.fromOffset(74, 0),
		Size = UDim2.fromOffset(176, 20),
	})
	ui.damage = PixelUi.label(block, "+0% урона", 24, GOLD, {
		Position = UDim2.fromOffset(74, 20),
		Size = UDim2.fromOffset(176, 28),
	})
	ui.extra = PixelUi.label(block, "", 12, C.bone, {
		Position = UDim2.fromOffset(74, 50),
		Size = UDim2.fromOffset(176, 16),
	})

	-- души боссов: активная [2] (перезарядка — слот 2 AbilityController) и пассивная
	local bossRow = Instance.new("Frame")
	bossRow.Name = "BossSouls"
	bossRow.BackgroundTransparency = 1
	bossRow.Position = UDim2.fromOffset(0, -60)
	bossRow.Size = UDim2.fromOffset(250, 48)
	bossRow.Parent = block
	ui.active = socket(bossRow, 8, keyName("Ability2"))
	ui.passive = socket(bossRow, 64, nil)
	PixelUi.label(bossRow, "ДУШИ БОССОВ", 12, SOUL, {
		Position = UDim2.fromOffset(122, 4),
		Size = UDim2.fromOffset(128, 16),
	})
	ui.bossName = PixelUi.label(bossRow, "", 12, C.bone, {
		Position = UDim2.fromOffset(122, 24),
		Size = UDim2.fromOffset(128, 16),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	-- разбор урона: над блоком, по наведению (ПК) или касанию (телефон)
	local panel = PixelUi.piece(block, "parchClean", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(-20, -66),
		Size = UDim2.fromOffset(320, 200),
		ZIndex = 30,
		Visible = false,
	})
	ui.panel = panel
	ui.lines = {}
	for index = 1, 11 do
		ui.lines[index] = PixelUi.text(panel, "", 14, C.ink, {
			Position = UDim2.fromOffset(16, 10 + (index - 1) * 18),
			Size = UDim2.fromOffset(290, 18),
			ZIndex = 31,
		})
	end

	local hit = Instance.new("TextButton")
	hit.Name = "SoulsInfo"
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.Position = UDim2.fromOffset(0, -60)
	hit.Size = UDim2.new(1, 0, 1, 60)
	hit.ZIndex = 25
	hit.Parent = block
	hit.MouseEnter:Connect(function()
		if not TouchControls.isTouch() then
			state.hover = true
			setPanel(true)
		end
	end)
	hit.MouseLeave:Connect(function()
		state.hover = false
		setPanel(state.pinned)
	end)
	hit.Activated:Connect(function()
		state.pinned = not state.pinned
		state.pinnedAt = os.clock()
		setPanel(state.pinned or state.hover)
	end)
end

local function refresh()
	if not ui.block then
		return
	end
	local b = bonuses()
	ui.count.Text = tostring(b.stacks)
	ui.title.Text = ("ДУШИ %d/%d"):format(b.stacks, b.max)
	ui.damage.Text = ("+%d%% урона"):format(pct(b.damage))
	ui.damage.TextTransparency = b.stacks > 0 and 0 or 0.4
	if b.stacks > 0 then
		ui.extra.Text = ("+%d%% атаки · +%d%% бега"):format(pct(b.attackSpeed), pct(b.moveSpeed))
	else
		ui.extra.Text = "души павших усилят удар"
	end
	local ratio = b.max > 0 and math.clamp(b.stacks / b.max, 0, 1) or 0
	TweenService:Create(ui.fill, TweenInfo.new(0.25), { Size = UDim2.new(1, -16, ratio, -16 * ratio) }):Play()
	local full = b.max > 0 and b.stacks >= b.max
	ui.maxTag.Visible = full
	ui.aura.ImageColor3 = full and GOLD or SOUL
	ui.aura.ImageTransparency = b.stacks > 0 and (0.75 - 0.45 * ratio) or 1
	refreshPanel(b)
end

local function setSocket(entry, id: string)
	if entry.id == id then
		return
	end
	entry.id = id
	local soul = SOULS[id]
	entry.slot:setIcon(soul and (SOUL_ICON[id] or "soul") or "soul")
	entry.slot:setRarity(soul and soul.rarity or nil)
	if entry.slot.icon then
		entry.slot.icon.ImageTransparency = soul and 0 or 0.7
	end
end

local function updateSockets()
	if not ui.active then
		return
	end
	local activeId = player:GetAttribute("SoulActive") or ""
	local passiveId = player:GetAttribute("SoulPassive") or ""
	setSocket(ui.active, activeId)
	setSocket(ui.passive, passiveId)
	local info = activeId ~= "" and AbilityController.info(2) or nil
	local left = info and info.left or 0
	if left > 0.05 then
		local ratio = math.clamp(left / math.max(info.length or 1, 0.1), 0, 1)
		ui.active.shade.Size = UDim2.new(1, -12, ratio, -12 * ratio)
		ui.active.count.Text = left >= 10 and tostring(math.ceil(left)) or ("%.1f"):format(left)
	else
		ui.active.shade.Size = UDim2.new(1, -12, 0, 0)
		ui.active.count.Text = ""
	end
	local shown = SOULS[activeId] or SOULS[passiveId]
	ui.bossName.Text = shown and tostring(shown.name) or "победи босса этажа"
	ui.bossName.TextColor3 = shown and (UiAssets.Rarity[shown.rarity] or C.bone) or C.grey
end

-- ===== эффекты =====

local fxFolder = nil
local fxGui = nil

local function worldFolder()
	if not fxFolder or not fxFolder.Parent then
		local folder = Instance.new("Folder")
		folder.Name = "KlinokSoulFx"
		folder.Parent = Workspace.CurrentCamera or Workspace
		fxFolder = folder
	end
	return fxFolder
end

local function screenFx()
	if not fxGui or not fxGui.Parent then
		local gui = Instance.new("ScreenGui")
		gui.Name = "KlinokSoulFx"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 7
		gui.Parent = player:WaitForChild("PlayerGui")
		fxGui = gui
	end
	return fxGui
end

-- Во сколько раз HUD сейчас крупнее макета (UIScale корня × связки на телефоне).
local function hudScale(): number
	local anchors = ui.anchors
	local rootScale = anchors and anchors.root and anchors.root:FindFirstChildOfClass("UIScale")
	local vitalsScale = anchors and anchors.vitals and anchors.vitals:FindFirstChildOfClass("UIScale")
	return (rootScale and rootScale.Scale or 1) * (vitalsScale and vitalsScale.Scale or 1)
end

local function floatText(at: Vector2, text: string, color: Color3, size: number)
	local s = hudScale()
	local label = PixelUi.label(screenFx(), text, math.max(math.floor(size * s / 8 + 0.5) * 8, 16), color, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(at.X, at.Y - 28 * s),
		Size = UDim2.fromOffset(440, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 8,
	})
	local stroke = label:FindFirstChildOfClass("UIStroke")
	PixelUi.tween(label, 0.9, { Position = UDim2.fromOffset(at.X, at.Y - 84 * s), TextTransparency = 1 })
	if stroke then
		PixelUi.tween(stroke, 0.9, { Transparency = 1 })
	end
	task.delay(0.95, function()
		label:Destroy()
	end)
end

-- Огонёк долетел до шара (или гнезда души босса).
local function arrive(target, amount: number, soul, at: Vector2)
	refresh()
	updateSockets()
	PixelUi.pop(target)
	local color = soul and (UiAssets.Rarity[soul.rarity] or SOUL) or SOUL
	local flash = PixelUi.glow(target, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(80, 80), color, 0.15)
	flash.ZIndex = 20
	PixelUi.tween(flash, 0.4, { ImageTransparency = 1, Size = UDim2.fromOffset(150, 150) })
	task.delay(0.45, function()
		flash:Destroy()
	end)
	if soul then
		floatText(at, "ДУША БОССА: " .. tostring(soul.name or ""), color, 24)
		pcall(UiSound.play, "medal", { volume = 0.7 })
	else
		floatText(at, "+" .. tostring(amount), SOUL, 24)
		-- вспыхивает именно бонус урона: видно, что растёт он
		ui.damage.TextColor3 = Color3.new(1, 1, 1)
		PixelUi.tween(ui.damage, 0.4, { TextColor3 = GOLD })
		local stacks = player:GetAttribute("SoulStacks") or 0
		local max = player:GetAttribute("SoulStacksMax") or 40
		local pitch = 0.9 + 0.5 * math.clamp(stacks / math.max(max, 1), 0, 1)
		pcall(UiSound.play, "echo_socket", { volume = 0.3, pitch = pitch })
	end
end

-- Второй этап: огонёк с экранной точки героя летит по дуге в шар HUD.
local function flyScreen(worldPos: Vector3, amount: number, soul)
	local camera = Workspace.CurrentCamera
	if not camera or not ui.orb then
		refresh()
		return
	end
	local target = ui.orb.holder
	if soul then
		target = (soul.kind == "passive" and ui.passive or ui.active).slot.holder
	end
	local to = target.AbsolutePosition + target.AbsoluteSize / 2
	local point, onScreen = camera:WorldToViewportPoint(worldPos)
	local from = onScreen and Vector2.new(point.X, point.Y) or camera.ViewportSize / 2
	local s = hudScale()
	local size = (soul and 60 or 36) * s
	local color = soul and (UiAssets.Rarity[soul.rarity] or SOUL) or SOUL
	local gui = screenFx()
	local glow = PixelUi.glow(gui, UDim2.fromOffset(from.X, from.Y), UDim2.fromOffset(size * 2.4, size * 2.4), color, 0.35)
	local dot = PixelUi.icon(gui, "soul", UDim2.fromOffset(from.X, from.Y), size, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 5,
	})
	if soul then
		dot.ImageColor3 = color
	end
	local bend = Vector2.new((from.X - to.X) * 0.25, -math.abs(to.X - from.X) * 0.2 - 90 * s)
	local control = (from + to) / 2 + bend
	local duration = soul and 0.8 or 0.5
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - start) / duration, 0, 1)
		local e = k < 0.5 and 2 * k * k or 1 - ((-2 * k + 2) ^ 2) / 2
		local u = 1 - e
		local p = from * (u * u) + control * (2 * u * e) + to * (e * e)
		local grow = 1 - 0.3 * e
		dot.Position = UDim2.fromOffset(p.X, p.Y)
		dot.Size = UDim2.fromOffset(size * grow, size * grow)
		glow.Position = dot.Position
		if k >= 1 then
			connection:Disconnect()
			dot:Destroy()
			glow:Destroy()
			arrive(target, amount, soul, to)
		end
	end)
end

-- Вспышка поглощения вокруг героя.
local function absorbFlash(root, color: Color3, boss: boolean)
	local ring = Instance.new("Part")
	ring.Name = "SoulAbsorb"
	ring.Shape = Enum.PartType.Ball
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Transparency = 0.45
	ring.Size = Vector3.one * 1.2
	ring.CFrame = root.CFrame
	ring.Parent = worldFolder()
	local time = boss and 0.5 or 0.26
	TweenService:Create(ring, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * (boss and 10 or 5.5),
		Transparency = 1,
	}):Play()
	task.delay(time + 0.05, function()
		ring:Destroy()
	end)
	if boss then
		pcall(UiSound.play, "star_on", { volume = 0.6, pitch = 0.8 })
	end
end

local function makeOrb(color: Color3, size: number)
	local part = Instance.new("Part")
	part.Name = "Soul"
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.one * size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 0.1
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = size * 10
	light.Brightness = 1.6
	light.Parent = part
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, size * 0.35, 0)
	top.Parent = part
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -size * 0.35, 0)
	bottom.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.3
	trail.MinLength = 0
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = part
	part.Parent = worldFolder()
	return part
end

-- Первый этап: огонёк вылетает из тела врага, взлетает и по дуге летит в героя.
local function flyWorld(from: Vector3, amount: number, soul)
	local root = rootPart()
	if not root then
		refresh()
		return
	end
	state.flying += 1
	local boss = soul ~= nil
	local color = boss and (UiAssets.Rarity[soul.rarity] or SOUL) or SOUL
	local orb = makeOrb(color, boss and 1.5 or 0.7)
	local riseTime = boss and 1.1 or 0.3
	local flyTime = boss and 0.65 or 0.42
	local top = from + Vector3.new(0, boss and 5 or 2.4, 0)
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local alive = root.Parent ~= nil
		local target = alive and root.Position or top
		if t < riseTime then
			local k = t / riseTime
			local eased = 1 - (1 - k) * (1 - k)
			local spin = boss and Vector3.new(math.sin(t * 8) * 0.4, 0, math.cos(t * 8) * 0.4) or Vector3.zero
			orb.CFrame = CFrame.new(from:Lerp(top, eased) + spin)
			if boss then
				orb.Size = Vector3.one * (1.5 + 0.3 * math.sin(t * 14))
			end
			return
		end
		local k = math.clamp((t - riseTime) / flyTime, 0, 1)
		local eased = k * k
		local mid = (top + target) / 2 + Vector3.new(0, boss and 6 or 3, 0)
		local u = 1 - eased
		orb.CFrame = CFrame.new(top * (u * u) + mid * (2 * u * eased) + target * (eased * eased))
		if k >= 1 then
			connection:Disconnect()
			orb:Destroy()
			state.flying -= 1
			if alive then
				absorbFlash(root, color, boss)
				flyScreen(root.Position, amount, soul)
			else
				refresh()
			end
		end
	end)
end

-- Недавние гибели рядом с героем (ближние — первыми). keep = не забирать из списка.
local function takeOrigins(count: number, maxAge: number, keep: boolean)
	local root = rootPart()
	local now = os.clock()
	local candidates = {}
	for index, death in ipairs(recent) do
		if now - death.t <= maxAge then
			local distance = root and (death.pos - root.Position).Magnitude or 0
			if distance < 150 then
				table.insert(candidates, { index = index, pos = death.pos, distance = distance })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	local out, used = {}, {}
	for _, candidate in ipairs(candidates) do
		if #out >= count then
			break
		end
		table.insert(out, candidate.pos)
		used[candidate.index] = true
	end
	if not keep then
		for index = #recent, 1, -1 do
			if used[index] then
				table.remove(recent, index)
			end
		end
	end
	return out
end

local function onGain(gained: number)
	local root = rootPart()
	if not root or state.flying >= MAX_FLYING then
		refresh()
		if ui.orb then
			PixelUi.pop(ui.orb.holder)
		end
		return
	end
	local origins = takeOrigins(math.min(gained, MAX_ORBS), 2.5, false)
	if #origins == 0 then
		table.insert(origins, root.Position + root.CFrame.LookVector * 6)
	end
	local per = math.max(math.floor(gained / #origins), 1)
	for index, origin in ipairs(origins) do
		local amount = index == #origins and math.max(gained - per * (#origins - 1), 1) or per
		task.delay((index - 1) * 0.08, flyWorld, origin, amount, nil)
	end
	-- страховка: если огонёк не долетел (смерть, телепорт), числа всё равно обновятся
	task.delay(2, refresh)
end

local function onLoss(lost: number, left: number)
	refresh()
	if not ui.orb then
		return
	end
	local holder = ui.orb.holder
	local at = holder.AbsolutePosition + holder.AbsoluteSize / 2
	local s = hudScale()
	floatText(at, "-" .. tostring(lost), LOSS, 24)
	if left == 0 then
		task.delay(0.15, floatText, at + Vector2.new(0, -30 * s), "души развеялись", LOSS, 16)
	end
	local flash = PixelUi.glow(holder, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(90, 90), LOSS, 0.2)
	flash.ZIndex = 20
	PixelUi.tween(flash, 0.5, { ImageTransparency = 1, Size = UDim2.fromOffset(170, 170) })
	task.delay(0.55, function()
		flash:Destroy()
	end)
	PixelUi.nudge(holder)
	local gui = screenFx()
	local pieces = math.clamp(lost, 3, 8)
	for index = 1, pieces do
		local angle = index / pieces * math.pi * 2 + math.random() * 0.4
		local dot = PixelUi.icon(gui, "soul", UDim2.fromOffset(at.X, at.Y), 22 * s, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 5,
		})
		local distance = (60 + math.random() * 40) * s
		PixelUi.tween(dot, 0.6, {
			Position = UDim2.fromOffset(at.X + math.cos(angle) * distance, at.Y + math.sin(angle) * distance - 30 * s),
			ImageTransparency = 1,
		})
		task.delay(0.65, function()
			dot:Destroy()
		end)
	end
end

local function soulByName(name)
	for _, soul in pairs(SOULS) do
		if soul.name == name then
			return soul
		end
	end
	return nil
end

local function onBossSoul(payload)
	if type(payload) ~= "table" then
		return
	end
	local soul = soulByName(payload.name) or {
		name = tostring(payload.name or "душа"),
		rarity = payload.rarity or "common",
		kind = "active",
	}
	local root = rootPart()
	if not root then
		updateSockets()
		return
	end
	local origins = takeOrigins(1, 5, true)
	flyWorld(origins[1] or (root.Position + root.CFrame.LookVector * 8), 1, soul)
end

-- ===== враги: где погиб последний =====

local function isEnemy(model): boolean
	return model:GetAttribute("EnemyMaxHealth") ~= nil or model:GetAttribute("EnemyType") ~= nil
end

local function pushDeath(model)
	local ok, pivot = pcall(function()
		return model:GetPivot()
	end)
	if not ok or typeof(pivot) ~= "CFrame" then
		return
	end
	table.insert(recent, 1, { pos = pivot.Position, t = os.clock() })
	if #recent > 24 then
		table.remove(recent)
	end
end

local function track(model)
	if tracked[model] then
		return
	end
	tracked[model] = true
	local dead = false
	local function mark()
		if not dead then
			dead = true
			pushDeath(model)
		end
	end
	model:GetAttributeChangedSignal("EnemyHealth"):Connect(function()
		local health = model:GetAttribute("EnemyHealth")
		if type(health) == "number" then
			if health <= 0 then
				mark()
			else
				dead = false -- модель снова в деле (пул врагов)
			end
		end
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			mark()
		end
	end)
end

local function consider(instance)
	if not instance.Parent or tracked[instance] then
		return
	end
	if isEnemy(instance) then
		track(instance)
		return
	end
	-- атрибуты могут прийти чуть позже самой модели
	task.delay(0.6, function()
		if instance.Parent and not tracked[instance] and isEnemy(instance) then
			track(instance)
		end
	end)
end

local function connect()
	player:GetAttributeChangedSignal("SoulStacks"):Connect(function()
		local stacks = player:GetAttribute("SoulStacks") or 0
		local previous = state.stacks or stacks
		state.stacks = stacks
		if stacks > previous then
			onGain(stacks - previous)
		elseif stacks < previous then
			onLoss(previous - stacks, stacks)
		else
			refresh()
		end
	end)
	for _, name in ipairs({ "SoulStacksMax", "SoulDmgTalent", "SoulDmgMult", "SoulActive", "SoulPassive" }) do
		player:GetAttributeChangedSignal(name):Connect(function()
			refresh()
			updateSockets()
		end)
	end
	task.spawn(function()
		local ok, remote = pcall(Net.get, "SoulReceived")
		if ok and remote then
			remote.OnClientEvent:Connect(onBossSoul)
		else
			warn("[SoulHudController] нет события SoulReceived — анимация души босса выключена")
		end
	end)
	Workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("Model") then
			task.defer(consider, instance)
		end
	end)
	task.spawn(function()
		for index, instance in ipairs(Workspace:GetDescendants()) do
			if instance:IsA("Model") then
				consider(instance)
			end
			if index % 4000 == 0 then
				task.wait()
			end
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / 15 then
			return
		end
		elapsed = 0
		updateSockets()
		if state.pinned and os.clock() - state.pinnedAt > 8 then
			state.pinned = false
			setPanel(state.hover)
		end
	end)
end

function SoulHudController.start()
	task.spawn(function()
		local anchors = nil
		for _ = 1, 150 do
			anchors = PixelHudController.anchors and PixelHudController.anchors()
			if anchors then
				break
			end
			task.wait(0.1)
		end
		if not anchors then
			warn("[SoulHudController] нет опоры в HUD — блок душ не построен")
			return
		end
		ui.anchors = anchors
		build(anchors)
		state.stacks = player:GetAttribute("SoulStacks") or 0
		refresh()
		updateSockets()
		connect()
	end)
end

return SoulHudController
