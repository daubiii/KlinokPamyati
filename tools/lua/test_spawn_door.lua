--!nonstrict
-- test_spawn_door.lua — проверка жалобы: спавн и переход во вторую комнату.

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
		ok = math.abs(actual - expected) < 0.5
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
local room1 = floor and floor:FindFirstChild("Room_01_combat")
local room2 = floor and floor:FindFirstChild("Room_02_combat")
if not room1 or not room2 then
	return "этаж не построен"
end

out[#out + 1] = "1. Спавн"
local character = player.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
check("персонаж есть", root ~= nil, true)
if root then
	out[#out + 1] = ("  позиция спавна: %.1f, %.1f, %.1f"):format(root.Position.X, root.Position.Y, root.Position.Z)
	check("спавн у входа комнаты 1 (z ≈ −5)", root.Position.Z, -5)
end

local nearest = math.huge
for _, child in ipairs(room1:GetChildren()) do
	if child:IsA("Model") and child:GetAttribute("EnemyType") and root then
		local distance = (child:GetPivot().Position - root.Position).Magnitude
		nearest = math.min(nearest, distance)
	end
end
out[#out + 1] = ("  ближайший враг на %.1f стада"):format(nearest)
check("враги не на спавне (дальше 20)", nearest > 20, true)

out[#out + 1] = "\n2. Дверь во вторую комнату"
local door = room2:FindFirstChild("Door")
check("дверь существует", door ~= nil, true)
if door then
	out[#out + 1] = ("  дверь на z = %.1f"):format(door.Position.Z)
	check("дверь на границе комнат (z ≈ −50)", door.Position.Z, -50.5)
	check("дверь закрыта на старте", door:GetAttribute("Open"), false)
end

out[#out + 1] = "\n3. Зачистка комнаты 1 открывает дверь"
-- Комната может перезапускаться, если игрок умирает, поэтому каждый шаг
-- заново ищем живую цель, а не держим ссылки.
local clears = 0
local deadline = os.clock() + 50
while os.clock() < deadline do
	if room1:GetAttribute("RoomState") == "cleared" then
		clears = 1
		break
	end
	local target
	for _, child in ipairs(room1:GetChildren()) do
		if child:IsA("Model") and (child:GetAttribute("EnemyHealth") or 0) > 0 and child:GetAttribute("EnemyType") then
			target = child
			break
		end
	end
	if target then
		local body = target.PrimaryPart
		if body and body.Parent then
			placeAt(Vector3.new(body.Position.X, 3.5, body.Position.Z + 2.5))
			task.wait(0.12)
			attackRemote:InvokeServer()
		end
	end
	task.wait(0.42)
end
check("комната зачищена", clears, 1)
check("дверь открылась", waitFor(function()
	return door and door:GetAttribute("Open") == true
end, 6), true)

out[#out + 1] = "\n4. Переход во вторую комнату"
placeAt(Vector3.new(0, 3.5, -55))
task.wait(0.6)
check("комната 2 активировалась", waitFor(function()
	return room2:GetAttribute("RoomState") == "active"
end, 6), true)
local room2Enemies = 0
for _, child in ipairs(room2:GetChildren()) do
	if child:IsA("Model") and child:GetAttribute("EnemyType") then
		room2Enemies += 1
	end
end
check("врагов в комнате 2", room2Enemies, 4)

out[#out + 1] = ("\nИТОГО: %s"):format(failures == 0 and "все проверки пройдены" or (failures .. " провалов"))
return table.concat(out, "\n")
