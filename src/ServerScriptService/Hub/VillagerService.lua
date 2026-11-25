--!nonstrict
-- VillagerService (сервер)
-- Жители долины (ТЗ хаба, разделы 5–6). Строит R15-жителей по HubVillagers,
-- надевает аксессуары из ReplicatedStorage.HubAccessories, ставит на точки,
-- водит по маршрутам.
--
-- Разговор идёт через станции хаба: корень жителя помечен тегом HubStation
-- (StationId = "villager:<id>"), клиент показывает подсказку [E] и на телефоне
-- кнопку, сервер проверяет дистанцию в HubService и зовёт VillagerService.talk.
-- Свой ProximityPrompt не ставим: клавишу E забирает ChestController, а
-- перехватчик хаба уже умеет её делить.
--
-- Житель поворачивается к игроку, над головой на 4 с облачко с репликой,
-- у игрока — строка внизу экрана (рисует HubController).
-- Для квеста «Голоса долины»: VillagerService.Talked:Connect(function(player, villagerId) ... end)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local HubVillagers = require(Config:WaitForChild("HubVillagers"))
local HubDialogue = require(Config:WaitForChild("HubDialogue"))
local HubLayout = require(Config:WaitForChild("HubLayout"))
local Palette = require(Config:WaitForChild("Palette"))

local VillagerService = {}

local talkedEvent = Instance.new("BindableEvent")
VillagerService.Talked = talkedEvent.Event

-- Стандартные анимации Roblox (R15), доступны в любом месте.
local ANIM = {
	idle = "rbxassetid://507766388",
	walk = "rbxassetid://507777826",
	talk = "rbxassetid://507770239", -- взмах рукой
}

local BUBBLE_TIME = 4
local TALK_HOLD_RADIUS = 11 -- собеседник рядом — житель не уходит (окно разговора)
local PIXEL_FONT = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Regular)
local BUBBLE_PAPER = Palette.Hub.wh
local BUBBLE_INK = Palette.UI.panel

local folder = nil
local firstMet = {} -- [player][villagerId] = true
local lastLine = {} -- [villagerId] = индекс последней реплики
local living = {} -- [villagerId] = { model, root, talk = function }

-- → реплика, true если это первая встреча.
local function pickLine(v, player): (string, boolean)
	local d = HubDialogue[v.id]
	if not d then
		return "…", false
	end
	firstMet[player] = firstMet[player] or {}
	if d.first and not firstMet[player][v.id] then
		firstMet[player][v.id] = true
		return d.first, true
	end
	local lines = d.lines or {}
	if #lines == 0 then
		return d.first or "…", false
	end
	if #lines == 1 then
		return lines[1], false
	end
	local idx
	repeat
		idx = math.random(1, #lines)
	until idx ~= lastLine[v.id]
	lastLine[v.id] = idx
	return lines[idx], false
end

local function makeLabel(parent, text, size, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.FontFace = PIXEL_FONT
	l.TextSize = size
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.3
	l.TextStrokeColor3 = Palette.UI.panel
	l.Text = text
	l.Parent = parent
	return l
end

local function addNameplate(model, v)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Nameplate"
	bb.Size = UDim2.fromOffset(240, 40)
	bb.StudsOffset = Vector3.new(0, 2.2, 0)
	bb.MaxDistance = 60
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = bb
	makeLabel(bb, v.name, 12, Palette.Hub.wh)
	if v.title and v.title ~= "" then
		makeLabel(bb, v.title, 9, Palette.UI.textMuted)
	end
	bb.Parent = head
end

local function showBubble(model, text)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("Bubble")
	if old then
		old:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Bubble"
	bb.Size = UDim2.fromOffset(280, 84)
	bb.StudsOffset = Vector3.new(0, 4.4, 0)
	bb.MaxDistance = 40
	bb.LightInfluence = 0
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = BUBBLE_PAPER
	frame.BorderSizePixel = 0
	frame.Parent = bb
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = BUBBLE_INK
	stroke.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = frame
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = PIXEL_FONT
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = BUBBLE_INK
	label.Text = text
	label.Parent = frame
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 11
	limit.MinTextSize = 7
	limit.Parent = label
	bb.Parent = head
	task.delay(BUBBLE_TIME, function()
		if bb.Parent then
			bb:Destroy()
		end
	end)
end

local function applyGhost(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Transparency = math.max(d.Transparency, 0.45)
		end
		if d:IsA("Decal") then
			d.Transparency = 0.45
		end
	end
	local head = model:FindFirstChild("Head")
	if head then
		local light = Instance.new("PointLight")
		light.Color = Palette.Memory
		light.Range = 10
		light.Brightness = 0.8
		light.Parent = head
	end
end

local function buildModel(v)
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = v.skin
	desc.TorsoColor = v.shirt
	desc.LeftArmColor = v.arms
	desc.RightArmColor = v.arms
	desc.LeftLegColor = v.pants
	desc.RightLegColor = v.pants
	if v.kid then
		desc.HeightScale = 0.8
		desc.WidthScale = 0.85
		desc.DepthScale = 0.85
		desc.HeadScale = 0.95
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[VillagerService] не удалось создать " .. v.id .. ": " .. tostring(model))
		return nil
	end
	model.Name = v.id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.WalkSpeed = v.kid and 12 or 7
	hum.BreakJointsOnDeath = false
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

	local accFolder = ReplicatedStorage:FindFirstChild("HubAccessories")
	for _, accName in ipairs(v.acc or {}) do
		local src = accFolder and accFolder:FindFirstChild(accName)
		if src then
			hum:AddAccessory(src:Clone())
		else
			warn("[VillagerService] нет аксессуара " .. accName)
		end
	end
	if v.ghost then
		applyGhost(model)
	end
	addNameplate(model, v)
	return model, hum
end

local function playLoop(hum, id)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local a = Instance.new("Animation")
	a.AnimationId = id
	return animator:LoadAnimation(a)
end

local function faceTowards(root, pos)
	local look = Vector3.new(pos.X, root.Position.Y, pos.Z)
	if (look - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, look)
	end
end

local function spawnVillager(v)
	local model, hum = buildModel(v)
	if not model then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart")
	local home = HubLayout.world(v.pos)
	local route = nil
	if v.route then
		route = {}
		for index, point in ipairs(v.route) do
			route[index] = HubLayout.world(point)
		end
	end
	model:PivotTo(CFrame.new(home + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, math.rad(v.yaw or 0), 0))
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local idle = playLoop(hum, ANIM.idle)
	local walk = playLoop(hum, ANIM.walk)
	local talk = playLoop(hum, ANIM.talk)
	idle.Looped = true
	walk.Looped = true
	idle:Play()
	hum.Running:Connect(function(speed)
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play(0.2)
				idle:Stop(0.2)
			end
		elseif walk.IsPlaying then
			walk:Stop(0.2)
			idle:Play(0.2)
		end
	end)

	local talkingUntil = 0
	local talker = nil -- кто говорит: пока стоит рядом (окно разговора открыто), житель ждёт

	-- Точка разговора для станций хаба.
	root:SetAttribute("StationId", "villager:" .. v.id)
	root:SetAttribute("Verb", "Поговорить: " .. v.name)
	CollectionService:AddTag(root, "HubStation")

	living[v.id] = {
		model = model,
		root = root,
		talk = function(player)
			local line, first = pickLine(v, player)
			talkingUntil = os.clock() + BUBBLE_TIME
			talker = player
			hum:MoveTo(root.Position)
			local char = player.Character
			local pr = char and char:FindFirstChild("HumanoidRootPart")
			if pr then
				faceTowards(root, pr.Position)
			end
			talk:Play(0.1)
			showBubble(model, line)
			talkedEvent:Fire(player, v.id)
			return line, first
		end,
	}

	-- поведение: маршрут, блуждание рядом с домом, «смотреть на север»
	task.spawn(function()
		local i = 1
		while model.Parent do
			if talker then
				local char = talker.Parent and talker.Character
				local pr = char and char:FindFirstChild("HumanoidRootPart")
				if pr and (pr.Position - root.Position).Magnitude < TALK_HOLD_RADIUS then
					talkingUntil = math.max(talkingUntil, os.clock() + 1.5)
				else
					talker = nil
				end
			end
			if os.clock() < talkingUntil then
				task.wait(0.3)
				continue
			end
			if v.lookNorth and math.random() < 0.15 then
				faceTowards(root, root.Position + Vector3.new(0, 0, -50))
				task.wait(6)
			end
			local target
			if route and #route > 0 then
				target = route[i]
				i = i % #route + 1
			elseif v.wander and v.wander > 0 then
				local a = math.random() * math.pi * 2
				local r = math.random() * v.wander
				target = home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			end
			if target then
				hum:MoveTo(target)
				local done = false
				local conn = hum.MoveToFinished:Connect(function()
					done = true
				end)
				local t0 = os.clock()
				while not done and os.clock() - t0 < 12 and os.clock() >= talkingUntil do
					task.wait(0.2)
				end
				conn:Disconnect()
				if os.clock() < talkingUntil then
					hum:MoveTo(root.Position)
				end
			end
			if not route and not v.wander and v.yaw and os.clock() >= talkingUntil then
				-- стоячие жители возвращают исходный поворот после разговора
				root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(v.yaw), 0)
			end
			task.wait(v.pause or (3 + math.random() * 5))
		end
	end)
end

-- Где сейчас житель (для проверки дистанции на сервере).
function VillagerService.position(villagerId: string): Vector3?
	local entry = living[villagerId]
	return entry and entry.root.Parent and entry.root.Position or nil
end

function VillagerService.find(villagerId: string)
	for _, v in ipairs(HubVillagers) do
		if v.id == villagerId then
			return v
		end
	end
	return nil
end

-- Разговор: житель отвечает, сервер возвращает имя, титул и реплику
-- (first = true при первой встрече) — клиент открывает окно разговора.
function VillagerService.talk(player, villagerId: string)
	local entry = living[villagerId]
	local v = VillagerService.find(villagerId)
	if not entry or not v then
		return nil
	end
	local line, first = entry.talk(player)
	return { name = v.name, title = v.title, line = line, first = first }
end

function VillagerService.start()
	local existing = Workspace:FindFirstChild("HubVillagers")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "HubVillagers"
	folder.Parent = Workspace
	for _, v in ipairs(HubVillagers) do
		task.spawn(spawnVillager, v)
	end
	Players.PlayerRemoving:Connect(function(p)
		firstMet[p] = nil
	end)
end

return VillagerService
