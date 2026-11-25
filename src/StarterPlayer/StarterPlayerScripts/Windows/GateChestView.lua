--!nonstrict
-- GateChestView — меню сундука во Вратах Печатей (из вкладки «Сундуки» меню
-- этажа). Слева сундук: картинка, описание, где найти, что гарантировано.
-- Вкладка «Оружие»: сетка оружия по редкостям с шансами (Config.ChestPreview —
-- те же таблицы, что у сервера), справа карточка выбранного оружия с
-- вращающейся моделью, уроном на уровне игрока, критом, скоростью,
-- способностью и пассивкой; стрелки листают оружие по одному.
-- Вкладка «Броня и прочее»: броня, припасы, аксессуары.
-- Переключатель «Воин / Маг» — посмотреть лут другого класса.
--
--   GateChestView.new(canvas, { k, grade, world, data, className, onClose, onClass(className) }) → view (:close())

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiAssets = require(Shared.Config.UiAssets)
local Chests = require(Shared.Config.Chests)
local WorldMap = require(Shared.Config.WorldMap)
local ChestPreview = require(Shared.Config.ChestPreview)
local Loot = require(Shared.Config.Loot)
local Weapons = require(Shared.Config.Weapons)
local Classes = require(Shared.Config.Classes)
local Echo = require(Shared.Config.Echo)
local UiAtlas = require(Shared.Config.UiAtlas)

local Lib = script.Parent.Parent.Lib
local PixelUi = require(Lib.PixelUi)
local PaperUi = require(Lib.PaperUi)
local UiSound = require(Lib.UiSound)
local UiMotion = require(Lib.UiMotion)
local ChestVisual = require(Lib.ChestVisual)
local Ui = require(Lib.Ui)
local GateKit = require(Lib.GateKit)

local GateChestView = {}
GateChestView.__index = GateChestView

local C = UiAssets.Colors
local W, H = 1400, 720
local POS = UDim2.fromOffset(100, 116)
local MID_X, MID_W = 384, 560
local CARD_X, CARD_W = 968, 408
local AREA_Y = 160
local TYPE_NAME = { sword = "Меч", hammer = "Молот", dagger = "Кинжал", staff = "Посох" }
local CLASS_NAME = { warrior = "Воин", mage = "Маг" }

local function rarityColor(id: string?): Color3
	return UiAssets.Rarity[id or "common"] or C.bone
end

local function rarityName(id: string?): string
	return UiAssets.RarityName[id or "common"] or tostring(id)
end

local function iconOr(name: string?, fallback: string): string
	if name and UiAtlas.Icons[name] then
		return name
	end
	return fallback
end

-- 150 → «150», 1.25 → «1,25», 13.0 → «13».
local function number(v: number, digits: number?): string
	if not digits then
		return tostring(math.floor(v + 0.5))
	end
	local text = ("%." .. digits .. "f"):format(v)
	text = text:gsub("0+$", "")
	text = text:gsub("%.$", "")
	return (text:gsub("%.", ","))
end

function GateChestView.new(canvas, args)
	local self = setmetatable({}, GateChestView)
	self.args = args
	self.k = args.k
	self.grade = args.grade == "gold" and "gold" or "common"
	self.data = args.data or {}
	self.className = args.className or self.data.className or "warrior"
	self.level = tonumber(self.data.level) or 1
	self.tab = "weapons"
	self.floor = Chests.Floors[self.k] or {}
	self.cfg = self.floor[self.grade] or {}
	self.modal = GateKit.modal(canvas, POS, UDim2.fromOffset(W, H), 50, function()
		self:close()
	end)
	self.body = self.modal.body
	UiSound.play("chest_appear", { volume = 0.7 })
	UiSound.play("lid_open", { volume = 0.5, gap = 0 })
	self:buildHeader()
	self:buildLeft()
	self.tabs = GateKit.tabs(self.body, UDim2.fromOffset(MID_X, 104), 232, 44,
		{ { "weapons", "ОРУЖИЕ" }, { "other", "БРОНЯ И ПРОЧЕЕ" } }, self.tab, function(id)
			self.tab = id
			self:render(true)
		end)
	local area = Instance.new("Frame")
	area.Name = "Area"
	area.BackgroundTransparency = 1
	area.Position = UDim2.fromOffset(MID_X, AREA_Y)
	area.Size = UDim2.fromOffset(W - MID_X - 24, H - AREA_Y - 24)
	area.ZIndex = 6
	area.Parent = self.body
	self.area = area
	self:render(true)
	return self
end

-- ===== шапка =====

function GateChestView:buildHeader()
	local body = self.body
	local isGold = self.grade == "gold"
	local world = self.args.world or {}
	PixelUi.label(body, self.cfg.name or "Сундук", 24, isGold and C.gold or C.bone, { Position = UDim2.fromOffset(24, 18), Size = UDim2.fromOffset(820, 32), ZIndex = 8 })
	PaperUi.italic(body, ("Этаж %s · %s · %s"):format(world.numeral or tostring(self.k), world.name or "", isGold and "золотой сундук хранителя" or "обычный сундук"),
		20, GateKit.Dim, { Position = UDim2.fromOffset(26, 54), Size = UDim2.fromOffset(820, 26), ZIndex = 8 })
	PixelUi.button(body, "wood", UDim2.new(1, -184, 0, 20), UDim2.fromOffset(160, 52), "НАЗАД", function()
		self:close()
	end, { z = 8 })
	-- переключатель класса: чей лут показывать
	self.classButtons = {}
	for i, id in ipairs({ "warrior", "mage" }) do
		local b = PixelUi.button(body, id == self.className and "gold" or "wood", UDim2.new(1, -184 - 16 - (3 - i) * 128, 0, 24), UDim2.fromOffset(116, 44),
			GateKit.upper(CLASS_NAME[id] or id), function()
				if self.className == id then
					return
				end
				UiSound.play("tab_select")
				self:setClass(id)
			end, { z = 8 })
		self.classButtons[id] = b
	end
	PixelUi.label(body, "ЛУТ ДЛЯ:", 16, C.grey, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -184 - 16 - 2 * 128 - 8, 0, 36), Size = UDim2.fromOffset(160, 22),
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8 })
	GateKit.line(body, UDim2.fromOffset(20, 92), UDim2.new(1, -40, 0, 2))
end

function GateChestView:setClass(id: string)
	self.className = id
	for cid, b in pairs(self.classButtons) do
		b:setKind(cid == id and "gold" or "wood")
	end
	self.selected = nil
	if self.args.onClass then
		self.args.onClass(id)
	end
	self:renderGuaranteed()
	self:render(true)
end

-- ===== левая колонка: сундук =====

function GateChestView:buildLeft()
	local left = Instance.new("Frame")
	left.Name = "Left"
	left.BackgroundTransparency = 1
	left.Position = UDim2.fromOffset(24, 104)
	left.Size = UDim2.fromOffset(336, H - 128)
	left.ZIndex = 6
	left.Parent = self.body
	self.left = left
	local isGold = self.grade == "gold"
	local glow = PixelUi.glow(left, UDim2.new(0.5, 0, 0, 100), UDim2.fromOffset(320, 240), isGold and C.gold or C.mem, 0.72)
	glow.ZIndex = 7
	UiMotion.breathe(glow, "ImageTransparency", 0.6, 0.88, 1.3)
	local art = ChestVisual.image(left, Chests.key(self.k, self.grade), "art", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(224, 192),
		ZIndex = 8,
	}, { spin = true })
	UiMotion.popIn(art, 0.05, 0.6)
	PaperUi.text(left, self.cfg.text or "", 18, GateKit.Dim, {
		Position = UDim2.fromOffset(0, 204), Size = UDim2.fromOffset(336, 84), TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 8 })
	local text = WorldMap.get(self.k) or {}
	PixelUi.label(left, "ГДЕ НАЙТИ", 16, C.gold, { Position = UDim2.fromOffset(0, 294), Size = UDim2.fromOffset(300, 22), ZIndex = 8 })
	PaperUi.text(left, text.chests and text.chests[self.grade] or "", 18, GateKit.Text, {
		Position = UDim2.fromOffset(0, 318), Size = UDim2.fromOffset(336, 48), TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 8 })
	PixelUi.label(left, "ВНУТРИ ВСЕГДА", 16, C.gold, { Position = UDim2.fromOffset(0, 374), Size = UDim2.fromOffset(300, 22), ZIndex = 8 })
	local guaranteed = Instance.new("Frame")
	guaranteed.BackgroundTransparency = 1
	guaranteed.Position = UDim2.fromOffset(0, 400)
	guaranteed.Size = UDim2.fromOffset(336, H - 128 - 400)
	guaranteed.ZIndex = 6
	guaranteed.Parent = left
	self.guaranteed = guaranteed
	self:renderGuaranteed()
end

function GateChestView:renderGuaranteed()
	local holder = self.guaranteed
	GateKit.clear(holder)
	local rewards = ChestPreview.rewards(self.k)
	local armor = ChestPreview.armor(self.k, self.grade, self.className)
	local rows = {
		{ "coin", ("%d золота"):format(rewards.gold), C.gold },
		{ "ingot", ("%s ×%d–%d"):format(rewards.materialName, rewards.materialRange[1], rewards.materialRange[2]), C.bone },
		{ self.className == "mage" and "staff" or "sword", "1 оружие (шансы — справа)", C.bone },
	}
	if armor then
		table.insert(rows, { "armor", "1 комплект брони — своя редкость", C.mem })
	end
	for i, row in ipairs(rows) do
		local y = (i - 1) * 36
		PixelUi.icon(holder, row[1], UDim2.fromOffset(0, y), 32, { ZIndex = 8 })
		PaperUi.bold(holder, row[2], 19, row[3], { Position = UDim2.fromOffset(44, y + 2), Size = UDim2.fromOffset(292, 28), ZIndex = 8 })
	end
	local left = math.max(0, Loot.Chest.firstChestsCommon - (tonumber(self.data.chestsOpened) or Loot.Chest.firstChestsCommon))
	if left > 0 then
		PaperUi.italic(holder, ("Первые %d сундука аккаунта дают обычное оружие — осталось %d."):format(Loot.Chest.firstChestsCommon, left), 17, C.mem, {
			Position = UDim2.fromOffset(0, #rows * 36 + 2), Size = UDim2.fromOffset(336, 40), TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 8 })
	end
end

-- ===== правая часть =====

function GateChestView:render(animate: boolean?)
	GateKit.clear(self.area)
	self.cardFill = nil
	if self.tab == "other" then
		self:renderOther()
	else
		self:renderWeapons()
	end
	if animate then
		GateKit.cascade(self.area, Vector2.new(0, 10))
	end
end

function GateChestView:renderWeapons()
	local preview = ChestPreview.weapons(self.k, self.grade, self.className)
	self.items = preview.items
	local list = GateKit.scroll(self.area, UDim2.fromOffset(0, 0), UDim2.fromOffset(MID_W, H - AREA_Y - 24), { gap = 8 })
	self.slots = {}
	local index = 0
	for _, g in ipairs(preview.groups) do
		local head = Instance.new("Frame")
		head.BackgroundTransparency = 1
		head.Size = UDim2.new(1, 0, 0, 28)
		head.LayoutOrder = list.next()
		head.ZIndex = 7
		head.Parent = list.frame
		local color = rarityColor(g.rarity)
		PixelUi.label(head, GateKit.upper(rarityName(g.rarity)), 16, color, { Position = UDim2.fromOffset(0, 2), Size = UDim2.fromOffset(300, 22), ZIndex = 8 })
		PixelUi.label(head, ChestPreview.percent(g.chance), 16, color, {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(120, 22),
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8 })
		GateKit.line(head, UDim2.fromOffset(0, 26), UDim2.new(1, 0, 0, 2), color:Lerp(Color3.new(0, 0, 0), 0.45))
		local grid = GateKit.grid(list.frame, Vector2.new(96, 122), 10, list.next())
		for i, it in ipairs(g.items) do
			index += 1
			local myIndex = index
			local cell = Instance.new("Frame")
			cell.BackgroundTransparency = 1
			cell.LayoutOrder = i
			cell.ZIndex = 7
			cell.Parent = grid
			local slot = PixelUi.slot(cell, UDim2.fromOffset(4, 4), 88, it.rarity, { z = 8 })
			slot:setIcon(iconOr(UiAssets.WeaponIcon[it.typeId], "sword"))
			if it.ability then
				slot:setCorner("1", C.mem)
			end
			PixelUi.label(cell, ChestPreview.percent(it.chance), 16, C.bone, {
				Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 22),
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
			local hit = Instance.new("TextButton")
			hit.BackgroundTransparency = 1
			hit.Text = ""
			hit.Size = UDim2.fromScale(1, 1)
			hit.ZIndex = 20
			hit.Parent = cell
			hit.MouseEnter:Connect(function()
				UiSound.play("ui_hover", { volume = 0.5 })
				PixelUi.tween(slot.holder, 0.08, { Position = UDim2.fromOffset(4, 0) })
			end)
			hit.MouseLeave:Connect(function()
				PixelUi.tween(slot.holder, 0.1, { Position = UDim2.fromOffset(4, 4) })
			end)
			hit.Activated:Connect(function()
				self:select(myIndex, true)
			end)
			self.slots[myIndex] = slot
		end
	end
	-- карточка
	local card = PixelUi.panel(self.area, UDim2.fromOffset(CARD_X - MID_X, 0), UDim2.fromOffset(CARD_W, H - AREA_Y - 24), { z = 6 })
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.ZIndex = 12
	body.Parent = card
	self.card = body
	if #self.items == 0 then
		PaperUi.italic(body, "Этот сундук оружия не держит.", 20, GateKit.Dim, { Position = UDim2.fromOffset(20, 40), Size = UDim2.new(1, -40, 0, 30), ZIndex = 13 })
		return
	end
	-- по умолчанию — самое редкое: на него и хочется посмотреть
	self:select(self.selected and math.clamp(self.selected, 1, #self.items) or #self.items, false)
end

function GateChestView:select(index: number, sound: boolean?)
	local count = #self.items
	if count == 0 then
		return
	end
	index = ((index - 1) % count) + 1
	if self.slots[self.selected or 0] then
		self.slots[self.selected]:setSelected(false)
	end
	self.selected = index
	if self.slots[index] then
		self.slots[index]:setSelected(true)
		UiMotion.punch(self.slots[index].holder, 0.08, 0.18)
	end
	if sound then
		UiSound.play("item_reveal", { volume = 0.6 })
	end
	self:renderCard(self.items[index])
end

function GateChestView:renderCard(it)
	local body = self.card
	GateKit.clear(body)
	local color = rarityColor(it.rarity)
	local glow = PixelUi.glow(body, UDim2.new(0.5, 0, 0, 100), UDim2.fromOffset(280, 230), color, 0.6)
	glow.ZIndex = 12
	UiMotion.breathe(glow, "ImageTransparency", 0.5, 0.8, 1.0)
	Ui.weaponView(body, { id = it.id, typeId = it.typeId }, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(180, 180),
		ZIndex = 13,
	}, { spin = true })
	-- стрелки: листать оружие этого сундука по одному
	local count = #self.items
	for side = -1, 1, 2 do
		PixelUi.button(body, "wood", side < 0 and UDim2.fromOffset(16, 72) or UDim2.new(1, -72, 0, 72), UDim2.fromOffset(56, 56),
			side < 0 and "<" or ">", function()
				self:select(self.selected + side, true)
			end, { z = 14, textSize = 24 })
	end
	PixelUi.label(body, ("%d / %d"):format(self.selected, count), 16, C.grey, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 12), Size = UDim2.fromOffset(100, 22),
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 14 })
	local name = PixelUi.label(body, it.name, 24, color, {
		Position = UDim2.fromOffset(14, 194), Size = UDim2.new(1, -28, 0, 30), TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14 })
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 24
	limit.MinTextSize = 12
	limit.Parent = name
	PaperUi.italic(body, ("%s · %s"):format(TYPE_NAME[it.typeId] or it.typeId, rarityName(it.rarity)), 20, GateKit.Dim, {
		Position = UDim2.fromOffset(14, 226), Size = UDim2.new(1, -28, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14 })
	-- числа: урон на уровне игрока (★1, без заточки), крит, скорость, шанс
	local classStats = Classes.statsAtLevel(self.className, self.level) or Classes.statsAtLevel("warrior", self.level)
	local ok, damage = pcall(Weapons.damage, classStats.weaponDamage, it.typeId, it.rarity, 0, it.id)
	local stats = Weapons.stats(it.typeId, it.rarity, it.id)
	local crit = Echo.critChance(1, it.rarity)
	local cells = {
		{ "Урон", ok and number(damage * Echo.damageMultiplier(1)) or "—", C.bone, ("на ур. %d"):format(self.level) },
		{ "Крит", ChestPreview.percent(crit), C.bone },
		{ "Скорость", "×" .. number(stats.speed or 1, 2), C.bone },
		{ "Шанс", ChestPreview.percent(it.chance), C.gold, "в этом сундуке" },
	}
	if (stats.mana or 0) > 0 then
		cells[3] = { "Мана", "+" .. number(stats.mana), C.manaLight, "×" .. number(stats.speed or 1, 2) .. " скорость" }
	end
	for i, cell in ipairs(cells) do
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		local x, y = 16 + col * 192, 256 + row * 52
		PixelUi.label(body, GateKit.upper(cell[1]), 16, C.grey, { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(180, 20), ZIndex = 14 })
		if cell[4] then
			PaperUi.italic(body, cell[4], 16, GateKit.Dim, { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(180, 20), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 14 })
		end
		PixelUi.label(body, cell[2], 24, cell[3], { Position = UDim2.fromOffset(x, y + 20), Size = UDim2.fromOffset(180, 28), ZIndex = 14 })
	end
	GateKit.line(body, UDim2.fromOffset(16, 362), UDim2.new(1, -32, 0, 2))
	local ability, passive = Loot.abilityOf({ id = it.id })
	local y = 372
	if ability then
		PixelUi.icon(body, iconOr(ability.icon, "star"), UDim2.fromOffset(16, y), 32, { ZIndex = 14 })
		PixelUi.label(body, ability.name or "", 16, C.mem, { Position = UDim2.fromOffset(56, y), Size = UDim2.fromOffset(330, 20), ZIndex = 14 })
		local meta = {}
		if ability.cooldown then
			table.insert(meta, ("перезарядка %s с"):format(number(ability.cooldown, 1)))
		end
		if ability.cost then
			table.insert(meta, ("мана %s"):format(number(ability.cost)))
		end
		table.insert(meta, "клавиша 1")
		PaperUi.italic(body, table.concat(meta, " · "), 16, GateKit.Dim, { Position = UDim2.fromOffset(56, y + 20), Size = UDim2.fromOffset(330, 18), ZIndex = 14 })
		PaperUi.text(body, ability.description or "", 17, GateKit.Text, {
			Position = UDim2.fromOffset(16, y + 42), Size = UDim2.new(1, -32, 0, passive and 54 or 110), TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 14 })
		y += 100
	else
		PaperUi.italic(body, "Без способности: простое, честное оружие — вплавь в него эхо, и оно станет сильнее.", 18, GateKit.Dim, {
			Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 66), TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 14 })
		y += 72
	end
	if passive then
		PixelUi.label(body, "ПАССИВКА · " .. GateKit.upper(passive.name or ""), 16, C.gold, { Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 20), TextScaled = true, ZIndex = 14 })
		PaperUi.text(body, passive.description or "", 17, GateKit.Text, {
			Position = UDim2.fromOffset(16, y + 22), Size = UDim2.new(1, -32, 0, 40), TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 14 })
	end
end

-- Строка списка: иконка, имя цветом редкости, подпись, шанс справа.
local function row(parent, order: number, icon, name: string, color: Color3, sub: string?, chance: string)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 44)
	holder.LayoutOrder = order
	holder.ZIndex = 7
	holder.Parent = parent
	if icon then
		icon(holder)
	end
	PaperUi.bold(holder, name, 18, color, { Position = UDim2.fromOffset(46, sub and 0 or 10), Size = UDim2.new(1, -120, 0, 22), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8 })
	if sub then
		PaperUi.italic(holder, sub, 16, GateKit.Dim, { Position = UDim2.fromOffset(46, 22), Size = UDim2.new(1, -120, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8 })
	end
	PixelUi.label(holder, chance, 16, C.bone, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 11), Size = UDim2.fromOffset(80, 22),
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8 })
	return holder
end

function GateChestView:renderOther()
	local areaH = H - AREA_Y - 24
	local colW = math.floor((W - MID_X - 24 - 2 * 20) / 3)
	local function column(i: number, title: string, color: Color3?)
		local panel = PixelUi.panel(self.area, UDim2.fromOffset((i - 1) * (colW + 20), 0), UDim2.fromOffset(colW, areaH), { corners = false, z = 6 })
		local body = Instance.new("Frame")
		body.BackgroundTransparency = 1
		body.Size = UDim2.fromScale(1, 1)
		body.ZIndex = 12
		body.Parent = panel
		PixelUi.label(body, title, 16, color or C.gold, { Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 22), TextScaled = true, ZIndex = 13 })
		local list = GateKit.scroll(body, UDim2.fromOffset(16, 48), UDim2.new(1, -24, 1, -60), { gap = 4 })
		return list
	end
	-- броня
	local armor = ChestPreview.armor(self.k, self.grade, self.className)
	local armorTitle = armor and (armor.chance >= 1 and "БРОНЯ · ВСЕГДА" or ("БРОНЯ · " .. ChestPreview.percent(armor.chance))) or "БРОНЯ"
	local a = column(1, armorTitle)
	if not armor or #armor.items == 0 then
		GateKit.para(a.frame, "Этот класс брони не носит.", 18, GateKit.Dim, { order = a.next(), kind = "italic" })
	else
		GateKit.para(a.frame, "Комплект в каждом сундуке; его редкость бросается отдельно от оружия.", 17, C.mem, { order = a.next(), kind = "italic" })
		for _, it in ipairs(armor.items) do
			row(a.frame, a.next(), function(holder)
				PixelUi.icon(holder, "armor", UDim2.fromOffset(0, 4), 36, { ZIndex = 8 })
			end, it.name, rarityColor(it.rarity), rarityName(it.rarity), ChestPreview.percent(it.chance))
		end
	end
	-- припасы
	local supplies = ChestPreview.supplies(self.k, self.grade)
	local s = column(2, ("ПРИПАСЫ · %d–%d СТОПКИ"):format(supplies.stacks[1], supplies.stacks[2]))
	GateKit.para(s.frame, "Шанс — найти хотя бы одну такую стопку.", 16, GateKit.Dim, { order = s.next(), kind = "italic" })
	for _, it in ipairs(supplies.items) do
		local count = it.count[1] == it.count[2] and ("×%d"):format(it.count[1]) or ("×%d–%d"):format(it.count[1], it.count[2])
		row(s.frame, s.next(), function(holder)
			PaperUi.itemIcon(holder, it.icon, UDim2.fromOffset(20, 22), 36, { ZIndex = 8 })
		end, it.name, rarityColor(it.rarity), count, ChestPreview.percent(it.chance))
	end
	-- аксессуары
	local acc = supplies.accessories
	local x = column(3, "АКСЕССУАРЫ · " .. ChestPreview.percent(acc.chance), C.gold)
	for _, it in ipairs(acc.items) do
		row(x.frame, x.next(), function(holder)
			PaperUi.itemIcon(holder, it.icon, UDim2.fromOffset(20, 22), 36, { ZIndex = 8 })
		end, it.name, rarityColor(it.rarity), (it.slot == "ring" and "Кольцо" or "Амулет") .. " · " .. rarityName(it.rarity), ChestPreview.percent(it.chance))
	end
end

function GateChestView:close()
	if self.closed then
		return
	end
	self.closed = true
	UiSound.play("page_back", { volume = 0.6 })
	self.modal.close()
	if self.args.onClose then
		self.args.onClose()
	end
end

return GateChestView
