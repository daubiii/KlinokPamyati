--!nonstrict
-- StationController (клиент)
-- Окна-сцены станций: при открытии камера плавно наезжает на станцию (или
-- через затемнение переносится в отдельную сцену — Горнило), включается свой
-- свет, HUD прячется, управление замирает, открывается окно из Windows/.
--
-- Как открыть:
--   • ProximityPrompt с атрибутом Station = "Forge" | "DailyChest" | "Gate" | "Wall" | "Board" | "Shop";
--   • из кода: StationController.open("Inventory");
--   • разговор с жителем: StationController.open("Talk", { villager = id, talk = payload });
--   • клавиша I / Tab — снаряжение.
-- Закрыть: крестик, Backspace, Esc (вместе с меню Roblox). Backspace сначала
-- зовёт module.back() — вложенные меню окна закрываются по одному.

local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Lib = script.Parent.Parent.Lib
local Bus = require(Lib.Bus)
local UiFx = require(Lib.UiFx)
local UiSound = require(Lib.UiSound)
local StationApi = require(Lib.StationApi)
local Binds = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Binds)
local ClientState = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Util.ClientState)

local Windows = script.Parent.Parent:WaitForChild("Windows")

local StationController = {}

local player = Players.LocalPlayer

-- Камера: позиция и точка взгляда в локальных координатах модели станции
-- (лицо модели смотрит в −Z). FOV — вертикальный угол Roblox.
-- part — вместо модели взять деталь по имени (её CFrame как pivot): у доски
-- заданий в сборке хаба нет своей модели, только щит QuestSurface в гильдии.
StationController.Stations = {
	Forge = {
		window = "ForgeWindow",
		scene = "ForgeStage", -- отдельная комната (вне карты): переход через затемнение
		lighting = "forge",
		fov = 37,
	},
	DailyChest = {
		window = "ChestWindow",
		model = "DailyChest",
		cam = Vector3.new(0, 11.5, -27),
		look = Vector3.new(0, 4, 3),
		lighting = "dusk",
		fov = 37,
	},
	Gate = {
		window = "GateWindow",
		model = "SealGate",
		cam = Vector3.new(0, 19, -76),
		look = Vector3.new(0, 19, 0),
		lighting = "dusk",
		fov = 37,
	},
	Wall = {
		window = "WallWindow",
		model = "MemorialWall",
		cam = Vector3.new(0, 9.5, -35),
		look = Vector3.new(0, 8.5, 0),
		lighting = "dusk",
		fov = 37,
	},
	Board = {
		window = "BoardWindow",
		part = "QuestSurface",
		cam = Vector3.new(0, 0.6, -10),
		look = Vector3.new(0, 0.2, 0),
		fov = 37,
	},
	Shop = {
		window = "ShopWindow",
		model = "ShardShop",
		cam = Vector3.new(-1, 9.5, -36),
		look = Vector3.new(-1, 8.5, 0),
		fov = 37,
	},
	-- «Книга героя»: снаряжение и сумка (I / Tab), герой (C), журнал (J).
	-- Без камеры: витрина персонажа во ViewportFrame. Старое окно — InventoryClassic.
	Inventory = {
		window = "CharacterWindow",
	},
	InventoryClassic = {
		window = "InventoryWindow",
	},
	-- Разговор с жителем долины: камера «из-за плеча» на лицо жителя,
	-- кадр считает само окно (DialogueWindow.cameraTarget по opts.villager).
	Talk = {
		window = "DialogueWindow",
		villager = true,
		fov = 34,
		fly = 0.75,
	},
}

-- Клавиша → вкладка книги героя.
local BOOK_TABS = { Inventory = "gear", Hero = "hero", Journal = "journal", Talents = "talents" }

-- Профили света (локально, только у этого игрока; на закрытии всё возвращается).
local PROFILES = {
	forge = {
		Lighting = { ClockTime = 0, Brightness = 0.4, Ambient = Color3.fromRGB(34, 40, 52), OutdoorAmbient = Color3.fromRGB(26, 30, 40), ExposureCompensation = 0.2 },
		Atmosphere = { Density = 0, Haze = 0 },
	},
	dusk = {
		Lighting = { ClockTime = 19.2, Brightness = 1.2, Ambient = Color3.fromRGB(70, 74, 96), OutdoorAmbient = Color3.fromRGB(96, 100, 130) },
		Atmosphere = { Density = 0.3, Haze = 1.5 },
	},
}

local state: any = {
	open = nil, -- имя открытой станции
	window = nil,
	busy = false,
	saved = nil,
	cameraConn = nil,
	cameraCF = nil,
	modules = {},
}

-- ===== свет =====
local function applyProfile(name: string?)
	local profile = name and PROFILES[name]
	if not profile then
		return
	end
	local saved = { Lighting = {}, Atmosphere = {} }
	for key, value in pairs(profile.Lighting) do
		saved.Lighting[key] = Lighting[key]
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		for key in pairs(profile.Atmosphere) do
			saved.Atmosphere[key] = atmosphere[key]
		end
	end
	state.saved = saved
	local TweenService = game:GetService("TweenService")
	local info = TweenInfo.new(name == "forge" and 0 or 0.9)
	TweenService:Create(Lighting, info, profile.Lighting):Play()
	if atmosphere then
		TweenService:Create(atmosphere, info, profile.Atmosphere):Play()
	end
end

local function restoreProfile(instant: boolean?)
	local saved = state.saved
	if not saved then
		return
	end
	state.saved = nil
	local TweenService = game:GetService("TweenService")
	local info = TweenInfo.new(instant and 0 or 0.7)
	TweenService:Create(Lighting, info, saved.Lighting):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and next(saved.Atmosphere) then
		TweenService:Create(atmosphere, info, saved.Atmosphere):Play()
	end
end

-- ===== камера =====
-- Модель по имени (FindFirstChild может вернуть Attachment-маркер с тем же именем).
local function findModel(name: string)
	local direct = Workspace:FindFirstChild(name, true)
	if direct and direct:IsA("Model") then
		return direct
	end
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("Model") and d.Name == name then
			return d
		end
	end
	return nil
end

local function findPart(name: string)
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == name then
			return d
		end
	end
	return nil
end

local function markerCFrame(model, name: string)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Attachment") and d.Name == name then
			return d.WorldCFrame
		end
	end
	return nil
end

local function cameraTargetFor(def, opts)
	if def.villager then
		local ok, module = pcall(require, Windows:WaitForChild(def.window))
		if ok and module.cameraTarget and opts and opts.villager then
			return module.cameraTarget(opts.villager)
		end
		return nil
	end
	if def.scene then
		local scene = findModel(def.scene)
		if not scene then
			return nil
		end
		local camPoint = markerCFrame(scene, "CamPoint")
		local camLook = markerCFrame(scene, "CamLook")
		if camPoint and camLook then
			return CFrame.lookAt(camPoint.Position, camLook.Position), scene
		end
		return nil
	end
	local model = (def.model and findModel(def.model)) or (def.part and findPart(def.part))
	if not model then
		return nil
	end
	local pivot = model:IsA("BasePart") and model.CFrame or model:GetPivot()
	local pos = pivot:PointToWorldSpace(def.cam)
	local look = pivot:PointToWorldSpace(def.look)
	return CFrame.lookAt(pos, look), model
end

-- Камеру в проекте ведёт CameraController (Scriptable, пишет CFrame каждый
-- кадр), поэтому сцена не перехватывает камеру сама, а ставит его override.
local function cameraController()
	local ok, module = pcall(require, script.Parent.CameraController)
	return ok and module or nil
end

local function holdCamera(target: CFrame, fov: number?, flyTime: number?)
	local camera = Workspace.CurrentCamera
	local controller = cameraController()
	if not controller or not controller.setOverride then
		return
	end
	state.cameraBefore = state.cameraBefore or { fov = camera.FieldOfView }
	local from = camera.CFrame
	local fromFov = camera.FieldOfView
	local toFov = fov or 40
	local started = os.clock()
	local duration = flyTime or 0.9
	UiFx.setSceneCamera(true)
	controller.setOverride(function()
		local t = math.clamp((os.clock() - started) / duration, 0, 1)
		local e = 1 - (1 - t) ^ 3
		local cf = from:Lerp(target, e)
		-- лёгкое «дыхание» камеры, чтобы сцена жила
		local breathe = CFrame.Angles(math.sin(os.clock() * 0.6) * 0.003, math.sin(os.clock() * 0.4) * 0.004, 0)
		return cf * breathe * UiFx.shakeOffset(), fromFov + (toFov - fromFov) * e
	end)
end

local function releaseCamera()
	local controller = cameraController()
	if controller and controller.setOverride then
		controller.setOverride(nil)
	end
	UiFx.setSceneCamera(false)
	local before = state.cameraBefore
	state.cameraBefore = nil
	if before then
		Workspace.CurrentCamera.FieldOfView = before.fov
	end
end

-- ===== управление =====
-- PlayerModule в этой сборке Studio не создаётся (см. CameraController),
-- движение движковое — поэтому героя на время сцены просто «примораживаем»:
-- корень персонажа закреплён локально (клиент владеет физикой персонажа).
local function setControls(enabled: boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not enabled then
		if root and not root.Anchored then
			root.Anchored = true
			state.frozenRoot = root
		end
	elseif state.frozenRoot then
		if state.frozenRoot.Parent then
			state.frozenRoot.Anchored = false
		end
		state.frozenRoot = nil
	end
	-- Бой, рывок и способности смотрят на ClientState; "ui" ещё и освобождает мышь.
	ClientState.lockInput("station", not enabled)
	ClientState.lockInput("ui", not enabled)
	Bus.emit("lockInput", { reason = "station", locked = not enabled })
end

-- ===== окна =====
local function windowModule(name: string)
	if state.modules[name] then
		return state.modules[name]
	end
	local module = require(Windows:WaitForChild(name))
	state.modules[name] = module
	return module
end

function StationController.isOpen(): boolean
	return state.open ~= nil
end

function StationController.open(name: string, opts)
	local def = StationController.Stations[name]
	if not def or state.busy then
		return
	end
	if state.open == name then
		return
	end
	if state.open then
		StationController.close(true)
	end
	state.busy = true
	state.open = name
	UiSound.play("ui_open_scene")
	Bus.emit("hud", { visible = false })
	setControls(false)

	local target, sceneModel = cameraTargetFor(def, opts)
	if def.scene and target then
		-- Отдельная сцена: затемнение → камера в комнате → свет → открыть.
		local reveal = UiFx.fadeOut(0.3)
		applyProfile(def.lighting)
		pcall(function()
			player:RequestStreamAroundAsync(target.Position, 2)
		end)
		holdCamera(target, def.fov, 0.01)
		reveal(0.5)
	elseif target then
		applyProfile(def.lighting)
		holdCamera(target, def.fov, def.fly or 1.0)
	end

	local module = windowModule(def.window)
	local ok, err = pcall(function()
		state.window = module.open({
			station = name,
			tab = opts and opts.tab or nil,
			scene = sceneModel,
			api = StationApi,
			data = opts,
			close = function()
				StationController.close()
			end,
			-- перейти из окна в другую станцию (разговор → доска заданий и т.п.)
			openStation = function(other: string, otherOpts)
				task.defer(StationController.open, other, otherOpts)
			end,
		})
	end)
	if not ok then
		warn("[StationController] окно " .. def.window .. ": " .. tostring(err))
		state.busy = false
		StationController.close()
		return
	end
	state.busy = false
end

function StationController.close(silent: boolean?)
	if not state.open or state.closing then
		return
	end
	state.closing = true
	local def = StationController.Stations[state.open]
	local module = def and state.modules[def.window]
	if module and module.close then
		pcall(module.close)
	end
	if not silent then
		UiSound.play("ui_click")
	end
	if def and def.scene then
		local reveal = UiFx.fadeOut(0.25)
		releaseCamera()
		restoreProfile(true)
		reveal(0.4)
	else
		releaseCamera()
		restoreProfile(false)
	end
	setControls(true)
	Bus.emit("hud", { visible = true })
	state.open = nil
	state.window = nil
	state.closing = false
end

function StationController.start()
	-- Промпты станций.
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		local station = prompt:GetAttribute("Station")
		if station and StationController.Stations[station] then
			StationController.open(station)
		end
	end)
	-- Клавиши.
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Backspace and state.open then
			if UserInputService:GetFocusedTextBox() then
				return
			end
			-- Окно с вложенными меню (Врата: сундук → этаж → карта) сначала
			-- закрывает своё верхнее меню: module.back() вернул true — окно живо.
			local def = StationController.Stations[state.open]
			local module = def and state.modules[def.window]
			if module and module.back then
				local ok, handled = pcall(module.back)
				if ok and handled then
					return
				end
			end
			StationController.close()
		end
	end)
	-- I / Tab, C, J, T: открыть книгу героя на своей вкладке; та же клавиша
	-- закрывает, другая — листает на другую вкладку.
	for action, tab in pairs(BOOK_TABS) do
		if Binds.defaults[action] then
			ContextActionService:BindActionAtPriority("StationBook" .. action, function(_, inputState)
				if inputState ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() then
					return Enum.ContextActionResult.Pass
				end
				local playerGui = player:FindFirstChildOfClass("PlayerGui")
				if playerGui and playerGui:FindFirstChild("IntroCutsceneGui") then
					return Enum.ContextActionResult.Sink
				end
				if state.open == "Inventory" then
					local module = state.modules[StationController.Stations.Inventory.window]
					if module and module.currentTab and module.selectTab and module.currentTab() ~= tab then
						module.selectTab(tab)
					else
						StationController.close()
					end
				elseif not state.open then
					StationController.open("Inventory", { tab = tab })
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value + 100, table.unpack(Binds.all(action)))
		end
	end
	-- Esc открывает меню Roblox — заодно закрываем окно.
	GuiService.MenuOpened:Connect(function()
		if state.open then
			StationController.close(true)
		end
	end)
	-- Смерть / респавн — закрыть.
	player.CharacterAdded:Connect(function()
		if state.open then
			StationController.close(true)
		end
	end)
	Bus.on("openStation", function(data)
		StationController.open(data.name, data)
	end)
	print("[StationController] окна-сцены готовы")
end

return StationController
