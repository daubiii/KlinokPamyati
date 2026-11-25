--!nonstrict
-- carve_tower_door.lua — вырезает проём в сплошной невидимой стене башни.
-- Стена: Floor1Map.tower.Collision.Col (x≈0, 24×24) — проёма в ней нет.
-- Заменяем её тремя частями (лево/право/верх), оставляя проход по размеру решётки.
local W = game.Workspace
local out = {}

-- 1. Габариты решётки — по ним вырезаем
local gate
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("Model") and d.Name == "Gate_TowerExit" then
		gate = d
		break
	end
end
if not gate then
	return "нет Gate_TowerExit"
end
local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
for _, part in ipairs(gate:GetDescendants()) do
	if part:IsA("BasePart") then
		local p = part.Position
		local h = part.Size / 2
		minV = Vector3.new(math.min(minV.X, p.X - h.X), math.min(minV.Y, p.Y - h.Y), math.min(minV.Z, p.Z - h.Z))
		maxV = Vector3.new(math.max(maxV.X, p.X + h.X), math.max(maxV.Y, p.Y + h.Y), math.max(maxV.Z, p.Z + h.Z))
	end
end
table.insert(out, string.format("решётка: x %.2f..%.2f, y %.2f..%.2f, z %.2f..%.2f",
	minV.X, maxV.X, minV.Y, maxV.Y, minV.Z, maxV.Z))

local margin = 0.6
local gapMinZ, gapMaxZ = minV.Z - margin, maxV.Z + margin
local gapTopY = maxV.Y + margin
local gapBottomY = minV.Y - margin

-- 2. Ищем сплошные стены рядом
local center = (minV + maxV) / 2
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { gate }
local walls = {}
for _, part in ipairs(W:GetPartBoundsInBox(CFrame.new(center), Vector3.new(40, 40, 40), params)) do
	if part:IsA("BasePart") and part.CanCollide and part.Transparency >= 0.9 then
		local s = part.Size
		if s.Y >= 15 and s.X <= 2 and (s.Y >= 15 or s.Z >= 15) then
			table.insert(walls, part)
		end
	end
end
table.insert(out, "сплошных стен найдено: " .. #walls)

for _, wall in ipairs(walls) do
	local p = wall.Position
	local s = wall.Size
	-- ось толщины — та, где размер меньше 2
	local thickX = s.X <= 2
	local parent = wall.Parent
	local template = wall
	local function piece(pos: Vector3, size: Vector3): Instance
		local part = template:Clone()
		part.Name = template.Name .. "_carved"
		part.Anchored = true
		part.CanCollide = true
		part.Position = pos
		part.Size = size
		part:SetAttribute("DoorwayFiller", nil)
		part:SetAttribute("Carved", true)
		part.Parent = parent
		return part
	end

	if thickX then
		-- стена в плоскости YZ: куски по Z и верх
		local halfY = s.Y / 2
		local halfZ = s.Z / 2
		local yMin, yMax = p.Y - halfY, p.Y + halfY
		local zMin, zMax = p.Z - halfZ, p.Z + halfZ
		local leftZ = (zMin + gapMinZ) / 2
		local rightZ = (gapMaxZ + zMax) / 2
		if gapMinZ > zMin then
			piece(Vector3.new(p.X, p.Y, leftZ), Vector3.new(s.X, s.Y, gapMinZ - zMin))
		end
		if gapMaxZ < zMax then
			piece(Vector3.new(p.X, p.Y, rightZ), Vector3.new(s.X, s.Y, zMax - gapMaxZ))
		end
		if gapBottomY > yMin then
			piece(Vector3.new(p.X, (yMin + gapBottomY) / 2, p.Z), Vector3.new(s.X, gapBottomY - yMin, s.Z))
		end
		if gapTopY < yMax then
			piece(Vector3.new(p.X, (gapTopY + yMax) / 2, p.Z), Vector3.new(s.X, yMax - gapTopY, s.Z))
		end
		wall:Destroy()
		table.insert(out, string.format("вырезан проём в стене x≈%.1f (было %.1f×%.1f×%.1f)", p.X, s.X, s.Y, s.Z))
	else
		table.insert(out, string.format("пропущена стена x≈%.1f (толщина не по X): %.1f×%.1f×%.1f", p.X, s.X, s.Y, s.Z))
	end
end

return table.concat(out, "\n")
