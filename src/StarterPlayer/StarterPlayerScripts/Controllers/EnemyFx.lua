--!nonstrict
-- EnemyFx (клиент)
-- Эффекты врагов по ТЗ врагов этажа 1 (раздел 2.3 и особые телеграфы 2.4):
--   * кольцо под ногами по роли, подсветка Highlight (телеграф, попадание,
--     оглушение), свечение оружия на замахе, круги на земле;
--   * особые телеграфы: стрелка рывка Тени и тарана босса (FX.Enemy.DashArrow),
--     прицельная линия и коридор выстрела стрелка (FX.Enemy.AimLine/AimGround),
--     тетива стрелка, фитиль и заряды Треснувшего, иконки и падающие цепи
--     Привратника, трещины и скважина II фазы;
--   * появление (пыль памяти), распад на пыль и осколки, душа, взрыв —
--     партиклы из шаблонов ReplicatedStorage.FX.Enemy;
--   * эффекты маркеров анимаций (Step, Hit, Release, AimLine, Scrape,
--     EyesOn, Crack, Roar), стрелы стрелка поверх серверного снаряда.
-- Не контроллер: им управляет EnemyVisualController (attach / update /
-- onMarker / onEvent / step / flush).
--
-- Производительность: временные детали берутся из пулов, перемещение
-- собирается в один BulkMoveTo за кадр (flush), Highlight — из пула (Roblox
-- рисует не больше 31 одновременно). В кадре ничего не создаётся.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anim = require(Shared.Util.Anim)
local Palette = require(Shared.Config.Palette)
local EnemyVisuals = require(Shared.Config.EnemyVisuals)
local Sfx = require(Shared.Config.Sfx)

local Bus = require(script.Parent.Parent.Lib.Bus)
local FxKit = require(script.Parent.Parent.Lib.FxKit)
local EnemyAura = require(script.Parent.EnemyAura)

local EnemyFx = {}

local hideGroundBeam, dashArrow -- объявлены ниже (стрелки на земле)

local V = Palette.Voxel
local FX = EnemyVisuals.Fx
local V3 = Vector3.new
local FAR = CFrame.new(0, -2000, 0)
local DISC_TURN = CFrame.Angles(0, 0, math.rad(90))
local TAU = math.pi * 2
local AIM_REACH = 38 -- длина зафиксированного прицела (= shotRange стрелка)

local player = Players.LocalPlayer
local random = Random.new()

-- ===== Папка, пулы, перемещение =====

local fxFolder

local function folder()
	if fxFolder and fxFolder.Parent then
		return fxFolder
	end
	fxFolder = Workspace:FindFirstChild("EnemyFx")
	if not fxFolder then
		fxFolder = Instance.new("Folder")
		fxFolder.Name = "EnemyFx"
		fxFolder.Parent = Workspace
	end
	return fxFolder
end

local pools = { cube = {}, glow = {}, disc = {}, ball = {} }

local function make(kind: string)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = kind == "cube" and Enum.Material.SmoothPlastic or Enum.Material.Neon
	if kind == "disc" then
		part.Shape = Enum.PartType.Cylinder
	elseif kind == "ball" then
		part.Shape = Enum.PartType.Ball
	end
	part.CFrame = FAR
	part.Parent = folder()
	return part
end

local function acquire(kind: string, size: Vector3, color: Color3, transparency: number?)
	local part = table.remove(pools[kind]) or make(kind)
	part.Size = size
	part.Color = color
	part.Transparency = transparency or 0
	return part
end

local function release(kind: string, part: BasePart)
	part.Transparency = 1
	part.CFrame = FAR
	table.insert(pools[kind], part)
end

local moveParts, moveCFrames = {}, {}

local function queue(part: BasePart, cf: CFrame)
	local index = #moveParts + 1
	moveParts[index] = part
	moveCFrames[index] = cf
end
EnemyFx.queue = queue

function EnemyFx.flush()
	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(moveParts)
		table.clear(moveCFrames)
	end
end

-- Highlight: пул на весь клиент.
local highlightFree = {}
local highlightCount = 0

local function takeHighlight(model: Model)
	local highlight = table.remove(highlightFree)
	if not highlight then
		if highlightCount >= FX.highlightPool then
			return nil
		end
		highlightCount += 1
		highlight = Instance.new("Highlight")
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = folder()
	end
	highlight.Adornee = model
	highlight.Enabled = true
	return highlight
end

local function giveHighlight(highlight)
	highlight.Enabled = false
	highlight.Adornee = nil
	table.insert(highlightFree, highlight)
end

-- Эмиттеры для вспышек частиц (один держатель на вид).
local emitters = {}

local function emitter(name: string, configure)
	local holder = Instance.new("Part")
	holder.Name = "Emitter_" .. name
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = V3(0.2, 0.2, 0.2)
	holder.CFrame = FAR
	holder.Parent = folder()
	local particles = Instance.new("ParticleEmitter")
	particles.Enabled = false
	particles.Rate = 0
	configure(particles)
	particles.Parent = holder
	emitters[name] = { part = holder, emitter = particles }
end

local function burst(name: string, position: Vector3, count: number)
	local entry = emitters[name]
	if entry and count > 0 then
		entry.part.CFrame = CFrame.new(position)
		entry.emitter:Emit(count)
	end
end

local function seq(a: number, b: number)
	return NumberSequence.new(a, b)
end

-- Текстура из шаблона FX (тот же вид, что у способностей), иначе штатная.
local function templateTexture(path: string, emitterName: string): string?
	local template = FxKit.template(path)
	local source = template and template:FindFirstChild(emitterName, true)
	return source and source:IsA("ParticleEmitter") and source.Texture or nil
end

local function setupEmitters()
	local smokeTexture = templateTexture("Common/Dust", "Smoke")
	local sparkTexture = templateTexture("Common/Flash", "Sparks")
	emitter("dust", function(p)
		p.Texture = smokeTexture or p.Texture
		p.Rotation = NumberRange.new(0, 360)
		p.Lifetime = NumberRange.new(0.4, 0.8)
		p.Speed = NumberRange.new(2, 6)
		p.SpreadAngle = Vector2.new(180, 30)
		p.Acceleration = V3(0, -2, 0)
		p.Color = ColorSequence.new(V.W)
		p.Size = seq(0.5, 1.4)
		p.Transparency = seq(0.5, 1)
	end)
	emitter("sparks", function(p)
		p.Texture = sparkTexture or p.Texture
		p.Orientation = Enum.ParticleOrientation.VelocityParallel
		p.Lifetime = NumberRange.new(0.15, 0.35)
		p.Speed = NumberRange.new(8, 18)
		p.SpreadAngle = Vector2.new(70, 70)
		p.Acceleration = V3(0, -30, 0)
		p.LightEmission = 1
		p.Color = ColorSequence.new(V.H, V.A)
		p.Size = seq(0.25, 0)
	end)
	emitter("explode", function(p)
		p.Texture = sparkTexture or p.Texture
		p.Orientation = Enum.ParticleOrientation.VelocityParallel
		p.Lifetime = NumberRange.new(0.3, 0.6)
		p.Speed = NumberRange.new(10, 24)
		p.SpreadAngle = Vector2.new(180, 180)
		p.Acceleration = V3(0, -20, 0)
		p.LightEmission = 1
		p.Color = ColorSequence.new(V.X, V.A)
		p.Size = seq(0.5, 0)
	end)
end

-- ===== Кольца и вспышки (шаблоны FX.Enemy.Ring / Flash) =====

-- Перекрасить и перевременить эмиттеры свежего эффекта: выброс идёт со
-- следующего кадра (FxKit), поэтому правка успевает.
local function tune(handle, color: Color3?, time: number?)
	if not handle then
		return
	end
	for _, d in ipairs(handle.root:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			if color then
				d.Color = ColorSequence.new(color)
			end
			if time then
				d.Lifetime = NumberRange.new(time)
			end
		end
	end
end

local function ring(center: Vector3, radius: number, color: Color3, time: number, _thickness: number?)
	local handle = FxKit.spawn("Enemy/Ring", CFrame.new(center.X, (center.Y or 0) + 0.2, center.Z), { radius = radius })
	tune(handle, color, time)
end

local function flash(position: Vector3, _from: number, to: number, color: Color3, time: number)
	local handle = FxKit.spawn("Enemy/Flash", CFrame.new(position), { scale = to })
	tune(handle, color, time)
end

local souls = {}

-- ===== Точки на модели =====

-- Точка эффекта: FX_* (через ObjectValue в папке FX или поиском).
local function fxPoint(rig, name: string): Attachment?
	local cache = rig.fx.points
	local cached = cache[name]
	if cached ~= nil then
		return cached or nil
	end
	local found = nil
	local fxFolderInModel = rig.model:FindFirstChild("FX")
	local link = fxFolderInModel and fxFolderInModel:FindFirstChild(name)
	if link and link:IsA("ObjectValue") and link.Value and link.Value:IsA("Attachment") then
		found = link.Value
	else
		local direct = rig.model:FindFirstChild(name, true)
		if direct and direct:IsA("Attachment") then
			found = direct
		end
	end
	cache[name] = found or false
	return found
end

local function headTop(rig): Vector3
	local point = fxPoint(rig, "FX_HeadTop")
	if point and rig.model.Parent then
		return point.WorldPosition
	end
	return rig.pos + V3(0, rig.stats.height + 0.6, 0)
end
EnemyFx.headTop = headTop

local function bodyCenter(rig): Vector3
	return rig.pos + V3(0, rig.stats.height * 0.55, 0)
end

local function localRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function sound(name: string?, position: Vector3?)
	if name then
		Bus.emit("sfx", { name = name, position = position })
	end
end

local function shake(amount: number, time: number)
	Bus.emit("shake", { amount = amount, time = time })
end

-- ===== Подключение врага =====

local BODY_RANK = {
	RightFoot = 0, LeftFoot = 0,
	RightLowerLeg = 1, LeftLowerLeg = 1, RightUpperLeg = 1, LeftUpperLeg = 1,
	LowerTorso = 2,
	UpperTorso = 3,
	RightLowerArm = 4, LeftLowerArm = 4, RightHand = 4, LeftHand = 4,
	RightUpperArm = 5, LeftUpperArm = 5,
	Head = 6,
}
local WEAPON_RANK = 7

local function voxelColors(part: BasePart): { Color3 }
	-- Генератор брони пишет три самых частых цвета детали в атрибут Colors
	-- («RGA» — буквы палитры). У заглушки — цвет самой детали.
	local letters = part:GetAttribute("Colors")
	if type(letters) == "string" and #letters > 0 then
		local list = {}
		for index = 1, #letters do
			local color = V[string.sub(letters, index, index)]
			if color then
				table.insert(list, color)
			end
		end
		if #list > 0 then
			return list
		end
	end
	return { part.Color }
end

function EnemyFx.attach(rig)
	local model = rig.model
	local fx: any = {
		points = {},
		body = {}, -- { part, base }
		armor = {}, -- { part, base, weld, body, rest, rank }
		weapon = {}, -- { part, base, color, material }
		weaponMotors = {},
		eyes = {},
		cracks = {},
		cracks2 = {},
		bombs = {},
		chains = {},
		keyhole = nil,
		discs = {},
		icons = {},
		highlight = nil,
		weaponLit = false,
		pulsePhase = 0,
		crackPhase = 0,
		flashUntil = 0,
		flashStrong = false,
		phaseLevel = 1,
		phaseShown = 1,
		stepSide = 0,
		nextGroan = os.clock() + 3 + random:NextNumber() * 2,
		nextBeep = 0,
		aimOn = false,
		aimFrom = 0,
		releaseAt = -10,
		trailUntil = 0,
		dashGhostAt = -10,
		exploded = false,
		eyesOn = true,
		threatSeen = false,
	}
	rig.fx = fx

	if rig.prefab then
		local armorFolder = model:FindFirstChild("Armor")
		local weaponFolder = model:FindFirstChild("Weapon")
		local glowFolder = model:FindFirstChild("Glow")
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
				table.insert(fx.body, { part = child, base = child.Transparency, rank = BODY_RANK[child.Name] or 3 })
			end
		end
		for _, part in ipairs(armorFolder and armorFolder:GetDescendants() or {}) do
			if part:IsA("BasePart") then
				local bodyName = part:GetAttribute("Body")
				local bodyPart = bodyName and model:FindFirstChild(bodyName)
				local weld = part:FindFirstChildOfClass("WeldConstraint")
				table.insert(fx.armor, {
					part = part,
					base = part.Transparency,
					weld = weld,
					bodyPart = bodyPart,
					rest = bodyPart and bodyPart.CFrame:ToObjectSpace(part.CFrame) or CFrame.identity,
					rank = BODY_RANK[bodyName or ""] or 3,
				})
				if string.match(part.Name, "^Chain") then
					table.insert(fx.chains, { part = part, color = part.Color, material = part.Material })
				end
			end
		end
		for _, part in ipairs(weaponFolder and weaponFolder:GetDescendants() or {}) do
			if part:IsA("BasePart") then
				table.insert(fx.weapon, { part = part, base = part.Transparency, color = part.Color, material = part.Material })
			elseif part:IsA("Motor6D") then
				table.insert(fx.weaponMotors, part)
			end
		end
		for _, part in ipairs(glowFolder and glowFolder:GetDescendants() or {}) do
			if part:IsA("BasePart") then
				local role = part:GetAttribute("Role")
				local entry = { part = part, base = part.Transparency, color = part.Color, size = part.Size }
				if role == "eye" then
					table.insert(fx.eyes, entry)
				elseif role == "crack" then
					table.insert(fx.cracks, entry)
				elseif role == "crack2" or role == "glow2" then
					-- glow2 — свечение II фазы из объёмных префабов (скрыто до фазы)
					table.insert(fx.cracks2, entry)
				elseif role == "bomb" then
					table.insert(fx.bombs, entry)
				elseif role == "keyhole" then
					fx.keyhole = entry
				end
			end
		end
		-- След оружия: маркер Hit включает его на 0,15 с.
		local base, tip = fxPoint(rig, "FX_WeaponBase"), fxPoint(rig, "FX_WeaponTip")
		if base and tip then
			local trail = Instance.new("Trail")
			trail.Attachment0 = base
			trail.Attachment1 = tip
			trail.Lifetime = 0.15
			trail.Color = ColorSequence.new(V.W)
			trail.Transparency = seq(0.3, 1)
			trail.LightEmission = 0.4
			trail.Enabled = false
			trail.Parent = base.Parent
			fx.trail = trail
		end
		-- Стрелок: прицельная линия от лука к цели.
		local nock = fxPoint(rig, "FX_BowNock")
		if not nock and rig.config.aimNock and weaponFolder then
			-- Объёмные префабы без FX_BowNock: точка на передней грани оружия.
			local weaponPart = weaponFolder:FindFirstChildWhichIsA("BasePart", true)
			if weaponPart then
				local made = Instance.new("Attachment")
				made.Name = "FX_BowNock"
				made.Position = V3(0, 0, -weaponPart.Size.Z * 0.45)
				made.Parent = weaponPart
				fx.points["FX_BowNock"] = made
				nock = made
			end
		end
		if nock then
			fx.nockRest = nock.Position
			local target = acquire("glow", V3(0.1, 0.1, 0.1), V.H, 1)
			local targetAttachment = Instance.new("Attachment")
			targetAttachment.Parent = target
			local beam = Instance.new("Beam")
			beam.Attachment0 = nock
			beam.Attachment1 = targetAttachment
			beam.Width0 = 0.04
			beam.Width1 = 0.04
			beam.Color = ColorSequence.new(V.H)
			beam.LightEmission = 0.5
			beam.FaceCamera = true
			beam.Segments = 1
			beam.Transparency = NumberSequence.new(0.7)
			beam.Enabled = false
			beam.Parent = nock.Parent
			fx.aimBeam = beam
			fx.aimTarget = target
			fx.aimAttachment = targetAttachment
		end
		-- Шипение фитиля Треснувшего — петля у FX_Fuse.
		local loopName = rig.config.sounds and rig.config.sounds.loop
		local loopSpec = loopName and Sfx.loops and Sfx.loops[loopName]
		local fuse = fxPoint(rig, "FX_Fuse")
		if loopSpec and fuse then
			local loop = Instance.new("Sound")
			loop.Name = "FuseHiss"
			loop.SoundId = loopSpec.id
			loop.Volume = loopSpec.volume
			loop.PlaybackSpeed = loopSpec.pitch or 1
			loop.Looped = true
			loop.RollOffMaxDistance = 40
			loop.Parent = fuse
			loop:Play()
			fx.loopSound = loop
		end
		local feet = fxPoint(rig, "FX_Feet")
		fx.smoke = feet and feet:FindFirstChild("ShadeSmoke")
		local fuseSparks = fuse and fuse:FindFirstChild("FuseSparks")
		fx.fuseSparks = fuseSparks
		local keyhole = fxPoint(rig, "FX_Keyhole")
		fx.keyholeLight = keyhole and keyhole:FindFirstChild("KeyholeLight")
		fx.keyholeRays = keyhole and keyhole:FindFirstChild("KeyholeRays")
		local chest = fxPoint(rig, "FX_Chest")
		fx.phaseSparks = chest and chest:FindFirstChild("PhaseSparks")
		fx.particles = {}
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") then
				table.insert(fx.particles, { emitter = descendant, enabled = descendant.Enabled })
			end
		end
	else
		-- Запасной кубический риг: всё — «тело».
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part.Transparency < 1 then
				table.insert(fx.body, { part = part, base = part.Transparency, rank = 3 })
				local role = part:GetAttribute("Role")
				if role == "weapon" then
					table.insert(fx.weapon, { part = part, base = part.Transparency, color = part.Color, material = part.Material })
				elseif role == "eye" then
					table.insert(fx.eyes, { part = part, base = part.Transparency, color = part.Color, size = part.Size })
				elseif role == "crack" then
					table.insert(fx.cracks, { part = part, base = part.Transparency, color = part.Color, size = part.Size })
				end
			end
		end
		fx.particles = {}
	end

	-- Кольцо под ногами (не у босса).
	local roleColor = EnemyVisuals.RoleColors[rig.stats.role]
	if roleColor and not rig.stats.isBoss then
		local diameter = rig.stats.radius * FX.ringScale
		fx.ring = acquire("disc", V3(0.05, diameter, diameter), roleColor, FX.ringTransparency)
	end

	-- Привратник, уже прошедший порог (клиент подключился поздно): II фаза сразу.
	local phase = rig.server:GetAttribute("BossPhase") or 1
	if phase >= 2 then
		fx.phaseLevel = phase
		EnemyFx.showPhase(rig, phase, true)
	end

	EnemyAura.attach(rig)
end

function EnemyFx.detach(rig)
	local fx = rig.fx
	if not fx then
		return
	end
	EnemyAura.detach(rig)
	if fx.highlight then
		giveHighlight(fx.highlight)
		fx.highlight = nil
	end
	if fx.ring then
		release("disc", fx.ring)
		fx.ring = nil
	end
	for _, disc in ipairs(fx.discs) do
		release("disc", disc)
	end
	table.clear(fx.discs)
	for _, entry in pairs(fx.groundBeams or {}) do
		entry.holder:Destroy()
	end
	fx.groundBeams = nil
	for _, cube in ipairs(fx.icons) do
		release("glow", cube)
	end
	table.clear(fx.icons)
	if fx.aimTarget then
		fx.aimAttachment:Destroy()
		release("glow", fx.aimTarget)
		fx.aimTarget = nil
	end
	if fx.ghosts then
		for _, ghost in ipairs(fx.ghosts) do
			ghost.model:Destroy()
		end
		fx.ghosts = nil
	end
	if fx.loopSound then
		fx.loopSound:Destroy()
		fx.loopSound = nil
	end
	-- Кубики сборки, которые ещё летят к этому врагу.
end

-- ===== Цвета: подсветка, оружие, глаза, свечения =====

local PARRY = V.H
local DANGER = V.X

-- Неон поверх детали. У MeshPart с текстурой-палитрой цвет детали не виден,
-- поэтому на время свечения текстура снимается и потом возвращается.
local savedTextures = setmetatable({}, { __mode = "k" })

local function glowOn(part: BasePart, color: Color3)
	if part:IsA("MeshPart") and part.TextureID ~= "" then
		savedTextures[part] = part.TextureID
		part.TextureID = ""
	end
	part.Material = Enum.Material.Neon
	part.Color = color
end

local function glowOff(part: BasePart, material: Enum.Material, color: Color3)
	part.Material = material
	part.Color = color
	local texture = savedTextures[part]
	if texture and part:IsA("MeshPart") then
		part.TextureID = texture
		savedTextures[part] = nil
	end
end

local function setWeaponLit(rig, color: Color3?)
	local fx = rig.fx
	local key = color or false
	if fx.weaponLit == key then
		return
	end
	fx.weaponLit = key
	for _, item in ipairs(fx.weapon) do
		if color then
			glowOn(item.part, color)
		else
			glowOff(item.part, item.material, item.color)
		end
	end
end

local function setEyes(rig, transparency: number)
	for _, eye in ipairs(rig.fx.eyes) do
		eye.part.Transparency = transparency
	end
end

-- Highlight: попадание > телеграф > оглушение.
local function updateHighlight(rig, dt: number, now: number, telegraphColor: Color3?, progress: number, farFx: boolean)
	local fx = rig.fx
	local mode = nil
	if now < fx.flashUntil and not farFx then
		mode = "flash"
	elseif telegraphColor then
		mode = "telegraph"
	elseif rig.state == "stunned" and not farFx then
		mode = "stun"
	end
	if not mode then
		if fx.highlight then
			giveHighlight(fx.highlight)
			fx.highlight = nil
		end
		return
	end
	local highlight = fx.highlight
	if not highlight then
		highlight = takeHighlight(rig.model)
		fx.highlight = highlight
		if not highlight then
			return
		end
	end
	if mode == "flash" then
		highlight.FillColor = PARRY
		highlight.OutlineColor = PARRY
		highlight.FillTransparency = 0.35
		highlight.OutlineTransparency = 0
	elseif mode == "telegraph" then
		-- Заливка 0,82 → 0,32 к концу замаха, пульс учащается «с 10 до 32»:
		-- как в прежнем EnemyVisualController, sin(t · (10 + 22p)) — это
		-- рад/с, а не герцы (32 Гц при 60 кадрах превратились бы в мусор).
		fx.pulsePhase = (fx.pulsePhase + (10 + 22 * progress) * dt) % TAU
		local fill = 0.82 - 0.5 * progress + 0.1 * progress * math.sin(fx.pulsePhase)
		highlight.FillColor = telegraphColor :: Color3
		highlight.OutlineColor = telegraphColor :: Color3
		highlight.FillTransparency = math.clamp(fill, 0.25, 0.9)
		highlight.OutlineTransparency = 0.05
	else
		highlight.FillColor = V.A
		highlight.OutlineColor = V.A
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 0.4
	end
end

-- ===== Круги на земле =====

local function parseZones(text: string?, out)
	table.clear(out)
	for entry in string.gmatch(text or "", "[^;]+") do
		-- «x,z» или «x,z,y» (этаж v2: третье — высота пола под зоной).
		local x, z, y = string.match(entry, "^%s*([%-%d%.]+),([%-%d%.]+),?([%-%d%.]*)")
		if x and z then
			local height = (y and y ~= "") and tonumber(y) or nil
			table.insert(out, V3(tonumber(x) :: number, height or math.huge, tonumber(z) :: number))
		end
	end
	return out
end

local zoneScratch = {}

local function clearDiscs(fx)
	for _, disc in ipairs(fx.discs) do
		release("disc", disc)
	end
	table.clear(fx.discs)
end

local function clearIcons(fx)
	for _, cube in ipairs(fx.icons) do
		release("glow", cube)
	end
	table.clear(fx.icons)
end

-- Внешний диск — граница (0,78), внутренний растёт по quadIn за замах
-- (0,5 → 0,3). Диск на высоте 0,12: щит Латника его не перекрывает.
local function groundTelegraph(rig, progress: number)
	local fx = rig.fx
	local server = rig.server
	local radius = server:GetAttribute("EnemyAttackRadius") or 0
	if radius <= 0 then
		clearDiscs(fx)
		clearIcons(fx)
		return
	end
	local centers = parseZones(server:GetAttribute("EnemyZones"), zoneScratch)
	if #centers == 0 then
		local center = server:GetAttribute("EnemyAttackCenter")
		if typeof(center) == "Vector3" then
			table.insert(centers, center)
		else
			table.insert(centers, V3(rig.pos.X, rig.groundY or 0, rig.pos.Z))
		end
	end
	if #fx.discs ~= #centers * 2 then
		clearDiscs(fx)
		for _ = 1, #centers do
			table.insert(fx.discs, acquire("disc", V3(0.08, radius * 2, radius * 2), DANGER, 0.78))
			table.insert(fx.discs, acquire("disc", V3(0.08, 0.2, 0.2), DANGER, 0.5))
		end
	end
	local fill = Anim.ease.quadIn(math.clamp(progress, 0, 1))
	local groundY = rig.groundY or 0
	for index, center in ipairs(centers) do
		local outer = fx.discs[index * 2 - 1]
		local inner = fx.discs[index * 2]
		-- Своя высота у зоны (залп Арбалетчицы по пандусу), иначе — пол врага.
		local floorY = (center.Y ~= math.huge and center.Y ~= 0) and center.Y or groundY
		outer.Size = V3(0.08, radius * 2, radius * 2)
		queue(outer, CFrame.new(center.X, floorY + 0.12, center.Z) * DISC_TURN)
		local size = math.max(radius * 2 * fill, 0.2)
		inner.Size = V3(0.08, size, size)
		inner.Transparency = 0.5 - 0.2 * fill
		queue(inner, CFrame.new(center.X, floorY + 0.14, center.Z) * DISC_TURN)
	end

	-- Цепи Привратника: над каждым кругом иконка-звено из 3 вокселей,
	-- опускается с 3 стадов к земле по прогрессу замаха.
	if rig.attack == "chains" and rig.state == "windup" then
		local cube = 0.125 * rig.scale
		if #fx.icons ~= #centers * 3 then
			clearIcons(fx)
			for _ = 1, #centers * 3 do
				table.insert(fx.icons, acquire("glow", V3(cube, cube, cube), V.G, 0))
			end
			for _, part in ipairs(fx.icons) do
				part.Material = Enum.Material.SmoothPlastic
			end
		end
		local height = 3 * (1 - progress) + 0.3
		local spin = os.clock() * 2
		for index, center in ipairs(centers) do
			local base = CFrame.new(center.X, groundY + height, center.Z) * CFrame.Angles(0, spin, 0)
			for k = 1, 3 do
				local offset = ({ V3(-cube, 0, 0), V3(0, cube, 0), V3(cube, 0, 0) })[k]
				queue(fx.icons[(index - 1) * 3 + k], base * CFrame.new(offset))
			end
		end
	else
		clearIcons(fx)
	end
end

-- ===== Шевроны (рывок Тени, таран босса) =====

-- ===== Стрелки и коридоры на земле (шаблоны FX.Enemy) =====

-- Плоский луч на земле: держатель с двумя точками и клон шаблона.
local function groundBeam(fx, key: string, path: string)
	fx.groundBeams = fx.groundBeams or {}
	local entry = fx.groundBeams[key]
	if entry and entry.holder.Parent then
		return entry
	end
	local beam = FxKit.clone(path)
	if not beam then
		return nil
	end
	local holder = FxKit.holder()
	holder.Name = "EnemyBeam_" .. key
	holder.Parent = folder()
	local a0 = Instance.new("Attachment")
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Parent = holder
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Enabled = false
	beam.Parent = holder
	entry = { holder = holder, a0 = a0, a1 = a1, beam = beam, transparency = beam.Transparency }
	fx.groundBeams[key] = entry
	return entry
end

local function placeGroundBeam(entry, from: Vector3, to: Vector3, color: Color3?, fade: number)
	local dir = to - from
	entry.a0.WorldCFrame = FxKit.flatFrame(from, dir)
	entry.a1.WorldCFrame = FxKit.flatFrame(to, dir)
	if color then
		entry.beam.Color = ColorSequence.new(color)
	end
	-- fade: 0 — как в шаблоне, 1 — невидимо.
	local points = {}
	for _, p in ipairs(entry.transparency.Keypoints) do
		table.insert(points, NumberSequenceKeypoint.new(p.Time, p.Value + (1 - p.Value) * fade))
	end
	entry.beam.Transparency = NumberSequence.new(points)
	entry.beam.Enabled = true
end

function hideGroundBeam(fx, key: string)
	local entry = fx.groundBeams and fx.groundBeams[key]
	if entry and entry.beam.Enabled then
		entry.beam.Enabled = false
	end
end

-- Стрелка рывка: до фиксации — бледная по взгляду, после (EnemyDashDir с
-- сервера) — яркая, ровно туда и на ту длину, куда враг рванёт.
function dashArrow(rig, color: Color3, defaultLength: number)
	local entry = groundBeam(rig.fx, "dash", "Enemy/DashArrow")
	if not entry then
		return
	end
	local dashDir = rig.server:GetAttribute("EnemyDashDir")
	local locked = typeof(dashDir) == "Vector3" and dashDir.Magnitude > 0.1
	local dir = locked and V3(dashDir.X, 0, dashDir.Z) or rig.facing
	if dir.Magnitude < 0.01 then
		return
	end
	local length = locked and dashDir.Magnitude or defaultLength
	local start = V3(rig.pos.X, rig.groundY + 0.15, rig.pos.Z) + dir.Unit * 0.8
	placeGroundBeam(entry, start, start + dir.Unit * length, color, locked and 0 or 0.65)
end

-- ===== Обновление врага за кадр =====

-- view: { distance, farFx } — от EnemyVisualController (LOD).
function EnemyFx.update(rig, dt: number, serverTime: number, view)
	local fx = rig.fx
	local now = os.clock()
	local state = rig.state
	local server = rig.server
	local telegraph = server:GetAttribute("EnemyTelegraph")
	local progress = 0
	if state == "windup" and rig.stateDur > 0 then
		progress = math.clamp((serverTime - rig.stateAt) / rig.stateDur, 0, 1)
	elseif state == "strike" then
		progress = 1
	end
	rig.progress = progress
	EnemyAura.update(rig, dt, now, view.farFx == true)

	local telegraphColor = nil
	if state == "windup" or state == "strike" then
		if telegraph == "parryable" then
			telegraphColor = PARRY
		elseif telegraph == "dodgeOnly" or telegraph == "zones" then
			telegraphColor = DANGER
		end
	end
	updateHighlight(rig, dt, now, telegraphColor, progress, view.farFx)
	setWeaponLit(rig, telegraphColor)

	-- Кольцо под ногами.
	if fx.ring then
		queue(fx.ring, CFrame.new(rig.pos.X, rig.groundY + 0.06, rig.pos.Z) * DISC_TURN)
		fx.ring.Transparency = rig.hidden and 1 or FX.ringTransparency
	end

	-- Круги на земле: в замахе, у прыжка — и в полёте.
	local airborne = state == "dash" and rig.attack == "leap"
	if (state == "windup" or airborne) and (server:GetAttribute("EnemyAttackRadius") or 0) > 0 then
		groundTelegraph(rig, airborne and 1 or progress)
	elseif #fx.discs > 0 or #fx.icons > 0 then
		clearDiscs(fx)
		clearIcons(fx)
	end

	-- Особые телеграфы.
	if state == "windup" and rig.attack == "dash_combo" then
		dashArrow(rig, PARRY, 8)
	elseif state == "windup" and (rig.attack == "charge" or rig.attack == "ram") then
		dashArrow(rig, DANGER, 20) -- таран Привратника и Садовницы
	elseif state == "windup" and rig.attack == "sting" then
		dashArrow(rig, DANGER, 11) -- жало пчелы-мутанта
	else
		hideGroundBeam(fx, "dash")
	end

	EnemyFx.updateArcher(rig, now)
	EnemyFx.updateMartyr(rig, dt, now, progress)
	EnemyFx.updateShade(rig, now)

	-- Глаза: тускнеют в оглушении.
	if fx.eyesOn then
		setEyes(rig, state == "stunned" and 0.9 or 0)
	end

	-- След оружия.
	if fx.trail then
		fx.trail.Enabled = now < fx.trailUntil
	end

	-- Частицы далеко не нужны.
	if fx.particlesOff ~= view.farFx then
		fx.particlesOff = view.farFx
		for _, item in ipairs(fx.particles) do
			item.emitter.Enabled = (not view.farFx) and item.enabled
		end
	end

	-- II фаза: если сцену пропустили (маркер Crack не пришёл) — сразу.
	local phase = server:GetAttribute("BossPhase") or 1
	if phase > fx.phaseLevel then
		fx.phaseLevel = phase
		fx.phaseAt = now
		sound(rig.config.sounds and rig.config.sounds.phase, rig.pos)
	end
	if fx.phaseLevel > fx.phaseShown and fx.phaseAt and now - fx.phaseAt > 2.2 then
		EnemyFx.showPhase(rig, fx.phaseLevel, true)
	end

	-- Треснувший стонет в покое раз в 3–5 с.
	local idleSound = rig.config.sounds and rig.config.sounds.idle
	if idleSound and now >= fx.nextGroan then
		fx.nextGroan = now + 3 + random:NextNumber() * 2
		if state == "idle" or state == "approach" then
			sound(idleSound, rig.pos)
		end
	end

	EnemyFx.updateSpawn(rig, now)
end

-- Тетива и прицельная линия стрелка.
function EnemyFx.updateArcher(rig, now: number)
	local fx = rig.fx
	local nock = fxPoint(rig, "FX_BowNock")
	if not nock then
		return
	end
	local attackConfig = rig.config.attacks[rig.attack]
	local drawing = rig.state == "windup" and (rig.attack == "shot" or (attackConfig ~= nil and attackConfig.aim == true))
	if fx.aimBeam then
		local wide = drawing and attackConfig ~= nil and attackConfig.aimWide == true
		if fx.aimWide ~= wide then
			-- Последний болт: толстый красный луч.
			fx.aimWide = wide
			fx.aimBeam.Width0 = wide and 0.16 or 0.04
			fx.aimBeam.Width1 = wide and 0.16 or 0.04
			fx.aimBeam.Color = ColorSequence.new(wide and V.X or V.H)
		end
	end
	if drawing and rig.attack == "shot" then
		-- Натяжение: тетива у правой кисти (+0,1 вперёд).
		local hand = rig.model:FindFirstChild("RightHand")
		if hand then
			nock.WorldPosition = hand.Position + hand.CFrame.LookVector * 0.1
		end
	elseif fx.nockRest then
		-- После выстрела тетива возвращается за 0,06 с (Back Out).
		local k = math.clamp((now - fx.releaseAt) / 0.06, 0, 1)
		if k < 1 then
			local from = fx.nockFrom or fx.nockRest
			local e = Anim.ease.backOut(k)
			nock.Position = from:Lerp(fx.nockRest, e)
		elseif nock.Position ~= fx.nockRest then
			nock.Position = fx.nockRest
		end
	end

	-- Прицельная линия. Пока стрелок целится — тонкая бледная за игроком
	-- (маркер AimLine). Когда прицел зафиксирован (EnemyAimPoint с сервера) —
	-- яркий луч до конца дальности и коридор на земле: стрела полетит ровно
	-- по ним, отойди в сторону.
	local beam = fx.aimBeam
	if beam then
		local blinking = now - fx.releaseAt < 0.08
		local aimPoint = rig.server:GetAttribute("EnemyAimPoint")
		local locked = drawing and typeof(aimPoint) == "Vector3"
		if locked then
			local origin = beam.Attachment0.WorldPosition
			local dir = aimPoint - origin
			dir = dir.Magnitude > 0.1 and dir.Unit or rig.facing
			local reach = AIM_REACH
			queue(fx.aimTarget, CFrame.new(origin + dir * reach))
			local template = FxKit.template("Enemy/AimLine")
			if template and not fx.aimStyled then
				fx.aimStyled = true
				fx.aimPlain = { beam.Width0, beam.Width1, beam.Color, beam.LightEmission }
			end
			if template then
				beam.Width0, beam.Width1 = template.Width0, template.Width1
				beam.Color = template.Color
				beam.LightEmission = template.LightEmission
				beam.Transparency = blinking and NumberSequence.new(0) or template.Transparency
			end
			beam.Enabled = true
			local ground = groundBeam(fx, "aim", "Enemy/AimGround")
			if ground then
				local flatDir = V3(dir.X, 0, dir.Z)
				if flatDir.Magnitude > 0.01 then
					local start = V3(rig.pos.X, rig.groundY + 0.12, rig.pos.Z) + flatDir.Unit * 1.2
					placeGroundBeam(ground, start, start + flatDir.Unit * reach, nil, 0)
				end
			end
		elseif (drawing and fx.aimOn) or blinking then
			if fx.aimStyled then
				fx.aimStyled = false
				beam.Width0, beam.Width1, beam.Color, beam.LightEmission = table.unpack(fx.aimPlain)
			end
			local root = localRoot()
			local target = root and root.Position or (rig.pos + rig.facing * 20 + V3(0, 3, 0))
			queue(fx.aimTarget, CFrame.new(target))
			local k = drawing and math.clamp((now - fx.aimFrom) / math.max(rig.stateDur * 0.5, 0.05), 0, 1) or 1
			local transparency = blinking and 0 or (0.7 - 0.5 * k)
			beam.Transparency = NumberSequence.new(transparency)
			beam.Enabled = true
			hideGroundBeam(fx, "aim")
		else
			beam.Enabled = false
			hideGroundBeam(fx, "aim")
			if not drawing then
				fx.aimOn = false
			end
		end
	end
end

-- Фитиль, заряды и трещины Треснувшего.
function EnemyFx.updateMartyr(rig, dt: number, now: number, progress: number)
	local fx = rig.fx
	if #fx.bombs == 0 and #fx.cracks == 0 then
		return
	end
	local windup = rig.state == "windup" and rig.attack == "explode"
	-- Трещины: покой 0,55 ± 0,1·sin(8t); замах 0,3 → 0, мерцание 8 → 30
	-- (в тех же единицах, что sin(8t): рад/с).
	local frequency = windup and (8 + 22 * progress) or 8
	fx.crackPhase = (fx.crackPhase + frequency * dt) % TAU
	local wave = math.sin(fx.crackPhase)
	local crackTransparency = windup and (0.3 * (1 - progress) + 0.08 * wave) or (0.55 + 0.1 * wave)
	for _, crack in ipairs(fx.cracks) do
		crack.part.Transparency = math.clamp(crackTransparency, 0, 1)
	end
	for _, bomb in ipairs(fx.bombs) do
		if windup then
			if bomb.part.Material ~= Enum.Material.Neon then
				glowOn(bomb.part, bomb.color)
			end
			bomb.part.Transparency = math.clamp(0.25 * (0.5 + 0.5 * wave) * (1 - progress), 0, 1)
		elseif bomb.part.Material ~= Enum.Material.SmoothPlastic then
			glowOff(bomb.part, Enum.Material.SmoothPlastic, bomb.color)
			bomb.part.Transparency = 0
		end
	end
	if fx.fuseSparks then
		fx.fuseSparks.Rate = windup and (6 + 34 * progress) or 6
	end
	-- Писк фитиля ускоряется с 2 до 12 Гц (доп.).
	if windup and now >= fx.nextBeep then
		fx.nextBeep = now + 1 / (2 + 10 * progress)
		sound("fuseBeep", rig.pos)
	end
end

-- Дым и следы-силуэты Тени.
function EnemyFx.updateShade(rig, now: number)
	local fx = rig.fx
	if fx.smoke then
		fx.smoke.Rate = rig.state == "dash" and 60 or 10
	end
	local ghosts = fx.ghosts
	if not ghosts then
		return
	end
	for _, ghost in ipairs(ghosts) do
		if ghost.at then
			local age = now - ghost.at
			local k = math.clamp(age / 0.25, 0, 1)
			for _, pair in ipairs(ghost.parts) do
				pair[1].Transparency = 0.5 + 0.5 * k
			end
			if k >= 1 then
				ghost.at = nil
				for _, pair in ipairs(ghost.parts) do
					queue(pair[1], FAR)
				end
			end
		end
	end
end

-- Силуэты рывка: три копии тела из ForceField, создаются при первом рывке.
local function makeGhosts(rig)
	local fx = rig.fx
	local list = {}
	for _ = 1, 3 do
		local ghostModel = Instance.new("Model")
		ghostModel.Name = "ShadeGhost"
		local parts = {}
		for _, item in ipairs(fx.body) do
			local source = item.part
			local ghost = Instance.new("Part")
			ghost.Anchored = true
			ghost.CanCollide = false
			ghost.CanQuery = false
			ghost.CanTouch = false
			ghost.CastShadow = false
			ghost.Material = Enum.Material.ForceField
			ghost.Color = V.K
			ghost.Size = source.Size
			ghost.Transparency = 1
			ghost.CFrame = FAR
			ghost.Parent = ghostModel
			table.insert(parts, { ghost, source })
		end
		for _, item in ipairs(fx.armor) do
			local ghost = Instance.new("Part")
			ghost.Anchored = true
			ghost.CanCollide = false
			ghost.CanQuery = false
			ghost.CanTouch = false
			ghost.CastShadow = false
			ghost.Material = Enum.Material.ForceField
			ghost.Color = V.K
			ghost.Size = item.part.Size
			ghost.Transparency = 1
			ghost.CFrame = FAR
			ghost.Parent = ghostModel
			table.insert(parts, { ghost, item.part })
		end
		ghostModel.Parent = folder()
		table.insert(list, { model = ghostModel, parts = parts, at = nil })
	end
	fx.ghosts = list
end

local function dropGhost(rig, index: number)
	local ghost = rig.fx.ghosts and rig.fx.ghosts[index]
	if not ghost or not rig.model.Parent then
		return
	end
	ghost.at = os.clock()
	for _, pair in ipairs(ghost.parts) do
		pair[1].Transparency = 0.5
		queue(pair[1], pair[2].CFrame)
	end
end

-- ===== Появление (раздел 2.3) =====

-- Начать сборку. elapsed — сколько уже прошло (клиент подключился позже).
function EnemyFx.beginSpawn(rig, elapsed: number)
	local fx = rig.fx
	local boss = rig.stats.isBoss
	-- У босса сцена 4,2 с: сборка растянута до маркера EyesOn (2,1 с).
	local stretch = boss and 2.5 or 1
	fx.spawn = { start = os.clock() - elapsed, stretch = stretch, armorDone = false }
	fx.eyesOn = false
	setEyes(rig, 1)
	local groundY = rig.groundY
	if elapsed < 0.1 then
		ring(V3(rig.pos.X, groundY, rig.pos.Z), 2.5, V.A, 0.3)
		FxKit.spawn("Common/Dust", CFrame.new(rig.pos.X, groundY + 0.3, rig.pos.Z), { scale = 0.5 })
	end

	-- Тело невидимо, броня отцеплена и спрятана.
	for _, item in ipairs(fx.body) do
		item.part.Transparency = 1
	end
	for _, item in ipairs(fx.armor) do
		if item.weld and item.bodyPart then
			item.weld.Enabled = false
			item.part.Anchored = true
		end
		item.part.Transparency = 1
	end
	for _, item in ipairs(fx.weapon) do
		item.part.Transparency = 1
	end
	for _, list in ipairs({ fx.cracks, fx.bombs }) do
		for _, item in ipairs(list) do
			item.part.Transparency = 1
		end
	end

	-- Пыль памяти стягивается к врагу (шаблон FX.Enemy.Spawn), пока
	-- проявляется тело и защёлкивается броня.
	local remaining = 0.8 * stretch - elapsed
	if remaining > 0.1 then
		FxKit.spawn("Enemy/Spawn", CFrame.new(rig.pos.X, groundY + 0.15, rig.pos.Z), {
			radius = boss and FX.spawnRadiusBoss or FX.spawnRadius,
			life = remaining,
		})
	end
end

-- Тело проявляется 0,25–0,80 с, броня «щёлкает» снизу вверх с шагом 0,05 с:
-- деталь стартует в 0,6 стада снаружи и въезжает за 0,15 с (Back Out).
function EnemyFx.updateSpawn(rig, now: number)
	local fx = rig.fx
	local spawn = fx.spawn
	if not spawn then
		return
	end
	local s = spawn.stretch
	local t = (now - spawn.start) / s
	local body = math.clamp((t - 0.25) / 0.55, 0, 1)
	for _, item in ipairs(fx.body) do
		item.part.Transparency = item.base + (1 - item.base) * (1 - body)
	end
	for _, list in ipairs({ fx.cracks, fx.bombs }) do
		for _, item in ipairs(list) do
			item.part.Transparency = body >= 1 and item.base or 1
		end
	end

	local allDone = true
	for _, item in ipairs(fx.armor) do
		local slot = 0.25 + item.rank * 0.05
		local u = math.clamp((t - slot) / 0.15, 0, 1)
		if u <= 0 then
			item.part.Transparency = 1
			allDone = false
		elseif item.bodyPart and item.weld then
			if u < 1 then
				allDone = false
				item.part.Transparency = item.base
				local rest = item.bodyPart.CFrame * item.rest
				local away = rest.Position - item.bodyPart.Position
				local dir = away.Magnitude > 0.05 and away.Unit or item.bodyPart.CFrame.UpVector
				local e = Anim.ease.backOut(u)
				queue(item.part, rest + dir * 0.6 * rig.scale * (1 - e))
			elseif item.part.Anchored then
				item.part.CFrame = item.bodyPart.CFrame * item.rest
				item.part.Anchored = false
				item.weld.Enabled = true
				item.part.Transparency = item.base
			end
		else
			item.part.Transparency = item.base
		end
	end

	-- Оружие последним: въезжает по своему суставу.
	local slot = 0.25 + WEAPON_RANK * 0.05
	local u = math.clamp((t - slot) / 0.15, 0, 1)
	for _, item in ipairs(fx.weapon) do
		item.part.Transparency = u > 0 and item.base or 1
	end
	for _, joint in ipairs(fx.weaponMotors) do
		joint.Transform = CFrame.new(0, 0.6 * (1 - Anim.ease.backOut(u)), 0)
	end
	if u < 1 then
		allDone = false
	end

	if allDone and body >= 1 then
		fx.spawn = nil
		if not fx.eyesOn and t > 1.2 then
			EnemyFx.eyesOn(rig)
		end
	end
end

-- Досрочно закончить сборку (смерть во время появления, поздний клиент).
function EnemyFx.finishSpawn(rig)
	local fx = rig.fx
	if fx.spawn then
		fx.spawn.start = os.clock() - 10
		EnemyFx.updateSpawn(rig, os.clock())
	end
	if not fx.eyesOn then
		EnemyFx.eyesOn(rig)
	end
end

-- Глаза погашены (сцена появления босса ждёт маркер EyesOn).
function EnemyFx.eyesOff(rig)
	local fx = rig.fx
	if not fx then
		return
	end
	fx.eyesOn = false
	setEyes(rig, 1)
end

-- Глаза загораются (маркер EyesOn): 1 → 0 за 0,1 с и белая вспышка.
function EnemyFx.eyesOn(rig)
	local fx = rig.fx
	if fx.eyesOn then
		return
	end
	fx.eyesOn = true
	setEyes(rig, 0)
	local point = fxPoint(rig, "FX_Eyes")
	local position = point and point.WorldPosition or headTop(rig)
	flash(position, 0.4 * rig.scale, 1.0 * rig.scale, V.H, 0.12)
end

-- ===== Фаза II Привратника =====

-- Трещины загораются по одной (0,1 с), скважина светится, глаза шире и
-- ярче, цепи — янтарный неон. instant — без очереди (поздний клиент).
function EnemyFx.showPhase(rig, phase: number, instant: boolean?)
	local fx = rig.fx
	if phase <= fx.phaseShown then
		return
	end
	fx.phaseShown = phase
	if phase >= 2 then
		for index, crack in ipairs(fx.cracks2) do
			if instant then
				crack.part.Transparency = 0
			else
				task.delay((index - 1) * 0.1, function()
					if crack.part.Parent then
						crack.part.Transparency = 0
						burst("sparks", crack.part.Position, 6)
					end
				end)
			end
		end
		if fx.keyhole then
			fx.keyhole.part.Transparency = 0
		end
		if fx.keyholeLight then
			fx.keyholeLight.Enabled = true
		end
		if fx.keyholeRays then
			fx.keyholeRays.Enabled = true
		end
		if fx.phaseSparks then
			fx.phaseSparks.Enabled = true
		end
		for _, eye in ipairs(fx.eyes) do
			eye.part.Size = V3(eye.size.X * 2, eye.size.Y, eye.size.Z)
			local light = eye.part:FindFirstChildOfClass("PointLight")
			if light then
				light.Brightness = 2.5
			end
		end
		for _, link in ipairs(fx.chains) do
			glowOn(link.part, V.A)
		end
		for _, item in ipairs(fx.particles) do
			if item.emitter == fx.keyholeRays or item.emitter == fx.phaseSparks then
				item.enabled = true
			end
		end
	end
	-- III фаза (доп.): искр из трещин втрое больше.
	if phase >= 3 and fx.phaseSparks then
		fx.phaseSparks.Rate = 24
	end
end

-- ===== Маркеры анимаций (раздел 3.5) =====

function EnemyFx.onMarker(rig, name: string, animName: string)
	local fx = rig.fx
	if not fx or rig.hidden then
		return
	end
	local config = rig.config
	local attackConfig = config.attacks[rig.attack] or config.attacks[rig.lastAttack or ""]
	if name == "Step" then
		fx.stepSide = 1 - fx.stepSide
		local foot = rig.model:FindFirstChild(fx.stepSide == 0 and "RightFoot" or "LeftFoot")
		local position = foot and foot.Position or rig.pos
		local heavy = config.heavySteps
		burst("dust", V3(position.X, rig.groundY + 0.2, position.Z), heavy and heavy.dust or 3)
		sound(config.sounds and config.sounds.step, position)
		if heavy then
			local root = localRoot()
			if root and (root.Position - rig.pos).Magnitude < heavy.range then
				shake(heavy.shake, 0.15)
			end
		end
		if rig.animator then
			rig.animator:kickCrown()
		end
	elseif name == "Hit" then
		fx.trailUntil = os.clock() + 0.15
		local hitSound = attackConfig and attackConfig.hitSound
		if type(hitSound) == "table" then
			fx.hitIndex = (fx.hitIndex or 0) % #hitSound + 1
			hitSound = hitSound[fx.hitIndex]
		end
		sound(hitSound, rig.pos)
	elseif name == "Release" then
		fx.releaseAt = os.clock()
		local nock = fxPoint(rig, "FX_BowNock")
		fx.nockFrom = nock and nock.Position or nil
		sound(attackConfig and attackConfig.hitSound, rig.pos)
	elseif config.markerSounds and config.markerSounds[name] then
		sound(config.markerSounds[name], rig.pos)
	elseif name == "AimLine" then
		fx.aimOn = true
		fx.aimFrom = os.clock()
	elseif name == "Scrape" then
		local foot = rig.model:FindFirstChild("RightFoot")
		local position = foot and foot.Position or rig.pos
		burst("sparks", V3(position.X, rig.groundY + 0.3, position.Z), 10)
		burst("dust", V3(position.X, rig.groundY + 0.3, position.Z), 6)
	elseif name == "EyesOn" then
		EnemyFx.eyesOn(rig)
	elseif name == "Crack" then
		EnemyFx.showPhase(rig, math.max(fx.phaseLevel, 2))
	elseif name == "Roar" then
		shake(0.9, 0.6)
		ring(V3(rig.pos.X, rig.groundY, rig.pos.Z), 12, V.A, 0.6, 0.3)
		sound(config.sounds and config.sounds.roar, rig.pos)
		if animName == config.spawn then
			Bus.emit("bossRoar", { model = rig.server })
		end
	end
end

-- ===== Смена состояния =====

function EnemyFx.onState(rig, previous: string, state: string)
	local fx = rig.fx
	if state == "windup" then
		local attackConfig = rig.config.attacks[rig.attack]
		sound(attackConfig and attackConfig.windupSound, rig.pos)
		fx.aimOn = false
	elseif state == "dash" then
		local attackConfig = rig.config.attacks[rig.attack]
		sound(attackConfig and attackConfig.dashSound, rig.pos)
		if rig.typeId == "shade" and rig.prefab then
			if not fx.ghosts then
				makeGhosts(rig)
			end
			dropGhost(rig, 1)
			task.delay(0.05, dropGhost, rig, 2)
			task.delay(0.1, dropGhost, rig, 3)
		end
	end
	if previous == "spawning" and state ~= "spawning" and state ~= "dead" then
		EnemyFx.finishSpawn(rig)
	end
end

-- ===== События сервера =====

function EnemyFx.hitFlash(rig, strong: boolean?)
	local fx = rig.fx
	fx.flashUntil = os.clock() + (strong and 0.25 or 0.08)
end

-- Взрыв Треснувшего (раздел 2.4.5).
function EnemyFx.explosion(center: Vector3, radius: number, rig)
	local ground = V3(center.X, (rig and rig.groundY) or 0, center.Z)
	FxKit.spawn("Enemy/Explosion", CFrame.new(ground + V3(0, 0.3, 0)), { radius = radius })
	FxKit.shockwave(ground + V3(0, 1, 0), radius)
	shake(0.35, 0.3)
	sound("explode", ground)
	if rig then
		rig.fx.exploded = true
	end
end

-- Падающие цепи Привратника: с высоты 20 столб звеньев 3×3 падает в центр
-- каждого круга за 0,15 с, бьёт в землю и гаснет за 0,4 с.
local chainFalls = {}

function EnemyFx.chainFall(centers, radius: number, rig)
	local groundY = rig and rig.groundY or 0
	-- Звено 3×3 вокселя брони (0,125 × масштаб босса).
	local link = 3 * 0.125 * (rig and rig.scale or 1.8)
	for _, center in ipairs(centers) do
		local parts = {}
		local count = math.floor(20 / (link * 1.1))
		for index = 1, count do
			local part = acquire("cube", V3(link, link, link * 0.35), V.G, 0)
			parts[index] = part
		end
		table.insert(chainFalls, {
			parts = parts,
			center = V3(center.X, groundY, center.Z),
			link = link,
			age = 0,
			landed = false,
			radius = radius,
		})
	end
	sound("chainSlam", centers[1])
end

local function stepChainFalls(dt: number)
	for index = #chainFalls, 1, -1 do
		local fall = chainFalls[index]
		fall.age += dt
		local k = math.clamp(fall.age / 0.15, 0, 1)
		local drop = 20 * (1 - Anim.ease.quadIn(k))
		if k >= 1 and not fall.landed then
			fall.landed = true
			ring(fall.center, fall.radius, V.W, 0.35, 0.25)
			burst("dust", fall.center + V3(0, 0.4, 0), 18)
			shake(0.3, 0.2)
		end
		local fade = math.clamp((fall.age - 0.15) / 0.4, 0, 1)
		for i, part in ipairs(fall.parts) do
			local y = fall.center.Y + drop + (i - 0.5) * fall.link * 1.1
			local turn = (i % 2 == 0) and CFrame.Angles(0, math.pi / 2, 0) or CFrame.identity
			queue(part, CFrame.new(fall.center.X, y, fall.center.Z) * turn)
			part.Transparency = fade
		end
		if fade >= 1 then
			for _, part in ipairs(fall.parts) do
				release("cube", part)
			end
			chainFalls[index] = chainFalls[#chainFalls]
			chainFalls[#chainFalls] = nil
		end
	end
end

-- ===== Распад (маркер Shatter) =====

function EnemyFx.shatter(rig)
	local fx = rig.fx
	if fx.shattered then
		return
	end
	fx.shattered = true
	EnemyFx.finishSpawn(rig)
	local boss = rig.stats.isBoss
	local strength = boss and 1.6 or 1
	local center = bodyCenter(rig)

	if not fx.exploded then
		-- Распад на пыль и осколки цвета брони (шаблон FX.Enemy.Death).
		local handle = FxKit.spawn("Enemy/Death", CFrame.new(center), { scale = rig.scale * strength })
		local source = fx.armor[1] or fx.body[1]
		local chips = handle and handle.root:FindFirstChild("Chips", true)
		if chips and source then
			local colors = voxelColors(source.part)
			chips.Color = ColorSequence.new(colors[1], colors[#colors])
		end
	end
	sound(rig.config.sounds and rig.config.sounds.death or "enemyDeath", center)
	EnemyFx.detach(rig)
	rig.model.Parent = nil
end

-- ===== Душа (раздел 19 плана) =====

-- Точка, куда летят души: остриё клинка героя.
local function bladePoint(): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "EquippedWeapon" then
			local root = descendant.PrimaryPart
			local tip = root and root:FindFirstChild("BladeTip")
			if tip and tip:IsA("Attachment") then
				return tip.WorldPosition
			end
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and (root.Position + V3(0, 1.5, 0)) or nil
end

-- Сгустки памяти (#6FE3FF, шаблон FX.Enemy.Soul) по дуге высотой 3 к
-- клинку за 0,6 с, вспышка на клинке, мягкий звон. Единственный голубой у врагов.
local SOUL_PIECES = 6

function EnemyFx.soul(origin: Vector3)
	local holder = FxKit.holder()
	local stream = { origin = origin, start = os.clock(), pieces = {}, arrived = false, holder = holder }
	for index = 1, SOUL_PIECES do
		local point = Instance.new("Attachment")
		point.WorldPosition = origin
		point.Parent = holder
		local side = V3(random:NextNumber() - 0.5, 0, random:NextNumber() - 0.5)
		stream.pieces[index] = {
			point = point,
			fx = FxKit.attach("Enemy/Soul", point),
			delay = random:NextNumber() * 0.15,
			side = side.Magnitude > 0.01 and side.Unit * (0.5 + random:NextNumber()) or Vector3.zero,
			done = false,
		}
	end
	table.insert(souls, stream)
end

local function stepSouls(now: number)
	if #souls == 0 then
		return
	end
	local target = bladePoint()
	for index = #souls, 1, -1 do
		local stream = souls[index]
		local alive = 0
		for _, piece in ipairs(stream.pieces) do
			if not piece.done then
				local k = (now - stream.start - piece.delay) / FX.soulTime
				if k >= 1 or not target then
					piece.done = true
					if piece.fx then
						piece.fx.stop()
					end
					if target and not stream.arrived then
						stream.arrived = true
						flash(target, 0.4, 1.0, Palette.Memory, 0.15)
						sound("soul", nil)
						Bus.emit("soulAbsorbed", {})
					end
				elseif k >= 0 then
					alive += 1
					local u = Anim.ease.sine(k)
					local position = stream.origin:Lerp(target :: Vector3, u)
					local arc = math.sin(math.pi * u) * FX.soulArc
					piece.point.WorldPosition = position + V3(0, arc, 0) + piece.side * math.sin(math.pi * u)
				else
					alive += 1
				end
			end
		end
		if alive == 0 then
			game:GetService("Debris"):AddItem(stream.holder, 0.5)
			souls[index] = souls[#souls]
			souls[#souls] = nil
		end
	end
end

-- ===== Стрелы поверх серверных снарядов =====

-- Сервер ведёт снаряд невидимой деталью (Workspace.Projectiles), клиент
-- рисует стрелу: древко N, наконечник L, оперение W (воксели 0,125),
-- неоновое ядро H и хвост 0,18 с. Отражённая — белая, хвост вдвое толще.
local arrows = {} -- [serverPart] = arrow
local arrowFree = {}

local function makeArrow()
	local holder = Instance.new("Model")
	holder.Name = "Arrow"
	local function piece(name: string, size: Vector3, color: Color3, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Size = size
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.CFrame = FAR
		part.Parent = holder
		return part
	end
	local arrow = {
		model = holder,
		shaft = piece("Shaft", V3(0.125, 0.125, 0.625), V.N),
		head = piece("Head", V3(0.125, 0.125, 0.25), V.L),
		fletch = piece("Fletch", V3(0.25, 0.25, 0.125), V.W),
		core = piece("Core", V3(0.2, 0.2, 0.2), V.H, Enum.Material.Neon),
	}
	local a0 = Instance.new("Attachment")
	a0.Parent = arrow.core
	local a1 = Instance.new("Attachment")
	a1.Parent = arrow.core
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.18
	trail.Color = ColorSequence.new(V.W)
	trail.Transparency = seq(0.2, 1)
	trail.LightEmission = 0.6
	trail.Parent = arrow.core
	arrow.a0, arrow.a1, arrow.trail = a0, a1, trail
	holder.Parent = folder()
	return arrow
end

local F2_ARROWS = {
	thorn = {
		shaft = V3(0.125, 0.125, 0.75), head = V3(0.125, 0.125, 0.375), core = V3(0.15, 0.15, 0.15),
		body = Color3.fromRGB(74, 92, 38), tip = Color3.fromRGB(196, 214, 120), fletch = Color3.fromRGB(58, 74, 30),
		glow = Color3.fromRGB(143, 194, 58), trail = 0.07,
	},
	rose = {
		shaft = V3(0.125, 0.125, 0.5), head = V3(0.375, 0.375, 0.375), core = V3(0.3, 0.3, 0.3),
		body = Color3.fromRGB(58, 92, 46), tip = Color3.fromRGB(190, 40, 52), fletch = Color3.fromRGB(150, 28, 44),
		glow = Color3.fromRGB(255, 92, 104), trail = 0.12,
	},
	spear = {
		shaft = V3(0.25, 0.25, 3.0), head = V3(0.375, 0.375, 0.625), core = V3(0.3, 0.3, 0.3),
		body = Color3.fromRGB(92, 58, 38), tip = Color3.fromRGB(217, 210, 197), fletch = Color3.fromRGB(140, 59, 46),
		glow = Color3.fromRGB(217, 164, 65), trail = 0.14,
	},
	trapbolt = {
		shaft = V3(0.25, 0.25, 1.0), head = V3(0.25, 0.25, 0.375), core = V3(0.25, 0.25, 0.25),
		body = Color3.fromRGB(70, 48, 34), tip = Color3.fromRGB(110, 102, 96), fletch = Color3.fromRGB(232, 220, 192),
		glow = Color3.fromRGB(255, 179, 71), trail = 0.08,
	},
	-- Этаж 3 (враги «Псарен»): болт арбалетчика-ловчего, болас капканщика, сокол сокольника.
	huntbolt = {
		shaft = V3(0.25, 0.25, 1.125), head = V3(0.25, 0.25, 0.5), core = V3(0.25, 0.25, 0.25),
		body = Color3.fromRGB(92, 58, 38), tip = Color3.fromRGB(196, 190, 180), fletch = Color3.fromRGB(140, 59, 46),
		glow = Color3.fromRGB(255, 179, 71), trail = 0.1,
	},
	bolas = {
		shaft = V3(1.5, 0.08, 0.08), head = V3(0.45, 0.45, 0.45), core = V3(0.45, 0.45, 0.45),
		body = Color3.fromRGB(196, 160, 104), tip = Color3.fromRGB(74, 67, 80), fletch = Color3.fromRGB(196, 160, 104),
		glow = Color3.fromRGB(110, 102, 96), trail = 0.06,
	},
	falcon = {
		shaft = V3(2.6, 0.15, 0.6), head = V3(0.35, 0.35, 0.45), core = V3(0.5, 0.45, 0.7),
		body = Color3.fromRGB(92, 70, 52), tip = Color3.fromRGB(255, 200, 87), fletch = Color3.fromRGB(232, 220, 192),
		glow = Color3.fromRGB(150, 120, 90), trail = 0.3,
	},
	rune = {
		shaft = V3(0.125, 0.125, 0.25), head = V3(0.5, 0.5, 0.125), core = V3(0.45, 0.45, 0.45),
		body = Color3.fromRGB(74, 63, 143), tip = Color3.fromRGB(142, 124, 224), fletch = Color3.fromRGB(184, 227, 255),
		glow = Color3.fromRGB(184, 227, 255), trail = 0.14,
	},
	page = {
		shaft = V3(0.625, 0.0625, 0.75), head = V3(0.5, 0.0625, 0.125), core = V3(0.12, 0.12, 0.12),
		body = Color3.fromRGB(236, 228, 204), tip = Color3.fromRGB(210, 198, 168), fletch = Color3.fromRGB(120, 104, 168),
		glow = Color3.fromRGB(184, 227, 255), trail = 0.1,
	},
}

local function attachArrow(serverPart: BasePart)
	if arrows[serverPart] then
		return
	end
	local arrow = table.remove(arrowFree) or makeArrow()
	local reflected = serverPart:GetAttribute("Reflected") == true
	-- Болты Арбалетчицы (ProjectileKind): толще, своё ядро.
	local kind = serverPart:GetAttribute("ProjectileKind") or "arrow"
	local bolt = kind ~= "arrow"
	arrow.shaft.Size = bolt and V3(0.25, 0.25, 0.875) or V3(0.125, 0.125, 0.625)
	arrow.head.Size = bolt and V3(0.25, 0.25, 0.375) or V3(0.125, 0.125, 0.25)
	arrow.core.Size = bolt and V3(0.35, 0.35, 0.35) or V3(0.2, 0.2, 0.2)
	arrow.core.Color = (kind == "lastBolt" and V.X) or (kind == "chainBolt" and V.A) or V.H
	local width = (reflected and 0.18 or 0.09) * (kind == "lastBolt" and 2.5 or (bolt and 1.5 or 1))
	arrow.a0.Position = V3(0, width, 0)
	arrow.a1.Position = V3(0, -width, 0)
	local tint = reflected and V.H or nil
	arrow.shaft.Color = tint or V.N
	arrow.fletch.Color = tint or V.W
	arrow.trail.Color = ColorSequence.new(reflected and V.H or (kind == "lastBolt" and V.X) or V.W)
	-- Этаж 2: шип следопыта и роза Садовницы; этаж 3: копьё и болт ловушки, болт ловчего, болас, сокол.
	local f2 = F2_ARROWS[kind]
	if f2 then
		arrow.shaft.Size = f2.shaft
		arrow.head.Size = f2.head
		arrow.core.Size = f2.core
		arrow.shaft.Color = tint or f2.body
		arrow.head.Color = f2.tip
		arrow.fletch.Color = tint or f2.fletch
		arrow.core.Color = f2.glow
		arrow.trail.Color = ColorSequence.new(reflected and V.H or f2.glow)
		arrow.a0.Position = V3(0, f2.trail, 0)
		arrow.a1.Position = V3(0, -f2.trail, 0)
	else
		arrow.head.Color = V.L
	end
	arrow.trail.Enabled = true
	arrow.server = serverPart
	arrows[serverPart] = arrow
end

local function releaseArrow(serverPart)
	local arrow = arrows[serverPart]
	if not arrow then
		return
	end
	arrows[serverPart] = nil
	if serverPart:GetAttribute("ProjectileResult") == "wall" then
		sound("arrowHit", arrow.core.Position)
	end
	arrow.trail.Enabled = false
	for _, part in ipairs({ arrow.shaft, arrow.head, arrow.fletch, arrow.core }) do
		part.CFrame = FAR
	end
	table.insert(arrowFree, arrow)
end

local function stepArrows()
	for serverPart, arrow in pairs(arrows) do
		if not serverPart.Parent then
			releaseArrow(serverPart)
		else
			-- Снаряд смотрит по направлению полёта (−Z — вперёд).
			local cf = serverPart.CFrame
			queue(arrow.shaft, cf)
			queue(arrow.head, cf * CFrame.new(0, 0, -0.4375))
			queue(arrow.fletch, cf * CFrame.new(0, 0, 0.4375))
			queue(arrow.core, cf)
		end
	end
end

local function watchProjectiles()
	local function hook(projectiles: Instance)
		projectiles.ChildAdded:Connect(function(child)
			if child:IsA("BasePart") then
				attachArrow(child)
			end
		end)
		projectiles.ChildRemoved:Connect(function(child)
			releaseArrow(child)
		end)
		for _, child in ipairs(projectiles:GetChildren()) do
			if child:IsA("BasePart") then
				attachArrow(child)
			end
		end
	end
	local existing = Workspace:FindFirstChild("Projectiles")
	if existing then
		hook(existing)
	end
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Projectiles" and child:IsA("Folder") then
			hook(child)
		end
	end)
end

-- ===== Общий шаг =====

function EnemyFx.step(dt: number)
	local now = os.clock()
	stepSouls(now)
	stepChainFalls(dt)
	stepArrows()
end

function EnemyFx.start()
	folder()
	setupEmitters()
	watchProjectiles()
end

return EnemyFx
