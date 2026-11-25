--!nonstrict
-- probe_shoulder_client.lua — читаем отладочные атрибуты хвата с клиента
-- (атрибуты, выставленные клиентом, на сервер не реплицируются).
local Players = game:GetService("Players")
local player = Players.LocalPlayer
if not player then
	return "нет игрока"
end
local out = {}
for _ = 1, 4 do
	table.insert(out, ("shoulder=%s calm=%s action=%s idleFor=%s weapon=%s"):format(
		tostring(player:GetAttribute("AnimShoulder")),
		tostring(player:GetAttribute("AnimCalm")),
		tostring(player:GetAttribute("AnimAction")),
		tostring(player:GetAttribute("AnimIdleFor")),
		tostring(player:GetAttribute("WeaponType"))))
	task.wait(1.5)
end
return table.concat(out, "\n")
