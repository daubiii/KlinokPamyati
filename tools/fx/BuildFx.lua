--[[
	BuildFx — шаблоны эффектов способностей в ReplicatedStorage.FX.
	Запуск: Studio, Command Bar, режим Edit. Потом Ctrl+S: папка FX живёт
	только в файле места (Rojo её не трогает, $ignoreUnknownInstances).

	Повторный запуск создаёт только то, чего нет: правки в Studio не теряются.
	REBUILD = true — снести FX и собрать заново (все ручные правки пропадут).

	Как устроены шаблоны (код — Lib/FxKit.lua, способности — AbilityFx.lua):
	  * Эффект «в точке» — невидимая деталь (Part) с ParticleEmitter, PointLight.
	    Код клонирует её и ставит на место; цвет, текстуры, размеры, скорость,
	    время жизни — всё берётся из шаблона, в коде их нет.
	  * Атрибуты ParticleEmitter:
	      Emit      — выпустить N частиц разом (вспышка). Без Emit эмиттер
	                  работает непрерывно, пока жив эффект (Rate).
	      EmitDelay — задержка выброса, с.
	      Pattern   — "ring": разлёт кольцом по земле; "inward": затягивание
	                  к центру с кромки детали. Направление выброса — Front.
	      ScaleSize, ScaleSpeed — масштабировать по радиусу способности
	                  (радиус шаблона — атрибут BaseRadius у детали).
	      MatchLife — время жизни частицы = длительности эффекта (печать).
	  * PointLight: атрибут Fade — погаснуть за N секунд.
	  * Beam / Trail — клонируются как есть, точки крепления ставит код.
	  * Плоские круги на земле: Orientation = VelocityPerpendicular,
	    EmissionDirection = Top, Speed ≈ 0 — частица лежит плашмя.
]]

local REBUILD = false

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	glow = "rbxassetid://127300277477869",
	spark = "rbxassetid://128412204996964",
	star = "rbxassetid://139416211393590",
	ring = "rbxassetid://89952298821336",
	smoke = "rbxassetid://98452882968066",
	rock = "rbxassetid://103382352113607",
	swirl = "rbxassetid://132543076313570",
	wind = "rbxassetid://124278302536870",
	slash = "rbxassetid://71956307402864",
	trail = "rbxassetid://106562669477891",
	crack = "rbxassetid://72048617806070",
	magma = "rbxassetid://75327668421864",
	chain = "rbxassetid://91643711077619",
	seal = "rbxassetid://133447100423207",
	keyhole = "rbxassetid://118822132984940",
	chevron = "rbxassetid://84512940291229",
}

local hex = Color3.fromHex
local C = {
	gold = hex("#FFB536"),
	core = hex("#FFE39A"),
	cream = hex("#F6E7C6"),
	ember = hex("#FF7A2A"),
	magma = hex("#FF4F12"),
	stone = hex("#6B5643"),
	stoneDark = hex("#2B1F17"),
	dust = hex("#A48B6C"),
}

-- ===== помощники =====

local function ns(...)
	local args = { ... }
	if #args == 1 then
		return NumberSequence.new(args[1])
	end
	local points = {}
	for i = 1, #args, 2 do
		table.insert(points, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(points)
end

local function cs(a, b)
	return b and ColorSequence.new(a, b) or ColorSequence.new(a)
end

local function nr(a, b)
	return NumberRange.new(a, b or a)
end

local function apply(inst, props)
	local attrs = props.attrs
	props.attrs = nil
	for k, v in pairs(props) do
		inst[k] = v
	end
	if attrs then
		for k, v in pairs(attrs) do
			inst:SetAttribute(k, v)
		end
	end
	return inst
end

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

-- Шаблон создаётся, только если его ещё нет.
local created, skipped = 0, 0
local function template(parent, name, build)
	if parent:FindFirstChild(name) then
		skipped += 1
		return
	end
	local inst = build()
	inst.Name = name
	inst.Parent = parent
	created += 1
end

local function anchor(size: Vector3, attrs)
	local p = Instance.new("Part")
	p.Size = size
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Locked = true
	if attrs then
		for k, v in pairs(attrs) do
			p:SetAttribute(k, v)
		end
	end
	return p
end

local function emitter(parent, name, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Enabled = false
	e.Rate = 0
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Speed = nr(0)
	e.SpreadAngle = Vector2.new(0, 0)
	-- В шаблоне эмиттер выключен; включает FxKit (или сборщик оружия).
	apply(e, props)
	e.Parent = parent
	return e
end

-- Плоская частица на земле (круг, печать, спираль).
local function flat(props)
	props.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	props.EmissionDirection = Enum.NormalId.Top
	props.Speed = nr(0.01)
	return props
end

local function light(parent, color, brightness, range, fade)
	local l = Instance.new("PointLight")
	l.Name = "Light"
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	if fade then
		l:SetAttribute("Fade", fade)
	end
	l.Parent = parent
	return l
end

local function beam(props)
	local b = Instance.new("Beam")
	b.FaceCamera = false
	b.LightInfluence = 0
	b.Segments = 1
	apply(b, props)
	return b
end

local function trail(props)
	local t = Instance.new("Trail")
	t.FaceCamera = false
	t.LightInfluence = 0
	t.MinLength = 0.05
	apply(t, props)
	return t
end

-- ===== сборка =====

local fx = RS:FindFirstChild("FX")
if fx and REBUILD then
	fx:Destroy()
	fx = nil
end
fx = fx or folder(RS, "FX")
-- Старая черновая папка (FX.Folder: unlock, UnlockFx) — заменена шаблонами ниже.
local draft = fx:FindFirstChild("Folder")
if draft then
	draft:Destroy()
end

local common = folder(fx, "Common")
local vortex = folder(fx, "Vortex")
local rift = folder(fx, "Rift")
local unlock = folder(fx, "Unlock")
local keyhole = folder(fx, "Keyhole")
local weapon = folder(fx, "Weapon")

-- ---------- Common ----------

template(common, "Flash", function()
	local p = anchor(Vector3.new(1, 1, 1), { BaseRadius = 1 })
	emitter(p, "Glow", {
		Texture = TEX.glow, Color = cs(C.core), Lifetime = nr(0.22), ZOffset = 0.5,
		Size = ns(0, 2.5, 1, 7), Transparency = ns(0, 0.25, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	})
	emitter(p, "Sparks", {
		Texture = TEX.spark, Color = cs(C.core, C.gold), Lifetime = nr(0.25, 0.45), Speed = nr(22, 40),
		SpreadAngle = Vector2.new(180, 180), Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = ns(0, 0.9, 1, 0), Drag = 5, Acceleration = Vector3.new(0, -25, 0), attrs = { Emit = 24 },
	})
	emitter(p, "Stars", {
		Texture = TEX.star, Color = cs(C.core), Lifetime = nr(0.3, 0.45), Speed = nr(3, 8),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0, 0.2, 1.6, 1, 0),
		Rotation = nr(0, 360), RotSpeed = nr(-90, 90), attrs = { Emit = 4 },
	})
	light(p, C.gold, 2.5, 12, 0.35)
	return p
end)

template(common, "Dust", function()
	local p = anchor(Vector3.new(1, 0.2, 1), { BaseRadius = 1 })
	emitter(p, "Smoke", {
		Texture = TEX.smoke, Color = cs(C.dust), LightEmission = 0, LightInfluence = 1,
		Lifetime = nr(0.6, 1.1), Speed = nr(10, 16), SpreadAngle = Vector2.new(10, 10), Drag = 4,
		Size = ns(0, 1.2, 1, 3.6), Transparency = ns(0, 0.35, 1, 1), Rotation = nr(0, 360), RotSpeed = nr(-60, 60),
		Acceleration = Vector3.new(0, 1.5, 0), EmissionDirection = Enum.NormalId.Front,
		attrs = { Emit = 16, Pattern = "ring", ScaleSpeed = true },
	})
	return p
end)

template(common, "Shockwave", function()
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.ForceField
	p.Color = C.gold
	p.Size = Vector3.new(1, 1, 1)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p:SetAttribute("Time", 0.45)
	return p
end)

-- ---------- Vortex ----------

template(vortex, "Funnel", function()
	local p = anchor(Vector3.new(11, 0.2, 11), { BaseRadius = 5.5, ScalePart = true })
	emitter(p, "Swirl", flat({
		Texture = TEX.swirl, Color = cs(C.gold, C.core), Rate = 7, Lifetime = nr(0.55),
		Size = ns(0, 11.5, 1, 9), Transparency = ns(0, 1, 0.25, 0.15, 0.75, 0.25, 1, 1),
		Rotation = nr(0, 360), RotSpeed = nr(-620, -520), attrs = { ScaleSize = true },
	}))
	emitter(p, "SwirlInner", flat({
		Texture = TEX.swirl, Color = cs(C.core), Rate = 6, Lifetime = nr(0.4), Brightness = 1.5,
		Size = ns(0, 6, 1, 3), Transparency = ns(0, 1, 0.3, 0.2, 1, 1),
		Rotation = nr(0, 360), RotSpeed = nr(-900, -760), attrs = { ScaleSize = true },
	}))
	emitter(p, "Motes", {
		Texture = TEX.spark, Color = cs(C.core, C.gold), Rate = 70, Lifetime = nr(0.35),
		Speed = nr(14), Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(6, 6), Size = ns(0, 0.9, 1, 0.2),
		attrs = { Pattern = "inward", ScaleSpeed = true },
	})
	emitter(p, "Dust", {
		Texture = TEX.glow, Color = cs(C.gold, C.core), Rate = 30, Lifetime = nr(0.5, 0.8),
		Speed = nr(2, 5), SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = ns(0, 0.35, 1, 0),
	})
	light(p, C.gold, 1.2, 12)
	return p
end)

template(vortex, "Arm", function()
	return beam({
		Texture = TEX.wind, TextureMode = Enum.TextureMode.Wrap, TextureLength = 3.5, TextureSpeed = 3,
		Width0 = 2.4, Width1 = 0.5, Segments = 24, LightEmission = 1, Brightness = 2,
		Color = cs(C.gold, C.core), Transparency = ns(0, 0.85, 0.3, 0.2, 0.8, 0.2, 1, 0.9),
	})
end)

template(vortex, "Sickle", function()
	local f = Instance.new("Folder")
	local t = trail({
		Texture = TEX.trail, TextureMode = Enum.TextureMode.Stretch, Lifetime = 0.2,
		LightEmission = 1, Brightness = 2, Color = cs(C.cream, C.gold),
		Transparency = ns(0, 0, 1, 1), WidthScale = ns(0, 1, 1, 0.3),
	})
	t.Name = "Blade"
	t.Parent = f
	emitter(f, "Edge", {
		Texture = TEX.glow, Color = cs(C.core), Rate = 40, Lifetime = nr(0.2),
		Size = ns(0, 0.6, 1, 0), LockedToPart = false,
	})
	return f
end)

template(vortex, "BladeTrail", function()
	return trail({
		Texture = TEX.trail, TextureMode = Enum.TextureMode.Stretch, Lifetime = 0.25,
		LightEmission = 1, Brightness = 2, Color = cs(C.core, C.gold), Transparency = ns(0, 0.1, 1, 1),
	})
end)

template(vortex, "Pull", function()
	local p = anchor(Vector3.new(11, 0.2, 11), { BaseRadius = 5.5, ScalePart = true })
	emitter(p, "Ring", flat({
		Texture = TEX.ring, Color = cs(C.gold), Lifetime = nr(0.28),
		Size = ns(0, 12, 1, 2.5), Transparency = ns(0, 0.6, 0.3, 0.1, 1, 1),
		attrs = { Emit = 1, ScaleSize = true },
	}))
	emitter(p, "Streaks", {
		Texture = TEX.spark, Color = cs(C.core), Lifetime = nr(0.25), Speed = nr(20),
		Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front,
		Size = ns(0, 1.1, 1, 0.3), attrs = { Emit = 24, Pattern = "inward", ScaleSpeed = true },
	})
	return p
end)

template(vortex, "Wave", function()
	local p = anchor(Vector3.new(1, 0.2, 1), { BaseRadius = 7 })
	emitter(p, "Ring", flat({
		Texture = TEX.ring, Color = cs(C.cream, C.gold), Lifetime = nr(0.35),
		Size = ns(0, 2, 1, 15), Transparency = ns(0, 0, 0.6, 0.3, 1, 1),
		attrs = { Emit = 1, ScaleSize = true },
	}))
	emitter(p, "Ring2", flat({
		Texture = TEX.ring, Color = cs(C.gold), Lifetime = nr(0.45),
		Size = ns(0, 1, 1, 17), Transparency = ns(0, 0.2, 1, 1),
		attrs = { Emit = 1, EmitDelay = 0.06, ScaleSize = true },
	}))
	emitter(p, "Crescents", {
		Texture = TEX.slash, Color = cs(C.cream, C.gold), Lifetime = nr(0.3), Speed = nr(26),
		Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front,
		Size = ns(0, 2.6, 1, 3.4), Transparency = ns(0, 0, 0.7, 0.2, 1, 1),
		attrs = { Emit = 10, Pattern = "ring", ScaleSpeed = true },
	})
	emitter(p, "GoldDust", {
		Texture = TEX.glow, Color = cs(C.gold, C.core), Lifetime = nr(0.5, 0.9), Speed = nr(14, 30),
		EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(20, 20), Drag = 4,
		Size = ns(0, 0.5, 1, 0), Acceleration = Vector3.new(0, 3, 0),
		attrs = { Emit = 60, Pattern = "ring", ScaleSpeed = true },
	})
	emitter(p, "Sparks", {
		Texture = TEX.spark, Color = cs(C.core), Lifetime = nr(0.25, 0.4), Speed = nr(30, 45),
		Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(15, 15), Size = ns(0, 0.8, 1, 0),
		attrs = { Emit = 30, Pattern = "ring", ScaleSpeed = true },
	})
	emitter(p, "Glow", {
		Texture = TEX.glow, Color = cs(C.core), Lifetime = nr(0.25), ZOffset = 0.5,
		Size = ns(0, 3, 1, 8), Transparency = ns(0, 0.45, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	})
	light(p, C.gold, 2.5, 16, 0.45)
	return p
end)

-- ---------- Rift ----------

template(rift, "Slam", function()
	local p = anchor(Vector3.new(1, 0.2, 1), { BaseRadius = 5 })
	emitter(p, "Glow", {
		Texture = TEX.glow, Color = cs(C.ember, C.gold), Lifetime = nr(0.25), ZOffset = 0.5,
		Size = ns(0, 3, 1, 9), Transparency = ns(0, 0.3, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	})
	emitter(p, "Ring", flat({
		Texture = TEX.ring, Color = cs(C.ember, C.gold), Lifetime = nr(0.35),
		Size = ns(0, 2, 1, 12), Transparency = ns(0, 0, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	}))
	emitter(p, "DustRing", {
		Texture = TEX.smoke, Color = cs(C.dust), LightEmission = 0, LightInfluence = 1,
		Lifetime = nr(0.7, 1.2), Speed = nr(12, 20), EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(12, 12), Drag = 5, Size = ns(0, 1.5, 1, 4.5), Transparency = ns(0, 0.3, 1, 1),
		Rotation = nr(0, 360), RotSpeed = nr(-50, 50), attrs = { Emit = 20, Pattern = "ring", ScaleSpeed = true },
	})
	emitter(p, "Debris", {
		Texture = TEX.rock, Color = cs(C.stone, C.stoneDark), LightEmission = 0, LightInfluence = 1,
		Lifetime = nr(0.7, 1.0), Speed = nr(18, 28), EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(35, 35), Acceleration = Vector3.new(0, -70, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6, 0.3), NumberSequenceKeypoint.new(1, 0.6, 0.3) }),
		Rotation = nr(0, 360), RotSpeed = nr(-300, 300), attrs = { Emit = 16 },
	})
	emitter(p, "Embers", {
		Texture = TEX.spark, Color = cs(C.magma, C.gold), Lifetime = nr(0.4, 0.8), Speed = nr(15, 30),
		Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(50, 50), Acceleration = Vector3.new(0, -20, 0),
		Size = ns(0, 0.7, 1, 0), attrs = { Emit = 30 },
	})
	light(p, C.ember, 3, 12, 0.5)
	return p
end)

template(rift, "Crack", function()
	return beam({
		Texture = TEX.crack, TextureMode = Enum.TextureMode.Wrap, TextureLength = 3,
		Width0 = 1.3, Width1 = 1.3, LightEmission = 0, LightInfluence = 1,
		Color = cs(C.stoneDark), Transparency = ns(0),
	})
end)

template(rift, "Magma", function()
	return beam({
		Texture = TEX.magma, TextureMode = Enum.TextureMode.Wrap, TextureLength = 3, TextureSpeed = -1.5,
		Width0 = 0.55, Width1 = 0.55, LightEmission = 1, Brightness = 3, ZOffset = 0.02,
		Color = cs(C.magma, C.gold), Transparency = ns(0),
	})
end)

template(rift, "CrackFx", function()
	-- Деталь растягивается по длине отрезка трещины (Z) — искры по всей линии.
	local p = anchor(Vector3.new(1, 0.2, 1))
	emitter(p, "Embers", {
		Texture = TEX.spark, Color = cs(C.magma, C.gold), Rate = 18, Lifetime = nr(0.4, 0.8),
		Speed = nr(3, 7), Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = ns(0, 0.5, 1, 0),
	})
	emitter(p, "Heat", {
		Texture = TEX.smoke, Color = cs(hex("#3A2C24")), LightEmission = 0, LightInfluence = 1,
		Rate = 4, Lifetime = nr(0.8, 1.2), Speed = nr(1, 2), EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = ns(0, 0.8, 1, 2), Transparency = ns(0, 0.6, 1, 1), Rotation = nr(0, 360),
	})
	light(p, C.ember, 1.5, 6)
	return p
end)

template(rift, "Spike", function()
	-- Каменный шип: основание и острие из клиньев, внутри — жила магмы.
	-- Опорная точка модели — низ основания. Можно заменить на свой MeshPart.
	local m = Instance.new("Model")
	local function rockPart(class, size, cf, color, material)
		local part = Instance.new(class)
		part.Size = size
		part.CFrame = cf
		part.Color = color
		part.Material = material or Enum.Material.Basalt
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Parent = m
		return part
	end
	local base = rockPart("Part", Vector3.new(1.4, 2.4, 1.4), CFrame.new(0, 1.2, 0), C.stone)
	base.Name = "Base"
	rockPart("WedgePart", Vector3.new(1.4, 1.6, 0.7), CFrame.new(0, 3.2, -0.35), C.stone).Name = "TipFront"
	rockPart("WedgePart", Vector3.new(1.4, 1.6, 0.7), CFrame.new(0, 3.2, 0.35) * CFrame.Angles(0, math.pi, 0), C.stone).Name = "TipBack"
	local vein = rockPart("Part", Vector3.new(0.25, 2.8, 1.45), CFrame.new(0.2, 1.5, 0), C.magma, Enum.Material.Neon)
	vein.Name = "Vein"
	m.PrimaryPart = base
	m.WorldPivot = CFrame.new(0, 0, 0)
	m:SetAttribute("Height", 4)
	return m
end)

template(rift, "SpikeBurst", function()
	local p = anchor(Vector3.new(1, 0.2, 1))
	emitter(p, "Dust", {
		Texture = TEX.smoke, Color = cs(C.dust), LightEmission = 0, LightInfluence = 1,
		Lifetime = nr(0.5, 0.9), Speed = nr(6, 10), EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(40, 40), Drag = 4, Size = ns(0, 1, 1, 2.8), Transparency = ns(0, 0.3, 1, 1),
		Rotation = nr(0, 360), attrs = { Emit = 6 },
	})
	emitter(p, "Rocks", {
		Texture = TEX.rock, Color = cs(C.stone, C.stoneDark), LightEmission = 0, LightInfluence = 1,
		Lifetime = nr(0.6, 0.9), Speed = nr(10, 16), EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(30, 30), Acceleration = Vector3.new(0, -60, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45, 0.2), NumberSequenceKeypoint.new(1, 0.45, 0.2) }),
		Rotation = nr(0, 360), RotSpeed = nr(-300, 300), attrs = { Emit = 6 },
	})
	emitter(p, "Embers", {
		Texture = TEX.spark, Color = cs(C.magma, C.gold), Lifetime = nr(0.3, 0.6), Speed = nr(10, 20),
		Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(35, 35), Size = ns(0, 0.6, 1, 0), attrs = { Emit = 10 },
	})
	return p
end)

-- ---------- Unlock ----------

template(unlock, "Key", function()
	-- Вешается на летящий ключ: Trail между BladeBase и BladeTip, искры и свет — на острие.
	local f = Instance.new("Folder")
	local t = trail({
		Texture = TEX.trail, TextureMode = Enum.TextureMode.Stretch, Lifetime = 0.3,
		LightEmission = 1, Brightness = 1.2, Color = cs(C.gold, C.ember),
		Transparency = ns(0, 0.05, 1, 1), WidthScale = ns(0, 1, 1, 0),
	})
	t.Name = "Trail"
	t.Parent = f
	emitter(f, "Sparkles", {
		Texture = TEX.star, Color = cs(C.core), Rate = 25, Lifetime = nr(0.4),
		Speed = nr(1, 3), SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0, 0.3, 0.6, 1, 0),
		Rotation = nr(0, 360),
	})
	emitter(f, "Glow", {
		Texture = TEX.glow, Color = cs(C.gold), Rate = 20, Lifetime = nr(0.25), LockedToPart = true,
		Size = ns(0, 2.5, 1, 1.5), Transparency = ns(0, 0.5, 1, 1),
	})
	light(f, C.gold, 3, 10)
	return f
end)

template(unlock, "Impact", function()
	local p = anchor(Vector3.new(1, 0.2, 1), { BaseRadius = 1 })
	emitter(p, "Glow", {
		Texture = TEX.glow, Color = cs(C.core, C.gold), Lifetime = nr(0.25), ZOffset = 0.5,
		Size = ns(0, 2, 1, 6), Transparency = ns(0, 0.2, 1, 1), attrs = { Emit = 1 },
	})
	emitter(p, "Ring", flat({
		Texture = TEX.ring, Color = cs(C.gold), Lifetime = nr(0.3),
		Size = ns(0, 1, 1, 6), Transparency = ns(0, 0, 1, 1), attrs = { Emit = 1 },
	}))
	emitter(p, "Dust", {
		Texture = TEX.smoke, Color = cs(C.dust), LightEmission = 0, LightInfluence = 1,
		Lifetime = nr(0.5, 0.8), Speed = nr(6, 10), EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(15, 15), Drag = 4, Size = ns(0, 0.8, 1, 2.4), Transparency = ns(0, 0.4, 1, 1),
		attrs = { Emit = 10, Pattern = "ring" },
	})
	emitter(p, "Sparks", {
		Texture = TEX.spark, Color = cs(C.core, C.gold), Lifetime = nr(0.25, 0.4), Speed = nr(15, 25),
		Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, -30, 0), Size = ns(0, 0.6, 1, 0),
		attrs = { Emit = 24 },
	})
	light(p, C.gold, 2, 12, 0.3)
	return p
end)

template(unlock, "Seal", function()
	local p = anchor(Vector3.new(20, 0.2, 20), { BaseRadius = 10, ScalePart = true })
	emitter(p, "Glyph", flat({
		Texture = TEX.seal, Color = cs(C.gold), Lifetime = nr(1.5), Brightness = 1.5,
		Size = ns(0, 16, 0.12, 20.5, 1, 20.5), Transparency = ns(0, 1, 0.1, 0.05, 0.85, 0.1, 1, 1),
		Rotation = nr(0, 360), RotSpeed = nr(25), attrs = { Emit = 1, ScaleSize = true, MatchLife = true },
	}))
	emitter(p, "Flare", flat({
		Texture = TEX.ring, Color = cs(C.core), Lifetime = nr(0.3),
		Size = ns(0, 1, 1, 22), Transparency = ns(0, 0, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	}))
	emitter(p, "Runes", {
		Texture = TEX.glow, Color = cs(C.gold, C.core), Rate = 50, Lifetime = nr(0.6, 1.0),
		Speed = nr(2, 5), EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = ns(0, 0.3, 1, 0),
	})
	light(p, C.gold, 1.6, 20)
	return p
end)

template(unlock, "Chain", function()
	return beam({
		Texture = TEX.chain, TextureMode = Enum.TextureMode.Static, TextureLength = 1.4,
		Width0 = 0.9, Width1 = 0.9, Segments = 16, LightEmission = 0.8, Brightness = 2,
		Color = cs(C.gold), Transparency = ns(0), FaceCamera = true,
	})
end)

template(unlock, "ChainEnd", function()
	-- Эмиттеры на конце цепи у врага (кладутся в Attachment на враге).
	local f = Instance.new("Folder")
	emitter(f, "Glow", {
		Texture = TEX.glow, Color = cs(C.gold), Rate = 12, Lifetime = nr(0.3), LockedToPart = true,
		Size = ns(0, 1.6, 1, 1), Transparency = ns(0, 0.3, 1, 1),
	})
	emitter(f, "Sparkles", {
		Texture = TEX.star, Color = cs(C.core), Rate = 6, Lifetime = nr(0.4), Speed = nr(1, 2),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0, 0.3, 0.5, 1, 0),
	})
	return f
end)

template(unlock, "Burst", function()
	local p = anchor(Vector3.new(1, 0.2, 1), { BaseRadius = 10 })
	emitter(p, "Glow", {
		Texture = TEX.glow, Color = cs(C.core), Lifetime = nr(0.3), ZOffset = 0.5,
		Size = ns(0, 5, 1, 18), Transparency = ns(0, 0.3, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	})
	emitter(p, "Ring", flat({
		Texture = TEX.ring, Color = cs(C.cream, C.gold), Lifetime = nr(0.4),
		Size = ns(0, 2, 1, 26), Transparency = ns(0, 0, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	}))
	emitter(p, "Ring2", flat({
		Texture = TEX.ring, Color = cs(C.gold), Lifetime = nr(0.55),
		Size = ns(0, 1, 1, 30), Transparency = ns(0, 0.3, 1, 1), attrs = { Emit = 1, EmitDelay = 0.08, ScaleSize = true },
	}))
	emitter(p, "Sparks", {
		Texture = TEX.spark, Color = cs(C.core, C.gold), Lifetime = nr(0.4, 0.7), Speed = nr(30, 60),
		Orientation = Enum.ParticleOrientation.VelocityParallel, SpreadAngle = Vector2.new(180, 180),
		EmissionDirection = Enum.NormalId.Top, Drag = 3, Acceleration = Vector3.new(0, -20, 0),
		Size = ns(0, 1.2, 1, 0), attrs = { Emit = 80, ScaleSpeed = true },
	})
	emitter(p, "Stars", {
		Texture = TEX.star, Color = cs(C.core), Lifetime = nr(0.5, 0.8), Speed = nr(8, 20),
		SpreadAngle = Vector2.new(180, 180), EmissionDirection = Enum.NormalId.Top, Drag = 2,
		Size = ns(0, 0, 0.2, 2, 1, 0), Rotation = nr(0, 360), RotSpeed = nr(-120, 120), attrs = { Emit = 16 },
	})
	emitter(p, "Smoke", {
		Texture = TEX.smoke, Color = cs(C.gold, C.dust), LightEmission = 0.4, LightInfluence = 0.5,
		Lifetime = nr(0.6, 1.0), Speed = nr(15, 25), EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(15, 15), Drag = 4, Size = ns(0, 2, 1, 5), Transparency = ns(0, 0.4, 1, 1),
		Rotation = nr(0, 360), attrs = { Emit = 16, Pattern = "ring", ScaleSpeed = true },
	})
	light(p, C.core, 3, 24, 0.6)
	return p
end)

-- ---------- Keyhole ----------

template(keyhole, "Mark", function()
	-- Значок метки над врагом (три штуки в ряд). Частица, «прилипшая» к точке:
	-- короткая жизнь и постоянный выпуск дают ровный значок. BillboardGui в
	-- этом месте не рисуется, поэтому так.
	local f = Instance.new("Folder")
	f:SetAttribute("OnColor", C.gold)
	f:SetAttribute("OffColor", hex("#5A4330"))
	f:SetAttribute("Spacing", 0.85) -- стады между значками
	emitter(f, "Icon", {
		Texture = TEX.keyhole, Color = cs(C.gold), Rate = 30, Lifetime = nr(0.1),
		LockedToPart = true, Size = ns(0.75), Transparency = ns(0), ZOffset = 0.5,
	})
	return f
end)

template(keyhole, "Burst", function()
	local p = anchor(Vector3.new(1, 1, 1))
	emitter(p, "Glow", {
		Texture = TEX.glow, Color = cs(C.core), Lifetime = nr(0.22), ZOffset = 0.5,
		Size = ns(0, 2, 1, 5), Transparency = ns(0, 0.2, 1, 1), attrs = { Emit = 1 },
	})
	emitter(p, "Sparks", {
		Texture = TEX.spark, Color = cs(C.core, C.gold), Lifetime = nr(0.25, 0.4), Speed = nr(18, 32),
		Orientation = Enum.ParticleOrientation.VelocityParallel, SpreadAngle = Vector2.new(180, 180),
		Drag = 4, Size = ns(0, 0.8, 1, 0), attrs = { Emit = 22 },
	})
	emitter(p, "Stars", {
		Texture = TEX.star, Color = cs(C.core), Lifetime = nr(0.35), Speed = nr(2, 6),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0, 0.2, 1.4, 1, 0), attrs = { Emit = 3 },
	})
	light(p, C.gold, 2.5, 12, 0.3)
	return p
end)

-- ---------- Enemy: телеграфы врагов ----------
-- Цвет стрелки код ставит по типу телеграфа (белый — парируемый, красный —
-- только уворот); остальное — отсюда.

local enemy = folder(fx, "Enemy")
template(enemy, "AimLine", function()
	-- Прицел стрелка после фиксации: луч от лука до конца дальности.
	return beam({
		Width0 = 0.14, Width1 = 0.1, LightEmission = 1, Brightness = 2, FaceCamera = true,
		Color = cs(hex("#FF3B2F")), Transparency = ns(0, 0.05, 1, 0.5),
	})
end)
template(enemy, "AimGround", function()
	-- Коридор выстрела на земле: бегущие шевроны по направлению стрелы.
	return beam({
		Texture = TEX.chevron, TextureMode = Enum.TextureMode.Static, TextureLength = 2.4, TextureSpeed = 3,
		Width0 = 1.5, Width1 = 1.5, LightEmission = 1, Brightness = 1.5,
		Color = cs(hex("#FF3B2F")), Transparency = ns(0, 0.25, 0.85, 0.35, 1, 1),
	})
end)
template(enemy, "DashArrow", function()
	-- Стрелка рывка (Тень) и тарана (Привратник) на земле.
	return beam({
		Texture = TEX.chevron, TextureMode = Enum.TextureMode.Static, TextureLength = 2.2, TextureSpeed = 4,
		Width0 = 2.6, Width1 = 2.2, LightEmission = 1, Brightness = 2,
		Color = cs(Color3.new(1, 1, 1)), Transparency = ns(0, 0.1, 0.85, 0.2, 1, 1),
	})
end)

-- Общие кольцо и вспышка врагов: цвет и время код ставит при вызове.
template(enemy, "Ring", function()
	local p = anchor(Vector3.new(1, 0.2, 1), { BaseRadius = 1 })
	emitter(p, "Ring", flat({
		Texture = TEX.ring, Color = cs(Color3.new(1, 1, 1)), Lifetime = nr(0.6),
		Size = ns(0, 0.4, 1, 2.1), Transparency = ns(0, 0.1, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	}))
	return p
end)
template(enemy, "Flash", function()
	local p = anchor(Vector3.new(1, 1, 1), { BaseRadius = 1 })
	emitter(p, "Glow", {
		Texture = TEX.glow, Color = cs(Color3.new(1, 1, 1)), Lifetime = nr(0.6), ZOffset = 0.5,
		Size = ns(0, 0.5, 1, 1.6), Transparency = ns(0, 0.15, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	})
	return p
end)

-- Взрыв Треснувшего: огненный шар, дым, искры, осколки, кольцо по земле.
template(enemy, "Explosion", function()
	local p = anchor(Vector3.new(1, 0.2, 1), { BaseRadius = 10 })
	local fire = hex("#FF8A2A")
	emitter(p, "Core", {
		Texture = TEX.glow, Color = cs(hex("#FFE6A0"), fire), Lifetime = nr(0.3), ZOffset = 0.5,
		Size = ns(0, 4, 1, 14), Transparency = ns(0, 0.1, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	})
	emitter(p, "Fire", {
		Texture = TEX.smoke, Color = cs(fire, hex("#5A2A18")), LightEmission = 0.8, LightInfluence = 0.3,
		Lifetime = nr(0.5, 0.9), Speed = nr(18, 30), EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(25, 25), Drag = 5, Acceleration = Vector3.new(0, 6, 0),
		Size = ns(0, 2.5, 1, 6), Transparency = ns(0, 0.1, 0.6, 0.5, 1, 1), Rotation = nr(0, 360), RotSpeed = nr(-90, 90),
		attrs = { Emit = 24, Pattern = "ring", ScaleSpeed = true },
	})
	emitter(p, "Smoke", {
		Texture = TEX.smoke, Color = cs(hex("#3A2E28")), LightEmission = 0, LightInfluence = 1,
		Lifetime = nr(1.2, 1.8), Speed = nr(4, 9), EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(50, 50), Drag = 2, Acceleration = Vector3.new(0, 3, 0),
		Size = ns(0, 3, 1, 9), Transparency = ns(0, 0.35, 1, 1), Rotation = nr(0, 360), attrs = { Emit = 14 },
	})
	emitter(p, "Sparks", {
		Texture = TEX.spark, Color = cs(hex("#FFE6A0"), fire), Lifetime = nr(0.4, 0.8), Speed = nr(30, 55),
		Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(80, 80), Drag = 2, Acceleration = Vector3.new(0, -40, 0),
		Size = ns(0, 1, 1, 0), attrs = { Emit = 45 },
	})
	emitter(p, "Debris", {
		Texture = TEX.rock, Color = cs(hex("#4A4350"), hex("#2B1F17")), LightEmission = 0, LightInfluence = 1,
		Lifetime = nr(0.8, 1.2), Speed = nr(18, 32), EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, -70, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6, 0.3), NumberSequenceKeypoint.new(1, 0.6, 0.3) }),
		Rotation = nr(0, 360), RotSpeed = nr(-360, 360), attrs = { Emit = 18 },
	})
	emitter(p, "Ring", flat({
		Texture = TEX.ring, Color = cs(fire), Lifetime = nr(0.4),
		Size = ns(0, 2, 1, 21), Transparency = ns(0, 0, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	}))
	light(p, fire, 4, 22, 0.5)
	return p
end)

-- Смерть врага: пыль, осколки брони (цвет — по броне, ставит код),
-- угли и голубые искры памяти.
template(enemy, "Death", function()
	local p = anchor(Vector3.new(1, 1, 1), { BaseRadius = 1 })
	emitter(p, "Dust", {
		Texture = TEX.smoke, Color = cs(hex("#5C4D42")), LightEmission = 0, LightInfluence = 1,
		Lifetime = nr(0.7, 1.2), Speed = nr(3, 7), EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(70, 70), Drag = 3, Size = ns(0, 1.5, 1, 4), Transparency = ns(0, 0.35, 1, 1),
		Rotation = nr(0, 360), attrs = { Emit = 12, ScaleSize = true },
	})
	emitter(p, "Chips", {
		Texture = TEX.rock, Color = cs(hex("#6B5643")), LightEmission = 0, LightInfluence = 1,
		Lifetime = nr(0.7, 1.1), Speed = nr(10, 20), EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0, -60, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4, 0.2), NumberSequenceKeypoint.new(1, 0.4, 0.2) }),
		Rotation = nr(0, 360), RotSpeed = nr(-400, 400), attrs = { Emit = 22, ScaleSize = true },
	})
	emitter(p, "Embers", {
		Texture = TEX.spark, Color = cs(hex("#FFB536"), hex("#FF5A1A")), Lifetime = nr(0.4, 0.8), Speed = nr(8, 16),
		Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, -15, 0), Size = ns(0, 0.6, 1, 0),
		attrs = { Emit = 14 },
	})
	emitter(p, "Memory", {
		Texture = TEX.glow, Color = cs(hex("#6FE3FF")), Lifetime = nr(0.8, 1.3), Speed = nr(1, 3),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, 3, 0),
		Size = ns(0, 0.35, 1, 0), attrs = { Emit = 10 },
	})
	return p
end)

-- Появление: пыль памяти стягивается к врагу, тёмная спираль под ногами.
template(enemy, "Spawn", function()
	local p = anchor(Vector3.new(6, 0.2, 6), { BaseRadius = 3, ScalePart = true })
	emitter(p, "Swirl", flat({
		Texture = TEX.swirl, Color = cs(hex("#3A2E3E")), LightEmission = 0, LightInfluence = 1, Rate = 5,
		Lifetime = nr(0.6), Size = ns(0, 6.5, 1, 4), Transparency = ns(0, 1, 0.3, 0.35, 1, 1),
		Rotation = nr(0, 360), RotSpeed = nr(-300, -240), attrs = { ScaleSize = true },
	}))
	emitter(p, "Motes", {
		Texture = TEX.spark, Color = cs(hex("#FFB536"), hex("#6FE3FF")), Rate = 70, Lifetime = nr(0.35),
		Speed = nr(8), Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(10, 25), Size = ns(0, 0.6, 1, 0.15),
		attrs = { Pattern = "inward", ScaleSpeed = true },
	})
	emitter(p, "Smoke", {
		Texture = TEX.smoke, Color = cs(hex("#2E2632")), LightEmission = 0, LightInfluence = 1, Rate = 14,
		Lifetime = nr(0.7, 1.0), Speed = nr(2, 4), EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = ns(0, 1.2, 1, 3), Transparency = ns(0, 0.5, 1, 1), Rotation = nr(0, 360),
	})
	return p
end)

-- Душа: светящийся сгусток с искрящимся следом (летит к клинку героя).
template(enemy, "Soul", function()
	local f = Instance.new("Folder")
	emitter(f, "Core", {
		Texture = TEX.glow, Color = cs(hex("#6FE3FF")), Rate = 30, Lifetime = nr(0.15), LockedToPart = true,
		Size = ns(0, 0.9, 1, 0.5), Transparency = ns(0, 0.2, 1, 1),
	})
	emitter(f, "Trail", {
		Texture = TEX.star, Color = cs(Color3.new(1, 1, 1), hex("#6FE3FF")), Rate = 45, Lifetime = nr(0.25, 0.4),
		Speed = nr(0.2, 0.8), SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.35, 1, 0), Rotation = nr(0, 360),
	})
	return f
end)

-- ---------- Combat: удары героя ----------

local combat = folder(fx, "Combat")
template(combat, "Slash", function()
	-- Серп удара: след между двумя точками, которые проходят дугу удара
	-- (AttackFxController). Цвет — по редкости оружия, ставит код.
	return trail({
		Texture = TEX.trail, TextureMode = Enum.TextureMode.Stretch, Lifetime = 0.18,
		LightEmission = 1, Brightness = 1.6, Color = cs(Color3.new(1, 1, 1)),
		Transparency = ns(0, 0.05, 0.6, 0.4, 1, 1), WidthScale = ns(0, 1, 1, 0.25),
	})
end)
template(combat, "StunStar", function()
	-- Звезда оглушения: кладётся в точку, кружащую над головой врага.
	local f = Instance.new("Folder")
	emitter(f, "Star", {
		Texture = TEX.star, Color = cs(hex("#FFD36A")), Rate = 14, Lifetime = nr(0.35), LockedToPart = true,
		Size = ns(0, 0.9, 1, 0.6), Transparency = ns(0, 0, 1, 1), Rotation = nr(0, 360), RotSpeed = nr(120, 200),
	})
	emitter(f, "Sparkle", {
		Texture = TEX.glow, Color = cs(hex("#FFE6A0")), Rate = 10, Lifetime = nr(0.3), Speed = nr(0.5, 1),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.25, 1, 0),
	})
	return f
end)

-- ---------- Env: окружение этажа ----------

local env = folder(fx, "Env")
template(env, "Fire", function()
	-- Живой огонь у факелов и жаровен карты (точки — Floor1Map.<зона>.Lights,
	-- ставит EnvironmentController). Воксельное пламя карты остаётся под ним.
	local f = Instance.new("Folder")
	emitter(f, "Flame", {
		Texture = TEX.glow, Color = cs(hex("#FFD27A"), hex("#FF5A1A")), Rate = 22, Lifetime = nr(0.35, 0.6),
		Speed = nr(2, 3.5), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(12, 12),
		Acceleration = Vector3.new(0, 3, 0), Size = ns(0, 1.1, 0.5, 0.8, 1, 0), Transparency = ns(0, 0.25, 1, 1),
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		WindAffectsDrag = true, Drag = 1,
	})
	emitter(f, "Embers", {
		Texture = TEX.spark, Color = cs(hex("#FFB536"), hex("#FF5A1A")), Rate = 5, Lifetime = nr(0.8, 1.4),
		Speed = nr(2, 4), Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(0, 2, 0), Size = ns(0, 0.25, 1, 0),
		WindAffectsDrag = true, Drag = 0.8,
	})
	emitter(f, "Smoke", {
		Texture = TEX.smoke, Color = cs(hex("#3A2E28")), LightEmission = 0, LightInfluence = 1, Rate = 3,
		Lifetime = nr(1.5, 2.2), Speed = nr(1.5, 2.5), EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(10, 10), Size = ns(0, 0.8, 1, 2.6), Transparency = ns(0, 0.75, 1, 1),
		Rotation = nr(0, 360), RotSpeed = nr(-30, 30), WindAffectsDrag = true, Drag = 0.6,
	})
	return f
end)

template(env, "Embers", function()
	-- Парящие угольки вместо неоновых кубиков-угольков в мешах карты:
	-- деталь растягивается по рамке спрятанного меша (EnvironmentController),
	-- выпуск — RatePerVolume на кубический стад.
	local p = anchor(Vector3.new(4, 4, 4))
	p:SetAttribute("RatePerVolume", 0.03)
	emitter(p, "Embers", {
		Texture = TEX.glow, Color = cs(hex("#FFB547"), hex("#FF6A2A")), Rate = 4, Lifetime = nr(2.5, 4),
		Speed = nr(0.3, 0.9), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, 0.6, 0), Size = ns(0, 0, 0.15, 0.32, 0.8, 0.22, 1, 0),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		WindAffectsDrag = true, Drag = 0.5, Brightness = 1.5,
	})
	return p
end)

-- ---------- Weather: песчаная буря этажа 1 ----------
-- Деталь ходит за камерой (SandstormController), Front смотрит по ветру.
-- Частицы несёт Workspace.GlobalWind (WindAffectsDrag). Атрибут Gust у
-- эмиттера — во сколько раз растёт выпуск в порыв.

local weather = folder(fx, "Weather")
template(weather, "Sandstorm", function()
	local p = anchor(Vector3.new(150, 50, 150))
	local sandHaze = hex("#D2A472")
	emitter(p, "Sheets", {
		Texture = TEX.smoke, Color = cs(sandHaze), LightEmission = 0, LightInfluence = 1,
		Rate = 10, Lifetime = nr(5, 7), Speed = nr(2, 4), EmissionDirection = Enum.NormalId.Front,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = ns(0, 18, 1, 34), Transparency = ns(0, 1, 0.25, 0.88, 0.75, 0.9, 1, 1),
		Rotation = nr(0, 360), RotSpeed = nr(-10, 10), WindAffectsDrag = true, Drag = 0.6,
		attrs = { Gust = 2.2 },
	})
	emitter(p, "Dust", {
		Texture = TEX.glow, Color = cs(hex("#E6C79A")), LightEmission = 0.3, LightInfluence = 1,
		Rate = 160, Lifetime = nr(1.5, 2.5), Speed = nr(1, 3), EmissionDirection = Enum.NormalId.Front,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22, 0.08), NumberSequenceKeypoint.new(1, 0.22, 0.08) }),
		Transparency = ns(0, 0.5, 0.5, 0.3, 1, 1), WindAffectsDrag = true, Drag = 2,
		attrs = { Gust = 2 },
	})
	emitter(p, "Streaks", {
		Texture = TEX.wind, Color = cs(hex("#F0D6AE")), LightEmission = 0.2, LightInfluence = 1,
		Rate = 8, Lifetime = nr(1.2, 1.8), Speed = nr(25, 35), EmissionDirection = Enum.NormalId.Front,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = ns(0, 6, 1, 10), Transparency = ns(0, 1, 0.3, 0.75, 1, 1), WindAffectsDrag = true, Drag = 1,
		attrs = { Gust = 3 },
	})
	return p
end)

-- ---------- Weapon: ауры оружия в покое ----------
-- Референс (доки/reference-mode, скрины 2026-11-22): мягкий дым, обнимающий
-- клинок, поверх — яркие микро-частицы и редкие искры; свет спокойный.
-- VoxelWeaponBuilder красит эмиттеры Smoke/Aura/Motes в цвет glow-вокселей
-- конкретного оружия (перекраска в addRarityFx), Stars остаются светлыми.
-- Эмиттеры Shape=Box+ShapeStyle=Volume builder сажает в AuraVolume (объём
-- клинка). Rate в шаблонах — рабочие значения: билдер включает эмиттеры
-- сам (Enabled=false в шаблоне, Flare остаётся Emit-вспышкой).

template(weapon, "epic", function()
	local f = Instance.new("Folder")
	-- дым: крупные мягкие клубы вдоль клинка, медленно всплывают
	emitter(f, "Smoke", {
		Texture = TEX.smoke, Color = cs(C.gold), Rate = 14, Lifetime = nr(1.8, 2.8),
		Speed = nr(0.12, 0.45), SpreadAngle = Vector2.new(180, 180),
		Size = ns(0, 0.9, 0.45, 1.7, 1, 2.4), Transparency = ns(0, 0.62, 0.6, 0.88, 1, 1),
		LightEmission = 0.2, LightInfluence = 0.6, Rotation = nr(-60, 60), RotSpeed = nr(-22, 22),
		Acceleration = Vector3.new(0, 0.55, 0), ZOffset = -0.4,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	-- мошки: яркие микро-частицы «энергии» по объёму
	emitter(f, "Motes", {
		Texture = TEX.glow, Color = cs(C.gold, C.core), Rate = 9, Lifetime = nr(0.9, 1.6),
		Speed = nr(0.15, 0.55), SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.1, 1, 0),
		LightEmission = 0.9, Acceleration = Vector3.new(0, 0.35, 0),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	-- мерцание: редкие звёздочки
	emitter(f, "Stars", {
		Texture = TEX.star, Color = cs(C.core), Rate = 2, Lifetime = nr(0.5, 0.9),
		Speed = nr(0.15, 0.5), SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0, 0.4, 0.6, 1, 0),
		Rotation = nr(0, 360), LightEmission = 0.8,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	light(f, C.gold, 0.45, 6)
	return f
end)

template(weapon, "legendary", function()
	local f = Instance.new("Folder")
	emitter(f, "Smoke", {
		Texture = TEX.smoke, Color = cs(C.gold), Rate = 20, Lifetime = nr(2, 3.2),
		Speed = nr(0.15, 0.55), SpreadAngle = Vector2.new(180, 180),
		Size = ns(0, 1.1, 0.45, 2.1, 1, 3), Transparency = ns(0, 0.58, 0.6, 0.86, 1, 1),
		LightEmission = 0.25, LightInfluence = 0.55, Rotation = nr(-70, 70), RotSpeed = nr(-26, 26),
		Acceleration = Vector3.new(0, 0.65, 0), ZOffset = -0.4,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	emitter(f, "Aura", {
		Texture = TEX.glow, Color = cs(C.gold), Rate = 6, Lifetime = nr(0.6), LockedToPart = true,
		Size = ns(0, 2.2, 1, 3), Transparency = ns(0, 0.82, 1, 1),
	})
	emitter(f, "Motes", {
		Texture = TEX.glow, Color = cs(C.gold, C.core), Rate = 14, Lifetime = nr(1, 1.8),
		Speed = nr(0.2, 0.7), SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.12, 1, 0),
		LightEmission = 0.9, Acceleration = Vector3.new(0, 0.45, 0),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	emitter(f, "Stars", {
		Texture = TEX.star, Color = cs(C.core), Rate = 3, Lifetime = nr(0.5, 0.9),
		Speed = nr(0.2, 0.7), SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0, 0.4, 0.8, 1, 0),
		Rotation = nr(0, 360), LightEmission = 0.85,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	-- вспышка: раз в несколько секунд её выпускает клиентский WeaponPresence
	local flareE = emitter(f, "Flare", {
		Texture = TEX.glow, Color = cs(C.core), Rate = 0, Lifetime = nr(0.5, 0.9),
		Speed = nr(0.5, 1.6), SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.35, 1, 0),
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	flareE:SetAttribute("Flare", 22)
	light(f, C.gold, 0.65, 6)
	return f
end)

template(weapon, "secret", function()
	local f = Instance.new("Folder")
	emitter(f, "Smoke", {
		Texture = TEX.smoke, Color = cs(C.gold), Rate = 26, Lifetime = nr(2.2, 3.4),
		Speed = nr(0.18, 0.6), SpreadAngle = Vector2.new(180, 180),
		Size = ns(0, 1.3, 0.5, 2.4, 1, 3.4), Transparency = ns(0, 0.55, 0.6, 0.85, 1, 1),
		LightEmission = 0.28, LightInfluence = 0.55, Rotation = nr(-80, 80), RotSpeed = nr(-30, 30),
		Acceleration = Vector3.new(0, 0.7, 0), ZOffset = -0.4,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	emitter(f, "Aura", {
		Texture = TEX.glow, Color = cs(C.gold), Rate = 8, Lifetime = nr(0.6), LockedToPart = true,
		Size = ns(0, 2.6, 1, 3.4), Transparency = ns(0, 0.8, 1, 1),
	})
	emitter(f, "Motes", {
		Texture = TEX.glow, Color = cs(C.gold, C.core), Rate = 18, Lifetime = nr(1.1, 2),
		Speed = nr(0.25, 0.8), SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.14, 1, 0),
		LightEmission = 0.95, Acceleration = Vector3.new(0, 0.5, 0),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	emitter(f, "Stars", {
		Texture = TEX.star, Color = cs(C.core), Rate = 4, Lifetime = nr(0.5, 1),
		Speed = nr(0.2, 0.8), SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0, 0.5, 0.9, 1, 0),
		Rotation = nr(0, 360), LightEmission = 0.9,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	local flareE = emitter(f, "Flare", {
		Texture = TEX.glow, Color = cs(C.core), Rate = 0, Lifetime = nr(0.5, 1),
		Speed = nr(0.6, 1.8), SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.42, 1, 0),
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	flareE:SetAttribute("Flare", 30)
	light(f, C.gold, 0.65, 7)
	return f
end)

print(("[BuildFx] готово: создано %d, уже было %d. Сохраните место (Ctrl+S)."):format(created, skipped))
