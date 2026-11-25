--!nonstrict
-- Floor3Atmosphere (клиент)
-- Настроение этажа 3 «Псарни охоты» (тема «Королевская охота»): тёплый закат.
-- Значения зафиксированы по согласованному превью карты (ноябрь 2026):
--   * свет: ClockTime ~17, тёплый OutdoorAmbient (#8A6450), закатное небо —
--     оранжевый горизонт (#C8704A) → пурпурно-малиновый зенит (#4A2030),
--     дымка #B0624A → #7A3A36, мягкий bloom и лучи солнца;
--   * погода у камеры: золотая пыль в лучах, падающие осенние листья,
--     редкая низкая дымка у земли;
--   * карта: ореолы и мошкара у фонарей, искры над жаровнями и кострами;
--   * Terrain: осенние цвета травы, листвы, земли и камня (только на этаже 3).
-- Свет этажей 1–2 ведёт Floor2Atmosphere; этот модуль трогает Lighting только
-- на этаже 3 и при выходе возвращает небо (Sky) в исходное состояние.
-- Дальше 120 стад от камеры эмиттеры выключены.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local TEX = require(script.Parent.Parent.Lib.FxTex)

local Floor3Atmosphere = {}

local player = Players.LocalPlayer
local hex = Color3.fromHex
local V3 = Vector3.new

local FLOOR = 3
local MAP = "Floor3Map"
local NEAR = 120

-- ===== Свет (зафиксировано) =====

local PROFILE = {
	lighting = {
		ClockTime = 17.0, GeographicLatitude = 38, Brightness = 2.2,
		Ambient = hex("#4A2E2A"), OutdoorAmbient = hex("#8A6450"),
		ColorShift_Top = hex("#FFB37A"), ColorShift_Bottom = hex("#5A2E3A"),
		EnvironmentDiffuseScale = 0.45, EnvironmentSpecularScale = 0.2, ExposureCompensation = 0.3,
	},
	atmosphere = { Density = 0.34, Offset = 0.2, Color = hex("#C8704A"), Decay = hex("#4A2030"), Glare = 0.4, Haze = 1.9 },
	bloom = { Intensity = 0.55, Size = 26, Threshold = 1.4 },
	grade = { Saturation = 0.06, Contrast = 0.12, Brightness = 0, TintColor = hex("#FFE8D6") },
	sunRays = { Intensity = 0.1, Spread = 0.65 },
	clouds = { Cover = 0.55, Density = 0.5, Color = hex("#C47E70") },
}
-- Небо: крупное низкое солнце, без звёзд; исходные значения возвращаются при выходе.
local SKY = { SunAngularSize = 16, MoonAngularSize = 8, StarCount = 0, CelestialBodiesShown = true }

-- Создаются, если в Lighting их нет (имена как у Floor2Atmosphere/FloorScenery).
local EFFECTS = {
	atmosphere = { "KlinokAtmosphere", "Atmosphere" },
	bloom = { "KlinokBloom", "BloomEffect" },
	grade = { "KlinokColor", "ColorCorrectionEffect" },
	sunRays = { "KlinokSunRays", "SunRaysEffect" },
}

local function effectOf(kind: string, create: boolean)
	if kind == "clouds" then
		local terrain = Workspace:FindFirstChildOfClass("Terrain")
		return terrain and terrain:FindFirstChildOfClass("Clouds")
	end
	local spec = EFFECTS[kind]
	local found = Lighting:FindFirstChild(spec[1]) or Lighting:FindFirstChildOfClass(spec[2])
	if not found and create then
		found = Instance.new(spec[2])
		found.Name = spec[1]
		found.Parent = Lighting
	end
	return found
end

local savedSky = nil
local function applySky(on: boolean)
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		return
	end
	if on and not savedSky then
		savedSky = {}
		for key, value in pairs(SKY) do
			savedSky[key] = sky[key]
			sky[key] = value
		end
	elseif not on and savedSky then
		for key, value in pairs(savedSky) do
			sky[key] = value
		end
		savedSky = nil
	end
end

local applied = false
local function applyProfile()
	if applied then
		return
	end
	applied = true
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, PROFILE.lighting):Play()
	for kind, goal in pairs(PROFILE) do
		if kind ~= "lighting" then
			local instance = effectOf(kind, true)
			if instance then
				TweenService:Create(instance, info, goal):Play()
			end
		end
	end
	applySky(true)
end

-- ===== Погода у камеры =====

local weather = nil

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
	folder.Name = "Floor3Weather"
	local near = anchorPart("Near", V3(110, 14, 110))
	near.Parent = folder
	local high = anchorPart("High", V3(120, 2, 120))
	high.Parent = folder
	-- Золотая пыль, подсвеченная закатом.
	local dust = emitter(near, {
		Name = "Dust", Texture = TEX.glow, Color = ColorSequence.new(hex("#FFD08A"), hex("#FF9F6B")), LightEmission = 0.8, LightInfluence = 0.2,
		Rate = 26, Lifetime = NumberRange.new(5, 9), Speed = NumberRange.new(0.2, 0.7), SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = ns(0, 0.1, 0.5, 0.16, 1, 0.08), Transparency = ns(0, 1, 0.2, 0.45, 0.8, 0.55, 1, 1),
		Acceleration = V3(0.25, 0.05, 0.1), Drag = 0.6, WindAffectsDrag = true,
	})
	-- Осенние листья — сверху, кружатся и ложатся.
	local leaves = emitter(high, {
		Name = "Leaves", Texture = TEX.rock, Color = ColorSequence.new(hex("#8C3B2E"), hex("#D9A441")),
		Rate = 9, Lifetime = NumberRange.new(7, 10), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = ns(0, 0.38, 1, 0.32), Transparency = ns(0, 1, 0.1, 0.05, 0.85, 0.15, 1, 1),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-140, 140), Acceleration = V3(0, -2.2, 0),
		Drag = 1.1, WindAffectsDrag = true,
	})
	-- Низкая тёплая дымка.
	local haze = emitter(near, {
		Name = "Haze", Texture = TEX.smoke, Color = ColorSequence.new(hex("#B0624A"), hex("#7A3A36")), Rate = 3,
		Lifetime = NumberRange.new(10, 14), Speed = NumberRange.new(0.4, 1.0), SpreadAngle = Vector2.new(180, 0),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = ns(0, 16, 1, 28), Transparency = ns(0, 1, 0.3, 0.9, 0.7, 0.9, 1, 1), Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-3, 3), WindAffectsDrag = true, Drag = 0.4,
	})
	folder.Parent = Workspace
	return {
		folder = folder, near = near, high = high,
		emitters = { dust, leaves, haze },
	}
end

local previousWind = nil

local function setWeather(active: boolean)
	if active and not weather then
		weather = buildWeather()
		previousWind = previousWind or Workspace.GlobalWind
		Workspace.GlobalWind = V3(3.5, 0, 1.5)
	elseif not active and weather then
		weather.folder:Destroy()
		weather = nil
		if previousWind then
			Workspace.GlobalWind = previousWind
			previousWind = nil
		end
	end
end

local function stepWeather()
	if not weather then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	weather.near.CFrame = CFrame.new(eye + V3(0, 2, 0))
	weather.high.CFrame = CFrame.new(eye + V3(0, 26, 0))
	-- Под крышей (охотничий дом, часовня, трофейный зал) листья не падают.
	local covered = Workspace:Raycast(eye, V3(0, 40, 0)) ~= nil
	weather.emitters[2].Enabled = not covered
end

-- ===== Карта: фонари и огонь =====

local mapState = { map = nil, lamps = {}, holder = nil }

local function isFire(color: Color3): boolean
	-- Жаровни/костры — насыщенно-оранжевые; фонари — светлее и желтее.
	return color.R > 0.85 and color.G < 0.62 and color.B < 0.35
end

local function bindMap(map)
	mapState.map = map
	mapState.lamps = {}
	for _, zone in ipairs(map:GetChildren()) do
		local lights = zone:FindFirstChild("Lights")
		for _, source in ipairs(lights and lights:GetChildren() or {}) do
			if source:IsA("BasePart") then
				local light = source:FindFirstChildOfClass("PointLight")
				local fire = light and isFire(light.Color)
				local items = {}
				table.insert(items, emitter(source, {
					Name = "Halo", Texture = TEX.glow, Color = ColorSequence.new(fire and hex("#FF8A3D") or hex("#FFC46B")),
					LightEmission = 1, LightInfluence = 0, Rate = 2, Lifetime = NumberRange.new(1.2, 1.6), Speed = NumberRange.new(0),
					Size = ns(0, 3.2, 1, 4), Transparency = ns(0, 1, 0.3, 0.84, 1, 1), LockedToPart = true,
				}))
				if fire then
					table.insert(items, emitter(source, {
						Name = "Sparks", Texture = TEX.spark, Color = ColorSequence.new(hex("#FFD27A"), hex("#FF6A2A")),
						LightEmission = 1, LightInfluence = 0, Rate = 6, Lifetime = NumberRange.new(1.0, 1.8), Speed = NumberRange.new(2, 4),
						SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top, Acceleration = V3(0.6, 1.5, 0.2),
						Size = ns(0, 0.14, 1, 0.04), Transparency = ns(0, 0, 0.7, 0.3, 1, 1), Drag = 1.2,
					}))
				else
					table.insert(items, emitter(source, {
						Name = "Moths", Texture = TEX.glow, Color = ColorSequence.new(hex("#FFF0D0")), LightEmission = 1, LightInfluence = 0,
						Rate = 3, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(0.8, 1.8), SpreadAngle = Vector2.new(180, 180),
						Size = ns(0, 0.12, 1, 0.08), Transparency = ns(0, 0.2, 1, 1), RotSpeed = NumberRange.new(-200, 200), Drag = 2,
					}))
				end
				for _, item in ipairs(items) do
					item.Enabled = false
				end
				table.insert(mapState.lamps, { position = source.Position, items = items, on = false })
			end
		end
	end
end

local lampCheck = 0
local function stepMap(dt: number)
	local map = mapState.map
	if not map or not map.Parent then
		mapState.map = nil
		local found = Workspace:FindFirstChild(MAP)
		if found then
			bindMap(found)
		end
		return
	end
	lampCheck -= dt
	if lampCheck > 0 then
		return
	end
	lampCheck = 0.5
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	for _, lamp in ipairs(mapState.lamps) do
		local on = (lamp.position - eye).Magnitude < NEAR
		if on ~= lamp.on then
			lamp.on = on
			for _, item in ipairs(lamp.items) do
				item.Enabled = on
			end
		end
	end
end

-- ===== Цвета Terrain (осенние холмы) =====
-- Цвета материалов Terrain общие на весь мир, а холмы этажа 2 (BuildJungle) и
-- этажа 3 (BuildForest3) лежат на одних материалах. Этажи далеко друг от друга,
-- поэтому меняем цвета только у себя (клиент) на время этажа 3 и возвращаем.

local TERRAIN = {
	[Enum.Material.Grass] = hex("#7E7838"), -- сухая трава #7A7A3A / #9A8A46
	[Enum.Material.LeafyGrass] = hex("#A4542A"), -- палая листва #A8382A / #C8662A
	[Enum.Material.Ground] = hex("#6A4A36"), -- земля #6A4A36
	[Enum.Material.Rock] = hex("#6B5C50"), -- камень гряды
	[Enum.Material.Mud] = hex("#4A3226"), -- грязь у дорог
}
local savedTerrain = nil

local function applyTerrain(on: boolean)
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		return
	end
	if on then
		if not savedTerrain then
			savedTerrain = {}
			for material in pairs(TERRAIN) do
				savedTerrain[material] = terrain:GetMaterialColor(material)
			end
		end
		for material, color in pairs(TERRAIN) do
			terrain:SetMaterialColor(material, color)
		end
	elseif savedTerrain then
		for material, color in pairs(savedTerrain) do
			terrain:SetMaterialColor(material, color)
		end
		savedTerrain = nil
	end
end

-- ===== Подключение =====

local function onFloor3(): boolean
	return player:GetAttribute("Zone") == "Floor" and (player:GetAttribute("FloorId") or 1) == FLOOR
end

local function refresh()
	local active = onFloor3()
	setWeather(active)
	applyTerrain(active)
	if active then
		-- После HubController/Floor2Atmosphere (они выставляют свет при смене зоны).
		task.delay(0.2, function()
			if onFloor3() then
				applied = false
				applyProfile()
			end
		end)
	else
		applied = false
		applySky(false)
	end
end

function Floor3Atmosphere.start()
	player:GetAttributeChangedSignal("Zone"):Connect(refresh)
	player:GetAttributeChangedSignal("FloorId"):Connect(refresh)
	refresh()
	RunService.RenderStepped:Connect(function(dt)
		stepWeather()
		stepMap(dt)
	end)
	print("[Floor3Atmosphere] закат королевской охоты: свет, пыль, листья, огни")
end

return Floor3Atmosphere
