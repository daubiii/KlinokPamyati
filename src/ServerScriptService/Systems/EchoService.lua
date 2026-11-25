--!nonstrict
-- EchoService (сервер)
-- Кузня Эха: повторки предметов становятся эхом, эхо вплавляется в предмет
-- (★ уровень), лишнее эхо и переплавка дают «Пыль эха». Все числа — в
-- Shared/Config/Echo.luau, здесь только правила и проверки.
--
-- Профиль оружия: { id, name, typeId, rarityId, level, echoes, ... }.
-- Старое поле sharpening переводится в уровень: level = 1 + floor(sharpening / 2).
--
-- Ремоуты (папка KlinokUiNet): GetForge, RequestEchoUpgrade, RequestEchoMelt, GetGear.
-- Дубль при выпадении перехватывается через DataService.addWeapon (обёртка в start()).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteGuard = require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("RemoteGuard"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Classes = require(Shared.Config.Classes)
local Echo = require(Shared.Config.Echo)
local Loot = require(Shared.Config.Loot)
local Rarities = require(Shared.Config.Rarities)
local Weapons = require(Shared.Config.Weapons)
local UiNet = require(Shared.Net.UiNet)

local DataService = require(script.Parent.DataService)

local EchoService = {}

-- ===== данные =====
function EchoService.normalize(weapon)
	if not weapon then
		return nil
	end
	if weapon.level == nil then
		weapon.level = 1 + math.floor((weapon.sharpening or 0) / 2)
	end
	weapon.level = math.clamp(weapon.level, 1, Echo.maxLevel(weapon.rarityId))
	weapon.echoes = weapon.echoes or 0
	weapon.sharpening = 0 -- заточка за золото убрана: урон считает Echo
	return weapon
end

local function sameItem(a, b): boolean
	return a and b and a.id == b.id and a.rarityId == b.rarityId and a.typeId == b.typeId
end

-- Найти предмет по ключу: "eq" — в руке, "w<N>" — profile.weapons[N].
local function byKey(profile, key)
	if key == "eq" then
		return profile.equippedWeapon, true
	end
	local index = typeof(key) == "string" and tonumber(key:match("^w(%d+)$"))
	if index then
		return profile.weapons[index], false, index
	end
	return nil
end

local function publishDust(player, profile)
	player:SetAttribute("EchoDust", profile.echoDust or 0)
end

local function publishEquipped(player, profile)
	local w = profile.equippedWeapon
	player:SetAttribute("WeaponLevel", w.level)
	player:SetAttribute("WeaponEchoes", w.echoes)
end

-- +1 эхо предмету (или пыль, если эха уже хватает до потолка).
-- Возвращает сколько пыли вышло (0 — эхо легло в предмет).
local function feed(player, profile, owner): number
	EchoService.normalize(owner)
	local maxLevel = Echo.maxLevel(owner.rarityId)
	-- эха больше не нужно: всё, что сверх оставшихся подъёмов, плавится в пыль
	local needed = 0
	for n = owner.level, maxLevel - 1 do
		needed += Echo.EchoCost[n] or 0
	end
	if owner.echoes >= needed then
		local dust = Echo.dustFor(1, owner.rarityId)
		profile.echoDust = (profile.echoDust or 0) + dust
		publishDust(player, profile)
		return dust
	end
	owner.echoes += 1
	return 0
end

-- Дубль выпал: +1 эхо существующему предмету (или пыль, если на потолке).
-- Возвращает предмет-владельца или nil, если такого предмета нет.
function EchoService.absorb(player, weapon)
	local profile = DataService.get(player)
	local owner
	if sameItem(profile.equippedWeapon, weapon) then
		owner = profile.equippedWeapon
	else
		for _, w in ipairs(profile.weapons) do
			if sameItem(w, weapon) then
				owner = w
				break
			end
		end
	end
	if not owner then
		return nil
	end
	local dust = feed(player, profile, owner)
	if dust > 0 then
		player:SetAttribute("LastEcho", ("+%d пыли эха"):format(dust))
	else
		player:SetAttribute("LastEcho", ("+1 эхо: %s"):format(owner.name))
	end
	player:SetAttribute("EchoEventId", (player:GetAttribute("EchoEventId") or 0) + 1)
	publishEquipped(player, profile)
	return owner
end

-- Награда эхом (Сундук дня): count эха надетому оружию, без ленты «ПОВТОРКА».
-- Возвращает сколько пыли вышло из лишнего эха.
function EchoService.grantEcho(player, count: number): number
	local profile = DataService.get(player)
	local dust = 0
	for _ = 1, count do
		dust += feed(player, profile, profile.equippedWeapon)
	end
	publishEquipped(player, profile)
	return dust
end

function EchoService.addDust(player, amount: number)
	local profile = DataService.get(player)
	profile.echoDust = (profile.echoDust or 0) + amount
	publishDust(player, profile)
end

-- ===== расчёт статов для окна =====
local function baseDamage(profile)
	local class = Classes.data[profile.className or "warrior"] or Classes.data.warrior
	return class.weaponDamage + class.weaponDamagePerLevel * math.max((profile.level or 1) - 1, 0)
end

local function statsAt(profile, weapon, level: number)
	local ok, dmg = pcall(Weapons.damage, baseDamage(profile), weapon.typeId, weapon.rarityId, 0, weapon.id)
	dmg = ok and dmg or 0
	return {
		damage = math.floor(dmg * Echo.damageMultiplier(level) + 0.5),
		crit = math.floor(Echo.critChance(level, weapon.rarityId) * 100 + 0.5),
		ability = Loot.abilityOf(weapon) and math.floor((Echo.abilityMultiplier(level) - 1) * 100 + 0.5) or 0,
	}
end

local function describe(profile, weapon, key, equipped)
	EchoService.normalize(weapon)
	local cost = Echo.cost(weapon.level, weapon.rarityId)
	local weaponType = Weapons.Types[weapon.typeId]
	local ability = Loot.abilityOf(weapon)
	return {
		key = key,
		index = not equipped and tonumber(key:match("%d+")) or nil,
		id = weapon.id, -- шаблон оружия: окна строят по нему 3D-модель (Lib/ItemView)
		name = weapon.name,
		typeId = weapon.typeId,
		typeName = weaponType and weaponType.name or weapon.typeId,
		rarityId = weapon.rarityId,
		rarityName = Rarities.get(weapon.rarityId) and Rarities.get(weapon.rarityId).name or weapon.rarityId,
		level = weapon.level,
		maxLevel = Echo.maxLevel(weapon.rarityId),
		echoes = weapon.echoes,
		equipped = equipped,
		cost = cost,
		now = statsAt(profile, weapon, weapon.level),
		next = cost and statsAt(profile, weapon, weapon.level + 1) or nil,
		socketLevel = Echo.SoulSocketLevel,
		soul = weapon.soul,
		ability = ability and ability.name or nil,
		dustValue = Echo.dustFor(1 + weapon.echoes + Echo.totalEchoes(weapon.level), weapon.rarityId),
		isNew = weapon.isNew,
	}
end

function EchoService.forgeState(player)
	local profile = DataService.get(player)
	local className = profile.className or "warrior"
	local items = { describe(profile, profile.equippedWeapon, "eq", true) }
	for i, w in ipairs(profile.weapons) do
		-- Оружие чужого класса (посохи у воина, мечи у мага) не показываем — ждёт смены класса.
		-- Ключи "w<N>" — по месту в profile.weapons, поэтому пропуски не сбивают нумерацию.
		if Loot.weaponClass(w) == className then
			table.insert(items, describe(profile, w, "w" .. i, false))
		end
	end
	return { gold = profile.gold, dust = profile.echoDust or 0, items = items }
end

-- Кузня: оружие + комплекты брони (ключи брони "A:<ключ ArmorService>").
-- Окно инвентаря (gearState) по-прежнему берёт только оружие из forgeState.
local function forgeWithArmor(player)
	local state = EchoService.forgeState(player)
	local ok, ArmorService = pcall(require, script.Parent.ArmorService)
	if ok and ArmorService and ArmorService.forgeItems then
		local okItems, list = pcall(ArmorService.forgeItems, player)
		if okItems and type(list) == "table" then
			for _, item in ipairs(list) do
				table.insert(state.items, item)
			end
		end
	end
	local profile = DataService.get(player)
	state.materials = table.clone(profile.materials or {})
	return state
end
EchoService.forgeFull = forgeWithArmor

local function armorKey(key)
	return typeof(key) == "string" and key:match("^A:(.+)$") or nil
end

-- Снаряжение для окна инвентаря (с «Силой»).
function EchoService.gearState(player)
	local state = EchoService.forgeState(player)
	local profile = DataService.get(player)
	local equipped = state.items[1]
	for _, item in ipairs(state.items) do
		item.damage = item.now.damage
		item.crit = item.now.crit
		local weaponType = Weapons.Types[item.typeId]
		item.speed = weaponType and weaponType.speedMultiplier or 1
	end
	local power = math.floor((equipped.now.damage * (1 + equipped.now.crit / 100 * (Echo.CritMultiplier - 1))) * 10 + 0.5)
	local best = 0
	for _, item in ipairs(state.items) do
		best = math.max(best, item.now.damage)
	end
	local soulsById = {}
	for _, soul in ipairs(profile.souls or {}) do
		if type(soul) == "table" then
			local id = tostring(soul.id or soul.name or "soul")
			local item = soulsById[id]
			if item then
				item.count += 1
			else
				item = {
					id = id,
					name = soul.name or id,
					rarityId = soul.rarityId or soul.rarity,
					kind = soul.kind,
					count = 1,
				}
				soulsById[id] = item
			end
		end
	end
	local souls = {}
	for _, soul in pairs(soulsById) do
		table.insert(souls, soul)
	end
	table.sort(souls, function(a, b)
		return a.name < b.name
	end)
	local materials = {}
	for id, count in pairs(profile.materials or {}) do
		if type(count) == "number" and count > 0 then
			table.insert(materials, {
				id = id,
				name = (Loot.MaterialNames and Loot.MaterialNames[id]) or (id == Loot.IronMaterial and "Ржавое железо") or id,
				count = count,
			})
		end
	end
	table.sort(materials, function(a, b)
		return a.name < b.name
	end)
	-- Броня (ArmorService): вкладка «Броня», слоты шлема и доспеха, вклад в «Силу».
	local armorState = { items = {}, slots = {}, armor = 0, health = 0, reduction = 0 }
	local okArmor, ArmorService = pcall(require, script.Parent.ArmorService)
	if okArmor and ArmorService and ArmorService.gearState then
		local ok, result = pcall(ArmorService.gearState, player)
		if ok and type(result) == "table" then
			armorState = result
		end
	end
	power += math.floor(armorState.armor * 6 + armorState.health * 0.5 + armorState.reduction * 4 + (armorState.mana or 0) * 0.4 + 0.5)
	return {
		power = power,
		powerDelta = best > equipped.now.damage and (best - equipped.now.damage) * 10 or nil,
		equipped = equipped,
		items = state.items,
		armorItems = armorState.items,
		armorStats = { armor = armorState.armor, totalArmor = armorState.totalArmor, health = armorState.health, reduction = armorState.reduction,
			mana = armorState.mana, manaRegen = armorState.manaRegen, className = armorState.className },
		slots = armorState.slots,
		souls = souls,
		soulStacks = profile.soulStacks or 0,
		materials = materials,
	}
end

-- Ковать и плавить можно только в долине (на этаже окно Кузни закрыто).
local function onFloor(player): boolean
	return player:GetAttribute("Zone") == "Floor"
end

function EchoService.upgrade(player, key)
	if onFloor(player) then
		return { ok = false, reason = "bad-request" }
	end
	-- Комплект брони: эхо + материал этажа (ArmorService).
	local aKey = armorKey(key)
	if aKey then
		local ArmorService = require(script.Parent.ArmorService)
		return ArmorService.requestUpgrade(player, aKey)
	end
	local profile = DataService.get(player)
	local weapon = byKey(profile, key)
	if not weapon then
		return { ok = false, reason = "bad-request" }
	end
	EchoService.normalize(weapon)
	local cost = Echo.cost(weapon.level, weapon.rarityId)
	if not cost then
		return { ok = false, reason = "max" }
	end
	if weapon.echoes < cost.echoes then
		return { ok = false, reason = "echo", need = cost.echoes - weapon.echoes }
	end
	if not DataService.spendGold(player, cost.gold) then
		return { ok = false, reason = "gold", need = cost.gold }
	end
	local before = weapon.level
	weapon.echoes -= cost.echoes
	weapon.level += 1
	local unlocked = {}
	if weapon.level == Echo.SoulSocketLevel then
		table.insert(unlocked, "socket")
	end
	if Echo.CooldownMilestones[weapon.level] then
		table.insert(unlocked, "cooldown")
	end
	publishEquipped(player, profile)
	return { ok = true, levelBefore = before, levelAfter = weapon.level, unlocked = unlocked }
end

function EchoService.melt(player, key)
	if onFloor(player) then
		return { ok = false, reason = "bad-request" }
	end
	if armorKey(key) then
		return { ok = false, reason = "armor" }
	end
	local profile = DataService.get(player)
	local weapon, equipped, index = byKey(profile, key)
	if not weapon or equipped or not index then
		return { ok = false, reason = equipped and "equipped" or "bad-request" }
	end
	EchoService.normalize(weapon)
	local dust = Echo.dustFor(1 + weapon.echoes + Echo.totalEchoes(weapon.level), weapon.rarityId)
	table.remove(profile.weapons, index)
	profile.echoDust = (profile.echoDust or 0) + dust
	publishDust(player, profile)
	player:SetAttribute("WeaponCount", #profile.weapons)
	return { ok = true, dust = dust }
end

-- Урон и крит для MeleeService / AbilityService (см. README, «Подключение урона»).
function EchoService.damageMultiplier(weapon): number
	EchoService.normalize(weapon)
	return Echo.damageMultiplier(weapon.level)
end

function EchoService.rollCrit(weapon, rng: Random?)
	EchoService.normalize(weapon)
	return Echo.rollCrit(weapon.level, weapon.rarityId, rng)
end

function EchoService.start()
	-- Дубли при выпадении → эхо. LootService зовёт DataService.addWeapon.
	local originalAdd = DataService.addWeapon
	DataService.addWeapon = function(player, weapon)
		local owner = EchoService.absorb(player, weapon)
		if owner then
			return owner
		end
		EchoService.normalize(weapon)
		return originalAdd(player, weapon)
	end

	local function hook(player)
		-- Нормализуем эхи только на настоящем профиле (не заглушке).
		local profile = player.Parent and DataService.waitForProfile(player, 60) or nil
		if not profile then
			return
		end
		EchoService.normalize(profile.equippedWeapon)
		for _, w in ipairs(profile.weapons) do
			EchoService.normalize(w)
		end
		profile.echoDust = profile.echoDust or 0
		publishDust(player, profile)
		publishEquipped(player, profile)
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(hook, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(hook, player)
	end

	UiNet.ensure("GetForge").OnServerInvoke = RemoteGuard.wrap("GetForge", forgeWithArmor)
	UiNet.ensure("GetGear").OnServerInvoke = RemoteGuard.wrap("GetGear", EchoService.gearState)
	UiNet.ensure("RequestEchoUpgrade").OnServerInvoke = RemoteGuard.wrap("RequestEchoUpgrade", EchoService.upgrade)
	UiNet.ensure("RequestEchoMelt").OnServerInvoke = RemoteGuard.wrap("RequestEchoMelt", EchoService.melt)
	print("[EchoService] Кузня Эха запущена")
end

return EchoService


