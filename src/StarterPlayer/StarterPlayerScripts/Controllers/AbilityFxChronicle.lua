--!nonstrict
-- AbilityFxChronicle (клиент)
-- Эффекты оружия этажа 5 «Архив Хроник» (kind = "chron"): Строка (перо пишет руны по земле), Опечатать (печать
-- и застывшие во времени враги), Безвременье (купол), Разлить чернила, Стереть, Вспомнить (эхо-двойники)
-- и пассивки «Песок времени» (эхо удара в куполе), «Пятна», «Забвение», «Послеобраз».
-- Сервер решает урон и цели; здесь только картинка. Шаблоны — FX.Chron/* (Shared/Fx/FxWeapons345).

local Debris = game:GetService("Debris")

local K = require(script.Parent.AbilityFx345Kit)
local FxKit = K.FxKit
local V3 = Vector3.new

local AbilityFxChronicle = {}

local VIOLET = K.color("#9B7BFF")
local LAVENDER = K.color("#B49CFF")
local ICE = K.color("#B8E3FF")
local INK = K.color("#1D1B3A")
local BRASS = K.color("#D6B467")
local MEMORY = K.color("#6FE3FF")
local WHITE = K.color("#F2F6FF")

-- ===== Строка =====

local lines = {} -- [caster] = { [index] = handle }

local function inscribeWrite(payload)
	local caster = payload.caster
	local origin = K.ground(payload.position, 0)
	local forward = K.flat(payload.direction)
	local length = payload.length or 12
	local writeTime = payload.writeTime or 0.45
	local detonate = payload.detonateDelay or 0.35
	local interval = payload.interval or 0.08
	local runes = payload.runes or {}
	K.sound("chronQuill", origin)

	-- Перо летит низко над землёй и оставляет чернильный след.
	local from = origin + V3(0, 0.9, 0)
	local quill = K.flyer("Chron/Quill", CFrame.lookAt(from, from + forward), { life = writeTime + 0.2 })
	K.loop(writeTime, function(t)
		local k = math.clamp(t / writeTime, 0, 1)
		local at = origin + forward * (length * k)
		at = V3(at.X, K.groundY(at) + 0.9 + math.sin(k * math.pi * 6) * 0.18, at.Z)
		quill.move(CFrame.lookAt(at, at + forward) * CFrame.Angles(math.rad(-35), 0, 0))
		return k < 1
	end)

	-- Руны проступают по мере прохода пера и живут до своей детонации.
	local set = {}
	lines[caster] = set
	local count = #runes
	for i, point in ipairs(runes) do
		local appear = writeTime * (i - 0.5) / math.max(1, count)
		local burstAt = writeTime + detonate + interval * (i - 1)
		task.delay(appear, function()
			if lines[caster] ~= set then
				return
			end
			local at = K.ground(point, 0.12)
			set[i] = FxKit.spawn("Chron/Rune", CFrame.new(at) * CFrame.Angles(0, math.random() * 6.28, 0), {
				life = math.max(0.1, burstAt - appear) + 0.1,
			})
		end)
	end
end

local function runeBurst(payload)
	local at = K.ground(payload.position, 0.12)
	local set = lines[payload.caster]
	local handle = set and set[payload.index or 0]
	if handle then
		handle.stop()
		set[payload.index] = nil
	end
	FxKit.spawn("Chron/RuneBurst", CFrame.new(at), { radius = payload.radius or 2.5 })
	if (payload.index or 1) % 2 == 1 then
		K.sound("chronRuneBurst", at)
	end
	K.shake(at, 0.12, 0.12)
end

-- ===== Опечатать =====

local function sealStamp(payload)
	local center = K.ground(payload.position, 0.1)
	local radius = payload.radius or 7
	K.sound("chronSealStamp", center)
	K.shake(center, 0.35, 0.3)
	FxKit.spawn("Chron/SealStamp", CFrame.new(center), { radius = radius })
	FxKit.shockwave(center + V3(0, 0.6, 0), radius)

	-- Печать-диск падает и вдавливается в пол.
	local disc = K.solid(V3(0.5, radius * 0.9, radius * 0.9), CFrame.new(center + V3(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(90)), BRASS, Enum.Material.Metal)
	disc.Shape = Enum.PartType.Cylinder
	local face = K.solid(V3(0.08, radius * 0.7, radius * 0.7), CFrame.new(), VIOLET, Enum.Material.Neon)
	face.Shape = Enum.PartType.Cylinder
	face.Transparency = 0.25
	K.loop(0.16, function(t)
		local k = math.clamp(t / 0.14, 0, 1)
		local cf = CFrame.new(center + V3(0, 6 * (1 - k * k) + 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
		disc.CFrame = cf
		face.CFrame = cf * CFrame.new(-0.3, 0, 0)
		return k < 1
	end)
	task.delay(0.6, function()
		K.dissolve(disc, 0.5)
		K.dissolve(face, 0.5)
	end)

	for _, model in ipairs(payload.targets or {}) do
		local state = K.onModel("frozen", model, "Chron/Frozen", payload.freeze or 2.5)
		K.highlight(state, model, ICE, WHITE, 0.6)
	end
	if #(payload.targets or {}) > 0 then
		K.sound("chronFreeze", center)
	end
end

local function sealBreak(payload)
	local part = K.modelPart(payload.model)
	local at = part and part.Position or payload.position
	K.offModel("frozen", payload.model)
	if at then
		FxKit.spawn("Chron/SealBreak", CFrame.new(at))
		K.sound("chronSealBreak", at)
	end
end

-- ===== Безвременье =====

local domes = {} -- [caster] = { ball, alive }

local function domeStart(payload)
	local caster = payload.caster
	local center = K.ground(payload.position, 0)
	local radius = payload.radius or 9
	local duration = payload.duration or 4
	K.sound("chronDomeStart", center)
	K.shake(center, 0.2, 0.25)
	FxKit.spawn("Chron/Dome", CFrame.new(center + V3(0, 0.12, 0)), { radius = radius, life = duration })

	local old = domes[caster]
	if old and old.ball.Parent then
		old.alive = false
		K.dissolve(old.ball, 0.2)
	end
	local ball = K.solid(V3(0.5, 0.5, 0.5), CFrame.new(center), ICE, Enum.Material.ForceField)
	ball.Shape = Enum.PartType.Ball
	ball.Transparency = 0.1
	K.tween(ball, 0.35, { Size = V3(radius * 2, radius * 2, radius * 2) }, Enum.EasingStyle.Back)
	local state = { ball = ball, alive = true, center = center, radius = radius }
	domes[caster] = state
	-- Тиканье раз в секунду, пока купол стоит.
	task.spawn(function()
		local ticks = math.floor(duration)
		for _ = 1, ticks do
			task.wait(1)
			if not state.alive then
				return
			end
			K.sound("chronTick", center)
		end
	end)
	Debris:AddItem(ball, duration + 3)
end

local function domeCollapse(payload)
	local center = K.ground(payload.position, 0.15)
	local radius = payload.radius or 9
	local state = domes[payload.caster]
	domes[payload.caster] = nil
	if state then
		state.alive = false
		if state.ball.Parent then
			K.tween(state.ball, 0.25, { Size = V3(1, 1, 1), Transparency = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(state.ball, 0.3)
		end
	end
	task.delay(0.22, function()
		K.sound("chronDomeCollapse", center)
		K.shake(center, 0.45, 0.35)
		FxKit.spawn("Chron/DomeCollapse", CFrame.new(center), { radius = radius })
		FxKit.shockwave(center + V3(0, 1, 0), radius)
	end)
end

local function timeEcho(payload)
	local part = K.modelPart(payload.model)
	local at = part and part.Position or payload.position
	if at then
		FxKit.spawn("Chron/TimeEcho", CFrame.new(at) * CFrame.Angles(0, math.random() * 6.28, 0))
		K.sound("chronTimeEcho", at)
	end
end

-- ===== Чернила =====

local function inkSplash(payload)
	local origin = K.ground(payload.position, 0)
	local forward = K.flat(payload.direction)
	local radius = payload.radius or 8.5
	K.sound("chronInkSplash", origin)
	FxKit.spawn("Chron/InkSplash", K.facing(origin + V3(0, 1.2, 0), forward), { radius = radius })
	K.arc(origin, forward, "Chron/Ribbon", INK, 0.24, 2 * (payload.halfAngle or 45), 1.5, radius * 0.8, 1.3, -0.4)
	local played = false
	for _, info in ipairs(payload.targets or {}) do
		local model = type(info) == "table" and info.model or info
		local stains = type(info) == "table" and info.stains or 0
		local part = K.modelPart(model)
		if part then
			K.offModel("ink", model)
			FxKit.spawn("Chron/InkHit", CFrame.new(part.Position), { scale = 1 + stains * 0.2 })
			FxKit.spawn("Chron/InkPuddle", CFrame.new(K.ground(part.Position, 0.08)), { radius = 1.6 + stains * 0.3, life = 2.5 })
			if not played and stains > 0 then
				played = true
				K.sound("chronInkHit", part.Position)
			end
		end
	end
end

local function inkStain(payload)
	local part = K.modelPart(payload.model)
	if not part then
		return
	end
	local count = payload.count or 1
	local state = K.onModel("ink", payload.model, "Chron/InkStain", 6)
	if count >= 3 then
		K.highlight(state, payload.model, INK, VIOLET, 0.8)
	end
	K.sound("chronInkStain", part.Position)
end

-- ===== Стереть и Забвение =====

local function erased(payload)
	local part = K.modelPart(payload.model)
	local at = part and part.Position or payload.position
	if at then
		FxKit.spawn("Chron/Erased", CFrame.new(at))
		K.sound("chronErased", at)
	end
end

local function eraseSwing(payload)
	local origin = K.ground(payload.position, 0)
	local forward = K.flat(payload.direction)
	local radius = payload.radius or 8.5
	K.sound("chronErase", origin)
	FxKit.spawn("Chron/EraseDust", K.facing(origin + V3(0, 1, 0), forward), { radius = radius })
	K.arc(origin, forward, "Chron/Ribbon", LAVENDER, 0.28, -2 * (payload.halfAngle or 110), radius * 0.3, radius * 0.95, 1.5, 0.5)
	K.arc(origin, forward, "Chron/Ribbon", ICE, 0.24, -2 * (payload.halfAngle or 110) * 0.9, radius * 0.5, radius * 0.8, 1.7, 0.3)
	if (payload.erased or 0) > 0 then
		K.shake(origin, 0.3, 0.25)
	end
end

local function oblivionMark(payload)
	local at = K.above(payload.model, 0.4) or payload.position
	if at then
		FxKit.spawn("Chron/OblivionMark", CFrame.new(at))
		K.sound("chronOblivion", at)
	end
end

-- ===== Вспомнить и Послеобраз =====

local recalls = {} -- [caster] = { ghosts = { { model, side } }, alive }

local function placeGhost(ghost, root, side: number, offset: number)
	local look = K.flat(root.CFrame.LookVector)
	local right = look:Cross(V3(0, 1, 0)).Unit
	local at = root.Position + right * (side * offset) - look * 0.8
	ghost:PivotTo(CFrame.lookAt(at, at + look))
end

local function recallSummon(payload)
	local caster = payload.caster
	local root = K.casterRoot(caster)
	if not root then
		return
	end
	local old = recalls[caster]
	if old then
		old.alive = false
		for _, g in ipairs(old.ghosts) do
			if g.model.Parent then
				K.dissolve(g.model, 0.2)
			end
		end
	end
	local echoes = payload.echoes or 2
	local offset = payload.offset or 2.2
	local life = (payload.start or 0.3) + (payload.gap or 0.3) * #(payload.combos or { 1 }) + 0.6
	K.sound("chronRecall", root.Position)
	FxKit.spawn("Chron/RecallSummon", CFrame.new(K.ground(root.Position - V3(0, K.FEET, 0), 0.12)))
	local state = { ghosts = {}, alive = true }
	recalls[caster] = state
	for e = 1, echoes do
		local side = (e % 2 == 1) and -1 or 1
		local ghost = K.ghost(caster, MEMORY)
		if ghost then
			placeGhost(ghost, root, side, offset)
			local core = ghost.PrimaryPart
			if core then
				local a = Instance.new("Attachment")
				a.Parent = core
				FxKit.attach("Chron/EchoGhost", a, { life = life })
			end
			table.insert(state.ghosts, { model = ghost, side = side })
		end
	end
	K.loop(life, function()
		if not state.alive or not root.Parent then
			return false
		end
		for _, g in ipairs(state.ghosts) do
			if g.model.Parent then
				placeGhost(g.model, root, g.side, offset)
			end
		end
		return true
	end)
	task.delay(life, function()
		state.alive = false
		for _, g in ipairs(state.ghosts) do
			if g.model.Parent then
				K.dissolve(g.model, 0.35)
			end
		end
		if recalls[caster] == state then
			recalls[caster] = nil
		end
	end)
end

local function recallSwing(payload)
	local state = recalls[payload.caster]
	if not state then
		return
	end
	local sign = ((payload.combo or 1) % 2 == 1) and 1 or -1
	for i, g in ipairs(state.ghosts) do
		local core = g.model.PrimaryPart
		if core then
			local feet = core.Position - V3(0, K.FEET, 0)
			K.arc(feet, core.CFrame.LookVector, "Chron/EchoRibbon", MEMORY, 0.18, 150 * sign, 1.2, 5.5, 1.5, 0.4)
			if i == 1 then
				K.sound("chronEchoSwing", core.Position)
			end
		end
	end
end

local function afterimage(payload)
	local feet = K.ground(payload.position, 0)
	local forward = K.flat(payload.direction)
	local delay = payload.delay or 0.25
	local ghost = K.ghost(payload.caster, MEMORY)
	if ghost then
		local at = feet + V3(0, K.FEET, 0) - forward * 0.5
		ghost:PivotTo(CFrame.lookAt(at, at + forward))
		Debris:AddItem(ghost, delay + 1)
	end
	task.delay(delay, function()
		local sign = ((payload.combo or 1) % 2 == 1) and 1 or -1
		K.arc(feet, forward, "Chron/EchoRibbon", MEMORY, 0.18, 130 * sign, 1.2, 5.5, 1.5, 0.4)
		FxKit.spawn("Chron/Afterimage", CFrame.new(feet + V3(0, 1.4, 0)))
		K.sound("chronAfterimage", feet)
		if ghost and ghost.Parent then
			K.dissolve(ghost, 0.35)
		end
	end)
end

AbilityFxChronicle.handlers = {
	chron = {
		inscribeWrite = inscribeWrite,
		runeBurst = runeBurst,
		sealStamp = sealStamp,
		sealBreak = sealBreak,
		domeStart = domeStart,
		domeCollapse = domeCollapse,
		timeEcho = timeEcho,
		inkSplash = inkSplash,
		inkStain = inkStain,
		erased = erased,
		eraseSwing = eraseSwing,
		oblivionMark = oblivionMark,
		recallSummon = recallSummon,
		recallSwing = recallSwing,
		afterimage = afterimage,
	},
}

return AbilityFxChronicle
