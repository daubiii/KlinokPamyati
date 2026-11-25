--!nonstrict
-- test_rest_doors.lua — комната отдыха не должна запирать игрока.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local out = {}
local failures = 0

local function check(label, actual, expected)
	local ok = actual == expected
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %-46s факт=%s ожидание=%s"):format(
		ok and "OK  " or "FAIL", label, tostring(actual), tostring(expected)
	)
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
local rest = floor and floor:FindFirstChild("Room_04_rest")
local hall = floor and floor:FindFirstChild("Room_05_combat")
if not rest or not hall then
	return "этаж не построен"
end

local restDoorIn = rest:FindFirstChild("Door")
local hallDoorIn = hall:FindFirstChild("Door")

out[#out + 1] = "1. До входа в комнату отдыха"
check("дверь комнаты отдыха закрыта", restDoorIn and restDoorIn:GetAttribute("Open"), false)

out[#out + 1] = "\n2. Вход в комнату отдыха"
placeAt(Vector3.new(0, 3.5, rest.Floor.Position.Z))
task.wait(0.8)

check("комната отдыха засчитана", rest:GetAttribute("RoomState"), "cleared")
check("вход в комнату отдыха открыт", restDoorIn and restDoorIn:GetAttribute("Open"), true)
check("дверь в Цепной зал открыта", hallDoorIn and hallDoorIn:GetAttribute("Open"), true)

out[#out + 1] = "\n3. Костёр"
local campfire
for _, child in ipairs(rest:GetDescendants()) do
	if child:GetAttribute("IsCampfire") then
		campfire = child
		break
	end
end
check("костёр найден", campfire ~= nil, true)

out[#out + 1] = "\n4. Переход в Цепной зал"
placeAt(Vector3.new(0, 3.5, hall.Floor.Position.Z + 10))
task.wait(0.8)
check("Цепной зал активировался", hall:GetAttribute("RoomState"), "active")
check("дверь за спиной закрылась", hallDoorIn and hallDoorIn:GetAttribute("Open"), false)

local enemies = 0
for _, child in ipairs(hall:GetChildren()) do
	if child:IsA("Model") and child:GetAttribute("EnemyType") then
		enemies += 1
	end
end
check("врагов в Цепном зале", enemies, 4)

out[#out + 1] = ("\nИТОГО: %s"):format(failures == 0 and "все проверки пройдены" or (failures .. " провалов"))
return table.concat(out, "\n")
