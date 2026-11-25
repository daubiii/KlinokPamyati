--!nonstrict
-- Floor45Atmosphere (клиент)
-- Воздух этажей 4–5 вокруг камеры (свет и туман — профили [4]/[5] в
-- Floor2Atmosphere):
--
--   этаж 4  искры, поднимающиеся от горнов, пепел сверху, тёплая дымка;
--           свечение расплава в карте (детали Role = glow) мерцает
--   этаж 5  пыль в лучах, редкие страницы, медленно кружащие в воздухе;
--           руны и витражи (glow) мягко «дышат»
--
-- Всё — у камеры (одна опора с эмиттерами), карта не меняется.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TEX = require(script.Parent.Parent.Lib.FxTex)

local Floor45Atmosphere = {}

local V3 = Vector3.new
local rgb = Color3.fromRGB
local player = Players.LocalPlayer

local function nseq(points)
	local keys = {}
	for _, pt in ipairs(points) do
		table.insert(keys, NumberSequenceKeypoint.new(pt[1], pt[2]))
	end
	return NumberSequence.new(keys)
end

local anchor = nil
local emitters = {} -- [floorId] = { emitter }
local pages = {} -- летящие страницы этажа 5
local glows = {} -- [floorId] = { { part, base, phase } }
local current = nil

local function makeAnchor()
	if anchor and anchor.Parent then
		return anchor
	end
	anchor = Instance.new("Part")
	anchor.Name = "Floor45Air"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = V3(70, 24, 70)
	anchor.Parent = Workspace
	return anchor
end

local function emitter(o)
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.tex or TEX.glow
	e.Color = ColorSequence.new(o.color, o.color2 or o.color)
	e.LightEmission = o.light or 0.5
	e.LightInfluence = (o.light or 0) >= 1 and 0 or 0.7
	e.Rate = o.rate
	e.Lifetime = NumberRange.new(o.life[1], o.life[2])
	e.Speed = NumberRange.new(o.speed[1], o.speed[2])
	e.SpreadAngle = Vector2.new(o.spread or 20, o.spread or 20)
	e.EmissionDirection = o.dir or Enum.NormalId.Top
	e.Acceleration = o.accel or V3()
	e.Drag = o.drag or 0
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Size = o.size
	e.Transparency = o.transp
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-(o.rot or 20), o.rot or 20)
	e.Enabled = false
	e.Parent = makeAnchor()
	return e
end

local function build()
	emitters[4] = {
		-- искры горна
		emitter({ tex = TEX.spark, color = rgb(255, 200, 87), color2 = rgb(226, 103, 43), light = 1, rate = 14, life = { 2, 4 }, speed = { 1, 3 },
			accel = V3(0, 1.2, 0), spread = 60, size = nseq({ { 0, 0.14 }, { 0.7, 0.1 }, { 1, 0 } }), transp = nseq({ { 0, 0.2 }, { 0.8, 0.3 }, { 1, 1 } }), rot = 90 }),
		-- пепел
		emitter({ tex = TEX.smoke, color = rgb(74, 67, 80), light = 0, rate = 10, life = { 5, 8 }, speed = { 0.2, 0.8 }, dir = Enum.NormalId.Bottom,
			accel = V3(0.2, -0.4, 0.1), spread = 40, size = nseq({ { 0, 0.12 }, { 1, 0.18 } }), transp = nseq({ { 0, 1 }, { 0.2, 0.4 }, { 0.8, 0.5 }, { 1, 1 } }) }),
		-- тёплая дымка
		emitter({ tex = TEX.smoke, color = rgb(106, 70, 54), light = 0.1, rate = 2, life = { 6, 9 }, speed = { 0.2, 0.5 },
			spread = 180, size = nseq({ { 0, 6 }, { 1, 10 } }), transp = nseq({ { 0, 1 }, { 0.4, 0.88 }, { 1, 1 } }) }),
	}
	emitters[5] = {
		-- пыль в лучах
		emitter({ tex = TEX.glow, color = rgb(184, 227, 255), color2 = rgb(142, 124, 224), light = 1, rate = 16, life = { 4, 7 }, speed = { 0.1, 0.4 },
			spread = 180, size = nseq({ { 0, 0.06 }, { 0.5, 0.1 }, { 1, 0 } }), transp = nseq({ { 0, 1 }, { 0.3, 0.3 }, { 0.7, 0.4 }, { 1, 1 } }) }),
		-- холодная дымка
		emitter({ tex = TEX.smoke, color = rgb(74, 63, 143), light = 0.2, rate = 2, life = { 6, 9 }, speed = { 0.2, 0.5 },
			spread = 180, size = nseq({ { 0, 6 }, { 1, 11 } }), transp = nseq({ { 0, 1 }, { 0.4, 0.9 }, { 1, 1 } }) }),
	}
end

local function floorNow(): number?
	if player:GetAttribute("Zone") ~= "Floor" then
		return nil
	end
	local id = player:GetAttribute("FloorId")
	if id == 4 or id == 5 then
		return id
	end
	return nil
end

-- Свечение карты: детали Visual с атрибутом Role = glow.
local function collectGlows(floorId: number)
	local map = Workspace:FindFirstChild("Floor" .. floorId .. "Map")
	local list = {}
	if map then
		for _, d in ipairs(map:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("Role") == "glow" then
				table.insert(list, { part = d, base = d.Transparency, phase = math.random() * math.pi * 2 })
			end
		end
	end
	glows[floorId] = list
end

local function setFloor(floorId: number?)
	if current == floorId then
		return
	end
	current = floorId
	for id, list in pairs(emitters) do
		for _, e in ipairs(list) do
			e.Enabled = id == floorId
		end
	end
	if floorId then
		collectGlows(floorId)
	end
	if floorId ~= 5 then
		for _, p in ipairs(pages) do
			p.part:Destroy()
		end
		pages = {}
	end
end

local function spawnPage(center: Vector3)
	local p = Instance.new("Part")
	p.Name = "DriftPage"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = V3(0.7, 0.04, 0.9)
	p.Color = math.random() < 0.7 and rgb(236, 228, 204) or rgb(210, 198, 168)
	p.Material = Enum.Material.SmoothPlastic
	local start = center + V3(math.random(-25, 25), math.random(6, 14), math.random(-25, 25))
	p.CFrame = CFrame.new(start)
	p.Parent = Workspace:FindFirstChild("Floor45Fx") or anchor
	table.insert(pages, { part = p, start = start, born = os.clock(), life = math.random(7, 11), phase = math.random() * 6, drift = V3(math.random(-10, 10) / 10, 0, math.random(-10, 10) / 10) })
end

local nextPage = 0
local glowAcc = 0

local function step(dt: number)
	local floorId = floorNow()
	setFloor(floorId)
	if not floorId then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local focus = camera.CFrame.Position
	makeAnchor().CFrame = CFrame.new(focus + V3(0, 2, 0))
	local t = os.clock()
	if floorId == 5 then
		if t >= nextPage and #pages < 8 then
			nextPage = t + math.random(15, 35) / 10
			spawnPage(focus)
		end
		for index = #pages, 1, -1 do
			local page = pages[index]
			local age = t - page.born
			if age >= page.life or not page.part.Parent then
				page.part:Destroy()
				table.remove(pages, index)
			else
				local pos = page.start + page.drift * age + V3(math.sin(age * 0.9 + page.phase) * 1.5, -age * 0.8, math.cos(age * 0.7 + page.phase) * 1.2)
				page.part.CFrame = CFrame.new(pos) * CFrame.Angles(math.sin(age * 2 + page.phase) * 0.8, age * 0.6, math.cos(age * 1.7) * 0.6)
				page.part.Transparency = math.clamp((age - (page.life - 1.5)) / 1.5, 0, 1)
			end
		end
	end
	-- Мерцание свечения карты (10 раз в секунду, только ближние).
	glowAcc += dt
	if glowAcc >= 0.1 then
		glowAcc = 0
		local speed = floorId == 4 and 5.5 or 1.4
		local depth = floorId == 4 and 0.12 or 0.18
		for _, g in ipairs(glows[floorId] or {}) do
			local p = g.part
			if p.Parent and (p.Position - focus).Magnitude < 140 then
				local wobble = math.sin(t * speed + g.phase) * 0.5 + math.sin(t * speed * 2.3 + g.phase * 1.7) * 0.5
				p.Transparency = math.clamp(g.base + depth * (0.5 + 0.5 * wobble), 0, 0.95)
			end
		end
	end
end

function Floor45Atmosphere.start()
	build()
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		setFloor(floorNow())
	end)
	player:GetAttributeChangedSignal("FloorId"):Connect(function()
		current = nil
		setFloor(floorNow())
	end)
	RunService.RenderStepped:Connect(step)
	print("[Floor45Atmosphere] воздух этажей 4–5")
end

return Floor45Atmosphere
