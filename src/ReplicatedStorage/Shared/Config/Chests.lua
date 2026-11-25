--!nonstrict
-- Chests — сундуки этажей v3 (04.11.2026).
-- Сундук больше не открывается на этаже: после зачистки комнаты (секретная
-- комната, ответвление, мини-босс) или босса он сам прилетает герою в сумку,
-- а открывается в долине — сценой «Клинок читает память» (ChestRevealController).
--
-- Два вида на каждом этаже:
--   common — обычный сундук (секретные комнаты, ответвления, мини-боссы);
--   gold   — золотой сундук босса этажа (Config.Chests[kind].final == true).
-- Содержимое прежнее (LootService.rollContents): золотой = «сундук босса»
-- (броня всегда, больше припасов, аксессуар чаще).
--
-- Дизайн моделей — Config/ChestDesigns (генерирует tools/chests/build_chest_art.py),
-- картинки для интерфейса — Config/ChestArt + Config/ChestAtlas.

local Chests = {}

Chests.Grades = {
	common = { id = "common", name = "Сундук", isBoss = false },
	gold = { id = "gold", name = "Золотой сундук", isBoss = true },
}
Chests.GradeOrder = { "gold", "common" }

-- Хранилище: profile.chests[ключ] = число; ключ = "f<этаж>_<вид>".
Chests.MaxPerStack = 999

-- Итог этажа ждёт, пока сундук босса долетит до героя (секунды после выдачи).
Chests.SummaryDelay = 3.6

-- Полёт сундука к герою (клиент, ChestFlyController).
Chests.Fly = {
	appear = 0.55, -- проявление из квадратов памяти
	hover = 0.55, -- парит и разворачивается
	flyMin = 0.75, -- полёт к герою (зависит от расстояния)
	flyMax = 1.35,
	startHeight = 3.2,
}

-- Этажи: название, босс, цвета (под Palette.Floors) и два сундука.
-- text — описание в сумке, whisper — строка «чтения памяти» в сцене раскрытия.
Chests.Floors = {
	[1] = {
		name = "Привратный двор",
		boss = "Привратник",
		bossDefeated = "Привратник повержен",
		colors = { "#3A2E2A", "#7A5C48", "#C98B4A", "#D9D2C5" },
		whisper = "звон ключей и шаги караула",
		common = {
			name = "Сундук стражи",
			text = "Дубовый короб караульни, окованный ржавым железом. Стража хранила в нём жалованье — и то, что не успела забыть.",
		},
		gold = {
			name = "Золотой сундук Привратника",
			text = "Ларец под гербом ворот с решёткой-печатью. Привратник запер в нём последнюю смену караула.",
		},
	},
	[2] = {
		name = "Затопленные сады",
		boss = "Садовница",
		bossDefeated = "Садовница повержена",
		colors = { "#1F3A33", "#3F7A5C", "#9CC48A", "#5FD0C0" },
		whisper = "шорох листвы под тёплым дождём",
		common = {
			name = "Замшелый сундук",
			text = "Садовый ларь, проросший мхом и лозой. Внутри пахнет дождём тех дней, когда сады ещё цвели.",
		},
		gold = {
			name = "Золотой сундук Садовницы",
			text = "Ларец, оплетённый золотыми розами. Садовница поливала его слезами — память в нём не сгнила.",
		},
	},
	[3] = {
		name = "Псарни охоты",
		boss = "Королевский ловчий",
		bossDefeated = "Королевский ловчий повержен",
		colors = { "#3B1E1E", "#8C3B2E", "#D9A441", "#E8DCC0" },
		whisper = "лай своры и далёкий зов рога",
		common = {
			name = "Охотничий сундук",
			text = "Кожаный короб псарей, стянутый ремнями и подбитый мехом. Хранит запах шерсти и звук далёкого рога.",
		},
		gold = {
			name = "Золотой сундук Ловчего",
			text = "Трофейный ларь с рогами и золотой гончей на крышке. Добыча королевской охоты.",
		},
	},
	[4] = {
		name = "Литейные",
		boss = "Старший литейщик",
		bossDefeated = "Старший литейщик повержен",
		colors = { "#1E1B1F", "#4A4350", "#E2672B", "#FFC857" },
		whisper = "жар горна и удар молота по заготовке",
		common = {
			name = "Литейный сундук",
			text = "Чугунный ящик на заклёпках, швы ещё тлеют. В нём остывали заготовки для клинков.",
		},
		gold = {
			name = "Золотой сундук Литейщика",
			text = "Кованый ларец с наковальней на крышке. Старший литейщик держал в нём лучшее эхо.",
		},
	},
	[5] = {
		name = "Зал хроник",
		boss = "Главный хронист",
		bossDefeated = "Главный хронист повержен",
		colors = { "#1D1B3A", "#4A3F8F", "#8E7CE0", "#B8E3FF" },
		whisper = "шелест страниц и скрип пера",
		common = {
			name = "Сундук-фолиант",
			text = "Огромная книга с застёжками, которая на деле — сундук. Между страниц — чужие воспоминания.",
		},
		gold = {
			name = "Золотой сундук Хрониста",
			text = "Фолиант в золотом окладе с недремлющим оком. Хронист вписывал сюда то, что нельзя забыть.",
		},
	},
}

Chests.FloorCount = #Chests.Floors

-- ===== чистые функции (общие для сервера, клиента и тестов) =====

-- Вид сундука по записи Config.Chests этажа: финальный (босс) — золотой.
function Chests.gradeOf(kindCfg): string
	return (type(kindCfg) == "table" and kindCfg.final == true) and "gold" or "common"
end

function Chests.clampFloor(floorId): number
	local n = math.floor(tonumber(floorId) or 1)
	return math.clamp(n, 1, Chests.FloorCount)
end

function Chests.key(floorId, grade: string): string
	return ("f%d_%s"):format(Chests.clampFloor(floorId), grade == "gold" and "gold" or "common")
end

-- "f3_gold" → 3, "gold" (или nil, если ключ чужой).
function Chests.parse(key)
	if type(key) ~= "string" then
		return nil
	end
	local floorText, grade = key:match("^f(%d+)_(%a+)$")
	local floorId = tonumber(floorText)
	if not floorId or not Chests.Floors[floorId] or not Chests.Grades[grade] then
		return nil
	end
	return floorId, grade
end

function Chests.info(floorId, grade: string)
	local floor = Chests.Floors[Chests.clampFloor(floorId)]
	local entry = floor[grade == "gold" and "gold" or "common"]
	return {
		key = Chests.key(floorId, grade),
		floor = Chests.clampFloor(floorId),
		grade = grade == "gold" and "gold" or "common",
		name = entry.name,
		text = entry.text,
		floorName = floor.name,
		boss = floor.boss,
		whisper = floor.whisper,
		colors = floor.colors,
		isBoss = grade == "gold",
	}
end

-- Стопки для сумки: золотые выше обычных, новые этажи выше старых.
function Chests.stacks(store)
	local list = {}
	for key, count in pairs(type(store) == "table" and store or {}) do
		local floorId, grade = Chests.parse(key)
		if floorId and type(count) == "number" and count > 0 then
			local info = Chests.info(floorId, grade)
			info.count = math.floor(count)
			table.insert(list, info)
		end
	end
	table.sort(list, function(a, b)
		if a.grade ~= b.grade then
			return a.grade == "gold"
		end
		return a.floor > b.floor
	end)
	return list
end

function Chests.total(store): number
	local n = 0
	for key, count in pairs(type(store) == "table" and store or {}) do
		if Chests.parse(key) and type(count) == "number" and count > 0 then
			n += math.floor(count)
		end
	end
	return n
end

-- Добавить в хранилище (возвращает новое число в стопке).
function Chests.add(store, floorId, grade: string, count: number?): number
	local key = Chests.key(floorId, grade)
	store[key] = math.clamp((store[key] or 0) + (count or 1), 0, Chests.MaxPerStack)
	return store[key]
end

-- Забрать один (false — стопка пуста).
function Chests.take(store, key): boolean
	if not Chests.parse(key) or (store[key] or 0) < 1 then
		return false
	end
	store[key] -= 1
	if store[key] <= 0 then
		store[key] = nil
	end
	return true
end

return Chests
