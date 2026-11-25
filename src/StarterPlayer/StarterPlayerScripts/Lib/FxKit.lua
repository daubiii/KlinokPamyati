--!nonstrict
-- FxKit (клиент)
-- Запуск эффектов из шаблонов ReplicatedStorage.FX (собирает tools/fx/BuildFx.lua).
-- Внешний вид — цвет, текстуры, размеры, скорость, время жизни — живёт в
-- шаблонах и правится в Studio; код только ставит эффект на место.
--
-- Соглашения шаблонов (атрибуты):
--   деталь:         BaseRadius — радиус, под который нарисован эффект;
--                   ScalePart — растянуть деталь по радиусу (форма выброса).
--   ParticleEmitter: Emit (вспышка N частиц), EmitDelay, Pattern ("ring" |
--                   "inward"), ScaleSize, ScaleSpeed, MatchLife.
--                   Без Emit — непрерывный, пока эффект жив.
--   PointLight:     Fade — погаснуть за N секунд.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FxKit = {}

local RING_STEPS = 12
local warned = {}

local holderFolder
local function folder()
	if holderFolder and holderFolder.Parent then
		return holderFolder
	end
	holderFolder = Workspace:FindFirstChild("KlinokAbilityFx")
	if not holderFolder then
		holderFolder = Instance.new("Folder")
		holderFolder.Name = "KlinokAbilityFx"
		holderFolder.Parent = Workspace
	end
	return holderFolder
end
FxKit.folder = folder

-- Шаблон по пути "Vortex/Funnel". Нет шаблона — одно предупреждение и nil.
function FxKit.template(path: string)
	local node = ReplicatedStorage:FindFirstChild("FX")
	for name in string.gmatch(path, "[^/]+") do
		node = node and node:FindFirstChild(name)
	end
	if not node and not warned[path] then
		warned[path] = true
		local hasFx = ReplicatedStorage:FindFirstChild("FX") ~= nil
		local head = string.match(path, "^([^/]+)/") or ""
		local builder = hasFx and head == "Garden" and "tools/fx/BuildFxGarden.lua"
			or (hasFx and (head == "Hunt" or head == "Forge" or head == "Chron" or head == "Weapon"))
				and "tools/fx/BuildFxWeapons345.lua (или перезапустите сервер)"
			or "tools/fx/BuildFx.lua"
		warn("[FxKit] нет шаблона FX/" .. path .. " — запустите " .. builder)
	end
	return node
end

local function scaleSequence(sequence: NumberSequence, k: number): NumberSequence
	local points = {}
	for _, p in ipairs(sequence.Keypoints) do
		table.insert(points, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
	end
	return NumberSequence.new(points)
end

-- ===== Выброс по рисунку =====

-- Движок берёт направление выброса в момент отрисовки, а не в момент Emit,
-- поэтому «кольцо» и «внутрь» — веер копий эмиттера на своих Attachment:
-- каждая смотрит в своё направление (EmissionDirection = Front).
local function fan(emitter: ParticleEmitter)
	local part = emitter.Parent
	if not part or not part:IsA("BasePart") then
		return { emitter }
	end
	local inward = emitter:GetAttribute("Pattern") == "inward"
	local radius = part.Size.X / 2
	local offset = math.random() * math.pi * 2
	local copies = {}
	for i = 1, RING_STEPS do
		local a = offset + (i / RING_STEPS) * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local point = Instance.new("Attachment")
		point.Name = emitter.Name .. i
		if inward then
			point.CFrame = CFrame.lookAt(dir * radius, Vector3.zero)
		else
			point.CFrame = CFrame.lookAt(Vector3.zero, dir)
		end
		point.Parent = part
		local copy = emitter:Clone()
		copy.Rate = emitter.Rate / RING_STEPS
		copy.Parent = point
		table.insert(copies, copy)
	end
	emitter:Destroy()
	return copies
end

-- N частиц поровну на копии веера. Новый эмиттер не выпускает частицы в
-- кадре, когда его создали, поэтому выброс — со следующего кадра.
local function emitSoon(copies, count: number, delay: number?)
	task.spawn(function()
		RunService.Heartbeat:Wait()
		if delay and delay > 0 then
			task.wait(delay)
		end
		local per = math.floor(count / #copies)
		local extra = count - per * #copies
		for i, e in ipairs(copies) do
			local n = per + ((i <= extra) and 1 or 0)
			if n > 0 and e.Parent then
				e:Emit(n)
			end
		end
	end)
end

-- ===== Подготовка клона =====

-- Настроить эмиттеры и свет внутри root. Возвращает непрерывные эмиттеры
-- и самое долгое время жизни вспышек.
local function prepare(root: Instance, scale: number, life: number?)
	local continuous = {}
	local longest = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			if d:GetAttribute("ScaleSize") and scale ~= 1 then
				d.Size = scaleSequence(d.Size, scale)
			end
			if d:GetAttribute("ScaleSpeed") and scale ~= 1 then
				d.Speed = NumberRange.new(d.Speed.Min * scale, d.Speed.Max * scale)
			end
			if d:GetAttribute("MatchLife") and life then
				d.Lifetime = NumberRange.new(life)
			end
			local burst = d:GetAttribute("Emit")
			local delay = d:GetAttribute("EmitDelay") or 0
			local lifetime = d.Lifetime.Max
			local rate = d.Rate
			d.Enabled = false
			local copies = d:GetAttribute("Pattern") and fan(d) or { d }
			if burst then
				longest = math.max(longest, delay + lifetime + 0.05)
				emitSoon(copies, burst, delay)
			elseif rate > 0 then
				for _, c in ipairs(copies) do
					table.insert(continuous, c)
				end
				longest = math.max(longest, lifetime)
			end
		elseif d:IsA("Light") then
			local fade = d:GetAttribute("Fade")
			if fade then
				TweenService:Create(d, TweenInfo.new(fade, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
				longest = math.max(longest, fade)
			end
		end
	end
	return continuous, longest
end

local function setContinuous(list, on: boolean)
	for _, e in ipairs(list) do
		if e.Parent then
			e.Enabled = on
		end
	end
end

local function makeHandle(root: Instance, continuous, longest: number, life: number?)
	local handle = { root = root, stopped = false }
	function handle.stop()
		if handle.stopped then
			return
		end
		handle.stopped = true
		setContinuous(continuous, false)
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Light") and not d:GetAttribute("Fade") then
				TweenService:Create(d, TweenInfo.new(0.25), { Brightness = 0 }):Play()
			end
		end
		Debris:AddItem(root, longest + 0.1)
	end
	function handle.destroy()
		handle.stopped = true
		setContinuous(continuous, false)
		if root.Parent then
			root:Destroy()
		end
	end
	setContinuous(continuous, true)
	if life then
		task.delay(life, handle.stop)
	elseif #continuous == 0 then
		Debris:AddItem(root, longest + 0.1)
		handle.stopped = true
	end
	return handle
end

-- ===== Публичные функции =====

-- Эффект-деталь в точке. opts: radius (масштаб от BaseRadius), scale,
-- life (сколько живут непрерывные эмиттеры; без life — до handle.stop()).
function FxKit.spawn(path: string, cframe: CFrame, opts)
	opts = opts or {}
	local template = FxKit.template(path)
	if not template or not template:IsA("BasePart") then
		return nil
	end
	local root = template:Clone()
	local base = template:GetAttribute("BaseRadius")
	local scale = opts.scale or ((opts.radius and base) and opts.radius / base) or 1
	if template:GetAttribute("ScalePart") then
		root.Size = Vector3.new(root.Size.X * scale, root.Size.Y, root.Size.Z * scale)
	end
	if opts.size then
		root.Size = opts.size
	end
	root.Locked = false
	root.CFrame = cframe
	root.Parent = opts.parent or folder()
	local continuous, longest = prepare(root, scale, opts.life)
	return makeHandle(root, continuous, longest, opts.life)
end

-- Содержимое шаблона-папки (эмиттеры, свет, след) — в готовый Attachment.
-- Trail из шаблона получает Attachment0 = attachment, Attachment1 = opts.other.
function FxKit.attach(path: string, attachment: Attachment, opts)
	opts = opts or {}
	local template = FxKit.template(path)
	if not template then
		return nil
	end
	local items = {}
	for _, child in ipairs(template:GetChildren()) do
		local clone = child:Clone()
		if clone:IsA("Trail") or clone:IsA("Beam") then
			if opts.other then
				clone.Attachment0 = attachment
				clone.Attachment1 = opts.other
				clone.Parent = attachment
				table.insert(items, clone)
			else
				clone:Destroy()
			end
		else
			clone.Parent = attachment
			table.insert(items, clone)
		end
	end
	local continuous, longest = {}, 0.3
	for _, item in ipairs(items) do
		if item:IsA("ParticleEmitter") then
			local burst = item:GetAttribute("Emit")
			item.Enabled = false
			if burst then
				emitSoon({ item }, burst, item:GetAttribute("EmitDelay"))
			elseif item.Rate > 0 then
				table.insert(continuous, item)
			end
			longest = math.max(longest, item.Lifetime.Max)
		elseif item:IsA("Trail") then
			longest = math.max(longest, item.Lifetime)
		end
	end
	local handle = { items = items, stopped = false }
	setContinuous(continuous, true)
	function handle.stop()
		if handle.stopped then
			return
		end
		handle.stopped = true
		setContinuous(continuous, false)
		for _, item in ipairs(items) do
			if item:IsA("Trail") then
				item.Enabled = false
			elseif item:IsA("Light") then
				TweenService:Create(item, TweenInfo.new(0.2), { Brightness = 0 }):Play()
			end
			Debris:AddItem(item, longest + 0.1)
		end
	end
	function handle.destroy()
		handle.stopped = true
		setContinuous(continuous, false)
		for _, item in ipairs(items) do
			if item.Parent then
				item:Destroy()
			end
		end
	end
	if opts.life then
		task.delay(opts.life, handle.stop)
	end
	return handle
end

-- Клон Beam/Trail/модели из шаблона (без запуска).
function FxKit.clone(path: string)
	local template = FxKit.template(path)
	return template and template:Clone() or nil
end

-- Невидимая деталь-держатель для своих Attachment (лучи, серпы, цепи).
function FxKit.holder(cframe: CFrame?)
	local p = Instance.new("Part")
	p.Name = "FxHolder"
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = cframe or CFrame.new()
	p.Parent = folder()
	return p
end

-- Плоская ориентация на земле для Attachment луча: ось X — вдоль луча,
-- ось Y (ширина луча) — поперёк по горизонтали, значит лента лежит плашмя.
function FxKit.flatFrame(position: Vector3, along: Vector3): CFrame
	local dir = Vector3.new(along.X, 0, along.Z)
	if dir.Magnitude < 1e-3 then
		dir = Vector3.new(1, 0, 0)
	end
	dir = dir.Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	return CFrame.fromMatrix(position, dir, side)
end

-- Прозрачность Beam/Trail плавно к 1 за time.
function FxKit.fade(item: Instance, time: number, destroy: boolean?)
	local start = item.Transparency
	local began = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not item.Parent then
			connection:Disconnect()
			return
		end
		local k = math.clamp((os.clock() - began) / time, 0, 1)
		local points = {}
		for _, p in ipairs(start.Keypoints) do
			table.insert(points, NumberSequenceKeypoint.new(p.Time, p.Value + (1 - p.Value) * k))
		end
		item.Transparency = NumberSequence.new(points)
		if k >= 1 then
			connection:Disconnect()
			if destroy then
				item:Destroy()
			end
		end
	end)
end

-- Расширяющаяся сфера (Common/Shockwave): от 1 до radius за Time шаблона.
function FxKit.shockwave(position: Vector3, radius: number)
	local template = FxKit.template("Common/Shockwave")
	if not template then
		return
	end
	local ball = template:Clone()
	local time = template:GetAttribute("Time") or 0.45
	ball.Size = Vector3.new(1, 1, 1)
	ball.CFrame = CFrame.new(position)
	ball.Parent = folder()
	local d = radius * 2
	TweenService:Create(ball, TweenInfo.new(time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(d, d, d),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ball, time + 0.05)
end

return FxKit
