--!nonstrict
-- AbilityController (клиент)
-- Способность оружия — клавиша 1, активная душа босса — клавиша 2,
-- умение класса — клавиша 3 (маг: «Покров»; сервер — AbilityService.hooks.slot3).
-- Сервер проверяет наличие способности, перезарядку и радиус; клиент просит,
-- проигрывает анимацию и показывает перезарядку в HUD (по атрибутам игрока
-- Cd_<id> и CdLen_<id>, которые ставит сервер).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Binds = require(Shared.Config.Binds)
local LootMage = require(Shared.Config.LootMage)
local ClientState = require(Shared.Util.ClientState)
local DebugState = require(Shared.Net.DebugState)
local Net = require(Shared.Net.Net)

local Bus = require(script.Parent.Parent.Lib.Bus)
local PlayerAnimator = require(script.Parent.PlayerAnimator)
local PlayerAnimMage = require(script.Parent.PlayerAnimMage)
local TouchControls = require(script.Parent.TouchControls)

local AbilityController = {}

local player = Players.LocalPlayer

-- Анимация по идентификатору способности: { имя, длительность }.
local ANIMATIONS = {
	vortex = { "vortex", 1.0 },
	rift = { "riftSlam", 0.7 },
	unlock = { "unlockThrow", 0.6 },
	whirl = { "whirl", 0.55 },
	sunder = { "slam", 0.7 },
	reap = { "reap", 0.55 },
	flood = { "flood", 0.7 },
	prune = { "prune", 0.6 },
	gate_barrier = { "barrier", 0.7 },
	guard_verdict = { "thrust", 0.7 },
}

-- Этажи 3–5: способности → анимации из PlayerAnimWeapons (связка терялась при наложении пакета мага).
for abilityId, animation in pairs(require(script.Parent.PlayerAnimWeapons).AbilityAnimations) do
	ANIMATIONS[abilityId] = animation
end

-- Заклинания посохов и «Покров» (PlayerAnimMage.SPELL_ANIM): поза на время каста + выход.
for id, animation in pairs(PlayerAnimMage.SPELL_ANIM) do
	local spell = LootMage.Abilities[id]
	local castTime = spell and spell.castTime or 0.25
	-- id воина не перетираем (у посоха и косы ловчего было общее имя last_hunt)
	if not ANIMATIONS[id] then
		ANIMATIONS[id] = { animation, math.max(castTime + 0.35, 0.6) }
	end
end

local NO_ABILITY = {
	[1] = "У оружия нет способности",
	[2] = "Нет активной души",
	[3] = "Покров — умение мага",
}

local runtime = {
	uses = 0,
	lastReason = "none",
	lastHits = 0,
	busy = false,
}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function publish()
	DebugState.set("Ability", "Uses", runtime.uses)
	DebugState.set("Ability", "LastReason", runtime.lastReason)
	DebugState.set("Ability", "LastHits", runtime.lastHits)
end

-- Рывок способности («Последний гон»): сервер присылает move { direction, distance, time, delay }.
-- Двигаем героя сами, как уворот (DodgeController): скорость корня на Heartbeat, ходьба на время рывка 0.
-- Блок терялся при наложении пакетов: сервер рывок присылал, клиент его не применял.
local function applyMove(move)
	if type(move) ~= "table" or typeof(move.direction) ~= "Vector3" then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	local direction = Vector3.new(move.direction.X, 0, move.direction.Z)
	if direction.Magnitude < 0.01 then
		return
	end
	direction = direction.Unit
	local duration = math.max(tonumber(move.time) or 0.2, 0.05)
	local speed = (tonumber(move.distance) or 0) / duration
	task.delay(tonumber(move.delay) or 0, function()
		if not root.Parent or humanoid.Health <= 0 then
			return
		end
		local previousWalkSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = 0
		local startedAt = os.clock()
		local connection
		connection = RunService.Heartbeat:Connect(function()
			if not root.Parent or os.clock() - startedAt >= duration then
				connection:Disconnect()
				if root.Parent then
					local v = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(v.X * 0.2, v.Y, v.Z * 0.2)
				end
				if humanoid.Parent then
					humanoid.WalkSpeed = previousWalkSpeed
				end
				return
			end
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(direction.X * speed, math.min(v.Y, 2), direction.Z * speed)
		end)
	end)
end

local function request(slot: number)
	if runtime.busy or ClientState.isInputBlocked() then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local remote = Net.get("RequestAbility")
	if not remote then
		return
	end

	runtime.busy = true
	local ok, response = pcall(function()
		return remote:InvokeServer(slot)
	end)
	runtime.busy = false

	if not ok or type(response) ~= "table" then
		runtime.lastReason = "invoke-failed"
		publish()
		return
	end
	if not response.ok then
		runtime.lastReason = tostring(response.reason)
		if response.reason == "no-ability" then
			Bus.emit("notify", { kind = "warn", text = NO_ABILITY[slot] or NO_ABILITY[1] })
		elseif response.reason == "no-mana" then
			Bus.emit("notify", { kind = "warn", text = "Не хватает маны" })
			if player:GetAttribute("WeaponType") == "staff" then
				PlayerAnimator.play("staffBarrierFail", 0.3)
			end
		elseif response.reason == "no-target" then
			Bus.emit("notify", { kind = "warn", text = "Нет цели рядом" })
		elseif response.reason == "busy" or response.reason == "casting" then
			-- молча: способность уже идёт
		elseif response.reason == "cooldown" then
			Bus.emit("notify", { kind = "warn", text = ("Перезарядка: %.0f с"):format(response.remaining or 0) })
		end
		publish()
		return
	end

	runtime.uses += 1
	runtime.lastReason = "ok"
	runtime.lastHits = response.hits or 0
	local animation = ANIMATIONS[response.ability] or { "slam", 0.7 }
	PlayerAnimator.play(animation[1], animation[2])
	if (slot == 1 or slot == 3) and response.castTime then
		ClientState.setCasting(now() + response.castTime)
	end
	-- Рывок способности («Последний гон» и подобные): сервер присылает move.
	if response.move then
		applyMove(response.move)
	end
	publish()
end

-- Готовность способности для HUD: { id, name, left, length } либо nil.
function AbilityController.info(slot: number)
	local id
	if slot == 1 then
		id = player:GetAttribute("WeaponAbility")
		if id == nil or id == "" then
			return nil
		end
	elseif slot == 3 then
		id = player:GetAttribute("ClassAbility")
		if id == nil or id == "" then
			return nil
		end
	else
		id = player:GetAttribute("SoulActive")
		if id == nil or id == "" then
			return nil
		end
	end
	local readyAt = player:GetAttribute("Cd_" .. id) or 0
	return {
		id = id,
		left = math.max(readyAt - now(), 0),
		length = player:GetAttribute("CdLen_" .. id) or 1,
	}
end

function AbilityController.start()
	-- Клавиши — через CAS, телефон — кнопки кластера TouchControls (пустой
	-- слот скрыт, перезарядка видна на кнопке).
	local touchLabels = { "ОРУЖ", "ДУША", "КЛАСС" }
	for slot, action in ipairs({ "Ability1", "Ability2", "Ability3" }) do
		local name = "KlinokAbility" .. slot
		local function handler(inputState)
			if inputState == Enum.UserInputState.Begin then
				task.spawn(request, slot)
			end
		end
		ContextActionService:BindAction(name, function(_, inputState)
			handler(inputState)
			return Enum.ContextActionResult.Sink
		end, false, table.unpack(Binds.all(action)))
		TouchControls.bind(name, {
			slot = "ability" .. slot,
			label = touchLabels[slot],
			handler = handler,
			visible = function()
				return AbilityController.info(slot) ~= nil
			end,
			cooldown = function()
				local info = AbilityController.info(slot)
				if info then
					return info.left, info.length
				end
				return 0, 1
			end,
		})
	end

	publish()
	print("[AbilityController] способность оружия: 1, активная душа: 2, умение класса: 3")
end

function AbilityController.state()
	return runtime
end

return AbilityController
