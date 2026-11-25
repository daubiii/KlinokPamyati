--!nonstrict
-- WorldMapView (клиент)
-- Пиксельная карта острова Хранилища для Врат Печатей: пять этажей-регионов,
-- плашки с названиями, компас (нарисован в карте), облака над морем, туман
-- над закрытыми этажами, подсветка при наведении, флажок «ты здесь».
--
-- Картинка — Config.WorldMapArt.Atlas (куски — Config.WorldMapAtlas), ×3 Pixelated.
-- Без загруженной картинки остров рисуется полосами сетки (WorldMapAtlas.Fallback):
-- та же форма, цвета этажей из Palette, закрытые — серые.
-- Попадания — те же полосы сетки (прозрачные кнопки 12×12 дизайн-px):
-- наведение и клик работают и мышью, и пальцем, без пересчёта координат.
--
--   local map = WorldMapView.new(parent, pos, worlds, { onPick = fn(k), onHover = fn(k|nil), revealed = {k...} })
--   map:setWorlds(worlds)  map:setSelected(k|nil)  map:setBlocked(bool)  map:deny(k)  map:reveal(k)
--   map:stop() (только анимация)  map:destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiAssets = require(Shared.Config.UiAssets)
local Palette = require(Shared.Config.Palette)
local WorldMapAtlas = require(Shared.Config.WorldMapAtlas)
local WorldMapArt = require(Shared.Config.WorldMapArt)
local WorldMap = require(Shared.Config.WorldMap)

local PixelUi = require(script.Parent.PixelUi)
local UiMotion = require(script.Parent.UiMotion)
local UiSound = require(script.Parent.UiSound)
local UiFx = require(script.Parent.UiFx)

local WorldMapView = {}
WorldMapView.__index = WorldMapView

local C = UiAssets.Colors
local S = WorldMapAtlas.Scale
local MAP_W, MAP_H = WorldMapAtlas.MapSize.w * S, WorldMapAtlas.MapSize.h * S
local CELL = WorldMapAtlas.Grid.cell * S

WorldMapView.Size = Vector2.new(MAP_W, MAP_H)

local STATE_COLOR = { open = C.mem, done = C.gold, locked = Color3.fromRGB(150, 144, 138) }
local SEA = Color3.fromRGB(44, 86, 120)
local SEA_DEEP = Color3.fromRGB(30, 62, 92)
local LOCKED_LAND = Color3.fromRGB(78, 80, 90)

-- Полосы попаданий (hit) прозрачны поверх картинки; флажок выше них — без картинки полосы и есть суша.
local Z = { map = 3, hi = 4, fog = 5, puff = 6, cloud = 7, hit = 9, pin = 10, plaque = 11 }

local function isHidden(world)
	return world == nil or world.hidden == true or world.name == WorldMap.HiddenName
end

local function isLocked(world)
	return world == nil or world.state == "locked"
end

local function piece(parent, name: string, props)
	local p = WorldMapAtlas.Pieces[name]
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Image = WorldMapArt.Atlas
	label.ImageRectOffset = Vector2.new(p.x, p.y)
	label.ImageRectSize = Vector2.new(p.w, p.h)
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.Size = UDim2.fromOffset(p.w * S, p.h * S)
	PixelUi.apply(label, props)
	label.Parent = parent
	return label
end
WorldMapView.piece = piece

local function regionPos(point)
	return UDim2.fromOffset(point.x * S, point.y * S)
end

local function floorColor(k: number, index: number): Color3
	local floor = Palette.Floors[k]
	return floor and floor.colors and floor.colors[index] or C.grey
end

function WorldMapView.new(parent, pos: UDim2, worlds, opts)
	local self = setmetatable({}, WorldMapView)
	self.opts = opts or {}
	self.worlds = worlds or {}
	self.atlas = WorldMapArt.has()
	self.alive = true
	self.hoverCount = {}
	self.regions = {}
	self.connections = {}

	local frame = Instance.new("Frame")
	frame.Name = "WorldMap"
	frame.BackgroundColor3 = SEA
	frame.BackgroundTransparency = self.atlas and 1 or 0
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Position = pos
	frame.Size = UDim2.fromOffset(MAP_W, MAP_H)
	frame.ZIndex = Z.map
	frame.Parent = parent
	self.frame = frame

	if self.atlas then
		self.mapImage = piece(frame, "map", { ZIndex = Z.map })
	else
		-- заглушка: тёмные полосы глубины моря
		for i = 0, 5 do
			local band = Instance.new("Frame")
			band.BorderSizePixel = 0
			band.BackgroundColor3 = SEA_DEEP
			band.BackgroundTransparency = 0.6 + i * 0.06
			band.Position = UDim2.fromOffset(0, i * CELL * 2)
			band.Size = UDim2.new(1, 0, 0, CELL)
			band.ZIndex = Z.map
			band.Parent = frame
		end
	end

	for k = 1, #WorldMapAtlas.Regions do
		self:buildRegion(k)
	end
	self:buildStrips()
	if self.atlas then
		self:buildClouds()
	end
	self:buildPin()
	self:paint()

	local started = os.clock()
	table.insert(self.connections, RunService.RenderStepped:Connect(function(dt)
		if not frame.Parent then
			self:stop()
			return
		end
		self:step(os.clock() - started, dt)
	end))
	return self
end

-- ===== постройка =====

function WorldMapView:buildRegion(k: number)
	local region = WorldMapAtlas.Regions[k]
	local r: any = { k = k, strips = {}, puffs = {} }
	self.regions[k] = r
	local box = region.box
	if self.atlas then
		r.hi = piece(self.frame, "hi" .. k, { Position = UDim2.fromOffset(box.x * S, box.y * S), ImageTransparency = 1, ZIndex = Z.hi })
		r.fog = piece(self.frame, "fog" .. k, { Position = regionPos(region.fog), ZIndex = Z.fog, Visible = false })
		for i = 1, 2 do
			local puff = piece(self.frame, "puff" .. i, { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = Z.puff, Visible = false, ImageTransparency = 0.15 })
			local cx = region.center.x + (i == 1 and -box.w * 0.18 or box.w * 0.16)
			local cy = region.center.y + (i == 1 and -box.h * 0.12 or box.h * 0.14)
			table.insert(r.puffs, { image = puff, x = cx * S, y = cy * S, phase = k * 1.7 + i * 2.3, amp = 18 + i * 8 })
		end
	end
	-- плашка с названием
	local plaque = Instance.new("Frame")
	plaque.Name = "Plaque" .. k
	plaque.BackgroundTransparency = 1
	plaque.AnchorPoint = Vector2.new(0.5, 0.5)
	plaque.Position = regionPos(region.label)
	plaque.Size = UDim2.fromOffset(200, 44)
	plaque.ZIndex = Z.plaque
	plaque.Parent = self.frame
	r.plaque = plaque
	r.plaqueBase = plaque.Position
	r.board = PixelUi.panel(plaque, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), { corners = false, z = Z.plaque })
	r.medal = PixelUi.piece(plaque, "medal", { Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(40, 40), ZIndex = Z.plaque + 2 })
	r.numeral = PixelUi.label(r.medal, "", 16, C.bone, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = Z.plaque + 3 })
	r.lock = PixelUi.icon(r.medal, "lock", UDim2.new(0.5, -12, 0.5, -12), 24, { ZIndex = Z.plaque + 3 })
	r.name = PixelUi.label(plaque, "", 16, C.bone, { Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -60, 1, 0), ZIndex = Z.plaque + 2 })
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = Z.plaque + 6
	hit.Parent = plaque
	self:bindHit(hit, k)
end

function WorldMapView:buildStrips()
	for _, s in ipairs(WorldMapAtlas.Fallback) do
		local k, x, y, len = s[1], s[2], s[3], s[4]
		local strip = Instance.new("TextButton")
		strip.Name = "Cell" .. k
		strip.AutoButtonColor = false
		strip.Text = ""
		strip.BorderSizePixel = 0
		strip.BackgroundTransparency = self.atlas and 1 or 0
		strip.Position = UDim2.fromOffset(x * CELL, y * CELL)
		strip.Size = UDim2.fromOffset(len * CELL, CELL)
		strip.ZIndex = Z.hit
		strip.Parent = self.frame
		local r = self.regions[k]
		if r then
			table.insert(r.strips, strip)
		end
		self:bindHit(strip, k)
	end
end

function WorldMapView:buildClouds()
	self.clouds = {}
	local specs = {
		{ "cloud1", 0.10, 0.10, 9 },
		{ "cloud3", 0.62, 0.84, 6 },
		{ "cloud2", 0.86, 0.30, 12 },
		{ "cloud1", 0.34, 0.92, 7 },
	}
	for _, spec in ipairs(specs) do
		local image = piece(self.frame, spec[1], { ZIndex = Z.cloud, ImageTransparency = 0.12 })
		table.insert(self.clouds, { image = image, x = spec[2] * MAP_W, y = spec[3] * MAP_H, speed = spec[4], w = image.Size.X.Offset })
	end
end

function WorldMapView:buildPin()
	if self.atlas then
		self.pin = piece(self.frame, "pin", { AnchorPoint = Vector2.new(0.5, 1), ZIndex = Z.pin, Visible = false })
	else
		local pin = Instance.new("Frame")
		pin.Name = "pin"
		pin.BorderSizePixel = 0
		pin.BackgroundColor3 = C.red
		pin.AnchorPoint = Vector2.new(0.5, 1)
		pin.Size = UDim2.fromOffset(12, 24)
		pin.ZIndex = Z.pin
		pin.Visible = false
		pin.Parent = self.frame
		self.pin = pin
	end
	self.pinLabel = PixelUi.label(self.frame, "ты здесь", 16, C.bone, {
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(160, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = Z.pin,
		Visible = false,
	})
end

-- Наведение по счётчику: соседние полосы одного этажа не мигают подсветкой,
-- в каком бы порядке ни пришли MouseLeave/MouseEnter.
function WorldMapView:bindHit(button, k: number)
	button.MouseEnter:Connect(function()
		self.hoverCount[k] = (self.hoverCount[k] or 0) + 1
		self:setHover(k)
	end)
	button.MouseLeave:Connect(function()
		self.hoverCount[k] = math.max(0, (self.hoverCount[k] or 0) - 1)
		task.defer(function()
			if self.alive and (self.hoverCount[k] or 0) == 0 and self.hovered == k then
				self:setHover(nil)
			end
		end)
	end)
	button.Activated:Connect(function()
		if self.alive and not self.blocked and self.opts.onPick then
			self.opts.onPick(k)
		end
	end)
end

-- ===== состояние =====

function WorldMapView:setWorlds(worlds)
	self.worlds = worlds or {}
	self:paint()
end

function WorldMapView:highestOpen(): number?
	local best
	for k, world in ipairs(self.worlds) do
		if not isLocked(world) then
			best = k
		end
	end
	return best
end

function WorldMapView:paint()
	for k, r in ipairs(self.regions) do
		local world = self.worlds[k]
		local locked = isLocked(world)
		local hidden = isHidden(world)
		local stateColor = STATE_COLOR[world and world.state or "locked"] or C.grey
		local text = hidden and WorldMap.HiddenName or (world and world.name or "")
		r.name.Text = text
		r.name.TextColor3 = locked and (hidden and Color3.fromRGB(130, 124, 118) or Color3.fromRGB(196, 188, 178)) or C.bone
		r.numeral.Text = world and world.numeral or tostring(k)
		r.numeral.TextColor3 = stateColor
		r.numeral.Visible = not locked
		r.lock.Visible = locked
		r.medal.ImageColor3 = stateColor
		local width = 52 + (utf8.len(text) or #text) * 16 + 16
		r.plaque.Size = UDim2.fromOffset(math.max(width, 120), 44)
		r.board.Visible = true
		if self.atlas then
			r.fog.Visible = locked
			-- следующий этаж (имя уже известно) — туман тоньше: «за печатью что-то есть»
			local base = hidden and 0.02 or 0.14
			if r.stopFog then
				r.stopFog()
				r.stopFog = nil
			end
			if locked then
				r.stopFog = UiMotion.breathe(r.fog, "ImageTransparency", base, base + 0.08, 2.4 + k * 0.3)
			end
			for _, puff in ipairs(r.puffs) do
				puff.image.Visible = locked
			end
		else
			for _, strip in ipairs(r.strips) do
				strip.BackgroundColor3 = locked and LOCKED_LAND or floorColor(k, 2)
			end
		end
	end
	local top = self:highestOpen()
	if top then
		local mark = WorldMapAtlas.Regions[top].landmark
		self.pinBase = UDim2.fromOffset(mark.x * S, mark.y * S - 6)
		self.pin.Position = self.pinBase
		self.pin.Visible = true
		self.pinLabel.Position = self.pinBase - UDim2.fromOffset(0, self.atlas and 30 or 28)
		self.pinLabel.Visible = true
	else
		self.pin.Visible = false
		self.pinLabel.Visible = false
	end
	self:paintHighlight()
end

function WorldMapView:paintHighlight()
	for k, r in ipairs(self.regions) do
		local world = self.worlds[k]
		local on = self.hovered == k or self.selected == k
		local color = STATE_COLOR[world and world.state or "locked"] or C.grey
		if self.atlas then
			if r.stopHi then
				r.stopHi()
				r.stopHi = nil
			end
			r.hi.ImageColor3 = color
			if self.selected == k then
				r.stopHi = UiMotion.breathe(r.hi, "ImageTransparency", 0.05, 0.45, 0.7)
			elseif on then
				r.hi.ImageTransparency = isLocked(world) and 0.45 or 0.1
			else
				r.hi.ImageTransparency = 1
			end
		else
			local base = isLocked(world) and LOCKED_LAND or floorColor(k, 2)
			local lit = isLocked(world) and LOCKED_LAND:Lerp(Color3.new(1, 1, 1), 0.15) or floorColor(k, 3)
			for _, strip in ipairs(r.strips) do
				strip.BackgroundColor3 = on and lit or base
			end
		end
		local lift = on and not isLocked(world) and -6 or 0
		if r.lift ~= lift then
			if r.lift ~= nil then
				TweenService:Create(r.plaque, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Position = r.plaqueBase + UDim2.fromOffset(0, lift) }):Play()
			end
			r.lift = lift
		end
	end
end

function WorldMapView:setHover(k: number?)
	if self.blocked and k ~= nil then
		return
	end
	if self.hovered == k then
		return
	end
	self.hovered = k
	if k then
		local world = self.worlds[k]
		UiSound.play(isLocked(world) and "stone_tick" or "choice_hover", { volume = 0.5, pitch = 0.9 + k * 0.05 })
	end
	self:paintHighlight()
	if self.opts.onHover then
		self.opts.onHover(k)
	end
end

-- Поверх карты открыто меню: наведение не подсвечивает и не звучит.
function WorldMapView:setBlocked(on: boolean)
	self.blocked = on
	if on then
		self:setHover(nil)
	end
end

function WorldMapView:setSelected(k: number?)
	self.selected = k
	self:paintHighlight()
end

-- Клик по закрытому этажу: печать держит.
function WorldMapView:deny(k: number)
	local r = self.regions[k]
	if not r then
		return
	end
	UiSound.play("stone_slab", { pitch = 1.2 })
	PixelUi.nudge(r.plaque)
	if r.fog then
		local base = r.fog.Position
		task.spawn(function()
			for _, dx in ipairs({ -6, 6, -4, 4, -2, 0 }) do
				if not r.fog.Parent then
					return
				end
				r.fog.Position = base + UDim2.fromOffset(dx, 0)
				task.wait(0.035)
			end
			r.fog.Position = base
		end)
	end
end

-- Этаж открылся с прошлого раза: туман редеет и разлетается клубами.
function WorldMapView:reveal(k: number)
	local r = self.regions[k]
	local region = WorldMapAtlas.Regions[k]
	if not r or not region then
		return
	end
	local center = Vector2.new(region.center.x * S, region.center.y * S)
	task.delay(0.45, function()
		if not self.alive then
			return
		end
		UiSound.play("memory_secret", { volume = 0.8 })
		UiSound.play("echo_absorb", { volume = 0.6, gap = 0 })
		if self.atlas then
			local fog = piece(self.frame, "fog" .. k, { Position = regionPos(region.fog), ZIndex = Z.fog + 1 })
			local size = fog.Size
			TweenService:Create(fog, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				ImageTransparency = 1,
				Size = size + UDim2.fromOffset(60, 30),
				Position = fog.Position - UDim2.fromOffset(30, 15),
			}):Play()
			task.delay(1.7, function()
				fog:Destroy()
			end)
			for i = 1, 6 do
				local puff = piece(self.frame, "puff" .. (i % 2 + 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(center.X, center.Y), ZIndex = Z.puff + 1 })
				local a = (i / 6) * math.pi * 2 + math.random() * 0.4
				TweenService:Create(puff, TweenInfo.new(1.3 + math.random() * 0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Position = UDim2.fromOffset(center.X + math.cos(a) * 260, center.Y + math.sin(a) * 120),
					ImageTransparency = 1,
				}):Play()
				task.delay(1.8, function()
					puff:Destroy()
				end)
			end
		end
		UiFx.burst(self.frame, center, { STATE_COLOR.open, C.bone, floorColor(k, 3) }, 30, 220)
		if r.plaque.Parent then
			UiMotion.punch(r.plaque, 0.2, 0.3)
		end
	end)
end

-- ===== анимация =====

function WorldMapView:step(t: number, dt: number)
	if self.clouds then
		for _, cloud in ipairs(self.clouds) do
			cloud.x += cloud.speed * dt
			if cloud.x > MAP_W + 20 then
				cloud.x = -cloud.w - 20
			end
			cloud.image.Position = UDim2.fromOffset(math.floor(cloud.x / S) * S, cloud.y)
		end
	end
	for _, r in ipairs(self.regions) do
		for _, puff in ipairs(r.puffs) do
			if puff.image.Visible then
				local x = puff.x + math.sin(t * 0.22 + puff.phase) * puff.amp
				local y = puff.y + math.cos(t * 0.17 + puff.phase) * 6
				puff.image.Position = UDim2.fromOffset(math.floor(x / S) * S, math.floor(y / S) * S)
			end
		end
	end
	if self.pin.Visible and self.pinBase then
		local bob = math.floor(math.abs(math.sin(t * 2.6)) * 3) * S
		self.pin.Position = self.pinBase - UDim2.fromOffset(0, bob)
	end
end

-- Остановить анимацию (окно гаснет само — карту не рвём посреди затухания).
function WorldMapView:stop()
	self.alive = false
	for _, c in ipairs(self.connections) do
		c:Disconnect()
	end
	self.connections = {}
end

function WorldMapView:destroy()
	if not self.alive and not self.frame then
		return
	end
	self:stop()
	if self.frame then
		self.frame:Destroy()
		self.frame = nil
	end
end

return WorldMapView
