--!nonstrict
-- ChestService (сервер) — сундуки этажей v3 (04.11.2026)
--
-- На этаже сундук не открывается: после зачистки секретной комнаты /
-- ответвления / мини-босса (обычный) или босса (золотой) FloorService зовёт
-- ChestService.grant — сундук кладётся в профиль (profile.chests[ключ] = N)
-- каждому герою на этаже, а клиент получает «ChestGranted»: сундук
-- проявляется в комнате, летит к герою и падает в сумку (ChestFlyController),
-- сверху лента «ПОЛУЧЕН СУНДУК».
--
-- Открыть можно только вне этажа (Zone ~= "Floor"): сумка → «Сундуки» →
-- ОТКРЫТЬ (ChestsOpen) → LootService.rollContents → сцена раскрытия
-- «Клинок читает память» (ChestRevealController).
--
-- Ключ стопки — "f<этаж>_<common|gold>", названия и тексты — Config/Chests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteGuard = require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("RemoteGuard"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Chests = require(Shared.Config.Chests)
local Net = require(Shared.Net.Net)
local UiNet = require(Shared.Net.UiNet)
local DebugState = require(Shared.Net.DebugState)

local DataService = require(script.Parent.DataService)
local LootService = require(script.Parent.LootService)

local ChestService = {}

local OPEN_COOLDOWN = 0.6
local lastOpen = {} -- [player] = os.clock()
local grantSeq = 0

local function storeOf(player)
	local profile = DataService.get(player)
	if type(profile.chests) ~= "table" then
		profile.chests = {}
	end
	return profile.chests, profile
end

-- profile.chestTiers[ключ] = { {minRarity, epicChance}, ... } — очередь гарантий стопки.
local function tiersOf(profile, key: string)
	if type(profile.chestTiers) ~= "table" then
		profile.chestTiers = {}
	end
	profile.chestTiers[key] = profile.chestTiers[key] or {}
	return profile.chestTiers[key]
end

function ChestService.publish(player)
	local store = storeOf(player)
	player:SetAttribute("ChestsStored", Chests.total(store))
end

function ChestService.canOpen(player): boolean
	return player:GetAttribute("Zone") ~= "Floor"
end

-- Выдать сундук герою. info: { position = Vector3?, kind = "boss" | "secret" | ..., silent = bool }
function ChestService.grant(player, floorId, grade: string, info)
	info = info or {}
	local store, profile = storeOf(player)
	grade = grade == "gold" and "gold" or "common"
	floorId = Chests.clampFloor(floorId)
	local count = Chests.add(store, floorId, grade, 1)
	-- Гарантия сундука (minRarity / epicChance из Config.FloorN.Chests): стопка
	-- в сумке общая, поэтому гарантии лежат очередью рядом и снимаются при открытии.
	if type(info.tier) == "table" and (info.tier.minRarity or info.tier.epicChance) then
		local tiers = tiersOf(profile, Chests.key(floorId, grade))
		table.insert(tiers, { minRarity = info.tier.minRarity, epicChance = info.tier.epicChance })
	end
	profile.stats = profile.stats or {}
	profile.stats.chestsEarned = (profile.stats.chestsEarned or 0) + 1
	ChestService.publish(player)
	grantSeq += 1
	local chest = Chests.info(floorId, grade)
	chest.count = count
	chest.total = Chests.total(store)
	chest.position = info.position
	chest.chestKind = info.kind
	chest.seq = grantSeq
	if not info.silent then
		local remote = Net.get("ChestGranted")
		if remote then
			remote:FireClient(player, chest)
		end
	end
	DebugState.set("Chests", "LastGranted", chest.name)
	return chest
end

-- Выдать всем героям из списка (этаж: floorPlayers()).
function ChestService.grantAll(players, floorId, grade: string, info)
	local granted = {}
	for _, player in ipairs(players) do
		local ok, chest = pcall(ChestService.grant, player, floorId, grade, info)
		if ok then
			granted[player] = chest
		else
			warn("[ChestService] сундук не выдан: " .. tostring(chest))
		end
	end
	return granted
end

function ChestService.state(player)
	local store = storeOf(player)
	return {
		stacks = Chests.stacks(store),
		total = Chests.total(store),
		canOpen = ChestService.canOpen(player),
	}
end

-- Открыть один сундук стопки. Только в долине (вне этажа).
function ChestService.open(player, key)
	if typeof(key) ~= "string" then
		return { ok = false, reason = "bad-request" }
	end
	if not ChestService.canOpen(player) then
		return { ok = false, reason = "on-floor", text = "Сундуки открываются в долине" }
	end
	local t = os.clock()
	if lastOpen[player] and t - lastOpen[player] < OPEN_COOLDOWN then
		return { ok = false, reason = "busy" }
	end
	local floorId, grade = Chests.parse(key)
	if not floorId then
		return { ok = false, reason = "bad-key" }
	end
	local store = storeOf(player)
	if not Chests.take(store, key) then
		return { ok = false, reason = "empty", text = "Таких сундуков нет" }
	end
	lastOpen[player] = t
	local _, profile = storeOf(player)
	local tiers = tiersOf(profile, key)
	local tier = table.remove(tiers, 1)
	-- Лишние гарантии (стопку открыли/почистили отладкой) не копятся.
	while #tiers > (store[key] or 0) do
		table.remove(tiers, 1)
	end
	local ok, payload = pcall(LootService.rollContents, player, floorId, grade == "gold", { quiet = true, tier = tier })
	if not ok then
		if tier then
			table.insert(tiers, 1, tier)
		end
		Chests.add(store, floorId, grade, 1)
		ChestService.publish(player)
		warn("[ChestService] сундук не открылся: " .. tostring(payload))
		return { ok = false, reason = "error", text = "Сундук не поддался — попробуйте ещё раз" }
	end
	ChestService.publish(player)
	payload.chest = Chests.info(floorId, grade)
	payload.remaining = store[key] or 0
	payload.total = Chests.total(store)
	payload.ok = true
	DebugState.set("Chests", "LastOpened", payload.chest.name)
	return payload
end

-- Отладка: очистить все сундуки.
function ChestService.clear(player)
	local _, profile = storeOf(player)
	profile.chests = {}
	profile.chestTiers = {}
	ChestService.publish(player)
end

function ChestService.start()
	Net.ensureAll()
	UiNet.ensure("ChestsGet").OnServerInvoke = function(player)
		if not RemoteGuard.allow(player, "ChestsGet") then return RemoteGuard.BUSY end
		return ChestService.state(player)
	end
	UiNet.ensure("ChestsOpen").OnServerInvoke = function(player, key)
		if not RemoteGuard.allow(player, "ChestsOpen", key) then return RemoteGuard.BUSY end
		return ChestService.open(player, key)
	end
	local function onPlayer(player)
		task.spawn(function()
			-- Публикуем после настоящей загрузки профиля (не заглушки).
			if DataService.waitForProfile(player, 60) and player.Parent then
				ChestService.publish(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastOpen[player] = nil
	end)
	print("[ChestService] сундуки этажей v3: в сумку, открытие в долине")
end

return ChestService
