--!nonstrict
-- probe_zone.lua — состояние зоны после телепорта: активировалась ли, кто враги.
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
table.insert(out, "zone barbican: " .. tostring(cmd:Invoke("zone barbican")))
task.wait(3)

local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
table.insert(out, ("игрок: RoomIndex=%s RoomName=%s позиция=%s"):format(
	tostring(player:GetAttribute("RoomIndex")),
	tostring(player:GetAttribute("RoomName")),
	root and string.format("%.1f, %.1f, %.1f", root.Position.X, root.Position.Y, root.Position.Z) or "?"
))

-- Папка рантайма этажа: атрибуты зон
local runtime = game.Workspace:FindFirstChild("FloorRuntime")
if runtime then
	local names = {}
	for _, child in ipairs(runtime:GetChildren()) do
		table.insert(names, child.Name .. "[" .. tostring(child:GetAttribute("State") or child:GetAttribute("state") or "?") .. "]")
	end
	table.insert(out, "FloorRuntime: " .. table.concat(names, ", "))
else
	table.insert(out, "FloorRuntime нет")
end

-- Враги
local kinds = {}
for _, d in ipairs(game.Workspace:GetDescendants()) do
	if d:IsA("Model") then
		local t = d:GetAttribute("EnemyType")
		if t then
			kinds[t] = (kinds[t] or 0) + 1
		end
	end
end
local list = {}
for k, v in pairs(kinds) do
	table.insert(list, k .. "=" .. v)
end
table.sort(list)
table.insert(out, "враги: " .. (#list > 0 and table.concat(list, ", ") or "нет"))

-- Ворота барбакана
for _, name in ipairs({ "Gate_BarbS", "Gate_BarbN" }) do
	for _, d in ipairs(game.Workspace:GetDescendants()) do
		if d:IsA("Model") and d.Name == name then
			local p = d:GetPivot().Position
			local collider = "?"
			for _, part in ipairs(d:GetDescendants()) do
				if part:IsA("BasePart") and part.Transparency >= 0.99 then
					collider = tostring(part.CanCollide)
				end
			end
			table.insert(out, ("%s: Y=%.2f коллайдер=%s"):format(name, p.Y, collider))
		end
	end
end

return table.concat(out, "\n")
