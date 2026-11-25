--!nonstrict
-- Floor3
-- Этаж 3 «Псарни охоты» (тема «Королевская охота», план floor3_plan_v1, согласован
-- с Артёмом): 15 зон + 3 секрета, три трофея открывают ристалище.
--   Т1 «Перо сокола»   — Сокольня, после зачистки
--   Т2 «Рог егерей»    — Вышка егерей, после удержания 60 с
--   Т3 «Клык вожака»   — Королевская псарня, мини-босс «Вожак своры»
-- Каждый трофей зажигает жаровню на донжоне; все три — поднимается Трофейная
-- решётка, за ней Королевское ристалище и босс «Королевский ловчий».
-- Карта — Workspace.Floor3Map (пакет floor3map), точки — Floor3Points (генерирует
-- f3/kit/export.py). Координаты ниже ЛОКАЛЬНЫЕ, в мир их переводит Offset; точки
-- Floor3Points уже мировые.
--
-- Своих врагов у этажа пока нет: стоят типы этажей 1–2 (заглушки, план — гончие,
-- егеря, сокольники, загонщики). Мини-босс — механика Сотника, босс — Привратника
-- с прыжками на вышки ристалища и метанием копий (Floor3World).
--
-- Свои поля этажа 3 (Floor3World):
--   nested     зона внутри другой — проверяется раньше
--   secret     имя ветхой стены (Dyn_<имя>): разбил — открыл проход в тайник
--   trophy     id трофея, который выдаёт зона после зачистки
--   cages      двери клеток/денников { door, at }: враг появился у at — дверь открылась
--   hazards    постоянные лужи { "mud" | "tar", точка, радиус } — замедляют
--   bearTraps  капканы (точки), tripwires — растяжки (точки линий)
--   plates     нажимные плиты самострелов { plate, from, dir }
--   span       обрушающийся пролёт моста, chandeliers — люстры Трофейного зала
--   cart       сорвавшаяся телега конюшен, perches — вышки ристалища для босса

local P = require(script.Parent.Floor3Points)

local Floor3 = {}

Floor3.FloorId = 3
Floor3.MapName = "Floor3Map"
Floor3.FolderName = "Floor3"
Floor3.RuntimeName = "Floor3Runtime"
Floor3.Offset = Vector3.new(5200, 0, 0)

-- Овраг под мостом: дно на −18. Ниже FallLimit — сорвался: на старт зоны (у моста — к краю оврага).
Floor3.FallLimit = -10
Floor3.FallDamagePct = 0.12

Floor3.GateTime = 0.7
Floor3.Seal = { transparency = 0.55, color = Color3.fromRGB(217, 164, 65) } -- #D9A441, золото охоты

Floor3.Chests = {
	mews = { tier = "rare", minRarity = "rare", epicChance = 0.2 },
	tannery = { tier = "rare", minRarity = "rare", epicChance = 0.2 },
	kennels = { tier = "epic", minRarity = "rare", epicChance = 0.45 },
	secret = { tier = "rare", minRarity = "rare", epicChance = 0.4 },
	boss = { tier = "epic", final = true },
}

Floor3.Keys = {}
Floor3.KeyPickupRadius = 6

-- Трофеи: подобрать (удерживать E) после зачистки своей зоны.
Floor3.Trophies = {
	{ id = "T1", name = "Перо сокола", zone = "mews", at = P.mews.TROPHY_T1, brazier = P.castle.BRAZIER_1, color = Color3.fromHex("#E8DCC0") },
	{ id = "T2", name = "Рог егерей", zone = "tower", at = P.tower.TROPHY_T2, brazier = P.castle.BRAZIER_2, color = Color3.fromHex("#D9A441") },
	{ id = "T3", name = "Клык вожака", zone = "kennels", at = P.kennels.TROPHY_T3, brazier = P.castle.BRAZIER_3, color = Color3.fromHex("#F2EAD8") },
}
Floor3.TrophyHold = 0.8 -- удерживать E, с
Floor3.TrophyGate = "Dyn_TrophyPortcullis" -- решётка Трофейных ворот замка (поднимается после трёх)
Floor3.SignalFire = P.tower.SignalFire -- сигнальный костёр вышки: загорается после удержания

-- Ловушки (числа — доп., правятся на тестах).
Floor3.Traps = {
	bear = { radius = 1.7, root = 1.4, damage = 14, rearm = 6.0 }, -- капкан: держит и кусает
	trip = { half = 8.0, depth = 0.9 }, -- растяжка с колокольцами: звенит (засаду поднимает группа зоны)
	xbow = { warn = 0.35, cooldown = 3.0, count = 2, spread = 4, speed = 62, damage = 16, plate = 2.2 },
	mud = { slow = 0.8 },
	tar = { slow = 0.5 },
	span = { crack = 1.0, back = 8.0, half = Vector3.new(6, 0, 4) }, -- пролёт моста: трещит и рушится
	chandelier = { first = 6.0, every = 8.0, warn = 1.3, radius = 5.5, damage = 30 }, -- пока идёт арена зала
	cart = { warn = 1.2, speed = 30, width = 3.2, damage = 26, cooldown = 14.0, knock = 38 },
	perch = { first = 12.0, every = 16.0, stay = 6.5, volleys = 3, gap = 1.6, spread = 6, speed = 70, damage = 22 },
}

local O = Floor3.Offset
local function V(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z) + O
end
local function B(x0, y0, z0, x1, y1, z1)
	return { x0 + O.X, y0, z0 + O.Z, x1 + O.X, y1, z1 + O.Z }
end
local function A(x0, z0, x1, z1)
	return { x0 + O.X, z0 + O.Z, x1 + O.X, z1 + O.Z }
end
local function C(cx, cz, r)
	return { cx = cx + O.X, cz = cz + O.Z, r = r }
end
-- Триггер засады: куб вокруг точки.
local function T(point: Vector3, r: number)
	return { point.X - r, point.Y - 5, point.Z - r, point.X + r, point.Y + 25, point.Z + r }
end
-- Порог двери клетки на улице (сами клетки в домах псарного ряда).
local function door(name: string, x: number, z: number)
	return { door = "Dyn_" .. name, at = V(x, 0, z) }
end

local K, M, R, TN, BR, TW = P.kennelrow, P.manege, P.range, P.tannery, P.bridge, P.tower
local ST, KN, TH, L = P.stables, P.kennels, P.trophy, P.lists

Floor3.Destructibles = {
	{ id = "stable_barrel", kind = "barrel", at = V(38, 0, -136), hits = 3, radius = 1.4 },
	{ id = "stable_hay", kind = "hay", at = V(18, 0, -136), hits = 2, radius = 1.6 },
}

Floor3.Zones = {
	-- ===== I. Псарни =====
	{
		id = "gate",
		name = "Охотничьи ворота",
		kind = "intro",
		box = B(-64, -5, 284, -4, 25, 356),
		start = P.gate.PlayerStart,
		areas = { A(-62, 286, -6, 352) },
		groups = {
			{ trigger = B(-36, -5, 288, -4, 25, 316), enemies = { { "hound", V(-14, 0, 298) }, { "hound", V(-14, 0, 306), 0.6 } } },
		},
	},
	{
		id = "kennelrow",
		name = "Псарный ряд",
		kind = "street",
		box = B(-6, -5, 288, 130, 25, 316),
		start = V(-2, 0, 302),
		areas = { A(-5, 292.5, 128, 311.5) },
		hazards = {
			{ "mud", V(14, 0, 300), 3.5 }, { "mud", V(38, 0, 306), 4.5 }, { "mud", V(60, 0, 298), 3 },
			{ "mud", V(88, 0, 303), 5 }, { "mud", V(112, 0, 299), 3.5 },
		},
		cages = {
			door("Cage_A1", 15, 294), door("Cage_A2", 15, 310),
			door("Cage_B1", 71, 294), door("Cage_B2", 69, 310),
			door("Cage_C1", 119, 294), door("Cage_C2", 119, 310),
		},
		groups = {
			{ trigger = T(K.Amb_A, 7), enemies = { { "hound", V(15, 0, 294) }, { "hound", V(15, 0, 310), 0.4 }, { "beater", V(30, 0, 302), 1.0 } } },
			{ trigger = T(K.Amb_B, 7), enemies = { { "hound", V(71, 0, 294) }, { "hound", V(69, 0, 310), 0.3 }, { "crossbowman", V(90, 0, 300), 0.6 }, { "beater_elite", V(84, 0, 304), 1.2 } } },
			{ trigger = T(K.Amb_C, 7), enemies = { { "hound", V(119, 0, 294) }, { "hound", V(119, 0, 310), 0.3 }, { "bear_hunter", V(124, 0, 302), 0.8 }, { "trapper", V(100, 0, 296), 1.2 } } },
		},
	},
	{
		id = "oldpen",
		name = "Заброшенный вольер",
		kind = "branch",
		nested = true,
		box = B(38, -5, 314, 74, 25, 354),
		enter = B(42, -5, 328, 70, 25, 352),
		start = V(56, 0, 330),
		areas = { A(40, 326, 72, 352) },
		secret = "BoardedPen",
		secretAt = K.SECRET_BoardedPen,
		waves = { { { "hound", V(48, 0, 342) }, { "hound", V(64, 0, 342) }, { "beater_elite", V(56, 0, 346) } } },
		chest = { at = P.oldpen.ChestPen, kind = "secret" },
	},
	{
		id = "manege",
		name = "Манеж выездки",
		kind = "arena",
		box = B(126, -5, 256, 220, 30, 350),
		enter = B(140, -5, 270, 206, 30, 334),
		start = M.PlayerEnter,
		areas = { C(173, 302, 43) },
		gates = { entry = { "Gate_F3_ManegeW" }, exit = { "Gate_F3_ManegeE", "Gate_F3_ManegeN" } },
		bearTraps = { M.TRAP_1, M.TRAP_2, M.TRAP_3, M.TRAP_4, M.TRAP_5, M.TRAP_6, M.TRAP_7, M.TRAP_8 },
		waves = {
			{ { "hound", M.SP_m1 }, { "hound", M.SP_m3 }, { "hound", M.SP_m5 }, { "beater_elite", M.SP_m7 }, { "crossbowman", M.SP_m2 } },
			{ { "bear_hunter_elite", M.SP_m4 }, { "hound", M.SP_m6 }, { "hound", M.SP_m8 }, { "trapper", M.SP_m2 }, { "trapper", M.SP_m6 } },
		},
	},
	{
		id = "mews",
		name = "Сокольня",
		kind = "branch",
		box = B(220, -5, 270, 296, 30, 336),
		enter = B(242, -5, 278, 292, 30, 330),
		start = P.mews.PlayerEnter,
		areas = { A(236, 274, 292, 332) },
		gates = { entry = { "Gate_F3_Mews" } },
		trophy = "T1",
		waves = {
			{ { "falcon", V(272, 0, 306) }, { "falcon", P.mews.SP_f2 }, { "falcon", P.mews.SP_f3 }, { "falconer", P.mews.SP_f5 }, { "falconer", P.mews.SP_f6 } },
			{ { "falcon", P.mews.SP_f4 }, { "falcon", P.mews.SP_f2 }, { "falcon", P.mews.SP_f6 }, { "beater_elite", P.mews.SP_f3 }, { "crossbowman", P.mews.SP_f5 } },
		},
		chest = { at = P.mews.ChestMews, kind = "mews" },
	},
	{
		id = "lodge",
		name = "Охотничий домик",
		kind = "rest",
		box = B(146, -5, 212, 200, 25, 256),
		start = P.lodge.PlayerEnter,
		campfire = P.lodge.Campfire,
	},

	-- ===== II. Лес =====
	{
		id = "trail",
		name = "Тропа загонщиков",
		kind = "street",
		box = B(161, -5, 102, 185, 25, 212),
		start = P.trail.PlayerEnter,
		areas = { A(163, 104, 183, 211) },
		hazards = { { "mud", V(174, 0, 190), 2.5 }, { "mud", V(170, 0, 158), 3 }, { "mud", V(176, 0, 137), 2.5 } },
		bearTraps = { P.trail.TRAP_t1, P.trail.TRAP_t2, P.trail.TRAP_t3, P.trail.TRAP_t4 },
		tripwires = { P.trail.TRIP_1, P.trail.TRIP_2 },
		groups = {
			-- засады поднимают растяжки: группа срабатывает ровно на линии
			{ trigger = B(163, -5, 185.6, 183, 25, 187.6), enemies = { { "hound", P.trail.SP_t3 }, { "hound", P.trail.SP_t4, 0.3 }, { "trapper", P.trail.SP_t1, 0.8 } } },
			{ trigger = B(163, -5, 175.6, 183, 25, 177.6), enemies = { { "beater_elite", P.trail.SP_t5 }, { "crossbowman", P.trail.SP_t2, 0.5 }, { "hound", P.trail.SP_t6, 0.9 } } },
			{ trigger = B(163, -5, 120, 183, 25, 134), enemies = { { "bear_hunter", V(173, 0, 112) }, { "hound", V(167, 0, 118), 0.4 }, { "hound", V(179, 0, 118), 0.8 } } },
		},
	},
	{
		id = "poacher",
		name = "Тайник браконьера",
		kind = "branch",
		box = B(184, -5, 140, 248, 25, 178),
		enter = B(212, -5, 144, 244, 25, 174),
		start = V(200, 0, 158),
		areas = { A(186, 142, 246, 176) },
		secret = "HideCurtain",
		secretAt = P.trail.SECRET_HideCurtain,
		waves = { { { "trapper", V(236, 0, 150) }, { "trapper", V(236, 0, 168) }, { "beater_elite", V(222, 0, 160) }, { "hound", V(240, 0, 160) } } },
		chest = { at = P.poacher.ChestPoacher, kind = "secret" },
	},
	{
		id = "range",
		name = "Стрельбище",
		kind = "arena",
		box = B(121, -5, 20, 225, 30, 104),
		enter = B(128, -5, 28, 218, 30, 96),
		start = R.PlayerEnter,
		areas = { A(124, 23, 222, 103) },
		gates = { entry = { "Gate_F3_RangeS" }, exit = { "Gate_F3_RangeN", "Gate_F3_RangeE" } },
		plates = {
			{ plate = R.TRAP_r1, from = R.XBOW_r1 },
			{ plate = R.TRAP_r2, from = R.XBOW_r2 },
		},
		waves = {
			{ { "crossbowman", R.SP_rg1 }, { "crossbowman", R.SP_rg4 }, { "trapper", R.SP_rg2 }, { "beater_elite", R.SP_r3 }, { "hound", R.SP_r1 }, { "hound", R.SP_r2 } },
			{ { "trapper", R.SP_rg3 }, { "crossbowman", R.SP_rg2 }, { "bear_hunter_elite", R.SP_r3 }, { "beater_elite", R.SP_r6 }, { "hound", R.SP_r7 }, { "torchbearer", R.SP_r4 } },
		},
	},
	{
		id = "tannery",
		name = "Кожевня",
		kind = "branch",
		box = B(225, -5, 32, 298, 25, 96),
		enter = B(242, -5, 38, 294, 25, 92),
		start = TN.PlayerEnter,
		areas = { A(237, 35, 295, 93) },
		hazards = {
			{ "tar", TN.TAR_1, 5 }, { "tar", TN.TAR_2, 5 }, { "tar", TN.TAR_3, 5 },
			{ "mud", V(262, 0, 70), 8 }, { "mud", V(245, 0, 88), 5 }, { "mud", V(290, 0, 84), 6 },
		},
		waves = {
			{ { "skinner", TN.SP_tn1 }, { "skinner", TN.SP_tn2 }, { "tanner", TN.SP_tn3 }, { "beater_elite", TN.SP_tn4 } },
			{ { "bear_hunter_elite", TN.SP_tn2 }, { "tanner", TN.SP_tn4 }, { "skinner", TN.SP_tn1 }, { "hound", TN.SP_tn3 } },
		},
		chest = { at = TN.ChestTannery, kind = "tannery" },
	},
	{
		id = "bridge",
		name = "Мост через овраг",
		kind = "street",
		box = B(163, -30, -112, 183, 25, 22),
		start = BR.RavineRespawn,
		areas = { A(166, -110, 180, 20) },
		span = { name = "Dyn_BridgeSpan", at = BR.COLLAPSE },
		groups = {
			-- соколы пикируют на мост (заглушка — пчёлы-стражи)
			{ trigger = B(163, -5, -30, 183, 25, -10), enemies = { { "falcon", V(173, 0, -40) }, { "falcon", V(170, 0, -36), 0.5 } } },
			{ trigger = B(163, -5, -80, 183, 25, -62), enemies = { { "falcon", V(173, 0, -96) }, { "falcon", V(176, 0, -100), 0.4 }, { "falconer", V(173, 0, -106), 0.8 } } },
		},
	},
	{
		id = "tower",
		name = "Вышка егерей",
		kind = "hold",
		box = B(124, -5, -202, 222, 40, -111),
		enter = B(140, -5, -190, 206, 40, -124),
		start = TW.PlayerEnter,
		areas = { A(130, -198, 216, -114) },
		gates = { entry = { "Gate_F3_TowerS" }, exit = { "Gate_F3_TowerW" } },
		trophy = "T2",
		hold = {
			duration = 60,
			limit = 7,
			every = 2.2,
			flows = { TW.SP_hw1, TW.SP_he1, TW.SP_hw2, TW.SP_he2, TW.SP_hw3, TW.SP_he3 },
			mix = { "hound", "trapper", "beater_elite", "hound", "crossbowman", "bear_hunter", "hound", "beater_elite", "torchbearer", "trapper" },
			innerGate = "F3NoInnerGate", -- внутренней решётки нет (FloorMap.setRaise молча пропускает)
		},
	},

	-- ===== III. Королевский двор =====
	{
		id = "chapel",
		name = "Часовня Белого оленя",
		kind = "rest",
		box = B(54, -5, -182, 124, 25, -138),
		start = P.chapel.PlayerEnter,
		campfire = P.chapel.Campfire,
	},
	{
		id = "stables",
		name = "Королевские конюшни",
		kind = "street",
		box = B(-98, -5, -186, 54, 25, -130),
		start = ST.PlayerEnter,
		areas = { A(-97, -176, 53, -141) },
		hazards = { { "mud", V(-70, 0, -164), 2.5 }, { "mud", V(-20, 0, -152), 3 }, { "mud", V(24, 0, -165), 2.5 }, { "mud", V(-88, 0, -151), 2 } },
		cages = {
			{ door = "Dyn_Stall_N1", at = ST.SP_Stall_N1 }, { door = "Dyn_Stall_N2", at = ST.SP_Stall_N2 }, { door = "Dyn_Stall_N3", at = ST.SP_Stall_N3 },
			{ door = "Dyn_Stall_S1", at = ST.SP_Stall_S1 }, { door = "Dyn_Stall_S2", at = ST.SP_Stall_S2 }, { door = "Dyn_Stall_S3", at = ST.SP_Stall_S3 },
		},
		cart = { model = "Dyn_RunawayCart", from = ST.CART_START, to = ST.CART_END, trigger = B(-90, -5, -176, 24, 25, -140) },
		groups = {
			{ trigger = B(-6, -5, -176, 20, 25, -140), enemies = { { "beater_elite", ST.SP_Stall_N3 }, { "hound", ST.SP_Stall_S3, 0.3 }, { "crossbowman", ST.SP_s6, 0.8 } } },
			{ trigger = B(-48, -5, -176, -24, 25, -140), enemies = { { "bear_hunter_elite", ST.SP_Stall_N2 }, { "hound", ST.SP_Stall_S2, 0.3 }, { "trapper", ST.SP_s2, 0.7 }, { "hound", ST.SP_s3, 1.0 } } },
			{ trigger = B(-90, -5, -176, -64, 25, -140), enemies = { { "beater_elite", ST.SP_Stall_N1 }, { "beater_elite", ST.SP_Stall_S1, 0.4 }, { "torchbearer", ST.SP_s1, 0.8 } } },
		},
	},
	{
		id = "kennels",
		name = "Королевская псарня",
		kind = "miniboss",
		box = B(-198, -5, -176, -98, 30, -74),
		enter = B(-190, -5, -166, -108, 30, -82),
		start = KN.PlayerEnter,
		areas = { A(-194, -170, -102, -78) },
		gates = { entry = { "Gate_F3_KennelsE" }, exit = { "Gate_F3_KennelsS" } },
		hazards = { { "mud", V(-180, 0, -140), 4 }, { "mud", V(-118, 0, -106), 3.5 }, { "mud", V(-170, 0, -100), 3 }, { "mud", V(-128, 0, -146), 3 } },
		cages = {
			{ door = "Dyn_KCage_N1", at = KN.SP_KCage_N1 }, { door = "Dyn_KCage_N2", at = KN.SP_KCage_N2 }, { door = "Dyn_KCage_N3", at = KN.SP_KCage_N3 },
			{ door = "Dyn_KCage_S1", at = KN.SP_KCage_S1 }, { door = "Dyn_KCage_S2", at = KN.SP_KCage_S2 }, { door = "Dyn_KCage_S3", at = KN.SP_KCage_S3 },
		},
		-- Мини-босс «Вожак своры» (заглушка — механика Сотника: знамя, рог, свора из клеток).
		boss = { typeId = "pack_leader", at = KN.MINIBOSS },
		bossName = "Вожак своры",
		bossTitle = "Пёс королевской охоты",
		points = {
			banner = V(-166, 0, -112),
			squads = { KN.SP_KCage_N1, KN.SP_KCage_S2, KN.SP_KCage_N3, KN.SP_KCage_S1 },
			key = KN.TROPHY_T3,
		},
		trophy = "T3",
		chest = { at = KN.ChestKennels, kind = "kennels" },
	},
	{
		id = "trophy",
		name = "Трофейный зал",
		kind = "arena",
		box = B(-196, -5, -74, -96, 30, 50),
		enter = B(-188, -5, -44, -112, 30, 40),
		start = TH.PlayerEnter,
		areas = { A(-194, -50, -106, 46) },
		gates = { entry = { "Gate_F3_TrophyN" }, exit = { "Gate_F3_TrophyE" } },
		chandeliers = {
			{ name = "Dyn_Chandelier_1", at = TH.CHANDELIER_1 }, { name = "Dyn_Chandelier_2", at = TH.CHANDELIER_2 },
			{ name = "Dyn_Chandelier_3", at = TH.CHANDELIER_3 }, { name = "Dyn_Chandelier_4", at = TH.CHANDELIER_4 },
		},
		waves = {
			{ { "bear_hunter_elite", TH.SP_th5 }, { "beater_elite", TH.SP_th1 }, { "beater_elite", TH.SP_th2 }, { "crossbowman", TH.SP_th3 }, { "crossbowman", TH.SP_th4 }, { "hound", TH.SP_th7 } },
			{ { "bear_hunter_elite", TH.SP_th6 }, { "trophy_bear", TH.SP_th8 }, { "trapper", TH.SP_th1 }, { "trapper", TH.SP_th2 }, { "hound", TH.SP_th7 }, { "torchbearer", TH.SP_th5 } },
		},
	},
	{
		id = "armory",
		name = "Оружейная егермейстера",
		kind = "branch",
		nested = true,
		box = B(-264, -5, -24, -196.5, 25, 16),
		enter = B(-258, -5, -20, -226, 25, 12),
		start = P.armory.PlayerEnter,
		areas = { A(-260, -20, -224, 12) },
		secret = "Tapestry",
		secretAt = TH.SECRET_Tapestry,
		waves = { { { "bear_hunter_elite", V(-250, 0, -4) }, { "beater_elite", V(-236, 0, -14) }, { "beater_elite", V(-236, 0, 6) } } },
		chest = { at = P.armory.ChestArmory, kind = "secret" },
	},
	{
		id = "lists",
		name = "Королевское ристалище",
		kind = "boss",
		box = B(-96, -5, -88, 88, 40, 88),
		enter = B(-46, -5, -46, 46, 40, 46),
		start = L.PlayerEnter,
		areas = { C(0, 0, 49) },
		-- Решётка Трофейных ворот поднимается от трёх трофеев (Floor3World), на время боя — вниз.
		boss = { typeId = "royal_huntsman", at = L.BOSS },
		bossName = "Королевский ловчий",
		bossTitle = "Хозяин королевской охоты",
		points = { summons = { L.SP_l1, L.SP_l3, L.SP_l5 } },
		perches = { V(-29, 9, -29), V(29, 9, -29), V(-29, 9, 29), V(29, 9, 29) },
		chest = { at = L.ChestBoss, kind = "boss" },
	},
}

function Floor3.byId(id: string)
	for index, zone in ipairs(Floor3.Zones) do
		if zone.id == id then
			return zone, index
		end
	end
	return nil, nil
end

function Floor3.trophyById(id: string)
	for index, trophy in ipairs(Floor3.Trophies) do
		if trophy.id == id then
			return trophy, index
		end
	end
	return nil, nil
end

function Floor3.inBox(box, position: Vector3): boolean
	return position.X >= box[1] and position.X <= box[4]
		and position.Y >= box[2] and position.Y <= box[5]
		and position.Z >= box[3] and position.Z <= box[6]
end

function Floor3.bounds(zone)
	local areas = {}
	for _, a in ipairs(zone.areas or {}) do
		if a.r then
			table.insert(areas, { cx = a.cx, cz = a.cz, r = a.r })
		else
			table.insert(areas, { x0 = a[1], z0 = a[2], x1 = a[3], z1 = a[4] })
		end
	end
	return { areas = areas }
end

return Floor3


