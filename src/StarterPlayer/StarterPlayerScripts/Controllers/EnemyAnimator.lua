--!nonstrict
-- EnemyAnimator (клиент)
-- Проигрывание анимаций врагов (ТЗ врагов, раздел 3.5). Не контроллер, а
-- класс: EnemyVisualController создаёт по экземпляру на врага.
--
--   local animator = EnemyAnimator.new(visualModel, typeId)
--   animator:setState(stateName, attackId, stateAt, stateDur)
--   animator:setLocomotion(velocity, facing)       -- каждый кадр
--   animator:playOneShot("Hit")
--   animator:onMarker(function(name, animName) end)
--   animator:update(dt, serverTime)                 -- считает позу
--   animator:apply()                                -- пишет Motor6D.Transform
--   animator:destroy()
--
-- Как устроено:
--   * Таблицы ключевых кадров (Shared/Anim, раскрытые Resolve) сэмплируются
--     Util/Anim.sample. Поза — плоская таблица градусов (RUA_x …) и стадов
--     (LTp_x …), сустава нет — он в покое.
--   * Два слоя: движение (Idle/Walk/Strafe) всегда снизу, действие сверху с
--     весом 0 → 1 за 0,06 с и 1 → 0 за 0,12 с после конца. Новое действие
--     стартует из текущей позы (from = "pose") или доводится за 0,09 с.
--   * Длительность берёт сервер: скорость = длина / EnemyStateDur, время
--     действия считается от EnemyStateAt — опоздавший клиент попадает в ту
--     же фазу удара. Замах (*_Windup) и любая неповторяемая анимация
--     замирают на последнем кадре до смены состояния.
--   * Hit — отдельный аддитивный слой: отдача поверх текущей позы, которая
--     к концу возвращается в ноль (поза замаха не сбивается — раздел 2.3).
--   * Поза сустава = CFrame.new(LTp) * rotation(x, y, z) — см. rotation():
--     Y применяется после подъёма. Смещения LTp умножаются на масштаб
--     модели: Model:ScaleTo не масштабирует Transform.
--   * Transform пишется как есть; поверх трека AnimationId — домножением
--     на позу, которую движок записал в этом кадре (см. write).
--   * Процедурное поверх (раздел 3.4): рывки головы и дрожь Треснувшего,
--     табард стража, плащ Тени, гребень Латника, цепи и корона Привратника.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anim = require(Shared.Util.Anim)
local Resolve = require(Shared.Anim.Resolve)
local EnemyVisuals = require(Shared.Config.EnemyVisuals)

local EnemyAnimator = {}
EnemyAnimator.__index = EnemyAnimator

-- Код сустава → имя Motor6D стандартного R15.
EnemyAnimator.MOTORS = {
	LT = "Root",
	UT = "Waist",
	HD = "Neck",
	RUA = "RightShoulder",
	RLA = "RightElbow",
	RH = "RightWrist",
	LUA = "LeftShoulder",
	LLA = "LeftElbow",
	LH = "LeftWrist",
	RUL = "RightHip",
	RLL = "RightKnee",
	RF = "RightAnkle",
	LUL = "LeftHip",
	LLL = "LeftKnee",
	LF = "LeftAnkle",
}

local JOINTS = Resolve.JOINTS
local FIELDS = Resolve.FIELDS
local KEYS = Resolve.KEYS

local ACTION_IN = 0.06
local ACTION_OUT = 0.12
local CARRY = 0.09
local MOVE_FADE = 0.15
local HIT_STATES = { idle = true, approach = true, retreat = true, circle = true, recover = true }
local MOVE_STATES = { idle = true, approach = true, retreat = true, circle = true }

local rad = math.rad

local function clearTable(t)
	for key in pairs(t) do
		t[key] = nil
	end
end

local function copyPose(from, to)
	clearTable(to)
	for key, value in pairs(from) do
		to[key] = value
	end
end

-- Поворот сустава по углам ТЗ (градусы). Порядок — сначала Z (в сторону),
-- затем X (вперёд-вверх), затем Y (влево) относительно родителя:
-- Angles(0, y, 0) · Angles(x, 0, z), как в PlayerAnimator. Буквальный
-- CFrame.Angles(x, y, z) из раздела 3.1 крутит поднятую руку вокруг её же
-- оси, и контрольная поза стрелка (рука на цель) не выходит — решение
-- владельца 21.10.2026. Проверочные позы 3.1 при этом не меняются.
function EnemyAnimator.rotation(x: number, y: number, z: number): CFrame
	return CFrame.Angles(0, rad(y), 0) * CFrame.Angles(rad(x), 0, rad(z))
end

-- CFrame сустава из плоской позы (градусы, стады × scale).
function EnemyAnimator.jointCFrame(pose, code: string, scale: number): CFrame
	local fields = FIELDS[code]
	local rotation = EnemyAnimator.rotation(pose[fields[1]] or 0, pose[fields[2]] or 0, pose[fields[3]] or 0)
	if code == "LT" then
		local p = FIELDS.LTp
		return CFrame.new((pose[p[1]] or 0) * scale, (pose[p[2]] or 0) * scale, (pose[p[3]] or 0) * scale) * rotation
	end
	return rotation
end

local function newLayer()
	return {
		anim = nil,
		name = nil,
		time = 0,
		lastTime = 0,
		rate = 1,
		weight = 0,
		fading = false,
		track = nil,
		amp = 1,
		frames = {}, -- рабочий список кадров (первый — снимок позы при from = "pose")
		startFrame = {},
		sample = {},
		carry = {},
		carryTime = 0,
		-- Время действия от сервера.
		serverStart = 0,
		after = nil, -- { name, amp } — что играть, когда закончится текущая
	}
end

-- options: motors = false — не искать Motor6D (кубический запасной риг),
-- scale — масштаб, если у модели нет GetScale.
function EnemyAnimator.new(model: Model, typeId: string, options)
	local opts = options or {}
	local config = EnemyVisuals.get(typeId) or EnemyVisuals.get("guard")
	local self = setmetatable({}, EnemyAnimator)
	self.model = model
	self.typeId = typeId
	self.config = config
	self.set = Resolve.forSet(config.set)
	self.scale = opts.scale or 1
	if opts.scale == nil then
		local ok, value = pcall(function()
			return model:GetScale()
		end)
		if ok and type(value) == "number" then
			self.scale = value
		end
	end

	self.motors = {}
	self.secondary = { chains = {} }
	if opts.motors ~= false then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("Motor6D") then
				local name = descendant.Name
				for code, motorName in pairs(EnemyAnimator.MOTORS) do
					if motorName == name then
						self.motors[code] = descendant
					end
				end
				if name == "Tabard" then
					self.secondary.tabard = descendant
				elseif name == "Cloak" then
					self.secondary.cloak = descendant
				elseif name == "Crest" then
					self.secondary.crest = descendant
				elseif name == "Crown" then
					self.secondary.crown = descendant
				elseif string.match(name, "^Chain") then
					table.insert(self.secondary.chains, { motor = descendant, x = 0, z = 0 })
				elseif name == "WingR" or name == "WingL" then
					-- Этаж 2: крылья пчелы-мутанта (машут процедурно).
					self.secondary.wings = self.secondary.wings or {}
					table.insert(self.secondary.wings, { motor = descendant, side = name == "WingR" and 1 or -1 })
				end
			end
		end
		table.sort(self.secondary.chains, function(a, b)
			return a.motor.Name < b.motor.Name
		end)
	end

	self.move = newLayer()
	self.action = newLayer()
	self.hit = newLayer()
	self.moveFrom = {}
	self.moveFade = 0
	self.pose = {} -- итог кадра (плоский)
	self.state = "spawning"
	self.attackId = "none"
	self.lastAttack = "none"
	self.stateAt = 0
	self.stateDur = 0
	self.speed = 0
	self.forward = 0
	self.lateral = 0
	self.clock = 0
	self.listeners = {}
	self.pendingWallHit = false
	self.twitch = { nextAt = 1 + math.random() * 2, untilT = 0, y = 0, z = 0 }
	self.crownKick = 0
	self.lastDt = 1 / 60
	self.random = Random.new()

	-- Запасной путь: AnimationId из конфига (раздел 3.0 п. 3).
	self.tracks = {}
	local animatorInstance = model:FindFirstChildWhichIsA("Animator", true)
	if animatorInstance and next(config.animIds or {}) ~= nil then
		self.animatorInstance = animatorInstance
	end

	self:setMovement(EnemyVisuals.Defaults.idle, 1)
	return self
end

function EnemyAnimator:onMarker(callback)
	table.insert(self.listeners, callback)
end

function EnemyAnimator:emit(name: string, animName: string)
	for _, listener in ipairs(self.listeners) do
		listener(name, animName)
	end
end

-- ===== Запасной путь: AnimationId =====

function EnemyAnimator:trackFor(name: string)
	if not self.animatorInstance then
		return nil
	end
	local id = self.config.animIds and self.config.animIds[name]
	if not id or id == "" then
		return nil
	end
	local track = self.tracks[name]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		track = self.animatorInstance:LoadAnimation(animation)
		local anim = self.set[name]
		for _, marker in ipairs(anim and anim.markers or {}) do
			track:GetMarkerReachedSignal(marker.name):Connect(function()
				self:emit(marker.name, name)
			end)
		end
		self.tracks[name] = track
	end
	return track
end

function EnemyAnimator:stopTrack(layer)
	if layer.track then
		layer.track:Stop(CARRY)
		layer.track = nil
	end
end

-- ===== Слои =====

-- Подготовить рабочие кадры слоя: при from = "pose" первый кадр — снимок
-- текущей позы. Таблицы переиспользуются, в кадре ничего не создаётся.
local function prepareFrames(layer, anim, currentPose)
	local frames = layer.frames
	clearTable(frames)
	for index, frame in ipairs(anim.frames) do
		frames[index] = frame
	end
	if anim.fromPose then
		local start = layer.startFrame
		copyPose(currentPose, start)
		start.t = 0
		start.ease = anim.frames[1].ease
		frames[1] = start
	end
end

function EnemyAnimator:setMovement(name: string, rate: number)
	local layer = self.move
	local anim = self.set[name]
	if not anim then
		return
	end
	if layer.name ~= name then
		-- Плавная смена ходьбы и покоя: держим прежнюю позу движения.
		if layer.anim then
			copyPose(layer.sample, self.moveFrom)
			self.moveFade = MOVE_FADE
		end
		layer.name = name
		layer.anim = anim
		prepareFrames(layer, anim, self.pose)
		layer.time = rate < 0 and anim.length or 0
		layer.lastTime = layer.time
		self:stopTrack(layer)
		local track = self:trackFor(name)
		if track then
			track:Play(MOVE_FADE)
			layer.track = track
		end
	end
	layer.rate = rate
	if layer.track then
		layer.track:AdjustSpeed(rate)
	end
end

-- Запустить анимацию слоя действия. speed — множитель времени, serverStart —
-- серверное время её начала (nil — считать локально).
function EnemyAnimator:playAction(name: string?, speed: number, serverStart: number?, amp: number?)
	local layer = self.action
	local anim = name and self.set[name] or nil
	if not anim then
		-- Нечего играть: слой гаснет.
		layer.fading = true
		layer.after = nil
		self:stopTrack(layer)
		return
	end
	if layer.anim and layer.weight > 0.01 and not anim.fromPose then
		copyPose(self.pose, layer.carry)
		layer.carryTime = CARRY
	else
		layer.carryTime = 0
	end
	layer.name = name
	layer.anim = anim
	layer.rate = speed
	layer.amp = amp or 1
	layer.fading = false
	layer.after = nil
	layer.serverStart = serverStart
	layer.time = 0
	layer.lastTime = -1e-6
	prepareFrames(layer, anim, self.pose)

	self:stopTrack(layer)
	local track = self:trackFor(name :: string)
	if track then
		track:Play(ACTION_IN)
		track:AdjustSpeed(speed)
		layer.track = track
	end
end

function EnemyAnimator:playOneShot(name: string)
	if name == "Hit" and not HIT_STATES[self.state] then
		return
	end
	local anim = self.set[name]
	if not anim then
		return
	end
	local layer = self.hit
	layer.name = name
	layer.anim = anim
	layer.time = 0
	layer.lastTime = -1e-6
	layer.weight = 1
	-- Аддитивный слой: первый кадр (from = "pose") — ноль.
	clearTable(layer.frames)
	for index, frame in ipairs(anim.frames) do
		layer.frames[index] = frame
	end
	if anim.fromPose then
		clearTable(layer.startFrame)
		layer.startFrame.t = 0
		layer.startFrame.ease = anim.frames[1].ease
		layer.frames[1] = layer.startFrame
	end
end

-- Анимации состояния сервера (таблица раздела 3.5).
function EnemyAnimator:setState(stateName: string, attackId: string?, stateAt: number, stateDur: number)
	local previous = self.state
	self.state = stateName
	self.stateAt = stateAt
	self.stateDur = stateDur
	local attack = attackId or "none"
	if attack ~= "none" then
		self.lastAttack = attack
	end
	self.attackId = attack
	local config = self.config
	local defaults = EnemyVisuals.Defaults
	local attackConfig = config.attacks[attack] or config.attacks[self.lastAttack]

	local function stretched(name: string?): number
		local anim = name and self.set[name]
		if not anim or stateDur <= 0 then
			return 1
		end
		return anim.length / stateDur
	end

	if stateName == "spawning" then
		local name = config.spawn or defaults.spawn
		self:playAction(name, config.spawn and 1 or stretched(name), stateAt)
		-- Сцена босса, к которой подключились с опозданием (короткая сцена,
		-- поздний вход): прошлые маркеры не играем пачкой.
		local anim = name and self.set[name]
		if config.introScene and anim and stateAt then
			local elapsed = Workspace:GetServerTimeNow() - stateAt
			if elapsed > 0.2 then
				self.action.lastTime = math.min(elapsed, anim.length)
			end
		end
	elseif MOVE_STATES[stateName] then
		self:playAction(nil, 1)
	elseif stateName == "windup" then
		local name = attackConfig and attackConfig.windup
		self:playAction(name, stretched(name), stateAt)
	elseif stateName == "dash" then
		local name = attackConfig and attackConfig.dash
		if name then
			-- Рывок: свой темп (раздел 3.5, скорость 1). Полёт прыжка (доп.)
			-- растягивается на время в воздухе.
			self:playAction(name, self.lastAttack == "leap" and stretched(name) or 1, stateAt)
		end
	elseif stateName == "strike" then
		local name = attackConfig and attackConfig.strike
		if attackConfig and attackConfig.strikeDouble and stateDur >= 0.3 then
			name = attackConfig.strikeDouble
		end
		if name then
			self:playAction(name, stateDur > 0.2 and stretched(name) or 1, stateAt)
		end
	elseif stateName == "recover" then
		local name = attackConfig and attackConfig.recover
		self:playAction(name, stretched(name), stateAt)
	elseif stateName == "channel" then
		-- Канал фирменной атаки босса (Systems/BossMoves): петля — в своём
		-- темпе, разовая — растягивается на время канала.
		local name = attackConfig and attackConfig.channel
		local anim = name and self.set[name]
		self:playAction(name, (anim and anim.loop) and 1 or stretched(name), stateAt)
	elseif stateName == "stunned" then
		if self.pendingWallHit and config.wallHit then
			self.pendingWallHit = false
			self:playAction(config.wallHit, 1, stateAt)
			self.action.after = { name = defaults.stun, amp = config.stunAmp or 1 }
		else
			self:playAction(defaults.stun, 1, stateAt)
		end
	elseif stateName == "phase" then
		local name = config.phase
		if type(name) == "table" then
			name = name[self.bossPhase or 2] or name[2]
		end
		self:playAction(name, 1, stateAt)
	elseif config.states and config.states[stateName] then
		-- Свои состояния мини-боссов (reload у Арбалетчицы): петля до смены.
		self:playAction(config.states[stateName], 1, stateAt)
	elseif stateName == "dead" then
		self:playAction(defaults.death, 1, nil)
	end

	if stateName ~= previous and stateName == "dead" then
		self.hit.anim = nil
	end
end

-- Событие сервера wallHit приходит раньше смены состояния на stunned.
function EnemyAnimator:noteWallHit()
	self.pendingWallHit = true
end

-- Скорость и направление визуала (сглаженные), каждый кадр.
function EnemyAnimator:setLocomotion(velocity: Vector3, facing: Vector3)
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = flat.Magnitude
	self.speed = speed
	local defaults = EnemyVisuals.Defaults
	if speed < 0.6 or not MOVE_STATES[self.state] then
		self:setMovement(defaults.idle, 1)
		return
	end
	local forwardDir = Vector3.new(facing.X, 0, facing.Z)
	if forwardDir.Magnitude < 0.01 then
		forwardDir = Vector3.new(0, 0, -1)
	end
	forwardDir = forwardDir.Unit
	local right = forwardDir:Cross(Vector3.yAxis)
	local forward = flat:Dot(forwardDir)
	local lateral = flat:Dot(right)
	self.forward = forward
	self.lateral = lateral
	if self.state == "circle" and math.abs(lateral) >= speed * 0.5 and self.set[defaults.strafe] then
		self:setMovement(defaults.strafe, lateral >= 0 and 1 or -1)
	else
		local rate = math.clamp(speed / defaults.walkBaseSpeed, 0.5, 2)
		self:setMovement(defaults.walk, forward >= 0 and rate or -rate)
	end
end

-- ===== Кадр =====

-- Маркеры между lastTime и time (с учётом зацикливания и обратного хода).
local function fireMarkers(self, layer, from: number, to: number)
	local anim = layer.anim
	local markers = anim.markers
	if #markers == 0 then
		return
	end
	local length = anim.length
	local function range(a: number, b: number)
		for _, marker in ipairs(markers) do
			if marker.t > a and marker.t <= b then
				self:emit(marker.name, layer.name)
			end
		end
	end
	if to >= from then
		if anim.loop and to - from >= length then
			range(-1, length)
		else
			range(from, to)
		end
	else
		-- Обратный ход или переход через конец цикла.
		if anim.loop and layer.rate > 0 then
			range(from, length)
			range(-1, to)
		else
			for _, marker in ipairs(markers) do
				if marker.t >= to and marker.t < from then
					self:emit(marker.name, layer.name)
				end
			end
		end
	end
end

local function wrap(time: number, length: number): number
	if length <= 0 then
		return 0
	end
	return time % length
end

function EnemyAnimator:advanceAction(dt: number, serverTime: number?)
	local layer = self.action
	local anim = layer.anim
	if not anim then
		layer.weight = math.max(layer.weight - dt / ACTION_OUT, 0)
		return
	end

	local time
	if layer.serverStart and serverTime then
		time = math.max(serverTime - layer.serverStart, 0) * layer.rate
	else
		time = layer.time + dt * layer.rate
	end
	if anim.loop then
		local previous = layer.lastTime
		local wrapped = wrap(time, anim.length)
		fireMarkers(self, layer, previous, wrapped)
		layer.time = time
		layer.lastTime = wrapped
	else
		fireMarkers(self, layer, layer.lastTime, math.min(time, anim.length))
		layer.time = time
		layer.lastTime = math.min(time, anim.length)
		if time >= anim.length and layer.after then
			local nextAnim = layer.after
			layer.after = nil
			local start = layer.serverStart and (layer.serverStart + anim.length / layer.rate) or nil
			self:playAction(nextAnim.name, 1, start, nextAnim.amp)
			return
		end
	end

	if layer.fading then
		layer.weight = math.max(layer.weight - dt / ACTION_OUT, 0)
		if layer.weight <= 0 then
			layer.anim = nil
			layer.name = nil
		end
	else
		layer.weight = math.min(layer.weight + dt / ACTION_IN, 1)
	end
end

local function sampleLayer(layer, out)
	local anim = layer.anim
	local time = anim.loop and wrap(layer.time, anim.length) or math.min(layer.time, anim.length)
	Anim.sample(layer.frames, time, out)
	if layer.amp ~= 1 then
		for key, value in pairs(out) do
			out[key] = value * layer.amp
		end
	end
	return out
end

local scratch = {}

function EnemyAnimator:update(dt: number, serverTime: number?)
	self.clock += dt
	self.lastDt = dt
	local pose = self.pose

	-- Движение.
	local move = self.move
	if move.anim then
		local length = move.anim.length
		local previous = move.lastTime or 0
		move.time += dt * move.rate
		local wrapped = wrap(move.time, length)
		if self.action.weight < 0.5 then
			fireMarkers(self, move, previous, wrapped)
		end
		move.lastTime = wrapped
		sampleLayer(move, move.sample)
	end
	copyPose(move.sample, pose)
	if self.moveFade > 0 then
		local k = Anim.ease.sine(1 - self.moveFade / MOVE_FADE)
		for _, key in ipairs(KEYS) do
			local from = self.moveFrom[key]
			local to = pose[key]
			if from or to then
				pose[key] = (from or 0) + ((to or 0) - (from or 0)) * k
			end
		end
		self.moveFade = math.max(self.moveFade - dt, 0)
	end

	-- Действие поверх.
	self:advanceAction(dt, serverTime)
	local action = self.action
	if action.anim and action.weight > 0 and not action.track then
		local sample = sampleLayer(action, action.sample)
		if action.carryTime > 0 then
			local k = 1 - action.carryTime / CARRY
			for _, key in ipairs(KEYS) do
				local from = action.carry[key]
				local to = sample[key]
				if from or to then
					sample[key] = (from or 0) + ((to or 0) - (from or 0)) * k
				end
			end
			action.carryTime = math.max(action.carryTime - dt, 0)
		end
		local w = Anim.ease.quadInOut(action.weight)
		for _, key in ipairs(KEYS) do
			local a = pose[key]
			local b = sample[key]
			if a or b then
				pose[key] = (a or 0) + ((b or 0) - (a or 0)) * w
			end
		end
	elseif action.track then
		-- Действие играет штатный трек: процедурное движение гаснет под ним.
		local keep = 1 - action.weight
		for key, value in pairs(pose) do
			pose[key] = value * keep
		end
	end

	-- Отдача от попадания (аддитивно).
	local hit = self.hit
	if hit.anim then
		hit.time += dt
		if hit.time >= hit.anim.length then
			hit.anim = nil
		else
			Anim.sample(hit.frames, hit.time, scratch)
			for key, value in pairs(scratch) do
				pose[key] = (pose[key] or 0) + value
			end
		end
	end

	self:procedural(dt)
end

-- Процедурное поверх таблиц (раздел 3.4).
function EnemyAnimator:procedural(dt: number)
	local pose = self.pose
	local typeId = self.typeId
	local action = self.action
	if typeId == "martyr" then
		-- Рывки головы в покое: раз в 1,5–3 с на 0,08 с.
		local twitch = self.twitch
		local idle = self.state == "idle" or self.state == "approach"
		if idle and self.clock >= twitch.nextAt then
			twitch.untilT = self.clock + 0.08
			twitch.nextAt = self.clock + 1.5 + self.random:NextNumber() * 1.5
			twitch.y = (self.random:NextNumber() < 0.5 and -15 or 15)
			twitch.z = (self.random:NextNumber() < 0.5 and -10 or 10)
		end
		if self.clock < twitch.untilT then
			pose.HD_y = (pose.HD_y or 0) + twitch.y
			pose.HD_z = (pose.HD_z or 0) + twitch.z
		end
		-- Дрожь корпуса в замахе: 0,05 + 0,2 × прогресс.
		if action.name == "Explode_Windup" and action.anim then
			local progress = math.clamp(action.time / action.anim.length, 0, 1)
			local amount = 0.05 + 0.2 * progress
			pose.LTp_x = (pose.LTp_x or 0) + (self.random:NextNumber() - 0.5) * 2 * amount
			pose.LTp_y = (pose.LTp_y or 0) + (self.random:NextNumber() - 0.5) * 2 * amount * 0.5
			pose.LTp_z = (pose.LTp_z or 0) + (self.random:NextNumber() - 0.5) * 2 * amount
		end
	end
	-- Этаж 2: пчела парит над землёй (traits.hover, раздел этажа 2) — подъём
	-- и покачивание поверх любой анимации, кроме смерти.
	local hover = self.config.hover
	if hover then
		local dying = self.state == "dead"
		self.hoverK = self.hoverK or 0
		local target = (dying or self.state == "spawning") and 0 or 1
		self.hoverK += math.clamp(target - self.hoverK, -dt * 2, dt * 2)
		local bob = math.sin(self.clock * 3.2) * 0.12
		pose.LTp_y = (pose.LTp_y or 0) + (hover + bob) * self.hoverK
	end
	self.crownKick = math.max(self.crownKick - dt * 4, 0)
end

-- Шаг (маркер Step) встряхивает корону босса.
function EnemyAnimator:kickCrown()
	self.crownKick = 1
end

-- Записать позу в Motor6D. Без треков AnimationId поза пишется как есть.
-- Приём PlayerAnimator («помнить записанное и сравнивать с прочитанным»)
-- здесь не годится: Transform читается обратно не бит-в-бит, сравнение
-- иногда не срабатывает, и поза домножалась на себя каждый кадр — враги
-- разваливались и улетали (плейтест 21.10.2026). Когда играет трек, движок
-- сам пишет его позу перед PreSimulation, и наша ложится поверх.
local function write(overTrack: boolean, joint, cf: CFrame)
	if overTrack then
		joint.Transform = joint.Transform * cf
	else
		joint.Transform = cf
	end
end

function EnemyAnimator:apply()
	local pose = self.pose
	local scale = self.scale
	local overTrack = self.move.track ~= nil or self.action.track ~= nil
	for _, code in ipairs(JOINTS) do
		local motor = self.motors[code]
		if motor and motor.Parent then
			write(overTrack, motor, EnemyAnimator.jointCFrame(pose, code, scale))
		end
	end

	local secondary = self.secondary
	local t = self.clock
	if secondary.tabard then
		-- ТЗ 2.4.1: −0,6 × max(угол бедра) в пределах [−35°, 0] + sin(2t)·2°.
		local hip = math.max(pose.RUL_x or 0, pose.LUL_x or 0)
		local x = math.clamp(-0.6 * hip, -35, 0) + math.sin(t * 2) * 2
		write(false, secondary.tabard, CFrame.Angles(rad(x), 0, 0))
	end
	if secondary.cloak then
		-- ТЗ 2.4.2: 10° + 1,5° × скорость + sin(3t)·4°, не больше 70°.
		local x = math.min(10 + 1.5 * self.speed + math.sin(t * 3) * 4, 70)
		write(false, secondary.cloak, CFrame.Angles(rad(x), 0, 0))
	end
	if secondary.crest then
		-- ТЗ 2.4.3: ±3° по X с темпом шага.
		local move = self.move
		local walking = move.name == EnemyVisuals.Defaults.walk and move.anim
		local x = walking and 3 * math.sin(move.time / move.anim.length * math.pi * 4) or 0
		write(false, secondary.crest, CFrame.Angles(rad(x), 0, 0))
	end
	if secondary.crown then
		local x = self.crownKick * 2 * math.sin(t * 40)
		write(false, secondary.crown, CFrame.Angles(rad(x), 0, 0))
	end
	if secondary.wings then
		-- Взмах ~9 Гц по оси вперёд (крыло вверх-вниз), на замахе — назад
		-- и чаще; в оглушении крылья опущены и дрожат.
		local state = self.state
		local stunned = state == "stunned" or state == "dead"
		local fast = state == "windup" or state == "dash" or state == "strike"
		local rate = stunned and 30 or (fast and 75 or 58)
		local amp = stunned and 6 or (fast and 32 or 26)
		local sweep = fast and -22 or 0
		local rest = stunned and -25 or 10
		for _, wing in ipairs(secondary.wings) do
			local z = (rest + amp * math.sin(t * rate)) * wing.side
			write(false, wing.motor, CFrame.Angles(0, rad(sweep * wing.side), 0) * CFrame.Angles(0, 0, rad(z)))
		end
	end
	if #secondary.chains > 0 then
		-- Цепи висят отвесно: гасим поворот плеча и локтя, каждое следующее
		-- звено догоняет предыдущее с запаздыванием ~0,05 с.
		-- Имена звеньев: ChainL, ChainR (заглушка) или ChainL1…ChainL4.
		local k = 1 - math.exp(-(self.lastDt or 1 / 60) / 0.05)
		for index, link in ipairs(secondary.chains) do
			local group = string.sub(link.motor.Name, 1, 6)
			local prefix = group == "ChainL" and "L" or "R"
			local targetX, targetZ
			if index == 1 or string.sub(secondary.chains[index - 1].motor.Name, 1, 6) ~= group then
				targetX = -((pose.UT_x or 0) + (pose[prefix .. "UA_x"] or 0) + (pose[prefix .. "LA_x"] or 0))
				targetZ = -(pose[prefix .. "UA_z"] or 0)
			else
				local previous = secondary.chains[index - 1]
				targetX, targetZ = previous.x, previous.z
			end
			targetX = math.clamp(targetX, -80, 80)
			targetZ = math.clamp(targetZ, -80, 80)
			link.x += (targetX - link.x) * k
			link.z += (targetZ - link.z) * k
			write(false, link.motor, CFrame.Angles(rad(link.x), 0, rad(link.z)))
		end
	end
end

-- Поставить позу напрямую (проверочные позы раздела 3.1). Слои выключаются
-- до следующей смены состояния.
function EnemyAnimator:debugPose(nested)
	clearTable(self.pose)
	for code, value in pairs(nested) do
		local fields = FIELDS[code]
		if fields then
			self.pose[fields[1]] = value[1] or 0
			self.pose[fields[2]] = value[2] or 0
			self.pose[fields[3]] = value[3] or 0
		end
	end
	self.move.anim = nil
	self.move.name = nil
	self.action.anim = nil
	self.hit.anim = nil
	clearTable(self.move.sample)
	self:apply()
end

function EnemyAnimator:destroy()
	for _, track in pairs(self.tracks) do
		track:Stop(0)
		track:Destroy()
	end
	self.tracks = {}
	self.listeners = {}
	self.motors = {}
end

return EnemyAnimator
