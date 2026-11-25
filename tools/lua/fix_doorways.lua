--!nonstrict
-- fix_doorways.lua — аккуратно: возвращает все снятые коллизии, затем гасит
-- ТОЛЬКО запечённые «заглушки проёма» — части шириной с решётку (≈10) в её центре.
-- Остальные (косяки, стены, полы) остаются на месте.
local W = game.Workspace
local out = {}

-- 1. Вернуть всё, что сняли прошлым запуском
local restored = 0
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("BasePart") and d:GetAttribute("RemovedBlocker") then
		d.CanCollide = true
		d:SetAttribute("RemovedBlocker", nil)
		restored += 1
	end
end
table.insert(out, "восстановлено коллизий: " .. restored)

-- 2. Заглушки проёма: в моделях ворот, ширина 9..11, высота 3..5, глубина 3..5
local function findGate(name: string)
	for _, d in ipairs(W:GetDescendants()) do
		if d:IsA("Model") and d.Name == name then
			return d
		end
	end
	return nil
end

for _, name in ipairs({ "Gate_BarbS", "Gate_BarbN" }) do
	local gate = findGate(name)
	if not gate then
		table.insert(out, name .. ": нет модели")
		continue
	end
	local center = gate:GetPivot().Position
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { gate }
	local parts = W:GetPartBoundsInBox(CFrame.new(center), Vector3.new(11, 8, 6), params)
	local killed = 0
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") and part.CanCollide and part.Transparency >= 0.9 then
			local s = part.Size
			local wide = s.X >= 9 and s.X <= 11
			local tall = s.Y >= 3 and s.Y <= 5
			if wide and tall then
				part.CanCollide = false
				part:SetAttribute("DoorwayFiller", true)
				killed += 1
				table.insert(out, string.format(
					"  заглушка проёма погашена: %s size %.1f%.1f%.1f",
					part:GetFullName(), s.X, s.Y, s.Z))
			end
		end
	end
	table.insert(out, ("%s: погашено %d"):format(name, killed))
end

return table.concat(out, "\n")
