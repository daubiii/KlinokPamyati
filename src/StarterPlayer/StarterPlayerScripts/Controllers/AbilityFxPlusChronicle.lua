--!nonstrict
-- AbilityFxPlusChronicle (клиент)
-- Продлённые фазы оружия этажа 5 «Архив Хроник» (kind = "chron") поверх AbilityFxChronicle, как
-- AbilityFxPlus для этажей 1–2: предвкушение, белый кадр удара с hit-stop, разлёт (стекло времени,
-- страницы, чернила, кубики памяти), «висение» (буквы, цифры циферблата, пылинки) и хвост 2–4 с,
-- плюс звуки fxChron* (Config/SfxSkills). Сервер, урон и шаблоны FX.Chron не трогаем.
-- Подключается из AbilityFxPlus (handlers), вызывается после основного обработчика.

local P = require(script.Parent.AbilityFxPlus345Kit)
local Fx = P.Fx
local Kit = P.Kit

local AbilityFxPlusChronicle = {}

local V3 = Vector3.new
local UP = V3(0, 1, 0)
local C = Fx.C
local rnd = Fx.rnd
local G, partOf, posOf, flat, groundUnder, rootOf, followRing = P.G, P.partOf, P.posOf, P.flat, P.groundUnder, P.rootOf, P.followRing

-- Палитра AbilityFxChronicle (VIOLET / LAVENDER / ICE / INK / BRASS / MEMORY / WHITE) + бумага.
local COL = {
	violet = C("#9B7BFF"), lavender = C("#B49CFF"), ice = C("#B8E3FF"), ink = C("#1D1B3A"), inkLight = C("#3B356E"),
	brass = C("#D6B467"), memory = C("#6FE3FF"), white = C("#F2F6FF"), paper = C("#EFE6CC"), dust = C("#C9C0D8"),
}
AbilityFxPlusChronicle.COLORS = COL

-- [caster] = { line = { count }, dome = { circle }, recall = { combos, echoes, offset, circle } }
local stateOf, states = P.states()
local once = P.limiter(0.3)

-- Брызги чернил веером (частицы).
local function inkSpray(origin: Vector3, dir: Vector3, spread: number, count: number, speed: number)
	Kit.burst(CFrame.lookAt(origin, origin + dir), { texture = "glow", color = { COL.inkLight, COL.violet }, count = count, size = { 0.6, 0 },
		life = { 0.4, 0.8 }, speed = { speed * 0.5, speed }, spread = spread, direction = Enum.NormalId.Front, accel = V3(0, -30, 0), drag = 2,
		brightness = 1.5, lightEmission = 0.3 })
end

-- Клякса: тёмное пятно с фиолетовой кромкой, кромка гаснет в чернила.
local function blot(at: Vector3, r: number, life: number)
	Fx.scorch(at, r, { color = COL.ink, hot = COL.violet, cool = COL.ink, glow = 1, life = life, transparency = 0.15 })
end

local function echoSides(echoes: number)
	if echoes <= 1 then
		return { 1 }
	elseif echoes == 2 then
		return { -1, 1 }
	end
	return { -1, 1, 0 }
end

local H = {}

H.chron = {
	-- ===== Строка =====
	-- Перо пишет: светящаяся строка проступает за пером, под пером брызжут чернила, над рунами
	-- поднимаются буквы.
	inscribeWrite = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local origin = G(p.position)
		local dir = flat(p.direction)
		local length = p.length or 14
		local writeTime = math.max(p.writeTime or 0.45, 0.1)
		local runes = p.runes or {}
		local hold = writeTime + (p.detonateDelay or 0.35) + (p.interval or 0.07) * #runes
		stateOf(p.caster).line = { count = #runes }
		Fx.seamPath(origin + dir * 0.6, dir, length - 0.6, { hot = COL.lavender, cool = COL.ink, life = hold + 1.2, width = 0.22, reveal = writeTime, jitter = 0.12 })
		local nextAt = 0
		Kit.every(writeTime, function(k, t)
			if t >= nextAt then
				nextAt = t + 0.06
				local at = origin + dir * length * k + V3(0, 0.3, 0)
				Kit.burst(at, { texture = "glow", color = { COL.violet, COL.inkLight }, count = 2, size = { 0.35, 0 }, life = { 0.3, 0.6 },
					speed = { 1, 3 }, accel = V3(0, -6, 0), spread = 90, brightness = 2 })
			end
			return true
		end)
		for i, point in ipairs(runes) do
			if typeof(point) == "Vector3" then
				Kit.after(writeTime * (i - 0.5) / math.max(1, #runes), function()
					Fx.glyphs(G(point) + V3(0, 0.4, 0), { count = 1, color = COL.lavender, radius = 0.3, time = 1.1, rise = 0.4, size = 1 })
				end)
			end
		end
		Fx.sfx("fxChronScribe", origin)
	end,
	-- Руна рвётся: мини-кадр (первая — со стоп-кадром), клякса, буквы; последняя — страницы, пылинки, свет.
	runeBurst = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 2.5
		local index = p.index or 1
		local st = stateOf(p.caster)
		local count = st.line and st.line.count or index
		local ground = G(p.position)
		Fx.heroFrame(ground + V3(0, 0.8, 0), { color = COL.violet, size = radius * 1.1, flash = index == 1 and 0.1 or 0, stop = index == 1 and 0.05 or 0,
			caster = p.caster, sparks = 8, ground = ground })
		blot(ground, radius * 0.6, 3.5)
		Fx.glyphs(ground + V3(0, 0.6, 0), { count = 2, color = COL.lavender, radius = radius * 0.4, time = 1.6, rise = 1.2, size = 1.1 })
		inkSpray(ground + V3(0, 0.3, 0), UP, 50, 8, 10)
		if index >= count then
			st.line = nil
			Fx.flutter(ground + V3(0, 1, 0), { kind = "page", count = 4, radius = 1, up = 8, speed = 4, time = 4.5 })
			Fx.motes(ground + V3(0, 1, 0), { color = COL.lavender, area = 3, time = 2.4, rate = 10 })
			Fx.afterglow(ground + V3(0, 1, 0), { color = COL.violet, time = 2.2, brightness = 3, range = 14 })
			Fx.sfx("fxChronRuneTail", ground)
		end
	end,

	-- ===== Опечатать =====
	-- Печать: кадр со стоп-кадром, латунный циферблат с остановленными стрелками на всё время
	-- заморозки (в конце вздрагивает и гаснет), страницы, на пойманных — иней-кубики.
	sealStamp = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 8
		local freeze = p.freeze or 2.5
		local ground = G(p.position)
		local targets = p.targets or {}
		Fx.heroFrame(ground + V3(0, 1.2, 0), { color = COL.brass, size = radius * 0.7, flash = 0.3, stop = 0.12, caster = p.caster, fov = 6, shake = 0.3, sparks = 20, ground = ground })
		local circle = Kit.circle(ground, radius * 0.85, COL.brass, { roman = true, ticks = 12, hexagram = false, spin = 0, innerSpin = 0, duration = freeze, appear = 0.2 })
		-- Время снова идёт: циферблат вздрагивает перед тем, как погаснуть.
		Kit.after(math.max(freeze - 0.3, 0.1), function()
			if circle and circle.alive then
				circle.pulse(0.1)
			end
		end)
		Fx.dust(ground, { radius = radius * 0.7, dirs = 10, count = 2, color = COL.dust })
		Fx.flutter(ground + V3(0, 0.8, 0), { kind = "page", count = 6, radius = radius * 0.35, up = 7, speed = 5, time = 4.5 })
		for i, model in ipairs(targets) do
			local part = partOf(model)
			if part and i <= 6 then
				Fx.cubes(part.Position, { count = 3, colors = { COL.ice, COL.white }, size = 0.35, radius = 1.2, height = 1.5, speed = 0.6, time = freeze })
				Fx.sparks(part.Position, { color = COL.ice, count = 6, speed = { 4, 8 } })
			end
		end
		if #targets > 0 then
			Fx.tint(ground, { color = COL.ice, amount = 0.15, time = math.min(freeze, 2), saturation = -0.2, range = radius + 10 })
			Fx.sfx("fxChronFreezeTail", ground, nil, 0.2)
		end
		Fx.sfx("fxChronStamp", ground)
	end,
	-- Заморозка спала: стеклянные осколки времени, искры, щелчок.
	sealBreak = function(p)
		local at = posOf(p.model, p.position)
		if not at then
			return
		end
		Fx.debris(at + V3(0, 0.6, 0), { count = 6, color = COL.ice, material = Enum.Material.Glass, transparency = 0.35, shard = true, size = 0.4, speed = 8, up = 10, time = 2.4,
			groundY = groundUnder(p.model, at).Y })
		Fx.sparks(at, { color = COL.white, count = 10, speed = { 6, 12 } })
		Kit.ringWave(groundUnder(p.model, at, 0.12), 1.8, COL.ice, { time = 0.4, brightness = 3 })
		if once(p.caster or "?") then
			Fx.sfx("fxChronShatter", at)
		end
	end,

	-- ===== Безвременье =====
	-- Купол: воздух втягивается, на земле — большой циферблат, висят пылинки и цифры, каждую секунду
	-- проходит рябь, экран блёкнет.
	domeStart = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 11.5
		local duration = math.max(p.duration or 3, 0.5)
		local center = G(p.position)
		local st = stateOf(p.caster)
		Fx.inward(center + V3(0, 1.5, 0), radius, { color = COL.lavender, count = 36, time = 0.4, speed = radius * 3, streak = true, size = { 0.35, 0.1 } })
		local circle = Kit.circle(center, radius * 0.92, COL.violet, { roman = true, ticks = 12, spin = 8, innerSpin = -14, duration = duration, appear = 0.35 })
		st.dome = { circle = circle }
		Fx.motes(center + V3(0, 2, 0), { color = COL.ice, area = radius * 0.8, time = duration, rate = 8 })
		Fx.glyphs(center + V3(0, 1.2, 0), { letters = Kit.ROMAN, count = 6, color = COL.brass, radius = radius * 0.7, time = duration, rise = 0.15, size = 1.4 })
		Fx.ripples(center, { time = duration, count = math.max(2, math.floor(duration)), radius = radius * 0.3, size = radius * 0.6, color = COL.lavender, transparency = 0.55, ringTime = 1.1 })
		Fx.tint(center, { color = COL.lavender, amount = 0.15, time = duration, attack = 0.3, saturation = -0.25, range = radius + 8 })
		for i = 1, math.floor(duration) do
			Kit.after(i, function()
				if st.dome and st.dome.circle == circle and circle.alive then
					circle.pulse(0.03)
				end
			end)
		end
		Fx.sfx("fxChronDomeHum", center)
	end,
	-- Схлопывание: всё втягивается к центру, белый кадр, стёкла купола сыплются, кубики памяти,
	-- цифры улетают вверх, печать расходится, долгий фиолетовый свет и дымка.
	domeCollapse = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 11.5
		local center = G(p.position)
		local st = stateOf(p.caster)
		local dome = st.dome
		st.dome = nil
		if dome and dome.circle and dome.circle.alive then
			dome.circle.fade(0.25)
		end
		Fx.inward(center + V3(0, radius * 0.4, 0), radius, { color = COL.lavender, count = 40, time = 0.22, speed = radius * 4, streak = true })
		local caster = p.caster
		Kit.after(0.22, function()
			Fx.heroFrame(center + V3(0, 1.5, 0), { color = COL.white, size = radius * 0.6, flash = 0.35, stop = 0.12, caster = caster, fov = 6, shake = 0.35, sparks = 24, ground = center })
			Fx.debris(center + V3(0, radius * 0.5, 0), { count = 14, color = COL.ice, material = Enum.Material.Glass, transparency = 0.35, shard = true, size = 0.5,
				speed = radius * 1.2, up = 8, radius = radius * 0.5, time = 3, groundY = center.Y })
			Fx.cubes(center + V3(0, 1, 0), { count = 10, colors = { COL.memory, COL.lavender, COL.white }, size = 0.45, radius = radius * 0.5, height = 3, speed = 2, time = 2.8 })
			Fx.glyphs(center + V3(0, 1, 0), { letters = Kit.ROMAN, count = 6, color = COL.brass, radius = radius * 0.5, time = 2.4, rise = 1.4, size = 1.3 })
			Fx.sigil(center, radius * 0.8, COL.lavender, { image = "seal", time = 2.6, spin = -90, grow = 0.25, transparency = 0.45 })
			Fx.afterglow(center + V3(0, 1.5, 0), { color = COL.violet, time = 2.8, brightness = 4, range = radius * 2.2 })
			Fx.mist(center, { radius = radius * 0.6, time = 3, color = COL.dust, rate = 4 })
			Fx.sfx("fxChronDomeShatter", center)
			Fx.sfx("fxChronDomeTail", center, nil, 0.25)
		end)
	end,
	-- Песок времени: удар отзывается эхом — рябь, цифра, искры инея.
	timeEcho = function(p)
		local at = posOf(p.model, p.position)
		if not at then
			return
		end
		Kit.ringWave(groundUnder(p.model, at, 0.12), 2.2, COL.lavender, { time = 0.5, brightness = 3 })
		Fx.glyphs(at + V3(0, 1, 0), { letters = Kit.ROMAN, count = 1, color = COL.brass, radius = 0.5, time = 1.2, rise = 1, size = 1 })
		Fx.sparks(at, { color = COL.ice, count = 6, speed = { 4, 8 } })
		if once(p.caster or "?") then
			Fx.sfx("fxChronEcho", at)
		end
	end,

	-- ===== Чернила =====
	-- Веер чернил: мини-кадр, струя брызг, кляксы ложатся по конусу, капли; на врагах — потёки.
	inkSplash = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local origin = G(p.position)
		local dir = flat(p.direction)
		local radius = p.radius or 10.5
		local half = p.halfAngle or 70
		Fx.heroFrame(origin + V3(0, 1.2, 0) + dir * 1.5, { color = COL.lavender, size = 3.5, flash = 0.12, stop = 0.07, caster = p.caster, sparks = 10, ring = false })
		inkSpray(origin + V3(0, 1.2, 0), dir, half * 0.8, 20, 20)
		for i = 1, 5 do
			local a = -half + (i - 0.5) / 5 * half * 2 + rnd(-6, 6)
			local dist = radius * rnd(0.45, 0.85)
			local at = G(origin + Kit.rotate(dir, a) * dist)
			Kit.after(0.06 + dist / radius * 0.18, function()
				blot(at, rnd(0.9, 1.5), 4)
				Fx.drops(at + V3(0, 0.4, 0), { count = 3, color = COL.inkLight, speed = 3, up = 6, time = 1.4, rings = 2, size = 0.25 })
			end)
		end
		for _, info in ipairs(p.targets or {}) do
			local at = type(info) == "table" and posOf(info.model)
			if at then
				Fx.drops(at + V3(0, 0.5, 0), { count = 2 + math.min(info.stains or 1, 3), color = COL.inkLight, speed = 2, up = 3, time = 1.6, rings = 2, size = 0.22,
					groundY = groundUnder(info.model, at).Y })
			end
		end
		Fx.sfx("fxChronInkSplat", origin)
		Fx.sfx("fxChronInkTail", origin, nil, 0.4)
	end,
	-- Пятно: пара капель стекает с врага.
	inkStain = function(p)
		local at = posOf(p.model)
		if not at then
			return
		end
		Fx.drops(at + V3(0, 0.5, 0), { count = 1 + math.min(p.count or 1, 3), color = COL.inkLight, speed = 2, up = 3, time = 1.4, rings = 2, size = 0.2,
			groundY = groundUnder(p.model, at).Y })
		if once(p.caster or "?") then
			Fx.sfx("fxChronStain", at)
		end
	end,

	-- ===== Стереть и Забвение =====
	-- Враг стёрт: белая вспышка, распад на кубики памяти, бумажная пыль, буквы уходят вверх.
	erased = function(p)
		local at = posOf(p.model, p.position)
		if not at then
			return
		end
		Fx.heroFrame(at, { color = COL.white, size = 3, sparks = 10, ring = false })
		Fx.cubes(at, { count = 10, colors = { COL.white, COL.lavender, COL.memory }, size = 0.4, radius = 1.2, height = 2.5, speed = 2, time = 2.4 })
		Fx.flutter(at + V3(0, 0.5, 0), { kind = "ash", color = COL.paper, count = 6, radius = 0.8, up = 5, speed = 3, time = 3.5 })
		Fx.glyphs(at, { count = 3, color = COL.lavender, radius = 0.8, time = 2, rise = 1.2 })
		Fx.sfx("fxChronErasedTail", at)
	end,
	-- Взмах-ластик: дуга из светлых черт, крошки бумаги, пыль; если кого-то стёрло — кадр.
	eraseSwing = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local origin = G(p.position)
		local dir = flat(p.direction)
		local radius = p.radius or 8.5
		local half = math.min(p.halfAngle or 110, 175)
		local n = 6
		for i = 1, n do
			local a1 = -half + (i - 1) / n * half * 2
			local a2 = -half + i / n * half * 2
			local p1 = origin + Kit.rotate(dir, a1) * radius * 0.75 + V3(0, 1.3, 0)
			local p2 = origin + Kit.rotate(dir, a2) * radius * 0.75 + V3(0, 1.3, 0)
			Kit.after(i * 0.025, function()
				Fx.slashMark((p1 + p2) / 2, p2 - p1, (p2 - p1).Magnitude * 1.05, COL.white, { time = 0.6, width = 0.2 })
			end)
		end
		Fx.flutter(origin + dir * radius * 0.5 + V3(0, 1, 0), { kind = "ash", color = COL.paper, count = 8, radius = radius * 0.4, up = 4, speed = 4, time = 3.5 })
		Fx.dust(origin, { radius = radius * 0.6, dirs = 8, count = 1, color = COL.dust })
		if (p.erased or 0) > 0 then
			Fx.heroFrame(origin + V3(0, 1.3, 0) + dir * 2, { color = COL.lavender, size = 4, flash = 0.15, stop = 0.08, caster = p.caster, sparks = 14, ring = false })
		end
		Fx.sfx("fxChronEraseSweep", origin)
	end,
	-- Забвение: под врагом закручивается чернильная воронка, тёмные пылинки.
	oblivionMark = function(p)
		local at = posOf(p.model, p.position)
		if not at then
			return
		end
		followRing(p.model, 1.5, COL.violet, 2.5, { image = "swirl", spin = -120, transparency = 0.35, pulse = 4 })
		Fx.motes(at, { color = COL.inkLight, texture = "glow", area = 1.6, time = 2, rate = 8, size = { 0.2, 0.35, 0 } })
		Fx.sfx("fxChronOblivionTail", at)
	end,

	-- ===== Вспомнить и Послеобраз =====
	-- Призыв эха: круг памяти под ногами, вокруг всплывают кубики, на местах двойников — столбы света.
	recallSummon = function(p)
		local root = rootOf(p.caster)
		if not root then
			return
		end
		local combos = math.max(#(p.combos or { 1 }), 1)
		local life = (p.start or 0.3) + (p.gap or 0.3) * combos + 0.6
		local echoes = p.echoes or 2
		local offset = p.offset or 2.2
		local feet = G(root.Position - V3(0, 3, 0))
		local right = P.flat(root.CFrame.RightVector)
		local st = stateOf(p.caster)
		local old = st.recall
		if old and old.circle and old.circle.alive then
			old.circle.fade(0.2)
		end
		local circle = Kit.circle(feet, 3.2, COL.memory, { duration = life, spin = 40, appear = 0.25 })
		st.recall = { combos = combos, echoes = echoes, offset = offset, circle = circle }
		Fx.inward(feet + V3(0, 1.5, 0), 5, { color = COL.memory, count = 30, time = 0.4, speed = 10, streak = true })
		Fx.cubes(feet, { count = 8, colors = { COL.memory, COL.white }, size = 0.35, radius = 2.5, height = 1, speed = 2.5, time = life })
		for _, side in ipairs(echoSides(echoes)) do
			Kit.pillar(feet + right * side * offset, 7, 0.9, COL.memory, { time = 0.5, transparency = 0.4 })
		end
		Fx.sfx("fxChronRecallRise", feet)
	end,
	-- Удар эха: черты-следы у каждого двойника, искры; последний — кадр, взрыв кубиков, буквы, свет.
	recallSwing = function(p)
		local root = rootOf(p.caster)
		if not root then
			return
		end
		local st = stateOf(p.caster)
		local rec = st.recall or { combos = 1, echoes = 2, offset = 2.2 }
		local index = p.index or 1
		local sign = ((p.combo or index) % 2 == 1) and 1 or -1
		local look = P.flat(root.CFrame.LookVector)
		local right = V3(-look.Z, 0, look.X)
		for _, side in ipairs(echoSides(rec.echoes)) do
			local at = root.Position + right * side * rec.offset + look * 1.5
			Fx.slashMark(at, right + UP * 0.4 * sign, 4, COL.memory, { time = 0.4, width = 0.14 })
			Fx.sparks(at, { color = COL.memory, count = 5, speed = { 5, 10 } })
		end
		if index >= rec.combos then
			if rec.circle and rec.circle.alive then
				rec.circle.pulse(0.1)
			end
			st.recall = nil
			local front = root.Position + look * 3
			local ground = G(front)
			Fx.heroFrame(front, { color = COL.memory, size = 4.5, flash = 0.2, stop = 0.08, caster = p.caster, fov = 5, sparks = 18, ground = ground })
			Fx.cubes(front, { count = 10, colors = { COL.memory, COL.white, COL.lavender }, size = 0.4, radius = 2, height = 2, speed = 3, time = 2.6 })
			Fx.glyphs(front, { count = 4, color = COL.memory, radius = 1.5, time = 2.2, rise = 1.3 })
			Fx.motes(front, { color = COL.memory, area = 3, time = 2.4, rate = 10 })
			Fx.afterglow(front, { color = COL.memory, time = 2.4, brightness = 4, range = 16 })
			Fx.sfx("fxChronRecallFinale", front)
			Fx.sfx("fxChronMemoryTail", front, nil, 0.3)
		else
			Fx.sfx("fxChronEchoSlash", root.Position, 0.8)
		end
	end,
	-- Послеобраз: призрачная черта удара догоняет, пылинки памяти, пара кубиков.
	afterimage = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local feet = G(p.position)
		local dir = flat(p.direction)
		local right = V3(-dir.Z, 0, dir.X)
		local sign = ((p.combo or 1) % 2 == 1) and 1 or -1
		Kit.after(p.delay or 0.25, function()
			local at = feet + V3(0, 1.4, 0) + dir * 1.8
			Fx.slashMark(at, right + UP * 0.35 * sign, 4.5, COL.lavender, { time = 0.55, width = 0.16 })
			Fx.motes(at, { color = COL.memory, area = 1.8, time = 1.8, rate = 8 })
			Fx.cubes(at, { count = 3, colors = { COL.memory, COL.white }, size = 0.3, radius = 1, height = 1, speed = 1.5, time = 2 })
			Fx.sfx("fxChronGhostSlash", at)
		end)
	end,
}

AbilityFxPlusChronicle.handlers = H

function AbilityFxPlusChronicle.forget(caster)
	local st = states[caster]
	if st then
		if st.dome and st.dome.circle and st.dome.circle.alive then
			st.dome.circle.destroy()
		end
		if st.recall and st.recall.circle and st.recall.circle.alive then
			st.recall.circle.destroy()
		end
	end
	states[caster] = nil
end

return AbilityFxPlusChronicle
