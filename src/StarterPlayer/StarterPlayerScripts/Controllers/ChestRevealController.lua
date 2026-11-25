--!nonstrict
-- ChestRevealController (клиент) — сцена «Клинок читает память»
--
-- Сундуки этажей v3 открываются только в долине, из сумки (CharacterWindow →
-- «Сундуки» → ОТКРЫТЬ) или командой отладки. Bus.emit("chestReveal", { key, fromBag }).
--
--   1. затемнение, сундук этажа (свой дизайн, ChestModel) падает сверху, пыль;
--   2. из квадратов памяти собирается Клинок Памяти — остриём вниз;
--   3. удар в замок: вспышка, искры, тряска — замок светится;
--   4. клинок взлетает, крышка откидывается, из сундука бьют лучи цвета этажа;
--   5. память по спирали течёт в клинок; дол клинка вспыхивает цветами
--      редкостей по порядку (обычное → редкое → …) до редкости находки;
--      строка «Клинок читает память: <шёпот этажа>»; у секретного — сбой и кольца;
--   6. клинок рассыпается — квадраты собираются в находку, столб света;
--   7. карточка: мощь и разница с оружием в руке, способность, броня/аксессуар/
--      припасы, золото и материал. НАДЕТЬ · В СУМКУ · ОТКРЫТЬ ЕЩЁ.
--      Выпавшая броня стоит в витрине 3D-моделью рядом с оружием (Lib/ArmorView,
--      модель собирает сервер — Systems/ArmorPreviewService).
-- Клик / Пробел — пропустить к карточке. Esc / Enter на карточке — закрыть.
-- Сервер (ChestService.open) бросает содержимое в самом начале — сцена только
-- показывает итог; если открыть не вышло, сундук остаётся в сумке.

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChestDesigns = require(Shared.Config.ChestDesigns)
local Chests = require(Shared.Config.Chests)
local Rarities = require(Shared.Config.Rarities)
local UiAssets = require(Shared.Config.UiAssets)
local ChestModel = require(Shared.Util.ChestModel)
local ClientState = require(Shared.Util.ClientState)
local Net = require(Shared.Net.Net)

local Lib = script.Parent.Parent.Lib
local ArmorView = require(Lib.ArmorView)
local Bus = require(Lib.Bus)
local ChestVisual = require(Lib.ChestVisual)
local PaperUi = require(Lib.PaperUi)
local PixelUi = require(Lib.PixelUi)
local StationApi = require(Lib.StationApi)
local Ui = require(Lib.Ui)
local UiFx = require(Lib.UiFx)
local UiMotion = require(Lib.UiMotion)
local UiSound = require(Lib.UiSound)
local PixelHudController = require(script.Parent.PixelHudController)

local ChestRevealController = {}

local player = Players.LocalPlayer
local C = PixelUi.colors
local WHITE = Color3.new(1, 1, 1)
local MEM = C.mem
local GOLD = C.gold

-- Раскладка в дизайн-координатах (1600×900).
local VIEW_CENTER = Vector2.new(800, 575)
local VIEW_SIZE = Vector2.new(840, 600)
local ITEM = Vector2.new(800, 270) -- где проявляется находка (центр витрины карточки)
local CARD_POS = Vector2.new(500, 100)
local CARD_SIZE = Vector2.new(600, 760)
local PX = 6 -- один пиксель Клинка Памяти
local BLADE = ChestDesigns.Blade
local BLADE_W = #BLADE[1]
local BLADE_H = #BLADE
local BLADE_SIZE = Vector2.new(BLADE_W * PX, BLADE_H * PX)
local HOVER_TIP = ITEM + Vector2.new(0, BLADE_SIZE.Y * 0.5) -- остриё, когда клинок «читает»

local ACTION = "KlinokChestReveal"

local scene = nil -- текущая сцена (одна на экран)

-- ===== мелочи =====

local function tween(object, time: number, props, style: Enum.EasingStyle?, dir: Enum.EasingDirection?, delay: number?)
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0)
	local t = TweenService:Create(object, info, props)
	t:Play()
	return t
end

local function ease(a: number, style: Enum.EasingStyle, dir: Enum.EasingDirection?): number
	return TweenService:GetValue(a, style, dir or Enum.EasingDirection.Out)
end

local function box(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = WHITE
	for key, value in pairs(props) do
		f[key] = value
	end
	f.Parent = parent
	return f
end

local function at(v: Vector2): UDim2
	return UDim2.fromOffset(v.X, v.Y)
end

local function hex(value, fallback: Color3): Color3
	if type(value) == "string" then
		local ok, color = pcall(Color3.fromHex, value)
		if ok then
			return color
		end
	end
	return fallback
end

-- Прогон 0..1 за duration в потоке таймлайна (task.cancel прерывает на task.wait).
local function run(duration: number, fn)
	local started = os.clock()
	while true do
		local a = math.clamp((os.clock() - started) / duration, 0, 1)
		fn(a)
		if a >= 1 then
			return
		end
		task.wait()
	end
end

-- Сияние: атлас (ImageTransparency) или заглушка-круг (BackgroundTransparency).
local function glowTo(g, time: number, t: number, color: Color3?, delay: number?)
	local props = {}
	if g.Image == "" then
		props.BackgroundTransparency = 1 - (1 - t) * 0.35
		if color then
			props.BackgroundColor3 = color
		end
	else
		props.ImageTransparency = t
		if color then
			props.ImageColor3 = color
		end
	end
	if time > 0 then
		tween(g, time, props, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, delay)
	else
		PixelUi.apply(g, props)
	end
end

local function makeGlow(parent, center: UDim2, size: UDim2, color: Color3, t: number, z: number?)
	local g = PixelUi.glow(parent, center, size, color, 1)
	glowTo(g, 0, t, color)
	g.ZIndex = z or 1
	return g
end

local function rarityColor(id: string?): Color3
	return UiAssets.Rarity[id or "common"] or Rarities.color(id or "common")
end

local function rarityName(id: string?): string
	local data = Rarities.get(id or "common")
	return data and data.name or (id or "")
end

-- Точка мира (в кадре витрины) → дизайн-координаты холста.
local function project(s, point: Vector3): Vector2
	local camera = s.camera
	local rel = camera.CFrame:PointToObjectSpace(point)
	local depth = math.max(-rel.Z, 0.01)
	local tanY = math.tan(math.rad(camera.FieldOfView) / 2)
	local aspect = VIEW_SIZE.X / VIEW_SIZE.Y
	local nx = rel.X / (depth * tanY * aspect)
	local ny = rel.Y / (depth * tanY)
	return Vector2.new(VIEW_CENTER.X + nx * VIEW_SIZE.X / 2, VIEW_CENTER.Y - ny * VIEW_SIZE.Y / 2)
end

-- ===== частицы и лучи =====

local function square(s, layer, color: Color3, size: number, pos: Vector2, z: number?)
	return box(layer or s.fx, {
		Name = "Bit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at(pos),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		ZIndex = z or 2,
	})
end

-- Частица с законом движения: path(e) → Vector2, e = 0..1 за life.
local function particle(s, layer, color: Color3, size: number, life: number, path, fade: number?, alpha: number?)
	local bit = square(s, layer, color, size, path(0))
	bit.BackgroundTransparency = alpha or 0
	table.insert(s.particles, { frame = bit, born = os.clock(), life = life, path = path, size = size, fade = fade or 0.35, alpha = alpha or 0 })
	return bit
end

local function ring(s, center: Vector2, color: Color3, from: number, to: number, time: number, thickness: number?)
	local r = box(s.fx, {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at(center),
		Size = UDim2.fromOffset(from, from),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = r
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 6
	stroke.Parent = r
	tween(r, time, { Size = UDim2.fromOffset(to, to) }, Enum.EasingStyle.Quart)
	tween(stroke, time, { Transparency = 1, Thickness = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(time + 0.05, function()
		r:Destroy()
	end)
	return r
end

-- Веер лучей из точки. Каждый луч — полоса длиной 2L с центром в точке,
-- видна только верхняя половина: так поворот идёт вокруг точки.
local function rays(parent, center: Vector2, opts)
	local holder = box(parent, {
		Name = "Rays",
		BackgroundTransparency = 1,
		Position = at(center),
		Size = UDim2.fromOffset(0, 0),
		ZIndex = opts.z or 9,
	})
	local list = {}
	for i = 1, opts.count do
		local base
		if opts.fan then
			base = -opts.fan + (i - 1) / math.max(opts.count - 1, 1) * opts.fan * 2
		else
			base = (i - 1) / opts.count * 360
		end
		local width = opts.width * (0.6 + 0.4 * ((i % 3) / 2))
		local ray = box(holder, {
			Name = "Ray",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(width, 0),
			BackgroundColor3 = opts.color,
			BackgroundTransparency = 1,
			Rotation = base,
			ZIndex = 1,
		})
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.55),
			NumberSequenceKeypoint.new(0.49, 0.05),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = ray
		local length = opts.length * (0.75 + math.random() * 0.4)
		table.insert(list, { frame = ray, base = base, length = length, phase = math.random() * 6 })
	end
	return { holder = holder, list = list, spin = opts.spin or 0, sway = opts.sway or 0, born = os.clock() }
end

local function showRays(group, time: number, transparency: number)
	for _, ray in ipairs(group.list) do
		tween(ray.frame, time, {
			Size = UDim2.fromOffset(ray.frame.Size.X.Offset, ray.length * 2),
			BackgroundTransparency = transparency,
		}, Enum.EasingStyle.Quart)
	end
end

local function colorRays(group, color: Color3, time: number?)
	for _, ray in ipairs(group.list) do
		if time and time > 0 then
			tween(ray.frame, time, { BackgroundColor3 = color })
		else
			ray.frame.BackgroundColor3 = color
		end
	end
end

local function hideRays(group, time: number)
	for _, ray in ipairs(group.list) do
		tween(ray.frame, time, { BackgroundTransparency = 1 })
	end
end

local function flash(s, color: Color3, strength: number, time: number)
	s.flash.BackgroundColor3 = color
	s.flash.BackgroundTransparency = 1 - strength
	tween(s.flash, time, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
end

local function shake(s, amount: number, time: number)
	s.shakeAmount = math.max(s.shakeAmount or 0, amount)
	s.shakeUntil = os.clock() + time
	s.shakeTime = time
end

-- ===== кадр =====

local function step(s)
	local now = os.clock()
	-- тряска холста
	if s.shakeUntil and now < s.shakeUntil then
		local k = (s.shakeUntil - now) / s.shakeTime
		local a = s.shakeAmount * k
		s.canvas.Position = UDim2.new(0.5, (math.random() * 2 - 1) * a, 0.5, (math.random() * 2 - 1) * a)
	elseif s.shakeUntil then
		s.shakeUntil = nil
		s.shakeAmount = 0
		s.canvas.Position = UDim2.fromScale(0.5, 0.5)
	end
	-- клинок парит
	if s.blade and s.blade.holder.Parent then
		local bob = s.blade.bob and math.sin(now * 2.4) * 5 or 0
		local jitter = s.blade.jitter or 0
		local p = s.blade.tip + Vector2.new((math.random() * 2 - 1) * jitter, bob + (math.random() * 2 - 1) * jitter)
		s.blade.holder.Position = at(p)
	end
	-- лучи
	for _, group in ipairs(s.rayGroups) do
		local t = now - group.born
		for _, ray in ipairs(group.list) do
			ray.frame.Rotation = ray.base + t * group.spin + math.sin(t * 0.9 + ray.phase) * group.sway
		end
	end
	-- частицы
	for i = #s.particles, 1, -1 do
		local p = s.particles[i]
		local e = (now - p.born) / p.life
		if e >= 1 or not p.frame.Parent then
			if p.frame.Parent then
				p.frame:Destroy()
			end
			table.remove(s.particles, i)
		else
			p.frame.Position = at(p.path(e))
			if e > 1 - p.fade then
				p.frame.BackgroundTransparency = p.alpha + (1 - p.alpha) * (e - (1 - p.fade)) / p.fade
			end
		end
	end
	-- пылинки памяти в воздухе
	s.moteClock = (s.moteClock or 0) + 1
	if s.moteClock % 7 == 0 and #s.particles < 220 then
		local x = math.random(80, 1520)
		local rise = math.random(160, 360)
		local drift = math.random(-40, 40)
		local start = Vector2.new(x, math.random(620, 920))
		particle(s, s.motes, s.palette[math.random(1, #s.palette)], math.random(1, 2) * 3, 2.6 + math.random() * 1.6, function(e)
			return start + Vector2.new(drift * e, -rise * e)
		end, 0.6, 0.35)
	end
	-- память течёт по спирали из сундука в клинок
	if s.reading and s.blade then
		s.readClock = (s.readClock or 0) + 1
		if s.readClock % 2 == 0 then
			local from = s.mouth + Vector2.new(math.random(-60, 60), math.random(-8, 8))
			local target = s.blade.tip - Vector2.new(0, BLADE_SIZE.Y * (0.25 + math.random() * 0.4))
			local a0 = math.random() * math.pi * 2
			local radius = 50 + math.random() * 70
			local color = math.random() < 0.5 and s.readColor or s.palette[math.random(1, #s.palette)]
			particle(s, s.fx, color, ({ 4, 6, 6, 8 })[math.random(1, 4)], 0.8 + math.random() * 0.5, function(e)
				local k = e * e * (3 - 2 * e)
				local base = from:Lerp(target, k)
				local r = radius * math.sin(e * math.pi) * (1 - e * 0.5)
				local ang = a0 + e * 7
				return base + Vector2.new(math.cos(ang) * r, math.sin(ang) * r * 0.45)
			end, 0.25)
		end
	end
end

-- ===== сцена =====

local function cleanup(s)
	if s.thread and coroutine.status(s.thread) ~= "dead" and s.thread ~= coroutine.running() then
		pcall(task.cancel, s.thread)
	end
	s.thread = nil
	if s.typer then
		s.typer.cancel()
		s.typer = nil
	end
	for _, connection in ipairs(s.conns) do
		connection:Disconnect()
	end
	table.clear(s.conns)
end

local function destroyScene(s)
	cleanup(s)
	if s.gui then
		s.gui:Destroy()
	end
end

local function unlock(s)
	ContextActionService:UnbindAction(ACTION)
	if s.blur then
		local blur = s.blur
		tween(blur, 0.3, { Size = 0 })
		task.delay(0.32, function()
			blur:Destroy()
		end)
		s.blur = nil
	end
	ClientState.lockInput("chestReveal", false)
	PixelHudController.setRevealActive(false)
	Bus.emit("hud", { visible = true })
end

local function close(s, after)
	if not s or s.phase == "closing" then
		return
	end
	s.phase = "closing"
	if scene == s then
		scene = nil
	end
	cleanup(s)
	UiMotion.fadeOut(s.root, 0.25)
	if s.view then
		tween(s.view, 0.25, { ImageTransparency = 1 })
	end
	if s.itemView then
		tween(s.itemView, 0.25, { ImageTransparency = 1 })
	end
	if s.armorView then
		tween(s.armorView, 0.25, { ImageTransparency = 1 })
	end
	task.delay(0.3, function()
		if s.gui then
			s.gui:Destroy()
		end
	end)
	unlock(s)
	Bus.emit("chestRevealClosed", { key = s.key, remaining = s.payload and s.payload.remaining or nil })
	if after then
		task.delay(0.35, after)
	end
end

local function label(parent, text: string, size: number, color: Color3, pos: Vector2, width: number, props)
	local l = PixelUi.label(parent, text, size, color, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = at(pos),
		Size = UDim2.fromOffset(width, size + 8),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 40,
	})
	if props then
		PixelUi.apply(l, props)
	end
	return l
end

local function buildScene(key: string, info, fromBag: boolean?)
	local s: any = {
		key = key,
		info = info,
		fromBag = fromBag,
		conns = {},
		particles = {},
		rayGroups = {},
		phase = "intro",
	}
	local floorColors = {}
	for i, value in ipairs(info.colors or {}) do
		floorColors[i] = hex(value, MEM)
	end
	s.floorColor = floorColors[1] or MEM
	s.accent = info.isBoss and GOLD or (floorColors[2] or MEM)
	s.palette = { MEM, s.floorColor, floorColors[3] or WHITE, floorColors[4] or MEM }
	s.readColor = MEM

	local gui, root = PixelUi.screen("KlinokChestReveal", 45)
	s.gui, s.root = gui, root
	s.dim = box(root, {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(6, 5, 10),
		BackgroundTransparency = 1,
		ZIndex = 1,
	})
	-- Скип-кнопка убрана (решение владельца 15.11: клик по интро ломал окно
	-- на долю секунды) — анимация «чтения памяти» досматривается целиком.
	local canvas = PixelUi.canvas(root)
	canvas.ZIndex = 3
	s.canvas = canvas
	s.flash = box(root, {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Active = false,
	})

	-- фон: сияние цвета этажа, пылинки
	s.backGlow = makeGlow(canvas, UDim2.fromOffset(800, 560), UDim2.fromOffset(1400, 1000), s.floorColor, 1, 2)
	s.motes = box(canvas, { Name = "Motes", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3 })

	-- заголовок
	s.title = PixelUi.label(canvas, (info.name or "Сундук"):upper(), 24, info.isBoss and GOLD or C.bone, {
		Position = UDim2.fromOffset(56, 34),
		Size = UDim2.fromOffset(700, 30),
		ZIndex = 40,
	})
	s.subtitle = PixelUi.label(canvas, ("Этаж %d · %s"):format(info.floor or 1, info.floorName or ""), 16, C.grey, {
		Position = UDim2.fromOffset(56, 68),
		Size = UDim2.fromOffset(700, 22),
		ZIndex = 40,
	})
	s.rarityLabel = label(canvas, "", 40, WHITE, Vector2.new(800, 34), 900)
	s.rarityScale = Instance.new("UIScale")
	s.rarityScale.Parent = s.rarityLabel
	s.hint = PixelUi.label(canvas, "КЛИК / ПРОБЕЛ — ПРОПУСТИТЬ", 16, C.grey, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromOffset(1560, 876),
		Size = UDim2.fromOffset(600, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = 0.3,
		ZIndex = 40,
	})

	-- сундук
	local designId = ChestModel.designId(info.floor, info.grade)
	local view, handle, camera = ChestVisual.viewport(canvas, designId, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at(VIEW_CENTER),
		Size = UDim2.fromOffset(VIEW_SIZE.X, VIEW_SIZE.Y),
		ZIndex = 10,
	}, { fill = 0.5 })
	s.view, s.handle, s.camera = view, handle, camera
	s.extent = ChestModel.extent(designId) * handle.scale

	-- точки сундука в покое (до падения): дно, рёбра, проём, замок
	ChestModel.place(handle, CFrame.new())
	local base2d = project(s, Vector3.zero)
	local left = project(s, Vector3.new(-s.extent.X / 2, 0, s.extent.Z / 2))
	local right = project(s, Vector3.new(s.extent.X / 2, 0, s.extent.Z / 2))
	s.base2d = base2d
	s.baseWidth = math.max((right - left).Magnitude, 120)
	s.mouth = project(s, Vector3.new(0, handle.design.hinge[1] * handle.scale, 0))
	s.lock2d = project(s, ChestModel.lockPoint(handle))
	ChestModel.place(handle, CFrame.new(0, s.extent.Y * 9, 0))

	s.shadow = box(canvas, {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at(base2d + Vector2.new(0, 6)),
		Size = UDim2.fromOffset(s.baseWidth * 1.15, 44),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 8,
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = s.shadow
	s.shadowScale = Instance.new("UIScale")
	s.shadowScale.Scale = 0.3
	s.shadowScale.Parent = s.shadow

	s.pillar = box(canvas, {
		Name = "Pillar",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(ITEM.X, 450),
		Size = UDim2.fromOffset(0, 1000),
		BackgroundTransparency = 1,
		ZIndex = 11,
	})
	local pillarGradient = Instance.new("UIGradient")
	pillarGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.35, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(0.65, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	pillarGradient.Parent = s.pillar

	s.fx = box(canvas, { Name = "Fx", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30 })

	-- шёпот памяти
	s.readTitle = label(canvas, "", 16, MEM, Vector2.new(800, 786), 1000)
	s.whisper = label(canvas, "", 24, C.bone, Vector2.new(800, 812), 1200)

	-- размытие мира
	local blur = Instance.new("BlurEffect")
	blur.Name = "KlinokChestBlur"
	blur.Size = 0
	blur.Parent = Lighting
	s.blur = blur
	tween(blur, 0.4, { Size = 18 })

	table.insert(s.conns, RunService.RenderStepped:Connect(function()
		step(s)
	end))
	return s
end

-- ===== Клинок Памяти =====

local function buildBlade(s)
	local holder = box(s.canvas, {
		Name = "MemoryBlade",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(BLADE_SIZE.X, BLADE_SIZE.Y),
		ZIndex = 20,
	})
	local glow = makeGlow(holder, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(BLADE_SIZE.X * 3.2, BLADE_SIZE.Y * 1.5), MEM, 1, 1)
	local blade: any = { holder = holder, glow = glow, cells = {}, channel = {}, tip = s.lock2d - Vector2.new(0, 90), bob = false }
	for r = 1, BLADE_H do
		local row = BLADE[r]
		for c = 1, BLADE_W do
			local ch = row:sub(c, c)
			local color = ChestDesigns.BladeColors[ch]
			if color then
				local home = Vector2.new((c - 1) * PX, (BLADE_H - r) * PX) -- остриё (строка 1) внизу
				local cell = box(holder, {
					Name = "Px",
					Position = at(home),
					Size = UDim2.fromOffset(PX, PX),
					BackgroundColor3 = hex(color, MEM),
					ZIndex = 2,
				})
				local entry = { frame = cell, home = home, row = r, ch = ch, color = cell.BackgroundColor3 }
				table.insert(blade.cells, entry)
				if ch == "f" or ch == "G" then
					table.insert(blade.channel, entry)
				end
			end
		end
	end
	s.blade = blade
	holder.Position = at(blade.tip)
	return blade
end

-- Квадраты слетаются со всех сторон: от рукояти к острию.
local function assembleBlade(s, blade, time: number)
	local center = BLADE_SIZE * 0.5
	for _, cell in ipairs(blade.cells) do
		local a = math.random() * math.pi * 2
		local d = 240 + math.random() * 340
		local from = center + Vector2.new(math.cos(a) * d, math.sin(a) * d * 0.7)
		cell.frame.Position = at(from)
		cell.frame.BackgroundTransparency = 1
		cell.frame.Rotation = math.random(-120, 120)
		cell.frame.BackgroundColor3 = MEM
		local delay = (BLADE_H - cell.row) / BLADE_H * time * 0.6 + math.random() * time * 0.15
		tween(cell.frame, time * 0.4, {
			Position = at(cell.home),
			BackgroundTransparency = 0,
			Rotation = 0,
			BackgroundColor3 = cell.color,
		}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, delay)
	end
end

local function setChannel(blade, color: Color3, time: number)
	for _, cell in ipairs(blade.channel) do
		tween(cell.frame, time, { BackgroundColor3 = color })
	end
	glowTo(blade.glow, 0, blade.glowT or 0.55, color)
end

-- ===== карточка находки =====

local function extrasOf(payload)
	local lines = {}
	local armor = payload.armor
	if type(armor) == "table" then
		local text = armor.echo and ("Броня: повторка «%s» — +1 эхо"):format(armor.name or "")
			or ("Броня: %s"):format(armor.name or "")
		table.insert(lines, { icon = "armor", text = text, color = rarityColor(armor.rarityId) })
	end
	local supplies = {}
	local supplyIcon
	for _, drop in ipairs(payload.items or {}) do
		if drop.accessory then
			table.insert(lines, {
				paper = drop.icon,
				icon = "ring",
				text = ("Аксессуар: %s"):format(drop.name or ""),
				color = rarityColor(drop.rarityId),
			})
		else
			supplyIcon = supplyIcon or drop.icon
			table.insert(supplies, ("%s ×%d"):format(drop.name or "", drop.count or 1))
		end
	end
	if #supplies > 0 then
		table.insert(lines, { paper = supplyIcon, icon = "flask", text = "Припасы: " .. table.concat(supplies, ", "), color = C.bone })
	end
	return lines
end

local function buildCard(s, payload)
	local card = box(s.canvas, {
		Name = "Card",
		BackgroundTransparency = 1,
		Position = at(CARD_POS),
		Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
		ZIndex = 22,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = card
	local color = rarityColor(payload.rarityId)
	makeGlow(card, UDim2.fromScale(0.5, 0.5), UDim2.new(1, 120, 1, 120), color, 0.55, 1)
	local panel = PixelUi.panel(card, UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), { z = 3 })
	local W = CARD_SIZE.X

	local function text(str: string, size: number, col: Color3, y: number, props)
		local l = PixelUi.label(panel, str, size, col, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, y),
			Size = UDim2.fromOffset(W - 48, size + 8),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 12,
		})
		if props then
			PixelUi.apply(l, props)
		end
		return l
	end

	text(("НАХОДКА · %s"):format((payload.chest and payload.chest.name or s.info.name or ""):upper()), 16, C.grey, 12)
	-- витрина
	local back = box(panel, {
		Name = "ViewBack",
		Position = UDim2.fromOffset(60, 36),
		Size = UDim2.fromOffset(W - 120, 268),
		BackgroundColor3 = color:Lerp(Color3.fromRGB(20, 14, 12), 0.72),
		ZIndex = 8,
	})
	local backGradient = Instance.new("UIGradient")
	backGradient.Rotation = 90
	backGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.55, 0),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	backGradient.Parent = back
	local backStroke = Instance.new("UIStroke")
	backStroke.Color = color
	backStroke.Thickness = 3
	backStroke.Parent = back

	local nameLabel = text((payload.name or ""):upper(), 32, color, 316, { TextWrapped = true })
	text(("%s · %s"):format(payload.rarityName or rarityName(payload.rarityId), payload.typeName or ""):upper(), 16, C.grey, 360)

	-- мощь
	text("МОЩЬ", 16, C.bone, 392)
	local power = math.floor((payload.rating or 1) * 100 + 0.5)
	local powerLabel = PixelUi.label(panel, "0", 40, GOLD, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, -6, 0, 414),
		Size = UDim2.fromOffset(220, 48),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 12,
	})
	local diff = ((payload.rating or 1) / math.max(payload.equippedRating or 1, 0.01) - 1) * 100
	local diffText, diffColor = "=", C.grey
	if diff > 0.5 then
		diffText, diffColor = ("+%d%%"):format(math.floor(diff + 0.5)), C.green
	elseif diff < -0.5 then
		diffText, diffColor = ("%d%%"):format(math.floor(diff - 0.5)), C.red
	end
	PixelUi.label(panel, diffText, 24, diffColor, {
		Position = UDim2.new(0.5, 10, 0, 424),
		Size = UDim2.fromOffset(200, 32),
		ZIndex = 12,
	})
	UiFx.countUp(powerLabel, 0, power, 0.7)
	text(payload.ability and ("Способность: " .. payload.ability) or "Без способности оружия", 16,
		payload.ability and GOLD or C.grey, 470)

	-- остальное содержимое
	local y = 504
	for _, line in ipairs(extrasOf(payload)) do
		local row = box(panel, { Name = "Extra", BackgroundTransparency = 1, Position = UDim2.fromOffset(40, y), Size = UDim2.fromOffset(W - 80, 30), ZIndex = 10 })
		if line.paper then
			PaperUi.itemIcon(row, line.paper, UDim2.fromOffset(14, 15), 28, { ZIndex = 12 })
		else
			PixelUi.icon(row, line.icon, UDim2.fromOffset(0, 1), 28, { ZIndex = 12 })
		end
		PixelUi.label(row, line.text, 16, line.color, {
			Position = UDim2.fromOffset(38, 3),
			Size = UDim2.fromOffset(W - 120, 24),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 12,
		})
		y += 32
	end
	-- золото и материал
	local reward = box(panel, { Name = "Reward", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y + 4), Size = UDim2.new(1, 0, 0, 32), ZIndex = 10 })
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = reward
	PixelUi.icon(reward, "coin", UDim2.new(), 28, { LayoutOrder = 1, ZIndex = 12 })
	PixelUi.label(reward, ("+%d"):format(payload.gold or 0), 16, GOLD, { Size = UDim2.fromOffset(90, 24), LayoutOrder = 2, ZIndex = 12 })
	PixelUi.icon(reward, "ingot", UDim2.new(), 28, { LayoutOrder = 3, ZIndex = 12 })
	local materialCount = payload.materialCount or payload.iron or 0
	local materialText = payload.materialName and ("%s +%d"):format(payload.materialName, materialCount) or ("+%d"):format(materialCount)
	PixelUi.label(reward, materialText, 16, C.bone, { Size = UDim2.fromOffset(220, 24), LayoutOrder = 4, ZIndex = 12 })

	local remaining = payload.remaining or 0
	if remaining > 0 then
		text(("В сумке ещё: %d"):format(remaining), 16, MEM, 650)
	end

	-- кнопки
	local buttons = {}
	local equip
	equip = PixelUi.button(panel, "gold", UDim2.fromOffset(0, 0), UDim2.fromOffset(10, 10), "НАДЕТЬ", function()
		if not equip.enabled then
			return
		end
		equip:setEnabled(false)
		local remote = Net.get("RequestEquip")
		local ok, response = pcall(function()
			return remote:InvokeServer(payload.index)
		end)
		if ok and type(response) == "table" and response.ok then
			equip:set("НАДЕТО")
			Bus.emit("notify", { kind = "campfire", text = "Оружие надето: " .. (payload.name or "") })
			task.delay(0.35, function()
				close(s)
			end)
		else
			equip:setEnabled(true)
			UiSound.play("error")
		end
	end, { glow = payload.better == true, z = 14 })
	table.insert(buttons, equip)
	table.insert(buttons, PixelUi.button(panel, "wood", UDim2.fromOffset(0, 0), UDim2.fromOffset(10, 10), "В СУМКУ", function()
		ChestRevealController.keep()
	end, { z = 14 }))
	if remaining > 0 then
		table.insert(buttons, PixelUi.button(panel, "mem", UDim2.fromOffset(0, 0), UDim2.fromOffset(10, 10), "ОТКРЫТЬ ЕЩЁ", function()
			ChestRevealController.again()
		end, { glow = true, z = 14 }))
	end
	local gap = 14
	local width = math.floor((W - 56 - gap * (#buttons - 1)) / #buttons)
	for i, button in ipairs(buttons) do
		button.holder.Position = UDim2.fromOffset(28 + (i - 1) * (width + gap), CARD_SIZE.Y - 90)
		button.holder.Size = UDim2.fromOffset(width, 60)
	end

	s.card = card
	s.cardScale = scale
	s.nameLabel = nameLabel
	return card
end

-- ===== этапы =====

local function dust(s, count: number)
	for _ = 1, count do
		local side = math.random() < 0.5 and -1 or 1
		local start = s.base2d + Vector2.new(side * s.baseWidth * (0.2 + math.random() * 0.35), math.random(-4, 6))
		local vx = side * (60 + math.random() * 160)
		local vy = -(20 + math.random() * 60)
		local color = (s.palette[math.random(2, #s.palette)]):Lerp(Color3.fromRGB(180, 170, 160), 0.5)
		particle(s, s.fx, color, ({ 4, 6, 8 })[math.random(1, 3)], 0.5 + math.random() * 0.4, function(e)
			local k = 1 - (1 - e) ^ 2
			return start + Vector2.new(vx * k, vy * k + 40 * e * e)
		end, 0.5)
	end
end

local function dropChest(s)
	local handle = s.handle
	local h0 = s.extent.Y * 9
	tween(s.shadow, 0.5, { BackgroundTransparency = 0.55 })
	tween(s.shadowScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	UiSound.play("chest_appear")
	run(0.5, function(a)
		local e = a * a
		ChestModel.place(handle, CFrame.new(0, h0 * (1 - e), 0) * CFrame.Angles(0, (1 - e) * 1.4, (1 - e) * 0.25))
	end)
	UiSound.play("chest_land")
	shake(s, s.info.isBoss and 14 or 9, 0.3)
	dust(s, s.info.isBoss and 26 or 18)
	if s.info.isBoss then
		UiFx.burst(s.fx, s.base2d - Vector2.new(0, 60), { GOLD, WHITE, s.floorColor }, 22, 180)
	end
	-- отскок
	local hop = s.extent.Y * 0.16
	run(0.28, function(a)
		ChestModel.place(handle, CFrame.new(0, math.sin(a * math.pi) * hop, 0))
	end)
	ChestModel.place(handle, CFrame.new())
end

local function formBlade(s)
	local blade = buildBlade(s)
	UiSound.play("blade_form")
	assembleBlade(s, blade, 1.0)
	glowTo(blade.glow, 0.6, 0.55, nil, 0.5)
	task.wait(1.0)
	blade.bob = true
	ring(s, blade.tip - Vector2.new(0, BLADE_SIZE.Y * 0.5), MEM, 60, 340, 0.5, 5)
	task.wait(0.25)
	return blade
end

local function strike(s, blade)
	blade.bob = false
	local hover = blade.tip
	local wind = s.lock2d - Vector2.new(0, 150)
	run(0.22, function(a)
		blade.tip = hover:Lerp(wind, ease(a, Enum.EasingStyle.Quad))
	end)
	task.wait(0.06)
	local hitAt = s.lock2d + Vector2.new(0, 8)
	run(0.08, function(a)
		blade.tip = wind:Lerp(hitAt, a * a)
	end)
	UiSound.play("blade_strike")
	flash(s, WHITE, 0.55, 0.3)
	shake(s, 16, 0.35)
	ChestModel.setGlow(s.handle, 1)
	UiFx.burst(s.fx, s.lock2d, { WHITE, MEM, s.accent }, 30, 170)
	ring(s, s.lock2d, MEM, 30, 260, 0.4, 6)
	ring(s, s.lock2d, s.accent, 20, 160, 0.3, 4)
	task.wait(0.32)
end

local function openLid(s, blade)
	local handle = s.handle
	local lidMax = handle.design.lidMax or 105
	local from = blade.tip
	UiSound.play("lid_open")
	s.chestRays = rays(s.canvas, s.mouth, { count = 9, fan = 58, width = 30, length = 520, color = s.floorColor, sway = 5, z = 9 })
	table.insert(s.rayGroups, s.chestRays)
	showRays(s.chestRays, 0.6, 0.35)
	glowTo(s.backGlow, 0.6, 0.7)
	run(0.6, function(a)
		blade.tip = from:Lerp(HOVER_TIP, ease(a, Enum.EasingStyle.Back))
		ChestModel.setLid(handle, lidMax * ease(math.min(a * 1.3, 1), Enum.EasingStyle.Quart))
	end)
	ChestModel.setLid(handle, lidMax)
	blade.bob = true
	UiFx.burst(s.fx, s.mouth, s.palette, 24, 160)
end

local function pulse(s, blade, id: string, index: number, final: boolean)
	local color = rarityColor(id)
	setChannel(blade, color, 0.1)
	glowTo(blade.glow, 0, 0.15, color)
	blade.glowT = final and 0.35 or 0.6
	glowTo(blade.glow, 0.35, blade.glowT)
	colorRays(s.chestRays, s.floorColor:Lerp(color, 0.7), 0.15)
	s.readColor = color
	ring(s, blade.tip - Vector2.new(0, BLADE_SIZE.Y * 0.45), color, 50, final and 420 or 260, 0.45, final and 8 or 5)
	s.rarityLabel.Text = rarityName(id):upper()
	s.rarityLabel.TextColor3 = color
	s.rarityScale.Scale = 1.3
	tween(s.rarityScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	UiSound.play("memory_tick", { pitch = 0.85 + 0.09 * index, gap = 0 })
	if final and Rarities.atLeast(id, "legendary") then
		shake(s, 8, 0.3)
		flash(s, color, 0.35, 0.35)
		UiFx.burst(s.fx, blade.tip - Vector2.new(0, BLADE_SIZE.Y * 0.45), { color, WHITE }, 26, 200)
	end
end

local function readMemory(s, blade, payload)
	s.reading = true
	s.readTitle.Text = "КЛИНОК ЧИТАЕТ ПАМЯТЬ"
	s.readTitle.TextTransparency = 1
	tween(s.readTitle, 0.3, { TextTransparency = 0 })
	s.typer = UiMotion.typewriter(s.whisper, ("«%s»"):format(s.info.whisper or "…"), { speed = 34 })
	task.wait(0.35)

	local target = Rarities.get(payload.rarityId or "common")
	local targetIndex = target and target.index or 1
	local secret = payload.rarityId == "secret"
	local last = secret and 5 or targetIndex
	for i = 1, last do
		pulse(s, blade, Rarities.order[i], i, i == targetIndex)
		task.wait(0.22 + 0.06 * i)
	end
	if secret then
		-- сбой: клинок дрожит, дол мерцает — и вспыхивает памятью
		blade.jitter = 3
		for k = 1, 6 do
			setChannel(blade, k % 2 == 0 and MEM or WHITE, 0.03)
			task.wait(0.07)
		end
		blade.jitter = 0
		task.wait(0.15)
		UiSound.play("memory_secret")
		pulse(s, blade, "secret", 6, true)
		flash(s, MEM, 0.5, 0.5)
		for k = 0, 2 do
			task.delay(k * 0.14, function()
				if s.fx.Parent then
					ring(s, blade.tip - Vector2.new(0, BLADE_SIZE.Y * 0.45), MEM, 40, 520 + k * 120, 0.6, 6)
				end
			end)
		end
		s.readTitle.Text = "ТАКОГО КЛИНОК ЕЩЁ НЕ ПОМНИЛ"
	end
	task.wait(0.5)
	s.reading = false
end

local function revealItem(s, blade, payload)
	local color = rarityColor(payload.rarityId)
	-- клинок рассыпается и квадраты собираются в находку
	local origin = blade.tip - BLADE_SIZE * Vector2.new(0.5, 1)
	for index, cell in ipairs(blade.cells) do
		local start = origin + cell.home + Vector2.one * (PX / 2)
		if index % 2 == 0 then
			local dir = (start - ITEM)
			if dir.Magnitude < 1 then
				dir = Vector2.new(0, -1)
			end
			local out = start + dir.Unit * (40 + math.random() * 120) + Vector2.new(math.random(-30, 30), math.random(-30, 30))
			local cellColor = cell.color:Lerp(color, 0.5)
			particle(s, s.fx, cellColor, PX, 0.55 + math.random() * 0.2, function(e)
				if e < 0.45 then
					return start:Lerp(out, ease(e / 0.45, Enum.EasingStyle.Quad))
				end
				return out:Lerp(ITEM, ease((e - 0.45) / 0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.In))
			end, 0.2)
		end
	end
	blade.holder:Destroy()
	s.blade = nil
	hideRays(s.chestRays, 0.5)
	task.wait(0.55)

	-- находка
	UiSound.play("item_reveal")
	flash(s, color, 0.45, 0.4)
	shake(s, 6, 0.25)
	s.itemView.Visible = true
	s.itemScale.Scale = 0.15
	tween(s.itemScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	s.pillar.BackgroundColor3 = color
	s.pillar.BackgroundTransparency = 0
	tween(s.pillar, 0.5, { Size = UDim2.fromOffset(220, 1000) }, Enum.EasingStyle.Quart)
	s.itemRays = rays(s.canvas, ITEM, { count = 12, width = 40, length = 460, color = color, spin = 10, z = 12 })
	table.insert(s.rayGroups, s.itemRays)
	showRays(s.itemRays, 0.6, 0.55)
	ring(s, ITEM, color, 60, 520, 0.6, 8)
	UiFx.burst(s.fx, ITEM, { color, WHITE, MEM }, 34, 240)
	task.wait(0.7)
end

-- Броня в витрине: оружие уходит влево, справа — манекен в выпавшем комплекте.
local WEAPON_SIDE = ITEM + Vector2.new(-112, 0)
local ARMOR_SIDE = ITEM + Vector2.new(126, -10)
local function showArmor(s, payload, instant: boolean)
	local armor = payload.armor
	if type(armor) ~= "table" or type(armor.setId) ~= "string" or s.armorView then
		return
	end
	local time = instant and 0 or 0.4
	tween(s.itemView, time, { Position = at(WEAPON_SIDE), Size = UDim2.fromOffset(300, 270) }, Enum.EasingStyle.Quart)
	local color = rarityColor(armor.rarityId)
	local view = ArmorView.new(s.canvas, armor.setId, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at(ARMOR_SIDE),
		Size = UDim2.fromOffset(200, 236),
		ZIndex = 25,
	})
	s.armorView = view
	local pop = Instance.new("UIScale")
	pop.Scale = instant and 1 or 0.2
	pop.Parent = view
	if not instant then
		tween(pop, 0.45, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.15)
		ring(s, ARMOR_SIDE, color, 30, 220, 0.5, 6)
		UiSound.play("item_reveal", { pitch = 0.92, volume = 0.6 })
	end
	-- подпись под манекеном: редкость брони (или «повторка»)
	local caption = armor.echo and "ПОВТОРКА · +1 ЭХО" or ("БРОНЯ · " .. rarityName(armor.rarityId):upper())
	s.armorCaption = label(s.canvas, caption, 16, color, ARMOR_SIDE + Vector2.new(0, 112), 220)
end

-- Итог: всё по местам (и после пропуска).
local function showCard(s, instant: boolean)
	if s.phase == "card" or s.phase == "closing" then
		return
	end
	s.phase = "card"
	local payload = s.payload
	local color = rarityColor(payload.rarityId)
	s.reading = false
	if s.typer then
		s.typer.skip()
	end
	if instant then
		for _, child in ipairs(s.fx:GetChildren()) do
			child:Destroy()
		end
		table.clear(s.particles)
		if s.blade then
			s.blade.holder:Destroy()
			s.blade = nil
		end
		ChestModel.place(s.handle, CFrame.new())
		ChestModel.setLid(s.handle, s.handle.design.lidMax or 105)
		if s.chestRays then
			hideRays(s.chestRays, 0.2)
		end
		s.dim.BackgroundTransparency = 0.18
		s.shadow.BackgroundTransparency = 0.55
		s.shadowScale.Scale = 1
		s.rarityLabel.Text = rarityName(payload.rarityId):upper()
		s.rarityLabel.TextColor3 = color
		s.pillar.BackgroundColor3 = color
		s.pillar.BackgroundTransparency = 0
		s.pillar.Size = UDim2.fromOffset(220, 1000)
		if not s.itemRays then
			s.itemRays = rays(s.canvas, ITEM, { count = 12, width = 40, length = 460, color = color, spin = 10, z = 12 })
			table.insert(s.rayGroups, s.itemRays)
			showRays(s.itemRays, 0.3, 0.55)
		end
		s.itemView.Visible = true
		s.itemScale.Scale = 1
		UiSound.play("item_reveal")
		flash(s, color, 0.3, 0.3)
	end
	s.hint.Visible = false
	-- сундук уходит вниз, поверх — карточка
	tween(s.view, 0.4, { Position = UDim2.fromOffset(VIEW_CENTER.X, VIEW_CENTER.Y + 380), ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(s.shadow, 0.3, { BackgroundTransparency = 1 })
	tween(s.readTitle, 0.3, { TextTransparency = 1 })
	tween(s.whisper, 0.3, { TextTransparency = 1 })
	for _, l in ipairs({ s.readTitle, s.whisper }) do
		local stroke = l:FindFirstChildOfClass("UIStroke")
		if stroke then
			tween(stroke, 0.3, { Transparency = 1 })
		end
	end
	tween(s.pillar, 0.6, { BackgroundTransparency = 0.45 })
	local card = buildCard(s, payload)
	showArmor(s, payload, instant)
	s.cardScale.Scale = 0.86
	card.Position = at(CARD_POS + Vector2.new(0, 40))
	tween(card, 0.45, { Position = at(CARD_POS) }, Enum.EasingStyle.Back)
	tween(s.cardScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	UiMotion.fadeIn(card, 0.25)
	Bus.emit("chestRevealed", { key = s.key, rarityId = payload.rarityId })
end

local function timeline(s)
	tween(s.dim, 0.35, { BackgroundTransparency = 0.18 })
	glowTo(s.backGlow, 0.6, 0.82)
	task.wait(0.3)
	dropChest(s)
	task.wait(0.15)
	local blade = formBlade(s)
	strike(s, blade)
	openLid(s, blade)
	-- ответ сервера (бросок сделан в самом начале)
	local waited = 0
	while s.result == nil and waited < 10 do
		waited += task.wait()
	end
	local payload = s.result
	if type(payload) ~= "table" or not payload.ok then
		s.reading = false
		s.readTitle.Text = "ЗАМОК НЕ ПОДДАЛСЯ"
		s.readTitle.TextColor3 = C.red
		s.whisper.Text = (type(payload) == "table" and payload.text) or "Сундук остался в сумке — попробуйте ещё раз"
		UiSound.play("error")
		task.wait(1.6)
		close(s)
		return
	end
	s.payload = payload
	s.fill({ id = payload.id, typeId = payload.typeId })
	readMemory(s, blade, payload)
	revealItem(s, blade, payload)
	showCard(s, false)
end

-- ===== вход =====

local function bindKeys()
	ContextActionService:BindActionAtPriority(ACTION, function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end
		local s = scene
		if not s then
			return Enum.ContextActionResult.Pass
		end
		if s.phase == "card" then
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonB then
				ChestRevealController.keep()
			end
		end
		-- скип интро убран (решение владельца): анимация досматривается целиком
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 200,
		Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.Escape, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB)
end

function ChestRevealController.isOpen(): boolean
	return scene ~= nil
end

-- Пропустить анимацию — сразу карточка (если сервер уже ответил).
function ChestRevealController.skip()
	local s = scene
	if not s or s.phase ~= "intro" then
		return
	end
	if type(s.result) ~= "table" then
		return -- ответа ещё нет — досмотрим
	end
	if not s.result.ok then
		close(s)
		return
	end
	s.payload = s.result
	cleanup(s)
	-- кадр снова живёт (cleanup снял RenderStepped)
	table.insert(s.conns, RunService.RenderStepped:Connect(function()
		step(s)
	end))
	s.fill({ id = s.payload.id, typeId = s.payload.typeId })
	showCard(s, true)
end

-- «В сумку»: закрыть; из сумки — вернуться в неё.
function ChestRevealController.keep()
	local s = scene
	if not s then
		return
	end
	local fromBag = s.fromBag
	local remaining = s.payload and s.payload.remaining or 0
	close(s, fromBag and function()
		Bus.emit("openStation", { name = "Inventory", tab = "gear", category = remaining > 0 and "chests" or "weapons" })
	end or nil)
end

function ChestRevealController.open(key: string, fromBag: boolean?)
	if type(key) ~= "string" then
		return false
	end
	local current = scene
	if current and current.phase ~= "card" then
		return false
	end
	if player:GetAttribute("Zone") == "Floor" then
		Bus.emit("notify", { kind = "warn", text = "Сундуки открываются в долине" })
		UiSound.play("error")
		return false
	end
	local floorId, grade = Chests.parse(key)
	if not floorId then
		return false
	end
	local info = Chests.info(floorId, grade)
	local wasOpen = current ~= nil
	if current then
		-- «Открыть ещё»: прошлая сцена уходит мгновенно, блокировки остаются
		current.phase = "closing"
		destroyScene(current)
		if current.blur then
			current.blur:Destroy()
			current.blur = nil
		end
		scene = nil
	end

	local s = buildScene(key, info, fromBag)
	scene = s
	local itemView, fill = Ui.weaponView(s.canvas, nil, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at(ITEM),
		Size = UDim2.fromOffset(440, 300),
		ZIndex = 25,
		Visible = false,
	}, { spin = true })
	s.itemView, s.fill = itemView, fill
	s.itemScale = Instance.new("UIScale")
	s.itemScale.Parent = itemView

	if not wasOpen then
		ClientState.lockInput("chestReveal", true)
		PixelHudController.setRevealActive(true)
		Bus.emit("hud", { visible = false })
		bindKeys()
	end
	s.hit.Activated:Connect(function()
		ChestRevealController.skip()
	end)

	-- сервер бросает содержимое сразу; сцена ждёт ответ к «чтению памяти»
	task.spawn(function()
		local result = StationApi.chests.open(key)
		if scene ~= s and s.phase == "closing" then
			return
		end
		s.result = result or { ok = false, text = "Нет связи с сервером — сундук остался в сумке" }
	end)
	s.thread = task.spawn(timeline, s)
	return true
end

function ChestRevealController.again()
	local s = scene
	if not s or not s.payload or (s.payload.remaining or 0) <= 0 then
		return
	end
	ChestRevealController.open(s.key, s.fromBag)
end

function ChestRevealController.start()
	Bus.on("chestReveal", function(data)
		if type(data) == "table" then
			ChestRevealController.open(data.key, data.fromBag)
		end
	end)
	player.CharacterAdded:Connect(function()
		if scene then
			close(scene)
		end
	end)
	print("[ChestRevealController] сцена «Клинок читает память»")
end

return ChestRevealController
