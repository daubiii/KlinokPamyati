--!nonstrict
-- Enemies45
-- Враги этажей 4 «Литейные» и 5 «Зал хроник» (лор и цвета — из плана,
-- поведение — по образцу этажей 1–2). Подмешиваются в Enemies.Types
-- (см. конец Enemies.lua). Особое поведение — Systems/Floor45Service через
-- хуки врага; числа — здесь, в traits и атаках. Все числа стартовые.
--
-- Поля, которые понимает EnemyService сам: windup, telegraph, damage, hits,
-- range, arc, radius, zones, dash, dashTime, wallStun, leap, leapTime,
-- projectileSpeed, projectileKind, aimLock, every, recover, cooldown,
-- diesOnAttack, parryStun. Свои поля этажей 4–5 (Floor45Service):
--   cone/length      конус перед врагом (выдох жара, разлив ковша)
--   burn             ожог при попадании { pct = доля MaxHealth в секунду, time }
--   puddle           лужа: kind = "molten" (жжёт) | "ink" (вязко) | "erase" (стирание)
--   puddles          сколько луж по линии конуса
--   spread/spreadAngle  веер снарядов (как у следопыта этажа 2)
--   root, slow       обездвиживание / замедление игрока при попадании
--   summon           призыв { typeId, count, limit }
--   lines/lineLength/lineWidth/lineSpread  линии (нити переплётчика)
--   beam             луч хрониста { length, width }
--   lookAs           запасной кубический риг Enemies.LOOK, если префаба нет

local Enemies45 = {}

Enemies45.Types = {
	-- ================= Этаж 4 «Литейные» =================

	-- Кузнечный автомат — танк. Нагрудник спереди режет урон вдвое; после
	-- «Сотрясения» стравливает пар — 1,5 с открыт (+50% урона).
	forge_automaton = {
		id = "forge_automaton",
		name = "Кузнечный автомат",
		role = "tank",
		health = 240,
		armor = 14,
		speed = 6.5,
		size = Vector3.new(4.6, 7.6, 3.0),
		lookAs = "knight",
		traits = {
			frontArmor = { arc = 120, block = 0.5 },
			vent = { after = "quake", vulnerable = 0.5, time = 1.5 },
		},
		attacks = {
			{ id = "hammer", windup = 0.95, telegraph = "parryable", damage = 30, range = 8, recover = 1.1, cooldown = 1.5 },
			{ id = "quake", windup = 1.2, telegraph = "dodgeOnly", damage = 22, radius = 7, recover = 1.6, cooldown = 1.6, every = 7 },
			{ id = "blast", windup = 0.8, telegraph = "dodgeOnly", damage = 18, range = 8, cone = 60, length = 9,
				burn = { pct = 0.03, time = 2.0 }, recover = 1.0, cooldown = 1.6, every = 9 },
		},
		rewards = { gold = 16, xp = 40, stacks = 2, ironChance = 0.45 },
	},

	-- Огненный дух — быстрый ближний, парит. Когти (белые) и бросок (красный).
	fire_spirit = {
		id = "fire_spirit",
		name = "Огненный дух",
		role = "melee",
		health = 70,
		armor = 0,
		speed = 16,
		size = Vector3.new(2.4, 5.4, 2.0),
		ignoreSlots = true,
		lookAs = "shade",
		traits = { hover = 0.8, burnOnHit = { pct = 0.02, time = 1.5 } },
		attacks = {
			{ id = "claws", windup = 0.45, telegraph = "parryable", damage = 10, hits = 2, range = 5, recover = 0.7, cooldown = 1.2 },
			{ id = "lunge", windup = 0.55, aimLock = 0.5, telegraph = "dodgeOnly", damage = 18, dash = 10, dashTime = 0.2, range = 4.5,
				recover = 1.1, cooldown = 1.8 },
		},
		rewards = { gold = 7, xp = 18, stacks = 1, ironChance = 0.2 },
	},

	-- Шлаковщик — дальний: навесом бросает шлак (лужа расплава), вблизи — ковш.
	slag_thrower = {
		id = "slag_thrower",
		name = "Шлаковщик",
		role = "ranged",
		health = 85,
		armor = 2,
		speed = 11,
		size = Vector3.new(2.8, 5.8, 2.0),
		keepMin = 12,
		keepMax = 22,
		shotRange = 30,
		lookAs = "archer",
		attacks = {
			{ id = "lob", windup = 0.9, telegraph = "zones", damage = 16, zones = 1, radius = 3,
				puddle = { kind = "molten", life = 5, radius = 3 }, burn = { pct = 0.02, time = 1.5 }, recover = 0.8, cooldown = 1.8 },
			{ id = "ladle", windup = 0.6, telegraph = "parryable", damage = 14, range = 5, recover = 0.8, cooldown = 1.2 },
		},
		rewards = { gold = 8, xp = 20, stacks = 1, ironChance = 0.25 },
	},

	-- Тлеющий — бежит и взрывается (как Треснувший этажа 1), оставляет расплав.
	smolder = {
		id = "smolder",
		name = "Тлеющий",
		role = "melee",
		health = 45,
		armor = 0,
		speed = 13,
		size = Vector3.new(2.2, 3.4, 2.2),
		ignoreSlots = true,
		lookAs = "martyr",
		traits = { deathPuddle = { kind = "molten", radius = 3.5, life = 5 } },
		attacks = {
			{ id = "burst", windup = 1.0, telegraph = "dodgeOnly", damage = 34, radius = 6, range = 3, diesOnAttack = true,
				recover = 0.5, cooldown = 1.0 },
		},
		rewards = { gold = 5, xp = 14, stacks = 1, ironChance = 0.15 },
	},

	-- Босс этажа 4 — Старший литейщик. Три фазы:
	--   I   100–65%: удар молотом (белый), разлив из ковша (конус + лужи), брызги (зоны)
	--   II   65–35%: «Горн раздут» — два огненных духа, вихрь с ковшом, разливы
	--               по жёлобам арены (POUR_*)
	--   III ниже 35%: «Плавка» — прыжок с ударом, случайные расплавы по арене
	elder_founder = {
		id = "elder_founder",
		name = "Старший литейщик",
		title = "Хозяин Великого горна",
		role = "boss",
		health = 1500,
		armor = 12,
		speed = 8.5,
		size = Vector3.new(6.2, 11.6, 3.8),
		lookAs = "gatekeeper",
		attacks = {
			{ id = "slam", windup = 0.9, telegraph = "parryable", damage = 42, range = 10, arc = 120, recover = 1.3, cooldown = 1.4, parryStun = 1.5 },
			{ id = "pour", windup = 0.9, telegraph = "dodgeOnly", damage = 30, range = 12, cone = 70, length = 14, puddles = 3,
				puddle = { kind = "molten", life = 7, radius = 2.6 }, burn = { pct = 0.03, time = 2 }, recover = 1.3, cooldown = 1.6, every = 6 },
			{ id = "splash", windup = 1.0, telegraph = "zones", damage = 24, zones = 3, radius = 3.2,
				puddle = { kind = "molten", life = 5, radius = 3.0 }, recover = 1.1, cooldown = 1.6, every = 5 },
		},
		phases = {
			{
				threshold = 0.65,
				name = "Горн раздут",
				attackSpeedBonus = 0.1,
				sceneTime = 2.2,
				summon = { typeId = "fire_spirit", count = 2 },
				channels = { every = 9, warn = 1.4, life = 6, radius = 3.4, count = 3 }, -- разливы по жёлобам (Floor4World)
				attacks = {
					{ id = "spin", windup = 1.0, telegraph = "dodgeOnly", damage = 34, radius = 9, recover = 1.4, cooldown = 1.6, every = 6 },
				},
			},
			{
				threshold = 0.35,
				name = "Плавка",
				attackSpeedBonus = 0.22,
				sceneTime = 2.0,
				melt = { every = 3.5, warn = 1.2, life = 5, radius = 3.0, count = 2 }, -- случайные расплавы (Floor4World)
				attacks = {
					{ id = "leap", windup = 1.1, telegraph = "dodgeOnly", damage = 50, radius = 6, leap = true, leapTime = 0.6,
						puddle = { kind = "molten", life = 5, radius = 4 }, recover = 1.5, cooldown = 1.8, every = 7 },
				},
			},
		},
		rewards = { gold = 260, xp = 560, iron = 8, soul = true },
	},

	-- ================= Этаж 5 «Зал хроник» =================

	-- Каменный чтец — танк. Книга-щит спереди; «Чтение вслух» — волна, замедляет.
	stone_reader = {
		id = "stone_reader",
		name = "Каменный чтец",
		role = "tank",
		health = 260,
		armor = 16,
		speed = 6,
		size = Vector3.new(4.8, 8.0, 3.2),
		lookAs = "knight",
		traits = { frontArmor = { arc = 110, block = 0.6 } },
		attacks = {
			{ id = "slam", windup = 0.95, telegraph = "parryable", damage = 32, range = 7.5, recover = 1.1, cooldown = 1.5 },
			{ id = "recital", windup = 1.2, telegraph = "dodgeOnly", damage = 20, radius = 8, slow = { mul = 0.6, time = 2.0 },
				recover = 1.3, cooldown = 1.6, every = 8 },
		},
		rewards = { gold = 18, xp = 44, stacks = 2, ironChance = 0.45 },
	},

	-- Маг печати — дальний. Неуязвим, пока цела его печать (ward_seal рядом);
	-- печать разбита — оглушён 1,5 с. Руны (белые — отбиваются) и знак под ногами.
	seal_mage = {
		id = "seal_mage",
		name = "Маг печати",
		role = "ranged",
		health = 90,
		armor = 0,
		speed = 9,
		size = Vector3.new(2.6, 6.0, 1.8),
		keepMin = 10,
		keepMax = 20,
		shotRange = 28,
		lookAs = "archer",
		traits = { ward = { typeId = "ward_seal", offset = 5, stun = 1.5 } },
		attacks = {
			{ id = "bolt", windup = 0.8, aimLock = 0.6, telegraph = "parryable", damage = 14, projectileSpeed = 45, projectileKind = "rune",
				recover = 0.6, cooldown = 1.6 },
			{ id = "sigil", windup = 1.0, telegraph = "zones", damage = 18, zones = 2, radius = 3, root = 0.8, recover = 0.9, cooldown = 1.8, every = 6 },
		},
		rewards = { gold = 9, xp = 24, stacks = 1, ironChance = 0.25 },
	},

	-- Печать мага — объект (без ИИ). Пока стоит — маг (или Хронист) неуязвим.
	ward_seal = {
		id = "ward_seal",
		name = "Защитная печать",
		role = "object",
		health = 60,
		armor = 0,
		speed = 0,
		size = Vector3.new(3.0, 4.2, 3.0),
		attacks = {},
		rewards = { gold = 0, xp = 6, stacks = 0 },
	},

	-- Чернильный писарь — призыватель: клясксы-слуги, брызги чернил (лужа
	-- вязкая), вблизи — укол пером.
	ink_scribe = {
		id = "ink_scribe",
		name = "Чернильный писарь",
		role = "disruptor",
		health = 100,
		armor = 2,
		speed = 8,
		size = Vector3.new(2.8, 5.6, 2.0),
		keepMin = 9,
		keepMax = 18,
		lookAs = "guard",
		attacks = {
			{ id = "summon", windup = 1.2, telegraph = "dodgeOnly", damage = 0, range = 30, summon = { typeId = "ink_blot", count = 2, limit = 4 },
				recover = 1.0, cooldown = 2.0, every = 9 },
			{ id = "splash", windup = 0.9, telegraph = "zones", damage = 10, zones = 1, radius = 3.5,
				puddle = { kind = "ink", life = 6, radius = 3.5 }, slow = { mul = 0.65, time = 1.5 }, recover = 0.8, cooldown = 1.6, every = 5 },
			{ id = "stab", windup = 0.5, telegraph = "parryable", damage = 14, range = 5, recover = 0.7, cooldown = 1.1 },
		},
		rewards = { gold = 9, xp = 24, stacks = 1, ironChance = 0.25 },
	},

	-- Клякса — мелкий слуга писаря; лопаясь, оставляет лужу чернил.
	ink_blot = {
		id = "ink_blot",
		name = "Клякса",
		role = "melee",
		health = 30,
		armor = 0,
		speed = 15,
		size = Vector3.new(2.2, 2.4, 2.2),
		ignoreSlots = true,
		lookAs = "martyr",
		traits = { deathPuddle = { kind = "ink", radius = 3.0, life = 5 } },
		attacks = {
			{ id = "bite", windup = 0.45, telegraph = "parryable", damage = 10, range = 4, recover = 0.6, cooldown = 1.0 },
		},
		rewards = { gold = 2, xp = 6, stacks = 0, ironChance = 0.05 },
	},

	-- Хранитель полок — стрелок: веер страниц (отбиваются), отскок от игрока.
	shelf_warden = {
		id = "shelf_warden",
		name = "Хранитель полок",
		role = "ranged",
		health = 75,
		armor = 0,
		speed = 12,
		size = Vector3.new(2.4, 6.4, 1.6),
		keepMin = 14,
		keepMax = 24,
		shotRange = 36,
		lookAs = "archer",
		traits = { hop = { range = 7, distance = 7, time = 0.3, cooldown = 4 } },
		attacks = {
			{ id = "fan", windup = 0.8, aimLock = 0.6, telegraph = "parryable", damage = 10, projectileSpeed = 58, projectileKind = "page",
				spread = 5, spreadAngle = 10, recover = 0.6, cooldown = 2.0 },
		},
		rewards = { gold = 8, xp = 22, stacks = 1, ironChance = 0.25 },
	},

	-- Мини-босс этажа 5 — Переплётчик (Скрипторий). На 50% — «Переплёт»:
	-- быстрее, три кляксы, нити тремя линиями (обездвиживают).
	bookbinder = {
		id = "bookbinder",
		name = "Переплётчик",
		title = "Страж скриптория",
		role = "miniboss",
		health = 900,
		armor = 10,
		speed = 9.5,
		size = Vector3.new(4.6, 9.2, 3.0),
		lookAs = "gatekeeper",
		attacks = {
			{ id = "cut", windup = 0.8, telegraph = "parryable", damage = 34, range = 9, arc = 110, recover = 1.1, cooldown = 1.3, parryStun = 1.4 },
			{ id = "stitch", windup = 0.6, aimLock = 0.6, telegraph = "dodgeOnly", damage = 30, dash = 16, dashTime = 0.35, wallStun = 1.5,
				root = 1.0, recover = 1.2, cooldown = 1.6, every = 6 },
			{ id = "press", windup = 1.0, telegraph = "dodgeOnly", damage = 36, radius = 6.5, recover = 1.4, cooldown = 1.6, every = 7 },
		},
		phases = {
			{
				threshold = 0.5,
				name = "Переплёт",
				attackSpeedBonus = 0.15,
				sceneTime = 2.0,
				summon = { typeId = "ink_blot", count = 3 },
				attacks = {
					{ id = "threads", windup = 1.1, telegraph = "dodgeOnly", damage = 26, range = 18, lines = 3, lineLength = 18, lineWidth = 1.6,
						lineSpread = 25, root = 1.0, recover = 1.2, cooldown = 1.6, every = 6 },
				},
			},
		},
		rewards = { gold = 120, xp = 300, iron = 4 },
	},

	-- Босс этажа 5 — Главный хронист. Три фазы:
	--   I   100–66%: удар пером-клинком (белый), веер страниц, стирание (зоны → пятна 6 с)
	--   II   66–33%: «Печати» — неуязвим, пока стоят четыре печати (SEAL_*); все
	--               разбиты — оглушён 3 с; луч строки (линия 30 × 2,6)
	--   III ниже 33%: «Стирание» — края арены стираются, безопасный круг
	--               сжимается; «Переписать» (прыжок), два хранителя полок
	chief_chronicler = {
		id = "chief_chronicler",
		name = "Главный хронист",
		title = "Тот, кто записал всё",
		role = "boss",
		health = 2000,
		armor = 12,
		speed = 8,
		size = Vector3.new(6.4, 12.4, 4.0),
		lookAs = "gatekeeper",
		attacks = {
			{ id = "slash", windup = 0.85, telegraph = "parryable", damage = 40, range = 10, arc = 120, recover = 1.3, cooldown = 1.4, parryStun = 1.4 },
			{ id = "volley", windup = 0.9, aimLock = 0.7, telegraph = "parryable", damage = 16, range = 28, projectileSpeed = 50, projectileKind = "page",
				spread = 5, spreadAngle = 12, recover = 0.8, cooldown = 1.6 },
			{ id = "erase", windup = 1.0, telegraph = "zones", damage = 28, zones = 3, radius = 3.5,
				puddle = { kind = "erase", life = 6, radius = 3.5 }, recover = 1.1, cooldown = 1.6, every = 6 },
		},
		phases = {
			{
				threshold = 0.66,
				name = "Печати",
				attackSpeedBonus = 0.1,
				sceneTime = 2.4,
				seals = { typeId = "ward_seal", stun = 3.0 }, -- Floor5World: печати на SEAL_1..4
				attacks = {
					{ id = "beam", windup = 1.1, aimLock = 0.7, telegraph = "dodgeOnly", damage = 36, range = 30, beam = { length = 30, width = 2.6 },
						recover = 1.3, cooldown = 1.6, every = 6 },
				},
			},
			{
				threshold = 0.33,
				name = "Стирание",
				attackSpeedBonus = 0.25,
				sceneTime = 2.0,
				summon = { typeId = "shelf_warden", count = 2 },
				erasure = { startRadius = 30, endRadius = 11, shrinkTime = 30, damage = 6, tick = 0.5 }, -- Floor5World
				attacks = {
					{ id = "rewrite", windup = 1.1, telegraph = "dodgeOnly", damage = 48, radius = 7, leap = true, leapTime = 0.6,
						recover = 1.5, cooldown = 1.8, every = 7 },
				},
			},
		},
		rewards = { gold = 340, xp = 720, iron = 10, soul = true },
	},
}

-- Порядок для сборщиков и отчётов.
Enemies45.Floor4 = { "forge_automaton", "fire_spirit", "slag_thrower", "smolder", "elder_founder" }
Enemies45.Floor5 = { "stone_reader", "seal_mage", "ward_seal", "ink_scribe", "ink_blot", "shelf_warden", "bookbinder", "chief_chronicler" }

return Enemies45
