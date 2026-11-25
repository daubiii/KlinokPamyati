--!nonstrict
-- check_loot_merge.lua — проверить, что в Studio у Loot и Weapons есть
-- подмешивание данных этажей 3-5 (без него оружие 3-5 не находится по id).
local cfg = game.ReplicatedStorage.Shared.Config
local out = {}

local function srcOf(name: string)
	local module = cfg:FindFirstChild(name)
	if not module then
		return nil, "нет модуля " .. name
	end
	local ok, src = pcall(function()
		return module.Source
	end)
	if not ok then
		return nil, "Source недоступен у " .. name
	end
	return src
end

local loot, lootErr = srcOf("Loot")
if loot then
	table.insert(out, "Loot.lua ссылается на LootFloor3: " .. tostring(string.find(loot, "LootFloor3", 1, true) ~= nil))
	table.insert(out, "Loot.lua задаёт веса этажей 3-5: " .. tostring(string.find(loot, "ChestWeightsByFloor[5]", 1, true) ~= nil))
else
	table.insert(out, lootErr)
end

local weapons, weaponsErr = srcOf("Weapons")
if weapons then
	table.insert(out, "Weapons.lua грузит LootFloor3: " .. tostring(string.find(weapons, "LootFloor", 1, true) ~= nil))
else
	table.insert(out, weaponsErr)
end

return table.concat(out, "\n")
