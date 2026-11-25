--!nonstrict
-- fix_all_gates.lua — у всех решёток Gate_* гасит запечённые «заглушки проёма»:
-- невидимые коллизии, лежащие ровно в центре решётки. Сама решётка имеет свою
-- коллизию, ей управляет FloorMap.setGate, поэтому заглушка только мешает пройти.
local W = game.Workspace
local out = {}

local gates = {}
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("Model") and string.find(d.Name, "^Gate_") then
		table.insert(gates, d)
	end
end
table.insert(out, "решёток найдено: " .. #gates)

local total = 0
for _, gate in ipairs(gates) do
	local center = gate:GetPivot().Position
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { gate }
	local size = Vector3.new(4, 10, 4) -- узкий объём вокруг центра проёма
	local parts = W:GetPartBoundsInBox(CFrame.new(center), size, params)
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") and part.CanCollide and part.Transparency >= 0.9 and part.CanQuery then
			-- только запечённые коллизии карты, а не части самой решётки
			if not part:IsDescendantOf(gate) then
				local s = part.Size
				part.CanCollide = false
				part:SetAttribute("DoorwayFiller", true)
				total += 1
				table.insert(out, string.format(
					"%s ← %s (%.1f×%.1f×%.1f)",
					gate.Name, part:GetFullName(), s.X, s.Y, s.Z))
			end
		end
	end
end
table.insert(out, "погашено заглушек: " .. total)
return table.concat(out, "\n")
