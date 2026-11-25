--!nonstrict
-- AbilityFxForge (клиент)
-- Эффекты оружия этажа 4 «Литейные» (kind = "forge"): Разлив (лужи расплава), Перекал (нова и жар в руке),
-- Наковальня с небес, Дыхание горна (струя пламени), Шлаковый серп (круговые дуги и комья шлака),
-- Заливка (волны металла) и пассивки «Закалка», «Угли», «Шлаковая корка», «Отливка» (ступени клинка).
-- Сервер решает урон и цели; здесь только картинка. Шаблоны — FX.Forge/* (Shared/Fx/FxWeapons345).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local K = require(script.Parent.AbilityFx345Kit)
local FxKit = K.FxKit
local V3 = Vector3.new

local AbilityFxForge = {}

local ORANGE = K.color("#FF7A2B")
local YELLOW = K.color("#FFC857")
local WHITE = K.color("#FFF1C2")
local RED = K.color("#E2572B")
local IRON = K.color("#3A3436")
local IRON_HI = K.color("#6B6266")

-- ===== Разлив =====

local pools = {} -- [caster][index] = handle

local function spillPour(payload)
	local origin = K.ground(payload.position, 0)
	local forward = K.flat(payload.direction)
	local lip = origin + forward * 1.6 + V3(0, 2.4, 0)
	K.sound("forgeSpillPour", lip)
	FxKit.spawn("Forge/SpillPour", CFrame.lookAt(lip, lip + forward + V3(0, -0.6, 0)))
	-- Струя-лента: расплав льётся дугой вперёд.
	K.ribbon("Forge/Ribbon", YELLOW, 0.9, 0.35, function(k)
		local p = lip + forward * (k * 5) + V3(0, -k * k * 2.2, 0)
		return p + V3(0, 0.3, 0), p - V3(0, 0.3, 0)
	end)
end

local function spillErupt(payload)
	local center = K.ground(payload.position, 0.12)
	local radius = payload.radius or 2.6
	K.sound("forgeErupt", center)
	K.shake(center, 0.18, 0.18)
	FxKit.spawn("Forge/SpillErupt", CFrame.new(center), { radius = radius })
	local handle = FxKit.spawn("Forge/SpillPool", CFrame.new(center), { radius = radius, life = payload.burnTime or 3 })
	pools[payload.caster] = pools[payload.caster] or {}
	pools[payload.caster][payload.index or 1] = handle
end

local function spillEnd(payload)
	local center = K.ground(payload.position, 0.2)
	FxKit.spawn("Forge/SpillEnd", CFrame.new(center), { radius = payload.radius or 2.6 })
	K.sound("forgeSteamSoft", center)
	for _, set in pairs(pools) do
		local handle = set[payload.index or 1]
		if handle and handle.root and (handle.root.Position - center).Magnitude < 1.5 then
			handle.stop()
			set[payload.index or 1] = nil
		end
	end
end

-- ===== Перекал =====

local function handAttachment(caster)
	local character = caster and caster.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if not hand then
		return nil
	end
	local a = Instance.new("Attachment")
	a.Name = "Fx345Hand"
	a.Parent = hand
	return a
end

local function overheatNova(payload)
	local center = K.ground(payload.position, 0.15)
	local radius = payload.radius or 5
	K.sound("forgeOverheat", center)
	K.shake(center, 0.28, 0.25)
	FxKit.spawn("Forge/OverheatNova", CFrame.new(center), { radius = radius })
	FxKit.shockwave(center + V3(0, 1, 0), radius)
	local duration = payload.duration or 6
	local hand = handAttachment(payload.caster)
	if hand then
		FxKit.attach("Forge/OverheatAura", hand, { life = duration })
		Debris:AddItem(hand, duration + 1.5)
	end
	-- Клинок раскаляется: неон-прожилки ярче на время баффа.
	local weapon = K.weapon(payload.caster)
	if weapon then
		local h = Instance.new("Highlight")
		h.Name = "Fx345Overheat"
		h.FillColor = ORANGE
		h.OutlineColor = YELLOW
		h.FillTransparency = 0.55
		h.OutlineTransparency = 0.2
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = weapon
		task.delay(duration, function()
			if h.Parent then
				K.tween(h, 0.4, { FillTransparency = 1, OutlineTransparency = 1 })
				Debris:AddItem(h, 0.45)
			end
		end)
	end
end

local function overheatBurst(payload)
	local at = K.ground(payload.position, 1)
	K.sound("forgeBurst", at)
	FxKit.spawn("Forge/OverheatBurst", CFrame.new(at), { radius = payload.radius or 3 })
end

-- ===== Наковальня с небес =====

local anvils = {} -- [caster] = model

-- Наковальня из деталей: основание, талия, тело, рог; раскалённые кромки.
local function makeAnvil(cframe: CFrame)
	local model = Instance.new("Model")
	model.Name = "SkyAnvil"
	local base = K.solid(V3(3.2, 0.9, 2.2), cframe * CFrame.new(0, 0.45, 0), IRON, Enum.Material.Metal, model)
	K.solid(V3(1.8, 1.0, 1.3), cframe * CFrame.new(0, 1.4, 0), IRON, Enum.Material.Metal, model)
	K.solid(V3(4.2, 1.1, 1.9), cframe * CFrame.new(0, 2.45, 0), IRON_HI, Enum.Material.Metal, model)
	local horn = K.solid(V3(1.6, 0.8, 1.2), cframe * CFrame.new(2.7, 2.6, 0), IRON_HI, Enum.Material.Metal, model)
	K.solid(V3(0.9, 0.5, 0.7), cframe * CFrame.new(3.8, 2.75, 0), IRON_HI, Enum.Material.Metal, model)
	K.solid(V3(4.25, 0.14, 1.95), cframe * CFrame.new(0, 3.05, 0), YELLOW, Enum.Material.Neon, model)
	K.solid(V3(3.25, 0.1, 2.25), cframe * CFrame.new(0, 0.05, 0), ORANGE, Enum.Material.Neon, model)
	model.PrimaryPart = base
	model.Parent = FxKit.folder()
	-- След: две точки по краям тела.
	local a0 = Instance.new("Attachment")
	a0.Position = V3(-1.9, 2, 0)
	a0.Parent = base
	local a1 = Instance.new("Attachment")
	a1.Position = V3(1.9, 2, 0)
	a1.Parent = base
	local trail = FxKit.clone("Forge/AnvilTrail")
	if trail and trail:IsA("Trail") then
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Enabled = true
		trail.Parent = base
	end
	local glow = Instance.new("PointLight")
	glow.Color = ORANGE
	glow.Brightness = 2
	glow.Range = 12
	glow.Parent = horn
	return model
end

local function anvilMark(payload)
	local point = K.ground(payload.position, 0)
	local time = payload.time or 0.8
	K.sound("forgeAnvilWhistle", point)
	FxKit.spawn("Forge/AnvilMark", CFrame.new(point + V3(0, 0.15, 0)), { radius = payload.radius or 5.5, life = time })
	local yaw = CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local high = 42
	local model = makeAnvil(CFrame.new(point + V3(0, high, 0)) * yaw)
	anvils[payload.caster] = model
	local spin = math.random() < 0.5 and -1 or 1
	K.loop(time, function(t)
		if not model.Parent then
			return false
		end
		local k = math.clamp(t / time, 0, 1)
		local y = high * (1 - k * k)
		local wobble = CFrame.Angles(math.rad(8 * (1 - k)) * spin, math.rad(20 * (1 - k)) * spin, 0)
		model:PivotTo(CFrame.new(point + V3(0, y, 0)) * yaw * wobble)
		return k < 1
	end)
	Debris:AddItem(model, time + 4)
end

local function anvilImpact(payload)
	local point = K.ground(payload.position, 0.1)
	local radius = payload.radius or 5.5
	K.sound("forgeAnvilImpact", point)
	K.shake(point, 0.7, 0.45)
	FxKit.spawn("Forge/AnvilImpact", CFrame.new(point), { radius = radius })
	FxKit.shockwave(point + V3(0, 0.8, 0), payload.ringRadius or radius * 1.4)
	FxKit.spawn("Common/Dust", CFrame.new(point), { scale = radius / 7 })
	local model = anvils[payload.caster]
	anvils[payload.caster] = nil
	if model and model.Parent then
		model:PivotTo(CFrame.new(point - V3(0, 0.1, 0)) * (model:GetPivot() - model:GetPivot().Position))
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Trail") then
				d.Enabled = false
			end
		end
		-- Стоит секунду, остывает и уходит в землю.
		task.delay(1, function()
			if model.Parent then
				local pivot = model:GetPivot()
				K.loop(0.8, function(t)
					if not model.Parent then
						return false
					end
					model:PivotTo(pivot * CFrame.new(0, -t * 4, 0))
					return true
				end)
				K.dissolve(model, 0.8)
			end
		end)
	end
end

-- ===== Дыхание горна =====

local function breathStart(payload)
	local root = K.casterRoot(payload.caster)
	if not root then
		return
	end
	local duration = payload.duration or 1.6
	K.sound("forgeBreath", root.Position)
	local a = Instance.new("Attachment")
	a.Name = "Fx345Breath"
	a.Position = V3(0, 0.7, -1.6)
	a.Parent = root
	local handle = FxKit.attach("Forge/BreathJet", a, { life = duration })
	-- Ширину конуса — из halfAngle (шаблон нарисован под 35°).
	if handle and payload.halfAngle then
		for _, item in ipairs(handle.items) do
			if item:IsA("ParticleEmitter") then
				local s = item.SpreadAngle
				local k = math.clamp(payload.halfAngle / 35, 0.5, 2)
				item.SpreadAngle = Vector2.new(s.X * k, s.Y * k)
			end
		end
	end
	Debris:AddItem(a, duration + 1.5)
end

local function breathTick(payload)
	if (payload.hits or 0) > 0 and (payload.index or 1) % 2 == 1 then
		local root = K.casterRoot(payload.caster)
		K.sound("forgeSizzle", root and root.Position)
	end
end

-- ===== Угли =====

local function ember(payload)
	local part = K.modelPart(payload.model)
	if not part then
		return
	end
	local count = payload.count or 1
	FxKit.spawn("Forge/Ember", CFrame.new(part.Position), { scale = 1 + count * 0.15 })
	K.onModel("burning", payload.model, "Forge/Burning", 2.5)
	if count >= 3 then
		K.sound("forgeEmberHigh", part.Position)
	end
end

local function emberBurst(payload)
	local at = payload.position or (K.modelPart(payload.model) and K.modelPart(payload.model).Position)
	if not at then
		return
	end
	K.offModel("burning", payload.model)
	K.sound("forgeEmberBurst", at)
	K.shake(at, 0.15, 0.15)
	FxKit.spawn("Forge/EmberBurst", CFrame.new(K.ground(at, 0.3)), { radius = payload.radius or 3 })
end

-- ===== Шлаковый серп =====

local function slagSpin(payload)
	local center = K.ground(payload.position, 0.15)
	local radius = payload.radius or 7.2
	local root = K.casterRoot(payload.caster)
	local forward = root and K.flat(root.CFrame.LookVector) or V3(0, 0, -1)
	local spin = (payload.index or 1) % 2 == 1 and 1 or -1
	K.sound("forgeSlagSpin", center)
	FxKit.spawn("Forge/SlagSpin", CFrame.new(center), { radius = radius })
	K.arc(center, forward, "Forge/Ribbon", ORANGE, 0.26, 360 * spin, radius * 0.35, radius * 0.92, 1.6, 0.6)
	K.arc(center, forward, "Forge/Ribbon", WHITE, 0.22, 330 * spin, radius * 0.5, radius * 0.75, 1.9, 0.3)
end

local function slagGlobs(payload)
	local from = K.ground(payload.position, 2)
	local flight = payload.flight or 0.45
	local played = false
	for i, point in ipairs(payload.points or {}) do
		local land = K.ground(point, 0.12)
		local fly = K.flyer("Forge/SlagGlob", CFrame.new(from), { life = flight + 0.2 })
		local peak = 3 + (i % 3)
		K.loop(flight, function(t)
			local k = math.clamp(t / flight, 0, 1)
			local p = from:Lerp(land, k) + V3(0, math.sin(k * math.pi) * peak, 0)
			fly.move(CFrame.new(p))
			if k >= 1 then
				fly.stop(0.5)
				FxKit.spawn("Forge/SlagPool", CFrame.new(land), { radius = payload.radius or 2.2, life = payload.time or 3 })
				if not played then
					played = true
					K.sound("forgeSlagLand", land)
				end
				return false
			end
			return true
		end)
	end
end

-- ===== Закалка, корка =====

local function temperStack(payload)
	local at = K.weaponTip(payload.caster)
	if not at then
		return
	end
	FxKit.spawn("Forge/TemperStack", CFrame.new(at), { scale = 1 + (payload.count or 1) * 0.12 })
	K.sound("forgeTemperStack", at)
end

local function temperRing(payload)
	local center = K.ground(payload.position, 0.15)
	K.sound("forgeTemper", center)
	K.shake(center, 0.2, 0.2)
	FxKit.spawn("Forge/TemperRing", CFrame.new(center), { radius = payload.radius or 4.5 })
	FxKit.shockwave(center + V3(0, 1, 0), payload.radius or 4.5)
end

local function crust(payload)
	local part = K.modelPart(payload.model)
	local at = part and part.Position or payload.position
	if at then
		FxKit.spawn("Forge/Crust", CFrame.new(at))
		K.sound("forgeCrust", at)
	end
end

-- ===== Отливка: ступени незавершённого клинка =====
-- Неон-сегменты G2/G3/G4 меша unfinished_blade видны по числу ступеней (атрибут игрока CastStage).

local STAGE_PARTS = { "G2_unfinished_blade", "G3_unfinished_blade", "G4_unfinished_blade" }

local function applyStage(player)
	local weapon = K.weapon(player)
	if not weapon or player:GetAttribute("WeaponId") ~= "unfinished_blade" then
		return
	end
	local stage = player:GetAttribute("CastStage") or 0
	for _, d in ipairs(weapon:GetDescendants()) do
		if d:IsA("BasePart") then
			local name = d:GetAttribute("MeshName")
			for i, wanted in ipairs(STAGE_PARTS) do
				if name == wanted then
					d.LocalTransparencyModifier = (stage >= i) and 0 or 1
				end
			end
		end
	end
end

local stageLoop = false
local function ensureStageLoop()
	if stageLoop then
		return
	end
	stageLoop = true
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(applyStage, player)
			end
		end
	end)
end
ensureStageLoop()

local function castStage(payload)
	local caster = payload.caster
	pcall(applyStage, caster)
	local at = K.weaponTip(caster)
	if not at then
		return
	end
	if payload.grew then
		FxKit.spawn("Forge/StageUp", CFrame.new(at), { scale = 1 + (payload.stage or 1) * 0.2 })
		K.sound("forgeStageUp", at)
	else
		K.sound("forgeStageDown", at)
	end
end

-- ===== Заливка =====

local function pourStart(payload)
	local center = K.ground(payload.position, 0.15)
	local life = (payload.waves or 3) * (payload.interval or 0.35) + 0.4
	K.sound("forgePourStart", center)
	FxKit.spawn("Forge/PourCore", CFrame.new(center), { radius = 2 + (payload.stage or 0) * 0.4, life = life })
end

local function pourWave(payload)
	local center = K.ground(payload.position, 0.15)
	local radius = payload.radius or 4.5
	K.sound("forgePourWave", center)
	K.shake(center, 0.18 + (payload.index or 1) * 0.06, 0.2)
	FxKit.spawn("Forge/PourWave", CFrame.new(center), { radius = radius })
	FxKit.shockwave(center + V3(0, 0.6, 0), radius)
	local root = K.casterRoot(payload.caster)
	local forward = root and K.flat(root.CFrame.LookVector) or V3(0, 0, -1)
	K.arc(center, forward, "Forge/Ribbon", (payload.index or 1) % 2 == 1 and YELLOW or RED, 0.3, 360, radius * 0.8, radius, 0.4, 0)
end

local function pourSteam(payload)
	local center = K.ground(payload.position, 0.15)
	K.sound("forgeSteam", center)
	FxKit.spawn("Forge/PourSteam", CFrame.new(center), { radius = payload.radius or 6.5 })
end

AbilityFxForge.handlers = {
	forge = {
		spillPour = spillPour,
		spillErupt = spillErupt,
		spillEnd = spillEnd,
		overheatNova = overheatNova,
		overheatBurst = overheatBurst,
		anvilMark = anvilMark,
		anvilImpact = anvilImpact,
		breathStart = breathStart,
		breathTick = breathTick,
		ember = ember,
		emberBurst = emberBurst,
		slagSpin = slagSpin,
		slagGlobs = slagGlobs,
		temperStack = temperStack,
		temperRing = temperRing,
		crust = crust,
		castStage = castStage,
		pourStart = pourStart,
		pourWave = pourWave,
		pourSteam = pourSteam,
	},
}

return AbilityFxForge
