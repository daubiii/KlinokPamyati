--!nonstrict
-- EnemyAura (клиент)
-- Постоянные «живые» эффекты мобов нового стиля (armor/: тело R15 + пиксельная броня):
-- частицы у кристаллов и ладоней, свет, вращающиеся детали (диск-печать мага).
-- Данные — SPECS[typeId]. Подключение: EnemyFx.attach / update / detach.
--
-- Правила:
--   * всё создаётся на клиентской визуальной копии (rig.model), сервер не трогаем;
--   * далеко (view.farFx) — эмиттеры выключены, свет погашен, вращение стоит;
--   * в замахе (EnemyState = windup) эффекты разгораются по rig.progress,
--     в ударе — вспышка; после смерти всё гаснет;
--   * размеры частиц умножаются на rig.scale (Model:ScaleTo их не масштабирует).

local TEX = require(script.Parent.Parent.Lib.FxTex)

local EnemyAura = {}

local V3 = Vector3.new
local hex = Color3.fromHex

local function nseq(points)
	local keys = {}
	for _, pt in ipairs(points) do
		table.insert(keys, NumberSequenceKeypoint.new(pt[1], pt[2]))
	end
	return NumberSequence.new(keys)
end

local function scaled(points, k: number)
	local out = {}
	for i, pt in ipairs(points) do
		out[i] = { pt[1], pt[2] * k }
	end
	return nseq(out)
end

-- Точка FX_* на модели (ObjectValue в папке FX или поиском).
local function point(model, name: string): Attachment?
	local folder = model:FindFirstChild("FX")
	local link = folder and folder:FindFirstChild(name)
	if link and link:IsA("ObjectValue") and link.Value and link.Value:IsA("Attachment") then
		return link.Value
	end
	local found = model:FindFirstChild(name, true)
	return (found and found:IsA("Attachment")) and found or nil
end

-- o: tex, color(s), size{{t,v}}, transp{{t,v}}, life{a,b}, speed{a,b}, spread, accel, drag, light, rate,
--    locked, rot, orient ("vp" — плоско поперёк скорости), dir (NormalId), zoff
local function emitter(parent: Instance, name: string, o, k: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = o.tex or TEX.glow
	e.Color = typeof(o.color) == "ColorSequence" and o.color or ColorSequence.new(o.color or Color3.new(1, 1, 1))
	e.Size = scaled(o.size or { { 0, 0.3 }, { 1, 0 } }, k)
	e.Transparency = nseq(o.transp or { { 0, 0.2 }, { 1, 1 } })
	e.Lifetime = NumberRange.new(o.life[1], o.life[2])
	e.Speed = NumberRange.new((o.speed or { 0, 0 })[1] * k, (o.speed or { 0, 0 })[2] * k)
	e.SpreadAngle = Vector2.new(o.spread or 0, o.spread or 0)
	e.Acceleration = (o.accel or Vector3.zero) * k
	e.Drag = o.drag or 0
	e.LightEmission = o.light or 1
	e.LightInfluence = 0
	e.Brightness = o.bright or 1.4
	e.LockedToPart = o.locked or false
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-(o.rot or 30), o.rot or 30)
	e.EmissionDirection = o.dir or Enum.NormalId.Top
	if o.orient == "vp" then
		e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	end
	if o.zoff then
		e.ZOffset = o.zoff
	end
	e.Rate = o.rate or 0
	e.Enabled = true
	e.Parent = parent
	return e
end

local LAV = hex("#B3A4FF")
local LAV_W = hex("#E6E0FF")
local ICE = hex("#BFE8FF")
local PAPER = hex("#E7DCC0")

-- ===== Описания =====
-- Каждая запись: build(rig, aura, k) — создаёт эффекты и кладёт в aura.items
-- { emitter, base, charge } (Rate в покое и в полном замахе); aura.lights — { light, base, charge }.

local SPECS = {}

SPECS.seal_mage = function(rig, aura, k)
	local model = rig.model
	-- Кристалл посоха: искры-мотыльки, мягкий ореол, свет.
	local tip = point(model, "FX_WeaponTip")
	if tip then
		table.insert(aura.items, {
			emitter = emitter(tip, "AuraMotes", {
				tex = TEX.star, color = ColorSequence.new(LAV_W, LAV), size = { { 0, 0.22 }, { 0.5, 0.16 }, { 1, 0 } },
				transp = { { 0, 0.1 }, { 0.7, 0.3 }, { 1, 1 } }, life = { 0.5, 1.0 }, speed = { 0.4, 1.1 }, spread = 180,
				accel = V3(0, 0.8, 0), drag = 2.5, rate = 7, rot = 90,
			}, k),
			base = 7, charge = 34, burst = 24,
		})
		table.insert(aura.items, {
			emitter = emitter(tip, "AuraHalo", {
				tex = TEX.glow, color = ICE, size = { { 0, 0.9 }, { 1, 1.3 } }, transp = { { 0, 0.6 }, { 1, 1 } },
				life = { 0.35, 0.5 }, rate = 5, locked = true,
			}, k),
			base = 5, charge = 16,
		})
		local light = Instance.new("PointLight")
		light.Name = "AuraLight"
		light.Color = LAV
		light.Range = 9 * k
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = tip
		table.insert(aura.lights, { light = light, base = 1.2, charge = 3.2, flicker = 0.25 })
	end
	-- Талисманы на посохе: изредка отрываются клочки бумаги и, кружась, падают.
	local paper = point(model, "FX_Talisman")
	if paper then
		table.insert(aura.items, {
			emitter = emitter(paper, "AuraPaper", {
				tex = TEX.rock, color = PAPER, size = { { 0, 0.14 }, { 1, 0.1 } }, transp = { { 0, 0 }, { 0.8, 0 }, { 1, 1 } },
				life = { 1.4, 2.2 }, speed = { 0.2, 0.5 }, spread = 70, accel = V3(0, -1.2, 0), drag = 1.2, rate = 0.8, rot = 240, light = 0, bright = 1,
			}, k),
			base = 0.8, charge = 4,
		})
	end
	-- Левая ладонь: тлеющий знак в покое, вихрь при касте.
	local palm = point(model, "FX_LeftPalm")
	if palm then
		table.insert(aura.items, {
			emitter = emitter(palm, "AuraPalm", {
				tex = TEX.swirl, color = LAV, size = { { 0, 0.2 }, { 1, 0.5 } }, transp = { { 0, 0.5 }, { 1, 1 } },
				life = { 0.4, 0.6 }, speed = { 0.1, 0.3 }, spread = 40, dir = Enum.NormalId.Bottom, rate = 1.5, rot = 180, locked = true,
			}, k),
			base = 1.5, charge = 22, burst = 10,
		})
	end
	-- Диск-печать за спиной: кольца-импульсы и искры по ободу.
	local halo = point(model, "FX_Halo")
	if halo then
		table.insert(aura.items, {
			emitter = emitter(halo, "AuraRing", {
				tex = TEX.ring, color = LAV, size = { { 0, 1.5 }, { 1, 2.1 } }, transp = { { 0, 1 }, { 0.2, 0.75 }, { 1, 1 } },
				life = { 1.4, 1.6 }, speed = { 0.01, 0.01 }, dir = Enum.NormalId.Back, orient = "vp", rate = 0.7, rot = 0, locked = true,
			}, k),
			base = 0.7, charge = 4, burst = 2,
		})
		table.insert(aura.items, {
			emitter = emitter(halo, "AuraRim", {
				tex = TEX.spark, color = ColorSequence.new(LAV_W, LAV), size = { { 0, 0.16 }, { 1, 0 } }, transp = { { 0, 0.2 }, { 1, 1 } },
				life = { 0.6, 0.9 }, speed = { 1.6, 1.8 }, spread = 180, drag = 5, rate = 5, rot = 0, locked = true,
			}, k),
			base = 5, charge = 26,
		})
	end
	-- Вращающийся диск: меш "UpperTorso__weapondisc" на своём Motor6D (WeaponGrip);
	-- светящиеся руны диска переваривают к нему, чтобы вращались вместе.
	local weapon = model:FindFirstChild("Weapon")
	local disc = weapon and weapon:FindFirstChild("UpperTorso__weapondisc", true)
	local grip = disc and disc:FindFirstChild("WeaponGrip")
	if disc and grip then
		local glow = model:FindFirstChild("Glow")
		local runes = glow and glow:FindFirstChild("UpperTorso__glowdisc", true)
		if runes then
			for _, c in ipairs(runes:GetChildren()) do
				if c:IsA("WeldConstraint") then
					c:Destroy()
				end
			end
			local w = Instance.new("WeldConstraint")
			w.Part0 = disc
			w.Part1 = runes
			w.Parent = runes
		end
		aura.spin = { motor = grip, angle = 0, base = 0.55, charge = 6.0 }
	end
end

-- ===== Жизненный цикл =====

function EnemyAura.attach(rig)
	local typeId = rig.server and rig.server:GetAttribute("EnemyType")
	local build = typeId and SPECS[typeId]
	if not build or not rig.model then
		return
	end
	local aura = { items = {}, lights = {}, spin = nil, off = false, lastState = nil, level = 0 }
	local ok, err = pcall(build, rig, aura, rig.scale or 1)
	if not ok then
		warn("[EnemyAura] " .. tostring(typeId) .. ": " .. tostring(err))
	end
	rig.aura = aura
end

function EnemyAura.detach(rig)
	local aura = rig.aura
	if not aura then
		return
	end
	rig.aura = nil
	for _, item in ipairs(aura.items) do
		if item.emitter then
			item.emitter:Destroy()
		end
	end
	for _, l in ipairs(aura.lights) do
		l.light:Destroy()
	end
end

local function setOff(aura, off: boolean)
	if aura.off == off then
		return
	end
	aura.off = off
	for _, item in ipairs(aura.items) do
		item.emitter.Enabled = not off
	end
	for _, l in ipairs(aura.lights) do
		l.light.Enabled = not off
	end
end

function EnemyAura.update(rig, dt: number, now: number, far: boolean)
	local aura = rig.aura
	if not aura then
		return
	end
	local dead = rig.dead == true
	setOff(aura, far or dead or (rig.hidden == true))
	if aura.off then
		return
	end
	-- Уровень «заряда»: замах — растёт с прогрессом, удар — 1, иначе спадает.
	local state = rig.state
	local target = 0
	if state == "windup" then
		target = 0.25 + 0.75 * (rig.progress or 0)
	elseif state == "strike" then
		target = 1
	end
	local rate = target > aura.level and 10 or 3
	aura.level += (target - aura.level) * math.min(1, dt * rate)
	local lv = aura.level
	if state ~= aura.lastState then
		if state == "strike" then
			for _, item in ipairs(aura.items) do
				if item.burst then
					item.emitter:Emit(item.burst)
				end
			end
		end
		aura.lastState = state
	end
	for _, item in ipairs(aura.items) do
		item.emitter.Rate = item.base + (item.charge - item.base) * lv
	end
	for i, l in ipairs(aura.lights) do
		local flick = 1 + (l.flicker or 0) * math.sin(now * 7.3 + i * 1.7) * math.sin(now * 2.9)
		l.light.Brightness = (l.base + (l.charge - l.base) * lv) * flick
	end
	local spin = aura.spin
	if spin and not (rig.fx and rig.fx.spawn) then
		spin.angle = (spin.angle + dt * (spin.base + (spin.charge - spin.base) * lv * lv)) % (math.pi * 2)
		spin.motor.Transform = CFrame.Angles(0, 0, spin.angle)
	end
end

EnemyAura.SPECS = SPECS

return EnemyAura
