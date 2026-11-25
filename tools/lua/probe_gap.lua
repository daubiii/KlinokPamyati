--!nonstrict
-- probe_gap.lua — все невидимые коллизии в полосе между костром и мостом.
local W = game.Workspace
local out = {}
local seen = {}
for _, part in ipairs(W:GetPartBoundsInBox(CFrame.new(-112, 6, -140), Vector3.new(30, 20, 34))) do
	if part:IsA("BasePart") and part.CanCollide then
		local key = part:GetFullName()
		if not seen[key] then
			local s = part.Size
			local transparent = part.Transparency >= 0.9 and "невид" or "ВИДИМ"
			seen[key] = string.format("%s | %.1f %.1f %.1f | %.1f×%.1f×%.1f | %s",
				key, part.Position.X, part.Position.Y, part.Position.Z, s.X, s.Y, s.Z, transparent)
		end
	end
end
local list = {}
for _, v in pairs(seen) do
	table.insert(list, v)
end
table.sort(list)
table.insert(out, "коллизий в полосе: " .. #list)
for i = 1, math.min(#list, 40) do
	table.insert(out, "  " .. list[i])
end
return table.concat(out, "\n")
