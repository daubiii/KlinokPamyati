--!nonstrict
-- carve_sand_columns.lua — точечно убирает песок над полом карты.
-- Идём сеткой 4 стада по габаритам карты: если над полом карты есть песок выше
-- него на 0.3+, вырезаем воздушный столбец (4×8×4). Пустыня вокруг замка цела:
-- там, где пола карты нет, ничего не трогаем.
local W = game.Workspace
local T = W.Terrain
local map = W:FindFirstChild("Floor1Map")
if not map then
	return "нет Floor1Map"
end
local out = {}

local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
for _, d in ipairs(map:GetDescendants()) do
	if d:IsA("BasePart") then
		local p = d.Position
		minX = math.min(minX, p.X)
		maxX = math.max(maxX, p.X)
		minZ = math.min(minZ, p.Z)
		maxZ = math.max(maxZ, p.Z)
	end
end
table.insert(out, string.format("габариты карты: x %.0f..%.0f, z %.0f..%.0f", minX, maxX, minZ, maxZ))

local mapParams = RaycastParams.new()
mapParams.FilterType = Enum.RaycastFilterType.Include
mapParams.FilterDescendantsInstances = { map }
local sandParams = RaycastParams.new()
sandParams.FilterType = Enum.RaycastFilterType.Include
sandParams.FilterDescendantsInstances = { T }

local step = 4
local columns = 0
local carvedRegions = 0
for x = minX, maxX, step do
	for z = minZ, maxZ, step do
		local floor = W:Raycast(Vector3.new(x, 40, z), Vector3.new(0, -80, 0), mapParams)
		if floor then
			columns += 1
			local sand = W:Raycast(Vector3.new(x, 40, z), Vector3.new(0, -80, 0), sandParams)
			if sand and sand.Position.Y > floor.Position.Y + 0.3 then
				local region = Region3.new(
					Vector3.new(x - step / 2, floor.Position.Y + 0.4, z - step / 2),
					Vector3.new(x + step / 2, math.min(sand.Position.Y + 2, floor.Position.Y + 12), z + step / 2)
				)
				T:FillRegion(region, 4, Enum.Material.Air)
				carvedRegions += 1
			end
		end
	end
end
table.insert(out, ("колонок с полом карты: %d, вырезано воздушных столбцов: %d"):format(columns, carvedRegions))
return table.concat(out, "\n")
