--!nonstrict
-- CombatService (сервер)
-- Владеет боевым состоянием игрока: класс, статы, рывок, неуязвимость,
-- входящий урон. Клиент только просит; решение всегда за сервером (§12).
--
-- Этап 2 реализует: применение статов класса, рывок с неуязвимостью 0.3 с,
-- перезарядку 0.8 с, проверку дистанции рывка и учёт входящего урона
-- с учётом неуязвимости и брони. Парирование — этап 3.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RemoteGuard = require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("RemoteGuard"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Classes = require(Shared.Config.Classes)
local Net = require(Shared.Net.Net)
local DebugState = require(Shared.Net.DebugState)
-- Древо талантов: лист зависимостей (DataService + Config), циклов нет.
local TalentMods = require(script.Parent.TalentMods)
local FloorBoonState = require(script.Parent.FloorBoonState)
local StatsService = require(script.Parent.StatsService)

local CombatService = {}

local states = {}

local ATTACK_GRACE = 0.12 -- допуск паузы между ударами на сетевой разброс, с

-- Хуки для других систем: боевая логика не знает про души и способности.
CombatService.hooks = {
	parrySuccess = nil,
	-- dodge(player) — рывок принят сервером (TutorialService: станция обучения).
	dodge = nil,
	-- absorb(player, damage) -> сколько урона осталось после щита души.
	absorb = nil,
	-- gearStats(player) -> { armor, health }: плоские бонусы брони (ArmorService).
	gearStats = nil,
	-- gearReduction(player, humanoid) -> доля снижения урона 0..0.5 (ArmorService).
	gearReduction = nil,
	-- classApplied(player, refill) — после applyClass (ManaService пересчитывает ману).
	classApplied = nil,
	-- damageBonus(player) -> доля к урону ближнего боя (аксессуары и бафы, InventoryService).
	damageBonus = nil,
	-- parryGate(player) -> ok, reason: можно ли открыть окно (барьер мага стоит маны, MageService).
	parryGate = nil,
}
local started = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Сообщить клиенту об исходе столкновения (эффекты, звук, интерфейс).
local function feedback(player, payload)
	local remote = Net.get("CombatFeedback")
	if remote then
		remote:FireClient(player, payload)
	end
end

local function characterOf(player)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	return character, character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
end

local function newState()
	return {
		className = Classes.default(),
		level = 1,
		dodgeCount = 0,
		acceptedDodges = 0,
		rejectedDodges = 0,
		lastDodgeAt = 0,
		invulnerableUntil = 0,
		cooldownUntil = 0,
		dodgeOrigin = nil,
		lastDodgeDistance = 0,
		suspiciousDistances = 0,
		damageTaken = 0,
		blockedDamage = 0,
		healsUsed = 0,
		armorBonus = 0,
		armorBonusUntil = 0,

		-- Парирование и комбо (этап 3).
		parryUntil = 0,
		parryRecoverUntil = 0,
		parrySuccesses = 0,
		parryFailures = 0,
		abilityCharge = 0,
		counterCharged = false,
		combo = 0,
		lastAttackAt = 0,
		attackCooldownUntil = 0,
		attackCount = 0,
		lastAttackDamage = 0,
		lastIncoming = "none",
	}
end

function CombatService.getState(player)
	local state = states[player]
	if not state then
		state = newState()
		states[player] = state
	end
	return state
end

-- Публикует состояние в атрибуты игрока: это и отладочный канал, и будущая
-- основа для интерфейса (клиенту не нужно отдельно спрашивать сервер).
function CombatService.publish(player)
	local state = CombatService.getState(player)
	player:SetAttribute("ClassName", state.className)
	player:SetAttribute("Level", state.level)
	player:SetAttribute("DodgeCount", state.dodgeCount)
	player:SetAttribute("AcceptedDodges", state.acceptedDodges)
	player:SetAttribute("RejectedDodges", state.rejectedDodges)
	player:SetAttribute("LastDodgeAt", state.lastDodgeAt)
	player:SetAttribute("InvulnerableUntil", state.invulnerableUntil)
	player:SetAttribute("CooldownUntil", state.cooldownUntil)
	player:SetAttribute("LastDodgeDistance", state.lastDodgeDistance)
	player:SetAttribute("DamageTaken", state.damageTaken)
	player:SetAttribute("BlockedDamage", state.blockedDamage)

	-- Этап 3.
	player:SetAttribute("Combo", state.combo)
	player:SetAttribute("AttackCount", state.attackCount)
	player:SetAttribute("LastAttackDamage", state.lastAttackDamage)
	player:SetAttribute("ParryActive", now() < state.parryUntil)
	player:SetAttribute("ParrySuccesses", state.parrySuccesses)
	player:SetAttribute("ParryFailures", state.parryFailures)
	player:SetAttribute("Recovering", now() < state.parryRecoverUntil)
	player:SetAttribute("CounterCharged", state.counterCharged)
	player:SetAttribute("AbilityCharge", state.abilityCharge)
	player:SetAttribute("LastIncoming", state.lastIncoming)
	player:SetAttribute("HealsUsed", state.healsUsed)
end

function CombatService.getStats(player)
	local state = CombatService.getState(player)
	local stats = Classes.statsAtLevel(state.className, state.level)
	stats.classArmor = stats.armor
	stats.gearArmor = 0
	stats.gearHealth = 0
	-- Надетая броня (шлем и доспех): плоская броня и здоровье.
	if CombatService.hooks.gearStats then
		local ok, gear = pcall(CombatService.hooks.gearStats, player)
		if ok and type(gear) == "table" then
			stats.gearArmor = gear.armor or 0
			stats.gearHealth = gear.health or 0
			stats.armor += stats.gearArmor
			stats.maxHealth += stats.gearHealth
		end
	end
	-- Временная броня от пассивной души («Ржавая стойка»).
	if state.armorBonusUntil and now() < state.armorBonusUntil then
		stats.armor = stats.armor + (state.armorBonus or 0)
	end
	-- Древо талантов: здоровье, броня (и от стаков, и после парирования),
	-- урон оружия, скорость атаки, окно парирования, бафы скорости бега.
	TalentMods.applyStats(player, stats)
	-- «Дары Эха»: здоровье, броня, скорость атаки и бега, урон оружия — до конца этажа.
	FloorBoonState.applyStats(player, stats)
	return stats
end

-- Временный бонус брони (пассивная душа после парирования).
function CombatService.addTemporaryArmor(player, amount: number, duration: number)
	local state = CombatService.getState(player)
	state.armorBonus = amount
	state.armorBonusUntil = now() + duration
	player:SetAttribute("ArmorBonus", amount)
	player:SetAttribute("ArmorBonusUntil", state.armorBonusUntil)
end

-- Применить класс и его статы к персонажу. Вызывается при спавне.
-- refill = true — вернуть здоровье на максимум (спавн, повышение уровня).
-- Без refill здоровье сохраняет долю, иначе каждое убийство лечило бы игрока.
function CombatService.applyClass(player, className: string?, level: number?, refill: boolean?)
	local state = CombatService.getState(player)
	if className and Classes.get(className) then
		state.className = className
	end
	if level then
		state.level = math.clamp(level, 1, Classes.MaxLevel)
	end
	CombatService.publish(player)
	if CombatService.hooks.classApplied then
		pcall(CombatService.hooks.classApplied, player, refill)
	end

	local _, humanoid = characterOf(player)
	if not humanoid then
		return
	end

	local stats = CombatService.getStats(player)
	local ratio = 1
	if refill ~= true and humanoid.MaxHealth > 0 then
		ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
	end
	humanoid.MaxHealth = stats.maxHealth
	humanoid.Health = stats.maxHealth * ratio
	humanoid.WalkSpeed = stats.walkSpeed

	-- Заряды лечения НЕ пополняются здесь: applyClass вызывается и при
	-- каждом стаке душ (убийство), и тогда пустые заряды восполнялись бы
	-- посреди боя. Выдача — CombatService.refillHeals (вход на этаж, костёр).
	if player:GetAttribute("HealCharges") == nil then
		player:SetAttribute("HealCharges", Combat.Heal.charges)
	end

	-- Прыжок на пробеле; рывок — Q / Shift.
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 6
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
end

-- Полные заряды лечения: начало забега и костёр.
function CombatService.refillHeals(player)
	player:SetAttribute("HealCharges", Combat.Heal.charges)
end

function CombatService.isInvulnerable(player): boolean
	local state = states[player]
	if not state then
		return false
	end
	return now() < state.invulnerableUntil
end

local function flatUnit(direction)
	if typeof(direction) ~= "Vector3" then
		return nil
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.001 then
		return nil
	end
	return flat.Unit
end

-- Запрос на рывок. Возвращает (ok, ответ).
-- Сервер сам решает, разрешён ли рывок, и открывает окно неуязвимости.
function CombatService.requestDodge(player, direction)
	local state = CombatService.getState(player)
	local timestamp = now()

	local character, humanoid, root = characterOf(player)
	if not character or not humanoid or not root then
		return false, { ok = false, reason = "no-character" }
	end
	if humanoid.Health <= 0 then
		return false, { ok = false, reason = "dead" }
	end
	if player:GetAttribute("BoonPause") then
		return false, { ok = false, reason = "paused" }
	end
	if timestamp < state.cooldownUntil then
		state.rejectedDodges += 1
		CombatService.publish(player)
		return false, {
			ok = false,
			reason = "cooldown",
			remaining = state.cooldownUntil - timestamp,
		}
	end

	local unit = flatUnit(direction)
	if not unit then
		return false, { ok = false, reason = "bad-direction" }
	end

	-- Принято.
	state.dodgeCount += 1
	state.acceptedDodges += 1
	state.lastDodgeAt = timestamp
	state.invulnerableUntil = timestamp + Combat.Dodge.iFrames
	state.cooldownUntil = timestamp + Combat.Dodge.cooldown
	state.dodgeOrigin = root.Position
	-- Рывок принят сервером (обучение ловит его через hooks.dodge).
	if CombatService.hooks.dodge then
		pcall(CombatService.hooks.dodge, player)
	end
	CombatService.publish(player)

	local dodgeId = state.dodgeCount

	-- Проверка «не телепорт»: через длительность рывка персонаж должен
	-- оказаться не дальше maxDistance × distanceTolerance.
	task.delay(Combat.Dodge.dashDuration + 0.2, function()
		if not player.Parent then
			return
		end
		local _, _, currentRoot = characterOf(player)
		if not currentRoot or not state.dodgeOrigin then
			return
		end
		local distance = (currentRoot.Position - state.dodgeOrigin).Magnitude
		state.lastDodgeDistance = distance
		if distance > Combat.Dodge.maxDistance * Combat.Dodge.distanceTolerance then
			state.suspiciousDistances += 1
			warn(("CombatService: рывок #%d игрока %s прошёл %.1f стадов (потолок %.1f)"):format(
				dodgeId,
				player.Name,
				distance,
				Combat.Dodge.maxDistance
			))
		end
		CombatService.publish(player)
		DebugState.set("Server", "LastDodgeDistance", distance)
	end)

	local remote = Net.get("DodgePerformed")
	if remote then
		remote:FireClient(player, {
			dodgeId = dodgeId,
			serverTime = timestamp,
			direction = unit,
		})
	end

	return true, {
		ok = true,
		serverTime = timestamp,
		speed = Combat.Dodge.dashSpeed,
		duration = Combat.Dodge.dashDuration,
		iFrames = Combat.Dodge.iFrames,
		cooldown = Combat.Dodge.cooldown,
		direction = unit,
		dodgeId = dodgeId,
	}
end

-- ===== Лечение (этап 5.5) =====
-- 3 заряда за забег, каждый лечит 35% максимального здоровья
-- (приложение Б). Заряды пополняются в комнате отдыха и из сундуков.

function CombatService.requestHeal(player)
	local state = CombatService.getState(player)
	local _, humanoid = characterOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return { ok = false, reason = "dead" }
	end

	if player:GetAttribute("BoonPause") then
		return { ok = false, reason = "paused" }
	end
	local charges = player:GetAttribute("HealCharges") or 0
	if charges <= 0 then
		return { ok = false, reason = "no-charges", charges = 0 }
	end
	if humanoid.Health >= humanoid.MaxHealth then
		return { ok = false, reason = "full", charges = charges }
	end

	-- «Выносливость» / «Целебный отвар»: 40% вместо 35%.
	local amount = humanoid.MaxHealth * TalentMods.healPct(player, Combat.Heal.percentOfMaxHealth)
	humanoid.Health = math.min(humanoid.Health + amount, humanoid.MaxHealth)
	player:SetAttribute("HealCharges", charges - 1)
	state.healsUsed += 1
	CombatService.publish(player)

	local remote = Net.get("CombatStateChanged")
	if remote then
		remote:FireClient(player, { healed = amount, charges = charges - 1 })
	end
	feedback(player, { kind = "heal", amount = amount })

	return { ok = true, healed = amount, charges = charges - 1, maxHealth = humanoid.MaxHealth }
end

-- Начать удар комбо. Возвращает номер удара в комбо или nil + причину.
-- finisherCooldown — пауза после последнего удара серии (если задана).
-- Возвращает номер удара и фактическую паузу до следующего.
function CombatService.beginAttack(player, cooldown: number, comboLength: number, comboWindow: number, finisherCooldown: number?)
	local state = CombatService.getState(player)
	local timestamp = now()

	local _, humanoid = characterOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return nil, "dead"
	end
	if timestamp < state.parryRecoverUntil then
		return nil, "recovering"
	end
	-- Допуск на сетевой разброс: пауза считается по приходу запроса, и если
	-- прошлый запрос задержался в сети, следующий выглядит «ранним». Без
	-- допуска удар проигрывался у игрока, а урона не было.
	if timestamp < state.attackCooldownUntil - ATTACK_GRACE then
		return nil, "cooldown"
	end

	if timestamp - state.lastAttackAt <= comboWindow then
		state.combo = (state.combo % comboLength) + 1
	else
		state.combo = 1
	end

	if state.combo == comboLength and finisherCooldown then
		cooldown = finisherCooldown
	end
	state.lastAttackAt = timestamp
	state.attackCooldownUntil = timestamp + cooldown
	state.attackCount += 1
	CombatService.publish(player)

	return state.combo, nil, cooldown
end

function CombatService.recordAttackDamage(player, damage: number)
	local state = CombatService.getState(player)
	state.lastAttackDamage = damage
	CombatService.publish(player)
end

-- ===== Парирование (этап 3) =====

function CombatService.isParryActive(player): boolean
	local state = states[player]
	if not state then
		return false
	end
	return now() < state.parryUntil
end

function CombatService.isRecovering(player): boolean
	local state = states[player]
	if not state then
		return false
	end
	return now() < state.parryRecoverUntil
end

-- Запрос на парирование. Открывает окно класса; если в окно не пришёл
-- парируемый удар, включается штрафная пауза (раздел 3: около 1 с).
function CombatService.requestParry(player)
	local state = CombatService.getState(player)
	local timestamp = now()

	local _, humanoid = characterOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return { ok = false, reason = "dead" }
	end
	if timestamp < state.parryRecoverUntil then
		return { ok = false, reason = "recovering", remaining = state.parryRecoverUntil - timestamp }
	end
	if timestamp < state.parryUntil then
		return { ok = false, reason = "already-parrying", remaining = state.parryUntil - timestamp }
	end
	if CombatService.hooks.parryGate then
		local okGate, allowed, gateReason = pcall(CombatService.hooks.parryGate, player)
		if okGate and allowed == false then
			return { ok = false, reason = gateReason or "blocked" }
		end
	end

	local stats = CombatService.getStats(player)
	local window = stats.parryWindow or Combat.Parry.failPause
	-- «Быстрый щит»: пауза после промаха 0,8 с вместо 1,0.
	local failPause = TalentMods.failPause(player, Combat.Parry.failPause)

	state.parryUntil = timestamp + window
	CombatService.publish(player)

	-- Если окно закрылось без успеха — штраф.
	task.delay(window + 0.02, function()
		if not player.Parent then
			return
		end
		if state.parryUntil ~= 0 and now() >= state.parryUntil then
			state.parryUntil = 0
			state.parryFailures += 1
			state.parryRecoverUntil = now() + failPause
			CombatService.publish(player)
			DebugState.set("Server", "ParryResult", "failed")
			feedback(player, { kind = "parryFail", pause = failPause })
		end
	end)

	return {
		ok = true,
		window = window,
		serverTime = timestamp,
		failPause = failPause,
	}
end

-- Забрать заряженную контратаку (после успешного парирования следующий удар ×2).
function CombatService.consumeCounter(player): boolean
	local state = CombatService.getState(player)
	if not state.counterCharged then
		return false
	end
	state.counterCharged = false
	CombatService.publish(player)
	return true
end

-- Разрешить входящую атаку врага: парирование, уклонение или попадание.
-- Порядок важен: парируемый удар в окне парирования не наносит урона вовсе.
function CombatService.resolveIncomingAttack(player, attack)
	local state = CombatService.getState(player)
	local timestamp = now()

	local parryable = attack.parryable ~= false

	if parryable and timestamp < state.parryUntil then
		state.parryUntil = 0
		state.parrySuccesses += 1
		StatsService.addParry(player) -- пожизненный счётчик достижений
		state.counterCharged = true
		state.abilityCharge = math.min(state.abilityCharge + 1, 10)
		state.lastIncoming = "parried"
		if CombatService.hooks.parrySuccess then
			pcall(CombatService.hooks.parrySuccess, player)
		end
		-- Древо: «Опора», «Железная воля», «Эхо щита» (слушатели TalentService).
		TalentMods.onParry(player, attack)
		CombatService.publish(player)
		DebugState.set("Server", "ParryResult", "success")
		feedback(player, { kind = "parry", position = attack.position })
		return "parried", 0
	end

	if timestamp < state.invulnerableUntil then
		state.lastIncoming = "dodged"
		CombatService.publish(player)
		feedback(player, { kind = "dodge", position = attack.position })
		return "dodged", 0
	end

	local taken, reason = CombatService.damagePlayer(player, attack.damage or 0, {
		source = attack.source,
		armorPierce = attack.armorPierce,
		position = attack.position,
	})
	state.lastIncoming = reason == "applied" and "hit" or reason
	CombatService.publish(player)
	return state.lastIncoming, taken
end

-- Входящий урон. Учитывает неуязвимость и броню класса.
-- Возвращает (сколько реально снято, причина).
function CombatService.damagePlayer(player, rawDamage: number, options)
	local state = CombatService.getState(player)
	local opts = options or {}

	-- Бессмертие из отладочных команд (DebugCommands, только Studio).
	if player:GetAttribute("DebugGod") then
		return 0, "invulnerable"
	end

	if state.invulnerableUntil > now() or player:GetAttribute("BoonPause") then
		state.blockedDamage += 1
		CombatService.publish(player)
		return 0, "invulnerable"
	end

	local _, humanoid = characterOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return 0, "dead"
	end

	-- «Тень» (дар этажа): шанс уклониться от удара целиком.
	local evasion = FloorBoonState.evasion(player)
	if evasion > 0 and not opts.unavoidable and math.random() < evasion then
		feedback(player, { kind = "evade", position = opts.position })
		return 0, "evaded"
	end

	local stats = CombatService.getStats(player)
	local armor = math.max(stats.armor - (opts.armorPierce or 0), 0)
	local taken = Combat.Armor.mitigate(rawDamage, armor)
	-- Снижение урона от редкости и ★ брони и бонус комплекта.
	local reduction = 0
	if CombatService.hooks.gearReduction then
		local ok, value = pcall(CombatService.hooks.gearReduction, player, humanoid)
		if ok and type(value) == "number" then
			reduction = math.clamp(value, 0, 0.5)
		end
	end
	taken *= 1 - reduction
	if CombatService.hooks.absorb then
		local ok, left = pcall(CombatService.hooks.absorb, player, taken)
		if ok and type(left) == "number" then
			taken = left
		end
	end
	-- Щит «Плаща забвения» (древо мага).
	taken = TalentMods.absorb(player, taken)

	-- «Несгибаемый»: раз за забег смертельный удар оставляет 1 здоровья.
	if taken > 0 and taken >= humanoid.Health then
		local saved, invuln = TalentMods.tryCheatDeath(player)
		if saved then
			taken = math.max(humanoid.Health - 1, 0)
			state.invulnerableUntil = math.max(state.invulnerableUntil, now() + invuln)
			feedback(player, { kind = "talent", id = "w_unbending", position = opts.position })
			local notify = Net.get("Notify")
			if notify then
				notify:FireClient(player, { kind = "talent", text = "Несгибаемый: удар выдержан" })
			end
		end
	end

	humanoid:TakeDamage(taken)
	-- «Ответный удар»: следующая атака сильнее.
	TalentMods.onDamaged(player, taken)
	state.damageTaken += taken
	CombatService.publish(player)
	DebugState.set("Server", "LastDamageTaken", taken)

	local remote = Net.get("DamageApplied")
	if remote then
		remote:FireClient(player, {
			amount = taken,
			raw = rawDamage,
			armor = armor,
			reduction = reduction,
			source = opts.source,
			position = opts.position,
		})
	end
	-- heavy — удар снял больше 15% здоровья: клиент играет тяжёлую реакцию.
	feedback(player, {
		kind = "hit",
		amount = taken,
		position = opts.position,
		heavy = humanoid.MaxHealth > 0 and taken / humanoid.MaxHealth > 0.15,
		armored = reduction > 0 or armor >= 15,
	})

	return taken, "applied"
end

function CombatService.reset(player)
	if player then
		states[player] = newState()
		CombatService.publish(player)
		return
	end
	for existing in pairs(states) do
		states[existing] = nil
	end
end

local function configurePlayer(player)
	-- Штатный shift lock выключен: камерой управляет CameraController, а
	-- MouseLockController из PlayerModule (в настоящем клиенте он есть) перехватывал
	-- бы Shift — это наша клавиша рывка — и рисовал свою кнопку фиксации.
	player.DevEnableMouseLock = false
	player.CameraMinZoomDistance = 6
	player.CameraMaxZoomDistance = 16

	CombatService.getState(player)
	CombatService.publish(player)

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		-- Новый персонаж: свежее боевое состояние (рывок, парирование, комбо).
		local state = CombatService.getState(player)
		state.invulnerableUntil = 0
		state.cooldownUntil = 0
		state.parryUntil = 0
		state.parryRecoverUntil = 0
		state.attackCooldownUntil = 0
		state.combo = 0
		state.counterCharged = false
		CombatService.applyClass(player, nil, nil, true)
	end)

	if player.Character then
		task.spawn(function()
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid") or player.Character:WaitForChild("Humanoid")
			if humanoid then
				CombatService.applyClass(player, nil, nil, true)
			end
		end)
	end
end

function CombatService.start()
	if started then
		return
	end
	started = true

	Net.ensureAll()

	local requestDodge = Net.get("RequestDodge")
	requestDodge.OnServerInvoke = function(player, direction)
		if not RemoteGuard.allow(player, "RequestDodge", direction) then return RemoteGuard.BUSY end
		-- RemoteFunction передаёт клиенту только первое возвращаемое значение,
		-- поэтому возвращаем один ответ: в нём уже есть поле ok.
		local _, response = CombatService.requestDodge(player, direction)
		return response
	end

	local requestHeal = Net.get("RequestHeal")
	requestHeal.OnServerInvoke = function(player)
		if not RemoteGuard.allow(player, "RequestHeal") then return RemoteGuard.BUSY end
		return CombatService.requestHeal(player)
	end

	Players.PlayerAdded:Connect(configurePlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		configurePlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	print("[CombatService] запущен")
end

return CombatService
