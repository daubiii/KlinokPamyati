--!nonstrict
-- probe_boss.lua — структура модели мини-босса: классы детей и атрибуты.
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
local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if root then
	root.CFrame = CFrame.new(-120, 3, -90)
	root.AssemblyLinearVelocity = Vector3.zero
end
task.wait(7)

local boss
for _, d in ipairs(game.Workspace:GetDescendants()) do
	if d:IsA("Model") and d:GetAttribute("EnemyType") == "centurion" then
		boss = d
		break
	end
end
if not boss then
	return "мини-босс не появился"
end

table.insert(out, "модель: " .. boss:GetFullName() .. " (" .. boss.ClassName .. ")")
for _, attr in ipairs(boss:GetAttributes()) do
	table.insert(out, "  attr " .. attr .. " = " .. tostring(boss:GetAttribute(attr)))
end
local children = {}
for _, child in ipairs(boss:GetChildren()) do
	table.insert(children, child.ClassName .. ":" .. child.Name)
end
table.insert(out, "  дети: " .. table.concat(children, ", "))

local humans = {}
for _, d in ipairs(boss:GetDescendants()) do
	if d:IsA("Humanoid") then
		table.insert(humans, d:GetFullName() .. " HP=" .. tostring(math.floor(d.Health)))
	end
end
table.insert(out, "  Humanoid: " .. (#humans > 0 and table.concat(humans, "; ") or "нет"))

-- Кто держит состояние врага: ищем рядом служебные папки
local runtime = game.Workspace:FindFirstChild("FloorRuntime")
if runtime then
	local names = {}
	for _, c in ipairs(runtime:GetChildren()) do
		table.insert(names, c.Name)
	end
	table.insert(out, "FloorRuntime: " .. table.concat(names, ", "))
end
return table.concat(out, "\n")
