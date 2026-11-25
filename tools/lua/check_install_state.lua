--!nonstrict
-- check_install_state.lua — что уже есть в Studio после наложения пакетов.
local out = {}

local systems = game.ServerScriptService:FindFirstChild("Systems")
for _, name in ipairs({ "ManaService", "TalentService", "ChestService", "BossMoves", "MageService", "BreakableService", "Floor45Service" }) do
	local found = systems and systems:FindFirstChild(name)
	table.insert(out, "Systems." .. name .. ": " .. (found and "есть" or "НЕТ"))
end

local shared = game.ReplicatedStorage:FindFirstChild("Shared")
local config = shared and shared:FindFirstChild("Config")
for _, name in ipairs({ "MageArmorMeshData", "WeaponMeshDataMage", "TalentArt", "ChestArt", "AbilityIcons345", "PaperAtlas", "Talents", "Mana", "Balance" }) do
	local found = config and config:FindFirstChild(name)
	table.insert(out, "Config." .. name .. ": " .. (found and "есть" or "НЕТ"))
end

for _, name in ipairs({ "weapons_floor3", "weapons_floor4", "weapons_floor5", "mage_armor", "staffs_mage" }) do
	local found = game.Workspace:FindFirstChild(name)
	local parts = 0
	if found then
		for _, d in ipairs(found:GetDescendants()) do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
	end
	table.insert(out, "Workspace." .. name .. ": " .. (found and ("есть, частей " .. parts) or "НЕТ"))
end

return table.concat(out, "\n")
