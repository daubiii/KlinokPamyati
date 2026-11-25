--!nonstrict
-- Enemies3
-- Враги этажа 3 «Псарни охоты» (тема «Королевская охота»). Подмешиваются в
-- Enemies.Types (см. конец Enemies.lua) так же, как Enemies45. Особое поведение —
-- Systems/Floor3EnemyService (хук EnemyService.spawnHooks, только эти typeId);
-- вышки и копья ловчего — Floor3World (не тронуты).
--
-- Баланс: каждый тип заменяет временный тип этажей 1–2 в тех же слотах волн
-- и повторяет его числа (здоровье, броня, скорость, урон, замахи, награды).
-- Новое поверх них помечено «(доп.)» — это предложения, их легко выключить.
--   shade → hound            guard → beater           guard_elite → beater_elite
--   archer → crossbowman     ranger → trapper (в Сокольне и на мосту — falconer)
--   knight → bear_hunter     knight_elite → bear_hunter_elite
--   martyr → torchbearer     bee → falcon             drowned → skinner
--   gardener → tanner        treant → trophy_bear
--   centurion (Псарня) → pack_leader     gatekeeper (Ристалище) → royal_huntsman
--
-- Поля EnemyService — см. шапку Enemies.lua. Свои поля этажа 3 (Floor3EnemyService):
--   slow = { mul, time }   замедление игрока при попадании (болас)
--   root                   обездвиживание, с (силок, капкан)
--   puddle = { kind = "tar" | "mud", life, radius }   лужа на месте зоны/смерти
--   spread/spreadAngle     веер снарядов
--   traits.horn            рог загонщика: раз за бой ускоряет гончих рядом
--   traits.hop             отскок от игрока (как у следопыта этажа 2)
--   traits.hide            чучело: спереди урон режется (как кора древесного стража)
--   traits.pack            вожак: аура своры (гончие рядом бьют сильнее)
--   lookAs                 запасной кубический риг Enemies.LOOK, если префаба нет

local Enemies3 = {}

Enemies3.Types = {
	-- Гончая (вместо Тени) — быстрый ближний, стаи. Рывок-укус = dash_combo Тени.
	hound = {
		id = "hound",
		name = "Гончая",
		role = "melee",
		health = 60,
		armor = 0,
		speed = 19,
		size = Vector3.new(2.2, 3.6, 3.0),
		ignoreSlots = true,
		lookAs = "shade",
		attacks = {
			{ id = "lunge", windup = 0.35, aimLock = 0.3, telegraph = "parryable", damage = 14, hits = 2, dash = 9, dashTime = 0.16,
				range = 5, recover = 0.8, cooldown = 1.6 },
			-- (доп.) прыжок на цель: красный круг под игроком, после приземления 0,9 с открыта
			{ id = "leap", windup = 0.6, telegraph = "dodgeOnly", damage = 16, radius = 3.2, leap = true, leapTime = 0.45,
				recover = 0.9, cooldown = 1.6, every = 8 },
		},
		rewards = { gold = 3, xp = 8, stacks = 1, ironChance = 0.25 },
	},

	-- Загонщик (вместо Ржавого стража) — ближний, выпад рогатиной.
	beater = {
		id = "beater",
		name = "Загонщик",
		role = "melee",
		health = 90,
		armor = 0,
		speed = 10,
		size = Vector3.new(2.6, 5.6, 1.4),
		lookAs = "guard",
		-- (доп.) рог: раз за бой, увидев игрока, трубит 1,6 с — гончие в радиусе 18
		-- на 6 с бегут на 20% быстрее и замахиваются на 15% короче
		traits = { horn = { radius = 18, time = 6, speed = 0.2, windup = 0.85, blow = 1.6 } },
		attacks = {
			{ id = "thrust", windup = 0.6, telegraph = "parryable", damage = 20, range = 6, recover = 0.8, cooldown = 1.2 },
		},
		rewards = { gold = 4, xp = 10, stacks = 1, ironChance = 0.25 },
	},
	beater_elite = {
		id = "beater_elite",
		name = "Старший загонщик",
		role = "melee",
		elite = true,
		health = 150,
		armor = 4,
		speed = 10,
		size = Vector3.new(2.8, 6.0, 1.5),
		lookAs = "guard",
		traits = { horn = { radius = 18, time = 6, speed = 0.2, windup = 0.85, blow = 1.6 } },
		attacks = {
			{ id = "thrust", windup = 0.55, telegraph = "parryable", damage = 24, range = 6.5, recover = 0.8, cooldown = 1.1, hits = 2 },
		},
		rewards = { gold = 10, xp = 25, stacks = 2, ironChance = 0.6 },
	},

	-- Арбалетчик-ловчий (вместо Теневого стрелка) — болт по линии прицела.
	crossbowman = {
		id = "crossbowman",
		name = "Арбалетчик-ловчий",
		role = "ranged",
		health = 70,
		armor = 0,
		speed = 12,
		size = Vector3.new(2.4, 5.6, 1.4),
		keepMin = 14,
		keepMax = 26,
		shotRange = 38,
		lookAs = "archer",
		attacks = {
			{ id = "bolt", windup = 0.75, aimLock = 0.55, telegraph = "parryable", damage = 16, projectileSpeed = 60, projectileKind = "huntbolt",
				recover = 0.4, cooldown = 1.7 },
		},
		rewards = { gold = 5, xp = 12, stacks = 1, ironChance = 0.25 },
	},

	-- Капканщик (вместо Мохового следопыта) — болас (замедляет), силок под ноги, отскок.
	trapper = {
		id = "trapper",
		name = "Капканщик",
		role = "ranged",
		health = 70,
		armor = 0,
		speed = 12,
		size = Vector3.new(2.4, 5.4, 1.4),
		keepMin = 12,
		keepMax = 22,
		shotRange = 34,
		lookAs = "archer",
		traits = { hop = { range = 6, distance = 7, time = 0.3, cooldown = 4 } },
		attacks = {
			-- три шипа следопыта (3 × 12) → болас 18 + замедление 40% на 2 с (отбивается парированием)
			{ id = "bolas", windup = 0.8, aimLock = 0.6, telegraph = "parryable", damage = 18, projectileSpeed = 50, projectileKind = "bolas",
				slow = { mul = 0.6, time = 2.0 }, recover = 0.5, cooldown = 2.0 },
			-- (доп.) силок: зона под игроком, попал — 1 с на месте
			{ id = "snare", windup = 1.0, telegraph = "zones", damage = 6, zones = 1, radius = 2.4, root = 1.0, recover = 0.8, cooldown = 1.8, every = 9 },
		},
		rewards = { gold = 6, xp = 16, stacks = 1, ironChance = 0.25 },
	},

	-- Сокольник (вместо следопыта в Сокольне и на мосту) — спускает сокола в пике.
	falconer = {
		id = "falconer",
		name = "Сокольник",
		role = "ranged",
		health = 70,
		armor = 0,
		speed = 12,
		size = Vector3.new(2.4, 5.4, 1.4),
		keepMin = 12,
		keepMax = 22,
		shotRange = 34,
		lookAs = "archer",
		traits = { hop = { range = 6, distance = 7, time = 0.3, cooldown = 4 } },
		attacks = {
			-- сокол летит по линии прицела и возвращается на перчатку (снаряд «falcon», только уклон)
			{ id = "release", windup = 0.9, aimLock = 0.6, telegraph = "dodgeOnly", damage = 24, projectileSpeed = 42, projectileKind = "falcon",
				recover = 0.9, cooldown = 2.2 },
			{ id = "knife", windup = 0.5, telegraph = "parryable", damage = 12, range = 5, recover = 0.7, cooldown = 1.2 },
		},
		rewards = { gold = 6, xp = 16, stacks = 1, ironChance = 0.25 },
	},

	-- Сокол (вместо Пчелы-стража) — летает, пике (только уклон) и когти.
	falcon = {
		id = "falcon",
		name = "Ловчий сокол",
		role = "melee",
		health = 80,
		armor = 0,
		speed = 17,
		size = Vector3.new(2.4, 5.0, 2.0),
		ignoreSlots = true,
		lookAs = "shade",
		traits = { hover = 2.2 },
		attacks = {
			{ id = "dive", windup = 0.55, aimLock = 0.5, telegraph = "dodgeOnly", damage = 22, dash = 11, dashTime = 0.18, range = 5, recover = 1.2, cooldown = 1.8 },
			{ id = "talons", windup = 0.45, telegraph = "parryable", damage = 12, hits = 2, range = 5, recover = 0.7, cooldown = 1.2 },
		},
		rewards = { gold = 5, xp = 14, stacks = 1, ironChance = 0.2 },
	},

	-- Медвежатник (вместо Латника) — танк: щит из медвежьей шкуры и секира.
	bear_hunter = {
		id = "bear_hunter",
		name = "Медвежатник",
		role = "tank",
		health = 135,
		armor = 10,
		speed = 8,
		size = Vector3.new(3.2, 6.4, 1.8),
		lookAs = "knight",
		attacks = {
			{ id = "bash", windup = 0.8, telegraph = "parryable", damage = 20, range = 7, recover = 1.0, cooldown = 1.4 },
			{ id = "chop", windup = 1.0, telegraph = "dodgeOnly", damage = 30, radius = 4, recover = 1.5, cooldown = 1.4, every = 8 },
		},
		rewards = { gold = 8, xp = 20, stacks = 1, ironChance = 0.6 },
	},
	bear_hunter_elite = {
		id = "bear_hunter_elite",
		name = "Матёрый медвежатник",
		role = "tank",
		elite = true,
		health = 220,
		armor = 14,
		speed = 8,
		size = Vector3.new(3.4, 6.8, 2.0),
		lookAs = "knight",
		attacks = {
			{ id = "bash", windup = 0.75, telegraph = "parryable", damage = 24, range = 7, recover = 1.0, cooldown = 1.3 },
			{ id = "chop", windup = 1.0, telegraph = "dodgeOnly", damage = 34, radius = 4.5, recover = 1.4, cooldown = 1.4, every = 7 },
		},
		rewards = { gold = 14, xp = 35, stacks = 2, ironChance = 0.8 },
	},

	-- Факельщик (вместо Треснувшего) — бежит с горящим бочонком дёгтя и разбивает его.
	torchbearer = {
		id = "torchbearer",
		name = "Факельщик",
		role = "disruptor",
		health = 50,
		armor = 0,
		speed = 14,
		size = Vector3.new(2.4, 5.4, 1.4),
		triggerRange = 3,
		lookAs = "martyr",
		-- (доп.) на месте взрыва — лужа дёгтя (замедляет, как дёготь Кожевни)
		traits = { deathPuddle = { kind = "tar", radius = 4, life = 6 } },
		attacks = {
			{ id = "keg", windup = 1.2, telegraph = "dodgeOnly", damage = 40, radius = 10, range = 3, recover = 0.2, cooldown = 2.0,
				zones = 1, diesOnAttack = true },
		},
		rewards = { gold = 4, xp = 10, stacks = 1, ironChance = 0.25 },
	},

	-- Свежевальщик (вместо Утопленника, Кожевня) — тесак; бросок горшка дёгтя (лужа); после смерти — лужа.
	skinner = {
		id = "skinner",
		name = "Свежевальщик",
		role = "melee",
		health = 160,
		armor = 4,
		speed = 8,
		size = Vector3.new(3.4, 6.0, 2.0),
		lookAs = "knight",
		traits = { deathPuddle = { kind = "tar", radius = 3.5, life = 6 } },
		attacks = {
			{ id = "cleave", windup = 0.85, telegraph = "parryable", damage = 30, range = 6.5, recover = 1.0, cooldown = 1.4 },
			{ id = "tarPot", windup = 0.9, telegraph = "zones", damage = 8, radius = 3, zones = 1, puddle = { kind = "tar", life = 5 },
				slow = { mul = 0.7, time = 1.5 }, recover = 0.8, cooldown = 1.6, every = 6 },
		},
		rewards = { gold = 8, xp = 20, stacks = 1, ironChance = 0.3 },
	},

	-- Дубильщик (вместо Садовника, Кожевня) — плещет дубильным раствором из ведра (конус 3 с, жжёт) и бьёт мешалкой.
	tanner = {
		id = "tanner",
		name = "Дубильщик",
		role = "disruptor",
		health = 110,
		armor = 2,
		speed = 9,
		size = Vector3.new(3.0, 5.6, 2.0),
		lookAs = "guard",
		attacks = {
			{ id = "pour", windup = 0.8, telegraph = "dodgeOnly", damage = 0, range = 8, cone = 70, length = 9, channel = 3.0,
				poison = 0.04, poisonTime = 2.5, puddles = 3, puddle = { kind = "brine", life = 6, radius = 2.2 },
				recover = 0.9, cooldown = 2.0, every = 7 },
			{ id = "paddle", windup = 0.6, telegraph = "parryable", damage = 18, range = 5.5, recover = 0.8, cooldown = 1.2 },
		},
		rewards = { gold = 7, xp = 18, stacks = 1, ironChance = 0.25 },
	},

	-- Чучело медведя (вместо Древесного стража, Трофейный зал) — ожившее чучело на постаменте.
	-- Набитая шкура спереди режет урон вдвое: бить сбоку и со спины.
	trophy_bear = {
		id = "trophy_bear",
		name = "Чучело медведя",
		role = "tank",
		health = 210,
		armor = 12,
		speed = 7,
		size = Vector3.new(4.4, 7.4, 2.6),
		lookAs = "knight",
		traits = { hide = { arc = 120, block = 0.5 } },
		attacks = {
			{ id = "maul", windup = 0.9, telegraph = "parryable", damage = 28, range = 7.5, recover = 1.1, cooldown = 1.5 },
			-- «Капкан»: под игроком щёлкает капкан из трофеев, попал — обездвижен
			{ id = "trap", windup = 1.1, telegraph = "zones", damage = 14, radius = 2.6, zones = 1, root = 1.2, recover = 1.0, cooldown = 1.6, every = 7 },
		},
		rewards = { gold = 12, xp = 30, stacks = 2, ironChance = 0.4 },
	},

	-- Мини-босс — Вожак своры (вместо механики Сотника; MiniBossService.register из Floor3EnemyService).
	--   Хватка (белая): парировал — вожак оглушён 3 с. Рывок (красный) → загрызание (белое, связка).
	--   Прыжок-удар (красный круг). Вой на 70% и 35%: свора из клеток Псарни (точки squads),
	--   пока рядом живы гончие — они бьют на 25% сильнее (аура R 12 вокруг вожака).
	--   «Сорвался с цепи» ниже 50%: быстрее.
	pack_leader = {
		id = "pack_leader",
		name = "Вожак своры",
		title = "Пёс королевской охоты",
		role = "miniboss",
		introTime = 3.0,
		health = 450,
		armor = 10,
		speed = 12,
		size = Vector3.new(3.6, 6.0, 5.0),
		lookAs = "knight",
		attacks = {
			{ id = "bite", windup = 0.8, telegraph = "parryable", damage = 26, range = 7, recover = 1.0, cooldown = 1.3, parryStun = 3.0 },
			{ id = "rush", windup = 1.0, telegraph = "dodgeOnly", damage = 32, dash = 14, dashTime = 0.42, recover = 0.9, cooldown = 1.6, line = 14 },
			{ id = "pounce", windup = 1.0, telegraph = "dodgeOnly", damage = 34, radius = 6, leap = true, leapTime = 0.55, recover = 1.3, cooldown = 1.6, every = 7 },
			{ id = "maul", windup = 0.7, telegraph = "parryable", damage = 30, range = 6.5, recover = 1.0, cooldown = 1.2, comboOnly = true },
		},
		phases = {
			{ threshold = 0.5, name = "Сорвался с цепи", attackSpeedBonus = 0.12, sceneTime = 1.4, attacks = {} },
		},
		miniboss = {
			howls = { 0.7, 0.35 },
			howlTime = 2.0,
			auraRadius = 12,
			auraDamage = 1.25,
			chainSpeed = 0.15, -- «Сорвался с цепи»: +15% к скорости бега
			squad = { { "hound", "hound", "hound" }, { "hound", "hound", "hound", "beater_elite" } },
		},
		rewards = { gold = 45, xp = 120, iron = 3 },
	},

	-- Босс — Королевский ловчий (вместо Привратника). Вышки и копья — Floor3World (насесты).
	--   I   100–60%: удар рогатиной (белый), выпад (белый, узкий), круг рогатиной (красный), сети (зоны, корни)
	--   II   60–30%: «Гон» — две гончие, двойной удар, таран, прыжок
	--   III ниже 30%: «Последний гон» — пять сетей, круг шире, рог (гончие быстрее)
	royal_huntsman = {
		id = "royal_huntsman",
		name = "Королевский ловчий",
		title = "Хозяин королевской охоты",
		role = "boss",
		introTime = 5.0,
		deathLinger = 3.0,
		health = 720,
		armor = 12,
		speed = 10,
		size = Vector3.new(5.0, 9.0, 3.0),
		lookAs = "gatekeeper",
		attacks = {
			{ id = "sweep", windup = 0.8, telegraph = "parryable", damage = 50, range = 7, recover = 1.5, cooldown = 1.5, parryStun = 1.5 },
			{ id = "thrust", windup = 0.65, telegraph = "parryable", damage = 35, range = 10, arc = 50, recover = 1.1, cooldown = 1.4, parryStun = 1.2 },
			{ id = "spin", windup = 1.0, telegraph = "dodgeOnly", damage = 40, radius = 7, recover = 1.5, cooldown = 1.5 },
			{ id = "nets", windup = 1.0, telegraph = "zones", damage = 30, radius = 3, zones = 3, root = 0.8, recover = 1.4, cooldown = 1.5 },
		},
		phases = {
			{
				threshold = 0.6,
				name = "Гон",
				attackSpeedBonus = 0.15,
				sceneTime = 2.2,
				summon = { typeId = "hound", count = 2 },
				modify = { sweep = { hits = 2 } },
				attacks = {
					{ id = "charge", windup = 1.2, telegraph = "dodgeOnly", damage = 60, dash = 20, dashTime = 0.45, recover = 1.5, cooldown = 1.5, wallStun = 2.0 },
					{ id = "leap", windup = 0.9, telegraph = "dodgeOnly", damage = 45, radius = 5.5, leap = true, leapTime = 0.55, recover = 1.3, cooldown = 1.6 },
				},
			},
			{
				threshold = 0.3,
				name = "Последний гон",
				attackSpeedBonus = 0.3,
				sceneTime = 2.0,
				horn = { radius = 60, time = 8, speed = 0.25, windup = 0.85 }, -- (доп.) все гончие арены быстрее
				modify = { nets = { zones = 5 }, spin = { radius = 9 } },
				attacks = {},
			},
		},
		rewards = { gold = 150, xp = 300, iron = 5, soul = true },
	},
}

-- Какие временные типы в Floor3.lua заменены (для проверки и отката).
Enemies3.Replaces = {
	shade = "hound", guard = "beater", guard_elite = "beater_elite", archer = "crossbowman",
	ranger = "trapper", knight = "bear_hunter", knight_elite = "bear_hunter_elite", martyr = "torchbearer",
	bee = "falcon", drowned = "skinner", gardener = "tanner", treant = "trophy_bear",
	centurion = "pack_leader", gatekeeper = "royal_huntsman",
}
Enemies3.ReplacesIn = { mews = { ranger = "falconer" }, bridge = { ranger = "falconer" } }

return Enemies3
