--!nonstrict
-- walk_log.lua — пошагово ведём героя и печатаем прогресс по X.
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

local character = player.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if not root or not humanoid then
	return table.concat(out, "\n") .. "\nнет персонажа"
end

local function walk(label: string, startX: number, targetX: number)
	root.CFrame = CFrame.new(startX, 3, -140)
	root.AssemblyLinearVelocity = Vector3.zero
	humanoid.WalkSpeed = 16
	task.wait(1.2)
	local x0 = root.Position.X
	humanoid:MoveTo(Vector3.new(targetX, 3, -140))
	local trace = {}
	for i = 1, 12 do
		task.wait(0.5)
		table.insert(trace, string.format("%.1f", root.Position.X))
	end
	humanoid:MoveTo(root.Position)
	table.insert(out, string.format("%s: старт %.1f → %s (дошёл %.1f)", label, x0, table.concat(trace, " "), root.Position.X))
end

walk("от костра", -118, -95)
walk("из середины", -110, -90)
walk("перед мостом", -105, -88)
return table.concat(out, "\n")
