--!nonstrict
-- VoxelWeaponBuilder
-- Строит воксельную модель оружия из таблицы вокселей (приложение Г, «Оружие:
-- 3D-модель»). Формы восьми видов оружия этажа 1 нарисованы по концептам из
-- assets/1 этаж (обычное, редкое, эпическое, легендарное оружие).
--
-- Конвенции:
--  * один воксель = VoxelSize стадов (0.22);
--  * сетка целочисленная, X — поперёк клинка, Y — вдоль клинка, Z — толщина;
--  * рукоять в начале координат: клинок растёт вверх от нуля;
--  * в модели есть Root с Attachment "Grip" в (0,0,0) — за неё оружие
--    цепляется к руке; BladeBase/BladeTip — концы следа удара;
--  * соседние воксели одной роли вдоль Y склеиваются в один брусок: деталей
--    в разы меньше, вид тот же;
--  * роли с суффиксом Glow — неон (светящиеся прожилки редкого оружия);
--  * цвета только из Palette.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(script.Parent.Parent.Config.Palette)

local VoxelWeaponBuilder = {}

-- Объёмные меши оружия (Blender → glb → Import 3D, 24.10.2026). Сборщик
-- AssembleWeapons.lua кладёт MeshPart в ReplicatedStorage.WeaponMeshes,
-- данные мест — Config.WeaponMeshData. Есть меши — модель из них; нет —
-- прежние воксели (ничего не ломается, пока меши не залиты).
local meshDataOk, MeshData = pcall(function()
	local data = require(script.Parent.Parent.Config.WeaponMeshData)
	-- Этажи 2–5: меши лежат в WeaponMeshDataFloorN (tools/weapons/export_weapons_floor2.py,
	-- export_weapons_floors.py N), id оружия не пересекаются. Нет модуля — этаж просто пропускается.
	local merged = {}
	for id, entry in pairs(data) do
		merged[id] = entry
	end
	for floor = 2, 5 do
		local extra = script.Parent.Parent.Config:FindFirstChild("WeaponMeshDataFloor" .. floor)
		if extra then
			for id, entry in pairs(require(extra)) do
				merged[id] = entry
			end
		end
	end
	return merged
end)
-- Посохи мага: меши в WeaponMeshDataMage (tools/mage-weapons/export_staffs.py), id не пересекаются.
if meshDataOk and MeshData then
	local mage = script.Parent.Parent.Config:FindFirstChild("WeaponMeshDataMage")
	if mage then
		local okMage, mageData = pcall(require, mage)
		if okMage and type(mageData) == "table" then
			local merged = {}
			for id, entry in pairs(MeshData) do
				merged[id] = entry
			end
			for id, entry in pairs(mageData) do
				merged[id] = entry
			end
			MeshData = merged
		end
	end
end
if not meshDataOk then
	MeshData = nil
end

-- Этажи 3–5: меши в WeaponMeshDataFloor3/4/5 (tools/weapons/export_weapons_floors.py),
-- id оружия не пересекаются. Без этого блока клинки 3–5 показывались моделью
-- начального меча: своих данных мешей у них не было.
if meshDataOk and MeshData then
	for _, floor in ipairs({ 3, 4, 5 }) do
		local extra = script.Parent.Parent.Config:FindFirstChild("WeaponMeshDataFloor" .. floor)
		if extra then
			local okExtra, extraData = pcall(require, extra)
			if okExtra and type(extraData) == "table" then
				local merged = {}
				for id, entry in pairs(MeshData) do
					merged[id] = entry
				end
				for id, entry in pairs(extraData) do
					merged[id] = entry
				end
				MeshData = merged
			end
		end
	end
end
VoxelWeaponBuilder.MeshFolderName = "WeaponMeshes"

-- 0.22, а не 0.25 из плана: формы по концептам длиннее старых (17–21
-- вокселей клинка), при 0.25 меч выходил выше героя.
VoxelWeaponBuilder.VoxelSize = 0.22

local Env = Palette.Env
local M = Palette.Material

-- Роли вокселей -> цвета.
VoxelWeaponBuilder.DefaultColors = {
	grip = Env.woodDark,
	gripWrap = Env.wood:Lerp(Env.rust, 0.3),
	guard = Env.iron:Lerp(Env.rust, 0.45),
	blade = Env.ironLight:Lerp(Env.bone, 0.4),
	bladeDark = Env.ironLight:Lerp(Env.iron, 0.3),
	bladeEdge = M.bladeEdge,
	rust = Env.rust,
	rustLight = Env.rust:Lerp(Env.gold, 0.45),
	gold = Env.gold,
	bronze = Env.gold:Lerp(Env.woodDark, 0.45),
	bronzeDark = Env.gold:Lerp(Env.woodDark, 0.7),
	cream = Env.sandLight:Lerp(Env.bone, 0.6),
	iron = Env.iron,
	ironLight = Env.ironLight,
	wood = Env.wood,
	goldGlow = Env.gold:Lerp(Env.flameCore, 0.45),
	emberGlow = Env.ember,
	-- Кристалл посоха мага (фолбэк без мешей).
	arcaneGlow = Color3.fromRGB(150, 110, 255),
	-- Старые роли (тесты и витрина).
	accent = M.steelDark,
	head = M.stone,
}

local function newShape()
	local voxels, seen = {}, {}
	local shape = {}
	function shape.put(x: number, y: number, z: number, role: string)
		local key = ("%d:%d:%d"):format(x, y, z)
		local existing = seen[key]
		if existing then
			existing.role = role -- поздний мазок перекрывает ранний
			return
		end
		local voxel = { x = x, y = y, z = z, role = role }
		seen[key] = voxel
		table.insert(voxels, voxel)
	end
	-- Прямоугольник по X×Y на слое(ях) Z.
	function shape.rect(x0: number, x1: number, y0: number, y1: number, role: string, z0: number?, z1: number?)
		for x = math.min(x0, x1), math.max(x0, x1) do
			for y = math.min(y0, y1), math.max(y0, y1) do
				for z = z0 or 0, z1 or z0 or 0 do
					shape.put(x, y, z, role)
				end
			end
		end
	end
	function shape.get(x: number, y: number, z: number)
		local voxel = seen[("%d:%d:%d"):format(x, y, z)]
		return voxel and voxel.role
	end
	shape.voxels = voxels
	return shape
end

-- Рукоять с обмоткой: y от y0 до -1.
local function grip(s, y0: number, wrapEvery: number?)
	for y = y0, -1 do
		local wrap = (y % (wrapEvery or 2)) == 0
		s.put(0, y, 0, wrap and "gripWrap" or "grip")
	end
end

-- Ржавые пятна: детерминированный разброс по уже нарисованному клинку.
local function rustOver(s, seed: number, chance: number, from: number, to: number, roles)
	local rng = Random.new(seed)
	for _, voxel in ipairs(s.voxels) do
		if voxel.y >= from and voxel.y <= to and roles[voxel.role] and rng:NextNumber() < chance then
			voxel.role = rng:NextNumber() < 0.5 and "rust" or "rustLight"
		end
	end
end

local shapes = {}

-- ===== Обычное =====

-- Ржавый меч: прямой клинок в три вокселя, ржавчина пятнами.
shapes.rusty_sword = function()
	local s = newShape()
	s.rect(-1, 1, -7, -7, "rust", -1, 1)
	s.put(0, -6, 0, "rust")
	grip(s, -6)
	s.rect(-3, 3, 0, 0, "guard", -1, 1)
	s.rect(-1, 1, 1, 1, "guard")
	for y = 2, 15 do
		s.put(-1, y, 0, "bladeDark")
		s.put(0, y, 0, "blade")
		s.put(1, y, 0, "bladeEdge")
	end
	s.put(0, 16, 0, "blade")
	s.put(1, 16, 0, "bladeEdge")
	s.put(0, 17, 0, "bladeEdge")
	rustOver(s, 3, 0.22, 2, 16, { blade = true, bladeDark = true })
	return s.voxels
end

-- Железный палаш: широкий длинный клинок, крестовина с медным центром,
-- кольцевое навершие.
shapes.iron_falchion = function()
	local s = newShape()
	-- Навершие-кольцо.
	s.rect(-1, 1, -9, -7, "rust", 0, 0)
	s.put(0, -8, 0, "bronzeDark")
	grip(s, -6)
	s.rect(-4, 4, 0, 0, "guard", -1, 1)
	s.rect(-1, 1, -1, 1, "rustLight", -1, 1)
	for y = 2, 18 do
		local width = y > 15 and (18 - y) or 2
		s.put(-1, y, 0, "bladeDark")
		for x = 0, width do
			s.put(x, y, 0, x == width and "bladeEdge" or "blade")
		end
	end
	s.put(0, 19, 0, "bladeEdge")
	rustOver(s, 7, 0.14, 3, 18, { blade = true, bladeDark = true })
	return s.voxels
end

-- Молот: длинная рукоять с бандажами, массивный боёк.
local function hammer(s, opts)
	for y = -7, 8 do
		local band = (y % 4 == 0)
		s.put(0, y, 0, band and (opts.bandRole or "rust") or "grip")
	end
	s.rect(-1, 1, -8, -8, opts.capRole or "rust", -1, 1)
	-- Боёк: тёмное ядро, светлые торцы, полоса посередине.
	s.rect(-4, 4, 9, 13, "iron", -1, 1)
	for _, x in ipairs({ -4, 4 }) do
		s.rect(x, x, 9, 13, "ironLight", -1, 1)
	end
	s.rect(-1, 1, 9, 13, opts.bandRole or "rust", -1, 1)
	s.rect(-4, 4, 13, 13, "bladeDark", -1, 1)
end

shapes.forge_hammer = function()
	local s = newShape()
	hammer(s, {})
	rustOver(s, 11, 0.12, 9, 13, { iron = true, ironLight = true })
	return s.voxels
end

-- ===== Редкое =====

-- Клинок стража: широкий клинок с медным узором-зигзагом, крестовина с
-- квадратным камнем, кольцевое навершие.
shapes.guard_blade = function()
	local s = newShape()
	s.rect(-1, 1, -9, -7, "rustLight", 0, 0)
	s.put(0, -8, 0, "gold")
	grip(s, -6, 3)
	s.rect(-4, 4, 0, 0, "bronze", -1, 1)
	s.put(-4, 1, 0, "bronze")
	s.put(4, 1, 0, "bronze")
	s.put(-4, -1, 0, "bronze")
	s.put(4, -1, 0, "bronze")
	s.rect(-1, 1, -1, 1, "gold", -1, 1)
	s.put(0, 0, -1, "rustLight")
	for y = 2, 17 do
		local width = y > 15 and 1 or 2
		for x = -width, width do
			local role = (x == width) and "bladeEdge" or ((x == -width) and "bladeDark" or "blade")
			s.put(x, y, 0, role)
		end
		-- Узор вдоль дола.
		if y >= 3 and y <= 14 then
			s.put((y % 4 < 2) and -1 or 0, y, 0, "rustLight")
		end
	end
	s.put(0, 18, 0, "bladeEdge")
	rustOver(s, 13, 0.08, 2, 17, { blade = true })
	return s.voxels
end

-- Молот стража: медные бандажи и ромбовидная эмблема на бойке.
shapes.guard_hammer = function()
	local s = newShape()
	hammer(s, { bandRole = "rustLight", capRole = "bronze" })
	for _, z in ipairs({ -2, 2 }) do
		s.put(0, 11, z, "gold")
		s.put(-1, 11, z, "bronze")
		s.put(1, 11, z, "bronze")
		s.put(0, 10, z, "bronze")
		s.put(0, 12, z, "bronze")
	end
	return s.voxels
end

-- ===== Эпическое =====

-- Вихревой клинок: изогнутый серп кремово-золотого клинка и спираль у гарды.
shapes.vortex_blade = function()
	local s = newShape()
	grip(s, -7, 3)
	s.rect(-1, 1, -8, -8, "bronze", -1, 1)
	s.put(0, -9, 0, "goldGlow")
	-- Спираль у основания.
	for step = 0, 22 do
		local angle = step * 0.55
		local radius = 1 + step * 0.13
		local x = math.floor(math.cos(angle) * radius + 0.5)
		local y = math.floor(math.sin(angle) * radius + 0.5) + 2
		s.put(x, y, 0, step % 3 == 0 and "goldGlow" or (step % 2 == 0 and "bronzeDark" or "bronze"))
	end
	-- Серп: дуга вокруг центра слева.
	local cx, cy = -7, 8
	for degrees = -35, 80, 4 do
		local a = math.rad(degrees)
		for r = 9, 11 do
			local x = math.floor(cx + math.cos(a) * r + 0.5)
			local y = math.floor(cy + math.sin(a) * r + 0.5)
			local role = r == 11 and "bladeEdge" or (r == 10 and "cream" or "goldGlow")
			s.put(x, y, 0, role)
		end
	end
	return s.voxels
end

-- Расколотый молот: тёмный боёк, рассечённый светящимися трещинами.
shapes.shattered_hammer = function()
	local s = newShape()
	hammer(s, { bandRole = "bronze", capRole = "bronzeDark" })
	-- Трещины на гранях бойка.
	local crack = { { -3, 13 }, { -2, 12 }, { -2, 11 }, { -1, 10 }, { 0, 10 }, { 1, 11 }, { 2, 11 }, { 3, 10 }, { 3, 9 } }
	for _, z in ipairs({ -2, 2 }) do
		for _, c in ipairs(crack) do
			s.put(c[1], c[2], z, "goldGlow")
		end
	end
	for _, c in ipairs({ { -4, 12 }, { -4, 11 }, { 4, 10 }, { 4, 11 } }) do
		s.put(c[1], c[2], 0, "goldGlow")
	end
	return s.voxels
end

-- ===== Легендарное =====

-- Ключ Привратника: меч-ключ. Бронзовый клинок с золотым каналом,
-- бородка ключа у острия, навершие — кольцо ключа.
shapes.gatekeeper_key = function()
	local s = newShape()
	-- Кольцо-навершие (бородка ключа) с сияющим центром.
	for x = -2, 2 do
		for y = -11, -7 do
			if math.abs(x) == 2 or y == -11 or y == -7 then
				s.put(x, y, 0, "gold")
			end
		end
	end
	s.put(0, -9, 0, "goldGlow")
	s.rect(-3, -3, -10, -8, "bronze")
	s.rect(3, 3, -10, -8, "bronze")
	grip(s, -6, 2)
	-- Гарда: золото с камнем.
	s.rect(-5, 5, 0, 0, "bronze", -1, 1)
	s.rect(-5, -5, 1, 2, "bronze")
	s.rect(5, 5, 1, 2, "bronze")
	s.rect(-1, 1, -1, 1, "gold", -1, 1)
	s.put(0, 0, -2, "goldGlow")
	s.put(0, 0, 2, "goldGlow")
	-- Клинок: бронза, тёмная кромка, канал из золотого света зигзагом.
	for y = 2, 19 do
		for x = -2, 2 do
			s.put(x, y, 0, math.abs(x) == 2 and "bronzeDark" or "bronze")
		end
		s.put(((y // 3) % 2 == 0) and 0 or 1, y, 0, "goldGlow")
	end
	-- Бородка ключа у острия: квадратная петля сбоку.
	for x = 3, 6 do
		for y = 15, 19 do
			if x == 6 or y == 15 or y == 19 then
				s.put(x, y, 0, "bronze")
			end
		end
	end
	s.put(5, 17, 0, "goldGlow")
	s.rect(-1, 1, 20, 20, "bronze")
	s.put(0, 21, 0, "gold")
	return s.voxels
end

-- ===== Общие типы (витрина и запасной вариант) =====

shapes.sword = shapes.rusty_sword
shapes.hammer = shapes.forge_hammer

-- Посох мага (фолбэк, пока меши посохов не залиты): древко с обмоткой у хвата,
-- бронзовые кольца, развилка и неоновый кристалл наверху.
shapes.staff = function()
	local s = newShape()
	s.put(0, -12, 0, "bronzeDark")
	for y = -11, 10 do
		local wrap = y >= -2 and y <= 1 and (y % 2 == 0)
		s.put(0, y, 0, wrap and "gripWrap" or "wood")
	end
	s.rect(-1, 1, -8, -8, "bronze", -1, 1)
	s.rect(-1, 1, 6, 6, "bronze", -1, 1)
	-- Развилка держит кристалл.
	s.put(-1, 10, 0, "bronzeDark")
	s.put(1, 10, 0, "bronzeDark")
	s.put(-2, 11, 0, "bronze")
	s.put(2, 11, 0, "bronze")
	s.put(-2, 12, 0, "bronze")
	s.put(2, 12, 0, "bronze")
	s.rect(-1, 1, 11, 13, "arcaneGlow", 0, 0)
	s.put(0, 12, -1, "arcaneGlow")
	s.put(0, 12, 1, "arcaneGlow")
	s.put(0, 14, 0, "arcaneGlow")
	return s.voxels
end

shapes.dagger = function()
	local s = newShape()
	s.put(0, -4, 0, "guard")
	grip(s, -3)
	s.rect(-2, 2, 0, 0, "guard")
	for y = 1, 8 do
		s.put(0, y, 0, "blade")
		s.put(1, y, 0, "bladeEdge")
	end
	s.put(0, 9, 0, "bladeEdge")
	return s.voxels
end

-- Тип оружия по id (если формы под id нет).
local KIND_BY_ID = {
	rusty_sword = "sword",
	iron_falchion = "sword",
	guard_blade = "sword",
	vortex_blade = "sword",
	gatekeeper_key = "sword",
	forge_hammer = "hammer",
	guard_hammer = "hammer",
	shattered_hammer = "hammer",
}

function VoxelWeaponBuilder.supportedKinds()
	local kinds = {}
	for kind in pairs(shapes) do
		table.insert(kinds, kind)
	end
	table.sort(kinds)
	return kinds
end

-- Таблица вокселей без создания объектов (для тестов).
function VoxelWeaponBuilder.voxelsFor(kind: string)
	local generator = shapes[kind]
	if not generator then
		error(("VoxelWeaponBuilder: неизвестный тип оружия '%s' (есть: %s)"):format(
			tostring(kind),
			table.concat(VoxelWeaponBuilder.supportedKinds(), ", ")
		))
	end
	return generator()
end

-- Склеить воксели одной роли в столбики вдоль Y.
local function mergeRuns(voxels)
	local columns = {}
	for _, voxel in ipairs(voxels) do
		local key = ("%d:%d:%s"):format(voxel.x, voxel.z, voxel.role)
		columns[key] = columns[key] or { x = voxel.x, z = voxel.z, role = voxel.role, ys = {} }
		table.insert(columns[key].ys, voxel.y)
	end
	local runs = {}
	for _, column in pairs(columns) do
		table.sort(column.ys)
		local start = column.ys[1]
		local previous = start
		for index = 2, #column.ys + 1 do
			local y = column.ys[index]
			if y ~= previous + 1 then
				table.insert(runs, { x = column.x, z = column.z, role = column.role, y0 = start, y1 = previous })
				start = y
			end
			previous = y
		end
	end
	return runs
end

-- Свечение редкого оружия: мягкий свет и микро-частицы вдоль клинка.
-- volume — невидимая деталь «AuraVolume» по габариту клинка:
-- эмиттеры шаблона с объёмной/поверхностной формой (Volume/Surface) сыплют частицы
-- по всему объёму клинка/бойка, остальные и свет остаются в точке BladeMid.
-- Эмиттеры с атрибутом Flare (rate 0) — микро-вспышки для клиентского WeaponPresence.
local function addRarityFx(root, bladeLength: number, rarityId: string?, color: Color3, weaponId: string?, volume: BasePart?, focusPos: Vector3?, tint: ColorSequence?)
	local mid = root:FindFirstChild("BladeMid")
	if not mid then
		mid = Instance.new("Attachment")
		mid.Name = "BladeMid"
		mid.Parent = root
	end
	mid.Position = focusPos or Vector3.new(0, bladeLength * 0.6, 0)

	local fx = ReplicatedStorage:FindFirstChild("FX")
	local auras = fx and fx:FindFirstChild("Weapon")
	local customAura = auras and weaponId and auras:FindFirstChild(weaponId) or nil
	local aura = customAura
		or (auras and auras:FindFirstChild(rarityId or ""))
		or (rarityId == "secret" and auras and auras:FindFirstChild("legendary"))
	if aura then
		for _, child in ipairs(aura:GetChildren()) do
			local clone = child:Clone()
			if clone:IsA("ParticleEmitter") then
				-- Flare — Emit-вспышка (rate 0, стреляет WeaponPresence); всё
				-- остальное включаем: в шаблоне Enabled=false, Rate — рабочие.
				clone.Enabled = clone:GetAttribute("Flare") == nil and clone.Rate > 0
				-- Перекрашиваем только общие шаблоны по редкости (когда у оружия нет
				-- собственного FX.Weapon.<id>); тёмные контрастные слои (DarkSmoke/DarkFlecks) не трогаем.
				if not customAura and tint and (
					clone.Name == "Aura"
					or clone.Name == "Motes"
					or clone.Name == "Arc"
					or clone.Name == "Haze"
					or clone.Name == "Ribbons"
					or clone.Name == "MicroSparks"
					or clone.Name == "MicroOrbs"
				) then
					clone.Color = tint
				end
				if volume and (
					clone.ShapeStyle == Enum.ParticleEmitterShapeStyle.Volume
					or clone.ShapeStyle == Enum.ParticleEmitterShapeStyle.Surface
				) then
					clone.Parent = volume
					continue
				end
			elseif clone:IsA("PointLight") and not customAura then
				clone.Color = color
			end
			clone.Parent = mid
		end
		return
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = (rarityId == "legendary" or rarityId == "secret") and 0.35 or 0.25
	light.Range = 4.5
	light.Parent = mid
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "RaritySparks"
	sparks.Rate = (rarityId == "legendary" or rarityId == "secret") and 10 or 6
	sparks.Lifetime = NumberRange.new(0.6, 1.1)
	sparks.Speed = NumberRange.new(0.2, 0.7)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.LightEmission = 0.85
	sparks.Color = ColorSequence.new(color)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(1, 0) })
	sparks.Shape = Enum.ParticleEmitterShape.Box
	sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	sparks.Parent = volume or mid
end

local function meshFolder()
	return ReplicatedStorage:FindFirstChild(VoxelWeaponBuilder.MeshFolderName)
end

-- Есть ли готовые меши у оружия (все детали на месте).
function VoxelWeaponBuilder.hasMeshes(shapeId: string): boolean
	local data = MeshData and MeshData[shapeId]
	local folder = meshFolder()
	if not data or not folder then
		return false
	end
	for _, object in ipairs(data.objects) do
		local source = folder:FindFirstChild(object.name)
		if not source or not source:IsA("MeshPart") then
			return false
		end
	end
	return true
end

-- Модель из мешей. Та же структура, что у воксельной: Root + Grip/BladeBase/
-- BladeTip, атрибуты BladeLength/Extent/CenterY — следы удара и иконки
-- работают без правок.
local function buildFromMeshes(kind: string, shapeId: string, opts)
	local data = MeshData[shapeId]
	local folder = meshFolder()
	local base = opts.baseCFrame or CFrame.new()
	local anchored = opts.anchored == true

	local model = Instance.new("Model")
	model.Name = opts.name or (shapeId .. "_Mesh")
	if opts.parent then
		model.Parent = opts.parent
	end

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Massless = true
	root.CFrame = base
	root.Parent = model

	local gripAttachment = Instance.new("Attachment")
	gripAttachment.Name = "Grip"
	gripAttachment.Parent = root
	local baseAttachment = Instance.new("Attachment")
	baseAttachment.Name = "BladeBase"
	baseAttachment.Position = Vector3.new(0, data.bladeBase, 0)
	baseAttachment.Parent = root
	local tipAttachment = Instance.new("Attachment")
	tipAttachment.Name = "BladeTip"
	-- Посохи мага: BladeTip — в центре светящегося камня навершия (focus), оттуда летят снаряды.
	tipAttachment.Position = data.focus or Vector3.new(0, data.bladeTip, 0)
	tipAttachment.Parent = root
	model:SetAttribute("BladeLength", data.bladeTip)
	model:SetAttribute("Extent", data.bladeTip - data.bottom)
	model:SetAttribute("CenterY", (data.bladeTip + data.bottom) / 2)

	local weldTarget = opts.weldTarget or root
	local glowColor = nil
	local glowIndex = 0
	-- Поправка импорта: если Import 3D развернул меши, у папки WeaponMeshes
	-- ставится атрибут ImportYaw = 180 (см. README пакета оружия).
	local importFix = CFrame.Angles(0, math.rad(folder:GetAttribute("ImportYaw") or 0), 0)
	for _, object in ipairs(data.objects) do
		local source = folder:FindFirstChild(object.name)
		local part = source:Clone()
		part.Name = object.role == "glow" and "Glow" or "Mesh"
		-- Имя исходного меша: по нему клиент находит части с особым поведением
		-- (ступени «Незавершённой отливки» G2–G4_unfinished_blade и т. п.).
		part:SetAttribute("MeshName", object.name)
		part.Size = object.size
		part.CFrame = base * CFrame.new(object.offset) * importFix
		part.Anchored = anchored
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		if object.role == "glow" then
			glowIndex += 1
			part.Material = Enum.Material.Neon
			part.Color = object.glow or Color3.fromRGB(255, 181, 54)
			part.Transparency = 0.14
			part.CastShadow = false
			part:SetAttribute("BaseGlowColor", part.Color)
			part:SetAttribute("BaseTransparency", part.Transparency)
			part:SetAttribute("GlowIndex", glowIndex)
			glowColor = glowColor or part.Color
		else
			part.CastShadow = opts.castShadow == true
		end
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("JointInstance") or child:IsA("WeldConstraint") then
				child:Destroy()
			end
		end
		part.Parent = model
		if not anchored then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = weldTarget
			weld.Part1 = part
			weld.Parent = part
		end
	end

	local rarityId = opts.rarityId or data.rarity
	local hasTierAura = rarityId == "epic" or rarityId == "legendary" or rarityId == "secret"
	if hasTierAura and not opts.noFx then
		local colors = opts.colors or VoxelWeaponBuilder.DefaultColors
		local auraSpec = data.aura
		if not auraSpec and data.bladeBase and data.bladeTip then
			-- Этажи 1–2: в WeaponMeshData/Floor2 поле aura не генерировалось — вычисляем
			-- габарит рабочей части клинка/бойка, чтобы частицы распределялись по форме.
			local mainObj = data.objects and data.objects[1]
			local sx = mainObj and mainObj.size.X or 1.4
			local sz = mainObj and mainObj.size.Z or 0.5
			local ox = mainObj and mainObj.offset.X or 0
			local oz = mainObj and mainObj.offset.Z or 0
			local y0 = data.bladeBase
			local y1 = data.bladeTip
			auraSpec = {
				offset = Vector3.new(ox, (y0 + y1) * 0.5, oz),
				size = Vector3.new(sx * 0.85, math.max(y1 - y0, 0.8), sz * 0.85),
			}
		end
		local volume = nil
		if auraSpec then
			-- Объём ауры: невидимая деталь по клинку, сварена как и меши.
			volume = Instance.new("Part")
			volume.Name = "AuraVolume"
			volume.Size = Vector3.new(
				math.max(auraSpec.size.X, 0.25),
				math.max(auraSpec.size.Y, 0.25),
				math.max(auraSpec.size.Z, 0.25)
			)
			volume.CFrame = base * CFrame.new(auraSpec.offset)
			volume.Transparency = 1
			volume.Anchored = anchored
			volume.CanCollide = false
			volume.CanQuery = false
			volume.CanTouch = false
			volume.CastShadow = false
			volume.Massless = true
			volume.Parent = model
			if not anchored then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = weldTarget
				weld.Part1 = volume
				weld.Parent = volume
			end
		end
		local focusPos = data.focus or (auraSpec and auraSpec.offset)
		-- перекраска ауры под цвет модели: тёмный край → основной → светлый блик
		local tint = nil
		if glowColor then
			tint = ColorSequence.new({
				ColorSequenceKeypoint.new(0, glowColor:Lerp(Color3.new(0, 0, 0), 0.45)),
				ColorSequenceKeypoint.new(0.55, glowColor),
				ColorSequenceKeypoint.new(1, glowColor:Lerp(Color3.new(1, 1, 1), 0.35)),
			})
		end
		addRarityFx(root, data.bladeTip, rarityId, glowColor or colors.goldGlow, opts.weaponId or shapeId, volume, focusPos, tint)
		model:SetAttribute("AuraRarity", rarityId)
		if glowColor then
			model:SetAttribute("AuraColor", glowColor)
		end
	end

	model.PrimaryPart = root
	model:SetAttribute("WeaponId", opts.weaponId or shapeId)
	model:SetAttribute("WeaponKind", kind)
	model:SetAttribute("WeaponShape", shapeId)
	model:SetAttribute("WeaponMesh", true)
	model:SetAttribute("PartCount", #data.objects)
	return model
end

-- opts: name, voxelSize, colors, baseCFrame, parent, weldTarget,
--       weaponId (форма под конкретное оружие), anchored (для витрины и
--       ViewportFrame: всё заанкерено, без сварки), rarityId (свечение).
function VoxelWeaponBuilder.build(kind: string, opts)
	opts = opts or {}

	local shapeId = (opts.weaponId and shapes[opts.weaponId]) and opts.weaponId or kind
	-- Объёмные меши, если залиты (opts.voxels = true — принудительно воксели).
	local meshId = opts.weaponId or kind
	if not opts.voxels and VoxelWeaponBuilder.hasMeshes(meshId) then
		local ok, model = pcall(buildFromMeshes, kind, meshId, opts)
		if ok and model then
			return model
		end
		warn("[VoxelWeaponBuilder] меши " .. tostring(meshId) .. ": " .. tostring(model))
	end
	local voxels = VoxelWeaponBuilder.voxelsFor(shapeId)
	local size = opts.voxelSize or VoxelWeaponBuilder.VoxelSize
	local colors = opts.colors or VoxelWeaponBuilder.DefaultColors
	-- Синхронная материальная палитра фолбэка. Другие коллекции и Glow не трогаем.
	if not opts.colors then
		local floor2 = {
			garden_machete = true, reed_saber = true, mud_mallet = true, thorn_blade = true,
			root_hammer = true, reaper_blade = true, tidal_hammer = true, gardener_shears = true,
		}
		local materialColors = KIND_BY_ID[meshId] and Palette.WeaponFloor1
			or (floor2[meshId] and Palette.WeaponFloor2)
		if materialColors then
			colors = table.clone(colors)
			for role, color in pairs(materialColors) do
				colors[role] = color
			end
		end
	end
	local base = opts.baseCFrame or CFrame.new()
	local anchored = opts.anchored == true

	local model = Instance.new("Model")
	model.Name = opts.name or (shapeId .. "_Voxel")

	-- Модель попадает в мир ДО создания вокселей: иначе сварка
	-- инициализируется вне DataModel и части разваливаются.
	if opts.parent then
		model.Parent = opts.parent
	end

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(size, size, size)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Massless = true
	root.CFrame = base
	root.Parent = model

	local gripAttachment = Instance.new("Attachment")
	gripAttachment.Name = "Grip"
	gripAttachment.Parent = root

	-- Концы клинка для следа удара.
	local topY, bottomY = 1, 0
	for _, voxel in ipairs(voxels) do
		topY = math.max(topY, voxel.y)
		bottomY = math.min(bottomY, voxel.y)
	end
	local baseAttachment = Instance.new("Attachment")
	baseAttachment.Name = "BladeBase"
	baseAttachment.Position = Vector3.new(0, size * 2, 0)
	baseAttachment.Parent = root
	local tipAttachment = Instance.new("Attachment")
	tipAttachment.Name = "BladeTip"
	tipAttachment.Position = Vector3.new(0, (topY + 0.5) * size, 0)
	tipAttachment.Parent = root
	model:SetAttribute("BladeLength", (topY + 0.5) * size)
	model:SetAttribute("Extent", (topY - bottomY + 1) * size)
	model:SetAttribute("CenterY", (topY + bottomY) / 2 * size)

	local weldTarget = opts.weldTarget or root
	local glowParts = 0
	local runs = mergeRuns(voxels)
	for _, run in ipairs(runs) do
		local length = run.y1 - run.y0 + 1
		local part = Instance.new("Part")
		part.Name = "Voxel"
		part.Size = Vector3.new(size, size * length, size)
		part.CFrame = base * CFrame.new(run.x * size, (run.y0 + run.y1) / 2 * size, run.z * size)
		part.Color = colors[run.role] or Palette.UI.danger
		local glow = string.sub(run.role, -4) == "Glow"
		part.Material = glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
		part.Anchored = anchored
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		if glow then
			glowParts += 1
		end

		if not anchored then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = weldTarget
			weld.Part1 = part
			weld.Parent = part
		end
	end

	-- Свечение редкого оружия: мягкий свет и искры вдоль клинка.
	local rarityId = opts.rarityId
	if (glowParts > 0 or rarityId == "epic" or rarityId == "legendary") and not opts.noFx then
		addRarityFx(root, topY * size, rarityId, (shapeId == "staff" and colors.arcaneGlow) or colors.goldGlow)
	end

	model.PrimaryPart = root
	model:SetAttribute("WeaponKind", kind)
	model:SetAttribute("WeaponShape", shapeId)
	model:SetAttribute("VoxelSize", size)
	model:SetAttribute("VoxelCount", #voxels)
	model:SetAttribute("PartCount", #runs)

	return model
end

-- Собрать полный стартовый набор (меч, кинжал, молот) в указанную папку.
function VoxelWeaponBuilder.buildSet(parent, opts)
	opts = opts or {}
	local folder = parent:FindFirstChild("Weapons")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Weapons"
		folder.Parent = parent
	end

	local built = {}
	for _, kind in ipairs({ "sword", "dagger", "hammer" }) do
		local name = kind:sub(1, 1):upper() .. kind:sub(2)
		local existing = folder:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
		built[kind] = VoxelWeaponBuilder.build(kind, {
			name = name,
			voxelSize = opts.voxelSize,
			parent = folder,
		})
	end

	return folder, built
end

VoxelWeaponBuilder.KindById = KIND_BY_ID

return VoxelWeaponBuilder


