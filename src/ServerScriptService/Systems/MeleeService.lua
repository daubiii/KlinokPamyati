--!nonstrict
-- MeleeService (сервер)
-- Удар и комбо игрока, попадание, разрешение парирования.
-- Клиент только просит удар; попадание и урон считает сервер (§12).
--
-- Комбо из 3 ударов, урон с бронёй цели, контратака ×2 после успешного
-- парирования. Направление удара — то, куда смотрит корпус (а корпус
-- развёрнут камерой, см. CameraController).
--
-- Урон берётся из экипированного оружия профиля (тип, редкость, заточка)
-- и растёт от стаков душ мобов (раздел 5 плана).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RemoteGuard = require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("RemoteGuard"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Progression = require(Shared.Config.Progression)
local Weapons = require(Shared.Config.Weapons)
local Net = require(Shared.Net.Net)
local DebugState = require(Shared.Net.DebugState)

local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)
local EchoService = require(script.Parent.EchoService)
local WeaponAbilities = require(script.Parent.WeaponAbilities)
local TalentMods = require(script.Parent.TalentMods)
local FloorBoonState = require(script.Parent.FloorBoonState)

local MeleeService = {}
MeleeService.swingHooks = {}
-- rangedAttack(player, weapon, attack) -> число снарядов: удар посохом мага (ставит MageService.start).
MeleeService.rangedAttack = nil :: any

local function characterRoot(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return nil
	end
	return root
end

-- Насколько точка удара от клиента может отличаться от серверной позиции
-- героя: задержка сети + выпад (до 2,4 стада). 6 стадов позволяли бить
-- на полдальности дальше оружия (PLAN_DORABOTKI P1-5), 3 стада закрывают
-- выпад и пинг до ~150 мс; при большем смещении сервер бьёт со своей позиции.
local AIM_TOLERANCE = 3

-- Точка и направление удара. Клиент присылает свои (позиция после выпада,
-- взгляд камеры в момент клика): сервер видит героя с задержкой, и без этого
-- удар по врагу на краю дальности или сразу после поворота уходил мимо.
-- Чужим данным верим, только если точка рядом с серверной позицией.
local function aimOf(root, aim)
	local origin = root.Position
	local look = root.CFrame.LookVector
	if type(aim) == "table" and typeof(aim.origin) == "Vector3" and typeof(aim.forward) == "Vector3" then
		local flatOffset = Vector3.new(aim.origin.X - origin.X, 0, aim.origin.Z - origin.Z)
		if flatOffset.Magnitude <= AIM_TOLERANCE and math.abs(aim.origin.Y - origin.Y) <= 4 then
			origin = aim.origin
			look = aim.forward
		end
	end
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 0.01 then
		return origin, nil
	end
	return origin, forward.Unit
end

-- Цели в конусе перед персонажем. Размер врага учитываем: по большому врагу
-- (босс) попадаем и краем тела, а не только центром.
function MeleeService.findTargets(player, range: number?, arcDegrees: number?, aim)
	local root = characterRoot(player)
	if not root then
		return {}
	end

	local reach = range or Combat.Attack.range
	local arc = arcDegrees or Combat.Attack.arcDegrees
	local halfArc = math.rad(arc / 2)

	local origin, forward = aimOf(root, aim)
	if not forward then
		return {}
	end

	local hits = {}
	for _, enemy in ipairs(EnemyService.all()) do
		if enemy.alive then
			-- Этаж v2: враги с высотой. Плоская дистанция + разница уровней.
			local toTarget = Vector3.new(enemy.position.X - origin.X, 0, enemy.position.Z - origin.Z)
			local distance = toTarget.Magnitude
			local radius = enemy.stats.radius
			local dy = math.abs(enemy.position.Y - (origin.Y - 3))
			if distance - radius <= reach and dy <= math.max(4.5, enemy.stats.height * 0.7) then
				local inArc = true
				if distance > 0.01 then
					local slack = math.atan2(radius, distance)
					inArc = forward:Dot(toTarget.Unit) >= math.cos(math.min(halfArc + slack, math.pi))
				end
				if inArc then
					table.insert(hits, enemy)
				end
			end
		end
	end
	return hits
end

local function hitDestructibleProps(player, origin: Vector3, forward: Vector3, reach: number, arcDegrees: number): number
	if player:GetAttribute("FloorId") ~= 3 or player:GetAttribute("Zone") ~= "Floor" then
		return 0
	end

	local runtime = Workspace:FindFirstChild("Floor3Runtime")
	local world = runtime and runtime:FindFirstChild("Floor3World")
	local props = world and world:FindFirstChild("Destructibles")
	if not props then
		return 0
	end

	local remote = Net.get("FloorEvent")
	local halfArc = math.rad(arcDegrees / 2)
	local hitCount = 0
	for _, prop in ipairs(props:GetChildren()) do
		if prop:IsA("Model") and prop:GetAttribute("Broken") ~= true then
			local position = prop:GetAttribute("HitPosition")
			if typeof(position) ~= "Vector3" then
				position = prop:GetPivot().Position
			end
			local toProp = Vector3.new(position.X - origin.X, 0, position.Z - origin.Z)
			local distance = toProp.Magnitude
			local radius = prop:GetAttribute("HitRadius") or 1
			local dy = math.abs(position.Y - (origin.Y - 3))
			local inArc = distance <= 0.01
				or forward:Dot(toProp.Unit) >= math.cos(math.min(halfArc + math.atan2(radius, distance), math.pi))

			if distance - radius <= reach and dy <= 4.5 and inArc then
				local health = prop:GetAttribute("Health")
				local maxHealth = prop:GetAttribute("MaxHealth")
				if type(health) == "number" and type(maxHealth) == "number" and health > 0 then
					health -= 1
					local broken = health <= 0
					prop:SetAttribute("Health", math.max(health, 0))
					prop:SetAttribute("Broken", broken)
					hitCount += 1

					local payload = {
						kind = "f3prop",
						propKind = prop:GetAttribute("PropKind"),
						position = position,
						health = math.max(health, 0),
						maxHealth = maxHealth,
						broken = broken,
					}
					if remote then
						for _, recipient in ipairs(Players:GetPlayers()) do
							if recipient:GetAttribute("FloorId") == 3 and recipient:GetAttribute("Zone") == "Floor" then
								remote:FireClient(recipient, payload)
							end
						end
					end

					if broken then
						for _, piece in ipairs(prop:GetDescendants()) do
							if piece:IsA("BasePart") then
								piece.CanCollide = false
								piece.Transparency = 1
							end
						end
						task.delay(0.25, function()
							if prop.Parent then
								prop:Destroy()
							end
						end)
					end
				end
			end
		end
	end
	return hitCount
end

-- Для снарядов посоха (MageService.propStep): ломаемые декорации на пути.
MeleeService.hitDestructibleProps = hitDestructibleProps

local function equippedWeapon(player)
	local profile = DataService.get(player)
	return profile.equippedWeapon
end

function MeleeService.requestAttack(player, aim)
	-- Во время способности (кружение, прыжок, поворот ключа) не бьём.
	if WeaponAbilities.isCasting(player) then
		return { ok = false, reason = "casting" }
	end
	-- Время остановлено (выбор «Дара Эха»): не бьём.
	if player:GetAttribute("BoonPause") then
		return { ok = false, reason = "paused" }
	end
	local stats = CombatService.getStats(player)
	local weapon = equippedWeapon(player)
	local profile = DataService.get(player)
	local bonuses = Progression.stackBonuses(profile.soulStacks or 0, FloorBoonState.soulCapBonus(player))
	-- «Сила душ» (древо воина): ещё +0,2% урона за стак, до +8%.
	bonuses.damage += TalentMods.soulDamage(player, profile.soulStacks or 0)
	-- «Голод душ» (дар этажа): весь урон от душ ×(1 + n).
	bonuses.damage *= FloorBoonState.soulDamageMult(player)
	-- Статы конкретного предмета (дальность, дуга, скорость, пошатывание).
	local item = Weapons.stats(weapon.typeId, weapon.rarityId, weapon.id)

	-- Интервал между ударами: база конфига, скорость оружия и класса, стаки душ.
	local cooldown = Weapons.attackInterval(
		Combat.Attack.hitInterval,
		weapon.typeId,
		(stats.attackSpeed - 1) + bonuses.attackSpeed,
		weapon.id
	)

	local combo, reason, actual = CombatService.beginAttack(
		player,
		cooldown,
		Combat.Attack.comboLength,
		Combat.Attack.comboWindow,
		Weapons.finisherInterval(cooldown, weapon.typeId, Combat.Attack.comboRecovery, weapon.id)
	)
	DebugState.bump("Melee", "Requests")
	if not combo then
		DebugState.bump("Melee", "Rejected_" .. tostring(reason))
		return { ok = false, reason = reason }
	end

	-- Заточка за золото убрана (UI v2): урон растёт от ★ уровня эха, плюс крит.
	local damage = Weapons.damage(stats.weaponDamage, weapon.typeId, weapon.rarityId, 0, weapon.id)
		* EchoService.damageMultiplier(weapon)
	local strikeBase = damage * (1 + bonuses.damage) -- для пассивки «Скважина»
	local critMul, isCrit = EchoService.rollCrit(weapon)
	if not isCrit then
		-- «Меткость» (древо мага): свой шанс крита поверх эха.
		critMul, isCrit = TalentMods.extraCrit(player)
	end
	damage *= critMul
	damage = damage * (1 + bonuses.damage)
	-- Аксессуары и леденец (InventoryService через CombatService.hooks).
	if CombatService.hooks.damageBonus then
		local okBonus, gearBonus = pcall(CombatService.hooks.damageBonus, player)
		if okBonus and type(gearBonus) == "number" then
			damage *= 1 + math.max(gearBonus, 0)
		end
	end
	if combo == Combat.Attack.comboLength then
		-- «Размах» / «Росчерк»: финал серии ещё +15%.
		damage *= Combat.Attack.finisherMultiplier * TalentMods.finisherMultiplier(player)
	end
	local counter = CombatService.consumeCounter(player)
	if counter then
		-- «Контратака» (путь «Парирование»): ×2,2 вместо ×2,0.
		damage = damage * TalentMods.counterMultiplier(player, Combat.Parry.counterDamageMultiplier)
	end
	-- «Ответный удар»: первая атака после полученного урона +50%.
	damage *= TalentMods.consumeRetaliate(player)
	if weapon.typeId == "staff" then
		-- «Резкость» (древо мага): первый удар посохом после заклинания +25%.
		damage *= TalentMods.consumeEmpower(player)
	end

	-- Посох мага: вместо дуги — снаряды (MageService.rangedAttack, полёт в MageBolts).
	if MeleeService.rangedAttack and weapon.typeId == "staff" then
		local root = characterRoot(player)
		local shots = 0
		if root then
			local origin, forward = aimOf(root, aim)
			if forward then
				local ok, result = pcall(MeleeService.rangedAttack, player, weapon, {
					origin = origin,
					forward = forward,
					damage = damage,
					strikeBase = strikeBase,
					combo = combo,
					counter = counter,
					crit = isCrit,
					item = item,
					cooldown = cooldown,
				})
				if ok then
					shots = type(result) == "number" and result or 0
				else
					warn("[MeleeService] rangedAttack: " .. tostring(result))
				end
			end
		end
		CombatService.recordAttackDamage(player, damage)
		DebugState.set("Melee", "LastCombo", combo)
		DebugState.set("Melee", "LastDamage", damage)
		DebugState.set("Melee", "LastCounter", counter)
		local payload = {
			combo = combo,
			damage = damage,
			hits = 0,
			shots = shots,
			ranged = true,
			counter = counter,
			crit = isCrit,
			props = 0,
			cooldown = cooldown,
			pause = actual,
			weapon = weapon.typeId,
			weaponId = weapon.id,
		}
		local remote = Net.get("AttackPerformed")
		if remote then
			remote:FireClient(player, payload)
		end
		payload.ok = true
		return payload
	end

	local targets = MeleeService.findTargets(player, item.range, item.arc, aim)
	local hits = 0
	local root = characterRoot(player)
	local origin = root and root.Position or Vector3.zero
	local forward = Vector3.zero
	if root then
		origin, forward = aimOf(root, aim)
	end
	local propHits = 0
	if root and forward.Magnitude > 0.01 then
		propHits = hitDestructibleProps(player, origin, forward, item.range, item.arc)
	end
	for _, enemy in ipairs(targets) do
		-- Удар засчитывается игроку: от этого зависят опыт, золото, стаки душ.
		local _, status = EnemyService.applyDamage(enemy, damage, player, { counter = counter, crit = isCrit })
		DebugState.bump("Melee", "Status_" .. tostring(status))
		if status == "applied" then
			hits += 1
			-- Молоты: финал серии пошатывает (короткий толчок, замах не сбивает).
			if combo == Combat.Attack.comboLength and (item.stagger or 0) > 0 and forward.Magnitude > 0.01 then
				EnemyService.shove(enemy, forward, 1.2, item.stagger)
			end
			WeaponAbilities.onMeleeHit(player, weapon, enemy, combo, strikeBase)
		end
	end

	local breakableHits = 0
	if root and forward.Magnitude > 0.01 then
		for _, hook in ipairs(MeleeService.swingHooks) do
			local ok, hits = pcall(hook, player, origin, forward, item.range or Combat.Attack.range, item.arc or Combat.Attack.arcDegrees, damage, combo)
			if not ok then
				warn("[MeleeService] swingHook: " .. tostring(hits))
			else
				breakableHits += type(hits) == "number" and hits or 0
			end
		end
	end

	if #targets == 0 and propHits == 0 and breakableHits == 0 then
		DebugState.bump("Melee", "NoTargets")
	end
	CombatService.recordAttackDamage(player, damage)

	DebugState.set("Melee", "LastCombo", combo)
	DebugState.set("Melee", "LastDamage", damage)
	DebugState.set("Melee", "LastHits", hits)
	DebugState.set("Melee", "LastProps", propHits)
	DebugState.set("Melee", "LastCounter", counter)

	local payload = {
		combo = combo,
		damage = damage,
		hits = hits,
		counter = counter,
		crit = isCrit,
		props = propHits,
		cooldown = cooldown,
		pause = actual,
		weapon = weapon.typeId,
		weaponId = weapon.id,
	}
	local remote = Net.get("AttackPerformed")
	if remote then
		remote:FireClient(player, payload)
	end

	payload.ok = true
	return payload
end

function MeleeService.requestParry(player)
	local response = CombatService.requestParry(player)
	local remote = Net.get("ParryResult")
	if remote and response.ok then
		remote:FireClient(player, response)
	end
	return response
end

function MeleeService.start()
	Net.ensureAll()

	local attackRemote = Net.get("RequestAttack")
	attackRemote.OnServerInvoke = function(player, aim)
		if not RemoteGuard.allow(player, "RequestAttack", aim) then return RemoteGuard.BUSY end
		return MeleeService.requestAttack(player, aim)
	end

	local parryRemote = Net.get("RequestParry")
	parryRemote.OnServerInvoke = function(player)
		if not RemoteGuard.allow(player, "RequestParry") then return RemoteGuard.BUSY end
		return MeleeService.requestParry(player)
	end

	print("[MeleeService] запущен")
end

return MeleeService
