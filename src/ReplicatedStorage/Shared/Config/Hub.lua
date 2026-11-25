--!nonstrict
-- Hub
-- Конфигурация хаба «Долина Последнего Эха» (ТЗ хаба, `hub-valley.md`).
-- Всё, что можно подкрутить числом, лежит здесь; точки и свет — в HubLayout,
-- жители — в HubVillagers, реплики — в HubDialogue, задания — в Quests.
--
-- Концепция. Игрок — Пробуждённый: он собирается из кубиков памяти в
-- Сердце Горы (пещера), откуда сто лет никто не выходил, и выходит в живую
-- солнечную долину. Справа деревня Колокольный Брод с жителями и станциями,
-- слева Перевал Печатей с Вратами на этажи. Этажи — «Пять Миров за
-- Снежным хребтом», их держат Пять Печатей.

local Palette = require(script.Parent.Palette)

local Hub = {}

Hub.Name = "Долина Последнего Эха"
Hub.Tagline = "Последний край, который мир ещё помнит"
Hub.NetFolder = "KlinokHubNet"
Hub.FolderName = "Hub" -- Workspace.Hub (вставлена из Hub.rbxmx)

Hub.InteractDistance = 9 -- в стадах, по горизонтали
Hub.TalkWindow = true -- разговор с жителем в окне DialogueWindow (false — строка внизу экрана)
Hub.ServerInteractSlack = 6 -- запас серверной проверки на пинг
Hub.VillagerPenalty = 3 -- житель «дальше» на столько стад, когда рядом станция
Hub.FallY = -40 -- ниже этой высоты игрок в долине возвращается к Вратам
Hub.ForceFieldSeconds = 2.5 -- защитное поле на время «сборки»
Hub.LakeBedDepth = 0.6 -- невидимое дно озера: настолько ниже берега (бродить по мелководью)

-- Подписи при появлении: где проснулся, куда вернулся.
Hub.Banners = {
	cave = { title = "Сердце Горы", sub = "Отсюда сто лет никто не выходил" },
	valley = { title = Hub.Name, sub = Hub.Tagline },
	gate = { title = "Перевал Печатей", sub = "Печати держат. Пока держат" },
}

-- Пробуждение (клиентский эффект). Параметры визуала, не баланса.
Hub.Awaken = {
	cubes = 36,
	cubeSize = 0.5,
	duration = 0.9,
	ringTime = 0.45,
	maxViewDistance = 160,
	coverFade = 0.7,
}

-- У пруда в пещере: отражение старика с молотом (ТЗ, раздел 3, доп.).
Hub.PondEcho = {
	distance = 3, -- от кромки воды
	duration = 1,
	cooldown = 25,
}

-- Звуки. Пустые id контроллер пропускает.
Hub.Audio = {
	ambient = "",
	awaken = "",
	portalOpen = "",
	interact = "",
	bell = "", -- колокол Звонницы
	pondChime = "",
}
Hub.BellInterval = 600 -- раз в 10 минут реального времени (доп.)

Hub.Difficulties = {
	{ id = "normal", name = "Обычный" },
	{ id = "hard", name = "Ненормальный" },
	{ id = "impossible", name = "Невозможный" },
}

-- Какие этажи реально собраны в проекте сейчас (вертикальный срез: этаж 1).
-- Остальные видны в окне Врат, но помечены «скоро».
Hub.BuiltFloors = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true } -- этажи 2–5 собраны

-- ДОПУЩЕНИЕ (в плане не расписано, поменять одной строкой): сложность
-- открывается последовательно — «ненормальный» после «обычного», «невозможный»
-- после «ненормального». Следующий этаж — после «ненормального» предыдущего
-- (это прямо сказано в плане, раздел 3 и приложение Д).
Hub.FloorUnlockDifficulty = "hard"
Hub.SequentialDifficulties = true

-- Станции. point — ключ HubLayout.Points (координаты сборки, мир даёт
-- HubLayout.world). kind: "dialog" — реплики и «скоро»; "portal" — окно
-- Врат; "quests" — доска заданий; "archive" — фрагменты Архива.
-- status: "stub" = системы ещё нет; "live" = работает.
-- Когда появится система (заточка, магазин...), её подключает хук
-- HubService.registerStation(id, handler).
-- window — окно-сцена UI v2 (StationController.Stations): станция с ним
-- открывает новое окно вместо прежней панели.
local forgeLines = {
	"Здесь эхо плавят в клинки. Раньше — по одному в год. Теперь — сколько принесёшь.",
	"Заточка и крафт откроются, когда появятся материалы и золото.",
}

Hub.Stations = {
	forge = {
		name = "Горнило",
		verb = "Кузня Эха: вплавить эхо",
		point = "CaveForge",
		kind = "dialog",
		status = "live",
		window = "Forge",
		title = "Горнило Кузни Эха",
		lines = forgeLines,
		soon = "Скоро: заточка оружия за золото и крафт аксессуаров.",
	},
	brazier = {
		name = "Жаровня эха",
		verb = "Жаровня эха: вплавить эхо",
		point = "VillageForge",
		kind = "dialog",
		status = "live",
		window = "Forge",
		title = "Жаровня эха",
		lines = {
			"Добрыня держит у горна угли из Кузни Эха. Тот же жар, тот же звон — бегать в гору не нужно.",
			forgeLines[2],
		},
		soon = "Скоро: заточка оружия за золото и крафт аксессуаров.",
	},
	portal = {
		name = "Врата Печатей",
		verb = "Врата Печатей: выбрать мир",
		point = "Portal",
		kind = "portal",
		status = "live",
		window = "Gate",
		title = "Врата Печатей",
	},
	shop = {
		name = "Лавка Осколков",
		verb = "Лавка Осколков",
		point = "Shop",
		kind = "dialog",
		status = "stub",
		window = "Shop",
		title = "Лавка Осколков",
		lines = {
			"Скины клинков и цвет поглощения душ. Сила здесь не продаётся, только вид.",
		},
		soon = "Скоро: косметические наборы. Платной случайности нет.",
	},
	chest = {
		name = "Сундук дня",
		verb = "Сундук дня",
		point = "DailyChest",
		kind = "dialog",
		status = "live",
		window = "DailyChest",
		title = "Сундук дня",
		lines = {
			"Дар деревни путнику. Открывается раз в день и помнит, сколько дней подряд ты возвращался.",
		},
		soon = "Скоро: ежедневная награда и стрик (заморозка на день при пропуске).",
	},
	names = {
		name = "Стена забытых имён",
		verb = "Стена забытых имён",
		point = "Leaderboard",
		kind = "dialog",
		status = "live",
		window = "Wall",
		title = "Стена забытых имён",
		lines = {
			"Здесь пишут имена тех, кто ушёл за хребет и не вернулся. Чтобы мир не забыл.",
			"На средней табличке — имена тех, кто сейчас в долине.",
		},
	},
	board = {
		name = "Доска заданий",
		verb = "Посмотреть доску",
		point = "QuestBoard",
		kind = "quests",
		status = "live",
		window = "Board",
		title = "Доска заданий Гильдии",
	},
	altar = {
		name = "Алтарь Переписывания",
		verb = "Алтарь: сменить орден",
		point = "Altar",
		kind = "dialog",
		status = "stub",
		title = "Алтарь Переписывания",
		lines = {
			"Орден меняют так же, как переписывают строку: старое остаётся под новым.",
			"Орден Щита, Стражи Памяти. Жнецы Теней. Хронисты. Прогресс каждого хранится отдельно.",
		},
		soon = "Сейчас доступен Воин. Первая смена бесплатная, дальше за золото или осколки.",
	},
	archive = {
		name = "Архив",
		verb = "Читать Архив",
		point = "Archive",
		kind = "archive",
		status = "live",
		title = "Архив Гильдии",
		lines = {
			"Каждая поглощённая память оставляет здесь страницу.",
			"Собирай фрагменты: так клинок вспоминает, кому принадлежал.",
		},
	},
	dummies = {
		name = "Тренировочный двор",
		verb = "Тренировка",
		point = "TrainingYard",
		kind = "dialog",
		status = "stub",
		title = "Тренировочный двор",
		lines = {
			"Набитые соломой стражи. Они не бьют в ответ и не забывают.",
		},
		soon = "Скоро: тренировка комбо, уклонения и парирования.",
	},
}

Hub.Floors = {}
for index, floor in ipairs(Palette.Floors) do
	Hub.Floors[index] = {
		id = floor.id,
		name = floor.name,
		theme = floor.theme,
		colors = floor.colors,
		built = Hub.BuiltFloors[floor.id] == true,
	}
end

-- Если FloorService недоступен, портал ставит игрока сюда.
Hub.FirstFloorFallback = Vector3.new(0, 3.5, -20)

return Hub
