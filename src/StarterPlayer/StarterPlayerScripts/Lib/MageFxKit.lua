--!nonstrict
-- MageFxKit (клиент)
-- Конструктор эффектов мага кодом, без шаблонов FX (их не надо собирать в Studio):
--   * магические круги — плоская деталь + SurfaceGui на верхней грани (LightInfluence 0,
--     Brightness > 1 — светятся сами и дают bloom): кольца (Frame + UICorner + UIStroke), руны
--     (TextLabel, греческие буквы), гексаграмма из Frame-линий, деления циферблата; слои —
--     отдельные детали, крутятся CFrame в разные стороны;
--   * неоновые шары и купола (Neon / ForceField), столбы света, лучи (Beam), молнии (ломаная
--     из неоновых брусков), разломы на земле, ударные волны и кольца, вспышки PointLight;
--   * частицы на текстурах FxTex (glow, spark, star, ring, smoke, rock, swirl, wind, slash,
--     trail, crack).
-- Всё гаснет и убирается само (Kit.every — один RenderStepped на все анимации).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Bus = require(script.Parent.Bus)
local FxTex = require(script.Parent.FxTex)

local Kit = {}
Kit.Tex = FxTex

local V3 = Vector3.new
local UP = V3(0, 1, 0)
local SHAKE_RANGE = 70

Kit.GLYPHS = { "Α", "Β", "Γ", "Δ", "Ε", "Ζ", "Η", "Θ", "Λ", "Ξ", "Π", "Σ", "Φ", "Ψ", "Ω", "Χ" }
Kit.ROMAN = { "XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI" }

-- ===== Папка, цвета, звук, тряска =====

local holderFolder
function Kit.folder()
	if holderFolder and holderFolder.Parent then
		return holderFolder
	end
	holderFolder = Workspace:FindFirstChild("KlinokMageFx")
	if not holderFolder then
		holderFolder = Instance.new("Folder")
		holderFolder.Name = "KlinokMageFx"
		holderFolder.Parent = Workspace
	end
	return holderFolder
end

local colorCache = {}
function Kit.color(value, fallback: Color3?): Color3
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "string" then
		local cached = colorCache[value]
		if cached then
			return cached
		end
		local ok, color = pcall(Color3.fromHex, value)
		if ok then
			colorCache[value] = color
			return color
		end
	end
	return fallback or Color3.new(1, 1, 1)
end

function Kit.sfx(name: string, position: Vector3?, volume: number?)
	Bus.emit("sfx", { name = name, position = position, volume = volume })
end

function Kit.shake(position: Vector3?, amount: number, time: number)
	local camera = Workspace.CurrentCamera
	if not position or (camera and (camera.CFrame.Position - position).Magnitude <= SHAKE_RANGE) then
		Bus.emit("shake", { amount = amount, time = time })
	end
end

-- ===== Анимации кадрами =====
-- step(k, t, dt): k = t / duration (0..1). Вернуть false — остановить раньше.

local tasks = {}
local loop = nil

local function runTasks(dt: number)
	local keep = {}
	for _, item in ipairs(tasks) do
		item.t += dt
		local k = math.clamp(item.t / item.duration, 0, 1)
		local ok, result = pcall(item.step, k, item.t, dt)
		if not ok then
			warn("[MageFxKit] " .. tostring(result))
		end
		if ok and result ~= false and k < 1 then
			table.insert(keep, item)
		elseif item.done then
			pcall(item.done)
		end
	end
	tasks = keep
	if #tasks == 0 and loop then
		loop:Disconnect()
		loop = nil
	end
end

function Kit.every(duration: number, step, done)
	table.insert(tasks, { t = 0, duration = math.max(duration, 1e-3), step = step, done = done })
	if not loop then
		loop = RunService.RenderStepped:Connect(runTasks)
	end
end

function Kit.after(delay: number, fn)
	if delay <= 0 then
		task.spawn(fn)
	else
		task.delay(delay, fn)
	end
end

local function ease(k: number, style: string?): number
	if style == "out" then
		return 1 - (1 - k) ^ 3
	elseif style == "in" then
		return k ^ 3
	elseif style == "inout" then
		return k < 0.5 and 4 * k ^ 3 or 1 - (-2 * k + 2) ^ 3 / 2
	elseif style == "back" then
		local c = 1.70158
		return 1 + (c + 1) * (k - 1) ^ 3 + c * (k - 1) ^ 2
	end
	return k
end
Kit.ease = ease

-- ===== Детали =====

function Kit.part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = V3(1, 1, 1)
	for key, value in pairs(props or {}) do
		p[key] = value
	end
	if not (props and props.Parent) then
		p.Parent = Kit.folder()
	end
	return p
end

function Kit.holder(cframe)
	local p = Kit.part({ Size = V3(0.2, 0.2, 0.2), Transparency = 1, Name = "MageFxHolder" })
	p.CFrame = typeof(cframe) == "Vector3" and CFrame.new(cframe) or (cframe or CFrame.new())
	return p
end

function Kit.ball(position: Vector3, diameter: number, color: Color3, props)
	local p = Kit.part({ Shape = Enum.PartType.Ball, Size = V3(diameter, diameter, diameter), Color = color, Name = "MageBall" })
	p.CFrame = CFrame.new(position)
	for key, value in pairs(props or {}) do
		p[key] = value
	end
	return p
end

function Kit.tween(instance: Instance, time: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local tween = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

-- Погасить деталь (и растянуть/сжать) и удалить.
function Kit.fade(part: BasePart, time: number, goal)
	local target = { Transparency = 1 }
	for key, value in pairs(goal or {}) do
		target[key] = value
	end
	Kit.tween(part, time, target)
	Debris:AddItem(part, time + 0.05)
end

function Kit.light(parent: Instance, color: Color3, brightness: number, range: number, life: number?)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = parent
	if life then
		Kit.tween(light, life, { Brightness = 0 })
		Debris:AddItem(light, life + 0.05)
	end
	return light
end

-- Вспышка: неоновый шар раздувается и гаснет + короткий свет.
function Kit.flash(position: Vector3, color: Color3, size: number, time: number?)
	local life = time or 0.22
	local ball = Kit.ball(position, size * 0.5, color, { Transparency = 0.05 })
	Kit.fade(ball, life, { Size = V3(size, size, size) * 1.4 })
	Kit.light(ball, color, 5, math.clamp(size * 3, 8, 40), life)
	return ball
end

-- ===== Частицы =====

local function numberSeq(value, default)
	if typeof(value) == "NumberSequence" then
		return value
	end
	if type(value) == "number" then
		return NumberSequence.new(value)
	end
	if type(value) == "table" then
		if #value == 2 then
			return NumberSequence.new(value[1], value[2])
		end
		local points = {}
		for i, v in ipairs(value) do
			table.insert(points, NumberSequenceKeypoint.new((i - 1) / (#value - 1), v))
		end
		return NumberSequence.new(points)
	end
	return default
end

local function colorSeq(value)
	if typeof(value) == "ColorSequence" then
		return value
	end
	if typeof(value) == "Color3" then
		return ColorSequence.new(value)
	end
	if type(value) == "table" then
		if #value == 2 then
			return ColorSequence.new(Kit.color(value[1]), Kit.color(value[2]))
		end
		local points = {}
		for i, v in ipairs(value) do
			table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#value - 1), Kit.color(v)))
		end
		return ColorSequence.new(points)
	end
	return ColorSequence.new(Color3.new(1, 1, 1))
end

local function range(value, a, b)
	if type(value) == "number" then
		return NumberRange.new(value)
	end
	if type(value) == "table" then
		return NumberRange.new(value[1], value[2] or value[1])
	end
	return NumberRange.new(a, b)
end

-- o: texture (имя в FxTex или id), color, size, transparency, life, speed, rate, spread, lightEmission,
--    drag, accel, rotation, rotSpeed, zoffset, shape, shapeStyle, direction, orientation, squash, locked.
function Kit.emitter(parent: Instance, o)
	local e = Instance.new("ParticleEmitter")
	e.Texture = FxTex[o.texture or "glow"] or o.texture or FxTex.glow
	e.Color = colorSeq(o.color)
	e.Size = numberSeq(o.size, NumberSequence.new(1, 0))
	e.Transparency = numberSeq(o.transparency, NumberSequence.new(0, 1))
	e.Lifetime = range(o.life, 0.4, 0.8)
	e.Speed = range(o.speed, 2, 6)
	e.Rate = o.rate or 0
	local spread = o.spread or 180
	e.SpreadAngle = type(spread) == "number" and Vector2.new(spread, spread) or spread
	e.LightEmission = o.lightEmission or 1
	e.LightInfluence = o.lightInfluence or 0
	e.Drag = o.drag or 0
	e.Acceleration = o.accel or Vector3.zero
	e.Rotation = range(o.rotation, 0, 360)
	e.RotSpeed = range(o.rotSpeed, -90, 90)
	e.ZOffset = o.zoffset or 0
	e.Brightness = o.brightness or 1.5
	if o.shape then
		e.Shape = o.shape
	end
	if o.shapeStyle then
		e.ShapeStyle = o.shapeStyle
	end
	if o.direction then
		e.EmissionDirection = o.direction
	end
	if o.orientation then
		e.Orientation = o.orientation
	end
	if o.squash then
		e.Squash = numberSeq(o.squash, NumberSequence.new(0))
	end
	e.LockedToPart = o.locked == true
	e.Enabled = (o.rate or 0) > 0
	e.Parent = parent
	return e
end

-- Разовый выброс частиц в точке. o.count, o.radius (объём), + поля emitter.
function Kit.burst(position: Vector3, o)
	local radius = o.radius or 0.3
	local holder = Kit.part({ Size = V3(radius * 2, radius * 2, radius * 2), Transparency = 1, Shape = Enum.PartType.Ball, Name = "MageBurst" })
	holder.CFrame = typeof(position) == "CFrame" and position or CFrame.new(position)
	local opts = table.clone(o)
	opts.rate = 0
	opts.shape = opts.shape or Enum.ParticleEmitterShape.Sphere
	local e = Kit.emitter(holder, opts)
	e:Emit(o.count or 12)
	local life = type(o.life) == "table" and (o.life[2] or o.life[1]) or (o.life or 0.8)
	Debris:AddItem(holder, life + 0.3)
	return e
end

-- Непрерывные частицы у точки на время life.
function Kit.stream(position, o, life: number)
	local holder = Kit.part({ Size = V3(0.2, 0.2, 0.2), Transparency = 1, Name = "MageStream" })
	holder.CFrame = typeof(position) == "CFrame" and position or CFrame.new(position)
	if o.size3 then
		holder.Size = o.size3
	end
	local e = Kit.emitter(holder, o)
	task.delay(life, function()
		e.Enabled = false
	end)
	local tail = type(o.life) == "table" and (o.life[2] or o.life[1]) or (o.life or 0.8)
	Debris:AddItem(holder, life + tail + 0.2)
	return e, holder
end

-- ===== Плоскости с картинкой и круги (SurfaceGui на верхней грани) =====

local function surface(part: BasePart, brightness: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(512, 512)
	gui.LightInfluence = 0
	gui.Brightness = brightness or 2.5
	gui.AlwaysOnTop = false
	gui.ClipsDescendants = false
	gui.Adornee = part
	gui.Parent = part
	return gui
end
Kit.surface = surface

-- Плоская картинка на земле (кольцо, свечение, разлом). Возвращает part, image.
function Kit.plane(cframe: CFrame, size: number, image: string?, color: Color3, o)
	o = o or {}
	local part = Kit.part({ Size = V3(size, 0.05, size), Transparency = 1, Name = "MagePlane" })
	part.CFrame = cframe
	local gui = surface(part, o.brightness)
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Image = FxTex[image or "glow"] or image or FxTex.glow
	label.ImageColor3 = color
	label.ImageTransparency = o.transparency or 0
	label.Rotation = o.rotation or 0
	label.Parent = gui
	return part, label
end

-- Кольцо-волна по земле: растёт до radius и гаснет.
function Kit.ringWave(position: Vector3, radius: number, color: Color3, o)
	o = o or {}
	local time = o.time or 0.4
	local start = o.from or 0.6
	local part, label = Kit.plane(CFrame.new(position + V3(0, o.lift or 0.12, 0)), start * 2, o.image or "ring", color,
		{ brightness = o.brightness or 3, transparency = o.transparency or 0 })
	local base = o.transparency or 0
	Kit.every(time, function(k)
		local e = ease(k, "out")
		local d = (start + (radius - start) * e) * 2
		part.Size = V3(d, 0.05, d)
		label.ImageTransparency = base + (1 - base) * (k ^ 1.6)
	end, function()
		part:Destroy()
	end)
	return part
end

-- Свечение на земле (пятно) на время life.
function Kit.glowSpot(position: Vector3, radius: number, color: Color3, life: number, o)
	o = o or {}
	local part, label = Kit.plane(CFrame.new(position + V3(0, o.lift or 0.08, 0)), radius * 2, o.image or "glow", color,
		{ brightness = o.brightness or 2, transparency = 1 })
	local peak = o.transparency or 0.25
	Kit.every(life, function(k)
		local fadeIn = math.clamp(k * life / 0.15, 0, 1)
		local fadeOut = math.clamp((1 - k) * life / 0.35, 0, 1)
		label.ImageTransparency = 1 - (1 - peak) * math.min(fadeIn, fadeOut)
	end, function()
		part:Destroy()
	end)
	return part, label
end

-- Элементы GUI, которым надо менять прозрачность вместе (затухание круга).
local function track(list, instance, prop: string)
	table.insert(list, { instance = instance, prop = prop, base = instance[prop] })
end

local function ringFrame(parent, scale: number, color: Color3, thickness: number, transparency: number, list)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(scale, scale)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	track(list, stroke, "Transparency")
	return frame, stroke
end

local function line(parent, x0: number, y0: number, x1: number, y1: number, color: Color3, px: number, transparency: number, list)
	local dx, dy = x1 - x0, y1 - y0
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale((x0 + x1) / 2, (y0 + y1) / 2)
	frame.Size = UDim2.new(math.sqrt(dx * dx + dy * dy), 0, 0, px)
	frame.Rotation = math.deg(math.atan2(dy, dx))
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	frame.Parent = parent
	track(list, frame, "BackgroundTransparency")
	return frame
end
Kit.guiLine = line

local function glyph(parent, text: string, x: number, y: number, size: number, rotation: number, color: Color3, transparency: number, list)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(x, y)
	label.Size = UDim2.fromScale(size, size)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.TextColor3 = color
	label.TextTransparency = transparency
	label.TextStrokeTransparency = 1
	label.Rotation = rotation
	label.Parent = parent
	track(list, label, "TextTransparency")
	return label
end

-- Многоугольник/звезда линиями: n вершин на радиусе r (доля холста), шаг step (2 — звезда).
local function polygon(parent, n: number, r: number, step: number, rotation: number, color: Color3, px: number, transparency: number, list)
	local points = {}
	for i = 0, n - 1 do
		local a = rotation + i * math.pi * 2 / n
		points[i] = { 0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r }
	end
	for i = 0, n - 1 do
		local a, b = points[i], points[(i + step) % n]
		line(parent, a[1], a[2], b[1], b[2], color, px, transparency, list)
	end
end

-- Магический круг. o: duration (сам погаснет), spin/innerSpin (°/с), glyphs (список), count,
-- hexagram (true), star (n вершин, по умолчанию 6), ticks (деления), roman (циферблат),
-- inner (цвет внутреннего слоя), brightness, lift, appear, fill (прозрачность заливки), thick.
-- Возвращает handle: { parts, alive, fade(time), destroy(), pulse(k), setSpin(outer, inner) }.
function Kit.circle(position: Vector3, radius: number, color: Color3, o)
	o = o or {}
	local inner = o.inner or color:Lerp(Color3.new(1, 1, 1), 0.35)
	local d = radius * 2
	local lift = o.lift or 0.1
	local base = CFrame.new(position + V3(0, lift, 0))
	local thick = o.thick or 7
	local elements = {}
	local parts = {}

	-- Заливка: мягкое свечение под кругом.
	local fillPart, fillLabel = Kit.plane(base, d * 1.05, "glow", color, { brightness = (o.brightness or 2.5) * 0.6, transparency = o.fill or 0.55 })
	track(elements, fillLabel, "ImageTransparency")
	table.insert(parts, { part = fillPart, spin = 0 })

	-- Внешний слой: двойное кольцо и руны между кольцами.
	local outer = Kit.part({ Size = V3(d, 0.05, d), Transparency = 1, Name = "MageCircleOuter" })
	outer.CFrame = base * CFrame.new(0, 0.01, 0)
	local outerGui = surface(outer, o.brightness)
	ringFrame(outerGui, 0.985, color, thick, 0, elements)
	ringFrame(outerGui, 0.83, color, thick * 0.7, 0.1, elements)
	ringFrame(outerGui, 0.79, inner, thick * 0.35, 0.35, elements)
	local glyphs = o.glyphs or Kit.GLYPHS
	local count = o.count or 12
	if o.roman then
		glyphs = Kit.ROMAN
		count = 12
	end
	for i = 1, count do
		local a = (i - 1) / count * math.pi * 2 - math.pi / 2
		local r = 0.455
		glyph(outerGui, glyphs[(i - 1) % #glyphs + 1], 0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r, o.roman and 0.085 or 0.07,
			math.deg(a) + 90, color, 0, elements)
	end
	if o.ticks then
		for i = 1, o.ticks do
			local a = (i - 1) / o.ticks * math.pi * 2
			local r0, r1 = 0.36, (i - 1) % 3 == 0 and 0.4 or 0.385
			line(outerGui, 0.5 + math.cos(a) * r0, 0.5 + math.sin(a) * r0, 0.5 + math.cos(a) * r1, 0.5 + math.sin(a) * r1, inner, 4, 0.1, elements)
		end
	end
	table.insert(parts, { part = outer, spin = math.rad(o.spin or 35) })

	-- Внутренний слой: звезда (гексаграмма) и малые кольца.
	local innerPart = Kit.part({ Size = V3(d, 0.05, d), Transparency = 1, Name = "MageCircleInner" })
	innerPart.CFrame = base * CFrame.new(0, 0.02, 0)
	local innerGui = surface(innerPart, o.brightness)
	if o.hexagram ~= false then
		local n = o.star or 6
		if n == 6 then
			polygon(innerGui, 3, 0.37, 1, -math.pi / 2, inner, thick * 0.6, 0.05, elements)
			polygon(innerGui, 3, 0.37, 1, math.pi / 2, inner, thick * 0.6, 0.05, elements)
		else
			polygon(innerGui, n, 0.37, 2, -math.pi / 2, inner, thick * 0.6, 0.05, elements)
		end
	end
	ringFrame(innerGui, 0.42, inner, thick * 0.5, 0.15, elements)
	ringFrame(innerGui, 0.16, color, thick * 0.5, 0.1, elements)
	table.insert(parts, { part = innerPart, spin = math.rad(o.innerSpin or -(o.spin or 35) * 1.6) })

	local handle = { parts = parts, alive = true, position = position, radius = radius, elements = elements }
	local scale = 0.15
	local opacity = 0 -- 0..1 множитель видимости
	local fading = nil
	local pulse = 0
	local angle = 0
	local appear = o.appear or 0.28

	local function apply()
		for _, entry in ipairs(elements) do
			if entry.instance.Parent then
				entry.instance[entry.prop] = 1 - (1 - entry.base) * opacity
			end
		end
	end

	function handle.fade(time: number?)
		if not handle.alive or fading then
			return
		end
		fading = { t = 0, time = time or 0.4 }
	end
	function handle.destroy()
		handle.alive = false
		for _, entry in ipairs(parts) do
			entry.part:Destroy()
		end
	end
	function handle.pulse(amount: number?)
		pulse = math.max(pulse, amount or 0.12)
	end
	function handle.setSpin(outerSpin: number?, innerSpin: number?)
		if outerSpin then
			parts[2].spin = math.rad(outerSpin)
		end
		if innerSpin then
			parts[3].spin = math.rad(innerSpin)
		end
	end

	local life = math.min(o.duration or 12, 30)
	local born = 0
	Kit.every(life + 2, function(_, t, dt)
		if not handle.alive then
			return false
		end
		born = t
		if fading then
			fading.t += dt
			opacity = math.clamp(1 - fading.t / fading.time, 0, 1)
			scale += dt * 0.15
			if opacity <= 0 then
				return false
			end
		else
			opacity = math.clamp(t / appear, 0, 1)
			scale = 0.15 + 0.85 * ease(math.clamp(t / appear, 0, 1), "back")
			if t >= life then
				handle.fade(0.45)
			end
		end
		pulse = math.max(pulse - dt * 0.8, 0)
		angle += dt
		local s = d * (scale + pulse)
		for _, entry in ipairs(parts) do
			if entry.part.Parent then
				entry.part.Size = V3(s, 0.05, s)
				entry.part.CFrame = base * CFrame.new(0, entry.part == parts[1].part and 0 or 0.01, 0) * CFrame.Angles(0, entry.spin * angle, 0)
			end
		end
		apply()
		return true
	end, function()
		handle.destroy()
	end)
	local _ = born
	return handle
end

-- ===== Купола, волны, взрывы =====

-- Купол/сфера ForceField (переливается сама).
function Kit.dome(position: Vector3, radius: number, color: Color3, props)
	local d = radius * 2
	local ball = Kit.ball(position, d, color, { Material = Enum.Material.ForceField, Transparency = 0, Name = "MageDome" })
	for key, value in pairs(props or {}) do
		ball[key] = value
	end
	return ball
end

-- Ударная волна: сфера ForceField + кольцо по земле.
function Kit.shockwave(position: Vector3, radius: number, color: Color3, o)
	o = o or {}
	local time = o.time or 0.42
	local ball = Kit.dome(position, 1, color)
	Kit.tween(ball, time, { Size = V3(radius * 2, radius * (o.flat and 0.7 or 2), radius * 2), Transparency = 1 }, Enum.EasingStyle.Quart)
	Debris:AddItem(ball, time + 0.05)
	Kit.ringWave(o.ground or position, radius * 1.05, color, { time = time * 1.1, brightness = 3.5 })
end

-- Взрыв: вспышка, волна, искры, дым, угли, свет, тряска. o: core, smoke, sparks, embers, shake, rocks.
function Kit.explosion(position: Vector3, radius: number, color: Color3, o)
	o = o or {}
	local core = o.core or color:Lerp(Color3.new(1, 1, 1), 0.6)
	Kit.flash(position, core, radius * 1.3, 0.25)
	Kit.shockwave(position, radius, color, { time = 0.4, ground = o.ground })
	Kit.burst(position, {
		count = o.sparks or math.floor(18 + radius * 4),
		texture = "spark",
		color = { core, color },
		size = { radius * 0.12 + 0.25, 0 },
		life = { 0.3, 0.7 },
		speed = { radius * 4, radius * 9 },
		drag = 4,
		accel = V3(0, -18, 0),
		radius = 0.4,
	})
	Kit.burst(position, {
		count = math.floor(10 + radius * 2),
		texture = "glow",
		color = color,
		size = { radius * 0.5, radius * 0.9 },
		transparency = { 0.2, 1 },
		life = { 0.25, 0.45 },
		speed = { radius * 2, radius * 4 },
		drag = 6,
		radius = radius * 0.3,
	})
	if o.smoke ~= false then
		Kit.burst(position, {
			count = math.floor(6 + radius),
			texture = "smoke",
			color = o.smokeColor or color:Lerp(Color3.new(0.1, 0.1, 0.12), 0.75),
			size = { radius * 0.5, radius * 1.1 },
			transparency = { 0.35, 1 },
			life = { 0.7, 1.3 },
			speed = { radius * 0.8, radius * 2 },
			drag = 3,
			accel = V3(0, 2, 0),
			lightEmission = 0,
			lightInfluence = 1,
			radius = radius * 0.4,
		})
	end
	if o.embers then
		Kit.burst(position, {
			count = o.embers,
			texture = "star",
			color = { core, color },
			size = { 0.25, 0 },
			life = { 0.7, 1.4 },
			speed = { 6, 16 },
			accel = V3(0, -30, 0),
			drag = 1,
			radius = 0.5,
		})
	end
	if o.rocks then
		Kit.burst(position, {
			count = o.rocks,
			texture = "rock",
			color = o.rockColor or Color3.fromRGB(90, 76, 66),
			size = { 0.5, 0.4 },
			transparency = { 0, 0.2, 1 },
			life = { 0.6, 1.0 },
			speed = { 10, 22 },
			accel = V3(0, -60, 0),
			lightEmission = 0,
			lightInfluence = 1,
			spread = 60,
			direction = Enum.NormalId.Top,
			radius = 0.5,
		})
	end
	if o.shake ~= false then
		Kit.shake(position, o.shakeAmount or math.clamp(radius * 0.05, 0.08, 0.5), o.shakeTime or 0.25)
	end
end

-- ===== Столбы, лучи, молнии, разломы =====

-- Вертикальный столб света/огня: цилиндр раскрывается, держится и гаснет.
function Kit.pillar(position: Vector3, height: number, radius: number, color: Color3, o)
	o = o or {}
	local time = o.time or 0.6
	local core = o.core or color:Lerp(Color3.new(1, 1, 1), 0.65)
	local upright = CFrame.new(position + V3(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local outer = Kit.part({ Shape = Enum.PartType.Cylinder, Color = color, Transparency = o.transparency or 0.35, Name = "MagePillar" })
	outer.Size = V3(height, 0.2, 0.2)
	outer.CFrame = upright
	local inner = Kit.part({ Shape = Enum.PartType.Cylinder, Color = core, Transparency = 0.1, Name = "MagePillarCore" })
	inner.Size = V3(height, 0.1, 0.1)
	inner.CFrame = upright
	local d = radius * 2
	local open = math.min(0.12, time * 0.3)
	Kit.every(time, function(k, t)
		local w
		if t < open then
			w = ease(t / open, "out")
		else
			w = 1 - ease(math.clamp((t - open) / (time - open), 0, 1), "in")
		end
		outer.Size = V3(height, d * w + 0.05, d * w + 0.05)
		inner.Size = V3(height * 1.02, d * 0.4 * w + 0.03, d * 0.4 * w + 0.03)
		outer.Transparency = 0.35 + 0.65 * k ^ 2
		return true
	end, function()
		outer:Destroy()
		inner:Destroy()
	end)
	Kit.light(outer, color, 4, math.clamp(height * 1.4, 10, 40), time)
	if o.particles ~= false then
		Kit.stream(CFrame.new(position + V3(0, 0.3, 0)), {
			texture = o.texture or "glow",
			color = { core, color },
			size = { radius * 0.5, 0 },
			life = { 0.4, 0.8 },
			speed = { height * 0.8, height * 1.6 },
			spread = 12,
			rate = 60,
			direction = Enum.NormalId.Top,
			size3 = V3(d, 0.2, d),
			shape = Enum.ParticleEmitterShape.Box,
		}, time * 0.8)
	end
	return outer
end

-- Луч (Beam) между двумя точками. o: width, width1, texture, speed, time, transparency, curve, segments.
function Kit.beam(from: Vector3, to: Vector3, color: Color3, o)
	o = o or {}
	local a = Kit.holder(from)
	local b = Kit.holder(to)
	local a0 = Instance.new("Attachment")
	a0.Parent = a
	local a1 = Instance.new("Attachment")
	a1.Parent = b
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = colorSeq(o.colors or color)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Brightness = o.brightness or 3
	beam.Width0 = o.width or 1
	beam.Width1 = o.width1 or o.width or 1
	beam.FaceCamera = o.faceCamera ~= false
	beam.Texture = FxTex[o.texture or "trail"] or o.texture or FxTex.trail
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.TextureSpeed = o.speed or 2
	beam.Segments = o.segments or 1
	if o.curve then
		beam.CurveSize0 = o.curve
		beam.CurveSize1 = -o.curve
	end
	local base = o.transparency or 0
	beam.Transparency = NumberSequence.new(base)
	beam.Parent = a
	local time = o.time or 0.35
	if time > 0 then
		local hold = o.hold or 0
		Kit.every(time + hold, function(_, t)
			local k = math.clamp((t - hold) / time, 0, 1)
			beam.Transparency = NumberSequence.new(base + (1 - base) * k)
			beam.Width0 = (o.width or 1) * (1 - k * 0.6)
			beam.Width1 = (o.width1 or o.width or 1) * (1 - k * 0.6)
			return true
		end, function()
			a:Destroy()
			b:Destroy()
		end)
	end
	return { beam = beam, a = a, b = b, a0 = a0, a1 = a1 }
end

-- Точки ломаной между from и to (молния, разлом), смещение jitter поперёк.
local function jagged(from: Vector3, to: Vector3, segments: number, jitter: number, flatOnly: boolean?)
	local points = { from }
	local dir = to - from
	local side = dir:Cross(UP)
	if side.Magnitude < 1e-3 then
		side = V3(1, 0, 0)
	end
	side = side.Unit
	local up2 = side:Cross(dir).Unit
	for i = 1, segments - 1 do
		local k = i / segments
		local offset = side * (math.random() * 2 - 1) * jitter
		if not flatOnly then
			offset += up2 * (math.random() * 2 - 1) * jitter * 0.6
		end
		table.insert(points, from + dir * k + offset)
	end
	table.insert(points, to)
	return points
end
Kit.jagged = jagged

local function stick(a: Vector3, b: Vector3, width: number, color: Color3, transparency: number)
	local length = (b - a).Magnitude
	local p = Kit.part({ Color = color, Transparency = transparency, Name = "MageBolt" })
	p.Size = V3(width, width, math.max(length, 0.05))
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	return p
end

-- Молния: ломаная из неоновых брусков + ореол, ветки, вспышка в конце. o: width, jitter, time, branches.
function Kit.lightning(from: Vector3, to: Vector3, color: Color3, o)
	o = o or {}
	local distance = (to - from).Magnitude
	local segments = math.clamp(math.floor(distance / 1.8), 3, 18)
	local width = o.width or 0.22
	local core = o.core or Color3.new(1, 1, 1)
	local time = o.time or 0.22
	local points = jagged(from, to, segments, o.jitter or math.clamp(distance * 0.08, 0.4, 1.6))
	local sticks = {}
	for i = 1, #points - 1 do
		table.insert(sticks, stick(points[i], points[i + 1], width, core, 0))
		table.insert(sticks, stick(points[i], points[i + 1], width * 3.2, color, 0.55))
	end
	for _ = 1, o.branches or math.floor(segments / 4) do
		local i = math.random(2, math.max(#points - 1, 2))
		local start = points[i]
		local dir = (to - from).Unit
		local branchTo = start + (dir + V3(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5)).Unit * (1.5 + math.random() * 2.5)
		local bp = jagged(start, branchTo, 3, 0.5)
		for j = 1, #bp - 1 do
			table.insert(sticks, stick(bp[j], bp[j + 1], width * 0.6, color:Lerp(core, 0.4), 0.15))
		end
	end
	for _, p in ipairs(sticks) do
		Kit.fade(p, time, { Size = V3(p.Size.X * 0.3, p.Size.Y * 0.3, p.Size.Z) })
	end
	Kit.flash(to, color, o.flash or 2.2, 0.18)
	return points
end

-- Разлом на земле: неоновая трещина с ореолом, раскрывается за reveal и гаснет через time.
-- o: width, reveal, time, jitter, glow (цвет ореола), segments.
function Kit.crack(origin: Vector3, dir: Vector3, length: number, color: Color3, o)
	o = o or {}
	local flatDir = V3(dir.X, 0, dir.Z)
	flatDir = flatDir.Magnitude > 1e-3 and flatDir.Unit or V3(0, 0, -1)
	local to = origin + flatDir * length
	local segments = o.segments or math.clamp(math.floor(length / 1.4), 3, 20)
	local points = jagged(origin, to, segments, o.jitter or 0.6, true)
	local width = o.width or 0.4
	local reveal = o.reveal or 0.25
	local time = o.time or 1.2
	local parts = {}
	for i = 1, #points - 1 do
		local a = points[i] + V3(0, 0.06, 0)
		local b = points[i + 1] + V3(0, 0.06, 0)
		local len = (b - a).Magnitude
		local core = Kit.part({ Color = o.core or color:Lerp(Color3.new(1, 1, 1), 0.4), Transparency = 1, Name = "MageCrack" })
		core.Size = V3(width * (1 - i / (#points + 2) * 0.5), 0.08, len + 0.1)
		core.CFrame = CFrame.lookAt((a + b) / 2, b)
		local glow = Kit.part({ Color = o.glow or color, Transparency = 1, Name = "MageCrackGlow" })
		glow.Size = V3(width * 3, 0.04, len + 0.2)
		glow.CFrame = CFrame.lookAt((a + b) / 2 - V3(0, 0.02, 0), b - V3(0, 0.02, 0))
		table.insert(parts, { core = core, glow = glow, at = (i - 1) / math.max(#points - 1, 1) * reveal })
	end
	Kit.every(time, function(_, t)
		for _, entry in ipairs(parts) do
			local shown = t >= entry.at
			local out = math.clamp((t - (time - 0.35)) / 0.35, 0, 1)
			if shown then
				entry.core.Transparency = out
				entry.glow.Transparency = 0.6 + 0.4 * out
			end
		end
		return true
	end, function()
		for _, entry in ipairs(parts) do
			entry.core:Destroy()
			entry.glow:Destroy()
		end
	end)
	return points
end

-- След за движущейся деталью (две точки поперёк).
function Kit.trail(part: BasePart, color: Color3, o)
	o = o or {}
	local w = (o.width or 0.6) / 2
	local a0 = Instance.new("Attachment")
	a0.Position = o.vertical and V3(0, w, 0) or V3(w, 0, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = o.vertical and V3(0, -w, 0) or V3(-w, 0, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = colorSeq(o.colors or color)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Brightness = o.brightness or 2
	trail.Lifetime = o.life or 0.25
	trail.MinLength = 0.05
	trail.FaceCamera = o.faceCamera ~= false
	trail.Texture = FxTex[o.texture or "trail"] or FxTex.trail
	trail.TextureMode = Enum.TextureMode.Stretch
	trail.Transparency = numberSeq(o.transparency, NumberSequence.new(0.1, 1))
	trail.WidthScale = numberSeq(o.widthScale, NumberSequence.new(1, 0))
	trail.Parent = part
	return trail
end

-- ===== Мир =====

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

-- Пол под точкой (луч вниз мимо персонажей и эффектов).
function Kit.ground(position: Vector3, lift: number?): Vector3
	local ignore = { Kit.folder() }
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local fx = Workspace:FindFirstChild("KlinokAbilityFx")
	if fx then
		table.insert(ignore, fx)
	end
	rayParams.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(position + V3(0, 3, 0), V3(0, -14, 0), rayParams)
	local y = result and result.Position.Y or position.Y
	return V3(position.X, y + (lift or 0), position.Z)
end

function Kit.characterOf(player)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, root
end

-- Навершие посоха игрока (BladeTip оружия в руке), иначе над правой рукой.
function Kit.tipOf(player): Vector3?
	local character, root = Kit.characterOf(player)
	if not character then
		return nil
	end
	local weapon = character:FindFirstChild("EquippedWeapon")
	local primary = weapon and weapon.PrimaryPart
	local tip = primary and primary:FindFirstChild("BladeTip")
	if tip and tip:IsA("Attachment") then
		return tip.WorldPosition
	end
	local hand = character:FindFirstChild("RightHand")
	if hand then
		return hand.Position + V3(0, 1.5, 0)
	end
	return root and root.Position + V3(0, 1.5, 0) or nil
end

function Kit.flatUnit(v: Vector3, fallback: Vector3?): Vector3
	local f = V3(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return fallback or V3(0, 0, -1)
	end
	return f.Unit
end

function Kit.rotate(dir: Vector3, degrees: number): Vector3
	return CFrame.Angles(0, math.rad(degrees), 0):VectorToWorldSpace(dir)
end

return Kit
