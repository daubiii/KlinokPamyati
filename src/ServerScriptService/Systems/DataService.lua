--!nonstrict
-- DataService (сервер)
-- Профиль игрока: золото, материалы, оружие, души, счётчик невезения,
-- версия формата. Раздел 12 плана.
--
-- Клиенту ничего не доверяем: он видит только атрибуты, а меняет всё через сервер.
--
-- Сохранения для многопользовательской игры (переделка 09.11.2026):
--   * У каждого игрока своё состояние: loading → ready (или failed).
--     Сбой загрузки у одного игрока больше НЕ переводит весь сервер в
--     «память сессии» — остальные сохраняются как обычно.
--   * Сессионный замок. В записи профиля лежит _session = { job, place, id, t }:
--     какой сервер сейчас держит профиль. Второй сервер профиль не откроет,
--     пока первый его не отпустит (выход игрока, закрытие сервера) или пока
--     замок не устареет (сервер упал и LOCK_STALE секунд его не обновлял).
--     Так один профиль нельзя играть на двух серверах одновременно, и
--     переход между серверами (телепорт) не теряет прогресс.
--   * Пишем только через UpdateAsync и только если замок наш. Если замок
--     перехватил другой сервер — ничего не перезаписываем, игрока отключаем.
--   * Профиль-заглушка (DataService.get до конца загрузки) никогда не
--     сохраняется и не публикуется в атрибуты.
--   * Ошибки хранилища: повторы с паузой, учёт бюджета запросов. В живой игре
--     после всех повторов — вежливое отключение, а не пустой профиль, который
--     потом затёр бы настоящий.
--   * Зеркальный бэкап-стор (KlinokPamyati_backup_v1): ценное сохранение и
--     выход пишут копию профиля в отдельный стор (кольцо из двух поколений:
--     cur + prev). Если главная запись пропала или побилась — профиль
--     восстанавливается из копии ещё ДО того, как игроку создадут новый.
--   * Строгая валидация после загрузки: битые числа (NaN, бесконечность,
--     отрицательные), сломанные словари/массивы правятся по умолчанию —
--     мусор из хранилища не доезжает до систем.
--   * Studio без доступа к API: профиль живёт в памяти сессии (как раньше);
--     при старте делается проба и печатается понятная инструкция по галке
--     «Enable Studio Access to API Services».
--
-- Признак «профиль загружен» для остальных систем: DataService.status(player)
-- == "ready", DataService.waitForProfile(player, таймаут) или DataService.onLoaded.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugState = require(Shared.Net.DebugState)
local Chests = require(Shared.Config.Chests)

local DataService = {}

-- Диагностика 15.11: сколько копий модуля загрузилось (2+ = расщепление
-- инстансов — обычно rojo-синк посреди плей-сессии). Studio-only канал
-- (DebugState), в опубликованной игре атрибутов не будет.
DebugState.bump("Data", "DSBoots")

local PROFILE_VERSION = 4 -- 2: броня воина (armorEquipped / armorItems); 3: древо талантов; 4: сундуки в сумке
local STORE_NAME = "KlinokPamyati_v1"
local BACKUP_STORE_NAME = "KlinokPamyati_backup_v1" -- зеркальная копия: cur + prev
local WEAPONS_CAP = 150 -- потолок массива оружия (профиль не должен распухать)
local ARMOR_CAP = 150
local AUTOSAVE_INTERVAL = 60
local LOCK_STALE = 180 -- с: замок без обновления дольше — сервер-владелец считается упавшим
local LOCK_WAIT = 24 -- с: сколько ждать, пока другой сервер отпустит профиль
local LOAD_ATTEMPTS = 5 -- попыток при ошибках хранилища
local SAVE_ATTEMPTS = 3
local CLOSE_TIMEOUT = 26 -- с: BindToClose даёт серверу 30 секунд

local IS_STUDIO = RunService:IsStudio()

local entries = {} -- [player] = { key, status, mode, profile, lockId, busy, nextSave }
local placeholders = {} -- [player] = профиль-заглушка до загрузки (не сохраняется)
local releasing = {} -- [key] = true, пока идёт финальная запись вышедшего игрока
local sessionStore = {} -- Studio без API: профили в памяти сервера
local loadedListeners = {}
local store = nil
local studioOffline = false -- Studio без доступа к API: всё в памяти сессии
local closing = false

local MESSAGES = {
	locked = "Твой профиль ещё открыт на другом сервере. Подожди минуту и зайди снова — прогресс в сохранности.",
	error = "Не удалось загрузить профиль: хранилище Roblox сейчас не отвечает. Зайди снова через пару минут — прогресс в сохранности.",
	stolen = "Этот профиль открыли на другом сервере. Здесь сессия закрыта, чтобы не потерять прогресс.",
}

local function defaultProfile()
	return {
		version = PROFILE_VERSION,
		className = "warrior",
		level = 5, -- эталонный воин этажа 1 (приложение Б)
		xp = 0,
		gold = 0,
		materials = {},
		weapons = {},
		souls = {},
		soulStacks = 0,
		bossKills = 0,
		-- Пройденные этажи: floorClears[этаж] = { normal = true, ... } (читает хаб).
		floorClears = {},
		-- Задания Гильдии (QuestService): active = id или nil, progress[id] = число,
		-- talked = { [villagerId] = true } для «Голосов долины», done[id] = true.
		quests = { active = nil, progress = {}, talked = {}, done = {} },
		-- Фрагменты Архива: archive[id] = true.
		archive = {},
		newWeapons = 0,
		-- Броня (ArmorService): надетое по слотам и снятое/найденное.
		-- Стартовый комплект странника кладёт ArmorService.ensureProfile.
		armorEquipped = {},
		armorItems = {},
		-- Надетое на других классах: armorStash[класс] = { helm, armor }.
		armorStash = {},
		newArmor = 0,
		-- Древо талантов (TalentService): talents[класс] = { nodes = { [id] = true }, resets = N, version = 2 }.
		-- Очки не хранятся: их число = уровень − 1, свободные = очки − потрачено.
		talents = {},
		chestsSinceSecret = 0,
		-- Лобби знакомства (TutorialService): показывается, пока метка не true.
		tutorialDone = false,
		-- Выбор класса после справки (TutorialService.applyClassChoice): true — окно больше не показывается.
		classChosen = false,
		-- Настройки игрока (PlayerSettings): громкость музыки/звуков, множитель чувствительности камеры.
		settings = { music = 0.7, sfx = 1, sens = 1 },
		-- Сундуки этажей v3 (ChestService): chests["f<этаж>_<common|gold>"] = N, открываются в долине.
		chests = {},
		equippedWeapon = {
			id = "rusty_sword",
			name = "Ржавый меч",
			typeId = "sword",
			rarityId = "common",
			sharpening = 0,
		},
		stats = {
			chestsOpened = 0,
			chestsEarned = 0,
			enemiesKilled = 0,
			dodges = 0,
			parries = 0,
			damageDealt = 0,
		},
	}
end

-- Миграции формата: каждая версия знает, как довести профиль до следующей.
local migrations = {
	-- 1 → 2: броня. Старому профилю выдаём пустые слоты — ArmorService
	-- наденет стартовый комплект странника при входе.
	[1] = function(profile)
		profile.armorEquipped = profile.armorEquipped or {}
		profile.armorItems = profile.armorItems or {}
		profile.newArmor = profile.newArmor or 0
	end,
	-- 2 → 3: древо талантов. Очки выдаются по уровню сразу — ничего не теряется.
	[2] = function(profile)
		profile.talents = profile.talents or {}
	end,
	-- 3 → 4: сундуки этажей лежат в сумке и открываются в долине.
	[3] = function(profile)
		profile.chests = profile.chests or {}
		profile.stats = profile.stats or {}
		profile.stats.chestsEarned = profile.stats.chestsEarned or 0
	end,
}

local function migrate(profile)
	local version = profile.version or 0
	while version < PROFILE_VERSION do
		local step = migrations[version]
		if step then
			step(profile)
		end
		version += 1
		profile.version = version
	end
	return profile
end

-- Дописать в профиль поля, которых не было на момент его сохранения
-- (PLAN_DORABOTKI P1-8): отсутствующие ключи берутся из дефолта, существующие
-- не трогаются. Дефолтные таблицы пустые, поэтому слияние вглубь безопасно:
-- оно только достраивает структуру, а не подмешивает чужие данные.
local function reconcile(target, template)
	for key, defaultValue in pairs(template) do
		local current = target[key]
		if current == nil then
			if type(defaultValue) == "table" then
				local copy = table.clone(defaultValue)
				target[key] = copy
				reconcile(copy, defaultValue)
			else
				target[key] = defaultValue
			end
		elseif type(current) == "table" and type(defaultValue) == "table" then
			reconcile(current, defaultValue)
		end
	end
end

-- ===== Строгая валидация профиля =====
-- Битые значения из хранилища (NaN, бесконечность, минусы, мусорные типы)
-- правятся по умолчанию ДО того, как профиль увидят системы. Чего не знаем —
-- не трогаем: системы и так достраивают своё через reconcile.

local function saneInt(v): boolean
	return typeof(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function fixInt(v, min: number, max: number): number?
	if not saneInt(v) then
		return nil
	end
	return math.floor(math.clamp(v, min, max))
end

local function validateProfile(profile)
	local fixed = {}
	local function mark(name: string)
		fixed[name] = true
	end

	-- Простые числа-поля.
	local function num(field: string, min: number, max: number, fallback: number)
		local v = fixInt(profile[field], min, max)
		if v == nil then
			profile[field] = fallback
			mark(field)
		else
			profile[field] = v
		end
	end
	num("level", 1, 500, 5)
	num("xp", 0, 1e12, 0)
	num("gold", 0, 1e12, 0)
	num("soulStacks", 0, 1e9, 0)
	num("bossKills", 0, 1e9, 0)
	num("newWeapons", 0, 1e9, 0)
	num("newArmor", 0, 1e9, 0)
	num("chestsSinceSecret", 0, 1e9, 0)

	-- Статистика: целые неотрицательные.
	if type(profile.stats) ~= "table" then
		profile.stats = {}
		mark("stats")
	end
	for _, key in ipairs({ "chestsOpened", "chestsEarned", "enemiesKilled", "dodges", "parries", "damageDealt" }) do
		local v = fixInt(profile.stats[key], 0, 1e12)
		if v == nil then
			profile.stats[key] = 0
			mark("stats." .. key)
		else
			profile.stats[key] = v
		end
	end

	-- Словари счётчиков: строковые ключи, целые неотрицательные значения.
	local function counters(field: string)
		if type(profile[field]) ~= "table" then
			profile[field] = {}
			mark(field)
			return
		end
		for key, value in pairs(profile[field]) do
			local v = fixInt(value, 0, 1e12)
			if type(key) ~= "string" or v == nil then
				profile[field][key] = nil
				mark(field)
			else
				profile[field][key] = v
			end
		end
	end
	counters("materials")
	counters("chests")

	-- Внутренние поля структур, которые сервисы создают лениво (само наличие
	-- таблицы они проверяют сами, а вот битые ЧИСЛА внутри ранее доезжали до
	-- арифметики и роняли DailyService.position / LeaderboardService.score).
	if type(profile.daily) == "table" then
		local streak = fixInt(profile.daily.streak, 0, 1e6)
		if streak == nil then
			profile.daily.streak = 0
			mark("daily.streak")
		else
			profile.daily.streak = streak
		end
		if profile.daily.lastDay ~= nil and type(profile.daily.lastDay) ~= "number" then
			profile.daily.lastDay = nil
			mark("daily.lastDay")
		end
	end
	if type(profile.records) == "table" then
		for _, key in ipairs({ "floor", "room" }) do
			local v = fixInt(profile.records[key], 0, 1e6)
			if v == nil then
				profile.records[key] = 0
				mark("records." .. key)
			else
				profile.records[key] = v
			end
		end
	end
	if type(profile.weekly) == "table" then
		local souls = fixInt(profile.weekly.souls, 0, 1e12)
		if souls == nil then
			profile.weekly.souls = 0
			mark("weekly.souls")
		else
			profile.weekly.souls = souls
		end
	end
	-- Очередь гарантий сундуков: только массивы пар {minRarity, epicChance}.
	if type(profile.chestTiers) == "table" then
		for key, queue in pairs(profile.chestTiers) do
			if type(key) ~= "string" or type(queue) ~= "table" then
				profile.chestTiers[key] = nil
				mark("chestTiers")
			else
				for i = #queue, 1, -1 do
					local entry = queue[i]
					if type(entry) ~= "table" or type(entry[1]) ~= "number" or type(entry[2]) ~= "number" then
						table.remove(queue, i)
						mark("chestTiers")
					end
				end
			end
		end
	end

	-- floorClears[этаж] = таблица флагов.
	if type(profile.floorClears) ~= "table" then
		profile.floorClears = {}
		mark("floorClears")
	else
		for floorId, flags in pairs(profile.floorClears) do
			if type(floorId) ~= "number" or type(flags) ~= "table" then
				profile.floorClears[floorId] = nil
				mark("floorClears")
			end
		end
	end

	-- Задания: три словаря флагов/счётчиков + активный id.
	if type(profile.quests) ~= "table" then
		profile.quests = { active = nil, progress = {}, talked = {}, done = {} }
		mark("quests")
	else
		if type(profile.quests.progress) ~= "table" then
			profile.quests.progress = {}
			mark("quests.progress")
		end
		for key, value in pairs(profile.quests.progress) do
			local v = fixInt(value, 0, 1e9)
			if type(key) ~= "string" or v == nil then
				profile.quests.progress[key] = nil
				mark("quests.progress")
			else
				profile.quests.progress[key] = v
			end
		end
		for _, field in ipairs({ "talked", "done" }) do
			if type(profile.quests[field]) ~= "table" then
				profile.quests[field] = {}
				mark("quests." .. field)
			else
				for key, value in pairs(profile.quests[field]) do
					if type(key) ~= "string" or value ~= true then
						profile.quests[field][key] = nil
						mark("quests." .. field)
					end
				end
			end
		end
		if profile.quests.active ~= nil and type(profile.quests.active) ~= "string" then
			profile.quests.active = nil
			mark("quests.active")
		end
	end

	-- Массивы с потолком: только таблицы, дыры вычищаются.
	local function cleanArray(field: string, cap: number)
		local clean = {}
		if type(profile[field]) == "table" then
			for _, value in ipairs(profile[field]) do
				if type(value) == "table" and #clean < cap then
					table.insert(clean, value)
				end
			end
			if #clean ~= #profile[field] then
				mark(field)
			end
		else
			mark(field)
		end
		profile[field] = clean
	end
	cleanArray("weapons", WEAPONS_CAP)
	cleanArray("armorItems", ARMOR_CAP)

	-- Души, архив, таланты, броня: словари/структуры систем — только тип.
	for _, field in ipairs({ "souls", "archive", "talents", "armorEquipped", "armorStash" }) do
		if type(profile[field]) ~= "table" then
			profile[field] = {}
			mark(field)
		end
	end

	-- Ключевые поля-«ярлыки».
	if type(profile.className) ~= "string" or profile.className == "" then
		profile.className = "warrior"
		mark("className")
	end
	if type(profile.equippedWeapon) ~= "table" or type(profile.equippedWeapon.id) ~= "string" then
		profile.equippedWeapon = {
			id = "rusty_sword",
			name = "Ржавый меч",
			typeId = "sword",
			rarityId = "common",
			sharpening = 0,
		}
		mark("equippedWeapon")
	end
	if type(profile.tutorialDone) ~= "boolean" then
		profile.tutorialDone = false
		mark("tutorialDone")
	end

	if next(fixed) ~= nil then
		local names = {}
		for name in pairs(fixed) do
			table.insert(names, name)
		end
		table.sort(names)
		warn("[DataService] строгая валидация исправила поля: " .. table.concat(names, ", "))
	end
end

-- ===== Хранилище =====

local function openStore()
	if store or studioOffline then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and result then
		store = result
	else
		warn("[DataService] DataStore не открылся: " .. tostring(result))
		if IS_STUDIO then
			studioOffline = true
			warn("[DataService] ЧТОБЫ ТЕСТЫ В STUDIO СОХРАНЯЛИСЬ: 1) опубликуй место — File → Publish to Roblox As; 2) Game Settings → Security → включи «Enable Studio Access to API Services». До этого профили в Studio живут в памяти сессии и не сохраняются.")
		end
	end
	return store
end

-- Дождаться бюджета запросов (не дольше maxWait секунд), чтобы не упереться
-- в лимит Roblox и не получить очередь из сотни запросов.
local function waitForBudget(maxWait: number)
	local waited = 0
	while waited < maxWait do
		local ok, budget = pcall(function()
			return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
		end)
		if not ok or budget > 0 then
			return
		end
		waited += task.wait(0.5)
	end
end

local function newLock(lockId: string)
	return { job = game.JobId, place = game.PlaceId, id = lockId, t = os.time() }
end

-- ===== Зеркальный бэкап-стор =====
-- Копия профиля пишется в отдельный стор при ценных сохранениях и выходе
-- (кольцо из двух поколений: cur + prev). Если главная запись пропала или
-- побилась — профиль восстанавливается из копии ДО создания нового профиля.

local backupStore = nil
local backupFailed = false

local function openBackup()
	if backupFailed then
		return nil
	end
	if backupStore then
		return backupStore
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(BACKUP_STORE_NAME)
	end)
	if ok and result then
		backupStore = result
	else
		backupFailed = true
		warn("[DataService] бэкап-стор не открылся: " .. tostring(result))
	end
	return backupStore
end

local function writeBackup(key: string, profile)
	local bs = openBackup()
	if not bs or type(profile) ~= "table" then
		return
	end
	local record = table.clone(profile)
	record._session = nil
	local ok, err = pcall(function()
		waitForBudget(4)
		bs:UpdateAsync(key, function(current)
			local prev = nil
			local prevT = nil
			if type(current) == "table" then
				prev = (type(current.cur) == "table") and current.cur or nil
				prevT = current.t
			end
			return { cur = record, prev = prev, prevT = prevT, t = os.time() }
		end)
	end)
	if not ok then
		warn("[DataService] бэкап " .. key .. " не записан: " .. tostring(err))
	end
end

-- Последняя (или предыдущая) копия профиля. nil — копии нет.
local function readBackup(key: string)
	local bs = openBackup()
	if not bs then
		return nil
	end
	local ok, data = pcall(function()
		waitForBudget(4)
		return bs:GetAsync(key)
	end)
	if not ok or type(data) ~= "table" then
		return nil
	end
	if type(data.cur) == "table" then
		return table.clone(data.cur), data.t
	end
	if type(data.prev) == "table" then
		return table.clone(data.prev), data.prevT
	end
	return nil
end

-- Замок держит другой живой сервер?
local function lockedByOther(lock): boolean
	if type(lock) ~= "table" then
		return false
	end
	if lock.job == game.JobId then
		return false -- наш же сервер (перезаход или недописанный выход)
	end
	return os.time() - (tonumber(lock.t) or 0) < LOCK_STALE
end

-- Вернуть профиль из копии в главный стор (пропавшая/битая запись), под свой
-- замок. → профиль | nil, причина.
local function tryRestoreFromBackup(key: string, lockId: string)
	local record, savedAt = readBackup(key)
	if not record or type(record) ~= "table" then
		return nil, "резервной копии нет"
	end
	local restored = nil
	local foreign = false
	local ok, err = pcall(function()
		waitForBudget(6)
		store:UpdateAsync(key, function(current)
			foreign = false
			restored = nil
			if current ~= nil and lockedByOther(type(current) == "table" and current._session or nil) then
				foreign = true
				return nil
			end
			local copy = table.clone(record)
			copy._session = newLock(lockId)
			restored = copy
			return copy
		end)
	end)
	if not ok then
		return nil, tostring(err)
	end
	if foreign then
		return nil, "замок у другого сервера"
	end
	if not restored then
		return nil, "хранилище не записало восстановление"
	end
	warn(("[DataService] профиль %s ВОССТАНОВЛЕН из резервной копии (сохранена %s)"):format(key, savedAt and os.date("%d.%m %H:%M", savedAt) or "?"))
	return restored, nil
end

local function entryOf(player)
	return entries[player]
end

local function publish(player, profile)
	-- Заглушку не публикуем: ProfileVersion — признак настоящей загрузки.
	local entry = entries[player]
	if not entry or entry.status ~= "ready" or entry.profile ~= profile then
		return
	end
	player:SetAttribute("Gold", profile.gold)
	player:SetAttribute("WeaponCount", #profile.weapons)
	player:SetAttribute("ChestsOpened", profile.stats.chestsOpened)
	player:SetAttribute("ChestsSinceSecret", profile.chestsSinceSecret)
	player:SetAttribute("ChestsStored", Chests.total(profile.chests))
	player:SetAttribute("ProfileVersion", profile.version)
	player:SetAttribute("Level", profile.level)
	player:SetAttribute("Xp", profile.xp)
	player:SetAttribute("SoulStacks", profile.soulStacks or 0)
	player:SetAttribute("NewWeapons", profile.newWeapons or 0)
	player:SetAttribute("NewArmor", profile.newArmor or 0)
	player:SetAttribute("IronCount", profile.materials.rusty_iron or 0)
	player:SetAttribute("MaterialCount", (function()
		local count = 0
		for _ in pairs(profile.materials) do
			count += 1
		end
		return count
	end)())
	player:SetAttribute("SaveMode", entry.mode)
	DebugState.set("Data", "Mode", entry.mode)
	DebugState.set("Data", "Gold", profile.gold)
end

-- Одна попытка взять профиль под свой замок.
-- "ok", profile, isNew | "locked", lock | "error", message
local function tryLoad(key: string, lockId: string)
	local loaded, isNew, foreign, corrupt = nil, false, nil, false
	waitForBudget(5)
	local ok, err = pcall(function()
		store:UpdateAsync(key, function(current)
			loaded, isNew, foreign, corrupt = nil, false, nil, false
			if current == nil then
				local fresh = defaultProfile()
				fresh._session = newLock(lockId)
				loaded, isNew = fresh, true
				return fresh
			end
			if type(current) ~= "table" then
				corrupt = true
				return nil -- непонятная запись: не трогаем и не затираем
			end
			if lockedByOther(current._session) then
				foreign = current._session
				return nil -- профиль держит другой сервер: запись отменяем
			end
			current._session = newLock(lockId)
			loaded = current
			return current
		end)
	end)
	if not ok then
		return "error", tostring(err)
	end
	if corrupt then
		return "error", "запись профиля не таблица"
	end
	if foreign then
		return "locked", foreign
	end
	if not loaded then
		return "error", "пустой ответ хранилища"
	end
	loaded._session = nil
	return "ok", loaded, isNew
end

-- Записать профиль игрока. release = отпустить замок (выход / закрытие).
-- true | false, "stolen" | false, "error"
local function writeEntry(entry, release: boolean)
	if entry.mode == "session" then
		sessionStore[entry.key] = entry.profile
		return true
	end
	if not openStore() then
		return false, "error"
	end
	local record = table.clone(entry.profile)
	if not release then
		record._session = newLock(entry.lockId)
	end
	for attempt = 1, SAVE_ATTEMPTS do
		waitForBudget(closing and 2 or 8)
		local stolen = false
		local ok, err = pcall(function()
			store:UpdateAsync(entry.key, function(current)
				stolen = false
				local lock = type(current) == "table" and current._session or nil
				-- Пишем только поверх своего замка. Замок снят или чужой — значит,
				-- профилем уже владеет другая сессия, и наши данные устарели.
				if type(lock) ~= "table" or lock.job ~= game.JobId or lock.id ~= entry.lockId then
					stolen = true
					return nil
				end
				return record
			end)
		end)
		if ok then
			if stolen then
				return false, "stolen"
			end
			entry.lastSaved = os.clock()
			return true
		end
		warn(("[DataService] не сохранилось (%s, попытка %d): %s"):format(entry.key, attempt, tostring(err)))
		if attempt < SAVE_ATTEMPTS then
			task.wait(closing and 1 or attempt * 2)
		end
	end
	return false, "error"
end

-- Одна запись за раз на игрока: автосейв, выход и закрытие не накладываются.
local function withEntry(entry, fn)
	local waited = 0
	while entry.busy and waited < 30 do
		waited += task.wait(0.1)
	end
	entry.busy = true
	local ok, a, b = pcall(fn)
	entry.busy = false
	if not ok then
		warn("[DataService] " .. tostring(a))
		return false, "error"
	end
	return a, b
end

local function kick(player, reason: string)
	if player.Parent then
		player:Kick(MESSAGES[reason] or MESSAGES.error)
	end
end

-- ===== Публичный API =====

-- "datastore" — пишем в DataStore; "session" — Studio без доступа к API.
function DataService.getMode()
	if studioOffline or (IS_STUDIO and not store) then
		return "session"
	end
	return "datastore"
end

-- Состояние профиля: "loading" | "ready" | "failed" | "released" | nil.
function DataService.status(player)
	local entry = entryOf(player)
	return entry and entry.status or nil
end

-- Ждать настоящий профиль (не дольше timeout). nil — не загрузился или игрок ушёл.
function DataService.waitForProfile(player, timeout: number?)
	local limit = timeout or 60
	local waited = 0
	while player.Parent and waited < limit do
		local entry = entries[player]
		if entry and entry.status == "ready" then
			return entry.profile
		end
		if entry and entry.status == "failed" then
			return nil
		end
		waited += task.wait(0.1)
	end
	local entry = entries[player]
	return entry and entry.status == "ready" and entry.profile or nil
end

-- callback(player, profile) — профиль загружен (для уже загруженных вызовется сразу).
function DataService.onLoaded(callback)
	table.insert(loadedListeners, callback)
	for player, entry in pairs(entries) do
		if entry.status == "ready" then
			task.spawn(callback, player, entry.profile)
		end
	end
end

-- Профиль игрока. До конца загрузки — временная заглушка: она никогда
-- не сохраняется и заменится настоящим профилем, как только тот загрузится.
function DataService.get(player)
	local entry = entries[player]
	if entry and entry.profile then
		return entry.profile
	end
	local placeholder = placeholders[player]
	if not placeholder then
		placeholder = defaultProfile()
		placeholders[player] = placeholder
	end
	return placeholder
end

local function finishLoad(player, entry, profile)
	entry.profile = migrate(profile)
	reconcile(entry.profile, defaultProfile())
	validateProfile(entry.profile)
	entry.status = "ready"
	entry.nextSave = os.clock() + AUTOSAVE_INTERVAL + math.random() * 15
	placeholders[player] = nil
	-- Размер профиля в лог: лимит Roblox — 4 МБ, предупреждаём заранее (P1-8).
	local okSize, encoded = pcall(function()
		return HttpService:JSONEncode(entry.profile)
	end)
	if okSize then
		local kb = math.floor(#encoded / 1024)
		DebugState.set("Data", "ProfileKB", kb)
		if kb > 1024 then
			warn(("[DataService] профиль %s разросся: %d КБ — близко к лимиту Roblox (4 МБ)"):format(entry.key, kb))
		end
	end
	publish(player, entry.profile)
	for _, callback in ipairs(loadedListeners) do
		task.spawn(callback, player, entry.profile)
	end
end

function DataService.load(player)
	local existing = entries[player]
	if existing then
		if existing.status == "loading" then
			DataService.waitForProfile(player, 90)
		end
		return existing.profile
	end

	local key = tostring(player.UserId)
	local entry = {
		key = key,
		status = "loading",
		mode = "datastore",
		profile = nil,
		lockId = HttpService:GenerateGUID(false),
		busy = false,
		nextSave = math.huge,
	}
	entries[player] = entry

	-- Тот же игрок только что вышел с этого сервера: сначала дописываем его выход.
	local waited = 0
	while releasing[key] and waited < 30 do
		waited += task.wait(0.2)
	end

	if studioOffline or (not openStore() and IS_STUDIO) then
		entry.mode = "session"
	end

	local profile, failure = nil, nil
	if entry.mode == "datastore" then
		local errors, lockWaited = 0, 0

		-- Профиль пропал из главного стора (создали бы пустой новый), а копия
		-- в бэкап-сторе есть: восстанавливаем ДО любых новых записей.
		if openStore() then
			local exists, data = pcall(function()
				waitForBudget(4)
				return store:GetAsync(key)
			end)
			if exists and data == nil then
				local restored, restoreReason = tryRestoreFromBackup(key, entry.lockId)
				if restored then
					profile = restored
				else
					warn("[DataService] запись " .. key .. " пуста, копии нет (" .. tostring(restoreReason) .. ") — будет новый профиль")
				end
			end
		end

		while player.Parent and profile == nil do
			local result, a, _isNew
			if openStore() then
				result, a, _isNew = tryLoad(key, entry.lockId)
			else
				result, a = "error", "DataStore недоступен"
			end
			if result == "ok" then
				profile = a
				break
			elseif result == "error" and a == "запись профиля не таблица" then
				-- Битая запись: сначала копия, только потом считаем это сбоем.
				warn("[DataService] запись " .. key .. " повреждена — пробуем резервную копию")
				local restored, restoreReason = tryRestoreFromBackup(key, entry.lockId)
				if restored then
					profile = restored
					break
				end
				warn("[DataService] восстановление не удалось: " .. tostring(restoreReason))
				errors += 1
				if errors >= LOAD_ATTEMPTS then
					failure = "error"
					break
				end
				task.wait(errors * 1.5)
			elseif result == "locked" then
				if lockWaited >= LOCK_WAIT then
					failure = "locked"
					break
				end
				local pause = lockWaited < 6 and 1.5 or 3
				lockWaited += pause
				task.wait(pause)
			else
				warn(("[DataService] загрузка %s: %s"):format(key, tostring(a)))
				if IS_STUDIO then
					-- Studio без доступа к API: дальше всё в памяти сессии, без задержек.
					studioOffline = true
					entry.mode = "session"
					break
				end
				errors += 1
				if errors >= LOAD_ATTEMPTS then
					failure = "error"
					break
				end
				task.wait(errors * 1.5)
			end
		end
	end

	if entry.mode == "session" then
		local saved = sessionStore[key]
		profile = saved or defaultProfile()
		if not saved then
			warn("[DataService] Studio без доступа к API: профиль в памяти сессии (" .. player.Name .. ")")
		end
	end
	DebugState.set("Data", "DSPhase_" .. player.Name, "загружен:" .. tostring(profile ~= nil))

	-- Игрок ушёл, пока грузился: если замок уже взят — сразу его отпускаем.
	if not player.Parent then
		if profile and entry.mode == "datastore" then
			entry.profile = profile
			releasing[key] = true
			withEntry(entry, function()
				return writeEntry(entry, true)
			end)
			releasing[key] = nil
		end
		entry.status = "released"
		if entries[player] == entry then
			entries[player] = nil
		end
		placeholders[player] = nil
		return nil
	end

	if not profile then
		entry.status = "failed"
		DebugState.set("Data", "DSPhase_" .. player.Name, "СБОЙ:" .. tostring(failure))
		warn(("[DataService] профиль %s не загружен (%s): игрок отключён, данные не тронуты"):format(key, tostring(failure)))
		kick(player, failure or "error")
		return nil
	end

	finishLoad(player, entry, profile)
	return entry.profile
end

-- Сохранить профиль сейчас (замок остаётся за нами). false — не сохранено.
function DataService.save(player)
	local entry = entries[player]
	if not entry or entry.status ~= "ready" then
		return false -- не загруженный профиль не пишем никогда
	end
	local ok, reason = withEntry(entry, function()
		if entry.status ~= "ready" then
			return false, "released"
		end
		return writeEntry(entry, false)
	end)
	if not ok and reason == "stolen" then
		entry.status = "failed"
		warn("[DataService] замок профиля " .. entry.key .. " у другого сервера: сессия закрыта")
		kick(player, "stolen")
	end
	return ok == true
end

-- Внеочередное сохранение после ценных событий: босс, сундук, ежедневка
-- (PLAN_DORABOTKI P1-8). С паузой: пачка событий за секунду даёт одну запись,
-- а не пачку. При падении сервера теряется не минута автосейва, а секунды.
local saveRequests = {}
function DataService.requestSave(player, delay: number?)
	local entry = entries[player]
	if not entry or entry.status ~= "ready" then
		return
	end
	local at = os.clock() + math.clamp(delay or 5, 1, 30)
	local current = saveRequests[player]
	if current and current > os.clock() and current <= at then
		return -- уже запланировано не позже
	end
	saveRequests[player] = at
	task.delay(at - os.clock(), function()
		if saveRequests[player] ~= at then
			return -- запрос перезаписали более срочным
		end
		saveRequests[player] = nil
		if entries[player] == entry and entry.status == "ready" and player.Parent then
			if DataService.save(player) then
				task.spawn(writeBackup, entry.key, entry.profile)
			end
		end
	end)
end

-- Финальная запись и снятие замка (выход игрока или закрытие сервера).
local function release(player, entry)
	if entry.status ~= "ready" then
		return
	end
	releasing[entry.key] = true
	withEntry(entry, function()
		if entry.status ~= "ready" then
			return true
		end
		local ok, reason = writeEntry(entry, true)
		if not ok then
			warn(("[DataService] выход %s: не записано (%s)"):format(entry.key, tostring(reason)))
		else
			task.spawn(writeBackup, entry.key, entry.profile)
		end
		entry.status = "released"
		return ok
	end)
	releasing[entry.key] = nil
end

-- ===== Операции над профилем =====

function DataService.addGold(player, amount: number)
	local profile = DataService.get(player)
	profile.gold = math.max(profile.gold + amount, 0)
	publish(player, profile)
	return profile.gold
end

function DataService.spendGold(player, amount: number): boolean
	local profile = DataService.get(player)
	if profile.gold < amount then
		return false
	end
	profile.gold -= amount
	publish(player, profile)
	return true
end

function DataService.addWeapon(player, weapon)
	local profile = DataService.get(player)
	table.insert(profile.weapons, weapon)
	profile.newWeapons = (profile.newWeapons or 0) + 1
	publish(player, profile)
	return weapon
end

function DataService.addMaterial(player, materialId: string, count: number?)
	local profile = DataService.get(player)
	profile.materials[materialId] = (profile.materials[materialId] or 0) + (count or 1)
	publish(player, profile)
	return profile.materials[materialId]
end

-- Списать материал (кузнец). false — не хватает, ничего не списано.
function DataService.spendMaterial(player, materialId: string, count: number): boolean
	local profile = DataService.get(player)
	local have = profile.materials[materialId] or 0
	if count > have then
		return false
	end
	profile.materials[materialId] = have - count
	publish(player, profile)
	return true
end

function DataService.start()
	openStore()

	-- Проба API в Studio: если галка «Enable Studio Access to API Services»
	-- выключена, каждая запись падала бы на первом сохранении. Ловим сразу и
	-- печатаем понятную инструкцию вместо серой ошибки.
	if IS_STUDIO and store then
		local ok, err = pcall(function()
			store:GetAsync("__klinok_probe__")
		end)
		if not ok then
			studioOffline = true
			warn("[DataService] STUDIO: сохранения в DataStore НЕ РАБОТАЮТ — " .. tostring(err):gsub("^%s*", ""):sub(1, 110))
			warn("[DataService] ВКЛЮЧИ: Creator Hub → место → Game Settings → Security → «Enable Studio Access to API Services» (место должно быть опубликовано). До включения профили в Studio живут в памяти сессии.")
		end
	end

	Players.PlayerAdded:Connect(function(player)
		DataService.load(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local entry = entries[player]
		placeholders[player] = nil
		saveRequests[player] = nil
		DebugState.set("Data", "DSPhase_" .. player.Name, "PlayerRemoving:" .. tostring(entry and entry.status or "нет записи"))
		if not entry then
			return
		end
		if entry.status == "loading" then
			return -- DataService.load сам отпустит замок, когда догрузится
		end
		release(player, entry)
		if entries[player] == entry then
			entries[player] = nil
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(DataService.load, player)
	end

	-- Закрытие сервера (в том числе остановка теста в Studio): все записи
	-- параллельно, ждём их до конца (но не дольше CLOSE_TIMEOUT).
	game:BindToClose(function()
		closing = true
		local pending = 0
		for player, entry in pairs(entries) do
			if entry.status == "ready" then
				pending += 1
				task.spawn(function()
					release(player, entry)
					pending -= 1
				end)
			end
		end
		local started = os.clock()
		while os.clock() - started < CLOSE_TIMEOUT do
			local busy = pending > 0
			if not busy then
				for _, entry in pairs(entries) do
					if entry.busy or entry.status == "loading" then
						busy = true
						break
					end
				end
			end
			if not busy and next(releasing) == nil then
				break
			end
			task.wait(0.1)
		end
	end)

	-- Автосейв: каждый игрок раз в AUTOSAVE_INTERVAL, со сдвигом — записи не
	-- уходят пачкой. Заодно обновляется сессионный замок.
	task.spawn(function()
		while not closing do
			task.wait(5)
			local now = os.clock()
			local due = {}
			for player, entry in pairs(entries) do
				-- Без ограничения по mode: writeEntry умеет session-режим, а
				-- сессионному хранилищу тоже нужно обновляться (перезаход в той
				-- же сессии читает отсюда).
				if entry.status == "ready" and not entry.busy and now >= entry.nextSave then
					entry.nextSave = now + AUTOSAVE_INTERVAL
					table.insert(due, player)
				end
			end
			for _, player in ipairs(due) do
				if closing then
					break
				end
				task.spawn(DataService.save, player)
			end
		end
	end)

	print("[DataService] запущен, режим: " .. DataService.getMode() .. " (сессионный замок, запись через UpdateAsync)")
end

return DataService
