--!nonstrict
-- test_items.lua — конфиг сумки (Config/Items) и бумажный атлас (Config/PaperAtlas):
-- иконки существуют, категории и группы отката согласованы, сундук ссылается на
-- реальные предметы, взвешенный выбор и аксессуары по этажам работают.
--   LUAU=путь/к/luau node tools/run-luau.js tools/lua/test_items.lua

local Shared = (_G :: any).KlinokShared or game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local PaperAtlas = require(Shared.Config.PaperAtlas)

local out = {}
local failures = 0
local function check(label, ok, detail)
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %s%s"):format(ok and "OK  " or "FAIL", label, detail and (" — " .. tostring(detail)) or "")
end

local Pieces = PaperAtlas.Pieces
local function inAtlas(name)
	local r = Pieces[name]
	return r ~= nil and r.x + r.w <= PaperAtlas.Size and r.y + r.h <= PaperAtlas.Size
end

-- категории
local categoryIds = {}
for _, cat in ipairs(Items.Categories) do
	categoryIds[cat.id] = true
	check("иконка категории " .. cat.id, inAtlas(cat.icon), cat.icon)
end
check("8 категорий", #Items.Categories == 8, #Items.Categories)

-- предметы
local count, bad = 0, {}
for id, item in pairs(Items.List) do
	count += 1
	if not inAtlas(item.icon) then table.insert(bad, id .. ":" .. tostring(item.icon)) end
	if not categoryIds[item.category] then table.insert(bad, id .. " категория " .. tostring(item.category)) end
	if item.use and item.category == "consumables" and not Items.Cooldowns[item.group or ""] then
		table.insert(bad, id .. " без группы отката")
	end
	if item.use and not Items.useText(item.use) then table.insert(bad, id .. " без useText") end
	if not item.name or item.name == "" then table.insert(bad, id .. " без имени") end
end
check(("предметы сумки (%d) согласованы"):format(count), #bad == 0, table.concat(bad, ", "))

-- аксессуары
bad = {}
local accCount = 0
for id, acc in pairs(Items.Accessories) do
	accCount += 1
	if not inAtlas(acc.icon) then table.insert(bad, id .. ":" .. tostring(acc.icon)) end
	if acc.slot ~= "amulet" and acc.slot ~= "ring" then table.insert(bad, id .. " слот " .. tostring(acc.slot)) end
	if not Items.SalvageDust[acc.rarityId] then table.insert(bad, id .. " без пыли") end
	if Items.statsText(acc.stats) == "" then table.insert(bad, id .. " без статов") end
end
check(("аксессуары (%d) согласованы"):format(accCount), #bad == 0, table.concat(bad, ", "))
check("statsText", Items.statsText({ health = 12, armor = 3, damage = 0.06 }) == "+12 здоровья · +3 брони · +6% урона",
	Items.statsText({ health = 12, armor = 3, damage = 0.06 }))

-- стартовый мешок и сундук
bad = {}
for id in pairs(Items.StarterBag) do
	if not Items.List[id] then table.insert(bad, id) end
end
check("стартовый мешок из настоящих предметов", #bad == 0 and Items.List[Items.StarterQuick] ~= nil, table.concat(bad, ","))
bad = {}
for _, entry in ipairs(Items.Chest.table) do
	if not Items.List[entry.id] then table.insert(bad, entry.id) end
end
check("таблица сундука из настоящих предметов", #bad == 0, table.concat(bad, ","))

-- подделка Random: последовательность чисел
local function fakeRng(values)
	local i = 0
	return {
		NextNumber = function()
			i += 1
			return values[(i - 1) % #values + 1]
		end,
		NextInteger = function(_, a, b)
			i += 1
			return math.clamp(a + math.floor(values[(i - 1) % #values + 1] * (b - a + 1)), a, b)
		end,
	}
end
local list = { { id = "a", weight = 1 }, { id = "b", weight = 3 } }
check("pick: малый бросок → первый", Items.pick(list, fakeRng({ 0.1 })).id == "a")
check("pick: большой бросок → второй", Items.pick(list, fakeRng({ 0.9 })).id == "b")
for floor = 1, 5 do
	local seen, okAll = {}, true
	for k = 0, 19 do
		local id = Items.rollAccessory(floor, fakeRng({ k / 20, (k * 7 % 20) / 20 }))
		if not Items.Accessories[id] then okAll = false end
		seen[id] = true
	end
	local kinds = 0
	for _ in pairs(seen) do kinds += 1 end
	check(("аксессуар этажа %d"):format(floor), okAll and kinds >= 2, kinds .. " видов")
end

-- куски, на которые опирается «Книга героя»
bad = {}
for _, name in ipairs({ "sheet", "sheetAlt", "sheetPlain", "sheetBack", "ribbon", "btn", "btnDown", "btnRoundBig",
	"btnRoundBigDown", "strip", "stripRed", "stripPlain", "barFrame", "barXp", "barHp", "ring224", "ring112", "ring80",
	"square", "plate", "plateB", "divider", "dot", "dotRing", "stampMark", "hlTL", "hlTR", "hlBR", "hlBL", "icClose",
	"icLock", "icCheck", "icCheckS", "icHomeS", "icPlusS", "hero1", "hero2", "npc1", "npc2", "npc3", "npc4", "book",
	"bookMark", "eqEmpty_helm", "eqEmpty_chest", "eqIron_helm", "eqIron_chest", "eqLeather_helm", "eqLeather_chest",
	"it_bookBlue", "it_bookRed", "it_soul", "it_sword", "it_amuletSilver", "it_ringSilver", "it_potionRed",
	"hlCross", "it_coinStack", "it_key", "chevronL" }) do
	if not inAtlas(name) then table.insert(bad, name) end
end
for k = 1, 20 do
	if not inAtlas("stamp" .. k) then table.insert(bad, "stamp" .. k) end
end
check("куски окна есть в атласе", #bad == 0, table.concat(bad, ", "))
local d = PaperAtlas.Desk
check("стол: 9-slice в пределах", d.slice[1] + d.slice[3] < d.w and d.slice[2] + d.slice[4] < d.h)

out[#out + 1] = ("ИТОГО: %d проверок, %d провалов"):format(#out, failures)
return table.concat(out, "\n")
