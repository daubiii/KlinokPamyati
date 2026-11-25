--!nonstrict
-- AbilityFxPlusForge (клиент)
-- Продлённые фазы оружия этажа 4 «Литейные» (kind = "forge") поверх AbilityFxForge, как
-- AbilityFxPlus для этажей 1–2: предвкушение, белый кадр удара с hit-stop, раскалённые обломки и
-- швы, «висение» (угли, искры, жар) и долгий хвост 2–4 с (дым, пар, остывающая корка), плюс звуки
-- fxForge* (Config/SfxSkills). Сервер, урон и шаблоны FX.Forge не трогаем — те же события AbilityFx.
-- Подключается из AbilityFxPlus (handlers), вызывается после основного обработчика.

local P = require(script.Parent.AbilityFxPlus345Kit)
local Fx = P.Fx
local Kit = P.Kit

local AbilityFxPlusForge = {}

local V3 = Vector3.new
local TAU = math.pi * 2
local C = Fx.C
local rnd = Fx.rnd
local G, partOf, posOf, flat, groundUnder, rootOf = P.G, P.partOf, P.posOf, P.flat, P.groundUnder, P.rootOf

-- Палитра AbilityFxForge (ORANGE / YELLOW / WHITE / RED / IRON) + шлак, дым, пар.
local COL = {
	orange = C("#FF7A2B"), yellow = C("#FFC857"), white = C("#FFF1C2"), red = C("#E2572B"),
	iron = C("#3A3436"), ironLight = C("#6B6266"), magmaCool = C("#5A140A"), slag = C("#2A2422"),
	rock = C("#5A4A44"), smoke = C("#4A403A"), steam = C("#E8E2DA"), ash = C("#6B625C"), dust = C("#8E8378"),
}
AbilityFxPlusForge.COLORS = COL

-- Цвета побежалости при закалке: соломенный → бронзовый → пурпурный → синий.
local TEMPER = { C("#FFE08A"), C("#D9A54A"), C("#A0522D"), C("#7B4FB0"), C("#4F7BE0") }

-- [caster] = { heat (токен жара в руке), breath, pour = { waves } }
local stateOf, states = P.states()
local once = P.limiter(0.3)

-- Брызги расплава вверх (фонтан искр).
local function fountain(position: Vector3, count: number, speed: number)
	Kit.burst(position, { texture = "spark", color = { COL.white, COL.orange }, count = count, size = { 0.4, 0 }, life = { 0.4, 0.9 },
		speed = { speed * 0.6, speed }, accel = V3(0, -50, 0), drag = 1, spread = 28, direction = Enum.NormalId.Top, brightness = 3,
		orientation = Enum.ParticleOrientation.VelocityParallel })
end

-- Языки огня над точкой.
local function flames(position: Vector3, count: number, size: number)
	Kit.burst(position, { texture = "glow", color = { COL.yellow, COL.orange, COL.red }, count = count, size = { size, 0 }, life = { 0.4, 0.8 },
		speed = { 2, 5 }, accel = V3(0, 8, 0), spread = 40, direction = Enum.NormalId.Top, brightness = 3 })
end

local H = {}

H.forge = {
	-- ===== Разлив =====
	-- Струя: блик на кромке, капли расплава срываются с дуги, жар.
	spillPour = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local origin = G(p.position, 0)
		local forward = flat(p.direction)
		local lip = origin + forward * 1.6 + V3(0, 2.4, 0)
		Kit.flash(lip, COL.white, 2, 0.15)
		Fx.sparks(lip, { color = COL.yellow, count = 10, speed = { 6, 12 } })
		for i = 1, 3 do
			Kit.after(0.08 * i, function()
				local k = i / 3
				local at = lip + forward * (k * 5) + V3(0, -k * k * 2.2, 0)
				Kit.burst(at, { texture = "spark", color = { COL.white, COL.orange }, count = 5, size = { 0.35, 0 }, life = { 0.4, 0.8 },
					speed = { 2, 6 }, accel = V3(0, -50, 0), spread = 50, direction = Enum.NormalId.Bottom, brightness = 3 })
			end)
		end
		Fx.afterglow(lip, { color = COL.orange, time = 1.2, brightness = 3, range = 12 })
		Fx.sfx("fxForgePourHiss", lip)
	end,
	-- Лужа вспыхивает: кадр (на третьей — стоп-кадр), раскалённое пятно, фонтан искр, комья, угли и
	-- дым до конца горения.
	spillErupt = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 3
		local burn = p.burnTime or 3
		local index = p.index or 1
		local ground = G(p.position)
		Fx.heroFrame(ground + V3(0, 0.8, 0), { color = COL.orange, size = radius * 1.2, flash = index == 1 and 0.14 or 0, stop = index == 3 and 0.06 or 0,
			caster = p.caster, fov = index == 3 and 4 or 0, sparks = 10, ground = ground })
		Fx.scorch(ground, radius * 1.05, { life = burn + 3, hot = COL.yellow, cool = COL.magmaCool, glow = burn + 0.6, transparency = 0.2 })
		fountain(ground + V3(0, 0.3, 0), 14, 18)
		Fx.debris(ground, { count = 4, hot = COL.white, color = COL.slag, size = 0.35, speed = 6, up = 18, time = 2.6, radius = radius * 0.4 })
		Fx.embers(ground + V3(0, 0.3, 0), { time = burn, rate = 8, area = V3(radius * 1.4, 0.3, radius * 1.4) })
		Fx.plume(ground + V3(0, 0.5, 0), { time = burn, rate = 4, radius = radius * 0.5 })
		if index == 1 then
			Fx.sfx("fxForgeSpill", ground)
			Fx.sfx("fxForgePoolTail", ground, nil, 0.3)
		end
	end,
	-- Лужа гаснет: пар, по корке бегут и гаснут трещины.
	spillEnd = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 3
		local ground = G(p.position)
		Fx.smoke(ground + V3(0, 0.5, 0), { color = COL.steam, radius = radius * 0.6, count = 6, lightInfluence = 0.5, accel = V3(0, 4, 0), life = { 1.2, 2.2 } })
		Fx.scorch(ground, radius, { color = COL.slag, hot = COL.orange, cool = COL.slag, edgeImage = "crack", glow = 1.4, life = 4, transparency = 0.35 })
		Kit.burst(ground + V3(0, 0.2, 0), { texture = "spark", color = COL.yellow, count = 5, size = { 0.25, 0 }, life = { 0.3, 0.6 }, speed = { 3, 7 },
			accel = V3(0, -30, 0), spread = 60, direction = Enum.NormalId.Top, brightness = 2 })
		if once(p.caster or "?") then
			Fx.sfx("fxForgeCool", ground)
		end
	end,

	-- ===== Перекал =====
	-- Нова: белый кадр, выжженный круг, раскалённые обломки, дымовое кольцо, тёплый экран; в руке —
	-- жар (языки и угли) всё время перекала, в конце рука остывает паром.
	overheatNova = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 6
		local duration = p.duration or 5
		local center = G(p.position)
		Fx.heroFrame(center + V3(0, 1.2, 0), { color = COL.orange, size = radius * 0.9, flash = 0.3, stop = 0.1, caster = p.caster, fov = 7, shake = 0.3, sparks = 24, ground = center })
		Fx.scorch(center, radius * 0.8, { life = 5, hot = COL.yellow, cool = COL.magmaCool, glow = 1.6, transparency = 0.3 })
		Fx.debris(center, { count = 8, hot = COL.white, color = COL.slag, size = 0.4, speed = radius * 2.2, up = 14, time = 2.8 })
		Fx.smoke(center + V3(0, 1, 0), { color = COL.smoke, radius = radius * 0.45, count = 10, speed = { 6, 12 }, drag = 3, life = { 1.2, 2.2 } })
		Fx.tint(center, { color = COL.orange, amount = 0.22, time = 1.2, brightness = 0.05, contrast = 0.12, range = 45 })
		Fx.afterglow(center + V3(0, 1.2, 0), { color = COL.orange, time = 2.6, brightness = 5, range = radius * 3 })
		local st = stateOf(p.caster)
		local token = {}
		st.heat = token
		local caster = p.caster
		local nextAt = 0
		Kit.every(duration, function(_, t)
			if st.heat ~= token then
				return false
			end
			if t >= nextAt then
				nextAt = t + 0.16
				local hand = P.handPos(caster)
				if hand then
					flames(hand, 2, 0.6)
					if math.random() < 0.4 then
						Fx.sparks(hand, { color = COL.yellow, count = 2, speed = { 2, 5 }, accel = V3(0, 6, 0) })
					end
				end
			end
			return true
		end, function()
			if st.heat ~= token then
				return
			end
			st.heat = nil
			local hand = P.handPos(caster)
			if hand then
				Fx.smoke(hand, { color = COL.steam, radius = 0.6, count = 6, lightInfluence = 0.5, accel = V3(0, 5, 0), life = { 0.8, 1.6 } })
				Fx.sfx("fxForgeHandCool", hand)
			end
		end)
		Fx.sfx("fxForgeNova", center)
		Fx.sfx("fxForgeHeatHum", center, nil, 0.25)
	end,
	-- Выброс жара от удара: мини-кадр, комья, дым, подпалина.
	overheatBurst = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 3.5
		local at = p.position
		local ground = G(at)
		Fx.heroFrame(at + V3(0, 0.5, 0), { color = COL.orange, size = 3, sparks = 12, ground = ground })
		Fx.debris(at, { count = 4, hot = COL.yellow, color = COL.slag, size = 0.3, speed = 8, up = 12, time = 2.2, groundY = ground.Y })
		Fx.smoke(at, { color = COL.smoke, radius = 1, count = 5, life = { 0.9, 1.6 } })
		Fx.scorch(ground, radius * 0.45, { life = 3, glow = 0.8, transparency = 0.35 })
		Fx.sfx("fxForgePop", at)
	end,

	-- ===== Наковальня с небес =====
	-- Предвкушение: тень растёт, кольцо сжимается, с неба сыплются искры; перед ударом — порыв пыли.
	anvilMark = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 7
		local time = math.max(p.time or 0.6, 0.15)
		local point = G(p.position)
		Fx.collapse(point, radius, COL.orange, { time = time, pop = false })
		local shadow, label = Kit.plane(CFrame.new(point + V3(0, 0.09, 0)), radius * 0.4, "glow", C("#140E0C"), { brightness = 1, transparency = 1 })
		Kit.every(time + 0.1, function(k)
			local d = radius * (0.4 + 1.1 * k * k)
			shadow.Size = V3(d, 0.05, d)
			label.ImageTransparency = 1 - 0.7 * math.min(1, k * 1.5)
		end, function()
			shadow:Destroy()
		end)
		Kit.burst(point + V3(0, 18, 0), { texture = "spark", color = { COL.white, COL.orange }, count = 12, size = { 0.4, 0 }, life = { 0.5, 0.8 },
			speed = { 20, 30 }, spread = 8, direction = Enum.NormalId.Bottom, accel = V3(0, -40, 0), brightness = 3, radius = 1.2,
			orientation = Enum.ParticleOrientation.VelocityParallel })
		Kit.after(math.max(time - 0.12, 0), function()
			Fx.dust(point, { radius = radius * 0.6, dirs = 8, count = 1, color = COL.dust })
		end)
		Fx.sfx("fxForgeAnvilFall", point + V3(0, 10, 0), nil, math.max(time - 0.4, 0))
	end,
	-- Удар: белый кадр со стоп-кадром, швы расплава лучами, кратер, камни и раскалённые комья,
	-- кольцо по ringRadius, дым столбом, долгий жар; через ~1 с наковальня осыпается.
	anvilImpact = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 7
		local ring = p.ringRadius or radius * 1.6
		local ground = G(p.position)
		Fx.heroFrame(ground + V3(0, 1.2, 0), { color = COL.white, size = radius * 0.9, flash = 0.4, stop = 0.14, caster = p.caster, fov = 9, shake = 0.45, sparks = 28, ground = ground })
		for i = 1, 6 do
			local a = (i / 6) * TAU + rnd(-0.25, 0.25)
			local dir = V3(math.cos(a), 0, math.sin(a))
			local length = ring * rnd(0.45, 0.7)
			Fx.seamPath(ground, dir, length, { hot = COL.yellow, cool = COL.magmaCool, life = 3.4, width = 0.45, jitter = 0.6 })
			if i <= 3 then
				Fx.embers(ground + dir * length * 0.55, { time = 2.8, rate = 7, area = V3(1.5, 0.3, 1.5) })
			end
		end
		Fx.scorch(ground, radius * 0.6, { life = 6, hot = COL.orange, cool = COL.magmaCool, glow = 2, transparency = 0.2 })
		Fx.debris(ground, { count = 14, color = COL.rock, size = 0.6, speed = radius * 2.4, up = 22, time = 3.2 })
		Fx.debris(ground, { count = 6, hot = COL.white, color = COL.slag, size = 0.3, speed = radius * 3, up = 26, time = 2.6 })
		Fx.dust(ground, { radius = ring * 0.8, dirs = 14, count = 3, color = COL.dust })
		Kit.after(0.12, function()
			Kit.ringWave(ground + V3(0, 0.15, 0), ring, COL.orange, { time = 0.55, brightness = 3.5 })
		end)
		Fx.plume(ground, { time = 3, rate = 8, radius = 2, color = COL.smoke })
		Fx.afterglow(ground + V3(0, 1.5, 0), { color = COL.orange, time = 3.2, brightness = 5, range = ring * 2 })
		Fx.tint(ground, { color = COL.orange, amount = 0.2, time = 0.9, brightness = 0.06, contrast = 0.15, range = 50 })
		Kit.after(1.1, function()
			Fx.debris(ground + V3(0, 1.2, 0), { count = 6, color = COL.ironLight, material = Enum.Material.Metal, size = 0.5, speed = 6, up = 10, time = 2.4 })
			Fx.smoke(ground + V3(0, 1, 0), { color = COL.smoke, radius = 1.6, count = 8, life = { 1.2, 2.2 } })
		end)
		Fx.sfx("fxForgeAnvilBoom", ground)
		Fx.sfx("fxForgeAnvilTail", ground, nil, 0.2)
	end,

	-- ===== Дыхание горна =====
	-- Пока дует: по конусу перед героем вспыхивают подпалины и языки; после — дым, пепел, угли, жар.
	breathStart = function(p)
		local root = rootOf(p.caster)
		if not root then
			return
		end
		local duration = math.max(p.duration or 1.1, 0.2)
		local radius = p.radius or 10.5
		local half = p.halfAngle or 45
		local st = stateOf(p.caster)
		local token = {}
		st.breath = token
		local caster = p.caster
		Kit.flash(root.Position + P.flat(root.CFrame.LookVector) * 1.6 + V3(0, 0.7, 0), COL.yellow, 2.5, 0.2)
		local nextAt, n = 0, 0
		Kit.every(duration, function(_, t)
			if st.breath ~= token then
				return false
			end
			local now = rootOf(caster)
			if not now or not now.Parent then
				return false
			end
			if t >= nextAt then
				nextAt = t + 0.09
				n += 1
				local dir = Kit.rotate(P.flat(now.CFrame.LookVector), rnd(-half, half) * 0.8)
				local at = G(now.Position + dir * radius * rnd(0.35, 0.95))
				if n % 2 == 1 then
					Fx.scorch(at, rnd(0.8, 1.4), { life = 3.2, hot = COL.yellow, cool = COL.magmaCool, glow = 1, transparency = 0.35 })
				end
				flames(at + V3(0, 0.3, 0), 3, 0.8)
			end
			return true
		end, function()
			if st.breath ~= token then
				return
			end
			st.breath = nil
			local now = rootOf(caster)
			if not now then
				return
			end
			local mid = G(now.Position + P.flat(now.CFrame.LookVector) * radius * 0.55)
			Fx.smoke(mid + V3(0, 1, 0), { color = COL.smoke, radius = radius * 0.25, count = 8, life = { 1.6, 2.8 } })
			Fx.flutter(mid + V3(0, 1.5, 0), { kind = "ash", count = 8, radius = radius * 0.3, up = 4, speed = 3, time = 4 })
			Fx.embers(mid, { time = 2.4, rate = 10, area = V3(radius * 0.5, 0.4, radius * 0.5) })
			Fx.afterglow(mid + V3(0, 1, 0), { color = COL.orange, time = 2.2, brightness = 3, range = radius * 1.6 })
			Fx.sfx("fxForgeBreathEnd", mid)
		end)
		Fx.sfx("fxForgeBreathRoar", root.Position)
	end,
	-- Попадание струи: искры в середине конуса.
	breathTick = function(p)
		if (p.hits or 0) <= 0 then
			return
		end
		local root = rootOf(p.caster)
		if root then
			Fx.sparks(root.Position + P.flat(root.CFrame.LookVector) * 5, { color = COL.yellow, count = 4, speed = { 4, 9 } })
		end
	end,

	-- ===== Угли =====
	-- Уголёк прилип: несколько искорок вверх.
	ember = function(p)
		local part = partOf(p.model)
		if part then
			flames(part.Position, 1 + math.min(p.count or 1, 4), 0.5)
		end
	end,
	-- Угли вспыхнули: мини-кадр, раскалённые комья, подпалина, угли тлеют.
	emberBurst = function(p)
		local at = posOf(p.model, p.position)
		if not at then
			return
		end
		local radius = p.radius or 3
		local ground = groundUnder(p.model, at)
		Fx.heroFrame(at, { color = COL.orange, size = math.max(2.5, radius), sparks = 12, ground = ground })
		Fx.debris(at, { count = 5, hot = COL.yellow, color = COL.slag, size = 0.3, speed = 9, up = 14, time = 2.4, groundY = ground.Y })
		Fx.scorch(ground, radius * 0.5, { life = 3.2, glow = 1, transparency = 0.3 })
		Fx.smoke(at, { color = COL.smoke, radius = 0.9, count = 5, life = { 0.9, 1.6 } })
		Fx.embers(ground, { time = 2, rate = 8, area = V3(radius, 0.3, radius) })
		Fx.sfx("fxForgeEmberPop", at)
	end,

	-- ===== Шлаковый серп =====
	-- Взмах: искры срываются с кромки по касательной, комья шлака, пыль, вихрь-след на земле.
	slagSpin = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 9
		local index = p.index or 1
		local spin = index % 2 == 1 and 1 or -1
		local center = G(p.position)
		if index == 1 then
			Fx.heroFrame(center + V3(0, 1.4, 0), { color = COL.orange, size = 3, stop = 0.05, caster = p.caster, sparks = false, ring = false })
		end
		for i = 1, 6 do
			local a = (i / 6) * TAU + rnd(-0.2, 0.2)
			local out = V3(math.cos(a), 0, math.sin(a))
			local tangent = V3(-out.Z, 0, out.X) * spin
			local at = center + out * radius * 0.85 + V3(0, 1.4, 0)
			Kit.after(0.035 * i, function()
				Kit.burst(CFrame.lookAt(at, at + tangent), { texture = "spark", color = { COL.white, COL.orange }, count = 4, size = { 0.35, 0 }, life = { 0.25, 0.5 },
					speed = { 12, 20 }, spread = 20, direction = Enum.NormalId.Front, accel = V3(0, -30, 0), drag = 3, brightness = 3,
					orientation = Enum.ParticleOrientation.VelocityParallel })
			end)
		end
		Fx.debris(center + V3(0, 1.2, 0), { count = 5, hot = COL.yellow, color = COL.slag, size = 0.3, speed = radius * 1.6, up = 8, time = 2.4 })
		Fx.dust(center, { radius = radius * 0.8, dirs = 10, count = 1, color = COL.ash })
		Fx.sigil(center, radius * 0.9, COL.orange, { image = "swirl", time = 1.2, spin = 200 * spin, grow = 0.1, transparency = 0.5 })
		Fx.sfx("fxForgeSlagWhirl", center)
	end,
	-- Комья шлака: шлепок с кольцом, раскалённая лужа тлеет, в конце — пар и треск остывания.
	slagGlobs = function(p)
		local flight = p.flight or 0.45
		local radius = p.radius or 2.6
		local life = p.time or 3
		for i, point in ipairs(p.points or {}) do
			if typeof(point) == "Vector3" then
				Kit.after(flight, function()
					local land = G(point)
					Kit.ringWave(land + V3(0, 0.1, 0), radius, COL.orange, { time = 0.35, brightness = 3 })
					Fx.scorch(land, radius * 0.9, { life = life + 2.5, hot = COL.yellow, cool = COL.magmaCool, glow = life, transparency = 0.25 })
					Fx.debris(land, { count = 2, hot = COL.yellow, color = COL.slag, size = 0.3, speed = 6, up = 10, time = 2 })
					Fx.embers(land + V3(0, 0.2, 0), { time = life, rate = 5, area = V3(radius, 0.2, radius) })
					if i == 1 then
						Fx.sfx("fxForgeSlagSplat", land)
					end
				end)
				Kit.after(flight + life, function()
					local land = G(point)
					Fx.smoke(land + V3(0, 0.4, 0), { color = COL.steam, radius = radius * 0.5, count = 4, lightInfluence = 0.5, accel = V3(0, 4, 0) })
					if i == 1 then
						Fx.sfx("fxForgeSlagCool", land)
					end
				end)
			end
		end
	end,

	-- ===== Закалка, корка =====
	-- Стопка закалки: искры у ног и кольцо цвета побежалости (чем больше стопок — тем «синее»).
	temperStack = function(p)
		local root = rootOf(p.caster)
		if not root then
			return
		end
		local count = math.clamp(p.count or 1, 1, #TEMPER)
		local feet = G(root.Position - V3(0, 3, 0))
		Kit.ringWave(feet + V3(0, 0.1, 0), 2 + count * 0.3, TEMPER[count], { time = 0.4, brightness = 3 })
		Fx.sparks(root.Position, { color = TEMPER[count], count = 4 + count, speed = { 3, 7 } })
	end,
	-- Кольцо закалки: кадр, волны цветов побежалости, пар закалки, дымка, искорки.
	temperRing = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 4.5
		local center = G(p.position)
		Fx.heroFrame(center + V3(0, 1, 0), { color = COL.yellow, size = radius * 0.7, flash = 0.12, stop = 0.06, caster = p.caster, sparks = 16, ground = center })
		for i, color in ipairs(TEMPER) do
			Kit.after((i - 1) * 0.12, function()
				Kit.ringWave(center + V3(0, 0.15, 0), radius * (0.5 + i * 0.15), color, { time = 0.55, brightness = 3 })
			end)
		end
		Fx.smoke(center + V3(0, 0.6, 0), { color = COL.steam, radius = radius * 0.4, count = 8, lightInfluence = 0.5, accel = V3(0, 5, 0), life = { 1.2, 2.2 } })
		Fx.mist(center, { radius = radius * 0.7, time = 2.4, color = COL.steam, rate = 4 })
		Fx.motes(center + V3(0, 1, 0), { color = COL.white, area = radius * 0.8, time = 2.2, rate = 8 })
		Fx.sfx("fxForgeTemper", center)
	end,
	-- Шлаковая корка: осколки корки осыпаются, клуб дыма.
	crust = function(p)
		local at = posOf(p.model, p.position)
		if not at then
			return
		end
		Fx.debris(at + V3(0, 0.5, 0), { count = 4, color = COL.slag, shard = true, size = 0.35, speed = 5, up = 6, time = 2.2, groundY = groundUnder(p.model, at).Y })
		Fx.smoke(at, { color = COL.smoke, radius = 0.8, count = 4, life = { 0.8, 1.4 } })
		Fx.sfx("fxForgeCrustTail", at)
	end,
	-- Отливка: ступень выросла — огоньки по спирали, кольцо, искры; сброс — клинок шипит паром.
	castStage = function(p)
		local root = rootOf(p.caster)
		if not root then
			return
		end
		local stage = math.clamp(p.stage or 1, 0, 4)
		local feet = G(root.Position - V3(0, 3, 0))
		if p.grew then
			Fx.wisps(feet, { count = 2 + stage, color = COL.orange, radius = 1.2, rise = 3.5, time = 2, spin = 7, size = 0.18 })
			Kit.ringWave(feet + V3(0, 0.1, 0), 2.5 + stage * 0.4, COL.yellow, { time = 0.45, brightness = 3 })
			Fx.sparks(root.Position, { color = COL.yellow, count = 8, speed = { 4, 9 } })
			Fx.sfx("fxForgeStage", root.Position)
		else
			local hand = P.handPos(p.caster) or root.Position
			Fx.smoke(hand, { color = COL.steam, radius = 0.7, count = 6, lightInfluence = 0.5, accel = V3(0, 5, 0), life = { 0.8, 1.6 } })
			Fx.sfx("fxForgeStageLost", hand)
		end
	end,

	-- ===== Заливка =====
	-- Набор: жар втягивается в центр, ядро светится, земля темнеет.
	pourStart = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local waves = math.max(p.waves or 3, 1)
		local interval = p.interval or 0.22
		local build = math.max(waves * interval, 0.3)
		local center = G(p.position)
		stateOf(p.caster).pour = { waves = waves }
		Fx.inward(center + V3(0, 0.8, 0), 6, { color = COL.yellow, count = 30, time = build, speed = 12, streak = true, size = { 0.35, 0.1 } })
		Fx.scorch(center, 2 + (p.stage or 0) * 0.4, { life = build + 4, hot = COL.yellow, cool = COL.magmaCool, glow = build + 0.5, transparency = 0.25 })
		Fx.afterglow(center + V3(0, 1, 0), { color = COL.orange, time = build + 0.8, brightness = 4, range = 16 })
		Fx.sfx("fxForgePourBuild", center)
	end,
	-- Волна: кольцо (жёлтое → красное), фонтан искр, комья, расплавленный диск; последняя — кадр,
	-- швы лучами, дым и угли.
	pourWave = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 4.5
		local index = p.index or 1
		local st = stateOf(p.caster)
		local waves = st.pour and st.pour.waves or 3
		local k = math.clamp(index / waves, 0, 1)
		local ground = G(p.position)
		Kit.ringWave(ground + V3(0, 0.12, 0), radius, COL.yellow:Lerp(COL.red, k), { time = 0.5, brightness = 3.5 })
		fountain(ground + V3(0, 0.3, 0), 10 + index * 3, 14 + index * 3)
		Fx.debris(ground, { count = 2 + index, hot = COL.white, color = COL.slag, size = 0.35, speed = radius * 1.8, up = 12, time = 2.6 })
		Fx.sigil(ground, radius * 0.85, COL.orange, { image = "magma", time = 2.5, spin = 10, grow = 0.05, transparency = 0.35 })
		if index >= waves then
			st.pour = nil
			Fx.heroFrame(ground + V3(0, 1, 0), { color = COL.white, size = radius * 0.8, flash = 0.3, stop = 0.12, caster = p.caster, fov = 7, shake = 0.35, sparks = 22, ground = ground })
			for i = 1, 6 do
				local a = (i / 6) * TAU + rnd(-0.3, 0.3)
				Fx.seamPath(ground, V3(math.cos(a), 0, math.sin(a)), radius * rnd(0.8, 1.2), { hot = COL.yellow, cool = COL.magmaCool, life = 3.2, width = 0.4, jitter = 0.5 })
			end
			Fx.plume(ground, { time = 3, rate = 8, radius = 2, color = COL.smoke })
			Fx.embers(ground + V3(0, 0.3, 0), { time = 3, rate = 12, area = V3(radius, 0.3, radius) })
			Fx.afterglow(ground + V3(0, 1, 0), { color = COL.orange, time = 3, brightness = 5, range = radius * 3 })
			Fx.sfx("fxForgePourCrash", ground)
		else
			Fx.heroFrame(ground + V3(0, 0.8, 0), { color = COL.orange, size = radius * 0.5, sparks = 10, ring = false })
		end
	end,
	-- Пар: белый столб, дымка по земле, корка с гаснущими трещинами.
	pourSteam = function(p)
		if typeof(p.position) ~= "Vector3" then
			return
		end
		local radius = p.radius or 9
		local ground = G(p.position)
		Fx.plume(ground + V3(0, 0.5, 0), { time = 2.6, rate = 12, radius = radius * 0.25, color = COL.steam, lightInfluence = 0.5, transparency = { 0.5, 0.7, 1 }, accel = V3(0, 6, 0) })
		Fx.mist(ground, { radius = radius * 0.7, time = 3, color = COL.steam, rate = 5 })
		Fx.scorch(ground, radius * 0.6, { color = COL.slag, hot = COL.orange, cool = COL.slag, edgeImage = "crack", glow = 2, life = 5, transparency = 0.3 })
		Fx.sfx("fxForgeSteamTail", ground)
	end,
}

AbilityFxPlusForge.handlers = H

function AbilityFxPlusForge.forget(caster)
	local st = states[caster]
	if st then
		st.heat, st.breath, st.pour = nil, nil, nil
	end
	states[caster] = nil
end

return AbilityFxPlusForge
