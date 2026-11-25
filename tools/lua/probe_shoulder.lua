--!nonstrict
-- probe_shoulder.lua — читаем отладочные атрибуты хвата: почему меч не на плече.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local player = Players:GetPlayers()[1]
if not player then
	return "нет игроков"
end
local cmd = ServerStorage.KlinokDebug.Cmd
local out = {}

table.insert(out, "give rusty_sword: " .. tostring(cmd:Invoke("give rusty_sword")))
task.wait(3.5)
table.insert(out, ("через 3.5 с: shoulder=%s calm=%s action=%s idleFor=%s"):format(
	tostring(player:GetAttribute("AnimShoulder")),
	tostring(player:GetAttribute("AnimCalm")),
	tostring(player:GetAttribute("AnimAction")),
	tostring(player:GetAttribute("AnimIdleFor"))))
task.wait(3)
table.insert(out, ("через 6.5 с: shoulder=%s calm=%s action=%s idleFor=%s"):format(
	tostring(player:GetAttribute("AnimShoulder")),
	tostring(player:GetAttribute("AnimCalm")),
	tostring(player:GetAttribute("AnimAction")),
	tostring(player:GetAttribute("AnimIdleFor"))))
return table.concat(out, "\n")
