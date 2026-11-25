--!nonstrict
-- AbilityFxPlus (клиент)
-- Продлённые фазы способностей воина поверх AbilityFx / AbilityFxGarden (шаблоны FX не
-- меняются): по pixelfx — предвкушение, белый кадр удара с hit-stop, разлёт, «висение»
-- (искры, угли), распад и долгий хвост 2–4 с, плюс звуки (Config/SfxSkills).
-- Геймплей и сервер не трогаем: те же события AbilityFx { kind, phase, ... }.
-- Вызывается из AbilityFx.onEvent после основного обработчика.

local Fx = require(script.Parent.Parent.Lib.FxAfter)
local Kit = Fx.Kit

local AbilityFxPlus = {}

local V3 = Vector3.new
local UP = V3(0, 1, 0)
local TAU = math.pi * 2
local C = Fx.C
local rnd = Fx.rnd
local FEET = 3

local COL = {
	wind = C("#CFF6FF"), windDeep = C("#6FD3E8"), dust = C("#A8957A"),
	rock = C("#6B5A4C"), rockDark = C("#3E342C"), magma = C("#FF5A1F"), magmaHot = C("#FFE6A0"), magmaCool = C("#5A140A"),
	gold = C("#FFD45A"), goldCore = C("#FFF4C8"), chain = C("#B9A27A"),
	reap = C("#5FD0C0"), reapCore = C("#B8F2E6"), reapDark = C("#1E5A52"), rot = C("#8EE04A"), rotDark = C("#3E5A22"),
	water = C("#5FD0C0"), waterLight = C("#BFF6EE"), wet = C("#1E2A2E"),
	prune = C("#9BE36A"), pruneCore = C("#EAFFD6"), twig = C("#6B4A2E"),
	bloom = C("#FF8FD0"), bloomCore = C("#FFF2FB"), thornDark = C("#2F6B2A"),
}
AbilityFxPlus.COLORS = COL

local function G(position: Vector3, lift: number?): Vector3
	return Kit.ground(position, lift or 0.06)
end

local function rootOf(caster)
	local _, root = Kit.characterOf(caster)
	return root
end

local function partOf(model)
	if typeof(model) ~= "Instance" then
		return nil
	end
	if model:IsA("BasePart") then
		return model
	end
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

local function flat(direction, fallback)
	if typeof(direction) ~= "Vector3" then
		return fallback or V3(0, 0, -1)
	end
	return Kit.flatUnit(direction, fallback)
end

local states = {} -- [caster] = { rift = {...}, unlock = {...} }
local function stateOf(caster)
	local key = caster or "?"
	states[key] = states[key] or {}
	return states[key]
end

local H = {}

-- ===== Вихрь =====

H.vortex = {
	-- Предвкушение: ветер втягивается к ногам, кольцо пыли сжимается, ленты по спирали.
	start = function(p)
		local root = rootOf(p.caster)
		if not root then
			return
		end
		local castTime = math.max(p.castTime or 1, 0.3)
		local radius = p.radius or 5.5
		local feet = G(root.Position - V3(0, FEET, 0))
		Fx.inward(feet + V3(0, 1.2, 0), radius * 1.3, { color = COL.wind, count = 46, time = castTime * 0.9, speed = radius * 1.6, streak = true, size = { 0.35, 0.15 } })
		Fx.collapse(feet, radius * 1.35, COL.windDeep, { time = castTime, image = "swirl", pop = false })
		Fx.wisps(feet, { count = 4, color = COL.wind, radius = radius * 0.6, rise = 1.1, time = castTime + 0.3, spin = 6, both = true, size = 0.22 })
		Fx.sfx("fxVortexSuck", feet)
	end,
	tick = function(p)
		if typeof(p.position) ~= "Vector3" or (p.hits or 0) <= 0 then
			return
		end
		Fx.dust(G(p.position), { radius = 1.8, dirs = 5, count = 2 })
	end,
	-- Выброс: белый кадр, пылевое кольцо, обломки; хвост — ленты вверх, след-воронка, листья, дымка.
	wave = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 7
		local ground = G(p.position)
		Fx.heroFrame(ground + V3(0, 1.5, 0), { color = COL.wind, size = radius * 0.8, flash = 0.22, stop = 0.08, caster = p.caster, fov = 5, ground = ground })
		Fx.dust(ground, { radius = radius * 0.8, dirs = 10, count = 3, color = COL.dust })
		Fx.debris(ground, { count = 10, color = COL.rock, size = 0.45, speed = radius * 2.4, up = 16, time = 3 })
		Fx.wisps(ground, { count = 6, color = COL.wind, radius = radius * 0.5, rise = 4.5, time = 2.4, spin = 7, size = 0.26 })
		Fx.sigil(ground, radius * 0.9, COL.windDeep, { image = "swirl", time = 3, spin = -140, transparency = 0.45, grow = 0.1 })
		Fx.flutter(ground + V3(0, 1, 0), { kind = "leaf", count = 9, radius = radius * 0.6, up = 10, speed = 7, time = 5 })
		Fx.mist(ground, { radius = radius * 0.7, time = 2.6, color = C("#D8CDBA"), rate = 4 })
		Fx.sfx("fxVortexWave", ground)
		Fx.sfx("fxVortexTail", ground)
	end,
}

-- ===== Разлом =====

H.rift = {
	-- Удар: кадр, камни, кратер; до выброса земля дрожит и подкидывает камешки.
	slam = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 6
		local ground = G(p.position)
		local wait = (p.crackTime or 0.4) + (p.eruptDelay or 0.6)
		Fx.heroFrame(ground + V3(0, 1, 0), { color = COL.magma, size = radius * 0.7, flash = 0.28, stop = 0.1, caster = p.caster, fov = 6, sparks = 18, ground = ground })
		Fx.debris(ground, { count = 12, color = COL.rock, size = 0.7, speed = 14, up = 20, time = 3 })
		Fx.dust(ground, { radius = radius * 0.9, dirs = 10, count = 3, color = COL.dust })
		Fx.scorch(ground, radius * 0.55, { life = wait + 4.5, hot = COL.magma, cool = COL.magmaCool, glow = wait + 0.8 })
		local cracks = {}
		for _, crack in ipairs(p.cracks or {}) do
			if typeof(crack.direction) == "Vector3" then
				table.insert(cracks, { dir = flat(crack.direction), length = crack.length or 6 })
			end
		end
		local st = stateOf(p.caster)
		local rift = { ground = ground, cracks = cracks, alive = true }
		st.rift = rift
		Fx.sfx("fxRiftSlam", ground)
		Fx.sfx("fxRiftRumble", ground, nil, 0.25)
		local nextAt = 0.2
		Kit.every(wait, function(_, t)
			if not rift.alive then
				return false
			end
			if t >= nextAt and #cracks > 0 then
				nextAt = t + 0.12
				local crack = cracks[math.random(#cracks)]
				local point = ground + crack.dir * crack.length * rnd(0.2, 1)
				Kit.burst(point + V3(0, 0.2, 0), { texture = "rock", color = COL.rock, count = 3, size = { 0.35, 0.2 }, speed = { 4, 8 },
					accel = V3(0, -40, 0), spread = 25, life = { 0.4, 0.7 }, lightEmission = 0, lightInfluence = 1, direction = Enum.NormalId.Top })
				Kit.shake(ground, 0.06, 0.12)
			end
			return true
		end)
	end,
	-- Выброс: кадр, остывающие швы трещин, раскалённые обломки, дым, угли; шипы стоят и рассыпаются.
	erupt = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local st = stateOf(p.caster)
		local rift = st.rift
		st.rift = nil
		if rift then
			rift.alive = false
		end
		local ground = rift and rift.ground or G(p.position)
		local cracks = rift and rift.cracks or {}
		if #cracks == 0 then
			for _, crack in ipairs(p.cracks or {}) do
				if typeof(crack.direction) == "Vector3" then
					table.insert(cracks, { dir = flat(crack.direction), length = crack.length or 6 })
				end
			end
		end
		Fx.heroFrame(ground + V3(0, 1, 0), { color = COL.magmaHot, size = 6, flash = 0.34, stop = 0.12, caster = p.caster, fov = 7, shake = 0.3, ground = ground })
		for i, crack in ipairs(cracks) do
			Fx.seamPath(ground, crack.dir, crack.length, { hot = COL.magmaHot, cool = COL.magmaCool, life = 3.2, width = 0.45, jitter = 0.5 })
			local mid = ground + crack.dir * crack.length * 0.6
			Fx.debris(mid, { count = 4, hot = COL.magmaHot, color = COL.rockDark, size = 0.5, speed = 6, up = 22, time = 3, dir = crack.dir })
			if i <= 4 then
				Fx.embers(mid, { time = 3, rate = 9, area = V3(2, 0.3, 2) })
			end
		end
		Fx.plume(ground, { time = 3, rate = 10, radius = 2 })
		Fx.afterglow(ground + V3(0, 1, 0), { color = COL.magma, time = 3.5, brightness = 5, range = 22 })
		Fx.sfx("fxRiftErupt", ground)
		Fx.sfx("fxRiftTail", ground, nil, 0.25)
		-- Шипы (AbilityFx.spike) держатся ~1,4 с и рассыпаются — звук осыпи.
		Fx.sfx("fxSpikeCrumble", ground, nil, 1.4)
	end,
}

-- Шип рассыпается (вызывает AbilityFx.spike): обломки, пыль.
function AbilityFxPlus.spikeCrumble(position: Vector3, height: number, color: Color3?)
	local base = G(position)
	local center = base + V3(0, height * 0.45, 0)
	Fx.debris(center, { count = 4, color = color or COL.rock, size = 0.6, speed = 5, up = 7, radius = 0.6, time = 2.2, groundY = base.Y })
	Fx.smoke(base + V3(0, 0.6, 0), { color = COL.dust, radius = 1, count = 3, life = { 0.9, 1.6 } })
end

-- ===== Отпереть / скважина =====

H.unlock = {
	-- Блик броска, пыль и камешки при втыкании.
	throw = function(p)
		if typeof(p.from) ~= "Vector3" or typeof(p.target) ~= "Vector3" then
			return
		end
		local flight = p.flightTime or 0.5
		Kit.flash(p.from, COL.goldCore, 1.6, 0.15)
		Fx.sparks(p.from, { color = COL.gold, count = 8, speed = { 6, 12 } })
		Fx.sfx("fxKeyGlint", p.from)
		local target = p.target
		Kit.after(flight, function()
			local ground = G(target)
			Fx.dust(ground, { radius = 2.4, dirs = 6, count = 2, color = COL.dust })
			Fx.debris(ground, { count = 5, color = COL.rock, size = 0.4, speed = 8, up = 12, time = 2.4 })
			Fx.sparks(ground + V3(0, 0.5, 0), { color = COL.gold, count = 10, speed = { 8, 16 } })
		end)
	end,
	-- Щелчок замка: мини-кадр, печать проявляется на время связывания.
	lock = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 10
		local bindTime = p.bindTime or 1
		local ground = G(p.position)
		Fx.heroFrame(ground + V3(0, 1, 0), { color = COL.gold, size = 3, stop = 0.06, caster = p.caster, sparks = 10, ground = ground })
		Fx.sigil(ground, radius * 0.6, COL.gold, { image = "seal", time = bindTime + 0.4, spin = -30, transparency = 0.45, grow = 0.05 })
		for _, model in ipairs(p.targets or {}) do
			local part = partOf(model)
			if part then
				Fx.sparks(part.Position, { color = COL.gold, count = 6, speed = { 4, 9 } })
			end
		end
		Fx.sfx("fxKeyLock", ground)
	end,
	-- Цепи рвутся: белый кадр, звенья разлетаются, искры; хвост — призрак печати, золотая пыль, звон ключа.
	open = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 10
		local ground = G(p.position)
		Fx.heroFrame(ground + V3(0, 1.2, 0), { color = COL.gold, size = radius * 0.6, flash = 0.38, stop = 0.12, caster = p.caster, fov = 7, sparks = 24, ground = ground })
		Fx.debris(ground + V3(0, 1.5, 0), { count = 14, color = COL.chain, material = Enum.Material.Metal, size = 0.42, speed = radius * 2, up = 18, time = 3 })
		Fx.sigil(ground, radius * 0.9, COL.gold, { image = "seal", time = 2.8, spin = 25, grow = 0.25, transparency = 0.35 })
		Fx.motes(ground + V3(0, 1, 0), { color = COL.gold, area = radius, time = 3, rate = 14 })
		Fx.afterglow(ground + V3(0, 1.5, 0), { color = COL.gold, time = 3, brightness = 4, range = radius * 2 })
		Fx.sfx("fxKeyOpen", ground)
		Fx.sfx("fxKeyTail", ground)
	end,
}

H.keyhole = {
	burst = function(p)
		local part = partOf(p.model)
		local position = part and part.Position or p.position
		if typeof(position) ~= "Vector3" then
			return
		end
		local height = (part and p.model:GetAttribute("EnemyHeight")) or 5
		local hit = position + V3(0, height * 0.15, 0)
		Fx.heroFrame(hit, { color = COL.gold, size = 3.5, flash = 0.12, stop = 0.06, caster = p.caster, sparks = 14, ring = false })
		Fx.sigil(G(position), 2, COL.gold, { image = "keyhole", time = 1.4, spin = 0, grow = 0.4, transparency = 0.2 })
		Fx.motes(hit, { color = COL.goldCore, area = 2, time = 1.4, rate = 10 })
		Fx.sfx("fxKeyhole", hit)
	end,
}

-- ===== Сады: жатва, гниль, паводок, обрезка, шипы, цветение =====

H.garden = {
	-- Жатва: кадр, светящийся шрам по пути волны, срезанная трава, рассеивание в конце.
	reapStart = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local dir = flat(p.direction)
		local length = p.length or 14
		local waveTime = p.waveTime or 0.5
		local ground = G(p.position)
		local origin = ground + V3(0, 1.2, 0)
		Fx.heroFrame(origin + dir * 1.5, { color = COL.reap, size = 4, flash = 0.15, stop = 0.07, caster = p.caster, sparks = 12, ground = ground })
		Fx.seamPath(ground + dir * 1.5, dir, length - 1.5, { hot = COL.reapCore, cool = COL.reapDark, life = 2.8, width = 0.5, reveal = waveTime, jitter = 0.3 })
		local n = math.clamp(math.floor(length / 3), 2, 6)
		for i = 1, n do
			local k = i / n
			Kit.after(waveTime * k, function()
				Fx.flutter(ground + dir * length * k + V3(0, 0.4, 0), { kind = "grass", count = 3, up = 6, speed = 3, radius = 1, time = 3.5 })
			end)
		end
		Kit.after(waveTime, function()
			local tip = ground + dir * length + V3(0, 1, 0)
			Fx.smoke(tip, { color = COL.reapCore, radius = 1.5, count = 6, lightEmission = 0.6, life = { 0.8, 1.6 } })
			Fx.motes(tip, { color = COL.reapCore, area = 2.5, time = 1.6, rate = 10 })
			Fx.sfx("fxReapTail", tip)
		end)
		Fx.sfx("fxReap", origin)
	end,
	reapHit = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		Fx.sparks(p.position + V3(0, 2, 0), { color = COL.reapCore, count = 10, speed = { 8, 16 } })
	end,
	-- Гниль: в конце действия — облачко спор и пузыри гаснут.
	rot = function(p)
		local part = partOf(p.model)
		if not part then
			return
		end
		local last = part.Position
		Kit.after(p.duration or 3, function()
			local now = partOf(p.model)
			local position = now and now.Parent and now.Position or last
			Fx.smoke(position, { color = COL.rotDark, radius = 1.2, count = 6, lightEmission = 0.3, life = { 1, 1.8 } })
			Fx.motes(position, { color = COL.rot, texture = "glow", area = 2, time = 1.6, rate = 8, size = { 0.15, 0.3, 0 } })
			Fx.sfx("fxRotTail", position, 0.8)
		end)
	end,
	-- Паводок: кадр, брызги, дождь капель за волной.
	floodSlam = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 9
		local dir = flat(p.direction)
		local ground = G(p.position)
		Fx.heroFrame(ground + V3(0, 1, 0), { color = COL.waterLight, size = radius * 0.6, flash = 0.22, stop = 0.1, caster = p.caster, fov = 6, ground = ground })
		Fx.drops(ground, { count = 18, color = COL.waterLight, speed = radius * 1.5, up = 22, time = 2 })
		for i = 1, 4 do
			Kit.after(0.1 * i, function()
				Fx.drops(ground + dir * radius * i / 4, { count = 5, color = COL.waterLight, speed = 4, up = 10, time = 1.6, rings = 3 })
			end)
		end
		Fx.sfx("fxFloodSlam", ground)
	end,
	-- Лужа: рябь и дымка над водой.
	floodPuddle = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 6
		local time = p.time or 3
		local ground = G(p.position)
		Fx.ripples(ground, { time = time, count = math.clamp(math.floor(time * 2.5), 3, 14), radius = radius * 0.8, size = radius * 0.25, color = COL.waterLight })
		Fx.mist(ground, { radius = radius * 0.6, time = time, color = C("#CFF4EE"), rate = 3 })
		Fx.sfx("fxFloodTail", ground)
	end,
	-- Слив: кольцо внутрь, пар, мокрое пятно сохнет.
	floodEnd = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 6
		local ground = G(p.position)
		Fx.collapse(ground, radius, COL.waterLight, { time = 0.8 })
		Fx.smoke(ground + V3(0, 0.5, 0), { color = C("#E8F4F4"), radius = radius * 0.4, count = 8, lightInfluence = 0.5, accel = V3(0, 4, 0) })
		Fx.scorch(ground, radius * 0.8, { color = COL.wet, edge = false, life = 4, transparency = 0.55 })
		Fx.sfx("fxFloodDrain", ground)
	end,
	-- Обрезка: на втором срезе «X» закрывается — вспышка, висящий крест, листья, веточки.
	pruneCut = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local dir = flat(p.direction)
		local radius = p.radius or 5
		local right = V3(-dir.Z, 0, dir.X)
		local center = p.position + V3(0, 2.1, 0) + dir * 2
		for _, model in ipairs(p.targets or {}) do
			local part = partOf(model)
			if part then
				Fx.sparks(part.Position, { color = COL.pruneCore, count = 6, speed = { 6, 12 } })
			end
		end
		if (p.index or 1) == 1 then
			Fx.slashMark(center, right + UP * 0.53, radius * 0.9, COL.prune, { time = 0.6, width = 0.18 })
			return
		end
		Fx.heroFrame(center, { color = COL.pruneCore, size = 4, flash = 0.2, stop = 0.09, caster = p.caster, ring = false, sparks = 16 })
		Fx.slashMark(center, right + UP * 0.53, radius * 0.9, COL.prune, { time = 1, width = 0.22 })
		Fx.slashMark(center, right - UP * 0.53, radius * 0.9, COL.prune, { time = 1, width = 0.22 })
		Fx.flutter(center, { kind = "leaf", count = 10, radius = 1.5, up = 6, speed = 6, time = 4.5 })
		Fx.debris(center, { count = 5, color = COL.twig, material = Enum.Material.Wood, shard = true, size = 0.5, speed = 8, up = 10, time = 2.8 })
		Fx.sfx("fxPruneX", center)
		Fx.sfx("fxPruneTail", center, nil, 0.15)
	end,
	thorn = function(p)
		local part = partOf(p.model)
		local position = part and part.Position or p.position
		if typeof(position) ~= "Vector3" then
			return
		end
		Fx.debris(position, { count = 3, color = COL.thornDark, shard = true, size = 0.4, speed = 6, up = 8, time = 2 })
		Fx.sparks(position, { color = COL.prune, count = 6, speed = { 5, 10 } })
	end,
	-- Цветение: лепестки летят и ложатся, пыльца мерцает.
	bloom = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 4
		local ground = G(p.position)
		Fx.heroFrame(ground + V3(0, 1.2, 0), { color = COL.bloom, size = math.max(3, radius * 0.6), flash = 0.15, stop = 0.06, caster = p.caster, ground = ground })
		Fx.flutter(ground + V3(0, 1.5, 0), { kind = "petal", count = 14, radius = radius * 0.5, up = 8, speed = 5, time = 5.5 })
		Fx.motes(ground + V3(0, 1, 0), { color = COL.bloomCore, area = radius, time = 2.5, rate = 10 })
		Fx.sfx("fxBloom", ground)
		Fx.sfx("fxBloomTail", ground, nil, 0.4)
	end,
}

-- ===== Этажи 3–5: Охота, Литейные, Архив Хроник =====
-- Свои модули (AbilityFxPlusHunt / Forge / Chronicle) со своими kind: hunt, forge, chron.
local EXTRA = { "AbilityFxPlusHunt", "AbilityFxPlusForge", "AbilityFxPlusChronicle" }
local extras = {}
for _, name in ipairs(EXTRA) do
	local module = script.Parent:FindFirstChild(name)
	if module then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			table.insert(extras, result)
			for kind, set in pairs(result.handlers or {}) do
				H[kind] = set
			end
		else
			warn("[AbilityFxPlus] " .. name .. ": " .. tostring(result))
		end
	end
end

AbilityFxPlus.HANDLERS = H

function AbilityFxPlus.onEvent(payload)
	if type(payload) ~= "table" then
		return
	end
	local set = H[payload.kind]
	local handler = set and set[payload.phase]
	if not handler then
		return
	end
	local ok, err = pcall(handler, payload)
	if not ok then
		warn("[AbilityFxPlus] " .. tostring(payload.kind) .. "/" .. tostring(payload.phase) .. ": " .. tostring(err))
	end
end

-- Игрок вышел — забыть его состояние.
function AbilityFxPlus.forget(caster)
	local st = states[caster]
	if st and st.rift then
		st.rift.alive = false
	end
	states[caster] = nil
	for _, extra in ipairs(extras) do
		if type(extra.forget) == "function" then
			pcall(extra.forget, caster)
		end
	end
end

return AbilityFxPlus
