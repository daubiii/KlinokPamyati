--!nonstrict
-- floor_check.lua — есть ли пол в проёме башни (иначе герой падает и не проходит).
local W = game.Workspace
local out = {}
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = {}

for _, x in ipairs({ 8, 6, 4, 2, 0, -2, -4, -6, -8 }) do
	local origin = Vector3.new(x, 26, -290)
	local hit = W:Raycast(origin, Vector3.new(0, -30, 0), params)
	if hit then
		table.insert(out, string.format("x=%d: пол на y=%.2f (%s, коллизия=%s)",
			x, hit.Position.Y, hit.Instance.Name, tostring(hit.Instance.CanCollide)))
	else
		table.insert(out, string.format("x=%d: пола нет (пустота)", x))
	end
end
return table.concat(out, "\n")
