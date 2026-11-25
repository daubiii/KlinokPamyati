--!nonstrict
-- check_floor1v3_paths2.lua — проходы между зонами: телепорт в зону, затем шаг к следующей.
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

local function leg(label: string, zone: string, to: Vector3, seconds: number?)
	cmd:Invoke("zone " .. zone)
	task.wait(1.5)
	humanoid.WalkSpeed = 20
	humanoid.Health = humanoid.MaxHealth
	local start = root.Position
	humanoid:MoveTo(to)
	task.wait(seconds or 5)
	humanoid:MoveTo(root.Position)
	humanoid.WalkSpeed = 16
	local done = root.Position
	local moved = (Vector3.new(done.X - start.X, 0, done.Z - start.Z)).Magnitude
	local need = (Vector3.new(to.X - start.X, 0, to.Z - start.Z)).Magnitude
	table.insert(out, string.format("%-20s %.1f из %.1f (%d%%), HP %d",
		label, moved, need, math.floor(moved / math.max(need, 1) * 100), math.floor(humanoid.Health)))
end

leg("привал → мост", "rest1", Vector3.new(-100, 3, -140))
leg("мост → арсенал", "bridge", Vector3.new(-30, 3, -140), 7)
leg("галерея → двор", "gallery", Vector3.new(0, 3, -262), 7)
leg("двор → зал", "tower", Vector3.new(50, 3, -292), 7)
return table.concat(out, "\n")
