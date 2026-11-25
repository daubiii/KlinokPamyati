--!nonstrict
-- Floor3World (сервер)
-- Особое этажа 3 «Псарни охоты» поверх общего FloorService (хуки экземпляра этажа:
-- beforeBuild, build, step, zoneActivated, zoneCleared, zoneReset, resetPlayer):
--
--   трофеи        Т1 «Перо сокола» (Сокольня), Т2 «Рог егерей» (Вышка егерей),
--                 Т3 «Клык вожака» (Королевская псарня) — ProximityPrompt «Взять
--                 трофей» после зачистки своей зоны. Каждый зажигает жаровню на
--                 донжоне; после трёх поднимается Трофейная решётка замка.
--                 Атрибут игрока F3Trophies, папки этажа — Trophies/TrophiesTotal.
--   ветхие стены  объект «Ветхая стена» перед тайником (доски, шкуры, гобелен):
--                 разбил — проход
--   клетки        двери клеток и денников поднимаются, когда рядом появился враг
--   лужи          грязь и дёготь — замедляют (Floor2Service.slow — общий статус)
--   ловушки       капканы (манеж, тропа), растяжки с колокольцами (тропа),
--                 самострелы на плитах (стрельбище), пролёт моста (рушится),
--                 люстры Трофейного зала (пока идёт арена), сорвавшаяся телега
--                 конюшен
--   ловчий        босс ристалища запрыгивает на вышки и мечет копья
--
-- Картинка — клиент Floor3Fx (события FloorEvent kind f3*). Детали, которых нет
-- в мешах карты (трофеи, капканы, огонь жаровен), создаются здесь.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FloorGeo = require(ReplicatedStorage.Shared.Floor.FloorGeo)
local CombatService = require(script.Parent.CombatService)
local EnemyService = require(script.Parent.EnemyService)
local ProjectileService = require(script.Parent.ProjectileService)
local Floor2Service = require(script.Parent.Floor2Service) -- общие статусы: slow, root

local Floor3World = {}

local FEET = 3.0
local V3 = Vector3.new
local hex = Color3.fromHex

local COLORS = {
	iron = hex("#3A3436"),
	ironLight = hex("#6E6660"),
	ember = hex("#FF7A2A"),
	flame = hex("#FFB347"),
	gold = hex("#D9A441"),
	bone = hex("#E8DCC0"),
	blood = hex("#8C3B2E"),
	warn = hex("#C8442E"),
}

local function flat(v: Vector3): Vector3
	return V3(v.X, 0, v.Z)
end

local function part(parent, props)
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = props.CastShadow == true
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	-- Форма раньше размера: Ball выравнивает Size, порядок pairs не задан.
	if props.Shape then
		p.Shape = props.Shape
	end
	for key, value in pairs(props) do
		if key ~= "Class" and key ~= "CastShadow" and key ~= "Material" and key ~= "Shape" then
			p[key] = value
		end
	end
	p.Parent = parent
	return p
end

-- Сдвинуть модель твином (у Model нет свойства для твина — через CFrameValue).
local function tweenPivot(model, target: CFrame, info: TweenInfo, done)
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(cf)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	local tween = TweenService:Create(value, info, { Value = target })
	tween.Completed:Connect(function()
		value:Destroy()
		if done then
			done()
		end
	end)
	tween:Play()
	return tween
end

function Floor3World.attach(ctx, hooks)
	local Config = ctx.Config
	local Map = ctx.Map
	local Traps = Config.Traps
	local world = {
		folder = nil,
		trophies = {}, -- [id] = { cfg, index, anchor, prompt, model, unlocked, taken }
		taken = 0,
		braziers = {}, -- [index] = { fire, light, coals }
		signal = nil,
		walls = {}, -- [zoneId] = объект-стена
		cages = {}, -- [door] = true — поднята
		seen = setmetatable({}, { __mode = "k" }), -- враги, у которых уже проверены клетки
		bears = {}, -- { position, zone, model, jaws, readyAt }
		trips = {}, -- [index] = время последнего звона
		plates = {}, -- [index] = { readyAt, pendingAt }
		span = nil,
		chandeliers = {}, -- [name] = { base, fallen }
		chandNext = 0,
		warnDiscs = {},
		cart = { state = "idle", at = 0, readyAt = 0 },
		perch = nil,
		gateOpen = false,
		hazards = {},
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

	local function hit(player, damage: number, source: string, position: Vector3, parryable: boolean?)
		CombatService.resolveIncomingAttack(player, {
			damage = damage,
			parryable = parryable == true,
			source = source,
			position = position,
		})
	end

	-- ===== Жаровни донжона и сигнальный костёр =====

	local function makeFire(parent, name: string, position: Vector3, size: number)
		local anchor = part(parent, {
			Name = name,
			Size = V3(size * 0.9, 0.6, size * 0.9),
			CFrame = CFrame.new(position),
			Color = COLORS.ember,
			Material = Enum.Material.Neon,
			Transparency = 1,
		})
		local fire = Instance.new("Fire")
		fire.Size = size
		fire.Heat = size * 1.4
		fire.Color = COLORS.ember
		fire.SecondaryColor = COLORS.flame
		fire.Enabled = false
		fire.Parent = anchor
		local light = Instance.new("PointLight")
		light.Color = COLORS.flame
		light.Range = math.min(size * 4, 60)
		light.Brightness = 2.5
		light.Shadows = false
		light.Enabled = false
		light.Parent = anchor
		return { anchor = anchor, fire = fire, light = light }
	end

	local function setFire(entry, on: boolean)
		if not entry then
			return
		end
		entry.fire.Enabled = on
		entry.light.Enabled = on
		entry.anchor.Transparency = on and 0.15 or 1
		entry.anchor:SetAttribute("Lit", on)
	end

	-- ===== Трофеи =====

	local function trophyModel(parent, cfg)
		local model = Instance.new("Model")
		model.Name = "Trophy_" .. cfg.id
		local base = CFrame.new(cfg.at + V3(0, 1.4, 0))
		if cfg.id == "T1" then
			-- перо: стержень и опахало
			part(model, { Name = "Quill", Size = V3(0.18, 3.2, 0.18), CFrame = base * CFrame.Angles(0, 0, math.rad(14)), Color = COLORS.gold, Material = Enum.Material.Neon })
			part(model, { Name = "Vane", Size = V3(0.12, 2.6, 1.0), CFrame = base * CFrame.new(0.1, 0.3, 0.35) * CFrame.Angles(0, 0, math.rad(14)), Color = cfg.color, CastShadow = true })
			part(model, { Name = "Band", Size = V3(0.14, 0.35, 1.02), CFrame = base * CFrame.new(0.16, 0.9, 0.35) * CFrame.Angles(0, 0, math.rad(14)), Color = COLORS.blood })
		elseif cfg.id == "T2" then
			-- рог: три сегмента дугой и золотые кольца
			for k = 0, 2 do
				part(model, { Name = "Horn" .. k, Size = V3(0.9 - k * 0.22, 1.4, 0.9 - k * 0.22), CFrame = base * CFrame.new(k * 0.75 - 0.75, k * 0.35, 0) * CFrame.Angles(0, 0, math.rad(60 - k * 30)), Color = COLORS.bone, CastShadow = true })
				part(model, { Name = "Ring" .. k, Size = V3(0.95 - k * 0.22, 0.18, 0.95 - k * 0.22), CFrame = base * CFrame.new(k * 0.75 - 0.75, k * 0.35 + 0.55, 0) * CFrame.Angles(0, 0, math.rad(60 - k * 30)), Color = COLORS.gold, Material = Enum.Material.Neon })
			end
		else
			-- клык: клин и золотая оправа
			part(model, { Class = "WedgePart", Name = "Fang", Size = V3(0.7, 2.4, 1.1), CFrame = base * CFrame.Angles(math.rad(180), 0, 0), Color = cfg.color, CastShadow = true })
			part(model, { Name = "Cap", Size = V3(0.85, 0.35, 1.25), CFrame = base * CFrame.new(0, 1.25, 0), Color = COLORS.gold, Material = Enum.Material.Neon })
		end
		local glow = part(model, { Name = "Glow", Size = V3(0.4, 0.4, 0.4), CFrame = base, Transparency = 1 })
		local light = Instance.new("PointLight")
		light.Color = COLORS.gold
		light.Range = 10
		light.Brightness = 1.2
		light.Enabled = false
		light.Parent = glow
		model.PrimaryPart = glow
		model.Parent = parent
		return model, light
	end

	local function publishTrophies()
		for _, player in ipairs(ctx.floorPlayers()) do
			player:SetAttribute("F3Trophies", world.taken)
		end
		if ctx.state.folder then
			ctx.state.folder:SetAttribute("Trophies", world.taken)
			ctx.state.folder:SetAttribute("TrophiesTotal", #Config.Trophies)
		end
	end

	local function setTrophyUnlocked(id: string, unlocked: boolean)
		local trophy = world.trophies[id]
		if not trophy then
			return
		end
		trophy.unlocked = unlocked
		trophy.prompt.Enabled = unlocked and not trophy.taken
		trophy.light.Enabled = unlocked and not trophy.taken
		trophy.anchor:SetAttribute("Unlocked", unlocked)
	end

	local function openTrophyGate(open: boolean, instant: boolean?)
		world.gateOpen = open
		Map.setGate(Config.TrophyGate, open, instant)
	end

	local function takeTrophy(id: string, player)
		local trophy = world.trophies[id]
		if not trophy or trophy.taken or not trophy.unlocked then
			return
		end
		trophy.taken = true
		trophy.prompt.Enabled = false
		trophy.light.Enabled = false
		trophy.anchor:SetAttribute("Taken", true)
		for _, d in ipairs(trophy.model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 1
			end
		end
		world.taken += 1
		publishTrophies()
		local brazier = world.braziers[trophy.index]
		task.delay(1.2, function()
			if trophy.taken then
				setFire(brazier, true)
			end
		end)
		ctx.fire({
			kind = "f3trophy",
			id = id,
			name = trophy.cfg.name,
			count = world.taken,
			total = #Config.Trophies,
			position = trophy.cfg.at,
			brazier = trophy.cfg.brazier,
			by = player,
		})
		if world.taken >= #Config.Trophies then
			task.delay(2.8, function()
				if world.taken >= #Config.Trophies then
					openTrophyGate(true)
					ctx.fire({ kind = "f3gate", open = true, position = Map.gatePosition(Config.TrophyGate) })
				end
			end)
		end
	end

	local function buildTrophies(folder)
		world.trophies = {}
		world.taken = 0
		world.braziers = {}
		for index, cfg in ipairs(Config.Trophies) do
			local model, light = trophyModel(folder, cfg)
			local anchor = part(folder, { Name = "TrophyPrompt_" .. cfg.id, Size = V3(3, 3, 3), CFrame = CFrame.new(cfg.at + V3(0, 1.4, 0)), Transparency = 1 })
			anchor:SetAttribute("TrophyId", cfg.id)
			anchor:SetAttribute("Unlocked", false)
			anchor:SetAttribute("Taken", false)
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "TrophyPrompt"
			prompt.ActionText = "Взять трофей"
			prompt.ObjectText = cfg.name
			prompt.HoldDuration = Config.TrophyHold
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.Enabled = false
			prompt.Parent = anchor
			prompt.Triggered:Connect(function(player)
				if ctx.onFloor(player) then
					takeTrophy(cfg.id, player)
				end
			end)
			world.trophies[cfg.id] = { cfg = cfg, index = index, anchor = anchor, prompt = prompt, model = model, light = light, unlocked = false, taken = false }
			world.braziers[index] = makeFire(folder, "Brazier_" .. index, cfg.brazier, 7)
		end
		world.signal = makeFire(folder, "SignalFire", Config.SignalFire, 5)
		publishTrophies()
	end

	-- ===== Ветхие стены перед тайниками =====

	local function spawnWall(zone)
		local cfg = zone.cfg
		if not cfg.secret or not cfg.secretAt then
			return
		end
		local name = "Dyn_" .. cfg.secret
		local model = Map.dynamic(name)
		if not model or model:GetAttribute("Broken") then
			return
		end
		if world.walls[cfg.id] and world.walls[cfg.id].alive then
			return
		end
		local wall = ctx.spawnEnemy(zone, "f3wall", cfg.secretAt, { noCredit = true, bounds = false })
		wall.onDeath = function()
			local position = Map.destroyDynamic(name)
			ctx.fire({ kind = "f3secret", zone = cfg.id, name = cfg.name, position = position or cfg.secretAt })
		end
		world.walls[cfg.id] = wall
	end

	-- ===== Клетки и денники =====

	local function closeCages(zoneCfg)
		for _, cage in ipairs(zoneCfg.cages or {}) do
			world.cages[cage.door] = nil
			Map.setGate(cage.door, false, true)
		end
	end

	local function stepCages()
		for _, zone in ipairs(ctx.state.rooms) do
			local cages = zone.cfg.cages
			if cages then
				for _, enemy in ipairs(zone.enemies) do
					if enemy.alive and not world.seen[enemy] then
						world.seen[enemy] = true
						for _, cage in ipairs(cages) do
							if not world.cages[cage.door] and flat(enemy.position - cage.at).Magnitude <= 7 then
								world.cages[cage.door] = true
								Map.setGate(cage.door, true)
								ctx.fire({ kind = "f3cage", position = cage.at })
								break
							end
						end
					end
				end
			end
		end
	end

	-- ===== Грязь и дёготь =====

	local function stepHazards()
		for _, zone in ipairs(ctx.state.rooms) do
			local list = zone.cfg.hazards
			if list then
				for _, entry in ipairs(playersInBox(zone.cfg.box)) do
					local feet = entry.root.Position - V3(0, FEET, 0)
					for _, h in ipairs(list) do
						if flat(feet - h[2]).Magnitude <= h[3] and math.abs(feet.Y - h[2].Y) < 2.5 then
							Floor2Service.slowFromPuddle(entry.player, (Traps[h[1]] or Traps.mud).slow)
							break
						end
					end
				end
			end
		end
	end

	-- ===== Капканы =====

	local function makeBear(folder, position: Vector3)
		local model = Instance.new("Model")
		model.Name = "BearTrap"
		local base = CFrame.new(position + V3(0, 0.08, 0))
		part(model, { Name = "Plate", Size = V3(0.9, 0.12, 0.9), CFrame = base, Color = COLORS.ironLight, Material = Enum.Material.Metal })
		for k = 0, 3 do
			local a = math.rad(k * 90)
			part(model, { Name = "Ring", Size = V3(2.2, 0.14, 0.18), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 1.0), Color = COLORS.iron, Material = Enum.Material.Metal })
		end
		local jaws = {}
		for side = -1, 1, 2 do
			local hinge = base * CFrame.new(0, 0, side * 1.0)
			local jaw = part(model, { Name = "Jaw", Size = V3(2.0, 0.12, 0.9), CFrame = hinge * CFrame.new(0, 0, side * 0.45), Color = COLORS.iron, Material = Enum.Material.Metal })
			table.insert(jaws, { part = jaw, open = jaw.CFrame, shut = base * CFrame.new(0, 0.55, side * 0.12) * CFrame.Angles(math.rad(side * 80), 0, 0) })
		end
		model.Parent = folder
		return model, jaws
	end

	local function setJaws(trap, shut: boolean)
		for _, jaw in ipairs(trap.jaws) do
			TweenService:Create(jaw.part, TweenInfo.new(shut and 0.07 or 0.4, Enum.EasingStyle.Quad), { CFrame = shut and jaw.shut or jaw.open }):Play()
		end
	end

	local function buildBears(folder)
		world.bears = {}
		for _, zone in ipairs(ctx.state.rooms) do
			for _, point in ipairs(zone.cfg.bearTraps or {}) do
				local model, jaws = makeBear(folder, point)
				table.insert(world.bears, { position = point, zone = zone, model = model, jaws = jaws, readyAt = 0, shut = false })
			end
		end
	end

	local function buildDestructibles(folder)
		local props = Instance.new("Folder")
		props.Name = "Destructibles"
		props.Parent = folder

		for _, cfg in ipairs(Config.Destructibles or {}) do
			local model = Instance.new("Model")
			model.Name = cfg.id
			model:SetAttribute("PropKind", cfg.kind)
			model:SetAttribute("Health", cfg.hits)
			model:SetAttribute("MaxHealth", cfg.hits)
			model:SetAttribute("HitRadius", cfg.radius)
			model:SetAttribute("HitPosition", cfg.at + V3(0, 1, 0))

			local colliderSize
			if cfg.kind == "barrel" then
				colliderSize = V3(2.1, 2.6, 2.1)
				part(model, {
					Name = "Body",
					Shape = Enum.PartType.Cylinder,
					Size = V3(2.4, 1.9, 1.9),
					CFrame = CFrame.new(cfg.at + V3(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
					Color = hex("#754A2E"),
					Material = Enum.Material.Wood,
				})
				for _, y in ipairs({ 0.45, 1.95 }) do
					part(model, {
						Name = "IronHoop",
						Shape = Enum.PartType.Cylinder,
						Size = V3(0.16, 2.02, 2.02),
						CFrame = CFrame.new(cfg.at + V3(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
						Color = COLORS.iron,
						Material = Enum.Material.Metal,
					})
				end
			elseif cfg.kind == "hay" then
				colliderSize = V3(2.8, 1.8, 2)
				part(model, {
					Name = "Bale",
					Size = V3(2.6, 1.6, 1.8),
					CFrame = CFrame.new(cfg.at + V3(0, 0.8, 0)),
					Color = hex("#B99648"),
					Material = Enum.Material.Grass,
				})
				for _, x in ipairs({ -0.75, 0.75 }) do
					part(model, {
						Name = "Twine",
						Size = V3(0.12, 1.65, 1.86),
						CFrame = CFrame.new(cfg.at + V3(x, 0.8, 0)),
						Color = hex("#6A4A36"),
						Material = Enum.Material.Wood,
					})
				end
			end

			local collider = part(model, {
				Name = "Collider",
				Size = colliderSize,
				CFrame = CFrame.new(cfg.at + V3(0, colliderSize.Y / 2, 0)),
				Transparency = 1,
				CanCollide = true,
				CanQuery = false,
			})
			model.PrimaryPart = collider
			model.Parent = props
		end
	end

	local function stepBears(t: number)
		local b = Traps.bear
		for _, trap in ipairs(world.bears) do
			if trap.shut and t >= trap.readyAt then
				trap.shut = false
				setJaws(trap, false)
			end
		end
		for _, player in ipairs(ctx.floorPlayers()) do
			local root = ctx.rootOf(player)
			if root then
				local feet = root.Position - V3(0, FEET, 0)
				for _, trap in ipairs(world.bears) do
					if not trap.shut and flat(feet - trap.position).Magnitude <= b.radius and math.abs(feet.Y - trap.position.Y) < 2 then
						trap.shut = true
						trap.readyAt = t + b.rearm
						setJaws(trap, true)
						Floor2Service.root(player, b.root)
						hit(player, b.damage, "BearTrap", trap.position)
						ctx.fire({ kind = "f3bear", position = trap.position, duration = b.root })
						break
					end
				end
			end
		end
	end

	-- ===== Растяжки с колокольцами =====

	local function stepTrips(t: number)
		local tr = Traps.trip
		local index = 0
		for _, zone in ipairs(ctx.state.rooms) do
			for _, wire in ipairs(zone.cfg.tripwires or {}) do
				index += 1
				if t - (world.trips[index] or -10) >= 4 then
					for _, player in ipairs(ctx.floorPlayers()) do
						local root = ctx.rootOf(player)
						if root then
							local d = root.Position - wire
							if math.abs(d.X) <= tr.half and math.abs(d.Z) <= tr.depth and d.Y < 6 and d.Y > -2 then
								world.trips[index] = t
								ctx.fire({ kind = "f3trip", position = wire })
								break
							end
						end
					end
				end
			end
		end
	end

	-- ===== Самострелы на плитах =====

	local function stepPlates(t: number)
		local x = Traps.xbow
		local index = 0
		for _, zone in ipairs(ctx.state.rooms) do
			local plates = zone.cfg.plates
			if plates then
				local inside = playersInBox(zone.cfg.box)
				for _, cfg in ipairs(plates) do
					index += 1
					local record = world.plates[index]
					if not record then
						record = { readyAt = 0 }
						world.plates[index] = record
					end
					if record.pendingAt and t >= record.pendingAt then
						record.pendingAt = nil
						local origin = cfg.from + flat(cfg.plate - cfg.from).Unit * 1.6
						local dir = ((cfg.plate + V3(0, 2.6, 0)) - origin).Unit
						for k = 1, x.count do
							local angle = math.rad((k - (x.count + 1) / 2) * x.spread)
							local shot = CFrame.Angles(0, angle, 0):VectorToWorldSpace(dir)
							ProjectileService.fire(ctx.state.folder, origin, shot, {
								speed = x.speed,
								damage = x.damage,
								parryable = true,
								source = "Crossbow",
								kind = "trapbolt",
								lifetime = 1.8,
							})
						end
						ctx.fire({ kind = "f3xbow", phase = "fire", position = origin, target = cfg.plate })
					elseif not record.pendingAt and t >= record.readyAt then
						for _, entry in ipairs(inside) do
							local feet = entry.root.Position - V3(0, FEET, 0)
							if flat(feet - cfg.plate).Magnitude <= x.plate and math.abs(feet.Y - cfg.plate.Y) < 2 then
								record.pendingAt = t + x.warn
								record.readyAt = t + x.cooldown
								ctx.fire({ kind = "f3xbow", phase = "warn", position = cfg.from, plate = cfg.plate, duration = x.warn })
								break
							end
						end
					end
				end
			end
		end
	end

	-- ===== Пролёт моста =====

	local function stepSpan(t: number)
		local zoneCfg = Config.byId("bridge")
		local span = zoneCfg and zoneCfg.span
		if not span then
			return
		end
		world.span = world.span or { state = "idle", at = 0 }
		local s = world.span
		local cfg = Traps.span
		if s.state == "idle" then
			if not Map.dynamic(span.name) then
				return
			end
			for _, entry in ipairs(playersInBox(zoneCfg.box)) do
				local d = entry.root.Position - span.at
				if math.abs(d.X) <= cfg.half.X and math.abs(d.Z) <= cfg.half.Z and d.Y < 8 then
					s.state = "crack"
					s.at = t
					ctx.fire({ kind = "f3span", phase = "crack", position = span.at, duration = cfg.crack })
					break
				end
			end
		elseif s.state == "crack" and t - s.at >= cfg.crack then
			s.state = "down"
			s.at = t
			Map.breakTiles(span.name, span.at, 8, cfg.back)
			ctx.fire({ kind = "f3span", phase = "fall", position = span.at, duration = cfg.back })
		elseif s.state == "down" and t - s.at >= cfg.back + 0.5 then
			s.state = "idle"
			ctx.fire({ kind = "f3span", phase = "back", position = span.at })
		end
	end

	-- ===== Люстры Трофейного зала =====

	local function chandelierRecord(name: string)
		local record = world.chandeliers[name]
		local model = Map.dynamic(name)
		if not model then
			return nil, nil
		end
		if not record then
			record = { base = model:GetPivot(), fallen = false }
			world.chandeliers[name] = record
		end
		return record, model
	end

	local function resetChandeliers(zoneCfg)
		for _, c in ipairs(zoneCfg.chandeliers or {}) do
			local record, model = chandelierRecord(c.name)
			if record and model then
				model:PivotTo(record.base)
				record.fallen = false
			end
		end
		for _, disc in ipairs(world.warnDiscs) do
			disc:Destroy()
		end
		world.warnDiscs = {}
	end

	local function dropChandelier(zone, c)
		local cfg = Traps.chandelier
		local record, model = chandelierRecord(c.name)
		if not record or record.fallen then
			return
		end
		record.fallen = true
		local ground = FloorGeo.groundAt(c.at.X, c.at.Z, 2) or 0
		local floorPoint = V3(c.at.X, ground, c.at.Z)
		local disc = part(world.folder, {
			Name = "ChandelierShadow",
			Class = "Part",
			Shape = Enum.PartType.Cylinder,
			Size = V3(0.12, cfg.radius * 2, cfg.radius * 2),
			CFrame = CFrame.new(floorPoint + V3(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = COLORS.warn,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
		})
		table.insert(world.warnDiscs, disc)
		ctx.fire({ kind = "f3chandelier", phase = "warn", position = floorPoint, radius = cfg.radius, duration = cfg.warn })
		task.delay(cfg.warn, function()
			if disc.Parent then
				disc:Destroy()
			end
			if not model.Parent or not record.fallen or zone.state ~= "active" then
				return
			end
			local drop = c.at.Y - ground - 0.6
			tweenPivot(model, record.base - V3(0, drop, 0), TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In), function()
				for _, player in ipairs(ctx.floorPlayers()) do
					local root = ctx.rootOf(player)
					if root and flat(root.Position - floorPoint).Magnitude <= cfg.radius and math.abs(root.Position.Y - FEET - ground) < 4 then
						hit(player, cfg.damage, "Chandelier", floorPoint)
					end
				end
				ctx.fire({ kind = "f3chandelier", phase = "fall", position = floorPoint, radius = cfg.radius })
			end)
		end)
	end

	local function stepChandeliers(t: number)
		for _, zone in ipairs(ctx.state.rooms) do
			local list = zone.cfg.chandeliers
			if list and zone.state == "active" and t >= world.chandNext then
				world.chandNext = t + Traps.chandelier.every
				-- люстра ближе всех к случайному игроку в зале
				local inside = playersInBox(zone.cfg.box)
				if #inside > 0 then
					local target = inside[math.random(1, #inside)].root.Position
					local best, bestD = nil, math.huge
					for _, c in ipairs(list) do
						local record = chandelierRecord(c.name)
						if record and not record.fallen then
							local d = flat(c.at - target).Magnitude
							if d < bestD then
								best, bestD = c, d
							end
						end
					end
					if best then
						dropChandelier(zone, best)
					end
				end
			end
		end
	end

	-- ===== Сорвавшаяся телега конюшен =====
	-- Детали телеги приварены к коллайдеру (WeldConstraint): двигается одна деталь,
	-- по сети идёт одна сборка, а не сотни деталей.

	local cartRig = nil

	local function rigCart(cfg)
		local model = Map.dynamic(cfg.model)
		if not model then
			return nil
		end
		if cartRig and cartRig.model == model then
			return cartRig
		end
		local collider = nil
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "Collider" then
				collider = d
			end
		end
		if not collider then
			return nil
		end
		collider.Anchored = true
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d ~= collider then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = collider
				weld.Part1 = d
				weld.Parent = d
				d.Anchored = false
				d.CanCollide = false
				d.Massless = true
			end
		end
		cartRig = { model = model, root = collider, base = collider.CFrame }
		return cartRig
	end

	local function resetCart()
		world.cart = { state = "idle", at = 0, readyAt = 0 }
		if cartRig and cartRig.root.Parent then
			cartRig.root.CFrame = cartRig.base
			cartRig.root.CanCollide = true
			for _, d in ipairs(cartRig.model:GetDescendants()) do
				if d:IsA("BasePart") and d ~= cartRig.root then
					d.Transparency = d:GetAttribute("BaseTransparency") or d.Transparency
				end
			end
		end
	end

	local function stepCart(t: number)
		local zoneCfg = Config.byId("stables")
		local cfg = zoneCfg and zoneCfg.cart
		if not cfg then
			return
		end
		local rig = rigCart(cfg)
		if not rig then
			return
		end
		local c = world.cart
		local tc = Traps.cart
		local path = flat(cfg.to - cfg.from)
		local length = path.Magnitude
		local dir = path.Unit
		if c.state == "idle" then
			if t >= c.readyAt and #playersInBox(cfg.trigger) > 0 then
				c.state = "warn"
				c.at = t
				ctx.fire({ kind = "f3cart", phase = "warn", position = cfg.from, target = cfg.to, duration = tc.warn })
			end
		elseif c.state == "warn" and t - c.at >= tc.warn then
			c.state = "roll"
			c.at = t
			c.hit = {}
			rig.root.CanCollide = false
			ctx.fire({ kind = "f3cart", phase = "roll", position = cfg.from, target = cfg.to, duration = length / tc.speed })
		elseif c.state == "roll" then
			local travelled = math.min((t - c.at) * tc.speed, length)
			local position = cfg.from + dir * travelled
			rig.root.CFrame = rig.base + dir * travelled
			for _, player in ipairs(ctx.floorPlayers()) do
				local root = ctx.rootOf(player)
				if root and not c.hit[player] then
					local rel = flat(root.Position - position)
					local along = rel:Dot(dir)
					local side = (rel - dir * along).Magnitude
					if along > -3 and along < 4 and side <= tc.width and root.Position.Y < 8 then
						c.hit[player] = true
						hit(player, tc.damage, "Cart", position)
						local away = (rel - dir * along)
						away = away.Magnitude > 0.1 and away.Unit or V3(0, 0, 1)
						root.AssemblyLinearVelocity = away * tc.knock + V3(0, 18, 0) + dir * 12
					end
				end
			end
			if travelled >= length then
				c.state = "gone"
				c.at = t
				ctx.fire({ kind = "f3cart", phase = "crash", position = cfg.to })
				for _, d in ipairs(rig.model:GetDescendants()) do
					if d:IsA("BasePart") and d ~= rig.root then
						if d:GetAttribute("BaseTransparency") == nil then
							d:SetAttribute("BaseTransparency", d.Transparency)
						end
						d.Transparency = 1
					end
				end
			end
		elseif c.state == "gone" and t - c.at >= 2 then
			resetCart()
			world.cart.readyAt = t + tc.cooldown
		end
	end

	-- ===== Королевский ловчий: вышки и копья =====

	local function bossZone()
		return ctx.zoneById("lists")
	end

	local function throwSpears(boss, origin: Vector3, zone)
		local p = Traps.perch
		for _, entry in ipairs(playersInBox(zone.cfg.box)) do
			local target = entry.root.Position
			local dir = (target - origin).Unit
			for k = -1, 1 do
				local shot = CFrame.Angles(0, math.rad(k * p.spread), 0):VectorToWorldSpace(dir)
				ProjectileService.fire(ctx.state.folder, origin, shot, {
					speed = p.speed,
					damage = p.damage,
					parryable = true,
					source = "Huntsman",
					kind = "spear",
					lifetime = 2.2,
				})
			end
		end
		ctx.fire({ kind = "f3spear", position = origin, model = boss.model })
	end

	local function leap(boss, to: Vector3, height: number, duration: number)
		boss.attack = nil
		boss.forced = nil
		boss.moveDir = Vector3.zero
		local t = ctx.now()
		boss.air = { startT = t, duration = duration, height = height }
		local from = boss.position
		ctx.fire({ kind = "f3perch", phase = "jump", position = from, target = to, model = boss.model })
		-- позиция плавно от точки к точке (и по высоте — на насест 9 стад), дугу даёт air
		task.spawn(function()
			while boss.alive and boss.air do
				local k = (ctx.now() - t) / duration
				if k >= 1 then
					break
				end
				boss.position = from:Lerp(to, k)
				task.wait()
			end
			if boss.alive then
				boss.position = to
			end
		end)
	end

	local function stepPerch(t: number)
		local zone = bossZone()
		local perch = world.perch
		if not zone or zone.state ~= "active" or not perch then
			return
		end
		local boss = zone.boss
		if not boss or not boss.alive then
			return
		end
		local p = Traps.perch
		local cfg = zone.cfg
		if perch.state == "ground" and t >= perch.nextAt then
			-- не прерываем удар на середине
			local state = boss.model:GetAttribute("EnemyState")
			if state == "strike" or state == "windup" then
				return
			end
			local options = {}
			for index in ipairs(cfg.perches) do
				if index ~= perch.last then
					table.insert(options, index)
				end
			end
			local index = options[math.random(1, #options)]
			perch.last = index
			local spot = cfg.perches[index]
			local y = FloorGeo.groundAt(spot.X, spot.Z, spot.Y + 1)
			if y == nil or y < spot.Y - 2 then
				y = spot.Y
			end
			perch.spot = V3(spot.X, y, spot.Z)
			perch.state = "up"
			perch.at = t
			perch.volleys = 0
			boss.sceneUntil = t + p.stay + 0.8
			boss.immuneUntil = math.max(boss.immuneUntil or 0, t + p.stay + 0.8)
			EnemyService.setState(boss, "phase", p.stay + 0.8)
			leap(boss, perch.spot, 12, 0.8)
		elseif perch.state == "up" then
			if perch.volleys < p.volleys and t >= perch.at + 1.2 + perch.volleys * p.gap then
				perch.volleys += 1
				throwSpears(boss, perch.spot + V3(0, 5, 0), zone)
			end
			if t >= perch.at + p.stay then
				-- вниз: рядом с игроком, но не вплотную
				local inside = playersInBox(cfg.box)
				local center = Config.Offset
				local target = center
				if #inside > 0 then
					target = inside[math.random(1, #inside)].root.Position
				end
				local toward = flat(center - target)
				local land = flat(target) + (toward.Magnitude > 0.1 and toward.Unit * 7 or V3(7, 0, 0))
				local fromCenter = land - flat(center)
				if fromCenter.Magnitude > 40 then
					land = flat(center) + fromCenter.Unit * 40
				end
				local y = FloorGeo.groundAt(land.X, land.Z, 3) or 0
				local landAt = V3(land.X, y, land.Z)
				perch.state = "down"
				perch.at = t
				leap(boss, landAt, 10, 0.8)
				task.delay(0.8, function()
					if not boss.alive then
						return
					end
					for _, player in ipairs(ctx.floorPlayers()) do
						local root = ctx.rootOf(player)
						if root and flat(root.Position - landAt).Magnitude <= 6 and math.abs(root.Position.Y - FEET - landAt.Y) < 4 then
							hit(player, 20, "Huntsman", landAt)
						end
					end
					ctx.fire({ kind = "f3perch", phase = "land", position = landAt, radius = 6, model = boss.model })
				end)
			end
		elseif perch.state == "down" and t >= perch.at + 1.0 then
			perch.state = "ground"
			perch.nextAt = t + p.every
		end
	end

	-- ===== Хуки этажа =====

	function hooks.beforeBuild()
		world.walls = {}
		world.plates = {}
		world.trips = {}
		world.span = nil
		world.perch = nil
		world.chandNext = 0
		world.seen = setmetatable({}, { __mode = "k" })
	end

	function hooks.build()
		local runtime = Workspace:FindFirstChild(Config.RuntimeName)
		if not runtime then
			runtime = Instance.new("Folder")
			runtime.Name = Config.RuntimeName
			runtime.Parent = Workspace
		end
		local old = runtime:FindFirstChild("Floor3World")
		if old then
			old:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "Floor3World"
		folder.Parent = runtime
		world.folder = folder
		world.warnDiscs = {}
		buildTrophies(folder)
		buildDestructibles(folder)
		buildBears(folder)
		openTrophyGate(false, true)
		resetCart()
		for _, zone in ipairs(ctx.state.rooms) do
			closeCages(zone.cfg)
			if zone.cfg.chandeliers then
				resetChandeliers(zone.cfg)
			end
			spawnWall(zone)
		end
	end

	local slowClock = 0
	function hooks.step(_, t: number, dt: number)
		stepBears(t)
		stepSpan(t)
		stepCart(t)
		stepPerch(t)
		slowClock += dt
		if slowClock < 0.15 then
			return
		end
		slowClock = 0
		stepCages()
		stepHazards()
		stepTrips(t)
		stepPlates(t)
		stepChandeliers(t)
	end

	function hooks.zoneActivated(_, zone)
		local cfg = zone.cfg
		if cfg.chandeliers then
			world.chandNext = ctx.now() + Traps.chandelier.first
		end
		if cfg.id == "lists" then
			-- Бой с ловчим: решётка за спиной опускается.
			openTrophyGate(false)
			world.perch = { state = "ground", nextAt = ctx.now() + Traps.perch.first, last = nil }
		end
	end

	function hooks.zoneCleared(_, zone)
		local cfg = zone.cfg
		if cfg.trophy then
			setTrophyUnlocked(cfg.trophy, true)
			local trophy = Config.trophyById(cfg.trophy)
			ctx.fire({ kind = "f3trophyReady", id = cfg.trophy, name = trophy and trophy.name, position = trophy and trophy.at })
		end
		if cfg.id == "tower" then
			setFire(world.signal, true)
			ctx.fire({ kind = "f3signal", position = Config.SignalFire })
		end
		if cfg.id == "lists" then
			world.perch = nil
			openTrophyGate(true)
		end
	end

	function hooks.zoneReset(_, zone)
		local cfg = zone.cfg
		spawnWall(zone)
		if cfg.chandeliers then
			resetChandeliers(cfg)
		end
		if cfg.cages and zone.state ~= "cleared" then
			closeCages(cfg)
		end
		if cfg.id == "lists" then
			world.perch = nil
			if world.taken >= #Config.Trophies then
				openTrophyGate(true)
			end
		end
	end

	function hooks.resetPlayer(_, player)
		player:SetAttribute("F3Trophies", world.taken)
	end

	-- Отладка (DebugCommands «trophies»): открыть все трофеи и решётку.
	function ctx.debugTrophies(take: boolean)
		for _, cfg in ipairs(Config.Trophies) do
			setTrophyUnlocked(cfg.id, true)
			if take then
				takeTrophy(cfg.id, nil)
			end
		end
		return world.taken
	end
end

return Floor3World
