--!nonstrict
-- probe_floor1v3_parts.lua — где на самом деле коллизии и меши зон.
local W = game.Workspace
local map = W:FindFirstChild("Floor1Map")
if not map then
	return "нет Floor1Map"
end
local out = {}
local pivot = map:GetPivot()
table.insert(out, string.format("пивот карты: %.1f %.1f %.1f", pivot.Position.X, pivot.Position.Y, pivot.Position.Z))

for _, zoneName in ipairs({ "street", "rest1", "bridge", "armory", "plaza" }) do
	local zone = map:FindFirstChild(zoneName)
	if not zone then
		table.insert(out, zoneName .. ": нет зоны")
		continue
	end
	local col = zone:FindFirstChild("Collision")
	local vis = zone:FindFirstChild("Visual")
	local colY, colN, colQuery = {}, 0, 0
	if col then
		for _, part in ipairs(col:GetDescendants()) do
			if part:IsA("BasePart") then
				colN += 1
				if part.CanQuery then
					colQuery += 1
				end
				if colN <= 3 then
					table.insert(colY, string.format("%s y=%.1f (%.1f×%.1f×%.1f) collide=%s query=%s",
						part.Name, part.Position.Y, part.Size.X, part.Size.Y, part.Size.Z,
						tostring(part.CanCollide), tostring(part.CanQuery)))
				end
			end
		end
	end
	local visN, visY = 0, nil
	if vis then
		for _, part in ipairs(vis:GetDescendants()) do
			if part:IsA("MeshPart") then
				visN += 1
				if not visY then
					visY = part.Position.Y
				end
			end
		end
	end
	table.insert(out, string.format("%s: коллизий %d (с CanQuery %d), мешей %d%s",
		zoneName, colN, colQuery, visN, visY and string.format(", первый меш y=%.1f", visY) or ""))
	for _, line in ipairs(colY) do
		table.insert(out, "    " .. line)
	end
end
return table.concat(out, "\n")
