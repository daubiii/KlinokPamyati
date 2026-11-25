--!nonstrict
-- MiniBossFx
-- Клиентские эффекты этажа 1 v2: мини-боссы (Сотник ворот, Арбалетчица
-- башни), ключи, удержание Зала лебёдки, обрушение моста, засады.
-- Сервер (FloorService, MiniBossService) шлёт события FloorEvent и
-- EnemyEvent; здесь — только картинка, звук и подсказки. Логики нет.
--
-- Сотник:  знамя за спиной прячется, когда воткнуто (BannerState), знамя в
--          гнезде + круг ауры, падение знамени, искры щита, треснувший щит.
-- Арбалетчица: значок перезарядки над головой, цепь поперёк пандуса
--          (по невидимым ChainBarrier сервера), капканы, баррикады в щепки.
-- Этаж:    ключи (метка на полу, ячейки в углу экрана), сцена замков,
--          полоса удержания, падение в ров, засада, обрушение досок.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local Palette = require(Shared.Config.Palette)

local Bus = require(script.Parent.Parent.Lib.Bus)
local Ui = require(script.Parent.Parent.Lib.Ui)
local EnemyVisualController = require(script.Parent.EnemyVisualController)

local MiniBossFx = {}

local V = Palette.Voxel
local V3 = Vector3.new
local FAR = CFrame.new(0, -500, 0)
local player = Players.LocalPlayer
local random = Random.new()

local KEYS = {
	{ id = "KeyCaptain", short = "С", name = "Ключ Сотника" },
	{ id = "KeyTower", short = "Б", name = "Ключ Башни" },
}

local folderRef = nil
local function folder()
	if folderRef and folderRef.Parent then
		return folderRef
	end
	folderRef = Instance.new("Folder")
	folderRef.Name = "MiniBossFx"
	folderRef.Parent = Workspace
	return folderRef
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function notify(text: string, kind: string?)
	Bus.emit("notify", { kind = kind or "warn", text = text })
end

local function sfx(name: string, position: Vector3?)
	Bus.emit("sfx", { name = name, position = position })
end

local function shake(amount: number, time: number)
	Bus.emit("shake", { amount = amount, time = time })
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = props.Parent or folder()
	return p
end

-- Диск на полу (цилиндр, ось X вверх).
local function disc(center: Vector3, radius: number, color: Color3, transparency: number)
	return part({
		Name = "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = V3(0.06, radius * 2, radius * 2),
		CFrame = CFrame.new(center + V3(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = transparency,
	})
end

-- ===== Обломки и вспышки (свой маленький пул) =====

local debris = {}

local function burst(position: Vector3, count: number, color: Color3, size: number?, speed: number?, neon: boolean?)
	for _ = 1, count do
		local s = (size or 0.25) * random:NextNumber(0.6, 1.3)
		local p = part({
			Name = "Bit",
			Size = V3(s, s, s),
			CFrame = CFrame.new(position + V3(random:NextNumber(-0.4, 0.4), random:NextNumber(0, 0.5), random:NextNumber(-0.4, 0.4))),
			Color = color,
			Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		})
		local v = speed or 14
		table.insert(debris, {
			part = p,
			velocity = V3(random:NextNumber(-1, 1) * v * 0.5, random:NextNumber(0.4, 1) * v, random:NextNumber(-1, 1) * v * 0.5),
			spin = V3(random:NextNumber(-8, 8), random:NextNumber(-8, 8), random:NextNumber(-8, 8)),
			life = random:NextNumber(0.7, 1.3),
			age = 0,
			floor = position.Y - 0.2,
		})
	end
end

local pulses = {}

local function ring(center: Vector3, radius: number, color: Color3, time: number)
	local p = disc(center, 0.5, color, 0.2)
	table.insert(pulses, { part = p, age = 0, time = time, r0 = 0.5, r1 = radius, center = center })
end

local function stepDebris(dt: number)
	for index = #debris, 1, -1 do
		local d = debris[index]
		d.age += dt
		d.velocity += V3(0, -60 * dt, 0)
		local pos = d.part.Position + d.velocity * dt
		if pos.Y < d.floor then
			pos = V3(pos.X, d.floor, pos.Z)
			d.velocity = V3(d.velocity.X * 0.5, -d.velocity.Y * 0.3, d.velocity.Z * 0.5)
		end
		d.part.CFrame = CFrame.new(pos) * d.part.CFrame.Rotation * CFrame.Angles(d.spin.X * dt, d.spin.Y * dt, d.spin.Z * dt)
		local k = d.age / d.life
		if k > 0.6 then
			d.part.Transparency = (k - 0.6) / 0.4
		end
		if k >= 1 then
			d.part:Destroy()
			debris[index] = debris[#debris]
			debris[#debris] = nil
		end
	end
	for index = #pulses, 1, -1 do
		local item = pulses[index]
		item.age += dt
		local k = math.clamp(item.age / item.time, 0, 1)
		local e = 1 - (1 - k) * (1 - k)
		local r = item.r0 + (item.r1 - item.r0) * e
		item.part.Size = V3(0.06, r * 2, r * 2)
		item.part.Transparency = 0.2 + 0.8 * k
		if k >= 1 then
			item.part:Destroy()
			pulses[index] = pulses[#pulses]
			pulses[#pulses] = nil
		end
	end
end

-- ===== Сотник: знамя =====

local centurions = {} -- [serverModel] = true
local planted = {} -- [zoneId] = { parts, aura, top, base, falling }

local function bannerPart(rig)
	if not rig or not rig.fx then
		return nil, nil
	end
	for _, entry in ipairs(rig.fx.armor) do
		if entry.part:GetAttribute("Role") == "banner" then
			return entry.part, entry
		end
	end
	return nil, nil
end

-- Знамя за спиной видно, только пока оно не воткнуто в гнездо.
local function updateCenturion(model)
	local rig = EnemyVisualController.rigOf(model)
	local banner, entry = bannerPart(rig)
	if not banner then
		return
	end
	local state = model:GetAttribute("BannerState") or "back"
	local hidden = state == "planted" or state == "lost"
	local target = hidden and 1 or 0
	if entry.base ~= target then
		entry.base = target
		banner.Transparency = target
	end
end

local function buildBanner(zoneId: string, socket: Vector3, radius: number)
	local old = planted[zoneId]
	if old then
		for _, p in ipairs(old.parts) do
			p:Destroy()
		end
	end
	local parts = {}
	local base = CFrame.new(socket)
	local function add(p)
		table.insert(parts, p)
		return p
	end
	add(part({ Name = "Pole", Size = V3(0.3, 7.5, 0.3), CFrame = base * CFrame.new(0, 3.75, 0), Color = V.N }))
	add(part({ Name = "Cross", Size = V3(3.2, 0.25, 0.25), CFrame = base * CFrame.new(0, 7.1, 0), Color = V.N }))
	add(part({ Name = "Cloth", Size = V3(3, 4, 0.12), CFrame = base * CFrame.new(0, 5, 0.1), Color = Palette.Env and Palette.Env.ember or V.D }))
	add(part({ Name = "Sigil", Size = V3(1.1, 1.1, 0.14), CFrame = base * CFrame.new(0, 5.2, 0.12) * CFrame.Angles(0, 0, math.rad(45)), Color = V.A, Material = Enum.Material.Neon }))
	local top = add(part({ Name = "Finial", Size = V3(0.5, 0.5, 0.5), CFrame = base * CFrame.new(0, 7.75, 0), Color = V.A, Material = Enum.Material.Neon }))
	local light = Instance.new("PointLight")
	light.Color = V.A
	light.Range = 14
	light.Brightness = 1.4
	light.Parent = top
	local aura = add(disc(socket, radius, V.A, 0.82))
	local edge = add(disc(socket + V3(0, 0.01, 0), radius + 0.15, V.A, 0.55))
	edge.Size = V3(0.04, (radius + 0.15) * 2, (radius + 0.15) * 2)
	local rest = {}
	for _, p in ipairs(parts) do
		rest[p] = base:ToObjectSpace(p.CFrame)
	end
	planted[zoneId] = { parts = parts, aura = aura, edge = edge, base = base, rest = rest, radius = radius, born = os.clock() }
	ring(socket, radius, V.A, 0.5)
	burst(socket + V3(0, 0.3, 0), 14, V.L, 0.2, 10)
end

local function fellBanner(zoneId: string)
	local b = planted[zoneId]
	if not b or b.falling then
		return
	end
	b.falling = os.clock()
	b.aura.Transparency = 1
	b.edge.Transparency = 1
	local tip = b.base * CFrame.new(0, 5, 0)
	burst(tip.Position, 24, V.D, 0.3, 12)
	burst(b.base.Position + V3(0, 0.4, 0), 10, V.A, 0.2, 16, true)
end

local function stepBanners(now: number)
	for zoneId, b in pairs(planted) do
		if b.falling then
			-- Заваливается за 0,6 с, лежит 4 с и тает.
			local k = math.clamp((now - b.falling) / 0.6, 0, 1)
			local angle = math.rad(88) * k * k
			local pivot = b.base * CFrame.Angles(angle, 0, 0)
			for p, rel in pairs(b.rest) do
				if p ~= b.aura and p ~= b.edge then
					p.CFrame = pivot * rel
				end
			end
			if now - b.falling > 4 then
				local fade = math.clamp((now - b.falling - 4) / 1, 0, 1)
				for _, p in ipairs(b.parts) do
					if p ~= b.aura and p ~= b.edge then
						p.Transparency = math.max(p.Transparency, fade)
					end
				end
				if fade >= 1 then
					for _, p in ipairs(b.parts) do
						p:Destroy()
					end
					planted[zoneId] = nil
				end
			end
		else
			-- Аура дышит.
			local wave = 0.5 + 0.5 * math.sin((now - b.born) * 3)
			b.aura.Transparency = 0.86 - 0.06 * wave
			b.edge.Transparency = 0.6 - 0.2 * wave
		end
	end
end

-- ===== Арбалетчица =====

local arbalests = {} -- [serverModel] = { icon, spokes }

local function reloadIcon()
	local hub = part({ Name = "ReloadIcon", Shape = Enum.PartType.Cylinder, Size = V3(0.12, 1.2, 1.2), Color = V.A, Material = Enum.Material.Neon, CFrame = FAR, Transparency = 0.15 })
	local spokes = {}
	for i = 1, 4 do
		local s = part({ Name = "Spoke", Size = V3(0.14, 1.9, 0.22), Color = V.A, Material = Enum.Material.Neon, CFrame = FAR })
		spokes[i] = s
	end
	return { hub = hub, spokes = spokes }
end

local function updateArbalest(model, entry, now: number)
	local reloading = model:GetAttribute("Reloading") == true and (model:GetAttribute("ReloadUntil") or 0) > serverNow()
	local root = model:FindFirstChild("Root") or model.PrimaryPart
	if not reloading or not root then
		if entry.icon.shown then
			entry.icon.shown = false
			entry.icon.hub.CFrame = FAR
			for _, s in ipairs(entry.icon.spokes) do
				s.CFrame = FAR
			end
		end
		return
	end
	entry.icon.shown = true
	local height = model:GetAttribute("EnemyHeight") or 6
	local camera = Workspace.CurrentCamera
	local at = root.Position + V3(0, height * 0.5 + 1.6, 0)
	local face = camera and CFrame.lookAt(at, camera.CFrame.Position) or CFrame.new(at)
	local spin = CFrame.Angles(0, 0, now * 4)
	entry.icon.hub.CFrame = face * CFrame.Angles(0, math.rad(90), 0)
	for i, s in ipairs(entry.icon.spokes) do
		s.CFrame = face * spin * CFrame.Angles(0, 0, math.rad(45 * i))
	end
end

-- Цепь поперёк пандуса: рисуем по серверному ChainBarrier (ось Z — длина).
local chains = {} -- [barrier] = { parts }

local function buildChain(barrier: BasePart)
	if chains[barrier] then
		return
	end
	local parts = {}
	local length = barrier.Size.Z
	local cf = barrier.CFrame
	for _, h in ipairs({ -0.9, 0.3 }) do
		local links = math.floor(length / 0.55)
		for i = 0, links do
			local z = -length / 2 + i * (length / links)
			local sag = -0.35 * (1 - (2 * i / links - 1) ^ 2)
			local link = part({
				Name = "Link",
				Size = V3(0.12, 0.3, 0.5),
				CFrame = cf * CFrame.new(0, h + sag, z) * CFrame.Angles(0, 0, (i % 2 == 0) and 0 or math.rad(90)),
				Color = V.G,
				Material = Enum.Material.Metal,
			})
			table.insert(parts, link)
		end
	end
	for _, z in ipairs({ -length / 2, length / 2 }) do
		table.insert(parts, part({ Name = "Hook", Size = V3(0.35, 2.2, 0.35), CFrame = cf * CFrame.new(0, -0.9, z), Color = V.S }))
		table.insert(parts, part({ Name = "Glint", Size = V3(0.3, 0.3, 0.3), CFrame = cf * CFrame.new(0, 0.3, z), Color = V.A, Material = Enum.Material.Neon }))
	end
	chains[barrier] = { parts = parts }
	burst(barrier.Position, 12, V.L, 0.18, 12, true)
	sfx("chainSlam", barrier.Position)
end

local function dropChain(barrier)
	local entry = chains[barrier]
	if not entry then
		return
	end
	chains[barrier] = nil
	for _, p in ipairs(entry.parts) do
		if p.Name == "Link" then
			burst(p.Position, 1, V.G, 0.2, 6)
		end
		p:Destroy()
	end
	sfx("chains", barrier.Position)
end

local function watchRuntime(runtime: Instance)
	runtime.ChildAdded:Connect(function(child)
		if child.Name == "ChainBarrier" and child:IsA("BasePart") then
			task.defer(buildChain, child)
		end
	end)
	runtime.ChildRemoved:Connect(function(child)
		dropChain(child)
	end)
	for _, child in ipairs(runtime:GetChildren()) do
		if child.Name == "ChainBarrier" and child:IsA("BasePart") then
			buildChain(child)
		end
	end
end

-- Капканы.
local traps = {} -- { part, teeth, position, untilT }

local function placeTraps(positions, radius: number, duration: number, pin: boolean?)
	for _, position in ipairs(positions or {}) do
		-- pin: круг цепного болта (красный, короткий) — выйти, пока не захлопнулся
		local base = disc(position, radius, pin and Color3.fromRGB(220, 60, 50) or V.X, pin and 0.45 or 0.75)
		local teeth = {}
		for i = 1, 8 do
			local a = (i / 8) * math.pi * 2
			table.insert(teeth, part({
				Name = "Tooth",
				Size = V3(0.18, 0.4, 0.18),
				CFrame = CFrame.new(position + V3(math.cos(a) * radius * 0.7, 0.2, math.sin(a) * radius * 0.7)),
				Color = V.L,
				Material = Enum.Material.Metal,
			}))
		end
		table.insert(traps, { part = base, teeth = teeth, position = position, untilT = os.clock() + (duration or 12), born = os.clock() })
		burst(position + V3(0, 0.2, 0), 5, V.L, 0.15, 6)
	end
	sfx("chains")
end

local function removeTrap(index: number, sprung: boolean)
	local trap = table.remove(traps, index)
	if not trap then
		return
	end
	if sprung then
		burst(trap.position + V3(0, 0.3, 0), 14, V.L, 0.18, 10)
		ring(trap.position, 2.5, V.X, 0.35)
		sfx("chainSlam", trap.position)
	end
	trap.part:Destroy()
	for _, t in ipairs(trap.teeth) do
		t:Destroy()
	end
end

local function stepTraps(now: number)
	for index = #traps, 1, -1 do
		local trap = traps[index]
		if now >= trap.untilT then
			removeTrap(index, false)
		else
			trap.part.Transparency = 0.72 + 0.12 * math.sin((now - trap.born) * 6)
		end
	end
end

-- ===== Ключи =====

local keyMarkers = {} -- { key, parts, position, born }
local keyUi: any = nil

local function buildKeyUi()
	local gui = Ui.screen("FloorKeys", 6)
	local holder = Ui.frame(gui, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 120),
		Size = UDim2.fromOffset(2 * 46 + 6, 46),
		BackgroundTransparency = 1,
	})
	local cells = {}
	for index, info in ipairs(KEYS) do
		local cell = Ui.frame(holder, {
			Position = UDim2.fromOffset((index - 1) * 52, 0),
			Size = UDim2.fromOffset(46, 46),
			BackgroundColor3 = Ui.colors.panel,
			BackgroundTransparency = 0.25,
		})
		local stroke = Ui.outline(cell, 2)
		local label = Ui.text(cell, {
			Size = UDim2.fromScale(1, 1),
			Text = info.short,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Ui.colors.textMuted,
			TextTransparency = 0.5,
		})
		cells[info.id] = { cell = cell, label = label, stroke = stroke }
	end
	gui.Enabled = false
	keyUi = { gui = gui, cells = cells }
end

local function refreshKeys()
	if not keyUi then
		return
	end
	local inFloor = player:GetAttribute("Zone") == "Floor"
	local any = false
	for _, info in ipairs(KEYS) do
		local has = player:GetAttribute(info.id) == true
		any = any or has
		local cell = keyUi.cells[info.id]
		cell.label.TextColor3 = has and Ui.colors.gold or Ui.colors.textMuted
		cell.label.TextTransparency = has and 0 or 0.55
		cell.stroke.Color = has and Ui.colors.gold or Ui.colors.outline
	end
	keyUi.gui.Enabled = inFloor and (any or #keyMarkers > 0)
end

local function addKeyMarker(key: string, position: Vector3)
	local parts = {}
	local ring0 = disc(position, 1.6, V.A, 0.55)
	table.insert(parts, ring0)
	local bow = part({ Name = "KeyBow", Shape = Enum.PartType.Cylinder, Size = V3(0.25, 0.9, 0.9), Color = V.A, Material = Enum.Material.Neon, CFrame = CFrame.new(position) })
	local shaft = part({ Name = "KeyShaft", Size = V3(0.22, 1.3, 0.22), Color = V.A, Material = Enum.Material.Neon, CFrame = CFrame.new(position) })
	local bit = part({ Name = "KeyBit", Size = V3(0.22, 0.25, 0.5), Color = V.A, Material = Enum.Material.Neon, CFrame = CFrame.new(position) })
	local light = Instance.new("PointLight")
	light.Color = V.A
	light.Range = 12
	light.Brightness = 2
	light.Parent = shaft
	table.insert(parts, bow)
	table.insert(parts, shaft)
	table.insert(parts, bit)
	table.insert(keyMarkers, { key = key, parts = parts, bow = bow, shaft = shaft, bit = bit, ring = ring0, position = position, born = os.clock() })
	burst(position + V3(0, 1, 0), 16, V.A, 0.18, 12, true)
	refreshKeys()
end

local function removeKeyMarker(key: string)
	for index = #keyMarkers, 1, -1 do
		local m = keyMarkers[index]
		if m.key == key then
			burst(m.shaft.Position, 20, V.A, 0.18, 14, true)
			for _, p in ipairs(m.parts) do
				p:Destroy()
			end
			table.remove(keyMarkers, index)
		end
	end
	refreshKeys()
end

local function stepKeys(now: number)
	for _, m in ipairs(keyMarkers) do
		local t = now - m.born
		local center = CFrame.new(m.position + V3(0, 1.6 + 0.25 * math.sin(t * 2.4), 0)) * CFrame.Angles(0, t * 1.8, 0)
		m.bow.CFrame = center * CFrame.new(0, 0.75, 0) * CFrame.Angles(0, math.rad(90), 0)
		m.shaft.CFrame = center * CFrame.new(0, -0.1, 0)
		m.bit.CFrame = center * CFrame.new(0, -0.55, -0.3)
		m.ring.Transparency = 0.5 + 0.2 * math.sin(t * 4)
	end
end

-- ===== Удержание (Зал лебёдки) =====

local holdUi: any = nil
local hold = nil -- { endsAt, duration }

local function buildHoldUi()
	local gui = Ui.screen("FloorHold", 7)
	local title = Ui.text(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.fromOffset(420, 22),
		Text = "ДЕРЖИТЕСЬ, ПОКА ПОДНИМАЕТСЯ РЕШЁТКА",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Ui.colors.gold,
	})
	local bar = Ui.bar(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 118),
		Size = UDim2.fromOffset(380, 14),
	}, { color = Ui.colors.gold, segments = 6 })
	local time = Ui.text(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 136),
		Size = UDim2.fromOffset(200, 20),
		Text = "",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	gui.Enabled = false
	holdUi = { gui = gui, title = title, bar = bar, time = time }
end

local function stepHold(dt: number)
	if not hold or not holdUi then
		return
	end
	local left = math.max(hold.endsAt - serverNow(), 0)
	-- Решётка поднимается: полоса растёт к концу удержания.
	holdUi.bar.set(1 - left / math.max(hold.duration, 0.1), dt)
	holdUi.time.Text = string.format("%d с", math.ceil(left))
end

-- ===== Арбалетчица: насесты, обвал, крюк =====

local WOOD = { Color3.fromRGB(122, 92, 72), Color3.fromRGB(107, 78, 61), Color3.fromRGB(98, 74, 52) }

-- Доски рушащегося насеста: настоящие по размеру, летят вниз с вращением.
local function collapsePlanks(position: Vector3, dirIn: Vector3)
	local side = V3(-dirIn.Z, 0, dirIn.X)
	for i = 1, 9 do
		local o = side * random:NextNumber(-3.2, 3.2) + dirIn * random:NextNumber(-1.5, 1.5)
		local p = part({
			Name = "Plank",
			Size = V3(random:NextNumber(0.8, 1.0), 0.4, random:NextNumber(2.5, 5)),
			CFrame = CFrame.lookAt(position + o, position + o + dirIn) * CFrame.Angles(0, math.rad(90), 0),
			Color = WOOD[random:NextInteger(1, #WOOD)],
			Material = Enum.Material.WoodPlanks,
		})
		table.insert(debris, {
			part = p,
			velocity = dirIn * random:NextNumber(2, 7) + V3(random:NextNumber(-3, 3), random:NextNumber(2, 8), random:NextNumber(-3, 3)),
			spin = V3(random:NextNumber(-5, 5), random:NextNumber(-3, 3), random:NextNumber(-5, 5)),
			life = random:NextNumber(1.6, 2.4),
			age = 0,
			floor = 0.2,
		})
	end
	burst(position, 26, V.N, 0.3, 12)
	burst(position - V3(0, 6, 0), 18, Color3.fromRGB(255, 179, 71), 0.22, 9, true)
end

-- Верёвка крюка: от неё к насесту, гаснет за время подъёма.
local function hookRope(from: Vector3, to: Vector3, duration: number)
	local a, b = from + V3(0, 4.5, 0), to + V3(0, 1.5, 0)
	local rope = part({
		Name = "HookRope",
		Size = V3(0.12, 0.12, (b - a).Magnitude),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = Color3.fromRGB(70, 60, 52),
		Material = Enum.Material.Fabric,
	})
	local hook = part({ Name = "Hook", Size = V3(0.5, 0.5, 0.5), CFrame = CFrame.new(b), Color = V.L, Material = Enum.Material.Metal })
	burst(b, 8, V.L, 0.15, 6)
	sfx("chains", b)
	task.delay(duration + 0.4, function()
		rope:Destroy()
		hook:Destroy()
	end)
end

-- ===== Обработчики =====

local function onFloorEvent(payload)
	if type(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	if kind == "bannerPlanted" then
		buildBanner(payload.zone or "?", payload.position, payload.radius or 12)
		notify("Знамя поднято — у знамени враги не дрогнут")
		sfx("slam", payload.position)
	elseif kind == "bannerFell" then
		fellBanner(payload.zone or "?")
		notify("Знамя пало! Строй сломан")
		sfx("explode", payload.position)
		shake(0.25, 0.3)
	elseif kind == "horn" then
		notify("Сотник трубит сбор!")
		shake(0.45, 0.6)
	elseif kind == "arbalestPerch" then
		if payload.index == 1 then
			sfx("door")
			shake(0.2, 0.3)
			notify("Арбалетчица на насесте — сломай светящуюся подпору!", "danger")
		else
			notify(("Насест %d из %d — снова подпора"):format(payload.index or 1, payload.total or 3))
		end
		if payload.support then
			ring(payload.support + V3(0, 0.1, 0), 3, Color3.fromRGB(255, 179, 71), 0.8)
		end
	elseif kind == "perchCollapse" then
		if typeof(payload.position) == "Vector3" then
			collapsePlanks(payload.position, typeof(payload.dirIn) == "Vector3" and payload.dirIn or V3(0, 0, 1))
			sfx("explode", payload.position)
		end
		shake(0.5, 0.5)
		notify("Насест рухнул! Бей, пока оглушена", "danger")
	elseif kind == "arbalestHook" then
		if typeof(payload.from) == "Vector3" and typeof(payload.to) == "Vector3" then
			hookRope(payload.from, payload.to, payload.duration or 1.2)
		end
	elseif kind == "arbalestGround" then
		notify("Насестов больше нет — бой на земле")
	elseif kind == "trapsPlaced" then
		placeTraps(payload.positions, payload.radius or 2, payload.duration, payload.pin)
	elseif kind == "trapSprung" then
		local best, bestD = nil, math.huge
		for index, trap in ipairs(traps) do
			local d = (trap.position - payload.position).Magnitude
			if d < bestD then
				best, bestD = index, d
			end
		end
		if best and bestD < 3 then
			removeTrap(best, true)
		end
		if payload.player == player then
			notify(payload.pin and "Цепной болт! Пригвождён" or "Капкан! Ноги схвачены")
			shake(0.2, 0.2)
		end
	elseif kind == "keyDrop" then
		addKeyMarker(payload.key, payload.position)
		notify(("Выпал %s"):format(payload.name or "ключ"), "levelUp")
	elseif kind == "keyPicked" then
		removeKeyMarker(payload.key)
		notify(("Получен: %s"):format(payload.name or "ключ"), "levelUp")
	elseif kind == "keyScene" then
		for _, at in ipairs({ payload.lockL, payload.lockR }) do
			if typeof(at) == "Vector3" then
				burst(at, 30, V.A, 0.2, 14, true)
				ring(at - V3(0, 2, 0), 4, V.A, 0.6)
				sfx("door", at)
			end
		end
		shake(0.35, (payload.duration or 3) * 0.5)
		notify("Ключи повёрнуты — Хранилище отпирается")
	elseif kind == "hold" then
		if payload.phase == "start" then
			hold = { endsAt = payload.endsAt or (serverNow() + (payload.duration or 60)), duration = payload.duration or 60 }
			if holdUi then
				holdUi.gui.Enabled = true
			end
			notify("Держитесь! Лебёдка поднимает решётку")
		else
			hold = nil
			if holdUi then
				holdUi.gui.Enabled = false
			end
		end
	elseif kind == "bridgeBreak" then
		for _, at in ipairs(payload.positions or {}) do
			burst(at, 18, V.N, 0.35, 10)
		end
		sfx("slam", payload.positions and payload.positions[1])
		shake(0.3, 0.3)
		notify("Доски моста рухнули!")
	elseif kind == "zoneLock" then
		if payload.locked then
			notify("Ворота опустились!", "danger")
			sfx("door")
			shake(0.15, 0.25)
		end
	elseif kind == "ambush" then
		notify("ЗАСАДА!", "danger")
		sfx("enemyWindup")
		shake(0.2, 0.3)
	elseif kind == "fell" then
		notify("Падение: −25% здоровья")
		shake(0.4, 0.3)
	elseif kind == "newRun" or kind == "playerDied" then
		hold = nil
		if holdUi then
			holdUi.gui.Enabled = false
		end
		for index = #traps, 1, -1 do
			removeTrap(index, false)
		end
		for zoneId, b in pairs(planted) do
			for _, p in ipairs(b.parts) do
				p:Destroy()
			end
			planted[zoneId] = nil
		end
		for _, m in ipairs(table.clone(keyMarkers)) do
			removeKeyMarker(m.key)
		end
	end
end

local function onEnemyEvent(payload)
	if type(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	if kind == "shieldBlock" then
		if payload.position then
			burst(payload.position, 8, V.H, 0.12, 16, true)
			sfx("parryFail", payload.position)
		end
	elseif kind == "shieldBroken" then
		local model = payload.model
		local root = model and (model:FindFirstChild("Root") or model.PrimaryPart)
		if root then
			burst(root.Position, 30, V.A, 0.16, 20, true)
			ring(root.Position - V3(0, (model:GetAttribute("EnemyHeight") or 6) * 0.5, 0), 5, V.A, 0.4)
		end
		notify("Щит пробит! Бей, пока он открыт")
		sfx("hitHeavy")
	elseif kind == "stunResisted" then
		if payload.position then
			ring(payload.position, 3, V.A, 0.3)
		end
	elseif kind == "interrupted" then
		local model = payload.model
		local root = model and (model:FindFirstChild("Root") or model.PrimaryPart)
		if root then
			burst(root.Position + V3(0, 1, 0), 18, V.X, 0.15, 14, true)
		end
		notify("Выстрел сорван!")
	end
end

-- ===== Слежение за мини-боссами =====

local function track(instance)
	if not instance:IsA("Model") then
		return
	end
	local typeId = instance:GetAttribute("EnemyType")
	if typeId == "centurion" then
		centurions[instance] = true
	elseif typeId == "arbalest" and not arbalests[instance] then
		arbalests[instance] = { icon = reloadIcon() }
	else
		return
	end
	instance.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			centurions[instance] = nil
			local entry = arbalests[instance]
			if entry then
				entry.icon.hub:Destroy()
				for _, s in ipairs(entry.icon.spokes) do
					s:Destroy()
				end
				arbalests[instance] = nil
			end
		end
	end)
end

local accum = 0
local function step(dt: number)
	local now = os.clock()
	stepDebris(dt)
	stepBanners(now)
	stepTraps(now)
	stepKeys(now)
	stepHold(dt)
	for model, entry in pairs(arbalests) do
		updateArbalest(model, entry, now)
	end
	accum += dt
	if accum >= 0.1 then
		accum = 0
		for model in pairs(centurions) do
			updateCenturion(model)
		end
	end
end

function MiniBossFx.start()
	folder()
	buildKeyUi()
	buildHoldUi()
	local floorRemote = Net.get("FloorEvent")
	if floorRemote then
		floorRemote.OnClientEvent:Connect(onFloorEvent)
	end
	local enemyRemote = Net.get("EnemyEvent")
	if enemyRemote then
		enemyRemote.OnClientEvent:Connect(onEnemyEvent)
	end
	Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			task.defer(track, d)
		elseif d.Name == "FloorRuntime" and d:IsA("Folder") then
			watchRuntime(d)
		end
	end)
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("Model") then
			track(d)
		end
	end
	local runtime = Workspace:FindFirstChild("FloorRuntime")
	if runtime then
		watchRuntime(runtime)
	end
	for _, info in ipairs(KEYS) do
		player:GetAttributeChangedSignal(info.id):Connect(refreshKeys)
	end
	player:GetAttributeChangedSignal("Zone"):Connect(refreshKeys)
	refreshKeys()
	RunService.Heartbeat:Connect(step)
end

return MiniBossFx
