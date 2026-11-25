--!nonstrict
-- Floor2World (сервер)
-- Особое этажа 2 «Затопленные сады» поверх общего FloorService (хуки экземпляра
-- этажа: build, step, zoneActivated, zoneCleared, zoneReset, resetPlayer):
--
--   вентили шлюзов   три вентиля (ProximityPrompt «Повернуть вентиль»): беседка
--                    в лабиринте, купальня, мельница; открываются после зачистки
--                    своей зоны. Каждый опускает воду Розового двора, после
--                    трёх поднимается решётка шлюза. Атрибут игрока F2Valves.
--   заросшие стены   объект «Заросшая стена» перед секретом: разбил — проход
--   постоянные лужи  гниль на аллее, мёд на пасеке, вода купальни (Floor2Service)
--   ловушки          шипы лоз в лабиринте, гнилые доски каналов, пролёт акведука,
--                    струи гнили фонтана и споры террас (пока идёт арена),
--                    статуи-стрелки сада статуй (нажимные плиты)
--
-- Картинка — клиент Floor2Fx (события FloorEvent kind f2*, атрибуты карты).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")


local CombatService = require(script.Parent.CombatService)
local ProjectileService = require(script.Parent.ProjectileService)
local Floor2Service = require(script.Parent.Floor2Service)

local Floor2World = {}

local FEET = 3.0

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Floor2World.attach(ctx, hooks)
	local Config = ctx.Config
	local Map = ctx.Map
	local Traps = Config.Traps
	local world = {
		valves = {}, -- [id] = { prompt, unlocked, turned, cfg }
		turned = 0,
		floodBase = nil,
		walls = {}, -- [zoneId] = объект-стена (враг)
		spikes = {}, -- шипы лабиринта
		planks = {}, -- [model] = { standSince }
		span = nil, -- { state = "idle"|"crack"|"down", at }
		jetsAt = 0,
		sporesAt = 0,
		darts = {}, -- [index] = { readyAt, pendingAt }
		lastSpikeHit = {},
		permanent = {},
	}

	local function zoneCfg(id: string)
		return Config.byId(id)
	end

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

	-- ===== Вода двора и решётка шлюза =====

	local function floodModel()
		return Map.dynamic("F2Flood")
	end

	local function setFlood(level: number, instant: boolean?)
		local model = floodModel()
		if not model then
			return
		end
		world.floodBase = world.floodBase or model:GetPivot()
		local target = world.floodBase - Vector3.new(0, Config.FloodDrop * level, 0)
		if level >= #Config.Valves then
			target = world.floodBase - Vector3.new(0, 6, 0) -- ушла под пол
		end
		if instant then
			model:PivotTo(target)
			return
		end
		local value = Instance.new("CFrameValue")
		value.Value = model:GetPivot()
		value.Changed:Connect(function(cf)
			if model.Parent then
				model:PivotTo(cf)
			end
		end)
		local tween = TweenService:Create(value, TweenInfo.new(3.5, Enum.EasingStyle.Sine), { Value = target })
		tween.Completed:Connect(function()
			value:Destroy()
		end)
		tween:Play()
	end

	local function publishValves()
		for _, player in ipairs(ctx.floorPlayers()) do
			player:SetAttribute("F2Valves", world.turned)
		end
		if ctx.state.folder then
			ctx.state.folder:SetAttribute("Valves", world.turned)
			ctx.state.folder:SetAttribute("ValvesTotal", #Config.Valves)
		end
	end

	local function setValveEnabled(id: string, enabled: boolean)
		local valve = world.valves[id]
		if valve then
			valve.unlocked = enabled
			valve.prompt.Enabled = enabled and not valve.turned
			valve.anchor:SetAttribute("Unlocked", enabled)
		end
	end

	local function turnValve(id: string, player)
		local valve = world.valves[id]
		if not valve or valve.turned or not valve.unlocked then
			return
		end
		valve.turned = true
		valve.prompt.Enabled = false
		valve.anchor:SetAttribute("Turned", true)
		world.turned += 1
		publishValves()
		setFlood(world.turned)
		ctx.fire({
			kind = "f2valve",
			id = id,
			name = valve.cfg.name,
			count = world.turned,
			total = #Config.Valves,
			position = valve.cfg.at,
			by = player,
		})
		if world.turned >= #Config.Valves then
			task.delay(2.5, function()
				Map.setGate(Config.SluiceGate, true)
				ctx.fire({ kind = "f2sluice", open = true, position = Map.gatePosition(Config.SluiceGate) })
			end)
		end
	end

	local function buildValves(runtime)
		world.valves = {}
		world.turned = 0
		for _, cfg in ipairs(Config.Valves) do
			local anchor = Instance.new("Part")
			anchor.Name = "Valve_" .. cfg.id
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			anchor.Transparency = 1
			anchor.Size = Vector3.new(3, 3, 3)
			anchor.CFrame = CFrame.new(cfg.at + Vector3.new(0, 2.2, 0))
			anchor:SetAttribute("ValveId", cfg.id)
			anchor:SetAttribute("Unlocked", false)
			anchor:SetAttribute("Turned", false)
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "ValvePrompt"
			prompt.ActionText = "Повернуть вентиль"
			prompt.ObjectText = cfg.name
			prompt.HoldDuration = Config.ValveHold
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.Enabled = false
			prompt.Parent = anchor
			anchor.Parent = runtime
			prompt.Triggered:Connect(function(player)
				if ctx.onFloor(player) then
					turnValve(cfg.id, player)
				end
			end)
			world.valves[cfg.id] = { prompt = prompt, anchor = anchor, cfg = cfg, unlocked = false, turned = false }
		end
		publishValves()
	end

	-- ===== Заросшие стены =====

	local function spawnWall(zone)
		local cfg = zone.cfg
		if not cfg.secret or not cfg.secretAt then
			return
		end
		local model = Map.dynamic(cfg.secret)
		if not model or model:GetAttribute("Broken") then
			return
		end
		if world.walls[cfg.id] and world.walls[cfg.id].alive then
			return
		end
		local wall = ctx.spawnEnemy(zone, "overgrowth", cfg.secretAt, { noCredit = true, bounds = false })
		wall.onDeath = function()
			local position = Map.destroyDynamic(cfg.secret)
			ctx.fire({ kind = "f2secret", zone = cfg.id, name = cfg.name, position = position or cfg.secretAt })
		end
		world.walls[cfg.id] = wall
	end

	-- ===== Шипы лабиринта (всегда, пока рядом игроки) =====

	local function spikePhase(t: number): string
		local s = Traps.spikes
		local cycle = s.idle + s.warn + s.active
		local p = t % cycle
		if p < s.idle then
			return "idle"
		elseif p < s.idle + s.warn then
			return "warn"
		end
		return "active"
	end

	local function stepSpikes(t: number)
		if #world.spikes == 0 then
			return
		end
		local maze = zoneCfg("maze")
		local inside = playersInBox(maze.box)
		local phase = #inside > 0 and spikePhase(t) or "idle"
		for _, trap in ipairs(world.spikes) do
			Map.setSpikePhase(trap, phase)
		end
		if phase ~= "active" then
			return
		end
		local s = Traps.spikes
		for _, entry in ipairs(inside) do
			for _, trap in ipairs(world.spikes) do
				if flat(entry.root.Position - trap.position).Magnitude <= s.radius and math.abs(entry.root.Position.Y - FEET - trap.position.Y) < 3 then
					if t - (world.lastSpikeHit[entry.player] or -10) >= s.tick then
						world.lastSpikeHit[entry.player] = t
						CombatService.resolveIncomingAttack(entry.player, { damage = s.damage, parryable = false, source = "Thorns", position = trap.position })
						Floor2Service.poison(entry.player, 0.02, 1.5)
					end
					break
				end
			end
		end
	end

	-- ===== Гнилые доски каналов =====

	local function stepPlanks(t: number)
		local canals = zoneCfg("canals")
		local inside = playersInBox(canals.box)
		if #inside == 0 then
			return
		end
		local p = Traps.planks
		for _, model in ipairs(Map.dynamicsMatching(canals.planks)) do
			local record = world.planks[model]
			if not record then
				record = { center = model:GetBoundingBox().Position }
				world.planks[model] = record
			end
			if model:GetAttribute("Broken") then
				record.standSince = nil
				continue
			end
			local standing = false
			for _, entry in ipairs(inside) do
				local feet = entry.root.Position - Vector3.new(0, FEET, 0)
				if flat(feet - record.center).Magnitude <= p.radius + 0.6 and math.abs(feet.Y - record.center.Y) < 1.5 then
					standing = true
				end
			end
			if standing then
				if not record.standSince then
					record.standSince = t
					ctx.fire({ kind = "f2plank", phase = "crack", position = record.center })
				elseif t - record.standSince >= p.hold then
					record.standSince = nil
					local centers = Map.breakTiles(model.Name, record.center, 0.5, p.back)
					if #centers > 0 then
						ctx.fire({ kind = "f2plank", phase = "break", position = record.center, duration = p.back })
					end
				end
			else
				record.standSince = nil
			end
		end
	end

	-- ===== Пролёт акведука =====

	local function stepSpan(t: number)
		local aq = zoneCfg("aqueduct")
		local span = aq.span
		world.span = world.span or { state = "idle", at = 0 }
		local s = world.span
		local model = Map.dynamic(span.name)
		if not model then
			return
		end
		if s.state == "idle" then
			for _, entry in ipairs(playersInBox(aq.box)) do
				local d = entry.root.Position - span.at
				if math.abs(d.X) <= span.half.X and math.abs(d.Z) <= span.half.Z then
					s.state = "crack"
					s.at = t
					ctx.fire({ kind = "f2span", phase = "crack", position = span.at, duration = Traps.span.crack })
					break
				end
			end
		elseif s.state == "crack" and t - s.at >= Traps.span.crack then
			s.state = "down"
			s.at = t
			Map.breakTiles(span.name, span.at, 4, Traps.span.back)
			ctx.fire({ kind = "f2span", phase = "fall", position = span.at, duration = Traps.span.back })
		elseif s.state == "down" and t - s.at >= Traps.span.back + 0.5 then
			s.state = "idle"
			ctx.fire({ kind = "f2span", phase = "back", position = span.at })
		end
	end

	-- ===== Струи фонтана и споры террас (пока арена активна) =====

	local function burstAt(kind: string, position: Vector3, radius: number, life: number, warn: number)
		ctx.fire({ kind = kind, phase = "warn", position = position, radius = radius, duration = warn })
		task.delay(warn, function()
			local hazard = kind == "f2spore" and "spore" or "rot"
			Floor2Service.addHazard(hazard, position, radius, life)
			ctx.fire({ kind = kind, phase = "burst", position = position, radius = radius, duration = life })
			-- Кто стоял в центре — сразу получает гниль.
			for _, player in ipairs(ctx.floorPlayers()) do
				local root = ctx.rootOf(player)
				if root and flat(root.Position - position).Magnitude <= radius and math.abs(root.Position.Y - FEET - position.Y) < 3 then
					Floor2Service.poison(player, kind == "f2spore" and Traps.spores.poison or 0.04, 2.0)
				end
			end
		end)
	end

	local function stepArenaTraps(t: number)
		for _, zone in ipairs(ctx.state.rooms) do
			if zone.state == "active" then
				local cfg = zone.cfg
				if cfg.jets and t >= world.jetsAt then
					world.jetsAt = t + Traps.jets.every
					local order = { 1, 2, 3, 4 }
					for i = #order, 2, -1 do
						local j = math.random(1, i)
						order[i], order[j] = order[j], order[i]
					end
					for k = 1, Traps.jets.count do
						burstAt("f2jet", cfg.jets[order[k]], Traps.jets.radius, Traps.jets.life, Traps.jets.warn)
					end
				end
				if cfg.spores and t >= world.sporesAt then
					world.sporesAt = t + Traps.spores.every
					local point = cfg.spores[math.random(1, #cfg.spores)]
					burstAt("f2spore", point, Traps.spores.radius, Traps.spores.life, Traps.spores.warn)
				end
			end
		end
	end

	-- ===== Статуи-стрелки =====

	local function stepDarts(t: number)
		local statues = zoneCfg("statues")
		local inside = playersInBox(statues.box)
		if #inside == 0 then
			return
		end
		local d = Traps.darts
		for index, dart in ipairs(statues.darts) do
			local record = world.darts[index]
			if not record then
				record = { readyAt = 0 }
				world.darts[index] = record
			end
			if record.pendingAt and t >= record.pendingAt then
				record.pendingAt = nil
				local origin = dart.from + flat(dart.plate - dart.from).Unit * 2.2
				local target = dart.plate + Vector3.new(0, 2.4, 0)
				local dir = (target - origin).Unit
				for k = 1, d.count do
					local angle = math.rad((k - (d.count + 1) / 2) * d.spread)
					local shot = CFrame.Angles(0, angle, 0):VectorToWorldSpace(dir)
					ProjectileService.fire(ctx.state.folder, origin, shot, {
						speed = d.speed,
						damage = d.damage,
						parryable = false,
						source = "Statue",
						kind = "thorn",
						lifetime = 1.6,
					})
				end
				ctx.fire({ kind = "f2dart", phase = "fire", position = origin, target = dart.plate })
			elseif not record.pendingAt and t >= record.readyAt then
				for _, entry in ipairs(inside) do
					local feet = entry.root.Position - Vector3.new(0, FEET, 0)
					if flat(feet - dart.plate).Magnitude <= d.plate and math.abs(feet.Y - dart.plate.Y) < 2 then
						record.pendingAt = t + d.warn
						record.readyAt = t + d.cooldown
						ctx.fire({ kind = "f2dart", phase = "warn", position = dart.from, plate = dart.plate, duration = d.warn })
						break
					end
				end
			end
		end
	end

	-- ===== Хуки этажа =====

	function hooks.beforeBuild()
		Floor2Service.clearHazards()
		world.planks = {}
		world.span = nil
		world.walls = {}
		world.darts = {}
		if world.floodBase then
			setFlood(0, true)
		end
	end

	function hooks.build()
		local runtime = Workspace:FindFirstChild(Config.RuntimeName)
		if not runtime then
			runtime = Instance.new("Folder")
			runtime.Name = Config.RuntimeName
			runtime.Parent = Workspace
		end
		local old = runtime:FindFirstChild("Floor2World")
		if old then
			old:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "Floor2World"
		folder.Parent = runtime
		buildValves(folder)
		world.floodBase = nil
		setFlood(0, true)
		Map.setGate(Config.SluiceGate, false, true)
		-- постоянные лужи
		world.permanent = {}
		for _, zone in ipairs(ctx.state.rooms) do
			for _, h in ipairs(zone.cfg.hazards or {}) do
				local hazard = Floor2Service.addHazard(h[1], h[2], h[3], math.huge)
				table.insert(world.permanent, hazard)
			end
			spawnWall(zone)
		end
		-- шипы лабиринта
		world.spikes = {}
		local maze = zoneCfg("maze")
		for _, point in ipairs(maze.spikes or {}) do
			table.insert(world.spikes, Map.makeSpikes(point))
		end
	end

	function hooks.step(_, t: number)
		stepSpikes(t)
		stepPlanks(t)
		stepSpan(t)
		stepArenaTraps(t)
		stepDarts(t)
	end

	function hooks.zoneActivated(_, zone)
		if zone.cfg.id == "rosecourt" then
			-- Бой с Садовницей: шлюз за спиной закрывается.
			Map.setGate(Config.SluiceGate, false)
		end
		if zone.cfg.jets then
			world.jetsAt = ctx.now() + 3
		end
		if zone.cfg.spores then
			world.sporesAt = ctx.now() + 4
		end
		if zone.cfg.id == "mill" then
			local map = Map.map()
			if map then
				map:SetAttribute("F2MillSpin", true)
			end
		end
	end

	function hooks.zoneCleared(_, zone)
		local cfg = zone.cfg
		if cfg.valve then
			setValveEnabled(cfg.valve, true)
			ctx.fire({ kind = "f2valveReady", id = cfg.valve, position = world.valves[cfg.valve] and world.valves[cfg.valve].cfg.at })
		end
		if cfg.id == "rosecourt" then
			Map.setGate(Config.SluiceGate, true)
		end
		if cfg.id == "mill" then
			local map = Map.map()
			if map then
				map:SetAttribute("F2MillSpin", false)
			end
		end
	end

	function hooks.zoneReset(_, zone)
		spawnWall(zone)
		if zone.cfg.id == "rosecourt" and world.turned >= #Config.Valves then
			Map.setGate(Config.SluiceGate, true)
		end
		if zone.cfg.id == "mill" then
			local map = Map.map()
			if map then
				map:SetAttribute("F2MillSpin", false)
			end
		end
	end

	function hooks.resetPlayer(_, player)
		player:SetAttribute("F2Valves", world.turned)
		Floor2Service.sendHazardsTo(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		world.lastSpikeHit[player] = nil
	end)
end

return Floor2World
