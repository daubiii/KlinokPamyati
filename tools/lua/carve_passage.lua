--!nonstrict
-- carve_passage.lua — вырезает проём в стене, которая реально перекрывает проход
-- за решёткой. Работает по проходу-коридору: берём габарит решётки, продолжаем
-- его наружу вдоль оси прохода и режем только те части, которые этот коридор
-- перекрывают и достаточно велики (тонкие стойки не трогаем).
--
-- Запускать в Edit. Аргумент — имя решётки (по умолчанию Gate_TowerExit).
local W = game.Workspace
local gateName = _G.__GATE_NAME or "Gate_TowerExit"
local out = {}

local gate
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("Model") and d.Name == gateName then
		gate = d
		break
	end
end
if not gate then
	return "нет модели " .. gateName
end

-- Габарит решётки
local minV = Vector3.new(math.huge, math.huge, math.huge)
local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
for _, part in ipairs(gate:GetDescendants()) do
	if part:IsA("BasePart") then
		local p, h = part.Position, part.Size / 2
		minV = Vector3.new(math.min(minV.X, p.X - h.X), math.min(minV.Y, p.Y - h.Y), math.min(minV.Z, p.Z - h.Z))
		maxV = Vector3.new(math.max(maxV.X, p.X + h.X), math.max(maxV.Y, p.Y + h.Y), math.max(maxV.Z, p.Z + h.Z))
	end
end
-- Ось прохода — самая тонкая сторона габарита
local size = maxV - minV
local axis = "x"
if size.Z < size.X then
	axis = "z"
end
local margin = 0.8
local gapMinY, gapMaxY = minV.Y - margin, maxV.Y + margin
local gapMinZ, gapMaxZ = minV.Z - margin, maxV.Z + margin
local gapMinX, gapMaxX = minV.X - margin, maxV.X + margin
table.insert(out, string.format("решётка %s: габарит %.1f×%.1f×%.1f, ось прохода %s",
	gateName, size.X, size.Y, size.Z, axis))

-- Ищем блокирующие стены в коридоре: 26 стадов вдоль оси прохода
local center = (minV + maxV) / 2
local searchSize = axis == "x" and Vector3.new(30, 10, 10) or Vector3.new(10, 10, 30)
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { gate }

local carved = 0
for _, part in ipairs(W:GetPartBoundsInBox(CFrame.new(center), searchSize, params)) do
	if part:IsA("BasePart") and part.CanCollide and part.Transparency >= 0.9 then
		local s = part.Size
		-- блокирующая стена: тонкая вдоль оси прохода и крупная в проёме
		local thin = axis == "x" and s.X <= 2 or axis == "z" and s.Z <= 2
		local bigEnough = s.Y >= 6 and (axis == "x" and s.Z >= 6 or axis == "z" and s.X >= 6)
		if thin and bigEnough then
			local p = part.Position
			local parent = part.Parent
			local template = part

			local function piece(pos: Vector3, pieceSize: Vector3)
				local newPart = template:Clone()
				newPart.Name = template.Name .. "_door"
				newPart.Anchored = true
				newPart.CanCollide = true
				newPart.Position = pos
				newPart.Size = pieceSize
				newPart:SetAttribute("Carved", true)
				newPart.Parent = parent
			end

			if axis == "x" then
				local yMin, yMax = p.Y - s.Y / 2, p.Y + s.Y / 2
				local zMin, zMax = p.Z - s.Z / 2, p.Z + s.Z / 2
				if gapMinZ > zMin then
					piece(Vector3.new(p.X, p.Y, (zMin + gapMinZ) / 2), Vector3.new(s.X, s.Y, gapMinZ - zMin))
				end
				if gapMaxZ < zMax then
					piece(Vector3.new(p.X, p.Y, (gapMaxZ + zMax) / 2), Vector3.new(s.X, s.Y, zMax - gapMaxZ))
				end
				if gapMinY > yMin then
					piece(Vector3.new(p.X, (yMin + gapMinY) / 2, p.Z), Vector3.new(s.X, gapMinY - yMin, s.Z))
				end
				if gapMaxY < yMax then
					piece(Vector3.new(p.X, (gapMaxY + yMax) / 2, p.Z), Vector3.new(s.X, yMax - gapMaxY, s.Z))
				end
			else
				local yMin, yMax = p.Y - s.Y / 2, p.Y + s.Y / 2
				local xMin, xMax = p.X - s.X / 2, p.X + s.X / 2
				if gapMinX > xMin then
					piece(Vector3.new((xMin + gapMinX) / 2, p.Y, p.Z), Vector3.new(gapMinX - xMin, s.Y, s.Z))
				end
				if gapMaxX < xMax then
					piece(Vector3.new((gapMaxX + xMax) / 2, p.Y, p.Z), Vector3.new(xMax - gapMaxX, s.Y, s.Z))
				end
				if gapMinY > yMin then
					piece(Vector3.new(p.X, (yMin + gapMinY) / 2, p.Z), Vector3.new(s.X, gapMinY - yMin, s.Z))
				end
				if gapMaxY < yMax then
					piece(Vector3.new(p.X, (gapMaxY + yMax) / 2, p.Z), Vector3.new(s.X, yMax - gapMaxY, s.Z))
				end
			end

			part:Destroy()
			carved += 1
			table.insert(out, string.format("прорезана стена %s (%.1f×%.1f×%.1f) в x=%.1f z=%.1f",
				part.Name, s.X, s.Y, s.Z, p.X, p.Z))
		end
	end
end
table.insert(out, "прорезано стен: " .. carved)
return table.concat(out, "\n")
