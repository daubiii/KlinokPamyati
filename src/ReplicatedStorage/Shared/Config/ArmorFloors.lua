--!nonstrict
-- ArmorFloors
-- Комплекты брони этажей 2–5 (06.11.2026). Воин и маг, на каждом этаже по
-- четыре редкости: обычный, редкий, эпический, легендарный. Секретной брони нет.
-- Подключает Config/Armor (здесь только данные).
--
-- Комплект — ОДИН предмет: шлем и доспех (шляпа и накидка) идут вместе.
-- Статы — на весь комплект. Пассивка — у эпических и легендарных.
--
-- Числа: база — комплекты этажа 1 той же редкости (Ржавого стража, Стражи
-- ворот, Теневого рыцаря, Привратника; у мага — Чтеца, Хрониста, Забвения,
-- Архивариуса) × множитель этажа. Броня и здоровье × 1,4 / 1,8 / 2,2 / 2,6,
-- мана × 1,25 / 1,5 / 1,75 / 2,0. Та же редкость на следующем этаже даёт
-- +20–40% брони и здоровья; легендарный прошлого этажа с ★ ещё держится
-- против обычного нового, поэтому ★ не обнуляется со сменой этажа.
--
-- passive.kind (логика — ArmorService):
--   afterDodge  — reduction на duration с после рывка;
--   afterParry  — reduction на duration с после парирования;
--   steadfast   — пока здоровье выше threshold, reduction;
--   lastStand   — пока здоровье ниже threshold, reduction;
--   regen       — через delay с без урона: percent макс. здоровья в секунду;
--   manaOnDodge — рывок возвращает amount маны;
--   manaWard    — пока маны больше threshold, reduction.
--
-- style — запасной облик из Part'ов (пока не импортированы меши этажа).

local Palette = require(script.Parent.Palette)

local Env = Palette.Env
local F = function(n)
	return Palette.Floors[n].colors
end

local ArmorFloors = {}

-- ===== облик-заглушка (до мешей) =====
local function warriorStyle(n: number, o)
	local c = F(n)
	return {
		steel = o.steel or c[2]:Lerp(Env.ironLight, 0.45),
		steelDark = o.steelDark or c[1],
		trim = o.trim or c[3],
		cloth = o.cloth or c[1]:Lerp(Env.clothDark, 0.3),
		clothLight = o.clothLight or c[2],
		leather = Env.woodDark,
		leatherLight = Env.wood,
		eye = Palette.Memory,
		accent = o.accent or c[3],
		sigil = o.sigil or "memory",
		helm = o.helm,
		chest = o.chest,
		cape = o.cape,
		pauldron = o.pauldron or 1.1,
	}
end

local function mageStyle(n: number, o)
	local c = F(n)
	local hat = o.hatColor or c[2]
	return {
		mage = true,
		hat = o.hat,
		hatHeight = o.hatHeight or 1.0,
		capeLength = o.capeLength or 1.4,
		hatColor = hat,
		band = o.band or c[3],
		mantle = o.mantle or c[2]:Lerp(c[1], 0.3),
		capeColor = o.cape or c[1],
		trim = o.trim or c[3],
		eye = Palette.Memory,
		glow = o.glow,
		cloth = o.mantle or c[2],
		clothLight = o.cape or c[1],
		leather = Env.woodDark,
		leatherLight = Env.wood,
		steelDark = o.band or c[3],
		accent = o.trim or c[3],
	}
end

-- ===== воин =====
ArmorFloors.Warrior = {
	-- Этаж 2 «Затопленные сады»
	{
		id = "gardener", name = "Садовника", title = "Доспехи садовника", rarity = "common", floor = 2,
		armor = 6, health = 18,
		pieces = { helm = "Соломенный шлем садовника", armor = "Кожаный фартук-латы" },
		style = warriorStyle(2, { helm = "open", chest = "riveted", cape = "short" }),
	},
	{
		id = "sluice_guard", name = "Шлюзового стража", title = "Доспехи шлюзового стража", rarity = "rare", floor = 2,
		armor = 8, health = 25,
		pieces = { helm = "Шлем шлюзового стража", armor = "Кираса со скобами шлюза" },
		style = warriorStyle(2, { helm = "kettle", chest = "plate", cape = "long", sigil = "gate" }),
	},
	{
		id = "thorn_knight", name = "Тернового рыцаря", title = "Доспехи тернового рыцаря", rarity = "epic", floor = 2,
		armor = 7, health = 31,
		pieces = { helm = "Терновый шлем", armor = "Латы в терновой лозе" },
		passive = { kind = "afterParry", reduction = 0.25, duration = 2.0, name = "Колючая стойка",
			description = "2 с после парирования −25% входящего урона" },
		style = warriorStyle(2, { helm = "horned", chest = "spiked", cape = "tattered", sigil = "shard", pauldron = 1.3 }),
	},
	{
		id = "rose_warden", name = "Розовой стражи", title = "Доспехи Розовой стражи", rarity = "legendary", floor = 2,
		armor = 8, health = 36,
		pieces = { helm = "Венец Розовой стражи", armor = "Мраморные латы в розах" },
		passive = { kind = "regen", delay = 4, percent = 0.015, name = "Цветение",
			description = "4 с без урона — восстанавливает 1,5% здоровья в секунду" },
		style = warriorStyle(2, { steel = Env.bone:Lerp(Env.stoneLight, 0.4), helm = "crown", chest = "tabard", cape = "long", sigil = "memory", pauldron = 1.4 }),
	},

	-- Этаж 3 «Псарни охоты»
	{
		id = "kennelman", name = "Псаря", title = "Доспехи псаря", rarity = "common", floor = 3,
		armor = 7, health = 23,
		pieces = { helm = "Кожаный капюшон псаря", armor = "Стёганка с ошейниками" },
		style = warriorStyle(3, { helm = "open", chest = "riveted", cape = "short" }),
	},
	{
		id = "huntsman", name = "Егеря", title = "Доспехи егеря", rarity = "rare", floor = 3,
		armor = 11, health = 32,
		pieces = { helm = "Шапель егеря", armor = "Бригантина егеря" },
		style = warriorStyle(3, { helm = "kettle", chest = "tabard", cape = "long", sigil = "anvil" }),
	},
	{
		id = "bear_hunter", name = "Медвежатника", title = "Доспехи медвежатника", rarity = "epic", floor = 3,
		armor = 9, health = 40,
		pieces = { helm = "Шлем с медвежьей пастью", armor = "Латы под медвежьей шкурой" },
		passive = { kind = "lastStand", threshold = 0.35, reduction = 0.2, name = "Медвежья шкура",
			description = "Пока здоровье ниже 35%, −20% входящего урона" },
		style = warriorStyle(3, { helm = "horned", chest = "spiked", cape = "tattered", sigil = "shard", pauldron = 1.4 }),
	},
	{
		id = "royal_hunt", name = "Королевского ловчего", title = "Доспехи Королевского ловчего", rarity = "legendary", floor = 3,
		armor = 11, health = 47,
		pieces = { helm = "Рогатый венец ловчего", armor = "Трофейные латы ловчего" },
		passive = { kind = "afterDodge", reduction = 0.3, duration = 1.0, name = "Гон",
			description = "1 с после рывка −30% входящего урона" },
		style = warriorStyle(3, { trim = Env.gold, helm = "crown", chest = "keyhole", cape = "long", sigil = "key", pauldron = 1.4 }),
	},

	-- Этаж 4 «Литейные»
	{
		id = "apprentice_smith", name = "Подмастерья", title = "Доспехи подмастерья", rarity = "common", floor = 4,
		armor = 9, health = 29,
		pieces = { helm = "Кожаный шлем с очками", armor = "Прожжённый фартук-латы" },
		style = warriorStyle(4, { helm = "open", chest = "riveted", cape = "none" }),
	},
	{
		id = "caster", name = "Литейщика", title = "Доспехи литейщика", rarity = "rare", floor = 4,
		armor = 13, health = 40,
		pieces = { helm = "Литой шлем-маска", armor = "Литая кираса" },
		style = warriorStyle(4, { helm = "kettle", chest = "plate", cape = "short", sigil = "anvil" }),
	},
	{
		id = "scale_knight", name = "Окалины", title = "Доспехи окалины", rarity = "epic", floor = 4,
		armor = 11, health = 48,
		pieces = { helm = "Шлем в окалине", armor = "Латы из закалённой окалины" },
		passive = { kind = "afterParry", reduction = 0.3, duration = 2.5, name = "Закалка",
			description = "2,5 с после парирования −30% входящего урона" },
		style = warriorStyle(4, { helm = "horned", chest = "spiked", cape = "tattered", sigil = "shard", pauldron = 1.3 }),
	},
	{
		id = "elder_founder", name = "Старшего литейщика", title = "Доспехи Старшего литейщика", rarity = "legendary", floor = 4,
		armor = 13, health = 57,
		pieces = { helm = "Венец-изложница", armor = "Раскалённые латы Основателя" },
		passive = { kind = "steadfast", threshold = 0.5, reduction = 0.12, name = "Литой доспех",
			description = "Пока здоровье выше 50%, −12% входящего урона" },
		style = warriorStyle(4, { trim = F(4)[4], helm = "crown", chest = "keyhole", cape = "long", sigil = "anvil", pauldron = 1.5 }),
	},

	-- Этаж 5 «Зал хроник»
	{
		id = "scribe", name = "Писца", title = "Доспехи писца", rarity = "common", floor = 5,
		armor = 10, health = 34,
		pieces = { helm = "Капюшон писца", armor = "Стёганка с пергаментом" },
		style = warriorStyle(5, { helm = "open", chest = "tabard", cape = "short" }),
	},
	{
		id = "binder", name = "Переплётчика", title = "Доспехи переплётчика", rarity = "rare", floor = 5,
		armor = 16, health = 47,
		pieces = { helm = "Шлем с застёжками", armor = "Латы-переплёт" },
		style = warriorStyle(5, { helm = "kettle", chest = "riveted", cape = "long", sigil = "gate" }),
	},
	{
		id = "seal_keeper", name = "Хранителя печати", title = "Доспехи хранителя печати", rarity = "epic", floor = 5,
		armor = 13, health = 57,
		pieces = { helm = "Шлем-печать", armor = "Латы с сургучом" },
		passive = { kind = "lastStand", threshold = 0.4, reduction = 0.22, name = "Опечатан",
			description = "Пока здоровье ниже 40%, −22% входящего урона" },
		style = warriorStyle(5, { helm = "horned", chest = "spiked", cape = "tattered", sigil = "shard", pauldron = 1.3 }),
	},
	{
		id = "chief_chronicler", name = "Главного хрониста", title = "Доспехи Главного хрониста", rarity = "legendary", floor = 5,
		armor = 16, health = 68,
		pieces = { helm = "Рунная корона хрониста", armor = "Латы последней главы" },
		passive = { kind = "afterDodge", reduction = 0.35, duration = 1.2, name = "Вычеркнутый удар",
			description = "1,2 с после рывка −35% входящего урона" },
		style = warriorStyle(5, { trim = F(5)[4], helm = "crown", chest = "keyhole", cape = "long", sigil = "memory", pauldron = 1.5 }),
	},
}

-- ===== маг =====
ArmorFloors.Mage = {
	-- Этаж 2
	{
		id = "herbalist", name = "Травника", title = "Облачение травника", rarity = "common", floor = 2,
		armor = 1, health = 13, mana = 40, manaRegen = 0.4,
		pieces = { helm = "Шляпа травника", armor = "Накидка травника" },
		style = mageStyle(2, { hat = "soft", hatHeight = 0.8, capeLength = 1.0 }),
	},
	{
		id = "dew", name = "Росы", title = "Облачение росы", rarity = "rare", floor = 2,
		armor = 3, health = 17, mana = 43, manaRegen = 2.0,
		pieces = { helm = "Шляпа росы", armor = "Накидка росы" },
		style = mageStyle(2, { hat = "tall", hatHeight = 1.1, capeLength = 1.3 }),
	},
	{
		id = "lotus", name = "Лотоса", title = "Облачение лотоса", rarity = "epic", floor = 2,
		armor = 4, health = 21, mana = 53, manaRegen = 1.0,
		pieces = { helm = "Шляпа-лотос", armor = "Мантия лотоса" },
		passive = { kind = "regen", delay = 4, percent = 0.012, name = "Цветение лотоса",
			description = "4 с без урона — восстанавливает 1,2% здоровья в секунду" },
		style = mageStyle(2, { hat = "star", hatHeight = 1.0, capeLength = 1.6, glow = F(2)[4] }),
	},
	{
		id = "gardener_mage", name = "Садовницы", title = "Облачение Садовницы", rarity = "legendary", floor = 2,
		armor = 6, health = 25, mana = 75, manaRegen = 1.8,
		pieces = { helm = "Венец-шляпа Садовницы", armor = "Мантия в розах" },
		passive = { kind = "manaWard", threshold = 0.4, reduction = 0.1, name = "Живая изгородь",
			description = "Пока маны больше 40%, −10% входящего урона" },
		style = mageStyle(2, { hat = "archive", hatHeight = 1.3, capeLength = 1.75, hatColor = Env.bone, glow = F(2)[4] }),
	},

	-- Этаж 3
	{
		id = "tracker", name = "Следопыта", title = "Облачение следопыта", rarity = "common", floor = 3,
		armor = 2, health = 16, mana = 48, manaRegen = 0.5,
		pieces = { helm = "Шляпа следопыта", armor = "Накидка следопыта" },
		style = mageStyle(3, { hat = "soft", hatHeight = 0.8, capeLength = 1.0 }),
	},
	{
		id = "moon_call", name = "Лунного зова", title = "Облачение лунного зова", rarity = "rare", floor = 3,
		armor = 4, health = 22, mana = 51, manaRegen = 2.4,
		pieces = { helm = "Шляпа лунного зова", armor = "Накидка лунного зова" },
		style = mageStyle(3, { hat = "tall", hatHeight = 1.1, capeLength = 1.3 }),
	},
	{
		id = "ghost_pack", name = "Призрачной стаи", title = "Облачение призрачной стаи", rarity = "epic", floor = 3,
		armor = 5, health = 27, mana = 63, manaRegen = 1.2,
		pieces = { helm = "Капюшон-волчья голова", armor = "Плащ призрачной стаи" },
		passive = { kind = "afterDodge", reduction = 0.25, duration = 1.0, name = "Призрачный шаг",
			description = "1 с после рывка −25% входящего урона" },
		style = mageStyle(3, { hat = "ragged", hatHeight = 0.9, capeLength = 1.75, glow = Palette.Memory }),
	},
	{
		id = "huntmaster", name = "Ловчего", title = "Облачение Ловчего", rarity = "legendary", floor = 3,
		armor = 7, health = 32, mana = 90, manaRegen = 2.1,
		pieces = { helm = "Рогатая шляпа Ловчего", armor = "Мантия королевской охоты" },
		passive = { kind = "lastStand", threshold = 0.4, reduction = 0.18, name = "Охотничья луна",
			description = "Пока здоровье ниже 40%, −18% входящего урона" },
		style = mageStyle(3, { hat = "archive", hatHeight = 1.3, capeLength = 1.75, trim = Env.gold, glow = F(3)[3] }),
	},

	-- Этаж 4
	{
		id = "stoker", name = "Кочегара", title = "Облачение кочегара", rarity = "common", floor = 4,
		armor = 2, health = 20, mana = 56, manaRegen = 0.5,
		pieces = { helm = "Шляпа кочегара", armor = "Прожжённая накидка" },
		style = mageStyle(4, { hat = "soft", hatHeight = 0.8, capeLength = 1.0 }),
	},
	{
		id = "bellows", name = "Мехов", title = "Облачение мехов", rarity = "rare", floor = 4,
		armor = 4, health = 26, mana = 60, manaRegen = 2.8,
		pieces = { helm = "Шляпа мехов", armor = "Накидка мехов" },
		style = mageStyle(4, { hat = "tall", hatHeight = 1.1, capeLength = 1.3 }),
	},
	{
		id = "crucible", name = "Тигля", title = "Облачение тигля", rarity = "epic", floor = 4,
		armor = 7, health = 33, mana = 74, manaRegen = 1.4,
		pieces = { helm = "Шляпа-тигель", armor = "Мантия жара" },
		passive = { kind = "manaOnDodge", amount = 18, name = "Мехи",
			description = "Рывок возвращает 18 маны" },
		style = mageStyle(4, { hat = "star", hatHeight = 1.0, capeLength = 1.6, glow = F(4)[3] }),
	},
	{
		id = "founder", name = "Основателя", title = "Облачение Основателя", rarity = "legendary", floor = 4,
		armor = 9, health = 40, mana = 105, manaRegen = 2.5,
		pieces = { helm = "Венец-шляпа Основателя", armor = "Мантия Великого горна" },
		passive = { kind = "regen", delay = 3, percent = 0.02, name = "Тепло горна",
			description = "3 с без урона — восстанавливает 2% здоровья в секунду" },
		style = mageStyle(4, { hat = "archive", hatHeight = 1.3, capeLength = 1.75, trim = F(4)[4], glow = F(4)[3] }),
	},

	-- Этаж 5
	{
		id = "copyist", name = "Переписчика", title = "Облачение переписчика", rarity = "common", floor = 5,
		armor = 3, health = 23, mana = 64, manaRegen = 0.6,
		pieces = { helm = "Шляпа переписчика", armor = "Накидка переписчика" },
		style = mageStyle(5, { hat = "soft", hatHeight = 0.8, capeLength = 1.0 }),
	},
	{
		id = "pages", name = "Страниц", title = "Облачение страниц", rarity = "rare", floor = 5,
		armor = 5, health = 31, mana = 68, manaRegen = 3.2,
		pieces = { helm = "Шляпа из страниц", armor = "Накидка из страниц" },
		style = mageStyle(5, { hat = "tall", hatHeight = 1.1, capeLength = 1.3 }),
	},
	{
		id = "clockkeeper", name = "Часовщика", title = "Облачение часовщика", rarity = "epic", floor = 5,
		armor = 8, health = 39, mana = 84, manaRegen = 1.6,
		pieces = { helm = "Шляпа с циферблатом", armor = "Мантия песочных часов" },
		passive = { kind = "afterDodge", reduction = 0.3, duration = 1.2, name = "Остановленный миг",
			description = "1,2 с после рывка −30% входящего урона" },
		style = mageStyle(5, { hat = "star", hatHeight = 1.0, capeLength = 1.6, glow = F(5)[4] }),
	},
	{
		id = "memory_scribe", name = "Летописца памяти", title = "Облачение Летописца памяти", rarity = "legendary", floor = 5,
		armor = 10, health = 47, mana = 120, manaRegen = 2.8,
		pieces = { helm = "Венец-шляпа Летописца", armor = "Мантия памяти" },
		passive = { kind = "manaWard", threshold = 0.5, reduction = 0.14, name = "Сноска",
			description = "Пока маны больше половины, −14% входящего урона" },
		style = mageStyle(5, { hat = "archive", hatHeight = 1.3, capeLength = 1.75, trim = F(5)[4], glow = Palette.Memory }),
	},
}

return ArmorFloors
