--!nonstrict
-- FloorBoons — «Дары Эха»: усиления до конца этажа (08.11.2026)
--
-- Каждые EveryRooms пройденных боевых комнат время останавливается, и каждому
-- герою на этаже выпадают 3 разные карточки. Выбрал — дар действует до конца
-- этажа (смерть его не снимает; выход в долину, новый забег, другой этаж — снимают).
-- Одну карточку можно взять несколько раз: значения складываются (до cap).
--
-- Значения — по редкости: { обычная, редкая, легендарная }.
-- text: %s — значение этой карточки; плашка «было → станет» считается из total.
-- Сервер: Systems/FloorBoonService (выбор, остановка времени),
-- Systems/FloorBoonState (статы). Клиент: Controllers/FloorBoonController.

local FloorBoons = {}

FloorBoons.EveryRooms = 2 -- карточки после каждых 2 пройденных боевых комнат
FloorBoons.Choices = 3
FloorBoons.GroupTimeout = 30 -- в группе: не выбрал за 30 с — случайная карточка
FloorBoons.SoloTimeout = nil -- один на этаже: ждём сколько угодно
FloorBoons.ResumeGrace = 1.2 -- после возобновления враги ещё столько не бьют

-- Цвета — как у редкостей предметов (UiAssets.Rarity): серый, зелёный, оранжевый.
FloorBoons.Rarities = {
	{ id = "common", name = "Обычный дар", weight = 70, color = Color3.fromRGB(170, 176, 184), glow = Color3.fromRGB(228, 232, 236) },
	{ id = "rare", name = "Редкий дар", weight = 25, color = Color3.fromRGB(88, 200, 92), glow = Color3.fromRGB(170, 245, 160) },
	{ id = "legendary", name = "Легендарный дар", weight = 5, color = Color3.fromRGB(255, 176, 46), glow = Color3.fromRGB(255, 226, 130) },
}
FloorBoons.RarityIndex = { common = 1, rare = 2, legendary = 3 }

-- kind — как значение показывать: pct (+20%), flat (+6), mult (×1,5).
-- weight — частота карточки в колоде.
FloorBoons.Cards = {
	{
		id = "soul_hunger", name = "Голод душ", icon = "soul_hunger", accent = Color3.fromRGB(168, 110, 240),
		values = { 0.20, 0.30, 0.45 }, kind = "pct", cap = 1.5, weight = 10,
		text = "Урон от накопленных душ\n+%s",
	},
	{
		id = "vitality", name = "Крепкое сердце", icon = "vitality", accent = Color3.fromRGB(220, 60, 70),
		values = { 0.30, 0.40, 0.55 }, kind = "pct", weight = 10,
		text = "Максимум здоровья\n+%s",
	},
	{
		id = "evasion", name = "Тень", icon = "evasion", accent = Color3.fromRGB(120, 140, 220),
		values = { 0.05, 0.07, 0.10 }, kind = "pct", cap = 0.35, weight = 9,
		text = "Шанс уклониться от удара\n+%s",
	},
	{
		id = "haste", name = "Ярость клинка", icon = "haste", accent = Color3.fromRGB(240, 196, 70),
		values = { 0.20, 0.28, 0.40 }, kind = "pct", cap = 1.0, weight = 10,
		text = "Скорость атаки\n+%s",
	},
	{
		id = "soul_surge", name = "Прилив душ", icon = "soul_surge", accent = Color3.fromRGB(80, 210, 220),
		values = { 1.5, 1.75, 2.0 }, kind = "mult", weight = 8,
		-- предел душ поднимается на extra[редкость] (база Progression.SoulStacks.max)
		extra = { 20, 30, 40 },
		text = "Души сейчас ×%s\nпредел душ +%s",
	},
	{
		id = "might", name = "Закалённая сталь", icon = "might", accent = Color3.fromRGB(255, 150, 40),
		values = { 0.12, 0.18, 0.26 }, kind = "pct", weight = 10,
		text = "Урон оружия\n+%s",
	},
	{
		id = "leech", name = "Кровавая жажда", icon = "leech", accent = Color3.fromRGB(200, 30, 50),
		values = { 0.03, 0.05, 0.08 }, kind = "pct", cap = 0.20, weight = 8,
		text = "Лечит %s\nот нанесённого урона",
	},
	{
		id = "bulwark", name = "Каменная кожа", icon = "bulwark", accent = Color3.fromRGB(200, 160, 70),
		values = { 6, 9, 14 }, kind = "flat", weight = 9,
		text = "Броня\n+%s",
	},
	{
		id = "swift", name = "Лёгкая поступь", icon = "swift", accent = Color3.fromRGB(190, 210, 240),
		values = { 0.10, 0.15, 0.22 }, kind = "pct", cap = 0.5, weight = 8,
		text = "Скорость бега\n+%s",
	},
	{
		id = "second_wind", name = "Второе дыхание", icon = "second_wind", accent = Color3.fromRGB(110, 200, 110),
		values = { 0.30, 0.45, 0.70 }, kind = "pct", weight = 7, instant = true,
		extra = { 1, 1, 2 }, -- зарядов лечения сверх обычного
		text = "Сразу лечит %s здоровья\n+%s заряд лечения",
	},
	{
		id = "reaper", name = "Жатва", icon = "reaper", accent = Color3.fromRGB(120, 230, 140),
		values = { 0.02, 0.03, 0.05 }, kind = "pct", cap = 0.15, weight = 8,
		text = "Каждое убийство лечит\n%s здоровья",
	},
}

FloorBoons.ById = {}
for _, card in ipairs(FloorBoons.Cards) do
	FloorBoons.ById[card.id] = card
end

-- Число по виду: 0.2 → «20%», 6 → «6», 1.5 → «1,5».
function FloorBoons.format(kind: string, value: number): string
	if kind == "pct" then
		local pct = value * 100
		if math.abs(pct - math.floor(pct + 0.5)) < 0.05 then
			return ("%d%%"):format(math.floor(pct + 0.5))
		end
		return (("%.1f%%"):format(pct)):gsub("%.", ",")
	elseif kind == "mult" then
		local s = ("%.2f"):format(value):gsub("0+$", ""):gsub("%.$", "")
		return (s:gsub("%.", ","))
	end
	return tostring(math.floor(value + 0.5))
end

-- Текст карточки для редкости (1..3).
function FloorBoons.describe(cardId: string, rarity: number): string
	local card = FloorBoons.ById[cardId]
	if not card then
		return ""
	end
	local value = FloorBoons.format(card.kind, card.values[rarity])
	if card.extra then
		return (card.text:format(value, tostring(card.extra[rarity])))
	end
	return (card.text:format(value))
end

-- Суммарное значение дара по списку взятых { {id, rarity}, … } — как на сервере
-- (FloorBoonState.add): mult перемножается, остальное складывается, до cap.
function FloorBoons.totals(list)
	local out = {}
	for _, item in ipairs(list or {}) do
		local id, rarity = item[1] or item.id, item[2] or item.rarity
		local card = FloorBoons.ById[id]
		if card and card.values[rarity] then
			local have = out[id] or { total = 0, count = 0, best = 0, extra = 0 }
			out[id] = have
			if card.kind == "mult" then
				have.total = math.max(have.total, 1) * card.values[rarity]
			else
				have.total += card.values[rarity]
			end
			if card.cap then
				have.total = math.min(have.total, card.cap)
			end
			have.count += 1
			have.best = math.max(have.best, rarity)
			if card.extra then
				have.extra += card.extra[rarity]
			end
		end
	end
	return out
end

-- Колода предложения: count разных карточек, редкость у каждой своя.
-- rng — Random; owned — { [id] = { total = number } } для «потолочных» карт.
function FloorBoons.roll(rng, wanted: number?, owned)
	local count: number = wanted or FloorBoons.Choices
	local pool = {}
	for _, card in ipairs(FloorBoons.Cards) do
		local have = owned and owned[card.id]
		local capped = card.cap and have and have.total >= card.cap - 1e-6
		if not capped then
			table.insert(pool, card)
		end
	end
	local offer = {}
	for _ = 1, math.min(count, #pool) do
		local sum = 0
		for _, card in ipairs(pool) do
			sum += card.weight
		end
		local pick = rng:NextNumber() * sum
		local index = #pool
		for i, card in ipairs(pool) do
			pick -= card.weight
			if pick <= 0 then
				index = i
				break
			end
		end
		local card = table.remove(pool, index)
		local roll = rng:NextNumber() * 100
		local rarity = 1
		local acc = 0
		for r, info in ipairs(FloorBoons.Rarities) do
			acc += info.weight
			if roll < acc then
				rarity = r
				break
			end
		end
		table.insert(offer, { id = card.id, rarity = rarity })
	end
	return offer
end

return FloorBoons
