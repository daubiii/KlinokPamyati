--!nonstrict
-- BossIntroScenes (клиент)
-- Сценарии сцен появления пяти боссов (Config/BossIntros): кадры камеры и
-- процедурные декорации по отметкам beats. Режиссёр — BossIntroController:
-- он даёт ctx (система координат босса, время сцены τ, тряска, вспышки,
-- реестр деталей) и сам ведёт полосы, титр, оттенок и выход из сцены.
--
-- Координаты сценария — (a, s, y) от ног босса B: a — вперёд, туда, куда он
-- смотрит (к игроку), s — вправо, y — вверх. ref = "head" | "chest" | "root"
-- — от соответствующей части модели (крупные планы следят за анимацией).
--
-- Кадры камеры: { t, pos, look, fov, cut, fn }. Между ключами — плавно
-- (sine), cut — склейка, fn(ctx, τ) → pos, look, fov — свой ход камеры.

local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.Parent.Lib.BossFxKit)
local EnemyFx = require(script.Parent.EnemyFx)

local BossIntroScenes = {}

local V3 = Vector3.new
local rgb = Color3.fromRGB
local TAU = math.pi * 2
local TEX = Kit.TEX
local random = Kit.random

local function ease(k: number): number
	k = math.clamp(k, 0, 1)
	return 1 - (1 - k) * (1 - k)
end

local function easeIn(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k
end

local function smooth(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

local function span(tau: number, a: number, b: number): number
	return math.clamp((tau - a) / math.max(b - a, 1e-3), 0, 1)
end

-- Видимость модели босса (LocalTransparencyModifier): 0 — видна, 1 — нет.
-- filter(part) → видимость отдельной детали (скан летописца).
local function setHidden(ctx, value: number, filter)
	local rig = ctx:rig()
	if not rig or not rig.model then
		return
	end
	for _, d in ipairs(rig.model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = filter and filter(d) or value
		elseif d:IsA("Decal") then
			d.Transparency = (filter and filter(d.Parent) or value) >= 1 and 1 or 0
		end
	end
end

-- Подсветка-оболочка модели (мрамор, раскалённый металл).
local function shell(ctx, color: Color3, fill: number)
	local rig = ctx:rig()
	if not rig or not rig.model then
		return nil
	end
	local h = ctx.state.highlight
	if not h or not h.Parent then
		h = Instance.new("Highlight")
		h.Name = "IntroShell"
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.OutlineTransparency = 1
		h.Adornee = rig.model
		h.Parent = rig.model
		ctx.state.highlight = h
		ctx:add(h)
	end
	h.FillColor = color
	h.FillTransparency = fill
	return h
end

local function eyes(ctx, on: boolean)
	local rig = ctx:rig()
	if not rig or not rig.fx then
		return
	end
	if on then
		EnemyFx.eyesOn(rig)
	else
		EnemyFx.eyesOff(rig)
	end
end

-- Деталь с регистрацией в сцене.
local function prop(ctx, props, class: string?)
	return ctx:add(Kit.part(props, class))
end

local function floorAt(ctx, p: Vector3): Vector3
	return V3(p.X, Kit.groundY(p, ctx.B.Y), p.Z)
end

local Scenes = {}
BossIntroScenes.Scenes = Scenes

-- ======================================================================
-- Привратник: ворота захлопываются, ключи слетаются в грудь, меч в пол
-- ======================================================================

local GOLD = rgb(255, 198, 86)
local IRON = rgb(74, 76, 86)
local DUST = rgb(150, 136, 118)

local function buildKey(ctx, at: Vector3, yaw: number)
	local list = {}
	local function add(size: Vector3, offset: Vector3, shape)
		local p = prop(ctx, { Name = "IntroKey", Size = size, Color = GOLD, Material = Enum.Material.Metal, Shape = shape or Enum.PartType.Block, CastShadow = true })
		table.insert(list, { part = p, offset = CFrame.new(offset) * (shape == Enum.PartType.Cylinder and CFrame.Angles(0, math.pi / 2, 0) or CFrame.identity) })
	end
	add(V3(0.22, 0.22, 1.5), V3(0, 0, 0))
	add(V3(0.16, 0.85, 0.85), V3(0, 0, -1.05), Enum.PartType.Cylinder)
	add(V3(0.16, 0.48, 0.38), V3(0, -0.3, 0.55))
	add(V3(0.16, 0.3, 0.2), V3(0, -0.24, 0.2))
	return { parts = list, home = CFrame.new(at) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.pi / 2, 0, 0) }
end

local function placeList(list, cf: CFrame)
	local parts, frames = {}, {}
	for _, item in ipairs(list) do
		table.insert(parts, item.part)
		table.insert(frames, cf * item.offset)
	end
	Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

Scenes.gatekeeper = {
	H = 9.6,
	setup = function(ctx)
		local st = ctx.state
		st.keys = {}
		for index = 1, 12 do
			local a = (index / 12) * TAU + random:NextNumber(-0.2, 0.2)
			local r = random:NextNumber(4.5, 9)
			local p = floorAt(ctx, ctx:at(math.cos(a) * r, math.sin(a) * r, 0)) + V3(0, 0.15, 0)
			local key = buildKey(ctx, p, random:NextNumber(0, TAU))
			key.delay = (index - 1) * 0.11
			placeList(key.parts, key.home)
			table.insert(st.keys, key)
		end
		local anchor = Kit.emitter(ctx:at(0, 0, 9), {
			tex = TEX.smoke, color = DUST, rate = 10, box = V3(26, 10, 26), life = { 3, 5 }, speed = { 0.2, 0.6 }, spread = 180,
			size = Kit.nseq({ { 0, 0.4 }, { 1, 0.8 } }), transp = Kit.nseq({ { 0, 1 }, { 0.3, 0.75 }, { 1, 1 } }), light = 0.2, accel = V3(0, -0.4, 0),
		}, ctx.cfg.full + 1)
		ctx:add(anchor)
		st.glow = prop(ctx, { Name = "ChestKeyGlow", Shape = Enum.PartType.Ball, Size = V3(0.4, 0.4, 0.4), Color = GOLD, Material = Enum.Material.Neon, Transparency = 1 })
		local light = Instance.new("PointLight")
		light.Color = GOLD
		light.Range = 14
		light.Brightness = 0
		light.Parent = st.glow
		st.light = light
		st.arrived = 0
		if ctx.start < ctx.cfg.beats.eyes then
			eyes(ctx, false)
		end
	end,
	update = function(ctx, tau, dt)
		local st = ctx.state
		local beats = ctx.cfg.beats
		local slam, slamLate = ctx:beat("slam")
		if slam and not slamLate then
			ctx:sfx("vaultOpen", ctx:at(14, 0, 3))
			ctx:sfx("bmGateSlam", ctx:at(10, 0, 3))
			ctx:shake(0.9, 0.5)
			ctx:flash(rgb(0, 0, 0), 0.2, 0.6)
			for _ = 1, 3 do
				Kit.smoke(ctx:at(random:NextNumber(-6, 6), random:NextNumber(-6, 6), 10), DUST, 6, 3, -2)
			end
		end
		local chest = ctx:part("chest")
		-- Ключи взлетают по спирали и входят в грудь.
		for index, key in ipairs(st.keys) do
			local from = beats.keys + key.delay
			local k = span(tau, from, from + 0.9)
			if tau >= from and not key.done then
				if not key.lifted then
					key.lifted = true
					if index % 3 == 1 and tau - from < 0.3 then
						ctx:sfx("chainRattle", key.home.Position)
					end
				end
				local start = key.home.Position
				local mid = start:Lerp(chest, 0.5) + V3(0, 4, 0)
				local p = start:Lerp(mid, ease(k)):Lerp(mid:Lerp(chest, ease(k)), easeIn(k))
				placeList(key.parts, CFrame.lookAt(p, chest + V3(0, 1e-3, 0)) * CFrame.Angles(0, 0, tau * 9))
				if k >= 1 then
					key.done = true
					st.arrived += 1
					Kit.flash(chest, GOLD, 2.2, 0.2)
					Kit.sparks(chest, GOLD, 6, 10)
					for _, item in ipairs(key.parts) do
						item.part:Destroy()
					end
				end
			end
		end
		if ctx.start > beats.keys + 1.5 then
			for _, key in ipairs(st.keys) do
				if not key.done then
					key.done = true
					for _, item in ipairs(key.parts) do
						item.part:Destroy()
					end
				end
			end
			st.arrived = #st.keys
		end
		local glow = math.clamp(st.arrived / #st.keys, 0, 1) * (1 - span(tau, beats.roar + 0.4, ctx.cfg.full))
		st.glow.CFrame = CFrame.new(chest + ctx.F * 0.6)
		st.glow.Transparency = 1 - 0.75 * glow
		local s = 0.4 + 1.4 * glow
		st.glow.Size = V3(s, s, s)
		st.light.Brightness = 5 * glow
		local fired, late = ctx:beat("eyes")
		if fired then
			eyes(ctx, true)
			if not late then
				ctx:sfx("bmKeyStab", ctx:part("head"))
			end
		end
		local rise, riseLate = ctx:beat("rise")
		if rise and not riseLate then
			ctx:sfx("chainRattle", ctx.B)
		end
		local plant, plantLate = ctx:beat("plant")
		if plant and not plantLate then
			ctx:sfx("bmGateSlam", ctx.B)
			ctx:shake(1.1, 0.45)
			ctx:punch(-8, 0.35)
			local tip = ctx:at(2.2, 0.6, 0)
			Kit.shockRing(tip, 16, GOLD, 0.6)
			Kit.smoke(tip + V3(0, 0.4, 0), DUST, 12, 3.5)
			Kit.burst(tip + V3(0, 0.4, 0), 18, { DUST, IRON, GOLD }, 0.5, 26, 0.9, ctx.B.Y + 0.1)
			Kit.sparks(tip + V3(0, 0.5, 0), GOLD, 30, 24)
			for index = 1, 9 do
				local a = (index / 9) * TAU + random:NextNumber(-0.2, 0.2)
				local length = random:NextNumber(6, 12)
				local dx, dz = math.cos(a), math.sin(a)
				local crack = ctx:add(Kit.beamPart(tip + V3(0, 0.09, 0), tip + V3(dx * 0.5, 0.09, dz * 0.5), random:NextNumber(0.25, 0.45), 0.05, GOLD, true, 0.15))
				st.cracks = st.cracks or {}
				table.insert(st.cracks, { part = crack, from = tip, dir = V3(dx, 0, dz), length = length })
			end
		end
		for _, c in ipairs(st.cracks or {}) do
			if c.dir then
				local k = ease(span(tau, beats.plant, beats.plant + 0.35))
				Kit.placeBeam(c.part, c.from + V3(0, 0.09, 0), c.from + c.dir * (0.5 + c.length * k) + V3(0, 0.09, 0))
				c.part.Transparency = 0.15 + 0.6 * span(tau, beats.roar + 0.8, ctx.cfg.full)
			end
		end
	end,
	shots = {
		{ t = 0.0, pos = { 16, -6, 7.5 }, look = { 0, 0, 3 }, fov = 55 },
		{ t = 1.7, pos = { 13, -4, 6 }, look = { 0, 0, 3.2 }, fov = 52 },
		{ t = 1.7, cut = true, pos = { 7.5, 6.5, 2.4 }, look = { 0, 0, 3.6 }, fov = 50 },
		{ t = 3.5, pos = { 6, 3.6, 3.2 }, look = { 0, 0, 4.2 }, fov = 46 },
		{ t = 3.5, cut = true, pos = { 3.2, 0.5, 0.3, ref = "head" }, look = { 0, 0, 0, ref = "head" }, fov = 36 },
		{ t = 3.9, pos = { 3.6, 0.7, 0.3, ref = "head" }, look = { 0, 0, 0, ref = "head" }, fov = 38 },
		{ t = 4.0, pos = { 5, -3, 1.2 }, look = { 0, 0, 0, ref = "head" }, fov = 50 },
		{ t = 5.85, pos = { 10, -5, 1.0 }, look = { 0, 0, 0, ref = "head" }, fov = 58 },
		{ t = 5.9, cut = true, pos = { 15, 3, 2.2 }, look = { 0, 0, 4 }, fov = 60 },
		{ t = 6.3, pos = { 13.5, 2.6, 2.0 }, look = { 0, 0, 4.4 }, fov = 58 },
		{ t = 6.35, pos = { 9, 1.5, 1.6 }, look = { 0, 0, 0, ref = "head" }, fov = 52 },
		{ t = 8.0, pos = { 11, 2.5, 3.5 }, look = { 0, 0, 6 }, fov = 60 },
	},
}

-- ======================================================================
-- Хранительница роз: статуя в лозах трескается, оживает, сад расцветает
-- ======================================================================

local MARBLE = rgb(224, 222, 214)
local MARBLE_DARK = rgb(150, 148, 142)
local VINE = rgb(52, 104, 56)
local LEAF = rgb(92, 160, 80)
local ROSE = rgb(218, 64, 104)
local PETAL = rgb(255, 156, 186)
local JADE = rgb(124, 242, 176)
local WATER = rgb(92, 168, 214)

Scenes.rosewarden = {
	H = 10,
	setup = function(ctx)
		local st = ctx.state
		local beats = ctx.cfg.beats
		-- Чаша фонтана: кольцо мраморных блоков и вода.
		for index = 1, 18 do
			local a = index / 18 * TAU
			local p = ctx:at(math.cos(a) * 4.2, math.sin(a) * 4.2, 0.4)
			prop(ctx, { Name = "Basin", Size = V3(1.6, 0.8, 1.0), CFrame = CFrame.lookAt(p, ctx.B + V3(0, 0.4, 0)), Color = MARBLE, Material = Enum.Material.Marble, CastShadow = true })
		end
		st.water = ctx:add(Kit.disc(ctx.B, 4.0, WATER, 0.35, 0.18))
		local petals = Kit.emitter(ctx:at(0, 0, 14), {
			tex = TEX.glow, color = Kit.cseq(PETAL, ROSE), rate = 18, box = V3(24, 1, 24), life = { 4, 6 }, speed = { 0.5, 1.5 }, spread = 180,
			size = Kit.nseq({ { 0, 0.22 }, { 1, 0.18 } }), transp = Kit.nseq({ { 0, 0.2 }, { 1, 1 } }), light = 0.3, accel = V3(0.6, -2.2, 0.3), rot = 160,
		}, ctx.cfg.full + 1)
		ctx:add(petals)
		local mist = Kit.emitter(ctx:at(0, 0, 0.6), {
			tex = TEX.smoke, color = rgb(200, 226, 214), rate = 8, box = V3(30, 0.5, 30), life = { 4, 6 }, speed = { 0.2, 0.6 }, spread = 180,
			size = Kit.nseq({ { 0, 4 }, { 1, 7 } }), transp = Kit.nseq({ { 0, 1 }, { 0.4, 0.8 }, { 1, 1 } }), light = 0.1,
		}, ctx.cfg.full + 1)
		ctx:add(mist)
		-- Лозы: спирали вокруг статуи от пола к груди.
		st.vines = {}
		for v = 1, 6 do
			local vine = { segments = {}, phase = v / 6 * TAU }
			for index = 1, 16 do
				local seg = prop(ctx, { Name = "Vine", Size = V3(0.32, 0.32, 1), Color = VINE, Material = Enum.Material.Grass, Transparency = 1 })
				local leaf
				if index % 3 == 0 then
					leaf = prop(ctx, { Name = "Leaf", Size = V3(0.7, 0.08, 0.45), Color = LEAF, Material = Enum.Material.Grass, Transparency = 1 })
				end
				table.insert(vine.segments, { part = seg, leaf = leaf })
			end
			vine.bud = prop(ctx, { Name = "Bud", Shape = Enum.PartType.Ball, Size = V3(0.6, 0.6, 0.6), Color = ROSE, Material = Enum.Material.Neon, Transparency = 1 })
			table.insert(st.vines, vine)
		end
		-- Розы вокруг: распускаются на bloom.
		st.roses = {}
		for index = 1, 22 do
			local a = index / 22 * TAU + random:NextNumber(-0.12, 0.12)
			local r = index % 2 == 0 and random:NextNumber(5.2, 7.5) or 4.2
			local base = floorAt(ctx, ctx:at(math.cos(a) * r, math.sin(a) * r, 0))
			local stem = prop(ctx, { Name = "Stem", Size = V3(0.2, 0.1, 0.2), Color = VINE, Material = Enum.Material.Grass, CFrame = CFrame.new(base) })
			local rose = prop(ctx, { Name = "Rose", Shape = Enum.PartType.Ball, Size = V3(0.1, 0.1, 0.1), Color = index % 3 == 0 and PETAL or ROSE, Material = Enum.Material.Neon, CFrame = CFrame.new(base), Transparency = 1 })
			table.insert(st.roses, { stem = stem, rose = rose, base = base, h = random:NextNumber(1.2, 2.4), delay = random:NextNumber(0, 0.5) })
		end
		if ctx.start < beats.wake then
			shell(ctx, MARBLE, 0.3)
		end
		if ctx.start < beats.eyes then
			eyes(ctx, false)
		end
	end,
	update = function(ctx, tau, dt)
		local st = ctx.state
		local beats = ctx.cfg.beats
		local H = ctx.H
		-- Мрамор держится до пробуждения (на поздней сцене оболочки нет).
		local h = st.highlight
		if h and h.Parent then
			if tau < beats.crack then
				h.FillTransparency = 0.05
				h.OutlineTransparency = 1
			elseif tau < beats.wake then
				h.OutlineColor = JADE
				h.OutlineTransparency = 0.2 + 0.3 * math.sin(tau * 40)
				h.FillTransparency = 0.05 + 0.1 * span(tau, beats.crack, beats.wake)
			else
				h.FillTransparency = 0.15 + 0.85 * span(tau, beats.wake, beats.wake + 0.3)
				h.OutlineTransparency = 1
			end
		end
		-- Лозы ползут вверх.
		local grow = span(tau, beats.vines, beats.crack)
		local torn = tau >= beats.wake
		for v, vine in ipairs(st.vines) do
			local shown = math.floor(grow * #vine.segments + 0.5)
			local previous = ctx:at(math.cos(vine.phase) * 1.9, math.sin(vine.phase) * 1.9, 0.1)
			for index, seg in ipairs(vine.segments) do
				local k = index / #vine.segments
				local a = vine.phase + k * TAU * 0.9
				local radius = 1.9 - 0.5 * k
				local p = ctx:at(math.cos(a) * radius, math.sin(a) * radius, 0.1 + k * H * 0.72)
				if index <= shown and not torn then
					seg.part.Transparency = 0
					Kit.placeBeam(seg.part, previous, p)
					if seg.leaf then
						seg.leaf.Transparency = 0
						seg.leaf.CFrame = CFrame.lookAt(p, p + (p - previous)) * CFrame.new(0.35, 0, 0) * CFrame.Angles(0, 0, 0.4)
					end
				elseif not torn then
					seg.part.Transparency = 1
					if seg.leaf then
						seg.leaf.Transparency = 1
					end
				end
				if index == shown and not torn then
					vine.bud.Transparency = 0
					vine.bud.CFrame = CFrame.new(p)
				end
				previous = p
			end
			if torn and not vine.torn then
				vine.torn = true
				for _, seg in ipairs(vine.segments) do
					if seg.part.Transparency < 1 then
						Kit.bit(seg.part.Position, V3(random:NextNumber(-8, 8), random:NextNumber(4, 10), random:NextNumber(-8, 8)), VINE, 0.35, 1.0, false, ctx.B.Y + 0.1)
					end
					seg.part.Transparency = 1
					if seg.leaf then
						seg.leaf.Transparency = 1
					end
				end
				vine.bud.Transparency = 1
			end
			local _ = v
		end
		local vines, vinesLate = ctx:beat("vines")
		if vines and not vinesLate then
			ctx:sfx("bmVines", ctx.B)
		end
		local crack, crackLate = ctx:beat("crack")
		if crack and not crackLate then
			ctx:sfx("statueCrack", ctx:part("head"))
			ctx:shake(0.35, 0.3)
			Kit.burst(ctx:part("chest"), 6, { MARBLE, MARBLE_DARK }, 0.3, 8, 0.5, ctx.B.Y + 0.1, false, Enum.Material.Marble)
		end
		local eye, eyeLate = ctx:beat("eyes")
		if eye then
			eyes(ctx, true)
			if not eyeLate then
				Kit.flash(ctx:part("head"), JADE, 3, 0.3)
			end
		end
		local wake, wakeLate = ctx:beat("wake")
		if wake and not wakeLate then
			ctx:sfx("bmPetrify", ctx:part("chest"))
			ctx:sfx("statueCrack", ctx:part("chest"))
			ctx:shake(0.7, 0.35)
			ctx:flash(MARBLE, 0.55, 0.35)
			for _, ref in ipairs({ "head", "chest", "root" }) do
				Kit.burst(ctx:part(ref), 10, { MARBLE, MARBLE_DARK }, 0.45, 18, 0.8, ctx.B.Y + 0.1, false, Enum.Material.Marble)
			end
			Kit.smoke(ctx:part("chest"), MARBLE, 8, 3)
		end
		-- Розы распускаются.
		local bloom = tau - beats.bloom
		for _, r in ipairs(st.roses) do
			local k = ease((bloom - r.delay) / 0.45)
			if bloom < r.delay then
				k = 0
			end
			local stemH = math.max(r.h * k, 0.1)
			r.stem.Size = V3(0.2, stemH, 0.2)
			r.stem.CFrame = CFrame.new(r.base + V3(0, stemH / 2, 0))
			local s = math.max(1.3 * k, 0.1)
			r.rose.Size = V3(s, s * 0.8, s)
			r.rose.Transparency = k > 0 and 0 or 1
			r.rose.CFrame = CFrame.new(r.base + V3(0, stemH + s * 0.3, 0))
			if k > 0 and not r.popped then
				r.popped = true
				Kit.burst(r.base + V3(0, r.h, 0), 3, { PETAL, ROSE }, 0.25, 6, 1, r.base.Y, true)
			end
		end
		local bloomed, bloomLate = ctx:beat("bloom")
		if bloomed and not bloomLate then
			ctx:sfx("gardenFlood", ctx.B)
			ctx:sfx("bmVines", ctx.B)
			Kit.shockRing(ctx.B, 12, ROSE, 0.7)
			Kit.emitter(ctx:at(0, 0, 3), {
				tex = TEX.glow, color = Kit.cseq(PETAL, ROSE), emit = 60, life = { 1.2, 2.2 }, speed = { 8, 16 }, spread = 180,
				size = Kit.nseq({ { 0, 0.35 }, { 1, 0.15 } }), transp = Kit.nseq({ { 0, 0 }, { 1, 1 } }), light = 0.4, accel = V3(0, -6, 0), drag = 1.5, rot = 200,
			})
		end
		st.water.Transparency = 0.35 + 0.1 * math.sin(tau * 3)
	end,
	shots = {
		{ t = 0.0, pos = { 12, -8, 5 }, look = { 0, 0, 5 }, fov = 50 },
		{ t = 1.9, pos = { 12, -3, 4 }, look = { 0, 0, 5.2 }, fov = 48 },
		{ t = 1.9, cut = true, pos = { 5, 2.5, 0.8 }, look = { 0, 0, 2.5 }, fov = 55 },
		{ t = 3.7, pos = { 4.6, 1.5, 6 }, look = { 0, 0, 0, ref = "head" }, fov = 48 },
		{ t = 3.7, cut = true, pos = { 3.2, 0.5, 0.2, ref = "head" }, look = { 0, 0, 0, ref = "head" }, fov = 36 },
		{ t = 4.25, pos = { 3.4, 0.6, 0.3, ref = "head" }, look = { 0, 0, 0, ref = "head" }, fov = 38 },
		{ t = 5.0, pos = { 10, -4, 3 }, look = { 0, 0, 6 }, fov = 55 },
		{ t = 5.8, pos = { 13, -6, 2 }, look = { 0, 0, 5 }, fov = 60 },
		{ t = 6.2, pos = { 9, 2, 2 }, look = { 0, 0, 0, ref = "head" }, fov = 50 },
		{ t = 8.0, pos = { 12, 3, 4 }, look = { 0, 0, 6 }, fov = 60 },
	},
}

-- ======================================================================
-- Королевский ловчий: рог в темноте, глаза своры, факелы, прыжок с пня
-- ======================================================================

local AMBER = rgb(255, 176, 60)
local BARK = rgb(84, 58, 38)
local WOOD = rgb(120, 84, 52)
local FIRE = rgb(255, 150, 50)
local BLOOD = rgb(196, 36, 36)

local function perchOffset(ctx): Vector3
	return -ctx.F * ctx.state.back + V3(0, ctx.state.height, 0)
end

Scenes.royal_huntsman = {
	H = 9,
	setup = function(ctx)
		local st = ctx.state
		local perch = ctx.cfg.perch or { height = 13, back = 9 }
		-- Насест не должен уйти в стену позади точки появления.
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { Kit.folder(), Workspace:FindFirstChild("EnemyVisuals") }
		local hit = Workspace:Raycast(ctx.B + V3(0, 3, 0), -ctx.F * (perch.back + 3), params)
		st.back = hit and math.max((hit.Position - (ctx.B + V3(0, 3, 0))).Magnitude - 3.2, 2) or perch.back
		st.height = perch.height
		local top = ctx.B + perchOffset(ctx)
		local foot = floorAt(ctx, V3(top.X, ctx.B.Y, top.Z))
		local h = top.Y - foot.Y
		st.stump = prop(ctx, { Name = "Stump", Shape = Enum.PartType.Cylinder, Size = V3(h, 5.2, 5.2), CFrame = CFrame.new(foot + V3(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = BARK, Material = Enum.Material.Wood, CastShadow = true })
		st.cap = prop(ctx, { Name = "StumpTop", Shape = Enum.PartType.Cylinder, Size = V3(0.3, 4.8, 4.8), CFrame = CFrame.new(top + V3(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = WOOD, Material = Enum.Material.Wood })
		for index = 1, 4 do
			local a = index / 4 * TAU + 0.4
			local p = foot + V3(math.cos(a) * 2.8, 0.6, math.sin(a) * 2.8)
			prop(ctx, { Name = "Root", Size = V3(1.0, 1.2, 3.0), CFrame = CFrame.lookAt(p, foot + V3(0, 2, 0)) * CFrame.Angles(-0.5, 0, 0), Color = BARK, Material = Enum.Material.Wood })
		end
		-- Глаза своры по кругу.
		st.eyes = {}
		for index = 1, 14 do
			local a = index / 14 * TAU + random:NextNumber(-0.15, 0.15)
			local r = random:NextNumber(13, 19)
			local base = floorAt(ctx, ctx:at(math.cos(a) * r, math.sin(a) * r, 0)) + V3(0, random:NextNumber(1.5, 2.5), 0)
			local toward = (ctx.B - base) * V3(1, 0, 1)
			toward = toward.Magnitude > 0.1 and toward.Unit or ctx.F
			local side = toward:Cross(V3(0, 1, 0))
			local pair = {}
			for _, sign in ipairs({ -1, 1 }) do
				table.insert(pair, prop(ctx, { Name = "HoundEye", Size = V3(0.22, 0.16, 0.12), Color = AMBER, Material = Enum.Material.Neon, Transparency = 1, CFrame = CFrame.new(base + side * 0.22 * sign) }))
			end
			table.insert(st.eyes, { pair = pair, base = base, side = side, toward = toward, delay = random:NextNumber(0, 1.2), blink = random:NextNumber(0, 3) })
		end
		-- Факелы по кругу.
		st.torches = {}
		for index = 1, 8 do
			local a = index / 8 * TAU + math.pi / 8
			local base = floorAt(ctx, ctx:at(math.cos(a) * 15, math.sin(a) * 15, 0))
			prop(ctx, { Name = "TorchPole", Size = V3(0.4, 4.2, 0.4), CFrame = CFrame.new(base + V3(0, 2.1, 0)), Color = WOOD, Material = Enum.Material.Wood, CastShadow = true })
			local head = prop(ctx, { Name = "TorchHead", Size = V3(0.7, 0.7, 0.7), CFrame = CFrame.new(base + V3(0, 4.4, 0)), Color = rgb(40, 30, 24), Material = Enum.Material.Slate })
			table.insert(st.torches, { head = head, base = base, at = index * 0.07 })
		end
		ctx:rig()
		if ctx.start < ctx.cfg.beats.eyes then
			eyes(ctx, false)
		end
	end,
	update = function(ctx, tau, dt)
		local st = ctx.state
		local beats = ctx.cfg.beats
		local rig = ctx:rig()
		-- Насест и прыжок: смещение модели (EnemyVisualController).
		if rig then
			local perch = perchOffset(ctx)
			if tau < beats.leap then
				rig.introOffset = perch
			elseif tau < beats.land then
				local k = span(tau, beats.leap, beats.land)
				rig.introOffset = perch:Lerp(Vector3.zero, smooth(k)) + V3(0, math.sin(math.pi * k) * 4, 0)
			else
				rig.introOffset = nil
			end
			rig.introFacing = ctx.F
		end
		local horn, hornLate = ctx:beat("horn")
		if horn and not hornLate then
			ctx:shake(0.25, 1.2)
		end
		-- Глаза загораются по одному, моргают; на gather стекаются к ловчему.
		for _, e in ipairs(st.eyes) do
			local on = tau >= beats.eyes + e.delay
			local blink = math.floor((tau + e.blink) * 0.8) % 4 == 0 and ((tau + e.blink) * 0.8) % 1 < 0.12
			local gather = span(tau, beats.gather, beats.gather + 1.0)
			local target = ctx.B - ctx.F * 4 + e.side * 3 + V3(0, 1.8, 0)
			local p = e.base:Lerp(target, smooth(gather))
			local fade = span(tau, beats.roar, beats.roar + 0.6)
			for index, part in ipairs(e.pair) do
				local sign = index == 1 and -1 or 1
				part.CFrame = CFrame.lookAt(p + e.side * 0.22 * sign, p + e.side * 0.22 * sign + e.toward)
				part.Transparency = (on and not blink) and fade or 1
			end
			if on and not e.lit then
				e.lit = true
				if random:NextNumber() < 0.35 and tau - (beats.eyes + e.delay) < 0.3 then
					ctx:sfx("bmHoundRun", e.base)
				end
			end
		end
		local eye = ctx:beat("eyes")
		if eye then
			eyes(ctx, true)
		end
		-- Факелы.
		for _, torch in ipairs(st.torches) do
			if tau >= beats.torches + torch.at and not torch.lit then
				torch.lit = true
				torch.head.Color = FIRE
				torch.head.Material = Enum.Material.Neon
				local light = Instance.new("PointLight")
				light.Color = FIRE
				light.Range = 16
				light.Brightness = 2.5
				light.Parent = torch.head
				Kit.emitter(Vector3.zero, {
					parent = torch.head, tex = TEX.glow, color = Kit.cseq(rgb(255, 220, 120), FIRE), rate = 30, life = { 0.3, 0.6 }, speed = { 2, 4 }, spread = 15,
					size = Kit.nseq({ { 0, 1.0 }, { 1, 0.1 } }), transp = Kit.nseq({ { 0, 0.1 }, { 1, 1 } }), light = 1, accel = V3(0, 4, 0),
				})
				if (torch.at < 0.15 or torch.at > 0.5) and tau - (beats.torches + torch.at) < 0.3 then
					ctx:sfx("bmTorches", torch.base)
				end
				Kit.sparks(torch.head.Position, FIRE, 8, 8)
			end
		end
		local leap, leapLate = ctx:beat("leap")
		if leap and not leapLate then
			ctx:sfx("bmSpearThrow", ctx.B + perchOffset(ctx))
			Kit.burst(ctx.B + perchOffset(ctx), 10, { BARK, WOOD }, 0.4, 16, 0.8, ctx.B.Y + 0.1)
		end
		local land, landLate = ctx:beat("land")
		if land and not landLate then
			ctx:sfx("bmIntroBoom", ctx.B)
			ctx:sfx("bmSpearHit", ctx.B)
			ctx:shake(1.2, 0.45)
			ctx:punch(-10, 0.3)
			Kit.shockRing(ctx.B, 14, AMBER, 0.55)
			Kit.smoke(ctx.B + V3(0, 0.5, 0), rgb(150, 130, 100), 14, 3.6)
			Kit.burst(ctx.B + V3(0, 0.4, 0), 16, { rgb(120, 96, 70), BARK }, 0.45, 22, 0.8, ctx.B.Y + 0.1)
		end
		local gather, gatherLate = ctx:beat("gather")
		if gather and not gatherLate then
			ctx:sfx("bmHoundRun", ctx.B)
		end
		local roar, roarLate = ctx:beat("roar")
		if roar and not roarLate then
			for index = 1, 3 do
				local slash = prop(ctx, { Name = "ClawMark", Size = V3(0.35, 0.05, 6), CFrame = CFrame.new(ctx:at(3, (index - 2) * 1.2, 0.08)) * CFrame.Angles(0, math.atan2(ctx.F.X, ctx.F.Z) + 0.5, 0), Color = BLOOD, Material = Enum.Material.Neon, Transparency = 0.2 })
				Kit.tween(slash, 1.8, { Transparency = 0.8 })
			end
		end
	end,
	cleanup = function(ctx)
		local rig = ctx:rig()
		if rig then
			rig.introOffset = nil
			rig.introFacing = nil
		end
	end,
	shots = {
		{ t = 0.0, fn = function(ctx, tau)
			local top = ctx.B + perchOffset(ctx) + V3(0, 4.5, 0)
			local k = tau / 1.8
			return ctx:at(15 - 2 * k, -5 + k, 1.5), top, 42 - 3 * k
		end },
		{ t = 1.8, cut = true, fn = function(ctx, tau)
			local k = smooth(span(tau, 1.8, 3.4))
			local a = math.rad(-70 + 140 * k)
			local eye = ctx:at(math.cos(a) * 16, math.sin(a) * 16, 2)
			return ctx:at(-2, 0, 3.2), eye, 50
		end },
		{ t = 3.4, cut = true, pos = { 21, 9, 12 }, look = { -5, 0, 11 }, fov = 62 },
		{ t = 4.55, pos = { 19, 7, 11 }, look = { -5, 0, 11.5 }, fov = 60 },
		{ t = 4.6, cut = true, fn = function(ctx, tau)
			local root = ctx:part("chest")
			return ctx:at(11, -7, 6), root, 55
		end },
		{ t = 5.3, cut = true, pos = { 6, 3, 1.0 }, look = { 0, 0, 0, ref = "head" }, fov = 55 },
		{ t = 6.55, pos = { 7, 2, 1.4 }, look = { 0, 0, 0, ref = "head" }, fov = 52 },
		{ t = 6.6, pos = { 8, -1.5, 1.6 }, look = { 0, 0, 0, ref = "head" }, fov = 48 },
		{ t = 8.5, pos = { 11, -3, 3 }, look = { 0, 0, 5 }, fov = 60 },
	},
}

-- ======================================================================
-- Старейший литейщик: ковш льёт металл в форму, форма трескается и
-- разлетается, раскалённый литейщик остывает и бьёт оземь
-- ======================================================================

local CAST_IRON = rgb(66, 58, 54)
local IRON_DARK = rgb(40, 34, 32)
local HOOP = rgb(98, 86, 74)
local MOLTEN = rgb(255, 136, 40)
local MOLTEN_HOT = rgb(255, 226, 150)
local EMBER = rgb(226, 103, 43)
local STEAM = rgb(214, 208, 200)
local WHITE = rgb(255, 255, 255)

local MOLD_R = 4.4
local MOLD_H = 12.5
local PLATE_W = 3.5
local PLATE_T = 0.9
local MOLD_G = 55
local SEAM_R = MOLD_R / math.cos(math.pi / 8) - 0.1

-- Положение плиты формы: дрожь перед взрывом, затем полёт по параболе с
-- опрокидыванием наружу (ложится плашмя раскалённой стороной вверх).
local function plateCFrame(ctx, plate, tau: number): CFrame
	local beats = ctx.cfg.beats
	if tau < beats.burst then
		local k = span(tau, beats.crack, beats.burst)
		if k <= 0 then
			return plate.home
		end
		local j = 0.14 * k * k
		local w = tau * 47 + plate.seed
		return plate.home * CFrame.new(math.sin(w) * j, math.sin(w * 1.3) * j * 0.4, math.cos(w * 0.9) * j)
			* CFrame.Angles(math.sin(w * 0.7) * j * 0.06, 0, math.cos(w * 1.1) * j * 0.06)
	end
	local t = tau - beats.burst
	local tl = plate.land
	local tt = math.min(t, tl)
	local v = plate.vel
	local flat = V3(v.X, 0, v.Z)
	local p = plate.home.Position + flat * tt + V3(0, v.Y * tt - 0.5 * MOLD_G * tt * tt, 0)
	if t > tl then
		p += flat * 0.16 * (1 - math.exp(-(t - tl) * 5))
		p = V3(p.X, plate.floorY + PLATE_T / 2, p.Z)
	end
	local a = math.min(t / tl, 1)
	return CFrame.new(p) * plate.home.Rotation * CFrame.Angles(0, plate.yaw * a, 0) * CFrame.Angles(-a * math.pi / 2, 0, 0)
end

Scenes.elder_founder = {
	H = 11.6,
	setup = function(ctx)
		local st = ctx.state
		local beats = ctx.cfg.beats
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { Kit.folder(), Workspace:FindFirstChild("EnemyVisuals") }
		-- Форма: восемь чугунных плит, обручи, швы и трещины.
		st.plates = {}
		st.seams = {}
		for index = 1, 8 do
			local a = index / 8 * TAU + math.pi / 8
			local n = ctx.F * math.cos(a) + ctx.R * math.sin(a)
			local center = ctx.B + n * MOLD_R + V3(0, MOLD_H / 2, 0)
			local home = CFrame.lookAt(center, center + n)
			local plate = { home = home, seed = random:NextNumber(0, 100), yaw = random:NextNumber(-0.6, 0.6), items = {} }
			plate.part = prop(ctx, { Name = "MoldPlate", Size = V3(PLATE_W, MOLD_H, PLATE_T), CFrame = home, Color = CAST_IRON, Material = Enum.Material.CorrodedMetal, CastShadow = true })
			for _, h in ipairs({ -4.6, 0, 4.6 }) do
				local hoop = prop(ctx, { Name = "MoldHoop", Size = V3(PLATE_W + 0.1, 0.55, 0.3), Color = HOOP, Material = Enum.Material.Metal })
				table.insert(plate.items, { part = hoop, offset = CFrame.new(0, h, -PLATE_T / 2 - 0.12) })
				for _, x in ipairs({ -1.4, 1.4 }) do
					local rivet = prop(ctx, { Name = "Rivet", Shape = Enum.PartType.Ball, Size = V3(0.3, 0.3, 0.3), Color = HOOP, Material = Enum.Material.Metal })
					table.insert(plate.items, { part = rivet, offset = CFrame.new(x, h, -PLATE_T / 2 - 0.28) })
				end
			end
			-- Раскалённая изнанка: видна, когда плита ляжет плашмя.
			plate.coat = prop(ctx, { Name = "MoldCoat", Size = V3(PLATE_W - 0.4, MOLD_H - 0.6, 0.06), Color = MOLTEN_HOT, Material = Enum.Material.Neon, Transparency = 1 })
			table.insert(plate.items, { part = plate.coat, offset = CFrame.new(0, 0, PLATE_T / 2 + 0.04) })
			-- Трещины: ломаные из неоновых отрезков на внешней стороне.
			plate.cracks = {}
			for c = 1, 2 do
				local x = random:NextNumber(-1.2, 1.2)
				local y = random:NextNumber(-4, 4)
				local delay = random:NextNumber(0, 0.35) + (c - 1) * 0.2
				for s = 1, 4 do
					local nx = math.clamp(x + random:NextNumber(-1.1, 1.1), -1.7, 1.7)
					local ny = y + random:NextNumber(-2.2, 2.2)
					local dx, dy = nx - x, ny - y
					local len = math.sqrt(dx * dx + dy * dy)
					local seg = prop(ctx, { Name = "MoldCrack", Size = V3(len + 0.1, 0.14, 0.06), Color = MOLTEN_HOT, Material = Enum.Material.Neon, Transparency = 1 })
					local item = { part = seg, offset = CFrame.new((x + nx) / 2, (y + ny) / 2, -PLATE_T / 2 - 0.04) * CFrame.Angles(0, 0, math.atan2(dy, dx)), at = delay + s * 0.1 }
					table.insert(plate.items, item)
					table.insert(plate.cracks, item)
					x, y = nx, ny
				end
			end
			-- Куда лететь: перед литейщиком (к камере) — ближе, позади — дальше,
			-- и не дальше ближайшей стены.
			local travel = math.cos(a) > 0.3 and random:NextNumber(6, 8) or random:NextNumber(10, 14)
			local hit = Workspace:Raycast(ctx.B + V3(0, 3, 0), n * (travel + MOLD_R + 4), params)
			if hit then
				travel = math.max((hit.Position - (ctx.B + V3(0, 3, 0))).Magnitude - MOLD_R - 3.5, 1.5)
			end
			local vy = random:NextNumber(10, 15)
			local floorY = Kit.groundY(ctx.B + n * (MOLD_R + travel) + V3(0, 4, 0), ctx.B.Y)
			local drop = math.max(center.Y - (floorY + PLATE_T / 2), 0)
			plate.land = (vy + math.sqrt(vy * vy + 2 * MOLD_G * drop)) / MOLD_G
			plate.vel = n * (travel / plate.land) + V3(0, vy, 0)
			plate.floorY = floorY
			table.insert(st.plates, plate)
			-- Шов между плитами (на углу восьмигранника).
			local b = a + math.pi / 8
			local m = ctx.F * math.cos(b) + ctx.R * math.sin(b)
			table.insert(st.seams, prop(ctx, { Name = "MoldSeam", Size = V3(0.45, 0.2, 0.45), Color = EMBER, Material = Enum.Material.Neon, Transparency = 1, CFrame = CFrame.new(ctx.B + m * SEAM_R) }))
			table.insert(st.seams, m)
		end
		-- Расплав внутри формы.
		st.surface = prop(ctx, { Name = "MoltenSurface", Shape = Enum.PartType.Cylinder, Size = V3(0.1, MOLD_R * 2 - 0.6, MOLD_R * 2 - 0.6), Color = MOLTEN_HOT, Material = Enum.Material.Neon, Transparency = 1, CFrame = Kit.discCFrame(ctx.B, 0.5) })
		st.light = Instance.new("PointLight")
		st.light.Color = MOLTEN
		st.light.Range = 20
		st.light.Brightness = 0
		st.light.Parent = st.surface
		local _, sparks = Kit.emitter(Vector3.zero, {
			parent = st.surface, tex = TEX.spark, color = Kit.cseq(MOLTEN_HOT, MOLTEN), rate = 0, life = { 0.4, 0.9 }, speed = { 6, 12 }, spread = 40,
			size = Kit.nseq({ { 0, 0.35 }, { 1, 0.05 } }), transp = Kit.nseq({ { 0, 0 }, { 1, 1 } }), light = 1, accel = V3(0, -20, 0),
		})
		st.sparks = sparks
		local _, fumes = Kit.emitter(Vector3.zero, {
			parent = st.surface, tex = TEX.smoke, color = rgb(120, 104, 96), rate = 0, life = { 1.5, 2.5 }, speed = { 3, 5 }, spread = 25,
			size = Kit.nseq({ { 0, 2 }, { 1, 6 } }), transp = Kit.nseq({ { 0, 1 }, { 0.3, 0.6 }, { 1, 1 } }), light = 0.1,
		})
		st.fumes = fumes
		-- Ковш над формой.
		st.ladleHome = ctx:at(-1.5, 2.5, MOLD_H + 2.5)
		local d = (ctx:at(0, 0, MOLD_H) - st.ladleHome) * V3(1, 0, 1)
		st.ladleDir = d.Magnitude > 0.1 and d.Unit or ctx.F
		st.ladleSide = st.ladleDir:Cross(V3(0, 1, 0))
		st.bowl = prop(ctx, { Name = "Ladle", Shape = Enum.PartType.Cylinder, Size = V3(2.6, 3.6, 3.6), Color = IRON_DARK, Material = Enum.Material.CorrodedMetal, CastShadow = true })
		st.bowlMetal = prop(ctx, { Name = "LadleMetal", Shape = Enum.PartType.Cylinder, Size = V3(0.1, 3.1, 3.1), Color = MOLTEN_HOT, Material = Enum.Material.Neon })
		st.handle = prop(ctx, { Name = "LadleHandle", Size = V3(0.45, 0.45, 1), Color = IRON_DARK, Material = Enum.Material.Metal })
		st.stream = {
			prop(ctx, { Name = "Pour", Size = V3(0.5, 0.5, 1), Color = MOLTEN_HOT, Material = Enum.Material.Neon, Transparency = 1 }),
			prop(ctx, { Name = "Pour", Size = V3(0.5, 0.5, 1), Color = MOLTEN_HOT, Material = Enum.Material.Neon, Transparency = 1 }),
		}
		-- Летающие угольки по всей зале.
		ctx:add(Kit.emitter(ctx:at(0, 0, 1), {
			tex = TEX.spark, color = Kit.cseq(MOLTEN_HOT, EMBER), rate = 10, box = V3(34, 1, 34), life = { 3, 5 }, speed = { 1, 3 }, spread = 30,
			size = Kit.nseq({ { 0, 0.2 }, { 1, 0.05 } }), transp = Kit.nseq({ { 0, 0.2 }, { 1, 1 } }), light = 1, accel = V3(0.3, 1.2, 0.2), rot = 90,
		}, ctx.cfg.full + 1))
		st.hideAt = -1
		ctx:rig()
		if ctx.start < beats.burst then
			setHidden(ctx, 1)
			eyes(ctx, false)
		end
	end,
	update = function(ctx, tau, dt)
		local st = ctx.state
		local beats = ctx.cfg.beats
		local up = V3(0, 1, 0)
		local burst = tau >= beats.burst
		-- Пока форма цела, литейщика не видно (детали могли досоздаться).
		if not burst and os.clock() - st.hideAt > 0.5 then
			st.hideAt = os.clock()
			setHidden(ctx, 1)
		end
		-- Ковш: наклон, струя, уход вверх.
		local tilt = math.rad(58) * smooth(span(tau, 0.1, beats.pour)) * (1 - smooth(span(tau, 2.6, 3.1)))
		local lift = 12 * easeIn(span(tau, 3.0, 3.9))
		local axis = up * math.cos(tilt) + st.ladleDir * math.sin(tilt)
		local o = st.ladleHome + V3(0, lift, 0)
		local bowl = CFrame.fromMatrix(o, axis, st.ladleSide)
		st.bowl.CFrame = bowl
		st.bowlMetal.CFrame = bowl * CFrame.new(1.2 - 0.6 * span(tau, beats.pour, 2.6), 0, 0)
		st.bowlMetal.Transparency = tau < 2.7 and 0 or 1
		Kit.placeBeam(st.handle, o - st.ladleDir * 1.7 + up * 0.4, o - st.ladleDir * 9 + up * 5)
		local level = 0.5 + (MOLD_H - 1.0) * smooth(span(tau, beats.pour + 0.2, 3.3))
		local surface = ctx.B + up * level
		local pouring = tau >= beats.pour and tau < 2.6
		local lip = o + axis * 1.3 + st.ladleDir * 1.8
		local mid = lip + st.ladleDir * 0.5 - up * 0.9
		local w = 0.45 + 0.08 * math.sin(tau * 31)
		for index, seg in ipairs(st.stream) do
			if pouring then
				local a, b = index == 1 and lip or mid, index == 1 and mid or surface
				Kit.placeBeam(seg, a, b)
				seg.Size = V3(w, w, seg.Size.Z)
				seg.Transparency = 0
			else
				seg.Transparency = 1
			end
		end
		local pour, pourLate = ctx:beat("pour")
		if pour and not pourLate then
			ctx:sfx("bmPour", ctx:at(0, 0, MOLD_H))
		end
		-- Расплав поднимается: свет и искры из горловины.
		if not burst then
			st.surface.CFrame = Kit.discCFrame(ctx.B, level)
			st.surface.Transparency = tau >= beats.pour + 0.15 and 0 or 1
			st.light.Brightness = 3.5 * span(tau, beats.pour, beats.fill)
			st.sparks.Rate = pouring and 45 or (tau >= beats.pour and 10 or 0)
			st.fumes.Rate = tau >= beats.pour and 6 or 0
		elseif st.surface.Transparency < 1 then
			st.surface.Transparency = 1
			st.light.Brightness = 0
			st.sparks.Rate = 0
			st.fumes.Rate = 0
		end
		-- Швы раскаляются снизу вверх вслед за уровнем металла.
		local glow = span(tau, beats.fill - 0.6, beats.fill + 0.8)
		for index = 1, #st.seams, 2 do
			local seam, m = st.seams[index], st.seams[index + 1]
			if burst then
				seam.Transparency = 1
			else
				local hgt = math.max(level - 0.3, 0.2)
				seam.Size = V3(0.45, hgt, 0.45)
				seam.CFrame = CFrame.lookAt(ctx.B + m * SEAM_R + up * (hgt / 2), ctx.B + m * (SEAM_R + 1) + up * (hgt / 2))
				seam.Transparency = 1 - 0.85 * glow
				seam.Color = EMBER:Lerp(MOLTEN_HOT, span(tau, beats.fill, beats.burst))
			end
		end
		-- Плиты: дрожь, трещины, полёт, остывание.
		local parts, frames = {}, {}
		local cool = span(tau, beats.burst + 0.4, beats.burst + 3.2)
		for _, plate in ipairs(st.plates) do
			local cf = plateCFrame(ctx, plate, tau)
			table.insert(parts, plate.part)
			table.insert(frames, cf)
			for _, item in ipairs(plate.items) do
				table.insert(parts, item.part)
				table.insert(frames, cf * item.offset)
			end
			for _, item in ipairs(plate.cracks) do
				local on = tau >= beats.crack + item.at
				item.part.Transparency = on and (0.1 + 0.9 * cool) or 1
				item.part.Color = MOLTEN_HOT:Lerp(EMBER, cool)
			end
			plate.coat.Transparency = burst and (0.05 + 0.75 * cool) or 1
			plate.coat.Color = MOLTEN_HOT:Lerp(EMBER, cool)
			if burst and not plate.landed and tau - beats.burst >= plate.land then
				plate.landed = true
				if tau - beats.burst < plate.land + 0.2 then
					local p = cf.Position
					Kit.burst(V3(p.X, plate.floorY + 0.3, p.Z), 8, { MOLTEN, EMBER, CAST_IRON }, 0.35, 14, 0.7, plate.floorY + 0.1, true)
					Kit.smoke(V3(p.X, plate.floorY + 0.5, p.Z), rgb(110, 96, 88), 4, 3)
					if not st.landSound then
						st.landSound = true
						ctx:sfx("bmIngotSkip", p)
					end
				end
			end
		end
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		local crack, crackLate = ctx:beat("crack")
		if crack and not crackLate then
			ctx:sfx("statueCrack", ctx:at(0, 0, 6))
			ctx:shake(0.35, 0.8)
			for index = 2, #st.seams, 2 do
				Kit.sparks(ctx.B + st.seams[index] * (MOLD_R + 0.5) + up * random:NextNumber(2, 10), MOLTEN_HOT, 6, 12)
			end
		end
		if tau >= beats.crack and not burst then
			ctx:shake(0.06 + 0.2 * span(tau, beats.crack, beats.burst), 0.1)
		end
		-- Взрыв формы.
		local fired, late = ctx:beat("burst")
		if fired then
			setHidden(ctx, 0)
			eyes(ctx, true)
			if not late then
				local chest = ctx:part("chest")
				ctx:sfx("bmMoldBurst", chest)
				ctx:sfx("bmIntroBoom", ctx.B)
				ctx:shake(1.4, 0.6)
				ctx:punch(-12, 0.35)
				ctx:flash(rgb(255, 214, 150), 0.25, 0.5)
				Kit.flash(chest, MOLTEN_HOT, 14, 0.35)
				Kit.burst(chest, 40, { MOLTEN, MOLTEN_HOT, EMBER }, 0.45, 40, 0.7, ctx.B.Y + 0.1, true)
				Kit.smoke(ctx.B + up * 4, STEAM, 16, 5, 3)
				Kit.shockRing(ctx.B, 18, MOLTEN, 0.6)
			end
			-- Пар от остывающего металла.
			st.steamAnchor = prop(ctx, { Name = "SteamAnchor", Size = V3(4, 8, 4), Transparency = 1, CFrame = CFrame.new(ctx.B + up * 5) })
			local _, steam = Kit.emitter(Vector3.zero, {
				parent = st.steamAnchor, box = true, tex = TEX.smoke, color = STEAM, rate = 30, life = { 1.2, 2.2 }, speed = { 2, 5 }, spread = 20,
				size = Kit.nseq({ { 0, 1.5 }, { 1, 5 } }), transp = Kit.nseq({ { 0, 1 }, { 0.25, 0.55 }, { 1, 1 } }), light = 0.2, accel = V3(0, 3, 0),
			})
			st.steam = steam
		end
		-- Раскалённая оболочка: белый → жар → угасает.
		if burst then
			local fill = 0.05 + 0.95 * smooth(span(tau, beats.cool + 0.3, 6.3))
			if fill < 1 then
				local c = MOLTEN_HOT:Lerp(EMBER, smooth(span(tau, beats.burst + 0.2, 5.4)))
				shell(ctx, WHITE:Lerp(c, span(tau, beats.burst, beats.burst + 0.25)), fill)
			elseif st.highlight and st.highlight.Parent then
				st.highlight.Enabled = false
			end
			if st.steam then
				st.steamAnchor.CFrame = CFrame.new(ctx:part("root") + up * 1.5)
				st.steam.Rate = 30 * (1 - span(tau, 5.6, 7.2))
			end
		end
		-- Удар оземь.
		local slam, slamLate = ctx:beat("slam")
		if slam and not slamLate then
			local hit = floorAt(ctx, ctx:at(2.5, 0, 0))
			ctx:sfx("forgeBlast", hit)
			ctx:shake(1.0, 0.45)
			ctx:punch(-8, 0.3)
			Kit.sparks(hit + up * 0.4, MOLTEN_HOT, 40, 30)
			Kit.shockRing(hit, 16, EMBER, 0.6)
			Kit.burst(hit + up * 0.3, 24, { MOLTEN, MOLTEN_HOT, CAST_IRON }, 0.4, 26, 0.8, ctx.B.Y + 0.1, true)
			local scorch = ctx:add(Kit.disc(hit, 3.6, MOLTEN, 0.15, 0.06))
			Kit.tween(scorch, 1.6, { Color = IRON_DARK, Transparency = 0.5 })
			Kit.smoke(hit + up * 0.6, rgb(110, 96, 88), 10, 3.5)
		end
		local roar, roarLate = ctx:beat("roar")
		if roar and not roarLate then
			Kit.emitter(ctx:part("head"), {
				tex = TEX.spark, color = Kit.cseq(MOLTEN_HOT, EMBER), emit = 50, life = { 0.6, 1.4 }, speed = { 10, 22 }, spread = 70,
				size = Kit.nseq({ { 0, 0.4 }, { 1, 0.05 } }), transp = Kit.nseq({ { 0, 0 }, { 1, 1 } }), light = 1, accel = V3(0, -14, 0),
			})
		end
	end,
	cleanup = function(ctx)
		if ctx.state.highlight and ctx.state.highlight.Parent then
			ctx.state.highlight:Destroy()
		end
	end,
	shots = {
		{ t = 0.0, pos = { 13, -7, 15 }, look = { -0.5, 1, 11 }, fov = 50 },
		{ t = 1.79, pos = { 12, -5, 13 }, look = { -0.5, 1, 11 }, fov = 48 },
		{ t = 1.8, cut = true, pos = { 13, 5, 5 }, look = { 0, 0, 6.5 }, fov = 50 },
		{ t = 3.39, pos = { 11, 3.5, 6 }, look = { 0, 0, 6.5 }, fov = 48 },
		{ t = 3.4, cut = true, pos = { 10, 2, 6 }, look = { 0, 0, 6.5 }, fov = 50 },
		{ t = 4.19, pos = { 9.4, 1.8, 6 }, look = { 0, 0, 6.5 }, fov = 47 },
		{ t = 4.2, cut = true, pos = { 16, -4, 4 }, look = { 0, 0, 5 }, fov = 62 },
		{ t = 6.3, pos = { 12, 4, 2.5 }, look = { 0, 0, 0, ref = "head" }, fov = 56 },
		{ t = 6.4, cut = true, pos = { 9, -2, 1.2 }, look = { 0, 0, 4 }, fov = 55 },
		{ t = 6.69, pos = { 9.6, -2.3, 1.3 }, look = { 0, 0, 4 }, fov = 56 },
		{ t = 6.7, cut = true, pos = { 8, -1.5, 1.5 }, look = { 0, 0, 0, ref = "head" }, fov = 50 },
		{ t = 8.0, pos = { 11, -2.5, 3 }, look = { 0, 0, 6 }, fov = 60 },
	},
}

-- ======================================================================
-- Главный летописец: вихрь страниц, из пола встаёт раскрытая хроника,
-- строка света «вписывает» летописца снизу вверх, чернила расползаются,
-- книга захлопывается, над головой загорается корона рун
-- ======================================================================

local INK = rgb(30, 22, 52)
local INK_GLOW = rgb(142, 124, 224)
local FROST = rgb(184, 227, 255)
local PAPER = rgb(236, 228, 206)
local PAPER_DARK = rgb(198, 186, 158)
local LEATHER = rgb(62, 40, 90)
local GILT = rgb(214, 180, 96)

local BOOK_W = 7.2
local BOOK_H = 14.4
local SCAN_R = 3.8

local function bookSpine(ctx, tau: number): Vector3
	local beats = ctx.cfg.beats
	local rise = -(BOOK_H + 1) * (1 - ease(span(tau, beats.book, beats.book + 1.1)))
	local sink = -(BOOK_H + 1) * easeIn(span(tau, beats.roar + 0.4, ctx.cfg.full))
	return ctx:at(-ctx.state.back, 0, BOOK_H / 2 + rise + sink)
end

-- Угол раскрытия половин: −90° — сложены назад, +18° — раскрыты к камере.
local function bookAngle(ctx, tau: number): number
	local beats = ctx.cfg.beats
	local open = ease(span(tau, beats.book + 0.3, beats.book + 1.5))
	local shut = easeIn(span(tau, beats.slam - 0.22, beats.slam))
	return math.rad(-90 + 108 * open - 108 * shut)
end

local function scanY(ctx, tau: number): number
	local beats = ctx.cfg.beats
	return -0.3 + (ctx.H + 0.8) * span(tau, beats.scan, beats.scanEnd)
end

Scenes.chief_chronicler = {
	H = 12.4,
	setup = function(ctx)
		local st = ctx.state
		local beats = ctx.cfg.beats
		local up = V3(0, 1, 0)
		-- Книга позади летописца, но не в стене.
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { Kit.folder(), Workspace:FindFirstChild("EnemyVisuals") }
		local hit = Workspace:Raycast(ctx.B + up * 3, -ctx.F * 8, params)
		st.back = hit and math.clamp((hit.Position - (ctx.B + up * 3)).Magnitude - 1.5, 2.5, 5.5) or 5.5
		-- Хроника: корешок, две половины (обложка, блок страниц, строки).
		st.spine = prop(ctx, { Name = "BookSpine", Shape = Enum.PartType.Cylinder, Size = V3(BOOK_H + 0.2, 1.0, 1.0), Color = LEATHER, Material = Enum.Material.Fabric, CastShadow = true })
		st.halves = {}
		for _, sign in ipairs({ -1, 1 }) do
			local half = { sign = sign, items = {}, lines = {} }
			half.cover = prop(ctx, { Name = "BookCover", Size = V3(BOOK_W, BOOK_H, 0.35), Color = LEATHER, Material = Enum.Material.Fabric, CastShadow = true })
			table.insert(half.items, { part = half.cover, offset = CFrame.new(0, 0, 0.3) })
			local pages = prop(ctx, { Name = "BookPages", Size = V3(BOOK_W - 0.4, BOOK_H - 0.6, 0.3), Color = PAPER, Material = Enum.Material.SmoothPlastic })
			table.insert(half.items, { part = pages, offset = CFrame.new(0, 0, 0) })
			for _, corner in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
				local gilt = prop(ctx, { Name = "BookGilt", Size = V3(0.8, 0.8, 0.12), Color = GILT, Material = Enum.Material.Metal })
				table.insert(half.items, { part = gilt, offset = CFrame.new(corner[1] * (BOOK_W / 2 - 0.3), corner[2] * (BOOK_H / 2 - 0.3), 0.5) * CFrame.Angles(0, 0, math.pi / 4) })
			end
			for index = 1, 12 do
				local y = (BOOK_H / 2 - 1.4) - (index - 1) * ((BOOK_H - 2.6) / 11)
				local len = (sign == -1 and index <= 2) and random:NextNumber(2.4, 3.2) or random:NextNumber(3.6, BOOK_W - 1.6)
				local x0 = (sign == -1 and index <= 2) and -0.6 or -(BOOK_W / 2 - 0.8)
				local line = prop(ctx, { Name = "BookLine", Size = V3(len, 0.16, 0.04), Color = INK, Material = Enum.Material.SmoothPlastic })
				local item = { part = line, offset = CFrame.new(x0 + len / 2, y, -0.18), k = (y + BOOK_H / 2) / BOOK_H }
				table.insert(half.items, item)
				table.insert(half.lines, item)
			end
			if sign == -1 then
				-- Буквица.
				local initial = prop(ctx, { Name = "BookInitial", Size = V3(1.7, 1.7, 0.05), Color = INK_GLOW, Material = Enum.Material.Neon })
				table.insert(half.items, { part = initial, offset = CFrame.new(-(BOOK_W / 2 - 1.6), BOOK_H / 2 - 1.9, -0.18) })
			end
			table.insert(st.halves, half)
		end
		-- Страницы: лежат на полу, вихрь поднимает их и вносит в книгу.
		st.pages = {}
		for index = 1, 48 do
			local a = random:NextNumber(0, TAU)
			local r = random:NextNumber(4, 13)
			local floor = floorAt(ctx, ctx:at(math.cos(a) * r, math.sin(a) * r, 0)) + up * 0.05
			table.insert(st.pages, {
				part = prop(ctx, { Name = "VortexPage", Size = V3(1.0, 0.04, 1.4), Color = index % 4 == 0 and PAPER_DARK or PAPER, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(floor) * CFrame.Angles(0, random:NextNumber(0, TAU), 0) }),
				floor = floor, a = random:NextNumber(0, TAU), r = random:NextNumber(6, 11), h = random:NextNumber(0.8, 9), speed = random:NextNumber(2.4, 3.6),
				delay = random:NextNumber(0, 0.7), phase = random:NextNumber(0, TAU), target = V3(random:NextNumber(-1, 1) * (BOOK_W - 1), random:NextNumber(-5.5, 5.5), 0),
				arrive = beats.book + random:NextNumber(-0.3, 0.6),
			})
		end
		ctx:add(Kit.emitter(ctx:at(0, 0, 4), {
			tex = TEX.swirl, color = Kit.cseq(INK_GLOW, INK), rate = 14, box = V3(6, 6, 6), life = { 0.8, 1.4 }, speed = { 1, 3 }, spread = 180,
			size = Kit.nseq({ { 0, 3 }, { 1, 7 } }), transp = Kit.nseq({ { 0, 1 }, { 0.3, 0.6 }, { 1, 1 } }), light = 0.4, rot = 200,
		}, math.max(beats.book - ctx.start, 0.05)))
		-- Строка света скана.
		st.scanDisc = prop(ctx, { Name = "ScanDisc", Shape = Enum.PartType.Cylinder, Size = V3(0.06, SCAN_R * 2, SCAN_R * 2), Color = FROST, Material = Enum.Material.Neon, Transparency = 1 })
		st.scanLight = Instance.new("PointLight")
		st.scanLight.Color = FROST
		st.scanLight.Range = 14
		st.scanLight.Brightness = 0
		st.scanLight.Parent = st.scanDisc
		st.scanRing = {}
		for index = 1, 28 do
			table.insert(st.scanRing, prop(ctx, { Name = "ScanRing", Size = V3(0.14, 0.14, SCAN_R * TAU / 28 * 0.7), Color = FROST, Material = Enum.Material.Neon, Transparency = 1 }))
		end
		st.glyphs = {}
		for index = 1, 18 do
			table.insert(st.glyphs, { part = prop(ctx, { Name = "ScanGlyph", Size = V3(0.32, 0.42, 0.05), Color = index % 3 == 0 and INK_GLOW or FROST, Material = Enum.Material.Neon, Transparency = 1 }), a = index / 18 * TAU, r = SCAN_R + random:NextNumber(0.3, 1.0), dy = random:NextNumber(-0.3, 0.5), flick = random:NextNumber(0, 10) })
		end
		-- Чернильные щупальца по полу.
		st.tentacles = {}
		for index = 1, 8 do
			local a = index / 8 * TAU + random:NextNumber(-0.2, 0.2)
			local t = { dir = ctx.F * math.cos(a) + ctx.R * math.sin(a), len = random:NextNumber(8, 12), phase = random:NextNumber(0, TAU), delay = index % 4 * 0.05, segs = {} }
			t.side = t.dir:Cross(up)
			for s = 1, 7 do
				table.insert(t.segs, prop(ctx, { Name = "InkTentacle", Size = V3(1, 0.06, 1), Color = INK, Material = Enum.Material.SmoothPlastic, Transparency = 1 }))
			end
			t.tip = prop(ctx, { Name = "InkTip", Shape = Enum.PartType.Ball, Size = V3(0.5, 0.5, 0.5), Color = INK_GLOW, Material = Enum.Material.Neon, Transparency = 1 })
			table.insert(st.tentacles, t)
		end
		-- Корона рун.
		st.crown = {}
		for index = 1, 8 do
			local rune = {
				prop(ctx, { Name = "CrownRune", Size = V3(0.12, 0.8, 0.05), Color = FROST, Material = Enum.Material.Neon, Transparency = 1 }),
				prop(ctx, { Name = "CrownRune", Size = V3(0.5, 0.12, 0.05), Color = FROST, Material = Enum.Material.Neon, Transparency = 1 }),
			}
			table.insert(st.crown, { parts = rune, a = index / 8 * TAU, tilt = (index % 2 == 0) and 0.5 or -0.5 })
		end
		st.hideAt = -1
		ctx:rig()
		if ctx.start < beats.scanEnd then
			setHidden(ctx, 1)
		end
		if ctx.start < beats.eyes then
			eyes(ctx, false)
		end
	end,
	update = function(ctx, tau, dt)
		local st = ctx.state
		local beats = ctx.cfg.beats
		local up = V3(0, 1, 0)
		local fired, late
		-- Вихрь страниц.
		fired, late = ctx:beat("vortex")
		if fired and not late then
			ctx:sfx("bmVortex", ctx:at(0, 0, 4))
		end
		local spine = bookSpine(ctx, tau)
		local beta = bookAngle(ctx, tau)
		local parts, frames = {}, {}
		for _, page in ipairs(st.pages) do
			local from = beats.vortex + page.delay
			if tau >= page.arrive + 0.5 then
				if page.part.Transparency < 1 then
					page.part.Transparency = 1
				end
			elseif tau >= from then
				local spinT = tau - from
				local k = span(tau, from, page.arrive)
				local a = page.a + page.speed * spinT * (1 + 1.5 * k)
				local r = page.r * (1 - 0.55 * k)
				local orbit = ctx.B + (ctx.F * math.cos(a) + ctx.R * math.sin(a)) * r + up * (page.h + math.sin(spinT * 2 + page.phase) * 1.2)
				local p = page.floor:Lerp(orbit, ease(span(tau, from, from + 0.6)))
				local target = spine + ctx.R * page.target.X + up * page.target.Y - ctx.F * 0.3
				p = p:Lerp(target, easeIn(span(tau, page.arrive - 0.7, page.arrive + 0.5)))
				local tangent = ctx.R * math.cos(a) - ctx.F * math.sin(a)
				table.insert(parts, page.part)
				table.insert(frames, CFrame.lookAt(p, p + tangent) * CFrame.Angles(math.sin(tau * 7 + page.phase) * 0.9, 0, math.cos(tau * 5 + page.phase) * 0.7))
			end
		end
		-- Книга встаёт из пола, раскрывается; на slam захлопывается назад.
		local bookOn = tau >= beats.book - 0.05
		st.spine.CFrame = CFrame.new(spine) * CFrame.Angles(0, 0, math.pi / 2)
		st.spine.Transparency = bookOn and 0 or 1
		local scanK = span(tau, beats.scan, beats.scanEnd)
		for _, half in ipairs(st.halves) do
			local e = ctx.R * half.sign * math.cos(beta) + ctx.F * math.sin(beta)
			local cf = CFrame.fromMatrix(spine + e * (BOOK_W / 2 + 0.2), e * half.sign, up)
			for _, item in ipairs(half.items) do
				table.insert(parts, item.part)
				table.insert(frames, cf * item.offset)
				item.part.Transparency = bookOn and 0 or 1
			end
			-- Строки загораются вслед за сканом.
			for _, line in ipairs(half.lines) do
				local lit = scanK >= line.k and tau < beats.slam
				line.part.Color = lit and FROST or INK
				line.part.Material = lit and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
		end
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		fired, late = ctx:beat("book")
		if fired and not late then
			ctx:sfx("bmBookSlam", spine)
			ctx:shake(0.5, 0.6)
			Kit.smoke(floorAt(ctx, ctx:at(-st.back, 0, 0)) + up * 0.5, rgb(120, 110, 140), 12, 4)
			Kit.burst(floorAt(ctx, ctx:at(-st.back, 0, 0)) + up * 0.4, 14, { rgb(90, 80, 100), PAPER_DARK }, 0.45, 18, 0.8, ctx.B.Y + 0.1)
		end
		-- Скан: модель проявляется снизу вверх под строкой света.
		local scanning = tau >= beats.scan and tau < beats.scanEnd
		local y = scanY(ctx, tau)
		if scanning then
			local cut = ctx.B.Y + y
			setHidden(ctx, 1, function(part)
				return part.Position.Y < cut and 0 or 1
			end)
		elseif tau < beats.scan and os.clock() - st.hideAt > 0.5 then
			st.hideAt = os.clock()
			setHidden(ctx, 1)
		end
		fired, late = ctx:beat("scan")
		if fired and not late then
			ctx:sfx("bmScan", ctx.B)
		end
		fired = ctx:beat("scanEnd")
		if fired then
			setHidden(ctx, 0)
			if tau < beats.scanEnd + 0.3 then
				Kit.flash(ctx:part("head"), FROST, 5, 0.3)
				Kit.sparks(ctx:part("head"), FROST, 16, 12)
			end
		end
		local center = ctx.B + up * y
		local ringOn = scanning and 0 or 1
		st.scanDisc.CFrame = Kit.discCFrame(center, 0)
		st.scanDisc.Transparency = scanning and 0.86 or 1
		st.scanLight.Brightness = scanning and 3 or 0
		for index, seg in ipairs(st.scanRing) do
			local a = index / #st.scanRing * TAU + tau * 1.6
			local p = center + (ctx.F * math.cos(a) + ctx.R * math.sin(a)) * SCAN_R
			local tangent = ctx.R * math.cos(a) - ctx.F * math.sin(a)
			seg.CFrame = CFrame.lookAt(p, p + tangent)
			seg.Transparency = ringOn
		end
		for _, glyph in ipairs(st.glyphs) do
			local a = glyph.a - tau * 0.9
			local p = center + (ctx.F * math.cos(a) + ctx.R * math.sin(a)) * glyph.r + up * glyph.dy
			glyph.part.CFrame = CFrame.lookAt(p, center + up * glyph.dy)
			local flick = math.sin(tau * 9 + glyph.flick) > -0.3
			glyph.part.Transparency = (scanning and flick) and 0.15 or 1
		end
		fired, late = ctx:beat("eyes")
		if fired then
			eyes(ctx, true)
		end
		-- Чернила расползаются по полу.
		fired, late = ctx:beat("spread")
		if fired and not late then
			ctx:sfx("bmInkPop", ctx.B)
			Kit.shockRing(ctx.B, 12, INK_GLOW, 0.6)
		end
		local fade = span(tau, beats.roar + 0.6, ctx.cfg.full)
		for _, t in ipairs(st.tentacles) do
			local g = ease(span(tau, beats.spread + t.delay, beats.spread + t.delay + 0.7))
			local on = g > 0
			local len = t.len * g
			local count = #t.segs
			local prev
			for s = 1, count + 1 do
				local k = (s - 1) / count
				local wob = math.sin(s * 0.9 + tau * 3 + t.phase) * 0.7 * k
				local p = ctx.B + t.dir * (1.2 + len * k) + t.side * wob
				p = V3(p.X, ctx.B.Y + 0.06 + s * 0.004, p.Z)
				if prev then
					local seg = t.segs[s - 1]
					local w = 1.0 - 0.75 * k
					seg.Size = V3(w, 0.06, math.max((p - prev).Magnitude + 0.15, 0.05))
					seg.CFrame = CFrame.lookAt((p + prev) / 2, p)
					seg.Transparency = on and (0.05 + 0.95 * fade) or 1
				end
				prev = p
			end
			t.tip.CFrame = CFrame.new(prev + up * 0.15)
			t.tip.Transparency = on and (0.1 + 0.9 * fade) or 1
		end
		-- Захлопнулась: обрывки страниц разлетаются (звук — маркер Slam).
		fired, late = ctx:beat("slam")
		if fired and not late then
			ctx:shake(1.1, 0.5)
			ctx:punch(-9, 0.3)
			local mid = spine - ctx.F * 0.5
			Kit.burst(mid, 30, { PAPER, PAPER_DARK }, 0.6, 30, 0.8, ctx.B.Y + 0.1, false, Enum.Material.SmoothPlastic)
			Kit.smoke(mid, rgb(130, 120, 150), 10, 4)
			Kit.shockRing(ctx.B, 16, FROST, 0.6)
		end
		-- Корона рун над головой.
		local roar = tau >= beats.roar
		local head = ctx:part("head")
		local grow = ease(span(tau, beats.roar, beats.roar + 0.35))
		local crownFade = span(tau, ctx.cfg.full - 0.6, ctx.cfg.full)
		fired, late = ctx:beat("roar")
		if fired and not late then
			Kit.flash(head + up * 2, FROST, 6, 0.3)
		end
		for _, rune in ipairs(st.crown) do
			local a = rune.a + tau * 1.6
			local p = head + up * (2.0 + 0.15 * math.sin(tau * 3 + rune.a)) + (ctx.F * math.cos(a) + ctx.R * math.sin(a)) * 1.7 * (0.4 + 0.6 * grow)
			local cf = CFrame.lookAt(p, p + (p - (head + up * 2.0)) * V3(1, 0, 1)) * CFrame.Angles(0, 0, rune.tilt)
			rune.parts[1].CFrame = cf
			rune.parts[2].CFrame = cf * CFrame.new(0, 0.15, 0)
			for _, part in ipairs(rune.parts) do
				part.Transparency = roar and (1 - grow * (1 - crownFade)) or 1
			end
		end
	end,
	shots = {
		{ t = 0.0, fn = function(ctx, tau)
			local k = span(tau, 0, 2.0)
			local a = math.rad(-50 + 70 * smooth(k))
			return ctx:at(math.cos(a) * 13, math.sin(a) * 13, 5 - k), ctx:at(0, 0, 4.5), 52 - 4 * k
		end },
		{ t = 2.0, cut = true, pos = { 14, 2, 6 }, look = { -5, 0, 7 }, fov = 55 },
		{ t = 3.19, pos = { 13, 1, 6.5 }, look = { -5, 0, 7.5 }, fov = 54 },
		{ t = 3.2, cut = true, fn = function(ctx, tau)
			local k = span(tau, 3.2, 5.3)
			local y = scanY(ctx, tau)
			return ctx:at(9 - k, 3 - 2 * k, y + 1.8), ctx:at(0, 0, y), 46
		end },
		{ t = 5.3, cut = true, pos = { 5.5, 1, 0.6, ref = "head" }, look = { 0, 0, 0, ref = "head" }, fov = 36 },
		{ t = 5.69, pos = { 5.0, 0.9, 0.5, ref = "head" }, look = { 0, 0, 0, ref = "head" }, fov = 34 },
		{ t = 5.7, cut = true, pos = { 7, -12, 4 }, look = { -3, 0, 6.5 }, fov = 55 },
		{ t = 6.4, pos = { 6, -13, 4.5 }, look = { -3, 0, 6.5 }, fov = 57 },
		{ t = 6.79, pos = { 5.6, -13.4, 4.6 }, look = { -3, 0, 6.5 }, fov = 58 },
		{ t = 6.8, cut = true, pos = { 9, 1.5, 1.8 }, look = { 0, 0, 0, ref = "head" }, fov = 50 },
		{ t = 8.5, pos = { 12, 2.5, 4 }, look = { 0, 0, 7 }, fov = 60 },
	},
}

BossIntroScenes.setHidden = setHidden
BossIntroScenes.eyes = eyes
BossIntroScenes.span = span
BossIntroScenes.smooth = smooth

function BossIntroScenes.get(typeId: string?)
	return typeId and Scenes[typeId] or nil
end

return BossIntroScenes
