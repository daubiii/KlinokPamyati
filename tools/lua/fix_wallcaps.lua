--!nonstrict
-- fix_wallcaps.lua — гасит невидимые WallCap в проёме моста (x≈-105, z -146..-134).
-- Только в полосе моста: стены по бокам не трогаем.
local W = game.Workspace
local out = {}
local folder = W:FindFirstChild("Floor1Map")
local caps = folder and folder:FindFirstChild("WallCaps")
if not caps then
	return "нет WallCaps"
end

local xMin, xMax = -107.5, -102.5
local zMin, zMax = -146.5, -133.5
local killed = 0
for _, d in ipairs(caps:GetDescendants()) do
	if d:IsA("BasePart") and d.CanCollide then
		local p, s = d.Position, d.Size
		local halfX, halfZ = s.X / 2, s.Z / 2
		local overlapsX = (p.X + halfX) > xMin and (p.X - halfX) < xMax
		local overlapsZ = (p.Z + halfZ) > zMin and (p.Z - halfZ) < zMax
		if overlapsX and overlapsZ then
			d.CanCollide = false
			d:SetAttribute("DoorwayFiller", true)
			killed += 1
			table.insert(out, string.format("погашен %s | %.1f %.1f %.1f | %.1f×%.1f×%.1f",
				d.Name, p.X, p.Y, p.Z, s.X, s.Y, s.Z))
		end
	end
end
table.insert(out, "погашено WallCap: " .. killed)
return table.concat(out, "\n")
