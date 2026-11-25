--!nonstrict
-- MageBolts (сервер)
-- Полёт снарядов мага: обычные удары посоха и снаряды заклинаний (лепестки, споры,
-- волки, глифы, сферы памяти). Один цикл Heartbeat на все снаряды, как у
-- ProjectileService. Сервер решает, в кого попал снаряд; клиент (MageFx) рисует тот
-- же полёт по событию MageFx {kind = "bolt"} и взрыв по {kind = "boltEnd"}.
--
-- Снаряд летит плоско на высоте BoltHeight над ногами стрелка. Стены — лучом по
-- карте (FloorGeo), враги — по плоской дистанции до отрезка шага с учётом радиуса
-- врага и размера снаряда, только на своём уровне (пандусы и балконы этажей v2).
-- Навесной снаряд (lob) летит по дуге в точку и взрывается там (без столкновений).
--
-- spawn(spec): spec.owner, origin, dir, speed, size, range, style, homing (°/с),
--   pierce, lob = { to, time, height }, visual, echo, data (свободные поля);
--   onHit(bolt, enemy) — попадание (вернуть false, чтобы снаряд не засчитал цель);
--   onEnd(bolt, position, reason) — конец полёта: "hit" | "wall" | "range" | "land" | "prop";
--   onStep(bolt, from, to) — проверка декораций (вернуть true — снаряд разбился).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FloorGeo = require(Shared.Floor.FloorGeo)
local Net = require(Shared.Net.Net)

local EnemyService = require(script.Parent.EnemyService)

local MageBolts = {}

local FEET = 3.0
local HOMING_CONE = math.cos(math.rad(70)) -- самонаведение ищет цель в этом конусе
local HOMING_RANGE = 18
local MAX_BOLTS = 220

local active = {}
local nextId = 0
local loop = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function MageBolts.fx(payload)
	local remote = Net.get("MageFx")
	if remote then
		remote:FireAllClients(payload)
	end
end

local function sameLevel(enemy, feetY: number): boolean
	return math.abs(enemy.position.Y - feetY) <= math.max(4.5, enemy.stats.height * 0.7)
end

-- Плоская дистанция от точки p до отрезка a→b.
local function segmentDistance(p: Vector3, a: Vector3, b: Vector3): number
	local ab = flat(b - a)
	local ap = flat(p - a)
	local len2 = ab:Dot(ab)
	if len2 < 1e-6 then
		return ap.Magnitude
	end
	local t = math.clamp(ap:Dot(ab) / len2, 0, 1)
	return (ap - ab * t).Magnitude
end

-- Ближайший живой враг перед снарядом (для самонаведения).
local function acquire(bolt)
	local best, bestScore = nil, math.huge
	for _, enemy in ipairs(EnemyService.all()) do
		if enemy.alive and not bolt.hitSet[enemy] and sameLevel(enemy, bolt.feetY) and enemy.stats.role ~= "object" then
			local rel = flat(enemy.position - bolt.pos)
			local distance = rel.Magnitude
			if distance < HOMING_RANGE and distance > 0.2 then
				local dot = rel.Unit:Dot(bolt.dir)
				if dot >= HOMING_CONE then
					local score = distance * (1.6 - dot)
					if score < bestScore then
						best, bestScore = enemy, score
					end
				end
			end
		end
	end
	return best
end

-- Поворот плоского направления к цели не больше чем на maxAngle (радианы).
local function turnToward(dir: Vector3, want: Vector3, maxAngle: number): Vector3
	local a = math.atan2(dir.X, dir.Z)
	local b = math.atan2(want.X, want.Z)
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	local n = a + math.clamp(d, -maxAngle, maxAngle)
	return Vector3.new(math.sin(n), 0, math.cos(n))
end
MageBolts.turnToward = turnToward

local function finish(bolt, position: Vector3, reason: string)
	if bolt.done then
		return
	end
	bolt.done = true
	bolt.endPos = position
	if bolt.onEnd then
		local ok, err = pcall(bolt.onEnd, bolt, position, reason)
		if not ok then
			warn("[MageBolts] onEnd: " .. tostring(err))
		end
	end
	if not bolt.silent then
		MageBolts.fx({ kind = "boltEnd", id = bolt.id, position = position, reason = reason, style = bolt.style,
			splash = bolt.splashRadius, visual = bolt.visual })
	end
end

local function stepLob(bolt, t: number)
	local lob = bolt.lob
	local k = math.clamp((t - bolt.born) / lob.time, 0, 1)
	local from, to = bolt.origin, lob.to
	local pos = from:Lerp(to, k) + Vector3.new(0, lob.height * 4 * k * (1 - k), 0)
	bolt.pos = pos
	if k >= 1 then
		finish(bolt, to, "land")
	end
end

local function stepFlat(bolt, dt: number)
	-- Самонаведение: держим цель, пока жива и впереди; иначе ищем новую.
	if bolt.homing and bolt.homing > 0 then
		local target = bolt.target
		if not target or not target.alive or bolt.hitSet[target] then
			target = acquire(bolt)
			bolt.target = target
		end
		if target then
			local want = flat(target.position - bolt.pos)
			if want.Magnitude > 0.05 then
				bolt.dir = turnToward(bolt.dir, want.Unit, math.rad(bolt.homing) * dt)
			end
		end
	end

	local move = bolt.dir * bolt.speed * dt
	local from = bolt.pos
	local to = from + move

	-- Стена.
	local wall = FloorGeo.raycast(from, move)
	if wall then
		to = wall.Position - bolt.dir * 0.1
	end

	-- Враги на отрезке шага.
	local hitEnd = nil
	for _, enemy in ipairs(EnemyService.all()) do
		if enemy.alive and not bolt.hitSet[enemy] and sameLevel(enemy, bolt.feetY) then
			if segmentDistance(enemy.position, from, to) <= enemy.stats.radius + bolt.size then
				local counted = true
				if bolt.onHit then
					local ok, result = pcall(bolt.onHit, bolt, enemy)
					if not ok then
						warn("[MageBolts] onHit: " .. tostring(result))
					elseif result == false then
						counted = false
					end
				end
				if counted then
					bolt.hitSet[enemy] = true
					bolt.hits += 1
					if (bolt.pierce or 0) > 0 then
						bolt.pierce -= 1
						if not bolt.silent then
							MageBolts.fx({ kind = "boltHit", id = bolt.id, position = Vector3.new(enemy.position.X, from.Y, enemy.position.Z), style = bolt.style })
						end
					else
						hitEnd = Vector3.new(enemy.position.X, from.Y, enemy.position.Z)
						break
					end
				end
			end
		end
	end
	if hitEnd then
		bolt.pos = hitEnd
		finish(bolt, hitEnd, "hit")
		return
	end

	-- Декорации (ломаемые предметы этажей 3–5).
	if bolt.onStep then
		local ok, broke = pcall(bolt.onStep, bolt, from, to)
		if ok and broke then
			bolt.pos = to
			finish(bolt, to, "prop")
			return
		end
	end

	bolt.pos = to
	bolt.traveled += (to - from).Magnitude
	if wall then
		finish(bolt, to, "wall")
	elseif bolt.traveled >= bolt.range then
		finish(bolt, to, "range")
	end
end

local function heartbeat(dt: number)
	local t = now()
	local keep = {}
	for _, bolt in ipairs(active) do
		if not bolt.done then
			if bolt.owner and not bolt.owner.Parent then
				bolt.done = true
			elseif t >= bolt.born then
				if bolt.lob then
					stepLob(bolt, t)
				else
					stepFlat(bolt, math.min(dt, 0.1))
				end
			end
		end
		if not bolt.done then
			table.insert(keep, bolt)
		end
	end
	active = keep
	if #active == 0 and loop then
		loop:Disconnect()
		loop = nil
	end
end

local function ensureLoop()
	if not loop then
		loop = RunService.Heartbeat:Connect(heartbeat)
	end
end

function MageBolts.spawn(spec)
	if #active >= MAX_BOLTS then
		return nil
	end
	nextId += 1
	local dir = flat(spec.dir or Vector3.new(0, 0, -1))
	dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(0, 0, -1)
	local bolt = {
		id = nextId,
		owner = spec.owner,
		origin = spec.origin,
		pos = spec.origin,
		feetY = spec.feetY or (spec.origin.Y - (spec.height or 2.7)),
		dir = dir,
		speed = spec.speed or 60,
		size = spec.size or 0.45,
		range = spec.range or 28,
		traveled = 0,
		homing = spec.homing,
		pierce = spec.pierce or 0,
		target = spec.target,
		lob = spec.lob,
		style = spec.style or "arcane",
		visual = spec.visual,
		echo = spec.echo,
		splashRadius = spec.splashRadius,
		data = spec.data or {},
		onHit = spec.onHit,
		onEnd = spec.onEnd,
		onStep = spec.onStep,
		hitSet = {},
		hits = 0,
		born = now() + (spec.delay or 0),
		silent = spec.silent,
	}
	if spec.exclude then
		for _, enemy in ipairs(spec.exclude) do
			bolt.hitSet[enemy] = true
		end
	end
	table.insert(active, bolt)
	ensureLoop()
	if not bolt.silent then
		MageBolts.fx({
			kind = "bolt",
			id = bolt.id,
			caster = spec.owner,
			style = bolt.style,
			visual = bolt.visual,
			origin = bolt.origin,
			dir = bolt.dir,
			speed = bolt.speed,
			size = bolt.size,
			range = bolt.range,
			homing = bolt.homing,
			pierce = bolt.pierce,
			lob = bolt.lob,
			echo = bolt.echo,
			feetY = bolt.feetY,
			target = bolt.target and bolt.target.model or nil,
			t = bolt.born,
		})
	end
	return bolt
end

function MageBolts.count(): number
	return #active
end

function MageBolts.clear()
	for _, bolt in ipairs(active) do
		bolt.done = true
	end
	active = {}
end

MageBolts.FEET = FEET
MageBolts.segmentDistance = segmentDistance
MageBolts.sameLevel = sameLevel

return MageBolts
