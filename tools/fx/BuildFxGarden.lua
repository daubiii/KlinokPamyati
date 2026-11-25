--[[
	BuildFxGarden — Garden-способности, индивидуальные FX.WeaponHits и ауры FX.Weapon.<id оружия>.
	Запуск: Studio, Command Bar, режим Edit (ПОСЛЕ BuildFx.lua: нужна папка FX). Потом Ctrl+S.
	Повторный запуск создаёт только то, чего нет: правки в Studio не теряются.
	REBUILD = true — снести FX.Garden и ауры этажа 2 и собрать заново.

	Шаблоны того же устройства, что у BuildFx.lua (см. шапку там): Part с ParticleEmitter, атрибуты Emit/EmitDelay/
	Pattern/ScaleSize/ScaleSpeed/MatchLife, PointLight с Fade. Код — Lib/FxKit.lua и Controllers/AbilityFxGarden.lua.

	Текстуры: старые id (glow, spark, star, ring, smoke, slash…) уже загружены. Три новых (лист, лепесток, капля)
	лежат в tools/fx/textures_garden/*.png: загрузите, впишите id в NEW ниже и запустите REBUILD = true
	(или правьте Texture у эмиттеров в Studio). Пока id пустые, берутся glow/star: эффекты работают, но без листьев.

	Что подстраивать на глаз в Studio (всё правится в шаблонах, код трогать не нужно):
	  Garden/ReapWave   — Crescent (серп): Size и Rotation под вашу текстуру slash;
	  Garden/PruneCut   — Slash: Speed, Size, направление веера;
	  Garden/Puddle     — Water/Ripples: прозрачность и цвет воды;
	  Garden/Bloom      — лепестки: Speed и Lifetime.
]]

local REBUILD = false

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	glow = "rbxassetid://127300277477869",
	spark = "rbxassetid://128412204996964",
	star = "rbxassetid://139416211393590",
	ring = "rbxassetid://89952298821336",
	smoke = "rbxassetid://124049881141719",
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

-- Новые текстуры этажа 2 (tools/fx/textures_garden): вписать id после загрузки, например "rbxassetid://123".
local NEW = { leaf = "", petal = "", drop = "" }
local function tex(name, fallback)
	if NEW[name] and NEW[name] ~= "" then
		return NEW[name]
	end
	return TEX[fallback]
end

-- Палитра этажа 2 (Palette.Floors[2]) и производные.
local G = {
	deep = hex("#1F3A33"),
	green = hex("#3F7A5C"),
	leaf = hex("#86BA6C"),
	leafDark = hex("#4C8A4F"),
	teal = hex("#5FD0C0"),
	mint = hex("#B8F2E6"),
	foam = hex("#E6F4EE"),
	rotLight = hex("#B6D84A"),
	rotDark = hex("#3F6B2A"),
	rose = hex("#D97A88"),
	roseDark = hex("#B04A5A"),
	pollen = hex("#F0E08A"),
	steel = hex("#CFE8DF"),
}

-- ===== сборка =====

local fx = RS:FindFirstChild("FX")
if not fx then
	error("[BuildFxGarden] нет ReplicatedStorage.FX: сначала запустите tools/fx/BuildFx.lua")
end
local weapon = folder(fx, "Weapon")
local weaponHits = folder(fx, "WeaponHits")
if REBUILD then
	local old = fx:FindFirstChild("Garden")
	if old then
		old:Destroy()
	end
	if weaponHits then
		weaponHits:Destroy()
		weaponHits = folder(fx, "WeaponHits")
	end
	for _, name in ipairs({ "reaper_blade", "tidal_hammer", "gardener_shears" }) do
		local aura = weapon:FindFirstChild(name)
		if aura then
			aura:Destroy()
		end
	end
end
local garden = folder(fx, "Garden")

-- A small signature burst for each floor-two weapon; the attack controller
-- layers these over its animated blade arc at the strike frame.
local function weaponStrike(name, primary, secondary, detailTexture, count, heavy)
	template(weaponHits, name, function()
		local p = anchor(Vector3.new(1, 1, 1), { BaseRadius = 1 })
		emitter(p, "Edge", {
			Texture = TEX.slash, Color = cs(G.foam, primary), Lifetime = nr(0.18, 0.24), Speed = nr(4, 8),
			SpreadAngle = Vector2.new(10, 10), Orientation = Enum.ParticleOrientation.VelocityParallel,
			Size = ns(0, heavy and 5.2 or 4.2, 1, heavy and 2.8 or 1.6),
			Transparency = ns(0, 0.05, 1, 1), EmissionDirection = Enum.NormalId.Front,
			attrs = { Emit = heavy and 2 or 1, ScaleSize = true },
		})
		emitter(p, "Sparks", {
			Texture = TEX.spark, Color = cs(secondary, primary), Lifetime = nr(0.24, 0.48),
			Speed = nr(heavy and 16 or 20, heavy and 32 or 38), SpreadAngle = Vector2.new(45, 45),
			Orientation = Enum.ParticleOrientation.VelocityParallel, Size = ns(0, heavy and 0.8 or 0.62, 1, 0),
			Drag = 4, Acceleration = Vector3.new(0, -12, 0), EmissionDirection = Enum.NormalId.Front,
			attrs = { Emit = count },
		})
		emitter(p, "Signature", {
			Texture = detailTexture, Color = cs(primary, secondary), Lifetime = nr(0.55, 0.9),
			Speed = nr(heavy and 7 or 9, heavy and 15 or 18), SpreadAngle = Vector2.new(65, 50),
			Size = ns(0, heavy and 0.75 or 0.62, 0.65, heavy and 0.55 or 0.42, 1, 0),
			Rotation = nr(0, 360), RotSpeed = nr(-260, 260), LightEmission = 0.35,
			Drag = 2, Acceleration = Vector3.new(0, -7, 0), EmissionDirection = Enum.NormalId.Front,
			attrs = { Emit = count, ScaleSize = true },
		})
		light(p, primary, heavy and 2.4 or 1.8, heavy and 12 or 9, 0.24)
		return p
	end)
end

weaponStrike("garden_machete", G.leaf, G.mint, tex("leaf", "star"), 14, false)
weaponStrike("reed_saber", G.teal, G.foam, tex("leaf", "star"), 18, false)
weaponStrike("mud_mallet", G.rotLight, G.leafDark, TEX.rock, 18, true)
weaponStrike("thorn_blade", G.rose, G.roseDark, TEX.crack, 16, false)
weaponStrike("root_hammer", G.leafDark, G.pollen, TEX.rock, 24, true)
weaponStrike("reaper_blade", G.mint, G.teal, tex("leaf", "star"), 22, false)
weaponStrike("tidal_hammer", G.teal, G.foam, tex("drop", "spark"), 30, true)
weaponStrike("gardener_shears", G.rose, G.pollen, tex("petal", "star"), 20, false)

-- Wide, camera-facing ribbons leave a curved 3D trail while the ability moves.
template(garden, "ReapRibbon", function()
	return trail({
		Texture = TEX.trail, TextureMode = Enum.TextureMode.Stretch, Lifetime = 0.24,
		LightEmission = 1, Brightness = 3, Color = cs(G.foam, G.teal),
		Transparency = ns(0, 0.04, 0.72, 0.18, 1, 1),
		WidthScale = ns(0, 1.7, 0.2, 1.2, 1, 0),
	})
end)

template(garden, "FloodRibbon", function()
	return trail({
		Texture = TEX.wind, TextureMode = Enum.TextureMode.Wrap, TextureLength = 1.6, Lifetime = 0.32,
		LightEmission = 1, Brightness = 2.5, Color = cs(G.foam, G.teal),
		Transparency = ns(0, 0.1, 0.7, 0.26, 1, 1),
		WidthScale = ns(0, 2.4, 0.28, 1.5, 1, 0),
	})
end)

template(garden, "PruneRibbon", function()
	return trail({
		Texture = TEX.slash, TextureMode = Enum.TextureMode.Stretch, Lifetime = 0.2,
		LightEmission = 1, Brightness = 3, Color = cs(G.foam, G.rose),
		Transparency = ns(0, 0.02, 0.76, 0.22, 1, 1),
		WidthScale = ns(0, 1.45, 0.35, 1, 1, 0),
	})
end)

template(garden, "BloomRibbon", function()
	return trail({
		Texture = TEX.trail, TextureMode = Enum.TextureMode.Stretch, Lifetime = 0.34,
		LightEmission = 1, Brightness = 2.4, Color = cs(G.pollen, G.rose),
		Transparency = ns(0, 0.12, 0.75, 0.3, 1, 1),
		WidthScale = ns(0, 1.2, 0.28, 0.85, 1, 0),
	})
end)

-- ---------- Жатва ----------

template(garden, "ReapCast", function()
	local p = anchor(Vector3.new(1, 1, 1), { BaseRadius = 1 })
	emitter(p, "Glow", {
		Texture = TEX.glow, Color = cs(G.mint), Lifetime = nr(0.22), ZOffset = 0.5,
		Size = ns(0, 2, 1, 5.5), Transparency = ns(0, 0.3, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	})
	emitter(p, "Leaves", {
		Texture = tex("leaf", "star"), Color = cs(G.leaf, G.leafDark), Lifetime = nr(0.5, 0.8), Speed = nr(6, 13),
		SpreadAngle = Vector2.new(70, 70), Size = ns(0, 0.5, 0.6, 0.5, 1, 0), LightEmission = 0.2,
		Rotation = nr(0, 360), RotSpeed = nr(-240, 240), Drag = 2, Acceleration = Vector3.new(0, -6, 0),
		EmissionDirection = Enum.NormalId.Front, attrs = { Emit = 10 },
	})
	emitter(p, "Sparks", {
		Texture = TEX.spark, Color = cs(G.mint, G.teal), Lifetime = nr(0.2, 0.4), Speed = nr(16, 30),
		SpreadAngle = Vector2.new(35, 35), Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = ns(0, 0.6, 1, 0), Drag = 4, EmissionDirection = Enum.NormalId.Front, attrs = { Emit = 14 },
	})
	light(p, G.teal, 2, 10, 0.3)
	return p
end)

-- Летит вперёд по дуге серпа: полоса-серп, листья, споры (код двигает деталь Tween).
template(garden, "ReapWave", function()
	local p = anchor(Vector3.new(1, 1, 1), { BaseRadius = 1 })
	emitter(p, "Crescent", {
		Texture = TEX.slash, Color = cs(G.mint, G.teal), Rate = 34, Lifetime = nr(0.2),
		Size = ns(0, 6.5, 1, 4.5), Transparency = ns(0, 0.1, 1, 1), ZOffset = 0.4, Rotation = nr(0, 0),
		LockedToPart = false,
	})
	emitter(p, "Core", {
		Texture = TEX.glow, Color = cs(G.steel, G.teal), Rate = 20, Lifetime = nr(0.18), LockedToPart = true,
		Size = ns(0, 3.4, 1, 1.2), Transparency = ns(0, 0.35, 1, 1),
	})
	emitter(p, "Leaves", {
		Texture = tex("leaf", "star"), Color = cs(G.leaf, G.leafDark), Rate = 55, Lifetime = nr(0.45, 0.8),
		Speed = nr(3, 9), SpreadAngle = Vector2.new(40, 40), Size = ns(0, 0.55, 0.7, 0.45, 1, 0),
		Rotation = nr(0, 360), RotSpeed = nr(-260, 260), LightEmission = 0.2, LockedToPart = false,
		Acceleration = Vector3.new(0, -5, 0), EmissionDirection = Enum.NormalId.Back,
	})
	emitter(p, "Spores", {
		Texture = TEX.glow, Color = cs(G.mint, G.teal), Rate = 40, Lifetime = nr(0.4, 0.7), Speed = nr(1, 4),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.4, 1, 0), LockedToPart = false,
	})
	light(p, G.teal, 2, 10)
	return p
end)

template(garden, "ReapHit", function()
	local p = anchor(Vector3.new(1, 1, 1), { BaseRadius = 1 })
	emitter(p, "Flash", {
		Texture = TEX.glow, Color = cs(G.mint), Lifetime = nr(0.2), ZOffset = 0.5,
		Size = ns(0, 2, 1, 4.5), Transparency = ns(0, 0.25, 1, 1), attrs = { Emit = 1 },
	})
	emitter(p, "Leaves", {
		Texture = tex("leaf", "star"), Color = cs(G.leaf, G.leafDark), Lifetime = nr(0.5, 0.9), Speed = nr(8, 16),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.55, 0.7, 0.45, 1, 0), Rotation = nr(0, 360),
		RotSpeed = nr(-300, 300), LightEmission = 0.2, Drag = 3, Acceleration = Vector3.new(0, -9, 0), attrs = { Emit = 12 },
	})
	emitter(p, "Sparks", {
		Texture = TEX.spark, Color = cs(G.mint, G.teal), Lifetime = nr(0.2, 0.4), Speed = nr(14, 28),
		SpreadAngle = Vector2.new(180, 180), Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = ns(0, 0.7, 1, 0), Drag = 5, attrs = { Emit = 14 },
	})
	light(p, G.teal, 1.8, 9, 0.25)
	return p
end)

-- Гниль на враге: кладётся в Attachment на корне врага и живёт, пока длится эффект.
template(garden, "Rot", function()
	local f = Instance.new("Folder")
	emitter(f, "Bubbles", {
		Texture = tex("drop", "glow"), Color = cs(G.rotLight, G.rotDark), Rate = 11, Lifetime = nr(0.8, 1.3),
		Speed = nr(1, 2.4), SpreadAngle = Vector2.new(35, 35), Size = ns(0, 0.45, 0.8, 0.3, 1, 0),
		Transparency = ns(0, 0.1, 1, 1), Acceleration = Vector3.new(0, 2.5, 0), Rotation = nr(-25, 25),
		EmissionDirection = Enum.NormalId.Top,
	})
	emitter(f, "Spores", {
		Texture = TEX.glow, Color = cs(G.rotLight, G.rotDark), Rate = 7, Lifetime = nr(0.6, 1), Speed = nr(0.4, 1.2),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.3, 1, 0),
	})
	emitter(f, "Miasma", {
		Texture = TEX.smoke, Color = cs(G.rotDark), LightEmission = 0, LightInfluence = 1, Rate = 3,
		Lifetime = nr(1, 1.5), Speed = nr(0.3, 0.8), SpreadAngle = Vector2.new(60, 60), Size = ns(0, 1.4, 1, 3),
		Transparency = ns(0, 0.55, 1, 1), Rotation = nr(0, 360), RotSpeed = nr(-20, 20),
		Acceleration = Vector3.new(0, 1, 0),
	})
	light(f, G.rotLight, 0.6, 6)
	return f
end)

-- ---------- Паводок ----------

template(garden, "FloodSlam", function()
	local p = anchor(Vector3.new(1, 0.2, 1), { BaseRadius = 6 })
	emitter(p, "Ring", flat({
		Texture = TEX.ring, Color = cs(G.mint, G.teal), Lifetime = nr(0.5), ZOffset = 0.3,
		Size = ns(0, 3, 1, 15), Transparency = ns(0, 0.15, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	}))
	emitter(p, "Splash", {
		Texture = tex("drop", "glow"), Color = cs(G.foam, G.teal), Lifetime = nr(0.5, 0.9), Speed = nr(14, 26),
		SpreadAngle = Vector2.new(38, 38), Size = ns(0, 0.8, 0.7, 0.55, 1, 0), Acceleration = Vector3.new(0, -55, 0),
		EmissionDirection = Enum.NormalId.Top, attrs = { Emit = 34, ScaleSpeed = true },
	})
	emitter(p, "Foam", {
		Texture = TEX.smoke, Color = cs(G.foam), LightEmission = 0.3, Lifetime = nr(0.5, 0.9), Speed = nr(9, 15),
		SpreadAngle = Vector2.new(10, 10), Drag = 4, Size = ns(0, 1.2, 1, 3.2), Transparency = ns(0, 0.35, 1, 1),
		Rotation = nr(0, 360), RotSpeed = nr(-50, 50), EmissionDirection = Enum.NormalId.Front,
		attrs = { Emit = 14, Pattern = "ring", ScaleSpeed = true },
	})
	light(p, G.teal, 2.2, 12, 0.35)
	return p
end)

-- Волна воды конусом вперёд (деталь смотрит по взгляду героя, Front = вперёд).
template(garden, "FloodWave", function()
	local p = anchor(Vector3.new(1, 1, 1), { BaseRadius = 9 })
	emitter(p, "Surge", {
		Texture = TEX.glow, Color = cs(G.foam, G.teal), Lifetime = nr(0.35, 0.55), Speed = nr(22, 36),
		SpreadAngle = Vector2.new(34, 5), Size = ns(0, 1.6, 0.6, 1.2, 1, 0.2), Transparency = ns(0, 0.2, 1, 1),
		Drag = 2, Acceleration = Vector3.new(0, -8, 0), EmissionDirection = Enum.NormalId.Front,
		attrs = { Emit = 70, ScaleSpeed = true },
	})
	emitter(p, "Droplets", {
		Texture = tex("drop", "spark"), Color = cs(G.foam, G.mint), Lifetime = nr(0.5, 0.9), Speed = nr(12, 24),
		SpreadAngle = Vector2.new(42, 30), Size = ns(0, 0.7, 0.7, 0.5, 1, 0), Acceleration = Vector3.new(0, -48, 0),
		EmissionDirection = Enum.NormalId.Front, attrs = { Emit = 42, ScaleSpeed = true },
	})
	emitter(p, "Foam", {
		Texture = TEX.star, Color = cs(G.foam), Lifetime = nr(0.3, 0.5), Speed = nr(10, 22),
		SpreadAngle = Vector2.new(40, 20), Size = ns(0, 0, 0.2, 1.1, 1, 0), Rotation = nr(0, 360),
		RotSpeed = nr(-120, 120), EmissionDirection = Enum.NormalId.Front, attrs = { Emit = 14, ScaleSpeed = true },
	})
	return p
end)

-- Разлив на земле на время puddleTime: круг воды, расходящиеся кольца, пузыри.
template(garden, "Puddle", function()
	local p = anchor(Vector3.new(9, 0.2, 9), { BaseRadius = 4.5, ScalePart = true })
	emitter(p, "Water", flat({
		Texture = TEX.glow, Color = cs(G.teal, G.green), Lifetime = nr(4), ZOffset = -0.2,
		Size = ns(0, 9.5, 1, 9), Transparency = ns(0, 0.55, 0.75, 0.6, 1, 1), LightEmission = 0.5,
		attrs = { Emit = 1, ScaleSize = true, MatchLife = true },
	}))
	emitter(p, "Ripples", flat({
		Texture = TEX.ring, Color = cs(G.mint), Rate = 2.2, Lifetime = nr(1.1), Size = ns(0, 1, 1, 8.5),
		Transparency = ns(0, 0.3, 1, 1), attrs = { ScaleSize = true },
	}))
	emitter(p, "Bubbles", {
		Texture = tex("drop", "glow"), Color = cs(G.foam, G.mint), Rate = 9, Lifetime = nr(0.7, 1.2), Speed = nr(1, 2.5),
		SpreadAngle = Vector2.new(20, 20), Size = ns(0, 0.35, 0.6, 0.4, 1, 0), Acceleration = Vector3.new(0, 2, 0),
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top,
	})
	light(p, G.teal, 0.9, 10)
	return p
end)

template(garden, "PuddleEnd", function()
	local p = anchor(Vector3.new(1, 0.2, 1), { BaseRadius = 4.5 })
	emitter(p, "Ring", flat({
		Texture = TEX.ring, Color = cs(G.mint), Lifetime = nr(0.5), Size = ns(0, 6, 1, 10),
		Transparency = ns(0, 0.4, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	}))
	emitter(p, "Drops", {
		Texture = tex("drop", "glow"), Color = cs(G.foam, G.teal), Lifetime = nr(0.4, 0.7), Speed = nr(5, 10),
		SpreadAngle = Vector2.new(30, 30), Size = ns(0, 0.5, 1, 0), Acceleration = Vector3.new(0, -30, 0),
		EmissionDirection = Enum.NormalId.Top, attrs = { Emit = 14, ScaleSpeed = true },
	})
	return p
end)

-- ---------- Обрезка ----------

template(garden, "PruneCut", function()
	local p = anchor(Vector3.new(1, 1, 1), { BaseRadius = 7 })
	emitter(p, "Slash", {
		Texture = TEX.slash, Color = cs(G.steel, G.mint), Lifetime = nr(0.16, 0.22), Speed = nr(36, 46),
		SpreadAngle = Vector2.new(3, 3), Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = ns(0, 5.5, 1, 1.5), Transparency = ns(0, 0, 1, 1), ZOffset = 0.5, EmissionDirection = Enum.NormalId.Front,
		attrs = { Emit = 3, ScaleSize = true },
	})
	emitter(p, "Blades", {
		Texture = TEX.spark, Color = cs(G.steel, G.teal), Lifetime = nr(0.2, 0.35), Speed = nr(26, 44),
		SpreadAngle = Vector2.new(20, 14), Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = ns(0, 0.8, 1, 0), Drag = 3, EmissionDirection = Enum.NormalId.Front, attrs = { Emit = 20 },
	})
	emitter(p, "Leaves", {
		Texture = tex("leaf", "star"), Color = cs(G.leaf, G.leafDark), Lifetime = nr(0.5, 0.9), Speed = nr(6, 15),
		SpreadAngle = Vector2.new(60, 40), Size = ns(0, 0.5, 0.7, 0.4, 1, 0), Rotation = nr(0, 360),
		RotSpeed = nr(-260, 260), LightEmission = 0.2, Acceleration = Vector3.new(0, -6, 0),
		EmissionDirection = Enum.NormalId.Front, attrs = { Emit = 9 },
	})
	light(p, G.mint, 1.8, 9, 0.25)
	return p
end)

template(garden, "PruneHit", function()
	local p = anchor(Vector3.new(1, 1, 1), { BaseRadius = 1 })
	emitter(p, "Petals", {
		Texture = tex("petal", "star"), Color = cs(G.rose, G.roseDark), Lifetime = nr(0.7, 1.2), Speed = nr(6, 13),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.55, 0.7, 0.45, 1, 0), Rotation = nr(0, 360),
		RotSpeed = nr(-240, 240), LightEmission = 0.25, Drag = 3, Acceleration = Vector3.new(0, -7, 0), attrs = { Emit = 10 },
	})
	emitter(p, "Sparks", {
		Texture = TEX.spark, Color = cs(G.steel, G.mint), Lifetime = nr(0.2, 0.35), Speed = nr(12, 24),
		SpreadAngle = Vector2.new(180, 180), Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = ns(0, 0.6, 1, 0), Drag = 5, attrs = { Emit = 10 },
	})
	return p
end)

-- ---------- Цветение ----------

template(garden, "Thorn", function()
	local p = anchor(Vector3.new(1, 1, 1), { BaseRadius = 1 })
	emitter(p, "Thorns", {
		Texture = tex("leaf", "star"), Color = cs(G.leaf, G.leafDark), Lifetime = nr(0.4, 0.7), Speed = nr(4, 9),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.4, 0.7, 0.3, 1, 0), Rotation = nr(0, 360),
		RotSpeed = nr(-200, 200), LightEmission = 0.2, Drag = 3, Acceleration = Vector3.new(0, -5, 0),
		attrs = { Emit = 5, ScaleSize = true },
	})
	emitter(p, "Spark", {
		Texture = TEX.glow, Color = cs(G.leaf), Lifetime = nr(0.2), Size = ns(0, 1.6, 1, 2.6),
		Transparency = ns(0, 0.4, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	})
	return p
end)

template(garden, "Bloom", function()
	local p = anchor(Vector3.new(1, 0.2, 1), { BaseRadius = 4 })
	emitter(p, "Ring", flat({
		Texture = TEX.ring, Color = cs(G.rose, G.roseDark), Lifetime = nr(0.5), ZOffset = 0.3,
		Size = ns(0, 2, 1, 9), Transparency = ns(0, 0.2, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	}))
	emitter(p, "Petals", {
		Texture = tex("petal", "star"), Color = cs(G.rose, G.roseDark), Lifetime = nr(0.7, 1.2), Speed = nr(9, 16),
		SpreadAngle = Vector2.new(8, 8), Size = ns(0, 0.7, 0.7, 0.55, 1, 0), Rotation = nr(0, 360),
		RotSpeed = nr(-260, 260), LightEmission = 0.25, Drag = 2, Acceleration = Vector3.new(0, -4, 0),
		EmissionDirection = Enum.NormalId.Front, attrs = { Emit = 36, Pattern = "ring", ScaleSpeed = true },
	})
	emitter(p, "Pollen", {
		Texture = TEX.glow, Color = cs(G.pollen, G.rose), Lifetime = nr(0.6, 1.1), Speed = nr(2, 6),
		SpreadAngle = Vector2.new(30, 30), Size = ns(0, 0.45, 1, 0), Acceleration = Vector3.new(0, 2, 0),
		EmissionDirection = Enum.NormalId.Top, attrs = { Emit = 24, ScaleSpeed = true },
	})
	light(p, G.rose, 2, 10, 0.4)
	return p
end)

-- Дополнительные сигнатурные всплески для читаемости каста с первого взгляда.
template(garden, "ReapBurst", function()
	local p = anchor(Vector3.new(1, 0.2, 1), { BaseRadius = 3.5 })
	emitter(p, "Ring", flat({
		Texture = TEX.ring, Color = cs(G.mint, G.teal), Lifetime = nr(0.45), ZOffset = 0.35,
		Size = ns(0, 3, 1, 13), Transparency = ns(0, 0.12, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	}))
	emitter(p, "Leaves", {
		Texture = tex("leaf", "star"), Color = cs(G.leaf, G.mint), Lifetime = nr(0.55, 0.95), Speed = nr(8, 15),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.6, 0.65, 0.48, 1, 0),
		Rotation = nr(0, 360), RotSpeed = nr(-280, 280), LightEmission = 0.3, Drag = 2,
		Acceleration = Vector3.new(0, -7, 0), attrs = { Emit = 30, Pattern = "ring" },
	})
	emitter(p, "Motes", {
		Texture = TEX.glow, Color = cs(G.foam, G.teal), Lifetime = nr(0.25, 0.45), Speed = nr(10, 18),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.5, 1, 0), attrs = { Emit = 28, Pattern = "ring" },
	})
	light(p, G.mint, 2.4, 12, 0.35)
	return p
end)

template(garden, "FloodCrest", function()
	local p = anchor(Vector3.new(1, 1, 1), { BaseRadius = 9 })
	emitter(p, "Crest", {
		Texture = TEX.glow, Color = cs(G.foam, G.teal), Lifetime = nr(0.35, 0.55), Speed = nr(24, 38),
		SpreadAngle = Vector2.new(28, 12), Size = ns(0, 2.2, 0.55, 1.5, 1, 0.2),
		Transparency = ns(0, 0.18, 1, 1), Drag = 2, Acceleration = Vector3.new(0, -9, 0),
		EmissionDirection = Enum.NormalId.Front, attrs = { Emit = 48, ScaleSpeed = true },
	})
	emitter(p, "Drops", {
		Texture = tex("drop", "spark"), Color = cs(G.foam, G.mint), Lifetime = nr(0.45, 0.75), Speed = nr(14, 26),
		SpreadAngle = Vector2.new(42, 34), Size = ns(0, 0.8, 0.65, 0.45, 1, 0),
		Acceleration = Vector3.new(0, -44, 0), EmissionDirection = Enum.NormalId.Front,
		attrs = { Emit = 36, ScaleSpeed = true },
	})
	emitter(p, "Foam", {
		Texture = TEX.star, Color = cs(G.foam), Lifetime = nr(0.3, 0.5), Speed = nr(10, 20),
		SpreadAngle = Vector2.new(36, 20), Size = ns(0, 0, 0.2, 1.2, 1, 0), Rotation = nr(0, 360),
		RotSpeed = nr(-150, 150), EmissionDirection = Enum.NormalId.Front, attrs = { Emit = 20, ScaleSpeed = true },
	})
	light(p, G.foam, 1.8, 10, 0.3)
	return p
end)

template(garden, "PruneCross", function()
	local p = anchor(Vector3.new(1, 1, 1), { BaseRadius = 7 })
	emitter(p, "Edge", {
		Texture = TEX.slash, Color = cs(G.foam, G.teal), Lifetime = nr(0.18, 0.24), Speed = nr(38, 48),
		SpreadAngle = Vector2.new(7, 5), Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = ns(0, 6.2, 1, 1.8), Transparency = ns(0, 0, 1, 1), ZOffset = 0.6,
		EmissionDirection = Enum.NormalId.Front, attrs = { Emit = 4, ScaleSize = true },
	})
	emitter(p, "Shards", {
		Texture = TEX.spark, Color = cs(G.steel, G.mint), Lifetime = nr(0.2, 0.38), Speed = nr(24, 42),
		SpreadAngle = Vector2.new(26, 18), Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = ns(0, 0.9, 1, 0), Drag = 3, EmissionDirection = Enum.NormalId.Front, attrs = { Emit = 28 },
	})
	emitter(p, "Leaves", {
		Texture = tex("leaf", "star"), Color = cs(G.leaf, G.leafDark), Lifetime = nr(0.45, 0.8), Speed = nr(8, 17),
		SpreadAngle = Vector2.new(60, 42), Size = ns(0, 0.55, 0.7, 0.4, 1, 0),
		Rotation = nr(0, 360), RotSpeed = nr(-280, 280), LightEmission = 0.25,
		Acceleration = Vector3.new(0, -7, 0), EmissionDirection = Enum.NormalId.Front, attrs = { Emit = 18 },
	})
	light(p, G.steel, 1.5, 9, 0.2)
	return p
end)

template(garden, "BloomBurst", function()
	local p = anchor(Vector3.new(1, 0.2, 1), { BaseRadius = 4 })
	emitter(p, "Halo", flat({
		Texture = TEX.ring, Color = cs(G.pollen, G.rose), Lifetime = nr(0.55), ZOffset = 0.35,
		Size = ns(0, 2.5, 1, 10), Transparency = ns(0, 0.1, 1, 1), attrs = { Emit = 1, ScaleSize = true },
	}))
	emitter(p, "Petals", {
		Texture = tex("petal", "star"), Color = cs(G.rose, G.pollen), Lifetime = nr(0.8, 1.35), Speed = nr(8, 15),
		SpreadAngle = Vector2.new(10, 10), Size = ns(0, 0.75, 0.65, 0.55, 1, 0), Rotation = nr(0, 360),
		RotSpeed = nr(-300, 300), LightEmission = 0.35, Drag = 2, Acceleration = Vector3.new(0, -5, 0),
		EmissionDirection = Enum.NormalId.Front, attrs = { Emit = 48, Pattern = "ring", ScaleSpeed = true },
	})
	emitter(p, "Pollen", {
		Texture = TEX.glow, Color = cs(G.pollen, G.rose), Lifetime = nr(0.7, 1.2), Speed = nr(3, 8),
		SpreadAngle = Vector2.new(30, 30), Size = ns(0, 0.5, 1, 0),
		Acceleration = Vector3.new(0, 3, 0), EmissionDirection = Enum.NormalId.Top, attrs = { Emit = 28 },
	})
	light(p, G.rose, 2.6, 12, 0.45)
	return p
end)

-- ---------- Ауры оружия этажа 2 (FX.Weapon.<id оружия>, ищутся раньше ауры по редкости) ----------

template(weapon, "reaper_blade", function()
	local f = Instance.new("Folder")
	emitter(f, "Motes", {
		Texture = TEX.glow, Color = cs(G.mint, G.teal), Rate = 9, Lifetime = nr(0.8, 1.4), Speed = nr(0.3, 1),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.28, 1, 0),
	})
	emitter(f, "Leaves", {
		Texture = tex("leaf", "star"), Color = cs(G.leaf, G.leafDark), Rate = 2.2, Lifetime = nr(1, 1.6), Speed = nr(0.4, 1.2),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.3, 0.6, 0.35, 1, 0), Rotation = nr(0, 360),
		RotSpeed = nr(-90, 90), LightEmission = 0.2, Acceleration = Vector3.new(0, -0.6, 0),
	})
	light(f, G.teal, 1, 8)
	return f
end)

template(weapon, "tidal_hammer", function()
	local f = Instance.new("Folder")
	emitter(f, "Drops", {
		Texture = tex("drop", "glow"), Color = cs(G.foam, G.teal), Rate = 7, Lifetime = nr(0.8, 1.3), Speed = nr(0.3, 1),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.3, 0.7, 0.22, 1, 0), Acceleration = Vector3.new(0, -3, 0),
	})
	emitter(f, "Bubbles", {
		Texture = TEX.glow, Color = cs(G.mint), Rate = 4, Lifetime = nr(1, 1.6), Speed = nr(0.3, 0.9),
		SpreadAngle = Vector2.new(40, 40), Size = ns(0, 0.22, 1, 0), Acceleration = Vector3.new(0, 1.5, 0),
	})
	light(f, G.teal, 1, 8)
	return f
end)

template(weapon, "gardener_shears", function()
	local f = Instance.new("Folder")
	emitter(f, "Aura", {
		Texture = TEX.glow, Color = cs(G.rose, G.mint), Rate = 6, Lifetime = nr(0.5), LockedToPart = true,
		Size = ns(0, 2.2, 1, 3), Transparency = ns(0, 0.8, 1, 1),
	})
	emitter(f, "Petals", {
		Texture = tex("petal", "star"), Color = cs(G.rose, G.roseDark), Rate = 5, Lifetime = nr(1, 1.7), Speed = nr(0.4, 1.3),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.34, 0.6, 0.3, 1, 0), Rotation = nr(0, 360),
		RotSpeed = nr(-120, 120), LightEmission = 0.3, Acceleration = Vector3.new(0, -0.8, 0),
	})
	emitter(f, "Motes", {
		Texture = TEX.glow, Color = cs(G.mint, G.teal), Rate = 10, Lifetime = nr(0.8, 1.4), Speed = nr(0.4, 1.4),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.3, 1, 0), Acceleration = Vector3.new(0, 1, 0),
	})
	light(f, G.rose, 1.5, 9)
	return f
end)

print(("[BuildFxGarden] готово: создано %d, уже было %d. Сохраните место (Ctrl+S)."):format(created, skipped))
