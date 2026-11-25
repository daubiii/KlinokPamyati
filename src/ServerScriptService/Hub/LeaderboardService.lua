--!nonstrict
-- LeaderboardService (сервер)
-- Стена забытых имён: глобальная таблица лидеров (решение владельца
-- 23.10.2026). Три вкладки окна WallWindow:
--   deep  — «Глубже всех»: дальше всех прошёл (этаж × 100 + комната);
--   souls — «Больше душ»: поглощено душ за всё время (= побеждённые враги);
--   week  — «За неделю»: то же за текущую неделю (с понедельника, UTC).
--
-- Хранение: OrderedDataStore на вкладку (week — свой на каждую неделю) +
-- обычный DataStore с именем и этажом игрока (строки других вкладок
-- показывают этаж). Пишем раз в минуту и при выходе, читаем топ раз в
-- минуту. Без доступа к DataStore (Studio без API) — рейтинг среди тех,
-- кто сейчас на сервере.
--
-- Профиль: profile.records = { floor, room }, profile.weekly = { week, souls }.
-- Ремоут (папка KlinokUiNet): GetLeaderboard(tab) → { rows[≤7], me }.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RemoteGuard = require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("RemoteGuard"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiNet = require(Shared.Net.UiNet)

local Systems = ServerScriptService:WaitForChild("Systems")
local DataService = require(Systems.DataService)
local ProgressionService = require(Systems.ProgressionService)

local LeaderboardService = {}

local ROWS = 7
local PAGE = 50 -- сколько мест читаем, чтобы найти «твоё» место
local REFRESH = 60
local INFO_TTL = 300
local WEEK = 7 * 86400
local MONDAY = 4 * 86400 -- 1 января 1970 — четверг

local TABS = { "deep", "souls", "week" }

local stores = {} -- [storeName] = OrderedDataStore | false
local infoStore = nil
local available = true
local cache = {} -- [tab] = { at, week, entries = { {userId, score} } }
local infoCache = {} -- [userId] = { at, name, floor }
local written = {} -- [player] = { [tab] = score }

local function weekId(): number
	return (os.time() - MONDAY) // WEEK
end

local function storeName(tab: string): string
	if tab == "week" then
		return "KlinokWall_week_" .. weekId()
	end
	return "KlinokWall_" .. tab
end

local function ordered(tab: string)
	if not available then
		return nil
	end
	local name = storeName(tab)
	if stores[name] == nil then
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
		stores[name] = ok and store or false
		if not ok then
			available = false
			warn("[LeaderboardService] OrderedDataStore недоступен, рейтинг по серверу: " .. tostring(store))
		end
	end
	return stores[name] or nil
end

local function records(player)
	local profile = DataService.get(player)
	profile.records = type(profile.records) == "table" and profile.records or { floor = 0, room = 0 }
	local weekly = profile.weekly
	if type(weekly) ~= "table" or weekly.week ~= weekId() then
		weekly = { week = weekId(), souls = 0 }
		profile.weekly = weekly
	end
	return profile, profile.records, weekly
end

local function score(player, tab: string): number
	local profile, best, weekly = records(player)
	if tab == "deep" then
		return (best.floor or 0) * 100 + (best.room or 0)
	elseif tab == "souls" then
		return profile.stats and profile.stats.enemiesKilled or 0
	end
	return weekly.souls or 0
end

local function bestFloor(player): number
	local _, best = records(player)
	return math.max(best.floor or 0, 1)
end

-- Прогресс по комнатам: FloorService ставит RoomIndex и FloorId.
local function trackRooms(player)
	player:GetAttributeChangedSignal("RoomIndex"):Connect(function()
		local room = player:GetAttribute("RoomIndex")
		local floor = player:GetAttribute("FloorId") or 1
		if typeof(room) ~= "number" then
			return
		end
		local _, best = records(player)
		if floor * 100 + room > (best.floor or 0) * 100 + (best.room or 0) then
			best.floor, best.room = floor, room
		end
	end)
end

local function onKilled(player)
	local _, _, weekly = records(player)
	weekly.souls += 1
end

-- ===== запись =====
local function push(player)
	if not available or player.UserId <= 0 then
		return
	end
	written[player] = written[player] or {}
	local changed = false
	for _, tab in ipairs(TABS) do
		local value = score(player, tab)
		if value > 0 and written[player][tab] ~= value then
			local store = ordered(tab)
			if store then
				local ok = pcall(store.SetAsync, store, tostring(player.UserId), value)
				if ok then
					written[player][tab] = value
					changed = true
				end
			end
		end
	end
	if changed then
		infoStore = infoStore or DataStoreService:GetDataStore("KlinokWall_info")
		pcall(infoStore.SetAsync, infoStore, tostring(player.UserId), { n = player.DisplayName, f = bestFloor(player) })
	end
end

-- ===== чтение =====
local function info(userId: number)
	local hit = infoCache[userId]
	if hit and os.clock() - hit.at < INFO_TTL then
		return hit
	end
	local live = Players:GetPlayerByUserId(userId)
	local entry = { at = os.clock(), name = live and live.DisplayName or ("#" .. userId), floor = live and bestFloor(live) or 1 }
	if not live and infoStore then
		local ok, data = pcall(infoStore.GetAsync, infoStore, tostring(userId))
		if ok and type(data) == "table" then
			entry.name = data.n or entry.name
			entry.floor = data.f or entry.floor
		end
	end
	infoCache[userId] = entry
	return entry
end

local function top(tab: string)
	local hit = cache[tab]
	if hit and os.clock() - hit.at < REFRESH and (tab ~= "week" or hit.week == weekId()) then
		return hit.entries
	end
	local entries = nil
	local store = ordered(tab)
	if store then
		local ok, pages = pcall(store.GetSortedAsync, store, false, PAGE)
		if ok then
			entries = {}
			for _, item in ipairs(pages:GetCurrentPage()) do
				table.insert(entries, { userId = tonumber(item.key), score = item.value })
			end
		end
	end
	if not entries then
		-- без DataStore: рейтинг тех, кто сейчас на сервере
		entries = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local value = score(player, tab)
			if value > 0 then
				table.insert(entries, { userId = player.UserId, score = value, player = player })
			end
		end
		table.sort(entries, function(a, b)
			return a.score > b.score
		end)
		return entries -- не кэшируем: и так дёшево
	end
	cache[tab] = { at = os.clock(), week = weekId(), entries = entries }
	return entries
end

local function display(tab: string, value: number)
	if tab == "deep" then
		return "комн. " .. tostring(value % 100)
	end
	return value
end

local function rowFloor(tab: string, value: number, floor: number): number
	return tab == "deep" and math.max(value // 100, 1) or floor
end

function LeaderboardService.get(player, tab)
	if typeof(tab) ~= "string" or not table.find(TABS, tab) then
		tab = "deep"
	end
	local entries = top(tab)
	local mine = score(player, tab)
	local rows = {}
	local myRank = nil
	for rank, entry in ipairs(entries) do
		local isMe = entry.userId == player.UserId
		-- своё значение свежее, чем записанное минуту назад
		local value = isMe and math.max(entry.score, mine) or entry.score
		if isMe then
			myRank = rank
		end
		if rank <= ROWS then
			local who = entry.player and { name = entry.player.DisplayName, floor = bestFloor(entry.player) } or info(entry.userId)
			table.insert(rows, {
				rank = rank,
				name = who.name,
				floor = rowFloor(tab, value, who.floor),
				value = display(tab, value),
			})
		end
	end

	local me = { rank = myRank or (#entries >= PAGE and (PAGE .. "+") or (#entries + 1)), name = player.DisplayName, floor = rowFloor(tab, mine, bestFloor(player)), value = display(tab, mine) }
	-- «ещё N до …» — зацепка до следующего места (по душам; для глубины — комнаты)
	-- в таблице — до места выше; вне таблицы — до последней строки на стене
	local place = myRank and myRank - 1 or math.min(ROWS, #entries)
	local target = place >= 1 and entries[place] or nil
	if target and target.score > mine then
		local gap = target.score - mine
		if tab == "deep" then
			me.hint = gap >= 100 and ("до %d-го места — следующий этаж"):format(place) or ("ещё %d комн. до %d-го"):format(gap, place)
		else
			me.hint = ("ещё %d до %d-го!"):format(gap + 1, place)
		end
	end
	return { rows = rows, me = me }
end

function LeaderboardService.start()
	local ok = pcall(function()
		infoStore = DataStoreService:GetDataStore("KlinokWall_info")
	end)
	available = ok and DataService.getMode() ~= "session"

	ProgressionService.Killed:Connect(onKilled)
	Players.PlayerAdded:Connect(trackRooms)
	for _, player in ipairs(Players:GetPlayers()) do
		trackRooms(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		task.spawn(push, player)
		task.delay(1, function()
			written[player] = nil
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(REFRESH)
			for _, player in ipairs(Players:GetPlayers()) do
				push(player)
			end
		end
	end)

	UiNet.ensure("GetLeaderboard").OnServerInvoke = RemoteGuard.wrap("GetLeaderboard", LeaderboardService.get)
	print("[LeaderboardService] Стена имён: " .. (available and "глобальная" or "по серверу (нет DataStore)"))
end

return LeaderboardService
