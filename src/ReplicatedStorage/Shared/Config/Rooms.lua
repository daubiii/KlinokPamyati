--!nonstrict
-- Rooms
-- Этаж 1 целиком по приложению Е нового плана: комнаты, волны, точки
-- появления, особенности. Координаты — в стадах от центра комнаты (0,0),
-- как в документе: вход (0,−25), выход (0,25), игрок появляется в (0,−20).
--
-- Локальная ось Y идёт ОТ входа К выходу, то есть мир = (x, centerZ − y):
-- проходим этаж в сторону −Z, вход каждой комнаты на её +Z краю, выход —
-- на −Z. Преобразование в мир — в Shared/Floor/FloorLayout.

local Rooms = {}

-- Размеры увеличены относительно приложения Е (50/30/80) по решению владельца
-- проекта: в тесных комнатах негде уклоняться и камера упирается в стены.
-- Точки появления и колонны остаются в координатах приложения Е — они ближе
-- к центру, а по краям остаётся простор для рывков.
Rooms.Size = {
	courtyard = 72,
	combat = 64,
	rest = 40,
	boss = 96,
}

-- Закрытые коридоры между комнатами: этаж ощущается длиннее, а следующая
-- комната не видна, пока не откроется дверь.
Rooms.Corridor = {
	length = 28,
	width = 14, -- внутренняя ширина (проём двери 12 + по стаду до стен)
	height = 13,
}

-- Двери деревянные, раздвижные: открываются, когда игрок подходит ближе
-- этого расстояния, и заперты, пока в комнате идёт бой.
Rooms.DoorOpenDistance = 11

-- Высокие стены: за край не выпасть, а над кромкой видно закатное небо.
Rooms.WallHeight = 24
Rooms.Doorway = { width = 12, height = 15 }
-- Невидимый барьер над стенами: рывок и физика не выкинут игрока наружу.
Rooms.BarrierHeight = 80
-- Ниже этой высоты игрок считается выпавшим и возвращается на старт комнаты.
Rooms.FallLimit = -25
-- Шаг плитки пола и кладки стен (1 воксель архитектуры = 1 стад, плитка 4×4).
Rooms.Tile = 4
Rooms.DoorTweenTime = 0.45
-- Комната считается «занятой», когда игрок зашёл на столько стадов за дверь:
-- иначе дверь закрылась бы прямо на нём в проёме.
Rooms.EntryDepth = 4

-- Точки появления врагов (приложение Е).
Rooms.Points = {
	A = Vector2.new(-15, 10),
	B = Vector2.new(15, 10),
	C = Vector2.new(-15, -5),
	D = Vector2.new(15, -5),
	E = Vector2.new(0, 18),
	F = Vector2.new(0, 5),
}

-- Колонны 3×3 стада: четыре по углам, блокируют снаряды.
Rooms.Pillars = {
	Vector2.new(-12, -12),
	Vector2.new(12, -12),
	Vector2.new(-12, 12),
	Vector2.new(12, 12),
}
Rooms.PillarSize = 3

-- Старт игрока — в стольких стадах от входной стены комнаты.
Rooms.StartBack = 8

-- Шипы в Цепном зале: цикл 2 с активны, 2 с убраны, предупреждение 0,8 с.
Rooms.Spikes = {
	cycleActive = 2.0,
	cycleIdle = 2.0,
	warning = 0.8,
	damage = 20,
	radius = 3,
	tick = 1.0, -- пока стоишь на выехавших шипах: повторный урон раз в секунду
	-- Четыре плиты шипов (локальные координаты комнаты).
	points = {
		Vector2.new(-10, 5),
		Vector2.new(10, 5),
		Vector2.new(-10, -10),
		Vector2.new(10, -10),
	},
}

-- Костёр в комнате отдыха: 3 с взаимодействия, пополняет заряды лечения.
Rooms.Campfire = {
	interact = 3.0,
	distance = 6,
}

-- Босс: появляется в (0,25), игрок входит в (0,−35), сундук после победы в (0,0).
Rooms.Boss = {
	spawn = Vector2.new(0, 28),
	playerStart = Vector2.new(0, -38),
	-- Арена круглая (концепт «Арена с боссом»): враги не выходят за круг.
	radius = 46,
	chest = Vector2.new(0, 0),
	chestDelay = 1.0,
}

-- Комнаты этажа 1 по порядку (приложение Е).
-- waves — список волн; в волне записи { typeId, point }.
Rooms.Floor1 = {
	{
		-- Комната 0: двор пустынной крепости перед главными воротами башни.
		-- Боя нет: игрок собирается с мыслями, ворота открываются при подходе.
		id = 0,
		kind = "courtyard",
		name = "Двор крепости",
	},
	{
		id = 1,
		kind = "combat",
		name = "Двор стражи",
		waves = {
			{ { typeId = "guard", point = "A" }, { typeId = "guard", point = "B" }, { typeId = "guard", point = "E" } },
		},
		pillars = false,
	},
	{
		id = 2,
		kind = "combat",
		name = "Тёмный проход",
		waves = {
			{
				{ typeId = "guard", point = "A" },
				{ typeId = "guard", point = "B" },
				{ typeId = "shade", point = "C" },
				{ typeId = "shade", point = "D" },
			},
		},
		pillars = false,
	},
	{
		id = 3,
		kind = "combat",
		name = "Оружейная",
		waves = {
			{
				{ typeId = "knight", point = "F" },
				{ typeId = "archer", point = "E" },
				{ typeId = "martyr", point = "C" },
				{ typeId = "guard", point = "A" },
			},
		},
		pillars = true,
	},
	{
		id = 4,
		kind = "rest",
		name = "Отдых. Костёр",
	},
	{
		id = 5,
		kind = "combat",
		name = "Цепной зал",
		waves = {
			{
				{ typeId = "knight", point = "F" },
				{ typeId = "archer", point = "A" },
				{ typeId = "archer", point = "B" },
				{ typeId = "shade", point = "D" },
			},
		},
		pillars = true,
		spikes = true,
	},
	{
		id = 6,
		kind = "combat",
		name = "Последние ворота",
		waves = {
			{
				{ typeId = "knight", point = "F" },
				{ typeId = "guard", point = "A" },
				{ typeId = "guard", point = "B" },
				{ typeId = "archer", point = "E" },
			},
			{
				{ typeId = "shade", point = "C" },
				{ typeId = "shade", point = "D" },
				{ typeId = "martyr", point = "F" },
			},
		},
		pillars = true,
		crumble = true,
	},
	{
		id = 7,
		kind = "boss",
		name = "Ворота Хранилища",
		bossTypeId = "gatekeeper",
	},
}

function Rooms.floor1()
	return Rooms.Floor1
end

return Rooms
