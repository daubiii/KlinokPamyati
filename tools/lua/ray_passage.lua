--!nonstrict
-- ray_passage.lua — проверка проёма лучами: на разной высоте через проход.
local W = game.Workspace
local out = {}

local z = -290
local fromX, toX = 9, -9
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = {}

for _, y in ipairs({ 17, 18, 19, 20, 21, 22 }) do
	local origin = Vector3.new(fromX, y, z)
	local direction = Vector3.new(toX - fromX, 0, 0)
	local hit = W:Raycast(origin, direction, params)
	if hit then
		table.insert(out, string.format("y=%d: препятствие %s на x=%.2f (размер %.1f×%.1f×%.1f, канарейка Collide=%s)",
			y, hit.Instance.Name, hit.Position.X,
			hit.Instance.Size.X, hit.Instance.Size.Y, hit.Instance.Size.Z,
			tostring(hit.Instance.CanCollide)))
	else
		table.insert(out, string.format("y=%d: свободно", y))
	end
end
return table.concat(out, "\n")
