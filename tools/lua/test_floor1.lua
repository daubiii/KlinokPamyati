--!nonstrict
-- test_floor1.lua — проверка этажа 1 по приложению Е: комнаты, волны, враги,
-- босс, костёр, ловушки. Игрок на этой проверке не воюет, только смотрит.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net.Net)

local player = Players.LocalPlayer
local out = {}
local failures = 0

local function check(label, actual, expected)
	local ok
	if type(expected) == "number" and type(actual) == "number" then
		ok = math.abs(actual - expected) < 0.05
	else
		ok = actual == expected
	end
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %-44s факт=%s ожидание=%s"):format(
		ok and "OK  " or "FAIL",
		label,
		tostring(actual),
		tostring(expected)
	)
end

local function waitFor(predicate, timeout: number, interval: number?)
	local deadline = os.clock() + (timeout or 5)
	while os.clock() < deadline do
		local ok, value = pcall(predicate)
		if ok and value then
			return value
		end
		task.wait(interval or 0.05)
	end
	return nil
end

local function placeAt(position: Vector3)
	for _ = 1, 25 do
		local character = player.Character
		local body = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if body and root and body.Health > 0 then
			body.Health = body.MaxHealth
			root.CFrame = CFrame.new(position)
			return true
		end
		task.wait(0.1)
	end
	return false
end

local floor = Workspace:FindFirstChild("Floor")

out[#out + 1] = "1. Структура этажа"
check("этаж построен", floor ~= nil, true)
if not floor then
	return table.concat(out, "\n")
end
check("комнат", floor:GetAttribute("RoomCount"), 7)

local names = {}
for _, child in ipairs(floor:GetChildren()) do
	if child:IsA("Folder") then
		table.insert(names, child.Name)
	end
end
table.sort(names)
check("комната 1", names[1], "Room_01_combat")
check("комната 4 — отдых", names[4], "Room_04_rest")
check("комната 7 — босс", names[7], "Room_07_boss")

out[#out + 1] = "\n2. Игрок на 5 уровне"
local level = player:GetAttribute("Level")
check("уровень из профиля", level, 5)
local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
check("HP по приложению Б", humanoid and humanoid.MaxHealth, 180)
check("опыт до следующего уровня", player:GetAttribute("XpToNext"), 500)

out[#out + 1] = "\n3. Первая комната: три Ржавых стража"
local room1 = floor:FindFirstChild("Room_01_combat")
local guards = {}
for _, child in ipairs(room1:GetChildren()) do
	if child:IsA("Model") and child:GetAttribute("EnemyType") then
		table.insert(guards, child)
	end
end
check("врагов в комнате 1", #guards, 3)

local first = guards[1]
check("тип врага", first and first:GetAttribute("EnemyType"), "guard")
check("HP стража", first and first:GetAttribute("EnemyMaxHealth"), 90)
check("броня стража", first and first:GetAttribute("EnemyArmor"), 0)

local whiteWindup = waitFor(function()
	for _, model in ipairs(guards) do
		if model:GetAttribute("EnemyTelegraph") == "parryable" and model:GetAttribute("EnemyAttack") == "slash" then
			return true
		end
	end
	return false
end, 8)
check("страж делает белый замах", whiteWindup, true)

out[#out + 1] = "\n4. Комната отдыха: костёр"
local rest = floor:FindFirstChild("Room_04_rest")
local campfire
if rest then
	for _, child in ipairs(rest:GetDescendants()) do
		if child:GetAttribute("IsCampfire") then
			campfire = child
			break
		end
	end
end
check("костёр есть", campfire ~= nil, true)

out[#out + 1] = "\n5. Цепной зал: шипы"
local hall = floor:FindFirstChild("Room_05_combat")
local spikes = 0
if hall then
	for _, child in ipairs(hall:GetChildren()) do
		if child.Name == "Spike" then
			spikes += 1
		end
	end
end
check("шипов", spikes, 4)

out[#out + 1] = "\n6. Способность оружия без способности"
local abilityRemote = Net.get("RequestAbility")
local response = abilityRemote and abilityRemote:InvokeServer()
check("стартовое оружие без способности", response and response.ok, false)
check("причина", response and response.reason, "no-ability")

out[#out + 1] = "\n7. Босс: появление и параметры"
local bossRoom = floor:FindFirstChild("Room_07_boss")
placeAt(Vector3.new(0, 3.5, bossRoom.Floor.Position.Z))
local boss = waitFor(function()
	for _, child in ipairs(bossRoom:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("EnemyIsBoss") then
			return child
		end
	end
	return nil
end, 10)

check("босс появился", boss ~= nil, true)
if boss then
	check("HP Привратника", boss:GetAttribute("EnemyMaxHealth"), 1000)
	check("броня Привратника", boss:GetAttribute("EnemyArmor"), 12)
	check("фаза 1", boss:GetAttribute("BossPhase"), 1)
	check("двери боссовой комнаты закрыты", bossRoom.Door and bossRoom.Door:GetAttribute("Open"), false)
end

out[#out + 1] = ("\nИТОГО: %s"):format(failures == 0 and "все проверки пройдены" or (failures .. " провалов"))
return table.concat(out, "\n")
