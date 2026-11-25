--!nonstrict
-- FloorBoonService (сервер) — «Дары Эха»: выбор карточки с остановкой времени
--
-- FloorService зовёт roomCleared(...) после каждой пройденной боевой комнаты.
-- Каждые FloorBoons.EveryRooms комнат:
--   1. время этажа останавливается: враги замирают (EnemyService.freeze), их
--      снаряды гаснут, герои неуязвимы и стоят (якорь, атрибут BoonPause);
--   2. каждому герою на этаже — свои 3 карточки (BoonOffer kind = "offer");
--   3. выбор (BoonPick) сразу даёт дар: статы, лечение, души;
--   4. когда выбрали все (в группе — не позже GroupTimeout, дальше случайная) —
--      время идёт дальше (kind = "resume"), враги ещё ResumeGrace не бьют.
-- Если за одну комнату набралось два выбора — второй показывается сразу после первого.
-- Дары живут до конца этажа: FloorBoonState.reset при входе на этаж и новом забеге.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteGuard = require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("RemoteGuard"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FloorBoons = require(Shared.Config.FloorBoons)
local Net = require(Shared.Net.Net)

local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)
local FloorBoonState = require(script.Parent.FloorBoonState)
local ProgressionService = require(script.Parent.ProgressionService)
local ProjectileService = require(script.Parent.ProjectileService)

local FloorBoonService = {}

local rng = Random.new()

-- Активная пауза на этаже: [folder] = { players = {player=true}, offers = {[player]={cards}}, queued = n, token }
local sessions = {}
-- [player] = folder активной паузы
local sessionOf = {}

local function remote()
	return Net.get("BoonOffer")
end

local function send(player, payload)
	local r = remote()
	if r and player.Parent then
		r:FireClient(player, payload)
	end
end

-- Папки, где стоят враги паузы: папка этажа и враги отладки (команда spawn
-- кладёт их в Workspace.DebugEnemies — без неё они бегали во время выбора).
local function frozenFolders(folder)
	local list = { folder }
	local debugFolder = game:GetService("Workspace"):FindFirstChild("DebugEnemies")
	if debugFolder then
		table.insert(list, debugFolder)
	end
	return list
end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function holdPlayer(player, on: boolean)
	player:SetAttribute("BoonPause", on or nil)
	local root = rootOf(player)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.Anchored = on
	end
end

-- Описание карточки для клиента: редкость, сколько уже взято, было → станет.
local function cardPayload(player, item)
	local card = FloorBoons.ById[item.id]
	local before = FloorBoonState.total(player, item.id)
	local after
	if card.kind == "mult" then
		after = math.max(before, 1) * card.values[item.rarity]
	else
		after = before + card.values[item.rarity]
	end
	if card.cap then
		after = math.min(after, card.cap)
	end
	return {
		id = item.id,
		rarity = item.rarity,
		count = FloorBoonState.count(player, item.id),
		before = before,
		after = after,
	}
end

-- Мгновенное действие карточки: лечение и заряды, души.
local function applyInstant(player, item)
	local card = FloorBoons.ById[item.id]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if item.id == "second_wind" and humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.Health + humanoid.MaxHealth * card.values[item.rarity], humanoid.MaxHealth)
		player:SetAttribute("HealCharges", (player:GetAttribute("HealCharges") or 0) + card.extra[item.rarity])
	elseif item.id == "soul_surge" then
		local profile = DataService.get(player)
		local stacks = profile.soulStacks or 0
		local target = math.floor(stacks * card.values[item.rarity] + 0.5)
		ProgressionService.addStacks(player, target - stacks)
	end
end

local resume

local function finish(folder, player, choice)
	local session = sessions[folder]
	if not session or not session.offers[player] then
		return
	end
	local offer = session.offers[player]
	session.offers[player] = nil
	local item = offer.cards[choice] or offer.cards[rng:NextInteger(1, #offer.cards)]
	if item then
		FloorBoonState.add(player, item.id, item.rarity)
		-- Здоровье, скорость, предел душ пересчитываются сразу; «Крепкое сердце»
		-- добавляет максимум, текущее здоровье сохраняет долю.
		ProgressionService.applyLevel(player)
		applyInstant(player, item)
		print(("[FloorBoons] %s: %s (%s)"):format(player.Name, item.id, FloorBoons.Rarities[item.rarity].id))
	end
	local left = 0
	for other in pairs(session.offers) do
		if other.Parent then
			left += 1
		end
	end
	send(player, { kind = "picked", id = item and item.id, rarity = item and item.rarity, auto = choice == nil, waiting = left })
	if left == 0 then
		resume(folder)
	end
end

local function openRound(folder, players)
	local session = sessions[folder]
	session.token += 1
	local token = session.token
	session.round += 1
	local alone = #players <= 1
	local timeout = alone and FloorBoons.SoloTimeout or FloorBoons.GroupTimeout
	for _, player in ipairs(players) do
		local cards = FloorBoons.roll(rng, FloorBoons.Choices, FloorBoonState.owned(player))
		if #cards > 0 then
			session.offers[player] = { cards = cards }
			local payload = {}
			for _, item in ipairs(cards) do
				table.insert(payload, cardPayload(player, item))
			end
			send(player, {
				kind = "offer",
				cards = payload,
				timeout = timeout,
				round = session.round,
				queued = session.queued,
				players = #players,
			})
		end
	end
	if next(session.offers) == nil then
		resume(folder)
		return
	end
	if timeout then
		task.delay(timeout + 0.5, function()
			local current = sessions[folder]
			if current and current.token == token then
				for player in pairs(table.clone(current.offers)) do
					finish(folder, player, nil)
				end
			end
		end)
	end
end

function resume(folder)
	local session = sessions[folder]
	if not session then
		return
	end
	-- Ещё один выбор в очереди (две пачки комнат подряд) — не размораживаем.
	if session.queued > 0 then
		session.queued -= 1
		local players = {}
		for player in pairs(session.players) do
			if player.Parent and sessionOf[player] == folder then
				table.insert(players, player)
			end
		end
		task.delay(0.6, function()
			if sessions[folder] == session then
				openRound(folder, players)
			end
		end)
		return
	end
	sessions[folder] = nil
	for player in pairs(session.players) do
		if sessionOf[player] == folder then
			sessionOf[player] = nil
		end
		if player.Parent then
			holdPlayer(player, false)
			send(player, { kind = "resume" })
		end
	end
	for _, f in ipairs(session.frozen or { folder }) do
		EnemyService.unfreeze(f, FloorBoons.ResumeGrace)
	end
end

-- Комната пройдена. floor = { key, folder, players, rooms } — rooms: сколько
-- боевых комнат пройдено на этаже (считает FloorService).
function FloorBoonService.roomCleared(floor)
	local every = FloorBoons.EveryRooms
	if not floor.folder or floor.rooms <= 0 or floor.rooms % every ~= 0 then
		return false
	end
	local players = {}
	for _, player in ipairs(floor.players or {}) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			table.insert(players, player)
		end
	end
	if #players == 0 then
		return false
	end
	local folder = floor.folder
	local session = sessions[folder]
	if session then
		session.queued += 1
		return true
	end
	session = { players = {}, offers = {}, queued = 0, token = 0, round = 0 }
	sessions[folder] = session
	for _, player in ipairs(players) do
		session.players[player] = true
		sessionOf[player] = folder
		holdPlayer(player, true)
		send(player, { kind = "stop" })
	end
	session.frozen = frozenFolders(folder)
	for _, f in ipairs(session.frozen) do
		EnemyService.freeze(f)
		ProjectileService.clearWithin(f)
	end
	-- Короткая пауза на эффект остановки времени, потом карточки.
	task.delay(0.9, function()
		if sessions[folder] == session then
			openRound(folder, players)
		end
	end)
	return true
end

-- Сброс даров: вход на этаж, новый забег, возврат в долину.
function FloorBoonService.reset(player, floorId)
	FloorBoonState.reset(player, floorId)
	local folder = sessionOf[player]
	sessionOf[player] = nil
	local session = folder and sessions[folder]
	if session then
		session.players[player] = nil
		if session.offers[player] then
			session.offers[player] = nil
			if next(session.offers) == nil then
				resume(folder)
			end
		end
	end
	holdPlayer(player, false)
	send(player, { kind = "resume" })
	if player.Parent then
		ProgressionService.applyLevel(player)
	end
end

-- Сброс паузы этажа (этаж перезапущен): все свободны, враги — по новой.
function FloorBoonService.abort(folder)
	local session = sessions[folder]
	if not session then
		return
	end
	session.queued = 0
	for player in pairs(session.offers) do
		session.offers[player] = nil
	end
	resume(folder)
end

-- Отладка (команда boon): выбор сейчас, count — сколько выборов подряд.
function FloorBoonService.debugOffer(player, count: number?): boolean
	local floorId = player:GetAttribute("FloorId") or 1
	local folder = nil
	for _, child in ipairs(game:GetService("Workspace"):GetChildren()) do
		if child:IsA("Folder") and child.Name == (floorId == 1 and "Floor" or "Floor" .. floorId) and child:GetAttribute("FloorId") == floorId then
			folder = child
			break
		end
	end
	if not folder or player:GetAttribute("Zone") ~= "Floor" then
		return false
	end
	for _ = 1, count or 1 do
		FloorBoonService.roomCleared({ folder = folder, players = { player }, rooms = FloorBoons.EveryRooms })
	end
	return true
end

function FloorBoonService.floorOf(player)
	return FloorBoonState.floorOf(player)
end

function FloorBoonService.isPaused(player): boolean
	return sessionOf[player] ~= nil
end

function FloorBoonService.start()
	Net.get("BoonPick").OnServerEvent:Connect(function(player, index)
		if not RemoteGuard.allow(player, "BoonPick", index) then return end
		local folder = sessionOf[player]
		if not folder or type(index) ~= "number" then
			return
		end
		local session = sessions[folder]
		local offer = session and session.offers[player]
		if not offer then
			return
		end
		index = math.floor(index)
		if index < 1 or index > #offer.cards then
			return
		end
		finish(folder, player, index)
	end)

	-- «Кровавая жажда»: лечит долю нанесённого урона.
	EnemyService.hooks.dealt = function(attacker, taken, enemy)
		if typeof(attacker) ~= "Instance" or not attacker:IsA("Player") then
			return
		end
		local share = FloorBoonState.lifesteal(attacker)
		if share <= 0 then
			return
		end
		local humanoid = attacker.Character and attacker.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = math.min(humanoid.Health + taken * share, humanoid.MaxHealth)
		end
	end

	-- Персонаж появился заново во время паузы — тоже стоит.
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			if sessionOf[player] then
				task.defer(holdPlayer, player, true)
			end
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function()
			if sessionOf[player] then
				task.defer(holdPlayer, player, true)
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		local folder = sessionOf[player]
		sessionOf[player] = nil
		local session = folder and sessions[folder]
		if session then
			session.players[player] = nil
			if session.offers[player] then
				session.offers[player] = nil
				if next(session.offers) == nil then
					resume(folder)
				end
			end
		end
	end)
end

return FloorBoonService
