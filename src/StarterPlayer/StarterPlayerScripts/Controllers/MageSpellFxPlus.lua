--!nonstrict
-- MageSpellFxPlus (клиент)
-- Продлённые фазы заклинаний мага поверх MageSpellFx: по pixelfx — предвкушение, белый
-- кадр-«hero frame» с hit-stop (только своему магу), тряска и рывок FOV, разлёт, «висение»
-- (искры, угли, пыль), распад и долгий хвост 2–4 с, плюс звуки (Config/SfxSkills).
-- Фазы и поля — те же, что у MageSpellFx (сервер не меняется). Вызывается из
-- MageSpellFx.handle после основного обработчика с тем же (payload, ctx).
-- «Призрачная стая», «Королевская ловля», «Грибница» — рисует MageSpellFxV2 (07.11), здесь их нет.

local Players = game:GetService("Players")

local Fx = require(script.Parent.Parent.Lib.FxAfter)
local Kit = Fx.Kit

local Plus = {}

local V3 = Vector3.new
local TAU = math.pi * 2
local WHITE = Color3.new(1, 1, 1)
local C = Fx.C
local rnd = Fx.rnd

-- Палитра MageSpellFx (подставляется из MageSpellFx.PALETTE), ниже — запасные цвета.
local P = {
	ward = C("#8C6CFF"), wardCore = C("#FFE7A0"),
	fire = C("#FF5A1F"), fireCore = C("#FFF4C0"), fireDark = C("#B8200F"),
	light = C("#FFD45A"), lightCore = C("#FFFDEE"),
	lotus = C("#FF8FD0"), lotusCore = C("#FFF2FB"), water = C("#4FD6FF"), waterCore = C("#EFFFFF"),
	spore = C("#C8E04A"), sporeCore = C("#FFFBD6"), poison = C("#8EE04A"),
	thorn = C("#6FCF5A"), thornDark = C("#2F6B2A"), thornCore = C("#EAFFD6"),
	moon = C("#A8C8FF"), moonCore = C("#F6F9FF"),
	bolt = C("#7FD8FF"), boltCore = WHITE, boltDeep = C("#3F7FFF"),
	magma = C("#FF3A10"), magmaCore = C("#FFE6A0"),
	forge = C("#FFE39A"), forgeHot = C("#FF8A2A"),
	page = C("#EFE6CC"), pageCore = C("#FFFFF4"), gold = C("#FFD98A"),
	time = C("#6FE3FF"), timeCore = C("#F2FFFF"),
	ink = C("#6A58D8"), inkDark = C("#14122A"), inkCore = C("#D2C4FF"),
	memory = C("#6FE3FF"), memoryAlt = C("#B49CFF"),
}
local EXTRA = {
	soot = C("#2A2220"), slag = C("#3A2E2A"), ash = C("#4A403A"), steam = C("#E4E0DA"),
	cool = C("#5A140A"), rock = C("#5A4C42"), dust = C("#A8957A"), wither = C("#9A8A4A"),
}

function Plus.setPalette(palette)
	for key, value in pairs(palette or {}) do
		if typeof(value) == "Color3" then
			P[key] = value
		end
	end
end

local LETTERS = { "A", "Ж", "R", "Ψ", "Ф", "K", "Л", "Ω", "Я", "S", "Д", "Θ", "Б", "Ξ", "M", "И" }

-- ===== Помощники =====

local function G(position: Vector3, lift: number?): Vector3
	return Kit.ground(position, lift or 0.06)
end

local function vec(value, fallback)
	if typeof(value) == "Vector3" then
		return value
	end
	return fallback
end

local function feetOf(caster)
	local _, root = Kit.characterOf(caster)
	return root and root.Position - V3(0, 3, 0) or nil
end

local function centerOf(p, s, fallback)
	local at = vec(p.position) or s.center or fallback or feetOf(p.caster)
	return at and G(at) or nil
end

local function along(origin: Vector3, dir: Vector3, length: number, n: number)
	local list = {}
	for i = 1, n do
		table.insert(list, origin + dir * length * ((i - 0.5) / n))
	end
	return list
end

local H = {}

-- ===== Охранный круг =====
H.ward_circle = {
	cast = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		s.center, s.radius = center, p.radius or 6
		local burstAt = math.max(p.burstAt or 0.3, 0.15)
		Fx.inward(center + V3(0, 1, 0), s.radius, { color = P.ward, count = 26, time = burstAt, speed = s.radius / burstAt * 0.9, size = { 0.2, 0.45 } })
		Fx.sfx("fxWardBuild", center)
	end,
	burst = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local radius = p.radius or s.radius or 6
		Fx.heroFrame(center + V3(0, 1.2, 0), { color = P.ward, size = radius * 0.5, flash = 0.22, stop = 0.08, caster = p.caster, fov = 4, ground = center })
		Fx.motes(center + V3(0, 1, 0), { color = P.wardCore, area = radius * 1.4, time = math.min(p.duration or 3, 4), rate = 10 })
		Fx.sfx("fxWardBurst", center)
	end,
	-- Финал: кольцо схлопывается, руны поднимаются, свет медленно гаснет.
	["end"] = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local radius = s.radius or p.radius or 6
		Fx.collapse(center, radius, P.ward, { time = 0.6 })
		Fx.glyphs(center, { count = 10, color = P.wardCore, radius = radius * 0.7, time = 2.4 })
		Fx.afterglow(center + V3(0, 1, 0), { color = P.ward, time = 2.5, brightness = 3, range = radius * 2.5 })
		Fx.motes(center + V3(0, 0.5, 0), { color = P.ward, area = radius, time = 1.8, rate = 8 })
		Fx.sfx("fxWardEnd", center)
	end,
}

-- ===== Сигнальный огонь =====
H.signal_fire = {
	blast = function(p, s)
		local ground = centerOf(p, s)
		if not ground then
			return
		end
		local radius = p.radius or 5
		local duration = p.duration or 3
		s.center, s.pillar = ground, p.pillarRadius or 4
		Fx.heroFrame(ground + V3(0, 1.5, 0), { color = P.fire, size = radius * 0.7, flash = 0.32, stop = 0.1, caster = p.caster, fov = 6, ground = ground })
		Fx.scorch(ground, radius * 0.8, { life = duration + 4, hot = P.fire, glow = duration + 0.5 })
		Fx.debris(ground, { count = 10, hot = P.fireCore, color = EXTRA.soot, speed = 12, up = 20, time = 3 })
		Fx.embers(ground, { time = duration + 1.5, rate = 16, area = V3(radius * 1.2, 0.3, radius * 1.2) })
		Fx.sfx("fxSignalBlast", ground)
		Fx.sfx("fxSignalTail", ground)
	end,
	-- Финал: столб дыма, остывающие угли, пепел.
	["end"] = function(p, s)
		local ground = centerOf(p, s)
		if not ground then
			return
		end
		local r = (s.pillar or 4) * 0.5
		Fx.plume(ground, { time = 3.5, rate = 12, radius = r })
		Fx.embers(ground, { time = 3, rate = 8, color = { "#FFB070", "#B8200F", "#3A1A10" }, area = V3(r * 2, 0.3, r * 2) })
		Fx.afterglow(ground + V3(0, 1, 0), { color = P.fire, time = 3.5, brightness = 3, range = 16 })
		Fx.flutter(ground + V3(0, 1, 0), { kind = "ash", count = 8, up = 6, speed = 3, time = 4.5 })
		Fx.sfx("fxSignalEnd", ground)
	end,
}

-- ===== Врата света =====
H.light_gate = {
	cast = function(p, s)
		local gate = centerOf(p, s)
		if not gate then
			return
		end
		s.center = gate
		local width = p.width or 6
		Fx.inward(gate + V3(0, 3, 0), width * 0.6, { color = P.light, count = 22, time = math.max(p.surgeAt or 0.55, 0.2), speed = width * 1.2 })
	end,
	-- Прорыв: кадр, светлый след по земле, перья, вспышка экрана.
	surge = function(p, s)
		local origin = vec(p.origin, s.center)
		if not origin then
			return
		end
		local dir = Kit.flatUnit(vec(p.dir, V3(0, 0, -1)))
		local length = p.length or 18
		local half = p.halfWidth or 2
		local ground = G(origin)
		Fx.heroFrame(ground + V3(0, 2, 0), { color = P.light, size = 5, flash = 0.36, stop = 0.08, caster = p.caster, fov = 6, ring = false })
		Fx.seamPath(ground, dir, length, { hot = P.lightCore, cool = P.light, life = 2.5, width = half * 0.8, jitter = 0.2 })
		for i, point in ipairs(along(ground, dir, length, 3)) do
			Kit.after(0.08 * i, function()
				Fx.flutter(point + V3(0, 2.5, 0), { kind = "feather", count = 4, glow = true, up = 3, speed = 2, time = 4.5 })
			end)
		end
		Fx.tint(ground, { color = P.lightCore, time = 0.8, amount = 0.25, brightness = 0.08 })
		Fx.sfx("fxGateSurge", ground)
	end,
	-- Закрытие: осколки света, кольцо внутрь, пылинки, хор.
	close = function(p, s)
		local gate = centerOf(p, s)
		if not gate then
			return
		end
		local radius = p.radius or 6
		Fx.debris(gate + V3(0, 3, 0), { count = 12, color = P.light, material = Enum.Material.Neon, shard = true, size = 0.5, speed = 10, up = 12, time = 2.8, transparency = 0.1, groundY = gate.Y })
		Fx.collapse(gate, radius * 0.6, P.light, { time = 0.5 })
		Fx.motes(gate + V3(0, 2, 0), { color = P.lightCore, area = 4, height = 4, time = 2.5, rate = 12 })
		Fx.afterglow(gate + V3(0, 2, 0), { color = P.light, time = 2.5, brightness = 4, range = 20 })
		Fx.sfx("fxGateClose", gate)
		Fx.sfx("fxGateTail", gate, nil, 0.3)
	end,
}

-- ===== Цветок лотоса =====
H.lotus_bloom = {
	cast = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		s.center, s.radius = center, p.radius or 6
		Fx.ripples(center, { time = math.max(p.geyserAt or 0.3, 0.2), count = 4, radius = s.radius * 0.5, size = s.radius * 0.3, color = P.waterCore, ringTime = 0.6 })
	end,
	-- Гейзер: кадр, брызги вверх и дождь капель, лепестки, рябь, дымка.
	geyser = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local radius = p.radius or s.radius or 6
		Fx.heroFrame(center + V3(0, 1.5, 0), { color = P.water, size = radius * 0.6, flash = 0.22, stop = 0.08, caster = p.caster, fov = 5, ground = center })
		Fx.drops(center + V3(0, 1.5, 0), { count = 22, color = P.waterCore, up = 24, speed = radius * 1.2, time = 2.4, groundY = center.Y })
		Kit.after(0.5, function()
			Fx.drops(center + V3(0, 9, 0), { count = 14, color = P.water, up = 3, speed = radius * 0.8, time = 2, groundY = center.Y })
		end)
		Fx.flutter(center + V3(0, 3, 0), { kind = "petal", count = 14, radius = radius * 0.4, up = 10, speed = 6, time = 5.5, groundY = center.Y })
		Fx.ripples(center, { time = 3, count = 7, radius = radius * 0.7, size = radius * 0.35, color = P.waterCore })
		Fx.mist(center, { radius = radius * 0.6, time = 3, color = C("#DDF7FF") })
		Fx.sfx("fxLotusGeyser", center)
		Fx.sfx("fxLotusTail", center, nil, 0.4)
	end,
}

-- ===== Грибница =====
H.mycelium = {
	-- Гриб лопается: мини-кадр, облако спор, ошмётки шляпки.
	pop = function(p, s)
		local ground = centerOf(p, s)
		if not ground then
			return
		end
		local radius = p.radius or 2.5
		Fx.heroFrame(ground + V3(0, 1, 0), { color = P.spore, size = math.max(2.5, radius), flash = 0.08, stop = 0.05, caster = p.caster, sparks = 8, ground = ground })
		Fx.smoke(ground + V3(0, 1, 0), { color = P.spore, radius = radius * 0.7, count = 8, lightEmission = 0.4, life = { 1.6, 2.6 }, accel = V3(0, 0.6, 0) })
		Fx.motes(ground + V3(0, 1, 0), { color = P.sporeCore, texture = "glow", area = radius * 1.5, time = 2.2, rate = 8, size = { 0.12, 0.25, 0 } })
		Fx.flutter(ground + V3(0, 0.8, 0), { kind = "cap", count = 4, up = 10, speed = 6, time = 3, rest = 0.6 })
		Fx.sfx("fxMycelPop", ground)
		Fx.sfx("fxMycelTail", ground, 0.8, 0.3)
	end,
}

-- ===== Терновый сад =====
H.thorn_garden = {
	cast = function(p, s)
		local center = centerOf(p, s)
		if center then
			s.center = center
		end
	end,
	ring = function(p, s)
		local ground = centerOf(p, s)
		if not ground then
			return
		end
		local radius = p.radius or 4
		s.radius = math.max(s.radius or 0, radius)
		Fx.dust(ground, { radius = radius * 0.6, dirs = 8, count = 2, color = EXTRA.dust })
		Fx.debris(ground, { count = 6, color = EXTRA.rock, size = 0.45, speed = radius * 1.5, up = 14, time = 2.6 })
		Fx.sfx("fxThornRing", ground)
	end,
	garden = function(p, s)
		local ground = centerOf(p, s)
		if not ground then
			return
		end
		local radius = p.radius or s.radius or 6
		s.center, s.radius = ground, radius
		Fx.heroFrame(ground + V3(0, 1, 0), { color = P.thorn, size = radius * 0.5, flash = 0.18, stop = 0.08, caster = p.caster, fov = 4, ground = ground })
		Fx.flutter(ground + V3(0, 1.5, 0), { kind = "leaf", count = 10, radius = radius * 0.6, up = 8, speed = 5, time = 4.5 })
		Fx.sfx("fxThornGarden", ground)
	end,
	-- Финал: шипы вянут и крошатся, листья опадают.
	["end"] = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local radius = s.radius or 6
		Fx.debris(center, { count = 14, color = P.thornDark, shard = true, size = 0.5, radius = radius * 0.8, speed = 4, up = 6, time = 3 })
		Fx.flutter(center + V3(0, 2.5, 0), { kind = "leaf", count = 12, radius = radius * 0.7, up = 2, speed = 2, time = 5, color = EXTRA.wither })
		Fx.smoke(center + V3(0, 0.5, 0), { color = EXTRA.dust, radius = radius * 0.5, count = 8 })
		Fx.collapse(center, radius, P.thorn, { time = 0.7 })
		Fx.sfx("fxThornEnd", center)
	end,
}

-- ===== Луна охотника =====
H.hunters_moon = {
	cast = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local radius = p.radius or 8
		local height = p.height or 14
		local life = (p.crescentAt or 2.7) + 2.5
		s.center, s.radius = center, radius
		Fx.mist(center, { radius = radius * 0.6, time = life, color = P.moon, rate = 4, lightEmission = 0.4 })
		Fx.motes(center + V3(0, height * 0.3, 0), { color = P.moonCore, area = radius, height = height * 0.6, time = life, rate = 10 })
	end,
	beam = function(p)
		local at = vec(p.position)
		if not at then
			return
		end
		local ground = G(at)
		Fx.sparks(ground + V3(0, 0.3, 0), { color = P.moonCore, count = 8, speed = { 6, 14 } })
		Kit.ringWave(ground, 1.6, P.moon, { time = 0.35, brightness = 3 })
		Fx.sfx("fxMoonBeam", ground, 0.8)
	end,
	-- Полумесяц: кадр, шрам-кольцо на земле, звёздная пыль, сова вдали.
	crescent = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local radius = p.radius or s.radius or 8
		Fx.heroFrame(center + V3(0, 1.5, 0), { color = P.moon, size = radius * 0.5, flash = 0.3, stop = 0.1, caster = p.caster, fov = 6, ground = center })
		Fx.scorch(center, radius * 0.7, { color = C("#0F1830"), hot = P.moonCore, cool = P.moon, glow = 2.5, life = 5, transparency = 0.5 })
		Fx.motes(center + V3(0, 1.5, 0), { color = P.moon, area = radius * 1.2, time = 3, rate = 14 })
		Fx.afterglow(center + V3(0, 2, 0), { color = P.moon, time = 3, brightness = 4, range = radius * 2 })
		Fx.sfx("fxMoonCrescent", center)
		Fx.sfx("fxMoonTail", center, nil, 0.3)
	end,
}

-- ===== Огненный дождь =====
H.fire_rain = {
	cast = function(p, s)
		local center = centerOf(p, s)
		if center then
			s.center, s.radius = center, p.radius or 8
		end
	end,
	meteor = function(p, s)
		local at = vec(p.position)
		if not at then
			return
		end
		local fall = p.fall or 0.4
		local radius = p.radius or 2
		Kit.after(fall, function()
			local ground = G(at)
			Fx.scorch(ground, radius * 0.6, { life = 4, glow = 1.2 })
			Fx.sparks(ground + V3(0, 0.4, 0), { color = P.fireCore, count = 8, speed = { 8, 16 } })
			Fx.debris(ground, { count = 3, hot = P.fireCore, color = EXTRA.soot, size = 0.35, speed = 8, up = 14, time = 2.2 })
			Fx.sfx("fxRainMeteor", ground)
		end)
	end,
	-- Финал: пепел оседает, дым и угли гаснут.
	["end"] = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local radius = s.radius or 8
		Fx.flutter(center + V3(0, 3, 0), { kind = "ash", count = 14, radius = radius, up = 1, speed = 1, time = 5 })
		Fx.plume(center, { time = 3, rate = 8, radius = radius * 0.4 })
		Fx.embers(center, { area = V3(radius * 1.6, 0.3, radius * 1.6), time = 3, rate = 12 })
		Fx.sfx("fxRainEnd", center)
	end,
}

-- ===== Кованая молния =====
H.forged_lightning = {
	-- Удар: кадр, выжженная звезда, ползущие разряды, раскат грома.
	strike = function(p)
		local at = vec(p.position)
		if not at then
			return
		end
		local ground = G(at)
		Fx.heroFrame(ground + V3(0, 1.5, 0), { color = P.bolt, size = 5, flash = 0.42, stop = 0.1, caster = p.caster, fov = 6, sparks = 20, ground = ground })
		Fx.scorch(ground, 2.6, { image = "crack", hot = P.boltCore, cool = P.boltDeep, glow = 1.2, life = 5, transparency = 0.25 })
		Fx.arcs(ground, { color = P.bolt, time = 2.2, count = 8, radius = 3, sound = "fxForgedChain" })
		Fx.tint(ground, { color = C("#CFE8FF"), time = 0.5, amount = 0.3, brightness = 0.12, contrast = 0.2 })
		Fx.sfx("fxForgedStrike", ground)
		Fx.sfx("fxForgedTail", ground)
	end,
	chain = function(p)
		local points = p.points
		if type(points) ~= "table" then
			return
		end
		for i = 2, #points do
			local point = vec(points[i])
			if point then
				Fx.sparks(point, { color = P.bolt, count = 8, speed = { 6, 14 } })
				Fx.scorch(G(point), 1.2, { life = 3, hot = P.boltCore, cool = P.boltDeep, glow = 0.6 })
			end
		end
		Fx.sfx("fxForgedChain", vec(points[2]) or vec(points[1]))
	end,
}

-- ===== Сердце кузни =====
H.forge_heart = {
	cast = function(p, s)
		local origin = vec(p.origin)
		if not origin then
			return
		end
		local dir = Kit.flatUnit(vec(p.dir, V3(0, 0, -1)))
		local length = p.length or 16
		s.origin, s.dir, s.length = G(origin), dir, length
		Fx.seamPath(s.origin, dir, length, { hot = P.forgeHot, cool = EXTRA.cool, life = (p.crackTime or 0.5) + (p.wallAt or 1) + 0.5, reveal = p.crackTime or 0.5, width = 0.4 })
	end,
	pillar = function(p)
		local at = vec(p.position)
		if not at then
			return
		end
		local ground = G(at)
		Fx.debris(ground, { count = 4, hot = P.forge, color = EXTRA.soot, speed = 8, up = 18, time = 2.6 })
		Fx.sparks(ground + V3(0, 0.5, 0), { color = P.forgeHot, count = 10 })
		Fx.sfx("fxForgePillar", ground, 0.8)
	end,
	wall = function(p, s)
		local origin = vec(p.origin, s.origin)
		if not origin then
			return
		end
		local dir = Kit.flatUnit(vec(p.dir, s.dir or V3(0, 0, -1)))
		local length = p.length or s.length or 16
		local ground = G(origin)
		s.origin, s.dir, s.length = ground, dir, length
		Fx.heroFrame(ground + dir * length * 0.5 + V3(0, 2, 0), { color = P.forgeHot, size = 5, flash = 0.28, stop = 0.1, caster = p.caster, fov = 5, ring = false })
		for _, point in ipairs(along(ground, dir, length, 3)) do
			Fx.embers(point, { time = (p.duration or 3) + 1, rate = 8, area = V3(2, 0.3, 2) })
		end
		Fx.sfx("fxForgeWall", ground + dir * length * 0.5)
	end,
	-- Финал: дым, остывающий шлак, шов гаснет.
	["end"] = function(p, s)
		local origin = vec(p.origin, s.origin)
		if not origin then
			return
		end
		local ground = G(origin)
		local dir = s.dir or V3(0, 0, -1)
		local length = s.length or 16
		for _, point in ipairs(along(ground, dir, length, 3)) do
			Fx.plume(point, { time = 3, rate = 6, radius = 1.4 })
			Fx.debris(point, { count = 4, hot = P.forgeHot, color = EXTRA.slag, speed = 4, up = 8, time = 3 })
		end
		Fx.seamPath(ground, dir, length, { hot = P.forgeHot, cool = C("#3A1208"), life = 3.5, width = 0.6 })
		Fx.afterglow(ground + dir * length * 0.5 + V3(0, 1, 0), { color = P.forgeHot, time = 3, brightness = 4, range = length })
		Fx.sfx("fxForgeEnd", ground + dir * length * 0.5)
	end,
}

-- ===== Метеор =====
H.meteor = {
	cast = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		s.center, s.radius = center, p.radius or 8
		Fx.motes(center + V3(0, 0.5, 0), { color = P.fireCore, texture = "glow", area = s.radius, height = 0.5, time = math.max(p.impactAt or 1, 0.3), rate = 10, accel = V3(0, 2, 0) })
	end,
	-- Удар: кадр, обломки, гриб дыма, дождь камней, кратер.
	impact = function(p, s)
		local ground = centerOf(p, s)
		if not ground then
			return
		end
		local radius = p.radius or s.radius or 8
		local lavaTime = p.lavaTime or 3
		s.center, s.lava = ground, p.lavaRadius or radius * 0.6
		Fx.heroFrame(ground + V3(0, 2, 0), { color = P.magmaCore, size = radius * 0.7, flash = 0.5, stop = 0.14, caster = p.caster, fov = 8, sparks = 28, ground = ground })
		Fx.debris(ground, { count = 24, hot = P.magmaCore, color = EXTRA.slag, speed = radius * 2.2, up = 30, size = 0.8, time = 3.6 })
		Fx.dust(ground, { radius = radius * 0.9, dirs = 12, count = 3, color = EXTRA.dust })
		Fx.plume(ground, { time = 2.2, rate = 26, radius = radius * 0.35, speed = { 8, 14 }, life = { 1.6, 2.6 }, spread = 8, color = C("#4A3A32") })
		Kit.after(0.5, function()
			Fx.smoke(ground + V3(0, 9, 0), { radius = radius * 0.6, count = 10, color = C("#3E3430"), speed = { 2, 5 }, accel = V3(0, 1, 0) })
		end)
		Kit.after(0.7, function()
			Fx.debris(ground + V3(0, 10, 0), { count = 10, color = EXTRA.rock, speed = radius * 0.8, up = 2, size = 0.45, time = 2.6, groundY = ground.Y })
		end)
		Fx.scorch(ground, radius * 0.8, { life = lavaTime + 4, hot = P.magma, glow = lavaTime * 0.6 + 1, transparency = 0.15 })
		Fx.tint(ground, { color = C("#FFD9B0"), time = 0.6, amount = 0.3, brightness = 0.1, contrast = 0.15 })
		Fx.sfx("fxMeteorImpact", ground)
		Fx.sfx("fxMeteorTail", ground, nil, 0.6)
	end,
	-- Финал: лава остывает паром.
	["end"] = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local r = s.lava or 5
		Fx.smoke(center + V3(0, 0.5, 0), { color = EXTRA.steam, radius = r * 0.7, count = 12, lightInfluence = 0.6, accel = V3(0, 5, 0), life = { 1.8, 3 } })
		Fx.plume(center, { color = EXTRA.steam, time = 2.5, rate = 8, radius = r * 0.4, transparency = { 0.55, 0.7, 1 } })
		Fx.embers(center, { time = 2, rate = 6, color = { "#FFB070", "#7A2A10" }, area = V3(r, 0.3, r) })
		Fx.afterglow(center + V3(0, 1, 0), { color = P.magma, time = 2.5, brightness = 3, range = r * 3 })
		Fx.sfx("fxMeteorEnd", center)
	end,
}

-- ===== Первое заклинание =====
H.first_cast = {
	cast = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local radius = p.radius or 14
		local novaAt = math.max(p.novaAt or 1.25, 0.3)
		s.center, s.radius = center, radius
		Fx.inward(center + V3(0, 1, 0), radius * 0.7, { color = P.forge, count = 40, time = novaAt, speed = radius * 0.9, streak = true })
	end,
	rift = function(p)
		local origin = vec(p.origin)
		if not origin then
			return
		end
		local dir = Kit.flatUnit(vec(p.dir, V3(0, 0, -1)))
		local length = p.length or 12
		local ground = G(origin)
		Fx.seamPath(ground, dir, length, { hot = P.magmaCore, cool = EXTRA.cool, life = 3.5, width = 0.5 })
		for _, point in ipairs(along(ground, dir, length, 3)) do
			Fx.debris(point, { count = 4, hot = P.magmaCore, color = EXTRA.soot, speed = 5, up = 14, size = 0.4, time = 2.6 })
		end
		Fx.sfx("fxFirstRift", ground + dir * length * 0.5)
	end,
	-- Нова: главный кадр — белая вспышка, hit-stop, шлак, кратер, угли, гонг.
	nova = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local radius = p.radius or s.radius or 14
		Fx.heroFrame(center + V3(0, 2, 0), { color = P.forge, size = radius * 0.5, flash = 0.55, stop = 0.14, caster = p.caster, fov = 9, sparks = 30, ground = center })
		Fx.tint(center, { color = C("#FFE9C0"), time = 0.9, amount = 0.35, brightness = 0.15, contrast = 0.2 })
		Fx.debris(center, { count = 20, hot = P.forge, color = EXTRA.slag, speed = radius * 1.6, up = 26, time = 3.6 })
		Fx.dust(center, { radius = radius * 0.7, dirs = 12, count = 3, color = EXTRA.dust })
		Fx.scorch(center, radius * 0.6, { life = 6, hot = P.forgeHot, glow = 2.5 })
		Fx.embers(center, { area = V3(radius, 0.3, radius), time = 3.5, rate = 20 })
		Fx.afterglow(center + V3(0, 2, 0), { color = P.forge, time = 3.5, brightness = 6, range = radius * 2.5 })
		Fx.sfx("fxFirstNova", center)
		Fx.sfx("fxFirstTail", center, nil, 0.4)
	end,
}

-- ===== Открытый фолиант =====
H.open_tome = {
	cast = function(p, s)
		local feet = feetOf(p.caster)
		if not feet then
			return
		end
		s.center = G(feet)
		Fx.glyphs(s.center, { count = 6, color = P.gold, letters = LETTERS, radius = 2, time = math.max(p.stormAt or 1.3, 0.6) + 0.4 })
	end,
	-- Шторм: страницы кружат и ложатся, буквы взлетают, книга захлопывается.
	storm = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local radius = p.radius or 6
		Fx.heroFrame(center + V3(0, 2, 0), { color = P.gold, size = radius * 0.5, flash = 0.2, stop = 0.07, caster = p.caster, ground = center })
		Fx.flutter(center + V3(0, 5, 0), { kind = "page", count = 12, radius = radius * 0.8, up = 3, speed = 3, time = 6, rest = 1.6 })
		Fx.glyphs(center, { count = 12, letters = LETTERS, color = P.gold, radius = radius * 0.8, time = 3, rise = 1.2 })
		local caster = p.caster
		Kit.after(2.6, function()
			local tip = Kit.tipOf(caster) or center + V3(0, 3, 0)
			Kit.flash(tip, P.pageCore, 2, 0.2)
			Fx.sparks(tip, { color = P.gold, count = 10, speed = { 4, 10 } })
		end)
		Fx.sfx("fxTomeStorm", center)
		Fx.sfx("fxTomeEnd", center, nil, 2.2)
	end,
}

-- ===== Остановка времени =====
H.time_stop = {
	cast = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local radius = p.radius or 10
		s.center, s.radius = center, radius
		Fx.ripples(center, { time = math.max(p.freezeAt or 0.3, 0.2) + 0.2, count = 3, radius = radius * 0.3, size = radius * 0.6, color = P.timeCore, ringTime = 0.6 })
		Fx.sfx("fxTimeCast", center)
	end,
	-- Заморозка: кадр, мир выцветает, пыль висит в воздухе.
	freeze = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local radius = p.radius or s.radius or 10
		local duration = p.duration or 2
		Fx.heroFrame(center + V3(0, 1.5, 0), { color = P.time, size = radius * 0.4, flash = 0.32, stop = 0.12, caster = p.caster, fov = -4, sparks = 12, ground = center })
		Fx.tint(center, { color = C("#BFEFFF"), time = math.min(duration, 3), attack = 0.12, amount = 0.4, saturation = -0.5, contrast = 0.1 })
		Fx.motes(center + V3(0, 1, 0), { color = P.timeCore, area = radius * 1.2, time = duration, rate = 10, speed = { 0, 0.2 }, accel = V3(0, 0, 0), life = { 2, 3 } })
		Fx.sfx("fxTimeFreeze", center)
	end,
	-- Удар: время трескается — стеклянные осколки, рябь, колокол.
	strike = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local radius = p.radius or s.radius or 10
		Fx.heroFrame(center + V3(0, 1.5, 0), { color = P.timeCore, size = radius * 0.5, flash = 0.42, stop = 0.12, caster = p.caster, fov = 7, sparks = 26, ground = center })
		Fx.debris(center + V3(0, 2, 0), { count = 20, color = C("#CFF6FF"), material = Enum.Material.Glass, shard = true, size = 0.6, speed = radius * 1.6, up = 18, transparency = 0.35, time = 3, groundY = center.Y })
		Fx.ripples(center, { time = 2.5, count = 5, radius = radius * 0.6, size = radius * 0.5, color = P.time })
		Fx.sfx("fxTimeStrike", center)
		Fx.sfx("fxTimeTail", center)
	end,
}

-- ===== Линия судьбы =====
H.fate_line = {
	-- Вспышка строки: кадр, выжженная полоса, пепел, угли.
	ignite = function(p)
		local origin = vec(p.origin)
		if not origin then
			return
		end
		local dir = Kit.flatUnit(vec(p.dir, V3(0, 0, -1)))
		local length = p.length or 20
		local half = p.halfWidth or 1.8
		local ground = G(origin)
		Fx.heroFrame(ground + dir * length * 0.5 + V3(0, 1.4, 0), { color = P.gold, size = 5, flash = 0.28, stop = 0.1, caster = p.caster, fov = 5, ring = false })
		Fx.seamPath(ground, dir, length, { hot = C("#FFE2A0"), cool = C("#3A1A0A"), life = 4, width = half * 0.6, jitter = 0.15 })
		for i, point in ipairs(along(ground, dir, length, 4)) do
			Fx.scorch(point, half * 1.2, { life = 5, hot = P.gold, glow = 1.5, transparency = 0.35 })
			if i % 2 == 1 then
				Fx.flutter(point + V3(0, 2, 0), { kind = "ash", count = 4, up = 3, speed = 2, time = 4.5, groundY = point.Y })
				Fx.embers(point, { time = 2.5, rate = 6, area = V3(2, 0.3, 2) })
			end
		end
		Fx.sfx("fxFateIgnite", ground + dir * length * 0.5)
		Fx.sfx("fxFateTail", ground + dir * length * 0.5, nil, 0.3)
	end,
}

-- ===== Чернильная дыра =====
H.ink_hole = {
	open = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local radius = p.radius or 6
		local pullTime = math.max(p.pullTime or 1.5, 0.3)
		s.center = center
		Fx.inward(center + V3(0, 1, 0), radius * 1.2, { color = P.ink, count = 40, time = pullTime, speed = radius * 1.5, streak = true })
		Fx.sfx("fxInkOpen", center)
	end,
	-- Выброс: кадр, чернильные брызги, кляксы на земле испаряются.
	blast = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local radius = p.radius or 6
		Fx.heroFrame(center + V3(0, 1.2, 0), { color = P.inkCore, size = radius * 0.6, flash = 0.28, stop = 0.1, caster = p.caster, fov = 6, ground = center })
		Fx.drops(center, { count = 20, color = P.ink, speed = radius * 1.6, up = 20, time = 2, groundY = center.Y })
		for _ = 1, 6 do
			local a = math.random() * TAU
			local d = rnd(0.3, 1) * radius
			local spot = center + V3(math.cos(a) * d, 0, math.sin(a) * d)
			Fx.scorch(spot, rnd(0.8, 1.6), { color = P.inkDark, hot = P.ink, cool = P.inkDark, glow = 1, life = 4.5, transparency = 0.2 })
			Kit.after(rnd(2.2, 3), function()
				Fx.smoke(spot + V3(0, 0.3, 0), { color = P.inkCore, radius = 0.8, count = 3, lightEmission = 0.3, life = { 1, 1.6 } })
			end)
		end
		Fx.sfx("fxInkBlast", center)
		Fx.sfx("fxInkTail", center, nil, 0.5)
	end,
}

-- ===== Полное воспоминание =====
H.total_recall = {
	cast = function(p, s)
		local center = centerOf(p, s)
		if center then
			s.center = center
		end
	end,
	beams = function(p)
		local list = p.beams
		if type(list) ~= "table" then
			return
		end
		local first = nil
		for _, beam in ipairs(list) do
			local from = vec(beam.from)
			local dir = vec(beam.dir)
			if from and dir then
				local tip = from + Kit.flatUnit(dir) * (beam.length or 14)
				first = first or tip
				Fx.sparks(tip, { color = P.memory, count = 6, speed = { 5, 10 } })
			end
		end
		if first then
			Fx.sfx("fxRecallBeams", first, 0.8)
		end
	end,
	-- Шторм памяти: кадр, кубики памяти парят и распадаются, свет гаснет.
	storm = function(p, s)
		local center = centerOf(p, s)
		if not center then
			return
		end
		local radius = p.radius or 8
		Fx.heroFrame(center + V3(0, 1.5, 0), { color = P.memory, size = radius * 0.5, flash = 0.32, stop = 0.1, caster = p.caster, fov = 6, ground = center })
		Fx.cubes(center, { count = 16, colors = { P.memory, P.memoryAlt, WHITE }, radius = radius * 0.8, height = 3, time = 3 })
		Fx.motes(center + V3(0, 1, 0), { color = P.memoryAlt, area = radius, time = 2.5, rate = 10 })
		Fx.afterglow(center + V3(0, 1.5, 0), { color = P.memory, time = 3, brightness = 4, range = radius * 2 })
		Fx.sfx("fxRecallStorm", center)
		Fx.sfx("fxRecallTail", center, nil, 0.3)
	end,
}

-- Не трогаем: «Призрачная стая» и «Последняя охота» остаются как были.
Plus.UNCHANGED = { spirit_pack = true, royal_hunt = true, mycelium = true }
Plus.HANDLERS = H

function Plus.handle(payload, ctx)
	local spell = H[payload.id]
	local handler = spell and spell[payload.phase]
	if not handler then
		return
	end
	ctx = ctx or {}
	ctx.plus = ctx.plus or {}
	local ok, err = pcall(handler, payload, ctx.plus, ctx)
	if not ok then
		warn(("[MageSpellFxPlus] %s.%s: %s"):format(tostring(payload.id), tostring(payload.phase), tostring(err)))
	end
end

return Plus
