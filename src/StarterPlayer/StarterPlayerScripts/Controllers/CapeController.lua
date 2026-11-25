--!nonstrict
-- CapeController (клиент)
-- Живой плащ героя. Плащ из мешей (HeroArmorBuilder) — цепочка сегментов
-- на Motor6D "CapeJoint1".."CapeJointN" (атрибут CapeIndex): верхний висит на
-- UpperTorso, каждый следующий — на предыдущем. Здесь каждый кадр считаются
-- углы шарниров по движению героя и пишутся в Motor6D.Transform:
--   покой    — плащ висит и чуть «дышит»;
--   бег      — отходит от спины, тем выше, чем быстрее, и полощется волной
--              (волна бежит от плеч к подолу, быстрее на большой скорости);
--   прыжок   — на взлёте подол подворачивается к ногам, бег поднимает
--              плащ слабее;
--   падение  — встречный воздух задирает его вверх, полощется сильнее;
--   шаг вбок — плащ сносит в другую сторону, на вираже — наружу поворота.
-- Углы ведёт пружина с затуханием: без рывков при смене состояния, с
-- лёгким перехлёстом при остановке. Анимируются все игроки (Transform не
-- реплицируется, каждый клиент считает сам). Дальше FAR стадов от камеры —
-- не считаем. Нет плаща из мешей (старая броня из Part'ов) — ничего не делаем.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CapeController = {}

local rad = math.rad
local clamp = math.clamp
local sin = math.sin

local FAR = 160
local RESCAN = 0.5 -- с: как часто искать новые плащи (смена брони, респаун)

-- Настройка «характера» плаща (градусы, стады/с).
local TUNE = {
	runSpeed = 18, -- скорость, при которой плащ поднят полностью
	liftTop = 42, -- верхний шарнир на полном беге
	liftRest = 9, -- остальные шарниры на полном беге (плащ распрямляется)
	fallTop = 62, -- добавка верхнему шарниру в падении
	fallRest = 16,
	riseTop = 8, -- взлёт: верх чуть отходит, низ подворачивается к ногам
	riseRest = -5.5,
	riseDamp = 0.45, -- на взлёте бег поднимает плащ слабее (воздух давит сверху)
	flutterIdle = 1.2,
	flutterRun = 7,
	flutterFall = 7,
	rollSide = 14, -- крен от шага вбок
	rollTurn = 16, -- крен от поворота (на вираже — наружу)
	stiffness = 150,
	damping = 15,
}

-- character -> rig
local rigs = {}

local function collect(character)
	local joints = {}
	local body = character:FindFirstChild("VoxelBody")
	if body then
		for _, d in ipairs(body:GetDescendants()) do
			if d:IsA("Motor6D") and d:GetAttribute("CapeIndex") then
				table.insert(joints, d)
			end
		end
	end
	table.sort(joints, function(a, b)
		return a:GetAttribute("CapeIndex") < b:GetAttribute("CapeIndex")
	end)
	return joints, body
end

local function rigFor(character)
	local rig = rigs[character]
	local body = character:FindFirstChild("VoxelBody")
	if rig and rig.body == body and rig.joints[1] and rig.joints[1].Parent then
		return rig
	end
	local joints = collect(character)
	if #joints == 0 then
		rigs[character] = nil
		return nil
	end
	local angles, speeds = {}, {}
	for i = 1, #joints do
		angles[i] = 0
		speeds[i] = 0
	end
	rig = {
		body = body,
		joints = joints,
		angles = angles,
		speeds = speeds,
		roll = 0,
		rollSpeed = 0,
		phase = math.random() * 10,
		velocity = Vector3.zero,
		yawRate = 0,
		lastPosition = nil,
		lastYaw = nil,
	}
	rigs[character] = rig
	return rig
end

local function rescan()
	local alive = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character.Parent then
			alive[character] = true
			rigFor(character)
		end
	end
	for character in pairs(rigs) do
		if not alive[character] then
			rigs[character] = nil
		end
	end
end

local function spring(angle, speed, target, dt)
	speed += ((target - angle) * TUNE.stiffness - speed * TUNE.damping) * dt
	return angle + speed * dt, speed
end

local function stepRig(rig, root: BasePart, humanoid, dt: number, clock: number)
	-- Скорость — по смещению корня (у чужих героев так надёжнее, чем по физике).
	local position = root.Position
	local cf = root.CFrame
	local look = cf.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	if rig.lastPosition then
		local raw = (position - rig.lastPosition) / dt
		if raw.Magnitude > 120 then
			raw = Vector3.zero -- телепорт / респаун
		end
		rig.velocity = rig.velocity:Lerp(raw, clamp(dt * 12, 0, 1))
		local dyaw = (yaw - rig.lastYaw + math.pi) % (2 * math.pi) - math.pi
		rig.yawRate += (dyaw / dt - rig.yawRate) * clamp(dt * 8, 0, 1)
	end
	rig.lastPosition = position
	rig.lastYaw = yaw

	local v = rig.velocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local forward = flat:Dot(Vector3.new(look.X, 0, look.Z))
	local side = flat:Dot(cf.RightVector)
	local alive = humanoid.Health > 0
	local seated = humanoid.Sit or humanoid:GetState() == Enum.HumanoidStateType.Swimming

	local run = clamp((math.max(forward, 0) + math.abs(side) * 0.35 + math.max(-forward, 0) * 0.15) / TUNE.runSpeed, 0, 1.2)
	local fall = clamp((-v.Y - 3) / 26, 0, 1)
	local rise = clamp((v.Y - 3) / 24, 0, 1)
	if not alive or seated then
		run, fall, rise = 0, 0, 0
	end

	rig.phase += dt * (2.2 + 9 * run + 7 * fall)
	local flutter = TUNE.flutterIdle + TUNE.flutterRun * run + TUNE.flutterFall * fall
	local lift = run * (1 - TUNE.riseDamp * rise)
	local joints, angles, speeds = rig.joints, rig.angles, rig.speeds
	local count = #joints
	for i = 1, count do
		local target
		if i == 1 then
			target = 3 + TUNE.liftTop * lift + TUNE.fallTop * fall + TUNE.riseTop * rise
				+ 1.5 * sin(clock * 1.3) -- «дыхание» в покое
				+ flutter * 0.35 * sin(rig.phase)
			target = clamp(target, -4, 120)
		else
			local k = 1 - 0.12 * (i - 2) -- ниже — чуть меньше распрямляется
			target = (1.5 + TUNE.liftRest * lift + TUNE.fallRest * fall + TUNE.riseRest * rise) * k
				+ flutter * sin(rig.phase - i * 0.95)
				+ 0.8 * sin(clock * 1.3 - i * 0.6)
			target = clamp(target, -30, 45)
		end
		angles[i], speeds[i] = spring(angles[i], speeds[i], target, dt)
	end
	-- Крен (вокруг Z шарнира, + — подол вправо): шаг вправо сносит плащ влево;
	-- на вираже налево (yawRate > 0) плащ заносит наружу — вправо, а при
	-- развороте на месте он чуть отстаёт — влево.
	local turn = clamp(rig.yawRate * 0.12, -1, 1) * (run * 1.3 - 0.3)
	local rollTarget = clamp(-side / TUNE.runSpeed, -1, 1) * TUNE.rollSide + turn * TUNE.rollTurn
	rig.roll, rig.rollSpeed = spring(rig.roll, rig.rollSpeed, rollTarget, dt)

	for i = 1, count do
		local joint = joints[i]
		if joint.Parent then
			-- Поворот вокруг X шарнира: минус — подол уходит назад, от спины.
			joint.Transform = CFrame.Angles(-rad(angles[i]), 0, i == 1 and rad(rig.roll) or 0)
		end
	end
end

local clock = 0
local sinceScan = RESCAN

local function step(dt: number)
	dt = clamp(dt, 1 / 240, 1 / 20)
	clock += dt
	sinceScan += dt
	if sinceScan >= RESCAN then
		sinceScan = 0
		rescan()
	end
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	for character, rig in pairs(rigs) do
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and rig.joints[1].Parent then
			if not eye or (root.Position - eye).Magnitude <= FAR then
				stepRig(rig, root, humanoid, dt, clock)
			else
				rig.lastPosition = nil
			end
		end
	end
end

function CapeController.start()
	-- Как PlayerAnimator: после штатного аниматора и до физики, иначе поза
	-- на физическом риге живёт один кадр.
	local ok = pcall(function()
		RunService.PreSimulation:Connect(step)
	end)
	if not ok then
		RunService.Heartbeat:Connect(step)
	end
	print("[CapeController] живые плащи героев")
end

return CapeController
