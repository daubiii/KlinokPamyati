--!nonstrict
-- DodgeController (клиент)
-- Рывок: Q (см. Config.Binds). Направление — относительно камеры.
--
-- Порядок: клиент спрашивает сервер (RequestDodge), сервер проверяет
-- перезарядку и открывает окно неуязвимости, клиент двигает персонажа.
-- Клиент не решает, попал ли он — это правило §12 плана.
--
-- Клавиша вынесена в Config.Binds: экран переназначения будет менять только
-- её, не трогая контроллер. Прыжка в игре нет, поэтому пробел свободен.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Binds = require(Shared.Config.Binds)
local ClientState = require(Shared.Util.ClientState)
local Net = require(Shared.Net.Net)
local DebugState = require(Shared.Net.DebugState)

local Bus = require(script.Parent.Parent.Lib.Bus)
local TouchControls = require(script.Parent.TouchControls)
local PlayerAnimator = require(script.Parent.PlayerAnimator)

local DodgeController = {}

local player = Players.LocalPlayer

local runtime = {
	active = false,
	localCooldownUntil = 0,
	requests = 0,
	accepted = 0,
	rejected = 0,
	dashes = 0,
	lastDistance = 0,
	lastDuration = 0,
	lastReason = "none",
	lastDirection = "0,0,0",
	lastServerTime = 0,
}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function publish()
	DebugState.set("Dodge", "Requests", runtime.requests)
	DebugState.set("Dodge", "Accepted", runtime.accepted)
	DebugState.set("Dodge", "Rejected", runtime.rejected)
	DebugState.set("Dodge", "Dashes", runtime.dashes)
	DebugState.set("Dodge", "Active", runtime.active)
	DebugState.set("Dodge", "LastDistance", runtime.lastDistance)
	DebugState.set("Dodge", "LastDuration", runtime.lastDuration)
	DebugState.set("Dodge", "LastReason", runtime.lastReason)
	DebugState.set("Dodge", "LastDirection", runtime.lastDirection)
	DebugState.set("Dodge", "LastServerTime", runtime.lastServerTime)
	DebugState.set("Dodge", "CooldownLeft", math.max(runtime.localCooldownUntil - now(), 0))
end

local function characterParts()
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return nil
	end
	return character, humanoid, root
end

local function cameraFlatDirection()
	local camera = Workspace.CurrentCamera
	if not camera then
		return Vector3.new(0, 0, -1)
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

-- Куда рывок: в сторону ввода, если он есть, иначе вперёд по камере.
local function dodgeDirection(humanoid)
	local move = humanoid.MoveDirection
	if move.Magnitude > 0.1 then
		local flat = Vector3.new(move.X, 0, move.Z)
		if flat.Magnitude > 0.01 then
			return flat.Unit
		end
	end
	return cameraFlatDirection()
end

local function applyDash(direction, response)
	local _, humanoid, root = characterParts()
	if not humanoid or not root then
		return
	end

	local speed = response.speed or Combat.Dodge.dashSpeed
	local duration = response.duration or Combat.Dodge.dashDuration
	local startPosition = root.Position
	local previousWalkSpeed = humanoid.WalkSpeed

	runtime.active = true
	runtime.dashes += 1
	publish()

	humanoid.WalkSpeed = 0

	local startedAt = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startedAt
		if not root.Parent or elapsed >= duration then
			connection:Disconnect()
			runtime.active = false
			runtime.lastDistance = (root.Position - startPosition).Magnitude
			runtime.lastDuration = elapsed
			if humanoid.Parent then
				humanoid.WalkSpeed = previousWalkSpeed
			end
			publish()
			return
		end

		local currentVelocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(
			direction.X * speed,
			math.min(currentVelocity.Y, 2),
			direction.Z * speed
		)
	end)
end

local function onDodgeRequested()
	if runtime.active then
		runtime.lastReason = "busy"
		publish()
		return
	end
	if now() < runtime.localCooldownUntil then
		runtime.lastReason = "local-cooldown"
		publish()
		return
	end

	local _, humanoid = characterParts()
	if not humanoid or ClientState.isInputBlocked() then
		runtime.lastReason = "no-character"
		publish()
		return
	end
	if humanoid.Health <= 0 then
		runtime.lastReason = "dead"
		publish()
		return
	end

	local direction = dodgeDirection(humanoid)
	runtime.requests += 1
	runtime.lastDirection = ("%.2f, %.2f, %.2f"):format(direction.X, direction.Y, direction.Z)
	publish()

	local remote = Net.get("RequestDodge")
	if not remote then
		runtime.lastReason = "no-remote"
		publish()
		return
	end

	local ok, response = pcall(function()
		return remote:InvokeServer(direction)
	end)

	if not ok or type(response) ~= "table" then
		runtime.rejected += 1
		runtime.lastReason = ok and ("bad-response:" .. tostring(response)) or ("invoke-failed:" .. tostring(response))
		publish()
		return
	end

	if not response.ok then
		runtime.rejected += 1
		runtime.lastReason = tostring(response.reason or "rejected")
		if response.reason == "cooldown" and response.remaining then
			runtime.localCooldownUntil = now() + response.remaining
		end
		publish()
		return
	end

	runtime.accepted += 1
	runtime.lastReason = "ok"
	runtime.lastServerTime = response.serverTime or now()
	runtime.localCooldownUntil = now() + (response.cooldown or Combat.Dodge.cooldown)
	applyDash(direction, response)

	local duration = response.duration or Combat.Dodge.dashDuration
	PlayerAnimator.play("dash", duration + 0.16)
	Bus.emit("fov", { amount = 7, time = duration + 0.2 })
	Bus.emit("sfx", { name = "dash" })
	Bus.emit("dashFx", { direction = direction, duration = duration })
end

local function onAction(actionName, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	task.spawn(onDodgeRequested)
	return Enum.ContextActionResult.Sink
end

function DodgeController.start()
	local remote = Net.get("DodgePerformed")
	if remote then
		remote.OnClientEvent:Connect(function(payload)
			if payload and payload.dodgeId then
				DebugState.set("Dodge", "ServerDodgeId", payload.dodgeId)
			end
		end)
	end

	ContextActionService:BindAction("KlinokDodge", onAction, false, table.unpack(Binds.all("Dash")))
	-- Телефон: кнопка «РЫВОК» в кластере TouchControls (с перезарядкой).
	TouchControls.bind("KlinokDodge", {
		slot = "dash",
		label = "РЫВОК",
		handler = function(inputState)
			onAction("KlinokDodge", inputState)
		end,
		cooldown = function()
			return DodgeController.cooldownLeft()
		end,
	})

	publish()
	print("[DodgeController] рывок: Q / Shift (пробел — прыжок)")
end

-- Остаток перезарядки рывка: left, total (для HUD и сенсорной кнопки).
function DodgeController.cooldownLeft(): (number, number)
	return math.max(runtime.localCooldownUntil - now(), 0), Combat.Dodge.cooldown
end

function DodgeController.state()
	return runtime
end

return DodgeController
