--!nonstrict
-- Palette
-- Единственный источник правды по цвету. Раздел 11 плана.
-- Правило единого вида: цвет берём ТОЛЬКО отсюда, хардкод Color3 в других
-- модулях запрещён. Голубой #6FE3FF закреплён за памятью (души, секретные
-- предметы, интерфейс памяти) и намеренно отсутствует в палитрах этажей.

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

local Palette = {}

-- Чистая память. Уникальный цвет проекта: больше нигде не используется.
Palette.Memory = hex("#6FE3FF")
Palette.MemoryDim = hex("#3E8FA8")

-- Мана мага: синяя, темнее памяти (память — только голубая).
Palette.Mana = hex("#4F7BFF")
Palette.ManaLight = hex("#9DB8FF")
Palette.ManaDark = hex("#22306E")

-- Облик мага (Хронисты): основные цвета комплектов — для запасного облика
-- из Part'ов, пока меши шляп и накидок не импортированы. Меши красит палитра.
Palette.Mage = {
	novice = { hat = hex("#94816A"), band = hex("#5E4E32"), mantle = hex("#748696"), cape = hex("#3C4858"), trim = hex("#C8B486") },
	reader = { hat = hex("#467A72"), band = hex("#B8403A"), mantle = hex("#4E7C76"), cape = hex("#365C58"), trim = hex("#D4A02C") },
	chronicler = { hat = hex("#2E4288"), band = hex("#AEB8C6"), mantle = hex("#1F2E66"), cape = hex("#1E2C62"), trim = hex("#AEB8C6") },
	oblivion = { hat = hex("#3E304E"), band = hex("#211A28"), mantle = hex("#211A28"), cape = hex("#2C2636"), trim = hex("#B48CFF") },
	archivist = { hat = hex("#D3C7AB"), band = hex("#D4A02C"), mantle = hex("#EFE7CF"), cape = hex("#D3C7AB"), trim = hex("#D4A02C") },
	violet = hex("#B48CFF"),
	crimson = hex("#621A26"),
}

-- Палитры этажей: ровно четыре цвета на этаж (приложение А, §11).
Palette.Floors = {
	{
		id = 1,
		name = "Привратный двор",
		theme = "Руины входа, память о страже",
		colors = { hex("#3A2E2A"), hex("#7A5C48"), hex("#C98B4A"), hex("#D9D2C5") },
	},
	{
		id = 2,
		name = "Затопленные сады",
		theme = "Мирные дни, ставшие гнилью",
		colors = { hex("#1F3A33"), hex("#3F7A5C"), hex("#9CC48A"), hex("#5FD0C0") },
	},
	{
		id = 3,
		name = "Псарни охоты",
		theme = "Королевская охота",
		colors = { hex("#3B1E1E"), hex("#8C3B2E"), hex("#D9A441"), hex("#E8DCC0") },
	},
	{
		id = 4,
		name = "Литейные",
		theme = "Где вплавляли эхо в клинки",
		colors = { hex("#1E1B1F"), hex("#4A4350"), hex("#E2672B"), hex("#FFC857") },
	},
	{
		id = 5,
		name = "Зал хроник",
		theme = "Библиотека памяти",
		colors = { hex("#1D1B3A"), hex("#4A3F8F"), hex("#8E7CE0"), hex("#B8E3FF") },
	},
}

-- Интерфейс (приложение Д).
Palette.UI = {
	panel = hex("#1E1B1F"),
	frame = hex("#4A4350"),
	accent = hex("#C98B4A"),
	accentBorder = hex("#7A5C48"),
	text = hex("#D9D2C5"),
	textMuted = hex("#9AA0A6"),
	danger = hex("#E5484D"),
}

-- Нейтральные роли для воксельных моделей. Оружие не принадлежит этажу,
-- поэтому у него своя палитра: металл, дерево, камень.
Palette.Material = {
	grip = hex("#4A3A2C"),
	gripWrap = hex("#7A5C48"),
	guard = hex("#9AA0A6"),
	blade = hex("#D9D2C5"),
	bladeEdge = hex("#F2EDE3"),
	steelDark = hex("#6B6F73"),
	wood = hex("#8C6A45"),
	stone = hex("#4A4350"),
}

-- Цвета эффектов. Только из палитры проекта: белая вспышка парирования,
-- тёплая искра попадания, зелёное лечение (цвет 2 этажа), голубая память.
Palette.Fx = {
	parry = Palette.Material.bladeEdge,
	hit = Palette.Material.bladeEdge,
	warn = Palette.Floors[1].colors[3],
	heal = Palette.Floors[2].colors[3],
	danger = Palette.UI.danger,
	memory = Palette.Memory,
	dust = Palette.Floors[1].colors[4],
}

-- Буквы пиксельных сеток брони и оружия врагов (ТЗ врагов, раздел 2.1).
-- Все цвета — те же, что выше; таблица только даёт им буквы. Порядок
-- VoxelOrder — столбцы текстуры-палитры 16×1 у мешей брони (позиции 13–16
-- свободны). Голубого здесь нет и быть не должно: он только у эффекта души.
do
	local c = Palette.Floors[1].colors
	Palette.Voxel = {
		K = Palette.UI.panel, -- #1E1B1F контур, тьма, щели
		S = Palette.UI.frame, -- #4A4350 тёмная сталь, камень
		G = Palette.Material.steelDark, -- #6B6F73 сталь
		L = Palette.UI.textMuted, -- #9AA0A6 светлая сталь
		W = Palette.Material.blade, -- #D9D2C5 кость, светлая ткань
		H = Palette.Material.bladeEdge, -- #F2EDE3 блик
		D = c[1], -- #3A2E2A тёмная ржавчина, тёмная кожа
		R = c[2], -- #7A5C48 ржавчина
		A = c[3], -- #C98B4A янтарь, латунь
		B = Palette.Material.grip, -- #4A3A2C коричневая кожа, ремни
		N = Palette.Material.wood, -- #8C6A45 дерево
		X = Palette.UI.danger, -- #E5484D красный (только Треснувший)
	}
	Palette.VoxelOrder = "KSGLWHDRABNX"
end

-- Окружение этажа 1 (концепты «комнаты с монстрами», «костёр», «арена»).
-- Большая часть тонов — смеси четырёх цветов этажа; отдельно названы только
-- ржавчина, дерево, железо, ткань знамён и жар огня.
do
	local c = Palette.Floors[1].colors
	Palette.Env = {
		mortar = c[1],
		-- Камень пыльный, ближе к костяному, чем к ржавому: на солнце
		-- насыщенный #7A5C48 «горит» оранжевым (проверено скриншотом).
		stoneDeep = c[1]:Lerp(c[2], 0.45),
		stoneDark = c[1]:Lerp(c[2], 0.75):Lerp(c[4], 0.1),
		stone = c[2]:Lerp(c[4], 0.2),
		stoneWarm = c[2]:Lerp(c[3], 0.12):Lerp(c[4], 0.15),
		stoneLight = c[2]:Lerp(c[4], 0.42),
		sand = c[2]:Lerp(c[4], 0.52),
		sandLight = c[2]:Lerp(c[4], 0.68),
		bone = c[4],
		grass = c[3]:Lerp(c[4], 0.2),
		grassDry = c[3]:Lerp(c[2], 0.35),
		rust = hex("#9C4A2A"),
		rustDark = hex("#6E3420"),
		wood = hex("#6B4A32"),
		woodDark = hex("#4A3426"),
		woodLight = hex("#8C6A45"),
		iron = hex("#3B3536"),
		ironLight = hex("#5A5254"),
		cloth = hex("#8C3B2E"),
		clothDark = hex("#5E2A22"),
		ember = hex("#FFB547"),
		flame = hex("#FF7A2E"),
		flameCore = hex("#FFE08A"),
		gold = hex("#E0A43C"),
		void = hex("#140F0D"),
	}

	-- Руины этажа (переработка 21.10.2026 по спецификации владельца):
	-- тёмный сланец пола, бурые обломки, светлая дорожка, оранжевые маяки.
	Palette.Ruin = {
		floor = c[1],
		rubble = c[2],
		path = c[4],
		beacon = c[3],
		tint = hex("#FFE4B5"),
	}
end

-- Хаб «Долина Последнего Эха» (ТЗ хаба, раздел 10). Хаб не этаж: у него
-- своя светлая палитра. mem/memd — те же цвета памяти, только для памяти.
Palette.Hub = {
	g1 = hex("#7DBF5A"), -- трава
	g2 = hex("#4E8F45"), -- лес
	g3 = hex("#2F5E3A"), -- тень
	g4 = hex("#9ED36B"), -- светлые пятна
	st1 = hex("#B9B3A8"), -- камень от светлого к тёмному
	st2 = hex("#8A847C"),
	st3 = hex("#5C5752"),
	st4 = hex("#3E3A38"),
	sn1 = hex("#F2F4F7"), -- снег
	sn2 = hex("#C9D3E0"),
	w1 = hex("#3E7FC4"), -- вода
	w2 = hex("#79B6E8"),
	w3 = hex("#2B5E99"),
	sa = hex("#D8BE8A"), -- дороги
	di = hex("#9C7A52"), -- земля
	wd = hex("#8C6A45"), -- дерево
	wd2 = hex("#5A4030"),
	rf = hex("#A8483A"), -- крыши
	rf2 = hex("#C98B4A"),
	rf3 = hex("#6E3B30"),
	wh = hex("#EDE6D6"), -- белёные стены
	fy = hex("#E8C547"), -- цветы
	fp = hex("#D96C8A"),
	sk = hex("#E2B98F"), -- кожа жителей
	bl = hex("#4F6FB0"), -- одежда
	pu = hex("#7A5BA6"),
	mem = Palette.Memory, -- память (только память)
	memd = Palette.MemoryDim,
	cv1 = hex("#4A4350"), -- пещера
	cv2 = hex("#3A2E2A"),
	cv3 = hex("#2A2428"),
	-- Не из таблицы ТЗ: зарево за северным хребтом (раздел 4.1).
	glow = hex("#8C2850"),
}

-- Материальные ступени weapons3d.py, только фолбэк оружия этажа 1.
-- Glow и общая палитра окружения не меняются.
Palette.WeaponFloor1 = {
	grip = hex("#141A26"), gripWrap = hex("#382C29"),
	guard = hex("#465363"), blade = hex("#81949E"),
	bladeDark = hex("#172333"), bladeEdge = hex("#F5E4BF"),
	rust = hex("#91421F"), rustLight = hex("#D78332"),
	gold = hex("#D59A32"), bronze = hex("#80502B"), bronzeDark = hex("#282031"),
	cream = hex("#CFB987"), iron = hex("#172333"), ironLight = hex("#81949E"),
	wood = hex("#765039"),
}

-- Холодная материальная оправа для запасного показа оружия садов.
Palette.WeaponFloor2 = {
	grip = hex("#141A26"), gripWrap = hex("#52684F"),
	guard = hex("#102A3A"), blade = hex("#8FBAB8"),
	bladeDark = hex("#3D6468"), bladeEdge = hex("#E4F4E9"),
	rust = hex("#49372D"), rustLight = hex("#8FC66B"),
	gold = hex("#D59A32"), bronze = hex("#2C6875"), bronzeDark = hex("#102632"),
	cream = hex("#EFF7ED"), iron = hex("#172333"), ironLight = hex("#8FBAB8"),
	wood = hex("#382C29"),
}

function Palette.floor(id: number)
	return Palette.Floors[id]
end

return Palette
