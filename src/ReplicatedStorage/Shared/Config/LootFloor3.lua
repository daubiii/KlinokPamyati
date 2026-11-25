--!nonstrict
-- LootFloor3
-- Оружие этажа 3 «Псарни охоты»: пул сундука, числа ударов, способности и пассивки.
-- Чистые данные, без require: Weapons.lua и Loot.lua подмешивают их к своим таблицам (как LootFloor2).
-- Проценты способностей — от урона оружия (урон класса × множитель предмета × ★ эха).
-- Логика — ServerScriptService/Systems/WeaponAbilitiesHunt, эффекты — клиентский AbilityFxHunt.
-- Все числа стартовые (ступень ≈ +8% к этажу 2): правятся здесь и на тестах.

local LootFloor3 = {}

-- Множители ударов {damage, speed, recovery, range, arc, stagger} (Weapons.Items).
-- Серии ударов кос — Controllers/PlayerAnimWeapons (свои кривые по id предмета).
LootFloor3.Items = {
	hunt_cleaver = { damage = 1.17, speed = 1.05, recovery = 0.95, range = 6.2, arc = 105, stagger = 0 },
	hunt_broadsword = { damage = 1.22, speed = 0.96, recovery = 1.02, range = 7, arc = 115, stagger = 0.1 },
	bear_mace = { damage = 1.96, speed = 0.66, recovery = 1.38, range = 7, arc = 125, stagger = 0.32 },
	pack_fang = { damage = 1.26, speed = 1.1, recovery = 0.95, range = 7.2, arc = 115, stagger = 0 },
	trap_maul = { damage = 2.08, speed = 0.68, recovery = 1.35, range = 7.4, arc = 130, stagger = 0.35 },
	royal_scythe = { damage = 1.36, speed = 0.96, recovery = 1.04, range = 8.4, arc = 160, stagger = 0 },
	falconer_saber = { damage = 1.3, speed = 1.08, recovery = 0.95, range = 7.4, arc = 115, stagger = 0 },
}

-- Пул сундука этажа 3: 1 обычное, 2 редких, 2 эпических, 2 легендарных.
LootFloor3.Weapons = {
	{ id = "hunt_cleaver", name = "Охотничий тесак", typeId = "sword", rarity = "common" },
	{ id = "hunt_broadsword", name = "Охотничий палаш", typeId = "sword", rarity = "rare" },
	{ id = "bear_mace", name = "Медвежья булава", typeId = "hammer", rarity = "rare" },
	{ id = "pack_fang", name = "Клык вожака", typeId = "sword", rarity = "epic", ability = "pack" },
	{ id = "trap_maul", name = "Молот-капкан", typeId = "hammer", rarity = "epic", ability = "snare" },
	{
		id = "royal_scythe",
		name = "Коса Королевского ловчего",
		typeId = "sword",
		rarity = "legendary",
		ability = "last_hunt",
		passive = "prey_mark",
		damageBonus = 0.15,
		cooldownReduction = 0.08,
	},
	{
		id = "falconer_saber",
		name = "Клинок сокольничего",
		typeId = "sword",
		rarity = "legendary",
		ability = "dive",
		passive = "falcon",
		damageBonus = 0.15,
		cooldownReduction = 0.08,
	},
}

-- Веса редкостей сундука этажа 3 (между этажом 2: 62/25/11/2 и этажом 5: 40/30/18/9).
LootFloor3.ChestWeights = {
	common = 56,
	rare = 27,
	epic = 13,
	legendary = 4,
}

LootFloor3.Chest = {
	gold = 260,
	material = "tanned_hide",
	materialName = "Дублёная шкура",
	materialRange = { 3, 5 },
}

-- icon — новый атлас иконок способностей (Config/AbilityIcons); пока атлас не загружен,
-- HUD берёт старую иконку из AbilityIcons.fallback.
LootFloor3.Abilities = {
	-- Клык вожака: три призрачные гончие срываются веером к ближайшим врагам и грызут их.
	pack = {
		id = "pack",
		name = "Свора",
		icon = "hunt_pack",
		description = "Три призрачные гончие бросаются к врагам в радиусе 15: по 3 укуса на 55% и замедление 30%",
		cooldown = 14,
		castTime = 0.5,
		summonAt = 0.25, -- вой и выход гончих (анимация: клинок вверх, рык)
		hounds = 3,
		seekRadius = 15,
		fanAngle = 35, -- веер выхода, градусы от направления взгляда
		houndSpeed = 26, -- стадов в секунду (рывок к цели)
		lifetime = 3.2,
		bites = 3,
		biteInterval = 0.65,
		biteDamage = 0.55,
		slow = 0.3,
		slowTime = 1,
		damageMultiplier = 4.95, -- 3 гончие × 3 укуса × 0,55, если все нашли цель
	},
	-- Молот-капкан: удар в землю раскрывает кольцо железных челюстей, через миг они схлопываются.
	snare = {
		id = "snare",
		name = "Капкан",
		icon = "hunt_snare",
		description = "Кольцо челюстей радиусом 7,5 схлопывается: 180%, враги прижаты к земле на 1,6 с (боссы 0,6), −6 брони на 6 с",
		cooldown = 15,
		castTime = 0.75,
		slamAt = 0.38,
		radius = 7.5,
		snapDelay = 0.45,
		snapDamage = 1.8,
		pull = 2.2, -- челюсти подтягивают к центру на столько стадов
		root = 1.6,
		bossRoot = 0.6,
		armorBreak = 6,
		armorBreakDuration = 6,
		damageMultiplier = 1.8,
	},
	-- Коса Королевского ловчего: рывок с низким махом сквозь строй, в конце — рог охоты.
	last_hunt = {
		id = "last_hunt",
		name = "Последний гон",
		icon = "hunt_spear",
		description = "Рывок с косой на 13, полоса шириной 6,4: 180% всем на пути, добыче — вдвое больше; рог в конце замедляет врагов в радиусе 8 на 45%",
		cooldown = 15,
		castTime = 0.55,
		windup = 0.18,
		dashTime = 0.22,
		dashDistance = 13,
		halfWidth = 3.2,
		damage = 1.8,
		preyBonus = 1.0, -- +100% по цели с «Меткой добычи»
		hornRadius = 8,
		slow = 0.45,
		slowTime = 2,
		damageMultiplier = 1.8,
	},
	-- Клинок сокольничего: призрачный сокол пикирует на точку перед героем.
	dive = {
		id = "dive",
		name = "Пикирование",
		icon = "hunt_dive",
		description = "Сокол пикирует на врага впереди (до 15): 240% в радиусе 6, подбрасывает",
		cooldown = 13,
		castTime = 0.5,
		releaseAt = 0.2,
		range = 15,
		coneHalfAngle = 40,
		diveTime = 0.35,
		radius = 6,
		damage = 2.4,
		launchHeight = 3,
		launchTime = 0.7,
		damageMultiplier = 2.4,
	},
}

LootFloor3.Passives = {
	-- Финал серии метит добычу (одна на героя); убийство добычи возвращает часть перезарядки.
	prey_mark = {
		id = "prey_mark",
		name = "Метка добычи",
		description = "Финал серии метит врага на 8 с: он получает +18% урона. Убийство добычи возвращает 30% перезарядки «Последнего гона»",
		markTime = 8,
		vulnerable = 0.18,
		refund = 0.3,
	},
	-- Сокол кружит над героем и раз в 5 с бьёт врага, которого герой только что ударил.
	falcon = {
		id = "falcon",
		name = "Сокол",
		description = "Раз в 5 с сокол бьёт врага, которого вы ударили: 80% удара и −4 брони на 4 с",
		interval = 5,
		delay = 0.35,
		damage = 0.8,
		armorBreak = 4,
		armorBreakDuration = 4,
	},
}

return LootFloor3
