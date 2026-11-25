--!strict
--[[
	RemoteGuard — общий фильтр входящих запросов клиента.

	Зачем: в мультиплеере любой клиент может дёргать RemoteFunction/RemoteEvent
	сколько угодно раз и с любыми аргументами (читеры так и делают). Один такой
	клиент может заспамить сервер и подпортить игру всем остальным.

	Что делает:
	  • частота — «ведро жетонов» на игрока и ключ: обычные запросы — 20 подряд,
	    дальше 10 в секунду; экономика (покупки, улучшения, сундуки) — 8 подряд,
	    дальше 4 в секунду; плюс общее ведро на игрока (80 подряд, 40/с).
	    Честный игрок до этих цифр не дотягивается даже при бешеном клике;
	  • аргументы — строки длиннее 200 символов, таблицы глубже 3 уровней
	    или больше 64 записей, NaN/бесконечность в числах и векторах — запрос
	    молча отбрасывается (NaN в позиции или направлении ломает математику удара).
	Никого не кикаем: игрок с лагом не должен вылетать. В Output пишем не чаще
	раза в минуту на игрока.

	Использование:
	  remote.OnServerInvoke = RemoteGuard.wrap("Ключ", handler)
	  remote.OnServerInvoke = function(player, a, b)
	      if not RemoteGuard.allow(player, "Ключ", a, b) then return RemoteGuard.BUSY end
	      ...
	  event.OnServerEvent:Connect(RemoteGuard.wrapEvent("Ключ", handler))
]]

local Players = game:GetService("Players")

local RemoteGuard = {}

-- Ответ RemoteFunction на отброшенный запрос: клиенты и так проверяют ok/err.
RemoteGuard.BUSY = table.freeze({ ok = false, reason = "rate", err = "Слишком часто" })

type Limit = { capacity: number, refill: number }

local DEFAULT: Limit = { capacity = 20, refill = 10 }
local ECONOMY: Limit = { capacity = 8, refill = 4 }
local GLOBAL: Limit = { capacity = 80, refill = 40 }
local GLOBAL_KEY = "\0all"

local LIMITS: { [string]: Limit } = {
	BuyShopItem = ECONOMY,
	RequestEchoUpgrade = ECONOMY,
	RequestEchoMelt = ECONOMY,
	RequestArmorUpgrade = ECONOMY,
	SalvageAccessory = ECONOMY,
	TalentsLearn = ECONOMY,
	TalentsReset = ECONOMY,
	ClaimDaily = ECONOMY,
	TurnInQuest = ECONOMY,
	ChestsOpen = ECONOMY,
	RequestSharpen = ECONOMY,
}

local MAX_STRING = 200
local MAX_DEPTH = 3
local MAX_ENTRIES = 64
local WARN_EVERY = 60

type Bucket = { tokens: number, t: number }

local buckets: { [Player]: { [string]: Bucket } } = setmetatable({}, { __mode = "k" }) :: any
local lastWarn: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function clean(value: any, depth: number, budget: { n: number }): boolean
	local kind = typeof(value)
	if kind == "string" then
		return #value <= MAX_STRING
	elseif kind == "number" then
		return finite(value)
	elseif kind == "Vector3" then
		return finite(value.X) and finite(value.Y) and finite(value.Z)
	elseif kind == "Vector2" then
		return finite(value.X) and finite(value.Y)
	elseif kind == "CFrame" then
		local p = value.Position
		local l = value.LookVector
		return finite(p.X) and finite(p.Y) and finite(p.Z) and finite(l.X) and finite(l.Y) and finite(l.Z)
	elseif kind == "table" then
		if depth >= MAX_DEPTH then
			return false
		end
		for k, v in value do
			budget.n += 1
			if budget.n > MAX_ENTRIES then
				return false
			end
			if not clean(k, depth + 1, budget) or not clean(v, depth + 1, budget) then
				return false
			end
		end
		return true
	end
	-- nil, boolean, Instance, EnumItem и прочее пропускаем как есть:
	-- типы каждый обработчик проверяет сам.
	return true
end

local function take(player: Player, key: string, limit: Limit): boolean
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local now = os.clock()
	local bucket = perPlayer[key]
	if not bucket then
		bucket = { tokens = limit.capacity, t = now }
		perPlayer[key] = bucket
	end
	bucket.tokens = math.min(limit.capacity, bucket.tokens + (now - bucket.t) * limit.refill)
	bucket.t = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function report(player: Player, key: string, why: string)
	local now = os.clock()
	local last = lastWarn[player]
	if last and now - last < WARN_EVERY then
		return
	end
	lastWarn[player] = now
	warn(string.format("[RemoteGuard] %s: запрос %s отброшен (%s)", player.Name, key, why))
end

-- true, если запрос можно обрабатывать. Аргументы — всё, что прислал клиент.
function RemoteGuard.allow(player: any, key: string, ...: any): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	if not take(player, GLOBAL_KEY, GLOBAL) or not take(player, key, LIMITS[key] or DEFAULT) then
		report(player, key, "слишком часто")
		return false
	end
	local budget = { n = 0 }
	for i = 1, select("#", ...) do
		if not clean((select(i, ...)), 0, budget) then
			report(player, key, "подозрительные аргументы")
			return false
		end
	end
	return true
end

-- Обёртка для OnServerInvoke: при отказе вернёт BUSY и не вызовет обработчик.
function RemoteGuard.wrap(key: string, handler: (...any) -> ...any): (...any) -> ...any
	return function(player, ...)
		if not RemoteGuard.allow(player, key, ...) then
			return RemoteGuard.BUSY
		end
		return handler(player, ...)
	end
end

-- Обёртка для OnServerEvent:Connect.
function RemoteGuard.wrapEvent(key: string, handler: (...any) -> ()): (...any) -> ()
	return function(player, ...)
		if RemoteGuard.allow(player, key, ...) then
			handler(player, ...)
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
	lastWarn[player] = nil
end)

return RemoteGuard
