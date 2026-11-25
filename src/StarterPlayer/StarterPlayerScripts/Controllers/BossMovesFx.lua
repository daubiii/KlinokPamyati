--!nonstrict
-- BossMovesFx (клиент)
-- Картинка и звук фирменных атак боссов (Config/BossMoves, Systems/BossMoves).
-- Логики урона нет: сервер шлёт EnemyEvent { kind = "bm", move, phase, seq,
-- t0 … }, здесь всё рисуется от t0 по серверным часам — опоздавший клиент
-- видит ту же фазу. move = "cancel" (оглушение, смерть, смена фазы) гасит
-- всё, что относится к seq.
--
--   gridDrop    тени клеток → опускные решётки с шипами, пыль, уход в пол
--   keyTurn     сигил скважины, засовы-бородки поднимаются и вращаются
--   flood       лепестковые дорожки-просветы, кольцевая волна с арками роз
--   gaze        каменный глаз над Хранительницей, трещины по краям экрана,
--               вспышка; окаменение — мраморная оболочка (PetrifiedUntil)
--   houndDrive  полосы с шевронами, призрачные гончие стаями
--   huntMark    красный прицел за игроком, копьё по дуге, торчит из пола
--   ingot       точки касаний, раскалённый слиток «блинчиком»
--   bellows     горн в груди, потоки воздуха к нему, огненная нова; тяга
--               своего героя по атрибутам BossPull*
--   rewind      чернильная нить, силуэты-следы, взрывы по порядку
--   bookSlam    гигантская книга: обложка встаёт стеной и захлопывается
--
-- Детали — Lib/BossFxKit (Workspace.BossFx).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local BossGeo = require(Shared.Util.BossGeo)

local Kit = require(script.Parent.Parent.Lib.BossFxKit)
local EnemyVisualController = require(script.Parent.EnemyVisualController)

local BossMovesFx = {}

local V3 = Vector3.new
local rgb = Color3.fromRGB
local hex = Color3.fromHex
local TAU = math.pi * 2
local TEX = Kit.TEX
local random = Kit.random
local player = Players.LocalPlayer
local now = Kit.serverNow

local C = {
	-- этаж 1: железо, ржавчина, золото ключей
	iron = rgb(74, 76, 86),
	ironDark = rgb(38, 38, 44),
	rust = rgb(146, 84, 50),
	gold = rgb(255, 198, 86),
	shadow = rgb(16, 12, 10),
	danger = rgb(255, 76, 54),
	dust = rgb(150, 136, 118),
	-- этаж 2: вода, лозы, розы, мрамор
	water = rgb(92, 168, 214),
	foam = rgb(228, 246, 255),
	vine = rgb(52, 104, 56),
	leaf = rgb(92, 160, 80),
	rose = rgb(218, 64, 104),
	petal = rgb(255, 156, 186),
	marble = rgb(224, 222, 214),
	marbleDark = rgb(150, 148, 142),
	jade = rgb(120, 226, 176),
	-- этаж 3: охота
	blood = rgb(224, 40, 36),
	ghost = rgb(190, 236, 255),
	amber = rgb(255, 176, 60),
	wood = rgb(110, 76, 46),
	safe = rgb(240, 204, 96),
	-- этаж 4: горн
	soot = hex("#1E1B1F"),
	ember = hex("#E2672B"),
	flame = hex("#FFC857"),
	white = rgb(255, 241, 184),
	crust = rgb(58, 40, 36),
	-- этаж 5: чернила и бумага
	ink = rgb(26, 22, 48),
	inkGloss = hex("#4A3F8F"),
	rune = hex("#8E7CE0"),
	frost = hex("#B8E3FF"),
	paper = rgb(236, 228, 204),
	paperDark = rgb(190, 176, 140),
	leather = rgb(92, 38, 44),
	goldLeaf = rgb(222, 180, 90),
}
BossMovesFx.Colors = C

-- ===== Прогоны =====
-- Каждый эффект — прогон { seq, model, parts, update(t, dt) → жив?, done() }.
-- Отмена по seq или смене состояния модели (для разметки замаха) гасит
-- детали за 0,25 с.

local runs = {}
local shared = {} -- [seq] = общее состояние нескольких событий одной атаки

local function newRun(payload, opts)
	local r = {
		seq = payload.seq,
		model = payload.model,
		t0 = payload.t0 or now(),
		parts = {},
		keepOnCancel = opts and opts.keepOnCancel or false,
		bound = opts and opts.bound or nil, -- допустимые состояния модели
		update = nil,
		cleanup = nil,
		finished = false,
	}
	function r.add(item)
		table.insert(r.parts, item)
		return item
	end
	table.insert(runs, r)
	return r
end

local function endRun(r, cancelled: boolean)
	if r.finished then
		return
	end
	r.finished = true
	if r.cleanup then
		pcall(r.cleanup, cancelled)
	end
	for _, item in ipairs(r.parts) do
		if item and item.Parent then
			Kit.fade(item, cancelled and 0.2 or 0.35)
		end
	end
end

local function cancelSeq(seq)
	for _, r in ipairs(runs) do
		if r.seq == seq and not r.keepOnCancel then
			endRun(r, true)
		end
	end
	shared[seq] = nil
end

local function stateOf(model): string
	return model and model.Parent and model:GetAttribute("EnemyState") or "gone"
end

local function stepRuns(dt: number)
	local t = now()
	for index = #runs, 1, -1 do
		local r = runs[index]
		if not r.finished then
			if r.bound and not r.bound[stateOf(r.model)] then
				endRun(r, true)
			else
				local ok, alive = pcall(r.update, t, dt)
				if not ok then
					warn("BossMovesFx: " .. tostring(alive))
					alive = false
				end
				if not alive then
					endRun(r, false)
				end
			end
		end
		if r.finished then
			table.remove(runs, index)
		end
	end
end

-- ===== Босс и игроки =====

local function rigOf(model)
	return model and EnemyVisualController.rigOf(model)
end

local function bossPos(model): Vector3
	local rig = rigOf(model)
	if rig and rig.pos then
		return rig.pos
	end
	if model and model.Parent then
		return model:GetPivot().Position
	end
	return Vector3.zero
end

local function bossPart(model, name: string): Vector3?
	local rig = rigOf(model)
	local p = rig and rig.model and rig.model:FindFirstChild(name, true)
	return p and p:IsA("BasePart") and p.Position or nil
end

local function rootOf(target): BasePart?
	local character = target and target.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- Одноразовая поза поверх канала (бросок, повторная вспышка) с возвратом.
local function beat(model, name: string, back: string, at: number?)
	local rig = rigOf(model)
	local animator = rig and rig.animator
	if not animator or rig.state ~= "channel" then
		return
	end
	animator:playAction(name, 1, at or now())
	animator.action.after = { name = back }
end

local function ease(k: number): number
	k = math.clamp(k, 0, 1)
	return 1 - (1 - k) * (1 - k)
end

local function easeIn(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k
end

local tipsShown = {}
local function tipOnce(key: string, text: string)
	if not tipsShown[key] then
		tipsShown[key] = true
		Kit.notify(text)
	end
end

local handlers = {}

-- ======================================================================
-- Привратник
-- ======================================================================

-- Опускная решётка: рама с крестом и девять шипов вниз. Смещения — от
-- середины верхней рамы.
local function buildGrate(size: number, spike: number)
	local h = size / 2 - 0.25
	local list = {}
	local function add(sizeV: Vector3, offset: Vector3, color: Color3, material)
		local p = Kit.part({ Name = "Grate", Size = sizeV, Color = color, Material = material or Enum.Material.Metal, CastShadow = true })
		table.insert(list, { part = p, offset = CFrame.new(offset) })
	end
	add(V3(size, 0.5, 0.5), V3(0, 0, h), C.rust)
	add(V3(size, 0.5, 0.5), V3(0, 0, -h), C.rust)
	add(V3(0.5, 0.5, size), V3(h, 0, 0), C.rust)
	add(V3(0.5, 0.5, size), V3(-h, 0, 0), C.rust)
	add(V3(size, 0.36, 0.36), V3(0, 0.05, 0), C.ironDark)
	add(V3(0.36, 0.36, size), V3(0, 0.05, 0), C.ironDark)
	for _, x in ipairs({ -h, 0, h }) do
		for _, z in ipairs({ -h, 0, h }) do
			add(V3(0.36, spike, 0.36), V3(x, -spike / 2, z), C.iron)
		end
	end
	return list
end

local function placeGrate(list, origin: CFrame)
	local parts, frames = {}, {}
	for _, item in ipairs(list) do
		table.insert(parts, item.part)
		table.insert(frames, origin * item.offset)
	end
	Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Контур клетки: четыре тонкие полосы.
local function outline(r, axes: CFrame, size: number, color: Color3)
	local h = size / 2
	local list = {}
	for _, spec in ipairs({ { V3(size, 0.06, 0.16), V3(0, 0, h) }, { V3(size, 0.06, 0.16), V3(0, 0, -h) },
		{ V3(0.16, 0.06, size), V3(h, 0, 0) }, { V3(0.16, 0.06, size), V3(-h, 0, 0) } }) do
		local p = r.add(Kit.part({ Name = "Edge", Size = spec[1], CFrame = axes * CFrame.new(spec[2]), Color = color, Material = Enum.Material.Neon, Transparency = 0.6 }))
		table.insert(list, p)
	end
	return list
end

local GRATE_FALL = 0.26
local SPIKE = 4.2

handlers.gridDrop = function(payload)
	local center = payload.center
	local fwd = payload.fwd
	local arena = payload.arena
	local cells = BossGeo.gridCells(center.X, center.Z, fwd.X, fwd.Z, payload.cell, payload.grid, arena)
	local y = center.Y
	local r = newRun(payload)
	local size = payload.cell - 0.5
	local waves = {}
	for wave = 1, payload.waves do
		local w = {
			shownAt = r.t0 + (wave - 1) * payload.gap,
			dropAt = r.t0 + payload.warn + (wave - 1) * payload.gap,
			cells = {},
			shown = false,
			falling = false,
			landed = false,
			gone = false,
		}
		for _, cell in ipairs(cells) do
			if BossGeo.cellDrops(cell.i, cell.j, wave) then
				table.insert(w.cells, { x = cell.x, z = cell.z })
			end
		end
		table.insert(waves, w)
	end
	local lastEnd = waves[#waves].dropAt + payload.stay + payload.sink + 0.2
	local axesOf = function(cx: number, cz: number)
		local p = V3(cx, y, cz)
		return CFrame.lookAt(p, p + fwd)
	end

	r.update = function(t)
		for _, w in ipairs(waves) do
			if not w.shown and t >= w.shownAt then
				w.shown = true
				for _, cell in ipairs(w.cells) do
					local axes = axesOf(cell.x, cell.z)
					cell.shadow = r.add(Kit.part({ Name = "GrateShadow", Size = V3(size, 0.05, size), CFrame = axes * CFrame.new(0, 0.07, 0), Color = C.shadow, Transparency = 1 }))
					cell.edges = outline(r, axes * CFrame.new(0, 0.09, 0), size, C.danger)
				end
			end
			if w.shown and not w.landed then
				local k = math.clamp((t - w.shownAt) / math.max(w.dropAt - w.shownAt, 0.05), 0, 1)
				local blink = (t > w.dropAt - 0.35) and (math.floor(t * 14) % 2 == 0) and 0.05 or 0.45
				for _, cell in ipairs(w.cells) do
					cell.shadow.Transparency = 1 - 0.65 * k
					local s = size * (0.55 + 0.45 * k)
					cell.shadow.Size = V3(s, 0.05, s)
					for _, edge in ipairs(cell.edges) do
						edge.Transparency = blink
					end
				end
			end
			if w.shown and not w.falling and t >= w.dropAt - GRATE_FALL then
				w.falling = true
				Kit.sfx("chainRattle", center)
				for _, cell in ipairs(w.cells) do
					cell.grate = buildGrate(size, SPIKE)
					for _, item in ipairs(cell.grate) do
						r.add(item.part)
					end
				end
			end
			if w.falling and not w.gone then
				local lift
				if t < w.dropAt then
					lift = payload.height * (1 - easeIn(1 - (w.dropAt - t) / GRATE_FALL))
				elseif t < w.dropAt + payload.stay then
					lift = 0
				else
					lift = -(SPIKE + 0.7) * ease((t - w.dropAt - payload.stay) / payload.sink)
				end
				for _, cell in ipairs(w.cells) do
					placeGrate(cell.grate, axesOf(cell.x, cell.z) * CFrame.new(0, SPIKE - 0.6 + lift, 0))
				end
				if not w.landed and t >= w.dropAt then
					w.landed = true
					Kit.sfx("bmGateSlam", center)
					Kit.shakeAt(center, 0.7, 0.28, 45)
					for index, cell in ipairs(w.cells) do
						local p = V3(cell.x, y + 0.3, cell.z)
						Kit.smoke(p, C.dust, 3, 2.6)
						Kit.burst(p, 3, { C.dust, C.ironDark }, 0.35, 16, 0.8, y + 0.15)
						if index % 3 == 1 then
							Kit.sparks(p + V3(0, 0.4, 0), C.gold, 10, 16)
						end
						Kit.fade(cell.shadow, 0.15)
						for _, edge in ipairs(cell.edges) do
							Kit.fade(edge, 0.15)
						end
					end
				end
				if t >= w.dropAt + payload.stay + payload.sink then
					w.gone = true
					for _, cell in ipairs(w.cells) do
						for _, item in ipairs(cell.grate) do
							item.part:Destroy()
						end
					end
				end
			end
		end
		return t < lastEnd
	end
end

-- Засов-бородка: брус от центра наружу, зубцы сверху, золотая жила.
local function buildBolt(radius: number, width: number)
	local length = radius - 1.6
	local list = {}
	local function add(sizeV: Vector3, offset: Vector3, color: Color3, material, transparency)
		local p = Kit.part({ Name = "Bolt", Size = sizeV, Color = color, Material = material or Enum.Material.Metal, Transparency = transparency or 0, CastShadow = true })
		table.insert(list, { part = p, offset = CFrame.new(offset) })
	end
	-- Смещения вдоль +Z (наружу от центра), середина бруса — на 1,6 + length/2.
	local mid = 1.6 + length / 2
	add(V3(width, 1.5, length), V3(0, 0.75, mid), C.iron)
	add(V3(width * 0.3, 0.08, length * 0.96), V3(0, 1.54, mid), C.gold, Enum.Material.Neon)
	for index = 1, 3 do
		local along = radius - 1.2 - (index - 1) * 2.2
		add(V3(width * 0.92, 0.7 + (index % 2) * 0.35, 1.2), V3(0, 1.85 + (index % 2) * 0.17, along), C.rust)
	end
	add(V3(width + 0.4, 1.9, 0.6), V3(0, 0.95, radius - 0.3), C.ironDark)
	return list
end

handlers.keyTurn = function(payload)
	local center = payload.center
	local r = newRun(payload)
	local spinFrom = r.t0 + payload.rise
	local spinTo = spinFrom + payload.spin
	local endAt = spinTo + 0.35
	-- Сигил скважины.
	local sigil = r.add(Kit.disc(center, 2.6, C.gold, 0.35, 0.09))
	local hole = r.add(Kit.disc(center, 0.8, C.shadow, 0.05, 0.11, false))
	local slot = r.add(Kit.part({ Name = "Slot", Size = V3(0.6, 0.06, 1.8), CFrame = CFrame.new(center + V3(0, 0.11, 0)) * CFrame.Angles(0, payload.a0, 0) * CFrame.new(0, 0, -1), Color = C.shadow }))
	local zone = r.add(Kit.disc(center, payload.radius, C.danger, 0.86, 0.06))
	Kit.tween(sigil, 0.4, { Size = V3(0.06, 6.4, 6.4) }, Enum.EasingStyle.Back)
	Kit.sparks(center + V3(0, 0.5, 0), C.gold, 22, 20)
	Kit.smoke(center + V3(0, 0.3, 0), C.dust, 6, 2.4)
	for _ = 1, 7 do
		local a = random:NextNumber(0, TAU)
		local length = random:NextNumber(3, 7)
		local dx, dz = BossGeo.dirOf(a)
		r.add(Kit.beamPart(center + V3(dx * 1.4, 0.08, dz * 1.4), center + V3(dx * (1.4 + length), 0.08, dz * (1.4 + length)), random:NextNumber(0.12, 0.25), 0.04, C.shadow))
	end
	local bolts, warnStrips = {}, {}
	for index = 1, payload.bolts do
		table.insert(bolts, buildBolt(payload.radius, payload.width))
		for _, item in ipairs(bolts[index]) do
			r.add(item.part)
		end
		local strip = r.add(Kit.part({ Name = "BoltWarn", Size = V3(payload.width, 0.05, payload.radius - 1.6), Color = C.danger, Material = Enum.Material.Neon, Transparency = 0.5 }))
		table.insert(warnStrips, strip)
	end
	local nextSpark, creaked = 0, false
	r.update = function(t)
		local k = math.max(t - spinFrom, 0)
		k = math.min(k, payload.spin)
		local angles = BossGeo.boltAngles(payload.a0, payload.bolts, payload.speed, k)
		local lift
		if t < spinFrom then
			lift = -2.4 + 2.4 * ease((t - r.t0) / payload.rise)
		elseif t < spinTo then
			lift = 0
		else
			lift = -2.4 * easeIn((t - spinTo) / 0.3)
		end
		local tips = {}
		for index, angle in ipairs(angles) do
			local base = CFrame.new(center) * CFrame.Angles(0, angle, 0)
			placeGrate(bolts[index], base * CFrame.new(0, lift, 0))
			local strip = warnStrips[index]
			strip.CFrame = base * CFrame.new(0, 0.07, 1.6 + (payload.radius - 1.6) / 2)
			strip.Transparency = t < spinFrom and (0.35 + 0.3 * math.sin(t * 18)) or 0.8
			table.insert(tips, (base * CFrame.new(0, 0.3, payload.radius - 0.3)).Position)
		end
		slot.CFrame = CFrame.new(center + V3(0, 0.11, 0)) * CFrame.Angles(0, angles[1], 0) * CFrame.new(0, 0, -1)
		if t >= spinFrom and not creaked then
			creaked = true
			Kit.sfx("gateCreak", center)
		end
		if t >= spinFrom and t < spinTo and t >= nextSpark then
			nextSpark = t + 0.09
			for _, tip in ipairs(tips) do
				Kit.burst(tip, 2, { C.gold, C.flame }, 0.18, 12, 0.6, center.Y + 0.1, true)
			end
		end
		zone.Transparency = 0.86 + 0.06 * math.sin(t * 6)
		return t < endAt
	end
	r.cleanup = function()
		Kit.sfx("chainSlam", center)
		Kit.fade(hole, 0.3)
	end
end

-- ======================================================================
-- Хранительница роз
-- ======================================================================

-- Лепестковая дорожка: безопасный просвет волны от центра к краю.
local function petalPath(r, center: Vector3, angle: number, gapWidth: number, fromR: number, toR: number, unroll: number, faint: boolean?)
	local dx, dz = BossGeo.dirOf(angle)
	local sx, sz = dz, -dx
	local items = {}
	local radius = fromR
	local index = 0
	while radius <= toR do
		index += 1
		local spread = math.min(radius * gapWidth * 0.32, 4)
		for _ = 1, 2 do
			local side = random:NextNumber(-spread, spread)
			local p = center + V3(dx * radius + sx * side, 0.09, dz * radius + sz * side)
			local petal = r.add(Kit.part({
				Name = "Petal", Size = V3(0.9, 0.06, 0.55), Color = random:NextNumber() < 0.7 and C.petal or C.rose,
				Material = Enum.Material.Neon, Transparency = 1,
				CFrame = CFrame.new(p) * CFrame.Angles(0, random:NextNumber(0, TAU), 0),
			}))
			table.insert(items, { part = petal, at = unroll * (radius - fromR) / math.max(toR - fromR, 1) })
		end
		radius += 2.3
	end
	-- Кромки просвета — тонкие зелёные линии.
	for _, sign in ipairs({ -1, 1 }) do
		local ex, ez = BossGeo.dirOf(angle + sign * gapWidth / 2)
		local edge = r.add(Kit.beamPart(center + V3(ex * fromR, 0.08, ez * fromR), center + V3(ex * toR, 0.08, ez * toR), 0.16, 0.05, C.leaf, true, 1))
		table.insert(items, { part = edge, at = 0, edge = true })
	end
	return items
end

local function showPetals(items, elapsed: number, faint: boolean?)
	for _, item in ipairs(items) do
		local k = math.clamp((elapsed - item.at) / 0.25, 0, 1)
		local target = item.edge and 0.55 or (faint and 0.55 or 0.15)
		item.part.Transparency = 1 - (1 - target) * k
	end
end

handlers.flood = function(payload)
	if payload.phase == "mark" then
		local r = newRun(payload, { bound = { windup = true, strike = true, channel = true } })
		local center = payload.center
		local paths = {}
		for _, gap in ipairs(payload.gaps) do
			table.insert(paths, petalPath(r, center, gap, payload.gapWidth, 3, payload.maxR, payload.windup * 0.7))
		end
		local pool = r.add(Kit.disc(center, 2, C.water, 0.45, 0.07))
		Kit.tween(pool, payload.windup, { Size = V3(0.06, 11, 11), Transparency = 0.3 })
		local anchor = Kit.emitter(center + V3(0, 0.4, 0), {
			tex = TEX.glow, color = Kit.cseq(C.foam, C.water), rate = 70, life = { 0.5, 0.9 }, speed = { 8, 14 }, spread = 18,
			size = Kit.nseq({ { 0, 0.5 }, { 1, 0.1 } }), transp = Kit.nseq({ { 0, 0.2 }, { 1, 1 } }), accel = V3(0, -30, 0), light = 0.4,
		}, payload.windup)
		r.add(anchor)
		local endAt = r.t0 + payload.windup + 3.4
		r.update = function(t)
			for _, items in ipairs(paths) do
				showPetals(items, t - r.t0)
			end
			return t < endAt
		end
		return
	end
	-- Волна.
	local r = newRun(payload)
	local center = payload.center
	local half = payload.gapWidth / 2
	local SEG = 64
	local segments = {}
	for index = 1, SEG do
		local angle = (index - 0.5) / SEG * TAU
		if not BossGeo.inGap(angle, payload.gaps, half) then
			local water = r.add(Kit.part({ Name = "Wave", Size = V3(payload.thick, 0.2, 1), Color = C.water, Material = Enum.Material.Glass, Transparency = 0.25 }))
			local crest = r.add(Kit.part({ Name = "Crest", Size = V3(payload.thick * 0.7, 0.45, 1), Color = C.foam, Material = Enum.Material.Neon, Transparency = 0.25 }))
			if #segments % 6 == 0 then
				Kit.emitter(Vector3.zero, {
					parent = crest, tex = TEX.glow, color = C.foam, rate = 26, life = { 0.4, 0.7 }, speed = { 4, 9 }, spread = 40,
					size = Kit.nseq({ { 0, 0.6 }, { 1, 0.15 } }), transp = Kit.nseq({ { 0, 0.3 }, { 1, 1 } }), accel = V3(0, -25, 0), light = 0.3,
				})
			end
			table.insert(segments, { angle = angle, water = water, crest = crest })
		end
	end
	-- Арки роз над просветами.
	local arches = {}
	for _, gap in ipairs(payload.gaps) do
		local arch = { gap = gap, pillars = {}, roses = {} }
		for _ = 1, 2 do
			table.insert(arch.pillars, r.add(Kit.part({ Name = "Vine", Size = V3(0.7, 4.4, 0.7), Color = C.vine, Material = Enum.Material.Grass })))
		end
		arch.beam = r.add(Kit.part({ Name = "ArchVine", Size = V3(0.5, 0.5, 1), Color = C.vine, Material = Enum.Material.Grass }))
		for _ = 1, 4 do
			table.insert(arch.roses, r.add(Kit.part({ Name = "Rose", Shape = Enum.PartType.Ball, Size = V3(1, 1, 1), Color = C.rose, Material = Enum.Material.Neon })))
		end
		table.insert(arches, arch)
	end
	local nextPaths
	if payload.nextGaps then
		nextPaths = {}
		for _, gap in ipairs(payload.nextGaps) do
			table.insert(nextPaths, petalPath(r, center, gap, payload.gapWidth, 3, payload.maxR, 0.4, true))
		end
	end
	if (payload.wave or 1) > 1 then
		Kit.sfx("gardenFlood", center)
	end
	local travel = (payload.maxR - payload.startR) / payload.speed
	local endAt = r.t0 + travel + 0.45
	r.update = function(t)
		local age = t - r.t0
		local radius = payload.startR + payload.speed * math.min(age, travel)
		local rise = ease(age / 0.18)
		local fall = age > travel and (1 - ease((age - travel) / 0.4)) or 1
		local height = 3.1 * rise * fall
		local arc = radius * TAU / SEG * 1.08
		local parts, frames = {}, {}
		for _, s in ipairs(segments) do
			local dx, dz = BossGeo.dirOf(s.angle)
			local p = center + V3(dx * radius, 0, dz * radius)
			local look = CFrame.lookAt(p, p + V3(dz, 0, -dx))
			s.water.Size = V3(payload.thick, math.max(height, 0.1), arc)
			s.crest.Size = V3(payload.thick * 0.7, 0.45, arc)
			table.insert(parts, s.water)
			table.insert(frames, look * CFrame.new(0, height / 2, 0))
			table.insert(parts, s.crest)
			table.insert(frames, look * CFrame.new(0, height + 0.1 * math.sin(t * 9 + s.angle * 5), 0))
		end
		for _, arch in ipairs(arches) do
			local tops = {}
			for index, sign in ipairs({ -1, 1 }) do
				local dx, dz = BossGeo.dirOf(arch.gap + sign * (half + 0.03))
				local base = center + V3(dx * radius, 0, dz * radius)
				local pillarH = 4.4 * rise * fall
				table.insert(parts, arch.pillars[index])
				table.insert(frames, CFrame.new(base + V3(0, pillarH / 2, 0)))
				table.insert(tops, base + V3(0, pillarH, 0))
			end
			local mid = (tops[1] + tops[2]) / 2 + V3(0, 0.8 * rise * fall, 0)
			arch.beam.Size = V3(0.5, 0.5, math.max((tops[2] - tops[1]).Magnitude, 0.1))
			table.insert(parts, arch.beam)
			table.insert(frames, CFrame.lookAt(mid, tops[2] + V3(0, 0.8 * rise * fall, 0) + V3(0, 1e-4, 0)))
			for index, rose in ipairs(arch.roses) do
				local k = (index - 0.5) / #arch.roses
				local p = tops[1]:Lerp(tops[2], k) + V3(0, math.sin(k * math.pi) * 0.8 * rise * fall + 0.3, 0)
				table.insert(parts, rose)
				table.insert(frames, CFrame.new(p))
			end
		end
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		if nextPaths then
			for _, items in ipairs(nextPaths) do
				showPetals(items, age, true)
			end
		end
		return t < endAt
	end
end

-- Каменный глаз над Хранительницей (BillboardGui).
local function buildEye(adornee: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "GazeEye"
	gui.Size = UDim2.new(8, 0, 4, 0)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Adornee = adornee
	local glow = Instance.new("ImageLabel")
	glow.BackgroundTransparency = 1
	glow.Image = TEX.glow
	glow.ImageColor3 = C.jade
	glow.ImageTransparency = 0.6
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.6, 2.4)
	glow.Parent = gui
	local sclera = Instance.new("Frame")
	sclera.AnchorPoint = Vector2.new(0.5, 0.5)
	sclera.Position = UDim2.fromScale(0.5, 0.5)
	sclera.Size = UDim2.fromScale(0.96, 0.8)
	sclera.BackgroundColor3 = C.marble
	sclera.ClipsDescendants = true
	sclera.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = sclera
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.marbleDark
	stroke.Thickness = 3
	stroke.Parent = sclera
	local iris = Instance.new("Frame")
	iris.AnchorPoint = Vector2.new(0.5, 0.5)
	iris.Position = UDim2.fromScale(0.5, 0.5)
	iris.Size = UDim2.fromScale(0.36, 0.9)
	iris.BackgroundColor3 = C.jade
	iris.Parent = sclera
	Instance.new("UICorner", iris).CornerRadius = UDim.new(0.5, 0)
	local pupil = Instance.new("Frame")
	pupil.AnchorPoint = Vector2.new(0.5, 0.5)
	pupil.Position = UDim2.fromScale(0.5, 0.5)
	pupil.Size = UDim2.fromScale(0.3, 0.8)
	pupil.BackgroundColor3 = rgb(16, 24, 20)
	pupil.Parent = iris
	Instance.new("UICorner", pupil).CornerRadius = UDim.new(0.5, 0)
	local lids = {}
	for _, top in ipairs({ true, false }) do
		local lid = Instance.new("Frame")
		lid.BackgroundColor3 = C.marbleDark
		lid.BorderSizePixel = 0
		lid.Size = UDim2.fromScale(1, 0.52)
		lid.Position = UDim2.fromScale(0, top and 0 or 0.48)
		lid.ZIndex = 3
		lid.Parent = sclera
		table.insert(lids, lid)
	end
	local crack = Instance.new("ImageLabel")
	crack.BackgroundTransparency = 1
	crack.Image = TEX.crack
	crack.ImageColor3 = rgb(60, 60, 58)
	crack.ImageTransparency = 1
	crack.Size = UDim2.fromScale(1, 1)
	crack.ZIndex = 4
	crack.Parent = sclera
	gui.Parent = adornee
	return { gui = gui, glow = glow, lids = lids, crack = crack, iris = iris }
end

local function setLids(eye, open: number)
	-- open: 0 — закрыт, 1 — распахнут.
	eye.lids[1].Position = UDim2.fromScale(0, -0.52 * open)
	eye.lids[2].Position = UDim2.fromScale(0, 0.48 + 0.52 * open)
end

-- Трещины по краям своего экрана (пока Хранительница готовит взгляд).
local screenGui
local function screen()
	if screenGui and screenGui.Parent then
		return screenGui
	end
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BossMovesFx"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 30
	screenGui.Parent = player:WaitForChild("PlayerGui")
	return screenGui
end

local function buildCracks()
	local root = Instance.new("Frame")
	root.Name = "GazeCracks"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = screen()
	local images = {}
	for index, spec in ipairs({ { 0, 0, 0 }, { 1, 0, 90 }, { 1, 1, 180 }, { 0, 1, 270 } }) do
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = TEX.crack
		image.ImageColor3 = rgb(70, 70, 66)
		image.ImageTransparency = 1
		image.AnchorPoint = Vector2.new(spec[1], spec[2])
		image.Position = UDim2.fromScale(spec[1], spec[2])
		image.Size = UDim2.fromScale(0.42, 0.42)
		image.Rotation = spec[3]
		image.Parent = root
		images[index] = image
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.2)
	label.Size = UDim2.fromScale(0.6, 0.08)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = "ОТВЕРНИСЬ!"
	label.TextColor3 = C.marble
	label.TextTransparency = 1
	label.Parent = root
	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(30, 30, 28)
	stroke.Thickness = 3
	stroke.Parent = label
	return { root = root, images = images, label = label, stroke = stroke }
end

local function flashScreen(color: Color3, from: number, time: number)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = from
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = screen()
	Kit.tween(frame, time, { BackgroundTransparency = 1 })
	task.delay(time + 0.05, function()
		frame:Destroy()
	end)
end

handlers.gaze = function(payload)
	local key = "gaze:" .. tostring(payload.model)
	if payload.phase == "mark" then
		local r = newRun(payload, { bound = { windup = true, strike = true, channel = true } })
		local anchor = r.add(Kit.part({ Name = "EyeAnchor", Size = V3(0.2, 0.2, 0.2), Transparency = 1 }))
		local eye = buildEye(anchor)
		setLids(eye, 0)
		local cracks
		local root = rootOf(player)
		local inRange = root and (root.Position - bossPos(payload.model)).Magnitude <= payload.range + 4
		if inRange then
			cracks = buildCracks()
			tipOnce("gaze", "Мраморный взгляд: отвернись от Хранительницы, когда откроется глаз!")
		end
		Kit.sfx("statueCrack", bossPos(payload.model))
		local state = { eye = eye, run = r, cracks = cracks, openUntil = 0, pulses = payload.pulses }
		shared[key] = state
		local strikeAt = r.t0 + payload.windup
		local endAt = strikeAt + (payload.pulses - 1) * payload.pulseGap + 1.2
		r.update = function(t)
			local head = bossPart(payload.model, "Head") or (bossPos(payload.model) + V3(0, 6, 0))
			anchor.CFrame = CFrame.new(head + V3(0, 4.2 + math.sin(t * 2) * 0.15, 0))
			local k = math.clamp((t - r.t0) / payload.windup, 0, 1)
			eye.crack.ImageTransparency = 1 - 0.8 * k
			eye.glow.ImageTransparency = 0.75 - 0.35 * k
			eye.glow.Size = UDim2.fromScale(1.4 + 0.6 * k, 2.2 + 0.8 * k)
			if t < state.openUntil then
				setLids(eye, 1)
			elseif t >= strikeAt then
				setLids(eye, 0.08)
			else
				setLids(eye, 0.04 * math.sin(t * 30) ^ 2)
			end
			if cracks then
				local c = t < strikeAt and k or math.max(0, 1 - (t - strikeAt) / 0.6)
				for _, image in ipairs(cracks.images) do
					image.ImageTransparency = 1 - 0.75 * c
				end
				local blink = t > strikeAt - 0.6 and t < strikeAt and (math.floor(t * 8) % 2 == 0)
				cracks.label.TextTransparency = (t < strikeAt and k > 0.25) and (blink and 0 or 0.25) or 1
				cracks.stroke.Transparency = cracks.label.TextTransparency
			end
			return t < endAt
		end
		r.cleanup = function()
			if cracks then
				cracks.root:Destroy()
			end
			if eye.gui then
				eye.gui:Destroy()
			end
			if shared[key] == state then
				shared[key] = nil
			end
		end
		return
	end
	-- Вспышка.
	local state = shared[key]
	local at = bossPart(payload.model, "Head") or (bossPos(payload.model) + V3(0, 6, 0))
	local eyeAt = at + V3(0, 4.2, 0)
	if state then
		state.openUntil = payload.t0 + 0.45
		Kit.tween(state.eye.glow, 0.15, { ImageTransparency = 0 })
		if payload.pulse and payload.pulse > 1 then
			beat(payload.model, "Gaze_Pulse", "Gaze_Channel", payload.t0)
		end
	end
	Kit.flash(eyeAt, C.jade, 14, 0.35)
	Kit.shockRing(bossPos(payload.model), 30, C.jade, 0.5)
	local root = rootOf(player)
	local mine = false
	for _, victim in ipairs(payload.victims or {}) do
		if victim == player then
			mine = true
		end
	end
	if mine then
		flashScreen(C.marble, 0, 0.6)
		Kit.sfx("bmPetrify", root and root.Position)
	elseif root and (root.Position - eyeAt).Magnitude < 48 then
		flashScreen(C.jade, 0.75, 0.3)
	end
end

-- ===== Окаменение: мраморная оболочка на любом игроке =====

local shells = {} -- [player] = { parts = { { part, src } }, untilT }

local function shatterShell(entry)
	for _, item in ipairs(entry.parts) do
		local p = item.part
		if p.Parent then
			Kit.burst(p.Position, 2, { C.marble, C.marbleDark }, 0.4, 14, 0.7, p.Position.Y - 3, false, Enum.Material.Marble)
			p:Destroy()
		end
	end
	if entry.tint then
		Kit.tween(entry.tint, 0.4, { Saturation = 0, Brightness = 0, Contrast = 0 })
		task.delay(0.45, function()
			entry.tint:Destroy()
		end)
	end
end

local function stepShells()
	local t = now()
	for _, other in ipairs(Players:GetPlayers()) do
		local untilT = other:GetAttribute("PetrifiedUntil") or 0
		local entry = shells[other]
		local character = other.Character
		if untilT > t and character and not entry then
			entry = { parts = {} }
			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and child.Transparency < 0.9 then
					local shell = Kit.part({
						Name = "Marble", Size = child.Size * 1.12, CFrame = child.CFrame, Color = random:NextNumber() < 0.5 and C.marble or rgb(206, 204, 196),
						Material = Enum.Material.Marble, Transparency = 1,
					})
					Kit.tween(shell, 0.25, { Transparency = 0 })
					table.insert(entry.parts, { part = shell, src = child })
				end
			end
			if other == player then
				local tint = Instance.new("ColorCorrectionEffect")
				tint.Name = "BossPetrify"
				tint.Parent = Lighting
				Kit.tween(tint, 0.3, { Saturation = -0.85, Contrast = 0.15, Brightness = -0.03 })
				entry.tint = tint
			end
			Kit.sfx("bmPetrify", character:GetPivot().Position)
			shells[other] = entry
		end
		if entry then
			if untilT <= t or not character or not character.Parent then
				shatterShell(entry)
				shells[other] = nil
			else
				local parts, frames = {}, {}
				for _, item in ipairs(entry.parts) do
					if item.src.Parent then
						table.insert(parts, item.part)
						table.insert(frames, item.src.CFrame)
					end
				end
				Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
			end
		end
	end
	for other, entry in pairs(shells) do
		if not other.Parent then
			shatterShell(entry)
			shells[other] = nil
		end
	end
end

-- ======================================================================
-- Королевский ловчий
-- ======================================================================

-- Призрачная гончая: смещения от «корня» (пол под грудью, взгляд +Z).
local HOUND = {
	{ name = "Body", size = V3(1.1, 1.0, 2.7), at = V3(0, 1.75, -0.4) },
	{ name = "Chest", size = V3(1.25, 1.25, 1.0), at = V3(0, 1.85, 0.9) },
	{ name = "Head", size = V3(0.85, 0.8, 1.0), at = V3(0, 2.45, 1.75) },
	{ name = "Snout", size = V3(0.5, 0.45, 0.7), at = V3(0, 2.25, 2.5) },
	{ name = "EarL", size = V3(0.18, 0.55, 0.3), at = V3(-0.28, 3.0, 1.55) },
	{ name = "EarR", size = V3(0.18, 0.55, 0.3), at = V3(0.28, 3.0, 1.55) },
	{ name = "LegFL", size = V3(0.3, 1.3, 0.3), at = V3(-0.38, 0.65, 0.95), leg = 1 },
	{ name = "LegFR", size = V3(0.3, 1.3, 0.3), at = V3(0.38, 0.65, 0.95), leg = -1 },
	{ name = "LegBL", size = V3(0.3, 1.3, 0.3), at = V3(-0.38, 0.65, -1.4), leg = -1 },
	{ name = "LegBR", size = V3(0.3, 1.3, 0.3), at = V3(0.38, 0.65, -1.4), leg = 1 },
	{ name = "Tail", size = V3(0.2, 0.2, 1.3), at = V3(0, 2.2, -2.2), tail = true },
	{ name = "EyeL", size = V3(0.16, 0.16, 0.1), at = V3(-0.22, 2.6, 2.26), eye = true },
	{ name = "EyeR", size = V3(0.16, 0.16, 0.1), at = V3(0.22, 2.6, 2.26), eye = true },
}

local function buildHound(r)
	local list = {}
	for _, spec in ipairs(HOUND) do
		local p = r.add(Kit.part({
			Name = "Hound" .. spec.name, Size = spec.size, Color = spec.eye and C.amber or C.ghost,
			Material = Enum.Material.Neon, Transparency = spec.eye and 0 or 0.45,
		}))
		table.insert(list, { part = p, spec = spec })
		if spec.name == "Body" then
			Kit.emitter(Vector3.zero, {
				parent = p, tex = TEX.smoke, color = C.ghost, rate = 22, life = { 0.4, 0.8 }, speed = { 0.5, 1.5 }, spread = 60,
				size = Kit.nseq({ { 0, 1.2 }, { 1, 2.2 } }), transp = Kit.nseq({ { 0, 0.6 }, { 1, 1 } }), light = 0.6, drag = 3,
			})
		end
	end
	return list
end

local function poseHound(list, base: CFrame, phase: number, parts, frames)
	local bob = math.abs(math.sin(phase)) * 0.25
	for _, item in ipairs(list) do
		local spec = item.spec
		local cf
		if spec.leg then
			local swing = math.sin(phase) * 0.9 * spec.leg
			cf = base * CFrame.new(spec.at.X, 1.3, spec.at.Z) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -0.65, 0)
		elseif spec.tail then
			cf = base * CFrame.new(spec.at + V3(0, bob, 0)) * CFrame.Angles(0.5 + math.sin(phase * 2) * 0.2, math.sin(phase) * 0.4, 0)
		else
			cf = base * CFrame.new(spec.at + V3(0, bob, 0))
		end
		table.insert(parts, item.part)
		table.insert(frames, cf)
	end
end

-- Шеврон «>» из двух полосок, острием по ходу бега.
local function chevron(r, color: Color3)
	local a = r.add(Kit.part({ Name = "Chevron", Size = V3(0.3, 0.05, 2.0), Color = color, Material = Enum.Material.Neon, Transparency = 0.4 }))
	local b = r.add(Kit.part({ Name = "Chevron", Size = V3(0.3, 0.05, 2.0), Color = color, Material = Enum.Material.Neon, Transparency = 0.4 }))
	return { a, b }
end

handlers.houndDrive = function(payload)
	local r = newRun(payload)
	local center = payload.center
	local dx, dz = payload.dir.X, payload.dir.Z
	local runAt = r.t0 + payload.warn
	local travel = payload.length / payload.speed
	local endAt = runAt + travel + 0.6
	local offsets = BossGeo.laneOffsets(payload.lanes, payload.laneWidth)
	local safe = {}
	for _, lane in ipairs(payload.safe or {}) do
		safe[lane] = true
	end
	local function at(along: number, side: number, lift: number?): Vector3
		local x, z = BossGeo.fromLocal(along, side, center.X, center.Z, dx, dz)
		return V3(x, center.Y + (lift or 0), z)
	end
	local look = function(p: Vector3)
		return CFrame.lookAt(p, p + V3(dx, 0, dz))
	end
	local lanes = {}
	for index, offset in ipairs(offsets) do
		local lane = { index = index, offset = offset, safe = safe[index] == true }
		local mid = at(0, offset, 0.07)
		lane.strip = r.add(Kit.part({
			Name = "Lane", Size = V3(payload.laneWidth - 0.5, 0.05, payload.length), CFrame = look(mid),
			Color = lane.safe and C.safe or C.blood, Material = Enum.Material.Neon, Transparency = 1,
		}))
		if lane.safe then
			lane.edges = {}
			for _, sign in ipairs({ -1, 1 }) do
				local e = r.add(Kit.part({
					Name = "SafeEdge", Size = V3(0.18, 0.06, payload.length), CFrame = look(at(0, offset + sign * (payload.laneWidth / 2 - 0.35), 0.09)),
					Color = C.safe, Material = Enum.Material.Neon, Transparency = 1,
				}))
				table.insert(lane.edges, e)
			end
		else
			lane.chevrons = {}
			for _ = 1, 5 do
				table.insert(lane.chevrons, chevron(r, C.blood))
			end
			lane.hounds = {}
		end
		table.insert(lanes, lane)
	end
	tipOnce("hounds", "Королевская травля: беги в золотую полосу — гончие её не трогают.")
	local ran, nextYelp = false, 0
	r.update = function(t)
		local k = math.clamp((t - r.t0) / payload.warn, 0, 1)
		local parts, frames = {}, {}
		for _, lane in ipairs(lanes) do
			local fadeOut = t > runAt + travel and math.clamp((t - runAt - travel) / 0.5, 0, 1) or 0
			if lane.safe then
				lane.strip.Transparency = 1 - 0.18 * ease(k * 2) * (1 - fadeOut)
				for _, e in ipairs(lane.edges) do
					e.Transparency = 1 - 0.75 * ease(k * 2) * (1 - fadeOut)
				end
			else
				lane.strip.Transparency = 1 - (0.25 + 0.1 * math.sin(t * 10)) * ease(k * 2) * (1 - fadeOut)
				local scroll = ((t - r.t0) * 9) % (payload.length / 5)
				for index, pair in ipairs(lane.chevrons) do
					local along = -payload.length / 2 + (index - 1) * payload.length / 5 + scroll
					local tip = at(along, lane.offset, 0.1)
					local w = payload.laneWidth * 0.3
					for side, part in ipairs(pair) do
						local sign = side == 1 and -1 or 1
						local back = at(along - 1.2, lane.offset + sign * w, 0.1)
						table.insert(parts, part)
						table.insert(frames, CFrame.lookAt((tip + back) / 2, tip))
						part.Transparency = 1 - 0.65 * ease(k * 2) * (1 - fadeOut) * (t < runAt + travel * 0.6 and 1 or 0.4)
					end
				end
			end
		end
		if t >= runAt and not ran then
			ran = true
			for _, lane in ipairs(lanes) do
				if not lane.safe then
					for h = 1, payload.pack do
						table.insert(lane.hounds, { parts = buildHound(r), lag = (h - 1) * 2.4 + 0.5, side = random:NextNumber(-0.9, 0.9), phase = random:NextNumber(0, TAU) })
					end
					Kit.smoke(at(-payload.length / 2, lane.offset, 1), C.ghost, 6, 3)
				end
			end
		end
		if ran then
			local front = -payload.length / 2 + payload.speed * (t - runAt)
			local fade = t > runAt + travel and math.clamp((t - runAt - travel) / 0.5, 0, 1) or 0
			for _, lane in ipairs(lanes) do
				if lane.hounds then
					for _, hound in ipairs(lane.hounds) do
						local along = math.min(front - hound.lag, payload.length / 2)
						local base = look(at(along, lane.offset + hound.side, 0))
						poseHound(hound.parts, base, (t - runAt) * 14 + hound.phase, parts, frames)
						if fade > 0 then
							for _, item in ipairs(hound.parts) do
								item.part.Transparency = math.max(item.part.Transparency, item.spec.eye and fade or (0.45 + 0.55 * fade))
							end
						end
					end
				end
			end
			if t >= nextYelp and t < runAt + travel then
				nextYelp = t + 0.45
				local root = rootOf(player)
				local p = root and root.Position or center
				local along = BossGeo.toLocal(p.X, p.Z, center.X, center.Z, dx, dz)
				local _, side = BossGeo.toLocal(p.X, p.Z, center.X, center.Z, dx, dz)
				Kit.sfx("bmHoundRun", at(math.clamp(front, -payload.length / 2, payload.length / 2), side))
				Kit.shakeAt(at(front, side), 0.25, 0.15, 14)
				local _ = along
			end
		end
		if #parts > 0 then
			Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		return t < endAt
	end
end

-- Копьё: древко, наконечник, оперение (смещения вдоль −Z — вперёд).
local function buildSpear(r)
	local list = {}
	local function add(size: Vector3, offset: Vector3, color: Color3, material)
		local p = r.add(Kit.part({ Name = "Spear", Size = size, Color = color, Material = material or Enum.Material.Wood, CastShadow = true }))
		table.insert(list, { part = p, offset = CFrame.new(offset) })
	end
	add(V3(0.22, 0.22, 6.4), V3(0, 0, 0), C.wood)
	add(V3(0.42, 0.18, 1.2), V3(0, 0, -3.7), C.iron, Enum.Material.Metal)
	add(V3(0.2, 0.2, 0.5), V3(0, 0, -4.45), C.marble, Enum.Material.Metal)
	add(V3(0.05, 0.55, 0.9), V3(0, 0.2, 2.8), C.blood, Enum.Material.Fabric)
	add(V3(0.55, 0.05, 0.9), V3(0.2, 0, 2.8), C.blood, Enum.Material.Fabric)
	return list
end

local function reticle(r)
	local ring = r.add(Kit.part({ Name = "MarkRing", Shape = Enum.PartType.Cylinder, Size = V3(0.06, 1, 1), Color = C.blood, Material = Enum.Material.Neon, Transparency = 0.45 }))
	local inner = r.add(Kit.part({ Name = "MarkFill", Shape = Enum.PartType.Cylinder, Size = V3(0.05, 1, 1), Color = C.blood, Material = Enum.Material.Neon, Transparency = 0.8 }))
	local dot = r.add(Kit.part({ Name = "MarkDot", Shape = Enum.PartType.Cylinder, Size = V3(0.07, 0.6, 0.6), Color = C.blood, Material = Enum.Material.Neon }))
	local ticks = {}
	for _ = 1, 4 do
		table.insert(ticks, r.add(Kit.part({ Name = "MarkTick", Size = V3(0.3, 0.07, 1.4), Color = C.blood, Material = Enum.Material.Neon })))
	end
	local pip = r.add(Kit.part({ Name = "MarkPip", Size = V3(0.6, 0.6, 0.6), Color = C.blood, Material = Enum.Material.Neon }))
	return { ring = ring, inner = inner, dot = dot, ticks = ticks, pip = pip }
end

local function placeReticle(m, p: Vector3, radius: number, spin: number, head: Vector3?)
	local parts, frames = { m.ring, m.inner, m.dot }, { Kit.discCFrame(p, 0.1), Kit.discCFrame(p, 0.09), Kit.discCFrame(p, 0.11) }
	m.ring.Size = V3(0.06, radius * 2, radius * 2)
	m.inner.Size = V3(0.05, radius * 1.9, radius * 1.9)
	for index, tick in ipairs(m.ticks) do
		local a = spin + (index - 1) * math.pi / 2
		local dx, dz = BossGeo.dirOf(a)
		local q = p + V3(dx * (radius + 0.6), 0.12, dz * (radius + 0.6))
		table.insert(parts, tick)
		table.insert(frames, CFrame.lookAt(q, q + V3(dx, 0, dz)))
	end
	if head then
		table.insert(parts, m.pip)
		table.insert(frames, CFrame.new(head) * CFrame.Angles(0, spin * 2, math.pi / 4) * CFrame.Angles(math.pi / 4, 0, 0))
	end
	Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

handlers.huntMark = function(payload)
	local key = "mark:" .. tostring(payload.seq) .. ":" .. tostring(payload.mark)
	if payload.phase == "mark" then
		local r = newRun(payload)
		local m = reticle(r)
		local state = { run = r, m = m, locked = nil, lockAt = 0, flight = 0.5, spin = 0 }
		shared[key] = state
		local target = payload.player
		local current
		if target == player then
			tipOnce("huntMark", "Метка ловчего: прицел замрёт — сразу уходи с красного круга!")
		end
		r.update = function(t, dt)
			local root = rootOf(target)
			local radius
			if state.locked then
				current = state.locked
				local k = math.clamp((t - state.lockAt) / state.flight, 0, 1)
				radius = payload.radius
				m.inner.Transparency = 0.8 - 0.5 * k
				m.ring.Transparency = math.floor(t * 16) % 2 == 0 and 0.05 or 0.35
				placeReticle(m, current, radius, state.spin or 0, nil)
				m.pip.Transparency = 1
				return t < state.lockAt + state.flight + 0.1
			end
			if root then
				local feet = root.Position - V3(0, 2.9, 0)
				current = current and current:Lerp(feet, math.clamp(dt * 14, 0, 1)) or feet
			end
			if not current then
				return t < r.t0 + payload.follow + 1
			end
			local k = math.clamp((t - r.t0) / payload.follow, 0, 1)
			radius = payload.radius * (1.7 - 0.7 * ease(k))
			state.spin = (t - r.t0) * (3 + 6 * k)
			m.ring.Transparency = 0.5 - 0.3 * k
			m.inner.Transparency = 0.85
			placeReticle(m, current, radius, state.spin, root and (root.Position + V3(0, 4.2 + math.sin(t * 6) * 0.2, 0)))
			return t < r.t0 + payload.follow + 2
		end
		r.cleanup = function()
			if shared[key] == state then
				shared[key] = nil
			end
		end
		return
	end
	local state = shared[key]
	if payload.phase == "lock" then
		if state then
			state.locked = payload.position
			state.lockAt = payload.t0
			state.flight = payload.flight
		end
		Kit.sfx("enemyWindup", payload.position)
		beat(payload.model, "HuntMark_Throw", "HuntMark_Channel", payload.t0 - 0.12)
		local r = newRun(payload)
		local spear = buildSpear(r)
		local from, to = payload.from, payload.position + V3(0, 0.6, 0)
		local height = math.max((to - from).Magnitude * 0.12, 1.5)
		local function pos(k: number): Vector3
			return from:Lerp(to, k) + V3(0, math.sin(math.pi * k) * height, 0)
		end
		local stuck = false
		local stuckDir
		local endAt = payload.t0 + payload.flight + 2.8
		r.update = function(t)
			local k = (t - payload.t0) / payload.flight
			if k < 0 then
				for _, item in ipairs(spear) do
					item.part.Transparency = 1
				end
				return true
			end
			if k < 1 then
				for _, item in ipairs(spear) do
					item.part.Transparency = 0
				end
				local p = pos(k)
				local ahead = pos(math.min(k + 0.02, 1.02))
				placeGrate(spear, CFrame.lookAt(p, ahead + V3(0, 1e-4, 0)) * CFrame.new(0, 0, -1))
				if random:NextNumber() < 0.6 then
					Kit.bit(p, V3(0, 0, 0), C.blood, 0.2, 0.25, true, p.Y - 5, 0)
				end
			elseif not stuck then
				stuck = true
				stuckDir = (pos(1) - pos(0.97)).Unit
				placeGrate(spear, CFrame.lookAt(to, to + stuckDir) * CFrame.new(0, 0, 1.6))
			end
			return t < endAt
		end
		return
	end
	if payload.phase == "impact" then
		local p = payload.position
		Kit.sfx("bmSpearHit", p)
		Kit.shakeAt(p, 0.5, 0.2, 20)
		Kit.shockRing(p, payload.radius * 1.4, C.blood, 0.35)
		Kit.smoke(p + V3(0, 0.4, 0), C.dust, 7, 2.4)
		Kit.burst(p + V3(0, 0.3, 0), 9, { C.dust, C.wood, C.ironDark }, 0.4, 18, 0.9, p.Y + 0.1)
		local crack = Kit.part({ Name = "Crack", Size = V3(payload.radius * 1.4, 0.05, payload.radius * 1.4), CFrame = CFrame.new(p + V3(0, 0.07, 0)) * CFrame.Angles(0, random:NextNumber(0, TAU), 0), Transparency = 1 })
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Top
		decal.Texture = TEX.crack
		decal.Color3 = C.shadow
		decal.Transparency = 0.2
		decal.Parent = crack
		task.delay(2.2, function()
			Kit.fade(crack, 0.6)
		end)
		if state then
			endRun(state.run, false)
		end
	end
end

-- ======================================================================
-- Старший литейщик
-- ======================================================================

local function hopPos(a: Vector3, b: Vector3, k: number, height: number): Vector3
	return a:Lerp(b, k) + V3(0, math.sin(math.pi * k) * height, 0)
end

handlers.ingot = function(payload)
	local dists = payload.dists or {}
	if payload.phase == "mark" then
		local r = newRun(payload, { bound = { windup = true, strike = true, channel = true } })
		local lastHit = payload.throwAt
		for index, points in ipairs(payload.lines) do
			local d = dists[index] or {}
			for k, point in ipairs(points) do
				local last = k == #points
				local radius = last and payload.lastRadius or payload.radius
				local hitAt = payload.throwAt + (d[k] or (k * 6)) / payload.speed
				lastHit = math.max(lastHit, hitAt)
				local rim, fill = Kit.warnRing(point, radius, last and C.ember or C.flame, math.max(hitAt - now(), 0.1))
				if rim then
					r.add(rim)
					r.add(fill)
				end
				if k > 1 then
					local a = points[k - 1]
					local h = math.max((point - a).Magnitude * 0.16, 0.8)
					for dot = 1, 4 do
						local q = hopPos(a, point, dot / 5, h)
						r.add(Kit.part({ Name = "HopDot", Shape = Enum.PartType.Ball, Size = V3(0.35, 0.35, 0.35), CFrame = CFrame.new(q + V3(0, 0.3, 0)), Color = C.flame, Material = Enum.Material.Neon, Transparency = 0.45 }))
					end
				end
			end
		end
		r.update = function(t)
			return t < lastHit + 0.05
		end
		return
	end
	-- Бросок.
	local r = newRun(payload)
	local ingots = {}
	for index, points in ipairs(payload.lines) do
		local d = dists[index] or {}
		local bar = r.add(Kit.part({ Name = "Ingot", Size = V3(0.8, 0.5, 1.7), Color = C.white, Material = Enum.Material.Neon }))
		local light = Instance.new("PointLight")
		light.Color = C.ember
		light.Range = 12
		light.Brightness = 3
		light.Parent = bar
		Kit.emitter(Vector3.zero, {
			parent = bar, tex = TEX.spark, color = Kit.cseq(C.flame, C.ember), rate = 60, life = { 0.2, 0.45 }, speed = { 1, 4 }, spread = 180,
			size = Kit.nseq({ { 0, 0.3 }, { 1, 0 } }), transp = Kit.nseq({ { 0, 0 }, { 1, 0.7 } }), light = 1, accel = V3(0, -12, 0),
		})
		local times = {}
		for k = 1, #points do
			times[k] = payload.t0 + (d[k] or (k * 6)) / payload.speed
		end
		table.insert(ingots, { bar = bar, points = points, times = times, touched = 0, light = light })
	end
	local endAt = payload.t0
	for _, ingot in ipairs(ingots) do
		endAt = math.max(endAt, ingot.times[#ingot.times] + 2.2)
	end
	r.update = function(t)
		local parts, frames = {}, {}
		for _, ingot in ipairs(ingots) do
			local pts, times = ingot.points, ingot.times
			local p
			if t < times[1] then
				local k = math.clamp((t - payload.t0) / math.max(times[1] - payload.t0, 0.05), 0, 1)
				p = hopPos(payload.from, pts[1] + V3(0, 0.3, 0), k, 1.2)
			elseif t >= times[#times] then
				p = pts[#pts] + V3(0, 0.3, 0)
			else
				for k = 1, #times - 1 do
					if t >= times[k] and t < times[k + 1] then
						local a, b = pts[k], pts[k + 1]
						local h = math.max((b - a).Magnitude * 0.16, 0.8)
						p = hopPos(a + V3(0, 0.3, 0), b + V3(0, 0.3, 0), (t - times[k]) / (times[k + 1] - times[k]), h)
						break
					end
				end
			end
			p = p or pts[#pts]
			while ingot.touched < #times and t >= times[ingot.touched + 1] do
				ingot.touched += 1
				local q = pts[ingot.touched]
				local last = ingot.touched == #times
				Kit.sfx(last and "forgeBlast" or "bmIngotSkip", q)
				Kit.burst(q + V3(0, 0.3, 0), last and 16 or 8, { C.ember, C.flame, C.white }, 0.3, last and 22 or 15, 0.8, q.Y + 0.1, true)
				Kit.sparks(q + V3(0, 0.4, 0), C.flame, last and 24 or 12, 18)
				Kit.shockRing(q, (last and payload.lastRadius or payload.radius) * 1.2, C.ember, 0.3)
				Kit.smoke(q + V3(0, 0.5, 0), C.soot, last and 6 or 3, 2.2)
				Kit.shakeAt(q, last and 0.45 or 0.2, 0.15, 18)
			end
			local landed = t >= times[#times]
			local spin = landed and 0 or t * 16
			table.insert(parts, ingot.bar)
			table.insert(frames, CFrame.new(p) * CFrame.Angles(0, spin, 0))
			if landed then
				local k = math.clamp((t - times[#times]) / 1.8, 0, 1)
				ingot.bar.Color = C.white:Lerp(C.ember, math.min(k * 2, 1)):Lerp(C.crust, math.max(k * 2 - 1, 0))
				ingot.light.Brightness = 3 * (1 - k)
			end
		end
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		return t < endAt
	end
end

-- Тяга своего героя к горну (атрибуты BossPull*).
local function stepPull(dt: number)
	local untilT = player:GetAttribute("BossPullUntil") or 0
	if untilT <= now() then
		return
	end
	local at = player:GetAttribute("BossPullAt")
	local speed = player:GetAttribute("BossPullSpeed") or 0
	local radius = player:GetAttribute("BossPullRadius") or 0
	local root = rootOf(player)
	if typeof(at) ~= "Vector3" or not root then
		return
	end
	local offset = V3(at.X - root.Position.X, 0, at.Z - root.Position.Z)
	local d = offset.Magnitude
	if d < 3 or d > radius + 6 then
		return
	end
	local step = math.min(speed * dt, d - 3)
	root.CFrame += offset.Unit * step
end

handlers.bellows = function(payload)
	local center = payload.center
	if payload.phase == "inhale" then
		local r = newRun(payload)
		local heart = r.add(Kit.part({ Name = "ForgeHeart", Shape = Enum.PartType.Ball, Size = V3(0.6, 0.6, 0.6), Color = C.ember, Material = Enum.Material.Neon, Transparency = 0.1 }))
		local light = Instance.new("PointLight")
		light.Color = C.ember
		light.Range = 18
		light.Brightness = 0
		light.Parent = heart
		local rim, fill = Kit.warnRing(center, payload.novaRadius, C.ember, payload.inhale)
		if rim then
			r.add(rim)
			r.add(fill)
		end
		local dashes = {}
		for index = 1, 28 do
			table.insert(dashes, { part = r.add(Kit.part({ Name = "WindDash", Size = V3(0.18, 0.06, 1.6), Color = C.white, Material = Enum.Material.Neon, Transparency = 0.6 })), angle = index / 28 * TAU })
		end
		local streaks = {}
		local spawnAcc = 0
		local root = rootOf(player)
		if root and (root.Position - center).Magnitude <= payload.pullRadius then
			tipOnce("bellows", "Дыхание горна тянет к себе — беги прочь из кольца до выдоха!")
		end
		local endAt = r.t0 + payload.inhale + 0.1
		r.update = function(t, dt)
			local k = math.clamp((t - r.t0) / payload.inhale, 0, 1)
			local chest = bossPart(payload.model, "UpperTorso") or (center + V3(0, 4, 0))
			local s = 0.6 + 2.2 * ease(k)
			heart.Size = V3(s, s, s)
			heart.CFrame = CFrame.new(chest)
			heart.Color = C.ember:Lerp(C.white, k)
			light.Brightness = 6 * k
			local parts, frames = { heart }, { CFrame.new(chest) }
			for _, dash in ipairs(dashes) do
				local radius = payload.pullRadius * (1 - ((t - r.t0) * 0.35 + dash.angle / TAU) % 1 * 0.25)
				local a = dash.angle + (t - r.t0) * 0.6
				local dx, dz = BossGeo.dirOf(a)
				local p = center + V3(dx * radius, 0.12, dz * radius)
				table.insert(parts, dash.part)
				table.insert(frames, CFrame.lookAt(p, p + V3(dz, 0, -dx)))
			end
			spawnAcc += dt * (30 + 50 * k)
			while spawnAcc >= 1 do
				spawnAcc -= 1
				local a = random:NextNumber(0, TAU)
				local dx, dz = BossGeo.dirOf(a)
				local radius = payload.pullRadius * random:NextNumber(0.55, 1)
				local p = center + V3(dx * radius, random:NextNumber(0.4, 4.5), dz * radius)
				local streak = Kit.part({ Name = "Draft", Size = V3(0.1, 0.1, 1.8), Color = random:NextNumber() < 0.5 and C.white or C.flame, Material = Enum.Material.Neon, Transparency = 0.5 })
				table.insert(streaks, { part = streak, pos = p })
			end
			for index = #streaks, 1, -1 do
				local st = streaks[index]
				local to = chest - st.pos
				local d = to.Magnitude
				if d < 1.5 or k >= 1 then
					st.part:Destroy()
					table.remove(streaks, index)
				else
					st.pos += to.Unit * math.min(d, (16 + 18 * k) * dt)
					st.part.Transparency = 0.3 + 0.6 * math.clamp(1 - d / payload.pullRadius, 0, 1)
					table.insert(parts, st.part)
					table.insert(frames, CFrame.lookAt(st.pos, chest))
				end
			end
			Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
			return t < endAt
		end
		r.cleanup = function()
			for _, st in ipairs(streaks) do
				st.part:Destroy()
			end
		end
		return
	end
	-- Нова.
	local r = newRun(payload)
	Kit.sfx("forgeBlast", center)
	Kit.sfx("bmIntroBoom", center)
	Kit.shakeAt(center, 0.9, 0.35, 40)
	Kit.flash(center + V3(0, 3, 0), C.flame, payload.radius * 1.6, 0.4)
	Kit.shockRing(center, payload.radius * 1.15, C.ember, payload.time * 1.6)
	Kit.shockRing(center, payload.radius * 0.8, C.white, payload.time * 1.2, 0.2)
	local scorch = Kit.disc(center, payload.radius * 0.9, C.soot, 0.35, 0.06, false)
	task.delay(1.6, function()
		Kit.fade(scorch, 1.2)
	end)
	local root = rootOf(player)
	if root and (root.Position - center).Magnitude <= payload.radius + 1 then
		flashScreen(C.ember, 0.45, 0.45)
	end
	local tongues = {}
	for index = 1, 30 do
		table.insert(tongues, {
			part = r.add(Kit.part({ Name = "Flame", Size = V3(0.9, 1, 0.9), Color = index % 3 == 0 and C.white or (index % 2 == 0 and C.flame or C.ember), Material = Enum.Material.Neon, Transparency = 0.1 })),
			angle = index / 30 * TAU + random:NextNumber(-0.08, 0.08),
			h = random:NextNumber(2.2, 4.2),
		})
	end
	local endAt = payload.t0 + payload.time + 0.5
	r.update = function(t)
		local k = math.clamp((t - payload.t0) / (payload.time + 0.45), 0, 1)
		local radius = payload.radius * ease(k * 1.25)
		local parts, frames = {}, {}
		for _, tongue in ipairs(tongues) do
			local dx, dz = BossGeo.dirOf(tongue.angle)
			local h = tongue.h * (1 - k) + 0.3
			tongue.part.Size = V3(0.9, h, 0.9)
			tongue.part.Transparency = 0.1 + 0.9 * k
			table.insert(parts, tongue.part)
			table.insert(frames, CFrame.new(center + V3(dx * radius, h / 2, dz * radius)) * CFrame.Angles(0, tongue.angle, 0.2))
		end
		Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		return t < endAt
	end
end

-- ======================================================================
-- Главный летописец
-- ======================================================================

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI" }

-- Чернильный силуэт героя (стоит на месте следа).
local function inkGhost(r, position: Vector3, facing: Vector3, index: number, radius: number)
	local base = CFrame.lookAt(position, position + facing)
	local list = {}
	local function add(size: Vector3, offset: Vector3, shape)
		local p = r.add(Kit.part({ Name = "InkGhost", Shape = shape or Enum.PartType.Block, Size = size, Color = C.ink, Material = Enum.Material.Neon, Transparency = 1 }))
		table.insert(list, { part = p, offset = CFrame.new(offset) })
	end
	add(V3(0.7, 1.9, 0.7), V3(-0.35, 0.95, 0))
	add(V3(0.7, 1.9, 0.7), V3(0.35, 0.95, 0))
	add(V3(1.7, 1.9, 0.9), V3(0, 2.85, 0))
	add(V3(0.55, 1.8, 0.55), V3(-1.15, 2.75, 0))
	add(V3(0.55, 1.8, 0.55), V3(1.15, 2.75, 0))
	add(V3(1.1, 1.1, 1.1), V3(0, 4.35, 0), Enum.PartType.Ball)
	local pool = r.add(Kit.disc(position, radius, C.ink, 1, 0.08, false))
	local glow = r.add(Kit.disc(position, radius * 0.96, C.rune, 1, 0.09))
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.new(2.2, 0, 1.2, 0)
	label.StudsOffsetWorldSpace = V3(0, 5.6, 0)
	label.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.Antique
	text.TextScaled = true
	text.Text = ROMAN[index] or tostring(index)
	text.TextColor3 = C.frost
	text.TextTransparency = 1
	text.Parent = label
	label.Adornee = pool
	label.Parent = pool
	local ghost = { list = list, base = base, pool = pool, glow = glow, text = text, born = now(), position = position, popAt = nil }
	return ghost
end

handlers.rewind = function(payload)
	local key = "rewind:" .. tostring(payload.seq)
	local state = shared[key]
	if payload.phase == "record" then
		local r = newRun(payload, { keepOnCancel = true })
		state = { run = r, ghosts = {}, lines = {}, recordUntil = payload.t0 + payload.samples * payload.sampleGap, done = 0, count = nil }
		shared[key] = state
		local thread = {}
		for _ = 1, 10 do
			table.insert(thread, r.add(Kit.part({ Name = "InkThread", Shape = Enum.PartType.Ball, Size = V3(0.3, 0.3, 0.3), Color = C.rune, Material = Enum.Material.Neon, Transparency = 0.3 })))
		end
		local victim = payload.player
		if victim == player then
			tipOnce("rewind", "Летописец пишет твой путь — потом следы взорвутся по порядку. Не стой на старых следах!")
		end
		r.update = function(t)
			local parts, frames = {}, {}
			local recording = t < state.recordUntil
			local quill = bossPart(payload.model, "RightHand")
			local root = rootOf(victim)
			for index, dot in ipairs(thread) do
				if recording and quill and root then
					local k = index / (#thread + 1)
					local p = quill:Lerp(root.Position, k) + V3(0, -math.sin(math.pi * k) * 1.5 + math.sin(t * 8 + index) * 0.15, 0)
					dot.Transparency = 0.3
					table.insert(parts, dot)
					table.insert(frames, CFrame.new(p))
				else
					dot.Transparency = 1
				end
			end
			for _, ghost in pairs(state.ghosts) do
				local k = math.clamp((t - ghost.born) / 0.3, 0, 1)
				local tremble = ghost.popAt and math.clamp(1 - (ghost.popAt - t) / 1.2, 0, 1) or 0
				for _, item in ipairs(ghost.list) do
					item.part.Transparency = 1 - 0.55 * k - 0.25 * tremble
					local jitter = tremble > 0 and V3(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)) * 0.12 * tremble or Vector3.zero
					table.insert(parts, item.part)
					table.insert(frames, ghost.base * item.offset + jitter)
				end
				ghost.pool.Transparency = 1 - 0.65 * k
				ghost.glow.Transparency = 1 - (0.25 + 0.5 * tremble) * k
				ghost.text.TextTransparency = 1 - 0.9 * k
			end
			if #parts > 0 then
				Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
			end
			local timeout = state.recordUntil + 8
			return t < timeout and not (state.count and state.done >= state.count)
		end
		r.cleanup = function()
			if shared[key] == state then
				shared[key] = nil
			end
		end
		return
	end
	if not state then
		return
	end
	local r = state.run
	if payload.phase == "mark" then
		local index = payload.index
		local previous = state.ghosts[index - 1]
		local facing = previous and (payload.position - previous.position) or V3(0, 0, 1)
		facing = V3(facing.X, 0, facing.Z)
		if facing.Magnitude < 0.1 then
			facing = V3(0, 0, 1)
		end
		state.ghosts[index] = inkGhost(r, payload.position, facing.Unit, index, payload.radius)
		if previous then
			local line = r.add(Kit.beamPart(previous.position + V3(0, 0.1, 0), payload.position + V3(0, 0.1, 0), 0.35, 0.05, C.inkGloss, true, 0.35))
			state.lines[index] = line
		end
		Kit.sfx("pageShot", payload.position)
		Kit.burst(payload.position + V3(0, 0.3, 0), 4, { C.ink, C.inkGloss }, 0.3, 8, 0.6, payload.position.Y + 0.1, true)
	elseif payload.phase == "pops" then
		state.count = payload.count
		state.recordUntil = math.min(state.recordUntil, payload.t0)
		for index = 1, payload.count do
			local ghost = state.ghosts[index]
			if ghost then
				ghost.popAt = payload.t0 + payload.pause + (index - 1) * payload.popGap
				local rim, fill = Kit.warnRing(ghost.position, payload.radius, C.rune, math.max(ghost.popAt - now(), 0.1))
				if rim then
					r.add(rim)
					r.add(fill)
				end
			end
		end
		Kit.sfx("chronicleChant", bossPos(payload.model))
	elseif payload.phase == "pop" then
		state.done += 1
		local ghost = state.ghosts[payload.index]
		local p = payload.position
		Kit.sfx("bmInkPop", p)
		Kit.shockRing(p, payload.radius * 1.3, C.rune, 0.3)
		Kit.burst(p + V3(0, 1, 0), 12, { C.ink, C.inkGloss, C.rune }, 0.4, 20, 0.9, p.Y + 0.1, true)
		Kit.smoke(p + V3(0, 1, 0), C.ink, 6, 2.6, 2)
		Kit.shakeAt(p, 0.25, 0.12, 16)
		if ghost then
			for _, item in ipairs(ghost.list) do
				Kit.fade(item.part, 0.12)
			end
			Kit.fade(ghost.pool, 0.8)
			Kit.fade(ghost.glow, 0.2)
			state.ghosts[payload.index] = nil
		end
		local line = state.lines[payload.index]
		if line then
			Kit.fade(line, 0.3)
			state.lines[payload.index] = nil
		end
		local nextLine = state.lines[payload.index + 1]
		if nextLine then
			Kit.fade(nextLine, 0.3)
			state.lines[payload.index + 1] = nil
		end
	end
end

-- Книга под ареной: страницы, корешок, одна обложка ходит туда-обратно.
handlers.bookSlam = function(payload)
	local r = newRun(payload)
	local center = payload.center
	local s = V3(payload.spine.X, 0, payload.spine.Z).Unit
	local n = V3(s.Z, 0, -s.X) -- сторона +1 (BossGeo.spineSide > 0)
	local up = V3(0, 1, 0)
	local L = payload.halfLength * 2
	local W = payload.width
	local one = payload.lift + payload.hold + payload.slam
	local impacts = { r.t0 + one, r.t0 + 2 * one + payload.between }
	local starts = { r.t0, r.t0 + one + payload.between }
	local sides = { payload.side, -payload.side }
	local endAt = impacts[2] + 1.1

	local function slab(sideSign: number, color: Color3, lift: number, material, transparency)
		local mid = center + n * sideSign * (payload.spineWidth + W) / 2 + up * lift
		return r.add(Kit.part({
			Name = "Page", Size = V3(L, 0.25, W - payload.spineWidth), Color = color, Material = material or Enum.Material.SmoothPlastic,
			Transparency = transparency or 0, CFrame = CFrame.fromMatrix(mid, s, up),
		}))
	end
	local pages = { [1] = slab(1, C.paper, 0.12), [-1] = slab(-1, C.paper, 0.12) }
	-- Строчки текста на страницах.
	for _, sign in ipairs({ 1, -1 }) do
		for line = 1, 7 do
			local offset = payload.spineWidth / 2 + 1.2 + (line - 1) * (W - payload.spineWidth - 2.4) / 6
			local mid = center + n * sign * offset + up * 0.27
			r.add(Kit.part({ Name = "Line", Size = V3(L * random:NextNumber(0.6, 0.85), 0.03, 0.35), CFrame = CFrame.fromMatrix(mid, s, up), Color = C.ink, Transparency = 0.35 }))
		end
	end
	local danger = { [1] = slab(1, C.danger, 0.3, Enum.Material.Neon, 1), [-1] = slab(-1, C.danger, 0.3, Enum.Material.Neon, 1) }
	local spineStrip = r.add(Kit.part({
		Name = "Spine", Size = V3(L, 0.3, payload.spineWidth * 2), CFrame = CFrame.fromMatrix(center + up * 0.15, s, up),
		Color = C.goldLeaf, Material = Enum.Material.Neon, Transparency = 0.25,
	}))
	local cover = r.add(Kit.part({ Name = "Cover", Size = V3(L + 1, 0.9, W + 0.6), Color = C.leather, Material = Enum.Material.Leather, CastShadow = true }))
	local trim = r.add(Kit.part({ Name = "CoverTrim", Size = V3(L * 0.7, 0.2, W * 0.55), Color = C.goldLeaf, Material = Enum.Material.Neon, Transparency = 0.2 }))
	local rune = r.add(Kit.part({ Name = "CoverRune", Shape = Enum.PartType.Cylinder, Size = V3(0.22, W * 0.4, W * 0.4), Color = C.rune, Material = Enum.Material.Neon, Transparency = 0.2 }))
	tipOnce("bookSlam", "Глава закрыта: обложка падает на половину книги — стой на золотом корешке или на другой странице!")
	local slammed = { false, false }
	local rustled = { false, false }
	-- Угол обложки: 0 — лежит на стороне −toSide, π — на toSide.
	local function coverFrame(toSide: number, phi: number)
		local d0 = -n * toSide
		local dir = d0 * math.cos(phi) + up * math.sin(phi)
		local normal = -d0 * math.sin(phi) + up * math.cos(phi)
		local hinge = center + up * 0.45
		local mid = hinge + dir * (W + 0.6) / 2
		return CFrame.fromMatrix(mid, s, normal), normal
	end
	r.update = function(t)
		local k = t < starts[2] and 1 or 2
		local toSide = sides[k]
		local local_ = t - starts[k]
		local phi
		if local_ < payload.lift then
			phi = (math.pi / 2) * ease(local_ / payload.lift)
		elseif local_ < payload.lift + payload.hold then
			phi = math.pi / 2 + math.sin((local_ - payload.lift) * 30) * 0.03
		elseif local_ < one then
			phi = math.pi / 2 + (math.pi / 2) * easeIn((local_ - payload.lift - payload.hold) / payload.slam)
		else
			phi = math.pi
		end
		if k == 1 and t > impacts[1] then
			phi = math.pi
		end
		local frame, normal = coverFrame(toSide, phi)
		local outer = frame * CFrame.new(0, 0.5, 0)
		Workspace:BulkMoveTo({ cover, trim, rune }, { frame, outer, outer * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2) }, Enum.BulkMoveMode.FireCFrameChanged)
		local _ = normal
		-- Красная половина, на которую упадёт обложка.
		for _, sign in ipairs({ 1, -1 }) do
			local active = sign == toSide and t >= starts[k] and t < impacts[k]
			local pulse = active and (0.55 + 0.2 * math.sin(t * (local_ > payload.lift and 22 or 9))) or 1
			danger[sign].Transparency = pulse
		end
		spineStrip.Transparency = 0.25 + 0.15 * math.sin(t * 5)
		if not rustled[k] and t >= starts[k] then
			rustled[k] = true
			Kit.sfx("pageRustle", center)
		end
		if not slammed[k] and t >= impacts[k] then
			slammed[k] = true
			local half = center + n * toSide * (W / 2)
			Kit.sfx("bmBookSlam", half)
			Kit.shakeAt(half, 1.0, 0.4, 60)
			Kit.smoke(half + up * 0.5, C.paperDark, 10, 4)
			for _ = 1, 18 do
				local along = random:NextNumber(-payload.halfLength, payload.halfLength)
				local p = center + s * along + n * toSide * (W + random:NextNumber(-1, 1)) + up * 0.6
				Kit.bit(p, n * toSide * random:NextNumber(8, 18) + up * random:NextNumber(6, 14), C.paper, 0.6, 1.2, false, center.Y + 0.1, 18)
			end
			Kit.burst(half + up * 0.5, 10, { C.ink, C.inkGloss }, 0.45, 16, 0.6, center.Y + 0.1, true)
			local root = rootOf(player)
			if root then
				local along, sideD = BossGeo.toLocal(root.Position.X, root.Position.Z, center.X, center.Z, s.X, s.Z)
				local _ = along
				if sideD * toSide > payload.spineWidth and sideD * toSide <= W then
					flashScreen(C.ink, 0.2, 0.5)
				end
			end
		end
		return t < endAt
	end
	r.cleanup = function()
		for _ = 1, 24 do
			local p = center + s * random:NextNumber(-payload.halfLength, payload.halfLength) + n * random:NextNumber(-W, W) + up * 0.5
			Kit.bit(p, up * random:NextNumber(6, 14) + V3(random:NextNumber(-4, 4), 0, random:NextNumber(-4, 4)), C.paper, 0.5, 1.4, false, center.Y + 0.1, 8)
		end
		Kit.sfx("pageRustle", center)
	end
	local _ = pages
end

-- ======================================================================
-- Подключение
-- ======================================================================

local function onEnemyEvent(payload)
	if type(payload) ~= "table" or payload.kind ~= "bm" then
		return
	end
	if payload.move == "cancel" then
		cancelSeq(payload.seq)
		return
	end
	local handler = handlers[payload.move]
	if not handler then
		return
	end
	local origin = payload.center or payload.position or (payload.model and bossPos(payload.model))
	if origin and not Kit.near(origin, Kit.FAR + 40) then
		return
	end
	local ok, err = pcall(handler, payload)
	if not ok then
		warn("BossMovesFx." .. tostring(payload.move) .. ": " .. tostring(err))
	end
end

BossMovesFx.handlers = handlers

function BossMovesFx.start()
	Kit.start()
	Kit.folder()
	local remote = Net.get("EnemyEvent")
	if remote then
		remote.OnClientEvent:Connect(onEnemyEvent)
	end
	RunService.Heartbeat:Connect(function(dt)
		stepRuns(dt)
		stepShells()
		stepPull(dt)
	end)
end

return BossMovesFx
