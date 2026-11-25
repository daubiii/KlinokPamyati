--!nonstrict
-- wallcaps.lua — что за WallCap перекрывает проход у моста (x≈-106, z=-140).
local W = game.Workspace
local out = {}
local folder = W:FindFirstChild("Floor1Map")
local caps = folder and folder:FindFirstChild("WallCaps")
if not caps then
	return "нет папки WallCaps"
end

local all = {}
for _, d in ipairs(caps:GetDescendants()) do
	if d:IsA("BasePart") then
		table.insert(all, d)
	end
end
table.insert(out, "частей в WallCaps: " .. #all)

-- Те, что рядом с проходом
local near = {}
for _, d in ipairs(all) do
	local p = d.Position
	if math.abs(p.X + 106) <= 8 and math.abs(p.Z + 140) <= 12 then
		table.insert(near, string.format(
			"%s | %.1f %.1f %.1f | %.1f×%.1f×%.1f | transp %.2f | коллизия=%s | CanQuery=%s",
			d:GetFullName(), p.X, p.Y, p.Z, d.Size.X, d.Size.Y, d.Size.Z,
			d.Transparency, tostring(d.CanCollide), tostring(d.CanQuery)))
	end
end
table.sort(near)
table.insert(out, "рядом с проходом: " .. #near)
for i = 1, math.min(#near, 15) do
	table.insert(out, "  " .. near[i])
end
return table.concat(out, "\n")
