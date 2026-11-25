--!nonstrict
-- AttackFxController (клиент)
-- Эффекты боя: след клинка, искры и числа урона, вспышка парирования,
-- ударные волны, оглушение, рывок, лечение, способности оружия.
-- Всё клиентское: сервер лишь присылает события (EnemyEvent, CombatFeedback,
-- AbilityUsed), эффекты никого не бьют и ничего не решают.
--
-- Цвета — только из Palette.Fx. Голубой (память) для ударов не используется.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Palette = require(Shared.Config.Palette)
local Rarities = require(Shared.Config.Rarities)
local Net = require(Shared.Net.Net)

local Bus = require(script.Parent.Parent.Lib.Bus)
local FxKit = require(script.Parent.Parent.Lib.FxKit)
local Ui = require(script.Parent.Parent.Lib.Ui)
local PlayerAnimator = require(script.Parent.PlayerAnimator)
local EnemyVisualController = require(script.Parent.EnemyVisualController)
local EnemyFx = require(script.Parent.EnemyFx)

local AttackFxController = {}

local player = Players.LocalPlayer
local V3 = Vector3.new

local fxFolder

local function folder()
	if fxFolder and fxFolder.Parent then
		return fxFolder
	end
	fxFolder = Workspace:FindFirstChild("KlinokFx")
	if not fxFolder then
		fxFolder = Instance.new("Folder")
		fxFolder.Name = "KlinokFx"
		fxFolder.Parent = Workspace
	end
	return fxFolder
end

local function localRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart"), character
end

local function fxPart(size: Vector3, color: Color3, transparency: number?)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.Transparency = transparency or 0
	part.Parent = folder()
	return part
end

-- ===== Эмиттеры-пулы =====

local emitters = {}

local function emitter(name: string, configure)
	local entry = emitters[name]
	if entry and entry.part.Parent then
		return entry
	end
	local part = Instance.new("Part")
	part.Name = "Emitter_" .. name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = V3(0.2, 0.2, 0.2)
	part.Parent = folder()
	local particle = Instance.new("ParticleEmitter")
	particle.Rate = 0
	particle.Enabled = false
	configure(particle)
	particle.Parent = part
	entry = { part = part, emitter = particle }
	emitters[name] = entry
	return entry
end

local function burst(name: string, position: Vector3, count: number)
	local entry = emitters[name]
	if not entry then
		return
	end
	entry.part.CFrame = CFrame.new(position)
	entry.emitter:Emit(count)
end

-- Текстуры из шаблонов FX (как у способностей), иначе штатные.
local function templateTexture(path: string, emitterName: string): string?
	local template = FxKit.template(path)
	local source = template and template:FindFirstChild(emitterName, true)
	return source and source:IsA("ParticleEmitter") and source.Texture or nil
end

local function setupEmitters()
	local spark = templateTexture("Common/Flash", "Sparks")
	local smoke = templateTexture("Common/Dust", "Smoke")
	local glow = templateTexture("Common/Flash", "Glow")
	emitter("sparks", function(p)
		p.Texture = spark or p.Texture
		p.Orientation = Enum.ParticleOrientation.VelocityParallel
		p.Lifetime = NumberRange.new(0.18, 0.34)
		p.Speed = NumberRange.new(14, 28)
		p.SpreadAngle = Vector2.new(180, 180)
		p.Acceleration = V3(0, -40, 0)
		p.LightEmission = 1
		p.Color = ColorSequence.new(Palette.Fx.hit, Palette.Fx.warn)
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.34), NumberSequenceKeypoint.new(1, 0) })
		p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	end)
	emitter("dust", function(p)
		p.Texture = smoke or p.Texture
		p.Rotation = NumberRange.new(0, 360)
		p.Lifetime = NumberRange.new(0.5, 0.9)
		p.Speed = NumberRange.new(4, 10)
		p.SpreadAngle = Vector2.new(180, 60)
		p.Acceleration = V3(0, -3, 0)
		p.Color = ColorSequence.new(Palette.Fx.dust)
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 2.2) })
		p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	end)
	emitter("chips", function(p)
		p.Lifetime = NumberRange.new(0.35, 0.6)
		p.Speed = NumberRange.new(10, 22)
		p.SpreadAngle = Vector2.new(180, 180)
		p.Acceleration = V3(0, -50, 0)
		p.RotSpeed = NumberRange.new(-400, 400)
		p.LightEmission = 0.6
		p.Color = ColorSequence.new(Palette.Fx.parry)
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.38), NumberSequenceKeypoint.new(1, 0.1) })
		p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	end)
	emitter("danger", function(p)
		p.Texture = spark or p.Texture
		p.Orientation = Enum.ParticleOrientation.VelocityParallel
		p.Lifetime = NumberRange.new(0.3, 0.6)
		p.Speed = NumberRange.new(10, 24)
		p.SpreadAngle = Vector2.new(180, 180)
		p.Acceleration = V3(0, -20, 0)
		p.LightEmission = 1
		p.Color = ColorSequence.new(Palette.Fx.danger, Palette.Fx.warn)
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	end)
	emitter("heal", function(p)
		p.Texture = glow or p.Texture
		p.Lifetime = NumberRange.new(0.7, 1.1)
		p.Speed = NumberRange.new(1, 3)
		p.SpreadAngle = Vector2.new(60, 180)
		p.Acceleration = V3(0, 6, 0)
		p.LightEmission = 0.8
		p.Color = ColorSequence.new(Palette.Fx.heal)
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.34), NumberSequenceKeypoint.new(1, 0) })
		p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	end)
end

-- ===== Кольцо и вспышка (шаблоны FX.Enemy.Ring / Flash) =====

local function tune(handle, color: Color3, time: number)
	if not handle then
		return
	end
	for _, d in ipairs(handle.root:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			d.Color = ColorSequence.new(color)
			d.Lifetime = NumberRange.new(time)
		end
	end
end

local function ring(position: Vector3, radius: number, color: Color3, time: number, _thickness: number?)
	tune(FxKit.spawn("Enemy/Ring", CFrame.new(position.X, position.Y + 0.2, position.Z), { radius = radius }), color, time)
end

-- Вспышка на месте попадания.
local function flash(position: Vector3, size: number, color: Color3, time: number)
	tune(FxKit.spawn("Enemy/Flash", CFrame.new(position), { scale = size * 2.4 }), color, time)
end

-- ===== Числа урона =====

-- Числа урона рисуются в экранном пространстве (как полоски врагов):
-- пиксельный шрифт, подскок, контрудар — крупнее и золотом.
local numberGui
local numberPool = {}
local numberCursor = 0
local NUMBER_POOL = 16

local function numberSlot()
	numberCursor = numberCursor % NUMBER_POOL + 1
	local slot = numberPool[numberCursor]
	if slot and slot.label.Parent then
		return slot
	end
	if not numberGui or not numberGui.Parent then
		numberGui = Ui.screen("KlinokDamageNumbers", 4)
	end
	local label = Ui.pixel(numberGui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(160, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 20,
		Visible = false,
		stroke = 3,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = label
	slot = { label = label, scale = scale, token = 0 }
	numberPool[numberCursor] = slot
	return slot
end

local function damageNumber(position: Vector3, amount: number, kind: string)
	local slot = numberSlot()
	slot.token += 1
	local token = slot.token
	local big = kind == "counter" or kind == "crit"
	slot.label.Text = ("%d%s"):format(math.floor(amount + 0.5), big and "!" or "")
	slot.label.TextColor3 = big and Palette.Env.gold or Palette.Material.bladeEdge
	slot.label.TextTransparency = 0
	local labelStroke = slot.label:FindFirstChildOfClass("UIStroke")
	if labelStroke then
		labelStroke.Transparency = 0
	end
	slot.label.TextSize = big and 28 or 20

	local jitter = V3((math.random() - 0.5) * 1.6, 0, (math.random() - 0.5) * 1.6)
	local start = position + jitter
	slot.scale.Scale = 1.8
	TweenService:Create(slot.scale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	task.spawn(function()
		local startedAt = os.clock()
		while os.clock() - startedAt < 0.8 and slot.token == token do
			local k = (os.clock() - startedAt) / 0.8
			local world = start + V3(0, 3 * (1 - (1 - k) ^ 2), 0)
			local camera = Workspace.CurrentCamera
			local point, onScreen = camera:WorldToViewportPoint(world)
			local guiScale = numberGui:FindFirstChild("Scale")
			local s = guiScale and guiScale.Scale or 1
			slot.label.Visible = onScreen and point.Z > 0
			slot.label.Position = UDim2.fromOffset(point.X / s, point.Y / s)
			local fade = math.clamp((k - 0.55) / 0.45, 0, 1)
			slot.label.TextTransparency = fade
			local stroke = slot.label:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = fade
			end
			RunService.RenderStepped:Wait()
		end
		if slot.token == token then
			slot.label.Visible = false
		end
	end)
end

-- ===== След клинка =====

local trailCache = {} -- [weaponModel] = Trail

local function weaponModel()
	local character = player.Character
	if not character then
		return nil
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "EquippedWeapon" then
			return descendant
		end
	end
	return nil
end

local function trailFor(model)
	local cached = trailCache[model]
	if cached and cached.Parent then
		return cached
	end
	local root = model.PrimaryPart
	local base = root and root:FindFirstChild("BladeBase")
	local tip = root and root:FindFirstChild("BladeTip")
	if not base or not tip then
		return nil
	end
	local rarityId = model:GetAttribute("RarityId") or "common"
	local color = Palette.Material.bladeEdge
	if rarityId ~= "common" then
		color = Palette.Material.bladeEdge:Lerp(Rarities.color(rarityId), 0.55)
	end
	local trail = Instance.new("Trail")
	trail.Attachment0 = base
	trail.Attachment1 = tip
	trail.Lifetime = 0.2
	trail.MinLength = 0.04
	trail.FaceCamera = true
	trail.LightEmission = 0.9
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.4) })
	trail.Enabled = false
	trail.Parent = root
	trailCache[model] = trail
	return trail
end

-- Серп взмаха (как в Pixel Blade — крупный светящийся след перед героем):
-- след FX.Combat.Slash между внутренней и внешней точкой, которые за 0,08 с
-- проходят дугу удара. Удары 1–2 — горизонтальные (в разные стороны),
-- финал серии — вертикальный, крупнее и тёплым цветом.
local SLASH = {
	sword = { radius = 5.2, span = 150, width = 1.6 },
	hammer = { radius = 5.6, span = 120, width = 2 },
	dagger = { radius = 4.0, span = 140, width = 1.3 },
}
local SLASH_SWEEP = 0.08

local FLOOR2_SLASH = {
	garden_machete = { color = Color3.fromHex("#86BA6C"), radius = 5.1, span = 138, width = 1.55, reach = 2.8 },
	reed_saber = { color = Color3.fromHex("#5FD0C0"), radius = 4.7, span = 174, width = 1.2, reach = 3.2 },
	mud_mallet = { color = Color3.fromHex("#B6D84A"), radius = 5.5, span = 124, width = 2.1, reach = 2.4 },
	thorn_blade = { color = Color3.fromHex("#D97A88"), radius = 5.0, span = 158, width = 1.45, reach = 3.0 },
	root_hammer = { color = Color3.fromHex("#4C8A4F"), radius = 5.4, span = 132, width = 2.3, reach = 2.5 },
	reaper_blade = { color = Color3.fromHex("#B8F2E6"), radius = 5.8, span = 184, width = 2.0, reach = 3.4 },
	tidal_hammer = { color = Color3.fromHex("#5FD0C0"), radius = 5.8, span = 142, width = 2.4, reach = 2.6 },
	gardener_shears = { color = Color3.fromHex("#D97A88"), radius = 4.8, span = 168, width = 1.3, reach = 3.1 },
}

local function playerSlash(combo: number, typeId: string, weaponId: string?)
	local root = localRoot()
	local template = FxKit.template("Combat/Slash")
	if not root or not template then
		return
	end
	local spec = FLOOR2_SLASH[weaponId] or SLASH[typeId] or SLASH.sword
	local rarityId = player:GetAttribute("WeaponRarity") or "common"
	local color = spec.color or Palette.Material.bladeEdge
	if rarityId ~= "common" then
		color = color:Lerp(Rarities.color(rarityId), spec.color and 0.22 or 0.6)
	end
	local final = combo >= 3
	if final then
		color = color:Lerp(Palette.Env.ember, 0.55)
	end

	local base = root.CFrame * CFrame.new(0, 0.6, 0)
	local radius = spec.radius * (final and 1.15 or 1)
	local width = spec.width * (final and 1.3 or 1)
	local span = math.rad(final and 150 or spec.span)
	local direction = combo == 2 and -1 or 1
	local plane = base * CFrame.Angles(0, 0, math.rad(direction * 14))

	-- Точка дуги на доле k (0..1) и расстоянии r от героя.
	local function arcPoint(k: number, r: number): Vector3
		if final then
			local a = math.rad(70) - k * math.rad(150)
			return (base * CFrame.new(0, math.sin(a) * r * 0.8, -math.cos(a) * r * 0.75)).Position
		end
		local angle = (k - 0.5) * span * direction
		return (plane * CFrame.new(math.sin(angle) * r, 0, -math.cos(angle) * r)).Position
	end

	local holder = FxKit.holder()
	local inner = Instance.new("Attachment")
	inner.WorldPosition = arcPoint(0, radius - width)
	inner.Parent = holder
	local outer = Instance.new("Attachment")
	outer.WorldPosition = arcPoint(0, radius)
	outer.Parent = holder
	local trail = template:Clone()
	trail.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color)
	trail.Attachment0 = outer
	trail.Attachment1 = inner
	trail.Parent = holder
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, width * 0.8),
		NumberSequenceKeypoint.new(0.35, width),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Brightness = 2
	local core = template:Clone()
	core.Color = ColorSequence.new(Color3.new(1, 1, 1), color:Lerp(Color3.new(1, 1, 1), 0.55))
	core.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, width * 0.34),
		NumberSequenceKeypoint.new(0.35, width * 0.46),
		NumberSequenceKeypoint.new(1, 0),
	})
	core.Brightness = 3
	core.Lifetime = trail.Lifetime * 0.72
	core.Attachment0 = outer
	core.Attachment1 = inner
	core.Parent = holder
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - started) / SLASH_SWEEP, 0, 1)
		inner.WorldPosition = arcPoint(k, radius - width)
		outer.WorldPosition = arcPoint(k, radius)
		if k >= 1 then
			connection:Disconnect()
			trail.Enabled = false
			core.Enabled = false
			Debris:AddItem(holder, trail.Lifetime + 0.05)
		end
	end)
end

local function weaponStrike(data)
	local style = FLOOR2_SLASH[data.weaponId]
	local root = localRoot()
	if not style or not root then
		return
	end
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if forward.Magnitude < 0.01 then
		return
	end
	forward = forward.Unit
	local position = root.Position + forward * style.reach + V3(0, 1.7, 0)
	local scale = data.combo >= 3 and 1.28 or 0.88
	FxKit.spawn("WeaponHits/" .. data.weaponId, CFrame.lookAt(position, position + forward), { scale = scale })
	if data.combo >= 3 then
		Bus.emit("shake", { amount = data.typeId == "hammer" and 0.14 or 0.08, time = 0.1 })
	end
end

local function onPlayerAnimation(name: string, data)
	if name ~= "attack" then
		return
	end
	-- Посох мага не рубит: вспышку навершия и звук каста рисует MageFx.
	if data.typeId == "staff" then
		return
	end
	task.delay(math.max(data.strikeDelay - 0.04, 0), function()
		playerSlash(data.combo, data.typeId, data.weaponId)
		weaponStrike(data)
	end)
	local model = weaponModel()
	local trail = model and trailFor(model)
	if not trail then
		return
	end
	trail.Lifetime = data.combo == 3 and 0.28 or 0.2
	local lead = math.max(data.strikeDelay - 0.12, 0)
	task.delay(lead, function()
		trail.Enabled = true
	end)
	task.delay(math.min(data.strikeDelay + 0.16, data.duration), function()
		trail.Enabled = false
	end)
	-- Свист клинка в момент прохода перед игроком.
	task.delay(math.max(data.strikeDelay - 0.05, 0), function()
		Bus.emit("sfx", { name = "swing" .. tostring(math.clamp(data.combo, 1, 3)) })
	end)
end

-- ===== Оглушение: звёзды над головой =====

local stars = {}

local function addStars(model, duration: number)
	for _, entry in ipairs(stars) do
		if entry.model == model then
			entry.untilT = os.clock() + duration
			return
		end
	end
	local holder = FxKit.holder()
	local points, handles = {}, {}
	for _ = 1, 3 do
		local point = Instance.new("Attachment")
		point.Parent = holder
		table.insert(points, point)
		table.insert(handles, FxKit.attach("Combat/StunStar", point))
	end
	table.insert(stars, { model = model, holder = holder, points = points, handles = handles, untilT = os.clock() + duration })
end

local function updateStars()
	local t = os.clock()
	for index = #stars, 1, -1 do
		local entry = stars[index]
		local rig = EnemyVisualController.rigOf(entry.model)
		if t >= entry.untilT or not rig or not rig.pos then
			for _, handle in ipairs(entry.handles) do
				if handle then
					handle.stop()
				end
			end
			Debris:AddItem(entry.holder, 0.4)
			table.remove(stars, index)
		else
			-- Три звезды над FX_HeadTop: радиус 1, 6 рад/с (ТЗ врагов, 2.3).
			local top = rig.fx and EnemyFx.headTop(rig) or (rig.pos + V3(0, rig.stats.height + 0.7, 0))
			for i, point in ipairs(entry.points) do
				local angle = t * 6 + i * (math.pi * 2 / 3)
				point.WorldPosition = top + V3(math.cos(angle) * 1.0, 0, math.sin(angle) * 1.0)
			end
		end
	end
end

-- Поглощение души, взрыв Треснувшего и цепи Привратника рисует EnemyFx
-- (ТЗ врагов, раздел 2.3).

-- ===== События врагов =====

local function bodyPoint(model, fallback: Vector3?)
	local rig = model and EnemyVisualController.rigOf(model)
	if rig and rig.pos then
		return rig.pos + V3(0, rig.stats.height * 0.55, 0)
	end
	return fallback
end

local function onEnemyEvent(payload)
	if type(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	local isBoss = payload.model and payload.model:GetAttribute("EnemyIsBoss")

	if kind == "damage" then
		local point = bodyPoint(payload.model, payload.position)
		if point then
			burst("sparks", point, payload.counter and 22 or 11)
			if payload.counter then
				ring(V3(point.X, 0, point.Z), 3.5, Palette.Fx.warn, 0.3)
				flash(point, 1.4, Palette.Fx.hit, 0.15)
			end
			if payload.position then
				damageNumber(payload.position, payload.amount or 0, payload.counter and "counter" or (payload.crit and "crit" or "normal"))
			end
		end
		Bus.emit("sfx", { name = isBoss and "hitHeavy" or "hit", position = point })
		-- Удар почувствовался: короткий «упор» и лёгкая тряска.
		PlayerAnimator.hitStop(Combat.Feel.hitStop * (payload.counter and 1.8 or 1))
		Bus.emit("shake", { amount = Combat.Feel.hitShake * (payload.counter and 2 or 1), time = 0.12 })
	elseif kind == "parried" then
		local point = bodyPoint(payload.model, payload.position)
		if point then
			burst("chips", point, 20)
			flash(point, 1.6, Palette.Fx.parry, 0.2)
			ring(V3(point.X, 0, point.Z), 4, Palette.Fx.parry, 0.35)
		end
		Bus.emit("sfx", { name = "parry", position = point })
		Bus.emit("shake", { amount = Combat.Feel.parryShake, time = 0.18 })
	elseif kind == "stun" then
		if payload.model then
			addStars(payload.model, payload.duration or 1)
		end
	elseif kind == "area" and payload.attack ~= "explode" and payload.attack ~= "chains" then
		-- Взрыв Треснувшего и цепи Привратника рисует EnemyFx.
		local center = payload.position
		if center then
			local radius = payload.radius or 4
			ring(V3(center.X, 0, center.Z), radius, Palette.Fx.warn, 0.4, 0.3)
			ring(V3(center.X, 0, center.Z), radius * 0.6, Palette.Fx.hit, 0.25, 0.3)
			burst("dust", V3(center.X, 0.6, center.Z), 26)
			Bus.emit("sfx", { name = "slam", position = center })
			Bus.emit("shake", { amount = isBoss and 0.5 or 0.35, time = 0.3 })
		end
	elseif kind == "talentEcho" then
		-- Талант «Эхо щита»: парирование отдаёт волну по ближним врагам.
		local center = payload.position
		if center then
			local radius = payload.radius or 6
			ring(V3(center.X, 0, center.Z), radius, Palette.Fx.parry, 0.35, 0.2)
			task.delay(0.08, ring, V3(center.X, 0, center.Z), radius * 0.55, Palette.Fx.warn, 0.25, 0.2)
			burst("chips", V3(center.X, 1, center.Z), 14)
			Bus.emit("shake", { amount = 0.2, time = 0.12 })
		end
	elseif kind == "wallHit" then
		if payload.position then
			burst("dust", V3(payload.position.X, 1, payload.position.Z), 40)
		end
		Bus.emit("sfx", { name = "bossWallHit" })
		Bus.emit("shake", { amount = 0.8, time = 0.5 })
	elseif kind == "phase2" then
		-- Новая фаза босса: двойная ударная волна, вспышка, рёв, баннер.
		local point = payload.position
		if point then
			ring(V3(point.X, 0, point.Z), 16, Palette.Fx.danger, 0.9, 0.5)
			task.delay(0.15, ring, V3(point.X, 0, point.Z), 24, Palette.Env.ember, 1.0, 0.4)
			burst("danger", V3(point.X, 5, point.Z), 80)
			flash(V3(point.X, 8, point.Z), 2.5, Palette.Env.flameCore, 0.35)
		end
		Bus.emit("sfx", { name = "bossIntro" })
		Bus.emit("shake", { amount = 0.9, time = 1.4 })
		Bus.emit("bossPhase", { phase = payload.phase or 2, name = payload.name })
	elseif kind == "death" then
		-- Душа павшего (поток в клинок) — EnemyFx.
		local point = payload.position
		if point then
			burst("dust", point, isBoss and 70 or 22)
			if isBoss then
				ring(V3(point.X, 0, point.Z), 18, Palette.Fx.parry, 0.9, 0.4)
				Bus.emit("shake", { amount = 0.8, time = 1.0 })
			end
		end
	end
end

-- ===== События игрока =====

local function onFeedback(payload)
	if type(payload) ~= "table" then
		return
	end
	local root = localRoot()
	if not root then
		return
	end
	local kind = payload.kind
	if kind == "parry" then
		local point = root.Position + root.CFrame.LookVector * 2.2 + V3(0, 0.6, 0)
		burst("chips", point, 22)
		flash(point, 1.2, Palette.Fx.parry, 0.18)
		ring(V3(root.Position.X, 0, root.Position.Z), 5, Palette.Fx.parry, 0.3)
		Bus.emit("sfx", { name = "parry" })
		Bus.emit("shake", { amount = Combat.Feel.parryShake, time = 0.18 })
	elseif kind == "parryFail" then
		Bus.emit("sfx", { name = "parryFail" })
	elseif kind == "hit" then
		burst("danger", root.Position + V3(0, 1.4, 0), payload.heavy and 22 or 14)
		-- Тяжёлый удар (>15% здоровья) звучит и трясёт сильнее; по броне —
		-- добавочный звон металла, чтобы игрок слышал, что доспех держит.
		Bus.emit("sfx", { name = payload.heavy and "hurtHeavy" or "hurt" })
		if payload.armored then
			Bus.emit("sfx", { name = "armorBlock" })
			burst("chips", root.Position + root.CFrame.LookVector * 0.8 + V3(0, 1.2, 0), 8)
		end
		Bus.emit("shake", { amount = payload.heavy and 0.45 or 0.3, time = payload.heavy and 0.28 or 0.2 })
		Bus.emit("hurtFlash", { amount = payload.amount or 0 })
	elseif kind == "dodge" then
		-- Увернулся от удара: короткая вспышка-подтверждение.
		ring(V3(root.Position.X, 0, root.Position.Z), 3, Palette.Fx.parry, 0.25, 0.1)
	elseif kind == "evade" then
		-- «Тень» (дар этажа): удар прошёл мимо — тень-двойник и надпись.
		local ghost = fxPart(V3(1.8, 4.6, 1.0), Color3.fromRGB(130, 150, 220), 0.45)
		ghost.Material = Enum.Material.ForceField
		ghost.CFrame = root.CFrame * CFrame.new(-1.2, 0, 0.6)
		TweenService:Create(ghost, TweenInfo.new(0.4), { Transparency = 1, CFrame = ghost.CFrame * CFrame.new(-1.5, 0, 0) }):Play()
		Debris:AddItem(ghost, 0.45)
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(180, 40)
		tag.StudsOffsetWorldSpace = V3(0, 3.6, 0)
		tag.AlwaysOnTop = true
		tag.Adornee = root
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.Arcade
		text.TextSize = 22
		text.Text = "УКЛОНЕНИЕ"
		text.TextColor3 = Color3.fromRGB(170, 195, 255)
		text.TextStrokeTransparency = 0.2
		text.Parent = tag
		tag.Parent = root
		TweenService:Create(tag, TweenInfo.new(0.7), { StudsOffsetWorldSpace = V3(0, 5.2, 0) }):Play()
		TweenService:Create(text, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		Debris:AddItem(tag, 0.75)
		Bus.emit("sfx", { name = "dash" })
	elseif kind == "heal" then
		for _ = 1, 3 do
			burst("heal", root.Position + V3(math.random() - 0.5, 0.2, math.random() - 0.5), 10)
		end
		ring(V3(root.Position.X, 0, root.Position.Z), 3.2, Palette.Fx.heal, 0.5, 0.12)
		Bus.emit("sfx", { name = "heal" })
	end
end

-- Рывок: цепочка следов-«призраков» вдоль пути.
local function onDashFx(data)
	local root = localRoot()
	if not root then
		return
	end
	burst("dust", root.Position - V3(0, 2.6, 0), 14)
	for index = 1, 4 do
		task.delay((index - 1) * data.duration / 4, function()
			local currentRoot = localRoot()
			if not currentRoot then
				return
			end
			local ghost = fxPart(V3(1.8, 4.2, 1.0), Palette.Fx.parry, 0.7)
			ghost.Material = Enum.Material.ForceField
			ghost.CFrame = currentRoot.CFrame
			TweenService:Create(ghost, TweenInfo.new(0.28), { Transparency = 1 }):Play()
			Debris:AddItem(ghost, 0.32)
		end)
	end
end

-- ===== Способности =====

local function barrier(duration: number)
	local root = localRoot()
	if not root then
		return
	end
	local dome = fxPart(V3(8, 8, 8), Palette.Fx.hit, 0.72)
	dome.Shape = Enum.PartType.Ball
	dome.Material = Enum.Material.ForceField
	dome.Parent = folder()
	local startedAt = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local currentRoot = localRoot()
		local shieldUntil = player:GetAttribute("ShieldUntil") or 0
		if not currentRoot or os.clock() - startedAt > duration or Workspace:GetServerTimeNow() > shieldUntil then
			connection:Disconnect()
			dome:Destroy()
			return
		end
		dome.CFrame = currentRoot.CFrame
		dome.Transparency = 0.7 + 0.1 * math.sin(os.clock() * 6)
	end)
end

local function onAbility(payload)
	if type(payload) ~= "table" then
		return
	end
	local root = localRoot()
	local position = payload.position or (root and root.Position)
	if not position then
		return
	end
	local flat = V3(position.X, 0, position.Z)
	if payload.kind == "weapon" then
		-- Новые способности (vortex/rift/unlock) рисует AbilityFx по событию AbilityFx.
		if payload.id ~= "whirl" and payload.id ~= "sunder" then
			return
		end
		if payload.id == "whirl" then
			ring(flat, payload.radius or 5, Palette.Fx.parry, 0.45, 0.2)
			ring(flat, (payload.radius or 5) * 0.65, Palette.Fx.warn, 0.35, 0.2)
			burst("sparks", position + V3(0, 1.5, 0), 36)
			Bus.emit("shake", { amount = 0.35, time = 0.3 })
		else
			ring(flat, payload.radius or 6, Palette.Fx.warn, 0.5, 0.3)
			burst("dust", V3(flat.X, 0.5, flat.Z) + (root and root.CFrame.LookVector * 3 or V3(0, 0, 0)), 50)
			burst("chips", position + V3(0, 1, 0), 24)
			Bus.emit("shake", { amount = 0.7, time = 0.4 })
		end
		Bus.emit("sfx", { name = "ability" })
	elseif payload.kind == "verdict" then
		local direction = payload.direction or V3(0, 0, -1)
		local length = payload.length or 14
		local beam = fxPart(V3(4, 0.3, length), Palette.Fx.parry, 0.2)
		beam.CFrame = CFrame.lookAt(flat + direction * (length / 2) + V3(0, 0.3, 0), flat + direction * length + V3(0, 0.3, 0))
		TweenService:Create(beam, TweenInfo.new(0.45), { Transparency = 1, Size = V3(0.3, 0.3, length) }):Play()
		Debris:AddItem(beam, 0.5)
		Bus.emit("shake", { amount = 0.6, time = 0.35 })
		Bus.emit("sfx", { name = "ability" })
	elseif payload.kind == "barrier" then
		barrier(payload.duration or 4)
		ring(flat, 4, Palette.Fx.parry, 0.4, 0.2)
		Bus.emit("sfx", { name = "ability" })
	elseif payload.kind == "passive" then
		ring(flat, 3, Palette.Fx.warn, 0.5, 0.15)
	end
end

function AttackFxController.start()
	setupEmitters()
	PlayerAnimator.onEvent(onPlayerAnimation)
	Bus.on("dashFx", onDashFx)

	local enemyRemote = Net.get("EnemyEvent")
	if enemyRemote then
		enemyRemote.OnClientEvent:Connect(onEnemyEvent)
	end
	local feedbackRemote = Net.get("CombatFeedback")
	if feedbackRemote then
		feedbackRemote.OnClientEvent:Connect(onFeedback)
	end
	local abilityRemote = Net.get("AbilityUsed")
	if abilityRemote then
		abilityRemote.OnClientEvent:Connect(onAbility)
	end

	RunService.RenderStepped:Connect(updateStars)
	print("[AttackFxController] эффекты боя")
end

return AttackFxController
