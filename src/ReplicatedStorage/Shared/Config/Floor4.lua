--!nonstrict
-- Floor4
-- Этаж 4 «Литейные» (план: цвета #1E1B1F #4A4350 #E2672B #FFC857; кузнечные
-- автоматы и огненные духи; босс — Старший литейщик; мини-боссов нет).
-- Порядок зон и правила — как у этажей 1–2: intro → street → arena (+branch)
-- → rest → street → hold → arena (+branch) → rest → boss. Комнаты просторные.
-- Карта — Workspace.Floor4Map (сборка: tools/AssembleFloor45.lua), точки —
-- Floor4Points (blender/bake.py, уже мировые). Координаты ниже — ЛОКАЛЬНЫЕ,
-- в мир их переводит Offset.
--
-- Свои поля этажа 4 (Systems/Floor4World):
--   cart     вагонетка по рельсам улицы (сбивает, предупреждает колоколом)
--   spills   разливы из ковшей арены литейной (точка → лужа расплава)
--   pours    жёлоба Великого горна (II фаза босса)

local P = require(script.Parent.Floor4Points)

local Floor4 = {}

Floor4.FloorId = 4
Floor4.MapName = "Floor4Map"
Floor4.FolderName = "Floor4"
Floor4.RuntimeName = "Floor4Runtime"
Floor4.Offset = Vector3.new(7800, 0, 0)

-- Пол верхнего яруса на 0, нижнего (клеть, литейная, горн) на −14.
Floor4.FallLimit = -30
Floor4.FallDamagePct = 0.15

Floor4.GateTime = 0.7
Floor4.Seal = { transparency = 0.55, color = Color3.fromRGB(226, 103, 43) } -- #E2672B

Floor4.Chests = {
	ingots = { tier = "rare", minRarity = "rare", epicChance = 0.2 },
	molds = { tier = "rare", minRarity = "rare", epicChance = 0.25 },
	boss = { tier = "epic", final = true },
}

Floor4.Keys = {}
Floor4.KeyPickupRadius = 6

-- Ловушки (числа стартовые, правятся на тестах).
Floor4.Traps = {
	cart = { every = 11, warn = 1.6, time = 3.2, width = 3.6, damage = 26, knock = 14 }, -- вагонетка улицы
	spills = { every = 6.5, warn = 1.2, life = 5, radius = 3.2, count = 2 }, -- ковши литейной (во время боя)
	molten = { damage = 6, tick = 0.5, burn = { pct = 0.02, time = 1.0 } }, -- лужа расплава: урон за тик + ожог
}

local O = Floor4.Offset
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

Floor4.Zones = {
	-- ===== I. Штольня и сортировка =====
	{
		id = "adit",
		name = "Штольня",
		kind = "intro",
		box = B(-23, -5, 140.5, 23, 25, 200),
		start = P.adit.PlayerStart,
		areas = { A(-21, 141, 21, 195) },
		groups = {
			{ trigger = B(-22, -5, 140, 22, 25, 162), enemies = { { "fire_spirit", P.adit.SP_a1 }, { "smolder", P.adit.SP_a2, 1.0 } } },
		},
	},
	{
		id = "railway",
		name = "Рудничная улица",
		kind = "street",
		box = B(-17, -5, 20.5, 17, 25, 140.5),
		start = P.railway.PlayerEnter,
		areas = { A(-15, 21, 15, 139.5) },
		cart = { from = P.railway.CART_FROM, to = P.railway.CART_TO },
		groups = {
			{ trigger = B(-16, -5, 96, 16, 25, 118), enemies = { { "fire_spirit", P.railway.SP_r1 }, { "fire_spirit", P.railway.SP_r2, 0.6 }, { "slag_thrower", P.railway.SP_r3, 1.0 } } },
			{ trigger = B(-16, -5, 60, 16, 25, 82), enemies = { { "forge_automaton", P.railway.SP_r6 }, { "smolder", P.railway.SP_r4, 0.8 }, { "smolder", P.railway.SP_r5, 1.2 } } },
			{ trigger = B(-16, -5, 26, 16, 25, 46), enemies = { { "slag_thrower", P.railway.SP_r7 }, { "slag_thrower", P.railway.SP_r8 }, { "fire_spirit", P.railway.SP_r9, 0.8 } } },
		},
	},
	{
		id = "sorting",
		name = "Сортировочный зал",
		kind = "arena",
		box = B(-46, -5, -60, 46, 30, 20.5),
		enter = B(-40, -5, -54, 40, 25, 12),
		start = P.sorting.PlayerEnter,
		areas = { A(-43, -58, 43, 18) },
		gates = { entry = { "Gate_F4_SortS" }, exit = { "Gate_F4_SortN", "Gate_F4_Ingot" } },
		waves = {
			{
				{ "forge_automaton", P.sorting.SP_s3 },
				{ "fire_spirit", P.sorting.SP_s1 },
				{ "fire_spirit", P.sorting.SP_s2 },
				{ "slag_thrower", P.sorting.SP_s4 },
				{ "slag_thrower", P.sorting.SP_s5 },
			},
			{
				{ "forge_automaton", P.sorting.SP_s8 },
				{ "smolder", P.sorting.SP_s6 },
				{ "smolder", P.sorting.SP_s7 },
				{ "fire_spirit", P.sorting.SP_s1 },
				{ "fire_spirit", P.sorting.SP_s2 },
				{ "slag_thrower", P.sorting.SP_s5 },
			},
		},
	},
	{
		id = "ingots",
		name = "Склад слитков",
		kind = "branch",
		box = B(-101, -5, -51, -45.5, 25, 11),
		enter = B(-97, -5, -47, -50, 25, 7),
		start = P.ingots.PlayerEnter,
		areas = { A(-98, -48, -47, 8) },
		gates = { entry = { "Gate_F4_Ingot" } },
		waves = {
			{ { "slag_thrower", P.ingots.SP_i1 }, { "slag_thrower", P.ingots.SP_i2 }, { "fire_spirit", P.ingots.SP_i3 }, { "smolder", P.ingots.SP_i4 } },
			{ { "forge_automaton", P.ingots.SP_i3 }, { "fire_spirit", P.ingots.SP_i1 }, { "fire_spirit", P.ingots.SP_i2 }, { "smolder", P.ingots.SP_i4 } },
		},
		chest = { at = P.ingots.ChestI, kind = "ingots" },
	},
	{
		id = "steiger",
		name = "Штейгерская",
		kind = "rest",
		box = B(-21, -5, -95, 21, 25, -60.5),
		start = P.steiger.PlayerEnter,
		campfire = P.steiger.Campfire,
	},

	-- ===== II. Вниз, к литейной =====
	{
		id = "coalslope",
		name = "Угольный склон",
		kind = "street",
		box = B(-17, -20, -214, 17, 25, -95),
		start = P.coalslope.PlayerEnter,
		areas = { A(-15, -213, 15, -96) },
		groups = {
			{ trigger = B(-16, -10, -126, 16, 25, -104), enemies = { { "smolder", P.coalslope.SP_c1 }, { "smolder", P.coalslope.SP_c2, 0.6 }, { "fire_spirit", P.coalslope.SP_c3, 1.0 } } },
			{ trigger = B(-16, -18, -166, 16, 25, -144), enemies = { { "forge_automaton", P.coalslope.SP_c6 }, { "slag_thrower", P.coalslope.SP_c4 }, { "slag_thrower", P.coalslope.SP_c5, 0.8 } } },
			{ trigger = B(-16, -20, -206, 16, 25, -186), enemies = { { "fire_spirit", P.coalslope.SP_c7 }, { "fire_spirit", P.coalslope.SP_c8, 0.5 }, { "smolder", P.coalslope.SP_c9, 1.0 } } },
		},
	},
	{
		id = "cage",
		name = "Клеть подъёмника",
		kind = "hold",
		box = B(-41, -20, -293, 41, 25, -214),
		enter = B(-36, -20, -284, 36, 6, -224),
		start = P.cage.PlayerEnter,
		areas = { A(-38, -288, 38, -217) },
		gates = { entry = { "Gate_F4_CageIn" } },
		lever = P.cage.Lever,
		hold = {
			duration = 60,
			limit = 6,
			every = 2.4,
			flows = { P.cage.FLOW_1, P.cage.FLOW_2, P.cage.FLOW_3 },
			mix = { "fire_spirit", "smolder", "slag_thrower", "fire_spirit", "forge_automaton", "smolder", "fire_spirit", "slag_thrower" },
			innerGate = "F4CageGate",
		},
	},
	{
		id = "foundry",
		name = "Литейная",
		kind = "arena",
		box = B(-56, -20, -391, 56, 34, -293),
		enter = B(-50, -20, -384, 50, 10, -303),
		start = P.foundry.PlayerEnter,
		areas = { A(-53, -388, 53, -298) },
		gates = { entry = { "Gate_F4_FoundryS" }, exit = { "Gate_F4_FoundryN", "Gate_F4_Mold" } },
		spills = { P.foundry.SPILL_1, P.foundry.SPILL_2, P.foundry.SPILL_3, P.foundry.SPILL_4, P.foundry.SPILL_5, P.foundry.SPILL_6 },
		waves = {
			{
				{ "forge_automaton", P.foundry.SP_f3 },
				{ "slag_thrower", P.foundry.SP_f4 },
				{ "slag_thrower", P.foundry.SP_f5 },
				{ "fire_spirit", P.foundry.SP_f1 },
				{ "fire_spirit", P.foundry.SP_f2 },
			},
			{
				{ "smolder", P.foundry.SP_f6 },
				{ "smolder", P.foundry.SP_f7 },
				{ "fire_spirit", P.foundry.SP_f8 },
				{ "forge_automaton", P.foundry.SP_f1 },
				{ "slag_thrower", P.foundry.SP_f5 },
			},
			{
				{ "forge_automaton", P.foundry.SP_f3 },
				{ "forge_automaton", P.foundry.SP_f8 },
				{ "slag_thrower", P.foundry.SP_f4 },
				{ "fire_spirit", P.foundry.SP_f6 },
				{ "fire_spirit", P.foundry.SP_f7 },
				{ "smolder", P.foundry.SP_f2 },
			},
		},
	},
	{
		id = "molds",
		name = "Формовочная",
		kind = "branch",
		box = B(55.5, -20, -376, 106, 25, -314),
		enter = B(60, -20, -372, 102, 10, -318),
		start = P.molds.PlayerEnter,
		areas = { A(57, -373, 103, -317) },
		gates = { entry = { "Gate_F4_Mold" } },
		waves = {
			{ { "fire_spirit", P.molds.SP_m1 }, { "fire_spirit", P.molds.SP_m2 }, { "slag_thrower", P.molds.SP_m3 }, { "smolder", P.molds.SP_m4 } },
			{ { "forge_automaton", P.molds.SP_m3 }, { "slag_thrower", P.molds.SP_m1 }, { "smolder", P.molds.SP_m2 }, { "smolder", P.molds.SP_m4 } },
		},
		chest = { at = P.molds.ChestM, kind = "molds" },
	},
	{
		id = "coldforge",
		name = "Остывший горн",
		kind = "rest",
		box = B(-21, -20, -431, 21, 25, -391),
		start = P.coldforge.PlayerEnter,
		campfire = P.coldforge.Campfire,
	},

	-- ===== III. Великий горн =====
	{
		id = "greatforge",
		name = "Великий горн",
		kind = "boss",
		box = B(-55, -20, -540, 55, 45, -431),
		enter = B(-40, -20, -526, 40, 20, -447),
		start = P.greatforge.PlayerEnter,
		areas = { C(0, -486, 47) },
		-- Решёток нет: проём из Остывшего горна запирает печать памяти.
		seals = { B(-9, -14, -431.6, 9, -1, -429.6) },
		boss = { typeId = "elder_founder", at = P.greatforge.BossSpawn },
		points = {
			summons = { P.greatforge.SUMMON_1, P.greatforge.SUMMON_2, P.greatforge.SUMMON_3, P.greatforge.SUMMON_4 },
			pours = { P.greatforge.POUR_1, P.greatforge.POUR_2, P.greatforge.POUR_3, P.greatforge.POUR_4, P.greatforge.POUR_5 },
			center = V(0, -14, -486),
			radius = 44,
		},
		chest = { at = P.greatforge.ChestBoss, kind = "boss" },
	},
}

function Floor4.byId(id: string)
	for index, zone in ipairs(Floor4.Zones) do
		if zone.id == id then
			return zone, index
		end
	end
	return nil, nil
end

function Floor4.inBox(box, position: Vector3): boolean
	return position.X >= box[1] and position.X <= box[4]
		and position.Y >= box[2] and position.Y <= box[5]
		and position.Z >= box[3] and position.Z <= box[6]
end

function Floor4.bounds(zone)
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

return Floor4
