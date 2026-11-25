--!nonstrict
-- WallWindow — Стена забытых имён. Каменная плита поверх настоящей стены:
-- вкладки, 7 табличек (тройка — с медалями и голубыми свечами), строка игрока
-- с подсказкой «ещё N до …».

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiAssets = require(Shared.Config.UiAssets)

local Lib = script.Parent.Parent.Lib
local PixelUi = require(Lib.PixelUi)
local UiMotion = require(Lib.UiMotion)
local UiSound = require(Lib.UiSound)
local WindowBase = require(Lib.WindowBase)

local WallWindow = {}

local C = UiAssets.Colors
local win, ctx
local refs: any = {}
local TABS = { { "deep", "Глубже всех" }, { "souls", "Больше душ" }, { "week", "За неделю" } }
local MEDAL = { Color3.fromRGB(255, 204, 84), Color3.fromRGB(215, 222, 232), Color3.fromRGB(210, 130, 76) }

local function slab(parent)
	-- каменная плита: тёмно-серая, с «кладкой» тонкими линиями
	local plate = Instance.new("Frame")
	plate.BorderSizePixel = 0
	plate.BackgroundColor3 = Color3.fromRGB(78, 84, 96)
	plate.BackgroundTransparency = 0.08
	plate.Position = UDim2.fromOffset(280, 148)
	plate.Size = UDim2.fromOffset(1040, 724)
	plate.ZIndex = 2
	plate.Parent = parent
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	g.Parent = plate
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(26, 16, 10)
	stroke.Thickness = 3
	stroke.Parent = plate
	for row = 0, 29 do
		local l = Instance.new("Frame")
		l.BorderSizePixel = 0
		l.BackgroundColor3 = Color3.fromRGB(52, 56, 66)
		l.Position = UDim2.fromOffset(0, row * 24)
		l.Size = UDim2.new(1, 0, 0, 2)
		l.ZIndex = 2
		l.Parent = plate
	end
	for _, x in ipairs({ -16, 1032 }) do
		local col = Instance.new("Frame")
		col.BorderSizePixel = 0
		col.BackgroundColor3 = Color3.fromRGB(150, 156, 168)
		col.Position = UDim2.fromOffset(x, -16)
		col.Size = UDim2.new(0, 24, 1, 16)
		col.ZIndex = 3
		col.Parent = plate
		local cs = Instance.new("UIStroke")
		cs.Color = Color3.fromRGB(26, 16, 10)
		cs.Thickness = 2
		cs.Parent = col
	end
	return plate
end

-- Число «набегает» от 0 до value.
local function countUp(label, value, delay: number)
	local n = tonumber(value)
	if not n then
		return
	end
	label.Text = "0"
	task.delay(delay, function()
		local t0 = os.clock()
		while label.Parent and os.clock() - t0 < 0.5 do
			local a = (os.clock() - t0) / 0.5
			label.Text = tostring(math.floor(n * (1 - (1 - a) ^ 3)))
			task.wait()
		end
		label.Text = tostring(value)
	end)
end

local renderToken = 0

local function render(tab: string)
	local body = refs.body
	renderToken += 1
	local my = renderToken
	-- старые таблички уходят в камень
	for _, c in ipairs(body:GetChildren()) do
		if c:IsA("GuiObject") and refs.shown then
			c.Name = "Leaving"
			UiMotion.fadeOut(c, 0.12)
			UiMotion.tween(c, 0.12, { Position = c.Position + UDim2.fromOffset(0, 12) })
			task.delay(0.13, function()
				c:Destroy()
			end)
		else
			c:Destroy()
		end
	end
	if refs.shown then
		task.wait(0.12)
		if my ~= renderToken or not body.Parent then
			return
		end
	end
	refs.shown = true
	local data = ctx.api.wall.get(tab)
	if not data then
		PixelUi.label(body, "Стена молчит…", 24, C.grey, { Position = UDim2.fromOffset(0, 300), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center })
		return
	end
	for i, row in ipairs(data.rows) do
		if i > 7 then
			break
		end
		local top = i <= 3
		local candle, flame, medalIcon
		local y = (i - 1) * 72
		local plate = Instance.new("Frame")
		plate.BorderSizePixel = 0
		plate.BackgroundColor3 = top and Color3.fromRGB(150, 156, 168) or Color3.fromRGB(118, 124, 136)
		plate.Position = UDim2.fromOffset(32, y)
		plate.Size = UDim2.new(1, -64, 0, 60)
		plate.ZIndex = 4
		plate.Parent = body
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190))
		g.Parent = plate
		local s = Instance.new("UIStroke")
		s.Color = top and MEDAL[i] or Color3.fromRGB(26, 16, 10)
		s.Thickness = top and 3 or 2
		s.Parent = plate
		local ink = top and Color3.fromRGB(34, 30, 30) or Color3.fromRGB(232, 236, 244)
		local make = top and PixelUi.text or PixelUi.label
		if top then
			local medal = PixelUi.piece(plate, "medal", { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(44, 44), ImageColor3 = MEDAL[i], ZIndex = 5 })
			PixelUi.text(medal, tostring(i), 16, MEDAL[i], { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
			candle = PixelUi.icon(body, "candle", UDim2.fromOffset(-12, y + 10), 40, { ZIndex = 6 })
			flame = PixelUi.glow(body, UDim2.fromOffset(8, y + 12), UDim2.fromOffset(80, 80), C.mem, 0.5)
			medalIcon = medal
		else
			make(plate, tostring(i), 16, ink, { Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(44, 60), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
		end
		make(plate, row.name, 16, ink, { Position = UDim2.fromOffset(76, 0), Size = UDim2.fromOffset(500, 60), ZIndex = 5 })
		make(plate, "Этаж " .. tostring(row.floor), 16, top and Color3.fromRGB(60, 60, 70) or Color3.fromRGB(200, 206, 216), {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -224, 0, 0), Size = UDim2.fromOffset(200, 60), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 })
		PixelUi.icon(plate, "soul", UDim2.new(1, -196, 0, 10), 40, { ZIndex = 5 })
		local valueLabel = PixelUi.label(plate, tostring(row.value), 16, C.mem, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 0), Size = UDim2.fromOffset(140, 60), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 })
		-- снизу вверх: сначала 7-й, тройка «высекается» последней
		local count = math.min(#data.rows, 7)
		local delay = 0.06 + (count - i) * 0.07 + (top and 0.12 * (4 - i) or 0)
		UiMotion.cascade({ plate }, Vector2.new(0, 18), 0, delay, 0.26)
		countUp(valueLabel, row.value, delay + 0.1)
		task.delay(delay, function()
			if not plate.Parent then
				return
			end
			if top then
				UiSound.play("stone_slab", { pitch = 1.1 - i * 0.05, gap = 0 })
				UiSound.play("medal", { pitch = 1.15 - i * 0.08, gap = 0 })
				UiMotion.punch(plate, 0.05, 0.25)
			else
				UiSound.play("stone_tick", { pitch = 0.9 + i * 0.04, gap = 0 })
			end
		end)
		if top then
			if medalIcon then
				UiMotion.popIn(medalIcon, delay + 0.12, 0.2)
			end
			-- свеча зажигается вместе с табличкой и потом мерцает
			if candle then
				UiMotion.popIn(candle, delay + 0.18, 0.3)
			end
			if flame then
				flame.ImageTransparency = 1
				task.delay(delay + 0.2, function()
					if flame.Parent then
						UiSound.play("candle", { gap = 0 })
						UiMotion.tween(flame, 0.3, { ImageTransparency = 0.5 })
						task.wait(0.3)
						if flame.Parent then
							UiMotion.breathe(flame, "ImageTransparency", 0.45, 0.72, 0.6 + math.random() * 0.4)
						end
					end
				end)
			end
		end
	end
	if data.me then
		local me = data.me
		local y = 7 * 72 + 16
		PixelUi.glow(body, UDim2.new(0.5, 0, 0, y + 30), UDim2.new(1, -20, 0, 100), C.mem, 0.6)
		local card = PixelUi.parch(body, UDim2.fromOffset(32, y), UDim2.new(1, -64, 0, 60), { clean = true })
		UiMotion.popIn(card, 0.85, 0.85)
		task.delay(0.85, function()
			if card.Parent then
				UiSound.play("paper_slide", { gap = 0 })
			end
		end)
		PixelUi.text(card, tostring(me.rank), 16, C.ink, { Position = UDim2.fromOffset(24, 0), Size = UDim2.fromOffset(80, 60), ZIndex = 5 })
		PixelUi.text(card, "Ты: " .. me.name, 16, C.ink, { Position = UDim2.fromOffset(100, 0), Size = UDim2.fromOffset(420, 60), ZIndex = 5 })
		PixelUi.text(card, ("Этаж %s%s"):format(tostring(me.floor), me.hint and (" · " .. me.hint) or ""), 16, Color3.fromRGB(30, 110, 140), {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 0), Size = UDim2.fromOffset(460, 60), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 })
	end
end

function WallWindow.open(context)
	ctx = context
	refs = {}
	win = WindowBase.new("KlinokWall", { title = "Стена забытых имён", sub = "«Имена тех, кто ушёл за хребет»", onClose = context.close, wallet = false })
	local plate = slab(win.canvas)
	PixelUi.slideIn(plate, 0, 0)
	refs.tabs = {}
	for i, tab in ipairs(TABS) do
		refs.tabs[i] = PixelUi.button(plate, i == 1 and "gold" or "off", UDim2.fromOffset(36 + (i - 1) * 324, 20), UDim2.fromOffset(304, 48), tab[2], function()
			if refs.tab == tab[1] then
				return
			end
			refs.tab = tab[1]
			UiSound.play("stone_slab", { pitch = 1.3, volume = 0.7 })
			for k, b in ipairs(refs.tabs) do
				b:setKind(k == i and "gold" or "off")
			end
			task.spawn(render, tab[1])
		end)
	end
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 88)
	body.Size = UDim2.new(1, 0, 1, -100)
	body.ZIndex = 4
	body.Parent = plate
	refs.body = body
	refs.tab = "deep"
	UiSound.play("stone_slab", { pitch = 0.85 })
	render("deep")
	return win
end

function WallWindow.close()
	if win then
		win:destroy()
		win = nil
	end
end

return WallWindow
