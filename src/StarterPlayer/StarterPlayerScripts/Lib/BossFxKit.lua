--!nonstrict
-- BossFxKit (клиент)
-- Процедурные детали для эффектов фирменных атак (Controllers/BossMovesFx) и
-- сцен появления боссов (Controllers/BossIntroScenes): детали, частицы,
-- осколки, кольца, твины. Всё временное живёт в Workspace.BossFx и само
-- убирается; дальние эффекты (FAR) не рисуются.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Bus = require(script.Parent.Bus)
local TEX = require(script.Parent.FxTex)

local Kit = {}

local V3 = Vector3.new
Kit.V3 = V3
Kit.rgb = Color3.fromRGB
Kit.hex = Color3.fromHex
Kit.TEX = TEX
Kit.TAU = math.pi * 2
Kit.FAR = 140
Kit.random = Random.new()

local random = Kit.random
local DEBRIS_MAX = 320

function Kit.serverNow(): number
	return Workspace:GetServerTimeNow()
end

function Kit.sfx(name: string, position: Vector3?)
	Bus.emit("sfx", { name = name, position = position })
end

function Kit.shake(amount: number, time: number)
	Bus.emit("shake", { amount = amount, time = time })
end

function Kit.notify(text: string, kind: string?)
	Bus.emit("notify", { kind = kind or "warn", text = text })
end

function Kit.localRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- Тряска, ослабевающая с расстоянием до своего героя.
function Kit.shakeAt(position: Vector3, amount: number, time: number, range: number?)
	local root = Kit.localRoot()
	if not root then
		return
	end
	local d = (root.Position - position).Magnitude
	local r = range or 50
	if d < r then
		Kit.shake(amount * (1 - d / r * 0.7), time)
	end
end

function Kit.near(position: Vector3, range: number?): boolean
	local camera = Workspace.CurrentCamera
	if not camera then
		return true
	end
	return (camera.CFrame.Position - position).Magnitude < (range or Kit.FAR)
end

local folderRef
function Kit.folder()
	if folderRef and folderRef.Parent then
		return folderRef
	end
	folderRef = Workspace:FindFirstChild("BossFx")
	if not folderRef then
		folderRef = Instance.new("Folder")
		folderRef.Name = "BossFx"
		folderRef.Parent = Workspace
	end
	return folderRef
end

function Kit.part(props, class: string?)
	local p = Instance.new(class or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	local parent = props.Parent
	props.Parent = nil
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = parent or Kit.folder()
	return p
end

local DISC_TURN = CFrame.Angles(0, 0, math.rad(90))
function Kit.discCFrame(center: Vector3, lift: number): CFrame
	return CFrame.new(center + V3(0, lift, 0)) * DISC_TURN
end

-- Плоский диск на полу (цилиндр лёжа).
function Kit.disc(center: Vector3, radius: number, color: Color3, transparency: number, lift: number?, neon: boolean?)
	return Kit.part({
		Name = "Disc", Shape = Enum.PartType.Cylinder, Size = V3(0.06, radius * 2, radius * 2),
		CFrame = Kit.discCFrame(center, lift or 0.08), Color = color, Transparency = transparency,
		Material = neon == false and Enum.Material.SmoothPlastic or Enum.Material.Neon,
	})
end

function Kit.tween(instance: Instance, time: number, props, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local tween = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

-- Растаять и исчезнуть.
function Kit.fade(instance: Instance, time: number, extra)
	if not instance or not instance.Parent then
		return
	end
	local list = { instance }
	for _, d in ipairs(instance:GetDescendants()) do
		table.insert(list, d)
	end
	for _, item in ipairs(list) do
		if item:IsA("BasePart") then
			local props = { Transparency = 1 }
			if extra and item == instance then
				for k, v in pairs(extra) do
					props[k] = v
				end
			end
			Kit.tween(item, time, props)
		elseif item:IsA("Decal") or item:IsA("Texture") then
			Kit.tween(item, time, { Transparency = 1 })
		elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") then
			item.Enabled = false
		elseif item:IsA("PointLight") or item:IsA("SpotLight") then
			Kit.tween(item, time, { Brightness = 0 })
		end
	end
	Debris:AddItem(instance, time + 0.1)
end

-- ===== Частицы =====

function Kit.nseq(points)
	local keys = {}
	for _, pt in ipairs(points) do
		table.insert(keys, NumberSequenceKeypoint.new(pt[1], pt[2]))
	end
	return NumberSequence.new(keys)
end

function Kit.cseq(a: Color3, b: Color3?)
	return b and ColorSequence.new(a, b) or ColorSequence.new(a)
end

-- Эмиттер на невидимой опоре. o: tex, color, size, transp, life, speed,
-- spread, accel, drag, light, dir, rot, rate, emit, box, cframe, parent.
function Kit.emitter(position: Vector3, o, duration: number?)
	local anchor = o.parent or Kit.part({ Name = "Fx", Size = o.box or V3(0.2, 0.2, 0.2), Transparency = 1, CFrame = o.cframe or CFrame.new(position) })
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.tex or TEX.glow
	e.Color = typeof(o.color) == "ColorSequence" and o.color or Kit.cseq(o.color or Color3.new(1, 1, 1))
	e.Size = o.size or NumberSequence.new(0.5)
	e.Transparency = o.transp or Kit.nseq({ { 0, 0.2 }, { 1, 1 } })
	e.Lifetime = NumberRange.new(o.life and o.life[1] or 0.6, o.life and o.life[2] or 1.2)
	e.Speed = NumberRange.new(o.speed and o.speed[1] or 2, o.speed and o.speed[2] or 6)
	e.SpreadAngle = Vector2.new(o.spread or 30, o.spread or 30)
	e.Acceleration = o.accel or V3(0, 0, 0)
	e.Drag = o.drag or 0
	e.LightEmission = o.light or 0.5
	e.LightInfluence = o.light and o.light >= 1 and 0 or 0.6
	e.EmissionDirection = o.dir or Enum.NormalId.Top
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-(o.rot or 40), o.rot or 40)
	e.Shape = o.box and Enum.ParticleEmitterShape.Box or Enum.ParticleEmitterShape.Sphere
	e.LockedToPart = o.locked or false
	e.Rate = o.rate or 0
	e.Enabled = (o.rate or 0) > 0
	e.Parent = anchor
	if o.emit then
		e:Emit(o.emit)
	end
	if duration and duration > 0 and e.Enabled then
		task.delay(duration, function()
			if e.Parent then
				e.Enabled = false
			end
		end)
	end
	if not o.parent then
		Debris:AddItem(anchor, (duration or 0) + (o.life and o.life[2] or 1.2) + 0.2)
	end
	return anchor, e
end

function Kit.smoke(position: Vector3, color: Color3, count: number, size: number, rise: number?)
	if not Kit.near(position) then
		return
	end
	Kit.emitter(position, {
		tex = TEX.smoke, color = color, emit = count, life = { 0.8, 1.6 }, speed = { 1.5, 5 }, spread = 180,
		size = Kit.nseq({ { 0, size * 0.5 }, { 1, size * 1.7 } }), transp = Kit.nseq({ { 0, 0.35 }, { 1, 1 } }), light = 0.05, drag = 2.5,
		accel = V3(0, rise or 1.5, 0),
	})
end

function Kit.sparks(position: Vector3, color: Color3, count: number, speed: number?)
	if not Kit.near(position) then
		return
	end
	Kit.emitter(position, {
		tex = TEX.spark, color = color, emit = count, life = { 0.25, 0.6 }, speed = { (speed or 14) * 0.5, speed or 14 }, spread = 180,
		size = Kit.nseq({ { 0, 0.35 }, { 1, 0 } }), transp = Kit.nseq({ { 0, 0 }, { 1, 0.6 } }), light = 1, accel = V3(0, -30, 0),
	})
end

function Kit.flash(position: Vector3, color: Color3, size: number, life: number?)
	if not Kit.near(position) then
		return
	end
	Kit.emitter(position, {
		tex = TEX.glow, color = color, emit = 1, life = { life or 0.25, life or 0.25 }, speed = { 0, 0 },
		size = Kit.nseq({ { 0, size * 0.4 }, { 0.3, size }, { 1, size * 1.2 } }), transp = Kit.nseq({ { 0, 0 }, { 1, 1 } }), light = 1,
	})
end

-- ===== Осколки =====

local debris = {}

function Kit.bit(position: Vector3, velocity: Vector3, color: Color3, size: number, life: number, neon: boolean?, floorY: number?, gravity: number?, material: Enum.Material?)
	if #debris >= DEBRIS_MAX then
		local oldest = table.remove(debris, 1)
		oldest.part:Destroy()
	end
	local p = Kit.part({
		Name = "Bit", Size = V3(size, size, size), CFrame = CFrame.new(position), Color = color,
		Material = material or (neon and Enum.Material.Neon or Enum.Material.SmoothPlastic),
	})
	table.insert(debris, {
		part = p,
		velocity = velocity,
		spin = V3(random:NextNumber(-8, 8), random:NextNumber(-8, 8), random:NextNumber(-8, 8)),
		life = life,
		age = 0,
		floor = floorY or (position.Y - 6),
		size = size,
		gravity = gravity or 50,
	})
	return p
end

function Kit.burst(position: Vector3, count: number, colors, size: number, speed: number, up: number?, floorY: number?, neon: boolean?, material: Enum.Material?)
	if not Kit.near(position) then
		return
	end
	for _ = 1, count do
		local color = colors[random:NextInteger(1, #colors)]
		local s = size * random:NextNumber(0.6, 1.3)
		local v = V3(random:NextNumber(-1, 1) * speed * 0.5, random:NextNumber(0.3, 1) * speed * (up or 1), random:NextNumber(-1, 1) * speed * 0.5)
		Kit.bit(position + V3(random:NextNumber(-0.3, 0.3), random:NextNumber(0, 0.3), random:NextNumber(-0.3, 0.3)), v, color, s, random:NextNumber(0.5, 1.1), neon, floorY, nil, material)
	end
end

local function stepDebris(dt: number)
	for index = #debris, 1, -1 do
		local d = debris[index]
		d.age += dt
		d.velocity += V3(0, -d.gravity * dt, 0)
		local pos = d.part.Position + d.velocity * dt
		if pos.Y < d.floor then
			pos = V3(pos.X, d.floor, pos.Z)
			d.velocity = V3(d.velocity.X * 0.4, -d.velocity.Y * 0.2, d.velocity.Z * 0.4)
			d.spin *= 0.5
		end
		local k = d.age / d.life
		if k >= 1 or not d.part.Parent then
			d.part:Destroy()
			table.remove(debris, index)
		else
			d.part.CFrame = CFrame.new(pos) * CFrame.Angles(d.spin.X * d.age, d.spin.Y * d.age, d.spin.Z * d.age)
			if k > 0.6 then
				local s = d.size * (1 - (k - 0.6) / 0.4)
				d.part.Size = V3(s, s, s)
			end
		end
	end
end

-- ===== Кольца =====

-- Кольцо-предупреждение: обод и заливка, наливающаяся к сроку.
function Kit.warnRing(position: Vector3, radius: number, color: Color3, duration: number)
	if not Kit.near(position) or duration <= 0 then
		return
	end
	local d = radius * 2
	local rim = Kit.part({ Name = "WarnRing", Shape = Enum.PartType.Cylinder, Size = V3(0.06, d, d), CFrame = Kit.discCFrame(position, 0.08), Color = color, Material = Enum.Material.Neon, Transparency = 0.75 })
	local fill = Kit.part({ Name = "WarnFill", Shape = Enum.PartType.Cylinder, Size = V3(0.07, 0.2, 0.2), CFrame = Kit.discCFrame(position, 0.1), Color = color, Material = Enum.Material.Neon, Transparency = 0.55 })
	Kit.tween(fill, duration, { Size = V3(0.07, d * 0.96, d * 0.96), Transparency = 0.35 }, Enum.EasingStyle.Linear)
	Debris:AddItem(rim, duration + 0.05)
	Debris:AddItem(fill, duration + 0.05)
	return rim, fill
end

-- Расходящаяся волна.
function Kit.shockRing(position: Vector3, radius: number, color: Color3, time: number, lift: number?)
	if not Kit.near(position) then
		return
	end
	local ring = Kit.part({ Name = "Wave", Shape = Enum.PartType.Cylinder, Size = V3(0.08, 1, 1), CFrame = Kit.discCFrame(position, lift or 0.12), Color = color, Material = Enum.Material.Neon, Transparency = 0.3 })
	Kit.tween(ring, time, { Size = V3(0.08, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(ring, time + 0.05)
end

-- Брусок между двумя точками.
function Kit.beamPart(a: Vector3, b: Vector3, width: number, height: number, color: Color3, neon: boolean?, transparency: number?)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	return Kit.part({
		Name = "Strip", Size = V3(width, height, math.max(length, 0.05)), CFrame = CFrame.lookAt(mid, b + V3(0, 1e-4, 0)),
		Color = color, Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic, Transparency = transparency or 0,
	})
end

function Kit.placeBeam(p: BasePart, a: Vector3, b: Vector3)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	p.Size = V3(p.Size.X, p.Size.Y, math.max(length, 0.05))
	p.CFrame = CFrame.lookAt(mid, b + V3(0, 1e-4, 0))
end

-- Высота пола под точкой (луч вниз мимо персонажей и эффектов).
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
function Kit.groundY(position: Vector3, fallback: number?): number
	local ignore = { Kit.folder() }
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local visuals = Workspace:FindFirstChild("EnemyVisuals")
	if visuals then
		table.insert(ignore, visuals)
	end
	rayParams.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(position + V3(0, 6, 0), V3(0, -40, 0), rayParams)
	return hit and hit.Position.Y or (fallback or position.Y)
end

local started = false
function Kit.start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(stepDebris)
end

return Kit
