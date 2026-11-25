--!nonstrict
-- WeaponPresence (клиент)
-- «Присутствие» легендарного и секретного оружия — у всех игроков, не только у своего:
--   • раз в ~3 с (секретка — ~2 с) вспышка: эмиттеры ауры с атрибутом Flare выпускают частицы,
--     свет оружия пульсирует, у ног расходится кольцо-волна (FX/Presence/Ring) в цвет оружия;
--   • у секретки под ногами всё время медленно вращается круг рун с искрами (FX/Presence/Sigil);
--   • находка легендарки/секретки (Notify kind = "legendDrop" → Bus «legendDrop» из FloorUiController):
--     столб света над сундуком на несколько секунд (FX/Presence/Pillar), виден издалека.
-- Сама аура (частицы по клинку, свечение, шлейф) — на модели оружия: её строит сервер
-- (VoxelWeaponBuilder + шаблоны FX.Weapon.<id> из Shared/Fx/FxWeapons345), так что её видят все.
-- Оружие в руке — Model «EquippedWeapon» с атрибутами AuraRarity / AuraColor (EquipmentService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Bus = require(script.Parent.Parent.Lib.Bus)
local FxKit = require(script.Parent.Parent.Lib.FxKit)

local WeaponPresence = {}

local WEAPON_NAME = "EquippedWeapon"
local VIEW_DISTANCE = 150 -- дальше камеры вспышки и круг рун не показываются
local SCAN_EVERY = 0.4
local FLARE_EVERY = { legendary = 3.2, secret = 2.1, epic = 4.4 }
local PULSE = { legendary = 2.2, secret = 2.8, epic = 1.7 } -- во сколько раз вспыхивает свет оружия
local BREATHE_RATE = 2.1 -- Гц дыхания неоновых деталей и света

local states = {} -- [Player] = { model, rarity, color, flares, lights, glows, nextFlare, sigil }

local function recolor(root: Instance, color: Color3)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			d.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color)
		elseif d:IsA("Light") then
			d.Color = color
		end
	end
end

local function feet(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root then
		return nil
	end
	local down = root.Size.Y / 2 + (humanoid and humanoid.HipHeight or 2) - 0.05
	return root.Position - Vector3.new(0, down, 0)
end

local function clear(player)
	local state = states[player]
	if not state then
		return
	end
	if state.sigil then
		state.sigil.destroy()
	end
	states[player] = nil
end

local function setup(player, model)
	local rarity = model:GetAttribute("AuraRarity") or model:GetAttribute("RarityId")
	if rarity ~= "legendary" and rarity ~= "secret" and rarity ~= "epic" then
		return { model = model }
	end
	local color = model:GetAttribute("AuraColor")
	local flares, lights, glows = {}, {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ParticleEmitter") and d:GetAttribute("Flare") then
			table.insert(flares, d)
		elseif d:IsA("PointLight") then
			table.insert(lights, { light = d, base = d.Brightness })
			color = color or d.Color
		elseif d:IsA("BasePart") and d:GetAttribute("BaseGlowColor") then
			-- неоновые детали клинка (VoxelWeaponBuilder): их дышит дыхание и вспышка
			table.insert(glows, {
				part = d,
				baseT = d:GetAttribute("BaseTransparency") or d.Transparency,
				baseC = d:GetAttribute("BaseGlowColor") or d.Color,
				phase = (d:GetAttribute("GlowIndex") or 0) * 1.9,
			})
		end
	end
	color = color or Rarities.color(rarity)
	return {
		model = model,
		rarity = rarity,
		color = color,
		flares = flares,
		lights = lights,
		glows = glows,
		nextFlare = os.clock() + 0.6 + math.random() * 1.2,
	}
end

-- Дыхание в покое: прозрачность и цвет неоновых деталей плавают, свет дышит.
-- Пока идёт вспышка (flareUntil), неоновым деталям и свету даём твинам дорисовать.
local function breathe(state, now)
	local flareHolds = state.flareUntil and now < state.flareUntil
	if not flareHolds then
		for _, g in ipairs(state.glows) do
			local p = g.part
			if p.Parent then
				local w = 0.5 + 0.5 * math.sin(now * BREATHE_RATE + g.phase)
				p.Transparency = math.clamp(g.baseT + 0.08 + 0.14 * w, 0, 1)
				p.Color = g.baseC:Lerp(Color3.new(1, 1, 1), 0.08 + 0.22 * w)
			end
		end
		for _, item in ipairs(state.lights) do
			local light = item.light
			if light.Parent then
				light.Brightness = item.base * (0.78 + 0.44 * (0.5 + 0.5 * math.sin(now * BREATHE_RATE)))
			end
		end
	end
end

local function flare(state, character)
	state.flareUntil = os.clock() + 0.8
	for _, e in ipairs(state.flares) do
		if e.Parent then
			e:Emit(e:GetAttribute("Flare"))
		end
	end
	for _, g in ipairs(state.glows) do
		local p = g.part
		if p.Parent then
			p.Transparency = math.max(0.02, g.baseT - 0.12)
			p.Color = p.Color:Lerp(Color3.new(1, 1, 1), 0.45)
			TweenService:Create(p, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Transparency = g.baseT, Color = g.baseC }):Play()
		end
	end
	for _, item in ipairs(state.lights) do
		local light = item.light
		if light.Parent then
			light.Brightness = item.base * PULSE[state.rarity]
			TweenService:Create(light, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Brightness = item.base }):Play()
		end
	end
	local at = feet(character)
	if at then
		local handle = FxKit.spawn("Presence/Ring", CFrame.new(at), { scale = state.rarity == "secret" and 1.3 or 1 })
		if handle and handle.root then
			recolor(handle.root, state.color)
		end
	end
end

local function updateSigil(state, character, visible: boolean)
	if state.rarity ~= "secret" then
		return
	end
	local at = visible and feet(character)
	if not at then
		if state.sigil then
			state.sigil.destroy()
			state.sigil = nil
		end
		return
	end
	if not state.sigil then
		state.sigil = FxKit.spawn("Presence/Sigil", CFrame.new(at))
		if state.sigil and state.sigil.root then
			recolor(state.sigil.root, state.color)
		end
	end
	if state.sigil and state.sigil.root and state.sigil.root.Parent then
		state.sigil.root.CFrame = CFrame.new(at)
	end
end

local function scan()
	for player, state in pairs(states) do
		if player.Parent == nil or not state.model or not state.model:IsDescendantOf(Workspace) then
			clear(player)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local model = character and character:FindFirstChild(WEAPON_NAME, true)
		local state = states[player]
		if not model then
			clear(player)
		elseif not state or state.model ~= model then
			clear(player)
			states[player] = setup(player, model)
		end
	end
end

local function pillar(payload)
	if type(payload) ~= "table" or typeof(payload.position) ~= "Vector3" then
		return
	end
	local color = Rarities.color(payload.rarity or "legendary")
	local secret = payload.rarity == "secret"
	local handle = FxKit.spawn("Presence/Pillar", CFrame.new(payload.position), { life = secret and 7 or 5 })
	if handle and handle.root then
		recolor(handle.root, color)
	end
end

function WeaponPresence.start()
	Bus.on("legendDrop", pillar)
	local lastScan = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastScan > SCAN_EVERY then
			lastScan = now
			scan()
		end
		local camera = Workspace.CurrentCamera
		local eye = camera and camera.CFrame.Position
		for player, state in pairs(states) do
			if state.rarity then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local visible = root ~= nil and (not eye or (root.Position - eye).Magnitude < VIEW_DISTANCE)
				updateSigil(state, character, visible)
				breathe(state, now)
				if visible and now >= state.nextFlare then
					state.nextFlare = now + FLARE_EVERY[state.rarity] * (0.85 + math.random() * 0.3)
					flare(state, character)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(clear)
end

return WeaponPresence
