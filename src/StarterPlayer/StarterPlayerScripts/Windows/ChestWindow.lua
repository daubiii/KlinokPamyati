--!nonstrict
-- ChestWindow — Сундук дня. Слева серия и таймер, справа награда сегодня и
-- кнопка, снизу 7 карточек дней (7-й — Великий дар). При открытии в 3D
-- поднимается крышка (группа Lid вокруг маркера LidHinge), столб света,
-- карточки наград выпрыгивают, монеты летят в кошелёк, камень серии загорается.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiAssets = require(Shared.Config.UiAssets)

local Lib = script.Parent.Parent.Lib
local PixelUi = require(Lib.PixelUi)
local UiFx = require(Lib.UiFx)
local UiMotion = require(Lib.UiMotion)
local UiSound = require(Lib.UiSound)
local WindowBase = require(Lib.WindowBase)

local ChestWindow = {}

local C = UiAssets.Colors
local win, ctx
local refs: any = {}
local lid -- состояние крышки в 3D

local function fmtTime(sec: number): string
	sec = math.max(0, math.floor(sec))
	return ("%02d:%02d:%02d"):format(sec // 3600, (sec % 3600) // 60, sec % 60)
end

-- ===== 3D: крышка и камни =====
local function prepareChest(model)
	if not model then
		return nil
	end
	local hinge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Attachment") and d.Name == "LidHinge" then
			hinge = d.WorldCFrame
		end
	end
	if not hinge then
		return nil
	end
	local parts, rel = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "Lid" or d.Name == "LidGem") then
			table.insert(parts, d)
			rel[d] = hinge:ToObjectSpace(d.CFrame)
		end
	end
	return { hinge = hinge, parts = parts, rel = rel, angle = 0 }
end

local function setLid(angle: number)
	if not lid then
		return
	end
	lid.angle = angle
	local cfs = {}
	local rot = lid.hinge * CFrame.Angles(math.rad(angle), 0, 0)
	for i, p in ipairs(lid.parts) do
		cfs[i] = rot * lid.rel[p]
	end
	Workspace:BulkMoveTo(lid.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

local function animateLid(to: number, time: number)
	if not lid then
		return
	end
	local from = lid.angle
	local started = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - started) / time, 0, 1)
		-- открытие с отскоком
		local e = to > from and (1 - (1 - t) ^ 3 + math.sin(t * math.pi) * 0.12) or t * t
		setLid(from + (to - from) * math.min(e, 1.08))
		if t >= 1 then
			conn:Disconnect()
			setLid(to)
		end
	end)
end

local function paintStones(model, streak: number, claimed: boolean)
	if not model then
		return
	end
	for i = 1, 7 do
		local glow = model:FindFirstChild(("Streak%dGlow"):format(i), true)
		if glow and glow:IsA("BasePart") then
			local done = i < streak or (claimed and i == streak)
			local today = i == streak and not claimed
			glow.Material = (done or today) and Enum.Material.Neon or Enum.Material.SmoothPlastic
			glow.Color = done and Color3.fromRGB(242, 190, 69) or (today and Color3.fromRGB(111, 227, 255) or Color3.fromRGB(96, 101, 110))
		end
	end
end

-- ===== карточки дней =====
local function dayCards(data, claimedNow: boolean)
	local holder = refs.days
	for _, c in ipairs(holder:GetChildren()) do
		c:Destroy()
	end
	local w, gap = 180, 16
	local x0 = (1600 - (7 * w + 6 * gap)) / 2
	refs.cards = {}
	for i, day in ipairs(data.days) do
		local claimed = data.claimedToday or claimedNow
		local done = i < data.streak or (claimed and i == data.streak)
		local today = i == data.streak and not claimed
		local big = i == 7
		local x = x0 + (i - 1) * (w + gap)
		local y = big and -20 or 0
		local card
		if done then
			card = PixelUi.parch(holder, UDim2.fromOffset(x, y), UDim2.fromOffset(w, 200 - y))
		else
			card = PixelUi.panel(holder, UDim2.fromOffset(x, y), UDim2.fromOffset(w, 200 - y), { corners = false })
		end
		if today then
			PixelUi.glow(card, UDim2.fromScale(0.5, 0.5), UDim2.new(1, 70, 1, 70), C.mem, 0.45)
			PixelUi.piece(card, "slotSelect", { Position = UDim2.fromOffset(-4, -4), Size = UDim2.new(1, 8, 1, 8), ImageColor3 = C.mem, ZIndex = 9 })
		elseif big then
			PixelUi.glow(card, UDim2.fromScale(0.5, 0.5), UDim2.new(1, 60, 1, 60), C.red, 0.55)
			PixelUi.piece(card, "slotSelect", { Position = UDim2.fromOffset(-4, -4), Size = UDim2.new(1, 8, 1, 8), ImageColor3 = Color3.fromRGB(255, 120, 110), ZIndex = 9 })
		end
		local titleColor = done and C.ink or (today and C.gold or (big and Color3.fromRGB(255, 150, 140) or C.grey))
		local make = done and PixelUi.text or PixelUi.label
		make(card, "День " .. i, 16, titleColor, { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8 })
		local icon = PixelUi.icon(card, day.icon, UDim2.new(0.5, -40, 0, 54), 80, { ZIndex = 8 })
		if not (done or today or big) then
			icon.ImageTransparency = 0.55
		end
		make(card, day.text, 16, done and C.ink or ((today or big) and C.bone or C.grey), {
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -16), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8 })
		if done then
			local seal = PixelUi.piece(card, "seal", { Position = UDim2.new(1, -52, 0, 38), Size = UDim2.fromOffset(44, 44), ZIndex = 9 })
			PixelUi.piece(seal, "check", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), ZIndex = 10 })
			if claimedNow and i == data.streak then
				-- печать прихлопывается на сегодняшний день
				UiMotion.popIn(seal, 0.1, 2.2)
				task.delay(0.16, function()
					if seal.Parent then
						UiSound.play("stamp", { gap = 0 })
						UiMotion.punch(card, 0.06, 0.25)
					end
				end)
			end
		end
		if today or big then
			-- сегодняшний день и Великий дар зовут: иконка покачивается
			UiMotion.bob(icon, 3, today and 0.8 or 1.2)
		end
		if not claimedNow then
			UiMotion.cascade({ card }, Vector2.new(0, 40), 0, 0.2 + i * 0.05, 0.3)
			task.delay(0.2 + i * 0.05, function()
				if card.Parent then
					UiSound.play("list_tick", { pitch = 0.85 + i * 0.07, volume = 0.6, gap = 0 })
				end
			end)
		end
		refs.cards[i] = card
	end
end

-- ===== панели =====
local function build(data)
	local canvas = win.canvas
	-- слева: серия
	local left = PixelUi.panel(canvas, UDim2.fromOffset(24, 148), UDim2.fromOffset(368, 452), { title = "Серия" })
	refs.left = left
	refs.streakLabel = PixelUi.label(left, ("%d %s"):format(data.streak, data.streak == 1 and "день" or (data.streak < 5 and "дня" or "дней")), 40, C.gold, {
		Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 48), TextXAlignment = Enum.TextXAlignment.Center })
	PixelUi.stars(left, UDim2.new(0.5, -(7 * 30) / 2, 0, 136), data.streak - (data.claimedToday and 0 or 1), 7, 24)
	local lines = { { "Заходи каждый", C.bone }, { "день. На 7-й", C.bone }, { "ждёт Великий", Color3.fromRGB(255, 150, 140) }, { "дар!", Color3.fromRGB(255, 150, 140) } }
	for i, l in ipairs(lines) do
		PixelUi.label(left, l[1], 16, l[2], { Position = UDim2.fromOffset(28, 184 + (i - 1) * 32), Size = UDim2.fromOffset(320, 24) })
	end
	local timerBox = Instance.new("Frame")
	timerBox.BorderSizePixel = 0
	timerBox.BackgroundColor3 = Color3.fromRGB(24, 18, 15)
	timerBox.Position = UDim2.fromOffset(20, 352)
	timerBox.Size = UDim2.new(1, -40, 0, 76)
	timerBox.ZIndex = 5
	timerBox.Parent = left
	PixelUi.label(timerBox, data.claimedToday and "Следующий дар" or "Серия сгорит", 16, C.grey, { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
	refs.timer = PixelUi.label(timerBox, "", 16, Color3.fromRGB(255, 190, 120), { Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
	PixelUi.slideIn(left, -1, 0.05)

	-- справа: сегодня
	local right = PixelUi.panel(canvas, UDim2.fromOffset(1208, 148), UDim2.fromOffset(368, 452), { title = "Сегодня" })
	refs.right = right
	local card = PixelUi.parch(right, UDim2.fromOffset(28, 60), UDim2.new(1, -56, 0, 184))
	PixelUi.icon(card, data.today.icon, UDim2.new(0.5, -40, 0, 18), 80, { ZIndex = 5 })
	PixelUi.text(card, data.today.text, 16, C.ink, { Position = UDim2.fromOffset(0, 114), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
	if data.today.extra then
		PixelUi.text(card, data.today.extra, 16, Color3.fromRGB(40, 120, 150), { Position = UDim2.fromOffset(0, 146), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
	end
	if data.tomorrow then
		PixelUi.label(right, "Завтра:", 16, C.grey, { Position = UDim2.fromOffset(0, 262), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center })
		PixelUi.icon(right, data.tomorrow.icon, UDim2.fromOffset(80, 290), 40)
		PixelUi.label(right, data.tomorrow.text, 16, C.bone, { Position = UDim2.fromOffset(130, 298), Size = UDim2.fromOffset(220, 24) })
	end
	refs.button = PixelUi.button(right, data.claimedToday and "off" or "gold", UDim2.fromOffset(24, 354), UDim2.new(1, -48, 0, 72),
		data.claimedToday and "ЗАВТРА" or "ОТКРЫТЬ", function()
			ChestWindow.claim()
		end, { textSize = 32, glow = not data.claimedToday, enabled = not data.claimedToday })
	PixelUi.slideIn(right, 1, 0.1)
	if not data.claimedToday then
		-- кнопка «ОТКРЫТЬ» дышит и время от времени подпрыгивает
		if refs.button.glow then
			UiMotion.breathe(refs.button.glow, "ImageTransparency", 0.4, 0.75, 0.8)
		end
		task.spawn(function()
			local my = win
			task.wait(1.2)
			while my.alive and not refs.busy and refs.data and not refs.data.claimedToday do
				UiMotion.punch(refs.button.holder, 0.05, 0.25)
				task.wait(2.6)
			end
		end)
	end

	-- низ: дни
	local days = Instance.new("Frame")
	days.BackgroundTransparency = 1
	days.Position = UDim2.fromOffset(0, 664)
	days.Size = UDim2.fromOffset(1600, 200)
	days.Parent = canvas
	refs.days = days
	dayCards(data, false)

end

function ChestWindow.claim()
	if refs.busy or not refs.data or refs.data.claimedToday then
		return
	end
	refs.busy = true
	refs.button:setEnabled(false)
	local result = ctx.api.chest.claim()
	if not result or not result.ok then
		UiSound.play("error")
		refs.busy = false
		refs.button:setEnabled(true)
		return
	end
	-- 0) предвкушение: крышка дважды подпрыгивает, сундук «дребезжит»
	UiSound.play("confirm")
	UiMotion.punch(refs.button.holder, 0.12, 0.25)
	for _, a in ipairs({ 9, 0, 14, 0 }) do
		if a > 0 then
			UiSound.play("stone_tick", { pitch = 1.3, gap = 0 })
		end
		animateLid(a, 0.12)
		task.wait(0.13)
	end
	-- 1) крышка и свет
	UiSound.play("chest_open")
	animateLid(110, 0.7)
	if lid then
		local glow = Instance.new("Part")
		glow.Name = "InnerGlow"
		glow.Anchored = true
		glow.CanCollide = false
		glow.CanQuery = false
		glow.Material = Enum.Material.Neon
		glow.Color = Color3.fromRGB(255, 216, 106)
		glow.Size = Vector3.new(5, 0.3, 3)
		glow.CFrame = lid.hinge * CFrame.new(0, -0.3, -1.8)
		glow.Parent = Workspace
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 120)
		light.Range = 22
		light.Brightness = 3
		light.Parent = glow
		lid.glow = glow
	end
	task.wait(0.55)
	UiFx.flash(C.gold, 0.6, 0.5)
	UiFx.shake(0.3, 0.2)
	local chestPoint = win:canvasToRoot(Vector2.new(800, 300))
	if ctx.scene then
		local p = win:toRoot(ctx.scene:GetPivot().Position + Vector3.new(0, 6, 0))
		chestPoint = p or chestPoint
	end
	UiFx.burst(win.root, chestPoint, { C.gold, Color3.fromRGB(255, 246, 200), C.mem }, 50, 260)
	refs.left.Visible = false
	refs.right.Visible = false

	-- 2) баннер и карточки наград
	local overlay = Instance.new("Frame")
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 30
	overlay.Parent = win.canvas
	local rays = PixelUi.glow(overlay, UDim2.fromOffset(800, 260), UDim2.fromOffset(700, 520), C.gold, 0.55)
	rays.ZIndex = 29
	UiMotion.popIn(rays, 0, 0.3)
	task.delay(0.3, function()
		if rays.Parent then
			UiMotion.breathe(rays, "ImageTransparency", 0.45, 0.7, 1.1)
		end
	end)
	local ribbon = PixelUi.ribbon(overlay, "gold", UDim2.fromOffset(800, 82), UDim2.fromOffset(760, 104), 31)
	PixelUi.pop(ribbon)
	PixelUi.text(ribbon, "ДАР ПОЛУЧЕН!", 40, Color3.fromRGB(70, 40, 10), { Size = UDim2.new(1, 0, 1, -4), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 33 })
	local rewards = result.rewards or {}
	local cw, gap = 228, 72
	local x0 = 800 - (#rewards * cw + (#rewards - 1) * gap) / 2
	for i, r in ipairs(rewards) do
		task.delay(0.25 + (i - 1) * 0.3, function()
			local card = PixelUi.parch(overlay, UDim2.fromOffset(x0 + (i - 1) * (cw + gap), 392), UDim2.fromOffset(cw, 180))
			local glow = PixelUi.glow(card, UDim2.fromScale(0.5, 0.5), UDim2.new(1, 80, 1, 80), r.kind == "mem" and C.mem or C.gold, 0.4)
			glow.ZIndex = 2
			PixelUi.icon(card, r.icon, UDim2.new(0.5, -40, 0, 16), 80, { ZIndex = 5 })
			PixelUi.text(card, r.big or "", 24, C.ink, { Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
			PixelUi.text(card, r.small or "", 16, r.kind == "mem" and Color3.fromRGB(40, 120, 150) or C.ink2, {
				Position = UDim2.fromOffset(0, 142), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
			-- карточка вылетает из сундука и встаёт на место
			UiMotion.cascade({ card }, Vector2.new(0, -150), 0, 0, 0.36)
			PixelUi.pop(card)
			UiSound.play("reward_pop", { pitch = 1 + i * 0.06 })
			UiSound.play("star_on", { pitch = 0.95 + i * 0.08, volume = 0.6, gap = 0 })
			if glow then
				UiMotion.breathe(glow, "ImageTransparency", 0.3, 0.6, 0.9)
			end
			if r.icon == "coin" then
				-- монеты летят в кошелёк
				UiSound.play("coins")
				local scale = win.root:FindFirstChildOfClass("UIScale")
				local s = scale and scale.Scale or 1
				local from = (card.AbsolutePosition + card.AbsoluteSize / 2) / s
				local to = Vector2.new(win.root.AbsoluteSize.X / s - 260, 44)
				for k = 1, 6 do
					task.delay(k * 0.07, function()
						UiFx.flyIcon(win.root, "coin", from, to, 0.6, k == 6 and win.refreshWallet or nil)
					end)
				end
			end
		end)
	end

	-- 3) серия: карточка дня получает печать, камень загорается
	task.delay(1.0, function()
		refs.data.claimedToday = true
		dayCards(refs.data, true)
		paintStones(ctx.scene, refs.data.streak, true)
		UiSound.play("streak_stone")
		local card = refs.cards[refs.data.streak]
		if card then
			PixelUi.pop(card)
		end
	end)
	local take = PixelUi.button(overlay, "gold", UDim2.fromOffset(660, 596), UDim2.fromOffset(280, 56), "ЗАБРАТЬ", function()
		ctx.close()
	end, { textSize = 24, glow = true })
	PixelUi.pop(take.holder, 0.9)
	task.delay(0.9, function()
		if take.glow then
			UiMotion.breathe(take.glow, "ImageTransparency", 0.4, 0.75, 0.8)
		end
	end)
end

function ChestWindow.open(context)
	ctx = context
	refs = {}
	win = WindowBase.new("KlinokChest", { title = "Сундук дня", sub = "Дар деревни путнику", onClose = context.close })
	lid = prepareChest(context.scene)
	local data = context.api.chest.get()
	if not data then
		PixelUi.label(win.canvas, "Сундук пока недоступен", 24, C.grey, { Position = UDim2.fromOffset(0, 420), Size = UDim2.fromOffset(1600, 30), TextXAlignment = Enum.TextXAlignment.Center })
		return win
	end
	refs.data = data
	build(data)
	paintStones(context.scene, data.streak, data.claimedToday)
	local opened = os.clock()
	task.spawn(function()
		local my = win
		while my.alive do
			if refs.timer then
				refs.timer.Text = "через " .. fmtTime((data.resetIn or 0) - (os.clock() - opened))
			end
			task.wait(1)
		end
	end)
	return win
end

function ChestWindow.close()
	if lid and lid.angle > 1 then
		animateLid(0, 0.4)
	end
	if lid and lid.glow then
		lid.glow:Destroy()
		lid.glow = nil
	end
	if win then
		win:destroy()
		win = nil
	end
end

return ChestWindow
