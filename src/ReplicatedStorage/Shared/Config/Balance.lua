--!nonstrict
-- Balance
-- Ребаланс врагов по этажам (приложение Б плана). Только числа и чистые
-- функции: их применяет Enemies.stats, сервер ничего не считает сам.
--
-- Было: числа врагов не зависели от этажа, и на этаже 5 мобы имели 30–100
-- здоровья и били на 10–18 — обычное оружие проходило игру насквозь.
-- Стало: этажу дан эталон плана (здоровье и удар моба, танк, босс), а тип
-- врага масштабируется к эталону своего этажа:
--   обычные мобы — здоровье × health этажа, броня не ниже mobArmor;
--   танки        — здоровье не ниже 1,5 × моб плана (элита ×1,6),
--                  броня 10 + 3 × (этаж − 1) (элита +4);
--   мини-боссы   — здоровье не ниже 4,5 × моба плана, броня как у танка;
--   боссы        — здоровье по плану, броня как у танка, сильнейший удар
--                  к удару босса плана (с поправкой на уровень, см. LevelFactor);
--   урон мобов   — × damage этажа, но удар не выше hitCap (большие замахи
--                  «только рывок» не превращаются в ваншот).
-- Опыт растёт вместе со здоровьем (xp этажа) и сложностью (Difficulty.xp).
-- Объекты (знамя, баррикады, печати) не масштабируются.
--
-- Ручки: Balance.Global — общий множитель всем этажам; Balance.Override —
-- точные числа для одного типа (перекрывают правило).

local Balance = {}

-- Эталон плана по этажам (приложение Б).
Balance.Plan = {
	level = { 5, 10, 15, 20, 25 },
	mobHealth = { 90, 120, 145, 170, 200 },
	mobHit = { 20, 30, 40, 50, 60 },
	bossHealth = { 1000, 1350, 1650, 1950, 2250 },
	bossHit = { 50, 75, 100, 125, 150 },
}

-- Игрок приходит на этаж ниже уровнем, чем в эталоне (кривая опыта 100 × уровень):
-- этаж 2 ≈ 9-й уровень, 3 ≈ 11-й, 4 ≈ 13-й, 5 ≈ 15-й вместо 10/15/20/25.
-- Удар моба и босса подогнан к цели плана × (здоровье героя на реальном уровне /
-- здоровье на уровне плана). Здоровье врагов — по плану без поправки: чтобы
-- проходить верхние этажи, нужно оружие лучше обычного, ★ эха и древо.
Balance.LevelFactor = { 1.0, 0.96, 0.86, 0.79, 0.74 }

-- Множители этажей. health/damage — обычным мобам; mobArmor — минимум брони
-- моба; tankArmor — броня танка (элита +4), она же минимум для боссов;
-- hitCap — потолок одного удара моба после множителя; xp — опыт за убийство.
Balance.Floors = {
	[1] = { health = 1.00, damage = 1.00, mobArmor = 0, tankArmor = 10, hitCap = nil, xp = 1.00 },
	[2] = { health = 1.00, damage = 1.90, mobArmor = 1, tankArmor = 13, hitCap = 45, xp = 1.00 },
	[3] = { health = 1.35, damage = 2.00, mobArmor = 2, tankArmor = 16, hitCap = 52, xp = 1.35 },
	[4] = { health = 1.95, damage = 2.00, mobArmor = 2, tankArmor = 19, hitCap = 60, xp = 1.95 },
	[5] = { health = 2.25, damage = 3.50, mobArmor = 3, tankArmor = 22, hitCap = 68, xp = 2.25 },
}

Balance.Tank = { health = 1.5, elite = 1.6, eliteArmor = 4 }
Balance.MiniBoss = { health = 4.5, hit = 0.75 } -- здоровье × моба плана; сильнейший удар × удара босса
Balance.Global = { health = 1.0, damage = 1.0, xp = 1.0 }

-- Опыт по сложности (выбор у врат). Множители здоровья и урона — Enemies.Difficulty.
Balance.DifficultyXp = { normal = 1.0, abnormal = 1.5, impossible = 2.0 }

-- Точные числа для отдельных типов (перекрывают правило). Пример:
--   gatekeeper = { health = 720 },  -- вернуть Привратнику прежнее здоровье
Balance.Override = {
	-- Этаж 1 — эталон: Арбалетчица остаётся как была (её отражённый болт бьёт долей её здоровья).
	arbalest = { health = 380, armor = 4 },
}

-- Этаж каждого типа (объекты не масштабируются и в списке не нужны).
Balance.FloorOf = {
	-- 1 «Внешний двор»
	guard = 1, shade = 1, archer = 1, knight = 1, martyr = 1, guard_elite = 1, knight_elite = 1,
	arbalest = 1, centurion = 1, gatekeeper = 1,
	-- 2 «Затопленные сады»
	bee = 2, drowned = 2, gardener = 2, ranger = 2, treant = 2, rosewarden = 2,
	-- 3 «Псарни охоты»
	hound = 3, beater = 3, beater_elite = 3, trapper = 3, crossbowman = 3, falcon = 3, falconer = 3,
	bear_hunter = 3, bear_hunter_elite = 3, skinner = 3, tanner = 3, torchbearer = 3, trophy_bear = 3,
	pack_leader = 3, royal_huntsman = 3,
	-- 4 «Литейная»
	fire_spirit = 4, smolder = 4, slag_thrower = 4, forge_automaton = 4, elder_founder = 4,
	-- 5 «Архив»
	ink_blot = 5, ink_scribe = 5, seal_mage = 5, shelf_warden = 5, stone_reader = 5, bookbinder = 5,
	chief_chronicler = 5,
}

-- Сильнейший удар типа (атаки и фазы; damagePct не в счёт).
function Balance.maxHit(enemyType): number
	local best = 0
	local function scan(list)
		for _, attack in ipairs(list or {}) do
			if type(attack.damage) == "number" and attack.damage > best then
				best = attack.damage
			end
		end
	end
	scan(enemyType.attacks)
	for _, phase in ipairs(enemyType.phases or {}) do
		scan(phase.attacks)
	end
	return best
end

local function round(v: number): number
	return math.floor(v + 0.5)
end

-- Масштаб типа: { floor, health, armor, damage (множитель), hitCap, xp (множитель) }.
-- health и armor — итоговые числа до множителя сложности.
function Balance.scale(typeId: string, enemyType)
	local floor = Balance.FloorOf[typeId]
	local result = {
		floor = floor,
		health = enemyType.health,
		armor = enemyType.armor or 0,
		damage = 1,
		hitCap = nil,
		xp = 1,
	}
	if enemyType.role == "object" or not floor or not Balance.Floors[floor] then
		return result
	end
	local f = Balance.Floors[floor]
	local plan = Balance.Plan
	local role = enemyType.role
	local elite = enemyType.elite == true
	local armor = enemyType.armor or 0
	if role == "boss" then
		result.health = math.max(enemyType.health, plan.bossHealth[floor])
		result.armor = math.max(armor, f.tankArmor)
		local hit = Balance.maxHit(enemyType)
		local target = plan.bossHit[floor] * Balance.LevelFactor[floor]
		result.damage = hit > 0 and math.max(1, target / hit) or 1
	elseif role == "miniboss" then
		result.health = math.max(enemyType.health, Balance.MiniBoss.health * plan.mobHealth[floor])
		result.armor = math.max(armor, f.tankArmor)
		local hit = Balance.maxHit(enemyType)
		local target = Balance.MiniBoss.hit * plan.bossHit[floor] * Balance.LevelFactor[floor]
		result.damage = hit > 0 and math.clamp(target / hit, 1, math.max(f.damage, 1)) or 1
	elseif role == "tank" then
		local want = Balance.Tank.health * plan.mobHealth[floor] * (elite and Balance.Tank.elite or 1)
		result.health = math.max(enemyType.health, want)
		result.armor = math.max(armor, f.tankArmor + (elite and Balance.Tank.eliteArmor or 0))
		result.damage = f.damage
		result.hitCap = f.hitCap
	else
		result.health = enemyType.health * f.health
		result.armor = math.max(armor, f.mobArmor)
		result.damage = f.damage
		result.hitCap = f.hitCap
	end
	result.xp = f.xp

	local override = Balance.Override[typeId]
	if override then
		for key, value in pairs(override) do
			result[key] = value
		end
	end
	result.health = round(result.health * Balance.Global.health)
	result.damage *= Balance.Global.damage
	result.xp *= Balance.Global.xp
	return result
end

-- Урон одной атаки после множителя этажа: не выше потолка, но и не ниже исходного.
function Balance.attackDamage(damage: number, scale): number
	local value = damage * (scale.damage or 1)
	if scale.hitCap then
		value = math.min(value, math.max(damage, scale.hitCap))
	end
	return round(value)
end

return Balance
