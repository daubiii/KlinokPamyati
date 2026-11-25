--!nonstrict
-- probe_sand.lua — где песок (террейн) выше пола карты.
local W = game.Workspace
local map = W:FindFirstChild("Floor1Map")
if not map then
	return "нет Floor1Map"
end
local out = {}

-- Границы карты по коллизиям
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
table.insert(out, string.format("границы карты: x %.0f..%.0f, z %.0f..%.0f", minX, maxX, minZ, maxZ))

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { W.Terrain }
local mapParams = RaycastParams.new()
mapParams.FilterType = Enum.RaycastFilterType.Include
mapParams.FilterDescendantsInstances = { map }

-- Сетка 20 стадов внутри карты: где песок выше пола
local hits = 0
local samples = 0
local worst = {}
for x = minX, maxX, 20 do
	for z = minZ, maxZ, 20 do
		samples += 1
		local sand = W:Raycast(Vector3.new(x, 40, z), Vector3.new(0, -60, 0), terrainParams)
		local floor = W:Raycast(Vector3.new(x, 40, z), Vector3.new(0, -60, 0), mapParams)
		if sand and floor and sand.Position.Y > floor.Position.Y + 0.5 then
			hits += 1
			if #worst < 12 then
				table.insert(worst, string.format("x=%.0f z=%.0f: песок y=%.1f выше пола y=%.1f на %.1f",
					x, z, sand.Position.Y, floor.Position.Y, sand.Position.Y - floor.Position.Y))
			end
		end
	end
end
table.insert(out, ("точек с песком выше пола: %d из %d"):format(hits, samples))
for _, line in ipairs(worst) do
	table.insert(out, "  " .. line)
end
return table.concat(out, "\n")
