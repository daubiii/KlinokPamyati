--!nonstrict
-- Floor4World (сервер)
-- Особое этажа 4 «Литейные» поверх общего FloorService (хуки экземпляра этажа):
--
--   вагонетка      Рудничная улица: каждые Traps.cart.every с колокол
--                  (предупреждение по рельсам), затем вагонетка катится от
--                  CART_FROM к CART_TO — кто на рельсах, получает урон и
--                  отлетает вбок. Только пока на улице есть игроки.
--   ковши          Литейная (пока идёт бой): разливы в точках SPILL_* —
--                  предупреждение, потом лужа расплава.
--   клеть          удержание (FloorService, kind hold) — здесь только рычаг
--                  и звук подъёмника.
--   Великий горн   II фаза литейщика — разливы по жёлобам (POUR_*); III —
--                  случайные расплавы по арене (часть — под ноги игрокам).
--   декорации      BreakableService.build(4) при каждой сборке этажа.
--
-- Картинка — клиент Floor45Fx (события FloorEvent kind f4*, лужи — EnemyEvent).

local Players = game:GetService("Players")

local CombatService = require(script.Parent.CombatService)
local Floor45Service = require(script.Parent.Floor45Service)
local BreakableService = require(script.Parent.BreakableService)

local Floor4World = {}

local FEET = 3.0

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function shuffled(list)
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.random(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

function Floor4World.attach(ctx, hooks)
	local Config = ctx.Config
	local Traps = Config.Traps
	local world = {
		cart = { state = "idle", nextAt = 0, startT = 0, hit = {} },
		spillsAt = 0,
		channelsAt = 0,
		meltAt = 0,
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

	-- Призыв (литейщик, кляксы и т. п.) идёт через зону — враг в счёте арены.
	Floor45Service.registerSpawner(function(zone, typeId, position)
		if ownsZone(zone) then
			return (ctx.spawnEnemy(zone, typeId, position))
		end
		return nil
	end)

	-- Предупреждение, затем лужа расплава.
	local function pourAt(kindName: string, position: Vector3, cfg, from: Vector3?)
		ctx.fire({ kind = kindName, phase = "warn", position = position, radius = cfg.radius, duration = cfg.warn, from = from })
		task.delay(cfg.warn, function()
			Floor45Service.addHazard("molten", position, cfg.radius, cfg.life)
			ctx.fire({ kind = kindName, phase = "burst", position = position, radius = cfg.radius, duration = cfg.life })
			BreakableService.areaHit(Config.FloorId, position, cfg.radius, 40)
		end)
	end

	-- ===== Вагонетка Рудничной улицы =====

	local function stepCart(t: number)
		local zone = ctx.zoneById("railway")
		if not zone then
			return
		end
		local cfg = zone.cfg.cart
		local c = Traps.cart
		local cart = world.cart
		if cart.state == "idle" then
			if #playersInBox(zone.cfg.box) == 0 then
				cart.nextAt = math.max(cart.nextAt, t + 3)
				return
			end
			if t >= cart.nextAt then
				cart.state = "warn"
				cart.startT = t
				ctx.fire({ kind = "f4cart", phase = "warn", from = cfg.from, to = cfg.to, width = c.width, duration = c.warn })
			end
		elseif cart.state == "warn" then
			if t - cart.startT >= c.warn then
				cart.state = "run"
				cart.startT = t
				cart.hit = {}
				ctx.fire({ kind = "f4cart", phase = "run", from = cfg.from, to = cfg.to, width = c.width, duration = c.time })
			end
		elseif cart.state == "run" then
			local alpha = (t - cart.startT) / c.time
			if alpha >= 1 then
				cart.state = "idle"
				cart.nextAt = t + c.every
				ctx.fire({ kind = "f4cart", phase = "done", from = cfg.from, to = cfg.to })
				return
			end
			local path = flat(cfg.to - cfg.from)
			local dir = path.Unit
			local side = Vector3.new(-dir.Z, 0, dir.X)
			local head = cfg.from:Lerp(cfg.to, alpha)
			for _, entry in ipairs(playersInBox(zone.cfg.box)) do
				if not cart.hit[entry.player] then
					local rel = flat(entry.root.Position - head)
					local along = rel:Dot(dir)
					local across = rel:Dot(side)
					local dy = entry.root.Position.Y - FEET - head.Y
					if math.abs(along) <= 2.4 and math.abs(across) <= c.width / 2 + 0.6 and dy > -2 and dy < 4 then
						cart.hit[entry.player] = true
						CombatService.damagePlayer(entry.player, c.damage, { source = "Вагонетка", position = head })
						-- Отбросить с рельсов в сторону, куда игрок ближе.
						local sign = across >= 0 and 1 or -1
						local shift = side * sign * (c.width / 2 + 1.8) - side * across
						local push = shift + side * sign * (c.knock * 0.15)
						entry.root.CFrame = entry.root.CFrame + push + Vector3.new(0, 0.6, 0)
						entry.root.AssemblyLinearVelocity = side * sign * c.knock + Vector3.new(0, c.knock * 0.6, 0)
						ctx.fire({ kind = "f4cartHit", position = entry.root.Position, by = entry.player })
					end
				end
			end
		end
	end

	-- ===== Ковши Литейной (пока арена активна) =====

	local function stepSpills(t: number)
		local zone = ctx.zoneById("foundry")
		if not zone or zone.state ~= "active" or t < world.spillsAt then
			return
		end
		local s = Traps.spills
		world.spillsAt = t + s.every
		local order = shuffled(zone.cfg.spills)
		for k = 1, math.min(s.count, #order) do
			pourAt("f4spill", order[k], s, order[k] + Vector3.new(0, 12, 0))
		end
	end

	-- ===== Великий горн: фазы литейщика =====

	local function stepBoss(t: number)
		local zone = ctx.zoneById("greatforge")
		if not zone or zone.state ~= "active" then
			return
		end
		local boss = zone.boss
		if not boss or not boss.alive then
			return
		end
		if t < (boss.sceneUntil or 0) then
			return
		end
		local phases = boss.stats.phases or {}
		local index = boss.phaseIndex or 1
		local pts = zone.cfg.points
		if index ~= world.bossPhase then
			world.bossPhase = index
			world.channelsAt = t + 2
			world.meltAt = t + 1.5
		end
		-- II: жёлоба (POUR_*)
		local two = phases[1] and phases[1].channels
		if index == 2 and two and t >= world.channelsAt then
			world.channelsAt = t + two.every
			local order = shuffled(pts.pours)
			for k = 1, math.min(two.count, #order) do
				pourAt("f4pour", order[k], two, order[k] + Vector3.new(0, 14, 0))
			end
		end
		-- III: случайные расплавы (один — под ноги игроку)
		local three = phases[2] and phases[2].melt
		if index >= 3 and three and t >= world.meltAt then
			world.meltAt = t + three.every
			local inside = playersInBox(zone.cfg.box)
			for k = 1, three.count do
				local position
				if k == 1 and #inside > 0 then
					local victim = inside[math.random(1, #inside)].root.Position
					position = Vector3.new(victim.X, pts.center.Y, victim.Z)
				else
					local a = math.random() * math.pi * 2
					local r = math.sqrt(math.random()) * pts.radius * 0.8
					position = pts.center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				end
				pourAt("f4melt", position, three, nil)
			end
		end
	end

	-- ===== Хуки этажа =====

	function hooks.beforeBuild()
		Floor45Service.clearHazards(Config.Offset.X)
		world.cart = { state = "idle", nextAt = 0, startT = 0, hit = {} }
		world.spillsAt = 0
		world.bossPhase = 1
	end

	function hooks.build()
		BreakableService.build(Config.FloorId)
		local map = ctx.Map.map()
		if map then
			map:SetAttribute("F4CageRun", false)
		end
	end

	local acc = 0
	function hooks.step(_, t: number, dt: number)
		acc += dt or 0
		if acc < 0.05 then
			return
		end
		acc = 0
		stepCart(t)
		stepSpills(t)
		stepBoss(t)
	end

	function hooks.zoneActivated(_, zone)
		local id = zone.cfg.id
		if id == "foundry" then
			world.spillsAt = ctx.now() + 4
		elseif id == "cage" then
			-- Рычаг клети: лебёдка пошла, решётка поднимается (FloorService.stepHold).
			ctx.fire({ kind = "f4lever", position = zone.cfg.lever })
			local map = ctx.Map.map()
			if map then
				map:SetAttribute("F4CageRun", true)
			end
		elseif id == "greatforge" then
			world.bossPhase = 1
		end
	end

	function hooks.zoneCleared(_, zone)
		local id = zone.cfg.id
		if id == "foundry" or id == "greatforge" then
			Floor45Service.clearHazardsIn(zone.cfg.box)
		end
		if id == "cage" then
			local map = ctx.Map.map()
			if map then
				map:SetAttribute("F4CageRun", false)
			end
		end
		if id == "greatforge" then
			ctx.fire({ kind = "f4forgeCooled", position = zone.cfg.points.center })
		end
	end

	function hooks.zoneReset(_, zone)
		local id = zone.cfg.id
		if id == "foundry" or id == "greatforge" or id == "cage" then
			Floor45Service.clearHazardsIn(zone.cfg.box)
		end
		if id == "cage" then
			local map = ctx.Map.map()
			if map then
				map:SetAttribute("F4CageRun", false)
			end
		end
		world.bossPhase = 1
	end

	function hooks.resetPlayer(_, player)
		Floor45Service.sendHazardsTo(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		world.cart.hit[player] = nil
	end)
end

return Floor4World
