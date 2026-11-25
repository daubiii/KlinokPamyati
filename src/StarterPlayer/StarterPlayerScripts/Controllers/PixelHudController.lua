--!nonstrict
-- PixelHudController (клиент)
-- v3 (обновление интерфейса): низ по центру — оружие (портрет), HP с опытом,
--   рывок (Q), фляга (F) и блок душ (SoulHudController); слева снизу —
--   способность оружия (1), предмет (G), умение класса (3); на телефоне
--   рывок, фляга, способности и предмет — на сенсорных кнопках. Раскладку
--   ведёт relayout() ниже. Описание v2 оставлено для истории:
-- Боевой HUD v2 (замена HudController):
--   низ по центру — портрет с уровнем, крупная полоса HP, тонкая полоса опыта, души;
--   левый нижний угол — рывок (Q), способности (1, 2), фляга (F);
--   слева сверху — оружие и текущее задание; справа сверху — кошелёк;
--   сверху по центру — ленты-уведомления; над полосой — «КОНТРУДАР!» и серия.
-- ЛКМ/ПКМ на экране нет — они и так понятны.
-- Данные — атрибуты игрока (их выставляет сервер), как в старом HUD.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Binds = require(Shared.Config.Binds)
local Combat = require(Shared.Config.Combat)
local Rarities = require(Shared.Config.Rarities)
local Weapons = require(Shared.Config.Weapons)
local UiAssets = require(Shared.Config.UiAssets)

local Lib = script.Parent.Parent.Lib
local Bus = require(Lib.Bus)
local PixelUi = require(Lib.PixelUi)
local UiFx = require(Lib.UiFx)
local UiSound = require(Lib.UiSound)
local ChestVisual = require(Lib.ChestVisual)
local AbilityController = require(script.Parent.AbilityController)
local TouchControls = require(script.Parent.TouchControls)

local PixelHudController = {}

local player = Players.LocalPlayer
local C = UiAssets.Colors
local ui: any = {}

local BAR_W = 520 -- полоса HP на ПК (v3: справа от неё рывок, фляга и блок душ)
local BAR_W_TOUCH = 300 -- на телефоне рывок и фляга — на сенсорных кнопках, полоса короче
local SOULS_W = 250 -- блок душ (SoulHudController): шар 64 + подписи

-- Ширина нижней связки: оружие 64 | HP | рывок 64 + фляга 64 (не на телефоне) | души.
local function vitalsWidth(touch)
	local bar = touch and BAR_W_TOUCH or BAR_W
	return 64 + 10 + bar + (touch and 14 or (10 + 64 + 8 + 64 + 14)) + SOULS_W
end

local function keyName(action: string): string
	local binding = Binds.get(action)
	if typeof(binding) == "EnumItem" and binding.EnumType == Enum.KeyCode then
		local names = { One = "1", Two = "2", Three = "3", Four = "4" }
		return names[binding.Name] or binding.Name
	end
	return "?"
end

-- Ячейка способности: слот 64, иконка, затемнение перезарядки, цифра, табличка клавиши.
local function abilitySlot(parent, x: number, iconName: string, key: string)
	local slot = PixelUi.slot(parent, UDim2.fromOffset(x, 0), 64, nil, { z = 5 })
	slot:setIcon(iconName)
	local shade = Instance.new("Frame")
	shade.BorderSizePixel = 0
	shade.BackgroundColor3 = Color3.fromRGB(10, 6, 4)
	shade.BackgroundTransparency = 0.35
	shade.AnchorPoint = Vector2.new(0, 1)
	shade.Position = UDim2.new(0, 8, 1, -8)
	shade.Size = UDim2.new(1, -16, 0, 0)
	shade.ZIndex = 9
	shade.Parent = slot.holder
	local count = PixelUi.label(slot.holder, "", 16, C.bone, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 10,
	})
	local tag = PixelUi.piece(slot.holder, "parchClean", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 6, 1, 6),
		Size = UDim2.fromOffset(math.max(28, #key * 16 + 12), 26),
		ZIndex = 11,
	})
	PixelUi.text(tag, key, 16, C.ink, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 12 })
	local stack = PixelUi.label(slot.holder, "", 16, C.bone, { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(60, 20), ZIndex = 11 })
	return { slot = slot, shade = shade, count = count, stack = stack, icon = iconName, ready = true }
end

local function build()
	local gui, root = PixelUi.screen("KlinokHud", 2)
	ui.gui = gui
	ui.root = root

	-- Красные края при уроне.
	ui.edges = {}
	for _, spec in ipairs({
		{ UDim2.new(1, 0, 0, 160), UDim2.fromOffset(0, 0), 90 },
		{ UDim2.new(1, 0, 0, 160), UDim2.new(0, 0, 1, -160), 270 },
		{ UDim2.new(0, 220, 1, 0), UDim2.fromOffset(0, 0), 0 },
		{ UDim2.new(0, 220, 1, 0), UDim2.new(1, -220, 0, 0), 180 },
	}) do
		local edge = Instance.new("Frame")
		edge.BorderSizePixel = 0
		edge.Size = spec[1]
		edge.Position = spec[2]
		edge.BackgroundColor3 = C.hp
		edge.BackgroundTransparency = 1
		edge.Parent = root
		local g = Instance.new("UIGradient")
		g.Rotation = spec[3]
		g.Transparency = NumberSequence.new(0, 1)
		g.Parent = edge
		table.insert(ui.edges, edge)
	end

	-- ===== низ по центру =====
	local bottom = Instance.new("Frame")
	bottom.Name = "Vitals"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -18)
	bottom.Size = UDim2.fromOffset(64 + 10 + BAR_W + 10 + 64, 70)
	bottom.Parent = root
	ui.bottom = bottom

	local portrait = PixelUi.slot(bottom, UDim2.fromOffset(0, 4), 64, nil, { z = 5 })
	portrait:setIcon("helm")
	ui.portrait = portrait
	local lvl = PixelUi.piece(portrait.holder, "parchClean", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(44, 26),
		ZIndex = 12,
	})
	ui.level = PixelUi.text(lvl, "1", 16, C.ink, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13 })

	ui.hp = PixelUi.bar(bottom, UDim2.fromOffset(74, 4), UDim2.fromOffset(BAR_W, 44), C.hp, { inset = 10, textSize = 16 })
	-- деления по 10%
	for k = 1, 9 do
		local tick = Instance.new("Frame")
		tick.BorderSizePixel = 0
		tick.BackgroundColor3 = Color3.fromRGB(60, 14, 12)
		tick.BackgroundTransparency = 0.3
		tick.Position = UDim2.new(k / 10, 0, 0, 0)
		tick.Size = UDim2.new(0, 2, 1, 0)
		tick.ZIndex = ui.hp.fill.ZIndex + 1
		tick.Parent = ui.hp.fill.Parent
	end
	local xpBack, xpFill = PixelUi.progress(bottom, UDim2.fromOffset(78, 54), UDim2.fromOffset(BAR_W - 8, 10), 0, C.xp)
	ui.xp = xpFill
	ui.xpBack = xpBack

	-- Мана мага: под HP, над опытом. Видна только у класса с маной (MaxMana > 0).
	ui.mana = PixelUi.bar(bottom, UDim2.fromOffset(74, 50), UDim2.fromOffset(BAR_W, 30), C.mana, { inset = 7, textSize = 12 })
	ui.mana.holder.Visible = false
	-- блик, бегущий по полосе при восстановлении
	local glint = Instance.new("Frame")
	glint.Name = "ManaGlint"
	glint.BorderSizePixel = 0
	glint.BackgroundColor3 = C.manaLight
	glint.BackgroundTransparency = 0.55
	glint.Size = UDim2.new(0, 10, 1, 0)
	glint.ZIndex = ui.mana.fill.ZIndex + 1
	glint.Parent = ui.mana.fill
	ui.manaGlint = glint
	ui.hasMana = false

	local souls = PixelUi.slot(bottom, UDim2.fromOffset(74 + BAR_W + 10, 4), 64, "secret", { z = 5 })
	souls:setIcon("soul")
	ui.souls = PixelUi.label(souls.holder, "x0", 16, C.mem, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(64, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 12,
	})
	ui.soulsSlot = souls

	ui.counter = PixelUi.label(bottom, "КОНТРУДАР!", 24, C.gold, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(400, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 15,
	})
	ui.combo = PixelUi.label(bottom, "", 32, C.bone, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0, 74 + BAR_W, 0, -2),
		Size = UDim2.fromOffset(160, 36),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 15,
	})

	-- ===== способности: левый нижний угол =====
	local abilities = Instance.new("Frame")
	abilities.Name = "Abilities"
	abilities.BackgroundTransparency = 1
	abilities.AnchorPoint = Vector2.new(0, 1)
	abilities.Position = UDim2.new(0, 24, 1, -72)
	abilities.Size = UDim2.fromOffset(5 * 76, 64)
	abilities.Parent = root
	ui.abilities = abilities
	ui.slots = {
		dash = abilitySlot(abilities, 0, "dash", keyName("Dash")),
		weapon = abilitySlot(abilities, 76, "whirl", keyName("Ability1")),
		soul = abilitySlot(abilities, 152, "verdict", keyName("Ability2")),
		heal = abilitySlot(abilities, 228, "flask", keyName("Heal")),
		-- Умение класса [3] (маг — «Покров»); у воина слот скрыт.
		class = abilitySlot(abilities, 304, "amulet", keyName("Ability3")),
	}
	ui.slots.class.slot.holder.Visible = false

	-- ===== слева сверху: оружие и задание =====
	local weapon = PixelUi.slot(root, UDim2.fromOffset(24, 22), 56, "common", { z = 5 })
	weapon:setIcon("sword")
	ui.weaponSlot = weapon
	ui.weaponName = PixelUi.label(root, "", 16, C.bone, { Position = UDim2.fromOffset(92, 28), Size = UDim2.fromOffset(350, 20) })
	local inventory = PixelUi.slot(root, UDim2.fromOffset(460, 20), 56, nil, { z = 5 })
	inventory:setIcon("scroll")
	local inventoryKey = PixelUi.piece(inventory.holder, "parchClean", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 3, 1, 3),
		Size = UDim2.fromOffset(24, 22),
		ZIndex = 12,
	})
	PixelUi.text(inventoryKey, "I", 12, C.ink, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 13,
	})
	local inventoryHit = Instance.new("TextButton")
	inventoryHit.Name = "InventoryButton"
	inventoryHit.BackgroundTransparency = 1
	inventoryHit.Text = ""
	inventoryHit.Size = UDim2.fromScale(1, 1)
	inventoryHit.ZIndex = 14
	inventoryHit.Parent = inventory.holder
	inventoryHit.Activated:Connect(function()
		if not ui.gui.Enabled then
			return
		end
		Bus.emit("openStation", { name = "Inventory" })
	end)
	ui.inventoryButton = inventoryHit
	ui.inventorySlot = inventory
	PixelUi.label(root, "ИНВЕНТАРЬ", 14, C.bone, {
		Position = UDim2.fromOffset(524, 30),
		Size = UDim2.fromOffset(150, 24),
	})
	-- Сундуки этажей v3 в сумке: значок с числом под надписью (атрибут ChestsStored).
	ui.chestBadge = Instance.new("Frame")
	ui.chestBadge.Name = "ChestBadge"
	ui.chestBadge.BackgroundTransparency = 1
	ui.chestBadge.Position = UDim2.fromOffset(522, 52)
	ui.chestBadge.Size = UDim2.fromOffset(120, 26)
	ui.chestBadge.Visible = false
	ui.chestBadge.Parent = root
	ui.chestBadgeScale = Instance.new("UIScale")
	ui.chestBadgeScale.Parent = ui.chestBadge
	PixelUi.icon(ui.chestBadge, "chest", UDim2.fromOffset(0, 0), 24, { ZIndex = 6 })
	ui.chestCount = PixelUi.label(ui.chestBadge, "", 16, C.gold, {
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.fromOffset(90, 24),
		ZIndex = 6,
	})
	ui.newBadge = PixelUi.piece(weapon.holder, "badge", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -2, 0, 2),
		Size = UDim2.fromOffset(26, 26),
		ZIndex = 14,
		Visible = false,
	})
	ui.newCount = PixelUi.label(ui.newBadge, "", 16, C.bone, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 15 })

	local quest = PixelUi.parch(root, UDim2.fromOffset(24, 92), UDim2.fromOffset(420, 48), { clean = true })
	PixelUi.icon(quest, "quest", UDim2.fromOffset(8, 4), 40, { ZIndex = 5 })
	ui.questTitle = PixelUi.text(quest, "", 16, C.ink, { Position = UDim2.fromOffset(54, 0), Size = UDim2.new(1, -130, 1, 0), ZIndex = 5 })
	ui.questProgress = PixelUi.text(quest, "", 16, C.ink2, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 0),
		Size = UDim2.fromOffset(80, 48),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 5,
	})
	ui.quest = quest

	-- ===== справа сверху: кошелёк =====
	ui.wallet = PixelUi.wallet(root, { { "coin", "Gold" }, { "ingot", "IronCount" }, { "dust", "EchoDust" } }, 24)

	-- ===== комната этажа под кошельком =====
	ui.room = PixelUi.label(root, "", 16, C.grey, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 78),
		Size = UDim2.fromOffset(500, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	-- Этаж 2: вентили шлюза (атрибут игрока F2Valves ставит Floor2World).
	ui.sluice = PixelUi.label(root, "", 16, Color3.fromRGB(95, 208, 192), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 102),
		Size = UDim2.fromOffset(500, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	-- ===== лента уведомлений =====
	ui.banner = Instance.new("Frame")
	ui.banner.Name = "Banner"
	ui.banner.BackgroundTransparency = 1
	ui.banner.AnchorPoint = Vector2.new(0.5, 0)
	ui.banner.Position = UDim2.new(0.5, 0, 0, -120)
	ui.banner.Size = UDim2.fromOffset(640, 80)
	ui.banner.Parent = root
	ui.bannerArt = PixelUi.piece(ui.banner, "ribbonGold", { Size = UDim2.fromScale(1, 1), ZIndex = 20 })
	ui.bannerTop = PixelUi.text(ui.banner, "", 16, Color3.fromRGB(120, 70, 20), {
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 21,
	})
	ui.bannerText = PixelUi.text(ui.banner, "", 24, C.ink, {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 21,
	})
	-- Значок слева на ленте (сундук этажа и т.п.): держатель над лентой.
	ui.bannerIcon = Instance.new("Frame")
	ui.bannerIcon.Name = "BannerIcon"
	ui.bannerIcon.BackgroundTransparency = 1
	ui.bannerIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	ui.bannerIcon.Position = UDim2.new(0, 70, 0.5, 2)
	ui.bannerIcon.Size = UDim2.fromOffset(84, 84)
	ui.bannerIcon.ZIndex = 22
	ui.bannerIcon.Parent = ui.banner
end

-- ===== уведомления =====
local bannerQueue = {}
local bannerBusy = false

local function showNextBanner()
	if bannerBusy or #bannerQueue == 0 then
		return
	end
	bannerBusy = true
	local item = table.remove(bannerQueue, 1)
	ui.bannerTop.Text = item.top or ""
	ui.bannerText.Text = item.text or ""
	ui.bannerTop.TextColor3 = item.topColor or Color3.fromRGB(120, 70, 20)
	for _, child in ipairs(ui.bannerIcon:GetChildren()) do
		child:Destroy()
	end
	local hasIcon = false
	if item.chest then
		-- сундук этажа: картинка атласа или живая модель
		ChestVisual.image(ui.bannerIcon, item.chest, "icon", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(84, 84),
			ZIndex = 23,
		})
		hasIcon = true
	elseif item.icon then
		PixelUi.icon(ui.bannerIcon, item.icon, UDim2.fromOffset(14, 14), 56, { ZIndex = 23 })
		hasIcon = true
	end
	local inset = hasIcon and 100 or 0
	ui.bannerTop.Position = UDim2.fromOffset(inset, 10)
	ui.bannerTop.Size = UDim2.new(1, -inset - (hasIcon and 30 or 0), 0, 22)
	ui.bannerText.Position = UDim2.fromOffset(inset, 34)
	ui.bannerText.Size = UDim2.new(1, -inset - (hasIcon and 30 or 0), 0, 30)
	local width = math.max(520, (utf8.len(item.text or "") or 10) * 24 + 160 + inset)
	ui.banner.Size = UDim2.fromOffset(width, 80)
	if hasIcon then
		ui.bannerIcon.Rotation = -8
		PixelUi.tween(ui.bannerIcon, 0.5, { Rotation = 0 }, Enum.EasingStyle.Back)
		PixelUi.pop(ui.bannerIcon, 0.15)
	end
	UiSound.play(item.sound or "reward_pop")
	PixelUi.tween(ui.banner, 0.35, { Position = UDim2.new(0.5, 0, 0, 16) }, Enum.EasingStyle.Back)
	task.delay(item.time or 2.6, function()
		PixelUi.tween(ui.banner, 0.3, { Position = UDim2.new(0.5, 0, 0, -120) })
		task.wait(0.35)
		bannerBusy = false
		showNextBanner()
	end)
end

-- opts: chest (id дизайна сундука — значок слева), icon (иконка атласа v2),
-- time (секунды показа), topColor.
function PixelHudController.banner(top: string?, text: string, sound: string?, opts)
	local item = { top = top, text = text, sound = sound }
	if opts then
		item.chest = opts.chest
		item.icon = opts.icon
		item.time = opts.time
		item.topColor = opts.topColor
	end
	table.insert(bannerQueue, item)
	showNextBanner()
end

-- ===== сундуки в сумке =====

-- Центр кнопки «Инвентарь» в пикселях экрана (сюда прилетает сундук).
function PixelHudController.inventoryPoint(): Vector2?
	local slot = ui.inventorySlot and ui.inventorySlot.holder
	if not slot or not ui.gui or not ui.gui.Enabled then
		return nil
	end
	return slot.AbsolutePosition + slot.AbsoluteSize / 2
end

local function updateChestBadge(pop: boolean?)
	if not ui.chestBadge then
		return
	end
	local n = player:GetAttribute("ChestsStored") or 0
	ui.chestBadge.Visible = n > 0
	ui.chestCount.Text = ("×%d"):format(n)
	if pop and n > 0 then
		ui.chestBadgeScale.Scale = 1.5
		PixelUi.tween(ui.chestBadgeScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

-- Сундук долетел до сумки: кнопка инвентаря «вздрагивает», число растёт.
function PixelHudController.pulseInventory()
	local slot = ui.inventorySlot and ui.inventorySlot.holder
	if slot then
		local scale = slot:FindFirstChild("PulseScale") or Instance.new("UIScale")
		scale.Name = "PulseScale"
		scale.Parent = slot
		scale.Scale = 1.25
		PixelUi.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	updateChestBadge(true)
end

-- ===== подсказка E у объекта (кастомный ProximityPrompt) =====
local promptGuis = {}

local function makePrompt(prompt: ProximityPrompt)
	local adornee = prompt.Parent
	if not (adornee and (adornee:IsA("BasePart") or adornee:IsA("Attachment") or adornee:IsA("Model"))) then
		return
	end
	local bill = Instance.new("BillboardGui")
	bill.Name = "PixelPrompt"
	bill.AlwaysOnTop = true
	bill.Size = UDim2.fromOffset(360, 60)
	bill.StudsOffset = Vector3.new(0, 2.5, 0)
	bill.LightInfluence = 0
	bill.Adornee = adornee
	bill.Parent = player:WaitForChild("PlayerGui")
	local key = PixelUi.slot(bill, UDim2.fromOffset(0, 4), 48, nil, { z = 2 })
	PixelUi.label(key.holder, prompt.KeyboardKeyCode.Name, 24, C.gold, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 10,
	})
	local text = prompt.ActionText ~= "" and prompt.ActionText or prompt.ObjectText
	local tag = PixelUi.parch(bill, UDim2.fromOffset(54, 8), UDim2.fromOffset((utf8.len(text) or 8) * 16 + 32, 40), { clean = true })
	PixelUi.text(tag, text, 16, C.ink, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
	local hold
	if prompt.HoldDuration > 0 then
		local _, fill = PixelUi.progress(bill, UDim2.fromOffset(54, 50), UDim2.fromOffset(tag.Size.X.Offset, 8), 0, C.gold)
		hold = fill
	end
	PixelUi.pop(bill:FindFirstChildWhichIsA("Frame") or key.holder)
	promptGuis[prompt] = { gui = bill, hold = hold }
end

local function hookPrompts()
	local function style(prompt)
		if prompt:IsA("ProximityPrompt") and not prompt:GetAttribute("KeepDefaultStyle") then
			prompt.Style = Enum.ProximityPromptStyle.Custom
		end
	end
	for _, d in ipairs(Workspace:GetDescendants()) do
		style(d)
	end
	Workspace.DescendantAdded:Connect(style)
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		if inputType ~= Enum.ProximityPromptInputType.Keyboard and inputType ~= Enum.ProximityPromptInputType.Gamepad then
			-- На телефоне — стандартная кнопка-касание надёжнее.
			prompt.Style = Enum.ProximityPromptStyle.Default
			return
		end
		makePrompt(prompt)
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		local entry = promptGuis[prompt]
		if entry then
			entry.gui:Destroy()
			promptGuis[prompt] = nil
		end
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		local entry = promptGuis[prompt]
		if entry and entry.hold then
			entry.hold.Size = UDim2.fromScale(0, 1)
			PixelUi.tween(entry.hold, prompt.HoldDuration, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		local entry = promptGuis[prompt]
		if entry and entry.hold then
			entry.hold.Size = UDim2.fromScale(0, 1)
		end
	end)
end

-- ===== обновление =====
-- ===== раскладка v3 =====
-- Низ по центру: оружие (портрет) | HP с опытом | рывок Q | фляга F | блок душ.
-- Блок душ строит SoulHudController в ui.soulsAnchor. Слева снизу остаются
-- способность оружия [1], предмет [G] (QuickItemController) и умение класса [3].
-- На телефоне рывок, фляга, способности и предмет — на сенсорных кнопках
-- (TouchControls), поэтому здесь они скрыты, полоса HP короче, связка крупнее.
local function relayout(force)
	local touch = TouchControls.isTouch()
	if touch == ui.touch and not force then
		return
	end
	ui.touch = touch
	local dash = ui.slots.dash.slot.holder
	local heal = ui.slots.heal.slot.holder
	if not ui.soulsAnchor then
		ui.vitalsScale = Instance.new("UIScale")
		ui.vitalsScale.Name = "VitalsScale"
		ui.vitalsScale.Parent = ui.bottom
		local anchor = Instance.new("Frame")
		anchor.Name = "SoulsAnchor"
		anchor.BackgroundTransparency = 1
		anchor.Size = UDim2.fromOffset(SOULS_W, 70)
		anchor.ZIndex = 20
		anchor.Parent = ui.bottom
		ui.soulsAnchor = anchor
		ui.counterBase = ui.counter.Position
		ui.comboBase = ui.combo.Position
		-- старый счётчик «x0» заменён блоком душ; душа босса [2] — тоже там
		ui.soulsSlot.holder.Parent = nil
		ui.slots.soul.slot.holder.Parent = nil
		-- оружие теперь в портрете нижней связки: верхний левый слот не нужен
		if ui.newBadge then
			ui.newBadge.Parent = ui.portrait.holder
		end
		ui.weaponSlot.holder.Visible = false
		ui.weaponName.Parent = ui.bottom
		ui.weaponName.Position = UDim2.fromOffset(0, -26)
		ui.weaponName.Size = UDim2.fromOffset(330, 20)
		-- ряд способностей: [1] оружия, место под предмет [G], [3] класса
		ui.slots.weapon.slot.holder.Position = UDim2.fromOffset(0, 0)
		ui.slots.class.slot.holder.Position = UDim2.fromOffset(152, 0)
		dash.Parent = ui.bottom
		heal.Parent = ui.bottom
	end
	local bar = touch and BAR_W_TOUCH or BAR_W
	ui.hp.holder.Size = UDim2.fromOffset(bar, 44)
	ui.mana.holder.Size = UDim2.fromOffset(bar, 30)
	ui.xpBack.Size = UDim2.fromOffset(bar - 8, 10)
	local combo = ui.comboBase
	ui.combo.Position = UDim2.new(combo.X.Scale, combo.X.Offset - BAR_W + bar, combo.Y.Scale, combo.Y.Offset)
	ui.counter.Position = touch and (ui.counterBase - UDim2.fromOffset(0, 58)) or ui.counterBase
	ui.bottom.Size = UDim2.fromOffset(vitalsWidth(touch), ui.hasMana and 100 or 70)
	ui.vitalsScale.Scale = touch and 1.15 or 1
	local x = 74 + bar + 10
	dash.Position = UDim2.fromOffset(x, 4)
	heal.Position = UDim2.fromOffset(x + 72, 4)
	dash.Visible = not touch
	heal.Visible = not touch
	ui.soulsAnchor.Position = UDim2.fromOffset(touch and (74 + bar + 14) or (x + 72 + 64 + 14), 0)
	ui.abilities.Visible = not touch
	if ui.quickHolder then
		ui.quickHolder.Visible = not touch
	end
end

-- Предмет [G] живёт на своём экране (QuickItemController); на телефоне его
-- заменяет сенсорная кнопка «ПРЕДМ», поэтому слот прячем.
local function quickItemSlot()
	if ui.quickHolder and ui.quickHolder.Parent then
		return
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local gui = playerGui and playerGui:FindFirstChild("KlinokQuickItem")
	local root = gui and gui:FindFirstChild("Root")
	local holder = root and root:FindFirstChild("QuickItem")
	ui.quickHolder = holder
	if holder then
		holder.Visible = not ui.touch
	end
end

local lastHealth
local hurtPulse = 0
local lastManaDenied = 0
local manaFlash = 0

-- Маг: полоса маны между HP и опытом, блок поднимается на её высоту.
local function layoutMana(hasMana: boolean)
	ui.hasMana = hasMana
	ui.mana.holder.Visible = hasMana
	ui.bottom.Size = UDim2.fromOffset(vitalsWidth(ui.touch == true), hasMana and 100 or 70)
	ui.xpBack.Position = UDim2.fromOffset(78, hasMana and 84 or 54)
	-- портрет v3 показывает текущее оружие (update), иконку здесь не трогаем
end

local function updateMana(dt: number)
	local maxMana = player:GetAttribute("MaxMana") or 0
	if (maxMana > 0) ~= ui.hasMana then
		layoutMana(maxMana > 0)
	end
	if not ui.hasMana then
		return
	end
	local mana = math.clamp(player:GetAttribute("Mana") or 0, 0, maxMana)
	local ratio = mana / maxMana
	if math.abs(ratio - ui.mana.value) > 0.001 then
		-- рост — сразу (реген идёт часто), трата — с «призраком»
		ui.mana:set(ratio, ratio > ui.mana.value)
	end
	ui.mana:setText(("%d / %d"):format(math.floor(mana), maxMana))
	-- не хватило маны: полоса вспыхивает красным и глухо звенит
	local denied = player:GetAttribute("ManaDeniedAt") or 0
	if denied > lastManaDenied then
		if lastManaDenied > 0 then
			manaFlash = 1
			UiSound.play("mana_empty")
		end
		lastManaDenied = denied
	end
	manaFlash = math.max(manaFlash - dt * 3, 0)
	ui.mana.fill.ImageColor3 = C.mana:Lerp(C.red, manaFlash)
	ui.mana.fill.BackgroundColor3 = ui.mana.fill.ImageColor3
	-- блик бежит, пока мана течёт
	local flowing = ratio < 0.999
	ui.manaGlint.Visible = flowing
	if flowing then
		local t = (os.clock() * 0.6) % 1
		ui.manaGlint.Position = UDim2.new(t, -5, 0, 0)
	end
end
local lastCombo = 0
local lastLevel

local function setCooldown(entry, left: number, length: number)
	if left > 0.05 then
		entry.shade.Size = UDim2.new(1, -16, math.clamp(left / math.max(length, 0.1), 0, 1), -16 * math.clamp(left / math.max(length, 0.1), 0, 1))
		entry.count.Text = left >= 10 and ("%d"):format(math.ceil(left)) or ("%.1f"):format(left)
		entry.ready = false
	else
		if not entry.ready then
			entry.ready = true
			-- готово: короткая вспышка слота
			local glow = PixelUi.glow(entry.slot.holder, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(120, 120), C.mem, 0.3)
			glow.ZIndex = 20
			PixelUi.tween(glow, 0.4, { ImageTransparency = 1, Size = UDim2.fromOffset(180, 180) })
			task.delay(0.45, function()
				glow:Destroy()
			end)
		end
		entry.shade.Size = UDim2.new(1, -16, 0, 0)
		entry.count.Text = ""
	end
end

local function update(dt: number)
	relayout()
	quickItemSlot()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local serverNow = Workspace:GetServerTimeNow()

	if humanoid then
		local ratio = humanoid.MaxHealth > 0 and math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) or 0
		if math.abs(ratio - ui.hp.value) > 0.001 then
			ui.hp:set(ratio)
		end
		ui.hp:setText(("%d / %d"):format(math.ceil(humanoid.Health), math.ceil(humanoid.MaxHealth)))
		if lastHealth and humanoid.Health < lastHealth - 0.5 then
			hurtPulse = 1
		end
		lastHealth = humanoid.Health
		local low = ratio < 0.3 and humanoid.Health > 0
		local base = low and (0.72 + 0.1 * math.sin(os.clock() * 5)) or 1
		hurtPulse = math.max(hurtPulse - dt * 2.5, 0)
		local transparency = math.min(base, 1 - hurtPulse * 0.55)
		for _, edge in ipairs(ui.edges) do
			edge.BackgroundTransparency = transparency
		end
	end

	-- уровень и опыт
	local level = player:GetAttribute("Level") or 1
	if lastLevel and level > lastLevel then
		UiSound.play("level_up")
		UiFx.floatText(ui.root, ("Уровень %d!"):format(level), Vector2.new(ui.root.AbsoluteSize.X / 2, ui.root.AbsoluteSize.Y - 160), C.gold, 32)
	end
	lastLevel = level
	ui.level.Text = tostring(level)
	local xp = player:GetAttribute("Xp") or 0
	local xpToNext = math.max(player:GetAttribute("XpToNext") or 100, 1)
	ui.xp.Size = UDim2.fromScale(math.clamp(xp / xpToNext, 0, 1), 1)

	ui.souls.Text = ("x%d"):format(player:GetAttribute("SoulStacks") or 0)
	updateMana(dt)

	-- контрудар и серия
	local counter = player:GetAttribute("CounterCharged") == true
	if counter and not ui.counter.Visible then
		ui.counter.Visible = true
		PixelUi.pop(ui.counter)
	elseif not counter then
		ui.counter.Visible = false
	end
	if counter then
		ui.counter.TextTransparency = 0.15 + 0.15 * math.sin(os.clock() * 10)
	end
	local combo = player:GetAttribute("Combo") or 0
	if combo ~= lastCombo then
		if combo >= 2 then
			ui.combo.Text = ("x%d"):format(combo)
			PixelUi.pop(ui.combo)
		else
			ui.combo.Text = ""
		end
		lastCombo = combo
	end

	-- способности
	local slots = ui.slots
	local dashLeft = math.max((player:GetAttribute("CooldownUntil") or 0) - serverNow, 0)
	setCooldown(slots.dash, dashLeft, Combat.Dodge.cooldown)
	local charges = player:GetAttribute("HealCharges") or 0
	slots.heal.stack.Text = ("x%d"):format(charges)
	slots.heal.slot.icon.ImageTransparency = charges > 0 and 0 or 0.6
	for index, entry in ipairs({ slots.weapon, slots.soul }) do
		local info = AbilityController.info(index)
		local iconName
		if index == 1 then
			-- Иконка способности — из Loot.Abilities[*].icon (атрибут ставит EquipmentService).
			local icon = player:GetAttribute("WeaponAbilityIcon")
			iconName = (icon and icon ~= "") and icon or (player:GetAttribute("WeaponAbility") == "whirl" and "whirl" or "split")
		else
			iconName = info and info.id == "gate_barrier" and "barrier" or "verdict"
		end
		if iconName ~= entry.icon then
			entry.slot:setIcon(iconName)
			entry.icon = iconName
		end
		if info then
			setCooldown(entry, info.left, info.length)
			entry.slot.icon.ImageTransparency = 0
		else
			-- способность закрыта
			entry.shade.Size = UDim2.new(1, -16, 0, 0)
			entry.count.Text = ""
			if entry.slot.icon then
				entry.slot.icon.ImageTransparency = 0.7
			end
		end
	end

	-- умение класса (слот 3)
	do
		local entry = slots.class
		local info = AbilityController.info(3)
		entry.slot.holder.Visible = info ~= nil
		if info then
			local icon = player:GetAttribute("ClassAbilityIcon")
			local iconName = (icon and icon ~= "") and icon or "amulet"
			if iconName ~= entry.icon then
				entry.slot:setIcon(iconName)
				entry.icon = iconName
			end
			setCooldown(entry, info.left, info.length)
			-- Под покровом слот подсвечен полупрозрачно: маг невидим.
			local veiled = (player:GetAttribute("VeiledUntil") or 0) > serverNow
			entry.slot.icon.ImageTransparency = veiled and 0.35 or 0
		end
	end

	-- оружие
	local typeId = player:GetAttribute("WeaponType") or "sword"
	local rarityId = player:GetAttribute("WeaponRarity") or "common"
	local stars = player:GetAttribute("WeaponLevel")
	ui.weaponName.Text = (player:GetAttribute("WeaponName") or "—") .. (stars and (" ★" .. stars) or "")
	ui.weaponName.TextColor3 = UiAssets.Rarity[rarityId] or C.bone
	if ui.weaponType ~= typeId then
		ui.weaponType = typeId
		ui.weaponSlot:setIcon(UiAssets.WeaponIcon[typeId] or "sword")
		ui.portrait:setIcon(UiAssets.WeaponIcon[typeId] or "sword")
	end
	ui.weaponSlot:setRarity(rarityId)
	ui.portrait:setRarity(rarityId)
	local newItems = player:GetAttribute("NewWeapons") or 0
	ui.newBadge.Visible = newItems > 0
	ui.newCount.Text = tostring(newItems)

	-- задание (атрибуты выставляет квестовая система: QuestTitle, QuestProgress)
	local questTitle = player:GetAttribute("QuestTitle")
	ui.quest.Visible = questTitle ~= nil and questTitle ~= ""
	ui.questTitle.Text = questTitle or ""
	ui.questProgress.Text = player:GetAttribute("QuestProgress") or ""

	-- комната этажа
	-- Папка этажа игрока: «Floor» (этаж 1), «Floor2» или «Floor3».
	local floorId = player:GetAttribute("FloorId") or 1
	local floor = Workspace:FindFirstChild(floorId == 1 and "Floor" or ("Floor" .. floorId))
	local roomIndex = player:GetAttribute("RoomIndex")
	local valves = player:GetAttribute("F2Valves")
	local trophies = player:GetAttribute("F3Trophies")
	if floorId == 2 and floor and valves then
		ui.sluice.Text = valves >= 3 and "Шлюз розария открыт" or ("Вентили шлюза %d/3"):format(valves)
	elseif floorId == 3 and floor and trophies then
		ui.sluice.Text = trophies >= 3 and "Ворота ристалища открыты" or ("Трофеи %d/3"):format(trophies)
	else
		ui.sluice.Text = ""
	end
	ui.room.Text = (floor and roomIndex) and ("%s · комната %d/%d"):format(player:GetAttribute("RoomName") or "", roomIndex, floor:GetAttribute("RoomCount") or 7) or ""
end

-- Сцена раскрытия сундука (ChestRevealController): ленты находок молчат.
function PixelHudController.setRevealActive(active: boolean)
	ui.revealActive = active
end

-- Пока сундук летит, число на значке не меняется (его «донесёт» pulseInventory).
function PixelHudController.setChestFlying(flying: boolean)
	ui.chestFlying = flying
	if not flying then
		updateChestBadge(false)
	end
end

function PixelHudController.setVisible(visible: boolean)
	if ui.gui then
		ui.gui.Enabled = visible
	end
end

-- Опоры для блока душ (SoulHudController): нижняя связка и место справа от фляги.
function PixelHudController.anchors()
	if not ui.soulsAnchor then
		return nil
	end
	return { gui = ui.gui, root = ui.root, vitals = ui.bottom, souls = ui.soulsAnchor }
end

function PixelHudController.start()
	build()
	relayout(true)
	hookPrompts()
	Bus.on("hurtFlash", function()
		hurtPulse = 1
	end)
	Bus.on("hud", function(data)
		PixelHudController.setVisible(data.visible ~= false)
	end)
	Bus.on("banner", function(data)
		PixelHudController.banner(data.top, data.text, data.sound, data)
	end)
	-- Сундуки в сумке: число обновляем сразу, «подпрыгивает» — когда сундук долетит.
	updateChestBadge(false)
	player:GetAttributeChangedSignal("ChestsStored"):Connect(function()
		local n = player:GetAttribute("ChestsStored") or 0
		if ui.chestBadge and (n < (ui.lastChests or 0) or not ui.chestFlying) then
			updateChestBadge(false)
		end
		ui.lastChests = n
	end)
	-- Новое оружие — лента.
	local lastNew = player:GetAttribute("NewWeapons") or 0
	player:GetAttributeChangedSignal("NewWeapons"):Connect(function()
		local now = player:GetAttribute("NewWeapons") or 0
		-- В сцене раскрытия сундука находку показывает сама сцена.
		if now > lastNew and not ui.revealActive then
			PixelHudController.banner("НОВАЯ НАХОДКА", "Оружие в инвентаре [I]", "reward_pop")
		end
		lastNew = now
	end)
	-- Повторка стала эхом (EchoService).
	player:GetAttributeChangedSignal("EchoEventId"):Connect(function()
		if ui.revealActive then
			return
		end
		PixelHudController.banner("ПОВТОРКА — ЭХО", player:GetAttribute("LastEcho") or "", "echo_absorb")
	end)
	RunService.RenderStepped:Connect(update)
	print("[PixelHudController] HUD v2 запущен")
end

-- Совместимость со старым HudController.
function PixelHudController.weaponTitle(): string
	local name = player:GetAttribute("WeaponName") or "—"
	local rarity = Rarities.get(player:GetAttribute("WeaponRarity") or "common")
	local typeId = player:GetAttribute("WeaponType") or "sword"
	local weaponType = Weapons.Types[typeId]
	return ("%s · %s"):format(name, rarity and rarity.name or (weaponType and weaponType.name or ""))
end

return PixelHudController
