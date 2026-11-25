--!nonstrict
-- HubService (сервер)
-- Хаб «Долина Последнего Эха»: спавн, станции, Стена забытых имён, Врата
-- Печатей (вход на этаж), жители и задания Гильдии.
--
-- Сама долина — готовая сборка Workspace.Hub (Hub.rbxmx, сдвинута на
-- HubLayout.Origin). Код её не строит и не меняет, только ставит точки
-- станций и подключает к ним системы.
--
-- Как это живёт рядом с остальным проектом:
--   * Игрок получает атрибут Zone: "Hub" или "Floor". Сразу после входа это "Hub".
--   * FloorService обслуживает только игроков с Zone == "Floor". После смерти
--     на этаже он переводит игрока в "Hub", и респавн происходит здесь.
--   * Первое появление за сессию — в Чертоге Пробуждения (пещера); возврат
--     с этажа, смерть и последующие появления — перед Вратами Печатей.
--     Кнопка «Начало пути» снова ставит в пещеру.
--   * Всё валидируется на сервере: клиент присылает намерение (открыть станцию,
--     войти на этаж, взять задание), решение принимает сервер.
--
-- Хуки для будущих систем: HubService.registerStation(id, handler).
-- handler(player, station) -> таблица payload для клиента или nil.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local RemoteGuard = require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("RemoteGuard"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Hub = require(Shared.Config.Hub)
local HubLayout = require(Shared.Config.HubLayout)
local Palette = require(Shared.Config.Palette)
local Chests = require(Shared.Config.Chests)
local VillagerService = require(script.Parent.VillagerService)
local QuestService = require(script.Parent.QuestService)
local DailyService = require(script.Parent.DailyService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local UiNet = require(Shared.Net.UiNet)
local Net = require(Shared.Net.Net)

local HubService = {}

local PIXEL_FONT = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Regular)

local state = {
	root = nil,
	net = nil,
	remotes = {},
	anchors = {}, -- [stationId] = Part
	handlers = {}, -- [stationId] = function
	throttle = {}, -- [player] = { [key] = os.clock() }
	awoke = {}, -- [player] = true после первого появления в пещере
	nextSpawn = {}, -- [player] = "cave" | "gate" — куда поставить при следующем появлении
	defaultSpawn = nil,
	namesLabel = nil,
	started = false,
}

----------------------------------------------------------------------
-- Утилиты
----------------------------------------------------------------------

local function systems(name: string)
	local folder = ServerScriptService:FindFirstChild("Systems")
	local module = folder and folder:FindFirstChild(name)
	if not module then
		return nil
	end
	local ok, result = pcall(require, module)
	return ok and result or nil
end

local function rootPart(player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function allowed(player, key: string, seconds: number): boolean
	local bucket = state.throttle[player]
	if not bucket then
		bucket = {}
		state.throttle[player] = bucket
	end
	local now = os.clock()
	if bucket[key] and now - bucket[key] < seconds then
		return false
	end
	bucket[key] = now
	return true
end

local function horizontal(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function remote(name: string, className: string)
	local existing = state.net:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = state.net
	state.remotes[name] = created
	return created
end

local function findPath(root: Instance, path: string): Instance?
	local node = root
	for name in string.gmatch(path, "[^%.]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

function HubService.isInHub(player): boolean
	return player:GetAttribute("Zone") == "Hub"
end

----------------------------------------------------------------------
-- Прогресс этажей (читаем профиль, если поле есть; иначе считаем «ничего не пройдено»)
-- Формат, который ждёт хаб: profile.floorClears[floorId] = { normal = true, hard = true, ... }
----------------------------------------------------------------------

local function clears(player)
	local DataService = systems("DataService")
	local profile = DataService and DataService.get and DataService.get(player)
	return profile and profile.floorClears or {}
end

function HubService.floorAccess(player)
	local cleared = clears(player)
	local result = {}
	for _, floor in ipairs(Hub.Floors) do
		local previous = cleared[floor.id - 1]
		local unlocked = floor.id == 1 or (previous ~= nil and previous[Hub.FloorUnlockDifficulty] == true)
		local own = cleared[floor.id] or {}
		local difficulties = {}
		for index, difficulty in ipairs(Hub.Difficulties) do
			local open = unlocked
			if open and Hub.SequentialDifficulties and index > 1 then
				open = own[Hub.Difficulties[index - 1].id] == true
			end
			difficulties[difficulty.id] = open
		end
		result[floor.id] = {
			id = floor.id,
			name = floor.name,
			theme = floor.theme,
			colors = floor.colors,
			built = floor.built,
			unlocked = unlocked,
			difficulties = difficulties,
		}
	end
	return result
end

local function highestUnlocked(player): number
	local highest = 1
	for id, info in pairs(HubService.floorAccess(player)) do
		if info.unlocked and id > highest then
			highest = id
		end
	end
	return highest
end

----------------------------------------------------------------------
-- Точки появления
----------------------------------------------------------------------

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

-- Высота пола под точкой (только детали долины): персонаж встаёт ровно на пол.
local function standOn(position: Vector3): Vector3
	if state.root then
		groundParams.FilterDescendantsInstances = { state.root }
		local hit = Workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), groundParams)
		if hit then
			return hit.Position + Vector3.new(0, 3.2, 0)
		end
	end
	return position + Vector3.new(0, 3.2, 0)
end

-- Чертог Пробуждения: плита в пещере, лицом к выходу (−Z).
local function caveCFrame(): CFrame
	local position = standOn(HubLayout.world(HubLayout.Points.Spawn))
	return CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
end

-- Перед Вратами Печатей, лицом к долине.
local function gateCFrame(): CFrame
	local portal = HubLayout.world(HubLayout.Points.ReturnFromFloor)
	local look = Vector3.new(1, 0, 0)
	local gate = state.root and findPath(state.root, "Pass.SealGate")
	if gate and gate:IsA("Model") then
		local vector = gate:GetPivot().LookVector
		look = Vector3.new(vector.X, 0, vector.Z).Unit
	end
	local position = standOn(portal + look * HubLayout.ReturnDistance)
	return CFrame.lookAt(position, position + look)
end

local function spawnCFrame(kind: string): CFrame
	return kind == "cave" and caveCFrame() or gateCFrame()
end

local function streamAround(player, position: Vector3)
	-- StreamingEnabled: просим клиент подгрузить место назначения до телепорта.
	pcall(function()
		player:RequestStreamAroundAsync(position, 4)
	end)
end

local function pivot(player, cframe: CFrame)
	local character = player.Character
	if character then
		character:PivotTo(cframe)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local function shield(player, seconds: number)
	local character = player.Character
	if not character or seconds <= 0 then
		return
	end
	local field = Instance.new("ForceField")
	field.Visible = false
	field.Parent = character
	task.delay(seconds, function()
		if field.Parent then
			field:Destroy()
		end
	end)
end

-- «Сборка» из кубиков у всех клиентов; banner — ключ Hub.Banners для самого игрока.
local function announce(player, cframe: CFrame, banner: string)
	shield(player, Hub.ForceFieldSeconds)
	state.remotes.HubAwaken:FireAllClients(cframe, player.UserId, banner)
end

local function heal(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = humanoid.MaxHealth
	end
end

-- Куда ставить при следующем появлении: первое за сессию — пещера.
local function takeSpawnKind(player): string
	local kind = state.nextSpawn[player]
	state.nextSpawn[player] = nil
	if kind then
		return kind
	end
	return state.awoke[player] and "gate" or "cave"
end

-- Персонаж появился в хабе: ставим на точку. Игрок рождается у старого
-- SpawnLocation (у этажа), поэтому держим его на точке несколько кадров,
-- пока движок не отпустит физику.
local function onCharacterAdded(player, character)
	if not HubService.isInHub(player) then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	player:SetAttribute("ZoneBusy", true)
	local kind = takeSpawnKind(player)
	local target = spawnCFrame(kind)
	streamAround(player, target.Position)

	for _ = 1, 18 do
		if not character.Parent or not HubService.isInHub(player) then
			return
		end
		if horizontal(root.Position, target.Position) > 8 or math.abs(root.Position.Y - target.Position.Y) > 12 then
			pivot(player, target)
		end
		task.wait(0.05)
	end
	if not character.Parent or not HubService.isInHub(player) then
		return
	end
	if horizontal(root.Position, target.Position) > 8 then
		pivot(player, target)
	end
	heal(player)
	if kind == "cave" then
		state.awoke[player] = true
	end
	announce(player, target, kind == "cave" and "cave" or "gate")
	task.wait(0.05)
	player:SetAttribute("ZoneBusy", false)
end

-- Перенести живого персонажа на точку с затемнением экрана.
local function relocate(player, kind: string)
	player:SetAttribute("ZoneBusy", true)
	task.wait(0.5) -- клиент гасит экран
	local target = spawnCFrame(kind)
	streamAround(player, target.Position)
	pivot(player, target)
	task.wait(0.15)
	if kind == "cave" then
		state.awoke[player] = true
	end
	announce(player, target, kind == "cave" and "cave" or "gate")
	task.wait(0.05)
	player:SetAttribute("ZoneBusy", false)
end

----------------------------------------------------------------------
-- Стена забытых имён: на центральной табличке — кто сейчас в долине
----------------------------------------------------------------------

local function setupNamesBoard()
	local surface = state.root and findPath(state.root, "Village.MemorialWall")
	surface = surface and surface:FindFirstChild("LeaderboardSurface", true)
	if not surface or not surface:IsA("BasePart") then
		warn("[HubService] нет LeaderboardSurface у Стены забытых имён")
		return
	end
	local old = surface:FindFirstChild("NamesGui")
	if old then
		old:Destroy()
	end
	-- Табличка смотрит к площади той гранью, что повёрнута к LookVector модели.
	local wall = surface:FindFirstAncestorOfClass("Model")
	local face = Enum.NormalId.Front
	if wall then
		local look = wall:GetPivot().LookVector
		local best = -math.huge
		for _, normal in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
			local dot = surface.CFrame:VectorToWorldSpace(Vector3.FromNormalId(normal)):Dot(look)
			if dot > best then
				best, face = dot, normal
			end
		end
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "NamesGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.06, 0)
	pad.PaddingBottom = UDim.new(0.06, 0)
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.18)
	title.FontFace = PIXEL_FONT
	title.TextScaled = true
	title.TextColor3 = Palette.UI.panel
	title.Text = "В ДОЛИНЕ"
	title.Parent = gui
	local names = Instance.new("TextLabel")
	names.Name = "Names"
	names.BackgroundTransparency = 1
	names.Position = UDim2.fromScale(0, 0.22)
	names.Size = UDim2.fromScale(1, 0.78)
	names.FontFace = PIXEL_FONT
	names.TextScaled = true
	names.TextWrapped = true
	names.TextYAlignment = Enum.TextYAlignment.Top
	names.TextColor3 = Palette.Hub.st4
	names.Text = ""
	names.Parent = gui
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 40
	limit.Parent = names
	gui.Parent = surface
	state.namesLabel = names
end

local function refreshNames()
	if not state.namesLabel then
		return
	end
	local residents = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if HubService.isInHub(player) then
			table.insert(residents, player.DisplayName)
		end
	end
	table.sort(residents)
	state.namesLabel.Text = #residents > 0 and table.concat(residents, "\n") or "· · ·"
end

----------------------------------------------------------------------
-- Зоны и переходы
----------------------------------------------------------------------

local function setZone(player, zone: string)
	player:SetAttribute("Zone", zone)
	refreshNames()
end

-- Вход на этаж: FloorService.enterRun собирает свежий этаж (если на нём
-- никого нет) и ставит игрока во двор крепости (комната 0).
local function enterFloor(player, floorId: number, difficulty: string)
	-- Профиль не загружен — на этаж нельзя: весь прогресс этажа (убийства,
	-- сундуки, золото) писал бы в placeholder, который загрузка выбросит.
	local Data = systems("DataService")
	if Data and Data.status and Data.status(player) ~= "ready" then
		local notify = Net.get("Notify")
		if notify then
			notify:FireClient(player, { kind = "warn", text = "Профиль ещё загружается — попробуй через несколько секунд" })
		end
		return
	end
	player:SetAttribute("ZoneBusy", true)
	task.wait(0.5) -- клиент гасит экран
	if not player.Parent then
		return
	end
	-- Пока гас экран, на этаж мог зайти другой игрок (другая сложность): проверяем ещё раз.
	local Floors = systems("FloorService")
	if Floors and Floors.canEnter then
		local okCall, canEnter, reason = pcall(Floors.canEnter, player, floorId, difficulty)
		if okCall and not canEnter then
			player:SetAttribute("ZoneBusy", false)
			local notify = Net.get("Notify")
			if notify then
				notify:FireClient(player, { kind = "warn", text = reason or "Этаж занят" })
			end
			return
		end
	end
	-- Зону меняем только когда этаж реально собрался: при ошибке enterRun
	-- игрок остаётся в хабе, и логика этажа его не «видит».
	local entered = false
	local FloorService = systems("FloorService")
	if FloorService and FloorService.enterRun then
		local ok, err = pcall(FloorService.enterRun, player)
		if ok then
			entered = true
		else
			warn("[HubService] вход на этаж: " .. tostring(err))
		end
	else
		pivot(player, CFrame.new(Hub.FirstFloorFallback))
		entered = true -- сервис не собран (дебаг-сборка): считаем вход состоявшимся
	end
	if not entered then
		player:SetAttribute("ZoneBusy", false)
		local notify = Net.get("Notify")
		if notify then
			notify:FireClient(player, { kind = "warn", text = "Этаж не собрался — попробуй ещё раз" })
		end
		return
	end
	player:SetAttribute("FloorId", floorId)
	player:SetAttribute("FloorDifficulty", difficulty)
	setZone(player, "Floor")
	player.RespawnLocation = state.defaultSpawn
	task.wait(0.2)
	player:SetAttribute("ZoneBusy", false)
	-- Отряд: лидер вошёл на этаж — члены в хабе следуют за ним (каждому свой лут).
	local Party = systems("PartyService")
	if Party and Party.onLeaderEnteredFloor then
		pcall(Party.onLeaderEnteredFloor, player, floorId, difficulty)
	end
end
-- Для отладочной команды «floor» (DebugCommands, только Studio).
HubService.enterFloor = enterFloor

function HubService.returnToHub(player)
	if HubService.isInHub(player) then
		return false
	end
	player:SetAttribute("ZoneBusy", true)
	task.wait(0.5)

	-- В хабе игрок меняет билд: временные стаки душ сбрасываются, здоровье полное.
	local Progression = systems("ProgressionService")
	if Progression and Progression.resetStacks then
		pcall(Progression.resetStacks, player)
	end
	heal(player)

	setZone(player, "Hub")
	player:SetAttribute("FloorId", nil)
	player:SetAttribute("FloorDifficulty", nil)
	player:SetAttribute("FloorsUnlocked", highestUnlocked(player))
	local target = gateCFrame()
	streamAround(player, target.Position)
	pivot(player, target)
	task.wait(0.15)
	announce(player, target, "gate")
	task.wait(0.05)
	player:SetAttribute("ZoneBusy", false)
	return true
end

----------------------------------------------------------------------
-- Станции
----------------------------------------------------------------------

function HubService.registerStation(id: string, handler)
	state.handlers[id] = handler
end

local function setupAnchors()
	local old = Workspace:FindFirstChild("HubStations")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "HubStations"
	for id, station in pairs(Hub.Stations) do
		local point = HubLayout.Points[station.point]
		if point then
			local anchor = Instance.new("Part")
			anchor.Name = "Station_" .. id
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			anchor.Transparency = 1
			anchor.Size = Vector3.new(1, 1, 1)
			anchor.Position = HubLayout.world(point)
			anchor:SetAttribute("StationId", id)
			anchor:SetAttribute("Verb", station.verb)
			CollectionService:AddTag(anchor, "HubStation")
			anchor.Parent = folder
			state.anchors[id] = anchor
		else
			warn("[HubService] у станции " .. id .. " нет точки " .. tostring(station.point))
		end
	end
	folder.Parent = Workspace
end

-- В сборке под озером нет ни одной детали с коллизией (берег, вода и мостки
-- CanCollide = false), и игрок проваливался в пустоту. Модели не трогаем:
-- кладём рядом невидимые опоры — мелководье чуть ниже воды (бродить можно)
-- и настил под досками мостков.
local function invisibleCollider(parent, name: string, size: Vector3, cframe: CFrame, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = true
	part.CanTouch = false
	part.Transparency = 1
	part.CastShadow = false
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe
	part.Parent = parent
	return part
end

-- Настил под досками (в осях самих досок) и, если нужно, перила по длинным краям.
local function deckUnder(folder, model: Instance?, plankName: string, railHeight: number?)
	if not model then
		return
	end
	local frame, minV, maxV = nil, nil, nil
	for _, plank in ipairs(model:GetDescendants()) do
		if plank:IsA("BasePart") and plank.Name == plankName then
			frame = frame or (plank.CFrame - plank.Position)
			local half = plank.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local corner = frame:PointToObjectSpace(plank.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y, half.Z * sz)))
					minV = minV and minV:Min(corner) or corner
					maxV = maxV and maxV:Max(corner) or corner
				end
			end
		end
	end
	if not minV then
		return
	end
	local center = frame:PointToWorldSpace(Vector3.new((minV.X + maxV.X) / 2, maxV.Y - 0.5, (minV.Z + maxV.Z) / 2))
	local size = Vector3.new(maxV.X - minV.X, 1, maxV.Z - minV.Z)
	local deck = frame + center
	invisibleCollider(folder, plankName .. "Deck", size, deck)
	if railHeight then
		-- Перила вдоль длинной стороны настила.
		local alongX = size.X >= size.Z
		for _, side in ipairs({ -1, 1 }) do
			local offset = alongX and Vector3.new(0, railHeight / 2, side * (size.Z / 2 + 0.25)) or Vector3.new(side * (size.X / 2 + 0.25), railHeight / 2, 0)
			local railSize = alongX and Vector3.new(size.X, railHeight, 0.5) or Vector3.new(0.5, railHeight, size.Z)
			invisibleCollider(folder, plankName .. "Rail", railSize, deck * CFrame.new(offset))
		end
	end
end

local function setupColliders()
	local old = Workspace:FindFirstChild("HubColliders")
	if old then
		old:Destroy()
	end
	if not state.root then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "HubColliders"
	local shore = findPath(state.root, "World.Water.Shore")
	if shore and shore:IsA("BasePart") and not shore.CanCollide then
		-- Диск берега: верх на Hub.LakeBedDepth ниже поверхности.
		local diameter = math.max(shore.Size.Y, shore.Size.Z)
		local top = shore.Position.Y - Hub.LakeBedDepth
		invisibleCollider(folder, "LakeBed", Vector3.new(2, diameter, diameter),
			CFrame.new(shore.Position.X, top - 1, shore.Position.Z) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
	end
	deckUnder(folder, findPath(state.root, "Lake.DockBoat"), "DockPlank")
	-- Подвесной мост: настил; боковые стенки BridgeGuard уже в модели.
	deckUnder(folder, findPath(state.root, "Cave.Cave"), "BridgePlank")
	-- Западная стенка BridgeGuard закрывает вход на мост от площадки (за ней камень
	-- на высоте 23): вход открыт, падение в неглубокое ущелье безопасно.
	local bridgeModel = findPath(state.root, "Cave.Cave")
	for _, guard in ipairs(bridgeModel and bridgeModel:GetDescendants() or {}) do
		if guard.Name == "BridgeGuard" and guard:IsA("BasePart") and guard.Position.X < 4 then
			guard.CanCollide = false
		end
	end
	for index, patch in ipairs(HubLayout.FloorPatches) do
		if patch.from then
			local from, to = HubLayout.world(patch.from), HubLayout.world(patch.to)
			local middle = (from + to) / 2
			local frame = CFrame.lookAt(middle, to)
			invisibleCollider(folder, "FloorRamp" .. index, Vector3.new(patch.width, 1, (to - from).Magnitude + 0.5),
				frame * CFrame.new(0, -0.5, 0))
		else
			invisibleCollider(folder, "FloorPatch" .. index, patch.size, CFrame.new(HubLayout.world(patch.center)))
		end
	end
	folder.Parent = Workspace

	-- Невидимое кольцо границы мира (радиус 310) проходит поперёк пещеры, прямо
	-- через мост: из Чертога было не выйти. Над пещерой границу держит сама
	-- Гора Сердца, поэтому у сегментов кольца внутри зоны пещеры (по плану)
	-- снимаем коллизию. Только на время игры, файл места не меняется.
	local zone = state.root:FindFirstChild("CaveLightingZone", true)
	local mountains = findPath(state.root, "World.Mountains")
	if zone and mountains then
		for _, wall in ipairs(mountains:GetChildren()) do
			if wall:IsA("BasePart") and wall.Name == "InvisibleWall" then
				local localPos = zone.CFrame:PointToObjectSpace(wall.Position)
				if math.abs(localPos.X) <= zone.Size.X / 2 and math.abs(localPos.Z) <= zone.Size.Z / 2 then
					wall.CanCollide = false
				end
			end
		end
	end
end

local function stationPayload(player, id: string, station)
	local payload = {
		ok = true,
		id = id,
		kind = station.kind,
		title = station.title,
		lines = station.lines and table.clone(station.lines) or nil,
		soon = station.soon,
		status = station.status,
	}
	if station.kind == "portal" then
		payload.floors = HubService.floorAccess(player)
		payload.difficulties = Hub.Difficulties
	elseif station.kind == "quests" then
		payload.quests = QuestService.snapshot(player)
	elseif station.kind == "archive" then
		local extra = QuestService.archivePayload(player)
		payload.lines = payload.lines or {}
		for _, line in ipairs(extra.extraLines or {}) do
			table.insert(payload.lines, line)
		end
		payload.soon = extra.soon
	end
	local handler = state.handlers[id]
	if handler then
		local ok, extra = pcall(handler, player, station)
		if ok and type(extra) == "table" then
			for key, value in pairs(extra) do
				payload[key] = value
			end
		elseif not ok then
			warn("[HubService] обработчик станции " .. id .. ": " .. tostring(extra))
		end
	end
	return payload
end

local function onRequestStation(player, id)
	if typeof(id) ~= "string" or not allowed(player, "station", 0.4) then
		return { ok = false }
	end
	local root = rootPart(player)
	if not root or not HubService.isInHub(player) then
		return { ok = false }
	end
	local reach = Hub.InteractDistance + Hub.ServerInteractSlack

	-- Житель: «villager:<id>».
	local villagerId = string.match(id, "^villager:(.+)$")
	if villagerId then
		local position = VillagerService.position(villagerId)
		if not position or horizontal(root.Position, position) > reach then
			return { ok = false }
		end
		local said = VillagerService.talk(player, villagerId)
		if not said then
			return { ok = false }
		end
		return { ok = true, kind = "talk", id = villagerId, name = said.name, title = said.title, line = said.line, first = said.first }
	end

	local station = Hub.Stations[id]
	local anchor = state.anchors[id]
	if not station or not anchor then
		return { ok = false }
	end
	if horizontal(root.Position, anchor.Position) > reach then
		return { ok = false, err = "Слишком далеко" }
	end
	return stationPayload(player, id, station)
end

local function nearStation(player, id: string): boolean
	local root = rootPart(player)
	local anchor = state.anchors[id]
	return root ~= nil and anchor ~= nil
		and horizontal(root.Position, anchor.Position) <= Hub.InteractDistance + Hub.ServerInteractSlack
end

local function onRequestEnterFloor(player, floorId, difficulty)
	if typeof(floorId) ~= "number" or typeof(difficulty) ~= "string" then
		return { ok = false, err = "Неверный запрос" }
	end
	if not allowed(player, "enter", 2) then
		return { ok = false, err = "Подожди секунду" }
	end
	if not HubService.isInHub(player) or player:GetAttribute("ZoneBusy") then
		return { ok = false, err = "Сейчас нельзя" }
	end
	if not nearStation(player, "portal") then
		return { ok = false, err = "Подойди к Вратам" }
	end

	local info = HubService.floorAccess(player)[floorId]
	if not info then
		return { ok = false, err = "Такого мира нет" }
	end
	if not info.built then
		return { ok = false, err = "Этот мир ещё не готов" }
	end
	if not info.unlocked then
		return { ok = false, err = "Печать закрыта" }
	end
	if info.difficulties[difficulty] ~= true then
		return { ok = false, err = "Сложность закрыта" }
	end
	-- Этаж один на сервер: к чужому забегу — только в начале и на той же сложности.
	local FloorService = systems("FloorService")
	if FloorService and FloorService.canEnter then
		local okCall, canEnter, reason = pcall(FloorService.canEnter, player, floorId, difficulty)
		if okCall and not canEnter then
			return { ok = false, err = reason or "Этаж занят" }
		end
	end

	task.spawn(enterFloor, player, floorId, difficulty)
	return { ok = true }
end

local function onRequestReturnHub(player)
	if not allowed(player, "return", 3) then
		return { ok = false }
	end
	if HubService.isInHub(player) or player:GetAttribute("ZoneBusy") then
		return { ok = false }
	end
	task.spawn(HubService.returnToHub, player)
	return { ok = true }
end

-- «Начало пути»: снова в Чертог Пробуждения (ТЗ, раздел 2, доп.).
local function onRequestJourneyStart(player)
	if not allowed(player, "journey", 3) then
		return { ok = false }
	end
	if not HubService.isInHub(player) or player:GetAttribute("ZoneBusy") then
		return { ok = false }
	end
	task.spawn(relocate, player, "cave")
	return { ok = true }
end

HubService.nearStation = nearStation

----------------------------------------------------------------------
-- Окна-сцены UI v2 (StationApi): Врата Печатей и Лавка Осколков.
-- Сундук дня — DailyService, Стена имён — LeaderboardService, доска — QuestService.
----------------------------------------------------------------------

local NUMERALS = { "I", "II", "III", "IV", "V" }
local WORLD_REWARDS = { [1] = { "coin", "ingot", "soul", "sword" } }
-- Хранители миров — боссы этажей (Config.Chests.Floors[f].boss).
local WORLD_KEEPERS = {}
for floorId, info in ipairs(Chests.Floors) do
	WORLD_KEEPERS[floorId] = info.boss
end

local function wrapLines(text: string, width: number)
	local lines, line = {}, ""
	for word in string.gmatch(text, "%S+") do
		if line ~= "" and utf8.len(line .. " " .. word) > width then
			table.insert(lines, line)
			line = word
		else
			line = line == "" and word or (line .. " " .. word)
		end
	end
	if line ~= "" then
		table.insert(lines, line)
	end
	return lines
end

local function difficultyName(id: string): string
	for _, difficulty in ipairs(Hub.Difficulties) do
		if difficulty.id == id then
			return difficulty.name
		end
	end
	return id
end

local function worldsPayload(player)
	local access = HubService.floorAccess(player)
	local cleared = clears(player)
	local DataService = systems("DataService")
	local profile = DataService and DataService.get(player)
	local best = profile and type(profile.records) == "table" and profile.records or {}
	local roomCount = 7
	local worlds = {}
	for _, floor in ipairs(Hub.Floors) do
		local info = access[floor.id]
		local own = cleared[floor.id] or {}
		local world = {
			id = floor.id,
			numeral = NUMERALS[floor.id] or tostring(floor.id),
			name = floor.name,
			keeper = WORLD_KEEPERS[floor.id] or "???",
			rewards = WORLD_REWARDS[floor.id] or {},
			theme = floor.theme,
		}
		-- Карта Врат: сложности и победы — у каждого мира свои.
		local worldDifficulties, passedIds = {}, {}
		for _, difficulty in ipairs(Hub.Difficulties) do
			local passed = own[difficulty.id] == true
			table.insert(worldDifficulties, {
				id = difficulty.id,
				name = difficulty.name,
				locked = not (info.unlocked and floor.built and info.difficulties[difficulty.id] == true),
				passed = passed,
			})
			if passed then
				table.insert(passedIds, difficulty.id)
			end
		end
		world.difficulties = worldDifficulties
		world.cleared = passedIds
		world.bossDefeated = #passedIds > 0
		if info.unlocked and floor.built then
			world.state = own[Hub.Difficulties[#Hub.Difficulties].id] and "done" or "open"
			world.sub = floor.theme
			world.desc = wrapLines(floor.theme .. ".", 20)
			local passed = {}
			for _, difficulty in ipairs(Hub.Difficulties) do
				if own[difficulty.id] then
					table.insert(passed, difficulty.name)
				end
			end
			if #passed > 0 then
				world.record = "пройден: " .. passed[#passed]
				world.recordRatio = 1
			elseif best.floor == floor.id then
				world.record = ("комната %d/%d"):format(best.room or 0, roomCount)
				world.recordRatio = (best.room or 0) / roomCount
			else
				world.record = "—"
				world.recordRatio = 0
			end
		else
			world.state = "locked"
			local previous = access[floor.id - 1]
			if info.unlocked then
				world.sub = "Скоро: мир ещё не готов"
			elseif previous and previous.unlocked then
				world.sub = ("Пройди «%s» на сложности «%s»"):format(Hub.Floors[floor.id - 1].name, difficultyName(Hub.FloorUnlockDifficulty))
			else
				world.name = "???"
				world.hidden = true
				world.theme = nil
				world.sub = "Печать " .. (NUMERALS[floor.id - 1] or "")
			end
		end
		table.insert(worlds, world)
	end
	-- Сложности окно показывает общими: берём их у первого открытого мира.
	local first = access[1]
	for _, floor in ipairs(Hub.Floors) do
		if access[floor.id].unlocked and floor.built then
			first = access[floor.id]
		end
	end
	local difficulties = {}
	local selected = nil
	for _, difficulty in ipairs(Hub.Difficulties) do
		local open = first.difficulties[difficulty.id] == true
		table.insert(difficulties, { id = difficulty.id, name = difficulty.name, locked = not open })
		selected = selected or (open and difficulty.id or nil)
	end
	-- Сундуки в сумке (ключ f<этаж>_<grade> → число), класс и уровень — для
	-- меню этажа и витрины лута (Config.ChestPreview на клиенте).
	local bag = {}
	if profile and type(profile.chests) == "table" then
		for key, count in pairs(profile.chests) do
			if type(key) == "string" and type(count) == "number" then
				bag[key] = count
			end
		end
	end
	return {
		worlds = worlds,
		difficulties = difficulties,
		selectedDifficulty = selected,
		chests = bag,
		chestsOpened = profile and profile.stats and profile.stats.chestsOpened or 0,
		className = profile and profile.className or player:GetAttribute("ClassName") or "warrior",
		level = profile and profile.level or player:GetAttribute("Level") or 1,
		unlockDifficulty = difficultyName(Hub.FloorUnlockDifficulty),
	}
end

local function onEnterWorld(player, worldId, difficultyId)
	local result = onRequestEnterFloor(player, worldId, difficultyId)
	return { ok = result.ok == true, reason = result.err }
end

-- Лавка: решение владельца 23.10.2026 — окно есть, покупок нет, пока нет
-- списка товаров («сила здесь не продаётся, только вид»).
local function shopPayload()
	return {
		items = {},
		restockIn = nil,
		line = { "Скины клинков и цвет поглощения душ.", "Сила здесь не продаётся, только вид. Товар скоро." },
	}
end

----------------------------------------------------------------------
-- Запуск
----------------------------------------------------------------------

local function onPlayerAdded(player)
	-- Раньше любого CharacterAdded: игрок «в хабе», экран закрыт до пробуждения.
	player:SetAttribute("Zone", "Hub")
	player:SetAttribute("ZoneBusy", true)
	player:SetAttribute("FloorsUnlocked", highestUnlocked(player))

	player.CharacterAdded:Connect(function(character)
		task.spawn(onCharacterAdded, player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	player:GetAttributeChangedSignal("Zone"):Connect(refreshNames)
	refreshNames()
end

local function onPlayerRemoving(player)
	state.throttle[player] = nil
	state.awoke[player] = nil
	state.nextSpawn[player] = nil
	task.defer(refreshNames)
end

function HubService.start()
	if state.started then
		return
	end
	state.started = true

	-- Отряд: авто-вход членов за лидером зовёт HubService.enterFloor.
	do
		local Party = systems("PartyService")
		if Party and Party.setHub then
			pcall(Party.setHub, HubService)
		end
	end

	-- Профиль загрузился — обновляем печати Врат: при входе атрибут ставился
	-- по заглушке (всегда 1) и до первого возврата с этажа оставался неверным.
	do
		local Data = systems("DataService")
		if Data and Data.onLoaded then
			Data.onLoaded(function(player)
				player:SetAttribute("FloorsUnlocked", highestUnlocked(player))
			end)
		end
	end

	state.root = Workspace:FindFirstChild(Hub.FolderName)
	if not state.root then
		warn("[HubService] нет Workspace." .. Hub.FolderName .. ": вставь Hub.rbxmx (tools/lua/install_hub.lua)")
	end

	local net = ReplicatedStorage:FindFirstChild(Hub.NetFolder)
	if not net then
		net = Instance.new("Folder")
		net.Name = Hub.NetFolder
		net.Parent = ReplicatedStorage
	end
	state.net = net

	remote("HubAwaken", "RemoteEvent")
	remote("RequestStation", "RemoteFunction").OnServerInvoke = RemoteGuard.wrap("RequestStation", onRequestStation)
	remote("RequestEnterFloor", "RemoteFunction").OnServerInvoke = RemoteGuard.wrap("RequestEnterFloor", onRequestEnterFloor)
	remote("RequestReturnHub", "RemoteFunction").OnServerInvoke = RemoteGuard.wrap("RequestReturnHub", onRequestReturnHub)
	remote("RequestJourneyStart", "RemoteFunction").OnServerInvoke = RemoteGuard.wrap("RequestJourneyStart", onRequestJourneyStart)

	-- Прежний SpawnLocation остаётся для респавна внутри этажа.
	for _, descendant in ipairs(Workspace:GetChildren()) do
		if descendant:IsA("SpawnLocation") then
			state.defaultSpawn = descendant
			break
		end
	end

	UiNet.ensure("GetWorlds").OnServerInvoke = RemoteGuard.wrap("GetWorlds", worldsPayload)
	UiNet.ensure("EnterWorld").OnServerInvoke = RemoteGuard.wrap("EnterWorld", onEnterWorld)
	UiNet.ensure("GetShop").OnServerInvoke = RemoteGuard.wrap("GetShop", shopPayload)
	UiNet.ensure("BuyShopItem").OnServerInvoke = RemoteGuard.wrap("BuyShopItem", function()
		return { ok = false, reason = "soon" }
	end)
	DailyService.start(HubService)
	LeaderboardService.start()

	setupColliders()
	setupAnchors()
	setupNamesBoard()
	do
		local ok, err = pcall(function()
			QuestService.start(net)
			QuestService.bindVillagers(VillagerService)
		end)
		if not ok then
			warn("[HubService] QuestService старт упал: " .. tostring(err) .. "\n" .. debug.traceback(nil, 2))
		end
		print("[HubService] QuestService старт завершён (ok=" .. tostring(ok) .. ")")
	end
	VillagerService.start()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	-- Страховка от падения: вернуть к Вратам.
	local fallY = HubLayout.Origin.Y + Hub.FallY
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0
		for _, player in ipairs(Players:GetPlayers()) do
			if HubService.isInHub(player) and not player:GetAttribute("ZoneBusy") then
				local root = rootPart(player)
				if root and root.Position.Y < fallY and horizontal(root.Position, HubLayout.Origin) < HubLayout.Radius + 200 then
					task.spawn(relocate, player, "gate")
				end
			end
		end
	end)

	local stations = 0
	for _ in pairs(state.anchors) do
		stations += 1
	end
	print(("[HubService] «%s»: станций %d"):format(Hub.Name, stations))
end

return HubService
