--!nonstrict
-- UiAssets
-- Все id картинок и звуков интерфейса v2 в одном месте.
-- После загрузки файлов из dist/ui2/assets в Roblox (Creator Hub → Development Items → Decals/Audio)
-- впишите сюда полученные rbxassetid. Код больше нигде не трогать.

local UiAssets = {}

-- Атласы интерфейса v2 и отдельные изображения бумажного инвентаря.
UiAssets.Atlas = "rbxassetid://133961702646527" -- assets/ui_atlas.png
UiAssets.Icons = "rbxassetid://109849206879952" -- assets/icons_atlas.png (перерисовка владельца, 12.11.2026; старый 107052473817040)
-- Иллюстрации справки новичка (слайды TutorialController): пиксель-арт иконки
-- владельца 20×20 из его сгенерированного листа (tools/icons/out/cells,
-- нарезка 12.11.2026), растянуты ×18 (nearest) до 360×360 — ImageLabel рисует
-- их 1:1, поэтому пиксели чёткие без Enum.ResampleMode (в сборке его нет).
UiAssets.TutorialArt = {
	keyart = "", -- кей-арт слайда 1 (арта владельца 16:9; id придёт после заливки)
	warriorHead = "rbxassetid://87349711319647", -- голова воина (иконка владельца 60×60)
	mageHead = "rbxassetid://132857988748016", -- голова мага
	sword = "rbxassetid://96283231034397",
	soul = "rbxassetid://111943452894344",
	dash = "rbxassetid://84718161334147",
	shield = "rbxassetid://93860838714944",
	chest = "rbxassetid://126553341753956",
	hammer = "rbxassetid://77378335258737",
	quest = "rbxassetid://132937001653793",
}
-- Отдельный атлас иконок владельца 256×128 на прозрачном фоне (28 шт., сетка
-- 11/11/6, ~16 px) — кандидат на замену UiAssets.Icons; пока не подключён.
-- id: 130353507730561
-- Humble Gift — Paper UI System v1.1, отдельные изображения, загруженные в Roblox.
UiAssets.Paper = {
	Panel = "rbxassetid://72691594969778",
	Banner = "rbxassetid://131292677449576",
	Item = "rbxassetid://124571601843442",
	Slot = "rbxassetid://106835371536147",
}

-- Бумажный атлас «Книги героя» (tools/paperui/build_paper_atlas.py):
-- assets/paper/paper_ui.png и подложка-стол assets/paper/paper_desk.png.
-- Пока пусто — окно рисует бумагу простыми рамками (заглушки PaperUi).
UiAssets.PaperAtlas = "rbxassetid://130197875642411"
UiAssets.PaperDesk = "rbxassetid://97724648764340"

-- Шрифт: Press Start 2P (в Roblox это Enum.Font.Arcade). Если кириллица в нём
-- отображается не пиксельной — заменить на загруженный шрифт или Enum.Font.Code.
UiAssets.Font = Font.fromEnum(Enum.Font.Arcade)
UiAssets.FontBold = Font.fromEnum(Enum.Font.Arcade)

-- Звуки (assets/sfx/*.ogg). Пока 0 — играют встроенные заглушки из fallback.
UiAssets.Sounds = {
	ui_click = { id = "rbxassetid://75945212875429", volume = 0.3, fallback = "rbxasset://sounds/button.wav" },
	ui_hover = { id = "rbxassetid://124886111336250", volume = 0.20, fallback = "rbxasset://sounds/clickfast.wav" },
	ui_open_scene = { id = "rbxassetid://73782762144647", volume = 0.4, fallback = "rbxasset://sounds/clickfast.wav" }, -- swoosh.wav в этой сборке нет
	echo_absorb = { id = "rbxassetid://94739563648535", volume = 0.5, fallback = "rbxasset://sounds/electronicpingshort.wav" },
	forge_strike = { id = "rbxassetid://90389338356573", volume = 0.6, fallback = "rbxasset://sounds/kick.mp3" },
	forge_success = { id = "rbxassetid://133343638842181", volume = 0.6, fallback = "rbxasset://sounds/victory.wav" },
	forge_fail = { id = "rbxassetid://125635591584897", volume = 0.4, fallback = "rbxasset://sounds/clickfast.wav" },
	coins = { id = "rbxassetid://74487280924066", volume = 0.4, fallback = "rbxasset://sounds/electronicpingshort.wav" },
	chest_open = { id = "rbxassetid://75789937658440", volume = 0.6, fallback = "rbxasset://sounds/victory.wav" },
	reward_pop = { id = "rbxassetid://99395334861564", volume = 0.4, fallback = "rbxasset://sounds/electronicpingshort.wav" },
	streak_stone = { id = "rbxassetid://89452146704855", volume = 0.5, fallback = "rbxasset://sounds/bass.wav" },
	level_up = { id = "rbxassetid://85413528296397", volume = 0.5, fallback = "rbxasset://sounds/victory.wav" },
	error = { id = "rbxassetid://82234121232217", volume = 0.4, fallback = "rbxasset://sounds/clickfast.wav" },
	smith_voice_1 = { id = "rbxassetid://130340821977363", volume = 0.4, fallback = nil },
	smith_voice_2 = { id = "rbxassetid://119019310769619", volume = 0.4, fallback = nil },
}

-- Цвета интерфейса (совпадают с макетами).
-- ===== Палитра звуков интерфейса v3 (07.11.2026) =====
-- «Дерево и пергамент» взамен резких звуков (tools/sfx-ui, страница-палитра
-- «Звуки интерфейса Клинка»). Файлы — tools/sfx-ui/ogg/<имя>.ogg: Артём
-- загружает одобренные в Roblox (Creator Hub → Audio) и вписывает id сюда.
-- Пока id пустой, играет старый звук — ничего не ломается.
UiAssets.UiVolume = 0.8 -- общий ползунок всех звуков интерфейса (SoundGroup «KlinokUi»)
UiAssets.Palette = {
	hover = { id = "rbxassetid://107736348949057", volume = 0.25 }, -- Наведение на кнопку, слот, пункт списка
	click = { id = "rbxassetid://95372400782300", volume = 0.35 }, -- Нажатие кнопки
	tab = { id = "rbxassetid://88533869811344", volume = 0.3 }, -- Вкладка, выбор ответа
	paper_slide = { id = "rbxassetid://136570631365713", volume = 0.3 }, -- Окно открылось / закрылось, разговор
	page_turn = { id = "rbxassetid://86956085889857", volume = 0.35 }, -- Листание книги героя
	error = { id = "", volume = 0.35 }, -- «Нельзя»: мало денег, нет места, закрыто
	stamp = { id = "rbxassetid://129164759068459", volume = 0.35 }, -- Подтвердил: печать, купил, выучил талант
	item_get = { id = "rbxassetid://111762567324627", volume = 0.35 }, -- Получен новый предмет (тост)
	armor_equip = { id = "rbxassetid://74761573467156", volume = 0.4 }, -- Надел броню / выпала броня
	coins = { id = "", volume = 0.3 }, -- Золото
	coin_tick = { id = "rbxassetid://126752889147997", volume = 0.25 }, -- Счётчик золота тикает
	level_up = { id = "", volume = 0.4 }, -- Новый уровень, задание выполнено
	star_on = { id = "rbxassetid://134795794729480", volume = 0.35 }, -- Звезда ★ / талант / медаль
	chest_appear = { id = "rbxassetid://117415232035440", volume = 0.3 }, -- Сундук появляется и летит в сумку
	chest_land = { id = "rbxassetid://108038579443928", volume = 0.4 }, -- Сундук ставится на стол / подобран
	chest_open = { id = "", volume = 0.4 }, -- Защёлка, скрип крышки
	blade_strike = { id = "rbxassetid://71133138268401", volume = 0.35 }, -- Клинок касается сундука («читает память»)
	memory_tick = { id = "rbxassetid://95978882371205", volume = 0.25 }, -- Перебор редкостей (тик)
	reveal = { id = "rbxassetid://120028950946561", volume = 0.35 }, -- Показ обычного / редкого предмета
	reveal_rare = { id = "rbxassetid://137942812021877", volume = 0.4 }, -- Эпик, легенда, секрет
	anvil = { id = "rbxassetid://95205046991817", volume = 0.35 }, -- Удар молота по наковальне
	forge_heat = { id = "rbxassetid://114032638018319", volume = 0.3 }, -- Горн разгорается
	quench = { id = "rbxassetid://117475570706634", volume = 0.3 }, -- Закалка в воде
	spark = { id = "rbxassetid://87391787892597", volume = 0.25 }, -- Искры
	forge_success = { id = "", volume = 0.4 }, -- Улучшение удалось (+★)
	forge_fail = { id = "", volume = 0.35 }, -- Не хватает материала / отказ кузни
	echo = { id = "rbxassetid://112213372188276", volume = 0.35 }, -- Эхо / душа впитывается
}

-- Какой звук палитры играет вместо старого ключа: UiSound.play(<ключ>) и
-- шина Bus.emit("sfx", { name = <ключ> }) (AudioController). Боёвки здесь нет.
UiAssets.PaletteFor = {
	ui_hover = "hover",
	choice_hover = "hover",
	list_tick = "hover",
	uiHover = "hover",
	stone_tick = "hover",
	ui_click = "click",
	ui = "click",
	dialog_next = "click",
	confirm = "click",
	floor_pick = "click",
	tab_select = "tab",
	choice_pick = "tab",
	paper_slide = "paper_slide",
	dialog_open = "paper_slide",
	dialog_close = "paper_slide",
	ui_open_scene = "paper_slide",
	page_turn = "page_turn",
	page_back = "page_turn",
	error = "error",
	mana_empty = "error",
	stamp = "stamp",
	reward_pop = "item_get",
	new_topic = "item_get",
	armorEquip = "armor_equip",
	coins = "coins",
	coin_tick = "coin_tick",
	level_up = "level_up",
	levelUp = "level_up",
	hubQuest = "level_up",
	star_on = "star_on",
	medal = "star_on",
	chest_appear = "chest_appear",
	chest_fly = "chest_appear",
	chest_land = "chest_land",
	chest_pickup = "chest_land",
	stone_slab = "chest_land",
	lid_open = "chest_open",
	chest_open = "chest_open",
	chest = "chest_open",
	blade_strike = "blade_strike",
	blade_form = "blade_strike",
	memory_tick = "memory_tick",
	item_reveal = "reveal",
	memory_secret = "reveal_rare",
	forge_strike = "anvil",
	forge_anvil = "anvil",
	forge_heat = "forge_heat",
	candle = "forge_heat",
	forge_quench = "quench",
	forge_spark = "spark",
	forge_success = "forge_success",
	forge_reveal = "forge_success",
	forge_fail = "forge_fail",
	echo_absorb = "echo",
	echo_socket = "echo",
	soul = "echo",
	-- «Дары Эха»: выбор карточки — как изучение таланта (вместо старого reward_pop),
	-- наведение — обычный звук наведения палитры (без перезвона)
	boon_pick = "star_on",
	boon_pick_legend = "star_on",
	boon_hover = "hover",
}

UiAssets.Colors = {
	ink = Color3.fromRGB(52, 36, 24),
	ink2 = Color3.fromRGB(120, 84, 48),
	bone = Color3.fromRGB(248, 240, 222),
	gold = Color3.fromRGB(255, 204, 84),
	mem = Color3.fromRGB(120, 232, 255),
	dark = Color3.fromRGB(14, 9, 6),
	green = Color3.fromRGB(120, 220, 110),
	grey = Color3.fromRGB(160, 150, 140),
	red = Color3.fromRGB(240, 90, 80),
	hp = Color3.fromRGB(214, 58, 52),
	xp = Color3.fromRGB(255, 204, 84),
	mana = Color3.fromRGB(79, 123, 255), -- Palette.Mana
	manaLight = Color3.fromRGB(157, 184, 255), -- Palette.ManaLight
}

UiAssets.Rarity = {
	common = Color3.fromRGB(170, 176, 184),
	rare = Color3.fromRGB(88, 200, 92),
	epic = Color3.fromRGB(176, 106, 244),
	legendary = Color3.fromRGB(255, 176, 46),
	mythic = Color3.fromRGB(240, 80, 84),
	secret = Color3.fromRGB(120, 232, 255),
}

UiAssets.RarityName = {
	common = "Обычное",
	rare = "Редкое",
	epic = "Эпическое",
	legendary = "Легендарное",
	mythic = "Мифическое",
	secret = "Тайное",
}

-- Иконка по типу оружия.
UiAssets.WeaponIcon = { sword = "sword", dagger = "dagger", hammer = "hammer", staff = "staff" }

return UiAssets
