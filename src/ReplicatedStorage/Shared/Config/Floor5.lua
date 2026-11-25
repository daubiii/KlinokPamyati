--!nonstrict
-- Floor5
-- Этаж 5 «Зал хроник» (план: цвета #1D1B3A #4A3F8F #8E7CE0 #B8E3FF; каменные
-- чтецы-танки, маги под защитными печатями, призыватели, стрелки; мини-босс;
-- босс — Главный хронист). После босса открываются ворота за куполом, за
-- ними — мост «Обрыв хроники» с надписью-отсылкой на продолжение.
-- Порядок: intro → street → arena (+branch) → rest → arena → street (лестница)
-- → keeper (мини-босс) → rest → boss → beyond (эпилог).
-- Карта — Workspace.Floor5Map, точки — Floor5Points (мировые). Ниже — ЛОКАЛЬНЫЕ.
--
-- Свои поля этажа 5 (Systems/Floor5World):
--   kind = "keeper"  зона мини-босса: печать, сцена, Переплётчик, сундук
--   bookfall         в Хранилище полок падают книги (зоны на полу)
--   epilogue         точка в конце моста: сцена «Хроника обрывается здесь»

local P = require(script.Parent.Floor5Points)

local Floor5 = {}

Floor5.FloorId = 5
Floor5.MapName = "Floor5Map"
Floor5.FolderName = "Floor5"
Floor5.RuntimeName = "Floor5Runtime"
Floor5.Offset = Vector3.new(10400, 0, 0)

-- Верхний ярус (скрипторий, купол) на +12; под мостом — пустота.
Floor5.FallLimit = -10
Floor5.FallDamagePct = 0.15

Floor5.GateTime = 0.7
Floor5.Seal = { transparency = 0.55, color = Color3.fromRGB(142, 124, 224) } -- #8E7CE0

Floor5.Chests = {
	maps = { tier = "rare", minRarity = "rare", epicChance = 0.25 },
	keeper = { tier = "rare", minRarity = "rare", epicChance = 0.4 },
	boss = { tier = "epic", final = true },
}

Floor5.Keys = {}
Floor5.KeyPickupRadius = 6

Floor5.Traps = {
	bookfall = { every = 5.5, warn = 1.0, radius = 2.8, damage = 16, count = 2 }, -- книги с полок (во время боя)
	ink = { slow = 0.65 }, -- лужа чернил: замедление на фиксированное время
	erase = { damage = 7, tick = 0.5 }, -- пятно стирания: урон за тик
}

Floor5.Epilogue = {
	radius = 7,
	title = "Хроника обрывается здесь",
	text = "Дальше страницы пусты. Кто-то ещё допишет эту историю…",
	sub = "Продолжение следует",
}

local O = Floor5.Offset
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

Floor5.Zones = {
	-- ===== I. Вход в хроники =====
	{
		id = "narthex",
		name = "Притвор",
		kind = "intro",
		box = B(-25, -5, 150.5, 25, 30, 207),
		start = P.narthex.PlayerStart,
		areas = { A(-23, 151, 23, 205) },
		groups = {
			{ trigger = B(-24, -5, 150, 24, 30, 174), enemies = { { "ink_scribe", P.narthex.SP_n1 }, { "ink_blot", P.narthex.SP_n2, 0.8 } } },
		},
	},
	{
		id = "gallery",
		name = "Галерея летописей",
		kind = "street",
		box = B(-15, -5, 30.5, 15, 25, 150.5),
		start = V(0, 0, 146),
		areas = { A(-13, 31, 13, 149.5) },
		groups = {
			{ trigger = B(-14, -5, 114, 14, 25, 136), enemies = { { "stone_reader", P.gallery.SP_g3 }, { "ink_blot", P.gallery.SP_g1, 0.5 }, { "ink_blot", P.gallery.SP_g2, 0.9 } } },
			{ trigger = B(-14, -5, 80, 14, 25, 100), enemies = { { "shelf_warden", P.gallery.SP_g4 }, { "shelf_warden", P.gallery.SP_g5, 0.6 }, { "ink_scribe", P.gallery.SP_g6, 1.0 } } },
			{ trigger = B(-14, -5, 38, 14, 25, 60), enemies = { { "seal_mage", P.gallery.SP_g9 }, { "ink_blot", P.gallery.SP_g7, 0.5 }, { "stone_reader", P.gallery.SP_g8, 1.0 } } },
		},
	},
	{
		id = "readingroom",
		name = "Читальный зал",
		kind = "arena",
		box = B(-49, -5, -62, 49, 35, 30.5),
		enter = B(-42, -5, -56, 42, 30, 22),
		start = P.readingroom.PlayerEnter,
		areas = { A(-46, -60, 46, 28) },
		gates = { entry = { "Gate_F5_ReadS" }, exit = { "Gate_F5_ReadN", "Gate_F5_Maps" } },
		waves = {
			{
				{ "stone_reader", P.readingroom.SP_r3 },
				{ "ink_scribe", P.readingroom.SP_r4 },
				{ "ink_blot", P.readingroom.SP_r1 },
				{ "ink_blot", P.readingroom.SP_r2 },
				{ "shelf_warden", P.readingroom.SP_r5 },
			},
			{
				{ "seal_mage", P.readingroom.SP_r9 },
				{ "seal_mage", P.readingroom.SP_r10 },
				{ "stone_reader", P.readingroom.SP_r8 },
				{ "shelf_warden", P.readingroom.SP_r11 },
				{ "ink_blot", P.readingroom.SP_r6 },
				{ "ink_blot", P.readingroom.SP_r7 },
			},
			{
				{ "stone_reader", P.readingroom.SP_r3 },
				{ "ink_scribe", P.readingroom.SP_r12 },
				{ "ink_scribe", P.readingroom.SP_r11 },
				{ "shelf_warden", P.readingroom.SP_r4 },
				{ "shelf_warden", P.readingroom.SP_r5 },
			},
		},
	},
	{
		id = "mapsarchive",
		name = "Архив карт",
		kind = "branch",
		box = B(-105, -5, -47, -49, 25, 15),
		enter = B(-100, -5, -43, -54, 25, 11),
		start = P.mapsarchive.PlayerEnter,
		areas = { A(-102, -44, -50, 12) },
		gates = { entry = { "Gate_F5_Maps" } },
		waves = {
			{ { "shelf_warden", P.mapsarchive.SP_m3 }, { "shelf_warden", P.mapsarchive.SP_m4 }, { "ink_blot", P.mapsarchive.SP_m1 }, { "ink_blot", P.mapsarchive.SP_m2 } },
			{ { "seal_mage", P.mapsarchive.SP_m6 }, { "stone_reader", P.mapsarchive.SP_m5 }, { "ink_scribe", P.mapsarchive.SP_m3 } },
		},
		chest = { at = P.mapsarchive.ChestMaps, kind = "maps" },
	},
	{
		id = "scribecell",
		name = "Келья писца",
		kind = "rest",
		box = B(-19, -5, -97.5, 19, 20, -62),
		start = P.scribecell.PlayerEnter,
		campfire = P.scribecell.Campfire,
	},

	-- ===== II. Хранилище и лестница =====
	{
		id = "stacks",
		name = "Хранилище полок",
		kind = "arena",
		box = B(-51, -5, -200.5, 51, 36, -97.5),
		enter = B(-44, -5, -194, 44, 30, -106),
		start = P.stacks.PlayerEnter,
		areas = { A(-48, -198, 48, -100) },
		gates = { entry = { "Gate_F5_StacksS" }, exit = { "Gate_F5_StacksN" } },
		bookfall = { A(-44, -194, 44, -106) },
		waves = {
			{
				{ "stone_reader", P.stacks.SP_s3 },
				{ "shelf_warden", P.stacks.SP_s4 },
				{ "shelf_warden", P.stacks.SP_s5 },
				{ "ink_blot", P.stacks.SP_s1 },
				{ "ink_blot", P.stacks.SP_s2 },
			},
			{
				{ "seal_mage", P.stacks.SP_s11 },
				{ "seal_mage", P.stacks.SP_s12 },
				{ "ink_scribe", P.stacks.SP_s6 },
				{ "stone_reader", P.stacks.SP_s7 },
				{ "shelf_warden", P.stacks.SP_s8 },
			},
			{
				{ "stone_reader", P.stacks.SP_s9 },
				{ "stone_reader", P.stacks.SP_s10 },
				{ "ink_scribe", P.stacks.SP_s8 },
				{ "seal_mage", P.stacks.SP_s3 },
				{ "shelf_warden", P.stacks.SP_s4 },
				{ "shelf_warden", P.stacks.SP_s5 },
			},
		},
	},
	{
		id = "stair",
		name = "Лестница летописцев",
		kind = "street",
		box = B(-15, -5, -290, 15, 34, -200.5),
		start = P.stair.PlayerEnter,
		areas = { A(-13, -289, 13, -201) },
		groups = {
			{ trigger = B(-14, -5, -232, 14, 30, -208), enemies = { { "shelf_warden", P.stair.SP_t3 }, { "ink_blot", P.stair.SP_t1, 0.4 }, { "ink_blot", P.stair.SP_t2, 0.8 } } },
			{ trigger = B(-14, 0, -262, 14, 32, -240), enemies = { { "stone_reader", P.stair.SP_t6 }, { "seal_mage", P.stair.SP_t4 }, { "shelf_warden", P.stair.SP_t5, 0.8 } } },
			{ trigger = B(-14, 6, -288, 14, 34, -270), enemies = { { "ink_scribe", P.stair.SP_t7 }, { "shelf_warden", P.stair.SP_t8, 0.6 } } },
		},
	},
	{
		id = "scriptorium",
		name = "Скрипторий",
		kind = "keeper",
		box = B(-43, 5, -373, 43, 42, -290),
		enter = B(-36, 6, -364, 36, 34, -300),
		start = P.scriptorium.PlayerEnter,
		areas = { A(-40, -370, 40, -292) },
		gates = { entry = { "Gate_F5_ScriptS" }, exit = { "Gate_F5_ScriptN" } },
		keeper = { typeId = "bookbinder", at = P.scriptorium.KeeperSpawn, intro = 3.0 },
		points = { summons = { P.scriptorium.SP_k1, P.scriptorium.SP_k2, P.scriptorium.SP_k3, P.scriptorium.SP_k4 } },
		chest = { at = P.scriptorium.ChestKeeper, kind = "keeper" },
	},
	{
		id = "antechamber",
		name = "Преддверие купола",
		kind = "rest",
		box = B(-19, 5, -412, 19, 36, -373),
		start = P.antechamber.PlayerEnter,
		campfire = P.antechamber.Campfire,
	},

	-- ===== III. Купол хроник =====
	{
		id = "dome",
		name = "Купол хроник",
		kind = "boss",
		box = B(-56, 5, -530, 56, 48, -412),
		enter = B(-40, 5, -516, 40, 36, -432),
		start = P.dome.PlayerEnter,
		areas = { C(0, -470, 49) },
		gates = { entry = { "Gate_F5_DomeS" } },
		vaultDoors = { "Vault_F5_L", "Vault_F5_R" },
		boss = { typeId = "chief_chronicler", at = P.dome.BossSpawn },
		points = {
			summons = { P.dome.SUMMON_1, P.dome.SUMMON_2, P.dome.SUMMON_3, P.dome.SUMMON_4 },
			seals = { P.dome.SEAL_1, P.dome.SEAL_2, P.dome.SEAL_3, P.dome.SEAL_4 },
			center = P.dome.BossCenter,
		},
		chest = { at = P.dome.ChestBoss, kind = "boss" },
	},
	{
		id = "beyond",
		name = "Обрыв хроники",
		kind = "street",
		box = B(-9, 5, -600, 9, 40, -530),
		start = P.beyond.PlayerEnter,
		areas = { A(-4, -590, 4, -531) },
		epilogue = P.beyond.EpilogueEnd,
	},
}

function Floor5.byId(id: string)
	for index, zone in ipairs(Floor5.Zones) do
		if zone.id == id then
			return zone, index
		end
	end
	return nil, nil
end

function Floor5.inBox(box, position: Vector3): boolean
	return position.X >= box[1] and position.X <= box[4]
		and position.Y >= box[2] and position.Y <= box[5]
		and position.Z >= box[3] and position.Z <= box[6]
end

function Floor5.bounds(zone)
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

return Floor5
