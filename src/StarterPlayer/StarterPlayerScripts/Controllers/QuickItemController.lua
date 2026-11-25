--!nonstrict
-- QuickItemController — быстрый предмет на HUD и бумажные тосты находок.
-- Слот 64 справа от панели способностей: иконка припаса из быстрого слота,
-- количество, клавиша [G], затемнение отката группы (атрибут
-- ItemCooldown_<group> — серверное время конца отката).
-- Клик или клавиша → StationApi.character.useQuick().
-- Справа — листки «+2 Хлеб» на событие BagChanged (InventoryService).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Binds = require(Shared.Config.Binds)
local UiNet = require(Shared.Net.UiNet)

local Lib = script.Parent.Parent.Lib
local Bus = require(Lib.Bus)
local PixelUi = require(Lib.PixelUi)
local PaperUi = require(Lib.PaperUi)
local StationApi = require(Lib.StationApi)
local UiSound = require(Lib.UiSound)
local TouchControls = require(script.Parent.TouchControls)

local QuickItemController = {}

local P = PaperUi.colors
local player = Players.LocalPlayer
local ui: any = {}
local busy = false

local REASONS = {
	full = "Здоровье полное",
	cooldown = "Откат",
	["charges-full"] = "Заряды полны",
	empty = "Пусто",
	["no-quick"] = "Слот пуст [I]",
	dead = "Нельзя",
}

local function keyName(): string
	local binding = Binds.get("UseItem")
	if typeof(binding) == "EnumItem" and binding.EnumType == Enum.KeyCode then
		return binding.Name
	end
	return "G"
end

local function quickGroup(): string?
	local item = Items.List[player:GetAttribute("QuickItem") or ""]
	return item and item.group or nil
end

local function cooldownLeft(): (number, number)
	local group = quickGroup()
	if not group then
		return 0, 1
	end
	local ends = player:GetAttribute("ItemCooldown_" .. group)
	local total = Items.Cooldowns[group] or 1
	if type(ends) ~= "number" then
		return 0, total
	end
	return math.max(0, ends - workspace:GetServerTimeNow()), total
end

local function hint(text: string, color: Color3?)
	if not ui.slot then
		return
	end
	if ui.hint then
		ui.hint:Destroy()
	end
	local label = PaperUi.bold(ui.holder, text, 18, color or P.paper, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(220, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		TextStrokeColor3 = P.woodDark,
		ZIndex = 20,
	})
	ui.hint = label
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {
		Position = UDim2.new(0.5, 0, 0, -40),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1, function()
		if label.Parent then
			label:Destroy()
		end
	end)
end

local function refresh()
	if not ui.holder then
		return
	end
	if ui.icon then
		ui.icon:Destroy()
		ui.icon = nil
	end
	local id = player:GetAttribute("QuickItem") or ""
	local count = player:GetAttribute("QuickItemCount") or 0
	local icon = player:GetAttribute("QuickItemIcon") or ""
	if id ~= "" and icon ~= "" then
		ui.icon = PaperUi.itemIcon(ui.holder, icon, UDim2.fromScale(0.5, 0.46), 48, { ZIndex = 9 })
		ui.icon.ImageTransparency = count > 0 and 0 or 0.6
	else
		ui.icon = PaperUi.itemIcon(ui.holder, "it_potionRed", UDim2.fromScale(0.5, 0.46), 48, { ZIndex = 9, ImageTransparency = 0.7 })
	end
	ui.count.Text = count > 1 and ("×" .. count) or (count == 1 and "" or (id ~= "" and "0" or ""))
end

local function use()
	if busy then
		return
	end
	if (player:GetAttribute("QuickItem") or "") == "" then
		UiSound.play("error")
		hint(REASONS["no-quick"])
		return
	end
	busy = true
	local result = StationApi.character.useQuick()
	busy = false
	if result and result.ok then
		UiSound.play("reward_pop", { volume = 0.6 })
		PixelUi.pop(ui.holder)
		hint(result.text or "", Color3.fromRGB(170, 240, 170))
	else
		UiSound.play("error")
		PixelUi.nudge(ui.holder)
		hint(REASONS[result and result.reason or ""] or "Не вышло")
	end
end

local function build(root)
	-- Ряд способностей PixelHud v3: [1] оружия (24, низ -72), предмет [G] за ним, [3] класса правее.
	local holder = Instance.new("Frame")
	holder.Name = "QuickItem"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.new(0, 24 + 76, 1, -72) -- v3: сразу за способностью оружия [1]
	holder.Size = UDim2.fromOffset(64, 64)
	holder.Parent = root
	ui.holder = holder
	local slot = PaperUi.slot(holder, UDim2.new(), 64, { z = 6 })
	ui.slot = slot
	-- затемнение отката: сверху вниз
	local shade = Instance.new("Frame")
	shade.Name = "Cooldown"
	shade.BorderSizePixel = 0
	shade.BackgroundColor3 = Color3.fromRGB(30, 22, 16)
	shade.BackgroundTransparency = 0.45
	shade.AnchorPoint = Vector2.new(0, 1)
	shade.Position = UDim2.new(0, 4, 1, -4)
	shade.Size = UDim2.new(1, -8, 0, 0)
	shade.ZIndex = 12
	shade.Parent = holder
	ui.shade = shade
	ui.timer = PaperUi.bold(holder, "", 20, P.paper, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		ZIndex = 13,
	})
	ui.count = PaperUi.bold(holder, "", 15, P.green, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -5, 1, -4),
		Size = UDim2.fromOffset(50, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 14,
	})
	-- табличка клавиши
	local key = PaperUi.image(holder, "plateB", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(28, 22),
		ZIndex = 15,
	}, { scale = 1 })
	PaperUi.bold(key, keyName(), 15, P.ink, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 16,
	})
	local hit = PaperUi.hit(holder, 18)
	hit.Activated:Connect(use)
	refresh()
end

-- ===== тосты находок =====

local toasts = {}

local function layoutToasts()
	for i, t in ipairs(toasts) do
		PixelUi.tween(t, 0.18, { Position = UDim2.new(1, -24, 0, 220 + (i - 1) * 62) })
	end
end

local function toast(entry)
	if not ui.toasts then
		return
	end
	local frame = PaperUi.sheet(ui.toasts, UDim2.new(1, 300, 0, 220 + #toasts * 62), UDim2.fromOffset(280, 54), {
		kind = "sheetPlain", back = false, z = 4, scale = 0.5,
	})
	frame.AnchorPoint = Vector2.new(1, 0)
	if entry.icon and entry.icon ~= "" then
		PaperUi.itemIcon(frame, entry.icon, UDim2.fromOffset(30, 27), 32, { ZIndex = 7 })
	end
	local color = PaperUi.rarityInk[entry.rarityId or "common"] or P.ink
	local text = (entry.count and entry.count > 1) and ("+%d %s"):format(entry.count, entry.name or "") or ("+ " .. (entry.name or ""))
	if entry.accessory then
		text ..= entry.equipped and " · надето" or ""
	end
	PaperUi.bold(frame, text, 18, color, {
		Position = UDim2.fromOffset(56, 0), Size = UDim2.new(1, -66, 1, -2),
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7,
	})
	table.insert(toasts, 1, frame)
	while #toasts > 5 do
		table.remove(toasts):Destroy()
	end
	layoutToasts()
	task.delay(3.2, function()
		local index = table.find(toasts, frame)
		if not index then
			return
		end
		PixelUi.tween(frame, 0.25, { Position = frame.Position + UDim2.fromOffset(320, 0) })
		task.wait(0.26)
		index = table.find(toasts, frame)
		if index then
			table.remove(toasts, index)
		end
		frame:Destroy()
		layoutToasts()
	end)
end

local function onBagChanged(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.added then
		for i, entry in ipairs(payload.added) do
			task.delay((i - 1) * 0.12, toast, entry)
		end
		UiSound.play("reward_pop", { volume = 0.4, pitch = 1.15 })
	end
	refresh()
end

function QuickItemController.start()
	local gui, root = PixelUi.screen("KlinokQuickItem", 6)
	ui.gui = gui
	build(root)
	local toastLayer = Instance.new("Frame")
	toastLayer.Name = "Toasts"
	toastLayer.BackgroundTransparency = 1
	toastLayer.Size = UDim2.fromScale(1, 1)
	toastLayer.Parent = root
	ui.toasts = toastLayer

	for _, attr in ipairs({ "QuickItem", "QuickItemCount", "QuickItemIcon" }) do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	ContextActionService:BindAction("KlinokUseItem", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			task.spawn(use)
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(Binds.all("UseItem")))
	-- Телефон: раньше быстрый предмет применялся только клавишей — теперь есть
	-- кнопка «ПРЕДМ» в кластере TouchControls (видна, когда предмет назначен).
	TouchControls.bind("KlinokUseItem", {
		slot = "item",
		label = "ПРЕДМ",
		handler = function(inputState)
			if inputState == Enum.UserInputState.Begin then
				task.spawn(use)
			end
		end,
		visible = function()
			local id = player:GetAttribute("QuickItem")
			return id ~= nil and id ~= ""
		end,
		count = function()
			return player:GetAttribute("QuickItemCount")
		end,
		cooldown = cooldownLeft,
	})

	Bus.on("hud", function(data)
		gui.Enabled = data.visible ~= false
	end)

	RunService.Heartbeat:Connect(function()
		if not ui.shade then
			return
		end
		local left, total = cooldownLeft()
		if left > 0 then
			ui.shade.Size = UDim2.new(1, -8, math.clamp(left / total, 0, 1), -8 * math.clamp(left / total, 0, 1))
			ui.timer.Text = left >= 1 and tostring(math.ceil(left)) or ""
		elseif ui.timer.Text ~= "" or ui.shade.Size.Y.Scale > 0 then
			ui.shade.Size = UDim2.new(1, -8, 0, 0)
			ui.timer.Text = ""
		end
	end)

	task.spawn(function()
		local remote
		for _ = 1, 40 do
			remote = UiNet.find("BagChanged")
			if remote then
				break
			end
			task.wait(0.5)
		end
		if remote then
			remote.OnClientEvent:Connect(onBagChanged)
		end
	end)
end

return QuickItemController