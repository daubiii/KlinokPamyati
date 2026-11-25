--!nonstrict
-- test_floor_boons.lua — «Дары Эха» (Config/FloorBoons, BoonIcons, Progression):
--   * у каждой карточки 3 значения, иконка 20×20 с цветами, текст без пустых %s;
--   * 3 разные карточки в предложении, редкости ≈ 70/25/5;
--   * карточка на потолке (cap) больше не выпадает;
--   * предел душ растёт с «Приливом душ», потолки бонусов — вместе с ним.
-- Запуск: node tools/run-luau.js tools/lua/test_floor_boons.lua
local Shared = (_G :: any).KlinokShared or game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local FloorBoons = require(Shared.Config.FloorBoons)
local Icons = require(Shared.Config.BoonIcons)
local Progression = require(Shared.Config.Progression)

-- Вне Roblox нет Random: простой ГПСЧ с тем же интерфейсом.
local Rand = Random or {
	new = function(seed)
		local state = seed or 1
		local r = {}
		function r:NextNumber()
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end
		function r:NextInteger(a, b)
			return a + math.floor(self:NextNumber() * (b - a + 1))
		end
		return r
	end,
}

local out, failures = {}, 0
local function check(label, ok, detail)
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %s%s"):format(ok and "OK  " or "FAIL", label, (not ok and detail) and ("  — " .. tostring(detail)) or "")
end

out[#out + 1] = "Карточки:"
check("карточек не меньше 10", #FloorBoons.Cards >= 10, #FloorBoons.Cards)
for _, card in ipairs(FloorBoons.Cards) do
	local ok = #card.values == 3 and card.values[1] < card.values[3] and card.weight and card.weight > 0
	check(card.id .. ": 3 значения по росту, вес", ok)
	local icon = Icons[card.icon]
	local good = icon and #icon.rows == Icons.size
	local missing = {}
	if good then
		for _, row in ipairs(icon.rows) do
			if #row ~= Icons.size then
				good = false
			end
			for ch in row:gmatch("[^%.]") do
				if not icon.pal[ch] then
					missing[ch] = true
				end
			end
		end
	end
	check(card.id .. ": иконка 20×20, все цвета в палитре", good and next(missing) == nil)
	for r = 1, 3 do
		local text = FloorBoons.describe(card.id, r)
		check(card.id .. " ×" .. r .. ": текст «" .. text:gsub("\n", " / ") .. "»", #text > 0 and not text:find("%%s") and not text:find("nil"))
	end
end
check("формат 0.2 → 20%", FloorBoons.format("pct", 0.2) == "20%", FloorBoons.format("pct", 0.2))
check("формат 0.075 → 7,5%", FloorBoons.format("pct", 0.075) == "7,5%", FloorBoons.format("pct", 0.075))
check("формат 1.75 → 1,75", FloorBoons.format("mult", 1.75) == "1,75", FloorBoons.format("mult", 1.75))
check("формат 2.0 → 2", FloorBoons.format("mult", 2.0) == "2", FloorBoons.format("mult", 2.0))

out[#out + 1] = "Колода:"
local rng = Rand.new(7)
local counts, rar, dup = {}, { 0, 0, 0 }, 0
local N = 4000
for _ = 1, N do
	local offer = FloorBoons.roll(rng, 3, nil)
	local seen = {}
	for _, item in ipairs(offer) do
		if seen[item.id] then
			dup += 1
		end
		seen[item.id] = true
		counts[item.id] = (counts[item.id] or 0) + 1
		rar[item.rarity] += 1
	end
end
check("3 разные карточки в каждом предложении", dup == 0, dup)
local total = rar[1] + rar[2] + rar[3]
check(("редкости %.0f/%.0f/%.1f%%"):format(rar[1] / total * 100, rar[2] / total * 100, rar[3] / total * 100),
	math.abs(rar[1] / total - 0.70) < 0.03 and math.abs(rar[3] / total - 0.05) < 0.015)
for _, card in ipairs(FloorBoons.Cards) do
	check(card.id .. " выпадает", (counts[card.id] or 0) > 0)
end
local capped = 0
for _ = 1, 500 do
	for _, item in ipairs(FloorBoons.roll(rng, 3, { evasion = { total = 0.35 }, haste = { total = 1.0 } })) do
		if item.id == "evasion" or item.id == "haste" then
			capped += 1
		end
	end
end
check("карточки на потолке не выпадают", capped == 0, capped)

out[#out + 1] = "Сумма даров (как на сервере):"
local t = FloorBoons.totals({ { "haste", 1 }, { "haste", 3 }, { "evasion", 3 }, { "evasion", 3 }, { "evasion", 3 }, { "evasion", 3 }, { "soul_surge", 1 }, { "soul_surge", 2 } })
check("скорость атаки 20% + 40% = 60%", math.abs(t.haste.total - 0.60) < 1e-9 and t.haste.count == 2 and t.haste.best == 3, t.haste.total)
check("уклонение упирается в предел 35%", math.abs(t.evasion.total - 0.35) < 1e-9, t.evasion.total)
check("души ×1,5 × ×1,75 = ×2,625, предел +50", math.abs(t.soul_surge.total - 2.625) < 1e-9 and t.soul_surge.extra == 50, t.soul_surge.total)

out[#out + 1] = "Души:"
check("предел 40 без даров", Progression.maxStacks(0) == 40)
check("предел 60 с +20", Progression.maxStacks(20) == 60)
local b40 = Progression.stackBonuses(60, 0)
local b60 = Progression.stackBonuses(60, 20)
check("без даров 60 душ = как 40 (+40% урона)", math.abs(b40.damage - 0.40) < 1e-9, b40.damage)
check("с пределом 60 — +60% урона", math.abs(b60.damage - 0.60) < 1e-9, b60.damage)
check("старый вызов без capBonus не изменился", math.abs(Progression.stackBonuses(10).damage - 0.10) < 1e-9)

out[#out + 1] = ("ИТОГО: %d провалов"):format(failures)
return table.concat(out, "\n")
