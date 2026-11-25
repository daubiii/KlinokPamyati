-- Сценарии fxsim: все фазы способностей воина и заклинаний мага в виртуальном времени.
-- Проверки: нет ошибок/предупреждений от новых эффектов, всё удаляется (нет утечек),
-- хвост ≥ 2 с после последней фазы, бюджет деталей соблюдён и возвращён, все звуки есть в Sfx.

math.randomseed(7)

local Shared = folder(ReplicatedStorage, "Shared")
local Config = folder(Shared, "Config")
mount(Config, "Sfx", "Shared/Config/Sfx")
mount(Config, "SfxMage", "Shared/Config/SfxMage")
mount(Config, "SfxSkills", "Shared/Config/SfxSkills")
local PSF = folder(StarterPlayer, "StarterPlayerScripts")
local LibF = folder(PSF, "Lib")
local CtrlF = folder(PSF, "Controllers")
for _, name in ipairs({ "Bus", "FxTex", "MageFxKit", "FxAfter" }) do
	mount(LibF, name, "PS/Lib/" .. name)
end
for _, name in ipairs({ "MageSpellFx", "MageSpellFxPlus", "AbilityFxPlus", "PlayerAnimator" }) do
	mount(CtrlF, name, "PS/Controllers/" .. name)
end

local Bus = require(LibF.Bus)
local Sfx = require(Config.Sfx)
local SfxSkills = require(Config.SfxSkills)
local Kit = require(LibF.MageFxKit)
local Fx = require(LibF.FxAfter)
local MageSpellFx = require(CtrlF.MageSpellFx)
local Plus = require(CtrlF.MageSpellFxPlus)
local Warrior = require(CtrlF.AbilityFxPlus)

Bus.on("sfx", function(d) table.insert(SIM.sfx, d.name) end)
Bus.on("fov", function(d) table.insert(SIM.fov, d.amount) end)
Bus.on("shake", function(d) table.insert(SIM.shake, d.amount) end)

local fails = 0
local lines = {}
local function say(s) table.insert(lines, s) end
local function bad(s)
	fails += 1
	say("  ПРОВАЛ: " .. s)
end

-- Враг
local enemy = Instance.new("Model")
enemy.Name = "Enemy"
local eroot = Instance.new("Part")
eroot.Name = "HumanoidRootPart"
eroot.CFrame = CFrame.new(3, 3, -10)
eroot.Parent = enemy
rawget(enemy, "_p").PrimaryPart = eroot
enemy:SetAttribute("EnemyHeight", 5)
local hum = Instance.new("Humanoid")
hum.Parent = enemy
enemy.Parent = Workspace

-- Покрытие обработчиков
local covered = {}
local function wrapAll(tbl, prefix)
	for id, set in pairs(tbl) do
		for phase, fn in pairs(set) do
			local key = prefix .. id .. "." .. phase
			covered[key] = false
			set[phase] = function(...)
				covered[key] = true
				return fn(...)
			end
		end
	end
end
wrapAll(Plus.HANDLERS, "mage:")
wrapAll(Warrior.HANDLERS, "warrior:")

-- Фазы плюс-обработчиков совпадают с фазами сервера
for id, set in pairs(Plus.HANDLERS) do
	local phases = MageSpellFx.PHASES[id]
	if not phases then
		bad("MageSpellFxPlus: нет заклинания " .. id .. " в PHASES")
	else
		for phase in pairs(set) do
			if not table.find(phases, phase) then bad(("MageSpellFxPlus: %s.%s нет в PHASES"):format(id, phase)) end
		end
	end
	if Plus.UNCHANGED[id] then bad("MageSpellFxPlus трогает " .. id) end
end
local WARRIOR_PHASES = {
	vortex = { "start", "tick", "wave" }, rift = { "slam", "erupt" }, unlock = { "throw", "lock", "open" }, keyhole = { "mark", "burst" },
	garden = { "reapStart", "reapHit", "rot", "floodSlam", "floodPuddle", "floodEnd", "pruneCut", "thorn", "bloom" },
}
for kind, set in pairs(Warrior.HANDLERS) do
	for phase in pairs(set) do
		if not (WARRIOR_PHASES[kind] and table.find(WARRIOR_PHASES[kind], phase)) then bad(("AbilityFxPlus: %s/%s нет в AbilityFx"):format(kind, phase)) end
	end
end

local V = Vector3.new
local DIR = V(0, 0, -1)
local castId = 0

local function M(id, list)
	return { id = id, kind = "mage", phases = list }
end
local function W(name, list)
	return { id = name, kind = "warrior", phases = list }
end
local function ph(t, phase, payload)
	payload.phase = phase
	return { t = t, payload = payload }
end

local meteors = {}
for i = 1, 10 do
	local a = i * 2.4
	meteors[i] = ph(0.25 + i * 0.18, "meteor", { from = V(math.cos(a) * 6, 24, -12 + math.sin(a) * 6), position = V(math.cos(a) * 5, 0, -12 + math.sin(a) * 5), fall = 0.4, radius = 2 })
end

local SCEN = {
	M("ward_circle", {
		ph(0, "cast", { position = V(0, 0, -8), radius = 6, duration = 4, burstAt = 0.3 }),
		ph(0.3, "burst", { position = V(0, 0, -8), radius = 6, duration = 4 }),
		ph(4.3, "end", { position = V(0, 0, -8) }),
	}),
	M("signal_fire", {
		ph(0, "cast", { from = V(0, 4, 0), to = V(0, 0, -14), flight = 0.5, delay = 0.1 }),
		ph(0.6, "blast", { position = V(0, 0, -14), radius = 5, pillarRadius = 4, duration = 3 }),
		ph(3.6, "end", { position = V(0, 0, -14) }),
	}),
	M("light_gate", {
		ph(0, "cast", { position = V(0, 0, -6), dir = DIR, width = 6, surgeAt = 0.55, closeAt = 1.25 }),
		ph(0.55, "surge", { origin = V(0, 0, -6), dir = DIR, length = 18, halfWidth = 2 }),
		ph(1.25, "close", { position = V(0, 0, -6), radius = 6 }),
	}),
	M("lotus_bloom", {
		ph(0, "cast", { position = V(0, 0, -10), radius = 6, geyserAt = 0.3 }),
		ph(0.3, "geyser", { position = V(0, 0, -10), radius = 6 }),
	}),
	M("mycelium", {
		ph(0, "cast", { position = V(0, 0, -4), dir = DIR }),
		ph(0.2, "mushroom", { position = V(0, 0, -8), delay = 0.2, radius = 2.5 }),
		ph(0.35, "mushroom", { position = V(2, 0, -11), delay = 0.2, radius = 2.5 }),
		ph(1.5, "pop", { position = V(0, 0, -8), radius = 2.5 }),
		ph(1.7, "pop", { position = V(2, 0, -11), radius = 2.5 }),
	}),
	M("thorn_garden", {
		ph(0, "cast", { position = V(0, 0, -10), rings = 3, ringAt = 0.3, gardenAt = 1, gardenTime = 3 }),
		ph(0.3, "ring", { position = V(0, 0, -10), index = 1, radius = 3 }),
		ph(0.6, "ring", { position = V(0, 0, -10), index = 2, radius = 5 }),
		ph(0.9, "ring", { position = V(0, 0, -10), index = 3, radius = 7 }),
		ph(1.0, "garden", { position = V(0, 0, -10), radius = 7, duration = 3 }),
		ph(4.0, "end", {}),
	}),
	M("hunters_moon", {
		ph(0, "cast", { position = V(0, 0, -10), height = 14, radius = 8, crescentAt = 2.7 }),
		ph(0.8, "beam", { position = V(2, 0, -9), from = V(0, 14, -10) }),
		ph(1.4, "beam", { position = V(-2, 0, -11), from = V(0, 14, -10) }),
		ph(2.7, "crescent", { position = V(0, 0, -10), radius = 8, dir = DIR }),
	}),
	M("fire_rain", (function()
		local list = { ph(0, "cast", { position = V(0, 0, -12), radius = 8, duration = 2, startAt = 0.25 }) }
		for _, m in ipairs(meteors) do table.insert(list, m) end
		table.insert(list, ph(2.7, "end", {}))
		return list
	end)()),
	M("forged_lightning", {
		ph(0, "cast", { position = V(3, 0, -10), model = enemy, strikeAt = 0.25 }),
		ph(0.25, "strike", { position = V(3, 0, -10) }),
		ph(0.35, "chain", { points = { V(3, 1, -10), V(7, 1, -12), V(10, 1, -9) } }),
	}),
	M("forge_heart", {
		ph(0, "cast", { origin = V(0, 0, -3), dir = DIR, length = 16, crackTime = 0.5, wallAt = 1, wallTime = 3 }),
		ph(0.5, "pillar", { position = V(0, 0, -7), radius = 1.5, index = 1 }),
		ph(0.65, "pillar", { position = V(0, 0, -11), radius = 1.5, index = 2 }),
		ph(0.8, "pillar", { position = V(0, 0, -15), radius = 1.5, index = 3 }),
		ph(1.0, "wall", { origin = V(0, 0, -3), dir = DIR, length = 16, halfWidth = 1.5, duration = 3 }),
		ph(4.0, "end", { origin = V(0, 0, -3) }),
	}),
	M("meteor", {
		ph(0, "cast", { position = V(0, 0, -14), radius = 8, impactAt = 1, from = V(10, 40, -24) }),
		ph(1.0, "impact", { position = V(0, 0, -14), radius = 8, lavaRadius = 5, lavaTime = 3 }),
		ph(4.0, "end", {}),
	}),
	M("first_cast", {
		ph(0, "cast", { position = V(0, 0, 0), radius = 14, novaAt = 1.25 }),
		ph(0.4, "rift", { origin = V(0, 0, -2), dir = DIR, length = 12 }),
		ph(0.6, "rift", { origin = V(0, 0, -2), dir = V(0.7, 0, -0.7), length = 12 }),
		ph(1.25, "nova", { position = V(0, 0, 0), radius = 14 }),
	}),
	M("open_tome", {
		ph(0, "cast", { startAt = 0.3, stormAt = 1.3 }),
		ph(1.3, "storm", { position = V(0, 0, -8), radius = 6 }),
	}),
	M("time_stop", {
		ph(0, "cast", { position = V(0, 0, -10), radius = 10, freezeAt = 0.3, freeze = 2, dir = DIR }),
		ph(0.3, "freeze", { position = V(0, 0, -10), radius = 10, models = { enemy }, duration = 2 }),
		ph(2.3, "strike", { position = V(0, 0, -10), radius = 10 }),
	}),
	M("fate_line", {
		ph(0, "cast", { origin = V(0, 0, -2), dir = DIR, length = 20, igniteAt = 0.8 }),
		ph(0.8, "ignite", { origin = V(0, 0, -2), dir = DIR, length = 20, halfWidth = 1.8 }),
	}),
	M("ink_hole", {
		ph(0, "cast", { from = V(0, 4, 0), to = V(0, 0, -12), flight = 0.5, delay = 0.1 }),
		ph(0.6, "open", { position = V(0, 0, -12), radius = 6, pullTime = 1.5 }),
		ph(2.1, "blast", { position = V(0, 0, -12), radius = 6 }),
	}),
	M("total_recall", {
		ph(0, "cast", { position = V(0, 0, 0), echoes = { V(3, 0, 2), V(-3, 0, 2), V(0, 0, 4) }, beamAt = 0.6, stormAt = 1.6, dir = DIR }),
		ph(0.6, "beams", { beams = { { from = V(2, 3, 0), dir = DIR, length = 14 }, { from = V(-2, 3, 0), dir = DIR, length = 14 } }, salvo = 1 }),
		ph(1.0, "beams", { beams = { { from = V(0, 3, 1), dir = DIR, length = 14 } }, salvo = 2 }),
		ph(1.6, "storm", { position = V(0, 0, -10), radius = 8 }),
	}),
	-- Воин
	W("vortex", {
		ph(0, "start", { kind = "vortex", castTime = 1, radius = 5.5 }),
		ph(0.4, "tick", { kind = "vortex", position = V(0, 0, 0), radius = 5.5, hits = 1 }),
		ph(0.7, "tick", { kind = "vortex", position = V(0, 0, 0), radius = 5.5, hits = 0 }),
		ph(1.0, "wave", { kind = "vortex", position = V(0, 0, 0), radius = 7, hits = 2 }),
	}),
	W("rift", {
		ph(0, "slam", { kind = "rift", position = V(0, 0, -4), radius = 6, crackTime = 0.4, eruptDelay = 0.6,
			cracks = { { direction = V(1, 0, 0), length = 8 }, { direction = V(-0.5, 0, -0.8), length = 9 }, { direction = V(-0.6, 0, 0.8), length = 7 },
				{ direction = V(0.3, 0, -1), length = 10 }, { direction = V(0.8, 0, 0.6), length = 6 } } }),
		ph(1.0, "erupt", { kind = "rift", position = V(0, 0, -4), cracks = {} }),
	}),
	W("unlock", {
		ph(0, "throw", { kind = "unlock", from = V(0, 4, 0), target = V(0, 0, -10), flightTime = 0.5 }),
		ph(0.5, "lock", { kind = "unlock", position = V(0, 0, -10), radius = 10, bindTime = 1, targets = { enemy } }),
		ph(1.5, "open", { kind = "unlock", position = V(0, 0, -10), radius = 10 }),
	}),
	W("keyhole", {
		ph(0, "mark", { kind = "keyhole", model = enemy }),
		ph(0.5, "burst", { kind = "keyhole", model = enemy, position = V(3, 3, -10) }),
	}),
	W("garden_reap", {
		ph(0, "reapStart", { kind = "garden", position = V(0, 0, 0), direction = DIR, length = 14, waveTime = 0.5 }),
		ph(0.3, "reapHit", { kind = "garden", position = V(0, 0, -7) }),
		ph(0.3, "rot", { kind = "garden", model = enemy, duration = 3 }),
	}),
	W("garden_flood", {
		ph(0, "floodSlam", { kind = "garden", position = V(0, 0, 0), direction = DIR, radius = 9 }),
		ph(0.4, "floodPuddle", { kind = "garden", position = V(0, 0, -6), radius = 6, time = 3 }),
		ph(3.4, "floodEnd", { kind = "garden", position = V(0, 0, -6), radius = 6 }),
	}),
	W("garden_prune", {
		ph(0, "pruneCut", { kind = "garden", position = V(0, 0, 0), direction = DIR, radius = 5, index = 1, targets = { enemy } }),
		ph(0.25, "pruneCut", { kind = "garden", position = V(0, 0, 0), direction = DIR, radius = 5, index = 2, targets = { enemy } }),
		ph(0.3, "thorn", { kind = "garden", model = enemy, count = 3 }),
	}),
	W("garden_bloom", {
		ph(0, "bloom", { kind = "garden", position = V(0, 0, -8), radius = 4, model = enemy }),
	}),
}

local fxFolder = Kit.folder()
local KEEP = { [camera] = true, [character] = true, [enemy] = true, [fxFolder] = true }

local function countFx()
	local n = #fxFolder:GetDescendants()
	for _, d in ipairs(Lighting:GetChildren()) do
		if d.Name == "KlinokSkillTint" then n += 1 end
	end
	local gui = playerGui:FindFirstChild("KlinokFxFlash")
	if gui then n += #gui:GetChildren() end
	return n
end

local function leftovers()
	local names = {}
	for _, d in ipairs(fxFolder:GetChildren()) do table.insert(names, d.Name) end
	for _, d in ipairs(Workspace:GetChildren()) do
		if not KEEP[d] then table.insert(names, "Workspace." .. d.Name) end
	end
	for _, d in ipairs(Lighting:GetChildren()) do
		-- MageTimeStop — общий эффект остановки времени (MageSpellFx переиспользует его).
		if d.Name ~= "MageTimeStop" then table.insert(names, "Lighting." .. d.Name) end
	end
	local gui = playerGui:FindFirstChild("KlinokFxFlash")
	if gui then
		for _, d in ipairs(gui:GetChildren()) do table.insert(names, "Flash." .. d.Name) end
	end
	return names
end

local function fire(sc, payload)
	if sc.kind == "mage" then
		MageSpellFx.handle(payload)
	else
		Warrior.onEvent(payload)
	end
end

local function run(sc, withPlus)
	LOG.warns, LOG.errors = {}, {}
	SIM.sfx, SIM.hitStops, SIM.fov, SIM.shake = {}, {}, {}, {}
	local savedHandle = Plus.handle
	if not withPlus then
		Plus.handle = function() end
	end
	castId += 1
	local start = VT
	local last = 0
	for _, p in ipairs(sc.phases) do
		local payload = table.clone(p.payload)
		payload.id = sc.id
		payload.caster = localPlayer
		payload.cast = castId
		last = math.max(last, p.t)
		task.delay(p.t, fire, sc, payload)
	end
	local peak, lastAlive = 0, 0
	local livePeak = 0
	while VT - start < last + 14 do
		stepFrame()
		local n = countFx()
		if n > 0 then lastAlive = VT - start end
		peak = math.max(peak, n)
		livePeak = math.max(livePeak, Fx.live())
	end
	Plus.handle = savedHandle
	local left = leftovers()
	-- Убрать хвосты от прошлого прогона (если есть утечки) — чтобы не мешали следующему.
	for _, d in ipairs(fxFolder:GetChildren()) do d:Destroy() end
	return {
		tail = lastAlive - last,
		last = last,
		peak = peak,
		livePeak = livePeak,
		live = Fx.live(),
		left = left,
		warns = table.clone(LOG.warns),
		errors = table.clone(LOG.errors),
		sfx = table.clone(SIM.sfx),
		hitStops = #SIM.hitStops,
		fov = #SIM.fov,
	}
end

local usedSounds = {}
say("Способность        | хвост было → стало | пик экз. было → стало | звуки fx | hit-stop")
for _, sc in ipairs(SCEN) do
	local base = sc.kind == "mage" and run(sc, false) or nil
	local r = run(sc, true)
	local fxSounds = {}
	for _, name in ipairs(r.sfx) do
		usedSounds[name] = true
		if not Sfx.layers(name) then bad(sc.id .. ": звук «" .. name .. "» не найден в Sfx") end
		if string.sub(name, 1, 2) == "fx" then table.insert(fxSounds, name) end
	end
	say(("%-18s | %5.1f → %5.1f с   | %4d → %4d | %d: %s | %d"):format(sc.id, base and base.tail or 0, r.tail, base and base.peak or 0, r.peak, #fxSounds, table.concat(fxSounds, ","), r.hitStops))
	if r.tail > 12 then
		say("    живут до конца прогона: " .. table.concat(r.left, ", "))
	end
	local baseErr = base and (#base.errors + #base.warns) or 0
	if #r.errors + #r.warns > baseErr then
		bad(sc.id .. ": новые ошибки/предупреждения:")
		for _, e in ipairs(r.errors) do say("    E " .. e) end
		for _, w in ipairs(r.warns) do say("    W " .. w) end
	elseif baseErr > 0 then
		say(("    (основа MageSpellFx в заглушке движка: %d сообщений, без изменений)"):format(baseErr))
		say("    " .. tostring(base.errors[1] or base.warns[1]))
	end
	if #r.left > (base and #base.left or 0) then
		bad(sc.id .. ": остались экземпляры: " .. table.concat(r.left, ", "))
	end
	if r.live ~= 0 then bad(sc.id .. ": бюджет не возвращён: " .. r.live) end
	if r.tail < 2 then bad(("%s: хвост %.1f с < 2 с"):format(sc.id, r.tail)) end
	if #fxSounds == 0 then bad(sc.id .. ": нет новых звуков") end
	if r.livePeak > Fx.BUDGET then bad(sc.id .. ": бюджет превышен " .. r.livePeak) end
end

-- Все разом: бюджет держит.
do
	LOG.warns, LOG.errors = {}, {}
	local start = VT
	for _, sc in ipairs(SCEN) do
		castId += 1
		for _, p in ipairs(sc.phases) do
			local payload = table.clone(p.payload)
			payload.id = sc.id
			payload.caster = localPlayer
			payload.cast = castId
			task.delay(p.t, fire, sc, payload)
		end
	end
	local peakLive, peakAll = 0, 0
	while VT - start < 20 do
		stepFrame()
		peakLive = math.max(peakLive, Fx.live())
		peakAll = math.max(peakAll, countFx())
	end
	say(("Все %d способностей разом: деталей с физикой пик %d (бюджет %d), всего экземпляров пик %d"):format(#SCEN, peakLive, Fx.BUDGET, peakAll))
	if peakLive > Fx.BUDGET then bad("бюджет превышен при всех разом") end
	if Fx.live() ~= 0 then bad("бюджет не возвращён после всех разом: " .. Fx.live()) end
	for _, d in ipairs(fxFolder:GetChildren()) do d:Destroy() end
end

-- Покрытие обработчиков
local missed = {}
for key, hit in pairs(covered) do
	if not hit then table.insert(missed, key) end
end
table.sort(missed)
if #missed > 0 then bad("не вызваны обработчики: " .. table.concat(missed, ", ")) end

-- Звуки: все слои — корректные id, все новые звуки используются
local unused = {}
for name, layers in pairs(SfxSkills.sounds) do
	for _, layer in ipairs(layers) do
		if not string.match(layer.id, "^rbxassetid://%d+$") then bad("SfxSkills." .. name .. ": плохой id " .. tostring(layer.id)) end
	end
	if not usedSounds[name] then table.insert(unused, name) end
end
for name, options in pairs(SfxSkills.candidates) do
	for i, option in ipairs(options) do
		for _, layer in ipairs(option.layers) do
			if not string.match(layer.id, "^rbxassetid://%d+$") then bad(("SfxSkills.candidates.%s[%d]: плохой id"):format(name, i)) end
		end
	end
	if not usedSounds[name] then table.insert(unused, name) end
end
table.sort(unused)
if #unused > 0 then bad("звуки не используются: " .. table.concat(unused, ", ")) end

say(("ИТОГО: %d провалов"):format(fails))
OUT(table.concat(lines, "\n"))
