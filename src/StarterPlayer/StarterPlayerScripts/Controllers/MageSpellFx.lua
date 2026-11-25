--!nonstrict
-- MageSpellFx (клиент, модуль без start; вызывает MageFx)
-- Заклинания посохов мага по событию MageFx { kind = "spell", id, phase, cast, caster, t, … }.
-- Сервер шлёт фазы (WeaponAbilitiesMage.PHASES) — здесь только «где и как красиво»:
-- магические круги и циферблаты, метеоры (падение from → position за fall, удар рисует
-- клиент), соколы, столбы огня и света, разломы, врата, лотос, грибы, книга, эхо мага.
-- Всё кодом через Lib/MageFxKit; состояние каста (круг, луна, книга, эхо) живёт между
-- фазами в casts[caster:cast] и само чистится.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.Parent.Lib.MageFxKit)
-- Продлённые фазы (кадр удара, обломки, хвосты 2–4 с, звуки) — поверх основных эффектов.
local MageSpellFxPlus = require(script.Parent.MageSpellFxPlus)
local MageSpellFxV2 = require(script.Parent.MageSpellFxV2)

local MageSpellFx = {}

local player = Players.LocalPlayer
local V3 = Vector3.new
local TAU = math.pi * 2
local WHITE = Color3.new(1, 1, 1)

local function C(hex: string): Color3
	return Kit.color(hex, WHITE)
end

-- Фазы — как на сервере (WeaponAbilitiesMage.PHASES); сверяет tools/lua/test_mage_weapons.lua.
MageSpellFx.PHASES = {
	ward_circle = { "cast", "burst", "end" },
	signal_fire = { "cast", "blast", "end" },
	light_gate = { "cast", "surge", "close" },
	lotus_bloom = { "cast", "geyser" },
	mycelium = { "cast", "seed", "glade", "exhale", "burst" },
	thorn_garden = { "cast", "ring", "garden", "end" },
	spirit_pack = { "cast", "surround", "howl", "bite", "pounce" },
	hunters_moon = { "cast", "beam", "crescent" },
	royal_hunt = { "cast", "net", "spear", "tear" },
	fire_rain = { "cast", "meteor", "end" },
	forged_lightning = { "cast", "strike", "chain" },
	forge_heart = { "cast", "pillar", "wall", "end" },
	meteor = { "cast", "impact", "end" },
	first_cast = { "cast", "rift", "nova" },
	open_tome = { "cast", "storm" },
	time_stop = { "cast", "freeze", "sweep", "strike", "rewind" },
	fate_line = { "cast", "ignite" },
	ink_hole = { "cast", "open", "blast" },
	total_recall = { "cast", "beams", "storm" },
}

-- Цвета заклинаний.
local P = {
	ward = C("#8C6CFF"), wardCore = C("#FFE7A0"),
	fire = C("#FF5A1F"), fireCore = C("#FFF4C0"), fireDark = C("#B8200F"),
	light = C("#FFD45A"), lightCore = C("#FFFDEE"),
	lotus = C("#FF8FD0"), lotusCore = C("#FFF2FB"), water = C("#4FD6FF"), waterCore = C("#EFFFFF"),
	spore = C("#C8E04A"), sporeCore = C("#FFFBD6"), poison = C("#8EE04A"),
	thorn = C("#6FCF5A"), thornDark = C("#2F6B2A"), thornCore = C("#EAFFD6"),
	spirit = C("#6FFFD0"), spiritCore = C("#EAFFF8"),
	moon = C("#A8C8FF"), moonCore = C("#F6F9FF"),
	hunt = C("#FFC46A"), huntCore = C("#FFF6E0"),
	bolt = C("#7FD8FF"), boltCore = WHITE, boltDeep = C("#3F7FFF"),
	magma = C("#FF3A10"), magmaCore = C("#FFE6A0"),
	forge = C("#FFE39A"), forgeHot = C("#FF8A2A"),
	page = C("#EFE6CC"), pageCore = C("#FFFFF4"), gold = C("#FFD98A"),
	time = C("#6FE3FF"), timeCore = C("#F2FFFF"),
	ink = C("#6A58D8"), inkDark = C("#14122A"), inkCore = C("#D2C4FF"),
	memory = C("#6FE3FF"), memoryAlt = C("#B49CFF"),
}
MageSpellFx.PALETTE = P
MageSpellFxPlus.setPalette(P)

-- Враги, которых видит MageFx (модель → true): для будущих эффектов по всем врагам.
MageSpellFx.enemies = {}
function MageSpellFx.setEnemies(list)
	MageSpellFx.enemies = list or {}
end

-- ===== Помощники =====

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function G(position: Vector3, lift: number?): Vector3
	return Kit.ground(position, lift or 0.08)
end

local function vec(value, fallback: Vector3?): Vector3?
	if typeof(value) == "Vector3" then
		return value
	end
	return fallback
end

local function rootOf(caster)
	local _, root = Kit.characterOf(caster)
	return root
end

local function feetOf(caster, fallback: Vector3?): Vector3?
	local root = rootOf(caster)
	if root then
		return root.Position - V3(0, 3, 0)
	end
	return fallback
end

local function sfx(name: string, position: Vector3?, volume: number?)
	Kit.sfx(name, position, volume)
end

local function shake(position: Vector3?, amount: number, time: number?)
	Kit.shake(position, amount, time or 0.25)
end

-- Состояние каста между фазами.
local casts = {}
local function ctxOf(payload)
	local caster = payload.caster
	local key = (caster and tostring(caster.UserId) or "?") .. ":" .. tostring(payload.cast or 0) .. ":" .. tostring(payload.id)
	local ctx = casts[key]
	if not ctx then
		ctx = { key = key, born = os.clock(), cleanup = {} }
		casts[key] = ctx
	end
	return ctx
end

local function dropCtx(ctx)
	if casts[ctx.key] ~= ctx then
		return
	end
	casts[ctx.key] = nil
	for _, fn in ipairs(ctx.cleanup) do
		pcall(fn)
	end
	ctx.cleanup = {}
end

task.spawn(function()
	while true do
		task.wait(5)
		local t = os.clock()
		for _, ctx in pairs(casts) do
			if t - ctx.born > 25 then
				dropCtx(ctx)
			end
		end
	end
end)

-- Заряд на навершии: свет стягивается к посоху.
local function charge(caster, color: Color3, core: Color3?, time: number?)
	local tip = Kit.tipOf(caster)
	if not tip then
		return
	end
	local life = time or 0.35
	local holder = Kit.holder(tip)
	local e = Kit.emitter(holder, { texture = "glow", color = { core or WHITE, color }, size = { 0.2, 0.9 }, rate = 60,
		life = { 0.2, 0.3 }, speed = { -9, -6 }, spread = 180, shape = Enum.ParticleEmitterShape.Sphere })
	holder.Size = V3(4, 4, 4)
	local light = Kit.light(holder, color, 0, 10)
	Kit.every(life, function(k)
		local p = Kit.tipOf(caster)
		if p then
			holder.CFrame = CFrame.new(p)
		end
		light.Brightness = 1 + k * 4
		return true
	end, function()
		e.Enabled = false
		Kit.flash(holder.Position, color, 2.4, 0.18)
		game:GetService("Debris"):AddItem(holder, 0.5)
	end)
end

-- Часть из меша-эллипсоида (лепестки, шляпки, тела соколов).
local function ellipsoid(size: Vector3, color: Color3, props)
	local p = Kit.part({ Size = size, Color = color, Name = "MageShape" })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	for key, value in pairs(props or {}) do
		p[key] = value
	end
	return p
end

local function cylinderUp(position: Vector3, height: number, diameter: number, color: Color3, props)
	local p = Kit.part({ Shape = Enum.PartType.Cylinder, Size = V3(height, diameter, diameter), Color = color, Name = "MageCylinder" })
	p.CFrame = CFrame.new(position + V3(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	for key, value in pairs(props or {}) do
		p[key] = value
	end
	return p
end

-- Плоская надпись на земле (SurfaceGui сверху детали).
local function letterPlane(position: Vector3, dir: Vector3, text: string, size: number, color: Color3, stroke: Color3?)
	local part = Kit.part({ Size = V3(size, 0.05, size), Transparency = 1, Name = "MageLetter" })
	part.CFrame = CFrame.lookAt(position, position + Kit.flatUnit(dir)) * CFrame.Angles(0, math.pi, 0)
	local gui = Kit.surface(part, 3)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.Garamond
	label.TextColor3 = color
	label.TextStrokeColor3 = stroke or Color3.new(0, 0, 0)
	label.TextStrokeTransparency = stroke and 0.2 or 1
	label.TextTransparency = 1
	label.Parent = gui
	return part, label
end

-- Шип из земли: тёмный клин с неоновым кончиком, выстреливает и уходит обратно.
local function spike(position: Vector3, height: number, color: Color3, tipColor: Color3, hold: number, tilt: Vector3?)
	local base = G(position, 0)
	local away = tilt or V3(0, 0, 0)
	local spin = math.random() * TAU
	local body = Kit.part({ Size = V3(0.42, height, 0.42), Color = color, Material = Enum.Material.SmoothPlastic, Name = "MageSpike" })
	local tip = Kit.part({ Size = V3(0.22, height * 0.32, 0.22), Color = tipColor, Name = "MageSpikeTip" })
	local lean = CFrame.Angles(away.Z * 0.35, spin, -away.X * 0.35)
	local up = 0.12
	local total = up + hold + 0.25
	Kit.every(total, function(_, t)
		local h
		if t < up then
			h = Kit.ease(t / up, "back")
		elseif t < up + hold then
			h = 1
		else
			h = 1 - Kit.ease((t - up - hold) / 0.25, "in")
		end
		local cf = CFrame.new(base) * lean * CFrame.new(0, height * (h - 0.5), 0)
		body.CFrame = cf
		tip.CFrame = cf * CFrame.new(0, height * 0.5, 0)
		return true
	end, function()
		body:Destroy()
		tip:Destroy()
	end)
	Kit.burst(base + V3(0, 0.3, 0), { texture = "rock", color = { "#6B5A48", "#3A3028" }, size = { 0.3, 0.1 }, count = 3,
		life = { 0.3, 0.5 }, speed = { 3, 6 }, spread = 50, direction = Enum.NormalId.Top, accel = V3(0, -30, 0),
		lightEmission = 0, lightInfluence = 1 })
end

-- Сокол: тело-эллипсоид, машущие крылья, след; пике по кривой Безье за dive.
function MageSpellFx.falcon(from: Vector3, to: Vector3, dive: number, color: Color3, small: boolean?)
	local s = small and 0.7 or 1
	local core = color:Lerp(WHITE, 0.55)
	local body = ellipsoid(V3(0.5, 0.42, 1.5) * s, core, { Transparency = 0.1 })
	local head = Kit.ball(from, 0.42 * s, WHITE)
	local wingL = ellipsoid(V3(1.9, 0.08, 0.7) * s, color, { Transparency = 0.15 })
	local wingR = ellipsoid(V3(1.9, 0.08, 0.7) * s, color, { Transparency = 0.15 })
	local tail = ellipsoid(V3(0.5, 0.06, 0.8) * s, color, { Transparency = 0.2 })
	Kit.trail(body, color, { width = 0.9 * s, life = 0.3, colors = { core, color } })
	local e = Kit.emitter(body, { texture = "star", color = { core, color }, size = { 0.35 * s, 0 }, rate = 30, life = { 0.2, 0.4 },
		speed = { 0.5, 2 } })
	local ctrl = from:Lerp(to, 0.35) + V3(0, 4, 0)
	local function at(k: number): Vector3
		return (1 - k) ^ 2 * from + 2 * (1 - k) * k * ctrl + k ^ 2 * to
	end
	Kit.every(math.max(dive, 0.1), function(k, t)
		local e2 = Kit.ease(k, "in")
		local pos = at(e2) + V3(0, 1.2, 0)
		local ahead = at(math.min(e2 + 0.03, 1)) + V3(0, 1.2, 0)
		local look = (ahead - pos).Magnitude > 1e-3 and (ahead - pos).Unit or V3(0, -1, 0)
		local cf = CFrame.lookAt(pos, pos + look)
		local flap = math.sin(t * 38) * 0.7 * (1 - k * 0.8)
		body.CFrame = cf
		head.CFrame = cf * CFrame.new(0, 0.1 * s, -0.8 * s)
		wingL.CFrame = cf * CFrame.new(-0.2 * s, 0.05, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.9 * s, 0, 0.1)
		wingR.CFrame = cf * CFrame.new(0.2 * s, 0.05, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.9 * s, 0, 0.1)
		tail.CFrame = cf * CFrame.new(0, 0, 0.9 * s)
		return true
	end, function()
		e.Enabled = false
		for _, part in ipairs({ body, head, wingL, wingR, tail }) do
			Kit.fade(part, 0.12)
		end
		local hitAt = to + V3(0, 1.2, 0)
		Kit.flash(hitAt, color, 3 * s, 0.2)
		Kit.burst(hitAt, { texture = "slash", color = { core, color }, size = { 1.8 * s, 0 }, count = 4, life = { 0.15, 0.25 },
			speed = { 2, 5 }, rotSpeed = { -400, 400 } })
		Kit.burst(hitAt, { texture = "star", color = { core, color }, size = { 0.5 * s, 0 }, count = 12, life = { 0.3, 0.6 },
			speed = { 6, 12 }, drag = 4 })
		Kit.ringWave(G(to, 0.1), 2.2 * s, color, { time = 0.3 })
		sfx("spellDive", to, small and 0.6 or 0.9)
	end)
	sfx("spellFalcon", from, small and 0.4 or 0.6)
end

-- Метеор: огненный шар from → to за fall, на земле — взрыв (рисует клиент сам).
local function meteorFall(from: Vector3, to: Vector3, fall: number, radius: number, big: boolean, onLand)
	local d = big and 4.6 or 1.5
	local core = Kit.ball(from, d * 0.7, P.magmaCore)
	local shell = Kit.ball(from, d, P.fire, { Transparency = 0.35 })
	local holder = Kit.holder(from)
	Kit.trail(core, P.fire, { width = d * 1.1, life = big and 0.6 or 0.35, colors = { P.fireCore, P.fireDark } })
	local fire = Kit.emitter(holder, { texture = "glow", color = { P.fireCore, P.fire, P.fireDark }, size = { d * 1.3, d * 0.3 },
		rate = big and 160 or 70, life = { 0.25, 0.5 }, speed = { 1, 4 }, spread = 180, transparency = { 0.1, 1 } })
	local smoke = Kit.emitter(holder, { texture = "smoke", color = { "#5A3A2A", "#1E1612" }, size = { d * 0.8, d * 2.2 },
		rate = big and 40 or 14, life = { 0.6, 1.1 }, speed = { 0.5, 2 }, spread = 180, transparency = { 0.4, 1 },
		lightEmission = 0, lightInfluence = 1 })
	local light = Kit.light(core, P.fire, big and 6 or 3, big and 40 or 16)
	local spin = CFrame.Angles(math.random(), math.random(), math.random())
	Kit.every(math.max(fall, 0.1), function(k, t)
		local pos = from:Lerp(to, k)
		core.CFrame = CFrame.new(pos) * spin * CFrame.Angles(t * 6, t * 4, 0)
		shell.CFrame = CFrame.new(pos)
		local w = 1 + math.sin(t * 30) * 0.08
		shell.Size = V3(d, d, d) * w
		holder.CFrame = CFrame.new(pos)
		light.Brightness = (big and 6 or 3) * (0.6 + k * 0.6)
		return true
	end, function()
		fire.Enabled = false
		smoke.Enabled = false
		core:Destroy()
		shell:Destroy()
		game:GetService("Debris"):AddItem(holder, 1.2)
		if onLand then
			onLand()
		end
	end)
end

-- Удар метеора о землю.
local function meteorImpact(position: Vector3, radius: number, big: boolean)
	local ground = G(position, 0.1)
	Kit.explosion(ground + V3(0, big and 2 or 0.8, 0), radius, P.fire, {
		core = P.fireCore, embers = big and 40 or 12, rocks = big and 16 or 5, ground = ground,
		shakeAmount = big and 0.8 or 0.14, shakeTime = big and 0.5 or 0.2,
	})
	Kit.glowSpot(ground, radius * 0.8, P.fireDark, big and 2.5 or 1.2, { transparency = 0.15 })
	Kit.burst(ground + V3(0, 0.5, 0), { texture = "smoke", color = { "#6B4A36", "#20160F" }, size = { radius * 0.6, radius * 1.4 },
		count = big and 14 or 5, life = { 0.8, 1.4 }, speed = { radius * 0.8, radius * 1.6 }, spread = 70,
		direction = Enum.NormalId.Top, transparency = { 0.35, 1 }, lightEmission = 0, lightInfluence = 1 })
	if big then
		for i = 1, 7 do
			local dir = Kit.rotate(V3(0, 0, -1), i * 360 / 7 + math.random() * 20)
			Kit.crack(ground, dir, radius * (0.9 + math.random() * 0.5), P.magma, { width = 0.5, reveal = 0.2, time = 3.2 })
		end
	end
	sfx("spellMeteorImpact", ground, big and 1.2 or 0.7)
end

-- Эхо мага: призрачная копия персонажа (клоны деталей, ForceField), стоит на месте.
local function ghostOf(caster, at: CFrame, color: Color3)
	local character, root = Kit.characterOf(caster)
	local parts = {}
	if not character or not root then
		return parts
	end
	local base = root.CFrame
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 0.95 then
			local ok, copy = pcall(function()
				return d:Clone()
			end)
			if ok and copy then
				for _, child in ipairs(copy:GetChildren()) do
					if not (child:IsA("DataModelMesh") or child:IsA("SurfaceAppearance")) then
						child:Destroy()
					end
				end
				copy.Anchored = true
				copy.CanCollide = false
				copy.CanQuery = false
				copy.CanTouch = false
				copy.CastShadow = false
				copy.Massless = true
				copy.Material = Enum.Material.ForceField
				copy.Color = color
				copy.Transparency = 0
				copy.LocalTransparencyModifier = 0
				pcall(function()
					(copy :: any).TextureID = ""
				end)
				copy.CFrame = at * base:ToObjectSpace(d.CFrame)
				copy.Parent = Kit.folder()
				table.insert(parts, { part = copy, rel = base:ToObjectSpace(d.CFrame) })
			end
		end
		if #parts >= 60 then
			break
		end
	end
	return parts
end

-- ===== Обработчики фаз =====
-- H[id][phase](payload, ctx)

local H = {}

-- ---------- Этаж 1 ----------

H.ward_circle = {
	cast = function(p, ctx)
		local center = G(vec(p.position, feetOf(p.caster, V3())))
		local radius = p.radius or 7
		local life = (p.duration or 4) + (p.burstAt or 0.3)
		ctx.center = center
		ctx.circle = Kit.circle(center, radius, P.ward, { duration = life, spin = 30, count = 12, ticks = 24, star = 6,
			inner = P.wardCore, fill = 0.62, appear = 0.25 })
		-- Руны поднимаются по кругу всё время действия.
		Kit.stream(CFrame.new(center + V3(0, 0.2, 0)), { texture = "star", color = { P.wardCore, P.ward }, size = { 0.45, 0 },
			rate = 34, life = { 0.6, 1.1 }, speed = { 2, 4 }, spread = 8, direction = Enum.NormalId.Top,
			shape = Enum.ParticleEmitterShape.Cylinder, shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			size3 = V3(radius * 2, 0.2, radius * 2), rotSpeed = { -120, 120 } }, life)
		charge(p.caster, P.ward, P.wardCore, p.burstAt or 0.3)
		sfx("spellRunes", center)
	end,
	burst = function(p, ctx)
		local center = G(vec(p.position, ctx.center or V3()))
		local radius = p.radius or 7
		if ctx.circle then
			ctx.circle.pulse(0.22)
			ctx.circle.setSpin(120, -200)
			Kit.after(0.4, function()
				if ctx.circle and ctx.circle.alive then
					ctx.circle.setSpin(30, -48)
				end
			end)
		end
		Kit.pillar(center, 14, 1.6, P.ward, { time = 0.55, core = P.wardCore })
		Kit.shockwave(center + V3(0, 1, 0), radius, P.ward, { time = 0.4, flat = true, ground = center })
		Kit.ringWave(center, radius, P.wardCore, { time = 0.5, brightness = 4 })
		Kit.burst(center + V3(0, 1, 0), { texture = "spark", color = { P.wardCore, P.ward }, size = { 0.5, 0 }, count = 40,
			life = { 0.3, 0.6 }, speed = { 14, 26 }, spread = 70, direction = Enum.NormalId.Top, drag = 3 })
		Kit.flash(center + V3(0, 1.5, 0), P.ward, 6, 0.25)
		sfx("spellBurst", center)
		shake(center, 0.3, 0.25)
	end,
	["end"] = function(p, ctx)
		if ctx.circle then
			ctx.circle.fade(0.5)
		end
		local center = G(vec(p.position, ctx.center or V3()))
		Kit.burst(center + V3(0, 0.5, 0), { texture = "star", color = { P.wardCore, P.ward }, size = { 0.4, 0 }, count = 16,
			life = { 0.4, 0.8 }, speed = { 2, 5 }, direction = Enum.NormalId.Top, spread = 60 })
		dropCtx(ctx)
	end,
}

H.signal_fire = {
	cast = function(p, ctx)
		local to = vec(p.to)
		charge(p.caster, P.fire, P.fireCore, p.delay or 0.12)
		if to then
			ctx.marker = Kit.circle(G(to), 2.4, P.fire, { duration = (p.flight or 0.45) + (p.delay or 0.12) + 0.1, spin = 160,
				count = 6, star = 5, appear = 0.12, inner = P.fireCore })
		end
		sfx("spellFireLaunch", vec(p.from), 0.9)
	end,
	blast = function(p, ctx)
		local ground = G(vec(p.position, V3()))
		local radius = p.radius or 5
		local life = p.duration or 3
		local pr = p.pillarRadius or 4
		if ctx.marker then
			ctx.marker.destroy()
		end
		Kit.explosion(ground + V3(0, 1, 0), radius, P.fire, { core = P.fireCore, embers = 22, rocks = 6, ground = ground,
			shakeAmount = 0.35 })
		-- Столб огня на всё время: ядро, языки пламени, искры, дым и свет.
		Kit.pillar(ground, 16, pr * 0.55, P.fire, { time = 0.7, core = P.fireCore })
		local column = cylinderUp(ground, 12, pr * 0.9, P.fire, { Transparency = 0.55 })
		local inner = cylinderUp(ground, 12.5, pr * 0.35, P.fireCore, { Transparency = 0.25 })
		Kit.light(column, P.fire, 5, 24, life)
		Kit.every(life, function(k, t)
			local w = 1 + math.sin(t * 22) * 0.07
			local fade = k > 0.8 and (k - 0.8) / 0.2 or 0
			column.Size = V3(12, pr * 0.9 * w * (1 - fade * 0.8), pr * 0.9 * w * (1 - fade * 0.8))
			column.Transparency = 0.55 + 0.45 * fade
			inner.Transparency = 0.25 + 0.75 * fade
			column.CFrame = CFrame.new(ground + V3(0, 6, 0)) * CFrame.Angles(0, t * 2, math.pi / 2)
			return true
		end, function()
			column:Destroy()
			inner:Destroy()
		end)
		Kit.stream(CFrame.new(ground + V3(0, 0.3, 0)), { texture = "glow", color = { P.fireCore, P.fire, P.fireDark },
			size = { pr * 0.9, 0.3 }, rate = 90, life = { 0.5, 0.9 }, speed = { 10, 18 }, spread = 10, direction = Enum.NormalId.Top,
			shape = Enum.ParticleEmitterShape.Disc, size3 = V3(pr * 1.4, 0.2, pr * 1.4), transparency = { 0.1, 1 } }, life)
		Kit.stream(CFrame.new(ground + V3(0, 1, 0)), { texture = "spark", color = { P.fireCore, P.fire }, size = { 0.35, 0 },
			rate = 40, life = { 0.6, 1.2 }, speed = { 8, 16 }, spread = 25, direction = Enum.NormalId.Top, accel = V3(0, -6, 0) }, life)
		Kit.stream(CFrame.new(ground + V3(0, 9, 0)), { texture = "smoke", color = { "#4A2A1E", "#120C0A" }, size = { 3, 7 },
			rate = 6, life = { 1.2, 2 }, speed = { 2, 4 }, spread = 30, direction = Enum.NormalId.Top, transparency = { 0.5, 1 },
			lightEmission = 0, lightInfluence = 1 }, life)
		Kit.glowSpot(ground, pr * 1.3, P.fire, life, { transparency = 0.2 })
		sfx("spellFireBlast", ground)
		sfx("spellFireLoop", ground, 0.7)
	end,
	["end"] = function(p, ctx)
		local ground = G(vec(p.position, V3()))
		Kit.burst(ground + V3(0, 2, 0), { texture = "smoke", color = { "#5A3A2A", "#1E1612" }, size = { 2, 5 }, count = 10,
			life = { 0.8, 1.4 }, speed = { 3, 6 }, transparency = { 0.4, 1 }, lightEmission = 0, lightInfluence = 1 })
		dropCtx(ctx)
	end,
}

H.light_gate = {
	cast = function(p, ctx)
		local gate = G(vec(p.position, V3()), 0)
		local dir = Kit.flatUnit(vec(p.dir, V3(0, 0, -1)))
		local side = Kit.rotate(dir, 90)
		local width = p.width or 8
		local height = 9
		local parts = {}
		local left = cylinderUp(gate - side * width / 2, height, 1.1, P.lightCore)
		local right = cylinderUp(gate + side * width / 2, height, 1.1, P.lightCore)
		local leftGlow = cylinderUp(gate - side * width / 2, height, 2.2, P.light, { Transparency = 0.6 })
		local rightGlow = cylinderUp(gate + side * width / 2, height, 2.2, P.light, { Transparency = 0.6 })
		local lintel = Kit.part({ Size = V3(width + 1.6, 0.9, 0.9), Color = P.lightCore, Name = "MageGateTop" })
		local veil = Kit.part({ Size = V3(width, height, 0.15), Color = P.light, Transparency = 0.7, Name = "MageGateVeil" })
		parts = { left, right, leftGlow, rightGlow, lintel, veil }
		ctx.gate = { parts = parts, position = gate, dir = dir, side = side, width = width }
		local rise = 0.3
		local face = CFrame.lookAt(gate, gate + dir)
		Kit.every((p.closeAt or 1.25) + 0.05, function(_, t)
			local k = Kit.ease(math.clamp(t / rise, 0, 1), "back")
			local h = height * k
			for i, part in ipairs({ left, right, leftGlow, rightGlow }) do
				local sideSign = (i % 2 == 1) and -1 or 1
				local pos = gate + side * sideSign * width / 2
				part.Size = V3(math.max(h, 0.1), part.Size.Y, part.Size.Z)
				part.CFrame = CFrame.new(pos + V3(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			end
			lintel.CFrame = face * CFrame.new(0, h + 0.3, 0)
			veil.Size = V3(width, math.max(h, 0.1), 0.15)
			veil.CFrame = face * CFrame.new(0, h / 2, 0)
			veil.Transparency = 0.62 + math.sin(t * 9) * 0.08
			return ctx.gate ~= nil
		end)
		Kit.light(lintel, P.light, 5, 26, (p.closeAt or 1.25) + 0.3)
		Kit.stream(face * CFrame.new(0, height / 2, 0), { texture = "star", color = { P.lightCore, P.light }, size = { 0.5, 0 },
			rate = 40, life = { 0.4, 0.8 }, speed = { 1, 3 }, spread = 180, shape = Enum.ParticleEmitterShape.Box,
			size3 = V3(width, height, 0.4) }, p.closeAt or 1.25)
		ctx.circle = Kit.circle(G(gate), width * 0.65, P.light, { duration = (p.closeAt or 1.25) + 0.2, spin = 50, count = 10,
			inner = P.lightCore, fill = 0.7 })
		charge(p.caster, P.light, P.lightCore, p.surgeAt or 0.55)
		sfx("spellLight", gate)
	end,
	surge = function(p, ctx)
		local origin = vec(p.origin, V3())
		local dir = Kit.flatUnit(vec(p.dir, V3(0, 0, -1)))
		local length = p.length or 18
		local half = p.halfWidth or 4
		local y = 2
		local wall = Kit.part({ Size = V3(half * 2, 4.5, 1.2), Color = P.lightCore, Transparency = 0.1, Name = "MageSurge" })
		local halo = Kit.part({ Size = V3(half * 2.4, 6, 2.4), Color = P.light, Transparency = 0.6, Name = "MageSurgeHalo" })
		Kit.trail(wall, P.light, { width = 4, life = 0.3, vertical = true, colors = { P.lightCore, P.light } })
		local travel = 0.35
		Kit.every(travel + 0.15, function(k, t)
			local d = math.min(t / travel, 1) * length
			local pos = origin + dir * d + V3(0, y, 0)
			local cf = CFrame.lookAt(pos, pos + dir)
			wall.CFrame = cf
			halo.CFrame = cf
			local fade = math.clamp((t - travel) / 0.15, 0, 1)
			wall.Transparency = 0.1 + 0.9 * fade
			halo.Transparency = 0.6 + 0.4 * fade
			return true
		end, function()
			wall:Destroy()
			halo:Destroy()
		end)
		Kit.beam(origin + V3(0, y, 0), origin + dir * length + V3(0, y, 0), P.light, { width = half * 2, time = 0.45,
			transparency = 0.35, colors = { P.lightCore, P.light } })
		for i = 1, 6 do
			Kit.after(i * travel / 6, function()
				local pt = G(origin + dir * (length * i / 6))
				Kit.ringWave(pt, half, P.light, { time = 0.3, brightness = 4 })
				Kit.burst(pt + V3(0, 1, 0), { texture = "spark", color = { P.lightCore, P.light }, size = { 0.5, 0 }, count = 8,
					life = { 0.2, 0.4 }, speed = { 6, 12 }, direction = Enum.NormalId.Top, spread = 50 })
			end)
		end
		if ctx.gate then
			Kit.flash(ctx.gate.position + V3(0, 4.5, 0), P.light, 9, 0.25)
		end
		sfx("spellBurst", origin)
		shake(origin, 0.3, 0.25)
	end,
	close = function(p, ctx)
		local gate = G(vec(p.position, ctx.gate and ctx.gate.position or V3()))
		local radius = p.radius or 6
		local g = ctx.gate
		ctx.gate = nil
		if g then
			for _, part in ipairs(g.parts) do
				Kit.tween(part, 0.18, { CFrame = CFrame.new(gate + V3(0, 3, 0)), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				game:GetService("Debris"):AddItem(part, 0.25)
			end
		end
		if ctx.circle then
			ctx.circle.fade(0.3)
		end
		Kit.after(0.16, function()
			Kit.explosion(gate + V3(0, 2, 0), radius, P.light, { core = P.lightCore, smoke = false, ground = gate, shakeAmount = 0.35 })
			Kit.pillar(gate, 18, 2.2, P.light, { time = 0.5, core = P.lightCore })
			sfx("spellBurst", gate, 0.9)
		end)
		dropCtx(ctx)
	end,
}

-- ---------- Этаж 2 ----------

H.lotus_bloom = {
	cast = function(p, ctx)
		local center = G(vec(p.position, feetOf(p.caster, V3())), 0.15)
		local radius = p.radius or 6
		local openTime = p.geyserAt or 0.3
		local petals = {}
		for layer = 1, 2 do
			local n = layer == 1 and 8 or 6
			for i = 1, n do
				local petal = ellipsoid(V3(radius * (layer == 1 and 0.32 or 0.24), 0.25, radius * (layer == 1 and 0.62 or 0.46)),
					layer == 1 and P.lotus or P.lotusCore, { Transparency = layer == 1 and 0.15 or 0.05 })
				table.insert(petals, { part = petal, angle = (i - 1) / n * TAU + (layer == 2 and 0.3 or 0), layer = layer })
			end
		end
		local heart = Kit.ball(center + V3(0, 0.4, 0), 1.2, C("#FFE06A"))
		ctx.lotus = { petals = petals, heart = heart, center = center }
		local life = openTime + 1.2
		Kit.every(life, function(_, t)
			local open = Kit.ease(math.clamp(t / (openTime + 0.15), 0, 1), "out")
			local fade = math.clamp((t - openTime - 0.6) / 0.6, 0, 1)
			for _, entry in ipairs(petals) do
				local reach = radius * (entry.layer == 1 and 0.42 or 0.26)
				local tilt = math.rad(80 - 65 * open) * (entry.layer == 1 and 1 or 1.2)
				local cf = CFrame.new(center) * CFrame.Angles(0, entry.angle + t * 0.4, 0) * CFrame.new(0, 0, -reach * open)
					* CFrame.Angles(tilt, 0, 0) * CFrame.new(0, 0, -reach * 0.6)
				entry.part.CFrame = cf + V3(0, fade * 2, 0)
				entry.part.Transparency = (entry.layer == 1 and 0.15 or 0.05) + 0.85 * fade
			end
			heart.Transparency = fade
			return true
		end, function()
			for _, entry in ipairs(petals) do
				entry.part:Destroy()
			end
			heart:Destroy()
		end)
		ctx.circle = Kit.circle(center, radius, P.lotus, { duration = openTime + 0.8, spin = 25, count = 8, star = 8,
			inner = P.water, fill = 0.6 })
		Kit.light(heart, P.lotus, 3, 16, life)
		sfx("spellPetals", center)
	end,
	geyser = function(p, ctx)
		local center = G(vec(p.position, ctx.lotus and ctx.lotus.center or V3()))
		local radius = p.radius or 6
		Kit.pillar(center, 14, radius * 0.4, P.water, { time = 0.8, core = P.waterCore })
		Kit.shockwave(center + V3(0, 1, 0), radius, P.water, { time = 0.45, flat = true, ground = center })
		Kit.ringWave(center, radius, P.waterCore, { time = 0.55, brightness = 4 })
		Kit.stream(CFrame.new(center + V3(0, 0.5, 0)), { texture = "glow", color = { P.waterCore, P.water }, size = { 0.7, 0.2 },
			rate = 160, life = { 0.8, 1.3 }, speed = { 16, 26 }, spread = 14, direction = Enum.NormalId.Top, accel = V3(0, -40, 0),
			shape = Enum.ParticleEmitterShape.Disc, size3 = V3(radius * 0.7, 0.2, radius * 0.7) }, 0.5)
		Kit.burst(center + V3(0, 0.5, 0), { texture = "star", color = { P.lotusCore, P.lotus }, size = { 0.6, 0 }, count = 30,
			life = { 0.6, 1.1 }, speed = { 8, 16 }, spread = 70, direction = Enum.NormalId.Top, accel = V3(0, -10, 0),
			rotSpeed = { -300, 300 } })
		if ctx.circle then
			ctx.circle.pulse(0.2)
			ctx.circle.fade(0.6)
		end
		sfx("spellWater", center)
		shake(center, 0.25, 0.25)
		dropCtx(ctx)
	end,
}

H.mycelium = {
	cast = function(p, ctx)
		local tip = vec(p.position) or Kit.tipOf(p.caster)
		if not tip then
			return
		end
		local dir = Kit.flatUnit(vec(p.dir, V3(0, 0, -1)))
		ctx.mushrooms = {}
		local holder = Kit.holder(CFrame.lookAt(tip, tip + dir))
		local e = Kit.emitter(holder, { texture = "glow", color = { P.sporeCore, P.spore, P.poison }, size = { 0.8, 2.2 }, rate = 0,
			life = { 0.5, 0.9 }, speed = { 6, 12 }, spread = 40, direction = Enum.NormalId.Front, drag = 4, transparency = { 0.3, 1 } })
		e:Emit(30)
		game:GetService("Debris"):AddItem(holder, 1.2)
		Kit.flash(tip, P.spore, 2.4, 0.2)
		sfx("spellSpores", tip)
	end,
	mushroom = function(p, ctx)
		local ground = G(vec(p.position, V3()), 0)
		local delay = p.delay or 1
		local scale = math.clamp((p.radius or 2.5) / 2.5, 0.7, 1.4)
		local stem = cylinderUp(ground, 1.2 * scale, 0.55 * scale, P.sporeCore, { Material = Enum.Material.SmoothPlastic })
		local cap = ellipsoid(V3(2.2, 1.1, 2.2) * scale, P.spore, { Transparency = 0.05 })
		local dots = ellipsoid(V3(1.4, 0.8, 1.4) * scale, P.sporeCore, { Transparency = 0.3 })
		local entry = { stem = stem, cap = cap, dots = dots, alive = true }
		ctx.mushrooms = ctx.mushrooms or {}
		table.insert(ctx.mushrooms, { position = ground, entry = entry })
		local grow = 0.25
		Kit.every(delay + 0.4, function(_, t)
			if not entry.alive then
				return false
			end
			local k = Kit.ease(math.clamp(t / grow, 0, 1), "back")
			local swell = t > delay - 0.35 and (1 + (t - delay + 0.35) * 0.9) or 1
			local wob = 1 + math.sin(t * (t > delay - 0.35 and 40 or 8)) * 0.06
			local h = 1.2 * scale * k
			stem.Size = V3(math.max(h, 0.05), 0.55 * scale, 0.55 * scale)
			stem.CFrame = CFrame.new(ground + V3(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			cap.Size = V3(2.2, 1.1, 2.2) * scale * k * swell * wob
			cap.CFrame = CFrame.new(ground + V3(0, h + 0.2 * scale, 0))
			dots.Size = V3(1.4, 0.8, 1.4) * scale * k * swell * wob
			dots.CFrame = CFrame.new(ground + V3(0, h + 0.45 * scale, 0))
			return true
		end, function()
			if entry.alive then
				entry.alive = false
				stem:Destroy()
				cap:Destroy()
				dots:Destroy()
			end
		end)
		Kit.light(cap, P.spore, 1.5, 8, delay + 0.3)
		Kit.burst(ground + V3(0, 0.3, 0), { texture = "rock", color = { "#6B5A48", "#3A3028" }, size = { 0.25, 0.1 }, count = 5,
			life = { 0.3, 0.5 }, speed = { 3, 6 }, direction = Enum.NormalId.Top, spread = 50, accel = V3(0, -30, 0),
			lightEmission = 0, lightInfluence = 1 })
	end,
	pop = function(p, ctx)
		local ground = G(vec(p.position, V3()), 0)
		local radius = p.radius or 2.5
		-- Ближайший гриб к точке — лопается.
		local best, bestD = nil, 2.5
		for i, item in ipairs(ctx.mushrooms or {}) do
			local d = (item.position - ground).Magnitude
			if d < bestD and item.entry.alive then
				best, bestD = i, d
			end
		end
		if best then
			local entry = ctx.mushrooms[best].entry
			entry.alive = false
			for _, part in ipairs({ entry.stem, entry.cap, entry.dots }) do
				Kit.fade(part, 0.12, { Size = part.Size * 1.6 })
			end
		end
		Kit.burst(ground + V3(0, 1.2, 0), { texture = "smoke", color = { P.spore, P.poison }, size = { radius * 0.6, radius * 1.4 },
			count = 10, life = { 0.6, 1.0 }, speed = { radius * 1.5, radius * 3 }, drag = 4, transparency = { 0.3, 1 },
			lightEmission = 0.5 })
		Kit.burst(ground + V3(0, 1.2, 0), { texture = "glow", color = { P.sporeCore, P.spore }, size = { 0.35, 0 }, count = 24,
			life = { 0.6, 1.0 }, speed = { 6, 12 }, drag = 3, accel = V3(0, 2, 0) })
		Kit.ringWave(G(ground), radius, P.spore, { time = 0.35 })
		Kit.flash(ground + V3(0, 1.2, 0), P.spore, 3, 0.18)
		sfx("spellPop", ground, 0.8)
	end,
}

H.thorn_garden = {
	cast = function(p, ctx)
		local center = G(vec(p.position, feetOf(p.caster, V3())))
		local radius = p.radius or 9
		ctx.center = center
		ctx.circle = Kit.circle(center, radius, P.thorn, { duration = (p.gardenAt or 1) + (p.gardenTime or 3), spin = 18, count = 14,
			star = 7, inner = P.thornCore, fill = 0.66 })
		Kit.burst(center + V3(0, 0.5, 0), { texture = "star", color = { P.thornCore, P.thorn }, size = { 0.5, 0 }, count = 20,
			life = { 0.5, 0.9 }, speed = { 4, 8 }, direction = Enum.NormalId.Top, spread = 70 })
		sfx("spellThorns", center, 0.7)
	end,
	ring = function(p, ctx)
		local center = G(vec(p.position, ctx.center or V3()), 0)
		local radius = p.radius or 3
		local count = math.clamp(math.floor(radius * 2.6), 8, 26)
		for i = 1, count do
			local a = (i - 1) / count * TAU + (p.index or 1) * 0.4
			local out = V3(math.cos(a), 0, math.sin(a))
			spike(center + out * radius, 2.2 + math.random() * 1.4, P.thornDark, P.thorn, 0.5, out)
		end
		Kit.ringWave(G(center), radius + 0.5, P.thorn, { time = 0.35, brightness = 3.5 })
		if ctx.circle then
			ctx.circle.pulse(0.1)
		end
		sfx("spellThorns", center, 0.9)
		shake(center, 0.12, 0.15)
	end,
	garden = function(p, ctx)
		local center = G(vec(p.position, ctx.center or V3()))
		local radius = p.radius or 9
		local life = p.duration or 3
		Kit.glowSpot(center, radius, P.thornDark, life, { transparency = 0.25, brightness = 1.4 })
		Kit.glowSpot(center, radius * 0.8, P.thorn, life, { transparency = 0.6, lift = 0.1 })
		for _ = 1, 16 do
			local a = math.random() * TAU
			local r = math.sqrt(math.random()) * radius * 0.95
			spike(center + V3(math.cos(a) * r, 0, math.sin(a) * r), 0.9 + math.random() * 0.8, P.thornDark, P.thorn, life - 0.35)
		end
		Kit.stream(CFrame.new(center + V3(0, 0.3, 0)), { texture = "star", color = { P.thornCore, P.thorn }, size = { 0.35, 0 },
			rate = 30, life = { 0.8, 1.4 }, speed = { 0.5, 1.5 }, spread = 30, direction = Enum.NormalId.Top,
			shape = Enum.ParticleEmitterShape.Cylinder, size3 = V3(radius * 2, 0.2, radius * 2), rotSpeed = { -90, 90 } }, life)
	end,
	["end"] = function(_, ctx)
		if ctx.circle then
			ctx.circle.fade(0.5)
		end
		dropCtx(ctx)
	end,
}

-- ---------- Этаж 3 ----------

H.spirit_pack = {
	cast = function(p, ctx)
		local feet = G(vec(p.position, feetOf(p.caster, V3())))
		local dir = Kit.flatUnit(vec(p.dir, V3(0, 0, -1)))
		Kit.circle(feet, 3.5, P.spirit, { duration = 0.9, spin = 90, count = 8, star = 4, inner = P.spiritCore, appear = 0.12 })
		Kit.burst(feet + V3(0, 1, 0), { texture = "swirl", color = { P.spiritCore, P.spirit }, size = { 2, 0 }, count = 14,
			life = { 0.5, 0.9 }, speed = { 3, 7 }, spread = 60, direction = Enum.NormalId.Top, rotSpeed = { -200, 200 } })
		-- Призрачные «головы» стаи вспыхивают перед магом и срываются вперёд (сами волки — снаряды).
		for i = 1, (p.wolves or 4) do
			local side = Kit.rotate(dir, (i - ((p.wolves or 4) + 1) / 2) * 22)
			Kit.after(0.3 + i * 0.06, function()
				local at = feet + side * 1.5 + V3(0, 1.2, 0)
				Kit.flash(at, P.spirit, 2.2, 0.2)
				Kit.burst(at, { texture = "glow", color = { P.spiritCore, P.spirit }, size = { 0.6, 0 }, count = 8,
					life = { 0.3, 0.5 }, speed = { 3, 6 } })
			end)
		end
		local glow = Kit.holder(feet + V3(0, 2, 0))
		Kit.light(glow, P.spirit, 3, 14, 0.8)
		game:GetService("Debris"):AddItem(glow, 0.9) -- держатель света не висит вечно
		sfx("spellHowl", feet)
		dropCtx(ctx)
	end,
}

H.hunters_moon = {
	cast = function(p, ctx)
		local center = G(vec(p.position, V3()))
		local height = p.height or 14
		local radius = p.radius or 12
		local life = (p.crescentAt or 2.7) + 0.5
		local sky = center + V3(0, height, 0)
		local moon = Kit.ball(sky, 4.5, P.moonCore, { Transparency = 1 })
		local halo = Kit.ball(sky, 9, P.moon, { Transparency = 1, Material = Enum.Material.ForceField })
		local shadow = Kit.ball(sky + V3(1.4, 0.6, -0.6), 4.2, C("#2A3A6A"), { Transparency = 1 })
		ctx.moon = { moon = moon, halo = halo, shadow = shadow, sky = sky }
		Kit.every(life, function(_, t)
			local k = math.clamp(t / 0.4, 0, 1)
			local fade = math.clamp((t - life + 0.4) / 0.4, 0, 1)
			local rise = Kit.ease(k, "out")
			local pos = sky + V3(0, (1 - rise) * -4, 0)
			moon.CFrame = CFrame.new(pos)
			halo.CFrame = CFrame.new(pos)
			shadow.CFrame = CFrame.new(pos + V3(1.4, 0.6, -0.6))
			moon.Transparency = 1 - k + fade
			halo.Transparency = 1 - k * 0.6 + fade * 0.6
			shadow.Transparency = 1 - k * 0.15 + fade * 0.15
			return true
		end, function()
			moon:Destroy()
			halo:Destroy()
			shadow:Destroy()
		end)
		Kit.light(moon, P.moon, 4, 50, life)
		ctx.circle = Kit.circle(center, radius, P.moon, { duration = life, spin = 12, count = 16, star = 8, inner = P.moonCore, fill = 0.75 })
		Kit.stream(CFrame.new(sky), { texture = "star", color = { P.moonCore, P.moon }, size = { 0.6, 0 }, rate = 20,
			life = { 1, 1.6 }, speed = { 1, 3 }, spread = 180, rotSpeed = { -60, 60 } }, life - 0.3)
		charge(p.caster, P.moon, P.moonCore, 0.35)
		sfx("spellMoon", center)
	end,
	beam = function(p, ctx)
		local point = G(vec(p.position, V3()), 0.1)
		local from = vec(p.from, ctx.moon and ctx.moon.sky or point + V3(0, 14, 0))
		Kit.beam(from, point, P.moon, { width = 2.2, width1 = 1.4, time = 0.35, colors = { P.moonCore, P.moon } })
		Kit.beam(from, point, P.moonCore, { width = 0.6, time = 0.25, texture = "glow" })
		Kit.flash(point + V3(0, 0.8, 0), P.moon, 3.5, 0.2)
		Kit.ringWave(point, 2.2, P.moonCore, { time = 0.3, brightness = 4 })
		Kit.burst(point + V3(0, 0.5, 0), { texture = "star", color = { P.moonCore, P.moon }, size = { 0.5, 0 }, count = 12,
			life = { 0.3, 0.6 }, speed = { 6, 12 }, direction = Enum.NormalId.Top, spread = 70 })
		if ctx.moon then
			Kit.flash(from, P.moonCore, 5, 0.12)
		end
		sfx("spellMoonBeam", point, 0.8)
	end,
	crescent = function(p, ctx)
		local center = G(vec(p.position, V3()), 0.3)
		local radius = p.radius or 8
		local dir = Kit.flatUnit(vec(p.dir, V3(0, 0, -1)))
		-- Серп: два ряда пластин по дуге 300°, растут от центра к краю.
		local count = 22
		local blades = {}
		for i = 1, count do
			blades[i] = Kit.part({ Size = V3(1, 0.3, 0.5), Color = (i % 2 == 0) and P.moonCore or P.moon, Transparency = 0.1,
				Name = "MageCrescent" })
		end
		local travel = 0.35
		Kit.every(travel + 0.2, function(_, t)
			local r = math.min(t / travel, 1) * radius + 0.5
			local fade = math.clamp((t - travel) / 0.2, 0, 1)
			for i, blade in ipairs(blades) do
				local a = -150 + (i - 1) / (count - 1) * 300
				local d = Kit.rotate(dir, a)
				local thick = 1 - math.abs(a) / 170
				local pos = center + d * r + V3(0, 1, 0)
				blade.Size = V3((TAU * r * 300 / 360) / count * 1.2, 0.3 + thick * 1.6, 0.5)
				blade.CFrame = CFrame.lookAt(pos, pos + d)
				blade.Transparency = 0.1 + 0.9 * fade
			end
			return true
		end, function()
			for _, blade in ipairs(blades) do
				blade:Destroy()
			end
		end)
		Kit.shockwave(center + V3(0, 1, 0), radius, P.moon, { time = 0.4, flat = true, ground = center })
		Kit.burst(center + V3(0, 1, 0), { texture = "slash", color = { P.moonCore, P.moon }, size = { 3, 0 }, count = 8,
			life = { 0.2, 0.35 }, speed = { 10, 20 }, rotSpeed = { -300, 300 } })
		if ctx.moon then
			Kit.flash(ctx.moon.sky, P.moonCore, 10, 0.3)
		end
		if ctx.circle then
			ctx.circle.fade(0.4)
		end
		sfx("spellCrescent", center)
		shake(center, 0.3, 0.25)
		dropCtx(ctx)
	end,
}


-- ---------- Этаж 4 ----------

H.fire_rain = {
	cast = function(p, ctx)
		local center = G(vec(p.position, V3()))
		local radius = p.radius or 10
		local life = (p.startAt or 0.25) + (p.duration or 2) + 0.7
		ctx.circle = Kit.circle(center, radius, P.fire, { duration = life, spin = 22, count = 12, star = 5, inner = P.fireCore,
			fill = 0.68 })
		Kit.glowSpot(center, radius * 1.1, P.fireDark, life, { transparency = 0.5 })
		-- Тлеющее небо: багровое облако над кругом.
		Kit.stream(CFrame.new(center + V3(0, 18, 0)), { texture = "smoke", color = { "#7A2A14", "#2A0E08" }, size = { 6, 10 },
			rate = 8, life = { 1.4, 2.2 }, speed = { 0.5, 1.5 }, spread = 180, shape = Enum.ParticleEmitterShape.Box,
			size3 = V3(radius * 2, 1, radius * 2), transparency = { 0.4, 1 }, lightEmission = 0.4 }, life - 0.6)
		charge(p.caster, P.fire, P.fireCore, p.startAt or 0.25)
		sfx("spellCharge", center)
	end,
	meteor = function(p, ctx)
		local to = vec(p.position)
		local from = vec(p.from)
		if not to or not from then
			return
		end
		local ground = G(to, 0.2)
		local radius = p.radius or 3
		Kit.ringWave(ground, radius, P.fire, { time = p.fall or 0.45, from = radius * 0.3, transparency = 0.3 })
		meteorFall(from, ground + V3(0, 0.5, 0), p.fall or 0.45, radius, false, function()
			meteorImpact(ground, radius, false)
			if ctx.circle then
				ctx.circle.pulse(0.05)
			end
		end)
		sfx("spellMeteorFall", ground, 0.5)
	end,
	["end"] = function(_, ctx)
		if ctx.circle then
			ctx.circle.fade(0.5)
		end
		dropCtx(ctx)
	end,
}

H.forged_lightning = {
	cast = function(p, ctx)
		local model = p.model
		local at = vec(p.position) or (model and model.PrimaryPart and model.PrimaryPart.Position)
		if not at then
			return
		end
		local ground = G(at)
		local strikeAt = p.strikeAt or 0.25
		Kit.circle(ground, 2.6, P.bolt, { duration = strikeAt + 0.25, spin = 240, count = 6, star = 3, inner = P.boltCore, appear = 0.1 })
		Kit.stream(CFrame.new(ground + V3(0, 16, 0)), { texture = "smoke", color = { "#3A4460", "#12141E" }, size = { 4, 7 }, rate = 30,
			life = { 0.5, 0.9 }, speed = { 1, 3 }, spread = 180, transparency = { 0.3, 1 }, lightEmission = 0.2 }, strikeAt + 0.2)
		Kit.stream(CFrame.new(ground + V3(0, 0.5, 0)), { texture = "spark", color = { P.boltCore, P.bolt }, size = { 0.3, 0 },
			rate = 40, life = { 0.08, 0.16 }, speed = { 6, 10 }, spread = 70, direction = Enum.NormalId.Top }, strikeAt)
		charge(p.caster, P.bolt, P.boltCore, strikeAt)
		sfx("spellCharge", ground, 0.8)
	end,
	strike = function(p, ctx)
		local at = vec(p.position)
		if not at then
			return
		end
		local ground = G(at, 0.1)
		local sky = ground + V3(math.random() * 4 - 2, 32, math.random() * 4 - 2)
		Kit.lightning(sky, ground + V3(0, 0.5, 0), P.bolt, { width = 0.45, jitter = 1.6, time = 0.3, branches = 4, core = P.boltCore,
			flash = 5 })
		Kit.after(0.05, function()
			Kit.lightning(sky + V3(1, 0, 0), ground + V3(0, 0.5, 0), P.boltDeep, { width = 0.25, jitter = 2.2, time = 0.22, branches = 2 })
		end)
		Kit.explosion(ground + V3(0, 1, 0), 3.5, P.bolt, { core = P.boltCore, smoke = false, ground = ground, shakeAmount = 0.4 })
		Kit.pillar(ground, 20, 1.2, P.bolt, { time = 0.35, core = P.boltCore })
		for i = 1, 5 do
			Kit.crack(ground, Kit.rotate(V3(0, 0, -1), i * 72 + math.random() * 30), 2.5 + math.random() * 2, P.bolt,
				{ width = 0.25, reveal = 0.08, time = 0.8 })
		end
		sfx("spellLightning", ground)
		sfx("spellAnvil", ground, 0.8)
		shake(ground, 0.45, 0.3)
	end,
	chain = function(p, ctx)
		local points = p.points
		if type(points) ~= "table" then
			return
		end
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			if typeof(a) == "Vector3" and typeof(b) == "Vector3" then
				Kit.after(0.07 * i, function()
					Kit.lightning(a + V3(0, 2.4, 0), b + V3(0, 2.4, 0), P.bolt, { width = 0.24, time = 0.24, core = P.boltCore, branches = 1 })
					Kit.flash(b + V3(0, 2.4, 0), P.bolt, 2.6, 0.15)
					Kit.burst(b + V3(0, 2.4, 0), { texture = "spark", color = { P.boltCore, P.bolt }, size = { 0.4, 0 }, count = 10,
						life = { 0.1, 0.25 }, speed = { 8, 14 } })
				end)
			end
		end
		sfx("spellChain", points[1])
		dropCtx(ctx)
	end,
}

H.forge_heart = {
	cast = function(p, ctx)
		local origin = vec(p.origin, V3())
		local dir = Kit.flatUnit(vec(p.dir, V3(0, 0, -1)))
		local length = p.length or 16
		local life = (p.wallAt or 1) + (p.wallTime or 3) + 0.4
		Kit.crack(G(origin), dir, length, P.magma, { width = 0.7, reveal = p.crackTime or 0.4, time = life, jitter = 0.7,
			core = P.magmaCore })
		Kit.crack(G(origin), Kit.rotate(dir, 8), length * 0.8, P.fire, { width = 0.35, reveal = (p.crackTime or 0.4) * 1.2, time = life })
		for i = 1, 6 do
			Kit.after((p.crackTime or 0.4) * i / 6, function()
				local pt = G(origin + dir * length * i / 6)
				Kit.burst(pt + V3(0, 0.3, 0), { texture = "rock", color = { "#5A4436", "#2A201A" }, size = { 0.4, 0.15 }, count = 5,
					life = { 0.4, 0.7 }, speed = { 4, 8 }, spread = 50, direction = Enum.NormalId.Top, accel = V3(0, -30, 0),
					lightEmission = 0, lightInfluence = 1 })
			end)
		end
		charge(p.caster, P.magma, P.magmaCore, p.crackTime or 0.4)
		sfx("spellRift", origin)
		shake(origin, 0.2, 0.3)
	end,
	pillar = function(p, _)
		local ground = G(vec(p.position, V3()), 0.1)
		local radius = p.radius or 2.8
		Kit.pillar(ground, 13, radius * 0.75, P.fire, { time = 0.75, core = P.fireCore })
		Kit.explosion(ground + V3(0, 1, 0), radius, P.magma, { core = P.magmaCore, embers = 10, rocks = 6, ground = ground,
			shakeAmount = 0.18, smoke = true })
		sfx("spellFireBlast", ground, 0.8)
	end,
	wall = function(p, _)
		local origin = vec(p.origin, V3())
		local dir = Kit.flatUnit(vec(p.dir, V3(0, 0, -1)))
		local length = p.length or 16
		local half = p.halfWidth or 1.6
		local life = p.duration or 3
		local mid = G(origin + dir * length / 2, 0.1)
		local cf = CFrame.lookAt(mid, mid + dir)
		local strip = Kit.part({ Size = V3(half * 1.4, 0.12, length), Color = P.magma, Transparency = 0.1, Name = "MageLavaStrip" })
		strip.CFrame = cf
		local wall = Kit.part({ Size = V3(half * 1.2, 3, length), Color = P.fire, Transparency = 0.7, Name = "MageFireWall" })
		Kit.light(strip, P.fire, 4, 18, life)
		Kit.every(life, function(k, t)
			local h = 2.5 + math.sin(t * 14) * 0.4
			local fade = k > 0.85 and (k - 0.85) / 0.15 or 0
			wall.Size = V3(half * 1.2, h * (1 - fade), length)
			wall.CFrame = cf * CFrame.new(0, h / 2, 0)
			wall.Transparency = 0.7 + 0.3 * fade
			strip.Transparency = 0.1 + 0.9 * fade
			return true
		end, function()
			wall:Destroy()
			strip:Destroy()
		end)
		local holder = Kit.holder(cf * CFrame.new(0, 0.3, 0))
		holder.Size = V3(half * 1.6, 0.2, length)
		local e1 = Kit.emitter(holder, { texture = "glow", color = { P.fireCore, P.fire, P.fireDark }, size = { 2.2, 0.4 }, rate = 220,
			life = { 0.4, 0.7 }, speed = { 6, 11 }, spread = 10, direction = Enum.NormalId.Top, shape = Enum.ParticleEmitterShape.Box,
			transparency = { 0.15, 1 } })
		local e2 = Kit.emitter(holder, { texture = "spark", color = { P.fireCore, P.fire }, size = { 0.3, 0 }, rate = 60,
			life = { 0.6, 1.1 }, speed = { 6, 12 }, spread = 25, direction = Enum.NormalId.Top, shape = Enum.ParticleEmitterShape.Box,
			accel = V3(0, -4, 0) })
		local e3 = Kit.emitter(holder, { texture = "smoke", color = { "#4A2A1E", "#120C0A" }, size = { 2, 5 }, rate = 12,
			life = { 1, 1.6 }, speed = { 4, 7 }, spread = 15, direction = Enum.NormalId.Top, shape = Enum.ParticleEmitterShape.Box,
			transparency = { 0.5, 1 }, lightEmission = 0, lightInfluence = 1 })
		task.delay(life, function()
			e1.Enabled = false
			e2.Enabled = false
			e3.Enabled = false
		end)
		game:GetService("Debris"):AddItem(holder, life + 2)
		sfx("spellFireLoop", mid)
	end,
	["end"] = function(p, ctx)
		local origin = vec(p.origin)
		if origin then
			Kit.burst(G(origin) + V3(0, 1, 0), { texture = "smoke", color = { "#5A3A2A", "#1E1612" }, size = { 2, 4 }, count = 8,
				life = { 0.8, 1.2 }, speed = { 2, 4 }, transparency = { 0.4, 1 }, lightEmission = 0, lightInfluence = 1 })
		end
		dropCtx(ctx)
	end,
}

H.meteor = {
	cast = function(p, ctx)
		local center = G(vec(p.position, V3()))
		local radius = p.radius or 8
		local impactAt = p.impactAt or 1
		local from = vec(p.from, center + V3(0, 60, 0))
		ctx.circle = Kit.circle(center, radius, P.magma, { duration = impactAt + 0.3, spin = 60, count = 12, star = 6, ticks = 36,
			inner = P.fireCore, fill = 0.55, brightness = 3 })
		Kit.ringWave(center, radius, P.fire, { time = impactAt, from = radius * 0.2, transparency = 0.2 })
		Kit.glowSpot(center, radius * 1.2, P.fire, impactAt + 0.2, { transparency = 0.35 })
		meteorFall(from, center + V3(0, 1.5, 0), impactAt, radius, true, nil)
		charge(p.caster, P.magma, P.magmaCore, 0.5)
		sfx("spellMeteorFall", center)
	end,
	impact = function(p, ctx)
		local center = G(vec(p.position, V3()), 0.1)
		local radius = p.radius or 8
		local lavaRadius = p.lavaRadius or 5
		local lavaTime = p.lavaTime or 3
		if ctx.circle then
			ctx.circle.destroy()
		end
		meteorImpact(center, radius, true)
		Kit.pillar(center, 26, 3, P.fire, { time = 0.8, core = P.fireCore })
		Kit.flash(center + V3(0, 3, 0), P.fireCore, 18, 0.35)
		-- Лужа лавы: пятно, кромка, пузыри и жар.
		Kit.glowSpot(center, lavaRadius, P.magma, lavaTime, { transparency = 0.05, brightness = 2.6 })
		Kit.glowSpot(center, lavaRadius * 0.6, P.magmaCore, lavaTime, { transparency = 0.35, lift = 0.12 })
		Kit.stream(CFrame.new(center + V3(0, 0.2, 0)), { texture = "glow", color = { P.magmaCore, P.magma }, size = { 0.8, 0 },
			rate = 30, life = { 0.4, 0.8 }, speed = { 2, 5 }, spread = 20, direction = Enum.NormalId.Top, accel = V3(0, -12, 0),
			shape = Enum.ParticleEmitterShape.Disc, size3 = V3(lavaRadius * 1.6, 0.2, lavaRadius * 1.6) }, lavaTime)
		Kit.stream(CFrame.new(center + V3(0, 0.5, 0)), { texture = "smoke", color = { "#4A2A1E", "#120C0A" }, size = { 2, 5 },
			rate = 8, life = { 1.2, 2 }, speed = { 2, 4 }, spread = 20, direction = Enum.NormalId.Top, shape = Enum.ParticleEmitterShape.Disc,
			size3 = V3(lavaRadius * 1.6, 0.2, lavaRadius * 1.6), transparency = { 0.5, 1 }, lightEmission = 0, lightInfluence = 1 }, lavaTime)
		local heat = Kit.holder(center + V3(0, 2, 0))
		Kit.light(heat, P.fire, 4, lavaRadius * 4, lavaTime)
		game:GetService("Debris"):AddItem(heat, lavaTime + 0.1) -- держатель света не висит вечно
		sfx("spellLava", center)
		shake(center, 0.9, 0.5)
	end,
	["end"] = function(_, ctx)
		dropCtx(ctx)
	end,
}

H.first_cast = {
	cast = function(p, ctx)
		local center = G(vec(p.position, feetOf(p.caster, V3())))
		local radius = p.radius or 14
		local novaAt = p.novaAt or 1.25
		ctx.center = center
		ctx.circle = Kit.circle(center, radius, P.forge, { duration = novaAt + 0.2, spin = 40, count = 16, star = 8, ticks = 48,
			roman = false, inner = P.forgeHot, fill = 0.5, brightness = 3.2 })
		ctx.inner = Kit.circle(center + V3(0, 0.05, 0), radius * 0.45, P.forgeHot, { duration = novaAt + 0.2, spin = -90, count = 8,
			star = 5, inner = WHITE, fill = 0.7 })
		-- Свет стягивается к магу со всего круга.
		local holder = Kit.holder(center + V3(0, 0.5, 0))
		holder.Size = V3(radius * 2, 0.2, radius * 2)
		local pull = Kit.emitter(holder, { texture = "glow", color = { WHITE, P.forge }, size = { 0.6, 0.1 }, rate = 120,
			life = { 0.6, 0.9 }, speed = { 1, 2 }, spread = 10, direction = Enum.NormalId.Top, shape = Enum.ParticleEmitterShape.Disc })
		local root = rootOf(p.caster)
		local column = root and cylinderUp(center, 30, 1.2, P.forge, { Transparency = 0.4 })
		Kit.every(novaAt, function(k, t)
			if column then
				local w = 1.2 + k * 2.5 + math.sin(t * 30) * 0.15
				column.Size = V3(30, w, w)
				column.Transparency = 0.6 - k * 0.3
			end
			return true
		end, function()
			pull.Enabled = false
			game:GetService("Debris"):AddItem(holder, 1)
			if column then
				column:Destroy()
			end
		end)
		if column then
			Kit.light(column, P.forge, 6, 40, novaAt)
		end
		charge(p.caster, P.forge, WHITE, novaAt)
		sfx("spellCharge", center)
		sfx("spellRunes", center, 0.8)
	end,
	rift = function(p, _)
		local origin = vec(p.origin, V3())
		local dir = Kit.flatUnit(vec(p.dir, V3(0, 0, -1)))
		local length = p.length or 11
		Kit.crack(G(origin), dir, length, P.forgeHot, { width = 0.6, reveal = 0.12, time = 1.2, core = WHITE, jitter = 0.5 })
		for i = 1, 3 do
			local pt = G(origin + dir * length * (i - 0.5) / 3)
			Kit.after(0.04 * i, function()
				Kit.pillar(pt, 10 + i * 2, 0.7, P.forge, { time = 0.45, core = WHITE, particles = false })
			end)
		end
		Kit.beam(G(origin, 0.6), G(origin + dir * length, 0.6), P.forgeHot, { width = 1.6, time = 0.4, colors = { WHITE, P.forgeHot } })
		sfx("spellRift", origin, 0.7)
	end,
	nova = function(p, ctx)
		local center = G(vec(p.position, ctx.center or V3()), 0.1)
		local radius = p.radius or 14
		if ctx.circle then
			ctx.circle.destroy()
		end
		if ctx.inner then
			ctx.inner.destroy()
		end
		Kit.flash(center + V3(0, 3, 0), WHITE, radius * 1.6, 0.4)
		Kit.explosion(center + V3(0, 2, 0), radius, P.forgeHot, { core = WHITE, embers = 40, rocks = 12, ground = center,
			shakeAmount = 1.0, shakeTime = 0.6 })
		Kit.shockwave(center + V3(0, 2, 0), radius * 1.2, P.forge, { time = 0.6, ground = center })
		Kit.ringWave(center, radius * 1.3, WHITE, { time = 0.7, brightness = 5 })
		Kit.pillar(center, 40, 4, P.forge, { time = 1.0, core = WHITE })
		Kit.burst(center + V3(0, 2, 0), { texture = "spark", color = { WHITE, P.forge, P.forgeHot }, size = { 0.8, 0 }, count = 80,
			life = { 0.5, 1.0 }, speed = { radius * 2, radius * 4 }, spread = 180, drag = 2 })
		Kit.glowSpot(center, radius, P.forgeHot, 1.6, { transparency = 0.3 })
		sfx("spellNova", center)
		dropCtx(ctx)
	end,
}

-- ---------- Этаж 5 ----------

H.open_tome = {
	cast = function(p, ctx)
		local caster = p.caster
		local startAt = p.startAt or 0.3
		local life = (p.stormAt or 1.3) + 0.35
		local cover = C("#5A3A22")
		local left = Kit.part({ Size = V3(1.7, 0.16, 2.3), Color = cover, Material = Enum.Material.SmoothPlastic, Name = "MageTome" })
		local right = Kit.part({ Size = V3(1.7, 0.16, 2.3), Color = cover, Material = Enum.Material.SmoothPlastic, Name = "MageTome" })
		local pagesL = Kit.part({ Size = V3(1.55, 0.12, 2.1), Color = P.pageCore, Name = "MageTomePages" })
		local pagesR = Kit.part({ Size = V3(1.55, 0.12, 2.1), Color = P.pageCore, Name = "MageTomePages" })
		local flips = {}
		for i = 1, 3 do
			flips[i] = Kit.part({ Size = V3(1.5, 0.04, 2.0), Color = P.pageCore, Name = "MageTomeFlip" })
		end
		ctx.book = { parts = { left, right, pagesL, pagesR, flips[1], flips[2], flips[3] } }
		local light = Kit.light(pagesL, P.gold, 4, 16)
		local glyphs = Kit.emitter(pagesR, { texture = "star", color = { P.pageCore, P.gold }, size = { 0.4, 0 }, rate = 30,
			life = { 0.5, 0.9 }, speed = { 1, 3 }, spread = 40, direction = Enum.NormalId.Top })
		local lastPos = nil
		Kit.every(life, function(_, t)
			local root = rootOf(caster)
			local base
			if root then
				local look = Kit.flatUnit(root.CFrame.LookVector)
				local pos = root.Position + V3(0, 3.6 + math.sin(t * 3) * 0.15, 0) - look * 0.3
				base = CFrame.lookAt(pos, pos + look) * CFrame.Angles(math.rad(-25), 0, 0)
				lastPos = base
			else
				base = lastPos or CFrame.new()
			end
			local open = Kit.ease(math.clamp(t / startAt, 0, 1), "back")
			local close = math.clamp((t - life + 0.3) / 0.3, 0, 1)
			local a = math.rad(85) * (open - close)
			left.CFrame = base * CFrame.Angles(0, 0, a) * CFrame.new(-0.85, 0, 0)
			right.CFrame = base * CFrame.Angles(0, 0, -a) * CFrame.new(0.85, 0, 0)
			pagesL.CFrame = left.CFrame * CFrame.new(0.05, 0.12, 0)
			pagesR.CFrame = right.CFrame * CFrame.new(-0.05, 0.12, 0)
			for i, flip in ipairs(flips) do
				local phase = ((t * 2.2 + i / 3) % 1)
				local fa = a - (2 * a) * phase
				flip.CFrame = base * CFrame.Angles(0, 0, fa) * CFrame.new(fa >= 0 and -0.78 or 0.78, 0.2, 0)
				flip.Transparency = open > 0.9 and close < 0.1 and 0 or 1
			end
			light.Brightness = 2 + open * 3
			return true
		end, function()
			glyphs.Enabled = false
			for _, part in ipairs(ctx.book and ctx.book.parts or {}) do
				Kit.fade(part, 0.2)
			end
		end)
		local root = rootOf(caster)
		if root then
			Kit.circle(G(root.Position - V3(0, 3, 0)), 3, P.gold, { duration = life, spin = 40, count = 10, glyphs = { "§", "¶", "†", "‡", "※" },
				inner = P.pageCore })
		end
		sfx("spellPages", root and root.Position)
	end,
	storm = function(p, ctx)
		local center = G(vec(p.position, feetOf(p.caster, V3())))
		local radius = p.radius or 6
		local pages = {}
		for i = 1, 26 do
			pages[i] = { part = Kit.part({ Size = V3(0.9, 0.04, 1.2), Color = (i % 3 == 0) and P.gold or P.pageCore, Name = "MagePage" }),
				a = math.random() * TAU, r = 1 + math.random() * (radius - 1), h = math.random() * 4, spin = math.random() * 10 }
		end
		local life = 0.9
		Kit.every(life, function(k, t)
			for _, page in ipairs(pages) do
				local a = page.a + t * (6 - page.r * 0.4)
				local r = page.r * (0.4 + 0.6 * Kit.ease(k, "out"))
				local pos = center + V3(math.cos(a) * r, 0.8 + page.h + k * 3, math.sin(a) * r)
				page.part.CFrame = CFrame.new(pos) * CFrame.Angles(t * page.spin, a, t * page.spin * 0.7)
				page.part.Transparency = math.clamp((k - 0.7) / 0.3, 0, 1)
			end
			return true
		end, function()
			for _, page in ipairs(pages) do
				page.part:Destroy()
			end
		end)
		Kit.shockwave(center + V3(0, 1.5, 0), radius, P.gold, { time = 0.45, flat = true, ground = center })
		Kit.burst(center + V3(0, 2, 0), { texture = "star", color = { P.pageCore, P.gold }, size = { 0.6, 0 }, count = 40,
			life = { 0.5, 0.9 }, speed = { 10, 18 }, drag = 3, rotSpeed = { -300, 300 } })
		Kit.flash(center + V3(0, 3.5, 0), P.gold, 6, 0.25)
		sfx("spellStorm", center)
		shake(center, 0.25, 0.25)
		dropCtx(ctx)
	end,
}

local timeTint = nil
local function timeShade(on: boolean, duration: number?)
	if not timeTint or not timeTint.Parent then
		timeTint = Instance.new("ColorCorrectionEffect")
		timeTint.Name = "MageTimeStop"
		timeTint.Parent = Lighting
	end
	if on then
		Kit.tween(timeTint, 0.15, { Saturation = -0.75, TintColor = Color3.fromRGB(210, 240, 255), Contrast = 0.1 })
		local stamp = os.clock()
		timeTint:SetAttribute("Stamp", stamp)
		task.delay((duration or 2) + 0.5, function()
			if timeTint and timeTint:GetAttribute("Stamp") == stamp then
				Kit.tween(timeTint, 0.25, { Saturation = 0, TintColor = WHITE, Contrast = 0 })
			end
		end)
	else
		Kit.tween(timeTint, 0.25, { Saturation = 0, TintColor = WHITE, Contrast = 0 })
	end
end

H.time_stop = {
	cast = function(p, ctx)
		local center = G(vec(p.position, feetOf(p.caster, V3())))
		local radius = p.radius or 10
		local life = (p.freezeAt or 0.3) + (p.freeze or 2) + 0.5
		local dir = Kit.flatUnit(vec(p.dir, V3(0, 0, -1)))
		ctx.center = center
		ctx.circle = Kit.circle(center, radius, P.time, { duration = life, spin = 6, roman = true, ticks = 60, star = 12,
			inner = P.gold, fill = 0.7, brightness = 3 })
		local hourHand = Kit.part({ Size = V3(0.5, 0.12, radius * 0.5), Color = P.gold, Name = "MageClockHand" })
		local minuteHand = Kit.part({ Size = V3(0.32, 0.12, radius * 0.85), Color = P.timeCore, Name = "MageClockHand" })
		local hub = cylinderUp(center, 0.3, 1.2, P.gold)
		ctx.hands = { hour = hourHand, minute = minuteHand, hub = hub, speed = 1, angle = 0 }
		local hands = ctx.hands
		local baseAngle = math.atan2(dir.X, dir.Z)
		Kit.every(life, function(k, t, dt)
			if hands.dead then
				return false
			end
			hands.angle += dt * hands.speed * (hands.strike and 18 or 7)
			local a = baseAngle + hands.angle
			local h = a / 12
			local lift = center + V3(0, 0.25, 0)
			minuteHand.CFrame = CFrame.new(lift) * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0, -radius * 0.42)
			hourHand.CFrame = CFrame.new(lift + V3(0, 0.05, 0)) * CFrame.Angles(0, -h, 0) * CFrame.new(0, 0, -radius * 0.25)
			local fade = math.clamp((k - 0.9) / 0.1, 0, 1)
			minuteHand.Transparency = fade
			hourHand.Transparency = fade
			hub.Transparency = fade
			return true
		end, function()
			hourHand:Destroy()
			minuteHand:Destroy()
			hub:Destroy()
		end)
		Kit.light(hub, P.time, 4, radius * 2.5, life)
		charge(p.caster, P.time, P.timeCore, p.freezeAt or 0.3)
		sfx("spellTick", center)
	end,
	freeze = function(p, ctx)
		local center = G(vec(p.position, ctx.center or V3()))
		local radius = p.radius or 10
		local duration = p.duration or 2
		if ctx.hands then
			ctx.hands.speed = 0
		end
		if ctx.circle then
			ctx.circle.setSpin(0, 0)
			ctx.circle.pulse(0.08)
		end
		Kit.ringWave(center, radius, P.timeCore, { time = 0.35, brightness = 4 })
		Kit.flash(center + V3(0, 2, 0), P.time, 8, 0.2)
		ctx.bubbles = {}
		for _, model in ipairs(p.models or {}) do
			local root = model and model.PrimaryPart
			if root then
				local height = model:GetAttribute("EnemyHeight") or 3
				local d = math.clamp(height * 1.3, 3, 10)
				local bubble = Kit.dome(root.Position, d / 2, P.time, { Transparency = 0.1 })
				local ring = Kit.part({ Shape = Enum.PartType.Cylinder, Size = V3(0.08, d * 1.1, d * 1.1), Color = P.gold,
					Transparency = 0.35, Name = "MageTimeRing" })
				local until_ = model:GetAttribute("MageFrozenUntil") or (now() + duration)
				Kit.every(math.max(until_ - now(), 0.3) + 0.2, function(_, t)
					if not root.Parent then
						return false
					end
					bubble.CFrame = root.CFrame
					ring.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, t * 0.6, math.pi / 2 + 0.3)
					return now() < (model:GetAttribute("MageFrozenUntil") or until_) and not ctx.shattered
				end, function()
					local pos = root.Parent and root.Position or bubble.Position
					bubble:Destroy()
					ring:Destroy()
					Kit.burst(pos, { texture = "spark", color = { P.timeCore, P.time }, size = { 0.5, 0 }, count = 14,
						life = { 0.3, 0.5 }, speed = { 8, 14 }, accel = V3(0, -20, 0) })
				end)
				table.insert(ctx.bubbles, bubble)
			end
		end
		-- Мир теряет цвет, если маг или игрок рядом с циферблатом.
		local myRoot = rootOf(player)
		if myRoot and (myRoot.Position - center).Magnitude <= radius * 1.6 then
			timeShade(true, duration)
		end
		sfx("spellTimeStop", center)
	end,
	strike = function(p, ctx)
		local center = G(vec(p.position, ctx.center or V3()), 0.1)
		local radius = p.radius or 10
		ctx.shattered = true
		if ctx.hands then
			ctx.hands.speed = 1
			ctx.hands.strike = true
		end
		timeShade(false)
		Kit.shockwave(center + V3(0, 1.5, 0), radius, P.time, { time = 0.45, ground = center })
		Kit.ringWave(center, radius * 1.1, P.gold, { time = 0.5, brightness = 5 })
		Kit.burst(center + V3(0, 1.5, 0), { texture = "slash", color = { P.timeCore, P.gold }, size = { 4, 0 }, count = 10,
			life = { 0.2, 0.35 }, speed = { 12, 22 }, rotSpeed = { -500, 500 } })
		Kit.burst(center + V3(0, 1.5, 0), { texture = "spark", color = { WHITE, P.time }, size = { 0.6, 0 }, count = 50,
			life = { 0.3, 0.6 }, speed = { radius * 2, radius * 3.5 }, drag = 3 })
		Kit.flash(center + V3(0, 2, 0), P.timeCore, radius * 1.2, 0.3)
		if ctx.circle then
			ctx.circle.fade(0.4)
		end
		Kit.after(0.4, function()
			if ctx.hands then
				ctx.hands.dead = true
			end
		end)
		sfx("spellTimeStrike", center)
		shake(center, 0.5, 0.3)
		dropCtx(ctx)
	end,
}

H.fate_line = {
	cast = function(p, ctx)
		local origin = vec(p.origin, V3())
		local dir = Kit.flatUnit(vec(p.dir, V3(0, 0, -1)))
		local length = p.length or 20
		local igniteAt = p.igniteAt or 0.8
		local count = math.clamp(math.floor(length / 1.6), 6, 16)
		ctx.letters = {}
		local alphabet = { "Α", "Ω", "Σ", "Φ", "Ψ", "Λ", "Ξ", "Θ", "Δ", "Π", "†", "‡", "§", "¶" }
		for i = 1, count do
			local pos = G(origin + dir * (length * (i - 0.5) / count), 0.1)
			local part, label = letterPlane(pos, dir, alphabet[(i - 1) % #alphabet + 1], 1.7, P.gold, P.inkDark)
			table.insert(ctx.letters, { part = part, label = label })
			Kit.after(igniteAt * 0.8 * (i - 1) / count, function()
				Kit.tween(label, 0.12, { TextTransparency = 0 })
				Kit.burst(pos + V3(0, 0.3, 0), { texture = "glow", color = { P.inkCore, P.ink }, size = { 0.4, 0 }, count = 4,
					life = { 0.3, 0.5 }, speed = { 1, 3 }, direction = Enum.NormalId.Top, spread = 40 })
			end)
		end
		-- Тонкая строка-подчёркивание.
		Kit.beam(G(origin, 0.12), G(origin + dir * length, 0.12), P.ink, { width = 0.25, time = igniteAt + 0.2, transparency = 0.3,
			faceCamera = false, colors = { P.inkCore, P.ink } })
		charge(p.caster, P.gold, P.pageCore, igniteAt)
		sfx("spellScribe", origin)
	end,
	ignite = function(p, ctx)
		local origin = vec(p.origin, V3())
		local dir = Kit.flatUnit(vec(p.dir, V3(0, 0, -1)))
		local length = p.length or 20
		local half = p.halfWidth or 1.8
		local a = origin + V3(0, 1.4, 0)
		local b = origin + dir * length + V3(0, 1.4, 0)
		Kit.beam(a, b, P.gold, { width = half * 2.2, time = 0.5, colors = { P.pageCore, P.gold } })
		Kit.beam(a, b, WHITE, { width = half * 0.7, time = 0.35, texture = "glow" })
		Kit.crack(G(origin), dir, length, P.gold, { width = 0.5, reveal = 0.1, time = 1.0, core = WHITE, jitter = 0.25 })
		for _, entry in ipairs(ctx.letters or {}) do
			Kit.tween(entry.label, 0.1, { TextColor3 = WHITE })
			Kit.after(0.15, function()
				Kit.tween(entry.label, 0.4, { TextTransparency = 1 })
				game:GetService("Debris"):AddItem(entry.part, 0.5)
				Kit.burst(entry.part.Position + V3(0, 0.4, 0), { texture = "spark", color = { WHITE, P.gold }, size = { 0.4, 0 },
					count = 6, life = { 0.3, 0.6 }, speed = { 4, 8 }, direction = Enum.NormalId.Top, spread = 40 })
			end)
		end
		Kit.flash(a, P.gold, 4, 0.2)
		Kit.flash(b, P.gold, 5, 0.25)
		sfx("spellFate", origin)
		shake(origin, 0.35, 0.25)
		dropCtx(ctx)
	end,
}

H.ink_hole = {
	cast = function(p, ctx)
		local to = vec(p.to)
		charge(p.caster, P.ink, P.inkCore, p.delay or 0.15)
		if to then
			Kit.circle(G(to), 2.2, P.ink, { duration = (p.flight or 0.4) + (p.delay or 0.15) + 0.1, spin = 200, count = 6, star = 5,
				inner = P.inkCore, appear = 0.1 })
		end
		sfx("spellInk", vec(p.from), 0.8)
	end,
	open = function(p, ctx)
		local center = G(vec(p.position, V3()))
		local radius = p.radius or 9
		local pull = p.pullTime or 2
		ctx.center = center
		local disc = Kit.glowSpot(center, radius, P.inkDark, pull + 0.2, { transparency = 0.05, brightness = 1 })
		local _ = disc
		local swirlA = Kit.plane(CFrame.new(center + V3(0, 0.12, 0)), radius * 2, "swirl", P.ink, { brightness = 2.5, transparency = 0.2 })
		local swirlB = Kit.plane(CFrame.new(center + V3(0, 0.14, 0)), radius * 1.3, "swirl", P.inkCore, { brightness = 3, transparency = 0.35 })
		local core = Kit.ball(center + V3(0, 0.6, 0), 1.6, P.inkDark)
		local halo = Kit.ball(center + V3(0, 0.6, 0), 3, P.ink, { Transparency = 0.6 })
		ctx.circle = Kit.circle(center, radius, P.ink, { duration = pull + 0.2, spin = 90, count = 12, inner = P.inkCore, fill = 0.85 })
		Kit.every(pull, function(k, t)
			swirlA.CFrame = CFrame.new(center + V3(0, 0.12, 0)) * CFrame.Angles(0, t * 4, 0)
			swirlB.CFrame = CFrame.new(center + V3(0, 0.14, 0)) * CFrame.Angles(0, -t * 7, 0)
			local w = 1.6 + k * 1.2 + math.sin(t * 20) * 0.1
			core.Size = V3(w, w, w)
			halo.Size = V3(w * 2, w * 2, w * 2)
			return true
		end, function()
			swirlA:Destroy()
			swirlB:Destroy()
			core:Destroy()
			halo:Destroy()
		end)
		-- Капли чернил стекаются к центру воронки.
		local drops = 0
		Kit.every(pull, function(_, t)
			local want = math.floor(t * 26)
			while drops < want do
				drops += 1
				local a = math.random() * TAU
				local from = center + V3(math.cos(a) * radius, 0.4, math.sin(a) * radius)
				local drop = Kit.ball(from, 0.35, (drops % 3 == 0) and P.inkCore or P.ink, { Transparency = 0.1 })
				Kit.tween(drop, 0.45, { CFrame = CFrame.new(center + V3(0, 0.6, 0)), Size = V3(0.1, 0.1, 0.1) }, Enum.EasingStyle.Quad,
					Enum.EasingDirection.In)
				game:GetService("Debris"):AddItem(drop, 0.5)
			end
			return true
		end)
		Kit.light(core, P.ink, 3, radius * 2, pull)
		sfx("spellInk", center)
	end,
	blast = function(p, ctx)
		local center = G(vec(p.position, ctx.center or V3()), 0.1)
		local radius = p.radius or 6
		if ctx.circle then
			ctx.circle.destroy()
		end
		Kit.explosion(center + V3(0, 1, 0), radius, P.ink, { core = P.inkCore, smokeColor = P.inkDark, ground = center,
			shakeAmount = 0.5 })
		Kit.burst(center + V3(0, 1, 0), { texture = "glow", color = { P.ink, P.inkDark }, size = { 0.9, 0.2 }, count = 40,
			life = { 0.5, 0.9 }, speed = { 12, 24 }, accel = V3(0, -30, 0), lightEmission = 0.3 })
		for i = 1, 8 do
			local dir = Kit.rotate(V3(0, 0, -1), i * 45 + math.random() * 20)
			Kit.after(0.05, function()
				Kit.glowSpot(G(center + dir * (radius * (0.5 + math.random() * 0.5))), 1 + math.random(), P.inkDark, 1.6,
					{ transparency = 0.15 })
			end)
		end
		sfx("spellInkBlast", center)
		dropCtx(ctx)
	end,
}

H.total_recall = {
	cast = function(p, ctx)
		local center = G(vec(p.position, feetOf(p.caster, V3())))
		local dir = Kit.flatUnit(vec(p.dir, V3(0, 0, -1)))
		local life = (p.stormAt or 1) + 0.4
		ctx.echoes = {}
		for i, pos in ipairs(p.echoes or {}) do
			if typeof(pos) == "Vector3" then
				local ground = G(pos, 0)
				local at = CFrame.lookAt(ground + V3(0, 3, 0), ground + V3(0, 3, 0) + dir)
				local color = (i % 2 == 0) and P.memoryAlt or P.memory
				local ghost = ghostOf(p.caster, at, color)
				table.insert(ctx.echoes, { parts = ghost, position = ground, at = at })
				Kit.circle(G(ground), 2.2, color, { duration = life, spin = 80, count = 6, inner = WHITE, appear = 0.15 })
				Kit.pillar(G(ground), 8, 1.2, color, { time = 0.4, core = WHITE })
				Kit.every(life, function(k, t)
					local rise = Kit.ease(math.clamp(t / 0.25, 0, 1), "out")
					local fade = math.clamp((k - 0.8) / 0.2, 0, 1)
					for _, entry in ipairs(ghost) do
						if entry.part.Parent then
							entry.part.CFrame = (at * CFrame.new(0, (rise - 1) * 2 + math.sin(t * 3 + i) * 0.1, 0)) * entry.rel
							entry.part.Transparency = 0.1 + 0.9 * math.max(1 - rise, fade)
						end
					end
					return true
				end, function()
					for _, entry in ipairs(ghost) do
						entry.part:Destroy()
					end
				end)
			end
		end
		Kit.circle(center, 4, P.memory, { duration = life, spin = 60, count = 10, inner = P.memoryAlt })
		charge(p.caster, P.memory, WHITE, 0.35)
		sfx("spellEcho", center)
	end,
	beams = function(p, ctx)
		for i, beam in ipairs(p.beams or {}) do
			local from = vec(beam.from)
			local dir = vec(beam.dir)
			if from and dir then
				local a = G(from, 2.6)
				local b = a + Kit.flatUnit(dir) * (beam.length or 20)
				local color = (i % 2 == 0) and P.memoryAlt or P.memory
				Kit.after((i - 1) * 0.03, function()
					Kit.beam(a, b, color, { width = 1.8, time = 0.35, colors = { WHITE, color } })
					Kit.beam(a, b, WHITE, { width = 0.5, time = 0.25, texture = "glow" })
					Kit.flash(a, color, 2.6, 0.15)
					Kit.flash(b, color, 3, 0.2)
					Kit.burst(b, { texture = "spark", color = { WHITE, color }, size = { 0.5, 0 }, count = 12, life = { 0.2, 0.4 },
						speed = { 8, 14 } })
				end)
			end
		end
		sfx("spellEchoBeam", nil, (p.salvo or 1) == 1 and 0.9 or 1)
	end,
	storm = function(p, ctx)
		local center = G(vec(p.position, feetOf(p.caster, V3())))
		local radius = p.radius or 12
		for _, echo in ipairs(ctx.echoes or {}) do
			Kit.burst(echo.position + V3(0, 2.5, 0), { texture = "star", color = { WHITE, P.memory, P.memoryAlt }, size = { 0.6, 0 },
				count = 24, life = { 0.5, 0.9 }, speed = { 4, 9 }, rotSpeed = { -300, 300 } })
			Kit.flash(echo.position + V3(0, 2.5, 0), P.memory, 4, 0.2)
		end
		Kit.ringWave(center, radius, P.memory, { time = 0.6, brightness = 4 })
		Kit.shockwave(center + V3(0, 1.5, 0), radius * 0.5, P.memoryAlt, { time = 0.4, flat = true, ground = center })
		Kit.circle(center, radius, P.memoryAlt, { duration = 1.6, spin = 30, count = 16, star = 8, inner = P.memory, fill = 0.8 })
		sfx("spellStorm", center)
		shake(center, 0.3, 0.25)
		dropCtx(ctx)
	end,
}

-- Переделки 07.11 (Королевская ловля, Призрачная стая, Грибница, стрелка и откат Остановки времени).
MageSpellFxV2.install(H, { dropCtx = dropCtx, feetOf = feetOf, charge = charge })

MageSpellFx.HANDLERS = H

-- ===== Вход =====

function MageSpellFx.handle(payload)
	local spell = H[payload.id]
	local handler = spell and spell[payload.phase]
	if not handler then
		return
	end
	local ctx = ctxOf(payload)
	local ok, err = pcall(handler, payload, ctx)
	if not ok then
		warn(("[MageSpellFx] %s.%s: %s"):format(tostring(payload.id), tostring(payload.phase), tostring(err)))
	end
	if not MageSpellFxV2.OWNED[payload.id] then
		MageSpellFxPlus.handle(payload, ctx)
	end
end

return MageSpellFx
