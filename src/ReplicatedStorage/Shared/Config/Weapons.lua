--!nonstrict
-- Weapons
-- Типы оружия и вся математика урона/заточки. Приложение Б плана.
-- Ключевая мысль баланса: тип задаёт стиль (урон × скорость), редкость даёт
-- способность и малый множитель, заточка позволяет обычному оружию оставаться
-- жизнеспособным (+30% на максимуме).

local Rarities = require(script.Parent.Rarities)

local Weapons = {}

Weapons.Types = {
	dagger = {
		id = "dagger",
		name = "Кинжал",
		damageMultiplier = 0.7,
		speedMultiplier = 1.35,
		recovery = 0.6, -- пауза после серии (× Combat.Attack.comboRecovery)
		ability = "Теневой шаг",
		abilityCooldown = 10,
	},
	sword = {
		id = "sword",
		name = "Меч",
		damageMultiplier = 1.0,
		speedMultiplier = 1.0,
		recovery = 1.0,
		ability = "Вихрь клинка",
		abilityCooldown = 12,
	},
	hammer = {
		id = "hammer",
		name = "Молот",
		damageMultiplier = 1.6,
		speedMultiplier = 0.65,
		recovery = 1.4,
		ability = "Раскол",
		abilityCooldown = 15,
	},
	staff = {
		id = "staff",
		name = "Посох",
		damageMultiplier = 0.9,
		speedMultiplier = 1.1,
		recovery = 0.9,
		ability = "Звёздный залп",
		abilityCooldown = 12,
	},
}

-- Статы конкретных предметов (согласовано с Артёмом 24.10.2026).
-- damage — ИТОГОВЫЙ множитель урона от урона класса (тип × редкость уже
-- внутри, поэтому множитель редкости поверх не применяется);
-- speed — скорость ударов (>1 быстрее); recovery — пауза после серии
-- (× Combat.Attack.comboRecovery); range — дальность удара, стады;
-- arc — ширина дуги удара, градусы; stagger — финал серии «пошатывает»
-- врага (короткий толчок, с), 0 — нет.
-- Предмет без записи берёт числа своего типа (Weapons.Types) и редкости.
Weapons.Items = {
	rusty_sword = { damage = 1.0, speed = 1.0, recovery = 1.0, range = 6, arc = 100, stagger = 0 },
	iron_falchion = { damage = 1.1, speed = 0.9, recovery = 1.05, range = 7, arc = 90, stagger = 0 },
	forge_hammer = { damage = 1.6, speed = 0.65, recovery = 1.4, range = 6.5, arc = 120, stagger = 0.3 },
	guard_blade = { damage = 1.06, speed = 1.05, recovery = 1.0, range = 6.5, arc = 110, stagger = 0 },
	guard_hammer = { damage = 1.7, speed = 0.68, recovery = 1.35, range = 7, arc = 120, stagger = 0.3 },
	vortex_blade = { damage = 1.12, speed = 1.05, recovery = 1.0, range = 7, arc = 110, stagger = 0 },
	shattered_hammer = { damage = 1.8, speed = 0.68, recovery = 1.35, range = 7, arc = 130, stagger = 0.35 },
	gatekeeper_key = { damage = 1.18, speed = 1.0, recovery = 1.0, range = 7.5, arc = 110, stagger = 0 },
}

-- Этаж 2 «Затопленные сады»: числа ударов восьми новых видов оружия (чистые данные в LootFloor2).
for itemId, stats in pairs(require(script.Parent.LootFloor2).Items) do
	Weapons.Items[itemId] = stats
end
-- Этажи 3–5: числа ударов из Config.LootFloor3/4/5.
for _, name in ipairs({ "LootFloor3", "LootFloor4", "LootFloor5" }) do
	for itemId, stats in pairs(require(script.Parent[name]).Items) do
		Weapons.Items[itemId] = stats
	end
end

-- Посохи мага: числа ударов-снарядов (Config.LootMage; range — дальность снаряда, arc — автоприцел,
-- mana/manaRegen/leech, bolt и combo — свойства снарядов для MageService).
for itemId, stats in pairs(require(script.Parent.LootMage).Items) do
	Weapons.Items[itemId] = stats
end

-- Этажи 3–5: числа ударов оружия «Псарен», «Кузни» и «Архива».
-- Тот же случай, что и в Loot.lua: пакеты — отдельные ветки, и этот блок
-- терялся при последовательном наложении (без него у оружия 3–5 оставались
-- базовые числа типа).
for _, floor in ipairs({ 3, 4, 5 }) do
	local module = script.Parent:FindFirstChild("LootFloor" .. floor)
	if module then
		for itemId, stats in pairs(require(module).Items) do
			Weapons.Items[itemId] = stats
		end
	end
end

-- Посохи мага: числа ударов-снарядов (Config.LootMage; range — дальность снаряда, arc — автоприцел,
-- mana/manaRegen/leech, bolt и combo — свойства снарядов для MageService).
for itemId, stats in pairs(require(script.Parent.LootMage).Items) do
	Weapons.Items[itemId] = stats
end

-- Числа удара для предмета: {damage, speed, recovery, range, arc, stagger}.
-- itemId может быть nil — тогда по типу и редкости.
function Weapons.stats(typeId: string, rarityId: string?, itemId: string?)
	local item = itemId and Weapons.Items[itemId]
	if item then
		return item
	end
	local weaponType = Weapons.Types[typeId] or Weapons.Types.sword
	local rarity = Rarities.get(rarityId or "common")
	return {
		damage = weaponType.damageMultiplier * (rarity and rarity.damageMultiplier or 1),
		speed = weaponType.speedMultiplier,
		recovery = weaponType.recovery,
		range = typeId == "hammer" and 6.5 or 6,
		arc = typeId == "hammer" and 120 or 100,
		stagger = 0,
	}
end

-- Заточка: +3% урона за уровень, максимум 10 уровней (всего +30%).
Weapons.MaxSharpening = 10
Weapons.SharpeningStep = 0.03

-- Стоимость уровня заточки n: 60 × 1.35^(n−1). Лестница ~3275 золота.
function Weapons.sharpeningCost(level: number): number
	if level < 1 or level > Weapons.MaxSharpening then
		return 0
	end
	return math.floor(60 * (1.35 ^ (level - 1)) + 0.5)
end

function Weapons.sharpeningMultiplier(level: number): number
	local clamped = math.clamp(level, 0, Weapons.MaxSharpening)
	return 1 + Weapons.SharpeningStep * clamped
end

-- Итоговый урон оружия.
-- baseDamage — урон класса на текущем уровне (уже с ростом за уровень).
-- itemId (необязательно) — id предмета: тогда множитель из Weapons.Items.
function Weapons.damage(baseDamage: number, typeId: string, rarityId: string, sharpening: number?, itemId: string?): number
	local item = itemId and Weapons.Items[itemId]
	if item then
		return baseDamage * item.damage * Weapons.sharpeningMultiplier(sharpening or 0)
	end
	local weaponType = Weapons.Types[typeId]
	local rarity = Rarities.get(rarityId)
	assert(weaponType, "unknown weapon type: " .. tostring(typeId))
	assert(rarity, "unknown rarity: " .. tostring(rarityId))
	return baseDamage
		* weaponType.damageMultiplier
		* rarity.damageMultiplier
		* Weapons.sharpeningMultiplier(sharpening or 0)
end

-- Интервал между ударами. speedMultiplier > 1 значит «быстрее».
function Weapons.attackInterval(baseInterval: number, typeId: string, attackSpeedBonus: number?, itemId: string?): number
	local item = itemId and Weapons.Items[itemId]
	local weaponType = Weapons.Types[typeId]
	assert(item or weaponType, "unknown weapon type: " .. tostring(typeId))
	local bonus = 1 + (attackSpeedBonus or 0)
	local speed = item and item.speed or weaponType.speedMultiplier
	return baseInterval / (speed * bonus)
end

-- Пауза перед следующим ударом после завершающего удара серии.
function Weapons.finisherInterval(interval: number, typeId: string, recoveryBase: number, itemId: string?): number
	local item = itemId and Weapons.Items[itemId]
	local weaponType = Weapons.Types[typeId]
	local recovery = (item and item.recovery) or (weaponType and weaponType.recovery) or 1
	return interval + recoveryBase * recovery
end

-- Сравнение оружия для «лучше / хуже»: урон × скорость (в секунду) без
-- учёта способности. Нужен интерфейсу и автоэкипировке находки.
function Weapons.rating(typeId: string, rarityId: string, sharpening: number?, itemId: string?): number
	local item = itemId and Weapons.Items[itemId]
	if item then
		return item.damage * item.speed * Weapons.sharpeningMultiplier(sharpening or 0)
	end
	local weaponType = Weapons.Types[typeId]
	local rarity = Rarities.get(rarityId)
	if not weaponType or not rarity then
		return 0
	end
	return weaponType.damageMultiplier
		* weaponType.speedMultiplier
		* rarity.damageMultiplier
		* Weapons.sharpeningMultiplier(sharpening or 0)
end

return Weapons


