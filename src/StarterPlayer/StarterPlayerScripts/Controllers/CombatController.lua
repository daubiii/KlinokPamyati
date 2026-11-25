--!nonstrict
-- CombatController (клиент)
-- Удар (ЛКМ), парирование (ПКМ), лечение (F). Клиент показывает и отправляет
-- намерение, сервер считает попадание и урон (§12).
--
-- Удобство: зажатая кнопка бьёт серию сама, нажатие чуть раньше конца паузы
-- запоминается (буфер 0,18 с) — комбо не «глотает» клики.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Weapons = require(Shared.Config.Weapons)
local Binds = require(Shared.Config.Binds)
local ClientState = require(Shared.Util.ClientState)
local Net = require(Shared.Net.Net)
local DebugState = require(Shared.Net.DebugState)

local PlayerAnimator = require(script.Parent.PlayerAnimator)
local Bus = require(script.Parent.Parent.Lib.Bus)
local CameraController = require(script.Parent.CameraController)
local TouchControls = require(script.Parent.TouchControls)

local CombatController = {}

local player = Players.LocalPlayer

local BUFFER = 0.18

local lunge -- объявлена ниже

local runtime = {
	attacks = 0,
	lastCombo = 0,
	lastDamage = 0,
	lastHits = 0,
	parries = 0,
	heals = 0,
	rejected = 0,
	lastReason = "none",
	attackCooldownUntil = 0,
	parryUntil = 0,
	recoveringUntil = 0,
	lastCounter = false,
	attackHeld = false,
	bufferedUntil = 0,
	busy = false,
}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function publish()
	DebugState.set("Combat", "Attacks", runtime.attacks)
	DebugState.set("Combat", "LastCombo", runtime.lastCombo)
	DebugState.set("Combat", "LastDamage", runtime.lastDamage)
	DebugState.set("Combat", "LastHits", runtime.lastHits)
	DebugState.set("Combat", "Parries", runtime.parries)
	DebugState.set("Combat", "Rejected", runtime.rejected)
	DebugState.set("Combat", "LastReason", runtime.lastReason)
	DebugState.set("Combat", "LastCounter", runtime.lastCounter)
	DebugState.set("Combat", "Recovering", now() < runtime.recoveringUntil)
end

local function humanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function canAct(): boolean
	local body = humanoid()
	return body ~= nil and body.Health > 0 and not ClientState.isInputBlocked()
end

-- Выпад: корпус подаётся вперёд за ударом. Если перед героем враг —
-- шаг к нему (но не вплотную), если врагов нет — короткий шажок на месте,
-- чтобы зажатая атака не «увозила» героя через всю комнату. Персонаж свой
-- (сетевой владелец — клиент), поэтому двигаем его локально. Стену впереди
-- проверяем лучом, чтобы не «влезть» в кладку.
local LUNGE = {
	sword = { 1.6, 1.6, 2.4 },
	hammer = { 1.2, 1.4, 2.0 },
	dagger = { 1.4, 1.4, 2.0 },
}
local LUNGE_IDLE = 0.35
local LUNGE_SEEK = 7 -- на таком расстоянии враг «притягивает» выпад
local LUNGE_GAP = 2.6 -- ближе этого к врагу не подходим

-- Ближайший враг в конусе перед героем: (дистанция) или nil.
local ENEMY_FOLDERS = { "Floor", "Floor2", "Floor3", "Floor4", "Floor5", "DebugEnemies" } -- враги этажей и из отладочной команды spawn

local function enemyAhead(root, forward: Vector3)
	local models = {}
	for _, name in ipairs(ENEMY_FOLDERS) do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			for _, d in ipairs(folder:GetDescendants()) do
				table.insert(models, d)
			end
		end
	end
	local best
	for _, model in ipairs(models) do
		if model:IsA("Model") and model:GetAttribute("EnemyType") and (model:GetAttribute("EnemyHealth") or 0) > 0 then
			local enemyRoot = model.PrimaryPart
			if enemyRoot then
				local offset = enemyRoot.Position - root.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local distance = flat.Magnitude - (model:GetAttribute("EnemyBodyRadius") or 1)
				if distance < LUNGE_SEEK and flat.Magnitude > 0.1 and forward:Dot(flat.Unit) > 0.6 then
					if not best or distance < best then
						best = distance
					end
				end
			end
		end
	end
	return best
end

-- Возвращает длину выпада и направление (сервер целит удар из точки после выпада).
-- Доводка удара (тач и геймпад): мышью игрок целится сам, а пальцем точно
-- навестись трудно. Ближайший живой враг в широком конусе перед камерой:
-- корпус сразу разворачивается к нему (направление удара уходит на сервер),
-- камера мягко доворачивает следом.
local ASSIST_RANGE = 12
local ASSIST_DOT = 0.35 -- конус ≈ ±70° от взгляда камеры

local function assistWanted(): boolean
	if TouchControls.isTouch() then
		return true
	end
	local last = UserInputService:GetLastInputType()
	return string.sub(last.Name, 1, 7) == "Gamepad"
end

local function aimAssist()
	if not assistWanted() then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if not root or not camera then
		return
	end
	local look = camera.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 0.01 then
		return
	end
	forward = forward.Unit
	local best, bestScore = nil, math.huge
	for _, name in ipairs(ENEMY_FOLDERS) do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			for _, model in ipairs(folder:GetDescendants()) do
				if model:IsA("Model") and model:GetAttribute("EnemyType") and (model:GetAttribute("EnemyHealth") or 0) > 0 then
					local enemyRoot = model.PrimaryPart
					if enemyRoot then
						local offset = enemyRoot.Position - root.Position
						local flat = Vector3.new(offset.X, 0, offset.Z)
						local distance = flat.Magnitude - (model:GetAttribute("EnemyBodyRadius") or 1)
						if distance < ASSIST_RANGE and flat.Magnitude > 0.1 and math.abs(offset.Y) < 12 then
							local dot = forward:Dot(flat.Unit)
							if dot > ASSIST_DOT then
								-- ближе и ровнее по взгляду — лучше
								local score = math.max(distance, 0) + (1 - dot) * 8
								if score < bestScore then
									best, bestScore = enemyRoot.Position, score
								end
							end
						end
					end
				end
			end
		end
	end
	if best then
		local flat = Vector3.new(best.X - root.Position.X, 0, best.Z - root.Position.Z)
		if flat.Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
			CameraController.assistAim(best)
		end
	end
end

function lunge(combo: number, weaponType: string): (number, Vector3?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return 0, nil
	end
	local distances = LUNGE[weaponType] or LUNGE.sword
	local distance = distances[math.clamp(combo, 1, #distances)]
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 0.01 then
		return 0, nil
	end
	forward = forward.Unit
	-- Посох мага бьёт снарядами с места: без выпада, только направление.
	if weaponType == "staff" then
		return 0, forward
	end
	local target = enemyAhead(root, forward)
	if target then
		distance = math.clamp(target - LUNGE_GAP, 0, distance)
	else
		distance = LUNGE_IDLE
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(root.Position, forward * (distance + 1.5), params)
	if hit then
		distance = math.max((hit.Position - root.Position).Magnitude - 1.6, 0)
	end
	if distance <= 0.05 then
		return 0, forward
	end
	local duration = combo == 3 and 0.16 or 0.11
	local moved = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not root.Parent then
			connection:Disconnect()
			return
		end
		local step = math.min(distance / duration * dt, distance - moved)
		moved += step
		root.CFrame += forward * step
		if moved >= distance - 0.001 then
			connection:Disconnect()
		end
	end)
	return distance, forward
end

local function requestAttack()
	if runtime.busy then
		return
	end
	if not canAct() then
		return
	end
	-- Идёт способность оружия: удар не начинаем (сервер тоже откажет).
	if now() < math.max(ClientState.castingUntil(), player:GetAttribute("CastingUntil") or 0) then
		return
	end
	if now() < runtime.attackCooldownUntil then
		-- Нажали чуть рано: удар уйдёт, как только пауза закончится.
		if runtime.attackCooldownUntil - now() <= BUFFER then
			runtime.bufferedUntil = now() + BUFFER
		end
		return
	end
	if now() < runtime.recoveringUntil then
		return
	end

	local remote = Net.get("RequestAttack")
	if not remote then
		return
	end

	-- Анимация и выпад — сразу, не дожидаясь сервера (раздел 12: «анимации
	-- и эффекты клиент запускает сразу»). Номер удара предсказываем по той же
	-- логике окна комбо, что и сервер; урон всё равно считает сервер.
	local cooldownGuess = runtime.lastCooldown or Combat.Attack.hitInterval
	local inWindow = now() - (runtime.lastAttackAt or -10) <= cooldownGuess + Combat.Attack.comboWindow
	local predicted = inWindow and (runtime.lastCombo % Combat.Attack.comboLength) + 1 or 1
	local weaponType = player:GetAttribute("WeaponType") or "sword"
	local weaponId = player:GetAttribute("WeaponId")
	runtime.lastAttackAt = now()
	-- После завершающего удара серии — восстановление (как на сервере).
	local pause = cooldownGuess
	if predicted == Combat.Attack.comboLength then
		pause = Weapons.finisherInterval(cooldownGuess, weaponType, Combat.Attack.comboRecovery, weaponId)
	end
	runtime.attackCooldownUntil = now() + pause
	PlayerAnimator.attack(predicted, cooldownGuess, weaponType, weaponId)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	aimAssist()
	local lungeDistance, forward = lunge(predicted, weaponType)
	local aim = nil
	if root then
		forward = forward or root.CFrame.LookVector
		aim = { origin = root.Position + forward * lungeDistance, forward = forward }
	end

	runtime.busy = true
	local ok, response = pcall(function()
		return remote:InvokeServer(aim)
	end)
	runtime.busy = false

	if not ok or type(response) ~= "table" or not response.ok then
		runtime.rejected += 1
		runtime.lastReason = ok and tostring(type(response) == "table" and response.reason or "bad") or "invoke-failed"
		publish()
		return
	end

	runtime.attacks += 1
	runtime.lastCombo = response.combo or predicted
	runtime.lastDamage = response.damage or 0
	runtime.lastHits = response.hits or 0
	runtime.lastCounter = response.counter == true
	runtime.lastReason = "ok"
	runtime.lastCooldown = response.cooldown or Combat.Attack.hitInterval
	if response.pause then
		runtime.attackCooldownUntil = math.max(runtime.attackCooldownUntil, runtime.lastAttackAt + response.pause - 0.05)
		runtime.attackPause = response.pause
	end
	publish()
end

local function requestParry()
	if not canAct() then
		return
	end
	if now() < runtime.recoveringUntil or now() < runtime.parryUntil then
		return
	end
	local remote = Net.get("RequestParry")
	if not remote then
		return
	end

	local ok, response = pcall(function()
		return remote:InvokeServer()
	end)
	if not ok or type(response) ~= "table" or not response.ok then
		runtime.lastReason = "parry-rejected"
		-- Барьер мага (вместо парирования) стоит ману.
		if ok and type(response) == "table" and response.reason == "no-mana" then
			Bus.emit("notify", { kind = "warn", text = "Не хватает маны для барьера" })
			Bus.emit("sfx", { name = "barrierNoMana" })
			PlayerAnimator.play("parryFail", 0.3)
		end
		publish()
		return
	end

	runtime.parries += 1
	runtime.lastReason = "parry-window"
	runtime.parryUntil = now() + (response.window or 0.3)
	runtime.recoveringUntil = runtime.parryUntil + (response.failPause or Combat.Parry.failPause)
	PlayerAnimator.play("parry", (response.window or 0.3) * 1.2)
	publish()
end

local function requestHeal()
	if not canAct() then
		return
	end
	local remote = Net.get("RequestHeal")
	if not remote then
		return
	end
	local ok, response = pcall(function()
		return remote:InvokeServer()
	end)
	if not ok or type(response) ~= "table" or not response.ok then
		runtime.lastReason = "heal:" .. tostring(ok and type(response) == "table" and response.reason or "failed")
		-- Подсказка вместо тишины: у игрока нет зарядов или здоровье полное.
		local reason = ok and type(response) == "table" and response.reason or nil
		local text = reason == "no-charges" and "Нет зарядов лечения" or (reason == "full" and "Здоровье полное" or nil)
		if text then
			Bus.emit("notify", { kind = "warn", text = text })
		end
		publish()
		return
	end

	runtime.heals += 1
	runtime.lastReason = "healed"
	PlayerAnimator.play("heal", 0.7)
	publish()
end

local function bindInputs()
	-- Клавиатура, мышь и геймпад — через CAS; телефон — свой кластер кнопок
	-- (TouchControls): штатные кнопки CAS наезжали на прыжок PlayerModule.
	local function bind(name, action, handler, touch)
		ContextActionService:BindAction(name, function(_, inputState)
			handler(inputState)
			return Enum.ContextActionResult.Sink
		end, false, table.unpack(Binds.all(action)))
		touch.handler = handler
		TouchControls.bind(name, touch)
	end

	bind("KlinokAttack", "Attack", function(inputState)
		if inputState == Enum.UserInputState.Begin then
			runtime.attackHeld = true
			task.spawn(requestAttack)
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			runtime.attackHeld = false
		end
	end, { slot = "attack", label = "УДАР" })

	bind("KlinokParry", "Parry", function(inputState)
		if inputState == Enum.UserInputState.Begin then
			task.spawn(requestParry)
		end
	end, { slot = "parry", label = "ЩИТ" })

	bind("KlinokHeal", "Heal", function(inputState)
		if inputState == Enum.UserInputState.Begin then
			task.spawn(requestHeal)
		end
	end, {
		slot = "heal",
		label = "ЛЕЧ",
		count = function()
			return player:GetAttribute("HealCharges")
		end,
	})
end

function CombatController.start()
	-- Исход столкновений приходит от сервера: показываем реакции.
	local feedback = Net.get("CombatFeedback")
	if feedback then
		feedback.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then
				return
			end
			if payload.kind == "parry" then
				runtime.parryUntil = 0
				runtime.recoveringUntil = 0
				PlayerAnimator.play("parryHit", 0.4)
				PlayerAnimator.hitStop(Combat.Feel.parryStop)
			elseif payload.kind == "parryFail" then
				runtime.recoveringUntil = now() + (payload.pause or Combat.Parry.failPause)
				PlayerAnimator.play("parryFail", payload.pause or Combat.Parry.failPause)
			elseif payload.kind == "hit" then
				PlayerAnimator.play("hurt", 0.35)
			end
		end)
	end

	bindInputs()

	-- Серия при зажатой кнопке и буфер раннего нажатия.
	RunService.Heartbeat:Connect(function()
		if runtime.busy or now() < runtime.attackCooldownUntil then
			return
		end
		if runtime.attackHeld or now() < runtime.bufferedUntil then
			runtime.bufferedUntil = 0
			task.spawn(requestAttack)
		end
	end)

	publish()
	print("[CombatController] ЛКМ = удар, ПКМ = парирование, F = лечение")
end

function CombatController.state()
	return runtime
end

return CombatController
