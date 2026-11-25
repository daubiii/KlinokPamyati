--!nonstrict
-- test_hub_walk.lua — прогон маршрута «Чертог Пробуждения → долина» ногами (Server, Play).
-- R15-двойник игрока идёт Humanoid:MoveTo по точкам маршрута пещеры (ТЗ хаба,
-- раздел 3); на каждой точке пишет, дошёл ли и не провалился ли. У самого
-- игрока MoveTo не работает: движение движковое и каждый кадр перебивает его.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HubLayout = require(ReplicatedStorage.Shared.Config.HubLayout)

-- Точки в координатах сборки (x, y пола, z).
local route = {
	{ "Чертог", Vector3.new(0, 11, 368) },
	{ "к лестнице", Vector3.new(8, 10, 363) },
	{ "низ лестницы", Vector3.new(9, 11, 359) },
	{ "верх лестницы", Vector3.new(9, 19, 345) },
	{ "площадка", Vector3.new(-5, 20, 342) },
	{ "площадка", Vector3.new(-5, 20, 334) },
	{ "напротив моста", Vector3.new(5, 20, 337) },
	{ "перед мостом", Vector3.new(5, 20, 331) },
	{ "середина моста", Vector3.new(5, 20, 319) },
	{ "за мостом", Vector3.new(5, 20, 302) },
	{ "грот пруда", Vector3.new(5, 22, 290) },
	{ "к кузне", Vector3.new(12, 22, 279) },
	{ "Кузня Эха", Vector3.new(25, 26, 279) },
	{ "грот пруда", Vector3.new(10, 22, 272) },
	{ "проход между камнями", Vector3.new(5.5, 22, 268) },
	{ "низ лестницы к свету", Vector3.new(5, 24, 261) },
	{ "верх лестницы", Vector3.new(0, 36, 232) },
	{ "Уступ", Vector3.new(0, 40, 214) },
	{ "низ парадной лестницы", Vector3.new(0, 0, 108) },
	{ "развилка", Vector3.new(8, 0, 92) },
}

local character = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
character.Name = "HubWalkTester"
local humanoid = character:FindFirstChildOfClass("Humanoid")
humanoid.WalkSpeed = 16
local root = character:FindFirstChild("HumanoidRootPart")
character:PivotTo(CFrame.new(HubLayout.world(route[1][2]) + Vector3.new(0, 3.2, 0)))
character.Parent = workspace
pcall(function()
	root:SetNetworkOwner(nil)
end)

local function flat(target: Vector3): number
	return (Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)).Magnitude
end

local function walkTo(target: Vector3, timeout: number)
	local t0 = os.clock()
	repeat
		humanoid:MoveTo(target) -- MoveTo сам сдаётся через 8 с: повторяем
		local done = false
		local conn = humanoid.MoveToFinished:Connect(function()
			done = true
		end)
		while not done and os.clock() - t0 < timeout do
			task.wait(0.1)
		end
		conn:Disconnect()
	until flat(target) < 2 or os.clock() - t0 >= timeout
	return flat(target)
end

local out = {}
task.wait(1)
local started = os.clock()
for index, step in ipairs(route) do
	local target = HubLayout.world(step[2])
	local miss = walkTo(target, 25)
	local y = root.Position.Y - 3
	local ok = miss < 3 and math.abs(y - target.Y) < 4
	table.insert(out, ("%s %d %s: промах %.1f, пол %.1f (ждали %.1f)"):format(ok and "OK " or "ERR", index, step[1], miss, y - HubLayout.Origin.Y, step[2].Y))
	if not ok then
		table.insert(out, "стоит в " .. tostring(root.Position - HubLayout.Origin))
		break
	end
end
table.insert(out, ("время ходьбы: %.0f с при WalkSpeed %d"):format(os.clock() - started, humanoid.WalkSpeed))
character:Destroy()
return table.concat(out, "\n")
