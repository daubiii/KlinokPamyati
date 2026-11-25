--!nonstrict
-- Combat
-- Числа боевой системы: рывок, парирование, броня, лечение, дебафы.
-- Раздел 3 плана и приложение Б. Никакой логики — только параметры и формулы.

local Combat = {}

-- Рывок (уклонение).
-- iFrames и cooldown заданы планом (0.3 / 0.8). Скорость и длительность
-- подобраны по отзыву с плейтеста: рывок должен быть резким и покрывать
-- около 11.5 стадов при номинале 72 × 0.16. Правятся свободно.
Combat.Dodge = {
	iFrames = 0.3,
	cooldown = 0.8,
	dashSpeed = 72,
	dashDuration = 0.16,
	maxDistance = 14, -- потолок для серверной проверки «не телепорт»
	distanceTolerance = 1.5, -- запас на пинг и инерцию
	verticalKeep = 0, -- по вертикали рывок не летит
}

-- Парирование. Окно своё у каждого класса (приложение Б),
-- здесь — общие правила.
Combat.Parry = {
	failPause = 1.0,
	successStun = 1.2, -- раздел 3: оглушение 1-1,5 с (у босса своя цифра, 1,5 с)
	successStunBonus = 0.3, -- прибавка от узла «Щитовой удар»
	counterDamageMultiplier = 2.0,
	requiresTelegraph = true, -- парируются только белые и жёлтые атаки
}

-- Атака и комбо (раздел 3).
-- hitInterval — базовая пауза между ударами комбо для оружия со скоростью 1.0.
-- comboWindow — сколько ждём следующий удар, прежде чем комбо начнётся заново.
-- Ритм серии (правка 21.10.2026: «закликиваешь как бешеный»): два быстрых
-- удара и тяжёлый третий (×finisherMultiplier), после него — восстановление
-- comboRecovery × recovery оружия, когда новый удар не начать.
Combat.Attack = {
	comboLength = 3,
	hitInterval = 0.45,
	comboWindow = 0.7,
	comboRecovery = 0.55,
	finisherMultiplier = 1.3,
	range = 6,
	arcDegrees = 100,
}

-- Замах врага (раздел 3): видно цвет, потом удар, потом пауза восстановления.
Combat.Enemy = {
	windupParryable = 0.6,
	windupDodgeOnly = 0.5,
	recoverTime = 0.9,
	idleBetweenAttacks = 1.2,
	attackRange = 9,
	engageRange = 30,
	vulnerableMultiplier = 1.0,
	-- Сколько врагов одновременно могут замахиваться. Толпа не должна бить
	-- одним залпом: план требует «опасны связки и позиционка», а не число.
	-- Это ручка баланса для контрольной точки, а не жёсткое правило.
	maxSimultaneousAttackers = 2,
	-- Ближний удар врага попадает, только если игрок перед ним (в конусе) и
	-- в пределах дальности + запас на пинг. Так «позиционка» работает:
	-- боковой шаг во время замаха спасает от удара.
	strikeArcDegrees = 140,
	hitSlop = 1.5,
	playerRadius = 0.8,
	-- Враг перестаёт доворачиваться к игроку за эту долю замаха до удара.
	lockFacingAt = 0.55,
}

-- Обратная связь по ощущениям (раздел 11): только числа эффектов.
Combat.Feel = {
	hitStop = 0.04,
	parryStop = 0.06,
	parryShake = 0.1,
	hitShake = 0.08,
}

-- Броня. Формула Dota: урон делится на (1 + 0.06 × броня).
Combat.Armor = {
	coefficient = 0.06,
}

function Combat.Armor.mitigate(rawDamage: number, armor: number): number
	local reduced = rawDamage / (1 + Combat.Armor.coefficient * math.max(armor, 0))
	return math.max(reduced, 0)
end

-- Доля урона, которую съедает броня (для интерфейса).
function Combat.Armor.reduction(armor: number): number
	return 1 - 1 / (1 + Combat.Armor.coefficient * math.max(armor, 0))
end

-- Лечение и дебафы (приложение Б).
Combat.Heal = {
	charges = 3,
	percentOfMaxHealth = 0.35,
}

Combat.Debuffs = {
	maxSimultaneous = 2,
	slow = { magnitude = 0.30, duration = 3 },
	burn = { percentPerSecond = 0.10, duration = 4 },
	poison = { percentPerSecond = 0.08, duration = 6, leavesAtOneHealth = true },
	armorBreak = { amount = 5, duration = 6 },
}

-- Состояния атаки врага (раздел 3): замах виден цветом, затем удар.
Combat.Telegraph = {
	parryable = { Color3.fromHex("#D9D2C5"), Color3.fromHex("#E8DCC0") }, -- белая и жёлтая
	dodgeOnly = Color3.fromHex("#E5484D"), -- красная: только уклонение
	windupMin = 0.4,
	windupMax = 0.8,
}

-- Вертикальная скорость, которую разрешено сохранять при рывке.
Combat.Dodge.keepVertical = Combat.Dodge.verticalKeep

return Combat
