--!nonstrict
-- test_stage5_client.lua — прогон этапа 5 «Этаж».
-- Проверяем: цепочку комнат по приложению А, закрытые двери, зачистку
-- комнаты, комнату отдыха и появление босса.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net.Net)

local player = Players.LocalPlayer
local attackRemote = Net.get("RequestAttack")

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

local character = player.Character
if not character then
	return "нет персонажа"
end
local root, humanoid

local function refresh()
	character = player.Character
	if not character then
		return false
	end
	root = character:FindFirstChild("HumanoidRootPart")
	humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	humanoid.Health = humanoid.MaxHealth
	return true
end

local function placeAt(position: Vector3)
	for _ = 1, 25 do
		if refresh() then
			root.CFrame = CFrame.new(position)
			return true
		end
		task.wait(0.1)
	end
	return false
end

local floor = Workspace:FindFirstChild("Floor")
if not floor then
	return "этаж не построен"
end

out[#out + 1] = "1. Структура этажа"
check("комнат на этаже", floor:GetAttribute("RoomCount"), 7)
check("первая комната боевая", floor:GetAttribute("ActiveRoomKind"), "combat")
check("активная комната", floor:GetAttribute("ActiveRoom"), 1)

local kinds = {}
for _, child in ipairs(floor:GetChildren()) do
	if child:IsA("Folder") then
		local kind = child.Name:match("_(%a+)$")
		table.insert(kinds, { name = child.Name, kind = kind })
	end
end
table.sort(kinds, function(a, b) return a.name < b.name end)

check("комнат в папке", #kinds, 7)
check("комната 1: combat", kinds[1].kind, "combat")
check("комната 4: rest (после 3-й боевой)", kinds[4].kind, "rest")
check("комната 7: boss", kinds[7].kind, "boss")

out[#out + 1] = "\n2. Первая комната: враги и закрытые двери"
local room1 = floor:FindFirstChild("Room_01_combat")
local room2 = floor:FindFirstChild("Room_02_combat")
local enemiesAlive = floor:GetAttribute("EnemiesAlive")
check("врагов в первой комнате (3-4)", enemiesAlive >= 3 and enemiesAlive <= 4, true)
check("дверь во вторую комнату закрыта", room2.Door:GetAttribute("Open"), false)

out[#out + 1] = "\n3. Зачистка комнаты открывает двери"
local function enemyModels(folder)
	local list = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("EnemyHealth") then
			table.insert(list, child)
		end
	end
	return list
end

-- Лучники отходят, а интервал удара 0.5 с, поэтому держимся рядом с целью
-- и бьём не чаще, чем разрешает перезарядка.
local function killEnemy(model, timeout: number?)
	local deadline = os.clock() + (timeout or 16)
	while os.clock() < deadline do
		if not model.Parent then
			return true
		end
		local health = model:GetAttribute("EnemyHealth")
		if not health or health <= 0 then
			return true
		end
		local body = model.PrimaryPart
		if body and body.Parent then
			if placeAt(Vector3.new(body.Position.X, 3.5, body.Position.Z + 2.5)) then
				task.wait(0.16)
				attackRemote:InvokeServer()
			end
		end
		task.wait(0.5)
	end
	return (model:GetAttribute("EnemyHealth") or 0) <= 0
end

local models = enemyModels(room1)
check("моделей врагов в комнате (3-4)", #models >= 3 and #models <= 4, true)

local killed = 0
for _, model in ipairs(models) do
	if killEnemy(model) then
		killed += 1
	end
end
out[#out + 1] = ("  добито врагов: %d из %d"):format(killed, #models)

local cleared = waitFor(function()
	return room1:GetAttribute("RoomState") == "cleared"
end, 10)
check("комната зачищена", cleared, true)
check("дверь открылась", waitFor(function()
	return room2.Door:GetAttribute("Open") == true
end, 5), true)
check("следующая комната не тронута", room2:GetAttribute("RoomState"), nil)
check("через одну комната не тронута", floor.Room_03_combat:GetAttribute("RoomState"), nil)

out[#out + 1] = "\n4. Комната отдыха пополняет лечение"
local restRoom = floor:FindFirstChild("Room_04_rest")
local zStart = restRoom.Floor.Position.Z
placeAt(Vector3.new(0, 3.5, zStart))
local healed = waitFor(function()
	return player:GetAttribute("HealCharges") == 3
end, 5)
check("заряды лечения = 3", healed, true)
check("тип комнаты отдыха", restRoom:GetAttribute("RoomKind"), "rest")
check("комната отдыха засчитана", restRoom:GetAttribute("RoomState"), "cleared")

out[#out + 1] = "\n5. Комната босса"
local bossRoom = floor:FindFirstChild("Room_07_boss")
placeAt(Vector3.new(0, 3.5, bossRoom.Floor.Position.Z))
local boss = waitFor(function()
	for _, model in ipairs(bossRoom:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("EnemyIsBoss") then
			return model
		end
	end
	return nil
end, 8)

check("босс появился", boss ~= nil, true)
if boss then
	check("HP босса 1 этажа", boss:GetAttribute("EnemyMaxHealth"), 1000)
	check("урон босса 50", boss:GetAttribute("EnemyDamage"), 50)
	check("броня босса 5", boss:GetAttribute("EnemyArmor"), 5)
	check("фаза босса", boss:GetAttribute("BossPhase"), 0)
	check("босс помечен как босс", boss:GetAttribute("EnemyIsBoss"), true)
end

out[#out + 1] = ("\nИТОГО: %s"):format(failures == 0 and "все проверки пройдены" or (failures .. " провалов"))
return table.concat(out, "\n")
