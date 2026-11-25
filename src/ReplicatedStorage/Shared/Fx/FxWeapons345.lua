--!nonstrict
-- FxWeapons345 (общий)
-- Шаблоны эффектов оружия этажей 3–5 декларативно: из них FxBuilder345 собирает
-- ReplicatedStorage.FX.Hunt/*, FX.Forge/*, FX.Chron/* и ауры FX.Weapon.<id>.
-- Шаблоны строит сервер при старте (только недостающие — правки, сохранённые в месте, не трогаются)
-- и Studio-скрипт tools/fx/BuildFxWeapons345.lua (с REBUILD = true — пересобрать всё по этой таблице).
--
-- Текстуры: TEX — уже загруженные (те же id, что Lib/FxTex). NEW — свои PNG из tools/fx/textures_345/:
-- загрузите в Creator Hub и впишите id сюда (только цифры). Пока id пустой — берётся FALLBACK из TEX.
--
-- Поля эмиттера: tex, color ("#hex" | {"#a","#b"} | {{t,"#hex"},…}), size / transparency (число | {a,b} | {{t,v},…}),
-- life {min,max}, speed {min,max}, spread {x,y}, rate, emit, delay, pattern ("ring" | "inward"), accel {x,y,z},
-- drag, rot {min,max}, spin {min,max}, light (LightEmission), influence (LightInfluence), bright (Brightness),
-- z (ZOffset), shape ("Box"|"Sphere"|"Cylinder"|"Disc"), style ("Volume"|"Surface"), inout ("Outward"|"Inward"|"InAndOut"),
-- dir (EmissionDirection), orient ("FacingCamera"|"VelocityParallel"|"VelocityPerpendicular"|"FacingCameraWorldUp"),
-- squash, locked (LockedToPart), scaleSize, scaleSpeed, matchLife, timeScale.

local S = {}

S.TEX = {
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
	magma = "rbxassetid://75327668421864", -- те же загрузки, что Lib/FxTex
}

-- Свои текстуры (tools/fx/textures_345/<имя>.png). Впишите asset id после загрузки.
S.NEW = {
	-- Флипбуки из pixelfx (tools/flipbooks/sheets/<имя>.png, сетка 4×4, fb_pillar — 8×8).
	-- Пока id пустой — играет запасная статичная текстура из FALLBACK, флипбук выключен.
	fb_scythe = "78840927727548",
	fb_slash = "108328207238386",
	fb_cleave = "71398688196557",
	fb_hit = "112761525124613",
	fb_crit = "135287832117287",
	fb_slam = "136391715674843",
	fb_wave = "114504240666822",
	fb_splash = "87054503454408",
	fb_pillar = "106690843062221",
	fb_feathers = "76006890126602",
	fb_bird = "129907541521573",
	fb_thorns = "128907884774452",
	fb_roots = "99475720108797",
	fb_tendrils = "131518957457699",
	fb_inkburst = "134436285851153",
	fb_runes = "137237369193769",
	fb_erase = "136522820819325",
	fb_memory = "105730462190244",
	fb_bite = "121458717567600",
	fb_jaws = "97000089264632",
	feather = "",
	page = "",
	rune = "",
	ember = "",
	sparkle = "",
	thinring = "",
	crescent = "",
	ink = "",
	claw = "",
	sand = "",
	clock = "",
	steam = "",
}

S.FALLBACK = {
	fb_scythe = "slash",
	fb_slash = "slash",
	fb_cleave = "slash",
	fb_hit = "spark",
	fb_crit = "star",
	fb_slam = "smoke",
	fb_wave = "swirl",
	fb_splash = "smoke",
	fb_pillar = "glow",
	fb_feathers = "slash",
	fb_bird = "glow",
	fb_thorns = "crack",
	fb_roots = "crack",
	fb_tendrils = "smoke",
	fb_inkburst = "smoke",
	fb_runes = "star",
	fb_erase = "spark",
	fb_memory = "glow",
	fb_bite = "slash",
	fb_jaws = "ring",
	feather = "slash",
	page = "smoke",
	rune = "star",
	ember = "spark",
	sparkle = "star",
	thinring = "ring",
	crescent = "slash",
	ink = "smoke",
	claw = "slash",
	sand = "spark",
	clock = "ring",
	steam = "smoke",
}

-- ===== Палитры =====
local HUNT = { gold = "#FFD45A", amber = "#FFB347", pale = "#FFF1C9", blood = "#E0402E", prey = "#FF4A3A", smoke = "#3B2A1E", iron = "#8E8696", bone = "#E8DCC0", spirit = "#FFE8A3" }
local FORGE = { orange = "#FF7A2B", yellow = "#FFC857", white = "#FFF1C2", red = "#E2572B", soot = "#2A2320", slag = "#54362A", steam = "#E8E4DE" }
local CHRON = { violet = "#9B7BFF", lavender = "#B49CFF", ice = "#B8E3FF", ink = "#1D1B3A", ink2 = "#2E2A5C", sand = "#FFD98A", memory = "#6FE3FF", white = "#F2F6FF" }
S.Palettes = { hunt = HUNT, forge = FORGE, chron = CHRON }

-- ===== Частые заготовки =====
local FLAT = { orient = "VelocityPerpendicular", dir = "Top", speed = { 0.01, 0.01 }, spread = { 0, 0 } }
local function with(base, extra)
	local t = table.clone(base)
	for k, v in pairs(extra) do
		t[k] = v
	end
	return t
end
-- Плоский декаль на земле (кольцо, руна, лужа): размер в стадах.
local function flat(name, tex, color, size, life, extra)
	return with(FLAT, with({ name = name, tex = tex, color = color, size = size, life = life, light = 1, influence = 0, z = 0.2, emit = 1 }, extra or {}))
end
local function burst(name, tex, color, size, life, speed, emit, extra)
	return with({ name = name, tex = tex, color = color, size = size, life = life, speed = speed, emit = emit, spread = { 180, 180 }, light = 1, influence = 0 }, extra or {})
end
local function stream(name, tex, color, size, life, speed, rate, extra)
	return with({ name = name, tex = tex, color = color, size = size, life = life, speed = speed, rate = rate, spread = { 180, 180 }, light = 1, influence = 0 }, extra or {})
end

S.Templates = {}
local T = S.Templates
local function part(path, radius, emitters, opts)
	opts = opts or {}
	-- version: правки существующего шаблона доезжают до места только с номером
	-- больше сохранённого (FxBuilder345 пересобирает старую версию сам).
	T[path] = { kind = "part", radius = radius, emitters = emitters, light = opts.light, scalePart = opts.scalePart, size = opts.size, shape = opts.shape, version = opts.version }
end
local function folder(path, emitters, opts)
	opts = opts or {}
	T[path] = { kind = "folder", emitters = emitters, light = opts.light, trail = opts.trail }
end
local function trail(path, tex, color, opts)
	T[path] = with({ kind = "trail", tex = tex, color = color }, opts or {})
end

-- ===================== ЭТАЖ 3: ОХОТА =====================

-- Свора: вой — волна пыли и души гончих стягиваются к герою.
part("Hunt/PackHowl", 3, {
	flat("Ring", "thinring", HUNT.spirit, { { 0, 1 }, { 1, 9 } }, { 0.45, 0.45 }, { transparency = { { 0, 0.2 }, { 1, 1 } } }),
	burst("Souls", "glow", { HUNT.pale, HUNT.amber }, { { 0, 0.5 }, { 0.5, 0.9 }, { 1, 0 } }, { 0.5, 0.7 }, { 6, 9 }, 24, { pattern = "inward", dir = "Front", spread = { 8, 8 }, shape = "Cylinder", style = "Surface", scaleSpeed = true }),
	burst("Dust", "smoke", HUNT.smoke, { { 0, 1.2 }, { 1, 3.2 } }, { 0.6, 0.9 }, { 4, 7 }, 18, { pattern = "ring", dir = "Front", spread = { 10, 10 }, transparency = { { 0, 0.5 }, { 1, 1 } }, light = 0, influence = 1, drag = 3 }),
	burst("Sparks", "spark", HUNT.gold, { { 0, 0.35 }, { 1, 0 } }, { 0.3, 0.55 }, { 10, 16 }, 30, { orient = "VelocityParallel", squash = 1.2, drag = 4 }),
}, { light = { color = HUNT.amber, brightness = 3, range = 12, fade = 0.5 } })

-- Призрачная гончая (на летящем держателе): дымное тело, светящееся ядро, глаза-искры.
folder("Hunt/Hound", {
	stream("Body", "smoke", { HUNT.spirit, HUNT.smoke }, { { 0, 1.7 }, { 0.6, 1.1 }, { 1, 0 } }, { 0.28, 0.4 }, { 0.5, 1.5 }, 70, { transparency = { { 0, 0.25 }, { 1, 1 } }, light = 0.6, z = 0.5 }),
	stream("Core", "glow", HUNT.amber, { { 0, 1.4 }, { 1, 0.6 } }, { 0.15, 0.2 }, { 0, 0 }, 30, { transparency = { { 0, 0.3 }, { 1, 1 } }, locked = true, z = 1 }),
	stream("Eyes", "sparkle", HUNT.pale, { { 0, 0.5 }, { 1, 0 } }, { 0.12, 0.18 }, { 0, 0.5 }, 16, { locked = true, z = 1.5 }),
	stream("Embers", "ember", HUNT.gold, { { 0, 0.25 }, { 1, 0 } }, { 0.4, 0.7 }, { 1, 3 }, 26, { accel = { 0, 4, 0 }, drag = 2 }),
}, { light = { color = HUNT.amber, brightness = 1.8, range = 8 }, trail = "Hunt/HoundTrail" })
trail("Hunt/HoundTrail", "trail", { HUNT.pale, HUNT.amber }, { lifetime = 0.3, width = 1.6, transparency = { { 0, 0.3 }, { 1, 1 } } })

-- Укус: когти крест-накрест, искры и брызги.
part("Hunt/Bite", 1.5, {
	burst("Claw", "claw", { HUNT.pale, HUNT.blood }, { { 0, 2.6 }, { 0.3, 3.2 }, { 1, 3.4 } }, { 0.18, 0.24 }, { 0, 0 }, 2, { rot = { -50, 50 }, transparency = { { 0, 0 }, { 0.6, 0.3 }, { 1, 1 } }, z = 2 }),
	burst("Sparks", "spark", { HUNT.gold, HUNT.blood }, { { 0, 0.3 }, { 1, 0 } }, { 0.2, 0.35 }, { 8, 14 }, 12, { orient = "VelocityParallel", squash = 1, drag = 6 }),
	burst("Flash", "glow", HUNT.amber, { { 0, 1.5 }, { 1, 2.6 } }, { 0.12, 0.12 }, { 0, 0 }, 1, { transparency = { { 0, 0.3 }, { 1, 1 } } }),
})
part("Hunt/HoundFade", 1.5, {
	burst("Puff", "smoke", { HUNT.spirit, HUNT.smoke }, { { 0, 1 }, { 1, 2.4 } }, { 0.4, 0.6 }, { 1, 3 }, 10, { transparency = { { 0, 0.4 }, { 1, 1 } }, light = 0.5 }),
	burst("Motes", "glow", HUNT.amber, { { 0, 0.3 }, { 1, 0 } }, { 0.4, 0.7 }, { 2, 4 }, 10, { accel = { 0, 3, 0 } }),
})

-- Капкан: кольцо челюстей раскрывается, затем схлопывается.
part("Hunt/SnareOpen", 6.5, {
	flat("Ring", "thinring", HUNT.iron, { { 0, 10 }, { 0.2, 13 }, { 1, 13 } }, { 0.5, 0.5 }, { transparency = { { 0, 1 }, { 0.15, 0.2 }, { 0.85, 0.3 }, { 1, 1 } }, matchLife = true }),
	flat("Glow", "glow", HUNT.amber, 13, { 0.5, 0.5 }, { transparency = { { 0, 1 }, { 0.3, 0.75 }, { 1, 1 } } }),
	burst("Teeth", "spark", { HUNT.pale, HUNT.iron }, { { 0, 0.55 }, { 1, 0.2 } }, { 0.4, 0.5 }, { 0.5, 1 }, 36, { pattern = "ring", dir = "Top", spread = { 5, 5 }, shape = "Cylinder", style = "Surface", orient = "VelocityParallel", squash = 2, accel = { 0, -2, 0 } }),
}, { light = { color = HUNT.amber, brightness = 1.5, range = 10, fade = 0.5 }, scalePart = true, size = Vector3.new(13, 0.2, 13), shape = "Cylinder" })
part("Hunt/SnareSnap", 6.5, {
	burst("Jaws", "spark", { HUNT.pale, HUNT.gold }, { { 0, 0.6 }, { 1, 0.1 } }, { 0.18, 0.26 }, { 26, 34 }, 48, { pattern = "inward", dir = "Front", spread = { 4, 4 }, orient = "VelocityParallel", squash = 2.5, scaleSpeed = true }),
	burst("Dust", "smoke", HUNT.smoke, { { 0, 1.5 }, { 1, 3.5 } }, { 0.6, 0.9 }, { 2, 5 }, 22, { pattern = "inward", dir = "Front", spread = { 15, 15 }, transparency = { { 0, 0.4 }, { 1, 1 } }, light = 0, influence = 1, drag = 3, scaleSpeed = true }),
	burst("Flash", "glow", HUNT.gold, { { 0, 4 }, { 1, 7 } }, { 0.16, 0.16 }, { 0, 0 }, 1, { transparency = { { 0, 0.3 }, { 1, 1 } } }),
	burst("Shards", "rock", HUNT.iron, { { 0, 0.5 }, { 1, 0.2 } }, { 0.5, 0.8 }, { 8, 14 }, 14, { accel = { 0, -40, 0 }, spin = { -300, 300 }, light = 0, influence = 1 }),
}, { light = { color = HUNT.gold, brightness = 4, range = 14, fade = 0.35 } })
folder("Hunt/Snared", {
	stream("Iron", "spark", HUNT.iron, { { 0, 0.3 }, { 1, 0 } }, { 0.25, 0.4 }, { 1, 3 }, 14, { orient = "VelocityParallel", squash = 1 }),
	stream("Ring", "thinring", HUNT.amber, { { 0, 3 }, { 1, 2 } }, { 0.4, 0.4 }, { 0, 0 }, 3, { transparency = { { 0, 0.5 }, { 1, 1 } }, locked = true }),
})

-- Последний гон: старт рывка, след косы, удар по пути, рог.
part("Hunt/DashBurst", 2, {
	burst("Wind", "wind", HUNT.pale, { { 0, 2 }, { 1, 4 } }, { 0.25, 0.35 }, { 12, 18 }, 10, { dir = "Back", spread = { 25, 25 }, transparency = { { 0, 0.4 }, { 1, 1 } }, orient = "VelocityParallel" }),
	burst("Dust", "smoke", HUNT.smoke, { { 0, 1.2 }, { 1, 3 } }, { 0.5, 0.8 }, { 3, 6 }, 14, { transparency = { { 0, 0.5 }, { 1, 1 } }, light = 0, influence = 1, drag = 3 }),
	burst("Sparks", "spark", HUNT.gold, { { 0, 0.4 }, { 1, 0 } }, { 0.25, 0.4 }, { 10, 18 }, 18, { orient = "VelocityParallel", squash = 1.4, drag = 4 }),
})
trail("Hunt/DashTrail", "trail", { HUNT.pale, HUNT.gold }, { lifetime = 0.35, width = 2.4, transparency = { { 0, 0.1 }, { 1, 1 } } })
part("Hunt/DashHit", 1.5, {
	burst("Pierce", "slash", { HUNT.pale, HUNT.gold }, { { 0, 3 }, { 1, 4 } }, { 0.16, 0.2 }, { 0, 0 }, 1, { orient = "FacingCamera", transparency = { { 0, 0 }, { 1, 1 } }, z = 2 }),
	burst("Sparks", "spark", HUNT.gold, { { 0, 0.4 }, { 1, 0 } }, { 0.2, 0.35 }, { 10, 16 }, 14, { orient = "VelocityParallel", squash = 1.2, drag = 5 }),
})
part("Hunt/Horn", 5.5, {
	flat("Wave1", "thinring", HUNT.gold, { { 0, 1 }, { 1, 11 } }, { 0.5, 0.5 }, { transparency = { { 0, 0.1 }, { 1, 1 } } }),
	flat("Wave2", "thinring", HUNT.pale, { { 0, 1 }, { 1, 11 } }, { 0.5, 0.5 }, { delay = 0.15, transparency = { { 0, 0.3 }, { 1, 1 } } }),
	burst("Leaves", "feather", { HUNT.gold, HUNT.amber }, { { 0, 0.6 }, { 1, 0.3 } }, { 0.8, 1.2 }, { 5, 9 }, 20, { pattern = "ring", dir = "Front", spread = { 20, 20 }, spin = { -200, 200 }, rot = { 0, 360 }, accel = { 0, -3, 0 }, drag = 2, scaleSpeed = true }),
}, { light = { color = HUNT.gold, brightness = 2, range = 12, fade = 0.5 } })

-- Метка добычи: красный прицел над врагом.
folder("Hunt/PreyMark", {
	stream("Reticle", "thinring", HUNT.prey, { { 0, 2.4 }, { 0.5, 2.0 }, { 1, 2.4 } }, { 0.7, 0.7 }, { 0, 0 }, 1.6, { transparency = { { 0, 1 }, { 0.2, 0.15 }, { 0.8, 0.15 }, { 1, 1 } }, locked = true, z = 2, spin = { 60, 60 } }),
	stream("Glow", "glow", HUNT.prey, { { 0, 1.6 }, { 1, 1.2 } }, { 0.5, 0.5 }, { 0, 0 }, 3, { transparency = { { 0, 0.6 }, { 1, 1 } }, locked = true, z = 1 }),
	stream("Drips", "spark", HUNT.blood, { { 0, 0.2 }, { 1, 0 } }, { 0.5, 0.8 }, { 0.5, 1 }, 5, { accel = { 0, -6, 0 } }),
}, { light = { color = HUNT.prey, brightness = 0.8, range = 6 } })
part("Hunt/PreyKill", 2, {
	burst("Flash", "glow", { HUNT.prey, HUNT.gold }, { { 0, 2 }, { 1, 5 } }, { 0.3, 0.3 }, { 0, 0 }, 1, { transparency = { { 0, 0.2 }, { 1, 1 } } }),
	burst("Ring", "thinring", HUNT.gold, { { 0, 1 }, { 1, 6 } }, { 0.35, 0.35 }, { 0, 0 }, 1, { transparency = { { 0, 0.1 }, { 1, 1 } }, z = 1 }),
	burst("Sparks", "sparkle", { HUNT.gold, HUNT.prey }, { { 0, 0.6 }, { 1, 0 } }, { 0.5, 0.8 }, { 6, 12 }, 20, { drag = 3 }),
}, { light = { color = HUNT.gold, brightness = 3, range = 10, fade = 0.4 } })

-- Сокол: перья, золотое ядро, след.
folder("Hunt/Falcon", {
	stream("Core", "glow", HUNT.gold, { { 0, 1.8 }, { 1, 1 } }, { 0.12, 0.16 }, { 0, 0 }, 30, { transparency = { { 0, 0.2 }, { 1, 1 } }, locked = true, z = 1 }),
	stream("Wings", "feather", { HUNT.pale, HUNT.gold }, { { 0, 1.6 }, { 1, 0.6 } }, { 0.25, 0.4 }, { 1, 3 }, 26, { rot = { 0, 360 }, spin = { -180, 180 }, transparency = { { 0, 0.1 }, { 1, 1 } } }),
	stream("Feathers", "feather", HUNT.pale, { { 0, 0.5 }, { 1, 0.4 } }, { 0.6, 1 }, { 1, 3 }, 14, { rot = { 0, 360 }, spin = { -120, 120 }, accel = { 0, -2, 0 }, drag = 1 }),
}, { light = { color = HUNT.gold, brightness = 2, range = 9 }, trail = "Hunt/FalconTrail" })
trail("Hunt/FalconTrail", "trail", { HUNT.pale, HUNT.gold }, { lifetime = 0.25, width = 1.4, transparency = { { 0, 0.15 }, { 1, 1 } } })
part("Hunt/DiveMark", 4.5, {
	flat("Ring", "thinring", HUNT.gold, { { 0, 12 }, { 1, 8.5 } }, { 0.4, 0.4 }, { transparency = { { 0, 1 }, { 0.3, 0.2 }, { 1, 0.4 } }, matchLife = true }),
	flat("Cross", "sparkle", HUNT.pale, 5, { 0.4, 0.4 }, { transparency = { { 0, 1 }, { 0.5, 0.4 }, { 1, 0.6 } }, matchLife = true }),
})
part("Hunt/DiveImpact", 4.5, {
	burst("Feathers", "feather", { HUNT.pale, HUNT.gold }, { { 0, 0.9 }, { 1, 0.5 } }, { 0.8, 1.4 }, { 8, 16 }, 34, { rot = { 0, 360 }, spin = { -260, 260 }, accel = { 0, -4, 0 }, drag = 2.5 }),
	burst("Dust", "smoke", HUNT.smoke, { { 0, 2 }, { 1, 4.5 } }, { 0.6, 1 }, { 5, 9 }, 20, { pattern = "ring", dir = "Front", spread = { 15, 15 }, transparency = { { 0, 0.45 }, { 1, 1 } }, light = 0, influence = 1, drag = 3, scaleSpeed = true }),
	flat("Shock", "thinring", HUNT.gold, { { 0, 2 }, { 1, 11 } }, { 0.35, 0.35 }, { transparency = { { 0, 0 }, { 1, 1 } } }),
	burst("Flash", "glow", HUNT.pale, { { 0, 4 }, { 1, 8 } }, { 0.18, 0.18 }, { 0, 0 }, 1, { transparency = { { 0, 0.2 }, { 1, 1 } } }),
	burst("Talons", "claw", HUNT.gold, { { 0, 4 }, { 1, 5 } }, { 0.22, 0.22 }, { 0, 0 }, 2, { rot = { -30, 30 }, transparency = { { 0, 0 }, { 1, 1 } }, z = 2 }),
}, { light = { color = HUNT.gold, brightness = 5, range = 16, fade = 0.4 } })
part("Hunt/FalconStrike", 1, {
	burst("Talons", "claw", { HUNT.pale, HUNT.gold }, { { 0, 2.2 }, { 1, 2.8 } }, { 0.18, 0.2 }, { 0, 0 }, 1, { rot = { -40, 40 }, transparency = { { 0, 0 }, { 1, 1 } }, z = 2 }),
	burst("Feathers", "feather", HUNT.pale, { { 0, 0.5 }, { 1, 0.3 } }, { 0.5, 0.9 }, { 4, 8 }, 10, { rot = { 0, 360 }, spin = { -200, 200 }, accel = { 0, -3, 0 }, drag = 2 }),
})
trail("Hunt/Ribbon", "trail", HUNT.gold, { lifetime = 0.22, width = 1, transparency = { { 0, 0.1 }, { 1, 1 } } })

-- ===================== ЭТАЖ 4: КУЗНЯ =====================

part("Forge/SpillPour", 1.5, {
	burst("Drops", "glow", { FORGE.white, FORGE.orange }, { { 0, 0.6 }, { 1, 0.3 } }, { 0.5, 0.7 }, { 10, 16 }, 26, { dir = "Front", spread = { 18, 10 }, accel = { 0, -38, 0 } }),
	burst("Smoke", "smoke", FORGE.soot, { { 0, 1 }, { 1, 3 } }, { 0.7, 1 }, { 2, 4 }, 10, { dir = "Front", spread = { 30, 30 }, transparency = { { 0, 0.5 }, { 1, 1 } }, light = 0, influence = 1, accel = { 0, 3, 0 } }),
})
part("Forge/SpillErupt", 2.6, {
	burst("Fountain", "spark", { FORGE.white, FORGE.yellow, FORGE.orange }, { { 0, 0.5 }, { 1, 0.1 } }, { 0.5, 0.9 }, { 14, 26 }, 40, { dir = "Top", spread = { 22, 22 }, accel = { 0, -46, 0 }, orient = "VelocityParallel", squash = 1.5, scaleSpeed = true }),
	burst("Blobs", "glow", { FORGE.yellow, FORGE.red }, { { 0, 0.9 }, { 1, 0.4 } }, { 0.6, 0.9 }, { 8, 14 }, 14, { dir = "Top", spread = { 35, 35 }, accel = { 0, -40, 0 } }),
	burst("Column", "smoke", { FORGE.orange, FORGE.soot }, { { 0, 1.6 }, { 1, 4.5 } }, { 0.8, 1.2 }, { 4, 8 }, 16, { dir = "Top", spread = { 15, 15 }, transparency = { { 0, 0.3 }, { 1, 1 } }, light = 0.4, influence = 0.6, drag = 1 }),
	burst("Flash", "glow", FORGE.yellow, { { 0, 5 }, { 1, 8 } }, { 0.2, 0.2 }, { 0, 0 }, 1, { transparency = { { 0, 0.2 }, { 1, 1 } } }),
}, { light = { color = FORGE.orange, brightness = 5, range = 14, fade = 0.5 } })
part("Forge/SpillPool", 2.6, {
	flat("Pool", "glow", { FORGE.yellow, FORGE.orange }, 6, { 1, 1 }, { rate = 3, emit = false, transparency = { { 0, 0.6 }, { 0.5, 0.3 }, { 1, 1 } } }),
	flat("Crust", "crack", FORGE.red, 5.4, { 1.2, 1.2 }, { rate = 1.2, emit = false, transparency = { { 0, 1 }, { 0.3, 0.2 }, { 1, 1 } }, z = 0.3 }),
	stream("Bubbles", "sparkle", { FORGE.white, FORGE.yellow }, { { 0, 0.4 }, { 1, 0 } }, { 0.3, 0.5 }, { 1, 3 }, 14, { dir = "Top", spread = { 10, 10 }, shape = "Disc", style = "Volume", scaleSize = true }),
	stream("Embers", "ember", FORGE.orange, { { 0, 0.3 }, { 1, 0 } }, { 0.8, 1.4 }, { 2, 5 }, 12, { dir = "Top", spread = { 25, 25 }, shape = "Disc", style = "Volume", accel = { 0, 3, 0 } }),
	stream("Heat", "smoke", FORGE.soot, { { 0, 1.2 }, { 1, 3 } }, { 1, 1.6 }, { 1, 3 }, 4, { dir = "Top", spread = { 20, 20 }, shape = "Disc", transparency = { { 0, 0.7 }, { 1, 1 } }, light = 0, influence = 1 }),
}, { light = { color = FORGE.orange, brightness = 2.5, range = 9 }, scalePart = true, size = Vector3.new(5.2, 0.2, 5.2), shape = "Cylinder" })
part("Forge/SpillEnd", 2.6, {
	burst("Smoke", "smoke", FORGE.soot, { { 0, 1.5 }, { 1, 3.5 } }, { 0.8, 1.2 }, { 1, 3 }, 10, { dir = "Top", spread = { 30, 30 }, transparency = { { 0, 0.5 }, { 1, 1 } }, light = 0, influence = 1 }),
})

part("Forge/OverheatNova", 5, {
	burst("Fire", "smoke", { FORGE.white, FORGE.yellow, FORGE.orange, FORGE.red }, { { 0, 1.4 }, { 1, 3.4 } }, { 0.35, 0.5 }, { 16, 22 }, 48, { pattern = "ring", dir = "Front", spread = { 6, 6 }, transparency = { { 0, 0.1 }, { 1, 1 } }, drag = 5, scaleSpeed = true }),
	flat("Ring", "thinring", FORGE.yellow, { { 0, 1 }, { 1, 11 } }, { 0.35, 0.35 }, { transparency = { { 0, 0 }, { 1, 1 } } }),
	burst("Sparks", "spark", { FORGE.white, FORGE.orange }, { { 0, 0.4 }, { 1, 0 } }, { 0.4, 0.6 }, { 14, 24 }, 40, { orient = "VelocityParallel", squash = 1.4, drag = 3 }),
	burst("Flash", "glow", FORGE.yellow, { { 0, 5 }, { 1, 9 } }, { 0.2, 0.2 }, { 0, 0 }, 1, { transparency = { { 0, 0.15 }, { 1, 1 } } }),
}, { light = { color = FORGE.orange, brightness = 6, range = 16, fade = 0.45 } })
folder("Forge/OverheatAura", {
	stream("Flames", "smoke", { FORGE.white, FORGE.yellow, FORGE.orange, FORGE.red }, { { 0, 0.9 }, { 1, 0.2 } }, { 0.25, 0.4 }, { 2, 5 }, 60, { dir = "Top", spread = { 15, 15 }, shape = "Cylinder", transparency = { { 0, 0.2 }, { 1, 1 } }, accel = { 0, 6, 0 } }),
	stream("Embers", "ember", FORGE.yellow, { { 0, 0.3 }, { 1, 0 } }, { 0.5, 0.9 }, { 2, 5 }, 24, { accel = { 0, 5, 0 }, drag = 1 }),
}, { light = { color = FORGE.orange, brightness = 2.5, range = 9 } })
part("Forge/OverheatBurst", 3, {
	burst("Fire", "smoke", { FORGE.white, FORGE.orange, FORGE.red }, { { 0, 1.2 }, { 1, 2.8 } }, { 0.25, 0.4 }, { 6, 12 }, 18, { transparency = { { 0, 0.1 }, { 1, 1 } }, drag = 6, scaleSpeed = true }),
	burst("Sparks", "spark", FORGE.yellow, { { 0, 0.35 }, { 1, 0 } }, { 0.3, 0.5 }, { 12, 20 }, 18, { orient = "VelocityParallel", squash = 1.2, drag = 4 }),
}, { light = { color = FORGE.orange, brightness = 3, range = 9, fade = 0.25 } })
folder("Forge/Burning", {
	stream("Flames", "smoke", { FORGE.yellow, FORGE.orange, FORGE.red }, { { 0, 0.8 }, { 1, 0.2 } }, { 0.3, 0.5 }, { 2, 4 }, 24, { dir = "Top", spread = { 25, 25 }, transparency = { { 0, 0.3 }, { 1, 1 } }, accel = { 0, 4, 0 } }),
	stream("Embers", "ember", FORGE.orange, { { 0, 0.25 }, { 1, 0 } }, { 0.6, 0.9 }, { 2, 4 }, 8, { accel = { 0, 4, 0 } }),
})

part("Forge/AnvilMark", 5.5, {
	flat("Ring", "thinring", FORGE.orange, { { 0, 14 }, { 1, 11 } }, { 0.6, 0.6 }, { transparency = { { 0, 1 }, { 0.2, 0.15 }, { 1, 0.2 } }, matchLife = true }),
	flat("Glow", "glow", FORGE.red, 11, { 0.6, 0.6 }, { transparency = { { 0, 1 }, { 1, 0.5 } }, matchLife = true }),
	burst("Rise", "ember", FORGE.yellow, { { 0, 0.35 }, { 1, 0 } }, { 0.5, 0.7 }, { 4, 8 }, 30, { dir = "Top", spread = { 5, 5 }, shape = "Cylinder", style = "Surface", scaleSize = false }),
}, { light = { color = FORGE.orange, brightness = 2, range = 12 }, scalePart = true, size = Vector3.new(11, 0.2, 11), shape = "Cylinder" })
part("Forge/AnvilImpact", 5.5, {
	burst("Dust", "smoke", FORGE.soot, { { 0, 2.5 }, { 1, 6 } }, { 0.8, 1.2 }, { 10, 16 }, 30, { pattern = "ring", dir = "Front", spread = { 12, 12 }, transparency = { { 0, 0.35 }, { 1, 1 } }, light = 0, influence = 1, drag = 4, scaleSpeed = true }),
	burst("Sparks", "spark", { FORGE.white, FORGE.yellow, FORGE.orange }, { { 0, 0.5 }, { 1, 0 } }, { 0.5, 0.9 }, { 18, 32 }, 60, { pattern = "ring", dir = "Front", spread = { 25, 25 }, orient = "VelocityParallel", squash = 1.6, accel = { 0, -30, 0 }, scaleSpeed = true }),
	burst("Rocks", "rock", FORGE.slag, { { 0, 0.7 }, { 1, 0.4 } }, { 0.7, 1.1 }, { 10, 18 }, 18, { dir = "Top", spread = { 50, 50 }, accel = { 0, -50, 0 }, spin = { -300, 300 }, light = 0, influence = 1 }),
	flat("Crack", "crack", FORGE.orange, 12, { 1.2, 1.2 }, { transparency = { { 0, 0 }, { 0.7, 0.3 }, { 1, 1 } } }),
	burst("Flash", "glow", FORGE.white, { { 0, 6 }, { 1, 12 } }, { 0.2, 0.2 }, { 0, 0 }, 1, { transparency = { { 0, 0.1 }, { 1, 1 } } }),
}, { light = { color = FORGE.yellow, brightness = 8, range = 22, fade = 0.5 } })
trail("Forge/AnvilTrail", "trail", { FORGE.white, FORGE.orange }, { lifetime = 0.2, width = 4, transparency = { { 0, 0.2 }, { 1, 1 } } })

-- Дыхание горна: струя пламени (Attachment смотрит вперёд, выброс Front).
folder("Forge/BreathJet", {
	stream("Jet", "smoke", { FORGE.white, FORGE.yellow, FORGE.orange, FORGE.red, FORGE.soot }, { { 0, 0.6 }, { 0.4, 2.2 }, { 1, 3.6 } }, { 0.38, 0.48 }, { 18, 24 }, 120, { dir = "Front", spread = { 14, 14 }, transparency = { { 0, 0.15 }, { 0.7, 0.4 }, { 1, 1 } }, drag = 1.5, rot = { 0, 360 }, spin = { -120, 120 } }),
	stream("Core", "glow", FORGE.white, { { 0, 0.8 }, { 1, 1.6 } }, { 0.2, 0.25 }, { 20, 26 }, 60, { dir = "Front", spread = { 5, 5 }, transparency = { { 0, 0.3 }, { 1, 1 } } }),
	stream("Sparks", "spark", FORGE.yellow, { { 0, 0.3 }, { 1, 0 } }, { 0.4, 0.6 }, { 20, 30 }, 50, { dir = "Front", spread = { 20, 20 }, orient = "VelocityParallel", squash = 1.4, accel = { 0, 4, 0 } }),
}, { light = { color = FORGE.orange, brightness = 4, range = 14 } })
part("Forge/Ember", 1, {
	burst("Ember", "ember", { FORGE.yellow, FORGE.orange }, { { 0, 0.5 }, { 1, 0 } }, { 0.4, 0.6 }, { 2, 5 }, 8, { accel = { 0, 4, 0 } }),
	burst("Glow", "glow", FORGE.orange, { { 0, 1.2 }, { 1, 0.4 } }, { 0.25, 0.25 }, { 0, 0 }, 1, { transparency = { { 0, 0.4 }, { 1, 1 } } }),
})
part("Forge/EmberBurst", 3, {
	burst("Fire", "smoke", { FORGE.white, FORGE.yellow, FORGE.orange }, { { 0, 1.4 }, { 1, 3.4 } }, { 0.3, 0.45 }, { 8, 14 }, 24, { transparency = { { 0, 0.1 }, { 1, 1 } }, drag = 5, scaleSpeed = true }),
	burst("Embers", "ember", FORGE.yellow, { { 0, 0.4 }, { 1, 0 } }, { 0.6, 1 }, { 8, 16 }, 30, { accel = { 0, -10, 0 }, drag = 2 }),
	flat("Ring", "thinring", FORGE.orange, { { 0, 1 }, { 1, 7 } }, { 0.3, 0.3 }, { transparency = { { 0, 0 }, { 1, 1 } } }),
}, { light = { color = FORGE.orange, brightness = 4, range = 10, fade = 0.3 } })

part("Forge/SlagSpin", 7.2, {
	burst("Arc", "spark", { FORGE.white, FORGE.orange }, { { 0, 0.5 }, { 1, 0.1 } }, { 0.3, 0.45 }, { 18, 26 }, 40, { pattern = "ring", dir = "Front", spread = { 6, 6 }, orient = "VelocityParallel", squash = 2, scaleSpeed = true }),
	burst("Slag", "rock", FORGE.slag, { { 0, 0.5 }, { 1, 0.3 } }, { 0.5, 0.8 }, { 10, 16 }, 16, { pattern = "ring", dir = "Front", spread = { 20, 20 }, accel = { 0, -30, 0 }, spin = { -300, 300 }, light = 0, influence = 1 }),
	flat("Ring", "thinring", FORGE.orange, { { 0, 6 }, { 1, 15 } }, { 0.3, 0.3 }, { transparency = { { 0, 0.2 }, { 1, 1 } } }),
})
folder("Forge/SlagGlob", {
	stream("Core", "glow", { FORGE.yellow, FORGE.orange }, { { 0, 1 }, { 1, 0.7 } }, { 0.12, 0.15 }, { 0, 0 }, 30, { locked = true, transparency = { { 0, 0.2 }, { 1, 1 } } }),
	stream("Smoke", "smoke", FORGE.soot, { { 0, 0.6 }, { 1, 1.6 } }, { 0.4, 0.6 }, { 0, 1 }, 40, { transparency = { { 0, 0.4 }, { 1, 1 } }, light = 0, influence = 1 }),
	stream("Sparks", "spark", FORGE.orange, { { 0, 0.25 }, { 1, 0 } }, { 0.2, 0.3 }, { 2, 5 }, 30, {}),
}, { trail = "Forge/GlobTrail" })
trail("Forge/GlobTrail", "trail", { FORGE.yellow, FORGE.red }, { lifetime = 0.18, width = 0.8, transparency = { { 0, 0.2 }, { 1, 1 } } })
part("Forge/SlagPool", 2.2, {
	flat("Crust", "crack", { FORGE.orange, FORGE.red }, 4.6, { 1.2, 1.2 }, { rate = 1.2, emit = false, transparency = { { 0, 1 }, { 0.25, 0.1 }, { 1, 1 } } }),
	flat("Dark", "smoke", FORGE.slag, 5, { 1.2, 1.2 }, { rate = 1.2, emit = false, transparency = { { 0, 1 }, { 0.25, 0.2 }, { 1, 1 } }, light = 0, influence = 1, z = 0.1 }),
	stream("Smoke", "smoke", FORGE.soot, { { 0, 0.8 }, { 1, 2.2 } }, { 1, 1.4 }, { 1, 2 }, 5, { dir = "Top", spread = { 20, 20 }, shape = "Disc", transparency = { { 0, 0.6 }, { 1, 1 } }, light = 0, influence = 1 }),
	stream("Glints", "ember", FORGE.yellow, { { 0, 0.25 }, { 1, 0 } }, { 0.4, 0.7 }, { 1, 2 }, 6, { dir = "Top", shape = "Disc" }),
}, { light = { color = FORGE.red, brightness = 1.2, range = 6 }, scalePart = true, size = Vector3.new(4.4, 0.2, 4.4), shape = "Cylinder" })
part("Forge/TemperStack", 1, {
	burst("Spark", "sparkle", { FORGE.white, FORGE.yellow }, { { 0, 0.8 }, { 1, 0 } }, { 0.25, 0.3 }, { 0, 1 }, 2, {}),
	burst("Sparks", "spark", FORGE.yellow, { { 0, 0.2 }, { 1, 0 } }, { 0.2, 0.3 }, { 6, 10 }, 8, { orient = "VelocityParallel", squash = 1 }),
})
part("Forge/TemperRing", 4.5, {
	flat("Ring", "thinring", FORGE.white, { { 0, 1 }, { 1, 10 } }, { 0.3, 0.3 }, { transparency = { { 0, 0 }, { 1, 1 } } }),
	flat("Ring2", "thinring", FORGE.yellow, { { 0, 1 }, { 1, 10 } }, { 0.3, 0.3 }, { delay = 0.08, transparency = { { 0, 0.2 }, { 1, 1 } } }),
	burst("Sparks", "spark", { FORGE.white, FORGE.yellow }, { { 0, 0.45 }, { 1, 0 } }, { 0.35, 0.5 }, { 16, 24 }, 40, { pattern = "ring", dir = "Front", spread = { 8, 8 }, orient = "VelocityParallel", squash = 1.5, scaleSpeed = true }),
	burst("Flash", "glow", FORGE.white, { { 0, 4 }, { 1, 7 } }, { 0.15, 0.15 }, { 0, 0 }, 1, { transparency = { { 0, 0.2 }, { 1, 1 } } }),
}, { light = { color = FORGE.yellow, brightness = 5, range = 12, fade = 0.3 } })
part("Forge/Crust", 1.2, {
	burst("Flakes", "rock", FORGE.slag, { { 0, 0.35 }, { 1, 0.2 } }, { 0.4, 0.6 }, { 4, 8 }, 8, { accel = { 0, -25, 0 }, spin = { -300, 300 }, light = 0, influence = 1 }),
	burst("Glint", "ember", FORGE.orange, { { 0, 0.4 }, { 1, 0 } }, { 0.3, 0.4 }, { 2, 4 }, 5, {}),
})
part("Forge/StageUp", 1, {
	burst("Molten", "glow", { FORGE.white, FORGE.yellow, FORGE.orange }, { { 0, 1.6 }, { 1, 0.4 } }, { 0.3, 0.4 }, { 1, 3 }, 6, { transparency = { { 0, 0.2 }, { 1, 1 } } }),
	burst("Sparks", "spark", FORGE.yellow, { { 0, 0.35 }, { 1, 0 } }, { 0.3, 0.5 }, { 8, 14 }, 18, { orient = "VelocityParallel", squash = 1.2, accel = { 0, -20, 0 } }),
	burst("Steam", "steam", FORGE.steam, { { 0, 0.6 }, { 1, 1.8 } }, { 0.5, 0.8 }, { 2, 4 }, 6, { transparency = { { 0, 0.5 }, { 1, 1 } }, light = 0.2, influence = 0.8 }),
}, { light = { color = FORGE.orange, brightness = 3, range = 8, fade = 0.3 } })
part("Forge/PourWave", 4.5, {
	burst("Molten", "glow", { FORGE.white, FORGE.yellow, FORGE.orange }, { { 0, 1.4 }, { 1, 0.6 } }, { 0.3, 0.4 }, { 14, 20 }, 48, { pattern = "ring", dir = "Front", spread = { 4, 4 }, transparency = { { 0, 0.1 }, { 1, 1 } }, drag = 4, scaleSpeed = true }),
	flat("Ring", "thinring", FORGE.orange, { { 0, 2 }, { 1, 9 } }, { 0.35, 0.35 }, { transparency = { { 0, 0 }, { 1, 1 } }, scaleSize = true }),
	burst("Splash", "spark", FORGE.yellow, { { 0, 0.4 }, { 1, 0 } }, { 0.4, 0.6 }, { 10, 16 }, 30, { pattern = "ring", dir = "Front", spread = { 25, 25 }, accel = { 0, -30, 0 }, orient = "VelocityParallel", squash = 1.2 }),
}, { light = { color = FORGE.orange, brightness = 5, range = 14, fade = 0.35 } })
part("Forge/PourCore", 2, {
	flat("Glow", "glow", { FORGE.yellow, FORGE.orange }, 5, { 1.2, 1.2 }, { transparency = { { 0, 0.2 }, { 1, 1 } } }),
	flat("Crack", "crack", FORGE.yellow, 6, { 1.2, 1.2 }, { transparency = { { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } } }),
	burst("Rise", "ember", FORGE.yellow, { { 0, 0.4 }, { 1, 0 } }, { 0.6, 1 }, { 4, 8 }, 24, { dir = "Top", spread = { 30, 30 } }),
})
part("Forge/PourSteam", 6.5, {
	burst("Steam", "steam", { FORGE.white, FORGE.steam }, { { 0, 2.5 }, { 1, 7 } }, { 1, 1.6 }, { 10, 18 }, 40, { transparency = { { 0, 0.2 }, { 1, 1 } }, light = 0.3, influence = 0.7, drag = 3, rot = { 0, 360 }, spin = { -40, 40 }, scaleSpeed = true }),
	burst("Column", "steam", FORGE.steam, { { 0, 3 }, { 1, 8 } }, { 1.2, 1.8 }, { 14, 22 }, 16, { dir = "Top", spread = { 15, 15 }, transparency = { { 0, 0.3 }, { 1, 1 } }, light = 0.2, influence = 0.8, drag = 1.5 }),
	burst("Sparks", "spark", { FORGE.white, FORGE.yellow }, { { 0, 0.5 }, { 1, 0 } }, { 0.5, 0.9 }, { 20, 34 }, 50, { orient = "VelocityParallel", squash = 1.6, accel = { 0, -25, 0 } }),
	burst("Flash", "glow", FORGE.white, { { 0, 8 }, { 1, 14 } }, { 0.25, 0.25 }, { 0, 0 }, 1, { transparency = { { 0, 0.1 }, { 1, 1 } } }),
}, { light = { color = FORGE.white, brightness = 8, range = 22, fade = 0.6 } })
trail("Forge/Ribbon", "trail", FORGE.orange, { lifetime = 0.22, width = 1, transparency = { { 0, 0.1 }, { 1, 1 } } })

-- ===================== ЭТАЖ 5: ХРОНИКИ =====================

folder("Chron/Quill", {
	stream("Ink", "ink", { CHRON.violet, CHRON.ink }, { { 0, 0.8 }, { 1, 0.3 } }, { 0.4, 0.6 }, { 0.5, 2 }, 50, { accel = { 0, -6, 0 }, transparency = { { 0, 0.1 }, { 1, 1 } }, rot = { 0, 360 } }),
	stream("Glow", "glow", CHRON.lavender, { { 0, 1.2 }, { 1, 0.4 } }, { 0.15, 0.2 }, { 0, 0 }, 30, { locked = true, transparency = { { 0, 0.3 }, { 1, 1 } } }),
	stream("Letters", "rune", CHRON.lavender, { { 0, 0.6 }, { 1, 0.3 } }, { 0.6, 1 }, { 1, 2 }, 10, { accel = { 0, 3, 0 }, rot = { -20, 20 }, transparency = { { 0, 0.2 }, { 1, 1 } } }),
}, { light = { color = CHRON.violet, brightness = 2, range = 8 }, trail = "Chron/InkTrail" })
trail("Chron/InkTrail", "trail", { CHRON.lavender, CHRON.ink }, { lifetime = 0.6, width = 0.9, transparency = { { 0, 0.05 }, { 1, 1 } } })
part("Chron/Rune", 1.9, {
	flat("Rune", "rune", CHRON.violet, 3.6, { 0.9, 0.9 }, { transparency = { { 0, 1 }, { 0.15, 0.05 }, { 0.85, 0.05 }, { 1, 1 } }, matchLife = true, rot = { 0, 360 } }),
	flat("Glow", "glow", CHRON.lavender, 4.2, { 0.9, 0.9 }, { transparency = { { 0, 1 }, { 0.3, 0.6 }, { 1, 1 } }, matchLife = true }),
	stream("Motes", "sparkle", CHRON.lavender, { { 0, 0.35 }, { 1, 0 } }, { 0.4, 0.6 }, { 1, 2 }, 8, { dir = "Top", spread = { 20, 20 } }),
}, { light = { color = CHRON.violet, brightness = 1.2, range = 6 } })
part("Chron/RuneBurst", 2.5, {
	burst("Flash", "glow", { CHRON.white, CHRON.violet }, { { 0, 3 }, { 1, 6 } }, { 0.2, 0.2 }, { 0, 0 }, 1, { transparency = { { 0, 0.1 }, { 1, 1 } } }),
	burst("Pillar", "glow", CHRON.lavender, { { 0, 1.2 }, { 1, 0.2 } }, { 0.3, 0.45 }, { 12, 18 }, 12, { dir = "Top", spread = { 4, 4 }, orient = "VelocityParallel", squash = 3 }),
	burst("Pages", "page", { CHRON.white, CHRON.lavender }, { { 0, 0.7 }, { 1, 0.5 } }, { 0.6, 1 }, { 6, 10 }, 10, { rot = { 0, 360 }, spin = { -200, 200 }, accel = { 0, -4, 0 }, drag = 2, light = 0.6 }),
	flat("Ring", "thinring", CHRON.violet, { { 0, 1 }, { 1, 6 } }, { 0.3, 0.3 }, { transparency = { { 0, 0 }, { 1, 1 } } }),
}, { light = { color = CHRON.violet, brightness = 4, range = 10, fade = 0.3 } })

part("Chron/SealStamp", 7, {
	flat("Seal", "rune", CHRON.violet, { { 0, 16 }, { 0.15, 14 }, { 1, 14 } }, { 1.2, 1.2 }, { transparency = { { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } } }),
	flat("Ring", "thinring", CHRON.lavender, { { 0, 18 }, { 0.2, 14.5 }, { 1, 14.5 } }, { 1.2, 1.2 }, { transparency = { { 0, 0 }, { 0.7, 0.3 }, { 1, 1 } } }),
	flat("Clock", "clock", CHRON.ice, 9, { 1.2, 1.2 }, { transparency = { { 0, 0.3 }, { 1, 1 } }, spin = { -60, -60 } }),
	burst("Wax", "spark", { CHRON.violet, CHRON.ink2 }, { { 0, 0.5 }, { 1, 0.1 } }, { 0.4, 0.6 }, { 16, 24 }, 40, { pattern = "ring", dir = "Front", spread = { 15, 15 }, orient = "VelocityParallel", squash = 1.4, accel = { 0, -25, 0 }, scaleSpeed = true }),
	burst("Dust", "sand", CHRON.ice, { { 0, 0.3 }, { 1, 0 } }, { 1, 1.6 }, { 1, 3 }, 40, { shape = "Cylinder", style = "Volume", dir = "Top", spread = { 10, 10 }, drag = 1 }),
	burst("Flash", "glow", CHRON.white, { { 0, 6 }, { 1, 12 } }, { 0.2, 0.2 }, { 0, 0 }, 1, { transparency = { { 0, 0.1 }, { 1, 1 } } }),
}, { light = { color = CHRON.violet, brightness = 6, range = 18, fade = 0.6 }, scalePart = true, size = Vector3.new(14, 0.2, 14), shape = "Cylinder" })
folder("Chron/Frozen", {
	stream("Clock", "clock", CHRON.ice, { { 0, 3.4 }, { 1, 3.4 } }, { 0.9, 0.9 }, { 0, 0 }, 1.1, { transparency = { { 0, 1 }, { 0.2, 0.2 }, { 0.8, 0.2 }, { 1, 1 } }, locked = true, z = 2, spin = { -40, -40 } }),
	stream("Ice", "sparkle", { CHRON.white, CHRON.ice }, { { 0, 0.4 }, { 1, 0 } }, { 0.5, 0.8 }, { 0.2, 0.6 }, 10, {}),
	stream("Sand", "sand", CHRON.sand, { { 0, 0.18 }, { 1, 0.1 } }, { 0.8, 1.2 }, { 0, 0.2 }, 12, { accel = { 0, -1.5, 0 } }),
}, { light = { color = CHRON.ice, brightness = 0.8, range = 6 } })
part("Chron/SealBreak", 1.5, {
	burst("Shards", "sparkle", { CHRON.white, CHRON.ice }, { { 0, 0.7 }, { 1, 0 } }, { 0.4, 0.6 }, { 8, 14 }, 20, { drag = 3 }),
	burst("Glass", "spark", CHRON.ice, { { 0, 0.35 }, { 1, 0.1 } }, { 0.4, 0.6 }, { 10, 16 }, 16, { orient = "VelocityParallel", squash = 1.2, accel = { 0, -30, 0 } }),
	burst("Crack", "crack", CHRON.lavender, { { 0, 3 }, { 1, 3.6 } }, { 0.3, 0.3 }, { 0, 0 }, 1, { transparency = { { 0, 0 }, { 1, 1 } }, z = 2 }),
}, { light = { color = CHRON.ice, brightness = 3, range = 8, fade = 0.3 } })

part("Chron/Dome", 9, {
	flat("Ring", "thinring", CHRON.sand, 18.4, { 1, 1 }, { rate = 1.4, emit = false, transparency = { { 0, 1 }, { 0.25, 0.25 }, { 0.75, 0.25 }, { 1, 1 } } }),
	flat("Clock", "clock", CHRON.sand, 13, { 1.4, 1.4 }, { rate = 0.9, emit = false, transparency = { { 0, 1 }, { 0.3, 0.55 }, { 0.7, 0.55 }, { 1, 1 } }, spin = { 25, 25 } }),
	stream("SandFall", "sand", { CHRON.white, CHRON.sand }, { { 0, 0.22 }, { 1, 0.12 } }, { 1.2, 1.6 }, { 0.5, 1 }, 90, { shape = "Disc", style = "Volume", dir = "Bottom", spread = { 3, 3 }, accel = { 0, -4, 0 }, orient = "VelocityParallel", squash = 2, scaleSize = false }),
	stream("Motes", "sparkle", CHRON.sand, { { 0, 0.3 }, { 0.5, 0.45 }, { 1, 0 } }, { 1, 1.6 }, { 0.3, 0.8 }, 24, { shape = "Sphere", style = "Volume", accel = { 0, 0.5, 0 } }),
}, { light = { color = CHRON.sand, brightness = 1.5, range = 18 }, scalePart = true, size = Vector3.new(18, 0.2, 18), shape = "Cylinder" })
part("Chron/DomeCollapse", 9, {
	burst("Sand", "sand", { CHRON.white, CHRON.sand }, { { 0, 0.4 }, { 1, 0.2 } }, { 0.7, 1.1 }, { 14, 24 }, 120, { pattern = "inward", dir = "Front", spread = { 15, 15 }, accel = { 0, -20, 0 }, orient = "VelocityParallel", squash = 1.2, scaleSpeed = true }),
	burst("Dust", "smoke", CHRON.sand, { { 0, 3 }, { 1, 7 } }, { 0.8, 1.2 }, { 3, 6 }, 24, { pattern = "ring", dir = "Front", spread = { 20, 20 }, transparency = { { 0, 0.5 }, { 1, 1 } }, light = 0.2, influence = 0.8, drag = 2, scaleSpeed = true }),
	flat("Ring", "thinring", CHRON.sand, { { 0, 18 }, { 1, 2 } }, { 0.4, 0.4 }, { transparency = { { 0, 0 }, { 1, 1 } } }),
	burst("Flash", "glow", CHRON.sand, { { 0, 6 }, { 1, 12 } }, { 0.25, 0.25 }, { 0, 0 }, 1, { transparency = { { 0, 0.2 }, { 1, 1 } } }),
}, { light = { color = CHRON.sand, brightness = 6, range = 20, fade = 0.5 } })
part("Chron/TimeEcho", 1, {
	burst("Tick", "clock", CHRON.sand, { { 0, 1.6 }, { 1, 2.6 } }, { 0.25, 0.25 }, { 0, 0 }, 1, { transparency = { { 0, 0.1 }, { 1, 1 } }, z = 2 }),
	burst("Sand", "sand", CHRON.sand, { { 0, 0.25 }, { 1, 0 } }, { 0.3, 0.5 }, { 4, 8 }, 12, { drag = 3 }),
})

part("Chron/InkSplash", 8.5, {
	burst("Splash", "ink", { CHRON.ink2, CHRON.ink }, { { 0, 1.2 }, { 1, 2.8 } }, { 0.4, 0.6 }, { 16, 26 }, 46, { dir = "Front", spread = { 60, 18 }, transparency = { { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }, light = 0, influence = 0.5, accel = { 0, -16, 0 }, drag = 2, rot = { 0, 360 }, scaleSpeed = true }),
	burst("Violet", "ink", CHRON.violet, { { 0, 0.8 }, { 1, 1.6 } }, { 0.35, 0.5 }, { 18, 28 }, 24, { dir = "Front", spread = { 55, 14 }, transparency = { { 0, 0.1 }, { 1, 1 } }, accel = { 0, -14, 0 }, rot = { 0, 360 }, scaleSpeed = true }),
	burst("Drops", "glow", CHRON.lavender, { { 0, 0.35 }, { 1, 0.15 } }, { 0.5, 0.8 }, { 14, 22 }, 30, { dir = "Front", spread = { 60, 25 }, accel = { 0, -30, 0 }, scaleSpeed = true }),
}, { light = { color = CHRON.violet, brightness = 3, range = 12, fade = 0.4 } })
part("Chron/InkPuddle", 2, {
	flat("Ink", "ink", CHRON.ink, 4, { 2.5, 2.5 }, { transparency = { { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }, light = 0, influence = 1, rot = { 0, 360 } }),
	flat("Shine", "ink", CHRON.violet, 3.2, { 2.5, 2.5 }, { transparency = { { 0, 0.6 }, { 1, 1 } }, rot = { 0, 360 }, z = 0.3 }),
})
folder("Chron/InkStain", {
	stream("Drip", "ink", { CHRON.ink2, CHRON.ink }, { { 0, 0.5 }, { 1, 0.3 } }, { 0.6, 0.9 }, { 0.3, 0.8 }, 6, { accel = { 0, -8, 0 }, light = 0, influence = 0.7, rot = { 0, 360 } }),
	stream("Glint", "glow", CHRON.violet, { { 0, 0.3 }, { 1, 0 } }, { 0.4, 0.6 }, { 0.2, 0.6 }, 4, {}),
})
part("Chron/InkHit", 1.5, {
	burst("Splat", "ink", { CHRON.violet, CHRON.ink }, { { 0, 1.6 }, { 1, 2.6 } }, { 0.25, 0.3 }, { 0, 0 }, 2, { rot = { 0, 360 }, transparency = { { 0, 0 }, { 1, 1 } }, light = 0.3, influence = 0.6, z = 2 }),
	burst("Drops", "glow", CHRON.lavender, { { 0, 0.3 }, { 1, 0.1 } }, { 0.4, 0.6 }, { 6, 12 }, 12, { accel = { 0, -24, 0 } }),
})

part("Chron/EraseDust", 8.5, {
	burst("Pages", "page", { CHRON.white, CHRON.ice }, { { 0, 0.8 }, { 1, 0.4 } }, { 0.8, 1.3 }, { 8, 14 }, 36, { pattern = "ring", dir = "Front", spread = { 25, 25 }, rot = { 0, 360 }, spin = { -240, 240 }, transparency = { { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } }, drag = 2, accel = { 0, 2, 0 }, scaleSpeed = true, light = 0.5 }),
	burst("Dust", "sparkle", CHRON.ice, { { 0, 0.4 }, { 1, 0 } }, { 0.6, 1 }, { 6, 12 }, 40, { pattern = "ring", dir = "Front", spread = { 30, 30 }, drag = 2, scaleSpeed = true }),
}, { light = { color = CHRON.ice, brightness = 3, range = 14, fade = 0.4 } })
part("Chron/Erased", 2, {
	burst("Dissolve", "page", { CHRON.white, CHRON.lavender }, { { 0, 0.6 }, { 1, 0.3 } }, { 0.9, 1.4 }, { 3, 7 }, 30, { shape = "Box", style = "Volume", accel = { 0, 6, 0 }, rot = { 0, 360 }, spin = { -200, 200 }, transparency = { { 0, 0 }, { 1, 1 } }, drag = 1, light = 0.6 }),
	burst("Motes", "sparkle", CHRON.ice, { { 0, 0.5 }, { 1, 0 } }, { 0.8, 1.2 }, { 2, 5 }, 30, { shape = "Box", style = "Volume", accel = { 0, 5, 0 } }),
	burst("Flash", "glow", CHRON.white, { { 0, 5 }, { 1, 9 } }, { 0.3, 0.3 }, { 0, 0 }, 1, { transparency = { { 0, 0.1 }, { 1, 1 } } }),
}, { light = { color = CHRON.white, brightness = 5, range = 12, fade = 0.5 }, size = Vector3.new(3, 5, 3) })
part("Chron/OblivionMark", 1.2, {
	burst("Sigil", "rune", CHRON.violet, { { 0, 2.6 }, { 1, 1.8 } }, { 0.5, 0.5 }, { 0, 0 }, 1, { transparency = { { 0, 0 }, { 1, 1 } }, z = 2, spin = { 90, 90 } }),
	burst("Ash", "sparkle", CHRON.lavender, { { 0, 0.35 }, { 1, 0 } }, { 0.5, 0.8 }, { 2, 5 }, 12, { accel = { 0, 3, 0 } }),
})
trail("Chron/Ribbon", "trail", CHRON.lavender, { lifetime = 0.25, width = 1, transparency = { { 0, 0.1 }, { 1, 1 } } })
trail("Chron/EchoRibbon", "trail", CHRON.memory, { lifetime = 0.22, width = 1, transparency = { { 0, 0.2 }, { 1, 1 } } })

-- Эхо-двойник (на держателе двойника) и вспышки памяти.
folder("Chron/EchoGhost", {
	stream("Memory", "sparkle", { CHRON.white, CHRON.memory }, { { 0, 0.3 }, { 1, 0 } }, { 0.5, 0.9 }, { 0.3, 1 }, 26, { shape = "Box", style = "Volume", accel = { 0, 1.5, 0 } }),
	stream("Haze", "glow", CHRON.memory, { { 0, 2.4 }, { 1, 1.8 } }, { 0.4, 0.5 }, { 0, 0 }, 6, { transparency = { { 0, 0.75 }, { 1, 1 } }, locked = true }),
}, { light = { color = CHRON.memory, brightness = 1.2, range = 7 } })
part("Chron/RecallSummon", 2.6, {
	burst("Flash", "glow", { CHRON.white, CHRON.memory }, { { 0, 3 }, { 1, 6 } }, { 0.25, 0.25 }, { 0, 0 }, 1, { transparency = { { 0, 0.1 }, { 1, 1 } } }),
	burst("Shards", "sparkle", CHRON.memory, { { 0, 0.6 }, { 1, 0 } }, { 0.5, 0.8 }, { 6, 12 }, 30, { drag = 3 }),
	flat("Ring", "clock", CHRON.memory, { { 0, 2 }, { 1, 6 } }, { 0.4, 0.4 }, { transparency = { { 0, 0 }, { 1, 1 } }, spin = { -90, -90 } }),
}, { light = { color = CHRON.memory, brightness = 4, range = 10, fade = 0.4 } })
part("Chron/Afterimage", 1.5, {
	burst("Flash", "glow", CHRON.memory, { { 0, 2 }, { 1, 3.5 } }, { 0.2, 0.2 }, { 0, 0 }, 1, { transparency = { { 0, 0.3 }, { 1, 1 } } }),
	burst("Motes", "sparkle", { CHRON.white, CHRON.memory }, { { 0, 0.4 }, { 1, 0 } }, { 0.4, 0.6 }, { 3, 6 }, 14, { drag = 2 }),
})

-- ===================== АУРЫ ОРУЖИЯ (FX.Weapon.<id>) =====================
-- Клонируются VoxelWeaponBuilder: эмиттеры с формой (shape = "Box") — в невидимую деталь «AuraVolume»
-- по габариту клинка (частицы по всему клинку, а не из одной точки), без формы и свет — в Attachment
-- «BladeMid». Эмиттеры с flare (rate 0) раз в несколько секунд выпускает клиентский WeaponPresence.
-- version — номер правки: шаблоны старой версии в месте пересобираются при старте сервера.
-- v3 (22.11.2026): слои «кипения» из референса — крупные мягкие капли энергии + мелкие яркие точки,
-- дымка-аура, дуги-прожилки, белая мерцательная Sheen; ауры по редкости для оружия этажей 1–2.
local AURA_VERSION = 3
local function aura(id, emitters, light)
	T["Weapon/" .. id] = { kind = "folder", emitters = emitters, light = light, version = AURA_VERSION }
end
local function motes(tex, color, rate, size, extra)
	return stream("Motes", tex, color, { { 0, size }, { 1, 0 } }, { 0.6, 1.1 }, { 0.3, 1 }, rate, with({ shape = "Box", style = "Volume" }, extra or {}))
end

-- Общие слои «живого» оружия (стиль референса): оружие «кипит» энергией.
-- Имена Motes/Aura/Arc/Smoke тинтятся в VoxelWeaponBuilder цветом оружия; белые
-- Sheen/Flare читаются как чистый блеск поверх любого цвета.
local function layerDrops(color, k)
	-- Крупные мягкие капли энергии: медленно плывут внутри объёма клинка.
	return stream("Aura", "glow", color, { { 0, 0.55 * k }, { 1, 0.95 * k } }, { 0.5, 0.9 }, { 0.2, 0.8 }, math.floor(6 * k), {
		shape = "Box", style = "Volume", transparency = { { 0, 0.4 }, { 1, 1 } }, light = 0.7, rot = { 0, 360 }, spin = { -40, 40 }, drag = 0.5,
	})
end
local function layerMotes(color, k)
	-- Мелкие яркие точки, что живут недолго и дрожат.
	return stream("Motes", "spark", color, { { 0, 0.09 }, { 1, 0.15 } }, { 0.35, 0.8 }, { 0.5, 1.8 }, math.floor(12 * k), {
		shape = "Box", style = "Volume", drag = 1, light = 1,
	})
end
local function layerSheen(k)
	-- Мерцание НА поверхности клинка: свет изнутри, как у эмиссии в референсе.
	return stream("Sheen", "glow", "#FFFFFF", { { 0, 0.35 }, { 1, 0 } }, { 0.18, 0.3 }, { 0, 0 }, math.floor(11 * k), {
		shape = "Box", style = "Surface", transparency = { { 0, 0.3 }, { 1, 1 } }, locked = true, light = 1, z = 0.5,
	})
end
local function layerHaze(color, k)
	-- Холодная дымка-аура: полупрозрачные размытые пятна вокруг клинка.
	return stream("Haze", "smoke", color, { { 0, 1.1 * k }, { 1, 1.9 * k } }, { 1.1, 1.8 }, { 0.3, 0.9 }, math.floor(4 * k), {
		shape = "Box", style = "Volume", transparency = { { 0, 0.8 }, { 1, 1 } }, light = 0.55, influence = 0,
		accel = { 0, 1.2, 0 }, drag = 1, rot = { 0, 360 }, spin = { -25, 25 },
	})
end
local function layerArcs(color, rate)
	-- Дуги-прожилки: тонкие яркие штрихи, что время от времени простреливают от клинка.
	return stream("Arc", "spark", color, { { 0, 0.13 }, { 1, 0 } }, { 0.16, 0.3 }, { 3, 6 }, rate, {
		shape = "Box", style = "Volume", orient = "VelocityParallel", squash = 2.2, drag = 4, light = 1,
	})
end
local function layerFlare(color, count)
	return stream("Flare", "star", color, { { 0, 0.4 }, { 1, 0 } }, { 0.6, 1.1 }, { 5, 11 }, 0, {
		shape = "Box", style = "Volume", drag = 3, flare = count, rot = { 0, 360 },
	})
end

-- Ауры по редкости — для оружия без собственной (этажи 1–2, витрина): раньше у них
-- был только слабый фолбэк из пары искр. Цвета — тёплый нейтрал: без тинта аура всё
-- равно выглядит собранно, с тинтом полностью перекрашивается в цвет оружия.
local function rarityAura(id, k, flareCount)
	aura(id, {
		layerDrops("#EEDFB0", k),
		layerMotes("#EEDFB0", k),
		layerSheen(k),
		layerHaze("#EEDFB0", k),
		layerArcs("#EEDFB0", math.floor(k)),
		layerFlare("#FFFFFF", flareCount),
	}, { color = "#FFF1C9", brightness = 1.6 + 0.7 * k, range = 8 + 4 * k })
end
rarityAura("epic", 1, 12)
rarityAura("legendary", 1.4, 20)
rarityAura("secret", 1.75, 30)

-- Эпики этажей 3–5: частицы по клинку + дымка + дуги + мягкий свет.
aura("pack_fang", {
	motes("ember", { HUNT.pale, HUNT.amber }, 9, 0.2),
	stream("Haze", "smoke", HUNT.spirit, { { 0, 0.6 }, { 1, 1.2 } }, { 0.6, 0.9 }, { 0.2, 0.6 }, 4, { shape = "Box", transparency = { { 0, 0.8 }, { 1, 1 } } }),
	layerArcs({ HUNT.pale, HUNT.amber }, 1),
}, { color = HUNT.amber, brightness = 1.4, range = 8 })
aura("trap_maul", {
	motes("spark", { HUNT.amber, HUNT.iron }, 8, 0.18, { orient = "VelocityParallel", squash = 1 }),
	layerHaze(HUNT.amber, 0.8),
	layerArcs({ HUNT.pale, HUNT.amber }, 1),
}, { color = HUNT.amber, brightness = 1.3, range = 8 })
aura("crucible_maul", {
	motes("ember", { FORGE.yellow, FORGE.orange }, 11, 0.22, { accel = { 0, 3, 0 } }),
	stream("Heat", "smoke", FORGE.soot, { { 0, 0.5 }, { 1, 1.4 } }, { 0.8, 1.2 }, { 0.5, 1 }, 4, { shape = "Box", transparency = { { 0, 0.7 }, { 1, 1 } }, light = 0, influence = 1, accel = { 0, 2, 0 } }),
	layerHaze(FORGE.orange, 0.9),
	layerArcs({ FORGE.white, FORGE.yellow }, 1),
}, { color = FORGE.orange, brightness = 1.6, range = 9 })
aura("searing_blade", {
	motes("ember", { FORGE.white, FORGE.yellow, FORGE.orange }, 14, 0.2, { accel = { 0, 4, 0 } }),
	layerHaze(FORGE.orange, 1),
	layerArcs({ FORGE.white, FORGE.yellow }, 2),
}, { color = FORGE.orange, brightness = 1.6, range = 9 })
aura("quill_blade", {
	motes("rune", CHRON.lavender, 4, 0.32, { accel = { 0, 1.5, 0 } }),
	motes("ink", CHRON.violet, 6, 0.22, { accel = { 0, -3, 0 } }),
	layerHaze(CHRON.violet, 0.9),
}, { color = CHRON.violet, brightness = 1.4, range = 8 })
aura("seal_hammer", {
	motes("sparkle", { CHRON.lavender, CHRON.violet }, 9, 0.22),
	layerHaze(CHRON.violet, 0.9),
	layerArcs({ CHRON.white, CHRON.lavender }, 1),
}, { color = CHRON.violet, brightness = 1.4, range = 8 })

-- Легендарки и секретки: «присутствие» из слоёв —
--   Body  — густые частицы по всему клинку;           Sheen — мерцание по поверхности клинка;
--   Haze  — дымка-аура вокруг клинка;                 Arc   — дуги-прожилки от клинка;
--   Rise  — частицы, что отрываются и остаются в мире (шлейф за бегущим героем);
--   Halo  — мягкое свечение вокруг оружия;            Flare/FlareFlash — вспышка раз в 2–3 с (клиент);
--   свет  — ярче и дальше, чем у эпиков (WeaponPresence ещё и пульсирует им на вспышке).
-- o: glow (цвет свечения), body {tex, color, size, extra}, rise {tex, color, size, extra}, flare {tex, color},
--    arc {color, rate} (не задано — от glow), extra {эмиттеры}, secret.
local function legend(id, o)
	local k = o.secret and 1.5 or 1
	local arc = o.arc or { color = o.glow, rate = math.floor(1.5 * k) }
	local list = {
		stream("Body", o.body[1], o.body[2], { { 0, o.body[3] }, { 0.6, o.body[3] * 0.8 }, { 1, 0 } }, { 0.7, 1.3 }, { 0.2, 0.8 }, math.floor(18 * k), with({ shape = "Box", style = "Volume" }, o.body[4] or {})),
		stream("Sheen", "glow", o.glow, { { 0, 0.55 }, { 1, 0 } }, { 0.3, 0.5 }, { 0, 0 }, math.floor(14 * k), { shape = "Box", style = "Surface", transparency = { { 0, 0.35 }, { 1, 1 } }, locked = true, light = 1, z = 0.5 }),
		layerHaze(o.glow, k),
		layerArcs(arc.color, arc.rate),
		stream("Rise", o.rise[1], o.rise[2], { { 0, o.rise[3] }, { 0.7, o.rise[3] * 0.7 }, { 1, 0 } }, { 1.4, 2.2 }, { 0.4, 1.2 }, math.floor(8 * k), with({ shape = "Box", style = "Volume", accel = { 0, 2.5, 0 }, drag = 0.6 }, o.rise[4] or {})),
		stream("Halo", "glow", o.glow, { { 0, o.secret and 5 or 4 }, { 0.5, o.secret and 5.8 or 4.6 }, { 1, o.secret and 5 or 4 } }, { 1, 1.4 }, { 0, 0 }, 3, { transparency = { { 0, 1 }, { 0.3, o.secret and 0.74 or 0.8 }, { 0.7, o.secret and 0.74 or 0.8 }, { 1, 1 } }, locked = true, z = -1 }),
		stream("Flare", o.flare[1], o.flare[2], { { 0, 0.5 }, { 1, 0 } }, { 0.6, 1.1 }, { 5, 11 }, 0, { shape = "Box", style = "Volume", drag = 3, flare = o.secret and 36 or 24, rot = { 0, 360 } }),
		stream("FlareFlash", "glow", o.glow, { { 0, 2.5 }, { 1, o.secret and 7 or 5.5 } }, { 0.35, 0.35 }, { 0, 0 }, 0, { transparency = { { 0, 0.25 }, { 1, 1 } }, locked = true, flare = 1 }),
	}
	for _, e in ipairs(o.extra or {}) do
		table.insert(list, e)
	end
	aura(id, list, { color = o.glow, brightness = o.secret and 3.4 or 2.6, range = o.secret and 16 or 13 })
end

-- этаж 3
legend("royal_scythe", {
	glow = HUNT.gold,
	body = { "sparkle", { HUNT.pale, HUNT.gold }, 0.28 },
	rise = { "ember", { HUNT.gold, HUNT.amber }, 0.22 },
	flare = { "star", { HUNT.pale, HUNT.gold } },
	extra = { stream("Prey", "ember", HUNT.prey, { { 0, 0.2 }, { 1, 0 } }, { 0.6, 1 }, { 0.3, 0.8 }, 5, { shape = "Box", style = "Volume" }) },
})
legend("falconer_saber", {
	glow = HUNT.gold,
	body = { "sparkle", { HUNT.pale, HUNT.gold }, 0.24 },
	rise = { "feather", { HUNT.pale, HUNT.gold }, 0.45, { rot = { 0, 360 }, spin = { -90, 90 }, accel = { 0, -0.6, 0 }, drag = 1.2 } },
	flare = { "feather", { HUNT.pale, HUNT.gold } },
})
-- этаж 4
legend("anvil_hammer", {
	glow = FORGE.yellow,
	body = { "spark", { FORGE.white, FORGE.yellow }, 0.24, { orient = "VelocityParallel", squash = 1, accel = { 0, -6, 0 } } },
	rise = { "ember", { FORGE.yellow, FORGE.orange }, 0.22, { accel = { 0, 4, 0 } } },
	flare = { "spark", { FORGE.white, FORGE.yellow } },
	extra = { stream("Smoke", "smoke", FORGE.soot, { { 0, 0.5 }, { 1, 1.4 } }, { 0.9, 1.3 }, { 0.4, 1 }, 4, { shape = "Box", transparency = { { 0, 0.7 }, { 1, 1 } }, light = 0, influence = 1, accel = { 0, 2, 0 } }) },
})
legend("forge_heart_blade", {
	glow = FORGE.orange,
	body = { "ember", { FORGE.white, FORGE.yellow, FORGE.orange }, 0.26, { accel = { 0, 4, 0 } } },
	rise = { "smoke", { FORGE.yellow, FORGE.red }, 0.6, { life = { 0.5, 0.9 }, accel = { 0, 5, 0 }, transparency = { { 0, 0.3 }, { 1, 1 } } } },
	flare = { "ember", { FORGE.white, FORGE.yellow } },
})
legend("slag_scythe", {
	glow = FORGE.red,
	body = { "ember", { FORGE.orange, FORGE.red }, 0.24, { accel = { 0, -4, 0 } } },
	rise = { "smoke", FORGE.soot, 0.7, { light = 0, influence = 1, transparency = { { 0, 0.6 }, { 1, 1 } } } },
	flare = { "spark", { FORGE.yellow, FORGE.red } },
})
-- этаж 5
legend("hourglass_maul", {
	glow = CHRON.sand,
	body = { "sand", { CHRON.white, CHRON.sand }, 0.18, { accel = { 0, -4, 0 } } },
	rise = { "sparkle", CHRON.sand, 0.24 },
	flare = { "sand", { CHRON.white, CHRON.sand } },
	extra = { stream("Clock", "clock", CHRON.sand, { { 0, 1.2 }, { 1, 1.6 } }, { 1.6, 1.6 }, { 0, 0 }, 1, { transparency = { { 0, 1 }, { 0.3, 0.7 }, { 0.7, 0.7 }, { 1, 1 } }, locked = true, spin = { 40, 40 } }) },
})
legend("ink_blade", {
	glow = CHRON.violet,
	body = { "ink", { CHRON.violet, CHRON.ink2 }, 0.3, { accel = { 0, -5, 0 }, rot = { 0, 360 } } },
	rise = { "glow", CHRON.lavender, 0.2 },
	flare = { "ink", { CHRON.violet, CHRON.lavender } },
})
legend("oblivion_scythe", {
	glow = CHRON.ice,
	body = { "sparkle", { CHRON.white, CHRON.ice }, 0.22 },
	rise = { "page", { CHRON.white, CHRON.ice }, 0.45, { rot = { 0, 360 }, spin = { -120, 120 }, accel = { 0, 1, 0 } } },
	flare = { "page", { CHRON.white, CHRON.ice } },
})
-- секретки: всё гуще и ярче, плюс свой слой
legend("unfinished_blade", {
	secret = true,
	glow = FORGE.orange,
	body = { "ember", { FORGE.white, FORGE.yellow, FORGE.orange }, 0.26, { accel = { 0, 3, 0 } } },
	rise = { "ember", { FORGE.yellow, CHRON.memory }, 0.24, { accel = { 0, 4, 0 } } },
	flare = { "ember", { FORGE.white, CHRON.memory } },
	extra = { stream("Memory", "sparkle", CHRON.memory, { { 0, 0.3 }, { 1, 0 } }, { 0.8, 1.2 }, { 0.2, 0.6 }, 8, { shape = "Box", style = "Surface" }) },
})
legend("memory_blade", {
	secret = true,
	glow = CHRON.memory,
	body = { "sparkle", { CHRON.white, CHRON.memory }, 0.28, { accel = { 0, 1.5, 0 } } },
	rise = { "sparkle", { CHRON.memory, CHRON.white }, 0.26, { accel = { 0, 3, 0 } } },
	flare = { "sparkle", { CHRON.white, CHRON.memory } },
	extra = { stream("Clock", "clock", CHRON.memory, { { 0, 1.4 }, { 1, 2 } }, { 1.8, 1.8 }, { 0, 0 }, 1, { transparency = { { 0, 1 }, { 0.3, 0.65 }, { 0.7, 0.65 }, { 1, 1 } }, locked = true, spin = { -50, -50 } }) },
})

-- ===== Присутствие у ног (клиентский WeaponPresence; белые — перекрашиваются в цвет оружия) =====
-- Кольцо-волна на вспышке легендарки/секретки.
part("Presence/Ring", 1, {
	flat("Ring", "thinring", "#FFFFFF", { { 0, 2 }, { 1, 9 } }, { 0.7, 0.7 }, { transparency = { { 0, 0.15 }, { 1, 1 } } }),
	burst("Rise", "sparkle", "#FFFFFF", { { 0, 0.4 }, { 1, 0 } }, { 0.8, 1.3 }, { 4, 9 }, 18, { shape = "Box", dir = "Top", spread = { 20, 20 }, drag = 1.5 }),
}, { size = Vector3.new(5, 0.2, 5) })
-- Секретка: медленно вращающийся круг рун и искры снизу вверх, пока оружие в руке.
part("Presence/Sigil", 3, {
	stream("Sigil", "rune", "#FFFFFF", 7, { 2.4, 2.4 }, { 0.01, 0.01 }, 0.9, with(FLAT, { transparency = { { 0, 1 }, { 0.25, 0.55 }, { 0.75, 0.55 }, { 1, 1 } }, spin = { 25, 25 }, z = 0.2 })),
	stream("Ring", "thinring", "#FFFFFF", 6.4, { 2, 2 }, { 0.01, 0.01 }, 0.8, with(FLAT, { transparency = { { 0, 1 }, { 0.3, 0.7 }, { 0.7, 0.7 }, { 1, 1 } }, spin = { -15, -15 }, z = 0.1 })),
	stream("Motes", "sparkle", "#FFFFFF", { { 0, 0.3 }, { 1, 0 } }, { 1, 1.6 }, { 1.5, 3.5 }, 14, { shape = "Box", dir = "Top", spread = { 10, 10 } }),
}, { size = Vector3.new(6, 0.2, 6) })
-- Находка легендарки/секретки: столб света над сундуком (life задаёт клиент, 5–7 с).
part("Presence/Pillar", 1.5, {
	stream("Column", "glow", "#FFFFFF", { { 0, 2.2 }, { 0.8, 1.4 }, { 1, 0 } }, { 0.9, 1.1 }, { 28, 36 }, 45, { shape = "Box", dir = "Top", spread = { 0, 0 }, transparency = { { 0, 0.3 }, { 1, 0.8 } } }),
	stream("Sparks", "sparkle", "#FFFFFF", { { 0, 0.5 }, { 1, 0 } }, { 1, 1.6 }, { 6, 14 }, 30, { shape = "Box", dir = "Top", spread = { 25, 25 }, drag = 0.8 }),
	flat("Ring", "thinring", "#FFFFFF", { { 0, 2 }, { 1, 16 } }, { 1, 1 }, { transparency = { { 0, 0.1 }, { 1, 1 } } }),
	burst("Flash", "glow", "#FFFFFF", { { 0, 6 }, { 1, 14 } }, { 0.45, 0.45 }, { 0, 0 }, 1, { transparency = { { 0, 0.1 }, { 1, 1 } } }),
}, { size = Vector3.new(3, 0.2, 3), light = { color = "#FFFFFF", brightness = 5, range = 26 } })

-- ===================== СПОСОБНОСТИ V2 (переделка 07.11.2026) =====================
-- Шаблоны новых и переделанных способностей мечей и молотов: Shared/Fx/FxWeaponsV2.
require(script.Parent.FxWeaponsV2).install(S, {
	part = part,
	folder = folder,
	trail = trail,
	flat = flat,
	burst = burst,
	stream = stream,
	with = with,
	FLAT = FLAT,
	HUNT = HUNT,
	FORGE = FORGE,
	CHRON = CHRON,
})

return S
