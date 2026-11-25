--!nonstrict
-- EnemyDebuffFx (клиент)
-- Визуал дебафов на игроке (мороз/огонь/яд): частицы на персонаже, цветной
-- тон экрана, иконка с таймером у полосы HP, звук наложения. Сервер
-- (EnemyDebuffs) решает всё через атрибуты DebuffKind / DebuffUntil —
-- клиент только рисует и играет звук.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Debuffs = require(Shared.Config.Debuffs)
local Lib = script.Parent.Parent.Lib
local UiSound = require(Lib.UiSound)

-- Звук наложения (палитра UI): мороз — закалка, огонь — горн, яд — эхо.
local APPLY_SOUND = {
	frost = "quench",
	burn = "forge_heat",
	poison = "echo",
}

-- Частицы: цвет/направление по виду.
local PARTICLES = {
	frost = { color = Color3.fromRGB(190, 230, 255), accel = Vector3.new(0, -6, 0), speed = 3, size = 0.35 },
	burn = { color = Color3.fromRGB(255, 160, 60), accel = Vector3.new(0, 10, 0), speed = 4, size = 0.45 },
	poison = { color = Color3.fromRGB(150, 230, 100), accel = Vector3.new(0, -3, 0), speed = 2, size = 0.3 },
}

local gui = Instance.new("ScreenGui")
gui.Name = "KlinokDebuff"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

-- Иконка дебафа с таймером: рядом с полосой HP (низ-центр, правее бара).
local debuffFrame = Instance.new("Frame")
debuffFrame.Name = "Debuff"
debuffFrame.AnchorPoint = Vector2.new(0.5, 1)
debuffFrame.Position = UDim2.new(0.5, 330, 1, -64)
debuffFrame.Size = UDim2.fromOffset(56, 64)
debuffFrame.BackgroundTransparency = 1
debuffFrame.ZIndex = 25
debuffFrame.Visible = false
debuffFrame.Parent = gui

local debuffIcon = Instance.new("ImageLabel")
debuffIcon.Name = "Icon"
debuffIcon.Position = UDim2.new(0.5, 0, 0, 0)
debuffIcon.AnchorPoint = Vector2.new(0.5, 0)
debuffIcon.Size = UDim2.fromOffset(48, 48)
debuffIcon.BackgroundTransparency = 1
debuffIcon.ZIndex = 26
debuffIcon.Parent = debuffFrame

local debuffTimer = Instance.new("TextLabel")
debuffTimer.Name = "Timer"
debuffTimer.AnchorPoint = Vector2.new(0.5, 0)
debuffTimer.Position = UDim2.new(0.5, 0, 0, 48)
debuffTimer.Size = UDim2.fromOffset(56, 16)
debuffTimer.BackgroundTransparency = 1
debuffTimer.FontFace = Font.fromEnum(Enum.Font.Arcade)
debuffTimer.TextSize = 13
debuffTimer.TextColor3 = Color3.fromRGB(238, 230, 214)
debuffTimer.Text = ""
debuffTimer.ZIndex = 26
debuffTimer.Parent = debuffFrame

-- Тон экрана: свой ColorCorrection (клиентский, на общий Lighting).
local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "KlinokDebuffTint"
tint.Enabled = false
tint.Parent = Lighting

-- Частицы на персонаже.
local particles = nil

local function clearParticles()
	if particles then
		particles:Destroy()
		particles = nil
	end
end

local function attachParticles(kind)
	clearParticles()
	local cfg = PARTICLES[kind]
	if not cfg then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	particles = Instance.new("ParticleEmitter")
	particles.Name = "DebuffParticles"
	particles.Texture = Debuffs.Atlas[kind]
	particles.Color = ColorSequence.new(cfg.color)
	particles.Acceleration = cfg.accel
	particles.Speed = NumberRange.new(cfg.speed * 0.6, cfg.speed)
	particles.Lifetime = NumberRange.new(0.6, 1.1)
	particles.Size = NumberSequence.new(cfg.size, 0)
	particles.Rate = 14
	particles.LightEmission = 0.8
	particles.Transparency = NumberSequence.new(0.2, 1)
	particles.Parent = root
end

local function clearAll()
	debuffFrame.Visible = false
	debuffTimer.Text = ""
	tint.Enabled = false
	clearParticles()
end

-- Отслеживание активного дебафа.
local activeKind = nil
local debuffUntil = 0

local function onCharacter(character)
	clearParticles()
	if activeKind then
		attachParticles(activeKind)
	end
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		clearAll()
	end)
end

if player.Character then
	onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)

local lastSecond = -1
RunService.Heartbeat:Connect(function()
	if not activeKind then
		return
	end
	local left = math.max(0, debuffUntil - workspace:GetServerTimeNow())
	debuffTimer.Text = string.format("%.1f", left)
	if left <= 0 then
		activeKind = nil
		clearAll()
	end
end)

local function applyVisual(kind)
	local cfg = Debuffs.Kinds[kind]
	if not cfg then
		return
	end
	debuffIcon.Image = Debuffs.Atlas[kind]
	debuffIcon.ImageColor3 = Color3.new(1, 1, 1)
	debuffFrame.Visible = true
	tint.TintColor = cfg.screen
	tint.Saturation = -0.08
	tint.Brightness = -0.02
	tint.Enabled = true
	attachParticles(kind)
end

local function sync()
	local kind = player:GetAttribute("DebuffKind")
	local until_ = player:GetAttribute("DebuffUntil")
	if kind and Debuffs.Kinds[kind] and typeof(until_) == "number" and until_ > workspace:GetServerTimeNow() then
		if activeKind ~= kind then
			activeKind = kind
			debuffUntil = until_
			applyVisual(kind)
			UiSound.play(APPLY_SOUND[kind] or "echo", { volume = 0.5 })
		else
			debuffUntil = until_ -- освежили тот же дебаф
		end
	else
		if activeKind then
			activeKind = nil
		end
		clearAll()
	end
end


local EnemyDebuffFx = {}

function EnemyDebuffFx.start()
player:GetAttributeChangedSignal("DebuffKind"):Connect(sync)
player:GetAttributeChangedSignal("DebuffUntil"):Connect(sync)
sync()


	return EnemyDebuffFx
end

return EnemyDebuffFx