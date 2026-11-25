--!nonstrict
-- check_staffs.lua — проверка посохов: класс маг, посох ловчего, id способности.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local player = Players:GetPlayers()[1]
if not player then
	return "нет игроков"
end
local cmd = ServerStorage.KlinokDebug.Cmd
local out = {}

table.insert(out, "class mage: " .. tostring(cmd:Invoke("class mage")))
task.wait(1.5)
table.insert(out, "staff huntmaster_staff: " .. tostring(cmd:Invoke("staff huntmaster_staff")))
task.wait(1.5)
table.insert(out, "WeaponAbility = " .. tostring(player:GetAttribute("WeaponAbility")))
table.insert(out, "WeaponType = " .. tostring(player:GetAttribute("WeaponType")))
table.insert(out, "ClassName = " .. tostring(player:GetAttribute("ClassName")))
table.insert(out, "Mana = " .. tostring(player:GetAttribute("Mana")) .. " / " .. tostring(player:GetAttribute("MaxMana")))

table.insert(out, "staff molten_scepter: " .. tostring(cmd:Invoke("staff molten_scepter")))
task.wait(1.5)
table.insert(out, "WeaponAbility = " .. tostring(player:GetAttribute("WeaponAbility")))

table.insert(out, "staff all: " .. tostring(cmd:Invoke("staff all")))
task.wait(1)
table.insert(out, "после staff all: " .. tostring(player:GetAttribute("WeaponAbility")))
return table.concat(out, "\n")
