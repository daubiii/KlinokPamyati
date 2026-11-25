--!nonstrict
-- walk_tower2.lua — тест прохода: ставим героя внутри башни у самой решётки,
-- ведём наружу вдоль оси прохода и смотрим, пересёк ли он стену.
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
table.insert(out, "zone tower: " .. tostring(cmd:Invoke("zone tower")))
task.wait(3)

-- Решётка
local gate
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("Model") and d.Name == "Gate_TowerExit" then
		gate = d
		break
	end
end
if not gate then
	return table.concat(out, "\n") .. "\nнет Gate_TowerExit"
end
local g = gate:GetPivot().Position
table.insert(out, string.format("решётка: %.1f %.1f %.1f", g.X, g.Y, g.Z))

-- Открыть её (погасить коллайдеры и поднять)
for _, part in ipairs(gate:GetDescendants()) do
	if part:IsA("BasePart") then
		part.CanCollide = false
	end
end
gate:PivotTo(gate:GetPivot() + Vector3.new(0, 10, 0))

local character = player.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if not root or not humanoid then
	return table.concat(out, "\n") .. "\nнет персонажа"
end

-- Внутри башни: чуть правее решётки по оси X (проход вдоль X)
local startPos = Vector3.new(g.X + 5, g.Y - 2, g.Z)
root.CFrame = CFrame.new(startPos)
root.AssemblyLinearVelocity = Vector3.zero
humanoid.WalkSpeed = 20
task.wait(1.5)
local from = root.Position
humanoid:MoveTo(Vector3.new(g.X - 16, g.Y - 2, g.Z))
task.wait(7)
local to = root.Position
humanoid:MoveTo(to)
humanoid.WalkSpeed = 16
table.insert(out, string.format("с %.1f,%.1f,%.1f до %.1f,%.1f,%.1f — сдвиг по X %.1f",
	from.X, from.Y, from.Z, to.X, to.Y, to.Z, from.X - to.X))
table.insert(out, to.X < g.X - 3 and "ПРОХОД ОТКРЫТ" or "ПРОХОД ЗАКРЫТ")
return table.concat(out, "\n")
