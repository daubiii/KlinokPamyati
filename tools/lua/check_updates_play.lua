--!nonstrict
-- check_updates_play.lua — функциональная проверка обновлений в Play.
-- Запускать в Play, контекст Server.
local out = {}
local players = game:GetService("Players")
local player = players:GetPlayers()[1]
if not player then
	return "нет игрока"
end

local storage = game:GetService("ServerStorage")
local debug = storage:FindFirstChild("KlinokDebug")
if not debug then
	return "нет ServerStorage.KlinokDebug"
end

local cmd = debug:FindFirstChild("Cmd")
if not cmd then
	return "нет KlinokDebug.Cmd"
end

local function run(label, ...)
	local ok, result = pcall(function(...)
		return cmd:Invoke(...)
	end, ...)
	table.insert(out, ("%s → %s"):format(label, ok and tostring(result) or ("ОШИБКА: " .. tostring(result))))
end

run("class mage", "class mage")
run("mana", "mana")
run("level 60", "level 60")
run("talents", "talents")
run("chest give 1 gold 3", "chest give 1 gold 3")
run("chest list", "chest list")
run("give staff", "give archivist")

-- Что в итоге у игрока
local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
table.insert(out, ("HP=%s, класс=%s, мана=%s, уровень=%s"):format(
	tostring(humanoid and humanoid.MaxHealth),
	tostring(player:GetAttribute("Class")),
	tostring(player:GetAttribute("Mana")),
	tostring(player:GetAttribute("Level"))
))
table.insert(out, "атрибуты: " .. table.concat((function()
	local list = {}
	for _, attr in ipairs(player:GetAttributes()) do
		table.insert(list, attr)
	end
	table.sort(list)
	return list
end)(), ", "))

return table.concat(out, "\n")
