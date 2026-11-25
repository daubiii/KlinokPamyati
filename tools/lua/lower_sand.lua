--!nonstrict
-- lower_sand.lua — срезает песок пустыни до уровня ниже пола карты.
-- Песчаная плита стоит на y≈2.2-2.5, пол карты — на y≈-0.1, поэтому песок
-- «вылезает» на карту и виден сверху. Режем воздух от -1.0 до +8 по всей
-- площади карты с запасом 60 стадов. Ничего не засыпаем: ямы и рвы остаются.
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
local pad = 60
local yBottom, yTop = -1.0, 8
table.insert(out, string.format("площадь: x %.0f..%.0f, z %.0f..%.0f, срез по y %.1f..%.1f",
	minX - pad, maxX + pad, minZ - pad, maxZ + pad, yBottom, yTop))

local region = Region3.new(
	Vector3.new(minX - pad, yBottom, minZ - pad),
	Vector3.new(maxX + pad, yTop, maxZ + pad)
)
local voxels = T:ReadVoxels(region, 4)
local removed = 0
for x = 1, voxels.Size.X do
	for y = 1, voxels.Size.Y do
		for z = 1, voxels.Size.Z do
			if voxels[x][y][z] ~= Enum.Material.Air then
				removed += 1
			end
		end
	end
end
T:FillRegion(region, 4, Enum.Material.Air)
table.insert(out, ("снято вокселей песка: %d"):format(removed))
return table.concat(out, "\n")
