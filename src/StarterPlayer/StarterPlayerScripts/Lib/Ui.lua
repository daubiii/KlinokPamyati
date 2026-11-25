--!nonstrict
-- Ui (клиент)
-- Кирпичики интерфейса в духе Pixel Blade и приложения Д плана:
--   * пиксельный шрифт (Press Start 2P, с кириллицей) для чисел и заголовков,
--     плотный Montserrat Black для текста — всё с толстой чёрной обводкой;
--   * панели с чёрным контуром и пиксельной фаской (светлая кромка сверху,
--     тень снизу), без скруглений;
--   * сегментированные полоски здоровья с «призраком» потерянного;
--   * кнопки в четырёх состояниях: обычная, наведение, нажатие (сдвиг на
--     2 пикселя), недоступная;
--   * пиксельные иконки 12×12 из битмапов (рисуются кодом в общей палитре);
--   * 3D-иконки оружия во ViewportFrame из той же воксельной модели, что в
--     руке (приложение Ж: «иконки оружия получаем из 3D-моделей»).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Config.Palette)
local Rarities = require(Shared.Config.Rarities)
local VoxelWeaponBuilder = require(Shared.Voxel.VoxelWeaponBuilder)

local Ui = {}

local Env = Palette.Env

Ui.colors = {
	panel = Palette.UI.panel,
	panelLight = Palette.UI.panel:Lerp(Palette.UI.frame, 0.45),
	frame = Palette.UI.frame,
	accent = Palette.UI.accent,
	accentBorder = Palette.UI.accentBorder,
	text = Palette.UI.text,
	textMuted = Palette.UI.textMuted,
	danger = Palette.UI.danger,
	outline = Env.void,
	gold = Env.gold,
	health = Palette.UI.danger,
	healthLight = Palette.UI.danger:Lerp(Env.flameCore, 0.35),
	xp = Env.gold,
	memory = Palette.Memory,
	heal = Palette.Fx.heal,
}

Ui.F = {
	pixel = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Regular),
	heavy = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy),
	bold = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold),
}

-- Старые имена (Enum.Font) — для совместимости.
Ui.fontBold = Enum.Font.GothamBold
Ui.font = Enum.Font.Gotham
Ui.fontTitle = Enum.Font.Arcade

-- ===== Основа =====

-- Новый ScreenGui. Масштаб подстраивается под высоту экрана.
-- respectInset = true — учитывать верхнюю панель Roblox.
function Ui.screen(name: string, order: number?, respectInset: boolean?)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = not respectInset
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order or 1
	gui.Parent = playerGui

	local scale = Instance.new("UIScale")
	scale.Name = "Scale"
	scale.Parent = gui
	local function refresh()
		local camera = Workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp(camera.ViewportSize.Y / 800, 0.65, 1.5)
		end
	end
	refresh()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	return gui
end

function Ui.apply(instance, props)
	if props then
		for key, value in pairs(props) do
			instance[key] = value
		end
	end
	return instance
end

function Ui.frame(parent, props)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Ui.colors.panel
	frame.BorderSizePixel = 0
	Ui.apply(frame, props)
	frame.Parent = parent
	return frame
end

-- Чёрная обводка (текст или рамка).
function Ui.outline(instance, thickness: number?, color: Color3?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Ui.colors.outline
	stroke.Thickness = thickness or 2
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	-- Только у меток обводка идёт по тексту; у кнопок и рамок — по краю
	-- (иначе ячейка-кнопка без текста остаётся вообще без рамки).
	if instance:IsA("TextLabel") then
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	else
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	stroke.Parent = instance
	return stroke
end

-- Текст: Montserrat Black, светлый, с обводкой. props.stroke = толщина.
function Ui.text(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = Ui.F.heavy
	label.TextColor3 = Ui.colors.text
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.RichText = false
	local stroke = props and props.stroke
	local copy = props and table.clone(props) or {}
	copy.stroke = nil
	Ui.apply(label, copy)
	label.Parent = parent
	if stroke ~= 0 then
		Ui.outline(label, stroke or 2)
	end
	return label
end

-- Пиксельный текст: заголовки и числа.
function Ui.pixel(parent, props)
	local copy = props and table.clone(props) or {}
	copy.FontFace = Ui.F.pixel
	copy.stroke = copy.stroke or 3
	return Ui.text(parent, copy)
end

-- Совместимость со старым кодом: обычная метка без обводки.
function Ui.label(parent, props)
	local copy = props and table.clone(props) or {}
	copy.stroke = 0
	if copy.Font then
		copy.FontFace = (copy.Font == Ui.fontBold) and Ui.F.heavy or Ui.F.bold
		copy.Font = nil
	end
	return Ui.text(parent, copy)
end

-- Панель: тёмная заливка, чёрный контур, пиксельная фаска.
function Ui.panel(parent, props)
	local frame = Ui.frame(parent, props)
	frame.BackgroundTransparency = (props and props.BackgroundTransparency) or 0.06
	local stroke = Ui.outline(frame, 3)
	-- Фаска: светлая полоса сверху, тёмная снизу.
	Ui.frame(frame, {
		Name = "BevelTop",
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = Ui.colors.frame,
		BackgroundTransparency = 0.1,
		ZIndex = frame.ZIndex,
	})
	Ui.frame(frame, {
		Name = "BevelBottom",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = Ui.colors.outline,
		BackgroundTransparency = 0.3,
		ZIndex = frame.ZIndex,
	})
	return frame, stroke
end

-- ===== Полоска =====

-- Сегментированная полоска: фон, «призрак» потерянного, заливка с бликом,
-- деления. Возвращает объект { frame, set(ratio, dt), color(c) }.
function Ui.bar(parent, props, opts)
	opts = opts or {}
	local back = Ui.frame(parent, props)
	back.BackgroundColor3 = opts.back or Ui.colors.outline
	back.ClipsDescendants = true
	Ui.outline(back, opts.stroke or 3)

	local chip = Ui.frame(back, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = opts.chip or Ui.colors.text, ZIndex = back.ZIndex + 1 })
	local fill = Ui.frame(back, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = opts.color or Ui.colors.health, ZIndex = back.ZIndex + 2 })
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.45, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(205, 205, 205)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 170, 170)),
	})
	gradient.Parent = fill
	-- Блик сверху.
	Ui.frame(fill, { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.fromOffset(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, ZIndex = back.ZIndex + 3 })

	local segments = opts.segments or 0
	for index = 1, segments - 1 do
		Ui.frame(back, {
			Position = UDim2.new(index / segments, -1, 0, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = Ui.colors.outline,
			BackgroundTransparency = 0.25,
			ZIndex = back.ZIndex + 4,
		})
	end

	local bar = { frame = back, fill = fill, chip = chip, ratio = 1, chipRatio = 1, hold = 0 }
	function bar.set(ratio: number, dt: number?)
		ratio = math.clamp(ratio, 0, 1)
		if ratio < bar.ratio - 0.0005 then
			bar.hold = 0.45
		end
		bar.ratio = ratio
		if ratio >= bar.chipRatio then
			bar.chipRatio = ratio
		elseif bar.hold > 0 then
			bar.hold -= dt or 0
		else
			bar.chipRatio += (ratio - bar.chipRatio) * math.min((dt or 0.016) * 7, 1)
		end
		fill.Size = UDim2.fromScale(ratio, 1)
		chip.Size = UDim2.fromScale(bar.chipRatio, 1)
	end
	function bar.color(color: Color3)
		fill.BackgroundColor3 = color
	end
	return bar
end

-- ===== Кнопка =====

-- Кнопка в четырёх состояниях (приложение Д). style: "gold" | "dark".
function Ui.button(parent, props, style)
	local gold = style ~= "dark"
	local base = gold and Ui.colors.accent or Ui.colors.panelLight
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = props and props.Size or UDim2.fromOffset(160, 48)
	holder.Position = props and props.Position or UDim2.new()
	holder.AnchorPoint = props and props.AnchorPoint or Vector2.zero
	holder.LayoutOrder = props and props.LayoutOrder or 0
	holder.ZIndex = props and props.ZIndex or 1
	holder.Parent = parent

	-- Тень под кнопкой: при нажатии кнопка «садится» на неё.
	Ui.frame(holder, {
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Ui.colors.outline,
		ZIndex = holder.ZIndex,
	})
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundColor3 = base
	button.BorderSizePixel = 0
	button.Size = UDim2.fromScale(1, 1)
	button.FontFace = Ui.F.pixel
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = props and props.TextSize or 14
	button.Text = props and props.Text or ""
	button.ZIndex = holder.ZIndex + 1
	button.Parent = holder
	Ui.outline(button, 3)
	local textStroke = Instance.new("UIStroke")
	textStroke.Thickness = 2
	textStroke.Color = Ui.colors.outline
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Parent = button
	Ui.frame(button, { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.65, ZIndex = holder.ZIndex + 2 })
	Ui.frame(button, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = gold and Ui.colors.accentBorder or Ui.colors.outline, BackgroundTransparency = 0.2, ZIndex = holder.ZIndex + 2 })

	local enabled = true
	local hovered = false
	local function refresh()
		if not enabled then
			button.BackgroundColor3 = Ui.colors.frame
			button.TextTransparency = 0.45
		else
			button.BackgroundColor3 = hovered and base:Lerp(Color3.new(1, 1, 1), 0.18) or base
			button.TextTransparency = 0
		end
	end
	button.MouseEnter:Connect(function()
		hovered = true
		refresh()
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		button.Position = UDim2.fromOffset(0, 0)
		refresh()
	end)
	button.MouseButton1Down:Connect(function()
		if enabled then
			button.Position = UDim2.fromOffset(0, 2)
		end
	end)
	button.MouseButton1Up:Connect(function()
		button.Position = UDim2.fromOffset(0, 0)
	end)

	local api = { holder = holder, button = button }
	function api.setEnabled(value: boolean)
		enabled = value
		button.Active = value
		refresh()
	end
	function api.setText(text: string)
		button.Text = text
	end
	button:SetAttribute("Gold", gold)
	-- Совместимость: старый код подключался к .Activated самой кнопки.
	return button, api
end

-- Круглая плашка клавиши (как «E» у способностей в Pixel Blade).
function Ui.keycap(parent, text: string, props)
	local cap = Ui.frame(parent, {
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Ui.colors.outline,
		ZIndex = (props and props.ZIndex) or 6,
	})
	Ui.apply(cap, props)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = cap
	local ring = Instance.new("UIStroke")
	ring.Color = Ui.colors.accent
	ring.Thickness = 2
	ring.Parent = cap
	Ui.pixel(cap, {
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextSize = #text > 2 and 7 or 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = cap.ZIndex + 1,
		stroke = 0,
	})
	return cap
end

-- ===== Пиксельные иконки =====

local ICON_COLORS = {
	k = Env.void,
	w = Palette.Material.bladeEdge,
	s = Env.ironLight:Lerp(Env.bone, 0.45),
	d = Env.iron:Lerp(Env.ironLight, 0.4),
	g = Env.gold,
	y = Env.flameCore,
	o = Env.ember,
	r = Palette.UI.danger,
	c = Palette.Memory,
	b = Env.wood,
	h = Palette.Fx.heal,
}

Ui.Icons = {
	chest = {
		"............",
		"..kkkkkkkk..",
		".kbbbbbbbbk.",
		"kbbgbbbbgbbk",
		"kggggggggggk",
		"kbbbbggbbbbk",
		"kbbbgccgbbbk",
		"kbbbbggbbbbk",
		"kbbgbbbbgbbk",
		"kggggggggggk",
		".kkkkkkkkkk.",
		"............",
	},
	sword = {
		"..........kk",
		".........kwk",
		"........kwsk",
		".......kwsk.",
		"......kwsk..",
		"..kk.kwsk...",
		"..kgkwsk....",
		"...kgsk.....",
		"..kbkgk.....",
		".kbk.kgk....",
		"kbk...kk....",
		"kk..........",
	},
	shield = {
		"..kkkkkkkk..",
		".kssssssssk.",
		"kswwwggwwwsk",
		"kswwwggwwwsk",
		"ksggggggggsk",
		"ksggggggggsk",
		"kswwwggwwwsk",
		".kswwggwwsk.",
		".kswwggwwsk.",
		"..ksswwssk..",
		"...kssssk...",
		"....kkkk....",
	},
	dash = {
		"............",
		"..k....k....",
		".kwk..kwk...",
		"..kwk..kwk..",
		"c..kwk..kwk.",
		"cc..kwk..kwk",
		"cc..kwk..kwk",
		"c..kwk..kwk.",
		"..kwk..kwk..",
		".kwk..kwk...",
		"..k....k....",
		"............",
	},
	heal = {
		"....kkkk....",
		"....kwwk....",
		".....kk.....",
		"....kbbk....",
		"...kk..kk...",
		"..k.hhhh.k..",
		".k.hhhhhh.k.",
		".khhhwhhhhk.",
		".khhwhhhhhk.",
		".khhhhhhhhk.",
		"..khhhhhhk..",
		"...kkkkkk...",
	},
	whirl = {
		"...kkkkkk...",
		"..kggggggk..",
		".kgkkkkkkgk.",
		"kgk.kggk.kgk",
		"kgkkg..gk.gk",
		"kg.kg.kgk.gk",
		"kg.kgggk..gk",
		"kgk.kkk..kgk",
		".kgk....kgk.",
		"..kggggggk..",
		"...kkkkkk...",
		"............",
	},
	hammer = {
		"..kkkkkkk...",
		".kssssssdk..",
		".ksskkkssdk.",
		".kssdbksssk.",
		"..kkkbkkkk..",
		"....kbk.....",
		"...kbk......",
		"..kbk.......",
		".kbk........",
		"kgk.........",
		"kk..........",
		"............",
	},
	soul = {
		".....kk.....",
		"....kck.....",
		"....kcck....",
		"...kccck.k..",
		"..kcwcck.kk.",
		".kccwwcckck.",
		".kcwwwwccck.",
		"kccwwwwwccck",
		"kccwwwwwccck",
		".kccwwwccck.",
		"..kcccccck..",
		"...kkkkkk...",
	},
	coin = {
		"...kkkkkk...",
		"..kggggggk..",
		".kgyyyyyygk.",
		"kgyyggggyygk",
		"kgyygyyyyygk",
		"kgyygyyyyygk",
		"kgyygyyyyygk",
		"kgyyggggyygk",
		".kgyyyyyygk.",
		"..kggggggk..",
		"...kkkkkk...",
		"............",
	},
	iron = {
		"............",
		"............",
		"....kkkkkk..",
		"...ksswwsk..",
		"..ksssssdk..",
		".kkkkkkkddk.",
		".ksssswwkdk.",
		".ksssssskdk.",
		".kddddddkk..",
		".kkkkkkkk...",
		"............",
		"............",
	},
	skull = {
		"..kkkkkkkk..",
		".kwwwwwwwwk.",
		"kwwwwwwwwwwk",
		"kwkkwwwwkkwk",
		"kwkrkwwkrkwk",
		"kwkkwwwwkkwk",
		"kwwwwkkwwwwk",
		".kwwwkkwwwk.",
		"..kwkwkwkk..",
		"..kwkwkwk...",
		"...kkkkk....",
		"............",
	},
	helm = {
		"....kkkk....",
		"...kggggk...",
		"..kssssssk..",
		".kssssssssk.",
		".ksswwwwssk.",
		".kskkkkkksk.",
		".kkcckkcckk.",
		".kskkkkkksk.",
		".kssssssssk.",
		".kdssssssdk.",
		"..kddddddk..",
		"...kkkkkk...",
	},
	fire = {
		".....k......",
		"....kok.....",
		"....kook....",
		"...kooyok...",
		"..koyyyoko..",
		"..koyyyyok..",
		".koyywyyyok.",
		".koyywwyyok.",
		".kooyyyyook.",
		"..kooooook..",
		"...kkkkkk...",
		"............",
	},
}

-- Нарисовать иконку: строки битмапа склеиваются в горизонтальные полосы
-- одного цвета, поэтому кадров немного.
function Ui.icon(parent, name: string, props)
	local bitmap = Ui.Icons[name] or Ui.Icons.sword
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(36, 36)
	Ui.apply(holder, props)
	holder.Parent = parent
	local rows = #bitmap
	local columns = #bitmap[1]
	for y = 1, rows do
		local row = bitmap[y]
		local x = 1
		while x <= columns do
			local char = string.sub(row, x, x)
			local run = 1
			while x + run <= columns and string.sub(row, x + run, x + run) == char do
				run += 1
			end
			local color = ICON_COLORS[char]
			if color then
				Ui.frame(holder, {
					Position = UDim2.fromScale((x - 1) / columns, (y - 1) / rows),
					Size = UDim2.fromScale(run / columns, 1 / rows),
					BackgroundColor3 = color,
					ZIndex = holder.ZIndex,
				})
			end
			x += run
		end
	end
	return holder
end

-- ===== 3D-иконка оружия =====

-- ViewportFrame с воксельной моделью оружия. opts.spin — медленно вращать.
function Ui.weaponView(parent, weapon, props, opts)
	opts = opts or {}
	local view = Instance.new("ViewportFrame")
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromOffset(64, 64)
	view.Ambient = Env.bone:Lerp(Color3.new(1, 1, 1), 0.3)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-1, -2, -1.5)
	Ui.apply(view, props)
	view.Parent = parent

	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = view
	view.CurrentCamera = camera

	local function fill(info)
		for _, child in ipairs(view:GetChildren()) do
			if child:IsA("Model") then
				child:Destroy()
			end
		end
		if not info then
			return
		end
		local typeId = info.typeId or VoxelWeaponBuilder.KindById[info.id or ""] or "sword"
		local ok, model = pcall(VoxelWeaponBuilder.build, typeId, {
			weaponId = info.id,
			anchored = true,
			noFx = true,
		})
		if not ok then
			return
		end
		local extent = model:GetAttribute("Extent") or 5
		local centerY = model:GetAttribute("CenterY") or 0
		-- Диагональ, как у иконок оружия: рукоять внизу слева.
		local tilt = CFrame.Angles(0, 0, math.rad(-45))
		model:PivotTo(tilt * CFrame.new(0, -centerY, 0))
		model.Parent = view
		local distance = extent / (2 * math.tan(math.rad(camera.FieldOfView / 2))) * 1.05
		local angle = 0
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, distance), Vector3.zero)
		if opts.spin then
			local connection
			connection = RunService.RenderStepped:Connect(function(dt)
				if not view.Parent or not model.Parent then
					connection:Disconnect()
					return
				end
				angle += dt * 0.8
				model:PivotTo(CFrame.Angles(0, angle, 0) * tilt * CFrame.new(0, -centerY, 0))
			end)
		end
	end
	fill(weapon)

	return view, fill
end

-- Цвет редкости.
function Ui.rarity(id: string?): Color3
	return Rarities.color(id or "common")
end

function Ui.tween(instance, time: number, goal, style)
	local tween = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

-- Формат времени «м:сс».
function Ui.clock(seconds: number): string
	seconds = math.max(math.floor(seconds), 0)
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

return Ui
