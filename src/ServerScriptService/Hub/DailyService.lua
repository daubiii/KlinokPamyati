--!nonstrict
-- DailyService (сервер)
-- Сундук дня: серия из 7 дней (правила и награды — Config.Daily).
-- Профиль: profile.daily = { streak = последний забранный день серии (0..7),
-- lastDay = номер суток UTC, когда забирали }.
-- Ремоуты (папка KlinokUiNet): GetDaily, ClaimDaily — форма описана в
-- StarterPlayerScripts/Lib/StationApi (раздел «Сундук дня»).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RemoteGuard = require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("RemoteGuard"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Daily = require(Shared.Config.Daily)
local UiNet = require(Shared.Net.UiNet)

local Systems = ServerScriptService:WaitForChild("Systems")
local DataService = require(Systems.DataService)
local EchoService = require(Systems.EchoService)

local DailyService = {}

local hub = nil -- HubService: проверка «рядом с сундуком»
local busy = {}

local function today(): number
	return os.time() // Daily.SecondsPerDay
end

local function dailyState(player)
	local profile = DataService.get(player)
	local d = profile.daily
	if type(d) ~= "table" then
		d = { streak = 0, lastDay = nil }
		profile.daily = d
	end
	return d
end

-- Какой день серии сегодня (1..7) и забран ли он уже.
local function position(d): (number, boolean)
	local now = today()
	if d.lastDay == now then
		return math.max(d.streak, 1), true
	end
	if d.lastDay == now - 1 and d.streak < Daily.Days then
		return d.streak + 1, false
	end
	-- пропуск (или круг из 7 дней пройден) — серия заново
	return 1, false
end

local function card(reward)
	return { icon = reward.icon, text = reward.text }
end

function DailyService.state(player)
	local d = dailyState(player)
	local day, claimed = position(d)
	local days = {}
	for i = 1, Daily.Days do
		days[i] = card(Daily.Rewards[i])
	end
	local reward = Daily.Rewards[day]
	local parts = string.split(Daily.describe(reward), " + ")
	local tomorrowDay = day % Daily.Days + 1
	return {
		streak = day,
		claimedToday = claimed,
		-- и «следующий дар», и «серия сгорит» — в полночь UTC
		resetIn = (today() + 1) * Daily.SecondsPerDay - os.time(),
		days = days,
		today = {
			icon = reward.icon,
			text = parts[1],
			extra = #parts > 1 and ("+ " .. table.concat(parts, " + ", 2)) or nil,
		},
		tomorrow = card(Daily.Rewards[tomorrowDay]),
	}
end

function DailyService.claim(player)
	if busy[player] then
		return { ok = false, reason = "busy" }
	end
	if hub and not hub.nearStation(player, "chest") then
		return { ok = false, reason = "too-far" }
	end
	local d = dailyState(player)
	local day, claimed = position(d)
	if claimed then
		return { ok = false, reason = "claimed" }
	end
	-- Награда выдаётся ДО фиксации дня (PLAN_DORABOTKI P1-7): если выдача
	-- упадёт, день не будет засчитан и игрок сможет забрать дар повторно.
	-- busy снимается в любом исходе — раньше ошибка залипала до перезахода.
	busy[player] = true
	local reward = Daily.Rewards[day]
	local rewards = {}
	local ok, err = pcall(function()
		if reward.gold then
			DataService.addGold(player, reward.gold)
			table.insert(rewards, { icon = "coin", big = tostring(reward.gold), small = "золота", kind = "gold" })
		end
		if reward.echo then
			local extraDust = EchoService.grantEcho(player, reward.echo)
			local weapon = DataService.get(player).equippedWeapon
			table.insert(rewards, { icon = "soul", big = "+" .. reward.echo, small = "эхо: " .. (weapon.name or ""), kind = "mem" })
			if extraDust > 0 then
				table.insert(rewards, { icon = "dust", big = "+" .. extraDust, small = "пыли (эхо сверх)", kind = "mem" })
			end
		end
		if reward.dust then
			EchoService.addDust(player, reward.dust)
			table.insert(rewards, { icon = "dust", big = "+" .. reward.dust, small = "пыли эха", kind = "mem" })
		end
	end)
	if ok then
		d.streak = day
		d.lastDay = today()
		player:SetAttribute("DailyClaimedDay", d.lastDay)
		-- ценные события сохраняются вне очереди, а не раз в минуту
		pcall(function() DataService.requestSave(player) end)
	else
		warn("[DailyService] награда дня " .. tostring(day) .. " не выдана: " .. tostring(err))
	end
	busy[player] = nil
	if not ok then
		return { ok = false, reason = "error" }
	end
	return { ok = true, streak = day, rewards = rewards }
end

function DailyService.start(hubService)
	hub = hubService
	UiNet.ensure("GetDaily").OnServerInvoke = RemoteGuard.wrap("GetDaily", DailyService.state)
	UiNet.ensure("ClaimDaily").OnServerInvoke = RemoteGuard.wrap("ClaimDaily", DailyService.claim)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return DailyService
