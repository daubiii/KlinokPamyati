--!nonstrict
-- GateKit (клиент)
-- Общие кирпичики меню Врат Печатей (меню этажа и меню сундука):
-- модальная панель поверх затемнения, прокручиваемая колонка со списком,
-- абзацы с автовысотой, заголовки разделов, чипы, вкладки.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiAssets = require(Shared.Config.UiAssets)

local PixelUi = require(script.Parent.PixelUi)
local PaperUi = require(script.Parent.PaperUi)
local UiMotion = require(script.Parent.UiMotion)
local UiSound = require(script.Parent.UiSound)

local GateKit = {}

local C = UiAssets.Colors
GateKit.Text = Color3.fromRGB(226, 214, 192)
GateKit.Dim = Color3.fromRGB(168, 156, 142)
GateKit.Keeper = Color3.fromRGB(255, 150, 140)
GateKit.Line = Color3.fromRGB(90, 66, 44)
GateKit.ChipFill = Color3.fromRGB(26, 19, 16)

-- ВЕРХНИЙ РЕГИСТР для кириллицы (string.upper понимает только латиницу).
function GateKit.upper(text: string): string
	local out = {}
	for _, c in utf8.codes(text) do
		if c >= 0x430 and c <= 0x44F then
			c -= 0x20
		elseif c == 0x451 then
			c = 0x401
		elseif c >= 97 and c <= 122 then
			c -= 32
		end
		table.insert(out, utf8.char(c))
	end
	return table.concat(out)
end

-- Модальная панель: затемнение (клик по нему — onDim), панель в оправе, body
-- поверх оправы. → { dim, panel, body, close(onDone) }
function GateKit.modal(parent, pos: UDim2, size: UDim2, z: number, onDim)
	local dim = Instance.new("TextButton")
	dim.Name = "ModalDim"
	dim.AutoButtonColor = false
	dim.Text = ""
	dim.BorderSizePixel = 0
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.Position = UDim2.fromOffset(-600, -600)
	dim.Size = UDim2.new(1, 1200, 1, 1200)
	dim.ZIndex = z
	dim.Parent = parent
	TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 0.42 }):Play()
	if onDim then
		dim.Activated:Connect(onDim)
	end
	local panel = PixelUi.panel(parent, pos, size, { z = z + 2 })
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.ZIndex = z + 8
	body.Parent = panel
	UiMotion.popIn(panel, 0, 0.92)
	local object = { dim = dim, panel = panel, body = body, alive = true }
	function object.close(onDone)
		if not object.alive then
			return
		end
		object.alive = false
		for _, d in ipairs(panel:GetDescendants()) do
			if d:IsA("GuiObject") then
				d.Interactable = false
			end
		end
		TweenService:Create(dim, TweenInfo.new(0.14), { BackgroundTransparency = 1 }):Play()
		PixelUi.tween(panel, 0.14, { Position = pos + UDim2.fromOffset(0, 24) })
		UiMotion.fadeOut(panel, 0.14)
		task.delay(0.15, function()
			dim:Destroy()
			panel:Destroy()
			if onDone then
				onDone()
			end
		end)
	end
	return object
end

-- Тонкая линия-разделитель.
function GateKit.line(parent, pos: UDim2, size: UDim2, color: Color3?)
	local line = Instance.new("Frame")
	line.BorderSizePixel = 0
	line.BackgroundColor3 = color or GateKit.Line
	line.Position = pos
	line.Size = size
	line.ZIndex = 5
	line.Parent = parent
	return line
end

-- Прокручиваемая колонка с вертикальным списком (детям ставится LayoutOrder).
function GateKit.scroll(parent, pos: UDim2, size: UDim2, opts)
	opts = opts or {}
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = opts.name or "Scroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = pos
	scroll.Size = size
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = opts.bar or Color3.fromRGB(150, 110, 70)
	scroll.ElasticBehavior = Enum.ElasticBehavior.Never
	scroll.ZIndex = 6
	scroll.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, opts.gap or 10)
	layout.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 16)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = scroll
	local object = { frame = scroll, order = 0 }
	function object.next(): number
		object.order += 1
		return object.order
	end
	return object
end

-- Абзац с автовысотой (Garamond). kind: nil | "italic" | "bold".
function GateKit.para(parent, text: string, size: number?, color: Color3?, opts)
	opts = opts or {}
	local fn = opts.kind == "italic" and PaperUi.italic or (opts.kind == "bold" and PaperUi.bold or PaperUi.text)
	local label = fn(parent, text, size or 20, color or GateKit.Text, {
		Size = UDim2.new(1, opts.inset or 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextXAlignment = opts.align or Enum.TextXAlignment.Left,
		LineHeight = opts.lineHeight or 1.08,
		ZIndex = 8,
	})
	if opts.order then
		label.LayoutOrder = opts.order
	end
	return label
end

-- Заголовок раздела: пиксельный текст + линия до правого края.
function GateKit.heading(parent, text: string, color: Color3?, order: number?)
	local holder = Instance.new("Frame")
	holder.Name = "Heading"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 30)
	holder.ZIndex = 7
	holder.LayoutOrder = order or 0
	holder.Parent = parent
	local w = (utf8.len(text) or #text) * 16 + 12
	PixelUi.label(holder, text, 16, color or C.gold, { Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(w, 22), ZIndex = 8 })
	GateKit.line(holder, UDim2.fromOffset(w + 6, 15), UDim2.new(1, -(w + 6), 0, 2))
	return holder
end

-- Сетка карточек (автовысота). → Frame-контейнер.
function GateKit.grid(parent, cell: Vector2, gap: number?, order: number?)
	local holder = Instance.new("Frame")
	holder.Name = "Grid"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.ZIndex = 7
	holder.LayoutOrder = order or 0
	holder.Parent = parent
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	grid.CellPadding = UDim2.fromOffset(gap or 10, gap or 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = holder
	return holder
end

-- Чип: тёмная плашка с обводкой, верхняя строка пиксельным шрифтом, нижняя — Garamond.
function GateKit.chip(parent, top: string, bottom: string?, topColor: Color3?, bottomColor: Color3?, order: number?)
	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.BorderSizePixel = 0
	chip.BackgroundColor3 = GateKit.ChipFill
	chip.BackgroundTransparency = 0.15
	chip.ZIndex = 7
	chip.LayoutOrder = order or 0
	chip.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = GateKit.Line
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = chip
	local name = PixelUi.label(chip, top, 16, topColor or C.bone, {
		Position = UDim2.fromOffset(10, bottom and 4 or 0),
		Size = UDim2.new(1, -20, 0, bottom and 24 or 1),
		TextScaled = true,
		ZIndex = 8,
	})
	if not bottom then
		name.Size = UDim2.new(1, -20, 1, 0)
	end
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 16
	limit.MinTextSize = 8
	limit.Parent = name
	if bottom then
		PaperUi.italic(chip, bottom, 17, bottomColor or GateKit.Dim, {
			Position = UDim2.fromOffset(10, 28),
			Size = UDim2.new(1, -20, 0, 20),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 8,
		})
	end
	return chip
end

-- Ряд вкладок. tabs = { {id, text}, ... } → { buttons, select(id) }.
function GateKit.tabs(parent, pos: UDim2, width: number, height: number, tabs, current: string, onSelect)
	local object: any = { buttons = {}, current = current }
	for i, tab in ipairs(tabs) do
		local b = PixelUi.button(parent, tab[1] == current and "gold" or "wood", pos + UDim2.fromOffset((i - 1) * (width + 12), 0),
			UDim2.fromOffset(width, height), tab[2], function()
				if object.current == tab[1] then
					return
				end
				UiSound.play("tab_select")
				object.select(tab[1])
				onSelect(tab[1])
			end, { z = 8 })
		object.buttons[tab[1]] = b
	end
	function object.select(id: string)
		object.current = id
		for tabId, b in pairs(object.buttons) do
			b:setKind(tabId == id and "gold" or "wood")
		end
	end
	return object
end

-- Мягкое появление содержимого колонки сверху вниз.
function GateKit.cascade(container, offset: Vector2?)
	local items = {}
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("GuiObject") then
			table.insert(items, c)
		end
	end
	table.sort(items, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end
		return a.Position.Y.Offset < b.Position.Y.Offset
	end)
	UiMotion.cascade(items, offset or Vector2.new(0, 14), 0.03, 0, 0.22)
end

function GateKit.clear(container)
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

return GateKit
