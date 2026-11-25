--!nonstrict
-- probe_carry.lua — почему меч не закидывается на плечо: атрибуты оружия и тип.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local player = Players:GetPlayers()[1]
if not player then
	return "нет игроков"
end
local cmd = ServerStorage.KlinokDebug.Cmd
local out = {}

table.insert(out, "give rusty_sword: " .. tostring(cmd:Invoke("give rusty_sword")))
task.wait(2)
table.insert(out, "WeaponType = " .. tostring(player:GetAttribute("WeaponType")))
table.insert(out, "WeaponId = " .. tostring(player:GetAttribute("WeaponId")))
table.insert(out, "ClassName = " .. tostring(player:GetAttribute("ClassName")))

local character = player.Character
local model = character and character:FindFirstChild("EquippedWeapon", true)
table.insert(out, "модель оружия: " .. (model and model.Name or "нет"))
if model then
	table.insert(out, "  TypeId = " .. tostring(model:GetAttribute("TypeId")))
	table.insert(out, "  RarityId = " .. tostring(model:GetAttribute("RarityId")))
end

local humanoid = character and character:FindFirstChildOfClass("Humanoid")
table.insert(out, "анимации: " .. tostring(#(humanoid and humanoid:GetPlayingAnimationTracks() or {})))

local names = {}
for _, track in ipairs(humanoid and humanoid:GetPlayingAnimationTracks() or {}) do
	table.insert(names, tostring(track.Animation and track.Animation.Name or "?"))
end
table.insert(out, "играют: " .. (#names > 0 and table.concat(names, ", ") or "ничего"))

table.insert(out, "give royal_scythe: " .. tostring(cmd:Invoke("give royal_scythe")))
task.wait(2)
table.insert(out, "после косы WeaponType = " .. tostring(player:GetAttribute("WeaponType")))
return table.concat(out, "\n")
