--!nonstrict
-- fix_map_shift.lua — сдвигает коллизии/динамику карты этажа 1 вниз на SHIFT,
-- не трогая Visual (меши уже стоят по FloorMapData).
-- Карта была вставлена из rbxmx на 32.5 стада выше нужного уровня.
local W = game.Workspace
local SHIFT = 32.5
local map = W:FindFirstChild("Floor1Map")
if not map then
	return "нет Floor1Map"
end

local function inVisual(instance): boolean
	local node = instance
	while node and node ~= map do
		if node.Name == "Visual" then
			return true
		end
		node = node.Parent
	end
	return false
end

local moved = 0
local offset = Vector3.new(0, -SHIFT, 0)
for _, d in ipairs(map:GetDescendants()) do
	if d:IsA("BasePart") and not inVisual(d) then
		d.CFrame = d.CFrame + offset
		moved += 1
	end
end

-- Проверка: границы мешей и коллизий после сдвига
local out = { ("сдвинуто частей: %d на %.1f вниз"):format(moved, SHIFT) }
for _, zoneName in ipairs({ "street", "rest1", "armory", "tower", "env" }) do
	local zone = map:FindFirstChild(zoneName)
	if zone then
		local vis = zone:FindFirstChild("Visual")
		local col = zone:FindFirstChild("Collision")
		local vMin, cMin = math.huge, math.huge
		if vis then
			for _, d in ipairs(vis:GetDescendants()) do
				if d:IsA("BasePart") then
					vMin = math.min(vMin, d.Position.Y - d.Size.Y / 2)
				end
			end
		end
		if col then
			for _, d in ipairs(col:GetDescendants()) do
				if d:IsA("BasePart") then
					cMin = math.min(cMin, d.Position.Y - d.Size.Y / 2)
				end
			end
		end
		table.insert(out, string.format("%-8s меши minY %.1f, коллизии minY %.1f", zoneName, vMin, cMin))
	end
end
return table.concat(out, "\n")
