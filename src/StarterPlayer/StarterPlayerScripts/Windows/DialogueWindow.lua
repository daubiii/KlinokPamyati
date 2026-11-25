--!nonstrict
-- DialogueWindow — разговор с жителем долины (окно-сцена «Talk»).
-- Камера наезжает «из-за плеча» героя на лицо жителя, сверху и снизу —
-- кинорамка, внизу лист бумаги: портрет (живая копия жителя во ViewportFrame),
-- лента с именем, титул, реплика печатается с «голосом» (слоги по высоте
-- голоса жителя), справа над листом — ответы героя (темы из HubDialogue).
--
-- Управление: E / Пробел / Enter / клик — допечатать или дальше; 1–5 — ответ;
-- Backspace / крестик — уйти. На телефоне — тап по листу и по ответам.
--
-- Открывает HubController (RequestStation → kind = "talk") через
-- StationController.open("Talk", { villager = id, talk = payload }).
-- Сервер уже повернул жителя к герою, засчитал разговор (квест «Голоса
-- долины») и выбрал первую реплику; темы и прощание — с клиента, из конфига.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HubDialogue = require(Shared.Config.HubDialogue)
local HubVillagers = require(Shared.Config.HubVillagers)
local Binds = require(Shared.Config.Binds)

local Lib = script.Parent.Parent.Lib
local PixelUi = require(Lib.PixelUi)
local PaperUi = require(Lib.PaperUi)
local UiMotion = require(Lib.UiMotion)
local UiSound = require(Lib.UiSound)
local WindowBase = require(Lib.WindowBase)

local DialogueWindow = {}

local P = PaperUi.colors
local player = Players.LocalPlayer

local win, ctx
local refs: any = {}
local state: any = {}
-- Какие темы герой уже спрашивал (на сессию): [villagerId][topicId] = true.
local visited = {}

local STATION_NAMES = {
	Board = "доска заданий", Shop = "лавка", Forge = "наковальня", Gate = "Врата",
	Wall = "Стена имён", DailyChest = "сундук дня",
}
local FALLBACK_PORTRAITS = { "npc1", "npc2", "npc3", "npc4", "npc5" }

-- Геометрия (дизайн-пиксели холста 1600×900).
local PANEL = { x = 230, y = 640, w = 1140, h = 210 }
local TEXT = { x = 404, y = 704, w = 850, h = 128 }
local CHOICE = { x = 1000, w = 392, h = 50, gap = 8 }

local function villagerConfig(id: string)
	for _, v in ipairs(HubVillagers) do
		if v.id == id then
			return v
		end
	end
	return nil
end

local function villagerModel(id: string)
	local folder = Workspace:FindFirstChild("HubVillagers")
	return folder and folder:FindFirstChild(id)
end

-- «*эмоция* текст» → RichText + флаги «без голоса» для каждого видимого символа.
local function markup(text: string)
	local rich, silent = {}, {}
	local pos = 1
	local emotionColor = P.ink2:ToHex()
	while pos <= #text do
		local a, b, inner = text:find("%*(.-)%*", pos)
		local chunk = a and text:sub(pos, a - 1) or text:sub(pos)
		table.insert(rich, chunk)
		for _ in utf8.codes(chunk) do
			table.insert(silent, false)
		end
		if not a then
			break
		end
		local shown = "(" .. inner .. ")"
		table.insert(rich, ('<i><font color="#%s">%s</font></i>'):format(emotionColor, shown))
		for _ in utf8.codes(shown) do
			table.insert(silent, true)
		end
		pos = b + 1
	end
	return table.concat(rich), silent
end

-- ===== портрет =====

local function buildPortrait(parent, model, villagerId: string)
	local frame = PaperUi.image(parent, "square", {
		Name = "Portrait",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(PANEL.x + 66, PANEL.y + 20),
		Size = UDim2.fromOffset(196, 196),
		Rotation = -3,
		ZIndex = 12,
	}, { scale = 4 })
	PaperUi.image(frame, "pin", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(96, 48),
		ZIndex = 16,
	}, { noSlice = true })
	refs.portrait = frame

	local clone
	if model then
		local ok, result = pcall(function()
			local archivable = model.Archivable
			model.Archivable = true
			local c = model:Clone()
			model.Archivable = archivable
			return c
		end)
		clone = ok and result or nil
	end
	local head = clone and clone:FindFirstChild("Head")
	if not head then
		if clone then
			clone:Destroy()
		end
		-- запасной портрет из атласа
		local index = 1
		for i = 1, #villagerId do
			index = (index + string.byte(villagerId, i)) % #FALLBACK_PORTRAITS
		end
		PaperUi.image(frame, FALLBACK_PORTRAITS[index + 1], {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromOffset(144, 144),
			ZIndex = 14,
		}, { noSlice = true })
		return
	end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("BillboardGui") or d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Face"
	vp.BackgroundColor3 = Color3.fromRGB(214, 196, 160)
	vp.BorderSizePixel = 0
	vp.Position = UDim2.fromOffset(14, 14)
	vp.Size = UDim2.new(1, -28, 1, -28)
	vp.Ambient = Color3.fromRGB(170, 160, 150)
	vp.LightColor = Color3.fromRGB(255, 236, 205)
	vp.LightDirection = Vector3.new(-0.6, -0.8, -0.9)
	vp.ZIndex = 13
	vp.Parent = frame
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 186, 160))
	gradient.Parent = vp
	clone.Parent = vp
	local camera = Instance.new("Camera")
	camera.FieldOfView = 24
	camera.Parent = vp
	vp.CurrentCamera = camera
	local headCf = head.CFrame
	local center = headCf.Position - Vector3.new(0, 0.25, 0)
	local started = os.clock()
	refs.portraitConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		-- лёгкое «дыхание» и поворот головы, когда житель говорит
		local talk = state.typing and math.sin(t * 14) * 0.03 or 0
		local yaw = math.sin(t * 0.7) * 0.08
		local eye = center + (headCf * CFrame.Angles(0, yaw, 0)).LookVector * 5.4 + Vector3.new(0, 0.35 + math.sin(t * 1.6) * 0.04 + talk, 0)
		camera.CFrame = CFrame.lookAt(eye, center + Vector3.new(0, talk * 0.5, 0))
	end)
	win:onCleanup(function()
		if refs.portraitConn then
			refs.portraitConn:Disconnect()
			refs.portraitConn = nil
		end
	end)
end

-- Облачко и табличка над головой жителя мешают кадру — прячем у себя.
local function hideOverhead(model)
	local head = model and model:FindFirstChild("Head")
	if not head then
		return
	end
	local hidden = {}
	local function hide(child)
		if child:IsA("BillboardGui") and child.Enabled then
			child.Enabled = false
			table.insert(hidden, child)
		end
	end
	for _, child in ipairs(head:GetChildren()) do
		hide(child)
	end
	local conn = head.ChildAdded:Connect(hide)
	win:onCleanup(function()
		conn:Disconnect()
		for _, gui in ipairs(hidden) do
			if gui.Parent and gui.Name ~= "Bubble" then
				gui.Enabled = true
			end
		end
	end)
end

-- ===== текст =====

local function clearChoices()
	for _, strip in ipairs(refs.choices or {}) do
		local holder = strip.holder
		PixelUi.tween(holder, 0.12, { Position = holder.Position + UDim2.fromOffset(40, 0) })
		UiMotion.fadeOut(holder, 0.12)
		task.delay(0.13, function()
			holder:Destroy()
		end)
	end
	refs.choices = {}
end

local showChoices -- forward

local function setDots(index: number, total: number)
	local holder = refs.dots
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if total <= 1 then
		return
	end
	for i = 1, total do
		PaperUi.image(holder, i == index and "dot" or "dotRing", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((i - 1) * 24 + 8, 8),
			Size = UDim2.fromOffset(16, 16),
			ImageColor3 = i == index and P.green or Color3.new(1, 1, 1),
			ZIndex = 14,
		}, { noSlice = true })
	end
end

local function setWaiting(on: boolean)
	refs.next.Visible = on
	refs.hint.Visible = on
	if on then
		UiMotion.popIn(refs.next, 0, 0.5)
	end
end

-- Напечатать страницу. onDone — когда игрок «пролистнул» её (после допечатки).
-- auto = true — сразу после допечатки идти дальше (без «дальше»).
local function typePage(text: string, question: string?, onAdvance, auto: boolean?)
	if state.job then
		state.job.cancel()
	end
	setWaiting(false)
	refs.question.Text = question and ("— " .. question) or ""
	refs.question.Visible = question ~= nil
	refs.body.Position = UDim2.fromOffset(TEXT.x, question and TEXT.y + 26 or TEXT.y)
	local rich, silent = markup(text)
	local voice = state.voice
	state.typing = true
	state.onAdvance = onAdvance
	state.job = UiMotion.typewriter(refs.body, rich, {
		speed = voice.speed or 44,
		onChar = function(ch, index)
			if silent[index] or ch == " " then
				return
			end
			if index % 2 == 1 then
				UiSound.blip(voice)
			end
			if index % 6 == 1 and refs.portrait then
				UiMotion.punch(refs.portrait, 0.015, 0.12)
			end
		end,
		onDone = function()
			state.typing = false
			if auto and state.onAdvance then
				local fn = state.onAdvance
				state.onAdvance = nil
				task.delay(0.25, function()
					if win and not state.closing then
						fn()
					end
				end)
			elseif state.onAdvance then
				setWaiting(true)
			end
		end,
	})
end

-- Последовательность страниц, затем then_(). autoLast — после последней
-- страницы не ждать клика (ответы появляются сами).
local function playPages(pages, question: string?, then_, autoLast: boolean?)
	local index = 0
	local function nextPage()
		index += 1
		if index > #pages then
			setDots(0, 0)
			if then_ then
				then_()
			end
			return
		end
		setDots(index, #pages)
		typePage(pages[index], index == 1 and question or nil, nextPage, autoLast and index == #pages)
	end
	nextPage()
end

-- Клик / E / Пробел.
local function advance()
	if not win or state.closing then
		return
	end
	if state.job and not state.job.done then
		state.job.skip()
		return
	end
	local fn = state.onAdvance
	if fn then
		state.onAdvance = nil
		setWaiting(false)
		UiSound.play("dialog_next")
		fn()
	end
end

-- ===== ответы =====

local function closeDialog()
	if ctx and not state.closing then
		ctx.close()
	end
end

local function pick(choice)
	if state.closing or state.picking then
		return
	end
	state.picking = true
	UiSound.play("choice_pick")
	clearChoices()
	task.delay(0.12, function()
		state.picking = false
		choice.run()
	end)
end

showChoices = function()
	clearChoices()
	state.onAdvance = nil
	local list = {}
	local cfg = state.cfg
	local seen = visited[state.id] or {}
	for _, topic in ipairs(cfg.topics or {}) do
		table.insert(list, {
			text = topic.text,
			fresh = not seen[topic.id],
			right = topic.station and STATION_NAMES[topic.station] or nil,
			run = function()
				seen[topic.id] = true
				visited[state.id] = seen
				playPages(topic.pages or { "…" }, topic.text, function()
					if topic.station and ctx and ctx.openStation then
						state.closing = true
						ctx.openStation(topic.station)
					else
						showChoices()
					end
				end, not topic.station)
			end,
		})
	end
	if cfg.lines and #cfg.lines > 1 then
		table.insert(list, {
			text = "Что нового?",
			run = function()
				local options = {}
				for _, line in ipairs(cfg.lines) do
					if line ~= state.lastLine then
						table.insert(options, line)
					end
				end
				local line = options[math.random(1, math.max(1, #options))] or cfg.lines[1]
				state.lastLine = line
				playPages({ line }, "Что нового?", showChoices, true)
			end,
		})
	end
	table.insert(list, {
		text = "Пока.",
		bye = true,
		run = function()
			typePage(cfg.bye or "Бывай.", "Пока.", closeDialog)
			-- прощание дочитано — окно закрывается само через пару секунд
			local my = win
			task.spawn(function()
				while win == my and state.typing do
					task.wait(0.1)
				end
				task.wait(1.8)
				if win == my and state.onAdvance == closeDialog then
					closeDialog()
				end
			end)
		end,
	})
	state.choiceList = list
	refs.choices = {}
	local anyFresh = false
	local count = #list
	for i, choice in ipairs(list) do
		local y = PANEL.y - 14 - (count - i + 1) * (CHOICE.h + CHOICE.gap)
		local strip = PaperUi.strip(refs.layer, UDim2.fromOffset(CHOICE.x, y), UDim2.fromOffset(CHOICE.w, CHOICE.h), {
			text = choice.text,
			knobText = tostring(i),
			right = choice.right,
			textSize = 20,
			z = 20,
			kind = choice.bye and "stripSoft" or nil,
			onClick = function()
				pick(choice)
			end,
		})
		if choice.fresh then
			anyFresh = true
			-- новая тема: красная точка у шарика
			PaperUi.image(strip.holder, "dot", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(26, 10),
				Size = UDim2.fromOffset(14, 14),
				ImageColor3 = Color3.fromRGB(220, 70, 60),
				ZIndex = 27,
			}, { noSlice = true })
		elseif not choice.bye and choice.fresh == false then
			strip.label.TextColor3 = P.ink2
		end
		strip.hit.MouseEnter:Connect(function()
			UiSound.play("choice_hover")
		end)
		table.insert(refs.choices, strip)
	end
	local holders = {}
	for _, strip in ipairs(refs.choices) do
		table.insert(holders, strip.holder)
	end
	UiMotion.cascade(holders, Vector2.new(60, 0), 0.045, 0, 0.26)
	if anyFresh then
		task.delay(0.15, function()
			UiSound.play("new_topic")
		end)
	end
end

-- ===== камера =====

-- Кадр «из-за плеча»: герой слева внизу, лицо жителя правее центра.
function DialogueWindow.cameraTarget(villagerId: string)
	local model = villagerModel(villagerId)
	local head = model and model:FindFirstChild("Head")
	local character = player.Character
	local me = character and character:FindFirstChild("HumanoidRootPart")
	if not head or not me then
		return nil, model
	end
	local eye = me.Position + Vector3.new(0, 1.6, 0)
	local flat = Vector3.new(head.Position.X - eye.X, 0, head.Position.Z - eye.Z)
	if flat.Magnitude < 0.5 then
		flat = -head.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	local forward = flat.Unit
	local right = forward:Cross(Vector3.yAxis)
	local camPos = eye - forward * 3.4 + right * 2.1 + Vector3.new(0, 0.45, 0)
	-- точка взгляда чуть ниже и левее головы: лицо выше центра (низ кадра —
	-- лист реплики), справа остаётся место под ответы
	local look = head.Position - right * 0.35 - Vector3.new(0, 0.7, 0)
	return CFrame.lookAt(camPos, look), model
end

-- ===== открыть / закрыть =====

function DialogueWindow.open(context)
	ctx = context
	refs = {}
	state = {}
	local data = context.data or {}
	local talk = data.talk or {}
	local id = data.villager or talk.id
	local cfg = (id and HubDialogue[id]) or {}
	local v = id and villagerConfig(id)
	state.id = id or "?"
	state.cfg = cfg
	state.voice = cfg.voice or { pitch = 1, speed = 44 }
	state.lastLine = talk.line

	win = WindowBase.new("KlinokDialogue", { onClose = context.close, wallet = false, order = 38 })
	win.vignette.BackgroundTransparency = 0.82
	win.closeButton.Visible = false
	local root, canvas = win.root, win.canvas

	-- Кинорамка убрана: при разговоре с жителями чёрные полосы мешали.
	refs.barTop = nil
	refs.barBottom = nil

	-- тап по экрану = дальше
	local tap = Instance.new("TextButton")
	tap.Name = "Tap"
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 0 -- под холстом: ответы и крестик ловят клик первыми
	tap.Parent = root
	tap.Activated:Connect(advance)

	local layer = Instance.new("Frame")
	layer.Name = "Dialogue"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 5
	layer.Parent = canvas
	refs.layer = layer

	-- лист
	local sheet = PaperUi.sheet(layer, UDim2.fromOffset(PANEL.x, PANEL.y), UDim2.fromOffset(PANEL.w, PANEL.h), { kind = "sheet", z = 8, tilt = -0.8 })
	refs.sheet = sheet
	local sheetHit = PaperUi.hit(sheet, 11)
	sheetHit.Activated:Connect(advance)

	local model = id and villagerModel(id)
	buildPortrait(layer, model, state.id)
	hideOverhead(model)

	local name = talk.name or (v and v.name) or "Житель"
	local title = talk.title or (v and v.title) or ""
	local ribbonWidth = math.clamp(140 + (utf8.len(name) or #name) * 22, 300, 520)
	local ribbon = PaperUi.ribbon(layer, UDim2.fromOffset(PANEL.x + 172, PANEL.y - 36), ribbonWidth, name:upper(), { height = 66, textSize = 27, z = 14 })
	refs.ribbon = ribbon
	refs.title = PaperUi.italic(layer, title ~= "" and title or (v and v.kid and "Мальчишка из долины" or "Житель долины"), 19, P.ink2, {
		Position = UDim2.fromOffset(PANEL.x + 176, PANEL.y + 32), Size = UDim2.fromOffset(420, 24), ZIndex = 14,
	})
	refs.question = PaperUi.italic(layer, "", 19, P.green, {
		Position = UDim2.fromOffset(TEXT.x, TEXT.y - 4), Size = UDim2.fromOffset(TEXT.w, 26), ZIndex = 14,
		TextTruncate = Enum.TextTruncate.AtEnd, Visible = false,
	})
	refs.body = PaperUi.text(layer, "", 25, P.ink, {
		Position = UDim2.fromOffset(TEXT.x, TEXT.y), Size = UDim2.fromOffset(TEXT.w, TEXT.h),
		TextWrapped = true, RichText = true, TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.08, ZIndex = 14,
	})
	-- «дальше»: шеврон покачивается в углу листа
	refs.next = PaperUi.image(layer, "chevronD", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(PANEL.x + PANEL.w - 52, PANEL.y + PANEL.h - 40),
		Size = UDim2.fromOffset(32, 32), ZIndex = 15, Visible = false,
	}, { noSlice = true })
	UiMotion.bob(refs.next, 4, 0.8)
	local interact = Binds.get("Interact")
	refs.hint = PaperUi.text(layer, ((interact and interact.Name) or "E") .. " — дальше", 16, P.faint, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromOffset(PANEL.x + PANEL.w - 76, PANEL.y + PANEL.h - 40),
		Size = UDim2.fromOffset(200, 22), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 15, Visible = false,
	})
	refs.dots = Instance.new("Frame")
	refs.dots.BackgroundTransparency = 1
	refs.dots.Position = UDim2.fromOffset(TEXT.x, PANEL.y + PANEL.h - 48)
	refs.dots.Size = UDim2.fromOffset(200, 16)
	refs.dots.ZIndex = 14
	refs.dots.Parent = layer

	PaperUi.roundButton(canvas, UDim2.fromOffset(1508, 84), 56, "icClose", closeDialog, { z = 30 })

	-- появление: лист снизу, портрет и лента — с задержкой
	UiSound.play("dialog_open")
	local sheetHome = sheet.Position
	sheet.Position = sheetHome + UDim2.fromOffset(0, 260)
	PixelUi.tween(sheet, 0.42, { Position = sheetHome }, Enum.EasingStyle.Back)
	UiMotion.popIn(refs.portrait, 0.16, 0.3)
	UiMotion.cascade({ ribbon, refs.title }, Vector2.new(-40, 0), 0.06, 0.2, 0.3)

	if talk.first then
		task.delay(0.55, function()
			if win then
				PaperUi.stamp(layer, UDim2.fromOffset(PANEL.x + PANEL.w - 96, PANEL.y + 58), 76, "ЗНАКОМСТВО", P.red, 18)
				UiSound.play("stamp")
			end
		end)
	end

	-- клавиши
	local keys = { Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.ButtonA }
	for _, k in ipairs(Binds.all("Interact") or {}) do
		table.insert(keys, k)
	end
	ContextActionService:BindActionAtPriority("KlinokDialogueNext", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			advance()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 200, table.unpack(keys))
	local numbers = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }
	ContextActionService:BindActionAtPriority("KlinokDialogueChoice", function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end
		local index = table.find(numbers, input.KeyCode)
		local list = refs.choices and #refs.choices > 0 and state.choiceList
		if index and list and list[index] then
			UiMotion.punch(refs.choices[index].holder, 0.08)
			pick(list[index])
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 200, table.unpack(numbers))
	win:onCleanup(function()
		ContextActionService:UnbindAction("KlinokDialogueNext")
		ContextActionService:UnbindAction("KlinokDialogueChoice")
		if state.job then
			state.job.cancel()
		end
	end)

	-- первая реплика — та, что выбрал сервер
	task.delay(0.35, function()
		if win and not state.closing then
			playPages({ talk.line or (cfg.lines and cfg.lines[1]) or "…" }, nil, showChoices, true)
		end
	end)
	return win
end

function DialogueWindow.close()
	state.closing = true
	if win then
		local closing = win
		win = nil
		UiSound.play("dialog_close")
		if refs.sheet and refs.sheet.Parent then
			PixelUi.tween(refs.sheet, 0.2, { Position = refs.sheet.Position + UDim2.fromOffset(0, 240) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		for _, b in ipairs({ refs.barTop, refs.barBottom }) do
			if b and b.Parent then
				local top = b.Name == "BarTop"
				PixelUi.tween(b, 0.2, { Position = UDim2.new(0, 0, top and 0 or 1, top and -70 or 40) })
			end
		end
		UiMotion.fadeOut(closing.canvas, 0.16)
		closing:destroy()
	end
	refs = {}
end

return DialogueWindow
