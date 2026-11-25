--!nonstrict
-- clear_doorway.lua — убирает невидимые запечённые коллизии в проёмах ворот.
-- Проверяем объём проёма: части с CanCollide=true и прозрачные.
local W = game.Workspace
local out = {}

local gates = { "Gate_BarbS", "Gate_BarbN" }

local function findGate(name: string)
	for _, d in ipairs(W:GetDescendants()) do
		if d:IsA("Model") and d.Name == name then
			return d
		end
	end
	return nil
end

for _, name in ipairs(gates) do
	local gate = findGate(name)
	if not gate then
		table.insert(out, name .. ": модели нет")
		continue
	end
	local center = gate:GetPivot().Position
	-- Объём проёма чуть шире самой решётки
	local size = Vector3.new(11, 6, 6)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { gate }
	local parts = W:GetPartBoundsInBox(CFrame.new(center), size, params)

	local blockers = {}
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") and part.CanCollide and part.Transparency >= 0.9 then
			table.insert(blockers, part)
		end
	end
	table.insert(out, ("%s (%d, %.1f, %.1f): невидимых коллизий в проёме %d"):format(
		name, math.floor(center.X), center.Y, center.Z, #blockers))
	for _, part in ipairs(blockers) do
		table.insert(out, string.format(
			"  убрана: %s size %.1f%.1f%.1f", part:GetFullName(),
			part.Size.X, part.Size.Y, part.Size.Z))
		part.CanCollide = false
		part:SetAttribute("RemovedBlocker", true)
	end
end

return table.concat(out, "\n")
