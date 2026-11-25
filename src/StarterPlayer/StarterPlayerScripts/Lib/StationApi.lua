--!nonstrict
-- StationApi (клиент)
-- Единый слой данных для окон-сцен. Окна НЕ знают про ремоуты — они зовут
-- только эти функции и получают таблицы нужной формы (описаны у каждой функции).
--
-- Кузня Эха и Снаряжение уже подключены (EchoService, GetInventory/RequestEquip).
-- Сундук дня, Врата, Стена имён, Доска заданий, Лавка — подключить к существующим
-- системам игры: в каждой функции есть пометка «ПОДКЛЮЧИТЬ». Пока система не
-- подключена, функция отдаёт пример данных (MOCK), чтобы окно можно было
-- посмотреть в Studio. Флаг StationApi.Mock = false отключает примеры.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiNet = require(Shared.Net.UiNet)
local Bus = require(script.Parent.Bus)

local StationApi = {}
-- Все окна подключены к серверу (EchoService, DailyService, LeaderboardService,
-- QuestService, HubService) — примеры данных выключены.
StationApi.Mock = false

local player = Players.LocalPlayer

local warned = {}
-- true — можно отдать пример данных; false — примеры выключены (вернётся nil).
local function mock(what: string): boolean
	if not StationApi.Mock then
		return false
	end
	if not warned[what] then
		warned[what] = true
		warn(("[StationApi] %s: система не подключена, показаны примеры данных"):format(what))
	end
	return true
end

-- Вызвать RemoteFunction, если сервер её создал. Иначе nil.
local function invoke(name: string, ...)
	local remote = UiNet.find(name)
	if not remote then
		return nil
	end
	local args = table.pack(...)
	local ok, result = pcall(function()
		return remote:InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok then
		warn("[StationApi] " .. name .. ": " .. tostring(result))
		return nil
	end
	return result
end

local function legacy(name: string, ...)
	local folder = ReplicatedStorage:FindFirstChild("KlinokNet")
	local remote = folder and folder:FindFirstChild(name)
	if not remote then
		return nil
	end
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	return ok and result or nil
end

-- =========================================================================
-- КУЗНЯ ЭХА (EchoService)
-- get() → {
--   gold, dust,
--   items = { {
--     key, name, typeId, rarityId, level, maxLevel, echoes, equipped,
--     cost = { echoes, gold } | nil,          -- nil на потолке
--     now  = { damage, crit, ability },       -- числа (урон, крит в %, сила способности в %)
--     next = { damage, crit, ability } | nil,
--     socketLevel, soul (название души | nil), dustValue (пыль при переплавке)
--   } }
-- }
-- =========================================================================
StationApi.forge = {}

function StationApi.forge.get()
	local result = invoke("GetForge")
	if result then
		return result
	end
	if not mock("Кузня Эха") then
		return nil
	end
	return {
		gold = player:GetAttribute("Gold") or 124,
		dust = player:GetAttribute("EchoDust") or 18,
		items = {
			{ key = "eq", name = "Ржавый меч", typeId = "sword", rarityId = "common", level = 2, maxLevel = 5, echoes = 2, equipped = true,
				cost = { echoes = 2, gold = 80 }, now = { damage = 24, crit = 0, ability = 0 }, next = { damage = 26, crit = 1, ability = 0 },
				socketLevel = 3, dustValue = 10 },
			{ key = "w1", name = "Кинжал тени", typeId = "dagger", rarityId = "rare", level = 1, maxLevel = 6, echoes = 0,
				cost = { echoes = 1, gold = 60 }, now = { damage = 18, crit = 2, ability = 0 }, next = { damage = 20, crit = 3, ability = 0 },
				socketLevel = 3, dustValue = 7 },
			{ key = "w2", name = "Клинок стражи", typeId = "sword", rarityId = "epic", level = 2, maxLevel = 7, echoes = 1,
				cost = { echoes = 2, gold = 160 }, now = { damage = 41, crit = 5, ability = 12 }, next = { damage = 44, crit = 6, ability = 24 },
				socketLevel = 3, dustValue = 10 },
			{ key = "w3", name = "Молот кузнеца", typeId = "hammer", rarityId = "legendary", level = 1, maxLevel = 8, echoes = 3,
				cost = { echoes = 1, gold = 120 }, now = { damage = 62, crit = 6, ability = 0 }, next = { damage = 68, crit = 7, ability = 12 },
				socketLevel = 3, dustValue = 15 },
		},
	}
end

-- upgrade(key) → { ok, reason?("echo"|"gold"|"max"), levelBefore, levelAfter, unlocked = {"socket"}?, state = get() }
function StationApi.forge.upgrade(key)
	local result = invoke("RequestEchoUpgrade", key)
	if result then
		return result
	end
	if not mock("Кузня Эха") then
		return nil
	end
	return { ok = true, levelBefore = 2, levelAfter = 3, unlocked = { "socket" } }
end

-- melt(key) → { ok, dust (сколько пыли получено), reason? }
function StationApi.forge.melt(key)
	local result = invoke("RequestEchoMelt", key)
	if result then
		return result
	end
	if not mock("Кузня Эха") then
		return nil
	end
	return { ok = true, dust = 10 }
end

-- =========================================================================
-- СНАРЯЖЕНИЕ (существующие GetInventory / RequestEquip)
-- get() → { power, powerDelta, equipped = item, items = { item... }, slots = { helm, armor, amulet, ring, soul } }
--   item = { key, index, name, typeId, rarityId, level, echoes, maxLevel, isNew, equipped,
--            damage, crit, speed, ability, cost = {echoes} | nil }
-- =========================================================================
StationApi.inventory = {}

local function mapWeapon(w, equipped)
	return {
		key = equipped and "eq" or ("w" .. tostring(w.index)),
		index = w.index,
		name = w.name,
		typeId = w.typeId,
		rarityId = w.rarityId,
		level = w.level or (1 + math.floor((w.sharpening or 0) / 2)),
		echoes = w.echoes or 0,
		maxLevel = w.maxLevel or 5,
		isNew = w.isNew,
		equipped = equipped,
		damage = w.damage or w.rating,
		crit = w.crit or 0,
		speed = w.speed or 1,
		ability = w.ability,
		cost = w.cost,
	}
end

function StationApi.inventory.get()
	local gear = invoke("GetGear")
	if gear then
		return gear
	end
	local result = legacy("GetInventory")
	if result and result.ok then
		local items = {}
		local equipped = mapWeapon(result.equipped, true)
		table.insert(items, equipped)
		for _, w in ipairs(result.weapons or {}) do
			table.insert(items, mapWeapon(w, false))
		end
		return {
			power = result.power or (equipped.damage or 0) * 10,
			powerDelta = result.powerDelta,
			equipped = equipped,
			items = items,
			slots = result.slots or {},
			newArmor = result.newArmor or 0,
		}
	end
	if not mock("Снаряжение") then
		return nil
	end
	local eq = { key = "eq", name = "Ржавый меч", typeId = "sword", rarityId = "common", level = 2, echoes = 2, maxLevel = 5, equipped = true,
		damage = 26, crit = 2, speed = 1, cost = { echoes = 2 } }
	return {
		power = 412,
		powerDelta = 36,
		equipped = eq,
		newArmor = 2,
		slots = {},
		items = {
			eq,
			{ key = "w1", index = 1, name = "Кинжал тени", typeId = "dagger", rarityId = "rare", level = 1, echoes = 0, maxLevel = 6, isNew = true, damage = 18, crit = 4, speed = 1.3 },
			{ key = "w2", index = 2, name = "Клинок стражи", typeId = "sword", rarityId = "epic", level = 2, echoes = 1, maxLevel = 7, damage = 41, crit = 5, speed = 1, ability = "Раскол" },
			{ key = "w3", index = 3, name = "Молот кузнеца", typeId = "hammer", rarityId = "legendary", level = 1, echoes = 3, maxLevel = 8, damage = 62, crit = 6, speed = 0.8, ability = "Вихрь" },
			{ key = "w4", index = 4, name = "Меч искателя", typeId = "sword", rarityId = "rare", level = 3, echoes = 0, maxLevel = 6, damage = 33, crit = 4, speed = 1 },
			{ key = "w5", index = 5, name = "Посох эха", typeId = "staff", rarityId = "mythic", level = 1, echoes = 0, maxLevel = 9, isNew = true, damage = 58, crit = 8, speed = 0.9 },
		},
	}
end

function StationApi.inventory.equip(item)
	if not item then
		return nil
	end
	-- Броня: ключ "a<N>" (ArmorService, KlinokUiNet.RequestEquipArmor).
	if item.kind == "armor" then
		local result = invoke("RequestEquipArmor", item.key)
		return result and result.ok and result or nil
	end
	if not item.index then
		return nil
	end
	local result = legacy("RequestEquip", item.index)
	-- Отказ (оружие чужого класса и т. п.) — как неудача, а не как успех.
	if type(result) == "table" and result.ok == false then
		return nil
	end
	return result
end

-- Вплавить эхо в броню (только в долине). → { ok, levelBefore, levelAfter } | { ok = false, reason, need }
function StationApi.inventory.upgradeArmor(item)
	if not item or item.kind ~= "armor" then
		return nil
	end
	return invoke("RequestArmorUpgrade", item.key)
end

-- =========================================================================
-- КНИГА ГЕРОЯ (InventoryService): сумка, аксессуары, герой, архив.
-- get() → {
--   gear = <inventory.get()>,                     -- оружие, броня, души, «Сила»
--   bag = { { key, id, kind("bag"|"material"), name, category, icon, rarityId, count,
--             desc, useText, usable, quick, canQuick, group, cooldown } },
--   accessories = { { key, uid, id, kind = "accessory", name, slot, slotName, rarityId,
--                     icon, stats, statsText, desc, equipped, salvage } },
--   equippedAccessories = { amulet = item?, ring = item? }, quickItem, cooldowns,
--   hero = { classId, className, level, maxLevel, xp, xpNext, rows = { {label, value, hint} },
--            classes = { {id, name, ready, current, blurb, health, armor, ...} },
--            chronicle = { {label, value, icon} } },
--   archive = { fragments = { {id, title, text?, owned} }, owned, total },
-- }
-- use(id) / useQuick() → { ok, count, text } | { ok = false, reason("cooldown"|"full"|"charges-full"|"empty"), left }
-- equipAccessory(uid) / unequipAccessory(slot) / salvage(uid) → { ok, dust? } ; setQuick(id|nil) → { ok }
-- =========================================================================
StationApi.character = {}

function StationApi.character.get()
	local result = invoke("GetCharacter")
	if result then
		if not result.gear then
			result.gear = StationApi.inventory.get()
		end
		return result
	end
	-- Сервер без InventoryService: книга работает как прежний инвентарь.
	local gear = StationApi.inventory.get()
	if not gear then
		return nil
	end
	return {
		gear = gear,
		bag = {},
		accessories = {},
		equippedAccessories = {},
		cooldowns = {},
		hero = nil,
		archive = { fragments = {}, owned = 0, total = 0 },
		legacy = true,
	}
end

function StationApi.character.use(id: string)
	return invoke("UseBagItem", id)
end

function StationApi.character.useQuick()
	return invoke("UseQuickItem")
end

function StationApi.character.setQuick(id: string?)
	return invoke("SetQuickItem", id)
end

function StationApi.character.equipAccessory(uid: number)
	return invoke("EquipAccessory", uid)
end

function StationApi.character.unequipAccessory(slot: string)
	return invoke("UnequipAccessory", slot)
end

function StationApi.character.salvage(uid: number)
	return invoke("SalvageAccessory", uid)
end

-- =========================================================================
-- СУНДУК ДНЯ — ПОДКЛЮЧИТЬ к существующей системе ежедневной награды.
-- get() → { streak (1..7, текущий день), claimedToday, resetIn (сек до сгорания серии),
--           days = { {icon, text} x7 }, today = {icon, text, extra?}, tomorrow = {icon, text} }
-- claim() → { ok, rewards = { {icon, big, small, kind("gold"|"mem")} }, streak }
-- =========================================================================
StationApi.chest = {}

function StationApi.chest.get()
	local result = invoke("GetDaily")
	if result then
		return result
	end
	if not mock("Сундук дня") then
		return nil
	end
	return {
		streak = 4,
		claimedToday = false,
		resetIn = 23 * 3600 + 41 * 60 + 7,
		days = {
			{ icon = "coin", text = "50" }, { icon = "coin", text = "80" }, { icon = "soul", text = "1 эхо" }, { icon = "coin", text = "150" },
			{ icon = "dust", text = "20 пыли" }, { icon = "coin", text = "250" }, { icon = "chest", text = "Великий" },
		},
		today = { icon = "coin", text = "150 золота", extra = "+ шанс эха" },
		tomorrow = { icon = "dust", text = "20 пыли" },
	}
end

function StationApi.chest.claim()
	local result = invoke("ClaimDaily")
	if result then
		return result
	end
	if not mock("Сундук дня") then
		return nil
	end
	return { ok = true, streak = 4, rewards = { { icon = "coin", big = "150", small = "золота", kind = "gold" }, { icon = "soul", big = "+1", small = "эхо меча", kind = "mem" } } }
end

-- =========================================================================
-- ВРАТА ПЕЧАТЕЙ — ПОДКЛЮЧИТЬ к существующему выбору этажа.
-- get() → { worlds = { { id, numeral, name, sub, state("open"|"done"|"locked"), desc = {строки}, keeper,
--                        record, floors, recordRatio, rewards = {иконки}, theme, hidden,
--                        difficulties = { {id, name, locked, passed} }, cleared = {id сложностей}, bossDefeated } },
--           difficulties = { {id, name, locked} }, selectedDifficulty,
--           chests = { f<этаж>_<common|gold> = N }, chestsOpened, className, level, unlockDifficulty }
-- enter(worldId, difficultyId) → { ok, reason? }
-- =========================================================================
StationApi.gate = {}

function StationApi.gate.get()
	local result = invoke("GetWorlds")
	if result then
		return result
	end
	if not mock("Врата Печатей") then
		return nil
	end
	-- Мок для Studio без сервера: двор и сады открыты, псарни — следующие, дальше «???».
	local function diffs(open, passed)
		return {
			{ id = "normal", name = "Обычный", locked = open < 1, passed = passed >= 1 },
			{ id = "hard", name = "Ненормальный", locked = open < 2, passed = passed >= 2 },
			{ id = "impossible", name = "Невозможный", locked = open < 3, passed = passed >= 3 },
		}
	end
	local player = game:GetService("Players").LocalPlayer
	return {
		worlds = {
			{ id = 1, numeral = "I", name = "Привратный двор", sub = "Руины входа, память о страже", theme = "Руины входа, память о страже",
				state = "open", keeper = "Привратник", record = "пройден: Ненормальный", recordRatio = 1,
				difficulties = diffs(3, 2), cleared = { "normal", "hard" }, bossDefeated = true },
			{ id = 2, numeral = "II", name = "Затопленные сады", sub = "Мирные дни, ставшие гнилью", theme = "Мирные дни, ставшие гнилью",
				state = "open", keeper = "Садовница", record = "комната 3/7", recordRatio = 3 / 7,
				difficulties = diffs(1, 0), cleared = {}, bossDefeated = false },
			{ id = 3, numeral = "III", name = "Псарни охоты", sub = "Пройди «Затопленные сады» на сложности «Ненормальный»", theme = "Королевская охота",
				state = "locked", keeper = "Королевский ловчий", difficulties = diffs(0, 0), cleared = {} },
			{ id = 4, numeral = "IV", name = "???", sub = "Печать III", state = "locked", hidden = true, keeper = "Старший литейщик", difficulties = diffs(0, 0), cleared = {} },
			{ id = 5, numeral = "V", name = "???", sub = "Печать IV", state = "locked", hidden = true, keeper = "Главный хронист", difficulties = diffs(0, 0), cleared = {} },
		},
		difficulties = diffs(1, 0),
		selectedDifficulty = "normal",
		chests = { f1_common = 2, f1_gold = 1, f2_common = 1 },
		chestsOpened = 5,
		className = player and player:GetAttribute("ClassName") or "warrior",
		level = player and player:GetAttribute("Level") or 5,
		unlockDifficulty = "Ненормальный",
	}
end

function StationApi.gate.enter(worldId, difficultyId)
	local result = invoke("EnterWorld", worldId, difficultyId)
	if result then
		if result.ok then
			-- уход во Врата: рассыпание на кубики рисует HubController
			Bus.emit("gateEntered", { world = worldId, difficulty = difficultyId })
		end
		return result
	end
	if not mock("Врата Печатей") then
		return nil
	end
	return { ok = false, reason = "mock" }
end

-- =========================================================================
-- СТЕНА ЗАБЫТЫХ ИМЁН — ПОДКЛЮЧИТЬ к существующей таблице лидеров.
-- get(tab: "deep"|"souls"|"week") → { rows = { {rank, name, floor, value} } (до 7), me = {rank, name, floor, value, hint?} }
-- =========================================================================
StationApi.wall = {}

function StationApi.wall.get(tab: string)
	local result = invoke("GetLeaderboard", tab)
	if result then
		return result
	end
	if not mock("Стена имён") then
		return nil
	end
	return {
		rows = {
			{ rank = 1, name = "Морозный_Клинок", floor = 5, value = 1204 }, { rank = 2, name = "nightfang", floor = 4, value = 980 },
			{ rank = 3, name = "Grimbolt", floor = 4, value = 911 }, { rank = 4, name = "Лиса_Аш", floor = 3, value = 640 },
			{ rank = 5, name = "kot_v_sapogah", floor = 3, value = 598 }, { rank = 6, name = "ironhand", floor = 2, value = 402 },
			{ rank = 7, name = "Ветер", floor = 2, value = 377 },
		},
		me = { rank = 23, name = player.Name, floor = 2, value = 120, hint = "ещё 1 до 20-го!" },
	}
end

-- =========================================================================
-- ДОСКА ЗАДАНИЙ — ПОДКЛЮЧИТЬ к квестам (Quests.luau / DataService).
-- get(tab: "story"|"tasks"|"done") → { quests = { {
--     id, title, progress, goal, rewardIcon, rewardText, state("active"|"ready"|"done"), tracked,
--     chapter, quote = {строки}, giver, steps = { {text, done} }, rewards = { {icon, text} } } } }
-- turnIn(id) → { ok, rewards = { {icon, text} } }   track(id) → { ok }
-- =========================================================================
StationApi.board = {}

function StationApi.board.get(tab: string)
	local result = invoke("GetQuests", tab)
	if result then
		return result
	end
	if not mock("Доска заданий") then
		return nil
	end
	return {
		quests = {
			{ id = "voices", title = "Голоса долины", progress = 2, goal = 5, rewardIcon = "coin", rewardText = "100", state = "active", tracked = true,
				chapter = "Сюжет · глава 1", giver = "Ольгерд", quote = { "«Искатель из горы?", "Оттуда не приходят.", "Пройдись, послушай", "людей.»" },
				steps = { { text = "Марта", done = true }, { text = "Тарас", done = true }, { text = "Дед Ефим" }, { text = "Ивга" }, { text = "Сенька" } },
				rewards = { { icon = "coin", text = "100" }, { icon = "xp", text = "+50 оп." } } },
			{ id = "rust", title = "Ржавая стража", progress = 10, goal = 10, rewardIcon = "soul", rewardText = "1 эхо", state = "ready",
				chapter = "Сюжет · глава 1", giver = "Ольгерд", quote = { "«Десять стражей.", "Хорошая работа.»" }, steps = {},
				rewards = { { icon = "soul", text = "1 эхо" } } },
			{ id = "key", title = "Ключ от ворот", progress = 0, goal = 1, rewardIcon = "scroll", rewardText = "Архив", state = "active",
				chapter = "Сюжет · глава 2", giver = "Феофан", quote = { "«Привратник держит", "ключ. Принеси его.»" }, steps = {},
				rewards = { { icon = "scroll", text = "Архив" } } },
			{ id = "bell", title = "Звон колокола", progress = 0, goal = 1, rewardIcon = "coin", rewardText = "60", state = "active",
				chapter = "Поручение", giver = "Дед Ефим", quote = { "«Помоги старику,", "колокол тяжёлый.»" }, steps = {},
				rewards = { { icon = "coin", text = "60" } } },
		},
	}
end

function StationApi.board.turnIn(id)
	local result = invoke("TurnInQuest", id)
	if result then
		return result
	end
	if not mock("Доска заданий") then
		return nil
	end
	return { ok = true, rewards = { { icon = "soul", text = "1 эхо" } } }
end

function StationApi.board.track(id)
	local result = invoke("TrackQuest", id)
	if result then
		return result
	end
	return { ok = true }
end

-- =========================================================================
-- ЛАВКА ОСКОЛКОВ — ПОДКЛЮЧИТЬ к магазину (товары заполним позже).
-- get() → { items = { {id, name, rarity, currency("coin"|"dust"), price, tag?} } (до 4), restockIn (сек), line }
-- buy(id) → { ok, reason?("gold"|"dust"|"soldout"), reward = {icon, text} }
-- =========================================================================
StationApi.shop = {}

function StationApi.shop.get()
	local result = invoke("GetShop")
	if result then
		return result
	end
	if not mock("Лавка") then
		return nil
	end
	return {
		items = {
			{ id = "shard_common", name = "Серый осколок", rarity = "common", currency = "coin", price = 50 },
			{ id = "shard_rare", name = "Зелёный осколок", rarity = "rare", currency = "coin", price = 120, tag = "-20%" },
			{ id = "shard_epic", name = "Фиолетовый", rarity = "epic", currency = "dust", price = 40 },
			{ id = "shard_legendary", name = "Золотой", rarity = "legendary", currency = "dust", price = 90, tag = "ХИТ" },
		},
		restockIn = 2 * 3600 + 14 * 60 + 33,
		line = { "Осколки из-за хребта.", "Бери, пока помнят." },
	}
end

function StationApi.shop.buy(id)
	local result = invoke("BuyShopItem", id)
	if result then
		return result
	end
	if not mock("Лавка") then
		return nil
	end
	return { ok = true, reward = { icon = "soul", text = "Осколок" } }
end

-- =========================================================================
-- ДРЕВО ТАЛАНТОВ (TalentService) — вкладка «Древо» книги героя.
-- get() → { classId, className, level, points, spent, free, byBranch = {[branchId]=n},
--           learned = {[nodeId]=true}, resets, resetCost, canReset, hubOnly, gold }
-- learn(id) → { ok, reason?, text?, state }
-- reset()   → { ok, reason?, text?, cost?, state }
-- Без сервера (превью в Studio без Play) — nil: окно рисует пустое древо.
-- =========================================================================
StationApi.talents = {}

function StationApi.talents.get()
	return invoke("TalentsGet")
end

function StationApi.talents.learn(id: string)
	return invoke("TalentsLearn", id)
end

function StationApi.talents.reset()
	return invoke("TalentsReset")
end

-- =========================================================================
-- СУНДУКИ ЭТАЖЕЙ (ChestService) — лежат в сумке, открываются в долине.
-- get()     → { stacks = { {key, floor, grade, name, text, floorName, boss, count, …} }, total, canOpen }
-- open(key) → { ok, reason?, text?, …находка (как LootService.rollContents), chest, remaining, total }
-- =========================================================================
StationApi.chests = {}

function StationApi.chests.get()
	return invoke("ChestsGet")
end

function StationApi.chests.open(key: string)
	return invoke("ChestsOpen", key)
end

return StationApi
