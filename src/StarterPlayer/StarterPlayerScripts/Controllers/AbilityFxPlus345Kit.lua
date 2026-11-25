--!nonstrict
-- AbilityFxPlus345Kit (клиент)
-- Общие мелочи продлённых фаз оружия этажей 3–5 (AbilityFxPlusHunt / Forge / Chronicle):
-- земля под точкой и под врагом, позиция модели, кольцо «за врагом», рука героя, состояния.
-- Сами эффекты — Lib/FxAfter (бюджет деталей, кадр удара, обломки, хвосты).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Fx = require(script.Parent.Parent.Lib.FxAfter)
local Kit = Fx.Kit

local P = {}
P.Fx = Fx
P.Kit = Kit

local V3 = Vector3.new

-- Пол этажа (как AbilityFx345Kit): луч только по геометрии карты — не упрётся во врага.
-- Нет модуля (хаб, tools/fxsim) — Kit.ground.
local FloorGeo = nil
do
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local floor = shared and shared:FindFirstChild("Floor")
	local module = floor and floor:FindFirstChild("FloorGeo")
	if module then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" and type(result.groundAt) == "function" then
			FloorGeo = result
		end
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function floorY(position: Vector3): number?
	if FloorGeo then
		local ok, y = pcall(FloorGeo.groundAt, position.X, position.Z, position.Y + 1.5)
		if ok and type(y) == "number" and math.abs(y - position.Y) < 6 then
			return y
		end
	end
	return nil
end

-- Точка на земле под position.
function P.G(position: Vector3, lift: number?): Vector3
	local y = floorY(position)
	if y then
		return V3(position.X, y + (lift or 0.06), position.Z)
	end
	return Kit.ground(position, lift or 0.06)
end

function P.partOf(model)
	if typeof(model) ~= "Instance" then
		return nil
	end
	if model:IsA("BasePart") then
		return model
	end
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

-- Позиция модели (если жива), иначе запасная точка из события.
function P.posOf(model, fallback)
	local part = P.partOf(model)
	if part and part.Parent then
		return part.Position
	end
	if typeof(fallback) == "Vector3" then
		return fallback
	end
	return nil
end

function P.height(model): number
	local h = typeof(model) == "Instance" and model:GetAttribute("EnemyHeight")
	return tonumber(h) or 5
end

-- Земля под врагом: пол карты, иначе луч мимо самой модели.
function P.groundUnder(model, position: Vector3, lift: number?): Vector3
	local y = floorY(position)
	if not y then
		local ignore = { Kit.folder() }
		if typeof(model) == "Instance" then
			table.insert(ignore, model)
		end
		for _, other in ipairs(Players:GetPlayers()) do
			if other.Character then
				table.insert(ignore, other.Character)
			end
		end
		local fx = Workspace:FindFirstChild("KlinokAbilityFx")
		if fx then
			table.insert(ignore, fx)
		end
		rayParams.FilterDescendantsInstances = ignore
		local result = Workspace:Raycast(position + V3(0, 1, 0), V3(0, -16, 0), rayParams)
		y = result and result.Position.Y or (position.Y - P.height(model) * 0.5)
	end
	return V3(position.X, y + (lift or 0.08), position.Z)
end

function P.flat(direction, fallback)
	if typeof(direction) ~= "Vector3" then
		return fallback or V3(0, 0, -1)
	end
	return Kit.flatUnit(direction, fallback)
end

function P.rootOf(caster)
	local _, root = Kit.characterOf(caster)
	return root
end

-- Правая рука героя (или точка у правого бока).
function P.handPos(caster): Vector3?
	local character, root = Kit.characterOf(caster)
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if hand and hand:IsA("BasePart") then
		return hand.Position
	end
	if root then
		return (root.CFrame * CFrame.new(1.1, -0.3, -0.5)).Position
	end
	return nil
end

-- Кольцо, которое едет за врагом по земле (метка, цепь, печать), пульсирует и гаснет.
-- o: image, brightness, transparency, spin (°/с), pulse.
function P.followRing(model, radius: number, color: Color3, life: number, o)
	o = o or {}
	local part = P.partOf(model)
	if not part then
		return
	end
	local plane, label = Kit.plane(CFrame.new(P.groundUnder(model, part.Position, 0.1)), radius * 2, o.image or "ring", color,
		{ brightness = o.brightness or 3, transparency = 1 })
	local angle = math.random() * 360
	local peak = o.transparency or 0.35
	Kit.every(life, function(_, t, dt)
		local now = P.partOf(model)
		if not now or not now.Parent then
			return false
		end
		angle += dt * (o.spin or 60)
		plane.CFrame = CFrame.new(P.groundUnder(model, now.Position, 0.1)) * CFrame.Angles(0, math.rad(angle), 0)
		local fadeIn = math.clamp(t / 0.2, 0, 1)
		local fadeOut = math.clamp((life - t) / 0.45, 0, 1)
		local pulse = 0.8 + 0.2 * math.sin(t * (o.pulse or 7))
		label.ImageTransparency = 1 - (1 - peak) * math.min(fadeIn, fadeOut) * pulse
		return true
	end, function()
		plane:Destroy()
	end)
end

-- Состояния по игроку: stateOf(caster) → таблица; forget(caster) — убрать.
function P.states()
	local states = {}
	local function stateOf(caster)
		local key = caster or "?"
		states[key] = states[key] or {}
		return states[key]
	end
	return stateOf, states
end

-- Звук не чаще раза в gap секунд на ключ (несколько целей/луж разом — один звук).
function P.limiter(gap: number)
	local last = {}
	return function(key): boolean
		local now = os.clock()
		if now - (last[key] or -math.huge) < gap then
			return false
		end
		last[key] = now
		return true
	end
end

return P
