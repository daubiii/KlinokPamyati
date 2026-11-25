--!nonstrict
-- test_enemy_axes.lua — проверочные позы раздела 3.1 ТЗ врагов (шаг 2).
-- Ставит префабу стража четыре позы через EnemyAnimator:debugPose и меряет
-- направления частей в мире:
--   1. RUA = {90,0,0}           правая рука вперёд горизонтально, меч вверх;
--   2. RUA = {0,0,90}           правая рука горизонтально вправо;
--   3. UT  = {-30,0,0}          наклон корпуса вперёд;
--   4. RUL = {90,0,0}, RLL = {-90,0,0}  колено поднято, голень вниз.
-- Модели остаются в Workspace.AssetLab.EnemyAxes (x ≈ 3000) для снимка —
-- удалить перед Ctrl+S (или запустить ещё раз с CLEAN = true).
-- Запуск: node C:\Users\artem\.dsh-roblox\s.js exec tools/lua/test_enemy_axes.lua Edit

local CLEAN = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")

local lab = workspace:FindFirstChild("AssetLab")
if lab and lab:FindFirstChild("EnemyAxes") then
	lab.EnemyAxes:Destroy()
end
if CLEAN then
	return "убрано"
end

-- Свежие копии модулей: require в Studio кэширует модули по экземпляру.
local original = ReplicatedStorage.Shared
original.Name = "Shared_orig"
local shared = original:Clone()
shared.Name = "Shared"
shared.Parent = ReplicatedStorage
local animatorModule = StarterPlayer.StarterPlayerScripts.Controllers.EnemyAnimator:Clone()
animatorModule.Parent = workspace

local out = {}
local failures = 0
local function check(label: string, actual: Vector3, expected: Vector3, tolerance: number?)
	local ok = (actual - expected).Magnitude < (tolerance or 0.15)
	if not ok then
		failures += 1
	end
	table.insert(out, ("  %s %-44s факт=(%.2f, %.2f, %.2f) ожидание=(%.0f, %.0f, %.0f)"):format(
		ok and "OK  " or "FAIL", label, actual.X, actual.Y, actual.Z, expected.X, expected.Y, expected.Z))
end

local ok, err = pcall(function()
	local EnemyAnimator = require(animatorModule)
	if not lab then
		lab = Instance.new("Folder")
		lab.Name = "AssetLab"
		lab.Parent = workspace
	end
	local holder = Instance.new("Folder")
	holder.Name = "EnemyAxes"
	holder.Parent = lab

	local poses = {
		{ "1. RUA {90,0,0}", { RUA = { 90, 0, 0 } } },
		{ "2. RUA {0,0,90}", { RUA = { 0, 0, 90 } } },
		{ "3. UT {-30,0,0}", { UT = { -30, 0, 0 } } },
		{ "4. RUL {90}, RLL {-90}", { RUL = { 90, 0, 0 }, RLL = { -90, 0, 0 } } },
	}
	local models = {}
	for index, entry in ipairs(poses) do
		local model = ReplicatedStorage.EnemyPrefabs.guard:Clone()
		-- Враг смотрит в −Z мира: «вперёд» = (0, 0, −1), «вправо» = (1, 0, 0).
		model:PivotTo(CFrame.new(3000 + (index - 1) * 6, 0, 0))
		model.Parent = holder
		local animator = EnemyAnimator.new(model, "guard")
		animator:debugPose(entry[2])
		models[index] = model
	end
	-- Дать движку разрешить суставы.
	RunService.Heartbeat:Wait()
	task.wait(0.1)

	local function dir(part: BasePart, axis: string): Vector3
		local cf = part.CFrame
		if axis == "down" then
			return -cf.UpVector
		elseif axis == "up" then
			return cf.UpVector
		end
		return cf.LookVector
	end

	local m1, m2, m3, m4 = models[1], models[2], models[3], models[4]
	table.insert(out, poses[1][1])
	check("рука (вниз по плечу) смотрит вперёд", dir(m1.RightUpperArm, "down"), Vector3.new(0, 0, -1))
	check("меч (+Y клинка) смотрит вверх", dir(m1.Weapon.Blade, "up"), Vector3.new(0, 1, 0))
	table.insert(out, poses[2][1])
	check("рука смотрит вправо", dir(m2.RightUpperArm, "down"), Vector3.new(1, 0, 0))
	table.insert(out, poses[3][1])
	check("верх корпуса наклонён вперёд (30°)", dir(m3.UpperTorso, "up"), Vector3.new(0, math.cos(math.rad(30)), -math.sin(math.rad(30))))
	table.insert(out, poses[4][1])
	check("бедро смотрит вперёд", dir(m4.RightUpperLeg, "down"), Vector3.new(0, 0, -1))
	check("голень смотрит вниз", dir(m4.RightLowerLeg, "down"), Vector3.new(0, -1, 0))
	-- Контрольная поза Shot_Windup (раздел 3.4): левая рука стрелка — на цель
	-- прямо перед ним, правая кисть у подбородка.
	local archer = ReplicatedStorage.EnemyPrefabs.archer:Clone()
	archer:PivotTo(CFrame.new(3000 + 5 * 6, 0, 0))
	archer.Parent = holder
	local archerAnimator = EnemyAnimator.new(archer, "archer")
	archerAnimator:debugPose({ LT = { 0, -60, 0 }, UT = { -5, -28, 0 }, HD = { 0, 82, 0 }, LUA = { 90, 85, 0 }, RUA = { 95, 50, 10 }, RLA = { 140, 0, 0 } })
	RunService.Heartbeat:Wait()
	task.wait(0.1)
	table.insert(out, "Стрелок, конец Shot_Windup")
	check("левая рука смотрит на цель (−Z)", dir(archer.LeftUpperArm, "down"), Vector3.new(0, 0, -1), 0.2)
	-- Кисть — сверка, не проверка: таблицу ТЗ не правим. По числам Shot_Windup
	-- (RUA {95,50,10}, RLA {140}) кисть выходит к уху, чуть за голову.
	local hand = archer.Head.CFrame:PointToObjectSpace(archer.RightHand.Position)
	table.insert(out, ("  СВЕР правая кисть в осях головы: (%.2f, %.2f, %.2f), подбородок ≈ (0, −0.5, −0.6)"):format(hand.X, hand.Y, hand.Z))
	-- Покой: при опущенной руке меч смотрит вперёд (правило предметов в руке).
	local rest = ReplicatedStorage.EnemyPrefabs.guard:Clone()
	rest:PivotTo(CFrame.new(3000 + 4 * 6, 0, 0))
	rest.Parent = holder
	RunService.Heartbeat:Wait()
	table.insert(out, "Покой (без позы)")
	check("меч при опущенной руке смотрит вперёд", dir(rest.Weapon.Blade, "up"), Vector3.new(0, 0, -1))
end)

animatorModule:Destroy()
shared:Destroy()
original.Name = "Shared"

if not ok then
	return "ОШИБКА: " .. tostring(err)
end
table.insert(out, ("\nИТОГО: %s"):format(failures == 0 and "все проверки пройдены" or (failures .. " провалов")))
return table.concat(out, "\n")
