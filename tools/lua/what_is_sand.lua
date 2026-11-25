--!nonstrict
-- what_is_sand.lua — что именно ловит луч как «песок».
local W = game.Workspace
local T = W.Terrain
local out = {}

table.insert(out, "Terrain: " .. T:GetFullName() .. ", размер " .. tostring(T.Size))

-- Все Terrain-подобные объекты в мире
local terrains = 0
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("Terrain") then
		terrains += 1
	end
end
table.insert(out, "объектов Terrain в Workspace: " .. terrains)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { T }
local hit = W:Raycast(Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), params)
if hit then
	table.insert(out, string.format("луч: %s (%s) на y=%.2f, материал %s, это Terrain? %s",
		hit.Instance.Name, hit.Instance.ClassName, hit.Position.Y,
		tostring(hit.Material), tostring(hit.Instance == T)))
else
	table.insert(out, "луч: ничего")
end

-- Что в вокселях по столбцу 0,0 от -20 до 40
local region = Region3.new(Vector3.new(-8, -20, -8), Vector3.new(8, 40, 8))
local ok, voxels = pcall(function()
	return T:ReadVoxels(region, 4)
end)
if ok then
	local bands = {}
	for yi = 1, voxels.Size.Y do
		local mat = voxels[1][yi][1]
		if mat ~= Enum.Material.Air then
			table.insert(bands, string.format("%s@%d", mat.Name, yi))
		end
	end
	table.insert(out, "столбец 0,0 (воксели снизу вверх): " .. (#bands > 0 and table.concat(bands, " ") or "воздух"))
	table.insert(out, string.format("размер сетки: %d×%d×%d, шаг 4, от y=-20", voxels.Size.X, voxels.Size.Y, voxels.Size.Z))
else
	table.insert(out, "ReadVoxels: " .. tostring(voxels))
end
return table.concat(out, "\n")
