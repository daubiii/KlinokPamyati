--!nonstrict
-- check_floor1v3_paths.lua — проходимость ключевых стыков новой карты.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local player = Players:GetPlayers()[1]
if not player then
	return "нет игроков"
end
local cmd = ServerStorage.KlinokDebug.Cmd
local out = {}

table.insert(out, "floor 1: " .. tostring(cmd:Invoke("floor 1")))
task.wait(3)

local character = player.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if not root or not humanoid then
	return table.concat(out, "\n") .. "\nнет персонажа"
end

local function walk(label: string, from: Vector3, to: Vector3, seconds: number?)
	root.CFrame = CFrame.new(from)
	root.AssemblyLinearVelocity = Vector3.zero
	humanoid.WalkSpeed = 20
	humanoid.Health = humanoid.MaxHealth
	task.wait(1.2)
	local start = root.Position
	humanoid:MoveTo(to)
	task.wait(seconds or 6)
	humanoid:MoveTo(root.Position)
	humanoid.WalkSpeed = 16
	local done = root.Position
	local moved = (Vector3.new(done.X - start.X, 0, done.Z - start.Z)).Magnitude
	local need = (Vector3.new(to.X - start.X, 0, to.Z - start.Z)).Magnitude
	table.insert(out, string.format("%-22s прошёл %.1f из %.1f (%d%%) HP %d",
		label, moved, need, math.floor(moved / math.max(need, 1) * 100), math.floor(humanoid.Health)))
end

-- привал → мост (тут раньше стояла невидимая стена)
walk("привал → мост", Vector3.new(-120, 4, -129), Vector3.new(-100, 4, -138))
-- мост → арсенал
walk("мост → арсенал", Vector3.new(-100, 4, -140), Vector3.new(-40, 4, -140), 8)
-- галерея → двор башни
walk("галерея → двор", Vector3.new(0, 5, -168), Vector3.new(0, 4, -262), 8)
-- двор → зал
walk("двор → зал", Vector3.new(10, 4, -270), Vector3.new(50, 4, -292), 8)

return table.concat(out, "\n")
