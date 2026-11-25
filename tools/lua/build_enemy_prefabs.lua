--!nonstrict
-- build_enemy_prefabs.lua — шаг 3 конвейера врагов: префабы-заглушки.
-- Собирает в ReplicatedStorage.EnemyPrefabs шесть моделей по шаблону
-- раздела 2.2 ТЗ: R15 Block Rig (Motor6D со стандартными именами),
-- AnimationController + Animator, папки Armor / Weapon / Glow / FX,
-- цвета тела, неоновые глаза. Броня — простые блоки нужных размеров и
-- основных цветов (не больше 25 частей брони, оружия и неона на врага, тело
-- R15 не считается — решение владельца). Оружие собрано из Part по сеткам ТЗ.
-- В конце Model:ScaleTo(k) по ТЗ.
--
-- Запуск в Studio (режим Edit), затем Ctrl+S:
--   node C:\Users\artem\.dsh-roblox\s.js exec tools/lua/build_enemy_prefabs.lua Edit
-- Повторный запуск пересобирает префабы с нуля. Меши из генератора брони
-- (шаг 5) заменяют блоки из папки Armor по именам — см. tools/enemy-armor/README.md.
--
-- Точки эффектов. Attachment не может жить в Folder (у него не будет мировой
-- позиции), поэтому сами FX_* стоят на частях тела и оружия, а в папке FX
-- лежат ObjectValue с теми же именами, указывающие на них.
--
-- Система координат сборки: начало — между ступнями на полу, враг смотрит в
-- −Z, +X — его правая сторона. Колонка 1 сетки «вид спереди» — правая
-- сторона врага (+X): зритель стоит перед ним.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local EnemyVisuals = require(ReplicatedStorage.Shared.Config.EnemyVisuals)

local V = Palette.Voxel
local VOX = 0.125
local RIG_VERSION = 1

local report = {}
local function log(text)
	table.insert(report, text)
end

-- ===== Тело R15 (масштаб 1.0, рост 5,2) =====

-- Части: размер и центр в осях модели.
local BODY = {
	HumanoidRootPart = { Vector3.new(2, 2, 1), Vector3.new(0, 2.6, 0) },
	LowerTorso = { Vector3.new(2, 0.4, 1), Vector3.new(0, 2.2, 0) },
	UpperTorso = { Vector3.new(2, 1.6, 1), Vector3.new(0, 3.2, 0) },
	Head = { Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0) },
	RightUpperArm = { Vector3.new(1, 1.2, 1), Vector3.new(1.5, 3.4, 0) },
	RightLowerArm = { Vector3.new(1, 1.0, 1), Vector3.new(1.5, 2.55, 0) },
	RightHand = { Vector3.new(1, 0.3, 1), Vector3.new(1.5, 2.05, 0) },
	LeftUpperArm = { Vector3.new(1, 1.2, 1), Vector3.new(-1.5, 3.4, 0) },
	LeftLowerArm = { Vector3.new(1, 1.0, 1), Vector3.new(-1.5, 2.55, 0) },
	LeftHand = { Vector3.new(1, 0.3, 1), Vector3.new(-1.5, 2.05, 0) },
	RightUpperLeg = { Vector3.new(1, 1.0, 1), Vector3.new(0.5, 1.55, 0) },
	RightLowerLeg = { Vector3.new(1, 1.0, 1), Vector3.new(0.5, 0.75, 0) },
	RightFoot = { Vector3.new(1, 0.3, 1), Vector3.new(0.5, 0.15, 0) },
	LeftUpperLeg = { Vector3.new(1, 1.0, 1), Vector3.new(-0.5, 1.55, 0) },
	LeftLowerLeg = { Vector3.new(1, 1.0, 1), Vector3.new(-0.5, 0.75, 0) },
	LeftFoot = { Vector3.new(1, 0.3, 1), Vector3.new(-0.5, 0.15, 0) },
}
local BODY_ORDER = {
	"HumanoidRootPart", "LowerTorso", "UpperTorso", "Head",
	"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
}

-- Суставы: имя, Part0, Part1, точка вращения в осях модели.
local JOINTS = {
	{ "Root", "HumanoidRootPart", "LowerTorso", Vector3.new(0, 2.2, 0) },
	{ "Waist", "LowerTorso", "UpperTorso", Vector3.new(0, 2.4, 0) },
	{ "Neck", "UpperTorso", "Head", Vector3.new(0, 4.0, 0) },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", Vector3.new(1.0, 3.75, 0) },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", Vector3.new(1.5, 2.9, 0) },
	{ "RightWrist", "RightLowerArm", "RightHand", Vector3.new(1.5, 2.15, 0) },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", Vector3.new(-1.0, 3.75, 0) },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", Vector3.new(-1.5, 2.9, 0) },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", Vector3.new(-1.5, 2.15, 0) },
	{ "RightHip", "LowerTorso", "RightUpperLeg", Vector3.new(0.5, 2.05, 0) },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", Vector3.new(0.5, 1.15, 0) },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", Vector3.new(0.5, 0.3, 0) },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", Vector3.new(-0.5, 2.05, 0) },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", Vector3.new(-0.5, 1.15, 0) },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", Vector3.new(-0.5, 0.3, 0) },
}

-- ===== Помощники =====

local function basePart(name: string, size: Vector3, color: Color3, cframe: CFrame, parent: Instance)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = cframe
	part.Parent = parent
	return part
end

local function weld(part0: BasePart, part1: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = part0
	constraint.Part1 = part1
	constraint.Parent = part1
	return constraint
end

-- Motor6D с точкой вращения pivot (CFrame в мире). rotation — поворот осей
-- сустава (у табарда и плаща 180° по Y, чтобы формулы ТЗ работали без смены
-- знака: положительный угол отводит низ назад).
local function motor(name: string, part0: BasePart, part1: BasePart, pivot: CFrame)
	local joint = Instance.new("Motor6D")
	joint.Name = name
	joint.Part0 = part0
	joint.Part1 = part1
	joint.C0 = part0.CFrame:ToObjectSpace(pivot)
	joint.C1 = part1.CFrame:ToObjectSpace(pivot)
	joint.Parent = part1
	return joint
end

local function attachment(name: string, parent: BasePart, position: Vector3, fxFolder: Folder?)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = position
	a.Parent = parent
	if fxFolder then
		local link = Instance.new("ObjectValue")
		link.Name = name
		link.Value = a
		link.Parent = fxFolder
	end
	return a
end

local function vox(x: number, y: number, z: number): Vector3
	return Vector3.new(x * VOX, y * VOX, z * VOX)
end

-- ===== Сборка одного врага =====

local function newRig(typeId: string, bodyColor: Color3)
	local model = Instance.new("Model")
	model.Name = typeId
	local body = {}
	for _, name in ipairs(BODY_ORDER) do
		local spec = BODY[name]
		local part = basePart(name, spec[1], bodyColor, CFrame.new(spec[2]), model)
		body[name] = part
	end
	local hrp = body.HumanoidRootPart
	hrp.Anchored = true
	hrp.Transparency = 1
	body.UpperTorso.CastShadow = true
	body.LowerTorso.CastShadow = true
	body.Head.CastShadow = true
	model.PrimaryPart = hrp

	for _, joint in ipairs(JOINTS) do
		motor(joint[1], body[joint[2]], body[joint[3]], CFrame.new(joint[4]))
	end

	local controller = Instance.new("AnimationController")
	controller.Parent = model
	local animator = Instance.new("Animator")
	animator.Parent = controller

	local folders = {}
	for _, name in ipairs({ "Armor", "Weapon", "Glow", "FX" }) do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = model
		folders[name] = folder
	end

	-- Общие точки эффектов.
	attachment("FX_HeadTop", body.Head, Vector3.new(0, 1.2, 0), folders.FX)
	attachment("FX_Chest", body.UpperTorso, Vector3.new(0, 0.2, -0.5), folders.FX)
	attachment("FX_Feet", hrp, Vector3.new(0, -2.6, 0), folders.FX)

	return {
		typeId = typeId,
		model = model,
		body = body,
		folders = folders,
		counts = { armor = 0, weapon = 0, glow = 0 },
	}
end

-- Деталь брони: размер в вокселях, смещение центра от центра части тела.
local function armor(rig, name: string, bodyName: string, size: Vector3, offset: Vector3, color: Color3, shadow: boolean?)
	local bodyPart = rig.body[bodyName]
	local part = basePart(name, vox(size.X, size.Y, size.Z), color, bodyPart.CFrame * CFrame.new(offset), rig.folders.Armor)
	part.CastShadow = shadow == true
	part:SetAttribute("Body", bodyName)
	weld(bodyPart, part)
	rig.counts.armor += 1
	return part
end

-- Деталь на своём Motor6D (табард, плащ, гребень, корона, цепи).
-- pivotLocal — точка подвеса в осях части тела, hang — смещение центра детали
-- от точки подвеса.
local function hanging(rig, name: string, bodyName: string, size: Vector3, pivotLocal: Vector3, hang: Vector3, color: Color3, flipped: boolean?, folder: string?)
	local bodyPart = rig.body[bodyName]
	local pivot = bodyPart.CFrame * CFrame.new(pivotLocal)
	local part = basePart(name, vox(size.X, size.Y, size.Z), color, pivot * CFrame.new(hang), rig.folders[folder or "Armor"])
	part:SetAttribute("Body", bodyName)
	local frame = flipped and (pivot * CFrame.Angles(0, math.pi, 0)) or pivot
	motor(name, bodyPart, part, frame)
	if (folder or "Armor") == "Armor" then
		rig.counts.armor += 1
	else
		rig.counts.glow += 1
	end
	return part
end

-- Неоновая деталь (глаза, трещины, заряды). role — что с ней делает клиент.
local function glow(rig, name: string, bodyName: string, size: Vector3, offset: Vector3, color: Color3, role: string, extra)
	local bodyPart = rig.body[bodyName]
	local part = basePart(name, size, color, bodyPart.CFrame * CFrame.new(offset), rig.folders.Glow)
	part.Material = Enum.Material.Neon
	part:SetAttribute("Role", role)
	for key, value in pairs(extra or {}) do
		part:SetAttribute(key, value)
	end
	weld(bodyPart, part)
	rig.counts.glow += 1
	return part
end

-- Пара глаз: центры по сетке, толщина 0,04, на 0,02 перед гранью.
local function eyes(rig, eyeColor: Color3, x: number, y: number, frontZ: number, width: number?)
	local size = Vector3.new(VOX * (width or 1), VOX, 0.04)
	local z = frontZ - 0.02 - 0.02
	local right = glow(rig, "EyeR", "Head", size, Vector3.new(x, y, z), eyeColor, "eye")
	local left = glow(rig, "EyeL", "Head", size, Vector3.new(-x, y, z), eyeColor, "eye")
	attachment("FX_Eyes", rig.body.Head, Vector3.new(0, y, z), rig.folders.FX)
	return right, left
end

-- Оружие из частей. spec.parts: { name, size (воксели), y (центр, воксели
-- от низа сетки), color, x? z? }; spec.main — имя части с хватом;
-- spec.gripY — строка хвата (центр, воксели от низа); hand — кисть;
-- reverse — обратный хват (C1 повёрнут на 180° по X).
local function weapon(rig, spec, hand: string, motorName: string?, c0Override: CFrame?, folder: string?)
	local parts = {}
	local handPart = rig.body[hand]
	-- Сначала собираем оружие в своих осях: начало — низ сетки, длинная ось +Y.
	local origin = CFrame.new(0, 50, 0)
	for _, item in ipairs(spec.parts) do
		local center = Vector3.new((item.x or 0) * VOX, item.y * VOX, (item.z or 0) * VOX)
		local cf = origin * CFrame.new(center) * (item.rotation or CFrame.identity)
		local part = basePart(item.name, vox(item.size.X, item.size.Y, item.size.Z), item.color, cf, rig.folders[folder or "Weapon"])
		part.CastShadow = item.shadow == true
		if item.shape then
			part.Shape = item.shape
		end
		parts[item.name] = part
		rig.counts.weapon += 1
	end
	local main = parts[spec.main]
	for name, part in pairs(parts) do
		if name ~= spec.main then
			weld(main, part)
		end
	end
	-- Хват: C0 = (0, −0.15, 0) · Angles(−90°, 0, 0) — правило предметов в
	-- руке (раздел 2.2); C1 — точка хвата в осях главной части.
	local gripWorld = origin * CFrame.new(0, spec.gripY * VOX, 0)
	local joint = Instance.new("Motor6D")
	joint.Name = motorName or "WeaponGrip"
	joint.Part0 = handPart
	joint.Part1 = main
	joint.C0 = c0Override or (CFrame.new(0, -0.15, 0) * CFrame.Angles(math.rad(-90), 0, 0))
	local c1 = main.CFrame:ToObjectSpace(gripWorld)
	if spec.reverse then
		c1 = c1 * CFrame.Angles(math.pi, 0, 0)
	end
	if spec.c1Rotation then
		c1 = c1 * spec.c1Rotation
	end
	joint.C1 = c1
	joint.Parent = main
	-- Точки следа (строки сетки) — в осях главной части, до переноса.
	for name, y in pairs(spec.points or {}) do
		attachment(name, main, main.CFrame:PointToObjectSpace((origin * CFrame.new(0, y * VOX, 0)).Position), rig.folders.FX)
	end
	-- Ставим оружие на место по суставу.
	local target = handPart.CFrame * joint.C0 * joint.C1:Inverse()
	local shift = target * main.CFrame:Inverse()
	for _, part in pairs(parts) do
		part.CFrame = shift * part.CFrame
	end
	return main, parts
end

local function emitter(parent: Instance, name: string, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for key, value in pairs(props) do
		e[key] = value
	end
	e.Parent = parent
	return e
end

local function seq(a: number, b: number)
	return NumberSequence.new(a, b)
end

-- ===== Враги (раздел 2.4) =====

local BUILDERS = {}

-- 2.4.1 Ржавый страж: капеллина, баклер, прямой меч, табард.
function BUILDERS.guard()
	local rig = newRig("guard", V.S)
	armor(rig, "Helmet", "Head", Vector3.new(12, 12, 12), Vector3.new(0, 0.06, 0), V.G, true)
	-- Поля: кольцо на строке 05 (центр строки 0,1875 выше центра шлема).
	armor(rig, "HelmetBrim", "Head", Vector3.new(16, 1, 16), Vector3.new(0, 0.06 + 0.1875, 0), V.R, true)
	armor(rig, "Cuirass", "UpperTorso", Vector3.new(18, 14, 10), Vector3.new(0, 0, 0), V.G, true)
	armor(rig, "PauldronR", "RightUpperArm", Vector3.new(11, 5, 11), Vector3.new(0.12, 0.45, 0), V.G)
	armor(rig, "PauldronL", "LeftUpperArm", Vector3.new(11, 5, 11), Vector3.new(-0.12, 0.45, 0), V.G)
	armor(rig, "BracerR", "RightLowerArm", Vector3.new(10, 5, 10), Vector3.new(0, -0.19, 0), V.R)
	armor(rig, "BracerL", "LeftLowerArm", Vector3.new(10, 5, 10), Vector3.new(0, -0.19, 0), V.R)
	-- Табард качается на Motor6D Tabard (точка подвеса — пояс спереди).
	hanging(rig, "Tabard", "LowerTorso", Vector3.new(8, 12, 1), Vector3.new(0, 0.2, -0.5625), Vector3.new(0, -0.75, 0), V.D, true)
	armor(rig, "GreaveR", "RightLowerLeg", Vector3.new(10, 9, 10), Vector3.new(0, 0.1, 0), V.G)
	armor(rig, "GreaveL", "LeftLowerLeg", Vector3.new(10, 9, 10), Vector3.new(0, 0.1, 0), V.G)
	armor(rig, "BootR", "RightFoot", Vector3.new(10, 3, 12), Vector3.new(0, 0.04, -0.125), V.B)
	armor(rig, "BootL", "LeftFoot", Vector3.new(10, 3, 12), Vector3.new(0, 0.04, -0.125), V.B)
	-- Глаза: строка 07, столбцы 4 и 9 сетки шлема 12×12.
	eyes(rig, EnemyVisuals.Types.guard.eyeColor, 0.3125, 0.06 - 0.0625, -0.75)

	-- Меч: 7×30, клинок 1, гарда 3, рукоять 2; хват — строка 05.
	weapon(rig, {
		main = "Grip",
		gripY = 4.5,
		parts = {
			{ name = "Blade", size = Vector3.new(5, 19, 1), y = 20.5, color = V.L },
			{ name = "Guard", size = Vector3.new(7, 4, 3), y = 9, color = V.A },
			{ name = "Grip", size = Vector3.new(3, 5, 2), y = 4.5, color = V.B },
			{ name = "Pommel", size = Vector3.new(5, 2, 2), y = 1, color = V.A },
		},
		points = { FX_WeaponBase = 11.5, FX_WeaponTip = 29.5 },
	}, "RightHand")

	-- Баклер 12×12×2 на левой кисти (лицо наружу-вперёд). Заглушка квадратная,
	-- круг даст меш.
	weapon(rig, {
		main = "Buckler",
		gripY = 6,
		parts = {
			{ name = "Buckler", size = Vector3.new(12, 12, 2), y = 6, color = V.R, shadow = true },
		},
	}, "LeftHand", "ShieldGrip", CFrame.new(-0.35, -0.1, -0.15) * CFrame.Angles(0, math.rad(90), 0))
	return rig
end

-- 2.4.2 Тень: острый капюшон, рваный плащ, два кинжала обратным хватом.
function BUILDERS.shade()
	local rig = newRig("shade", V.K)
	for _, name in ipairs({ "RightLowerLeg", "LeftLowerLeg", "RightFoot", "LeftFoot" }) do
		rig.body[name].Transparency = 0.25
	end
	armor(rig, "Hood", "Head", Vector3.new(13, 13, 13), Vector3.new(0, 0.05, 0), V.S, true)
	-- Хвост капюшона: 3×3 у макушки сзади, свисает назад на 4.
	armor(rig, "HoodTail", "Head", Vector3.new(3, 3, 4), Vector3.new(0, 0.55, 0.95), V.S)
	armor(rig, "Pelerine", "UpperTorso", Vector3.new(18, 8, 10), Vector3.new(0, 0.3, 0), V.S, true)
	-- Плащ на Motor6D Cloak, подвес — верх спины.
	hanging(rig, "Cloak", "UpperTorso", Vector3.new(16, 27, 1), Vector3.new(0, 0.75, 0.5625), Vector3.new(0, -1.6875, 0), V.S, true)
	armor(rig, "WrapLegR", "RightLowerLeg", Vector3.new(9, 9, 9), Vector3.new(0, 0, 0), V.D)
	armor(rig, "WrapLegL", "LeftLowerLeg", Vector3.new(9, 9, 9), Vector3.new(0, 0, 0), V.D)
	armor(rig, "WrapArmR", "RightLowerArm", Vector3.new(9, 7, 9), Vector3.new(0, -0.06, 0), V.D)
	armor(rig, "WrapArmL", "LeftLowerArm", Vector3.new(9, 7, 9), Vector3.new(0, -0.06, 0), V.D)
	-- Глаза: строка 07, столбцы 5 и 9 капюшона 13×13; костяные точки 1×1.
	eyes(rig, EnemyVisuals.Types.shade.eyeColor, 0.25, 0.05, -0.8125)

	-- Кинжалы 5×16, хват — строка 04, обратный хват.
	local function dagger(hand: string, suffix: string, points)
		return weapon(rig, {
			main = "DaggerGrip" .. suffix,
			gripY = 3.5,
			reverse = true,
			parts = {
				{ name = "DaggerBlade" .. suffix, size = Vector3.new(3, 8, 1), y = 12.5, color = V.W },
				{ name = "DaggerGuard" .. suffix, size = Vector3.new(5, 3, 2), y = 7, color = V.G },
				{ name = "DaggerGrip" .. suffix, size = Vector3.new(3, 5, 2), y = 3, color = V.B },
			},
			points = points,
		}, hand)
	end
	dagger("RightHand", "R", { FX_WeaponBase = 8.5, FX_WeaponTip = 15.5 })
	local left = dagger("LeftHand", "L", nil)
	left:FindFirstChildOfClass("Motor6D").Name = "WeaponGripL"

	-- Дым у ступней (раздел 2.4.2, «Частицы»).
	emitter(rig.body.HumanoidRootPart:FindFirstChild("FX_Feet"), "ShadeSmoke", {
		Rate = 10,
		Lifetime = NumberRange.new(0.6, 0.9),
		Speed = NumberRange.new(0.5, 1),
		Size = seq(0.6, 1.4),
		Color = ColorSequence.new(V.S, V.K),
		Transparency = seq(0.5, 1),
		LightEmission = 0,
		Acceleration = Vector3.new(0, 1, 0),
		SpreadAngle = Vector2.new(180, 180),
	})
	return rig
end

-- 2.4.3 Латник: шлем-ведро с гребнем, ростовой щит, булава.
function BUILDERS.knight()
	local rig = newRig("knight", V.G)
	armor(rig, "Helmet", "Head", Vector3.new(13, 14, 13), Vector3.new(0, 0.1, 0), V.G, true)
	-- Гребень на своём суставе (дрожит с шагом).
	hanging(rig, "Crest", "Head", Vector3.new(3, 6, 8), Vector3.new(0, 0.1 + 0.875, 0.06), Vector3.new(0, 0.375, 0), V.A)
	armor(rig, "Cuirass", "UpperTorso", Vector3.new(18, 14, 10), Vector3.new(0, 0, 0), V.G, true)
	armor(rig, "PauldronR", "RightUpperArm", Vector3.new(13, 6, 13), Vector3.new(0.15, 0.42, 0), V.L, true)
	armor(rig, "PauldronL", "LeftUpperArm", Vector3.new(13, 6, 13), Vector3.new(-0.15, 0.42, 0), V.L, true)
	armor(rig, "Faulds", "LowerTorso", Vector3.new(18, 4, 10), Vector3.new(0, -0.05, 0), V.S)
	armor(rig, "GreaveR", "RightLowerLeg", Vector3.new(10, 9, 10), Vector3.new(0, 0.1, 0), V.G)
	armor(rig, "GreaveL", "LeftLowerLeg", Vector3.new(10, 9, 10), Vector3.new(0, 0.1, 0), V.G)
	armor(rig, "BootR", "RightFoot", Vector3.new(10, 3, 12), Vector3.new(0, 0.04, -0.125), V.B)
	armor(rig, "BootL", "LeftFoot", Vector3.new(10, 3, 12), Vector3.new(0, 0.04, -0.125), V.B)
	armor(rig, "BracerR", "RightLowerArm", Vector3.new(10, 6, 10), Vector3.new(0, -0.12, 0), V.G)
	armor(rig, "BracerL", "LeftLowerArm", Vector3.new(10, 6, 10), Vector3.new(0, -0.12, 0), V.G)
	-- Глаза: строка 08, столбцы 4 и 10 шлема 13×14.
	eyes(rig, EnemyVisuals.Types.knight.eyeColor, 0.375, 0.1 - 0.0625, -0.8125)

	-- Булава 8×26: головка 6×6×6 (строки 20–25), древко, навершие; хват — строка 06.
	weapon(rig, {
		main = "MaceShaft",
		gripY = 5.5,
		parts = {
			{ name = "MaceHead", size = Vector3.new(6, 6, 6), y = 22, color = V.G, shadow = true },
			{ name = "MaceShaft", size = Vector3.new(3, 17, 3), y = 10.5, color = V.N },
			{ name = "MacePommel", size = Vector3.new(4, 2, 3), y = 1, color = V.A },
		},
		points = { FX_WeaponBase = 18.5, FX_WeaponTip = 25.5 },
	}, "RightHand")

	-- Ростовой щит 16×26×2 на левом предплечье.
	weapon(rig, {
		main = "TowerShield",
		gripY = 13,
		parts = {
			{ name = "TowerShield", size = Vector3.new(16, 26, 2), y = 13, color = V.G, shadow = true },
		},
	}, "LeftLowerArm", "ShieldGrip", CFrame.new(-0.6, -0.2, -0.2) * CFrame.Angles(0, math.rad(90), 0))
	return rig
end

-- 2.4.4 Теневой стрелок: капюшон с костяной маской, лук, колчан.
function BUILDERS.archer()
	local rig = newRig("archer", V.D)
	armor(rig, "Hood", "Head", Vector3.new(12, 12, 12), Vector3.new(0, 0.05, 0), V.D, true)
	-- Маска: строки 07–10 (камень со стежками).
	armor(rig, "Mask", "Head", Vector3.new(8, 4, 1), Vector3.new(0, 0.05 - 0.3125, -0.8125), V.S)
	armor(rig, "Jacket", "UpperTorso", Vector3.new(18, 14, 10), Vector3.new(0, 0, 0), V.R, true)
	local quiver = armor(rig, "Quiver", "UpperTorso", Vector3.new(5, 16, 5), Vector3.new(0.55, 0.35, 0.85), V.N)
	quiver.CFrame = quiver.CFrame * CFrame.Angles(0, 0, math.rad(-15))
	armor(rig, "BracerR", "RightLowerArm", Vector3.new(9, 6, 9), Vector3.new(0, -0.12, 0), V.B)
	armor(rig, "BracerL", "LeftLowerArm", Vector3.new(9, 6, 9), Vector3.new(0, -0.12, 0), V.B)
	armor(rig, "BootR", "RightFoot", Vector3.new(10, 4, 11), Vector3.new(0, 0.1, -0.0625), V.B)
	armor(rig, "BootL", "LeftFoot", Vector3.new(10, 4, 11), Vector3.new(0, 0.1, -0.0625), V.B)
	-- Глаза: строка 06, столбцы 5 и 8 капюшона 12×12.
	eyes(rig, EnemyVisuals.Types.archer.eyeColor, 0.1875, 0.05 + 0.0625, -0.75)

	-- Лук: 34 вокселя по +Y, хват посередине (y = 17), плечи — дуга
	-- x(y) = 4 − 4·((y − 17)/17)² вперёд от хвата. «Вперёд» у предмета в
	-- руке — его −Z (при поднятой руке +Y смотрит вверх, −Z — на цель),
	-- поэтому концы плеч на 4 вокселя дальше по +Z, к стрелку.
	local tilt = math.atan(4 / 17)
	local limb = math.sqrt(17 * 17 + 4 * 4)
	local main = weapon(rig, {
		main = "BowGrip",
		gripY = 17,
		parts = {
			{ name = "BowGrip", size = Vector3.new(2, 5, 2), y = 17, color = V.B },
			{ name = "BowLimbTop", size = Vector3.new(2, limb, 2), y = 25.5, z = 2, color = V.N, rotation = CFrame.Angles(tilt, 0, 0) },
			{ name = "BowLimbBottom", size = Vector3.new(2, limb, 2), y = 8.5, z = 2, color = V.N, rotation = CFrame.Angles(-tilt, 0, 0) },
		},
	}, "LeftHand", "BowGrip")
	-- Тетива — два Beam (раздел 2.4.4): BowTop → FX_BowNock → BowBottom.
	local top = attachment("BowTop", main, Vector3.new(0, 17 * VOX, 4 * VOX))
	local bottom = attachment("BowBottom", main, Vector3.new(0, -17 * VOX, 4 * VOX))
	local nock = attachment("FX_BowNock", main, Vector3.new(0, 0, 4 * VOX), rig.folders.FX)
	for index, pair in ipairs({ { top, nock }, { nock, bottom } }) do
		local beam = Instance.new("Beam")
		beam.Name = "String" .. index
		beam.Attachment0 = pair[1]
		beam.Attachment1 = pair[2]
		beam.Width0 = 0.05
		beam.Width1 = 0.05
		beam.Color = ColorSequence.new(V.H)
		beam.LightEmission = 0.3
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Parent = main
	end
	-- Колчан не оружие, но стрелы на нём — часть силуэта; FX у лука — кончик плеча.
	attachment("FX_WeaponBase", main, Vector3.new(0, 0, 0), rig.folders.FX)
	attachment("FX_WeaponTip", main, Vector3.new(0, 17 * VOX, 4 * VOX), rig.folders.FX)
	return rig
end

-- 2.4.5 Треснувший: маска-голова, связка зарядов с фитилём, трещины.
function BUILDERS.martyr()
	local rig = newRig("martyr", V.R)
	local X = V.X
	armor(rig, "Mask", "Head", Vector3.new(12, 12, 12), Vector3.new(0, 0, 0), V.R, true)
	local pack = armor(rig, "ChargePack", "UpperTorso", Vector3.new(18, 14, 3), Vector3.new(0, 0, -0.5 - 0.1875), V.R, true)
	armor(rig, "BracerR", "RightLowerArm", Vector3.new(9, 8, 9), Vector3.new(0, -0.0, 0), V.D)
	armor(rig, "BracerL", "LeftLowerArm", Vector3.new(9, 8, 9), Vector3.new(0, -0.0, 0), V.D)
	-- Заряды: три цилиндра (строки 06–10, столбцы 4–5, 9–10, 14–15).
	local packFront = -0.5 - 0.375 - 0.03
	for index, column in ipairs({ 4.5, 9.5, 14.5 }) do
		local bomb = glow(rig, "Bomb" .. index, "UpperTorso", vox(2, 5, 1), Vector3.new((9.5 - column) * VOX, 7 * VOX - 7.5 * VOX, packFront), X, "bomb")
		bomb.Material = Enum.Material.SmoothPlastic
	end
	-- Фитиль 1×3 над средним зарядом.
	local fuse = armor(rig, "Fuse", "UpperTorso", Vector3.new(1, 3, 1), Vector3.new(0, (7 - 3.5) * VOX + 0.2, packFront), V.W)
	attachment("FX_Fuse", fuse, Vector3.new(0, 1.5 * VOX, 0), rig.folders.FX)
	-- Глаза 2×1: строка 06, столбцы 4–5 и 8–9.
	eyes(rig, EnemyVisuals.Types.martyr.eyeColor, 0.25, 0.0625, -0.75, 2)
	-- Трещины: маска (2), спина (2 диагонали), правое предплечье, левое бедро.
	glow(rig, "CrackMask1", "Head", vox(1, 3, 0.3), Vector3.new(-0.25, 0.45, -0.77), X, "crack")
	glow(rig, "CrackMask2", "Head", vox(1, 2, 0.3), Vector3.new(0.0, -0.05, -0.77), X, "crack")
	local back1 = glow(rig, "CrackBack1", "UpperTorso", vox(1, 6, 0.3), Vector3.new(0.3, 0.1, 0.53), X, "crack")
	back1.CFrame = back1.CFrame * CFrame.Angles(0, 0, math.rad(35))
	local back2 = glow(rig, "CrackBack2", "UpperTorso", vox(1, 8, 0.3), Vector3.new(-0.35, -0.1, 0.53), X, "crack")
	back2.CFrame = back2.CFrame * CFrame.Angles(0, 0, math.rad(-30))
	glow(rig, "CrackArmR", "RightLowerArm", vox(1, 6, 0.3), Vector3.new(0.53, 0.1, 0), X, "crack")
	glow(rig, "CrackLegL", "LeftUpperLeg", vox(1, 5, 0.3), Vector3.new(0, 0, -0.53), X, "crack")
	-- Повёрнутые трещины надо переварить заново: WeldConstraint запомнил старое.
	for _, part in ipairs({ back1, back2 }) do
		part:FindFirstChildOfClass("WeldConstraint"):Destroy()
		weld(rig.body.UpperTorso, part)
	end
	-- Колчан у стрелка поворачивали так же; здесь — пояс зарядов.
	pack:SetAttribute("Role", "pack")

	emitter(rig.model.Armor.Fuse:FindFirstChild("FX_Fuse"), "FuseSparks", {
		Rate = 6,
		Lifetime = NumberRange.new(0.2, 0.4),
		Speed = NumberRange.new(2, 5),
		Size = seq(0.15, 0),
		Color = ColorSequence.new(V.A, X),
		LightEmission = 1,
		SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Top,
	})
	emitter(rig.body.UpperTorso:FindFirstChild("FX_Chest"), "Heat", {
		Rate = 4,
		Lifetime = NumberRange.new(0.8, 0.8),
		Speed = NumberRange.new(0.5, 0.5),
		Size = seq(0.3, 0.6),
		Color = ColorSequence.new(X),
		Transparency = seq(0.6, 1),
		LightEmission = 0.5,
		SpreadAngle = Vector2.new(60, 60),
	})
	return rig
end

-- 2.4.6 Привратник: шлем-решётка, корона из ключей, башни-наплечники,
-- меч-засов, цепи на руках. Трещины и скважина — до фазы II скрыты.
function BUILDERS.gatekeeper()
	local rig = newRig("gatekeeper", V.S)
	local A = V.A
	armor(rig, "Helmet", "Head", Vector3.new(15, 15, 13), Vector3.new(0, 0.12, 0), V.G, true)
	-- Корона (обод 2 + зубцы до 5) одним блоком на суставе Crown: дрожит на
	-- шагах. Лимит 25 частей не даёт делить её на обод и зубцы.
	hanging(rig, "Crown", "Head", Vector3.new(15, 7, 13), Vector3.new(0, 0.12 + 0.9375, 0), Vector3.new(0, 0.4375, 0), A)
	armor(rig, "Cuirass", "UpperTorso", Vector3.new(18, 14, 10), Vector3.new(0, 0, 0), V.G, true)
	armor(rig, "TowerR", "RightUpperArm", Vector3.new(12, 8, 12), Vector3.new(0.15, 0.4, 0), V.G, true)
	armor(rig, "TowerL", "LeftUpperArm", Vector3.new(12, 8, 12), Vector3.new(-0.15, 0.4, 0), V.G, true)
	armor(rig, "Skirt", "LowerTorso", Vector3.new(18, 6, 10), Vector3.new(0, -0.15, 0), V.G)
	armor(rig, "BracerR", "RightLowerArm", Vector3.new(10, 7, 10), Vector3.new(0, -0.06, 0), V.G)
	armor(rig, "BracerL", "LeftLowerArm", Vector3.new(10, 7, 10), Vector3.new(0, -0.06, 0), V.G)
	-- Цепи: одна часть на руку (4 звена по 3 вокселя), на суставах ChainR/ChainL.
	hanging(rig, "ChainR", "RightLowerArm", Vector3.new(3, 12, 1), Vector3.new(0.6, -0.35, 0), Vector3.new(0, -0.75, 0), V.G)
	hanging(rig, "ChainL", "LeftLowerArm", Vector3.new(3, 12, 1), Vector3.new(-0.6, -0.35, 0), Vector3.new(0, -0.75, 0), V.G)
	armor(rig, "GreaveR", "RightLowerLeg", Vector3.new(11, 10, 11), Vector3.new(0, 0.1, 0), V.G)
	armor(rig, "GreaveL", "LeftLowerLeg", Vector3.new(11, 10, 11), Vector3.new(0, 0.1, 0), V.G)
	armor(rig, "BootR", "RightFoot", Vector3.new(11, 4, 13), Vector3.new(0, 0.1, -0.125), V.S)
	armor(rig, "BootL", "LeftFoot", Vector3.new(11, 4, 13), Vector3.new(0, 0.1, -0.125), V.S)
	-- Глаза: строка 07, столбцы 5 и 11 шлема 15×15, со светом.
	local eyeR, eyeL = eyes(rig, A, 0.375, 0.12 + 0.125, -0.8125)
	for _, eye in ipairs({ eyeR, eyeL }) do
		local light = Instance.new("PointLight")
		light.Color = A
		light.Range = 6
		light.Brightness = 1
		light.Parent = eye
	end

	-- Скважина и трещины фазы II (скрыты: Transparency 1).
	local keyhole = glow(rig, "Keyhole", "UpperTorso", vox(2, 3, 0.3), Vector3.new(0, -0.1, -0.66), A, "keyhole", { Phase = 2 })
	keyhole.Transparency = 1
	local keyAttachment = attachment("FX_Keyhole", rig.body.UpperTorso, Vector3.new(0, -0.1, -0.7), rig.folders.FX)
	local keyLight = Instance.new("PointLight")
	keyLight.Name = "KeyholeLight"
	keyLight.Color = A
	keyLight.Range = 10
	keyLight.Brightness = 2
	keyLight.Enabled = false
	keyLight.Parent = keyAttachment
	emitter(keyAttachment, "KeyholeRays", {
		Enabled = false,
		Rate = 12,
		Lifetime = NumberRange.new(0.5, 0.5),
		Speed = NumberRange.new(4, 4),
		SpreadAngle = Vector2.new(15, 15),
		Size = seq(0.2, 0),
		Color = ColorSequence.new(A),
		LightEmission = 1,
		EmissionDirection = Enum.NormalId.Front,
	})
	local cracks = {
		{ "CrackChest1", "UpperTorso", vox(1, 7, 0.3), Vector3.new(0.45, 0.2, -0.66), 35 },
		{ "CrackChest2", "UpperTorso", vox(9, 1, 0.3), Vector3.new(-0.2, -0.45, -0.66), 0 },
		{ "CrackShoulderR", "RightUpperArm", vox(1, 6, 0.3), Vector3.new(0, 0, -0.78), 0 },
		{ "CrackThighL", "LeftUpperLeg", vox(1, 6, 0.3), Vector3.new(0, 0, -0.53), 0 },
		{ "CrackHelm", "Head", vox(3, 1, 0.3), Vector3.new(0.375, 0.5, -0.83), 0 },
	}
	for _, spec in ipairs(cracks) do
		local part = glow(rig, spec[1], spec[2], spec[3], spec[4], A, "crack2", { Phase = 2 })
		if spec[5] ~= 0 then
			part.CFrame = part.CFrame * CFrame.Angles(0, 0, math.rad(spec[5]))
			part:FindFirstChildOfClass("WeldConstraint"):Destroy()
			weld(rig.body[spec[2]], part)
		end
		part.Transparency = 1
	end

	-- Меч-засов 13×44: клинок 7 (с контуром 9) × 30, гарда 13×4, рукоять
	-- под две руки с навершием-ключом; хват — строка 07.
	weapon(rig, {
		main = "BoltHilt",
		gripY = 6.5,
		parts = {
			{ name = "BoltBlade", size = Vector3.new(9, 31, 2), y = 28.5, color = V.L, shadow = true },
			{ name = "BoltHilt", size = Vector3.new(13, 13, 3), y = 6.5, color = A },
		},
		points = { FX_WeaponBase = 13.5, FX_WeaponTip = 43.5 },
	}, "RightHand")

	-- Ржавая пыль из-под наплечников (покой).
	for _, side in ipairs({ "RightUpperArm", "LeftUpperArm" }) do
		local a = attachment("RustDust", rig.body[side], Vector3.new(0, -0.1, 0))
		emitter(a, "RustDust", {
			Rate = 3,
			Lifetime = NumberRange.new(1.5, 1.5),
			Speed = NumberRange.new(0.3, 0.8),
			Size = seq(0.12, 0.05),
			Color = ColorSequence.new(V.R),
			EmissionDirection = Enum.NormalId.Bottom,
			Acceleration = Vector3.new(0, -2, 0),
		})
	end
	-- Искры из трещин фазы II.
	emitter(rig.body.UpperTorso:FindFirstChild("FX_Chest"), "PhaseSparks", {
		Enabled = false,
		Rate = 8,
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(2, 4),
		Size = seq(0.15, 0),
		Color = ColorSequence.new(A),
		LightEmission = 1,
		SpreadAngle = Vector2.new(70, 70),
	})
	return rig
end

-- ===== Запуск =====

local folder = ReplicatedStorage:FindFirstChild("EnemyPrefabs")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "EnemyPrefabs"
	folder.Parent = ReplicatedStorage
end

for _, typeId in ipairs({ "guard", "shade", "knight", "archer", "martyr", "gatekeeper" }) do
	local rig = BUILDERS[typeId]()
	local model = rig.model
	local config = EnemyVisuals.Types[typeId]
	model:SetAttribute("TypeId", typeId)
	model:SetAttribute("Scale", config.scale)
	model:SetAttribute("RigVersion", RIG_VERSION)
	model:PivotTo(CFrame.new(0, 0, 0))
	model:ScaleTo(config.scale)
	local old = folder:FindFirstChild(typeId)
	if old then
		old:Destroy()
	end
	model.Parent = folder
	local extra = rig.counts.armor + rig.counts.weapon + rig.counts.glow
	local _, size = model:GetBoundingBox()
	log(("%-11s масштаб %.2f  рост %.2f  броня %d  оружие %d  неон %d  = %d %s"):format(
		typeId,
		config.scale,
		5.2 * config.scale,
		rig.counts.armor,
		rig.counts.weapon,
		rig.counts.glow,
		extra,
		extra <= 25 and "(≤ 25)" or "(БОЛЬШЕ 25!)"
	))
	log(("            габарит модели %.1f × %.1f × %.1f"):format(size.X, size.Y, size.Z))
	task.wait()
end

log("Готово: ReplicatedStorage.EnemyPrefabs. Не забудь Ctrl+S.")
return table.concat(report, "\n")
