--!nonstrict
-- FloorService (сервер) — этажи забега
-- Этаж 1 v2 «Привратный двор» (Config/Floor1v2) и этаж 2 «Затопленные сады»
-- (Config/Floor2, 29.10.2026). Каждый этаж — свой экземпляр (createFloor):
-- своя карта (Floor1Map / Floor2Map), папка в Workspace («Floor» / «Floor2»),
-- зоны, враги, игроки. Игрок попадает на этаж по атрибуту FloorId (врата хаба).
-- Особое этажа 2 (шлюзы, заросшие стены, гнилые доски, статуи-стрелки…) —
-- в Systems/Floor2World через хуки (build, step, zoneActivated, zoneCleared,
-- zoneReset, resetPlayer).
--
-- Этаж 1: арены с решётками, улицы с засадами, ответвления с сундуками, два
-- мини-босса с ключами, удержание в Зале лебёдки, костры, Привратник со сценой ключей.
--
-- Геометрия — готовая карта Workspace.Floor1Map (меши + коллизии, собирается в
-- Studio из пакета карты). Живые части карты (решётки, доски моста, баррикады)
-- — FloorMap. Мини-боссы — MiniBossService.
--
-- Внешний интерфейс прежний: setLoot, start, build, enterRun, state, runStats,
-- currentRoom. События FloorEvent прежние (room, wave, roomCleared, chestReady,
-- playerDied, bossIntro, newRun, roomReset, campfire) + новые: keyDrop,
-- keyPicked, keyScene, hold, bannerPlanted/bannerFell, chainBolt, trapsPlaced,
-- trapSprung, arbalestTop, bridgeBreak, horn.
--
-- Этаж обслуживает только игроков с атрибутом Zone == "Floor" (врата хаба).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local RemoteGuard = require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("RemoteGuard"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Enemies = require(Shared.Config.Enemies)
local Rooms = require(Shared.Config.Rooms)
local Floor1v2 = require(Shared.Config.Floor1v2)
local Floor2 = require(Shared.Config.Floor2)
local Floor3 = require(Shared.Config.Floor3)
local Floor4 = require(Shared.Config.Floor4)
local Floor5 = require(Shared.Config.Floor5)
local Chests = require(Shared.Config.Chests)
local Net = require(Shared.Net.Net)
local DebugState = require(Shared.Net.DebugState)

local FloorMap = require(script.Parent.FloorMap)
local Floor2World = require(script.Parent.Floor2World)
local Floor3World = require(script.Parent.Floor3World)
local Floor4World = require(script.Parent.Floor4World)
local Floor5World = require(script.Parent.Floor5World)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)
local MiniBossService = require(script.Parent.MiniBossService)
local MotionGuard = require(script.Parent.MotionGuard)

-- PartyService грузится лениво: Bootstrap стартует его позже FloorService.
local function partyModule()
	local module = script.Parent:FindFirstChild("PartyService")
	if not module then
		return nil
	end
	local ok, result = pcall(require, module)
	return ok and result or nil
end
local ProgressionService = require(script.Parent.ProgressionService)
local ChestService = require(script.Parent.ChestService)
local FloorBoonService = require(script.Parent.FloorBoonService)

local FloorService = {}

-- Один этаж: Config — Floor1v2 / Floor2, World — модуль особого этажа (хуки) или nil.
local function createFloor(Config, World)
	local F = {}
	F.Config = Config
	local Map = Config.FloorId == 1 and FloorMap or FloorMap.new(Config.MapName, Config)
	local hooks: { [string]: (...any) -> ...any } = {}
	local ctx = {}

	local state = {
		folder = nil, -- Workspace.Floor: враги, сундуки, атрибуты для HUD
		rooms = {}, -- зоны (имя «rooms» оставлено для совместимости)
		playerRoom = {}, -- [player] = индекс зоны
		run = {},
		floorCleared = false,
		chests = {},
		loot = nil,
		used = false,
		keyDrops = {}, -- { position, key, zone, part }
		bounds = {}, -- [player] = { safe, outSince }: выход за карту
		boonRooms = 0, -- пройдено боевых комнат («Дары Эха» каждые FloorBoons.EveryRooms)
		-- Многопользовательский забег (один этаж на сервер = одна группа):
		difficulty = nil, -- сложность текущего забега (фиксируется первым вошедшим)
		runStartedAt = 0, -- когда группа зашла: присоединиться можно только в начале
		newRunVotes = {}, -- [player] = true: голоса за «новый забег» после босса
	}

	-- Присоединиться к чужому забегу можно только в первые JOIN_WINDOW секунд и пока
	-- не зачищена ни одна комната: иначе новичок пришёл бы на готовое (или наоборот,
	-- пересборка этажа для него сбросила бы всех).
	local JOIN_WINDOW = 90
	local DIFFICULTY_NAMES = { normal = "Обычный", abnormal = "Ненормальный", impossible = "Невозможный" }

	function F.setLoot(loot)
		state.loot = loot
	end

	local function now(): number
		return Workspace:GetServerTimeNow()
	end

	-- Игрок на этом этаже: зона «Floor» и номер этажа (FloorId из хаба; нет — этаж 1).
	local function onFloor(player): boolean
		return player:GetAttribute("Zone") == "Floor" and (player:GetAttribute("FloorId") or 1) == Config.FloorId
	end

	-- События этажа — только его игрокам (на другом этаже свой интерфейс).
	local function fire(payload, onlyPlayer)
		local remote = Net.get("FloorEvent")
		if not remote then
			return
		end
		if onlyPlayer then
			remote:FireClient(onlyPlayer, payload)
		else
			for _, player in ipairs(Players:GetPlayers()) do
				if onFloor(player) then
					remote:FireClient(player, payload)
				end
			end
		end
	end

	local function floorPlayers(except)
		local list = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= except and onFloor(player) then
				table.insert(list, player)
			end
		end
		return list
	end

	-- Голосование конца забега объявлено заранее: finishFloor (босс, выше по
	-- файлу) и resolveEndVote (ниже) оба его зовут.
	local startEndVote

	local function rootOf(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and humanoid and humanoid.Health > 0 then
			return root, humanoid
		end
		return nil, nil
	end

	local function publish()
		local folder = state.folder
		if not folder then
			return
		end
		local cleared = 0
		for _, zone in ipairs(state.rooms) do
			if zone.state == "cleared" then
				cleared += 1
			end
		end
		folder:SetAttribute("RoomCount", #state.rooms)
		folder:SetAttribute("RoomsCleared", cleared)
		folder:SetAttribute("FloorCleared", state.floorCleared)
	end

	-- ===== Решётки зоны =====

	local function setGates(zone, which: string, open: boolean, instant: boolean?)
		for _, name in ipairs((zone.cfg.gates or {})[which] or {}) do
			Map.setGate(name, open, instant)
		end
	end

	local function setSeals(zone, on: boolean)
		for _, box in ipairs(zone.cfg.seals or {}) do
			Map.setSeal(box, on)
		end
	end

	local function lockZone(zone)
		setGates(zone, "entry", false)
		setGates(zone, "exit", false)
		setSeals(zone, true)
		fire({ kind = "zoneLock", room = zone.index, locked = true })
	end

	local function unlockZone(zone)
		setGates(zone, "entry", true)
		setGates(zone, "exit", true)
		setSeals(zone, false)
		fire({ kind = "zoneLock", room = zone.index, locked = false })
	end

	-- Начальное состояние всех решёток: вход открыт, выход закрыт (у арен и
	-- мини-боссов), у Арбалетчицы решётка пандуса открыта.
	local function initialGateStates()
		local states = {}
		for _, cfg in ipairs(Config.Zones) do
			for which, names in pairs(cfg.gates or {}) do
				for _, name in ipairs(names) do
					states[name] = which == "entry" or which == "phase"
				end
			end
		end
		return states
	end

	-- ===== Награды =====

	local function creditKill(attacker, enemyStats)
		if not attacker or enemyStats.role == "object" then
			return
		end
		ProgressionService.rewardKill(attacker, enemyStats)
		local run = state.run[attacker]
		if run then
			run.kills += 1
		end
	end

	-- ===== Враги =====

	local zoneAdvance

	-- Сложность забега: выбор у врат (атрибут FloorDifficulty). Раньше враги
	-- всегда создавались «обычными», и «Ненормальный»/«Невозможный» ничего
	-- не меняли. Игроков на этаже несколько — берём самую высокую.
	local DIFFICULTY_RANK = { normal = 1, abnormal = 2, impossible = 3 }
	local function runDifficulty(): string
		if state.difficulty and DIFFICULTY_RANK[state.difficulty] then
			return state.difficulty -- зафиксирована на весь забег
		end
		local best, rank = "normal", 1
		for _, player in ipairs(floorPlayers()) do
			local id = player:GetAttribute("FloorDifficulty")
			local r = DIFFICULTY_RANK[id or ""]
			if r and r > rank then
				best, rank = id, r
			end
		end
		return best
	end

	local function spawnEnemy(zone, typeId: string, position: Vector3, extra)
		local stats = Enemies.stats(typeId, runDifficulty())
		local options = {
			parent = state.folder,
			bounds = zone.bounds,
			obstacles = {},
			room = zone,
		}
		if extra then
			for key, value in pairs(extra) do
				options[key] = value
			end
			if extra.bounds == false then
				options.bounds = nil
			end
		end
		local enemy = EnemyService.spawn(stats, position, options)
		table.insert(zone.enemies, enemy)
		if not (extra and extra.noCredit) then
			enemy.onDeath = function(dead, attacker)
				creditKill(attacker, dead.stats)
				if zone.onEnemyDeath then
					zone.onEnemyDeath(dead, attacker)
				end
			end
		end
		return enemy, stats
	end

	local function aliveIn(zone, ignoreObjects: boolean?)
		local alive = 0
		for _, enemy in ipairs(zone.enemies) do
			if enemy.alive and not (ignoreObjects and enemy.stats.role == "object") then
				alive += 1
			end
		end
		return alive
	end

	-- ===== Сундуки и ключи =====

	-- Сундуки этажей v3: модель на этаже не ставим — сундук сразу улетает в
	-- сумку каждому герою на этаже (ChestService.grant → клиент показывает
	-- полёт и ленту «ПОЛУЧЕН СУНДУК»). Открывают его в долине.
	-- Финальный сундук (босс) — золотой; через Chests.SummaryDelay — итог этажа.
	local function sendSummary(players)
		local floorInfo = Chests.Floors[Chests.clampFloor(Config.FloorId)]
		for _, player in ipairs(players) do
			if player.Parent and onFloor(player) then
				local run = state.run[player]
				local stats = F.runStats(player)
				local profile = DataService.get(player)
				fire({
					kind = "floorSummary",
					seconds = stats.seconds,
					kills = stats.kills,
					deaths = stats.deaths,
					level = profile.level,
					gold = profile.gold,
					floorId = Config.FloorId,
					floorName = floorInfo.name,
					bossDefeated = floorInfo.bossDefeated,
					chests = run and run.chests or {},
				}, player)
			end
		end
	end

	local function spawnChest(zone, chestCfg)
		local kind = Config.Chests[chestCfg.kind] or {}
		local grade = Chests.gradeOf(kind)
		local at = chestCfg.at
		local recipients = floorPlayers()
		local info = Chests.info(Config.FloorId, grade)
		ChestService.grantAll(recipients, Config.FloorId, grade, { position = at, kind = chestCfg.kind, tier = kind })
		for _, player in ipairs(recipients) do
			local run = state.run[player]
			if run then
				run.chests = run.chests or {}
				table.insert(run.chests, { key = info.key, name = info.name, grade = grade })
			end
		end
		table.insert(state.chests, { kind = chestCfg.kind, grade = grade, at = at })
		DebugState.set("Floor", "LastChest", info.name)
		fire({ kind = "chestReady", position = at, chestKind = chestCfg.kind, grade = grade, name = info.name, granted = true })
		if kind.final then
			task.delay(Chests.SummaryDelay, function()
				sendSummary(recipients)
			end)
		end
		return nil
	end

	local function dropKey(zone, keyId: string, position: Vector3)
		local info
		for _, k in ipairs(Config.Keys or {}) do
			if k.id == keyId then
				info = k
			end
		end
		local drop = { key = keyId, name = info and info.name or keyId, position = position, zone = zone.cfg.id }
		table.insert(state.keyDrops, drop)
		fire({ kind = "keyDrop", key = keyId, name = drop.name, position = position })
	end

	local function stepKeys()
		for index = #state.keyDrops, 1, -1 do
			local drop = state.keyDrops[index]
			for _, player in ipairs(floorPlayers()) do
				local root = rootOf(player)
				if root and (root.Position - (drop.position + Vector3.new(0, 3, 0))).Magnitude <= Config.KeyPickupRadius then
					table.remove(state.keyDrops, index)
					-- Ключ общий для группы: получают все на этаже.
					for _, other in ipairs(floorPlayers()) do
						other:SetAttribute(drop.key, true)
					end
					fire({ kind = "keyPicked", key = drop.key, name = drop.name, position = drop.position, by = player })
					DebugState.set("Floor", "Key_" .. drop.key, true)
					break
				end
			end
		end
	end

	-- ===== Завершение зоны =====

	local function finishFloor(zone)
		state.floorCleared = true
		publish()
		for _, player in ipairs(floorPlayers()) do
			local profile = DataService.get(player)
			profile.floorClears = profile.floorClears or {}
			local clears = profile.floorClears[Config.FloorId] or {}
			clears[player:GetAttribute("FloorDifficulty") or "normal"] = true
			profile.floorClears[Config.FloorId] = clears
		end
		-- Пати-забег: голосование «играть снова / в лобби» (сундук и итоги
		-- уходят всем на этаже независимо от голосования).
		startEndVote("win")
		Map.openVault(zone.cfg.vaultDoors or {}, true)
		task.delay(Rooms.Boss.chestDelay, function()
			if state.folder and zone.cfg.chest then
				spawnChest(zone, zone.cfg.chest)
			end
		end)
	end

	local function clearZone(zone)
		if zone.state == "cleared" then
			return
		end
		zone.state = "cleared"
		unlockZone(zone)
		publish()
		fire({ kind = "roomCleared", room = zone.index, name = zone.cfg.name, roomKind = zone.cfg.kind })
		if hooks.zoneCleared then
			hooks.zoneCleared(ctx, zone)
		end
		-- «Дары Эха»: боевая комната (были враги, не финальный босс) — в счёт.
		local fought = false
		for _, enemy in ipairs(zone.enemies) do
			if enemy.stats.role ~= "object" then
				fought = true
				break
			end
		end
		if fought and zone.cfg.kind ~= "boss" and zone.cfg.kind ~= "intro" then
			state.boonRooms += 1
			FloorBoonService.roomCleared({ folder = state.folder, players = floorPlayers(), rooms = state.boonRooms })
		end
		if zone.cfg.kind == "branch" and zone.cfg.chest then
			task.delay(0.8, function()
				if zone.state == "cleared" then
					spawnChest(zone, zone.cfg.chest)
				end
			end)
		end
	end

	-- ===== Арены и ответвления: волны =====

	local function spawnWave(zone, waveIndex: number)
		zone.waveIndex = waveIndex
		for _, entry in ipairs(zone.cfg.waves[waveIndex]) do
			spawnEnemy(zone, entry[1], entry[2])
		end
		state.folder:SetAttribute("Wave", waveIndex)
		fire({ kind = "wave", room = zone.index, wave = waveIndex, waves = #zone.cfg.waves })
	end

	function zoneAdvance(zone)
		if zone.state ~= "active" then
			return
		end
		if zone.cfg.waves and (zone.waveIndex or 0) < #zone.cfg.waves then
			task.delay(Enemies.Behavior.wavePause, function()
				if zone.state == "active" and aliveIn(zone, true) == 0 then
					spawnWave(zone, zone.waveIndex + 1)
				end
			end)
			return
		end
		clearZone(zone)
	end

	local function activateArena(zone)
		zone.state = "active"
		zone.activatedAt = now()
		lockZone(zone)
		zone.onEnemyDeath = function()
			if zone.state == "active" and aliveIn(zone, true) == 0 then
				zoneAdvance(zone)
			end
		end
		task.delay(Enemies.Behavior.entryGrace, function()
			if zone.state == "active" and (zone.waveIndex or 0) == 0 then
				spawnWave(zone, 1)
			end
		end)
	end

	-- ===== Мини-босс =====

	local function activateMiniBoss(zone)
		zone.state = "active"
		zone.activatedAt = now()
		lockZone(zone)
		local intro = 3.0
		local boss = MiniBossService.start(zone.cfg, {
			intro = intro,
			map = FloorMap,
			runtime = function()
				return Workspace:FindFirstChild("FloorRuntime") or state.folder
			end,
			spawn = function(typeId, position, extra)
				return (spawnEnemy(zone, typeId, position, extra))
			end,
			setPhaseGates = function(open)
				setGates(zone, "phase", open)
			end,
		})
		if not boss then
			clearZone(zone)
			return
		end
		zone.boss = boss
		local previous = boss.onDeath
		boss.onDeath = function(dead, attacker)
			if previous then
				previous(dead, attacker)
			end
			MiniBossService.stop(zone.cfg.id)
			for _, enemy in ipairs(zone.enemies) do
				if enemy ~= dead and enemy.alive then
					EnemyService.kill(enemy, nil)
				end
			end
			setGates(zone, "phase", true)
			if zone.cfg.key then
				dropKey(zone, zone.cfg.key, zone.cfg.points.key)
			end
			clearZone(zone)
			if zone.cfg.chest then
				task.delay(1.2, function()
					spawnChest(zone, zone.cfg.chest)
				end)
			end
		end
		local stats = boss.stats
		if zone.cfg.bossName and boss.model then
			boss.model:SetAttribute("EnemyName", zone.cfg.bossName)
		end
		fire({
			kind = "bossIntro",
			room = zone.index,
			name = zone.cfg.bossName or stats.name,
			title = zone.cfg.bossTitle or stats.title or "",
			duration = intro,
			model = boss.model,
			position = boss.position,
			miniBoss = true,
		})
	end

	-- ===== Удержание (Зал лебёдки) =====

	local function activateHold(zone)
		local hold = zone.cfg.hold
		zone.state = "active"
		zone.activatedAt = now()
		zone.holdUntil = zone.activatedAt + hold.duration
		zone.nextFlowAt = zone.activatedAt + 1.0
		zone.flowIndex = 0
		lockZone(zone)
		zone.spikes = {}
		for _, point in ipairs(hold.spikes or {}) do
			table.insert(zone.spikes, Map.makeSpikes(point))
		end
		fire({ kind = "hold", room = zone.index, phase = "start", duration = hold.duration, endsAt = zone.holdUntil })
	end

	local function stepHold(zone, t: number)
		local hold = zone.cfg.hold
		local progress = math.clamp((t - zone.activatedAt) / hold.duration, 0, 1)
		Map.setRaise(hold.innerGate, progress * 0.55)
		if t >= zone.holdUntil then
			-- Решётка поднята: враги рассыпаются.
			for _, enemy in ipairs(zone.enemies) do
				if enemy.alive then
					EnemyService.kill(enemy, nil)
				end
			end
			Map.setRaise(hold.innerGate, 1)
			for _, trap in ipairs(zone.spikes or {}) do
				Map.setSpikePhase(trap, "idle")
			end
			fire({ kind = "hold", room = zone.index, phase = "done" })
			clearZone(zone)
			return
		end
		if t >= zone.nextFlowAt then
			zone.nextFlowAt = t + hold.every
			local alive = aliveIn(zone, true)
			if alive < hold.limit then
				zone.flowIndex += 1
				local typeId = hold.mix[((zone.flowIndex - 1) % #hold.mix) + 1]
				local gate = hold.flows[(zone.flowIndex % #hold.flows) + 1]
				spawnEnemy(zone, typeId, gate)
			end
		end
	end

	-- ===== Привратник и сцена ключей =====

	local function hasKeys(player): boolean
		for _, k in ipairs(Config.Keys or {}) do
			if not player:GetAttribute(k.id) then
				return false
			end
		end
		return true
	end

	local function activateBoss(zone)
		zone.state = "active"
		zone.activatedAt = now()
		lockZone(zone)
		local pts = zone.cfg.points
		-- Сцена: половины ключа входят в замки, створки вздрагивают. Без ключей
		-- (отладка, телепорт) сцена пропускается.
		local keysOk = false
		if #(Config.Keys or {}) > 0 and pts and pts.lockL then
			for _, player in ipairs(floorPlayers()) do
				keysOk = keysOk or hasKeys(player)
			end
		end
		local sceneTime = keysOk and (Config.KeyScene or 0.3) or 0.3
		if keysOk then
			fire({ kind = "keyScene", room = zone.index, duration = sceneTime, lockL = pts.lockL, lockR = pts.lockR, scene = pts.scene })
		end
		task.delay(sceneTime, function()
			if zone.state ~= "active" then
				return
			end
			local bossType = Enemies.Types[zone.cfg.boss.typeId]
			local duration = (bossType and bossType.introTime) or Enemies.Behavior.bossIntro
			local boss, stats = spawnEnemy(zone, zone.cfg.boss.typeId, zone.cfg.boss.at, { introDelay = duration })
			zone.boss = boss
			zone.onEnemyDeath = nil
			boss.onDeath = function(dead, attacker)
				creditKill(attacker, dead.stats)
				if attacker then
					ProgressionService.rewardBossSoul(attacker)
				end
				for _, enemy in ipairs(zone.enemies) do
					if enemy ~= dead and enemy.alive then
						EnemyService.kill(enemy, nil)
					end
				end
				clearZone(zone)
				finishFloor(zone)
			end
			boss.onPhase = function(_, _, phase)
				local summon = phase and phase.summon
				if not summon then
					return
				end
				for index = 1, summon.count do
					local point = pts.summons[((index - 1) % #pts.summons) + 1]
					spawnEnemy(zone, summon.typeId, point)
				end
			end
			if zone.cfg.bossName and boss.model then
				boss.model:SetAttribute("EnemyName", zone.cfg.bossName)
			end
			fire({
				kind = "bossIntro",
				room = zone.index,
				name = zone.cfg.bossName or stats.name,
				title = zone.cfg.bossTitle or stats.title or "Страж ворот Хранилища",
				duration = duration,
				model = boss.model,
				position = boss.position,
				typeId = zone.cfg.boss.typeId,
			})
		end)
	end

	-- ===== Улицы: засады по триггерам =====

	local function stepStreet(zone, roots)
		for gi, group in ipairs(zone.cfg.groups or {}) do
			if not zone.groupsSpawned[gi] then
				for _, position in ipairs(roots) do
					if Config.inBox(group.trigger, position) then
						zone.groupsSpawned[gi] = true
						for _, entry in ipairs(group.enemies) do
							local delay = entry[3] or 0
							if delay > 0 then
								task.delay(delay, function()
									if zone.groupsSpawned[gi] and state.rooms[zone.index] == zone then
										spawnEnemy(zone, entry[1], entry[2])
									end
								end)
							else
								spawnEnemy(zone, entry[1], entry[2])
							end
						end
						fire({ kind = "ambush", room = zone.index, group = gi })
						break
					end
				end
			end
		end
	end

	-- Взрыв Треснувшего на мосту пробивает доски.
	local function hookBridge(zone)
		if not zone.cfg.breakable then
			return
		end
		zone.onEnemyDeath = function(dead)
			if dead.exploded then
				local centers = Map.breakTiles(zone.cfg.breakable .. "_", dead.position, 3.2, 6)
				if #centers > 0 then
					fire({ kind = "bridgeBreak", positions = centers, duration = 6 })
				end
			end
		end
	end

	-- ===== Вход в зону =====

	local function activateZone(zone)
		local kind = zone.cfg.kind
		if kind == "arena" or kind == "branch" then
			activateArena(zone)
		elseif kind == "miniboss" then
			activateMiniBoss(zone)
		elseif kind == "hold" then
			activateHold(zone)
		elseif kind == "boss" then
			activateBoss(zone)
		end
		if hooks.zoneActivated then
			hooks.zoneActivated(ctx, zone)
		end
		publish()
	end

	local function enterZone(player, zone)
		player:SetAttribute("RoomIndex", zone.index)
		player:SetAttribute("RoomName", zone.cfg.name)
		fire({ kind = "room", room = zone.index, name = zone.cfg.name, roomKind = zone.cfg.kind, total = #state.rooms }, player)
	end

	-- ===== Шипы (Зал лебёдки) =====

	local lastSpikeHit = {}

	local function spikePhase(zone, t: number): string
		local spikes = Rooms.Spikes
		local cycle = spikes.cycleIdle + spikes.warning + spikes.cycleActive
		local phaseTime = (t - (zone.activatedAt or t)) % cycle
		if phaseTime < spikes.cycleIdle then
			return "idle"
		elseif phaseTime < spikes.cycleIdle + spikes.warning then
			return "warn"
		end
		return "active"
	end

	local function updateSpikes(zone, t: number)
		if not zone.spikes then
			return
		end
		local phase = zone.state == "active" and spikePhase(zone, t) or "idle"
		for _, trap in ipairs(zone.spikes) do
			Map.setSpikePhase(trap, phase)
		end
		if phase ~= "active" then
			return
		end
		for _, player in ipairs(floorPlayers()) do
			local root = rootOf(player)
			if root then
				for _, trap in ipairs(zone.spikes) do
					local flatD = Vector3.new(root.Position.X - trap.position.X, 0, root.Position.Z - trap.position.Z).Magnitude
					if flatD <= Rooms.Spikes.radius and math.abs(root.Position.Y - 3 - trap.position.Y) < 3 then
						if t - (lastSpikeHit[player] or -10) >= Rooms.Spikes.tick then
							lastSpikeHit[player] = t
							CombatService.resolveIncomingAttack(player, {
								damage = Rooms.Spikes.damage,
								parryable = false,
								source = "Spikes",
								position = trap.position,
							})
						end
						break
					end
				end
			end
		end
	end

	-- ===== Костры =====

	local function bindCampfire(zone)
		local point = zone.cfg.campfire
		if not point then
			return
		end
		local anchor, prompt = Map.makeCampfirePrompt(point, zone.cfg.id)
		zone.campfire = anchor
		prompt.Triggered:Connect(function(player)
			local current = player:GetAttribute("HealCharges") or 0
			local text
			if current >= Combat.Heal.charges then
				text = "Заряды лечения уже полны"
			else
				CombatService.refillHeals(player)
				text = "Заряды лечения восстановлены"
			end
			-- Костёр — чекпоинт: смерть дальше вернёт сюда (если включено в хабе).
			player:SetAttribute("Checkpoint", zone.index)
			DebugState.set("Floor", "CampfireUsed", true)
			local notify = Net.get("Notify")
			if notify then
				notify:FireClient(player, { kind = "campfire", text = text })
			end
			fire({ kind = "campfire", position = point }, player)
		end)
	end

	-- ===== Сборка этажа =====

	local function resetZone(zone)
		if zone.cfg.kind == "miniboss" then
			MiniBossService.stop(zone.cfg.id)
		end
		for _, enemy in ipairs(zone.enemies) do
			EnemyService.remove(enemy)
		end
		zone.enemies = {}
		zone.waveIndex = 0
		zone.groupsSpawned = {}
		zone.boss = nil
		if zone.state ~= "cleared" then
			zone.state = "idle"
		end
		setGates(zone, "entry", true)
		setGates(zone, "phase", true)
		setSeals(zone, false)
		if zone.cfg.kind == "hold" then
			Map.setRaise(zone.cfg.hold.innerGate, 0)
		end
		fire({ kind = "roomReset", room = zone.index })
		if hooks.zoneReset then
			hooks.zoneReset(ctx, zone)
		end
	end

	local buildBody -- тело сборки объявлено ниже; F.build — обёртка с логом ошибок

	function F.build()
		local ok, buildErr = pcall(function()
			buildBody()
		end)
		if not ok then
			warn("[FloorService] сборка этажа " .. tostring(Config.FloorId) .. " упала: " .. tostring(buildErr))
		end
	end

	function buildBody()
		-- Только свои враги: на другом этаже могут быть игроки.
		for _, zone in ipairs(state.rooms) do
			for _, enemy in ipairs(zone.enemies or {}) do
				EnemyService.remove(enemy)
			end
		end
		if Config.FloorId == 1 then
			MiniBossService.stopAll()
		end
		if hooks.beforeBuild then
			hooks.beforeBuild(ctx)
		end
		if state.folder then
			FloorBoonService.abort(state.folder) -- пауза выбора даров на старом этаже
		end
		state.boonRooms = 0
		for _, child in ipairs(Workspace:GetChildren()) do
			if child.Name == Config.FolderName then
				child:Destroy()
			end
		end
		if not Map.ready() then
			warn("[FloorService] нет Workspace." .. Config.MapName .. " — соберите карту этажа " .. Config.FloorId .. " (README пакета карты)")
		end
		Map.reset(initialGateStates())
		Map.capWalls() -- один раз: невидимые надстройки стен

		local folder = Instance.new("Folder")
		folder.Name = Config.FolderName
		folder:SetAttribute("FloorId", Config.FloorId)
		folder.Parent = Workspace
		state.folder = folder
		state.rooms = {}
		state.chests = {}
		state.keyDrops = {}
		for index, cfg in ipairs(Config.Zones) do
			local zone = {
				index = index,
				cfg = cfg,
				name = cfg.name,
				kind = cfg.kind,
				state = (cfg.kind == "rest" or cfg.kind == "intro" or cfg.kind == "street") and "open" or "idle",
				enemies = {},
				groupsSpawned = {},
				bounds = Config.bounds(cfg),
				waveIndex = 0,
				folder = folder,
			}
			state.rooms[index] = zone
			bindCampfire(zone)
			hookBridge(zone)
		end
		state.floorCleared = false
		state.used = false
		publish()
		if hooks.build then
			hooks.build(ctx)
		end
		print(("[FloorService] этаж %d: зон %d"):format(Config.FloorId, #state.rooms))
	end

	local function startPosition(zone): Vector3
		local p = zone.cfg.start or Vector3.zero
		return Vector3.new(p.X, p.Y + 3.5, p.Z)
	end

	local function teleportToZone(player, zone)
		if not zone then
			warn("[FloorService] teleportToZone: зона nil! диагностика:\n" .. debug.traceback(nil, 2)
				.. "\nзон=" .. tostring(#state.rooms) .. " used=" .. tostring(state.used) .. " cleared=" .. tostring(state.floorCleared))
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local position = startPosition(zone)
		root.CFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
		root.AssemblyLinearVelocity = Vector3.zero
		MotionGuard.markLegal(player, 3) -- телепорт легален: сторож не считает его скачком
		state.playerRoom[player] = zone.index
		enterZone(player, zone)
	end

	-- ===== Выход за карту =====
	-- Вокруг замка пустыня (Terrain). Кто стоит на песке вне всех игровых зон —
	-- перелез через стену; через OUT_GRACE возвращаем в последнюю точку внутри.
	-- Песок внутри «Порога» законный: он в рамке своей зоны.

	local OUT_GRACE = 0.4
	local OUT_MARGIN = 3

	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Include

	local function inBoxMargin(b, position: Vector3): boolean
		return position.X >= b[1] - OUT_MARGIN and position.X <= b[4] + OUT_MARGIN and position.Z >= b[3] - OUT_MARGIN and position.Z <= b[6] + OUT_MARGIN
	end

	local function insideAnyZone(position: Vector3): boolean
		-- Переходы между зонами вне их боксов (Config.Links).
		for _, b in ipairs(Config.Links or {}) do
			if inBoxMargin(b, position) then
				return true
			end
		end
		for _, cfg in ipairs(Config.Zones) do
			local b = cfg.box
			if
				b
				and position.X >= b[1] - OUT_MARGIN
				and position.X <= b[4] + OUT_MARGIN
				and position.Z >= b[3] - OUT_MARGIN
				and position.Z <= b[6] + OUT_MARGIN
			then
				return true
			end
		end
		return false
	end

	local function onSandOutside(root): boolean
		if insideAnyZone(root.Position) then
			return false
		end
		local map = Workspace:FindFirstChild(Config.MapName)
		groundParams.FilterDescendantsInstances = map and { Workspace.Terrain, map } or { Workspace.Terrain }
		local hit = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), groundParams)
		if not hit then
			return false -- в прыжке или падает: решит FallLimit
		end
		-- Песок вокруг этажа — всегда «снаружи»; плиты карты за стенами — если этаж
		-- так просит (Config.GuardMapOutside): вылез в щель — назад на последнее место.
		return hit.Instance == Workspace.Terrain or Config.GuardMapOutside == true
	end

	local function guardBounds(player, root, t: number)
		local guard = state.bounds[player]
		if not guard then
			guard = { safe = nil, outSince = nil }
			state.bounds[player] = guard
		end
		if onSandOutside(root) then
			guard.outSince = guard.outSince or t
			if t - guard.outSince >= OUT_GRACE then
				guard.outSince = nil
				if guard.safe then
					root.CFrame = CFrame.new(guard.safe) * root.CFrame.Rotation
					root.AssemblyLinearVelocity = Vector3.zero
					MotionGuard.markLegal(player, 2) -- возврат делает сервер, не игрок
				else
					local zone = state.rooms[state.playerRoom[player] or 1]
					if zone then
						teleportToZone(player, zone)
					end
				end
				fire({ kind = "outOfBounds" }, player)
			end
		else
			guard.outSince = nil
			local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air and insideAnyZone(root.Position) then
				guard.safe = root.Position + Vector3.new(0, 0.5, 0)
			end
		end
	end

	-- Наблюдатель вернулся к живому: снять якорь и метки, вернуть управление.
	local function clearSpectate(player)
		if player:GetAttribute("Spectating") == nil then
			return
		end
		player:SetAttribute("Spectating", nil)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root.Anchored then
			root.Anchored = false
		end
		if character then
			local force = character:FindFirstChildOfClass("ForceField")
			if force then
				force:Destroy()
			end
		end
	end

	-- Погибший член отряда остаётся на этаже наблюдателем (решение владельца):
	-- возрождённый персонаж уводится под карту и якорится — в бой он не влияет,
	-- но floorPlayers() его видит, поэтому сундуки/опыт событий идут ему, пока
	-- он досматривает. Вернулся в лобби раньше конца — финального сундука нет.
	local function startSpectate(player, target)
		player:SetAttribute("Spectating", target.UserId)
		fire({ kind = "spectate", target = target.UserId, name = target.Name }, player)
	end

	-- Живые члены отряда на этаже, которые сами не наблюдатели.
	local function activeSurvivors(party, except): number
		local count = 0
		for _, member in ipairs(party.members) do
			if member ~= except and onFloor(member) and rootOf(member) and member:GetAttribute("Spectating") == nil then
				count += 1
			end
		end
		return count
	end

	-- Смерть на этаже: в отряде с выжившими — наблюдение, иначе как раньше —
	-- в лобби (соло).
	local function spectateOrHub(player)
		local Party = partyModule()
		local party = Party and Party.rawParty(player) or nil
		local target = nil
		if party then
			for _, member in ipairs(party.members) do
				if member ~= player and onFloor(member) and rootOf(member) and member:GetAttribute("Spectating") == nil then
					target = member
					break
				end
			end
		end
		if target then
			startSpectate(player, target)
			-- Наблюдатели, следившие за погибшим, переключаются на живых.
			for _, other in ipairs(floorPlayers()) do
				if other ~= player and other:GetAttribute("Spectating") == player.UserId then
					local otherParty = Party and Party.rawParty(other) or nil
					local next = nil
					if otherParty then
						for _, member in ipairs(otherParty.members) do
							if member ~= other and onFloor(member) and rootOf(member) and member:GetAttribute("Spectating") == nil then
								next = member
								break
							end
						end
					end
					if next then
						other:SetAttribute("Spectating", next.UserId)
						fire({ kind = "spectate", target = next.UserId, name = next.Name }, other)
					end
				end
			end
			if party and activeSurvivors(party, player) == 0 then
				-- Весь отряд мёртв: конец забега — голосование.
				startEndVote("fail")
			end
		else
			sendToHubOnDeath(player)
		end
	end

	local function sendToHubOnDeath(player)
		task.delay(math.max(Players.RespawnTime - 0.6, 0.5), function()
			if player.Parent and onFloor(player) then
				player:SetAttribute("ZoneBusy", true)
				player:SetAttribute("Zone", "Hub")
			end
		end)
	end

	-- ===== Голосование конца забега (механика владельца 14.11) =====
	-- Пати-забег пройден или провален: «играть снова» или «в лобби». Побеждает
	-- большее число голосов; поровну (и молчавшие) — всех в лобби. Соло —
	-- прежний поток (сундук/возврат, RequestNewRun без голосования).
	local END_VOTE_TIME = 30
	local newRun -- определён ниже; resolve и finishFloor зовут его

	local function resolveEndVote(kind: string)
		local vote = state.endVote
		if not vote or vote.kind ~= kind then
			return
		end
		state.endVote = nil
		local again, lobby = 0, 0
		for member in pairs(vote.members) do
			local choice = vote.votes[member] or "lobby"
			if choice == "again" then
				again += 1
			else
				lobby += 1
			end
		end
		local result = (again > lobby) and "again" or "lobby"
		fire({ kind = "endVoteResult", voteKind = kind, again = again, lobby = lobby, result = result })
		if result == "again" then
			newRun()
			return
		end
		-- В лобби: наблюдателей отпускаем, всех на этаже возвращаем.
		local okHub, Hub = pcall(function()
			return require(script.Parent.Parent:WaitForChild("Hub"):WaitForChild("HubService"))
		end)
		for _, player in ipairs(floorPlayers()) do
			clearSpectate(player)
			if okHub and Hub and Hub.returnToHub then
				task.spawn(function()
					pcall(Hub.returnToHub, player)
				end)
			else
				player:SetAttribute("Zone", "Hub")
			end
		end
	end

	function startEndVote(kind: string)
		local Party = partyModule()
		if not Party then
			return
		end
		local members = {}
		local seen = {}
		for _, player in ipairs(floorPlayers()) do
			if Party.rawParty(player) and not seen[player] then
				seen[player] = true
				table.insert(members, player)
			end
		end
		if #members < 2 then
			return -- соло: прежний поток
		end
		local deadline = now() + END_VOTE_TIME
		local votes = {}
		local memberMap = {}
		for _, member in ipairs(members) do
			memberMap[member] = true
		end
		state.endVote = { kind = kind, votes = votes, members = memberMap, deadline = deadline }
		fire({ kind = "endVote", voteKind = kind, deadline = deadline, votes = 0, total = #members })
		task.delay(END_VOTE_TIME + 0.5, function()
			resolveEndVote(kind)
		end)
	end

	local function castVote(player, choice: string)
		local vote = state.endVote
		if not vote or not vote.members[player] then
			return
		end
		if choice ~= "again" and choice ~= "lobby" then
			return
		end
		vote.votes[player] = choice
		local casted, total = 0, 0
		local again, lobby = 0, 0
		for member in pairs(vote.members) do
			total += 1
			if vote.votes[member] then
				casted += 1
				if vote.votes[member] == "again" then
					again += 1
				else
					lobby += 1
				end
			end
		end
		fire({ kind = "endVote", voteKind = vote.kind, deadline = vote.deadline, votes = casted, total = total, mine = choice })
		if casted >= total then
			resolveEndVote(vote.kind)
		end
	end

	local function livingPlayersIn(zone, except): number
		local count = 0
		for _, player in ipairs(floorPlayers(except)) do
			if rootOf(player) and state.playerRoom[player] == zone.index then
				count += 1
			end
		end
		return count
	end

	local function onCharacter(player, character)
		local humanoid = character:WaitForChild("Humanoid")
		character:WaitForChild("HumanoidRootPart")
		humanoid.Died:Connect(function()
			if not onFloor(player) then
				return
			end
			local run = state.run[player]
			if run then
				run.deaths += 1
			end
			ProgressionService.resetStacks(player)
			local index = state.playerRoom[player]
			local zone = index and state.rooms[index]
			fire({ kind = "playerDied", room = index }, player)
			-- Активная зона без живых игроков начинается заново.
			if zone and zone.state == "active" and livingPlayersIn(zone, player) == 0 then
				resetZone(zone)
			end
			spectateOrHub(player)
		end)
		task.wait(0.1)
		if not onFloor(player) then
			return
		end
		if player:GetAttribute("Spectating") ~= nil then
			-- Наблюдатель: возрождённого уводим под карту и якорим — вне боя,
			-- но на этаже (floorPlayers его видит, награды идут).
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = CFrame.new(root.Position - Vector3.new(0, 220, 0))
				root.Anchored = true
				MotionGuard.markLegal(player, 3)
				local force = Instance.new("ForceField")
				force.Visible = false
				force.Parent = character
			end
			return
		end
		local zone = state.rooms[state.playerRoom[player] or 1]
		if zone then
			teleportToZone(player, zone)
		end
	end

	local function resetKeys(player)
		for _, k in ipairs(Config.Keys or {}) do
			player:SetAttribute(k.id, nil)
		end
		player:SetAttribute("Checkpoint", nil)
		if hooks.resetPlayer then
			hooks.resetPlayer(ctx, player)
		end
	end

	-- Вход на этаж из хаба (врата Хранилища).
	local function clearedRooms(): number
		local cleared = 0
		for _, zone in ipairs(state.rooms) do
			if zone.state == "cleared" then
				cleared += 1
			end
		end
		return cleared
	end

	-- Можно ли игроку войти на этаж сейчас. true | false, причина (для окна врат).
	function F.canEnter(player, difficulty: string?)
		local others = floorPlayers(player)
		if #others == 0 then
			return true -- этаж свободен: соберётся заново для этой группы
		end
		local current = others[1]:GetAttribute("FloorDifficulty") or state.difficulty or "normal"
		if state.floorCleared then
			return false, ("На этом этаже группа (%d) уже победила босса. Подожди, пока они вернутся."):format(#others)
		end
		-- Забег приватен: объединяются только участники одного отряда (решение
		-- владельца — у соло своя карта, общий этаж только у пати).
		local Party = partyModule()
		if not (Party and Party.inSameParty(player, others[1])) then
			return false, ("Этаж занят: забег группы (%d) уже идёт. Подожди, пока они закончат."):format(#others)
		end
		if difficulty and current ~= difficulty then
			return false, ("Идёт забег на сложности «%s». Выбери её или подожди."):format(DIFFICULTY_NAMES[current] or current)
		end
		if clearedRooms() > 0 or now() - state.runStartedAt > JOIN_WINDOW then
			return false, ("Этаж занят: забег группы (%d) уже идёт. Подожди, пока они закончат."):format(#others)
		end
		return true
	end

	function F.enterRun(player)
		if #floorPlayers(player) == 0 then
			-- Первый в группе: его сложность — сложность всего забега.
			state.difficulty = player:GetAttribute("FloorDifficulty") or "normal"
			state.runStartedAt = now()
			state.newRunVotes = {}
			state.endVote = nil
			if state.used then
				F.build()
			end
		end
		state.used = true
		state.run[player] = { startedAt = now(), kills = 0, deaths = 0 }
		resetKeys(player)
		FloorBoonService.reset(player, Config.FloorId) -- дары прошлого этажа не переходят
		ProgressionService.resetStacks(player)
		local profile = DataService.get(player)
		CombatService.applyClass(player, profile.className, profile.level, true)
		CombatService.refillHeals(player)
		teleportToZone(player, state.rooms[1])
		fire({ kind = "newRun", zones = #state.rooms }, player)
		return { ok = true }
	end

	-- newRun объявлен выше по файлу (его зовут resolveEndVote и finishFloor).
	function newRun()
		state.newRunVotes = {}
		state.endVote = nil
		state.runStartedAt = now()
		F.build()
		for _, other in ipairs(floorPlayers()) do
			clearSpectate(other)
			state.run[other] = { startedAt = now(), kills = 0, deaths = 0 }
			resetKeys(other)
			FloorBoonService.reset(other, Config.FloorId)
			ProgressionService.resetStacks(other)
			CombatService.applyClass(other, DataService.get(other).className, DataService.get(other).level, true)
			CombatService.refillHeals(other)
			teleportToZone(other, state.rooms[1])
			fire({ kind = "newRun", zones = #state.rooms }, other)
		end
		return { ok = true }
	end

	-- Зона по позиции: сначала текущая (зоны на стыках перекрываются), потом все.
	local function zoneAt(position: Vector3, current: number?)
		-- Вложенные зоны (секрет внутри лабиринта) — раньше объемлющей.
		for _, z in ipairs(state.rooms) do
			if z.cfg.nested and Config.inBox(z.cfg.box, position) then
				return z
			end
		end
		local zone = current and state.rooms[current]
		if zone and Config.inBox(zone.cfg.box, position) then
			return zone
		end
		for _, z in ipairs(state.rooms) do
			if Config.inBox(z.cfg.box, position) then
				return z
			end
		end
		return nil
	end

	-- Новый забег (после победы над боссом этажа). Этаж общий, поэтому решает
	-- вся группа: один игрок больше не сбрасывает остальных. Забег начинается заново,
	-- когда проголосовали все, кто ещё на этаже (ушедшие в долину не считаются).
	local function countVotes()
		local players = floorPlayers()
		local votes = 0
		for _, other in ipairs(players) do
			if state.newRunVotes[other] then
				votes += 1
			end
		end
		return votes, #players, players
	end

	local function resolveVotes()
		if not state.floorCleared then
			state.newRunVotes = {}
			return nil
		end
		local votes, total, players = countVotes()
		if total > 0 and votes >= total then
			return newRun()
		end
		if votes > 0 then
			for _, other in ipairs(players) do
				fire({ kind = "newRunVote", votes = votes, total = total, mine = state.newRunVotes[other] == true }, other)
			end
			-- Отдельного окна голосования у клиента пока нет — подсказываем тостом,
			-- чтобы было понятно, почему забег ещё не начался.
			local notify = Net.get("Notify")
			if notify then
				local text = ("Новый забег: за %d из %d. Начнётся, когда согласятся все на этаже"):format(votes, total)
				for _, other in ipairs(players) do
					notify:FireClient(other, { kind = "warn", text = text })
				end
			end
		end
		return { ok = true, pending = true, votes = votes, total = total }
	end

	function F.requestNewRun(player)
		if not state.floorCleared or not onFloor(player) then
			return { ok = false, reason = "not-cleared" }
		end
		state.newRunVotes[player] = true
		return resolveVotes() or { ok = false, reason = "not-cleared" }
	end

	-- Наружу для FloorService.start (ремоуты RequestLeaveFloor / FloorVote).
	F.castVote = castVote
	F.clearSpectate = clearSpectate

	-- Игрок ушёл с этажа или с сервера: его голос снимается, оставшиеся могли
	-- уже все согласиться.
	local function dropVote(player)
		local had = state.newRunVotes[player]
		state.newRunVotes[player] = nil
		if state.floorCleared and next(state.newRunVotes) ~= nil then
			task.defer(resolveVotes)
		elseif had then
			state.newRunVotes = {}
		end
	end

	function F.start()
		Net.ensureAll()
		F.build()

		local function hook(player)
			player.CharacterAdded:Connect(function(character)
				task.spawn(onCharacter, player, character)
			end)
			if player.Character then
				task.spawn(onCharacter, player, player.Character)
			end
			player:GetAttributeChangedSignal("Zone"):Connect(function()
				if not onFloor(player) then
					if state.newRunVotes[player] ~= nil or next(state.newRunVotes) ~= nil then
						dropVote(player)
					end
					if FloorBoonService.floorOf(player) == Config.FloorId then
						FloorBoonService.reset(player, nil) -- ушёл с этажа: дары кончились
					end
					state.playerRoom[player] = nil
					state.bounds[player] = nil
					player:SetAttribute("RoomIndex", nil)
					player:SetAttribute("RoomName", nil)
				end
			end)
		end
		Players.PlayerAdded:Connect(hook)
		for _, player in ipairs(Players:GetPlayers()) do
			hook(player)
		end
		Players.PlayerRemoving:Connect(function(player)
			if next(state.newRunVotes) ~= nil then
				dropVote(player)
			end
			state.playerRoom[player] = nil
			state.bounds[player] = nil
			state.run[player] = nil
			lastSpikeHit[player] = nil
		end)


		local accumulator = 0
		RunService.Heartbeat:Connect(function(dt)
			local t = now()
			Map.step()
			if hooks.step then
				hooks.step(ctx, t, dt)
			end
			for _, zone in ipairs(state.rooms) do
				if zone.state == "active" and zone.cfg.kind == "hold" then
					stepHold(zone, t)
				end
				updateSpikes(zone, t)
			end
			accumulator += dt
			if accumulator < 0.15 then
				return
			end
			accumulator = 0
			stepKeys()
			local roots = {}
			for _, player in ipairs(floorPlayers()) do
				local root, humanoid = rootOf(player)
				if root then
					table.insert(roots, root.Position)
					local current = state.playerRoom[player]
					if root.Position.Y < Config.FallLimit then
						-- Упал (ров, край): на старт зоны, с потерей здоровья.
						local zone = state.rooms[current or 1]
						if zone then
							teleportToZone(player, zone)
							if humanoid then
								humanoid:TakeDamage(humanoid.MaxHealth * Config.FallDamagePct)
							end
							fire({ kind = "fell", room = zone.index }, player)
						end
					else
						guardBounds(player, root, os.clock())
						local zone = zoneAt(root.Position, current)
						if zone and zone.index ~= current then
							state.playerRoom[player] = zone.index
							enterZone(player, zone)
						end
						zone = zone or (current and state.rooms[current])
						if zone and zone.state == "idle" and zone.cfg.enter and Config.inBox(zone.cfg.enter, root.Position) then
							activateZone(zone)
						end
					end
				end
			end
			for _, zone in ipairs(state.rooms) do
				if zone.cfg.groups then
					stepStreet(zone, roots)
				end
			end
		end)

		print(("[FloorService] этаж %d запущен"):format(Config.FloorId))
	end

	function F.state()
		return state
	end

	function F.runStats(player)
		local run = state.run[player]
		if not run then
			return { seconds = 0, kills = 0, deaths = 0 }
		end
		return { seconds = now() - run.startedAt, kills = run.kills, deaths = run.deaths }
	end

	function F.currentRoom(player)
		local index = state.playerRoom[player]
		return index and state.rooms[index] or nil
	end

	-- Контекст для хуков этажа (Floor2World).
	ctx.Config = Config
	ctx.Map = Map
	ctx.state = state
	ctx.now = now
	ctx.fire = fire
	ctx.onFloor = onFloor
	ctx.floorPlayers = floorPlayers
	ctx.rootOf = rootOf
	ctx.publish = publish
	ctx.setGates = setGates
	ctx.lockZone = lockZone
	ctx.unlockZone = unlockZone
	ctx.spawnEnemy = spawnEnemy
	ctx.aliveIn = aliveIn
	ctx.spawnChest = spawnChest
	ctx.clearZone = clearZone
	ctx.activateZone = activateZone
	ctx.teleportToZone = teleportToZone
	ctx.zoneById = function(id: string)
		for _, zone in ipairs(state.rooms) do
			if zone.cfg.id == id then
				return zone
			end
		end
		return nil
	end
	if World then
		World.attach(ctx, hooks)
	end
	F.ctx = ctx
	F.Map = Map
	return F
end

-- ===== Этажи =====

local floors = {
	[1] = createFloor(Floor1v2, nil),
	[2] = createFloor(Floor2, Floor2World),
	[3] = createFloor(Floor3, Floor3World),
	[4] = createFloor(Floor4, Floor4World),
	[5] = createFloor(Floor5, Floor5World),
}
FloorService.floors = floors

local function floorOf(player)
	return floors[player:GetAttribute("FloorId") or 1] or floors[1]
end
FloorService.floorOf = floorOf

function FloorService.setLoot(loot)
	for _, floor in pairs(floors) do
		floor.setLoot(loot)
	end
end

function FloorService.start()
	Net.ensureAll()
	for _, floor in pairs(floors) do
		floor.start()
	end
	Net.get("RequestNewRun").OnServerInvoke = function(player)
		if not RemoteGuard.allow(player, "RequestNewRun") then return RemoteGuard.BUSY end
		return floorOf(player).requestNewRun(player)
	end

	-- Наблюдатель вернулся в лобби (кнопка на экране смерти): награды этажа,
	-- включая финальный сундук, дальше не положены (решение владельца).
	Net.get("RequestLeaveFloor").OnServerInvoke = RemoteGuard.wrap("RequestLeaveFloor", function(player)
		local floor = floorOf(player)
		if not floor then
			return { ok = false }
		end
		if floor.clearSpectate then
			floor.clearSpectate(player)
		end
		local okHub, Hub = pcall(function()
			return require(script.Parent.Parent:WaitForChild("Hub"):WaitForChild("HubService"))
		end)
		if okHub and Hub and Hub.returnToHub then
			task.spawn(function()
				pcall(Hub.returnToHub, player)
			end)
		end
		return { ok = true }
	end)

	-- Голос «играть снова / в лобби» конца забега.
	Net.get("FloorVote").OnServerEvent:Connect(RemoteGuard.wrapEvent("FloorVote", function(player, choice)
		local floor = floorOf(player)
		if floor and floor.castVote then
			floor.castVote(player, typeof(choice) == "string" and choice or "")
		end
	end))
end

-- Пересобрать этаж (по умолчанию — первый).
function FloorService.build(floorId: number?)
	floors[floorId or 1].build()
end

-- Можно ли войти на этаж floorId со сложностью difficulty (проверка у врат).
function FloorService.canEnter(player, floorId: number, difficulty: string?)
	local floor = floors[floorId]
	if not floor or not floor.canEnter then
		return true
	end
	return floor.canEnter(player, difficulty)
end

-- Вход на этаж из хаба: этаж — по атрибуту FloorId (его ставит HubService).
function FloorService.enterRun(player)
	return floorOf(player).enterRun(player)
end

function FloorService.state(floorId: number?)
	return floors[floorId or 1].state()
end

function FloorService.runStats(player)
	return floorOf(player).runStats(player)
end

function FloorService.currentRoom(player)
	return floorOf(player).currentRoom(player)
end

return FloorService
