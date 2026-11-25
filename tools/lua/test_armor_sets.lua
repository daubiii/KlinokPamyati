--!nonstrict
-- test_armor_sets.lua — броня-комплекты и лут сундуков (06.11.2026):
--   * комплект — один предмет; старые id «<набор>_helm/_armor» читаются как набор;
--   * на каждом этаже 1–5 у воина и мага есть комплекты обычной…легендарной редкости;
--   * сундук: броня всегда, редкость — свой бросок без секретной;
--   * кузнец: таблица материалов на каждый шаг ★ до потолка редкости;
--   * сундуки этажей 3–5 дают свой материал и золото, гарантия редкости оружия.
--   LUAU=путь/к/luau node tools/run-luau.js tools/lua/test_armor_sets.lua

local Shared = (_G :: any).KlinokShared or game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Armor = require(Shared.Config.Armor)
local Echo = require(Shared.Config.Echo)
local Loot = require(Shared.Config.Loot)
local Rarities = require(Shared.Config.Rarities)
local Items = require(Shared.Config.Items)
local ChestPreview = require(Shared.Config.ChestPreview)

local out = {}
local failures = 0
local function check(label, ok, detail)
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %s%s"):format(ok and "OK  " or "FAIL", label, detail and (" — " .. tostring(detail)) or "")
end

-- Детерминированный Random для бросков.
local function rngOf(seed)
	local state = seed
	return {
		NextNumber = function()
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end,
		NextInteger = function(self, a, b)
			return a + math.floor(self:NextNumber() * (b - a + 1))
		end,
	}
end

local RAR = { "common", "rare", "epic", "legendary" }

-- 1. Комплекты
out[#out + 1] = "Комплекты:"
local count = 0
for setId, set in pairs(Armor.Sets) do
	count += 1
	local t = Armor.template(setId)
	if not (t and t.id == setId and t.slot == "set" and t.health > 0 and Rarities.get(t.rarity)) then
		check("шаблон " .. setId, false)
	end
	if Armor.NoRarity[set.rarity] then
		check("нет секретной брони: " .. setId, false, set.rarity)
	end
	local strong = Rarities.atLeast(set.rarity, "epic")
	if strong and not set.passive then
		check("пассивка у эпического/легендарного " .. setId, false)
	end
	if set.passive and not (set.passive.name and set.passive.description and set.passive.kind) then
		check("описание пассивки " .. setId, false)
	end
	if not Armor.Styles[setId] then
		check("облик-заглушка " .. setId, false)
	end
end
check("всего комплектов 42 (10 этажа 1 + 32 этажей 2–5)", count == 42, count)

for _, className in ipairs({ "warrior", "mage" }) do
	for floor = 1, 5 do
		local missing = {}
		for _, r in ipairs(RAR) do
			if #Armor.pool(r, floor, className) == 0 then
				table.insert(missing, r)
			end
		end
		check(("%s, этаж %d: все 4 редкости"):format(className, floor), #missing == 0, table.concat(missing, ","))
	end
	check(className .. ": стартовый не падает", (function()
		for _, r in ipairs(RAR) do
			for _, pick in ipairs(Armor.pool(r, 1, className)) do
				if pick[1] == Armor.starterFor(className) then
					return false
				end
			end
		end
		return true
	end)())
end

-- старые id
check("parse gate_guard_helm → gate_guard", Armor.parse("gate_guard_helm") == "gate_guard")
check("parse archivist_armor → archivist", Armor.parse("archivist_armor") == "archivist")
check("parse rose_warden → rose_warden", Armor.parse("rose_warden") == "rose_warden")
check("parse мусор → nil", Armor.parse("nope_helm") == nil)
check("классы не смешиваются", not Armor.canWear("mage", "rose_warden") and Armor.canWear("mage", "lotus") and not Armor.canWear("assassin"))

-- рост по этажам: та же редкость выше этажом — не слабее по броне и здоровью
for _, className in ipairs({ "warrior", "mage" }) do
	for _, r in ipairs(RAR) do
		local ok = true
		for floor = 2, 4 do
			local a = Armor.Sets[Armor.pool(r, floor, className)[1][1]]
			local b = Armor.Sets[Armor.pool(r, floor + 1, className)[1][1]]
			ok = ok and b.armor >= a.armor and b.health > a.health
		end
		check(("%s %s: растёт от этажа к этажу"):format(className, r), ok)
	end
end

-- 2. Бросок брони
out[#out + 1] = "Сундук:"
for floor = 1, 5 do
	local weights = Loot.chestWeights(floor, "warrior")
	local rng = rngOf(floor * 7919)
	local seen, secret = {}, 0
	for _ = 1, 4000 do
		local r = Armor.rollRarity(weights, rng, 10, 2)
		seen[r] = (seen[r] or 0) + 1
		if Armor.NoRarity[r] then
			secret += 1
		end
	end
	check(("этаж %d: без секретной, обычная и редкая падают"):format(floor), secret == 0 and (seen.common or 0) > 0 and (seen.rare or 0) > 0,
		("common %d rare %d epic %d leg %d"):format(seen.common or 0, seen.rare or 0, seen.epic or 0, seen.legendary or 0))
end
check("первые сундуки — обычная броня", Armor.rollRarity(Loot.chestWeights(5), rngOf(1), 0, 2) == "common")

for floor = 1, 5 do
	local preview = ChestPreview.armor(floor, "common", "warrior")
	local sum = 0
	for _, it in ipairs(preview.items) do
		sum += it.chance
	end
	check(("витрина брони этажа %d: сумма шансов = 1"):format(floor), math.abs(sum - 1) < 1e-6 and preview.chance == 1, sum)
end

-- 3. Кузнец
out[#out + 1] = "Кузнец:"
for _, r in ipairs(RAR) do
	local steps = Echo.maxLevel(r) - 1
	local row = Armor.MaterialCost[r]
	check(("%s: шагов ★ %d = строк таблицы"):format(r, steps), row and #row == steps, row and #row)
	local ok = true
	for i = 2, #row do
		ok = ok and row[i] > row[i - 1]
	end
	check(r .. ": цена растёт", ok)
	check(r .. ": на потолке цены нет", Armor.materialCost(Echo.maxLevel(r), r) == nil)
end
out[#out + 1] = ("  всего материала: обычный %d, редкий %d, эпический %d, легендарный %d"):format(
	Armor.totalMaterials("common", 5), Armor.totalMaterials("rare", 6), Armor.totalMaterials("epic", 7), Armor.totalMaterials("legendary", 8))

-- 4. Лут сундуков
out[#out + 1] = "Лут:"
local mats = {}
for floor = 1, 5 do
	local info = Loot.chestInfo(floor)
	mats[floor] = info.material
	check(("этаж %d: материал %s есть в Items"):format(floor, tostring(info.material)), Items.get and Items.get(info.material) ~= nil or Items.List[info.material] ~= nil)
	local roll = Loot.rollChest(10, rngOf(floor), floor, "warrior")
	check(("этаж %d: сундук даёт свой материал и золото"):format(floor),
		roll.materialId == info.material and roll.gold == info.gold and roll.materialCount >= info.materialRange[1] and roll.materialCount <= info.materialRange[2],
		("%s ×%d, %d зол."):format(roll.materialId, roll.materialCount, roll.gold))
end
check("материалы этажей разные", mats[1] ~= mats[2] and mats[3] ~= mats[4] and mats[4] ~= mats[5] and mats[2] ~= mats[3])

local tierRng = rngOf(99)
local low = 0
for _ = 1, 500 do
	local w = Loot.rollWeapon(10, tierRng, 1, "warrior", { minRarity = "rare", epicChance = 0.25 })
	if not Rarities.atLeast(w.rarityId, "rare") then
		low += 1
	end
end
check("гарантия сундука: оружие не ниже редкого", low == 0, low)
check("первые сундуки — без гарантии (обычное)", Loot.rollWeapon(0, rngOf(5), 1, "warrior", { minRarity = "rare" }).rarityId == "common")

-- 4б. Меши: у каждого комплекта есть данные мешей (шлем/шляпа и корпус) той же редкости
out[#out + 1] = "Меши:"
local HeroData = require(Shared.Config.HeroArmorMeshData)
local MageData = require(Shared.Config.MageArmorMeshData)
local FloorsData = require(Shared.Config.ArmorFloorsMeshData)
local noMesh = {}
for setId, set in pairs(Armor.Sets) do
	local mesh = HeroData.sets[setId] or MageData.sets[setId] or FloorsData.sets[setId]
	if not (mesh and #mesh.helm > 0 and #mesh.armor > 0 and mesh.rarity == set.rarity) then
		table.insert(noMesh, setId)
	elseif FloorsData.sets[setId] and (FloorsData.sets[setId].floor ~= set.floor or ((FloorsData.sets[setId].class or "warrior") ~= (set.class or "warrior"))) then
		table.insert(noMesh, setId .. "(этаж/класс)")
	end
end
check("у всех 42 комплектов есть меши с той же редкостью", #noMesh == 0, table.concat(noMesh, ","))
local dup = {}
for setId in pairs(FloorsData.sets) do
	if HeroData.sets[setId] or MageData.sets[setId] then
		table.insert(dup, setId)
	end
end
check("меши этажей 2–5 не пересекаются с этажом 1", #dup == 0, table.concat(dup, ","))

-- 5. Перевод старых профилей (ArmorMigrate)
out[#out + 1] = "Перевод профиля:"
local ArmorMigrate = require(Shared.Util.ArmorMigrate)
local old = {
	className = "warrior",
	armorEquipped = {
		helm = { kind = "armor", id = "gate_guard_helm", setId = "gate_guard", slot = "helm", rarityId = "rare", level = 3, echoes = 1 },
		armor = { kind = "armor", id = "shade_knight_armor", setId = "shade_knight", slot = "armor", rarityId = "epic", level = 2, echoes = 2 },
	},
	armorItems = {
		{ kind = "armor", id = "gate_guard_armor", setId = "gate_guard", slot = "armor", rarityId = "rare", level = 4, echoes = 0 },
		{ kind = "armor", id = "rusty_guard_helm", setId = "rusty_guard", slot = "helm", rarityId = "common", level = 1, echoes = 3 },
		{ kind = "armor", id = "rusty_guard_helm", setId = "rusty_guard", slot = "helm", rarityId = "common", level = 1, echoes = 0 },
	},
	armorStash = { mage = { helm = { id = "archivist_helm", level = 5, echoes = 0 }, armor = { id = "novice_armor", level = 1, echoes = 0 } } },
}
ArmorMigrate.run(old)
local worn = old.armorEquipped.set
check("надет набор доспеха (теневой рыцарь)", worn and worn.id == "shade_knight" and worn.level == 2 and old.armorEquipped.helm == nil, worn and worn.id)
local byId = {}
for _, it in ipairs(old.armorItems) do
	byId[it.id] = it
end
check("шлем+доспех стражи ворот слились: ★4, эхо 1", byId.gate_guard and byId.gate_guard.level == 4 and byId.gate_guard.echoes == 1)
check("два шлема стража — один комплект, эхо 3", byId.rusty_guard and byId.rusty_guard.echoes == 3 and #old.armorItems == 3, #old.armorItems)
check("запас мага — комплект накидки (послушник)", old.armorStash.mage and old.armorStash.mage.id == "novice")
check("шляпа архивариуса из запаса не потерялась", byId.archivist ~= nil and byId.archivist.level == 5)
check("формат 2, повторный прогон ничего не меняет", old.armorFormat == 2 and (function()
	ArmorMigrate.run(old)
	return #old.armorItems == 3 and old.armorEquipped.set == worn
end)())
local fresh = { armorEquipped = {}, armorItems = {}, armorStash = {} }
ArmorMigrate.run(fresh)
check("новый профиль: пусто, формат 2", fresh.armorFormat == 2 and fresh.armorEquipped.set == nil and #fresh.armorItems == 0)

out[#out + 1] = ("ИТОГО: %d провалов"):format(failures)
return table.concat(out, "\n")
