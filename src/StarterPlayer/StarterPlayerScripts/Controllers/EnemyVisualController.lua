--!nonstrict
-- EnemyVisualController (клиент)
-- Рисует врагов (ТЗ врагов этажа 1, разделы 2.0 и 3.5). Сервер держит у
-- врага только невидимую Root-часть и атрибуты состояния (EnemyState,
-- EnemyStateAt, EnemyStateDur, EnemyAttack, EnemyTelegraph…); видимого врага
-- строит этот контроллер:
--   * клон префаба ReplicatedStorage.EnemyPrefabs.<typeId> (R15 с бронёй,
--     AnimationController) — ставится на позицию серверного Root со
--     сглаживанием, анимации играет EnemyAnimator по состоянию сервера;
--   * если префаба нет — запасной кубический риг (Lib/EnemyRigs), его кости
--     двигает та же поза EnemyAnimator;
--   * эффекты (телеграфы, кольцо, сборка, распад, душа, особые телеграфы) —
--     EnemyFx;
--   * LOD: дальше 60 стад поза 15 раз в секунду, дальше 80 — без частиц и
--     подсветки (кроме телеграфа), дальше 120 — модель скрыта.
-- Всё обновляется одним циклом PreSimulation: Transform суставов пишется
-- после движка анимаций и до физики (как у PlayerAnimator), Root-детали
-- всех врагов двигаются одним BulkMoveTo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anim = require(Shared.Util.Anim)
local Enemies = require(Shared.Config.Enemies)
local EnemyVisuals = require(Shared.Config.EnemyVisuals)
local Net = require(Shared.Net.Net)
local Resolve = require(Shared.Anim.Resolve)

local Bus = require(script.Parent.Parent.Lib.Bus)
local EnemyRigs = require(script.Parent.Parent.Lib.EnemyRigs)
local EnemyAnimator = require(script.Parent.EnemyAnimator)
local EnemyFx = require(script.Parent.EnemyFx)

local EnemyVisualController = {}

local rigs = {} -- [serverModel] = rig
local hitStopUntil = 0 -- хит-стоп способностей V2 (EnemyVisualController.hitStop)
local folder
local localPlayer = Players.LocalPlayer
local FX = EnemyVisuals.Fx

local V3 = Vector3.new
local RIG_HEIGHT = 5.2 -- рост R15 Block Rig при масштабе 1 (префабы)
local HRP_HEIGHT = 2.6 -- центр HumanoidRootPart над ступнями

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function visualsFolder()
	if folder and folder.Parent then
		return folder
	end
	folder = Workspace:FindFirstChild("EnemyVisuals")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "EnemyVisuals"
		folder.Parent = Workspace
	end
	return folder
end

-- ===== Запасной кубический риг =====

local function buildCubic(stats, model: Model)
	local descriptors, layout = EnemyRigs.describe(stats)
	local bones = {}
	for _, name in ipairs(EnemyRigs.nodeOrder) do
		local bone = Instance.new("Part")
		bone.Name = "Bone_" .. name
		bone.Size = V3(0.2, 0.2, 0.2)
		bone.Transparency = 1
		bone.Anchored = true
		bone.CanCollide = false
		bone.CanQuery = false
		bone.CanTouch = false
		bone.CastShadow = false
		bone.CFrame = CFrame.new(layout.absolute[name])
		bone.Parent = model
		bones[name] = bone
	end
	for _, descriptor in ipairs(descriptors) do
		local part = Instance.new("Part")
		part.Name = descriptor.role or "Voxel"
		part.Size = descriptor.size
		part.Color = descriptor.color
		part.Material = descriptor.material
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = descriptor.size.X * descriptor.size.Y > 0.3
		part.CFrame = bones[descriptor.node].CFrame * descriptor.offset
		if descriptor.role then
			part:SetAttribute("Role", descriptor.role)
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = bones[descriptor.node]
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	return bones, layout
end


-- Узлы кубического рига из позы R15: бедро ← LT, корпус ← UT, голова ← HD,
-- плечо ← UA, кисть ← LA + H, нога ← UL.
local function cubicNodes(rig, base: CFrame)
	local pose = rig.animator.pose
	local layout = rig.layout
	local pivot = layout.pivot
	local k = layout.H / RIG_HEIGHT
	local function angles(code: string, extraX: number?)
		local f = Resolve.FIELDS[code]
		return EnemyAnimator.rotation((pose[f[1]] or 0) + (extraX or 0), pose[f[2]] or 0, pose[f[3]] or 0)
	end
	local p = Resolve.FIELDS.LTp
	local lift = V3((pose[p[1]] or 0) * k, (pose[p[2]] or 0) * k, (pose[p[3]] or 0) * k)
	local nodes = rig.nodes
	nodes.hips = base * CFrame.new(pivot.hips + lift) * angles("LT")
	nodes.torso = nodes.hips * CFrame.new(pivot.torso) * angles("UT")
	nodes.head = nodes.torso * CFrame.new(pivot.head) * angles("HD")
	nodes.armR = nodes.torso * CFrame.new(pivot.armR) * angles("RUA")
	nodes.armL = nodes.torso * CFrame.new(pivot.armL) * angles("LUA")
	nodes.handR = nodes.armR * CFrame.new(pivot.handR) * angles("RLA", pose.RH_x or 0)
	nodes.handL = nodes.armL * CFrame.new(pivot.handL) * angles("LLA", pose.LH_x or 0)
	nodes.legR = nodes.hips * CFrame.new(pivot.legR) * angles("RUL")
	nodes.legL = nodes.hips * CFrame.new(pivot.legL) * angles("LUL")
	return nodes
end

-- ===== Построение =====

local function build(serverModel)
	local typeId = serverModel:GetAttribute("EnemyType")
	local ok, stats = pcall(Enemies.stats, typeId, "normal")
	if not ok then
		return nil
	end
	local config = EnemyVisuals.get(typeId)
	if not config then
		return nil
	end

	local prefabs = ReplicatedStorage:FindFirstChild("EnemyPrefabs")
	-- Элита (guard_elite…) берёт префаб обычного врага: config.prefab.
	local prefab = prefabs and (prefabs:FindFirstChild(typeId) or (config.prefab and prefabs:FindFirstChild(config.prefab)))
	local model, animator, bones, layout, scale
	if prefab and prefab:IsA("Model") and prefab.PrimaryPart then
		model = prefab:Clone()
		model.Name = "Visual_" .. stats.name
		if prefab.Name ~= typeId and config.scale then
			model:ScaleTo(config.scale)
		end
		if config.elite then
			-- Элита: свечение (глаза, руны) в цвет eyeColor.
			local glow = model:FindFirstChild("Glow")
			for _, part in ipairs(glow and glow:GetDescendants() or {}) do
				if part:IsA("BasePart") then
					part.Color = config.eyeColor
				end
			end
		end
		scale = model:GetScale()
		animator = EnemyAnimator.new(model, typeId)
	else
		model = Instance.new("Model")
		model.Name = "Visual_" .. stats.name
		bones, layout = buildCubic(stats, model)
		scale = layout.H / RIG_HEIGHT
		animator = EnemyAnimator.new(model, typeId, { motors = false, scale = scale })
	end

	local rig: any = {
		server = serverModel,
		root = serverModel:FindFirstChild("Root") or serverModel.PrimaryPart,
		stats = stats,
		typeId = typeId,
		config = config,
		model = model,
		prefab = bones == nil,
		bones = bones,
		layout = layout,
		nodes = {},
		scale = scale,
		hrpOffset = HRP_HEIGHT * scale,
		animator = animator,
		pos = nil,
		groundY = 0,
		facing = V3(0, 0, -1),
		velocity = Vector3.zero,
		kick = Vector3.zero,
		state = "",
		stateAt = 0,
		stateDur = 0,
		attack = "none",
		lastAttack = "none",
		progress = 0,
		hidden = false,
		dead = false,
		deadAt = 0,
		finished = false,
		animAccum = 0,
		fx = nil,
	}

	EnemyFx.attach(rig)
	animator:onMarker(function(name: string, animName: string)
		EnemyFx.onMarker(rig, name, animName)
		-- Сцены появления и эффекты фирменных атак слушают маркеры анимаций.
		Bus.emit("enemyMarker", { rig = rig, name = name, anim = animName })
		if name == "Shatter" then
			EnemyFx.shatter(rig)
			rig.finished = true
		end
	end)
	model.Parent = visualsFolder()
	return rig
end

-- ===== Состояние =====

local function readState(rig, serverTime: number)
	local server = rig.server
	local state = server:GetAttribute("EnemyState") or "idle"
	local stateAt = server:GetAttribute("EnemyStateAt") or serverTime
	if state == rig.state and stateAt == rig.stateAt then
		return
	end
	local previous = rig.state
	local attack = server:GetAttribute("EnemyAttack") or "none"
	rig.state = state
	rig.stateAt = stateAt
	rig.stateDur = server:GetAttribute("EnemyStateDur") or 0
	if attack ~= "none" then
		rig.lastAttack = attack
		rig.attack = attack
	elseif state == "recover" or state == "dash" or state == "channel" then
		-- Сервер стирает EnemyAttack перед восстановлением: помним последнюю.
		rig.attack = rig.lastAttack
	else
		rig.attack = "none"
	end
	rig.animator.bossPhase = server:GetAttribute("BossPhase") or 1
	rig.animator:setState(state, attack, stateAt, rig.stateDur)
	EnemyFx.onState(rig, previous, state)

	-- Свою сцену появления (Config/BossIntros) ведёт BossIntroController:
	-- сборки из кубиков нет.
	if state == "spawning" and previous == "" and rig.prefab and not rig.config.introScene then
		local elapsed = math.max(serverTime - stateAt, 0)
		if elapsed < rig.stateDur * 0.6 then
			EnemyFx.beginSpawn(rig, elapsed)
		end
	end
	if state == "dead" and not rig.dead then
		rig.dead = true
		rig.deadAt = os.clock()
		-- Треснувший взорвался: ударной анимации нет, распад сразу.
		if rig.fx and rig.fx.exploded then
			EnemyFx.shatter(rig)
			rig.finished = true
		end
	end
end

-- ===== Кадр =====

local hrpParts, hrpCFrames = {}, {}
local slowStep = 1 / FX.lodSlowRate

local function update(dt: number)
	local serverTime = serverNow()
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	table.clear(hrpParts)
	table.clear(hrpCFrames)

	for _, rig in pairs(rigs) do
		if rig.finished then
			continue
		end
		local root = rig.root
		if not root or not root.Parent then
			continue
		end

		-- Позиция и разворот: сглаживаем 20-герцовые обновления сервера.
		local height = rig.stats.height
		local target = root.Position - V3(0, height / 2, 0)
		local look = root.CFrame.LookVector
		look = V3(look.X, 0, look.Z)
		if look.Magnitude < 0.01 then
			look = rig.facing
		end
		if not rig.pos then
			rig.pos = target
			rig.facing = look.Unit
		end
		local previous = rig.pos
		rig.pos = Anim.dampVector(rig.pos, target, 20, dt)
		rig.groundY = target.Y
		local velocity = (rig.pos - previous) / math.max(dt, 1e-3)
		rig.velocity = Anim.dampVector(rig.velocity, velocity, 10, dt)
		local newFacing = Anim.dampVector(rig.facing, look.Unit, 14, dt)
		if newFacing.Magnitude > 0.01 then
			rig.facing = newFacing.Unit
		end

		readState(rig, serverTime)
		if rig.finished then
			continue
		end
		-- Подстраховка: ждём завершения анимации смерти, включая длинные сцены боссов.
		local deathAnim = rig.animator.set and rig.animator.set.Death
		local deathWait = math.max(1.6, (deathAnim and deathAnim.length or 0) + 0.25)
		if rig.dead and os.clock() - rig.deadAt > deathWait then
			EnemyFx.shatter(rig)
			rig.finished = true
			continue
		end

		-- LOD.
		local distance = (rig.pos - eye).Magnitude
		local hide = distance > FX.lodHide
		if hide ~= rig.hidden then
			rig.hidden = hide
			rig.model.Parent = if hide then nil else visualsFolder()
			if hide and rig.fx and rig.fx.ring then
				rig.fx.ring.Transparency = 1
			end
		end
		local view = rig.view or {}
		rig.view = view
		view.distance = distance
		view.farFx = distance > FX.lodFx

		-- Отдача от попадания затухает.
		rig.kick = Anim.dampVector(rig.kick, Vector3.zero, 12, dt)
		local feet = rig.pos + rig.kick
		-- Прыжок босса (доп.): дуга вверх, пока он в воздухе.
		if rig.state == "dash" and rig.attack == "leap" and rig.stateDur > 0 then
			local k = math.clamp((serverTime - rig.stateAt) / rig.stateDur, 0, 1)
			feet += V3(0, math.sin(math.pi * k) * height * 0.6, 0)
		end
		-- Этаж 2: отскок мохового следопыта (F2HopAt) — короткая дуга 0,3 с.
		local hopAt = rig.server:GetAttribute("F2HopAt")
		if hopAt then
			local k = (serverTime - hopAt) / 0.3
			if k >= 0 and k < 1 then
				feet += V3(0, math.sin(math.pi * k) * 1.4, 0)
			end
		end
		-- Сцена появления (BossIntroController): насест, смещение, свой разворот.
		if rig.introOffset then
			feet += rig.introOffset
		end
		local facing = rig.introFacing or rig.facing
		local base = CFrame.lookAt(feet, feet + facing)

		if not hide then
			-- Поза: вблизи каждый кадр, дальше 60 стад — 15 раз в секунду.
			rig.animAccum += dt
			local step = distance > FX.lodSlow and slowStep or 0
			if os.clock() < hitStopUntil or rig.server:GetAttribute("TimeFrozen") then
				rig.animAccum = 0 -- хит-стоп / остановка времени («Дары Эха»): поза стоит
			elseif rig.animAccum >= step then
				local animDt = rig.animAccum
				rig.animAccum = 0
				rig.animator:setLocomotion(rig.velocity, rig.facing)
				rig.animator:update(animDt, serverTime)
				if rig.prefab then
					rig.animator:apply()
				end
			end
			if rig.prefab then
				table.insert(hrpParts, rig.model.PrimaryPart)
				table.insert(hrpCFrames, base * CFrame.new(0, rig.hrpOffset, 0))
			else
				local nodes = cubicNodes(rig, base)
				for name, bone in pairs(rig.bones) do
					table.insert(hrpParts, bone)
					table.insert(hrpCFrames, nodes[name])
				end
			end
			EnemyFx.update(rig, dt, serverTime, view)
		end
	end

	if #hrpParts > 0 then
		Workspace:BulkMoveTo(hrpParts, hrpCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	EnemyFx.step(dt)
	EnemyFx.flush()
end

-- ===== События =====

local function handleEvent(payload)
	if type(payload) ~= "table" then
		return
	end
	local model = payload.model
	local rig = model and rigs[model]
	local kind = payload.kind

	if kind == "death" and payload.killer == localPlayer and payload.position then
		-- Душа павшего уходит в клинок того, кто его сразил.
		EnemyFx.soul(payload.position)
	end
	if not rig or rig.finished then
		return
	end

	if kind == "damage" then
		EnemyFx.hitFlash(rig, false)
		rig.animator:playOneShot("Hit")
		local character = localPlayer.Character
		local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
		if playerRoot and rig.pos then
			local away = V3(rig.pos.X - playerRoot.Position.X, 0, rig.pos.Z - playerRoot.Position.Z)
			if away.Magnitude > 0.1 then
				rig.kick = away.Unit * (rig.stats.isBoss and FX.hitKickBoss or FX.hitKick)
			end
		end
	elseif kind == "parried" then
		EnemyFx.hitFlash(rig, true)
	elseif kind == "wallHit" then
		rig.animator:noteWallHit()
	elseif kind == "area" and payload.attack == "explode" and payload.position then
		EnemyFx.explosion(payload.position, payload.radius or 4, rig)
	elseif kind == "area" and payload.attack == "chains" and type(payload.positions) == "table" then
		EnemyFx.chainFall(payload.positions, payload.radius or 3, rig)
	end
end

local function destroyRig(serverModel)
	local rig = rigs[serverModel]
	if not rig then
		return
	end
	rigs[serverModel] = nil
	EnemyFx.detach(rig)
	rig.animator:destroy()
	rig.model:Destroy()
end

local function track(instance)
	if rigs[instance] or not instance:IsA("Model") or not instance:GetAttribute("EnemyType") then
		return
	end
	task.defer(function()
		if rigs[instance] or not instance.Parent then
			return
		end
		local rig = build(instance)
		if rig then
			rigs[instance] = rig
			instance.AncestryChanged:Connect(function(_, parent)
				if parent == nil then
					destroyRig(instance)
				end
			end)
		end
	end)
end

function EnemyVisualController.rigOf(serverModel)
	return rigs[serverModel]
end

-- Все живые риги: serverModel → rig (эффекты способностей: подсветка врагов в зоне).
function EnemyVisualController.all()
	return rigs
end

-- Хит-стоп (способности V2): позы врагов замирают на duration секунд — удар «весит».
function EnemyVisualController.hitStop(duration: number)
	hitStopUntil = math.max(hitStopUntil, os.clock() + duration)
end

function EnemyVisualController.start()
	visualsFolder()
	EnemyFx.start()
	Workspace.DescendantAdded:Connect(track)
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		track(descendant)
	end

	local remote = Net.get("EnemyEvent")
	if remote then
		remote.OnClientEvent:Connect(handleEvent)
	end

	-- После движка анимаций и до физики (см. PlayerAnimator).
	local ok = pcall(function()
		RunService.PreSimulation:Connect(update)
	end)
	if not ok then
		RunService.Heartbeat:Connect(update)
	end
	print("[EnemyVisualController] враги: префабы R15 + EnemyAnimator")
end

return EnemyVisualController
