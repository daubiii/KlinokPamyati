--!nonstrict
-- AbilityService (сервер)
-- Способность оружия (клавиша 1), активные души босса (клавиша 2) и
-- пассивная душа «Ржавая стойка».
--
-- Способность оружия есть у эпического и выше (поле ability в профиле).
-- Души: «Ржавая стойка» — пассив (+15 брони на 5 с после парирования),
-- «Барьер ворот» — щит на 4 с, «Приговор стража» — удар по линии.
-- Урон по врагам наносится от имени игрока: опыт и золото начисляются.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RemoteGuard = require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("RemoteGuard"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loot = require(Shared.Config.Loot)
local Net = require(Shared.Net.Net)
local DebugState = require(Shared.Net.DebugState)

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)
local EnemyService = require(script.Parent.EnemyService)
local WeaponAbilities = require(script.Parent.WeaponAbilities)
local TalentMods = require(script.Parent.TalentMods)

local AbilityService = {}

-- Хуки классов: slot3 — классовое умение (у мага «Покров», MageService.start).
AbilityService.hooks = {}

-- Параметры активных душ взяты из описаний в Loot.BossSouls (приложение Е).
local BARRIER = { duration = 4, absorb = 200, cooldown = 18 }
local VERDICT = { damage = 3.0, stun = 1.5, cooldown = 22, length = 14, halfWidth = 2.5 }

local cooldowns = {} -- [player] = { [abilityId] = readyAt }
local shields = {} -- [player] = { left, untilT }

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function hasSoul(player, soulId: string): boolean
	for _, soul in ipairs(DataService.get(player).souls or {}) do
		if soul.id == soulId then
			return true
		end
	end
	return false
end

local function cooldownLeft(player, id: string): number
	local list = cooldowns[player]
	return math.max(((list and list[id]) or 0) - now(), 0)
end

local function startCooldown(player, id: string, duration: number)
	cooldowns[player] = cooldowns[player] or {}
	cooldowns[player][id] = now() + duration
	player:SetAttribute("Cd_" .. id, cooldowns[player][id])
	player:SetAttribute("CdLen_" .. id, duration)
end

-- Для классовых умений (MageService: «Покров»).
AbilityService.cooldownLeft = cooldownLeft
AbilityService.startCooldown = startCooldown

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return root
end

local function announce(player, payload)
	local remote = Net.get("AbilityUsed")
	if remote then
		remote:FireClient(player, payload)
	end
end

local function onParrySuccess(player)
	if not hasSoul(player, "rusty_stance") then
		return
	end
	local soul = Loot.BossSouls.common
	CombatService.addTemporaryArmor(player, soul.armorBonus, soul.duration)
	DebugState.set("Ability", "PassiveTriggered", true)
	announce(player, { kind = "passive", id = "rusty_stance", name = soul.name, duration = soul.duration })
end

-- Щит поглощает урон до исчерпания лимита или конца времени.
local function absorb(player, damage: number): number
	local shield = shields[player]
	if not shield then
		return damage
	end
	if now() >= shield.untilT or shield.left <= 0 then
		shields[player] = nil
		player:SetAttribute("ShieldUntil", 0)
		return damage
	end
	local soaked = math.min(shield.left, damage)
	shield.left -= soaked
	if shield.left <= 0 then
		shields[player] = nil
		player:SetAttribute("ShieldUntil", 0)
		announce(player, { kind = "shieldBroken" })
	end
	return damage - soaked
end

-- ===== Способность оружия =====

-- Способности оружия живут в WeaponAbilities (Вихрь-воронка, Разлом,
-- Отпереть). Здесь — проверки, перезарядка и ответ клиенту.
local function weaponAbility(player)
	local profile = DataService.get(player)
	local weapon = profile.equippedWeapon
	local ability = Loot.abilityOf(weapon)
	if not ability then
		return { ok = false, reason = "no-ability" }
	end
	local left = cooldownLeft(player, ability.id)
	if left > 0 then
		return { ok = false, reason = "cooldown", remaining = left }
	end
	if not rootOf(player) then
		return { ok = false, reason = "no-character" }
	end

	local result = WeaponAbilities.cast(player, weapon, ability)
	if not result.ok then
		return result
	end

	-- «Мастер оружия» (−20%) / «Быстрое чтение» (−15%).
	local cooldown = WeaponAbilities.cooldown(weapon, ability) * TalentMods.cooldownScale(player)
	startCooldown(player, ability.id, cooldown)

	local root = rootOf(player)
	announce(player, {
		kind = "weapon",
		id = ability.id,
		name = ability.name,
		radius = result.radius or ability.radius,
		position = root and root.Position,
		hits = result.hits or 0,
		cooldown = cooldown,
		legacy = result.legacy,
	})

	return {
		ok = true,
		ability = ability.id,
		name = ability.name,
		cooldown = cooldown,
		castTime = (ability.castTime or 0.5) * TalentMods.castTimeScale(player),
		hits = result.hits,
		-- рывок способности («Последний гон»): клиент двигает героя сам (AbilityController.applyMove);
		-- поле терялось, и рывок не двигал героя
		move = result.move,
	}
end

-- ===== Активная душа =====

local function soulAbility(player)
	local root = rootOf(player)
	if not root then
		return { ok = false, reason = "no-character" }
	end

	if hasSoul(player, "guard_verdict") then
		local left = cooldownLeft(player, "guard_verdict")
		if left > 0 then
			return { ok = false, reason = "cooldown", remaining = left }
		end
		local stats = CombatService.getStats(player)
		local damage = stats.weaponDamage * VERDICT.damage
		local look = root.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z).Unit
		local origin = Vector3.new(root.Position.X, 0, root.Position.Z)
		local hits = 0
		for _, enemy in ipairs(EnemyService.all()) do
			if enemy.alive then
				local rel = Vector3.new(enemy.position.X - origin.X, 0, enemy.position.Z - origin.Z)
				local along = rel:Dot(forward)
				local side = (rel - forward * along).Magnitude
				if along > -enemy.stats.radius and along < VERDICT.length + enemy.stats.radius and side <= VERDICT.halfWidth + enemy.stats.radius then
					EnemyService.applyDamage(enemy, damage, player, { ability = "guard_verdict" })
					EnemyService.stun(enemy, VERDICT.stun)
					hits += 1
				end
			end
		end
		startCooldown(player, "guard_verdict", VERDICT.cooldown)
		announce(player, {
			kind = "verdict",
			id = "guard_verdict",
			name = Loot.BossSouls.legendary.name,
			position = root.Position,
			direction = forward,
			length = VERDICT.length,
			cooldown = VERDICT.cooldown,
			hits = hits,
		})
		return { ok = true, ability = "guard_verdict", hits = hits, cooldown = VERDICT.cooldown }
	end

	if hasSoul(player, "gate_barrier") then
		local left = cooldownLeft(player, "gate_barrier")
		if left > 0 then
			return { ok = false, reason = "cooldown", remaining = left }
		end
		shields[player] = { left = BARRIER.absorb, untilT = now() + BARRIER.duration }
		player:SetAttribute("ShieldUntil", now() + BARRIER.duration)
		startCooldown(player, "gate_barrier", BARRIER.cooldown)
		announce(player, {
			kind = "barrier",
			id = "gate_barrier",
			name = Loot.BossSouls.epic.name,
			duration = BARRIER.duration,
			cooldown = BARRIER.cooldown,
		})
		return { ok = true, ability = "gate_barrier", cooldown = BARRIER.cooldown }
	end

	return { ok = false, reason = "no-ability" }
end

function AbilityService.use(player, slot)
	-- Время остановлено (выбор «Дара Эха»).
	if player:GetAttribute("BoonPause") then
		return { ok = false, reason = "paused" }
	end
	if slot == 2 then
		return soulAbility(player)
	end
	if slot == 3 then
		local classHook = AbilityService.hooks.slot3
		if classHook then
			return classHook(player)
		end
		return { ok = false, reason = "no-ability" }
	end
	return weaponAbility(player)
end

-- Какие души у игрока: клиент показывает их в HUD по атрибутам.
local function publishSouls(player)
	local active = ""
	if hasSoul(player, "guard_verdict") then
		active = "guard_verdict"
	elseif hasSoul(player, "gate_barrier") then
		active = "gate_barrier"
	end
	player:SetAttribute("SoulActive", active)
	player:SetAttribute("SoulPassive", hasSoul(player, "rusty_stance") and "rusty_stance" or "")
end

-- Сократить идущую перезарядку на seconds. Нужна пассивкам оружия этажей 3–5
-- («Песок времени» сокращает «Безвременье», «Метка добычи» возвращает часть
-- «Последнего гона»). Блок пришёл из пакета оружия 3–5 и терялся при
-- наложении более поздних пакетов — вызовы были, функции не было.
function AbilityService.reduceCooldown(player, id: string, seconds: number)
	local list = cooldowns[player]
	local readyAt = list and list[id]
	if not readyAt or seconds <= 0 then
		return
	end
	local t = now()
	if readyAt <= t then
		return
	end
	list[id] = math.max(t, readyAt - seconds)
	player:SetAttribute("Cd_" .. id, list[id])
end

function AbilityService.reset(player)
	cooldowns[player] = nil
	shields[player] = nil
	player:SetAttribute("ShieldUntil", 0)
	player:SetAttribute("CastingUntil", 0)
end

-- Только перезарядки (отладка): идущий каст и щит не трогаем.
function AbilityService.resetCooldowns(player)
	local list = cooldowns[player]
	cooldowns[player] = nil
	for id in pairs(list or {}) do
		player:SetAttribute("Cd_" .. id, 0)
	end
end

function AbilityService.start()
	Net.ensureAll()

	CombatService.hooks.parrySuccess = onParrySuccess
	CombatService.hooks.absorb = absorb

	Net.get("RequestAbility").OnServerInvoke = function(player, slot)
		if not RemoteGuard.allow(player, "RequestAbility", slot) then return RemoteGuard.BUSY end
		return AbilityService.use(player, typeof(slot) == "number" and slot or 1)
	end

	local Players = game:GetService("Players")
	local function hook(player)
		task.spawn(function()
			local waited = 0
			while not player:GetAttribute("ProfileVersion") and waited < 60 and player.Parent do
				waited += task.wait(0.1)
			end
			publishSouls(player)
		end)
		player:GetAttributeChangedSignal("LastSoul"):Connect(function()
			publishSouls(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
		shields[player] = nil
	end)

	print("[AbilityService] запущен")
end

return AbilityService
