--[[
  «Клинок Памяти» — вступительная катсцена v3 (38,5 сек)
  ТИП: LocalScript
  КУДА: StarterPlayer > StarterPlayerScripts > IntroCutscene

  Работает вместе с BuildIntroStage.lua (он строит IntroStage и IntroCam).
  Ручной расстановки не нужно: камера, свет, частицы, клинки, герой — всё автоматически.

  РЕЖИМ ЗАПИСИ (CFG.RECORD_MODE = true): ролик запускается сам при нажатии Play (F5),
  без кнопки пропуска, с паузой в 2 сек до старта и чёрным кадром с названием в конце.
  Для игроков поставьте RECORD_MODE = false (кнопка пропуска, возврат управления).
  Запись экрана: 1920x1080, 60 fps.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera
-- Флаг для игровых систем (заставка загрузки, TutorialController, HubController,
-- свет): пока ролик идёт, свои экраны и освещение не показываем. Снимается в finish().
player:SetAttribute("FilmPlaying", true)

---------------------------------------------------------------- НАСТРОЙКИ
local CFG = {
	RECORD_MODE = false, -- true только на время записи трейлера; для тестов и игроков false
	SUBTITLES = true,                       -- false = чистая картинка без субтитров
	SKIP_APPEARS_AT = 5,
	MEMORY_COLOR = Color3.fromHex("6FE3FF"),
	SUB_COLOR = Color3.fromRGB(217, 246, 255),
	-- Английские субтитры: встроенный пиксельный шрифт Roblox.
	FONT_LATIN = Font.fromEnum(Enum.Font.Arcade),
	-- Кириллица («Пропустить», название): Arcade её не умеет, поэтому SourceSansBold.
	-- Чтобы подставить шрифт вашего UI: Font.new("rbxassetid://ID_СЕМЕЙСТВА_ШРИФТА")
	FONT_CYRILLIC = Font.fromEnum(Enum.Font.SourceSansBold),
	TITLE_TEXT = "КЛИНОК ПАМЯТИ",
	FOV = 60,
	-- Кто поднимает клинок: "model" — обычная чёрная фигурка игрока Roblox со светящимися глазами;
	-- "none" — героя нет совсем, клинок наполняется душами и поднимается сам.
	HERO_MODE = "model",
	-- Скин героя: true — фигурку визуально заменяет аватар САМОГО зрителя (каждый видит
	-- своего персонажа). Хореография не меняется: мешы аватара жёстко ездят на тех же
	-- костях (сегмент тела = кость). R6-аватары пока не поддерживаются — останется
	-- чёрная фигурка. false — прежняя чёрная фигурка со светящимися глазами.
	HERO_SKIN = true,
	-- глаза героя. Красные на тёмной фигурке — единственный тёплый акцент в сине-голубой сцене.
	-- Голубой вариант, родной для сцены: Color3.fromRGB(150, 235, 255)
	-- (со скином глаза — неоновая вспышка поверх лица аватара на 30,5)
	HERO_EYE_COLOR = Color3.fromRGB(255, 45, 40),
	-- Ручки настройки эффектов (крутите без правки остального кода)
	FX = {
		ParticleDensity = 1.0,  -- 0.5 = вдвое меньше частиц, 2 = вдвое больше
		BloomIntensity = 1.2,   -- свечение голубого (на референсах оно мягкое и большое)
		BloomSize = 38,
		BloomThreshold = 0.8,
		Vignette = 0.45,        -- затемнение по краям, 0 = выключить
		Saturation = 0.12,
		Contrast = 0.12,
	},

	-- Звуки. id = 0: звук пропускается, ролик не падает. bus: Music / Amb / SFX / Voice — у каждой шины своя громкость,
	-- музыка и атмосфера сами приглушаются под голос. loop = true: зацикленный звук.
	-- Что делает каждый звук, тайм-коды и промпты для генераторов: документ «Звуковая палитра».
	SOUNDS = {
		-- Музыка: пять кусков, скрипт сводит их кроссфейдом. Если загружен один общий трек в Music (38,5 с), куски не играют.
		Music         = { id = 0, volume = 0.55, bus = "Music" },
		MusicVoid     = { id = 0, volume = 0.55, bus = "Music" },   -- 0:00 пустота и коридор
		MusicHall     = { id = 0, volume = 0.55, bus = "Music" },   -- 0:11 зал, хор
		MusicRot      = { id = 0, volume = 0.6,  bus = "Music" },   -- 0:18 память гниёт
		MusicAwaken   = { id = 0, volume = 0.6,  bus = "Music" },   -- 0:26 Пробуждённый
		MusicFinale   = { id = 0, volume = 0.65, bus = "Music" },   -- 0:33 клинок и название
		-- Атмосфера
		SubHum        = { id = 0, volume = 0.8,  bus = "Amb" },     -- суббас, 0:00
		AmbCorridor   = { id = 0, volume = 0.5,  bus = "Amb", loop = true },
		AmbHall       = { id = 0, volume = 0.45, bus = "Amb", loop = true },
		ForgeFire     = { id = 0, volume = 0.7,  bus = "Amb", loop = true },   -- объёмный, сидит в чаше Горнила
		BladeHum      = { id = 0, volume = 0.65, bus = "Amb", loop = true },   -- объёмный, сидит в клинке, высота растёт с наполнением
		-- События
		Hammer        = { id = 0, volume = 0.9,  bus = "SFX" },     -- одинокий далёкий удар молота по Горнилу, 0:01
		LightOn       = { id = 0, volume = 0.7,  bus = "SFX" },
		HallReveal    = { id = 0, volume = 0.9,  bus = "SFX" },
		Corrupt       = { id = 0, volume = 0.9,  bus = "SFX" },
		Absorb        = { id = 0, volume = 1.0,  bus = "SFX" },
		SoulTick      = { id = 0, volume = 0.8,  bus = "SFX" },
		BladeFull     = { id = 0, volume = 1.0,  bus = "SFX" },
		Scrape        = { id = 0, volume = 1.0,  bus = "SFX" },
		Thud          = { id = 0, volume = 1.0,  bus = "SFX" },
		Materialize   = { id = 0, volume = 0.9,  bus = "SFX" },
		Grip          = { id = 0, volume = 0.9,  bus = "SFX" },
		BladeRise     = { id = 0, volume = 0.9,  bus = "SFX" },
		EyesOpen      = { id = 0, volume = 0.9,  bus = "SFX" },
		Whoosh        = { id = 0, volume = 0.8,  bus = "SFX" },
		TitleSting    = { id = 0, volume = 1.0,  bus = "SFX" },
		FinalHit      = { id = 0, volume = 1.0,  bus = "SFX" },
		-- Голос (бриф в VOICE_BRIEF.md)
		Voice1        = { id = 0, volume = 1.0,  bus = "Voice" },
		Voice2        = { id = 0, volume = 1.0,  bus = "Voice" },
		Voice3        = { id = 0, volume = 1.0,  bus = "Voice" },
		Voice4        = { id = 0, volume = 1.0,  bus = "Voice" },
		Voice5        = { id = 0, volume = 1.0,  bus = "Voice" },
	},
}

local SUBS = {
	{ t = 4.0,  delay = 0.4, dur = 6.0, text = "The world remembers everything…\nEven what it was meant to forget." },
	{ t = 11.0, delay = 0.4, dur = 6.5, text = "The First Blacksmith wanted to keep every soul.\nEvery echo. Every pain." },
	{ t = 18.0, delay = 0.4, dur = 7.5, text = "But memory rots.\nMemories become monsters.\nAnd the world… begins to forget." },
	{ t = 26.0, delay = 0.4, dur = 6.5, text = "You are the Awakened.\nYou have no name. No past.\nOnly an empty blade…\nand the memories of others." },
	{ t = 33.5, delay = 0.2, dur = 3.5, text = "Absorb. Or forget." },
}
local TOTAL = 38.5

---------------------------------------------------------------- СОСТОЯНИЕ
local skipped, finished = false, false
local T0 = 0
local cleanup = {}
local function onCleanup(fn) table.insert(cleanup, fn) end
local function now() return os.clock() - T0 end
-- ждать до момента t; false, если ролик пропустили
local function at(t)
	while now() < t do
		if skipped then return false end
		RunService.Heartbeat:Wait()
	end
	return not skipped
end

---------------------------------------------------------------- СЦЕНА
-- Сцена лежит либо в Workspace (запись ролика), либо в ReplicatedStorage (в игре):
-- тогда клонируем её на время ролика и удаляем после.
local function acquire(name)
	local o = workspace:FindFirstChild(name)
	if o then return o, false end
	local src = ReplicatedStorage:FindFirstChild(name)
	if src then
		local c = src:Clone()
		c.Parent = workspace
		return c, true
	end
	return nil, false
end

local stage, stageCloned, camFolder, camCloned
do
	local waited = 0
	repeat
		stage, stageCloned = acquire("IntroStage")
		camFolder, camCloned = acquire("IntroCam")
		if stage and camFolder then break end
		task.wait(0.25)
		waited = waited + 0.25
	until waited >= 10
end
if not stage or not camFolder then
	warn("[IntroCutscene] нет IntroStage/IntroCam — сначала запустите BuildIntroStage.lua в Command Bar")
	return
end
local dofEffect
local setDOF
-- на мобильных и слабых устройствах убираем микродетали (папка Detail)
do
	local UIS = game:GetService("UserInputService")
	local det = stage:FindFirstChild("Detail")
	if det and (UIS.TouchEnabled and not UIS.KeyboardEnabled) and not CFG.RECORD_MODE then
		det:Destroy()
	end
end
local function pt(name)
	local p = camFolder:FindFirstChild(name)
	if not p then warn("[IntroCutscene] не найден IntroCam." .. name) end
	return p
end

-- при StreamingEnabled просим подгрузить удалённую сцену и даём ей время приехать
if workspace.StreamingEnabled and not (stageCloned and camCloned) then
	local s1 = camFolder:FindFirstChild("Shot1")
	if s1 then pcall(function() player:RequestStreamAroundAsync(s1.Position) end) end
	task.wait(2)
end

---------------------------------------------------------------- ЗВУКИ И СЛУЖЕБНЫЕ ОБЪЕКТЫ
local runtime = Instance.new("Folder")
runtime.Name = "IntroRuntime"
runtime.Parent = camera
-- шины: у каждой своя громкость, музыка и атмосфера приглушаются под голос
local soundService = game:GetService("SoundService")
local groups = {}
for _, bus in ipairs({ "Music", "Amb", "SFX", "Voice" }) do
	local g = Instance.new("SoundGroup")
	g.Name = "Intro" .. bus
	g.Volume = 1
	g.Parent = soundService
	groups[bus] = g
end
onCleanup(function() for _, g in pairs(groups) do g:Destroy() end end)

local sounds = {}
for name, s in pairs(CFG.SOUNDS) do
	local snd = Instance.new("Sound")
	snd.Name = name
	snd.Volume = s.volume
	snd.Looped = s.loop == true
	snd.SoundGroup = groups[s.bus or "SFX"]
	if s.id and s.id ~= 0 then snd.SoundId = "rbxassetid://" .. tostring(s.id) end
	snd.Parent = runtime
	sounds[name] = snd
end
-- один общий трек в Music: куски музыки тогда не играем
local singleMusic = sounds.Music and sounds.Music.SoundId ~= ""

-- длины реплик из VOICE_BRIEF.md: по ним музыка приглушается, пока говорит голос
local VOICE_LEN = { Voice1 = 6.5, Voice2 = 6.5, Voice3 = 7.5, Voice4 = 6.5, Voice5 = 3.0 }
local duckToken = 0
local function duck(len)
	duckToken = duckToken + 1
	local my = duckToken
	TweenService:Create(groups.Music, TweenInfo.new(0.4), { Volume = 0.6 }):Play()
	TweenService:Create(groups.Amb, TweenInfo.new(0.4), { Volume = 0.8 }):Play()
	task.delay(len, function()
		if my == duckToken and groups.Music.Parent then
			TweenService:Create(groups.Music, TweenInfo.new(1.0), { Volume = 1 }):Play()
			TweenService:Create(groups.Amb, TweenInfo.new(1.0), { Volume = 1 }):Play()
		end
	end)
end
local function play(name, mul)
	local s = sounds[name]
	if not (s and s.SoundId ~= "") then return end
	s.Volume = CFG.SOUNDS[name].volume * (mul or 1)
	s:Play()
	if name:sub(1, 5) == "Voice" then
		local tl = s.TimeLength
		duck((tl and tl > 0) and (tl + 0.3) or (VOICE_LEN[name] or 6))
	end
end
-- плавный вход / выход звука (для кусков музыки и атмосферы)
local function fadeIn(name, dur)
	local s = sounds[name]
	if not (s and s.SoundId ~= "") then return end
	if singleMusic and name:sub(1, 5) == "Music" then return end
	s.Volume = 0
	s:Play()
	TweenService:Create(s, TweenInfo.new(dur), { Volume = CFG.SOUNDS[name].volume }):Play()
end
local function fadeOut(name, dur)
	local s = sounds[name]
	if not (s and s.IsPlaying) then return end
	TweenService:Create(s, TweenInfo.new(dur), { Volume = 0 }):Play()
	task.delay(dur + 0.05, function() if s.Parent then s:Stop() end end)
end
local function fadeOutSounds(dur)
	for _, s in pairs(sounds) do
		if s.IsPlaying then TweenService:Create(s, TweenInfo.new(dur), { Volume = 0 }):Play() end
	end
end
-- тик прилёта души: высота растёт вместе с наполнением клинка (0..1), так «заряд» слышно
local tickPool, tickI, lastTick = {}, 0, 0
local function soulTick(frac)
	local base = sounds.SoulTick
	if not (base and base.SoundId ~= "") then return end
	local nowT = os.clock()
	if nowT - lastTick < 0.04 then return end
	lastTick = nowT
	if #tickPool == 0 then
		for i = 1, 4 do
			local c = base:Clone()
			c.Parent = runtime
			tickPool[i] = c
		end
	end
	tickI = tickI % 4 + 1
	local c = tickPool[tickI]
	c.PlaybackSpeed = 0.85 + 0.9 * math.min(frac, 1) + (math.random() - 0.5) * 0.08
	c.Volume = base.Volume * (0.55 + 0.45 * math.min(frac, 1))
	c:Play()
end

local camValue = Instance.new("CFrameValue")
camValue.Name = "CameraValue"
camValue.Parent = runtime

---------------------------------------------------------------- UI
local gui = Instance.new("ScreenGui")
gui.Name = "IntroCutsceneGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.Parent = playerGui

local black = Instance.new("Frame")
black.Name = "Black"
black.Size = UDim2.fromScale(1, 1)
black.BackgroundColor3 = Color3.new(0, 0, 0)
black.BorderSizePixel = 0
black.ZIndex = 1
black.Parent = gui

for _, top in ipairs({ true, false }) do
	local bar = Instance.new("Frame")
	bar.Name = top and "BarTop" or "BarBottom"
	bar.Size = UDim2.new(1, 0, 0.09, 0)
	bar.Position = top and UDim2.fromScale(0, 0) or UDim2.fromScale(0, 0.91)
	bar.BackgroundColor3 = Color3.new(0, 0, 0)
	bar.BorderSizePixel = 0
	bar.ZIndex = 5
	bar.Parent = gui
end

-- виньетка (мягкое затемнение краёв)
if CFG.FX.Vignette > 0 then
	local function edge(pos, size, rot)
		local f = Instance.new("Frame")
		f.Name = "Vignette"
		f.Position = pos
		f.Size = size
		f.BackgroundColor3 = Color3.fromRGB(4, 6, 18)
		f.BorderSizePixel = 0
		f.ZIndex = 4
		local g = Instance.new("UIGradient")
		g.Rotation = rot
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - CFG.FX.Vignette),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
		f.Parent = gui
	end
	edge(UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.25), 90)
	edge(UDim2.fromScale(0, 0.75), UDim2.fromScale(1, 0.25), -90)
	edge(UDim2.fromScale(0, 0), UDim2.fromScale(0.2, 1), 0)
	edge(UDim2.fromScale(0.8, 0), UDim2.fromScale(0.2, 1), 180)
end

local subLabel = Instance.new("TextLabel")
subLabel.Name = "Subtitle"
subLabel.AnchorPoint = Vector2.new(0.5, 1)
subLabel.Position = UDim2.fromScale(0.5, 0.86)
subLabel.Size = UDim2.fromScale(0.8, 0.14)
subLabel.BackgroundTransparency = 1
subLabel.FontFace = CFG.FONT_LATIN
subLabel.TextScaled = true
subLabel.TextColor3 = CFG.SUB_COLOR
subLabel.TextStrokeColor3 = Color3.fromRGB(10, 40, 60)
subLabel.TextStrokeTransparency = 1
subLabel.TextTransparency = 1
subLabel.TextWrapped = true
subLabel.ZIndex = 6
subLabel.Parent = gui
local subLimit = Instance.new("UITextSizeConstraint")
subLimit.MaxTextSize = 34
subLimit.Parent = subLabel

local function showSub(text, dur)
	if not CFG.SUBTITLES then return end
	subLabel.Text = text
	TweenService:Create(subLabel, TweenInfo.new(0.4), { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
	task.delay(dur - 0.4, function()
		if skipped or finished then return end
		TweenService:Create(subLabel, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

local skipBtn = Instance.new("TextButton")
skipBtn.Name = "SkipButton"
skipBtn.AnchorPoint = Vector2.new(1, 1)
skipBtn.Position = UDim2.new(1, -24, 0.91, -16)
skipBtn.Size = UDim2.fromOffset(190, 44)
skipBtn.BackgroundColor3 = Color3.fromRGB(20, 30, 40)
skipBtn.BackgroundTransparency = 1
skipBtn.TextTransparency = 1
skipBtn.FontFace = CFG.FONT_CYRILLIC
skipBtn.TextSize = 22
skipBtn.TextColor3 = CFG.SUB_COLOR
skipBtn.Text = "Пропустить  ▸"
skipBtn.AutoButtonColor = false
skipBtn.Active = false
skipBtn.Visible = not CFG.RECORD_MODE
skipBtn.ZIndex = 20
skipBtn.Parent = gui
local stroke = Instance.new("UIStroke")
stroke.Color = CFG.MEMORY_COLOR
stroke.Thickness = 2
stroke.Transparency = 1
stroke.Parent = skipBtn

---------------------------------------------------------------- СВЕТ И ПОСТ-ЭФФЕКТЫ (временно, потом возвращаются)
local function setupLook()
	local saved = {}
	for _, p in ipairs({ "Brightness", "ClockTime", "Ambient", "OutdoorAmbient", "ExposureCompensation",
		"FogColor", "FogStart", "FogEnd", "GlobalShadows", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" }) do
		saved[p] = Lighting[p]
	end
	-- сине-фиолетовая ночь, как на референсах (не чёрная и не бирюзовая)
	Lighting.Brightness = 0.3
	Lighting.ClockTime = 0
	Lighting.Ambient = Color3.fromRGB(52, 56, 96)
	Lighting.OutdoorAmbient = Color3.fromRGB(40, 42, 82)
	pcall(function()
		Lighting.EnvironmentDiffuseScale = 0.2      -- неба нет, окружение почти не светит: свет рисуют лампы сцены
		Lighting.EnvironmentSpecularScale = 0.15
	end)
	Lighting.ExposureCompensation = 0.45
	Lighting.FogColor = Color3.fromRGB(22, 22, 48)
	Lighting.FogStart = 60
	Lighting.FogEnd = 320
	Lighting.GlobalShadows = true

	local removed = {}
	for _, o in ipairs(Lighting:GetChildren()) do
		if o:IsA("Sky") or o:IsA("Atmosphere") or o:IsA("PostEffect") then
			table.insert(removed, o)
			o.Parent = nil
		end
	end
	local made = {}
	local function add(inst, props)
		for k, v in pairs(props) do inst[k] = v end
		inst.Parent = Lighting
		table.insert(made, inst)
	end
	-- чёрное небо без стандартных текстур, звёзд и луны: небо рисует сама сцена (папка Sky)
	add(Instance.new("Sky"), { SkyboxBk = "", SkyboxDn = "", SkyboxFt = "", SkyboxLf = "", SkyboxRt = "", SkyboxUp = "", StarCount = 0, CelestialBodiesShown = false })
	add(Instance.new("Atmosphere"), { Density = 0.32, Offset = 0, Color = Color3.fromRGB(34, 38, 74), Decay = Color3.fromRGB(14, 14, 36), Glare = 0, Haze = 1.6 })
	add(Instance.new("ColorCorrectionEffect"), { Contrast = CFG.FX.Contrast, Saturation = CFG.FX.Saturation, TintColor = Color3.fromRGB(226, 232, 255) })
	add(Instance.new("BloomEffect"), { Intensity = CFG.FX.BloomIntensity, Size = CFG.FX.BloomSize, Threshold = CFG.FX.BloomThreshold })
	dofEffect = Instance.new("DepthOfFieldEffect")
	add(dofEffect, { FarIntensity = 0.22, FocusDistance = 22, InFocusRadius = 38, NearIntensity = 0 })

	onCleanup(function()
		for _, o in ipairs(made) do o:Destroy() end
		for _, o in ipairs(removed) do o.Parent = Lighting end
		for p, v in pairs(saved) do Lighting[p] = v end
	end)
end

---------------------------------------------------------------- ЧАСТИЦЫ (только блоки)
-- плавная смена фокуса под каждый кадр
function setDOF(focus, radius, far, dur)
	if not dofEffect then return end
	TweenService:Create(dofEffect, TweenInfo.new(dur or 1.0, Enum.EasingStyle.Sine), {
		FocusDistance = focus, InFocusRadius = radius, FarIntensity = far,
	}):Play()
end

local fxFolder = Instance.new("Folder")
fxFolder.Name = "IntroFX"
fxFolder.Parent = workspace

local DENS = math.max(CFG.FX.ParticleDensity, 0.1)
-- палитра частиц памяти: белое «горячее» ядро + фирменный голубой + глубокий голубой
local PALETTE = {
	Color3.fromRGB(235, 252, 255),
	Color3.fromRGB(111, 227, 255),
	Color3.fromRGB(111, 227, 255),
	Color3.fromRGB(60, 170, 235),
}
local function pickMemoryColor() return PALETTE[math.random(#PALETTE)] end

local function makeCube(size, pos, color)
	local c = Instance.new("Part")
	c.Size = Vector3.one * size
	c.Anchored = true
	c.CanCollide = false
	c.CanQuery = false
	c.CanTouch = false
	c.CastShadow = false
	c.Material = Enum.Material.Neon
	c.Color = color or pickMemoryColor()
	c.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
	c.Parent = fxFolder
	return c
end

local ambientOn = true
-- голубые искры вокруг камеры
task.spawn(function()
	while ambientOn and not skipped do
		local cf = camera.CFrame
		local offset = cf.RightVector * math.random(-12, 12) + cf.UpVector * math.random(-6, 8) + cf.LookVector * math.random(6, 30)
		local cube = makeCube(0.12 + math.random() * 0.12, cf.Position + offset)
		local drift = Vector3.new(math.random(-10, 10) / 10, math.random(2, 8) / 10, math.random(-10, 10) / 10)
		local life = 3 + math.random() * 2
		TweenService:Create(cube, TweenInfo.new(life, Enum.EasingStyle.Sine), { Position = cube.Position + drift * 3, Transparency = 1 }):Play()
		Debris:AddItem(cube, life + 0.1)
		task.wait(0.07 / DENS)
	end
end)
-- Россыпь искр: золотые и голубые квадраты (золото — раскалённый обод Горнила)
local function burstSparks(origin, count, warmShare)
	count = math.floor(count * DENS)
	warmShare = warmShare or 0.35
	for i = 1, count do
		local warm = math.random() < warmShare
		local col = warm and Color3.fromRGB(255, 190 + math.random(0, 50), 110 + math.random(0, 40)) or pickMemoryColor()
		local c = makeCube(0.1 + math.random() * 0.2, origin, col)
		local peak = origin + Vector3.new(math.random(-60, 60) / 10, math.random(25, 70) / 10, math.random(-60, 60) / 10)
		local life = 0.8 + math.random() * 1.2
		local t1 = TweenService:Create(c, TweenInfo.new(life * 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = peak })
		t1.Completed:Connect(function()
			TweenService:Create(c, TweenInfo.new(life * 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = peak - Vector3.new(0, math.random(20, 40) / 10, 0), Transparency = 1 }):Play()
		end)
		t1:Play()
		Debris:AddItem(c, life + 0.2)
	end
end

-- Горнило Первого Кузнеца: кубики памяти поднимаются из чаши, души падают в неё из космоса,
-- по ярусам течёт каскад, у подножия вспыхивают брызги
local crucF = stage:FindFirstChild("Crucible")
local liqF = crucF and crucF:FindFirstChild("Liquid")
local casF = crucF and crucF:FindFirstChild("Cascade")
local bowlLamp = casF and casF:FindFirstChild("LampBowl")
local lipLamp = casF and casF:FindFirstChild("LampLip")
local poolLamp = casF and casF:FindFirstChild("LampPool")
local liqList = liqF and liqF:GetChildren() or {}
task.spawn(function()
	while ambientOn and not skipped and #liqList > 0 do
		local src = liqList[math.random(#liqList)]
		local pos = src.Position + Vector3.new(0, 1.2, 0)
		local gold = math.random() < 0.16
		local c = makeCube(0.18 + math.random() * 0.28, pos, gold and Color3.fromRGB(255, 205, 130) or pickMemoryColor())
		local life = 4 + math.random() * 3
		TweenService:Create(c, TweenInfo.new(life, Enum.EasingStyle.Sine), {
			Position = pos + Vector3.new(math.random(-60, 60) / 10, math.random(16, 36), math.random(-60, 60) / 10), Transparency = 1 }):Play()
		Debris:AddItem(c, life + 0.1)
		task.wait(0.05 / DENS)
	end
end)
-- души падают в чашу из космоса
task.spawn(function()
	while ambientOn and not skipped and bowlLamp do
		local a = math.random() * 6.28
		local r = 8 + math.random() * 50
		local from = bowlLamp.Position + Vector3.new(math.cos(a) * r, 50 + math.random() * 70, math.sin(a) * r * 0.5 - 8)
		local to = bowlLamp.Position + Vector3.new((math.random() - 0.5) * 18, -4, (math.random() - 0.5) * 10)
		local c = makeCube(0.35 + math.random() * 0.4, from, pickMemoryColor())
		local life = 3.2 + math.random() * 2.2
		TweenService:Create(c, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = to }):Play()
		Debris:AddItem(c, life + 0.05)
		task.wait(0.1 / DENS)
	end
end)
-- капли каскада: носик -> ярус 2 -> ярус 1 -> пол
task.spawn(function()
	while ambientOn and not skipped and lipLamp do
		local x = (math.random() - 0.5) * 8
		local o = lipLamp.Position
		local base = Vector3.new(o.X, o.Y, o.Z)
		local zPool = poolLamp and poolLamp.Position.Z or (o.Z + 20)
		local pts = {
			base + Vector3.new(x, -2, 0.8),
			Vector3.new(o.X + x * 1.2, o.Y - 14.5, o.Z + 4),
			Vector3.new(o.X + x * 1.35, o.Y - 19.5, o.Z + 14.5),
			Vector3.new(o.X + x * 1.6, o.Y - 24, zPool + 1),
		}
		local c = makeCube(0.3 + math.random() * 0.35, pts[1], math.random() < 0.3 and PALETTE[1] or pickMemoryColor())
		local durs = { 0.7, 0.4, 0.4 }
		local function leg(i)
			if i > 3 or not c.Parent then
				if c.Parent then c:Destroy() end
				return
			end
			local tw = TweenService:Create(c, TweenInfo.new(durs[i], Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = pts[i + 1] })
			tw.Completed:Connect(function() leg(i + 1) end)
			tw:Play()
		end
		leg(1)
		Debris:AddItem(c, 3)
		task.wait(0.12 / DENS)
	end
end)
-- брызги у подножия каскада и золотые вспышки носика
task.spawn(function()
	while ambientOn and not skipped and poolLamp do
		task.wait(1.4 + math.random() * 1.6)
		if ambientOn and not skipped then
			burstSparks(poolLamp.Position + Vector3.new((math.random() - 0.5) * 6, 0.8, 0), 12, 0.12)
		end
	end
end)
task.spawn(function()
	while ambientOn and not skipped and lipLamp do
		task.wait(2.2 + math.random() * 2.2)
		if ambientOn and not skipped then
			burstSparks(lipLamp.Position + Vector3.new((math.random() - 0.5) * 5, -1, 2.5), 14, 0.7)
		end
	end
end)

-- Кубики поднимаются вдоль светового столба над чашей
local beamBase = stage:FindFirstChild("BeamBase")
task.spawn(function()
	while ambientOn and not skipped and beamBase do
		local pos = beamBase.Position + Vector3.new(math.random(-60, 60) / 10, 0, math.random(-60, 60) / 10)
		local c = makeCube(0.2 + math.random() * 0.35, pos)
		local life = 4 + math.random() * 3
		TweenService:Create(c, TweenInfo.new(life, Enum.EasingStyle.Sine), {
			Position = pos + Vector3.new((math.random() - 0.5) * 6, math.random(30, 70), (math.random() - 0.5) * 6), Transparency = 1 }):Play()
		Debris:AddItem(c, life + 0.1)
		task.wait(0.07 / DENS)
	end
end)

-- Поглощение: вихрь квадратных частиц по спирали (как кольцо у «Врат Печатей»).
-- targetPart — деталь, в которую втягиваются кубики (позиция читается каждый кадр, цель может двигаться).
local function absorb(targetPart, count, duration, spread, sourcePart, vol)
	if not targetPart then return end
	spread = spread or 8
	count = math.floor(count * DENS)
	play("Absorb", vol)
	local list = {}
	for i = 1, count do
		local center = sourcePart and sourcePart.Position or targetPart.Position
		local start
		if sourcePart then
			start = center + Vector3.new(math.random(-spread, spread) / 4, math.random(-spread, spread) / 3, math.random(-spread, spread) / 4)
		else
			start = center + Vector3.new(math.random(-spread, spread), math.random(0, spread), math.random(-spread, spread))
		end
		table.insert(list, {
			start = start,
			delay = math.random() * duration * 0.6,
			life = duration * (0.4 + math.random() * 0.4),
			r = 1.5 + math.random() * 3.5,
			a0 = math.random() * 6.28,
			spin = 5 + math.random() * 5,
			size = 0.15 + math.random() * 0.3,
		})
	end
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if skipped then
			for _, p in ipairs(list) do if p.cube then p.cube:Destroy() end end
			conn:Disconnect()
			return
		end
		local el = os.clock() - t0
		local alive = false
		for _, p in ipairs(list) do
			local f = (el - p.delay) / p.life
			if f < 1 then alive = true end
			if f >= 0 and f < 1 then
				if not p.cube then p.cube = makeCube(p.size, p.start) end
				local e = f * f * (3 - 2 * f)
				local base = p.start:Lerp(targetPart.Position, e)
				local r = p.r * (1 - e)
				local a = p.a0 + f * p.spin
				local pos = base + Vector3.new(math.cos(a) * r, math.sin(a * 0.7) * r * 0.4, math.sin(a) * r)
				p.cube.CFrame = CFrame.new(pos) * CFrame.Angles(a, a * 0.5, 0)
				p.cube.Size = Vector3.one * (p.size * (1 - 0.8 * f))
				if f > 0.85 then p.cube.Color = PALETTE[1] end
			elseif f >= 1 and p.cube then
				p.cube:Destroy()
				p.cube = nil
			end
		end
		if not alive then conn:Disconnect() end
	end)
end

---------------------------------------------------------------- ЖИВАЯ СЦЕНА: покачивание клинков, герой, рука, свечение
local blades = stage:FindFirstChild("Blades")
local bladeAnim = {}
if blades then
	for _, m in ipairs(blades:GetChildren()) do
		if m:IsA("Model") then
			table.insert(bladeAnim, { m = m, base = m:GetPivot(), ph = m:GetAttribute("Phase") or 0 })
		end
	end
end
-- расплав Горнила: гладь колышется, пузыри всплывают; Колесо Клинков вращается вокруг чаши
local liqAnim = {}
for _, p in ipairs(liqList) do
	if p:IsA("BasePart") then
		table.insert(liqAnim, { p = p, cf = p.CFrame, ph = p:GetAttribute("ph") or math.random() * 6, amp = (p.Name == "Bubble") and 0.8 or 0.3 })
	end
end
local wheelF = stage:FindFirstChild("Wheel")
local wheelA, wheelB = wheelF and wheelF:FindFirstChild("WheelA"), wheelF and wheelF:FindFirstChild("WheelB")
local wheelBaseA, wheelBaseB = wheelA and wheelA:GetPivot(), wheelB and wheelB:GetPivot()
local updateHero, updateFill, updateShake
local animConn = RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, f in ipairs(liqAnim) do
		local w = math.sin(t * 1.7 + f.ph) * f.amp + math.sin(t * 3.1 + f.ph * 1.7) * f.amp * 0.4
		f.p.CFrame = f.cf * CFrame.new(0, w, 0)
	end
	if wheelA then wheelA:PivotTo(wheelBaseA * CFrame.Angles(0, 0, t * 0.04)) end
	if wheelB then wheelB:PivotTo(wheelBaseB * CFrame.Angles(0, 0, -t * 0.065)) end
	if bowlLamp then
		local l = bowlLamp:FindFirstChildOfClass("PointLight")
		if l then l.Brightness = 3.2 + 0.5 * math.sin(t * 2.3) + 0.25 * math.sin(t * 5.1) end
	end
	for _, b in ipairs(bladeAnim) do
		b.m:PivotTo(b.base * CFrame.new(0, math.sin(t * 0.8 + b.ph) * 0.4, 0) * CFrame.Angles(0, t * 0.12 + b.ph, 0))
	end
	if updateShake then updateShake() end
	if updateHero then updateHero() end
	if updateFill then updateFill() end
end)

local blade = stage:FindFirstChild("EmptyBlade")
local bladeBody = blade and blade:FindFirstChild("Blade")

-- объёмные звуки: сидят в деталях сцены, слушатель — камера, поэтому громкость и панорама идут сами
local pinned = {}
local function pin(name, part, minD, maxD)
	local snd = sounds[name]
	if not (snd and part) then return end
	snd.Parent = part
	snd.RollOffMode = Enum.RollOffMode.Linear
	snd.RollOffMinDistance = minD
	snd.RollOffMaxDistance = maxD
	table.insert(pinned, snd)
end
pin("ForgeFire", bowlLamp, 14, 120)
pin("BladeHum", bladeBody, 6, 90)
onCleanup(function() for _, snd in ipairs(pinned) do snd:Destroy() end end)

-- гул клинка: громкость и высота зависят от наполнения (считается в updateFill)
local hum = sounds.BladeHum
local humTarget, humGain = 0, 0
local function startHum()
	if hum and hum.SoundId ~= "" then
		hum.Volume = 0
		hum:Play()
		humTarget = 1
	end
end

---------------------------------------------------------------- ГЕРОЙ «ПРОБУЖДЁННЫЙ»
-- Безымянный носитель клинка — самая обычная фигурка игрока Roblox: пропорции R15, собрана из блоков,
-- матово-чёрная, без одежды, брони и украшений. Светятся только глаза, и они открываются в конце.
-- Тело считается каждый кадр: позвоночник, голова, руки и ноги (двухкостный IK).
-- У обычной фигурки руки стоят широко, поэтому меч держит одна рука (левая), как в Roblox держат инструмент;
-- правая опирается на бедро и помогает встать.
-- CFG.HERO_MODE = "none": героя нет совсем, клинок поднимается сам (путь меча и камеры другие).
local V3 = Vector3.new
local HERO_ON = (CFG.HERO_MODE ~= "none")
-- положение сцены в мире: берём из маркера клинка (построитель ставит всё от ORIGIN)
local floorMarker = camFolder:FindFirstChild("BladeFloor")
local OR = floorMarker and (floorMarker.Position - V3(4, 0.55, -108)) or V3(0, 0, 0)
local P0 = V3(4, 0.55, -108)                          -- середина рукояти клинка, пока он лежит на полу

local K = 1.4                                         -- обычная R15-фигурка (5,3 стада) в 1,4 раза крупнее: так лучше читается с камеры
local HEADS = 1.2 * K
local UTS, LTS = V3(2.0, 1.6, 1.0) * K, V3(2.0, 0.4, 1.0) * K
local LW = 1.0 * K                                    -- толщина рук и ног
local UA, LA, UL, LL = 1.05 * K, 0.9 * K, 0.95 * K, 0.8 * K
local FOOTH, FOOTL = 0.3 * K, 1.0 * K
local HANDL, NECK = 0.5 * K, 0.04 * K              -- кисть; зазор между головой и торсом (как у обычной фигурки — почти вплотную)
local HX = 3.4                                        -- герой стоит чуть левее оси зала: левая рука достаёт до рукояти

local hp = {}
-- Скин героя (визуальный слой поверх костей): заполнится клоном аватара зрителя,
-- если HERO_SKIN и персонаж уже заспавнился. Заполняется лениво из updateHero.
local skinBones, skinAcc, skinHidden = {}, {}, {}
local skinOn, skinTries = false, 0
local skinModel = Instance.new("Model")
skinModel.Name = "HeroSkin"
local buildHeroSkin, syncHeroSkin = nil, nil -- присваиваются в блоке героя, вызываются из updateHero
local eyeLight, heroKey, heroRim, heroFill
if HERO_ON then   -- палитра и детали героя: в отдельном блоке, чтобы не расходовать лимит локальных переменных Luau (200)
	local old = stage:FindFirstChild("Hero")
	if old then old:Destroy() end
	local heroModel = Instance.new("Model")
	heroModel.Name = "Hero"
	heroModel.Parent = stage

	-- «чёрный пластик» с холодным отливом: в синей сцене он читается тёмным, но с объёмом (у чистого чёрного формы не видно)
	local BODY = Color3.fromRGB(46, 52, 76)
	local LIMB = Color3.fromRGB(40, 45, 66)
	local DARK = Color3.fromRGB(30, 34, 50)
	local EYEC = CFG.HERO_EYE_COLOR or Color3.fromRGB(255, 45, 40)
	local function P(name, size, color, glow)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = not glow
		p.Material = glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
		p.Color = color
		p.Size = size
		p.Transparency = 1
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = heroModel
		hp[name] = p
		return p
	end
	P("LowerTorso", LTS, DARK)
	P("UpperTorso", UTS, BODY)
	-- голова — простой куб, лицо — гладкая чёрная пустота
	P("Head", V3(HEADS, HEADS, HEADS), DARK)
	-- глаза: два светящихся блока и белое «ядро» в каждом
	local core = EYEC:Lerp(Color3.new(1, 1, 1), 0.72)
	P("EyeL", V3(0.24 * K, 0.03 * K, 0.06 * K), EYEC, true)
	P("EyeR", V3(0.24 * K, 0.03 * K, 0.06 * K), EYEC, true)
	P("EyeLC", V3(0.11 * K, 0.02 * K, 0.07 * K), core, true)
	P("EyeRC", V3(0.11 * K, 0.02 * K, 0.07 * K), core, true)
	for _, s in ipairs({ "L", "R" }) do
		P("UpperArm" .. s, V3(LW, LW, UA), LIMB)
		P("LowerArm" .. s, V3(LW, LW, LA), LIMB)
		P("Fist" .. s, V3(LW * 0.92, LW * 0.92, HANDL), DARK)
		P("Shoulder" .. s, V3(LW, LW, LW), LIMB)
		P("Elbow" .. s, V3(LW * 0.98, LW * 0.98, LW * 0.98), LIMB)
		P("UpperLeg" .. s, V3(LW, LW, UL), LIMB)
		P("LowerLeg" .. s, V3(LW, LW, LL), LIMB)
		P("Knee" .. s, V3(LW * 0.98, LW * 0.98, LW * 0.98), LIMB)
		P("Foot" .. s, V3(LW, FOOTH, FOOTL), DARK)
	end
	-- свет: глаза подсвечивают лицо и руку с мечом
	eyeLight = Instance.new("PointLight")
	eyeLight.Color = EYEC
	eyeLight.Brightness = 0
	eyeLight.Range = 8
	eyeLight.Parent = hp.EyeL
	-- «студийный» свет на героя: мягкий холодный ключ со стороны камеры и фиолетовый контровой сзади.
	-- Тело само не светится, форма читается за счёт этих двух ламп.
	local function heroLamp(name, pos, color, range)
		local lp = Instance.new("Part")
		lp.Name = name
		lp.Anchored = true
		lp.CanCollide, lp.CanQuery, lp.CanTouch, lp.CastShadow = false, false, false, false
		lp.Transparency = 1
		lp.Size = V3(0.2, 0.2, 0.2)
		lp.Position = pos
		lp.Parent = heroModel
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = 0
		l.Shadows = false
		l.Parent = lp
		return l
	end
	heroKey = heroLamp("KeyLamp", OR + V3(0.5, 8.5, -104), Color3.fromRGB(153, 209, 255), 14)
	heroRim = heroLamp("RimLamp", OR + V3(8, 7, -117), Color3.fromRGB(178, 128, 255), 14)
	heroFill = heroLamp("FillLamp", OR + V3(10.5, 3.2, -103.5), Color3.fromRGB(90, 190, 255), 16)

	-- ===== СКИН ГЕРОЯ: аватар зрителя на костях фигурки =====
	-- Визуальная замена без правки хореографии: каждый сегмент тела персонажа
	-- жёстко следует за своей костью (UpperArm — за плечевой и т.д.), поэтому
	-- наклон корпуса, повороты головы и IK рук работают как у чёрной фигурки.
	-- Размеры мешей подгоняются под кость: у торса/головы/стоп оси совпадают
	-- (Y вверх, перед по Z), у костей-«стрел» (boneCF) длина по Z — ремап в Y меша.
	local SKIN_PIECES = {
		-- axis — ось кости, по которой тянем меш (равномерный масштаб: пропорции
		-- аватара сохраняются, длина сегмента совпадает с костью);
		-- face — как ориентировать меш: front (торс/голова: перед аватара -Z
		-- смотрит в перед фигурки +Z), foot (стопа: перед совпадает), arrow
		-- (кость-стрела: +Z кости = вверх сегмента, перед = перед торса)
		{ bone = "UpperTorso", part = "UpperTorso", axis = "Y", face = "front" },
		{ bone = "LowerTorso", part = "LowerTorso", axis = "Y", face = "front" },
		{ bone = "Head", part = "Head", axis = "Y", face = "front" },
		{ bone = "UpperArmL", part = "LeftUpperArm", axis = "Z" },
		{ bone = "LowerArmL", part = "LeftLowerArm", axis = "Z" },
		{ bone = "FistL", part = "LeftHand", axis = "Z" },
		{ bone = "UpperArmR", part = "RightUpperArm", axis = "Z" },
		{ bone = "LowerArmR", part = "RightLowerArm", axis = "Z" },
		{ bone = "FistR", part = "RightHand", axis = "Z" },
		{ bone = "UpperLegL", part = "LeftUpperLeg", axis = "Z" },
		{ bone = "LowerLegL", part = "LeftLowerLeg", axis = "Z" },
		{ bone = "FootL", part = "LeftFoot", axis = "Z", face = "foot" },
		{ bone = "UpperLegR", part = "RightUpperLeg", axis = "Z" },
		{ bone = "LowerLegR", part = "RightLowerLeg", axis = "Z" },
		{ bone = "FootR", part = "RightFoot", axis = "Z", face = "foot" },
	}
	local BONE_OF_PART = {
		UpperTorso = "UpperTorso", LowerTorso = "LowerTorso", Head = "Head",
	}
	local function prepSkinPart(p)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Transparency = 1
	end

	buildHeroSkin = function()
		if not CFG.HERO_SKIN or skinOn then
			return skinOn
		end
		local char = player.Character
		if not (char and char.Parent and char:FindFirstChild("UpperTorso")) then
			return false -- ещё не заспавнился или R6 — остаётся чёрная фигурка
		end
		-- у живых персонажей Archivable=false: без этого Clone() вернёт nil
		char.Archivable = true
		local clone = char:Clone()
		char.Archivable = false
		if not clone then
			return false
		end
		clone.Name = "HeroSkin"
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BaseScript") or d:IsA("Highlight") or d:IsA("ParticleEmitter")
				or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Light") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.CastShadow = true
			end
		end
		local hum = clone:FindFirstChildOfClass("Humanoid")
		if hum then
			-- Humanoid оставляем (на нём держится рендер одежды), но переносим в
			-- скин-модель: он не должен остаться в клоне, который уничтожим ниже.
			hum.PlatformStand = true
			hum.EvaluateStateMachine = false
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			hum.Parent = skinModel
		end
		local headSrc = clone:FindFirstChild("Head")
		local headNaturalY = headSrc and headSrc.Size.Y or 1

		for _, pc in ipairs(SKIN_PIECES) do
			local srcPart = clone:FindFirstChild(pc.part)
			local bone = hp[pc.bone]
			if srcPart and bone then
				prepSkinPart(srcPart)
				-- равномерный масштаб по главной оси кости: сегмент совпадает с
				-- костью длиной, но не превращается в глыбу с чужими пропорциями
				local nat = srcPart.Size
				local s = 1
				if pc.axis == "Y" then
					s = bone.Size.Y / math.max(nat.Y, 0.01)
				elseif pc.axis == "Z" then
					s = bone.Size.Z / math.max(nat.Z, 0.01)
				end
				srcPart.Size = nat * s
				srcPart.Parent = skinModel
				skinBones[pc.bone] = { part = srcPart, face = pc.face or "arrow" }
				skinHidden[pc.bone] = true
			end
		end
		-- Аксессуары (шляпа, волосы, очки): жёстко поверх своей кости, масштаб — от головы.
		local headScale = (skinBones.Head and hp.Head.Size.Y / headNaturalY) or 1
		for _, acc in ipairs(clone:GetChildren()) do
			if acc:IsA("Accessory") then
				local handle = acc:FindFirstChild("Handle")
				local weld = handle and (handle:FindFirstChild("AccessoryWeld") or handle:FindFirstChildOfClass("Weld") or handle:FindFirstChildOfClass("WeldConstraint"))
				local boneName = weld and weld.Part1 and BONE_OF_PART[weld.Part1.Name]
				if handle and boneName and skinBones[boneName] then
					-- смещение из покоя сварки (C0/C1), чтобы не запечь текущую
					-- idle-позу живого персонажа; WeldConstraint — как есть
					local rel
					if weld:IsA("Weld") and weld.Part0 == handle then
						rel = weld.C1 * weld.C0:Inverse()
					else
						rel = weld.Part1.CFrame:ToObjectSpace(handle.CFrame)
					end
					prepSkinPart(handle)
					handle.Size = handle.Size * headScale
					weld:Destroy() -- части на якоре, ведём хендл вручную
					acc.Parent = skinModel
					table.insert(skinAcc, { handle = handle, bone = boneName, rel = rel })
				else
					acc:Destroy()
				end
			end
		end
		local rootPart = clone:FindFirstChild("HumanoidRootPart")
		if rootPart then
			-- Humanoid жив (рендер одежды) — его корень должен существовать
			prepSkinPart(rootPart)
			rootPart.Transparency = 1
			rootPart.Parent = skinModel
		end
		clone:Destroy()
		-- кубы-суставы под скином не нужны: их закрывают меши аватара
		for _, n in ipairs({ "ShoulderL", "ShoulderR", "ElbowL", "ElbowR", "KneeL", "KneeR" }) do
			if hp[n] then skinHidden[n] = true end
		end
		skinModel.Parent = heroModel
		skinOn = skinBones.UpperTorso ~= nil
		return skinOn
	end

	-- Кадр скина: кость задаёт позицию и (для стрел) ось сегмента, «перед» берём
	-- от торса — локти/колени всегда смотрят туда, куда повёрнуто тело.
	syncHeroSkin = function(vis)
		if not skinOn then
			return
		end
		local front = hp.UpperTorso and hp.UpperTorso.CFrame.ZVector or V3(0, 0, 1)
		for boneName, sk in pairs(skinBones) do
			local bone = hp[boneName]
			if bone then
				if sk.face == "front" then
					-- торс/голова: перед аватара (-Z) смотрит в перед фигурки (+Z)
					sk.part.CFrame = bone.CFrame * CFrame.Angles(0, math.pi, 0)
				elseif sk.face == "foot" then
					-- стопа: перед аватара и так по -Z, кадр кости совпадает
					sk.part.CFrame = bone.CFrame
				else
					-- кость-стрела: boneCF ориентирует -Z к нижнему суставу, значит
					-- +Z кости = «вверх сегмента» = +Y меша; перед меша = перед торса
					local up = bone.CFrame.ZVector
					local back = -front - up * (-front):Dot(up)
					if back.Magnitude < 1e-3 then
						back = up:Cross(V3(1, 0, 0))
					end
					back = back.Unit
					sk.part.CFrame = CFrame.fromMatrix(bone.Position, up:Cross(back), up, back)
				end
				sk.part.Transparency = math.clamp(1 - vis, 0, 1)
			end
		end
		for _, a in ipairs(skinAcc) do
			local sk = skinBones[a.bone]
			if sk then
				a.handle.CFrame = sk.part.CFrame * a.rel
				a.handle.Transparency = math.clamp(1 - vis, 0, 1)
			end
		end
	end
end

-- параметры, которые двигает таймлайн
local H = { vis = 0, eyes = 0 }
local Htw = {}
local function ease(f) return f * f * (3 - 2 * f) end
local function tweenH(key, to, dur, delay)
	Htw[key] = { from = H[key], to = to, t0 = os.clock() + (delay or 0), dur = math.max(dur, 0.01) }
end
local function stepH()
	local t = os.clock()
	for k, tw in pairs(Htw) do
		local f = (t - tw.t0) / tw.dur
		if f >= 1 then
			H[k] = tw.to
			Htw[k] = nil
		elseif f >= 0 then
			H[k] = tw.from + (tw.to - tw.from) * ease(f)
		end
	end
end

-- кость от a до b: длинная ось детали вдоль кости; at — если нужно поставить деталь не в середину (кубик сустава)
local function boneCF(a, b, at)
	local d = b - a
	local m = d.Magnitude
	local c = at or (a + b) / 2
	if m < 1e-4 then return CFrame.new(c) end
	local dir = d / m
	if math.abs(dir.Y) > 0.995 then
		return CFrame.new(c) * CFrame.Angles(dir.Y > 0 and math.pi / 2 or -math.pi / 2, 0, 0)
	end
	return CFrame.lookAt(c, c + dir)
end
-- двухкостный IK; pole — направление, куда «смотрит» сустав (колено/локоть)
local function ik(root, target, l1, l2, pole)
	local d = target - root
	local dist = math.max(0.05, math.min(d.Magnitude, l1 + l2 - 0.02))
	local dir = d.Unit
	local pp = pole - dir * pole:Dot(dir)
	if pp.Magnitude < 1e-3 then pp = V3(0, 0, 1) - dir * dir.Z end
	pp = pp.Unit
	local a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
	local h = math.sqrt(math.max(l1 * l1 - a * a, 0))
	return root + dir * a + pp * h, root + dir * dist, (d.Magnitude - dist)
end
local function rotOnly(cf, v) return cf * v - cf.Position end
local function setP(name, cf) hp[name].CFrame = cf end

-- Плавные каналы по ключам (кубический Эрмит): время в секундах от появления героя
local function chan(keys)
	local n = #keys
	local tang = {}
	for i = 1, n do
		if i == 1 or i == n then
			tang[i] = keys[i][2] * 0
		else
			tang[i] = (keys[i + 1][2] - keys[i - 1][2]) * (0.85 / (keys[i + 1][1] - keys[i - 1][1]))
		end
	end
	return function(t)
		if t <= keys[1][1] then return keys[1][2] end
		if t >= keys[n][1] then return keys[n][2] end
		local i = 1
		while keys[i + 1][1] <= t do i = i + 1 end
		local t0, t1 = keys[i][1], keys[i + 1][1]
		local dt = t1 - t0
		local s = (t - t0) / dt
		local s2, s3 = s * s, s * s * s
		return keys[i][2] * (2 * s3 - 3 * s2 + 1) + tang[i] * (dt * (s3 - 2 * s2 + s))
			+ keys[i + 1][2] * (-2 * s3 + 3 * s2) + tang[i + 1] * (dt * (s3 - s2))
	end
end

-- ХОРЕОГРАФИЯ (tr = секунды после появления героя; tr 0 = 26:00 ролика). Координаты — от начала сцены.
-- Герой стоит на ЛЕВОМ колене (левая нога сзади), правая нога упирается стопой. Левая рука берёт меч у навершия.
local centerM = pt("BladeCenter")
local cP = centerM and (centerM.Position - OR) or V3(4, 9.6, -107.8)
local C = {}
C.pelvis = chan({
	{ 0, V3(HX, 2.03, -109.9) }, { 2.0, V3(HX, 2.03, -109.9) }, { 2.8, V3(HX, 2.03, -109.9) },
	{ 3.5, V3(HX, 2.2, -110.1) }, { 4.2, V3(HX, 2.5, -110.4) }, { 5.0, V3(HX, 2.78, -110.55) },
	{ 5.6, V3(HX, 2.82, -110.55) }, { 9, V3(HX, 2.82, -110.55) } })
C.pitch = chan({ { 0, 0.28 }, { 1.0, 0.34 }, { 2.0, 1.05 }, { 2.5, 1.1 }, { 2.9, 1.1 }, { 3.5, 0.8 }, { 4.2, 0.42 },
	{ 5.0, 0.1 }, { 5.8, 0.04 }, { 9, 0.04 } })
C.twist = chan({ { 0, 0 }, { 1.8, 0.1 }, { 3.0, 0.14 }, { 4.6, 0.04 }, { 5.6, -0.08 }, { 7.0, -0.08 }, { 8.5, 0 } })
C.roll = chan({ { 0, 0 }, { 1.0, 0 }, { 2.0, -0.28 }, { 2.9, -0.3 }, { 3.6, -0.18 }, { 4.6, 0 }, { 5.6, -0.07 }, { 7.0, -0.07 }, { 8.5, 0 } })
C.headPitch = chan({ { 0, 0.78 }, { 0.8, 0.72 }, { 1.3, 0.42 }, { 2.0, 0.95 }, { 2.9, 1.0 }, { 3.5, 0.55 }, { 4.4, 0.28 },
	{ 5.6, 0.08 }, { 6.6, -0.04 }, { 7.0, -0.04 }, { 8.2, -0.3 }, { 9, -0.3 } })
C.headYaw = chan({ { 0, 0 }, { 1.0, 0.18 }, { 1.4, 0.0 }, { 4.5, 0.0 }, { 6.0, -0.14 }, { 7.0, -0.1 }, { 8.2, 0 } })
-- стопы (центр лодыжки): правая стоит, левая лежит голенью на полу и потом шагает вперёд
C.footR = chan({ { 0, V3(HX - 1.6, FOOTH, -110.2) }, { 3.6, V3(HX - 1.6, FOOTH, -110.2) }, { 5.0, V3(HX - 0.85, FOOTH, -110.8) }, { 9, V3(HX - 0.85, FOOTH, -110.8) } })
C.footL = chan({ { 0, V3(HX + 0.7, 0.72, -111.02) }, { 3.4, V3(HX + 0.7, 0.72, -111.02) }, { 4.1, V3(HX + 0.8, 1.5, -110.7) },
	{ 4.8, V3(HX + 0.85, FOOTH, -110.3) }, { 5.4, V3(HX + 0.85, FOOTH, -110.3) }, { 9, V3(HX + 0.85, FOOTH, -110.3) } })
C.kneeL = chan({ { 0, 1 }, { 3.4, 1 }, { 4.3, 0 }, { 9, 0 } })           -- 1 = левое колено на полу (полюс вниз)
C.wL = chan({ { 0, 0 }, { 0.9, 0 }, { 1.9, 1 }, { 7.0, 1 }, { 7.6, 0 }, { 9, 0 } })   -- левая рука на рукояти
C.stand = chan({ { 0, 0 }, { 3.6, 0 }, { 5.2, 1 }, { 9, 1 } })              -- 0 = правая ладонь на бедре, 1 = руки свободно висят
C.awe = chan({ { 0, 0 }, { 7.0, 0 }, { 8.4, 1 }, { 9, 1 } })                -- после отпускания руки чуть раскрываются
-- Меч. Крен вокруг оси клинка: 90 = лежит плашмя (широкой гранью вверх), 0 = широкая грань смотрит в камеру
C.bladePsi = chan({ { 0, 0 }, { 2.7, 0 }, { 3.2, 6 }, { 4.0, 38 }, { 4.9, 78 }, { 5.7, 96 }, { 7.0, 96 }, { 8.7, 90 }, { 9.5, 90 } })
C.bladeRoll = chan({ { 0, 90 }, { 2.7, 90 }, { 3.2, 82 }, { 4.0, 50 }, { 4.9, 12 }, { 5.7, 0 }, { 9.5, 0 } })
local function bladeRot(tr)
	return CFrame.Angles(0, 0, math.rad(90 - C.bladePsi(tr))) * CFrame.Angles(0, math.rad(C.bladeRoll(tr)), 0)
end
-- ладонь на рукояти (локальные координаты клинка): у навершия; чуть над рукоятью, пока клинок лежит,
-- и со стороны героя, когда стоит
local GY = -0.85
local function gripLocal(tr)
	local a = math.max(0, math.min(1, math.cos(math.rad(C.bladePsi(tr)))))
	local rr = math.rad(C.bladeRoll(tr))
	return V3(0.3 * a * math.cos(rr), GY, 0.3 * a * math.sin(rr) - 0.3 * (1 - a))
end
local RELEASE, ARRIVE = 7.0, 8.7                          -- рука отпускает меч; меч приходит в центр
if HERO_ON then
	-- путь ладони (от начала сцены); клинок считается от неё, поэтому хват не может «оторваться»
	local hand0 = P0 + bladeRot(0) * gripLocal(0)
	C.hand = chan({
		{ 2.7, hand0 }, { 3.3, V3(4.85, 1.25, -108.4) }, { 4.0, V3(5.25, 2.2, -108.9) },
		{ 4.9, V3(5.65, 3.1, -109.1) }, { 5.7, V3(5.8, 3.9, -109.0) }, { 9, V3(5.8, 3.9, -109.0) } })
else
	-- героя нет: клинок сам отрывается от пола, переворачивается остриём вверх и всплывает к центру
	C.bladeP = chan({
		{ 0, P0 }, { 2.0, P0 }, { 2.9, V3(4, 0.95, -108.1) }, { 3.9, V3(4.1, 2.0, -108.4) }, { 4.9, V3(4.3, 3.4, -108.5) },
		{ 5.9, V3(4.3, 5.2, -108.3) }, { 7.0, V3(4.1, 7.2, -108.0) }, { 8.0, cP }, { 9.5, cP } })
	C.bladePsi = chan({ { 0, 0 }, { 2.0, 0 }, { 2.9, 7 }, { 3.9, 35 }, { 4.9, 70 }, { 5.9, 92 }, { 7.0, 94 }, { 8.0, 90 }, { 9.5, 90 } })
	C.bladeRoll = chan({ { 0, 90 }, { 2.0, 90 }, { 2.9, 80 }, { 3.9, 45 }, { 4.9, 12 }, { 5.9, 0 }, { 9.5, 0 } })
	RELEASE, ARRIVE = 7.0, 8.0
end
local function heldPivot(tr)
	if tr < 2.7 then return P0 end
	return C.hand(tr) - bladeRot(tr) * gripLocal(tr)
end
local PIV7 = HERO_ON and heldPivot(RELEASE) or P0
local function bladeCFAt(tr)
	local pos, rot = nil, bladeRot(tr)
	if not HERO_ON then
		pos = C.bladeP(tr)
		-- без рук клинок парит: лёгкое покачивание и поворот вокруг оси
		local k = math.max(0, math.min(1, (tr - 5.0) / 1.5))
		local t = os.clock()
		pos = pos + V3(0, math.sin(t * 1.9) * 0.08 * k, 0)
		rot = rot * CFrame.Angles(0, math.sin(t * 1.1) * 0.16 * k, 0)
	elseif tr <= RELEASE then
		pos = heldPivot(tr)
	else
		local f = math.min(1, (tr - RELEASE) / (ARRIVE - RELEASE))
		pos = PIV7:Lerp(cP, f * f * (3 - 2 * f))
	end
	return CFrame.new(OR + pos) * rot
end

local heroT0 = nil
-- деталь, которая по наклону ушла ниже пола, поднимаем до пола
local function groundClamp(name)
	local p = hp[name]
	local cf, sz = p.CFrame, p.Size
	local ext = 0.5 * (math.abs(cf.RightVector.Y) * sz.X + math.abs(cf.UpVector.Y) * sz.Y + math.abs(cf.LookVector.Y) * sz.Z)
	local lo = cf.Position.Y - ext - (OR.Y + 0.02)
	if lo < 0 then p.CFrame = CFrame.new(0, -lo, 0) * cf end
end
local DEBUG = rawget(_G, "HERO_DEBUG")
local function hideHero()
	H.vis = 0
	Htw.vis = nil
end
function updateHero()
	stepH()
	local t = os.clock()
	local tr = heroT0 and (t - heroT0) or 0
	-- меч ведёт хореография; руки героя подстраиваются под него (в режиме «none» рук нет: клинок летит сам)
	if heroT0 and blade then blade:PivotTo(bladeCFAt(tr)) end
	if not HERO_ON then return end
	-- скин строится лениво: к моменту проявления героя персонаж зрителя уже заспавнен
	if not skinOn and skinTries < 600 then
		skinTries += 1
		if buildHeroSkin() then
			skinOn = true
		end
	end
	if H.vis <= 0.001 then
		for _, p in pairs(hp) do p.Transparency = 1 end
		if syncHeroSkin then syncHeroSkin(0) end
		return
	end
	local vis = H.vis
	local breathe = math.sin(t * 1.55)
	local function c01(v) return math.max(0, math.min(1, v)) end

	-- таз, позвоночник, голова
	local hipC = C.pelvis(tr) + V3(0, breathe * 0.012, 0) + OR
	local pitch = C.pitch(tr) + breathe * 0.01
	local pelvisRot = CFrame.Angles(pitch * 0.3, C.twist(tr) * -0.3, 0)
	local ltCF = CFrame.new(hipC) * pelvisRot * CFrame.new(0, LTS.Y / 2, 0)
	local waist = ltCF * V3(0, LTS.Y / 2, 0)
	local spine = CFrame.Angles(pitch * 0.7, C.twist(tr), C.roll(tr))
	local utCF = CFrame.new(waist) * pelvisRot * spine * CFrame.new(0, UTS.Y / 2, 0)
	local neck = utCF * V3(0, UTS.Y / 2, 0)
	local hAng = CFrame.Angles(C.headPitch(tr), C.headYaw(tr), 0)
	local headCF = CFrame.new(neck) * hAng * CFrame.new(0, NECK + HEADS / 2, 0)
	setP("LowerTorso", ltCF)
	setP("UpperTorso", utCF)
	setP("Head", headCF)
	-- глаза: открываются по вертикали, у зрачка белое ядро
	local open = H.eyes
	local eh = 0.03 * K + 0.31 * K * open
	-- со скином глаза вспыхивают поверх лица аватара: чуть выдвигаем из-под меша головы
	local ex, ey, ez = 0.27 * HEADS, 0.08 * HEADS, HEADS / 2 + 0.005 + (skinOn and 0.09 or 0)
	hp.EyeL.Size = V3(0.24 * K, eh, 0.06 * K)
	hp.EyeR.Size = V3(0.24 * K, eh, 0.06 * K)
	hp.EyeLC.Size = V3(0.11 * K, math.max(0.02, eh * 0.62), 0.07 * K)
	hp.EyeRC.Size = V3(0.11 * K, math.max(0.02, eh * 0.62), 0.07 * K)
	setP("EyeL", headCF * CFrame.new(ex, ey, ez))
	setP("EyeR", headCF * CFrame.new(-ex, ey, ez))
	setP("EyeLC", headCF * CFrame.new(ex, ey, ez + 0.012))
	setP("EyeRC", headCF * CFrame.new(-ex, ey, ez + 0.012))

	-- ноги: левая на колене сзади (голень лежит на полу), правая упирается стопой
	local hips = { L = ltCF * V3(0.5 * K, -LTS.Y / 2, 0), R = ltCF * V3(-0.5 * K, -LTS.Y / 2, 0) }
	local kn = c01(C.kneeL(tr))
	local ankles = { L = OR + C.footL(tr), R = OR + C.footR(tr) }
	for _, s in ipairs({ "L", "R" }) do
		local a = ankles[s]
		ankles[s] = V3(a.X, math.max(a.Y, OR.Y + FOOTH + 0.01), a.Z)
	end
	local poles = {
		R = V3(-0.45, -0.15, 1),
		L = V3(0, -1, 0.05):Lerp(V3(0.2, -0.1, 1), 1 - kn),
	}
	local kneePos, ankPos = {}, {}
	for _, s in ipairs({ "L", "R" }) do
		local knee, ank = ik(hips[s], ankles[s], UL, LL, poles[s])
		kneePos[s], ankPos[s] = knee, ank
		setP("UpperLeg" .. s, boneCF(hips[s], knee))
		setP("LowerLeg" .. s, boneCF(knee, ank))
		setP("Knee" .. s, boneCF(hips[s], knee, knee))
		local fd = V3(0, 0, 1)
		if s == "L" then
			-- стопа в воздухе разворачивается носком назад -> наружу -> вперёд (без скачка направления)
			local th = math.pi * (1 - kn)
			fd = V3(math.sin(th), 0, -math.cos(th))
		else
			fd = V3(-0.18, 0, 1).Unit
		end
		fd = V3(fd.X, 0, fd.Z)
		fd = fd.Magnitude > 0.05 and fd.Unit or V3(0, 0, 1)
		local fc = V3(ank.X, ank.Y - FOOTH / 2, ank.Z) + fd * (0.3 * K)
		setP("Foot" .. s, CFrame.lookAt(fc, fc + fd))
		groundClamp("Foot" .. s)
		groundClamp("LowerLeg" .. s)
		groundClamp("Knee" .. s)
	end

	-- руки: левая тянется к рукояти и держит меч, правая лежит на бедре и потом свободно висит
	local bladeCF = blade and blade:GetPivot() or (CFrame.new(OR + P0) * bladeRot(0))
	local sh = { L = utCF * V3(1.5 * K, UTS.Y / 2 - LW / 2, 0), R = utCF * V3(-1.5 * K, UTS.Y / 2 - LW / 2, 0) }
	local stand, awe = c01(C.stand(tr)), c01(C.awe(tr))
	local w = c01(C.wL(tr))
	local gripErr = 0
	for _, s in ipairs({ "L", "R" }) do
		local sg = (s == "L") and 1 or -1
		local hang = sh[s] + V3(0.25 * sg, -(UA + LA) * 0.9, 0.35)
		local wide = sh[s] + V3(0.95 * sg, -(UA + LA) * 0.7, 0.85)
		local rest = hang
		if s == "R" then rest = (kneePos.R + hips.R) / 2 + V3(0, LW * 0.5 + 0.3 * K, 0) end
		local free = rest:Lerp(hang, stand):Lerp(wide, awe)
		local target = free
		local grip
		if s == "L" then
			grip = bladeCF * gripLocal(tr)
			local arc = math.sin(math.pi * w) * 0.7
			target = free:Lerp(grip, w) + V3(0, arc, -arc * 0.35)
		end
		local pole = rotOnly(utCF, V3(0.75 * sg, -0.7, -0.55))
		local elbow, hand = ik(sh[s], target, UA, LA, pole)
		if grip and w > 0.99 then
			local e = (hand - grip).Magnitude
			gripErr = math.max(gripErr, e)
			if DEBUG then
				DEBUG.log = DEBUG.log or {}
				local key = s .. string.format("%.1f", math.floor(tr * 2) / 2)
				DEBUG.log[key] = math.max(DEBUG.log[key] or 0, e)
				if e > (DEBUG.worst or 0) then DEBUG.worst, DEBUG.worstAt = e, s .. string.format(" tr=%.2f", tr) end
			end
		end
		setP("Shoulder" .. s, utCF * CFrame.new(1.5 * K * sg, UTS.Y / 2 - LW / 2, 0))
		setP("UpperArm" .. s, boneCF(sh[s], elbow))
		setP("Elbow" .. s, boneCF(sh[s], elbow, elbow))
		setP("LowerArm" .. s, boneCF(elbow, hand))
		setP("Fist" .. s, boneCF(elbow, hand, hand))
	end

	-- проявление: при сборке из кубиков тело проступает из прозрачности, глаза горят только когда открыты
	for name, p in pairs(hp) do
		if name == "EyeL" or name == "EyeR" or name == "EyeLC" or name == "EyeRC" then
			p.Transparency = (open <= 0.01) and 1 or (1 - math.min(1, vis * open * 2))
		elseif skinHidden[name] then
			p.Transparency = 1 -- под мешами аватара кости не видны
		else
			p.Transparency = 1 - vis
		end
	end
	syncHeroSkin(vis)
	eyeLight.Brightness = open * 0.9
	-- пока герой на колене и встаёт (tr < ~6), света больше — чтобы читалось, что он делает; к крупному плану глаз — темнее
	local lift = 1 - c01((tr - 4.2) / 2.2)
	heroKey.Brightness = (1.6 + 0.9 * lift) * vis
	heroFill.Brightness = 1.4 * lift * vis
	heroRim.Brightness = 1.4 * vis
	if DEBUG then
		DEBUG.tr, DEBUG.gripErr = tr, math.max(DEBUG.gripErr or 0, gripErr)
	end
end
local function syncArm() updateHero() end
local function revealHero(dur)
	if HERO_ON then tweenH("vis", 1, dur or 0.7) end
	heroT0 = heroT0 or os.clock()
end
local function openEyes()
	if HERO_ON then tweenH("eyes", 1, 2.2) end
end


---------------------------------------------------------------- ДУШИ → ПУСТОЙ КЛИНОК
-- Что должен понять зритель: клинок на полу пуст; чужая память в стеклянном клинке гниёт (мерцает, сереет),
-- затем силуэт рассыпается на кубики, они сверху вниз по дугам летят в пустой клинок, и клинок
-- заполняется светом от гарды к острию. Дальше свет остаётся в клинке и будит героя.
local doomed = blades and blades:FindFirstChild("DoomedBlade")
local BLADE_FROM, BLADE_LEN = 1.75, 3.5     -- лезвие пустого клинка по локальной оси Y: от гарды до острия
local fillAmt, fillShown, fillFlash = 0, 0, 0
local boostTarget, boost = 1, 1
local fillPart, fillCore
local haloA, haloB                                -- мягкое сияние вокруг полного клинка: он должен читаться издалека в финальном кадре
local haloTarget, haloK = 0, 0
if blade then
	haloA = Instance.new("Part")
	haloA.Name = "BladeHaloA"
	haloA.Anchored, haloA.CanCollide, haloA.CanQuery, haloA.CanTouch, haloA.CastShadow = true, false, false, false, false
	haloA.Material = Enum.Material.Neon
	haloA.Color = Color3.fromRGB(111, 227, 255)
	haloA.Size = V3(0.95, BLADE_LEN + 1.2, 0.95)
	haloA.Transparency = 1
	haloA.Parent = blade
	haloB = haloA:Clone()
	haloB.Name = "BladeHaloB"
	haloB.Size = V3(1.9, BLADE_LEN + 2.6, 1.9)
	haloB.Parent = blade
	fillPart = Instance.new("Part")
	fillPart.Name = "BladeFill"
	fillPart.Anchored, fillPart.CanCollide, fillPart.CanQuery, fillPart.CanTouch, fillPart.CastShadow = true, false, false, false, false
	fillPart.Material = Enum.Material.Neon
	fillPart.Color = Color3.fromRGB(111, 227, 255)
	fillPart.Size = V3(0.34, 0.1, 0.26)
	fillPart.Transparency = 1
	fillPart.Parent = blade
	fillCore = fillPart:Clone()
	fillCore.Name = "BladeFillCore"
	fillCore.Color = Color3.fromRGB(235, 252, 255)
	fillCore.Parent = blade
end
function updateFill()
	if not (fillPart and blade) then return end
	fillShown = fillShown + (fillAmt - fillShown) * 0.12
	fillFlash = fillFlash * 0.9
	boost = boost + (boostTarget - boost) * 0.05
	humGain = humGain + (humTarget - humGain) * 0.06
	if hum and hum.IsPlaying then
		local f = math.min(fillShown, 1)
		hum.PlaybackSpeed = 0.8 + 0.5 * f + 0.06 * (boost - 1)
		hum.Volume = CFG.SOUNDS.BladeHum.volume * humGain * (0.3 + 0.7 * f) * (1 + 0.25 * (boost - 1))
	end
	if fillShown < 0.01 then return end
	local L = math.max(0.05, BLADE_LEN * math.min(fillShown, 1))
	local cf = blade:GetPivot() * CFrame.new(0, BLADE_FROM + L / 2, 0)
	fillPart.Size = V3(0.34, L, 0.26)
	fillPart.CFrame = cf
	fillPart.Transparency = 0.2
	fillCore.Size = V3(0.14, L, 0.28)
	fillCore.CFrame = cf
	fillCore.Transparency = math.max(0, 0.15 - fillFlash * 0.15)
	local g = blade:FindFirstChild("BladeGlow")
	if g then
		g.Transparency = math.max(0.05, 0.7 - 0.45 * fillShown - 0.25 * fillFlash)
		local l = g:FindFirstChildOfClass("PointLight")
		if l then l.Brightness = (0.3 + 2.2 * fillShown + 1.6 * fillFlash) * boost end
	end
	local gem = blade:FindFirstChild("PommelGem")
	if gem then gem.Color = Color3.fromRGB(26, 62, 86):Lerp(Color3.fromRGB(150, 240, 255), math.min(1, fillShown)) end
	haloK = haloK + (haloTarget - haloK) * 0.04
	if haloA and haloK > 0.02 then
		local hc = blade:GetPivot() * CFrame.new(0, BLADE_FROM + BLADE_LEN / 2 + 0.1, 0)
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 4.2)
		haloA.CFrame = hc
		haloB.CFrame = hc
		haloA.Transparency = 1 - haloK * (0.34 + 0.08 * pulse)
		haloB.Transparency = 1 - haloK * (0.10 + 0.04 * pulse)
	elseif haloA then
		haloA.Transparency, haloB.Transparency = 1, 1
	end
end

-- кубики-воксели из блоков модели (берём цвет детали)
local function voxelsOf(model, vsize, maxN)
	local list = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local sz = p.Size
			local nx = math.max(1, math.floor(sz.X / vsize + 0.5))
			local ny = math.max(1, math.floor(sz.Y / vsize + 0.5))
			local nz = math.max(1, math.floor(sz.Z / vsize + 0.5))
			for ix = 1, nx do
				for iy = 1, ny do
					for iz = 1, nz do
						local lp = V3((ix - 0.5) / nx * sz.X - sz.X / 2, (iy - 0.5) / ny * sz.Y - sz.Y / 2, (iz - 0.5) / nz * sz.Z - sz.Z / 2)
						table.insert(list, { pos = p.CFrame * lp, col = p.Color })
					end
				end
			end
		end
	end
	while #list > maxN do table.remove(list, math.random(#list)) end
	return list
end

-- общий поток кубиков по кривым Безье; следы затухают вручную (без тысяч твинов)
local function soulStream(items, onArrive)
	local t0 = os.clock()
	local trails = {}
	local live = #items
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if skipped then conn:Disconnect() return end
		local el = os.clock() - t0
		for _, p in ipairs(items) do
			if not p.done then
				local f0 = el - p.delay
				if f0 >= 0 then
					if not p.cube then p.cube = makeCube(p.size, p.S, p.col) end
					local pos, sc
					if f0 < p.hold then
						local k = f0 / p.hold
						local e = 1 - (1 - k) * (1 - k)
						pos = p.S:Lerp(p.P1, e)
						p.cube.Color = p.col:Lerp(PALETTE[1], k)
						sc = 1 + 0.6 * k
					else
						local f = (f0 - p.hold) / p.life
						if f >= 1 then
							p.cube:Destroy()
							p.cube = nil
							p.done = true
							live = live - 1
							if onArrive then onArrive(p) end
						else
							local e = f * f * (1.7 - 0.7 * f)
							local a = p.P1:Lerp(p.C, e)
							local b = p.C:Lerp(p.T, e)
							pos = a:Lerp(b, e)
							sc = 1.6 - 0.9 * f
							p.cube.Color = PALETTE[1]:Lerp(PALETTE[2], 0.3 + 0.7 * f)
							if p.trail and el - (p.lastTrail or -1) > 0.07 then
								p.lastTrail = el
								local tc = makeCube(p.size * 0.6, pos, PALETTE[2])
								table.insert(trails, { part = tc, born = el, size = p.size * 0.6 })
							end
						end
					end
					if p.cube then
						p.cube.CFrame = CFrame.new(pos) * CFrame.Angles(el * 3 + p.delay, el * 2, 0)
						p.cube.Size = Vector3.one * (p.size * sc)
					end
				end
			end
		end
		for i = #trails, 1, -1 do
			local tr = trails[i]
			local age = (el - tr.born) / 0.5
			if age >= 1 then
				tr.part:Destroy()
				table.remove(trails, i)
			else
				tr.part.Transparency = age
				tr.part.Size = Vector3.one * (tr.size * (1 - 0.6 * age))
			end
		end
		if live <= 0 and #trails == 0 then conn:Disconnect() end
	end)
end

local function impactSpark(pos)
	local c = makeCube(0.14 + math.random() * 0.12, pos, PALETTE[1])
	local v = V3(math.random(-10, 10) / 10, math.random(2, 12) / 10, math.random(-10, 10) / 10)
	TweenService:Create(c, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = pos + v, Transparency = 1 }):Play()
	Debris:AddItem(c, 0.5)
end

local ROT = Color3.fromRGB(150, 96, 196)
-- 1) память гниёт: глитч, сереющий силуэт, мигающий свет, голова разбухает
local function corrupt(dur)
	if not doomed then return end
	local sil = doomed:FindFirstChild("Silhouette")
	if not sil then return end
	local items = {}
	for _, o in ipairs(sil:GetDescendants()) do
		if o:IsA("BasePart") then table.insert(items, { p = o, cf = o.CFrame, size = o.Size, col = o.Color, tr = o.Transparency }) end
	end
	local body = doomed:FindFirstChild("Body")
	local bodyCol = body and body.Color
	local lt
	for _, o in ipairs(doomed:GetDescendants()) do if o:IsA("PointLight") then lt = o break end end
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local k = (os.clock() - t0) / dur
		if skipped or k >= 1 then
			for _, it in ipairs(items) do
				if it.p.Parent then it.p.CFrame = it.cf it.p.Size = it.size it.p.Color = ROT it.p.Transparency = it.tr end
			end
			if body then body.Color = Color3.fromRGB(60, 78, 140) end
			conn:Disconnect()
			return
		end
		for _, it in ipairs(items) do
			if math.random() < 0.3 then
				local j = k * k
				local sx = 1 + (math.random() - 0.5) * 0.6 * j
				local sy = 1 + (math.random() - 0.5) * 0.7 * j
				if it.p.Name == "Head" then sx, sy = sx + 0.5 * k, sy + 0.4 * k end
				it.p.CFrame = it.cf * CFrame.new((math.random() - 0.5) * 0.5 * j, (math.random() - 0.5) * 0.3 * j, 0)
				it.p.Size = V3(it.size.X * sx, it.size.Y * sy, it.size.Z)
			end
			it.p.Color = it.col:Lerp(ROT, k)
			it.p.Transparency = (math.random() < 0.25 * k) and 0.9 or it.tr
		end
		if body then body.Color = bodyCol:Lerp(Color3.fromRGB(60, 78, 140), k) end
		if lt then lt.Brightness = 3.5 * (1 - 0.7 * k) * (0.25 + 0.75 * math.random()) end
	end)
end

-- 2) силуэт рассыпается: воксели отрываются сверху вниз и летят в лезвие пустого клинка
local arrived, totalSouls = 0, 1
local function dissolveDoomed()
	if not (doomed and blade) then return end
	local sil = doomed:FindFirstChild("Silhouette")
	if not sil then return end
	local vox = voxelsOf(sil, 0.34, 190)
	for _, o in ipairs(sil:GetDescendants()) do
		if o:IsA("BasePart") then o.Transparency = 1 end
	end
	local body = doomed:FindFirstChild("Body")
	if body then TweenService:Create(body, TweenInfo.new(1.6), { Transparency = 0.92 }):Play() end
	for _, o in ipairs(doomed:GetDescendants()) do
		if o:IsA("PointLight") then TweenService:Create(o, TweenInfo.new(2.2), { Brightness = 0 }):Play() end
	end
	local minY, maxY = math.huge, -math.huge
	for _, v in ipairs(vox) do
		minY = math.min(minY, v.pos.Y)
		maxY = math.max(maxY, v.pos.Y)
	end
	for _, v in ipairs(vox) do
		v.delay = (maxY - v.pos.Y) / math.max(maxY - minY, 0.1) * 1.5 + math.random() * 0.25
	end
	table.sort(vox, function(a, b) return a.delay < b.delay end)
	local pivot = blade:GetPivot()
	local items = {}
	totalSouls = #vox
	arrived = 0
	for i, v in ipairs(vox) do
		local u = i / #vox
		local tgt = pivot * V3((math.random() - 0.5) * 0.3, BLADE_FROM + u * BLADE_LEN, (math.random() - 0.5) * 0.2)
		local P1 = v.pos + V3((math.random() - 0.5) * 1.0 + 0.2, 0.5 + math.random() * 0.9, (math.random() - 0.5) * 0.8)
		local C = (P1 + tgt) / 2 + V3((math.random() - 0.5) * 2.4, 2.0 + math.random() * 1.8, (math.random() - 0.5) * 2.0)
		table.insert(items, {
			S = v.pos, P1 = P1, C = C, T = tgt, delay = v.delay, hold = 0.35 + math.random() * 0.15,
			life = 1.05 + math.random() * 0.35, size = 0.2 + math.random() * 0.16, col = v.col,
			trail = (i % 3 == 0),
		})
	end
	play("Absorb")
	soulStream(items, function(p)
		arrived = arrived + 1
		fillAmt = arrived / totalSouls
		fillFlash = 1
		soulTick(fillAmt)
		if arrived % 2 == 0 then impactSpark(p.T) end
	end)
end

-- 3) кульминация наполнения: вспышка, кольцо кубиков по полу, дрожь клинка
local function shockwave(center, count, radius, dur)
	for i = 1, math.floor(count * DENS) do
		local a = i / count * math.pi * 2
		local c = makeCube(0.22 + math.random() * 0.12, center + V3(math.cos(a) * 0.6, 0, math.sin(a) * 0.6), PALETTE[(i % 2) + 1])
		TweenService:Create(c, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = center + V3(math.cos(a) * radius, 0.15 + math.random() * 0.4, math.sin(a) * radius), Transparency = 1 }):Play()
		Debris:AddItem(c, dur + 0.1)
	end
end
local shake = nil
function updateShake()
	if not (shake and blade) then return end
	local k = (os.clock() - shake.t0) / shake.dur
	if k >= 1 then
		blade:PivotTo(shake.base)
		shake = nil
		return
	end
	local d = (1 - k) * shake.amp
	blade:PivotTo(shake.base * CFrame.new((math.random() - 0.5) * d, (math.random() - 0.5) * d * 0.5, (math.random() - 0.5) * d)
		* CFrame.Angles(0, 0, (math.random() - 0.5) * 0.06 * (1 - k)))
end
local function shakeBlade(dur, amp)
	if blade then shake = { t0 = os.clock(), dur = dur, amp = amp, base = blade:GetPivot() } end
end
local function finishFill()
	fillAmt = 1
	fillFlash = 3
	if blade then shockwave(blade:GetPivot().Position + V3(-2.0, -0.2, 0), 48, 9, 0.9) end
	shakeBlade(0.7, 0.14)
end
-- герой «собирается» из кубиков, летящих от клинка к телу
local function materialize()
	if not blade then return end
	local from = blade:GetPivot().Position
	local items = {}
	local chest = OR + V3(3.4, 3.5, -109.6)
	for i = 1, math.floor(70 * DENS) do
		local S = from + V3((math.random() - 0.5) * 6, math.random() * 1.2, (math.random() - 0.5) * 1.5)
		local P1 = S + V3(0, 0.4 + math.random() * 0.6, 0)
		local T = chest + V3((math.random() - 0.5) * 2.2, (math.random() - 0.5) * 3.0, (math.random() - 0.5) * 1.2)
		table.insert(items, {
			S = S, P1 = P1, C = (P1 + T) / 2 + V3((math.random() - 0.5) * 2, 1.5, (math.random() - 0.5) * 2), T = T,
			delay = math.random() * 0.5, hold = 0.12, life = 0.6 + math.random() * 0.3,
			size = 0.16 + math.random() * 0.14, col = PALETTE[math.random(#PALETTE)], trail = (i % 4 == 0),
		})
	end
	soulStream(items, nil)
end
-- река душ: из носика Горнила огромной дугой к клинку героя
local function soulRiver(count, dur)
	if not (lipLamp and blade) then return end
	local items = {}
	local from = lipLamp.Position
	local center = blade:GetPivot().Position
	for i = 1, math.floor(count * DENS) do
		local S = from + V3((math.random() - 0.5) * 7, (math.random() - 0.5) * 3, 2 + math.random() * 3)
		local T = center + V3((math.random() - 0.5) * 0.5, (math.random() - 0.5) * 3.2, (math.random() - 0.5) * 0.5)
		local P1 = S + V3((math.random() - 0.5) * 3, 3 + math.random() * 4, 4 + math.random() * 4)
		table.insert(items, {
			S = S, P1 = P1, C = (P1 + T) / 2 + V3((math.random() - 0.5) * 14, 12 + math.random() * 12, (math.random() - 0.5) * 8), T = T,
			delay = math.random() * dur, hold = 0.25 + math.random() * 0.2, life = 2.0 + math.random() * 0.8,
			size = 0.25 + math.random() * 0.25, col = PALETTE[math.random(#PALETTE)], trail = (i % 2 == 0),
		})
	end
	play("Absorb", 0.5)
	soulStream(items, function(p)
		fillFlash = math.min(fillFlash + 0.05, 1.2)
		if math.random() < 0.3 then impactSpark(p.T) end
	end)
end

---------------------------------------------------------------- КАМЕРА
local swayAmount = 0.06
local oldFOV = camera.FieldOfView
local CAM_STEP = "IntroCutsceneCamera"

local camCC -- игровой CameraController, если есть: кадр фильма идёт через его setOverride
local function camPose(t)
	local sway = CFrame.new(math.sin(t * 0.9) * swayAmount, math.cos(t * 0.7) * swayAmount, 0)
		* CFrame.Angles(math.sin(t * 0.6) * 0.004, math.cos(t * 0.5) * 0.004, 0)
	return camValue.Value * sway
end
local function startCamera()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CFG.FOV
	-- приоритет выше стандартных камер Roblox (для записи ролика вне игры)
	RunService:BindToRenderStep(CAM_STEP, Enum.RenderPriority.Camera.Value + 1, function()
		camera.CFrame = camPose(os.clock())
	end)
	-- Внутри игры камеру каждый кадр ведёт CameraController и перебивает наш
	-- бинд: отдаём кадр фильма через его официальный хук setOverride.
	pcall(function()
		local Controllers = script.Parent:FindFirstChild("Controllers")
		local CC = Controllers and Controllers:FindFirstChild("CameraController")
		camCC = CC and require(CC)
		if camCC and camCC.setOverride then
			camCC.setOverride(function()
				return camPose(os.clock()), CFG.FOV
			end)
		end
	end)
end
local function stopCamera()
	pcall(function() RunService:UnbindFromRenderStep(CAM_STEP) end)
	pcall(function()
		if camCC and camCC.setOverride then
			camCC.setOverride(nil)
		end
	end)
end
local function cut(name)
	local p = pt(name)
	if p then camValue.Value = p.CFrame end
end
-- плавный полёт к точке bName; aName = nil значит «стартовать оттуда, где камера сейчас» (без скачка)
local function fly(aName, bName, dur, style)
	local b = pt(bName)
	if not b then return end
	if aName then
		local a = pt(aName)
		if a then camValue.Value = a.CFrame end
	end
	TweenService:Create(camValue, TweenInfo.new(dur, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = b.CFrame }):Play()
end

-- то же, но к произвольному кадру (CFrame) без маркера: для режима HERO_MODE = "none"
local function flyTo(cf, dur)
	TweenService:Create(camValue, TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = cf }):Play()
end

local function fade(toTransparency, dur)
	TweenService:Create(black, TweenInfo.new(dur), { BackgroundTransparency = toTransparency }):Play()
end

---------------------------------------------------------------- ИГРОК
local UserInputService = game:GetService("UserInputService")
local oldMouseIcon
local function lockPlayer()
	local hidden = {}
	for _, g in ipairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	-- Контроллеры создают свои ScreenGui уже после старта фильма (снимок выше
	-- их не застал): прячем и их, иначе HUD рисуется поверх кадра. Те, кто
	-- сам возвращает себе Enabled (прицел, HUD), гасим повторно до конца фильма.
	local watchers = {}
	local function suppress(g)
		table.insert(watchers, g:GetPropertyChangedSignal("Enabled"):Connect(function()
			if not finished and g.Enabled then
				g.Enabled = false
			end
		end))
	end
	local watchGuis = playerGui.ChildAdded:Connect(function(g)
		if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
			g.Enabled = false
			table.insert(hidden, g)
			suppress(g)
		end
	end)
	for _, g in ipairs(hidden) do
		suppress(g)
	end
	onCleanup(function()
		watchGuis:Disconnect()
		for _, w in ipairs(watchers) do w:Disconnect() end
		for _, g in ipairs(hidden) do g.Enabled = true end
	end)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
	onCleanup(function() pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end) end)
	-- курсор мыши в кадре трейлера не нужен: пустая иконка на время фильма
	pcall(function() oldMouseIcon = UserInputService.MouseIcon end)
	pcall(function() UserInputService.MouseIcon = "rbxasset://textures/blank.png" end)
	onCleanup(function() pcall(function() UserInputService.MouseIcon = oldMouseIcon or "" end) end)
	if ClientState then
		-- ввод игры стоит (бег, удары, рывки), курсор свободен — им нажимают «Пропустить»
		pcall(function() ClientState.lockInput("cursor", true) end)
		onCleanup(function() pcall(function() ClientState.lockInput("cursor", false) end) end)
	end

	-- PlayerModule есть не во всех сборках Studio (и не всегда успевает приехать):
	-- ждём с таймаутом, без него просто якорим персонажа ниже. БЕЗ таймаута
	-- WaitForChild виснет навсегда и ролик не стартует.
	local ok, controls = pcall(function()
		local scripts = player:WaitForChild("PlayerScripts", 5)
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if not module then return nil end
		return require(module):GetControls()
	end)
	if ok and controls then
		controls:Disable()
		onCleanup(function() controls:Enable() end)
	end
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		local was = hrp.Anchored
		hrp.Anchored = true
		onCleanup(function() if hrp.Parent then hrp.Anchored = was end end)
	end
end

---------------------------------------------------------------- ЗАГОЛОВОК
local function showTitle()
	local holder = Instance.new("Frame")
	holder.Name = "Title"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.45)
	holder.Size = UDim2.fromScale(0.8, 0.2)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 8
	holder.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = holder

	local letters = {}
	for _, cp in utf8.codes(CFG.TITLE_TEXT) do
		local ch = utf8.char(cp)
		local l = Instance.new("TextLabel")
		l.Name = "Letter"
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromOffset(ch == " " and 24 or 58, 90)
		l.FontFace = CFG.FONT_CYRILLIC
		l.Text = ch
		l.TextSize = 84
		l.TextColor3 = Color3.fromRGB(235, 252, 255)
		l.TextStrokeColor3 = Color3.fromRGB(8, 28, 60)
		l.TextStrokeTransparency = 0.1
		l.TextTransparency = 1
		l.ZIndex = 9
		l.Parent = holder
		table.insert(letters, l)
	end
	for _, l in ipairs(letters) do
		TweenService:Create(l, TweenInfo.new(0.9), { TextTransparency = 0 }):Play()
		task.wait(0.05)
	end
	task.delay(0.9, function()
		for _, l in ipairs(letters) do
			if l.Parent and l.Text ~= " " then
				for k = 1, 3 do
					local px = Instance.new("Frame")
					local s = math.random(4, 9)
					px.Size = UDim2.fromOffset(s, s)
					px.AnchorPoint = Vector2.new(0.5, 0.5)
					px.BackgroundColor3 = CFG.MEMORY_COLOR
					px.BorderSizePixel = 0
					px.ZIndex = 10
					px.Position = UDim2.new(0.5, math.random(-24, 24), 0.5, math.random(-38, 38))
					px.Parent = l
					TweenService:Create(px, TweenInfo.new(1.4 + math.random(), Enum.EasingStyle.Quad), {
						Position = px.Position + UDim2.fromOffset(math.random(-14, 14), math.random(50, 120)),
						BackgroundTransparency = 1 }):Play()
					Debris:AddItem(px, 2.6)
				end
			end
		end
	end)
end

---------------------------------------------------------------- ЗАВЕРШЕНИЕ
local function finish()
	if finished then return end
	finished = true
	player:SetAttribute("FilmPlaying", nil)
	ambientOn = false
	skipBtn.Active = false
	humTarget = 0
	fadeOutSounds(0.8)
	fade(0, 0.7)
	task.wait(0.8)
	if CFG.RECORD_MODE then
		-- держим чёрный кадр с названием: ролик записан
		return
	end
	stopCamera()
	animConn:Disconnect()
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = oldFOV
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then camera.CameraSubject = hum end
	for _, fn in ipairs(cleanup) do pcall(fn) end
	if stageCloned then stage:Destroy() end
	if camCloned then camFolder:Destroy() end
	fade(1, 0.8)
	task.wait(0.9)
	fxFolder:Destroy()
	runtime:Destroy()
	gui:Destroy()
end

skipBtn.MouseButton1Click:Connect(function()
	if skipBtn.Active then skipped = true end
end)

---------------------------------------------------------------- ГЛАВНАЯ ПОСЛЕДОВАТЕЛЬНОСТЬ
if not game:IsLoaded() then game.Loaded:Wait() end
lockPlayer()
setupLook()
startCamera()
cut("Shot1")
hideHero()
syncArm()

if CFG.RECORD_MODE then task.wait(2) end -- пауза перед стартом записи
T0 = os.clock()

if not CFG.RECORD_MODE then
	task.delay(CFG.SKIP_APPEARS_AT, function()
		if skipped or finished then return end
		skipBtn.Active = true
		TweenService:Create(skipBtn, TweenInfo.new(0.6), { BackgroundTransparency = 0.6, TextTransparency = 0.35 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.6), { Transparency = 0.5 }):Play()
	end)
end

for _, s in ipairs(SUBS) do
	task.spawn(function()
		if at(s.t + s.delay) then showSub(s.text, s.dur - s.delay) end
	end)
end

-- звук удара молота в 0:01, не задерживая остальную последовательность
task.spawn(function()
	if at(1.0) then play("Hammer") end
end)

task.spawn(function()
	-- 0:00 — чёрный, гул, холодный свет проявляется вдали
	play("Music")
	play("SubHum")
	fade(0.4, 3.4)

	-- 0:04 — коридор Хранилища
	if not at(4.0) then return end
	fade(1, 1.2)
	fly("Shot2A", "Shot2B", 7.0)
	setDOF(40, 25, 0.3, 1.0)
	if at(4.3) then play("Voice1") end

	-- 0:11 — выход в зал: Горнило, Колесо Клинков, парящие клинки (старт из точки, где камера закончила коридор)
	if not at(11.0) then return end
	fly(nil, "Shot3B", 7.0)
	setDOF(35, 20, 0.35, 1.5)
	if at(11.3) then play("Voice2") end

	-- 0:18 — стеклянный клинок с гниющей памятью; силуэт рассыпается, пустой клинок на полу наполняется светом
	if not at(18.0) then return end
	fly(nil, "Shot4A", 1.4)                      -- с высоты к стеклянному клинку: силуэт крупно и в анфас
	setDOF(11, 7, 0.45, 1.2)
	if at(18.3) then play("Voice3") end
	if at(19.0) then corrupt(1.9) end            -- память гниёт: глитч, серый силуэт, мигающий свет
	if at(20.2) then
		fly(nil, "Shot4B", 0.9)                  -- отъезд: в кадре и обречённый клинок, и пустой на полу
		setDOF(14, 10, 0.4, 1.0)
	end
	if at(21.0) then dissolveDoomed() end        -- силуэт -> кубики -> лезвие пустого клинка
	if at(21.6) then
		fly(nil, "Shot4C", 4.2)                  -- медленно ближе к пустому клинку
		setDOF(7, 5, 0.5, 2.5)
	end
	if at(24.9) then
		finishFill()                             -- клинок полон: вспышка, кольцо кубиков, дрожь
		play("Scrape")
		task.delay(0.5, function() play("Thud") end)
		local old = swayAmount
		swayAmount = 0.4
		task.delay(0.6, function() swayAmount = old end)
	end

	-- 0:26 — Пробуждённый: рука тянется к клинку, поднимается из колена, лицо без имени
	-- (HERO_MODE = "none": героя нет, полный клинок поднимается сам, камера идёт вверх вместе с ним)
	if not at(26.0) then return end
	if HERO_ON then
		-- герой на коленях за клинком: камера спереди-слева, в кадре вся фигура и клинок на полу
		-- (с маркера Shot5A фигура, склонённая к рукояти, сливалась в тёмную кучу блоков)
		camValue.Value = CFrame.lookAt(OR + V3(-0.5, 3.6, -100.5), OR + V3(4.2, 2.6, -109.6))
		flyTo(CFrame.lookAt(OR + V3(0.9, 4.0, -101.0), OR + V3(4.2, 2.9, -109.8)), 2.0)   -- медленный подъезд
		setDOF(10, 4.5, 0.45, 0.2)               -- фокус на герое (камера в ~10 шагах), размыт только дальний зал
	else
		cut("Shot5A")
		setDOF(9, 4, 0.5, 0.2)
	end
	revealHero(0.8)
	if HERO_ON then materialize() end
	if at(26.2) then play("Voice4") end
	if at(27.4) then
		boostTarget = 1.8                        -- хват: клинок вспыхивает, дальше герой сам ведёт меч и встаёт
		fillFlash = 2
	end
	if at(28.0) then
		if HERO_ON then
			fly(nil, "Shot5B", 5.0)
			setDOF(9, 3.5, 0.5, 2.0)              -- камера в 9–10 шагах от героя: он и клинок в фокусе, зал позади мягко размыт
		else
			flyTo(CFrame.lookAt(OR + V3(7.4, 5.0, -101.2), OR + V3(4.3, 6.4, -108.3)), 5.0)
			setDOF(8, 4, 0.5, 2.0)
		end
	end
	if not HERO_ON and at(28.9) and blade then   -- клинок отрывается от пола: кольцо кубиков по полу
		shockwave(OR + V3(4, 0.15, -108), 40, 7, 1.0)
		fillFlash = 2.5
	end
	if at(30.5) then
		if HERO_ON then
			openEyes()
		elseif blade then                        -- вместо открывшихся глаз клинок вспыхивает кольцом света
			shockwave(blade:GetPivot().Position, 40, 6, 1.0)
			fillFlash = 3
			boostTarget = 2.0
		end
	end

	-- 0:33 — клинок в центре, частицы втягиваются, отъезд, название
	if not at(33.0) then return end
	cut("Shot6A")
	fly(nil, "Shot6B", 5.5)
	setDOF(6, 4, 0.4, 0.5)
	task.delay(2, function() setDOF(14, 10, 0.3, 2.5) end)
	if at(33.4) then play("Voice5") end
	if at(33.6) then
		soulRiver(150, 2.6)                       -- из Горнила к клинку тянется река душ
		absorb(bladeBody, 60, 3.0, 8, nil, 0.7)   -- у клинка они закручиваются в вихрь
		boostTarget = 2.0
		haloTarget = 1
		fillFlash = 2
	end
	if at(34.0) then showTitle() end

	-- 0:38 — пик, обрыв, тишина
	if not at(37.9) then return end
	for _, s in pairs(sounds) do
		if s.IsPlaying and s.Name ~= "FinalHit" then s:Stop() end
	end
	play("FinalHit")
end)

-- Звуковой режиссёр: музыка, атмосфера и события идут отдельным потоком по тем же таймкодам.
-- Голос, Hammer, Scrape, Thud, Absorb и FinalHit запускаются в основной последовательности.
task.spawn(function()
	-- 0:00 пустота: суббас, первый кусок музыки, холодный воздух коридора
	fadeIn("MusicVoid", 2.5)
	fadeIn("AmbCorridor", 3.0)
	if at(2.0) then play("LightOn") end              -- голубой свет проявляется вдали
	if at(3.0) then fadeIn("ForgeFire", 5.0) end     -- Горнило слышно издалека, ближе к залу громче

	-- 0:11 выход в зал: кроссфейд музыки и воздуха
	if at(10.2) then
		fadeIn("MusicHall", 2.0)
		fadeOut("MusicVoid", 2.4)
		fadeOut("AmbCorridor", 2.5)
		fadeIn("AmbHall", 2.5)
	end
	if at(11.0) then play("HallReveal") end

	-- 0:18 память гниёт
	if at(17.4) then
		fadeIn("MusicRot", 1.8)
		fadeOut("MusicHall", 2.2)
	end
	if at(19.0) then play("Corrupt") end
	if at(21.0) then startHum() end                  -- с первой прилетевшей души клинок начинает звучать

	-- 0:24.9 клинок полон: музыка обрывается, остаются удар и тишина
	if at(24.9) then
		play("BladeFull")
		fadeOut("MusicRot", 0.35)
	end

	-- 0:26 Пробуждённый
	if at(26.0) then
		play("Materialize")
		fadeIn("MusicAwaken", 3.0)
	end
	if at(27.6) then play("Grip") end
	if at(29.5) then play("BladeRise") end
	if at(30.5) then play("EyesOpen") end

	-- 0:33 клинок в центре, название
	if at(33.0) then
		play("Whoosh")
		fadeIn("MusicFinale", 1.2)
		fadeOut("MusicAwaken", 1.6)
	end
	if at(34.0) then play("TitleSting") end
end)

task.spawn(function()
	while not skipped and now() < TOTAL do RunService.Heartbeat:Wait() end
	finish()
end)
