--!nonstrict
-- AbilityFxGarden (клиент)
-- Эффекты оружия этажа 2 «Затопленные сады»: Жатва, Паводок, Обрезка, Цветение, гниль на врагах.
-- События приходят в AbilityFx (kind = "garden"), сюда они попадают через handlers (вставка в AbilityFx.lua,
-- patches/floor2.patch). Сервер решает урон и попадания, здесь только картинка.
-- Внешний вид живёт в шаблонах ReplicatedStorage.FX.Garden (tools/fx/BuildFxGarden.lua): цвет, размер, скорость,
-- текстуры правятся в Studio. Если шаблона нет — эффект тихо пропускается (FxKit предупредит один раз).

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Bus = require(script.Parent.Parent.Lib.Bus)
local FxKit = require(script.Parent.Parent.Lib.FxKit)

local V3 = Vector3.new

local AbilityFxGarden = {}

local rotStates = {} -- [model] = { attachment, handle }

local function modelPart(model)
	if not model then
		return nil
	end
	return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart", true)
end

local function lifted(position: Vector3, lift: number?): Vector3
	return V3(position.X, position.Y + (lift or 0.15), position.Z)
end

local function facing(position: Vector3, direction: Vector3, yaw: number?): CFrame
	local base = CFrame.lookAt(position, position + direction)
	if yaw then
		base = base * CFrame.Angles(0, math.rad(yaw), 0)
	end
	return base
end

local function sound(name: string, position: Vector3)
	Bus.emit("sfx", { name = name, position = position })
end

local function impact(position: Vector3, amount: number, time: number)
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude <= 40 then
		Bus.emit("shake", { amount = amount, time = time })
	end
end

local function flatDirection(direction: Vector3): Vector3
	local flat = V3(direction.X, 0, direction.Z)
	return flat.Magnitude > 0.01 and flat.Unit or V3(0, 0, -1)
end

local function animatedRibbon(path: string, color: Color3, width: number, duration: number, positionAt)
	local holder = FxKit.holder()
	local a0 = Instance.new("Attachment")
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Parent = holder
	local ribbon = FxKit.clone(path)
	if not ribbon or not ribbon:IsA("Trail") then
		holder:Destroy()
		return
	end
	ribbon.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	ribbon.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, width),
		NumberSequenceKeypoint.new(0.35, width * 0.78),
		NumberSequenceKeypoint.new(1, 0),
	})
	ribbon.Attachment0 = a0
	ribbon.Attachment1 = a1
	ribbon.Parent = holder
	ribbon.Enabled = true

	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not holder.Parent then
			connection:Disconnect()
			return
		end
		local t = math.clamp((os.clock() - started) / duration, 0, 1)
		a0.WorldPosition, a1.WorldPosition = positionAt(t)
		if t >= 1 then
			connection:Disconnect()
			ribbon.Enabled = false
		end
	end)
	task.delay(duration + ribbon.Lifetime + 0.1, function()
		if connection.Connected then
			connection:Disconnect()
		end
		if holder.Parent then
			Debris:AddItem(holder, 0)
		end
	end)
end

local function sweepRibbon(origin: Vector3, direction: Vector3, path: string, color: Color3, duration: number, sweep: number, innerRadius: number, outerRadius: number, height: number, lift: number)
	local forward = flatDirection(direction)
	animatedRibbon(path, color, 1.3, duration, function(t)
		local angle = math.rad((t - 0.5) * sweep)
		local rotated = CFrame.fromAxisAngle(V3(0, 1, 0), angle):VectorToWorldSpace(forward)
		local y = height + (t - 0.5) * lift + math.sin(t * math.pi) * 0.35
		return origin + rotated * innerRadius + V3(0, y, 0), origin + rotated * outerRadius + V3(0, y + 0.12, 0)
	end)
end

local function travelingRibbon(origin: Vector3, direction: Vector3, path: string, color: Color3, duration: number, length: number, width: number, height: number, crest: number)
	local forward = flatDirection(direction)
	local side = V3(-forward.Z, 0, forward.X)
	for lane = -1, 1 do
		local laneOffset = lane * width * 0.32
		local laneColor = lane == 0 and Color3.new(1, 1, 1) or color
		animatedRibbon(path, laneColor, lane == 0 and 1.1 or 1.55, duration, function(t)
			local center = origin + forward * (length * t) + side * laneOffset
				+ V3(0, height + math.sin(t * math.pi) * crest, 0)
			local halfWidth = width * (0.32 + 0.12 * math.sin(t * math.pi))
			return center - side * halfWidth, center + side * halfWidth
		end)
	end
end

local function pruneRibbon(feet: Vector3, direction: Vector3, index: number)
	local forward = flatDirection(direction)
	local side = V3(-forward.Z, 0, forward.X)
	local sign = index == 1 and 1 or -1
	animatedRibbon("Garden/PruneRibbon", Color3.fromHex(index == 1 and "#B8F2E6" or "#D97A88"), 1.2, 0.18, function(t)
		local center = feet + forward * (1.7 + t * 1.15) + V3(0, 2.25, 0)
		local sideOffset = 2.1
		return center - side * sideOffset + V3(0, sign * 1.15, 0),
			center + side * sideOffset - V3(0, sign * 1.15, 0)
	end)
end

local function bloomHelix(position: Vector3, radius: number)
	for turn = 1, 2 do
		local direction = turn == 1 and 1 or -1
		local color = turn == 1 and Color3.fromHex("#D97A88") or Color3.fromHex("#F0E08A")
		animatedRibbon("Garden/BloomRibbon", color, 1.0, 0.62, function(t)
			local angle = direction * t * math.pi * 2.4
			local phase = (turn - 1) * math.pi
			local function point(offset: number)
				local a = angle + phase + offset
				return position + V3(math.cos(a) * radius, 0.4 + t * 3.2, math.sin(a) * radius)
			end
			return point(0), point(0.5)
		end)
	end
end

-- ===== Жатва =====

local function reapStart(payload)
	local origin = lifted(payload.position, 1.2)
	local direction = payload.direction
	sound("gardenReap", origin)
	impact(origin, 0.12, 0.14)
	FxKit.spawn("Garden/ReapCast", CFrame.new(origin))
	FxKit.spawn("Garden/ReapBurst", CFrame.new(origin), { radius = 3.5 })
	sweepRibbon(origin, direction, "Garden/ReapRibbon", Color3.fromHex("#5FD0C0"), 0.24, 150, 1.5, 4.3, 0.2, 0.7)
	travelingRibbon(origin, direction, "Garden/ReapRibbon", Color3.fromHex("#B8F2E6"), payload.waveTime, payload.length, 2.1, 0.35, 1.2)
	local handle = FxKit.spawn("Garden/ReapWave", facing(origin, direction), { life = payload.waveTime + 0.05 })
	if not handle then
		return
	end
	local goal = facing(origin + direction * payload.length, direction)
	TweenService:Create(handle.root, TweenInfo.new(payload.waveTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = goal,
	}):Play()
end

local function reapHit(payload)
	FxKit.spawn("Garden/ReapHit", CFrame.new(lifted(payload.position, 2)))
	sound("gardenReapHit", payload.position)
end

-- Гниль: зелёные пузыри и дымка на враге на всё время действия.
local function rot(payload)
	local model = payload.model
	local part = modelPart(model)
	if not part then
		return
	end
	local old = rotStates[model]
	if old then
		if old.handle then
			old.handle.destroy()
		end
		if old.attachment and old.attachment.Parent then
			old.attachment:Destroy()
		end
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "GardenRot"
	attachment.Parent = part
	local handle = FxKit.attach("Garden/Rot", attachment, { life = payload.duration })
	local state = { attachment = attachment, handle = handle }
	rotStates[model] = state
	task.delay(payload.duration + 1.2, function()
		if attachment.Parent then
			attachment:Destroy()
		end
		if rotStates[model] == state then
			rotStates[model] = nil
		end
	end)
end

-- ===== Паводок =====

local function floodSlam(payload)
	local ground = lifted(payload.position, 0.15)
	sound("gardenFlood", ground)
	impact(ground, 0.34, 0.34)
	FxKit.spawn("Garden/FloodSlam", CFrame.new(ground), { radius = payload.radius * 0.67 })
	local crest = facing(lifted(payload.position, 0.8), payload.direction)
	FxKit.spawn("Garden/FloodWave", crest, { radius = payload.radius })
	FxKit.spawn("Garden/FloodCrest", crest, { radius = payload.radius })
	travelingRibbon(ground, payload.direction, "Garden/FloodRibbon", Color3.fromHex("#5FD0C0"), 0.42, payload.radius * 1.35, payload.radius * 0.5, 0.75, 3.0)
	FxKit.spawn("Common/Dust", CFrame.new(ground), { scale = payload.radius / 9 })
end

local function floodPuddle(payload)
	local ground = lifted(payload.position, 0.12)
	FxKit.spawn("Garden/Puddle", CFrame.new(ground), { radius = payload.radius, life = payload.time })
end

local function floodEnd(payload)
	FxKit.spawn("Garden/PuddleEnd", CFrame.new(lifted(payload.position, 0.2)), { radius = payload.radius })
end

-- ===== Обрезка =====
-- Два среза идут по диагонали навстречу друг другу: первый слева направо и вниз, второй наоборот.

local function pruneCut(payload)
	local feet = payload.position
	local direction = payload.direction
	local yaw = payload.index == 1 and 28 or -28
	local height = payload.index == 1 and 2.6 or 1.6
	local origin = lifted(feet, height) + direction * 1.5
	sound("gardenPrune", origin)
	FxKit.spawn("Garden/PruneCut", facing(origin, direction, yaw), { radius = payload.radius })
	FxKit.spawn("Garden/PruneCross", facing(origin, direction, yaw), { radius = payload.radius })
	pruneRibbon(feet, direction, payload.index or 1)
	local playedHit = false
	for _, model in ipairs(payload.targets or {}) do
		local part = modelPart(model)
		if part then
			FxKit.spawn("Garden/PruneHit", CFrame.new(part.Position))
			if not playedHit then
				sound("gardenPruneHit", part.Position)
				playedHit = true
			end
		end
	end
end

-- ===== Цветение =====

local function thorn(payload)
	local part = modelPart(payload.model)
	local position = part and part.Position or payload.position
	local template = FxKit.template("Garden/Thorn")
	if not template then
		return
	end
	sound("gardenThorn", position)
	-- Чем больше шипов, тем сильнее выброс.
	FxKit.spawn("Garden/Thorn", CFrame.new(position), { scale = 1 + (payload.count or 1) * 0.12 })
end

local function bloom(payload)
	local ground = lifted(payload.position, 0.2)
	sound("gardenBloom", ground)
	impact(ground, 0.24, 0.24)
	FxKit.spawn("Garden/Bloom", CFrame.new(ground), { radius = payload.radius })
	FxKit.spawn("Garden/BloomBurst", CFrame.new(ground), { radius = payload.radius })
	bloomHelix(ground, math.clamp((payload.radius or 4) * 0.45, 1.5, 3.5))
	local part = modelPart(payload.model)
	if part then
		FxKit.spawn("Garden/PruneHit", CFrame.new(part.Position))
	end
end

-- kind = "garden": phase → обработчик. AbilityFx подмешивает их в свою таблицу HANDLERS.
AbilityFxGarden.handlers = {
	garden = {
		reapStart = reapStart,
		reapHit = reapHit,
		rot = rot,
		floodSlam = floodSlam,
		floodPuddle = floodPuddle,
		floodEnd = floodEnd,
		pruneCut = pruneCut,
		thorn = thorn,
		bloom = bloom,
	},
}

return AbilityFxGarden
