--!nonstrict
-- Floor1v2
-- Этаж 1 «Привратный двор» v2: 16 зон по концепту floor1-v2-concept.md.
-- Карта стоит в Workspace.Floor1Map (меши + коллизии, собирается один раз
-- в Studio), точки — в Floor1Points (генерирует bake.py вместе с картой).
-- Все координаты — мировые, север = −Z.
--
-- Виды зон:
--   intro    обучение, без замков; groups — засады по триггерам
--   arena    запираемая арена: волны, ворота (gates) и печати (seals)
--   street   улица/мост/стена: засады по триггерам, ничего не запирается
--   branch   ответвление: как арена, после зачистки — сундук
--   miniboss мини-босс (MiniBossService), ключ, сундук
--   hold     удержание: поток врагов, таймер, решётка поднимается
--   rest     костёр
--   boss     Привратник + сцена ключей
--
-- box = { x0, y0, z0, x1, y1, z1 }, areas — области ходьбы врагов
-- ({ x0, z0, x1, z1 } или { cx, cz, r }), enemies = { { тип, точка } }.

local P = require(script.Parent.Floor1Points)

local Floor1v2 = {}

Floor1v2.FloorId = 1
Floor1v2.MapName = "Floor1Map"
Floor1v2.FolderName = "Floor"

-- Ниже этой высоты игрок упал (ров, край): возврат на чекпоинт зоны.
Floor1v2.FallLimit = -12
Floor1v2.FallDamagePct = 0.25 -- концепт: падение с моста — 25% здоровья

-- Ворота-решётки: время подъёма/опускания, высота подъёма = высота решётки.
Floor1v2.GateTime = 0.7

-- Печать памяти (проём без решётки): полупрозрачная янтарная стена.
Floor1v2.Seal = { transparency = 0.55, color = Color3.fromRGB(201, 139, 74) }

-- Сундуки: tier — вид (FloorBuilder.ChestTiers), минимальная редкость и шанс
-- редкости выше (доп.: таблицы лута этажа — следующим пакетом, пока rollChest).
Floor1v2.Chests = {
	branch = { tier = "rare", minRarity = "rare" },
	forge = { tier = "rare", minRarity = "rare", epicChance = 0.25 },
	miniboss1 = { tier = "rare", minRarity = "rare", epicChance = 0.25 },
	miniboss2 = { tier = "rare", minRarity = "rare", epicChance = 0.35 },
	boss = { tier = "epic", final = true },
}

-- Ключи: атрибуты игрока, ячейки на HUD.
Floor1v2.Keys = {
	{ id = "KeyCaptain", name = "Ключ Сотника", from = "barbican" },
	{ id = "KeyTower", name = "Ключ Башни", from = "tower" },
}
Floor1v2.KeyPickupRadius = 6
Floor1v2.KeyScene = 3.0 -- вставка ключей в замки ворот Хранилища, с

Floor1v2.Zones = {
	-- ===== I. Внешний двор =====
	{
		id = "intro",
		name = "Порог",
		kind = "intro",
		box = { -16, -5, 95, 16, 25, 137 },
		start = P.intro.PlayerStart,
		areas = { { -14, 97, 14, 133 } },
		groups = {
			{ trigger = { -15, -5, 96, 15, 25, 114 }, enemies = { { "guard", P.intro.Duelist } } },
		},
	},
	{
		id = "yard",
		name = "Двор стражи",
		kind = "arena",
		box = { -31, -5, 34, 31, 25, 92 },
		enter = { -27, -5, 38, 27, 25, 80 },
		start = Vector3.new(0, 0, 88),
		areas = { { -28, 37, 28, 83 } },
		gates = { exit = { "Gate_YardN" } },
		seals = { { -8.6, 0, 85.2, 8.6, 10, 86.9 } },
		waves = {
			{ { "guard", Vector3.new(-15, 0, 50) }, { "guard", Vector3.new(15, 0, 50) }, { "guard", Vector3.new(0, 0, 42) } },
			{
				{ "guard", Vector3.new(-15, 0, 68) },
				{ "guard", Vector3.new(15, 0, 68) },
				{ "shade", Vector3.new(-20, 0, 44) },
				{ "shade", Vector3.new(20, 0, 44) },
			},
		},
	},
	{
		id = "street",
		name = "Казарменная улица",
		kind = "street",
		box = { -105, -5, 12.5, 12, 25, 31.5 },
		start = Vector3.new(0, 0, 28),
		areas = { { -103, 13.5, 10, 30.5 } },
		groups = {
			{
				trigger = { -14, -5, 13, 2, 25, 31 },
				enemies = { { "shade", P.street.SP_doorA }, { "shade", P.street.SP_doorA + Vector3.new(-2, 0, 1) }, { "archer", P.street.ARCH_N1 } },
			},
			{
				trigger = { -50, -5, 13, -34, 25, 31 },
				enemies = { { "guard", P.street.SP_mid }, { "shade", P.street.SP_doorD }, { "archer", P.street.ARCH_S3 } },
			},
			{
				trigger = { -86, -5, 13, -70, 25, 31 },
				enemies = { { "martyr", P.street.SP_doorF }, { "martyr", P.street.SP_doorS2 }, { "archer", P.street.ARCH_N5 } },
			},
		},
	},
	{
		id = "warehouse",
		name = "Склад",
		kind = "branch",
		box = { -69, -5, -25, -39, 25, 13 },
		enter = { -67, -5, -23, -41, 25, -2 },
		start = Vector3.new(-54, 0, 10),
		areas = { { -67, -23, -41, 1 }, { -57, 1, -51, 12 } },
		gates = { entry = { "Gate_Warehouse" } },
		waves = {
			{
				{ "martyr", P.warehouse.SP_wa1 },
				{ "martyr", P.warehouse.SP_wa2 },
				{ "martyr", P.warehouse.SP_wa3 },
				{ "martyr", P.warehouse.SP_wa4 },
				{ "guard", P.warehouse.SP_wa5 },
				{ "guard", P.warehouse.SP_wa6 },
			},
		},
		chest = { at = P.warehouse.ChestA, kind = "branch" },
	},
	{
		id = "plaza",
		name = "Плац",
		kind = "arena",
		box = { -155, -5, -47, -93, 25, 14 },
		enter = { -140, -5, -42, -96, 25, 6 },
		start = P.plaza.PlayerEnter,
		areas = {
			{ -141, -44, -95, 12 }, -- нижний двор
			{ -154, -44, -143, 12 }, -- галерея +5
			{ -142, -20, -136, -6 },
			{ -142, -42, -136, -28 }, -- пандусы
		},
		gates = { entry = { "Gate_PlazaS" }, exit = { "Gate_PlazaN" } },
		waves = {
			{
				{ "guard", P.plaza.SP_p1 },
				{ "guard", P.plaza.SP_p2 },
				{ "guard", P.plaza.SP_p3 },
				{ "archer", P.plaza.ARCH_G1 },
				{ "archer", P.plaza.ARCH_G2 },
			},
			{ { "knight", P.plaza.SP_p3 }, { "shade", P.plaza.SP_p1 }, { "shade", P.plaza.SP_p2 }, { "martyr", P.plaza.SP_p4 } },
		},
	},
	{
		id = "barbican",
		name = "Барбакан",
		kind = "miniboss",
		box = { -157, -5, -127, -83, 30, -47 },
		enter = { -142, -5, -110, -98, 25, -66 },
		start = P.barbican.PlayerEnter,
		areas = { { cx = -120, cz = -90, r = 32 } },
		gates = { entry = { "Gate_BarbS" }, exit = { "Gate_BarbN" } },
		boss = { typeId = "centurion", at = P.barbican.BossSpawn },
		points = {
			banner = P.barbican.BannerSocket,
			squads = { P.barbican.SQUAD_1, P.barbican.SQUAD_2, P.barbican.SQUAD_3, P.barbican.SQUAD_4 },
			key = P.barbican.KeyDrop,
		},
		key = "KeyCaptain",
		chest = { at = P.barbican.ChestM1, kind = "miniboss1" },
	},
	{
		id = "rest1",
		name = "Надвратная башня",
		kind = "rest",
		box = { -135, -5, -155, -105, 25, -127 },
		start = P.rest1.PlayerEnter,
		campfire = P.rest1.Campfire,
	},

	-- ===== II. Ров и стены =====
	{
		id = "bridge",
		name = "Подъёмный мост",
		kind = "street",
		box = { -106, -60, -160, -28, 25, -120 },
		start = P.bridge.BridgeStart,
		areas = {
			{ -105, -145.8, -27, -134.2 },
			{ -78, -158, -70, -150 },
			{ -58, -130, -50, -122 },
			{ -77, -150, -71, -146 },
			{ -57, -134, -51, -130 },
		},
		breakable = "Bridge", -- доски Dynamic/Bridge_*: взрыв Треснувшего пробивает дыру
		groups = {
			{
				trigger = { -104, -5, -146, -96, 25, -134 },
				enemies = {
					{ "archer", P.bridge.ARCH_BN },
					{ "archer", P.bridge.ARCH_BS },
					{ "martyr", P.bridge.SP_m1, 1.5 }, -- третье число — задержка появления, с
					{ "martyr", P.bridge.SP_m2, 3.0 },
					{ "martyr", P.bridge.SP_m3, 4.5 },
				},
			},
			{
				trigger = { -62, -5, -146, -56, 25, -134 },
				enemies = { { "shade", P.bridge.SP_m1 }, { "shade", P.bridge.SP_m2 } },
			},
		},
	},
	{
		id = "armory",
		name = "Оружейная",
		kind = "arena",
		box = { -29, -5, -167, 29, 25, -113 },
		enter = { -22, -5, -160, 22, 25, -120 },
		start = P.armory.PlayerEnter,
		areas = { { -26, -164, 26, -116 } },
		gates = { entry = { "Gate_ArmoryW" }, exit = { "Gate_ArmoryN", "Gate_ArmoryE" } },
		waves = {
			{ { "knight", P.armory.SP_a5 }, { "archer", P.armory.SP_a3 }, { "archer", P.armory.SP_a4 }, { "guard", P.armory.SP_a1 } },
			{
				{ "guard", P.armory.SP_a2 },
				{ "guard", P.armory.SP_a6 },
				{ "shade", P.armory.SP_a1 },
				{ "shade", P.armory.SP_a7 },
				{ "martyr", P.armory.SP_a3 },
			},
		},
	},
	{
		id = "forge",
		name = "Кузня оружейника",
		kind = "branch",
		box = { 29, -5, -154, 68, 25, -126 },
		enter = { 43, -5, -151, 66, 25, -129 },
		start = Vector3.new(32, 0, -140),
		areas = { { 43, -151, 60, -129 }, { 29, -143, 43, -137 } },
		gates = { entry = { "Gate_Forge" } },
		waves = {
			{ { "guard_elite", P.forge.SP_f2 }, { "shade", P.forge.SP_f1 }, { "shade", P.forge.SP_f3 } },
		},
		chest = { at = P.forge.ChestB, kind = "forge" },
	},
	{
		id = "gallery",
		name = "Галерея на стене",
		kind = "street",
		box = { -7, -5, -258, 7, 30, -165 },
		start = Vector3.new(0, 0, -168),
		areas = { { -3.4, -252, 3.4, -177 } },
		groups = {
			{
				trigger = { -4, 6, -190, 4, 16, -180 },
				enemies = { { "guard", P.gallery.SP_g1 }, { "guard", P.gallery.SP_g1 + Vector3.new(0, 0, -3) } },
			},
			{ trigger = { -4, 6, -210, 4, 16, -200 }, enemies = { { "shade", P.gallery.SP_g2 }, { "shade", P.gallery.SP_g2 + Vector3.new(0, 0, -3) } } },
			{ trigger = { -4, 6, -230, 4, 16, -220 }, enemies = { { "guard", P.gallery.SP_g3 }, { "archer", P.gallery.ARCH_g } } },
		},
	},

	-- ===== III. Подступ =====
	{
		id = "tower",
		name = "Северная башня",
		kind = "miniboss",
		box = { -31, -5, -321, 31, 45, -258 },
		enter = { -27, -5, -312, 27, 30, -264 },
		start = P.tower.PlayerEnter,
		areas = { { cx = 0, cz = -290, r = 29 } },
		gates = { exit = { "Gate_TowerExit" }, phase = { "Gate_RampTop" } },
		boss = { typeId = "arbalest", at = P.tower.ArbalestSpot },
		points = {
			edge = P.tower.ArbalestEdge,
			center = Vector3.new(0, 18, -290),
			top = 18,
			topRadius = 11,
			traps = { P.tower.TRAP_1, P.tower.TRAP_2, P.tower.TRAP_3, P.tower.TRAP_4 },
			barricades = {
				P.tower.BARRICADE_1,
				P.tower.BARRICADE_2,
				P.tower.BARRICADE_3,
				P.tower.BARRICADE_4,
				P.tower.BARRICADE_5,
				P.tower.BARRICADE_6,
			},
			key = P.tower.ArbalestEdge,
		},
		cover = { { "shade", P.tower.SP_t1 }, { "shade", P.tower.SP_t2 }, { "archer", P.tower.SP_t3 } },
		key = "KeyTower",
		chest = { at = P.tower.ChestM2, kind = "miniboss2" },
	},
	{
		id = "hall",
		name = "Зал лебёдки",
		kind = "hold",
		box = { 46, -5, -317, 100, 34, -263 },
		enter = { 50, -5, -312, 96, 6, -268 },
		start = P.hall.BridgeIn,
		areas = { { 49, -314, 97, -266 } },
		gates = { entry = { "Gate_HallIn" } },
		hold = {
			duration = 60,
			limit = 6, -- врагов на поле одновременно
			every = 2.5, -- проверка «есть ли место», с
			flows = { P.hall.FLOW_N, P.hall.FLOW_S },
			mix = { "guard", "shade", "guard", "martyr", "shade", "archer", "guard", "knight" },
			innerGate = "InnerGate",
			spikes = { P.hall.SPIKE_1, P.hall.SPIKE_2, P.hall.SPIKE_3, P.hall.SPIKE_4 },
		},
	},
	{
		id = "chapel",
		name = "Часовня",
		kind = "rest",
		box = { 98, -5, -306, 135, 25, -273 },
		start = P.chapel.PlayerEnter,
		campfire = P.chapel.Campfire,
	},
	{
		id = "lastgates",
		name = "Последние ворота",
		kind = "arena",
		box = { 88, -5, -367, 148, 25, -305 },
		enter = { 93, -5, -360, 143, 25, -314 },
		start = P.lastgates.PlayerEnter,
		areas = { { 91, -364, 145, -311 } },
		gates = { entry = { "Gate_LastS" }, exit = { "Gate_LastN" } },
		waves = {
			{
				{ "knight_elite", P.lastgates.SP_l3 },
				{ "guard", P.lastgates.SP_l1 },
				{ "guard", P.lastgates.SP_l2 },
				{ "archer", P.lastgates.SP_l6 },
			},
			{
				{ "shade", P.lastgates.SP_l4 },
				{ "shade", P.lastgates.SP_l5 },
				{ "martyr", P.lastgates.SP_l1 },
				{ "martyr", P.lastgates.SP_l2 },
			},
		},
	},
	{
		id = "boss",
		name = "Ворота Хранилища",
		kind = "boss",
		box = { 70, -5, -468, 166, 40, -366 },
		enter = { 96, -5, -444, 140, 30, -384 },
		start = P.boss.PlayerEnter,
		areas = { { cx = 118, cz = -420, r = 43 } },
		gates = { entry = { "Gate_BossS" } },
		boss = { typeId = "gatekeeper", at = P.boss.BossSpawn },
		points = {
			summons = { Vector3.new(106, 0, -410), Vector3.new(130, 0, -410) },
			lockL = P.boss.KeyLockL,
			lockR = P.boss.KeyLockR,
			scene = P.boss.KeyScene,
		},
		vaultDoors = { "VaultDoorL", "VaultDoorR" },
		chest = { at = P.boss.ChestBoss, kind = "boss" },
	},
}

function Floor1v2.byId(id: string)
	for index, zone in ipairs(Floor1v2.Zones) do
		if zone.id == id then
			return zone, index
		end
	end
	return nil, nil
end

-- Точка внутри коробки { x0, y0, z0, x1, y1, z1 }.
function Floor1v2.inBox(box, position: Vector3): boolean
	return position.X >= box[1] and position.X <= box[4]
		and position.Y >= box[2] and position.Y <= box[5]
		and position.Z >= box[3] and position.Z <= box[6]
end

-- Области ходьбы врагов в формате FloorLayout.clampToBounds.
function Floor1v2.bounds(zone)
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

return Floor1v2
