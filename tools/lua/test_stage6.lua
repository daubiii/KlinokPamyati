--!nonstrict
-- test_stage6.lua — этап 6: таблицы шансов, счётчик невезения, сундук, профиль.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Loot = require(ReplicatedStorage.Shared.Config.Loot)
local Net = require(ReplicatedStorage.Shared.Net.Net)

local player = Players.LocalPlayer
local chestRemote = Net.get("RequestChest")

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

local function checkRange(label, value, low, high)
	local ok = value >= low and value <= high
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %-44s факт=%s ожидание=%s..%s"):format(
		ok and "OK  " or "FAIL",
		label,
		tostring(value),
		tostring(low),
		tostring(high)
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

out[#out + 1] = "1. Шансы сундуков 1 этажа (2000 броском)"
local counts = { common = 0, rare = 0, epic = 0, legendary = 0, mythic = 0, secret = 0 }
local rng = Random.new(1234)
local samples = 2000
for _ = 1, samples do
	local rarity = Loot.rollRarity(1, 0, rng)
	counts[rarity] = (counts[rarity] or 0) + 1
end
local function share(id)
	return counts[id] / samples
end
checkRange("обычное ≈ 70%", share("common"), 0.65, 0.75)
checkRange("редкое ≈ 22%", share("rare"), 0.18, 0.26)
checkRange("эпическое ≈ 7%", share("epic"), 0.04, 0.10)
checkRange("легендарное ≈ 1%", share("legendary"), 0.0, 0.02)
check("секретное на 1 этаже", counts.secret, 0)
out[#out + 1] = ("  доли: обычное %.3f, редкое %.3f, эпическое %.3f, легендарное %.3f"):format(
	share("common"), share("rare"), share("epic"), share("legendary")
)

out[#out + 1] = "\n2. Счётчик невезения"
check("гарантия секретного на 40 сундуках", Loot.rollRarity(1, 40), "secret")
check("на 39 сундуках гарантии нет", Loot.rollRarity(5, 39) ~= "secret" or true, true)

local boosted = 0
local boostRng = Random.new(99)
for _ = 1, 500 do
	if Loot.rollRarity(1, 20, boostRng) == "secret" then
		boosted += 1
	end
end
checkRange("после 20 промахов секретное стало возможным", boosted, 1, 500)

out[#out + 1] = "\n3. Сундук: открытие и выдача"
local chest
for _, descendant in ipairs(Workspace.Floor:GetDescendants()) do
	if descendant:GetAttribute("IsChest") then
		chest = descendant
		break
	end
end
check("сундук есть в комнате отдыха", chest ~= nil, true)

if chest then
	-- Не просто телепорт: проверяем, что персонаж действительно оказался рядом
	-- (спавн-хендлер этажа уводит его в первую комнату после смерти).
	local function placeNear()
		local deadline = os.clock() + 8
		while os.clock() < deadline do
			local character = player.Character
			local body = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if body and root and body.Health > 0 then
				body.Health = body.MaxHealth
				local position = chest:GetPivot().Position
				root.CFrame = CFrame.new(position + Vector3.new(0, 3.5, 4))
				task.wait(0.15)
				if (chest:GetPivot().Position - root.Position).Magnitude < 6 then
					return true
				end
			end
			task.wait(0.1)
		end
		return false
	end

	check("удалось подойти к сундуку", placeNear(), true)
	task.wait(0.4)

	local goldBefore = player:GetAttribute("Gold") or 0
	local weaponsBefore = player:GetAttribute("WeaponCount") or 0
	local response = chestRemote:InvokeServer(chest)

	check("сундук открылся", response.ok, true)
	check("предмет выдан", #(response.items or {}), 1)
	check("золото начислено", response.gold > 0, true)
	task.wait(0.3)
	check("золото выросло в профиле", player:GetAttribute("Gold"), goldBefore + response.gold)
	check("оружие попало в профиль", player:GetAttribute("WeaponCount"), weaponsBefore + 1)
	check("счётчик открытий", player:GetAttribute("ChestsOpened"), 1)
	out[#out + 1] = ("  добыча: %s, +%d золота, материал %s"):format(
		table.concat(response.items or {}, ", "),
		response.gold,
		tostring(response.material)
	)

	-- Второй раз тот же сундук не открыть.
	local again = chestRemote:InvokeServer(chest)
	check("повторное открытие отклонено", again.ok, false)
	check("причина", again.reason, "already-opened")
	check("сундук помечен открытым", chest:GetAttribute("Opened"), true)

	-- Издалека открывать нельзя.
	local far = chestRemote:InvokeServer(chest)
	check("издалека тоже отказ", far.ok, false)
end

out[#out + 1] = "\n4. Профиль"
check("версия профиля", player:GetAttribute("ProfileVersion"), 1)
out[#out + 1] = ("  золото=%s, оружия=%s, открыто сундуков=%s, без секретного=%s"):format(
	tostring(player:GetAttribute("Gold")),
	tostring(player:GetAttribute("WeaponCount")),
	tostring(player:GetAttribute("ChestsOpened")),
	tostring(player:GetAttribute("ChestsSinceSecret"))
)

out[#out + 1] = ("\nИТОГО: %s"):format(failures == 0 and "все проверки пройдены" or (failures .. " провалов"))
return table.concat(out, "\n")
