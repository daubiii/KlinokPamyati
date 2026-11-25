--!nonstrict
-- Quests
-- Квестовая линия Гильдии искателей (ТЗ хаба, раздел 5; главы — по этажам
-- из GDD, разделы 2 и 9). Задания идут по порядку: следующее появляется на
-- доске, когда сдано предыдущее. Берутся у доски заданий, прогресс считает
-- сервер (QuestService), хранится в профиле: profile.quests.
--
-- kind:
--   "talk" — поговорить с goal разными жителями (VillagerService.Talked);
--   "kill" — победить goal врагов типа enemy (Config.Enemies*, id типа).
-- Награды (GDD, разделы 9–10: квесты — источник золота, охотничьи кормят
-- крафт): gold — золото; echo — эхо надетому оружию (на потолке → пыль);
-- dust — пыль эха; material — N штук материала этажа (id в quest.material);
-- archive — фрагмент Архива (за босса этажа). Числа сверены с экономикой:
-- сундук этажа даёт 150–330 золота, квест ≈ 1,5–2 сундука, чтобы направление
-- игрока к боссу ощущалось наградой. Ежедневка за неделю ~1230 золота —
-- сюжетная линия не должна обесцениваться быстрее неё.
--
-- giver/chapter — подписи для окна доски (UI v2, как в макете).

local Quests = {}

Quests.List = {
	-- ===== Глава 1 · Привратный двор =====
	{
		id = "voices",
		title = "Голоса долины",
		text = "Поговори с пятью жителями долины. Их легко найти: у каждого над головой имя.",
		kind = "talk",
		goal = 5,
		reward = { gold = 50 },
		giver = "Ольгерд",
		chapter = "Сюжет · глава 1",
	},
	{
		id = "rust_guard",
		title = "Ржавая стража",
		text = "Победи 10 Ржавых стражей в Привратном дворе.",
		kind = "kill",
		enemy = "guard",
		goal = 10,
		reward = { chest = 1, gold = 150 },
		giver = "Ольгерд",
		chapter = "Сюжет · глава 1",
	},
	-- ===== Глава 2 · Врата Хранилища =====
	{
		id = "gate_key",
		title = "Ключ от ворот",
		text = "Победи Привратника у Ворот Хранилища.",
		kind = "kill",
		enemy = "gatekeeper",
		goal = 1,
		reward = { chest = 2, gold = 300, archive = "gate_key" },
		giver = "Феофан",
		chapter = "Сюжет · глава 2",
	},
	-- ===== Глава 3 · Затопленные сады (этаж 2) =====
	{
		id = "sunken_choir",
		title = "Шёпот с водой",
		text = "Утопленники в садах шепчут имена, которых не помнят сами. Победи 12 — и послушай, что они говорят.",
		kind = "kill",
		enemy = "drowned",
		goal = 12,
		reward = { chest = 1, gold = 250, echo = 1 },
		giver = "Ольгерд",
		chapter = "Сюжет · глава 3",
	},
	{
		id = "wax_guards",
		title = "Медовые часовые",
		text = "Пчёлы-стражи охраняют то, что сад помнит лучше людей. Сними 10 с поста.",
		kind = "kill",
		enemy = "bee",
		goal = 10,
		reward = { chest = 1, gold = 280, dust = 20 },
		giver = "Ольгерд",
		chapter = "Сюжет · глава 3",
	},
	{
		id = "gardener",
		title = "Та, что поливала",
		text = "Садовница поливала статуи чужой памятью, пока они не начали ходить. Останови её.",
		kind = "kill",
		enemy = "gardener",
		goal = 1,
		material = "swamp_reed",
		reward = { chest = 2, gold = 450, dust = 30, material = 3, archive = "gardener" },
		giver = "Феофан",
		chapter = "Сюжет · глава 3",
	},
	-- ===== Глава 4 · Псарни охоты (этаж 3) =====
	{
		id = "kennel_choir",
		title = "Голоса своры",
		text = "Гончие выслеживают тех, кто ещё помнит. Победи 14 — и они перестанут идти по твоему следу.",
		kind = "kill",
		enemy = "hound",
		goal = 14,
		reward = { chest = 1, gold = 300, echo = 1 },
		giver = "Ольгерд",
		chapter = "Сюжет · глава 4",
	},
	{
		id = "hunt_masters",
		title = "Ловчие",
		text = "Арбалетчики-ловчие ловят не зверя. Они ловят память, которая уходит с этажа. Победи 10.",
		kind = "kill",
		enemy = "crossbowman",
		goal = 10,
		reward = { chest = 1, gold = 320, dust = 25 },
		giver = "Ольгерд",
		chapter = "Сюжет · глава 4",
	},
	{
		id = "pack_leader",
		title = "Голос хозяина",
		text = "Вожак своры помнит голос своего хозяина. Победи его — клинку нужен этот голос.",
		kind = "kill",
		enemy = "pack_leader",
		goal = 1,
		material = "tanned_hide",
		reward = { chest = 2, gold = 550, echo = 1, material = 3, archive = "pack_leader" },
		giver = "Феофан",
		chapter = "Сюжет · глава 4",
	},
	-- ===== Глава 5 · Литейные (этаж 4) =====
	{
		id = "foundry_shift",
		title = "Вечная смена",
		text = "Кузнечные автоматы всё ещё куют то, чего никто не заказывал. Останови 12.",
		kind = "kill",
		enemy = "forge_automaton",
		goal = 12,
		reward = { chest = 1, gold = 380, echo = 2 },
		giver = "Ольгерд",
		chapter = "Сюжет · глава 5",
	},
	{
		id = "ember_days",
		title = "Обрывки горна",
		text = "Огненные духи — это дни у горна, которые кто-то пытался удержать. Разгони 10.",
		kind = "kill",
		enemy = "fire_spirit",
		goal = 10,
		reward = { gold = 400, dust = 30 },
		giver = "Ольгерд",
		chapter = "Сюжет · глава 5",
	},
	{
		id = "elder_founder",
		title = "Тот, кто ковал клинок",
		text = "Старший литейщик помнит, как ковали сам Клинок. Победи его — это память ближе всех к твоему имени.",
		kind = "kill",
		enemy = "elder_founder",
		goal = 1,
		material = "cast_bronze",
		reward = { chest = 2, gold = 700, echo = 2, dust = 30, material = 3, archive = "elder_founder" },
		giver = "Феофан",
		chapter = "Сюжет · глава 5",
	},
	-- ===== Глава 6 · Зал хроник (этаж 5) =====
	{
		id = "ink_pages",
		title = "Чужие жизни",
		text = "Чернильные писари переписывают чужие жизни в книги, которым нет конца. Разорви 12 таких страниц — победи писарей.",
		kind = "kill",
		enemy = "ink_scribe",
		goal = 12,
		reward = { chest = 1, gold = 450, echo = 2 },
		giver = "Ольгерд",
		chapter = "Сюжет · глава 6",
	},
	{
		id = "keeper_seals",
		title = "Переплёт",
		text = "Переплётчик сшивает чужие жизни в один том, чтобы никто не вышел из книги. Разорви его переплёт.",
		kind = "kill",
		enemy = "bookbinder",
		goal = 1,
		reward = { chest = 2, gold = 550, dust = 40 },
		giver = "Феофан",
		chapter = "Сюжет · глава 6",
	},
	{
		id = "chief_chronicler",
		title = "Имя кузнеца",
		text = "Главный хронист — последний, кто помнит имя кузнеца. Победи его. Клинок вспомнит себя. И ты — тоже.",
		kind = "kill",
		enemy = "chief_chronicler",
		goal = 1,
		material = "memory_ink",
		reward = { goldChest = 3, gold = 900, echo = 3, dust = 50, material = 3, archive = "chief_chronicler" },
		giver = "Феофан",
		chapter = "Сюжет · глава 6",
	},

	-- ===== Достижения (GDD раздел 9: «долгий горизонт») =====
	-- kind = "stat": прогресс — пожизненный счётчик из profile.stats
	-- (StatsService: parries, damageDealt; kills ведёт ProgressionService).
	-- Выполняются сами, без «ВЗЯТЬ»; тиры одной цепочки открываются по
	-- очереди (категория achv на доске). Награда растёт с тиром.
	{
		id = "achv_parry_10",
		title = "Стальная вежливость",
		text = "Отбей 10 вражеских ударов в окно парирования.",
		kind = "stat",
		stat = "parries",
		tier = 1,
		goal = 10,
		reward = { chest = 1, gold = 150, echo = 1 },
		giver = "Ольгерд",
		chapter = "Достижения · I",
	},
	{
		id = "achv_parry_50",
		title = "Стальная вежливость II",
		text = "Отбей 50 вражеских ударов в окно парирования.",
		kind = "stat",
		stat = "parries",
		tier = 2,
		goal = 50,
		reward = { chest = 2, gold = 400, echo = 2 },
		giver = "Ольгерд",
		chapter = "Достижения · II",
	},
	{
		id = "achv_parry_100",
		title = "Стальная вежливость III",
		text = "Отбей 100 вражеских ударов в окно парирования.",
		kind = "stat",
		stat = "parries",
		tier = 3,
		goal = 100,
		reward = { goldChest = 1, gold = 900, echo = 3, dust = 50 },
		giver = "Ольгерд",
		chapter = "Достижения · III",
	},
	{
		id = "achv_damage_1k",
		title = "Клинок помнит",
		text = "Нанеси врагам 1 000 урона.",
		kind = "stat",
		stat = "damageDealt",
		tier = 1,
		goal = 1000,
		reward = { chest = 1, gold = 200, dust = 20 },
		giver = "Ольгерд",
		chapter = "Достижения · I",
	},
	{
		id = "achv_damage_10k",
		title = "Клинок помнит II",
		text = "Нанеси врагам 10 000 урона.",
		kind = "stat",
		stat = "damageDealt",
		tier = 2,
		goal = 10000,
		reward = { chest = 2, gold = 500, echo = 2 },
		giver = "Ольгерд",
		chapter = "Достижения · II",
	},
	{
		id = "achv_damage_100k",
		title = "Клинок помнит III",
		text = "Нанеси врагам 100 000 урона.",
		kind = "stat",
		stat = "damageDealt",
		tier = 3,
		goal = 100000,
		reward = { goldChest = 1, gold = 1000, echo = 3, dust = 60 },
		giver = "Ольгерд",
		chapter = "Достижения · III",
	},
	{
		id = "achv_kill_25",
		title = "Редкие страницы",
		text = "Победи 25 врагов. Каждый — чья-то забытая жизнь.",
		kind = "stat",
		stat = "enemiesKilled",
		tier = 1,
		goal = 25,
		reward = { chest = 1, gold = 150, dust = 15 },
		giver = "Ольгерд",
		chapter = "Достижения · I",
	},
	{
		id = "achv_kill_100",
		title = "Редкие страницы II",
		text = "Победи 100 врагов.",
		kind = "stat",
		stat = "enemiesKilled",
		tier = 2,
		goal = 100,
		reward = { chest = 2, gold = 350, echo = 1 },
		giver = "Ольгерд",
		chapter = "Достижения · II",
	},
	{
		id = "achv_kill_250",
		title = "Редкие страницы III",
		text = "Победи 250 врагов.",
		kind = "stat",
		stat = "enemiesKilled",
		tier = 3,
		goal = 250,
		reward = { goldChest = 1, gold = 800, echo = 2, dust = 30 },
		giver = "Ольгерд",
		chapter = "Достижения · III",
	},

	-- ===== Охота (P6): особые враги с золотым сиянием =====
	-- Изредка в забеге один из врагов приходит «особым»: золотое сияние,
	-- вдвое крепче, при смерти сыплет золотом и материалом этажа. Счётчик
	-- specialKilled ведёт SpecialMobs ( attacker получает добычу).
	-- Числа: особый враг ≈ 0.6–0.9 сундука ценности, тиры по возрастающей —
	-- охота не должна обесценить сюжет (та же логика, что у достижений).
	{
		id = "hunt_1",
		title = "Золотой след",
		text = "В забегах изредка приходит особый враг — золотое сияние и хитрая ухмылка. Победи одного.",
		kind = "stat",
		stat = "specialKilled",
		tier = 1,
		goal = 1,
		reward = { chest = 1, gold = 150, dust = 15 },
		giver = "Феофан",
		chapter = "Охота · I",
	},
	{
		id = "hunt_2",
		title = "Золотой след II",
		text = "Победи 5 особых врагов. Они любят появляться там, где тесно и шумно.",
		kind = "stat",
		stat = "specialKilled",
		tier = 2,
		goal = 5,
		reward = { chest = 2, gold = 350, dust = 30 },
		giver = "Феофан",
		chapter = "Охота · II",
	},
	{
		id = "hunt_3",
		title = "Стая золотых теней",
		text = "Победи 12 особых врагов. Гильдия начинает верить, что ты видишь их насквозь.",
		kind = "stat",
		stat = "specialKilled",
		tier = 3,
		goal = 12,
		reward = { goldChest = 1, gold = 700, echo = 2 },
		giver = "Феофан",
		chapter = "Охота · III",
	},
	{
		id = "hunt_4",
		title = "Королевская охота",
		text = "Победи 25 особых врагов. Теперь твоё имя шепчут в псарнях и в залах.",
		kind = "stat",
		stat = "specialKilled",
		tier = 4,
		goal = 25,
		reward = { goldChest = 2, gold = 1300, dust = 60, echo = 3 },
		giver = "Феофан",
		chapter = "Охота · IV",
	},
}

-- Фрагменты Архива, которые выдают задания (читает станция Архива).
Quests.ArchiveFragments = {
	gate_key = {
		title = "Ключ от ворот",
		text = "Привратник не охранял ворота. Он охранял то, что за ними помнило его имя.",
	},
	gardener = {
		title = "Сад чужой памяти",
		text = "Садовница поливала сад водой из колодца забвения. Розы цвели. Сад забывал, чей он.",
	},
	pack_leader = {
		title = "Голос хозяина",
		text = "Пёс приходил на голос хозяина даже тогда, когда хозяина не стало. Эхо голоса осталось в псарнях.",
	},
	elder_founder = {
		title = "День, когда ковали клинок",
		text = "Клинок отлили из тишины, что осталась после всех забытых имён. Литейщик плакал и не помнил, почему.",
	},
	chief_chronicler = {
		title = "Имя кузнеца",
		text = "Кузнеца звали так же, как зовут тебя. Он отдал своё имя клинку — чтобы клинок помнил, кого защищает.",
	},
}

-- ===== Поручения: ежедневные и еженедельные (GDD раздел 9) =====
-- Каждому игроку в 00:00 UTC выбирается 3 ежедневных и раз в неделю 3
-- еженедельных из этих пулов (seed = игрок + период, так что набор
-- стабилен весь день и не перекидывается перезаходом). Прогресс считается
-- от «базовой линии» пожизненных счётчиков на момент ротации (см.
-- QuestService.ensurePeriods), закрываются сами, награда — той же панелью.
-- stat — ключ в profile.stats; bossesKilled ведёт QuestService (см. onKilled).
Quests.DailyPool = {
	{
		id = "d_kills", title = "Разгони рой",
		text = "Победи 15 врагов на любых этажах.",
		stat = "enemiesKilled", goal = 15,
		reward = { gold = 120, dust = 15 },
	},
	{
		id = "d_damage", title = "Горячая рука",
		text = "Нанеси врагам 2 500 урона.",
		stat = "damageDealt", goal = 2500,
		reward = { gold = 130, dust = 15 },
	},
	{
		id = "d_parry", title = "Час стражи",
		text = "Отбей 6 ударов в окно парирования.",
		stat = "parries", goal = 6,
		reward = { gold = 110, dust = 15 },
	},
	{
		id = "d_chests", title = "Свежие находки",
		text = "Открой 2 сундука в долине.",
		stat = "chestsOpened", goal = 2,
		reward = { gold = 120, dust = 20 },
	},
	{
		id = "d_boss", title = "Судьба этажа",
		text = "Победи любого босса этажа.",
		stat = "bossesKilled", goal = 1,
		reward = { chest = 1, gold = 180, dust = 25 },
	},
}

Quests.WeeklyPool = {
	{
		id = "w_kills", title = "Большая охота",
		text = "Победи 120 врагов за неделю.",
		stat = "enemiesKilled", goal = 120,
		reward = { chest = 2, gold = 550, echo = 2 },
	},
	{
		id = "w_damage", title = "Неделя ковки",
		text = "Нанеси врагам 30 000 урона за неделю.",
		stat = "damageDealt", goal = 30000,
		reward = { chest = 2, gold = 600, dust = 80 },
	},
	{
		id = "w_parry", title = "Не дрогнуть",
		text = "Отбей 40 ударов в окно парирования за неделю.",
		stat = "parries", goal = 40,
		reward = { chest = 2, gold = 500, echo = 2 },
	},
	{
		id = "w_chests", title = "Обход кладовых",
		text = "Открой 8 сундуков в долине за неделю.",
		stat = "chestsOpened", goal = 8,
		reward = { gold = 550, dust = 70 },
	},
	{
		id = "w_boss", title = "Три памяти",
		text = "Победи 3 боссов этажей за неделю.",
		stat = "bossesKilled", goal = 3,
		reward = { chest = 1, goldChest = 1, gold = 700, echo = 3, dust = 40 },
	},
}

Quests.ById = {}
for index, quest in ipairs(Quests.List) do
	quest.order = index
	Quests.ById[quest.id] = quest
end

-- Достижения и охота — цепочки «achv»: считаются от пожизненных счётчиков,
-- выполняются сами, вне сюжетной очереди. Проставляем категорию по префиксу:
-- раньше поле терялось (пакетное слияние) и доска показывала прогресс по
-- q.progress, который у stat-квестов никогда не растёт.
for _, quest in ipairs(Quests.List) do
	local prefix = quest.id:sub(1, 5)
	if prefix == "achv_" or prefix == "hunt_" then
		quest.category = "achv"
	end
end

-- Имя материала этажа для текста награды («3 × Болотный тростник»).
-- Лениво: Loot грузится сам, когда понадобится, цикла по конфигам нет.
local materialNames = nil
local function materialName(id: string?): string
	if materialNames == nil then
		local ok, loot = pcall(function()
			return require(script.Parent.Loot)
		end)
		materialNames = (ok and loot and loot.MaterialNames) or {}
	end
	if not id then
		return "?"
	end
	return materialNames[id] or id
end

-- «1 обычный сундук», «2 обычных сундука», «3 золотых сундука» — с учётом склонения.
local function chestPhrase(count: number, gold: boolean): string
	local kind = gold and "золот" or "обычн"
	local tail = ""
	if count % 10 == 1 and count % 100 ~= 11 then
		tail = "ый сундук"
	elseif count % 10 >= 2 and count % 10 <= 4 and (count % 100 < 12 or count % 100 > 14) then
		tail = "ых сундука"
	else
		tail = "ых сундуков"
	end
	return count .. " " .. kind .. tail
end

function Quests.rewardText(quest): string
	local parts = {}
	local reward = quest.reward or {}
	if reward.gold then
		table.insert(parts, reward.gold .. " золота")
	end
	if reward.echo then
		table.insert(parts, reward.echo .. " эхо")
	end
	if reward.dust then
		table.insert(parts, reward.dust .. " пыли")
	end
	if reward.material then
		-- tostring: ошибка в конфиге (забыт id материала) не должна ронять
		-- снапшот квестов и вместе с ним профиль игрока (баг 11.11.2026).
		table.insert(parts, reward.material .. " × " .. tostring(materialName(quest.material)))
	end
	if reward.chest and reward.chest > 0 then
		table.insert(parts, chestPhrase(reward.chest, false))
	end
	if reward.goldChest and reward.goldChest > 0 then
		table.insert(parts, chestPhrase(reward.goldChest, true))
	end
	if reward.archive then
		table.insert(parts, "фрагмент Архива")
	end
	return table.concat(parts, ", ")
end

return Quests
