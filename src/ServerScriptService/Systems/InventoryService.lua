--!nonstrict
-- InventoryService (сервер)
-- Сумка героя и окно «Книга героя»: припасы стопками (profile.bag),
-- аксессуары в слотах «Амулет» и «Кольцо», быстрый предмет (клавиша G),
-- добыча из сундуков сверх оружия и брони, сводка характеристик.
--
-- Профиль (поля добавляются лениво — версию DataService не трогаем):
--   bag = { [itemId] = число }, quickItem = itemId | nil,
--   accessories = { { uid, id } ... }, accessoryEquipped = { amulet = uid, ring = uid },
--   accessorySeq = последний выданный uid.
--
-- В бой аксессуары попадают через CombatService.hooks: gearStats оборачиваем
-- (здоровье и броня складываются с бронёй ArmorService), damageBonus читает
-- MeleeService. Клиент ничего не решает: только просит действие по id.
--
-- Ремоуты (папка KlinokUiNet): GetCharacter, UseBagItem, EquipAccessory,
-- UnequipAccessory, SalvageAccessory, SetQuickItem; событие BagChanged.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteGuard = require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("RemoteGuard"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Classes = require(Shared.Config.Classes)
local Combat = require(Shared.Config.Combat)
local Progression = require(Shared.Config.Progression)
local Quests = require(Shared.Config.Quests)
local UiNet = require(Shared.Net.UiNet)
local DebugState = require(Shared.Net.DebugState)

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)
local TalentMods = require(script.Parent.TalentMods)
local FloorBoonState = require(script.Parent.FloorBoonState)

local InventoryService = {}

-- Готовые классы (остальные в окне «Герой» видны, но закрыты).
InventoryService.ReadyClasses = { warrior = true }
InventoryService.ClassBlurb = {
	warrior = "Щит долины. Много здоровья и брони, держит удар и отвечает контрударом.",
	assassin = "Тень за спиной. Быстрые удары, два рывка, хрупкое тело.",
	mage = "Память, ставшая огнём. Сильные заклинания и запас маны.",
}

local CATEGORY_ORDER = {}
for index, category in ipairs(Items.Categories) do
	CATEGORY_ORDER[category.id] = index
end
local RARITY_ORDER = { secret = 7, mythic = 6, legendary = 5, epic = 4, rare = 3, common = 1 }

local states = {} -- [player] = { cd = { [group] = until }, buff = { damage, untilT }, regenToken, lastCall }
local bagChanged: RemoteEvent? = nil

local function now(): number
	return os.clock()
end

local function stateOf(player)
	local state = states[player]
	if not state then
		state = { cd = {}, buff = nil, regenToken = 0, lastCall = 0 }
		states[player] = state
	end
	return state
end

local function lazy(name: string)
	local ok, module = pcall(require, script.Parent[name])
	if ok then
		return module
	end
	return nil
end

-- ===== профиль =====

function InventoryService.ensureProfile(profile)
	if type(profile.bag) ~= "table" then
		profile.bag = {}
		for id, count in pairs(Items.StarterBag) do
			profile.bag[id] = count
		end
		profile.quickItem = Items.StarterQuick
	end
	profile.accessories = type(profile.accessories) == "table" and profile.accessories or {}
	profile.accessoryEquipped = type(profile.accessoryEquipped) == "table" and profile.accessoryEquipped or {}
	local seq = 0
	for _, entry in ipairs(profile.accessories) do
		seq = math.max(seq, entry.uid or 0)
	end
	profile.accessorySeq = math.max(profile.accessorySeq or 0, seq)
	-- Снятые с продажи/переименованные предметы не ломают сумку.
	for id, count in pairs(profile.bag) do
		if not Items.List[id] or type(count) ~= "number" or count <= 0 then
			profile.bag[id] = nil
		end
	end
	for slot, uid in pairs(profile.accessoryEquipped) do
		local found = false
		for _, entry in ipairs(profile.accessories) do
			if entry.uid == uid and Items.Accessories[entry.id] and Items.Accessories[entry.id].slot == slot then
				found = true
			end
		end
		if not found then
			profile.accessoryEquipped[slot] = nil
		end
	end
	return profile
end

local function profileOf(player)
	return InventoryService.ensureProfile(DataService.get(player))
end

local function accessoryByUid(profile, uid)
	for index, entry in ipairs(profile.accessories) do
		if entry.uid == uid then
			return entry, index
		end
	end
	return nil
end

local function quickCount(profile): number
	return profile.quickItem and (profile.bag[profile.quickItem] or 0) or 0
end

local function publish(player)
	local profile = profileOf(player)
	local quick = profile.quickItem and Items.List[profile.quickItem]
	player:SetAttribute("QuickItem", quick and profile.quickItem or "")
	player:SetAttribute("QuickItemName", quick and quick.name or "")
	player:SetAttribute("QuickItemIcon", quick and quick.icon or "")
	player:SetAttribute("QuickItemCount", quickCount(profile))
	local kinds = 0
	for _ in pairs(profile.bag) do
		kinds += 1
	end
	player:SetAttribute("BagKinds", kinds)
	player:SetAttribute("AccessoryCount", #profile.accessories)
	local amulet = profile.accessoryEquipped.amulet and accessoryByUid(profile, profile.accessoryEquipped.amulet)
	local ring = profile.accessoryEquipped.ring and accessoryByUid(profile, profile.accessoryEquipped.ring)
	player:SetAttribute("AccessoryAmulet", amulet and amulet.id or "")
	player:SetAttribute("AccessoryRing", ring and ring.id or "")
	DebugState.set("Bag", "Kinds", kinds)
end

local function fireChanged(player, payload)
	if bagChanged then
		bagChanged:FireClient(player, payload)
	end
end

-- Здоровье и скорость пересчитывает прогресс (доля HP сохраняется).
local function reapply(player)
	local ProgressionService = lazy("ProgressionService")
	if ProgressionService and ProgressionService.applyLevel then
		pcall(ProgressionService.applyLevel, player)
	end
end

-- ===== выдача =====

-- Положить припас/ценное (или материал) в сумку. → новое количество.
function InventoryService.addItem(player, id: string, count: number?, silent: boolean?)
	local item = Items.List[id]
	if not item then
		return 0
	end
	count = math.max(1, math.floor(count or 1))
	local profile = profileOf(player)
	local total
	if item.category == "materials" then
		total = DataService.addMaterial(player, id, count)
	else
		total = math.min((profile.bag[id] or 0) + count, Items.MaxStack)
		profile.bag[id] = total
		if not profile.quickItem and item.use and item.category == "consumables" then
			profile.quickItem = id
		end
	end
	publish(player)
	if not silent then
		fireChanged(player, { added = { { id = id, name = item.name, icon = item.icon, rarityId = item.rarityId, count = count } } })
	end
	return total
end

function InventoryService.removeItem(player, id: string, count: number?): boolean
	local profile = profileOf(player)
	local have = profile.bag[id] or 0
	count = count or 1
	if have < count then
		return false
	end
	profile.bag[id] = have - count > 0 and have - count or nil
	publish(player)
	return true
end

function InventoryService.addAccessory(player, id: string, silent: boolean?)
	local template = Items.Accessories[id]
	if not template then
		return nil
	end
	local profile = profileOf(player)
	profile.accessorySeq += 1
	local entry = { uid = profile.accessorySeq, id = id }
	table.insert(profile.accessories, entry)
	-- Пустой слот надеваем сразу: так находку видно в бою.
	local autoEquip = profile.accessoryEquipped[template.slot] == nil
	if autoEquip then
		profile.accessoryEquipped[template.slot] = entry.uid
		reapply(player)
	end
	publish(player)
	if not silent then
		fireChanged(player, { added = { { id = id, name = template.name, icon = template.icon, rarityId = template.rarityId, count = 1, accessory = true, equipped = autoEquip } } })
	end
	return entry
end

-- ===== бой: статы аксессуаров и бафы =====

function InventoryService.accessoryStats(player)
	local total = { health = 0, armor = 0, damage = 0 }
	local profile = DataService.get(player)
	if not profile or type(profile.accessoryEquipped) ~= "table" or type(profile.accessories) ~= "table" then
		return total
	end
	for _, uid in pairs(profile.accessoryEquipped) do
		local entry = accessoryByUid(profile, uid)
		local template = entry and Items.Accessories[entry.id]
		if template then
			total.health += template.stats.health or 0
			total.armor += template.stats.armor or 0
			total.damage += template.stats.damage or 0
		end
	end
	return total
end

-- Доля к урону ближнего боя: аксессуары + леденец.
function InventoryService.damageBonus(player): number
	local bonus = InventoryService.accessoryStats(player).damage
	local state = states[player]
	if state and state.buff and now() < state.buff.untilT then
		bonus += state.buff.amount
	end
	return bonus
end

-- ===== использование =====

local function cooldownLeft(state, group: string?): number
	if not group then
		return 0
	end
	return math.max(0, (state.cd[group] or 0) - now())
end

local function humanoidOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function startRegen(player, state, humanoid, percent: number, seconds: number)
	state.regenToken += 1
	local token = state.regenToken
	local ticks = math.max(1, math.floor(seconds / 0.5))
	local perTick = humanoid.MaxHealth * percent / ticks
	player:SetAttribute("RegenUntil", workspace:GetServerTimeNow() + seconds)
	task.spawn(function()
		for _ = 1, ticks do
			task.wait(0.5)
			if state.regenToken ~= token or humanoid.Health <= 0 or not humanoid.Parent then
				return
			end
			humanoid.Health = math.min(humanoid.Health + perTick, humanoid.MaxHealth)
		end
	end)
end

-- → { ok, count, text } | { ok = false, reason, left? }
function InventoryService.use(player, id: string)
	local item = Items.List[id]
	if not item or not item.use then
		return { ok = false, reason = "bad-request" }
	end
	local profile = profileOf(player)
	if (profile.bag[id] or 0) <= 0 then
		return { ok = false, reason = "empty" }
	end
	local state = stateOf(player)
	local left = cooldownLeft(state, item.group)
	if left > 0 then
		return { ok = false, reason = "cooldown", left = left }
	end
	local use = item.use
	local humanoid = humanoidOf(player)
	if use.kind ~= "xp" and not humanoid then
		return { ok = false, reason = "dead" }
	end
	local text
	if use.kind == "heal" then
		if humanoid.Health >= humanoid.MaxHealth then
			return { ok = false, reason = "full" }
		end
		local amount = humanoid.MaxHealth * use.percent
		humanoid.Health = math.min(humanoid.Health + amount, humanoid.MaxHealth)
		text = ("+%d здоровья"):format(math.floor(amount + 0.5))
	elseif use.kind == "regen" then
		if humanoid.Health >= humanoid.MaxHealth then
			return { ok = false, reason = "full" }
		end
		startRegen(player, state, humanoid, use.percent, use.seconds)
		text = ("Лечение %d с"):format(use.seconds)
	elseif use.kind == "charge" then
		local charges = player:GetAttribute("HealCharges") or 0
		if charges >= Combat.Heal.charges then
			return { ok = false, reason = "charges-full" }
		end
		player:SetAttribute("HealCharges", math.min(charges + (use.amount or 1), Combat.Heal.charges))
		text = "+1 заряд лечения"
	elseif use.kind == "armor" then
		CombatService.addTemporaryArmor(player, use.amount, use.seconds)
		text = ("+%d брони на %d с"):format(use.amount, use.seconds)
	elseif use.kind == "damage" then
		state.buff = { amount = use.amount, untilT = now() + use.seconds }
		player:SetAttribute("BuffDamage", use.amount)
		player:SetAttribute("BuffDamageUntil", workspace:GetServerTimeNow() + use.seconds)
		text = ("+%d%% урона на %d с"):format(math.floor(use.amount * 100 + 0.5), use.seconds)
	elseif use.kind == "xp" then
		local ProgressionService = lazy("ProgressionService")
		if not ProgressionService or not ProgressionService.addXp then
			return { ok = false, reason = "bad-request" }
		end
		ProgressionService.addXp(player, use.amount)
		text = ("+%d опыта"):format(use.amount)
	else
		return { ok = false, reason = "bad-request" }
	end
	if item.group then
		state.cd[item.group] = now() + (Items.Cooldowns[item.group] or 1)
		player:SetAttribute("ItemCooldown_" .. item.group, workspace:GetServerTimeNow() + (Items.Cooldowns[item.group] or 1))
	end
	InventoryService.removeItem(player, id, 1)
	DebugState.bump("Bag", "Used_" .. id)
	local count = profile.bag[id] or 0
	fireChanged(player, { used = { id = id, name = item.name, icon = item.icon, text = text, count = count } })
	return { ok = true, count = count, text = text, cooldown = Items.Cooldowns[item.group] or 0 }
end

-- Быстрый предмет (клавиша G / кнопка на HUD).
function InventoryService.useQuick(player)
	local profile = profileOf(player)
	if not profile.quickItem then
		return { ok = false, reason = "no-quick" }
	end
	return InventoryService.use(player, profile.quickItem)
end

function InventoryService.setQuick(player, id: string?)
	local profile = profileOf(player)
	if id == nil or id == "" then
		profile.quickItem = nil
	else
		local item = Items.List[id]
		if not item or not item.use or item.category ~= "consumables" then
			return { ok = false, reason = "bad-request" }
		end
		profile.quickItem = id
	end
	publish(player)
	return { ok = true, quickItem = profile.quickItem }
end

-- ===== аксессуары =====

function InventoryService.equipAccessory(player, uid: number)
	local profile = profileOf(player)
	local entry = accessoryByUid(profile, uid)
	local template = entry and Items.Accessories[entry.id]
	if not template then
		return { ok = false, reason = "bad-request" }
	end
	profile.accessoryEquipped[template.slot] = uid
	reapply(player)
	publish(player)
	return { ok = true, slot = template.slot }
end

function InventoryService.unequipAccessory(player, slot: string)
	local profile = profileOf(player)
	if slot ~= "amulet" and slot ~= "ring" then
		return { ok = false, reason = "bad-request" }
	end
	profile.accessoryEquipped[slot] = nil
	reapply(player)
	publish(player)
	return { ok = true }
end

function InventoryService.salvageAccessory(player, uid: number)
	local profile = profileOf(player)
	local entry, index = accessoryByUid(profile, uid)
	local template = entry and Items.Accessories[entry.id]
	if not template then
		return { ok = false, reason = "bad-request" }
	end
	for _, equippedUid in pairs(profile.accessoryEquipped) do
		if equippedUid == uid then
			return { ok = false, reason = "equipped" }
		end
	end
	table.remove(profile.accessories, index)
	local dust = Items.SalvageDust[template.rarityId] or 1
	profile.echoDust = (profile.echoDust or 0) + dust
	player:SetAttribute("EchoDust", profile.echoDust)
	publish(player)
	return { ok = true, dust = dust }
end

-- ===== сундуки =====

-- Припасы и (иногда) аксессуар сверх оружия и брони. → список находок.
function InventoryService.rollChest(player, floorId: number?, isBoss: boolean?, rng)
	rng = rng or Random.new()
	local cfg = Items.Chest
	local range = isBoss and cfg.bossRolls or cfg.rolls
	local drops = {}
	for _ = 1, rng:NextInteger(range[1], range[2]) do
		local entry = Items.pick(cfg.table, rng)
		local count = rng:NextInteger(entry.count[1], entry.count[2])
		local item = Items.List[entry.id]
		InventoryService.addItem(player, entry.id, count, true)
		table.insert(drops, { id = entry.id, name = item.name, icon = item.icon, rarityId = item.rarityId, count = count })
	end
	if rng:NextNumber() < (isBoss and cfg.bossAccessoryChance or cfg.accessoryChance) then
		local id = Items.rollAccessory(floorId, rng)
		local template = Items.Accessories[id]
		local entry = InventoryService.addAccessory(player, id, true)
		if entry then
			local profile = profileOf(player)
			table.insert(drops, { id = id, name = template.name, icon = template.icon, rarityId = template.rarityId, count = 1,
				accessory = true, equipped = profile.accessoryEquipped[template.slot] == entry.uid })
		end
	end
	if #drops > 0 then
		fireChanged(player, { added = drops, source = "chest" })
	end
	return drops
end

-- ===== окно «Книга героя» =====

local function describeAccessory(entry, equippedUids)
	local template = Items.Accessories[entry.id]
	local equipped = false
	for _, uid in pairs(equippedUids) do
		if uid == entry.uid then
			equipped = true
		end
	end
	local slotName = template.slot == "amulet" and "Амулет" or "Кольцо"
	return {
		key = "c" .. entry.uid,
		uid = entry.uid,
		id = entry.id,
		kind = "accessory",
		name = template.name,
		slot = template.slot,
		slotName = slotName,
		rarityId = template.rarityId,
		icon = template.icon,
		stats = template.stats,
		statsText = Items.statsText(template.stats),
		desc = template.desc,
		equipped = equipped,
		salvage = Items.SalvageDust[template.rarityId] or 1,
	}
end

local function bagPayload(player, profile)
	local list = {}
	local state = stateOf(player)
	for id, count in pairs(profile.bag) do
		local item = Items.List[id]
		if item and count > 0 then
			table.insert(list, {
				key = "b" .. id,
				id = id,
				kind = "bag",
				name = item.name,
				category = item.category,
				icon = item.icon,
				rarityId = item.rarityId,
				count = count,
				desc = item.desc,
				useText = Items.useText(item.use),
				usable = item.use ~= nil,
				quick = profile.quickItem == id,
				canQuick = item.use ~= nil and item.category == "consumables",
				group = item.group,
				cooldown = cooldownLeft(state, item.group),
			})
		end
	end
	for id, count in pairs(profile.materials or {}) do
		if type(count) == "number" and count > 0 then
			local item = Items.List[id]
			table.insert(list, {
				key = "m" .. id,
				id = id,
				kind = "material",
				name = item and item.name or id,
				category = "materials",
				icon = item and item.icon or "it_star",
				rarityId = item and item.rarityId or "common",
				count = count,
				desc = item and item.desc or "Материал. Пригодится в долине.",
			})
		end
	end
	table.sort(list, function(a, b)
		local ca, cb = CATEGORY_ORDER[a.category] or 99, CATEGORY_ORDER[b.category] or 99
		if ca ~= cb then
			return ca < cb
		end
		local ra, rb = RARITY_ORDER[a.rarityId] or 0, RARITY_ORDER[b.rarityId] or 0
		if ra ~= rb then
			return ra > rb
		end
		return a.name < b.name
	end)
	return list
end

local function heroPayload(player, profile, gear)
	local className = profile.className or Classes.default()
	local level = profile.level or 1
	local base = Classes.statsAtLevel(className, level) or Classes.statsAtLevel(Classes.default(), level)
	local stats = CombatService.getStats(player)
	local acc = InventoryService.accessoryStats(player)
	local capBonus = FloorBoonState.soulCapBonus(player)
	local stacks = Progression.stackBonuses(profile.soulStacks or 0, capBonus)
	stacks.damage *= FloorBoonState.soulDamageMult(player)
	local humanoid = humanoidOf(player)
	local setReduction = 0
	local ArmorService = lazy("ArmorService")
	if ArmorService and ArmorService.reduction then
		local ok, value = pcall(ArmorService.reduction, player, humanoid)
		if ok and type(value) == "number" then
			setReduction = value
		end
	end
	local armorReduction = Combat.Armor.reduction(stats.armor)
	local equipped = gear and gear.equipped
	local buff = 0
	local state = states[player]
	if state and state.buff and now() < state.buff.untilT then
		buff = state.buff.amount
	end
	local pct = function(v)
		return ("%d%%"):format(math.floor(v * 100 + 0.5))
	end
	local rows = {
		{ id = "health", label = "Здоровье", value = tostring(math.floor(stats.maxHealth + 0.5)),
			hint = ("класс %d · снаряжение +%d%s"):format(math.floor(base.maxHealth + 0.5), math.floor((stats.gearHealth or 0) + 0.5),
				(stats.talentHealth or 0) > 0.5 and (" · древо +%d"):format(math.floor(stats.talentHealth + 0.5)) or "") },
		{ id = "armor", label = "Броня", value = tostring(math.floor(stats.armor + 0.5)),
			hint = ("гасит %s урона%s"):format(pct(armorReduction),
				(stats.talentArmor or 0) > 0 and (" · древо +%d"):format(stats.talentArmor) or "") },
		{ id = "reduction", label = "Снижение урона", value = pct(setReduction), hint = "от редкости и ★ брони" },
		{ id = "damage", label = "Урон оружия", value = tostring(equipped and equipped.damage or math.floor(stats.weaponDamage)),
			hint = equipped and equipped.name or "" },
		{ id = "crit", label = "Крит", value = ("%d%%"):format(equipped and equipped.crit or 0), hint = "шанс сильного удара" },
		{ id = "bonus", label = "Бонус урона", value = "+" .. pct(acc.damage + buff + stacks.damage),
			hint = ("аксессуары %s · души %s%s"):format(pct(acc.damage), pct(stacks.damage), buff > 0 and (" · леденец " .. pct(buff)) or "") },
		{ id = "speed", label = "Скорость атаки", value = ("×%.2f"):format(stats.attackSpeed + stacks.attackSpeed), hint = "класс, древо и стаки душ" },
		{ id = "walk", label = "Скорость бега", value = tostring(math.floor(stats.walkSpeed + 0.5)), hint = "" },
		{ id = "dodge", label = "Рывки", value = tostring(stats.dodgeCharges), hint = "Q / Shift" },
		{ id = "parry", label = "Окно парирования", value = ("%.2f с"):format(stats.parryWindow), hint = "ПКМ" },
		{ id = "heal", label = "Лечение", value = ("%d/%d"):format(player:GetAttribute("HealCharges") or 0, Combat.Heal.charges),
			hint = ("заряд — %s здоровья (F)"):format(pct(TalentMods.healPct(player, Combat.Heal.percentOfMaxHealth))) },
		{ id = "stacks", label = "Стаки душ", value = ("%d/%d"):format(profile.soulStacks or 0, Progression.maxStacks(capBonus)),
			hint = "сгорают при смерти" },
	}
	-- Маг: мана (класс + шляпа и накидка + посох) и её восстановление.
	local ManaService = lazy("ManaService")
	if ManaService and ManaService.compute then
		local ok, maxMana, regen, parts = pcall(ManaService.compute, player)
		if ok and maxMana > 0 then
			table.insert(rows, 2, { id = "mana", label = "Мана", value = tostring(maxMana),
				hint = ("класс %d · снаряжение +%d · посох +%d%s"):format(parts.classMana or 0, parts.gearMana or 0, parts.weaponMana or 0,
					(maxMana > (parts.classMana or 0) + (parts.gearMana or 0) + (parts.weaponMana or 0)) and " · древо" or "") })
			table.insert(rows, 3, { id = "manaRegen", label = "Восстановление маны", value = ("%.1f/с"):format(regen),
				hint = "вне боя ×2 · удары посохом ману не тратят" })
		end
	end
	local classes = {}
	-- Скрытые на бете классы (ассасин) в окне не показываем.
	for _, id in ipairs(Classes.visible()) do
		local data = Classes.data[id]
		local s = Classes.statsAtLevel(id, level)
		table.insert(classes, {
			id = id,
			name = data.name,
			ready = InventoryService.ReadyClasses[id] == true,
			current = id == className,
			blurb = InventoryService.ClassBlurb[id] or "",
			health = math.floor(s.maxHealth + 0.5),
			armor = math.floor(s.armor + 0.5),
			weaponDamage = math.floor(s.weaponDamage + 0.5),
			attackSpeed = s.attackSpeed,
			walkSpeed = s.walkSpeed,
			dodgeCharges = s.dodgeCharges,
			mana = s.maxMana,
		})
	end
	local cleared = 0
	for _, clears in pairs(profile.floorClears or {}) do
		if type(clears) == "table" and next(clears) ~= nil then
			cleared += 1
		end
	end
	local counters = profile.stats or {}
	return {
		classId = className,
		className = base.name,
		level = level,
		maxLevel = Classes.MaxLevel,
		xp = profile.xp or 0,
		xpNext = Progression.xpToNext(level),
		rows = rows,
		classes = classes,
		chronicle = {
			{ label = "Врагов повержено", value = counters.enemiesKilled or 0, icon = "hlCross" },
			{ label = "Боссов повержено", value = profile.bossKills or 0, icon = "it_soul" },
			{ label = "Сундуков открыто", value = counters.chestsOpened or 0, icon = "it_coinStack" },
			{ label = "Этажей пройдено", value = cleared, icon = "it_key" },
			{ label = "Уклонений", value = counters.dodges or 0, icon = "chevronL" },
			{ label = "Парирований", value = counters.parries or 0, icon = "icCheck" },
		},
	}
end

local function archivePayload(profile)
	-- какой квест даёт фрагмент: подпись для ещё не найденных страниц
	local sourceOf = {}
	for _, quest in ipairs(Quests.List) do
		local archiveId = quest.reward and quest.reward.archive
		if archiveId then
			sourceOf[archiveId] = (quest.title or "Задание") .. " · " .. (quest.chapter or "")
		end
	end
	local list = {}
	local owned = 0
	local ids = {}
	for id in pairs(Quests.ArchiveFragments) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local fragment = Quests.ArchiveFragments[id]
		local has = profile.archive and profile.archive[id] == true
		if has then
			owned += 1
		end
		table.insert(list, {
			id = id,
			title = fragment.title,
			text = has and fragment.text or nil,
			owned = has,
			source = sourceOf[id],
		})
	end
	return { fragments = list, owned = owned, total = #ids }
end

function InventoryService.characterState(player)
	local profile = profileOf(player)
	local gear
	local EchoService = lazy("EchoService")
	if EchoService and EchoService.gearState then
		local ok, result = pcall(EchoService.gearState, player)
		if ok then
			gear = result
		else
			warn("[InventoryService] gearState: " .. tostring(result))
		end
	end
	local accessories = {}
	for _, entry in ipairs(profile.accessories) do
		if Items.Accessories[entry.id] then
			table.insert(accessories, describeAccessory(entry, profile.accessoryEquipped))
		end
	end
	table.sort(accessories, function(a, b)
		if a.equipped ~= b.equipped then
			return a.equipped
		end
		local ra, rb = RARITY_ORDER[a.rarityId] or 0, RARITY_ORDER[b.rarityId] or 0
		if ra ~= rb then
			return ra > rb
		end
		return a.uid < b.uid
	end)
	local equippedAccessories = {}
	for _, item in ipairs(accessories) do
		if item.equipped then
			equippedAccessories[item.slot] = item
		end
	end
	-- Окно показывает броню 3D-манекенами (Lib/ItemView): модели комплектов собираются
	-- на сервере один раз и лежат в ReplicatedStorage.KlinokArmorPreviews.
	local ArmorPreviewService = lazy("ArmorPreviewService")
	if gear and ArmorPreviewService and ArmorPreviewService.ensure then
		for _, item in ipairs(gear.armorItems or {}) do
			pcall(ArmorPreviewService.ensure, item.setId)
		end
	end
	if gear then
		-- «Сила» с аксессуарами: те же веса, что у брони, урон — от оружия.
		local acc = InventoryService.accessoryStats(player)
		local weaponPower = gear.equipped and (gear.equipped.damage or 0) * 10 or 0
		gear.power = (gear.power or 0) + math.floor(acc.armor * 6 + acc.health * 0.5 + weaponPower * acc.damage + 0.5)
	end
	local state = stateOf(player)
	local cooldowns = {}
	for group in pairs(Items.Cooldowns) do
		cooldowns[group] = cooldownLeft(state, group)
	end
	-- Сундуки этажей v3 (ChestService): стопки для категории «Сундуки».
	local chests
	local ChestService = lazy("ChestService")
	if ChestService and ChestService.state then
		local ok, result = pcall(ChestService.state, player)
		if ok then
			chests = result
		else
			warn("[InventoryService] chests: " .. tostring(result))
		end
	end
	return {
		gear = gear,
		chests = chests,
		bag = bagPayload(player, profile),
		accessories = accessories,
		equippedAccessories = equippedAccessories,
		quickItem = profile.quickItem,
		cooldowns = cooldowns,
		hero = heroPayload(player, profile, gear),
		archive = archivePayload(profile),
	}
end

-- ===== запуск =====

local function guard(player): boolean
	local state = stateOf(player)
	local t = now()
	if t - state.lastCall < 0.15 then
		return false
	end
	state.lastCall = t
	return true
end

function InventoryService.start()
	-- Бой: аксессуары поверх брони ArmorService (её хук уже стоит).
	local baseGear = CombatService.hooks.gearStats
	CombatService.hooks.gearStats = function(player)
		local gear = { armor = 0, health = 0, mana = 0, manaRegen = 0 }
		if baseGear then
			local ok, result = pcall(baseGear, player)
			if ok and type(result) == "table" then
				gear = { armor = result.armor or 0, health = result.health or 0, mana = result.mana or 0, manaRegen = result.manaRegen or 0 }
			end
		end
		local acc = InventoryService.accessoryStats(player)
		gear.armor += acc.armor
		gear.health += acc.health
		return gear
	end
	CombatService.hooks.damageBonus = InventoryService.damageBonus

	bagChanged = UiNet.ensure("BagChanged", "RemoteEvent")
	UiNet.ensure("GetCharacter").OnServerInvoke = function(player)
		if not RemoteGuard.allow(player, "GetCharacter") then return RemoteGuard.BUSY end
		return InventoryService.characterState(player)
	end
	UiNet.ensure("UseBagItem").OnServerInvoke = function(player, id)
		if not RemoteGuard.allow(player, "UseBagItem", id) then return RemoteGuard.BUSY end
		if typeof(id) ~= "string" or not guard(player) then
			return { ok = false, reason = "bad-request" }
		end
		return InventoryService.use(player, id)
	end
	UiNet.ensure("UseQuickItem").OnServerInvoke = function(player)
		if not RemoteGuard.allow(player, "UseQuickItem") then return RemoteGuard.BUSY end
		if not guard(player) then
			return { ok = false, reason = "bad-request" }
		end
		return InventoryService.useQuick(player)
	end
	UiNet.ensure("SetQuickItem").OnServerInvoke = function(player, id)
		if not RemoteGuard.allow(player, "SetQuickItem", id) then return RemoteGuard.BUSY end
		if id ~= nil and typeof(id) ~= "string" then
			return { ok = false, reason = "bad-request" }
		end
		return InventoryService.setQuick(player, id)
	end
	UiNet.ensure("EquipAccessory").OnServerInvoke = function(player, uid)
		if not RemoteGuard.allow(player, "EquipAccessory", uid) then return RemoteGuard.BUSY end
		if typeof(uid) ~= "number" or not guard(player) then
			return { ok = false, reason = "bad-request" }
		end
		return InventoryService.equipAccessory(player, uid)
	end
	UiNet.ensure("UnequipAccessory").OnServerInvoke = function(player, slot)
		if not RemoteGuard.allow(player, "UnequipAccessory", slot) then return RemoteGuard.BUSY end
		if typeof(slot) ~= "string" or not guard(player) then
			return { ok = false, reason = "bad-request" }
		end
		return InventoryService.unequipAccessory(player, slot)
	end
	UiNet.ensure("SalvageAccessory").OnServerInvoke = function(player, uid)
		if not RemoteGuard.allow(player, "SalvageAccessory", uid) then return RemoteGuard.BUSY end
		if typeof(uid) ~= "number" or not guard(player) then
			return { ok = false, reason = "bad-request" }
		end
		return InventoryService.salvageAccessory(player, uid)
	end

	local function onPlayer(player)
		task.spawn(function()
			-- Публикуем после настоящей загрузки профиля (не заглушки).
			if not DataService.waitForProfile(player, 60) or not player.Parent then
				return
			end
			publish(player)
			-- Здоровье с аксессуарами — при каждом спавне (applyClass зовёт gearStats).
			player.CharacterAdded:Connect(function()
				local state = states[player]
				if state then
					state.regenToken += 1
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	print("[InventoryService] сумка, аксессуары и быстрый предмет готовы")
end

return InventoryService
