--!nonstrict
-- Floor2Atmosphere (клиент)
-- Настроение этажа 2 «Затопленные сады» (решение Артёма 29.10.2026: зелёные сумерки).
--   * свет: сумерки, бирюзовая дымка, мягкий bloom; на этаже 1 — его прежний
--     свет (значения FloorScenery), в хабе свет ведёт HubController;
--   * погода у камеры: морось, полосы тумана, светлячки, падающие листья;
--   * карта: ореолы и мошкара у фонарей, блики у заросших стен (подсказка
--     секрета), мельничное колесо крутится (быстрее в удержании), колёса
--     вентилей проворачиваются.
-- Всё локально; дальше 120 стад от камеры эмиттеры выключены.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)

local TEX = require(script.Parent.Parent.Lib.FxTex)

local Floor2Atmosphere = {}

local player = Players.LocalPlayer
local hex = Color3.fromHex
local V3 = Vector3.new

local MAP = "Floor2Map"
local NEAR = 120

-- ===== Свет =====

local PROFILES = {
	-- Этаж 1: как FloorScenery.setupLighting (пыльный закат).
	[1] = {
		lighting = {
			ClockTime = 17.5, Brightness = 1.5, Ambient = hex("#3A2E2A"), OutdoorAmbient = hex("#7A5C48"),
			ColorShift_Top = hex("#D9D2C5"):Lerp(Color3.new(1, 1, 1), 0.2), EnvironmentDiffuseScale = 0.5, EnvironmentSpecularScale = 0.15,
		},
		atmosphere = { Density = 0.4, Offset = 0.3, Color = hex("#B98C64"), Decay = hex("#6E4636"), Glare = 0.1, Haze = 1.7 },
		bloom = { Intensity = 0.4, Size = 24, Threshold = 1.6 },
		grade = { Saturation = -0.15, Contrast = 0.1, Brightness = 0 },
		sunRays = { Intensity = 0.06, Spread = 0.7 },
		clouds = { Cover = 0.6, Density = 0.55 },
	},
	-- Этаж 2: зелёные сумерки — тёмная бирюза, туман, свечение воды и гнили.
	[2] = {
		lighting = {
			ClockTime = 18.7, Brightness = 1.1, Ambient = hex("#1F3A33"), OutdoorAmbient = hex("#3A6A58"),
			ColorShift_Top = hex("#9CC48A"), EnvironmentDiffuseScale = 0.4, EnvironmentSpecularScale = 0.25,
		},
		atmosphere = { Density = 0.46, Offset = 0.18, Color = hex("#5E8C7A"), Decay = hex("#1F3A33"), Glare = 0.05, Haze = 2.3 },
		bloom = { Intensity = 0.65, Size = 28, Threshold = 1.35 },
		grade = { Saturation = -0.05, Contrast = 0.12, Brightness = 0.02, TintColor = hex("#DDF2E6") },
		sunRays = { Intensity = 0.03, Spread = 0.5 },
		clouds = { Cover = 0.78, Density = 0.62, Color = hex("#6F8F80") },
	},
	-- Этаж 4 «Литейные»: тёплая копоть и янтарная дымка.
	[4] = {
		lighting = {
			ClockTime = 0.5, Brightness = 0.6, Ambient = hex("#2A2026"), OutdoorAmbient = hex("#3A2C2C"),
			ColorShift_Top = hex("#FFB070"), EnvironmentDiffuseScale = 0.3, EnvironmentSpecularScale = 0.35,
		},
		atmosphere = { Density = 0.42, Offset = 0.05, Color = hex("#6A4636"), Decay = hex("#1E1B1F"), Glare = 0, Haze = 2.0 },
		bloom = { Intensity = 0.8, Size = 30, Threshold = 1.2 },
		grade = { Saturation = 0.04, Contrast = 0.16, Brightness = 0, TintColor = hex("#FFE6D2") },
		sunRays = { Intensity = 0, Spread = 0.3 },
		clouds = { Cover = 0.9, Density = 0.7, Color = hex("#3A2E30") },
	},
	-- Этаж 5 «Зал хроник»: холодный фиолетово-синий полумрак.
	[5] = {
		lighting = {
			ClockTime = 21.5, Brightness = 0.8, Ambient = hex("#23204A"), OutdoorAmbient = hex("#3A3570"),
			ColorShift_Top = hex("#B8E3FF"), EnvironmentDiffuseScale = 0.4, EnvironmentSpecularScale = 0.3,
		},
		atmosphere = { Density = 0.38, Offset = 0.12, Color = hex("#4A3F8F"), Decay = hex("#1D1B3A"), Glare = 0.05, Haze = 1.8 },
		bloom = { Intensity = 0.7, Size = 28, Threshold = 1.3 },
		grade = { Saturation = -0.06, Contrast = 0.12, Brightness = 0.01, TintColor = hex("#E6E4FF") },
		sunRays = { Intensity = 0.04, Spread = 0.6 },
		clouds = { Cover = 0.7, Density = 0.5, Color = hex("#4A4580") },
	},
}

local EFFECT_NAMES = {
	atmosphere = { "KlinokAtmosphere", "Atmosphere" },
	bloom = { "KlinokBloom", "BloomEffect" },
	grade = { "KlinokColor", "ColorCorrectionEffect" },
	sunRays = { "KlinokSunRays", "SunRaysEffect" },
}

local function effectOf(kind: string)
	if kind == "clouds" then
		local terrain = Workspace:FindFirstChildOfClass("Terrain")
		return terrain and terrain:FindFirstChildOfClass("Clouds")
	end
	local spec = EFFECT_NAMES[kind]
	return Lighting:FindFirstChild(spec[1]) or Lighting:FindFirstChildOfClass(spec[2])
end

local applied = nil
local function applyProfile(floorId: number)
	local profile = PROFILES[floorId]
	if not profile or applied == floorId then
		return
	end
	applied = floorId
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, profile.lighting):Play()
	for kind, goal in pairs(profile) do
		if kind ~= "lighting" then
			local instance = effectOf(kind)
			if instance then
				TweenService:Create(instance, info, goal):Play()
			end
		end
	end
end

-- ===== Погода у камеры =====

local weather = nil -- { part, emitters = { { e, rate } }, near = Part }

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 1
	e.LightEmission = 0
	for key, value in pairs(props) do
		e[key] = value
	end
	e.Parent = parent
	return e
end

local function ns(...)
	local args = { ... }
	local points = {}
	for i = 1, #args, 2 do
		table.insert(points, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(points)
end

local function anchorPart(name: string, size: Vector3)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function buildWeather()
	local folder = Instance.new("Folder")
	folder.Name = "Floor2Weather"
	-- Высокий объём над камерой: морось и туман.
	local sky = anchorPart("Sky", V3(140, 2, 140))
	sky.Parent = folder
	local rain = emitter(sky, {
		Name = "Rain", Texture = TEX.trail, Color = ColorSequence.new(hex("#A9D6C8")), LightEmission = 0.15,
		Rate = 320, Lifetime = NumberRange.new(0.8, 1.0), Speed = NumberRange.new(55, 65),
		EmissionDirection = Enum.NormalId.Bottom, Orientation = Enum.ParticleOrientation.VelocityParallel,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = ns(0, 0.09, 1, 0.09), Transparency = ns(0, 0.75, 0.5, 0.6, 1, 0.85), Squash = ns(0, 3, 1, 3),
	})
	-- Низкий объём у земли: туман, светлячки, листья.
	local near = anchorPart("Near", V3(110, 10, 110))
	near.Parent = folder
	local mist = emitter(near, {
		Name = "Mist", Texture = TEX.smoke, Color = ColorSequence.new(hex("#6F9C88")), Rate = 5,
		Lifetime = NumberRange.new(9, 13), Speed = NumberRange.new(0.6, 1.4), SpreadAngle = Vector2.new(180, 0),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = ns(0, 14, 1, 26), Transparency = ns(0, 1, 0.3, 0.86, 0.7, 0.88, 1, 1), Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-4, 4), WindAffectsDrag = true, Drag = 0.4,
	})
	local fireflies = emitter(near, {
		Name = "Fireflies", Texture = TEX.glow, Color = ColorSequence.new(hex("#D8F27A"), hex("#7CF2D8")), LightEmission = 1, LightInfluence = 0,
		Rate = 22, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0.3, 1.1), SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = ns(0, 0.22, 0.5, 0.3, 1, 0.18), Transparency = ns(0, 1, 0.15, 0.2, 0.35, 0.7, 0.5, 0.1, 0.7, 0.6, 0.85, 0.15, 1, 1),
		Acceleration = V3(0, 0.15, 0), Drag = 0.8,
	})
	local leaves = emitter(near, {
		Name = "Leaves", Texture = TEX.rock, Color = ColorSequence.new(hex("#45855A"), hex("#9CC48A")),
		Rate = 6, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = ns(0, 0.35, 1, 0.3), Transparency = ns(0, 1, 0.1, 0.1, 0.85, 0.2, 1, 1),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-120, 120), Acceleration = V3(0, -1.6, 0),
		Drag = 1.2, WindAffectsDrag = true,
	})
	folder.Parent = Workspace
	return {
		folder = folder, sky = sky, near = near,
		emitters = { { e = rain, rate = rain.Rate }, { e = mist, rate = mist.Rate }, { e = fireflies, rate = fireflies.Rate }, { e = leaves, rate = leaves.Rate } },
		rain = rain,
	}
end

local previousWind = nil
local gust = { level = 0, nextAt = 0, untilT = 0 }

local function setWeather(active: boolean)
	if active and not weather then
		weather = buildWeather()
		previousWind = previousWind or Workspace.GlobalWind
		Workspace.GlobalWind = V3(5, 0, 2.5)
	elseif not active and weather then
		weather.folder:Destroy()
		weather = nil
		if previousWind then
			Workspace.GlobalWind = previousWind
			previousWind = nil
		end
	end
end

local function stepWeather(dt: number)
	if not weather then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	weather.sky.CFrame = CFrame.new(eye + V3(0, 34, 0))
	weather.near.CFrame = CFrame.new(eye + V3(0, -1, 0))
	-- Морось то усиливается, то стихает (раз в 20–45 с ливень на 6–10 с).
	local t = os.clock()
	if t >= gust.nextAt and t > gust.untilT then
		gust.untilT = t + math.random(6, 10)
		gust.nextAt = gust.untilT + math.random(20, 45)
	end
	local target = t < gust.untilT and 1 or 0
	gust.level += (target - gust.level) * math.min(dt * 0.6, 1)
	weather.rain.Rate = 320 * (1 + 1.6 * gust.level)
	Workspace.GlobalWind = V3(5, 0, 2.5) * (1 + gust.level)
	-- Под крышей (оранжерея, грот, склеп) дождь не идёт.
	local covered = Workspace:Raycast(eye, V3(0, 40, 0)) ~= nil
	weather.rain.Enabled = not covered
end

-- ===== Карта: фонари, секреты, колёса =====

local mapState = {
	map = nil,
	lamps = {}, -- { position, items }
	glints = {}, -- { model, emitter, part }
	wheel = nil, -- { parts, rel, center, angle }
	valves = {}, -- [id] = { parts, rel, center, spin }
}

local function bindMap(map)
	mapState.map = map
	mapState.lamps = {}
	mapState.glints = {}
	mapState.valves = {}
	mapState.wheel = nil
	local holder = Instance.new("Folder")
	holder.Name = "Floor2MapFx"
	holder.Parent = Workspace
	mapState.holder = holder
	for _, zone in ipairs(map:GetChildren()) do
		local lights = zone:FindFirstChild("Lights")
		for _, source in ipairs(lights and lights:GetChildren() or {}) do
			if source:IsA("BasePart") then
				local light = source:FindFirstChildOfClass("PointLight")
				local warm = light and light.Color.R > light.Color.B
				local halo = emitter(source, {
					Name = "Halo", Texture = TEX.glow, Color = ColorSequence.new(warm and hex("#FFC46B") or hex("#7CF2D8")),
					LightEmission = 1, LightInfluence = 0, Rate = 2, Lifetime = NumberRange.new(1.2, 1.6), Speed = NumberRange.new(0),
					Size = ns(0, 3.5, 1, 4.2), Transparency = ns(0, 1, 0.3, 0.82, 1, 1), LockedToPart = true,
				})
				local moths = emitter(source, {
					Name = "Moths", Texture = TEX.glow, Color = ColorSequence.new(hex("#F2F7D8")), LightEmission = 1, LightInfluence = 0,
					Rate = 4, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(0.8, 1.8), SpreadAngle = Vector2.new(180, 180),
					Size = ns(0, 0.12, 1, 0.08), Transparency = ns(0, 0.2, 1, 1), RotSpeed = NumberRange.new(-200, 200), Drag = 2,
				})
				halo.Enabled = false
				moths.Enabled = false
				table.insert(mapState.lamps, { position = source.Position, items = { halo, moths }, on = false })
			end
		end
		local dynamic = zone:FindFirstChild("Dynamic")
		for _, model in ipairs(dynamic and dynamic:GetChildren() or {}) do
			if model:IsA("Model") then
				if string.match(model.Name, "^F2Overgrowth") then
					local cf, size = model:GetBoundingBox()
					local part = anchorPart("Glint", size * 0.9)
					part.CFrame = cf
					part.Parent = holder
					local glint = emitter(part, {
						Name = "Glint", Texture = TEX.star, Color = ColorSequence.new(hex("#F2E8A0")), LightEmission = 1, LightInfluence = 0,
						Rate = 3, Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(0.2, 0.5), SpreadAngle = Vector2.new(180, 180),
						Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
						Size = ns(0, 0, 0.4, 0.55, 1, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60),
					})
					table.insert(mapState.glints, { model = model, emitter = glint, part = part })
				elseif model.Name == "F2MillWheel" or string.match(model.Name, "^F2Valve%d_Wheel$") then
					local cf, size = model:GetBoundingBox()
					local parts, rel = {}, {}
					for _, d in ipairs(model:GetDescendants()) do
						if d:IsA("BasePart") then
							table.insert(parts, d)
							table.insert(rel, cf:ToObjectSpace(d.CFrame))
						end
					end
					-- Ось колеса — самый тонкий размер коробки (X или Z).
					local entry = { parts = parts, rel = rel, center = cf, angle = 0, spin = 0, frames = {}, axis = size.X <= size.Z and "x" or "z" }
					if model.Name == "F2MillWheel" then
						mapState.wheel = entry
					else
						mapState.valves[string.match(model.Name, "^(F2Valve%d)")] = entry
					end
				end
			end
		end
	end
end

local function rotateEntry(entry, axisCF: CFrame)
	local frames = entry.frames
	table.clear(frames)
	for index, rel in ipairs(entry.rel) do
		frames[index] = entry.center * axisCF * rel
	end
	Workspace:BulkMoveTo(entry.parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

local lampCheck = 0
local function stepMap(dt: number)
	local map = mapState.map
	if not map or not map.Parent then
		local found = Workspace:FindFirstChild(MAP)
		if found then
			bindMap(found)
		end
		return
	end
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	lampCheck -= dt
	if lampCheck <= 0 then
		lampCheck = 0.5
		for _, lamp in ipairs(mapState.lamps) do
			local on = (lamp.position - eye).Magnitude < NEAR
			if on ~= lamp.on then
				lamp.on = on
				for _, item in ipairs(lamp.items) do
					item.Enabled = on
				end
			end
		end
		for _, glint in ipairs(mapState.glints) do
			local alive = glint.model.Parent ~= nil and not glint.model:GetAttribute("Broken")
			glint.emitter.Enabled = alive and (glint.part.Position - eye).Magnitude < NEAR
		end
	end
	-- Мельничное колесо: медленно всегда, быстро в удержании.
	local wheel = mapState.wheel
	if wheel and (wheel.center.Position - eye).Magnitude < 180 then
		local fast = map:GetAttribute("F2MillSpin") == true
		wheel.spin += ((fast and 1.6 or 0.35) - wheel.spin) * math.min(dt, 1)
		wheel.angle += wheel.spin * dt
		rotateEntry(wheel, wheel.axis == "x" and CFrame.Angles(wheel.angle, 0, 0) or CFrame.Angles(0, 0, wheel.angle))
	end
	-- Вентили: после поворота — два оборота колеса.
	for _, valve in pairs(mapState.valves) do
		if valve.turnUntil then
			local k = math.clamp(1 - (valve.turnUntil - os.clock()) / 2.0, 0, 1)
			local eased = 1 - (1 - k) ^ 3
			local a = eased * math.pi * 4
			rotateEntry(valve, valve.axis == "x" and CFrame.Angles(a, 0, 0) or CFrame.Angles(0, 0, a))
			if k >= 1 then
				valve.turnUntil = nil
			end
		end
	end
end

-- ===== Подключение =====

local function currentFloor(): number?
	if player:GetAttribute("Zone") ~= "Floor" then
		return nil
	end
	return player:GetAttribute("FloorId") or 1
end

local function refresh()
	local floorId = currentFloor()
	setWeather(floorId == 2)
	if floorId then
		-- После HubController (он возвращает свет этажа при выходе из хаба).
		task.delay(0.1, function()
			if currentFloor() == floorId then
				applied = nil
				applyProfile(floorId)
			end
		end)
	else
		applied = nil
	end
end

function Floor2Atmosphere.start()
	player:GetAttributeChangedSignal("Zone"):Connect(refresh)
	player:GetAttributeChangedSignal("FloorId"):Connect(refresh)
	refresh()
	local remote = Net.get("FloorEvent")
	if remote then
		remote.OnClientEvent:Connect(function(payload)
			if type(payload) == "table" and payload.kind == "f2valve" then
				local valve = mapState.valves[payload.id]
				if valve then
					valve.turnUntil = os.clock() + 2.0
				end
			end
		end)
	end
	RunService.RenderStepped:Connect(function(dt)
		stepWeather(dt)
		stepMap(dt)
	end)
	print("[Floor2Atmosphere] сумерки, дождь и туман этажа 2")
end

return Floor2Atmosphere
