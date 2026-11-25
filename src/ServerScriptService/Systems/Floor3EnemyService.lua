--!nonstrict
-- Floor3EnemyService
-- Поведение врагов этажа 3 «Псарни охоты» (Config/Enemies3). Подключение — как
-- у Floor2Service / Floor45Service: хук EnemyService.spawnHooks вешает на врага
-- onWindup / onStrike / onDamage / brain / onKilled, только для typeId этажа 3.
-- Клиенту — EnemyEvent с kind f3e* (Controllers/Floor3EnemyFx). Вышки, копья
-- ловчего с насеста, капканы и прочие ловушки карты — Floor3World (не тронут).
--
--   рог          загонщик раз за бой трубит: гончие рядом быстрее и короче
--                замахиваются; ловчий в III фазе трубит на всю арену
--   статусы      болас — замедление, силок / капкан / сети — обездвиживание
--                (Floor2Service.slow / root — общие статусы)
--   лужи         дёготь (tar: замедляет, как дёготь Кожевни) и дубильный
--                раствор (brine: жжёт) — свои, у Floor2Service их нет
--   конус        дубильщик плещет из ведра 3 с (как полив Садовницы)
--   шкура        чучело медведя: спереди урон вдвое меньше
--   сокол        летит по линии прицела и возвращается на перчатку
--   отскок       капканщик и сокольник отпрыгивают от игрока
--   Вожак своры  мини-босс (MiniBossService.register): вой со сворой из клеток,
--                аура своры, «Сорвался с цепи»
--   ловчий       на насесте (Floor3World ставит состояние phase) — своё
--                состояние perch, чтобы клиент играл Perch, а не сцену фазы

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enemies = require(Shared.Config.Enemies)
local Floor3 = require(Shared.Config.Floor3)
local FloorGeo = require(Shared.Floor.FloorGeo)
local Net = require(Shared.Net.Net)

local EnemyService = require(script.Parent.EnemyService)
local ProjectileService = require(script.Parent.ProjectileService)
local Floor2Service = require(script.Parent.Floor2Service)
local MiniBossService = require(script.Parent.MiniBossService)

local Floor3EnemyService = {}

local FEET = 3.0
local TICK = 0.1

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

local function playersIn(test)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = EnemyService.livingRoot(player)
		if root and test(root) then
			table.insert(list, { player = player, root = root })
		end
	end
	return list
end

local function attackOf(enemy, id: string)
	for _, attack in ipairs(EnemyService.availableAttacks(enemy)) do
		if attack.id == id then
			return attack
		end
	end
	return nil
end

-- ======================================================================
-- Последствия попадания
-- ======================================================================

local function applyOnHit(enemy, attack, player)
	if not player or not attack then
		return
	end
	if attack.root then
		Floor2Service.root(player, attack.root)
	end
	if attack.slow then
		Floor2Service.slow(player, attack.slow.mul, attack.slow.time)
	end
end

-- Свой многоцелевой удар: последствия накладываем сами, сигнал «hit» глушим.
local function resolveMany(enemy, attack, targets)
	local any = "out-of-range"
	enemy.suppressHitFx = true
	for _, target in ipairs(targets) do
		local result = EnemyService.resolveOnPlayer(enemy, attack, target.player)
		if result == "hit" then
			applyOnHit(enemy, attack, target.player)
			any = "hit"
		elseif any ~= "hit" then
			any = result
		end
	end
	enemy.suppressHitFx = false
	enemy.model:SetAttribute("LastAttackResult", any)
	return any
end

-- ======================================================================
-- Лужи: дёготь (tar) и дубильный раствор (brine)
-- ======================================================================

local HAZARD_TICK = { tar = 0.25, brine = 0.5 }
local BRINE = { pct = 0.03, time = 1.0 } -- жжёт, пока стоишь (доля здоровья в секунду)

local HAZARD = {
	tar = function(player)
		Floor2Service.slowFromPuddle(player, (Floor3.Traps.tar and Floor3.Traps.tar.slow) or 0.5)
	end,
	brine = function(player, hazard)
		Floor2Service.poison(player, hazard.pct or BRINE.pct, BRINE.time)
	end,
}

local hazards = {}
local hazardId = 0

function Floor3EnemyService.addHazard(kind: string, center: Vector3, radius: number, life: number, extra)
	life = math.min(life, 60)
	hazardId += 1
	local y = groundY(center.X, center.Z, center.Y)
	local hazard = {
		id = hazardId,
		kind = kind,
		center = Vector3.new(center.X, y, center.Z),
		radius = radius,
		untilT = now() + life,
		nextTick = {},
		pct = extra and extra.pct,
	}
	table.insert(hazards, hazard)
	fire({ kind = "f3ehazard", id = hazard.id, hazard = kind, position = hazard.center, radius = radius, life = life })
	return hazard
end

local function stepHazards(t: number)
	for index = #hazards, 1, -1 do
		local hazard = hazards[index]
		if t >= hazard.untilT then
			table.remove(hazards, index)
		else
			local apply = HAZARD[hazard.kind]
			local every = HAZARD_TICK[hazard.kind] or 0.5
			if apply then
				for _, hit in ipairs(playersIn(function(root)
					return flat(root.Position - hazard.center).Magnitude <= hazard.radius
						and math.abs(root.Position.Y - FEET - hazard.center.Y) < 3
				end)) do
					local nextAt = hazard.nextTick[hit.player] or 0
					if t >= nextAt then
						hazard.nextTick[hit.player] = t + every
						apply(hit.player, hazard)
					end
				end
			end
		end
	end
end

-- Убрать лужи внутри бокса { x0, y0, z0, x1, y1, z1 } или все (box = nil).
function Floor3EnemyService.clearHazards(box)
	for index = #hazards, 1, -1 do
		local c = hazards[index].center
		if not box or (c.X >= box[1] and c.X <= box[4] and c.Z >= box[3] and c.Z <= box[6]) then
			fire({ kind = "f3ehazardEnd", id = hazards[index].id })
			table.remove(hazards, index)
		end
	end
end

function Floor3EnemyService.sendHazardsTo(player)
	local remote = Net.get("EnemyEvent")
	if not remote then
		return
	end
	local t = now()
	for _, hazard in ipairs(hazards) do
		remote:FireClient(player, {
			kind = "f3ehazard",
			id = hazard.id,
			hazard = hazard.kind,
			position = hazard.center,
			radius = hazard.radius,
			life = math.max(hazard.untilT - t, 0.1),
		})
	end
end

-- Лужи в центрах зон атаки (горшок дёгтя свежевальщика).
local function puddlesAtZones(enemy, attack)
	local puddle = attack.puddle
	if not puddle then
		return
	end
	for _, center in ipairs(enemy.zoneCenters or {}) do
		Floor3EnemyService.addHazard(puddle.kind, center, puddle.radius or attack.radius, puddle.life)
	end
end

local function deathPuddle(enemy)
	local puddle = enemy.stats.traits and enemy.stats.traits.deathPuddle
	if puddle then
		Floor3EnemyService.addHazard(puddle.kind, enemy.position, puddle.radius, puddle.life)
	end
end

-- ======================================================================
-- Снаряды со своим исходом (болас — замедление, сокол — возврат)
-- ======================================================================

local function nearestPlayerTo(position: Vector3, maxDistance: number)
	local best, bestDistance = nil, maxDistance
	for _, player in ipairs(Players:GetPlayers()) do
		local root = EnemyService.livingRoot(player)
		if root then
			local d = (root.Position - position).Magnitude
			if d < bestDistance then
				best, bestDistance = player, d
			end
		end
	end
	return best
end

-- onEnd(result, position, player?) — когда снаряд исчез (hit / parried / dodged / wall / expired).
local function shoot(enemy, attack, root, options, onEnd)
	local origin = enemy.position + Vector3.new(0, enemy.stats.height * 0.65, 0) + enemy.facing * 0.6
	local target = enemy.aimPoint or root.Position
	enemy.aimPoint = nil
	local direction = target - origin
	if direction.Magnitude < 0.5 then
		return nil
	end
	local part = ProjectileService.fire(enemy.model, origin, direction.Unit, {
		speed = attack.projectileSpeed,
		damage = attack.damage,
		parryable = attack.telegraph == "parryable",
		source = enemy.stats.name,
		shooter = enemy,
		kind = attack.projectileKind,
		lifetime = options and options.lifetime or attack.projectileLife,
	})
	enemy.model:SetAttribute("LastAttackResult", "projectile")
	if part and onEnd then
		local done = false
		part:GetAttributeChangedSignal("ProjectileResult"):Connect(function()
			local result = part:GetAttribute("ProjectileResult")
			if done or result == "flying" then
				return
			end
			done = true
			local position = part.Position
			local player = (result ~= "wall" and result ~= "expired") and nearestPlayerTo(position, 6) or nil
			local ok, err = pcall(onEnd, result, position, player)
			if not ok then
				warn("[Floor3EnemyService] снаряд: " .. tostring(err))
			end
		end)
	end
	return part
end

-- ======================================================================
-- Общие куски поведения
-- ======================================================================

-- Шкура спереди (чучело медведя): как броня спереди этажей 4–5.
local function attachHide(enemy, cfg)
	local cosArc = math.cos(math.rad(cfg.arc / 2))
	local previous = enemy.onDamage
	enemy.onDamage = function(e, amount, attacker, info)
		if previous then
			amount = previous(e, amount, attacker, info) or amount
			if amount <= 0 then
				return 0
			end
		end
		local character = attacker and attacker.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or e.state == "stunned" or (info and info.reflected) then
			return amount
		end
		local to = unitOr(root.Position - e.position, e.facing)
		if e.facing:Dot(to) >= cosArc then
			fire({ kind = "f3ehide", model = e.model, position = e.position + Vector3.new(0, e.stats.height * 0.55, 0) + to * e.stats.radius })
			return amount * (1 - cfg.block)
		end
		return amount
	end
end

-- Отскок от игрока (капканщик, сокольник), как у следопыта этажа 2.
local function tryHop(e, t: number, root, distance: number?)
	local hop = e.stats.traits and e.stats.traits.hop
	if not hop or not root or not distance then
		return
	end
	if distance < hop.range and t >= (e.hopReadyAt or 0) and e.state ~= "windup" then
		e.hopReadyAt = t + hop.cooldown
		local away = unitOr(e.position - root.Position, -e.facing)
		if EnemyService.shove(e, away, hop.distance, hop.time) then
			fire({ kind = "f3ehop", model = e.model, position = e.position })
		end
	end
end

local function ready(e, attack, t: number): boolean
	if not attack then
		return false
	end
	return not attack.every or t - (e.attackUsedAt[attack.id] or -math.huge) >= attack.every
end

-- Рог: гончие в радиусе на time секунд быстрее (speed) и короче замахиваются (windup).
local buffed = {} -- [enemy] = { untilT, speed }
local function hornBuff(center: Vector3, horn, owner)
	local t = now()
	local count = 0
	for _, e in ipairs(EnemyService.all()) do
		if e.alive and e ~= owner and e.stats.typeId == "hound" and flat(e.position - center).Magnitude <= horn.radius then
			local entry = buffed[e]
			if not entry then
				entry = { speed = e.stats.speed }
				buffed[e] = entry
			end
			entry.untilT = math.max(entry.untilT or 0, t + horn.time)
			e.stats.speed = entry.speed * (1 + horn.speed)
			e.windupMul = horn.windup
			e.model:SetAttribute("F3HornUntil", entry.untilT)
			count += 1
		end
	end
	return count
end

local function stepBuffs(t: number)
	for e, entry in pairs(buffed) do
		if not e.alive or t >= entry.untilT then
			e.stats.speed = entry.speed
			e.windupMul = nil
			if e.model then
				e.model:SetAttribute("F3HornUntil", nil)
			end
			buffed[e] = nil
		end
	end
end

-- Сыграть рог: стоит blow секунд (состояние horn → анимация Horn), на 0,35 —
-- гончие получают бафф.
local function blowHorn(e, horn, blow: number, t: number)
	e.attack = nil
	e.forced = nil
	e.moveDir = Vector3.zero
	e.sceneUntil = t + blow
	e.model:SetAttribute("EnemyAttack", "horn")
	EnemyService.setState(e, "horn", blow)
	fire({ kind = "f3ehorn", model = e.model, position = e.position, radius = horn.radius, duration = horn.time })
	task.delay(math.min(0.45, blow * 0.35), function()
		if e.alive then
			hornBuff(e.position, horn, e)
		end
	end)
end

-- ======================================================================
-- Поведение по типам
-- ======================================================================

local attachers = {}
local active = {} -- враги с покадровой логикой

-- Гончая: рывок-укус и прыжок — штатные (dash / leap). Рог и аура своры
-- приходят снаружи (hornBuff, аура Вожака).
attachers.hound = function(_) end

-- Загонщик: рог раз за бой, когда видит игрока.
local function beater(enemy)
	local horn = enemy.stats.traits and enemy.stats.traits.horn
	if not horn then
		return
	end
	enemy.brain = function(e, t, player, root, distance)
		if e.hornUsed or not player or not distance or distance > 24 or t < (e.spawnUntil or 0) + 0.5 then
			return false
		end
		e.hornUsed = true
		blowHorn(e, horn, horn.blow or 1.6, t)
		return true
	end
end
attachers.beater = beater
attachers.beater_elite = beater

attachers.crossbowman = function(_) end -- болт: штатный снаряд (projectileKind = "huntbolt")

-- Капканщик: болас замедляет (свой снаряд), силок под ноги раз в every, отскок.
attachers.trapper = function(enemy)
	enemy.brain = function(e, t, player, root, distance)
		tryHop(e, t, root, distance)
		if player and root and t >= e.nextAttackAt then
			local snare = attackOf(e, "snare")
			if ready(e, snare, t) and distance <= 22 and distance >= 4 then
				e.hasSlot = true
				e.targetPlayer = player
				EnemyService.beginAttack(e, snare, player, root, t)
				return true
			end
		end
		return false
	end
	enemy.onStrike = function(e, attack, t, _, root)
		if attack.id ~= "bolas" or not root then
			return false
		end
		shoot(e, attack, root, nil, function(result, _, player)
			if result == "hit" and player then
				Floor2Service.slow(player, attack.slow.mul, attack.slow.time)
				fire({ kind = "f3ebolas", player = player })
			end
		end)
		EnemyService.startRecover(e, t)
		return true
	end
end

-- Сокольник: сокол летит по линии прицела и возвращается; вблизи — нож; отскок.
attachers.falconer = function(enemy)
	enemy.brain = function(e, t, player, root, distance)
		tryHop(e, t, root, distance)
		if player and root and t >= e.nextAttackAt then
			local knife = attackOf(e, "knife")
			if knife and distance <= (knife.range or 5) + 0.5 then
				e.hasSlot = true
				e.targetPlayer = player
				e.faceDir = unitOr(root.Position - e.position, e.facing)
				EnemyService.beginAttack(e, knife, player, root, t)
				return true
			end
			-- Сокол ещё не вернулся: держит дистанцию, не стреляет.
			if t < (e.falconBackAt or 0) then
				e.nextAttackAt = math.max(e.nextAttackAt, e.falconBackAt)
			end
		end
		return false
	end
	enemy.onStrike = function(e, attack, t, _, root)
		if attack.id ~= "release" or not root then
			return false
		end
		local range = (e.stats.shotRange or 34) + 6
		local life = range / math.max(attack.projectileSpeed or 42, 1)
		e.falconBackAt = t + life + 0.8
		fire({ kind = "f3efalcon", phase = "out", model = e.model })
		shoot(e, attack, root, { lifetime = life }, function(result, position)
			fire({ kind = "f3efalcon", phase = "back", model = e.model, position = position, result = result })
		end)
		EnemyService.startRecover(e, t)
		return true
	end
	enemy.onKilled = function(e)
		fire({ kind = "f3efalcon", phase = "drop", model = e.model, position = e.position })
	end
end

attachers.falcon = function(_) end -- пике и когти — штатные; парение — клиент (hover)
attachers.bear_hunter = function(_) end
attachers.bear_hunter_elite = function(_) end

-- Факельщик: взрыв бочонка — штатный (как у Треснувшего); на месте — лужа дёгтя.
attachers.torchbearer = function(enemy)
	enemy.onKilled = deathPuddle
end

-- Свежевальщик: горшок дёгтя (зона → лужа, замедление), лужа после смерти.
attachers.skinner = function(enemy)
	enemy.onStrike = function(e, attack)
		if attack.id == "tarPot" then
			puddlesAtZones(e, attack)
			fire({ kind = "f3elob", model = e.model, from = e.position + Vector3.new(0, e.stats.height * 0.7, 0), positions = e.zoneCenters })
		end
		return false
	end
	enemy.onKilled = deathPuddle
end

-- Дубильщик: плещет раствором из ведра channel секунд (конус, жжёт), за собой — лужи.
attachers.tanner = function(enemy)
	enemy.onWindup = function(e, attack, _, root)
		if attack.id == "pour" then
			local dir = root and unitOr(root.Position - e.position, e.facing) or e.facing
			e.pourDir = dir
			e.model:SetAttribute("F3Cone", ("%d,%.1f,%.3f,%.3f"):format(attack.cone, attack.length, dir.X, dir.Z))
		end
	end
	enemy.onStrike = function(e, attack, t)
		if attack.id ~= "pour" then
			return false
		end
		local dir = e.pourDir or e.facing
		e.pourDir = nil
		e.pour = { attack = attack, dir = dir, startT = t, untilT = t + attack.channel, nextTick = t, puddles = 0 }
		-- Серия «держится», пока льёт: stepStrike не уходит в восстановление.
		e.hitsLeft = 1
		e.nextHitAt = math.huge
		EnemyService.setState(e, "strike", attack.channel)
		e.model:SetAttribute("EnemyAttack", "pour")
		fire({ kind = "f3epour", model = e.model, direction = dir, cone = attack.cone, length = attack.length, duration = attack.channel })
		active[e] = true
		return true
	end
end

local function stepPour(e, t: number)
	local pour = e.pour
	if not pour then
		return
	end
	local attack = pour.attack
	if not e.alive or e.state ~= "strike" then
		e.pour = nil
		e.model:SetAttribute("F3Cone", nil)
		fire({ kind = "f3epourStop", model = e.model })
		return
	end
	e.faceDir = pour.dir
	e.moveDir = Vector3.zero
	if t >= pour.nextTick then
		pour.nextTick = t + 0.25
		local cosHalf = math.cos(math.rad(attack.cone / 2))
		for _, hit in ipairs(playersIn(function(root)
			local rel = flat(root.Position - e.position)
			local distance = rel.Magnitude
			if distance > attack.length + 0.8 or math.abs(root.Position.Y - FEET - e.position.Y) > 4 then
				return false
			end
			return distance < 1.2 or pour.dir:Dot(rel.Unit) >= cosHalf
		end)) do
			Floor2Service.poison(hit.player, attack.poison, attack.poisonTime)
		end
	end
	local k = (t - pour.startT) / attack.channel
	while pour.puddles < (attack.puddles or 0) and k >= (pour.puddles + 1) / (attack.puddles + 0.5) do
		pour.puddles += 1
		local distance = attack.length * (pour.puddles / (attack.puddles + 0.5))
		local side = Vector3.new(-pour.dir.Z, 0, pour.dir.X) * ((pour.puddles % 2 == 0) and 1 or -1) * math.min(distance * 0.2, 2)
		Floor3EnemyService.addHazard(attack.puddle.kind, e.position + pour.dir * distance + side, attack.puddle.radius, attack.puddle.life, { pct = attack.poison })
	end
	if t >= pour.untilT then
		e.pour = nil
		e.hitsLeft = 0
		e.model:SetAttribute("F3Cone", nil)
		fire({ kind = "f3epourStop", model = e.model })
		EnemyService.startRecover(e, t)
	end
end

-- Чучело медведя: шкура спереди; капкан (зона) — обездвиживание через сигнал попадания.
attachers.trophy_bear = function(enemy)
	attachHide(enemy, enemy.stats.traits.hide)
	enemy.onStrike = function(e, attack)
		if attack.id == "trap" then
			fire({ kind = "f3etrap", model = e.model, positions = e.zoneCenters, radius = attack.radius })
		end
		return false
	end
end

-- Королевский ловчий: сети (корни через сигнал попадания), рог III фазы,
-- состояние perch на насесте (см. start: обёртка EnemyService.setState).
attachers.royal_huntsman = function(enemy)
	enemy.onStrike = function(e, attack)
		if attack.id == "nets" then
			fire({ kind = "f3enets", model = e.model, positions = e.zoneCenters, radius = attack.radius })
		end
		return false
	end
	enemy.f3phaseSeen = 1
	active[enemy] = true
end

-- Покадрово: рог на входе в фазу с полем horn (ловчий, III фаза).
local function stepPhaseHorn(e, t: number)
	if not e.alive or (e.f3phaseSeen or 1) == e.phaseIndex then
		return
	end
	e.f3phaseSeen = e.phaseIndex
	local phase = e.stats.phases and e.stats.phases[e.phaseIndex - 1]
	local horn = phase and phase.horn
	if horn then
		-- Рог трубит в середине сцены фазы (маркер Horn анимации Phase3).
		local delay = math.max(0.2, (phase.sceneTime or 2) * 0.3)
		task.delay(delay, function()
			if e.alive then
				fire({ kind = "f3ehorn", model = e.model, position = e.position, radius = horn.radius, duration = horn.time, boss = true })
				hornBuff(e.position, horn, e)
			end
		end)
	end
end

-- ======================================================================
-- Вожак своры (мини-босс Псарни) — MiniBossService.register
-- ======================================================================

local function packLeader(zone, ctx)
	local cfg = Enemies.Types.pack_leader.miniboss
	local ctrl = { zone = zone, kind = "pack_leader", squad = {}, howls = 0 }
	local boss = ctx.spawn("pack_leader", zone.boss.at, { introDelay = ctx.intro })
	ctrl.boss = boss
	boss.hasSlot = true
	local baseSpeed = boss.stats.speed
	local comboPending = false
	local auraId = "pack_" .. tostring(zone.id)
	boss.model:SetAttribute("F3PackAura", cfg.auraRadius)

	local function howl(t: number)
		ctrl.howls += 1
		comboPending = false
		boss.attack = nil
		boss.forced = nil
		boss.moveDir = Vector3.zero
		boss.sceneUntil = t + cfg.howlTime
		boss.model:SetAttribute("EnemyAttack", "howl")
		EnemyService.setState(boss, "howl", cfg.howlTime)
		fire({ kind = "f3ehowl", model = boss.model, position = boss.position, radius = cfg.auraRadius, duration = cfg.howlTime })
		local squad = cfg.squad[math.min(ctrl.howls, #cfg.squad)]
		local gates = (zone.points and zone.points.squads) or {}
		task.delay(cfg.howlTime * 0.45, function()
			if not boss.alive or ctrl.stopped then
				return
			end
			local positions = {}
			for index, typeId in ipairs(squad) do
				local gate = #gates > 0 and gates[((index + ctrl.howls) % #gates) + 1] or (boss.position + Vector3.new(math.cos(index) * 8, 0, math.sin(index) * 8))
				local enemy = ctx.spawn(typeId, gate)
				if enemy then
					table.insert(ctrl.squad, enemy)
					table.insert(positions, gate)
				end
			end
			fire({ kind = "f3epack", model = boss.model, positions = positions })
		end)
	end

	boss.brain = function(enemy, t, player, root, distance)
		enemy.hasSlot = true
		local share = enemy.health / enemy.maxHealth
		if ctrl.howls < #cfg.howls and share <= cfg.howls[ctrl.howls + 1] then
			howl(t)
			return true
		end
		if not player then
			EnemyService.moveToward(enemy, Vector3.zero, 0, "idle")
			return true
		end
		local direction = unitOr(root.Position - enemy.position, enemy.facing)
		enemy.faceDir = direction
		enemy.targetPlayer = player

		-- Связка: после рывка — загрызание (во II фазе всегда, в I — через раз).
		if comboPending and enemy.lastAttackId == "rush" then
			local maul = MiniBossService.attackById(enemy, "maul")
			if maul and distance <= MiniBossService.reachOf(maul) + 2 then
				comboPending = false
				EnemyService.beginAttack(enemy, maul, player, root, t)
				return true
			end
			if t - (enemy.attackUsedAt.rush or 0) > 2.5 then
				comboPending = false
			end
			EnemyService.moveToward(enemy, direction, 1.3, "approach")
			return true
		end

		if t >= enemy.nextAttackAt then
			local options = {}
			for _, attack in ipairs(EnemyService.availableAttacks(enemy)) do
				local ok = not attack.comboOnly and ready(enemy, attack, t)
				if attack.id == enemy.lastAttackId and attack.id ~= "bite" then
					ok = false
				end
				if ok then
					if attack.dash then
						ok = distance >= 6 and distance <= (attack.line or 14) + 2
					elseif attack.leap then
						ok = distance >= 5 and distance <= 18
					else
						ok = distance <= MiniBossService.reachOf(attack)
					end
				end
				if ok then
					table.insert(options, attack)
				end
			end
			if #options > 0 then
				local attack = options[math.random(1, #options)]
				if attack.id == "rush" then
					comboPending = (enemy.phaseIndex or 1) >= 2 or math.random() < 0.5
				end
				EnemyService.beginAttack(enemy, attack, player, root, t)
				return true
			end
		end
		-- Обходит по дуге, как пёс, и сближается.
		if distance > 4.5 then
			local tangent = Vector3.new(-direction.Z, 0, direction.X) * enemy.circleSign
			local dir = distance > 12 and direction or (direction + tangent * 0.45).Unit
			EnemyService.moveToward(enemy, dir, 1, "approach")
		else
			EnemyService.moveToward(enemy, Vector3.zero, 0, "idle")
		end
		return true
	end

	ctrl.step = function(t: number)
		if not boss.alive then
			EnemyService.clearAura(auraId)
			return
		end
		-- Аура своры: союзники в радиусе бьют сильнее (центр — вожак).
		EnemyService.setAura(auraId, {
			center = boss.position,
			radius = cfg.auraRadius,
			damageMul = cfg.auraDamage,
			noStun = false,
			owner = boss,
		})
		-- «Сорвался с цепи» (II фаза): бег быстрее.
		if (boss.phaseIndex or 1) >= 2 then
			boss.stats.speed = baseSpeed * (1 + (cfg.chainSpeed or 0))
		end
	end

	ctrl.cleanup = function()
		ctrl.stopped = true
		EnemyService.clearAura(auraId)
		for _, enemy in ipairs(ctrl.squad) do
			if enemy.alive then
				EnemyService.kill(enemy, nil)
			end
		end
	end
	return ctrl
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
	stepHazards(t)
	stepBuffs(t)
	for enemy in pairs(active) do
		if not enemy.model or not enemy.model.Parent then
			active[enemy] = nil
		elseif enemy.frozenAt then
			-- «Дары Эха»: время стоит — особые действия врага тоже ждут
		else
			local ok, err = pcall(function()
				stepPour(enemy, t)
				stepPhaseHorn(enemy, t)
			end)
			if not ok then
				warn("[Floor3EnemyService] " .. tostring(enemy.stats.typeId) .. ": " .. tostring(err))
			end
		end
	end
end

-- Сигнал попадания: LastAttackResult → «hit» (сбрасываем в «none» на замахе).
local function watchHits(enemy)
	local previousWindup = enemy.onWindup
	enemy.onWindup = function(e, attack, player, root, t)
		e.model:SetAttribute("LastAttackResult", "none")
		if previousWindup then
			previousWindup(e, attack, player, root, t)
		end
	end
	enemy.model:GetAttributeChangedSignal("LastAttackResult"):Connect(function()
		if enemy.suppressHitFx or not enemy.alive then
			return
		end
		if enemy.model:GetAttribute("LastAttackResult") == "hit" then
			applyOnHit(enemy, enemy.attack, enemy.targetPlayer)
		end
	end)
end

local started = false
function Floor3EnemyService.start()
	if started then
		return
	end
	started = true
	MiniBossService.register("pack_leader", packLeader)
	table.insert(EnemyService.spawnHooks, function(enemy)
		local attach = attachers[enemy.stats.typeId]
		if attach then
			attach(enemy)
			watchHits(enemy)
			enemy.model:SetAttribute("Floor3", true)
		elseif enemy.stats.typeId == "pack_leader" then
			watchHits(enemy)
			enemy.model:SetAttribute("Floor3", true)
		end
	end)
	-- Насест ловчего: Floor3World ставит боссу состояние phase на время на
	-- насесте. Клиенту — своё состояние perch (анимация Perch, а не сцена фазы).
	-- Смена фазы боя идёт через внутренний setState EnemyService и сюда не попадает.
	local setState = EnemyService.setState
	EnemyService.setState = function(enemy, stateName, duration)
		if stateName == "phase" and enemy and enemy.stats and enemy.stats.typeId == "royal_huntsman" then
			stateName = "perch"
		end
		return setState(enemy, stateName, duration)
	end
	RunService.Heartbeat:Connect(heartbeat)
	print("[Floor3EnemyService] враги этажа 3: рог, болас, силки, сокол, дёготь, раствор, шкура, Вожак своры")
end

-- Для мира этажа и тестов.
Floor3EnemyService.resolveMany = resolveMany
Floor3EnemyService.playersIn = playersIn
Floor3EnemyService.applyOnHit = applyOnHit
Floor3EnemyService.hornBuff = hornBuff

return Floor3EnemyService
