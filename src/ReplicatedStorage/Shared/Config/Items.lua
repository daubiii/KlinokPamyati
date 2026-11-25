--!nonstrict
-- Items
-- Сумка героя: припасы, материалы, ценное и аксессуары (амулеты и кольца).
-- Оружие и броня живут в своих системах (EchoService / ArmorService) —
-- здесь только то, что лежит в сумке стопками или надевается в слоты
-- «Амулет» и «Кольцо». Только числа и подписи: логика — в
-- ServerScriptService/Systems/InventoryService, окно — Windows/CharacterWindow.
--
-- icon — имя куска бумажного атласа (Config/PaperAtlas, префикс it_ / itL_):
-- иконка 16×16 в сетке, крупная 48×48 (если есть itL_<имя>) в карточке.
--
-- use.kind:
--   "heal"   — сразу вернуть percent от макс. здоровья;
--   "regen"  — вернуть percent за seconds (тиками по 0,5 с);
--   "charge" — +1 заряд лечения (не выше Combat.Heal.charges);
--   "armor"  — временная броня amount на seconds (как у души «Ржавая стойка»);
--   "damage" — +amount к урону ближнего боя на seconds;
--   "xp"     — опыт amount.
-- group — общий откат: «зелья» и «еда» не пьются/едятся подряд.

local Items = {}

Items.MaxStack = 99

-- Вкладки сумки (порядок — как в окне).
Items.Categories = {
	{ id = "all", name = "Всё", icon = "it_star" },
	{ id = "weapons", name = "Оружие", icon = "it_sword" },
	{ id = "armor", name = "Броня", icon = "eqIron_chest" },
	{ id = "accessories", name = "Аксессуары", icon = "it_amulet" },
	{ id = "consumables", name = "Припасы", icon = "it_potionRed" },
	{ id = "materials", name = "Материалы", icon = "it_ingot" },
	{ id = "souls", name = "Души", icon = "it_soul" },
	{ id = "valuables", name = "Ценное", icon = "it_bookGreen" },
}

-- Откаты групп, секунды.
Items.Cooldowns = { potion = 6, food = 3, buff = 1, book = 1 }

Items.List = {
	-- ===== припасы =====
	healing_draught = {
		name = "Настой памяти", category = "consumables", icon = "it_potionRed", rarityId = "common",
		desc = "Горький, но честный. Возвращает 30% здоровья сразу.",
		use = { kind = "heal", percent = 0.30 }, group = "potion",
	},
	strong_draught = {
		name = "Крепкий настой", category = "consumables", icon = "it_potionGold", rarityId = "epic",
		desc = "Им отпаивали стражей после осады. Возвращает 60% здоровья.",
		use = { kind = "heal", percent = 0.60 }, group = "potion",
	},
	echo_tonic = {
		name = "Отвар эха", category = "consumables", icon = "it_potionBlue", rarityId = "rare",
		desc = "Наполняет пустую флягу: +1 заряд лечения (до полного запаса).",
		use = { kind = "charge", amount = 1 }, group = "potion",
	},
	wardroot_brew = {
		name = "Настой корня", category = "consumables", icon = "it_potionGreen", rarityId = "rare",
		desc = "Кожа грубеет, как кора: +6 брони на 30 секунд.",
		use = { kind = "armor", amount = 6, seconds = 30 }, group = "buff",
	},
	honey_candy = {
		name = "Медовый леденец", category = "consumables", icon = "it_candy", rarityId = "rare",
		desc = "Сладость придаёт злости: +12% урона ближнего боя на 30 секунд.",
		use = { kind = "damage", amount = 0.12, seconds = 30 }, group = "buff",
	},
	roast_meat = {
		name = "Жареное мясо", category = "consumables", icon = "it_meat", rarityId = "common",
		desc = "Сытно. Возвращает 40% здоровья за 10 секунд.",
		use = { kind = "regen", percent = 0.40, seconds = 10 }, group = "food",
	},
	bread = {
		name = "Хлеб долины", category = "consumables", icon = "it_bread", rarityId = "common",
		desc = "Испечён в Долине Последнего Эха. Возвращает 25% здоровья за 8 секунд.",
		use = { kind = "regen", percent = 0.25, seconds = 8 }, group = "food",
	},
	river_fish = {
		name = "Речная рыба", category = "consumables", icon = "it_fish", rarityId = "common",
		desc = "Возвращает 20% здоровья за 6 секунд.",
		use = { kind = "regen", percent = 0.20, seconds = 6 }, group = "food",
	},
	egg = {
		name = "Печёное яйцо", category = "consumables", icon = "it_egg", rarityId = "common",
		desc = "Быстрый перекус: 10% здоровья сразу.",
		use = { kind = "heal", percent = 0.10 }, group = "food",
	},

	-- ===== ценное =====
	seeker_notes = {
		name = "Записки искателя", category = "valuables", icon = "it_bookBlue", rarityId = "rare",
		desc = "Чужой опыт тоже опыт. Прочитать: +120 опыта.",
		use = { kind = "xp", amount = 120 }, group = "book",
	},
	old_chronicle = {
		name = "Старая летопись", category = "valuables", icon = "it_bookRed", rarityId = "epic",
		desc = "Страницы помнят больше, чем люди. Прочитать: +300 опыта.",
		use = { kind = "xp", amount = 300 }, group = "book",
	},
	star_shard = {
		name = "Звёздный осколок", category = "valuables", icon = "it_star", rarityId = "legendary",
		desc = "Упавший кусочек памяти мира. Прочитать нельзя — только сжать в кулаке: +600 опыта.",
		use = { kind = "xp", amount = 600 }, group = "book",
	},

	-- ===== материалы (счётчики profile.materials, а не сумка) =====
	rusty_iron = {
		name = "Ржавое железо", category = "materials", icon = "it_ingot", rarityId = "common",
		desc = "Сундуки и стражи Привратного двора. Кузнец куёт из него броню двора.",
	},
	swamp_reed = {
		name = "Болотный тростник", category = "materials", icon = "it_leaf", rarityId = "common",
		desc = "Растёт у шлюзов Затопленных садов. Кузнец плетёт из него броню садов.",
	},
	tanned_hide = {
		name = "Дублёная шкура", category = "materials", icon = "it_feather", rarityId = "common",
		desc = "Из дубилен Псарен охоты. Кузнец кроит из неё броню псарей.",
	},
	cast_bronze = {
		name = "Литая бронза", category = "materials", icon = "it_goldOre", rarityId = "common",
		desc = "Остывшие слитки Литейных. Кузнец перековывает ими броню литейщиков.",
	},
	memory_ink = {
		name = "Чернила памяти", category = "materials", icon = "it_potionBlue", rarityId = "common",
		desc = "Чернила Зала хроник. Кузнец вписывает ими силу в броню хронистов.",
	},
}

-- Аксессуары: надеваются в слоты amulet / ring. stats: health, armor —
-- плоские; damage — доля к урону ближнего боя.
Items.Accessories = {
	wanderer_charm = { name = "Оберег странника", slot = "amulet", rarityId = "common", icon = "it_amuletSilver",
		stats = { health = 10 }, desc = "Нитка, камешек и чья-то молитва." },
	rust_locket = { name = "Ржавый медальон", slot = "amulet", rarityId = "rare", icon = "it_amuletSilver",
		stats = { health = 12, armor = 3 }, desc = "Снят со стража, который его так и не открыл." },
	memory_locket = { name = "Медальон памяти", slot = "amulet", rarityId = "epic", icon = "it_amulet",
		stats = { health = 18, damage = 0.06 }, desc = "Внутри — портрет, который меняется, если долго не смотреть." },
	gatekeeper_seal = { name = "Печать Привратника", slot = "amulet", rarityId = "legendary", icon = "it_amuletRed",
		stats = { armor = 4, damage = 0.10 }, desc = "Тяжёлая. Ворота за ней всё ещё заперты." },
	copper_ring = { name = "Медное кольцо", slot = "ring", rarityId = "common", icon = "it_ringSilver",
		stats = { damage = 0.03 }, desc = "Позеленело, но держится." },
	gardener_ring = { name = "Кольцо садовницы", slot = "ring", rarityId = "rare", icon = "it_ringSilver",
		stats = { health = 22 }, desc = "Пахнет розами и сырой землёй." },
	ember_ring = { name = "Кольцо углей", slot = "ring", rarityId = "epic", icon = "it_ringRed",
		stats = { armor = 2, damage = 0.07 }, desc = "Тёплое даже в снегу." },
	echo_band = { name = "Обод эха", slot = "ring", rarityId = "legendary", icon = "it_ring",
		stats = { health = 25, damage = 0.09 }, desc = "Если прислушаться, в нём звучит твой первый удар." },
}

Items.AccessorySlots = {
	{ id = "amulet", name = "Амулет" },
	{ id = "ring", name = "Кольцо" },
}

-- Разобрать аксессуар → пыль эха.
Items.SalvageDust = { common = 2, rare = 5, epic = 12, legendary = 30, mythic = 60, secret = 60 }

-- Стартовый мешок нового профиля (и старых сохранений без сумки).
Items.StarterBag = { healing_draught = 3, bread = 2 }
Items.StarterQuick = "healing_draught"

-- Сундук: припасы сверх оружия и брони.
Items.Chest = {
	rolls = { 1, 2 }, -- обычный сундук: 1–2 стопки
	bossRolls = { 2, 3 },
	table = {
		{ id = "healing_draught", weight = 30, count = { 1, 2 } },
		{ id = "bread", weight = 16, count = { 1, 2 } },
		{ id = "egg", weight = 12, count = { 1, 3 } },
		{ id = "river_fish", weight = 12, count = { 1, 2 } },
		{ id = "roast_meat", weight = 9, count = { 1, 1 } },
		{ id = "honey_candy", weight = 7, count = { 1, 1 } },
		{ id = "wardroot_brew", weight = 6, count = { 1, 1 } },
		{ id = "echo_tonic", weight = 6, count = { 1, 1 } },
		{ id = "seeker_notes", weight = 5, count = { 1, 1 } },
		{ id = "strong_draught", weight = 3, count = { 1, 1 } },
		{ id = "old_chronicle", weight = 2, count = { 1, 1 } },
		{ id = "star_shard", weight = 1, count = { 1, 1 } },
	},
	accessoryChance = 0.08,
	bossAccessoryChance = 0.40,
	-- Веса редкости аксессуара: этаж → редкость → вес (глубже — щедрее).
	accessoryRarity = {
		[1] = { common = 62, rare = 30, epic = 7, legendary = 1 },
		[2] = { common = 45, rare = 38, epic = 14, legendary = 3 },
		[3] = { common = 30, rare = 42, epic = 22, legendary = 6 },
		[4] = { common = 20, rare = 40, epic = 30, legendary = 10 },
		[5] = { common = 12, rare = 36, epic = 36, legendary = 16 },
	},
}

for id, item in pairs(Items.List) do
	item.id = id
end
for id, acc in pairs(Items.Accessories) do
	acc.id = id
	acc.category = "accessories"
end

function Items.get(id: string)
	return Items.List[id]
end

function Items.accessory(id: string)
	return Items.Accessories[id]
end

-- Подпись к статам аксессуара: «+12 здоровья · +3 брони · +6% урона».
function Items.statsText(stats): string
	local parts = {}
	if stats.health and stats.health ~= 0 then
		table.insert(parts, ("+%d здоровья"):format(stats.health))
	end
	if stats.armor and stats.armor ~= 0 then
		table.insert(parts, ("+%d брони"):format(stats.armor))
	end
	if stats.damage and stats.damage ~= 0 then
		table.insert(parts, ("+%d%% урона"):format(math.floor(stats.damage * 100 + 0.5)))
	end
	return table.concat(parts, " · ")
end

-- Короткое описание действия припаса для карточки.
function Items.useText(use): string?
	if not use then
		return nil
	end
	if use.kind == "heal" then
		return ("Лечение: %d%% здоровья сразу"):format(math.floor(use.percent * 100 + 0.5))
	elseif use.kind == "regen" then
		return ("Лечение: %d%% за %d с"):format(math.floor(use.percent * 100 + 0.5), use.seconds)
	elseif use.kind == "charge" then
		return ("Заряды лечения: +%d"):format(use.amount or 1)
	elseif use.kind == "armor" then
		return ("Броня: +%d на %d с"):format(use.amount, use.seconds)
	elseif use.kind == "damage" then
		return ("Урон: +%d%% на %d с"):format(math.floor(use.amount * 100 + 0.5), use.seconds)
	elseif use.kind == "xp" then
		return ("Опыт: +%d"):format(use.amount)
	end
	return nil
end

-- Взвешенный выбор: list = { {weight, ...} } → элемент.
function Items.pick(list, rng)
	local total = 0
	for _, entry in ipairs(list) do
		total += entry.weight
	end
	local roll = rng:NextNumber() * total
	for _, entry in ipairs(list) do
		roll -= entry.weight
		if roll <= 0 then
			return entry
		end
	end
	return list[#list]
end

-- Аксессуар для сундука этажа floor.
function Items.rollAccessory(floor: number?, rng)
	rng = rng or Random.new()
	local weights = Items.Chest.accessoryRarity[math.clamp(floor or 1, 1, 5)]
	local rarityList = {}
	for rarityId, weight in pairs(weights) do
		table.insert(rarityList, { rarityId = rarityId, weight = weight })
	end
	table.sort(rarityList, function(a, b)
		return a.rarityId < b.rarityId
	end)
	local rarityId = Items.pick(rarityList, rng).rarityId
	local pool = {}
	for id, acc in pairs(Items.Accessories) do
		if acc.rarityId == rarityId then
			table.insert(pool, id)
		end
	end
	table.sort(pool)
	if #pool == 0 then
		return "wanderer_charm"
	end
	return pool[rng:NextInteger(1, #pool)]
end

return Items
