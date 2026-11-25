--!nonstrict
-- TouchControls (клиент): боевые кнопки для телефона и планшета.
--
-- Раньше кнопки создавал ContextActionService: одинаковые серые круги с
-- позициями «на глаз» — «Удар» наезжал на штатную кнопку прыжка PlayerModule,
-- не было ни перезарядки, ни зарядов лечения, а быстрый предмет с телефона
-- нельзя было применить вовсе.
-- Теперь — свой кластер под правый большой палец, вокруг кнопки прыжка:
--   * крупная «УДАР» (удержание — серия ударов, как зажатая ЛКМ);
--   * ближнее кольцо: «РЫВОК», «ЛЕЧ» (со счётчиком зарядов), «ЩИТ»;
--   * внешняя дуга: способности 1–3 и быстрый предмет;
--   * перезарядка — затемнение и таймер, пустые слоты скрыты.
-- Раскладка считается от настоящей кнопки прыжка (TouchGui.JumpButton), а без
-- неё — по той же формуле, что у PlayerModule; пересчёт при смене экрана.
-- Мультитач: у каждой кнопки своё касание, отпускание ловится глобально
-- (палец может съехать с кнопки — удар всё равно отпустится).
-- Кластер виден, только когда последний ввод — касание (планшет с клавиатурой
-- или геймпадом прячет его), и скрыт, пока открыто окно или идёт сцена.
--
-- API для контроллеров (модуль запускается сам при первом bind):
--   TouchControls.bind(id, {
--     slot = "attack" | "dash" | "heal" | "parry" | "ability1".."ability3" | "item",
--     label = "УДАР",
--     handler = function(inputState) end, -- Begin / End / Cancel, как у CAS
--     cooldown = function() return left, total end, -- необязательно
--     count = function() return n end, -- необязательно: значок с числом
--     visible = function() return true end, -- необязательно
--   })
--   TouchControls.isTouch() — последний ввод был касанием (доводка прицела).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ClientState = require(ReplicatedStorage.Shared.Util.ClientState)
local Bus = require(script.Parent.Parent.Lib.Bus)

local TouchControls = {}

local player = Players.LocalPlayer
local PIXEL_FONT = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Regular)

local COLORS = {
	fill = Color3.fromRGB(24, 20, 28),
	pressed = Color3.fromRGB(86, 66, 50),
	stroke = Color3.fromRGB(236, 226, 204),
	text = Color3.fromRGB(246, 238, 220),
	shade = Color3.fromRGB(0, 0, 0),
	badge = Color3.fromRGB(190, 52, 52),
	badgeEmpty = Color3.fromRGB(70, 66, 72),
}

-- Слоты кластера: кольцо (0 — центр, 1 — ближнее, 2 — внешнее) и угол в
-- градусах от центра «УДАРА» (0 — вправо, 90 — вверх). Углы подобраны так,
-- чтобы кружки не касались друг друга и кнопки прыжка (проверено на 844×390,
-- 667×375 и 1024×768); левые 40% экрана остаются под стик движения.
local SLOTS = {
	attack = { ring = 0, angle = 0 },
	dash = { ring = 1, angle = 76 },
	heal = { ring = 1, angle = 133 },
	parry = { ring = 1, angle = 190 },
	ability1 = { ring = 2, angle = 80 },
	ability2 = { ring = 2, angle = 111 },
	ability3 = { ring = 2, angle = 143 },
	item = { ring = 2, angle = 175 },
}

local entries = {} -- [id] = { button, handler, input, ... }
local gui = nil
local root = nil
local started = false
local shown = false
local hudVisible = true
local touchMode = false

local function newCorner(parent: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = parent
	return corner
end

local function newText(parent: Instance, name: string, maxSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.84, 0.42)
	label.FontFace = PIXEL_FONT
	label.TextColor3 = COLORS.text
	label.TextScaled = true
	label.Text = ""
	label.ZIndex = 3
	label.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.MinTextSize = 5
	limit.Parent = label
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.new(0, 0, 0)
	outline.Thickness = 1
	outline.Transparency = 0.2
	outline.Parent = label
	return label
end

local function setPressed(entry, pressed: boolean)
	if not entry.button then
		return
	end
	entry.scale.Scale = pressed and 0.9 or 1
	entry.button.BackgroundColor3 = pressed and COLORS.pressed or COLORS.fill
	entry.stroke.Transparency = pressed and 0 or 0.3
end

local function fire(entry, inputState)
	if not entry.handler then
		return
	end
	local ok, err = pcall(entry.handler, inputState)
	if not ok then
		warn("[TouchControls] " .. tostring(entry.id) .. ": " .. tostring(err))
	end
end

local function release(entry, inputState)
	if not entry.input then
		return
	end
	entry.input = nil
	setPressed(entry, false)
	fire(entry, inputState or Enum.UserInputState.End)
end

local function buildButton(entry)
	local big = entry.slot == "attack"
	local button = Instance.new("ImageButton")
	button.Name = entry.id
	button.AutoButtonColor = false
	button.Image = ""
	button.BackgroundColor3 = COLORS.fill
	button.BackgroundTransparency = 0.3
	button.BorderSizePixel = 0
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Selectable = false
	button.ZIndex = 1
	newCorner(button)

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = entry.color or COLORS.stroke
	stroke.Thickness = big and 3 or 2
	stroke.Transparency = 0.3
	stroke.Parent = button

	local scale = Instance.new("UIScale")
	scale.Parent = button

	local shade = Instance.new("Frame")
	shade.Name = "Cooldown"
	shade.BackgroundColor3 = COLORS.shade
	shade.BackgroundTransparency = 0.4
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.Visible = false
	shade.ZIndex = 2
	shade.Parent = button
	newCorner(shade)

	local label = newText(button, "Label", big and 14 or 10)
	label.Text = entry.label

	local timer = newText(button, "Timer", big and 16 or 12)
	timer.Size = UDim2.fromScale(0.7, 0.4)
	timer.ZIndex = 4
	timer.Visible = false

	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.86, 0.14)
	badge.Size = UDim2.fromScale(0.44, 0.44)
	badge.BackgroundColor3 = COLORS.badge
	badge.BorderSizePixel = 0
	badge.FontFace = PIXEL_FONT
	badge.TextColor3 = COLORS.text
	badge.TextScaled = true
	badge.Text = ""
	badge.Visible = false
	badge.ZIndex = 5
	badge.Parent = button
	newCorner(badge)
	local badgeLimit = Instance.new("UITextSizeConstraint")
	badgeLimit.MaxTextSize = 10
	badgeLimit.Parent = badge
	local badgePad = Instance.new("UIPadding")
	badgePad.PaddingTop = UDim.new(0.2, 0)
	badgePad.PaddingBottom = UDim.new(0.2, 0)
	badgePad.Parent = badge

	entry.button = button
	entry.stroke = stroke
	entry.scale = scale
	entry.shade = shade
	entry.labelUi = label
	entry.timer = timer
	entry.badge = badge

	button.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if input.UserInputState ~= Enum.UserInputState.Begin or entry.input then
			return
		end
		entry.input = input
		setPressed(entry, true)
		fire(entry, Enum.UserInputState.Begin)
	end)

	button.Parent = root
end

local function jumpButton()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if jump and jump:IsA("GuiObject") and jump.AbsoluteSize.X > 4 then
		return jump
	end
	return nil
end

local function layout()
	if not root then
		return
	end
	local screen = root.AbsoluteSize
	if screen.X < 50 or screen.Y < 50 then
		return
	end
	local small = math.min(screen.X, screen.Y) <= 500
	local attackR = small and 44 or 56
	local smallR = small and 29 or 36
	local gap = small and 10 or 12

	local jumpCenter, jumpR
	local jump = jumpButton()
	if jump then
		jumpR = jump.AbsoluteSize.X / 2
		jumpCenter = jump.AbsolutePosition + jump.AbsoluteSize / 2 - root.AbsolutePosition
	else
		-- Та же формула, что у PlayerModule (TouchJump).
		local size = small and 70 or 120
		jumpR = size / 2
		local x = screen.X - (size * 1.5 - 10) + jumpR
		local y = small and (screen.Y - size - 20 + jumpR) or (screen.Y - size * 1.75 + jumpR)
		jumpCenter = Vector2.new(x, y)
	end

	local center = Vector2.new(jumpCenter.X - jumpR - gap - attackR, jumpCenter.Y - jumpR * 0.3)
	center = Vector2.new(
		math.max(center.X, attackR + 8),
		math.clamp(center.Y, attackR + 8, math.max(attackR + 8, screen.Y - attackR - 6))
	)
	local ring1 = attackR + gap + smallR
	local ring2 = ring1 + smallR * 2 + gap
	for _, entry in pairs(entries) do
		local slot = SLOTS[entry.slot]
		if slot and entry.button then
			local radius = 0
			if slot.ring == 1 then
				radius = ring1
			elseif slot.ring == 2 then
				radius = ring2
			end
			local angle = math.rad(slot.angle)
			local position = center + Vector2.new(math.cos(angle), -math.sin(angle)) * radius
			local r = slot.ring == 0 and attackR or smallR
			entry.button.Position = UDim2.fromOffset(math.floor(position.X + 0.5), math.floor(position.Y + 0.5))
			entry.button.Size = UDim2.fromOffset(r * 2, r * 2)
		end
	end
end

local function refreshEntry(entry)
	local button = entry.button
	if not button then
		return
	end
	local visible = SLOTS[entry.slot] ~= nil
	if visible and entry.visible then
		local ok, value = pcall(entry.visible)
		visible = ok and value ~= false
	end
	if button.Visible ~= visible then
		button.Visible = visible
	end
	if not visible then
		release(entry, Enum.UserInputState.Cancel)
		return
	end

	local left, total = 0, 1
	if entry.cooldown then
		local ok, a, b = pcall(entry.cooldown)
		if ok and type(a) == "number" then
			left = a
			total = (type(b) == "number" and b > 0) and b or math.max(a, 0.01)
		end
	end
	local cooling = left > 0.05
	entry.shade.Visible = cooling
	entry.timer.Visible = cooling
	if cooling then
		entry.shade.BackgroundTransparency = 0.25 + 0.4 * (1 - math.clamp(left / total, 0, 1))
		entry.timer.Text = left >= 10 and tostring(math.ceil(left)) or string.format("%.1f", left)
	end
	entry.labelUi.TextTransparency = cooling and 0.75 or 0

	if entry.count then
		local ok, n = pcall(entry.count)
		if ok and type(n) == "number" then
			local value = math.max(math.floor(n), 0)
			entry.badge.Visible = true
			entry.badge.Text = tostring(value)
			entry.badge.BackgroundColor3 = value > 0 and COLORS.badge or COLORS.badgeEmpty
			button.BackgroundTransparency = value > 0 and 0.3 or 0.6
		else
			entry.badge.Visible = false
			button.BackgroundTransparency = 0.3
		end
	end
end

local function wantShown(): boolean
	if not touchMode or not hudVisible then
		return false
	end
	if ClientState.isInputBlocked() then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local accumulator = 0
local function step(dt: number)
	accumulator += dt
	if accumulator < 1 / 15 then
		return
	end
	accumulator = 0
	local want = wantShown()
	if want ~= shown then
		shown = want
		if gui then
			gui.Enabled = want
		end
		if not want then
			for _, entry in pairs(entries) do
				release(entry, Enum.UserInputState.Cancel)
			end
		end
	end
	if want then
		for _, entry in pairs(entries) do
			refreshEntry(entry)
		end
	end
end

local function hasDesktopInput(): boolean
	return UserInputService.KeyboardEnabled or UserInputService.MouseEnabled or UserInputService.GamepadEnabled
end

local function onInputType(kind: Enum.UserInputType)
	if kind == Enum.UserInputType.Touch then
		touchMode = true
		return
	end
	-- На чистом телефоне мыши и клавиатуры нет — режим не сбрасываем.
	if not hasDesktopInput() then
		return
	end
	if
		kind == Enum.UserInputType.Keyboard
		or kind == Enum.UserInputType.MouseMovement
		or kind == Enum.UserInputType.MouseButton1
		or kind == Enum.UserInputType.MouseButton2
		or string.sub(kind.Name, 1, 7) == "Gamepad"
	then
		touchMode = false
	end
end

local function watchJump(button: Instance)
	if button.Name == "JumpButton" and button:IsA("GuiObject") then
		button:GetPropertyChangedSignal("AbsolutePosition"):Connect(layout)
		button:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
		task.defer(layout)
	end
end

local function init()
	if started then
		return
	end
	started = true
	local playerGui = player:WaitForChild("PlayerGui")

	-- Телефон держат горизонтально: интерфейс и кластер рассчитаны на это.
	if UserInputService.TouchEnabled then
		pcall(function()
			playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
		end)
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "KlinokTouch"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	gui.Parent = playerGui

	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		watchJump(descendant)
	end
	playerGui.DescendantAdded:Connect(watchJump)

	touchMode = UserInputService.TouchEnabled
		and (UserInputService:GetLastInputType() == Enum.UserInputType.Touch or not hasDesktopInput())
	UserInputService.LastInputTypeChanged:Connect(onInputType)

	-- Отпускание ловим глобально: палец мог уйти с кнопки.
	UserInputService.InputEnded:Connect(function(input)
		for _, entry in pairs(entries) do
			if entry.input == input then
				release(entry, Enum.UserInputState.End)
			end
		end
	end)

	Bus.on("hud", function(data)
		hudVisible = not (type(data) == "table" and data.visible == false)
	end)

	RunService.Heartbeat:Connect(step)
end

function TouchControls.bind(id: string, options)
	init()
	local old = entries[id]
	if old and old.button then
		release(old, Enum.UserInputState.Cancel)
		old.button:Destroy()
	end
	local entry = {
		id = id,
		slot = options.slot,
		label = options.label or id,
		handler = options.handler,
		cooldown = options.cooldown,
		count = options.count,
		visible = options.visible,
		color = options.color,
		input = nil,
	}
	entries[id] = entry
	buildButton(entry)
	layout()
	refreshEntry(entry)
	return entry
end

function TouchControls.unbind(id: string)
	local entry = entries[id]
	if not entry then
		return
	end
	release(entry, Enum.UserInputState.Cancel)
	if entry.button then
		entry.button:Destroy()
	end
	entries[id] = nil
end

-- Последний ввод — касание (для доводки удара и подсказок).
function TouchControls.isTouch(): boolean
	return touchMode
end

-- Кластер сейчас на экране.
function TouchControls.enabled(): boolean
	return shown
end

return TouchControls
