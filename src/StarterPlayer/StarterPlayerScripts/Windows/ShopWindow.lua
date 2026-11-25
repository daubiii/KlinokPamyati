--!nonstrict
-- ShopWindow — Лавка Осколков. Товары стоят в 3D на витринах перед прилавком
-- (маркеры Display1..Display4 в модели ShopDisplay); под каждой — ценник с
-- кнопкой «КУПИТЬ». Реплика Ивги, таймер нового товара. Пустые места — «скоро».

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiAssets = require(Shared.Config.UiAssets)
local HubDialogue = require(Shared.Config.HubDialogue)

local Lib = script.Parent.Parent.Lib
local PixelUi = require(Lib.PixelUi)
local UiFx = require(Lib.UiFx)
local UiMotion = require(Lib.UiMotion)
local UiSound = require(Lib.UiSound)
local WindowBase = require(Lib.WindowBase)

local ShopWindow = {}

local C = UiAssets.Colors
local win, ctx
local refs: any = {}
local FALLBACK_X = { 224, 562, 912, 1262 }

local function fmtTime(sec: number): string
	sec = math.max(0, math.floor(sec))
	return ("%02d:%02d:%02d"):format(sec // 3600, (sec % 3600) // 60, sec % 60)
end

-- Где на экране витрина i (в координатах холста).
local function displayX(i: number): number
	local display = Workspace:FindFirstChild("ShopDisplay", true)
	if display then
		for _, d in ipairs(display:GetDescendants()) do
			if d:IsA("Attachment") and d.Name == "Display" .. i then
				local p = win:toRoot(d.WorldPosition)
				if p then
					local offset = win:canvasToRoot(Vector2.zero)
					return p.X - offset.X
				end
			end
		end
	end
	return FALLBACK_X[i]
end

local function tag(i: number, item)
	local cx = displayX(i)
	local y = 668
	local rc = item and UiAssets.Rarity[item.rarity] or C.grey
	local card = PixelUi.parch(win.canvas, UDim2.fromOffset(cx - 140, y), UDim2.fromOffset(280, 176), { clean = true })
	-- верёвочки к витрине
	for _, dx in ipairs({ 60, 220 }) do
		local rope = Instance.new("Frame")
		rope.BorderSizePixel = 0
		rope.BackgroundColor3 = Color3.fromRGB(60, 44, 30)
		rope.Position = UDim2.fromOffset(dx, -40)
		rope.Size = UDim2.fromOffset(3, 42)
		rope.ZIndex = 2
		rope.Parent = card
	end
	if not item then
		PixelUi.text(card, "скоро", 24, C.ink2, { Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
		PixelUi.slideIn(card, 0, 0.05 * i)
		return
	end
	refs.cards = refs.cards or {}
	refs.cards[i] = card
	PixelUi.glow(card, UDim2.fromScale(0.5, 0.5), UDim2.new(1, 50, 1, 50), rc, 0.7)
	local bar = Instance.new("Frame")
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = rc
	bar.Size = UDim2.new(1, 0, 0, 6)
	bar.ZIndex = 5
	bar.Parent = card
	PixelUi.text(card, item.name, 16, C.ink, { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
	PixelUi.text(card, UiAssets.RarityName[item.rarity] or "", 16, rc:Lerp(Color3.new(0, 0, 0), 0.3), { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
	PixelUi.icon(card, item.currency == "dust" and "dust" or "coin", UDim2.fromOffset(64, 78), 40, { ZIndex = 5 })
	PixelUi.text(card, tostring(item.price), 24, C.ink, { Position = UDim2.fromOffset(112, 82), Size = UDim2.fromOffset(140, 30), ZIndex = 5 })
	local buy = PixelUi.button(card, "gold", UDim2.fromOffset(28, 124), UDim2.new(1, -56, 0, 40), "КУПИТЬ", nil, { textSize = 16 })
	buy.hit.Activated:Connect(function()
		ShopWindow.buy(item, buy, card)
	end)
	-- ценник покачивается на верёвочках под курсором
	local hover = Instance.new("TextButton")
	hover.BackgroundTransparency = 1
	hover.Text = ""
	hover.Size = UDim2.fromScale(1, 1)
	hover.ZIndex = 4
	hover.Parent = card
	hover.MouseEnter:Connect(function()
		UiSound.play("choice_hover", { volume = 0.5 })
		UiMotion.tween(card, 0.18, { Rotation = (i % 2 == 0) and 2 or -2 }, Enum.EasingStyle.Back)
	end)
	hover.MouseLeave:Connect(function()
		UiMotion.tween(card, 0.3, { Rotation = 0 }, Enum.EasingStyle.Elastic)
	end)
	if item.tag then
		local flag = PixelUi.piece(card, "ribbonRed", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -20, 0, -6), Size = UDim2.fromOffset(120, 40), ZIndex = 8 })
		PixelUi.label(flag, item.tag, 16, Color3.fromRGB(255, 240, 230), { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
	end
	PixelUi.slideIn(card, 0, 0.05 * i)
	-- повис: короткое затухающее качание + шелест бумаги
	task.delay(0.05 * i + 0.3, function()
		if not card.Parent then
			return
		end
		UiSound.play("paper_slide", { pitch = 0.9 + i * 0.07, volume = 0.5, gap = 0 })
		local sign = (i % 2 == 0) and 1 or -1
		for _, r in ipairs({ 4, -3, 1.5, 0 }) do
			UiMotion.tween(card, 0.16, { Rotation = r * sign }, Enum.EasingStyle.Sine)
			task.wait(0.16)
		end
	end)
end

function ShopWindow.buy(item, button, card)
	local result = ctx.api.shop.buy(item.id)
	if result and result.ok then
		UiSound.play("coins")
		UiSound.play("reward_pop")
		UiSound.play("stamp", { volume = 0.7, gap = 0 })
		UiMotion.punch(card, 0.08, 0.25)
		-- печать «КУПЛЕНО» прихлопывается на ценник и тает
		local mark = Instance.new("Frame")
		mark.BackgroundTransparency = 1
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(0.5, 0.42)
		mark.Size = UDim2.fromOffset(190, 52)
		mark.Rotation = -12
		mark.ZIndex = 14
		mark.Parent = card
		local ms = Instance.new("UIStroke")
		ms.Color = Color3.fromRGB(190, 50, 40)
		ms.Thickness = 4
		ms.Parent = mark
		local mt = PixelUi.text(mark, "КУПЛЕНО", 24, Color3.fromRGB(190, 50, 40), { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 15 })
		UiMotion.popIn(mark, 0, 1.8)
		task.delay(1.3, function()
			if mark.Parent then
				UiMotion.tween(mt, 0.4, { TextTransparency = 1 })
				UiMotion.tween(ms, 0.4, { Transparency = 1 })
				task.delay(0.45, function()
					mark:Destroy()
				end)
			end
		end)
		local scale = win.root:FindFirstChildOfClass("UIScale")
		local s = scale and scale.Scale or 1
		local p = (card.AbsolutePosition + card.AbsoluteSize / 2) / s
		UiFx.burst(win.root, p, { UiAssets.Rarity[item.rarity] or C.gold, C.gold }, 30, 140)
		UiFx.floatText(win.root, result.reward and result.reward.text or item.name, p - Vector2.new(0, 120), UiAssets.Rarity[item.rarity] or C.gold, 24)
		if refs.bubble then
			refs.bubble:say("Хороший выбор. Он помнит больше, чем кажется.")
		end
		if win.refreshWallet then
			win.refreshWallet()
		end
	else
		UiSound.play("error")
		PixelUi.nudge(button.holder)
		UiMotion.tween(card, 0.08, { Rotation = 3 })
		task.delay(0.08, function()
			UiMotion.tween(card, 0.4, { Rotation = 0 }, Enum.EasingStyle.Elastic)
		end)
		if refs.bubble then
			refs.bubble:say(result and result.reason == "dust" and "Пыли маловато, милый." or "Золота не хватает, милый.")
		end
	end
end

function ShopWindow.open(context)
	ctx = context
	refs = {}
	win = WindowBase.new("KlinokShop", { title = "Лавка Осколков", onClose = context.close })
	local data = context.api.shop.get() or { items = {}, line = { "Лавка закрыта." } }
	refs.bubble = PixelUi.bubble(win.canvas, UDim2.fromOffset(24, 136), UDim2.fromOffset(576, 100), "ИВГА", "bottom")
	local ivga = HubDialogue.Ivga
	refs.bubble.voice = { pitch = ivga and ivga.voice and ivga.voice.pitch or 1, volume = 0.45 }
	PixelUi.slideIn(refs.bubble.holder, 2, 0.1)
	task.delay(0.35, function()
		if win and win.alive then
			refs.bubble:say(table.concat(data.line or {}, " "))
		end
	end)
	-- таймер нового товара
	local timer = PixelUi.panel(win.canvas, UDim2.fromOffset(1120, 124), UDim2.fromOffset(456, 80), { corners = false })
	PixelUi.label(timer, "Новый товар через", 16, C.grey, { Position = UDim2.fromOffset(24, 16), Size = UDim2.fromOffset(360, 22), ZIndex = 6 })
	local timeLabel = PixelUi.label(timer, "", 16, C.gold, { Position = UDim2.fromOffset(24, 44), Size = UDim2.fromOffset(200, 22), ZIndex = 6 })
	PixelUi.icon(timer, "lock", UDim2.new(1, -60, 0, 20), 40, { ZIndex = 6 })
	PixelUi.slideIn(timer, 1, 0)
	-- ценники ставим, когда камера долетела (позиции витрин берутся с экрана)
	task.delay(1.0, function()
		if win and win.alive then
			for i = 1, 4 do
				tag(i, data.items[i])
			end
		end
	end)
	local opened = os.clock()
	task.spawn(function()
		local my = win
		while my.alive do
			timeLabel.Text = data.restockIn and fmtTime(data.restockIn - (os.clock() - opened)) or "скоро"
			task.wait(1)
		end
	end)
	return win
end

function ShopWindow.close()
	if win then
		win:destroy()
		win = nil
	end
end

return ShopWindow
