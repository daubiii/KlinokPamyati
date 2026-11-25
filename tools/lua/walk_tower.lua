--!nonstrict
-- walk_tower.lua — проверка: проходит ли герой через выход башни после вырезания проёма.
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

-- Открыть решётку башни
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("Model") and d.Name == "Gate_TowerExit" then
		for _, part in ipairs(d:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
		d:PivotTo(d:GetPivot() + Vector3.new(0, 10, 0))
		break
	end
end

local character = player.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if not root or not humanoid then
	return table.concat(out, "\n") .. "\nнет персонажа"
end

root.CFrame = CFrame.new(8, 19, -290)
root.AssemblyLinearVelocity = Vector3.zero
task.wait(1)
local from = root.Position
humanoid:MoveTo(Vector3.new(-14, 19, -290))
task.wait(6)
local to = root.Position
table.insert(out, string.format("проход башни: с x=%.1f до x=%.1f (сдвиг %.1f)", from.X, to.X, (to - from).Magnitude))
humanoid:MoveTo(to)
table.insert(out, to.X < -2 and "ПРОХОД ОТКРЫТ (пересёк стену)" or "ПРОХОД ЗАКРЫТ (стоит)")

-- Габариты стены после вырезания
local walls = {}
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("BasePart") and d.Transparency >= 0.9 and d.CanCollide and d.Parent and d.Parent.Name == "Collision" then
		if math.abs(d.Position.X) <= 2 and math.abs(d.Position.Z + 290) < 14 and d.Size.Y >= 15 then
			table.insert(walls, string.format("%s %s %.1f×%.1f×%.1f", d.Name, tostring(d:GetAttribute("Carved")), d.Size.X, d.Size.Y, d.Size.Z))
		end
	end
end
table.insert(out, "части стены у проёма: " .. (#walls > 0 and table.concat(walls, " | ") or "нет"))
return table.concat(out, "\n")
