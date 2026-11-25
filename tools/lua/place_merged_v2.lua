--!nonstrict
-- place_merged_v2.lua — переставляет слитые меши зон по FloorMapData.
--
-- Почему: первая версия (place_merged_visuals.lua) выравнивала меш по габариту
-- КОЛЛИЗИЙ. В зонах, где невидимые коллизии выше видимого (barbican, boss,
-- tower), меш уезжал по высоте и игрок оказывался внутри геометрии.
--
-- Теперь цель берётся из данных пакета (FloorMapData.zones): объединение
-- центров и размеров всех объектов зоны. Это ровно те координаты, по которым
-- пакетный AssembleFloor1 ставил бы 388 отдельных мешей, поэтому визуал
-- совпадает с задуманным, а не с коллизиями.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DATA = require(ReplicatedStorage.Shared.Config.FloorMapData)

local map = Workspace:FindFirstChild("Floor1Map")
if not map then
	return "[place_merged_v2] нет Workspace.Floor1Map"
end

local placed, missing = 0, 0
local report = {}

for zone, objects in pairs(DATA.zones) do
	local zoneFolder = map:FindFirstChild(zone)
	if not zoneFolder then
		missing += 1
		table.insert(report, zone .. ": нет папки зоны")
		continue
	end

	local visual = zoneFolder:FindFirstChild("Visual")
	if not visual then
		visual = Instance.new("Folder")
		visual.Name = "Visual"
		visual.Parent = zoneFolder
	end

	local mesh
	for _, d in ipairs(visual:GetDescendants()) do
		if d:IsA("MeshPart") then
			mesh = d
			break
		end
	end
	if not mesh then
		missing += 1
		table.insert(report, zone .. ": нет меша в Visual")
		continue
	end

	-- Объединение габаритов всех объектов зоны.
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = -min
	local count = 0
	for _, object in ipairs(objects) do
		local half = object.size / 2
		local a = object.center - half
		local b = object.center + half
		min = Vector3.new(math.min(min.X, a.X), math.min(min.Y, a.Y), math.min(min.Z, a.Z))
		max = Vector3.new(math.max(max.X, b.X), math.max(max.Y, b.Y), math.max(max.Z, b.Z))
		count += 1
	end
	if count == 0 then
		missing += 1
		table.insert(report, zone .. ": нет объектов в данных")
		continue
	end

	local center = (min + max) / 2
	local size = max - min

	local oldCenter = mesh.Position
	local oldSize = mesh.Size

	mesh.Size = size
	mesh.CFrame = CFrame.new(center)
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
	mesh.Name = zone .. "_vis"
	mesh:SetAttribute("Role", "merged")
	mesh:SetAttribute("Zone", zone)
	mesh.Parent = visual

	placed += 1
	table.insert(report, ("%s: объектов %d, сдвиг %.1f,%.1f,%.1f, размер %.0f×%.0f×%.0f (было %.0f×%.0f×%.0f)"):format(
		zone, count,
		center.X - oldCenter.X, center.Y - oldCenter.Y, center.Z - oldCenter.Z,
		size.X, size.Y, size.Z,
		oldSize.X, oldSize.Y, oldSize.Z
	))
end

table.sort(report)
return ("[place_merged_v2] поставлено: %d, не найдено: %d\n%s"):format(placed, missing, table.concat(report, "\n"))
