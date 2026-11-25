--!nonstrict
-- LootMage
-- Посохи мага (этажи 1–5): пул сундуков, числа ударов-снарядов, заклинания и пассивки,
-- дебафы и умения класса («Барьер» на парировании, «Покров» на клавише 3).
-- Чистые данные, без require: Weapons.lua, Loot.lua подмешивают их к своим таблицам.
-- Логика — ServerScriptService/Systems/MageService (снаряды, дебафы, пассивки, барьер,
-- покров), MageBolts (полёт снарядов), WeaponAbilitiesMage (заклинания); эффекты —
-- клиентские MageFx (снаряды, барьер, покров, дебафы) и MageSpellFx (заклинания).
--
-- Обычная атака посоха — снаряды, маны НЕ тратит. Урон снаряда = урон удара
-- (урон класса × множитель посоха × ★ эха × крит × финал серии) × доля паттерна.
-- Дебафы горения/яда бьют % от урона удара посоха в секунду (без крита и финала).
-- Заклинания (клавиша 1) тратят ману и масштабируются от максимума маны (Mana.abilityScale).

local LootMage = {}

LootMage.Class = "mage"
LootMage.TypeId = "staff"
LootMage.StarterWeapon = "apprentice_staff"

-- ===== Умения класса =====

-- «Барьер» — парирование мага: ПКМ открывает купол на окно класса (Classes.mage.parryWindow).
LootMage.Barrier = {
	cost = 10, -- мана на попытку (нет маны — купол не откроется)
	refund = 15, -- удачный барьер возвращает
	pushRadius = 7, -- удачный барьер отбрасывает ближних врагов
	push = 4,
	pushTime = 0.22,
	-- Снаряды врагов в окне отражаются (ProjectileService, как у парирования воина).
}

-- «Покров» — невидимость (клавиша 3, Binds.Ability3).
LootMage.Veil = {
	id = "veil",
	name = "Покров",
	icon = "amulet",
	cost = 25,
	duration = 3,
	cooldown = 12,
	ambush = 1.5, -- первый удар или заклинание из покрова ×1.5 (и снимает покров)
	description = "3 с невидимости: враги теряют цель. Первый удар или заклинание из покрова ×1,5",
}

-- Доля длительности анимации удара посохом, на которой снаряд срывается с навершия
-- (PlayerAnimMage.STRIKE_AT — те же числа; сервер ждёт столько же, чтобы снаряд
-- вылетал в такт взмаху).
LootMage.StrikeAt = { 0.3, 0.3, 0.42 }

-- Финал серии (3-й удар) всегда взрывается: {радиус, доля урона соседям}. Баланс 07.11.2026 —
-- обычные удары мага по толпе отставали от воина на 25–40% (воин задевает дугой 2 из 4).
LootMage.FinisherSplash = { 3, 0.75 }

-- Мягкий автоприцел: снаряд доворачивает на ближайшего врага в этом полуугле (градусы).
LootMage.AimAssist = 20

-- Высота полёта снарядов над ногами мага, стады.
LootMage.BoltHeight = 2.7

-- ===== Дебафы =====
-- На враге одновременно не больше MaxDebuffs дебафов мага: новый вытесняет самый старый.
-- Повтор того же дебафа обновляет срок (не складывается).
LootMage.MaxDebuffs = 2
LootMage.DebuffTick = 0.5
LootMage.Debuffs = {
	slow = { id = "slow", name = "Замедление", amount = 0.3, duration = 3, color = "#9DD8FF" },
	burn = { id = "burn", name = "Горение", dps = 0.10, duration = 4, color = "#FF7A1F" },
	poison = { id = "poison", name = "Яд", dps = 0.08, duration = 6, color = "#8EE04A" },
	sunder = { id = "sunder", name = "Раскол брони", armor = 5, duration = 6, color = "#D8CDB0" },
}

-- ===== Вид снарядов =====
-- shape: orb (сфера), shard (осколок/шип), flame (огненный шар), page (страница),
-- spark (молния), wisp (дух с длинным хвостом), blob (тяжёлая капля/ком).
LootMage.Styles = {
	arcane = { shape = "orb", core = "#F0EBFF", glow = "#8C6CFF", trail = "#5B3FD9" },
	rust = { shape = "shard", core = "#FFD9B0", glow = "#D9772F", trail = "#7A3A16" },
	ember = { shape = "flame", core = "#FFF0B0", glow = "#FF7A1F", trail = "#C2381A" },
	light = { shape = "orb", core = "#FFFDEE", glow = "#FFD45A", trail = "#E0A030" },
	gate = { shape = "orb", core = "#E4F4FF", glow = "#6FB8FF", trail = "#3A6FD0" },
	water = { shape = "orb", core = "#EFFFFF", glow = "#4FD6FF", trail = "#1E7FC2" },
	poison = { shape = "blob", core = "#F4FFC8", glow = "#8EE04A", trail = "#3E8A2A" },
	thorn = { shape = "shard", core = "#EAFFD6", glow = "#6FCF5A", trail = "#2F6B2A" },
	lotus = { shape = "orb", core = "#FFF2FB", glow = "#FF8FD0", trail = "#C24F9A" },
	spore = { shape = "blob", core = "#FFFBD6", glow = "#C8E04A", trail = "#7A8A2A" },
	bone = { shape = "shard", core = "#FFF8E8", glow = "#E2D6B8", trail = "#8A7A60" },
	spirit = { shape = "wisp", core = "#EAFFF8", glow = "#6FFFD0", trail = "#2FA88A" },
	moon = { shape = "orb", core = "#F6F9FF", glow = "#A8C8FF", trail = "#5A6FB8" },
	fire = { shape = "flame", core = "#FFF4C0", glow = "#FF5A1F", trail = "#B8200F" },
	slag = { shape = "blob", core = "#FFE2A0", glow = "#FF8A2A", trail = "#4A2A1E" },
	lightning = { shape = "spark", core = "#FFFFFF", glow = "#7FD8FF", trail = "#3F7FFF" },
	magma = { shape = "flame", core = "#FFE6A0", glow = "#FF3A10", trail = "#7A1008" },
	forge = { shape = "orb", core = "#FFFFFF", glow = "#FFE39A", trail = "#FF8A2A" },
	ink = { shape = "blob", core = "#D2C4FF", glow = "#6A58D8", trail = "#14122A" },
	page = { shape = "page", core = "#FFFFF4", glow = "#EFE6CC", trail = "#B9A983" },
	sand = { shape = "orb", core = "#FFF8DE", glow = "#FFD98A", trail = "#B8904A" },
	time = { shape = "orb", core = "#F2FFFF", glow = "#6FE3FF", trail = "#FFD98A" },
	memory = { shape = "orb", core = "#FFFFFF", glow = "#6FE3FF", trail = "#B49CFF" },
}

-- ===== Паттерны серии =====
-- Удар серии (1, 2, 3) выбирает паттерн из combo посоха. share — доля урона удара на снаряд.
--   shots/spread — сколько снарядов и угол между соседними (веер);
--   offset — параллельные снаряды со сдвигом вбок (стады);
--   interval — очередь: снаряды друг за другом;
--   size/speed — множители размера и скорости; splash — взрыв {радиус, доля} поверх свойств посоха;
--   lob — навесом в точку (враг под прицелом или lobRange вперёд); wave — волна-конус; beam — луч.
LootMage.Patterns = {
	single = { shots = 1, share = 1.0 },
	twin = { shots = 2, offset = 0.9, share = 0.6 },
	fan3 = { shots = 3, spread = 12, share = 0.45 },
	fan5 = { shots = 5, spread = 10, share = 0.3 },
	volley2 = { shots = 2, interval = 0.08, share = 0.6 },
	volley3 = { shots = 3, interval = 0.07, share = 0.42 },
	big = { shots = 1, share = 1.0, size = 1.7, speed = 0.85, splash = { 3, 0.5 } },
	lob = { shots = 1, share = 1.0, lob = true, splash = { 2.6, 0.6 } },
	lob3 = { shots = 3, spread = 16, share = 0.5, lob = true, splash = { 2.4, 0.6 } },
	wave = { wave = true, radius = 11, angle = 70, share = 1.0 },
	beam = { beam = true, width = 1.3, share = 1.15 },
	nova = { nova = true, radius = 5.5, share = 0.85 },
}

-- ===== Посохи: числа ударов (Weapons.Items) =====
-- damage/speed/recovery — как у оружия воина; range — дальность снаряда; arc — полуугол автоприцела;
-- mana/manaRegen — к мане мага (ManaService), leech — доля нанесённого урона в здоровье;
-- bolt — свойства снаряда посоха: style, speed (стад/с), size (радиус), homing (°/с),
--   pierce (сквозь врагов), splash {радиус, доля}, split {осколков, доля, угол},
--   debuff {вид, шанс} (финал серии — всегда), chain {прыжков, радиус, доля};
-- combo — паттерны трёх ударов серии.
local function staff(damage, speed, recovery, extra)
	local item = { damage = damage, speed = speed, recovery = recovery, range = 28, arc = LootMage.AimAssist, stagger = 0 }
	for k, v in pairs(extra) do
		item[k] = v
	end
	return item
end

LootMage.Items = {
	-- Этаж 1 «Порог» (0.80–1.02)
	apprentice_staff = staff(0.96, 1.0, 1.0, { mana = 0,
		bolt = { style = "arcane", speed = 62, size = 0.45 },
		combo = { "single", "single", "twin" } }),
	rusted_rod = staff(0.98, 0.92, 1.05, { mana = 5,
		bolt = { style = "rust", speed = 58, size = 0.5 },
		combo = { "single", "single", "big" } }),
	ember_staff = staff(0.98, 1.0, 1.0, { mana = 10, manaRegen = 0.1,
		bolt = { style = "ember", speed = 60, size = 0.5, debuff = { "burn", 0.3 } },
		combo = { "single", "twin", "fan3" } }),
	warden_rod = staff(0.98, 1.08, 0.95, { mana = 10, manaRegen = 0.2, leech = 0.03,
		bolt = { style = "light", speed = 56, size = 0.42, homing = 160 },
		combo = { "single", "single", "volley3" } }),
	gate_staff = staff(1.0, 1.0, 1.0, { mana = 20, manaRegen = 0.3,
		bolt = { style = "gate", speed = 64, size = 0.5, pierce = 1, debuff = { "sunder", 0.25 } },
		combo = { "single", "twin", "fan3" } }),
	beacon_staff = staff(1, 0.98, 1.0, { mana = 20, manaRegen = 0.3,
		bolt = { style = "fire", speed = 58, size = 0.55, splash = { 2.5, 0.4 }, debuff = { "burn", 0.25 } },
		combo = { "single", "single", "big" } }),
	gatekeeper_scepter = staff(1.02, 1.05, 0.95, { mana = 30, manaRegen = 0.5, leech = 0.02,
		bolt = { style = "light", speed = 66, size = 0.5, homing = 120, pierce = 1 },
		combo = { "single", "twin", "fan5" } }),

	-- Этаж 2 «Затопленные сады» (0.86–1.08)
	reed_wand = staff(0.9, 1.15, 0.9, { mana = 5,
		bolt = { style = "water", speed = 70, size = 0.4 },
		combo = { "single", "twin", "twin" } }),
	mossy_staff = staff(1.04, 1.0, 1.0, { mana = 10,
		bolt = { style = "poison", speed = 56, size = 0.5, debuff = { "poison", 0.25 } },
		combo = { "single", "single", "lob" } }),
	tide_staff = staff(0.88, 0.98, 1.0, { mana = 15, manaRegen = 0.2,
		bolt = { style = "water", speed = 64, size = 0.55, pierce = 2, debuff = { "slow", 0.4 } },
		combo = { "single", "single", "wave" } }),
	thorn_rod = staff(1.04, 1.05, 0.95, { mana = 15, manaRegen = 0.2,
		bolt = { style = "thorn", speed = 72, size = 0.38, debuff = { "poison", 0.15 } },
		combo = { "fan3", "fan3", "fan5" } }),
	lotus_staff = staff(1.06, 1.0, 1.0, { mana = 25, manaRegen = 0.4, leech = 0.03,
		bolt = { style = "lotus", speed = 58, size = 0.5, homing = 90 },
		combo = { "single", "twin", "fan3" } }),
	spore_staff = staff(1.04, 1.0, 1.0, { mana = 25, manaRegen = 0.4,
		bolt = { style = "spore", speed = 54, size = 0.55, debuff = { "poison", 0.35 } },
		combo = { "single", "volley2", "lob3" } }),
	gardener_crook = staff(1.08, 1.02, 0.95, { mana = 30, manaRegen = 0.6, leech = 0.02,
		bolt = { style = "thorn", speed = 66, size = 0.45, homing = 70, debuff = { "poison", 0.3 } },
		combo = { "fan3", "twin", "fan5" } }),

	-- Этаж 3 «Псарни охоты» (0.98–1.18)
	bone_wand = staff(1.08, 1.05, 1.0, { mana = 10,
		bolt = { style = "bone", speed = 66, size = 0.45, split = { 3, 0.3, 40 } },
		combo = { "single", "single", "big" } }),
	antler_staff = staff(1.07, 1.0, 1.0, { mana = 10, manaRegen = 0.2,
		bolt = { style = "spirit", speed = 58, size = 0.42, homing = 100 },
		combo = { "twin", "twin", "fan3" } }),
	howl_staff = staff(1.14, 0.95, 1.05, { mana = 15, manaRegen = 0.3,
		bolt = { style = "spirit", speed = 62, size = 0.5, debuff = { "slow", 0.3 } },
		combo = { "single", "single", "wave" } }),
	trap_rod = staff(1.1, 0.92, 1.05, { mana = 15, manaRegen = 0.3,
		bolt = { style = "bone", speed = 46, size = 0.55, splash = { 2.4, 0.5 }, debuff = { "slow", 0.5 } },
		combo = { "lob", "lob", "lob3" } }),
	pack_staff = staff(1.16, 1.0, 1.0, { mana = 25, manaRegen = 0.4,
		bolt = { style = "spirit", speed = 60, size = 0.5, homing = 140 },
		combo = { "single", "twin", "volley3" } }),
	moon_staff = staff(1.14, 0.98, 1.0, { mana = 25, manaRegen = 0.5,
		bolt = { style = "moon", speed = 68, size = 0.5, pierce = 1 },
		combo = { "single", "twin", "beam" } }),
	huntmaster_staff = staff(1.18, 1.02, 0.95, { mana = 35, manaRegen = 0.7, leech = 0.03,
		bolt = { style = "moon", speed = 66, size = 0.5, homing = 110, debuff = { "slow", 0.2 } },
		combo = { "twin", "fan3", "volley3" } }),

	-- Этаж 4 «Кузня Основателя» (1.08–1.30)
	poker_rod = staff(1.13, 1.0, 1.0, { mana = 15,
		bolt = { style = "fire", speed = 62, size = 0.5, debuff = { "burn", 0.2 } },
		combo = { "single", "single", "twin" } }),
	bellows_staff = staff(1.22, 0.96, 1.0, { mana = 20, manaRegen = 0.3,
		bolt = { style = "fire", speed = 60, size = 0.5, debuff = { "burn", 0.3 } },
		combo = { "fan3", "fan3", "wave" } }),
	slag_rod = staff(1.24, 0.9, 1.1, { mana = 20, manaRegen = 0.3,
		bolt = { style = "slag", speed = 48, size = 0.6, splash = { 2.8, 0.55 }, debuff = { "sunder", 0.3 } },
		combo = { "lob", "lob", "lob3" } }),
	crucible_staff = staff(1.15, 0.98, 1.0, { mana = 30, manaRegen = 0.5,
		bolt = { style = "magma", speed = 58, size = 0.55, splash = { 2.4, 0.4 }, debuff = { "burn", 0.3 } },
		combo = { "single", "twin", "big" } }),
	anvil_rod = staff(1.1, 1.0, 1.0, { mana = 30, manaRegen = 0.5,
		bolt = { style = "lightning", speed = 90, size = 0.4, chain = { 2, 8, 0.6 } },
		combo = { "single", "single", "volley3" } }),
	founder_staff = staff(1.26, 1.0, 1.0, { mana = 40, manaRegen = 0.8, leech = 0.02,
		bolt = { style = "forge", speed = 64, size = 0.55, splash = { 2.2, 0.4 }, debuff = { "burn", 0.25 } },
		combo = { "twin", "fan3", "big" } }),
	molten_scepter = staff(1.28, 0.98, 1.0, { mana = 40, manaRegen = 0.8, leech = 0.02,
		bolt = { style = "magma", speed = 56, size = 0.6, splash = { 2.6, 0.45 }, debuff = { "burn", 0.35 } },
		combo = { "single", "lob", "lob3" } }),
	unfinished_staff = staff(1.3, 1.02, 0.95, { mana = 45, manaRegen = 1.0, leech = 0.03,
		bolt = { style = "forge", speed = 70, size = 0.55, homing = 80, pierce = 1, splash = { 2.4, 0.4 }, debuff = { "burn", 0.3 } },
		combo = { "fan3", "volley3", "beam" } }),

	-- Этаж 5 «Архив Хрониста» (1.15–1.42)
	quill_wand = staff(1.21, 1.2, 0.9, { mana = 15,
		bolt = { style = "ink", speed = 80, size = 0.35 },
		combo = { "single", "volley2", "volley3" } }),
	page_staff = staff(1.34, 1.0, 1.0, { mana = 20, manaRegen = 0.3,
		bolt = { style = "page", speed = 56, size = 0.45, homing = 120 },
		combo = { "fan3", "fan3", "fan5" } }),
	hourglass_rod = staff(1.34, 0.96, 1.0, { mana = 20, manaRegen = 0.4,
		bolt = { style = "sand", speed = 62, size = 0.5, debuff = { "slow", 0.5 } },
		combo = { "single", "twin", "beam" } }),
	tome_staff = staff(1.36, 1.0, 1.0, { mana = 30, manaRegen = 0.6,
		bolt = { style = "arcane", speed = 64, size = 0.5, homing = 90, split = { 2, 0.35, 30 } },
		combo = { "single", "fan3", "big" } }),
	clock_staff = staff(1.36, 1.05, 0.95, { mana = 30, manaRegen = 0.6,
		bolt = { style = "time", speed = 70, size = 0.48, debuff = { "slow", 0.3 } },
		combo = { "volley2", "twin", "nova" } }),
	chronicler_staff = staff(1.36, 1.0, 1.0, { mana = 40, manaRegen = 0.8, leech = 0.03,
		bolt = { style = "ink", speed = 68, size = 0.5, pierce = 1, homing = 60 },
		combo = { "twin", "fan3", "beam" } }),
	ink_scepter = staff(1.38, 0.98, 1.0, { mana = 40, manaRegen = 0.8, leech = 0.03,
		bolt = { style = "ink", speed = 58, size = 0.6, splash = { 2.6, 0.45 }, debuff = { "poison", 0.3 } },
		combo = { "single", "lob", "big" } }),
	memory_staff = staff(1.42, 1.05, 0.95, { mana = 45, manaRegen = 1.0, leech = 0.04,
		bolt = { style = "memory", speed = 72, size = 0.5, homing = 120, pierce = 1 },
		combo = { "twin", "fan5", "beam" } }),
}

-- ===== Пулы сундуков мага =====
-- Количество по редкостям — как у воина (±1); секретки только на этажах 4 и 5.
-- Легендарка: +15% к урону способности, −8% к перезарядке; секретка: +20% / −10%.
local LEGEND = { damageBonus = 0.15, cooldownReduction = 0.08 }
local SECRET = { damageBonus = 0.2, cooldownReduction = 0.1 }

local function weapon(id, name, rarity, floor, ability, passive)
	local entry = { id = id, name = name, typeId = "staff", rarity = rarity, floor = floor, class = "mage",
		ability = ability, passive = passive }
	local bonus = rarity == "secret" and SECRET or (rarity == "legendary" and LEGEND or nil)
	if bonus then
		entry.damageBonus = bonus.damageBonus
		entry.cooldownReduction = bonus.cooldownReduction
	end
	return entry
end

LootMage.Weapons = {
	-- Этаж 1: 2 обычных, 2 редких, 2 эпических, 1 легендарка.
	weapon("apprentice_staff", "Посох послушника", "common", 1),
	weapon("rusted_rod", "Ржавый жезл", "common", 1),
	weapon("ember_staff", "Посох углей", "rare", 1),
	weapon("warden_rod", "Жезл дозорного", "rare", 1),
	weapon("gate_staff", "Посох Заставы", "epic", 1, "ward_circle"),
	weapon("beacon_staff", "Маячный посох", "epic", 1, "signal_fire"),
	weapon("gatekeeper_scepter", "Скипетр Привратника", "legendary", 1, "light_gate", "key_resonance"),
	-- Этаж 2.
	weapon("reed_wand", "Камышовый жезл", "common", 2),
	weapon("mossy_staff", "Замшелый посох", "common", 2),
	weapon("tide_staff", "Посох прилива", "rare", 2),
	weapon("thorn_rod", "Терновый жезл", "rare", 2),
	weapon("lotus_staff", "Посох лотоса", "epic", 2, "lotus_bloom"),
	weapon("spore_staff", "Споровый посох", "epic", 2, "mycelium"),
	weapon("gardener_crook", "Посох Садовницы", "legendary", 2, "thorn_garden", "dew"),
	-- Этаж 3.
	weapon("bone_wand", "Костяной жезл", "common", 3),
	weapon("antler_staff", "Рогатый посох", "common", 3),
	weapon("howl_staff", "Посох воя", "rare", 3),
	weapon("trap_rod", "Жезл ловчего", "rare", 3),
	weapon("pack_staff", "Посох стаи", "epic", 3, "spirit_pack"),
	weapon("moon_staff", "Лунный посох", "epic", 3, "hunters_moon"),
	weapon("huntmaster_staff", "Посох Королевского ловчего", "legendary", 3, "royal_hunt", "hunter_mark"),
	-- Этаж 4: + вторая легендарка и секретка.
	weapon("poker_rod", "Жезл-кочерга", "common", 4),
	weapon("bellows_staff", "Посох мехов", "rare", 4),
	weapon("slag_rod", "Шлаковый жезл", "rare", 4),
	weapon("crucible_staff", "Посох тигля", "epic", 4, "fire_rain"),
	weapon("anvil_rod", "Наковальный жезл", "epic", 4, "forged_lightning"),
	weapon("founder_staff", "Посох Основателя", "legendary", 4, "forge_heart", "tempering"),
	weapon("molten_scepter", "Расплавленный скипетр", "legendary", 4, "meteor", "cinders"),
	weapon("unfinished_staff", "Незаконченный посох", "secret", 4, "first_cast", "casting_heat"),
	-- Этаж 5.
	weapon("quill_wand", "Перо-жезл", "common", 5),
	weapon("page_staff", "Посох страниц", "rare", 5),
	weapon("hourglass_rod", "Жезл песочных часов", "rare", 5),
	weapon("tome_staff", "Посох фолианта", "epic", 5, "open_tome"),
	weapon("clock_staff", "Часовой посох", "epic", 5, "time_stop"),
	weapon("chronicler_staff", "Посох Хрониста", "legendary", 5, "fate_line", "footnote"),
	weapon("ink_scepter", "Чернильный скипетр", "legendary", 5, "ink_hole", "blot"),
	weapon("memory_staff", "Посох Памяти", "secret", 5, "total_recall", "echo"),
}

-- Веса редкостей сундука мага по этажу (как у оружия воина этих этажей).
LootMage.ChestWeights = {
	[1] = { common = 70, rare = 22, epic = 7, legendary = 1 },
	[2] = { common = 62, rare = 25, epic = 11, legendary = 2 },
	[3] = { common = 56, rare = 27, epic = 13, legendary = 4 },
	[4] = { common = 50, rare = 28, epic = 15, legendary = 6, secret = 1 },
	[5] = { common = 40, rare = 30, epic = 18, legendary = 9, secret = 1.5 },
}

-- ===== Заклинания (клавиша 1) =====
-- mana — цена, cooldown — перезарядка (легендарка/секретка срезают её, ★ эха тоже),
-- castTime — маг занят (удары не идут), числа — доли силы заклинания
-- (урон оружия × ★ эха × бонус редкости × масштаб маны × засада из покрова).
local function spell(id, name, icon, mana, cooldown, castTime, description, numbers)
	local entry = { id = id, name = name, icon = icon, mana = mana, cooldown = cooldown, castTime = castTime,
		description = description, school = "mage" }
	for k, v in pairs(numbers) do
		entry[k] = v
	end
	return entry
end

LootMage.Abilities = {
	-- Этаж 1
	ward_circle = spell("ward_circle", "Сторожевой круг", "mage_ward", 30, 14, 0.6,
		"Круг рун R7 на 4 с: вспышка 120% и отброс, затем 25% каждые 0,5 с и замедление 30%",
		{ radius = 7, burst = 1.2, push = 3, duration = 4, tick = 0.5, tickDamage = 0.25, slow = 0.3, damageMultiplier = 3.2 }),
	signal_fire = spell("signal_fire", "Сигнальный огонь", "mage_signal", 32, 14, 0.5,
		"Огненный маяк летит вперёд: взрыв 180% R5 с горением, столб огня 3 с бьёт 30% каждые 0,5 с",
		{ range = 16, flight = 0.45, radius = 5, blast = 1.8, pillarRadius = 4, pillarTime = 3, tick = 0.5, tickDamage = 0.3, damageMultiplier = 3.6 }),
	light_gate = spell("light_gate", "Врата света", "mage_gate", 40, 16, 0.9,
		"Врата из света в 8 стадах: волна 210% на 18 стадов с оглушением 1 с, затем обрушение 100% R6",
		{ distance = 8, gateWidth = 8, surgeAt = 0.55, surgeLength = 18, surgeHalfWidth = 4, surge = 2.1, stun = 1.0,
			closeAt = 1.25, closeRadius = 6, close = 1.0, damageMultiplier = 3.1 }),
	-- Этаж 2
	lotus_bloom = spell("lotus_bloom", "Цветение лотоса", "mage_lotus", 32, 15, 0.6,
		"Лотос R6 у ног: гейзер 200% с подбросом, 10 лепестков-самонаводов по 35%; лечит 12% здоровья (союзникам 8%)",
		{ radius = 6, geyserAt = 0.3, geyser = 2, launch = 3, petals = 10, petal = 0.35, heal = 0.12, allyHeal = 0.08, damageMultiplier = 5.5 }),
	mycelium = spell("mycelium", "Грибница", "mage_spore", 30, 13, 0.5,
		"5 спор навесом засевают поляну R7 (35% и яд); через 1 с поляна 3 с выдыхает облако: 25% каждые 0,5 с, яд, замедление 25%; в конце грибы лопаются 80%",
		{ distance = 9, radius = 7, spores = 5, flight = 0.55, spore = 0.35, seedRadius = 2.5, gladeAt = 0.7, exhaleAt = 1.1,
			cloudTime = 3, tick = 0.5, cloudTick = 0.25, slow = 0.25, burst = 0.8, damageMultiplier = 3.2 }),
	thorn_garden = spell("thorn_garden", "Сад шипов", "mage_thorn", 42, 16, 0.8,
		"Три кольца шипов R3/R6/R9 по 140% с ядом и корнями, затем сад 3 с: замедление 40% и 25% каждые 0,5 с",
		{ rings = { 3, 6, 9 }, ringAt = { 0.3, 0.6, 0.9 }, ring = 1.4, root = 0.6, gardenTime = 3, tick = 0.5, tickDamage = 0.25,
			slow = 0.4, radius = 9, damageMultiplier = 2.9 }),
	-- Этаж 3
	spirit_pack = spell("spirit_pack", "Призрачная стая", "mage_pack", 34, 15, 0.6,
		"4 волка окружают цель и воют: соседи в R7 бегут в страхе 1,5 с (80%), цель прижата 1 с; 6 укусов по 55%, общий прыжок 180% с замедлением",
		{ range = 22, wolves = 4, runTime = 0.45, howlAt = 0.7, fearRadius = 7, howl = 0.8, fear = 1.5, fearPush = 6, hold = 1.0,
			bossHold = 0.4, biteAt = 0.95, biteEvery = 0.18, bites = 6, bite = 0.55, pounce = 1.8, slow = 0.35, damageMultiplier = 5.1 }),
	hunters_moon = spell("hunters_moon", "Охотничья луна", "mage_moon", 36, 16, 0.7,
		"Луна над полем боя: 8 лунных лучей по 60% в радиусе 12, затем серп-волна 100% R8",
		{ distance = 9, height = 14, radius = 12, beams = 8, beamEvery = 0.28, beam = 0.6, crescent = 1.0, crescentRadius = 8,
			damageMultiplier = 5.8 }),
	royal_hunt = spell("royal_hunt", "Королевская ловля", "mage_net", 45, 16, 0.8,
		"Сеть R6 в 10 стадах: 60%, держит 2 с и подтягивает к центру; 3 копья с неба по 140% R2,5 в самых живучих; сеть рвётся 80% с замедлением",
		{ distance = 10, flight = 0.45, radius = 6, net = 0.6, hold = 2.0, bossHold = 0.6, pull = 2, spears = 3, spearAt = 0.55,
			spearEvery = 0.4, spear = 1.4, spearRadius = 2.5, tearAt = 2.0, tear = 0.8, slow = 0.3, damageMultiplier = 5.6 }),
	-- Этаж 4
	fire_rain = spell("fire_rain", "Огненный дождь", "mage_firerain", 36, 15, 0.7,
		"Круг R10 впереди: 8 метеоров за 2 с, каждый 70% R3 с горением",
		{ distance = 12, radius = 10, meteors = 8, duration = 2.0, meteor = 0.7, meteorRadius = 3, damageMultiplier = 5.6 }),
	forged_lightning = spell("forged_lightning", "Кованая молния", "mage_lightning", 34, 14, 0.5,
		"Молния с неба 160% в ближайшего врага и цепь на 6 целей (−15% за прыжок), оглушение 0,4 с",
		{ range = 18, strike = 1.6, jumps = 6, jumpRange = 9, decay = 0.85, stun = 0.4, damageMultiplier = 7.2 }),
	forge_heart = spell("forge_heart", "Сердце горна", "mage_heart", 45, 17, 1.0,
		"Разлом на 16 стадов: 5 огненных столбов по 180% с подбросом и горением, стена огня шириной 4 на 3 с — 40% каждые 0,5 с",
		{ length = 16, crackTime = 0.4, pillars = 5, pillar = 1.8, pillarRadius = 2.8, launch = 3, wallTime = 3, tick = 0.5,
			tickDamage = 0.4, wallHalfWidth = 2, damageMultiplier = 4.2 }),
	meteor = spell("meteor", "Звезда горна", "mage_meteor", 48, 18, 1.1,
		"Круг R8 и гигантский метеор через 1 с: 380% (к краю 60%) с отбросом, лава R5 3 с — 25% каждые 0,5 с",
		{ distance = 12, radius = 8, impactAt = 1.0, impact = 3.8, edge = 0.6, knockback = 4, lavaRadius = 5, lavaTime = 3,
			tick = 0.5, tickDamage = 0.25, damageMultiplier = 5.3 }),
	first_cast = spell("first_cast", "Первая плавка", "mage_firstcast", 55, 20, 1.4,
		"Круг R14: 8 разломов с лучами по 120%, затем сверхновая 300% (к краю 50%) с горением и подбросом",
		{ radius = 14, rifts = 8, riftFrom = 3, riftAt = 0.35, riftEvery = 0.08, rift = 1.2, riftHalfWidth = 1.4,
			novaAt = 1.25, nova = 3.0, edge = 0.5, launch = 3.5, damageMultiplier = 6.0 }),
	-- Этаж 5
	open_tome = spell("open_tome", "Раскрытая книга", "mage_tome", 34, 15, 0.8,
		"Над магом раскрывается фолиант: 12 самонаводящихся глифов по 50%, затем буря страниц 120% R6",
		{ glyphs = 12, glyph = 0.5, glyphEvery = 0.07, stormAt = 1.3, storm = 1.2, stormRadius = 6, damageMultiplier = 7.2 }),
	time_stop = spell("time_stop", "Остановка времени", "mage_clock", 38, 18, 0.6,
		"Циферблат R10: враги замирают на 2 с (боссы 0,8 с), стрелка дважды режет круг по 55%, удар стрелок 220%; стрелки идут назад — вернёшь 25% здоровья, потерянного за 5 с",
		{ radius = 10, freeze = 2.0, bossFreeze = 0.8, sweeps = 2, sweep = 0.55, strike = 2.2, rewind = 0.25, rewindWindow = 5,
			damageMultiplier = 3.3 }),
	fate_line = spell("fate_line", "Строка судьбы", "mage_fate", 44, 17, 0.9,
		"Строка письмен на 20 стадов: через 0,8 с вспыхивает лучом 300%, цели уязвимы (+15%) 4 с",
		{ length = 20, halfWidth = 1.8, igniteAt = 0.8, beam = 3.0, vulnerable = 0.15, vulnerableTime = 4, damageMultiplier = 3.0 }),
	ink_hole = spell("ink_hole", "Чёрная клякса", "mage_inkhole", 46, 18, 0.9,
		"Клякса в 12 стадах становится воронкой R9: 2 с стягивает и бьёт 12% каждые 0,25 с, затем взрыв 210% R6",
		{ distance = 12, flight = 0.4, radius = 9, pullTime = 2.0, tick = 0.25, tickDamage = 0.12, pull = 1.4,
			blast = 2.1, blastRadius = 6, damageMultiplier = 3.1 }),
	total_recall = spell("total_recall", "Вспомнить всё", "mage_recall", 55, 20, 1.4,
		"3 эха мага бьют лучами (2 залпа по 110%), затем шторм 16 сфер памяти по 55% в радиусе 12",
		{ echoes = 3, echoRadius = 4, beamAt = { 0.35, 0.75 }, beam = 1.1, beamRange = 20, stormAt = 1.0, orbs = 16, orb = 0.55,
			stormRadius = 12, damageMultiplier = 15.4 }),
}

-- ===== Пассивки легендарок и секреток =====
LootMage.Passives = {
	key_resonance = { id = "key_resonance", name = "Резонанс ключа", school = "mage",
		description = "Каждое 3-е попадание по врагу: разряд 60% в цель и дуги ещё в 2 врагов рядом",
		hits = 3, window = 6, damage = 0.6, arcs = 2, arcRange = 8 },
	dew = { id = "dew", name = "Роса", school = "mage",
		description = "Попадания копят росу; 6 капель — лечение 5% здоровья и +8 маны",
		drops = 6, heal = 0.05, mana = 8 },
	hunter_mark = { id = "hunter_mark", name = "Метка ловчего", school = "mage",
		description = "Попадание метит врага на 6 с: +15% урона снарядами, каждое 4-е — пикирующий сокол 80%",
		markTime = 6, bonus = 0.15, every = 4, falcon = 0.8 },
	tempering = { id = "tempering", name = "Закалка", school = "mage",
		description = "Попадания греют посох (+2% урона за деление, до 10); на 10 — взрыв 120% R3,5",
		max = 10, step = 0.02, decay = 3, blast = 1.2, radius = 3.5 },
	cinders = { id = "cinders", name = "Тлеющие угли", school = "mage", -- было embers: id совпадал с пассивкой Клинка горна
		description = "Горящие враги при смерти взрываются: 60% R4 и поджог соседей",
		damage = 0.6, radius = 4 },
	casting_heat = { id = "casting_heat", name = "Жар отливки", school = "mage",
		description = "Каждый 5-й снаряд — расплавленная капля: взрыв 120% R3 с горением",
		every = 5, damage = 1.2, radius = 3 },
	footnote = { id = "footnote", name = "Сноска", school = "mage",
		description = "Каждое 4-е попадание оставляет сноску: через 1,5 с она повторяет 60% удара",
		every = 4, delay = 1.5, damage = 0.6 },
	blot = { id = "blot", name = "Клякса", school = "mage",
		description = "25% попаданий — лужа чернил R2,5 на 3 с: 10% каждые 0,5 с и замедление 20%",
		chance = 0.25, radius = 2.5, time = 3, tick = 0.5, damage = 0.1, slow = 0.2 },
	echo = { id = "echo", name = "Эхо", school = "mage",
		description = "Каждый выстрел через 0,35 с повторяет эхо — 40% урона",
		delay = 0.35, damage = 0.4 },
}

return LootMage
