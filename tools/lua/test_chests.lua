--!nonstrict
-- test_chests.lua — сундуки этажей v3: Config/Chests (ключи, стопки, градации),
-- Config/ChestDesigns (10 дизайнов, блоки, Клинок Памяти) и Config/ChestAtlas.
--   LUAU=путь/к/luau node tools/run-luau.js tools/lua/test_chests.lua

local Shared = (_G :: any).KlinokShared or game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Chests = require(Shared.Config.Chests)
local ChestDesigns = require(Shared.Config.ChestDesigns)
local ChestAtlas = require(Shared.Config.ChestAtlas)

local out = {}
local failures = 0
local function check(label, ok, detail)
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %s%s"):format(ok and "OK  " or "FAIL", label, detail and (" — " .. tostring(detail)) or "")
end

local function isHex(value)
	return type(value) == "string" and value:match("^#%x%x%x%x%x%x$") ~= nil
end

-- ===== этажи =====
check("5 этажей", Chests.FloorCount == 5 and #Chests.Floors == 5, Chests.FloorCount)
for f = 1, 5 do
	local floor = Chests.Floors[f]
	local ok = type(floor) == "table" and type(floor.name) == "string" and type(floor.boss) == "string"
		and type(floor.bossDefeated) == "string" and type(floor.whisper) == "string"
	check(("этаж %d: имя, босс, шёпот"):format(f), ok)
	local colorsOk = type(floor.colors) == "table" and #floor.colors == 4
	for _, c in ipairs(floor.colors or {}) do
		colorsOk = colorsOk and isHex(c)
	end
	check(("этаж %d: 4 цвета #RRGGBB"):format(f), colorsOk)
	for _, grade in ipairs(Chests.GradeOrder) do
		local entry = floor[grade]
		check(("этаж %d: %s — имя и описание"):format(f, grade),
			type(entry) == "table" and type(entry.name) == "string" and #entry.name > 0 and type(entry.text) == "string" and #entry.text > 0)
	end
end

-- имена сундуков не повторяются
local names, dup = {}, nil
for f = 1, 5 do
	for _, grade in ipairs(Chests.GradeOrder) do
		local n = Chests.Floors[f][grade].name
		if names[n] then
			dup = n
		end
		names[n] = true
	end
end
check("имена сундуков уникальны", dup == nil, dup)

-- ===== градации =====
check("final → золотой", Chests.gradeOf({ final = true, tier = "epic" }) == "gold")
check("ответвление → обычный", Chests.gradeOf({ tier = "rare", minRarity = "rare" }) == "common")
check("мини-босс → обычный", Chests.gradeOf({ tier = "epic", miniboss = true }) == "common")
check("nil → обычный", Chests.gradeOf(nil) == "common")
check("final = 1 (не true) → обычный", Chests.gradeOf({ final = 1 }) == "common")

-- ===== ключи =====
check("clampFloor(0) = 1", Chests.clampFloor(0) == 1)
check("clampFloor(9) = 5", Chests.clampFloor(9) == 5)
check("clampFloor('3') = 3", Chests.clampFloor("3") == 3)
check("key(2, gold)", Chests.key(2, "gold") == "f2_gold", Chests.key(2, "gold"))
check("key(2, ?) → common", Chests.key(2, "weird") == "f2_common")
local pf, pg = Chests.parse("f3_gold")
check("parse(f3_gold)", pf == 3 and pg == "gold")
check("parse(f9_gold) — чужой этаж", Chests.parse("f9_gold") == nil)
check("parse(f1_silver) — чужая градация", Chests.parse("f1_silver") == nil)
check("parse(мусор)", Chests.parse("hello") == nil and Chests.parse(42) == nil)
for f = 1, 5 do
	for _, grade in ipairs(Chests.GradeOrder) do
		local key = Chests.key(f, grade)
		local a, b = Chests.parse(key)
		if a ~= f or b ~= grade then
			check("parse(key) обратим " .. key, false)
		end
	end
end
check("parse(key(f, g)) обратим для всех 10", true)

local info = Chests.info(5, "gold")
check("info: поля", info.key == "f5_gold" and info.floor == 5 and info.grade == "gold" and info.isBoss == true
	and info.name == Chests.Floors[5].gold.name and info.whisper == Chests.Floors[5].whisper)

-- ===== хранилище =====
local store = {}
check("add → 1", Chests.add(store, 1, "common") == 1)
check("add ×3 → 4", Chests.add(store, 1, "common", 3) == 4)
Chests.add(store, 3, "gold")
Chests.add(store, 5, "common", 2)
Chests.add(store, 1, "gold")
check("total = 8", Chests.total(store) == 8, Chests.total(store))
local stacks = Chests.stacks(store)
check("4 стопки", #stacks == 4, #stacks)
check("золотые выше, новые этажи выше",
	stacks[1].key == "f3_gold" and stacks[2].key == "f1_gold" and stacks[3].key == "f5_common" and stacks[4].key == "f1_common",
	("%s %s %s %s"):format(stacks[1].key, stacks[2].key, stacks[3].key, stacks[4].key))
check("count в стопке", stacks[4].count == 4)
check("take", Chests.take(store, "f3_gold") and store.f3_gold == nil)
check("take пустой — false", Chests.take(store, "f3_gold") == false)
check("take чужого ключа — false", Chests.take(store, "f7_gold") == false)
check("лимит стопки", Chests.add(store, 2, "common", 5000) == Chests.MaxPerStack)
check("мусор в хранилище не считается", Chests.total({ junk = 5, f1_common = 2, f2_gold = -1 }) == 2)

-- ===== дизайны =====
check("10 дизайнов в Order", #ChestDesigns.Order == 10, #ChestDesigns.Order)
local blockBad = {}
for f = 1, 5 do
	for _, grade in ipairs(Chests.GradeOrder) do
		local id = Chests.key(f, grade)
		local d = ChestDesigns.Designs[id]
		if not d then
			table.insert(blockBad, id .. ": нет дизайна")
		else
			if type(d.size) ~= "table" or #d.size ~= 3 or type(d.hinge) ~= "table" or type(d.lock) ~= "table" then
				table.insert(blockBad, id .. ": size/hinge/lock")
			end
			if not isHex(d.glow) then
				table.insert(blockBad, id .. ": glow")
			end
			if #d.base < 4 or #d.lid < 2 then
				table.insert(blockBad, id .. ": мало блоков")
			end
			for part, list in pairs({ base = d.base, lid = d.lid }) do
				for i, b in ipairs(list) do
					local okNums = true
					for k = 1, 6 do
						okNums = okNums and type(b[k]) == "number"
					end
					okNums = okNums and b[4] > 0 and b[5] > 0 and b[6] > 0
					if not okNums or not isHex(b[7]) or not ChestDesigns.Materials[b[8]] then
						table.insert(blockBad, ("%s.%s[%d]"):format(id, part, i))
					end
				end
			end
			-- замок спереди: на передней стенке (z ≥ половины глубины)
			if d.lock[3] < d.size[2] * 0.45 then
				table.insert(blockBad, id .. ": замок не спереди")
			end
		end
	end
end
check("дизайны: блоки, цвета, материалы", #blockBad == 0, table.concat(blockBad, ", "))

-- ===== Клинок Памяти =====
local blade = ChestDesigns.Blade
local widthOk = true
local cells = 0
local unknown = {}
for _, row in ipairs(blade) do
	widthOk = widthOk and #row == #blade[1]
	for c = 1, #row do
		local ch = row:sub(c, c)
		if ch ~= "." then
			cells += 1
			if not isHex(ChestDesigns.BladeColors[ch]) then
				unknown[ch] = true
			end
		end
	end
end
local unknownList = {}
for ch in pairs(unknown) do
	table.insert(unknownList, ch)
end
check("клинок 15×50", #blade == 50 and #blade[1] == 15 and widthOk, ("%d×%d"):format(#blade[1], #blade))
check("цвета клинка известны", #unknownList == 0, table.concat(unknownList, ""))
check("остриё — строка 1 (один пиксель)", select(2, blade[1]:gsub("[^%.]", "")) == 1)
local channel = 0
for _, row in ipairs(blade) do
	channel += select(2, row:gsub("[fG]", ""))
end
check("дол клинка (f/G) для пульсов редкости", channel >= 20, channel)
check("клинок не слишком тяжёлый для UI (≤ 500 квадратов)", cells <= 500, cells)

-- ===== атлас =====
local atlasBad = {}
for _, id in ipairs(ChestDesigns.Order) do
	for _, kind in ipairs({ "icon", "art", "open" }) do
		local p = ChestAtlas.Pieces[id .. "_" .. kind]
		if not p then
			table.insert(atlasBad, id .. "_" .. kind)
		elseif p.x < 0 or p.y < 0 or p.x + p.w > ChestAtlas.Size.w or p.y + p.h > ChestAtlas.Size.h then
			table.insert(atlasBad, id .. "_" .. kind .. " за краем")
		end
	end
end
check("атлас: 30 кусков в пределах", #atlasBad == 0, table.concat(atlasBad, ", "))
local icon = ChestAtlas.Pieces.f1_common_icon
local art = ChestAtlas.Pieces.f1_common_art
check("размеры кусков 32×32 и 112×96", icon.w == 32 and icon.h == 32 and art.w == 112 and art.h == 96)

out[#out + 1] = ("ИТОГО: %d проверок, %d провалов"):format(#out, failures)
return table.concat(out, "\n")
