--!nonstrict
-- SettingsController (клиент)
-- Окно настроек в бумажном стиле: громкость музыки, громкость звуков,
-- чувствительность камеры. Кнопка «НАСТР» в HUD рядом с «ОТРЯД».
-- Значения хранятся в профиле (PlayerSettings) и применяются на клиенте:
-- SoundGroups KlinokMusic/KlinokUi/KlinokSfx + CameraController.setSensitivity.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local Lib = script.Parent.Parent.Lib
local PixelUi = require(Lib.PixelUi)
local PaperUi = require(Lib.PaperUi)
local UiSound = require(Lib.UiSound)
local CameraController = require(script.Parent.CameraController)

local P = PaperUi.colors

local SettingsController = {}

-- Вся сборка — в start(): модуль требует Bootstrap.
function SettingsController.start()

local remote = Net.get("RequestSettings")

-- ===== HUD-кнопка =====
local gui, root = PixelUi.screen("KlinokSettings", 44)
local canvas = PixelUi.canvas(root)
canvas.Visible = false

-- Кнопка-шестерёнка в квадрате (слева от «ОТРЯД», не задевает «В ПЕЩЕРУ»).
local GEAR = "rbxassetid://136662035868556" -- пиксельная шестерёнка (tools/classart/gear.png)
local gearFrame = Instance.new("Frame")
gearFrame.Name = "SettingsButton"
gearFrame.AnchorPoint = Vector2.new(1, 0)
gearFrame.Position = UDim2.new(1, -178, 0, 118)
gearFrame.Size = UDim2.fromOffset(48, 48)
gearFrame.BackgroundColor3 = Color3.fromRGB(26, 16, 10)
gearFrame.BorderSizePixel = 0
gearFrame.ZIndex = 8
gearFrame.Parent = root
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = gearFrame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(122, 86, 54)
	stroke.Thickness = 2
	stroke.Parent = gearFrame
	local gear = Instance.new("ImageLabel")
	gear.Name = "Gear"
	gear.AnchorPoint = Vector2.new(0.5, 0.5)
	gear.Position = UDim2.fromScale(0.5, 0.5)
	gear.Size = UDim2.fromOffset(34, 34)
	gear.BackgroundTransparency = 1
	gear.Image = GEAR
	gear.ZIndex = 9
	gear.Parent = gearFrame
	pcall(function()
		gear.ResampleMode = Enum.ResampleMode.Pixel
	end)
end
local gearHit = Instance.new("TextButton")
gearHit.Name = "GearHit"
gearHit.Text = ""
gearHit.AutoButtonColor = false
gearHit.BackgroundTransparency = 1
gearHit.Size = UDim2.fromScale(1, 1)
gearHit.ZIndex = 10
gearHit.Parent = gearFrame

-- ===== окно (пергамент) =====
PixelUi.shadow(canvas, UDim2.fromOffset(454, 196), UDim2.fromOffset(692, 548), 2)
local sheet = PixelUi.parch(canvas, UDim2.fromOffset(470, 180), UDim2.fromOffset(660, 520))
sheet.ZIndex = 3

local header = PixelUi.text(sheet, "НАСТРОЙКИ", 24, P.ink, {
	Name = "Header",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 20),
	Size = UDim2.fromOffset(400, 34),
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 6,
})
local divider = Instance.new("Frame")
divider.Name = "Divider"
divider.AnchorPoint = Vector2.new(0.5, 0)
divider.Position = UDim2.new(0.5, 0, 0, 62)
divider.Size = UDim2.fromOffset(480, 2)
divider.BackgroundColor3 = P.ink2
divider.BorderSizePixel = 0
divider.ZIndex = 5
divider.Parent = sheet

-- ===== слайдер =====
-- Paper-слайдер: тёмная дорожка, золотая заполненная часть, круглый ползунок.
local function buildSlider(parent, label: string, y: number, initial: number, onChange)
	local holder = Instance.new("Frame")
	holder.Name = label
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(70, y)
	holder.Size = UDim2.fromOffset(520, 74)
	holder.ZIndex = 6
	holder.Parent = parent

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(0, 0)
	title.Size = UDim2.fromOffset(520, 24)
	title.FontFace = Font.fromEnum(Enum.Font.Arcade)
	title.TextSize = 15
	title.TextColor3 = P.ink
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = label
	title.ZIndex = 7
	title.Parent = holder

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(0, 40)
	track.Size = UDim2.fromOffset(520, 10)
	track.BackgroundColor3 = P.paperDark
	track.BorderSizePixel = 0
	track.ZIndex = 7
	track.Parent = holder
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(initial, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 204, 84)
	fill.BorderSizePixel = 0
	fill.ZIndex = 8
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(initial, 0, 0.5, 0)
	knob.Size = UDim2.fromOffset(22, 22)
	knob.BackgroundColor3 = P.ink
	knob.BorderSizePixel = 0
	knob.ZIndex = 9
	knob.Parent = track
	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.Position = UDim2.new(1, 0, 0, 0)
	valueLabel.Size = UDim2.fromOffset(70, 24)
	valueLabel.BackgroundTransparency = 1
	valueLabel.FontFace = Font.fromEnum(Enum.Font.Arcade)
	valueLabel.TextSize = 15
	valueLabel.TextColor3 = P.ink2
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Text = tostring(math.floor(initial * 100)) .. "%"
	valueLabel.ZIndex = 7
	valueLabel.Parent = holder

	local object = { holder = holder }

	function object.set(value: number)
		value = math.clamp(value, 0, 1)
		fill.Size = UDim2.fromScale(value, 1)
		knob.Position = UDim2.new(value, 0, 0.5, 0)
		valueLabel.Text = tostring(math.floor(value * 100)) .. "%"
		if onChange then
			onChange(value)
		end
	end

	local dragging = false
	local function valueFromX(x: number): number
		local abs = track.AbsolutePosition.X
		return math.clamp((x - abs) / track.AbsoluteSize.X, 0, 1)
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			object.set(valueFromX(input.Position.X))
		end
	end)
	track.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			object.set(valueFromX(input.Position.X))
		end
	end)
	track.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	return object
end

-- ===== применение настроек =====
local state = { music = 0.7, sfx = 1, sens = 1 }

local function applyMusic(v: number)
	local group = SoundService:FindFirstChild("KlinokMusic")
	if group and group:IsA("SoundGroup") then
		group.Volume = v
	end
end

local function applySfx(v: number)
	for _, name in ipairs({ "KlinokSfx", "KlinokUi" }) do
		local group = SoundService:FindFirstChild(name)
		if group and group:IsA("SoundGroup") then
			group.Volume = v
		end
	end
end

local function applySens(v: number)
	if CameraController.setSensitivity then
		pcall(CameraController.setSensitivity, v)
	end
end

local savePending = nil
local function scheduleSave()
	if savePending then
		task.cancel(savePending)
	end
	savePending = task.delay(0.8, function()
		savePending = nil
		pcall(function()
			remote:InvokeServer({ action = "set", settings = state })
		end)
	end)
end

-- ===== сборка слайдеров =====
buildSlider(sheet, "Громкость музыки", 84, state.music, function(v)
	state.music = v
	applyMusic(v)
	scheduleSave()
end)
buildSlider(sheet, "Громкость звуков", 168, state.sfx, function(v)
	state.sfx = v
	applySfx(v)
	scheduleSave()
end)
buildSlider(sheet, "Чувствительность камеры", 252, state.sens, function(v)
	state.sens = v
	applySens(v)
	scheduleSave()
end)

-- подпись-подсказка
PixelUi.text(sheet, "настройки сохраняются в профиле", 13, P.faint, {
	Name = "Hint",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(500, 20),
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 6,
})

-- ===== открыть/закрыть =====
local function openWindow()
	canvas.Visible = true
	UiSound.play("paper_slide", { volume = 0.6 })
end

local function closeWindow()
	canvas.Visible = false
	UiSound.play("paper_slide", { volume = 0.4 })
end

gearHit.Activated:Connect(function()
	if canvas.Visible then
		closeWindow()
	else
		openWindow()
	end
end)

game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and canvas.Visible then
		closeWindow()
	end
end)

-- ===== загрузка сохранённых значений при старте =====
task.spawn(function()
	local waited = 0
	while not player:GetAttribute("ProfileVersion") and waited < 60 and player.Parent do
		waited += task.wait(0.25)
	end
	local ok, res = pcall(function()
		return remote:InvokeServer({ action = "get" })
	end)
	if ok and type(res) == "table" and res.ok and type(res.settings) == "table" then
		state.music = res.settings.music or state.music
		state.sfx = res.settings.sfx or state.sfx
		state.sens = res.settings.sens or state.sens
	end
	applyMusic(state.music)
	applySfx(state.sfx)
	applySens(state.sens)
	-- слайдеры создаются вместе с окном настроек: на старте контроллера их ещё нет
	if musicSlider then
		musicSlider.set(state.music)
	end
end)

print("[SettingsController] окно настроек готово")
end

return SettingsController
