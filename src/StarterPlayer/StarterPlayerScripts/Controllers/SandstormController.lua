--!nonstrict
-- SandstormController (клиент)
-- Песчаная буря этажа 1: шаблон ReplicatedStorage.FX.Weather.Sandstorm ходит
-- за камерой, пока игрок на этаже (атрибут Zone = "Floor"). Частицы несёт
-- Workspace.GlobalWind; время от времени налетает порыв — выпуск растёт
-- (атрибут Gust у эмиттера), потом спадает. В хабе бури нет.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FxKit = require(script.Parent.Parent.Lib.FxKit)

local SandstormController = {}

local player = Players.LocalPlayer

local WIND = Vector3.new(-26, 0, 9) -- стады/с, по земле
local GUST_EVERY = { 18, 40 } -- пауза между порывами, с
local GUST_TIME = { 5, 9 } -- длительность порыва, с

local storm = nil -- { part, emitters = { { e, rate, gust } } }
local previousWind = nil
local gust = { level = 0, nextAt = 0, untilT = 0 }

local function build()
	local template = FxKit.template("Weather/Sandstorm")
	if not template then
		return nil
	end
	local part = template:Clone()
	part.Locked = false
	part.Parent = FxKit.folder()
	local emitters = {}
	for _, d in ipairs(part:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			table.insert(emitters, { e = d, rate = d.Rate, gust = d:GetAttribute("Gust") or 1 })
			d.Enabled = true
		end
	end
	return { part = part, emitters = emitters }
end

local function setActive(active: boolean)
	if active then
		if not storm or not storm.part.Parent then
			storm = build()
		end
		if previousWind == nil then
			previousWind = Workspace.GlobalWind
		end
		Workspace.GlobalWind = WIND
		gust.nextAt = os.clock() + math.random(GUST_EVERY[1], GUST_EVERY[2])
	else
		if storm then
			storm.part:Destroy()
			storm = nil
		end
		if previousWind ~= nil then
			Workspace.GlobalWind = previousWind
			previousWind = nil
		end
	end
end

local function step(dt: number)
	if not storm then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	-- Деталь чуть против ветра от камеры: частицы успевают долететь до игрока.
	local windDir = WIND.Unit
	local center = camera.CFrame.Position - windDir * 25 + Vector3.new(0, 6, 0)
	storm.part.CFrame = CFrame.lookAt(center, center + windDir)

	-- Порыв: плавно вверх, держится, плавно вниз.
	local t = os.clock()
	if t >= gust.nextAt and t > gust.untilT then
		gust.untilT = t + math.random(GUST_TIME[1], GUST_TIME[2])
		gust.nextAt = gust.untilT + math.random(GUST_EVERY[1], GUST_EVERY[2])
	end
	local target = t < gust.untilT and 1 or 0
	gust.level += (target - gust.level) * math.min(dt * 0.8, 1)
	for _, entry in ipairs(storm.emitters) do
		entry.e.Rate = entry.rate * (1 + (entry.gust - 1) * gust.level)
	end
	Workspace.GlobalWind = WIND * (1 + 0.8 * gust.level)
end

function SandstormController.start()
	-- Буря только на этаже 1 (на этаже 2 — дождь и туман, Floor2Atmosphere).
	local function refresh()
		setActive(player:GetAttribute("Zone") == "Floor" and (player:GetAttribute("FloorId") or 1) == 1)
	end
	player:GetAttributeChangedSignal("Zone"):Connect(refresh)
	player:GetAttributeChangedSignal("FloorId"):Connect(refresh)
	refresh()
	RunService.RenderStepped:Connect(step)
	print("[SandstormController] песчаная буря этажа")
end

return SandstormController
