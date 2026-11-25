--!nonstrict
-- FxWeaponsV2 (общий) — шаблоны эффектов переделанных способностей мечей и молотов (07.11.2026).
-- Подмешиваются в таблицу FxWeapons345 (install) и собираются тем же FxBuilder345 в
-- ReplicatedStorage.FX.V2/*. Клиент — Controllers/AbilityFxV2.
--
-- Текстуры fb_* — флипбуки из pixelfx (tools/flipbooks): пока их id не вписаны в
-- FxWeapons345.NEW, эмиттер берёт запасную статичную текстуру и тинт из таблицы; когда id
-- вписан — включается сетка кадров (flip = 4 | 8) и тинт становится белым (цвета листа).
-- texSig = true: шаблон сам пересобирается, когда в NEW появился id.

local FxWeaponsV2 = {}

function FxWeaponsV2.install(S, h)
	local part, folder, flat, burst, stream, with = h.part, h.folder, h.flat, h.burst, h.stream, h.with
	local HUNT, FORGE, CHRON = h.HUNT, h.FORGE, h.CHRON
	local T = S.Templates
	local function sig(path)
		T[path].texSig = true
	end

	local GREY = { ash = "#9A98AA", paper = "#E8E6F0", void = "#2A2833", white = "#FFFFFF" }
	local SEA = { foam = "#EFFCFF", water = "#4FD6FF", deep = "#1E7FC2" }
	local LEAF = { green = "#8EE04A", dark = "#3E8A2A", pale = "#EAFFD6", petal = "#FF8FD0" }
	local MEM = { cyan = "#6FE3FF", white = "#EFFCFF", deep = "#1F8FA8" }

	-- ===== Общие вспышки =====
	-- v2 (22.11.2026): сочнее — вспышка-ядро и штрихи-прожилки к основному кадру,
	-- чтобы каждое попадание читалось как в референсе (вспышка + разлёт).
	part("V2/Hit", 1, {
		burst("Spark", "fb_hit", HUNT.pale, { { 0, 3 }, { 1, 3.4 } }, { 0.32, 0.32 }, { 0, 0 }, 1, { flip = 4, rot = { -30, 30 }, z = 2 }),
		burst("Flash", "glow", "#FFFFFF", { { 0, 2 }, { 1, 3.4 } }, { 0.12, 0.14 }, { 0, 0 }, 1, { transparency = { { 0, 0.2 }, { 1, 1 } } }),
		burst("Streaks", "spark", HUNT.pale, { { 0, 0.32 }, { 1, 0 } }, { 0.2, 0.32 }, { 10, 16 }, 3, { orient = "VelocityParallel", squash = 1.7, drag = 5 }),
	}, { version = 2 })
	sig("V2/Hit")
	part("V2/Crit", 1.5, {
		burst("Star", "fb_crit", HUNT.gold, { { 0, 4.5 }, { 1, 5.2 } }, { 0.55, 0.55 }, { 0, 0 }, 1, { flip = 4, z = 2 }),
		burst("Flash", "glow", "#FFFFFF", { { 0, 3.5 }, { 1, 5 } }, { 0.2, 0.2 }, { 0, 0 }, 1, { transparency = { { 0, 0.15 }, { 1, 1 } }, z = 1 }),
		burst("Sparks", "spark", { HUNT.pale, HUNT.gold }, { { 0, 0.4 }, { 1, 0 } }, { 0.3, 0.5 }, { 12, 20 }, 22, { orient = "VelocityParallel", squash = 1.2, drag = 5 }),
		burst("Streaks", "spark", HUNT.gold, { { 0, 0.4 }, { 1, 0 } }, { 0.26, 0.42 }, { 16, 26 }, 8, { orient = "VelocityParallel", squash = 1.9, drag = 4 }),
	}, { light = { color = HUNT.gold, brightness = 5, range = 16, fade = 0.35 }, version = 2 })
	sig("V2/Crit")

	-- ===== Коса Забвения: «Забвение» =====
	part("V2/EraseField", 10, {
		flat("Ring", "thinring", GREY.paper, 20, { 1.2, 1.2 }, { rate = 2, emit = false, transparency = { { 0, 1 }, { 0.2, 0.35 }, { 0.8, 0.35 }, { 1, 1 } }, spin = { 30, 30 } }),
		flat("Runes", "rune", GREY.ash, 17, { 2, 2 }, { rate = 0.8, emit = false, transparency = { { 0, 1 }, { 0.3, 0.55 }, { 0.7, 0.55 }, { 1, 1 } }, spin = { -20, -20 } }),
		stream("Ash", "fb_erase", GREY.paper, { { 0, 1.6 }, { 1, 2.4 } }, { 0.9, 1.3 }, { 0.5, 1.5 }, 14, { flip = 4, shape = "Cylinder", style = "Volume", dir = "Top", spread = { 10, 10 }, accel = { 0, 2, 0 } }),
		stream("Dust", "smoke", GREY.void, { { 0, 2 }, { 1, 4 } }, { 1.2, 1.8 }, { 0.3, 1 }, 10, { shape = "Cylinder", style = "Volume", transparency = { { 0, 0.6 }, { 1, 1 } }, light = 0, influence = 1 }),
	}, { size = Vector3.new(20, 0.2, 20), scalePart = true, light = { color = GREY.paper, brightness = 1.5, range = 18 } })
	sig("V2/EraseField")
	part("V2/EraseFade", 1.5, {
		burst("Erase", "fb_erase", GREY.white, { { 0, 5 }, { 1, 5.5 } }, { 0.9, 0.9 }, { 0, 0 }, 1, { flip = 4, z = 2 }),
		burst("Scraps", "page", GREY.paper, { { 0, 0.6 }, { 1, 0.2 } }, { 0.8, 1.4 }, { 3, 7 }, 18, { accel = { 0, 3, 0 }, spin = { -180, 180 }, drag = 1.5, light = 0.2 }),
	})
	sig("V2/EraseFade")
	part("V2/EraseSweep", 10, {
		burst("Scythe", "fb_scythe", GREY.paper, { { 0, 22 }, { 1, 24 } }, { 0.55, 0.55 }, { 0, 0 }, 1, { flip = 4, z = 3 }),
		flat("Ring", "thinring", GREY.white, { { 0, 4 }, { 1, 22 } }, { 0.5, 0.5 }, { transparency = { { 0, 0 }, { 1, 1 } } }),
		burst("Pages", "page", GREY.paper, { { 0, 0.9 }, { 1, 0.3 } }, { 1, 1.8 }, { 8, 16 }, 40, { pattern = "ring", dir = "Front", spread = { 15, 15 }, spin = { -200, 200 }, drag = 2, accel = { 0, 2, 0 }, light = 0.3 }),
	}, { size = Vector3.new(20, 0.2, 20), scalePart = true, light = { color = GREY.white, brightness = 6, range = 24, fade = 0.4 } })
	sig("V2/EraseSweep")

	-- ===== Клинок горна: «Горнило» =====
	part("V2/HeartPlunge", 2, {
		burst("Flash", "glow", FORGE.white, { { 0, 4 }, { 1, 8 } }, { 0.25, 0.25 }, { 0, 0 }, 1, { transparency = { { 0, 0.1 }, { 1, 1 } } }),
		flat("Ring", "thinring", FORGE.orange, { { 0, 2 }, { 1, 14 } }, { 0.5, 0.5 }, { transparency = { { 0, 0 }, { 1, 1 } } }),
		burst("Embers", "ember", { FORGE.yellow, FORGE.orange }, { { 0, 0.5 }, { 1, 0 } }, { 0.6, 1 }, { 10, 18 }, 40, { dir = "Top", spread = { 60, 60 }, accel = { 0, -18, 0 }, drag = 1 }),
	}, { light = { color = FORGE.orange, brightness = 6, range = 18, fade = 0.6 } })
	part("V2/Fissure", 1, {
		stream("Glow", "crack", { FORGE.yellow, FORGE.orange }, 3, { 0.5, 0.7 }, { 0.01, 0.01 }, 30, with(h.FLAT, { shape = "Box", style = "Surface", transparency = { { 0, 0.2 }, { 1, 1 } }, z = 0.3 })),
		stream("Heat", "smoke", FORGE.red, { { 0, 0.8 }, { 1, 1.6 } }, { 0.4, 0.7 }, { 1, 3 }, 16, { shape = "Box", dir = "Top", spread = { 5, 5 }, transparency = { { 0, 0.6 }, { 1, 1 } } }),
	}, { size = Vector3.new(1.4, 0.2, 12) })
	part("V2/Pillar", 2.5, {
		burst("Pillar", "fb_pillar", { FORGE.yellow, FORGE.orange }, { { 0, 9 }, { 1, 10 } }, { 1.4, 1.4 }, { 0, 0 }, 1, { flip = 8, z = 1 }),
		burst("Column", "glow", { FORGE.white, FORGE.orange }, { { 0, 2.2 }, { 1, 0 } }, { 0.5, 0.7 }, { 16, 24 }, 26, { shape = "Disc", dir = "Top", spread = { 4, 4 } }),
		burst("Rocks", "rock", FORGE.slag, { { 0, 0.5 }, { 1, 0.3 } }, { 0.7, 1 }, { 8, 14 }, 10, { dir = "Top", spread = { 40, 40 }, accel = { 0, -30, 0 }, spin = { -200, 200 }, light = 0, influence = 1 }),
		burst("Smoke", "smoke", FORGE.soot, { { 0, 2 }, { 1, 4 } }, { 1, 1.5 }, { 2, 5 }, 8, { dir = "Top", spread = { 20, 20 }, transparency = { { 0, 0.4 }, { 1, 1 } }, light = 0, influence = 1 }),
	}, { light = { color = FORGE.orange, brightness = 5, range = 14, fade = 1 } })
	sig("V2/Pillar")
	folder("V2/BurningBlade", {
		stream("Fire", "glow", { FORGE.yellow, FORGE.red }, { { 0, 1 }, { 1, 0 } }, { 0.25, 0.4 }, { 1, 3 }, 60, { shape = "Box", accel = { 0, 6, 0 }, transparency = { { 0, 0.2 }, { 1, 1 } } }),
		stream("Embers", "ember", FORGE.yellow, { { 0, 0.25 }, { 1, 0 } }, { 0.4, 0.8 }, { 1, 3 }, 24, { accel = { 0, 5, 0 }, drag = 1 }),
	}, { light = { color = FORGE.orange, brightness = 2.5, range = 9 } })
	part("V2/FireArc", 5, {
		burst("Arc", "fb_scythe", FORGE.orange, { { 0, 12 }, { 1, 13 } }, { 0.45, 0.45 }, { 0, 0 }, 1, { flip = 4, z = 2, keepColor = true }),
		burst("Sparks", "spark", { FORGE.yellow, FORGE.orange }, { { 0, 0.35 }, { 1, 0 } }, { 0.3, 0.5 }, { 14, 22 }, 26, { orient = "VelocityParallel", squash = 1.2, drag = 4 }),
	}, { light = { color = FORGE.orange, brightness = 4, range = 14, fade = 0.4 } })
	sig("V2/FireArc")

	-- ===== Незавершённая отливка: «Первая отливка» =====
	folder("V2/PourStream", {
		stream("Metal", "glow", { FORGE.white, FORGE.orange }, { { 0, 1.2 }, { 1, 0.8 } }, { 0.35, 0.45 }, { 14, 18 }, 70, { dir = "Bottom", spread = { 2, 2 } }),
		stream("Drips", "ember", FORGE.yellow, { { 0, 0.3 }, { 1, 0 } }, { 0.5, 0.8 }, { 4, 8 }, 20, { dir = "Bottom", spread = { 25, 25 }, accel = { 0, -20, 0 } }),
	}, { light = { color = FORGE.orange, brightness = 3, range = 10 } })
	part("V2/PourRing", 5.5, {
		flat("Ring", "thinring", FORGE.orange, { { 0, 6 }, { 1, 12 } }, { 0.45, 0.45 }, { transparency = { { 0, 0 }, { 1, 1 } }, scaleSize = true }),
		burst("Wave", "smoke", { FORGE.yellow, FORGE.red }, { { 0, 1.2 }, { 1, 2.2 } }, { 0.35, 0.5 }, { 8, 12 }, 36, { pattern = "ring", dir = "Front", spread = { 6, 6 }, scaleSpeed = true, transparency = { { 0, 0.2 }, { 1, 1 } } }),
		burst("Embers", "ember", FORGE.yellow, { { 0, 0.4 }, { 1, 0 } }, { 0.5, 0.8 }, { 6, 12 }, 30, { pattern = "ring", dir = "Front", spread = { 20, 20 }, accel = { 0, -10, 0 }, scaleSpeed = true }),
	}, { size = Vector3.new(11, 0.2, 11), light = { color = FORGE.orange, brightness = 4, range = 16, fade = 0.4 } })
	part("V2/GhostCleave", 4, {
		burst("Cleave", "fb_cleave", FORGE.yellow, { { 0, 18 }, { 1, 19 } }, { 0.8, 0.8 }, { 0, 0 }, 1, { flip = 4, z = 3 }),
		burst("Slam", "fb_slam", FORGE.orange, { { 0, 12 }, { 1, 13 } }, { 1, 1 }, { 0, 0 }, 1, { flip = 4, z = 2, delay = 0.18 }),
		burst("Rocks", "rock", FORGE.slag, { { 0, 0.6 }, { 1, 0.3 } }, { 0.8, 1.2 }, { 10, 18 }, 18, { dir = "Top", spread = { 50, 50 }, accel = { 0, -30, 0 }, spin = { -200, 200 }, light = 0, influence = 1, delay = 0.18 }),
	}, { light = { color = FORGE.yellow, brightness = 8, range = 22, fade = 0.6 } })
	sig("V2/GhostCleave")
	part("V2/Steam", 9, {
		burst("Steam", "smoke", FORGE.steam, { { 0, 3 }, { 1, 9 } }, { 1.2, 1.8 }, { 6, 12 }, 40, { pattern = "ring", dir = "Front", spread = { 30, 30 }, transparency = { { 0, 0.3 }, { 1, 1 } }, drag = 2, accel = { 0, 4, 0 }, light = 0.2, influence = 1, scaleSpeed = true }),
		flat("Ring", "thinring", FORGE.white, { { 0, 4 }, { 1, 18 } }, { 0.5, 0.5 }, { transparency = { { 0, 0.2 }, { 1, 1 } }, scaleSize = true }),
	}, { size = Vector3.new(18, 0.2, 18) })

	-- ===== Клинок сокольничего: «Соколиная охота» =====
	folder("V2/Falcon", {
		stream("Glow", "glow", HUNT.amber, { { 0, 2 }, { 1, 1.4 } }, { 0.15, 0.2 }, { 0, 0 }, 20, { locked = true, transparency = { { 0, 0.5 }, { 1, 1 } } }),
		stream("Feathers", "feather", HUNT.pale, { { 0, 0.5 }, { 1, 0.2 } }, { 0.6, 1 }, { 0.5, 1.5 }, 5, { spin = { -120, 120 }, accel = { 0, -2, 0 } }),
	}, { light = { color = HUNT.amber, brightness = 1.5, range = 8 }, trail = "V2/FalconTrail" })
	-- Тело сокола — BillboardGui с кадрами листа fb_bird (клиент, AbilityFxV2.falconBody).
	h.trail("V2/FalconTrail", "trail", { HUNT.pale, HUNT.amber }, { lifetime = 0.25, width = 1.2, transparency = { { 0, 0.3 }, { 1, 1 } } })
	part("V2/FalconCall", 2, {
		burst("Feathers", "fb_feathers", HUNT.gold, { { 0, 4 }, { 1, 4.5 } }, { 0.8, 0.8 }, { 0, 0 }, 1, { flip = 4 }),
		flat("Ring", "thinring", HUNT.amber, { { 0, 1 }, { 1, 8 } }, { 0.4, 0.4 }, { transparency = { { 0, 0.2 }, { 1, 1 } } }),
	})
	sig("V2/FalconCall")
	part("V2/FalconDive", 4, {
		burst("Feathers", "fb_feathers", HUNT.gold, { { 0, 8 }, { 1, 9 } }, { 1, 1 }, { 0, 0 }, 1, { flip = 4, z = 2 }),
		burst("Crit", "fb_crit", HUNT.amber, { { 0, 6 }, { 1, 7 } }, { 0.5, 0.5 }, { 0, 0 }, 1, { flip = 4, z = 3 }),
		flat("Ring", "thinring", HUNT.pale, { { 0, 2 }, { 1, 10 } }, { 0.4, 0.4 }, { transparency = { { 0, 0 }, { 1, 1 } }, scaleSize = true }),
		burst("Dust", "smoke", HUNT.smoke, { { 0, 1.5 }, { 1, 3.5 } }, { 0.6, 0.9 }, { 4, 8 }, 20, { pattern = "ring", dir = "Front", spread = { 10, 10 }, transparency = { { 0, 0.4 }, { 1, 1 } }, light = 0, influence = 1, drag = 3, scaleSpeed = true }),
	}, { light = { color = HUNT.gold, brightness = 6, range = 16, fade = 0.4 } })
	sig("V2/FalconDive")

	-- ===== Клинок Памяти: финал «Сшивка» =====
	folder("V2/MemoryDash", {
		stream("Glow", "glow", MEM.cyan, { { 0, 1.6 }, { 1, 0 } }, { 0.2, 0.3 }, { 0, 0 }, 60, { transparency = { { 0, 0.3 }, { 1, 1 } } }),
	}, { trail = "V2/MemoryTrail", light = { color = MEM.cyan, brightness = 2, range = 8 } })
	h.trail("V2/MemoryTrail", "trail", { MEM.white, MEM.cyan }, { lifetime = 0.35, width = 2.2, transparency = { { 0, 0.1 }, { 1, 1 } } })
	part("V2/MemoryBurst", 6, {
		burst("Blink", "fb_memory", MEM.cyan, { { 0, 8 }, { 1, 9 } }, { 0.7, 0.7 }, { 0, 0 }, 1, { flip = 4, z = 2 }),
		burst("Crit", "fb_crit", MEM.white, { { 0, 9 }, { 1, 10 } }, { 0.5, 0.5 }, { 0, 0 }, 1, { flip = 4, z = 3, keepColor = true }),
		flat("Ring", "thinring", MEM.cyan, { { 0, 2 }, { 1, 14 } }, { 0.5, 0.5 }, { transparency = { { 0, 0 }, { 1, 1 } }, scaleSize = true }),
		burst("Shards", "sparkle", { MEM.white, MEM.cyan }, { { 0, 0.6 }, { 1, 0 } }, { 0.6, 1 }, { 10, 18 }, 40, { drag = 3 }),
	}, { size = Vector3.new(12, 0.2, 12), light = { color = MEM.cyan, brightness = 7, range = 20, fade = 0.5 } })
	sig("V2/MemoryBurst")
	part("V2/MemoryEcho", 1.5, {
		burst("Blink", "fb_memory", MEM.cyan, { { 0, 6 }, { 1, 6.5 } }, { 0.6, 0.6 }, { 0, 0 }, 1, { flip = 4 }),
	})
	sig("V2/MemoryEcho")

	-- ===== Шлаковая коса: «Шлаковый смерч» =====
	part("V2/Cyclone", 6, {
		stream("Blades", "fb_scythe", FORGE.orange, 12, { 0.35, 0.35 }, { 0, 0 }, 6, { flip = 4, rot = { 0, 360 }, locked = true, keepColor = true, z = 2 }),
		stream("Slag", "ember", { FORGE.yellow, FORGE.red }, { { 0, 0.5 }, { 1, 0 } }, { 0.5, 0.8 }, { 8, 14 }, 40, { pattern = "ring", dir = "Front", spread = { 10, 30 }, accel = { 0, -16, 0 } }),
		stream("Dust", "smoke", FORGE.slag, { { 0, 2 }, { 1, 4 } }, { 0.6, 0.9 }, { 3, 6 }, 16, { shape = "Cylinder", style = "Surface", transparency = { { 0, 0.5 }, { 1, 1 } }, light = 0, influence = 1 }),
	}, { size = Vector3.new(12, 0.2, 12), light = { color = FORGE.orange, brightness = 3, range = 14 } })
	sig("V2/Cyclone")
	part("V2/SlagPool", 2.6, {
		flat("Pool", "magma", { FORGE.orange, FORGE.slag }, 5.2, { 1, 1 }, { rate = 2, emit = false, transparency = { { 0, 1 }, { 0.2, 0.3 }, { 0.8, 0.3 }, { 1, 1 } }, spin = { -10, 10 } }),
		stream("Bubbles", "ember", FORGE.yellow, { { 0, 0.3 }, { 1, 0 } }, { 0.4, 0.7 }, { 1, 2 }, 8, { shape = "Disc", style = "Surface", dir = "Top", spread = { 20, 20 } }),
	}, { size = Vector3.new(5.2, 0.2, 5.2), light = { color = FORGE.orange, brightness = 1.5, range = 7 } })
	part("V2/SlagSlam", 7, {
		burst("Slam", "fb_slam", FORGE.orange, { { 0, 16 }, { 1, 17 } }, { 1, 1 }, { 0, 0 }, 1, { flip = 4, z = 2 }),
		flat("Ring", "thinring", FORGE.yellow, { { 0, 2 }, { 1, 16 } }, { 0.5, 0.5 }, { transparency = { { 0, 0 }, { 1, 1 } }, scaleSize = true }),
		burst("Rocks", "rock", FORGE.slag, { { 0, 0.7 }, { 1, 0.3 } }, { 0.8, 1.2 }, { 10, 18 }, 22, { dir = "Top", spread = { 55, 55 }, accel = { 0, -30, 0 }, spin = { -200, 200 }, light = 0, influence = 1 }),
	}, { size = Vector3.new(14, 0.2, 14), light = { color = FORGE.orange, brightness = 7, range = 20, fade = 0.5 } })
	sig("V2/SlagSlam")

	-- ===== Чернильный клинок: «Чернильный прилив» =====
	part("V2/Tendrils", 1.5, {
		burst("Tendrils", "fb_tendrils", CHRON.lavender, { { 0, 5 }, { 1, 5.5 } }, { 1.1, 1.1 }, { 0, 0 }, 1, { flip = 4, z = 1 }),
		burst("Drops", "ink", CHRON.ink2, { { 0, 0.6 }, { 1, 0.2 } }, { 0.5, 0.8 }, { 2, 5 }, 10, { light = 0.2, influence = 1 }),
	})
	sig("V2/Tendrils")
	part("V2/InkBurst", 5, {
		burst("Burst", "fb_inkburst", CHRON.violet, { { 0, 13 }, { 1, 14 } }, { 1.1, 1.1 }, { 0, 0 }, 1, { flip = 4, z = 2 }),
		flat("Ring", "thinring", CHRON.lavender, { { 0, 2 }, { 1, 12 } }, { 0.5, 0.5 }, { transparency = { { 0, 0 }, { 1, 1 } }, scaleSize = true }),
		burst("Ink", "ink", { CHRON.ink, CHRON.ink2 }, { { 0, 1.2 }, { 1, 0.5 } }, { 0.7, 1.1 }, { 8, 14 }, 36, { pattern = "ring", dir = "Front", spread = { 25, 25 }, accel = { 0, -14, 0 }, light = 0.2, influence = 1, scaleSpeed = true }),
	}, { size = Vector3.new(10, 0.2, 10), light = { color = CHRON.violet, brightness = 6, range = 18, fade = 0.5 } })
	sig("V2/InkBurst")

	-- ===== Коса ловчего: «Последний гон» =====
	part("V2/HornWave", 7, {
		flat("Ring", "thinring", HUNT.prey, { { 0, 2 }, { 1, 28 } }, { 0.7, 0.7 }, { transparency = { { 0, 0.1 }, { 1, 1 } }, scaleSize = true }),
		burst("Dust", "smoke", HUNT.smoke, { { 0, 1.5 }, { 1, 3 } }, { 0.6, 0.9 }, { 6, 10 }, 24, { pattern = "ring", dir = "Front", spread = { 10, 10 }, transparency = { { 0, 0.5 }, { 1, 1 } }, light = 0, influence = 1, drag = 3, scaleSpeed = true }),
	}, { size = Vector3.new(14, 0.2, 14), light = { color = HUNT.prey, brightness = 3, range = 18, fade = 0.6 } })
	folder("V2/PreyMark", {
		stream("Mark", "claw", HUNT.prey, 1.8, { 0.5, 0.5 }, { 0, 0 }, 4, { locked = true, transparency = { { 0, 1 }, { 0.2, 0.1 }, { 0.8, 0.1 }, { 1, 1 } }, z = 2 }),
		stream("Glow", "glow", HUNT.blood, 2.4, { 0.4, 0.4 }, { 0, 0 }, 6, { locked = true, transparency = { { 0, 1 }, { 0.3, 0.5 }, { 1, 1 } } }),
	})
	part("V2/HuntSlash", 2, {
		burst("Slash", "fb_slash", HUNT.prey, { { 0, 7 }, { 1, 7.5 } }, { 0.35, 0.35 }, { 0, 0 }, 1, { flip = 4, rot = { -40, 40 }, z = 2, keepColor = true }),
		burst("Blood", "spark", { HUNT.prey, HUNT.blood }, { { 0, 0.35 }, { 1, 0 } }, { 0.25, 0.4 }, { 10, 16 }, 16, { orient = "VelocityParallel", squash = 1.2, drag = 5 }),
	}, { light = { color = HUNT.prey, brightness = 3, range = 10, fade = 0.3 } })
	sig("V2/HuntSlash")
	part("V2/HuntFinale", 6, {
		burst("Scythe", "fb_scythe", HUNT.pale, { { 0, 14 }, { 1, 15 } }, { 0.5, 0.5 }, { 0, 0 }, 1, { flip = 4, z = 2 }),
		flat("Ring", "thinring", HUNT.prey, { { 0, 2 }, { 1, 14 } }, { 0.5, 0.5 }, { transparency = { { 0, 0 }, { 1, 1 } }, scaleSize = true }),
	}, { size = Vector3.new(12, 0.2, 12), light = { color = HUNT.gold, brightness = 5, range = 16, fade = 0.4 } })
	sig("V2/HuntFinale")

	-- ===== Секатор Садовницы: лозы и «чик» =====
	part("V2/Vines", 1.5, {
		stream("Vines", "fb_roots", LEAF.green, 4.2, { 1.2, 1.2 }, { 0, 0 }, 1, { flip = 4, z = 1 }),
		stream("Thorns", "fb_thorns", LEAF.green, 5, { 1.2, 1.2 }, { 0, 0 }, 0.8, { flip = 4, z = 0.5 }),
	})
	sig("V2/Vines")
	part("V2/VineBurst", 2, {
		burst("Thorns", "fb_thorns", LEAF.green, { { 0, 6 }, { 1, 6.5 } }, { 0.8, 0.8 }, { 0, 0 }, 1, { flip = 4, z = 1 }),
		burst("Leaves", "feather", { LEAF.green, LEAF.dark }, { { 0, 0.6 }, { 1, 0.2 } }, { 0.6, 1 }, { 6, 12 }, 18, { spin = { -200, 200 }, drag = 2, light = 0.2, influence = 1 }),
		burst("Petals", "sparkle", LEAF.petal, { { 0, 0.5 }, { 1, 0.2 } }, { 0.8, 1.2 }, { 4, 8 }, 10, { spin = { -200, 200 }, accel = { 0, -3, 0 }, drag = 1.5 }),
	}, { light = { color = LEAF.green, brightness = 3, range = 10, fade = 0.4 } })
	sig("V2/VineBurst")

	-- ===== Приливный молот: «Прилив» =====
	folder("V2/WaveCrest", {
		stream("Crest", "fb_wave", SEA.water, 7, { 0.45, 0.45 }, { 0, 0 }, 18, { flip = 4, flipMode = "Loop", flipFps = { 12, 12 }, shape = "Box", z = 1 }),
		stream("Foam", "smoke", SEA.foam, { { 0, 1.2 }, { 1, 2.6 } }, { 0.4, 0.6 }, { 2, 5 }, 40, { shape = "Box", dir = "Top", spread = { 30, 30 }, transparency = { { 0, 0.3 }, { 1, 1 } }, light = 0.3, influence = 1 }),
		stream("Drops", "spark", SEA.water, { { 0, 0.3 }, { 1, 0 } }, { 0.4, 0.6 }, { 6, 10 }, 30, { shape = "Box", dir = "Top", spread = { 40, 40 }, accel = { 0, -24, 0 } }),
	}, { light = { color = SEA.water, brightness = 2, range = 10 } })
	sig("V2/WaveCrest")
	part("V2/Splash", 4.5, {
		burst("Splash", "fb_splash", SEA.water, { { 0, 10 }, { 1, 11 } }, { 0.9, 0.9 }, { 0, 0 }, 1, { flip = 4, z = 2 }),
		flat("Ring", "thinring", SEA.foam, { { 0, 2 }, { 1, 11 } }, { 0.5, 0.5 }, { transparency = { { 0, 0 }, { 1, 1 } }, scaleSize = true }),
		burst("Drops", "spark", { SEA.foam, SEA.water }, { { 0, 0.4 }, { 1, 0 } }, { 0.5, 0.8 }, { 10, 16 }, 30, { dir = "Top", spread = { 50, 50 }, accel = { 0, -30, 0 } }),
	}, { size = Vector3.new(9, 0.2, 9), light = { color = SEA.water, brightness = 4, range = 14, fade = 0.4 } })
	sig("V2/Splash")
	part("V2/Puddle", 4.5, {
		flat("Pool", "smoke", SEA.water, 9, { 1, 1 }, { rate = 2, emit = false, transparency = { { 0, 1 }, { 0.2, 0.45 }, { 0.8, 0.45 }, { 1, 1 } }, spin = { -10, 10 } }),
		stream("Ripples", "thinring", SEA.foam, { { 0, 0.5 }, { 1, 2.5 } }, { 0.8, 0.8 }, { 0.01, 0.01 }, 4, with(h.FLAT, { shape = "Disc", style = "Surface", transparency = { { 0, 0.4 }, { 1, 1 } } })),
	}, { size = Vector3.new(9, 0.2, 9) })

	-- ===== Перо хрониста: «Строка» крестом =====
	part("V2/RuneGlyph", 1.2, {
		burst("Glyph", "fb_runes", CHRON.lavender, { { 0, 3.2 }, { 1, 3.4 } }, { 1.2, 1.2 }, { 0, 0 }, 1, { flip = 4, z = 1 }),
	})
	sig("V2/RuneGlyph")
	part("V2/RuneBlast", 2.5, {
		burst("Burst", "fb_inkburst", CHRON.violet, { { 0, 5 }, { 1, 5.5 } }, { 0.7, 0.7 }, { 0, 0 }, 1, { flip = 4, z = 2 }),
		burst("Sparks", "sparkle", { CHRON.white, CHRON.lavender }, { { 0, 0.5 }, { 1, 0 } }, { 0.4, 0.7 }, { 8, 14 }, 18, { drag = 4 }),
	}, { light = { color = CHRON.violet, brightness = 4, range = 10, fade = 0.3 } })
	sig("V2/RuneBlast")

	-- ===== Подтянутый визуал: Жатва, Свора, Капкан; Перекал; Тигель =====
	part("V2/ReapCrescent", 2, {
		burst("Crescent", "fb_scythe", LEAF.green, { { 0, 8 }, { 1, 9 } }, { 0.45, 0.45 }, { 0, 0 }, 1, { flip = 4, z = 2, keepColor = true }),
	})
	sig("V2/ReapCrescent")
	part("V2/RotMark", 1.2, {
		burst("Rot", "smoke", { LEAF.dark, "#2A2A12" }, { { 0, 1.2 }, { 1, 2.4 } }, { 0.8, 1.2 }, { 0.5, 1.5 }, 6, { dir = "Top", transparency = { { 0, 0.4 }, { 1, 1 } }, light = 0, influence = 1 }),
		burst("Flies", "spark", LEAF.green, { { 0, 0.2 }, { 1, 0 } }, { 0.6, 1 }, { 1, 3 }, 6, { spin = { -300, 300 } }),
	})
	part("V2/Bite", 1.5, {
		burst("Bite", "fb_bite", HUNT.blood, { { 0, 4 }, { 1, 4.4 } }, { 0.45, 0.45 }, { 0, 0 }, 1, { flip = 4, rot = { -20, 20 }, z = 2 }),
	})
	sig("V2/Bite")
	part("V2/Jaws", 2, {
		burst("Jaws", "fb_jaws", HUNT.iron, { { 0, 6 }, { 1, 6.5 } }, { 0.6, 0.6 }, { 0, 0 }, 1, { flip = 4, z = 2 }),
	})
	sig("V2/Jaws")
	part("V2/JawRing", 7.5, {
		flat("Teeth", "crack", HUNT.iron, 15, { 0.55, 0.55 }, { transparency = { { 0, 1 }, { 0.3, 0.2 }, { 1, 0.6 } }, spin = { 60, 60 }, z = 0.3 }),
		flat("Ring", "thinring", HUNT.prey, { { 0, 15 }, { 1, 13 } }, { 0.55, 0.55 }, { transparency = { { 0, 1 }, { 0.3, 0.2 }, { 1, 0.3 } }, z = 0.2 }),
	}, { size = Vector3.new(15, 0.2, 15), scalePart = true })
	folder("V2/HeatBlade", {
		stream("Glow", "glow", { FORGE.white, FORGE.yellow }, { { 0, 1.2 }, { 1, 0.4 } }, { 0.2, 0.3 }, { 0, 0.5 }, 40, { shape = "Box", transparency = { { 0, 0.3 }, { 1, 1 } } }),
		stream("Haze", "smoke", FORGE.steam, { { 0, 0.6 }, { 1, 1.4 } }, { 0.4, 0.6 }, { 1, 2 }, 10, { accel = { 0, 3, 0 }, transparency = { { 0, 0.85 }, { 1, 1 } }, light = 0, influence = 1 }),
	}, { light = { color = FORGE.yellow, brightness = 2, range = 8 } })
	part("V2/SearingFinale", 4, {
		burst("Burst", "fb_crit", FORGE.yellow, { { 0, 8 }, { 1, 9 } }, { 0.5, 0.5 }, { 0, 0 }, 1, { flip = 4, z = 2 }),
		flat("Ring", "thinring", FORGE.orange, { { 0, 2 }, { 1, 10 } }, { 0.4, 0.4 }, { transparency = { { 0, 0 }, { 1, 1 } }, scaleSize = true }),
		burst("Sparks", "spark", { FORGE.yellow, FORGE.orange }, { { 0, 0.4 }, { 1, 0 } }, { 0.3, 0.5 }, { 14, 22 }, 30, { orient = "VelocityParallel", squash = 1.2, drag = 4 }),
	}, { size = Vector3.new(8, 0.2, 8), light = { color = FORGE.orange, brightness = 6, range = 16, fade = 0.4 } })
	sig("V2/SearingFinale")
	folder("V2/CrucibleStream", {
		stream("Metal", "glow", { FORGE.white, FORGE.orange }, { { 0, 0.9 }, { 1, 0.6 } }, { 0.4, 0.5 }, { 10, 14 }, 60, { dir = "Front", spread = { 6, 6 }, accel = { 0, -30, 0 } }),
		stream("Smoke", "smoke", FORGE.soot, { { 0, 0.8 }, { 1, 1.8 } }, { 0.5, 0.8 }, { 1, 3 }, 12, { accel = { 0, 4, 0 }, transparency = { { 0, 0.5 }, { 1, 1 } }, light = 0, influence = 1 }),
	}, { light = { color = FORGE.orange, brightness = 3, range = 10 } })
end

return FxWeaponsV2
