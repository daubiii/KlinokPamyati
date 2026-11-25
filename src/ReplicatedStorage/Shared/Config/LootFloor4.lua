--!nonstrict
-- LootFloor4
-- Оружие этажа 4 «Кузня Основателя»: пул сундука, числа ударов, способности и пассивки.
-- Чистые данные, без require: Weapons.lua и Loot.lua подмешивают их к своим таблицам (как LootFloor2).
-- Логика — ServerScriptService/Systems/WeaponAbilitiesForge, эффекты — клиентский AbilityFxForge.
-- Секретка «Незавершённая отливка» падает только из сундука этажа 4 (вес secret ниже).
-- Все числа стартовые (ступень ≈ +8% к этажу 3): правятся здесь и на тестах.

local LootFloor4 = {}

LootFloor4.Items = {
	cast_cleaver = { damage = 1.26, speed = 1.03, recovery = 0.95, range = 6.3, arc = 105, stagger = 0 },
	quench_blade = { damage = 1.3, speed = 1.1, recovery = 0.92, range = 7, arc = 100, stagger = 0 },
	apprentice_hammer = { damage = 2.1, speed = 0.68, recovery = 1.35, range = 7, arc = 125, stagger = 0.32 },
	crucible_maul = { damage = 2.25, speed = 0.68, recovery = 1.35, range = 7.5, arc = 135, stagger = 0.36 },
	searing_blade = { damage = 1.36, speed = 1.08, recovery = 0.95, range = 7.4, arc = 115, stagger = 0 },
	anvil_hammer = { damage = 2.4, speed = 0.66, recovery = 1.4, range = 7.5, arc = 135, stagger = 0.4 },
	forge_heart_blade = { damage = 1.42, speed = 1.05, recovery = 0.95, range = 7.6, arc = 120, stagger = 0 },
	slag_scythe = { damage = 1.4, speed = 0.95, recovery = 1.05, range = 8, arc = 160, stagger = 0 },
	unfinished_blade = { damage = 1.3, speed = 1.05, recovery = 0.95, range = 7.2, arc = 115, stagger = 0 },
}

-- Пул сундука этажа 4: 1 обычное, 2 редких, 2 эпических, 3 легендарных, 1 секретное.
LootFloor4.Weapons = {
	{ id = "cast_cleaver", name = "Литой тесак", typeId = "sword", rarity = "common" },
	{ id = "quench_blade", name = "Закалённый клинок", typeId = "sword", rarity = "rare" },
	{ id = "apprentice_hammer", name = "Молот подмастерья", typeId = "hammer", rarity = "rare" },
	{ id = "crucible_maul", name = "Молот-тигель", typeId = "hammer", rarity = "epic", ability = "spill" },
	{ id = "searing_blade", name = "Раскалённый клинок", typeId = "sword", rarity = "epic", ability = "overheat" },
	{
		id = "anvil_hammer",
		name = "Наковальня",
		typeId = "hammer",
		rarity = "legendary",
		ability = "anvil_drop",
		passive = "temper",
		damageBonus = 0.15,
		cooldownReduction = 0.08,
	},
	{
		id = "forge_heart_blade",
		name = "Клинок горна",
		typeId = "sword",
		rarity = "legendary",
		ability = "forge_breath",
		passive = "embers",
		damageBonus = 0.15,
		cooldownReduction = 0.08,
	},
	{
		id = "slag_scythe",
		name = "Шлаковая коса",
		typeId = "sword",
		rarity = "legendary",
		ability = "slag_reap",
		passive = "slag_crust",
		damageBonus = 0.15,
		cooldownReduction = 0.08,
	},
	{
		id = "unfinished_blade",
		name = "Незавершённая отливка",
		typeId = "sword",
		rarity = "secret",
		ability = "pour",
		passive = "casting",
		damageBonus = 0.2,
		cooldownReduction = 0.1,
	},
}

LootFloor4.ChestWeights = {
	common = 50,
	rare = 28,
	epic = 15,
	legendary = 6,
	secret = 1,
}

LootFloor4.Chest = {
	gold = 300,
	material = "cast_bronze",
	materialName = "Литая бронза",
	materialRange = { 3, 6 },
}

LootFloor4.Abilities = {
	-- Молот-тигель: тигель опрокидывается вперёд, три лужи расплава вспыхивают одна за другой.
	spill = {
		id = "spill",
		name = "Разлив",
		icon = "forge_spill",
		description = "Тигель опрокидывается: три лужи расплава вспыхивают по линии (120%, подброс), затем горят 3 с: 20% каждые 0,5 с и замедление 30%",
		cooldown = 15,
		castTime = 0.8,
		pourAt = 0.4,
		pools = 3,
		poolStart = 2.5,
		poolSpacing = 3.2,
		poolDelay = 0.14,
		poolRadius = 3.0,
		eruptDamage = 1.2,
		launchHeight = 1.5,
		launchTime = 0.5,
		burnTime = 3,
		burnTick = 0.5,
		burnDamage = 0.2,
		slow = 0.3,
		slowTime = 0.6,
		damageMultiplier = 2.4,
	},
	-- Раскалённый клинок: волна жара вокруг и 5 с перекала — удары взрываются.
	overheat = {
		id = "overheat",
		name = "Перекал",
		icon = "forge_overheat",
		description = "Волна жара 110% в радиусе 6; 5 с каждый удар взрывается: +50% удара в радиусе 3,5 и ожог 3 × 15%",
		cooldown = 16,
		castTime = 0.45,
		novaAt = 0.22,
		novaRadius = 6,
		novaDamage = 1.1,
		buffTime = 5,
		hitBurst = 0.5, -- доля удара
		burstRadius = 3.5,
		burnTicks = 3,
		burnInterval = 1,
		burnDamage = 0.15, -- доля удара за тик
		damageMultiplier = 1.1,
	},
	-- Наковальня: метка на земле, через 0,6 с с неба падает огромная наковальня.
	anvil_drop = {
		id = "anvil_drop",
		name = "Наковальня с небес",
		icon = "forge_anvil",
		description = "Через 0,6 с в точку впереди (до 12) падает наковальня: 300% в радиусе 7, оглушение 1,2 с; ударная волна до 12 — 60%",
		cooldown = 16,
		castTime = 0.6,
		markAt = 0.3,
		range = 12,
		fallTime = 0.6,
		radius = 7,
		damage = 3.0,
		stun = 1.2,
		bossStun = 0.4,
		ringRadius = 12,
		ringDamage = 0.6,
		damageMultiplier = 3.6,
	},
	-- Клинок горна: из клинка бьёт струя пламени (поддерживается 1,1 с).
	forge_breath = {
		id = "forge_breath",
		name = "Дыхание горна",
		icon = "forge_breath",
		description = "Струя пламени конусом 90° на 10,5: 6 тиков по 46%, каждый тик подкладывает уголь",
		cooldown = 15,
		castTime = 1.3,
		startAt = 0.2,
		ticks = 6,
		tickInterval = 0.18,
		radius = 10.5,
		halfAngle = 45,
		tickDamage = 0.46,
		damageMultiplier = 2.76,
	},
	-- Шлаковая коса: два оборота с косой, шлак разлетается и застывает лужами.
	slag_reap = {
		id = "slag_reap",
		name = "Шлаковый серп",
		icon = "forge_scythe",
		description = "Два оборота с косой: 2 × 125% в радиусе 9; восемь комьев шлака застывают лужами на 3 с (замедление 40%, 18% каждые 0,5 с)",
		cooldown = 14,
		castTime = 0.85,
		hits = { 0.3, 0.62 },
		radius = 9,
		hitDamage = 1.25,
		globs = 8,
		globDistance = 7,
		globFlight = 0.45,
		globRadius = 2.6,
		globTime = 3,
		globTick = 0.5,
		globDamage = 0.18,
		slow = 0.4,
		slowTime = 0.6,
		damageMultiplier = 2.5,
	},
	-- Секретка: заливка форм — волны расплава по числу ступеней отливки, финал — взрыв пара.
	pour = {
		id = "pour",
		name = "Заливка",
		icon = "forge_pour",
		description = "Волны расплава по числу ступеней отливки (1–3): 120% кольцом от радиуса 5,5, каждая шире; на 3-й ступени — взрыв пара 240% в радиусе 9 и подброс. Ступени сгорают",
		cooldown = 14,
		castTime = 1.1,
		waveAt = 0.4,
		waveInterval = 0.22,
		waveDamage = 1.2,
		waveRadius = 5.5,
		waveGrow = 2.2,
		steamDelay = 0.25,
		steamDamage = 2.4,
		steamRadius = 9,
		launchHeight = 3,
		launchTime = 0.8,
		damageMultiplier = 6.0, -- на 3-й ступени: 3 × 1,2 + 2,0
	},
}

LootFloor4.Passives = {
	temper = {
		id = "temper",
		name = "Закалка",
		description = "Каждый удар — заряд закалки (до 5, 6 с). На 5 зарядах финал серии звенит: 150% удара в радиусе 4,5 и оглушение 0,5 с",
		maxStacks = 5,
		stackTime = 6,
		damage = 1.5,
		radius = 4.5,
		stun = 0.5,
	},
	embers = {
		id = "embers",
		name = "Угли",
		description = "Удар оставляет на враге уголь (5 с); на 3-м угле враг вспыхивает: 100% удара в радиусе 3 и ожог 3 × 20%",
		stacks = 3,
		stackTime = 5,
		burstDamage = 1.0,
		radius = 3,
		burnTicks = 3,
		burnInterval = 1,
		burnDamage = 0.2,
	},
	slag_crust = {
		id = "slag_crust",
		name = "Окалина",
		description = "Удары замедляют на 15%; каждый 3-й удар по одному врагу снимает 3 брони на 4 с",
		slow = 0.15,
		slowTime = 1.5,
		every = 3,
		armorBreak = 3,
		armorBreakDuration = 4,
	},
	-- Секретка: удары докапывают клинок — он растёт по ступеням и бьёт сильнее.
	casting = {
		id = "casting",
		name = "Отливка",
		description = "Каждый удар доливает металл в клинок: 10 ударов — ступень (до 3). Ступень даёт +12% урона удара и удлиняет клинок; без боя 8 с металл остывает",
		perStage = 10,
		stages = 3,
		decayDelay = 8,
		decayRate = 2, -- единиц металла в секунду после паузы
		bonusPerStage = 0.12,
	},
}

return LootFloor4
