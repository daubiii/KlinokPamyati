--!nonstrict
-- FloorMap (сервер)
-- Живые части карты этажа (Workspace.Floor1Map / Floor2Map, собирается один раз в
-- Studio из пакета карты): решётки ворот, печати памяти в проёмах, доски моста
-- (пробиваются взрывом), баррикады пандуса, внутренняя решётка Зала лебёдки,
-- створки Ворот Хранилища, костры (ProximityPrompt), шипы.
--
-- Статика (меши и коллизии) не трогается. Всё динамическое лежит в папках
-- Floor1Map.<зона>.Dynamic как Model с настоящими Part; при сборке этажа
-- (reset) их исходные положения восстанавливаются.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Floor1v2 = require(Shared.Config.Floor1v2)
local Rooms = require(Shared.Config.Rooms)

local FloorMap = {}

-- Экземпляр на карту: FloorMap.new("Floor2Map", Floor2) — у каждого этажа свои
-- решётки, печати, папка рантайма и восстановление досок. Модульные функции
-- (FloorMap.setGate и т. д.) — экземпляр этажа 1, как раньше.
local function create(mapName: string, settings)
	local M = {}


	local cache = {
		map = nil,
		gates = {}, -- [name] = { model, closed: CFrame, height, collider, open }
		pieces = {}, -- [model] = { [part] = { transparency, canCollide } } — для восстановления
		originals = {}, -- [name] = клон модели (баррикады), чтобы вернуть после разрушения
		runtime = nil, -- папка для созданных на ходу деталей (печати, подсказки)
		seals = {},
		broken = {}, -- [tileModel] = время восстановления
	}

	local function now(): number
		return Workspace:GetServerTimeNow()
	end

	function M.map()
		if cache.map and cache.map.Parent then
			return cache.map
		end
		cache.map = Workspace:FindFirstChild(mapName)
		return cache.map
	end

	function M.ready(): boolean
		return M.map() ~= nil
	end

	local function runtimeFolder()
		if cache.runtime and cache.runtime.Parent then
			return cache.runtime
		end
		local folder = Instance.new("Folder")
		folder.Name = settings.RuntimeName or "FloorRuntime"
		folder.Parent = Workspace
		cache.runtime = folder
		return folder
	end

	-- ===== Невидимые надстройки стен =====
	-- С ящиков и колонн внутри комнаты можно было перепрыгнуть стену и уйти за
	-- карту. Над каждой стеной (тонкая вертикальная коллизия) ставим невидимый
	-- столб до WALL_CAP стадов вверх; если над стеной что-то есть (пандус башни,
	-- перекрытие), столб обрывается под ним. Строится один раз при старте.
	-- CanQuery = false: лучи (пол врагов, камера, стрелы) столбы не видят.

	local WALL_CAP = 35
	local WALL_MIN_HEIGHT = 3.5
	local WALL_MAX_THICKNESS = 3.2

	function M.capWalls(): number
		local map = M.map()
		if not map or map:FindFirstChild("WallCaps") then
			return 0
		end
		local collisions = {}
		for _, zone in ipairs(map:GetChildren()) do
			local col = zone:FindFirstChild("Collision")
			if col then
				table.insert(collisions, col)
			end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = collisions
		-- пол рядом со стеной: коллизии и динамика (доски моста)
		local floorParams = RaycastParams.new()
		floorParams.FilterType = Enum.RaycastFilterType.Include
		floorParams.FilterDescendantsInstances = { map }

		local folder = Instance.new("Folder")
		folder.Name = "WallCaps"
		local count = 0
		for _, col in ipairs(collisions) do
			for _, wall in ipairs(col:GetDescendants()) do
				local size = wall:IsA("Part") and wall.Shape == Enum.PartType.Block and wall.Size
				if
					size
					and wall.CanCollide
					and size.Y >= WALL_MIN_HEIGHT
					and math.min(size.X, size.Z) <= WALL_MAX_THICKNESS
					and math.abs(wall.CFrame.UpVector.Y) > 0.99
				then
					local top = wall.Position.Y + size.Y / 2
					-- Стена вровень с полом рядом (борт рва под мостом, фундамент) —
					-- не стена: столб над ней встал бы невидимой преградой посреди прохода.
					local thinX = size.X <= size.Z
					local across = thinX and wall.CFrame.RightVector or wall.CFrame.LookVector
					local half = (thinX and size.X or size.Z) / 2 + 0.8
					local flush = false
					for _, side in ipairs({ 1, -1 }) do
						local origin = Vector3.new(wall.Position.X, top + 2, wall.Position.Z) + across * half * side
						local below = Workspace:Raycast(origin, Vector3.new(0, -3.2, 0), floorParams)
						if below and below.Position.Y >= top - 0.75 then
							flush = true
						end
					end
					local footprint = Vector3.new(math.max(size.X - 0.2, 0.1), 0.2, math.max(size.Z - 0.2, 0.1))
					local start = CFrame.new(wall.Position.X, top + 0.2, wall.Position.Z) * wall.CFrame.Rotation
					local hit = Workspace:Blockcast(start, footprint, Vector3.new(0, WALL_CAP, 0), params)
					local height = hit and math.max(hit.Distance - 0.3, 0) or WALL_CAP
					if height > 1 and not flush then
						local cap = Instance.new("Part")
						cap.Name = "WallCap"
						cap.Anchored = true
						cap.CanCollide = true
						cap.CanQuery = false
						cap.CanTouch = false
						cap.CastShadow = false
						cap.Transparency = 1
						cap.Size = Vector3.new(size.X, height, size.Z)
						cap.CFrame = CFrame.new(wall.Position.X, top + height / 2, wall.Position.Z) * wall.CFrame.Rotation
						cap.Parent = folder
						count += 1
					end
				end
			end
		end
		folder.Parent = map
		return count
	end

	-- Найти динамическую модель по имени во всех зонах.
	function M.dynamic(name: string)
		local map = M.map()
		if not map then
			return nil
		end
		for _, zone in ipairs(map:GetChildren()) do
			local dyn = zone:FindFirstChild("Dynamic")
			local model = dyn and dyn:FindFirstChild(name)
			if model then
				return model
			end
		end
		return nil
	end

	function M.dynamicsMatching(prefix: string)
		local list = {}
		local map = M.map()
		if not map then
			return list
		end
		for _, zone in ipairs(map:GetChildren()) do
			local dyn = zone:FindFirstChild("Dynamic")
			if dyn then
				for _, model in ipairs(dyn:GetChildren()) do
					if string.sub(model.Name, 1, #prefix) == prefix then
						table.insert(list, model)
					end
				end
			end
		end
		return list
	end

	-- ===== Решётки =====

	local function gateRecord(name: string)
		local record = cache.gates[name]
		if record and record.model.Parent then
			return record
		end
		local model = M.dynamic(name)
		if not model then
			warn("[FloorMap] нет решётки " .. name)
			return nil
		end
		-- Запечённая заглушка проёма: невидимая коллизия ровно в центре решётки
		-- (≈ «ширина решётки × 3.5 × 4»). Она перекрывает проход даже когда решётка
		-- поднята — гасим её при первом обращении. На карте v3 таких не должно
		-- остаться, но проверка дешёвая и защищает от повторной запечки.
		local pivot = model:GetPivot().Position
		for _, part in ipairs(Workspace:GetPartBoundsInBox(CFrame.new(pivot), Vector3.new(3, 12, 3))) do
			if part:IsA("BasePart") and part.CanCollide and part.Transparency >= 0.9 and not part:IsDescendantOf(model) then
				local s = part.Size
				if s.Y >= 3 and s.Y <= 5 and s.Z >= 3 and s.Z <= 5 and s.X >= 9 and s.X <= 13 then
					part.CanCollide = false
					part:SetAttribute("DoorwayFiller", true)
				end
			end
		end
		local collider, height = nil, 6
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part.Transparency >= 0.99 then
				collider = part
				height = part.Size.Y
			end
		end
		if not model.PrimaryPart and collider then
			model.PrimaryPart = collider
		end
		record = { model = model, closed = model:GetPivot(), height = height, collider = collider, open = false }
		cache.gates[name] = record
		return record
	end

	-- open = true — решётка поднята (проход свободен).
	function M.setGate(name: string, open: boolean, instant: boolean?)
		local record = gateRecord(name)
		if not record then
			return
		end
		if record.open == open and not instant then
			return
		end
		record.open = open
		local target = open and (record.closed + Vector3.new(0, record.height - 0.6, 0)) or record.closed
		if record.collider then
			record.collider.CanCollide = not open
		end
		if instant then
			record.model:PivotTo(target)
			return
		end
		-- Модель двигаем через CFrameValue: у Model нет свойства для твина.
		local value = Instance.new("CFrameValue")
		value.Value = record.model:GetPivot()
		value.Changed:Connect(function(cf)
			if record.model.Parent then
				record.model:PivotTo(cf)
			end
		end)
		local tween = TweenService:Create(value, TweenInfo.new(settings.GateTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = target })
		tween.Completed:Connect(function()
			value:Destroy()
		end)
		tween:Play()
	end

	function M.gatePosition(name: string): Vector3?
		local record = gateRecord(name)
		return record and record.closed.Position or nil
	end

	-- ===== Печати памяти (проёмы без решёток) =====

	local function sealKey(box): string
		return table.concat(box, ",")
	end

	function M.setSeal(box, on: boolean)
		local key = sealKey(box)
		local part = cache.seals[key]
		if on and not part then
			part = Instance.new("Part")
			part.Name = "MemorySeal"
			part.Anchored = true
			part.CanCollide = true
			part.CanQuery = true
			part.CanTouch = false
			part.CastShadow = false
			part.Material = Enum.Material.ForceField
			part.Color = settings.Seal.color
			part.Transparency = settings.Seal.transparency
			part.Size = Vector3.new(box[4] - box[1], box[5] - box[2], box[6] - box[3])
			part.CFrame = CFrame.new((box[1] + box[4]) / 2, (box[2] + box[5]) / 2, (box[3] + box[6]) / 2)
			part:SetAttribute("Seal", true)
			part.Parent = runtimeFolder()
			cache.seals[key] = part
		elseif not on and part then
			part:Destroy()
			cache.seals[key] = nil
		end
	end

	-- ===== Видимость/коллизия модели (доски моста, баррикады) =====

	local function remember(model)
		if cache.pieces[model] then
			return cache.pieces[model]
		end
		local list = {}
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				list[part] = { transparency = part.Transparency, canCollide = part.CanCollide, canQuery = part.CanQuery }
			end
		end
		cache.pieces[model] = list
		return list
	end

	local function setPresent(model, present: boolean)
		local list = remember(model)
		for part, saved in pairs(list) do
			if part.Parent then
				part.Transparency = present and saved.transparency or 1
				part.CanCollide = present and saved.canCollide or false
				part.CanQuery = present and saved.canQuery or false
			end
		end
		model:SetAttribute("Broken", not present)
	end

	-- Пробить доски моста в радиусе (взрыв Треснувшего). Возвращает центры
	-- пробитых плит — клиенту для обломков.
	function M.breakTiles(prefix: string, position: Vector3, radius: number, duration: number)
		local centers = {}
		for _, model in ipairs(M.dynamicsMatching(prefix)) do
			local pivot = model:GetBoundingBox().Position
			local flat = Vector3.new(pivot.X - position.X, 0, pivot.Z - position.Z)
			if flat.Magnitude <= radius and not model:GetAttribute("Broken") then
				setPresent(model, false)
				cache.broken[model] = now() + duration
				table.insert(centers, pivot)
			end
		end
		return centers
	end

	-- Разрушить (спрятать) динамическую модель целиком: баррикада.
	function M.destroyDynamic(name: string)
		local model = M.dynamic(name)
		if model then
			setPresent(model, false)
			return model:GetBoundingBox().Position
		end
		return nil
	end

	-- Восстановление пробитых досок по таймеру.
	function M.step()
		local t = now()
		for model, untilT in pairs(cache.broken) do
			if t >= untilT then
				cache.broken[model] = nil
				if model.Parent then
					setPresent(model, true)
				end
			end
		end
	end

	-- ===== Внутренняя решётка Зала лебёдки =====

	local innerGate = nil

	function M.setRaise(name: string, progress: number, height: number?)
		local model = M.dynamic(name)
		if not model then
			return
		end
		if not innerGate or innerGate.model ~= model then
			innerGate = { model = model, base = model:GetPivot() }
		end
		local h = height or 9.5
		model:PivotTo(innerGate.base + Vector3.new(0, h * math.clamp(progress, 0, 1), 0))
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = progress < 0.6
			end
		end
	end

	-- ===== Створки Ворот Хранилища =====

	local doors = {}

	function M.openVault(names, open: boolean, instant: boolean?)
		for index, name in ipairs(names) do
			local model = M.dynamic(name)
			if model then
				doors[name] = doors[name] or model:GetPivot()
				local side = index == 1 and -1 or 1
				local target = open and (doors[name] + Vector3.new(side * 6.2, 0, 0)) or doors[name]
				if instant then
					model:PivotTo(target)
				else
					local value = Instance.new("CFrameValue")
					value.Value = model:GetPivot()
					value.Changed:Connect(function(cf)
						model:PivotTo(cf)
					end)
					local tween = TweenService:Create(value, TweenInfo.new(2.4, Enum.EasingStyle.Sine), { Value = target })
					tween.Completed:Connect(function()
						value:Destroy()
					end)
					tween:Play()
				end
				for _, part in ipairs(model:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = not open
					end
				end
			end
		end
	end

	-- ===== Костёр (ProximityPrompt, как в старом этаже) =====

	function M.makeCampfirePrompt(position: Vector3, zoneId: string)
		local anchor = Instance.new("Part")
		anchor.Name = "Campfire_" .. zoneId
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(4, 1, 4)
		anchor.CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0))
		anchor:SetAttribute("IsCampfire", true)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "CampfirePrompt"
		prompt.ActionText = "Отдохнуть у костра"
		prompt.ObjectText = "Костёр"
		prompt.HoldDuration = Rooms.Campfire.interact
		prompt.MaxActivationDistance = Rooms.Campfire.distance + 2
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = anchor
		anchor.Parent = runtimeFolder()
		return anchor, prompt
	end

	-- ===== Шипы (плиты из мешей — неподвижны; иглы создаём здесь) =====

	function M.makeSpikes(position: Vector3)
		local needles = {}
		for ix = -1, 1 do
			for iz = -1, 1 do
				local needle = Instance.new("Part")
				needle.Name = "Needle"
				needle.Anchored = true
				needle.CanCollide = false
				needle.CanQuery = false
				needle.CanTouch = false
				needle.Material = Enum.Material.Metal
				needle.Color = Color3.fromRGB(69, 69, 78)
				needle.Size = Vector3.new(0.4, 2.0, 0.4)
				needle.CFrame = CFrame.new(position.X + ix * 1.35, position.Y - 1.3, position.Z + iz * 1.35)
				needle.Parent = runtimeFolder()
				table.insert(needles, needle)
			end
		end
		return { needles = needles, position = position, phase = "idle" }
	end

	function M.setSpikePhase(trap, phase: string)
		if trap.phase == phase then
			return
		end
		trap.phase = phase
		for _, needle in ipairs(trap.needles) do
			local y = trap.position.Y + (phase == "active" and 0.9 or (phase == "warn" and -0.65 or -1.3))
			TweenService:Create(needle, TweenInfo.new(phase == "active" and 0.08 or 0.2, Enum.EasingStyle.Quad), {
				Position = Vector3.new(needle.Position.X, y, needle.Position.Z),
				Color = phase == "active" and Color3.fromRGB(217, 210, 197) or (phase == "warn" and Color3.fromRGB(201, 139, 74) or Color3.fromRGB(69, 69, 78)),
			}):Play()
		end
	end

	-- ===== Сброс =====

	function M.clearRuntime()
		if cache.runtime then
			cache.runtime:Destroy()
			cache.runtime = nil
		end
		cache.seals = {}
	end

	-- Вернуть карту в исходное: решётки по заданному состоянию, доски и баррикады
	-- на месте, внутренняя решётка опущена, створки закрыты.
	function M.reset(gateStates)
		M.clearRuntime()
		for model in pairs(cache.broken) do
			if model.Parent then
				setPresent(model, true)
			end
		end
		cache.broken = {}
		for model in pairs(cache.pieces) do
			if model.Parent and model:GetAttribute("Broken") then
				setPresent(model, true)
			end
		end
		for name, open in pairs(gateStates or {}) do
			local record = gateRecord(name)
			if record then
				record.open = not open -- чтобы setGate не пропустил
				M.setGate(name, open, true)
			end
		end
		if innerGate and innerGate.model.Parent then
			M.setRaise(innerGate.model.Name, 0)
		end
		for name in pairs(doors) do
			M.openVault({ name }, false, true)
		end
	end


	return M
end

FloorMap.new = create
local default = create(Floor1v2.MapName, Floor1v2)
for key, value in pairs(default) do
	FloorMap[key] = value
end

return FloorMap
