--!nonstrict
-- Classes
-- Базовые статы классов и рост за уровень. Приложение Б плана.
-- Здесь только числа: поведение классов живёт в системах.

local Classes = {}

-- Потолок уровня 60, но статы растут только до 30-го (Приложение Б: «до 30»).
-- Уровни 31..60 дают лишь очко древа талантов (Config/Talents) — так игрок,
-- ушедший далеко за 30, получает прокачку, а баланс этажей не уезжает.
Classes.MaxLevel = 60
Classes.StatLevel = 30

Classes.order = { "warrior", "assassin", "mage" }

-- Бета (решение Артёма 06.11.2026): ассасина в бете нет — доделываем к открытию
-- режима. Скрытый класс не показывается в окне героя и не выбирается; данные
-- класса остаются (отладка: class assassin). Открыть — убрать из списка.
Classes.Hidden = { assassin = true }

-- Классы, которые видит игрок (порядок как в Classes.order).
function Classes.visible(): { string }
	local list = {}
	for _, id in ipairs(Classes.order) do
		if not Classes.Hidden[id] then
			table.insert(list, id)
		end
	end
	return list
end

Classes.data = {
	warrior = {
		id = "warrior",
		name = "Воин",
		order = 1,
		health = 140,
		healthPerLevel = 10,
		armor = 8,
		armorPerLevel = 0.5,
		weaponDamage = 20,
		weaponDamagePerLevel = 1.5,
		attackSpeed = 0.9,
		walkSpeed = 15,
		parryWindow = 0.35,
		dodgeCharges = 1,
		stat = "armor",
	},
	assassin = {
		id = "assassin",
		name = "Ассасин",
		order = 2,
		health = 95,
		healthPerLevel = 7,
		armor = 3,
		armorPerLevel = 0.3,
		weaponDamage = 16,
		weaponDamagePerLevel = 1.2,
		attackSpeed = 1.4,
		walkSpeed = 18,
		parryWindow = 0.20,
		dodgeCharges = 2,
		stat = "walkSpeed",
	},
	mage = {
		id = "mage",
		name = "Маг",
		order = 3,
		health = 85,
		healthPerLevel = 6,
		armor = 2,
		armorPerLevel = 0.2,
		weaponDamage = 24,
		weaponDamagePerLevel = 1.8,
		attackSpeed = 0.8,
		walkSpeed = 16,
		parryWindow = 0.25,
		dodgeCharges = 1,
		mana = 100,
		manaPerLevel = 8,
		manaRegen = 3,
		stat = "mana",
	},
}

function Classes.get(id: string)
	return Classes.data[id]
end

function Classes.default()
	return "warrior"
end

-- Статы на уровне. Уровень клампится в 1..60, рост статов — до StatLevel (30).
function Classes.statsAtLevel(id: string, level: number?)
	local base = Classes.data[id]
	if not base then
		return nil
	end
	local lvl = math.clamp(level or 1, 1, Classes.MaxLevel)
	local growth = math.min(lvl, Classes.StatLevel) - 1

	local stats = {
		className = base.id,
		name = base.name,
		level = lvl,
		maxHealth = base.health + base.healthPerLevel * growth,
		armor = base.armor + base.armorPerLevel * growth,
		weaponDamage = base.weaponDamage + base.weaponDamagePerLevel * growth,
		attackSpeed = base.attackSpeed,
		walkSpeed = base.walkSpeed,
		parryWindow = base.parryWindow,
		dodgeCharges = base.dodgeCharges,
	}

	if base.mana then
		stats.maxMana = base.mana + base.manaPerLevel * growth
		stats.manaRegen = base.manaRegen
	end

	return stats
end

return Classes
