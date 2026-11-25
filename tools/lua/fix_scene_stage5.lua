--!nonstrict
-- fix_scene_stage5.lua — разово переносит тренировочную арену в сторону,
-- чтобы она не пересекалась с этажом, который строится из z=0 в −Z.
-- Этаж живёт в x≈0, z от 0 до −350; арена уезжает на x = +150.

local Workspace = game:GetService("Workspace")
local out = {}

local SHIFT = Vector3.new(150, 0, 0)

local function shiftContainer(containerName: string)
	local container = Workspace:FindFirstChild(containerName)
	if not container then
		table.insert(out, containerName .. ": нет")
		return
	end
	local moved = 0
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Model") then
			child:PivotTo(child:GetPivot() + SHIFT)
			moved += 1
		elseif child:IsA("BasePart") then
			child.Position = child.Position + SHIFT
			moved += 1
		end
	end
	-- Модели внутри папок тоже сдвигаем (витрина оружия).
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Parent ~= container and descendant.Parent ~= Workspace then
			descendant:PivotTo(descendant:GetPivot() + SHIFT)
			moved += 1
		end
	end
	table.insert(out, ("%s: сдвинуто %d"):format(containerName, moved))
end

shiftContainer("TestArena")
shiftContainer("WeaponShowcase")

local spawnLocation = Workspace:FindFirstChildOfClass("SpawnLocation")
if spawnLocation then
	spawnLocation.Position = Vector3.new(0, 0.5, -8)
	table.insert(out, "SpawnLocation -> " .. tostring(spawnLocation.Position))
end

-- Старый бесхозный Baseplate убираем: он мешает и не нужен.
local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
	table.insert(out, "Baseplate удалён")
end

return table.concat(out, "\n")
