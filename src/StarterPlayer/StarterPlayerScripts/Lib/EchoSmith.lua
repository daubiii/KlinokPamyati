--!nonstrict
-- EchoSmith (клиент)
-- Отзвук — призрак-кузнец в сцене Горнила. Модель из деталей (EchoSmith внутри
-- ForgeStage): группы Body, Tail, Hood, Eye, ArmR, ArmL, Hammer, Mote и
-- маркеры ShoulderR / ShoulderL / Head. Анимация — только на клиенте,
-- workspace:BulkMoveTo раз в кадр:
--   парение и покачивание, волна хвоста, кружащие кубики, моргание;
--   strike() — замах и удар молотом (колбэк в момент удара);
--   joy() — руки вверх и вихрь частиц; no() — качает капюшоном и тускнеет;
--   talk() — кивает и «бормочет» (звук smith_voice), глаза ярче.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SmithLines = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("SmithLines"))
local UiSound = require(script.Parent.UiSound)

local EchoSmith = {}
EchoSmith.__index = EchoSmith

local lastLine = {}

-- Случайная реплика по ключу (без повтора подряд), с подстановкой {item}/{n}.
function EchoSmith.line(key: string, vars): string
	local set = SmithLines[key]
	if not set or #set == 0 then
		return ""
	end
	local index = math.random(1, #set)
	if #set > 1 and index == lastLine[key] then
		index = index % #set + 1
	end
	lastLine[key] = index
	local text = set[index]
	if vars then
		text = text:gsub("{(%w+)}", function(name)
			return vars[name] ~= nil and tostring(vars[name]) or ""
		end)
	end
	return text
end

local function attachment(model, name: string)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Attachment") and d.Name == name then
			return d
		end
	end
	return nil
end

function EchoSmith.attach(scene)
	local model = scene and scene:FindFirstChild("EchoSmith", true)
	if not model then
		return nil
	end
	local self = setmetatable({}, EchoSmith)
	self.model = model
	self.root = model:GetPivot()
	self.groups = { Body = {}, Tail = {}, Hood = {}, Eye = {}, ArmR = {}, ArmL = {}, Hammer = {}, Mote = {} }
	self.parts = {}
	self.rel = {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local group = self.groups[part.Name] and part.Name or "Body"
			table.insert(self.groups[group], part)
			table.insert(self.parts, part)
			self.rel[part] = self.root:ToObjectSpace(part.CFrame)
			part.Anchored = true
		end
	end
	local function localPos(name, default)
		local a = attachment(model, name)
		if a then
			return self.root:PointToObjectSpace(a.WorldPosition)
		end
		return default
	end
	self.shoulderR = localPos("ShoulderR", Vector3.new(1.25, 4.6, 0))
	self.shoulderL = localPos("ShoulderL", Vector3.new(-1.25, 4.6, 0))
	self.head = localPos("Head", Vector3.new(0, 5.75, 0))
	self.eyeColor = {}
	for _, eye in ipairs(self.groups.Eye) do
		self.eyeColor[eye] = eye.Color
	end
	-- состояние анимации
	self.armR = 0 -- угол руки с молотом (рад), + вперёд/вниз
	self.armL = 0
	self.nod = 0
	self.dim = 0
	self.spin = 0
	self.anim = nil
	self.started = os.clock()
	self.nextBlink = os.clock() + 2 + math.random() * 3
	self.blinkUntil = 0
	self.conn = RunService.RenderStepped:Connect(function()
		self:step()
	end)
	return self
end

-- Ключевые кадры: список {время, armR, armL, nod, spin}, интерполяция smoothstep.
function EchoSmith:play(keys, onEvent)
	self.anim = { keys = keys, started = os.clock(), onEvent = onEvent, fired = {} }
end

local function smooth(t)
	return t * t * (3 - 2 * t)
end

function EchoSmith:sampleAnim()
	local anim = self.anim
	if not anim then
		return nil
	end
	local t = os.clock() - anim.started
	local keys = anim.keys
	for i, k in ipairs(keys) do
		if k.event and t >= k[1] and not anim.fired[i] then
			anim.fired[i] = true
			if anim.onEvent then
				task.spawn(anim.onEvent, k.event)
			end
		end
	end
	if t >= keys[#keys][1] then
		self.anim = nil
		return keys[#keys]
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t >= a[1] and t < b[1] then
			local u = smooth((t - a[1]) / math.max(b[1] - a[1], 1e-3))
			return { 0, a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u, (a[4] or 0) + ((b[4] or 0) - (a[4] or 0)) * u, (a[5] or 0) + ((b[5] or 0) - (a[5] or 0)) * u }
		end
	end
	return keys[1]
end

function EchoSmith:step()
	if not self.model.Parent then
		self:destroy()
		return
	end
	local now = os.clock()
	local t = now - self.started
	local pose = self:sampleAnim()
	if pose then
		self.armR, self.armL, self.nod, self.spin = pose[2], pose[3], pose[4] or 0, pose[5] or 0
	else
		-- покой: молот покачивается у плеча
		self.armR = math.sin(t * 1.3) * 0.08
		self.armL = math.sin(t * 1.1 + 1) * 0.1
		self.spin = 0
		self.nod = self.talking and math.sin(t * 9) * 0.06 or 0
	end

	local bob = math.sin(t * 2.6) * 0.35
	local base = self.root * CFrame.new(0, bob, 0) * CFrame.Angles(0, math.sin(t * 0.5) * 0.08 + self.spin, math.sin(t * 0.8) * 0.02)
	local shoulderR = CFrame.new(self.shoulderR)
	local shoulderL = CFrame.new(self.shoulderL)
	local armRcf = shoulderR * CFrame.Angles(self.armR, 0, 0) * shoulderR:Inverse()
	local armLcf = shoulderL * CFrame.Angles(self.armL, 0, 0) * shoulderL:Inverse()
	local headPivot = CFrame.new(self.head - Vector3.new(0, 0.8, 0))
	local headCf = headPivot * CFrame.Angles(self.nod, 0, 0) * headPivot:Inverse()

	local parts, cframes = {}, {}
	local function add(part, cf)
		table.insert(parts, part)
		table.insert(cframes, cf)
	end
	for _, p in ipairs(self.groups.Body) do
		add(p, base * self.rel[p])
	end
	for _, p in ipairs(self.groups.Tail) do
		local rel = self.rel[p]
		local y = rel.Position.Y
		add(p, base * CFrame.new(math.sin(t * 3 + y * 1.4) * 0.18 * (1.2 - y * 0.3), 0, math.cos(t * 2.4 + y) * 0.1) * rel)
	end
	for _, p in ipairs(self.groups.Hood) do
		add(p, base * headCf * self.rel[p])
	end
	for _, p in ipairs(self.groups.Eye) do
		add(p, base * headCf * self.rel[p])
	end
	for _, p in ipairs(self.groups.ArmR) do
		add(p, base * armRcf * self.rel[p])
	end
	for _, p in ipairs(self.groups.Hammer) do
		add(p, base * armRcf * self.rel[p])
	end
	for _, p in ipairs(self.groups.ArmL) do
		add(p, base * armLcf * self.rel[p])
	end
	for i, p in ipairs(self.groups.Mote) do
		local rel = self.rel[p]
		local a = t * (0.35 + (i % 5) * 0.06) + i
		local orbit = CFrame.Angles(0, a * 0.25, 0)
		add(p, self.root * CFrame.new(0, math.sin(t * 1.7 + i) * 0.4, 0) * orbit * rel)
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)

	-- моргание и яркость глаз
	if now >= self.nextBlink then
		self.blinkUntil = now + 0.12
		self.nextBlink = now + 2.5 + math.random() * 3.5
	end
	local blink = now < self.blinkUntil
	for _, eye in ipairs(self.groups.Eye) do
		eye.Transparency = blink and 1 or 0
		local base3 = self.eyeColor[eye]
		if self.dim > 0 then
			eye.Color = base3:Lerp(Color3.fromRGB(60, 90, 110), self.dim)
		elseif self.talking then
			eye.Color = base3:Lerp(Color3.new(1, 1, 1), 0.5 + 0.5 * math.sin(t * 14))
		else
			eye.Color = base3
		end
	end
end

-- Удар молотом. onImpact вызывается в момент касания наковальни.
function EchoSmith:strike(onImpact)
	self:play({
		{ 0, self.armR, 0 },
		{ 0.22, -2.1, -0.3 }, -- замах вверх-назад
		{ 0.34, 0.55, 0.1, 0.08, event = "impact" }, -- удар вниз
		{ 0.5, 0.45, 0.1 },
		{ 0.8, 0, 0 },
	}, function(event)
		if event == "impact" and onImpact then
			onImpact()
		end
	end)
end

function EchoSmith:joy()
	self:play({
		{ 0, self.armR, self.armL, 0, 0 },
		{ 0.25, -2.6, -2.6, -0.1, 0 },
		{ 0.9, -2.5, -2.5, -0.1, math.pi * 2 },
		{ 1.3, -2.4, -2.6, 0, math.pi * 2 },
		{ 1.8, 0, 0, 0, math.pi * 2 },
	})
	task.delay(1.8, function()
		-- после полного оборота сбросить угол (визуально тот же)
		self.spin = 0
	end)
end

function EchoSmith:no()
	self.dim = 0.6
	self:play({
		{ 0, self.armR, self.armL, 0 },
		{ 0.15, 0.2, 0.2, 0.15 },
		{ 0.3, 0.2, 0.2, -0.15 },
		{ 0.45, 0.2, 0.2, 0.15 },
		{ 0.7, 0, 0, 0 },
	})
	task.delay(0.9, function()
		self.dim = 0
	end)
end

-- «Говорит»: кивает и бормочет, длительность по длине реплики.
function EchoSmith:talk(text: string)
	local length = utf8.len(text) or #text
	self.talking = true
	UiSound.play(length > 30 and "smith_voice_2" or "smith_voice_1", { pitch = 0.9 + math.random() * 0.2 })
	local token = (self.talkToken or 0) + 1
	self.talkToken = token
	task.delay(math.clamp(length * 0.03, 0.8, 2.6), function()
		if self.talkToken == token then
			self.talking = false
		end
	end)
end

function EchoSmith:destroy()
	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end
	-- вернуть детали на места
	if self.model.Parent then
		local parts, cframes = {}, {}
		for _, p in ipairs(self.parts) do
			table.insert(parts, p)
			table.insert(cframes, self.root * self.rel[p])
		end
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

return EchoSmith
