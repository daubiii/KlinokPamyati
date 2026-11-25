--!nonstrict
-- test_worldmap.lua — карта Врат Печатей: Config/WorldMapAtlas (куски, регионы,
-- сетка попаданий, заглушка), Config/WorldMap (тексты 5 этажей, имена врагов
-- совпадают с Enemies*), Config/ChestPreview (шансы лута = серверный бросок:
-- суммы, эталонная копия старой логики пулов, Monte Carlo).
--   LUAU=путь/к/luau node tools/run-luau.js tools/lua/test_worldmap.lua

-- В luau CLI нет Random: детерминированный xorshift32 с тем же API.
local RandomShim = {}
RandomShim.__index = RandomShim
local function nextU32(self)
	local x = self.s
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.s = x
	return x
end
function RandomShim:NextNumber(a, b)
	local v = nextU32(self) / 4294967296
	if a then
		return a + (b - a) * v
	end
	return v
end
function RandomShim:NextInteger(a, b)
	return a + math.floor(self:NextNumber() * (b - a + 1))
end
Random = {
	new = function(seed)
		local s = bit32.band(math.floor(seed or 12345), 0xFFFFFFFF)
		if s == 0 then
			s = 2463534242
		end
		return setmetatable({ s = s }, RandomShim)
	end,
}

local Shared = (_G :: any).KlinokShared or game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local WorldMapAtlas = require(Shared.Config.WorldMapAtlas)
local WorldMap = require(Shared.Config.WorldMap)
local ChestPreview = require(Shared.Config.ChestPreview)
local Chests = require(Shared.Config.Chests)
local Loot = require(Shared.Config.Loot)
local Armor = require(Shared.Config.Armor)
local Items = require(Shared.Config.Items)
local Rarities = require(Shared.Config.Rarities)
local Enemies = require(Shared.Config.Enemies)
local Enemies3 = require(Shared.Config.Enemies3)
local Enemies45 = require(Shared.Config.Enemies45)

local out = {}
local failures = 0
local function check(label, ok, detail)
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %s%s"):format(ok and "OK  " or "FAIL", label, detail and (" — " .. tostring(detail)) or "")
end
local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-9)
end

-- ===== WorldMapAtlas =====
local A = WorldMapAtlas
local bad = {}
for name, p in pairs(A.Pieces) do
	if p.x < 0 or p.y < 0 or p.x + p.w > A.Size.w or p.y + p.h > A.Size.h then
		table.insert(bad, name)
	end
end
check("атлас: куски в пределах 1024×488", #bad == 0, table.concat(bad, ", "))
check("атлас: карта 504×236", A.Pieces.map.w == A.MapSize.w and A.Pieces.map.h == A.MapSize.h)
for _, name in ipairs({ "cloud1", "cloud2", "cloud3", "puff1", "puff2", "pin" }) do
	check("атлас: кусок " .. name, A.Pieces[name] ~= nil)
end
check("5 регионов", #A.Regions == 5)
for k = 1, 5 do
	local r = A.Regions[k]
	local box = r.box
	check(("регион %d: рамка в карте"):format(k), box.x >= 0 and box.y >= 0 and box.x + box.w <= A.MapSize.w and box.y + box.h <= A.MapSize.h)
	local fog, hi = A.Pieces["fog" .. k], A.Pieces["hi" .. k]
	check(("регион %d: fog/hi размером с рамку"):format(k), fog and hi and fog.w == box.w and fog.h == box.h and hi.w == box.w and hi.h == box.h)
	check(("регион %d: ориентир попадает в свой этаж"):format(k), A.regionAt(r.landmark.x, r.landmark.y) == k, A.regionAt(r.landmark.x, r.landmark.y))
	check(("регион %d: плашка внутри карты"):format(k), r.label.x > 20 and r.label.x < A.MapSize.w - 20 and r.label.y > 6 and r.label.y < A.MapSize.h - 6)
end
local g = A.Grid
local rowsOk = #g.rows == g.h
for _, row in ipairs(g.rows) do
	rowsOk = rowsOk and #row == g.w and row:match("^[0-5]+$") ~= nil
end
check("сетка 126×59 из цифр 0–5", rowsOk and g.w * g.cell == A.MapSize.w + (A.MapSize.w % g.cell == 0 and 0 or g.cell - A.MapSize.w % g.cell))
check("regionAt: море и вне карты — 0", A.regionAt(0, 0) == 0 and A.regionAt(-10, 5) == 0 and A.regionAt(9999, 9999) == 0)
-- заглушка: полосы ровно покрывают клетки этажей сетки
local gridCount, stripCount = {}, {}
for _, row in ipairs(g.rows) do
	for i = 1, #row do
		local v = tonumber(row:sub(i, i))
		if v > 0 then
			gridCount[v] = (gridCount[v] or 0) + 1
		end
	end
end
local stripsOk = true
for _, s in ipairs(A.Fallback) do
	local k, x, y, len = s[1], s[2], s[3], s[4]
	stripCount[k] = (stripCount[k] or 0) + len
	local row = g.rows[y + 1]
	stripsOk = stripsOk and row ~= nil and row:sub(x + 1, x + len) == string.rep(tostring(k), len)
end
check("заглушка: полосы лежат на своих клетках", stripsOk)
for k = 1, 5 do
	check(("заглушка: этаж %d покрыт полностью"):format(k), (gridCount[k] or 0) > 0 and gridCount[k] == stripCount[k], ("%s/%s"):format(tostring(stripCount[k]), tostring(gridCount[k])))
end

-- ===== WorldMap: тексты =====
local enemyNames = {}
local function collect(t, depth, seen)
	if type(t) ~= "table" or depth > 4 or seen[t] then
		return
	end
	seen[t] = true
	if type(t.name) == "string" then
		enemyNames[t.name] = enemyNames[t.name] or { title = t.title, role = t.role }
	end
	for _, v in pairs(t) do
		collect(v, depth + 1, seen)
	end
end
for _, m in ipairs({ Enemies, Enemies3, Enemies45 }) do
	collect(m, 0, {})
end
check("WorldMap: 5 этажей", WorldMap.FloorCount == 5)
for k = 1, 5 do
	local f = WorldMap.get(k)
	check(("этаж %d: описание, летопись, цитата"):format(k), f and #f.about >= 2 and #f.lore >= 3 and type(f.quote) == "string" and #f.quote > 10)
	check(("этаж %d: хранитель = босс сундуков"):format(k), f.keeper == Chests.Floors[k].boss, f.keeper)
	local boss = enemyNames[f.keeper]
	check(("этаж %d: титул хранителя как у врага"):format(k), boss ~= nil and boss.title == f.keeperTitle, boss and boss.title)
	check(("этаж %d: где найти оба сундука"):format(k), f.chests and type(f.chests.common) == "string" and type(f.chests.gold) == "string")
	local missing = {}
	for _, e in ipairs(f.inhabitants) do
		local known = enemyNames[e.name]
		if not known or not WorldMap.Roles[e.role] or (known.role and known.role ~= e.role) then
			table.insert(missing, e.name .. "/" .. tostring(e.role) .. "≠" .. tostring(known and known.role))
		end
	end
	check(("этаж %d: обитатели есть в Enemies* и роли совпадают"):format(k), #missing == 0 and #f.inhabitants >= 4, table.concat(missing, ", "))
	local mbBad = {}
	for _, mb in ipairs(f.minibosses) do
		local known = enemyNames[mb.name]
		if not known or known.title ~= mb.title then
			table.insert(mbBad, mb.name)
		end
	end
	check(("этаж %d: мини-боссы и их титулы"):format(k), #mbBad == 0, table.concat(mbBad, ", "))
	check(("этаж %d: опасности"):format(k), #f.dangers >= 3)
end

-- ===== ChestPreview: оружие =====
-- Эталон: старая логика пула Loot.rollWeapon до выноса в Loot.chestPool.
local function oldPoolFor(rarityId, floor, className)
	local list = {}
	local wanted = className == "mage" and "mage" or "warrior"
	for _, weapon in ipairs(Loot.Weapons) do
		if weapon.rarity == rarityId and (weapon.floor or 1) == (floor or 1) and (weapon.class or "warrior") == wanted then
			table.insert(list, weapon)
		end
	end
	return list
end
local function oldPool(rarityId, floor, className)
	local pool = oldPoolFor(rarityId, floor, className)
	if #pool == 0 then
		pool = oldPoolFor("common", floor, className)
	end
	local lower = (floor or 1) - 1
	while #pool == 0 and lower >= 1 do
		pool = oldPoolFor(rarityId, lower, className)
		if #pool == 0 then
			pool = oldPoolFor("common", lower, className)
		end
		lower -= 1
	end
	return pool
end
local function ids(list)
	local t = {}
	for _, w in ipairs(list) do
		table.insert(t, type(w) == "table" and (w.id or (w[1] .. "_" .. w[2])) or tostring(w))
	end
	return table.concat(t, ",")
end
local poolBad = {}
for _, class in ipairs({ "warrior", "mage" }) do
	for f = 1, 5 do
		for _, r in ipairs(Rarities.order) do
			if ids(Loot.chestPool(r, f, class)) ~= ids(oldPool(r, f, class)) then
				table.insert(poolBad, ("%s/%d/%s"):format(class, f, r))
			end
		end
	end
end
check("Loot.chestPool = старая логика пула (2 класса × 5 этажей × 6 редкостей)", #poolBad == 0, table.concat(poolBad, ", "))
local wBad = {}
for _, class in ipairs({ "warrior", "mage" }) do
	for f = 1, 5 do
		local old = (Loot.ChestWeightsByClass[class] and (Loot.ChestWeightsByClass[class][f] or Loot.ChestWeightsByClass[class][1])) or Loot.ChestWeightsByFloor[f] or Loot.ChestWeights
		if Loot.chestWeights(f, class) ~= old then
			table.insert(wBad, class .. f)
		end
	end
end
check("Loot.chestWeights = старая таблица весов", #wBad == 0, table.concat(wBad, ", "))

local N = 20000
local maxDiff, worst = 0, ""
for _, class in ipairs({ "warrior", "mage" }) do
	for f = 1, 5 do
		for _, grade in ipairs({ "common", "gold" }) do
			local p = ChestPreview.weapons(f, grade, class)
			local sum, classOk = 0, true
			for _, it in ipairs(p.items) do
				sum += it.chance
				classOk = classOk and Loot.weaponClass({ id = it.id }) == class
			end
			local gsum = 0
			for _, gr in ipairs(p.groups) do
				gsum += gr.chance
			end
			check(("оружие %s эт.%d %s: сумма 100%%, свой класс"):format(class, f, grade), near(sum, 1, 1e-9) and near(gsum, 1, 1e-9) and classOk and #p.items > 0, sum)
		end
		-- Monte Carlo против настоящего броска (grade на оружие не влияет)
		local rng = Random.new(f * 7919 + (class == "mage" and 104729 or 0))
		local freq = {}
		for _ = 1, N do
			local w = Loot.rollWeapon(10, rng, f, class)
			freq[w.id] = (freq[w.id] or 0) + 1
		end
		local p = ChestPreview.weapons(f, "common", class)
		local known = {}
		for _, it in ipairs(p.items) do
			known[it.id] = true
			local d = math.abs((freq[it.id] or 0) / N - it.chance)
			if d > maxDiff then
				maxDiff, worst = d, ("%s эт.%d %s"):format(class, f, it.id)
			end
		end
		local extra = {}
		for id in pairs(freq) do
			if not known[id] then
				table.insert(extra, id)
			end
		end
		check(("Monte Carlo %s эт.%d: выпадает только показанное"):format(class, f), #extra == 0, table.concat(extra, ", "))
	end
end
check(("Monte Carlo оружия: расхождение < 1,5%% (худшее %.4f, %s)"):format(maxDiff, worst), maxDiff < 0.015)
local forced = ChestPreview.weapons(1, "common", "warrior", 1)
local allCommon = forced.forced
for _, it in ipairs(forced.items) do
	allCommon = allCommon and it.rarity == "common"
end
check("первые 2 сундука: только обычное", allCommon)
local full = ChestPreview.get(1, "common", "warrior", 0)
check("get: осталось 2 обычных сундука у нового аккаунта", full.firstCommonLeft == 2 and ChestPreview.get(1, "common", "warrior", 9).firstCommonLeft == 0)

-- ===== золото и материал =====
local r1, r2, r4 = ChestPreview.rewards(1), ChestPreview.rewards(2), ChestPreview.rewards(4)
check("награда эт.1: 150 золота, ржавое железо 3–5", r1.gold == 150 and r1.materialId == "rusty_iron" and r1.materialRange[1] == 3 and r1.materialRange[2] == 5)
check("награда эт.2: 220 золота, болотный тростник", r2.gold == 220 and r2.materialId == "swamp_reed")
check("награда эт.4: как у этажа 1 (Loot.rollChest)", r4.gold == 150 and r4.materialId == "rusty_iron")
local rc = Loot.rollChest(10, Random.new(5), 2, "warrior")
check("Loot.rollChest эт.2 согласован с витриной", rc.gold == r2.gold and rc.materialId == r2.materialId and rc.materialCount >= 3 and rc.materialCount <= 5)

-- ===== броня =====
-- Эталон: старая логика ArmorService.rollChest (до Armor.chestPool).
local function oldArmorRoll(rng, floor, className, isBoss)
	local chance = Armor.ChestChance[floor or 1] or Armor.ChestChance[1]
	if not (isBoss and Armor.BossChestGuaranteed) and rng:NextNumber() > chance then
		return nil
	end
	local rarityId = Loot.rollRarity(10, rng, floor)
	if isBoss and not Rarities.atLeast(rarityId, "rare") then
		rarityId = "rare"
	end
	local pool = Armor.pool(rarityId, floor, className)
	if #pool == 0 then
		pool = Armor.pool(rarityId, 1, className)
	end
	if #pool == 0 then
		for index = Rarities.get(rarityId).index - 1, 1, -1 do
			pool = Armor.pool(Rarities.order[index], 1, className)
			if #pool > 0 then
				break
			end
		end
	end
	if #pool == 0 then
		return nil
	end
	local pick = pool[rng:NextInteger(1, #pool)]
	return pick[1] .. "_" .. pick[2]
end
local armorPoolBad = {}
for _, class in ipairs({ "warrior", "mage" }) do
	for f = 1, 5 do
		for _, r in ipairs(Rarities.order) do
			local a = Armor.chestPool(r, f, class)
			local b = Armor.pool(r, f, class)
			if #b == 0 then
				b = Armor.pool(r, 1, class)
			end
			if #b == 0 then
				for index = Rarities.get(r).index - 1, 1, -1 do
					b = Armor.pool(Rarities.order[index], 1, class)
					if #b > 0 then
						break
					end
				end
			end
			if ids(a) ~= ids(b) then
				table.insert(armorPoolBad, ("%s/%d/%s"):format(class, f, r))
			end
		end
	end
end
check("Armor.chestPool = старая логика ArmorService", #armorPoolBad == 0, table.concat(armorPoolBad, ", "))
local aMax, aWorst = 0, ""
for _, class in ipairs({ "warrior", "mage" }) do
	for _, f in ipairs({ 1, 2, 5 }) do
		for _, grade in ipairs({ "common", "gold" }) do
			local p = ChestPreview.armor(f, grade, class)
			local sum, rareOk, classOk = 0, true, true
			for _, it in ipairs(p.items) do
				sum += it.chance
				rareOk = rareOk and (grade ~= "gold" or Rarities.atLeast(it.rarity, "rare"))
				classOk = classOk and Armor.classOf(it.setId) == class
			end
			check(("броня %s эт.%d %s: сумма = шанс брони, свой класс%s"):format(class, f, grade, grade == "gold" and ", от редкой" or ""),
				near(sum, p.chance, 1e-9) and classOk and rareOk and (grade ~= "gold" or p.chance == 1), ("%.4f/%.4f"):format(sum, p.chance))
			local rng = Random.new(f * 31 + #grade * 7 + (class == "mage" and 1000 or 0))
			local freq, n = {}, 12000
			for _ = 1, n do
				local id = oldArmorRoll(rng, f, class, grade == "gold")
				if id then
					freq[id] = (freq[id] or 0) + 1
				end
			end
			for _, it in ipairs(p.items) do
				local d = math.abs((freq[it.id] or 0) / n - it.chance)
				if d > aMax then
					aMax, aWorst = d, ("%s эт.%d %s %s"):format(class, f, grade, it.id)
				end
			end
		end
	end
end
check(("Monte Carlo брони: расхождение < 1,5%% (худшее %.4f, %s)"):format(aMax, aWorst), aMax < 0.015)
check("ассасин: брони нет", ChestPreview.armor(1, "common", "assassin") == nil)

-- ===== припасы и аксессуары =====
for _, grade in ipairs({ "common", "gold" }) do
	local s = ChestPreview.supplies(3, grade)
	local sum, chanceOk = 0, true
	for _, it in ipairs(s.items) do
		sum += it.perStack
		chanceOk = chanceOk and it.chance > 0 and it.chance <= 1 and it.chance >= it.perStack - 1e-12 and Items.List[it.id] ~= nil
	end
	check(("припасы %s: веса стопки = 100%%, шансы в (0,1]"):format(grade), near(sum, 1, 1e-9) and chanceOk and #s.items == #Items.Chest.table)
	local asum = 0
	for _, it in ipairs(s.accessories.items) do
		asum += it.chance
	end
	check(("аксессуары %s: сумма = шанс аксессуара"):format(grade), near(asum, s.accessories.chance, 1e-9), ("%.4f"):format(asum))
end
local accMax = 0
for _, f in ipairs({ 1, 3, 5 }) do
	local s = ChestPreview.supplies(f, "common")
	local rng = Random.new(f * 101)
	local freq, n = {}, 20000
	for _ = 1, n do
		local id = Items.rollAccessory(f, rng)
		freq[id] = (freq[id] or 0) + 1
	end
	for _, it in ipairs(s.accessories.items) do
		accMax = math.max(accMax, math.abs((freq[it.id] or 0) / n - it.chance / s.accessories.chance))
	end
end
check(("Monte Carlo аксессуаров: расхождение < 1,5%% (%.4f)"):format(accMax), accMax < 0.015)

-- ===== проценты =====
check("проценты: 70%, 0,5%, <0,1%, 0%", ChestPreview.percent(0.7) == "70%" and ChestPreview.percent(0.005) == "0,5%"
	and ChestPreview.percent(0.0004) == "<0,1%" and ChestPreview.percent(0) == "0%", ChestPreview.percent(0.005))

out[#out + 1] = ("ИТОГО: %d проверок, %d провалов"):format(#out, failures)
return table.concat(out, "\n")
