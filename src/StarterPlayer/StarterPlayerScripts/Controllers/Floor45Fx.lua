--!nonstrict
-- Floor45Fx (клиент)
-- Эффекты этажей 4 «Литейные» и 5 «Зал хроник». Логики нет — только картинка
-- и звук по атрибутам моделей и событиям Floor45Service (EnemyEvent, kind f45*)
-- и Floor4World / Floor5World (FloorEvent, kind f4* / f5*).
--
--   лужи        расплав (корка, жар, искры), чернила (вязкий блеск), стирание
--               (белёсая пустота страницы)
--   телеграфы   конус выдоха жара и ковша (F45Cone), нити Переплётчика
--               (F45Lines), луч строки Хрониста (F45Beam)
--   удары       выдох / разлив по конусу, нити, луч, бросок шлака и чернил,
--               чтение вслух, броня спереди, отбитый печатью удар
--   печати      лучи «маг → печать» (F45WardAt) и «печать → Хронист»
--               (ObjectValue F45WardTarget), щит Хрониста (F5SealsUp)
--   клапаны     пар у открытого автомата (F45VentUntil), одноразовые
--               анимации (Vent, Hop) по oneShots из EnemyVisuals45
--   ожог        угли на горящих игроках (BurnUntil), своему — тёплый оттенок
--   карта       вагонетка, ковши, жёлоба, расплавы, книгопад, стирание
--               краёв купола (атрибут F5Erasure), ворота, эпилог
--
-- Временные детали — в Workspace.Floor45Fx; дальние эффекты не рисуются.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local Palette = require(Shared.Config.Palette)
local EnemyVisuals = require(Shared.Config.EnemyVisuals)

local Bus = require(script.Parent.Parent.Lib.Bus)
local TEX = require(script.Parent.Parent.Lib.FxTex)
local EnemyVisualController = require(script.Parent.EnemyVisualController)

local Floor45Fx = {}

local V = Palette.Voxel
local V3 = Vector3.new
local rgb = Color3.fromRGB
local hex = Color3.fromHex
local TAU = math.pi * 2
local FAR_FX = 110
local DEBRIS_MAX = 260

local C = {
	danger = V.X,
	-- этаж 4 (#1E1B1F #4A4350 #E2672B #FFC857)
	soot = hex("#1E1B1F"),
	iron = hex("#4A4350"),
	ember = hex("#E2672B"),
	gold = hex("#FFC857"),
	white = rgb(255, 241, 184),
	crust = rgb(58, 40, 36),
	steam = rgb(220, 214, 210),
	-- этаж 5 (#1D1B3A #4A3F8F #8E7CE0 #B8E3FF)
	night = hex("#1D1B3A"),
	ink = rgb(26, 22, 48),
	inkGloss = hex("#4A3F8F"),
	rune = hex("#8E7CE0"),
	frost = hex("#B8E3FF"),
	paper = rgb(236, 228, 204),
	paperDark = rgb(196, 184, 150),
	blank = rgb(244, 246, 255),
}

local player = Players.LocalPlayer
local random = Random.new()

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function sfx(name: string, position: Vector3?)
	Bus.emit("sfx", { name = name, position = position })
end

local function notify(text: string)
	Bus.emit("notify", { kind = "warn", text = text })
end

local function banner(top: string?, text: string)
	Bus.emit("banner", { top = top, text = text })
end

local function shake(amount: number, time: number)
	Bus.emit("shake", { amount = amount, time = time })
end

local tipsShown: { [string]: boolean } = {}
local function tipOnce(key: string, text: string)
	if not tipsShown[key] then
		tipsShown[key] = true
		notify(text)
	end
end

local folderRef
local function folder()
	if folderRef and folderRef.Parent then
		return folderRef
	end
	folderRef = Workspace:FindFirstChild("Floor45Fx")
	if not folderRef then
		folderRef = Instance.new("Folder")
		folderRef.Name = "Floor45Fx"
		folderRef.Parent = Workspace
	end
	return folderRef
end

local function part(props, class: string?)
	local p = Instance.new(class or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = folder()
	return p
end

local DISC_TURN = CFrame.Angles(0, 0, math.rad(90))
local function discCFrame(center: Vector3, lift: number): CFrame
	return CFrame.new(center + V3(0, lift, 0)) * DISC_TURN
end

local function near(position: Vector3, range: number?): boolean
	local camera = Workspace.CurrentCamera
	return camera == nil or (camera.CFrame.Position - position).Magnitude < (range or FAR_FX)
end

local function flat(v: Vector3): Vector3
	return V3(v.X, 0, v.Z)
end

local function unitFlat(v: Vector3, fallback: Vector3): Vector3
	local f = flat(v)
	if f.Magnitude < 0.01 then
		return fallback
	end
	return f.Unit
end

local function onFloor45(): boolean
	local id = player:GetAttribute("FloorId")
	return player:GetAttribute("Zone") == "Floor" and (id == 4 or id == 5)
end

-- Треугольник из двух клиньев (конусы).
local function triangle(a: Vector3, b: Vector3, c: Vector3, w1: WedgePart, w2: WedgePart, thickness: number)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab)
	if right.Magnitude < 1e-4 or bc.Magnitude < 1e-4 then
		w1.CFrame = CFrame.new(0, -2000, 0)
		w2.CFrame = CFrame.new(0, -2000, 0)
		return
	end
	right = right.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	w1.Size = V3(thickness, math.max(height, 0.01), math.max(math.abs(ab:Dot(back)), 0.01))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)
	w2.Size = V3(thickness, math.max(height, 0.01), math.max(math.abs(ac:Dot(back)), 0.01))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
end

-- ===== Осколки, искры, капли =====

local debris = {}

local function spawnBit(position: Vector3, velocity: Vector3, color: Color3, size: number, life: number, neon: boolean?, floorY: number?, gravity: number?)
	if #debris >= DEBRIS_MAX then
		local oldest = table.remove(debris, 1)
		oldest.part:Destroy()
	end
	local p = part({
		Name = "Bit",
		Size = V3(size, size, size),
		CFrame = CFrame.new(position),
		Color = color,
		Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic,
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
end

local function burst(position: Vector3, count: number, colors, size: number, speed: number, up: number?, floorY: number?, neon: boolean?)
	if not near(position) then
		return
	end
	for _ = 1, count do
		local color = colors[random:NextInteger(1, #colors)]
		local s = size * random:NextNumber(0.6, 1.3)
		local v = V3(random:NextNumber(-1, 1) * speed * 0.5, random:NextNumber(0.3, 1) * speed * (up or 1), random:NextNumber(-1, 1) * speed * 0.5)
		spawnBit(position + V3(random:NextNumber(-0.3, 0.3), random:NextNumber(0, 0.3), random:NextNumber(-0.3, 0.3)), v, color, s, random:NextNumber(0.5, 1.1), neon, floorY)
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
		if k >= 1 then
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

-- ===== Частицы =====

local function nseq(points)
	local keys = {}
	for _, pt in ipairs(points) do
		table.insert(keys, NumberSequenceKeypoint.new(pt[1], pt[2]))
	end
	return NumberSequence.new(keys)
end

local function cseq(a: Color3, b: Color3?)
	return b and ColorSequence.new(a, b) or ColorSequence.new(a)
end

-- Эмиттер на невидимой опоре (как Floor2Fx.emitter).
local function emitter(position: Vector3, o, duration: number?)
	local anchor = part({ Name = "Fx", Size = o.box or V3(0.2, 0.2, 0.2), Transparency = 1, CFrame = o.cframe or CFrame.new(position) })
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.tex or TEX.glow
	e.Color = typeof(o.color) == "ColorSequence" and o.color or cseq(o.color or Color3.new(1, 1, 1))
	e.Size = o.size or NumberSequence.new(0.5)
	e.Transparency = o.transp or nseq({ { 0, 0.2 }, { 1, 1 } })
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
	Debris:AddItem(anchor, (duration or 0) + (o.life and o.life[2] or 1.2) + 0.2)
	return anchor, e
end

local function smokePuff(position: Vector3, color: Color3, count: number, size: number)
	if not near(position) then
		return
	end
	emitter(position, {
		tex = TEX.smoke, color = color, emit = count, life = { 0.8, 1.6 }, speed = { 1.5, 4 }, spread = 180,
		size = nseq({ { 0, size * 0.5 }, { 1, size * 1.6 } }), transp = nseq({ { 0, 0.4 }, { 1, 1 } }), light = 0.1, drag = 2,
		accel = V3(0, 1.5, 0),
	})
end

local function sparks(position: Vector3, color: Color3, count: number, speed: number?)
	if not near(position) then
		return
	end
	emitter(position, {
		tex = TEX.spark, color = color, emit = count, life = { 0.25, 0.6 }, speed = { (speed or 14) * 0.5, speed or 14 }, spread = 180,
		size = nseq({ { 0, 0.35 }, { 1, 0 } }), transp = nseq({ { 0, 0 }, { 1, 0.6 } }), light = 1, accel = V3(0, -30, 0),
	})
end

-- Предупреждающее кольцо на полу (наливается к сроку).
local function warnRing(position: Vector3, radius: number, color: Color3, duration: number)
	if not near(position) then
		return
	end
	local d = radius * 2
	local rim = part({ Name = "WarnRing", Size = V3(0.06, d, d), CFrame = discCFrame(position, 0.08), Color = color, Material = Enum.Material.Neon, Transparency = 0.75, Shape = Enum.PartType.Cylinder })
	local fill = part({ Name = "WarnFill", Size = V3(0.07, 0.2, 0.2), CFrame = discCFrame(position, 0.1), Color = color, Material = Enum.Material.Neon, Transparency = 0.55, Shape = Enum.PartType.Cylinder })
	TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = V3(0.07, d * 0.96, d * 0.96), Transparency = 0.35 }):Play()
	Debris:AddItem(rim, duration + 0.05)
	Debris:AddItem(fill, duration + 0.05)
end

-- Расходящаяся волна (чтение вслух, падение книги, остывание горна).
local function shockRing(position: Vector3, radius: number, color: Color3, time: number)
	if not near(position) then
		return
	end
	local ring = part({ Name = "Wave", Shape = Enum.PartType.Cylinder, Size = V3(0.08, 1, 1), CFrame = discCFrame(position, 0.12), Color = color, Material = Enum.Material.Neon, Transparency = 0.3 })
	TweenService:Create(ring, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = V3(0.08, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(ring, time + 0.05)
end

-- Брошенный ком (шлак, чернила): дуга до точки, потом брызги.
local function lob(from: Vector3, to: Vector3, color: Color3, glow: Color3, size: number, time: number, onLand)
	if not near(to) and not near(from) then
		return
	end
	local blob = part({ Name = "Lob", Shape = Enum.PartType.Ball, Size = V3(size, size, size), CFrame = CFrame.new(from), Color = color, Material = Enum.Material.Neon })
	local born = os.clock()
	local apex = math.max(from.Y, to.Y) + 4 + (to - from).Magnitude * 0.15
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local k = (os.clock() - born) / time
		if k >= 1 or not blob.Parent then
			connection:Disconnect()
			blob:Destroy()
			if onLand then
				onLand()
			end
			return
		end
		local p = from:Lerp(to, k)
		local y = (1 - k) * (1 - k) * from.Y + 2 * (1 - k) * k * apex + k * k * to.Y
		blob.CFrame = CFrame.new(p.X, y, p.Z)
		if random:NextNumber() < 0.5 then
			spawnBit(blob.Position, V3(random:NextNumber(-1, 1), random:NextNumber(0, 2), random:NextNumber(-1, 1)), glow, size * 0.35, 0.35, true, to.Y)
		end
	end)
end

-- ===== Лужи: расплав, чернила, стирание =====

local puddles = {} -- [id] = puddle

local PUDDLE_STYLE = {
	molten = { base = C.ember, inner = C.gold, rim = C.crust, innerNeon = true, baseNeon = true, rimNeon = false, bubble = C.gold, ember = true, transp = 0.1 },
	ink = { base = C.ink, inner = C.inkGloss, rim = C.rune, innerNeon = false, baseNeon = false, rimNeon = true, bubble = C.inkGloss, transp = 0.1 },
	erase = { base = C.blank, inner = C.frost, rim = C.frost, innerNeon = true, baseNeon = true, rimNeon = true, bubble = C.blank, mote = true, transp = 0.45 },
}

local function puddleFx(center: Vector3, radius: number, style)
	local anchor = part({ Name = "PuddleFx", Size = V3(radius * 1.6, 0.4, radius * 1.6), Transparency = 1, CFrame = CFrame.new(center + V3(0, 0.3, 0)) })
	local items = {}
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = style.ember and TEX.spark or TEX.glow
	bubbles.Color = ColorSequence.new(style.bubble)
	bubbles.LightEmission = 1
	bubbles.LightInfluence = 0
	bubbles.Rate = math.clamp(radius * radius * 1.2, 4, 22)
	bubbles.Lifetime = NumberRange.new(0.6, 1.4)
	bubbles.Speed = NumberRange.new(style.ember and 2 or 0.6, style.ember and 5 or 1.6)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.SpreadAngle = Vector2.new(15, 15)
	bubbles.Shape = Enum.ParticleEmitterShape.Box
	bubbles.Acceleration = style.ember and V3(0, -4, 0) or V3(0, 0, 0)
	bubbles.Size = nseq({ { 0, style.ember and 0.25 or 0.15 }, { 0.8, 0.3 }, { 1, 0 } })
	bubbles.Transparency = nseq({ { 0, 0.4 }, { 0.3, 0.05 }, { 1, 0.9 } })
	bubbles.Parent = anchor
	table.insert(items, bubbles)
	if style.ember or style.mote then
		local haze = Instance.new("ParticleEmitter")
		haze.Texture = TEX.smoke
		haze.Color = ColorSequence.new(style.ember and rgb(90, 70, 64) or C.blank)
		haze.LightEmission = style.ember and 0.2 or 0.6
		haze.Rate = style.ember and 4 or 6
		haze.Lifetime = NumberRange.new(1.8, 3.0)
		haze.Speed = NumberRange.new(0.8, 2)
		haze.EmissionDirection = Enum.NormalId.Top
		haze.Shape = Enum.ParticleEmitterShape.Box
		haze.Size = nseq({ { 0, radius * 0.4 }, { 1, radius * 0.9 } })
		haze.Transparency = nseq({ { 0, 0.85 }, { 0.4, 0.7 }, { 1, 1 } })
		haze.Parent = anchor
		table.insert(items, haze)
	end
	if style.ember then
		local light = Instance.new("PointLight")
		light.Color = C.ember
		light.Range = radius * 2.6
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = anchor
	end
	return anchor, items
end

local function addPuddle(id: number, kind: string, center: Vector3, radius: number, life: number)
	local style = PUDDLE_STYLE[kind]
	if not style or puddles[id] then
		return
	end
	local function disc(name, color, neon)
		return part({ Name = name, Shape = Enum.PartType.Cylinder, Color = color, Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic, Transparency = 1, Size = V3(0.08, 0.2, 0.2) })
	end
	local blobs = {}
	for index = 1, 6 do
		local angle = index / 6 * TAU + random:NextNumber(-0.4, 0.4)
		table.insert(blobs, { part = disc("Blob", style.base, style.baseNeon), angle = angle, r = random:NextNumber(0.6, 0.88), size = random:NextNumber(0.3, 0.55) })
	end
	-- Корка расплава: тёмные островки поверх светящейся лужи.
	local crust = {}
	if kind == "molten" then
		for _ = 1, 4 do
			local a, r = random:NextNumber() * TAU, random:NextNumber(0.1, 0.6)
			table.insert(crust, { part = disc("Crust", C.crust, false), angle = a, r = r, size = random:NextNumber(0.18, 0.3) })
		end
	end
	local entry = {
		kind = kind,
		style = style,
		center = center,
		radius = radius,
		born = os.clock(),
		untilT = os.clock() + life,
		base = disc("Puddle", style.base, style.baseNeon),
		inner = disc("PuddleInner", style.inner, style.innerNeon),
		rim = disc("PuddleRim", style.rim, style.rimNeon),
		blobs = blobs,
		crust = crust,
		nextFx = 0,
	}
	puddles[id] = entry
	entry.fx, entry.fxItems = puddleFx(center, radius, style)
	if near(center) then
		burst(center + V3(0, 0.3, 0), 12, { style.base, style.inner }, 0.2, 12, 0.9, center.Y, style.baseNeon)
		sfx(kind == "molten" and "moltenHiss" or (kind == "ink" and "inkSplash" or "erasureHum"), center)
	end
end

local function removePuddle(id)
	local p = puddles[id]
	if not p then
		return
	end
	puddles[id] = nil
	p.base:Destroy()
	p.inner:Destroy()
	p.rim:Destroy()
	for _, blob in ipairs(p.blobs) do
		blob.part:Destroy()
	end
	for _, c in ipairs(p.crust) do
		c.part:Destroy()
	end
	if p.fx then
		p.fx:Destroy()
	end
end

local function stepPuddles()
	local now = os.clock()
	for id, p in pairs(puddles) do
		if now >= p.untilT then
			removePuddle(id)
			continue
		end
		local grow = math.clamp((now - p.born) / 0.3, 0, 1)
		grow = 1 - (1 - grow) ^ 3
		local fade = math.clamp((p.untilT - now) / 0.9, 0, 1)
		local r = p.radius * grow * (0.85 + 0.15 * fade)
		local d = math.max(r * 2, 0.2)
		local base = p.style.transp
		local flicker = p.kind == "molten" and 0.06 * math.sin(now * 7 + p.center.Z) or 0
		p.base.Size = V3(0.08, d, d)
		p.base.CFrame = discCFrame(p.center, 0.05)
		p.base.Transparency = 1 - (1 - base) * fade
		p.inner.Size = V3(0.08, d * 0.6, d * 0.6)
		p.inner.CFrame = discCFrame(p.center, 0.07)
		p.inner.Transparency = 1 - (0.85 - base * 0.5 + flicker) * fade
		p.rim.Size = V3(0.06, d * 1.06, d * 1.06)
		p.rim.CFrame = discCFrame(p.center, 0.03)
		p.rim.Transparency = 1 - (p.style.rimNeon and 0.35 or 0.6) * fade
		for _, blob in ipairs(p.blobs) do
			local bd = math.max(r * blob.size * 2, 0.2)
			local pos = p.center + V3(math.cos(blob.angle) * r * blob.r, 0, math.sin(blob.angle) * r * blob.r)
			blob.part.Size = V3(0.08, bd, bd)
			blob.part.CFrame = discCFrame(pos, 0.05)
			blob.part.Transparency = 1 - (1 - base) * fade
		end
		for _, c in ipairs(p.crust) do
			local cd = math.max(r * c.size * 2, 0.2)
			local pos = p.center + V3(math.cos(c.angle + now * 0.05) * r * c.r, 0, math.sin(c.angle + now * 0.05) * r * c.r)
			c.part.Size = V3(0.08, cd, cd)
			c.part.CFrame = discCFrame(pos, 0.09)
			-- К концу жизни лужа остывает: корка растёт и темнеет.
			c.part.Transparency = 1 - (0.6 + 0.35 * (1 - fade)) * math.min(1, fade * 4)
		end
		if now >= p.nextFx then
			p.nextFx = now + 0.5
			local on = near(p.center) and fade > 0.3
			for _, item in ipairs(p.fxItems or {}) do
				item.Enabled = on
			end
		end
	end
end

local function clearPuddles(offsetX: number?)
	for id, p in pairs(puddles) do
		if not offsetX or math.abs(p.center.X - offsetX) < 600 then
			removePuddle(id)
		end
	end
end

-- ===== Враги: конусы, нити, луч, пар, лучи печатей =====

local TYPES = {}
for _, id in ipairs({ "forge_automaton", "fire_spirit", "slag_thrower", "smolder", "elder_founder", "stone_reader", "seal_mage", "ward_seal", "ink_scribe", "ink_blot", "shelf_warden", "bookbinder", "chief_chronicler" }) do
	TYPES[id] = true
end

local tracked = {} -- [serverModel] = entry

local function rootOf(model)
	return model and (model:FindFirstChild("Root") or model.PrimaryPart)
end

local function rigPose(model)
	local rig = EnemyVisualController.rigOf(model)
	if rig and rig.pos then
		return rig.pos, rig.facing, rig
	end
	local root = rootOf(model)
	if not root then
		return nil
	end
	local height = model:GetAttribute("EnemyHeight") or 5
	local look = flat(root.CFrame.LookVector)
	return root.Position - V3(0, height / 2, 0), look.Magnitude > 0.01 and look.Unit or V3(0, 0, -1), nil
end

local function oneShot(model, key: string)
	local rig = EnemyVisualController.rigOf(model)
	local typeId = model:GetAttribute("EnemyType")
	local visual = typeId and EnemyVisuals.Types and EnemyVisuals.Types[typeId]
	local name = visual and visual.oneShots and visual.oneShots[key]
	if rig and rig.animator and name then
		pcall(function()
			rig.animator:playOneShot(name)
		end)
	end
end

local function windupProgress(model): number
	local now = serverNow()
	local at = model:GetAttribute("EnemyStateAt") or now
	local dur = model:GetAttribute("EnemyStateDur") or 1
	return math.clamp((now - at) / math.max(dur, 0.05), 0, 1)
end

-- Конус: веер треугольников.
local CONE_SLICES = 7

local function hideCone(entry)
	local cone = entry.cone
	if not cone then
		return
	end
	for _, w in ipairs(cone.wedges) do
		w:Destroy()
	end
	for _, r in ipairs(cone.rim) do
		r:Destroy()
	end
	entry.cone = nil
end

local function drawCone(entry, model, spec: string, progress: number, color: Color3)
	local a, l, dx, dz = string.match(spec, "^([%d%.]+),([%d%.]+),([%-%d%.]+),([%-%d%.]+)$")
	local coneAngle, length = tonumber(a), tonumber(l)
	if not coneAngle or not length then
		return
	end
	local feet = rigPose(model)
	if not feet then
		return
	end
	local dir = unitFlat(V3(tonumber(dx) or 0, 0, tonumber(dz) or -1), V3(0, 0, -1))
	if not entry.cone then
		local cone = { wedges = {}, rim = {} }
		for _ = 1, CONE_SLICES * 2 do
			table.insert(cone.wedges, part({ Name = "Cone", Material = Enum.Material.Neon, Color = color, Transparency = 0.8 }, "WedgePart"))
		end
		for _ = 1, CONE_SLICES do
			table.insert(cone.rim, part({ Name = "ConeRim", Material = Enum.Material.Neon, Color = color, Transparency = 0.35, Size = V3(0.12, 0.06, 1) }))
		end
		entry.cone = cone
	end
	local cone = entry.cone
	local origin = feet + V3(0, 0.1, 0)
	local reach = length * (0.35 + 0.65 * progress)
	local half = math.rad(coneAngle / 2)
	local transparency = 0.82 - 0.22 * progress
	local points = {}
	for index = 0, CONE_SLICES do
		local ang = -half + (index / CONE_SLICES) * half * 2
		table.insert(points, origin + CFrame.Angles(0, ang, 0):VectorToWorldSpace(dir) * reach)
	end
	for index = 1, CONE_SLICES do
		local w1, w2 = cone.wedges[index * 2 - 1], cone.wedges[index * 2]
		triangle(origin, points[index], points[index + 1], w1, w2, 0.05)
		w1.Transparency, w2.Transparency = transparency, transparency
		local p0, p1 = points[index], points[index + 1]
		local rim = cone.rim[index]
		rim.Size = V3(0.14, 0.07, (p1 - p0).Magnitude)
		rim.CFrame = CFrame.lookAt((p0 + p1) / 2 + V3(0, 0.02, 0), p1 + V3(0, 0.02, 0))
	end
end

local function hideStrips(entry, key: string)
	for _, strip in ipairs(entry[key] or {}) do
		strip:Destroy()
	end
	entry[key] = nil
	entry[key .. "Spec"] = nil
end

local function parseLines(spec: string)
	local list = {}
	for chunk in string.gmatch(spec, "[^;]+") do
		local dx, dz, len = string.match(chunk, "^([%-%d%.]+),([%-%d%.]+),([%d%.]+)$")
		if dx then
			table.insert(list, { dir = V3(tonumber(dx), 0, tonumber(dz)), length = tonumber(len) })
		end
	end
	return list
end

local function drawStrips(entry, key: string, spec: string, origin: Vector3, width: number, progress: number, color: Color3, list)
	if entry[key .. "Spec"] ~= spec then
		hideStrips(entry, key)
		entry[key .. "Spec"] = spec
		entry[key .. "Data"] = list
		entry[key] = {}
		for _ = 1, #list do
			table.insert(entry[key], part({ Name = "Strip", Material = Enum.Material.Neon, Color = color, Transparency = 0.7 }))
		end
	end
	for index, line in ipairs(entry[key .. "Data"]) do
		local strip = entry[key][index]
		local length = math.max(line.length * (0.15 + 0.85 * progress), 0.2)
		local start = origin + V3(0, 0.12, 0) + line.dir * 1.2
		strip.Size = V3(width * (0.5 + 0.5 * progress), 0.06, length)
		strip.CFrame = CFrame.lookAt(start + line.dir * length / 2, start + line.dir * (length + 1))
		strip.Transparency = 0.78 - 0.33 * progress
	end
end

-- Луч между двумя точками (печати): тонкая неоновая палка.
local function linkPart(entry, key: string, color: Color3)
	if not entry[key] then
		entry[key] = part({ Name = "WardLink", Material = Enum.Material.Neon, Color = color, Transparency = 0.4, Size = V3(0.18, 0.18, 1) })
	end
	return entry[key]
end

local function placeLink(link: BasePart, a: Vector3, b: Vector3, t: number)
	local length = (b - a).Magnitude
	if length < 0.1 then
		link.CFrame = CFrame.new(0, -2000, 0)
		return
	end
	local w = 0.14 + 0.06 * math.sin(t * 9)
	link.Size = V3(w, w, length)
	link.CFrame = CFrame.lookAt((a + b) / 2, b)
	link.Transparency = 0.35 + 0.2 * math.sin(t * 5)
end

local function untrack(model)
	local entry = tracked[model]
	if not entry then
		return
	end
	tracked[model] = nil
	hideCone(entry)
	hideStrips(entry, "lines")
	hideStrips(entry, "beam")
	for _, key in ipairs({ "wardLink", "bossLink", "shield", "steam" }) do
		if entry[key] then
			entry[key]:Destroy()
			entry[key] = nil
		end
	end
end

local function track(instance)
	if tracked[instance] or not instance:IsA("Model") then
		return
	end
	local typeId = instance:GetAttribute("EnemyType")
	if not TYPES[typeId] then
		return
	end
	tracked[instance] = { typeId = typeId }
	instance.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			untrack(instance)
		end
	end)
end

local function stepSteam(entry, model, until_: number)
	local now = serverNow()
	if now < until_ then
		if not entry.steam then
			local root = rootOf(model)
			if root then
				local anchor, e = emitter(root.Position, {
					tex = TEX.smoke, color = C.steam, rate = 30, life = { 0.6, 1.2 }, speed = { 4, 8 }, spread = 25,
					size = nseq({ { 0, 0.6 }, { 1, 2.2 } }), transp = nseq({ { 0, 0.3 }, { 1, 1 } }), light = 0.2, drag = 1.5, box = V3(2.5, 1, 2.5),
				}, until_ - now)
				entry.steam = anchor
				entry.steamEmitter = e
			end
		end
		if entry.steam and entry.steam.Parent then
			local root = rootOf(model)
			if root then
				entry.steam.CFrame = root.CFrame * CFrame.new(0, 1.2, 0.6)
			end
		end
	elseif entry.steam then
		entry.steam = nil
	end
end

local function stepEnemies()
	local t = os.clock()
	for model, entry in pairs(tracked) do
		if not model.Parent then
			untrack(model)
			continue
		end
		local state = model:GetAttribute("EnemyState")
		local windup = state == "windup"
		-- Конус: выдох жара автомата, ковш литейщика.
		local cone = model:GetAttribute("F45Cone")
		if type(cone) == "string" and windup then
			drawCone(entry, model, cone, windupProgress(model), C.danger)
		elseif entry.cone then
			hideCone(entry)
		end
		-- Нити Переплётчика.
		local lines = model:GetAttribute("F45Lines")
		local origin = model:GetAttribute("F45LinesOrigin")
		if type(lines) == "string" and typeof(origin) == "Vector3" and windup then
			drawStrips(entry, "lines", lines, origin, model:GetAttribute("F45LinesWidth") or 1.6, windupProgress(model), C.danger, parseLines(lines))
		elseif entry.lines then
			hideStrips(entry, "lines")
		end
		-- Луч строки Хрониста.
		local beam = model:GetAttribute("F45Beam")
		if type(beam) == "string" and windup then
			local ox, oy, oz, dx, dz, len, width = string.match(beam, "^([%-%d%.]+),([%-%d%.]+),([%-%d%.]+),([%-%d%.]+),([%-%d%.]+),([%d%.]+),([%d%.]+)$")
			if ox then
				local list = { { dir = unitFlat(V3(tonumber(dx), 0, tonumber(dz)), V3(0, 0, -1)), length = tonumber(len) } }
				drawStrips(entry, "beam", beam, V3(tonumber(ox), tonumber(oy), tonumber(oz)), tonumber(width) or 2.6, windupProgress(model), C.danger, list)
			end
		elseif entry.beam then
			hideStrips(entry, "beam")
		end
		-- Пар открытого автомата.
		local vent = model:GetAttribute("F45VentUntil")
		if type(vent) == "number" then
			stepSteam(entry, model, vent)
		end
		-- Маг → своя печать.
		local wardAt = model:GetAttribute("F45WardAt")
		if typeof(wardAt) == "Vector3" then
			local feet, _ = rigPose(model)
			if feet and near(feet) then
				local height = model:GetAttribute("EnemyHeight") or 6
				placeLink(linkPart(entry, "wardLink", C.rune), feet + V3(0, height * 0.6, 0), wardAt, t)
			end
		elseif entry.wardLink then
			entry.wardLink:Destroy()
			entry.wardLink = nil
		end
		-- Печать купола → Хронист.
		local target = model:FindFirstChild("F45WardTarget")
		if target and target:IsA("ObjectValue") and target.Value and target.Value.Parent then
			local a = rootOf(model)
			local b = rootOf(target.Value)
			if a and b and near(a.Position) then
				placeLink(linkPart(entry, "bossLink", C.frost), a.Position + V3(0, 1, 0), b.Position, t)
			end
		elseif entry.bossLink then
			entry.bossLink:Destroy()
			entry.bossLink = nil
		end
		-- Щит Хрониста, пока стоят печати.
		local sealsUp = model:GetAttribute("F5SealsUp")
		if type(sealsUp) == "number" and sealsUp > 0 then
			local root = rootOf(model)
			if root then
				if not entry.shield then
					entry.shield = part({ Name = "SealShield", Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = C.rune, Transparency = 0.2 })
				end
				local height = model:GetAttribute("EnemyHeight") or 12
				local s = height * 1.05 + 0.4 * math.sin(t * 2)
				entry.shield.Size = V3(s, s, s)
				entry.shield.CFrame = CFrame.new(root.Position)
			end
		elseif entry.shield then
			entry.shield:Destroy()
			entry.shield = nil
			sparks((rootOf(model) or { Position = V3() }).Position, C.frost, 40, 20)
		end
	end
end

-- ===== Игроки: ожог =====

local playerFx = {}
local burnTint

local function stepPlayers(dt: number)
	local now = serverNow()
	local clock = os.clock()
	local localBurn = false
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local entry = playerFx[other]
		if not entry then
			entry = { nextEmber = 0, nextTick = 0 }
			playerFx[other] = entry
		end
		if not root then
			continue
		end
		local burning = now < (other:GetAttribute("BurnUntil") or 0)
		if burning and clock >= entry.nextEmber and near(root.Position) then
			entry.nextEmber = clock + 0.07
			local pos = root.Position + V3(random:NextNumber(-0.9, 0.9), random:NextNumber(-2.2, 1.2), random:NextNumber(-0.9, 0.9))
			spawnBit(pos, V3(random:NextNumber(-0.5, 0.5), random:NextNumber(3, 6), random:NextNumber(-0.5, 0.5)), random:NextNumber() < 0.5 and C.gold or C.ember, random:NextNumber(0.1, 0.22), 0.5, true, pos.Y - 5, -2)
		end
		if other == player then
			localBurn = burning
			if burning and clock >= entry.nextTick then
				entry.nextTick = clock + 0.5
				sfx("moltenHiss")
			end
			if burning then
				tipOnce("burn", "Ожог! Жжёт, пока не погаснет. Не стойте в расплаве")
			end
		end
	end
	for other in pairs(playerFx) do
		if not other.Parent then
			playerFx[other] = nil
		end
	end
	if not burnTint then
		burnTint = Instance.new("ColorCorrectionEffect")
		burnTint.Name = "Floor45Burn"
		burnTint.Enabled = false
		burnTint.Parent = Lighting
	end
	local target = localBurn and 1 or 0
	local current = burnTint:GetAttribute("K") or 0
	current += math.clamp(target - current, -dt * 3, dt * 3)
	burnTint:SetAttribute("K", current)
	burnTint.Enabled = current > 0.01
	if burnTint.Enabled then
		burnTint.TintColor = Color3.new(1, 1, 1):Lerp(rgb(255, 214, 180), current)
		burnTint.Contrast = 0.08 * current
	end
end

-- ===== События врагов (EnemyEvent) =====

local function coneBurst(origin: Vector3, dir: Vector3, angle: number, length: number, pour: boolean)
	if not near(origin) then
		return
	end
	local half = math.rad(angle / 2)
	for _ = 1, pour and 40 or 30 do
		local a = random:NextNumber(-half, half)
		local d = CFrame.Angles(0, a, 0):VectorToWorldSpace(dir)
		local speed = random:NextNumber(0.5, 1) * length * 2.2
		local color = random:NextNumber() < 0.4 and C.gold or (pour and C.ember or C.white)
		spawnBit(origin + V3(0, pour and 2.5 or 1.6, 0) + d * 0.8, d * speed + V3(0, random:NextNumber(2, 6), 0), color, random:NextNumber(0.15, 0.3), random:NextNumber(0.35, 0.6), true, origin.Y + 0.05, pour and 30 or 6)
	end
	emitter(origin + V3(0, 1.6, 0) + dir * 1.5, {
		tex = TEX.smoke, color = pour and rgb(110, 70, 50) or rgb(255, 160, 80), emit = 18, life = { 0.4, 0.9 }, speed = { length * 0.8, length * 1.6 },
		spread = angle / 2, size = nseq({ { 0, 1 }, { 1, 3 } }), transp = nseq({ { 0, 0.3 }, { 1, 1 } }), light = pour and 0.3 or 1, drag = 3,
		cframe = CFrame.lookAt(origin + V3(0, 1.6, 0), origin + V3(0, 1.6, 0) + dir) * CFrame.Angles(-math.pi / 2, 0, 0),
	})
	sfx(pour and "forgePour" or "forgeBlast", origin)
	shake(pour and 0.25 or 0.18, 0.25)
end

local function linesBurst(origin: Vector3, lines, width: number)
	for _, line in ipairs(lines) do
		local dir = unitFlat(line.dir, V3(0, 0, -1))
		local strip = part({ Name = "Thread", Material = Enum.Material.Neon, Color = C.rune, Transparency = 0.2, Size = V3(width * 0.35, 0.12, line.length) })
		local start = origin + V3(0, 0.6, 0) + dir * 1.2
		strip.CFrame = CFrame.lookAt(start + dir * line.length / 2, start + dir * (line.length + 1))
		TweenService:Create(strip, TweenInfo.new(0.5), { Transparency = 1, Size = V3(0.05, 0.05, line.length) }):Play()
		Debris:AddItem(strip, 0.55)
		for step = 1, math.floor(line.length / 1.5) do
			local p = start + dir * step * 1.5
			spawnBit(p, V3(random:NextNumber(-2, 2), random:NextNumber(3, 6), random:NextNumber(-2, 2)), random:NextNumber() < 0.5 and C.ink or C.rune, 0.16, 0.5, true, origin.Y)
		end
	end
	sfx("pageRustle", origin)
end

local function beamBurst(origin: Vector3, dir: Vector3, length: number, width: number)
	local d = unitFlat(dir, V3(0, 0, -1))
	local a = origin + V3(0, 2.2, 0)
	local b = a + d * length
	local core = part({ Name = "Beam", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = C.frost, Transparency = 0.05, Size = V3(length, width * 0.7, width * 0.7) })
	core.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	local glow = part({ Name = "BeamGlow", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = C.rune, Transparency = 0.55, Size = V3(length, width * 1.3, width * 1.3) })
	glow.CFrame = core.CFrame
	TweenService:Create(core, TweenInfo.new(0.45), { Transparency = 1, Size = V3(length, 0.1, 0.1) }):Play()
	TweenService:Create(glow, TweenInfo.new(0.55), { Transparency = 1 }):Play()
	Debris:AddItem(core, 0.5)
	Debris:AddItem(glow, 0.6)
	for step = 1, math.floor(length / 2) do
		sparks(a + d * step * 2, C.frost, 3, 8)
	end
	sfx("chronicleBeam", origin)
	shake(0.22, 0.3)
end

local function onEnemyEvent(payload)
	if type(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	if type(kind) ~= "string" or string.sub(kind, 1, 3) ~= "f45" then
		return
	end
	if kind == "f45hazard" and typeof(payload.position) == "Vector3" then
		addPuddle(payload.id, payload.hazard, payload.position, payload.radius or 3, payload.life or 5)
	elseif kind == "f45hazardEnd" then
		removePuddle(payload.id)
	elseif kind == "f45hazardClear" then
		clearPuddles(payload.offsetX)
	elseif kind == "f45cone" and typeof(payload.origin) == "Vector3" and typeof(payload.direction) == "Vector3" then
		coneBurst(payload.origin, unitFlat(payload.direction, V3(0, 0, -1)), payload.angle or 60, payload.length or 8, payload.cone == "pour")
	elseif kind == "f45lines" and typeof(payload.origin) == "Vector3" and type(payload.lines) == "table" then
		linesBurst(payload.origin, payload.lines, payload.width or 1.6)
	elseif kind == "f45beam" and typeof(payload.origin) == "Vector3" and typeof(payload.direction) == "Vector3" then
		beamBurst(payload.origin, payload.direction, payload.length or 30, payload.width or 2.6)
	elseif kind == "f45vent" and payload.model then
		oneShot(payload.model, "vent")
		local pos = payload.position or (rootOf(payload.model) and rootOf(payload.model).Position)
		if pos then
			sfx("ventHiss", pos)
			smokePuff(pos + V3(0, 3, 0), C.steam, 16, 1.4)
		end
		tipOnce("vent", "Клапаны автомата открыты — сейчас он уязвим!")
	elseif kind == "f45hop" and payload.model then
		oneShot(payload.model, "hop")
		local root = rootOf(payload.model)
		if root then
			burst(root.Position, 12, { C.paper, C.paperDark }, 0.22, 10, 0.6)
			sfx("pageRustle", root.Position)
		end
	elseif kind == "f45lob" and typeof(payload.from) == "Vector3" and type(payload.positions) == "table" then
		local inkLob = payload.ink == true
		for _, to in ipairs(payload.positions) do
			if typeof(to) == "Vector3" then
				local color = inkLob and C.ink or C.ember
				local glow = inkLob and C.rune or C.gold
				lob(payload.from, to, color, glow, payload.big and 1.1 or 0.7, 0.45, function()
					burst(to + V3(0, 0.2, 0), 10, { color, glow }, 0.2, 12, 0.8, to.Y, not inkLob)
				end)
			end
		end
		sfx(inkLob and "inkSplash" or "slagLob", payload.from)
	elseif kind == "f45recital" and typeof(payload.position) == "Vector3" then
		shockRing(payload.position, payload.radius or 8, C.rune, 0.5)
		shockRing(payload.position, (payload.radius or 8) * 0.7, C.frost, 0.4)
		sfx("chronicleChant", payload.position)
		tipOnce("recital", "«Чтение вслух» замедляет — отходите от каменного чтеца")
	elseif kind == "f45armor" and typeof(payload.position) == "Vector3" then
		sparks(payload.position, C.white, 10, 12)
		burst(payload.position, 6, { C.iron, C.paperDark }, 0.16, 10, 0.6)
		sfx("breakMetalHit", payload.position)
		tipOnce("armor", "Спереди броня гасит удар — заходите сбоку или со спины")
	elseif kind == "f45wardBlock" and typeof(payload.position) == "Vector3" then
		shockRing(payload.position - V3(0, 2, 0), payload.boss and 5 or 3, C.rune, 0.3)
		sparks(payload.position, C.rune, 8, 10)
		sfx("sealHum", payload.position)
		if payload.boss then
			tipOnce("bossSeals", "Хронист под печатями — разбейте все четыре печати")
		else
			tipOnce("ward", "Маг неуязвим, пока цела его печать — разбейте её")
		end
	elseif kind == "f45ward" and typeof(payload.position) == "Vector3" then
		shockRing(payload.position, 3, C.rune, 0.4)
		sfx("runeCharge", payload.position)
	elseif kind == "f45sealBreak" and typeof(payload.position) == "Vector3" then
		burst(payload.position + V3(0, 2, 0), 22, { C.rune, C.frost, C.inkGloss }, 0.3, 18, 1, payload.position.Y, true)
		shockRing(payload.position, 4, C.frost, 0.35)
		sfx("sealShatter", payload.position)
	elseif kind == "f45summon" and type(payload.positions) == "table" then
		for _, p in ipairs(payload.positions) do
			if typeof(p) == "Vector3" then
				burst(p + V3(0, 0.3, 0), 12, { C.ink, C.inkGloss }, 0.22, 12, 0.8, p.Y)
				smokePuff(p + V3(0, 0.8, 0), C.ink, 8, 1)
			end
		end
		local root = rootOf(payload.model)
		if root then
			sfx("inkSplash", root.Position)
		end
	end
end

-- ===== Карта (FloorEvent) =====

-- Вагонетка: собранная на клиенте воксельная тележка с рудой.
local cart = nil

local function buildCart(): Model
	local model = Instance.new("Model")
	model.Name = "F4Cart"
	local function block(name, size, offset, color, material, neon)
		local p = part({ Name = name, Size = size, Color = color, Material = neon and Enum.Material.Neon or (material or Enum.Material.Metal) })
		p:SetAttribute("Offset", offset)
		p.Parent = model
		return p
	end
	block("Body", V3(3.0, 1.6, 4.2), V3(0, 1.4, 0), C.iron, Enum.Material.Metal)
	block("Rim", V3(3.2, 0.25, 4.4), V3(0, 2.25, 0), rgb(70, 64, 74), Enum.Material.Metal)
	block("Ore", V3(2.6, 0.6, 3.8), V3(0, 2.3, 0), rgb(60, 44, 40), Enum.Material.Slate)
	block("Glow1", V3(0.7, 0.5, 0.7), V3(0.5, 2.6, 0.8), C.ember, nil, true)
	block("Glow2", V3(0.6, 0.45, 0.6), V3(-0.6, 2.55, -0.9), C.gold, nil, true)
	block("Band1", V3(3.1, 0.25, 0.25), V3(0, 1.4, 1.6), C.soot, Enum.Material.Metal)
	block("Band2", V3(3.1, 0.25, 0.25), V3(0, 1.4, -1.6), C.soot, Enum.Material.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			block("Wheel", V3(0.35, 1.0, 1.0), V3(sx * 1.55, 0.5, sz * 1.3), C.soot, Enum.Material.Metal)
		end
	end
	local light = Instance.new("PointLight")
	light.Color = C.ember
	light.Range = 12
	light.Brightness = 1.6
	light.Parent = model:FindFirstChild("Glow1")
	model.Parent = folder()
	return model
end

local function placeCart(model: Model, position: Vector3, dir: Vector3, bob: number)
	local frame = CFrame.lookAt(position, position + dir) * CFrame.new(0, bob, 0)
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			local offset = p:GetAttribute("Offset") or V3()
			local cf = frame * CFrame.new(offset)
			if p.Name == "Wheel" then
				cf *= CFrame.Angles(os.clock() * 12, 0, 0)
			end
			p.CFrame = cf
		end
	end
end

local function cartEvent(payload)
	if typeof(payload.from) ~= "Vector3" or typeof(payload.to) ~= "Vector3" then
		return
	end
	local dir = unitFlat(payload.to - payload.from, V3(0, 0, -1))
	if payload.phase == "warn" then
		if cart and cart.model then
			cart.model:Destroy()
		end
		cart = { model = buildCart(), from = payload.from, to = payload.to, dir = dir, state = "warn" }
		placeCart(cart.model, payload.from, dir, 0)
		-- Красная полоса по рельсам: путь вагонетки.
		local length = flat(payload.to - payload.from).Magnitude
		local strip = part({ Name = "CartWarn", Material = Enum.Material.Neon, Color = C.danger, Transparency = 0.85, Size = V3(payload.width or 3.6, 0.06, length) })
		strip.CFrame = CFrame.lookAt((payload.from + payload.to) / 2 + V3(0, 0.1, 0), payload.to + V3(0, 0.1, 0))
		TweenService:Create(strip, TweenInfo.new(payload.duration or 1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true), { Transparency = 0.55 }):Play()
		Debris:AddItem(strip, (payload.duration or 1.6) + 3.4)
		cart.strip = strip
		sfx("cartRoll", payload.from)
		tipOnce("cart", "По рельсам идёт вагонетка — сойдите с полосы!")
	elseif payload.phase == "run" then
		if not cart or not cart.model or not cart.model.Parent then
			cart = { model = buildCart(), from = payload.from, to = payload.to, dir = dir }
		end
		cart.state = "run"
		cart.startT = os.clock()
		cart.time = payload.duration or 3.2
		cart.nextSpark = 0
		sfx("cartRoll", payload.from)
	elseif payload.phase == "done" then
		if cart and cart.model then
			cart.model:Destroy()
		end
		if cart and cart.strip then
			cart.strip:Destroy()
		end
		cart = nil
	end
end

local function stepCart()
	if not cart or cart.state ~= "run" or not cart.model.Parent then
		return
	end
	local k = math.clamp((os.clock() - cart.startT) / cart.time, 0, 1)
	local pos = cart.from:Lerp(cart.to, k)
	placeCart(cart.model, pos, cart.dir, 0.05 * math.sin(os.clock() * 30))
	if os.clock() >= cart.nextSpark and near(pos) then
		cart.nextSpark = os.clock() + 0.08
		local side = V3(-cart.dir.Z, 0, cart.dir.X)
		for _, s in ipairs({ -1, 1 }) do
			spawnBit(pos + side * s * 1.5 + V3(0, 0.1, 0), -cart.dir * random:NextNumber(4, 8) + V3(0, random:NextNumber(2, 5), 0), C.gold, 0.12, 0.35, true, pos.Y)
		end
	end
	if k >= 1 then
		cart.state = "end"
	end
end

-- Струя из ковша / жёлоба: падает сверху к сроку.
local function pourStream(from: Vector3, to: Vector3, duration: number)
	if not near(to) then
		return
	end
	local height = math.max(from.Y - to.Y, 2)
	local stream = part({ Name = "PourStream", Material = Enum.Material.Neon, Color = C.gold, Transparency = 0.15, Size = V3(0.7, 0.1, 0.7) })
	stream.CFrame = CFrame.new(from)
	local delay = math.max(duration - 0.35, 0)
	task.delay(delay, function()
		if not stream.Parent then
			return
		end
		TweenService:Create(stream, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = V3(0.7, height, 0.7),
			CFrame = CFrame.new(to.X, to.Y + height / 2, to.Z),
		}):Play()
		task.delay(0.35, function()
			if stream.Parent then
				TweenService:Create(stream, TweenInfo.new(0.6), { Transparency = 1, Size = V3(0.2, height, 0.2) }):Play()
			end
		end)
	end)
	Debris:AddItem(stream, duration + 1.1)
end

local function pourEvent(payload)
	local position = payload.position
	if typeof(position) ~= "Vector3" then
		return
	end
	if payload.phase == "warn" then
		warnRing(position, payload.radius or 3, C.ember, payload.duration or 1.2)
		if typeof(payload.from) == "Vector3" then
			pourStream(payload.from, position, payload.duration or 1.2)
		else
			-- Расплав проступает из пола: искры по кругу.
			sparks(position, C.gold, 8, 6)
		end
		if payload.kind == "f4pour" then
			sfx("forgePour", position)
		end
	elseif payload.phase == "burst" then
		burst(position + V3(0, 0.3, 0), 18, { C.ember, C.gold, C.white }, 0.24, 16, 1, position.Y, true)
		smokePuff(position + V3(0, 0.6, 0), rgb(90, 66, 58), 6, 1.4)
		sfx("moltenHiss", position)
	end
end

-- Книга с полки: падает к сроку, бьёт, разлетаются страницы.
local function bookFall(position: Vector3, duration: number)
	if not near(position) then
		return
	end
	local colors = { rgb(120, 52, 60), rgb(52, 70, 120), rgb(74, 63, 143), rgb(96, 84, 52) }
	local book = part({ Name = "FallingBook", Size = V3(1.6, 0.5, 2.1), Color = colors[random:NextInteger(1, #colors)], Material = Enum.Material.Fabric })
	local top = position + V3(0, 16, 0)
	local spin = CFrame.Angles(random:NextNumber(-1, 1), random:NextNumber() * TAU, random:NextNumber(-1, 1))
	book.CFrame = CFrame.new(top) * spin
	TweenService:Create(book, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(position + V3(0, 0.25, 0)) * CFrame.Angles(0, random:NextNumber() * TAU, 0) }):Play()
	Debris:AddItem(book, duration + 1.2)
	task.delay(duration + 0.6, function()
		if book.Parent then
			TweenService:Create(book, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
	end)
end

-- Стирание краёв купола: стена белёсой пустоты на радиусе (атрибут F5Erasure).
local erasure = nil

local function parseErasure(value)
	if type(value) ~= "string" then
		return nil
	end
	local parts = string.split(value, ",")
	if #parts < 7 then
		return nil
	end
	return {
		center = V3(tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])),
		from = tonumber(parts[4]),
		to = tonumber(parts[5]),
		t0 = tonumber(parts[6]),
		time = tonumber(parts[7]),
	}
end

local ERASE_SEGMENTS = 40

local function hideErasure()
	if erasure then
		for _, p in ipairs(erasure.wall) do
			p:Destroy()
		end
		erasure.ring:Destroy()
		if erasure.fog then
			erasure.fog:Destroy()
		end
		erasure = nil
	end
end

local eraseTint

local function stepErasure(dt: number)
	local runtime = Workspace:FindFirstChild("Floor5")
	local spec = runtime and parseErasure(runtime:GetAttribute("F5Erasure"))
	if not spec or player:GetAttribute("FloorId") ~= 5 then
		hideErasure()
	else
		if not erasure or erasure.key ~= runtime:GetAttribute("F5Erasure") then
			hideErasure()
			erasure = { key = runtime:GetAttribute("F5Erasure"), spec = spec, wall = {} }
			for _ = 1, ERASE_SEGMENTS do
				table.insert(erasure.wall, part({ Name = "EraseWall", Material = Enum.Material.Neon, Color = C.blank, Transparency = 0.55 }))
			end
			erasure.ring = part({ Name = "EraseRing", Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = C.frost, Transparency = 0.6, Size = V3(0.06, 1, 1) })
			erasure.fog, erasure.fogEmitter = emitter(spec.center, {
				tex = TEX.smoke, color = C.blank, rate = 40, life = { 1.5, 2.5 }, speed = { 0.5, 1.5 }, spread = 180,
				size = nseq({ { 0, 2 }, { 1, 5 } }), transp = nseq({ { 0, 0.85 }, { 0.5, 0.6 }, { 1, 1 } }), light = 0.8, box = V3(1, 2, 1),
			}, 0)
			sfx("erasureHum", spec.center)
			tipOnce("erasure", "Края купола стираются — держитесь внутри светлого круга!")
		end
		local s = erasure.spec
		local k = math.clamp((serverNow() - s.t0) / math.max(s.time, 0.1), 0, 1)
		local r = s.from + (s.to - s.from) * k
		local circumference = TAU * r
		local w = circumference / ERASE_SEGMENTS + 0.2
		local pulse = 0.08 * math.sin(os.clock() * 3)
		for index, p in ipairs(erasure.wall) do
			local a = (index - 0.5) / ERASE_SEGMENTS * TAU
			local pos = s.center + V3(math.cos(a) * r, 3, math.sin(a) * r)
			p.Size = V3(w, 6 + 1.5 * math.sin(os.clock() * 2 + index), 0.3)
			p.CFrame = CFrame.lookAt(pos, V3(s.center.X, pos.Y, s.center.Z))
			p.Transparency = 0.55 + pulse + 0.1 * math.sin(os.clock() * 4 + index * 0.7)
		end
		erasure.ring.Size = V3(0.06, r * 2, r * 2)
		erasure.ring.CFrame = discCFrame(s.center, 0.15)
		if erasure.fog and erasure.fog.Parent then
			erasure.fog.Size = V3(r * 2.4, 2, r * 2.4)
		end
	end
	-- Свой игрок снаружи круга — экран выцветает.
	local outside = false
	if erasure then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local s = erasure.spec
		if root then
			local k = math.clamp((serverNow() - s.t0) / math.max(s.time, 0.1), 0, 1)
			local r = s.from + (s.to - s.from) * k
			outside = flat(root.Position - s.center).Magnitude > r and math.abs(root.Position.Y - s.center.Y) < 12
		end
	end
	if not eraseTint then
		eraseTint = Instance.new("ColorCorrectionEffect")
		eraseTint.Name = "Floor5Erase"
		eraseTint.Enabled = false
		eraseTint.Parent = Lighting
	end
	local current = eraseTint:GetAttribute("K") or 0
	current += math.clamp((outside and 1 or 0) - current, -dt * 3, dt * 3)
	eraseTint:SetAttribute("K", current)
	eraseTint.Enabled = current > 0.01
	if eraseTint.Enabled then
		eraseTint.Saturation = -0.7 * current
		eraseTint.Brightness = 0.12 * current
	end
end

-- Эпилог: затемнение, надпись-отсылка на продолжение.
local function epilogue(payload)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Floor5Epilogue"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = C.night
	shade.BackgroundTransparency = 1
	shade.BorderSizePixel = 0
	shade.Parent = gui
	local function label(text: string, y: number, size: number, color: Color3, font)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.fromScale(0.8, 0.08)
		l.Font = font or Enum.Font.Arcade
		l.Text = text
		l.TextScaled = true
		l.TextColor3 = color
		l.TextTransparency = 1
		l.TextStrokeTransparency = 1
		l.TextStrokeColor3 = Color3.new(0, 0, 0)
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = size
		limit.Parent = l
		l.Parent = shade
		return l
	end
	local title = label(string.upper(payload.title or "Хроника обрывается здесь"), 0.42, 48, C.frost)
	local text = label(payload.text or "", 0.52, 26, C.paper, Enum.Font.SourceSans)
	local sub = label(payload.sub or "Продолжение следует", 0.62, 30, C.rune)
	gui.Parent = player:WaitForChild("PlayerGui")
	sfx("epilogue")
	local fadeIn = TweenInfo.new(1.6, Enum.EasingStyle.Sine)
	TweenService:Create(shade, fadeIn, { BackgroundTransparency = 0.25 }):Play()
	task.delay(0.8, function()
		TweenService:Create(title, fadeIn, { TextTransparency = 0, TextStrokeTransparency = 0.4 }):Play()
	end)
	task.delay(2.0, function()
		TweenService:Create(text, fadeIn, { TextTransparency = 0 }):Play()
	end)
	task.delay(3.4, function()
		TweenService:Create(sub, fadeIn, { TextTransparency = 0, TextStrokeTransparency = 0.5 }):Play()
	end)
	task.delay(9.5, function()
		local out = TweenInfo.new(1.8, Enum.EasingStyle.Sine)
		for _, l in ipairs({ title, text, sub }) do
			TweenService:Create(l, out, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		TweenService:Create(shade, out, { BackgroundTransparency = 1 }):Play()
		Debris:AddItem(gui, 2)
	end)
end

local function onMapEvent(payload)
	if type(payload) ~= "table" or type(payload.kind) ~= "string" then
		return
	end
	local kind = payload.kind
	if kind == "f4cart" then
		cartEvent(payload)
	elseif kind == "f4cartHit" and typeof(payload.position) == "Vector3" then
		sparks(payload.position, C.gold, 16, 16)
		if payload.by == player then
			shake(0.45, 0.35)
		end
		sfx("hitHeavy", payload.position)
	elseif kind == "f4spill" or kind == "f4pour" or kind == "f4melt" then
		pourEvent(payload)
		if kind == "f4spill" and payload.phase == "warn" then
			tipOnce("spill", "Ковши опрокидываются — следите за кругами на полу")
		elseif kind == "f4melt" and payload.phase == "warn" then
			tipOnce("melt", "«Плавка»: пол горна плавится под ногами — не стойте на месте")
		end
	elseif kind == "f4lever" then
		sfx("leverPull", payload.position)
		banner("Клеть подъёмника", "Лебёдка пошла — продержитесь, пока поднимется решётка")
	elseif kind == "f4forgeCooled" and typeof(payload.position) == "Vector3" then
		smokePuff(payload.position + V3(0, 2, 0), C.steam, 30, 4)
		shockRing(payload.position, 30, C.gold, 1.2)
		sfx("ventHiss", payload.position)
	elseif kind == "f5bookfall" and typeof(payload.position) == "Vector3" then
		if payload.phase == "warn" then
			warnRing(payload.position, payload.radius or 2.8, C.rune, payload.duration or 1)
			bookFall(payload.position, payload.duration or 1)
			tipOnce("bookfall", "С полок падают книги — уходите из фиолетовых кругов")
		else
			burst(payload.position + V3(0, 0.4, 0), 16, { C.paper, C.paperDark, C.inkGloss }, 0.26, 12, 1, payload.position.Y)
			smokePuff(payload.position + V3(0, 0.5, 0), C.paperDark, 6, 1.2)
			sfx("breakPaper", payload.position)
			shake(0.12, 0.15)
		end
	elseif kind == "f5bind" and type(payload.points) == "table" then
		for _, p in ipairs(payload.points) do
			if typeof(p) == "Vector3" then
				burst(p + V3(0, 0.4, 0), 14, { C.ink, C.inkGloss, C.rune }, 0.24, 12, 0.9, p.Y)
			end
		end
		sfx("inkSplash", payload.position)
	elseif kind == "f5seals" then
		if type(payload.positions) == "table" then
			for _, p in ipairs(payload.positions) do
				if typeof(p) == "Vector3" then
					shockRing(p, 5, C.rune, 0.6)
				end
			end
		end
		sfx("sealHum")
		banner("Главный хронист", "Четыре печати держат его — разбейте их")
	elseif kind == "f5sealsDown" and typeof(payload.position) == "Vector3" then
		sparks(payload.position + V3(0, 4, 0), C.frost, 40, 22)
		shockRing(payload.position, 10, C.frost, 0.6)
		sfx("sealShatter", payload.position)
		notify("Печати разбиты — Хронист оглушён!")
	elseif kind == "f5erasure" then
		if payload.phase == "start" then
			shake(0.2, 0.6)
		end
	elseif kind == "f5vault" then
		sfx("vaultOpen", payload.position)
		banner("Купол хроник", "Ворота за куполом открылись")
	elseif kind == "f5epilogue" then
		epilogue(payload)
	end
end

local function step(dt: number)
	stepEnemies()
	stepPuddles()
	stepDebris(dt)
	stepCart()
	if onFloor45() then
		stepPlayers(dt)
	end
	stepErasure(dt)
end

function Floor45Fx.start()
	folder()
	local remote = Net.get("EnemyEvent")
	if remote then
		remote.OnClientEvent:Connect(onEnemyEvent)
	end
	local floorRemote = Net.get("FloorEvent")
	if floorRemote then
		floorRemote.OnClientEvent:Connect(onMapEvent)
	end
	-- Ушёл с этажа — убрать лужи и вагонетку.
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		if not onFloor45() then
			clearPuddles()
			if cart and cart.model then
				cart.model:Destroy()
			end
			cart = nil
		end
	end)
	Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			task.defer(track, d)
		end
	end)
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("Model") then
			track(d)
		end
	end
	RunService.Heartbeat:Connect(step)
	print("[Floor45Fx] эффекты этажей 4–5")
end

return Floor45Fx
