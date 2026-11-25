--!nonstrict
-- find_wall.lua — ищет невидимые коллизии в проходе Барбакана (север/юг).
local W = game.Workspace
local out = {}

-- Область барбакана: x -157..-83, z -127..-47
local function inArea(p: Vector3): boolean
	return p.X >= -170 and p.X <= -70 and p.Z >= -140 and p.Z <= -40
end

local found = 0
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("BasePart") and d.CanCollide and d.Transparency >= 0.9 and inArea(d.Position) then
		found += 1
		if found <= 30 then
			table.insert(out, string.format(
				"%s | %s | поз %.1f %.1f %.1f | размер %.1f %.1f %.1f | CanQuery=%s",
				d:GetFullName(),
				d.ClassName,
				d.Position.X, d.Position.Y, d.Position.Z,
				d.Size.X, d.Size.Y, d.Size.Z,
				tostring(d.CanQuery)
			))
		end
	end
end
table.insert(out, 1, "невидимых коллизий в области Барбакана: " .. found)
return table.concat(out, "\n")
