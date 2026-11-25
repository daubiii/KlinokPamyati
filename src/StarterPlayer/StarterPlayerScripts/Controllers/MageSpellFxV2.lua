--!nonstrict
-- MageSpellFxV2 (клиент) — переделанные заклинания посохов (07.11.2026) по стандарту V2:
-- три такта, зона на полу в размер серверной, хит-стоп и тряска на главном ударе, свой звук на такт.
--   «Королевская ловля» (royal_hunt)   cast · net · spear · tear
--   «Призрачная стая»  (spirit_pack)  cast · surround · howl · bite · pounce
--   «Грибница»         (mycelium)     cast · seed · glade · exhale · burst
--   «Остановка времени» (time_stop)   + sweep · rewind (cast · freeze · strike — прежние, MageSpellFx)
-- Подключается из MageSpellFx (install), фазы сверяет tools/lua/test_mage_spells.lua с сервером
-- (Systems/WeaponAbilitiesMage.PHASES). Урон и цели решает сервер, здесь — «где и как красиво».

local Debris = game:GetService("Debris")

local Kit = require(script.Parent.Parent.Lib.MageFxKit)
local K = require(script.Parent.AbilityFx345Kit)
local V2 = require(script.Parent.AbilityFxV2).tools

local MageSpellFxV2 = {}

-- Заклинания, которые целиком рисует этот модуль (продлённые эффекты MageSpellFxPlus для них не идут).
MageSpellFxV2.OWNED = { royal_hunt = true, spirit_pack = true, mycelium = true }

local V3 = Vector3.new
local TAU = math.pi * 2
local WHITE = Color3.new(1, 1, 1)

local C = {
	gold = K.color("#FFD45A"),
	rope = K.color("#F2E3B3"),
	moon = K.color("#A8C8FF"),
	prey = K.color("#FF4A3A"),
	spirit = K.color("#6FFFD0"),
	spiritCore = K.color("#EAFFF8"),
	spiritDeep = K.color("#2FA88A"),
	spore = K.color("#C8E04A"),
	sporeCore = K.color("#FFFBD6"),
	poison = K.color("#8EE04A"),
	poisonDark = K.color("#3E6A22"),
	cap = K.color("#D8F070"),
	stem = K.color("#F4EEDC"),
	time = K.color("#6FE3FF"),
	timeCore = K.color("#F2FFFF"),
}

local function vec(value, fallback)
	if typeof(value) == "Vector3" then
		return value
	end
	return fallback
end

local function modelPos(model, fallback)
	local part = K.modelPart(model)
	return part and part.Position or fallback
end

local function track(ctx, instance)
	table.insert(ctx.cleanup, function()
		if instance and instance.Parent then
			instance:Destroy()
		end
	end)
	return instance
end

-- ===================== Волк стаи =====================
-- Лёгкий риг из неоновых деталей (ForceField — призрачный перелив), позу ставит set(cf, pose).
local WOLF_SCALE = 1.35
local WOLF_LIFT = 0.85 * WOLF_SCALE -- от земли до центра тела
local NECK = CFrame.new(0, 0.3, -0.7)
local WOLF = {
	{ "body", V3(0.8, 0.7, 1.7), CFrame.new(0, 0, 0.1) },
	{ "head", V3(0.62, 0.56, 0.66), CFrame.new(0, 0, -0.3) },
	{ "head", V3(0.34, 0.3, 0.5), CFrame.new(0, -0.14, -0.78) },
	{ "head", V3(0.16, 0.3, 0.14), CFrame.new(-0.19, 0.4, -0.22) },
	{ "head", V3(0.16, 0.3, 0.14), CFrame.new(0.19, 0.4, -0.22) },
	{ "eye", V3(0.1, 0.1, 0.06), CFrame.new(-0.15, 0.08, -0.64) },
	{ "eye", V3(0.1, 0.1, 0.06), CFrame.new(0.15, 0.08, -0.64) },
	{ "tail", V3(0.22, 0.22, 0.95), CFrame.new(0, 0.35, 1.15) * CFrame.Angles(math.rad(-25), 0, 0) },
	{ "leg", V3(0.18, 0.6, 0.18), CFrame.new(-0.25, -0.55, -0.5), 1 },
	{ "leg", V3(0.18, 0.6, 0.18), CFrame.new(0.25, -0.55, -0.5), 2 },
	{ "leg", V3(0.18, 0.6, 0.18), CFrame.new(-0.25, -0.55, 0.6), 3 },
	{ "leg", V3(0.18, 0.6, 0.18), CFrame.new(0.25, -0.55, 0.6), 4 },
}

local function newWolf(at: CFrame)
	local wolf = { parts = {}, alive = true, cf = at, legPhase = math.random() * TAU }
	for _, spec in ipairs(WOLF) do
		local kind = spec[1]
		local part = Kit.part({
			Name = "MageWolf",
			Size = spec[2] * WOLF_SCALE,
			Color = kind == "eye" and WHITE or (kind == "tail" and C.spirit or C.spirit:Lerp(C.spiritCore, 0.25)),
			Material = kind == "eye" and Enum.Material.Neon or Enum.Material.ForceField,
			Transparency = 1,
		})
		local offset = spec[3]
		table.insert(wolf.parts, { part = part, kind = kind, offset = CFrame.new(offset.Position * WOLF_SCALE) * offset.Rotation, leg = spec[4] })
	end
	local core = wolf.parts[1].part
	wolf.light = Kit.light(core, C.spirit, 2, 9)
	wolf.trail = Kit.emitter(core, { texture = "swirl", color = { C.spiritCore, C.spirit }, size = { 1.1, 0 }, rate = 18,
		life = { 0.3, 0.55 }, speed = { 0.5, 1.5 }, spread = 60, direction = Enum.NormalId.Back, transparency = { 0.4, 1 } })
	function wolf.set(cf: CFrame, pose)
		if not wolf.alive then
			return
		end
		pose = pose or {}
		wolf.cf = cf
		local pitch = math.rad(pose.head or 0)
		local stride = pose.run or 0
		for _, entry in ipairs(wolf.parts) do
			local local_ = entry.offset
			if entry.kind == "head" or entry.kind == "eye" then
				local_ = CFrame.new(NECK.Position * WOLF_SCALE) * CFrame.Angles(pitch, 0, 0) * entry.offset
			elseif entry.kind == "leg" then
				local swing = math.sin(wolf.legPhase + (entry.leg % 2 == 0 and math.pi or 0) + (entry.leg > 2 and math.pi or 0)) * 0.7 * stride
				local hip = CFrame.new(entry.offset.Position + V3(0, 0.3 * WOLF_SCALE, 0))
				local_ = hip * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -0.3 * WOLF_SCALE, 0)
			elseif entry.kind == "tail" then
				local_ = entry.offset * CFrame.Angles(math.sin(wolf.legPhase * 0.5) * 0.25 * (stride + 0.3), 0, 0)
			end
			entry.part.CFrame = cf * local_
		end
	end
	function wolf.opacity(alpha: number)
		for _, entry in ipairs(wolf.parts) do
			entry.part.Transparency = entry.kind == "eye" and (1 - alpha) or (1 - alpha * 0.85)
		end
	end
	function wolf.destroy(fade: number?)
		if not wolf.alive then
			return
		end
		wolf.alive = false
		wolf.trail.Enabled = false
		for _, entry in ipairs(wolf.parts) do
			if fade and fade > 0 then
				Kit.fade(entry.part, fade, { Size = entry.part.Size * 0.6 })
			else
				entry.part:Destroy()
			end
		end
	end
	wolf.set(at)
	return wolf
end

local function groundCF(position: Vector3, look: Vector3, lift: number?): CFrame
	local ground = K.ground(position, 0) + V3(0, lift or WOLF_LIFT, 0)
	local dir = K.flat(look)
	return CFrame.lookAt(ground, ground + dir)
end

function MageSpellFxV2.install(H, h)
	local dropCtx, feetOf, charge = h.dropCtx, h.feetOf, h.charge

	-- ===================== «Призрачная стая» =====================
	-- Состояние стаи живёт в ctx: волки, цель, режим (run / circle / bite / pounce).
	local function packCenter(ctx)
		return modelPos(ctx.model, ctx.target or V3())
	end

	local function startPack(p, ctx, from: Vector3, instant: boolean?)
		if ctx.wolves then
			return
		end
		ctx.model = p.model or ctx.model
		ctx.target = vec(p.target, vec(p.position, from))
		ctx.wolves = {}
		ctx.mode = instant and "circle" or "run"
		ctx.started = os.clock()
		ctx.runTime = p.runTime or 0.45
		ctx.orbit = math.random() * TAU
		local count = p.wolves or 4
		local center = packCenter(ctx)
		local look = K.flat(center - from)
		for i = 1, count do
			local side = Kit.rotate(look, (i - (count + 1) / 2) * 35)
			local start = instant and center + Kit.rotate(look, i * 90) * 2.6 or from + side * 1.6
			local wolf = newWolf(groundCF(start, look))
			wolf.start = start
			wolf.slot = i
			wolf.opacity(instant and 1 or 0)
			table.insert(ctx.wolves, wolf)
			table.insert(ctx.cleanup, function()
				wolf.destroy(0.3)
			end)
			if not instant then
				Kit.after(i * 0.04, function()
					Kit.flash(start + V3(0, 1, 0), C.spirit, 2.4, 0.2)
				end)
			end
		end
		ctx.radius = 2.6
		local appear = 0
		ctx.loop = K.loop(8, function(t, dt)
			if ctx.done then
				return false
			end
			appear = math.min(appear + dt / 0.15, 1)
			local center_ = packCenter(ctx)
			local runK = math.clamp((os.clock() - ctx.started) / ctx.runTime, 0, 1)
			ctx.orbit += dt * (ctx.mode == "circle" and 1.1 or 0.4)
			for _, wolf in ipairs(ctx.wolves) do
				if wolf.alive and not wolf.busy then
					wolf.legPhase += dt * (ctx.mode == "run" and 22 or 9)
					local angle = ctx.orbit + (wolf.slot - 1) * TAU / #ctx.wolves
					local slot = center_ + V3(math.cos(angle), 0, math.sin(angle)) * ctx.radius
					local pos, look, run, head
					if ctx.mode == "run" and runK < 1 then
						local e = 1 - (1 - runK) ^ 2
						pos = wolf.start:Lerp(slot, e)
						look = slot - wolf.start
						run = 1
					else
						pos = slot
						-- кружат боком к цели, мордой чуть внутрь
						look = Kit.rotate(K.flat(center_ - slot), -70)
						run = ctx.mode == "howl" and 0 or 0.55
					end
					head = ctx.mode == "howl" and -45 or (ctx.mode == "run" and 8 or 0)
					wolf.set(groundCF(pos, look), { run = run, head = head })
					wolf.opacity(appear)
				end
			end
			return true
		end)
		table.insert(ctx.cleanup, function()
			ctx.done = true
		end)
	end

	H.spirit_pack = {
		cast = function(p, ctx)
			local feet = K.ground(vec(p.position, feetOf(p.caster, V3())), 0.1)
			Kit.circle(feet, 3.5, C.spirit, { duration = 0.9, spin = 90, count = 8, star = 4, inner = C.spiritCore, appear = 0.12 })
			charge(p.caster, C.spirit, C.spiritCore, 0.3)
			startPack(p, ctx, feet, false)
			K.sound("mPackSummon", feet)
		end,
		surround = function(p, ctx)
			if not ctx.wolves then
				startPack(p, ctx, vec(p.position, V3()), true)
			end
			ctx.model = p.model or ctx.model
			ctx.mode = "circle"
			local center = packCenter(ctx)
			V2.groundZone(center, ctx.radius + 0.6, C.spirit, 1.4, { fill = 0.9, edge = 0.45 })
			if p.model then
				K.onModel("mPackPrey", p.model, "V2/PreyMark", 2.4, 1.2)
			end
			K.sound("v2PreyMarked", center)
		end,
		howl = function(p, ctx)
			if not ctx.wolves then
				startPack(p, ctx, vec(p.position, V3()), true)
			end
			ctx.mode = "howl"
			local center = K.ground(vec(p.position, packCenter(ctx)), 0.1)
			local radius = p.radius or 7
			V2.groundZone(center, radius, C.spirit, 0.9, { fill = 0.88, edge = 0.3 })
			Kit.ringWave(center, radius, C.spiritCore, { time = 0.5, brightness = 4 })
			Kit.shockwave(center + V3(0, 1.2, 0), radius * 0.6, C.spirit, { time = 0.45, flat = true, ground = center })
			for _, model in ipairs(p.feared or {}) do
				local top = K.above(model, 0.8)
				if top then
					Kit.burst(top, { texture = "swirl", color = { C.spiritCore, C.spirit }, size = { 1.2, 0 }, count = 6,
						life = { 0.4, 0.7 }, speed = { 2, 4 }, accel = V3(0, 4, 0) })
					V2.spawnAt("V2/Hit", top)
				end
			end
			V2.impact(p.caster, center, 0.4)
			K.sound("spellHowl", center)
			Kit.after(0.45, function()
				if ctx.mode == "howl" then
					ctx.mode = "circle"
				end
			end)
		end,
		bite = function(p, ctx)
			if not ctx.wolves then
				startPack(p, ctx, vec(p.position, V3()), true)
			end
			ctx.model = p.model or ctx.model
			ctx.mode = "circle"
			local wolf = ctx.wolves[((p.wolf or 1) - 1) % #ctx.wolves + 1]
			local target = modelPos(ctx.model, vec(p.position, V3()))
			if wolf and wolf.alive then
				wolf.busy = true
				local from = wolf.cf
				local to = groundCF(target + K.flat(from.Position - target) * 0.9, target - from.Position, WOLF_LIFT + 0.4)
				K.loop(0.2, function(t, dt)
					if not wolf.alive then
						return false
					end
					local k = math.clamp(t / 0.2, 0, 1)
					local e = k < 0.45 and (k / 0.45) or (1 - (k - 0.45) / 0.55)
					wolf.legPhase += dt * 30
					wolf.set(from:Lerp(to, e), { run = 1, head = -15 * e })
					if k >= 1 then
						wolf.busy = false
					end
					return k < 1
				end)
			end
			Kit.after(0.08, function()
				local at = target + V3(0, 1.4, 0)
				V2.spawnAt("V2/Bite", at)
				Kit.burst(at, { texture = "slash", color = { C.spiritCore, C.spirit }, size = { 1.6, 0 }, count = 3,
					life = { 0.15, 0.25 }, speed = { 4, 8 }, rotSpeed = { -400, 400 } })
				K.sound("spellBite", at)
				if (p.index or 1) % 2 == 0 then
					V2.hitStop(p.caster, 0.04)
				end
			end)
		end,
		pounce = function(p, ctx)
			if not ctx.wolves then
				startPack(p, ctx, vec(p.position, V3()), true)
			end
			ctx.model = p.model or ctx.model
			local target = modelPos(ctx.model, vec(p.position, V3()))
			ctx.mode = "pounce"
			for _, wolf in ipairs(ctx.wolves) do
				if wolf.alive then
					wolf.busy = true
					local from = wolf.cf
					local to = groundCF(target + K.flat(from.Position - target) * 0.4, target - from.Position, WOLF_LIFT + 0.6)
					K.loop(0.24, function(t)
						if not wolf.alive then
							return false
						end
						local k = math.clamp(t / 0.24, 0, 1)
						local arc = math.sin(k * math.pi) * 2.6
						wolf.set(from:Lerp(to, k) + V3(0, arc, 0), { run = 0.2, head = -20 })
						if k >= 1 then
							wolf.destroy(0.35)
						end
						return k < 1
					end)
				end
			end
			Kit.after(0.22, function()
				local at = target + V3(0, 1.2, 0)
				V2.spawnAt("V2/Crit", at)
				Kit.explosion(at, 3.2, C.spirit, { core = C.spiritCore, ground = K.ground(target, 0.1) })
				V2.impact(p.caster, target, 1)
				K.sound("mPackPounce", target)
				if ctx.model then
					K.offModel("mPackPrey", ctx.model)
				end
				ctx.done = true
				dropCtx(ctx)
			end)
		end,
	}

	-- ===================== «Королевская ловля» =====================
	local function buildNet(center: Vector3, radius: number)
		local parts = {}
		local spokes, rings = 10, { 0.45, 0.75, 1 }
		local y = 0.18
		local function rope(a: Vector3, b: Vector3, width: number)
			local mid = (a + b) / 2
			local length = (b - a).Magnitude
			local part = Kit.part({ Name = "MageNet", Size = V3(width, 0.08, length), Color = C.rope, Transparency = 1 })
			part.CFrame = CFrame.lookAt(mid, b)
			table.insert(parts, { part = part, mid = mid - center })
			return part
		end
		for i = 1, spokes do
			local a = (i - 1) * TAU / spokes
			rope(center + V3(0, y, 0), center + V3(math.cos(a) * radius, y, math.sin(a) * radius), 0.14)
		end
		for _, k in ipairs(rings) do
			local r = radius * k
			for i = 1, spokes do
				local a0, a1 = (i - 1) * TAU / spokes, i * TAU / spokes
				rope(center + V3(math.cos(a0) * r, y, math.sin(a0) * r), center + V3(math.cos(a1) * r, y, math.sin(a1) * r), 0.12)
			end
		end
		return parts
	end

	H.royal_hunt = {
		cast = function(p, ctx)
			local to = K.ground(vec(p.to, V3()), 0.1)
			local radius = p.radius or 6
			ctx.center = to
			V2.groundZone(to, radius, C.gold, (p.flight or 0.45) + 0.35, { fill = 0.92, edge = 0.4 })
			charge(p.caster, C.gold, WHITE, 0.3)
			K.sound("mHuntThrow", vec(p.from, to))
		end,
		net = function(p, ctx)
			local center = K.ground(vec(p.position, ctx.center or V3()), 0.05)
			local radius = p.radius or 6
			local hold = p.hold or 2
			ctx.center = center
			ctx.radius = radius
			ctx.models = p.models or {}
			-- сеть падает сверху и натягивается
			local net = buildNet(center, radius)
			ctx.net = net
			for _, entry in ipairs(net) do
				track(ctx, entry.part)
				local final = entry.part.CFrame
				entry.part.CFrame = final + V3(0, 3, 0)
				entry.part.Transparency = 0.15
				Kit.tween(entry.part, 0.16, { CFrame = final }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
			V2.groundZone(center, radius, C.gold, hold + 0.3, { fill = 0.9, edge = 0.3 })
			Kit.after(0.16, function()
				Kit.ringWave(center, radius, C.rope, { time = 0.35, brightness = 3 })
				Kit.burst(center + V3(0, 0.5, 0), { texture = "spark", color = { WHITE, C.gold }, size = { 0.4, 0 }, count = 26,
					life = { 0.3, 0.6 }, speed = { 6, 12 }, radius = radius * 0.6 })
				V2.impact(p.caster, center, 0.5)
				K.sound("mHuntNet", center)
			end)
			-- пойманные: метка добычи и подсветка
			for _, model in ipairs(ctx.models) do
				local state = K.onModel("mHuntNet", model, "V2/PreyMark", hold + 0.4, 1.2)
				K.highlight(state, model, C.gold, C.rope, 0.75)
			end
			-- сеть «дышит», пока держит
			local born = os.clock()
			K.loop(hold + 0.3, function()
				if ctx.torn then
					return false
				end
				local t = os.clock() - born
				for i, entry in ipairs(net) do
					if entry.part.Parent then
						entry.part.Transparency = 0.15 + 0.15 * (0.5 + 0.5 * math.sin(t * 6 + i * 0.4))
					end
				end
				return true
			end)
		end,
		spear = function(p, ctx)
			local to = K.ground(vec(p.position, ctx.center or V3()), 0)
			local from = vec(p.from, to + V3(0, 18, 0))
			local fall = p.fall or 0.18
			local radius = p.radius or 2.5
			V2.groundZone(to, radius, C.prey, fall + 0.25, { fill = 0.8, edge = 0.2, fadeIn = 0.05 })
			local dir = (to - from).Unit
			local shaft = Kit.part({ Name = "MageSpear", Size = V3(0.28, 0.28, 7), Color = C.gold, Transparency = 0.05 })
			local tip = Kit.part({ Name = "MageSpearTip", Size = V3(0.55, 0.55, 1.3), Color = WHITE, Transparency = 0 })
			Kit.trail(shaft, C.gold, { width = 0.6, life = 0.15 })
			local function place(pos: Vector3)
				shaft.CFrame = CFrame.lookAt(pos - dir * 3.6, pos)
				tip.CFrame = CFrame.lookAt(pos - dir * 0.2, pos + dir) * CFrame.Angles(0, 0, math.rad(45))
			end
			place(from)
			K.sound("mHuntSpearFall", to)
			Kit.every(fall, function(k)
				place(from:Lerp(to, k * k))
				return true
			end, function()
				place(to + dir * 1.2)
				local index = p.index or 1
				V2.spawnAt("V2/Hit", to + V3(0, 1, 0))
				Kit.explosion(to + V3(0, 0.6, 0), radius, C.gold, { core = WHITE, ground = to })
				Kit.glowSpot(to, radius * 0.8, C.gold, 1.2, { transparency = 0.3 })
				V2.impact(p.caster, to, index >= 3 and 1 or 0.6)
				K.sound("mHuntSpear", to)
				-- копьё торчит в земле и гаснет
				Kit.after(0.9, function()
					Kit.fade(shaft, 0.4)
					Kit.fade(tip, 0.4)
				end)
			end)
		end,
		tear = function(p, ctx)
			local center = K.ground(vec(p.position, ctx.center or V3()), 0.1)
			local radius = p.radius or ctx.radius or 6
			ctx.torn = true
			for _, entry in ipairs(ctx.net or {}) do
				local part = entry.part
				if part.Parent then
					local out = K.flat(entry.mid)
					Kit.tween(part, 0.35, { CFrame = part.CFrame + out * 2.5 + V3(0, 1.2, 0), Transparency = 1 })
				end
			end
			for _, model in ipairs(ctx.models or {}) do
				K.offModel("mHuntNet", model)
			end
			Kit.ringWave(center, radius, C.rope, { time = 0.4, brightness = 4 })
			Kit.burst(center + V3(0, 1, 0), { texture = "spark", color = { WHITE, C.rope }, size = { 0.35, 0 }, count = 30,
				life = { 0.3, 0.6 }, speed = { 8, 16 }, radius = radius * 0.5 })
			V2.impact(p.caster, center, 0.6)
			K.sound("mHuntTear", center)
			Kit.after(0.45, function()
				dropCtx(ctx)
			end)
		end,
	}

	-- ===================== «Грибница» =====================
	local function mushroom(position: Vector3, size: number, ctx)
		local base = K.ground(position, 0)
		local stem = Kit.part({ Name = "MageShroomStem", Material = Enum.Material.SmoothPlastic, Color = C.stem,
			Size = V3(0.3, 0.05, 0.3) * size, Transparency = 0 })
		stem.CFrame = CFrame.new(base)
		local cap = Kit.part({ Name = "MageShroomCap", Color = math.random() < 0.5 and C.cap or C.spore, Size = V3(0.1, 0.1, 0.1) })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = cap
		cap.CFrame = CFrame.new(base + V3(0, 0.1, 0))
		local height = (0.9 + math.random() * 0.6) * size
		local width = (1.1 + math.random() * 0.5) * size
		local grow = 0.25 + math.random() * 0.2
		Kit.tween(stem, grow, { Size = V3(0.3 * size, height, 0.3 * size), CFrame = CFrame.new(base + V3(0, height / 2, 0)) },
			Enum.EasingStyle.Back)
		Kit.tween(cap, grow, { Size = V3(width, width * 0.55, width), CFrame = CFrame.new(base + V3(0, height, 0)) }, Enum.EasingStyle.Back)
		local shroom = { stem = stem, cap = cap, top = base + V3(0, height, 0), width = width }
		track(ctx, stem)
		track(ctx, cap)
		table.insert(ctx.shrooms, shroom)
		return shroom
	end

	H.mycelium = {
		cast = function(p, ctx)
			local center = K.ground(vec(p.position, V3()), 0.1)
			local radius = p.radius or 7
			ctx.center = center
			ctx.radius = radius
			ctx.shrooms = {}
			local life = (p.exhaleAt or 1.1) + (p.cloudTime or 3) + 0.4
			V2.groundZone(center, radius, C.spore, life, { fill = 0.93, edge = 0.45 })
			charge(p.caster, C.spore, C.sporeCore, 0.35)
			K.sound("spellSpores", vec(p.from, center))
		end,
		seed = function(p, ctx)
			ctx.shrooms = ctx.shrooms or {}
			local at = K.ground(vec(p.position, V3()), 0.1)
			local radius = p.radius or 2.5
			Kit.burst(at + V3(0, 0.4, 0), { texture = "glow", color = { C.sporeCore, C.spore }, size = { 0.5, 0 }, count = 14,
				life = { 0.4, 0.8 }, speed = { 3, 7 }, accel = V3(0, -6, 0) })
			Kit.glowSpot(at, radius, C.poison, 1.2, { transparency = 0.35 })
			Kit.ringWave(at, radius, C.spore, { time = 0.3, brightness = 3 })
			for _ = 1, 2 do
				mushroom(at + V3(math.random() * 1.6 - 0.8, 0, math.random() * 1.6 - 0.8), 0.6, ctx)
			end
			K.sound("mSporeSeed", at)
		end,
		glade = function(p, ctx)
			ctx.shrooms = ctx.shrooms or {}
			local center = K.ground(vec(p.position, ctx.center or V3()), 0.1)
			local radius = p.radius or ctx.radius or 7
			ctx.center, ctx.radius = center, radius
			ctx.circle = Kit.circle(center, radius, C.poison, { duration = 4.5, spin = 12, count = 12, star = 6,
				inner = C.spore, fill = 0.85, brightness = 2 })
			for i = 1, 9 do
				local a = (i - 1) * TAU / 9 + math.random() * 0.5
				local r = radius * (0.25 + math.random() * 0.65)
				Kit.after(i * 0.03, function()
					mushroom(center + V3(math.cos(a) * r, 0, math.sin(a) * r), 0.9 + math.random() * 0.5, ctx)
				end)
			end
			Kit.burst(center + V3(0, 0.3, 0), { texture = "glow", color = { C.sporeCore, C.poison }, size = { 0.4, 0 }, count = 30,
				life = { 0.6, 1.1 }, speed = { 1, 3 }, radius = radius * 0.7, accel = V3(0, 2, 0) })
			K.sound("mGladeGrow", center)
		end,
		exhale = function(p, ctx)
			local center = K.ground(vec(p.position, ctx.center or V3()), 0.1)
			local radius = p.radius or ctx.radius or 7
			local duration = p.duration or 3
			-- облако: низкий густой дым + споры-искры, пятно яда на полу
			Kit.stream(CFrame.new(center + V3(0, 1, 0)), { texture = "smoke", color = { "#B6E05A", "#4E7A2A" }, size = { 3, 6 },
				life = { 1.2, 1.8 }, speed = { 0.4, 1.4 }, rate = 26, spread = 180, transparency = { 0.55, 1 },
				size3 = V3(radius * 1.7, 1.5, radius * 1.7), shape = Enum.ParticleEmitterShape.Box, lightEmission = 0.3,
				accel = V3(0, 0.6, 0), rotSpeed = { -30, 30 } }, duration)
			Kit.stream(CFrame.new(center + V3(0, 0.8, 0)), { texture = "star", color = { C.sporeCore, C.spore }, size = { 0.3, 0 },
				life = { 0.6, 1.2 }, speed = { 0.5, 2 }, rate = 30, size3 = V3(radius * 1.8, 1, radius * 1.8),
				shape = Enum.ParticleEmitterShape.Box, accel = V3(0, 1.5, 0) }, duration)
			Kit.glowSpot(center, radius, C.poisonDark, duration + 0.3, { transparency = 0.35 })
			Kit.shockwave(center + V3(0, 0.8, 0), radius, C.poison, { time = 0.5, flat = true, ground = center })
			-- грибы «дышат» на каждом тике (0,5 с)
			local ticks = math.floor(duration / 0.5)
			for i = 1, ticks do
				Kit.after(i * 0.5 - 0.25, function()
					for _, shroom in ipairs(ctx.shrooms or {}) do
						if shroom.cap.Parent then
							local size = shroom.cap.Size
							Kit.tween(shroom.cap, 0.12, { Size = size * 1.15 }).Completed:Connect(function()
								if shroom.cap.Parent then
									Kit.tween(shroom.cap, 0.2, { Size = size })
								end
							end)
							if math.random() < 0.35 then
								Kit.burst(shroom.top + V3(0, 0.3, 0), { texture = "smoke", color = { "#C8E04A", "#5A8A2A" }, size = { 1, 2.4 },
									count = 2, life = { 0.6, 1 }, speed = { 1.5, 3 }, transparency = { 0.4, 1 }, lightEmission = 0.3,
									direction = Enum.NormalId.Top, spread = 25 })
							end
						end
					end
					if i % 2 == 1 then
						K.sound("mExhalePuff", center)
					end
				end)
			end
			K.sound("mExhale", center)
		end,
		burst = function(p, ctx)
			local center = K.ground(vec(p.position, ctx.center or V3()), 0.1)
			local radius = p.radius or ctx.radius or 7
			for i, shroom in ipairs(ctx.shrooms or {}) do
				Kit.after(i * 0.025, function()
					if shroom.cap.Parent then
						Kit.flash(shroom.top, C.spore, shroom.width * 2.2, 0.18)
						Kit.burst(shroom.top, { texture = "glow", color = { C.sporeCore, C.poison }, size = { 0.5, 0 }, count = 10,
							life = { 0.3, 0.6 }, speed = { 6, 12 }, accel = V3(0, -12, 0) })
						shroom.cap:Destroy()
						Kit.fade(shroom.stem, 0.3, { Size = shroom.stem.Size * V3(1, 0.2, 1) })
					end
				end)
			end
			if ctx.circle then
				ctx.circle.fade(0.4)
			end
			Kit.ringWave(center, radius, C.spore, { time = 0.45, brightness = 4 })
			V2.impact(p.caster, center, 0.6)
			K.sound("mSporeBurst", center)
			K.sound("spellPop", center)
			Kit.after(0.6, function()
				dropCtx(ctx)
			end)
		end,
	}

	-- ===================== «Остановка времени»: стрелка и откат =====================
	local time = H.time_stop
	if time then
		time.sweep = function(p, ctx)
			local center = K.ground(vec(p.position, ctx.center or V3()), 0.1)
			local radius = p.radius or 10
			local sweepTime = p.time or 0.5
			local hands = ctx.hands
			if hands then
				-- полный оборот минутной стрелки за sweepTime (цикл рук крутит 7 рад/с × speed)
				hands.speed = (TAU / sweepTime) / 7
				Kit.after(sweepTime, function()
					if not hands.strike then
						hands.speed = 0
					end
				end)
			end
			local dir = K.flat(vec(p.dir, V3(0, 0, -1)))
			local start = math.atan2(dir.X, dir.Z)
			Kit.every(sweepTime, function(k)
				local a = start + k * TAU
				local tipPos = center + V3(math.sin(a), 0.4, math.cos(a)) * radius * 0.9
				Kit.burst(tipPos, { texture = "spark", color = { C.timeCore, C.time }, size = { 0.45, 0 }, count = 2,
					life = { 0.2, 0.35 }, speed = { 1, 3 } })
				return true
			end)
			Kit.ringWave(center, radius, C.time, { time = sweepTime, brightness = 2.5 })
			V2.hitStop(p.caster, 0.05)
			K.sound("mClockSweep", center)
		end
		time.rewind = function(p, _)
			local feet = vec(p.position, feetOf(p.caster, V3()))
			if not feet then
				return
			end
			local at = K.ground(feet, 0.1)
			-- маленький циферблат у ног крутится назад, зелёно-голубой подъём
			Kit.circle(at, 2.6, C.time, { duration = 0.9, spin = -540, roman = true, ticks = 12, inner = WHITE, appear = 0.1, fill = 0.7 })
			Kit.stream(CFrame.new(at + V3(0, 0.5, 0)), { texture = "star", color = { WHITE, C.time }, size = { 0.45, 0 },
				life = { 0.6, 0.9 }, speed = { 3, 6 }, rate = 50, direction = Enum.NormalId.Top, spread = 15,
				size3 = V3(2.4, 0.2, 2.4), shape = Enum.ParticleEmitterShape.Box }, 0.6)
			local amount = tonumber(p.amount) or 0
			if amount > 0 then
				local holder = Kit.holder(at + V3(0, 5.5, 0))
				local gui = Instance.new("BillboardGui")
				gui.Size = UDim2.fromOffset(120, 40)
				gui.AlwaysOnTop = true
				gui.LightInfluence = 0
				gui.Adornee = holder
				gui.Parent = holder
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromScale(1, 1)
				label.Font = Enum.Font.GothamBold
				label.TextScaled = true
				label.Text = "+" .. tostring(amount)
				label.TextColor3 = C.timeCore
				label.TextStrokeColor3 = Color3.fromRGB(20, 60, 70)
				label.TextStrokeTransparency = 0.2
				label.Parent = gui
				Kit.tween(holder, 1.1, { CFrame = holder.CFrame + V3(0, 2, 0) })
				Kit.tween(label, 1.1, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				Debris:AddItem(holder, 1.2)
			end
			K.sound("mRewind", at)
		end
	end
end

return MageSpellFxV2
