--!nonstrict
-- ChestPreview
-- Витрина лута сундука для Врат Печатей: что и с каким шансом может выпасть.
-- Чистая функция над теми же таблицами, что и сервер:
--   оружие   — Loot.chestWeights / Loot.chestPool (Loot.rollWeapon);
--   золото и материал — Loot.chestInfo (сундук своего этажа);
--   броня    — в каждом сундуке, Armor.rarityWeights / Armor.chestPool (ArmorService.rollChest);
--   припасы и аксессуары — Items.Chest (InventoryService.rollChest).
-- Ничего не бросает и не меняет. Сверка с Monte Carlo — tools/lua/test_worldmap.lua.

local Rarities = require(script.Parent.Rarities)
local Loot = require(script.Parent.Loot)
local Armor = require(script.Parent.Armor)
local Items = require(script.Parent.Items)

local ChestPreview = {}

local function rarityIndex(id)
	local r = Rarities.get(id)
	return r and r.index or 99
end

-- Доли редкостей броска: { {rarity, chance}, ... } по Rarities.order.
local function rarityShares(weights)
	local total = 0
	for _, id in ipairs(Rarities.order) do
		total += weights[id] or 0
	end
	local list = {}
	if total <= 0 then
		return { { rarity = "common", chance = 1 } }
	end
	for _, id in ipairs(Rarities.order) do
		local w = weights[id]
		if w and w > 0 then
			table.insert(list, { rarity = id, chance = w / total })
		end
	end
	return list
end

-- Сгруппировать предметы по их настоящей редкости (пул-подстраховка может
-- выдать обычное вместо отсутствующего редкого — витрина показывает правду).
local function groupByRarity(items)
	local groups, byId = {}, {}
	for _, it in ipairs(items) do
		local g = byId[it.rarity]
		if not g then
			g = { rarity = it.rarity, chance = 0, items = {} }
			byId[it.rarity] = g
			table.insert(groups, g)
		end
		g.chance += it.chance
		table.insert(g.items, it)
	end
	table.sort(groups, function(a, b)
		return rarityIndex(a.rarity) < rarityIndex(b.rarity)
	end)
	return groups
end

local function sortItems(items)
	table.sort(items, function(a, b)
		local ra, rb = rarityIndex(a.rarity), rarityIndex(b.rarity)
		if ra ~= rb then
			return ra < rb
		end
		return a.order < b.order
	end)
end

-- Оружие: { items = {{id, name, typeId, rarity, ability, passive, chance}}, groups, rarities }.
-- chestsOpened < Loot.Chest.firstChestsCommon → сервер даёт обычное: forced = true.
function ChestPreview.weapons(floor: number, grade: string?, className: string?, chestsOpened: number?)
	local forced = chestsOpened ~= nil and chestsOpened < Loot.Chest.firstChestsCommon
	local shares = forced and { { rarity = "common", chance = 1 } } or rarityShares(Loot.chestWeights(floor, className))
	-- Обычные сундуки этажей (ответвления, тайники, мини-боссы) гарантируют
	-- оружие не ниже редкого (Config.FloorN.Chests.minRarity): обычное → редкое.
	-- Шанс эпического у каждого сундука свой — витрина его не показывает.
	if not forced and grade ~= "gold" then
		local merged, byRarity = {}, {}
		for _, s in ipairs(shares) do
			local id = Rarities.atLeast(s.rarity, "rare") and s.rarity or "rare"
			if not byRarity[id] then
				byRarity[id] = { rarity = id, chance = 0 }
				table.insert(merged, byRarity[id])
			end
			byRarity[id].chance += s.chance
		end
		shares = merged
	end
	local byId, items = {}, {}
	local order = {}
	for i, w in ipairs(Loot.Weapons) do
		order[w.id] = i
	end
	for _, share in ipairs(shares) do
		local pool = Loot.chestPool(share.rarity, floor, className)
		for _, template in ipairs(pool) do
			local it = byId[template.id]
			if not it then
				it = {
					id = template.id,
					name = template.name,
					typeId = template.typeId,
					rarity = template.rarity,
					ability = template.ability,
					passive = template.passive,
					chance = 0,
					order = order[template.id] or 0,
				}
				byId[template.id] = it
				table.insert(items, it)
			end
			it.chance += share.chance / #pool
		end
	end
	sortItems(items)
	return { items = items, groups = groupByRarity(items), rarities = shares, forced = forced }
end

-- Золото и материал (одинаково для обычного и золотого сундука).
function ChestPreview.rewards(floor: number)
	local info = Loot.chestInfo(floor)
	local range = info.materialRange or Loot.Chest.iron
	return {
		gold = info.gold or Loot.Chest.gold,
		materialId = info.material,
		materialName = info.materialName,
		materialRange = { range[1], range[2] },
	}
end

-- Броня: nil, если класс брони не носит. Иначе { chance, items = {{id, setId, slot, name, setName, rarity, chance}}, groups }.
-- Комплект есть в каждом сундуке (chance = 1), редкость — свой бросок по весам
-- этажа без секретной (как ArmorService.rollChest), сундук босса — так же.
function ChestPreview.armor(floor: number, grade: string?, className: string?)
	if not Armor.canWear(className) then
		return nil
	end
	local weights = Armor.rarityWeights(Loot.chestWeights(floor, className))
	local shares = rarityShares(weights)
	local byId, items = {}, {}
	for _, share in ipairs(shares) do
		local pool = Armor.chestPool(share.rarity, floor, className)
		for i, pick in ipairs(pool) do
			local id = pick[1]
			local it = byId[id]
			if not it then
				local t = Armor.template(id)
				it = { id = id, setId = id, slot = Armor.Slot, name = t.name, setName = t.setName, rarity = t.rarity, chance = 0, order = #items + i }
				byId[id] = it
				table.insert(items, it)
			end
			it.chance += share.chance / #pool
		end
	end
	sortItems(items)
	return { chance = 1, items = items, groups = groupByRarity(items) }
end

-- Припасы и аксессуары.
-- supplies: стопок {a, b}; items = {{id, name, icon, rarity, count{a,b}, perStack, chance}},
--   chance — вероятность найти хотя бы одну такую стопку в сундуке.
-- accessories: { chance, items = {{id, name, icon, slot, rarity, chance}} } (chance — итоговый).
function ChestPreview.supplies(floor: number, grade: string?)
	local cfg = Items.Chest
	local isBoss = grade == "gold"
	local range = isBoss and cfg.bossRolls or cfg.rolls
	local total = 0
	for _, e in ipairs(cfg.table) do
		total += e.weight
	end
	local items = {}
	for i, e in ipairs(cfg.table) do
		local p = e.weight / total
		local atLeast = 0
		for n = range[1], range[2] do
			atLeast += 1 - (1 - p) ^ n
		end
		atLeast /= (range[2] - range[1] + 1)
		local item = Items.List[e.id]
		table.insert(items, {
			id = e.id,
			name = item and item.name or e.id,
			icon = item and item.icon,
			rarity = item and item.rarityId or "common",
			count = { e.count[1], e.count[2] },
			perStack = p,
			chance = atLeast,
			order = i,
		})
	end
	table.sort(items, function(a, b)
		return a.perStack > b.perStack or (a.perStack == b.perStack and a.order < b.order)
	end)
	local accChance = isBoss and cfg.bossAccessoryChance or cfg.accessoryChance
	local weights = cfg.accessoryRarity[math.clamp(floor or 1, 1, 5)]
	local wTotal = 0
	for _, w in pairs(weights) do
		wTotal += w
	end
	local accItems = {}
	local accById = {}
	local ids = {}
	for id in pairs(Items.Accessories) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for rarityId, w in pairs(weights) do
		local pool = {}
		for _, id in ipairs(ids) do
			if Items.Accessories[id].rarityId == rarityId then
				table.insert(pool, id)
			end
		end
		if #pool == 0 then
			pool = { "wanderer_charm" }
		end
		for _, id in ipairs(pool) do
			local acc = Items.Accessories[id]
			local it = accById[id]
			if not it then
				it = { id = id, name = acc.name, icon = acc.icon, slot = acc.slot, rarity = acc.rarityId, stats = acc.stats, desc = acc.desc, chance = 0, order = 0 }
				accById[id] = it
				table.insert(accItems, it)
			end
			it.chance += accChance * (w / wTotal) / #pool
		end
	end
	for i, it in ipairs(accItems) do
		it.order = i
	end
	sortItems(accItems)
	return {
		stacks = { range[1], range[2] },
		items = items,
		accessories = { chance = accChance, items = accItems, groups = groupByRarity(accItems) },
	}
end

-- Всё сразу для окна сундука.
function ChestPreview.get(floor: number, grade: string?, className: string?, chestsOpened: number?)
	local f = math.clamp(math.floor(tonumber(floor) or 1), 1, 5)
	local g = grade == "gold" and "gold" or "common"
	local c = className == "mage" and "mage" or "warrior"
	return {
		floor = f,
		grade = g,
		className = c,
		weapons = ChestPreview.weapons(f, g, c),
		firstCommonLeft = math.max(0, Loot.Chest.firstChestsCommon - (chestsOpened or Loot.Chest.firstChestsCommon)),
		rewards = ChestPreview.rewards(f),
		armor = ChestPreview.armor(f, g, c),
		supplies = ChestPreview.supplies(f, g),
	}
end

-- «12,5%» / «0,4%» / «<0,1%».
function ChestPreview.percent(p: number): string
	local v = (p or 0) * 100
	if v <= 0 then
		return "0%"
	elseif v < 0.1 then
		return "<0,1%"
	end
	local text
	if v >= 10 or math.abs(v - math.floor(v + 0.5)) < 0.05 then
		text = ("%d"):format(math.floor(v + 0.5))
	else
		text = ("%.1f"):format(v)
	end
	return (text:gsub("%.", ",")) .. "%"
end

return ChestPreview
