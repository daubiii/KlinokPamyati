--!nonstrict
-- restore_and_fix_gates.lua
-- 1) Возвращает ВСЕ коллизии, которые трогали прошлые запуски.
-- 2) Гасит только «заглушки проёма»: невидимая коллизия ровно в центре решётки
--    размером примерно «ширина решётки × 3.5 × 4» (сигнатура запечённой заглушки).
local W = game.Workspace
local out = {}

-- 1. Откат
local restored = 0
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("BasePart") and (d:GetAttribute("DoorwayFiller") or d:GetAttribute("RemovedBlocker")) then
		d.CanCollide = true
		d:SetAttribute("DoorwayFiller", nil)
		d:SetAttribute("RemovedBlocker", nil)
		restored += 1
	end
end
table.insert(out, "откат: возвращено коллизий " .. restored)

-- 2. Точечно
local gates = {}
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("Model") and string.find(d.Name, "^Gate_") then
		table.insert(gates, d)
	end
end

local killed = 0
for _, gate in ipairs(gates) do
	local center = gate:GetPivot().Position
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { gate }
	local parts = W:GetPartBoundsInBox(CFrame.new(center), Vector3.new(3, 12, 3), params)
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") and part.CanCollide and part.Transparency >= 0.9 and not part:IsDescendantOf(gate) then
			local s = part.Size
			local filler = s.Y >= 3 and s.Y <= 5 and s.Z >= 3 and s.Z <= 5 and s.X >= 9 and s.X <= 13
			if filler then
				local p = part.Position
				local dxz = Vector3.new(p.X - center.X, 0, p.Z - center.Z).Magnitude
				if dxz <= 2.5 then
					part.CanCollide = false
					part:SetAttribute("DoorwayFiller", true)
					killed += 1
					table.insert(out, string.format("%s ← %s (%.1f×%.1f×%.1f) dxz=%.1f",
						gate.Name, part.Parent.Parent.Name, s.X, s.Y, s.Z, dxz))
				end
			end
		end
	end
end
table.insert(out, "погашено заглушек проёма: " .. killed)
return table.concat(out, "\n")
