--!nonstrict
-- terrain_check.lua — не перекрывает ли проход террейн (он не BasePart и в обход не попадает).
local W = game.Workspace
local out = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { W.Terrain }

for _, y in ipairs({ 1, 3, 5, 7 }) do
	local hit = W:Raycast(Vector3.new(-121, y, -140), Vector3.new(45, 0, 0), params)
	if hit then
		table.insert(out, string.format("террейн на y=%d: препятствие x=%.1f (материал %s)", y, hit.Position.X, tostring(hit.Material)))
	else
		table.insert(out, string.format("y=%d: террейна нет", y))
	end
end

-- Материал под ногами в ключевых точках
for _, point in ipairs({ { -118, -140 }, { -114, -140 }, { -110, -140 }, { -106, -140 }, { -103, -140 }, { -100, -140 } }) do
	local x, z = point[1], point[2]
	local hit = W:Raycast(Vector3.new(x, 12, z), Vector3.new(0, -20, 0), params)
	if hit then
		table.insert(out, string.format("под точкой x=%d z=%d: террейн на y=%.2f (%s)", x, z, hit.Position.Y, tostring(hit.Material)))
	else
		table.insert(out, string.format("под точкой x=%d z=%d: террейна нет", x, z))
	end
end

-- Что видно лучами через проход по всем частям (для сравнения)
local all = RaycastParams.new()
all.FilterType = Enum.RaycastFilterType.Exclude
all.FilterDescendantsInstances = {}
for _, y in ipairs({ 3, 5 }) do
	local hit = W:Raycast(Vector3.new(-118, y, -140), Vector3.new(25, 0, 0), all)
	table.insert(out, string.format("луч (все части) y=%d: %s на x=%.1f",
		y, hit and hit.Instance:GetFullName() or "свободно", hit and hit.Position.X or 0))
end
return table.concat(out, "\n")
