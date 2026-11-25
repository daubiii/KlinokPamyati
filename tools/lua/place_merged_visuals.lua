--!nonstrict
-- place_merged_visuals.lua — собирает карту из СЛИТЫХ мешей (по одному на зону).
--
-- Зачем: 3D Importer слил каждый OBJ в один MeshPart с именем "default" и
-- поставил все 17 моделей в одну точку (≈128, 26, −60). Позицию исправляем
-- переносом: размер меша уже соответствует зоне, поэтому достаточно совместить
-- центр его габарита с центром коллизий зоны — без масштабирования, чтобы не
-- исказить геометрию.
--
-- Что теряется по сравнению с полной сборкой (388 MeshPart):
--   * свечение glow-объектов (270 шт.) — материал теперь один на зону;
--   * стекло и отдельные роли объектов;
--   * гранулярность стриминга по объектам.
-- Коллизии берутся из Floor1Map.<зона>.Collision, поэтому геймплей и лучи
-- врагов работают как задумано.

local Workspace = game:GetService("Workspace")

local map = Workspace:FindFirstChild("Floor1Map")
if not map then
	return "[place_merged] нет Workspace.Floor1Map"
end

local function bboxOf(container)
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = -min
	local found = false
	for _, part in ipairs(container:GetChildren()) do
		if part:IsA("BasePart") then
			local a = part.Position - part.Size / 2
			local b = part.Position + part.Size / 2
			min = Vector3.new(math.min(min.X, a.X), math.min(min.Y, a.Y), math.min(min.Z, a.Z))
			max = Vector3.new(math.max(max.X, b.X), math.max(max.Y, b.Y), math.max(max.Z, b.Z))
			found = true
		end
	end
	if not found then
		return nil, nil
	end
	return (min + max) / 2, max - min
end

local function firstMeshPart(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("MeshPart") then
			return d
		end
	end
	return nil
end

local placed, missing = 0, 0
local report = {}

for _, zoneFolder in ipairs(map:GetChildren()) do
	local zone = zoneFolder.Name
	local collision = zoneFolder:FindFirstChild("Collision")
	local visual = zoneFolder:FindFirstChild("Visual")
	if not visual then
		visual = Instance.new("Folder")
		visual.Name = "Visual"
		visual.Parent = zoneFolder
	end

	local source = Workspace:FindFirstChild(zone .. "_vis")
	local collisionCenter, collisionSize = nil, nil
	if collision then
		collisionCenter, collisionSize = bboxOf(collision)
	end

	if not source then
		missing += 1
		table.insert(report, ("%s: нет модели %s_vis"):format(zone, zone))
		continue
	end

	local mesh = firstMeshPart(source)
	if not mesh then
		missing += 1
		table.insert(report, ("%s: в %s_vis нет MeshPart"):format(zone, zone))
		continue
	end

	-- Центр габарита самого меша (по его Size и CFrame).
	local meshCenter = mesh.Position

	if not collisionCenter then
		table.insert(report, ("%s: нет коллизий, меш оставлен на месте"):format(zone))
	else
		local delta = collisionCenter - meshCenter
		mesh.CFrame = mesh.CFrame + delta
		meshCenter += delta
		table.insert(report, ("%s: сдвиг %.1f, %.1f, %.1f (размер зоны %.1f×%.1f×%.1f)"):format(
			zone, delta.X, delta.Y, delta.Z, collisionSize.X, collisionSize.Y, collisionSize.Z
		))
	end

	mesh.Name = zone .. "_vis"
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.Massless = true
	mesh.Reflectance = 0
	mesh.CastShadow = true
	mesh.Transparency = 0
	mesh.Material = Enum.Material.SmoothPlastic
	mesh.Color = Color3.new(1, 1, 1)
	mesh:SetAttribute("Role", "merged")
	mesh:SetAttribute("Zone", zone)
	mesh.Parent = visual

	-- Обёртку импортера убираем, если в ней не осталось деталей.
	local left = 0
	for _, d in ipairs(source:GetDescendants()) do
		if d:IsA("BasePart") then
			left += 1
		end
	end
	if left == 0 then
		source:Destroy()
	end

	placed += 1
end

-- Коллизии: невидимые, но с лучами.
local collisionParts = 0
for _, d in ipairs(map:GetDescendants()) do
	if d:IsA("BasePart") and d.Parent and d.Parent.Name == "Collision" then
		d.Transparency = 1
		d.CanCollide = true
		d.CanQuery = true
		d.Anchored = true
		collisionParts += 1
	end
end

return ("[place_merged] мешей поставлено: %d, не найдено: %d, частей коллизий: %d\n%s"):format(
	placed, missing, collisionParts, table.concat(report, "\n")
)
