--!nonstrict
-- FloorProps (сервер)
-- Воксельный реквизит этажа 1 по концептам из assets/1 этаж: колонны со
-- знамёнами, факелы и жаровни, мёртвые деревья, брошенные доспехи, ящики,
-- бочки, лавки, цепи, стойки с оружием, наковальня, шатёр, фонари.
--
-- Правила:
--  * один воксель архитектуры = 1 стад, детали мельче — кратны 0.25;
--  * цвета только из Palette.Env / Palette.Floors[1]: «пиксельность» даёт
--    разброс тона соседних кубиков, а не текстуры;
--  * всё анкерное и без коллизий, кроме того, что должно останавливать
--    игрока (колонны, ящики у стен);
--  * анимацию (покачивание кубиков, мерцание огня) ведёт клиент по тегам
--    KlinokFloat / KlinokFlame / KlinokRise — сервер ничего не крутит.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Config.Palette)

local Props = {}

local Env = Palette.Env
local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

Props.Tags = {
	float = "KlinokFloat",
	flame = "KlinokFlame",
	rise = "KlinokRise",
	hover = "KlinokHover",
}

-- ===== Кирпичик =====

-- opts: collide, query, shadow, transparency, shape
function Props.part(parent, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, opts)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	local collide = opts and opts.collide or false
	part.CanCollide = collide
	part.CanQuery = (opts and opts.query ~= nil) and opts.query or collide
	part.CanTouch = false
	part.CastShadow = not (opts and opts.shadow == false)
	if opts and opts.transparency then
		part.Transparency = opts.transparency
	end
	if opts and opts.shape then
		part.Shape = opts.shape
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Тон соседнего кубика: чуть темнее или светлее основы.
function Props.vary(color: Color3, rng, amount: number?): Color3
	local k = (rng:NextNumber() - 0.5) * 2 * (amount or 0.08)
	if k >= 0 then
		return color:Lerp(Env.bone, k)
	end
	return color:Lerp(Env.void, -k)
end

-- Выбор из списка с весами { {value, weight}, ... }.
function Props.pick(rng, list)
	local total = 0
	for _, entry in ipairs(list) do
		total += entry[2]
	end
	local roll = rng:NextNumber() * total
	for _, entry in ipairs(list) do
		roll -= entry[2]
		if roll <= 0 then
			return entry[1]
		end
	end
	return list[#list][1]
end

local function tag(instance, name: string)
	CollectionService:AddTag(instance, name)
	return instance
end

-- ===== Огонь =====

-- Воксельное пламя: ядро и языки из неоновых кубиков, искры и тёплый свет.
-- Клиент дёргает кубики по тегу KlinokFlame, поэтому огонь «живой».
function Props.flame(parent, position: Vector3, scale: number?, opts)
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "Flame"
	local cubes = {
		{ V3(0, 0.35, 0), 0.9, Env.flame },
		{ V3(0.32, 0.3, 0.1), 0.55, Env.flame },
		{ V3(-0.3, 0.28, -0.12), 0.55, Env.flame },
		{ V3(0.05, 0.85, 0.05), 0.6, Env.ember },
		{ V3(-0.1, 0.55, 0.2), 0.45, Env.flameCore },
		{ V3(0.12, 1.3, -0.05), 0.35, Env.ember },
		{ V3(0, 1.7, 0.1), 0.22, Env.flameCore },
	}
	for index, cube in ipairs(cubes) do
		local part = Props.part(model, "FlameVoxel", V3(cube[2], cube[2], cube[2]) * s, CF(position + cube[1] * s), cube[3], Enum.Material.Neon, { shadow = false })
		part.Transparency = index <= 3 and 0.05 or 0.15
		part:SetAttribute("Seed", index * 1.7 + position.X * 0.13 + position.Z * 0.07)
		tag(part, Props.Tags.flame)
	end

	local core = model:FindFirstChild("FlameVoxel")
	local light = Instance.new("PointLight")
	light.Color = Env.flame
	-- Днём огонь не должен пересвечивать сцену: свет мягкий, ярко горят
	-- только сами неоновые кубики.
	light.Brightness = ((opts and opts.brightness) or 2.2) * 0.55
	light.Range = (opts and opts.range) or 18 * math.sqrt(s)
	light.Shadows = opts and opts.shadows or false
	light.Parent = core

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Embers"
	sparks.Rate = 6 * s
	sparks.Lifetime = NumberRange.new(0.8, 1.6)
	sparks.Speed = NumberRange.new(1.5, 3.5)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Acceleration = V3(0, 2.5, 0)
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(Env.flameCore, Env.flame)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18 * s), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	sparks.Shape = Enum.ParticleEmitterShape.Box
	sparks.Parent = core

	model.Parent = parent
	return model, light
end

-- Факел на стене: кронштейн, чаша и огонь. facing — направление «в комнату».
function Props.torch(parent, position: Vector3, facing: Vector3)
	local frame = CFrame.lookAt(position, position + facing)
	Props.part(parent, "TorchPlate", V3(1.3, 2.0, 0.35), frame * CF(0, -0.5, 0.15), Env.iron, Enum.Material.Metal)
	Props.part(parent, "TorchArm", V3(0.5, 0.5, 1.6), frame * CF(0, -0.8, -0.7), Env.iron, Enum.Material.Metal)
	Props.part(parent, "TorchCup", V3(1.3, 0.7, 1.3), frame * CF(0, -0.55, -1.45), Env.ironLight, Enum.Material.Metal)
	return Props.flame(parent, (frame * CF(0, -0.2, -1.45)).Position, 1.15, { range = 24 })
end

-- Жаровня на каменной тумбе (арена, двор).
function Props.brazier(parent, position: Vector3, rng, height: number?)
	local h = height or 3
	local base = Props.part(parent, "BrazierBase", V3(2.6, 0.8, 2.6), CF(position + V3(0, 0.4, 0)), Env.stoneDark, nil, { collide = true })
	Props.part(parent, "BrazierPost", V3(1.8, h - 1.2, 1.8), CF(position + V3(0, 0.8 + (h - 1.2) / 2, 0)), Props.vary(Env.stone, rng), nil, { collide = true })
	Props.part(parent, "BrazierBowl", V3(2.8, 0.6, 2.8), CF(position + V3(0, h - 0.1, 0)), Env.iron, Enum.Material.Metal)
	Props.part(parent, "BrazierRim", V3(3.1, 0.3, 3.1), CF(position + V3(0, h + 0.25, 0)), Env.ironLight, Enum.Material.Metal)
	Props.part(parent, "BrazierCoal", V3(2.2, 0.3, 2.2), CF(position + V3(0, h + 0.3, 0)), Env.rustDark, Enum.Material.Neon)
	return Props.flame(parent, position + V3(0, h + 0.4, 0), 1.6, { range = 30, brightness = 2.6 })
end

-- ===== Знамя =====

-- Рваное знамя с рунным знаком. cf — точка крепления (верх), смотрит в комнату.
function Props.banner(parent, cf: CFrame, height: number, color: Color3, rng)
	local width = 2.6
	Props.part(parent, "BannerRod", V3(width + 0.8, 0.3, 0.3), cf * CF(0, 0, -0.1), Env.iron, Enum.Material.Metal)
	-- Полотно полосами: нижний край рваный.
	local strips = 5
	for index = 1, strips do
		local x = -width / 2 + (index - 0.5) * (width / strips)
		local tear = (index == 1 or index == strips) and 0.9 or rng:NextNumber() * 0.9
		local length = height - tear
		Props.part(parent, "BannerCloth", V3(width / strips + 0.02, length, 0.15), cf * CF(x, -0.2 - length / 2, -0.2), Props.vary(color, rng, 0.05), Enum.Material.Fabric, { shadow = false })
	end
	-- Кайма и знак: меч-трезубец стражи (концепт арены).
	local trim = Env.gold
	Props.part(parent, "BannerTrim", V3(width, 0.25, 0.18), cf * CF(0, -0.45, -0.25), trim, Enum.Material.SmoothPlastic, { shadow = false })
	local mid = -height * 0.45
	Props.part(parent, "BannerSigil", V3(0.25, height * 0.45, 0.18), cf * CF(0, mid, -0.3), trim, Enum.Material.SmoothPlastic, { shadow = false })
	Props.part(parent, "BannerSigil", V3(1.2, 0.25, 0.18), cf * CF(0, mid + height * 0.12, -0.3), trim, Enum.Material.SmoothPlastic, { shadow = false })
	for _, sx in ipairs({ -1, 1 }) do
		Props.part(parent, "BannerSigil", V3(0.25, 0.6, 0.18), cf * CF(sx * 0.5, mid + height * 0.12 + 0.35, -0.3), trim, Enum.Material.SmoothPlastic, { shadow = false })
	end
end

-- ===== Колонна =====

-- Колонна 3×3 из кубиков: ступенчатые база и капитель, знамя на грани.
function Props.pillar(parent, x: number, z: number, height: number, rng, opts)
	local size = (opts and opts.size) or 3
	local base = CF(x, 0, z)
	Props.part(parent, "PillarFoot", V3(size + 1.6, 1, size + 1.6), base * CF(0, 0.5, 0), Env.stoneDark)
	Props.part(parent, "PillarFoot", V3(size + 0.8, 1, size + 0.8), base * CF(0, 1.5, 0), Props.vary(Env.stoneLight, rng))
	-- Ствол: блоки по 2 стада с разбросом тона и сдвигом.
	local y = 2
	while y < height - 2 do
		local h = math.min(2, height - 2 - y)
		local jitter = (rng:NextNumber() - 0.5) * 0.12
		local color = Props.pick(rng, { { Env.stone, 4 }, { Env.stoneWarm, 2 }, { Env.stoneLight, 2 }, { Env.stoneDark, 1 } })
		Props.part(parent, "PillarStone", V3(size + jitter, h, size + jitter), base * CF(0, y + h / 2, 0) * ANG(0, (rng:NextNumber() - 0.5) * 0.04, 0), Props.vary(color, rng))
		y += h
	end
	Props.part(parent, "PillarCap", V3(size + 0.8, 1, size + 0.8), base * CF(0, height - 1.5, 0), Props.vary(Env.stoneLight, rng))
	Props.part(parent, "PillarCap", V3(size + 1.6, 1, size + 1.6), base * CF(0, height - 0.5, 0), Env.sandLight)
	Props.part(parent, "PillarTop", V3(size - 0.6, 0.8, size - 0.6), base * CF(0, height + 0.4, 0), Env.stoneLight)
	-- Невидимое тело для столкновений и упора камеры.
	local body = Props.part(parent, "Pillar", V3(size, height, size), base * CF(0, height / 2, 0), Env.stone, nil, { collide = true, transparency = 1, shadow = false })
	if opts and opts.banner then
		local face = opts.banner -- направление грани со знаменем
		local mount = CFrame.lookAt(V3(x, height - 3, z) + face * (size / 2 + 0.1), V3(x, height - 3, z) + face * 10)
		Props.banner(parent, mount, math.min(height * 0.45, 9), Env.cloth, rng)
	end
	return body
end

-- ===== Природа и обломки =====

-- Мёртвое дерево из кубиков: ствол с изгибом и голые ветви.
function Props.deadTree(parent, position: Vector3, rng, scale: number?)
	local s = scale or 1
	local trunk = Env.woodDark:Lerp(Env.stoneDark, 0.25)
	local x, z = position.X, position.Z
	local y = 0
	local dx, dz = 0, 0
	local heightTotal = math.floor(10 * s)

	-- Ветка — непрерывная ломаная из кубиков: шаг равен размеру кубика,
	-- иначе получаются «щепки в воздухе».
	local function branch(bx: number, by: number, bz: number, angle: number, length: number, thickness: number, depth: number)
		local rise = 0.55 + rng:NextNumber() * 0.35
		for step = 1, length do
			local bw = math.max(thickness - step * 0.05, 0.28)
			local direction = V3(math.cos(angle), rise, math.sin(angle)).Unit
			bx += direction.X * bw * 0.85
			by += direction.Y * bw * 0.85
			bz += direction.Z * bw * 0.85
			Props.part(parent, "TreeBranch", V3(bw, bw, bw), CF(bx, by, bz), Props.vary(trunk, rng, 0.05), Enum.Material.Wood, { shadow = false })
			angle += (rng:NextNumber() - 0.5) * 0.25
			if depth < 1 and step == math.floor(length * 0.6) and rng:NextNumber() < 0.6 then
				branch(bx, by, bz, angle + (rng:NextNumber() < 0.5 and 0.9 or -0.9), math.floor(length * 0.6), bw, depth + 1)
			end
		end
	end

	for index = 0, heightTotal do
		local w = math.max(1.0 * s - index * 0.05 * s, 0.45)
		Props.part(parent, "TreeTrunk", V3(w, 0.8, w), CF(x + dx, y + 0.4, z + dz), Props.vary(trunk, rng, 0.05), Enum.Material.Wood)
		y += 0.8
		if index > 3 and rng:NextNumber() < 0.4 then
			dx += (rng:NextNumber() - 0.5) * 0.5
			dz += (rng:NextNumber() - 0.5) * 0.5
		end
		if index >= 5 and index % 4 == 1 then
			branch(x + dx, y, z + dz, rng:NextNumber() * math.pi * 2, math.floor((5 + rng:NextNumber() * 3) * s), 0.75 * s, 0)
		end
	end
	-- Вершина: тонкий побег вверх.
	branch(x + dx, y, z + dz, rng:NextNumber() * math.pi * 2, math.floor(4 * s), 0.55 * s, 1)
	-- Корни у основания.
	for index = 1, 4 do
		local angle = index * math.pi / 2 + rng:NextNumber() * 0.4
		Props.part(parent, "TreeRoot", V3(1.6 * s, 0.6, 0.7 * s), CF(x + math.cos(angle) * 0.9 * s, 0.3, z + math.sin(angle) * 0.9 * s) * ANG(0, -angle, 0), trunk, Enum.Material.Wood)
	end
end

-- Пучок сухой травы.
function Props.grass(parent, position: Vector3, rng)
	for _ = 1, 3 + rng:NextInteger(0, 2) do
		local h = 0.5 + rng:NextNumber() * 0.9
		local color = rng:NextNumber() < 0.5 and Env.grass or Env.grassDry
		Props.part(parent, "Grass", V3(0.18, h, 0.18),
			CF(position.X + (rng:NextNumber() - 0.5) * 0.9, h / 2, position.Z + (rng:NextNumber() - 0.5) * 0.9)
				* ANG((rng:NextNumber() - 0.5) * 0.5, 0, (rng:NextNumber() - 0.5) * 0.5),
			color, Enum.Material.SmoothPlastic, { shadow = false })
	end
end

-- Обломки кладки на полу.
function Props.rubble(parent, position: Vector3, rng, count: number?)
	for _ = 1, count or 4 do
		local size = 0.4 + rng:NextNumber() * 0.9
		Props.part(parent, "Rubble", V3(size, size * 0.8, size),
			CF(position.X + (rng:NextNumber() - 0.5) * 2.6, size * 0.35, position.Z + (rng:NextNumber() - 0.5) * 2.6)
				* ANG(0, rng:NextNumber() * 6, (rng:NextNumber() - 0.5) * 0.3),
			Props.vary(Props.pick(rng, { { Env.stone, 3 }, { Env.stoneLight, 2 }, { Env.stoneDark, 1 } }), rng), nil, { shadow = false })
	end
end

-- Пятно ржавчины/крови на плитах: несколько плоских кубиков разного тона.
function Props.stain(parent, position: Vector3, rng, color: Color3?)
	local base = color or Env.rust
	for _ = 1, 3 + rng:NextInteger(0, 3) do
		local w = 0.8 + rng:NextNumber() * 1.8
		local d = 0.8 + rng:NextNumber() * 1.8
		local part = Props.part(parent, "Stain", V3(w, 0.04, d),
			CF(position.X + (rng:NextNumber() - 0.5) * 3, 0.17, position.Z + (rng:NextNumber() - 0.5) * 3),
			Props.vary(base, rng, 0.1), Enum.Material.SmoothPlastic, { shadow = false })
		part.Transparency = 0.25 + rng:NextNumber() * 0.3
	end
end

-- ===== Брошенное снаряжение =====

-- Груда доспеха: шлем, нагрудник, щит с крестом, меч рядом.
function Props.armorPile(parent, position: Vector3, rng)
	local frame = CF(position) * ANG(0, rng:NextNumber() * math.pi * 2, 0)
	local metal = Env.ironLight
	Props.part(parent, "ArmorChest", V3(1.8, 1.0, 1.3), frame * CF(0, 0.5, 0) * ANG(0, 0, 0.15), Props.vary(metal, rng), Enum.Material.Metal)
	Props.part(parent, "ArmorRust", V3(1.0, 0.1, 0.8), frame * CF(0.2, 1.02, 0.1), Env.rust, Enum.Material.SmoothPlastic, { shadow = false })
	Props.part(parent, "ArmorHelm", V3(1.1, 1.0, 1.1), frame * CF(1.5, 0.5, 0.6) * ANG(0, 0.6, 0.25), Props.vary(metal, rng), Enum.Material.Metal)
	Props.part(parent, "ArmorVisor", V3(0.8, 0.18, 0.1), frame * CF(1.5, 0.6, 0.6) * ANG(0, 0.6, 0.25) * CF(0, 0, -0.56), Env.void, Enum.Material.SmoothPlastic, { shadow = false })
	-- Щит с крестом (концепт: щиты с оранжевым крестом).
	local shield = frame * CF(-1.4, 0.15, -0.4) * ANG(-math.pi / 2 + 0.08, 0.4, 0)
	Props.part(parent, "ShieldBoard", V3(1.8, 2.3, 0.25), shield, Env.woodDark, Enum.Material.Wood)
	Props.part(parent, "ShieldRim", V3(2.0, 2.5, 0.15), shield * CF(0, 0, 0.12), Env.iron, Enum.Material.Metal)
	Props.part(parent, "ShieldCross", V3(0.3, 1.6, 0.1), shield * CF(0, 0, -0.17), Env.gold, Enum.Material.SmoothPlastic, { shadow = false })
	Props.part(parent, "ShieldCross", V3(1.1, 0.3, 0.1), shield * CF(0, 0.25, -0.17), Env.gold, Enum.Material.SmoothPlastic, { shadow = false })
	Props.fallenSword(parent, (frame * CF(0.4, 0, -1.8)).Position, rng)
end

-- Меч, лежащий на полу.
function Props.fallenSword(parent, position: Vector3, rng)
	local frame = CF(position.X, 0.18, position.Z) * ANG(0, rng:NextNumber() * math.pi * 2, 0)
	Props.part(parent, "SwordBlade", V3(0.35, 0.18, 3.2), frame * CF(0, 0, -1.2), Env.ironLight:Lerp(Env.bone, 0.3), Enum.Material.Metal, { shadow = false })
	Props.part(parent, "SwordRust", V3(0.36, 0.05, 1.0), frame * CF(0, 0.08, -0.6), Env.rust, Enum.Material.SmoothPlastic, { shadow = false })
	Props.part(parent, "SwordGuard", V3(1.3, 0.25, 0.3), frame * CF(0, 0, 0.5), Env.iron, Enum.Material.Metal, { shadow = false })
	Props.part(parent, "SwordGrip", V3(0.25, 0.22, 0.9), frame * CF(0, 0, 1.1), Env.woodDark, Enum.Material.Wood, { shadow = false })
end

-- ===== Деревянное =====

function Props.crate(parent, position: Vector3, rng, size: number?)
	local s = size or (1.8 + rng:NextNumber() * 0.8)
	local frame = CF(position.X, position.Y + s / 2, position.Z) * ANG(0, rng:NextNumber() * 0.5, 0)
	Props.part(parent, "Crate", V3(s, s, s), frame, Props.vary(Env.wood, rng), Enum.Material.Wood, { collide = true })
	for _, sy in ipairs({ -1, 1 }) do
		Props.part(parent, "CrateBand", V3(s + 0.1, 0.25, s + 0.1), frame * CF(0, sy * s * 0.38, 0), Env.woodDark, Enum.Material.Wood, { shadow = false })
	end
	Props.part(parent, "CrateBrace", V3(s + 0.08, 0.25, s * 1.3), frame * ANG(math.rad(45), 0, 0) * CF(0, 0, 0), Env.woodDark, Enum.Material.Wood, { shadow = false })
	return s
end

function Props.barrel(parent, position: Vector3, rng)
	local frame = CF(position.X, 1.2, position.Z) * ANG(0, rng:NextNumber() * 3, 0)
	Props.part(parent, "Barrel", V3(2.4, 1.7, 1.7), frame * ANG(0, 0, math.rad(90)), Props.vary(Env.wood, rng), Enum.Material.Wood, { collide = true, shape = Enum.PartType.Cylinder })
	for _, sy in ipairs({ -0.75, 0, 0.75 }) do
		Props.part(parent, "BarrelHoop", V3(0.22, 1.82, 1.82), frame * CF(0, sy, 0) * ANG(0, 0, math.rad(90)), Env.iron, Enum.Material.Metal, { shape = Enum.PartType.Cylinder, shadow = false })
	end
	Props.part(parent, "BarrelLid", V3(0.1, 1.5, 1.5), frame * CF(0, 1.2, 0) * ANG(0, 0, math.rad(90)), Env.woodLight, Enum.Material.Wood, { shape = Enum.PartType.Cylinder, shadow = false })
end

function Props.bench(parent, cf: CFrame, rng)
	local seat = cf * CF(0, 1.1, 0)
	Props.part(parent, "BenchSeat", V3(5.5, 0.45, 1.5), seat, Props.vary(Env.woodLight, rng), Enum.Material.Wood, { collide = true })
	Props.part(parent, "BenchPlank", V3(5.5, 0.06, 0.08), seat * CF(0, 0.24, 0), Env.woodDark, Enum.Material.Wood, { shadow = false })
	for _, sx in ipairs({ -2.2, 2.2 }) do
		Props.part(parent, "BenchLeg", V3(0.5, 0.9, 1.3), cf * CF(sx, 0.45, 0), Env.woodDark, Enum.Material.Wood)
	end
end

-- Столб с фонарём (концепт костра).
function Props.lanternPost(parent, position: Vector3, facing: Vector3, rng)
	local frame = CFrame.lookAt(position, position + facing)
	Props.part(parent, "PostFoot", V3(1.2, 0.6, 1.2), frame * CF(0, 0.3, 0), Env.stoneDark)
	Props.part(parent, "Post", V3(0.6, 7, 0.6), frame * CF(0, 3.5, 0), Props.vary(Env.wood, rng), Enum.Material.Wood)
	Props.part(parent, "PostArm", V3(0.45, 0.45, 2.2), frame * CF(0, 6.6, -0.9), Env.wood, Enum.Material.Wood)
	Props.part(parent, "LanternCap", V3(0.9, 0.3, 0.9), frame * CF(0, 6.0, -1.7), Env.iron, Enum.Material.Metal)
	local body = Props.part(parent, "LanternBody", V3(0.7, 0.8, 0.7), frame * CF(0, 5.45, -1.7), Env.ember, Enum.Material.Neon, { shadow = false })
	Props.part(parent, "LanternBase", V3(0.9, 0.2, 0.9), frame * CF(0, 4.95, -1.7), Env.iron, Enum.Material.Metal)
	local glow = Instance.new("PointLight")
	glow.Color = Env.ember
	glow.Brightness = 1.6
	glow.Range = 16
	glow.Parent = body
end

-- Стойка с оружием у стены (оружейная).
function Props.weaponRack(parent, cf: CFrame, rng)
	Props.part(parent, "RackFrame", V3(5, 0.4, 0.6), cf * CF(0, 3.6, 0), Env.wood, Enum.Material.Wood)
	Props.part(parent, "RackFrame", V3(5, 0.4, 0.6), cf * CF(0, 0.6, 0), Env.wood, Enum.Material.Wood)
	for _, sx in ipairs({ -2.3, 2.3 }) do
		Props.part(parent, "RackPost", V3(0.45, 4.2, 0.6), cf * CF(sx, 2.1, 0), Env.woodDark, Enum.Material.Wood)
	end
	for index = -1, 1 do
		local tilt = (rng:NextNumber() - 0.5) * 0.15
		local blade = cf * CF(index * 1.4, 2.4, -0.4) * ANG(0, 0, tilt)
		Props.part(parent, "RackBlade", V3(0.35, 3.2, 0.12), blade * CF(0, 0.4, 0), Env.ironLight:Lerp(Env.bone, 0.25), Enum.Material.Metal, { shadow = false })
		Props.part(parent, "RackGuard", V3(1.0, 0.2, 0.25), blade * CF(0, -1.25, 0), Env.iron, Enum.Material.Metal, { shadow = false })
		Props.part(parent, "RackGrip", V3(0.22, 0.8, 0.22), blade * CF(0, -1.75, 0), Env.woodDark, Enum.Material.Wood, { shadow = false })
	end
end

function Props.anvil(parent, position: Vector3, rng)
	local frame = CF(position) * ANG(0, rng:NextNumber() * 3, 0)
	Props.part(parent, "AnvilStump", V3(1.8, 1.4, 1.8), frame * CF(0, 0.7, 0), Env.woodDark, Enum.Material.Wood, { collide = true })
	Props.part(parent, "AnvilBody", V3(0.9, 0.7, 1.4), frame * CF(0, 1.75, 0), Env.iron, Enum.Material.Metal)
	Props.part(parent, "AnvilTop", V3(1.2, 0.45, 2.6), frame * CF(0, 2.3, 0.1), Env.ironLight, Enum.Material.Metal)
	Props.part(parent, "AnvilHorn", V3(0.6, 0.35, 0.8), frame * CF(0, 2.25, 1.75), Env.ironLight, Enum.Material.Metal)
end

-- Цепь, свисающая сверху: звенья-кубики попеременно повёрнуты.
function Props.chain(parent, top: Vector3, length: number, rng)
	local links = math.floor(length / 0.7)
	for index = 0, links do
		local turned = index % 2 == 0
		Props.part(parent, "ChainLink", turned and V3(0.5, 0.8, 0.18) or V3(0.18, 0.8, 0.5), CF(top - V3(0, index * 0.7, 0)), Props.vary(Env.iron, rng, 0.06), Enum.Material.Metal, { shadow = false })
	end
	Props.part(parent, "ChainWeight", V3(0.9, 0.9, 0.9), CF(top - V3(0, links * 0.7 + 0.8, 0)) * ANG(0, 0.6, 0), Env.ironLight, Enum.Material.Metal)
end

-- Навес шатра (комната отдыха): ткань на четырёх столбах.
function Props.tent(parent, cf: CFrame, rng)
	for _, corner in ipairs({ { -3.5, -2 }, { 3.5, -2 }, { -3.5, 2 }, { 3.5, 2 } }) do
		local h = corner[2] < 0 and 6.5 or 5.5
		Props.part(parent, "TentPost", V3(0.5, h, 0.5), cf * CF(corner[1], h / 2, corner[2]), Env.woodDark, Enum.Material.Wood)
	end
	for strip = -3, 3 do
		Props.part(parent, "TentCloth", V3(1.05, 0.2, 4.8), cf * CF(strip, 6.0 + math.abs(strip) * -0.05, 0) * ANG(math.rad(-12), 0, 0),
			Props.vary(Env.sandLight, rng, 0.06), Enum.Material.Fabric)
	end
	-- Свисающий край ткани.
	for strip = -3, 3 do
		local drop = 0.5 + rng:NextNumber() * 0.8
		Props.part(parent, "TentFlap", V3(1.0, drop, 0.12), cf * CF(strip, 5.35 - drop / 2, 2.4), Props.vary(Env.sandLight, rng, 0.06), Enum.Material.Fabric, { shadow = false })
	end
end

-- Ковёр под сундуком (концепт костра).
function Props.rug(parent, position: Vector3)
	Props.part(parent, "Rug", V3(6, 0.06, 4.4), CF(position.X, 0.19, position.Z), Env.cloth, Enum.Material.Fabric, { shadow = false })
	Props.part(parent, "RugInner", V3(4.6, 0.07, 3.0), CF(position.X, 0.2, position.Z), Env.clothDark, Enum.Material.Fabric, { shadow = false })
	Props.part(parent, "RugBorder", V3(6.2, 0.05, 0.25), CF(position.X, 0.2, position.Z - 2.1), Env.gold, Enum.Material.Fabric, { shadow = false })
	Props.part(parent, "RugBorder", V3(6.2, 0.05, 0.25), CF(position.X, 0.2, position.Z + 2.1), Env.gold, Enum.Material.Fabric, { shadow = false })
end

-- ===== Парящие кубики =====

-- Кубик, который покачивается в воздухе (клиент по тегу KlinokFloat).
function Props.floatCube(parent, position: Vector3, size: number, color: Color3, rng)
	local part = Props.part(parent, "FloatCube", V3(size, size, size), CF(position) * ANG(rng:NextNumber() * 6, rng:NextNumber() * 6, rng:NextNumber() * 6), color, nil, { shadow = false })
	part:SetAttribute("Seed", rng:NextNumber() * 100)
	part:SetAttribute("Amp", 0.4 + rng:NextNumber() * 1.2)
	tag(part, Props.Tags.float)
	return part
end

-- Кубик «распада»: отрывается от кромки, поднимается и гаснет по кругу
-- (раздел 19: «кубики отрываются от краёв комнаты и медленно поднимаются»).
function Props.riseCube(parent, position: Vector3, size: number, color: Color3, rng)
	local part = Props.part(parent, "RiseCube", V3(size, size, size), CF(position), color, nil, { shadow = false })
	part:SetAttribute("Seed", rng:NextNumber() * 100)
	part:SetAttribute("Period", 5 + rng:NextNumber() * 5)
	part:SetAttribute("Lift", 6 + rng:NextNumber() * 8)
	tag(part, Props.Tags.rise)
	return part
end

-- Кубик над руинами: плавно поднимается на 1–2 стада за 2–4 с и
-- возвращается (Sine, туда-обратно, бесконечно). Ведёт клиент по тегу
-- KlinokHover.
function Props.hoverCube(parent, position: Vector3, color: Color3, rng)
	local part = Props.part(parent, "HoverCube", V3(1, 1, 1), CF(position) * ANG(0, rng:NextNumber() * 3, 0), color, nil, { shadow = false })
	part:SetAttribute("Seed", rng:NextNumber() * 100)
	part:SetAttribute("Amp", 1 + rng:NextNumber())
	part:SetAttribute("Period", 2 + rng:NextNumber() * 2)
	tag(part, Props.Tags.hover)
	return part
end

-- Скопление обломков руин: 1–3 кубические глыбы 2–5 стадов друг на друге,
-- общая высота 1–8, наклон по X/Z до ±15°. Возвращает высоту верха.
function Props.ruinCluster(parent, position: Vector3, rng, colors, maxHeight: number?)
	local top = 0
	local limit = maxHeight or 8
	local stack = rng:NextInteger(1, 3)
	for index = 1, stack do
		if top >= limit then
			break
		end
		local w = 2 + rng:NextNumber() * 3
		local d = 2 + rng:NextNumber() * 3
		local h = math.min(1 + rng:NextNumber() * 4, limit - top)
		if h < 0.8 then
			break
		end
		local offset = index == 1 and V3(0, 0, 0) or V3((rng:NextNumber() - 0.5) * 1.5, 0, (rng:NextNumber() - 0.5) * 1.5)
		local tilt = ANG(math.rad(rng:NextNumber(-15, 15)), rng:NextNumber() * math.pi, math.rad(rng:NextNumber(-15, 15)))
		Props.part(parent, "Ruin", V3(w, h, d), CF(position + offset + V3(0, top + h / 2 - (index == 1 and 0.3 or 0.15), 0)) * tilt,
			Props.vary(Props.pick(rng, colors), rng, 0.06), Enum.Material.Slate, { collide = true })
		top += h * 0.85
	end
	-- Мелкие осколки у подножия.
	for _ = 1, rng:NextInteger(0, 2) do
		local s = 0.6 + rng:NextNumber() * 0.9
		Props.part(parent, "RuinChip", V3(s, s * 0.7, s), CF(position + V3((rng:NextNumber() - 0.5) * 5, s * 0.3, (rng:NextNumber() - 0.5) * 5)) * ANG(rng:NextNumber(), rng:NextNumber() * 3, rng:NextNumber()),
			Props.vary(Props.pick(rng, colors), rng, 0.08), Enum.Material.Slate, { shadow = false })
	end
	return top
end

return Props
