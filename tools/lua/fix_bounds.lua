--!nonstrict
-- fix_bounds.lua — все «Fix_*» невидимые коллизии карты: где стоят и какие.
local W = game.Workspace
local out = {}
local list = {}
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("BasePart") and string.find(d.Name, "^Fix_") then
		local s = d.Size
		table.insert(list, string.format("%s | %.1f %.1f %.1f | %.1f×%.1f×%.1f | коллизия=%s",
			d:GetFullName(), d.Position.X, d.Position.Y, d.Position.Z,
			s.X, s.Y, s.Z, tostring(d.CanCollide)))
	end
end
table.sort(list)
table.insert(out, "частей Fix_*: " .. #list)
for i = 1, math.min(#list, 30) do
	table.insert(out, "  " .. list[i])
end

-- Печати памяти (создаются в рантайме)
local seals = 0
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("BasePart") and d:GetAttribute("Seal") then
		seals += 1
		table.insert(out, string.format("  ПЕЧАТЬ %s | %.1f %.1f %.1f | %.1f×%.1f×%.1f",
			d:GetFullName(), d.Position.X, d.Position.Y, d.Position.Z,
			d.Size.X, d.Size.Y, d.Size.Z))
	end
end
table.insert(out, "печатей памяти: " .. seals)
return table.concat(out, "\n")
