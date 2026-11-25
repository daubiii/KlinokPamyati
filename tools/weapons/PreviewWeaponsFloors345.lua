--[[
	PreviewWeaponsFloors345 — выставить оружие этажей 3, 4, 5 тремя рядами для проверки на глаз.
	Command Bar, режим Edit. Модель Workspace.WeaponPreview345 — удалить перед Ctrl+S
	(второй запуск скрипта тоже её удаляет).
	В Output: у каждого оружия «меш» (новые модели) или «воксели» (меши не найдены).
]]
local RS = game:GetService("ReplicatedStorage")
local Builder = require(RS.Shared.Voxel.VoxelWeaponBuilder)
local Loot = require(RS.Shared.Config.Loot)

local old = workspace:FindFirstChild("WeaponPreview345")
if old then
	old:Destroy()
	print("[PreviewWeaponsFloors345] витрина убрана")
	return
end

local holder = Instance.new("Model")
holder.Name = "WeaponPreview345"
holder.Parent = workspace

local camera = workspace.CurrentCamera
local look = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
local flatLook = Vector3.new(look.X, 0, look.Z).Unit
local origin = camera and (camera.CFrame.Position + flatLook * 26) or Vector3.new(0, 10, 0)
local right = flatLook:Cross(Vector3.yAxis).Unit
local facing = CFrame.lookAt(Vector3.zero, -flatLook)

for row, floor in ipairs({ 3, 4, 5 }) do
	local list = {}
	for _, weapon in ipairs(Loot.Weapons) do
		if weapon.floor == floor then
			table.insert(list, weapon)
		end
	end
	for index, weapon in ipairs(list) do
		local position = origin + right * ((index - (#list + 1) / 2) * 3.2) + flatLook * ((row - 2) * 6)
		local model = Builder.build(weapon.typeId, {
			weaponId = weapon.id,
			rarityId = weapon.rarity,
			anchored = true,
			parent = holder,
			baseCFrame = CFrame.new(position) * facing.Rotation,
		})
		model.Name = weapon.id
		local mesh = Builder.hasMeshes(weapon.id)
		print(("[PreviewWeaponsFloors345] этаж %d: %s [%s] — %s"):format(floor, weapon.name, weapon.rarity, mesh and "меш" or "воксели"))
	end
end
