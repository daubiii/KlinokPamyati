--!nonstrict
-- probe_floor1v3_ground.lua — есть ли пол под точками входа зон и где он.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local W = game.Workspace
local player = Players:GetPlayers()[1]
if not player then
	return "нет игроков"
end
local cmd = ServerStorage.KlinokDebug.Cmd
local out = {}

table.insert(out, "floor 1: " .. tostring(cmd:Invoke("floor 1")))
task.wait(3)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { player.Character }

local zones = { "street", "warehouse", "plaza", "barbican", "rest1", "bridge", "armory", "forge", "gallery", "tower", "hall", "chapel", "lastgates" }
for _, id in ipairs(zones) do
	cmd:Invoke("zone " .. id)
	task.wait(0.8)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root then
		table.insert(out, id .. ": нет персонажа")
		continue
	end
	local p = root.Position
	-- ищем пол под точкой входа
	local hit = W:Raycast(Vector3.new(p.X, p.Y + 12, p.Z), Vector3.new(0, -40, 0), params)
	table.insert(out, string.format(
		"%-11s вход y=%.1f (%.1f, %.1f) | пол %s | HP %d",
		id, p.Y, p.X, p.Z,
		hit and string.format("на y=%.1f (%s)", hit.Position.Y, hit.Instance.Name) or "НЕ НАЙДЕН",
		humanoid and math.floor(humanoid.Health) or -1))
end
return table.concat(out, "\n")
