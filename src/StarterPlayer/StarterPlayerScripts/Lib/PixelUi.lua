--!nonstrict
-- PixelUi (клиент)
-- Кирпичики интерфейса v2: панели из атласа (9-slice), пергамент, кнопки с
-- нажатием, слоты редкости, полосы, звёзды, облачка, кошелёк, ленты.
--
-- Координаты — «дизайн-пиксели» макета 1600×900. Корень окна растягивается на
-- весь экран и масштабируется UIScale, поэтому один макет работает на ПК,
-- планшете и телефоне. Арт атласа рисуется ×2 (PIXEL) с ResampleMode Pixelated.

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local UiAssets = require(Config.UiAssets)
local AbilityIcons345 = require(Config.AbilityIcons345)
local AbilityIconsMage = require(Config.AbilityIconsMage)
local UiAtlas = require(Config.UiAtlas)

local UiSound = require(script.Parent.UiSound)
local UiMotion = require(script.Parent.UiMotion)

local PixelUi = {}

PixelUi.PIXEL = 2 -- 1 пиксель арта = 2 дизайн-пикселя
PixelUi.DESIGN = Vector2.new(1600, 900)
PixelUi.colors = UiAssets.Colors
PixelUi.rarity = UiAssets.Rarity

local C = UiAssets.Colors

local function hasAtlas(id: string): boolean
	return typeof(id) == "string" and id ~= "" and not id:match("://0$")
end

-- Заглушки, пока атлас не загружен: цвет и обводка по имени куска.
local FALLBACK = {
	panel = { Color3.fromRGB(30, 22, 19), 0.06, Color3.fromRGB(122, 86, 54) },
	frame = { Color3.fromRGB(30, 22, 19), 1, Color3.fromRGB(122, 86, 54) },
	parch = { Color3.fromRGB(238, 222, 182), 0, Color3.fromRGB(150, 110, 70) },
	parchClean = { Color3.fromRGB(238, 222, 182), 0, Color3.fromRGB(150, 110, 70) },
	plank = { Color3.fromRGB(150, 100, 60), 0, Color3.fromRGB(26, 16, 10) },
	btnGold = { Color3.fromRGB(230, 170, 60), 0, Color3.fromRGB(26, 16, 10) },
	btnMem = { Color3.fromRGB(70, 180, 220), 0, Color3.fromRGB(26, 16, 10) },
	btnRed = { Color3.fromRGB(190, 60, 50), 0, Color3.fromRGB(26, 16, 10) },
	btnWood = { Color3.fromRGB(130, 90, 56), 0, Color3.fromRGB(26, 16, 10) },
	btnOff = { Color3.fromRGB(80, 76, 72), 0, Color3.fromRGB(26, 16, 10) },
	btnGreen = { Color3.fromRGB(100, 190, 80), 0, Color3.fromRGB(26, 16, 10) },
	slotBase = { Color3.fromRGB(24, 18, 15), 0, Color3.fromRGB(26, 16, 10) },
	slotRing = { Color3.new(1, 1, 1), 1, Color3.new(1, 1, 1) },
	slotSelect = { Color3.new(1, 1, 1), 1, Color3.fromRGB(255, 204, 84) },
	barFrame = { Color3.fromRGB(24, 18, 15), 0, Color3.fromRGB(58, 42, 30) },
	barFill = { Color3.new(1, 1, 1), 0, nil },
	ribbonBlue = { Color3.fromRGB(30, 100, 140), 0, Color3.fromRGB(150, 230, 255) },
	ribbonGold = { Color3.fromRGB(220, 160, 60), 0, Color3.fromRGB(255, 240, 190) },
	ribbonRed = { Color3.fromRGB(160, 40, 34), 0, Color3.fromRGB(255, 170, 150) },
	seal = { Color3.fromRGB(176, 40, 34), 0, nil, true },
	medal = { Color3.fromRGB(24, 22, 26), 0, Color3.new(1, 1, 1), true },
	badge = { Color3.fromRGB(200, 50, 44), 0, nil, true },
	glow = { Color3.new(1, 1, 1), 0.85, nil, true },
	shadow = { Color3.new(0, 0, 0), 0.6, nil },
	pixel = { Color3.new(1, 1, 1), 0, nil },
	check = { Color3.fromRGB(100, 180, 80), 0, Color3.fromRGB(26, 16, 10) },
	checkOff = { Color3.fromRGB(50, 40, 36), 0, Color3.fromRGB(26, 16, 10) },
	close = { Color3.fromRGB(130, 90, 56), 0, Color3.fromRGB(26, 16, 10) },
}

-- ===== экран и корень =====

-- ScreenGui + корневой Frame в дизайн-координатах (растянут на весь экран).
function PixelUi.screen(name: string, order: number?)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order or 5
	gui.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root

	local function refresh()
		local camera = Workspace.CurrentCamera
		local vp = camera and camera.ViewportSize or PixelUi.DESIGN
		-- Рабочая высота — без верхней панели Roblox: корень сдвинут вниз на её
		-- высоту, поэтому и размер считаем от остатка. Иначе низ экрана (HP-бар,
		-- подвал окон) уезжает за границу.
		local inset = GuiService:GetGuiInset().Y
		local usableY = math.max(vp.Y - inset, 240)
		local s = math.clamp(math.min(vp.X / PixelUi.DESIGN.X, usableY / PixelUi.DESIGN.Y), 0.45, 1.6)
		scale.Scale = s
		root.Position = UDim2.fromOffset(0, inset)
		root.Size = UDim2.fromOffset(vp.X / s, usableY / s)
	end
	refresh()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	return gui, root
end

-- Группа для макета 1600×900, центрированная в корне (для окон-сцен).
function PixelUi.canvas(root)
	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromOffset(PixelUi.DESIGN.X, PixelUi.DESIGN.Y)
	canvas.Parent = root
	return canvas
end

function PixelUi.apply(instance, props)
	if props then
		for key, value in pairs(props) do
			instance[key] = value
		end
	end
	return instance
end

-- ===== картинки из атласа =====

function PixelUi.piece(parent, name: string, props, atlasKind: string?)
	local isIcon = atlasKind == "icon"
	local rects = isIcon and UiAtlas.Icons or UiAtlas.Ui
	local rect = rects[name]
	local atlasId = isIcon and UiAssets.Icons or UiAssets.Atlas
	if isIcon and not rect then
		-- Иконки способностей этажей 3–5: свой атлас, до загрузки — запасная иконка.
		local own = AbilityIcons345.rects[name]
		if own and hasAtlas(AbilityIcons345.atlas) then
			rect = own
			atlasId = AbilityIcons345.atlas
		elseif AbilityIcons345.fallback[name] then
			rect = rects[AbilityIcons345.fallback[name]]
		end
		-- Заклинания посохов (08.11): свой атлас, до загрузки — прежняя иконка.
		local spell = AbilityIconsMage.rects[name]
		if spell and hasAtlas(AbilityIconsMage.atlas) then
			rect = spell
			atlasId = AbilityIconsMage.atlas
		elseif AbilityIconsMage.fallback[name] then
			rect = rects[AbilityIconsMage.fallback[name]]
		end
	end
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	if rect and hasAtlas(atlasId) then
		label.Image = atlasId
		label.ImageRectOffset = Vector2.new(rect.x, rect.y)
		label.ImageRectSize = Vector2.new(rect.w, rect.h)
		label.ResampleMode = name == "glow" and Enum.ResamplerMode.Default or Enum.ResamplerMode.Pixelated
		if rect.slice then
			local l, t, r, b = rect.slice[1], rect.slice[2], rect.slice[3], rect.slice[4]
			label.ScaleType = Enum.ScaleType.Slice
			label.SliceCenter = Rect.new(l, t, rect.w - r, rect.h - b)
			label.SliceScale = PixelUi.PIXEL
		end
	else
		-- Заглушка до загрузки атласа.
		local fb = FALLBACK[name]
		if isIcon or not fb then
			label.BackgroundTransparency = 1
			if isIcon then
				local text = Instance.new("TextLabel")
				text.BackgroundTransparency = 1
				text.Size = UDim2.fromScale(1, 1)
				text.Text = string.upper(string.sub(name, 1, 1))
				text.TextScaled = true
				text.FontFace = UiAssets.Font
				text.TextColor3 = C.bone
				text.Parent = label
			end
		else
			label.BackgroundColor3 = fb[1]
			label.BackgroundTransparency = fb[2]
			if fb[3] then
				local stroke = Instance.new("UIStroke")
				stroke.Color = fb[3]
				stroke.Thickness = 2
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Parent = label
			end
			if fb[4] then
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(1, 0)
				corner.Parent = label
			end
		end
	end
	label.Parent = parent
	return PixelUi.apply(label, props)
end

function PixelUi.icon(parent, name: string, pos: UDim2, size: number?, props)
	local s = size or 40
	local label = PixelUi.piece(parent, name, {
		Position = pos,
		Size = UDim2.fromOffset(s, s),
		ZIndex = 4,
	}, "icon")
	return PixelUi.apply(label, props)
end

-- ===== текст =====

-- size: 16 / 24 / 32 / 40 (кратно 8 — шрифт остаётся чётким).
function PixelUi.text(parent, text: string, size: number?, color: Color3?, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = UiAssets.Font
	label.Text = text
	label.TextSize = size or 16
	label.TextColor3 = color or C.bone
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.RichText = false
	label.ZIndex = 6
	label.Size = UDim2.fromOffset(400, (size or 16) + 6)
	label.Parent = parent
	PixelUi.apply(label, props)
	return label
end

-- Тёмная обводка (для текста поверх сцены).
function PixelUi.outline(label, thickness: number?, color: Color3?)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 2
	stroke.Color = color or C.dark
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.Parent = label
	return stroke
end

-- Текст с обводкой — по умолчанию для всего, что лежит на сцене / тёмной панели.
function PixelUi.label(parent, text: string, size: number?, color: Color3?, props)
	local label = PixelUi.text(parent, text, size, color, props)
	PixelUi.outline(label, math.max(2, math.floor((size or 16) / 8)))
	return label
end

-- ===== панели =====

function PixelUi.shadow(parent, pos: UDim2, size: UDim2, z: number?)
	return PixelUi.piece(parent, "shadow", {
		Position = pos + UDim2.fromOffset(4, 6),
		Size = size + UDim2.fromOffset(12, 12),
		AnchorPoint = Vector2.new(0, 0),
		ZIndex = z or 1,
		ImageTransparency = 0.1,
	})
end

-- Тёмная панель в кованой оправе. opts.corners=false — без уголков; opts.title — заголовок.
function PixelUi.panel(parent, pos: UDim2, size: UDim2, opts)
	opts = opts or {}
	local holder = Instance.new("Frame")
	holder.Name = opts.name or "Panel"
	holder.BackgroundTransparency = 1
	holder.Position = pos
	holder.Size = size
	holder.ZIndex = opts.z or 2
	holder.Parent = parent
	if opts.shadow ~= false then
		PixelUi.piece(holder, "shadow", { Position = UDim2.fromOffset(-2, 2), Size = UDim2.new(1, 12, 1, 12), ZIndex = holder.ZIndex - 1 })
	end
	PixelUi.piece(holder, opts.flat and "frame" or "panel", { Size = UDim2.fromScale(1, 1), ZIndex = holder.ZIndex })
	if opts.corners ~= false then
		local s = 12 * PixelUi.PIXEL
		for _, spec in ipairs({
			{ "cornerTL", Vector2.new(0, 0), UDim2.fromOffset(-4, -4) },
			{ "cornerTR", Vector2.new(1, 0), UDim2.new(1, 4, 0, -4) },
			{ "cornerBL", Vector2.new(0, 1), UDim2.new(0, -4, 1, 4) },
			{ "cornerBR", Vector2.new(1, 1), UDim2.new(1, 4, 1, 4) },
		}) do
			PixelUi.piece(holder, spec[1], { AnchorPoint = spec[2], Position = spec[3], Size = UDim2.fromOffset(s, s), ZIndex = holder.ZIndex + 3 })
		end
	end
	if opts.title then
		PixelUi.header(holder, opts.title, 18)
	end
	return holder
end

-- Заголовок внутри панели: золотой текст между двумя линиями с ромбами.
function PixelUi.header(parent, text: string, y: number, color: Color3?)
	local width = #text * 12 + 24 -- приблизительно (utf8 кириллица = 2 байта, поэтому /2 * 24)
	width = (utf8.len(text) or #text) * 24 + 24
	local label = PixelUi.label(parent, text, 24, color or C.gold, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.fromOffset(width, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 8,
	})
	for side = -1, 1, 2 do
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.fromRGB(110, 80, 50)
		line.AnchorPoint = Vector2.new(side < 0 and 1 or 0, 0.5)
		line.Position = UDim2.new(0.5, side * (width / 2 + 8), 0, y + 15)
		line.Size = UDim2.new(0.5, -(width / 2 + 28), 0, 2)
		line.ZIndex = 7
		line.Parent = parent
	end
	return label
end

function PixelUi.parch(parent, pos: UDim2, size: UDim2, props)
	local holder = PixelUi.piece(parent, (props and props.clean) and "parchClean" or "parch", {
		Position = pos,
		Size = size,
		ZIndex = 3,
	})
	if props then
		props.clean = nil
		PixelUi.apply(holder, props)
	end
	return holder
end

-- ===== кнопки =====

local BUTTON_TEXT = {
	btnGold = { C.ink, nil },
	btnMem = { Color3.fromRGB(250, 255, 255), Color3.fromRGB(8, 40, 56) },
	btnRed = { Color3.fromRGB(255, 240, 230), Color3.fromRGB(50, 8, 6) },
	btnWood = { C.bone, C.dark },
	btnOff = { Color3.fromRGB(150, 144, 138), C.dark },
	btnGreen = { Color3.fromRGB(250, 255, 240), Color3.fromRGB(20, 50, 10) },
}

-- kind: gold | mem | red | wood | off | green. Возвращает объект с :set(text), :setKind(kind), :setEnabled(bool).
function PixelUi.button(parent, kind: string, pos: UDim2, size: UDim2, text: string, onClick, opts)
	opts = opts or {}
	local name = "btn" .. kind:sub(1, 1):upper() .. kind:sub(2)
	local holder = Instance.new("Frame")
	holder.Name = "Button"
	holder.BackgroundTransparency = 1
	holder.Position = pos
	holder.Size = size
	holder.ZIndex = opts.z or 6
	holder.Parent = parent
	if opts.anchor then
		holder.AnchorPoint = opts.anchor
	end

	local glow
	if opts.glow and (kind == "gold" or kind == "mem" or kind == "red") then
		glow = PixelUi.glow(holder, UDim2.fromScale(0.5, 0.5), UDim2.new(1, 60, 1, 60),
			kind == "mem" and C.mem or (kind == "red" and C.red or C.gold), 0.55)
		glow.ZIndex = holder.ZIndex - 1
	end
	local face = PixelUi.piece(holder, name, { Size = UDim2.fromScale(1, 1), ZIndex = holder.ZIndex })
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = holder.ZIndex + 3
	hit.Parent = holder

	local colors = BUTTON_TEXT[name] or BUTTON_TEXT.btnGold
	local label = PixelUi.text(holder, text, opts.textSize or 16, colors[1], {
		Size = UDim2.new(1, 0, 1, -6),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = holder.ZIndex + 2,
	})
	if colors[2] then
		PixelUi.outline(label, 2, colors[2])
	end
	local iconLabel
	if opts.icon then
		iconLabel = PixelUi.icon(holder, opts.icon, UDim2.new(0, 14, 0.5, -20), 40, { ZIndex = holder.ZIndex + 2 })
		label.Position = UDim2.fromOffset(24, 0)
	end

	local object: any = { holder = holder, label = label, face = face, glow = glow, enabled = opts.enabled ~= false, kind = kind }

	local function paint()
		face.ImageColor3 = object.enabled and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 150)
	end

	hit.MouseEnter:Connect(function()
		if not object.enabled then
			return
		end
		UiSound.play("ui_hover")
		TweenService:Create(face, TweenInfo.new(0.08), { Position = UDim2.fromOffset(0, -2) }):Play()
		TweenService:Create(label, TweenInfo.new(0.08), { Position = label.Position - UDim2.fromOffset(0, 2) }):Play()
	end)
	hit.MouseLeave:Connect(function()
		TweenService:Create(face, TweenInfo.new(0.08), { Position = UDim2.fromOffset(0, 0) }):Play()
		TweenService:Create(label, TweenInfo.new(0.08), { Position = UDim2.fromOffset(iconLabel and 24 or 0, 0) }):Play()
	end)
	hit.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, 2)
	end)
	hit.MouseButton1Up:Connect(function()
		face.Position = UDim2.fromOffset(0, 0)
	end)
	hit.Activated:Connect(function()
		if not object.enabled then
			UiSound.play("error")
			PixelUi.nudge(holder)
			return
		end
		UiSound.play("ui_click")
		UiMotion.punch(holder, 0.06, 0.18)
		if onClick then
			task.spawn(onClick)
		end
	end)

	function object:set(newText: string)
		label.Text = newText
	end
	function object:setEnabled(value: boolean)
		object.enabled = value
		paint()
	end
	function object:setKind(newKind: string)
		local newName = "btn" .. newKind:sub(1, 1):upper() .. newKind:sub(2)
		local rect = UiAtlas.Ui[newName]
		if rect and hasAtlas(UiAssets.Atlas) then
			face.ImageRectOffset = Vector2.new(rect.x, rect.y)
		elseif FALLBACK[newName] then
			face.BackgroundColor3 = FALLBACK[newName][1]
		end
		local tc = BUTTON_TEXT[newName] or BUTTON_TEXT.btnGold
		label.TextColor3 = tc[1]
		object.kind = newKind
	end
	object.hit = hit
	paint()
	return object
end

-- Кнопка «закрыть» в правом верхнем углу.
function PixelUi.closeButton(parent, onClick)
	local holder = Instance.new("ImageButton")
	holder.Name = "Close"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -20, 0, 20)
	holder.Size = UDim2.fromOffset(48, 48)
	holder.ZIndex = 20
	holder.Parent = parent
	PixelUi.piece(holder, "close", { Size = UDim2.fromScale(1, 1), ZIndex = 20 })
	PixelUi.label(holder, "Esc", 16, C.grey, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(60, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 20,
	})
	holder.MouseEnter:Connect(function()
		UiSound.play("ui_hover")
		PixelUi.tween(holder, 0.14, { Rotation = 90 }, Enum.EasingStyle.Back)
	end)
	holder.MouseLeave:Connect(function()
		PixelUi.tween(holder, 0.14, { Rotation = 0 })
	end)
	holder.Activated:Connect(function()
		UiSound.play("ui_click")
		UiMotion.punch(holder, -0.15, 0.12)
		if onClick then
			onClick()
		end
	end)
	return holder
end

-- ===== слоты =====

-- Слот предмета: основа + кольцо цвета редкости. Возвращает объект с полями для заполнения.
function PixelUi.slot(parent, pos: UDim2, size: number, rarity: string?, opts)
	opts = opts or {}
	local holder = Instance.new("Frame")
	holder.Name = "Slot"
	holder.BackgroundTransparency = 1
	holder.Position = pos
	holder.Size = UDim2.fromOffset(size, size)
	holder.ZIndex = opts.z or 5
	holder.Parent = parent
	PixelUi.piece(holder, "slotBase", { Size = UDim2.fromScale(1, 1), ZIndex = holder.ZIndex })
	local ring = PixelUi.piece(holder, "slotRing", { Size = UDim2.fromScale(1, 1), ZIndex = holder.ZIndex + 1 })
	local object: any = { holder = holder, ring = ring }

	function object:setRarity(rarityId: string?)
		local color = rarityId and UiAssets.Rarity[rarityId]
		ring.Visible = color ~= nil
		if color then
			ring.ImageColor3 = color
			if ring.Image == "" then
				ring.BackgroundTransparency = 1
				local stroke = ring:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = color
				end
			end
		end
	end
	function object:setIcon(iconName: string?, dim: boolean?)
		if object.icon then
			object.icon:Destroy()
			object.icon = nil
		end
		if iconName then
			local s = math.floor(size * 0.55 / 20) * 20
			s = math.max(s, 20)
			object.icon = PixelUi.icon(holder, iconName, UDim2.new(0.5, -s / 2, 0.5, -s / 2), s, { ZIndex = holder.ZIndex + 2 })
			object.icon.ImageTransparency = dim and 0.65 or 0
		end
	end
	function object:setCorner(text: string?, color: Color3?)
		if not object.corner then
			object.corner = PixelUi.label(holder, "", 16, C.gold, {
				Position = UDim2.fromOffset(6, 4),
				Size = UDim2.fromOffset(size, 20),
				ZIndex = holder.ZIndex + 4,
			})
		end
		object.corner.Text = text or ""
		object.corner.TextColor3 = color or C.gold
	end
	function object:setBadge(text: string?, color: Color3?)
		if not object.badge then
			object.badge = PixelUi.label(holder, "", 16, C.mem, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -6, 1, -2),
				Size = UDim2.fromOffset(size, 20),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = holder.ZIndex + 4,
			})
		end
		object.badge.Text = text or ""
		object.badge.TextColor3 = color or C.mem
	end
	function object:setNew(on: boolean)
		if on and not object.newDot then
			object.newDot = PixelUi.piece(holder, "badge", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -4, 0, 4),
				Size = UDim2.fromOffset(28, 28),
				ZIndex = holder.ZIndex + 5,
			})
			PixelUi.label(object.newDot, "!", 16, C.bone, {
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = holder.ZIndex + 6,
			})
		end
		if object.newDot then
			object.newDot.Visible = on
		end
	end
	function object:setSelected(on: boolean)
		if on and not object.select then
			object.select = PixelUi.piece(holder, "slotSelect", {
				Position = UDim2.fromOffset(-6, -6),
				Size = UDim2.new(1, 12, 1, 12),
				ZIndex = holder.ZIndex + 3,
			})
			object.selectGlow = PixelUi.glow(holder, UDim2.fromScale(0.5, 0.5), UDim2.new(1, 50, 1, 50), C.gold, 0.6)
			object.selectGlow.ZIndex = holder.ZIndex - 1
		end
		if object.select then
			object.select.Visible = on
			object.selectGlow.Visible = on
		end
	end

	object:setRarity(rarity)
	if opts.clickable then
		local hit = Instance.new("TextButton")
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = holder.ZIndex + 8
		hit.Parent = holder
		object.hit = hit
		hit.MouseEnter:Connect(function()
			UiSound.play("ui_hover")
			TweenService:Create(holder, TweenInfo.new(0.08), { Position = pos - UDim2.fromOffset(0, 3) }):Play()
		end)
		hit.MouseLeave:Connect(function()
			TweenService:Create(holder, TweenInfo.new(0.08), { Position = pos }):Play()
		end)
	end
	return object
end

-- ===== полосы =====

-- Полоса с «призраком» (chip). Возвращает объект :set(ratio, instant?), :setText(text).
function PixelUi.bar(parent, pos: UDim2, size: UDim2, color: Color3, opts)
	opts = opts or {}
	local holder = PixelUi.piece(parent, "barFrame", { Position = pos, Size = size, ZIndex = opts.z or 5 })
	local inset = opts.inset or 10
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.ClipsDescendants = true
	inner.Position = UDim2.fromOffset(inset, inset)
	inner.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
	inner.ZIndex = holder.ZIndex + 1
	inner.Parent = holder
	local chip = PixelUi.piece(inner, "barFill", { Size = UDim2.fromScale(1, 1), ImageColor3 = Color3.fromRGB(255, 240, 220), ZIndex = holder.ZIndex + 1 })
	local fill = PixelUi.piece(inner, "barFill", { Size = UDim2.fromScale(1, 1), ImageColor3 = color, ZIndex = holder.ZIndex + 2 })
	if fill.Image == "" then
		fill.BackgroundColor3 = color
		chip.BackgroundColor3 = Color3.fromRGB(255, 240, 220)
	end
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	gradient.Parent = fill
	local text = PixelUi.label(holder, "", opts.textSize or 16, C.bone, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = holder.ZIndex + 4,
	})
	local object: any = { holder = holder, fill = fill, chip = chip, text = text, value = 1, chipValue = 1 }
	function object:set(ratio: number, instant: boolean?)
		ratio = math.clamp(ratio, 0, 1)
		if ratio < object.value and not instant then
			-- урон: сначала прыгает заливка, призрак догоняет через паузу
			fill.Size = UDim2.fromScale(ratio, 1)
			task.delay(0.35, function()
				if object.value == ratio then
					TweenService:Create(chip, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(ratio, 1) }):Play()
				end
			end)
		else
			if instant then
				fill.Size = UDim2.fromScale(ratio, 1)
			else
				TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(ratio, 1) }):Play()
			end
			chip.Size = UDim2.fromScale(ratio, 1)
		end
		object.value = ratio
	end
	function object:setText(value: string)
		text.Text = value
	end
	return object
end

-- Тонкая полоса прогресса без рамки-атласа (для карточек).
-- opts.track / opts.trackTransparency — вид дорожки: по умолчанию тёмная
-- (на тёмных панелях), на пергаменте лучше полупрозрачная с контуром.
function PixelUi.progress(parent, pos: UDim2, size: UDim2, ratio: number, color: Color3?, opts)
	opts = opts or {}
	local back = Instance.new("Frame")
	back.BorderSizePixel = 0
	back.BackgroundColor3 = opts.track or Color3.fromRGB(26, 16, 10)
	back.BackgroundTransparency = opts.trackTransparency or 0
	back.Position = pos
	back.Size = size
	back.ZIndex = 6
	back.Parent = parent
	if opts.trackStroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = opts.trackStroke
		stroke.Thickness = 1
		stroke.Parent = back
	end
	local inner = Instance.new("Frame")
	inner.BorderSizePixel = 0
	inner.BackgroundColor3 = opts.inner or Color3.fromRGB(30, 24, 20)
	inner.BackgroundTransparency = opts.trackTransparency or 0
	inner.Position = UDim2.fromOffset(2, 2)
	inner.Size = UDim2.new(1, -4, 1, -4)
	inner.ZIndex = 6
	inner.Parent = back
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = color or C.mem
	fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
	fill.ZIndex = 7
	fill.Parent = inner
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
	gradient.Parent = fill
	return back, fill
end

-- ===== мелочи =====

function PixelUi.stars(parent, pos: UDim2, n: number, max: number, size: number?)
	local s = size or 28
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = pos
	holder.Size = UDim2.fromOffset(max * (s + 6), s)
	holder.ZIndex = 6
	holder.Parent = parent
	local list = {}
	for i = 1, max do
		local star = PixelUi.piece(holder, i <= n and "starOn" or "starOff", {
			Position = UDim2.fromOffset((i - 1) * (s + 6), 0),
			Size = UDim2.fromOffset(s, s),
			ZIndex = 7,
		})
		list[i] = star
	end
	return holder, list
end

function PixelUi.glow(parent, center: UDim2, size: UDim2, color: Color3, transparency: number?)
	return PixelUi.piece(parent, "glow", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = center,
		Size = size,
		ImageColor3 = color,
		ImageTransparency = transparency or 0.4,
		ZIndex = 1,
	})
end

-- Облачко реплики (пергамент + хвост + табличка имени). Возвращает объект :say(text).
function PixelUi.bubble(parent, pos: UDim2, size: UDim2, name: string?, tail: string?)
	local holder = Instance.new("Frame")
	holder.Name = "Bubble"
	holder.BackgroundTransparency = 1
	holder.Position = pos
	holder.Size = size
	holder.ZIndex = 10
	holder.Parent = parent
	PixelUi.piece(holder, "parchClean", { Size = UDim2.fromScale(1, 1), ZIndex = 10 })
	local tailPos = tail or "bottom"
	if tailPos == "bottom" then
		PixelUi.piece(holder, "tail", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.8, 0, 1, -2), Size = UDim2.fromOffset(32, 24), ZIndex = 11 })
	elseif tailPos == "left" then
		PixelUi.piece(holder, "tail", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(32, 24), Rotation = 90, ZIndex = 11 })
	end
	if name then
		local tag = PixelUi.piece(holder, "btnMem", {
			Position = UDim2.fromOffset(20, -18),
			Size = UDim2.fromOffset((utf8.len(name) or #name) * 16 + 32, 34),
			ZIndex = 12,
		})
		PixelUi.label(tag, name, 16, Color3.fromRGB(230, 252, 255), {
			Size = UDim2.new(1, 0, 1, -4),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 13,
		})
	end
	local text = PixelUi.text(holder, "", 16, C.ink, {
		Position = UDim2.fromOffset(24, 22),
		Size = UDim2.new(1, -48, 1, -36),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.5,
		ZIndex = 12,
	})
	-- voice = { pitch, volume } — «голос» слогами (как в окне разговора); false — молча.
	local object: any = { holder = holder, label = text, voice = { pitch = 1, volume = 0.45 } }
	local token = 0
	-- Печатает текст по буквам (как в RPG), с паузами на знаках и «голосом».
	function object:say(line: string, speed: number?)
		token += 1
		local my = token
		holder.Visible = true
		text.Text = line
		text.MaxVisibleGraphemes = 0
		UiMotion.punch(holder, 0.04, 0.2)
		local chars = {}
		for _, code in utf8.codes(line) do
			table.insert(chars, utf8.char(code))
		end
		task.spawn(function()
			for i, ch in ipairs(chars) do
				if my ~= token or not holder.Parent then
					return
				end
				text.MaxVisibleGraphemes = i
				if object.voice and i % 2 == 1 and ch ~= " " then
					UiSound.blip(object.voice)
				end
				local wait = speed or 0.025
				if ch == "." or ch == "!" or ch == "?" or ch == "…" then
					wait *= 7
				elseif ch == "," or ch == "—" or ch == ":" then
					wait *= 3.5
				end
				task.wait(wait)
			end
			text.MaxVisibleGraphemes = -1
		end)
	end
	return object
end

-- Доска-заголовок окна сверху по центру (+ подзаголовок).
function PixelUi.plankTitle(parent, title: string, sub: string?)
	local len = utf8.len(title) or #title
	local w = len * 32 + 120
	local plank = PixelUi.piece(parent, "plank", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(w, 68),
		ZIndex = 12,
	})
	for side = 0, 1 do
		local rope = Instance.new("Frame")
		rope.BorderSizePixel = 0
		rope.BackgroundColor3 = Color3.fromRGB(40, 30, 24)
		rope.Position = UDim2.new(side, side == 0 and 30 or -34, 0, -12)
		rope.Size = UDim2.fromOffset(4, 14)
		rope.ZIndex = 11
		rope.Parent = plank
	end
	PixelUi.label(plank, title, 32, C.gold, {
		Size = UDim2.new(1, 0, 1, -4),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 13,
	})
	if sub then
		PixelUi.label(parent, sub, 16, Color3.fromRGB(200, 236, 250), {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 90),
			Size = UDim2.fromOffset(900, 22),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 12,
		})
	end
	return plank
end

-- Кошелёк справа сверху: items = { {icon, attr | getter}, ... }. Возвращает refresh().
function PixelUi.wallet(parent, items, rightInset: number?)
	local holder = Instance.new("Frame")
	holder.Name = "Wallet"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -(rightInset or 84), 0, 20)
	holder.Size = UDim2.fromOffset(600, 48)
	holder.ZIndex = 12
	holder.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	local tags = {}
	for i, item in ipairs(items) do
		local tag = PixelUi.piece(holder, "parchClean", { Size = UDim2.fromOffset(120, 44), LayoutOrder = i, ZIndex = 12 })
		PixelUi.icon(tag, item[1], UDim2.fromOffset(6, 2), 40, { ZIndex = 13 })
		local value = PixelUi.text(tag, "0", 24, C.ink, { Position = UDim2.fromOffset(50, 0), Size = UDim2.new(1, -54, 1, 0), ZIndex = 13 })
		tags[i] = { tag = tag, value = value, source = item[2] }
	end
	local player = Players.LocalPlayer
	local function refresh()
		for _, t in ipairs(tags) do
			local v = typeof(t.source) == "function" and t.source() or player:GetAttribute(t.source) or 0
			local s = tostring(v)
			t.value.Text = s
			t.tag.Size = UDim2.fromOffset(60 + #s * 24, 44)
		end
	end
	refresh()
	for _, t in ipairs(tags) do
		if typeof(t.source) == "string" then
			player:GetAttributeChangedSignal(t.source):Connect(refresh)
		end
	end
	return refresh, holder
end

function PixelUi.ribbon(parent, kind: string, pos: UDim2, size: UDim2, z: number?)
	return PixelUi.piece(parent, "ribbon" .. kind:sub(1, 1):upper() .. kind:sub(2), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = size,
		ZIndex = z or 14,
	})
end

-- ===== анимации =====

function PixelUi.tween(object, time: number, props, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- Выпрыгивание: масштаб 0.6 → 1.08 → 1.
function PixelUi.pop(object, delay: number?)
	local scale = object:FindFirstChild("PopScale") or Instance.new("UIScale")
	scale.Name = "PopScale"
	scale.Scale = 0.6
	scale.Parent = object
	task.delay(delay or 0, function()
		PixelUi.tween(scale, 0.18, { Scale = 1.08 }, Enum.EasingStyle.Back)
		task.wait(0.18)
		PixelUi.tween(scale, 0.12, { Scale = 1 })
	end)
end

-- Короткая тряска (ошибка, нехватка ресурса).
function PixelUi.nudge(object)
	local base = object.Position
	task.spawn(function()
		for _, dx in ipairs({ -8, 8, -6, 6, -3, 0 }) do
			object.Position = base + UDim2.fromOffset(dx, 0)
			task.wait(0.03)
		end
		object.Position = base
	end)
end

-- Панель въезжает сбоку (side: -1 слева, 1 справа, 0 снизу, 2 сверху).
function PixelUi.slideIn(object, side: number, delay: number?)
	local target = object.Position
	if side == 2 then
		object.Position = target - UDim2.fromOffset(0, 140)
	elseif side == 0 then
		object.Position = target + UDim2.fromOffset(0, 120)
	else
		object.Position = target + UDim2.fromOffset(side * 480, 0)
	end
	task.delay(delay or 0, function()
		PixelUi.tween(object, 0.35, { Position = target }, Enum.EasingStyle.Back)
	end)
end

return PixelUi
