--!nonstrict
-- Floor2Fx (клиент)
-- Эффекты врагов этажа 2 «Затопленные сады» (28.10.2026). Логики нет — только
-- картинка и звук по атрибутам и событиям Floor2Service (EnemyEvent, kind f2*).
--
--   лужи         тина (замедляет) и гниль (жжёт): диски на полу, пузыри
--   полив        конус на земле (замах — красный, полив — гнилой), струя
--                капель из лейки садовника
--   корни        древесный страж: шипы корней из кругов; Садовница: три
--                линии (полосы в замахе, корни бегут по ним при ударе)
--   кора         щепки, когда удар спереди вязнет в коре стража
--   следопыт     листва при отскоке, камуфляж (почти невидим в покое)
--   цветение     Садовница, III фаза: сжимающийся круг лепестков
--   статусы      на игроках: корни на ногах, пузыри гнили, капли тины;
--                своему — оттенок экрана и подсказки
--
--   карта        (FloorEvent от Floor2World) вентили и маяки, шлюз, тайники,
--                гнилые доски, пролёт акведука, струи фонтана, споры, статуи
--
-- Все временные детали — в Workspace.Floor2Fx; число живых осколков
-- ограничено (DEBRIS_MAX), дальние эффекты (> 90 стад) не рисуются.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local Palette = require(Shared.Config.Palette)

local Bus = require(script.Parent.Parent.Lib.Bus)
local TEX = require(script.Parent.Parent.Lib.FxTex)
local EnemyVisualController = require(script.Parent.EnemyVisualController)

local Floor2Fx = {}

local V = Palette.Voxel
local V3 = Vector3.new
local rgb = Color3.fromRGB
local TAU = math.pi * 2
local FAR_FX = 90
local DEBRIS_MAX = 260

local C = {
	danger = V.X,
	mud = rgb(90, 74, 46),
	mudDark = rgb(58, 47, 30),
	mudWet = rgb(120, 104, 62),
	rot = rgb(92, 58, 110),
	rotDark = rgb(58, 34, 72),
	rotGlow = rgb(166, 224, 90),
	bark = rgb(92, 64, 40),
	barkLight = rgb(140, 104, 64),
	root = rgb(74, 52, 32),
	rootMoss = rgb(98, 120, 44),
	leaf = rgb(96, 140, 52),
	leafDark = rgb(58, 92, 36),
	petal = rgb(255, 92, 140),
	honey = rgb(224, 165, 58),
	honeyDark = rgb(168, 112, 30),
	honeyLight = rgb(242, 196, 107),
	sporeGlow = rgb(199, 123, 232),
	water = rgb(95, 208, 192), -- #5FD0C0, бирюза этажа 2
	petalDark = rgb(170, 40, 90),
	bloomRim = rgb(124, 242, 176),
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

local folderRef
local function folder()
	if folderRef and folderRef.Parent then
		return folderRef
	end
	folderRef = Workspace:FindFirstChild("Floor2Fx")
	if not folderRef then
		folderRef = Instance.new("Folder")
		folderRef.Name = "Floor2Fx"
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

-- Диск на полу (цилиндр, ось X вверх).
local DISC_TURN = CFrame.Angles(0, 0, math.rad(90))
local function discCFrame(center: Vector3, lift: number): CFrame
	return CFrame.new(center + V3(0, lift, 0)) * DISC_TURN
end

local function near(position: Vector3): boolean
	local camera = Workspace.CurrentCamera
	return camera == nil or (camera.CFrame.Position - position).Magnitude < FAR_FX
end

local function flat(v: Vector3): Vector3
	return V3(v.X, 0, v.Z)
end

-- Треугольник из двух клиньев (конус полива).
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

-- ===== Осколки, капли, листья =====

local debris = {}

local function spawnBit(position: Vector3, velocity: Vector3, color: Color3, size: number, life: number, neon: boolean?, floorY: number?)
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
	})
end

local function burst(position: Vector3, count: number, colors, size: number, speed: number, up: number?, floorY: number?)
	if not near(position) then
		return
	end
	for _ = 1, count do
		local color = colors[random:NextInteger(1, #colors)]
		local s = size * random:NextNumber(0.6, 1.3)
		local v = V3(random:NextNumber(-1, 1) * speed * 0.5, random:NextNumber(0.3, 1) * speed * (up or 1), random:NextNumber(-1, 1) * speed * 0.5)
		spawnBit(position + V3(random:NextNumber(-0.3, 0.3), random:NextNumber(0, 0.3), random:NextNumber(-0.3, 0.3)), v, color, s, random:NextNumber(0.5, 1.1), false, floorY)
	end
end

local function stepDebris(dt: number)
	for index = #debris, 1, -1 do
		local d = debris[index]
		d.age += dt
		d.velocity += V3(0, -50 * dt, 0)
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

-- ===== Шипы корней =====

local spikes = {} -- { part, base, top, born, riseT, holdUntil, sinkT }

-- Корень: клин остриём вверх, вырастает за riseT и уходит в землю через hold.
local function rootSpike(ground: Vector3, height: number, width: number, delay: number, hold: number, lean: Vector3?)
	if not near(ground) then
		return
	end
	local p = part({
		Name = "Root",
		Size = V3(width, height, width * 1.4),
		Color = random:NextNumber() < 0.3 and C.rootMoss or C.root,
		Material = Enum.Material.Wood,
	}, "WedgePart")
	local yaw = random:NextNumber() * TAU
	local tilt = lean or V3(random:NextNumber(-0.25, 0.25), 0, random:NextNumber(-0.25, 0.25))
	local frame = CFrame.new(ground) * CFrame.Angles(tilt.X, yaw, tilt.Z)
	p.CFrame = frame * CFrame.new(0, -height, 0)
	table.insert(spikes, {
		part = p,
		frame = frame,
		height = height,
		born = os.clock() + delay,
		riseT = 0.12,
		holdUntil = os.clock() + delay + 0.12 + hold,
		sinkT = 0.35,
	})
end

local function stepSpikes()
	local now = os.clock()
	for index = #spikes, 1, -1 do
		local s = spikes[index]
		local y
		if now < s.born then
			y = -s.height
		elseif now < s.born + s.riseT then
			local k = (now - s.born) / s.riseT
			y = -s.height * (1 - k) ^ 2 + s.height * 0.5 * math.sin(k * math.pi) * 0.15
		elseif now < s.holdUntil then
			y = 0
		else
			local k = (now - s.holdUntil) / s.sinkT
			if k >= 1 then
				s.part:Destroy()
				table.remove(spikes, index)
				continue
			end
			y = -s.height * k
		end
		s.part.CFrame = s.frame * CFrame.new(0, s.height / 2 + y, 0)
	end
end

-- Корни древесного стража: венец шипов вокруг круга и толстые в центре.
local function rootsEruption(center: Vector3, radius: number, hold: number)
	for index = 1, 9 do
		local angle = index / 9 * TAU + random:NextNumber(-0.2, 0.2)
		local r = radius * random:NextNumber(0.55, 0.95)
		local ground = center + V3(math.cos(angle) * r, 0, math.sin(angle) * r)
		-- Наклон внутрь круга: корни смыкаются над целью.
		local lean = V3(math.sin(angle) * -0.35, 0, math.cos(angle) * 0.35)
		rootSpike(ground, random:NextNumber(1.6, 2.6), random:NextNumber(0.3, 0.5), random:NextNumber(0, 0.08), hold, lean)
	end
	for _ = 1, 3 do
		local ground = center + V3(random:NextNumber(-0.6, 0.6), 0, random:NextNumber(-0.6, 0.6))
		rootSpike(ground, random:NextNumber(2.4, 3.2), random:NextNumber(0.45, 0.65), 0.04, hold)
	end
	burst(center + V3(0, 0.2, 0), 16, { C.mud, C.mudDark, C.root }, 0.22, 16, 1, center.Y)
end

-- ===== Лужи =====

local puddles = {} -- [id] = puddle

local PUDDLE_STYLE = {
	mud = { base = C.mud, inner = C.mudDark, rim = C.mudWet, rimNeon = false, bubble = C.mudWet },
	rot = { base = C.rot, inner = C.rotDark, rim = C.rotGlow, rimNeon = true, bubble = C.rotGlow, glow = true },
	honey = { base = C.honey, inner = C.honeyDark, rim = C.honeyLight, rimNeon = false, bubble = C.honeyLight, glow = true },
	spore = { base = C.rotDark, inner = C.rot, rim = C.sporeGlow, rimNeon = true, bubble = C.sporeGlow, glow = true, cloud = true },
	water = { invisible = true }, -- мелкая вода купальни: видна в карте
}

-- Частицы лужи: пузыри (свечение), дымка над гнилью, облако спор.
local function puddleFx(center: Vector3, radius: number, style)
	local anchor = part({ Name = "PuddleFx", Size = V3(radius * 1.6, 0.4, radius * 1.6), Transparency = 1, CFrame = CFrame.new(center + V3(0, 0.3, 0)) })
	local items = {}
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = TEX.glow
	bubbles.Color = ColorSequence.new(style.bubble)
	bubbles.LightEmission = style.glow and 1 or 0.2
	bubbles.LightInfluence = style.glow and 0 or 1
	bubbles.Rate = math.clamp(radius * radius * 0.9, 3, 18)
	bubbles.Lifetime = NumberRange.new(0.7, 1.4)
	bubbles.Speed = NumberRange.new(0.6, 1.6)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.SpreadAngle = Vector2.new(12, 12)
	bubbles.Shape = Enum.ParticleEmitterShape.Box
	bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 0) })
	bubbles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.3, 0.1), NumberSequenceKeypoint.new(1, 0.9) })
	bubbles.Parent = anchor
	table.insert(items, bubbles)
	if style.glow then
		local haze = Instance.new("ParticleEmitter")
		haze.Texture = TEX.smoke
		haze.Color = ColorSequence.new(style.cloud and C.sporeGlow or style.base)
		haze.LightEmission = 0.3
		haze.Rate = style.cloud and 14 or 2
		haze.Lifetime = NumberRange.new(style.cloud and 1.6 or 2.5, style.cloud and 2.4 or 3.5)
		haze.Speed = NumberRange.new(0.3, style.cloud and 2.5 or 0.8)
		haze.SpreadAngle = Vector2.new(style.cloud and 180 or 30, style.cloud and 180 or 30)
		haze.Shape = Enum.ParticleEmitterShape.Box
		haze.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, radius * 0.5), NumberSequenceKeypoint.new(1, radius * (style.cloud and 1.4 or 0.9)) })
		haze.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, style.cloud and 0.55 or 0.85), NumberSequenceKeypoint.new(1, 1) })
		haze.Rotation = NumberRange.new(0, 360)
		haze.RotSpeed = NumberRange.new(-20, 20)
		haze.Parent = anchor
		table.insert(items, haze)
	end
	return anchor, items
end

local function addPuddle(id: number, kind: string, center: Vector3, radius: number, life: number)
	local style = PUDDLE_STYLE[kind] or PUDDLE_STYLE.mud
	if style.invisible then
		return
	end
	if puddles[id] then
		return
	end
	local base = part({ Name = "Puddle", Shape = Enum.PartType.Cylinder, Color = style.base, Transparency = 0.15, Size = V3(0.08, 0.2, 0.2) })
	local inner = part({ Name = "PuddleInner", Shape = Enum.PartType.Cylinder, Color = style.inner, Transparency = 0.25, Size = V3(0.08, 0.2, 0.2) })
	local rim = part({
		Name = "PuddleRim",
		Shape = Enum.PartType.Cylinder,
		Color = style.rim,
		Material = style.rimNeon and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		Transparency = style.rimNeon and 0.75 or 0.5,
		Size = V3(0.06, 0.2, 0.2),
	})
	-- Пятна-блобы по краю: лужа не идеальный круг.
	local blobs = {}
	for index = 1, 5 do
		local angle = index / 5 * TAU + random:NextNumber(-0.4, 0.4)
		table.insert(blobs, {
			part = part({ Name = "Blob", Shape = Enum.PartType.Cylinder, Color = style.base, Transparency = 0.15, Size = V3(0.08, 0.2, 0.2) }),
			angle = angle,
			r = random:NextNumber(0.6, 0.85),
			size = random:NextNumber(0.35, 0.55),
		})
	end
	puddles[id] = {
		kind = kind,
		style = style,
		center = center,
		radius = radius,
		born = os.clock(),
		untilT = os.clock() + life,
		base = base,
		inner = inner,
		rim = rim,
		blobs = blobs,
		nextBubble = 0,
	}
	puddles[id].fx, puddles[id].fxItems = puddleFx(center, radius, style)
	if near(center) then
		burst(center + V3(0, 0.3, 0), 10, { style.base, style.inner }, 0.2, 10, 0.8, center.Y)
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
		local fade = math.clamp((p.untilT - now) / 0.8, 0, 1)
		local r = p.radius * grow * (0.85 + 0.15 * fade)
		local d = math.max(r * 2, 0.2)
		p.base.Size = V3(0.08, d, d)
		p.base.CFrame = discCFrame(p.center, 0.05)
		p.base.Transparency = 1 - 0.85 * fade
		p.inner.Size = V3(0.08, d * 0.62, d * 0.62)
		p.inner.CFrame = discCFrame(p.center, 0.07)
		p.inner.Transparency = 1 - 0.75 * fade
		p.rim.Size = V3(0.06, d * 1.06, d * 1.06)
		p.rim.CFrame = discCFrame(p.center, 0.03)
		local pulse = p.style.rimNeon and (0.08 * math.sin(now * 3 + p.center.X)) or 0
		p.rim.Transparency = 1 - (1 - (p.style.rimNeon and 0.75 or 0.5) + pulse) * fade
		for _, blob in ipairs(p.blobs) do
			local bd = math.max(r * blob.size * 2, 0.2)
			local pos = p.center + V3(math.cos(blob.angle) * r * blob.r, 0, math.sin(blob.angle) * r * blob.r)
			blob.part.Size = V3(0.08, bd, bd)
			blob.part.CFrame = discCFrame(pos, 0.05)
			blob.part.Transparency = 1 - 0.85 * fade
		end
		-- Частицы: только рядом с камерой и пока лужа не высыхает.
		if now >= p.nextBubble then
			p.nextBubble = now + 0.5
			local on = near(p.center) and fade > 0.3
			for _, item in ipairs(p.fxItems or {}) do
				item.Enabled = on
			end
		end
	end
end

local function clearPuddles()
	for id in pairs(puddles) do
		removePuddle(id)
	end
end

-- ===== Враги этажа 2: конус полива, линии корней, цветение, камуфляж =====

local tracked = {} -- [serverModel] = entry

local function rigPose(model)
	local rig = EnemyVisualController.rigOf(model)
	if rig and rig.pos then
		return rig.pos, rig.facing, rig
	end
	local root = model:FindFirstChild("Root") or model.PrimaryPart
	if not root then
		return nil
	end
	local height = model:GetAttribute("EnemyHeight") or 5
	local look = flat(root.CFrame.LookVector)
	return root.Position - V3(0, height / 2, 0), look.Magnitude > 0.01 and look.Unit or V3(0, 0, -1), nil
end

-- Конус: веер из CONE_SLICES треугольников.
local CONE_SLICES = 7

local function ensureCone(entry)
	if entry.cone then
		return entry.cone
	end
	local cone = { wedges = {}, rim = {} }
	for _ = 1, CONE_SLICES * 2 do
		table.insert(cone.wedges, part({ Name = "Cone", Material = Enum.Material.Neon, Color = C.danger, Transparency = 0.75 }, "WedgePart"))
	end
	for _ = 1, CONE_SLICES do
		table.insert(cone.rim, part({ Name = "ConeRim", Material = Enum.Material.Neon, Color = C.danger, Transparency = 0.35, Size = V3(0.12, 0.06, 1) }))
	end
	entry.cone = cone
	return cone
end

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

local function drawCone(entry, model, spec: string, pouring: boolean, progress: number)
	local angleText, lengthText = string.match(spec, "^([%d%.]+),([%d%.]+)$")
	local coneAngle, length = tonumber(angleText), tonumber(lengthText)
	if not coneAngle or not length then
		return
	end
	local feet, facing = rigPose(model)
	if not feet then
		return
	end
	local dir = entry.pourDir or facing
	local cone = ensureCone(entry)
	local origin = feet + V3(0, 0.1, 0)
	-- В замахе конус «наливается» от лейки до полной длины.
	local reach = pouring and length or length * (0.35 + 0.65 * math.clamp(progress, 0, 1))
	local half = math.rad(coneAngle / 2)
	local color = pouring and C.rotGlow or C.danger
	local transparency = pouring and (0.7 + 0.06 * math.sin(os.clock() * 10)) or (0.82 - 0.2 * progress)
	local points = {}
	for index = 0, CONE_SLICES do
		local a = -half + (index / CONE_SLICES) * half * 2
		local d = CFrame.Angles(0, a, 0):VectorToWorldSpace(dir)
		table.insert(points, origin + d * reach)
	end
	for index = 1, CONE_SLICES do
		local w1, w2 = cone.wedges[index * 2 - 1], cone.wedges[index * 2]
		triangle(origin, points[index], points[index + 1], w1, w2, 0.05)
		w1.Color, w2.Color = color, color
		w1.Transparency, w2.Transparency = transparency, transparency
		local a, b = points[index], points[index + 1]
		local rim = cone.rim[index]
		rim.Color = color
		rim.Size = V3(0.14, 0.07, (b - a).Magnitude)
		rim.CFrame = CFrame.lookAt((a + b) / 2 + V3(0, 0.02, 0), b + V3(0, 0.02, 0))
	end
end

-- Струя гнили из лейки: капли летят дугой в случайную точку конуса.
local function spout(model, rig, feet: Vector3, facing: Vector3): Vector3
	local visual = rig and rig.model
	local weapon = visual and visual:FindFirstChild("Weapon")
	local can = weapon and weapon:FindFirstChildWhichIsA("BasePart", true)
	if can then
		-- Носик — дальний по взгляду край лейки.
		local half = can.Size / 2
		local best, bestDot = can.Position, -math.huge
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local p = can.CFrame:PointToWorldSpace(V3(half.X * sx, half.Y * 0.4, half.Z * sz))
				local dot = (p - feet):Dot(facing)
				if dot > bestDot then
					best, bestDot = p, dot
				end
			end
		end
		return best
	end
	return feet + V3(0, (model:GetAttribute("EnemyHeight") or 5) * 0.5, 0) + facing * 1.2
end

local function stepPour(entry, model, dt: number)
	local pour = entry.pour
	if not pour then
		return
	end
	if os.clock() >= pour.untilT or not model.Parent then
		entry.pour = nil
		entry.pourDir = nil
		return
	end
	local feet, _, rig = rigPose(model)
	if not feet or not near(feet) then
		return
	end
	local dir = pour.dir
	local origin = spout(model, rig, feet, dir)
	pour.accum += dt * 38
	while pour.accum >= 1 do
		pour.accum -= 1
		local a = math.rad(random:NextNumber(-pour.cone / 2, pour.cone / 2))
		local d = CFrame.Angles(0, a, 0):VectorToWorldSpace(dir)
		local target = feet + d * random:NextNumber(1.2, pour.length)
		local flightT = random:NextNumber(0.35, 0.55)
		local delta = target - origin
		local v = V3(delta.X / flightT, (delta.Y + 25 * flightT * flightT) / flightT, delta.Z / flightT)
		local color = random:NextNumber() < 0.35 and C.rotGlow or (random:NextNumber() < 0.5 and C.rot or C.rotDark)
		spawnBit(origin, v, color, random:NextNumber(0.12, 0.2), flightT + 0.25, color == C.rotGlow, feet.Y + 0.05)
	end
	if os.clock() >= pour.nextSound then
		pour.nextSound = os.clock() + 0.6
		sfx("pourRot", feet)
	end
end

local LINE_COLOR = C.danger

local function hideLines(entry)
	for _, strip in ipairs(entry.lines or {}) do
		strip:Destroy()
	end
	entry.lines = nil
	entry.linesSpec = nil
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

local function drawLines(entry, model, progress: number)
	local spec = model:GetAttribute("F2Lines")
	local origin = model:GetAttribute("F2LinesOrigin")
	local width = model:GetAttribute("F2LinesWidth") or 1.6
	if type(spec) ~= "string" or typeof(origin) ~= "Vector3" then
		hideLines(entry)
		return
	end
	if entry.linesSpec ~= spec then
		hideLines(entry)
		entry.linesSpec = spec
		entry.linesData = parseLines(spec)
		entry.lines = {}
		for _ = 1, #entry.linesData do
			table.insert(entry.lines, part({ Name = "RootLine", Material = Enum.Material.Neon, Color = LINE_COLOR, Transparency = 0.7 }))
		end
	end
	local k = math.clamp(progress, 0, 1)
	for index, line in ipairs(entry.linesData) do
		local strip = entry.lines[index]
		local length = math.max(line.length * (0.15 + 0.85 * k), 0.2)
		local start = origin + V3(0, 0.12, 0) + line.dir * 1.2
		strip.Size = V3(width, 0.06, length)
		strip.CFrame = CFrame.lookAt(start + line.dir * length / 2, start + line.dir * (length + 1))
		strip.Transparency = 0.75 - 0.3 * k
	end
end

-- Корни бегут по линиям от Садовницы наружу.
local function rootLinesEruption(origin: Vector3, lines, width: number)
	for _, line in ipairs(lines) do
		local dir = flat(line.dir)
		if dir.Magnitude < 0.01 then
			continue
		end
		dir = dir.Unit
		local side = V3(-dir.Z, 0, dir.X)
		local count = math.floor(line.length / 1.1)
		for step = 1, count do
			local along = 1.2 + step * 1.1
			for _, offset in ipairs({ -0.35, 0.35 }) do
				local ground = origin + dir * along + side * (offset * width + random:NextNumber(-0.15, 0.15))
				rootSpike(ground, random:NextNumber(1.4, 2.4), random:NextNumber(0.3, 0.45), step * 0.025, 0.7)
			end
		end
		burst(origin + dir * (line.length * 0.5) + V3(0, 0.2, 0), 8, { C.mud, C.root }, 0.2, 12, 1, origin.Y)
	end
	sfx("rootsBurst", origin)
end

-- Цветение: круг лепестков сжимается к Садовнице.
local BLOOM_PETALS = 56

local function hideBloom(entry)
	for _, petal in ipairs(entry.bloomParts or {}) do
		petal:Destroy()
	end
	entry.bloomParts = nil
	entry.bloomSpec = nil
end

local function drawBloom(entry, model)
	local spec = model:GetAttribute("F2Bloom")
	if type(spec) ~= "string" then
		if entry.bloomParts then
			hideBloom(entry)
		end
		return
	end
	local values = {}
	for number in string.gmatch(spec, "[^,]+") do
		table.insert(values, tonumber(number))
	end
	if #values < 7 then
		return
	end
	local center = V3(values[1], values[2], values[3])
	local from, to, time, start = values[4], values[5], values[6], values[7]
	if entry.bloomSpec ~= spec then
		hideBloom(entry)
		entry.bloomSpec = spec
		entry.bloomParts = {}
		for index = 1, BLOOM_PETALS do
			local petal = part({
				Name = "Petal",
				Size = V3(0.5, 0.1, 0.8),
				Color = index % 3 == 0 and C.petalDark or C.petal,
				Material = Enum.Material.Neon,
				Transparency = 0.15,
			})
			table.insert(entry.bloomParts, petal)
		end
		-- Пограничная стена тумана: тонкое кольцо из сегментов.
		for _ = 1, BLOOM_PETALS do
			table.insert(entry.bloomParts, part({ Name = "BloomRim", Size = V3(0.12, 1.2, 1), Color = C.rot, Material = Enum.Material.Neon, Transparency = 0.6 }))
		end
	end
	local k = math.clamp((serverNow() - start) / time, 0, 1)
	local radius = from + (to - from) * k
	local now = os.clock()
	for index = 1, BLOOM_PETALS do
		local a = index / BLOOM_PETALS * TAU + now * 0.15
		local pos = center + V3(math.cos(a) * radius, 0.25 + 0.12 * math.sin(now * 3 + index), math.sin(a) * radius)
		local petal = entry.bloomParts[index]
		petal.CFrame = CFrame.lookAt(pos, center + V3(0, pos.Y - center.Y, 0)) * CFrame.Angles(math.rad(25), 0, math.rad(15 * math.sin(now * 2 + index)))
		local rim = entry.bloomParts[BLOOM_PETALS + index]
		local b = (index + 0.5) / BLOOM_PETALS * TAU + now * 0.15
		local segment = TAU * radius / BLOOM_PETALS * 1.05
		local rimPos = center + V3(math.cos(b) * (radius + 0.3), 0.6, math.sin(b) * (radius + 0.3))
		rim.Size = V3(0.12, 1.2 + 0.3 * math.sin(now * 4 + index * 0.7), segment)
		rim.CFrame = CFrame.lookAt(rimPos, rimPos + V3(-math.sin(b), 0, math.cos(b)))
	end
	-- Гнилые споры за кругом.
	if near(center) and random:NextNumber() < 0.5 then
		local a = random:NextNumber() * TAU
		local r = radius + random:NextNumber(0.5, 6)
		spawnBit(center + V3(math.cos(a) * r, 0.1, math.sin(a) * r), V3(0, random:NextNumber(1, 2.5), 0), C.rotGlow, 0.15, 0.9, true, center.Y)
	end
end

-- Камуфляж следопыта: тело тает до 0,7 (traits.camo), глаза — до 0,5.
local function stepCamo(entry, model, dt: number)
	local target = model:GetAttribute("F2Camo") == true and 1 or 0
	entry.camo = entry.camo or 0
	local speed = target > entry.camo and 1.5 or 6 -- проявляется быстро
	entry.camo += math.clamp(target - entry.camo, -speed * dt, speed * dt)
	local rig = EnemyVisualController.rigOf(model)
	if not rig or not rig.model then
		return
	end
	if entry.camoModel ~= rig.model then
		entry.camoModel = rig.model
		entry.camoParts = {}
		for _, d in ipairs(rig.model:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
				local glow = d.Parent and d.Parent.Name == "Glow"
				table.insert(entry.camoParts, { part = d, max = glow and 0.5 or 0.7 })
			end
		end
		entry.camoApplied = nil
	end
	local value = entry.camo
	if entry.camoApplied and math.abs(entry.camoApplied - value) < 0.01 then
		return
	end
	entry.camoApplied = value
	for _, item in ipairs(entry.camoParts) do
		if item.part.Parent then
			item.part.LocalTransparencyModifier = item.max * value
		end
	end
end

local function untrack(model)
	local entry = tracked[model]
	if not entry then
		return
	end
	tracked[model] = nil
	hideCone(entry)
	hideLines(entry)
	hideBloom(entry)
end

local FLOOR2_TYPES = { treant = true, bee = true, drowned = true, gardener = true, ranger = true, rosewarden = true }

local function track(instance)
	if tracked[instance] or not instance:IsA("Model") then
		return
	end
	local typeId = instance:GetAttribute("EnemyType")
	if not FLOOR2_TYPES[typeId] then
		return
	end
	tracked[instance] = { typeId = typeId }
	instance.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			untrack(instance)
		end
	end)
end

local function stepEnemies(dt: number)
	local now = serverNow()
	for model, entry in pairs(tracked) do
		if not model.Parent then
			untrack(model)
			continue
		end
		local typeId = entry.typeId
		if typeId == "gardener" then
			local spec = model:GetAttribute("F2Cone")
			local state = model:GetAttribute("EnemyState")
			if type(spec) == "string" and (state == "windup" or state == "strike") then
				local progress = 1
				if state == "windup" then
					local at = model:GetAttribute("EnemyStateAt") or now
					local dur = model:GetAttribute("EnemyStateDur") or 1
					progress = (now - at) / math.max(dur, 0.05)
				end
				drawCone(entry, model, spec, state == "strike", progress)
			elseif entry.cone then
				hideCone(entry)
			end
			stepPour(entry, model, dt)
		elseif typeId == "ranger" then
			stepCamo(entry, model, dt)
		elseif typeId == "rosewarden" then
			if model:GetAttribute("EnemyState") == "windup" and model:GetAttribute("F2Lines") then
				local at = model:GetAttribute("EnemyStateAt") or now
				local dur = model:GetAttribute("EnemyStateDur") or 1
				drawLines(entry, model, (now - at) / math.max(dur, 0.05))
			elseif entry.lines then
				hideLines(entry)
			end
			drawBloom(entry, model)
		end
	end
end

-- ===== Статусы игроков =====

local playerFx = {} -- [player] = { roots = {parts}, nextBubble, nextDrip }
local poisonTint
local tipsShown: { [string]: boolean } = {}

local function rootsOn(entry, root: BasePart)
	if entry.roots then
		return
	end
	entry.roots = {}
	local feet = root.Position - V3(0, 3, 0)
	for index = 1, 6 do
		local a = index / 6 * TAU
		local ground = feet + V3(math.cos(a) * 0.9, 0, math.sin(a) * 0.9)
		local p = part({ Name = "LegRoot", Size = V3(0.35, 2.2, 0.5), Color = index % 2 == 0 and C.rootMoss or C.root, Material = Enum.Material.Wood }, "WedgePart")
		-- Наклон к ногам: корни обвивают голени.
		local frame = CFrame.new(ground) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(0, 0, math.rad(-22))
		table.insert(entry.roots, { part = p, frame = frame, born = os.clock() })
	end
	burst(feet + V3(0, 0.2, 0), 10, { C.mud, C.root }, 0.18, 10, 1, feet.Y)
end

local function rootsOff(entry)
	for _, r in ipairs(entry.roots or {}) do
		r.part:Destroy()
	end
	entry.roots = nil
end

local function stepPlayers(dt: number)
	local now = serverNow()
	local clock = os.clock()
	local localPoison = false
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local entry = playerFx[other]
		if not entry then
			entry = { nextBubble = 0, nextDrip = 0, nextTick = 0 }
			playerFx[other] = entry
		end
		if not root then
			rootsOff(entry)
			continue
		end
		-- Окаменевшего («Мраморный взгляд») держит камень, а не лозы (BossMovesFx).
		local rooted = now < (other:GetAttribute("RootedUntil") or 0) and now >= (other:GetAttribute("PetrifiedUntil") or 0)
		local poisoned = now < (other:GetAttribute("PoisonUntil") or 0)
		local slowed = now < (other:GetAttribute("SlowUntil") or 0)
		if rooted then
			rootsOn(entry, root)
			for _, r in ipairs(entry.roots) do
				local k = math.clamp((clock - r.born) / 0.15, 0, 1)
				r.part.CFrame = r.frame * CFrame.new(0, -1.1 + 1.1 * k, 0)
			end
			if other == player and not entry.wasRooted then
				sfx("rootsBurst", root.Position)
			end
		elseif entry.roots then
			rootsOff(entry)
		end
		entry.wasRooted = rooted
		if poisoned and clock >= entry.nextBubble and near(root.Position) then
			entry.nextBubble = clock + 0.12
			local pos = root.Position + V3(random:NextNumber(-0.8, 0.8), random:NextNumber(-1.5, 1), random:NextNumber(-0.8, 0.8))
			spawnBit(pos, V3(0, random:NextNumber(2, 4), 0), random:NextNumber() < 0.5 and C.rotGlow or C.rot, random:NextNumber(0.1, 0.2), 0.5, true, pos.Y - 5)
		end
		if slowed and clock >= entry.nextDrip and near(root.Position) then
			entry.nextDrip = clock + 0.18
			local pos = root.Position + V3(random:NextNumber(-0.6, 0.6), -1.5, random:NextNumber(-0.6, 0.6))
			spawnBit(pos, V3(0, -1, 0), C.mud, random:NextNumber(0.12, 0.2), 0.5, false, root.Position.Y - 3)
		end
		if other == player then
			localPoison = poisoned
			if poisoned and clock >= entry.nextTick then
				entry.nextTick = clock + 0.5
				sfx("poisonTick")
			end
			if rooted and not tipsShown.root then
				tipsShown.root = true
				notify("Корни держат! Переждите — или уклоняйтесь от кругов заранее")
			end
			if poisoned and not tipsShown.poison then
				tipsShown.poison = true
				notify("Гниль жжёт, пока вы в ней. Не убивает, но оставит без сил")
			end
		end
	end
	for other, entry in pairs(playerFx) do
		if not other.Parent then
			rootsOff(entry)
			playerFx[other] = nil
		end
	end
	-- Оттенок экрана у отравленного.
	if not poisonTint then
		poisonTint = Instance.new("ColorCorrectionEffect")
		poisonTint.Name = "Floor2Poison"
		poisonTint.Enabled = false
		poisonTint.Parent = Lighting
	end
	local target = localPoison and 1 or 0
	local current = poisonTint:GetAttribute("K") or 0
	current += math.clamp(target - current, -dt * 3, dt * 3)
	poisonTint:SetAttribute("K", current)
	poisonTint.Enabled = current > 0.01
	if poisonTint.Enabled then
		poisonTint.TintColor = Color3.new(1, 1, 1):Lerp(rgb(214, 236, 190), current)
		poisonTint.Saturation = -0.15 * current
	end
end

-- ===== События сервера =====

local function rootOf(model)
	return model and (model:FindFirstChild("Root") or model.PrimaryPart)
end

local function onEnemyEvent(payload)
	if type(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	if kind == "f2hazard" and typeof(payload.position) == "Vector3" then
		addPuddle(payload.id, payload.hazard, payload.position, payload.radius or 3, payload.life or 5)
		if payload.hazard == "mud" then
			sfx("mudSplash", payload.position)
		end
	elseif kind == "f2hazardClear" then
		clearPuddles()
	elseif kind == "f2bark" and typeof(payload.position) == "Vector3" then
		burst(payload.position, 12, { C.bark, C.barkLight, C.rootMoss }, 0.18, 14, 0.8)
		sfx("barkBlock", payload.position)
	elseif kind == "f2hop" then
		local root = rootOf(payload.model)
		if root then
			burst(root.Position, 14, { C.leaf, C.leafDark }, 0.2, 10, 0.6)
			sfx("rangerHop", root.Position)
		end
	elseif kind == "f2pour" and payload.model then
		local entry = tracked[payload.model]
		if entry and typeof(payload.direction) == "Vector3" then
			entry.pourDir = flat(payload.direction).Unit
			entry.pour = {
				dir = entry.pourDir,
				cone = payload.cone or 70,
				length = payload.length or 9,
				untilT = os.clock() + (payload.duration or 3),
				accum = 0,
				nextSound = 0,
			}
		end
	elseif kind == "f2pourStop" and payload.model then
		local entry = tracked[payload.model]
		if entry then
			entry.pour = nil
			entry.pourDir = nil
		end
	elseif kind == "f2rootLines" and typeof(payload.origin) == "Vector3" and type(payload.lines) == "table" then
		rootLinesEruption(payload.origin, payload.lines, payload.width or 1.6)
	elseif kind == "f2bloom" then
		sfx("bloom", typeof(payload.center) == "Vector3" and payload.center or nil)
		notify("Цветение! Гниль снаружи круга — держитесь ближе к Садовнице")
	elseif kind == "area" and payload.attack == "roots" then
		local hold = 1.2
		for _, center in ipairs(type(payload.positions) == "table" and payload.positions or { payload.position }) do
			if typeof(center) == "Vector3" then
				rootsEruption(center, payload.radius or 2.6, hold)
			end
		end
		sfx("rootsBurst", payload.position)
	elseif kind == "area" and payload.attack == "mudThrow" and typeof(payload.position) == "Vector3" then
		burst(payload.position + V3(0, 0.3, 0), 22, { C.mud, C.mudDark, C.mudWet }, 0.24, 18, 0.9, payload.position.Y)
	elseif kind == "area" and payload.attack == "thornRing" then
		local root = rootOf(payload.model)
		local center = typeof(payload.position) == "Vector3" and payload.position or (root and root.Position)
		if center then
			local radius = payload.radius or 6
			for index = 1, 16 do
				local a = index / 16 * TAU
				rootSpike(center + V3(math.cos(a) * radius * 0.8, 0, math.sin(a) * radius * 0.8), random:NextNumber(1.2, 2), 0.35, index * 0.01, 0.35)
			end
			sfx("rootsBurst", center)
		end
	elseif kind == "phase2" and payload.model and tracked[payload.model] and tracked[payload.model].typeId == "rosewarden" then
		local root = rootOf(payload.model)
		if root then
			burst(root.Position + V3(0, 2, 0), 30, { rgb(214, 210, 200), rgb(170, 166, 158), C.bloomRim }, 0.25, 18, 1)
			sfx("statueCrack", root.Position)
		end
	end
end

-- ===== Карта этажа 2: шлюзы, тайники, ловушки (FloorEvent от Floor2World) =====

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

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

-- Эмиттер на невидимой опоре. o: tex, color(Color3|ColorSequence), size(NumberSequence),
-- transp, life{a,b}, speed{a,b}, spread, accel, drag, light, rate, emit, box(Vector3), rot, lockedToPart.
local function emitter(position: Vector3, o, duration: number?)
	local anchor = part({ Name = "MapFx", Size = o.box or V3(0.2, 0.2, 0.2), Transparency = 1, CFrame = o.cframe or CFrame.new(position) })
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
	Debris:AddItem(anchor, (duration or 0) + (o.life and o.life[2] or 1.2) + 0.2)
	return anchor, e
end

-- Предупреждающее кольцо на полу: растёт к сроку срабатывания.
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

local function banner(top: string?, text: string)
	Bus.emit("banner", { top = top, text = text })
end

-- Маяки над вентилями, которые можно крутить: [id] = anchor.
local beacons = {}

local function clearBeacon(id)
	if beacons[id] then
		beacons[id]:Destroy()
		beacons[id] = nil
	end
end

local function valveBeacon(id, position: Vector3)
	clearBeacon(id)
	local anchor = part({ Name = "ValveBeacon", Size = V3(2, 0.2, 2), Transparency = 1, CFrame = CFrame.new(position + V3(0, 0.5, 0)) })
	local column = Instance.new("ParticleEmitter")
	column.Texture = TEX.glow
	column.Color = cseq(C.water, Color3.new(1, 1, 1))
	column.LightEmission = 1
	column.LightInfluence = 0
	column.Rate = 10
	column.Lifetime = NumberRange.new(1.6, 2.4)
	column.Speed = NumberRange.new(3, 5)
	column.SpreadAngle = Vector2.new(4, 4)
	column.Shape = Enum.ParticleEmitterShape.Box
	column.Size = nseq({ { 0, 0.4 }, { 0.5, 0.7 }, { 1, 0 } })
	column.Transparency = nseq({ { 0, 1 }, { 0.2, 0.3 }, { 1, 1 } })
	column.Parent = anchor
	local ring = Instance.new("ParticleEmitter")
	ring.Texture = TEX.ring
	ring.Color = cseq(C.water)
	ring.LightEmission = 1
	ring.LightInfluence = 0
	ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ring.EmissionDirection = Enum.NormalId.Top
	ring.Rate = 0.8
	ring.Lifetime = NumberRange.new(1.5)
	ring.Speed = NumberRange.new(0.01)
	ring.Size = nseq({ { 0, 1 }, { 1, 6 } })
	ring.Transparency = nseq({ { 0, 0.3 }, { 1, 1 } })
	ring.Parent = anchor
	local light = Instance.new("PointLight")
	light.Color = C.water
	light.Range = 14
	light.Brightness = 1.6
	light.Parent = anchor
	beacons[id] = anchor
end

local function waterBurst(position: Vector3, scale: number)
	emitter(position, {
		tex = TEX.smoke, color = cseq(Color3.new(1, 1, 1), C.water), emit = math.floor(18 * scale),
		size = nseq({ { 0, 0.8 * scale }, { 1, 2.6 * scale } }), transp = nseq({ { 0, 0.3 }, { 1, 1 } }),
		life = { 0.6, 1.1 }, speed = { 6 * scale, 14 * scale }, spread = 50, accel = V3(0, -30, 0), drag = 2, light = 0.3,
	})
	emitter(position, {
		tex = TEX.glow, color = cseq(C.water), emit = math.floor(24 * scale),
		size = nseq({ { 0, 0.35 }, { 1, 0.1 } }), transp = nseq({ { 0, 0 }, { 1, 1 } }),
		life = { 0.5, 1 }, speed = { 8 * scale, 18 * scale }, spread = 40, accel = V3(0, -50, 0), light = 1,
	})
end

local function onMapEvent(payload)
	if type(payload) ~= "table" or type(payload.kind) ~= "string" or payload.kind:sub(1, 2) ~= "f2" then
		return
	end
	local kind = payload.kind
	local pos = typeof(payload.position) == "Vector3" and payload.position or nil
	if kind == "f2valve" then
		clearBeacon(payload.id)
		if pos then
			waterBurst(pos + V3(0, 1, 0), 1)
			emitter(pos + V3(0, 0.2, 0), {
				tex = TEX.ring, color = cseq(C.water), emit = 3, dir = Enum.NormalId.Top,
				size = nseq({ { 0, 1 }, { 1, 14 } }), transp = nseq({ { 0, 0.2 }, { 1, 1 } }), life = { 0.9, 1.3 }, speed = { 0.01, 0.02 }, light = 1,
			})
			sfx("valveTurn", pos)
		end
		local count, total = payload.count or 0, payload.total or 3
		if count >= total then
			banner("Все вентили повёрнуты", "Шлюз розария поднимается")
		else
			banner(("Вентиль %d/%d"):format(count, total), "Вода во дворе опускается")
		end
	elseif kind == "f2valveReady" then
		if pos then
			valveBeacon(payload.id, pos)
			sfx("valveReady", pos)
		end
		notify("Вентиль освободился — поверните его [E]")
	elseif kind == "f2sluice" then
		if pos then
			waterBurst(pos, 2)
			emitter(pos, {
				tex = TEX.smoke, color = cseq(C.leaf), emit = 20, box = V3(14, 1, 2),
				size = nseq({ { 0, 2 }, { 1, 5 } }), transp = nseq({ { 0, 0.5 }, { 1, 1 } }), life = { 1.5, 2.5 }, speed = { 1, 3 }, spread = 60, light = 0.2,
			})
			sfx("sluiceOpen", pos)
		end
		if payload.open then
			banner("Шлюз открыт", "Розарий ждёт")
		end
	elseif kind == "f2secret" then
		if pos then
			burst(pos + V3(0, 2, 0), 26, { C.leaf, C.leafDark, C.rootMoss }, 0.3, 18, 0.8)
			emitter(pos + V3(0, 2, 0), {
				tex = TEX.star, color = cseq(rgb(255, 230, 150), C.water), emit = 26, box = V3(6, 4, 1),
				size = nseq({ { 0, 0.6 }, { 1, 0 } }), transp = nseq({ { 0, 0 }, { 1, 1 } }), life = { 0.8, 1.6 }, speed = { 2, 7 }, spread = 180, drag = 1.5, light = 1,
			})
			sfx("secretFound", pos)
		end
		banner("Тайник", payload.name or "Тайная комната")
	elseif kind == "f2plank" and pos then
		if payload.phase == "crack" then
			burst(pos, 6, { C.bark, C.barkLight }, 0.14, 6, 0.6)
			emitter(pos, { tex = TEX.smoke, color = cseq(C.barkLight), emit = 4, box = V3(4, 0.2, 4), size = nseq({ { 0, 0.6 }, { 1, 1.4 } }), transp = nseq({ { 0, 0.6 }, { 1, 1 } }), life = { 0.5, 0.9 }, speed = { 0.5, 1.5 }, light = 0 })
			sfx("plankCrack", pos)
		elseif payload.phase == "break" then
			burst(pos, 18, { C.bark, C.barkLight, C.rootMoss }, 0.26, 12, 0.5, pos.Y - 6)
			waterBurst(pos + V3(0, -1, 0), 0.8)
			sfx("plankBreak", pos)
		end
	elseif kind == "f2span" and pos then
		if payload.phase == "crack" then
			emitter(pos, {
				tex = TEX.smoke, color = cseq(rgb(196, 190, 170)), rate = 16, box = V3(12, 0.4, 6),
				size = nseq({ { 0, 0.5 }, { 1, 1.6 } }), transp = nseq({ { 0, 0.4 }, { 1, 1 } }), life = { 0.8, 1.4 }, speed = { 1, 3 }, accel = V3(0, -6, 0), dir = Enum.NormalId.Bottom, light = 0,
			}, payload.duration or 1.2)
			emitter(pos, { tex = TEX.crack, color = cseq(rgb(60, 50, 40)), emit = 3, box = V3(10, 0.2, 4), size = NumberSequence.new(3), transp = nseq({ { 0, 0.2 }, { 1, 1 } }), life = { 1.2, 1.4 }, speed = { 0, 0 }, rot = 0, light = 0 })
			sfx("spanCrack", pos)
		elseif payload.phase == "fall" then
			burst(pos, 30, { rgb(176, 170, 150), rgb(120, 116, 100), C.rootMoss }, 0.5, 14, 0.4, pos.Y - 12)
			emitter(pos, { tex = TEX.smoke, color = cseq(rgb(200, 196, 180)), emit = 24, box = V3(12, 1, 6), size = nseq({ { 0, 2 }, { 1, 6 } }), transp = nseq({ { 0, 0.3 }, { 1, 1 } }), life = { 1.2, 2.2 }, speed = { 2, 6 }, spread = 180, drag = 2, light = 0 })
			sfx("spanFall", pos)
		elseif payload.phase == "back" then
			emitter(pos, { tex = TEX.glow, color = cseq(C.water), emit = 20, box = V3(12, 0.4, 6), size = nseq({ { 0, 0.4 }, { 1, 0 } }), transp = nseq({ { 0, 0 }, { 1, 1 } }), life = { 0.6, 1 }, speed = { 2, 4 }, light = 1 })
		end
	elseif kind == "f2jet" and pos then
		local radius = payload.radius or 3
		if payload.phase == "warn" then
			warnRing(pos, radius, C.water, payload.duration or 1)
			emitter(pos, { tex = TEX.glow, color = cseq(Color3.new(1, 1, 1), C.water), rate = 20, box = V3(radius, 0.2, radius), size = nseq({ { 0, 0.25 }, { 1, 0 } }), life = { 0.4, 0.7 }, speed = { 2, 5 }, light = 1 }, payload.duration or 1)
			sfx("jetWarn", pos)
		elseif payload.phase == "burst" then
			local life = math.min(payload.duration or 1.5, 4)
			emitter(pos, {
				tex = TEX.smoke, color = cseq(Color3.new(1, 1, 1), C.water), rate = 60, box = V3(radius * 0.8, 0.2, radius * 0.8),
				size = nseq({ { 0, 1 }, { 0.6, 2.4 }, { 1, 3 } }), transp = nseq({ { 0, 0.2 }, { 1, 1 } }), life = { 0.8, 1.2 }, speed = { 18, 26 }, spread = 6, accel = V3(0, -20, 0), light = 0.3,
			}, life)
			emitter(pos, { tex = TEX.glow, color = cseq(C.water), rate = 50, box = V3(radius, 0.2, radius), size = nseq({ { 0, 0.3 }, { 1, 0.1 } }), transp = nseq({ { 0, 0 }, { 1, 1 } }), life = { 0.8, 1.4 }, speed = { 14, 22 }, spread = 14, accel = V3(0, -40, 0), light = 1 }, life)
			sfx("jetBurst", pos)
		end
	elseif kind == "f2spore" and pos then
		local radius = payload.radius or 3
		if payload.phase == "warn" then
			warnRing(pos, radius, C.sporeGlow, payload.duration or 1)
			emitter(pos, { tex = TEX.glow, color = cseq(C.sporeGlow), rate = 14, box = V3(radius, 0.2, radius), size = nseq({ { 0, 0.3 }, { 1, 0 } }), life = { 0.6, 1 }, speed = { 1, 2 }, light = 1 }, payload.duration or 1)
		elseif payload.phase == "burst" then
			emitter(pos + V3(0, 1, 0), {
				tex = TEX.smoke, color = cseq(C.sporeGlow, C.rotDark), emit = 30, box = V3(radius, 1, radius),
				size = nseq({ { 0, radius * 0.6 }, { 1, radius * 1.4 } }), transp = nseq({ { 0, 0.4 }, { 1, 1 } }), life = { 1.2, 2 }, speed = { 3, 8 }, spread = 180, drag = 2.5, light = 0.4,
			})
			sfx("sporeBurst", pos)
		end
	elseif kind == "f2dart" and pos then
		if payload.phase == "warn" then
			emitter(pos, { tex = TEX.glow, color = cseq(C.rotGlow), rate = 30, size = nseq({ { 0, 0.8 }, { 1, 0 } }), life = { 0.3, 0.5 }, speed = { 0.5, 1 }, spread = 180, light = 1 }, payload.duration or 0.8)
			if typeof(payload.plate) == "Vector3" then
				warnRing(payload.plate, 2.2, C.rotGlow, payload.duration or 0.8)
			end
			sfx("dartWarn", pos)
		elseif payload.phase == "fire" then
			burst(pos, 8, { C.leaf, C.rootMoss }, 0.16, 10, 0.4)
			sfx("thornShot", pos)
		end
	end
end

local function clearBeacons()
	for id in pairs(beacons) do
		clearBeacon(id)
	end
end

-- ===== Кадр =====

local function step(dt: number)
	stepEnemies(dt)
	stepPuddles()
	stepSpikes()
	stepDebris(dt)
	stepPlayers(dt)
end

function Floor2Fx.start()
	folder()
	local remote = Net.get("EnemyEvent")
	if remote then
		remote.OnClientEvent:Connect(onEnemyEvent)
	end
	local floorRemote = Net.get("FloorEvent")
	if floorRemote then
		floorRemote.OnClientEvent:Connect(onMapEvent)
	end
	-- Маяки вентилей живут, пока игрок на этаже 2.
	player:GetAttributeChangedSignal("FloorId"):Connect(function()
		if player:GetAttribute("FloorId") ~= 2 then
			clearBeacons()
		end
	end)
	Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			-- Атрибуты ставятся до Parent, но подстрахуемся: ждём кадр.
			task.defer(track, d)
		end
	end)
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("Model") then
			track(d)
		end
	end
	RunService.Heartbeat:Connect(step)
end

return Floor2Fx
