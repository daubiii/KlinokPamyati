--!nonstrict
-- TalentMods (сервер)
-- Модификаторы древа талантов для боевых систем. Лист зависимостей: только
-- DataService и Config.Talents — поэтому его можно звать откуда угодно
-- (CombatService, MeleeService, EnemyService, MageService…) без циклов.
--
-- Здесь же короткоживущее состояние узлов (бафы на секунды, «раз за забег»,
-- щит «Плаща забвения», счётчик «Эха заклинаний»). Слушатели событий, которым
-- нужны враги и мана (парирование, убийство), живут в TalentService.
--
-- Хранение в профиле: profile.talents[класс] = { nodes = { [id] = true }, resets = N, version = V }.
-- Узлы другой версии древа (Talents.Version) при первом обращении возвращаются
-- бесплатно: раскладка путей изменилась, старый набор мог бы нарушать порядок.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Talents = require(Shared.Config.Talents)
local Echo = require(Shared.Config.Echo)

local DataService = require(script.Parent.DataService)

local TalentMods = {}

-- Ставит TalentService: обновить скорость бега после бафа (нужен CombatService).
TalentMods.hooks = { refreshSpeed = nil }
-- Слушатели удачного парирования: fn(player, attack) — ставит TalentService.
TalentMods.parryListeners = {}

local cache = {} -- [player] = { classId, mods }
local runtime = {} -- [player] = состояние бафов

local EMPTY = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function isPlayer(value): boolean
	return typeof(value) == "Instance" and value:IsA("Player")
end
TalentMods.isPlayer = isPlayer

local function profileOf(player)
	if not isPlayer(player) then
		return nil
	end
	local ok, profile = pcall(DataService.get, player)
	return ok and profile or nil
end

-- Запись класса в профиле (создаётся при первом обращении).
function TalentMods.entry(profile, classId: string?)
	profile.talents = profile.talents or {}
	local id = classId or profile.className or "warrior"
	local entry = profile.talents[id]
	if type(entry) ~= "table" then
		entry = { nodes = {}, resets = 0 }
		profile.talents[id] = entry
	end
	entry.nodes = entry.nodes or {}
	entry.resets = entry.resets or 0
	if entry.version ~= Talents.Version then
		entry.nodes = {}
		entry.version = Talents.Version
	end
	return entry
end

-- Изученные узлы текущего класса игрока.
function TalentMods.learned(player)
	local profile = profileOf(player)
	if not profile then
		return EMPTY, "warrior"
	end
	local classId = profile.className or "warrior"
	local stored = profile.talents and profile.talents[classId]
	if not stored or stored.version ~= Talents.Version then
		return EMPTY, classId
	end
	return stored.nodes or EMPTY, classId
end

-- Сумма эффектов (кэш до invalidate). Неизвестный игрок — пустая таблица.
function TalentMods.get(player)
	if not isPlayer(player) then
		return EMPTY
	end
	local learned, classId = TalentMods.learned(player)
	local cached = cache[player]
	if cached and cached.classId == classId then
		return cached.mods
	end
	local mods = Talents.aggregate(classId, learned)
	cache[player] = { classId = classId, mods = mods }
	return mods
end

function TalentMods.has(player, key: string): boolean
	return (TalentMods.get(player)[key] or 0) ~= 0
end

function TalentMods.invalidate(player)
	cache[player] = nil
end

local function stateOf(player)
	local state = runtime[player]
	if not state then
		state = {
			speed = {}, -- [источник] = { pct, untilT }
			hasteUntil = 0,
			haste = 0,
			armorUntil = 0,
			armor = 0,
			retaliateArmed = false,
			retaliateReadyAt = 0,
			cheatUsed = false,
			shield = nil, -- { left, untilT }
			spells = 0,
			empowered = false, -- «Резкость»: следующий удар посохом усилен
			boltHits = 0, -- «Расщепление»: счётчик попаданий снарядов посоха
		}
		runtime[player] = state
	end
	return state
end
TalentMods.stateOf = stateOf

-- ===== статы героя (CombatService.getStats) =====

function TalentMods.applyStats(player, stats)
	local mods = TalentMods.get(player)
	if mods == EMPTY or next(mods) == nil then
		local state = runtime[player]
		if not state then
			return stats
		end
	end
	local t = now()
	local state = stateOf(player)
	stats.talentHealth = 0
	if mods.maxHealthPct then
		local before = stats.maxHealth
		stats.maxHealth = stats.maxHealth * (1 + mods.maxHealthPct)
		stats.talentHealth = stats.maxHealth - before
	end
	local armor = mods.armor or 0
	if mods.soulArmorPer and mods.soulArmorPer > 0 then
		local profile = profileOf(player)
		local stacks = profile and profile.soulStacks or 0
		armor += math.min(math.floor(stacks / mods.soulArmorPer), mods.soulArmorMax or 10)
	end
	if t < state.armorUntil then
		armor += state.armor
	end
	stats.talentArmor = armor
	stats.armor += armor
	if mods.weaponDamagePct then
		stats.weaponDamage = stats.weaponDamage * (1 + mods.weaponDamagePct)
	end
	local haste = mods.attackSpeed or 0
	if t < state.hasteUntil then
		haste += state.haste
	end
	stats.attackSpeed += haste
	if mods.parryWindow then
		stats.parryWindow = (stats.parryWindow or 0) + mods.parryWindow
	end
	-- Бафы на секунды («Опора», «Покров») + постоянная прибавка малых узлов («Лёгкие ноги»).
	local speed = TalentMods.speedBonus(player, t) + (mods.moveSpeed or 0)
	if speed > 0 then
		stats.walkSpeed = stats.walkSpeed * (1 + speed)
	end
	return stats
end

-- ===== лечение, дебафы, парирование =====

function TalentMods.healPct(player, base: number): number
	return base + (TalentMods.get(player).healPct or 0)
end

-- Множитель длительности дебафов на герое (замедление, яд, корни, горение).
function TalentMods.debuffScale(player): number
	if not isPlayer(player) then
		return 1
	end
	return math.max(0.2, 1 + (TalentMods.get(player).debuffTime or 0))
end

function TalentMods.failPause(player, base: number): number
	return math.max(0.3, base + (TalentMods.get(player).failPause or 0))
end

function TalentMods.parryStunBonus(player): number
	if not isPlayer(player) then
		return 0
	end
	return TalentMods.get(player).parryStun or 0
end

-- Удачное парирование (CombatService.resolveIncomingAttack): бафы и слушатели.
function TalentMods.onParry(player, attack)
	local mods = TalentMods.get(player)
	local t = now()
	if mods.parrySpeed then
		TalentMods.addSpeed(player, "parry", mods.parrySpeed, mods.parrySpeedTime or 3)
	end
	if mods.parryArmor then
		local state = stateOf(player)
		state.armor = mods.parryArmor
		state.armorUntil = t + (mods.parryArmorTime or 4)
		player:SetAttribute("TalentArmorUntil", state.armorUntil)
	end
	for _, listener in ipairs(TalentMods.parryListeners) do
		local ok, err = pcall(listener, player, attack, mods)
		if not ok then
			warn("[TalentMods] parry: " .. tostring(err))
		end
	end
end

-- ===== удары героя (MeleeService) =====

function TalentMods.counterMultiplier(player, base: number): number
	return base + (TalentMods.get(player).counterBonus or 0)
end

function TalentMods.finisherMultiplier(player): number
	return 1 + (TalentMods.get(player).finisherBonus or 0)
end

-- «Сила душ»: урон сверх обычного бонуса стаков.
function TalentMods.soulDamage(player, stacks: number): number
	local mods = TalentMods.get(player)
	if not mods.soulDamagePer then
		return 0
	end
	return math.min((stacks or 0) * mods.soulDamagePer, mods.soulDamageMax or 0.08)
end

-- «Меткость»: свой шанс крита поверх шанса эха (если эхо не дало крит).
-- Возвращает множитель и флаг, как Echo.rollCrit.
function TalentMods.extraCrit(player, rng: Random?): (number, boolean)
	local chance = isPlayer(player) and TalentMods.get(player).critChance or 0
	if not chance or chance <= 0 then
		return 1, false
	end
	local r = rng and rng:NextNumber() or math.random()
	if r < chance then
		return Echo.CritMultiplier, true
	end
	return 1, false
end

-- «Ответный удар»: множитель следующей атаки (и снять заряд).
function TalentMods.consumeRetaliate(player): number
	local state = runtime[player]
	if not state or not state.retaliateArmed then
		return 1
	end
	state.retaliateArmed = false
	player:SetAttribute("TalentRetaliate", false)
	return 1 + (TalentMods.get(player).retaliateBonus or 0)
end

-- После полученного урона (CombatService.damagePlayer).
function TalentMods.onDamaged(player, taken: number)
	if taken <= 0 then
		return
	end
	local mods = TalentMods.get(player)
	if not mods.retaliateBonus then
		return
	end
	local state = stateOf(player)
	local t = now()
	if not state.retaliateArmed and t >= state.retaliateReadyAt then
		state.retaliateArmed = true
		state.retaliateReadyAt = t + (mods.retaliateCooldown or 4)
		player:SetAttribute("TalentRetaliate", true)
	end
end

-- «Несгибаемый»: true — смерть отменена (CombatService оставит 1 здоровья).
function TalentMods.tryCheatDeath(player): (boolean, number)
	local mods = TalentMods.get(player)
	if not mods.cheatDeath then
		return false, 0
	end
	local state = stateOf(player)
	if state.cheatUsed then
		return false, 0
	end
	state.cheatUsed = true
	player:SetAttribute("TalentCheatUsed", true)
	return true, mods.cheatDeathInvuln or 2
end

-- Новый забег (вход на этаж, смерть, хаб): «раз за забег» снова доступно.
function TalentMods.onRunReset(player)
	local state = runtime[player]
	if state then
		state.cheatUsed = false
		state.retaliateArmed = false
		state.shield = nil
		state.spells = 0
		state.empowered = false
		state.boltHits = 0
	end
	if isPlayer(player) then
		player:SetAttribute("TalentCheatUsed", false)
		player:SetAttribute("TalentShield", 0)
	end
end

-- ===== урон по врагам (EnemyService.applyDamage) =====

local function shredOf(enemy, t: number): number
	local shred = enemy.talentShred
	if shred and t < shred.untilT then
		return shred.stacks
	end
	return 0
end
TalentMods.shredOf = shredOf

-- Входящий в врага урон от игрока: (новый урон, снятая броня).
function TalentMods.outgoing(attacker, enemy, amount: number, t: number): (number, number)
	local pierce = shredOf(enemy, t)
	if not isPlayer(attacker) then
		return amount, pierce
	end
	local mods = TalentMods.get(attacker)
	if mods.stunnedBonus and enemy.stunUntil and t < enemy.stunUntil then
		amount *= 1 + mods.stunnedBonus
	end
	pierce += mods.armorPierce or 0
	return amount, pierce
end

-- После удачного удара: стак «Разрушителя».
function TalentMods.afterHit(attacker, enemy, t: number)
	if not isPlayer(attacker) or not enemy.alive then
		return
	end
	local mods = TalentMods.get(attacker)
	if not mods.shredPerHit then
		return
	end
	local current = shredOf(enemy, t)
	enemy.talentShred = {
		stacks = math.min(current + mods.shredPerHit, mods.shredMax or 6),
		untilT = t + (mods.shredTime or 4),
	}
	if enemy.model then
		enemy.model:SetAttribute("EnemyShred", enemy.talentShred.stacks)
		enemy.model:SetAttribute("EnemyShredUntil", enemy.talentShred.untilT)
	end
end

function TalentMods.reflectMultiplier(player): number
	if not isPlayer(player) then
		return 1
	end
	return 1 + (TalentMods.get(player).reflectBonus or 0)
end

-- ===== способности =====

function TalentMods.cooldownScale(player): number
	return math.max(0.3, 1 + (TalentMods.get(player).abilityCooldown or 0))
end

function TalentMods.abilityDamageScale(player): number
	return 1 + (TalentMods.get(player).abilityDamage or 0)
end

function TalentMods.castTimeScale(player): number
	return math.max(0.3, 1 + (TalentMods.get(player).castTime or 0))
end

-- Цена заклинания: −% от «Тонких полей», 0 — если следующее по «Эху» бесплатно.
function TalentMods.spellCost(player, base: number): (number, boolean)
	local mods = TalentMods.get(player)
	local every = mods.freeEvery
	if every and every > 1 then
		local state = stateOf(player)
		if (state.spells + 1) % every == 0 then
			return 0, true
		end
	end
	return math.max(math.floor(base * (1 + (mods.spellCost or 0)) + 0.5), 0), false
end

-- Заклинание прочитано: счётчик «Эха заклинаний», заряд «Резкости».
function TalentMods.noteSpell(player)
	local mods = TalentMods.get(player)
	if mods.freeEvery then
		local state = stateOf(player)
		state.spells += 1
		player:SetAttribute("TalentSpellCount", state.spells % mods.freeEvery)
	end
	if mods.empower then
		stateOf(player).empowered = true
		player:SetAttribute("TalentEmpower", true)
	end
end

-- «Резкость»: множитель удара посохом после заклинания (и снять заряд).
function TalentMods.consumeEmpower(player): number
	local state = runtime[player]
	if not state or not state.empowered then
		return 1
	end
	state.empowered = false
	player:SetAttribute("TalentEmpower", false)
	return 1 + (TalentMods.get(player).empower or 0)
end

-- ===== снаряды посоха (MageService.spawnBolt / boltHit) =====

-- Модификаторы снарядов посоха или nil, если древо их не трогает.
-- speed/range — множители; homing — °/с; pierce — сколько ещё врагов пробить.
function TalentMods.boltMods(player)
	if not isPlayer(player) then
		return nil
	end
	local mods = TalentMods.get(player)
	if not (mods.projectileSpeed or mods.projectileRange or mods.homing or mods.pierce or mods.splitEvery) then
		return nil
	end
	return {
		speed = 1 + (mods.projectileSpeed or 0),
		range = 1 + (mods.projectileRange or 0),
		homing = mods.homing,
		pierce = mods.pierce and math.floor(mods.pierce + 0.5) or 0,
		pierceShare = mods.pierceShare or 1,
		splitEvery = mods.splitEvery,
		splitShards = mods.splitShards or 3,
		splitShare = mods.splitShare or 0.4,
	}
end

-- «Расщепление»: true — это попадание раскалывает снаряд (каждое N-е).
function TalentMods.rollSplit(player): boolean
	local every = TalentMods.get(player).splitEvery
	if not every or every < 1 then
		return false
	end
	local state = stateOf(player)
	state.boltHits += 1
	if state.boltHits >= every then
		state.boltHits = 0
		return true
	end
	return false
end

-- ===== «Покров» и барьер мага =====

function TalentMods.veilDuration(player, base: number): number
	return base + (TalentMods.get(player).veilDuration or 0)
end

function TalentMods.veilCooldown(player, base: number): number
	local mods = TalentMods.get(player)
	return math.max(1, (base + (mods.veilCooldown or 0)) * TalentMods.cooldownScale(player))
end

function TalentMods.ambush(player, base: number): number
	return base + (TalentMods.get(player).ambushBonus or 0)
end

function TalentMods.barrierRefund(player, base: number): number
	return base + (TalentMods.get(player).barrierRefund or 0)
end

-- «Покров» спал (вышло время или герой ударил): щит «Плаща забвения».
function TalentMods.onVeilEnd(player)
	TalentMods.clearSpeed(player, "veil")
	local mods = TalentMods.get(player)
	if not mods.veilShield then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local state = stateOf(player)
	local duration = mods.veilShieldTime or 4
	state.shield = { left = humanoid.MaxHealth * mods.veilShield, untilT = now() + duration }
	player:SetAttribute("TalentShield", math.floor(state.shield.left + 0.5))
	player:SetAttribute("TalentShieldUntil", state.shield.untilT)
end

-- Щит забирает урон (CombatService.damagePlayer после брони).
function TalentMods.absorb(player, damage: number): number
	local state = runtime[player]
	local shield = state and state.shield
	if not shield or damage <= 0 then
		return damage
	end
	if now() >= shield.untilT then
		state.shield = nil
		player:SetAttribute("TalentShield", 0)
		return damage
	end
	local soaked = math.min(shield.left, damage)
	shield.left -= soaked
	if shield.left <= 0.01 then
		state.shield = nil
	end
	player:SetAttribute("TalentShield", state.shield and math.floor(shield.left + 0.5) or 0)
	return damage - soaked
end

-- ===== временные бафы =====

function TalentMods.speedBonus(player, t: number?): number
	local state = runtime[player]
	if not state then
		return 0
	end
	t = t or now()
	local best = 0
	for _, entry in pairs(state.speed) do
		if t < entry.untilT and entry.pct > best then
			best = entry.pct
		end
	end
	return best
end

local function refreshSpeed(player)
	local hook = TalentMods.hooks.refreshSpeed
	if hook then
		local ok, err = pcall(hook, player)
		if not ok then
			warn("[TalentMods] refreshSpeed: " .. tostring(err))
		end
	end
end

-- Баф скорости бега от источника (сильнейший действует, бафы не складываются).
function TalentMods.addSpeed(player, source: string, pct: number, duration: number)
	local state = stateOf(player)
	local untilT = now() + duration
	state.speed[source] = { pct = pct, untilT = untilT }
	refreshSpeed(player)
	task.delay(duration + 0.05, function()
		local entry = state.speed[source]
		if entry and entry.untilT == untilT and player.Parent then
			state.speed[source] = nil
			refreshSpeed(player)
		end
	end)
end

function TalentMods.clearSpeed(player, source: string)
	local state = runtime[player]
	if state and state.speed[source] then
		state.speed[source] = nil
		refreshSpeed(player)
	end
end

-- Скорость атаки на время («Боевой раж»).
function TalentMods.addHaste(player, pct: number, duration: number)
	local state = stateOf(player)
	state.haste = pct
	state.hasteUntil = now() + duration
	player:SetAttribute("TalentHasteUntil", state.hasteUntil)
end

function TalentMods.forget(player)
	cache[player] = nil
	runtime[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	TalentMods.forget(player)
end)

return TalentMods
