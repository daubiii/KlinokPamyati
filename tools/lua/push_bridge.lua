--!nonstrict
-- push_bridge.lua — толкаем героя от костра к мосту скоростью (обход MoveTo).
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
table.insert(out, string.format("до: Anchored=%s WalkSpeed=%.1f Sit=%s", tostring(root.Anchored), humanoid.WalkSpeed, tostring(humanoid.Sit)))

root.CFrame = CFrame.new(-118, 2, -140)
root.AssemblyLinearVelocity = Vector3.zero
humanoid.WalkSpeed = 16
humanoid.JumpPower = 50
task.wait(1)
local from = root.Position

-- Полтора секунды толкаем в +X
for _ = 1, 15 do
	root.AssemblyLinearVelocity = Vector3.new(20, root.AssemblyLinearVelocity.Y, 0)
	task.wait(0.1)
end
local to = root.Position
table.insert(out, string.format("толчок: с %.1f,%.1f,%.1f до %.1f,%.1f,%.1f (X %.1f)",
	from.X, from.Y, from.Z, to.X, to.Y, to.Z, to.X - from.X))

-- Что впереди
local seen = {}
for _, part in ipairs(W:GetPartBoundsInBox(CFrame.new(to.X + 2, to.Y, to.Z), Vector3.new(6, 8, 10))) do
	if part:IsA("BasePart") and part.CanCollide and not part:IsDescendantOf(character) then
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
table.insert(out, "впереди коллизий: " .. #list)
for i = 1, math.min(#list, 15) do
	table.insert(out, "  " .. list[i])
end
return table.concat(out, "\n")
