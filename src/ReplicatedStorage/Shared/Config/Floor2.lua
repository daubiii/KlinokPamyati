--!nonstrict
-- Floor2
-- Этаж 2 «Затопленные сады» (концепт floor2-concept.md, решения Артёма 29.10.2026):
-- 15 зон + 3 секрета, мини-боссов нет; три вентиля шлюзов (секрет в лабиринте,
-- купальня, мельница) спускают воду у Розового двора, после трёх — бой с Садовницей.
-- Карта — Workspace.Floor2Map (собирается в Studio из пакета), точки — Floor2Points
-- (генерирует f2/map/kit/bake2.py). Координаты ниже — ЛОКАЛЬНЫЕ (как в китe карты),
-- в мир их переводит Offset; точки из Floor2Points уже мировые.
--
-- Виды зон — как у этажа 1 (Floor1v2): intro, street, arena, branch, rest, hold, boss.
-- Свои поля этажа 2:
--   nested    зона внутри другой (беседка в лабиринте) — проверяется раньше
--   secret    имя заросшей стены (Dyn_<имя>): разбил — открыл проход
--   valve     вентиль, который открывается после зачистки зоны
--   hazards   постоянные лужи { вид, точка, радиус } (гниль, мёд, вода)
--   jets, spores, spikes, darts, planks, span — ловушки (Floor2World)

local P = require(script.Parent.Floor2Points)

local Floor2 = {}

Floor2.FloorId = 2
Floor2.MapName = "Floor2Map"
Floor2.FolderName = "Floor2"
Floor2.RuntimeName = "Floor2Runtime"
Floor2.Offset = Vector3.new(2600, 0, 0)

-- Вода: гладь на −1,6, дно на −12. Ниже FallLimit — «утонул»: на старт зоны.
Floor2.FallLimit = -9
Floor2.FallDamagePct = 0.15

Floor2.GateTime = 0.7
Floor2.Seal = { transparency = 0.55, color = Color3.fromRGB(95, 208, 192) }

Floor2.Chests = {
	greenhouse = { tier = "rare", minRarity = "rare" },
	apiary = { tier = "rare", minRarity = "rare", epicChance = 0.15 },
	baths = { tier = "rare", minRarity = "rare", epicChance = 0.2 },
	secret = { tier = "rare", minRarity = "rare", epicChance = 0.35 },
	boss = { tier = "epic", final = true },
}

-- Ключей этажа 1 нет: вместо них вентили шлюзов.
Floor2.Keys = {}
Floor2.KeyPickupRadius = 6
Floor2.Valves = {
	{ id = "F2Valve1", name = "Вентиль беседки", zone = "arbor", at = P.maze.VALVE_F2Valve1 },
	{ id = "F2Valve2", name = "Вентиль купальни", zone = "baths", at = P.baths.VALVE_F2Valve2 },
	{ id = "F2Valve3", name = "Вентиль мельницы", zone = "mill", at = P.mill.VALVE_F2Valve3 },
}
Floor2.ValveHold = 1.2 -- удерживать E, с
Floor2.FloodDrop = 1.25 -- на столько опускается вода двора за вентиль, стад
Floor2.SluiceGate = "Gate_F2_Sluice"

-- Ловушки (числа — доп., правятся на тестах).
Floor2.Traps = {
	planks = { hold = 0.6, back = 6.0, radius = 1.15 }, -- стоишь на гнилой доске 0,6 с — проваливается
	span = { crack = 1.2, back = 8.0 }, -- пролёт акведука трескается и рушится
	jets = { every = 5.0, warn = 0.9, radius = 3.2, life = 4.0, count = 2 }, -- струи гнили фонтана (арена)
	spores = { every = 6.0, warn = 1.0, radius = 4.5, life = 3.0, poison = 0.05 }, -- споровые грибы террас (арена)
	darts = { warn = 0.35, cooldown = 3.0, count = 3, spread = 9, speed = 48, damage = 14, plate = 2.4 },
	spikes = { idle = 2.4, warn = 0.8, active = 1.2, radius = 2.2, damage = 12, tick = 0.5 },
}

local O = Floor2.Offset
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

Floor2.Zones = {
	-- ===== I. Вход в сад =====
	{
		id = "pier",
		name = "Причал",
		kind = "intro",
		box = B(-23, -14, 118, 23, 25, 181),
		start = P.pier.PlayerStart,
		areas = { A(-21, 121, 21, 149), A(-5.5, 150, 5.5, 171) },
		groups = {
			{ trigger = B(-22, -5, 128, 22, 25, 152), enemies = { { "drowned", P.pier.SP_d1 }, { "drowned", P.pier.SP_d2, 1.2 } } },
		},
	},
	{
		id = "avenue",
		name = "Ивовая аллея",
		kind = "street",
		box = B(-17, -5, 4, 17, 25, 119),
		start = V(0, 0, 114),
		areas = { A(-15, 9, 15, 118) },
		hazards = { { "rot", P.avenue.ROT, 2.6 }, { "rot", P.avenue.ROT_2, 2.6 }, { "rot", P.avenue.ROT_3, 2.6 } },
		groups = {
			{ trigger = B(-16, -5, 90, 16, 25, 106), enemies = { { "drowned", P.avenue.SP_a1 }, { "drowned", P.avenue.SP_a2, 0.8 }, { "bee", P.avenue.SP_a3, 1.5 } } },
			{ trigger = B(-16, -5, 54, 16, 25, 70), enemies = { { "bee", P.avenue.SP_b1 }, { "bee", P.avenue.SP_b2, 0.5 }, { "bee", P.avenue.SP_b3, 1.0 } } },
			{ trigger = B(-16, -5, 16, 16, 25, 32), enemies = { { "gardener", P.avenue.SP_c1 }, { "ranger", P.avenue.SP_c2 }, { "drowned", P.avenue.SP_c3, 1.0 } } },
		},
	},
	{
		id = "fountain",
		name = "Фонтанная площадь",
		kind = "arena",
		box = B(-63, -5, -90, 53, 25, 4),
		enter = B(-36, -5, -76, 36, 25, -6),
		start = P.fountain.PlayerEnter,
		areas = { C(0, -40, 46) },
		gates = { entry = { "Gate_F2_FountainS" }, exit = { "Gate_F2_FountainE", "Gate_F2_Greenhouse" } },
		jets = { P.fountain.JET_1, P.fountain.JET_2, P.fountain.JET_3, P.fountain.JET_4 },
		waves = {
			{
				{ "gardener", P.fountain.SP_f1 },
				{ "gardener", P.fountain.SP_f5 },
				{ "bee", P.fountain.SP_f2 },
				{ "bee", P.fountain.SP_f3 },
				{ "bee", P.fountain.SP_f7 },
			},
			{
				{ "treant", P.fountain.SP_f1 },
				{ "drowned", P.fountain.SP_f4 },
				{ "drowned", P.fountain.SP_f6 },
				{ "ranger", P.fountain.SP_f8 },
				{ "bee", P.fountain.SP_f3 },
			},
		},
	},
	{
		id = "greenhouse",
		name = "Оранжерея",
		kind = "branch",
		box = B(-133, -5, -73, -61.5, 25, -7),
		enter = B(-128, -5, -70, -68, 25, -10),
		start = P.greenhouse.PlayerEnter,
		areas = { A(-130, -70, -64, -10) },
		gates = { entry = { "Gate_F2_Greenhouse" } },
		waves = {
			{ { "ranger", P.greenhouse.SP_g1 }, { "ranger", P.greenhouse.SP_g2 }, { "bee", P.greenhouse.SP_g3 }, { "bee", P.greenhouse.SP_g4 } },
			{ { "gardener", P.greenhouse.SP_g5 }, { "ranger", P.greenhouse.SP_g6 }, { "bee", P.greenhouse.SP_g3 }, { "drowned", P.greenhouse.SP_g1 } },
		},
		chest = { at = P.greenhouse.ChestG, kind = "greenhouse" },
	},
	{
		id = "maze",
		name = "Лабиринт изгороди",
		kind = "street",
		box = B(51, -5, -105, 153, 25, -3),
		start = V(58, 0, -40),
		areas = { A(53, -103, 151, -5) },
		spikes = { P.maze.SPIKE_1, P.maze.SPIKE_2, P.maze.SPIKE_3, P.maze.SPIKE_4 },
		groups = {
			{ trigger = T(P.maze.SP_m1, 7), enemies = { { "drowned", P.maze.SP_m2 }, { "bee", P.maze.SP_m3, 0.8 } } },
			{ trigger = T(P.maze.SP_m3, 7), enemies = { { "gardener", P.maze.SP_m8 }, { "bee", P.maze.SP_m7, 0.6 } } },
			{ trigger = T(P.maze.SP_m4, 7), enemies = { { "treant", P.maze.SP_m5 }, { "ranger", P.maze.SP_m6 } } },
		},
	},
	{
		id = "arbor",
		name = "Беседка в сердце лабиринта",
		kind = "branch",
		nested = true,
		box = B(95.5, -5, -75, 122.8, 25, -47.5),
		enter = B(98, -5, -72, 120, 25, -50),
		start = P.maze.ArborCenter,
		areas = { A(96, -74, 122, -49) },
		secret = "F2Overgrowth_Arbor",
		secretAt = P.maze.SECRET_F2Overgrowth_Arbor,
		valve = "F2Valve1",
		waves = {
			{ { "treant", P.maze.ArborCenter + Vector3.new(-6, 0, -6) }, { "bee", P.maze.ArborCenter + Vector3.new(6, 0, -6) }, { "bee", P.maze.ArborCenter + Vector3.new(6, 0, 6) } },
		},
	},
	{
		id = "lodge",
		name = "Домик садовника",
		kind = "rest",
		box = B(76, -5, -144, 126, 25, -105),
		start = P.lodge.PlayerEnter,
		campfire = P.lodge.Campfire,
	},

	-- ===== II. Вода =====
	{
		id = "canals",
		name = "Каналы",
		kind = "street",
		box = B(62, -14, -271, 137, 25, -142),
		start = P.canals.PlayerEnter,
		areas = {
			A(64, -160, 136, -144),
			A(64, -260, 80, -160),
			A(120, -260, 136, -160),
			A(92, -196, 108, -160),
			A(92, -260, 108, -212),
			A(64, -270, 136, -260),
		},
		planks = "F2Plank_",
		groups = {
			{ trigger = B(64, -5, -170, 136, 25, -148), enemies = { { "drowned", P.canals.SP_k3 }, { "drowned", P.canals.SP_k1, 0.8 }, { "bee", P.canals.SP_k2, 1.2 } } },
			{ trigger = B(64, -5, -222, 136, 25, -192), enemies = { { "ranger", P.canals.SP_k7 }, { "ranger", P.canals.SP_k9 }, { "drowned", P.canals.SP_k4 }, { "bee", P.canals.SP_k6, 1.0 } } },
			{ trigger = B(64, -5, -262, 136, 25, -238), enemies = { { "drowned", P.canals.SP_k8 }, { "gardener", P.canals.SP_k5 }, { "bee", P.canals.SP_k6, 0.6 } } },
		},
	},
	{
		id = "grotto",
		name = "Грот за водопадом",
		kind = "branch",
		box = B(136.5, -5, -227, 174, 25, -195),
		enter = B(140, -5, -224, 170, 25, -198),
		start = P.grotto.PlayerEnter,
		areas = { A(139, -224, 170, -198) },
		secret = "F2Overgrowth_Grotto",
		secretAt = P.canals.SECRET_F2Overgrowth_Grotto,
		waves = { { { "drowned", P.grotto.SP_gr1 }, { "ranger", P.grotto.SP_gr2 }, { "drowned", P.grotto.SP_gr2 + Vector3.new(4, 0, 4) } } },
		chest = { at = P.grotto.ChestGrotto, kind = "secret" },
	},
	{
		id = "apiary",
		name = "Пасека",
		kind = "branch",
		box = B(-17, -5, -247, 59, 25, -169),
		enter = B(-14, -5, -244, 54, 25, -172),
		start = P.apiary.PlayerEnter,
		areas = { A(-14, -244, 56, -172) },
		gates = { entry = { "Gate_F2_Apiary" } },
		hazards = {
			{ "honey", P.apiary.HONEY_1, 3.2 },
			{ "honey", P.apiary.HONEY_2, 3.2 },
			{ "honey", P.apiary.HONEY_3, 3.2 },
			{ "honey", P.apiary.HONEY_4, 3.2 },
		},
		waves = {
			{ { "bee", P.apiary.SP_p1 }, { "bee", P.apiary.SP_p2 }, { "bee", P.apiary.SP_p3 }, { "bee", P.apiary.SP_p4 } },
			{ { "bee", P.apiary.SP_p5 }, { "bee", P.apiary.SP_p6 }, { "ranger", P.apiary.SP_p3 }, { "gardener", P.apiary.SP_p2 } },
		},
		chest = { at = P.apiary.ChestA, kind = "apiary" },
	},
	{
		id = "terraces",
		name = "Террасы",
		kind = "arena",
		box = B(35, -5, -366, 141, 30, -270),
		enter = B(40, -5, -360, 136, 30, -282),
		start = P.terraces.PlayerEnter,
		areas = {
			A(37, -299, 139, -277),
			A(37, -324, 139, -301),
			A(37, -363, 139, -326),
			A(46, -301, 56, -286),
			A(120, -301, 130, -286),
			A(70, -326, 80, -311),
			A(96, -326, 106, -311),
		},
		gates = { entry = { "Gate_F2_TerraceS" }, exit = { "Gate_F2_TerraceW", "Gate_F2_Baths" } },
		spores = { P.terraces.SPORE_1, P.terraces.SPORE_2, P.terraces.SPORE_3 },
		waves = {
			{
				{ "drowned", P.terraces.SP_t1 },
				{ "drowned", P.terraces.SP_t2 },
				{ "gardener", P.terraces.SP_t3 },
				{ "ranger", P.terraces.ARCH_t1 },
				{ "ranger", P.terraces.ARCH_t2 },
			},
			{
				{ "treant", P.terraces.SP_t4 },
				{ "treant", P.terraces.SP_t5 },
				{ "bee", P.terraces.SP_t6 },
				{ "bee", P.terraces.SP_t3 },
				{ "ranger", P.terraces.ARCH_t3 },
			},
		},
	},
	{
		id = "baths",
		name = "Затопленная купальня",
		kind = "branch",
		box = B(139, -1, -361, 219, 25, -283),
		enter = B(150, -1, -356, 214, 25, -288),
		start = P.baths.PlayerEnter,
		areas = { A(148, -358, 216, -286) },
		gates = { entry = { "Gate_F2_Baths" } },
		hazards = { { "water", P.baths.POOL_1, 5 }, { "water", P.baths.POOL_2, 6 }, { "water", P.baths.POOL_3, 6 } },
		valve = "F2Valve2",
		waves = {
			{ { "drowned", P.baths.SP_b1 }, { "drowned", P.baths.SP_b3 }, { "gardener", P.baths.SP_b2 }, { "gardener", P.baths.SP_b6 } },
			{ { "treant", P.baths.SP_b4 }, { "bee", P.baths.SP_b5 }, { "bee", P.baths.SP_b2 }, { "drowned", P.baths.SP_b1 } },
		},
		chest = { at = P.baths.ChestB, kind = "baths" },
	},
	{
		id = "aqueduct",
		name = "Акведук",
		kind = "street",
		box = B(-111, -20, -355, 36, 25, -335),
		start = P.aqueduct.PlayerEnter,
		areas = { A(-109, -353, 35, -337) },
		span = { name = "F2Span", at = P.aqueduct.SPAN, half = Vector3.new(6, 0, 9) },
		groups = {
			{ trigger = B(-10, 0, -355, 20, 25, -335), enemies = { { "bee", P.aqueduct.SP_q1 }, { "bee", P.aqueduct.SP_q2, 0.6 } } },
			{ trigger = B(-70, 0, -355, -50, 25, -335), enemies = { { "bee", P.aqueduct.SP_q3 }, { "bee", P.aqueduct.SP_q4, 0.6 }, { "ranger", P.aqueduct.ARCH_q } } },
		},
	},

	-- ===== III. К Розовому двору =====
	{
		id = "mill",
		name = "Водяная мельница",
		kind = "hold",
		box = B(-191, -14, -421, -109, 25, -329),
		enter = B(-186, -5, -416, -129, 6, -334),
		start = P.mill.PlayerEnter,
		areas = { A(-188, -418, -112, -332) },
		gates = { entry = { "Gate_F2_MillIn" } },
		valve = "F2Valve3",
		hold = {
			duration = 60,
			limit = 6,
			every = 2.5,
			flows = { P.mill.FLOW_1, P.mill.FLOW_2 },
			mix = { "drowned", "bee", "gardener", "drowned", "bee", "treant", "ranger", "drowned" },
			innerGate = "F2MillGate",
			spikes = { P.mill.SPIKE_1, P.mill.SPIKE_2, P.mill.SPIKE_3, P.mill.SPIKE_4 },
		},
	},
	{
		id = "gazebo",
		name = "Беседка смотрителя",
		kind = "rest",
		box = B(-179, -5, -457, -127, 25, -421),
		start = P.gazebo.PlayerEnter,
		campfire = P.gazebo.Campfire,
	},
	{
		id = "statues",
		name = "Сад статуй",
		kind = "arena",
		box = B(-205, -5, -561, -95, 25, -457),
		enter = B(-198, -5, -554, -102, 25, -469),
		start = P.statues.PlayerEnter,
		areas = { A(-202, -558, -98, -464) },
		gates = { entry = { "Gate_F2_StatuesS" }, exit = { "Gate_F2_StatuesN" } },
		darts = {
			{ from = P.statues.DART_1, plate = P.statues.PLATE_1 },
			{ from = P.statues.DART_2, plate = P.statues.PLATE_2 },
			{ from = P.statues.DART_3, plate = P.statues.PLATE_3 },
			{ from = P.statues.DART_4, plate = P.statues.PLATE_4 },
		},
		waves = {
			{ { "treant", P.statues.SP_s1 }, { "treant", P.statues.SP_s4 }, { "gardener", P.statues.SP_s5 }, { "gardener", P.statues.SP_s6 } },
			{
				{ "drowned", P.statues.SP_s7 },
				{ "drowned", P.statues.SP_s8 },
				{ "ranger", P.statues.SP_s2 },
				{ "ranger", P.statues.SP_s3 },
				{ "bee", P.statues.SP_s1 },
				{ "bee", P.statues.SP_s4 },
			},
		},
	},
	{
		id = "crypt",
		name = "Склеп под статуей",
		kind = "branch",
		box = B(-245, -5, -541, -205.5, 25, -505),
		enter = B(-240, -5, -537, -209, 25, -509),
		start = P.crypt.PlayerEnter,
		areas = { A(-242, -538, -207, -508) },
		secret = "F2Overgrowth_Crypt",
		secretAt = P.statues.SECRET_F2Overgrowth_Crypt,
		waves = { { { "drowned", P.crypt.SP_c1 }, { "drowned", P.crypt.SP_c2 }, { "ranger", P.crypt.SP_c1 + Vector3.new(-8, 0, 0) } } },
		chest = { at = P.crypt.ChestC, kind = "secret" },
	},
	{
		id = "rosecourt",
		name = "Розовый двор",
		kind = "boss",
		box = B(-205, -14, -706, -95, 30, -561),
		enter = B(-188, -5, -688, -112, 30, -606),
		start = P.rosecourt.PlayerEnter,
		areas = { C(-150, -650, 50) },
		-- Решётка шлюза закрыта, пока не повернуты три вентиля (не entry: та открыта с начала).
		gates = { sluice = { "Gate_F2_Sluice" } },
		boss = { typeId = "rosewarden", at = P.rosecourt.BossSpawn },
		points = { summons = { P.rosecourt.SUMMON_1, P.rosecourt.SUMMON_2 } },
		chest = { at = P.rosecourt.ChestBoss, kind = "boss" },
	},
}

function Floor2.byId(id: string)
	for index, zone in ipairs(Floor2.Zones) do
		if zone.id == id then
			return zone, index
		end
	end
	return nil, nil
end

function Floor2.inBox(box, position: Vector3): boolean
	return position.X >= box[1] and position.X <= box[4]
		and position.Y >= box[2] and position.Y <= box[5]
		and position.Z >= box[3] and position.Z <= box[6]
end

function Floor2.bounds(zone)
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

return Floor2
