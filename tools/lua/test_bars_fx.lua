--!nonstrict
-- test_bars_fx.lua — полоски здоровья над врагами и видимая анимация удара.
-- Полоски сделаны геометрией (папка ClientEnemyBars), потому что GUI над
-- врагами в этой среде не отрисовывается.

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
		ok = math.abs(actual - expected) < 0.06
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
		task.wait(interval or 0.03)
	end
	return nil
end

local character = player.Character
if not character then
	return "нет персонажа"
end

local function refresh()
	local current = player.Character
	if not current then
		return false
	end
	local body = current:FindFirstChildOfClass("Humanoid")
	local root = current:FindFirstChild("HumanoidRootPart")
	if not body or not root or body.Health <= 0 then
		return false
	end
	body.Health = body.MaxHealth
	return true
end

local function placeAt(position: Vector3)
	for _ = 1, 25 do
		if refresh() then
			player.Character.HumanoidRootPart.CFrame = CFrame.new(position)
			return true
		end
		task.wait(0.1)
	end
	return false
end

out[#out + 1] = "1. Полоски здоровья над врагами"
local room = Workspace.Floor.Room_01_combat
local enemies = {}
for _, model in ipairs(room:GetChildren()) do
	if model:IsA("Model") and model:GetAttribute("EnemyMaxHealth") then
		table.insert(enemies, model)
	end
end
check("врагов в комнате (3-4)", #enemies >= 3 and #enemies <= 4, true)

task.wait(0.8)

local barsFolder = Workspace:FindFirstChild("ClientEnemyBars")
check("папка полосок создана", barsFolder ~= nil, true)

local backgrounds, fills = 0, 0
if barsFolder then
	for _, part in ipairs(barsFolder:GetChildren()) do
		if part.Name == "EnemyBarBg" then
			backgrounds += 1
		elseif part.Name == "EnemyBarFill" then
			fills += 1
		end
	end
end
check("фонов полосок не меньше врагов комнаты", backgrounds >= #enemies, true)
check("заливок столько же, сколько фонов", fills, backgrounds)

-- Полоса стоит над головой врага: проверяем по одной ближайшей цели.
local sample = enemies[1]
local head = sample:FindFirstChild("Head") or sample.PrimaryPart
local nearestFill
local bestDistance = math.huge
if barsFolder then
	for _, part in ipairs(barsFolder:GetChildren()) do
		if part.Name == "EnemyBarFill" then
			local distance = (part.Position - head.Position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				nearestFill = part
			end
		end
	end
end
check("полоса висит рядом с головой", bestDistance < 6, true)
out[#out + 1] = ("  ближайшая заливка в %.2f стадах от головы"):format(bestDistance)

out[#out + 1] = "\n2. Удар: полоса уменьшается, дуга взмаха появляется"
local target
for _, model in ipairs(enemies) do
	if (model:GetAttribute("EnemyHealth") or 0) > 0 then
		target = model
		break
	end
end
check("есть живая цель", target ~= nil, true)
if not target then
	return table.concat(out, "\n")
end

local healthBefore = target:GetAttribute("EnemyHealth")
local swingSeen = false
local landed = false
local attack

for attempt = 1, 6 do
	local body = target.PrimaryPart
	if not body or not body.Parent then
		break
	end
	placeAt(Vector3.new(body.Position.X, 3.5, body.Position.Z + 2.5))
	task.wait(0.15)
	attack = attackRemote:InvokeServer()

	local deadline = os.clock() + 0.3
	while os.clock() < deadline do
		if Workspace:FindFirstChild("SwingArc") then
			swingSeen = true
		end
		task.wait(0.01)
	end

	if attack and attack.ok and (attack.hits or 0) >= 1 then
		landed = true
		break
	end
	task.wait(0.45)
end

check("удар засчитан", landed, true)
check("дуга взмаха появилась", swingSeen, true)
out[#out + 1] = ("  попаданий: %s, урон: %s"):format(tostring(attack and attack.hits), tostring(attack and attack.damage))

task.wait(0.4)
local healthAfter = target:GetAttribute("EnemyHealth")
check("здоровье врага уменьшилось", healthAfter < healthBefore, true)

if nearestFill then
	local ratio = healthAfter / target:GetAttribute("EnemyMaxHealth")
	task.wait(0.4)
	check("длина заливки отражает долю", nearestFill.Size.X, math.max(2.0 * ratio, 0.06))
end

out[#out + 1] = "\n3. Третий удар комбо выделяется"
local restRoom = Workspace.Floor:FindFirstChild("Room_04_rest")
local restZ = restRoom and restRoom.Floor.Position.Z or -170
placeAt(Vector3.new(0, 3.5, restZ))
task.wait(0.4)

local memory = Color3.fromHex("#6FE3FF")
local steel = Color3.fromHex("#F2EDE3")

local function near(color, targetColor)
	return math.abs(color.R - targetColor.R) < 0.03
		and math.abs(color.G - targetColor.G) < 0.03
		and math.abs(color.B - targetColor.B) < 0.03
end

local colorsSeen = { memory = false, steel = false }
local combosSeen = {}
for index = 1, 4 do
	refresh()
	local response = attackRemote:InvokeServer()
	table.insert(combosSeen, tostring(response and response.combo))
	local waitTo = os.clock() + 0.2
	while os.clock() < waitTo do
		for _, instance in ipairs(Workspace:GetChildren()) do
			if instance.Name == "SwingArc" then
				if near(instance.Color, memory) then
					colorsSeen.memory = true
				elseif near(instance.Color, steel) then
					colorsSeen.steel = true
				end
			end
		end
		task.wait(0.01)
	end
	task.wait(0.32)
end
out[#out + 1] = "  комбо: " .. table.concat(combosSeen, ",")
check("комбо дошло до третьего удара", table.concat(combosSeen, ","):find("3") ~= nil, true)
check("дуга третьего удара цветом памяти", colorsSeen.memory, true)
check("обычная дуга стальная", colorsSeen.steel, true)

out[#out + 1] = ("\nИТОГО: %s"):format(failures == 0 and "все проверки пройдены" or (failures .. " провалов"))
return table.concat(out, "\n")
