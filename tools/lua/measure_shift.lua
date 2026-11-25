--!nonstrict
-- measure_shift.lua — на сколько коллизии карты выше мешей (по границам зон).
local W = game.Workspace
local map = W:FindFirstChild("Floor1Map")
if not map then
	return "нет Floor1Map"
end
local out = {}
table.insert(out, string.format("%-11s %10s %10s %10s %10s", "зона", "меши minY", "колл minY", "меши maxY", "колл maxY"))
local deltas = {}
for _, zone in ipairs(map:GetChildren()) do
	local vis = zone:FindFirstChild("Visual")
	local col = zone:FindFirstChild("Collision")
	if vis and col then
		local vMin, vMax, cMin, cMax = math.huge, -math.huge, math.huge, -math.huge
		local vN, cN = 0, 0
		for _, d in ipairs(vis:GetDescendants()) do
			if d:IsA("BasePart") then
				vN += 1
				vMin = math.min(vMin, d.Position.Y - d.Size.Y / 2)
				vMax = math.max(vMax, d.Position.Y + d.Size.Y / 2)
			end
		end
		for _, d in ipairs(col:GetDescendants()) do
			if d:IsA("BasePart") then
				cN += 1
				cMin = math.min(cMin, d.Position.Y - d.Size.Y / 2)
				cMax = math.max(cMax, d.Position.Y + d.Size.Y / 2)
			end
		end
		if vN > 0 and cN > 0 then
			table.insert(deltas, cMin - vMin)
			table.insert(out, string.format("%-11s %10.1f %10.1f %10.1f %10.1f", zone.Name, vMin, cMin, vMax, cMax))
		end
	end
end
if #deltas > 0 then
	table.sort(deltas)
	local median = deltas[math.floor(#deltas / 2) + 1]
	table.insert(out, string.format("медиана сдвига коллизий: %.2f (коллизии выше мешей на столько)", median))
end
return table.concat(out, "\n")
