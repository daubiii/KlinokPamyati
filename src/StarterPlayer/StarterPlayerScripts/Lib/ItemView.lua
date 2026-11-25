--!nonstrict
-- ItemView (клиент) — настоящие 3D-модели предметов в окнах (08.11.2026).
--
-- Инвентарь показывал пиксельные значки «меч / коса / посох». Теперь каждая клетка —
-- витрина: бумажная рамка, внутри «бархат» цвета редкости со светом в центре
-- и тенью-подставкой, а на ней та же модель, что в руке героя и в сундуке:
--   оружие — VoxelWeaponBuilder (меши оружия; нет мешей — воксели);
--   броня  — манекен в комплекте из ReplicatedStorage.KlinokArmorPreviews.<setId>
--            (собирает сервер, Systems/ArmorPreviewService — тем же AppearanceService,
--            что одевает героя).
--
-- ItemView.case(parent, pos, size, rarityId, opts)  → { holder, window, setSelected, setHover }
-- ItemView.weapon(parent, info, props, opts)         → ViewportFrame, info = { id, typeId }
-- ItemView.armor(parent, setId, props, opts)         → ViewportFrame, opts.framing: full | bust | head | torso;
--   opts.onReady — модель пришла (убрать значок-заглушку: первую сборку сервер делает до пары секунд)
--   opts.spin  — медленно вращать (иначе — статичный ракурс 3/4, дешевле);
--   opts.drag  — крутить мышью/пальцем (витрина карточки);
--   opts.angle — стартовый поворот, градусы.
-- Модели оружия кэшируются по id: в сетке на 40 клеток сборка идёт один раз на вид.
-- Статичный ViewportFrame Roblox не перерисовывает — 40 витрин почти бесплатны;
-- крутится только выбранная клетка и карточка.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Config.Palette)
local UiAssets = require(Shared.Config.UiAssets)
local VoxelWeaponBuilder = require(Shared.Voxel.VoxelWeaponBuilder)

local PixelUi = require(script.Parent.PixelUi)

local ItemView = {}

local ARMOR_FOLDER = "KlinokArmorPreviews"
local ARMOR_WAIT = 10

-- Бархат витрины: тёмный тёплый тон, в который подмешан цвет редкости.
local VELVET_DARK = Color3.fromRGB(38, 28, 22)
local PAPER = Color3.fromRGB(236, 222, 192)
-- Свет витрины: тёплый сверху-спереди, чтобы металл и ткань читались на тёмном.
local AMBIENT = Color3.fromRGB(150, 140, 128)
local LIGHT = Color3.fromRGB(255, 244, 226)
local LIGHT_DIR = Vector3.new(-0.9, -1.6, -1.4)

function ItemView.rarityColor(rarityId: string?): Color3
	return UiAssets.Rarity[rarityId or "common"] or UiAssets.Rarity.common or Color3.fromRGB(200, 200, 200)
end

-- ===== витрина-подложка =====

-- Бумажная рамка + бархат цвета редкости + свет + тень-подставка.
-- opts: z, round (радиус угла), glow (0..1 сила света), frame (false — без бумажной рамки), inset,
-- plinth (тень-подставка — для манекенов брони).
function ItemView.case(parent, pos: UDim2, size: Vector2, rarityId: string?, opts)
	opts = opts or {}
	local z = opts.z or 6
	local color = ItemView.rarityColor(rarityId)
	local holder = Instance.new("Frame")
	holder.Name = "ItemCase"
	holder.BackgroundTransparency = 1
	holder.Position = pos
	holder.Size = UDim2.fromOffset(size.X, size.Y)
	holder.ZIndex = z
	holder.Parent = parent

	local inset = opts.inset or math.max(5, math.floor(math.min(size.X, size.Y) * 0.06))
	-- бумажная рамка: светлая кайма с тонкой чернильной линией
	if opts.frame ~= false then
		local frame = Instance.new("Frame")
		frame.Name = "Frame"
		frame.BackgroundColor3 = PAPER
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromScale(1, 1)
		frame.ZIndex = z
		frame.Parent = holder
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, opts.round or 8)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Edge"
		stroke.Color = Color3.fromRGB(160, 140, 108)
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame
		local shade = Instance.new("UIGradient")
		shade.Rotation = 90
		shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(222, 206, 172))
		shade.Parent = frame
	end

	-- внутреннее окно в тон пергамента (раньше было тёмное «бархатное» —
	-- давало двойную рамку и чужой тёмный фон); редкость показывает только
	-- контур окна своим цветом, рамка одна
	local window = Instance.new("Frame")
	window.Name = "Window"
	window.BorderSizePixel = 0
	window.BackgroundColor3 = PAPER:Lerp(Color3.fromRGB(158, 122, 72), 0.16)
	window.Position = UDim2.fromOffset(inset, inset)
	window.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
	window.ClipsDescendants = true
	window.ZIndex = z + 1
	window.Parent = holder
	local windowCorner = Instance.new("UICorner")
	windowCorner.CornerRadius = UDim.new(0, math.max((opts.round or 8) - 3, 2))
	windowCorner.Parent = window
	local paperShade = Instance.new("UIGradient")
	paperShade.Rotation = 90
	paperShade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(226, 210, 180)),
	})
	paperShade.Parent = window
	local rim = Instance.new("UIStroke")
	rim.Name = "Rim"
	rim.Color = color
	rim.Thickness = 2
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = window

	-- свет в центре (как луч из сундука, только мягкий)
	local w = size.X - inset * 2
	local h = size.Y - inset * 2
	local glow = PixelUi.glow(window, UDim2.fromScale(0.5, 0.46), UDim2.fromOffset(w * 1.25, h * 1.15), color:Lerp(Color3.new(1, 1, 1), 0.35),
		1 - (opts.glow or 0.55))
	glow.ZIndex = z + 1
	-- тень-подставка под манекеном (оружие висит по диагонали — ему тень не нужна)
	if opts.plinth then
		local shadow = Instance.new("Frame")
		shadow.Name = "Plinth"
		shadow.AnchorPoint = Vector2.new(0.5, 0.5)
		shadow.Position = UDim2.fromScale(0.5, 0.9)
		shadow.Size = UDim2.new(0.62, 0, 0.1, 0)
		shadow.BackgroundColor3 = Color3.new(0, 0, 0)
		shadow.BackgroundTransparency = 0.72
		shadow.BorderSizePixel = 0
		shadow.ZIndex = z + 1
		shadow.Parent = window
		local shadowCorner = Instance.new("UICorner")
		shadowCorner.CornerRadius = UDim.new(1, 0)
		shadowCorner.Parent = shadow
		local shadowFade = Instance.new("UIGradient")
		shadowFade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		shadowFade.Parent = shadow
	end

	-- легендарное и выше: медленный блик по бархату
	if rarityId == "legendary" or rarityId == "mythic" or rarityId == "secret" then
		local shine = Instance.new("Frame")
		shine.Name = "Shine"
		shine.BackgroundColor3 = Color3.new(1, 1, 1)
		shine.BackgroundTransparency = 0
		shine.BorderSizePixel = 0
		shine.Size = UDim2.fromScale(1, 1)
		shine.ZIndex = z + 1
		shine.Parent = window
		local band = Instance.new("UIGradient")
		band.Rotation = 25
		band.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.82),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		band.Offset = Vector2.new(-1, 0)
		band.Parent = shine
		local tween = game:GetService("TweenService"):Create(band,
			TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 1.4), { Offset = Vector2.new(1, 0) })
		tween:Play()
	end

	local object: any = { holder = holder, window = window, glow = glow, rim = rim, z = z + 2, color = color }
	-- выбор: рамка цвета редкости толще, свет ярче
	function object.setSelected(value: boolean)
		rim.Thickness = value and 3 or 2
		rim.Color = value and color:Lerp(Color3.new(1, 1, 1), 0.2) or color:Lerp(VELVET_DARK, 0.25)
		glow.ImageTransparency = value and math.max(0.1, 1 - (opts.glow or 0.55) - 0.25) or (1 - (opts.glow or 0.55))
	end
	function object.setHover(value: boolean)
		glow.ImageTransparency = value and math.max(0.15, 1 - (opts.glow or 0.55) - 0.15) or (1 - (opts.glow or 0.55))
	end
	return object
end

-- ===== общее для ViewportFrame =====

local function newViewport(parent, props)
	local view = Instance.new("ViewportFrame")
	view.Name = "ItemView"
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(1, 1)
	view.Ambient = AMBIENT
	view.LightColor = LIGHT
	view.LightDirection = LIGHT_DIR
	for key, value in pairs(props or {}) do
		view[key] = value
	end
	view.Parent = parent
	local camera = Instance.new("Camera")
	camera.FieldOfView = 22
	camera.Parent = view
	view.CurrentCamera = camera
	return view, camera
end

-- Вращение: медленное (spin) и/или мышью (drag). base — поза модели в начале координат.
local function animate(view, model, base: CFrame, opts)
	local yaw = math.rad(opts.angle or 0)
	model:PivotTo(CFrame.Angles(0, yaw, 0) * base)
	if not opts.spin and not opts.drag then
		return
	end
	local dragging, lastX = false, 0
	local conns = {}
	local function stop()
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		table.clear(conns)
	end
	if opts.drag then
		view.Active = true
		table.insert(conns, view.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging, lastX = true, input.Position.X
			end
		end))
		table.insert(conns, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end))
		table.insert(conns, UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				yaw += (input.Position.X - lastX) * 0.012
				lastX = input.Position.X
			end
		end))
	end
	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		if not view.Parent or not model.Parent then
			stop()
			return
		end
		if opts.spin and not dragging then
			yaw += dt * (opts.spinSpeed or 0.7)
		end
		model:PivotTo(CFrame.Angles(0, yaw, 0) * base)
	end))
	view.Destroying:Connect(stop)
end

-- Камера так, чтобы рамка size (высота × ширина, стады) вошла в кадр с запасом margin.
-- side: −1 — камера со стороны −Z (лицо манекена), +1 — со стороны +Z (оружие: рукоять внизу слева,
-- как в сундуке и на старых значках).
local function fit(view, camera, height: number, width: number, depth: number, margin: number?, lift: number?, side: number?)
	local abs = view.AbsoluteSize
	local aspect = abs.X > 1 and abs.Y > 1 and abs.X / abs.Y or 1
	local half = math.tan(math.rad(camera.FieldOfView / 2))
	local fitH = height / 2 / half
	local fitW = width / 2 / (half * aspect)
	local distance = math.max(fitH, fitW) * (margin or 1.12) + depth / 2
	camera.CFrame = CFrame.lookAt(Vector3.new(0, lift or 0, distance * (side or -1)), Vector3.new(0, lift or 0, 0))
end

-- ===== оружие =====

local weaponCache = {} -- id → шаблон модели (не в мире)

local function weaponTemplate(info)
	local id = info.id or info.typeId or "sword"
	local cached = weaponCache[id]
	if cached then
		return cached
	end
	local typeId = info.typeId or VoxelWeaponBuilder.KindById[info.id or ""] or "sword"
	local ok, model = pcall(VoxelWeaponBuilder.build, typeId, {
		weaponId = info.id,
		anchored = true,
		noFx = true,
	})
	if not ok or not model then
		warn("[ItemView] оружие " .. tostring(id) .. ": " .. tostring(model))
		return nil
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Light") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	weaponCache[id] = model
	return model
end

-- Оружие по диагонали (рукоять внизу слева) — длинный клинок и древко целиком входят в квадрат.
function ItemView.weapon(parent, info, props, opts)
	opts = opts or {}
	local view, camera = newViewport(parent, props)
	if type(info) ~= "table" then
		return view
	end
	local template = weaponTemplate(info)
	if not template then
		return view
	end
	local model = template:Clone()
	local extent = model:GetAttribute("Extent") or 5
	local centerY = model:GetAttribute("CenterY") or 0
	local tilt = CFrame.Angles(0, 0, math.rad(opts.tilt or -45))
	local base = tilt * CFrame.new(0, -centerY, 0)
	model:PivotTo(base)
	model.Parent = view
	-- рамка по диагонали: проекция длины на оси после наклона
	local span = extent * math.abs(math.cos(math.rad(opts.tilt or -45))) + 0.6
	local spanY = extent * math.abs(math.sin(math.rad(opts.tilt or -45))) + 0.6
	local function refit()
		fit(view, camera, spanY, span, 1, opts.margin or 1.08, 0, 1)
	end
	refit()
	view:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	-- поворот вокруг вертикали — поверх наклона
	animate(view, model, base, opts)
	return view
end

-- ===== броня =====

-- Рамки манекена (доли высоты от макушки): центр и высота кадра.
local FRAMING = {
	full = { center = 0.5, height = 1.0, margin = 1.08 },
	bust = { center = 0.3, height = 0.56, margin = 1.05 },
	head = { center = 0.13, height = 0.3, margin = 1.1 },
	torso = { center = 0.4, height = 0.42, margin = 1.08 },
}

function ItemView.armor(parent, setId: string?, props, opts)
	opts = opts or {}
	local view, camera = newViewport(parent, props)
	if type(setId) ~= "string" then
		return view
	end
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild(ARMOR_FOLDER, ARMOR_WAIT)
		local source = folder and folder:WaitForChild(setId, ARMOR_WAIT)
		if not source or not view.Parent then
			return
		end
		if opts.onReady then
			pcall(opts.onReady)
		end
		local model = source:Clone()
		local cf, size = model:GetBoundingBox()
		local base = CFrame.new(-cf.Position) * model:GetPivot()
		model:PivotTo(base)
		model.Parent = view
		local frame = FRAMING[opts.framing or "full"] or FRAMING.full
		local top = size.Y / 2
		local centerY = top - size.Y * frame.center
		local height = size.Y * frame.height
		local function refit()
			fit(view, camera, height, math.min(size.X, height * 1.1), size.Z, frame.margin, centerY)
		end
		refit()
		view:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
		-- 3/4: перед и плечо (модель смотрит в −Z, камера спереди)
		local start = opts.angle
		if start == nil then
			start = -24
		end
		animate(view, model, base, { spin = opts.spin, drag = opts.drag, angle = start, spinSpeed = opts.spinSpeed or 0.5 })
	end)
	return view
end

-- Палитра для подписей поверх витрин (светлая на бархате).
ItemView.Ink = { light = Palette.Env.bone, paper = PAPER }

return ItemView
