--!nonstrict
-- ArmorService (сервер)
-- Броня героя — КОМПЛЕКТ одним предметом (переделка 06.11.2026): шлем и доспех
-- (у мага шляпа и накидка) идут вместе, у эпических и легендарных — пассивка.
-- Сундук всегда кладёт комплект (свой бросок редкости), повторка → эхо,
-- ★ поднимает кузнец за эхо и материал этажа комплекта. Числа — Config/Armor,
-- Config/ArmorFloors, Config/Echo.
--
-- Профиль (формат брони 2, поле profile.armorFormat = 2):
--   profile.armorEquipped = { set = item }   — надетый комплект текущего класса
--   profile.armorStash    = { [класс] = item } — надетое на других классах
--   profile.armorItems    = { item, ... }      — снятые и найденные комплекты всех классов
--   item = { kind = "armor", id = setId, setId, slot = "set", name, rarityId, level, echoes }
-- Старые профили (два слота helm/armor) переводятся в ensureProfile: каждая
-- часть становится комплектом своего набора, одинаковые сливаются (★ — больший,
-- эхо — сумма).
--
-- В бой броня попадает через CombatService.hooks.gearStats (плоская броня и
-- здоровье) и CombatService.hooks.gearReduction (доля снижения урона).
-- Пассивка «regen» тикает здесь же (start). Облик — AppearanceService.refresh.
--
-- Ремоуты (KlinokUiNet): RequestEquipArmor(key), RequestArmorUpgrade(key).
-- key: "set" (и старые "helm"/"armor") — надетое, "a<N>" — profile.armorItems[N].

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local RemoteGuard = require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("RemoteGuard"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Armor = require(Shared.Config.Armor)
local Echo = require(Shared.Config.Echo)
local Loot = require(Shared.Config.Loot)
local Rarities = require(Shared.Config.Rarities)
local Net = require(Shared.Net.Net)
local UiNet = require(Shared.Net.UiNet)
local DebugState = require(Shared.Net.DebugState)
local ArmorMigrate = require(Shared.Util.ArmorMigrate)

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)
local AppearanceService = require(script.Parent.AppearanceService)

local ArmorService = {}

local SLOT = Armor.Slot -- "set"

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- ===== данные =====

local function normalize(item)
	if not item then
		return nil
	end
	local template = Armor.template(item.id)
	if template then
		item.id = template.id
		item.setId = template.setId
		item.name = template.name
		item.rarityId = template.rarity
	end
	item.slot = SLOT
	item.kind = "armor"
	item.level = math.clamp(item.level or 1, 1, Echo.maxLevel(item.rarityId or "common"))
	item.echoes = item.echoes or 0
	return item
end

local function classOf(profile): string
	return profile.className or "warrior"
end

local function sameItem(a, b): boolean
	return a and b and a.setId == b.setId and a.rarityId == b.rarityId
end

-- Довести профиль до формата 2 (новый профиль и старые сохранения).
-- Надетое чужого класса (сменили класс) уходит в armorStash, на его место —
-- то, что этот класс носил раньше, или его стартовый комплект.
function ArmorService.ensureProfile(profile)
	profile.armorItems = profile.armorItems or {}
	profile.armorEquipped = profile.armorEquipped or {}
	profile.armorStash = profile.armorStash or {}
	ArmorMigrate.run(profile)
	local className = classOf(profile)
	local hasArmor = Armor.canWear(className)
	local item = profile.armorEquipped[SLOT]
	if item and hasArmor and Armor.classOf(item.setId) ~= className then
		local owner = Armor.classOf(item.setId) or "warrior"
		if profile.armorStash[owner] then
			table.insert(profile.armorItems, profile.armorStash[owner])
		end
		profile.armorStash[owner] = item
		item = nil
	end
	if not item and hasArmor then
		item = profile.armorStash[className] or Armor.newItem(Armor.starterFor(className), nil, "starter")
		profile.armorStash[className] = nil
	end
	if not item then
		-- Класс без брони (ассасин): облик и профиль — по стартовому воина.
		item = Armor.newItem(Armor.StarterSet, nil, "starter")
	end
	profile.armorEquipped = { [SLOT] = item }
	normalize(item)
	for _, other in ipairs(profile.armorItems) do
		normalize(other)
	end
	return profile
end

local function profileOf(player)
	return ArmorService.ensureProfile(DataService.get(player))
end

local function equippedOf(profile)
	return profile.armorEquipped[SLOT]
end

local function byKey(profile, key)
	if key == SLOT or key == "helm" or key == "armor" then
		return equippedOf(profile), true, nil
	end
	local index = typeof(key) == "string" and tonumber(key:match("^a(%d+)$"))
	if index then
		return profile.armorItems[index], false, index
	end
	return nil
end

-- ===== статы =====

local function itemHealth(item, level: number?): number
	local template = Armor.template(item.id)
	if not template then
		return 0
	end
	return math.floor(template.health * Echo.armorHpMultiplier(level or item.level or 1) + 0.5)
end

local function itemArmor(item): number
	local template = Armor.template(item.id)
	return template and template.armor or 0
end

local function itemReduction(item, level: number?): number
	return Echo.damageReduction(level or item.level or 1, item.rarityId or "common") * Armor.ReductionShare
end

-- Мана комплекта мага растёт с ★, как здоровье.
local function itemMana(item, level: number?): number
	local template = Armor.template(item.id)
	if not template or (template.mana or 0) <= 0 then
		return 0
	end
	return math.floor(template.mana * Echo.armorHpMultiplier(level or item.level or 1) + 0.5)
end

local function itemManaRegen(item): number
	local template = Armor.template(item.id)
	return template and template.manaRegen or 0
end

local function wears(profile): boolean
	return Armor.canWear(profile.className)
end

local function passiveOf(profile)
	local item = equippedOf(profile)
	local set = item and Armor.Sets[item.setId]
	return set and set.passive or nil
end

-- Плоские бонусы снаряжения: { armor, health, mana, manaRegen }.
function ArmorService.gearStats(player)
	local profile = profileOf(player)
	if not wears(profile) then
		return { armor = 0, health = 0, mana = 0, manaRegen = 0 }
	end
	local item = equippedOf(profile)
	if not item then
		return { armor = 0, health = 0, mana = 0, manaRegen = 0 }
	end
	return { armor = itemArmor(item), health = itemHealth(item), mana = itemMana(item), manaRegen = itemManaRegen(item) }
end

-- Пассивка надетого комплекта (или nil). Имя прежнее — его зовёт ManaService
-- (manaOnDodge): раньше это был «бонус полного комплекта».
function ArmorService.setBonus(player)
	return passiveOf(profileOf(player))
end
ArmorService.passive = ArmorService.setBonus

-- Время последнего парирования и последнего урона по герою (для пассивок).
local lastParry = {} -- [player] = t
local lastHit = {} -- [player] = t

-- Активна ли условная пассивка прямо сейчас (для окна и для снижения урона).
local function passiveReduction(player, passive, humanoid): number
	if not passive or not passive.reduction then
		return 0
	end
	local kind = passive.kind
	if kind == "afterDodge" then
		local last = player:GetAttribute("LastDodgeAt") or 0
		return (now() - last <= (passive.duration or 1)) and passive.reduction or 0
	elseif kind == "afterParry" then
		return (now() - (lastParry[player] or -math.huge) <= (passive.duration or 1)) and passive.reduction or 0
	elseif (kind == "steadfast" or kind == "lastStand") and humanoid and humanoid.MaxHealth > 0 then
		local share = humanoid.Health / humanoid.MaxHealth
		if kind == "steadfast" then
			return share > (passive.threshold or 0.5) and passive.reduction or 0
		end
		return share < (passive.threshold or 0.35) and passive.reduction or 0
	elseif kind == "manaWard" then
		local maxMana = player:GetAttribute("MaxMana") or 0
		if maxMana > 0 and (player:GetAttribute("Mana") or 0) / maxMana > (passive.threshold or 0.5) then
			return passive.reduction
		end
	end
	return 0
end

-- Доля снижения урона прямо сейчас (с учётом пассивки).
function ArmorService.reduction(player, humanoid): number
	local profile = profileOf(player)
	if not wears(profile) then
		return 0
	end
	local item = equippedOf(profile)
	local value = item and math.min(itemReduction(item), Echo.ReductionCap) or 0
	value += passiveReduction(player, passiveOf(profile), humanoid)
	-- Общий потолок: даже с пассивкой броня не делает героя бессмертным.
	return math.clamp(value, 0, Armor.ReductionCap)
end

local function publish(player)
	local profile = profileOf(player)
	local gear = ArmorService.gearStats(player)
	local item = equippedOf(profile)
	player:SetAttribute("GearArmor", gear.armor)
	player:SetAttribute("GearHealth", gear.health)
	player:SetAttribute("GearMana", gear.mana)
	player:SetAttribute("GearManaRegen", gear.manaRegen)
	-- ArmorHelm / ArmorChest — прежние атрибуты (их читают HUD и окна): оба = комплект.
	player:SetAttribute("ArmorHelm", item and item.id or "")
	player:SetAttribute("ArmorChest", item and item.id or "")
	player:SetAttribute("ArmorSet", item and item.setId or "")
	local passive = passiveOf(profile)
	player:SetAttribute("ArmorPassive", passive and passive.name or "")
	player:SetAttribute("ArmorCount", #profile.armorItems)
end

-- Облик по надетому: шлем и корпус — от одного комплекта.
function ArmorService.look(player)
	local profile = profileOf(player)
	local item = equippedOf(profile)
	local starter = Armor.canWear(profile.className) and Armor.starterFor(profile.className) or Armor.StarterSet
	local setId = item and item.setId or starter
	return { helm = setId, armor = setId }
end

-- Пересчитать здоровье/броню и облик после смены брони.
local function apply(player)
	publish(player)
	-- Здоровье и скорость пересчитывает прогресс (сохраняет долю HP).
	local ok, ProgressionService = pcall(require, script.Parent.ProgressionService)
	if ok and ProgressionService and ProgressionService.applyLevel then
		ProgressionService.applyLevel(player)
	end
	-- Мана мага (макс. и реген) зависит от облачения.
	local okMana, ManaService = pcall(require, script.Parent.ManaService)
	if okMana and ManaService and ManaService.recalc then
		ManaService.recalc(player)
	end
	local character = player.Character
	if character then
		AppearanceService.refresh(character, ArmorService.look(player))
	end
end

-- ===== кузнец: цена ★ =====

-- Цена подъёма комплекта: { echoes, materials, materialId, materialName, gold } или nil (потолок).
function ArmorService.cost(item)
	local echoCost = Echo.cost(item.level or 1, item.rarityId or "common")
	if not echoCost then
		return nil
	end
	local floor = Armor.floorOf(item.setId)
	return {
		echoes = echoCost.echoes,
		materials = Armor.materialCost(item.level or 1, item.rarityId or "common") or 0,
		materialId = Loot.materialOf(floor),
		materialName = Loot.materialName(floor),
		floor = floor,
		gold = Armor.GoldFee or 0,
	}
end

-- ===== описание для окон =====

local function describe(item, key: string, equipped: boolean, profile)
	normalize(item)
	local template = Armor.template(item.id)
	local set = template and Armor.Sets[template.setId]
	local cost = ArmorService.cost(item)
	local itemClass = template and template.class or "warrior"
	local mana = itemMana(item)
	local passive = set and set.passive
	local have = cost and (profile.materials and profile.materials[cost.materialId] or 0) or 0
	local reduction = math.floor(itemReduction(item) * 1000 + 0.5) / 10
	return {
		key = key,
		kind = "armor",
		id = item.id,
		index = not equipped and tonumber(key:match("%d+")) or nil,
		name = item.name,
		slot = SLOT,
		slotName = Armor.slotName(SLOT, itemClass),
		class = itemClass,
		floor = template and template.floor or 1,
		setId = item.setId,
		setName = set and set.name or "",
		pieces = template and template.pieces or nil,
		-- passive — пассивка эпических и легендарных (setBonus — старое имя поля для окон).
		passive = passive and { name = passive.name, description = passive.description, kind = passive.kind } or nil,
		setBonus = passive and passive.description or nil,
		setActive = equipped and passive ~= nil,
		rarityId = item.rarityId,
		rarityName = Rarities.get(item.rarityId) and Rarities.get(item.rarityId).name or item.rarityId,
		level = item.level,
		maxLevel = Echo.maxLevel(item.rarityId),
		echoes = item.echoes,
		cost = cost,
		materialHave = have,
		equipped = equipped,
		armor = itemArmor(item),
		health = itemHealth(item),
		nextHealth = cost and itemHealth(item, item.level + 1) or nil,
		mana = mana > 0 and mana or nil,
		nextMana = cost and mana > 0 and itemMana(item, item.level + 1) or nil,
		manaRegen = itemManaRegen(item) > 0 and itemManaRegen(item) or nil,
		reduction = reduction,
		nextReduction = cost and math.floor(itemReduction(item, item.level + 1) * 1000 + 0.5) / 10 or nil,
		-- для Кузни (ForgeWindow): «сейчас → после»
		now = { armor = itemArmor(item), health = itemHealth(item), reduction = reduction, mana = mana > 0 and mana or nil },
		next = cost and {
			armor = itemArmor(item),
			health = itemHealth(item, item.level + 1),
			reduction = math.floor(itemReduction(item, item.level + 1) * 1000 + 0.5) / 10,
			mana = mana > 0 and itemMana(item, item.level + 1) or nil,
		} or nil,
	}
end

-- Для окон (вкладка «Броня», кукла). slots.helm и slots.armor — обе клетки
-- куклы показывают надетый комплект; slots.set — он же.
function ArmorService.gearState(player)
	local profile = profileOf(player)
	local items = {}
	local slots = {}
	local item = equippedOf(profile)
	if item then
		local info = describe(item, SLOT, true, profile)
		slots[SLOT] = info
		for _, doll in ipairs(Armor.DollSlots) do
			slots[doll] = info
		end
		table.insert(items, info)
	end
	-- Броня других классов лежит в профиле, но в окне не видна.
	local className = classOf(profile)
	for index, other in ipairs(profile.armorItems) do
		if Armor.classOf(other.setId) == className then
			table.insert(items, describe(other, "a" .. index, false, profile))
		end
	end
	local gear = ArmorService.gearStats(player)
	local okStats, stats = pcall(CombatService.getStats, player)
	return {
		items = items,
		slots = slots,
		totalArmor = okStats and stats and math.floor(stats.armor + 0.5) or gear.armor,
		armor = gear.armor,
		health = gear.health,
		mana = gear.mana,
		manaRegen = gear.manaRegen,
		reduction = math.floor(ArmorService.reduction(player, nil) * 100 + 0.5),
		className = className,
		slotNames = Armor.SlotNames[className] or Armor.SlotNames.warrior,
	}
end

-- Строки брони для Кузни (EchoService.forgeState): ключ "A:<key>".
function ArmorService.forgeItems(player)
	local state = ArmorService.gearState(player)
	local list = {}
	for _, info in ipairs(state.items) do
		info.key = "A:" .. info.key
		info.typeName = ("%s · этаж %d"):format(info.slotName or "Броня", info.floor or 1)
		table.insert(list, info)
	end
	return list
end

-- ===== эхо =====

-- Повторка: +1 эхо комплекту. Если эха уже хватает до потолка — пыль.
local function feed(player, profile, owner): number
	normalize(owner)
	local maxLevel = Echo.maxLevel(owner.rarityId)
	local needed = 0
	for n = owner.level, maxLevel - 1 do
		needed += Echo.EchoCost[n] or 0
	end
	if owner.echoes >= needed then
		local dust = Echo.dustFor(1, owner.rarityId)
		profile.echoDust = (profile.echoDust or 0) + dust
		player:SetAttribute("EchoDust", profile.echoDust)
		return dust
	end
	owner.echoes += 1
	return 0
end

local function findOwner(profile, item)
	local worn = equippedOf(profile)
	if sameItem(worn, item) then
		return worn
	end
	for _, existing in ipairs(profile.armorItems) do
		if sameItem(existing, item) then
			return existing
		end
	end
	for _, existing in pairs(profile.armorStash or {}) do
		if type(existing) == "table" and sameItem(existing, item) then
			return existing
		end
	end
	return nil
end

-- Положить находку в профиль. Повторка → +1 эхо существующему комплекту.
-- Возвращает (предмет, isEcho, пыль).
function ArmorService.give(player, item)
	local profile = profileOf(player)
	normalize(item)
	local owner = findOwner(profile, item)
	if owner then
		local dust = feed(player, profile, owner)
		publish(player)
		return owner, true, dust
	end
	table.insert(profile.armorItems, item)
	profile.newArmor = (profile.newArmor or 0) + 1
	publish(player)
	return item, false, 0
end

-- Бросок брони для сундука: комплект есть ВСЕГДА, редкость — свой бросок по
-- весам этажа (без секретной), независимо от оружия. nil — класс без брони.
function ArmorService.rollChest(player, floorId: number?, isBoss: boolean?)
	local profile = profileOf(player)
	if not wears(profile) then
		return nil
	end
	local rng = Random.new()
	local className = classOf(profile)
	-- LootService уже прибавил этот сундук к chestsOpened: считаем как у оружия (до прибавки).
	local opened = math.max((profile.stats and profile.stats.chestsOpened or 0) - 1, 0)
	local weights = Loot.chestWeights(floorId, className)
	local rarityId = Armor.rollRarity(weights, rng, opened, Loot.Chest.firstChestsCommon)
	-- Нет комплекта такой редкости на этаже — тот же этажом ниже или ниже по редкости.
	local pool = Armor.chestPool(rarityId, floorId, className)
	if #pool == 0 then
		return nil
	end
	local pick = pool[rng:NextInteger(1, #pool)]
	local item = Armor.newItem(pick[1], nil, isBoss and "boss" or "chest")
	local owner, isEcho, dust = ArmorService.give(player, item)
	local set = Armor.Sets[owner.setId]
	return {
		id = owner.id,
		setId = owner.setId,
		name = owner.name,
		slot = SLOT,
		rarityId = owner.rarityId,
		passive = set and set.passive and set.passive.name or nil,
		echo = isEcho,
		echoes = owner.echoes,
		level = owner.level,
		dust = dust,
	}
end

-- ===== ремоуты =====

function ArmorService.requestEquip(player, key)
	if typeof(key) ~= "string" then
		return { ok = false, reason = "bad-request" }
	end
	local profile = profileOf(player)
	if not wears(profile) then
		return { ok = false, reason = "class" }
	end
	local item, equipped, index = byKey(profile, key)
	if not item or equipped or not index then
		return { ok = false, reason = equipped and "equipped" or "bad-request" }
	end
	if not Armor.canWear(profile.className, item.setId) then
		return { ok = false, reason = "class" }
	end
	-- Обмен: выбранное надеть, прежнее — на его место в списке.
	profile.armorItems[index] = equippedOf(profile)
	profile.armorEquipped[SLOT] = item
	profile.newArmor = math.max((profile.newArmor or 0) - 1, 0)
	apply(player)
	DebugState.set("Armor", "Equipped", item.name)

	local notify = Net.get("Notify")
	local set = Armor.Sets[item.setId]
	if notify and set and set.passive then
		notify:FireClient(player, { kind = "armorSet", text = ("%s: %s"):format(set.passive.name, set.passive.description), rarity = set.rarity })
	end
	return { ok = true }
end

local function onFloor(player): boolean
	return player:GetAttribute("Zone") == "Floor"
end

-- ★ комплекта у кузнеца: эхо (повторки) + материал этажа комплекта.
function ArmorService.requestUpgrade(player, key)
	if onFloor(player) then
		return { ok = false, reason = "floor" }
	end
	local profile = profileOf(player)
	local item = byKey(profile, key)
	if not item then
		return { ok = false, reason = "bad-request" }
	end
	normalize(item)
	local cost = ArmorService.cost(item)
	if not cost then
		return { ok = false, reason = "max" }
	end
	if item.echoes < cost.echoes then
		return { ok = false, reason = "echo", need = cost.echoes - item.echoes }
	end
	local have = profile.materials and profile.materials[cost.materialId] or 0
	if have < cost.materials then
		return { ok = false, reason = "material", need = cost.materials - have, materialName = cost.materialName }
	end
	if (cost.gold or 0) > 0 and (profile.gold or 0) < cost.gold then
		return { ok = false, reason = "gold", need = cost.gold }
	end
	if not DataService.spendMaterial(player, cost.materialId, cost.materials) then
		return { ok = false, reason = "material", need = cost.materials, materialName = cost.materialName }
	end
	if (cost.gold or 0) > 0 then
		DataService.spendGold(player, cost.gold)
	end
	local before = item.level
	item.echoes -= cost.echoes
	item.level += 1
	apply(player)
	return { ok = true, levelBefore = before, levelAfter = item.level, kind = "armor" }
end

-- Сменили класс (выбор класса, debug setclass): переодеть и пересчитать.
function ArmorService.onClassChanged(player)
	ArmorService.ensureProfile(DataService.get(player))
	apply(player)
end

-- Пассивка «regen»: через delay с без урона — percent макс. здоровья в секунду.
local REGEN_TICK = 0.5
local function regenTick()
	local t = now()
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("ArmorPassive") ~= "" and player:GetAttribute("ProfileVersion") then
			local ok, profile = pcall(DataService.get, player)
			local passive = ok and profile and wears(profile) and passiveOf(profile) or nil
			if passive and passive.kind == "regen" then
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth
					and t - (lastHit[player] or -math.huge) >= (passive.delay or 4) then
					humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * (passive.percent or 0.01) * REGEN_TICK)
				end
			end
		end
	end
end

function ArmorService.start()
	Net.ensureAll()

	-- Бой: плоские бонусы и снижение урона.
	CombatService.hooks.gearStats = ArmorService.gearStats
	CombatService.hooks.gearReduction = ArmorService.reduction
	-- Облик при каждом спавне — по надетой броне.
	AppearanceService.lookProvider = ArmorService.look

	local function hook(player)
		local waited = 0
		while not player:GetAttribute("ProfileVersion") and waited < 60 and player.Parent do
			waited += task.wait(0.1)
		end
		if not player.Parent then
			return
		end
		-- Время парирования и урона для пассивок (атрибуты публикует CombatService).
		player:GetAttributeChangedSignal("ParrySuccesses"):Connect(function()
			lastParry[player] = now()
		end)
		local lastTaken = player:GetAttribute("DamageTaken") or 0
		player:GetAttributeChangedSignal("DamageTaken"):Connect(function()
			local taken = player:GetAttribute("DamageTaken") or 0
			if taken > lastTaken then
				lastHit[player] = now()
			end
			lastTaken = taken
		end)
		apply(player)
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(hook, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(hook, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastParry[player] = nil
		lastHit[player] = nil
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= REGEN_TICK then
			acc -= REGEN_TICK
			regenTick()
		end
	end)

	UiNet.ensure("RequestEquipArmor").OnServerInvoke = RemoteGuard.wrap("RequestEquipArmor", ArmorService.requestEquip)
	UiNet.ensure("RequestArmorUpgrade").OnServerInvoke = RemoteGuard.wrap("RequestArmorUpgrade", ArmorService.requestUpgrade)

	-- Только Studio: выдать броню. Command Bar в Play (сервер):
	--   game.ServerStorage.KlinokDebug.GiveArmor:Invoke(nil, "gatekeeper")     -- комплект (надеть)
	--   game.ServerStorage.KlinokDebug.GiveArmor:Invoke(nil, "rose_warden", 3) -- +3 повторки (эхо)
	if RunService:IsStudio() then
		local ServerStorage = game:GetService("ServerStorage")
		local debugFolder = ServerStorage:FindFirstChild("KlinokDebug") or Instance.new("Folder")
		debugFolder.Name = "KlinokDebug"
		debugFolder.Parent = ServerStorage
		local give = debugFolder:FindFirstChild("GiveArmor") or Instance.new("BindableFunction")
		give.Name = "GiveArmor"
		give.Parent = debugFolder
		give.OnInvoke = function(playerName, id, copies)
			local player = playerName and Players:FindFirstChild(playerName) or Players:GetPlayers()[1]
			if not player then
				return "нет игрока"
			end
			local setId = Armor.parse(id)
			if not setId then
				return "нет брони: " .. tostring(id)
			end
			local profile = profileOf(player)
			local first, isEcho = ArmorService.give(player, Armor.newItem(setId, nil, "debug"))
			for _ = 2, math.max(tonumber(copies) or 1, 1) do
				ArmorService.give(player, Armor.newItem(setId, nil, "debug"))
			end
			if not isEcho then
				for index, item in ipairs(profile.armorItems) do
					if item == first then
						ArmorService.requestEquip(player, "a" .. index)
						break
					end
				end
			end
			apply(player)
			return ("%s: %s, ★%d, эхо %d"):format(isEcho and "повторка" or "надето", first.name, first.level, first.echoes)
		end

		-- Витрина: манекены R15 перед игроком, по комплекту на каждого.
		--   game.ServerStorage.KlinokDebug.PreviewArmor:Invoke()          -- воин, все этажи
		--   game.ServerStorage.KlinokDebug.PreviewArmor:Invoke("mage")    -- маг
		--   game.ServerStorage.KlinokDebug.PreviewArmor:Invoke("warrior", 3) -- только этаж 3
		--   game.ServerStorage.KlinokDebug.PreviewArmor:Invoke("clear")   -- убрать
		local preview = debugFolder:FindFirstChild("PreviewArmor") or Instance.new("BindableFunction")
		preview.Name = "PreviewArmor"
		preview.Parent = debugFolder
		preview.OnInvoke = function(mode, floorFilter)
			local old = workspace:FindFirstChild("KlinokArmorPreview")
			if old then
				old:Destroy()
			end
			if mode == "clear" then
				return "витрина убрана"
			end
			local player = Players:GetPlayers()[1]
			local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local origin = root and root.CFrame or CFrame.new(0, 5, 0)
			local folder = Instance.new("Folder")
			folder.Name = "KlinokArmorPreview"
			folder.Parent = workspace
			local order = Armor.SetOrderByClass[mode == "mage" and "mage" or "warrior"]
			local shown = 0
			for _, setId in ipairs(order) do
				local set = Armor.Sets[setId]
				if set and (not floorFilter or (set.floor or 1) == tonumber(floorFilter)) then
					local ok, dummy = pcall(function()
						return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
					end)
					if ok and dummy then
						dummy.Name = "Preview_" .. setId
						local hum = dummy:FindFirstChildOfClass("Humanoid")
						if hum then
							hum.DisplayName = set.title or set.name or setId
							hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
						end
						local col, row = shown % 5, math.floor(shown / 5)
						local spot = origin * CFrame.new((col - 2) * 4.5, 0, -10 - row * 7) * CFrame.Angles(0, math.pi, 0)
						dummy:PivotTo(spot)
						dummy.HumanoidRootPart.Anchored = true
						dummy.Parent = folder
						AppearanceService.refresh(dummy, { helm = setId, armor = setId })
						shown += 1
					end
				end
			end
			return "витрина: " .. shown .. " манекенов"
		end
	end

	print("[ArmorService] броня-комплекты воина и мага, этажи 1–5")
end

return ArmorService
