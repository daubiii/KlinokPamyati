--!nonstrict
-- FloorBoonController (клиент) — «Дары Эха»: остановка времени и выбор карточки
--
-- Сервер (FloorBoonService) шлёт BoonOffer:
--   stop    — время замерло: мир серо-голубой, размытие, волна от героя, часы;
--   offer   — 3 карточки поднимаются рубашкой вверх и переворачиваются по очереди
--             (редкие и легендарные — со своей вспышкой и звуком);
--   picked  — выбор принят (или выбран случайно по таймеру): карточка улетает
--             в полоску даров слева, остальные падают; «ждём других героев»;
--   resume  — время пошло: цвета возвращаются, волна сжимается обратно.
-- Выбор: клик / 1, 2, 3. Полоска даров слева видна до конца этажа, у каждого
-- значка подсказка с суммой.

local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoonIcons = require(Shared.Config.BoonIcons)
local FloorBoons = require(Shared.Config.FloorBoons)
local UiAssets = require(Shared.Config.UiAssets)
local Net = require(Shared.Net.Net)

local Lib = script.Parent.Parent.Lib
local PaperUi = require(Lib.PaperUi)
local PixelUi = require(Lib.PixelUi)
local UiFx = require(Lib.UiFx)
local UiMotion = require(Lib.UiMotion)
local UiSound = require(Lib.UiSound)

local FloorBoonController = {}

local player = Players.LocalPlayer
local P = PaperUi.colors
local DARK = Color3.fromRGB(20, 16, 22)

-- Раскладка (дизайн 1600×900)
local CARD_W, CARD_H = 300, 430
local CARD_GAP = 56
local CARD_Y = 500
local STRIP_X, STRIP_Y, STRIP_SLOT = 24, 168, 50

local gui, root, canvas
local scene = nil -- текущий выбор
local strip = nil

local function tween(object, time: number, props, style, dir)
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = DARK
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function label(parent, text: string, size: number, color: Color3, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = UiAssets.Font
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.RichText = true
	l.ZIndex = 20
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	l.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = math.max(2, math.floor(size / 9))
	stroke.Color = Color3.fromRGB(10, 6, 8)
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.Parent = l
	return l
end

local function hex(c: Color3): string
	return ("#%02X%02X%02X"):format(math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

-- ===== пиксельная иконка из Config/BoonIcons: полосы одного цвета в строке =====

local function pixelIcon(parent, iconId: string, pixel: number, z: number?)
	local icon = BoonIcons[iconId]
	local n = BoonIcons.size
	local holder = frame(parent, { BackgroundTransparency = 1, Size = UDim2.fromOffset(n * pixel, n * pixel), ZIndex = z or 20 })
	if not icon then
		return holder
	end
	for y, row in ipairs(icon.rows) do
		local x = 1
		while x <= #row do
			local ch = row:sub(x, x)
			local run = 1
			while x + run <= #row and row:sub(x + run, x + run) == ch do
				run += 1
			end
			if ch ~= "." and icon.pal[ch] then
				frame(holder, {
					BackgroundColor3 = icon.pal[ch],
					Position = UDim2.fromOffset((x - 1) * pixel, (y - 1) * pixel),
					Size = UDim2.fromOffset(run * pixel, pixel),
					ZIndex = z or 20,
				})
			end
			x += run
		end
	end
	return holder
end

-- ===== остановка времени: цвет, размытие, волна, часы =====

local timeFx = { cc = nil, blur = nil, active = false }

local function effects()
	if not (timeFx.cc and timeFx.cc.Parent) then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "KlinokBoonTime"
		cc.Enabled = true
		cc.Parent = Lighting
		timeFx.cc = cc
	end
	if not (timeFx.blur and timeFx.blur.Parent) then
		local blur = Instance.new("BlurEffect")
		blur.Name = "KlinokBoonBlur"
		blur.Size = 0
		blur.Parent = Lighting
		timeFx.blur = blur
	end
	return timeFx.cc, timeFx.blur
end

-- Прозрачная сфера-волна вокруг героя (в мире).
local function worldRipple(grow: boolean)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	local ball = Instance.new("Part")
	ball.Name = "BoonRipple"
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.ForceField
	ball.Color = Color3.fromRGB(150, 210, 255)
	local big, small = Vector3.new(70, 70, 70), Vector3.new(2, 2, 2)
	ball.Size = grow and small or big
	ball.Transparency = grow and 0.2 or 0.85
	ball.CFrame = rootPart.CFrame
	ball.Parent = Workspace
	tween(ball, grow and 0.9 or 0.6, { Size = grow and big or small, Transparency = grow and 1 or 0.3 }, Enum.EasingStyle.Quart)
	task.delay(1, function()
		ball:Destroy()
	end)
end

-- Кольцо по экрану из центра.
local function screenRipple(parent, color: Color3, grow: boolean)
	local ring = frame(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = grow and UDim2.fromOffset(40, 40) or UDim2.fromOffset(2200, 2200),
		BackgroundTransparency = 1,
		ZIndex = 5,
	})
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 10
	stroke.Color = color
	stroke.Transparency = 0.2
	stroke.Parent = ring
	tween(ring, 0.8, { Size = grow and UDim2.fromOffset(2200, 2200) or UDim2.fromOffset(40, 40) }, Enum.EasingStyle.Quart)
	tween(stroke, 0.8, { Transparency = 1, Thickness = 2 })
	task.delay(0.85, function()
		ring:Destroy()
	end)
end

local function timeStop()
	if timeFx.active then
		return
	end
	timeFx.active = true
	local cc, blur = effects()
	tween(cc, 0.45, { Saturation = -0.75, Contrast = 0.08, Brightness = -0.03, TintColor = Color3.fromRGB(205, 225, 255) })
	tween(blur, 0.6, { Size = 18 })
	worldRipple(true)
	UiSound.play("boon_stop")
	UiFx.shake(0.25, 0.25)
end

local function timeResume()
	if not timeFx.active then
		return
	end
	timeFx.active = false
	local cc, blur = effects()
	tween(cc, 0.5, { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
	tween(blur, 0.4, { Size = 0 })
	worldRipple(false)
	UiSound.play("boon_resume")
end

-- Циферблат за карточками: кольцо, 12 рисок, стрелки стоят.
local function clockFace(parent)
	local size = 600
	local dial = frame(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(800, CARD_Y),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 3,
	})
	Instance.new("UICorner", dial).CornerRadius = UDim.new(1, 0)
	local ring = Instance.new("UIStroke")
	ring.Thickness = 6
	ring.Color = Color3.fromRGB(150, 200, 255)
	ring.Transparency = 0.7
	ring.Parent = dial
	for i = 0, 11 do
		local holder = frame(dial, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(12, size - 30),
			BackgroundTransparency = 1,
			Rotation = i * 30,
			ZIndex = 3,
		})
		frame(holder, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(i % 3 == 0 and 10 or 6, i % 3 == 0 and 34 or 20),
			BackgroundColor3 = Color3.fromRGB(150, 200, 255),
			BackgroundTransparency = 0.6,
			ZIndex = 3,
		})
	end
	for _, hand in ipairs({ { 0.32, 10, -50 }, { 0.42, 6, 62 } }) do
		local holder = frame(dial, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(hand[2], size * hand[1] * 2),
			BackgroundTransparency = 1,
			Rotation = hand[3],
			ZIndex = 3,
		})
		frame(holder, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(1, 0, 0.5, 0),
			BackgroundColor3 = Color3.fromRGB(150, 200, 255),
			BackgroundTransparency = 0.55,
			ZIndex = 3,
		})
	end
	dial.Rotation = -8
	tween(dial, 1.2, { Rotation = 0 }, Enum.EasingStyle.Back)
	return dial
end

-- Пылинки висят в воздухе (время стоит) и мерцают.
local function frozenDust(parent)
	local specks = {}
	for _ = 1, 42 do
		local s = math.random(1, 3) * 2
		local speck = frame(parent, {
			Position = UDim2.fromScale(math.random(), math.random()),
			Size = UDim2.fromOffset(s, s),
			BackgroundColor3 = Color3.fromRGB(200, 225, 255),
			BackgroundTransparency = 0.4 + math.random() * 0.4,
			ZIndex = 4,
		})
		table.insert(specks, { speck, math.random() * math.pi * 2, 0.5 + math.random() })
	end
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		for _, item in ipairs(specks) do
			if item[1].Parent then
				item[1].BackgroundTransparency = 0.45 + 0.4 * (0.5 + 0.5 * math.sin(t * item[3] + item[2]))
			end
		end
	end)
	return conn
end

-- Фон выбора на весь экран (а не на холст 1600×900 — иначе по краям широкого
-- экрана был виден серый прямоугольник): холодная тонировка поверх размытого
-- мира, тёмная виньетка по краям, мягкий свет за карточками, пыль в воздухе.
-- Слои: { объект, свойство, целевая прозрачность } — для появления и ухода.
local function backdrop()
	local holder = frame(gui, {
		Name = "BoonBackdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
	})
	local layers = {}
	local function layer(color: Color3, target: number, gradient)
		local f = frame(holder, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = 1, ZIndex = 1 })
		if gradient then
			local g = Instance.new("UIGradient")
			g.Rotation = gradient.rotation
			g.Transparency = gradient.seq
			g.Parent = f
		end
		table.insert(layers, { f, "BackgroundTransparency", target })
		return f
	end
	-- общая тонировка: мир виден, но приглушён
	layer(Color3.fromRGB(12, 16, 34), 0.5)
	-- виньетка: сверху-снизу и по бокам темнее, к центру прозрачно
	layer(Color3.fromRGB(3, 4, 10), 0.05, {
		rotation = 90,
		seq = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.28, 0.8),
			NumberSequenceKeypoint.new(0.72, 0.8),
			NumberSequenceKeypoint.new(1, 0),
		}),
	})
	layer(Color3.fromRGB(3, 4, 10), 0.05, {
		rotation = 0,
		seq = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.22, 0.85),
			NumberSequenceKeypoint.new(0.78, 0.85),
			NumberSequenceKeypoint.new(1, 0.1),
		}),
	})
	-- холодный свет за карточками, медленно «дышит»
	local light = PixelUi.glow(holder, UDim2.fromScale(0.5, 0.55), UDim2.new(0.9, 0, 0.95, 0), Color3.fromRGB(150, 195, 255), 1)
	light.ZIndex = 2
	table.insert(layers, { light, "ImageTransparency", 0.78 })
	local dust = frozenDust(holder)
	local t0 = os.clock()
	local breathe = RunService.RenderStepped:Connect(function()
		if light.Parent and light:GetAttribute("Ready") then
			light.ImageTransparency = 0.78 + 0.06 * math.sin((os.clock() - t0) * 1.3)
		end
	end)
	for _, item in ipairs(layers) do
		tween(item[1], 0.45, { [item[2]] = item[3] })
	end
	task.delay(0.46, function()
		light:SetAttribute("Ready", true)
	end)
	return {
		holder = holder,
		close = function(instant: boolean?)
			dust:Disconnect()
			breathe:Disconnect()
			if instant then
				holder:Destroy()
				return
			end
			light:SetAttribute("Ready", nil)
			for _, child in ipairs(holder:GetDescendants()) do
				if child:IsA("Frame") then
					tween(child, 0.4, { BackgroundTransparency = 1 })
				elseif child:IsA("ImageLabel") then
					tween(child, 0.4, { ImageTransparency = 1 })
				end
			end
			task.delay(0.45, function()
				holder:Destroy()
			end)
		end,
	}
end

-- ===== карточка =====

local function rarityOf(index: number)
	return FloorBoons.Rarities[index] or FloorBoons.Rarities[1]
end

-- Цвет редкости «чернилами» — как редкость предметов в «Книге героя».
local RARITY_KEY = { "common", "rare", "legendary" }
-- строка под кольцом (string.lower не знает кириллицу — пишем сразу строчными)
local RARITY_LINE = { "обычный дар", "редкий дар", "легендарный дар" }
local function rarityInk(index: number): Color3
	return PaperUi.rarityInk[RARITY_KEY[index] or "common"]
end

local function valueText(card, value: number): string
	if card.kind == "pct" then
		return "+" .. FloorBoons.format("pct", value)
	elseif card.kind == "mult" then
		return "×" .. FloorBoons.format("mult", value)
	end
	return "+" .. FloorBoons.format(card.kind, value)
end

-- Описание: числа жирные, крупнее, цветом редкости (у обычной — чернилами).
local function richDescription(cardId: string, rarity: number): string
	local color = rarity == 1 and P.ink or rarityInk(rarity)
	local text = FloorBoons.describe(cardId, rarity)
	text = text:gsub("([%+×]?%d[%d,]*%%?)", function(num)
		return ('<font color="%s" size="28"><b>%s</b></font>'):format(hex(color), num)
	end)
	return text
end

local function paperLabel(parent, text: string, size: number, color: Color3, face, props)
	local l = PaperUi.text(parent, text, size, color, props)
	l.FontFace = face or PaperUi.Font
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.RichText = true
	l.TextWrapped = true
	return l
end

-- Рубашка: лист потемнее, в центре книга героя.
local function cardBack(parent)
	local back = PaperUi.sheet(parent, UDim2.fromOffset(0, 0), UDim2.fromOffset(CARD_W, CARD_H), { kind = "sheetAlt", back = false, z = 20, name = "Back" })
	PaperUi.image(back, "book", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.46, 0),
		Size = UDim2.fromOffset(64 * 3, 80 * 3),
		ZIndex = 21,
	}, { noSlice = true })
	paperLabel(back, "Дар Эха", 22, P.ink2, PaperUi.FontItalic, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -48),
		Size = UDim2.fromOffset(240, 30),
		ZIndex = 21,
	})
	return back
end

-- Лицо: лист «Книги героя», лента с именем, кольцо с иконкой, строка редкости,
-- завиток, описание чернилами, печать редкости.
local function cardFace(parent, data)
	local card = FloorBoons.ById[data.id]
	local ink = rarityInk(data.rarity)
	local face = PaperUi.sheet(parent, UDim2.fromOffset(0, 0), UDim2.fromOffset(CARD_W, CARD_H), { z = 10, name = "Face" })
	-- рамка чернилами у редкой и легендарной (у легендарной двойная)
	if data.rarity >= 2 then
		for k, inset in ipairs(data.rarity == 3 and { 16, 21 } or { 16 }) do
			local line = frame(face, {
				Position = UDim2.fromOffset(inset, inset),
				Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
				BackgroundTransparency = 1,
				ZIndex = 11,
			})
			local stroke = Instance.new("UIStroke")
			stroke.Color = ink
			stroke.Thickness = k == 1 and 2 or 1
			stroke.Transparency = k == 1 and 0.35 or 0.5
			stroke.Parent = line
		end
	end
	-- лента с именем
	PaperUi.ribbon(face, UDim2.fromOffset(-22, -22), CARD_W + 44, card.name, { height = 64, z = 14, textSize = 24, color = P.green })
	-- кольцо с иконкой
	PaperUi.image(face, "ring80", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 66),
		Size = UDim2.fromOffset(160, 160),
		ZIndex = 12,
	}, { noSlice = true })
	local icon = pixelIcon(face, card.icon, 5, 13)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0.5, 0, 0, 146)
	-- редкость курсивом между двумя точками
	paperLabel(face, RARITY_LINE[data.rarity] or "", 20, ink, PaperUi.FontItalic, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 246),
		Size = UDim2.fromOffset(220, 26),
		ZIndex = 13,
	})
	for _, side in ipairs({ -1, 1 }) do
		frame(face, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, side * 92, 0, 246),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = ink,
			ZIndex = 13,
		})
	end
	PaperUi.divider(face, UDim2.new(0.5, -100, 0, 262), 200, 13)
	-- описание
	paperLabel(face, richDescription(data.id, data.rarity), 21, P.ink, PaperUi.FontBold, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 286),
		Size = UDim2.fromOffset(CARD_W - 36, 84),
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.05,
		ZIndex = 13,
	})
	-- подвал: «новый дар» или «было → станет»
	local foot
	if (data.count or 0) > 0 and not card.instant then
		foot = ("Уже есть ×%d · станет %s"):format(data.count, valueText(card, data.after or 0))
	elseif (data.count or 0) > 0 then
		foot = ("Взят уже %d раз"):format(data.count)
	else
		foot = "Новый дар"
	end
	paperLabel(face, foot, 17, (data.count or 0) > 0 and P.green or P.faint, PaperUi.FontItalic, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, data.rarity >= 2 and -18 or 0, 1, -58),
		Size = UDim2.fromOffset(CARD_W - 70, 24),
		ZIndex = 13,
	})
	-- печать редкости в углу
	if data.rarity >= 2 then
		PaperUi.seal(face, UDim2.new(1, -44, 1, -40), 56, nil, ink, 15)
	end
	return face
end

local function buildCard(parent, data, index: number, x: number)
	local rarity = rarityOf(data.rarity)
	local tilt = ({ -2.0, 0.8, 2.2 })[index] or 0
	local holder = frame(parent, {
		Name = "Card" .. index,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, CARD_Y + 720),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundTransparency = 1,
		Rotation = tilt * 3,
		ZIndex = 9,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	-- мягкий свет редкости за листом (обычная — без)
	local glow = PixelUi.glow(holder, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(CARD_W + 120, CARD_H + 120), rarity.glow, 1)
	glow.ZIndex = 7
	local shadow = frame(holder, {
		Position = UDim2.fromOffset(10, 14),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		ZIndex = 8,
	})
	local face = cardFace(holder, data)
	face.Visible = false
	local back = cardBack(holder)
	-- клавиша на бумажной плашке
	local key = PaperUi.image(holder, "plate", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 14),
		Size = UDim2.fromOffset(40, 40),
		ZIndex = 12,
	}, { scale = 1 })
	paperLabel(key, tostring(index), 22, P.ink, PaperUi.FontBold, { Size = UDim2.fromScale(1, 1), ZIndex = 13 })
	key.Visible = false
	local hit = Instance.new("TextButton")
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.AutoButtonColor = false
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 60
	hit.Active = false
	hit.Parent = holder

	local glowRest = data.rarity == 1 and 1 or (data.rarity == 2 and 0.72 or 0.5)
	local obj: any = { holder = holder, scale = scale, glow = glow, data = data, index = index, x = x, ready = false, hit = hit, key = key, face = face }

	function obj.rise(delay: number)
		task.delay(delay, function()
			UiSound.play("boon_rise", { pitch = 0.95 + index * 0.05 })
			tween(holder, 0.5, { Position = UDim2.fromOffset(x, CARD_Y), Rotation = tilt }, Enum.EasingStyle.Back)
		end)
	end

	-- Переворот: рубашка поднимается и уходит в сторону, как снятый лист.
	function obj.reveal(delay: number)
		task.delay(delay, function()
			if not holder.Parent then
				return
			end
			UiSound.play("page_turn")
			face.Visible = true
			tween(back, 0.32, { Position = UDim2.fromOffset(46 * (index - 2) + 18, -70), Rotation = 14 * (index == 1 and -1 or 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			for _, d in ipairs(back:GetDescendants()) do
				if d:IsA("ImageLabel") then
					tween(d, 0.3, { ImageTransparency = 1 })
				elseif d:IsA("TextLabel") then
					tween(d, 0.3, { TextTransparency = 1 })
				end
			end
			task.delay(0.34, function()
				back:Destroy()
			end)
			tween(glow, 0.5, { ImageTransparency = glowRest })
			UiMotion.punch(holder, 0.04, 0.2)
			if data.rarity == 3 then
				UiSound.play("boon_reveal_legend")
				UiFx.burst(canvas, Vector2.new(x, CARD_Y - 80), { rarity.glow, rarity.color, P.paper }, 30, 220)
				UiFx.shake(0.2, 0.2)
			elseif data.rarity == 2 then
				UiSound.play("boon_reveal_rare")
				UiFx.burst(canvas, Vector2.new(x, CARD_Y - 80), { rarity.glow, rarity.color }, 16, 160)
			end
			key.Visible = true
			obj.ready = true
			hit.Active = true
		end)
	end

	function obj.setHover(on: boolean)
		if not obj.ready or obj.done then
			return
		end
		obj.hover = on
		tween(scale, 0.14, { Scale = on and 1.04 or 1 }, Enum.EasingStyle.Quad)
		tween(holder, 0.16, { Position = UDim2.fromOffset(x, CARD_Y + (on and -16 or 0)), Rotation = on and 0 or tilt })
		tween(glow, 0.2, { ImageTransparency = on and math.min(glowRest, 0.55) or glowRest })
		if on then
			UiSound.play("boon_hover")
		end
	end

	-- Выбранная: штамп «ВЗЯТО» цветом редкости, потом лист улетает в полоску даров.
	function obj.take(target: Vector2)
		obj.done = true
		hit.Active = false
		key.Visible = false
		tween(holder, 0.14, { Position = UDim2.fromOffset(x, CARD_Y - 10), Rotation = 0 })
		UiSound.play(data.rarity == 3 and "boon_pick_legend" or "boon_pick")
		PaperUi.stamp(face, UDim2.new(0.5, 0, 0.5, 6), 120, "ВЗЯТО", data.rarity == 1 and P.green or rarityInk(data.rarity), 30)
		task.delay(0.55, function()
			UiFx.burst(canvas, Vector2.new(x, CARD_Y), { rarity.glow, rarity.color, P.paper }, 30, 220)
		end)
		task.delay(1.0, function()
			if not holder.Parent then
				return
			end
			tween(holder, 0.5, { Position = UDim2.fromOffset(target.X, target.Y), Rotation = -8 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			tween(scale, 0.5, { Scale = 0.12 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			tween(glow, 0.3, { ImageTransparency = 1 })
			tween(shadow, 0.3, { BackgroundTransparency = 1 })
		end)
	end

	function obj.drop(delay: number)
		obj.done = true
		hit.Active = false
		key.Visible = false
		task.delay(delay, function()
			if not holder.Parent then
				return
			end
			tween(holder, 0.45, { Position = UDim2.fromOffset(x, CARD_Y + 760), Rotation = tilt * 5 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			tween(glow, 0.3, { ImageTransparency = 1 })
		end)
	end

	return obj
end

-- ===== полоска даров (слева, до конца этажа): бумажные слоты как в сумке =====

local function boonList()
	local raw = player:GetAttribute("FloorBoons")
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and type(list) == "table" and list or {}
end

local function totalText(card, have): string
	if card.id == "soul_surge" then
		return ("Предел душ +%d"):format(have.extra or 0)
	elseif card.id == "second_wind" then
		return ("Взято %d раз"):format(have.count)
	end
	return valueText(card, have.total) .. (card.cap and have.total >= card.cap - 1e-6 and "  (предел)" or "")
end

local function buildStrip()
	local holder = frame(root, {
		Name = "BoonStrip",
		Position = UDim2.fromOffset(STRIP_X, STRIP_Y),
		Size = UDim2.fromOffset(STRIP_SLOT, 600),
		BackgroundTransparency = 1,
		ZIndex = 5,
	})
	local tip = PaperUi.sheet(root, UDim2.fromOffset(0, 0), UDim2.fromOffset(280, 84), { kind = "sheetPlain", back = false, z = 60, name = "BoonTip" })
	tip.Visible = false
	local tipTitle = paperLabel(tip, "", 20, P.green, PaperUi.FontBold, {
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 61,
	})
	tipTitle.TextXAlignment = Enum.TextXAlignment.Left
	local tipText = paperLabel(tip, "", 18, P.ink, PaperUi.Font, {
		Position = UDim2.fromOffset(16, 44),
		Size = UDim2.new(1, -32, 0, 24),
		ZIndex = 61,
	})
	tipText.TextXAlignment = Enum.TextXAlignment.Left
	return { holder = holder, tip = tip, tipTitle = tipTitle, tipText = tipText, slots = {} }
end

local function refreshStrip(pulseId: string?)
	if not strip then
		return
	end
	for _, slot in ipairs(strip.slots) do
		slot:Destroy()
	end
	strip.slots = {}
	local onFloor = player:GetAttribute("Zone") == "Floor"
	local totals = FloorBoons.totals(boonList())
	local order = {}
	for _, card in ipairs(FloorBoons.Cards) do
		if totals[card.id] then
			table.insert(order, card)
		end
	end
	strip.holder.Visible = onFloor and #order > 0
	strip.tip.Visible = false
	for i, card in ipairs(order) do
		local have = totals[card.id]
		local slot = PaperUi.slot(strip.holder, UDim2.fromOffset(0, (i - 1) * (STRIP_SLOT + 8)), STRIP_SLOT, {
			rarityId = RARITY_KEY[have.best],
			z = 6,
			custom = function(holderFrame, _, z)
				local icon = pixelIcon(holderFrame, card.icon, 2, z)
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Position = UDim2.fromScale(0.5, 0.46)
				return icon
			end,
		})
		local slotHolder = slot.holder
		if have.count > 1 then
			local count = PaperUi.bold(slotHolder, "×" .. have.count, 18, P.paper, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, 6, 1, 6),
				Size = UDim2.fromOffset(40, 20),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 12,
			})
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 2
			stroke.Color = P.ink
			stroke.Parent = count
		end
		local hover = Instance.new("TextButton")
		hover.Text = ""
		hover.BackgroundTransparency = 1
		hover.Size = UDim2.fromScale(1, 1)
		hover.ZIndex = 14
		hover.Parent = slotHolder
		hover.MouseEnter:Connect(function()
			strip.tip.Position = UDim2.fromOffset(STRIP_X + STRIP_SLOT + 12, STRIP_Y + (i - 1) * (STRIP_SLOT + 8) - 16)
			strip.tipTitle.Text = card.name
			strip.tipText.Text = totalText(card, have)
			strip.tip.Visible = true
		end)
		hover.MouseLeave:Connect(function()
			strip.tip.Visible = false
		end)
		if pulseId == card.id then
			UiMotion.popIn(slotHolder, 0, 1.6)
		end
		table.insert(strip.slots, slotHolder)
	end
end

local function stripSlotCenter(cardId: string): Vector2
	local totals = FloorBoons.totals(boonList())
	local n = 0
	for _, card in ipairs(FloorBoons.Cards) do
		if totals[card.id] or card.id == cardId then
			n += 1
		end
		if card.id == cardId then
			break
		end
	end
	-- полоска лежит в корне, карточки — на холсте 1600×900 по его центру
	-- (масштаб у них общий — UIScale корня): сдвиг на поля корня.
	local inRoot = Vector2.new(STRIP_X + STRIP_SLOT / 2, STRIP_Y + (n - 1) * (STRIP_SLOT + 8) + STRIP_SLOT / 2)
	local margin = Vector2.new((root.Size.X.Offset - PixelUi.DESIGN.X) / 2, (root.Size.Y.Offset - PixelUi.DESIGN.Y) / 2)
	return inRoot - margin
end

-- ===== сцена выбора =====

local pickAction = "KlinokBoonPick"

local function closeScene(instant: boolean?)
	local s = scene
	if not s then
		return
	end
	scene = nil
	ContextActionService:UnbindAction(pickAction)
	if s.backdrop then
		s.backdrop.close(instant)
	end
	if s.timer then
		s.timer:Disconnect()
	end
	local overlay = s.overlay
	if instant then
		overlay:Destroy()
		return
	end
	for _, child in ipairs(overlay:GetDescendants()) do
		if child:IsA("Frame") then
			tween(child, 0.35, { BackgroundTransparency = 1 })
		elseif child:IsA("TextLabel") then
			tween(child, 0.3, { TextTransparency = 1 })
		elseif child:IsA("UIStroke") then
			tween(child, 0.3, { Transparency = 1 })
		elseif child:IsA("ImageLabel") then
			tween(child, 0.3, { ImageTransparency = 1 })
		end
	end
	tween(overlay, 0.35, { BackgroundTransparency = 1 })
	task.delay(0.4, function()
		overlay:Destroy()
	end)
end

local function choose(index: number)
	local s = scene
	if not s or s.chosen or not s.cards[index] or not s.cards[index].ready then
		return
	end
	s.chosen = index
	local remote = Net.get("BoonPick")
	if remote then
		remote:FireServer(index)
	end
	local chosen = s.cards[index]
	chosen.take(stripSlotCenter(chosen.data.id))
	for i, card in ipairs(s.cards) do
		if i ~= index then
			card.drop(0.1 + 0.08 * i)
		end
	end
	if s.timerBar then
		tween(s.timerBar, 0.3, { BackgroundTransparency = 1 })
	end
end

local function waitingNote(s, left: number)
	if not s.wait then
		s.wait = paperLabel(s.overlay, "", 24, Color3.fromRGB(232, 236, 250), PaperUi.FontItalic, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.78),
			Size = UDim2.fromOffset(900, 40),
			ZIndex = 30,
		})
	end
	s.wait.Text = left > 0 and ("Дар принят. Ждём других героев: %d"):format(left) or "Дар принят"
end

local function openOffer(payload)
	if scene then
		closeScene(true)
	end
	timeStop()
	local overlay = frame(canvas, {
		Name = "BoonScene",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})
	-- курсор свободен (камера могла держать его по центру)
	local modal = Instance.new("TextButton")
	modal.Text = ""
	modal.BackgroundTransparency = 1
	modal.Modal = true
	modal.Size = UDim2.fromScale(1, 1)
	modal.ZIndex = 2
	modal.Parent = overlay
	local s: any = { overlay = overlay, cards = {}, chosen = nil, payload = payload }
	scene = s
	s.backdrop = backdrop()
	clockFace(overlay)
	screenRipple(overlay, Color3.fromRGB(170, 215, 255), true)
	-- заголовок — дуга «Книги героя»
	local arc, title = PaperUi.header(overlay, UDim2.fromOffset(800, 30), 432, "Дар Эха", { z = 30, textSize = 34, color = P.green })
	-- по умолчанию текст на 0.34 высоты дуги — крупная надпись садилась на нижний
	-- край ленты; выше — ровно по середине полотна
	title.Position = UDim2.new(0.5, 0, 0.26, 0)
	local sub = paperLabel(overlay, "Время замерло. Выбери один дар — до конца этажа", 22, Color3.fromRGB(232, 236, 250), PaperUi.FontItalic, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(800, 178),
		Size = UDim2.fromOffset(1100, 30),
		ZIndex = 30,
	})
	local subStroke = Instance.new("UIStroke")
	subStroke.Thickness = 3
	subStroke.Color = Color3.fromRGB(14, 12, 20)
	subStroke.Parent = sub
	if (payload.queued or 0) > 0 then
		sub.Text ..= ("   (ещё выборов: %d)"):format(payload.queued)
	end
	PaperUi.drop(arc, 0.05)
	title.TextTransparency = 1
	sub.TextTransparency = 1
	tween(title, 0.4, { TextTransparency = 0 })
	tween(sub, 0.5, { TextTransparency = 0 })
	local titleScale = Instance.new("UIScale")
	titleScale.Scale = 1.4
	titleScale.Parent = title
	tween(titleScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	-- карточки
	local n = #payload.cards
	local total = n * CARD_W + (n - 1) * CARD_GAP
	for i, data in ipairs(payload.cards) do
		local x = 800 - total / 2 + CARD_W / 2 + (i - 1) * (CARD_W + CARD_GAP)
		local card = buildCard(overlay, data, i, x)
		s.cards[i] = card
		card.rise(0.25 + 0.12 * i)
		card.reveal(0.95 + 0.28 * i)
		card.hit.MouseEnter:Connect(function()
			card.setHover(true)
		end)
		card.hit.MouseLeave:Connect(function()
			card.setHover(false)
		end)
		card.hit.Activated:Connect(function()
			choose(i)
		end)
	end
	-- лучи медальонов редких и легендарных медленно крутятся
	local t0 = os.clock()
	s.timer = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		for _, card in ipairs(s.cards) do
			if card.rays and card.data.rarity >= 2 then
				card.rays.Rotation = t * (card.data.rarity == 3 and 22 or 12)
			end
		end
		if s.deadline and s.timerBar and not s.chosen then
			local left = math.max(s.deadline - os.clock(), 0)
			s.timerBar.Size = UDim2.fromOffset(600 * left / s.timeout, 8)
			local whole = math.ceil(left)
			if whole <= 5 and whole ~= s.lastTick and left > 0 then
				s.lastTick = whole
				UiSound.play("boon_tick")
			end
			s.timerText.Text = ("%d"):format(whole)
		end
	end)
	-- таймер группы
	if payload.timeout then
		s.timeout = payload.timeout
		s.deadline = os.clock() + payload.timeout
		local bg = frame(overlay, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(800, CARD_Y + CARD_H / 2 + 92),
			Size = UDim2.fromOffset(604, 12),
			BackgroundColor3 = Color3.fromRGB(20, 20, 30),
			ZIndex = 20,
		})
		s.timerBar = frame(bg, { Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(600, 8), BackgroundColor3 = Color3.fromRGB(150, 200, 255), ZIndex = 21 })
		s.timerText = label(overlay, "", 18, Color3.fromRGB(200, 220, 255), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(800 + 330, CARD_Y + CARD_H / 2 + 92),
			Size = UDim2.fromOffset(60, 24),
			ZIndex = 21,
		})
	end
	-- клавиши 1–3
	ContextActionService:BindActionAtPriority(pickAction, function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end
		local map = {
			[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
			[Enum.KeyCode.KeypadOne] = 1, [Enum.KeyCode.KeypadTwo] = 2, [Enum.KeyCode.KeypadThree] = 3,
		}
		local index = map[input.KeyCode]
		if index then
			choose(index)
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.KeypadOne, Enum.KeyCode.KeypadTwo, Enum.KeyCode.KeypadThree)
	UserInputService.MouseIconEnabled = true
end

local function onPicked(payload)
	local s = scene
	if s and not s.chosen and payload.id then
		-- по таймеру сервер выбрал сам: показать, какая
		for i, card in ipairs(s.cards) do
			if card.data.id == payload.id and card.data.rarity == payload.rarity then
				s.chosen = i
				card.take(stripSlotCenter(card.data.id))
				for j, other in ipairs(s.cards) do
					if j ~= i then
						other.drop(0.1 + 0.08 * j)
					end
				end
				break
			end
		end
	end
	if s then
		waitingNote(s, payload.waiting or 0)
	end
	task.delay(0.9, function()
		refreshStrip(payload.id)
	end)
end

local function onBoon(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.kind == "stop" then
		timeStop()
	elseif payload.kind == "offer" then
		openOffer(payload)
	elseif payload.kind == "picked" then
		onPicked(payload)
	elseif payload.kind == "resume" then
		local s = scene
		task.delay(s and 0.5 or 0, function()
			if scene == s then
				closeScene(false)
			end
			timeResume()
			refreshStrip()
		end)
	end
end

function FloorBoonController.start()
	gui, root = PixelUi.screen("KlinokBoons", 40)
	root.ZIndex = 2 -- карточки и полоска даров поверх фона выбора (он — сосед корня, ZIndex 1)
	canvas = PixelUi.canvas(root)
	strip = buildStrip()
	refreshStrip()
	player:GetAttributeChangedSignal("FloorBoons"):Connect(function()
		if not scene then
			refreshStrip()
		end
	end)
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		refreshStrip()
	end)
	local remote = Net.get("BoonOffer")
	if remote then
		remote.OnClientEvent:Connect(onBoon)
	end
	-- Новый персонаж / выход с этажа во время паузы — не оставлять серый мир.
	player.CharacterAdded:Connect(function()
		if not player:GetAttribute("BoonPause") then
			closeScene(true)
			timeResume()
		end
	end)
end

return FloorBoonController
