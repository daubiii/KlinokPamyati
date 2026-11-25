--!nonstrict
-- probe_bridge.lua — что стоит между костром (x=-120) и мостом (x=-103) на z=-140.
local W = game.Workspace
local out = {}

-- Лучи вдоль +X на разных высотах
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = {}
for _, y in ipairs({ 3, 5, 7, 9, 11 }) do
	local origin = Vector3.new(-121, y, -140)
	local hit = W:Raycast(origin, Vector3.new(40, 0, 0), params)
	if hit then
		table.insert(out, string.format("y=%d: стоп %s на x=%.1f (%.1f×%.1f×%.1f, transp %.2f, коллизия %s)",
			y, hit.Instance.Name, hit.Position.X,
			hit.Instance.Size.X, hit.Instance.Size.Y, hit.Instance.Size.Z,
			hit.Instance.Transparency, tostring(hit.Instance.CanCollide)))
	else
		table.insert(out, string.format("y=%d: свободно", y))
	end
end

-- Все невидимые коллизии в коридоре
local seen = {}
for _, part in ipairs(W:GetPartBoundsInBox(CFrame.new(-112, 8, -140), Vector3.new(26, 22, 14))) do
	if part:IsA("BasePart") and part.CanCollide and part.Transparency >= 0.9 then
		local key = part:GetFullName()
		if not seen[key] then
			seen[key] = string.format("%s | %.1f %.1f %.1f | %.1f×%.1f×%.1f",
				key, part.Position.X, part.Position.Y, part.Position.Z,
				part.Size.X, part.Size.Y, part.Size.Z)
		end
	end
end
local list = {}
for _, v in pairs(seen) do
	table.insert(list, v)
end
table.sort(list)
table.insert(out, "невидимых коллизий в коридоре: " .. #list)
for i = 1, math.min(#list, 18) do
	table.insert(out, "  " .. list[i])
end
return table.concat(out, "\n")
