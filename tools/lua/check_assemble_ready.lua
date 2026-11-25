--!nonstrict
-- check_assemble_ready.lua — всё ли готово к сборочным скриптам:
-- конфиги данных и импортированные модели.
local out = {}

local function has(parent, name)
	return parent and parent:FindFirstChild(name) ~= nil
end

local config = game.ReplicatedStorage:FindFirstChild("Shared")
config = config and config:FindFirstChild("Config")

for _, name in ipairs({ "WeaponMeshDataFloor3", "WeaponMeshDataFloor4", "WeaponMeshDataFloor5", "MageArmorMeshData", "WeaponMeshDataMage" }) do
	table.insert(out, ("конфиг %s: %s"):format(name, has(config, name) and "есть" or "НЕТ"))
end

local rs = game.ReplicatedStorage
for _, name in ipairs({ "WeaponMeshes", "HeroArmorMeshes" }) do
	local folder = rs:FindFirstChild(name)
	local count = 0
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			count += 1
		end
	end
	table.insert(out, ("ReplicatedStorage.%s: %s"):format(name, folder and ("есть, детей " .. count) or "НЕТ"))
end

for _, name in ipairs({ "weapons_floor3", "weapons_floor4", "weapons_floor5", "mage_armor", "staffs_mage" }) do
	local model = game.Workspace:FindFirstChild(name)
	local meshes = 0
	if model then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("MeshPart") then
				meshes += 1
			end
		end
	end
	table.insert(out, ("Workspace.%s: %s"):format(name, model and ("есть, MeshPart " .. meshes) or "НЕТ"))
end

return table.concat(out, "\n")
