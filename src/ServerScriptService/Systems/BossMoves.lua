--!nonstrict
-- BossMoves (сервер)
-- Фирменные атаки боссов (Config/BossMoves): по две на босса, тема этажа.
-- Подключение — как у Floor2Service / Floor45Service: хук EnemyService.spawnHooks
-- оборачивает уже повешенные onWindup / onStrike босса. Наша атака (поле
-- attack.move) после удара переводит босса в состояние channel (EnemyService:
-- стоит, затем обычное восстановление), а сама атака идёт по расписанию —
-- задания (after) и покадровые проверки (every) в своём Heartbeat.
--
-- Клиенту — EnemyEvent { kind = "bm", move = <kind>, phase = …, seq, t0 … }
-- (Controllers/BossMovesFx). Время — серверное (GetServerTimeNow): клиент
-- рисует от t0 и не зависит от задержки сети. Прервали атаку (оглушение,
-- смена фазы) — { kind = "bm", move = "cancel", seq }: всё, что игрок ещё не
-- видел, отменяется; уже показанное (тень решётки, летящее копьё) — доигрывает.
--
-- Попадания — EnemyService.resolveOnPlayer (уворот, неуязвимость, броня), без
-- парирования (telegraph = dodgeOnly). Последствия: slow / root (Floor2Service),
-- burn (Floor45Service), окаменение (корни + атрибут PetrifiedUntil), отброс.
--
-- Сцены появления боссов: хук разворачивает босса к игрокам (Config/BossIntros),
-- длительность сцены — FloorService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.BossMoves)
local BossIntros = require(Shared.Config.BossIntros)
local BossGeo = require(Shared.Util.BossGeo)
local FloorGeo = require(Shared.Floor.FloorGeo)

local EnemyService = require(script.Parent.EnemyService)
local Floor2Service = require(script.Parent.Floor2Service)
local Floor45Service = require(script.Parent.Floor45Service)

local BossMoves = {}

local FEET = 3.0
local NEAR = 90 -- игроки дальше от босса не участвуют
local TAU = math.pi * 2

local random = Random.new()

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function groundY(x: number, z: number, nearY: number): number
	return FloorGeo.groundAt(x, z, nearY + 1) or nearY
end

local function fire(payload)
	payload.kind = "bm"
	EnemyService.fireEvent(payload)
end

-- Живые игроки рядом с боссом: { player, root }.
local function playersNear(enemy, radius: number?)
	local list = {}
	local limit = radius or NEAR
	for _, player in ipairs(Players:GetPlayers()) do
		local root = EnemyService.livingRoot(player)
		if root and flat(root.Position - enemy.position).Magnitude <= limit then
			table.insert(list, { player = player, root = root })
		end
	end
	return list
end

-- ===== Расписание =====

local seqs = {} -- [id] = { id, enemy, attack, endsAt, cancelledAt }
local jobs = {} -- { at, fn, seq, visibleAt }
local tickers = {} -- { fn(t, dt) → true (дальше) | false, seq, bound, untilT }
local seqCounter = 0

local function newSeq(enemy, attack, duration: number)
	seqCounter += 1
	local seq = { id = seqCounter, enemy = enemy, attack = attack, endsAt = now() + duration, cancelledAt = nil }
	seqs[seq.id] = seq
	return seq
end

-- Задание через delay секунд. visibleAt — с какого момента игрок уже видит
-- эту часть атаки: если атаку прервали раньше, задание отменяется.
local function after(seq, delay: number, fn, visibleAt: number?)
	table.insert(jobs, { at = now() + delay, fn = fn, seq = seq, visibleAt = visibleAt })
end

-- Покадровая проверка до untilT. bound — прерывается вместе с атакой.
local function every(seq, untilT: number, fn, bound: boolean)
	table.insert(tickers, { fn = fn, seq = seq, untilT = untilT, bound = bound })
end

local function seqAlive(seq): boolean
	local enemy = seq.enemy
	return enemy.alive and enemy.attack == seq.attack and not seq.cancelledAt
end

local function stepSeqs(t: number)
	for id, seq in pairs(seqs) do
		if t > seq.endsAt + 8 then
			seqs[id] = nil
		elseif not seq.cancelledAt and t < seq.endsAt then
			local enemy = seq.enemy
			if not enemy.alive or enemy.attack ~= seq.attack then
				seq.cancelledAt = t
				fire({ move = "cancel", seq = seq.id, model = enemy.model })
				if seq.onCancel then
					pcall(seq.onCancel, t)
				end
			end
		end
	end
end

local function runJobs(t: number)
	local due = {}
	for index = #jobs, 1, -1 do
		local job = jobs[index]
		if t >= job.at then
			table.remove(jobs, index)
			table.insert(due, 1, job)
		end
	end
	for _, job in ipairs(due) do
		local seq = job.seq
		local skip = false
		if seq and seq.cancelledAt then
			skip = job.visibleAt == nil or seq.cancelledAt < job.visibleAt
		end
		if not skip then
			local ok, err = pcall(job.fn, t)
			if not ok then
				warn("[BossMoves] " .. tostring(err))
			end
		end
	end
end

local function runTickers(t: number, dt: number)
	for index = #tickers, 1, -1 do
		local ticker = tickers[index]
		local keep = t < ticker.untilT
		if keep and ticker.bound and ticker.seq and not seqAlive(ticker.seq) then
			keep = false
		end
		if keep then
			local ok, result = pcall(ticker.fn, t, dt)
			if not ok then
				warn("[BossMoves] " .. tostring(result))
				keep = false
			elseif result == false then
				keep = false
			end
		end
		if not keep then
			table.remove(tickers, index)
		end
	end
end

-- ===== Попадание =====

-- effects: slow = { mul, time }, root = сек, burn = { pct, time },
-- petrify = сек, knock = Vector3 (скорость отброса), mul — множитель урона.
local function hit(enemy, attack, player, root, effects)
	local fx = effects or {}
	local sub = {
		id = attack.id,
		damage = (attack.damage or 0) * (fx.mul or 1),
		telegraph = "dodgeOnly",
	}
	enemy.suppressHitFx = true
	local ok, result = pcall(EnemyService.resolveOnPlayer, enemy, sub, player)
	enemy.suppressHitFx = false
	if not ok then
		warn("[BossMoves] resolve: " .. tostring(result))
		return "error"
	end
	if result == "hit" then
		if fx.slow then
			Floor2Service.slow(player, fx.slow.mul, fx.slow.time)
		end
		if fx.root then
			Floor2Service.root(player, fx.root)
		end
		if fx.petrify then
			Floor2Service.root(player, fx.petrify)
			player:SetAttribute("PetrifiedUntil", now() + fx.petrify)
		end
		if fx.burn then
			Floor45Service.burn(player, fx.burn.pct, fx.burn.time)
		end
		if fx.knock and root and root.Parent then
			pcall(function()
				root.AssemblyLinearVelocity = fx.knock
			end)
		end
	end
	return result
end

local function feetAbove(root, floorY: number): number
	return (root.Position.Y - FEET) - floorY
end

-- ===== Общие точки =====

local function arenaOf(enemy)
	local home = enemy.home or enemy.position
	local cx, cz, r = BossGeo.arena(enemy.bounds, home.X, home.Z, 34)
	return { cx, cz, r }
end

local function targetPoint(enemy, root, margin: number)
	local arena = arenaOf(enemy)
	local p = root and root.Position or enemy.position
	local x, z = BossGeo.clampCircle(p.X, p.Z, arena[1], arena[2], arena[3], margin)
	return x, z, arena
end

local function dirTo(enemy, x: number, z: number): (number, number)
	local fx, fz = BossGeo.unit(x - enemy.position.X, z - enemy.position.Z, enemy.facing.X, enemy.facing.Z)
	return fx, fz
end

local function enterChannel(enemy, p)
	local duration = Config.channelTime(p)
	EnemyService.setState(enemy, "channel", duration)
	return duration
end

-- ======================================================================
-- Атаки
-- ======================================================================

local handlers = {}

-- ----- Привратник: «Решётки Хранилища» -----
-- Сетка 5×5 клеток вокруг цели, шахматкой падают опускные решётки: волна
-- роняет «чёрные» клетки, следующая — «белые». Тень клетки — за warn секунд.
handlers.gridDrop = {
	strike = function(e, attack, p, t, player, root)
		local x, z, arena = targetPoint(e, root, p.cell * 0.8)
		local fx, fz = dirTo(e, x, z)
		local y = groundY(x, z, e.position.Y)
		local cells = BossGeo.gridCells(x, z, fx, fz, p.cell, p.grid, arena)
		local channel = enterChannel(e, p)
		local seq = newSeq(e, attack, channel)
		fire({
			move = "gridDrop", seq = seq.id, model = e.model, t0 = t,
			center = Vector3.new(x, y, z), fwd = Vector3.new(fx, 0, fz), arena = arena,
			cell = p.cell, grid = p.grid, waves = p.waves, warn = p.warn, gap = p.gap,
			stay = p.stay, sink = p.sink, height = p.height,
		})
		for wave = 1, p.waves do
			local shownAt = t + (wave - 1) * p.gap
			after(seq, p.warn + (wave - 1) * p.gap, function()
				for _, target in ipairs(playersNear(e)) do
					local pos = target.root.Position
					for _, cell in ipairs(cells) do
						if BossGeo.cellDrops(cell.i, cell.j, wave) and BossGeo.inCell(pos.X, pos.Z, cell.x, cell.z, fx, fz, p.cell, p.inset) then
							hit(e, attack, target.player, target.root, { slow = { mul = 0.7, time = 0.6 } })
							break
						end
					end
				end
			end, shownAt)
		end
	end,
}

-- ----- Привратник: «Поворот ключа» -----
-- Меч входит в пол, как ключ в скважину: от босса поднимаются засовы и
-- поворачиваются вокруг него. Засов можно перепрыгнуть или уйти за радиус.
handlers.keyTurn = {
	strike = function(e, attack, p, t, player, root)
		local center = e.position
		local y = groundY(center.X, center.Z, center.Y)
		local toward = root and BossGeo.angleOf(root.Position.X - center.X, root.Position.Z - center.Z) or BossGeo.angleOf(e.facing.X, e.facing.Z)
		local a0 = toward + math.pi / p.bolts
		local spin = random:NextNumber() < 0.5 and -1 or 1
		local speed = math.rad(p.speed) * spin
		local channel = enterChannel(e, p)
		local seq = newSeq(e, attack, channel)
		fire({
			move = "keyTurn", seq = seq.id, model = e.model, t0 = t,
			center = Vector3.new(center.X, y, center.Z), a0 = a0, bolts = p.bolts, radius = p.radius,
			width = p.width, rise = p.rise, spin = p.spin, speed = speed,
		})
		local lastHit = {}
		local spinFrom = t + p.rise
		every(seq, spinFrom + p.spin, function(now_)
			if now_ < spinFrom then
				return true
			end
			local k = now_ - spinFrom
			local angles = BossGeo.boltAngles(a0, p.bolts, speed, k)
			-- Босс поворачивается вместе с ключом.
			local fx, fz = BossGeo.dirOf(toward + speed * k)
			e.faceDir = Vector3.new(fx, 0, fz)
			for _, target in ipairs(playersNear(e, p.radius + 2)) do
				local pos = target.root.Position
				if (lastHit[target.player] or -1e9) + p.hitGap <= now_ and feetAbove(target.root, y) < p.jumpClear then
					for _, angle in ipairs(angles) do
						if BossGeo.boltHit(pos.X, pos.Z, center.X, center.Z, angle, p.radius, p.width + 1.2) then
							lastHit[target.player] = now_
							-- Отброс по ходу засова.
							local ax, az = BossGeo.dirOf(angle + math.pi / 2 * spin)
							hit(e, attack, target.player, target.root, { knock = Vector3.new(ax * p.knock, 18, az * p.knock) })
							break
						end
					end
				end
			end
			return true
		end, true)
	end,
}

-- ----- Садовница: «Половодье» -----
-- Кольцевая волна воды от неё; два просвета под розовыми арками. Просветы
-- видны уже на замахе (лепестковые дорожки).
handlers.flood = {
	windup = function(e, attack, p, player, root, t)
		local toward = root and BossGeo.angleOf(root.Position.X - e.position.X, root.Position.Z - e.position.Z) or 0
		local first = toward + random:NextNumber(-0.65, 0.65)
		local gaps = { first }
		for index = 2, p.gaps do
			table.insert(gaps, first + (index - 1) * TAU / p.gaps + random:NextNumber(-0.4, 0.4))
		end
		e.bmFloodGaps = gaps
		local y = groundY(e.position.X, e.position.Z, e.position.Y)
		fire({
			move = "flood", phase = "mark", model = e.model, t0 = t, windup = e.windupDuration,
			center = Vector3.new(e.position.X, y, e.position.Z), gaps = gaps, gapWidth = math.rad(p.gapWidth), maxR = p.maxR,
		})
	end,
	strike = function(e, attack, p, t, player, root)
		local center = e.position
		local y = groundY(center.X, center.Z, center.Y)
		local gaps = e.bmFloodGaps or { 0, math.pi }
		e.bmFloodGaps = nil
		local channel = enterChannel(e, p)
		local seq = newSeq(e, attack, channel)
		local half = math.rad(p.gapWidth) / 2
		for wave = 1, p.waves do
			local waveGaps = {}
			for _, g in ipairs(gaps) do
				table.insert(waveGaps, g + (wave - 1) * math.pi / p.gaps)
			end
			local launch = t + (wave - 1) * p.waveGap
			local shownAt = t + math.max(0, (wave - 2)) * p.waveGap
			after(seq, (wave - 1) * p.waveGap, function()
				fire({
					move = "flood", phase = "wave", wave = wave, seq = seq.id, model = e.model, t0 = launch,
					center = Vector3.new(center.X, y, center.Z), gaps = waveGaps, gapWidth = math.rad(p.gapWidth),
					speed = p.speed, startR = p.startR, maxR = p.maxR, thick = p.thick,
					nextGaps = wave < p.waves and (function()
						local list = {}
						for _, g in ipairs(waveGaps) do
							table.insert(list, g + math.pi / p.gaps)
						end
						return list
					end)() or nil,
				})
				local hitSet = {}
				local untilT = launch + (p.maxR - p.startR) / p.speed
				every(seq, untilT, function(now_)
					local r = p.startR + p.speed * (now_ - launch)
					for _, target in ipairs(playersNear(e, p.maxR + 2)) do
						if not hitSet[target.player] then
							local pos = target.root.Position
							local dx, dz = pos.X - center.X, pos.Z - center.Z
							local d = math.sqrt(dx * dx + dz * dz)
							if BossGeo.ringHit(d, r, p.thick + 0.8) and not BossGeo.inGap(BossGeo.angleOf(dx, dz), waveGaps, half)
								and feetAbove(target.root, y) < 3.2 then
								hitSet[target.player] = true
								hit(e, attack, target.player, target.root, { slow = p.slow })
							end
						end
					end
					return true
				end, false)
			end, shownAt)
		end
	end,
}

-- ----- Садовница: «Мраморный взгляд» -----
-- Закрывает лицо, над ней открывается каменный глаз. Кто в миг вспышки
-- смотрит на неё (и видит её) — каменеет. Спасение — отвернуться.
handlers.gaze = {
	windup = function(e, attack, p, player, root, t)
		fire({ move = "gaze", phase = "mark", model = e.model, t0 = t, windup = e.windupDuration, range = p.range, pulses = p.pulses, pulseGap = p.pulseGap })
	end,
	strike = function(e, attack, p, t, player, root)
		local channel = enterChannel(e, p)
		local seq = newSeq(e, attack, channel)
		for pulse = 1, p.pulses do
			after(seq, (pulse - 1) * p.pulseGap, function(now_)
				local eye = e.position + Vector3.new(0, e.stats.height * 0.85, 0)
				local victims = {}
				for _, target in ipairs(playersNear(e, p.range)) do
					local pos = target.root.Position
					local look = target.root.CFrame.LookVector
					if BossGeo.looksAt(look.X, look.Z, pos.X, pos.Z, e.position.X, e.position.Z, p.cone)
						and not EnemyService.lineBlocked(e, eye, pos) then
						local result = hit(e, attack, target.player, target.root, { petrify = p.petrify })
						if result == "hit" then
							table.insert(victims, target.player)
						end
					end
				end
				fire({ move = "gaze", phase = "pulse", pulse = pulse, seq = seq.id, model = e.model, t0 = now_, victims = victims, petrify = p.petrify, last = pulse == p.pulses })
			end, pulse == 1 and t or nil)
		end
	end,
}

-- ----- Ловчий: «Королевская травля» -----
-- Рог — и призрачные гончие стаями бегут по полосам поперёк арены. Две
-- полосы пустые. Во II фазе — вторая волна поперёк первой.
handlers.houndDrive = {
	strike = function(e, attack, p, t, player, root)
		local channel = enterChannel(e, p)
		local seq = newSeq(e, attack, channel)
		local baseDir = nil
		local sign = random:NextNumber() < 0.5 and -1 or 1
		for wave = 1, p.waves do
			local startAt = (wave - 1) * p.waveGap
			after(seq, startAt, function(now_)
				local target = EnemyService.livingRoot(e.targetPlayer) or root
				local x, z = targetPoint(e, target, 6)
				local fx, fz = dirTo(e, x, z)
				if not baseDir then
					-- Первая волна бежит поперёк линии «ловчий → цель».
					baseDir = { fz * sign, -fx * sign }
				end
				local dx, dz = baseDir[1], baseDir[2]
				if wave % 2 == 0 then
					dx, dz = -baseDir[2], baseDir[1]
				end
				local y = groundY(x, z, e.position.Y)
				-- Две пустые полосы, но не та, где стоит цель.
				local laneOfTarget = target and BossGeo.laneOf(target.Position.X, target.Position.Z, x, z, dx, dz, p.lanes, p.laneWidth) or nil
				local safe = {}
				local pool = {}
				for lane = 1, p.lanes do
					if lane ~= laneOfTarget then
						table.insert(pool, lane)
					end
				end
				local a = table.remove(pool, random:NextInteger(1, #pool))
				safe[a] = true
				local rest = {}
				for _, lane in ipairs(pool) do
					if math.abs(lane - a) > 1 then
						table.insert(rest, lane)
					end
				end
				if #rest > 0 then
					safe[rest[random:NextInteger(1, #rest)]] = true
				end
				local safeList = {}
				for lane in pairs(safe) do
					table.insert(safeList, lane)
				end
				local runAt = now_ + p.warn
				fire({
					move = "houndDrive", phase = "wave", wave = wave, seq = seq.id, model = e.model, t0 = now_,
					center = Vector3.new(x, y, z), dir = Vector3.new(dx, 0, dz), lanes = p.lanes, laneWidth = p.laneWidth,
					length = p.length, safe = safeList, warn = p.warn, speed = p.speed, pack = p.pack,
				})
				local hitSet = {}
				local packLength = p.pack * 2.4
				every(seq, runAt + p.length / p.speed + 0.3, function(tick)
					if tick < runAt then
						return true
					end
					local front = -p.length / 2 + p.speed * (tick - runAt)
					for _, entry in ipairs(playersNear(e)) do
						if not hitSet[entry.player] then
							local pos = entry.root.Position
							local lane, along = BossGeo.laneOf(pos.X, pos.Z, x, z, dx, dz, p.lanes, p.laneWidth)
							if lane and not safe[lane] and along <= front + 1.2 and along >= front - packLength then
								hitSet[entry.player] = true
								hit(e, attack, entry.player, entry.root, { slow = p.slow, knock = Vector3.new(dx * 22, 14, dz * 22) })
							end
						end
					end
					return true
				end, false)
			end, wave == 1 and t or nil)
		end
	end,
}

-- ----- Ловчий: «Метка ловчего» -----
-- Красный прицел ходит за игроком, замирает — и в метку летит копьё.
handlers.huntMark = {
	strike = function(e, attack, p, t, player, root)
		local channel = enterChannel(e, p)
		local seq = newSeq(e, attack, channel)
		for mark = 1, p.marks do
			local startAt = (mark - 1) * p.period
			after(seq, startAt, function(now_)
				local victim = e.targetPlayer
				if not EnemyService.livingRoot(victim) then
					local list = playersNear(e)
					victim = list[1] and list[1].player
				end
				if not victim then
					return
				end
				local vRoot = EnemyService.livingRoot(victim)
				if vRoot then
					local fx, fz = dirTo(e, vRoot.Position.X, vRoot.Position.Z)
					e.faceDir = Vector3.new(fx, 0, fz)
				end
				fire({ move = "huntMark", phase = "mark", mark = mark, seq = seq.id, model = e.model, t0 = now_, follow = p.follow, player = victim, radius = p.radius })
				after(seq, p.follow, function(lockT)
					local lockRoot = EnemyService.livingRoot(victim)
					local pos = lockRoot and lockRoot.Position or (e.position + e.facing * 8)
					local y = groundY(pos.X, pos.Z, pos.Y - FEET)
					local at = Vector3.new(pos.X, y, pos.Z)
					local fx, fz = dirTo(e, at.X, at.Z)
					e.faceDir = Vector3.new(fx, 0, fz)
					fire({
						move = "huntMark", phase = "lock", mark = mark, seq = seq.id, model = e.model, t0 = lockT,
						position = at, flight = p.flight, radius = p.radius,
						from = e.position + Vector3.new(0, e.stats.height * 0.8, 0),
					})
					after(seq, p.flight, function(impactT)
						for _, entry in ipairs(playersNear(e)) do
							if flat(entry.root.Position - at).Magnitude <= p.radius then
								hit(e, attack, entry.player, entry.root, { root = p.pin })
							end
						end
						fire({ move = "huntMark", phase = "impact", mark = mark, seq = seq.id, model = e.model, t0 = impactT, position = at, radius = p.radius })
					end, lockT)
				end, now_ + p.follow)
			end, mark == 1 and t or nil)
		end
	end,
}

-- ----- Литейщик: «Раскалённая заготовка» -----
-- Слиток добела летит «блинчиком»: касания пола видны заранее, каждое —
-- брызги и лужа расплава. Во II фазе два слитка, в III — три веером.
local function ingotLines(e, p, root)
	local arena = arenaOf(e)
	local target = root and root.Position or (e.position + e.facing * 10)
	local fx, fz = dirTo(e, target.X, target.Z)
	local base = BossGeo.angleOf(fx, fz)
	local lines = {}
	for index = 1, p.fan do
		local offset = 0
		if p.fan > 1 then
			offset = math.rad(p.fanAngle) * ((index - 1) / (p.fan - 1) * 2 - 1)
		end
		local dx, dz = BossGeo.dirOf(base + offset)
		local pts = BossGeo.skipPoints(e.position.X, e.position.Z, dx, dz, p.skips, arena)
		local points = {}
		for _, pt in ipairs(pts) do
			table.insert(points, Vector3.new(pt.x, groundY(pt.x, pt.z, e.position.Y), pt.z))
		end
		table.insert(lines, { points = points, distances = (function()
			local list = {}
			for _, pt in ipairs(pts) do
				table.insert(list, pt.d)
			end
			return list
		end)() })
	end
	return lines
end

handlers.ingot = {
	windup = function(e, attack, p, player, root, t)
		local lockIn = (e.windupDuration or attack.windup) * p.lock
		after(nil, lockIn, function(now_)
			if e.attack ~= attack or not e.alive then
				return
			end
			local r = EnemyService.livingRoot(e.targetPlayer)
			local lines = ingotLines(e, p, r)
			e.bmIngot = lines
			local fx, fz = dirTo(e, lines[1].points[1].X, lines[1].points[1].Z)
			e.faceDir = Vector3.new(fx, 0, fz)
			e.lockFacingAt = now_
			local packed, dists = {}, {}
			for _, line in ipairs(lines) do
				table.insert(packed, line.points)
				table.insert(dists, line.distances)
			end
			fire({ move = "ingot", phase = "mark", model = e.model, t0 = now_, throwAt = e.stateUntil, lines = packed, dists = dists, speed = p.speed, radius = p.radius, lastRadius = p.lastRadius })
		end)
	end,
	strike = function(e, attack, p, t, player, root)
		local lines = e.bmIngot or ingotLines(e, p, root)
		e.bmIngot = nil
		local channel = enterChannel(e, p)
		local seq = newSeq(e, attack, channel)
		local origin = e.position + Vector3.new(0, e.stats.height * 0.7, 0)
		local packed, dists = {}, {}
		for _, line in ipairs(lines) do
			table.insert(packed, line.points)
			table.insert(dists, line.distances)
		end
		fire({ move = "ingot", phase = "throw", seq = seq.id, model = e.model, t0 = t, from = origin, lines = packed, dists = dists, speed = p.speed, radius = p.radius, lastRadius = p.lastRadius })
		for _, line in ipairs(lines) do
			for index, point in ipairs(line.points) do
				local last = index == #line.points
				local radius = last and p.lastRadius or p.radius
				after(seq, line.distances[index] / p.speed, function()
					for _, entry in ipairs(playersNear(e)) do
						if flat(entry.root.Position - point).Magnitude <= radius and feetAbove(entry.root, point.Y) < 2.5 then
							hit(e, attack, entry.player, entry.root, { burn = p.burn, mul = last and 1.2 or 1 })
						end
					end
					if p.puddle then
						Floor45Service.addHazard(p.puddle.kind, point, last and p.puddle.radius * 1.3 or p.puddle.radius, p.puddle.life)
					end
				end, t)
			end
		end
	end,
}

-- ----- Литейщик: «Дыхание горна» -----
-- Вдох: горн в груди разгорается, воздух (и игроки) тянется к нему. Выдох —
-- огненная нова вокруг. Тягу двигает клиент (атрибуты BossPull*).
local function clearPull(player)
	player:SetAttribute("BossPullUntil", 0)
end

handlers.bellows = {
	strike = function(e, attack, p, t, player, root)
		local center = e.position
		local y = groundY(center.X, center.Z, center.Y)
		local channel = enterChannel(e, p)
		local seq = newSeq(e, attack, channel)
		local pulled = {}
		local untilT = t + p.inhale
		seq.onCancel = function()
			for target in pairs(pulled) do
				clearPull(target)
			end
		end
		fire({
			move = "bellows", phase = "inhale", seq = seq.id, model = e.model, t0 = t,
			center = Vector3.new(center.X, y, center.Z), inhale = p.inhale, pullRadius = p.pullRadius, novaRadius = p.novaRadius,
		})
		every(seq, untilT, function()
			for _, entry in ipairs(playersNear(e, p.pullRadius)) do
				if not pulled[entry.player] then
					pulled[entry.player] = true
					entry.player:SetAttribute("BossPullAt", Vector3.new(center.X, y, center.Z))
					entry.player:SetAttribute("BossPullSpeed", p.pullSpeed)
					entry.player:SetAttribute("BossPullRadius", p.pullRadius)
					entry.player:SetAttribute("BossPullUntil", untilT)
				end
			end
			return true
		end, true)
		after(seq, p.inhale, function(now_)
			for target in pairs(pulled) do
				clearPull(target)
			end
			fire({ move = "bellows", phase = "nova", seq = seq.id, model = e.model, t0 = now_, center = Vector3.new(center.X, y, center.Z), radius = p.novaRadius, time = p.novaTime })
			for _, entry in ipairs(playersNear(e, p.novaRadius + 0.8)) do
				local away = flat(entry.root.Position - center)
				local dir = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
				hit(e, attack, entry.player, entry.root, { burn = p.burn, knock = dir * 34 + Vector3.new(0, 20, 0) })
			end
		end, t)
	end,
}

-- ----- Хронист: «Переписать прошлое» -----
-- Перо записывает путь цели: каждые sampleGap секунд — чернильный след.
-- Потом страница «переписывается»: следы взрываются по порядку.
handlers.rewind = {
	strike = function(e, attack, p, t, player, root)
		local channel = enterChannel(e, p)
		local seq = newSeq(e, attack, channel)
		local victim = player
		local marks = {}
		local popped = false
		local function startPops(at: number)
			if popped then
				return
			end
			popped = true
			fire({ move = "rewind", phase = "pops", seq = seq.id, model = e.model, t0 = at, pause = p.pause, popGap = p.popGap, count = #marks, radius = p.radius })
			for index, mark in ipairs(marks) do
				local delay = (at - now()) + p.pause + (index - 1) * p.popGap
				after(nil, math.max(delay, 0), function(popT)
					for _, entry in ipairs(playersNear(e)) do
						if flat(entry.root.Position - mark).Magnitude <= p.radius then
							hit(e, attack, entry.player, entry.root, { slow = p.slow })
						end
					end
					fire({ move = "rewind", phase = "pop", seq = seq.id, model = e.model, t0 = popT, index = index, position = mark, radius = p.radius })
				end)
			end
		end
		seq.onCancel = function(cancelT)
			startPops(cancelT)
		end
		fire({ move = "rewind", phase = "record", seq = seq.id, model = e.model, t0 = t, player = victim, samples = p.samples, sampleGap = p.sampleGap, radius = p.radius })
		for index = 1, p.samples do
			after(seq, index * p.sampleGap, function(now_)
				local vRoot = EnemyService.livingRoot(victim)
				if vRoot then
					local pos = vRoot.Position
					local mark = Vector3.new(pos.X, groundY(pos.X, pos.Z, pos.Y - FEET), pos.Z)
					table.insert(marks, mark)
					fire({ move = "rewind", phase = "mark", seq = seq.id, model = e.model, t0 = now_, index = #marks, position = mark, radius = p.radius })
				end
				if index == p.samples then
					startPops(now_)
				end
			end)
		end
	end,
}

-- ----- Хронист: «Глава закрыта» -----
-- Под ареной раскрыта гигантская книга, корешок — под Хронистом. Обложка
-- поднимается стеной и захлопывается на половину с игроком, затем другая —
-- на вторую половину. Полоса корешка безопасна.
handlers.bookSlam = {
	strike = function(e, attack, p, t, player, root)
		local center = e.position
		local y = groundY(center.X, center.Z, center.Y)
		local target = root and root.Position or (center + e.facing * 10)
		local fx, fz = dirTo(e, target.X, target.Z)
		-- Корешок поперёк линии «Хронист → цель»: цель — на своей половине.
		local sx, sz = fz, -fx
		local side = BossGeo.spineSide(target.X, target.Z, center.X, center.Z, sx, sz) >= 0 and 1 or -1
		local channel = enterChannel(e, p)
		local seq = newSeq(e, attack, channel)
		fire({
			move = "bookSlam", seq = seq.id, model = e.model, t0 = t,
			center = Vector3.new(center.X, y, center.Z), spine = Vector3.new(sx, 0, sz), side = side,
			width = p.width, halfLength = p.halfLength, spineWidth = p.spine,
			lift = p.lift, hold = p.hold, slam = p.slam, between = p.between,
		})
		for k = 1, 2 do
			local slamSide = k == 1 and side or -side
			local impact = Config.bookImpact(p, k)
			local shownAt = k == 1 and t or (t + Config.bookImpact(p, 1) + p.between)
			after(seq, impact, function()
				for _, entry in ipairs(playersNear(e)) do
					local pos = entry.root.Position
					if BossGeo.underCover(pos.X, pos.Z, center.X, center.Z, sx, sz, slamSide, p.width, p.halfLength, p.spine) then
						hit(e, attack, entry.player, entry.root, {})
					end
				end
			end, shownAt)
		end
	end,
}

-- ======================================================================
-- Подключение
-- ======================================================================

local function paramsFor(enemy, attack)
	return Config.params(attack.move, enemy.phaseIndex or 1)
end

local function attach(enemy)
	local list = Config.Moves[enemy.stats.typeId]
	if not list then
		return
	end
	enemy.home = enemy.home or enemy.position
	local previousWindup = enemy.onWindup
	local previousStrike = enemy.onStrike
	enemy.onWindup = function(e, attack, player, root, t)
		if previousWindup then
			previousWindup(e, attack, player, root, t)
		end
		local move = attack.move
		local handler = move and handlers[move.kind]
		if handler and handler.windup then
			local ok, err = pcall(handler.windup, e, attack, paramsFor(e, attack), player, root, t)
			if not ok then
				warn("[BossMoves] windup " .. tostring(move.kind) .. ": " .. tostring(err))
			end
		end
	end
	enemy.onStrike = function(e, attack, t, player, root)
		local move = attack.move
		local handler = move and handlers[move.kind]
		if handler then
			local ok, err = pcall(handler.strike, e, attack, paramsFor(e, attack), t, player, root)
			if not ok then
				warn("[BossMoves] strike " .. tostring(move.kind) .. ": " .. tostring(err))
				EnemyService.startRecover(e, t)
			end
			return true
		end
		if previousStrike then
			return previousStrike(e, attack, t, player, root)
		end
		return false
	end
end

-- Сцена появления: босс сразу смотрит на ближайшего игрока.
local function faceIntro(enemy)
	if not BossIntros.get(enemy.stats.typeId) then
		return
	end
	local best, bestD = nil, math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local root = EnemyService.livingRoot(player)
		if root then
			local d = flat(root.Position - enemy.position).Magnitude
			if d < bestD and d < 140 then
				best, bestD = root, d
			end
		end
	end
	if best then
		local dir = flat(best.Position - enemy.position)
		if dir.Magnitude > 0.1 then
			enemy.facing = dir.Unit
			enemy.faceDir = dir.Unit
			if enemy.root and enemy.root.Parent then
				local p = enemy.root.Position
				enemy.root.CFrame = CFrame.lookAt(p, p + dir.Unit)
			end
		end
	end
end

-- Отладка (DebugCommands «bossmove»): заставить босса начать атаку сейчас.
function BossMoves.force(enemy, attackId: string, player)
	if not enemy or not enemy.alive then
		return false, "нет босса"
	end
	-- Команды отладки приходят в нижнем регистре: сравниваем без регистра.
	local wanted = string.lower(attackId)
	local attack = nil
	for _, a in ipairs(EnemyService.availableAttacks(enemy)) do
		if string.lower(a.id) == wanted then
			attack = a
		end
	end
	if not attack then
		-- Атака более поздней фазы — из статов фаз (урон уже с масштабом этажа).
		for _, phase in ipairs(enemy.stats.phases or {}) do
			for _, a in ipairs(phase.attacks or {}) do
				if string.lower(a.id) == wanted then
					attack = a
				end
			end
		end
	end
	if not attack then
		local entry = nil
		for _, candidate in ipairs(Config.list(enemy.stats.typeId)) do
			if string.lower(candidate.attack.id) == wanted then
				entry = candidate
			end
		end
		if not entry then
			return false, "у босса нет атаки " .. attackId
		end
		attack = table.clone(entry.attack)
		attack.bossMove = true
	end
	local root = EnemyService.livingRoot(player)
	if not root then
		return false, "нет персонажа"
	end
	local t = now()
	enemy.spawnUntil = math.min(enemy.spawnUntil or 0, t)
	enemy.sceneUntil = 0
	enemy.stunUntil = 0
	EnemyService.beginAttack(enemy, attack, player, root, t)
	return true, attack.name or attack.id
end

-- Отладка: перечень атак босса.
function BossMoves.listFor(typeId: string): { string }
	local names = {}
	for _, entry in ipairs(Config.list(typeId)) do
		table.insert(names, ("%s (%s, фаза %d)"):format(entry.attack.id, entry.attack.name or "", entry.phase))
	end
	return names
end

local started = false
function BossMoves.start()
	if started then
		return
	end
	started = true
	table.insert(EnemyService.spawnHooks, function(enemy)
		if not enemy.stats.isBoss or enemy.stats.isMiniBoss then
			return
		end
		attach(enemy)
		faceIntro(enemy)
	end)
	local function hookCharacter(player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("BossPullUntil", 0)
			player:SetAttribute("PetrifiedUntil", 0)
		end)
	end
	Players.PlayerAdded:Connect(hookCharacter)
	for _, player in ipairs(Players:GetPlayers()) do
		hookCharacter(player)
	end
	RunService.Heartbeat:Connect(function(dt)
		local t = now()
		stepSeqs(t)
		runJobs(t)
		runTickers(t, dt)
	end)
	print("[BossMoves] фирменные атаки боссов: 10 атак, сцены появления")
end

return BossMoves
