--!nonstrict
-- HubController (клиент)
-- Всё, что игрок видит и трогает в «Долине Последнего Эха»:
--   * «Пробуждение»: чёрный экран, персонаж собирается из кубиков памяти;
--     уход во Врата — персонаж рассыпается на кубики;
--   * взаимодействие со станциями и жителями (клавиша Interact из Binds,
--     на телефоне кнопка-подсказка);
--   * окно Врат Печатей (пять миров, три сложности, замки), диалоги станций,
--     доска заданий Гильдии и плашка текущего задания слева;
--   * строка реплики жителя внизу экрана;
--   * свет: долина ↔ пещера (часть CaveLightingZone), свет этажа
--     возвращается при уходе из хаба;
--   * первый выход из горы: камера отъезжает и показывает долину, титр;
--   * у пруда в пещере на миг проступает отражение старика с молотом;
--   * ожившая долина: указатели, мельница, вихрь Врат, печати по прогрессу,
--     кубики памяти, мост, дым из труб, брызги водопада, птицы, бабочки, колокол;
--   * кнопка «К Вратам Печатей» на этаже и «В пещеру» в долине.
--
-- Клавишу E уже занимает ChestController (он «глотает» её всегда), поэтому
-- хаб вешает свой перехватчик с более высоким приоритетом: он забирает E
-- только рядом со станцией или жителем, в остальных случаях отдаёт дальше.
--
-- Карта большая и стримится (StreamingEnabled): детали долины приходят и
-- уходят, поэтому живой декор пересобирается по DescendantAdded/Removing.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Binds = require(Shared.Config.Binds)
local Hub = require(Shared.Config.Hub)
local HubLayout = require(Shared.Config.HubLayout)
local Palette = require(Shared.Config.Palette)
local Bus = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Bus"))
local UiSound = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiSound"))
local PixelUi = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("PixelUi"))

local player = Players.LocalPlayer
local FONT = Enum.Font.Code
local PIXEL = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Regular)
local H = Palette.Hub

local HubController = {}

local state = {
	inHub = false,
	panelOpen = false,
	busy = false,
	nearest = nil,
	openAnchor = nil,
	coverOn = true,
	pendingAwaken = nil,
	pendingZoneSync = nil, -- зона/экран менялись во время ролика: применить после
	typeId = 0,
	saved = nil, -- свет этажа на время пребывания в хабе
	lockBefore = nil,
	confirmUntil = 0,
	journeyUntil = 0,
	fxPool = {},
	ambient = nil,
	bannerToken = 0,
	talkToken = 0,
	quests = nil,
	inCave = nil,
	sawCave = false,
	vistaDone = false,
	pondReadyAt = 0,
	lastBell = nil,
}

local ui = {}
local remotes = {}

----------------------------------------------------------------------
-- Мелочи
----------------------------------------------------------------------

local function make(className: string, props, parent)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function horizontal(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function sfx(name: string, position: Vector3?)
	Bus.emit("sfx", { name = name, position = position })
end

local function ease(alpha: number): number
	alpha = math.clamp(alpha, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

local function cameraController()
	local scripts = player:FindFirstChild("PlayerScripts")
	local controllers = scripts and scripts:FindFirstChild("Controllers")
	local module = controllers and controllers:FindFirstChild("CameraController")
	if not module then
		return nil
	end
	local ok, result = pcall(require, module)
	return ok and result or nil
end

local function hubFolder(): Instance?
	return Workspace:FindFirstChild(Hub.FolderName)
end

local function findPath(root: Instance, path: string): Instance?
	local node = root
	for name in string.gmatch(path, "[^%.]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

----------------------------------------------------------------------
-- Интерфейс
----------------------------------------------------------------------

local function makeButton(parent, text: string, size: UDim2, accent: boolean?)
	local base = accent and Palette.UI.accent or Palette.UI.frame
	local stroke = accent and Palette.UI.accentBorder or Palette.UI.panel
	local button = make("TextButton", {
		Size = size,
		BackgroundColor3 = base,
		AutoButtonColor = false,
		Font = FONT,
		TextSize = 18,
		Text = text,
		TextColor3 = accent and Palette.UI.panel or Palette.UI.text,
	}, parent)
	make("UIStroke", { Color = stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
	local padding = make("UIPadding", {}, button)
	button:SetAttribute("Enabled", true)

	local function paint(hover: boolean)
		if not button:GetAttribute("Enabled") then
			button.BackgroundColor3 = Palette.UI.frame
			button.TextColor3 = Palette.UI.textMuted
			return
		end
		button.BackgroundColor3 = hover and lighten(base, 0.18) or base
		button.TextColor3 = accent and Palette.UI.panel or Palette.UI.text
	end
	button.MouseEnter:Connect(function()
		paint(true)
	end)
	button.MouseLeave:Connect(function()
		padding.PaddingTop = UDim.new(0, 0)
		paint(false)
	end)
	button.MouseButton1Down:Connect(function()
		if button:GetAttribute("Enabled") then
			padding.PaddingTop = UDim.new(0, 2) -- нажатие: сдвиг на 2 пикселя вниз
		end
	end)
	button.MouseButton1Up:Connect(function()
		padding.PaddingTop = UDim.new(0, 0)
	end)
	button:GetAttributeChangedSignal("Enabled"):Connect(function()
		paint(false)
	end)
	return button
end

local function setEnabled(button, enabled: boolean)
	button:SetAttribute("Enabled", enabled)
end

local function makePanel(name: string, size: Vector2)
	local frame = make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Palette.UI.panel,
		Visible = false,
		ZIndex = 20,
	}, ui.root)
	make("UIStroke", { Color = Palette.UI.frame, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	return frame
end

local function label(parent, props)
	local merged = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 18,
		TextColor3 = Palette.UI.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 21,
	}
	for key, value in pairs(props) do
		merged[key] = value
	end
	return make("TextLabel", merged, parent)
end

local function panelHeader(panel, text: string)
	local title = label(panel, {
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -40, 0, 30),
		TextSize = 24,
		TextColor3 = Palette.UI.accent,
		Text = text,
	})
	make("Frame", {
		Position = UDim2.fromOffset(20, 52),
		Size = UDim2.new(1, -40, 0, 3),
		BackgroundColor3 = Palette.UI.accentBorder,
		BorderSizePixel = 0,
		ZIndex = 21,
	}, panel)
	return title
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	if not camera or not ui.scale then
		return
	end
	local viewport = camera.ViewportSize
	local scale = math.clamp(math.min(viewport.X / 960, viewport.Y / 620), 0.6, 1.3)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		scale = math.clamp(scale, 0.7, 1.1)
	end
	ui.scale.Scale = scale
	-- UIScale растягивает и сам корень: без поправки он больше экрана, и всё,
	-- что прижато к правому и нижнему краю, уезжает за край.
	ui.root.Size = UDim2.fromScale(1 / scale, 1 / scale)
end

local function buildUi()
	local gui = make("ScreenGui", {
		Name = "KlinokHub",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 30,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	ui.gui = gui

	ui.root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	ui.scale = make("UIScale", {}, ui.root)
	updateScale()

	-- Титр места: пиксельный шрифт.
	ui.banner = label(ui.root, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.14, 0),
		Size = UDim2.fromOffset(900, 48),
		FontFace = PIXEL,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = H.wh,
		TextTransparency = 1,
		TextStrokeColor3 = Palette.UI.panel,
		TextStrokeTransparency = 1,
		ZIndex = 30,
	})
	ui.bannerSub = label(ui.root, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.14, 56),
		Size = UDim2.fromOffset(900, 28),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Palette.UI.accent,
		TextTransparency = 1,
		TextStrokeColor3 = Palette.UI.panel,
		TextStrokeTransparency = 1,
		ZIndex = 30,
	})

	-- Подсказка станции (кнопка, чтобы работало и на телефоне).
	ui.hint = makeButton(ui.root, "", UDim2.fromOffset(460, 48), true)
	ui.hint.AnchorPoint = Vector2.new(0.5, 1)
	ui.hint.Position = UDim2.new(0.5, 0, 1, -200) -- над полоской здоровья HUD
	ui.hint.Visible = false
	ui.hint.ZIndex = 25
	ui.hint.MouseButton1Click:Connect(function()
		if state.nearest then
			HubController.openStation(state.nearest:GetAttribute("StationId"))
		end
	end)

	-- Строка реплики жителя (над подсказкой).
	ui.talk = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -262),
		Size = UDim2.fromOffset(680, 64),
		BackgroundColor3 = Palette.UI.panel,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 24,
	}, ui.root)
	make("UIStroke", { Color = Palette.UI.accent, Thickness = 2 }, ui.talk)
	ui.talkText = label(ui.talk, {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 1, -16),
		TextSize = 18,
		RichText = true,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 25,
	})

	-- Короткое сообщение.
	ui.toast = label(ui.root, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -336),
		Size = UDim2.fromOffset(620, 28),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Palette.UI.danger,
		TextStrokeColor3 = Palette.UI.panel,
		TextStrokeTransparency = 0.3,
		Visible = false,
		ZIndex = 40,
	})

	-- Плашка текущего задания (слева, ниже карточки оружия HUD).
	ui.tracker = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.42, 0),
		Size = UDim2.fromOffset(290, 78),
		BackgroundColor3 = Palette.UI.panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 22,
	}, ui.root)
	make("UIStroke", { Color = Palette.UI.frame, Thickness = 3 }, ui.tracker)
	ui.trackerHead = label(ui.tracker, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 16),
		TextSize = 14,
		TextColor3 = Palette.UI.accent,
		Text = "ЗАДАНИЕ",
		ZIndex = 23,
	})
	ui.trackerTitle = label(ui.tracker, {
		Position = UDim2.fromOffset(12, 26),
		Size = UDim2.new(1, -24, 0, 22),
		TextSize = 18,
		ZIndex = 23,
	})
	ui.trackerProgress = label(ui.tracker, {
		Position = UDim2.fromOffset(12, 50),
		Size = UDim2.new(1, -24, 0, 20),
		TextSize = 16,
		TextColor3 = Palette.UI.textMuted,
		ZIndex = 23,
	})

	-- Кнопка возврата с этажа в хаб.
	ui.returnButton = makeButton(ui.root, "К Вратам Печатей", UDim2.fromOffset(220, 44), false)
	-- Справа под трекером комнат: слева сверху — карточка оружия HUD.
	ui.returnButton.AnchorPoint = Vector2.new(1, 0)
	ui.returnButton.Position = UDim2.new(1, -16, 0, 160)
	ui.returnButton.Visible = false
	ui.returnButton.ZIndex = 25
	ui.returnButton.MouseButton1Click:Connect(function()
		if os.clock() > state.confirmUntil then
			state.confirmUntil = os.clock() + 3
			ui.returnButton.Text = "Точно? Ещё раз"
			task.delay(3.05, function()
				if os.clock() > state.confirmUntil then
					ui.returnButton.Text = "К Вратам Печатей"
				end
			end)
			return
		end
		state.confirmUntil = 0
		ui.returnButton.Text = "К Вратам Печатей"
		pcall(function()
			remotes.RequestReturnHub:InvokeServer()
		end)
	end)

	-- Возврат в пещеру из хаба.
	ui.journeyButton = makeButton(ui.root, "В ПЕЩЕРУ", UDim2.fromOffset(190, 40), false)
	ui.journeyButton.AnchorPoint = Vector2.new(1, 0)
	ui.journeyButton.Position = UDim2.new(1, -16, 0, 160)
	ui.journeyButton.Visible = false
	ui.journeyButton.ZIndex = 25
	ui.journeyButton.TextSize = 16
	ui.journeyButton.MouseButton1Click:Connect(function()
		if os.clock() > state.journeyUntil then
			state.journeyUntil = os.clock() + 3
			ui.journeyButton.Text = "В ПЕЩЕРУ? ЕЩЁ РАЗ"
			task.delay(3.05, function()
				if os.clock() > state.journeyUntil then
					ui.journeyButton.Text = "В ПЕЩЕРУ"
				end
			end)
			return
		end
		state.journeyUntil = 0
		ui.journeyButton.Text = "В ПЕЩЕРУ"
		pcall(function()
			remotes.RequestJourneyStart:InvokeServer()
		end)
	end)

	-- Диалог станции.
	ui.dialog = makePanel("Dialog", Vector2.new(580, 300))
	ui.dialogTitle = panelHeader(ui.dialog, "")
	ui.dialogBody = label(ui.dialog, {
		Position = UDim2.fromOffset(20, 68),
		Size = UDim2.new(1, -40, 1, -148),
		TextSize = 20,
		MaxVisibleGraphemes = -1,
	})
	ui.dialogNext = makeButton(ui.dialog, "Дальше", UDim2.fromOffset(170, 48), true)
	ui.dialogNext.AnchorPoint = Vector2.new(1, 1)
	ui.dialogNext.Position = UDim2.new(1, -20, 1, -18)
	ui.dialogNext.ZIndex = 22
	ui.dialogClose = makeButton(ui.dialog, "Закрыть", UDim2.fromOffset(150, 48), false)
	ui.dialogClose.AnchorPoint = Vector2.new(0, 1)
	ui.dialogClose.Position = UDim2.new(0, 20, 1, -18)
	ui.dialogClose.ZIndex = 22

	-- Врата Печатей.
	ui.portal = makePanel("Portal", Vector2.new(900, 520))
	ui.portalTitle = panelHeader(ui.portal, "Врата Печатей")
	ui.portalCards = make("Frame", {
		Position = UDim2.fromOffset(20, 68),
		Size = UDim2.new(1, -40, 0, 250),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, ui.portal)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, ui.portalCards)
	ui.portalDiffs = make("Frame", {
		Position = UDim2.fromOffset(20, 328),
		Size = UDim2.new(1, -40, 0, 48),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, ui.portal)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, ui.portalDiffs)
	ui.portalNote = label(ui.portal, {
		Position = UDim2.fromOffset(20, 384),
		Size = UDim2.new(1, -40, 0, 44),
		TextSize = 16,
		TextColor3 = Palette.UI.textMuted,
	})
	ui.portalEnter = makeButton(ui.portal, "Войти", UDim2.fromOffset(280, 56), true)
	ui.portalEnter.AnchorPoint = Vector2.new(1, 1)
	ui.portalEnter.Position = UDim2.new(1, -20, 1, -20)
	ui.portalEnter.ZIndex = 22
	ui.portalClose = makeButton(ui.portal, "Закрыть", UDim2.fromOffset(150, 56), false)
	ui.portalClose.AnchorPoint = Vector2.new(0, 1)
	ui.portalClose.Position = UDim2.new(0, 20, 1, -20)
	ui.portalClose.ZIndex = 22

	-- Доска заданий Гильдии.
	ui.board = makePanel("QuestBoard", Vector2.new(720, 470))
	ui.boardTitle = panelHeader(ui.board, "Доска заданий Гильдии")
	ui.boardList = make("Frame", {
		Position = UDim2.fromOffset(20, 68),
		Size = UDim2.new(1, -40, 0, 316),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, ui.board)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, ui.boardList)
	ui.boardNote = label(ui.board, {
		Position = UDim2.fromOffset(20, 392),
		Size = UDim2.new(1, -220, 0, 56),
		TextSize = 16,
		TextColor3 = Palette.UI.textMuted,
		Text = "Платим золотом, а не песнями. — Ольгерд",
	})
	ui.boardClose = makeButton(ui.board, "Закрыть", UDim2.fromOffset(150, 48), false)
	ui.boardClose.AnchorPoint = Vector2.new(1, 1)
	ui.boardClose.Position = UDim2.new(1, -20, 1, -18)
	ui.boardClose.ZIndex = 22

	-- Чёрный экран на время переходов (последним, поверх всего).
	ui.cover = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.UI.panel,
		BorderSizePixel = 0,
		ZIndex = 200,
	}, gui)

	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

local function toast(text: string, color: Color3?)
	ui.toast.Text = text
	ui.toast.TextColor3 = color or Palette.UI.danger
	ui.toast.Visible = true
	local stamp = os.clock()
	ui.toast:SetAttribute("Stamp", stamp)
	task.delay(2.6, function()
		if ui.toast:GetAttribute("Stamp") == stamp then
			ui.toast.Visible = false
		end
	end)
end

local function setCover(on: boolean, seconds: number)
	state.coverOn = on
	ui.cover.Visible = true
	local tween = TweenService:Create(ui.cover, TweenInfo.new(seconds), { BackgroundTransparency = on and 0 or 1 })
	tween:Play()
	if not on then
		task.delay(seconds + 0.05, function()
			if not state.coverOn then
				ui.cover.Visible = false
			end
		end)
	end
end

-- Титр: Hub.Banners[key] или { title, sub }.
local function showBanner(key)
	local banner = type(key) == "table" and key or Hub.Banners[key]
	if not banner then
		return
	end
	state.bannerToken += 1
	local token = state.bannerToken
	ui.banner.Text = string.upper(banner.title)
	ui.bannerSub.Text = banner.sub or ""
	local fadeIn = TweenInfo.new(0.8)
	TweenService:Create(ui.banner, fadeIn, { TextTransparency = 0, TextStrokeTransparency = 0.4 }):Play()
	TweenService:Create(ui.bannerSub, fadeIn, { TextTransparency = 0, TextStrokeTransparency = 0.5 }):Play()
	task.delay(4, function()
		if state.bannerToken ~= token then
			return
		end
		local fadeOut = TweenInfo.new(1.2)
		TweenService:Create(ui.banner, fadeOut, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(ui.bannerSub, fadeOut, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

-- Реплика жителя внизу экрана на 4 с.
local function showTalk(name: string, line: string)
	state.talkToken += 1
	local token = state.talkToken
	ui.talkText.Text = ('<font color="#%s">%s:</font> %s'):format(Palette.UI.accent:ToHex(), name, line)
	ui.talk.Visible = true
	task.delay(4, function()
		if state.talkToken == token then
			ui.talk.Visible = false
		end
	end)
end

----------------------------------------------------------------------
-- Панели: открыть / закрыть
----------------------------------------------------------------------

local function releaseCursor()
	if state.lockBefore ~= nil then
		return
	end
	local camera = cameraController()
	if camera and camera.state then
		state.lockBefore = camera.state().locked == true
		camera.setLock(false)
	else
		state.lockBefore = false
	end
end

local function restoreCursor()
	if state.lockBefore == nil then
		return
	end
	local camera = cameraController()
	if camera and camera.setLock then
		camera.setLock(state.lockBefore)
	end
	state.lockBefore = nil
end

local refreshTracker -- плашка задания, объявлена ниже

local function closePanels()
	state.typeId += 1
	ui.dialog.Visible = false
	ui.portal.Visible = false
	ui.board.Visible = false
	if state.panelOpen then
		state.panelOpen = false
		restoreCursor()
		ui.journeyButton.Visible = state.inHub
		refreshTracker()
	end
end

local function openPanel(panel)
	state.panelOpen = true
	ui.hint.Visible = false
	-- Плашка задания и кнопка справа лежат поверх окон: прячем на время.
	ui.tracker.Visible = false
	ui.journeyButton.Visible = false
	releaseCursor()
	panel.Visible = true
end

-- Печатная машинка для реплик.
local function typeText(target, text: string, onDone)
	state.typeId += 1
	local id = state.typeId
	target.Text = text
	target.MaxVisibleGraphemes = 0
	task.spawn(function()
		local total = utf8.len(text) or #text
		for count = 1, total do
			if state.typeId ~= id then
				return
			end
			target.MaxVisibleGraphemes = count
			task.wait(0.018)
		end
		target.MaxVisibleGraphemes = -1
		if onDone and state.typeId == id then
			onDone()
		end
	end)
end

local dialogConnections = {}

local function showDialog(payload)
	for _, connection in ipairs(dialogConnections) do
		connection:Disconnect()
	end
	dialogConnections = {}

	local pages = {}
	for _, line in ipairs(payload.lines or {}) do
		table.insert(pages, { text = line, note = false })
	end
	if payload.soon then
		table.insert(pages, { text = payload.soon, note = true })
	end
	if #pages == 0 then
		table.insert(pages, { text = "...", note = false })
	end

	ui.dialogTitle.Text = payload.title or ""
	local index = 0
	local typing = false

	local function show(pageIndex)
		local page = pages[pageIndex]
		ui.dialogBody.TextColor3 = page.note and Palette.Memory or Palette.UI.text
		typing = true
		typeText(ui.dialogBody, page.text, function()
			typing = false
		end)
		ui.dialogNext.Text = pageIndex >= #pages and "Закрыть" or "Дальше"
	end

	local function advance()
		if typing then
			state.typeId += 1
			ui.dialogBody.MaxVisibleGraphemes = -1
			typing = false
			return
		end
		if index >= #pages then
			closePanels()
			return
		end
		index += 1
		show(index)
	end

	table.insert(dialogConnections, ui.dialogNext.MouseButton1Click:Connect(advance))
	table.insert(dialogConnections, ui.dialogClose.MouseButton1Click:Connect(closePanels))
	openPanel(ui.dialog)
	index = 1
	show(1)
end

----------------------------------------------------------------------
-- Рассыпаться на кубики (уход во Врата) и собраться (пробуждение)
----------------------------------------------------------------------

local function fxFolder()
	local existing = Workspace:FindFirstChild("HubFx")
	if existing then
		return existing
	end
	return make("Folder", { Name = "HubFx" }, Workspace)
end

local function takeCube()
	local cube = table.remove(state.fxPool)
	if cube then
		return cube
	end
	return make("Part", {
		Name = "FxCube",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = Palette.Memory,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}, nil)
end

local function giveCube(cube)
	cube.Parent = nil
	if #state.fxPool < Hub.Awaken.cubes * 2 then
		table.insert(state.fxPool, cube)
	else
		cube:Destroy()
	end
end

-- Персонаж проявляется или тает (только у нас на экране, структуру не трогаем).
local function fadeCharacter(character, seconds: number, fadeOut: boolean)
	local parts = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	task.spawn(function()
		local started = os.clock()
		while true do
			local alpha = math.clamp((os.clock() - started) / seconds, 0, 1)
			for _, part in ipairs(parts) do
				if part.Parent then
					part.LocalTransparencyModifier = fadeOut and alpha or 1 - alpha
				end
			end
			if alpha >= 1 or not character.Parent then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

local function playAwaken(cframe: CFrame, userId: number)
	local camera = Workspace.CurrentCamera
	local isLocal = userId == player.UserId
	if camera and not isLocal and (camera.CFrame.Position - cframe.Position).Magnitude > Hub.Awaken.maxViewDistance then
		return
	end
	local config = Hub.Awaken
	local folder = fxFolder()
	local feet = cframe.Position - Vector3.new(0, 3.0, 0)
	sfx("hubAwaken", isLocal and nil or cframe.Position)

	local owner = Players:GetPlayerByUserId(userId)
	if owner and owner.Character then
		fadeCharacter(owner.Character, config.duration, false)
	end

	-- Кубики слетаются в силуэт.
	for _ = 1, config.cubes do
		local cube = takeCube()
		cube.Size = Vector3.new(config.cubeSize, config.cubeSize, config.cubeSize)
		cube.Transparency = 0.1
		local angle = math.random() * math.pi * 2
		local distance = 5 + math.random() * 7
		cube.Position = feet + Vector3.new(math.cos(angle) * distance, 1 + math.random() * 11, math.sin(angle) * distance)
		cube.Orientation = Vector3.new(math.random(0, 90), math.random(0, 90), 0)
		cube.Parent = folder
		local target = feet + Vector3.new((math.random() - 0.5) * 2, 0.5 + math.random() * 4.6, (math.random() - 0.5) * 1.2)
		local travel = config.duration * (0.65 + math.random() * 0.35)
		local tween = TweenService:Create(cube, TweenInfo.new(travel, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = target,
			Orientation = Vector3.zero,
		})
		tween.Completed:Once(function()
			local fade = TweenService:Create(cube, TweenInfo.new(0.25), { Transparency = 1 })
			fade.Completed:Once(function()
				giveCube(cube)
			end)
			fade:Play()
		end)
		tween:Play()
	end

	-- Волна по полу после сборки.
	task.delay(config.duration * 0.85, function()
		local ring = make("Part", {
			Name = "AwakenRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 1, 1),
			CFrame = CFrame.new(feet.X, feet.Y + 0.15, feet.Z) * CFrame.Angles(0, 0, math.pi / 2),
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.Neon,
			Color = Palette.Memory,
			Transparency = 0.2,
		}, folder)
		local tween = TweenService:Create(ring, TweenInfo.new(config.ringTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.2, 14, 14),
			Transparency = 1,
		})
		tween.Completed:Once(function()
			ring:Destroy()
		end)
		tween:Play()
	end)
end

-- Уход во Врата: голубая вспышка, персонаж рассыпается на кубики за 0,4 с.
local function playDissolve()
	local character = player.Character
	local root = rootPart()
	if not character or not root then
		return
	end
	local folder = fxFolder()
	sfx("hubPortal")
	fadeCharacter(character, 0.4, true)
	local flash = make("Part", {
		Name = "PortalFlash",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		CFrame = root.CFrame,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = Palette.Memory,
		Transparency = 0.3,
	}, folder)
	local grow = TweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(9, 9, 9),
		Transparency = 1,
	})
	grow.Completed:Once(function()
		flash:Destroy()
	end)
	grow:Play()
	for _ = 1, Hub.Awaken.cubes do
		local cube = takeCube()
		local size = Hub.Awaken.cubeSize
		cube.Size = Vector3.new(size, size, size)
		cube.Transparency = 0.1
		local start = root.Position + Vector3.new((math.random() - 0.5) * 2, (math.random() - 0.4) * 5, (math.random() - 0.5) * 1.2)
		cube.Position = start
		cube.Parent = folder
		local angle = math.random() * math.pi * 2
		local target = start + Vector3.new(math.cos(angle) * 4, 2 + math.random() * 5, math.sin(angle) * 4)
		local tween = TweenService:Create(cube, TweenInfo.new(0.4 + math.random() * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = target,
			Transparency = 1,
			Orientation = Vector3.new(math.random(0, 180), math.random(0, 180), 0),
		})
		tween.Completed:Once(function()
			giveCube(cube)
		end)
		tween:Play()
	end
	-- На этаже персонаж снова виден: экран к тому времени уже открыт.
	task.delay(1.6, function()
		if character.Parent then
			for _, descendant in ipairs(character:GetDescendants()) do
				if descendant:IsA("BasePart") then
					descendant.LocalTransparencyModifier = 0
				end
			end
		end
	end)
end

----------------------------------------------------------------------
-- Врата Печатей: выбор мира и сложности
----------------------------------------------------------------------

local portalConnections = {}

local function showPortal(payload)
	for _, connection in ipairs(portalConnections) do
		connection:Disconnect()
	end
	portalConnections = {}
	for _, child in ipairs(ui.portalCards:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for _, child in ipairs(ui.portalDiffs:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	ui.portalTitle.Text = payload.title or "Врата Печатей"

	local floors = payload.floors or {}
	local difficulties = payload.difficulties or Hub.Difficulties
	local selection = { floor = 1, difficulty = "normal" }
	local cardButtons = {}
	local diffButtons = {}

	local function refresh()
		for id, card in pairs(cardButtons) do
			local info = floors[id]
			local selected = id == selection.floor
			local usable = info and info.built and info.unlocked
			card.BackgroundColor3 = selected and Palette.UI.frame or Palette.UI.panel
			local stroke = card:FindFirstChildOfClass("UIStroke")
			stroke.Color = selected and Palette.UI.accent or Palette.UI.frame
			card.Status.Text = not info.built and "скоро" or (info.unlocked and "печать открыта" or "печать закрыта")
			card.Status.TextColor3 = usable and Palette.Memory or Palette.UI.textMuted
			for _, descendant in ipairs(card:GetDescendants()) do
				if descendant:IsA("TextLabel") and descendant.Name ~= "Status" then
					descendant.TextTransparency = usable and 0 or 0.5
				end
			end
		end
		local info = floors[selection.floor]
		local canEnter = false
		for _, difficulty in ipairs(difficulties) do
			local button = diffButtons[difficulty.id]
			local open = info and info.built and info.difficulties[difficulty.id] == true
			setEnabled(button, open)
			button.Text = open and difficulty.name or (difficulty.name .. " (закрыто)")
			local stroke = button:FindFirstChildOfClass("UIStroke")
			stroke.Color = (difficulty.id == selection.difficulty) and Palette.UI.accent or Palette.UI.panel
			if difficulty.id == selection.difficulty and open then
				canEnter = true
			end
		end
		setEnabled(ui.portalEnter, canEnter)
		if not info then
			ui.portalNote.Text = ""
		elseif not info.built then
			ui.portalNote.Text = "Мир " .. info.id .. " ещё не собран."
		elseif not info.unlocked then
			ui.portalNote.Text = "Печать откроется после прохождения «ненормального» в предыдущем мире."
		elseif not canEnter then
			ui.portalNote.Text = "Эта сложность пока закрыта."
		else
			ui.portalNote.Text = info.theme
		end
	end

	for order, id in ipairs({ 1, 2, 3, 4, 5 }) do
		local info = floors[id]
		if info then
			local card = make("TextButton", {
				Name = "Card" .. id,
				LayoutOrder = order,
				Size = UDim2.fromOffset(160, 250),
				BackgroundColor3 = Palette.UI.panel,
				AutoButtonColor = false,
				Text = "",
				ZIndex = 22,
			}, ui.portalCards)
			make("UIStroke", { Color = Palette.UI.frame, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
			-- четыре цвета палитры этажа
			for chip, color in ipairs(info.colors) do
				make("Frame", {
					Position = UDim2.fromOffset(8 + (chip - 1) * 36, 8),
					Size = UDim2.fromOffset(32, 32),
					BackgroundColor3 = color,
					BorderSizePixel = 0,
					ZIndex = 23,
				}, card)
			end
			label(card, {
				Position = UDim2.fromOffset(8, 48),
				Size = UDim2.new(1, -16, 0, 24),
				TextSize = 16,
				TextColor3 = Palette.UI.accent,
				Text = "ПЕЧАТЬ " .. id,
				ZIndex = 23,
			})
			label(card, {
				Position = UDim2.fromOffset(8, 74),
				Size = UDim2.new(1, -16, 0, 56),
				TextSize = 18,
				Text = info.name,
				ZIndex = 23,
			})
			label(card, {
				Position = UDim2.fromOffset(8, 134),
				Size = UDim2.new(1, -16, 0, 72),
				TextSize = 14,
				TextColor3 = Palette.UI.textMuted,
				Text = info.theme,
				ZIndex = 23,
			})
			label(card, {
				Name = "Status",
				Position = UDim2.fromOffset(8, 218),
				Size = UDim2.new(1, -16, 0, 24),
				TextSize = 14,
				Text = "",
				ZIndex = 23,
			})
			cardButtons[id] = card
			table.insert(portalConnections, card.MouseButton1Click:Connect(function()
				selection.floor = id
				refresh()
			end))
		end
	end

	for order, difficulty in ipairs(difficulties) do
		local button = makeButton(ui.portalDiffs, difficulty.name, UDim2.fromOffset(250, 48), false)
		button.LayoutOrder = order
		button.ZIndex = 22
		diffButtons[difficulty.id] = button
		table.insert(portalConnections, button.MouseButton1Click:Connect(function()
			if button:GetAttribute("Enabled") then
				selection.difficulty = difficulty.id
				refresh()
			end
		end))
	end

	table.insert(portalConnections, ui.portalClose.MouseButton1Click:Connect(closePanels))
	table.insert(portalConnections, ui.portalEnter.MouseButton1Click:Connect(function()
		if not ui.portalEnter:GetAttribute("Enabled") or state.busy then
			return
		end
		state.busy = true
		local ok, response = pcall(function()
			return remotes.RequestEnterFloor:InvokeServer(selection.floor, selection.difficulty)
		end)
		state.busy = false
		if ok and type(response) == "table" and response.ok then
			closePanels()
			playDissolve()
		else
			ui.portalNote.Text = (ok and type(response) == "table" and response.err) or "Не получилось войти"
			ui.portalNote.TextColor3 = Palette.UI.danger
			task.delay(2.4, function()
				ui.portalNote.TextColor3 = Palette.UI.textMuted
				refresh()
			end)
		end
	end))

	openPanel(ui.portal)
	refresh()
end

----------------------------------------------------------------------
-- Задания: доска и плашка слева
----------------------------------------------------------------------

-- Плашку задания теперь рисует PixelHudController по атрибутам QuestTitle /
-- QuestProgress (их ставит QuestService); прежняя плашка хаба не показывается.
refreshTracker = function()
	ui.tracker.Visible = false
end

local boardConnections = {}

local function showBoard(snapshot)
	for _, connection in ipairs(boardConnections) do
		connection:Disconnect()
	end
	boardConnections = {}
	for _, child in ipairs(ui.boardList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for order, quest in ipairs(snapshot.list or {}) do
		local row = make("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 98),
			BackgroundColor3 = quest.status == "active" and Palette.UI.frame or Palette.UI.panel,
			ZIndex = 22,
		}, ui.boardList)
		make("UIStroke", {
			Color = quest.status == "active" and Palette.UI.accent or Palette.UI.frame,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, row)
		local muted = quest.status == "done" or quest.status == "locked"
		label(row, {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -190, 0, 24),
			TextSize = 20,
			TextColor3 = muted and Palette.UI.textMuted or Palette.UI.accent,
			Text = quest.status == "locked" and "???" or quest.title,
			ZIndex = 23,
		})
		label(row, {
			Position = UDim2.fromOffset(12, 34),
			Size = UDim2.new(1, -190, 0, 36),
			TextSize = 15,
			TextColor3 = muted and Palette.UI.textMuted or Palette.UI.text,
			Text = quest.status == "locked" and "Листок приколот, но надпись не разобрать. Сначала прошлые задания." or quest.text,
			ZIndex = 23,
		})
		label(row, {
			Position = UDim2.fromOffset(12, 72),
			Size = UDim2.new(1, -190, 0, 20),
			TextSize = 14,
			TextColor3 = Palette.UI.textMuted,
			Text = quest.status == "locked" and "" or ("Награда: " .. quest.reward),
			ZIndex = 23,
		})
		local statusText = ({
			done = "Выполнено",
			active = ("%d / %d"):format(quest.progress, quest.goal),
			locked = "Закрыто",
		})[quest.status]
		if quest.status == "available" then
			local take = makeButton(row, "Взять", UDim2.fromOffset(150, 44), true)
			take.AnchorPoint = Vector2.new(1, 0.5)
			take.Position = UDim2.new(1, -12, 0.5, 0)
			take.ZIndex = 24
			table.insert(boardConnections, take.MouseButton1Click:Connect(function()
				if state.busy then
					return
				end
				state.busy = true
				local ok, response = pcall(function()
					return remotes.RequestQuest:InvokeServer("take", quest.id)
				end)
				state.busy = false
				if ok and type(response) == "table" and response.ok and response.snapshot then
					state.quests = response.snapshot
					refreshTracker()
					sfx("ui")
					showBoard(response.snapshot)
				elseif ok and type(response) == "table" and response.err then
					toast(response.err)
				end
			end))
		else
			label(row, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(160, 24),
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextColor3 = quest.status == "done" and Palette.Memory or (quest.status == "active" and Palette.UI.accent or Palette.UI.textMuted),
				Text = statusText,
				ZIndex = 23,
			})
		end
	end
	table.insert(boardConnections, ui.boardClose.MouseButton1Click:Connect(closePanels))
	if not ui.board.Visible then
		openPanel(ui.board)
	end
end

-- Панель выполненного задания: заголовок, имя квеста, карточки награды
-- (иконки атласа Ui приходят с сервера в completed.cards). PLAN квесты:
-- выполнение и получение награды должны ощущаться — pop-анимация,
-- фанфары hubQuest + медаль UiSound. Заменяет прежний текстовый баннер.
local questRewardToken = 0
local questRewardGui = nil
local function showQuestReward(data)
	questRewardToken += 1
	local token = questRewardToken
	if questRewardGui then
		questRewardGui:Destroy()
		questRewardGui = nil
	end
	local cards = type(data.cards) == "table" and data.cards or {}
	if #cards == 0 then
		cards = { { icon = "quest", text = "" } }
	end
	local rowW = #cards * 128
	local width = math.max(380, rowW + 60)
	local panel = make("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.23, 0),
		Size = UDim2.fromOffset(width, 128),
		BackgroundColor3 = Palette.UI.panel,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		ZIndex = 32,
	}, ui.root)
	questRewardGui = panel
	make("UIStroke", { Color = Palette.UI.accentBorder, Thickness = 2 }, panel)
	label(panel, {
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 18),
		FontFace = PIXEL,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Palette.UI.accent,
		Text = "ЗАДАНИЕ ВЫПОЛНЕНО",
		ZIndex = 33,
	})
	label(panel, {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 24),
		FontFace = PIXEL,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = H.wh,
		Text = tostring(data.completed or ""),
		ZIndex = 33,
	})
	local rowX = math.floor((width - rowW) / 2)
	for index, card in ipairs(cards) do
		local x = rowX + (index - 1) * 128
		local icon = PixelUi.icon(panel, card.icon, UDim2.fromOffset(x, 72), 32)
		if card.gold then
			-- золотой сундук и прочие «премиальные» карточки — золотая кайма
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(255, 204, 84)
			stroke.Thickness = 2
			stroke.Parent = icon
		end
		label(panel, {
			Position = UDim2.fromOffset(x + 38, 74),
			Size = UDim2.fromOffset(84, 28),
			FontFace = PIXEL,
			TextSize = 16,
			TextColor3 = card.gold and Color3.fromRGB(255, 204, 84) or H.wh,
			Text = tostring(card.text or ""),
			ZIndex = 33,
		})
	end
	local scale = make("UIScale", { Scale = 0.6 }, panel)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(panel, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
	sfx("hubQuest")
	task.delay(0.3, function()
		if token == questRewardToken then
			pcall(function() UiSound.play("medal") end)
		end
	end)
	task.delay(4.6, function()
		if token ~= questRewardToken or not panel.Parent then
			return
		end
		TweenService:Create(panel, TweenInfo.new(0.5), { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.2, 0) }):Play()
		task.delay(0.55, function()
			if token == questRewardToken and questRewardGui == panel then
				panel:Destroy()
				questRewardGui = nil
			end
		end)
	end)
end

local function onQuestUpdate(snapshot, completed)
	if type(snapshot) == "table" then
		state.quests = snapshot
		refreshTracker()
	end
	if type(completed) == "table" then
		showQuestReward(completed)
	end
end

----------------------------------------------------------------------
-- Станции и жители
----------------------------------------------------------------------

function HubController.openStation(id)
	if state.panelOpen or state.busy or state.sceneOpen or typeof(id) ~= "string" then
		return
	end
	-- Станции UI v2 открываются окном-сценой (StationController).
	local station = Hub.Stations[id]
	if station and station.window then
		ui.hint.Visible = false
		Bus.emit("openStation", { name = station.window })
		return
	end
	state.busy = true
	local ok, payload = pcall(function()
		return remotes.RequestStation:InvokeServer(id)
	end)
	state.busy = false
	if not ok or type(payload) ~= "table" or not payload.ok then
		if ok and type(payload) == "table" and payload.err then
			toast(payload.err)
		end
		return
	end
	if payload.kind == "talk" then
		-- окно разговора (DialogueWindow): камера на жителя, ответы героя;
		-- Hub.TalkWindow = false — старая строка внизу экрана
		if Hub.TalkWindow ~= false then
			ui.hint.Visible = false
			Bus.emit("openStation", { name = "Talk", villager = payload.id or string.match(id, "^villager:(.+)$"), talk = payload })
		else
			sfx("hubTalk")
			showTalk(payload.name, payload.line)
		end
		return
	end
	sfx("ui")
	if payload.kind == "portal" then
		showPortal(payload)
	elseif payload.kind == "quests" then
		state.quests = payload.quests
		refreshTracker()
		showBoard(payload.quests)
	else
		showDialog(payload)
	end
end

local function updateNearest()
	local root = rootPart()
	if not state.inHub or not root or player:GetAttribute("ZoneBusy") or state.sceneOpen then
		state.nearest = nil
		ui.hint.Visible = false
		return
	end

	if state.panelOpen then
		-- Отошёл от станции: закрываем панель.
		local anchor = state.openAnchor
		if anchor and anchor.Parent and horizontal(root.Position, anchor.Position) > Hub.InteractDistance + 4 then
			closePanels()
		end
		return
	end

	-- Станция рядом с жителем (жаровня и Добрыня, доска и Феофан) важнее:
	-- к жителю сначала подходят вплотную.
	local best, bestScore = nil, math.huge
	for _, anchor in ipairs(CollectionService:GetTagged("HubStation")) do
		if anchor:IsA("BasePart") and anchor:IsDescendantOf(Workspace) then
			local distance = horizontal(root.Position, anchor.Position)
			local villager = string.sub(anchor:GetAttribute("StationId") or "", 1, 9) == "villager:"
			local score = distance + (villager and Hub.VillagerPenalty or 0)
			if distance <= Hub.InteractDistance and score < bestScore and math.abs(root.Position.Y - anchor.Position.Y) < 14 then
				best, bestScore = anchor, score
			end
		end
	end
	state.nearest = best
	state.openAnchor = best or state.openAnchor
	if best then
		local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local key = Binds.isKeyCode("Interact") and Binds.get("Interact").Name or "E"
		local verb = best:GetAttribute("Verb") or "Взаимодействовать"
		ui.hint.Text = touchOnly and verb or ("[" .. key .. "] " .. verb)
		ui.hint.Visible = true
	else
		ui.hint.Visible = false
	end
end

----------------------------------------------------------------------
-- Свет: долина, пещера и возврат света этажа
----------------------------------------------------------------------

local LIGHT_KEYS = {
	"ClockTime",
	"Brightness",
	"Ambient",
	"OutdoorAmbient",
	"ExposureCompensation",
	"ColorShift_Top",
	"ColorShift_Bottom",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"GeographicLatitude",
}

local EFFECTS = {
	atmosphere = { class = "Atmosphere", keys = { "Density", "Haze", "Offset", "Color", "Decay", "Glare" } },
	bloom = { class = "BloomEffect", keys = { "Intensity", "Threshold", "Size" } },
	sunRays = { class = "SunRaysEffect", keys = { "Intensity", "Spread" } },
	grade = { class = "ColorCorrectionEffect", keys = { "Brightness", "Contrast", "Saturation", "TintColor" } },
	clouds = { class = "Clouds", terrain = true, keys = { "Cover", "Density", "Color" } },
}

local function effectParent(spec)
	return spec.terrain and Workspace:FindFirstChildOfClass("Terrain") or Lighting
end

local function snapshot(instance, keys)
	local data = {}
	for _, key in ipairs(keys) do
		data[key] = instance[key]
	end
	return data
end

-- Эффект нужного класса; если его нет — свой, локальный (удалим при выходе).
local function effect(kind: string)
	local spec = EFFECTS[kind]
	local parent = effectParent(spec)
	if not parent then
		return nil
	end
	local existing = parent:FindFirstChildOfClass(spec.class)
	if existing then
		return existing
	end
	local created = Instance.new(spec.class)
	created.Name = "Hub" .. spec.class
	created.Parent = parent
	if state.saved then
		state.saved.created[created] = true
	end
	return created
end

local function saveLighting()
	if state.saved then
		return
	end
	local saved = { lighting = snapshot(Lighting, LIGHT_KEYS), effects = {}, created = {} }
	for kind, spec in pairs(EFFECTS) do
		local parent = effectParent(spec)
		local instance = parent and parent:FindFirstChildOfClass(spec.class)
		if instance then
			saved.effects[kind] = { instance = instance, values = snapshot(instance, spec.keys) }
		end
	end
	state.saved = saved
end

local function applyProfile(profile, instant: boolean?)
	local info = TweenInfo.new(instant and 0 or HubLayout.Lighting.tweenTime, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, profile.lighting):Play()
	for kind in pairs(EFFECTS) do
		local goal = profile[kind]
		local instance = goal and effect(kind)
		if instance then
			if instance:IsA("Clouds") then
				instance.Enabled = true
			end
			TweenService:Create(instance, info, goal):Play()
		end
	end
end

local function restoreLighting()
	local saved = state.saved
	if not saved then
		return
	end
	state.saved = nil
	local info = TweenInfo.new(HubLayout.Lighting.tweenTime, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, saved.lighting):Play()
	for _, entry in pairs(saved.effects) do
		if entry.instance.Parent then
			TweenService:Create(entry.instance, info, entry.values):Play()
		end
	end
	for instance in pairs(saved.created) do
		instance:Destroy()
	end
end

----------------------------------------------------------------------
-- Живая долина
----------------------------------------------------------------------

local world = {
	spinners = {}, -- { axis, speed, parts = { {part, offset} } }
	bobbers = {}, -- { part, base, phase, amp }
	planks = {}, -- { part, base, phase }
	films = {},
	seals = {}, -- [i] = { parts }
	zone = nil, -- { cframe, size } части CaveLightingZone
	pond = nil, -- { center, radius, y }
	dirty = true,
}
local baseCFrame = setmetatable({}, { __mode = "k" }) -- исходный CFrame детали (сервер её не двигает)

local function base(part: BasePart): CFrame
	local cf = baseCFrame[part]
	if not cf then
		cf = part.CFrame
		baseCFrame[part] = cf
	end
	return cf
end

-- Надпись на табличке с обеих сторон.
local function signGui(board: BasePart, text: string, face)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "HubSign"
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0.6
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.FontFace = PIXEL
	l.TextScaled = true
	l.TextColor3 = H.wd2:Lerp(Palette.UI.panel, 0.6)
	l.Text = text
	l.Parent = sg
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.Parent = l
	sg.Parent = board
end

local function setupSigns(hub)
	for _, s in ipairs(HubLayout.Signs) do
		local node = findPath(hub, s.path)
		if node and node:IsA("BasePart") and not node:FindFirstChild("HubSign") then
			signGui(node, s.text, Enum.NormalId.Front)
			signGui(node, s.text, Enum.NormalId.Back)
		end
	end
end

-- Дым из труб и брызги водопада (ТЗ, «добавить по желанию»).
local function addEmitter(attachment: Attachment, kind: string)
	if attachment:FindFirstChild("HubEmitter") then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "HubEmitter"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.LightInfluence = 0.6
	if kind == "smoke" then
		emitter.Color = ColorSequence.new(H.st1, H.sn2)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.7, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Size = NumberSequence.new(1.5, 6)
		emitter.Lifetime = NumberRange.new(4, 6)
		emitter.Rate = 2.5
		emitter.Speed = NumberRange.new(2, 3.5)
		emitter.SpreadAngle = Vector2.new(10, 10)
		emitter.Acceleration = Vector3.new(1.2, 0.4, 0.3) -- ветер
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.RotSpeed = NumberRange.new(-20, 20)
	else
		emitter.Color = ColorSequence.new(H.sn1)
		emitter.Transparency = NumberSequence.new(0.35, 1)
		emitter.Size = NumberSequence.new(2, 6)
		emitter.Lifetime = NumberRange.new(1, 1.8)
		emitter.Rate = 22
		emitter.Speed = NumberRange.new(5, 10)
		emitter.SpreadAngle = Vector2.new(70, 70)
		emitter.Acceleration = Vector3.new(0, -6, 0)
		emitter.EmissionDirection = Enum.NormalId.Top
	end
	emitter.Parent = attachment
end

local function refreshSeals()
	local unlocked = player:GetAttribute("FloorsUnlocked") or 1
	for index, parts in pairs(world.seals) do
		local open = index <= unlocked
		for _, part in ipairs(parts) do
			if part.Parent then
				part.Material = open and Enum.Material.Neon or Enum.Material.SmoothPlastic
				part.Color = open and H.mem or H.memd
			end
		end
	end
end

-- Полный пересбор списков живого декора (после прихода/ухода деталей).
local function rebuildWorld()
	world.dirty = false
	local hub = hubFolder()
	if not hub then
		return
	end
	setupSigns(hub)
	local groups = {} -- [model] = { kind, parts }
	world.bobbers, world.planks, world.films, world.seals = {}, {}, {}, {}
	local plankIndex = 0
	for _, d in ipairs(hub:GetDescendants()) do
		if d:IsA("BasePart") then
			local name = d.Name
			if name == "MillWing" or name == "MemorySwirl" then
				local model = d:FindFirstAncestorOfClass("Model")
				if model then
					local group = groups[model]
					if not group then
						group = { kind = name, parts = {} }
						groups[model] = group
					end
					table.insert(group.parts, d)
				end
			elseif name == "MemoryMote" or name == "AbyssSpark" or (name == "MemoryCrystal" and d.Size.Y < 0.6) then
				local cf = base(d)
				local seed = cf.Position.X * 0.37 + cf.Position.Z * 0.11
				table.insert(world.bobbers, { d, cf, seed % 6.28, 0.4 + (seed % 0.5) })
			elseif name == "BridgePlank" then
				plankIndex += 1
				table.insert(world.planks, { d, base(d), plankIndex * 0.55 })
			elseif name == "MemoryFilm" then
				table.insert(world.films, d)
			elseif name == "CaveLightingZone" then
				world.zone = { cframe = d.CFrame, size = d.Size }
			elseif name == "PondSurface" then
				local size = d.Size
				local radius = d.Shape == Enum.PartType.Cylinder and math.min(size.Y, size.Z) / 2 or math.max(size.X, size.Z) / 2
				world.pond = { center = d.Position, radius = radius, y = d.Position.Y + size.Y / 2 }
				if d.Shape == Enum.PartType.Cylinder then
					world.pond.y = d.Position.Y
				end
			else
				local seal = string.match(name, "^Seal(%d)Glyph$")
				if seal then
					local index = tonumber(seal)
					world.seals[index] = world.seals[index] or {}
					table.insert(world.seals[index], d)
				end
			end
		elseif d:IsA("PointLight") then
			local lantern = HubLayout.CaveLanterns
			if d.Color:ToHex():lower() == lantern.color and d:FindFirstAncestor("Cave") and d:FindFirstAncestorOfClass("Model").Name == "Cave" then
				d.Brightness = lantern.brightness
				d.Range = lantern.range
			end
		elseif d:IsA("Attachment") then
			if d.Name == "Smoke" then
				addEmitter(d, "smoke")
			elseif d.Name == "Spray" then
				addEmitter(d, "spray")
			end
		end
	end

	world.spinners = {}
	for model, group in pairs(groups) do
		local axis, speed = nil, 0
		local look = model:GetPivot().LookVector
		if group.kind == "MillWing" then
			local primary = model.PrimaryPart
			local att = primary and primary:FindFirstChild("WingAxis")
			if att then
				axis = CFrame.lookAt(att.WorldPosition, att.WorldPosition + look)
				speed = math.rad(10) -- 10°/с по ТЗ
			end
		else
			local sum = Vector3.zero
			for _, part in ipairs(group.parts) do
				sum += base(part).Position
			end
			local center = sum / #group.parts
			axis = CFrame.lookAt(center, center + look)
			speed = math.rad(-40)
		end
		if axis then
			local entry = { axis = axis, speed = speed, parts = {} }
			for _, part in ipairs(group.parts) do
				table.insert(entry.parts, { part, axis:ToObjectSpace(base(part)) })
			end
			table.insert(world.spinners, entry)
		end
	end
	refreshSeals()
end

local function markDirty()
	if world.dirty then
		return
	end
	world.dirty = true
	task.delay(0.4, function()
		if world.dirty then
			rebuildWorld()
		end
	end)
end

----------------------------------------------------------------------
-- Птицы над озером и бабочки
----------------------------------------------------------------------

local life = { birds = {}, butterflies = {}, folder = nil }

local function lifePart(parent, size: Vector3, color: Color3)
	return make("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Size = size,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}, parent)
end

local function buildLife()
	if life.folder then
		return
	end
	life.folder = make("Folder", { Name = "HubLife" }, Workspace)
	local rng = Random.new(7)
	-- 3 стайки по 5 «галочек» кругами над озером.
	local lake = HubLayout.world(HubLayout.Points.Lake)
	for flock = 1, 3 do
		local center = lake + Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30))
		local radius = rng:NextNumber(35, 65)
		local height = rng:NextNumber(40, 60)
		local speed = rng:NextNumber(0.12, 0.2) * (flock % 2 == 0 and -1 or 1)
		for bird = 1, 5 do
			table.insert(life.birds, {
				left = lifePart(life.folder, Vector3.new(1.4, 0.15, 0.45), H.st4),
				right = lifePart(life.folder, Vector3.new(1.4, 0.15, 0.45), H.st4),
				center = center,
				radius = radius + (bird - 3) * 2.2,
				height = height + rng:NextNumber(-2, 2),
				speed = speed,
				phase = flock * 2.1 + bird * 0.09,
				flap = rng:NextNumber(0, 6),
			})
		end
	end
	-- Бабочки в трёх местах: у Стены имён, у озера, у полей.
	local spots = {
		HubLayout.world(Vector3.new(170, 0, -38)),
		HubLayout.world(Vector3.new(-62, 0, 24)),
		HubLayout.world(Vector3.new(190, 0, 168)),
	}
	local colors = { H.fy, H.fp, H.wh }
	for spotIndex, spot in ipairs(spots) do
		for index = 1, 3 do
			local color = colors[(spotIndex + index) % #colors + 1]
			table.insert(life.butterflies, {
				left = lifePart(life.folder, Vector3.new(0.35, 0.05, 0.3), color),
				right = lifePart(life.folder, Vector3.new(0.35, 0.05, 0.3), color),
				spot = spot,
				phase = rng:NextNumber(0, 6.28),
				speed = rng:NextNumber(0.4, 0.7),
			})
		end
	end
end

local function setLifeVisible(visible: boolean)
	if life.folder then
		life.folder.Parent = visible and Workspace or nil
	end
end

local function stepLife(now: number)
	for _, b in ipairs(life.birds) do
		local angle = b.phase + now * b.speed
		local position = b.center + Vector3.new(math.cos(angle) * b.radius, b.height + math.sin(now * 0.5 + b.phase) * 1.5, math.sin(angle) * b.radius)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * math.sign(b.speed)
		local frame = CFrame.lookAt(position, position + tangent)
		local wing = math.sin(now * 7 + b.flap) * 0.5 + 0.35
		b.left.CFrame = frame * CFrame.Angles(0, 0, wing) * CFrame.new(-0.65, 0, 0)
		b.right.CFrame = frame * CFrame.Angles(0, 0, -wing) * CFrame.new(0.65, 0, 0)
	end
	for _, f in ipairs(life.butterflies) do
		local t = now * f.speed + f.phase
		local position = f.spot + Vector3.new(math.sin(t * 1.3) * 5, 1.6 + math.sin(t * 2.7) * 0.8, math.sin(t * 0.9) * 4)
		local ahead = f.spot + Vector3.new(math.sin((t + 0.1) * 1.3) * 5, 1.6, math.sin((t + 0.1) * 0.9) * 4)
		local frame = CFrame.lookAt(position, Vector3.new(ahead.X, position.Y, ahead.Z))
		local wing = math.abs(math.sin(now * 14 + f.phase)) * 1.2
		f.left.CFrame = frame * CFrame.Angles(0, 0, wing) * CFrame.new(-0.18, 0, 0)
		f.right.CFrame = frame * CFrame.Angles(0, 0, -wing) * CFrame.new(0.18, 0, 0)
	end
end

----------------------------------------------------------------------
-- Пещера: свет, первый выход, отражение у пруда
----------------------------------------------------------------------

local function insideZone(p: Vector3): boolean
	local zone = world.zone
	if not zone then
		return false
	end
	local l = zone.cframe:PointToObjectSpace(p)
	local h = zone.size / 2
	return math.abs(l.X) <= h.X and math.abs(l.Y) <= h.Y and math.abs(l.Z) <= h.Z
end

-- Первый выход: камера уходит над долину, держит вид и возвращается к игроку.
-- Ввод не блокируется (ТЗ, раздел 3; HubLayout.Reveal).
local function playReveal()
	state.vistaDone = true
	showBanner("valley")
	local controller = cameraController()
	local camera = Workspace.CurrentCamera
	local root = rootPart()
	if not controller or not controller.setOverride or not camera or not root then
		return
	end
	local config = HubLayout.Reveal
	local start = camera.CFrame
	local offset = start.Position - root.Position
	local rotation = start - start.Position
	local wide = CFrame.lookAt(HubLayout.world(config.To.eye), HubLayout.world(config.To.look))
	local total = config.Duration + config.Hold + config.Back
	local started = os.clock()
	controller.setOverride(function()
		local t = os.clock() - started
		local alpha
		if t < config.Duration then
			alpha = ease(t / config.Duration)
		elseif t < config.Duration + config.Hold then
			alpha = 1
		elseif t < total then
			alpha = 1 - ease((t - config.Duration - config.Hold) / config.Back)
		else
			controller.setOverride(nil)
			return nil
		end
		local r = rootPart()
		local follow = r and (CFrame.new(r.Position + offset) * rotation) or start
		return follow:Lerp(wide, alpha)
	end)
end

-- У пруда: силуэт старика с молотом в воде на 1 с, тихий звон, без текста.
local function playPondEcho(root: BasePart)
	local pond = world.pond
	local config = Hub.PondEcho
	local toPlayer = Vector3.new(root.Position.X - pond.center.X, 0, root.Position.Z - pond.center.Z)
	if toPlayer.Magnitude < 0.1 then
		return
	end
	local dir = toPlayer.Unit
	-- Вода светится и непрозрачна, поэтому отражение — плоская тень на её
	-- поверхности: ноги у кромки со стороны игрока, голова к центру пруда.
	local feet = Vector3.new(pond.center.X, pond.y + 0.12, pond.center.Z) + dir * math.max(pond.radius - 0.6, 0.5)
	local along = -dir -- «вверх» фигуры: от игрока вглубь пруда
	local frame = CFrame.fromMatrix(feet, along:Cross(Vector3.yAxis), along, Vector3.yAxis)
	local folder = make("Model", { Name = "PondEcho" }, fxFolder())
	local ink = H.cv3
	local flat = 0.06
	local parts = {
		{ Vector3.new(2, 2, flat), CFrame.new(0, 3, 0) }, -- корпус
		{ Vector3.new(1.4, 1.4, flat), CFrame.new(0, 4.7, 0) }, -- голова
		{ Vector3.new(1.2, 0.9, flat), CFrame.new(0, 3.9, 0) }, -- борода
		{ Vector3.new(0.8, 2, flat), CFrame.new(-0.6, 1, 0) }, -- ноги
		{ Vector3.new(0.8, 2, flat), CFrame.new(0.6, 1, 0) },
		{ Vector3.new(0.8, 2, flat), CFrame.new(-1.4, 3, 0) }, -- руки
		{ Vector3.new(0.8, 2, flat), CFrame.new(1.6, 3.6, 0) * CFrame.Angles(0, 0, math.rad(-35)) },
		{ Vector3.new(0.3, 2.6, flat), CFrame.new(2.4, 4.8, 0) }, -- рукоять молота
		{ Vector3.new(1.6, 0.9, flat), CFrame.new(2.4, 6.1, 0) }, -- боёк
	}
	local made = {}
	for _, spec in ipairs(parts) do
		local part = lifePart(folder, spec[1], ink)
		part.CFrame = frame * spec[2]
		part.Transparency = 1
		table.insert(made, part)
	end
	sfx("hubChime")
	local half = config.duration / 2
	for _, part in ipairs(made) do
		TweenService:Create(part, TweenInfo.new(half * 0.6), { Transparency = 0.3 }):Play()
	end
	task.delay(half * 1.2, function()
		for _, part in ipairs(made) do
			TweenService:Create(part, TweenInfo.new(half * 0.8), { Transparency = 1 }):Play()
		end
		task.delay(half, function()
			folder:Destroy()
		end)
	end)
end

local function checkCave(root: BasePart)
	local now = insideZone(root.Position)
	if now ~= state.inCave then
		local first = state.inCave == nil
		local wasInCave = state.inCave == true
		state.inCave = now
		applyProfile(now and HubLayout.Lighting.Cave or HubLayout.Lighting.Valley, first)
		setLifeVisible(not now)
		if now then
			state.sawCave = true
		elseif wasInCave and state.sawCave and not state.vistaDone
			and horizontal(root.Position, HubLayout.world(HubLayout.Points.Ledge)) < 60 then
			playReveal()
		end
	end
	-- Отражение у пруда.
	local pond = world.pond
	if now and pond and os.clock() >= state.pondReadyAt then
		local edge = horizontal(root.Position, pond.center) - pond.radius
		if edge <= Hub.PondEcho.distance and math.abs(root.Position.Y - pond.y) < 6 then
			state.pondReadyAt = os.clock() + Hub.PondEcho.cooldown
			playPondEcho(root)
		end
	end
end

----------------------------------------------------------------------
-- Кадр живой долины
----------------------------------------------------------------------

local function step()
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero

	for _, s in ipairs(world.spinners) do
		if (s.axis.Position - eye).Magnitude < 400 then
			local rotation = s.axis * CFrame.Angles(0, 0, now * s.speed)
			for _, e in ipairs(s.parts) do
				if e[1].Parent then
					e[1].CFrame = rotation * e[2]
				end
			end
		end
	end
	for _, b in ipairs(world.bobbers) do
		local part = b[1]
		if part.Parent and (b[2].Position - eye).Magnitude < 160 then
			part.CFrame = b[2] * CFrame.new(0, math.sin(now * 1.3 + b[3]) * b[4], 0) * CFrame.Angles(0, now * 0.6 + b[3], 0)
		end
	end
	for _, p in ipairs(world.planks) do
		if p[1].Parent and (p[2].Position - eye).Magnitude < 120 then
			p[1].CFrame = p[2] * CFrame.new(0, math.sin(now * 1.6 + p[3]) * 0.15, 0)
		end
	end
	for _, film in ipairs(world.films) do
		if film.Parent then
			film.Transparency = 0.45 + 0.1 * math.sin(now * 2)
		end
	end
	if not state.inCave then
		stepLife(now)
	end
end

-- Колокол Звонницы: раз в Hub.BellInterval по общим часам (у всех разом).
local function checkBell()
	local slot = math.floor(os.time() / Hub.BellInterval)
	if state.lastBell == nil then
		state.lastBell = slot
		return
	end
	if slot ~= state.lastBell then
		state.lastBell = slot
		sfx("hubBell", HubLayout.world(HubLayout.Points.Bell))
	end
end

local function startAmbient()
	if state.ambient then
		return
	end
	buildLife()
	state.ambient = RunService.RenderStepped:Connect(step)
end

local function stopAmbient()
	if state.ambient then
		state.ambient:Disconnect()
		state.ambient = nil
	end
	setLifeVisible(false)
end

----------------------------------------------------------------------
-- Зона и переходы
----------------------------------------------------------------------

-- Пока играет вступительный ролик (FilmPlaying), свет и экран принадлежат
-- катсцене: смена зоны (телепорт новичка на двор обучения) и снятие ZoneBusy
-- откладываются до конца фильма — иначе restoreLighting забивает полуночную
-- сцену дневным светом, а cover перебивает чёрный кадр катсцены.
local function filmPlaying(): boolean
	return player:GetAttribute("FilmPlaying") == true
end

local onZoneChanged, onBusyChanged, syncZone

local function onZoneChangedInner()
	local zone = player:GetAttribute("Zone")
	local inHub = zone == "Hub"
	if inHub == state.inHub and ui.returnButton.Visible == (zone == "Floor") then
		return
	end
	state.inHub = inHub
	ui.returnButton.Visible = zone == "Floor"
	ui.journeyButton.Visible = inHub
	if inHub then
		saveLighting()
		state.inCave = nil -- свет выберет первый же опрос зоны
		startAmbient()
		refreshSeals()
	else
		closePanels()
		restoreLighting()
		stopAmbient()
		ui.hint.Visible = false
		ui.talk.Visible = false
	end
	refreshTracker()
end

function onBusyChanged()
	if filmPlaying() then
		state.pendingZoneSync = true
		return
	end
	if player:GetAttribute("ZoneBusy") then
		closePanels()
		setCover(true, 0.3)
		return
	end
	-- Переход завершён: проявляем мир.
	local pending = state.pendingAwaken
	state.pendingAwaken = nil
	setCover(false, Hub.Awaken.coverFade)
	if pending then
		playAwaken(pending.cframe, player.UserId)
		showBanner(pending.banner)
	end
end

function onZoneChanged()
	if filmPlaying() then
		state.pendingZoneSync = true
		return
	end
	onZoneChangedInner()
end

-- Отложенная синхронизация после конца фильма: зона и экран выставляются
-- так, как если бы событий не было — по текущим атрибутам.
function syncZone()
	state.pendingZoneSync = nil
	onZoneChangedInner()
	if player:GetAttribute("ZoneBusy") then
		setCover(true, 0)
	else
		onBusyChanged()
	end
end

function HubController.start()
	local net = ReplicatedStorage:WaitForChild(Hub.NetFolder, 20)
	if not net then
		warn("[HubController] нет " .. Hub.NetFolder .. ": хаб на сервере не запущен")
		return
	end
	for _, name in ipairs({ "HubAwaken", "RequestStation", "RequestEnterFloor", "RequestReturnHub", "RequestJourneyStart", "QuestUpdate", "RequestQuest" }) do
		remotes[name] = net:WaitForChild(name, 20)
	end

	buildUi()
	ui.cover.BackgroundTransparency = 0 -- до первого кадра хаба экран закрыт
	-- Стартовый снимок lockPlayer'а ролика мог не застать KlinokHub (он создан
	-- здесь): если фильм уже идёт, cover не включаем — сцена катсцены должна
	-- быть видна под её собственным чёрным кадром.
	if filmPlaying() then
		ui.cover.Visible = false
		ui.cover.BackgroundTransparency = 1
	end

	-- Перехватчик клавиши взаимодействия: выше обычного приоритета, чем у ChestController.
	local interact = Binds.get("Interact")
	if interact then
		ContextActionService:BindActionAtPriority("KlinokHubInteract", function(_, inputState)
			if inputState ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end
			if state.inHub and state.nearest and not state.panelOpen and not state.busy and not state.sceneOpen then
				task.spawn(HubController.openStation, state.nearest:GetAttribute("StationId"))
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.ContextActionPriority.High.Value, interact)
	end

	remotes.HubAwaken.OnClientEvent:Connect(function(cframe, userId, banner)
		if userId == player.UserId then
			if player:GetAttribute("ZoneBusy") then
				state.pendingAwaken = { cframe = cframe, banner = banner }
			else
				playAwaken(cframe, userId)
				showBanner(banner)
			end
		else
			playAwaken(cframe, userId)
		end
	end)
	remotes.QuestUpdate.OnClientEvent:Connect(onQuestUpdate)

	-- Окно-сцена (StationController) прячет HUD: прячем и подсказку станции.
	Bus.on("hud", function(data)
		state.sceneOpen = data.visible == false
		if state.sceneOpen then
			ui.hint.Visible = false
			ui.talk.Visible = false
			ui.journeyButton.Visible = false
		elseif not state.panelOpen then
			ui.journeyButton.Visible = state.inHub
		end
	end)
	Bus.on("gateEntered", playDissolve)

	-- Долина стримится: следим за приходом и уходом деталей.
	task.spawn(function()
		local hub = Workspace:WaitForChild(Hub.FolderName, 30)
		if not hub then
			warn("[HubController] нет Workspace." .. Hub.FolderName)
			return
		end
		hub.DescendantAdded:Connect(markDirty)
		hub.DescendantRemoving:Connect(markDirty)
		rebuildWorld()
	end)

	player:GetAttributeChangedSignal("Zone"):Connect(onZoneChanged)
	player:GetAttributeChangedSignal("ZoneBusy"):Connect(onBusyChanged)
	player:GetAttributeChangedSignal("FloorsUnlocked"):Connect(refreshSeals)
	-- Конец фильма: применяем то, что накопилось за ролик (зона «Tutorial»,
	-- снятый ZoneBusy) — экран открывается уже после чёрного кадра катсцены.
	player:GetAttributeChangedSignal("FilmPlaying"):Connect(function()
		if player:GetAttribute("FilmPlaying") ~= true and state.pendingZoneSync then
			syncZone()
		end
	end)

	local accumulator, slow = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		slow += dt
		if accumulator >= 0.1 then
			accumulator = 0
			updateNearest()
		end
		if slow >= 0.25 then
			slow = 0
			local root = rootPart()
			if state.inHub and root and not player:GetAttribute("ZoneBusy") then
				checkCave(root)
				checkBell()
			end
		end
	end)

	if filmPlaying() then
		state.pendingZoneSync = true -- хаб настроится после титров
	else
		syncZone()
	end
	-- Страховка: если сервер так и не открыл экран, не оставляем игрока в чёрном.
	task.delay(12, function()
		if state.coverOn and not player:GetAttribute("ZoneBusy") and not filmPlaying() then
			setCover(false, 0.5)
		end
	end)

	print("[HubController] хаб «" .. Hub.Name .. "» на клиенте")
end

return HubController
