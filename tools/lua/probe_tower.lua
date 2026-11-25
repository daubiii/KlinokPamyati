--!nonstrict
-- probe_tower.lua — что стоит в проёме Gate_TowerExit и рядом (башня, Арбалетчица).
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
local zone = cmd:Invoke("zone tower")
table.insert(out, "zone tower: " .. tostring(zone))
task.wait(3)

local gate
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("Model") and d.Name == "Gate_TowerExit" then
		gate = d
		break
	end
end
if not gate then
	return table.concat(out, "\n") .. "\nGate_TowerExit не найден"
end

local center = gate:GetPivot().Position
table.insert(out, string.format("Gate_TowerExit: %.1f %.1f %.1f", center.X, center.Y, center.Z))

local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { gate }
local parts = W:GetPartBoundsInBox(CFrame.new(center), Vector3.new(20, 24, 20), params)
local list = {}
for _, part in ipairs(parts) do
	if part:IsA("BasePart") and part.Transparency >= 0.9 then
		local s = part.Size
		if s.X >= 4 or s.Z >= 4 then
			table.insert(list, string.format(
				"%s | %.1f %.1f %.1f | %.1f×%.1f×%.1f | CanCollide=%s",
				part:GetFullName(), part.Position.X, part.Position.Y, part.Position.Z,
				s.X, s.Y, s.Z, tostring(part.CanCollide)))
		end
	end
end
table.sort(list)
table.insert(out, "крупных невидимых коллизий рядом: " .. #list)
for i = 1, math.min(#list, 15) do
	table.insert(out, "  " .. list[i])
end
return table.concat(out, "\n")
