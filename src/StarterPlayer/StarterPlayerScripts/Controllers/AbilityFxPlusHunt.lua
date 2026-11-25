--!nonstrict
-- AbilityFxPlusHunt (клиент)
-- Продлённые фазы оружия этажа 3 «Псарни охоты» (kind = "hunt") поверх AbilityFxHunt, как
-- AbilityFxPlus для этажей 1–2: предвкушение, белый кадр удара с hit-stop, разлёт (пыль, перья,
-- обломки, клочья), «висение» (огоньки, золотая пыль) и долгий хвост 2–4 с, плюс звуки fxHunt*
-- (Config/SfxSkills). Сервер, урон и шаблоны FX.Hunt не трогаем — те же события AbilityFx.
-- Подключается из AbilityFxPlus (handlers), вызывается после основного обработчика.

local P = require(script.Parent.AbilityFxPlus345Kit)
local Fx = P.Fx
local Kit = P.Kit

local AbilityFxPlusHunt = {}

local V3 = Vector3.new
local UP = V3(0, 1, 0)
local TAU = math.pi * 2
local C = Fx.C
local rnd = Fx.rnd
local G, partOf, posOf, flat, groundUnder, followRing = P.G, P.partOf, P.posOf, P.flat, P.groundUnder, P.followRing

-- Палитра AbilityFxHunt (GOLD / PALE / PREY / IRON) + земля, шерсть, листва.
local COL = {
	gold = C("#FFD45A"), pale = C("#FFF1C9"), spirit = C("#FFE9A8"), prey = C("#FF4A3A"), preyDark = C("#6A1A14"),
	iron = C("#5E5866"), ironEdge = C("#B9B2C2"), dirt = C("#6E5B45"), dust = C("#A8957A"), fur = C("#8A7A66"),
	mist = C("#E2D8C2"), scar = C("#2A231C"),
}
AbilityFxPlusHunt.COLORS = COL

-- [caster] = { pack = { token, hounds }, dash = { dir }, fadeSoundAt }
local stateOf, states = P.states()

-- ===== Свора =====

-- Гончие живут в AbilityFxHunt (packs[caster][index].position / forward / gone). Нет модуля
-- (например, в tools/fxsim) — считаем бег по прямой из события.
local huntBase = nil
local function basePacks()
	if huntBase == nil then
		huntBase = false
		local module = script.Parent:FindFirstChild("AbilityFxHunt")
		if module then
			local ok, result = pcall(require, module)
			if ok and type(result) == "table" then
				huntBase = result
			end
		end
	end
	return huntBase and huntBase.packs or nil
end

-- След лапы: пятно-подушечка и пальцы чуть впереди, светятся и тают.
local function pawPrint(ground: Vector3, forward: Vector3, side: number)
	local right = V3(-forward.Z, 0, forward.X)
	local at = ground + right * side * 0.32
	Kit.glowSpot(at, 0.3, COL.gold, 1.7, { transparency = 0.35, brightness = 2.5 })
	Kit.glowSpot(at + forward * 0.42, 0.17, COL.pale, 1.5, { transparency = 0.3, brightness = 3 })
end

-- Гончая растворилась: огоньки уходят вверх, золотая дымка, пыль.
local function houndVanish(st, at: Vector3)
	local ground = G(at)
	Fx.wisps(ground + V3(0, 0.6, 0), { count = 3, color = COL.spirit, radius = 0.8, rise = 3.2, time = 2.1, spin = 6, both = true, size = 0.2 })
	Fx.smoke(at, { color = COL.pale, radius = 0.9, count = 5, lightEmission = 0.6, lightInfluence = 0.3, life = { 0.8, 1.5 }, accel = V3(0, 3, 0) })
	Fx.motes(at, { color = COL.gold, area = 1.6, time = 1.8, rate = 8 })
	Kit.glowSpot(ground, 0.9, COL.gold, 1.2, { transparency = 0.45 })
	-- Несколько гончих гаснут почти разом — один звук на 0,35 с.
	local now = os.clock()
	if now - (st.fadeSoundAt or -1) > 0.35 then
		st.fadeSoundAt = now
		Fx.sfx("fxHuntFade", at, 0.8)
	end
end

local function trackPack(p, st, origin: Vector3)
	local token = {}
	local hounds = {}
	for i, info in ipairs(p.hounds or {}) do
		local forward = flat(info.direction)
		hounds[info.index or i] = { forward = forward, pos = origin + V3(0, 1.1, 0), start = origin + V3(0, 1.1, 0), side = 1, lastAt = nil, lastT = -1 }
	end
	st.pack = { token = token, hounds = hounds }
	local speed = p.speed or 26
	local life = (p.lifetime or 3.2) + 1.5
	local set = nil
	local packs = basePacks()
	if packs then
		set = packs[p.caster]
	end
	Kit.every(life, function(_, t)
		if not st.pack or st.pack.token ~= token then
			return false
		end
		local alive = 0
		for index, h in pairs(hounds) do
			if not h.done then
				local position, forward = nil, h.forward
				if set then
					local hound = set[index]
					if hound and not hound.gone then
						position, forward = hound.position, hound.forward or h.forward
					end
				else
					-- Запасной бег: вперёд на 0,7 скорости и раствориться (как гончая без цели).
					local run = math.min(speed * t, speed * 0.7)
					position = h.start + h.forward * run
					if run >= speed * 0.7 then
						position = nil
					end
				end
				if position then
					alive += 1
					h.pos, h.forward = position, forward
					local moved = h.lastAt and (position - h.lastAt).Magnitude or math.huge
					if moved >= 2.4 and t - h.lastT >= 0.12 then
						h.lastAt, h.lastT = position, t
						h.side = -h.side
						pawPrint(G(position), flat(forward), h.side)
						Kit.burst(position + V3(0, 0.2, 0), { texture = "glow", color = { COL.pale, COL.gold }, count = 2, size = { 0.45, 0 },
							life = { 0.35, 0.7 }, speed = { 0.5, 2 }, accel = V3(0, 4, 0), spread = 60, brightness = 3, direction = Enum.NormalId.Top })
					end
				else
					h.done = true
					if not h.faded then
						h.faded = true
						houndVanish(st, h.pos)
					end
				end
			end
		end
		return alive > 0 or t < 0.2
	end)
end

local H = {}

H.hunt = {
	-- Вой: кольца звука, пыль по кругу, огоньки духа; дальше за гончими — светящиеся следы лап.
	packSummon = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local ground = G(p.position)
		local st = stateOf(p.caster)
		Fx.heroFrame(ground + V3(0, 1.2, 0), { color = COL.gold, size = 4, flash = 0.12, stop = 0.05, caster = p.caster, fov = 4, sparks = 12, ground = ground })
		for i = 0, 2 do
			Kit.after(0.12 + i * 0.22, function()
				Kit.ringWave(ground + V3(0, 0.25, 0), 5 + i * 2.6, COL.pale, { time = 0.75, brightness = 2.5, transparency = 0.3 })
			end)
		end
		Fx.dust(ground, { radius = 3.5, dirs = 8, count = 2, color = COL.dust })
		Fx.wisps(ground, { count = 5, color = COL.spirit, radius = 1.8, rise = 3.6, time = 2.3, spin = 5, both = true, size = 0.22 })
		Fx.motes(ground + V3(0, 1, 0), { color = COL.gold, area = 3, time = 2.6, rate = 10 })
		Fx.flutter(ground + V3(0, 0.5, 0), { kind = "leaf", count = 6, radius = 2, up = 7, speed = 6, time = 4.5 })
		Fx.mist(ground, { radius = 3, time = 2.6, color = COL.mist, rate = 3 })
		trackPack(p, st, ground)
		Fx.sfx("fxHuntHowlTail", ground, nil, 0.3)
	end,
	-- Смена цели: гончая вскидывается (блик), под новой добычей вспыхивает красное кольцо.
	packRetarget = function(p)
		local st = stateOf(p.caster)
		local h = st.pack and st.pack.hounds[p.index]
		local at = h and h.pos or posOf(p.model)
		if at then
			Kit.flash(at + V3(0, 0.4, 0), COL.pale, 1.6, 0.12)
			Fx.sparks(at + V3(0, 0.4, 0), { color = COL.gold, count = 6, speed = { 4, 9 } })
		end
		local target = posOf(p.model)
		if target then
			Kit.ringWave(groundUnder(p.model, target, 0.12), 2, COL.prey, { time = 0.45, brightness = 3 })
		end
	end,
	-- Укус: мини-кадр, следы клыков (две дуги), клочья шерсти, пыль из-под лап.
	packBite = function(p)
		local at = posOf(p.model, p.position)
		if not at then
			return
		end
		local st = stateOf(p.caster)
		local h = st.pack and st.pack.hounds[p.index]
		local dir = h and flat(at - h.pos, h.forward) or V3(0, 0, -1)
		local right = V3(-dir.Z, 0, dir.X)
		local hit = at + V3(0, 0.6, 0) - dir * 0.6
		Fx.heroFrame(hit, { color = COL.pale, size = 2.4, sparks = 8, ring = false })
		Fx.slashMark(hit + UP * 0.32, right + UP * 0.3, 1.5, COL.gold, { time = 0.45, width = 0.13 })
		Fx.slashMark(hit - UP * 0.32, right - UP * 0.3, 1.5, COL.gold, { time = 0.45, width = 0.13 })
		Fx.flutter(hit, { kind = "ash", color = COL.fur, count = 3, radius = 0.5, up = 5, speed = 3, time = 2.6 })
		Fx.dust(groundUnder(p.model, at, 0.06), { radius = 1.2, dirs = 4, count = 1, color = COL.dust })
		Fx.sfx("fxHuntBite", hit, (p.bite or 1) > 1 and 0.75 or 1)
	end,
	packFade = function(p)
		local st = stateOf(p.caster)
		local h = st.pack and st.pack.hounds[p.index]
		if h then
			h.done = true
			if h.faded then
				return
			end
			h.faded = true
		end
		local at = h and h.pos or p.position
		if typeof(at) == "Vector3" then
			houndVanish(st, at)
		end
	end,

	-- Капкан: земля втягивается к центру, кольцо цепи сжимается, камешки подпрыгивают.
	snareOpen = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 7.5
		local snap = math.max(p.snapDelay or 0.45, 0.15)
		local ground = G(p.position)
		Fx.inward(ground + V3(0, 0.6, 0), radius, { color = COL.dust, count = 30, time = snap, speed = radius * 2.2, streak = true, size = { 0.4, 0.15 } })
		Fx.collapse(ground, radius * 1.05, COL.ironEdge, { time = snap, image = "chain", pop = false })
		Fx.scorch(ground, radius * 0.7, { color = COL.scar, edge = false, life = snap + 3, transparency = 0.6 })
		local nextAt = 0
		Kit.every(snap, function(_, t)
			if t >= nextAt then
				nextAt = t + 0.09
				local a = math.random() * TAU
				local point = ground + V3(math.cos(a), 0, math.sin(a)) * radius * rnd(0.3, 0.9)
				Kit.burst(point + V3(0, 0.2, 0), { texture = "rock", color = COL.dirt, count = 2, size = { 0.3, 0.15 }, speed = { 3, 6 },
					accel = V3(0, -40, 0), spread = 25, life = { 0.35, 0.6 }, lightEmission = 0, lightInfluence = 1, direction = Enum.NormalId.Top })
			end
			return true
		end)
		Fx.sfx("fxHuntSnareTense", ground)
	end,
	-- Щелчок: белый кадр, звенья и осколки зубьев, пыль; на пойманных — цепь-кольцо на всё время
	-- обездвиживания, потом цепь падает.
	snareSnap = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 7.5
		local root = p.root or 1.6
		local ground = G(p.position)
		local caught = #(p.targets or {}) > 0
		Fx.heroFrame(ground + V3(0, 1, 0), { color = COL.ironEdge, size = radius * 0.6, flash = caught and 0.25 or 0.12, stop = caught and 0.1 or 0.04,
			caster = p.caster, fov = 5, shake = 0.25, sparks = 18, ground = ground })
		Fx.debris(ground + V3(0, 0.8, 0), { count = 10, color = COL.iron, material = Enum.Material.Metal, shard = true, size = 0.4, speed = radius * 1.6, up = 14, time = 2.8 })
		Fx.dust(ground, { radius = radius * 0.8, dirs = 10, count = 2, color = COL.dust })
		Fx.sparks(ground + V3(0, 0.6, 0), { color = COL.gold, count = 14, speed = { 8, 18 } })
		Fx.sigil(ground, radius * 0.75, COL.ironEdge, { image = "chain", time = 2.4, spin = -30, grow = 0.05, transparency = 0.5 })
		Fx.flutter(ground + V3(0, 0.6, 0), { kind = "leaf", count = 6, radius = radius * 0.4, up = 6, speed = 5, time = 4 })
		Fx.mist(ground, { radius = radius * 0.6, time = 2.4, color = COL.mist, rate = 3 })
		for _, model in ipairs(p.targets or {}) do
			local part = partOf(model)
			if part then
				Fx.sparks(part.Position, { color = COL.ironEdge, count = 8, speed = { 5, 10 } })
				followRing(model, 1.6, COL.ironEdge, root, { image = "chain", spin = 40, transparency = 0.3 })
			end
		end
		if caught then
			Kit.after(root, function()
				for i, model in ipairs(p.targets or {}) do
					local at = posOf(model)
					if at then
						Fx.debris(at, { count = 3, color = COL.iron, material = Enum.Material.Metal, size = 0.3, speed = 4, up = 6, time = 2, groundY = groundUnder(model, at).Y })
						if i == 1 then
							Fx.sfx("fxHuntChainDrop", at)
						end
					end
				end
			end)
		end
		Fx.sfx("fxHuntSnap", ground)
		Fx.sfx("fxHuntSnareTail", ground, nil, 0.25)
	end,

	-- Последний гон: три борозды когтей по пути, комета-черта, пыль и листья вслед; на финише —
	-- кадр, кольцо, золотая пыль висит, дымка вдоль пути.
	dash = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local dir = flat(p.direction)
		local length = p.length or 13
		local time = math.max(p.time or 0.22, 0.05)
		local half = p.halfWidth or 3.2
		local ground = G(p.position)
		local right = V3(-dir.Z, 0, dir.X)
		local finish = G(ground + dir * length)
		stateOf(p.caster).dash = { dir = dir }
		Fx.smoke(ground - dir * 0.8 + V3(0, 0.5, 0), { color = COL.dust, radius = 1.2, count = 6, speed = { 3, 7 }, life = { 0.8, 1.5 } })
		Kit.flash(ground + V3(0, 1.2, 0), COL.pale, 3, 0.15)
		for _, s in ipairs({ -1, 0, 1 }) do
			Fx.seamPath(ground + right * s * half * 0.3 + dir * 1.2, dir, length - 1.2, { hot = COL.pale, cool = COL.preyDark, life = 2.6, width = 0.26, reveal = time, jitter = 0.3 })
		end
		Fx.slashMark(ground + V3(0, 1.3, 0) + dir * length * 0.5, dir, length, COL.gold, { time = 0.75, width = 0.3 })
		local n = math.clamp(math.floor(length / 3), 3, 6)
		for i = 1, n do
			local k = i / n
			Kit.after(time * k, function()
				local at = ground + dir * length * k
				Fx.dust(at, { radius = half * 0.6, dirs = 4, count = 1, color = COL.dust })
				if i % 2 == 0 then
					Fx.flutter(at + V3(0, 0.4, 0), { kind = "leaf", count = 3, radius = 1, up = 6, speed = 5, time = 3.6 })
				end
			end)
		end
		Kit.after(time, function()
			Fx.heroFrame(finish + V3(0, 1.2, 0), { color = COL.gold, size = 4.5, flash = 0.18, stop = 0.07, caster = p.caster, fov = 5, sparks = 16, ground = finish })
			Fx.dust(finish, { radius = 3.5, dirs = 8, count = 2, color = COL.dust })
			Fx.debris(finish, { count = 6, color = COL.dirt, size = 0.35, speed = 10, up = 12, time = 2.6, dir = dir })
			Fx.motes(finish + V3(0, 1, 0), { color = COL.gold, area = 3, time = 2.4, rate = 10 })
			Fx.mist(ground + dir * length * 0.5, { radius = length * 0.35, time = 2.6, color = COL.mist, rate = 3 })
			Fx.afterglow(finish + V3(0, 1, 0), { color = COL.gold, time = 2.2, brightness = 3, range = 16 })
			Fx.sfx("fxHuntDashEnd", finish)
			Fx.sfx("fxHuntDashTail", finish, nil, 0.2)
		end)
		Fx.sfx("fxHuntDashRush", ground)
	end,
	-- Пронзание: черта насквозь по ходу рывка, искры; первая цель — мини-кадр со стоп-кадром.
	dashHit = function(p)
		local st = stateOf(p.caster)
		local dir = st.dash and st.dash.dir or V3(0, 0, -1)
		for i, model in ipairs(p.targets or {}) do
			local at = posOf(model)
			if at then
				local hit = at + V3(0, 0.5, 0)
				if i == 1 then
					Fx.heroFrame(hit, { color = COL.prey, size = 3, stop = 0.06, caster = p.caster, sparks = 12, ring = false })
					Fx.sfx("fxHuntPierce", hit)
				else
					Fx.sparks(hit, { color = COL.pale, count = 8, speed = { 6, 12 } })
				end
				Fx.slashMark(hit, dir + UP * 0.08, 4, COL.pale, { time = 0.5, width = 0.16 })
				Fx.flutter(hit, { kind = "ash", color = COL.fur, count = 2, radius = 0.4, up = 4, speed = 3, time = 2.4 })
			end
		end
	end,
	-- Рог: волны звука расходятся кольцами, рябь, листья сдувает наружу, тёплая вспышка экрана.
	horn = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 8
		local ground = G(p.position)
		Fx.heroFrame(ground + V3(0, 1.5, 0), { color = COL.gold, size = radius * 0.5, flash = 0.12, stop = 0.05, caster = p.caster, fov = 4, sparks = false, ring = false })
		for i = 0, 3 do
			Kit.after(i * 0.16, function()
				Kit.ringWave(ground + V3(0, 0.15, 0), radius * (0.6 + i * 0.25), i % 2 == 0 and COL.gold or COL.pale, { time = 0.6 + i * 0.1, brightness = 3, transparency = 0.25 })
			end)
		end
		Fx.ripples(ground, { time = 2, count = 6, radius = radius * 0.7, size = radius * 0.3, color = COL.pale, transparency = 0.5 })
		Fx.dust(ground, { radius = radius, dirs = 12, count = 2, color = COL.dust })
		Fx.flutter(ground + V3(0, 0.6, 0), { kind = "leaf", count = 10, radius = radius * 0.5, up = 5, speed = 12, time = 4.5 })
		Fx.tint(ground, { color = COL.gold, amount = 0.18, time = 0.9, brightness = 0.04, range = 40 })
		Fx.sigil(ground, radius * 0.7, COL.gold, { image = "ring", time = 2.4, spin = 20, grow = 0.3, transparency = 0.55 })
		Fx.sfx("fxHuntHornTail", ground)
	end,

	-- Пикирование: красное кольцо цели сжимается, воздух втягивается, с неба падают перья.
	diveStart = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local point = G(p.position)
		local time = math.max(p.time or 0.35, 0.1)
		local radius = p.radius or 6
		local from = typeof(p.from) == "Vector3" and p.from or point + V3(0, 10, 0)
		Fx.collapse(point, radius * 1.1, COL.prey, { time = time, pop = false })
		Fx.inward(point + V3(0, 0.6, 0), radius, { color = COL.gold, count = 26, time = time, speed = radius * 2.6, streak = true, size = { 0.35, 0.1 } })
		Kit.glowSpot(point, radius * 0.5, COL.prey, time + 0.15, { transparency = 0.5 })
		Fx.flutter(from, { kind = "feather", count = 4, radius = 1, up = 1, speed = 2, time = 4 })
		Fx.sfx("fxHuntDiveWind", from)
	end,
	-- Удар сокола: кадр, кратер с остывающими швами, комья земли, взрыв перьев, огоньки, дымка.
	diveImpact = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 6
		local ground = G(p.position)
		Fx.heroFrame(ground + V3(0, 1.2, 0), { color = COL.gold, size = radius * 0.8, flash = 0.3, stop = 0.12, caster = p.caster, fov = 7, shake = 0.3, sparks = 22, ground = ground })
		Fx.scorch(ground, radius * 0.55, { life = 5, hot = COL.gold, cool = COL.preyDark, glow = 1.4, transparency = 0.25 })
		for i = 1, 5 do
			local a = (i / 5) * TAU + rnd(-0.3, 0.3)
			Fx.seamPath(ground, V3(math.cos(a), 0, math.sin(a)), radius * rnd(0.6, 0.95), { hot = COL.pale, cool = COL.preyDark, life = 2.6, width = 0.35, jitter = 0.5 })
		end
		Fx.debris(ground, { count = 12, color = COL.dirt, size = 0.5, speed = radius * 2.2, up = 20, time = 3 })
		Fx.dust(ground, { radius = radius, dirs = 12, count = 3, color = COL.dust })
		Fx.flutter(ground + V3(0, 1.5, 0), { kind = "feather", count = 12, radius = 1.5, up = 12, speed = 7, time = 5 })
		Fx.wisps(ground, { count = 5, color = COL.gold, radius = radius * 0.4, rise = 4, time = 2.3, spin = 6, size = 0.24 })
		Fx.mist(ground, { radius = radius * 0.8, time = 3, color = COL.mist, rate = 4 })
		Fx.afterglow(ground + V3(0, 1, 0), { color = COL.gold, time = 2.6, brightness = 4, range = radius * 3 })
		Fx.sfx("fxHuntDiveBoom", ground)
		Fx.sfx("fxHuntDiveTail", ground, nil, 0.2)
	end,

	-- Метка добычи: красное кольцо-прицел едет под врагом всю метку, блик над головой.
	preyMark = function(p)
		local part = partOf(p.model)
		if not part then
			return
		end
		local duration = p.duration or 4
		followRing(p.model, 1.7, COL.prey, duration, { image = "ring", spin = 90, transparency = 0.4, pulse = 5 })
		local height = p.model:GetAttribute("EnemyHeight") or 5
		Fx.sparks(part.Position + V3(0, height * 0.5, 0), { color = COL.prey, count = 6, speed = { 3, 7 } })
		Fx.sfx("fxHuntMark", part.Position)
	end,
	-- Добыча пала: трофейная вспышка, три борозды когтей на земле, золотые огни уходят вверх.
	preyKill = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local ground = G(p.position)
		local hit = ground + V3(0, 1.5, 0)
		Fx.heroFrame(hit, { color = COL.prey, size = 3, flash = 0.08, sparks = 12, ground = ground })
		local dir = flat(V3(rnd(-1, 1), 0, rnd(-1, 1)))
		local right = V3(-dir.Z, 0, dir.X)
		for s = -1, 1 do
			Fx.seamPath(ground - dir * 1.6 + right * s * 0.55, dir, 3.2, { hot = COL.gold, cool = COL.preyDark, life = 2.4, width = 0.2, jitter = 0.15 })
		end
		Fx.wisps(ground, { count = 4, color = COL.gold, radius = 1, rise = 4, time = 2.2, spin = 5, size = 0.2 })
		Fx.motes(hit, { color = COL.gold, area = 2, time = 2.2, rate = 10 })
		Fx.sfx("fxHuntTrophy", hit)
	end,
	-- Сокол бьёт: после налёта — облако перьев, «X» когтей, пыль.
	falconStrike = function(p)
		local delay = math.max(0.18, p.delay or 0.35)
		local model, fallback = p.model, p.position
		Kit.after(delay, function()
			local at = posOf(model, fallback)
			if not at then
				return
			end
			local hit = at + V3(0, 0.8, 0)
			Fx.slashMark(hit, V3(1, 0.7, 0), 2.2, COL.pale, { time = 0.45, width = 0.12 })
			Fx.slashMark(hit, V3(-1, 0.7, 0), 2.2, COL.pale, { time = 0.45, width = 0.12 })
			Fx.flutter(hit + V3(0, 0.5, 0), { kind = "feather", count = 5, radius = 0.8, up = 5, speed = 4, time = 3.5 })
			Fx.sparks(hit, { color = COL.gold, count = 8, speed = { 6, 12 } })
			Fx.sfx("fxHuntTalonTail", hit)
		end)
	end,
}

AbilityFxPlusHunt.handlers = H

function AbilityFxPlusHunt.forget(caster)
	local st = states[caster]
	if st then
		st.pack = nil
	end
	states[caster] = nil
end

return AbilityFxPlusHunt
