--!nonstrict
-- test_heal_hud.lua — проверка лечения, HUD, меча в руке и очереди атак.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net.Net)

local player = Players.LocalPlayer
local healRemote = Net.get("RequestHeal")

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
	out[#out + 1] = ("  %s %-42s факт=%s ожидание=%s"):format(
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

out[#out + 1] = "1. Меч в руке"
local character = player.Character
local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
local sword = hand and hand:FindFirstChild("EquippedSword")
check("меч приварен к кисти", sword ~= nil, true)
if sword then
	check("вокселей в мече", sword:GetAttribute("VoxelCount"), 33)
	local weld = sword.PrimaryPart and sword.PrimaryPart:FindFirstChild("GripWeld")
	check("есть сварка с рукой", weld ~= nil, true)
	check("модель не пустая", #sword:GetChildren() > 30, true)
end

out[#out + 1] = "\n2. HUD"
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:FindFirstChild("KlinokHud")
check("ScreenGui создан", gui ~= nil, true)
if gui then
	local panel = gui:FindFirstChild("HealthPanel")
	check("панель здоровья", panel ~= nil, true)
	check("заливка здоровья", panel and panel:FindFirstChild("HealthFill") ~= nil, true)
	check("текст здоровья", gui:FindFirstChild("140 / 140") ~= nil or gui:FindFirstChildOfClass("TextLabel") ~= nil, true)
	local pips = 0
	for _, child in ipairs(gui:GetChildren()) do
		if child.Name:match("^HealPip") then
			pips += 1
		end
	end
	check("индикаторов лечения", pips, 3)
end

out[#out + 1] = "\n3. Лечение"
check("зарядов на старте", player:GetAttribute("HealCharges"), 3)

local function freshHumanoid()
	local current = player.Character
	if not current then
		return nil
	end
	local body = current:FindFirstChildOfClass("Humanoid")
	if not body or body.Health <= 0 then
		return nil
	end
	return body
end

local function waitForDamage(threshold: number, timeout: number?)
	return waitFor(function()
		local body = freshHumanoid()
		return body and body.Health < body.MaxHealth * threshold
	end, timeout or 25)
end

-- Лечимся по-настоящему: здоровье снимают враги, а не тест.
-- Клиентская запись Health до сервера доходит не мгновенно, поэтому
-- «подставить» здоровье нельзя — ждём урон.
local healedOk = 0
for index = 1, 3 do
	if not waitForDamage(0.8) then
		out[#out + 1] = ("  не дождались урона перед лечением %d"):format(index)
		break
	end
	local before = player:GetAttribute("HealCharges") or 0
	local response = healRemote:InvokeServer()
	check(("лечение %d разрешено"):format(index), response.ok, true)
	if response.ok then
		healedOk += 1
		check(("вылечено 35%% от максимума (%d)"):format(index), response.healed, 140 * 0.35)
		check(("заряды после лечения %d"):format(index), player:GetAttribute("HealCharges"), before - 1)
	end
end
check("проведено лечений", healedOk, 3)

while (player:GetAttribute("HealCharges") or 0) > 0 do
	if not waitForDamage(0.95) then
		break
	end
	healRemote:InvokeServer()
end
local denied = healRemote:InvokeServer()
check("без зарядов лечение отклонено", denied.ok, false)
check("причина", denied.reason, "no-charges")

out[#out + 1] = "\n4. Очередь атак: одновременно бьют не больше 2"
local maxAttacking = 0
local samples = 0
local deadline = os.clock() + 6
while os.clock() < deadline do
	local attacking = 0
	local floor = Workspace:FindFirstChild("Floor")
	if floor then
		for _, room in ipairs(floor:GetChildren()) do
			if room:IsA("Folder") then
				for _, model in ipairs(room:GetChildren()) do
					if model:IsA("Model") and model:GetAttribute("Attacking") == true then
						attacking += 1
					end
				end
			end
		end
	end
	maxAttacking = math.max(maxAttacking, attacking)
	samples += 1
	task.wait(0.05)
end
out[#out + 1] = ("  замеров: %d, максимум одновременно атакующих: %d"):format(samples, maxAttacking)
check("одновременных атак не больше 2", maxAttacking <= 2, true)

out[#out + 1] = ("\nИТОГО: %s"):format(failures == 0 and "все проверки пройдены" or (failures .. " провалов"))
return table.concat(out, "\n")
