--!nonstrict
-- QuestService (сервер)
-- Задания Гильдии искателей (ТЗ хаба, раздел 5; список — Config.Quests).
--
-- Правила:
--   * задания идут по порядку; на доске доступно следующее несданное;
--   * взять можно одно задание за раз (у доски заданий, станция board);
--   * прогресс считает только сервер: разговоры (VillagerService.Talked) и
--     убийства (ProgressionService.Killed); считается только после взятия;
--   * выполнено → награда сразу, задание отмечается сданным.
-- Профиль: profile.quests = { active, progress, talked, done }, profile.archive.
-- Клиент получает снимок через KlinokHubNet.QuestUpdate (плашка слева).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RemoteGuard = require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("RemoteGuard"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)
local HubVillagers = require(Shared.Config.HubVillagers)
local UiNet = require(Shared.Net.UiNet)

local Systems = ServerScriptService:WaitForChild("Systems")
local DataService = require(Systems.DataService)
local EchoService = require(Systems.EchoService)
local ProgressionService = require(Systems.ProgressionService)
local StatsService = require(Systems.StatsService)
local ChestService = require(Systems.ChestService)

local QuestService = {}

local updateRemote = nil

local function questState(player)
	-- Заглушку не трогаем: задания, выданные на ней, пропали бы при загрузке
	-- настоящего профиля (DataService.get никогда не возвращает nil).
	if DataService.status(player) ~= "ready" then
		return nil, nil
	end
	local profile = DataService.get(player)
	local q = profile.quests
	if type(q) ~= "table" then
		q = {}
		profile.quests = q
	end
	q.progress = q.progress or {}
	q.talked = q.talked or {}
	q.done = q.done or {}
	profile.archive = profile.archive or {}
	return q, profile
end

-- Следующее несданное сюжетное задание по порядку (достижения вне очереди).
local function nextQuest(q)
	for _, quest in ipairs(Quests.List) do
		if quest.category ~= "achv" and not q.done[quest.id] then
			return quest
		end
	end
	return nil
end

-- Пожизненное значение счётчика достижения.
local function statValue(player, stat: string): number
	local profile = DataService.get(player)
	local stats = profile and profile.stats
	return (stats and stats[stat]) or 0
end

-- Открыт ли тир достижения: первый — всегда, следующие — когда закрыт
-- предыдущий тир того же счётчика.
local function achvOpen(q, quest)
	if (quest.tier or 1) <= 1 then
		return true
	end
	for _, other in ipairs(Quests.List) do
		if other.category == "achv" and other.stat == quest.stat and (other.tier or 1) == quest.tier - 1 then
			return q.done[other.id] == true
		end
	end
	return true
end

-- Статус одного задания для снимка и доски.
local function statusOf(player, q, quest)
	if q.done[quest.id] then
		return "done"
	end
	if quest.category == "achv" then
		if not achvOpen(q, quest) then
			return "locked"
		end
		return "tracking"
	end
	if q.active == quest.id then
		return "active"
	end
	if nextQuest(q) == quest and not q.active then
		return "available"
	end
	return "locked"
end

-- Снимок для клиента: список заданий со статусами.
function QuestService.snapshot(player)
	local q, profile = questState(player)
	if not q then
		return { list = {} }
	end
	local list = {}
	for _, quest in ipairs(Quests.List) do
		local progress
		if quest.category == "achv" then
			progress = math.min(statValue(player, quest.stat), quest.goal)
		else
			progress = math.min(q.progress[quest.id] or 0, quest.goal)
		end
		table.insert(list, {
			id = quest.id,
			title = quest.title,
			text = quest.text,
			goal = quest.goal,
			progress = progress,
			reward = Quests.rewardText(quest),
			status = statusOf(player, q, quest),
		})
	end
	return { list = list, active = q.active }
end

-- Плашка задания в HUD (PixelHudController читает атрибуты).
local function publishHud(player, snapshot)
	local active, available = nil, nil
	for _, quest in ipairs(snapshot.list) do
		if quest.status == "active" then
			active = quest
		elseif quest.status == "available" then
			available = quest
		end
	end
	if active then
		player:SetAttribute("QuestTitle", active.title)
		player:SetAttribute("QuestProgress", ("%d/%d"):format(active.progress, active.goal))
	elseif available then
		player:SetAttribute("QuestTitle", "Новое задание на доске")
		player:SetAttribute("QuestProgress", "«" .. available.title .. "»")
	else
		player:SetAttribute("QuestTitle", nil)
		player:SetAttribute("QuestProgress", nil)
	end
end

local function push(player)
	if updateRemote and player.Parent then
		local snapshot = QuestService.snapshot(player)
		publishHud(player, snapshot)
		updateRemote:FireClient(player, snapshot)
	end
end

-- Карточки награды для окна доски и для панели выполнения (иконки атласа Ui).
local function rewardCards(quest)
	local cards = {}
	local reward = quest.reward or {}
	if reward.gold then
		table.insert(cards, { icon = "coin", text = tostring(reward.gold) })
	end
	if reward.echo then
		table.insert(cards, { icon = "soul", text = tostring(reward.echo) })
	end
	if reward.dust then
		table.insert(cards, { icon = "dust", text = tostring(reward.dust) })
	end
	if reward.material and quest.material then
		table.insert(cards, { icon = "ingot", text = tostring(reward.material) })
	end
	if reward.archive then
		table.insert(cards, { icon = "scroll", text = "Архив" })
	end
	return cards
end


----------------------------------------------------------------------
-- Поручения: ежедневные и еженедельные (GDD раздел 9)
----------------------------------------------------------------------

-- Боссы этажей: их победы считает weekly-поручение «Три памяти».
local BOSS_TYPES = {
	gatekeeper = true, gardener = true, pack_leader = true,
	elder_founder = true, chief_chronicler = true, bookbinder = true,
}

local function dayIndex(): number
	return math.floor(os.time() / 86400) -- ротация в 00:00 UTC
end

local function weekIndex(): number
	return math.floor((os.time() - 345600) / 604800) -- границы — понедельник UTC
end

local function pickPool(pool, seed: number)
	local rng = Random.new(seed)
	local copy = table.clone(pool)
	for i = #copy, 2, -1 do
		local j = rng:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return { copy[1], copy[2], copy[3] }
end

-- Ротация: новый день/неделя — новые поручения. Прогресс считается от
-- «базовой линии» пожизненных счётчиков на момент ротации: награда честная,
-- даже если игрок успел набить урон до входа в игру.
local function ensurePeriods(player, q, profile)
	local stats = profile.stats or {}
	local day, week = dayIndex(), weekIndex()
	if not q.daily or q.daily.day ~= day then
		local base = {
			enemiesKilled = stats.enemiesKilled or 0,
			damageDealt = stats.damageDealt or 0,
			parries = stats.parries or 0,
			chestsOpened = stats.chestsOpened or 0,
			bossesKilled = stats.bossesKilled or 0,
		}
		local entries = {}
		for _, t in ipairs(pickPool(Quests.DailyPool, player.UserId * 7919 + day)) do
			table.insert(entries, {
				id = t.id, stat = t.stat, goal = t.goal, title = t.title, text = t.text,
				reward = t.reward, base = base, progress = 0, done = false,
			})
		end
		q.daily = { day = day, entries = entries }
	end
	if not q.weekly or q.weekly.week ~= week then
		local base = {
			enemiesKilled = stats.enemiesKilled or 0,
			damageDealt = stats.damageDealt or 0,
			parries = stats.parries or 0,
			chestsOpened = stats.chestsOpened or 0,
			bossesKilled = stats.bossesKilled or 0,
		}
		local entries = {}
		for _, t in ipairs(pickPool(Quests.WeeklyPool, player.UserId * 104729 + week)) do
			table.insert(entries, {
				id = t.id, stat = t.stat, goal = t.goal, title = t.title, text = t.text,
				reward = t.reward, base = base, progress = 0, done = false,
			})
		end
		q.weekly = { week = week, entries = entries }
	end
end

-- Прогресс поручения = пожизненный счётчик минус база на момент ротации.
local function periodProgress(q, entry, stats)
	local base = entry.base or {}
	local value = (stats[entry.stat] or 0) - (base[entry.stat] or 0)
	return math.clamp(math.floor(value), 0, entry.goal)
end

-- Закрыть созревшие поручения: награда той же панелью, что у сюжетных.
-- Этаж для сундуковых наград: сундук того этажа, ГДЕ ИГРОК, чтобы за прогресс
-- на 2 этаже не приходил сундук 5-го (идея владельца). В долине — ближайший
-- «свой» этаж: самый высокий пройденный + 1.
local function questFloor(player, profile): number
	if player:GetAttribute("Zone") == "Floor" then
		return math.clamp(player:GetAttribute("FloorId") or 1, 1, 5)
	end
	local highest = 0
	for floor, clears in pairs(profile.floorClears or {}) do
		if type(clears) == "table" and next(clears) and floor > highest then
			highest = floor
		end
	end
	return math.clamp(highest + 1, 1, 5)
end

-- Выдать сундуковые награды: reward.chest — обычные, reward.goldChest —
-- золотые. Сундуки кладутся в сумку этажа игрока и открываются в долине.
local function grantQuestChests(player, profile, reward)
	local commons, golds = reward.chest or 0, reward.goldChest or 0
	if commons <= 0 and golds <= 0 then
		return
	end
	local floor = questFloor(player, profile)
	for _ = 1, commons do
		pcall(ChestService.grant, player, floor, "common", { kind = "quest" })
	end
	for _ = 1, golds do
		pcall(ChestService.grant, player, floor, "gold", { kind = "quest" })
	end
end

local function checkPeriods(player)
	local q, profile = questState(player)
	if not q or not player.Parent then
		return
	end
	ensurePeriods(player, q, profile)
	local stats = profile.stats or {}
	local changed = false
	for _, pack in ipairs({ { pack = q.daily, label = "Ежедневное поручение" }, { pack = q.weekly, label = "Еженедельное поручение" } }) do
		for _, entry in ipairs(pack.pack and pack.pack.entries or {}) do
			if not entry.done and periodProgress(q, entry, stats) >= entry.goal then
				entry.done = true
				entry.progress = entry.goal
				changed = true
				local reward = entry.reward or {}
				pcall(function()
					if reward.gold and reward.gold > 0 then
						DataService.addGold(player, reward.gold)
					end
					if reward.echo and reward.echo > 0 then
						EchoService.grantEcho(player, reward.echo)
					end
					if reward.dust and reward.dust > 0 then
						EchoService.addDust(player, reward.dust)
					end
					grantQuestChests(player, profile, reward)
				end)
				pcall(function() DataService.requestSave(player) end)
				if updateRemote then
					local snapshot = QuestService.snapshot(player)
					updateRemote:FireClient(player, snapshot, {
						completed = entry.title,
						reward = Quests.rewardText(entry),
						cards = rewardCards(entry),
					})
				end
			end
		end
		if pack.pack and changed then
			for _, entry in ipairs(pack.pack.entries) do
				entry.progress = periodProgress(q, entry, stats)
			end
		end
	end
	if changed then
		push(player)
	end
end


local function complete(player, quest)
	local q, profile = questState(player)
	q.done[quest.id] = true
	q.active = nil
	local reward = quest.reward or {}
	-- Награды по GDD (разделы 9–10). Выдача до отправки на клиент; каждая
	-- операция в pcall — падение одной не должно оставлять квест без награды.
	local granted = {}
	local function grant(kind, fn)
		local ok, err = pcall(fn)
		if not ok then
			warn("[QuestService] награда " .. kind .. " квеста " .. quest.id .. " не выдана: " .. tostring(err))
		else
			granted[kind] = true
		end
	end
	if reward.gold and reward.gold > 0 then
		grant("gold", function() DataService.addGold(player, reward.gold) end)
	end
	if reward.echo and reward.echo > 0 then
		grant("echo", function() EchoService.grantEcho(player, reward.echo) end)
	end
	if reward.dust and reward.dust > 0 then
		grant("dust", function() EchoService.addDust(player, reward.dust) end)
	end
	if reward.material and reward.material > 0 and quest.material then
		grant("material", function() DataService.addMaterial(player, quest.material, reward.material) end)
	end
	grant("chests", function() grantQuestChests(player, profile, reward) end)
	if reward.archive then
		grant("archive", function() profile.archive[reward.archive] = true end)
	end
	-- ценные события сохраняются вне очереди (PLAN_DORABOTKI P1-8)
	pcall(function() DataService.requestSave(player) end)
	if updateRemote then
		local snapshot = QuestService.snapshot(player)
		publishHud(player, snapshot)
		updateRemote:FireClient(player, snapshot, {
			completed = quest.title,
			reward = Quests.rewardText(quest),
			cards = rewardCards(quest),
		})
	end
end

local function advance(player, quest, amount: number)
	local q = questState(player)
	if not q or q.active ~= quest.id then
		return
	end
	q.progress[quest.id] = math.min((q.progress[quest.id] or 0) + amount, quest.goal)
	if q.progress[quest.id] >= quest.goal then
		complete(player, quest)
	else
		push(player)
	end
end

local function activeQuest(player)
	local q = questState(player)
	return q and q.active and Quests.ById[q.active] or nil
end

local function onTalked(player, villagerId: string)
	local quest = activeQuest(player)
	if not quest or quest.kind ~= "talk" then
		return
	end
	local q = questState(player)
	if q.talked[villagerId] then
		return
	end
	q.talked[villagerId] = true
	advance(player, quest, 1)
end

local function onKilled(player, typeId: string?)
	local quest = activeQuest(player)
	if quest and quest.kind == "kill" and quest.enemy == typeId then
		advance(player, quest, 1)
	end
	-- боссы — пожизненный счётчик для недельного поручения «Три памяти»
	if BOSS_TYPES[typeId] then
		local q, profile = questState(player)
		if q and profile then
			profile.stats = profile.stats or {}
			profile.stats.bossesKilled = (profile.stats.bossesKilled or 0) + 1
			checkPeriods(player)
		end
	end
end

-- Взять задание (клиент присылает намерение, проверяем здесь).
local function take(player, questId)
	local q = questState(player)
	if not q then
		return { ok = false, err = "Профиль не загружен" }
	end
	local quest = Quests.ById[questId]
	if not quest then
		return { ok = false, err = "Нет такого задания" }
	end
	if quest.category == "achv" then
		return { ok = false, err = "Достижения выполняются сами" }
	end
	if q.active then
		return { ok = false, err = "Сначала закончи текущее задание" }
	end
	if q.done[quest.id] or nextQuest(q) ~= quest then
		return { ok = false, err = "Это задание сейчас не взять" }
	end
	q.active = quest.id
	q.progress[quest.id] = 0
	if quest.kind == "talk" then
		q.talked = {}
	end
	push(player)
	return { ok = true, snapshot = QuestService.snapshot(player) }
end

-- Payload станции «Доска заданий».
-- Payload станции «Архив»: сюжетные фрагменты, которые есть у игрока.
function QuestService.archivePayload(player)
	local _, profile = questState(player)
	local lines = {}
	local count = 0
	for id, fragment in pairs(Quests.ArchiveFragments) do
		if profile and profile.archive[id] then
			count += 1
			table.insert(lines, "«" .. fragment.title .. "». " .. fragment.text)
		end
	end
	if count == 0 then
		return { soon = "Фрагментов пока нет. Задания Гильдии и боссы за хребтом приносят страницы Архива." }
	end
	return { extraLines = lines }
end

----------------------------------------------------------------------
-- Окно доски заданий (UI v2): GetQuests(tab), TurnInQuest(id), TrackQuest(id).
-- Задания сдаются сами при выполнении, поэтому печать на доске у нового
-- задания — «ВЗЯТЬ» (action = "take"), а не «СДАТЬ».
----------------------------------------------------------------------

local villagerNames = {}
for _, villager in ipairs(HubVillagers) do
	villagerNames[villager.id] = villager.name
end

-- Слова заказчика: строки по ширине записки (~24 знака) в «ёлочках».
local function quoteLines(text: string)
	local lines, line = {}, ""
	for word in string.gmatch("«" .. text .. "»", "%S+") do
		if line ~= "" and utf8.len(line .. " " .. word) > 24 then
			table.insert(lines, line)
			line = word
		else
			line = line == "" and word or (line .. " " .. word)
		end
	end
	if line ~= "" then
		table.insert(lines, line)
	end
	return lines
end

local function boardQuest(q, quest, status, profile)
	local steps = {}
	if quest.kind == "talk" and status ~= "done" then
		local talked = {}
		if q.active == quest.id then
			for villagerId in pairs(q.talked) do
				table.insert(talked, villagerNames[villagerId] or villagerId)
			end
			table.sort(talked)
		end
		for i = 1, quest.goal do
			table.insert(steps, talked[i] and { text = talked[i], done = true } or { text = "Житель долины" })
		end
	end
	local rewards = rewardCards(quest)
	local progress = 0
	if status == "done" then
		progress = quest.goal
	elseif quest.category == "achv" then
		-- прогресс достижения — сам пожизненный счётчик, виден и под замком
		local stats = profile and profile.stats
		progress = math.min((stats and stats[quest.stat]) or 0, quest.goal)
	elseif status == "active" then
		progress = math.min(q.progress[quest.id] or 0, quest.goal)
	end
	return {
		id = quest.id,
		title = quest.title,
		progress = progress,
		goal = quest.goal,
		rewardIcon = rewards[1] and rewards[1].icon or "coin",
		rewardText = rewards[1] and rewards[1].text or "",
		state = status == "available" and "ready" or status,
		action = status == "available" and "take" or nil,
		tracked = status == "active",
		category = quest.category or "story",
		chapter = quest.chapter,
		giver = quest.giver,
		quote = quoteLines(quest.text),
		steps = steps,
		rewards = rewards,
	}
end

function QuestService.board(player, tab)
	local q, profile = questState(player)
	local quests = {}
	if not q then
		return { quests = quests }
	end
	if tab == "tasks" then
		-- Поручения: ежедневные и еженедельные, с таймером до обновления.
		ensurePeriods(player, q, profile)
		local stats = profile.stats or {}
		local function human(seconds: number): string
			seconds = math.max(math.floor(seconds / 60) * 60, 0)
			local hours = math.floor(seconds / 3600)
			local minutes = math.floor((seconds % 3600) / 60)
			if hours > 0 then
				return ("%d ч %02d мин"):format(hours, minutes)
			end
			return ("%d мин"):format(math.max(minutes, 1))
		end
		for _, pack in ipairs({
			{ pack = q.daily, section = "Ежедневные · обновление через " .. human((dayIndex() + 1) * 86400 - os.time()), kind = "daily" },
			{ pack = q.weekly, section = "Еженедельные · обновление через " .. human((weekIndex() + 1) * 604800 + 345600 - os.time()), kind = "weekly" },
		}) do
			for _, entry in ipairs(pack.pack and pack.pack.entries or {}) do
				local done = entry.done
				local progress = done and entry.goal or periodProgress(q, entry, stats)
				table.insert(quests, {
					id = pack.kind .. "_" .. entry.id,
					title = entry.title,
					progress = progress,
					goal = entry.goal,
					rewardIcon = (entry.reward.gold and "coin") or (entry.reward.echo and "soul") or "dust",
					rewardText = Quests.rewardText(entry),
					state = done and "done" or "tracking",
					category = "tasks",
					section = pack.section,
					giver = pack.kind == "daily" and "Гильдия · день" or "Гильдия · неделя",
					quote = quoteLines(entry.text),
					steps = {},
					rewards = rewardCards(entry),
				})
			end
		end
		return { quests = quests }
	end
	for _, quest in ipairs(Quests.List) do
		local category = quest.category or "story"
		if tab == "achv" and category ~= "achv" then
			continue
		end
		local status = statusOf(player, q, quest)
		local wanted
		if tab == "achv" then
			wanted = true -- достижения: все тиры видны сразу, с замками и прогрессом
		elseif tab == "done" then
			wanted = status == "done"
		else
			wanted = true -- сюжет: все главы видны, недоступные — под замком
		end
		if wanted then
			table.insert(quests, boardQuest(q, quest, status, profile))
		end
	end
	return { quests = quests }
end

function QuestService.start(net: Folder)
	updateRemote = Instance.new("RemoteEvent")
	updateRemote.Name = "QuestUpdate"
	updateRemote.Parent = net

	local request = Instance.new("RemoteFunction")
	request.Name = "RequestQuest"
	request.Parent = net
	local last = {}
	request.OnServerInvoke = function(player, action, questId)
		if not RemoteGuard.allow(player, "RequestQuest", action, questId) then return RemoteGuard.BUSY end
		local now = os.clock()
		if last[player] and now - last[player] < 0.4 then
			return { ok = false }
		end
		last[player] = now
		if action == "take" and typeof(questId) == "string" then
			return take(player, questId)
		elseif action == "get" then
			return { ok = true, snapshot = QuestService.snapshot(player) }
		end
		return { ok = false }
	end
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)

	ProgressionService.Killed:Connect(onKilled)

	local lastBoard = {}
	UiNet.ensure("GetQuests").OnServerInvoke = function(player, tab)
		if not RemoteGuard.allow(player, "GetQuests", tab) then return RemoteGuard.BUSY end
		return QuestService.board(player, typeof(tab) == "string" and tab or "story")
	end
	UiNet.ensure("TurnInQuest").OnServerInvoke = function(player, questId)
		if not RemoteGuard.allow(player, "TurnInQuest", questId) then return RemoteGuard.BUSY end
		local now = os.clock()
		if typeof(questId) ~= "string" or (lastBoard[player] and now - lastBoard[player] < 0.4) then
			return { ok = false }
		end
		lastBoard[player] = now
		local result = take(player, questId)
		if not result.ok then
			return { ok = false, reason = result.err }
		end
		return { ok = true, rewards = { { icon = "quest", text = "Задание взято" } } }
	end
	-- Следить можно только за текущим заданием — оно и так на плашке.
	UiNet.ensure("TrackQuest").OnServerInvoke = function()
		return { ok = true }
	end
	Players.PlayerRemoving:Connect(function(player)
		lastBoard[player] = nil
	end)

	-- Достижения закрываются сами: счётчик растёт — тир, чей порог пройден
	-- и чьи предыдущие тиры закрыты, получает награду и уходит в «сдано».
	-- Тот же сигнал двигает ежедневные/еженедельные поручения.
	StatsService.statChanged:Connect(function(player, stat)
		local q = questState(player)
		if not q or not player.Parent then
			return
		end
		for _, quest in ipairs(Quests.List) do
			if quest.category == "achv" and quest.stat == stat and not q.done[quest.id]
				and achvOpen(q, quest) and statValue(player, stat) >= quest.goal then
				complete(player, quest)
			end
		end
		checkPeriods(player)
	end)

	-- Плашка задания должна быть видна сразу после входа.
	local function onPlayerAdded(player)
		task.spawn(function()
			-- Ротация и плашка — после настоящей загрузки профиля (не заглушки).
			if not DataService.waitForProfile(player, 60) then
				return
			end
			checkPeriods(player) -- ротация дня/недели при входе
			push(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	-- Страховка достижений: statChanged-путь иногда теряется (наблюдение
	-- 15.11.2026 — connection жив, сигнал шлётся, а ветка не доходит), поэтому
	-- раз в 5 с добираем достижения, чьи пороги уже пройдены. Дёшево: у сервера
	-- ≤ десятка игроков, у Quests.List ~30 записей.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in ipairs(Players:GetPlayers()) do
				local okQ, q = pcall(questState, player)
				if not okQ then
					workspace:SetAttribute("QSweepErr", "questState: " .. tostring(q))
				elseif q and player.Parent then
					for _, quest in ipairs(Quests.List) do
						if quest.category == "achv" and not q.done[quest.id]
							and achvOpen(q, quest) and statValue(player, quest.stat) >= quest.goal then
							local okC, errC = pcall(complete, player, quest)
							if not okC then
								workspace:SetAttribute("QSweepErr", quest.id .. ": " .. tostring(errC))
							end
						end
					end
				end
			end
		end
	end)
	print(("[QuestService] заданий в линии: %d, поручений в день: %d, в неделю: %d"):format(
		#Quests.List, #Quests.DailyPool, #Quests.WeeklyPool))
end

function QuestService.bindVillagers(villagerService)
	villagerService.Talked:Connect(onTalked)
end

return QuestService
