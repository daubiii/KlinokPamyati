--!nonstrict
-- PaperUi (клиент)
-- Бумажные кирпичики «Книги героя» и сумки на арте Humble Gift «Paper UI
-- System» (атлас Config/PaperAtlas, id — UiAssets.PaperAtlas): листы бумаги
-- со стопкой под ними, ленты-заголовки, кнопки с нажатием, строки-полоски,
-- слоты с рамкой выделения, полосы опыта и здоровья, печать «штампом».
--
-- Пока атлас не загружен в Roblox (UiAssets.PaperAtlas = ""), всё рисуется
-- заглушками: бумажный цвет, рамка, иконки из уже загруженного атласа v2.
-- Координаты — дизайн-пиксели 1600×900, как в PixelUi. Арт рисуется ×1
-- (scale = SliceScale): 1 пиксель набора = 1 дизайн-пиксель, мелкие
-- предметы 16×16 увеличиваются кратно (×3, ×4).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local UiAssets = require(Config.UiAssets)
local PaperAtlas = require(Config.PaperAtlas)

local PixelUi = require(script.Parent.PixelUi)
local UiSound = require(script.Parent.UiSound)

local PaperUi = {}

local Pieces = PaperAtlas.Pieces

PaperUi.colors = {
	ink = Color3.fromRGB(66, 48, 32),
	ink2 = Color3.fromRGB(106, 83, 58),
	faint = Color3.fromRGB(150, 128, 98),
	green = Color3.fromRGB(35, 101, 78),
	greenSoft = Color3.fromRGB(54, 91, 72),
	greenLight = Color3.fromRGB(68, 140, 100),
	red = Color3.fromRGB(150, 52, 44),
	gold = Color3.fromRGB(156, 100, 34),
	paper = Color3.fromRGB(236, 222, 192),
	paperDark = Color3.fromRGB(204, 184, 142),
	line = Color3.fromRGB(160, 140, 108),
	wood = Color3.fromRGB(176, 108, 72),
	woodDark = Color3.fromRGB(96, 56, 38),
}
local P = PaperUi.colors

-- Цвета редкости на бумаге: светлые цвета v2 темнее, чтобы читались на светлом.
PaperUi.rarityInk = {
	common = Color3.fromRGB(110, 104, 96),
	rare = Color3.fromRGB(46, 128, 60),
	epic = Color3.fromRGB(118, 62, 184),
	legendary = Color3.fromRGB(184, 108, 18),
	mythic = Color3.fromRGB(178, 46, 50),
	secret = Color3.fromRGB(26, 130, 170),
}

-- Единый пиксельный шрифт всей бумажной системы (раньше была антиква
-- Garamond — на её фоне остальной интерфейс выглядел «неигровым»).
-- Кириллица у Arcade в Roblox отрисовывается пиксельно (см. доску заданий).
PaperUi.Font = Font.fromEnum(Enum.Font.Arcade)
PaperUi.FontBold = Font.fromEnum(Enum.Font.Arcade)
PaperUi.FontItalic = Font.fromEnum(Enum.Font.Arcade)

function PaperUi.hasAtlas(): boolean
	local id = UiAssets.PaperAtlas
	return typeof(id) == "string" and id ~= "" and not id:match("://0$")
end

local function hasDesk(): boolean
	local id = UiAssets.PaperDesk
	return typeof(id) == "string" and id ~= "" and not id:match("://0$")
end

local function apply(instance, props)
	if props then
		for key, value in pairs(props) do
			instance[key] = value
		end
	end
	return instance
end
PaperUi.apply = apply

-- Иконки v2 (атлас уже загружен) для заглушек бумажных предметов.
local ICON_FALLBACK = {
	it_potionRed = "flask", it_potionGold = "flask", it_potionBlue = "flask", it_potionGreen = "flask",
	it_amulet = "amulet", it_amuletRed = "amulet", it_amuletSilver = "amulet",
	it_ring = "ring", it_ringRed = "ring", it_ringSilver = "ring",
	it_soul = "soul", it_key = "key", it_coinStack = "coin", coins = "coin", it_ingot = "ingot", it_dust = "dust",
	it_star = "star", it_bookBlue = "scroll", it_bookRed = "scroll", it_bookGreen = "scroll", book = "scroll",
	bookMark = "scroll", scroll = "scroll", it_sword = "sword", it_candy = "star", it_meat = "flask", it_bread = "flask",
	it_fish = "flask", it_egg = "flask", it_leaf = "dust", it_goldOre = "coin", it_log = "ingot", it_feather = "star",
	icLock = "lock", icLockS = "lock", icCheck = "star", icCheckS = "star", hlCross = "sword", chevronL = "dash",
	hero1 = "helm", hero2 = "helm", npc1 = "quest", npc2 = "quest", npc3 = "quest", npc4 = "quest", npc5 = "quest",
}

local FALLBACK_FILL = {
	sheet = { P.paper, P.line }, sheetAlt = { P.paper, P.line }, sheetPlain = { P.paper, P.line },
	sheetBack = { P.paperDark, P.paperDark },
	ribbon = { P.paper, P.green }, headerArc = { P.paper, P.green }, headerWave = { P.paper, P.green },
	bookmark = { P.paper, P.green }, bookmarkUp = { P.paper, P.green }, bookmarkTwin = { P.paper, P.green }, bookmarkLow = { P.paper, P.green },
	btn = { P.paper, P.green }, btnDown = { P.paperDark, P.green },
	btnRound = { P.paper, P.green, true }, btnRoundDown = { P.paperDark, P.green, true },
	btnRoundBig = { P.paper, P.green, true }, btnRoundBigDown = { P.paperDark, P.green, true },
	knob = { Color3.fromRGB(130, 142, 168), Color3.fromRGB(20, 40, 50), true }, knobDark = { Color3.fromRGB(100, 110, 130), Color3.fromRGB(20, 40, 50), true },
	strip = { P.paper, P.line }, stripRed = { P.paper, P.red }, stripSoft = { P.paper, P.line }, stripSoftRed = { P.paper, P.red },
	stripBack = { P.paper, P.line }, stripBackRed = { P.paper, P.red }, stripPlain = { P.paper, P.line }, stripPlainRed = { P.paper, P.red },
	barFrame = { Color3.fromRGB(226, 210, 176), P.green }, barSeg = { P.paper, P.green },
	barHp = { Color3.fromRGB(214, 58, 52) }, barXp = { Color3.fromRGB(240, 140, 30) },
	ring224 = { P.paper, P.green, true }, ring112 = { P.paper, P.green, true }, ring80 = { P.paper, P.green, true },
	ring64 = { P.paper, P.green, true }, ring32 = { P.paper, P.green, true }, dot32 = { P.paper, P.green, true }, dot32b = { P.paper, P.green, true },
	square = { P.paper, P.line }, squareB = { P.paper, P.line }, plate = { P.paper, P.line }, plateB = { P.paper, P.line }, plateC = { P.paper, P.line },
	divider = { P.line }, dividerPlain = { P.line }, dot = { P.green, nil, true }, dotRing = { P.paper, P.green, true },
	stampMark = { Color3.new(1, 1, 1), P.green, true, true },
	pin = { Color3.fromRGB(120, 130, 150) },
}

local function fallback(label, name: string)
	local fb = FALLBACK_FILL[name]
	if fb then
		label.BackgroundColor3 = fb[1]
		label.BackgroundTransparency = fb[4] and 1 or 0
		if name == "divider" or name == "dividerPlain" then
			label.BackgroundTransparency = 1
			local line = Instance.new("Frame")
			line.BorderSizePixel = 0
			line.BackgroundColor3 = fb[1]
			line.AnchorPoint = Vector2.new(0, 0.5)
			line.Position = UDim2.fromScale(0, 0.5)
			line.Size = UDim2.new(1, 0, 0, 2)
			line.Parent = label
			return
		end
		if fb[2] then
			local stroke = Instance.new("UIStroke")
			stroke.Color = fb[2]
			stroke.Thickness = 2
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = label
		end
		local corner = Instance.new("UICorner")
		corner.CornerRadius = fb[3] and UDim.new(1, 0) or UDim.new(0, 4)
		corner.Parent = label
		return
	end
	label.BackgroundTransparency = 1
	local base = name:gsub("^itL_", "it_")
	local icon = ICON_FALLBACK[base]
	if not icon then
		if base:match("_helm$") then
			icon = "helm"
		elseif base:match("_chest$") or base:match("^eq") then
			icon = "armor"
		end
	end
	if icon then
		local inner = PixelUi.piece(label, icon, { Size = UDim2.fromScale(1, 1) }, "icon")
		inner.ZIndex = label.ZIndex
		label:GetPropertyChangedSignal("ZIndex"):Connect(function()
			inner.ZIndex = label.ZIndex
		end)
		label:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
			inner.ImageTransparency = label.ImageTransparency
		end)
		label:GetPropertyChangedSignal("ImageColor3"):Connect(function()
			inner.ImageColor3 = label.ImageColor3
		end)
	end
end

-- Кусок атласа. opts.scale — SliceScale для 9-slice; opts.noSlice — без нарезки.
function PaperUi.image(parent, name: string, props, opts)
	opts = opts or {}
	local rect = Pieces[name]
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.ZIndex = 3
	if rect and PaperUi.hasAtlas() then
		label.Image = UiAssets.PaperAtlas
		label.ImageRectOffset = Vector2.new(rect.x, rect.y)
		label.ImageRectSize = Vector2.new(rect.w, rect.h)
		label.ResampleMode = Enum.ResamplerMode.Pixelated
		if rect.slice and not opts.noSlice then
			local l, t, r, b = rect.slice[1], rect.slice[2], rect.slice[3], rect.slice[4]
			label.ScaleType = Enum.ScaleType.Slice
			label.SliceCenter = Rect.new(l, t, rect.w - r, rect.h - b)
			label.SliceScale = opts.scale or 1
		end
		label.Size = UDim2.fromOffset(rect.w, rect.h)
	else
		label.Size = rect and UDim2.fromOffset(rect.w, rect.h) or UDim2.fromOffset(32, 32)
		fallback(label, name)
	end
	label.Parent = parent
	return apply(label, props)
end

-- Размер куска в пикселях атласа (для пропорций).
function PaperUi.size(name: string): Vector2
	local rect = Pieces[name]
	return rect and Vector2.new(rect.w, rect.h) or Vector2.new(32, 32)
end

-- ===== текст =====

function PaperUi.text(parent, text: string, size: number?, color: Color3?, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = PaperUi.Font
	label.Text = text
	label.TextSize = size or 18
	label.TextColor3 = color or P.ink
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Size = UDim2.fromOffset(300, (size or 18) + 8)
	label.ZIndex = 8
	label.Parent = parent
	if parent:IsA("GuiObject") then
		label.ZIndex = math.max(label.ZIndex, parent.ZIndex + 1)
	end
	return apply(label, props)
end

function PaperUi.bold(parent, text: string, size: number?, color: Color3?, props)
	local label = PaperUi.text(parent, text, size, color, props)
	label.FontFace = PaperUi.FontBold
	return label
end

function PaperUi.italic(parent, text: string, size: number?, color: Color3?, props)
	local label = PaperUi.text(parent, text, size, color, props)
	label.FontFace = PaperUi.FontItalic
	return label
end

-- ===== листы =====

-- Лист бумаги со стопкой под ним. opts: kind ("sheet" | "sheetAlt" | "sheetPlain"),
-- back (false — без стопки), tilt (градусы нижнего листа), z, scale.
function PaperUi.sheet(parent, pos: UDim2, size: UDim2, opts)
	opts = opts or {}
	local z = opts.z or 3
	local holder = Instance.new("Frame")
	holder.Name = opts.name or "Sheet"
	holder.BackgroundTransparency = 1
	holder.Position = pos
	holder.Size = size
	holder.ZIndex = z
	holder.Parent = parent
	if opts.back ~= false then
		local back = PaperUi.image(holder, "sheetBack", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, opts.backDx or 6, 0.5, opts.backDy or 8),
			Size = UDim2.new(1, -4, 1, -6),
			Rotation = opts.tilt or -1.2,
			ZIndex = z,
		}, { scale = opts.scale or 1 })
		holder:SetAttribute("Back", back.Name)
	end
	PaperUi.image(holder, opts.kind or "sheet", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
	}, { scale = opts.scale or 1 })
	return holder
end

-- Подложка-стол (Book Desk) на всё окно.
function PaperUi.desk(parent, pos: UDim2, size: UDim2, z: number?)
	local label = Instance.new("ImageLabel")
	label.Name = "Desk"
	label.BorderSizePixel = 0
	label.Position = pos
	label.Size = size
	label.ZIndex = z or 1
	if hasDesk() then
		label.BackgroundTransparency = 1
		label.Image = UiAssets.PaperDesk
		label.ResampleMode = Enum.ResamplerMode.Pixelated
		label.ScaleType = Enum.ScaleType.Slice
		local d = PaperAtlas.Desk
		label.SliceCenter = Rect.new(d.slice[1], d.slice[2], d.w - d.slice[3], d.h - d.slice[4])
		label.SliceScale = 2
	else
		label.BackgroundColor3 = P.wood
		label.BackgroundTransparency = 0
		local stroke = Instance.new("UIStroke")
		stroke.Color = P.woodDark
		stroke.Thickness = 4
		stroke.Parent = label
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = label
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new(Color3.fromRGB(255, 240, 225), Color3.fromRGB(205, 180, 160))
		g.Parent = label
	end
	label.Parent = parent
	return label
end

-- ===== ленты и заголовки =====

-- Лента с текстом (3-slice). height по умолчанию 64.
function PaperUi.ribbon(parent, pos: UDim2, width: number, text: string, opts)
	opts = opts or {}
	local height = opts.height or 64
	local scale = height / 80
	local ribbon = PaperUi.image(parent, "ribbon", {
		Position = pos,
		AnchorPoint = opts.anchor or Vector2.zero,
		Size = UDim2.fromOffset(width, height),
		ZIndex = opts.z or 6,
	}, { scale = scale })
	local label = PaperUi.bold(ribbon, text, opts.textSize or math.floor(height * 0.36), opts.color or P.green, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -math.floor(height * 0.08)),
		Size = UDim2.new(1, -math.floor(160 * scale), 0, math.floor(height * 0.5)),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	return ribbon, label
end

-- Дуговой заголовок окна (headerArc) с текстом по центру.
function PaperUi.header(parent, center: UDim2, width: number, text: string, opts)
	opts = opts or {}
	local size = PaperUi.size(opts.kind or "headerArc")
	local height = math.floor(width * size.Y / size.X)
	local header = PaperUi.image(parent, opts.kind or "headerArc", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = center,
		Size = UDim2.fromOffset(width, height),
		ZIndex = opts.z or 9,
	}, { noSlice = true })
	local label = PaperUi.bold(header, text, opts.textSize or math.floor(height * 0.2), opts.color or P.green, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.34, 0),
		Size = UDim2.new(0.7, 0, 0, math.floor(height * 0.26)),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	return header, label
end

-- Разделитель с завитком.
function PaperUi.divider(parent, pos: UDim2, width: number, z: number?)
	return PaperUi.image(parent, "divider", {
		Position = pos,
		Size = UDim2.fromOffset(width, 16),
		ZIndex = z or 6,
	}, { scale = 1 })
end

-- ===== интерактив =====

local function hitButton(holder, z: number)
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = z
	hit.AutoButtonColor = false
	hit.Parent = holder
	return hit
end
PaperUi.hit = hitButton

-- Кнопка-плашка с нажатием. opts: icon (кусок атласа), disabled, tone ("green" | "red"),
-- textSize, z, scale (толщина рамки), sound.
function PaperUi.button(parent, pos: UDim2, size: UDim2, text: string, onClick, opts)
	opts = opts or {}
	local z = opts.z or 7
	local holder = Instance.new("Frame")
	holder.Name = "PaperButton"
	holder.BackgroundTransparency = 1
	holder.Position = pos
	holder.Size = size
	holder.ZIndex = z
	holder.Parent = parent
	local scale = opts.scale or 2
	local face = PaperUi.image(holder, "btn", { Size = UDim2.fromScale(1, 1), ZIndex = z }, { scale = scale })
	local color = opts.tone == "red" and P.red or P.green
	local label = PaperUi.bold(holder, text, opts.textSize or 18, color, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, opts.icon and 14 or 0, 0.5, -3),
		Size = UDim2.new(1, opts.icon and -52 or -16, 1, -10),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = z + 2,
	})
	local icon
	if opts.icon then
		icon = PaperUi.image(holder, opts.icon, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, -3),
			Size = UDim2.fromOffset(opts.iconSize or 32, opts.iconSize or 32),
			ZIndex = z + 2,
		}, { noSlice = true })
	end
	local object: any = { holder = holder, face = face, label = label, icon = icon, disabled = opts.disabled == true }
	local function paint(down: boolean)
		local rect = Pieces[down and "btnDown" or "btn"]
		if rect and PaperUi.hasAtlas() then
			face.ImageRectOffset = Vector2.new(rect.x, rect.y)
		else
			face.BackgroundColor3 = down and P.paperDark or P.paper
		end
		label.Position = UDim2.new(0.5, opts.icon and 14 or 0, 0.5, down and 0 or -3)
		if icon then
			icon.Position = UDim2.new(0, 14, 0.5, down and 0 or -3)
		end
	end
	function object:setDisabled(value: boolean)
		object.disabled = value
		face.ImageColor3 = value and Color3.fromRGB(205, 196, 180) or Color3.new(1, 1, 1)
		label.TextColor3 = value and P.faint or color
		if icon then
			icon.ImageTransparency = value and 0.5 or 0
		end
	end
	function object:setText(value: string)
		label.Text = value
	end
	object:setDisabled(object.disabled)
	local hit = hitButton(holder, z + 4)
	hit.MouseButton1Down:Connect(function()
		if not object.disabled then
			paint(true)
		end
	end)
	hit.MouseLeave:Connect(function()
		paint(false)
	end)
	hit.MouseButton1Up:Connect(function()
		paint(false)
	end)
	hit.MouseEnter:Connect(function()
		if not object.disabled then
			UiSound.play("ui_hover")
		end
	end)
	hit.Activated:Connect(function()
		paint(false)
		if object.disabled then
			UiSound.play("error")
			PixelUi.nudge(holder)
			return
		end
		UiSound.play(opts.sound or "ui_click")
		if onClick then
			onClick(object)
		end
	end)
	object.hit = hit
	return object
end

-- Круглая кнопка с иконкой (крестик, стрелки).
function PaperUi.roundButton(parent, pos: UDim2, size: number, iconName: string, onClick, opts)
	opts = opts or {}
	local z = opts.z or 9
	local holder = Instance.new("Frame")
	holder.Name = "RoundButton"
	holder.BackgroundTransparency = 1
	holder.Position = pos
	holder.AnchorPoint = opts.anchor or Vector2.zero
	holder.Size = UDim2.fromOffset(size, size)
	holder.ZIndex = z
	holder.Parent = parent
	local face = PaperUi.image(holder, "btnRoundBig", { Size = UDim2.fromScale(1, 1), ZIndex = z }, { noSlice = true })
	local iconSize = math.floor(size * 0.5)
	local icon = PaperUi.image(holder, iconName, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -2),
		Size = UDim2.fromOffset(iconSize, iconSize),
		ZIndex = z + 1,
	}, { noSlice = true })
	local hit = hitButton(holder, z + 3)
	hit.MouseButton1Down:Connect(function()
		local rect = Pieces.btnRoundBigDown
		if rect and PaperUi.hasAtlas() then
			face.ImageRectOffset = Vector2.new(rect.x, rect.y)
		end
		icon.Position = UDim2.new(0.5, 0, 0.5, 0)
	end)
	local function up()
		local rect = Pieces.btnRoundBig
		if rect and PaperUi.hasAtlas() then
			face.ImageRectOffset = Vector2.new(rect.x, rect.y)
		end
		icon.Position = UDim2.new(0.5, 0, 0.5, -2)
	end
	hit.MouseLeave:Connect(up)
	hit.MouseButton1Up:Connect(up)
	hit.Activated:Connect(function()
		up()
		UiSound.play("ui_click")
		if onClick then
			onClick()
		end
	end)
	return { holder = holder, face = face, icon = icon, hit = hit }
end

-- Строка-полоска (шарик слева, шевроны справа): вкладки, задания, списки.
-- opts: active, text, right (текст справа), knobIcon, knobText (буква в шарике), kind, z, onClick.
function PaperUi.strip(parent, pos: UDim2, size: UDim2, opts)
	opts = opts or {}
	local z = opts.z or 6
	local holder = Instance.new("Frame")
	holder.Name = "Strip"
	holder.BackgroundTransparency = 1
	holder.Position = pos
	holder.Size = size
	holder.ZIndex = z
	holder.Parent = parent
	local height = size.Y.Offset > 0 and size.Y.Offset or 48
	local scale = height / 32
	local kind = opts.kind or (opts.active and "stripRed" or "strip")
	local face = PaperUi.image(holder, kind, { Size = UDim2.fromScale(1, 1), ZIndex = z }, { scale = scale })
	local knobIcon
	if opts.knobIcon then
		local s = math.floor(height * 0.5)
		knobIcon = PaperUi.image(holder, opts.knobIcon, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(math.floor(7.5 * scale), math.floor(height / 2)),
			Size = UDim2.fromOffset(s, s),
			ZIndex = z + 2,
		}, { noSlice = true })
	end
	if opts.knobText then
		-- буква в шарике слева (клавиша вкладки)
		PaperUi.bold(holder, opts.knobText, math.floor(height * 0.3), P.paper, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(math.floor(7.5 * scale), math.floor(height / 2) - 1),
			Size = UDim2.fromOffset(math.floor(height * 0.5), math.floor(height * 0.5)),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = z + 3,
		})
	end
	local left = math.floor(30 * scale)
	local label = PaperUi.bold(holder, opts.text or "", opts.textSize or math.floor(height * 0.4), opts.active and P.red or P.ink, {
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -left - math.floor(34 * scale) - (opts.right and 70 or 0), 1, -2),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = z + 2,
	})
	local right
	if opts.right then
		right = PaperUi.text(holder, opts.right, math.floor(height * 0.36), P.ink2, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -math.floor(30 * scale), 0, 0),
			Size = UDim2.fromOffset(90, height - 2),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = z + 2,
		})
	end
	local object: any = { holder = holder, face = face, label = label, right = right, knob = knobIcon }
	function object:setActive(value: boolean)
		local rect = Pieces[value and "stripRed" or (opts.kind or "strip")]
		if rect and PaperUi.hasAtlas() then
			face.ImageRectOffset = Vector2.new(rect.x, rect.y)
		else
			local stroke = face:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = value and P.red or P.line
			end
		end
		label.TextColor3 = value and P.red or P.ink
	end
	if opts.onClick then
		local hit = hitButton(holder, z + 4)
		hit.MouseEnter:Connect(function()
			PixelUi.tween(holder, 0.08, { Position = pos + UDim2.fromOffset(6, 0) })
		end)
		hit.MouseLeave:Connect(function()
			PixelUi.tween(holder, 0.08, { Position = pos })
		end)
		hit.Activated:Connect(function()
			UiSound.play("ui_click")
			opts.onClick(object)
		end)
		object.hit = hit
	end
	return object
end

-- ===== слоты и иконки =====

-- Иконка предмета: для крупных размеров берёт itL_ (48×48), если есть.
function PaperUi.itemIcon(parent, iconName: string?, center: UDim2, size: number, props)
	if not iconName then
		return nil
	end
	local name = iconName
	if size >= 72 then
		local large = iconName:gsub("^it_", "itL_")
		if Pieces[large] then
			name = large
		end
	end
	local label = PaperUi.image(parent, name, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = center,
		Size = UDim2.fromOffset(size, size),
		ZIndex = 9,
	}, { noSlice = true })
	return apply(label, props)
end

-- Слот сумки/экипировки. opts: icon (кусок бумажного атласа) | pixelIcon (атлас v2),
-- rarityId, count, level, empty (силуэт пустого слота), equipped, selected, dim, z,
-- round (круглый держатель), onClick, iconScale, custom (своя картинка: function(holder, iconSize, z)).
function PaperUi.slot(parent, pos: UDim2, size: number, opts)
	opts = opts or {}
	local z = opts.z or 6
	local holder = Instance.new("Frame")
	holder.Name = "PaperSlot"
	holder.BackgroundTransparency = 1
	holder.Position = pos
	holder.Size = UDim2.fromOffset(size, size)
	holder.ZIndex = z
	holder.Parent = parent
	local base = PaperUi.image(holder, opts.round and "ring80" or "square", {
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
	}, opts.round and { noSlice = true } or { scale = math.max(1, math.floor(size / 40)) })
	local object: any = { holder = holder, base = base }
	local rarityColor = opts.rarityId and UiAssets.Rarity[opts.rarityId]
	if rarityColor then
		-- полоска редкости снизу + уголок
		local bar = Instance.new("Frame")
		bar.Name = "Rarity"
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = PaperUi.rarityInk[opts.rarityId] or rarityColor
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.new(0.5, 0, 1, opts.round and -6 or -5)
		bar.Size = UDim2.new(opts.round and 0.4 or 0.62, 0, 0, 4)
		bar.ZIndex = z + 1
		bar.Parent = holder
		object.rarity = bar
		if opts.rarityId == "legendary" or opts.rarityId == "mythic" or opts.rarityId == "secret" then
			local glow = Instance.new("UIStroke")
			glow.Color = rarityColor
			glow.Thickness = 2
			glow.Transparency = 0.35
			glow.Parent = base
		end
	end
	local iconSize = opts.iconSize or math.floor(size * 0.6 / 16) * 16
	iconSize = math.max(iconSize, 16)
	if opts.icon then
		object.icon = PaperUi.itemIcon(holder, opts.icon, UDim2.fromScale(0.5, 0.48), iconSize, { ZIndex = z + 2 })
	elseif opts.pixelIcon then
		local s = math.floor(size * 0.55)
		object.icon = PixelUi.icon(holder, opts.pixelIcon, UDim2.new(0.5, -s / 2, 0.48, -s / 2), s, { ZIndex = z + 2 })
	elseif opts.custom then
		-- своя картинка (арт сундука и т.п.): custom(holder, iconSize, z) → GuiObject
		object.icon = opts.custom(holder, iconSize, z + 2)
	elseif opts.empty then
		object.icon = PaperUi.itemIcon(holder, opts.empty, UDim2.fromScale(0.5, 0.48), iconSize, { ZIndex = z + 2, ImageTransparency = 0.45 })
	end
	if object.icon and opts.dim then
		object.icon.ImageTransparency = 0.55
	end
	if opts.count and opts.count > 1 then
		PaperUi.bold(holder, "×" .. opts.count, math.max(13, math.floor(size * 0.2)), P.green, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -6, 1, -6),
			Size = UDim2.fromOffset(size, 18),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = z + 4,
		})
	end
	if opts.level and opts.level > 1 then
		PaperUi.bold(holder, "★" .. opts.level, math.max(13, math.floor(size * 0.19)), P.gold, {
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.fromOffset(size, 18),
			ZIndex = z + 4,
		})
	end
	if opts.equipped then
		-- зелёная галочка «надето» (16 px, кратно увеличенная)
		local tick = size >= 72 and 32 or 16
		PaperUi.image(holder, "icCheck", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -3, 0, 3),
			Size = UDim2.fromOffset(tick, tick),
			ZIndex = z + 5,
		}, { noSlice = true })
	end
	if opts.badge then
		local badge = PaperUi.image(holder, "dot", {
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.fromOffset(12, 12),
			ImageColor3 = Color3.fromRGB(220, 70, 60),
			ZIndex = z + 5,
		}, { noSlice = true })
		object.badge = badge
	end
	function object:setSelected(value: boolean)
		if object.brackets then
			for _, b in ipairs(object.brackets) do
				b:Destroy()
			end
			object.brackets = nil
		end
		if not value then
			return
		end
		object.brackets = {}
		local s = math.max(16, math.floor(size * 0.3))
		for _, spec in ipairs({ { "hlTL", 0, 0 }, { "hlTR", 1, 0 }, { "hlBR", 1, 1 }, { "hlBL", 0, 1 } }) do
			local b = PaperUi.image(holder, spec[1], {
				AnchorPoint = Vector2.new(spec[2], spec[3]),
				Position = UDim2.new(spec[2], spec[2] == 0 and -4 or 4, spec[3], spec[3] == 0 and -4 or 4),
				Size = UDim2.fromOffset(s, s),
				ZIndex = z + 6,
			}, { noSlice = true })
			if not PaperUi.hasAtlas() then
				b.BackgroundTransparency = 1
				local stroke = Instance.new("UIStroke")
				stroke.Color = P.red
				stroke.Thickness = 2
				stroke.Parent = b
			end
			table.insert(object.brackets, b)
			-- «дыхание» рамки
			local base = b.Position
			local out = UDim2.new(base.X.Scale, base.X.Offset + (spec[2] == 0 and -2 or 2), base.Y.Scale, base.Y.Offset + (spec[3] == 0 and -2 or 2))
			local tween = game:GetService("TweenService"):Create(b, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = out })
			tween:Play()
		end
	end
	if opts.selected then
		object:setSelected(true)
	end
	if opts.onClick then
		local hit = hitButton(holder, z + 8)
		hit.MouseEnter:Connect(function()
			UiSound.play("ui_hover")
			if object.icon then
				PixelUi.tween(object.icon, 0.08, { Position = object.icon.Position - UDim2.fromOffset(0, 3) })
			end
		end)
		hit.MouseLeave:Connect(function()
			if object.icon then
				PixelUi.tween(object.icon, 0.08, { Position = UDim2.fromScale(0.5, 0.48) + (opts.pixelIcon and UDim2.fromOffset(-math.floor(size * 0.55) / 2, -math.floor(size * 0.55) / 2) or UDim2.new()) })
			end
		end)
		hit.Activated:Connect(function()
			UiSound.play("ui_click")
			opts.onClick(object)
		end)
		object.hit = hit
	end
	return object
end

-- Уголки выделения вокруг holder (как у слота): «дышат». → список деталей (для :Destroy()).
function PaperUi.brackets(holder, size: number, z: number)
	local made = {}
	local s = math.max(16, math.floor(size * 0.24 / 8) * 8)
	for _, spec in ipairs({ { "hlTL", 0, 0 }, { "hlTR", 1, 0 }, { "hlBR", 1, 1 }, { "hlBL", 0, 1 } }) do
		local b = PaperUi.image(holder, spec[1], {
			AnchorPoint = Vector2.new(spec[2], spec[3]),
			Position = UDim2.new(spec[2], spec[2] == 0 and -5 or 5, spec[3], spec[3] == 0 and -5 or 5),
			Size = UDim2.fromOffset(s, s),
			ZIndex = z,
		}, { noSlice = true })
		if not PaperUi.hasAtlas() then
			b.BackgroundTransparency = 1
			local stroke = Instance.new("UIStroke")
			stroke.Color = P.red
			stroke.Thickness = 2
			stroke.Parent = b
		end
		local base = b.Position
		local out = UDim2.new(base.X.Scale, base.X.Offset + (spec[2] == 0 and -2 or 2), base.Y.Scale, base.Y.Offset + (spec[3] == 0 and -2 or 2))
		game:GetService("TweenService"):Create(b, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = out }):Play()
		table.insert(made, b)
	end
	return made
end

-- ===== полосы =====

-- Полоса опыта / здоровья. kind: "xp" | "hp". → объект с :set(ratio, text?)
function PaperUi.bar(parent, pos: UDim2, size: UDim2, ratio: number, kind: string?, z: number?)
	z = z or 6
	local frame = PaperUi.image(parent, "barFrame", { Position = pos, Size = size, ZIndex = z }, { scale = math.max(1, size.Y.Offset / 16) })
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.BorderSizePixel = 0
	back.BackgroundColor3 = Color3.fromRGB(226, 210, 176)
	back.Position = UDim2.fromOffset(4, 4)
	back.Size = UDim2.new(1, -8, 1, -8)
	back.ZIndex = z - 1
	back.Parent = frame
	local clip = Instance.new("Frame")
	clip.Name = "Clip"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Position = UDim2.fromOffset(4, 4)
	clip.Size = UDim2.new(math.clamp(ratio, 0, 1), -8, 1, -8)
	clip.ZIndex = z + 1
	clip.Parent = frame
	local fill = PaperUi.image(clip, kind == "hp" and "barHp" or "barXp", {
		Size = UDim2.new(0, math.max(frame.AbsoluteSize.X, size.X.Offset) - 8, 1, 0),
		ZIndex = z + 1,
	}, { scale = math.max(1, (size.Y.Offset - 8) / 16) })
	local label = PaperUi.bold(frame, "", math.max(12, math.floor(size.Y.Offset * 0.55)), P.ink, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = z + 3,
	})
	local object: any = { frame = frame, clip = clip, fill = fill, label = label }
	function object:set(value: number, text: string?, animate: boolean?)
		local target = UDim2.new(math.clamp(value, 0, 1), -8 * math.clamp(value, 0, 1), 1, -8)
		if animate then
			PixelUi.tween(clip, 0.5, { Size = target })
		else
			clip.Size = target
		end
		label.Text = text or ""
	end
	object:set(ratio)
	return object
end

-- ===== печать =====

-- Анимированная печать: молоток-штамп опускается, остаётся оттиск с текстом.
-- center — центр оттиска, size — его размер. → Frame оттиска.
function PaperUi.stamp(parent, center: UDim2, size: number, text: string?, color: Color3?, z: number?)
	z = z or 14
	local tint = color or P.green
	local mark = PaperUi.image(parent, "stampMark", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = center,
		Size = UDim2.fromOffset(size, size),
		ImageColor3 = tint,
		ImageTransparency = 1,
		Rotation = -12,
		ZIndex = z,
	}, { noSlice = true })
	local label
	if text then
		label = PaperUi.bold(mark, text, math.max(16, math.floor(size * 0.2)), tint, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 2),
			Size = UDim2.new(2, 0, 0, math.floor(size * 0.3)),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTransparency = 1,
			ZIndex = z + 1,
		})
	end
	local function reveal()
		mark.Size = UDim2.fromOffset(size * 1.25, size * 1.25)
		PixelUi.tween(mark, 0.12, { ImageTransparency = 0.05, Size = UDim2.fromOffset(size, size) }, Enum.EasingStyle.Back)
		if label then
			PixelUi.tween(label, 0.12, { TextTransparency = 0 })
		end
	end
	if not PaperUi.hasAtlas() then
		reveal()
		return mark
	end
	-- молоток: кадры stamp1..stamp20 поверх оттиска
	local hammer = PaperUi.image(parent, "stamp1", {
		AnchorPoint = Vector2.new(0.3, 0.75),
		Position = center,
		Size = UDim2.fromOffset(size * 2, size * 2),
		ZIndex = z + 2,
	}, { noSlice = true })
	task.spawn(function()
		for k = 1, 20 do
			local rect = Pieces["stamp" .. k]
			if not hammer.Parent then
				return
			end
			hammer.ImageRectOffset = Vector2.new(rect.x, rect.y)
			if k == 7 then
				reveal()
				UiSound.play("forge_strike", { pitch = 1.6, volume = 0.35 })
			end
			task.wait(0.035)
		end
		PixelUi.tween(hammer, 0.2, { ImageTransparency = 1 })
		task.wait(0.22)
		hammer:Destroy()
	end)
	return mark
end

-- Оттиск без анимации (для уже выполненного).
function PaperUi.seal(parent, center: UDim2, size: number, text: string?, color: Color3?, z: number?)
	local tint = color or P.green
	local mark = PaperUi.image(parent, "stampMark", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = center,
		Size = UDim2.fromOffset(size, size),
		ImageColor3 = tint,
		Rotation = -12,
		ZIndex = z or 14,
	}, { noSlice = true })
	if text then
		PaperUi.bold(mark, text, math.max(16, math.floor(size * 0.2)), tint, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 2),
			Size = UDim2.new(2, 0, 0, math.floor(size * 0.3)),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = (z or 14) + 1,
		})
	end
	return mark
end

-- Появление листа: лёгкий подъём и разворот, как будто кладут на стол.
function PaperUi.drop(object, delay: number?)
	local target = object.Position
	local rot = object.Rotation
	object.Position = target + UDim2.fromOffset(0, 26)
	object.Rotation = rot + 2.5
	task.delay(delay or 0, function()
		if object.Parent then
			PixelUi.tween(object, 0.28, { Position = target, Rotation = rot }, Enum.EasingStyle.Back)
		end
	end)
end

return PaperUi
