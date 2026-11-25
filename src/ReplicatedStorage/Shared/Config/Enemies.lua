--!nonstrict
-- Enemies
-- Пять врагов этажа 1 и босс — точно по приложению Е плана.
-- Числа здесь не придуманы: каждое взято из таблиц приложения Е и Б.
--
-- Формат атаки:
--   id         имя для отладки
--   windup     замах, секунды
--   telegraph  parryable (белая) | dodgeOnly (красная) | zones (зоны на земле)
--   damage     урон за попадание
--   hits       сколько попаданий в серии (у Тени два взмаха)
--   range      дальность ближнего удара
--   radius     радиус для атак по площади (центр — сам враг)
--   zones      сколько зон на земле (центры задаются в начале замаха)
--   dash       рывок в стадах перед ударом
--   dashTime   длительность рывка (не из плана: чтобы рывок был виден)
--   projectileSpeed  скорость снаряда
--   recover    пауза восстановления после удара (враг уязвим)
--   cooldown   минимум между НАЧАЛАМИ атак (интервал «между ударами»)
--   every      особая атака не чаще, чем раз в N секунд
--   diesOnAttack  враг погибает, нанеся удар (Треснувший)
--   parryStun  оглушение после удачного парирования (по умолчанию из Combat)
--   wallStun   оглушение при ударе рывком в стену
--
-- look — только для клиента: какой моделью рисовать и какими цветами
-- палитры. Сервер про внешний вид ничего не знает.

local Palette = require(script.Parent.Palette)
local Balance = require(script.Parent.Balance)

local Enemies = {}

local F1 = Palette.Floors[1].colors -- тёмный, ржавый, янтарный, костяной
local M = Palette.Material
local E = Palette.Env

-- Внешний вид — по спрайтам из assets (Voxel_pixel_art_sprite_*): ростом
-- враги теперь с игрока (R15 ≈ 5 стадов), босс вдвое выше. Цвета:
--   armor/armorDark — доспех, rust — ржавчина, cloth — ткань, void — пустота
--   внутри шлема, eye — свечение глаз, metal — оружие, trim — отделка,
--   glow — магма/руна/энергия.
local LOOK = {
	guard = {
		kind = "guard",
		armor = E.ironLight:Lerp(E.rust, 0.3),
		armorDark = E.iron:Lerp(E.rust, 0.35),
		rust = E.rust,
		cloth = E.clothDark,
		void = E.void,
		eye = E.ember,
		metal = E.ironLight:Lerp(E.bone, 0.3),
		trim = E.gold:Lerp(E.rust, 0.45),
		glow = E.ember,
	},
	shade = {
		kind = "shade",
		armor = E.void:Lerp(E.stoneDeep, 0.35),
		armorDark = E.void,
		rust = E.stoneDeep,
		cloth = E.void:Lerp(E.stoneDeep, 0.2),
		void = E.void,
		eye = M.bladeEdge,
		metal = E.void:Lerp(E.iron, 0.6),
		trim = M.bladeEdge,
		glow = M.bladeEdge,
	},
	knight = {
		kind = "knight",
		armor = E.iron:Lerp(E.ironLight, 0.35),
		armorDark = E.iron,
		rust = E.rust,
		cloth = E.clothDark,
		void = E.void,
		eye = E.ember,
		metal = E.ironLight,
		trim = E.rust:Lerp(E.gold, 0.3),
		glow = E.flame,
	},
	archer = {
		kind = "archer",
		armor = E.wood:Lerp(E.woodDark, 0.5),
		armorDark = E.woodDark,
		rust = E.wood,
		cloth = E.void:Lerp(E.stoneDeep, 0.45),
		void = E.void,
		eye = E.gold:Lerp(E.flameCore, 0.4),
		metal = E.woodLight,
		trim = E.stoneLight,
		glow = E.void:Lerp(Palette.UI.danger, 0.35),
	},
	martyr = {
		kind = "martyr",
		armor = E.stone,
		armorDark = E.stoneDark,
		rust = E.ironLight,
		cloth = E.stoneDeep,
		void = E.void,
		eye = E.flameCore,
		metal = E.iron,
		trim = E.flame,
		glow = E.flame,
	},
	gatekeeper = {
		kind = "gatekeeper",
		armor = E.ironLight:Lerp(E.rust, 0.35),
		armorDark = E.iron:Lerp(E.rust, 0.3),
		rust = E.rust,
		cloth = E.cloth,
		void = E.void,
		eye = E.gold:Lerp(E.flameCore, 0.5),
		metal = E.ironLight:Lerp(E.bone, 0.2),
		trim = E.gold,
		glow = E.gold:Lerp(E.flameCore, 0.5),
		horn = E.bone:Lerp(E.stoneLight, 0.4),
	},
}

Enemies.Difficulty = {
	normal = { id = "normal", name = "Обычный", damage = 1.0, health = 1.0, windup = 1.0 },
	abnormal = { id = "abnormal", name = "Ненормальный", damage = 1.55, health = 1.8, windup = 0.85 },
	impossible = { id = "impossible", name = "Невозможный", damage = 2.2, health = 3.0, windup = 0.7 },
}

Enemies.Types = {
	guard = {
		id = "guard",
		name = "Ржавый страж",
		role = "melee",
		health = 90,
		armor = 0,
		speed = 10,
		size = Vector3.new(2.6, 5.4, 1.4),
		look = LOOK.guard,
		attacks = {
			{ id = "slash", windup = 0.6, telegraph = "parryable", damage = 20, range = 6, recover = 0.8, cooldown = 1.2 },
		},
		rewards = { gold = 4, xp = 10, stacks = 1, ironChance = 0.25 },
	},

	shade = {
		id = "shade",
		name = "Тень",
		role = "melee",
		health = 60,
		armor = 0,
		speed = 19,
		size = Vector3.new(2.2, 4.6, 1.2),
		look = LOOK.shade,
		-- Бафф 28.10.2026 (Артём: «не опасны»): не ждёт очереди ближних,
		-- замах быстрее, рывок длиннее; направление рывка фиксируется на
		-- середине замаха и показано стрелкой (aimLock) — от него можно уйти.
		ignoreSlots = true,
		attacks = {
			{
				id = "dash_combo",
				windup = 0.35,
				aimLock = 0.3,
				telegraph = "parryable",
				damage = 14,
				hits = 2,
				dash = 9,
				dashTime = 0.16,
				range = 5,
				recover = 0.8,
				cooldown = 1.6,
			},
		},
		rewards = { gold = 3, xp = 8, stacks = 1, ironChance = 0.25 },
	},

	knight = {
		id = "knight",
		name = "Латник",
		role = "tank",
		health = 135,
		armor = 10,
		speed = 8,
		size = Vector3.new(3.2, 6.4, 1.8),
		look = LOOK.knight,
		attacks = {
			{ id = "shield", windup = 0.8, telegraph = "parryable", damage = 20, range = 7, recover = 1.0, cooldown = 1.4 },
			{
				id = "slam",
				windup = 1.0,
				telegraph = "dodgeOnly",
				damage = 30,
				radius = 4,
				recover = 1.5,
				cooldown = 1.4,
				every = 8,
			},
		},
		rewards = { gold = 8, xp = 20, stacks = 1, ironChance = 0.6 },
	},

	archer = {
		id = "archer",
		name = "Теневой стрелок",
		role = "ranged",
		health = 70,
		armor = 0,
		speed = 12,
		size = Vector3.new(2.2, 5.2, 1.2),
		-- Бафф 28.10.2026: дальше и чаще. Стреляет с любой дистанции до
		-- shotRange при чистой линии; прицел фиксируется на 55% замаха и
		-- показан линией — стрела летит по ней (уворот в сторону).
		keepMin = 14,
		keepMax = 26,
		shotRange = 38,
		look = LOOK.archer,
		attacks = {
			{
				id = "shot",
				windup = 0.75,
				aimLock = 0.55,
				telegraph = "parryable",
				damage = 16,
				projectileSpeed = 60,
				recover = 0.4,
				cooldown = 1.7,
			},
		},
		rewards = { gold = 5, xp = 12, stacks = 1, ironChance = 0.25 },
	},

	martyr = {
		id = "martyr",
		name = "Треснувший",
		role = "disruptor",
		health = 50,
		armor = 0,
		speed = 14,
		size = Vector3.new(2.4, 4.4, 1.4),
		-- Мартир запускает взрыв с дистанции 3 стада (приложение Е).
		triggerRange = 3,
		look = LOOK.martyr,
		attacks = {
			{
				id = "explode",
				windup = 1.2,
				telegraph = "dodgeOnly",
				damage = 40,
				radius = 10, -- было 4 (бафф 28.10.2026: ×2,5)
				range = 3,
				recover = 0.2,
				cooldown = 2.0,
				zones = 1,
				diesOnAttack = true,
			},
		},
		rewards = { gold = 4, xp = 10, stacks = 1, ironChance = 0.25 },
	},

	-- Босс этажа: три фазы (раздел 7: «2-3 фазы по порогам здоровья, каждая
	-- добавляет новую атаку»). Числа фазы I и II — из приложения Е, фаза III,
	-- выпад и прыжок добавлены при переработке босса (решение владельца:
	-- «стадии и атаки босса плохие, сделать красиво»).
	--   I   «Страж ворот»       100–60%: рубящий, выпад древком, разворот, цепи
	--   II  «Ярость стража»      60–30%: призыв двух стражей, +15% к скорости,
	--                                   рубящий становится двойным, таран, прыжок
	--   III «Последний рубеж»   ниже 30%: +30% к скорости, пять цепей вместо трёх,
	--                                   разворот шире
	gatekeeper = {
		id = "gatekeeper",
		name = "Привратник",
		title = "Страж ворот Хранилища",
		role = "boss",
		-- 1000 → 720 (−28%) по итогам плейтеста владельца 21.10.2026: босс
		-- проходился только с шестой попытки.
		health = 720,
		armor = 12,
		speed = 10,
		size = Vector3.new(6.0, 9.6, 3.2),
		look = LOOK.gatekeeper,
		attacks = {
			{
				id = "slash",
				windup = 0.8,
				telegraph = "parryable",
				damage = 50,
				range = 7,
				recover = 1.5,
				cooldown = 1.5,
				parryStun = 1.5,
			},
			{
				id = "thrust",
				windup = 0.65,
				telegraph = "parryable",
				damage = 35,
				range = 10,
				arc = 50, -- узкий выпад: уходят шагом в сторону
				recover = 1.1,
				cooldown = 1.4,
				parryStun = 1.2,
			},
			{ id = "spin", windup = 1.0, telegraph = "dodgeOnly", damage = 40, radius = 7, recover = 1.5, cooldown = 1.5 },
			{ id = "chains", windup = 1.0, telegraph = "zones", damage = 30, radius = 3, zones = 3, recover = 1.4, cooldown = 1.5 },
		},
		phases = {
			{
				threshold = 0.6,
				name = "Ярость стража",
				attackSpeedBonus = 0.15,
				sceneTime = 2.0, -- сцена входа в фазу (приложение Е)
				summon = { typeId = "guard", count = 2 },
				-- Рубящий удар становится двойным: два белых взмаха подряд.
				modify = { slash = { hits = 2 } },
				attacks = {
					{
						id = "charge",
						windup = 1.2,
						telegraph = "dodgeOnly",
						damage = 60,
						dash = 20,
						dashTime = 0.45,
						recover = 1.5,
						cooldown = 1.5,
						wallStun = 2.0,
					},
					{
						id = "leap",
						windup = 0.9,
						telegraph = "dodgeOnly",
						damage = 45,
						radius = 5.5,
						leap = true,
						leapTime = 0.55,
						recover = 1.3,
						cooldown = 1.6,
					},
				},
			},
			{
				threshold = 0.3,
				name = "Последний рубеж",
				attackSpeedBonus = 0.3,
				sceneTime = 1.6,
				modify = { chains = { zones = 5 }, spin = { radius = 9 } },
				attacks = {},
			},
		},
		rewards = { gold = 150, xp = 300, iron = 5, soul = true },
	},

	-- ===== Этаж 1 v2 =====
	-- Элитные (концепт v2: в ответвлении B, у Последних ворот и в отряде Сотника).
	-- Визуал — префаб базового врага крупнее (EnemyVisuals.prefab/scale).
	guard_elite = {
		id = "guard_elite",
		name = "Элитный страж",
		role = "melee",
		elite = true,
		health = 150,
		armor = 4,
		speed = 10,
		size = Vector3.new(2.8, 5.8, 1.5),
		look = LOOK.guard,
		attacks = {
			{ id = "slash", windup = 0.55, telegraph = "parryable", damage = 24, range = 6.5, recover = 0.8, cooldown = 1.1, hits = 2 },
		},
		rewards = { gold = 10, xp = 25, stacks = 2, ironChance = 0.6 },
	},
	knight_elite = {
		id = "knight_elite",
		name = "Элитный латник",
		role = "tank",
		elite = true,
		health = 220,
		armor = 14,
		speed = 8,
		size = Vector3.new(3.4, 6.8, 2.0),
		look = LOOK.knight,
		attacks = {
			{ id = "shield", windup = 0.75, telegraph = "parryable", damage = 24, range = 7, recover = 1.0, cooldown = 1.3 },
			{ id = "slam", windup = 1.0, telegraph = "dodgeOnly", damage = 34, radius = 4.5, recover = 1.4, cooldown = 1.4, every = 7 },
		},
		rewards = { gold = 14, xp = 35, stacks = 2, ironChance = 0.8 },
	},

	-- Мини-босс 1 — Сотник ворот (концепт v2, раздел 4). Логика — MiniBossService.
	--   «Стена щита»: урон спереди (120°) −85%, во II фазе −60%; парирование
	--   удара щитом — стойка сломана на 3 с, урон по нему ×1,5.
	--   Рог сбора на 70% и 35%: знамя в гнездо (цель 60 HP), отряд из решёток.
	centurion = {
		id = "centurion",
		name = "Сотник ворот",
		title = "Держащий строй",
		role = "miniboss",
		health = 450,
		armor = 10,
		speed = 9,
		size = Vector3.new(3.8, 7.6, 2.2),
		look = LOOK.knight,
		attacks = {
			{ id = "bash", windup = 0.8, telegraph = "parryable", damage = 26, range = 7, recover = 1.0, cooldown = 1.3, parryStun = 3.0 },
			{ id = "rush", windup = 1.0, telegraph = "dodgeOnly", damage = 32, dash = 14, dashTime = 0.42, recover = 0.9, cooldown = 1.6, line = 14 },
			{ id = "bannerSweep", windup = 1.1, telegraph = "dodgeOnly", damage = 34, radius = 7, recover = 1.3, cooldown = 1.6, needsBanner = true },
			{ id = "pick", windup = 0.7, telegraph = "parryable", damage = 30, range = 6.5, recover = 1.0, cooldown = 1.2, comboOnly = true },
		},
		phases = {
			{ threshold = 0.5, name = "Треснувший щит", attackSpeedBonus = 0.1, sceneTime = 1.4, attacks = {} },
		},
		miniboss = {
			shieldArc = 120,
			shieldBlock = 0.85,
			shieldBlockPhase2 = 0.6,
			brokenMultiplier = 1.5,
			brokenTime = 3.0,
			turnRate = 90, -- град/с, медленный разворот: заход за спину
			horns = { 0.7, 0.35 },
			hornTime = 2.0,
			bannerHealth = 60,
			auraRadius = 12,
			auraDamage = 1.25,
			lostFormation = 4.0, -- знамя срублено: замахи медленнее
			lostFormationWindup = 1.3,
			squad = { { "guard", "guard", "archer" }, { "guard", "guard", "archer", "guard_elite" } },
		},
		rewards = { gold = 45, xp = 120, iron = 3 },
	},

	-- Мини-босс 2 — Арбалетчица башни (концепт v2, раздел 5).
	--   Фаза «Подъём»: стреляет с площадки, пока игрок на пандусе; перезарядка
	--   воротом 2 с после каждого третьего выстрела. Фаза «Площадка»: игрок
	--   наверху, решётка пандуса закрыта, ближний бой; на 25% — «Последний болт».
	arbalest = {
		id = "arbalest",
		name = "Арбалетчица башни",
		title = "Часовая северной стены",
		role = "miniboss",
		health = 380,
		armor = 4,
		speed = 12,
		size = Vector3.new(2.6, 6.6, 1.4),
		look = LOOK.archer,
		sight = 120,
		anyLevel = true,
		attacks = {
			-- фаза «Подъём»
			{ id = "aimedBolt", originOut = 3.6, windup = 1.0, telegraph = "parryable", damage = 22, projectileSpeed = 55, projectileKind = "bolt",
				reflectPct = 0.08, reflectStun = 1.5, recover = 0.4, cooldown = 1.6, ranged = true, phase = "climb" },
			{ id = "volley", windup = 1.3, telegraph = "zones", damage = 20, radius = 3, zones = 4, recover = 0.6, cooldown = 2.2,
				ignoreBounds = true, ranged = true, phase = "climb" },
			{ id = "chainBolt", originOut = 3.6, windup = 1.0, telegraph = "dodgeOnly", damage = 15, projectileSpeed = 60, projectileKind = "chainBolt",
				recover = 0.5, cooldown = 6, every = 9, ranged = true, phase = "climb", line = 30 },
			-- фаза «Площадка»
			{ id = "stock", windup = 0.6, telegraph = "parryable", damage = 20, range = 6, recover = 0.8, cooldown = 1.1, phase = "top" },
			{ id = "leapShot", windup = 0.8, telegraph = "dodgeOnly", damage = 28, projectileSpeed = 70, projectileKind = "bolt",
				recover = 0.9, cooldown = 2.0, phase = "top", backstep = 6, line = 24 },
			{ id = "traps", windup = 0.9, telegraph = "zones", damage = 8, radius = 2, zones = 3, recover = 0.7, cooldown = 2.4,
				every = 10, phase = "top", trap = true },
			{ id = "lastBolt", windup = 2.0, telegraph = "parryable", damagePct = 0.7, projectileSpeed = 80, projectileKind = "lastBolt",
				reflectPct = 0.15, reflectStun = 2.5, interruptible = true, interruptStun = 2.5, recover = 1.2, cooldown = 2.0,
				phase = "top", once = 0.25, line = 40 },
		},
		miniboss = {
			reloadEvery = 3,
			reloadTime = 2.0,
			chainHealth = 20,
			chainTime = 4.0,
			trapRoot = 1.0,
			trapLife = 8.0,
		},
		rewards = { gold = 45, xp = 120, iron = 3 },
	},

	-- Объекты-цели: без ИИ, только здоровье (знамя, цепь, баррикада). Вид
	-- рисует MiniBossFx; полоски — EnemyBarsController по атрибутам.
	banner = {
		id = "banner", name = "Знамя ворот", role = "object", health = 60, armor = 0, speed = 0,
		size = Vector3.new(2.0, 9.0, 2.0), attacks = {}, rewards = { gold = 0, xp = 10, stacks = 0 },
	},
	chainpost = {
		id = "chainpost", name = "Цепной болт", role = "object", health = 20, armor = 0, speed = 0,
		size = Vector3.new(6.0, 3.0, 1.2), attacks = {}, rewards = { gold = 0, xp = 0, stacks = 0 },
	},
	-- Подпора насеста Арбалетчицы (двор башни): сломать — насест рухнет.
	perchpost = {
		id = "perchpost", name = "Подпора насеста", role = "object", health = 80, armor = 0, speed = 0,
		size = Vector3.new(2.2, 7.6, 2.2), attacks = {}, rewards = { gold = 0, xp = 10, stacks = 0 },
	},
	barricade = {
		id = "barricade", name = "Баррикада", role = "object", health = 30, armor = 0, speed = 0,
		size = Vector3.new(4.0, 3.0, 2.0), attacks = {}, rewards = { gold = 0, xp = 0, stacks = 0 },
	},

	-- Этаж 2: заросшая стена перед секретом (разбить — откроется проход).
	overgrowth = {
		id = "overgrowth", name = "Заросшая стена", role = "object", health = 45, armor = 0, speed = 0,
		size = Vector3.new(10.0, 8.0, 3.0), attacks = {}, rewards = { gold = 0, xp = 5, stacks = 0 },
	},
	f3wall = {
		id = "f3wall", name = "Ветхая стена", role = "object", health = 40, armor = 0, speed = 0,
		size = Vector3.new(6.0, 8.0, 6.0), attacks = {}, rewards = { gold = 0, xp = 5, stacks = 0 },
	},
	-- ===== Этаж 2 «Затопленные сады» (28.10.2026, согласовано с Артёмом) =====
	-- Модели — генерации Артёма, пересобранные в воксели 0,1 стада на своих
	-- суставах (EnemyPrefabs.<id>, сборщик AssembleEnemies2). Особое поведение
	-- (кора, корни, лужи, полив, шипы веером, камуфляж, Садовница) — в
	-- Systems/Floor2Service через хуки врага; числа — здесь, в traits и атаках.
	--   root      обездвиживание игрока при попадании, с
	--   puddle    лужа после удара: kind = "mud" (замедление) | "rot" (гниль, яд)
	--   cone/length/channel — полив: конус (градусы), длина, сколько секунд льёт
	--   spread/spreadAngle  — веер снарядов: сколько и угол между ними

	-- Древесный страж — танк. Кора спереди режет урон вдвое: бить сбоку и со спины.
	treant = {
		id = "treant",
		name = "Древесный страж",
		role = "tank",
		health = 210,
		armor = 12,
		speed = 7,
		size = Vector3.new(4.4, 7.0, 2.4),
		look = LOOK.knight, -- запасной кубический риг, если префаба нет
		traits = { barkArc = 120, barkBlock = 0.5 },
		attacks = {
			{ id = "smash", windup = 0.9, telegraph = "parryable", damage = 28, range = 7.5, recover = 1.1, cooldown = 1.5 },
			-- «Корни»: круг под игроком в начале замаха, попал — обездвижен.
			{ id = "roots", windup = 1.1, telegraph = "zones", damage = 14, radius = 2.6, zones = 1, root = 1.2, recover = 1.0, cooldown = 1.6, every = 7 },
		},
		rewards = { gold = 12, xp = 30, stacks = 2, ironChance = 0.4 },
	},

	-- Пчела-страж — быстрый ближний, парит. Жало — рывок (только уклон),
	-- после него 1,2 с «застревает»: окно для удара.
	bee = {
		id = "bee",
		name = "Пчела-страж",
		role = "melee",
		health = 80,
		armor = 0,
		speed = 17,
		size = Vector3.new(2.6, 5.0, 1.6),
		ignoreSlots = true,
		look = LOOK.shade,
		traits = { hover = 0.6 },
		attacks = {
			{ id = "sting", windup = 0.55, aimLock = 0.5, telegraph = "dodgeOnly", damage = 22, dash = 11, dashTime = 0.18, range = 5, recover = 1.2, cooldown = 1.8 },
			{ id = "claws", windup = 0.45, telegraph = "parryable", damage = 12, hits = 2, range = 5, recover = 0.7, cooldown = 1.2 },
		},
		rewards = { gold = 5, xp = 14, stacks = 1, ironChance = 0.2 },
	},

	-- Утопленник — ближний. Бросок тины (лужа, замедление); умирая, оставляет лужу.
	drowned = {
		id = "drowned",
		name = "Утопленник",
		role = "melee",
		health = 160,
		armor = 4,
		speed = 8,
		size = Vector3.new(3.4, 6.0, 2.0),
		look = LOOK.knight,
		traits = { deathPuddle = { kind = "mud", radius = 3.5, life = 6 } },
		attacks = {
			{ id = "pound", windup = 0.85, telegraph = "parryable", damage = 30, range = 6.5, recover = 1.0, cooldown = 1.4 },
			{ id = "mudThrow", windup = 0.9, telegraph = "zones", damage = 8, radius = 3, zones = 1, puddle = { kind = "mud", life = 5 },
				recover = 0.8, cooldown = 1.6, every = 6 },
		},
		rewards = { gold = 8, xp = 20, stacks = 1, ironChance = 0.3 },
	},

	-- Садовник — мешающий. «Полив гнилью»: конус 3 с (гниль, пока стоишь в
	-- нём) и лужи гнили по линии; вблизи — удар лейкой.
	gardener = {
		id = "gardener",
		name = "Садовник",
		role = "disruptor",
		health = 110,
		armor = 2,
		speed = 9,
		size = Vector3.new(3.0, 5.4, 2.0),
		look = LOOK.guard,
		attacks = {
			{ id = "pour", windup = 0.8, telegraph = "dodgeOnly", damage = 0, range = 8, cone = 70, length = 9, channel = 3.0,
				poison = 0.04, poisonTime = 2.5, puddles = 3, puddle = { kind = "rot", life = 6, radius = 2.2 },
				recover = 0.9, cooldown = 2.0, every = 7 },
			{ id = "canBash", windup = 0.6, telegraph = "parryable", damage = 18, range = 5.5, recover = 0.8, cooldown = 1.2 },
		},
		rewards = { gold = 7, xp = 18, stacks = 1, ironChance = 0.25 },
	},

	-- Моховой следопыт — дальний. Три шипа веером из ладони (отбиваются
	-- парированием), отскок от игрока, стоя на месте — сливается с травой.
	ranger = {
		id = "ranger",
		name = "Моховой следопыт",
		role = "ranged",
		health = 70,
		armor = 0,
		speed = 12,
		size = Vector3.new(2.4, 5.4, 1.4),
		keepMin = 12,
		keepMax = 22,
		shotRange = 34,
		look = LOOK.archer,
		traits = { camo = { after = 1.5, transparency = 0.7 }, hop = { range = 6, distance = 7, time = 0.3, cooldown = 4 } },
		attacks = {
			{ id = "thorns", windup = 0.8, aimLock = 0.6, telegraph = "parryable", damage = 12, projectileSpeed = 55, projectileKind = "thorn",
				spread = 3, spreadAngle = 12, recover = 0.5, cooldown = 2.0 },
		},
		rewards = { gold = 6, xp = 16, stacks = 1, ironChance = 0.25 },
	},

	-- Босс этажа 2 — Садовница, «ожившая статуя» (решение Артёма). Три фазы:
	--   I   100–60%: удар лозой (белый), терновый круг (красный), залп роз (отбиваются)
	--   II   60–30%: «Трещины мрамора» — светящиеся трещины, два садовника,
	--               корни тремя линиями к игроку (обездвиживают)
	--   III ниже 30%: «Цветение» — гниль по краям арены, безопасный круг
	--               сжимается; таран статуи (в колонну — оглушена 2 с)
	rosewarden = {
		id = "rosewarden",
		name = "Садовница",
		title = "Хозяйка Затопленных садов",
		role = "boss",
		health = 1100,
		armor = 10,
		speed = 9,
		size = Vector3.new(5.0, 10.0, 2.8),
		look = LOOK.gatekeeper,
		attacks = {
			{ id = "lash", windup = 0.8, telegraph = "parryable", damage = 40, range = 9, arc = 120, recover = 1.3, cooldown = 1.4, parryStun = 1.5 },
			{ id = "thornRing", windup = 1.0, telegraph = "dodgeOnly", damage = 35, radius = 6, recover = 1.4, cooldown = 1.5 },
			{ id = "roseVolley", windup = 0.9, aimLock = 0.7, telegraph = "parryable", damage = 18, range = 26, projectileSpeed = 50,
				projectileKind = "rose", spread = 3, spreadAngle = 15, recover = 0.8, cooldown = 1.6 },
		},
		phases = {
			{
				threshold = 0.6,
				name = "Трещины мрамора",
				attackSpeedBonus = 0.1,
				sceneTime = 2.0,
				summon = { typeId = "gardener", count = 2 },
				attacks = {
					{ id = "rootLines", windup = 1.1, telegraph = "dodgeOnly", damage = 32, range = 18, lines = 3, lineLength = 18, lineWidth = 1.6,
						lineSpread = 25, root = 1.0, recover = 1.2, cooldown = 1.6 },
				},
			},
			{
				threshold = 0.3,
				name = "Цветение",
				attackSpeedBonus = 0.25,
				sceneTime = 1.8,
				bloom = { startRadius = 16, endRadius = 7, shrinkTime = 25, poison = 0.05 },
				attacks = {
					{ id = "ram", windup = 1.2, telegraph = "dodgeOnly", damage = 55, dash = 20, dashTime = 0.5, recover = 1.4, cooldown = 1.6, wallStun = 2.0 },
				},
			},
		},
		rewards = { gold = 200, xp = 420, iron = 6, soul = true },
	},
}

-- Элитные враги (ТЗ врагов, раздел 2.5): на этаже 1 выключены. Числа
-- свойств — при балансе этажа 2.
Enemies.Elite = {
	enabledFromFloor = 2, -- (доп.)
}

-- Общие правила поведения (приложение Е).
Enemies.Behavior = {
	spawnAssemble = 1.0, -- сборка из кубиков
	spawnGrace = 1.0, -- первые секунды не атакуют
	maxMeleeAttackers = 2, -- одновременно бьют не больше двух ближних
	circleMin = 6, -- остальные кружат на 6-8 стадах
	circleMax = 8,
	wavePause = 2.0, -- пауза между волнами
	entryGrace = 0.5, -- после входа можно осмотреться
	bossIntro = 4.2, -- сцена появления босса (раздел 7): секунды без боя
}

-- Награда с опытом этажа и сложности (золото и стаки — как в таблице типа).
local function scaledRewards(rewards, scale, difficultyId: string)
	if not rewards then
		return nil
	end
	local copy = table.clone(rewards)
	if copy.xp then
		copy.xp = math.floor(copy.xp * (scale.xp or 1) * (Balance.DifficultyXp[difficultyId] or 1) + 0.5)
	end
	return copy
end

function Enemies.difficulty(difficultyId: string?)
	return Enemies.Difficulty[difficultyId or "normal"] or Enemies.Difficulty.normal
end

-- Итоговые статы врага: числа из таблицы → эталон этажа (Config/Balance) →
-- множители сложности.
function Enemies.stats(typeId: string, difficultyId: string?)
	local enemyType = Enemies.Types[typeId]
	assert(enemyType, "Enemies: неизвестный тип '" .. tostring(typeId) .. "'")
	local difficulty = Enemies.difficulty(difficultyId)
	local scale = Balance.scale(typeId, enemyType)

	local function scaleAttack(attack)
		local copy = table.clone(attack)
		-- damagePct (доля здоровья игрока) не масштабируется: у таких атак damage нет.
		copy.damage = attack.damage and Balance.attackDamage(attack.damage, scale) * difficulty.damage
		copy.windup = attack.windup * difficulty.windup
		return copy
	end

	local attacks = {}
	for _, attack in ipairs(enemyType.attacks) do
		table.insert(attacks, scaleAttack(attack))
	end

	-- Фазы босса (по убыванию порога). phase2 — первая из них, старое имя.
	local phases = {}
	for _, phase in ipairs(enemyType.phases or {}) do
		local copy = table.clone(phase)
		copy.attacks = {}
		for _, attack in ipairs(phase.attacks or {}) do
			table.insert(copy.attacks, scaleAttack(attack))
		end
		table.insert(phases, copy)
	end
	local phase2 = phases[1]

	local stats = {
		typeId = enemyType.id,
		name = enemyType.name,
		role = enemyType.role,
		isBoss = enemyType.role == "boss" or enemyType.role == "miniboss",
		isMiniBoss = enemyType.role == "miniboss",
		elite = enemyType.elite == true,
		sight = enemyType.sight,
		anyLevel = enemyType.anyLevel,
		miniboss = enemyType.miniboss,
		health = scale.health * difficulty.health,
		maxHealth = scale.health * difficulty.health,
		armor = scale.armor,
		floor = scale.floor,
		speed = enemyType.speed,
		size = enemyType.size,
		radius = math.max(enemyType.size.X, enemyType.size.Z) * 0.5,
		height = enemyType.size.Y,
		keepMin = enemyType.keepMin,
		keepMax = enemyType.keepMax,
		triggerRange = enemyType.triggerRange,
		look = enemyType.look,
		attacks = attacks,
		phase2 = phase2,
		phases = phases,
		title = enemyType.title,
		rewards = scaledRewards(enemyType.rewards, scale, difficulty.id),
		difficulty = difficulty.id,
	}
	-- Свои поля типа (ignoreSlots, shotRange, traits этажа 2…) переносятся как
	-- есть. Раньше копировались только перечисленные выше, и баффы Тени
	-- (ignoreSlots) и стрелка (shotRange) до сервера не доходили.
	for key, value in pairs(enemyType) do
		if stats[key] == nil and key ~= "attacks" and key ~= "phases" and key ~= "health" and key ~= "rewards" then
			stats[key] = value
		end
	end
	return stats
end

-- Этажи 4–5: сохранить базовые типы и добавить новые без замены таблицы.
do
	local Enemies45 = require(script.Parent.Enemies45)
	for id, enemyType in pairs(Enemies45.Types) do
		if enemyType.look == nil and enemyType.lookAs then
			enemyType.look = LOOK[enemyType.lookAs]
		end
		Enemies.Types[id] = enemyType
	end
end

-- Этаж 3 «Псарни охоты»: поведение врагов — Floor3EnemyService.
do
	local Enemies3 = require(script.Parent.Enemies3)
	for id, enemyType in pairs(Enemies3.Types) do
		if enemyType.look == nil and enemyType.lookAs then
			enemyType.look = LOOK[enemyType.lookAs]
		end
		Enemies.Types[id] = enemyType
	end
	Enemies.Replaces3 = Enemies3.Replaces
end

-- Фирменные атаки боссов (Config/BossMoves): по две на босса, в нужные фазы.
require(script.Parent.BossMoves).inject(Enemies.Types)

Enemies.LOOK = LOOK

return Enemies
