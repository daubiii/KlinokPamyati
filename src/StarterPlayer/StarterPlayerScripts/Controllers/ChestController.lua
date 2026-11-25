--!nonstrict
-- ChestController (клиент)
-- Карточка находки после открытия сундука — по образцу карточек Pixel Blade:
-- рамка цвета редкости со свечением, вращающаяся 3D-модель оружия, «мощь»
-- крупными пиксельными цифрами и разница с оружием в руке (зелёным / красным),
-- способность, награда золотом и железом, кнопки «Надеть» и «В сумку».
-- Открывает сундук сервер (ProximityPrompt), клиент только показывает итог.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientState = require(Shared.Util.ClientState)
local Net = require(Shared.Net.Net)
local Palette = require(Shared.Config.Palette)
local Rarities = require(Shared.Config.Rarities)

local Bus = require(script.Parent.Parent.Lib.Bus)
local Ui = require(script.Parent.Parent.Lib.Ui)

local ChestController = {}

local ui: any = {}
local current = nil

local function close()
	if not current then
		return
	end
	current = nil
	ui.root.Visible = false
	ClientState.lockInput("ui", false)
	ClientState.lockInput("chest", false)
	ContextActionService:UnbindAction("KlinokChestClose")
	Bus.emit("chestClosed", {})
end

local function equip()
	if not current then
		return
	end
	local remote = Net.get("RequestEquip")
	local ok, response = pcall(function()
		return remote:InvokeServer(current.index)
	end)
	if ok and type(response) == "table" and response.ok then
		Bus.emit("notify", { kind = "campfire", text = "Оружие надето: " .. (current.name or "") })
		Bus.emit("sfx", { name = "ui" })
	end
	close()
end

local function show(payload)
	current = payload
	local color = Rarities.color(payload.rarityId)
	ui.stroke.Color = color
	ui.glow.BackgroundColor3 = color
	ui.viewBack.BackgroundColor3 = color:Lerp(Palette.UI.panel, 0.55)
	ui.name.Text = (payload.name or ""):upper()
	ui.name.TextColor3 = color
	ui.rarity.Text = ("%s · %s"):format(payload.rarityName or "", payload.typeName or ""):upper()
	ui.fillView({ id = payload.id, typeId = payload.typeId })

	local power = math.floor((payload.rating or 1) * 100 + 0.5)
	local diff = (payload.rating / math.max(payload.equippedRating, 0.01) - 1) * 100
	ui.power.Text = tostring(power)
	if diff > 0.5 then
		ui.diff.Text = ("+%d%%"):format(math.floor(diff + 0.5))
		ui.diff.TextColor3 = Ui.colors.heal
	elseif diff < -0.5 then
		ui.diff.Text = ("%d%%"):format(math.floor(diff - 0.5))
		ui.diff.TextColor3 = Ui.colors.danger
	else
		ui.diff.Text = "="
		ui.diff.TextColor3 = Ui.colors.textMuted
	end
	ui.ability.Text = payload.ability and ("Способность: " .. payload.ability) or "Без способности оружия"
	ui.ability.TextColor3 = payload.ability and Ui.colors.gold or Ui.colors.textMuted
	ui.gold.Text = ("+%d"):format(payload.gold or 0)
	local materialCount = payload.materialCount or payload.iron or 0
	if payload.materialName and payload.materialId ~= "rusty_iron" then
		ui.materialIcon.Visible = false
		ui.iron.Size = UDim2.fromOffset(150, 26)
		ui.iron.Text = ("%s +%d"):format(string.upper(payload.materialName), materialCount)
	else
		ui.materialIcon.Visible = true
		ui.iron.Size = UDim2.fromOffset(60, 26)
		ui.iron.Text = ("+%d"):format(materialCount)
	end

	ui.root.Visible = true
	ui.card.Position = UDim2.new(0.5, 0, 0.62, 0)
	ui.cardScale.Scale = 0.85
	Ui.tween(ui.card, 0.45, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
	Ui.tween(ui.cardScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	ClientState.lockInput("ui", true)
	ClientState.lockInput("chest", true)
	Bus.emit("sfx", { name = "chest" })
	Bus.emit("shake", { amount = 0.15, time = 0.2 })

	ContextActionService:BindAction("KlinokChestClose", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			close()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Escape, Enum.KeyCode.Return)
end

local function build()
	local gui = Ui.screen("KlinokChest", 6)
	ui.root = Ui.frame(gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.Env.void,
		BackgroundTransparency = 0.4,
		Visible = false,
	})
	-- Свечение за карточкой цветом редкости.
	ui.card = Instance.new("Frame")
	ui.card.BackgroundTransparency = 1
	ui.card.AnchorPoint = Vector2.new(0.5, 0.5)
	ui.card.Position = UDim2.fromScale(0.5, 0.5)
	ui.card.Size = UDim2.fromOffset(440, 580)
	ui.card.Parent = ui.root
	ui.cardScale = Instance.new("UIScale")
	ui.cardScale.Parent = ui.card
	ui.glow = Ui.frame(ui.card, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 40, 1, 40),
		BackgroundTransparency = 0.6,
		BackgroundColor3 = Ui.colors.gold,
	})
	local glowGradient = Instance.new("UIGradient")
	glowGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.2),
		NumberSequenceKeypoint.new(0.9, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	glowGradient.Parent = ui.glow

	local panel, stroke = Ui.panel(ui.card, { Size = UDim2.fromScale(1, 1) })
	stroke.Thickness = 5
	ui.stroke = stroke

	Ui.pixel(panel, {
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 18),
		Text = "НАХОДКА",
		TextSize = 11,
		TextColor3 = Ui.colors.textMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		stroke = 2,
	})
	ui.name = Ui.pixel(panel, {
		Position = UDim2.fromOffset(12, 42),
		Size = UDim2.new(1, -24, 0, 34),
		Text = "",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
	})
	ui.rarity = Ui.text(panel, {
		Position = UDim2.fromOffset(12, 80),
		Size = UDim2.new(1, -24, 0, 18),
		Text = "",
		TextSize = 13,
		TextColor3 = Ui.colors.textMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- Витрина с моделью.
	ui.viewBack = Ui.frame(panel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.fromOffset(300, 230),
		BackgroundColor3 = Ui.colors.panelLight,
		ZIndex = 2,
	})
	Ui.outline(ui.viewBack, 3)
	local radial = Instance.new("UIGradient")
	radial.Rotation = 90
	radial.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	radial.Parent = ui.viewBack
	local _, fill = Ui.weaponView(ui.viewBack, nil, {
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	}, { spin = true })
	ui.fillView = fill

	-- Мощь: крупные пиксельные цифры, разница рядом.
	Ui.pixel(panel, {
		Position = UDim2.fromOffset(0, 352),
		Size = UDim2.new(1, 0, 0, 16),
		Text = "МОЩЬ:",
		TextSize = 11,
		TextColor3 = Ui.colors.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		stroke = 2,
	})
	local powerRow = Instance.new("Frame")
	powerRow.BackgroundTransparency = 1
	powerRow.Position = UDim2.fromOffset(0, 372)
	powerRow.Size = UDim2.new(1, 0, 0, 34)
	powerRow.Parent = panel
	local powerLayout = Instance.new("UIListLayout")
	powerLayout.FillDirection = Enum.FillDirection.Horizontal
	powerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	powerLayout.Padding = UDim.new(0, 14)
	powerLayout.Parent = powerRow
	ui.power = Ui.pixel(powerRow, {
		Size = UDim2.fromOffset(110, 34),
		Text = "",
		TextSize = 24,
		TextColor3 = Ui.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		LayoutOrder = 1,
	})
	ui.diff = Ui.pixel(powerRow, {
		Size = UDim2.fromOffset(110, 34),
		Text = "",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
	})
	ui.ability = Ui.text(panel, {
		Position = UDim2.fromOffset(12, 412),
		Size = UDim2.new(1, -24, 0, 20),
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- Награда.
	local reward = Instance.new("Frame")
	reward.BackgroundTransparency = 1
	reward.Position = UDim2.fromOffset(0, 440)
	reward.Size = UDim2.new(1, 0, 0, 30)
	reward.Parent = panel
	local rewardLayout = Instance.new("UIListLayout")
	rewardLayout.FillDirection = Enum.FillDirection.Horizontal
	rewardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rewardLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rewardLayout.Padding = UDim.new(0, 8)
	rewardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rewardLayout.Parent = reward
	Ui.icon(reward, "coin", { Size = UDim2.fromOffset(26, 26), LayoutOrder = 1 })
	ui.gold = Ui.pixel(reward, { Size = UDim2.fromOffset(80, 26), Text = "", TextSize = 13, TextColor3 = Ui.colors.gold, LayoutOrder = 2 })
	ui.materialIcon = Ui.icon(reward, "iron", { Size = UDim2.fromOffset(26, 26), LayoutOrder = 3 })
	ui.iron = Ui.pixel(reward, { Size = UDim2.fromOffset(60, 26), Text = "", TextSize = 13, LayoutOrder = 4 })

	local equipButton = Ui.button(panel, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 22, 1, -26),
		Size = UDim2.new(0.5, -30, 0, 54),
		Text = "НАДЕТЬ",
		TextSize = 14,
	})
	local keepButton = Ui.button(panel, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -22, 1, -26),
		Size = UDim2.new(0.5, -30, 0, 54),
		Text = "В СУМКУ",
		TextSize = 14,
	}, "dark")
	equipButton.Activated:Connect(equip)
	keepButton.Activated:Connect(function()
		Bus.emit("sfx", { name = "ui" })
		close()
	end)
end

function ChestController.start()
	build()
	local remote = Net.get("ChestOpened")
	if remote then
		remote.OnClientEvent:Connect(function(payload)
			if type(payload) == "table" then
				show(payload)
			end
		end)
	end
	print("[ChestController] карточка находки")
end

return ChestController
