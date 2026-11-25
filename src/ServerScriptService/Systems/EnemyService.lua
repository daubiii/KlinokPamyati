--!nonstrict
-- EnemyService (сервер)
-- Логика врагов этажа 1 по приложению Е: пять типов и босс.
--
-- Что здесь, а что нет:
--  * сервер ведёт ЛОГИКУ: положение, состояние, замахи, урон, оглушение;
--  * внешний вид и анимации рисует клиент (EnemyVisualController) по
--    атрибутам модели. На сервере у врага одна невидимая деталь Root, по
--    ней же работают удары игрока.
--
-- Враг — конечный автомат, который обновляется одним циклом Heartbeat.
-- Никаких сопрограмм на каждого врага: когда комнату пересоздают, враги
-- удаляются тут же и не оставляют «живого» ИИ (раньше удалённые модели
-- продолжали бить игрока).
--
-- Состояния (атрибут EnemyState):
--   spawning  сборка из кубиков, не атакует (1 с по приложению Е)
--   idle / approach / retreat / circle  — движение
--   windup    замах: виден цвет и форма подсказки (атрибут EnemyTelegraph)
--   dash      рывок (Тень, Таран босса)
--   strike    серия ударов
--   recover   пауза восстановления: враг уязвим
--   stunned   оглушён парированием, способностью или стеной
--   phase     босс входит во вторую фазу (2 с, неуязвим)
--   dead
--
-- Общие правила (прил. Е): одновременно бьют не больше двух ближних, остальные
-- кружат на 6–8 стадах; стрелки целятся по текущей позиции без упреждения.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Enemies = require(Shared.Config.Enemies)
local FloorLayout = require(Shared.Floor.FloorLayout)
local FloorGeo = require(Shared.Floor.FloorGeo)
local Net = require(Shared.Net.Net)
local CombatService = require(script.Parent.CombatService)
local ProjectileService = require(script.Parent.ProjectileService)
-- Древо талантов: пробивание брони, «Разрушитель», стан после парирования.
local TalentMods = require(script.Parent.TalentMods)
-- Пожизненные счётчики достижений (урон, снятый с врагов).
local StatsService = require(script.Parent.StatsService)

local EnemyService = {}

-- Неуязвимость босса при входе в новую фазу, с.
local PHASE_IMMUNITY = 0.3

local enemies = {}
local activeMeleeAttackers = 0
local loopConnection = nil

local MELEE_HIT_GAP = 0.18 -- между двумя взмахами Тени
local STRIKE_PRESENT = 0.14 -- сколько клиент показывает взмах
local DEATH_LINGER = 2

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function unitOr(vector: Vector3, fallback: Vector3): Vector3
	local f = flat(vector)
	if f.Magnitude < 0.001 then
		return fallback
	end
	return f.Unit
end

-- ===== Атрибуты модели (то, что видит клиент) =====

local function publishHealth(enemy)
	local model = enemy.model
	model:SetAttribute("EnemyHealth", enemy.health)
	model:SetAttribute("EnemyMaxHealth", enemy.maxHealth)
	model:SetAttribute("EnemyArmor", enemy.armor)
end

local function setState(enemy, stateName: string, duration: number?)
	local t = now()
	enemy.state = stateName
	enemy.stateAt = t
	enemy.stateUntil = t + (duration or 0)
	local model = enemy.model
	-- Сначала время и длительность, потом имя: клиент реагирует на имя.
	model:SetAttribute("EnemyStateAt", t)
	model:SetAttribute("EnemyStateDur", duration or 0)
	model:SetAttribute("EnemyState", stateName)
end

local function clearTelegraph(enemy)
	local model = enemy.model
	model:SetAttribute("EnemyTelegraph", "none")
	model:SetAttribute("EnemyAttack", "none")
	model:SetAttribute("EnemyAttackRadius", 0)
	model:SetAttribute("EnemyZones", "")
	model:SetAttribute("EnemyAimPoint", nil)
	model:SetAttribute("EnemyDashDir", nil)
end

local function fireEvent(payload)
	local remote = Net.get("EnemyEvent")
	if remote then
		remote:FireAllClients(payload)
	end
end

-- ===== Игроки =====

local function livingRoot(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

-- Этаж v2 с высотами: ноги игрока ≈ корень − 3 (R15). Враг «видит» игрока
-- на своём уровне; на другом уровне (балкон, виток пандуса) — только дальние.
local FEET = 3.0
local LEVEL_GAP = 7.0

local function feetY(root): number
	return root.Position.Y - FEET
end

-- «Покров» мага (MageService.veil): пока VeiledUntil > сейчас, враги игрока не видят.
local function veiled(player): boolean
	return player ~= nil and (player:GetAttribute("VeiledUntil") or 0) > now()
end

local function nearestPlayer(position: Vector3, maxDistance: number, anyLevel: boolean?)
	local best, bestRoot, bestDistance = nil, nil, math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local root = not veiled(player) and livingRoot(player) or nil
		if root and (anyLevel or math.abs(feetY(root) - position.Y) <= LEVEL_GAP) then
			local distance = flat(root.Position - position).Magnitude
			if distance <= maxDistance and distance < bestDistance then
				best, bestRoot, bestDistance = player, root, distance
			end
		end
	end
	return best, bestRoot, bestDistance
end

-- ===== Слоты ближних атакующих =====

local function acquireSlot(enemy): boolean
	if enemy.hasSlot then
		return true
	end
	local role = enemy.stats.role
	-- ignoreSlots: Тень-ассасин не ждёт очереди ближних (иначе просто кружит).
	if role == "ranged" or role == "boss" or enemy.stats.ignoreSlots then
		enemy.hasSlot = true
		return true
	end
	if activeMeleeAttackers >= Enemies.Behavior.maxMeleeAttackers then
		return false
	end
	activeMeleeAttackers += 1
	enemy.hasSlot = true
	enemy.counted = true
	enemy.model:SetAttribute("Attacking", true)
	return true
end

local function releaseSlot(enemy)
	if not enemy.hasSlot then
		return
	end
	enemy.hasSlot = false
	enemy.model:SetAttribute("Attacking", false)
	if enemy.counted then
		enemy.counted = false
		activeMeleeAttackers = math.max(activeMeleeAttackers - 1, 0)
	end
end

-- ===== Столкновения: стены комнаты, колонны, соседи =====

-- Круг радиуса r против прямоугольника: выталкиваем по оси наименьшего
-- проникновения.
local function pushOutOfBox(x: number, z: number, r: number, box)
	local dx = x - box.cx
	local dz = z - box.cz
	local px = box.hx + r - math.abs(dx)
	local pz = box.hz + r - math.abs(dz)
	if px > 0 and pz > 0 then
		if px < pz then
			x = box.cx + (dx >= 0 and 1 or -1) * (box.hx + r)
		else
			z = box.cz + (dz >= 0 and 1 or -1) * (box.hz + r)
		end
		return x, z, true
	end
	return x, z, false
end

-- Отрезок AB пересекает прямоугольник (метод плит). Для колонн, которые
-- блокируют снаряды.
local function segmentHitsBox(ax: number, az: number, bx: number, bz: number, box): boolean
	local dx, dz = bx - ax, bz - az
	local tmin, tmax = 0, 1
	local function slab(origin: number, delta: number, low: number, high: number): boolean
		if math.abs(delta) < 1e-6 then
			return origin >= low and origin <= high
		end
		local t1 = (low - origin) / delta
		local t2 = (high - origin) / delta
		if t1 > t2 then
			t1, t2 = t2, t1
		end
		tmin = math.max(tmin, t1)
		tmax = math.min(tmax, t2)
		return tmin <= tmax
	end
	if not slab(ax, dx, box.cx - box.hx, box.cx + box.hx) then
		return false
	end
	return slab(az, dz, box.cz - box.hz, box.cz + box.hz)
end

local function lineBlocked(enemy, from: Vector3, to: Vector3): boolean
	for _, box in ipairs(enemy.obstacles) do
		if segmentHitsBox(from.X, from.Z, to.X, to.Z, box) then
			return true
		end
	end
	-- Этаж v2: стены, баррикады, колонны карты (укрытия от болтов).
	return FloorGeo.blocked(from, to)
end

-- Возвращает новую позицию и признак «упёрся» (для Тарана босса).
local function collide(enemy, position: Vector3, separate: boolean)
	local x, z = position.X, position.Z
	local r = enemy.stats.radius
	local blocked = false

	local bounds = enemy.bounds
	if bounds then
		local cx, cz = FloorLayout.clampToBounds(bounds, x, z)
		if math.abs(cx - x) > 0.001 or math.abs(cz - z) > 0.001 then
			blocked = true
		end
		x, z = cx, cz
	end

	for _, box in ipairs(enemy.obstacles) do
		local hit
		x, z, hit = pushOutOfBox(x, z, r, box)
		if hit then
			blocked = true
		end
	end

	if separate then
		for _, other in ipairs(enemies) do
			if other ~= enemy and other.alive and other.room == enemy.room then
				local dx = x - other.position.X
				local dz = z - other.position.Z
				local distance = math.sqrt(dx * dx + dz * dz)
				local minimum = r + other.stats.radius + 0.3
				if distance < minimum then
					if distance < 0.01 then
						dx, dz, distance = 1, 0, 1
					end
					local push = (minimum - distance) * 0.5
					x += dx / distance * push
					z += dz / distance * push
				end
			end
		end
	end

	return Vector3.new(x, position.Y, z), blocked
end

-- ===== Ауры (знамя Сотника) =====
-- { center: Vector3, radius, damageMul, noStun, owner } — союзники в круге
-- бьют сильнее и не оглушаются. Ставит и снимает MiniBossService.
local auras = {}

local function auraFor(enemy)
	local damageMul, noStun = 1, false
	for _, aura in pairs(auras) do
		if aura.owner ~= enemy and flat(enemy.position - aura.center).Magnitude <= aura.radius then
			damageMul = math.max(damageMul, aura.damageMul or 1)
			noStun = noStun or aura.noStun == true
		end
	end
	return damageMul, noStun
end

function EnemyService.setAura(id: string, aura)
	auras[id] = aura
end

function EnemyService.clearAura(id: string)
	auras[id] = nil
end

-- ===== Урон по игроку =====

local function resolveOnPlayer(enemy, attack, player)
	local damage = attack.damage
	if attack.damagePct then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		damage = (humanoid and humanoid.MaxHealth or 100) * attack.damagePct
	end
	damage *= (auraFor(enemy))
	local result, taken = CombatService.resolveIncomingAttack(player, {
		damage = damage,
		parryable = attack.telegraph == "parryable",
		source = enemy.stats.name,
		position = enemy.position,
	})
	enemy.model:SetAttribute("LastAttackResult", result)
	enemy.model:SetAttribute("LastAttackDamage", taken or 0)
	-- Аффиксы врагов (EnemyDebuffs): урон прошёл — носитель передаёт дебаф.
	if EnemyService.onPlayerHit then
		pcall(EnemyService.onPlayerHit, enemy, player, result, taken)
	end
	if result == "parried" then
		enemy.parriedBy = player -- для «Щитового удара» (дольше стан)
	end
	return result
end

-- ===== Выбор атаки =====

-- Дальность, на которой атака вообще имеет смысл.
local function attackReach(attack): number
	-- Фирменные атаки боссов (Config/BossMoves): дальность задана явно.
	if attack.reach then
		return attack.reach
	end
	if attack.leap then
		return 32 -- прыжок: сокращает дистанцию
	end
	if attack.zones and not attack.diesOnAttack then
		return 30 -- цепи: зоны вокруг игрока, дистанция не важна
	end
	if attack.diesOnAttack then
		return attack.range or 3
	end
	if attack.dash and attack.wallStun then
		return 28 -- Таран: разгон по линии
	end
	if attack.radius then
		return attack.radius + 2.5
	end
	return (attack.range or 6) * 0.8 + 1
end

local function attackMinRange(attack): number
	if attack.minRange then
		return attack.minRange
	end
	if attack.dash and attack.wallStun then
		return 6
	end
	if attack.leap then
		return 8
	end
	return 0
end

-- Пройденные фазы босса: phaseIndex 1 — базовая, 2 — после первого порога…
local function activePhases(enemy)
	local list = {}
	local phases = enemy.stats.phases or {}
	for index = 1, (enemy.phaseIndex or 1) - 1 do
		if phases[index] then
			table.insert(list, phases[index])
		end
	end
	return list
end

-- Атаки с учётом фаз: добавленные фазами и изменённые (modify). Список
-- кэшируется на фазу, чтобы не клонировать таблицы каждый кадр.
local function availableAttacks(enemy)
	local phaseIndex = enemy.phaseIndex or 1
	enemy.attackCache = enemy.attackCache or {}
	local cached = enemy.attackCache[phaseIndex]
	if cached then
		return cached
	end
	local phases = activePhases(enemy)
	local modify = {}
	for _, phase in ipairs(phases) do
		for id, changes in pairs(phase.modify or {}) do
			modify[id] = modify[id] or {}
			for key, value in pairs(changes) do
				modify[id][key] = value
			end
		end
	end
	local list = {}
	for _, attack in ipairs(enemy.stats.attacks) do
		local changes = modify[attack.id]
		if changes then
			local copy = table.clone(attack)
			for key, value in pairs(changes) do
				copy[key] = value
			end
			table.insert(list, copy)
		else
			table.insert(list, attack)
		end
	end
	for _, phase in ipairs(phases) do
		for _, attack in ipairs(phase.attacks or {}) do
			table.insert(list, attack)
		end
	end
	enemy.attackCache[phaseIndex] = list
	return list
end

-- Ускорение атак текущей фазы (0 — без ускорения).
local function phaseSpeedBonus(enemy): number
	local bonus = 0
	for _, phase in ipairs(activePhases(enemy)) do
		bonus = math.max(bonus, phase.attackSpeedBonus or 0)
	end
	return bonus
end

local function pickAttack(enemy, distance: number, t: number)
	local candidates = {}
	local fallback = {}
	for _, attack in ipairs(availableAttacks(enemy)) do
		local ready = true
		if attack.every and t - (enemy.attackUsedAt[attack.id] or -math.huge) < attack.every then
			ready = false
		end
		if ready and distance <= attackReach(attack) and distance >= attackMinRange(attack) then
			-- Одна и та же атака не повторяется дважды подряд.
			if attack.id == enemy.lastAttackId then
				table.insert(fallback, attack)
			else
				table.insert(candidates, attack)
			end
		end
	end
	if #candidates == 0 then
		candidates = fallback
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

-- ===== Атака =====

local function zoneGround(x: number, z: number, nearY: number): number
	return FloorGeo.groundAt(x, z, nearY + 1) or nearY
end

local function computeZones(enemy, attack, targetPosition: Vector3)
	-- Одна зона точно под игроком, остальные рядом (приложение Е).
	-- Этаж v2: у каждой зоны своя высота пола (пандус, галерея).
	local baseY = targetPosition.Y - FEET
	local centers = { Vector3.new(targetPosition.X, zoneGround(targetPosition.X, targetPosition.Z, baseY), targetPosition.Z) }
	local extra = (attack.zones or 1) - 1
	local startAngle = math.random() * math.pi * 2
	for index = 1, extra do
		local angle = startAngle + (index / extra) * math.pi * 2
		local spread = attack.radius * 1.6
		local center = Vector3.new(
			targetPosition.X + math.cos(angle) * spread,
			0,
			targetPosition.Z + math.sin(angle) * spread
		)
		local bounds = enemy.bounds
		if bounds and not attack.ignoreBounds then
			local x, z = FloorLayout.clampToBounds(bounds, center.X, center.Z)
			center = Vector3.new(x, 0, z)
		end
		center = Vector3.new(center.X, zoneGround(center.X, center.Z, baseY), center.Z)
		table.insert(centers, center)
	end
	return centers
end

local function encodeZones(centers): string
	local parts = {}
	for _, center in ipairs(centers) do
		-- «x,z,y»: третье число — высота пола (клиент рисует круг на ней).
		table.insert(parts, ("%.2f,%.2f,%.2f"):format(center.X, center.Z, center.Y))
	end
	return table.concat(parts, ";")
end

local function beginAttack(enemy, attack, player, root, t: number)
	enemy.attack = attack
	enemy.targetPlayer = player
	enemy.attackStartedAt = t
	enemy.lastAttackId = attack.id
	enemy.attackUsedAt[attack.id] = t
	enemy.moveDir = Vector3.zero

	local speedUp = 1 - phaseSpeedBonus(enemy)
	-- windupMul: Сотник «потерял строй» (знамя срублено) — замахи медленнее.
	local windup = attack.windup * speedUp * (enemy.windupMul or 1)
	enemy.windupDuration = windup
	enemy.lockFacingAt = t + windup * Combat.Enemy.lockFacingAt
	enemy.attackCooldown = (attack.cooldown or 1) * speedUp
	-- aimLock: на этой доле замаха прицел (выстрел) или направление рывка
	-- фиксируются, клиент рисует их явно — от удара можно уйти в сторону.
	enemy.aimPoint = nil
	enemy.dashDir = nil
	enemy.aimLockAt = attack.aimLock and (t + windup * attack.aimLock) or nil

	local model = enemy.model
	model:SetAttribute("EnemyAttack", attack.id)
	model:SetAttribute("EnemyTelegraph", attack.telegraph)

	-- Цели прошлой атаки не должны «протекать» в эту.
	enemy.zoneCenters = nil
	enemy.attackCenter = nil

	local radius = 0
	-- Цепи: зоны вокруг игрока. Взрыв Треснувшего (zones = 1, но diesOnAttack)
	-- и удары по площади (разворот, удар в землю) — вокруг самого врага.
	-- Прыжок: зона там, где игрок стоит в начале замаха.
	if attack.leap then
		local x, z = root.Position.X, root.Position.Z
		if enemy.bounds then
			x, z = FloorLayout.clampToBounds(enemy.bounds, x, z)
		end
		enemy.attackCenter = Vector3.new(x, zoneGround(x, z, feetY(root)), z)
		radius = attack.radius
	elseif attack.zones and attack.radius and not attack.diesOnAttack then
		enemy.zoneCenters = computeZones(enemy, attack, root.Position)
		model:SetAttribute("EnemyZones", encodeZones(enemy.zoneCenters))
		radius = attack.radius
	elseif attack.radius then
		enemy.attackCenter = enemy.position
		radius = attack.radius
	end
	if radius > 0 then
		model:SetAttribute("EnemyAttackCenter", enemy.attackCenter or enemy.zoneCenters[1])
	end
	model:SetAttribute("EnemyAttackRadius", radius)
	enemy.faceDir = unitOr(root.Position - enemy.position, enemy.facing)

	setState(enemy, "windup", windup)
	-- Свой замах (этаж 2: линии корней, конус полива) — разметка для клиента.
	if enemy.onWindup then
		local ok, err = pcall(enemy.onWindup, enemy, attack, player, root, t)
		if not ok then
			warn("[EnemyService] onWindup: " .. tostring(err))
		end
	end
end

local function finishAttack(enemy, t: number)
	releaseSlot(enemy)
	local attack = enemy.attack
	local cooldown = enemy.attackCooldown or 1
	enemy.nextAttackAt = math.max(enemy.attackStartedAt + cooldown, t)
	enemy.attack = nil
	enemy.forced = nil
	clearTelegraph(enemy)
	setState(enemy, "idle")
	enemy.model:SetAttribute("LastAttackId", attack and attack.id or "none")
end

local function startRecover(enemy, t: number)
	local attack = enemy.attack
	clearTelegraph(enemy)
	setState(enemy, "recover", attack and attack.recover or Combat.Enemy.recoverTime)
end

local function cancelAttack(enemy, t: number)
	releaseSlot(enemy)
	enemy.forced = nil
	enemy.attack = nil
	enemy.hitsLeft = 0
	enemy.nextAttackAt = t + 0.4
	clearTelegraph(enemy)
end

function EnemyService.stun(enemy, duration: number, force: boolean?)
	if not enemy or not enemy.alive then
		return
	end
	if enemy.stats.role == "object" then
		return
	end
	-- Знамя Сотника: союзники в круге не оглушаются (кроме сценария force).
	local _, noStun = auraFor(enemy)
	if noStun and not force then
		fireEvent({ kind = "stunResisted", model = enemy.model, position = enemy.position })
		return
	end
	local t = now()
	cancelAttack(enemy, t)
	enemy.stunUntil = math.max(enemy.stunUntil, t + duration)
	enemy.moveDir = Vector3.zero
	setState(enemy, "stunned", enemy.stunUntil - t)
	enemy.model:SetAttribute("EnemyStunnedUntil", enemy.stunUntil)
	fireEvent({ kind = "stun", model = enemy.model, duration = duration })
end

-- Исход удара: парирование оглушает врага и обрывает серию.
local function handleResult(enemy, attack, result: string, t: number): boolean
	if result == "parried" then
		enemy.hitsLeft = 0
		-- «Щитовой удар» (Бастион): стан после парирования +0,3 с.
		local bonus = TalentMods.parryStunBonus(enemy.parriedBy)
		enemy.parriedBy = nil
		EnemyService.stun(enemy, (attack.parryStun or Combat.Parry.successStun) + bonus, true)
		fireEvent({ kind = "parried", model = enemy.model, position = enemy.position })
		if enemy.onParried then
			enemy.onParried(enemy, attack)
		end
		return true
	end
	return false
end

-- Один ближний удар: игрок должен быть перед врагом и в пределах дальности.
local function meleeHit(enemy, attack, t: number): string
	local player = enemy.targetPlayer
	local root = livingRoot(player)
	if not root then
		return "miss"
	end
	local to = flat(root.Position - enemy.position)
	local distance = to.Magnitude
	local reach = (attack.range or 6) + Combat.Enemy.hitSlop
	-- Этаж v2: игрок на другом уровне (балкон, виток пандуса) недосягаем.
	if math.abs(feetY(root) - enemy.position.Y) > math.max(4.5, enemy.stats.height * 0.6) then
		enemy.model:SetAttribute("LastAttackResult", "out-of-range")
		return "out-of-range"
	end
	if distance > reach then
		enemy.model:SetAttribute("LastAttackResult", "out-of-range")
		return "out-of-range"
	end
	if distance > 1.5 then
		-- У выпада древком дуга узкая: от него уходят шагом в сторону.
		local cosHalf = math.cos(math.rad((attack.arc or Combat.Enemy.strikeArcDegrees) / 2))
		if enemy.facing:Dot(to.Unit) < cosHalf then
			enemy.model:SetAttribute("LastAttackResult", "out-of-arc")
			return "out-of-arc"
		end
	end
	return resolveOnPlayer(enemy, attack, player)
end

-- Попадание по площади: центр — враг (разворот, удар в землю, взрыв) или
-- зоны на земле (цепи).
local function areaHit(enemy, attack): string
	local player = enemy.targetPlayer
	local root = livingRoot(player)
	if not root then
		return "miss"
	end
	local reach = attack.radius + Combat.Enemy.playerRadius
	local inside = false
	local position = flat(root.Position)
	local feet = feetY(root)
	local function within(center: Vector3): boolean
		return (position - flat(center)).Magnitude <= reach and math.abs(feet - center.Y) <= 4
	end
	if enemy.zoneCenters then
		for _, center in ipairs(enemy.zoneCenters) do
			if within(center) then
				inside = true
				break
			end
		end
	else
		inside = within(enemy.attackCenter or enemy.position)
	end
	if not inside then
		enemy.model:SetAttribute("LastAttackResult", "out-of-range")
		return "out-of-range"
	end
	return resolveOnPlayer(enemy, attack, player)
end

local function fireProjectile(enemy, attack, root)
	local origin = enemy.position + Vector3.new(0, enemy.stats.height * 0.65, 0)
	-- originOut: снаряд рождается за парапетом (Арбалетчица стреляет с башни вниз).
	if attack.originOut then
		origin += unitOr(root.Position - enemy.position, enemy.facing) * attack.originOut
	end
	-- Зафиксированный прицел: стрела летит по показанной линии.
	local direction = (enemy.aimPoint or root.Position) - origin
	enemy.aimPoint = nil
	if direction.Magnitude < 0.5 then
		return
	end
	local damage = attack.damage
	if attack.damagePct then
		local player = enemy.targetPlayer
		local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		damage = (humanoid and humanoid.MaxHealth or 100) * attack.damagePct
	end
	ProjectileService.fire(enemy.model, origin, direction.Unit, {
		speed = attack.projectileSpeed,
		damage = damage * (auraFor(enemy)),
		parryable = attack.telegraph == "parryable",
		source = enemy.stats.name,
		shooter = enemy,
		kind = attack.projectileKind, -- клиенту: «bolt», «lastBolt», «chainBolt» (нет — стрела)
		-- Отражённый болт Арбалетчицы: доля здоровья стрелка и оглушение.
		reflectDamage = attack.reflectPct and enemy.maxHealth * attack.reflectPct or nil,
		reflectStun = attack.reflectStun,
		lifetime = attack.projectileLife,
	})
	enemy.model:SetAttribute("LastAttackResult", "projectile")
end

-- Конец замаха: удар.
local function strike(enemy, t: number)
	local attack = enemy.attack
	local player = enemy.targetPlayer
	local root = livingRoot(player)
	clearTelegraph(enemy)
	enemy.model:SetAttribute("EnemyAttack", attack.id)
	-- Свой удар (мини-боссы: цепной болт, капканы). true — удар обработан.
	if enemy.onStrike and enemy.onStrike(enemy, attack, t, player, root) then
		return
	end

	if attack.leap then
		-- Прыжок: зона приземления остаётся видна, пока босс в воздухе.
		local target = enemy.attackCenter or enemy.position
		local offset = flat(target - enemy.position)
		local duration = attack.leapTime or 0.5
		local model = enemy.model
		model:SetAttribute("EnemyTelegraph", attack.telegraph)
		model:SetAttribute("EnemyAttackRadius", attack.radius)
		model:SetAttribute("EnemyAttackCenter", target)
		enemy.faceDir = unitOr(offset, enemy.facing)
		enemy.forced = {
			direction = unitOr(offset, enemy.facing),
			speed = offset.Magnitude / duration,
			untilT = t + duration,
			leap = true,
			target = target,
		}
		setState(enemy, "dash", duration)
		return
	end

	if attack.dash then
		local direction = enemy.facing
		if enemy.dashDir then
			direction = enemy.dashDir -- показан стрелкой с середины замаха
		elseif root then
			direction = unitOr(root.Position - enemy.position, enemy.facing)
		end
		enemy.dashDir = nil
		local duration = attack.dashTime or 0.2
		enemy.faceDir = direction
		enemy.forced = {
			direction = direction,
			speed = attack.dash / duration,
			untilT = t + duration,
			hit = false,
			ram = attack.wallStun ~= nil,
		}
		setState(enemy, "dash", duration)
		return
	end

	if attack.projectileSpeed then
		if root then
			fireProjectile(enemy, attack, root)
		end
		startRecover(enemy, t)
		return
	end

	if attack.radius then
		setState(enemy, "strike", STRIKE_PRESENT)
		local result = areaHit(enemy, attack)
		enemy.model:SetAttribute("LastAttackResult", result)
		fireEvent({
			kind = "area",
			model = enemy.model,
			position = enemy.zoneCenters and enemy.zoneCenters[1] or enemy.attackCenter,
			positions = enemy.zoneCenters,
			radius = attack.radius,
			attack = attack.id,
		})
		if attack.diesOnAttack then
			enemy.exploded = true -- этаж v2: взрыв на мосту пробивает доски
			EnemyService.kill(enemy, enemy.lastHitBy)
			return
		end
		if not handleResult(enemy, attack, result, t) then
			startRecover(enemy, t)
		end
		return
	end

	-- Ближний удар (или серия).
	enemy.hitsLeft = attack.hits or 1
	enemy.nextHitAt = t
	setState(enemy, "strike", STRIKE_PRESENT + MELEE_HIT_GAP * (enemy.hitsLeft - 1))
end

-- ===== Шаг состояния =====

local function stepStrike(enemy, t: number)
	local attack = enemy.attack
	if enemy.hitsLeft and enemy.hitsLeft > 0 and t >= enemy.nextHitAt then
		enemy.hitsLeft -= 1
		enemy.nextHitAt = t + MELEE_HIT_GAP
		local result = meleeHit(enemy, attack, t)
		if handleResult(enemy, attack, result, t) then
			return
		end
	end
	if (not enemy.hitsLeft or enemy.hitsLeft <= 0) and t >= enemy.stateAt + STRIKE_PRESENT then
		startRecover(enemy, t)
	end
end

local function stepDash(enemy, t: number)
	local forced = enemy.forced
	local attack = enemy.attack
	if not forced or not attack then
		finishAttack(enemy, t)
		return
	end

	-- Таран: задел игрока на пути — один удар.
	if forced.ram and not forced.hit then
		local root = livingRoot(enemy.targetPlayer)
		if root then
			local reach = enemy.stats.radius + Combat.Enemy.playerRadius + 0.6
			if flat(root.Position - enemy.position).Magnitude <= reach then
				forced.hit = true
				local result = resolveOnPlayer(enemy, attack, enemy.targetPlayer)
				enemy.model:SetAttribute("LastAttackResult", result)
			end
		end
	end

	if forced.leap and t >= forced.untilT then
		-- Приземление: ровно в центр зоны, удар по площади и ударная волна.
		enemy.forced = nil
		local landed = collide(enemy, forced.target, false)
		enemy.position = Vector3.new(landed.X, FloorGeo.groundAt(landed.X, landed.Z, forced.target.Y + 2) or forced.target.Y, landed.Z)
		setState(enemy, "strike", STRIKE_PRESENT)
		local result = areaHit(enemy, attack)
		enemy.model:SetAttribute("LastAttackResult", result)
		fireEvent({ kind = "area", model = enemy.model, position = forced.target, radius = attack.radius, attack = attack.id })
		clearTelegraph(enemy)
		enemy.model:SetAttribute("EnemyAttack", attack.id)
		startRecover(enemy, t)
		return
	end

	if t >= forced.untilT then
		enemy.forced = nil
		if forced.ram then
			startRecover(enemy, t)
		else
			-- Рывок Тени кончился: два взмаха.
			enemy.hitsLeft = attack.hits or 1
			enemy.nextHitAt = t
			setState(enemy, "strike", STRIKE_PRESENT + MELEE_HIT_GAP * (enemy.hitsLeft - 1))
		end
	end
end

local function moveToward(enemy, direction: Vector3, speedFactor: number, stateName: string)
	enemy.moveDir = direction
	enemy.moveSpeedFactor = speedFactor
	if enemy.state ~= stateName then
		setState(enemy, stateName)
	end
end

local function think(enemy, t: number)
	local stats = enemy.stats
	local player, root, distance = nearestPlayer(enemy.position, stats.sight or 60, stats.anyLevel)
	-- Свой мозг (MiniBossService): вернул true — ход сделан.
	if enemy.brain and enemy.brain(enemy, t, player, root, distance) then
		return
	end
	if not player then
		enemy.moveDir = Vector3.zero
		if enemy.state ~= "idle" then
			setState(enemy, "idle")
		end
		return
	end

	local toPlayer = flat(root.Position - enemy.position)
	local direction = unitOr(toPlayer, enemy.facing)
	enemy.faceDir = direction
	enemy.targetPlayer = player

	local wantsAttack = t >= enemy.nextAttackAt
	local role = stats.role

	if role == "ranged" then
		-- Стреляет с любой дистанции до shotRange, если линия чистая; держится
		-- в полосе keepMin..keepMax. Нет линии (колонна, угол) — подходит, а не
		-- кружит. Упёрся в стену при отходе или обходе — меняет сторону.
		local keepMin = stats.keepMin or 18
		local keepMax = stats.keepMax or 22
		local shotRange = stats.shotRange or (keepMax + 6)
		local from = enemy.position + Vector3.new(0, 1, 0)
		local clear = not lineBlocked(enemy, from, root.Position)
		if wantsAttack and clear and distance <= shotRange and distance >= 4 then
			local attack = enemy.stats.attacks[1]
			enemy.hasSlot = true
			beginAttack(enemy, attack, player, root, t)
			return
		end
		local tangent = Vector3.new(-direction.Z, 0, direction.X) * enemy.circleSign
		if (enemy.stuckFor or 0) > 0.4 then
			enemy.circleSign = -enemy.circleSign
			enemy.stuckFor = 0
			tangent = -tangent
		end
		if not clear or distance > keepMax then
			moveToward(enemy, direction, 1, "approach")
		elseif distance < keepMin - 1 then
			-- Отход; у стены — вбок.
			local away = (enemy.stuckFor or 0) > 0.15 and tangent or (-direction + tangent * 0.35).Unit
			moveToward(enemy, away, 1, "retreat")
		else
			moveToward(enemy, tangent, 0.45, "circle")
		end
		return
	end

	-- Ближние, танк, Треснувший, босс.
	if wantsAttack and not enemy.hasSlot then
		acquireSlot(enemy)
	end

	if enemy.hasSlot then
		local attack = pickAttack(enemy, distance, t)
		if attack then
			beginAttack(enemy, attack, player, root, t)
			return
		end
		moveToward(enemy, direction, 1, "approach")
		return
	end

	-- Нет слота или перезарядка: кружим на 6–8 стадах.
	local behavior = Enemies.Behavior
	local middle = (behavior.circleMin + behavior.circleMax) / 2
	if role == "disruptor" then
		-- Мартир не отступает: он бежит на игрока.
		moveToward(enemy, direction, 1, "approach")
	elseif distance > behavior.circleMax + 1 then
		moveToward(enemy, direction, 0.8, "approach")
	elseif distance < behavior.circleMin - 1 then
		moveToward(enemy, -direction, 0.7, "retreat")
	else
		local tangent = Vector3.new(-direction.Z, 0, direction.X) * enemy.circleSign
		local radial = distance > middle and direction * 0.25 or -direction * 0.25
		moveToward(enemy, (tangent + radial).Unit, 0.6, "circle")
	end
end

local function step(enemy, t: number, dt: number)
	if not enemy.alive then
		return
	end
	-- Объекты (знамя, цепь, баррикада): без ИИ, только здоровье.
	if enemy.stats.role == "object" then
		if enemy.state == "spawning" and t >= enemy.spawnUntil then
			setState(enemy, "idle")
		end
		return
	end

	-- Появление.
	if t < enemy.spawnUntil then
		enemy.moveDir = Vector3.zero
		return
	end
	if enemy.state == "spawning" then
		setState(enemy, "idle")
	end

	-- Сцена смены фазы: босс стоит и не атакует.
	if t < (enemy.sceneUntil or 0) then
		enemy.moveDir = Vector3.zero
		return
	end
	if enemy.state == "phase" then
		setState(enemy, "idle")
	end

	-- Оглушение.
	if t < enemy.stunUntil then
		enemy.moveDir = Vector3.zero
		return
	end
	if enemy.state == "stunned" then
		enemy.model:SetAttribute("EnemyStunnedUntil", 0)
		setState(enemy, "idle")
	end

	-- Взгляд на игрока, пока замах не «зафиксирован».
	if enemy.state == "windup" then
		enemy.moveDir = Vector3.zero
		-- Отскок перед выстрелом: короткое принудительное движение в замахе.
		if enemy.forced and enemy.forced.windupMove and t >= enemy.forced.untilT then
			enemy.forced = nil
		end
		if t < enemy.lockFacingAt then
			local root = livingRoot(enemy.targetPlayer)
			if root then
				enemy.faceDir = unitOr(root.Position - enemy.position, enemy.facing)
			end
		end
		if enemy.aimLockAt and t >= enemy.aimLockAt then
			enemy.aimLockAt = nil
			local root = livingRoot(enemy.targetPlayer)
			local attack = enemy.attack
			if root and attack then
				if attack.projectileSpeed then
					enemy.aimPoint = root.Position
					enemy.model:SetAttribute("EnemyAimPoint", root.Position)
				elseif attack.dash then
					local dir = unitOr(flat(root.Position - enemy.position), enemy.facing)
					enemy.dashDir = dir
					enemy.faceDir = dir
					enemy.model:SetAttribute("EnemyDashDir", dir * (attack.dash + (attack.range or 0)))
				end
			end
		end
		if not livingRoot(enemy.targetPlayer) or veiled(enemy.targetPlayer) then
			cancelAttack(enemy, t)
			setState(enemy, "idle")
			return
		end
		if t >= enemy.stateUntil then
			strike(enemy, t)
		end
		return
	end

	if enemy.state == "dash" then
		stepDash(enemy, t)
		return
	end

	if enemy.state == "strike" then
		enemy.moveDir = Vector3.zero
		stepStrike(enemy, t)
		return
	end

	-- Канал фирменной атаки босса (Systems/BossMoves): стоит и «ведёт» её,
	-- затем обычное восстановление.
	if enemy.state == "channel" then
		enemy.moveDir = Vector3.zero
		if t >= enemy.stateUntil then
			startRecover(enemy, t)
		end
		return
	end

	if enemy.state == "recover" then
		enemy.moveDir = Vector3.zero
		if t >= enemy.stateUntil then
			finishAttack(enemy, t)
		end
		return
	end

	think(enemy, t)
end

-- ===== Движение =====

local function move(enemy, dt: number)
	local forced = enemy.forced
	-- Толчок способностью (EnemyService.shove) живёт до своего срока.
	if forced and forced.shove and now() >= forced.untilT then
		enemy.forced = nil
		forced = nil
	end
	local direction, speed
	if forced then
		direction, speed = forced.direction, forced.speed
	else
		direction = enemy.moveDir
		speed = enemy.stats.speed * (enemy.moveSpeedFactor or 1)
		if enemy.phase2Active and enemy.stats.isBoss then
			speed *= 1.1
		end
		if enemy.slow then
			if now() < enemy.slow.untilT then
				speed *= enemy.slow.factor
			else
				enemy.slow = nil
			end
		end
	end

	if enemy.stats.role == "object" then
		return
	end
	if direction.Magnitude > 0.01 and speed > 0 then
		local target = enemy.position + direction * speed * dt
		local resolved, blocked = collide(enemy, target, forced == nil)
		-- Этаж v2: скольжение вдоль стен карты и пол под ногами (пандусы,
		-- лестницы, балконы). В дыру и с обрыва враг не шагает.
		local slid, hitWall = FloorGeo.slide(enemy.position, resolved - enemy.position, enemy.stats.radius * 0.8)
		blocked = blocked or hitWall
		-- Сколько уже упирается (стрелок по этому меняет сторону обхода).
		local before = enemy.position
		local ground = FloorGeo.groundAt(slid.X, slid.Z, enemy.position.Y)
		if ground == nil or ground < enemy.position.Y - FloorGeo.DropDown then
			blocked = true
		else
			resolved = Vector3.new(slid.X, ground, slid.Z)
		end
		if ground ~= nil and ground >= enemy.position.Y - FloorGeo.DropDown then
			enemy.position = resolved
		end
		local progress = flat(enemy.position - before).Magnitude
		if not forced and progress < speed * dt * 0.3 then
			enemy.stuckFor = (enemy.stuckFor or 0) + dt
		else
			enemy.stuckFor = 0
		end
		if forced then
			if not forced.shove then
				enemy.faceDir = forced.direction
			end
			if blocked and forced.ram then
				-- Таран в стену: босс оглушён (приложение Е).
				local attack = enemy.attack
				local stun = attack and attack.wallStun or 2
				enemy.forced = nil
				EnemyService.stun(enemy, stun)
				fireEvent({ kind = "wallHit", model = enemy.model, position = enemy.position })
			end
		end
	else
		-- Стоим: только расталкиваемся с соседями.
		enemy.position = collide(enemy, enemy.position, true)
	end

	-- Плавный разворот. turnRate (град/с) — медленный разворот Сотника:
	-- за спину ему можно зайти рывком.
	if enemy.turnRate and not (forced and not forced.shove) then
		local current = math.atan2(enemy.facing.X, enemy.facing.Z)
		local wanted = math.atan2(enemy.faceDir.X, enemy.faceDir.Z)
		local delta = (wanted - current + math.pi) % (2 * math.pi) - math.pi
		local maxStep = math.rad(enemy.turnRate) * dt
		local angle = current + math.clamp(delta, -maxStep, maxStep)
		enemy.facing = Vector3.new(math.sin(angle), 0, math.cos(angle))
	else
		local blend = math.min(1, dt * (enemy.state == "windup" and 8 or 12))
		local mixed = enemy.facing + (enemy.faceDir - enemy.facing) * blend
		enemy.facing = unitOr(mixed, enemy.faceDir)
	end

	-- Подброс (EnemyService.launch): дуга вверх-вниз над точкой на земле.
	local lift = 0
	local air = enemy.air
	if air then
		local k = (now() - air.startT) / air.duration
		if k >= 1 then
			enemy.air = nil
		else
			lift = 4 * air.height * k * (1 - k)
		end
	end

	local root = enemy.root
	if root.Parent then
		local height = enemy.stats.height / 2
		local position = Vector3.new(enemy.position.X, enemy.position.Y + height + lift, enemy.position.Z)
		root.CFrame = CFrame.lookAt(position, position + enemy.facing)
	end
end

local function removeFromList(enemy)
	local index = table.find(enemies, enemy)
	if index then
		table.remove(enemies, index)
	end
end

-- ===== Остановка времени («Дары Эха», FloorBoonService) =====
-- Враги внутри замороженной папки этажа не думают, не двигаются и не получают
-- урон. Замах в момент остановки отменяется; после возобновления все отметки
-- времени врага сдвигаются на длину паузы, плюс короткая передышка.
local frozenFolders = {} -- [folder] = время начала паузы

local function frozenBy(enemy)
	if next(frozenFolders) == nil then
		return nil
	end
	for folder in pairs(frozenFolders) do
		if enemy.model:IsDescendantOf(folder) then
			return folder
		end
	end
	return nil
end

local function shiftTimes(tbl, paused: number, around: number)
	for key, value in pairs(tbl) do
		if type(value) == "number" and type(key) == "string" and (key:sub(-2) == "At" or key:sub(-5) == "Until" or key == "untilT" or key == "t0") then
			-- только отметки времени около паузы (не урон, не счётчики)
			if math.abs(value - around) < 3600 then
				tbl[key] = value + paused
			end
		end
	end
end

local function freezeEnemy(enemy, t: number)
	if enemy.frozenAt then
		return
	end
	enemy.frozenAt = t
	if enemy.attack or enemy.state == "windup" or enemy.state == "strike" or enemy.state == "dash" then
		cancelAttack(enemy, t)
		setState(enemy, "idle")
	end
	enemy.forced = nil
	enemy.moveDir = Vector3.zero
	enemy.model:SetAttribute("TimeFrozen", true)
end

local function thawEnemy(enemy, t: number, grace: number)
	local at = enemy.frozenAt
	if not at then
		return
	end
	enemy.frozenAt = nil
	local paused = math.max(t - at, 0)
	shiftTimes(enemy, paused, at)
	if enemy.attackUsedAt then
		for id, used in pairs(enemy.attackUsedAt) do
			enemy.attackUsedAt[id] = used + paused
		end
	end
	enemy.nextAttackAt = math.max(enemy.nextAttackAt or 0, t + grace)
	enemy.model:SetAttribute("TimeFrozen", nil)
end

function EnemyService.freeze(folder)
	if not folder or frozenFolders[folder] then
		return
	end
	local t = now()
	frozenFolders[folder] = t
	for _, enemy in ipairs(enemies) do
		if enemy.alive and enemy.model:IsDescendantOf(folder) then
			freezeEnemy(enemy, t)
		end
	end
	fireEvent({ kind = "timeStop", folder = folder })
end

function EnemyService.unfreeze(folder, grace: number?)
	if not folder or not frozenFolders[folder] then
		return
	end
	frozenFolders[folder] = nil
	local t = now()
	for _, enemy in ipairs(enemies) do
		if enemy.alive and enemy.frozenAt and not frozenBy(enemy) then
			thawEnemy(enemy, t, grace or 1)
		end
	end
	fireEvent({ kind = "timeResume", folder = folder })
end

local function heartbeat(dt: number)
	local t = now()
	local snapshot = table.clone(enemies)
	for _, enemy in ipairs(snapshot) do
		if enemy.alive and (enemy.frozenAt or (next(frozenFolders) ~= nil and frozenBy(enemy))) then
			-- Время стоит: враг замер (появившийся во время паузы — тоже).
			if not enemy.frozenAt then
				freezeEnemy(enemy, t)
			end
			enemy.moveDir = Vector3.zero
		elseif enemy.alive then
			if not enemy.model.Parent then
				-- Модель удалили снаружи: тихо убираем и логику.
				EnemyService.remove(enemy)
			else
				local ok, err = pcall(step, enemy, t, dt)
				if not ok then
					warn("[EnemyService] ошибка шага «" .. enemy.stats.name .. "»: " .. tostring(err))
				end
				if enemy.alive then
					move(enemy, dt)
				end
			end
		end
	end
end

local function ensureLoop()
	if loopConnection then
		return
	end
	loopConnection = RunService.Heartbeat:Connect(heartbeat)
end

-- ===== Публичный интерфейс =====

local function buildModel(stats, position: Vector3, name: string?)
	local model = Instance.new("Model")
	model.Name = name or stats.name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = stats.size
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.CFrame = CFrame.new(position.X, position.Y + stats.height / 2, position.Z)
	root.Parent = model

	model.PrimaryPart = root
	return model, root
end

-- Функции (enemy) → (), вызываются после появления каждого врага.
EnemyService.spawnHooks = {}
-- dealt(attacker, taken, enemy) — после урона по врагу (ставит FloorBoonService).
EnemyService.hooks = { dealt = nil }
-- onPlayerHit(enemy, player, result, taken) — урон игроку прошёл (ставит EnemyDebuffs).
EnemyService.onPlayerHit = nil

-- options: parent, bounds, obstacles, room, name, introDelay
function EnemyService.spawn(stats, position: Vector3, options)
	local opts = options or {}
	-- Этаж v2: ставим на пол под точкой (балкон, пандус, галерея).
	local groundY = FloorGeo.groundAt(position.X, position.Z, position.Y + 1)
	position = Vector3.new(position.X, groundY or position.Y, position.Z)
	local model, root = buildModel(stats, position, opts.name)
	local t = now()
	local grace = math.max(Enemies.Behavior.spawnGrace, Enemies.Behavior.spawnAssemble)
	if opts.introDelay then
		grace = math.max(grace, opts.introDelay)
	end

	local enemy = {
		model = model,
		root = root,
		stats = stats,
		health = stats.health,
		maxHealth = stats.maxHealth or stats.health,
		armor = stats.armor or 0,
		alive = true,
		state = "spawning",
		stateAt = t,
		stateUntil = t + grace,
		spawnUntil = t + grace,
		immuneUntil = opts.introDelay and (t + opts.introDelay) or 0,
		stunUntil = 0,
		phaseUntil = 0,
		attackUsedAt = {},
		nextAttackAt = t + grace,
		bounds = opts.bounds,
		obstacles = opts.obstacles or {},
		room = opts.room,
		position = position,
		facing = Vector3.new(0, 0, 1),
		faceDir = Vector3.new(0, 0, 1),
		moveDir = Vector3.zero,
		moveSpeedFactor = 1,
		circleSign = math.random() < 0.5 and -1 or 1,
		phase2Active = false,
		phaseIndex = 1,
		hasSlot = false,
		counted = false,
		lastHitBy = nil,
	}

	local first = stats.attacks and stats.attacks[1]
	enemy.damage = first and first.damage or 0

	model:SetAttribute("EnemyType", stats.typeId)
	model:SetAttribute("EnemyName", stats.name)
	model:SetAttribute("EnemyRole", stats.role)
	model:SetAttribute("EnemyIsBoss", stats.isBoss == true)
	model:SetAttribute("EnemyHeight", stats.height)
	model:SetAttribute("EnemyBodyRadius", stats.radius)
	model:SetAttribute("EnemyDamage", enemy.damage)
	model:SetAttribute("BossPhase", 1)
	model:SetAttribute("SpawnedAt", t)
	model:SetAttribute("LastAttackResult", "none")
	model:SetAttribute("EnemyStunnedUntil", 0)
	publishHealth(enemy)
	clearTelegraph(enemy)
	setState(enemy, "spawning", grace)

	model.Parent = opts.parent or Workspace
	table.insert(enemies, enemy)
	ensureLoop()
	-- Хуки появления: Floor2Service вешает поведение врагов этажа 2.
	for _, hook in ipairs(EnemyService.spawnHooks) do
		local ok, err = pcall(hook, enemy)
		if not ok then
			warn("[EnemyService] spawnHook: " .. tostring(err))
		end
	end
	return enemy
end

-- Урон врагу. info.counter — усиленный удар после парирования, info.crit —
-- крит эха (клиент рисует цифру крупнее и жёлтым).
function EnemyService.applyDamage(enemy, amount: number, attacker, info)
	if not enemy or not enemy.alive then
		return 0, "dead"
	end
	if enemy.frozenAt then
		return 0, "immune" -- время остановлено
	end
	local t = now()
	if t < enemy.immuneUntil or t < enemy.phaseUntil then
		return 0, "immune"
	end

	-- Свои правила урона (стена щита Сотника): 0 — удар отбит.
	if enemy.onDamage then
		amount = enemy.onDamage(enemy, amount, attacker, info) or amount
		if amount <= 0 then
			fireEvent({ kind = "blocked", model = enemy.model, position = enemy.position + Vector3.new(0, enemy.stats.height * 0.55, 0) })
			return 0, "blocked"
		end
	end
	-- Прерываемый замах («Последний болт»): любой удар сбивает его.
	if enemy.state == "windup" and enemy.attack and enemy.attack.interruptible then
		local stunTime = enemy.attack.interruptStun or 2
		fireEvent({ kind = "interrupted", model = enemy.model, attack = enemy.attack.id, position = enemy.position })
		EnemyService.stun(enemy, stunTime, true)
	end

	-- Уязвимость («Отпереть»): +N% входящего урона до срока.
	if enemy.vulnerable and t < enemy.vulnerable.untilT then
		amount *= 1 + enemy.vulnerable.amount
	end

	-- Древо талантов: «Точный удар» (+15% по оглушённым), «Пробивающий луч»
	-- и стаки «Разрушителя» снимают броню.
	local pierce
	amount, pierce = TalentMods.outgoing(attacker, enemy, amount, t)

	local armor = enemy.armor
	if enemy.armorBreak and t < enemy.armorBreak.untilT then
		armor = math.max(armor - enemy.armorBreak.amount, 0)
	end
	armor = math.max(armor - pierce, 0)
	local taken = Combat.Armor.mitigate(amount, armor)
	enemy.health = math.max(enemy.health - taken, 0)
	if taken > 0 then
		TalentMods.afterHit(attacker, enemy, t)
		-- Пожизненный счётчик урона достижений (только урон от игроков).
		if attacker and attacker:IsA("Player") then
			StatsService.addDamage(attacker, taken)
		end
		-- «Кровавая жажда» и прочее «после удара игрока» (FloorBoonService).
		if EnemyService.hooks.dealt and attacker then
			local ok, err = pcall(EnemyService.hooks.dealt, attacker, taken, enemy)
			if not ok then
				warn("[EnemyService] hooks.dealt: " .. tostring(err))
			end
		end
	end
	if attacker then
		enemy.lastHitBy = attacker
	end
	publishHealth(enemy)

	fireEvent({
		kind = "damage",
		model = enemy.model,
		position = enemy.position + Vector3.new(0, enemy.stats.height + 0.5, 0),
		amount = taken,
		counter = info and info.counter == true or false,
		crit = info and info.crit == true or false,
		stunned = t < enemy.stunUntil,
	})

	-- Фазы босса: каждая ровно один раз, по порогу здоровья. Если удар
	-- перескочил через два порога, сцена играется для последней фазы.
	local phases = enemy.stats.phases
	if enemy.stats.isBoss and phases and enemy.health > 0 then
		local entered = nil
		while phases[enemy.phaseIndex] and enemy.health / enemy.maxHealth <= phases[enemy.phaseIndex].threshold do
			entered = phases[enemy.phaseIndex]
			enemy.phaseIndex += 1
			if entered.summon and enemy.onPhase then
				enemy.onPhase(enemy, enemy.phaseIndex, entered)
			end
		end
		if entered then
			enemy.phase2Active = true
			cancelAttack(enemy, t)
			enemy.moveDir = Vector3.zero
			enemy.forced = nil
			-- Неуязвимость на смене фазы — минимальная: только чтобы одна серия
			-- ударов не проскочила два порога. Сама сцена (босс не атакует)
			-- длится sceneTime — это окно для ударов игрока.
			enemy.phaseUntil = t + PHASE_IMMUNITY
			enemy.sceneUntil = t + (entered.sceneTime or 2)
			enemy.model:SetAttribute("BossPhase", enemy.phaseIndex)
			enemy.model:SetAttribute("BossPhaseName", entered.name or "")
			setState(enemy, "phase", entered.sceneTime or 2)
			fireEvent({
				kind = "phase2",
				phase = enemy.phaseIndex,
				name = entered.name,
				model = enemy.model,
				position = enemy.position,
			})
		end
	end

	if enemy.health <= 0 then
		EnemyService.kill(enemy, attacker)
	end

	return taken, "applied"
end

-- Снизить броню врага (Раскол): amount на duration секунд.
function EnemyService.breakArmor(enemy, amount: number, duration: number)
	if enemy and enemy.alive then
		enemy.armorBreak = { amount = amount, untilT = now() + duration }
		-- Клиенту: значок «снятая броня» над врагом (ТЗ врагов, 2.3).
		enemy.model:SetAttribute("EnemyArmorBreakUntil", enemy.armorBreak.untilT)
	end
end

-- Уязвимость: враг получает на amount (доля) больше урона duration секунд.
function EnemyService.setVulnerable(enemy, amount: number, duration: number)
	if enemy and enemy.alive then
		local untilT = now() + duration
		if not enemy.vulnerable or enemy.vulnerable.untilT < untilT or enemy.vulnerable.amount < amount then
			enemy.vulnerable = { amount = amount, untilT = untilT }
		end
		enemy.model:SetAttribute("EnemyVulnerableUntil", enemy.vulnerable.untilT)
	end
end

-- Толчок способностью: сдвинуть врага по плоскости на distance стадов за
-- time секунд (по стенам скользит, с обрыва не падает — как обычный шаг).
-- Боссов и объекты не двигает; танк сдвигается вдвое меньше. Рывок/таран
-- врага толчок не перебивает.
function EnemyService.shove(enemy, direction: Vector3, distance: number, time: number?)
	if not enemy or not enemy.alive or enemy.stats.role == "object" or enemy.stats.isBoss then
		return false
	end
	if enemy.forced and not enemy.forced.shove then
		return false
	end
	local flatDir = Vector3.new(direction.X, 0, direction.Z)
	if flatDir.Magnitude < 0.01 or distance <= 0 then
		return false
	end
	if enemy.stats.role == "tank" then
		distance *= 0.5
	end
	local duration = math.max(time or 0.15, 0.05)
	enemy.forced = {
		shove = true,
		direction = flatDir.Unit,
		speed = distance / duration,
		untilT = now() + duration,
	}
	return true
end

-- Замедление: скорость шага × (1 − amount) на duration секунд (рывки и
-- тараны врага не трогает). Объекты не замедляются.
function EnemyService.slow(enemy, amount: number, duration: number)
	if not enemy or not enemy.alive or enemy.stats.role == "object" then
		return
	end
	local untilT = now() + duration
	local factor = math.clamp(1 - amount, 0, 1)
	if not enemy.slow or enemy.slow.untilT < untilT or enemy.slow.factor > factor then
		enemy.slow = { factor = factor, untilT = untilT }
	end
	enemy.model:SetAttribute("EnemySlowedUntil", enemy.slow.untilT)
end

-- Подброс: враг взлетает на height стадов и падает за duration секунд,
-- всё это время оглушён. Боссов и объекты не подбрасывает; танка — вдвое ниже.
function EnemyService.launch(enemy, height: number, duration: number)
	if not enemy or not enemy.alive or enemy.stats.role == "object" or enemy.stats.isBoss then
		return false
	end
	if enemy.stats.role == "tank" then
		height *= 0.5
	end
	enemy.air = { startT = now(), duration = duration, height = height }
	enemy.model:SetAttribute("EnemyAirUntil", now() + duration)
	EnemyService.stun(enemy, duration)
	return true
end

function EnemyService.kill(enemy, attacker)
	if not enemy.alive then
		return
	end
	enemy.alive = false
	enemy.forced = nil
	releaseSlot(enemy)
	clearTelegraph(enemy)
	local linger = enemy.stats.deathLinger or DEATH_LINGER
	setState(enemy, "dead", linger)
	enemy.model:SetAttribute("EnemyHealth", 0)

	fireEvent({
		kind = "death",
		model = enemy.model,
		position = Vector3.new(enemy.position.X, enemy.position.Y + enemy.stats.height / 2, enemy.position.Z),
		isBoss = enemy.stats.isBoss == true,
		typeId = enemy.stats.typeId,
		killer = attacker,
	})

	if enemy.onDeath then
		local ok, err = pcall(enemy.onDeath, enemy, attacker)
		if not ok then
			warn("[EnemyService] onDeath: " .. tostring(err))
		end
	end
	-- onKilled — для поведения врага (лужа Утопленника); onDeath занят этажом.
	if enemy.onKilled then
		local ok, err = pcall(enemy.onKilled, enemy, attacker)
		if not ok then
			warn("[EnemyService] onKilled: " .. tostring(err))
		end
	end

	task.delay(linger, function()
		if enemy.model and enemy.model.Parent then
			enemy.model:Destroy()
		end
		removeFromList(enemy)
	end)
end

-- Тихое удаление без наград и без вызова onDeath: перезапуск комнаты.
function EnemyService.remove(enemy)
	if not enemy then
		return
	end
	enemy.alive = false
	enemy.forced = nil
	enemy.attack = nil
	releaseSlot(enemy)
	if enemy.model then
		enemy.model:Destroy()
	end
	removeFromList(enemy)
end

function EnemyService.clear()
	for _, enemy in ipairs(table.clone(enemies)) do
		EnemyService.remove(enemy)
	end
	enemies = {}
	activeMeleeAttackers = 0
end

function EnemyService.all()
	return enemies
end

function EnemyService.availableAttacks(enemy)
	return availableAttacks(enemy)
end

-- Для ProjectileService: отражённый снаряд бьёт по врагам.
ProjectileService.enemyProvider = function()
	return enemies
end
ProjectileService.enemyDamage = function(enemy, amount, attacker)
	return EnemyService.applyDamage(enemy, amount, attacker, { counter = true, reflected = true })
end
ProjectileService.enemyStun = function(enemy, duration)
	EnemyService.stun(enemy, duration, true)
end

-- Для MiniBossService: начать атаку из своего мозга и найти игрока.
EnemyService.beginAttack = function(enemy, attack, player, root, t)
	return beginAttack(enemy, attack, player, root, t)
end
EnemyService.moveToward = function(enemy, direction, speedFactor, stateName)
	return moveToward(enemy, direction, speedFactor, stateName)
end
EnemyService.setState = function(enemy, stateName, duration)
	return setState(enemy, stateName, duration)
end
EnemyService.fireEvent = fireEvent
EnemyService.livingRoot = livingRoot
-- Этаж 2 (Floor2Service): свой удар целиком — урон, площадь, восстановление.
EnemyService.resolveOnPlayer = function(enemy, attack, player)
	return resolveOnPlayer(enemy, attack, player)
end
EnemyService.areaHit = function(enemy, attack)
	return areaHit(enemy, attack)
end
EnemyService.startRecover = function(enemy, t)
	return startRecover(enemy, t)
end
EnemyService.handleResult = function(enemy, attack, result, t)
	return handleResult(enemy, attack, result, t)
end
EnemyService.feetY = feetY
EnemyService.lineBlocked = function(enemy, from, to)
	return lineBlocked(enemy, from, to)
end

return EnemyService
