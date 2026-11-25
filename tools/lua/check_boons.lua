--!nonstrict
-- check_boons.lua — проверка «Даров Эха»: команда boon и состояние.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local player = Players:GetPlayers()[1]
if not player then
	return "нет игроков"
end
local cmd = ServerStorage.KlinokDebug.Cmd
local out = {}

table.insert(out, "floor 1: " .. tostring(cmd:Invoke("floor 1")))
task.wait(3)
table.insert(out, "zone street: " .. tostring(cmd:Invoke("zone street")))
task.wait(1.5)
table.insert(out, "spawn guard 3: " .. tostring(cmd:Invoke("spawn guard 3")))
task.wait(1.5)

local ok, res = pcall(function()
	return cmd:Invoke("boon")
end)
table.insert(out, "boon: " .. tostring(ok) .. " / " .. tostring(res))
task.wait(1)

-- Что видно в мире: серый ли экран (атрибуты), сколько карточек
table.insert(out, "BoonActive = " .. tostring(player:GetAttribute("BoonActive")))
local gui = player:FindFirstChild("PlayerGui")
local boonGui = gui and gui:FindFirstChild("KlinokBoons")
table.insert(out, "KlinokBoons в PlayerGui: " .. (boonGui and "есть" or "нет"))
if boonGui then
	local cards = 0
	for _, d in ipairs(boonGui:GetDescendants()) do
		if d:IsA("GuiObject") and string.find(d.Name, "Card", 1, true) then
			cards += 1
		end
	end
	table.insert(out, "элементов с 'Card' в имени: " .. cards)
end
return table.concat(out, "\n")
