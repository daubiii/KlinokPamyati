--!nonstrict
-- PartyService (сервер)
-- Отряды до 3 игроков, приглашения и групповые этажи (решение владельца,
-- 14.11.2026): лидер приглашает друзей (в этом сервере — баннер-приглашение,
-- в другом — сообщение через MessagingService), «Перейти к отряду» телепортирует
-- в сервер лидера (TeleportToPlaceInstance), вход лидера на этаж автоматически
-- ведёт за собой отряд, HP врагов этажа +35% за каждого лишнего игрока.
--
-- Данные игрока не трогаем: добыча и квесты у каждого свои (каждому своё).
-- Всё состояния — в памяти сервера; между серверами — только MessagingService.

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local RemoteGuard = require(script.Parent.RemoteGuard)

local PartyService = {}

local MAX_MEMBERS = 3
local INVITE_TOPIC = "KlinokPartyInvite_v1"
local PENDING_TTL = 240 -- с: сколько живёт «зов отряда» (баннер в другом сервере)
local HP_PER_EXTRA = 0.35 -- +35% HP врагам за каждого лишнего игрока на этаже

local function fixUserId(value): number?
	if typeof(value) == "number" and value == value and value > 0 then
		return math.floor(value)
	end
	if typeof(value) == "string" and value:match("^%d+$") then
		return tonumber(value)
	end
	return nil
end

local partyOf = {} -- [player] = party
local parties = {} -- [id] = party
local leaderIndex = {} -- [userId лидера] = party
local inServerInvites = {} -- [player-цель] = { leader, leaderId, leaderName, job, t }
local pendingInvites = {} -- [userId цели] = { leaderId, leaderName, job, t } (пришло MessagingService)

local Hub = nil -- HubService (для авто-входа отряда за лидером), ставится setHub

local function notify(player, text: string, kind: string?)
	local remote = Net.get("Notify")
	if remote then
		remote:FireClient(player, { kind = kind or "info", text = text })
	end
end

local function freshInvite(player)
	local invite = inServerInvites[player]
	if not invite then
		invite = pendingInvites[player.UserId]
		if invite and os.time() - (invite.t or 0) > PENDING_TTL then
			pendingInvites[player.UserId] = nil
			invite = nil
		end
	end
	return invite
end

-- Снимок отряда для окна клиента.
local function snapshotFor(party)
	local members = {}
	for _, member in ipairs(party.members) do
		table.insert(members, {
			userId = member.UserId,
			name = member.Name,
			leader = member == party.leader,
			zone = member:GetAttribute("Zone"),
			floorId = member:GetAttribute("FloorId"),
		})
	end
	return {
		id = party.id,
		leaderId = party.leader.UserId,
		leaderName = party.leader.Name,
		max = MAX_MEMBERS,
		members = members,
	}
end

local function publish(player)
	local party = partyOf[player]
	local data = nil
	if party then
		data = snapshotFor(party)
	end
	local invite = freshInvite(player)
	if invite then
		data = data or {}
		data.invite = {
			leaderId = invite.leaderId,
			leaderName = invite.leaderName,
			job = invite.job,
			cross = invite.job ~= game.JobId,
		}
	elseif data then
		data.invite = nil
	end
	player:SetAttribute("PartyCount", party and #party.members or 0)
	local remote = Net.get("PartyState")
	if remote then
		remote:FireClient(player, data)
	end
end

local function publishAll(party)
	for _, member in ipairs(party.members) do
		publish(member)
	end
end

-- ===== состав отряда =====

local function disband(party, reason: string?)
	parties[party.id] = nil
	if party.leader.Parent then
		leaderIndex[party.leader.UserId] = nil
	end
	for _, member in ipairs(party.members) do
		partyOf[member] = nil
		publish(member)
		if reason and member.Parent then
			notify(member, reason)
		end
	end
end

function PartyService.create(player)
	if partyOf[player] then
		return false, "Ты уже в отряде"
	end
	local party = { id = HttpService:GenerateGUID(false), leader = player, members = { player } }
	partyOf[player] = party
	parties[party.id] = party
	leaderIndex[player.UserId] = party
	publish(player)
	notify(player, "Отряд создан: позови друзей в меню «Отряд»")
	return true
end

-- Приглашение. Цель в этом сервере — баннер; в другом — MessagingService.
function PartyService.invite(leader, targetUserId: number)
	local party = partyOf[leader]
	if not party or party.leader ~= leader then
		return false, "Приглашает только лидер отряда"
	end
	if #party.members >= MAX_MEMBERS then
		return false, "Отряд полон (" .. MAX_MEMBERS .. ")"
	end
	if targetUserId == leader.UserId then
		return false
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if target then
		-- Цель играет на этом же сервере.
		if partyOf[target] then
			return false, "Игрок уже в отряде"
		end
		inServerInvites[target] = { leader = leader, leaderId = leader.UserId, leaderName = leader.Name, job = game.JobId, t = os.time() }
		publish(target)
		publish(leader)
		notify(target, "★ " .. leader.Name .. " зовёт тебя в отряд — открой меню «Отряд»")
		return true
	end
	-- Цель в другом сервере (или друг офлайн): проверяем дружбу и зовём через
	-- MessagingService — в его сервере всплывёт «Перейти к отряду».
	local isFriend = false
	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(leader.UserId)
	end)
	if ok and pages then
		local function scan()
			for _, friend in ipairs(pages:GetCurrentPages()) do
				if friend.Id == targetUserId then
					isFriend = true
					break
				end
			end
		end
		pcall(scan)
		-- Листание страниц — сетевой вызов: сбой не должен ронять обработчик зова.
		while ok and not isFriend and not pages:IsFinished() do
			local okPage, errPage = pcall(pages.AdvanceToNextPageAsync, pages)
			if not okPage then
				warn("[PartyService] список друзей не листается: " .. tostring(errPage))
				break
			end
			pcall(scan)
		end
	end
	if not isFriend then
		return false, "Это не твой друг в Roblox"
	end
	local sent, err = pcall(function()
		MessagingService:PublishAsync(INVITE_TOPIC, {
			kind = "invite",
			targetUserId = targetUserId,
			leaderUserId = leader.UserId,
			leaderName = leader.Name,
			job = game.JobId,
		})
	end)
	if not sent then
		warn("[PartyService] MessagingService: " .. tostring(err))
		return false, "Зов не ушёл: сеть Roblox не отвечает, попробуй ещё раз"
	end
	publish(leader)
	return true
end

function PartyService.accept(player)
	local invite = freshInvite(player)
	if not invite then
		return false, "Приглашения нет"
	end
	if invite.job ~= game.JobId then
		return false, "cross" -- отряд в другом сервере: клиент зовёт crossJoin
	end
	local leaderParty = nil
	if invite.leader and invite.leader.Parent then
		leaderParty = partyOf[invite.leader]
	elseif pendingInvites[player.UserId] then
		leaderParty = leaderIndex[invite.leaderId]
	end
	if not leaderParty or not leaderParty.leader.Parent then
		inServerInvites[player] = nil
		pendingInvites[player.UserId] = nil
		publish(player)
		return false, "Отряд уже распущен"
	end
	if partyOf[player] then
		inServerInvites[player] = nil
		publish(player)
		return false, "Ты уже в отряде"
	end
	if #leaderParty.members >= MAX_MEMBERS then
		inServerInvites[player] = nil
		pendingInvites[player.UserId] = nil
		publish(player)
		return false, "Отряд уже полон"
	end
	table.insert(leaderParty.members, player)
	partyOf[player] = leaderParty
	inServerInvites[player] = nil
	pendingInvites[player.UserId] = nil
	publishAll(leaderParty)
	notify(player, "Ты в отряде ★ " .. leaderParty.leader.Name)
	return true
end

function PartyService.decline(player)
	local had = false
	if inServerInvites[player] then
		local leader = inServerInvites[player].leader
		inServerInvites[player] = nil
		had = true
		if leader and leader.Parent then
			notify(leader, player.Name .. " отклонил приглашение")
			publish(leader)
		end
	end
	if pendingInvites[player.UserId] then
		pendingInvites[player.UserId] = nil
		had = true
	end
	publish(player)
	return had
end

-- «Перейти к отряду»: телепорт в конкретный сервер лидера.
function PartyService.crossJoin(player)
	local invite = freshInvite(player)
	if not invite then
		return false, "Приглашения нет"
	end
	if invite.job == game.JobId then
		return PartyService.accept(player)
	end
	local ok, err = pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, invite.job, player)
	end)
	if not ok then
		warn("[PartyService] телепорт к отряду: " .. tostring(err))
		return false, "Не получилось телепортироваться: сервер лидера мог закрыться. Попроси отряд позвать снова."
	end
	return true
end

-- Серверные API для FloorService (приватность забега, наблюдение, голосование).

-- Оба игрока в одном отряде?
function PartyService.inSameParty(a, b): boolean
	local party = a and partyOf[a]
	return party ~= nil and partyOf[b] == party
end

-- Отряд игрока в сыром виде (объекты Player) или nil. Только для сервера.
function PartyService.rawParty(player)
	return partyOf[player]
end

-- Смена лидера при выходе: отряд живёт, пока есть хоть один участник
-- (решение владельца: вылет лидера не роняет забег и голосование).
function PartyService.onMemberLeaving(player)
	local userId = player.UserId
	inServerInvites[player] = nil
	pendingInvites[userId] = nil
	local party = partyOf[player]
	if not party then
		return
	end
	for i, member in ipairs(party.members) do
		if member == player then
			table.remove(party.members, i)
			break
		end
	end
	partyOf[player] = nil
	if party.leader == player then
		local nextLeader = party.members[1]
		if nextLeader then
			party.leader = nextLeader
			leaderIndex[nextLeader.UserId] = party
			leaderIndex[userId] = nil
			publishAll(party)
			for _, member in ipairs(party.members) do
				if member.Parent then
					notify(member, "★ " .. player.Name .. " вышел — новый лидер: " .. nextLeader.Name)
				end
			end
			return
		end
		-- Отряд опустел.
		parties[party.id] = nil
		leaderIndex[userId] = nil
		return
	end
	publishAll(party)
end

function PartyService.leave(player)
	local party = partyOf[player]
	if not party then
		return false
	end
	for i, member in ipairs(party.members) do
		if member == player then
			table.remove(party.members, i)
			break
		end
	end
	partyOf[player] = nil
	if party.leader == player then
		disband(party, "★ Лидер " .. player.Name .. " вышел — отряд распущен")
	else
		publish(player)
		publishAll(party)
		notify(player, "Ты вышел из отряда")
	end
	return true
end

-- ===== групповой вход на этаж =====

-- Игроки на этаже floorId (для масштаба HP).
function PartyService.playersOnFloor(floorId: number)
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("Zone") == "Floor" and player:GetAttribute("FloorId") == floorId then
			count += 1
		end
	end
	return count
end

-- Множитель HP врагов этажа: +35% за каждого игрока сверх первого.
function PartyService.enemyScaleFor(floorId: number)
	local count = PartyService.playersOnFloor(floorId)
	if count <= 1 then
		return 1
	end
	return 1 + HP_PER_EXTRA * (count - 1)
end

-- Лидер вошёл на этаж: отряд в хабе следует за ним (каждому — свой loot).
function PartyService.onLeaderEnteredFloor(leader, floorId: number, difficulty: string?)
	local party = partyOf[leader]
	if not party or party.leader ~= leader then
		return
	end
	for _, member in ipairs(party.members) do
		if member ~= leader and member.Parent then
			if member:GetAttribute("Zone") == "Hub" and member:GetAttribute("ZoneBusy") ~= true then
				task.delay(1.2, function()
					-- За паузу отряд мог распасться, а игрок — уйти с хаба.
					if member.Parent and partyOf[member] == party and party.leader == leader
						and member:GetAttribute("Zone") == "Hub" and member:GetAttribute("ZoneBusy") ~= true then
						if Hub and Hub.enterFloor then
							pcall(Hub.enterFloor, member, floorId, difficulty)
						end
					end
				end)
			else
				notify(member, "★ Отряд " .. leader.Name .. " уходит на этаж " .. tostring(floorId))
			end
		end
	end
end

-- HubService ставит себя: PartyService зовёт его enterFloor для членов отряда.
function PartyService.setHub(hub)
	Hub = hub
end

-- ===== старт =====

function PartyService.start()
	Net.ensureAll()

	-- HP-масштаб: враги этажа получают +35% за каждого лишнего игрока.
	-- Хук спавна — enemy.room несёт floorId (зоны FloorService).
	local okEnemy, EnemyService = pcall(require, script.Parent:WaitForChild("EnemyService"))
	if okEnemy and EnemyService then
		table.insert(EnemyService.spawnHooks, function(enemy)
			local room = enemy.room
			if not room or type(room.floorId) ~= "number" then
				return
			end
			local scale = PartyService.enemyScaleFor(room.floorId)
			if scale <= 1 then
				return
			end
			enemy.maxHealth = math.floor(enemy.maxHealth * scale)
			enemy.health = enemy.maxHealth
			local humanoid = enemy.model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.MaxHealth = enemy.maxHealth
				humanoid.Health = enemy.maxHealth
			end
			enemy.model:SetAttribute("EnemyHealth", enemy.health)
			enemy.model:SetAttribute("EnemyMaxHealth", enemy.maxHealth)
		end)
	end

	-- Зовы отряда из других серверов. SubscribeAsync может виснуть бесконечно
	-- (Studio без сети/прокси — вечный yield), и pcall от него не спасает:
	-- подписка живёт в своей таске, чтобы не морозить весь старт (через неё
	-- цепочка бута когда-то вставала на PartyService, лишая хвост систем).
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(INVITE_TOPIC, function(message)
				local data = message.Data
				if type(data) ~= "table" or data.kind ~= "invite" then
					return
				end
				local target = Players:GetPlayerByUserId(data.targetUserId)
				if not target then
					return
				end
				if partyOf[target] then
					return -- уже в отряде на этом сервере
				end
				pendingInvites[data.targetUserId] = {
					leaderId = data.leaderUserId,
					leaderName = data.leaderName,
					job = data.job,
					t = os.time(),
				}
				publish(target)
				notify(target, "★ " .. tostring(data.leaderName) .. " зовёт тебя в отряд — открой меню «Отряд»")
			end)
		end)
		if not ok then
			warn("[PartyService] подписка MessagingService не удалась: " .. tostring(err))
		end
	end)

	-- Действия окна отряда.
	Net.get("PartyRequest").OnServerInvoke = RemoteGuard.wrap("PartyRequest", function(player, payload)
		if type(payload) ~= "table" then
			return { ok = false }
		end
		local action = payload.action
		if action == "create" then
			local ok, reason = PartyService.create(player)
			return { ok = ok, reason = reason }
		elseif action == "invite" then
			local userId = fixUserId(payload.userId)
			if not userId then
				return { ok = false, reason = "Не понял, кого звать" }
			end
			local ok, reason = PartyService.invite(player, userId)
			return { ok = ok, reason = reason }
		elseif action == "accept" then
			local ok, reason = PartyService.accept(player)
			return { ok = ok, reason = reason }
		elseif action == "decline" then
			local ok = PartyService.decline(player)
			return { ok = ok }
		elseif action == "crossJoin" then
			local ok, reason = PartyService.crossJoin(player)
			return { ok = ok, reason = reason }
		elseif action == "leave" then
			local ok = PartyService.leave(player)
			return { ok = ok }
		end
		return { ok = false, reason = "Неизвестное действие" }
	end)

	Players.PlayerRemoving:Connect(function(player)
		PartyService.onMemberLeaving(player)
	end)

	print("[PartyService] отряды готовы (до " .. MAX_MEMBERS .. ", телепорт к лидеру, HP +"
		.. math.floor(HP_PER_EXTRA * 100) .. "%/игрок)")
end

return PartyService
