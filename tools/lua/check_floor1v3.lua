--!nonstrict
-- check_floor1v3.lua — прогон по зонам новой карты: телепорт и проверка, что герой
-- не провалился и не застрял в геометрии.
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

local zones = { "street", "warehouse", "plaza", "barbican", "rest1", "bridge", "armory", "forge", "gallery", "tower", "hall", "chapel", "lastgates" }
for _, id in ipairs(zones) do
	local ok, res = pcall(function()
		return cmd:Invoke("zone " .. id)
	end)
	task.wait(1.2)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root then
		table.insert(out, string.format("%-11s %s | поз %.1f %.1f %.1f | HP %d | земля %s",
			id,
			tostring(ok and res or res),
			root.Position.X, root.Position.Y, root.Position.Z,
			humanoid and math.floor(humanoid.Health) or -1,
			humanoid and tostring(humanoid.FloorMaterial) or "?"))
	else
		table.insert(out, string.format("%-11s %s | нет персонажа", id, tostring(ok and res or res)))
	end
end
return table.concat(out, "\n")
