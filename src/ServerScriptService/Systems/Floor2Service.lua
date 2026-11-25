--!nonstrict
-- Floor2Service (сервер)
-- Поведение врагов этажа 2 «Затопленные сады» поверх EnemyService (28.10.2026,
-- согласовано с Артёмом). Числа — Config/Enemies (traits и поля атак).
--
--   Древесный страж  кора спереди −50% урона; «Корни» — круг под игроком,
--                    попал — обездвижен
--   Утопленник       бросок тины — лужа (замедление); после смерти лужа
--   Садовник         «Полив гнилью» — конус 3 с (гниль, пока стоишь в нём)
--                    и лужи гнили по линии
--   Моховой следопыт три шипа веером; отскок от игрока; камуфляж в покое
--   Садовница        залп роз веером; корни тремя линиями (II фаза);
--                    призыв садовников; «Цветение» — гниль снаружи
--                    сжимающегося круга (III фаза)
--
-- Статусы игрока: замедление (множитель WalkSpeed), гниль (доля здоровья в
-- секунду, не убивает — оставляет 1), обездвиживание. Клиенту — атрибуты
-- игрока SlowUntil / PoisonUntil / RootedUntil, эффекты — события EnemyEvent
-- с kind "f2…" (клиентский Floor2Fx).
--
-- Подключение: хук EnemyService.spawnHooks — работает и для врагов из
-- DebugCommands (spawn treant 2), и для будущего FloorService этажа 2.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enemies = require(Shared.Config.Enemies)
local FloorGeo = require(Shared.Floor.FloorGeo)
local Net = require(Shared.Net.Net)

local EnemyService = require(script.Parent.EnemyService)
local ProjectileService = require(script.Parent.ProjectileService)
-- «Стойкость» (древо воина): дебафы на герое короче на 20%.
local TalentMods = require(script.Parent.TalentMods)

local Floor2Service = {}

local FEET = 3.0
local TICK = 0.1
local PUDDLE_SLOW_DURATION = 8

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function unitOr(v: Vector3, fallback: Vector3): Vector3
	local f = flat(v)
	if f.Magnitude < 0.001 then
		return fallback
	end
	return f.Unit
end

local function fire(payload)
	EnemyService.fireEvent(payload)
end

local function groundY(x: number, z: number, nearY: number): number
	return FloorGeo.groundAt(x, z, nearY + 1) or nearY
end

-- ======================================================================
-- Статусы игрока
-- ======================================================================

local status = {} -- [player] = { slowMul, slowUntil, poison, poisonUntil, rootUntil, base, jump, lastSet, nextPoison }

local function entryOf(player)
	local entry = status[player]
	if not entry then
		entry = { slowMul = 1, slowUntil = 0, poison = 0, poisonUntil = 0, rootUntil = 0, nextPoison = 0 }
		status[player] = entry
	end
	return entry
end

-- Замедление: скорость × mul на duration секунд (сильнейшее держится).
function Floor2Service.slow(player, mul: number, duration: number)
	duration *= TalentMods.debuffScale(player)
	local entry = entryOf(player)
	local t = now()
	if t >= entry.slowUntil or mul <= entry.slowMul then
		entry.slowMul = mul
	end
	entry.slowUntil = math.max(entry.slowUntil, t + duration)
	player:SetAttribute("SlowUntil", entry.slowUntil)
end

function Floor2Service.slowFromPuddle(player, mul: number)
	Floor2Service.slow(player, mul, PUDDLE_SLOW_DURATION)
end

-- Гниль: pct максимального здоровья в секунду на duration секунд. Не убивает.
function Floor2Service.poison(player, pct: number, duration: number)
	duration *= TalentMods.debuffScale(player)
	local entry = entryOf(player)
	local t = now()
	entry.poison = math.max(t < entry.poisonUntil and entry.poison or 0, pct)
	entry.poisonUntil = math.max(entry.poisonUntil, t + duration)
	if entry.nextPoison < t then
		entry.nextPoison = t + 0.5
	end
	player:SetAttribute("PoisonUntil", entry.poisonUntil)
end

-- Обездвиживание (корни): скорость и прыжок 0 на duration секунд.
function Floor2Service.root(player, duration: number)
	duration *= TalentMods.debuffScale(player)
	local entry = entryOf(player)
	entry.rootUntil = math.max(entry.rootUntil, now() + duration)
	player:SetAttribute("RootedUntil", entry.rootUntil)
end

local function stepStatus(t: number)
	for player, entry in pairs(status) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not player.Parent then
			status[player] = nil
			continue
		end
		if not humanoid or humanoid.Health <= 0 then
			continue
		end
		local rooted = t < entry.rootUntil
		local slowed = t < entry.slowUntil
		if rooted or slowed then
			-- Базовая скорость: если её поменял кто-то другой (стаки душ,
			-- уровень), берём новую — иначе вернули бы устаревшую.
			if not entry.base or (humanoid.WalkSpeed > 0 and humanoid.WalkSpeed ~= entry.lastSet) then
				if humanoid.WalkSpeed > 0 then
					entry.base = humanoid.WalkSpeed
					entry.jump = humanoid.JumpPower
				end
			end
			if entry.base then
				local speed = rooted and 0 or entry.base * entry.slowMul
				humanoid.WalkSpeed = speed
				entry.lastSet = speed
				if rooted then
					humanoid.JumpPower = 0
				elseif entry.jump then
					humanoid.JumpPower = entry.jump
				end
			end
		elseif entry.base then
			if humanoid.WalkSpeed == entry.lastSet then
				humanoid.WalkSpeed = entry.base
			end
			if entry.jump then
				humanoid.JumpPower = entry.jump
			end
			entry.base = nil
			entry.lastSet = nil
			entry.slowMul = 1
		end
		-- Гниль: тик раз в 0,5 с, не ниже 1 здоровья.
		if t < entry.poisonUntil and t >= entry.nextPoison then
			entry.nextPoison = t + 0.5
			if not player:GetAttribute("DebugGod") then
				local amount = humanoid.MaxHealth * entry.poison * 0.5
				humanoid.Health = math.max(1, humanoid.Health - amount)
			end
		end
	end
end

-- ======================================================================
-- Лужи (тина, мёд, вода — замедление; гниль и споры — яд)
-- ======================================================================

local hazards = {}
local hazardId = 0

local HAZARD = {
	mud = function(player)
		Floor2Service.slowFromPuddle(player, 0.7)
	end,
	rot = function(player)
		Floor2Service.poison(player, 0.04, 1.0)
	end,
	-- Этаж 2 (карта): медовая топь пасеки, мелкая вода купальни, облако спор.
	honey = function(player)
		Floor2Service.slowFromPuddle(player, 0.55)
	end,
	water = function(player)
		Floor2Service.slowFromPuddle(player, 0.82)
	end,
	spore = function(player)
		Floor2Service.poison(player, 0.05, 1.0)
	end,
}

-- life — сколько живёт лужа, с (постоянные лужи карты — до пересборки этажа).
function Floor2Service.addHazard(kind: string, center: Vector3, radius: number, life: number)
	life = math.min(life, 1e6)
	hazardId += 1
	local y = groundY(center.X, center.Z, center.Y)
	local hazard = { id = hazardId, kind = kind, center = Vector3.new(center.X, y, center.Z), radius = radius, untilT = now() + life }
	table.insert(hazards, hazard)
	fire({ kind = "f2hazard", id = hazard.id, hazard = kind, position = hazard.center, radius = radius, life = life })
	return hazard
end

local function playersIn(test)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = EnemyService.livingRoot(player)
		if root and test(root) then
			table.insert(list, player)
		end
	end
	return list
end

local nextHazardTick = 0
local function stepHazards(t: number)
	if t < nextHazardTick then
		return
	end
	nextHazardTick = t + 0.25
	for index = #hazards, 1, -1 do
		local hazard = hazards[index]
		if t >= hazard.untilT then
			table.remove(hazards, index)
		else
			local apply = HAZARD[hazard.kind]
			for _, player in ipairs(playersIn(function(root)
				return flat(root.Position - hazard.center).Magnitude <= hazard.radius
					and math.abs(root.Position.Y - FEET - hazard.center.Y) < 3
			end)) do
				apply(player)
			end
		end
	end
end

-- Игроку, вошедшему позже: все живые лужи (постоянные лужи карты).
function Floor2Service.sendHazardsTo(player)
	local remote = Net.get("EnemyEvent")
	if not remote then
		return
	end
	local t = now()
	for _, hazard in ipairs(hazards) do
		remote:FireClient(player, {
			kind = "f2hazard",
			id = hazard.id,
			hazard = hazard.kind,
			position = hazard.center,
			radius = hazard.radius,
			life = math.max(hazard.untilT - t, 0.1),
		})
	end
end

function Floor2Service.clearHazards()
	table.clear(hazards)
	fire({ kind = "f2hazardClear" })
end

-- ======================================================================
-- Общие удары
-- ======================================================================

-- Удар по зонам (корни, бросок тины): урон как у цепей Привратника + своё
-- последствие попадания. Состояние врага ведём сами (onStrike вернул true).
local function strikeZones(enemy, attack, t: number, onHit)
	local result = EnemyService.areaHit(enemy, attack)
	enemy.model:SetAttribute("LastAttackResult", result)
	fire({
		kind = "area",
		model = enemy.model,
		position = enemy.zoneCenters and enemy.zoneCenters[1] or enemy.position,
		positions = enemy.zoneCenters,
		radius = attack.radius,
		attack = attack.id,
	})
	if result == "hit" and onHit and enemy.targetPlayer then
		onHit(enemy.targetPlayer)
	end
	if not EnemyService.handleResult(enemy, attack, result, t) then
		EnemyService.startRecover(enemy, t)
	end
	return true
end

-- Веер снарядов (шипы следопыта, розы Садовницы): по зафиксированному прицелу.
local function fireSpread(enemy, attack, root)
	local origin = enemy.position + Vector3.new(0, enemy.stats.height * 0.6, 0) + enemy.facing * 0.8
	local target = enemy.aimPoint or root.Position
	enemy.aimPoint = nil
	local direction = target - origin
	if direction.Magnitude < 0.5 then
		return
	end
	direction = direction.Unit
	local count = attack.spread or 1
	local step = math.rad(attack.spreadAngle or 10)
	for index = 1, count do
		local angle = (index - (count + 1) / 2) * step
		local d = CFrame.Angles(0, angle, 0):VectorToWorldSpace(direction)
		ProjectileService.fire(enemy.model, origin, d, {
			speed = attack.projectileSpeed,
			damage = attack.damage,
			parryable = attack.telegraph == "parryable",
			source = enemy.stats.name,
			shooter = enemy,
			kind = attack.projectileKind,
		})
	end
	enemy.model:SetAttribute("LastAttackResult", "projectile")
end

-- ======================================================================
-- Поведение по типам
-- ======================================================================

local attachers = {}
local active = {} -- враги этажа 2 с покадровой логикой (полив, камуфляж, цветение)

attachers.treant = function(enemy)
	local traits = enemy.stats.traits
	local cosArc = math.cos(math.rad(traits.barkArc / 2))
	-- Кора: удар спереди режет урон вдвое (оглушённого — нет).
	enemy.onDamage = function(e, amount, attacker)
		local character = attacker and attacker.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or e.state == "stunned" then
			return amount
		end
		local to = unitOr(root.Position - e.position, e.facing)
		if e.facing:Dot(to) >= cosArc then
			fire({ kind = "f2bark", model = e.model, position = e.position + Vector3.new(0, e.stats.height * 0.55, 0) + to * e.stats.radius })
			return amount * (1 - traits.barkBlock)
		end
		return amount
	end
	enemy.onStrike = function(e, attack, t)
		if attack.id == "roots" then
			return strikeZones(e, attack, t, function(player)
				Floor2Service.root(player, attack.root)
			end)
		end
		return false
	end
end

attachers.drowned = function(enemy)
	enemy.onStrike = function(e, attack, t)
		if attack.id == "mudThrow" then
			local center = e.zoneCenters and e.zoneCenters[1]
			if center then
				Floor2Service.addHazard(attack.puddle.kind, center, attack.radius, attack.puddle.life)
			end
			return strikeZones(e, attack, t, function(player)
				Floor2Service.slow(player, 0.7, 1.5)
			end)
		end
		return false
	end
	enemy.onKilled = function(e)
		local puddle = e.stats.traits.deathPuddle
		Floor2Service.addHazard(puddle.kind, e.position, puddle.radius, puddle.life)
	end
end

attachers.gardener = function(enemy)
	enemy.onWindup = function(e, attack)
		if attack.id == "pour" then
			e.model:SetAttribute("F2Cone", ("%d,%.1f"):format(attack.cone, attack.length))
		end
	end
	enemy.onStrike = function(e, attack, t)
		if attack.id ~= "pour" then
			return false
		end
		e.pour = { attack = attack, dir = e.facing, startT = t, untilT = t + attack.channel, nextTick = t, puddles = 0 }
		-- Серия «держится», пока льёт: stepStrike не уходит в восстановление.
		e.hitsLeft = 1
		e.nextHitAt = math.huge
		EnemyService.setState(e, "strike", attack.channel)
		e.model:SetAttribute("EnemyAttack", "pour")
		e.model:SetAttribute("F2Cone", ("%d,%.1f"):format(attack.cone, attack.length))
		fire({ kind = "f2pour", model = e.model, direction = e.facing, cone = attack.cone, length = attack.length, duration = attack.channel })
		active[e] = true
		return true
	end
	active[enemy] = true
end

local function stepPour(e, t: number)
	local pour = e.pour
	if not pour then
		return
	end
	local attack = pour.attack
	if not e.alive or e.state ~= "strike" then
		e.pour = nil
		e.model:SetAttribute("F2Cone", nil)
		fire({ kind = "f2pourStop", model = e.model })
		return
	end
	e.faceDir = pour.dir
	e.moveDir = Vector3.zero
	if t >= pour.nextTick then
		pour.nextTick = t + 0.25
		local cosHalf = math.cos(math.rad(attack.cone / 2))
		for _, player in ipairs(playersIn(function(root)
			local rel = flat(root.Position - e.position)
			local distance = rel.Magnitude
			if distance > attack.length + 0.8 or math.abs(root.Position.Y - FEET - e.position.Y) > 4 then
				return false
			end
			return distance < 1.2 or pour.dir:Dot(rel.Unit) >= cosHalf
		end)) do
			Floor2Service.poison(player, attack.poison, attack.poisonTime)
		end
	end
	local k = (t - pour.startT) / attack.channel
	while pour.puddles < attack.puddles and k >= (pour.puddles + 1) / (attack.puddles + 0.5) do
		pour.puddles += 1
		local distance = attack.length * (pour.puddles / (attack.puddles + 0.5))
		local center = e.position + pour.dir * distance
		Floor2Service.addHazard(attack.puddle.kind, center, attack.puddle.radius, attack.puddle.life)
	end
	if t >= pour.untilT then
		e.pour = nil
		e.hitsLeft = 0
		e.model:SetAttribute("F2Cone", nil)
		fire({ kind = "f2pourStop", model = e.model })
		EnemyService.startRecover(e, t)
	end
end

attachers.ranger = function(enemy)
	local traits = enemy.stats.traits
	enemy.lastActiveAt = now()
	enemy.onStrike = function(e, attack, t, _, root)
		if attack.id ~= "thorns" or not root then
			return false
		end
		fireSpread(e, attack, root)
		EnemyService.startRecover(e, t)
		return true
	end
	-- Отскок: игрок подошёл ближе hop.range — прыжок назад (раз в hop.cooldown).
	enemy.brain = function(e, t, player, root, distance)
		local hop = traits.hop
		if player and root and distance and distance < hop.range and t >= (e.hopReadyAt or 0) then
			e.hopReadyAt = t + hop.cooldown
			local away = unitOr(e.position - root.Position, -e.facing)
			if EnemyService.shove(e, away, hop.distance, hop.time) then
				e.model:SetAttribute("F2HopAt", t)
				fire({ kind = "f2hop", model = e.model, position = e.position })
			end
		end
		return false
	end
	active[enemy] = true
end

local CAMO_STATES = { idle = true, circle = true }
local function stepCamo(e, t: number)
	local camo = e.stats.traits and e.stats.traits.camo
	if not camo then
		return
	end
	if not CAMO_STATES[e.state] or e.forced then
		e.lastActiveAt = t
	end
	local on = e.alive and (t - (e.lastActiveAt or t)) >= camo.after
	if (e.model:GetAttribute("F2Camo") == true) ~= on then
		e.model:SetAttribute("F2Camo", on)
	end
end

attachers.rosewarden = function(enemy)
	enemy.home = enemy.position
	enemy.onWindup = function(e, attack, _, root)
		if attack.id ~= "rootLines" or not root then
			return
		end
		local base = unitOr(root.Position - e.position, e.facing)
		local origin = e.position + Vector3.new(0, 1.5, 0)
		local lines, encoded = {}, {}
		for index = 1, attack.lines do
			local angle = math.rad((index - (attack.lines + 1) / 2) * attack.lineSpread)
			local d = flat(CFrame.Angles(0, angle, 0):VectorToWorldSpace(base)).Unit
			local length = attack.lineLength
			local wall = FloorGeo.raycast(origin, d * length)
			if wall then
				length = math.max(3, flat(wall.Position - origin).Magnitude - 0.5)
			end
			table.insert(lines, { dir = d, length = length })
			table.insert(encoded, ("%.3f,%.3f,%.1f"):format(d.X, d.Z, length))
		end
		e.rootLines = lines
		e.rootOrigin = e.position
		e.model:SetAttribute("F2LinesOrigin", e.position)
		e.model:SetAttribute("F2LinesWidth", attack.lineWidth)
		e.model:SetAttribute("F2Lines", table.concat(encoded, ";"))
	end
	enemy.onStrike = function(e, attack, t, player, root)
		if attack.id == "roseVolley" and root then
			fireSpread(e, attack, root)
			EnemyService.startRecover(e, t)
			return true
		end
		if attack.id == "rootLines" then
			local lines, origin = e.rootLines or {}, e.rootOrigin or e.position
			local result = "out-of-range"
			if root and player then
				local rel = flat(root.Position - origin)
				local inside = false
				for _, line in ipairs(lines) do
					local along = rel:Dot(line.dir)
					local side = (rel - line.dir * along).Magnitude
					if along > 0 and along < line.length + 0.6 and side <= attack.lineWidth / 2 + 0.8 then
						inside = true
					end
				end
				if inside and math.abs(root.Position.Y - FEET - origin.Y) < 4 then
					result = EnemyService.resolveOnPlayer(e, attack, player)
					if result == "hit" then
						Floor2Service.root(player, attack.root)
					end
				end
			end
			e.model:SetAttribute("LastAttackResult", result)
			e.model:SetAttribute("F2Lines", nil)
			fire({ kind = "f2rootLines", model = e.model, origin = origin, lines = lines, width = attack.lineWidth })
			e.rootLines = nil
			EnemyService.startRecover(e, t)
			return true
		end
		return false
	end
	-- Призыв садовников во II фазе. На настоящем этаже FloorService ставит
	-- свой onPhase (точки арены) после появления босса — он заменит этот.
	enemy.onPhase = function(e, _, phase)
		local summon = phase and phase.summon
		if not summon then
			return
		end
		for index = 1, summon.count do
			local angle = (index / summon.count) * math.pi * 2
			local position = e.position + Vector3.new(math.cos(angle) * 6, 0, math.sin(angle) * 6)
			local stats = Enemies.stats(summon.typeId, e.stats.difficulty)
			local minion = EnemyService.spawn(stats, position, { parent = e.model.Parent, room = e.room, bounds = e.bounds })
			minion.summoned = true
		end
	end
	-- Фаза «Цветение» (с порогом, где задан bloom): номер phaseIndex после входа.
	for index, phase in ipairs(enemy.stats.phases or {}) do
		if phase.bloom then
			enemy.bloomPhase = index + 1
			enemy.bloomCfg = phase.bloom
		end
	end
	active[enemy] = true
end

-- «Цветение»: снаружи сжимающегося круга (центр — где босс появился) гниль.
local function stepBloom(e, t: number)
	if not e.bloomPhase then
		return
	end
	if not e.alive then
		if e.bloom then
			e.bloom = nil
			e.model:SetAttribute("F2Bloom", nil)
			fire({ kind = "f2bloomStop", model = e.model })
		end
		return
	end
	if not e.bloom and (e.phaseIndex or 1) >= e.bloomPhase then
		local cfg = e.bloomCfg
		local center = e.home or e.position
		e.bloom = { start = t, nextTick = t, center = center }
		-- Клиенту: «x,y,z,от,до,время,начало» — круг рисуется по атрибуту
		-- (и у тех, кто вошёл в бой позже события).
		e.model:SetAttribute("F2Bloom", ("%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.3f"):format(
			center.X, center.Y, center.Z, cfg.startRadius, cfg.endRadius, cfg.shrinkTime, t))
		fire({ kind = "f2bloom", model = e.model, center = center, from = cfg.startRadius, to = cfg.endRadius, time = cfg.shrinkTime })
	end
	local bloom = e.bloom
	if bloom and t >= bloom.nextTick then
		bloom.nextTick = t + 0.5
		local cfg = e.bloomCfg
		local k = math.clamp((t - bloom.start) / cfg.shrinkTime, 0, 1)
		local radius = cfg.startRadius + (cfg.endRadius - cfg.startRadius) * k
		for _, player in ipairs(playersIn(function(root)
			local distance = flat(root.Position - bloom.center).Magnitude
			return distance > radius and distance < cfg.startRadius + 30
		end)) do
			Floor2Service.poison(player, cfg.poison, 1.0)
		end
	end
end

-- ======================================================================
-- Цикл и подключение
-- ======================================================================

local accum = 0
local function heartbeat(dt: number)
	accum += dt
	if accum < TICK then
		return
	end
	accum = 0
	local t = now()
	stepStatus(t)
	stepHazards(t)
	for enemy in pairs(active) do
		if not enemy.model or not enemy.model.Parent then
			if enemy.bloom then
				fire({ kind = "f2bloomStop", model = enemy.model })
			end
			active[enemy] = nil
		elseif enemy.frozenAt then
			-- «Дары Эха»: время стоит — особые действия врага тоже ждут
		else
			local ok, err = pcall(function()
				stepPour(enemy, t)
				stepCamo(enemy, t)
				stepBloom(enemy, t)
			end)
			if not ok then
				warn("[Floor2Service] " .. tostring(enemy.stats.typeId) .. ": " .. tostring(err))
			end
		end
	end
end

local started = false
function Floor2Service.start()
	if started then
		return
	end
	started = true
	table.insert(EnemyService.spawnHooks, function(enemy)
		local attach = attachers[enemy.stats.typeId]
		if attach then
			attach(enemy)
			enemy.model:SetAttribute("Floor2", true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		status[player] = nil
	end)
	local function hook(player)
		player.CharacterAdded:Connect(function()
			status[player] = nil
			player:SetAttribute("SlowUntil", 0)
			player:SetAttribute("PoisonUntil", 0)
			player:SetAttribute("RootedUntil", 0)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
	RunService.Heartbeat:Connect(heartbeat)
	print("[Floor2Service] враги этажа 2: кора, корни, лужи, полив, шипы, Садовница")
end

return Floor2Service
