--!nonstrict
-- repro_barbican.lua — воспроизведение: мини-босс барбакана побеждён, ворота
-- Gate_BarbN должны открыться (подняться).
-- 1) вход на этаж 1, 2) телепорт к зоне barbican, 3) ждём появления мини-босса,
-- 4) убиваем его (Humanoid.Health = 0), 5) смотрим ворота до/после.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local player = Players:GetPlayers()[1]
if not player then
	return "нет игроков"
end

local cmd = ServerStorage.KlinokDebug.Cmd
local out = {}

local function gateY(name: string): string
	for _, d in ipairs(game.Workspace:GetDescendants()) do
		if d:IsA("Model") and d.Name == name then
			local ok, pivot = pcall(function()
				return d:GetPivot().Position
			end)
			if ok then
				local collider = "нет"
				for _, part in ipairs(d:GetDescendants()) do
					if part:IsA("BasePart") and part.Transparency >= 0.99 then
						collider = tostring(part.CanCollide)
					end
				end
				return ("Y=%.2f, коллайдер=%s"):format(pivot.Y, collider)
			end
		end
	end
	return "не найдено"
end

table.insert(out, "до: Gate_BarbN " .. gateY("Gate_BarbN") .. "; Gate_BarbS " .. gateY("Gate_BarbS"))
table.insert(out, "floor 1: " .. tostring(cmd:Invoke("floor 1")))
task.wait(2)
table.insert(out, "zone barbican: " .. tostring(cmd:Invoke("zone barbican")))
task.wait(6)

-- Ищем мини-босса: модель с атрибутом EnemyType (centurion) в Workspace
local boss = nil
for _, d in ipairs(game.Workspace:GetDescendants()) do
	if d:IsA("Model") then
		local enemyType = d:GetAttribute("EnemyType")
		if enemyType == "centurion" then
			boss = d
			break
		end
	end
end
if not boss then
	table.insert(out, "мини-босс centurion НЕ найден в Workspace")
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
	table.insert(out, "враги в Workspace: " .. table.concat(list, ", "))
	return table.concat(out, "\n")
end

local humanoid = boss:FindFirstChildOfClass("Humanoid")
table.insert(out, ("мини-босс найден: %s, HP=%s"):format(boss:GetFullName(), humanoid and tostring(math.floor(humanoid.Health)) or "нет Humanoid"))
if humanoid then
	humanoid.Health = 0
end
task.wait(4)
table.insert(out, "после смерти: Gate_BarbN " .. gateY("Gate_BarbN") .. "; Gate_BarbS " .. gateY("Gate_BarbS"))
return table.concat(out, "\n")
