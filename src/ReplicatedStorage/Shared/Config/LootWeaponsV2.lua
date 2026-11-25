--!nonstrict
-- LootWeaponsV2 — переделка способностей мечей и молотов (07.11.2026, концепты одобрены Артёмом,
-- документ «Способности оружия — переделка»). Поля подмешиваются ПОВЕРХ способностей из
-- LootFloor2–5 (Loot.lua, в самом конце): что не названо здесь — остаётся как было.
-- Механика — Systems/WeaponAbilitiesV2 (и Chronicle для «Вспомнить»), картинка — Controllers/AbilityFxV2.
-- Числа урона — доли силы способности (урон оружия × ★ эха × бонус легендарки × таланты).

local LootWeaponsV2 = {}

LootWeaponsV2.Patches = {
	-- ===== Подтянуть визуал =====
	reap = {
		description = "Серп-волна вперёд на 16: 130% по линии (пробивает); цели гниют 3 с по 30% в секунду",
		waveRange = 16,
	},

	-- ===== Доработать =====
	-- Приливный молот: стена воды катится вперёд и толкает, разбивается лужей; в луже враги «размокшие».
	flood = {
		name = "Прилив",
		description = "Стена воды катится вперёд на 12: 160% и толкает на 5. Разбивается лужей R4,5 на 4 с: "
			.. "замедление 40%, враги в ней получают +20% урона",
		cooldown = 15,
		castTime = 0.7,
		slamAt = 0.35,
		waveLength = 12,
		waveHalfWidth = 3,
		waveTime = 0.6,
		waveDamage = 1.6,
		push = 5,
		puddleRadius = 4.5,
		puddleTime = 4,
		puddleTick = 0.5,
		puddleDamage = 0.15,
		slow = 0.4,
		soaked = 0.2,
		damageMultiplier = 2.8,
	},
	-- Секатор: два среза → лозы держат → большой «чик».
	prune = {
		description = "Два среза веером 120° по 110% (−8 брони, +20% урона по целям); на задетых вырастают лозы и "
			.. "держат 1,2 с; затем «чик» — лозы лопаются: 150% и +2 шипа «Цветения»",
		cooldown = 16,
		castTime = 0.6,
		vineAt = 0.6,
		vineTime = 1.2,
		bossVineTime = 0.4,
		snipAt = 1.8,
		snipDamage = 1.5,
		blooms = 2,
		damageMultiplier = 3.7,
	},
	-- Коса ловчего: рог метит добычу, гон по меткам, финальный взмах.
	last_hunt = {
		description = "Рог: до 4 врагов в R14 — добыча. Рывками от добычи к добыче: 120%, по добыче вдвое. "
			.. "Финал — взмах R6: 160% и замедление 45%. Нет добычи — рывок на 13",
		cooldown = 15,
		castTime = 0.4,
		hornAt = 0.3,
		hornRadius = 14,
		targets = 4,
		hopTime = 0.17,
		hopGap = 0.07,
		hopDamage = 1.2,
		preyBonus = 1,
		finaleRadius = 6,
		finaleDamage = 1.6,
		slow = 0.45,
		slowTime = 2,
		dashDistance = 13,
		halfWidth = 3.2,
		damageMultiplier = 4,
	},
	-- Молот-тигель: механика та же (звуки на высоте), анимация опрокидывания и струя металла.
	spill = {
		description = "Тигель над головой — и опрокинут вперёд: струя расплава, три лужи вспыхивают по линии "
			.. "(120%, подброс), горят 3 с: 20% каждые 0,5 с и замедление 30%",
	},
	-- Раскалённый клинок: + финал серии во время перекала — большой взрыв.
	overheat = {
		description = "Волна жара 110% R6; 5 с клинок раскалён: каждый удар взрывается (+50% удара R3,5, ожог 3 × 15%), "
			.. "финал серии — большой взрыв 100% R4",
		finaleDamage = 1.0,
		finaleRadius = 4,
	},
	-- Шлаковая коса: вместо двух оборотов — смерч 2,2 с.
	slag_reap = {
		name = "Шлаковый смерч",
		description = "2,2 с вращения на ходу: 6 ударов по 55% R6, комья шлака застывают лужами (замедление 40%, "
			.. "18% каждые 0,5 с). Финал — коса в землю: 200% R7, −6 брони на 6 с",
		cooldown = 15,
		castTime = 2.5,
		spinTime = 2.2,
		spins = 6,
		spinStart = 0.2,
		spinDamage = 0.55,
		radius = 6,
		globsPerSpin = 2,
		globDistance = 6,
		globFlight = 0.4,
		globRadius = 2.6,
		globTime = 3,
		globTick = 0.5,
		globDamage = 0.18,
		slow = 0.4,
		slowTime = 0.6,
		slamAt = 2.35,
		slamRadius = 7,
		slamDamage = 2.0,
		armorBreak = 6,
		armorBreakDuration = 6,
		launchHeight = 2,
		launchTime = 0.6,
		damageMultiplier = 5.3,
	},
	-- Перо хрониста: две строки крестом, центр креста — двойной урон.
	inscribe = {
		description = "Перо пишет две строки крестом по 16 (ширина 6): руны взрываются по очереди — 150% и "
			.. "оглушение 0,8 с; в центре креста — ещё 150%",
		cooldown = 14,
		castTime = 0.7,
		writeAt = 0.15,
		writeTime = 0.5,
		length = 16,
		halfWidth = 3,
		crossAngle = 45,
		crossAhead = 8,
		runes = 6,
		runeInterval = 0.06,
		detonateDelay = 0.35,
		damage = 1.5,
		stun = 0.8,
		centerRadius = 2.8,
		centerDamage = 1.5,
		damageMultiplier = 3,
	},
	-- Чернильный клинок: веер → жгуты стягивают помеченных → клякса.
	ink_splash = {
		name = "Чернильный прилив",
		description = "Веер чернил 140° на 10,5: 120% и пятно. Жгуты стягивают всех с пятнами в R12 в точку "
			.. "впереди; клякса R5: 100% + 40% за каждое пятно, замедление 40%",
		cooldown = 14,
		castTime = 0.6,
		splashAt = 0.3,
		radius = 10.5,
		halfAngle = 70,
		damage = 1.2,
		pullAt = 0.6,
		pullRadius = 12,
		pullAhead = 6,
		pullTime = 0.9,
		burstAt = 1.6,
		burstRadius = 5,
		burstDamage = 1.0,
		perStain = 0.4,
		slow = 0.4,
		slowTime = 2.5,
		damageMultiplier = 3.6,
	},

	-- ===== Переделать с нуля =====
	-- Клинок сокольничего: сокол кружит 4 с и пикирует на тех, кого вы бьёте; финальное пике.
	dive = {
		name = "Соколиная охота",
		description = "Сокол кружит над боем 4 с: ваши попадания посылают его в пике (120% R4, подброс, до 3 раз). "
			.. "Финальное пике на сильнейшего врага рядом: 220% R6",
		cooldown = 13,
		castTime = 0.45,
		callAt = 0.3,
		huntTime = 4,
		dives = 3,
		diveGap = 0.9,
		diveTime = 0.35,
		diveRadius = 4,
		diveDamage = 1.2,
		finalRange = 15,
		finalRadius = 6,
		finalDamage = 2.2,
		launchHeight = 2.5,
		launchTime = 0.6,
		damageMultiplier = 5.8,
	},
	-- Клинок горна: клинок в землю → 5 трещин и огненные столбы → горящий клинок 6 с.
	forge_breath = {
		name = "Горнило",
		description = "Клинок в землю: 5 лавовых трещин веером 120° на 12, из каждой бьёт огонь — 90% и подброс. "
			.. "6 с клинок горит: удары ставят по 2 угля, финал серии бросает огненную дугу 120% на 10",
		cooldown = 15,
		castTime = 0.9,
		plungeAt = 0.4,
		fissures = 5,
		fan = 120,
		length = 12,
		halfWidth = 1.6,
		eruptAt = 0.65,
		eruptGap = 0.1,
		eruptDamage = 0.9,
		launchHeight = 2.5,
		launchTime = 0.6,
		bladeTime = 6,
		arcLength = 10,
		arcHalfWidth = 2,
		arcDamage = 1.2,
		damageMultiplier = 5.7,
	},
	-- Незавершённая отливка: расплав с неба → 3 кольца → клинок-призрак → пар.
	pour = {
		name = "Первая отливка",
		description = "Расплав льётся с неба в клинок: 3 кольца расплава по 140% (R5,5 → 10,5), затем раскалённый "
			.. "клинок-призрак рубит вперёд 300% (16 × 4) и пар взрывается 240% R9. Каждая ступень отливки — +25% финалу",
		cooldown = 15,
		castTime = 1.6,
		raiseAt = 0.1,
		ringAt = 0.55,
		ringGap = 0.2,
		rings = { 5.5, 8, 10.5 },
		ringDamage = 1.4,
		cleaveAt = 1.25,
		cleaveLength = 16,
		cleaveHalfWidth = 2,
		cleaveDamage = 3.0,
		steamAt = 1.5,
		steamRadius = 9,
		steamDamage = 2.4,
		stageBonus = 0.25,
		launchHeight = 3,
		launchTime = 0.8,
		damageMultiplier = 9.6,
	},
	-- Коса Забвения: круг забвения 2 с → круговой взмах, слабые стираются.
	erase = {
		name = "Забвение",
		description = "Коса чертит круг R10 на 2 с: мир внутри сереет, враги замедлены на 50% и стираются "
			.. "(20% каждые 0,25 с). Затем круговой взмах 250%: враг ниже 30% здоровья стёрт, боссам +60%",
		cooldown = 17,
		castTime = 0.6,
		drawAt = 0.35,
		radius = 10,
		fieldTime = 2,
		tick = 0.25,
		tickDamage = 0.2,
		slow = 0.5,
		finalDamage = 2.5,
		executeBelow = 0.3,
		bossBonus = 0.6,
		damageMultiplier = 4.1,
	},
	-- Клинок Памяти: двойники всегда отыгрывают не меньше 6 ударов, финал «Сшивка».
	recall = {
		description = "Два двойника повторяют ваши удары за 5 с по 70% (меньше 6 ударов — добивают полной серией), "
			.. "затем «Сшивка»: рывками крест-накрест 2 × 180% и взрыв памяти 250% R6",
		replayScale = 0.7,
		minSwings = 6,
		finaleGap = 0.3,
		dashLength = 10,
		dashHalfWidth = 1.8,
		dashDamage = 1.8,
		dashTime = 0.22,
		burstAhead = 4,
		burstRadius = 6,
		burstDamage = 2.5,
		damageMultiplier = 14,
	},
}

return LootWeaponsV2
