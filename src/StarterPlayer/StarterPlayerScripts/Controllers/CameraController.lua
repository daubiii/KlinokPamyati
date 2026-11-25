--!nonstrict
-- CameraController (клиент)
-- Фиксация камеры (shift lock) для боёвки: камера за плечом, мышь захвачена,
-- персонаж развёрнут в сторону взгляда (стрейф вместо разворота).
--
-- Почему своя реализация, а не штатная:
-- в установленной сборке Studio (0.743) PlayerModule в PlayerScripts не
-- создаётся вообще — ни MouseLockController, ни ControlModule. Движение и
-- камера при этом работают (движок), но включить штатный shift lock нечем:
-- MouseLockController просто отсутствует. Поэтому камера ведётся скриптом,
-- а камера-относительное движение остаётся движковым (оно читает
-- CurrentCamera.CFrame, а его задаём мы).
--
-- Что даёт: камера на 9.5 стада, смещение за плечо 1.75, ограничение
-- вертикали, упор в стены лучом-сферой, разворот корпуса по yaw камеры.
--
-- Свободный курсор (07.11.2026): Alt (или Ctrl) переключает «бой» ↔ «курсор».
-- В режиме курсора мышь видна и камера стоит — можно нажать задание справа
-- сверху и кнопки HUD; ходить можно, удары и рывок ждут возврата в бой.
-- Вернуться — снова Alt/Ctrl или клик по миру (не по кнопке). Курсор
-- отпускается и сам, пока открыто окно или сцена сундука
-- (ClientState.wantsCursor).

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DebugState = require(ReplicatedStorage.Shared.Net.DebugState)
local ClientState = require(ReplicatedStorage.Shared.Util.ClientState)
local Binds = require(ReplicatedStorage.Shared.Config.Binds)
local Bus = require(script.Parent.Parent.Lib.Bus)

local CameraController = {}

local solveCamera, fadeCharacter -- объявлены ниже (упор в геометрию)

local player = Players.LocalPlayer

local config = {
	sensitivity = 0.0022,
	distance = 12,
	shoulder = 2.0,
	focusHeight = 2.0,
	pitchMin = math.rad(-70),
	pitchMax = math.rad(70),
	collisionPadding = 0.4,
	rotationRate = 14,
	baseFov = 70,
	-- Телефон: радиан на пиксель пальца (по горизонтали, по вертикали).
	touchSensitivity = Vector2.new(0.0062, 0.0046),
	-- Геймпад: радиан в секунду при полном отклонении правого стика.
	gamepadSpeed = math.rad(230),
	gamepadDeadzone = 0.18,
}

-- Тряска и «рывок» угла обзора: короткие, затухающие.
local fx = {
	shakeAmount = 0,
	shakeUntil = 0,
	shakeTotal = 0.01,
	fovPunch = 0,
	fovUntil = 0,
	fovTotal = 0.01,
	override = nil, -- функция () -> CFrame?, fov? : сцена босса и т.п.
	lastOverride = nil, -- последний кадр сцены (для плавного выхода)
	lastFov = nil,
	blendFrom = nil, -- выход из сцены: от кадра сцены к обычной камере
	blendFov = 70,
	blendStart = 0,
	blendTime = 0,
}

-- Тряска: шум, затухающий к концу.
local function shakeOffset(clock: number, scale: number): CFrame?
	if clock >= fx.shakeUntil then
		return nil
	end
	local k = (fx.shakeUntil - clock) / fx.shakeTotal
	local amount = fx.shakeAmount * k * scale
	return CFrame.new(
		(math.noise(clock * 38, 0.5) * 2) * amount,
		(math.noise(clock * 41, 7.1) * 2) * amount,
		0
	) * CFrame.Angles(0, 0, math.noise(clock * 29, 3.3) * amount * 0.05)
end

local state = {
	yaw = 0,
	pitch = math.rad(-12),
	locked = false,
	cameraType = "Custom",
	lastMouseDelta = Vector2.zero,
	collisionDistance = config.distance,
	characterFacing = 0,
	cursorFree = false, -- режим «курсор» (Alt/Ctrl): мышь видна, камера стоит
	touchInput = nil, -- палец, который сейчас крутит камеру (телефон)
	touchLast = nil,
	stick = Vector2.zero, -- правый стик геймпада
	assistYaw = nil, -- доводка прицела (тач/геймпад): целевой yaw
	assistUntil = 0,
}

local function currentCamera()
	return Workspace.CurrentCamera
end

local function characterParts()
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end
	return character, humanoid, root
end

local function publish()
	DebugState.set("Camera", "Locked", state.locked)
	DebugState.set("Camera", "Yaw", math.deg(state.yaw))
	DebugState.set("Camera", "Pitch", math.deg(state.pitch))
	DebugState.set("Camera", "Distance", state.collisionDistance)
	DebugState.set("Camera", "CameraType", state.cameraType)
	DebugState.set("Camera", "MouseBehavior", tostring(UserInputService.MouseBehavior))
end

local function applyLock(locked: boolean)
	state.locked = locked
	if locked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
	publish()
end

-- ===== Упор камеры в геометрию (переделка 06.11.2026) =====
-- Видимые меши карт собраны с CanQuery = false и коллизией Box (на ходу её не
-- поменять), поэтому камера, как и герой, упирается в коробки коллизий карты.
-- Раньше это был один тонкий луч из головы: ближняя плоскость камеры влезала
-- в стену у самой стены, в узком проходе смещение «за плечо» втыкало камеру в
-- боковую стену, под низким перекрытием камера прыгала к затылку, а на углах
-- дрожала (каждый кадр то упор, то нет). Теперь:
--   * луч-сфера радиуса RADIUS — камера держит дистанцию до стены, не только до точки;
--   * мелочь, персонажи, враги, эффекты и детали с атрибутом CameraIgnore не мешают;
--   * потолок: камера опускается под него, а не прыгает к затылку;
--   * узкий проход: плечо поджимается;
--   * к стене — сразу, обратно — плавно;
--   * камера у затылка — свой персонаж полупрозрачный.
-- Места, где видимой стене/потолку не хватает коллизии, правятся в картах
-- (команда camaudit ищет тесноту по этажу).
local RADIUS = 0.6
local MIN_DISTANCE = 1.4
local RETURN_RATE = 7 -- 1/с: насколько быстро камера отъезжает назад
local MIN_BLOCK = 1.6 -- детали меньше (стад) камеру не останавливают
local MAX_SKIPS = 8

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local smooth = { distance = config.distance, shoulder = config.shoulder }

-- Препятствие ли для камеры то, во что попал луч.
local function blocksCamera(part: Instance): boolean
	if not part:IsA("BasePart") then
		return false
	end
	if not part.CanCollide or part.Material == Enum.Material.Neon then
		return false -- эффекты, свечение, декор без коллизии
	end
	if part.Name == "WallCap" then
		return false -- невидимые надстройки стен (FloorMap.capWalls) выше видимой стены
	end
	local s = part.Size
	if math.max(s.X, s.Y, s.Z) < MIN_BLOCK then
		return false
	end
	local model = part:FindFirstAncestorOfClass("Model")
	if model and (model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")) then
		return false -- персонажи и враги
	end
	local node = part
	while node and node ~= Workspace do
		if node:GetAttribute("CameraIgnore") then
			return false
		end
		node = node.Parent
	end
	return true
end

-- Сфера от from по dir: первое настоящее препятствие (или nil).
local function sweep(character, from: Vector3, dir: Vector3)
	if dir.Magnitude < 1e-3 then
		return nil
	end
	local exclude = { character }
	for _ = 1, MAX_SKIPS do
		rayParams.FilterDescendantsInstances = exclude
		local ok, hit = pcall(Workspace.Spherecast, Workspace, from, RADIUS, dir, rayParams)
		if not ok then
			hit = Workspace:Raycast(from, dir, rayParams)
		end
		if not hit then
			return nil
		end
		if blocksCamera(hit.Instance) then
			return hit
		end
		table.insert(exclude, hit.Instance)
	end
	return nil
end

-- Позиция камеры: желаемая точка за плечом, поджатая к препятствиям.
solveCamera = function(character, focus: Vector3, forward: Vector3, flatRight: Vector3, dt: number)
	-- 1. Плечо: в узком проходе сбоку стена — смещение уменьшается.
	local shoulder = config.shoulder
	local side = sweep(character, focus, flatRight * (config.shoulder + RADIUS))
	if side then
		shoulder = math.max(side.Distance - RADIUS * 0.5, 0)
	end
	smooth.shoulder = shoulder < smooth.shoulder and shoulder
		or smooth.shoulder + (shoulder - smooth.shoulder) * math.clamp(dt * RETURN_RATE, 0, 1)
	local pivot = focus + flatRight * smooth.shoulder

	-- 2. Назад от плеча; если первым встретился потолок — опускаем камеру под него.
	local offset = -forward * config.distance
	local hit = sweep(character, pivot, offset)
	if hit and hit.Normal.Y < -0.6 and offset.Y > 0 then
		local roof = hit.Position.Y - RADIUS - 0.2
		local lowered = Vector3.new(offset.X, math.max(math.min(offset.Y, roof - pivot.Y), 0), offset.Z)
		offset = lowered.Unit * config.distance
		hit = sweep(character, pivot, offset)
	end
	local wanted = hit and math.max(hit.Distance - 0.15, MIN_DISTANCE) or config.distance

	-- 3. К стене — сразу, назад — плавно.
	if wanted < smooth.distance then
		smooth.distance = wanted
	else
		smooth.distance += (wanted - smooth.distance) * math.clamp(dt * RETURN_RATE, 0, 1)
	end
	return pivot + offset.Unit * smooth.distance, smooth.distance
end

-- Камера у самого затылка: свой персонаж и броня полупрозрачные, чтобы видеть бой.
local fadedCharacter = nil
local fadeValue = 0
fadeCharacter = function(character, distance: number)
	local target = distance < 3 and math.clamp((3 - distance) / 1.6, 0, 0.75) or 0
	if math.abs(target - fadeValue) < 0.02 and fadedCharacter == character then
		return
	end
	fadeValue = target
	fadedCharacter = character
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = target
		end
	end
end

-- Пересчитать позицию камеры и развернуть корпус.
-- ===== Телефон и геймпад (09.11.2026) =====
-- Камера Scriptable, поэтому штатная камера PlayerModule её не крутит: палец
-- и правый стик обрабатываем сами. Палец на стике движения камеру не трогает
-- (как у штатной камеры): зона стика берётся из TouchGui, без неё — левые 40%.
local function inThumbstickArea(position: Vector3): boolean
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local stick = frame and (frame:FindFirstChild("DynamicThumbstickFrame") or frame:FindFirstChild("ThumbstickFrame"))
	if stick and stick:IsA("GuiObject") and touchGui:IsA("ScreenGui") and touchGui.Enabled then
		local topLeft = stick.AbsolutePosition
		local bottomRight = topLeft + stick.AbsoluteSize
		return position.X >= topLeft.X
			and position.Y >= topLeft.Y
			and position.X <= bottomRight.X
			and position.Y <= bottomRight.Y
	end
	local camera = currentCamera()
	return camera ~= nil and position.X < camera.ViewportSize.X * 0.4
end

-- Правый стик геймпада и доводка прицела — каждый кадр, до расчёта камеры.
local function stepPadAndAssist(deltaTime: number)
	local stick = state.stick
	if stick.Magnitude > config.gamepadDeadzone and state.locked and not ClientState.isInputBlocked() then
		local k = math.clamp((stick.Magnitude - config.gamepadDeadzone) / (1 - config.gamepadDeadzone), 0, 1)
		local direction = stick.Unit * (k * k)
		state.yaw -= direction.X * config.gamepadSpeed * deltaTime
		state.pitch = math.clamp(
			state.pitch + direction.Y * config.gamepadSpeed * 0.6 * deltaTime,
			config.pitchMin,
			config.pitchMax
		)
		state.assistUntil = 0
	end
	if state.assistYaw and os.clock() < state.assistUntil then
		local diff = (state.assistYaw - state.yaw + math.pi) % (2 * math.pi) - math.pi
		state.yaw += diff * math.clamp(deltaTime * 16, 0, 1)
	end
end

local function update(deltaTime: number)
	local camera = currentCamera()
	if not camera then
		return
	end

	-- Камеру ведём мы: любой другой режим отдал бы управление движку.
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
		state.cameraType = tostring(camera.CameraType)
	end

	local character, humanoid, root = characterParts()
	if not character or not humanoid or not root then
		return
	end

	-- Фиксация: мышь всегда в центре, иначе она уйдёт из окна. Пока открыт
	-- экран интерфейса (инвентарь, находка), мышь свободна.
	local uiOpen = ClientState.wantsCursor()
	if state.locked and not uiOpen and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	elseif uiOpen and UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end

	-- Сцена: камеру ведёт внешний сценарий.
	if fx.override then
		local cf, fov = fx.override()
		if cf then
			-- Тряска и рывок обзора работают и в сцене (удары, рёв).
			local clock = os.clock()
			fov = fov or config.baseFov
			fx.lastOverride = cf
			fx.lastFov = fov
			local shaken = shakeOffset(clock, 0.7)
			camera.CFrame = shaken and cf * shaken or cf
			if clock < fx.fovUntil then
				fov += fx.fovPunch * ((fx.fovUntil - clock) / fx.fovTotal)
			end
			camera.FieldOfView = math.clamp(fov, 10, 110)
			return
		end
	end

	-- Только Studio: обзорная камера для проверки эффектов (DebugCommands «cam»).
	-- Атрибут DebugCam — смещение камеры в осях персонажа (X вправо, Y вверх,
	-- Z назад); смотрит на точку перед героем.
	local debugCam = RunService:IsStudio() and player:GetAttribute("DebugCam")
	if typeof(debugCam) == "Vector3" then
		local flatLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		flatLook = flatLook.Magnitude > 0.01 and flatLook.Unit or Vector3.new(0, 0, -1)
		local basis = CFrame.lookAt(root.Position, root.Position + flatLook)
		local target = root.Position + flatLook * 4 - Vector3.new(0, 1.5, 0)
		camera.CFrame = CFrame.lookAt(basis:PointToWorldSpace(debugCam), target)
		camera.FieldOfView = config.baseFov
		return
	end

	stepPadAndAssist(deltaTime)

	local rotation = CFrame.fromEulerAnglesYXZ(state.pitch, state.yaw, 0)
	local forward = rotation.LookVector
	local right = rotation.RightVector
	local flatRight = Vector3.new(right.X, 0, right.Z)
	if flatRight.Magnitude > 0.001 then
		flatRight = flatRight.Unit
	end

	local focus = root.Position + Vector3.new(0, config.focusHeight, 0)
	local finalPosition, distance = solveCamera(character, focus, forward, flatRight, deltaTime)
	state.collisionDistance = distance
	fadeCharacter(character, distance)

	local cf = CFrame.lookAt(finalPosition, finalPosition + forward)

	-- Тряска: шум, затухающий к концу.
	local clock = os.clock()
	local shaken = shakeOffset(clock, 1)
	if shaken then
		cf = cf * shaken
	end

	-- Рывок обзора (рывок персонажа, удары по боссу).
	local fovTarget = config.baseFov
	if clock < fx.fovUntil then
		fovTarget += fx.fovPunch * ((fx.fovUntil - clock) / fx.fovTotal)
	end

	-- Выход из сцены: плавно от последнего кадра сцены к камере за плечом.
	if fx.blendFrom then
		local k = (clock - fx.blendStart) / math.max(fx.blendTime, 1e-3)
		if k >= 1 then
			fx.blendFrom = nil
		else
			local e = k * k * (3 - 2 * k)
			cf = fx.blendFrom:Lerp(cf, e)
			fovTarget = fx.blendFov + (fovTarget - fx.blendFov) * e
		end
	end
	camera.CFrame = cf
	camera.FieldOfView = fovTarget

	-- Корпус разворачивается за камерой: бой требует прицела, а не разворота.
	if humanoid.AutoRotate then
		humanoid.AutoRotate = false
	end
	local flatForward = Vector3.new(forward.X, 0, forward.Z)
	if state.assistYaw and os.clock() < state.assistUntil then
		-- доводка: корпус уже смотрит на цель, камера догоняет
		flatForward = Vector3.new(-math.sin(state.assistYaw), 0, -math.cos(state.assistYaw))
	end
	if flatForward.Magnitude > 0.001 then
		flatForward = flatForward.Unit
		local currentCFrame = root.CFrame
		local targetCFrame = CFrame.lookAt(currentCFrame.Position, currentCFrame.Position + flatForward)
		local alpha = math.clamp(deltaTime * config.rotationRate, 0, 1)
		root.CFrame = currentCFrame:Lerp(targetCFrame, alpha)
		local _, currentYaw = (currentCFrame - currentCFrame.Position):ToEulerAnglesYXZ()
		local _, targetYaw = (targetCFrame - targetCFrame.Position):ToEulerAnglesYXZ()
		state.characterFacing = math.deg(targetYaw)
		DebugState.set("Camera", "CharacterYawDelta", math.deg(targetYaw - currentYaw))
	end
end

function CameraController.start()
	-- Стартовый угол берём у текущей камеры, чтобы не дёрнуть вид на спавне.
	local camera = currentCamera()
	if camera then
		local _, startYaw = (camera.CFrame - camera.CFrame.Position):ToEulerAnglesYXZ()
		state.yaw = startYaw
	end

	applyLock(true)
	player.CameraMinZoomDistance = 6
	player.CameraMaxZoomDistance = 14

	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		if not state.locked or ClientState.isInputBlocked() then
			return
		end
		state.lastMouseDelta = input.Delta
		state.assistUntil = 0
		state.yaw -= input.Delta.X * config.sensitivity
		state.pitch = math.clamp(state.pitch - input.Delta.Y * config.sensitivity, config.pitchMin, config.pitchMax)
		DebugState.set("Camera", "LastMouseDeltaX", input.Delta.X)
	end)

	-- Телефон: камеру крутит палец, начавший касание вне кнопок и вне стика.
	-- Геймпад: правый стик (применяется в update с учётом dt).
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if gameProcessed or state.touchInput or inThumbstickArea(input.Position) then
			return
		end
		state.touchInput = input
		state.touchLast = Vector2.new(input.Position.X, input.Position.Y)
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input == state.touchInput then
			local position = Vector2.new(input.Position.X, input.Position.Y)
			local delta = position - (state.touchLast or position)
			state.touchLast = position
			if not state.locked or ClientState.isInputBlocked() then
				return
			end
			state.assistUntil = 0
			state.yaw -= delta.X * config.touchSensitivity.X
			state.pitch = math.clamp(state.pitch - delta.Y * config.touchSensitivity.Y, config.pitchMin, config.pitchMax)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			state.stick = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == state.touchInput then
			state.touchInput = nil
			state.touchLast = nil
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			state.stick = Vector2.zero
		end
	end)
	UserInputService.GamepadDisconnected:Connect(function()
		state.stick = Vector2.zero
	end)

	-- Слежение за курсором возвращаем, если игроки вышли из окна.
	UserInputService.WindowFocused:Connect(function()
		if state.locked and not ClientState.wantsCursor() then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
	end)

	-- Меню Roblox (Escape) должно отпускать мышь, иначе игрок заперт.
	GuiService.MenuOpened:Connect(function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end)
	GuiService.MenuClosed:Connect(function()
		if state.locked and not ClientState.wantsCursor() then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		end
	end)

	-- Свободный курсор ↔ бой.
	local cursorKeys = {}
	for _, key in ipairs(Binds.all("Cursor")) do
		cursorKeys[key] = true
	end
	local hinted = false
	local function setCursorFree(free: boolean)
		if state.cursorFree == free then
			return
		end
		state.cursorFree = free
		ClientState.lockInput("cursor", free)
		Bus.emit("cursorMode", { free = free })
		DebugState.set("Camera", "CursorFree", free)
		if free and not hinted then
			hinted = true
			Bus.emit("notify", { kind = "warn", text = "Курсор свободен · Alt или клик по миру — назад к бою" })
		end
	end
	CameraController.setCursorFree = setCursorFree
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if cursorKeys[input.KeyCode] then
			if UserInputService:GetFocusedTextBox() then
				return
			end
			-- В окнах курсор и так свободен — переключатель не нужен.
			if not state.cursorFree and ClientState.wantsCursor() then
				return
			end
			setCursorFree(not state.cursorFree)
		elseif state.cursorFree and input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessed then
			-- клик по миру, а не по кнопке, — назад в бой. Снимаем блокировку
			-- после всех обработчиков этого клика, чтобы он не стал ударом.
			task.defer(setCursorFree, false)
		end
	end)

	Bus.on("shake", function(data)
		local amount = data.amount or 0.2
		local time = data.time or 0.2
		-- Более сильная тряска перебивает слабую, слабая не обрезает сильную.
		if os.clock() >= fx.shakeUntil or amount >= fx.shakeAmount * ((fx.shakeUntil - os.clock()) / fx.shakeTotal) then
			fx.shakeAmount = amount
			fx.shakeTotal = time
			fx.shakeUntil = os.clock() + time
		end
	end)
	Bus.on("fov", function(data)
		fx.fovPunch = data.amount or 6
		fx.fovTotal = data.time or 0.25
		fx.fovUntil = os.clock() + fx.fovTotal
	end)

	RunService.RenderStepped:Connect(update)

	print("[CameraController] камера с фиксацией: за плечом; мышь, палец и правый стик крутят обзор")
	publish()
end

function CameraController.state()
	return state
end

-- Сценарий камеры: функция, возвращающая CFrame (и угол обзора) каждый кадр,
-- либо nil, чтобы вернуть управление игроку.
function CameraController.setOverride(callback)
	fx.override = callback
	if callback then
		fx.blendFrom = nil
	end
end

-- Чувствительность мыши для окна настроек (множитель к базовой 0.0022).
function CameraController.setSensitivity(mult: number)
	config.sensitivity = 0.0022 * math.clamp(mult, 0.3, 2.5)
end

-- Плавно вернуть камеру игроку после сцены (за blendTime секунд). lookAt —
-- куда развернуть взгляд (обычно на босса), иначе прежний угол.
function CameraController.release(blendTime: number?, lookAt: Vector3?)
	fx.override = nil
	local time = blendTime or 0.8
	if fx.lastOverride and time > 0 then
		fx.blendFrom = fx.lastOverride
		fx.blendFov = fx.lastFov or config.baseFov
		fx.blendStart = os.clock()
		fx.blendTime = time
	end
	fx.lastOverride = nil
	local _, _, root = characterParts()
	if lookAt and root then
		local d = lookAt - root.Position
		if Vector3.new(d.X, 0, d.Z).Magnitude > 0.5 then
			state.yaw = math.atan2(-d.X, -d.Z)
			state.pitch = math.rad(-12)
		end
	end
end

-- Доводка прицела (тач и геймпад): камера мягко доворачивает к цели за
-- ~0.2 с, корпус смотрит на неё сразу; ручной поворот доводку отменяет.
function CameraController.assistAim(target: Vector3, duration: number?)
	local _, _, root = characterParts()
	if not root then
		return
	end
	local d = target - root.Position
	if Vector3.new(d.X, 0, d.Z).Magnitude < 0.5 then
		return
	end
	state.assistYaw = math.atan2(-d.X, -d.Z)
	state.assistUntil = os.clock() + (duration or 0.22)
end

function CameraController.setLock(locked: boolean)
	applyLock(locked)
end

return CameraController
