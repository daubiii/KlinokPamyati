--!nonstrict
-- AbilityFxHunt (клиент)
-- Эффекты оружия этажа 3 «Псарни охоты» (kind = "hunt"): Свора (призрачные гончие), Капкан (железные челюсти),
-- Последний гон (рывок-пронзание и рог), Пикирование (сокол), пассивки «Метка добычи» и «Сокол».
-- Сервер решает урон и цели; здесь только картинка. Шаблоны — FX.Hunt/* (Shared/Fx/FxWeapons345).

local Debris = game:GetService("Debris")

local K = require(script.Parent.AbilityFx345Kit)
local FxKit = K.FxKit
local V3 = Vector3.new

local AbilityFxHunt = {}

local GOLD = K.color("#FFD45A")
local PALE = K.color("#FFF1C9")
local PREY = K.color("#FF4A3A")
local IRON = K.color("#5E5866")
local IRON_EDGE = K.color("#B9B2C2")

-- ===== Свора =====

local packs = {} -- [caster] = { [index] = hound }
-- Продлённые фазы (AbilityFxPlusHunt) читают отсюда, где сейчас гончие, — следы лап за ними.
AbilityFxHunt.packs = packs

local function houndFade(hound)
	if hound.gone then
		return
	end
	hound.gone = true
	FxKit.spawn("Hunt/HoundFade", CFrame.new(hound.position))
	hound.fly.stop(0.8)
end

local function packSummon(payload)
	local caster = payload.caster
	local origin = K.ground(payload.position, 0.2)
	K.sound("huntPackHowl", origin)
	K.shake(origin, 0.12, 0.2)
	FxKit.spawn("Hunt/PackHowl", CFrame.new(origin), { radius = 3 })
	FxKit.shockwave(origin + V3(0, 1, 0), 5)

	local old = packs[caster]
	if old then
		for _, hound in pairs(old) do
			houndFade(hound)
		end
	end
	local set = {}
	packs[caster] = set
	local speed = payload.speed or 26
	local lifetime = (payload.lifetime or 4) + 1.5
	for _, info in ipairs(payload.hounds or {}) do
		local forward = K.flat(info.direction)
		local side = V3(-forward.Z, 0, forward.X)
		local lane = (info.index - (#payload.hounds + 1) / 2) * 1.6
		local start = origin + side * lane - forward * 0.8 + V3(0, 1.1, 0)
		local hound = {
			index = info.index,
			target = info.model,
			position = start,
			forward = forward,
			phase = math.random() * math.pi * 2,
			lungeT = -1,
			spawnT = os.clock(),
			born = os.clock(),
		}
		hound.fly = K.flyer("Hunt/Hound", CFrame.lookAt(start, start + forward), { life = lifetime })
		set[info.index] = hound
		-- Без цели — пробежать вперёд и раствориться.
		local runOut = not info.model
		K.loop(lifetime, function(t, dt)
			if hound.gone or hound.fly.stopped then
				return false
			end
			local goal
			local targetPart = K.modelPart(hound.target)
			if targetPart then
				-- Кружат вокруг добычи, каждая со своей стороны.
				local a = hound.phase + t * 2.4
				goal = targetPart.Position + V3(math.cos(a), 0, math.sin(a)) * 2.4
				goal = V3(goal.X, K.groundY(targetPart.Position) + 1.1, goal.Z)
			elseif runOut then
				goal = start + forward * speed * 0.7
				if (hound.position - goal).Magnitude < 1 then
					houndFade(hound)
					return false
				end
			else
				goal = hound.position
			end
			local delta = goal - hound.position
			local step = math.min(delta.Magnitude, speed * dt)
			if delta.Magnitude > 0.05 then
				hound.forward = K.flat(delta)
				hound.position += delta.Unit * step
			end
			-- Бег прыжками; рывок-укус — короткий выпад к цели.
			local hop = math.abs(math.sin(t * 13 + hound.phase)) * 0.55
			local lunge = 0
			local since = os.clock() - hound.lungeT
			if since < 0.2 and targetPart then
				lunge = math.sin(since / 0.2 * math.pi) * 1.4
				hound.forward = K.flat(targetPart.Position - hound.position)
			end
			local at = hound.position + hound.forward * lunge + V3(0, hop, 0)
			hound.fly.move(CFrame.lookAt(at, at + hound.forward))
			return true
		end)
		task.delay(lifetime, function()
			houndFade(hound)
			if packs[caster] == set then
				set[info.index] = nil
			end
		end)
	end
end

local function packRetarget(payload)
	local set = packs[payload.caster]
	local hound = set and set[payload.index]
	if hound then
		hound.target = payload.model
		K.sound("huntHoundSnarl", hound.position)
	end
end

local function packBite(payload)
	local set = packs[payload.caster]
	local hound = set and set[payload.index]
	local part = K.modelPart(payload.model)
	local at = part and part.Position or payload.position
	if hound then
		hound.lungeT = os.clock()
		hound.target = payload.model
	end
	if at then
		FxKit.spawn("Hunt/Bite", CFrame.new(at + V3(0, 0.6, 0)) * CFrame.Angles(0, math.random() * 6.28, 0))
		K.sound("huntBite", at)
	end
end

local function packFade(payload)
	local set = packs[payload.caster]
	local hound = set and set[payload.index]
	if hound then
		houndFade(hound)
		set[payload.index] = nil
	end
end

-- ===== Капкан =====

local snares = {} -- [caster] = { teeth, center, radius }

-- Кольцо железных зубьев: раскрыты наружу, на «щелчке» схлопываются к центру.
local function makeTeeth(center: Vector3, radius: number)
	local model = Instance.new("Model")
	model.Name = "SnareTeeth"
	local teeth = {}
	local count = math.clamp(math.floor(radius * 2.4), 10, 20)
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		local dir = V3(math.cos(a), 0, math.sin(a))
		local base = center + dir * radius
		local tooth = K.solid(V3(0.45, 1.6, 0.9), CFrame.lookAt(base, base + dir), IRON, Enum.Material.Metal, model)
		local edge = K.solid(V3(0.2, 1.2, 0.2), CFrame.new(), IRON_EDGE, Enum.Material.Neon, model)
		edge.Transparency = 0.2
		table.insert(teeth, { part = tooth, edge = edge, base = base, dir = dir })
	end
	model.Parent = FxKit.folder()
	return model, teeth
end

local function poseTeeth(teeth, open: number, rise: number)
	for _, t in ipairs(teeth) do
		-- open 1: наклон наружу 55°, 0: вертикально, < 0: к центру.
		local cf = CFrame.lookAt(t.base, t.base + t.dir) * CFrame.new(0, -0.9 + rise * 1.5, 0) * CFrame.Angles(math.rad(-55 * open), 0, 0) * CFrame.new(0, 0.8, 0)
		t.part.CFrame = cf
		t.edge.CFrame = cf * CFrame.new(0, 0.3, -0.42)
	end
end

local function snareOpen(payload)
	local center = K.ground(payload.position, 0)
	local radius = payload.radius or 6.5
	local snap = payload.snapDelay or 0.5
	K.sound("huntSnareOpen", center)
	FxKit.spawn("Hunt/SnareOpen", CFrame.new(center + V3(0, 0.15, 0)), { radius = radius, life = snap + 0.1 })
	local old = snares[payload.caster]
	if old and old.model.Parent then
		old.model:Destroy()
	end
	local model, teeth = makeTeeth(center, radius)
	local state = { model = model, teeth = teeth, center = center, radius = radius, opened = os.clock() }
	snares[payload.caster] = state
	poseTeeth(teeth, 1, 0)
	-- Зубья выныривают из земли.
	K.loop(snap, function(t)
		if not model.Parent or state.snapped then
			return false
		end
		local k = math.clamp(t / math.max(0.15, snap * 0.5), 0, 1)
		poseTeeth(teeth, 1, 1 - (1 - k) ^ 3)
		return true
	end)
	Debris:AddItem(model, snap + 2.5)
end

local function snareSnap(payload)
	local center = K.ground(payload.position, 0.15)
	local radius = payload.radius or 6.5
	K.sound("huntSnareSnap", center)
	K.shake(center, 0.3, 0.25)
	FxKit.spawn("Hunt/SnareSnap", CFrame.new(center), { radius = radius })
	local state = snares[payload.caster]
	if state and state.model.Parent then
		state.snapped = true
		local teeth, model = state.teeth, state.model
		K.loop(0.14, function(t)
			local k = math.clamp(t / 0.12, 0, 1)
			poseTeeth(teeth, 1 - 1.7 * k * k, 1)
			return true
		end)
		task.delay(0.9, function()
			if model.Parent then
				K.dissolve(model, 0.5)
			end
		end)
		snares[payload.caster] = nil
	end
	for _, model in ipairs(payload.targets or {}) do
		local s = K.onModel("snared", model, "Hunt/Snared", payload.root or 1.5)
		K.highlight(s, model, IRON_EDGE, GOLD, 0.85)
	end
end

-- ===== Последний гон =====

local function dash(payload)
	local origin = K.ground(payload.position, 0.2)
	local forward = K.flat(payload.direction)
	local length = payload.length or 10
	local time = payload.time or 0.25
	K.sound("huntDash", origin)
	K.fov(payload.caster, 8, 0.3)
	FxKit.spawn("Hunt/DashBurst", CFrame.lookAt(origin + V3(0, 1.2, 0), origin + V3(0, 1.2, 0) + forward))
	-- Серп-комета вдоль пути и двойная золотая лента по краям.
	-- Дух гона ведёт острие: светящееся ядро чуть впереди героя.
	local root = K.casterRoot(payload.caster)
	local tip = K.flyer("Hunt/Hound", CFrame.new(origin), { life = time + 0.15, trailScale = 1.4 })
	tip.part.Name = "DashComet"
	K.loop(time + 0.1, function(t)
		local k = math.clamp(t / time, 0, 1)
		local at = (root and root.Parent and root.Position or (origin + forward * length * k + V3(0, 2.6, 0))) + forward * 1.6
		tip.move(CFrame.lookAt(at, at + forward))
		return true
	end)
	local side = V3(-forward.Z, 0, forward.X)
	local half = payload.halfWidth or 2.2
	local spread = half / 2.2 -- ленты по краям полосы поражения
	for lane = -1, 1, 2 do
		K.ribbon("Hunt/DashTrail", lane < 0 and PALE or GOLD, 1.1 * spread, time, function(k)
			local center = origin + forward * (length * k) + V3(0, 1.8 + lane * 0.5, 0)
			return center + side * lane * 0.35 * spread, center + side * lane * 1.4 * spread + V3(0, -0.3, 0)
		end)
	end
	-- Коса: низкий золотой серп-мах в конце рывка — во всю ширину полосы.
	task.delay(time * 0.7, function()
		local finish = origin + forward * length
		K.arc(finish - forward * 1.5, forward, "Hunt/DashTrail", GOLD, 0.22, 200, 1, half + 1.4, 1.1, -0.4)
		K.arc(finish - forward * 1.5, forward, "Hunt/DashTrail", PALE, 0.2, 180, 0.8, half + 0.6, 1.5, -0.3)
		FxKit.shockwave(finish + V3(0, 1, 0), half + 1.5)
		K.shake(finish, 0.18, 0.2)
	end)
end

local function dashHit(payload)
	local played = false
	for _, model in ipairs(payload.targets or {}) do
		local part = K.modelPart(model)
		if part then
			FxKit.spawn("Hunt/DashHit", CFrame.new(part.Position) * CFrame.Angles(0, math.random() * 6.28, 0))
			if not played then
				played = true
				K.sound("huntPierce", part.Position)
				K.shake(part.Position, 0.22, 0.18)
			end
		end
	end
end

local function horn(payload)
	local center = K.ground(payload.position, 0.15)
	K.sound("huntHorn", center)
	K.shake(center, 0.15, 0.3)
	FxKit.spawn("Hunt/Horn", CFrame.new(center), { radius = payload.radius or 5.5 })
	FxKit.shockwave(center + V3(0, 1.2, 0), (payload.radius or 5.5) * 0.9)
end

-- ===== Пикирование и сокол =====

-- Сокол летит по дуге from → to за time: подъём, затем пике.
local function falconFlight(from: Vector3, to: Vector3, time: number, onArrive)
	local fly = K.flyer("Hunt/Falcon", CFrame.new(from), { life = time + 0.3 })
	local peak = math.max(from.Y, to.Y) + 5
	local lastAt = from
	K.loop(time, function(t)
		local k = math.clamp(t / time, 0, 1)
		local e = k * k * (3 - 2 * k)
		local flat = from:Lerp(to, e)
		-- Высота: парабола с вершиной в первой трети, затем крутое пике.
		local h = (k < 0.35) and (from.Y + (peak - from.Y) * math.sin(k / 0.35 * math.pi / 2)) or (peak + (to.Y - peak) * ((k - 0.35) / 0.65) ^ 2)
		local at = V3(flat.X, h, flat.Z)
		local dir = at - lastAt
		if dir.Magnitude > 0.01 then
			fly.move(CFrame.lookAt(at, at + dir))
		end
		lastAt = at
		if k >= 1 then
			fly.stop(0.6)
			if onArrive then
				onArrive(at)
			end
			return false
		end
		return true
	end)
	return fly
end

local function diveStart(payload)
	local point = K.ground(payload.position, 0.15)
	local time = payload.time or 0.5
	K.sound("huntFalconCry", payload.from or point)
	FxKit.spawn("Hunt/DiveMark", CFrame.new(point), { radius = payload.radius or 4.5, life = time })
	falconFlight(payload.from or (point + V3(0, 8, 0)), point + V3(0, 0.6, 0), time)
	K.ribbon("Hunt/Ribbon", GOLD, 1, time, function(k)
		local a = k * math.pi * 3
		local r = (payload.radius or 4.5) * (1 - k * 0.6)
		local p = point + V3(math.cos(a) * r, 0.25, math.sin(a) * r)
		return p, p + V3(0, 0.6 + k, 0)
	end)
end

local function diveImpact(payload)
	local point = K.ground(payload.position, 0.15)
	local radius = payload.radius or 4.5
	K.sound("huntDiveImpact", point)
	K.shake(point, 0.4, 0.3)
	FxKit.spawn("Hunt/DiveImpact", CFrame.new(point), { radius = radius })
	FxKit.shockwave(point + V3(0, 0.8, 0), radius)
	FxKit.spawn("Common/Dust", CFrame.new(point), { scale = radius / 9 })
end

local function preyMark(payload)
	local state = K.onModel("prey", payload.model, "Hunt/PreyMark", payload.duration or 4, 1.4)
	K.highlight(state, payload.model, PREY, PREY, 0.92)
	local at = K.above(payload.model, 1)
	if at then
		K.sound("huntPreyMark", at)
	end
end

local function preyKill(payload)
	local at = payload.position
	K.sound("huntPreyKill", at)
	FxKit.spawn("Hunt/PreyKill", CFrame.new(at + V3(0, 1.5, 0)))
end

local function falconStrike(payload)
	local part = K.modelPart(payload.model)
	local target = part and part.Position or payload.position
	if not target then
		return
	end
	local root = K.casterRoot(payload.caster)
	local from = (root and root.Position or target) + V3(math.random(-3, 3), 9, math.random(-3, 3))
	K.sound("huntFalcon", from)
	falconFlight(from, target + V3(0, 0.8, 0), math.max(0.18, payload.delay or 0.35), function(at)
		local now = K.modelPart(payload.model)
		FxKit.spawn("Hunt/FalconStrike", CFrame.new(now and now.Position or at) * CFrame.Angles(0, math.random() * 6.28, 0))
		K.sound("huntTalon", at)
	end)
end

AbilityFxHunt.handlers = {
	hunt = {
		packSummon = packSummon,
		packRetarget = packRetarget,
		packBite = packBite,
		packFade = packFade,
		snareOpen = snareOpen,
		snareSnap = snareSnap,
		dash = dash,
		dashHit = dashHit,
		horn = horn,
		diveStart = diveStart,
		diveImpact = diveImpact,
		preyMark = preyMark,
		preyKill = preyKill,
		falconStrike = falconStrike,
	},
}

return AbilityFxHunt
