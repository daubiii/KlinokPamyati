--!nonstrict
-- repro2.lua — вход в зону Барбакана (внутрь enter-бокса), убийство мини-босса,
-- проверка ворот Gate_BarbN.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local player = Players:GetPlayers()[1]
if not player then
	return "нет игроков"
end
local cmd = ServerStorage.KlinokDebug.Cmd
local out = {}

local function gate(name: string): string
	for _, d in ipairs(game.Workspace:GetDescendants()) do
		if d:IsA("Model") and d.Name == name then
			local p = d:GetPivot().Position
			local coll = "?"
			for _, part in ipairs(d:GetDescendants()) do
				if part:IsA("BasePart") and part.Transparency >= 0.99 then
					coll = tostring(part.CanCollide)
				end
			end
			return string.format("Y=%.2f коллайдер=%s", p.Y, coll)
		end
	end
	return "не найдено"
end

table.insert(out, "floor 1: " .. tostring(cmd:Invoke("floor 1")))
task.wait(3)

local character = player.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
if not root then
	return table.concat(out, "\n") .. "\nнет персонажа"
end
-- Внутрь enter-бокса Барбакана: x -120, y 3, z -90
root.CFrame = CFrame.new(-120, 3, -90)
root.AssemblyLinearVelocity = Vector3.zero
table.insert(out, "телепорт в enter-бокс: -120, 3, -90")
task.wait(7)

local boss = nil
for _, d in ipairs(game.Workspace:GetDescendants()) do
	if d:IsA("Model") and d:GetAttribute("EnemyType") == "centurion" then
		boss = d
		break
	end
end

local kinds = {}
for _, d in ipairs(game.Workspace:GetDescendants()) do
	if d:IsA("Model") then
		local t = d:GetAttribute("EnemyType")
		if t then
			kinds[t] = (kinds[t] or 0) + 1
		end
	end
end
local list = {}
for k, v in pairs(kinds) do
	table.insert(list, k .. "=" .. v)
end
table.sort(list)
table.insert(out, "враги после входа: " .. (#list > 0 and table.concat(list, ", ") or "нет"))
table.insert(out, "до смерти: Gate_BarbN " .. gate("Gate_BarbN") .. ", Gate_BarbS " .. gate("Gate_BarbS"))

if not boss then
	table.insert(out, "мини-босс не появился")
	return table.concat(out, "\n")
end

local humanoid = boss:FindFirstChildWhichIsA("Humanoid", true)
table.insert(out, ("мини-босс: %s HP=%s"):format(boss.Name, humanoid and tostring(math.floor(humanoid.Health)) or "?"))
if humanoid then
	humanoid.Health = 0
end
task.wait(5)
table.insert(out, "после смерти: Gate_BarbN " .. gate("Gate_BarbN") .. ", Gate_BarbS " .. gate("Gate_BarbS"))
local zoneState = {}
for _, d in ipairs(game.Workspace:GetDescendants()) do
	if d:IsA("Model") and d:GetAttribute("EnemyType") == "centurion" then
		table.insert(zoneState, d.Name .. " жив")
	end
end
table.insert(out, "осталось мини-боссов: " .. (#zoneState > 0 and table.concat(zoneState, ", ") or "нет"))
return table.concat(out, "\n")
