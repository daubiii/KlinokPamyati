--!nonstrict
-- AbilityFx345Kit (клиент)
-- Общие помощники эффектов оружия этажей 3–5 (AbilityFxHunt / AbilityFxForge / AbilityFxChronicle):
-- земля, звук, тряска, ленты-следы, летящие держатели с эмиттерами из шаблона-папки, эффекты «на враге»,
-- подсветка, кадровые риги. Шаблоны — ReplicatedStorage.FX (Shared/Fx/FxWeapons345 → FxBuilder345).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FloorGeo = require(Shared.Floor.FloorGeo)

local Bus = require(script.Parent.Parent.Lib.Bus)
local FxKit = require(script.Parent.Parent.Lib.FxKit)

local K = {}
K.FxKit = FxKit
K.V3 = Vector3.new
local V3 = Vector3.new

local SHAKE_RANGE = 40
K.FEET = 3

-- ===== Общее =====

function K.modelPart(model)
	if typeof(model) ~= "Instance" or not model.Parent then
		return nil
	end
	return model:FindFirstChild("Root")
		or (model:IsA("Model") and model.PrimaryPart)
		or model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChildWhichIsA("BasePart", true)
end

-- Точка над врагом: верх детали-корня + lift.
function K.above(model, lift: number?)
	local part = K.modelPart(model)
	if not part then
		return nil
	end
	local height = part.Size.Y * 0.5
	if model:IsA("Model") then
		local ok, _, size = pcall(model.GetBoundingBox, model)
		if ok and size then
			height = math.max(height, size.Y * 0.5)
		end
	end
	return part.Position + V3(0, height + (lift or 0), 0), part
end

function K.casterRoot(caster)
	local character = typeof(caster) == "Instance" and caster:IsA("Player") and caster.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

function K.isLocal(caster)
	return caster == Players.LocalPlayer
end

function K.groundY(position: Vector3): number
	local ok, y = pcall(FloorGeo.groundAt, position.X, position.Z, position.Y + 1.5)
	if ok and type(y) == "number" and math.abs(y - position.Y) < 4 then
		return y
	end
	return position.Y
end

function K.ground(position: Vector3, lift: number?): Vector3
	return V3(position.X, K.groundY(position) + (lift or 0.15), position.Z)
end

function K.sound(name: string, position: Vector3?)
	Bus.emit("sfx", { name = name, position = position })
end

function K.shake(position: Vector3?, amount: number, time: number)
	local camera = Workspace.CurrentCamera
	if camera and (not position or (camera.CFrame.Position - position).Magnitude <= SHAKE_RANGE) then
		Bus.emit("shake", { amount = amount, time = time })
	end
end

function K.fov(caster, amount: number, time: number)
	if K.isLocal(caster) then
		Bus.emit("fov", { amount = amount, time = time })
	end
end

function K.flat(direction: Vector3?): Vector3
	if typeof(direction) ~= "Vector3" then
		return V3(0, 0, -1)
	end
	local flat = V3(direction.X, 0, direction.Z)
	return flat.Magnitude > 0.01 and flat.Unit or V3(0, 0, -1)
end

function K.facing(position: Vector3, direction: Vector3, yaw: number?): CFrame
	local base = CFrame.lookAt(position, position + K.flat(direction))
	if yaw then
		base = base * CFrame.Angles(0, math.rad(yaw), 0)
	end
	return base
end

function K.color(hex: string): Color3
	return Color3.fromHex(hex)
end

function K.tween(item: Instance, time: number, props, style, direction)
	local tween = TweenService:Create(item, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

-- Кадровый риг: fn(t, dt) каждые RenderStepped, пока не вернёт false или не выйдет время.
function K.loop(duration: number?, fn)
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - started
		local ok, keep = pcall(fn, t, dt)
		if not ok then
			warn("[AbilityFx345] " .. tostring(keep))
		end
		if not ok or keep == false or (duration and t >= duration) then
			connection:Disconnect()
		end
	end)
	return connection
end

-- ===== Ленты =====

-- Лента-след из Trail-шаблона: positionAt(t 0..1) → два края.
function K.ribbon(path: string, color: Color3?, width: number, duration: number, positionAt)
	local holder = FxKit.holder()
	local a0 = Instance.new("Attachment")
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Parent = holder
	local ribbon = FxKit.clone(path)
	if not ribbon or not ribbon:IsA("Trail") then
		holder:Destroy()
		return
	end
	if color then
		ribbon.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	end
	ribbon.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, width),
		NumberSequenceKeypoint.new(0.35, width * 0.78),
		NumberSequenceKeypoint.new(1, 0),
	})
	a0.WorldPosition, a1.WorldPosition = positionAt(0)
	ribbon.Attachment0 = a0
	ribbon.Attachment1 = a1
	ribbon.Parent = holder
	ribbon.Enabled = true
	K.loop(duration + 0.05, function(t)
		if not holder.Parent then
			return false
		end
		local k = math.clamp(t / duration, 0, 1)
		a0.WorldPosition, a1.WorldPosition = positionAt(k)
		if k >= 1 then
			ribbon.Enabled = false
			return false
		end
		return true
	end)
	Debris:AddItem(holder, duration + ribbon.Lifetime + 0.2)
end

-- Дуга удара вокруг origin: sweep градусов (знак — направление), радиусы inner..outer, высота height.
function K.arc(origin: Vector3, direction: Vector3, path: string, color: Color3?, duration: number, sweep: number, inner: number, outer: number, height: number, tilt: number?)
	local forward = K.flat(direction)
	K.ribbon(path, color, 1.3, duration, function(t)
		local angle = math.rad((t - 0.5) * sweep)
		local rotated = CFrame.fromAxisAngle(V3(0, 1, 0), angle):VectorToWorldSpace(forward)
		local y = height + (t - 0.5) * (tilt or 0) + math.sin(t * math.pi) * 0.3
		return origin + rotated * inner + V3(0, y, 0), origin + rotated * outer + V3(0, y + 0.1, 0)
	end)
end

-- ===== Летящий держатель =====

-- Держатель с содержимым шаблона-папки (эмиттеры, свет) и его Trail (ширина — атрибут Width).
-- Возвращает { part, point, handle, move(cframe), stop(fade?) }.
function K.flyer(path: string, cframe: CFrame, opts)
	opts = opts or {}
	local holder = FxKit.holder(cframe)
	local point = Instance.new("Attachment")
	point.Name = "Core"
	point.Parent = holder
	local handle = FxKit.attach(path, point, { life = opts.life })
	local template = FxKit.template(path)
	local trail = template and template:FindFirstChildWhichIsA("Trail")
	local a0, a1
	if trail and opts.trail ~= false then
		local width = (trail:GetAttribute("Width") or 1) * (opts.trailScale or 1)
		a0 = Instance.new("Attachment")
		a0.Position = V3(0, width / 2, 0)
		a0.Parent = holder
		a1 = Instance.new("Attachment")
		a1.Position = V3(0, -width / 2, 0)
		a1.Parent = holder
		local clone = trail:Clone()
		clone.Attachment0 = a0
		clone.Attachment1 = a1
		clone.Enabled = true
		clone.Parent = holder
		trail = clone
	else
		trail = nil
	end
	local fly = { part = holder, point = point, handle = handle, trail = trail, stopped = false }
	function fly.move(cf: CFrame)
		if holder.Parent then
			holder.CFrame = cf
		end
	end
	function fly.stop(linger: number?)
		if fly.stopped then
			return
		end
		fly.stopped = true
		if handle then
			handle.stop()
		end
		if trail then
			trail.Enabled = false
		end
		Debris:AddItem(holder, linger or 1.2)
	end
	if opts.life then
		task.delay(opts.life, fly.stop)
	end
	Debris:AddItem(holder, (opts.life or 12) + 2)
	return fly
end

-- ===== Эффект «на враге» (одна копия на модель и ключ) =====

local attached = {} -- [key][model] = { attachment, handle, token }

-- Эмиттеры шаблона-папки на Attachment над/в корне модели на life секунд (повтор продлевает).
function K.onModel(key: string, model, path: string, life: number, lift: number?)
	local part = K.modelPart(model)
	if not part then
		return nil
	end
	attached[key] = attached[key] or {}
	local set = attached[key]
	local old = set[model]
	if old and old.attachment.Parent then
		old.token += 1
		local token = old.token
		task.delay(life, function()
			if set[model] == old and old.token == token then
				K.offModel(key, model)
			end
		end)
		return old
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "Fx_" .. key
	attachment.Parent = part
	if lift then
		local top = K.above(model, lift)
		if top then
			attachment.WorldPosition = top
		end
	end
	local handle = FxKit.attach(path, attachment, {})
	local state = { attachment = attachment, handle = handle, token = 1 }
	set[model] = state
	task.delay(life, function()
		if set[model] == state and state.token == 1 then
			K.offModel(key, model)
		end
	end)
	return state
end

function K.offModel(key: string, model)
	local set = attached[key]
	local state = set and set[model]
	if not state then
		return
	end
	set[model] = nil
	if state.handle then
		state.handle.stop()
	end
	if state.highlight then
		K.tween(state.highlight, 0.25, { FillTransparency = 1, OutlineTransparency = 1 })
		Debris:AddItem(state.highlight, 0.3)
	end
	Debris:AddItem(state.attachment, 1.5)
end

function K.hasModel(key: string, model)
	return attached[key] ~= nil and attached[key][model] ~= nil
end

-- Подсветка модели (Highlight) на state из onModel — гаснет вместе с ним.
function K.highlight(state, model, fill: Color3, outline: Color3, fillTransparency: number)
	if not state or state.highlight or typeof(model) ~= "Instance" then
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "Fx345Highlight"
	h.FillColor = fill
	h.OutlineColor = outline
	h.FillTransparency = 1
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = model
	state.highlight = h
	K.tween(h, 0.15, { FillTransparency = fillTransparency, OutlineTransparency = 0.1 })
end

-- ===== Оружие и персонаж =====

function K.weapon(caster)
	local character = typeof(caster) == "Instance" and caster:IsA("Player") and caster.Character
	return character and character:FindFirstChild("EquippedWeapon", true)
end

-- Мировая точка у острия оружия (или перед героем).
function K.weaponTip(caster)
	local weapon = K.weapon(caster)
	if weapon then
		local tip = weapon:FindFirstChild("BladeTip", true) or weapon:FindFirstChild("BladeMid", true)
		if tip and tip:IsA("Attachment") then
			return tip.WorldPosition
		end
		local part = weapon:IsA("BasePart") and weapon or weapon:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position
		end
	end
	local root = K.casterRoot(caster)
	return root and (root.Position + root.CFrame.LookVector * 1.5) or nil
end

-- Призрачная копия персонажа: без скриптов и гуманоида, ForceField-материал, закреплена.
function K.ghost(caster, color: Color3)
	local character = typeof(caster) == "Instance" and caster:IsA("Player") and caster.Character
	if not character then
		return nil
	end
	local archivable = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(character.Clone, character)
	character.Archivable = archivable
	if not ok or not copy then
		return nil
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Sound")
			or d:IsA("Humanoid") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Trail")
			or d:IsA("Beam") or d:IsA("BillboardGui") or d:IsA("Highlight") or d:IsA("ForceField") then
			d:Destroy()
		end
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Massless = true
			d.Material = Enum.Material.ForceField
			d.Color = color
			d.LocalTransparencyModifier = 0
			if d.Name == "HumanoidRootPart" then
				d.Transparency = 1
			else
				d.Transparency = 0
			end
			if d:IsA("MeshPart") then
				pcall(function()
					d.TextureID = ""
				end)
			end
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = 1
		elseif d:IsA("SurfaceAppearance") then
			d:Destroy()
		end
	end
	copy.Name = "Fx345Ghost"
	local root = copy:FindFirstChild("HumanoidRootPart")
	if root then
		copy.PrimaryPart = root
	end
	copy.Parent = FxKit.folder()
	return copy
end

-- Плавно растворить модель/деталь и удалить.
function K.dissolve(item: Instance, time: number)
	local list = item:IsA("BasePart") and { item } or item:GetDescendants()
	for _, d in ipairs(list) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			K.tween(d, time, { Transparency = 1 })
		end
	end
	Debris:AddItem(item, time + 0.1)
end

-- Деталь-«вещь» эффекта (наковальня, зубья, печать).
function K.solid(size: Vector3, cframe: CFrame, color: Color3, material, parent)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or FxKit.folder()
	return p
end

return K
