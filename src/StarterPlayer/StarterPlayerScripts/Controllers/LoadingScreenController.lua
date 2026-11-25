--!nonstrict
-- LoadingScreenController (клиент)
-- Полноэкранная заставка загрузки профиля: тёмный фон, пиксельный титул,
-- строки лора и живой статус. Игрок не остаётся в «чёрном мире», пока
-- DataService идёт в хранилище (в сбойном случае — до 5 попыток).
-- Экран уходит, когда:
--   * профиль загружен (атрибут ProfileVersion от сервера);
--   * начался вступительный ролик (FilmPlaying) — он не ждёт профиль;
--   * сервер отключил игрока (экран не важен, уходит вместе с клиентом).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LoadingScreen = {}

-- Вся сборка — в start(): модуль требует Bootstrap (вызывается первым).
function LoadingScreen.start()

local gui = Instance.new("ScreenGui")
gui.Name = "KlinokLoading"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100 -- поверх всего, включая ролик
gui.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.Name = "Back"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(10, 7, 5)
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 1
backdrop.Active = true -- не даём кликать в мир под заставкой
backdrop.Parent = gui

local ARC = Font.fromEnum(Enum.Font.Arcade)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.new(0.5, 0, 0.42, 0)
title.Size = UDim2.fromOffset(900, 60)
title.FontFace = ARC
title.TextSize = 40
title.TextColor3 = Color3.fromRGB(255, 204, 84)
title.Text = "КЛИНОК ПАМЯТИ"
title.ZIndex = 2
title.Parent = backdrop

local lore = Instance.new("TextLabel")
lore.BackgroundTransparency = 1
lore.AnchorPoint = Vector2.new(0.5, 0)
lore.Position = UDim2.new(0.5, 0, 0.52, 0)
lore.Size = UDim2.fromOffset(760, 46)
lore.FontFace = ARC
lore.TextSize = 17
lore.TextColor3 = Color3.fromRGB(214, 226, 255)
lore.TextWrapped = true
lore.Text = ""
lore.ZIndex = 2
lore.Parent = backdrop

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.new(0.5, 0, 0.62, 0)
status.Size = UDim2.fromOffset(600, 26)
status.FontFace = ARC
status.TextSize = 14
status.TextColor3 = Color3.fromRGB(154, 160, 166)
status.Text = "собираем памяти"
status.ZIndex = 2
status.Parent = backdrop

local LORE = {
	"Памяти павших не умирают — они живут в клинке.",
	"Долина Последнего Эха — последний оплот живых.",
	"Каждая победа делает клинок тяжелее и мудрее.",
	"Рывок сквозь смерть, парирование судьбы.",
	"Этажи помнят тех, кто прошёл их до конца.",
}
local loreIndex = 0
task.spawn(function()
	while gui.Parent do
		loreIndex += 1
		lore.Text = LORE[((loreIndex - 1) % #LORE) + 1]
		task.wait(4)
	end
end)

-- Живой статус: «собираем памяти ···»
task.spawn(function()
	local dots = 0
	while gui.Parent do
		dots = (dots % 3) + 1
		local base = status:GetAttribute("Base") or "собираем памяти"
		status.Text = base .. string.rep(" ·", dots)
		task.wait(0.4)
	end
end)

-- Ждём: если хранилище молчит дольше 45 с — меняем текст статуса.
task.delay(45, function()
	if gui.Parent then
		status:SetAttribute("Base", "хранилище не отвечает, пробуем ещё")
	end
end)

local done = false
local function finish(fast: boolean)
	if done then
		return
	end
	done = true
	if fast then
		gui:Destroy()
		return
	end
	local fade = TweenService:Create(backdrop, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	fade:Play()
	for _, label in ipairs({ title, lore, status }) do
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	end
	fade.Completed:Wait()
	gui:Destroy()
end

-- Ролик не ждёт профиль: пока он играет, заставка прячется (не уничтожается),
-- а после ролика возвращается, если профиль ещё не готов.
local function sync()
	if done then
		return
	end
	local profileReady = player:GetAttribute("ProfileVersion") ~= nil
	local film = player:GetAttribute("FilmPlaying") == true
	if profileReady then
		finish(false)
		return
	end
	gui.Enabled = not film
end

player:GetAttributeChangedSignal("ProfileVersion"):Connect(sync)
player:GetAttributeChangedSignal("FilmPlaying"):Connect(sync)
sync()

print("[LoadingScreen] заставка загрузки готова")
end

return LoadingScreen
