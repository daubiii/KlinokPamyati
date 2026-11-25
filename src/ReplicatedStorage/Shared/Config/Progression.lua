--!nonstrict
-- Progression
-- Опыт, уровни и временные стаки душ. Приложения Б и Е нового плана.
--
-- Опыт: до следующего уровня = 100 × текущий уровень.
-- Уровень даёт статы по приложению Б (через Classes.statsAtLevel).
-- Стаки душ мобов временные: сбрасываются при смерти и в конце забега.

local Classes = require(script.Parent.Classes)

local Progression = {}

Progression.StartLevel = 5 -- эталонный воин этажа 1 (приложение Б)
Progression.MaxLevel = Classes.MaxLevel

Progression.SoulStacks = {
	max = 40,
	perStack = {
		damage = 0.01,
		attackSpeed = 0.006,
		moveSpeed = 0.00375,
	},
	caps = {
		damage = 0.40,
		attackSpeed = 0.24,
		moveSpeed = 0.15,
	},
}

function Progression.xpToNext(level: number): number
	return 100 * math.max(level, 1)
end

-- Предел душ: база + надбавка «Прилива душ» (дар этажа, FloorBoons).
function Progression.maxStacks(capBonus: number?): number
	return Progression.SoulStacks.max + math.max(capBonus or 0, 0)
end

-- Суммарные бонусы от стаков. capBonus — надбавка к пределу душ: потолки
-- бонусов растут вместе с пределом (40 душ → +40% урона, 60 душ → +60%).
function Progression.stackBonuses(stacks: number, capBonus: number?)
	local max = Progression.maxStacks(capBonus)
	local count = math.clamp(stacks or 0, 0, max)
	local perStack = Progression.SoulStacks.perStack
	local caps = Progression.SoulStacks.caps
	local k = max / Progression.SoulStacks.max
	return {
		damage = math.min(count * perStack.damage, caps.damage * k),
		attackSpeed = math.min(count * perStack.attackSpeed, caps.attackSpeed * k),
		moveSpeed = math.min(count * perStack.moveSpeed, caps.moveSpeed * k),
	}
end

-- Применить уровень к персонажу: HP, броня, урон оружия.
function Progression.statsFor(className: string, level: number)
	return Classes.statsAtLevel(className, level)
end

return Progression
