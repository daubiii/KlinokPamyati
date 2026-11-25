--!nonstrict
-- walk_test.lua — открываем решётки вручную, ведём героя через проём,
-- затем ищем, что его остановило (все коллизии на пути).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local W = game.Workspace
local player = Players:GetPlayers()[1]
if not player then
	return "нет игроков"
end
local cmd = ServerStorage.KlinokDebug.Cmd
local out = {}

table.insert(out, "floor 1: " .. tostring(cmd:Invoke("floor 1")))
task.wait(3)

-- Открыть обе решётки: погасить их коллайдеры и поднять модели
local function openGate(name: string)
	for _, d in ipairs(W:GetDescendants()) do
		if d:IsA("Model") and d.Name == name then
			for _, part in ipairs(d:GetDescendants()) do
				if part:IsA("BasePart") and part.Transparency >= 0.99 then
					part.CanCollide = false
				elseif part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
			d:PivotTo(d:GetPivot() + Vector3.new(0, 10, 0))
			return true
		end
	end
	return false
end
table.insert(out, "Gate_BarbS открыта: " .. tostring(openGate("Gate_BarbS")))
table.insert(out, "Gate_BarbN открыта: " .. tostring(openGate("Gate_BarbN")))

-- Погасить заглушки в проёмах (по сигнатуре)
local function killFillers()
	local n = 0
	for _, d in ipairs(W:GetDescendants()) do
		if d:IsA("BasePart") and d.CanCollide and d.Transparency >= 0.9 then
			local s = d.Size
			if s.Y >= 3 and s.Y <= 5 and s.Z >= 3 and s.Z <= 5 and s.X >= 9 and s.X <= 13 then
				d.CanCollide = false
				n += 1
			end
		end
	end
	return n
end
table.insert(out, "погашено заглушек: " .. killFillers())

-- Поставить героя в барбакан и вести на север
local character = player.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if not root or not humanoid then
	return table.concat(out, "\n") .. "\nнет персонажа"
end
root.CFrame = CFrame.new(-120, 3, -95)
root.AssemblyLinearVelocity = Vector3.zero
task.wait(1)
local startPos = root.Position
humanoid:MoveTo(Vector3.new(-120, 3, -140))
task.wait(6)
local endPos = root.Position
table.insert(out, string.format("идти с %.1f,%.1f,%.1f → дошёл до %.1f,%.1f,%.1f (сдвиг %.1f)",
	startPos.X, startPos.Y, startPos.Z, endPos.X, endPos.Y, endPos.Z, (endPos - startPos).Magnitude))
humanoid:MoveTo(endPos)

-- Что стоит на пути: коллизии в коридоре от z=-100 до z=-140
local obstacles = {}
for z = -100, -140, -4 do
	local center = CFrame.new(-120, 5, z)
	local parts = W:GetPartBoundsInBox(center, Vector3.new(8, 8, 4))
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") and part.CanCollide then
			local key = part:GetFullName()
			if not obstacles[key] then
				obstacles[key] = string.format("%s | z=%.1f | size %.1f%.1f%.1f | transp %.2f",
					key, part.Position.Z, part.Size.X, part.Size.Y, part.Size.Z, part.Transparency)
			end
		end
	end
end
local list = {}
for _, v in pairs(obstacles) do
	table.insert(list, v)
end
table.sort(list)
table.insert(out, "коллизий на пути: " .. #list)
for i = 1, math.min(#list, 20) do
	table.insert(out, "  " .. list[i])
end
return table.concat(out, "\n")
