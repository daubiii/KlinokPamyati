--!nonstrict
-- MiniBossService (сервер)
-- Мини-боссы этажа 1 v2 (концепт floor1-v2-concept.md, разделы 4–5) поверх
-- машины состояний EnemyService: свой «мозг» (enemy.brain), свои правила урона
-- (enemy.onDamage), свои удары (enemy.onStrike).
--
--   Сотник ворот (Барбакан)
--     «Стена щита»: удар спереди (сектор 120°) ослаблен на 85% (II фаза — 60%),
--     сзади — полный. Разворот медленный (90°/с): заход рывком за спину.
--     Парирование удара щитом — стойка сломана 3 с, урон по нему ×1,5.
--     Натиск → клевец (во II фазе — всегда). Удар знаменем по кругу, пока
--     знамя за спиной. Рог сбора на 70% и 35%: знамя в гнездо (цель 60 HP),
--     аура R 12 (+25% урона союзникам, не оглушаются), отряд из решёток.
--     Знамя срублено — 4 с «потерял строй»: замахи ×1,3.
--
--   Арбалетчица (двор северной башни, переделка 08.11.2026)
--     Три насеста на высоте 8 вокруг двора, под каждым светящаяся подпора.
--     На насесте: прицельный болт, залп по зонам, цепной болт (круг у ног —
--     пригвождает), с 3-го насеста капканы. Урон по ней на насесте ×0,6.
--     Подпора сломана → насест рушится, она падает и 4 с оглушена (×1,5),
--     затем крюком на следующий насест. После третьего — бой на земле:
--     приклад, отскок и выстрел, капканы, «Последний болт» на 25%.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enemies = require(Shared.Config.Enemies)
local FloorGeo = require(Shared.Floor.FloorGeo)
local Net = require(Shared.Net.Net)

local EnemyService = require(script.Parent.EnemyService)
-- «Стойкость» (древо воина): дебафы на герое короче на 20%.
local TalentMods = require(script.Parent.TalentMods)

local MiniBossService = {}

local controllers = {} -- [zoneId] = ctrl
local loop = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function unitOr(v: Vector3, fallback: Vector3): Vector3
	local f = flat(v)
	if f.Magnitude < 1e-3 then
		return fallback
	end
	return f.Unit
end

local function floorEvent(payload)
	local remote = Net.get("FloorEvent")
	if remote then
		remote:FireAllClients(payload)
	end
end

local function attackById(enemy, id: string)
	for _, attack in ipairs(EnemyService.availableAttacks(enemy)) do
		if attack.id == id then
			return attack
		end
	end
	return nil
end

local function reachOf(attack): number
	if attack.radius and not attack.zones then
		return attack.radius + 2
	end
	return (attack.range or 6) * 0.8 + 1
end

-- ======================================================================
-- Сотник ворот
-- ======================================================================

local function centurion(zone, ctx)
	local cfg = Enemies.Types.centurion.miniboss
	local ctrl = { zone = zone, kind = "centurion", squad = {}, horns = 0, banner = "back" }
	local boss = ctx.spawn("centurion", zone.boss.at, { introDelay = ctx.intro })
	ctrl.boss = boss
	boss.turnRate = cfg.turnRate
	boss.hasSlot = true
	local brokenUntil = 0
	local lostUntil = 0
	local comboPending = false

	-- Стена щита: урон спереди ослаблен, со стороны и сзади — полный.
	boss.onDamage = function(enemy, amount, attacker, info)
		local t = now()
		if t < brokenUntil then
			return amount * cfg.brokenMultiplier
		end
		if info and (info.reflected or info.ability == "guard_verdict") then
			return amount
		end
		local root = attacker and attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return amount
		end
		local toAttacker = unitOr(root.Position - enemy.position, enemy.facing)
		if toAttacker:Dot(enemy.facing) >= math.cos(math.rad(cfg.shieldArc / 2)) then
			local block = (enemy.phaseIndex or 1) >= 2 and cfg.shieldBlockPhase2 or cfg.shieldBlock
			EnemyService.fireEvent({ kind = "shieldBlock", model = enemy.model, position = enemy.position + Vector3.new(0, enemy.stats.height * 0.5, 0) + enemy.facing * 1.5 })
			return amount * (1 - block)
		end
		return amount
	end

	-- Парирование удара щитом: стойка сломана.
	boss.onParried = function(enemy, attack)
		if attack.id == "bash" then
			brokenUntil = now() + cfg.brokenTime
			enemy.model:SetAttribute("ShieldBrokenUntil", brokenUntil)
			EnemyService.fireEvent({ kind = "shieldBroken", model = enemy.model, duration = cfg.brokenTime })
		end
	end

	local function plantBanner()
		ctrl.banner = "planted"
		local socket = zone.points.banner
		local banner = ctx.spawn("banner", socket, { noCredit = true, bounds = false })
		ctrl.bannerEnemy = banner
		EnemyService.setAura("banner_" .. zone.id, {
			center = socket,
			radius = cfg.auraRadius,
			damageMul = cfg.auraDamage,
			noStun = true,
			owner = nil,
		})
		boss.model:SetAttribute("BannerState", "planted")
		floorEvent({ kind = "bannerPlanted", zone = zone.id, position = socket, radius = cfg.auraRadius, model = banner.model, boss = boss.model })
		banner.onDeath = function()
			EnemyService.clearAura("banner_" .. zone.id)
			ctrl.banner = "lost"
			lostUntil = now() + cfg.lostFormation
			boss.windupMul = cfg.lostFormationWindup
			boss.model:SetAttribute("BannerState", "lost")
			boss.model:SetAttribute("LostFormationUntil", lostUntil)
			floorEvent({ kind = "bannerFell", zone = zone.id, position = socket, boss = boss.model })
		end
	end

	local function horn(t: number)
		ctrl.horns += 1
		comboPending = false
		boss.attack = nil
		boss.forced = nil
		boss.moveDir = Vector3.zero
		boss.sceneUntil = t + cfg.hornTime
		boss.immuneUntil = math.max(boss.immuneUntil, t + cfg.hornTime)
		boss.model:SetAttribute("EnemyAttack", "horn")
		EnemyService.setState(boss, "phase", cfg.hornTime)
		EnemyService.fireEvent({ kind = "horn", model = boss.model, position = boss.position })
		floorEvent({ kind = "horn", zone = zone.id, boss = boss.model })
		local squad = cfg.squad[math.min(ctrl.horns, #cfg.squad)]
		task.delay(cfg.hornTime * 0.6, function()
			if not boss.alive or controllers[zone.id] ~= ctrl then
				return
			end
			if ctrl.banner ~= "planted" then
				if ctrl.bannerEnemy and ctrl.bannerEnemy.alive then
					-- знамя ещё стоит с прошлого рога
				else
					plantBanner()
				end
			end
			for index, typeId in ipairs(squad) do
				local gate = zone.points.squads[((index + ctrl.horns) % #zone.points.squads) + 1]
				local enemy = ctx.spawn(typeId, gate)
				table.insert(ctrl.squad, enemy)
			end
		end)
	end

	boss.brain = function(enemy, t, player, root, distance)
		enemy.hasSlot = true
		if t >= lostUntil and enemy.windupMul then
			enemy.windupMul = nil
		end
		-- Рог сбора по порогам здоровья.
		local share = enemy.health / enemy.maxHealth
		if ctrl.horns < #cfg.horns and share <= cfg.horns[ctrl.horns + 1] then
			horn(t)
			return true
		end
		if not player then
			EnemyService.moveToward(enemy, Vector3.zero, 0, "idle")
			return true
		end
		local direction = unitOr(root.Position - enemy.position, enemy.facing)
		enemy.faceDir = direction
		enemy.targetPlayer = player

		-- Связка: после натиска — клевец (во II фазе всегда, в I — через раз).
		if comboPending and enemy.lastAttackId == "rush" then
			local pick = attackById(enemy, "pick")
			if pick and distance <= reachOf(pick) + 2 then
				comboPending = false
				EnemyService.beginAttack(enemy, pick, player, root, t)
				return true
			end
			EnemyService.moveToward(enemy, direction, 1.3, "approach")
			return true
		end

		if t >= enemy.nextAttackAt then
			local options = {}
			for _, attack in ipairs(EnemyService.availableAttacks(enemy)) do
				local ok = not attack.comboOnly
				if attack.needsBanner and ctrl.banner ~= "back" then
					ok = false
				end
				if attack.id == enemy.lastAttackId and attack.id ~= "bash" then
					ok = false
				end
				if ok then
					if attack.dash then
						ok = distance >= 6 and distance <= (attack.line or 14) + 2
					else
						ok = distance <= reachOf(attack)
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
				if attack.id == "bannerSweep" then
					enemy.model:SetAttribute("BannerState", "swing")
				end
				EnemyService.beginAttack(enemy, attack, player, root, t)
				return true
			end
		end
		if ctrl.banner == "back" and enemy.model:GetAttribute("BannerState") == "swing" and enemy.state ~= "windup" then
			enemy.model:SetAttribute("BannerState", "back")
		end
		-- Держит строй: идёт на игрока не спеша, щит вперёд.
		if distance > 5 then
			EnemyService.moveToward(enemy, direction, 0.9, "approach")
		else
			EnemyService.moveToward(enemy, Vector3.zero, 0, "idle")
		end
		return true
	end

	boss.model:SetAttribute("BannerState", "back")
	ctrl.cleanup = function()
		EnemyService.clearAura("banner_" .. zone.id)
		for _, enemy in ipairs(ctrl.squad) do
			if enemy.alive then
				EnemyService.kill(enemy, nil)
			end
		end
		if ctrl.bannerEnemy and ctrl.bannerEnemy.alive then
			EnemyService.remove(ctrl.bannerEnemy)
		end
	end
	return ctrl
end

-- ======================================================================
-- Арбалетчица: бой у подножия башни (переделка 08.11.2026)
-- ======================================================================
-- Двор вокруг башни, три деревянных насеста на высоте 8 (Dynamic/Perch_A..C).
-- Под каждым — светящаяся подпора (цель perchpost). Подпора сломана → насест
-- рушится, арбалетчица падает и FALL_STUN с оглушена (урон ×STUN_MULT), потом
-- крюком забирается на следующий насест. После третьего — бой на земле.
-- На насесте урон по ней ×PERCH_MULT: маг может стрелять сразу, воин ломает подпоры.

local PERCH_MULT = 0.6
local STUN_MULT = 1.5
local FALL_TIME = 0.55
local FALL_STUN = 4.0
local HOOK_TIME = 1.2
local PIN_RADIUS = 2.6 -- цепной болт: круг у ног, кто остался в нём — пригвождён
local PIN_DELAY = 0.7
local PIN_ROOT = 1.5

local function arc(a: Vector3, b: Vector3, k: number, apex: number): Vector3
	local p = a:Lerp(b, k)
	return p + Vector3.new(0, 4 * apex * k * (1 - k), 0)
end

local function arbalest(zone, ctx)
	local cfg = Enemies.Types.arbalest.miniboss
	local pts = zone.points
	local perches = pts.perches
	local ctrl: any = { zone = zone, kind = "arbalest", phase = "perch", perch = 1, shots = 0, reloadedAt3 = false, traps = {}, cover = {}, support = nil, stunnedUntil = 0 }
	local boss = ctx.spawn("arbalest", perches[1].stand, { introDelay = ctx.intro, bounds = false })
	ctrl.boss = boss
	boss.hasSlot = true
	local reloadUntil = 0
	local lastBoltUsed = false
	local motion = nil -- { from, to, t0, time, apex, after }

	ctx.setPhaseGates(false) -- решётка у лестницы опускается за спиной
	boss.model:SetAttribute("ArbalestPhase", "perch")

	local function spawnCover(index)
		for _, entry in ipairs((zone.cover or {})[index] or {}) do
			table.insert(ctrl.cover, ctx.spawn(entry[1], entry[2]))
		end
	end

	local function setPerch(index)
		ctrl.perch = index
		ctrl.phase = "perch"
		local perch = perches[index]
		boss.position = perch.stand
		boss.model:SetAttribute("ArbalestPhase", "perch")
		boss.model:SetAttribute("ArbalestPerch", perch.id)
		local support = ctx.spawn("perchpost", perch.support, { noCredit = true, bounds = false })
		ctrl.support = support
		support.onDeath = function()
			if ctrl.support ~= support then
				return
			end
			ctrl.support = nil
			ctrl.collapse(index)
		end
		spawnCover(index)
		floorEvent({ kind = "arbalestPerch", zone = zone.id, perch = perch.id, index = index, total = #perches, position = perch.stand, support = perch.support })
	end

	-- Насест рухнул: она падает перед подпорой и оглушена.
	function ctrl.collapse(index)
		local perch = perches[index]
		local position = ctx.map.destroyDynamic("Perch_" .. perch.id)
		local ahead = unitOr(pts.center - perch.support, Vector3.new(0, 0, 1))
		local landing = Vector3.new(perch.support.X, pts.center.Y, perch.support.Z) + ahead * 2.2
		ctrl.phase = "fall"
		boss.model:SetAttribute("ArbalestPhase", "fall")
		EnemyService.setState(boss, "idle", FALL_TIME)
		motion = { from = boss.position, to = landing, t0 = now(), time = FALL_TIME, apex = 0.6, after = function()
			ctrl.phase = "stunned"
			boss.model:SetAttribute("ArbalestPhase", "stunned")
			ctrl.stunnedUntil = now() + FALL_STUN
			EnemyService.stun(boss, FALL_STUN, true)
		end }
		floorEvent({ kind = "perchCollapse", zone = zone.id, perch = perch.id, index = index, total = #perches, position = position or perch.stand, landing = landing, dirIn = ahead })
	end

	-- Крюк на следующий насест.
	local function hookTo(index)
		local perch = perches[index]
		ctrl.phase = "hook"
		boss.model:SetAttribute("ArbalestPhase", "hook")
		floorEvent({ kind = "arbalestHook", zone = zone.id, from = boss.position, to = perch.stand, duration = HOOK_TIME, boss = boss.model })
		motion = { from = boss.position, to = perch.stand, t0 = now() + 0.35, time = HOOK_TIME, apex = 3.5, after = function()
			setPerch(index)
		end }
	end

	boss.onDamage = function(enemy, amount, attacker, info)
		if ctrl.phase == "perch" or ctrl.phase == "hook" then
			return amount * PERCH_MULT
		elseif ctrl.phase == "stunned" or ctrl.phase == "fall" then
			return amount * STUN_MULT
		end
		return amount
	end

	-- Цепной болт: круг у ног цели — не вышел за PIN_DELAY, пригвождён.
	local function placePin(root)
		local feet = root.Position - Vector3.new(0, 3, 0)
		local ground = FloorGeo.groundAt(feet.X, feet.Z, feet.Y + 1) or feet.Y
		local at = Vector3.new(feet.X, ground, feet.Z)
		table.insert(ctrl.traps, { position = at, radius = PIN_RADIUS, fromT = now() + PIN_DELAY, untilT = now() + PIN_DELAY + 0.25, root = PIN_ROOT, pin = true })
		floorEvent({ kind = "trapsPlaced", zone = zone.id, positions = { at }, radius = PIN_RADIUS, duration = PIN_DELAY + 0.25, pin = true })
	end

	boss.onStrike = function(enemy, attack, t, player, root)
		if attack.id == "chainBolt" and root then
			placePin(root)
			return false -- сам болт летит как обычный снаряд
		end
		if attack.trap and enemy.zoneCenters then
			for _, c in ipairs(enemy.zoneCenters) do
				table.insert(ctrl.traps, { position = c, radius = attack.radius, untilT = t + cfg.trapLife, root = cfg.trapRoot })
			end
			floorEvent({ kind = "trapsPlaced", zone = zone.id, positions = enemy.zoneCenters, radius = attack.radius, duration = cfg.trapLife })
			return false
		end
		return false
	end

	local function rangedOptions(enemy, t, clear)
		local options = {}
		for _, attack in ipairs(EnemyService.availableAttacks(enemy)) do
			local allowed = attack.phase == "climb" or (attack.trap and ctrl.perch >= 3)
			if allowed and attack.id ~= enemy.lastAttackId then
				local ready = not attack.every or t - (enemy.attackUsedAt[attack.id] or -math.huge) >= attack.every
				if attack.id == "aimedBolt" then
					ready = ready and clear
				elseif attack.id == "chainBolt" then
					ready = ready and clear and ctrl.perch >= 2
				end
				if ready then
					table.insert(options, attack)
				end
			end
		end
		return options
	end

	boss.brain = function(enemy, t, player, root, distance)
		enemy.hasSlot = true
		if motion or ctrl.phase == "fall" or ctrl.phase == "hook" or ctrl.phase == "stunned" then
			enemy.moveDir = Vector3.zero
			return true
		end
		if not player then
			EnemyService.moveToward(enemy, Vector3.zero, 0, "idle")
			return true
		end
		enemy.targetPlayer = player
		local direction = unitOr(root.Position - enemy.position, enemy.facing)
		enemy.faceDir = direction

		-- Перезарядка воротом каждые reloadEvery выстрелов.
		if t < reloadUntil then
			if enemy.state ~= "reload" then
				EnemyService.setState(enemy, "reload", reloadUntil - t)
			end
			enemy.moveDir = Vector3.zero
			return true
		elseif enemy.model:GetAttribute("Reloading") then
			enemy.model:SetAttribute("Reloading", false)
		end
		if ctrl.shots > 0 and ctrl.shots % cfg.reloadEvery == 0 and not ctrl.reloadedAt3 then
			ctrl.reloadedAt3 = true
			reloadUntil = t + cfg.reloadTime
			enemy.model:SetAttribute("Reloading", true)
			enemy.model:SetAttribute("ReloadUntil", reloadUntil)
			EnemyService.setState(enemy, "reload", cfg.reloadTime)
			EnemyService.fireEvent({ kind = "reload", model = enemy.model, duration = cfg.reloadTime })
			return true
		end

		if ctrl.phase == "perch" then
			-- Стоит на насесте, не сходит с него.
			EnemyService.moveToward(enemy, Vector3.zero, 0, "idle")
			enemy.position = perches[ctrl.perch].stand
			if t < enemy.nextAttackAt then
				return true
			end
			local eye = enemy.position + Vector3.new(0, enemy.stats.height * 0.65, 0) + direction * 3.6
			local clear = not EnemyService.lineBlocked(enemy, eye, root.Position)
			local options = rangedOptions(enemy, t, clear)
			if #options == 0 then
				options = { attackById(enemy, "volley") }
			end
			local attack = options[math.random(1, #options)]
			if attack then
				ctrl.shots += 1
				ctrl.reloadedAt3 = false
				EnemyService.beginAttack(enemy, attack, player, root, t)
			end
			return true
		end

		-- «Земля»: ближний бой, отскок и выстрел, капканы, «Последний болт».
		if t < enemy.nextAttackAt then
			if distance > 5 then
				EnemyService.moveToward(enemy, direction, 1, "approach")
			elseif distance < 3 then
				EnemyService.moveToward(enemy, -direction, 0.8, "retreat")
			else
				EnemyService.moveToward(enemy, Vector3.new(-direction.Z, 0, direction.X), 0.6, "circle")
			end
			return true
		end
		local share = enemy.health / enemy.maxHealth
		local attack
		if not lastBoltUsed and share <= 0.25 then
			lastBoltUsed = true
			attack = attackById(enemy, "lastBolt")
		else
			local options = {}
			for _, a in ipairs(EnemyService.availableAttacks(enemy)) do
				if a.phase == "top" and not a.once and a.id ~= enemy.lastAttackId then
					local ready = not a.every or t - (enemy.attackUsedAt[a.id] or -math.huge) >= a.every
					if a.id == "stock" then
						ready = ready and distance <= reachOf(a)
					end
					if ready then
						table.insert(options, a)
					end
				end
			end
			if #options == 0 then
				if distance > 6 then
					EnemyService.moveToward(enemy, direction, 1, "approach")
					return true
				end
				options = { attackById(enemy, "stock") }
			end
			attack = options[math.random(1, #options)]
		end
		if attack then
			EnemyService.beginAttack(enemy, attack, player, root, t)
			if attack.backstep then
				local away = unitOr(enemy.position - root.Position, -enemy.facing)
				enemy.forced = { direction = away, speed = attack.backstep / 0.25, untilT = t + 0.25, windupMove = true }
			end
		end
		return true
	end

	ctrl.step = function(t)
		-- Падение / крюк: позиция по дуге.
		if motion and t >= motion.t0 then
			local k = math.clamp((t - motion.t0) / motion.time, 0, 1)
			boss.position = arc(motion.from, motion.to, k, motion.apex)
			if k >= 1 then
				local after = motion.after
				motion = nil
				if after then
					after()
				end
			end
		end
		-- Оглушение прошло: следующий насест или бой на земле.
		if ctrl.phase == "stunned" and t >= (ctrl.stunnedUntil or 0) then
			if ctrl.perch < #perches then
				hookTo(ctrl.perch + 1)
			else
				ctrl.phase = "ground"
				boss.model:SetAttribute("ArbalestPhase", "ground")
				floorEvent({ kind = "arbalestGround", zone = zone.id, boss = boss.model })
			end
		end
		-- Капканы и круги цепного болта.
		for index = #ctrl.traps, 1, -1 do
			local trap = ctrl.traps[index]
			if t >= trap.untilT then
				table.remove(ctrl.traps, index)
			elseif not trap.fromT or t >= trap.fromT then
				for _, player in ipairs(Players:GetPlayers()) do
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					if root and humanoid and humanoid.Health > 0 then
						local feet = root.Position.Y - 3
						if flat(root.Position - trap.position).Magnitude <= trap.radius and math.abs(feet - trap.position.Y) < 3 then
							table.remove(ctrl.traps, index)
							MiniBossService.root(player, trap.root or cfg.trapRoot)
							floorEvent({ kind = "trapSprung", zone = zone.id, position = trap.position, player = player, pin = trap.pin })
							break
						end
					end
				end
			end
		end
	end
	ctrl.cleanup = function()
		for _, enemy in ipairs(ctrl.cover) do
			if enemy.alive then
				EnemyService.remove(enemy)
			end
		end
		if ctrl.support and ctrl.support.alive then
			EnemyService.remove(ctrl.support)
		end
		ctrl.support = nil
		ctrl.traps = {}
		motion = nil
	end

	setPerch(1)
	return ctrl
end

-- Обездвижить игрока (капкан): WalkSpeed 0 на время, потом вернуть.
local rooted = {}
function MiniBossService.root(player, duration: number)
	duration *= TalentMods.debuffScale(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if not rooted[player] then
		rooted[player] = { speed = humanoid.WalkSpeed, jump = humanoid.JumpPower }
	end
	rooted[player].untilT = now() + duration
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	player:SetAttribute("RootedUntil", rooted[player].untilT)
end

local function stepRooted(t: number)
	for player, entry in pairs(rooted) do
		if t >= entry.untilT then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.WalkSpeed == 0 then
				humanoid.WalkSpeed = entry.speed
				humanoid.JumpPower = entry.jump
			end
			rooted[player] = nil
			player:SetAttribute("RootedUntil", nil)
		end
	end
end

-- ======================================================================
-- Общее
-- ======================================================================

local BUILDERS = { centurion = centurion, arbalest = arbalest }

function MiniBossService.register(typeId: string, builder)
	BUILDERS[typeId] = builder
end

MiniBossService.attackById = attackById
MiniBossService.reachOf = reachOf

-- ctx: spawn(typeId, position, extra) → enemy; map (FloorMap); runtime() → папка;
-- setPhaseGates(open); intro — длительность сцены появления.
function MiniBossService.start(zone, ctx)
	MiniBossService.stop(zone.id)
	local builder = BUILDERS[zone.boss.typeId]
	if not builder then
		warn("[MiniBossService] нет мини-босса " .. tostring(zone.boss.typeId))
		return nil
	end
	local ctrl = builder(zone, ctx)
	controllers[zone.id] = ctrl
	if not loop then
		loop = RunService.Heartbeat:Connect(function()
			local t = now()
			stepRooted(t)
			for _, c in pairs(controllers) do
				if c.step then
					local ok, err = pcall(c.step, t)
					if not ok then
						warn("[MiniBossService] " .. tostring(err))
					end
				end
			end
		end)
	end
	return ctrl.boss, ctrl
end

function MiniBossService.stop(zoneId: string)
	local ctrl = controllers[zoneId]
	if not ctrl then
		return
	end
	controllers[zoneId] = nil
	if ctrl.cleanup then
		pcall(ctrl.cleanup)
	end
end

function MiniBossService.stopAll()
	for id in pairs(controllers) do
		MiniBossService.stop(id)
	end
	for player in pairs(rooted) do
		rooted[player].untilT = 0
	end
end

return MiniBossService
