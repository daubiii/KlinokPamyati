--!nonstrict
-- LootFloor5
-- Оружие этажа 5 «Архив Хрониста»: пул сундука, числа ударов, способности и пассивки.
-- Чистые данные, без require: Weapons.lua и Loot.lua подмешивают их к своим таблицам (как LootFloor2).
-- Логика — ServerScriptService/Systems/WeaponAbilitiesChronicle, эффекты — клиентский AbilityFxChronicle.
-- Секретка «Клинок Памяти» падает только из сундука этажа 5 (вес secret ниже).
-- Все числа стартовые (ступень ≈ +8% к этажу 4): правятся здесь и на тестах.

local LootFloor5 = {}

LootFloor5.Items = {
	paper_knife = { damage = 1.36, speed = 1.15, recovery = 0.88, range = 6, arc = 100, stagger = 0 },
	tome_hammer = { damage = 2.25, speed = 0.68, recovery = 1.35, range = 7, arc = 125, stagger = 0.33 },
	bookmark_blade = { damage = 1.4, speed = 1.08, recovery = 0.95, range = 7.2, arc = 105, stagger = 0 },
	quill_blade = { damage = 1.46, speed = 1.08, recovery = 0.95, range = 7.6, arc = 115, stagger = 0 },
	seal_hammer = { damage = 2.4, speed = 0.68, recovery = 1.35, range = 7.6, arc = 135, stagger = 0.36 },
	hourglass_maul = { damage = 2.55, speed = 0.66, recovery = 1.4, range = 7.6, arc = 135, stagger = 0.4 },
	ink_blade = { damage = 1.52, speed = 1.08, recovery = 0.95, range = 7.6, arc = 120, stagger = 0 },
	oblivion_scythe = { damage = 1.5, speed = 0.95, recovery = 1.05, range = 8.2, arc = 165, stagger = 0 },
	memory_blade = { damage = 1.45, speed = 1.08, recovery = 0.95, range = 7.6, arc = 120, stagger = 0 },
}

-- Пул сундука этажа 5: 1 обычное, 2 редких, 2 эпических, 3 легендарных, 1 секретное.
LootFloor5.Weapons = {
	{ id = "paper_knife", name = "Нож для бумаги", typeId = "sword", rarity = "common" },
	{ id = "tome_hammer", name = "Молот-фолиант", typeId = "hammer", rarity = "rare" },
	{ id = "bookmark_blade", name = "Клинок-закладка", typeId = "sword", rarity = "rare" },
	{ id = "quill_blade", name = "Перо хрониста", typeId = "sword", rarity = "epic", ability = "inscribe" },
	{ id = "seal_hammer", name = "Печать", typeId = "hammer", rarity = "epic", ability = "seal_time" },
	{
		id = "hourglass_maul",
		name = "Молот Песочных часов",
		typeId = "hammer",
		rarity = "legendary",
		ability = "timeless",
		passive = "sand",
		damageBonus = 0.15,
		cooldownReduction = 0.08,
	},
	{
		id = "ink_blade",
		name = "Чернильный клинок",
		typeId = "sword",
		rarity = "legendary",
		ability = "ink_splash",
		passive = "ink_stain",
		damageBonus = 0.15,
		cooldownReduction = 0.08,
	},
	{
		id = "oblivion_scythe",
		name = "Коса Забвения",
		typeId = "sword",
		rarity = "legendary",
		ability = "erase",
		passive = "oblivion",
		damageBonus = 0.15,
		cooldownReduction = 0.08,
	},
	{
		id = "memory_blade",
		name = "Клинок Памяти",
		typeId = "sword",
		rarity = "secret",
		ability = "recall",
		passive = "afterimage",
		damageBonus = 0.2,
		cooldownReduction = 0.1,
	},
}

-- Веса этажа 5 — из плана (40/30/18/9) + секретка.
LootFloor5.ChestWeights = {
	common = 40,
	rare = 30,
	epic = 18,
	legendary = 9,
	secret = 1.5,
}

LootFloor5.Chest = {
	gold = 350,
	material = "memory_ink",
	materialName = "Чернила памяти",
	materialRange = { 4, 6 },
}

LootFloor5.Abilities = {
	-- Перо хрониста: пишет строку рун по земле, руны детонируют по очереди.
	inscribe = {
		id = "inscribe",
		name = "Строка",
		icon = "chron_line",
		description = "Перо пишет строку рун на 14 вперёд; через 0,35 с руны взрываются по очереди: 180% и оглушение 0,6 с",
		cooldown = 14,
		castTime = 0.6,
		writeAt = 0.15,
		writeTime = 0.45,
		length = 14,
		halfWidth = 2.3,
		runes = 6,
		detonateDelay = 0.35,
		runeInterval = 0.07,
		damage = 1.8,
		stun = 0.6,
		damageMultiplier = 1.8,
	},
	-- Печать: удар печатью — враги в круге застывают во времени, потом печать ломается.
	seal_time = {
		id = "seal_time",
		name = "Опечатать",
		icon = "chron_seal",
		description = "Печать радиусом 8: 140%, враги застывают во времени на 2,5 с (боссы 0,8) и получают +20% урона; печать ломается — 80%",
		cooldown = 16,
		castTime = 0.7,
		stampAt = 0.36,
		radius = 8,
		damage = 1.4,
		freeze = 2.5,
		bossFreeze = 0.8,
		vulnerable = 0.2,
		breakDamage = 0.8,
		damageMultiplier = 2.2,
	},
	-- Молот Песочных часов: купол безвременья — враги почти стоят, удары героя внутри отдаются эхом.
	timeless = {
		id = "timeless",
		name = "Безвременье",
		icon = "chron_hourglass",
		description = "Купол радиусом 11,5 на 3 с: враги замедлены на 70%, ваши удары по ним внутри — эхо +35%; песок обрушивается — 160%",
		cooldown = 18,
		castTime = 0.8,
		turnAt = 0.42,
		radius = 11.5,
		duration = 3,
		slow = 0.7,
		pulse = 0.25,
		echo = 0.35,
		collapseDamage = 1.6,
		damageMultiplier = 1.6,
	},
	-- Чернильный клинок: веер чернил; пятна на врагах усиливают выплеск.
	ink_splash = {
		id = "ink_splash",
		name = "Разлить чернила",
		icon = "chron_ink",
		description = "Веер чернил 140° на 10,5: 140% + 35% за каждое пятно на враге (пятна сгорают), замедление 40% на 2,5 с",
		cooldown = 14,
		castTime = 0.6,
		splashAt = 0.3,
		radius = 10.5,
		halfAngle = 70,
		damage = 1.4,
		perStain = 0.35,
		slow = 0.4,
		slowTime = 2.5,
		damageMultiplier = 2.8,
	},
	-- Коса Забвения: широкий взмах, слабых врагов стирает со страниц.
	erase = {
		id = "erase",
		name = "Стереть",
		icon = "chron_erase",
		description = "Взмах косой 240° на 10,5: 220%; враг ниже 25% здоровья стирается (боссы — +50% урона)",
		cooldown = 17,
		castTime = 0.9,
		swingAt = 0.5,
		radius = 10.5,
		halfAngle = 120,
		damage = 2.2,
		executeBelow = 0.25,
		bossBonus = 0.5,
		damageMultiplier = 2.2,
	},
	-- Секретка: два эхо-двойника повторяют ваши удары за последние 4 с.
	recall = {
		id = "recall",
		name = "Вспомнить",
		icon = "chron_memory",
		description = "Два эхо-двойника повторяют ваши удары за последние 5 с (до 10): каждый повтор — 60% исходного удара",
		cooldown = 16,
		castTime = 0.5,
		summonAt = 0.25,
		memory = 5,
		maxSwings = 10,
		echoes = 2,
		replayScale = 0.6,
		replayStart = 0.35,
		replayGap = 0.28, -- минимальный шаг между повторами (быстрые серии растягиваются)
		echoOffset = 2.6, -- двойники встают слева и справа позади героя
		damageMultiplier = 12, -- 2 двойника × 8 повторов × 0,6 (полная память)
	},
}

LootFloor5.Passives = {
	sand = {
		id = "sand",
		name = "Песок времени",
		description = "Каждый удар сокращает перезарядку «Безвременья» на 0,4 с, финал серии — на 1 с",
		perHit = 0.4,
		perFinisher = 1.0,
	},
	ink_stain = {
		id = "ink_stain",
		name = "Пятна",
		description = "Каждый удар ставит на врага чернильное пятно (до 4, 6 с)",
		maxStains = 4,
		stainTime = 6,
	},
	oblivion = {
		id = "oblivion",
		name = "Забвение",
		description = "Финал серии стирает 4 брони на 5 с, цель получает +10% урона",
		armorBreak = 4,
		armorBreakDuration = 5,
		vulnerable = 0.1,
		vulnerableTime = 5,
	},
	-- Секретка: каждый 4-й попавший удар повторяет эхо через 0,35 с.
	afterimage = {
		id = "afterimage",
		name = "Послеобраз",
		description = "Каждый 4-й попавший удар повторяет эхо через 0,35 с: 50% удара по той же дуге",
		every = 4,
		delay = 0.35,
		damage = 0.5,
	},
}

return LootFloor5
