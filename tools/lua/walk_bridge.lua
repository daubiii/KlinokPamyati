--!nonstrict
-- walk_bridge.lua — ведём героя от костра к мосту и находим, где он встал.
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

root.CFrame = CFrame.new(-120, 2, -140)
root.AssemblyLinearVelocity = Vector3.zero
humanoid.WalkSpeed = 20
task.wait(1.5)
local from = root.Position
humanoid:MoveTo(Vector3.new(-90, 2, -140))
task.wait(9)
local to = root.Position
humanoid:MoveTo(to)
humanoid.WalkSpeed = 16
table.insert(out, string.format("от %.1f,%.1f,%.1f до %.1f,%.1f,%.1f (прошёл по X %.1f)",
	from.X, from.Y, from.Z, to.X, to.Y, to.Z, to.X - from.X))

-- Что стоит вокруг точки остановки
local seen = {}
for _, part in ipairs(W:GetPartBoundsInBox(CFrame.new(to.X + 1.5, to.Y, to.Z), Vector3.new(5, 8, 8))) do
	if part:IsA("BasePart") and part.CanCollide then
		local key = part:GetFullName()
		if not seen[key] then
			local s = part.Size
			seen[key] = string.format("%s | %.1f %.1f %.1f | %.1f×%.1f×%.1f | transp %.2f",
				key, part.Position.X, part.Position.Y, part.Position.Z, s.X, s.Y, s.Z, part.Transparency)
		end
	end
end
local list = {}
for _, v in pairs(seen) do
	table.insert(list, v)
end
table.sort(list)
table.insert(out, "коллизий у точки остановки: " .. #list)
for i = 1, math.min(#list, 15) do
	table.insert(out, "  " .. list[i])
end
return table.concat(out, "\n")
