-- calc_materials.lua — сколько материала этажа в среднем приносит один забег.
-- Без Studio: LUAU=<luau> node tools/run-luau.js tools/lua/calc_materials.lua
-- Считает: враги во всех списках зон (волны, засады, группы) × ironChance,
-- фиксированное iron мини-боссов и босса, сундуки этажа × среднее materialRange.
local Shared = (_G :: any).KlinokShared or game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Enemies = require(Shared.Config.Enemies)
local Loot = require(Shared.Config.Loot)

local floors = {
	{ id = 1, cfg = require(Shared.Config.Floor1v2) },
	{ id = 2, cfg = require(Shared.Config.Floor2) },
	{ id = 3, cfg = require(Shared.Config.Floor3) },
	{ id = 4, cfg = require(Shared.Config.Floor4) },
	{ id = 5, cfg = require(Shared.Config.Floor5) },
}

local out = {}
local function walk(node, seen, acc)
	if type(node) ~= "table" or seen[node] then
		return
	end
	seen[node] = true
	if type(node[1]) == "string" and Enemies.Types[node[1]] and type(node[2]) == "table" then
		local t = Enemies.Types[node[1]]
		acc.count += 1
		acc.chance += (t.rewards and t.rewards.ironChance) or 0
		return
	end
	for k, v in pairs(node) do
		if k == "boss" or k == "keeper" then
			if type(v) == "table" and type(v.typeId) == "string" and Enemies.Types[v.typeId] then
				local t = Enemies.Types[v.typeId]
				acc.fixed += (t.rewards and t.rewards.iron) or 0
				acc.bosses += 1
			end
		end
		walk(v, seen, acc)
	end
end

for _, f in ipairs(floors) do
	local acc = { count = 0, chance = 0, fixed = 0, bosses = 0 }
	walk(f.cfg.Zones or f.cfg.Encounters or f.cfg, {}, acc)
	local chests = 0
	for _ in pairs(f.cfg.Chests or {}) do
		chests += 1
	end
	local chest = Loot.chestInfo and Loot.chestInfo(f.id) or nil
	local range = chest and chest.materialRange or { 3, 5 }
	local perChest = (range[1] + range[2]) / 2
	local total = acc.chance + acc.fixed + chests * perChest
	table.insert(out, ("этаж %d: врагов %d, с врагов ≈%.1f, боссы %d (+%d), сундуков %d × %.1f = %.1f · ИТОГО ≈ %.1f"):format(
		f.id, acc.count, acc.chance, acc.bosses, acc.fixed, chests, perChest, chests * perChest, total))
end
return table.concat(out, "\n")
