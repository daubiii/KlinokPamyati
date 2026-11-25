--!nonstrict
-- LootFloor2
-- Оружие этажа 2 «Затопленные сады»: пул сундука, числа ударов, способности и пассивка.
-- Это чистые данные, без require: Weapons.lua, Loot.lua подмешивают их к своим таблицам (см. patches/floor2.patch).
-- Проценты способностей — от урона оружия (урон класса × множитель предмета × ★ эха), как на этаже 1.
-- Логика — ServerScriptService/Systems/WeaponAbilitiesGarden, эффекты — клиентский AbilityFxGarden.
-- Все числа стартовые (черновик плана, приложение Б): правятся здесь и на тестах.

local LootFloor2 = {}

-- Множители ударов {damage, speed, recovery, range, arc, stagger} (Weapons.Items).
-- Ступень этажа 2 ≈ +8% к этажу 1; разрыв между редкостями остаётся ≤ 18%, как в плане.
LootFloor2.Items = {
	garden_machete = { damage = 1.08, speed = 1.05, recovery = 0.95, range = 5.8, arc = 105, stagger = 0 },
	reed_saber = { damage = 1.05, speed = 1.12, recovery = 0.9, range = 6.8, arc = 95, stagger = 0 },
	mud_mallet = { damage = 1.72, speed = 0.66, recovery = 1.4, range = 6.5, arc = 120, stagger = 0.3 },
	thorn_blade = { damage = 1.16, speed = 1.05, recovery = 1.0, range = 6.8, arc = 110, stagger = 0 },
	root_hammer = { damage = 1.82, speed = 0.68, recovery = 1.35, range = 7, arc = 125, stagger = 0.3 },
	reaper_blade = { damage = 1.24, speed = 1.08, recovery = 1.0, range = 7.5, arc = 125, stagger = 0 },
	tidal_hammer = { damage = 1.95, speed = 0.7, recovery = 1.35, range = 7.2, arc = 135, stagger = 0.35 },
	gardener_shears = { damage = 1.3, speed = 1.05, recovery = 0.95, range = 7.5, arc = 115, stagger = 0 },
}

-- Пул сундука этажа 2: 3 обычных, 2 редких, 2 эпических, 1 легендарное.
LootFloor2.Weapons = {
	{ id = "garden_machete", name = "Садовый тесак", typeId = "sword", rarity = "common" },
	{ id = "reed_saber", name = "Камышовая сабля", typeId = "sword", rarity = "common" },
	{ id = "mud_mallet", name = "Колотушка садовника", typeId = "hammer", rarity = "common" },
	{ id = "thorn_blade", name = "Терновый клинок", typeId = "sword", rarity = "rare" },
	{ id = "root_hammer", name = "Корневой молот", typeId = "hammer", rarity = "rare" },
	{ id = "reaper_blade", name = "Клинок жатвы", typeId = "sword", rarity = "epic", ability = "reap" },
	{ id = "tidal_hammer", name = "Приливный молот", typeId = "hammer", rarity = "epic", ability = "flood" },
	{
		id = "gardener_shears",
		name = "Секатор Садовницы",
		typeId = "sword",
		rarity = "legendary",
		ability = "prune",
		passive = "bloom",
		-- Легендарка: +15% к урону способности, −8% к перезарядке (план, приложение Б).
		damageBonus = 0.15,
		cooldownReduction = 0.08,
	},
}

-- Веса редкостей сундука этажа 2 (между этажом 1: 70/22/7/1 и этажом 5: 40/30/18/9).
LootFloor2.ChestWeights = {
	common = 62,
	rare = 25,
	epic = 11,
	legendary = 2,
}

-- Сундук этажа 2: больше золота, свой материал (Loot.IronMaterial остаётся для этажа 1).
LootFloor2.Chest = {
	gold = 220,
	material = "swamp_reed", -- «Болотный тростник»: название и крафт — по плану этажа 2
	materialName = "Болотный тростник",
	materialRange = { 3, 5 },
}

LootFloor2.Abilities = {
	-- Клинок жатвы: серповидная волна вперёд по линии (пробивает), цели покрываются гнилью.
	reap = {
		id = "reap",
		name = "Жатва",
		icon = "whirl", -- иконок этажа 2 в атласе пока нет: берём вихрь, см. README
		description = "Серповидная волна вперёд на 14: 130% по линии (пробивает); цели гниют 3 с по 30% в секунду",
		cooldown = 12,
		castTime = 0.55,
		releaseAt = 0.3, -- волна уходит с клинка (анимация: широкий взмах)
		waveRange = 14,
		waveHalfWidth = 2.4,
		waveTime = 0.35,
		waveDamage = 1.3,
		rotDamage = 0.3, -- за тик
		rotTicks = 3,
		rotInterval = 1.0,
		damageMultiplier = 2.2, -- суммарно: 1,3 + 3 × 0,3
	},
	-- Приливный молот: волна воды конусом (урон, отброс) и разлив на 4 с (замедление, урон).
	flood = {
		id = "flood",
		name = "Паводок",
		icon = "split",
		description = "Удар молотом: волна воды конусом 160% с отбросом; разлив на 4 с замедляет на 40% и бьёт по 25% каждые 0,5 с",
		cooldown = 15,
		castTime = 0.7,
		slamAt = 0.35,
		coneRadius = 9,
		coneHalfAngle = 50,
		waveDamage = 1.6,
		knockback = 4,
		puddleDistance = 5.5,
		puddleRadius = 4.5,
		puddleTime = 4,
		puddleTick = 0.5,
		puddleDamage = 0.25,
		slow = 0.4,
		slowTime = 0.7,
		damageMultiplier = 3.6, -- 1,6 + 8 тиков × 0,25 при полном времени в разливе
	},
	-- Секатор Садовницы: два перекрёстных среза веером, снимают броню и делают цели уязвимее.
	prune = {
		id = "prune",
		name = "Обрезка",
		icon = "key",
		description = "Два перекрёстных среза по 110% веером 120°: −8 брони на 8 с и +20% урона по целям на 6 с",
		cooldown = 16,
		castTime = 0.6,
		cuts = { 0.25, 0.45 },
		cutDamage = 1.1,
		radius = 7,
		halfAngle = 60,
		armorBreak = 8,
		armorBreakDuration = 8,
		vulnerable = 0.2,
		vulnerableTime = 6,
		damageMultiplier = 2.2,
	},
}

LootFloor2.Passives = {
	-- Каждый удар сажает на врага шип; на 5-м шипе распускается цветок.
	bloom = {
		id = "bloom",
		name = "Цветение",
		description = "Каждый удар сажает на врага шип (6 с); на 5-м шипе цветок распускается: 90% урона в радиусе 4 и замедление 30% на 2 с",
		stacks = 5,
		stackTime = 6,
		damage = 0.9,
		radius = 4,
		slow = 0.3,
		slowTime = 2,
	},
}

return LootFloor2
