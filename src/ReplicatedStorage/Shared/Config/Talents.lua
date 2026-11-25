--!nonstrict
-- Talents
-- Древо талантов (приложение В плана). Игрок видит ОДНО древо — своего класса
-- («Древо воина», «Древо мага»). В древе три пути (у воина — Защита, Натиск,
-- Парирование; у мага — Источник, Посох, Чары), в каждом 22 узла:
--   14 малых узлов (1 очко, слабые: +1,5% здоровья, +1 броня…),
--    5 узлов (1 очко, заметные),
--    3 ключевых узла (5 очков, меняют игру).
-- Путь — 34 очка, древо — 102. Очко даётся за каждый уровень после первого;
-- потолок уровня 60 (Config/Classes, статы растут до 30) — на 60-м 59 очков,
-- то есть целиком берутся полтора-два пути из трёх.
-- Узлы только пассивные: активные умения дают души боссов и оружие.
--
-- Только числа, раскладка и чистые функции (их зовут и сервер, и клиент, и тесты).
-- Применение эффектов — ServerScriptService/Systems/TalentMods и TalentService.
--
-- Поля узла:
--   id, name, text   — подпись и описание (их видит игрок);
--   slot             — место в пути (Talents.Layout): a1..r6 малые, N1..N5 узлы, K1..K3 ключевые;
--   needs            — нужен ЛЮБОЙ из этих узлов (у a1 — ничего);
--   effects          — числа для TalentMods (ключи описаны в Talents.Effects);
--   icon             — кусок атласа Config/TalentAtlas (малые узлы — глиф g_*);
--   source           — "plan" (как в плане), "changed" (число изменено после
--                      проверки баланса, plan — как было), "new" (узла в плане не было).

local Talents = {}

-- Версия древа. Сохранённые узлы другой версии возвращаются бесплатно (TalentMods.entry):
-- v1 — 3 × 8 узлов до 30-го уровня, v2 — 3 × 22 узла до 60-го.
Talents.Version = 2
Talents.MaxLevel = 60
Talents.Costs = { minor = 1, normal = 1, key = 5 }
Talents.Kinds = { minor = "Малый узел", normal = "Узел", key = "Ключевой узел" }

-- Сброс за золото (план: «Сброс за золото»; цена — наша): первый бесплатно,
-- дальше 25 золота за каждое потраченное очко, не меньше 50. Только в долине.
Talents.Reset = { goldPerPoint = 25, minGold = 50, firstFree = true, hubOnly = true }

-- Раскладка пути (снизу вверх). x — сдвиг от центра пути в шагах (шаг 105 дизайн-px),
-- y — дизайн-пиксели листа древа (1120 × 748, Windows/TalentPage):
--
--        K2              K3        ← ключевые концов путей (5 очков)
--        l6              r6
--        l5              r5
--        N4              N5
--        l4      K1      r4        ← K1: ключевой середины (нужен l2 или r2)
--        l3   l2    r2   r3
--        N2              N3
--            l1      r1
--                N1
--                a2
--                a1                ← вход в путь
Talents.Layout = {
	a1 = { x = 0, y = 654 },
	a2 = { x = 0, y = 610 },
	N1 = { x = 0, y = 556 },
	l1 = { x = -0.55, y = 512 },
	r1 = { x = 0.55, y = 512 },
	N2 = { x = -1, y = 470 },
	N3 = { x = 1, y = 470 },
	l2 = { x = -0.48, y = 424 },
	r2 = { x = 0.48, y = 424 },
	K1 = { x = 0, y = 372 },
	l3 = { x = -1, y = 416 },
	l4 = { x = -1, y = 372 },
	N4 = { x = -1, y = 318 },
	r3 = { x = 1, y = 416 },
	r4 = { x = 1, y = 372 },
	N5 = { x = 1, y = 318 },
	l5 = { x = -1, y = 264 },
	l6 = { x = -1, y = 220 },
	K2 = { x = -1, y = 160 },
	r5 = { x = 1, y = 264 },
	r6 = { x = 1, y = 220 },
	K3 = { x = 1, y = 160 },
}
-- Порядок слотов: каждый узел идёт после своих предшественников.
Talents.Order = {
	"a1", "a2", "N1", "l1", "r1", "N2", "N3", "l2", "r2", "K1",
	"l3", "l4", "N4", "r3", "r4", "N5", "l5", "l6", "K2", "r5", "r6", "K3",
}
Talents.Needs = {
	a1 = {},
	a2 = { "a1" },
	N1 = { "a2" },
	l1 = { "N1" },
	r1 = { "N1" },
	N2 = { "l1" },
	N3 = { "r1" },
	l2 = { "N2" },
	r2 = { "N3" },
	K1 = { "l2", "r2" },
	l3 = { "N2" },
	l4 = { "l3" },
	N4 = { "l4" },
	r3 = { "N3" },
	r4 = { "r3" },
	N5 = { "r4" },
	l5 = { "N4" },
	l6 = { "l5" },
	K2 = { "l6" },
	r5 = { "N5" },
	r6 = { "r5" },
	K3 = { "r6" },
}
-- Малые узлы пути — три вида (A, B, C) по слотам: A × 5, B × 5, C × 4.
Talents.MinorPattern = {
	a1 = "A", a2 = "B", l1 = "A", r1 = "C", l2 = "B", r2 = "C", l3 = "A",
	l4 = "B", r3 = "C", r4 = "A", l5 = "B", l6 = "A", r5 = "C", r6 = "B",
}

-- Ключи effects (одинаковые ключи разных узлов складываются).
Talents.Effects = {
	maxHealthPct = "доля к максимальному здоровью",
	armor = "плоская броня",
	healPct = "к доле лечения заряда (база 0,35)",
	debuffTime = "к длительности дебафов на герое (−0,2 = −20%)",
	moveSpeed = "к скорости бега (0,01 = +1%)",
	retaliateBonus = "после полученного урона следующий удар × (1 + bonus)",
	retaliateCooldown = "перезарядка «Ответного удара», с",
	soulArmorPer = "стаков душ на 1 броню",
	soulArmorMax = "потолок брони от стаков",
	cheatDeath = "раз за забег смертельный удар оставляет 1 здоровья",
	cheatDeathInvuln = "неуязвимость после спасения, с",
	weaponDamagePct = "доля к урону оружия (у мага — посоха)",
	attackSpeed = "к скорости атаки (0,05 = +5%)",
	critChance = "к шансу крита (0,01 = +1%), крит ×1,5 как у эха",
	stunnedBonus = "доля к урону по оглушённым",
	finisherBonus = "доля к урону третьего удара комбо",
	soulDamagePer = "урон за стак душ сверх обычного",
	soulDamageMax = "потолок урона от «Силы душ»",
	shredPerHit = "броня врага за удар",
	shredMax = "потолок стаков «Разрушителя»",
	shredTime = "время жизни стаков, с",
	killHaste = "скорость атаки после убийства",
	killHasteTime = "длительность, с",
	abilityCooldown = "к перезарядке способностей оружия и заклинаний (−0,2 = на 20% быстрее)",
	abilityDamage = "доля к урону способностей оружия и заклинаний",
	parryWindow = "к окну парирования (барьера), с",
	parryStun = "к оглушению после парирования, с",
	failPause = "к паузе после промаха парирования, с",
	counterBonus = "к множителю контратаки (база ×2,0)",
	parrySpeed = "скорость бега после парирования",
	parrySpeedTime = "длительность, с",
	reflectBonus = "к множителю урона отражённого снаряда",
	parryArmor = "броня после парирования",
	parryArmorTime = "длительность, с",
	parryEchoRadius = "радиус оглушения врагов вокруг после парирования",
	parryEchoStun = "длительность этого оглушения, с",
	maxManaPct = "доля к максимуму маны",
	maxMana = "плоская мана",
	manaRegen = "к восстановлению маны в секунду",
	lowManaRegen = "мана ниже 25% — восстановление × (1 + значение)",
	castTime = "к времени чтения заклинания (−0,15 = −15%)",
	spellCost = "к цене заклинаний (−0,1 = −10%)",
	killMana = "мана за убийство",
	freeEvery = "каждое N-е заклинание бесплатно",
	empower = "после заклинания следующий удар посохом × (1 + значение)",
	projectileSpeed = "к скорости полёта снарядов посоха (0,03 = +3%)",
	projectileRange = "к дальности снарядов посоха",
	homing = "самонаведение снарядов посоха, °/с (у посохов с наведением — не меньше этого)",
	pierce = "снаряд посоха пробивает ещё столько врагов",
	pierceShare = "доля урона по врагам после первого пробития",
	splitEvery = "каждое N-е попадание снаряда посоха раскалывает его",
	splitShards = "осколков при расколе",
	splitShare = "доля урона осколка",
	veilCooldown = "к перезарядке «Покрова», с",
	veilDuration = "к длительности «Покрова», с",
	veilSpeed = "скорость бега в «Покрове»",
	ambushBonus = "к множителю удара из «Покрова» (база ×1,5)",
	veilShield = "щит после «Покрова», доля здоровья",
	veilShieldTime = "время щита, с",
	barrierRefund = "к мане за удачный барьер (база 15)",
	armorPierce = "удары и заклинания игнорируют столько брони врага",
}

local function node(slot, id, name, text, icon, effects, source, plan)
	return { slot = slot, id = id, name = name, text = text, icon = icon, effects = effects, source = source or "plan", plan = plan }
end
-- Вид малого узла: имя, описание, глиф, эффекты.
local function minor(name, text, glyph, effects)
	return { name = name, text = text, icon = glyph, effects = effects }
end

Talents.Classes = {
	warrior = {
		id = "warrior",
		name = "Воин",
		title = "ДРЕВО ВОИНА",
		prefix = "w",
		item = "helm", -- фирменный предмет класса на печати фона
		background = "bg_warrior",
		branches = {
			{
				id = "guard", name = "Защита", plan = "Страж", text = "Здоровье, броня и лечение",
				minor = {
					A = minor("Крепкое тело", "+1,5% максимального здоровья", "g_heart", { maxHealthPct = 0.015 }),
					B = minor("Заклёпки", "+1 броня", "g_plate", { armor = 1 }),
					C = minor("Перевязка", "Заряд лечения лечит ещё 1% здоровья", "g_cross", { healPct = 0.01 }),
				},
				nodes = {
					node("N1", "w_temper", "Закалка", "+6% максимального здоровья", "i_heart", { maxHealthPct = 0.06 }),
					node("N2", "w_plates", "Латы", "+3 брони", "i_plate", { armor = 3 }),
					node("N3", "w_stamina", "Выносливость", "Заряд лечения лечит 40% здоровья вместо 35%", "i_flask", { healPct = 0.05 }),
					node("K1", "w_retaliate", "Ответный удар", "После полученного урона следующая атака +50% (перезарядка 4 с)", "k_retaliate",
						{ retaliateBonus = 0.5, retaliateCooldown = 4 }, "changed", "+30%, перезарядка 6 с"),
					node("N4", "w_shieldwall", "Щитовая стена", "+4 брони и +4% здоровья", "i_towershield", { armor = 4, maxHealthPct = 0.04 }),
					node("N5", "w_steadfast", "Стойкость", "Дебафы на герое длятся на 20% меньше", "i_anchor", { debuffTime = -0.2 }),
					node("K2", "w_livingfort", "Живая крепость", "+1 броня за каждые 3 стака душ мобов, до +10", "k_fort",
						{ soulArmorPer = 3, soulArmorMax = 10 }),
					node("K3", "w_unbending", "Несгибаемый", "Раз за забег смертельный удар оставляет 1 здоровья и даёт 2 с неуязвимости", "k_unbending",
						{ cheatDeath = 1, cheatDeathInvuln = 2 }),
				},
			},
			{
				id = "blade", name = "Натиск", plan = "Клинок", text = "Урон, скорость атаки и пробой брони",
				minor = {
					A = minor("Заточка", "+1,5% урона оружия", "g_blade", { weaponDamagePct = 0.015 }),
					B = minor("Хватка", "+1% скорости атаки", "g_speed", { attackSpeed = 0.01 }),
					C = minor("Добивание", "Третий удар комбо +3% урона", "g_arc", { finisherBonus = 0.03 }),
				},
				nodes = {
					node("N1", "w_sharp", "Острый клинок", "+6% урона оружия", "i_sword", { weaponDamagePct = 0.06 }),
					node("N2", "w_quick", "Быстрая рука", "+5% скорости атаки", "i_gauntlet", { attackSpeed = 0.05 }),
					node("N3", "w_sweep", "Размах", "Третий удар комбо +15% урона", "i_arc", { finisherBonus = 0.15 }),
					node("K1", "w_master", "Мастер оружия", "Способность оружия перезаряжается на 20% быстрее и бьёт на 25% сильнее", "k_crossed",
						{ abilityCooldown = -0.2, abilityDamage = 0.25 }),
					node("N4", "w_souls", "Сила душ", "Каждый стак душ даёт ещё +0,2% урона, до +8%", "i_soulflame",
						{ soulDamagePer = 0.002, soulDamageMax = 0.08 }),
					node("N5", "w_precise", "Точный удар", "+15% урона по оглушённым врагам", "i_target",
						{ stunnedBonus = 0.15 }, "changed", "+8%"),
					node("K2", "w_fury", "Боевой раж", "После убийства +15% скорости атаки на 5 с", "k_fury",
						{ killHaste = 0.15, killHasteTime = 5 }, "changed", "+10% на 4 с"),
					node("K3", "w_breaker", "Разрушитель", "Удары снижают броню врага на 1 (до 6 стаков, 4 с)", "k_hammer",
						{ shredPerHit = 1, shredMax = 6, shredTime = 4 }, "changed", "до 8 стаков"),
				},
			},
			{
				id = "bastion", name = "Парирование", plan = "Бастион", text = "Окно парирования и ответный удар",
				minor = {
					A = minor("Внимание", "Окно парирования +0,005 с", "g_eye", { parryWindow = 0.005 }),
					B = minor("Ответ", "Контратака после парирования: +0,03 к множителю", "g_counter", { counterBonus = 0.03 }),
					C = minor("Лёгкие ноги", "+1% скорости бега", "g_boot", { moveSpeed = 0.01 }),
				},
				nodes = {
					node("N1", "w_keen", "Чуткость", "Окно парирования +0,03 с", "i_eye", { parryWindow = 0.03 }),
					node("N2", "w_quickshield", "Быстрый щит", "Пауза после промаха парирования 0,8 с вместо 1,0", "i_buckler", { failPause = -0.2 }),
					node("N3", "w_shieldbash", "Щитовой удар", "Оглушение после парирования +0,3 с", "i_bash", { parryStun = 0.3 }),
					node("K1", "w_reflect", "Отражение", "Отражённый снаряд наносит ×2 урона", "k_mirror", { reflectBonus = 1.0 }),
					node("N4", "w_footing", "Опора", "После парирования +10% скорости бега на 3 с", "i_boot",
						{ parrySpeed = 0.10, parrySpeedTime = 3 }),
					node("N5", "w_counter", "Контратака", "Удар после парирования ×2,2 вместо ×2,0", "i_counter", { counterBonus = 0.2 }),
					node("K2", "w_ironwill", "Железная воля", "После парирования +15 брони на 4 с", "k_helm",
						{ parryArmor = 15, parryArmorTime = 4 }, "changed", "+25 брони на 5 с"),
					node("K3", "w_shieldecho", "Эхо щита", "Удачное парирование оглушает врагов в радиусе 4 на 1 с (кроме боссов)", "k_rings",
						{ parryEchoRadius = 4, parryEchoStun = 1 }, "changed", "длительность и боссы не указаны"),
				},
			},
		},
	},
	mage = {
		id = "mage",
		name = "Маг",
		title = "ДРЕВО МАГА",
		prefix = "m",
		item = "hat",
		background = "bg_mage",
		branches = {
			{
				id = "source", name = "Источник", text = "Мана, восстановление и запас здоровья",
				minor = {
					A = minor("Капля чернил", "+2% максимальной маны", "g_drop", { maxManaPct = 0.02 }),
					B = minor("Вдох", "+0,15 восстановления маны в секунду", "g_wave", { manaRegen = 0.15 }),
					C = minor("Плотная мантия", "+1,5% максимального здоровья", "g_heart", { maxHealthPct = 0.015 }),
				},
				nodes = {
					node("N1", "m_ink", "Запас чернил", "+8% максимальной маны", "i_inkwell", { maxManaPct = 0.08 }, "new"),
					node("N2", "m_breath", "Ровное дыхание", "+0,6 восстановления маны в секунду", "i_wind", { manaRegen = 0.6 }, "new"),
					node("N3", "m_margins", "Тонкие поля", "Заклинания стоят на 10% меньше маны", "i_scroll", { spellCost = -0.10 }, "new"),
					node("K1", "m_well", "Глубокий колодец", "+60 маны", "k_well", { maxMana = 60 }, "changed", "+40 маны"),
					node("N4", "m_second", "Второе дыхание", "Пока маны меньше 25%, она восстанавливается вдвое быстрее", "i_vial",
						{ lowManaRegen = 1 }, "new"),
					node("N5", "m_notes", "Конспект", "Убийство врага возвращает 5 маны", "i_book", { killMana = 5 }, "new"),
					node("K2", "m_spellecho", "Эхо заклинаний", "Каждое четвёртое заклинание бесплатно", "k_twinrune", { freeEvery = 4 }),
					node("K3", "m_oblivion", "Плащ забвения", "Когда «Покров» спадает — щит на 15% здоровья на 4 с", "k_hood",
						{ veilShield = 0.15, veilShieldTime = 4 }),
				},
			},
			{
				id = "staff", name = "Посох", text = "Снаряды посоха: урон, скорость, наведение",
				minor = {
					A = minor("Лёгкость", "Снаряды посоха летят на 3% быстрее", "g_speed", { projectileSpeed = 0.03 }),
					B = minor("Заряд", "+1,5% урона посоха", "g_spark", { weaponDamagePct = 0.015 }),
					C = minor("Меткость", "+1% шанса крита (крит — ×1,5 урона)", "g_star", { critChance = 0.01 }),
				},
				nodes = {
					node("N1", "m_facet", "Огранка", "+6% урона посоха", "i_crystal", { weaponDamagePct = 0.06 }, "new"),
					node("N2", "m_light", "Лёгкий снаряд", "Снаряды посоха летят на 15% быстрее и на 10% дальше", "i_swift",
						{ projectileSpeed = 0.15, projectileRange = 0.10 }, "new"),
					node("N3", "m_gesture", "Беглый жест", "+5% скорости ударов посохом", "i_hand", { attackSpeed = 0.05 }, "new"),
					node("K1", "m_piercing", "Пробивающий луч", "Удары и заклинания игнорируют 5 брони врага", "k_beam", { armorPierce = 5 }),
					node("N4", "m_seek", "Наводка", "Снаряды посоха сами доворачивают к ближайшему врагу", "i_seek", { homing = 90 }, "new"),
					node("N5", "m_through", "Насквозь", "Снаряд посоха пробивает ещё одного врага (по нему — 60% урона)", "i_pierce",
						{ pierce = 1, pierceShare = 0.6 }, "new"),
					node("K2", "m_shatter", "Расщепление", "Каждое 4-е попадание снаряда посоха раскалывает его на 3 осколка по 40% урона", "k_shatter",
						{ splitEvery = 4, splitShards = 3, splitShare = 0.4 }, "new"),
					node("K3", "m_reflector", "Отражатель", "Снаряды, отражённые барьером, наносят ×1,5 урона", "k_prism", { reflectBonus = 0.5 }),
				},
			},
			{
				id = "spells", name = "Чары", text = "Заклинания и «Покров»: сила и перезарядка",
				minor = {
					A = minor("Беглость", "Перезарядка заклинаний −1,5%", "g_hourglass", { abilityCooldown = -0.015 }),
					B = minor("Слово", "+2% урона заклинаний", "g_rune", { abilityDamage = 0.02 }),
					C = minor("Тень", "Перезарядка «Покрова» −0,25 с", "g_moon", { veilCooldown = -0.25 }),
				},
				nodes = {
					node("N1", "m_cursive", "Скоропись", "Заклинания читаются на 15% быстрее", "i_quill", { castTime = -0.15 }, "new"),
					node("N2", "m_word", "Сила слова", "+8% урона заклинаний", "i_rune", { abilityDamage = 0.08 }, "new"),
					node("N3", "m_slip", "Тихий уход", "Перезарядка «Покрова» −2 с", "i_moon", { veilCooldown = -2 }, "new"),
					node("K1", "m_quickread", "Быстрое чтение", "Перезарядка заклинаний и «Покрова» −15%", "k_hourglass", { abilityCooldown = -0.15 }),
					node("N4", "m_edge", "Резкость", "После заклинания следующий удар посохом +25%", "i_edge", { empower = 0.25 }, "new"),
					node("N5", "m_silentstep", "Тихий шаг", "Удар или заклинание из «Покрова» ×1,7 вместо ×1,5", "i_dagger",
						{ ambushBonus = 0.2 }, "changed", "+30% (×1,8)"),
					node("K2", "m_resonance", "Резонанс", "+20% урона заклинаний", "k_wave", { abilityDamage = 0.20 }, "changed", "+10%"),
					node("K3", "m_silence", "Безмолвие", "«Покров» длится 5 с вместо 3", "k_closedeye", { veilDuration = 2 }),
				},
			},
		},
	},
}

-- Сборка путей: малые узлы по шаблону, порядок Talents.Order, needs по id.
-- Talents.Nodes[id] = узел (с classId, branchId, branchIndex, kind, cost).
Talents.Nodes = {}
for classId, tree in pairs(Talents.Classes) do
	for branchIndex, branch in ipairs(tree.branches) do
		branch.index = branchIndex
		local given = {}
		for _, n in ipairs(branch.nodes) do
			given[n.slot] = n
		end
		local nodes, bySlot = {}, {}
		for _, slot in ipairs(Talents.Order) do
			local n = given[slot]
			local kindOf = Talents.MinorPattern[slot]
			if kindOf then
				local m = branch.minor[kindOf]
				local effects = {}
				for k, v in pairs(m.effects) do
					effects[k] = v
				end
				n = node(slot, ("%s_%s_%s"):format(tree.prefix, branch.id, slot), m.name, m.text, m.icon, effects, "new")
				n.minorKind = kindOf
			end
			n.classId = classId
			n.branchId = branch.id
			n.branchIndex = branchIndex
			n.kind = kindOf and "minor" or (string.sub(slot, 1, 1) == "K" and "key" or "normal")
			n.cost = Talents.Costs[n.kind]
			table.insert(nodes, n)
			bySlot[slot] = n
		end
		branch.nodes = nodes
		branch.bySlot = bySlot
		local cost = 0
		for _, n in ipairs(nodes) do
			n.needs = {}
			for _, slot in ipairs(Talents.Needs[n.slot]) do
				table.insert(n.needs, bySlot[slot].id)
			end
			cost += n.cost
			Talents.Nodes[n.id] = n
		end
		branch.cost = cost
	end
end

function Talents.tree(classId: string)
	return Talents.Classes[classId]
end

-- Очков в пути (34) и в древе (102).
function Talents.branchCost(branch): number
	return branch and branch.cost or 0
end

function Talents.treeCost(classId: string): number
	local tree = Talents.Classes[classId]
	local total = 0
	for _, branch in ipairs(tree and tree.branches or {}) do
		total += branch.cost
	end
	return total
end

-- Очков на уровне: 1 за каждый уровень после первого.
function Talents.pointsAt(level: number?): number
	return math.max(0, math.min(math.floor(level or 1), Talents.MaxLevel) - 1)
end

-- Потрачено очков: всего и по путям ({ [branchId] = n }).
function Talents.spent(classId: string, learned)
	local total, byBranch = 0, {}
	for id in pairs(learned or {}) do
		local n = Talents.Nodes[id]
		if n and n.classId == classId then
			total += n.cost
			byBranch[n.branchId] = (byBranch[n.branchId] or 0) + n.cost
		end
	end
	return total, byBranch
end

-- Можно ли изучить узел. reason: "unknown" | "class" | "learned" | "locked" | "points".
-- bonus — лишние очки сверх уровня (только отладка Studio: «talents points N»).
function Talents.canLearn(classId: string, learned, nodeId: string, level: number?, bonus: number?)
	local n = Talents.Nodes[nodeId]
	if not n then
		return false, "unknown"
	end
	if n.classId ~= classId then
		return false, "class"
	end
	learned = learned or {}
	if learned[nodeId] then
		return false, "learned"
	end
	if #n.needs > 0 then
		local open = false
		for _, need in ipairs(n.needs) do
			if learned[need] then
				open = true
				break
			end
		end
		if not open then
			return false, "locked"
		end
	end
	local spent = Talents.spent(classId, learned)
	if Talents.pointsAt(level) + (bonus or 0) - spent < n.cost then
		return false, "points"
	end
	return true, nil
end

-- Сумма эффектов изученных узлов класса.
function Talents.aggregate(classId: string, learned)
	local mods = {}
	for id in pairs(learned or {}) do
		local n = Talents.Nodes[id]
		if n and n.classId == classId then
			for key, value in pairs(n.effects) do
				mods[key] = (mods[key] or 0) + value
			end
		end
	end
	return mods
end

-- Сброс всегда целиком (план: «Сброс за золото»): по одному узлы не снимаются.
-- Цена сброса: первый бесплатно, дальше 25 × потраченные очки, не меньше 50.
function Talents.resetCost(spent: number, resets: number?): number
	if spent <= 0 then
		return 0
	end
	if Talents.Reset.firstFree and (resets or 0) == 0 then
		return 0
	end
	return math.max(Talents.Reset.minGold, Talents.Reset.goldPerPoint * spent)
end

-- Подписи причин для интерфейса.
Talents.Reasons = {
	unknown = "Такого узла нет",
	class = "Узел другого класса",
	learned = "Уже изучено",
	locked = "Сначала изучите предыдущий узел",
	points = "Не хватает очков",
	gold = "Не хватает золота",
	hub = "Сбросить древо можно только в долине",
	empty = "Древо и так пустое",
	busy = "Слишком быстро",
}

return Talents
