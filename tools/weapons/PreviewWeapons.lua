--[[
	PreviewWeapons — выставить 8 моделей оружия в ряд для проверки на глаз.
	Command Bar, режим Edit. Модель Workspace.WeaponPreview — удалить перед Ctrl+S
	(второй запуск скрипта тоже её удаляет).
	В Output: у каждого оружия «меш» (новые модели) или «воксели» (меши не найдены).
]]
local RS = game:GetService("ReplicatedStorage")
local Builder = require(RS.Shared.Voxel.VoxelWeaponBuilder)
local Loot = require(RS.Shared.Config.Loot)

local old = workspace:FindFirstChild("WeaponPreview")
if old then
	old:Destroy()
	print("[PreviewWeapons] витрина убрана")
	return
end

local holder = Instance.new("Model")
holder.Name = "WeaponPreview"
holder.Parent = workspace

local camera = workspace.CurrentCamera
local origin = camera and (camera.CFrame.Position + camera.CFrame.LookVector * 22) or Vector3.new(0, 10, 0)
local right = camera and camera.CFrame.RightVector or Vector3.new(1, 0, 0)
right = Vector3.new(right.X, 0, right.Z).Unit
local facing = CFrame.lookAt(Vector3.zero, -Vector3.new(camera and camera.CFrame.LookVector.X or 0, 0, camera and camera.CFrame.LookVector.Z or 1))

for index, weapon in ipairs(Loot.Weapons) do
	local position = origin + right * ((index - 4.5) * 3.2)
	local model = Builder.build(weapon.typeId, {
		weaponId = weapon.id,
		rarityId = weapon.rarity,
		anchored = true,
		parent = holder,
		baseCFrame = CFrame.new(position) * facing.Rotation,
	})
	model.Name = weapon.id
	print(("[PreviewWeapons] %s — %s"):format(weapon.name, model:GetAttribute("WeaponMesh") and "меш" or "воксели"))
end
