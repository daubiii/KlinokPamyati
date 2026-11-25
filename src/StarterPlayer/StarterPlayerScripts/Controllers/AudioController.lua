--!nonstrict
-- AudioController (клиент)
-- Звук и музыка.
--   * Bus "sfx" { name, position? } — проиграть звук из Config/Sfx. Звук
--     состоит из слоёв (звон + глухой удар), у каждого своя высота и задержка.
--     Громкость падает с расстоянием от игрока.
--   * Музыка: фон этажа играет сам; на сцене босса плавно сменяется темой
--     босса, после победы (или гибели игрока) возвращается фон.
-- Эффекты и музыка — в разных SoundGroup: громкость правится отдельно.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sfx = require(Shared.Config.Sfx)
local Net = require(Shared.Net.Net)

local Bus = require(script.Parent.Parent.Lib.Bus)
local UiSound = require(script.Parent.Parent.Lib.UiSound)

local AudioController = {}

local player = Players.LocalPlayer
local random = Random.new()
local lastPlayed = {}

local MAX_DISTANCE = 80
local MIN_GAP = 0.04 -- один и тот же звук не чаще, чем раз в 40 мс

local groups = {}

local function group(name: string, volume: number)
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		groups[name] = existing
		return existing
	end
	local created = Instance.new("SoundGroup")
	created.Name = name
	created.Volume = volume
	created.Parent = SoundService
	groups[name] = created
	return created
end

-- ===== Эффекты =====

local function playLayer(entry, volumeScale: number)
	local sound = Instance.new("Sound")
	sound.SoundId = entry.id
	sound.Volume = entry.volume * volumeScale
	local pitch = entry.pitch
	sound.PlaybackSpeed = pitch and random:NextNumber(pitch[1], pitch[2]) or 1
	sound.SoundGroup = groups.KlinokSfx
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	if entry.from and entry.from > 0 then
		sound.TimePosition = entry.from -- играть не с начала файла
	end
	sound:Play()
	if entry.length then
		-- Обрезка длинного хвоста: затухание (fade, по умолчанию 0,35 с).
		local fade = entry.fade or 0.35
		task.delay(entry.length, function()
			if sound.Parent then
				TweenService:Create(sound, TweenInfo.new(fade), { Volume = 0 }):Play()
			end
		end)
		Debris:AddItem(sound, entry.length + fade + 0.2)
	else
		Debris:AddItem(sound, 8)
	end
end

local function play(data)
	-- Звуки интерфейса на шине («ui», «armorEquip», «levelUp»…): если для них
	-- загружен звук палитры v3 (UiAssets.Palette), играет он — через UiSound.
	if data.position == nil and UiSound.hasPalette(data.name) then
		UiSound.play(data.name, { volume = data.volume })
		return
	end
	-- SfxPick_<имя> — вариант, выбранный командой «sfx» (только Studio).
	local layers = Sfx.layers(data.name, player:GetAttribute("SfxPick_" .. tostring(data.name)))
	if not layers then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[data.name] or 0) < MIN_GAP then
		return
	end
	lastPlayed[data.name] = now

	local scale = data.volume or 1
	if typeof(data.position) == "Vector3" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local distance = (root.Position - data.position).Magnitude
			scale *= math.clamp(1 - distance / MAX_DISTANCE, 0, 1)
		end
	end
	if scale < 0.02 then
		return
	end

	for _, entry in ipairs(layers) do
		if entry.delay and entry.delay > 0 then
			task.delay(entry.delay, playLayer, entry, scale)
		else
			playLayer(entry, scale)
		end
	end
end

-- ===== Музыка =====

local music = {} -- [name] = Sound
local currentTrack = nil

local function track(name: string)
	if music[name] then
		return music[name]
	end
	local spec = Sfx.music[name]
	if not spec or spec.id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Music_" .. name
	sound.SoundId = spec.id
	sound.Volume = 0
	sound.Looped = true
	sound.SoundGroup = groups.KlinokMusic
	sound.Parent = SoundService
	sound:SetAttribute("TargetVolume", spec.volume)
	music[name] = sound
	return sound
end

local function switchMusic(name: string)
	if currentTrack == name then
		return
	end
	local fade = Sfx.musicFade or 1.5
	for trackName, sound in pairs(music) do
		if trackName ~= name and sound.IsPlaying then
			local tween = TweenService:Create(sound, TweenInfo.new(fade), { Volume = 0 })
			tween:Play()
			tween.Completed:Once(function()
				if currentTrack ~= trackName then
					sound:Pause()
				end
			end)
		end
	end
	currentTrack = name
	local sound = track(name)
	if sound then
		if not sound.IsPlaying then
			if name == "boss" then
				sound.TimePosition = 0
			end
			sound:Play()
		end
		TweenService:Create(sound, TweenInfo.new(fade), { Volume = sound:GetAttribute("TargetVolume") or 0.3 }):Play()
	end
end

function AudioController.music(name: string)
	switchMusic(name)
end

function AudioController.start()
	group("KlinokSfx", 1)
	group("KlinokMusic", 1)
	Bus.on("sfx", play)
	-- Прослушивание: команда «sfx <имя> <номер>» (атрибут SfxAudition «имя#N»).
	player:GetAttributeChangedSignal("SfxAudition"):Connect(function()
		local name = string.match(player:GetAttribute("SfxAudition") or "", "^(.-)#")
		if name and name ~= "" then
			lastPlayed[name] = 0
			play({ name = name })
		end
	end)
	Bus.on("music", function(data)
		switchMusic(type(data) == "table" and data.name or tostring(data))
	end)

	-- Музыка следует за этажом: босс — своя тема, победа и смерть — фон.
	local floorRemote = Net.get("FloorEvent")
	if floorRemote then
		floorRemote.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then
				return
			end
			if payload.kind == "bossIntro" then
				switchMusic("boss")
			elseif payload.kind == "roomCleared" or payload.kind == "playerDied" or payload.kind == "newRun" then
				switchMusic("floor")
			end
		end)
	end

	-- В хабе своя тема (или тишина), на этаже — фон этажа.
	local function zoneMusic()
		switchMusic(player:GetAttribute("Zone") == "Floor" and "floor" or "hub")
	end
	player:GetAttributeChangedSignal("Zone"):Connect(zoneMusic)
	task.delay(1, zoneMusic)
	print("[AudioController] звук: слои Pro Sound Effects / APM, музыка этажа и босса")
end

return AudioController
