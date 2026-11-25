--!nonstrict
-- Echo
-- Прокачка снаряжения в Кузне Эха (заменяет заточку за золото).
--
-- Повторка (эхо) — ТОЧНО ТОТ ЖЕ предмет (тот же itemId и та же редкость).
-- Выпавший дубль не занимает место в инвентаре: он превращается в +1 эхо
-- на карточке этого предмета. В Кузне эхо вплавляют в предмет: ★1 → ★2 → …
-- Эхо сверх потолка редкости автоматически плавится в «Пыль эха» (валюта).
--
-- Все числа — здесь. Сервер считает, клиент только показывает.

local Echo = {}

-- Потолок уровня по редкости.
Echo.MaxLevel = {
	common = 5,
	rare = 6,
	epic = 7,
	legendary = 8,
	mythic = 9,
	secret = 10,
}

-- Множитель редкости для платы золотом и для пыли.
Echo.RarityFactor = {
	common = 1,
	rare = 1.5,
	epic = 2,
	legendary = 3,
	mythic = 4,
	secret = 5,
}

-- Сколько эха нужно, чтобы поднять уровень n → n+1 (индекс = n).
Echo.EchoCost = { 1, 2, 4, 6, 9, 12, 16, 20, 25 }

-- Базовый шанс крита по редкости (доля), прирост за уровень и множитель крита.
Echo.BaseCrit = {
	common = 0,
	rare = 0.02,
	epic = 0.04,
	legendary = 0.06,
	mythic = 0.08,
	secret = 0.10,
}
Echo.CritPerLevel = 0.01
Echo.CritMultiplier = 1.5

Echo.DamagePerLevel = 0.10 -- оружие: +10% урона за уровень
Echo.AbilityPerLevel = 0.12 -- способность оружия: +12% урона за уровень
Echo.CooldownMilestones = { [4] = 0.10, [8] = 0.10 } -- на ★4 и ★8 перезарядка −10% (суммируется)
Echo.SoulSocketLevel = 3 -- гнездо для души босса открывается на ★3

Echo.ArmorHpPerLevel = 0.06 -- броня: +6% HP за уровень
Echo.BaseReduction = { -- броня: снижение урона по редкости
	common = 0,
	rare = 0.02,
	epic = 0.04,
	legendary = 0.06,
	mythic = 0.08,
	secret = 0.10,
}
Echo.ReductionPerLevel = 0.01
Echo.ReductionCap = 0.25

Echo.GoldFeeBase = 40 -- плата: 40 × n × множитель редкости
Echo.DustPerEcho = 5 -- пыль за 1 лишнее эхо: 5 × множитель редкости

function Echo.maxLevel(rarityId: string): number
	return Echo.MaxLevel[rarityId] or 5
end

-- Цена подъёма с уровня n: эхо и золото. nil, если уже потолок.
function Echo.cost(level: number, rarityId: string)
	if level >= Echo.maxLevel(rarityId) then
		return nil
	end
	return {
		echoes = Echo.EchoCost[level] or math.huge,
		gold = math.floor(Echo.GoldFeeBase * level * (Echo.RarityFactor[rarityId] or 1) + 0.5),
	}
end

-- Всего эха до уровня target с ★1.
function Echo.totalEchoes(target: number): number
	local sum = 0
	for n = 1, target - 1 do
		sum += Echo.EchoCost[n] or 0
	end
	return sum
end

function Echo.damageMultiplier(level: number): number
	return 1 + Echo.DamagePerLevel * (math.max(level, 1) - 1)
end

function Echo.critChance(level: number, rarityId: string): number
	return (Echo.BaseCrit[rarityId] or 0) + Echo.CritPerLevel * (math.max(level, 1) - 1)
end

function Echo.abilityMultiplier(level: number): number
	return 1 + Echo.AbilityPerLevel * (math.max(level, 1) - 1)
end

function Echo.cooldownMultiplier(level: number): number
	local cut = 0
	for milestone, value in pairs(Echo.CooldownMilestones) do
		if level >= milestone then
			cut += value
		end
	end
	return 1 - cut
end

function Echo.armorHpMultiplier(level: number): number
	return 1 + Echo.ArmorHpPerLevel * (math.max(level, 1) - 1)
end

function Echo.damageReduction(level: number, rarityId: string): number
	local value = (Echo.BaseReduction[rarityId] or 0) + Echo.ReductionPerLevel * (math.max(level, 1) - 1)
	return math.min(value, Echo.ReductionCap)
end

function Echo.dustFor(echoes: number, rarityId: string): number
	return math.floor(echoes * Echo.DustPerEcho * (Echo.RarityFactor[rarityId] or 1) + 0.5)
end

-- Крит при ударе (сервер): возвращает множитель урона и флаг крита.
function Echo.rollCrit(level: number, rarityId: string, rng: Random?)
	local r = rng and rng:NextNumber() or math.random()
	if r < Echo.critChance(level, rarityId) then
		return Echo.CritMultiplier, true
	end
	return 1, false
end

return Echo
