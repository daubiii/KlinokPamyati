--!nonstrict
-- Floor3EnemyFx (клиент)
-- Эффекты врагов этажа 3 «Псарни охоты». Логики нет — только картинка, звук и
-- разовые анимации по событиям Floor3EnemyService (EnemyEvent, kind f3e*) и
-- броскам копий ловчего (FloorEvent f3spear из Floor3World).
--
--   лужи        дёготь (чёрный блеск, пузыри) и дубильный раствор (жёлтый, пар)
--   конус       телеграф ведра дубильщика (атрибут F3Cone) и брызги, пока льёт
--   рог / вой   кольца звука; гончие под рогом — искры у лап (F3HornUntil);
--               аура своры — бледное кольцо вокруг Вожака (F3PackAura)
--   сокол       прячется с перчатки (меш bird из EnemyVisuals3), летит за
--               снарядом и возвращается на перчатку
--   анимации    Hop (отскок), SpearThrow (копья с насеста, потом снова Perch)
--   прочее      шкура чучела, капкан, сети, горшок дёгтя, болас на ногах
--
-- Временные детали — в Workspace.Floor3EnemyFx; дальние эффекты не рисуются.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local EnemyVisuals = require(Shared.Config.EnemyVisuals)

local Bus = require(script.Parent.Parent.Lib.Bus)
local EnemyVisualController = require(script.Parent.EnemyVisualController)

local Floor3EnemyFx = {}

local V3 = Vector3.new
local rgb = Color3.fromRGB
local TAU = math.pi * 2
local FAR_FX = 110
local BITS_MAX = 200

local C = {
	tar = rgb(30, 22, 18),
	tarGloss = rgb(74, 60, 52),
	brine = rgb(184, 166, 90),
	brineFoam = rgb(232, 220, 170),
	horn = rgb(255, 200, 87),
	howl = rgb(232, 220, 192),
	danger = rgb(255, 92, 72),
	leather = rgb(140, 96, 60),
	rope = rgb(196, 160, 104),
	ember = rgb(255, 154, 60),
}

local player = Players.LocalPlayer
local random = Random.new()

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function sfx(name: string?, position: Vector3?)
	if name then
		Bus.emit("sfx", { name = name, position = position })
	end
end

local function shake(amount: number, time: number)
	Bus.emit("shake", { amount = amount, time = time })
end

local folderRef
local function folder()
	if folderRef and folderRef.Parent then
		return folderRef
	end
	folderRef = Workspace:FindFirstChild("Floor3EnemyFx")
	if not folderRef then
		folderRef = Instance.new("Folder")
		folderRef.Name = "Floor3EnemyFx"
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

local function onFloor3(): boolean
	return player:GetAttribute("Zone") == "Floor" and player:GetAttribute("FloorId") == 3
end

local function rigPose(model)
	local rig = model and EnemyVisualController.rigOf(model)
	if rig and rig.pos then
		return rig.pos, rig.facing, rig
	end
	local root = model and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart"))
	if not root then
		return nil
	end
	local height = model:GetAttribute("EnemyHeight") or 5
	local look = flat(root.CFrame.LookVector)
	return root.Position - V3(0, height / 2, 0), look.Magnitude > 0.01 and look.Unit or V3(0, 0, -1), nil
end

-- ===== Осколки и капли =====

local bits = {}

local function spawnBit(position: Vector3, velocity: Vector3, color: Color3, size: number, life: number, neon: boolean?, gravity: number?)
	if #bits >= BITS_MAX then
		local oldest = table.remove(bits, 1)
		oldest.part:Destroy()
	end
	local p = part({
		Name = "Bit",
		Size = V3(size, size, size),
		CFrame = CFrame.new(position),
		Color = color,
		Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic,
	})
	table.insert(bits, { part = p, velocity = velocity, born = os.clock(), life = life, gravity = gravity or 40, floorY = position.Y - 8 })
end

local function burst(position: Vector3, count: number, color: Color3, speed: number, size: number?, neon: boolean?)
	if not near(position) then
		return
	end
	for _ = 1, count do
		local a = random:NextNumber() * TAU
		local up = random:NextNumber(0.4, 1)
		spawnBit(position, V3(math.cos(a) * speed, up * speed, math.sin(a) * speed), color, size or 0.3, random:NextNumber(0.4, 0.8), neon)
	end
end

local function stepBits(dt: number)
	local t = os.clock()
	for index = #bits, 1, -1 do
		local b = bits[index]
		local age = t - b.born
		if age >= b.life or not b.part.Parent then
			b.part:Destroy()
			table.remove(bits, index)
		else
			b.velocity -= V3(0, b.gravity * dt, 0)
			local position = b.part.Position + b.velocity * dt
			if position.Y < b.floorY then
				position = V3(position.X, b.floorY, position.Z)
				b.velocity = V3(b.velocity.X * 0.3, 0, b.velocity.Z * 0.3)
			end
			b.part.CFrame = CFrame.new(position)
			b.part.Transparency = math.clamp((age / b.life - 0.6) / 0.4, 0, 1)
		end
	end
end

-- Расходящееся кольцо (рог, вой, капкан).
local rings = {}
local function ring(center: Vector3, radius: number, color: Color3, time: number, from: number?)
	if not near(center, FAR_FX + radius) then
		return
	end
	local p = part({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = V3(0.08, 1, 1), Color = color, Material = Enum.Material.Neon, Transparency = 0.35 })
	table.insert(rings, { part = p, center = center, radius = radius, from = from or 0.5, born = os.clock(), time = time })
end

local function stepRings()
	local t = os.clock()
	for index = #rings, 1, -1 do
		local r = rings[index]
		local k = (t - r.born) / r.time
		if k >= 1 then
			r.part:Destroy()
			table.remove(rings, index)
		else
			local e = 1 - (1 - k) ^ 3
			local d = (r.from + (r.radius - r.from) * e) * 2
			r.part.Size = V3(0.08, d, d)
			r.part.CFrame = discCFrame(r.center, 0.12)
			r.part.Transparency = 0.35 + 0.65 * k
		end
	end
end

-- ===== Лужи: дёготь и раствор =====

local puddles = {}

local function addPuddle(payload)
	local kind = payload.hazard
	local center = payload.position
	if not center or puddles[payload.id] then
		return
	end
	local color = kind == "brine" and C.brine or C.tar
	local disc = part({
		Name = "Puddle_" .. tostring(kind),
		Shape = Enum.PartType.Cylinder,
		Size = V3(0.08, 0.5, 0.5),
		CFrame = discCFrame(center, 0.06),
		Color = color,
		Material = kind == "brine" and Enum.Material.Glass or Enum.Material.SmoothPlastic,
		Reflectance = kind == "tar" and 0.25 or 0,
		Transparency = kind == "brine" and 0.25 or 0.05,
	})
	puddles[payload.id] = {
		disc = disc,
		kind = kind,
		center = center,
		radius = payload.radius or 3,
		born = os.clock(),
		life = payload.life or 5,
		nextBubble = 0,
	}
end

local function removePuddle(id)
	local p = puddles[id]
	if p then
		p.disc:Destroy()
		puddles[id] = nil
	end
end

local function clearPuddles()
	for id in pairs(puddles) do
		removePuddle(id)
	end
end

local function stepPuddles()
	local t = os.clock()
	for id, p in pairs(puddles) do
		local age = t - p.born
		if age >= p.life then
			removePuddle(id)
		else
			local grow = math.min(age / 0.25, 1)
			local fade = math.clamp((p.life - age) / 0.8, 0, 1)
			local d = p.radius * 2 * (0.4 + 0.6 * grow) * (0.85 + 0.15 * fade)
			p.disc.Size = V3(0.08, d, d)
			p.disc.Transparency = 1 - (1 - (p.kind == "brine" and 0.25 or 0.05)) * fade
			if t >= p.nextBubble and near(p.center, 70) then
				p.nextBubble = t + (p.kind == "brine" and 0.18 or 0.35)
				local a = random:NextNumber() * TAU
				local r = random:NextNumber() * p.radius * 0.8
				local at = p.center + V3(math.cos(a) * r, 0.15, math.sin(a) * r)
				if p.kind == "brine" then
					spawnBit(at, V3(0, random:NextNumber(1.5, 3), 0), C.brineFoam, 0.22, 0.7, false, -1)
				else
					spawnBit(at, V3(0, random:NextNumber(0.6, 1.2), 0), C.tarGloss, 0.28, 0.5, false, 2)
				end
			end
		end
	end
end

-- ===== Разовые анимации (полная поза поверх, потом назад) =====

local function actionShot(model, key: string)
	local rig = EnemyVisualController.rigOf(model)
	local animator = rig and rig.animator
	local config = rig and rig.config
	local name = config and config.oneShots and config.oneShots[key]
	if not animator or not name or not (animator.set and animator.set[name]) then
		return
	end
	-- После броска — снова анимация своего состояния (Perch на насесте),
	-- иначе слой действия гаснет в ходьбу.
	local back = config.states and config.states[animator.state] or nil
	pcall(function()
		animator:playAction(name, 1, nil)
		animator.action.after = { name = back, amp = 1 }
	end)
end

-- ===== Сокол сокольника =====

local falcons = {} -- [falconerModel] = { clone, part, phase, from, startT }

local function birdMesh(rig)
	local config = rig and rig.config
	local name = config and config.bird
	return name and rig.model and rig.model:FindFirstChild(name, true) or nil
end

local function setBirdVisible(rig, visible: boolean)
	local mesh = birdMesh(rig)
	if mesh and mesh:IsA("BasePart") then
		mesh.LocalTransparencyModifier = visible and 0 or 1
	end
end

local function makeFlyer(rig)
	local mesh = birdMesh(rig)
	if not mesh then
		return nil
	end
	local clone = mesh:Clone()
	for _, c in ipairs(clone:GetChildren()) do
		if not c:IsA("SpecialMesh") and not c:IsA("SurfaceAppearance") then
			c:Destroy()
		end
	end
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.LocalTransparencyModifier = 0
	clone.Transparency = 0
	clone.Parent = folder()
	return clone
end

local function nearestFalconShot(position: Vector3)
	local projectiles = Workspace:FindFirstChild("Projectiles")
	local best, bestD = nil, 8
	for _, p in ipairs(projectiles and projectiles:GetChildren() or {}) do
		if p:IsA("BasePart") and p:GetAttribute("ProjectileKind") == "falcon" then
			local d = (p.Position - position).Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best
end

local function falconEvent(payload)
	local model = payload.model
	local rig = model and EnemyVisualController.rigOf(model)
	if not rig then
		return
	end
	local entry = falcons[model]
	if payload.phase == "out" then
		setBirdVisible(rig, false)
		if entry and entry.clone then
			entry.clone:Destroy()
		end
		falcons[model] = { rig = rig, clone = makeFlyer(rig), phase = "out", startT = os.clock() }
	elseif payload.phase == "back" then
		if not entry then
			entry = { rig = rig, clone = makeFlyer(rig) }
			falcons[model] = entry
		end
		entry.phase = "back"
		entry.from = payload.position or (entry.clone and entry.clone.Position) or rig.pos
		entry.startT = os.clock()
		sfx("unlockThrow", entry.from)
	elseif payload.phase == "drop" then
		if entry and entry.clone then
			entry.phase = "away"
			entry.from = entry.clone.Position
			entry.startT = os.clock()
		end
	end
end

local BACK_TIME = 0.55
local function stepFalcons()
	local t = os.clock()
	for model, entry in pairs(falcons) do
		local rig = entry.rig
		local clone = entry.clone
		if not model.Parent or not clone then
			if clone then
				clone:Destroy()
			end
			falcons[model] = nil
			continue
		end
		local hand = rig.model and rig.model:FindFirstChild("LeftHand")
		local glove = hand and hand.Position or (rig.pos and rig.pos + V3(0, 3, 0)) or clone.Position
		if entry.phase == "out" then
			entry.shot = (entry.shot and entry.shot.Parent) and entry.shot or nearestFalconShot(entry.lastPos or glove)
			if entry.shot then
				local p = entry.shot.Position
				local look = entry.shot.CFrame.LookVector
				local flap = math.sin(t * 22) * 0.25
				clone.CFrame = CFrame.lookAt(p, p + look) * CFrame.Angles(0, 0, flap)
				entry.lastPos = p
			elseif t - entry.startT > 0.3 then
				clone.CFrame = CFrame.new(entry.lastPos or glove)
			end
		elseif entry.phase == "back" then
			local k = math.clamp((t - entry.startT) / BACK_TIME, 0, 1)
			local e = k * k * (3 - 2 * k)
			local arc = math.sin(k * math.pi) * 2.5
			local p = entry.from:Lerp(glove, e) + V3(0, arc, 0)
			local dir = glove - entry.from
			clone.CFrame = (dir.Magnitude > 0.1 and CFrame.lookAt(p, p + dir) or CFrame.new(p)) * CFrame.Angles(0, 0, math.sin(t * 20) * 0.3)
			if k >= 1 then
				clone:Destroy()
				setBirdVisible(rig, true)
				falcons[model] = nil
			end
		elseif entry.phase == "away" then
			local k = (t - entry.startT) / 1.2
			clone.CFrame = CFrame.new(entry.from + V3(0, k * 14, k * 6))
			clone.LocalTransparencyModifier = math.clamp(k, 0, 1)
			if k >= 1 then
				clone:Destroy()
				falcons[model] = nil
			end
		end
	end
end

-- ===== Конус ведра дубильщика =====

local cones = {} -- [model] = { wedges, pourUntil }
local CONE_SLICES = 6

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

local function hideCone(model)
	local entry = cones[model]
	if entry then
		for _, w in ipairs(entry.wedges) do
			w:Destroy()
		end
		cones[model] = nil
	end
end

local function drawCone(model, spec: string, pouring: boolean)
	local angle, length, dx, dz = spec:match("^([%d%.%-]+),([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)$")
	if not angle then
		return
	end
	angle, length = tonumber(angle), tonumber(length)
	local dir = V3(tonumber(dx), 0, tonumber(dz))
	local pos = rigPose(model)
	if not pos or dir.Magnitude < 0.01 then
		return
	end
	local entry = cones[model]
	if not entry then
		entry = { wedges = {} }
		for index = 1, CONE_SLICES * 2 do
			entry.wedges[index] = part({ Name = "Cone", Color = C.danger, Material = Enum.Material.Neon, Transparency = 0.7 }, "WedgePart")
		end
		cones[model] = entry
	end
	local origin = pos + V3(0, 0.15, 0)
	local base = math.atan2(dir.Z, dir.X)
	local half = math.rad(angle / 2)
	for index = 1, CONE_SLICES do
		local a0 = base - half + (index - 1) / CONE_SLICES * half * 2
		local a1 = base - half + index / CONE_SLICES * half * 2
		local p0 = origin + V3(math.cos(a0), 0, math.sin(a0)) * length
		local p1 = origin + V3(math.cos(a1), 0, math.sin(a1)) * length
		triangle(origin, p0, p1, entry.wedges[index * 2 - 1], entry.wedges[index * 2], 0.06)
	end
	local tint = pouring and C.brine or C.danger
	for _, w in ipairs(entry.wedges) do
		w.Color = tint
		w.Transparency = pouring and 0.55 or 0.7
	end
	-- Брызги раствора, пока льёт.
	if pouring and near(origin) and random:NextNumber() < 0.7 then
		local a = base + random:NextNumber(-half, half)
		local d = V3(math.cos(a), 0, math.sin(a))
		spawnBit(origin + d * 1.2 + V3(0, 2.6, 0), d * random:NextNumber(10, 16) + V3(0, random:NextNumber(2, 5), 0), C.brine, 0.25, 0.6, false, 30)
	end
end

local pouring = {} -- [model] = untilT (os.clock)

local tracked = {} -- модели врагов этажа 3 с покадровыми эффектами

local function stepTracked(dt: number)
	local t = serverNow()
	for model in pairs(tracked) do
		if not model.Parent then
			tracked[model] = nil
			hideCone(model)
			continue
		end
		local spec = model:GetAttribute("F3Cone")
		if spec then
			drawCone(model, spec, (pouring[model] or 0) > os.clock())
		elseif cones[model] then
			hideCone(model)
		end
		-- Гончие под рогом: искры у лап.
		local hornUntil = model:GetAttribute("F3HornUntil")
		if hornUntil and hornUntil > t and random:NextNumber() < dt * 10 then
			local pos = rigPose(model)
			if pos and near(pos, 70) then
				spawnBit(pos + V3(random:NextNumber(-0.8, 0.8), 0.4, random:NextNumber(-0.8, 0.8)), V3(0, random:NextNumber(2, 4), 0), C.ember, 0.18, 0.4, true, 4)
			end
		end
		-- Аура своры: бледное кольцо вокруг Вожака.
		local aura = model:GetAttribute("F3PackAura")
		if aura then
			local pos = rigPose(model)
			local entry = tracked[model]
			if pos and model:GetAttribute("EnemyState") ~= "dead" then
				if not entry.aura then
					entry.aura = part({ Name = "PackAura", Shape = Enum.PartType.Cylinder, Size = V3(0.06, aura * 2, aura * 2), Color = C.howl, Material = Enum.Material.Neon, Transparency = 0.9 })
				end
				entry.aura.CFrame = discCFrame(pos, 0.08)
			elseif entry.aura then
				entry.aura:Destroy()
				entry.aura = nil
			end
		end
	end
end

local function track(model)
	if tracked[model] or not model:IsA("Model") then
		return
	end
	if model:GetAttribute("Floor3") or model:GetAttribute("F3PackAura") then
		tracked[model] = {}
		model.Destroying:Connect(function()
			local entry = tracked[model]
			if entry and entry.aura then
				entry.aura:Destroy()
			end
			tracked[model] = nil
			hideCone(model)
		end)
	end
end

-- ===== События врагов (EnemyEvent) =====

local function onEnemyEvent(payload)
	if type(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	if type(kind) ~= "string" or kind:sub(1, 3) ~= "f3e" then
		return
	end
	if payload.model then
		track(payload.model)
	end
	if kind == "f3ehazard" then
		addPuddle(payload)
	elseif kind == "f3ehazardEnd" then
		removePuddle(payload.id)
	elseif kind == "f3ehop" then
		actionShot(payload.model, "hop")
		local rig = EnemyVisualController.rigOf(payload.model)
		sfx(rig and rig.config.sounds and rig.config.sounds.hop, payload.position)
		if payload.position then
			burst(payload.position + V3(0, 0.2, 0), 5, rgb(120, 104, 84), 6, 0.25)
		end
	elseif kind == "f3ehorn" then
		local center = payload.position
		if center then
			for index = 0, 2 do
				task.delay(index * 0.28, function()
					ring(center, payload.radius or 18, C.horn, 0.9)
				end)
			end
			if payload.boss then
				shake(0.12, 0.4)
			end
		end
	elseif kind == "f3ehowl" then
		local center = payload.position
		if center then
			for index = 0, 3 do
				task.delay(0.5 + index * 0.3, function()
					ring(center, (payload.radius or 12) * 1.3, C.howl, 1.0)
				end)
			end
			task.delay(0.55, function()
				shake(0.1, 0.6)
			end)
		end
	elseif kind == "f3epack" then
		for _, position in ipairs(payload.positions or {}) do
			burst(position + V3(0, 0.5, 0), 10, rgb(150, 128, 100), 8, 0.35)
		end
		sfx("chainRattle", payload.positions and payload.positions[1])
	elseif kind == "f3efalcon" then
		falconEvent(payload)
	elseif kind == "f3ebolas" then
		local target = payload.player
		local character = target and target.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			burst(root.Position - V3(0, 2.4, 0), 8, C.rope, 4, 0.2)
			sfx("chains", root.Position)
		end
		if target == player then
			Bus.emit("notify", { kind = "warn", text = "Болас на ногах — медленнее" })
		end
	elseif kind == "f3epour" then
		pouring[payload.model] = os.clock() + (payload.duration or 3)
	elseif kind == "f3epourStop" then
		pouring[payload.model] = nil
	elseif kind == "f3ehide" then
		if payload.position then
			burst(payload.position, 6, C.leather, 5, 0.25)
			sfx("armorBlock", payload.position)
		end
	elseif kind == "f3etrap" or kind == "f3enets" then
		local color = kind == "f3etrap" and rgb(110, 102, 96) or C.rope
		for _, center in ipairs(payload.positions or {}) do
			ring(center, payload.radius or 2.6, color, 0.45, (payload.radius or 2.6) * 0.9)
			burst(center + V3(0, 0.3, 0), 6, color, 5, 0.22)
		end
	elseif kind == "f3elob" then
		local from = payload.from
		for _, to in ipairs(payload.positions or {}) do
			if from and near(to) then
				local flight = 0.45
				local v = (to - from) / flight + V3(0, 40 * flight / 2, 0)
				spawnBit(from, v, C.tar, 0.6, flight, false, 40)
				task.delay(flight, function()
					burst(to + V3(0, 0.2, 0), 8, C.tar, 6, 0.3)
				end)
			end
		end
	end
end

-- ===== Карта (FloorEvent): копья ловчего с насеста =====

local function onMapEvent(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.kind == "f3spear" and payload.model then
		actionShot(payload.model, "spearThrow")
	end
end

local function step(dt: number)
	stepBits(dt)
	stepRings()
	stepPuddles()
	stepFalcons()
	stepTracked(dt)
end

function Floor3EnemyFx.start()
	folder()
	local remote = Net.get("EnemyEvent")
	if remote then
		remote.OnClientEvent:Connect(onEnemyEvent)
	end
	local floorRemote = Net.get("FloorEvent")
	if floorRemote then
		floorRemote.OnClientEvent:Connect(onMapEvent)
	end
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		if not onFloor3() then
			clearPuddles()
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
	print("[Floor3EnemyFx] эффекты врагов этажа 3")
end

-- Для тестов.
Floor3EnemyFx.Types = EnemyVisuals.Types

return Floor3EnemyFx
