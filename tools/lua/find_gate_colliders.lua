--!nonstrict
-- find_gate_colliders.lua — что мешает пройти через конкретную решётку:
-- ищем невидимые коллизии в объёме проёма.
local W = game.Workspace
local gateName = "Gate_BarbN"
local out = {}

local gate
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("Model") and d.Name == gateName then
		gate = d
		break
	end
end
if not gate then
	return "нет модели " .. gateName
end

local pivot = gate:GetPivot()
table.insert(out, ("%s: позиция %.1f %.1f %.1f"):format(gateName, pivot.Position.X, pivot.Position.Y, pivot.Position.Z))
local parts = {}
for _, d in ipairs(gate:GetDescendants()) do
	if d:IsA("BasePart") then
		table.insert(parts, string.format(
			"%s %s %.1f%.1f%.1f size %.1f%.1f%.1f CanCollide=%s Transp=%.2f",
			d.Name, d.ClassName, d.Position.X, d.Position.Y, d.Position.Z,
			d.Size.X, d.Size.Y, d.Size.Z, tostring(d.CanCollide), d.Transparency
		))
	end
end
table.insert(out, "внутри модели: " .. (#parts > 0 and table.concat(parts, " | ") or "нет частей"))

-- Коллизии рядом с проёмом (радиус 8 по XZ, ±8 по Y)
local center = pivot.Position
local near = {}
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("BasePart") and d.CanCollide and d:IsDescendantOf(gate.Parent.Parent) then
		local p = d.Position
		local dxz = Vector3.new(p.X - center.X, 0, p.Z - center.Z).Magnitude
		if dxz <= 9 and math.abs(p.Y - center.Y) <= 9 and not d:IsDescendantOf(gate) then
			table.insert(near, string.format(
				"%s | %.1f %.1f %.1f | size %.1f%.1f%.1f | transp %.2f",
				d:GetFullName(), p.X, p.Y, p.Z, d.Size.X, d.Size.Y, d.Size.Z, d.Transparency
			))
		end
	end
end
table.insert(out, "коллизий вокруг проёма: " .. #near)
for i = 1, math.min(#near, 15) do
	table.insert(out, "  " .. near[i])
end
return table.concat(out, "\n")
