--!nonstrict
-- MageFx (клиент)
-- Визуал мага по событию MageFx (сервер шлёт всем; урон и попадания решает сервер):
--   bolt / boltHit / boltEnd — снаряды посоха и заклинаний: клиент сам ведёт тот же
--     полёт (время рождения t — серверное, самонаведение к target или к ближнему врагу
--     в конусе 70°/18 стад, навес по дуге), вид — по стилю (LootMage.Styles: orb, shard,
--     flame, page, spark, wisp, blob) или по visual (petal, spore, wolf, glyph, orb,
--     beacon, inkdrop, molten, shard, echo, big); попадание — искры и звук стихии;
--   chain / wave / beam / nova — паттерны серии (цепная молния, волна, луч, всплеск);
--   barrier open / block — купол барьера и отбрасывающая волна;
--   veil on / off — «Покров»: персонаж почти невидим и мерцает, засада — вспышка;
--   debuff — горение, яд, замедление, раскол брони на враге до untilT;
--   heal, passive (9 пассивок посохов) — вспышки, метки, соколы, лужи чернил;
--   spell — заклинания (Controllers/MageSpellFx).
-- Плюс постоянное: аура стихии на навершии посоха, жар «Закалки» (MageHeat),
-- капли «Росы» вокруг мага (MageDew), вспышка навершия при ударе посохом.
-- Эффекты строятся кодом (Lib/MageFxKit): шаблоны в Studio собирать не нужно.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LootMage = require(Shared.Config.LootMage)
local Net = require(Shared.Net.Net)

local okSfx, SfxMage = pcall(function()
	return require(Shared.Config.SfxMage)
end)
if not okSfx then
	SfxMage = { HitByStyle = {} }
end

local Kit = require(script.Parent.Parent.Lib.MageFxKit)
local PlayerAnimator = require(script.Parent.PlayerAnimator)
local MageSpellFx = require(script.Parent.MageSpellFx)

local MageFx = {}

local player = Players.LocalPlayer
local V3 = Vector3.new
local WHITE = Color3.new(1, 1, 1)
local TAU = math.pi * 2

local HOMING_CONE = math.cos(math.rad(70))
local HOMING_RANGE = 18
local BLEND_TIME = 0.12 -- снаряд «выходит» из навершия посоха
local SPELL_VISUALS = { petal = true, spore = true, wolf = true, glyph = true, orb = true, beacon = true, inkdrop = true }
local DESCEND = { glyph = true, orb = true, petal = true } -- плавно опускаются к высоте полёта

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- ===== Стили =====

local styleCache = {}
local function styleOf(name)
	name = name or "arcane"
	local cached = styleCache[name]
	if cached then
		return cached
	end
	local spec = LootMage.Styles[name] or LootMage.Styles.arcane
	cached = {
		name = name,
		shape = spec.shape or "orb",
		core = Kit.color(spec.core, WHITE),
		glow = Kit.color(spec.glow, Color3.fromRGB(140, 108, 255)),
		trail = Kit.color(spec.trail, Color3.fromRGB(91, 63, 217)),
	}
	styleCache[name] = cached
	return cached
end
MageFx.styleOf = styleOf

local function hitSound(styleName): string
	return SfxMage.HitByStyle and SfxMage.HitByStyle[styleName or "arcane"] or "boltArcane"
end

-- ===== Враги (для самонаведения и меток) =====

local enemies = {}

local function track(instance)
	if instance:IsA("Model") and instance:GetAttribute("EnemyMaxHealth") ~= nil then
		enemies[instance] = true
	end
end

local function enemyAlive(model): boolean
	return model ~= nil
		and model.Parent ~= nil
		and model.PrimaryPart ~= nil
		and (model:GetAttribute("EnemyHealth") or 0) > 0
		and model:GetAttribute("EnemyRole") ~= "object"
end

local function enemyRoot(model)
	return model and model.PrimaryPart
end
MageFx.enemyRoot = enemyRoot

local function flat(v: Vector3): Vector3
	return V3(v.X, 0, v.Z)
end

local function turnToward(dir: Vector3, want: Vector3, maxAngle: number): Vector3
	local a = math.atan2(dir.X, dir.Z)
	local b = math.atan2(want.X, want.Z)
	local d = (b - a + math.pi) % TAU - math.pi
	local n = a + math.clamp(d, -maxAngle, maxAngle)
	return V3(math.sin(n), 0, math.cos(n))
end

local function acquire(bolt)
	local best, bestScore = nil, math.huge
	for model in pairs(enemies) do
		if enemyAlive(model) and not bolt.hitSet[model] then
			local root = model.PrimaryPart
			local rel = flat(root.Position - bolt.pos)
			local distance = rel.Magnitude
			if distance < HOMING_RANGE and distance > 0.2 and math.abs(root.Position.Y - 2.5 - bolt.feetY) < 5 then
				local dot = rel.Unit:Dot(bolt.dir)
				if dot >= HOMING_CONE then
					local score = distance * (1.6 - dot)
					if score < bestScore then
						best, bestScore = model, score
					end
				end
			end
		end
	end
	return best
end

-- ===== Вид снарядов =====
-- Визуал — невидимый корень (на нём свет, след, частицы) и детали со смещением.

local function addPart(vis, part: BasePart, offset: CFrame?, o)
	part.Parent = Kit.folder()
	table.insert(vis.parts, { part = part, offset = offset or CFrame.new(), spin = o and o.spin, wobble = o and o.wobble,
		base = part.Size, transparency = part.Transparency, flicker = o and o.flicker })
	return part
end

local function neon(size: Vector3, color: Color3, props)
	local p = Kit.part({ Size = size, Color = color, Name = "MageBoltPart" })
	for key, value in pairs(props or {}) do
		p[key] = value
	end
	return p
end

local function ballPart(d: number, color: Color3, transparency: number?)
	return neon(V3(d, d, d), color, { Shape = Enum.PartType.Ball, Transparency = transparency or 0 })
end

local function newVisual(position: Vector3)
	local root = Kit.part({ Size = V3(0.2, 0.2, 0.2), Transparency = 1, Name = "MageBolt" })
	root.CFrame = CFrame.new(position)
	return { root = root, parts = {}, emitters = {}, trail = nil, light = nil }
end

local function visualTrail(vis, color: Color3, color2: Color3, width: number, life: number, o)
	local trail = Kit.trail(vis.root, color, {
		width = width,
		life = life,
		colors = { color, color2 },
		transparency = o and o.transparency or { 0.05, 1 },
		brightness = o and o.brightness or 3,
		texture = o and o.texture,
		vertical = o and o.vertical,
	})
	vis.trail = trail
	return trail
end

local function visualEmitter(vis, o)
	local e = Kit.emitter(vis.root, o)
	table.insert(vis.emitters, e)
	return e
end

local function buildShape(vis, style, shape: string, size: number)
	local core, glow, trail = style.core, style.glow, style.trail
	if shape == "shard" then
		addPart(vis, neon(V3(size * 0.7, size * 0.7, size * 3.4), glow), nil, { spin = 9 })
		addPart(vis, neon(V3(size * 0.36, size * 0.36, size * 2.4), core), CFrame.new(0, 0, -size * 0.3), { spin = 9 })
		addPart(vis, ballPart(size * 2.4, glow, 0.7))
		visualTrail(vis, glow, trail, size * 1.3, 0.16)
		visualEmitter(vis, { texture = "spark", color = { core, glow }, size = { size * 0.6, 0 }, rate = 26, life = { 0.15, 0.3 },
			speed = { 1, 3 }, spread = 180 })
	elseif shape == "flame" then
		addPart(vis, ballPart(size * 1.4, core))
		addPart(vis, ballPart(size * 2.6, glow, 0.6), nil, { wobble = 0.12 })
		visualTrail(vis, glow, trail, size * 1.8, 0.22)
		visualEmitter(vis, { texture = "glow", color = { core, glow, trail }, size = { size * 2.4, size * 0.4 }, rate = 70,
			life = { 0.22, 0.38 }, speed = { 2, 6 }, spread = 18, direction = Enum.NormalId.Back, transparency = { 0.1, 1 } })
		visualEmitter(vis, { texture = "smoke", color = { trail, Color3.fromRGB(40, 30, 28) }, size = { size * 1.4, size * 3 },
			rate = 16, life = { 0.4, 0.7 }, speed = { 1, 2 }, spread = 30, direction = Enum.NormalId.Back,
			transparency = { 0.55, 1 }, lightEmission = 0, lightInfluence = 1, brightness = 1 })
	elseif shape == "page" then
		addPart(vis, neon(V3(size * 2.2, 0.06, size * 1.6), core, { Material = Enum.Material.SmoothPlastic }), nil, { spin = 7 })
		addPart(vis, neon(V3(size * 1.7, 0.08, size * 0.12), trail), CFrame.new(0, 0.02, -size * 0.3), { spin = 7 })
		addPart(vis, ballPart(size * 2.2, glow, 0.75))
		visualTrail(vis, glow, trail, size * 1.2, 0.2)
		visualEmitter(vis, { texture = "star", color = { core, glow }, size = { size * 0.5, 0 }, rate = 18, life = { 0.25, 0.45 },
			speed = { 0.5, 1.5 }, spread = 180 })
	elseif shape == "spark" then
		addPart(vis, ballPart(size * 1.1, core))
		addPart(vis, ballPart(size * 2.4, glow, 0.65), nil, { flicker = true })
		for i = 1, 3 do
			addPart(vis, neon(V3(0.07, 0.07, size * 2.4), glow), CFrame.Angles(i, i * 2, 0), { flicker = true, spin = 25 })
		end
		visualTrail(vis, glow, trail, size * 1.1, 0.14, { texture = "trail" })
		visualEmitter(vis, { texture = "spark", color = { WHITE, glow }, size = { size * 0.7, 0 }, rate = 40, life = { 0.08, 0.18 },
			speed = { 4, 9 }, spread = 180 })
	elseif shape == "wisp" then
		addPart(vis, ballPart(size * 1.2, core, 0.1))
		addPart(vis, ballPart(size * 2.4, glow, 0.7), nil, { wobble = 0.18 })
		visualTrail(vis, glow, trail, size * 1.6, 0.38, { transparency = { 0.2, 1 } })
		visualEmitter(vis, { texture = "swirl", color = { core, glow }, size = { size * 1.8, 0 }, rate = 30, life = { 0.3, 0.55 },
			speed = { 0.5, 1.5 }, spread = 40, direction = Enum.NormalId.Back, rotSpeed = { -180, 180 } })
	elseif shape == "blob" then
		addPart(vis, ballPart(size * 1.9, glow, 0.1), nil, { wobble = 0.16 })
		addPart(vis, ballPart(size * 1.1, core), CFrame.new(size * 0.2, size * 0.25, 0))
		visualTrail(vis, glow, trail, size * 1.6, 0.2)
		visualEmitter(vis, { texture = "glow", color = { glow, trail }, size = { size * 0.7, 0 }, rate = 18, life = { 0.35, 0.6 },
			speed = { 0.5, 1.5 }, spread = 60, accel = V3(0, -22, 0) })
	else -- orb
		addPart(vis, ballPart(size * 1.5, core))
		addPart(vis, ballPart(size * 2.8, glow, 0.62), nil, { wobble = 0.08 })
		visualTrail(vis, glow, trail, size * 1.7, 0.18)
		visualEmitter(vis, { texture = "star", color = { core, glow }, size = { size * 0.8, 0 }, rate = 28, life = { 0.2, 0.4 },
			speed = { 0.5, 2 }, spread = 180, rotSpeed = { -200, 200 } })
	end
end

local function buildVisual(vis, style, visual: string?, size: number)
	local core, glow, trail = style.core, style.glow, style.trail
	if visual == "petal" then
		for i = 0, 2 do
			addPart(vis, neon(V3(0.55, 0.05, 0.28), i == 0 and core or glow, { Shape = Enum.PartType.Block }),
				CFrame.Angles(0, i * TAU / 3, 0) * CFrame.new(0.22, 0, 0), { spin = 10 })
		end
		addPart(vis, ballPart(0.28, core))
		visualTrail(vis, glow, trail, 0.45, 0.3)
		visualEmitter(vis, { texture = "star", color = { core, glow }, size = { 0.3, 0 }, rate = 14, life = { 0.3, 0.5 },
			speed = { 0.3, 1 }, spread = 180 })
	elseif visual == "spore" then
		addPart(vis, ballPart(0.5, core))
		addPart(vis, ballPart(1.1, glow, 0.7), nil, { wobble = 0.2 })
		visualTrail(vis, glow, trail, 0.4, 0.25)
		visualEmitter(vis, { texture = "glow", color = { core, glow }, size = { 0.22, 0 }, rate = 24, life = { 0.5, 0.9 },
			speed = { 0.3, 1.2 }, spread = 180, accel = V3(0, 1.5, 0) })
	elseif visual == "wolf" then
		local body = Color3.fromRGB(150, 255, 220)
		local mat = { Material = Enum.Material.ForceField }
		addPart(vis, neon(V3(0.7, 0.62, 1.5), body, mat), CFrame.new(0, 0, 0.1))
		addPart(vis, neon(V3(0.56, 0.5, 0.6), body, mat), CFrame.new(0, 0.26, -0.92))
		addPart(vis, neon(V3(0.3, 0.26, 0.4), body, mat), CFrame.new(0, 0.14, -1.36))
		addPart(vis, neon(V3(0.14, 0.26, 0.12), core), CFrame.new(-0.17, 0.62, -0.84))
		addPart(vis, neon(V3(0.14, 0.26, 0.12), core), CFrame.new(0.17, 0.62, -0.84))
		addPart(vis, neon(V3(0.2, 0.2, 0.85), glow, mat), CFrame.new(0, 0.3, 1.05) * CFrame.Angles(math.rad(-25), 0, 0))
		addPart(vis, neon(V3(0.1, 0.1, 0.06), WHITE), CFrame.new(-0.14, 0.34, -1.22))
		addPart(vis, neon(V3(0.1, 0.1, 0.06), WHITE), CFrame.new(0.14, 0.34, -1.22))
		for i, x in ipairs({ -0.24, 0.24, -0.24, 0.24 }) do
			local z = i <= 2 and -0.45 or 0.6
			addPart(vis, neon(V3(0.16, 0.5, 0.16), body, mat), CFrame.new(x, -0.45, z), { leg = i })
			vis.parts[#vis.parts].leg = i
		end
		addPart(vis, ballPart(1.8, glow, 0.82))
		visualTrail(vis, glow, trail, 0.9, 0.35, { transparency = { 0.3, 1 } })
		visualEmitter(vis, { texture = "swirl", color = { core, glow }, size = { 1.2, 0 }, rate = 26, life = { 0.3, 0.6 },
			speed = { 0.5, 1.5 }, spread = 50, direction = Enum.NormalId.Back, rotSpeed = { -150, 150 } })
		vis.wolf = true
	elseif visual == "glyph" then
		addPart(vis, ballPart(0.4, core))
		addPart(vis, ballPart(1.2, glow, 0.75))
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(1.6, 1.6)
		gui.LightInfluence = 0
		gui.Brightness = 3
		gui.AlwaysOnTop = false
		gui.Adornee = vis.root
		gui.Parent = vis.root
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = Kit.GLYPHS[math.random(#Kit.GLYPHS)]
		label.TextScaled = true
		label.Font = Enum.Font.Garamond
		label.TextColor3 = Color3.fromRGB(255, 236, 170)
		label.TextStrokeColor3 = trail
		label.TextStrokeTransparency = 0.3
		label.Parent = gui
		vis.label = label
		visualTrail(vis, Color3.fromRGB(255, 226, 150), trail, 0.5, 0.25)
		visualEmitter(vis, { texture = "star", color = { core, Color3.fromRGB(255, 214, 120) }, size = { 0.35, 0 }, rate = 16,
			life = { 0.3, 0.5 }, speed = { 0.3, 1 }, spread = 180 })
	elseif visual == "orb" then
		addPart(vis, ballPart(0.6, core))
		addPart(vis, ballPart(1.3, glow, 0.6), nil, { wobble = 0.12 })
		addPart(vis, neon(V3(0.05, 1.4, 1.4), trail, { Shape = Enum.PartType.Cylinder, Transparency = 0.45 }), nil, { spin = 6 })
		visualTrail(vis, glow, trail, 0.6, 0.3)
		visualEmitter(vis, { texture = "star", color = { core, trail }, size = { 0.4, 0 }, rate = 20, life = { 0.25, 0.45 },
			speed = { 0.5, 1.5 }, spread = 180 })
	elseif visual == "beacon" then
		addPart(vis, ballPart(1.0, Color3.fromRGB(255, 244, 200)))
		addPart(vis, ballPart(2.0, Color3.fromRGB(255, 120, 30), 0.45), nil, { wobble = 0.15 })
		visualTrail(vis, Color3.fromRGB(255, 160, 50), Color3.fromRGB(190, 40, 10), 1.6, 0.35)
		visualEmitter(vis, { texture = "glow", color = { "#FFF4C0", "#FF7A1F", "#B8200F" }, size = { 2.4, 0.4 }, rate = 90,
			life = { 0.3, 0.5 }, speed = { 1, 4 }, spread = 180, transparency = { 0.1, 1 } })
		visualEmitter(vis, { texture = "spark", color = { "#FFF0B0", "#FF7A1F" }, size = { 0.4, 0 }, rate = 40, life = { 0.3, 0.6 },
			speed = { 3, 8 }, spread = 180, accel = V3(0, -10, 0) })
	elseif visual == "inkdrop" then
		addPart(vis, ballPart(1.3, Color3.fromRGB(20, 16, 42), 0), nil, { wobble = 0.18 })
		addPart(vis, ballPart(2.1, Color3.fromRGB(106, 88, 216), 0.65))
		visualTrail(vis, Color3.fromRGB(106, 88, 216), Color3.fromRGB(20, 18, 42), 1.1, 0.3)
		visualEmitter(vis, { texture = "glow", color = { "#6A58D8", "#14122A" }, size = { 0.5, 0 }, rate = 30, life = { 0.4, 0.7 },
			speed = { 0.5, 2 }, spread = 90, accel = V3(0, -24, 0), lightEmission = 0.3 })
	elseif visual == "molten" then
		addPart(vis, ballPart(size * 1.6, Color3.fromRGB(255, 230, 160)))
		addPart(vis, ballPart(size * 2.6, Color3.fromRGB(255, 90, 20), 0.4), nil, { wobble = 0.2 })
		visualTrail(vis, Color3.fromRGB(255, 140, 40), Color3.fromRGB(120, 20, 8), size * 1.8, 0.3)
		visualEmitter(vis, { texture = "spark", color = { "#FFF0B0", "#FF5A1F" }, size = { 0.35, 0 }, rate = 40, life = { 0.3, 0.6 },
			speed = { 2, 6 }, spread = 180, accel = V3(0, -18, 0) })
	else
		buildShape(vis, style, visual == "shard" and "shard" or style.shape, size)
	end
	local light = Kit.light(vis.root, glow, visual == "beacon" and 4 or 2, visual == "beacon" and 14 or 8)
	vis.light = light
end

local function ghostify(vis)
	for _, entry in ipairs(vis.parts) do
		entry.transparency = 1 - (1 - entry.transparency) * 0.45
		entry.part.Transparency = entry.transparency
		entry.part.Color = entry.part.Color:Lerp(Color3.fromRGB(200, 230, 255), 0.35)
	end
	if vis.trail then
		vis.trail.Transparency = NumberSequence.new(0.5, 1)
	end
	for _, e in ipairs(vis.emitters) do
		e.Rate *= 0.5
	end
end

local function placeVisual(vis, cf: CFrame, age: number)
	vis.root.CFrame = cf
	for i, entry in ipairs(vis.parts) do
		local offset = entry.offset
		if entry.spin then
			offset = CFrame.Angles(0, 0, age * entry.spin) * offset
		end
		if entry.leg then
			local swing = math.sin(age * 22 + (entry.leg % 2 == 0 and math.pi or 0) + (entry.leg > 2 and math.pi or 0)) * 0.6
			offset = offset * CFrame.new(0, 0.2, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -0.2, 0)
		end
		local part = entry.part
		if part.Parent then
			part.CFrame = cf * offset
			if entry.wobble then
				local w = 1 + math.sin(age * 17 + i) * entry.wobble
				part.Size = entry.base * w
			end
			if entry.flicker then
				part.Transparency = math.random() < 0.3 and 1 or entry.transparency
				if entry.spin then
					entry.offset = CFrame.Angles(math.random() * TAU, math.random() * TAU, 0)
				end
			end
		end
	end
	if vis.label then
		vis.label.Rotation = math.sin(age * 5) * 12
	end
end

local function destroyVisual(vis, fadeTime: number?)
	local t = fadeTime or 0.08
	for _, entry in ipairs(vis.parts) do
		if entry.part.Parent then
			Kit.fade(entry.part, t, { Size = entry.part.Size * 1.5 })
		end
	end
	for _, e in ipairs(vis.emitters) do
		e.Enabled = false
	end
	if vis.light then
		Kit.tween(vis.light, t + 0.1, { Brightness = 0 })
	end
	if vis.trail then
		task.delay(0.02, function()
			if vis.trail then
				vis.trail.Enabled = false
			end
		end)
	end
	task.delay(0.6, function()
		vis.root:Destroy()
	end)
end

-- ===== Полёт снарядов =====

local bolts = {}
local endedEarly = {}
local loop = nil

local function finishBolt(bolt)
	if bolt.dead then
		return
	end
	bolt.dead = true
	bolts[bolt.id] = nil
	destroyVisual(bolt.vis)
end

local function stepBolt(bolt, dt: number)
	if bolt.lob then
		local lob = bolt.lob
		local k = math.clamp(bolt.simT / math.max(lob.time, 0.05), 0, 1)
		local pos = bolt.origin:Lerp(lob.to, k) + V3(0, lob.height * 4 * k * (1 - k), 0)
		local ahead = math.clamp(k + 0.02, 0, 1)
		local next = bolt.origin:Lerp(lob.to, ahead) + V3(0, lob.height * 4 * ahead * (1 - ahead), 0)
		if (next - pos).Magnitude > 1e-3 then
			bolt.look = (next - pos).Unit
		end
		bolt.pos = pos
		if k >= 1 then
			bolt.landed = true
		end
		return
	end
	if bolt.stopped then
		return
	end
	if bolt.homing and bolt.homing > 0 then
		local target = bolt.target
		if not enemyAlive(target) or bolt.hitSet[target] then
			target = acquire(bolt)
			bolt.target = target
		end
		if target then
			local want = flat(target.PrimaryPart.Position - bolt.pos)
			if want.Magnitude > 0.05 then
				bolt.dir = turnToward(bolt.dir, want.Unit, math.rad(bolt.homing) * dt)
			end
		end
	end
	local step = bolt.speed * dt
	bolt.pos += bolt.dir * step
	bolt.traveled += step
	bolt.look = bolt.dir
	-- Предсказанное попадание: снаряд без пробития замирает на враге до boltEnd сервера.
	for model in pairs(enemies) do
		if enemyAlive(model) and not bolt.hitSet[model] then
			local root = model.PrimaryPart
			if flat(root.Position - bolt.pos).Magnitude <= (model:GetAttribute("EnemyRadius") or 1.3) + bolt.size
				and math.abs(root.Position.Y - 2.5 - bolt.feetY) < 5 then
				bolt.hitSet[model] = true
				if bolt.pierce > 0 then
					bolt.pierce -= 1
				else
					bolt.stopped = true
					bolt.stoppedAt = bolt.simT
				end
				break
			end
		end
	end
	if bolt.traveled >= bolt.range then
		bolt.stopped = true
		bolt.stoppedAt = bolt.simT
	end
end

local function displayCFrame(bolt, age: number): CFrame
	local pos = bolt.pos
	if DESCEND[bolt.visual] and not bolt.lob then
		local want = bolt.feetY + (LootMage.BoltHeight or 2.7)
		pos = V3(pos.X, want + (bolt.origin.Y - want) * math.exp(-age * 5), pos.Z)
	elseif bolt.visual == "wolf" then
		pos = V3(pos.X, pos.Y - 0.35 + math.abs(math.sin(age * 11)) * 0.3, pos.Z)
	elseif bolt.visual == "spore" or bolt.visual == "petal" then
		pos += V3(0, math.sin(age * 9 + bolt.id) * 0.25, 0)
	end
	-- Первые доли секунды снаряд подтягивается от навершия посоха.
	if bolt.tipOffset and age < BLEND_TIME then
		local k = Kit.ease(age / BLEND_TIME, "out")
		pos += bolt.tipOffset * (1 - k)
	end
	local look = bolt.look or bolt.dir
	if look.Magnitude < 1e-3 then
		look = V3(0, 0, -1)
	end
	return CFrame.lookAt(pos, pos + look)
end

local function runBolts(dt: number)
	local t = now()
	local any = false
	for _, bolt in pairs(bolts) do
		any = true
		local elapsed = t - bolt.born
		if elapsed >= 0 then
			if not bolt.visible then
				bolt.visible = true
			end
			-- Догоняем серверное время шагами по 1/60 (первый кадр — с учётом пинга).
			local guard = 0
			while bolt.simT < elapsed and guard < 90 do
				local h = math.min(1 / 60, elapsed - bolt.simT)
				bolt.simT += h
				stepBolt(bolt, h)
				guard += 1
			end
			placeVisual(bolt.vis, displayCFrame(bolt, elapsed), elapsed)
			-- Сервер молчит слишком долго (потеря события) — гасим сами.
			if (bolt.stopped and bolt.simT - (bolt.stoppedAt or bolt.simT) > 0.6) or elapsed > bolt.maxLife then
				finishBolt(bolt)
			end
		end
	end
	if not any and loop then
		loop:Disconnect()
		loop = nil
	end
end

local function muzzleFlash(position: Vector3, style, scale: number?)
	local s = scale or 1
	Kit.flash(position, style.glow, 1.4 * s, 0.14)
	Kit.burst(position, { texture = "spark", color = { style.core, style.glow }, size = { 0.35 * s, 0 }, count = 8,
		life = { 0.12, 0.25 }, speed = { 5, 10 }, spread = 60 })
end

local function onBolt(payload)
	if bolts[payload.id] or endedEarly[payload.id] or typeof(payload.origin) ~= "Vector3" then
		return
	end
	local style = styleOf(payload.style)
	local size = payload.size or 0.45
	local visual = payload.visual
	if visual == "big" then
		size *= 1.15
	end
	local vis = newVisual(payload.origin)
	buildVisual(vis, style, visual ~= "echo" and visual ~= "big" and visual or nil, size)
	if payload.echo or visual == "echo" then
		ghostify(vis)
	end
	local dir = typeof(payload.dir) == "Vector3" and flat(payload.dir) or V3(0, 0, -1)
	dir = dir.Magnitude > 0.01 and dir.Unit or V3(0, 0, -1)
	local bolt = {
		id = payload.id,
		vis = vis,
		visual = visual,
		style = payload.style,
		origin = payload.origin,
		pos = payload.origin,
		dir = dir,
		look = dir,
		speed = payload.speed or 60,
		size = size,
		range = payload.range or 28,
		traveled = 0,
		homing = payload.homing,
		pierce = payload.pierce or 0,
		lob = type(payload.lob) == "table" and typeof(payload.lob.to) == "Vector3" and payload.lob or nil,
		target = payload.target,
		feetY = payload.feetY or (payload.origin.Y - (LootMage.BoltHeight or 2.7)),
		hitSet = {},
		born = payload.t or now(),
		simT = 0,
	}
	bolt.maxLife = (bolt.lob and bolt.lob.time or bolt.range / math.max(bolt.speed, 1)) + 1.5
	-- Старт с навершия посоха (если стрелок рядом с точкой вылета).
	local tip = Kit.tipOf(payload.caster)
	if tip and not SPELL_VISUALS[visual] and (tip - payload.origin).Magnitude < 6 then
		bolt.tipOffset = tip - payload.origin
	end
	vis.root.CFrame = CFrame.new(payload.origin)
	placeVisual(vis, CFrame.lookAt(payload.origin, payload.origin + dir), 0)
	bolts[bolt.id] = bolt
	-- Чужие выстрелы посохом: вспышка навершия (свою рисует анимация удара).
	if payload.caster ~= player and not SPELL_VISUALS[visual] and tip then
		local delay = math.max(bolt.born - now(), 0)
		Kit.after(delay, function()
			muzzleFlash(tip, style, 0.8)
		end)
	end
	if not loop then
		loop = RunService.RenderStepped:Connect(runBolts)
	end
end

-- ===== Попадания и взрывы снарядов =====

local function impact(position: Vector3, styleName, scale: number, sound: boolean, volume: number?)
	local style = styleOf(styleName)
	Kit.flash(position, style.glow, 2.2 * scale, 0.18)
	Kit.burst(position, { texture = "spark", color = { style.core, style.glow }, size = { 0.45 * scale, 0 }, count = math.floor(14 * scale),
		life = { 0.18, 0.35 }, speed = { 8, 16 }, spread = 180, drag = 4 })
	Kit.burst(position, { texture = "ring", color = { style.core, style.glow }, size = { 0.4, 3.2 * scale }, count = 1,
		life = 0.22, speed = 0, transparency = { 0.1, 1 } })
	if style.shape == "flame" then
		Kit.burst(position, { texture = "smoke", color = { style.trail, Color3.fromRGB(40, 30, 28) }, size = { 1, 2.4 * scale },
			count = 4, life = { 0.4, 0.7 }, speed = { 1, 3 }, transparency = { 0.5, 1 }, lightEmission = 0, lightInfluence = 1 })
	elseif style.shape == "blob" then
		Kit.burst(position, { texture = "glow", color = { style.glow, style.trail }, size = { 0.5, 0 }, count = 10,
			life = { 0.4, 0.7 }, speed = { 4, 9 }, accel = V3(0, -30, 0) })
	elseif style.shape == "page" then
		Kit.burst(position, { texture = "star", color = { style.core, style.glow }, size = { 0.5, 0 }, count = 8,
			life = { 0.4, 0.7 }, speed = { 3, 6 }, rotSpeed = { -300, 300 } })
	end
	if sound then
		Kit.sfx(hitSound(styleName), position, volume)
	end
end
MageFx.impact = impact

local function onBoltHit(payload)
	if typeof(payload.position) == "Vector3" then
		impact(payload.position, payload.style, 0.8, true, 0.8)
	end
end

local function onBoltEnd(payload)
	local bolt = bolts[payload.id]
	local position = typeof(payload.position) == "Vector3" and payload.position or (bolt and bolt.pos)
	if bolt then
		if position then
			bolt.pos = V3(position.X, bolt.pos.Y, position.Z)
			placeVisual(bolt.vis, displayCFrame(bolt, now() - bolt.born), now() - bolt.born)
		end
		finishBolt(bolt)
	else
		endedEarly[payload.id] = payload
		task.delay(2, function()
			endedEarly[payload.id] = nil
		end)
	end
	if not position then
		return
	end
	local style = styleOf(payload.style)
	local visual = payload.visual
	local reason = payload.reason
	local echo = bolt and bolt.vis and visual == "echo"
	if type(payload.splash) == "number" and payload.splash > 0 then
		Kit.explosion(position, payload.splash, style.glow, { core = style.core, embers = style.shape == "flame" and 14 or nil,
			ground = Kit.ground(position, 0.1), shakeAmount = math.clamp(payload.splash * 0.04, 0.06, 0.3) })
		Kit.sfx("boltBlast", position, visual == "molten" and 0.9 or 1)
		return
	end
	if visual == "beacon" or visual == "inkdrop" then
		Kit.flash(position, style.glow, 2.4, 0.2)
		return
	end
	if visual == "wolf" then
		Kit.burst(position, { texture = "swirl", color = { style.core, style.glow }, size = { 1.6, 0 }, count = 10,
			life = { 0.35, 0.6 }, speed = { 2, 5 }, rotSpeed = { -200, 200 } })
		if reason == "hit" then
			Kit.sfx("spellBite", position, 0.8)
		end
		return
	end
	if visual == "petal" then
		Kit.burst(position, { texture = "star", color = { style.core, style.glow }, size = { 0.5, 0 }, count = 10,
			life = { 0.3, 0.6 }, speed = { 3, 7 }, rotSpeed = { -300, 300 } })
		if reason == "hit" then
			Kit.sfx("boltWater", position, 0.6)
		end
		return
	end
	if reason == "range" then
		Kit.burst(position, { texture = "glow", color = { style.core, style.glow }, size = { 0.8, 0 }, count = 6,
			life = { 0.2, 0.35 }, speed = { 1, 3 }, transparency = { 0.4, 1 } })
		return
	end
	local scale = (reason == "wall") and 0.75 or 1
	if SPELL_VISUALS[visual] then
		scale *= 0.8
	end
	if bolt and bolt.size then
		scale *= math.clamp(bolt.size / 0.45, 0.8, 1.8)
	end
	impact(position, payload.style, scale, true, (echo and 0.5 or 1) * (reason == "wall" and 0.6 or 1))
end

-- ===== Паттерны серии: цепь, волна, луч, всплеск =====

local function onChain(payload)
	local points = payload.points
	if type(points) ~= "table" or #points < 2 then
		return
	end
	local style = styleOf(payload.style or "lightning")
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		Kit.after((i - 1) * 0.06, function()
			Kit.lightning(a + V3(0, 2.4, 0), b + V3(0, 2.4, 0), style.glow, { width = 0.18, time = 0.24, core = style.core })
			impact(b + V3(0, 2.4, 0), payload.style or "lightning", 0.7, i == 1)
		end)
	end
	Kit.sfx("spellChain", points[1], 0.7)
end

local function onWave(payload)
	local style = styleOf(payload.style)
	local origin = payload.origin
	local dir = Kit.flatUnit(payload.dir or V3(0, 0, -1))
	local radius = payload.radius or 8
	local angle = payload.angle or 40
	local speed = payload.speed or 30
	local echo = payload.echo
	local count = 9
	local slabs = {}
	for i = 1, count do
		local slab = Kit.part({ Size = V3(1, 0.5, 0.3), Color = i % 2 == 0 and style.core or style.glow,
			Transparency = echo and 0.55 or 0.15, Name = "MageWave" })
		slabs[i] = slab
	end
	local life = radius / speed
	local y = (LootMage.BoltHeight or 2.7) - 1.2
	Kit.every(life + 0.12, function(k, t)
		local r = math.min(t * speed, radius) + 0.8
		local fade = math.clamp((t - life * 0.6) / (life * 0.5 + 0.12), 0, 1)
		for i, slab in ipairs(slabs) do
			local a = (i - (count + 1) / 2) / ((count - 1) / 2) * angle
			local d = Kit.rotate(dir, a)
			local p = origin + d * r + V3(0, y, 0)
			local width = (TAU * r * (angle * 2 / 360)) / count * 1.25
			slab.Size = V3(width, 0.9 - k * 0.4, 0.3)
			slab.CFrame = CFrame.lookAt(p, p + d)
			slab.Transparency = (echo and 0.55 or 0.15) + (1 - (echo and 0.55 or 0.15)) * fade
		end
		return true
	end, function()
		for _, slab in ipairs(slabs) do
			slab:Destroy()
		end
	end)
	Kit.stream(CFrame.new(origin + V3(0, y, 0)), { texture = "spark", color = { style.core, style.glow }, size = { 0.4, 0 },
		rate = 80, life = { 0.2, 0.35 }, speed = { speed * 0.6, speed }, spread = angle, direction = Enum.NormalId.Front,
		orientation = Enum.ParticleOrientation.VelocityParallel }, life * 0.6).Parent.CFrame = CFrame.lookAt(origin + V3(0, y, 0), origin + V3(0, y, 0) + dir)
	Kit.sfx(hitSound(payload.style), origin, echo and 0.4 or 0.7)
end

local function onBeam(payload)
	local style = styleOf(payload.style)
	local origin = payload.origin
	local dir = Kit.flatUnit(payload.dir or V3(0, 0, -1))
	local length = payload.length or 16
	local width = payload.width or 1
	local echo = payload.echo
	local from = origin
	local tip = Kit.tipOf(payload.caster)
	if tip and (tip - origin).Magnitude < 6 then
		from = tip
	end
	local to = origin + dir * length
	local mul = echo and 0.5 or 1
	Kit.beam(from, to, style.glow, { width = width * 2.2 * mul, time = 0.32, transparency = echo and 0.5 or 0.1, colors = { style.glow, style.trail } })
	Kit.beam(from, to, style.core, { width = width * 0.8 * mul, time = 0.26, transparency = echo and 0.5 or 0, texture = "glow" })
	Kit.flash(from, style.glow, 2, 0.15)
	Kit.flash(to, style.glow, 2.6, 0.2)
	for i = 1, 5 do
		local p = from:Lerp(to, i / 6)
		Kit.burst(p, { texture = "spark", color = { style.core, style.glow }, size = { 0.35, 0 }, count = 4,
			life = { 0.15, 0.3 }, speed = { 4, 9 } })
	end
	Kit.sfx("spellEchoBeam", origin, echo and 0.35 or 0.6)
end

local function onNova(payload)
	local style = styleOf(payload.style)
	local position = payload.position
	local radius = payload.radius or 5
	local ground = Kit.ground(position, 0.1)
	Kit.shockwave(position + V3(0, 1.2, 0), radius, style.glow, { time = 0.38, flat = true, ground = ground })
	Kit.ringWave(ground, radius, style.core, { time = 0.45, brightness = 4 })
	Kit.burst(position + V3(0, 1, 0), { texture = "spark", color = { style.core, style.glow }, size = { 0.5, 0 }, count = 26,
		life = { 0.25, 0.45 }, speed = { radius * 2.5, radius * 4 }, spread = 180, drag = 3 })
	Kit.flash(position + V3(0, 1.2, 0), style.glow, radius * 0.8, 0.2)
	Kit.sfx(hitSound(payload.style), position, payload.echo and 0.45 or 0.9)
end

-- ===== Барьер =====

local function onBarrier(payload)
	local caster = payload.caster
	local _, root = Kit.characterOf(caster)
	local barrierColor = Color3.fromRGB(150, 120, 255)
	if payload.phase == "open" then
		if not root then
			return
		end
		local window = math.max(payload.window or 0.3, 0.2)
		local dome = Kit.dome(root.Position, 3.4, barrierColor, { Transparency = 0.15 })
		local core = Kit.ball(root.Position, 6.6, Color3.fromRGB(200, 185, 255), { Transparency = 0.86, Material = Enum.Material.Neon })
		local circle = Kit.circle(Kit.ground(root.Position - V3(0, 2.8, 0), 0.08), 3.4, barrierColor,
			{ duration = window + 0.15, spin = 120, count = 8, star = 6, appear = 0.1 })
		Kit.every(window + 0.18, function(k)
			if not root.Parent then
				return false
			end
			local s = 6.8 * (k < 0.15 and Kit.ease(k / 0.15, "back") or 1)
			dome.Size = V3(s, s, s)
			dome.CFrame = root.CFrame
			core.Size = V3(s * 0.97, s * 0.97, s * 0.97)
			core.CFrame = root.CFrame
			dome.Transparency = 0.15 + 0.85 * math.clamp((k - 0.75) / 0.25, 0, 1)
			core.Transparency = 0.86 + 0.14 * math.clamp((k - 0.6) / 0.4, 0, 1)
			return true
		end, function()
			dome:Destroy()
			core:Destroy()
			circle.fade(0.15)
		end)
		Kit.light(dome, barrierColor, 3, 12, window + 0.2)
		Kit.sfx("barrierOpen", root.Position, caster == player and 1 or 0.6)
	elseif payload.phase == "block" then
		local position = payload.position or (root and root.Position)
		if not position then
			return
		end
		local radius = payload.radius or 7
		Kit.flash(position, Color3.fromRGB(230, 220, 255), 7, 0.22)
		Kit.shockwave(position, radius, barrierColor, { time = 0.4, flat = true, ground = Kit.ground(position - V3(0, 2.8, 0), 0.1) })
		Kit.burst(position, { texture = "star", color = { "#FFFFFF", "#9C7CFF" }, size = { 0.6, 0 }, count = 30,
			life = { 0.3, 0.55 }, speed = { 18, 30 }, spread = 180, drag = 5, rotSpeed = { -300, 300 } })
		Kit.burst(position, { texture = "ring", color = { "#FFFFFF", "#9C7CFF" }, size = { 1, 9 }, count = 2, life = 0.3, speed = 0 })
		Kit.sfx("barrierBlock", position)
		Kit.shake(position, caster == player and 0.35 or 0.15, 0.22)
	end
end

-- ===== Покров =====

local veils = {}

local function setCharacterAlpha(character, value: number)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = value
		end
	end
end

local function veilOff(caster, ambush: boolean?)
	local state = veils[caster]
	local character, root = Kit.characterOf(caster)
	if state then
		state.alive = false
		veils[caster] = nil
		if state.emitter then
			state.emitter.Enabled = false
			game:GetService("Debris"):AddItem(state.emitter, 1)
		end
	end
	if character then
		setCharacterAlpha(character, 0)
	end
	if not root then
		return
	end
	local veilColor = Color3.fromRGB(120, 90, 200)
	if ambush then
		Kit.flash(root.Position, Color3.fromRGB(190, 150, 255), 6, 0.25)
		Kit.burst(root.Position, { texture = "slash", color = { "#FFFFFF", "#9C7CFF" }, size = { 2.4, 0 }, count = 6,
			life = { 0.18, 0.3 }, speed = { 6, 12 }, rotSpeed = { -400, 400 } })
		Kit.burst(root.Position, { texture = "smoke", color = { "#3A2A66", "#120E22" }, size = { 2, 4 }, count = 10,
			life = { 0.5, 0.9 }, speed = { 3, 7 }, transparency = { 0.3, 1 }, lightEmission = 0, lightInfluence = 1 })
		Kit.sfx("veilAmbush", root.Position)
		Kit.shake(root.Position, caster == player and 0.2 or 0.08, 0.15)
	else
		Kit.burst(root.Position, { texture = "smoke", color = { veilColor, "#120E22" }, size = { 1.6, 3.2 }, count = 8,
			life = { 0.5, 0.8 }, speed = { 2, 4 }, transparency = { 0.4, 1 }, lightEmission = 0, lightInfluence = 1 })
		Kit.sfx("veilOff", root.Position, 0.7)
	end
end

local function veilOn(payload)
	local caster = payload.caster
	local character, root = Kit.characterOf(caster)
	if not character or not root then
		return
	end
	if veils[caster] then
		veils[caster].alive = false
	end
	local untilT = payload.untilT or (now() + (LootMage.Veil.duration or 3))
	local state = { alive = true, untilT = untilT }
	veils[caster] = state
	local position = root.Position
	Kit.burst(position, { texture = "smoke", color = { "#5A44A0", "#120E22" }, size = { 2.2, 4.5 }, count = 16,
		life = { 0.6, 1.0 }, speed = { 3, 7 }, spread = 180, transparency = { 0.25, 1 }, lightEmission = 0, lightInfluence = 1 })
	Kit.burst(position, { texture = "star", color = { "#FFFFFF", "#9C7CFF" }, size = { 0.5, 0 }, count = 18,
		life = { 0.4, 0.8 }, speed = { 4, 9 } })
	Kit.ringWave(Kit.ground(position - V3(0, 2.8, 0), 0.1), 4, Color3.fromRGB(130, 100, 230), { time = 0.4 })
	state.emitter = Kit.emitter(root, { texture = "swirl", color = { "#9C7CFF", "#2A1E4A" }, size = { 1.4, 0 }, rate = 10,
		life = { 0.5, 0.9 }, speed = { 0.3, 1 }, transparency = { 0.6, 1 }, rotSpeed = { -120, 120 } })
	Kit.sfx("veilOn", position, caster == player and 1 or 0.6)
	local base = caster == player and 0.68 or 0.9
	Kit.every(math.max(untilT - now(), 0.2) + 1, function(_, t)
		if not state.alive or not character.Parent then
			return false
		end
		local left = state.untilT - now()
		if left <= 0 or (caster:GetAttribute("VeiledUntil") or 0) < now() - 0.3 then
			return false
		end
		-- Мерцание: прозрачность дышит, под конец мигает чаще.
		local flicker = math.sin(t * (left < 0.8 and 30 or 6)) * 0.06
		setCharacterAlpha(character, math.clamp(base + flicker, 0, 0.97))
		return true
	end, function()
		if state.alive then
			veilOff(caster, false)
		end
	end)
end

local function onVeil(payload)
	if payload.phase == "on" then
		veilOn(payload)
	else
		veilOff(payload.caster, payload.ambush == true)
	end
end

-- ===== Дебафы на врагах =====

local debuffFx = {} -- model -> kind -> { emitters, untilT }
local DEBUFF_SOUND = { burn = "debuffBurn", poison = "debuffPoison", slow = "debuffSlow", sunder = "debuffSunder" }

local function debuffEmitters(model, kind: string)
	local root = model.PrimaryPart
	local list = {}
	local spec = LootMage.Debuffs[kind]
	local color = Kit.color(spec and spec.color, WHITE)
	if kind == "burn" then
		table.insert(list, Kit.emitter(root, { texture = "glow", color = { "#FFF0B0", "#FF7A1F", "#C2381A" }, size = { 1.2, 0.2 },
			rate = 30, life = { 0.3, 0.55 }, speed = { 2, 5 }, spread = 25, direction = Enum.NormalId.Top, accel = V3(0, 6, 0),
			shape = Enum.ParticleEmitterShape.Box, transparency = { 0.15, 1 } }))
		table.insert(list, Kit.emitter(root, { texture = "spark", color = { "#FFF0B0", "#FF5A1F" }, size = { 0.25, 0 }, rate = 14,
			life = { 0.5, 0.9 }, speed = { 2, 4 }, spread = 40, direction = Enum.NormalId.Top, shape = Enum.ParticleEmitterShape.Box }))
	elseif kind == "poison" then
		table.insert(list, Kit.emitter(root, { texture = "glow", color = { "#F4FFC8", "#8EE04A", "#3E8A2A" }, size = { 0.5, 0 },
			rate = 16, life = { 0.6, 1.0 }, speed = { 0.5, 1.5 }, spread = 180, accel = V3(0, 2, 0),
			shape = Enum.ParticleEmitterShape.Box, transparency = { 0.2, 1 } }))
		table.insert(list, Kit.emitter(root, { texture = "smoke", color = { "#8EE04A", "#2A4A1A" }, size = { 1.2, 2.2 }, rate = 5,
			life = { 0.8, 1.2 }, speed = { 0.3, 0.8 }, transparency = { 0.6, 1 }, lightEmission = 0.2, shape = Enum.ParticleEmitterShape.Box }))
	elseif kind == "slow" then
		table.insert(list, Kit.emitter(root, { texture = "star", color = { "#FFFFFF", "#9DD8FF" }, size = { 0.4, 0 }, rate = 12,
			life = { 0.6, 1.0 }, speed = { 0.5, 1 }, spread = 180, accel = V3(0, -3, 0), shape = Enum.ParticleEmitterShape.Box,
			rotSpeed = { -90, 90 } }))
		table.insert(list, Kit.emitter(root, { texture = "ring", color = { color, color }, size = { 3.6, 4.2 }, rate = 2,
			life = 0.8, speed = 0, orientation = Enum.ParticleOrientation.FacingCameraWorldUp, transparency = { 0.5, 1 } }))
	elseif kind == "sunder" then
		table.insert(list, Kit.emitter(root, { texture = "rock", color = { "#F2EAD0", "#8A7A60" }, size = { 0.35, 0.1 }, rate = 8,
			life = { 0.5, 0.8 }, speed = { 2, 4 }, spread = 70, direction = Enum.NormalId.Top, accel = V3(0, -20, 0),
			shape = Enum.ParticleEmitterShape.Box, lightEmission = 0.2, lightInfluence = 0.6 }))
		table.insert(list, Kit.emitter(root, { texture = "crack", color = { color, color }, size = { 2.6, 2.6 }, rate = 1.5,
			life = 0.6, speed = 0, transparency = { 0.3, 1 } }))
	end
	return list
end

local function clearDebuff(model, kind: string)
	local entry = debuffFx[model] and debuffFx[model][kind]
	if not entry then
		return
	end
	debuffFx[model][kind] = nil
	for _, e in ipairs(entry.emitters) do
		e.Enabled = false
		game:GetService("Debris"):AddItem(e, 1.2)
	end
end

local function onDebuff(payload)
	local model = payload.model
	local kind = payload.debuff
	if not model or not model.Parent or not model.PrimaryPart or type(kind) ~= "string" then
		return
	end
	if (payload.untilT or 0) <= now() then
		clearDebuff(model, kind)
		return
	end
	debuffFx[model] = debuffFx[model] or {}
	local entry = debuffFx[model][kind]
	if entry then
		entry.untilT = payload.untilT
		return
	end
	debuffFx[model][kind] = { emitters = debuffEmitters(model, kind), untilT = payload.untilT }
	local position = model.PrimaryPart.Position
	local spec = LootMage.Debuffs[kind]
	Kit.burst(position, { texture = kind == "sunder" and "rock" or (kind == "slow" and "star" or "glow"),
		color = { WHITE, Kit.color(spec and spec.color, WHITE) }, size = { 0.6, 0 }, count = 10, life = { 0.3, 0.5 }, speed = { 4, 8 } })
	Kit.sfx(DEBUFF_SOUND[kind] or "passiveProc", position, 0.7)
end

local function sweepDebuffs()
	local t = now()
	for model, kinds in pairs(debuffFx) do
		if not model.Parent or (model:GetAttribute("EnemyHealth") or 0) <= 0 then
			for kind in pairs(kinds) do
				clearDebuff(model, kind)
			end
			debuffFx[model] = nil
		else
			for kind, entry in pairs(kinds) do
				if entry.untilT <= t then
					clearDebuff(model, kind)
				end
			end
			if next(kinds) == nil then
				debuffFx[model] = nil
			end
		end
	end
end

-- ===== Лечение и пассивки =====

local function onHeal(payload)
	local _, root = Kit.characterOf(payload.caster)
	if not root then
		return
	end
	Kit.stream(CFrame.new(root.Position - V3(0, 2.6, 0)), { texture = "star", color = { "#FFFFFF", "#9CFFB0", "#FFD45A" },
		size = { 0.5, 0 }, rate = 50, life = { 0.6, 1.0 }, speed = { 3, 6 }, spread = 20, direction = Enum.NormalId.Top,
		shape = Enum.ParticleEmitterShape.Disc, size3 = V3(3, 0.2, 3), rotSpeed = { -200, 200 } }, 0.4)
	Kit.ringWave(Kit.ground(root.Position - V3(0, 2.8, 0), 0.1), 3, Color3.fromRGB(140, 255, 170), { time = 0.5 })
	Kit.light(root, Color3.fromRGB(150, 255, 180), 3, 10, 0.6)
	if payload.caster == player then
		Kit.sfx("heal", root.Position, 0.7)
	end
end

local function billboard(model, name: string, size: number, offsetY: number)
	local root = model.PrimaryPart
	local old = root:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromScale(size, size)
	gui.StudsOffsetWorldSpace = V3(0, offsetY, 0)
	gui.LightInfluence = 0
	gui.Brightness = 2.5
	gui.AlwaysOnTop = true
	gui.Adornee = root
	gui.Parent = root
	return gui
end

local function markHunter(model, untilT: number)
	if not model or not model.PrimaryPart then
		return
	end
	local height = model:GetAttribute("EnemyHeight") or 3
	local gui = billboard(model, "MageHunterMark", 2.2, height * 0.6 + 1.4)
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.8, 0.8)
	ring.BackgroundTransparency = 1
	ring.Parent = gui
	Instance.new("UICorner", ring).CornerRadius = UDim.new(0.5, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 196, 90)
	stroke.Thickness = 3
	stroke.Parent = ring
	for i = 0, 3 do
		local tick = Instance.new("Frame")
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.BackgroundColor3 = Color3.fromRGB(255, 120, 60)
		tick.BorderSizePixel = 0
		local a = i * math.pi / 2
		tick.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.46, 0.5 + math.sin(a) * 0.46)
		tick.Size = (i % 2 == 0) and UDim2.fromScale(0.22, 0.06) or UDim2.fromScale(0.06, 0.22)
		tick.Parent = ring
	end
	Kit.every(math.max(untilT - now(), 0.3) + 0.1, function(_, t)
		if not gui.Parent then
			return false
		end
		ring.Rotation = t * 90
		local pulse = 1 + math.sin(t * 8) * 0.06
		ring.Size = UDim2.fromScale(0.8 * pulse, 0.8 * pulse)
		return now() < untilT
	end, function()
		gui:Destroy()
	end)
end

local function footnoteMark(model, delay: number)
	if not model or not model.PrimaryPart then
		return
	end
	local height = model:GetAttribute("EnemyHeight") or 3
	local gui = billboard(model, "MageFootnote", 1.6, height * 0.6 + 1.2)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "†"
	label.TextScaled = true
	label.Font = Enum.Font.Garamond
	label.TextColor3 = Color3.fromRGB(210, 196, 255)
	label.TextStrokeColor3 = Color3.fromRGB(20, 18, 42)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	Kit.every(delay + 0.1, function(k)
		if not gui.Parent then
			return false
		end
		label.TextTransparency = 0.5 - 0.5 * k
		label.Rotation = math.sin(k * 30) * 8 * k
		return true
	end, function()
		gui:Destroy()
	end)
end

local function onPassive(payload)
	local id = payload.id
	local position = payload.position
	if id == "key_resonance" then
		local from = (position or V3()) + V3(0, 2.4, 0)
		local gold = Color3.fromRGB(255, 212, 90)
		Kit.flash(from, gold, 3, 0.2)
		for i, target in ipairs(payload.targets or {}) do
			if typeof(target) == "Vector3" then
				Kit.after(i * 0.04, function()
					Kit.lightning(from, target + V3(0, 2.4, 0), gold, { width = 0.16, time = 0.22, core = WHITE })
				end)
			end
		end
		Kit.burst(from, { texture = "star", color = { "#FFFFFF", "#FFD45A" }, size = { 0.6, 0 }, count = 12,
			life = { 0.3, 0.5 }, speed = { 6, 12 } })
		Kit.sfx("passiveProc", from)
	elseif id == "dew" then
		local _, root = Kit.characterOf(payload.caster)
		if root then
			Kit.burst(root.Position, { texture = "glow", color = { "#EFFFFF", "#4FD6FF" }, size = { 0.6, 0 }, count = 18,
				life = { 0.4, 0.7 }, speed = { 4, 8 }, accel = V3(0, -12, 0) })
			Kit.ringWave(Kit.ground(root.Position - V3(0, 2.8, 0), 0.1), 3.5, Color3.fromRGB(80, 214, 255), { time = 0.5 })
			Kit.sfx("passiveProc", root.Position, 0.7)
		end
	elseif id == "hunter_mark" then
		if payload.phase == "mark" then
			markHunter(payload.model, payload.untilT or now() + 6)
		elseif payload.phase == "falcon" and position then
			local caster = payload.caster
			local _, root = Kit.characterOf(caster)
			local from = (root and root.Position or position) + V3(0, 12, 0)
			MageSpellFx.falcon(from, position, 0.28, Color3.fromRGB(255, 200, 110), true)
		end
	elseif id == "tempering" then
		if position then
			Kit.explosion(position + V3(0, 1.2, 0), payload.radius or 3.5, Color3.fromRGB(255, 138, 42),
				{ core = Color3.fromRGB(255, 240, 200), embers = 12, ground = Kit.ground(position, 0.1) })
			Kit.sfx("passiveBlast", position)
		end
	elseif id == "footnote" then
		if payload.phase == "mark" then
			footnoteMark(payload.model, payload.delay or 1.5)
		elseif payload.phase == "burst" and position then
			local p = position + V3(0, 2.4, 0)
			Kit.flash(p, Color3.fromRGB(106, 88, 216), 3, 0.2)
			Kit.burst(p, { texture = "glow", color = { "#D2C4FF", "#14122A" }, size = { 0.8, 0 }, count = 16,
				life = { 0.3, 0.6 }, speed = { 6, 12 }, lightEmission = 0.4 })
			Kit.sfx("passiveProc", p, 0.8)
		end
	elseif id == "blot" then
		if position then
			local ground = Kit.ground(position, 0.06)
			local radius = payload.radius or 2.5
			local life = payload.time or 3
			Kit.glowSpot(ground, radius, Color3.fromRGB(40, 30, 90), life, { transparency = 0.1, brightness = 1.2 })
			Kit.glowSpot(ground, radius * 0.7, Color3.fromRGB(106, 88, 216), life, { transparency = 0.45, lift = 0.1 })
			Kit.stream(CFrame.new(ground), { texture = "glow", color = { "#6A58D8", "#14122A" }, size = { 0.5, 0 }, rate = 10,
				life = { 0.5, 0.9 }, speed = { 0.5, 1.5 }, spread = 20, direction = Enum.NormalId.Top, size3 = V3(radius * 1.6, 0.2, radius * 1.6),
				shape = Enum.ParticleEmitterShape.Box, lightEmission = 0.3 }, life)
			Kit.sfx("spellInk", ground, 0.6)
		end
	elseif id == "cinders" then
		if position then
			Kit.explosion(position + V3(0, 1.2, 0), payload.radius or 4, Color3.fromRGB(255, 90, 30),
				{ core = Color3.fromRGB(255, 230, 160), embers = 18, ground = Kit.ground(position, 0.1) })
			Kit.sfx("passiveBlast", position)
		end
	elseif id == "casting_heat" then
		local tip = Kit.tipOf(payload.caster)
		if tip then
			Kit.flash(tip, Color3.fromRGB(255, 120, 30), 2.4, 0.2)
			Kit.burst(tip, { texture = "spark", color = { "#FFF0B0", "#FF5A1F" }, size = { 0.4, 0 }, count = 14,
				life = { 0.3, 0.5 }, speed = { 5, 10 }, accel = V3(0, -20, 0) })
			Kit.sfx("passiveProc", tip, 0.7)
		end
	end
end

-- ===== Постоянное: аура посоха, жар, роса =====

local auras = {} -- player -> { model, light, emitters, style }
local dewDrops = {} -- player -> { parts }

local function auraFor(other)
	local character = other.Character
	local weapon = character and character:FindFirstChild("EquippedWeapon")
	local primary = weapon and weapon.PrimaryPart
	local tip = primary and primary:FindFirstChild("BladeTip")
	local entry = auras[other]
	local isStaff = other:GetAttribute("WeaponType") == "staff"
	if entry and (entry.model ~= weapon or not isStaff or not entry.tip.Parent) then
		for _, e in ipairs(entry.emitters) do
			e:Destroy()
		end
		if entry.light then
			entry.light:Destroy()
		end
		auras[other] = nil
		entry = nil
	end
	if entry or not isStaff or not tip then
		return entry
	end
	local item = LootMage.Items[other:GetAttribute("WeaponId") or ""]
	local styleName = item and item.bolt and item.bolt.style or "arcane"
	local style = styleOf(styleName)
	local emitters = {}
	local function add(o)
		local e = Kit.emitter(tip, o)
		table.insert(emitters, e)
		return e
	end
	add({ texture = "glow", color = { style.core, style.glow }, size = { 0.9, 0 }, rate = 8, life = { 0.3, 0.5 }, speed = 0,
		transparency = { 0.4, 1 }, zoffset = 0.5 })
	if style.shape == "flame" then
		add({ texture = "glow", color = { style.core, style.glow, style.trail }, size = { 0.6, 0.1 }, rate = 22, life = { 0.3, 0.5 },
			speed = { 1, 2.5 }, spread = 15, accel = V3(0, 4, 0), transparency = { 0.2, 1 } })
	elseif style.shape == "spark" then
		add({ texture = "spark", color = { WHITE, style.glow }, size = { 0.3, 0 }, rate = 10, life = { 0.06, 0.14 }, speed = { 3, 6 } })
	elseif style.shape == "wisp" then
		add({ texture = "swirl", color = { style.core, style.glow }, size = { 0.8, 0 }, rate = 6, life = { 0.5, 0.8 },
			speed = { 0.3, 0.8 }, accel = V3(0, 1.5, 0), transparency = { 0.4, 1 } })
	elseif style.shape == "blob" then
		add({ texture = "glow", color = { style.glow, style.trail }, size = { 0.3, 0 }, rate = 5, life = { 0.5, 0.8 },
			speed = { 0.2, 0.6 }, accel = V3(0, -8, 0) })
	elseif style.shape == "page" then
		add({ texture = "star", color = { style.core, style.glow }, size = { 0.3, 0 }, rate = 5, life = { 0.6, 1 },
			speed = { 0.3, 0.8 }, rotSpeed = { -200, 200 } })
	else
		add({ texture = "star", color = { style.core, style.glow }, size = { 0.3, 0 }, rate = 6, life = { 0.5, 0.9 },
			speed = { 0.3, 1 }, rotSpeed = { -200, 200 } })
	end
	local heat = add({ texture = "spark", color = { "#FFF0B0", "#FF5A1F" }, size = { 0.3, 0 }, rate = 0, life = { 0.3, 0.6 },
		speed = { 2, 5 }, accel = V3(0, 5, 0) })
	local light = Kit.light(tip.Parent, style.glow, 1.2, 7)
	entry = { model = weapon, tip = tip, emitters = emitters, light = light, style = style, heat = heat }
	auras[other] = entry
	return entry
end

local function updateAuras()
	for _, other in ipairs(Players:GetPlayers()) do
		local ok, entry = pcall(auraFor, other)
		if ok and entry then
			-- «Закалка»: посох раскаляется (MageHeat 0..10).
			local heat = math.clamp((other:GetAttribute("MageHeat") or 0) / 10, 0, 1)
			entry.light.Brightness = 1.2 + heat * 3
			entry.light.Color = entry.style.glow:Lerp(Color3.fromRGB(255, 110, 30), heat)
			entry.heat.Rate = heat * 30
			entry.heat.Enabled = heat > 0
		end
	end
	for other in pairs(auras) do
		if not other.Parent then
			auras[other] = nil
		end
	end
end

local function updateDew(_dt: number)
	local t = os.clock()
	for _, other in ipairs(Players:GetPlayers()) do
		local count = math.clamp(other:GetAttribute("MageDew") or 0, 0, 8)
		local entry = dewDrops[other]
		if count > 0 and not entry then
			entry = { parts = {} }
			dewDrops[other] = entry
		end
		if entry then
			while #entry.parts < count do
				local drop = Kit.ball(V3(), 0.35, Color3.fromRGB(110, 220, 255), { Transparency = 0.15, Name = "MageDew" })
				table.insert(entry.parts, drop)
			end
			while #entry.parts > count do
				local drop = table.remove(entry.parts)
				Kit.fade(drop, 0.2, { Size = V3(0.8, 0.8, 0.8) })
			end
			local _, root = Kit.characterOf(other)
			for i, drop in ipairs(entry.parts) do
				if root then
					local a = t * 2.2 + (i - 1) / math.max(count, 1) * TAU
					drop.CFrame = CFrame.new(root.Position + V3(math.cos(a) * 1.9, 0.4 + math.sin(t * 3 + i) * 0.25, math.sin(a) * 1.9))
				end
			end
			if count == 0 then
				dewDrops[other] = nil
			end
		end
	end
end

-- Свой удар посохом: вспышка на навершии и звук каста в момент выброса.
local function onAnimation(name: string, data)
	if name ~= "attack" or type(data) ~= "table" or data.typeId ~= "staff" then
		return
	end
	task.delay(math.max((data.strikeDelay or 0.1) - 0.02, 0), function()
		local tip = Kit.tipOf(player)
		if not tip then
			return
		end
		local item = LootMage.Items[player:GetAttribute("WeaponId") or ""]
		local style = styleOf(item and item.bolt and item.bolt.style or "arcane")
		local combo = math.clamp(data.combo or 1, 1, 3)
		muzzleFlash(tip, style, combo == 3 and 1.4 or 1)
		if combo == 3 then
			Kit.burst(tip, { texture = "ring", color = { style.core, style.glow }, size = { 0.4, 3 }, count = 1, life = 0.2, speed = 0 })
		end
		Kit.sfx("mageCast" .. combo, tip)
	end)
end

-- ===== События =====

local HANDLERS = {
	bolt = onBolt,
	boltHit = onBoltHit,
	boltEnd = onBoltEnd,
	chain = onChain,
	wave = onWave,
	beam = onBeam,
	nova = onNova,
	barrier = onBarrier,
	veil = onVeil,
	debuff = onDebuff,
	heal = onHeal,
	passive = onPassive,
	spell = function(payload)
		MageSpellFx.handle(payload)
	end,
}
MageFx.HANDLERS = HANDLERS

local function onEvent(payload)
	if type(payload) ~= "table" then
		return
	end
	local handler = HANDLERS[payload.kind]
	if not handler then
		return
	end
	local ok, err = pcall(handler, payload)
	if not ok then
		warn("[MageFx] " .. tostring(payload.kind) .. ": " .. tostring(err))
	end
end

function MageFx.start()
	for _, d in ipairs(Workspace:GetDescendants()) do
		track(d)
	end
	Workspace.DescendantAdded:Connect(track)
	Workspace.DescendantRemoving:Connect(function(instance)
		enemies[instance] = nil
	end)
	MageSpellFx.setEnemies(enemies)

	local remote = Net.get("MageFx")
	if remote then
		remote.OnClientEvent:Connect(onEvent)
	else
		warn("[MageFx] нет RemoteEvent MageFx")
	end
	PlayerAnimator.onEvent(onAnimation)

	task.spawn(function()
		while true do
			pcall(updateAuras)
			pcall(sweepDebuffs)
			task.wait(0.25)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(updateDew, dt)
		if not ok then
			warn("[MageFx] dew: " .. tostring(err))
		end
	end)
	Players.PlayerRemoving:Connect(function(other)
		veils[other] = nil
		auras[other] = nil
		local entry = dewDrops[other]
		if entry then
			for _, drop in ipairs(entry.parts) do
				drop:Destroy()
			end
			dewDrops[other] = nil
		end
	end)
	print("[MageFx] эффекты мага запущены")
end

return MageFx
