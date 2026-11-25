--!nonstrict
-- Floor5World (сервер)
-- Особое этажа 5 «Зал хроник» поверх общего FloorService (хуки экземпляра этажа):
--
--   Скрипторий     kind = "keeper": FloorService такую зону не ведёт — здесь.
--                  Вход запирается, сцена, Переплётчик (мини-босс); на 50 % —
--                  кляксы в точках SP_k*; смерть — зона чиста, сундук.
--   Хранилище      пока идёт бой, с полок падают книги: метка на полу, удар.
--   полок
--   Купол хроник   II фаза Хрониста — четыре печати (ward_seal) на SEAL_*:
--                  пока стоят, удары по боссу отбиты; все разбиты — оглушён.
--                  III фаза — стирание: края арены стираются, безопасный круг
--                  сжимается к центру (урон снаружи).
--   ворота         после босса створки Vault_F5_L/R расходятся (FloorService),
--                  за ними мост «Обрыв хроники»; в конце — сцена-отсылка
--                  на продолжение (один раз на игрока за заход).
--   декорации      BreakableService.build(5) при каждой сборке этажа.
--
-- Картинка — клиент Floor45Fx (события FloorEvent kind f5*).

local Players = game:GetService("Players")

local CombatService = require(script.Parent.CombatService)
local EnemyService = require(script.Parent.EnemyService)
local Floor45Service = require(script.Parent.Floor45Service)
local BreakableService = require(script.Parent.BreakableService)
local FloorGeo = require(game:GetService("ReplicatedStorage").Shared.Floor.FloorGeo)

local Floor5World = {}

local FEET = 3.0

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Floor5World.attach(ctx, hooks)
	local Config = ctx.Config
	local Traps = Config.Traps
	local world = {
		bookfallAt = 0,
		seals = nil, -- { list, boss }
		erasure = nil, -- { t0, center, cfg, nextTick }
		epilogue = {}, -- [player] = true
		bossPhase = 1,
	}

	local function playersInBox(box)
		local list = {}
		for _, player in ipairs(ctx.floorPlayers()) do
			local root = ctx.rootOf(player)
			if root and Config.inBox(box, root.Position) then
				table.insert(list, { player = player, root = root })
			end
		end
		return list
	end

	local function ownsZone(zone): boolean
		for _, z in ipairs(ctx.state.rooms or {}) do
			if z == zone then
				return true
			end
		end
		return false
	end

	Floor45Service.registerSpawner(function(zone, typeId, position)
		if ownsZone(zone) then
			return (ctx.spawnEnemy(zone, typeId, position))
		end
		return nil
	end)

	-- ===== Скрипторий: Переплётчик =====

	local function activateKeeper(zone)
		local cfg = zone.cfg
		local keeper = cfg.keeper
		zone.state = "active"
		zone.activatedAt = ctx.now()
		ctx.lockZone(zone)
		local boss, stats = ctx.spawnEnemy(zone, keeper.typeId, keeper.at, { introDelay = keeper.intro })
		zone.boss = boss
		local credit = boss.onDeath
		boss.onDeath = function(dead, attacker)
			if credit then
				credit(dead, attacker)
			end
			for _, enemy in ipairs(zone.enemies) do
				if enemy ~= dead and enemy.alive then
					EnemyService.kill(enemy, nil)
				end
			end
			ctx.clearZone(zone)
			if cfg.chest then
				task.delay(1.2, function()
					if zone.state == "cleared" and ctx.state.folder then
						ctx.spawnChest(zone, cfg.chest)
					end
				end)
			end
		end
		-- «Переплёт» (50 %): кляксы из точек скриптория, а не вокруг босса.
		boss.onPhase = function(_, _, phase)
			local summon = phase and phase.summon
			if not summon then
				return
			end
			local points = cfg.points.summons
			for index = 1, summon.count do
				ctx.spawnEnemy(zone, summon.typeId, points[((index - 1) % #points) + 1])
			end
			ctx.fire({ kind = "f5bind", position = boss.position, points = points })
		end
		ctx.fire({
			kind = "bossIntro",
			room = zone.index,
			name = stats.name,
			title = stats.title or "",
			duration = keeper.intro,
			model = boss.model,
			position = boss.position,
			miniBoss = true,
		})
	end

	-- ===== Хранилище полок: книгопад =====

	local function dropBook(position: Vector3)
		local b = Traps.bookfall
		ctx.fire({ kind = "f5bookfall", phase = "warn", position = position, radius = b.radius, duration = b.warn })
		task.delay(b.warn, function()
			ctx.fire({ kind = "f5bookfall", phase = "hit", position = position, radius = b.radius })
			for _, player in ipairs(ctx.floorPlayers()) do
				local root = ctx.rootOf(player)
				if root and flat(root.Position - position).Magnitude <= b.radius and math.abs(root.Position.Y - FEET - position.Y) < 4 then
					CombatService.damagePlayer(player, b.damage, { source = "Книгопад", position = position })
				end
			end
			BreakableService.areaHit(Config.FloorId, position, b.radius, 30)
		end)
	end

	local function stepBookfall(t: number)
		local zone = ctx.zoneById("stacks")
		if not zone or zone.state ~= "active" or t < world.bookfallAt then
			return
		end
		local b = Traps.bookfall
		world.bookfallAt = t + b.every
		local inside = playersInBox(zone.cfg.box)
		local area = zone.cfg.bookfall[math.random(1, #zone.cfg.bookfall)]
		local floorY = zone.cfg.start and zone.cfg.start.Y or 0
		for k = 1, b.count do
			local position
			if k == 1 and #inside > 0 then
				local victim = inside[math.random(1, #inside)].root.Position
				position = Vector3.new(victim.X, victim.Y - FEET, victim.Z)
			else
				position = Vector3.new(
					area[1] + math.random() * (area[3] - area[1]),
					floorY,
					area[2] + math.random() * (area[4] - area[2])
				)
			end
			position = Vector3.new(position.X, FloorGeo.groundAt(position.X, position.Z, position.Y + 3) or position.Y, position.Z)
			dropBook(position)
		end
	end

	-- ===== Купол: печати II фазы =====

	local function setSealsAttr(boss, count: number)
		if boss and boss.model and boss.model.Parent then
			boss.model:SetAttribute("F5SealsUp", count)
		end
	end

	local function raiseSeals(zone, boss, cfg)
		local list = {}
		boss.sealsUp = 0
		for _, point in ipairs(zone.cfg.points.seals) do
			local seal = ctx.spawnEnemy(zone, cfg.typeId, point, { noCredit = true, bounds = false })
			-- Луч печать → Хронист (клиент Floor45Fx).
			local link = Instance.new("ObjectValue")
			link.Name = "F45WardTarget"
			link.Value = boss.model
			link.Parent = seal.model
			seal.onSealBroken = function()
				if not boss.alive then
					return
				end
				boss.sealsUp = math.max(0, (boss.sealsUp or 1) - 1)
				setSealsAttr(boss, boss.sealsUp)
				if boss.sealsUp == 0 then
					EnemyService.stun(boss, cfg.stun, true)
					ctx.fire({ kind = "f5sealsDown", model = boss.model, position = boss.position, duration = cfg.stun })
				end
			end
			boss.sealsUp += 1
			table.insert(list, seal)
		end
		setSealsAttr(boss, boss.sealsUp)
		world.seals = { list = list, boss = boss }
		ctx.fire({ kind = "f5seals", model = boss.model, positions = zone.cfg.points.seals })
	end

	-- ===== Купол: стирание III фазы =====

	local function setErasureAttr(value: string?)
		if ctx.state.folder then
			ctx.state.folder:SetAttribute("F5Erasure", value)
		end
	end

	local function startErasure(zone, cfg)
		local t = ctx.now()
		local center = zone.cfg.points.center
		world.erasure = { t0 = t, center = center, cfg = cfg, nextTick = t + 1 }
		setErasureAttr(("%.2f,%.2f,%.2f,%.2f,%.2f,%.3f,%.2f"):format(center.X, center.Y, center.Z, cfg.startRadius, cfg.endRadius, t, cfg.shrinkTime))
		ctx.fire({ kind = "f5erasure", phase = "start", position = center, from = cfg.startRadius, to = cfg.endRadius, time = cfg.shrinkTime, startedAt = t })
	end

	local function stopErasure()
		if world.erasure then
			world.erasure = nil
			setErasureAttr(nil)
			ctx.fire({ kind = "f5erasure", phase = "stop" })
		end
	end

	local function erasureRadius(t: number): number
		local e = world.erasure
		local a = math.clamp((t - e.t0) / e.cfg.shrinkTime, 0, 1)
		return e.cfg.startRadius + (e.cfg.endRadius - e.cfg.startRadius) * a
	end

	local function stepErasure(zone, t: number)
		local e = world.erasure
		if not e or t < e.nextTick then
			return
		end
		e.nextTick = t + e.cfg.tick
		local radius = erasureRadius(t)
		for _, entry in ipairs(playersInBox(zone.cfg.box)) do
			if flat(entry.root.Position - e.center).Magnitude > radius then
				CombatService.damagePlayer(entry.player, e.cfg.damage, { source = "Стирание", position = entry.root.Position })
			end
		end
	end

	local function stepBoss(t: number)
		local zone = ctx.zoneById("dome")
		if not zone or zone.state ~= "active" then
			return
		end
		local boss = zone.boss
		if not boss or not boss.alive then
			return
		end
		local phases = boss.stats.phases or {}
		local index = boss.phaseIndex or 1
		if index ~= world.bossPhase then
			world.bossPhase = index
			local entered = phases[index - 1]
			if entered and entered.seals and not world.seals then
				raiseSeals(zone, boss, entered.seals)
			end
			if entered and entered.erasure and not world.erasure then
				-- Стирание пойдёт, когда кончится сцена фазы.
				world.erasurePending = entered.erasure
			end
		end
		if world.erasurePending and t >= (boss.sceneUntil or 0) then
			startErasure(zone, world.erasurePending)
			world.erasurePending = nil
		end
		stepErasure(zone, t)
	end

	local function resetDome()
		stopErasure()
		world.erasurePending = nil
		world.seals = nil
		world.bossPhase = 1
	end

	-- ===== Обрыв хроники: эпилог =====

	local function stepEpilogue()
		local zone = ctx.zoneById("beyond")
		if not zone or not zone.cfg.epilogue then
			return
		end
		local point = zone.cfg.epilogue
		local e = Config.Epilogue
		for _, entry in ipairs(playersInBox(zone.cfg.box)) do
			if not world.epilogue[entry.player] and flat(entry.root.Position - point).Magnitude <= e.radius then
				world.epilogue[entry.player] = true
				entry.player:SetAttribute("F5Epilogue", true)
				ctx.fire({ kind = "f5epilogue", title = e.title, text = e.text, sub = e.sub, position = point }, entry.player)
			end
		end
	end

	-- ===== Хуки этажа =====

	function hooks.beforeBuild()
		Floor45Service.clearHazards(Config.Offset.X)
		world.bookfallAt = 0
		world.epilogue = {}
		resetDome()
	end

	function hooks.build()
		BreakableService.build(Config.FloorId)
		setErasureAttr(nil)
	end

	local acc, slow = 0, 0
	function hooks.step(_, t: number, dt: number)
		acc += dt or 0
		if acc < 0.05 then
			return
		end
		slow += acc
		acc = 0
		stepBookfall(t)
		stepBoss(t)
		if slow >= 0.25 then
			slow = 0
			stepEpilogue()
		end
	end

	function hooks.zoneActivated(_, zone)
		local id = zone.cfg.id
		if zone.cfg.kind == "keeper" then
			activateKeeper(zone)
		elseif id == "stacks" then
			world.bookfallAt = ctx.now() + 4
		elseif id == "dome" then
			resetDome()
		end
	end

	function hooks.zoneCleared(_, zone)
		local id = zone.cfg.id
		if id == "stacks" or id == "readingroom" or id == "scriptorium" then
			Floor45Service.clearHazardsIn(zone.cfg.box)
		end
		if id == "dome" then
			resetDome()
			Floor45Service.clearHazardsIn(zone.cfg.box)
			-- Створки открывает FloorService (finishFloor → Map.openVault).
			ctx.fire({ kind = "f5vault", position = zone.cfg.points.center })
		end
	end

	function hooks.zoneReset(_, zone)
		local id = zone.cfg.id
		if id == "dome" then
			resetDome()
		end
		if zone.cfg.kind == "arena" or zone.cfg.kind == "keeper" or zone.cfg.kind == "boss" then
			Floor45Service.clearHazardsIn(zone.cfg.box)
		end
	end

	function hooks.resetPlayer(_, player)
		Floor45Service.sendHazardsTo(player)
		world.epilogue[player] = nil
		player:SetAttribute("F5Epilogue", nil)
	end

	Players.PlayerRemoving:Connect(function(player)
		world.epilogue[player] = nil
	end)
end

return Floor5World
