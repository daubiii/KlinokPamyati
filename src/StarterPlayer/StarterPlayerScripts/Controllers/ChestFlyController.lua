--!nonstrict
-- ChestFlyController (клиент) — сундук этажа v3 летит в сумку
--
-- Сервер (ChestService.grant) шлёт «ChestGranted». Здесь:
--   1. в комнате, где был бы сундук, бьёт столб света этажа, квадраты памяти
--      стекаются в точку — и из них проявляется сундук (свой дизайн этажа);
--   2. сундук всплывает, разворачивается к герою и парит;
--   3. летит по дуге к герою, вращаясь и уменьшаясь, со шлейфом квадратов;
--   4. «пуф» у героя — значок сундука летит в кнопку «Инвентарь» на HUD,
--      сверху лента «ПОЛУЧЕН СУНДУК · <имя>».
-- Модель — локальная (ChestModel), другим игрокам не видна: у каждого свой сундук.
-- В долине с непустой сумкой сундуков — напоминание «Сундуки ждут».

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Chests = require(Shared.Config.Chests)
local ChestModel = require(Shared.Util.ChestModel)
local Net = require(Shared.Net.Net)

local Lib = script.Parent.Parent.Lib
local Bus = require(Lib.Bus)
local ChestVisual = require(Lib.ChestVisual)
local UiFx = require(Lib.UiFx)
local UiSound = require(Lib.UiSound)
local PixelHudController = require(script.Parent.PixelHudController)

local ChestFlyController = {}

local player = Players.LocalPlayer
local MEM = Color3.fromRGB(111, 227, 255)
local GOLD = Color3.fromRGB(255, 214, 110)
local FLY = Chests.Fly

local queue = {}
local busy = false

local function fxFolder()
	local folder = Workspace:FindFirstChild("KlinokChestFx")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "KlinokChestFx"
		folder.Parent = Workspace
	end
	return folder
end

local function tween(object, time: number, props, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function cube(color: Color3, size: number, cf: CFrame)
	local part = Instance.new("Part")
	part.Name = "MemoryCube"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.one * size
	part.CFrame = cf
	part.Parent = fxFolder()
	return part
end

local function rootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function bezier(a: Vector3, b: Vector3, c: Vector3, t: number): Vector3
	local u = 1 - t
	return a * (u * u) + b * (2 * u * t) + c * (t * t)
end

local function easeOutBack(t: number): number
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

-- Столб света и кольцо на полу.
local function beacon(ground: Vector3, color: Color3, gold: boolean)
	local column = Instance.new("Part")
	column.Name = "ChestBeacon"
	column.Anchored = true
	column.CanCollide = false
	column.CanQuery = false
	column.CanTouch = false
	column.CastShadow = false
	column.Material = Enum.Material.Neon
	column.Color = color
	column.Transparency = 0.25
	column.Size = Vector3.new(gold and 1.6 or 1.1, 18, gold and 1.6 or 1.1)
	column.CFrame = CFrame.new(ground + Vector3.new(0, 9, 0))
	column.Parent = fxFolder()
	tween(column, 0.9, { Transparency = 1, Size = Vector3.new(0.1, 22, 0.1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(column, 1)

	local ring = Instance.new("Part")
	ring.Name = "ChestRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.12, 1, 1)
	ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = fxFolder()
	tween(ring, 0.8, { Size = Vector3.new(0.12, gold and 12 or 9, gold and 12 or 9), Transparency = 1 })
	Debris:AddItem(ring, 0.85)
end

-- Квадраты памяти стекаются в точку (проявление сундука).
local function converge(center: Vector3, colors, count: number, time: number)
	local rng = Random.new()
	for _ = 1, count do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(3, 5.5)
		local from = center + Vector3.new(math.cos(a) * r, rng:NextNumber(-0.5, 3), math.sin(a) * r)
		local p = cube(colors[rng:NextInteger(1, #colors)], rng:NextNumber(0.18, 0.34), CFrame.new(from) * CFrame.Angles(rng:NextNumber() * 3, rng:NextNumber() * 3, 0))
		tween(p, time * rng:NextNumber(0.7, 1), { CFrame = CFrame.new(center), Size = Vector3.one * 0.05, Transparency = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(p, time + 0.05)
	end
end

local function burst(center: Vector3, colors, count: number, radius: number)
	local rng = Random.new()
	for _ = 1, count do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 1), rng:NextNumber(-1, 1))
		if dir.Magnitude < 0.05 then
			dir = Vector3.yAxis
		end
		local p = cube(colors[rng:NextInteger(1, #colors)], rng:NextNumber(0.16, 0.3), CFrame.new(center))
		local time = rng:NextNumber(0.3, 0.5)
		tween(p, time, { CFrame = CFrame.new(center + dir.Unit * radius * rng:NextNumber(0.5, 1)) * CFrame.Angles(rng:NextNumber() * 4, rng:NextNumber() * 4, 0), Size = Vector3.one * 0.04, Transparency = 1 })
		Debris:AddItem(p, time + 0.05)
	end
end

-- Сундук: проявиться → парить → лететь к герою. Возвращает мировую точку прибытия.
local function flyWorld(info, designId: string): Vector3?
	local root = rootPart()
	if not root or typeof(info.position) ~= "Vector3" then
		return nil
	end
	local gold = info.grade == "gold"
	local floorColors = Chests.Floors[Chests.clampFloor(info.floor)].colors
	local accent = Color3.fromHex(floorColors[3])
	local colors = gold and { MEM, GOLD, accent } or { MEM, accent, Color3.fromHex(floorColors[4]) }
	local ground: Vector3 = info.position
	local handle = ChestModel.build(designId, { parent = fxFolder() })
	ChestModel.setTransparency(handle, 1)
	local function facing(target: Vector3): CFrame
		local d = (target - ground) * Vector3.new(1, 0, 1)
		if d.Magnitude < 0.1 then
			return CFrame.new()
		end
		-- лицо сундука (+Z) — к герою
		return CFrame.lookAt(Vector3.zero, -d.Unit)
	end

	beacon(ground, gold and GOLD or accent, gold)
	converge(ground + Vector3.new(0, 1, 0), colors, gold and 26 or 18, FLY.appear)
	UiSound.play("chest_appear")

	local started = os.clock()
	local appearEnd = FLY.appear
	local hoverEnd = appearEnd + FLY.hover
	local hoverAt = ground + Vector3.new(0, FLY.startHeight, 0)
	local flyFrom = nil
	local flyTime = FLY.flyMin
	local spin = 0
	local lastTrail = 0
	local arrived = nil
	local transparent = true
	local faceStart = facing(root.Position)

	local done = Instance.new("BindableEvent")
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - started
		local target = rootPart()
		local targetPos = target and (target.Position + Vector3.new(0, 0.6, 0)) or hoverAt
		if t < appearEnd then
			local a = t / appearEnd
			local k = 0.25 + 0.75 * easeOutBack(a)
			ChestModel.setTransparency(handle, 1 - math.clamp(a * 1.6, 0, 1))
			transparent = true
			local cf = CFrame.new(ground + Vector3.new(0, 0.4 * a, 0)) * faceStart * CFrame.Angles(0, (1 - a) * 2.5, 0)
			ChestModel.place(handle, cf, k)
			if handle.light then
				handle.light.Brightness = a * 2.5
			end
		elseif t < hoverEnd then
			if transparent then
				ChestModel.setTransparency(handle, 0)
				transparent = false
			end
			local a = (t - appearEnd) / FLY.hover
			local pos = ground:Lerp(hoverAt, smooth(a)) + Vector3.new(0, math.sin(t * 9) * 0.08, 0)
			local face = faceStart:Lerp(facing(targetPos), smooth(a))
			ChestModel.place(handle, CFrame.new(pos) * face * CFrame.Angles(math.sin(t * 6) * 0.06, 0, math.cos(t * 5) * 0.05), 1)
			if handle.light then
				handle.light.Brightness = 2.5 + math.sin(t * 12) * 1
			end
		else
			if not flyFrom then
				flyFrom = handle.root.Position
				flyTime = math.clamp(FLY.flyMin + (targetPos - flyFrom).Magnitude / 60, FLY.flyMin, FLY.flyMax)
				UiSound.play("chest_fly")
			end
			local a = math.clamp((t - hoverEnd) / flyTime, 0, 1)
			local e = a ^ 1.7
			local lift = 3 + (targetPos - flyFrom).Magnitude * 0.18
			local control = (flyFrom + targetPos) / 2 + Vector3.new(0, lift, 0)
			local pos = bezier(flyFrom, control, targetPos, e)
			spin += dt * (6 + a * 16)
			local k = 1 - 0.78 * smooth(a)
			ChestModel.place(handle, CFrame.new(pos) * facing(targetPos) * CFrame.Angles(0, spin, 0) * CFrame.new(0, -0.5 * k, 0), k)
			if t - lastTrail > 0.035 then
				lastTrail = t
				local p = cube(colors[math.random(1, #colors)], 0.22 + 0.14 * k, CFrame.new(pos + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.6))
				tween(p, 0.45, { Size = Vector3.one * 0.03, Transparency = 1, CFrame = p.CFrame + Vector3.new(0, -0.6, 0) })
				Debris:AddItem(p, 0.5)
			end
			if a >= 1 then
				arrived = pos
				connection:Disconnect()
				done:Fire()
			end
		end
	end)
	done.Event:Wait()
	done:Destroy()
	handle.model:Destroy()
	burst(arrived, colors, gold and 18 or 12, 3)
	UiSound.play("chest_pickup")
	Bus.emit("shake", { amount = 0.06, time = 0.12 })
	return arrived
end

-- Значок сундука из точки экрана в кнопку «Инвентарь».
local function flyIcon(designId: string, fromScreen: Vector2?, onArrive)
	local to = PixelHudController.inventoryPoint()
	local layer = UiFx.layer()
	if not to or not layer then
		onArrive()
		return
	end
	local scale = layer.AbsoluteSize.X / math.max(layer.Size.X.Offset, 1)
	local function toLayer(p: Vector2): Vector2
		return (p - layer.AbsolutePosition) / scale
	end
	local camera = Workspace.CurrentCamera
	local from = fromScreen or (camera and camera.ViewportSize / 2) or to
	local a, b = toLayer(from), toLayer(to)
	local icon = ChestVisual.image(layer, designId, "icon", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(a.X, a.Y),
		Size = UDim2.fromOffset(72, 72),
		ZIndex = 70,
	})
	local started = os.clock()
	local duration = 0.55
	local lift = math.min(180, (b - a).Magnitude * 0.35)
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - started) / duration, 0, 1)
		local e = t * t
		local p = a:Lerp(b, e) - Vector2.new(0, math.sin(t * math.pi) * lift)
		local s = 72 * (1 - 0.55 * e)
		icon.Position = UDim2.fromOffset(p.X, p.Y)
		icon.Size = UDim2.fromOffset(s, s)
		icon.Rotation = math.sin(t * math.pi * 2) * 12
		if t >= 1 then
			connection:Disconnect()
			icon:Destroy()
			UiFx.burst(layer, b, { MEM, GOLD, Color3.fromRGB(248, 240, 222) }, 14, 60)
			onArrive()
		end
	end)
end

local function play(info)
	local designId = ChestModel.designId(info.floor, info.grade)
	local gold = info.grade == "gold"
	PixelHudController.setChestFlying(true)
	local okWorld, arrived = pcall(flyWorld, info, designId)
	if not okWorld then
		warn("[ChestFlyController] полёт: " .. tostring(arrived))
		arrived = nil
	end
	local fromScreen = nil
	local camera = Workspace.CurrentCamera
	if arrived and camera then
		local v, visible = camera:WorldToViewportPoint(arrived)
		if visible then
			fromScreen = Vector2.new(v.X, v.Y)
		end
	end
	local finished = Instance.new("BindableEvent")
	flyIcon(designId, fromScreen, function()
		PixelHudController.setChestFlying(false)
		PixelHudController.pulseInventory()
		PixelHudController.banner(gold and "ПОЛУЧЕН ЗОЛОТОЙ СУНДУК" or "ПОЛУЧЕН СУНДУК", info.name or "Сундук", gold and "medal" or "reward_pop", {
			chest = designId,
			time = 3,
			topColor = gold and Color3.fromRGB(150, 90, 10) or nil,
		})
		finished:Fire()
	end)
	finished.Event:Wait()
	finished:Destroy()
end

local function pump()
	if busy then
		return
	end
	busy = true
	while #queue > 0 do
		local info = table.remove(queue, 1)
		local ok, err = pcall(play, info)
		if not ok then
			warn("[ChestFlyController] " .. tostring(err))
			PixelHudController.setChestFlying(false)
		end
		task.wait(0.2)
	end
	busy = false
end

-- В долине: напомнить, что сундуки ждут.
local function remindInHub()
	local n = player:GetAttribute("ChestsStored") or 0
	if n <= 0 or player:GetAttribute("Zone") == "Floor" then
		return
	end
	local word = (n % 10 == 1 and n % 100 ~= 11) and "сундук ждёт" or ((n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 10 or n % 100 >= 20)) and "сундука ждут" or "сундуков ждут")
	PixelHudController.banner(("%d %s"):format(n, word):upper(), "Открой в сумке [I] → «Сундуки»", "reward_pop", { icon = "chest", time = 3.4 })
end

function ChestFlyController.start()
	task.spawn(function()
		local remote = Net.get("ChestGranted")
		if not remote then
			warn("[ChestFlyController] нет ремоута ChestGranted")
			return
		end
		remote.OnClientEvent:Connect(function(info)
			if type(info) ~= "table" then
				return
			end
			table.insert(queue, info)
			task.spawn(pump)
		end)
	end)
	local lastZone = player:GetAttribute("Zone")
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		local zone = player:GetAttribute("Zone")
		if lastZone == "Floor" and zone ~= "Floor" then
			task.delay(2.5, remindInHub)
		end
		lastZone = zone
	end)
	-- Вход в игру с сундуками в сумке.
	task.delay(6, function()
		if (player:GetAttribute("ChestsStored") or 0) > 0 and player:GetAttribute("Zone") ~= "Floor" then
			remindInHub()
		end
	end)
	print("[ChestFlyController] сундуки летят в сумку")
end

return ChestFlyController
