--!nonstrict
-- GateFloorView — меню этажа во Вратах Печатей (открывается кликом по
-- открытому этажу на карте). Слева: фрагмент карты, хранитель, рекорд,
-- сложность и «ВОЙТИ». Справа вкладки: «Об этаже» (описание, мини-боссы,
-- обитатели, опасности, добыча), «Летопись» (лор на пергаменте), «Сундуки»
-- (две карточки → меню сундука GateChestView).
--
--   GateFloorView.new(canvas, { k, world, data, difficulty, onClose, onEnter(worldId, diffId, button),
--                               onChest(grade), onDifficulty(id) }) → view (:close())

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiAssets = require(Shared.Config.UiAssets)
local Chests = require(Shared.Config.Chests)
local WorldMap = require(Shared.Config.WorldMap)
local WorldMapAtlas = require(Shared.Config.WorldMapAtlas)
local WorldMapArt = require(Shared.Config.WorldMapArt)
local ChestPreview = require(Shared.Config.ChestPreview)
local Palette = require(Shared.Config.Palette)

local Lib = script.Parent.Parent.Lib
local PixelUi = require(Lib.PixelUi)
local PaperUi = require(Lib.PaperUi)
local UiSound = require(Lib.UiSound)
local UiMotion = require(Lib.UiMotion)
local ChestVisual = require(Lib.ChestVisual)
local GateKit = require(Lib.GateKit)

local GateFloorView = {}
GateFloorView.__index = GateFloorView

local C = UiAssets.Colors
local STATE_COLOR = { open = C.mem, done = C.gold, locked = Color3.fromRGB(150, 144, 138) }
local ROLE_COLOR = {
	melee = Color3.fromRGB(236, 196, 150),
	tank = Color3.fromRGB(170, 190, 220),
	ranged = Color3.fromRGB(160, 220, 150),
	disruptor = Color3.fromRGB(220, 160, 230),
	object = Color3.fromRGB(190, 180, 160),
}
local NUMERALS = { "I", "II", "III" }

local W, H = 1280, 712
local POS = UDim2.fromOffset(160, 118)
local RIGHT_X, RIGHT_W = 488, 768
local CONTENT_Y, CONTENT_H = 172, 516

local function bagCount(data, k: number, grade: string): number
	local bag = data and data.chests or {}
	return tonumber(bag[Chests.key(k, grade)]) or 0
end

-- Сложность по умолчанию: запомненная (если открыта) или самая дальняя открытая.
local function defaultDifficulty(world, remembered: string?)
	local list = world.difficulties or {}
	local best
	for _, d in ipairs(list) do
		if not d.locked then
			if d.id == remembered then
				return d.id
			end
			best = d.id
		end
	end
	return best
end

function GateFloorView.new(canvas, args)
	local self = setmetatable({}, GateFloorView)
	self.args = args
	self.k = args.k
	self.world = args.world
	self.data = args.data
	self.text = WorldMap.get(args.k) or {}
	self.difficulty = defaultDifficulty(self.world, args.difficulty)
	self.tab = "about"
	self.modal = GateKit.modal(canvas, POS, UDim2.fromOffset(W, H), 30, function()
		self:close()
	end)
	self.body = self.modal.body
	UiSound.play("page_turn", { volume = 0.8 })
	UiSound.play("stone_slab", { pitch = 1.35, volume = 0.4, gap = 0 })
	self:buildHeader()
	self:buildLeft()
	self.tabs = GateKit.tabs(self.body, UDim2.fromOffset(RIGHT_X, 112), 200, 48,
		{ { "about", "ОБ ЭТАЖЕ" }, { "lore", "ЛЕТОПИСЬ" }, { "chests", "СУНДУКИ" } }, self.tab, function(id)
			self.tab = id
			self:renderTab(true)
		end)
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(RIGHT_X, CONTENT_Y)
	content.Size = UDim2.fromOffset(RIGHT_W, CONTENT_H)
	content.ZIndex = 6
	content.Parent = self.body
	self.content = content
	self:renderTab(true)
	return self
end

-- ===== шапка =====

function GateFloorView:buildHeader()
	local world, body = self.world, self.body
	local color = STATE_COLOR[world.state] or C.grey
	local medal = PixelUi.piece(body, "medal", { Position = UDim2.fromOffset(24, 14), Size = UDim2.fromOffset(68, 68), ImageColor3 = color, ZIndex = 8 })
	PixelUi.label(medal, world.numeral or tostring(self.k), 24, color, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
	local halo = PixelUi.glow(medal, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(130, 130), color, 0.5)
	halo.ZIndex = 7
	UiMotion.breathe(halo, "ImageTransparency", 0.35, 0.7, 0.9)
	PixelUi.label(body, world.name or "", 32, Color3.fromRGB(220, 244, 255), { Position = UDim2.fromOffset(108, 14), Size = UDim2.fromOffset(760, 40), ZIndex = 8 })
	PaperUi.italic(body, world.theme or world.sub or "", 22, GateKit.Dim, { Position = UDim2.fromOffset(110, 54), Size = UDim2.fromOffset(700, 28), ZIndex = 8 })
	local status
	if world.state == "done" then
		status = "ПЕЧАТЬ ПРОЙДЕНА"
	elseif world.bossDefeated then
		status = "ХРАНИТЕЛЬ ПОВЕРЖЕН"
	else
		status = "ПЕЧАТЬ ОТКРЫТА"
	end
	PixelUi.label(body, status, 16, color, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -208, 0, 34),
		Size = UDim2.fromOffset(320, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 8,
	})
	PixelUi.button(body, "wood", UDim2.new(1, -184, 0, 20), UDim2.fromOffset(160, 52), "НАЗАД", function()
		self:close()
	end, { z = 8 })
	GateKit.line(body, UDim2.fromOffset(20, 98), UDim2.new(1, -40, 0, 2))
end

-- ===== левая колонка =====

-- Фрагмент карты: кусок острова по рамке этажа + белая обводка цвета статуса.
function GateFloorView:buildCrop(parent, pos: UDim2, size: Vector2)
	local frame = PixelUi.panel(parent, pos, UDim2.fromOffset(size.X, size.Y), { corners = false, shadow = false, flat = true, z = 7 })
	local inner = Instance.new("Frame")
	inner.BackgroundColor3 = Color3.fromRGB(44, 86, 120)
	inner.BorderSizePixel = 0
	inner.ClipsDescendants = true
	inner.Position = UDim2.fromOffset(6, 6)
	inner.Size = UDim2.new(1, -12, 1, -12)
	inner.ZIndex = 9
	inner.Parent = frame
	local region = WorldMapAtlas.Regions[self.k]
	local box = region.box
	local color = STATE_COLOR[self.world.state] or C.grey
	if WorldMapArt.has() then
		local map = WorldMapAtlas.Pieces.map
		local crop = Instance.new("ImageLabel")
		crop.BackgroundTransparency = 1
		crop.Image = WorldMapArt.Atlas
		crop.ImageRectOffset = Vector2.new(map.x + box.x, map.y + box.y)
		crop.ImageRectSize = Vector2.new(box.w, box.h)
		crop.ResampleMode = Enum.ResamplerMode.Pixelated
		crop.ScaleType = Enum.ScaleType.Fit
		crop.Size = UDim2.fromScale(1, 1)
		crop.ZIndex = 10
		crop.Parent = inner
		local hi = WorldMapAtlas.Pieces["hi" .. self.k]
		local outline = crop:Clone()
		outline.ImageRectOffset = Vector2.new(hi.x, hi.y)
		outline.ImageRectSize = Vector2.new(hi.w, hi.h)
		outline.ImageColor3 = color
		outline.ZIndex = 11
		outline.Parent = inner
		UiMotion.breathe(outline, "ImageTransparency", 0.1, 0.6, 1.1)
	else
		-- заглушка: полосы сетки этого этажа, вписанные в рамку
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for _, s in ipairs(WorldMapAtlas.Fallback) do
			if s[1] == self.k then
				minX, minY = math.min(minX, s[2]), math.min(minY, s[3])
				maxX, maxY = math.max(maxX, s[2] + s[4]), math.max(maxY, s[3] + 1)
			end
		end
		local cw, ch = size.X - 12, size.Y - 12
		local cell = math.floor(math.min(cw / math.max(1, maxX - minX), ch / math.max(1, maxY - minY)))
		local ox = math.floor((cw - (maxX - minX) * cell) / 2)
		local oy = math.floor((ch - (maxY - minY) * cell) / 2)
		local land = Palette.Floors[self.k] and Palette.Floors[self.k].colors[2] or C.grey
		for _, s in ipairs(WorldMapAtlas.Fallback) do
			if s[1] == self.k then
				local strip = Instance.new("Frame")
				strip.BorderSizePixel = 0
				strip.BackgroundColor3 = land
				strip.Position = UDim2.fromOffset(ox + (s[2] - minX) * cell, oy + (s[3] - minY) * cell)
				strip.Size = UDim2.fromOffset(s[4] * cell, cell)
				strip.ZIndex = 10
				strip.Parent = inner
			end
		end
	end
	PixelUi.label(inner, self.text.short or "", 16, C.bone, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -6),
		Size = UDim2.fromOffset(300, 22),
		ZIndex = 12,
	})
	return frame
end

function GateFloorView:buildLeft()
	local body, world, text = self.body, self.world, self.text
	local left = Instance.new("Frame")
	left.Name = "Left"
	left.BackgroundTransparency = 1
	left.Position = UDim2.fromOffset(24, 112)
	left.Size = UDim2.fromOffset(440, 576)
	left.ZIndex = 6
	left.Parent = body
	self.left = left
	self:buildCrop(left, UDim2.fromOffset(0, 0), Vector2.new(440, 224))
	-- хранитель
	PixelUi.label(left, "ХРАНИТЕЛЬ", 16, C.grey, { Position = UDim2.fromOffset(0, 240), Size = UDim2.fromOffset(200, 22), ZIndex = 8 })
	PixelUi.label(left, text.keeper or world.keeper or "—", 24, GateKit.Keeper, { Position = UDim2.fromOffset(0, 266), Size = UDim2.fromOffset(440, 30), ZIndex = 8 })
	PaperUi.italic(left, "«" .. (text.keeperTitle or "") .. "»", 20, GateKit.Dim, { Position = UDim2.fromOffset(0, 298), Size = UDim2.fromOffset(440, 24), ZIndex = 8 })
	if world.bossDefeated then
		local f = Chests.Floors[self.k]
		PixelUi.label(left, "ПОВЕРЖЕН", 16, C.gold, {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 240), Size = UDim2.fromOffset(200, 22),
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8,
		})
		if f then
			PixelUi.icon(left, "trophy", UDim2.new(1, -36, 0, 266), 32, { ZIndex = 8 })
		end
	end
	-- рекорд
	PixelUi.label(left, "РЕКОРД", 16, C.grey, { Position = UDim2.fromOffset(0, 336), Size = UDim2.fromOffset(200, 22), ZIndex = 8 })
	PixelUi.label(left, world.record or "—", 16, C.gold, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 336), Size = UDim2.fromOffset(300, 22),
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8,
	})
	PixelUi.progress(left, UDim2.fromOffset(0, 364), UDim2.new(1, 0, 0, 16), world.recordRatio or 0, C.mem)
	-- сложность
	self.diffHolder = Instance.new("Frame")
	self.diffHolder.BackgroundTransparency = 1
	self.diffHolder.Position = UDim2.fromOffset(0, 394)
	self.diffHolder.Size = UDim2.fromOffset(440, 96)
	self.diffHolder.ZIndex = 6
	self.diffHolder.Parent = left
	self:renderDifficulty()
	-- ВОЙТИ
	local open = world.state ~= "locked" and self.difficulty ~= nil
	self.enter = PixelUi.button(left, open and "mem" or "off", UDim2.fromOffset(0, 500), UDim2.fromOffset(440, 76), open and "ВОЙТИ" or "ЗАКРЫТО", function()
		if self.args.onEnter and self.difficulty then
			self.args.onEnter(world.id or self.k, self.difficulty, self.enter)
		end
	end, { textSize = 32, glow = open, enabled = open, z = 8 })
	if self.enter.glow then
		UiMotion.breathe(self.enter.glow, "ImageTransparency", 0.45, 0.75, 0.8)
	end
end

function GateFloorView:renderDifficulty(punch: number?)
	local holder = self.diffHolder
	GateKit.clear(holder)
	local list = self.world.difficulties or {}
	local current
	for _, d in ipairs(list) do
		if d.id == self.difficulty then
			current = d
		end
	end
	PixelUi.label(holder, "СЛОЖНОСТЬ", 16, C.grey, { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(200, 22), ZIndex = 8 })
	PixelUi.label(holder, current and current.name or "", 16, C.mem, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(260, 22),
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8,
	})
	local n = math.max(1, #list)
	local bw = math.floor((440 - (n - 1) * 16) / n)
	for i, d in ipairs(list) do
		local on = d.id == self.difficulty
		local b = PixelUi.button(holder, on and "mem" or "off", UDim2.fromOffset((i - 1) * (bw + 16), 32), UDim2.fromOffset(bw, 52),
			d.locked and "" or (NUMERALS[i] or tostring(i)), function()
				if self.difficulty == d.id then
					return
				end
				UiSound.play("floor_pick", { pitch = 0.9 + i * 0.08 })
				self.difficulty = d.id
				if self.args.onDifficulty then
					self.args.onDifficulty(d.id)
				end
				self:renderDifficulty(i)
			end, { enabled = not d.locked, textSize = 24, z = 8 })
		if d.locked then
			PixelUi.icon(b.holder, "lock", UDim2.new(0.5, -16, 0.5, -18), 32, { ZIndex = 14 })
		elseif d.passed then
			PixelUi.icon(b.holder, "star", UDim2.new(1, -30, 0, -8), 28, { ZIndex = 14 })
		end
		if punch == i then
			UiMotion.punch(b.holder, 0.12, 0.22)
		end
	end
end

-- ===== вкладки =====

function GateFloorView:renderTab(animate: boolean?)
	GateKit.clear(self.content)
	if self.tab == "lore" then
		self:renderLore()
	elseif self.tab == "chests" then
		self:renderChests()
	else
		self:renderAbout()
	end
	if animate then
		GateKit.cascade(self.content)
	end
end

function GateFloorView:renderAbout()
	local text, data, k = self.text, self.data, self.k
	local list = GateKit.scroll(self.content, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1))
	local col = list.frame
	for _, p in ipairs(text.about or {}) do
		GateKit.para(col, p, 22, GateKit.Text, { order = list.next() })
	end
	if text.minibosses and #text.minibosses > 0 then
		GateKit.heading(col, "МИНИ-БОССЫ", C.gold, list.next())
		local grid = GateKit.grid(col, Vector2.new(368, 56), 12, list.next())
		for i, mb in ipairs(text.minibosses) do
			GateKit.chip(grid, mb.name, "«" .. (mb.title or "") .. "»", GateKit.Keeper, GateKit.Dim, i)
		end
	end
	if text.inhabitants and #text.inhabitants > 0 then
		GateKit.heading(col, "ОБИТАТЕЛИ", C.gold, list.next())
		local grid = GateKit.grid(col, Vector2.new(240, 56), 12, list.next())
		for i, e in ipairs(text.inhabitants) do
			GateKit.chip(grid, e.name, WorldMap.Roles[e.role] or "", C.bone, ROLE_COLOR[e.role] or GateKit.Dim, i)
		end
	end
	if text.dangers and #text.dangers > 0 then
		GateKit.heading(col, "ОПАСНОСТИ", C.red, list.next())
		for _, d in ipairs(text.dangers) do
			GateKit.para(col, "•  " .. d, 20, GateKit.Text, { order = list.next() })
		end
	end
	GateKit.heading(col, "ДОБЫЧА", C.gold, list.next())
	local rewards = ChestPreview.rewards(k)
	GateKit.para(col, ("За сундук: %d золота и «%s» ×%d–%d, одно оружие, иногда броня, припасы и аксессуары."):format(
		rewards.gold, rewards.materialName, rewards.materialRange[1], rewards.materialRange[2]), 20, GateKit.Text, { order = list.next() })
	local common, gold = bagCount(data, k, "common"), bagCount(data, k, "gold")
	GateKit.para(col, ("Сундуков этого этажа в сумке: обычных ×%d, золотых ×%d."):format(common, gold), 20,
		(common + gold) > 0 and C.gold or GateKit.Dim, { order = list.next(), kind = "bold" })
end

function GateFloorView:renderLore()
	local text = self.text
	local parch = PixelUi.parch(self.content, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), { ZIndex = 6 })
	local list = GateKit.scroll(parch, UDim2.fromOffset(36, 28), UDim2.new(1, -60, 1, -52), { bar = PaperUi.colors.ink2, gap = 14 })
	local col = list.frame
	if text.quote then
		GateKit.para(col, text.quote, 24, PaperUi.colors.ink2, { order = list.next(), kind = "italic", align = Enum.TextXAlignment.Center })
	end
	for _, p in ipairs(text.lore or {}) do
		GateKit.para(col, p, 22, PaperUi.colors.ink, { order = list.next(), lineHeight = 1.12 })
	end
	GateKit.para(col, "— из Архива Кузни Эха", 20, PaperUi.colors.ink2, { order = list.next(), kind = "italic", align = Enum.TextXAlignment.Right })
end

function GateFloorView:renderChests()
	local k, data = self.k, self.data
	local floor = Chests.Floors[k]
	local className = data.className or "warrior"
	for i, grade in ipairs({ "common", "gold" }) do
		local x = (i - 1) * (376 + 16)
		local card = PixelUi.panel(self.content, UDim2.fromOffset(x, 0), UDim2.fromOffset(376, CONTENT_H), { corners = grade == "gold", z = 6 })
		local body = Instance.new("Frame")
		body.BackgroundTransparency = 1
		body.Size = UDim2.fromScale(1, 1)
		body.ZIndex = 12
		body.Parent = card
		local isGold = grade == "gold"
		local cfg = floor and floor[grade] or {}
		PixelUi.label(body, isGold and "ЗОЛОТОЙ · ХРАНИТЕЛЬ" or "ОБЫЧНЫЙ", 16, isGold and C.gold or C.grey, {
			Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13 })
		if isGold then
			local glow = PixelUi.glow(body, UDim2.new(0.5, 0, 0, 136), UDim2.fromOffset(300, 220), C.gold, 0.7)
			glow.ZIndex = 12
			UiMotion.breathe(glow, "ImageTransparency", 0.55, 0.85, 1.2)
		end
		local art = ChestVisual.image(body, Chests.key(k, grade), "art", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 40),
			Size = UDim2.fromOffset(224, 192),
			ZIndex = 13,
		})
		local bag = bagCount(data, k, grade)
		if bag > 0 then
			PixelUi.label(body, "×" .. bag, 24, C.gold, {
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 44), Size = UDim2.fromOffset(100, 30),
				TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 15 })
		end
		PixelUi.label(body, cfg.name or "Сундук", 16, isGold and C.gold or C.bone, {
			Position = UDim2.fromOffset(14, 238), Size = UDim2.new(1, -28, 0, 40), TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13 })
		PaperUi.text(body, cfg.text or "", 18, GateKit.Dim, {
			Position = UDim2.fromOffset(18, 282), Size = UDim2.new(1, -36, 0, 66), TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 13 })
		local where = self.text.chests and self.text.chests[grade] or ""
		PaperUi.bold(body, "Где найти: ", 18, C.bone, { Position = UDim2.fromOffset(18, 352), Size = UDim2.fromOffset(100, 22), ZIndex = 13 })
		PaperUi.text(body, where, 18, GateKit.Text, {
			Position = UDim2.fromOffset(18, 374), Size = UDim2.new(1, -36, 0, 44), TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 13 })
		-- полоса редкостей оружия
		local preview = ChestPreview.weapons(k, grade, className)
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = C.dark
		bar.BorderSizePixel = 0
		bar.Position = UDim2.fromOffset(18, 424)
		bar.Size = UDim2.new(1, -36, 0, 12)
		bar.ZIndex = 13
		bar.Parent = body
		local x0 = 0
		for _, g in ipairs(preview.groups) do
			local seg = Instance.new("Frame")
			seg.BorderSizePixel = 0
			seg.BackgroundColor3 = UiAssets.Rarity[g.rarity] or C.grey
			seg.Position = UDim2.fromScale(x0, 0)
			seg.Size = UDim2.fromScale(g.chance, 1)
			seg.ZIndex = 14
			seg.Parent = bar
			x0 += g.chance
		end
		local best = preview.groups[#preview.groups]
		if best then
			PaperUi.text(body, ("Лучшее оружие: %s — %s"):format(UiAssets.RarityName[best.rarity] or best.rarity, ChestPreview.percent(best.chance)), 17,
				UiAssets.Rarity[best.rarity] or C.bone, { Position = UDim2.fromOffset(18, 438), Size = UDim2.new(1, -36, 0, 20), ZIndex = 13 })
		end
		local look = PixelUi.button(body, isGold and "gold" or "wood", UDim2.fromOffset(18, 462), UDim2.new(1, -36, 0, 44), "СМОТРЕТЬ ЛУТ", function()
			if self.args.onChest then
				self.args.onChest(grade)
			end
		end, { z = 13 })
		-- клик по самому сундуку — то же самое
		local hit = Instance.new("TextButton")
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Position = UDim2.fromOffset(60, 40)
		hit.Size = UDim2.new(1, -120, 0, 192)
		hit.ZIndex = 20
		hit.Parent = body
		hit.MouseEnter:Connect(function()
			UiSound.play("choice_hover", { volume = 0.5 })
			UiMotion.punch(art, 0.05, 0.15)
		end)
		hit.Activated:Connect(function()
			UiMotion.punch(look.holder, 0.06, 0.18)
			if self.args.onChest then
				self.args.onChest(grade)
			end
		end)
	end
end

function GateFloorView:close()
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

return GateFloorView
