--!nonstrict
-- AbilityFxV2 (клиент) — картинка и звук переделанных способностей мечей и молотов (07.11.2026).
-- Сервер (Systems/WeaponAbilitiesV2, «Вспомнить» — WeaponAbilitiesChronicle) шлёт AbilityFx kind = "v2";
-- урон и цели решает сервер, здесь — только «где и как красиво».
--
-- Стандарт (документ «Способности оружия — переделка»): три такта (замах → удар → последствие),
-- зона видна на полу в размер серверной, на главном ударе — хит-стоп (замирают поза героя и врагов),
-- вспышка и тряска, свой звук на каждый такт. Шаблоны — FX.V2/* (Shared/Fx/FxWeaponsV2), флипбуки —
-- листы из pixelfx (tools/flipbooks); пока их id не вписаны, играют запасные текстуры.
--
-- Плюс «оверлеи» поверх старых эффектов, механика которых не менялась: Жатва, Свора, Капкан
-- (AbilityFxV2.overlay вызывается из AbilityFx на каждое событие).

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local K = require(script.Parent.AbilityFx345Kit)
local FxKit = K.FxKit
local PlayerAnimator = require(script.Parent.PlayerAnimator)
local EnemyVisualController = require(script.Parent.EnemyVisualController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FxBuilder345 = require(Shared.Fx.FxBuilder345)

local AbilityFxV2 = {}

local V3 = Vector3.new
local player = Players.LocalPlayer

local C = {
	paper = K.color("#E8E6F0"),
	ash = K.color("#9A98AA"),
	orange = K.color("#FF7A2B"),
	yellow = K.color("#FFC857"),
	white = K.color("#FFF1C2"),
	gold = K.color("#FFD45A"),
	prey = K.color("#FF4A3A"),
	green = K.color("#8EE04A"),
	water = K.color("#4FD6FF"),
	violet = K.color("#9B7BFF"),
	ink = K.color("#1D1B3A"),
	memory = K.color("#6FE3FF"),
}

-- ===== Общие приёмы =====

-- Хит-стоп: только у того, кто ударил (это ощущение удара, а не событие мира).
local function hitStop(caster, duration: number)
	if K.isLocal(caster) then
		PlayerAnimator.hitStop(duration)
		EnemyVisualController.hitStop(duration)
	end
end

-- Главный удар: хит-стоп, тряска, толчок угла обзора.
local function impact(caster, position: Vector3, strength: number)
	hitStop(caster, 0.05 + 0.05 * strength)
	K.shake(position, 0.18 + 0.22 * strength, 0.2 + 0.15 * strength)
	K.fov(caster, 3 + 4 * strength, 0.25)
end

local function spawnAt(path: string, position: Vector3, opts)
	return FxKit.spawn(path, CFrame.new(position), opts)
end

-- Зона на полу: тонкий диск (неон, прозрачный) + кромка — в размер серверной зоны.
local function groundZone(position: Vector3, radius: number, color: Color3, life: number, opts)
	opts = opts or {}
	local center = K.ground(position, 0.08)
	local disc = Instance.new("Part")
	disc.Name = "V2Zone"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = V3(0.06, radius * 2, radius * 2)
	disc.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Material = Enum.Material.Neon
	disc.Color = color
	disc.Transparency = 1
	disc.Parent = FxKit.folder()
	local fill = opts.fill or 0.82
	K.tween(disc, opts.fadeIn or 0.15, { Transparency = fill })
	-- кромка: плоская деталь с кольцом-текстурой на верхней грани (центр прозрачный)
	local edge = Instance.new("Part")
	edge.Name = "V2ZoneEdge"
	edge.Size = V3(radius * 2 + 0.6, 0.05, radius * 2 + 0.6)
	edge.CFrame = CFrame.new(center + V3(0, 0.02, 0))
	edge.Anchored = true
	edge.CanCollide = false
	edge.CanQuery = false
	edge.CanTouch = false
	edge.CastShadow = false
	edge.Transparency = 1
	edge.Parent = disc.Parent
	local ring = Instance.new("Decal")
	ring.Face = Enum.NormalId.Top
	ring.Texture = FxBuilder345.texture("ring")
	ring.Color3 = color
	ring.Transparency = 1
	ring.Parent = edge
	K.tween(ring, opts.fadeIn or 0.15, { Transparency = opts.edge or 0.35 })
	task.delay(math.max(0, life - 0.25), function()
		K.tween(disc, 0.25, { Transparency = 1 })
		K.tween(ring, 0.25, { Transparency = 1 })
	end)
	Debris:AddItem(disc, life + 0.1)
	Debris:AddItem(edge, life + 0.1)
	return disc, edge
end

-- Полоса на полу (линия удара).
local function groundStrip(origin: Vector3, direction: Vector3, length: number, width: number, color: Color3, life: number, transparency: number?)
	local dir = K.flat(direction)
	local start = K.ground(origin, 0.07)
	local part = Instance.new("Part")
	part.Name = "V2Strip"
	part.Size = V3(width, 0.06, length)
	part.CFrame = CFrame.lookAt(start + dir * (length / 2), start + dir * (length / 2 + 1))
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 1
	part.Parent = FxKit.folder()
	K.tween(part, 0.12, { Transparency = transparency or 0.7 })
	task.delay(math.max(0, life - 0.2), function()
		K.tween(part, 0.2, { Transparency = 1 })
	end)
	Debris:AddItem(part, life + 0.1)
	return part
end

-- Модель врага для эффекта: визуальный риг, если есть, иначе серверная модель.
local function visualOf(model)
	local rig = EnemyVisualController.rigOf(model)
	return rig and rig.model or model
end

-- ===================== С НУЛЯ =====================

-- ===== «Забвение» =====
local fields = {}

local function eraseField(p)
	local center = K.ground(p.position, 0.1)
	local radius = p.radius or 10
	local duration = p.duration or 2
	groundZone(center, radius, C.paper, duration + 0.4, { fill = 0.86, edge = 0.35 })
	local handle = spawnAt("V2/EraseField", center, { radius = radius, life = duration })
	K.sound("v2EraseDraw", center)
	K.shake(center, 0.12, 0.3)
	-- враги внутри сереют (подсветка серым по мере «стирания»)
	local lights = {}
	local token = {}
	fields[p.caster] = token
	K.loop(duration + 0.1, function()
		if fields[p.caster] ~= token then
			return false
		end
		for serverModel, rig in pairs(EnemyVisualController.all()) do
			local root = K.modelPart(serverModel)
			if root and K.flat(root.Position - center).Magnitude <= radius + 1 then
				local h = lights[serverModel]
				if not h and rig.model then
					h = Instance.new("Highlight")
					h.FillColor = C.ash
					h.OutlineColor = C.paper
					h.FillTransparency = 1
					h.OutlineTransparency = 0.4
					h.DepthMode = Enum.HighlightDepthMode.Occluded
					h.Adornee = rig.model
					h.Parent = rig.model
					lights[serverModel] = h
				end
				if h then
					local fade = serverModel:GetAttribute("EraseFade") or 0
					h.FillTransparency = 1 - math.clamp(fade, 0, 0.75)
				end
			end
		end
		return true
	end)
	task.delay(duration + 0.6, function()
		for _, h in pairs(lights) do
			if h.Parent then
				K.tween(h, 0.3, { FillTransparency = 1, OutlineTransparency = 1 })
				Debris:AddItem(h, 0.35)
			end
		end
		if handle then
			handle.stop()
		end
	end)
	for i = 1, 4 do
		task.delay(i * duration / 5, function()
			K.sound("v2EraseTick", center)
		end)
	end
end

local function eraseFinal(p)
	local center = K.ground(p.position, 0.1)
	spawnAt("V2/EraseSweep", center + V3(0, 1.5, 0), { radius = p.radius })
	K.sound("v2EraseSweep", center)
	impact(p.caster, center, 1)
	for _, e in ipairs(p.erased or {}) do
		if typeof(e.position) == "Vector3" then
			spawnAt("V2/EraseFade", e.position + V3(0, 1.5, 0))
		end
	end
	if #(p.erased or {}) > 0 then
		K.sound("v2Erased", center)
	end
end

-- ===== «Горнило» =====
local function heartPlunge(p)
	local origin = K.ground(p.position, 0.1)
	spawnAt("V2/HeartPlunge", origin)
	K.sound("v2HeartPlunge", origin)
	impact(p.caster, origin, 0.6)
	for i, f in ipairs(p.fissures or {}) do
		local dir = K.flat(f.dir)
		task.delay((i - 1) * 0.03, function()
			local strip = groundStrip(origin, dir, f.length, 1.4, C.orange, (p.eruptIn or 0.25) + (p.gap or 0.1) * #p.fissures + 0.8, 0.45)
			strip.Size = V3(1.4, 0.06, 0.1)
			local start = K.ground(origin, 0.07)
			-- трещина растёт от клинка наружу
			strip.CFrame = CFrame.lookAt(start + dir * 0.05, start + dir * 1.05)
			K.tween(strip, p.eruptIn or 0.25, {
				Size = V3(1.4, 0.06, f.length),
				CFrame = CFrame.lookAt(start + dir * (f.length / 2), start + dir * (f.length / 2 + 1)),
			})
		end)
	end
end

local function heartErupt(p)
	local origin = K.ground(p.position, 0)
	local dir = K.flat(p.direction)
	local length = p.length or 12
	local count = math.max(2, math.floor(length / 3.5))
	for k = 1, count do
		task.delay((k - 1) * 0.035, function()
			local point = K.ground(origin + dir * (length * k / count), 0)
			spawnAt("V2/Pillar", point + V3(0, 4.2, 0), { scale = 0.8 + 0.25 * (k / count) })
		end)
	end
	K.sound("v2HeartErupt", origin + dir * length * 0.5)
	if (p.index or 1) == 3 then
		impact(p.caster, origin, 0.8)
	end
end

local burning = {}
local function heartBlade(p)
	local caster = p.caster
	local tip = K.weapon(caster)
	local part = tip and (tip:IsA("BasePart") and tip or tip:FindFirstChildWhichIsA("BasePart", true))
	if not part then
		return
	end
	local old = burning[caster]
	if old then
		old.stop()
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "V2BurningBlade"
	attachment.Parent = part
	local handle = FxKit.attach("V2/BurningBlade", attachment, { life = p.duration or 6 })
	burning[caster] = handle
	Debris:AddItem(attachment, (p.duration or 6) + 1.5)
	K.sound("v2HeartBlade", part.Position)
end

local function heartArc(p)
	local origin = K.ground(p.position, 1.4)
	local dir = K.flat(p.direction)
	local length = p.length or 10
	local fly = K.flyer("V2/BurningBlade", CFrame.lookAt(origin, origin + dir), { life = 0.45, trail = false })
	K.loop(0.32, function(t)
		local k = math.clamp(t / 0.3, 0, 1)
		fly.move(CFrame.lookAt(origin + dir * (length * k), origin + dir * (length * k + 1)))
		return true
	end)
	spawnAt("V2/FireArc", origin + dir * 2.5, { scale = 1 })
	groundStrip(p.position, dir, length, 3.6, C.orange, 0.5, 0.75)
	K.sound("v2HeartArc", origin)
end

-- ===== «Первая отливка» =====
local function pourRaise(p)
	local caster = p.caster
	local tip = K.weaponTip(caster)
	if not tip then
		return
	end
	local holder = K.flyer("V2/PourStream", CFrame.new(tip + V3(0, 9, 0)), { life = math.max(0.4, (p.until_ or 1.2) - 0.1), trail = false })
	K.loop(p.until_ or 1.2, function()
		local now = K.weaponTip(caster)
		if now then
			holder.move(CFrame.new(now + V3(0, 9, 0)))
		end
		return true
	end)
	K.sound("v2PourSky", tip)
	-- ступени отливки: по вспышке на ступень (1–3)
	for s = 1, (p.stage or 0) do
		task.delay(0.15 * s, function()
			local now = K.weaponTip(caster)
			if now then
				spawnAt("V2/Crit", now)
			end
		end)
	end
end

local function pourRing(p)
	local center = K.ground(p.position, 0.1)
	spawnAt("V2/PourRing", center, { radius = p.radius })
	groundZone(center, p.radius, C.orange, 0.4, { fill = 0.88, edge = 0.4, fadeIn = 0.06 })
	K.sound("v2PourRing", center)
	hitStop(p.caster, 0.04)
end

local function pourCleave(p)
	local origin = K.ground(p.position, 0)
	local dir = K.flat(p.direction)
	local length = p.length or 16
	local mid = origin + dir * (length * 0.5)
	FxKit.spawn("V2/GhostCleave", CFrame.lookAt(mid + V3(0, 4, 0), mid + V3(0, 4, 0) + dir), { scale = 1 + 0.15 * (p.stage or 0) })
	groundStrip(origin, dir, length, 4, C.yellow, 1.2, 0.55)
	K.sound("v2PourCleave", mid)
	impact(p.caster, mid, 1.2)
end

local function pourSteam(p)
	local center = K.ground(p.position, 0.2)
	spawnAt("V2/Steam", center, { radius = p.radius })
	K.sound("v2PourSteam", center)
	K.shake(center, 0.25, 0.35)
end

-- ===== «Соколиная охота» =====
local falcons = {} -- [caster] = { gui, holder, mode, target, t0 }

-- Тело сокола: BillboardGui с кадрами листа fb_bird (если лист загружен), иначе золотая искра.
local function falconBody(holder: BasePart)
	local id = FxBuilder345.texture("fb_bird")
	local own = FxBuilder345.ownTexture("fb_bird")
	local gui = Instance.new("BillboardGui")
	gui.Name = "Falcon"
	gui.Size = UDim2.fromScale(3.4, 3.4)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Adornee = holder
	gui.Parent = holder
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = id
	image.ResampleMode = Enum.ResamplerMode.Pixelated
	image.ImageColor3 = own and Color3.new(1, 1, 1) or C.gold
	image.Parent = gui
	if own then
		image.ImageRectSize = Vector2.new(256, 256)
		local frame = 0
		local acc = 0
		K.loop(nil, function(_, dt)
			if not gui.Parent then
				return false
			end
			acc += dt
			if acc >= 1 / 14 then
				acc = 0
				frame = (frame + 1) % 16
				image.ImageRectOffset = Vector2.new((frame % 4) * 256, math.floor(frame / 4) * 256)
			end
			return true
		end)
	end
	return gui, image
end

local function falconCall(p)
	local caster = p.caster
	local root = K.casterRoot(caster)
	if not root then
		return
	end
	local old = falcons[caster]
	if old and old.fly then
		old.fly.stop(0.3)
	end
	spawnAt("V2/FalconCall", root.Position + V3(0, 1.5, 0))
	K.sound("v2FalconCall", root.Position)
	local fly = K.flyer("V2/Falcon", CFrame.new(root.Position + V3(0, 3, 0)), { life = (p.duration or 4) + 2 })
	local _, image = falconBody(fly.part)
	local state: any = { fly = fly, image = image, mode = "circle", t0 = os.clock(), from = nil, target = nil, time = 0.35 }
	falcons[caster] = state
	-- кружит над героем; на пике — к цели и обратно (режим ставит falconDive)
	local angle = 0
	K.loop((p.duration or 4) + 2, function(_, dt)
		if falcons[caster] ~= state or fly.stopped then
			return false
		end
		local r = K.casterRoot(caster)
		if not r then
			return false
		end
		if state.mode == "circle" then
			angle += dt * 2.2
			local pos = r.Position + V3(math.cos(angle) * 5, 6 + math.sin(angle * 2) * 0.6, math.sin(angle) * 5)
			local nextPos = r.Position + V3(math.cos(angle + 0.1) * 5, 6, math.sin(angle + 0.1) * 5)
			fly.move(CFrame.lookAt(pos, nextPos))
			if image then
				image.ImageTransparency = 0
				-- лист нарисован «вправо»: зеркалим, когда летит влево по экрану
				local camera = workspace.CurrentCamera
				if camera then
					local screenDir = camera.CFrame:VectorToObjectSpace(nextPos - pos)
					image.Rotation = 0
					image.Size = screenDir.X < 0 and UDim2.new(-1, 0, 1, 0) or UDim2.fromScale(1, 1)
					image.Position = screenDir.X < 0 and UDim2.fromScale(1, 0) or UDim2.fromScale(0, 0)
				end
			end
		elseif state.mode == "dive" then
			local k = math.clamp((os.clock() - state.t0) / state.time, 0, 1)
			local from, to = state.from, state.target
			local pos = from:Lerp(to, k * k) + V3(0, math.sin(k * math.pi) * 1.5, 0)
			fly.move(CFrame.lookAt(pos, to))
			if k >= 1 then
				state.mode = "rise"
				state.t0 = os.clock()
				state.from = pos
			end
		elseif state.mode == "rise" then
			local k = math.clamp((os.clock() - state.t0) / 0.5, 0, 1)
			local target = r.Position + V3(math.cos(angle) * 5, 6, math.sin(angle) * 5)
			fly.move(CFrame.new(state.from:Lerp(target, k)))
			if k >= 1 then
				state.mode = "circle"
			end
		end
		return true
	end)
end

local function falconDive(p)
	local caster = p.caster
	local state = falcons[caster]
	local target = K.ground(p.position, 0.6)
	local time = p.time or 0.35
	if state and state.fly and not state.fly.stopped then
		state.mode = "dive"
		state.from = state.fly.part.Position
		state.target = target
		state.time = time
		state.t0 = os.clock()
	end
	K.sound(p.final and "v2FalconFinalDive" or "v2FalconDive", target)
	groundZone(target, p.radius or 4, C.gold, time + 0.25, { fill = 0.85, edge = 0.4, fadeIn = 0.08 })
	task.delay(time, function()
		spawnAt("V2/FalconDive", target + V3(0, 0.5, 0), { radius = p.radius, scale = p.final and 1.4 or 1 })
		K.sound(p.final and "v2FalconFinalHit" or "v2FalconHit", target)
		impact(caster, target, p.final and 1 or 0.5)
		if p.final and state and state.fly then
			task.delay(0.5, function()
				state.fly.stop(0.4)
			end)
		end
	end)
end

local function falconLeave(p)
	local state = falcons[p.caster]
	if state and state.fly then
		K.sound("v2FalconCall", state.fly.part.Position)
		state.mode = "leave"
		local from = state.fly.part.Position
		K.loop(0.8, function(t)
			state.fly.move(CFrame.new(from + V3(0, t * 14, 0)))
			return true
		end)
		task.delay(0.8, function()
			state.fly.stop(0.3)
		end)
	end
end

-- ===================== ДОРАБОТКА =====================

-- ===== «Прилив» =====
local function tideWave(p)
	local origin = K.ground(p.position, 0)
	local dir = K.flat(p.direction)
	local length = p.length or 12
	local time = p.time or 0.6
	local width = p.width or 6
	groundStrip(origin, dir, length, width, C.water, time + 0.4, 0.8)
	spawnAt("V2/Splash", origin + dir * 1.5, { scale = 0.6 })
	K.sound("v2TideSlam", origin)
	impact(p.caster, origin, 0.6)
	local fly = K.flyer("V2/WaveCrest", CFrame.lookAt(origin + V3(0, 1.4, 0), origin + V3(0, 1.4, 0) + dir), { life = time + 0.2, trail = false })
	-- держатель шириной в волну: эмиттеры Box берут его размер
	fly.part.Size = V3(width, 1.5, 1)
	K.loop(time, function(t)
		local k = math.clamp(t / time, 0, 1)
		local pos = origin + dir * (length * k) + V3(0, 1.4, 0)
		fly.move(CFrame.lookAt(pos, pos + dir))
		return true
	end)
	K.sound("v2TideRoll", origin + dir * length * 0.5)
end

local function tideCrash(p)
	local center = K.ground(p.position, 0.1)
	spawnAt("V2/Splash", center + V3(0, 1, 0), { radius = p.radius })
	spawnAt("V2/Puddle", center, { radius = p.radius, life = p.time })
	groundZone(center, p.radius, C.water, p.time or 4, { fill = 0.88, edge = 0.55 })
	K.sound("v2TideCrash", center)
	K.shake(center, 0.2, 0.25)
end

-- ===== «Обрезка» =====
local function pruneCut(p)
	local origin = K.ground(p.position, 1.4)
	local dir = K.flat(p.direction)
	local side = (p.index or 1) == 1 and 1 or -1
	FxKit.spawn("V2/ReapCrescent", CFrame.lookAt(origin + dir * 3, origin + dir * 4) * CFrame.Angles(0, 0, math.rad(35 * side)), { scale = 1 })
	K.sound("v2PruneCut", origin)
	hitStop(p.caster, 0.04)
end

local function pruneVines(p)
	for _, model in ipairs(p.targets or {}) do
		local state = K.onModel("v2Vines", model, "V2/Vines", (p.time or 1.2) + 0.2, -1.5)
		K.highlight(state, visualOf(model), C.green, C.green, 0.7)
	end
	if #(p.targets or {}) > 0 then
		K.sound("v2PruneVines", nil)
	end
end

local function pruneSnip(p)
	local any = false
	for _, t in ipairs(p.targets or {}) do
		if typeof(t.position) == "Vector3" then
			spawnAt("V2/VineBurst", t.position + V3(0, 1, 0))
			any = true
		end
		if t.model then
			K.offModel("v2Vines", t.model)
		end
	end
	if any then
		K.sound("v2PruneSnip", nil)
		impact(p.caster, (p.targets[1] and p.targets[1].position) or V3(), 0.6)
	end
end

-- ===== «Последний гон» =====
local preyMarks = {}

-- Цепочка рывков героя (только у себя): как AbilityController.applyMove, по точкам.
local function chainMove(hops, start: number, hopTime: number, hopGap: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	task.delay(start, function()
		if not root.Parent or humanoid.Health <= 0 then
			return
		end
		local previousWalkSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = 0
		for i, hop in ipairs(hops) do
			local target = V3(hop.to.X, root.Position.Y, hop.to.Z)
			local from = root.Position
			local rel = target - from
			local dist = V3(rel.X, 0, rel.Z).Magnitude
			if dist > 0.3 then
				local dir = V3(rel.X, 0, rel.Z).Unit
				root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
				PlayerAnimator.play("huntLunge", hopTime + hopGap + 0.05)
				local t0 = os.clock()
				while os.clock() - t0 < hopTime and root.Parent do
					root.AssemblyLinearVelocity = dir * (dist / hopTime) + V3(0, root.AssemblyLinearVelocity.Y * 0, 0)
					RunService.Heartbeat:Wait()
				end
				root.AssemblyLinearVelocity = V3(0, root.AssemblyLinearVelocity.Y, 0)
			end
			if i < #hops then
				task.wait(hopGap)
			end
		end
		if humanoid.Parent then
			humanoid.WalkSpeed = previousWalkSpeed
		end
	end)
end

local function huntHorn(p)
	local center = K.ground(p.position, 0.1)
	spawnAt("V2/HornWave", center, { radius = p.radius })
	groundZone(center, p.radius or 14, C.prey, 0.6, { fill = 0.92, edge = 0.5, fadeIn = 0.1 })
	K.sound("huntHorn", center)
	for _, model in ipairs(p.targets or {}) do
		local state = K.onModel("v2Prey", model, "V2/PreyMark", 3, 1.2)
		preyMarks[model] = state
		K.highlight(state, visualOf(model), C.prey, C.prey, 0.75)
	end
	if #(p.targets or {}) > 0 then
		K.sound("v2PreyMarked", center)
	end
	if K.isLocal(p.caster) and p.hops then
		chainMove(p.hops, p.start or 0.3, p.hopTime or 0.17, p.hopGap or 0.07)
	end
	-- след рывков (видят все): полосы по пути
	for i, hop in ipairs(p.hops or {}) do
		task.delay((p.start or 0.3) + (i - 1) * ((p.hopTime or 0.17) + (p.hopGap or 0.07)), function()
			local rel = K.flat(hop.to - hop.from)
			local len = (hop.to - hop.from).Magnitude
			groundStrip(hop.from, rel, len, 1.2, C.prey, 0.5, 0.6)
			K.sound("huntDash", hop.from)
		end)
	end
end

local function huntDash(p)
	groundStrip(p.position, p.direction, p.length or 13, 6.4, C.prey, 0.5, 0.75)
	K.sound("huntDash", p.position)
end

local function huntHop(p)
	local at = p.position + V3(0, 2, 0)
	FxKit.spawn("V2/HuntSlash", CFrame.new(at), { scale = 1 })
	K.sound("huntPierce", at)
	if p.model then
		K.offModel("v2Prey", p.model)
		preyMarks[p.model] = nil
	end
	hitStop(p.caster, 0.06)
	K.shake(at, 0.15, 0.15)
end

local function huntFinale(p)
	local center = K.ground(p.position, 0.1)
	spawnAt("V2/HuntFinale", center + V3(0, 1.5, 0), { radius = p.radius })
	groundZone(center, p.radius or 6, C.prey, 0.5, { fill = 0.85, edge = 0.4, fadeIn = 0.05 })
	K.sound("v2HuntFinale", center)
	impact(p.caster, center, 0.9)
end

-- ===== «Шлаковый смерч» =====
local function slagCyclone(p)
	local caster = p.caster
	local duration = p.duration or 2.2
	local root = K.casterRoot(caster)
	if not root then
		return
	end
	local holder = FxKit.spawn("V2/Cyclone", CFrame.new(root.Position - V3(0, 1.5, 0)), { radius = p.radius, life = duration })
	K.sound("v2CycloneStart", root.Position)
	local spinT = 0
	K.loop(duration + 0.1, function(_, dt)
		local r = K.casterRoot(caster)
		if not r or not holder or not holder.root or not holder.root.Parent then
			return false
		end
		spinT += dt
		holder.root.CFrame = CFrame.new(r.Position - V3(0, 2.6, 0)) * CFrame.Angles(0, -spinT * 9, 0)
		return true
	end)
	local spins = 6
	for i = 1, spins do
		task.delay((p.start or 0.2) + (i - 1) * duration / spins, function()
			local r = K.casterRoot(caster)
			K.sound("v2CycloneSpin", r and r.Position)
		end)
	end
end

local function slagGlobs(p)
	local from = K.ground(p.position, 2)
	for _, point in ipairs(p.points or {}) do
		local to = K.ground(point, 0.1)
		local fly = K.flyer("V2/BurningBlade", CFrame.new(from), { life = (p.flight or 0.4) + 0.1, trail = false })
		K.loop(p.flight or 0.4, function(t)
			local k = math.clamp(t / (p.flight or 0.4), 0, 1)
			fly.move(CFrame.new(from:Lerp(to, k) + V3(0, math.sin(k * math.pi) * 3, 0)))
			return true
		end)
		task.delay(p.flight or 0.4, function()
			spawnAt("V2/SlagPool", to, { radius = p.radius, life = p.time })
			groundZone(to, p.radius or 2.6, C.orange, p.time or 3, { fill = 0.85, edge = 0.6 })
		end)
	end
	if (p.index or 1) % 2 == 1 then
		K.sound("forgeSteamSoft", from)
	end
end

local function slagSlam(p)
	local center = K.ground(p.position, 0.1)
	spawnAt("V2/SlagSlam", center + V3(0, 1, 0), { radius = p.radius })
	groundZone(center, p.radius or 7, C.orange, 0.6, { fill = 0.8, edge = 0.35, fadeIn = 0.05 })
	K.sound("v2CycloneSlam", center)
	impact(p.caster, center, 1.1)
end

-- ===== «Строка» крестом =====
local function quillWrite(p)
	local write = p.writeTime or 0.5
	for li, line in ipairs(p.lines or {}) do
		local dir = K.flat(line.dir)
		groundStrip(line.from, dir, line.length, 6, C.violet, write + (p.detonateDelay or 0.35) + 0.8, 0.85)
		for r, point in ipairs(line.runes or {}) do
			task.delay(write * (r - 1) / #line.runes + (li - 1) * 0.05, function()
				spawnAt("V2/RuneGlyph", K.ground(point, 1.2))
			end)
			task.delay(write + (p.detonateDelay or 0.35) + (r - 1) * (p.interval or 0.06) + (li - 1) * 0.03, function()
				spawnAt("V2/RuneBlast", K.ground(point, 1))
				if r % 2 == 1 then
					K.sound("chronRuneBurst", point)
				end
			end)
		end
	end
	K.sound("chronQuill", p.center)
end

local function quillCenter(p)
	local center = K.ground(p.position, 0.1)
	spawnAt("V2/InkBurst", center + V3(0, 1, 0), { scale = 0.6 })
	groundZone(center, p.radius or 2.8, C.violet, 0.5, { fill = 0.7, edge = 0.3, fadeIn = 0.05 })
	K.sound("v2QuillCenter", center)
	impact(p.caster, center, 0.8)
end

-- ===== «Чернильный прилив» =====
local function inkFan(p)
	local origin = K.ground(p.position, 1.2)
	local dir = K.flat(p.direction)
	for i = -2, 2 do
		local d = CFrame.fromAxisAngle(V3(0, 1, 0), math.rad(i * (p.halfAngle or 70) / 2.5)):VectorToWorldSpace(dir)
		task.delay(math.abs(i) * 0.02, function()
			spawnAt("V2/Tendrils", origin + d * (p.radius or 10.5) * 0.55, { scale = 0.8 })
		end)
	end
	K.sound("chronInkSplash", origin)
	hitStop(p.caster, 0.05)
end

local function inkPull(p)
	local point = K.ground(p.position, 0.1)
	groundZone(point, 2.5, C.violet, (p.time or 0.9) + 0.8, { fill = 0.7, edge = 0.3 })
	for _, model in ipairs(p.targets or {}) do
		local state = K.onModel("v2InkPull", model, "V2/Tendrils", (p.time or 0.9) + 0.2, -1)
		K.highlight(state, visualOf(model), C.ink, C.violet, 0.6)
	end
	K.sound("v2InkPull", point)
end

local function inkBurst(p)
	local center = K.ground(p.position, 0.1)
	spawnAt("V2/InkBurst", center + V3(0, 1, 0), { radius = p.radius })
	groundZone(center, p.radius or 5, C.violet, 0.6, { fill = 0.75, edge = 0.35, fadeIn = 0.05 })
	K.sound("v2InkBurst", center)
	impact(p.caster, center, 1)
end

-- ===== Тигель, Перекал =====
local function crucibleTip(p)
	local caster = p.caster
	task.delay(math.max(0, (p.pourAt or 0.4) - 0.1), function()
		local weapon = K.weapon(caster)
		local part = weapon and (weapon:IsA("BasePart") and weapon or weapon:FindFirstChildWhichIsA("BasePart", true))
		if not part then
			return
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = "V2CrucibleStream"
		attachment.Parent = part
		local tip = K.weaponTip(caster)
		if tip then
			attachment.WorldPosition = tip
		end
		FxKit.attach("V2/CrucibleStream", attachment, { life = p.time or 0.7 })
		Debris:AddItem(attachment, (p.time or 0.7) + 1.2)
	end)
end

local searing = {}
local function searingBlade(p)
	local caster = p.caster
	local weapon = K.weapon(caster)
	local part = weapon and (weapon:IsA("BasePart") and weapon or weapon:FindFirstChildWhichIsA("BasePart", true))
	if not part then
		return
	end
	if searing[caster] then
		searing[caster].stop()
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "V2HeatBlade"
	attachment.Parent = part
	searing[caster] = FxKit.attach("V2/HeatBlade", attachment, { life = p.duration or 5 })
	Debris:AddItem(attachment, (p.duration or 5) + 1.5)
end

local function searingFinale(p)
	local center = K.ground(p.position, 0.1)
	spawnAt("V2/SearingFinale", center + V3(0, 1, 0), { radius = p.radius })
	K.sound("v2SearingFinale", center)
	impact(p.caster, center, 0.7)
end

-- ===== «Вспомнить»: финал «Сшивка» =====
local function recallStitch(p)
	local time = p.time or 0.22
	for i, dash in ipairs(p.dashes or {}) do
		local from = K.ground(dash.from, 2.6)
		local dir = K.flat(dash.dir)
		local ghost = K.ghost(p.caster, C.memory)
		if ghost then
			ghost:PivotTo(CFrame.lookAt(from, from + dir))
		end
		spawnAt("V2/MemoryEcho", from)
		local fly = K.flyer("V2/MemoryDash", CFrame.lookAt(from, from + dir), { life = time + 0.3 })
		K.loop(time, function(t)
			local k = math.clamp(t / time, 0, 1)
			local pos = from + dir * (dash.length * k)
			fly.move(CFrame.lookAt(pos, pos + dir))
			if ghost and ghost.Parent then
				ghost:PivotTo(CFrame.lookAt(pos, pos + dir))
			end
			return true
		end)
		task.delay(time + 0.05, function()
			if ghost then
				K.dissolve(ghost, 0.3)
			end
		end)
		K.sound(i == 1 and "chronEchoSwing" or "huntDash", from)
	end
	task.delay(time, function()
		local meet = K.ground(p.meet, 0.1)
		spawnAt("V2/MemoryBurst", meet + V3(0, 1, 0), { radius = p.radius })
		groundZone(meet, p.radius or 6, C.memory, 0.6, { fill = 0.8, edge = 0.35, fadeIn = 0.05 })
		K.sound("v2MemoryBurst", meet)
		impact(p.caster, meet, 1.2)
	end)
end

-- ===================== ОВЕРЛЕИ ПОВЕРХ СТАРЫХ ЭФФЕКТОВ =====================

local overlays = {
	garden = {
		reapStart = function(p)
			local origin = K.ground(p.position, 1.4)
			local dir = K.flat(p.direction)
			local length = p.length or 16
			local time = p.waveTime or 0.35
			groundStrip(p.position, dir, length, 4.8, C.green, time + 0.4, 0.8)
			for k = 1, 3 do
				task.delay(time * (k - 1) / 3, function()
					FxKit.spawn("V2/ReapCrescent", CFrame.lookAt(origin + dir * (length * k / 3), origin + dir * (length * k / 3 + 1)), { scale = 1 })
				end)
			end
			hitStop(p.caster, 0.04)
		end,
		rot = function(p)
			if p.model then
				K.onModel("v2Rot", p.model, "V2/RotMark", p.duration or 3, 0.2)
			end
		end,
	},
	hunt = {
		packBite = function(p)
			if typeof(p.position) == "Vector3" then
				spawnAt("V2/Bite", p.position + V3(0, 1.6, 0))
			end
		end,
		snareOpen = function(p)
			local center = K.ground(p.position, 0.1)
			spawnAt("V2/JawRing", center, { radius = p.radius, life = p.snapDelay })
			groundZone(center, p.radius or 7.5, C.prey, (p.snapDelay or 0.45) + 0.1, { fill = 0.9, edge = 0.4, fadeIn = 0.1 })
		end,
		snareSnap = function(p)
			local center = K.ground(p.position, 0.1)
			spawnAt("V2/Jaws", center + V3(0, 1, 0), { scale = 1.5 })
			for _, model in ipairs(p.targets or {}) do
				local root = K.modelPart(model)
				if root then
					spawnAt("V2/Jaws", root.Position)
				end
			end
			impact(p.caster, center, 0.7)
		end,
	},
}

-- ===== Разбор =====

AbilityFxV2.handlers = {
	v2 = {
		eraseField = eraseField,
		eraseFinal = eraseFinal,
		heartPlunge = heartPlunge,
		heartErupt = heartErupt,
		heartBlade = heartBlade,
		heartArc = heartArc,
		pourRaise = pourRaise,
		pourRing = pourRing,
		pourCleave = pourCleave,
		pourSteam = pourSteam,
		falconCall = falconCall,
		falconDive = falconDive,
		falconLeave = falconLeave,
		tideWave = tideWave,
		tideCrash = tideCrash,
		pruneCut = pruneCut,
		pruneVines = pruneVines,
		pruneSnip = pruneSnip,
		huntDash = huntDash,
		huntHorn = huntHorn,
		huntHop = huntHop,
		huntFinale = huntFinale,
		slagCyclone = slagCyclone,
		slagGlobs = slagGlobs,
		slagSlam = slagSlam,
		quillWrite = quillWrite,
		quillCenter = quillCenter,
		inkFan = inkFan,
		inkPull = inkPull,
		inkBurst = inkBurst,
		crucibleTip = crucibleTip,
		searingBlade = searingBlade,
		searingFinale = searingFinale,
		recallStitch = recallStitch,
	},
}

-- Поверх старых эффектов (Жатва, Свора, Капкан): AbilityFx вызывает на каждое событие.
function AbilityFxV2.overlay(payload)
	local set = overlays[payload.kind]
	local fn = set and set[payload.phase]
	if fn then
		local ok, err = pcall(fn, payload)
		if not ok then
			warn("[AbilityFxV2] overlay " .. tostring(payload.kind) .. "/" .. tostring(payload.phase) .. ": " .. tostring(err))
		end
	end
end

-- Текстуры эффектов заранее: свежезагруженные картинки Roblox ещё «готовит»
-- («Asset content representation is being generated») — пусть это случится до первого удара.
function AbilityFxV2.preload()
	task.spawn(function()
		local fx = ReplicatedStorage:WaitForChild("FX", 30)
		if not fx then
			return
		end
		local list, seen = {}, {}
		for _, d in ipairs(fx:GetDescendants()) do
			if d:IsA("ParticleEmitter") and d.Texture ~= "" and not seen[d.Texture] then
				seen[d.Texture] = true
				table.insert(list, d)
			end
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
	end)
end

-- Общие приёмы V2 — для заклинаний мага (MageSpellFxV2), чтобы стандарт был один.
AbilityFxV2.tools = {
	hitStop = hitStop,
	impact = impact,
	groundZone = groundZone,
	groundStrip = groundStrip,
	spawnAt = spawnAt,
	visualOf = visualOf,
}

Players.PlayerRemoving:Connect(function(leaver)
	fields[leaver] = nil
	burning[leaver] = nil
	searing[leaver] = nil
	local state = falcons[leaver]
	if state and state.fly then
		state.fly.stop(0.1)
	end
	falcons[leaver] = nil
end)

return AbilityFxV2
