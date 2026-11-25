--!nonstrict
-- AbilityFx (клиент)
-- Визуал способностей эпического и легендарного оружия по событию AbilityFx
-- (сервер шлёт фазы всем игрокам; урон и цели решает сервер):
--   vortex  — Вихрь-воронка: золотая воронка (спирали, лучи-рукава), три
--             серпа вокруг героя, затягивание на тиках, режущая волна;
--   rift    — Разлом: удар в землю, три трещины с магмой бегут вперёд,
--             через 0,6 с из них бьют каменные шипы;
--   unlock  — Отпереть: ключ летит по дуге и втыкается в землю, печать и
--             цепи к скованным, взрыв цепей, ключ возвращается в руку;
--   keyhole — Скважина: метки 1–3 над врагом, на третьей — удар ключом.
--
-- Внешний вид — шаблоны ReplicatedStorage.FX (цвета, текстуры, размеры
-- правятся в Studio, см. tools/fx/BuildFx.lua). Здесь — только где и когда.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FloorGeo = require(Shared.Floor.FloorGeo)
local Net = require(Shared.Net.Net)
local VoxelWeaponBuilder = require(Shared.Voxel.VoxelWeaponBuilder)

local Bus = require(script.Parent.Parent.Lib.Bus)
local FxKit = require(script.Parent.Parent.Lib.FxKit)
-- Продлённые фазы (кадр удара, обломки, хвосты, звуки) — поверх шаблонов.
local AbilityFxPlus = require(script.Parent.AbilityFxPlus)

local AbilityFx = {}

local player = Players.LocalPlayer
local V3 = Vector3.new
local TAU = math.pi * 2

local SHAKE_RANGE = 40
local FEET = 3 -- R15: ноги ≈ корень − 3

-- ===== Общее =====

local function casterRoot(caster)
	local character = caster and caster.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function groundY(position: Vector3): number
	local ok, y = pcall(FloorGeo.groundAt, position.X, position.Z, position.Y + 1.5)
	if ok and y and math.abs(y - position.Y) < 4 then
		return y
	end
	return position.Y
end

local function onGround(position: Vector3, lift: number?): Vector3
	return V3(position.X, groundY(position) + (lift or 0), position.Z)
end

local function shake(position: Vector3, amount: number, time: number)
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude <= SHAKE_RANGE then
		Bus.emit("shake", { amount = amount, time = time })
	end
end

local function sfx(name: string, position: Vector3?)
	Bus.emit("sfx", { name = name, position = position })
end

local function attachment(parent: Instance, name: string?)
	local a = Instance.new("Attachment")
	a.Name = name or "FxPoint"
	a.Parent = parent
	return a
end

local function modelPart(model: Instance)
	if typeof(model) ~= "Instance" or not model.Parent then
		return nil
	end
	return model:FindFirstChild("Root") or (model:IsA("Model") and model.PrimaryPart) or nil
end

-- ===== Риги: всё, что двигается несколько кадров =====

local rigs = {} -- { update(dt, now) -> keep:boolean, destroy() }

local function addRig(rig)
	table.insert(rigs, rig)
	return rig
end

local function stepRigs(dt: number)
	local t = os.clock()
	for i = #rigs, 1, -1 do
		local rig = rigs[i]
		local ok, keep = pcall(rig.update, dt, t)
		if not ok then
			warn("[AbilityFx] " .. tostring(keep))
		end
		if not ok or not keep then
			if rig.destroy then
				pcall(rig.destroy)
			end
			table.remove(rigs, i)
		end
	end
end

-- ===== Оружие в руке и летающий ключ =====

local function equippedWeapon(caster)
	local character = caster and caster.Character
	return character and character:FindFirstChild("EquippedWeapon", true)
end

-- Спрятать/показать оружие в руке (пока ключ в полёте).
local hiddenWeapons = {} -- [caster] = { part = modifier }
local function hideWeapon(caster, hidden: boolean)
	local weapon = equippedWeapon(caster)
	if hidden then
		if not weapon or hiddenWeapons[caster] then
			return
		end
		local saved = { model = weapon, emitters = {} }
		for _, d in ipairs(weapon:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			elseif (d:IsA("ParticleEmitter") or d:IsA("Light")) and d.Enabled then
				d.Enabled = false
				table.insert(saved.emitters, d)
			end
		end
		hiddenWeapons[caster] = saved
	else
		local saved = hiddenWeapons[caster]
		hiddenWeapons[caster] = nil
		if not saved then
			return
		end
		for _, d in ipairs(saved.model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
			end
		end
		for _, e in ipairs(saved.emitters) do
			if e.Parent then
				e.Enabled = true
			end
		end
	end
end

-- Модель Ключа Привратника (меши или воксели) со следом и искрами из шаблона.
local function makeKey(cframe: CFrame)
	local ok, model = pcall(VoxelWeaponBuilder.build, "sword", {
		weaponId = "gatekeeper_key",
		rarityId = "legendary",
		anchored = true,
		noFx = true,
		name = "ThrownKey",
		baseCFrame = cframe,
		parent = FxKit.folder(),
	})
	if not ok or not model then
		return nil
	end
	local root = model:FindFirstChild("Root")
	local base = root and root:FindFirstChild("BladeBase")
	local tip = root and root:FindFirstChild("BladeTip")
	local handle = tip and FxKit.attach("Unlock/Key", tip, { other = base })
	return {
		model = model,
		length = model:GetAttribute("BladeLength") or 3,
		fx = handle,
	}
end

local function destroyKey(key)
	if not key then
		return
	end
	if key.fx then
		key.fx.destroy()
	end
	if key.model and key.model.Parent then
		key.model:Destroy()
	end
end

-- Кадр ключа по центру и повороту: центр — середина ключа, ось +Y — к острию.
local function placeKey(key, center: Vector3, rotation: CFrame)
	local cf = CFrame.new(center) * rotation * CFrame.new(0, -key.length / 2, 0)
	key.model:PivotTo(cf)
end

-- ===== Вихрь-воронка =====

local vortexRigs = {} -- [caster] = rig

local function vortexStart(payload)
	local caster = payload.caster
	local root = casterRoot(caster)
	if not root then
		return
	end
	local castTime = payload.castTime or 1
	local radius = payload.radius or 5.5
	local old = vortexRigs[caster]
	if old then
		old.finished = true
	end

	local feet = root.Position - V3(0, FEET, 0)
	local funnel = FxKit.spawn("Vortex/Funnel", CFrame.new(onGround(feet, 0.15)), { radius = radius })
	local holder = FxKit.holder()

	-- Три рукава-луча: от кромки по дуге к центру.
	local arms = {}
	for _ = 1, 3 do
		local a0 = attachment(holder)
		local a1 = attachment(holder)
		local beam = FxKit.clone("Vortex/Arm")
		if beam then
			beam.Attachment0 = a0
			beam.Attachment1 = a1
			beam.Parent = holder
		end
		table.insert(arms, { a0 = a0, a1 = a1, beam = beam })
	end

	-- Три серпа: след между внутренней и внешней точкой, на внешней — блик.
	local sickles = {}
	for _ = 1, 3 do
		local inner = attachment(holder)
		local outer = attachment(holder)
		local handle = FxKit.attach("Vortex/Sickle", outer, { other = inner })
		table.insert(sickles, { inner = inner, outer = outer, fx = handle })
	end

	-- След клинка на время кружения.
	local bladeTrail = nil
	local weapon = equippedWeapon(caster)
	local weaponRoot = weapon and weapon:FindFirstChild("Root")
	local base = weaponRoot and weaponRoot:FindFirstChild("BladeBase")
	local tip = weaponRoot and weaponRoot:FindFirstChild("BladeTip")
	if base and tip then
		bladeTrail = FxKit.clone("Vortex/BladeTrail")
		if bladeTrail then
			bladeTrail.Attachment0 = base
			bladeTrail.Attachment1 = tip
			bladeTrail.Parent = weaponRoot
		end
	end

	local started = os.clock()
	local spin = 0
	local rig
	rig = {
		finished = false,
		update = function(dt, now)
			local current = casterRoot(caster)
			local e = now - started
			if rig.finished or not current or e > castTime + 0.05 then
				return false
			end
			local k = math.clamp(e / castTime, 0, 1)
			spin += dt * (8 + 14 * k)
			local center = current.Position
			local ground = onGround(center - V3(0, FEET, 0), 0.2)
			if funnel then
				funnel.root.CFrame = CFrame.new(ground)
			end
			-- Рукава закручиваются и сжимаются к герою.
			local r = radius * (1 - 0.35 * k)
			for i, arm in ipairs(arms) do
				local a = spin * 0.9 + i * TAU / 3
				local dir = V3(math.cos(a), 0, math.sin(a))
				local tangent = V3(-dir.Z, 0, dir.X)
				arm.a0.WorldCFrame = CFrame.fromMatrix(ground + dir * r, tangent, dir)
				arm.a1.WorldCFrame = CFrame.fromMatrix(ground + dir * 0.4, tangent, dir)
				if arm.beam then
					arm.beam.CurveSize0 = r * 0.9
					arm.beam.CurveSize1 = 0
				end
			end
			-- Серпы летают вокруг корпуса быстрее, чем он крутится.
			for i, s in ipairs(sickles) do
				local a = -spin * 1.5 + i * TAU / 3
				local dir = V3(math.cos(a), 0, math.sin(a))
				local bob = 0.25 * math.sin(e * 6 + i * 2)
				s.inner.WorldPosition = center + dir * 2.2 + V3(0, -0.6 + bob, 0)
				s.outer.WorldPosition = center + dir * 3.7 + V3(0, -0.3 + bob, 0)
			end
			return true
		end,
		destroy = function()
			if vortexRigs[caster] == rig then
				vortexRigs[caster] = nil
			end
			if funnel then
				funnel.stop()
			end
			for _, arm in ipairs(arms) do
				if arm.beam then
					FxKit.fade(arm.beam, 0.2)
				end
			end
			for _, s in ipairs(sickles) do
				if s.fx then
					s.fx.stop()
				end
			end
			Debris:AddItem(holder, 0.45)
			if bladeTrail then
				bladeTrail.Enabled = false
				Debris:AddItem(bladeTrail, 0.3)
			end
		end,
	}
	vortexRigs[caster] = rig
	addRig(rig)
	sfx("vortexSpin", feet)
end

local function vortexTick(payload)
	local center = payload.position
	if not center then
		return
	end
	local ground = onGround(center, 0.2)
	FxKit.spawn("Vortex/Pull", CFrame.new(ground), { radius = payload.radius })
	if (payload.hits or 0) > 0 then
		shake(ground, 0.18, 0.12)
	end
end

local function vortexWave(payload)
	local center = payload.position
	if not center then
		return
	end
	local radius = payload.radius or 7
	local ground = onGround(center, 0.2)
	FxKit.spawn("Vortex/Wave", CFrame.new(ground), { radius = radius })
	FxKit.spawn("Common/Dust", CFrame.new(ground), { scale = radius / 6 })
	shake(ground, 0.5, 0.3)
	sfx("vortexWave", ground)
end

-- ===== Разлом =====

local riftStates = {} -- [caster] = state

-- Зигзаг трещины по земле: точки от центра до конца.
local function crackPoints(center: Vector3, direction: Vector3, length: number)
	local right = V3(-direction.Z, 0, direction.X)
	local steps = math.max(3, math.ceil(length / 1.4))
	local rng = Random.new(math.floor(center.X * 13 + center.Z * 7 + direction.X * 101 + length * 31))
	local points = { onGround(center, 0.06) }
	for i = 1, steps do
		local along = length * i / steps
		local jitter = (i < steps) and rng:NextNumber(-0.55, 0.55) or rng:NextNumber(-0.2, 0.2)
		table.insert(points, onGround(center + direction * along + right * jitter, 0.06))
	end
	return points
end

local function drawCrack(state, center: Vector3, crack, crackTime: number)
	local points = crackPoints(center, crack.direction, crack.length)
	local count = #points - 1
	for i = 1, count do
		local p0, p1 = points[i], points[i + 1]
		local delay = crackTime * (i - 1) / count
		task.delay(delay, function()
			if state.done then
				return
			end
			local along = p1 - p0
			local a0 = attachment(state.holder)
			local a1 = attachment(state.holder)
			a0.WorldCFrame = FxKit.flatFrame(p0, along)
			a1.WorldCFrame = FxKit.flatFrame(p1, along)
			local taper0 = 1 - (i - 1) / count * 0.55
			local taper1 = 1 - i / count * 0.55
			for _, path in ipairs({ "Rift/Crack", "Rift/Magma" }) do
				local beam = FxKit.clone(path)
				if beam then
					beam.Width0 *= taper0
					beam.Width1 *= taper1
					beam.Attachment0 = a0
					beam.Attachment1 = a1
					beam.Parent = state.holder
					table.insert(path == "Rift/Magma" and state.magma or state.beams, beam)
				end
			end
			local mid = (p0 + p1) / 2
			local len = along.Magnitude
			local embers = FxKit.spawn("Rift/CrackFx", CFrame.lookAt(mid, mid + along), { size = V3(0.6 * taper0, 0.2, len) })
			if embers then
				table.insert(state.embers, embers)
			end
		end)
		-- Шипы — через отрезок, начиная со второго.
		if i % 2 == 0 or i == count then
			table.insert(state.spikes, { position = p1, direction = crack.direction })
		end
	end
end

local function riftSlam(payload)
	local center = payload.position
	if not center then
		return
	end
	local caster = payload.caster
	local old = riftStates[caster]
	if old then
		old.done = true
		old.holder:Destroy()
	end
	local ground = onGround(center, 0.2)
	FxKit.spawn("Rift/Slam", CFrame.new(ground), { radius = payload.radius })
	shake(ground, 0.9, 0.4)
	sfx("riftSlam", ground)

	local state = { holder = FxKit.holder(), beams = {}, magma = {}, embers = {}, spikes = {}, done = false }
	riftStates[caster] = state
	for _, crack in ipairs(payload.cracks or {}) do
		drawCrack(state, center, crack, payload.crackTime or 0.25)
	end

	-- Магма пульсирует всё чаще до взрыва.
	local eruptAt = os.clock() + (payload.eruptDelay or 0.6)
	local started = os.clock()
	addRig({
		update = function(_, now)
			if state.done or now > eruptAt + 0.05 then
				return false
			end
			local k = math.clamp((now - started) / (eruptAt - started), 0, 1)
			local pulse = 0.5 + 0.5 * math.sin(now * (10 + 30 * k))
			for _, beam in ipairs(state.magma) do
				beam.Brightness = 2 + 3 * k + pulse * 1.5
			end
			return true
		end,
	})
end

-- Каменный шип вырывается из земли, стоит ~1,4 с и рассыпается обломками (AbilityFxPlus).
local SPIKE_HOLD = 1.4
local function spike(position: Vector3, direction: Vector3, delay: number)
	local model = FxKit.clone("Rift/Spike")
	if not model then
		return
	end
	local height = model:GetAttribute("Height") or 4
	local scale = 0.75 + math.random() * 0.5
	pcall(model.ScaleTo, model, scale)
	height *= scale
	-- Наклон наружу от трещины и случайный поворот.
	local tilt = CFrame.fromAxisAngle(V3(-direction.Z, 0, direction.X), math.rad(math.random(8, 22)))
	local yaw = CFrame.Angles(0, math.random() * TAU, 0)
	local up = CFrame.new(position) * tilt * yaw
	local down = up * CFrame.new(0, -height - 0.3, 0)
	model:PivotTo(down)
	model.Parent = FxKit.folder()
	local started = os.clock() + delay
	local burst = false
	addRig({
		update = function(_, now)
			local e = now - started
			if e < 0 then
				return true
			end
			if not burst then
				burst = true
				FxKit.spawn("Rift/SpikeBurst", CFrame.new(position))
			end
			local cf
			if e < 0.09 then
				local k = 1 - (1 - e / 0.09) ^ 3
				cf = down:Lerp(up, k)
			elseif e < SPIKE_HOLD then
				-- Стоит; под конец мелко дрожит перед тем, как рассыпаться.
				local shiver = math.clamp((e - (SPIKE_HOLD - 0.35)) / 0.35, 0, 1)
				cf = shiver > 0 and up * CFrame.new((math.random() - 0.5) * 0.12 * shiver, 0, (math.random() - 0.5) * 0.12 * shiver) or up
			else
				local color = nil
				local part = model:FindFirstChildWhichIsA("BasePart", true)
				if part then
					color = part.Color
				end
				pcall(AbilityFxPlus.spikeCrumble, position, height, color)
				return false
			end
			model:PivotTo(cf)
			return true
		end,
		destroy = function()
			model:Destroy()
		end,
	})
end

local function riftErupt(payload)
	local center = payload.position
	if not center then
		return
	end
	local caster = payload.caster
	local state = riftStates[caster]
	if not state then
		-- Пропустили удар (зашёл позже): рисуем трещины сразу.
		state = { holder = FxKit.holder(), beams = {}, magma = {}, embers = {}, spikes = {}, done = false }
		for _, crack in ipairs(payload.cracks or {}) do
			drawCrack(state, center, crack, 0)
		end
	end
	riftStates[caster] = nil
	state.done = true

	for index, s in ipairs(state.spikes) do
		spike(s.position, s.direction, index * 0.015)
	end
	for _, beam in ipairs(state.magma) do
		beam.Brightness = 6
		FxKit.fade(beam, 0.9)
	end
	for _, beam in ipairs(state.beams) do
		FxKit.fade(beam, 1.1)
	end
	for _, embers in ipairs(state.embers) do
		embers.stop()
	end
	Debris:AddItem(state.holder, 1.2)
	local ground = onGround(center, 0.2)
	shake(ground, 0.6, 0.3)
	sfx("riftErupt", ground)
end

-- ===== Отпереть =====

local unlockStates = {} -- [caster] = { key, chains, seal, holder }

local function unlockThrow(payload)
	local from, target = payload.from, payload.target
	if not from or not target then
		return
	end
	local caster = payload.caster
	local old = unlockStates[caster]
	if old then
		destroyKey(old.key)
		if old.holder then
			old.holder:Destroy()
		end
	end
	local flight = payload.flightTime or 0.5
	local key = makeKey(CFrame.new(from))
	local state = { key = key, chains = {}, landed = false }
	unlockStates[caster] = state
	hideWeapon(caster, true)
	sfx("unlockThrow", from)
	-- Страховка: что бы ни случилось, оружие вернётся в руку.
	task.delay(flight + 4, function()
		if unlockStates[caster] == state then
			destroyKey(state.key)
			unlockStates[caster] = nil
		end
		hideWeapon(caster, false)
	end)
	if not key then
		return
	end

	local landing = target + V3(0, key.length * 0.1, 0) -- остриё уходит в землю
	local flatDir = V3(target.X - from.X, 0, target.Z - from.Z)
	if flatDir.Magnitude < 0.05 then
		local root = casterRoot(caster)
		flatDir = root and V3(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) or V3(0, 0, -1)
	end
	flatDir = flatDir.Unit
	local arc = 1.5 + flatDir:Dot(target - from) * 0.12
	local facing = CFrame.lookAt(V3(), flatDir)
	local started = os.clock()
	addRig({
		update = function(_, now)
			if unlockStates[caster] ~= state then
				return false
			end
			local k = math.clamp((now - started) / flight, 0, 1)
			local center = from:Lerp(landing, k) + V3(0, arc * 4 * k * (1 - k), 0)
			-- Два оборота «через голову»; на земле — остриём вниз с наклоном.
			local turn = -(math.pi * (1 + 4 * k) + 0.3 * k)
			placeKey(key, center, facing * CFrame.Angles(turn, 0, 0))
			if k >= 1 then
				state.landed = true
				state.rest = { center = center, rotation = facing * CFrame.Angles(turn, 0, 0) }
				FxKit.spawn("Unlock/Impact", CFrame.new(onGround(target, 0.15)))
				shake(target, 0.4, 0.2)
				return false
			end
			return true
		end,
	})
end

local function unlockLock(payload)
	local center = payload.position
	if not center then
		return
	end
	local caster = payload.caster
	local state = unlockStates[caster] or { chains = {} }
	unlockStates[caster] = state
	local radius = payload.radius or 10
	local bindTime = payload.bindTime or 1
	local ground = onGround(center, 0.12)

	state.seal = FxKit.spawn("Unlock/Seal", CFrame.new(ground), { radius = radius, life = bindTime + 0.3 })
	state.holder = state.holder or FxKit.holder()
	shake(ground, 0.3, 0.2)
	sfx("unlockLock", ground)

	-- Цепи: по две от земли с боков врага и одна от ключа. Цепь «выстреливает»
	-- из точки на земле и цепляется за врага.
	for _, model in ipairs(payload.targets or {}) do
		local part = modelPart(model)
		if part then
			local endPoint = attachment(part, "ChainEnd")
			local endFx = FxKit.attach("Unlock/ChainEnd", endPoint)
			local enemyGround = onGround(part.Position - V3(0, (model:GetAttribute("EnemyHeight") or 5) / 2, 0), 0.1)
			local toEnemy = V3(enemyGround.X - ground.X, 0, enemyGround.Z - ground.Z)
			local dir = toEnemy.Magnitude > 0.1 and toEnemy.Unit or V3(1, 0, 0)
			local side = V3(-dir.Z, 0, dir.X)
			local anchors = {
				enemyGround + side * 2.6 - dir * 0.6,
				enemyGround - side * 2.6 - dir * 0.6,
				ground + dir * 0.6,
			}
			local entry = { endPoint = endPoint, endFx = endFx, beams = {}, part = part }
			for index, anchorPoint in ipairs(anchors) do
				local a0 = attachment(state.holder)
				a0.WorldCFrame = CFrame.fromMatrix(anchorPoint, V3(0, 1, 0), dir)
				local tipPoint = attachment(state.holder)
				tipPoint.WorldPosition = anchorPoint
				local beam = FxKit.clone("Unlock/Chain")
				if beam then
					beam.Attachment0 = a0
					beam.Attachment1 = tipPoint
					beam.Parent = state.holder
					table.insert(entry.beams, { beam = beam, a0 = a0, tip = tipPoint, from = anchorPoint, delay = (index - 1) * 0.04 })
				end
			end
			table.insert(state.chains, entry)
		end
	end

	local started = os.clock()
	addRig({
		update = function(_, now)
			if unlockStates[caster] ~= state or state.opened then
				return false
			end
			local e = now - started
			for _, entry in ipairs(state.chains) do
				if entry.part.Parent then
					for _, link in ipairs(entry.beams) do
						local k = math.clamp((e - link.delay) / 0.12, 0, 1)
						if k < 1 then
							link.tip.WorldPosition = link.from:Lerp(entry.endPoint.WorldPosition, 1 - (1 - k) ^ 2)
						elseif link.beam.Attachment1 ~= entry.endPoint then
							link.beam.Attachment1 = entry.endPoint
						end
						-- Натянутая цепь дрожит.
						link.beam.CurveSize0 = (1 - k) * 2 + math.sin(now * 40 + link.delay * 50) * 0.12
					end
				end
			end
			return e < bindTime + 0.5
		end,
	})
end

local function unlockOpen(payload)
	local center = payload.position
	if not center then
		return
	end
	local caster = payload.caster
	local radius = payload.radius or 10
	local ground = onGround(center, 0.3)
	local state = unlockStates[caster]

	FxKit.spawn("Unlock/Burst", CFrame.new(ground), { radius = radius })
	FxKit.shockwave(ground + V3(0, 0.8, 0), radius * 1.05)
	shake(ground, 1.0, 0.45)
	sfx("unlockOpen", ground)

	if not state then
		return
	end
	state.opened = true
	-- Цепи рвутся: вспышка у каждого врага.
	for _, entry in ipairs(state.chains) do
		if entry.part.Parent then
			FxKit.spawn("Common/Flash", CFrame.new(entry.endPoint.WorldPosition), { scale = 0.6 })
		end
		if entry.endFx then
			entry.endFx.stop()
		end
		Debris:AddItem(entry.endPoint, 0.5)
	end
	state.chains = {}
	if state.seal then
		state.seal.stop()
	end
	if state.holder then
		state.holder:Destroy()
		state.holder = nil
	end

	-- Ключ возвращается в руку.
	local key = state.key
	if not key or not key.model.Parent then
		unlockStates[caster] = nil
		hideWeapon(caster, false)
		return
	end
	local rest = state.rest or { center = key.model:GetPivot().Position, rotation = CFrame.new() }
	local started = os.clock()
	local back = 0.35
	addRig({
		update = function(_, now)
			local root = casterRoot(caster)
			local k = math.clamp((now - started) / back, 0, 1)
			local hand = root and (root.Position + root.CFrame.LookVector * 0.8 + V3(0, 0.6, 0)) or rest.center
			local eased = k * k
			local position = rest.center:Lerp(hand, eased) + V3(0, 2.5 * 4 * k * (1 - k), 0)
			placeKey(key, position, rest.rotation * CFrame.Angles(-k * TAU * 1.5, 0, 0))
			return k < 1
		end,
		destroy = function()
			if unlockStates[caster] == state then
				unlockStates[caster] = nil
			end
			local root = casterRoot(caster)
			if root then
				FxKit.spawn("Common/Flash", CFrame.new(root.Position + root.CFrame.LookVector * 0.8 + V3(0, 0.6, 0)), { scale = 0.35 })
			end
			destroyKey(key)
			hideWeapon(caster, false)
		end,
	})
end

-- ===== Скважина =====

local marks = {} -- [model] = { part, points, icons, untilT, ... }

local function clearMark(model)
	local m = marks[model]
	if m then
		for _, point in ipairs(m.points) do
			point:Destroy()
		end
		marks[model] = nil
	end
end

local function keyholeMark(payload)
	local model = payload.model
	local part = modelPart(model)
	local template = FxKit.template("Keyhole/Mark")
	if not part or not template then
		return
	end
	local m = marks[model]
	if not m then
		m = {
			part = part,
			points = {},
			icons = {},
			height = model:GetAttribute("EnemyHeight") or 5,
			spacing = template:GetAttribute("Spacing") or 0.85,
			on = template:GetAttribute("OnColor") or Color3.fromRGB(255, 181, 54),
			off = template:GetAttribute("OffColor") or Color3.fromRGB(90, 67, 48),
		}
		for i = 1, 3 do
			local point = attachment(part, "Keyhole" .. i)
			table.insert(m.points, point)
			table.insert(m.icons, FxKit.attach("Keyhole/Mark", point))
		end
		marks[model] = m
	end
	m.untilT = payload.untilT or (Workspace:GetServerTimeNow() + 8)
	local count = math.clamp(payload.count or 1, 1, 3)
	for i, handle in ipairs(m.icons) do
		for _, item in ipairs(handle and handle.items or {}) do
			if item:IsA("ParticleEmitter") then
				item.Color = ColorSequence.new(i <= count and m.on or m.off)
				item.Transparency = NumberSequence.new(i <= count and 0 or 0.45)
				if not m.baseSize then
					m.baseSize = item.Size
				end
			end
		end
	end
	m.popIndex = count
	m.popAt = os.clock()
	FxKit.spawn("Common/Flash", CFrame.new(part.Position + V3(0, m.height / 2 + 1.2, 0)), { scale = 0.25 })
end

local function keyholeBurst(payload)
	local model = payload.model
	clearMark(model)
	local part = modelPart(model)
	local position = part and part.Position or payload.position
	if not position then
		return
	end
	local height = (part and model:GetAttribute("EnemyHeight")) or 5
	local top = position + V3(0, height / 2 + 3, 0)
	local hit = position + V3(0, height * 0.15, 0)
	sfx("keyholeBurst", hit)
	local key = makeKey(CFrame.new(top))
	if not key then
		FxKit.spawn("Keyhole/Burst", CFrame.new(hit))
		return
	end
	-- Ключ из света падает остриём вниз и проворачивается в «скважине».
	local down = CFrame.Angles(math.pi, 0, 0)
	local started = os.clock()
	local struck = false
	addRig({
		update = function(_, now)
			local e = now - started
			local k = math.clamp(e / 0.14, 0, 1)
			local center = top:Lerp(hit + V3(0, key.length * 0.35, 0), k * k)
			local twist = e > 0.14 and math.min((e - 0.14) / 0.18, 1) * math.pi / 2 or 0
			placeKey(key, center, down * CFrame.Angles(0, twist, 0))
			if e >= 0.14 and not struck then
				struck = true
				FxKit.spawn("Keyhole/Burst", CFrame.new(hit))
				shake(hit, 0.3, 0.15)
			end
			if e > 0.3 then
				local f = math.clamp((e - 0.3) / 0.15, 0, 1)
				for _, d in ipairs(key.model:GetDescendants()) do
					if d:IsA("BasePart") then
						d.LocalTransparencyModifier = f
					end
				end
			end
			return e < 0.45
		end,
		destroy = function()
			destroyKey(key)
		end,
	})
end

local function stepMarks()
	local serverNow = Workspace:GetServerTimeNow()
	local camera = Workspace.CurrentCamera
	local right = camera and camera.CFrame.RightVector or V3(1, 0, 0)
	right = V3(right.X, 0, right.Z)
	right = right.Magnitude > 0.01 and right.Unit or V3(1, 0, 0)
	local now = os.clock()
	for model, m in pairs(marks) do
		if not model.Parent or not m.part.Parent or serverNow > (m.untilT or 0) or (model:GetAttribute("EnemyHealth") or 1) <= 0 then
			clearMark(model)
		else
			local base = m.part.Position + V3(0, m.height / 2 + 2.1 + math.sin(now * 3) * 0.06, 0)
			for i, point in ipairs(m.points) do
				point.WorldPosition = base + right * ((i - 2) * m.spacing)
			end
			-- Новая метка «впрыгивает»: крупнее и сжимается за 0,2 с.
			local k = math.clamp((now - (m.popAt or 0)) / 0.2, 0, 1)
			local icon = m.icons[m.popIndex or 0]
			if icon and m.baseSize and k <= 1 then
				local scale = 1 + 0.7 * (1 - k)
				local points = {}
				for _, kp in ipairs(m.baseSize.Keypoints) do
					table.insert(points, NumberSequenceKeypoint.new(kp.Time, kp.Value * scale))
				end
				for _, item in ipairs(icon.items) do
					if item:IsA("ParticleEmitter") then
						item.Size = NumberSequence.new(points)
					end
				end
			end
		end
	end
end

-- ===== Разбор событий =====

local HANDLERS = {
	vortex = { start = vortexStart, tick = vortexTick, wave = vortexWave },
	rift = { slam = riftSlam, erupt = riftErupt },
	unlock = { throw = unlockThrow, lock = unlockLock, open = unlockOpen },
	keyhole = { mark = keyholeMark, burst = keyholeBurst },
}
-- Этаж 2 «Затопленные сады»: kind = "garden" (Controllers/AbilityFxGarden).
for kind, set in pairs(require(script.Parent.AbilityFxGarden).handlers) do
	HANDLERS[kind] = set
end
-- Этажи 3–5: kind = "hunt" / "forge" / "chron" (Controllers/AbilityFxHunt, AbilityFxForge, AbilityFxChronicle).
-- Без этой регистрации события оружия этажей 3–5 приходили, но не находили обработчика — способности
-- работали без картинки и без звука. Ошибка одного модуля не должна ломать остальные — pcall.
-- Переделанные способности мечей и молотов (07.11.2026): kind = "v2" (Controllers/AbilityFxV2).
for _, name in ipairs({ "AbilityFxHunt", "AbilityFxForge", "AbilityFxChronicle", "AbilityFxV2" }) do
	local module = script.Parent:FindFirstChild(name)
	if module then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" and type(result.handlers) == "table" then
			for kind, set in pairs(result.handlers) do
				HANDLERS[kind] = set
			end
		else
			warn("[AbilityFx] " .. name .. ": " .. tostring(result))
		end
	end
end

local okV2, AbilityFxV2 = pcall(require, script.Parent.AbilityFxV2)
if not okV2 then
	warn("[AbilityFx] AbilityFxV2: " .. tostring(AbilityFxV2))
	AbilityFxV2 = nil
end

local function onEvent(payload)
	if type(payload) ~= "table" then
		return
	end
	local set = HANDLERS[payload.kind]
	local handler = set and set[payload.phase]
	if handler then
		local ok, err = pcall(handler, payload)
		if not ok then
			warn("[AbilityFx] " .. tostring(payload.kind) .. "/" .. tostring(payload.phase) .. ": " .. tostring(err))
		end
	end
	-- Продлённые фазы поверх основного эффекта.
	AbilityFxPlus.onEvent(payload)
	-- V2: подтянутый визуал поверх старых (Жатва, Свора, Капкан).
	if AbilityFxV2 then
		AbilityFxV2.overlay(payload)
	end
end

function AbilityFx.start()
	local remote = Net.get("AbilityFx")
	if remote then
		remote.OnClientEvent:Connect(onEvent)
	end
	if AbilityFxV2 then
		AbilityFxV2.preload()
	end
	RunService.RenderStepped:Connect(function(dt)
		stepRigs(dt)
		stepMarks()
	end)
	Players.PlayerRemoving:Connect(function(leaver)
		local rig = vortexRigs[leaver]
		if rig then
			rig.finished = true
		end
		local rift = riftStates[leaver]
		if rift then
			rift.done = true
			rift.holder:Destroy()
			riftStates[leaver] = nil
		end
		local unlock = unlockStates[leaver]
		if unlock then
			destroyKey(unlock.key)
			if unlock.holder then
				unlock.holder:Destroy()
			end
			unlockStates[leaver] = nil
		end
		hiddenWeapons[leaver] = nil
		AbilityFxPlus.forget(leaver)
	end)
	print("[AbilityFx] способности оружия: вихрь, разлом, отпереть, скважина, сады, охота, горн, летопись (шаблоны FX)")
end

-- Для проверок без сервера (Command Bar в Play): AbilityFx.debug(payload).
AbilityFx.debug = onEvent

return AbilityFx
