--!nonstrict
-- FxAfter (клиент)
-- «Продлённые» фазы способностей по правилам pixelfx (docs/AUTHORING.md):
--   anticipation → release (белый кадр-«hero frame», вспышка, свет, hit-stop, тряска, FOV) →
--   spread → hold (искры, угли) → break / melt → долгий хвост 2–4 с.
-- Кирпичики собираются кодом на MageFxKit (Kit): частицы FxTex, неоновые детали, плоскости
-- на земле. Всё гаснет и удаляется само. Детали с физикой (обломки, листья, капли, кубики,
-- огоньки, руны) берут место из общего бюджета BUDGET — при куче способностей разом лишнее
-- просто не создаётся, FPS не проседает.
--
-- Используют Controllers/AbilityFxPlus (воин) и Controllers/MageSpellFxPlus (маг).

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Bus = require(script.Parent.Bus)
local Kit = require(script.Parent.MageFxKit)

local Fx = {}
Fx.Kit = Kit

local V3 = Vector3.new
local WHITE = Color3.new(1, 1, 1)
local TAU = math.pi * 2
local ZERO = V3(0, 0, 0)

local function rnd(a: number, b: number): number
	return a + (b - a) * math.random()
end
Fx.rnd = rnd

local function C(value, fallback)
	return Kit.color(value, fallback or WHITE)
end
Fx.C = C

-- ===== Бюджет деталей =====

Fx.BUDGET = 160
local live = 0
local peak = 0

local function take(n: number): number
	n = math.max(0, math.min(math.floor(n), Fx.BUDGET - live))
	live += n
	peak = math.max(peak, live)
	return n
end

local function give(n: number)
	live = math.max(0, live - n)
end

function Fx.live(): number
	return live
end

function Fx.peak(): number
	return peak
end

-- ===== Помощники =====

-- NumberSequence по точкам { {время, значение, разброс?}, ... }.
function Fx.seq(points)
	local list = {}
	for _, p in ipairs(points) do
		table.insert(list, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(list)
end

-- Мерцание: прозрачность скачет, к концу гаснет.
Fx.FLICKER = Fx.seq({ { 0, 0 }, { 0.15, 0.35 }, { 0.3, 0 }, { 0.5, 0.45 }, { 0.65, 0.1 }, { 0.82, 0.5 }, { 1, 1 } })

function Fx.after(delay: number, fn)
	Kit.after(delay, fn)
end

function Fx.sfx(name: string, position: Vector3?, volume: number?, delay: number?)
	if delay and delay > 0 then
		task.delay(delay, Kit.sfx, name, position, volume)
	else
		Kit.sfx(name, position, volume)
	end
end

local function camDistance(position: Vector3): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 0
	end
	return (camera.CFrame.Position - position).Magnitude
end

local function nearness(position: Vector3, range: number?): number
	return math.clamp(1 - camDistance(position) / (range or 70), 0, 1)
end
Fx.nearness = nearness

function Fx.ground(position: Vector3, lift: number?): Vector3
	return Kit.ground(position, lift or 0)
end

-- ===== Экранная вспышка и hit-stop =====

local flashGui = nil
local function screenFlash(color: Color3, amount: number, time: number)
	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	if not (flashGui and flashGui.Parent) then
		flashGui = playerGui:FindFirstChild("KlinokFxFlash")
		if not flashGui then
			flashGui = Instance.new("ScreenGui")
			flashGui.Name = "KlinokFxFlash"
			flashGui.IgnoreGuiInset = true
			flashGui.ResetOnSpawn = false
			flashGui.DisplayOrder = 40
			flashGui.Parent = playerGui
		end
	end
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1 - math.clamp(amount, 0, 0.8)
	frame.Parent = flashGui
	Kit.tween(frame, time, { BackgroundTransparency = 1 })
	Debris:AddItem(frame, time + 0.05)
end
Fx.screenFlash = screenFlash

local animator = nil
function Fx.hitStop(duration: number)
	if animator == nil then
		local ok, module = pcall(function()
			return require(script.Parent.Parent.Controllers.PlayerAnimator)
		end)
		animator = ok and type(module) == "table" and module or false
	end
	if animator and animator.hitStop then
		pcall(animator.hitStop, duration)
	end
end

-- ===== Release: «hero frame» =====
-- o: color, size, flash (0..1 экран), stop (hit-stop, только своему игроку), caster, fov (градусы),
--    shake, shakeTime, light, sparks (число | false), ring (false — без кольца), ground (точка кольца).
function Fx.heroFrame(position: Vector3, o)
	o = o or {}
	local color = o.color or WHITE
	local size = o.size or 6
	-- 1–2 кадра всё белое, затем цвет способности.
	local core = Kit.ball(position, size * 0.3, WHITE, { Transparency = 0 })
	Kit.fade(core, 0.1, { Size = V3(size, size, size) * 0.75 })
	Kit.after(0.05, function()
		Kit.flash(position, color, size * 1.25, 0.34)
	end)
	local holder = Kit.holder(position)
	Kit.light(holder, color:Lerp(WHITE, 0.45), o.light or 9, math.clamp(size * 4, 12, 60), 0.55)
	Debris:AddItem(holder, 0.65)
	local near = nearness(position)
	if (o.flash or 0) > 0 and near > 0 then
		screenFlash(color:Lerp(WHITE, 0.7), o.flash * near, o.flashTime or 0.26)
	end
	if (o.stop or 0) > 0 and o.caster ~= nil and o.caster == Players.LocalPlayer then
		Fx.hitStop(o.stop)
	end
	if (o.shake or 0) > 0 then
		Kit.shake(position, o.shake, o.shakeTime or 0.3)
	end
	if (o.fov or 0) ~= 0 and near > 0 then
		Bus.emit("fov", { amount = o.fov * near, time = o.fovTime or 0.3 })
	end
	if o.sparks ~= false then
		Fx.sparks(position, { color = color:Lerp(WHITE, 0.3), count = o.sparks or math.floor(10 + size * 1.5), speed = { size * 2.5, size * 6 } })
	end
	if o.ring ~= false then
		Kit.ringWave(o.ground or position, size * 1.1, color:Lerp(WHITE, 0.4), { time = 0.3, brightness = 4 })
	end
end

-- ===== Частицы =====

-- Искры: быстрые, по скорости, падают.
function Fx.sparks(position, o)
	o = o or {}
	return Kit.burst(position, {
		texture = o.texture or "spark",
		color = o.color or WHITE,
		count = o.count or 16,
		size = o.size or { 0.55, 0 },
		transparency = o.transparency or { 0, 0.1, 1 },
		life = o.life or { 0.3, 0.75 },
		speed = o.speed or { 14, 32 },
		drag = o.drag or 4,
		accel = o.accel or V3(0, -40, 0),
		spread = o.spread or 180,
		orientation = Enum.ParticleOrientation.VelocityParallel,
		brightness = o.brightness or 3,
		radius = o.radius or 0.3,
		rotation = 0,
		rotSpeed = 0,
	})
end

-- Клуб дыма (разово). o: color, radius, count, life, speed, accel.
function Fx.smoke(position, o)
	o = o or {}
	local r = o.radius or 2
	return Kit.burst(position, {
		texture = "smoke",
		color = o.color or C("#4A4440"),
		count = o.count or 10,
		size = o.size or { r * 0.6, r * 1.5, r * 2.1 },
		transparency = o.transparency or { 0.35, 0.55, 1 },
		life = o.life or { 1.8, 3.2 },
		speed = o.speed or { 1, 4 },
		drag = o.drag or 1.5,
		accel = o.accel or V3(0, 2.5, 0),
		spread = 180,
		lightEmission = o.lightEmission or 0,
		lightInfluence = o.lightInfluence or 0.8,
		brightness = o.brightness or 1,
		rotSpeed = { -30, 30 },
		radius = r * 0.6,
	})
end

-- Столб дыма: поток слабеет до нуля за time.
function Fx.plume(position: Vector3, o)
	o = o or {}
	local time = o.time or 3
	local rate = o.rate or 14
	local r = o.radius or 1.5
	local e, holder = Kit.stream(position, {
		texture = "smoke",
		color = o.color or C("#3E3936"),
		size = o.size or { r, r * 2.2, r * 3 },
		transparency = o.transparency or { 0.45, 0.6, 1 },
		life = o.life or { 2, 3.5 },
		speed = o.speed or { 3, 6 },
		spread = o.spread or 12,
		rate = rate,
		accel = o.accel or V3(0, 1.5, 0),
		drag = o.drag or 0.6,
		lightEmission = o.lightEmission or 0,
		lightInfluence = o.lightInfluence or 0.7,
		brightness = o.brightness or 1,
		rotSpeed = { -20, 20 },
		size3 = V3(r, 0.2, r),
	}, time)
	Kit.every(time, function(k)
		e.Rate = rate * (1 - k) ^ 1.4
	end)
	return e, holder
end

-- Угли: огоньки взлетают и мерцают; поток слабеет.
function Fx.embers(position: Vector3, o)
	o = o or {}
	local time = o.time or 2.5
	local rate = o.rate or 18
	local e, holder = Kit.stream(position, {
		texture = o.texture or "glow",
		color = o.color or { "#FFF2B0", "#FF8A2A", "#B8200F" },
		size = o.size or { 0.35, 0.25, 0 },
		transparency = o.transparency or Fx.FLICKER,
		life = o.life or { 1.2, 2.4 },
		speed = o.speed or { 1.5, 5 },
		spread = o.spread or 40,
		rate = rate,
		accel = o.accel or V3(0, 3, 0),
		drag = o.drag or 1.2,
		brightness = o.brightness or 3,
		rotSpeed = 0,
		size3 = o.area or V3(2, 0.3, 2),
	}, time)
	if o.fade ~= false then
		Kit.every(time, function(k)
			e.Rate = rate * (1 - k)
		end)
	end
	return e, holder
end

-- Мелкие искорки-«пылинки» висят и мерцают (магия, звёздная пыль).
function Fx.motes(position: Vector3, o)
	o = o or {}
	local time = o.time or 2.5
	local rate = o.rate or 12
	local area = o.area or 4
	local e, holder = Kit.stream(position, {
		texture = o.texture or "star",
		color = o.color or WHITE,
		size = o.size or { 0.1, 0.35, 0 },
		transparency = o.transparency or Fx.FLICKER,
		life = o.life or { 1.4, 2.8 },
		speed = o.speed or { 0.2, 1.2 },
		spread = 180,
		rate = rate,
		accel = o.accel or V3(0, 0.8, 0),
		drag = 1,
		brightness = o.brightness or 3,
		rotSpeed = { -60, 60 },
		size3 = V3(area, o.height or 1.5, area),
	}, time)
	Kit.every(time, function(k)
		e.Rate = rate * (1 - k * k)
	end)
	return e, holder
end

-- Низкая дымка по земле.
function Fx.mist(position: Vector3, o)
	o = o or {}
	local r = o.radius or 6
	local time = o.time or 3
	local rate = o.rate or 6
	local e, holder = Kit.stream(position + V3(0, 0.3, 0), {
		texture = "smoke",
		color = o.color or C("#C8D2E6"),
		size = { r * 0.5, r * 0.9, r * 1.1 },
		transparency = o.transparency or { 1, 0.72, 1 },
		life = o.life or { 2.5, 4 },
		speed = { 0.3, 1 },
		spread = 180,
		rate = rate,
		accel = V3(0, 0.15, 0),
		drag = 0.5,
		lightEmission = o.lightEmission or 0.2,
		lightInfluence = 0.6,
		brightness = 1,
		rotSpeed = { -10, 10 },
		size3 = V3(r * 1.6, 0.3, r * 1.6),
	}, time)
	Kit.every(time, function(k)
		e.Rate = rate * (1 - k * k)
	end)
	return e, holder
end

-- Пылевое кольцо: клубы летят по земле во все стороны (лицом наружу).
function Fx.dust(position: Vector3, o)
	o = o or {}
	local r = o.radius or 3
	local n = o.dirs or 8
	local color = o.color or C("#968470")
	for i = 1, n do
		local a = (i / n) * TAU + math.random() * 0.4
		local dir = V3(math.cos(a), 0, math.sin(a))
		local p = position + dir * (r * 0.25) + V3(0, 0.4, 0)
		Kit.burst(CFrame.lookAt(p, p + dir + V3(0, o.lift or 0.12, 0)), {
			texture = "smoke",
			color = color,
			count = o.count or 3,
			size = { r * 0.3, r * 0.65, r * 0.85 },
			transparency = o.transparency or { 0.3, 0.6, 1 },
			life = o.life or { 0.9, 1.8 },
			speed = o.speed or { r * 2.2, r * 4 },
			drag = 3.5,
			spread = 18,
			shape = Enum.ParticleEmitterShape.Box,
			direction = Enum.NormalId.Front,
			lightEmission = 0,
			lightInfluence = 0.9,
			brightness = 1,
			accel = V3(0, 1, 0),
			rotSpeed = { -40, 40 },
			radius = 0.2,
		})
	end
end

-- Частицы со сферы к центру (всасывание, схлопывание).
function Fx.inward(position: Vector3, r: number, o)
	o = o or {}
	local speed = o.speed or 12
	local holder = Kit.part({ Shape = Enum.PartType.Ball, Size = V3(r * 2, r * 2, r * 2), Transparency = 1, Name = "FxInward" })
	holder.CFrame = CFrame.new(position)
	local life = r / speed
	local e = Kit.emitter(holder, {
		texture = o.texture or "glow",
		color = o.color or WHITE,
		size = o.size or { 0.25, 0.6 },
		transparency = o.transparency or { 0.6, 0 },
		life = { life * 0.85, life },
		speed = speed,
		shape = Enum.ParticleEmitterShape.Sphere,
		shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		drag = 0,
		rotSpeed = 0,
		brightness = o.brightness or 2.5,
		orientation = o.streak and Enum.ParticleOrientation.VelocityParallel or nil,
	})
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	if (o.time or 0) > 0 then
		e.Rate = (o.count or 30) / o.time
		e.Enabled = true
		task.delay(o.time, function()
			e.Enabled = false
		end)
		Debris:AddItem(holder, o.time + life + 0.3)
	else
		e:Emit(o.count or 30)
		Debris:AddItem(holder, life + 0.3)
	end
	return e
end

-- ===== Земля: выжженное пятно, остывающие швы, рябь, схлопывание =====

-- Тёмное пятно + раскалённая кромка, которая остывает (hot → cool) и гаснет.
function Fx.scorch(position: Vector3, r: number, o)
	o = o or {}
	local life = o.life or 6
	local lift = o.lift or 0.07
	local dark, darkLabel = Kit.plane(CFrame.new(position + V3(0, lift, 0)) * CFrame.Angles(0, math.random() * TAU, 0), r * 2, o.image or "smoke",
		o.color or C("#17120F"), { brightness = 1, transparency = 1 })
	local gui = dark:FindFirstChildOfClass("SurfaceGui")
	if gui then
		gui.LightInfluence = 1
	end
	local hot = o.hot or C("#FF7A28")
	local cool = o.cool or C("#5A140A")
	local glowTime = o.glow or 1.6
	local edge, edgeLabel = nil, nil
	if o.edge ~= false then
		edge, edgeLabel = Kit.plane(CFrame.new(position + V3(0, lift + 0.02, 0)), r * 2.1, o.edgeImage or "ring", hot, { brightness = 3, transparency = 0.2 })
	end
	local peakT = o.transparency or 0.3
	Kit.every(life, function(_, t)
		local fadeIn = math.clamp(t / 0.2, 0, 1)
		local fadeOut = math.clamp((life - t) / (life * 0.4), 0, 1)
		darkLabel.ImageTransparency = 1 - (1 - peakT) * math.min(fadeIn, fadeOut)
		if edgeLabel then
			local g = math.clamp(t / glowTime, 0, 1)
			edgeLabel.ImageColor3 = hot:Lerp(cool, g)
			edgeLabel.ImageTransparency = 0.2 + 0.8 * g ^ 0.7
		end
	end, function()
		dark:Destroy()
		if edge then
			edge:Destroy()
		end
	end)
	return dark
end

-- Остывающий шов (по прямой from → to): горячий, темнеет, сужается, гаснет.
function Fx.seam(from: Vector3, to: Vector3, o)
	o = o or {}
	local len = (to - from).Magnitude
	if len < 0.05 then
		return nil
	end
	local life = o.life or 2.5
	local hot = o.hot or C("#FFC85A")
	local cool = o.cool or C("#781808")
	local w = o.width or 0.35
	local p = Kit.part({ Size = V3(w, 0.08, len), Color = hot, Transparency = 0, Name = "FxSeam" })
	p.CFrame = CFrame.lookAt((from + to) / 2, to + V3(0, 1e-3, 0))
	Kit.every(life, function(k)
		p.Color = hot:Lerp(cool, math.min(1, k * 1.6))
		p.Transparency = k ^ 1.5
		p.Size = V3(w * (1 - 0.6 * k), 0.08, len)
	end, function()
		p:Destroy()
	end)
	return p
end

-- Ломаный шов по земле от origin в сторону dir на length.
function Fx.seamPath(origin: Vector3, dir: Vector3, length: number, o)
	o = o or {}
	dir = Kit.flatUnit(dir)
	local side = V3(-dir.Z, 0, dir.X)
	local n = math.clamp(math.floor(length / 1.8), 2, 10)
	local prev = origin
	for i = 1, n do
		local k = i / n
		local jitter = i < n and (math.random() - 0.5) * (o.jitter or 0.8) or 0
		local point = origin + dir * (length * k) + side * jitter
		local life = (o.life or 2.5) * (1 - 0.35 * k)
		-- Начало отрезка — копия: замыкание с reveal > 0 срабатывает позже, когда prev уже сдвинут
		-- (иначе все отрезки тянулись из последней точки).
		local from = prev
		Kit.after((o.reveal or 0) * k, function()
			Fx.seam(from, point, { life = life, hot = o.hot, cool = o.cool, width = (o.width or 0.35) * (1 - 0.4 * k) })
		end)
		prev = point
	end
end

-- Кольцо снаружи внутрь (схлопывание), в конце — маленькая вспышка.
function Fx.collapse(position: Vector3, r: number, color: Color3, o)
	o = o or {}
	local time = o.time or 0.5
	local part, label = Kit.plane(CFrame.new(position + V3(0, o.lift or 0.14, 0)), r * 2, o.image or "ring", color,
		{ brightness = o.brightness or 3.5, transparency = 0.1 })
	Kit.every(time, function(k)
		local e = Kit.ease(k, "in")
		local d = math.max(0.2, r * 2 * (1 - e))
		part.Size = V3(d, 0.05, d)
		label.ImageTransparency = 0.1 + 0.6 * (k ^ 3)
	end, function()
		part:Destroy()
		if o.pop ~= false then
			Kit.flash(position + V3(0, 0.4, 0), color:Lerp(WHITE, 0.4), o.popSize or math.max(1.5, r * 0.45), 0.25)
		end
	end)
end

-- Серия колец-ряби в области (вода, время, звук).
function Fx.ripples(position: Vector3, o)
	o = o or {}
	local time = o.time or 2.5
	local n = o.count or 5
	local area = o.radius or 3
	local size = o.size or 2
	local color = o.color or C("#BFEFFF")
	for i = 1, n do
		Kit.after((i - 1) / n * time * 0.8 + math.random() * 0.15, function()
			local a = math.random() * TAU
			local d = math.random() * area
			Kit.ringWave(position + V3(math.cos(a) * d, 0, math.sin(a) * d), size * rnd(0.7, 1.3), color,
				{ time = o.ringTime or 0.9, from = 0.15, brightness = o.brightness or 2, transparency = o.transparency or 0.35, lift = 0.1 })
		end)
	end
end

-- Долгий свет, который мерцает и гаснет.
function Fx.afterglow(position: Vector3, o)
	o = o or {}
	local life = o.time or 3
	local brightness = o.brightness or 4
	local holder = Kit.holder(position)
	local light = Kit.light(holder, o.color or WHITE, brightness, o.range or 16)
	local seed = math.random() * 10
	Kit.every(life, function(k, t)
		local flicker = 0.82 + 0.18 * math.sin(t * 17 + seed) * math.sin(t * 7.3 + seed * 2)
		light.Brightness = brightness * (1 - k) ^ 1.6 * flicker
	end, function()
		holder:Destroy()
	end)
	return holder
end

-- Лёгкая цветокоррекция экрана, если камера рядом (удар времени, вспышка света).
function Fx.tint(position: Vector3?, o)
	o = o or {}
	if position and camDistance(position) > (o.range or 60) then
		return
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "KlinokSkillTint"
	cc.TintColor = WHITE
	cc.Brightness = 0
	cc.Contrast = 0
	cc.Saturation = 0
	cc.Parent = Lighting
	local tint = o.color or WHITE
	local time = o.time or 1
	local attack = o.attack or 0.08
	Kit.every(time, function(_, t)
		local w = t < attack and t / attack or 1 - (t - attack) / math.max(time - attack, 1e-3)
		w = math.clamp(w, 0, 1)
		cc.TintColor = WHITE:Lerp(tint, w * (o.amount or 0.35))
		cc.Brightness = (o.brightness or 0.04) * w
		cc.Contrast = (o.contrast or 0.1) * w
		cc.Saturation = (o.saturation or 0) * w
	end, function()
		cc:Destroy()
	end)
end

-- ===== Детали с движением (бюджет) =====

-- Воксельные обломки: летят, крутятся, отскакивают (до 3 раз), ложатся, тают.
-- o: count, color, hot (раскалённые: светятся и остывают в color), material, size, speed, up, dir,
--    radius, time, shard (вытянутые осколки), transparency, groundY.
function Fx.debris(position: Vector3, o)
	o = o or {}
	local n = take(o.count or 10)
	if n <= 0 then
		return
	end
	local groundY = o.groundY or Kit.ground(position).Y
	local color = o.color or C("#605448")
	local hot = o.hot
	local material = o.material or Enum.Material.Slate
	local life = o.time or 3.2
	local gravity = o.gravity or 70
	local cool = o.coolTime or 1.4
	local items = {}
	for i = 1, n do
		local s = (o.size or 0.7) * rnd(0.5, 1.3)
		local size = o.shard and V3(s * 0.35, s * 0.35, s * 1.7) or V3(s, s * rnd(0.7, 1.2), s * rnd(0.8, 1.2))
		local part = Kit.part({
			Size = size,
			Color = hot or color,
			Material = hot and Enum.Material.Neon or material,
			Transparency = o.transparency or 0,
			Name = "FxDebris",
		})
		local a = math.random() * TAU
		local out = V3(math.cos(a), 0, math.sin(a))
		local spd = (o.speed or 18) * rnd(0.4, 1.1)
		local up = (o.up or 22) * rnd(0.5, 1.2)
		local vel = out * spd + V3(0, up, 0)
		if o.dir then
			vel = (out * 0.6 + o.dir).Unit * spd + V3(0, up, 0)
		end
		local pos = position + out * math.random() * (o.radius or 0.8) + V3(0, 0.3, 0)
		items[i] = {
			part = part,
			pos = pos,
			vel = vel,
			rot = CFrame.Angles(math.random() * TAU, math.random() * TAU, math.random() * TAU),
			spin = V3(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14,
			bounces = 0,
			rest = false,
			half = math.min(size.X, size.Y, size.Z) / 2,
			size = size,
		}
		part.CFrame = CFrame.new(pos) * items[i].rot
	end
	Kit.every(life, function(_, t, dt)
		dt = math.min(dt, 1 / 20)
		local melt = math.clamp((t - (life - 0.9)) / 0.9, 0, 1)
		for _, it in ipairs(items) do
			if not it.rest then
				it.vel -= V3(0, gravity * dt, 0)
				it.pos += it.vel * dt
				it.rot *= CFrame.Angles(it.spin.X * dt, it.spin.Y * dt, it.spin.Z * dt)
				local floor = groundY + it.half
				if it.pos.Y <= floor then
					it.pos = V3(it.pos.X, floor, it.pos.Z)
					it.bounces += 1
					if it.bounces >= 3 or math.abs(it.vel.Y) < 5 then
						-- Лёг гранью на землю.
						it.rest = true
						it.vel = ZERO
						it.rot = CFrame.Angles(0, math.random() * TAU, 0)
					else
						it.vel = V3(it.vel.X * 0.55, -it.vel.Y * 0.38, it.vel.Z * 0.55)
						it.spin *= 0.6
					end
				end
			end
			if melt > 0 then
				-- Оседает в землю и тает.
				it.part.Size = it.size * (1 - 0.7 * melt)
				it.part.Transparency = math.max(o.transparency or 0, melt ^ 1.5)
				it.part.CFrame = CFrame.new(it.pos - V3(0, it.half * melt, 0)) * it.rot
			else
				it.part.CFrame = CFrame.new(it.pos) * it.rot
			end
			if hot then
				local c = math.clamp(t / cool, 0, 1)
				it.part.Color = hot:Lerp(color, c)
				if c >= 1 and it.part.Material == Enum.Material.Neon then
					it.part.Material = material
				end
			end
		end
	end, function()
		for _, it in ipairs(items) do
			it.part:Destroy()
		end
		give(n)
	end)
end

local FLUTTER = {
	leaf = { size = V3(0.5, 0.05, 0.32), colors = { "#6FCF5A", "#4E9E3A", "#9BD86A", "#C9B04A" }, fall = 3.2 },
	petal = { size = V3(0.38, 0.05, 0.26), colors = { "#FF8FD0", "#FFC2E6", "#FFF2FB" }, fall = 2.6 },
	page = { size = V3(0.9, 0.04, 1.2), colors = { "#EFE6CC", "#F7F0DA", "#E2D6B4" }, fall = 3.6 },
	feather = { size = V3(0.18, 0.04, 0.9), colors = { "#FFFDEE", "#FFE9A8" }, fall = 2.2 },
	ash = { size = V3(0.22, 0.04, 0.22), colors = { "#3A3533", "#5A524C", "#2A2624" }, fall = 2.0 },
	grass = { size = V3(0.08, 0.05, 0.7), colors = { "#7FBF4A", "#5E9A36", "#A3C95A" }, fall = 4.0 },
	cap = { size = V3(0.45, 0.12, 0.4), colors = { "#C8E04A", "#E9D9A8", "#B05A3A" }, fall = 9.0 },
}

-- Листья, лепестки, страницы, перья, пепел: взлетают, кружат, ложатся на землю, тают.
-- o: kind, count, color, glow (неон), scale, radius, height, speed, up, rest, time, groundY.
function Fx.flutter(position: Vector3, o)
	o = o or {}
	local spec = FLUTTER[o.kind or "leaf"] or FLUTTER.leaf
	local n = take(o.count or 8)
	if n <= 0 then
		return
	end
	local groundY = o.groundY or Kit.ground(position).Y
	local life = o.time or 5
	local rest = o.rest or 1.2
	local fall = spec.fall * (o.fallScale or 1)
	local items = {}
	for i = 1, n do
		local color = o.color or C(spec.colors[math.random(#spec.colors)])
		local s = (o.scale or 1) * rnd(0.75, 1.25)
		local part = Kit.part({
			Size = spec.size * s,
			Color = color,
			Material = o.glow and Enum.Material.Neon or Enum.Material.SmoothPlastic,
			Transparency = 0,
			Name = "FxFlutter",
		})
		local a = math.random() * TAU
		local out = V3(math.cos(a), 0, math.sin(a))
		local pos = position + out * (math.random() * (o.radius or 1.5)) + V3(0, math.random() * (o.height or 1), 0)
		local item = {
			part = part,
			pos = pos,
			vel = out * (o.speed or 6) * rnd(0.4, 1) + V3(0, (o.up or 5) * rnd(0.6, 1.2), 0),
			phase = math.random() * TAU,
			freq = rnd(2, 4.5),
			spin = V3(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 8,
			rot = CFrame.Angles(math.random() * TAU, math.random() * TAU, 0),
			landed = nil,
		}
		items[i] = item
		part.CFrame = CFrame.new(pos) * item.rot
	end
	Kit.every(life, function(_, t, dt)
		dt = math.min(dt, 1 / 20)
		local late = math.clamp((t - (life - 0.8)) / 0.8, 0, 1)
		for _, it in ipairs(items) do
			if it.landed then
				local since = t - it.landed
				it.part.Transparency = math.max(late, math.clamp((since - rest) / 0.8, 0, 1))
			else
				local v = it.vel
				local h = V3(v.X, 0, v.Z) * math.max(0, 1 - 2.2 * dt)
				local vy = math.max(v.Y - 18 * dt, -fall)
				it.vel = h + V3(0, vy, 0)
				local sway = ZERO
				if vy < 0 then
					sway = V3(math.cos(t * it.freq + it.phase), 0, math.sin(t * it.freq * 0.8 + it.phase)) * (1.4 * dt)
				end
				it.pos += it.vel * dt + sway
				it.rot *= CFrame.Angles(it.spin.X * dt, it.spin.Y * dt, it.spin.Z * dt)
				if it.pos.Y <= groundY + 0.04 then
					it.landed = t
					it.pos = V3(it.pos.X, groundY + 0.04, it.pos.Z)
					it.part.CFrame = CFrame.new(it.pos) * CFrame.Angles(0, math.random() * TAU, 0)
				else
					local wobble = math.sin(t * it.freq * 1.3 + it.phase) * 0.6
					it.part.CFrame = CFrame.new(it.pos) * it.rot * CFrame.Angles(wobble, 0, 0)
				end
				it.part.Transparency = late
			end
		end
	end, function()
		for _, it in ipairs(items) do
			it.part:Destroy()
		end
		give(n)
	end)
end

-- Капли по дуге; упав, дают кольцо-брызги.
function Fx.drops(position: Vector3, o)
	o = o or {}
	local n = take(o.count or 12)
	if n <= 0 then
		return
	end
	local groundY = o.groundY or Kit.ground(position).Y
	local color = o.color or C("#9FE8FF")
	local life = o.time or 2.2
	local rings = o.rings or 8
	local items = {}
	for i = 1, n do
		local d = (o.size or 0.3) * rnd(0.6, 1.3)
		local ball = Kit.ball(position + V3(0, 0.3, 0), d, color, { Transparency = 0.2, Name = "FxDrop" })
		local a = math.random() * TAU
		local out = V3(math.cos(a), 0, math.sin(a))
		items[i] = {
			part = ball,
			pos = position + out * math.random() * (o.radius or 0.6) + V3(0, 0.3, 0),
			vel = out * (o.speed or 12) * rnd(0.3, 1) + V3(0, (o.up or 18) * rnd(0.5, 1.2), 0),
			alive = true,
		}
	end
	local splashed = 0
	Kit.every(life, function(_, t, dt)
		dt = math.min(dt, 1 / 20)
		local any = false
		for _, it in ipairs(items) do
			if it.alive then
				any = true
				it.vel -= V3(0, 55 * dt, 0)
				it.pos += it.vel * dt
				if it.pos.Y <= groundY + 0.1 and it.vel.Y < 0 then
					it.alive = false
					it.part.Transparency = 1
					splashed += 1
					if splashed <= rings then
						Kit.ringWave(V3(it.pos.X, groundY, it.pos.Z), rnd(0.6, 1.2), color, { time = 0.35, from = 0.1, brightness = 2, transparency = 0.3, lift = 0.1 })
					end
				else
					it.part.CFrame = CFrame.new(it.pos)
				end
			end
		end
		if not any and t > 0.1 then
			return false
		end
		return true
	end, function()
		for _, it in ipairs(items) do
			it.part:Destroy()
		end
		give(n)
	end)
end

-- Огоньки со следом: поднимаются по спирали и гаснут.
function Fx.wisps(position: Vector3, o)
	o = o or {}
	local n = take(o.count or 5)
	if n <= 0 then
		return
	end
	local life = o.time or 2.2
	local color = o.color or WHITE
	local rise = o.rise or 3
	local radius = o.radius or 2
	local items = {}
	for i = 1, n do
		local ball = Kit.ball(position, o.size or 0.3, color, { Name = "FxWisp" })
		Kit.trail(ball, color, { width = (o.size or 0.3) * 1.2, life = o.trail or 0.5, brightness = 3 })
		items[i] = { part = ball, angle = (i / n) * TAU + math.random() * 0.5, r = radius * rnd(0.6, 1.1), h = rnd(0, 0.6), w = (o.spin or 4) * rnd(0.8, 1.2) * (o.both and (i % 2 == 0 and -1 or 1) or 1) }
	end
	Kit.every(life, function(k, _, dt)
		for _, it in ipairs(items) do
			it.angle += it.w * dt
			it.h += rise * dt
			local r = it.r * (1 - 0.65 * k)
			it.part.CFrame = CFrame.new(position + V3(math.cos(it.angle) * r, it.h, math.sin(it.angle) * r))
			it.part.Transparency = math.clamp((k - 0.6) / 0.4, 0, 1)
		end
	end, function()
		for _, it in ipairs(items) do
			it.part:Destroy()
		end
		give(n)
	end)
end

-- Кубики памяти / осколки: парят, вращаются и распадаются.
function Fx.cubes(position: Vector3, o)
	o = o or {}
	local n = take(o.count or 10)
	if n <= 0 then
		return
	end
	local life = o.time or 2.6
	local colors = o.colors or { WHITE }
	local items = {}
	for i = 1, n do
		local s = (o.size or 0.5) * rnd(0.6, 1.3)
		local a = math.random() * TAU
		local d = math.random() * (o.radius or 3)
		local color = colors[(i - 1) % #colors + 1]
		local part = Kit.part({ Size = V3(s, s, s), Color = color, Transparency = 0.1, Name = "FxCube" })
		items[i] = {
			part = part,
			pos = position + V3(math.cos(a) * d, rnd(0.3, o.height or 2.5), math.sin(a) * d),
			vel = V3(math.random() - 0.5, rnd(0.6, 1.6), math.random() - 0.5) * (o.speed or 1.5),
			rot = CFrame.Angles(math.random() * TAU, math.random() * TAU, 0),
			spin = V3(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 5,
			breakAt = rnd(0.35, 0.8) * life,
			s = s,
			broke = false,
			color = color,
		}
	end
	local pops = 0
	Kit.every(life, function(_, t, dt)
		for _, it in ipairs(items) do
			it.pos += it.vel * dt
			it.rot *= CFrame.Angles(it.spin.X * dt, it.spin.Y * dt, it.spin.Z * dt)
			local k = math.clamp((t - it.breakAt) / 0.45, 0, 1)
			if k > 0 and not it.broke then
				it.broke = true
				pops += 1
				if pops <= 6 then
					Kit.burst(it.pos, { texture = "spark", color = it.color, count = 5, size = { 0.25, 0 }, life = { 0.3, 0.6 }, speed = { 3, 7 }, drag = 3, radius = 0.1 })
				end
			end
			local s = it.s * (1 - k)
			it.part.Size = V3(math.max(s, 0.05), math.max(s, 0.05), math.max(s, 0.05))
			it.part.Transparency = 0.1 + 0.9 * k
			it.part.CFrame = CFrame.new(it.pos) * it.rot
		end
	end, function()
		for _, it in ipairs(items) do
			it.part:Destroy()
		end
		give(n)
	end)
end

-- Руны/буквы поднимаются и тают (BillboardGui).
function Fx.glyphs(position: Vector3, o)
	o = o or {}
	local n = take(o.count or 8)
	if n <= 0 then
		return
	end
	local life = o.time or 2.2
	local letters = o.letters or Kit.GLYPHS
	local color = o.color or WHITE
	local items = {}
	for i = 1, n do
		local a = math.random() * TAU
		local d = math.random() * (o.radius or 2.5)
		local holder = Kit.holder(position + V3(math.cos(a) * d, rnd(0.2, 1.2), math.sin(a) * d))
		local gui = Instance.new("BillboardGui")
		local size = (o.size or 1.2) * rnd(0.7, 1.2)
		gui.Size = UDim2.new(size, 0, size, 0)
		gui.LightInfluence = 0
		gui.Brightness = 2.5
		gui.AlwaysOnTop = false
		gui.Adornee = holder
		gui.Parent = holder
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = letters[math.random(#letters)]
		label.TextScaled = true
		label.Font = o.font or Enum.Font.Fantasy
		label.TextColor3 = color
		label.TextStrokeColor3 = o.stroke or color:Lerp(Color3.new(0, 0, 0), 0.6)
		label.TextStrokeTransparency = 0.4
		label.TextTransparency = 1
		label.Parent = gui
		items[i] = { holder = holder, label = label, base = holder.Position, speed = rnd(1.2, 2.6) * (o.rise or 1), phase = math.random() * TAU, delay = rnd(0, 0.35) * life }
	end
	Kit.every(life, function(_, t)
		for _, it in ipairs(items) do
			local local_t = math.max(0, t - it.delay)
			local span = math.max(life - it.delay, 0.1)
			local k = local_t / span
			it.holder.CFrame = CFrame.new(it.base + V3(math.sin(local_t * 2 + it.phase) * 0.3, it.speed * local_t, 0))
			local fadeIn = math.clamp(local_t / 0.2, 0, 1)
			it.label.TextTransparency = 1 - fadeIn * (1 - k ^ 1.5)
			it.label.TextStrokeTransparency = 0.4 + 0.6 * (1 - fadeIn * (1 - k))
		end
	end, function()
		for _, it in ipairs(items) do
			it.holder:Destroy()
		end
		give(n)
	end)
end

-- Остаточные разряды: короткие молнии у земли, всё реже.
function Fx.arcs(position: Vector3, o)
	o = o or {}
	local time = o.time or 2
	local count = o.count or 8
	local r = o.radius or 4
	local color = o.color or C("#7FD8FF")
	for i = 1, count do
		Kit.after(time * (i / count) ^ 1.4, function()
			local a = math.random() * TAU
			local d = math.random() * r
			local from = position + V3(math.cos(a) * d, 0.2, math.sin(a) * d)
			local b = math.random() * TAU
			local to = from + V3(math.cos(b), rnd(0, 0.4), math.sin(b)) * rnd(1, 2.6)
			Kit.lightning(from, to, color, { width = 0.08, time = 0.12, branches = 0, flash = 0.6, jitter = 0.35 })
			if o.sound and i % 3 == 1 then
				Kit.sfx(o.sound, from, o.volume or 0.35)
			end
		end)
	end
end

-- Кольцо-печать (картинка) на земле: проявляется, крутится, гаснет.
function Fx.sigil(position: Vector3, r: number, color: Color3, o)
	o = o or {}
	local life = o.time or 2
	local part, label = Kit.plane(CFrame.new(position + V3(0, o.lift or 0.12, 0)), r * 2, o.image or "seal", color,
		{ brightness = o.brightness or 3, transparency = 1 })
	local spin = o.spin or 40
	local grow = o.grow or 0.15
	local peakT = o.transparency or 0.15
	Kit.every(life, function(k, t)
		local fadeIn = math.clamp(t / 0.15, 0, 1)
		local fadeOut = math.clamp((1 - k) / 0.6, 0, 1)
		label.ImageTransparency = 1 - (1 - peakT) * math.min(fadeIn, fadeOut)
		label.Rotation = spin * t
		local d = r * 2 * (1 + grow * k)
		part.Size = V3(d, 0.05, d)
	end, function()
		part:Destroy()
	end)
	return part, label
end

-- Висящая неоновая черта (след удара, «X»): светится, сужается, гаснет.
function Fx.slashMark(center: Vector3, dir: Vector3, length: number, color: Color3, o)
	o = o or {}
	local life = o.time or 1
	local w = o.width or 0.25
	local unit = dir.Magnitude > 1e-3 and dir.Unit or V3(0, 0, -1)
	local p = Kit.part({ Size = V3(w, w, length), Color = color, Transparency = 0.05, Name = "FxSlashMark" })
	p.CFrame = CFrame.lookAt(center, center + unit + V3(0, 1e-3, 0))
	Kit.light(p, color, 3, math.clamp(length * 1.5, 8, 24), life)
	Kit.every(life, function(k)
		local e = k ^ 1.4
		p.Size = V3(w * (1 - 0.8 * e), w * (1 - 0.8 * e), length * (1 + 0.1 * k))
		p.Transparency = 0.05 + 0.95 * e
	end, function()
		p:Destroy()
	end)
	return p
end

return Fx
