--!nonstrict
-- probe_archer.lua — проверка: теряет ли стрелок здоровье, когда стреляет.
-- Игрок стоит далеко (вне удара), сам не атакует.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local archer
local floor = Workspace:FindFirstChild("Floor")
for _, room in ipairs(floor:GetChildren()) do
	if room:IsA("Folder") then
		for _, model in ipairs(room:GetChildren()) do
			if model:IsA("Model") and model:GetAttribute("EnemyType") == "archer" then
				archer = model
				break
			end
		end
	end
	if archer then
		break
	end
end

if not archer then
	return "стрелка в первой комнате нет"
end

-- Ставим игрока в 22 стадах: стрелок достаёт (engage), удар в ближнем бою — нет.
local placed = false
local samples = {}
local healthHistory = {}
local shots = 0

for index = 1, 60 do
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = humanoid.MaxHealth
		if not placed then
			local target = archer:GetPivot().Position + Vector3.new(0, 0, 20)
			character.HumanoidRootPart.CFrame = CFrame.new(target.X, 3.5, target.Z)
			placed = true
		end
	end

	local health = archer:GetAttribute("EnemyHealth") or -1
	local lastResult = archer:GetAttribute("LastAttackResult")
	if lastResult == "projectile" then
		shots += 1
	end
	table.insert(healthHistory, health)

	if index % 15 == 0 then
		table.insert(samples, ("t=%.1fs hp=%.1f"):format(index * 0.2, health))
	end
	task.wait(0.2)
end

local minHealth = math.huge
local maxHealth = -math.huge
for _, value in ipairs(healthHistory) do
	minHealth = math.min(minHealth, value)
	maxHealth = math.max(maxHealth, value)
end

return ("стрелок: hp от %.1f до %.1f | выстрелов замечено: %d\n%s"):format(
	minHealth,
	maxHealth,
	shots,
	table.concat(samples, " | ")
)
