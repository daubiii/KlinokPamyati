--!nonstrict
-- WindowBase (клиент)
-- Общий каркас окна-сцены: ScreenGui, холст 1600×900 по центру, доска-заголовок,
-- кошелёк, крестик, мягкая виньетка и плавное появление/исчезание.

local Workspace = game:GetService("Workspace")

local PixelUi = require(script.Parent.PixelUi)
local UiMotion = require(script.Parent.UiMotion)
local UiSound = require(script.Parent.UiSound)

local WindowBase = {}
WindowBase.__index = WindowBase

-- opts: { title, sub, wallet = { {icon, attr}... } | false, onClose, order, intro }
-- intro (по умолчанию — у окон с доской-заголовком): звук открытия, виньетка
-- проявляется, содержимое холста мягко проступает, при закрытии — гаснет.
function WindowBase.new(name: string, opts)
	local self = setmetatable({}, WindowBase)
	self.gui, self.root = PixelUi.screen(name, opts.order or 20)
	self.canvas = PixelUi.canvas(self.root)
	self.alive = true
	self.cleanup = {}

	-- виньетка: сцена остаётся видна, края темнее
	local vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.BorderSizePixel = 0
	vignette.BackgroundColor3 = Color3.new(0, 0, 0)
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundTransparency = 0.35
	vignette.ZIndex = 0
	vignette.Parent = self.root
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.25, 1),
		NumberSequenceKeypoint.new(0.75, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	g.Parent = vignette
	self.vignette = vignette

	if opts.title then
		self.title = PixelUi.plankTitle(self.root, opts.title, opts.sub)
		PixelUi.slideIn(self.title, 2)
	end
	if opts.wallet ~= false then
		self.refreshWallet = PixelUi.wallet(self.root, opts.wallet or { { "coin", "Gold" }, { "ingot", "IronCount" }, { "dust", "EchoDust" } }, 92)
	end
	self.closeButton = PixelUi.closeButton(self.root, opts.onClose)

	local intro = opts.intro
	if intro == nil then
		intro = opts.title ~= nil
	end
	self.intro = intro
	if intro then
		UiSound.play("paper_slide", { volume = 0.8 })
		UiSound.play("dialog_open", { volume = 0.5, gap = 0 })
		vignette.BackgroundTransparency = 1
		PixelUi.tween(vignette, 0.3, { BackgroundTransparency = 0.35 })
		UiMotion.popIn(self.closeButton, 0.25, 0.3)
		-- холст «подъезжает» масштабом (прозрачность не трогаем — у окон свои каскады)
		local introScale = Instance.new("UIScale")
		introScale.Name = "IntroScale"
		introScale.Scale = 0.94
		introScale.Parent = self.canvas
		PixelUi.tween(introScale, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	return self
end

-- Точка мира → координаты корня окна (дизайн-пиксели).
function WindowBase:toRoot(world: Vector3): Vector2?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local p, onScreen = camera:WorldToViewportPoint(world)
	if not onScreen then
		return nil
	end
	local scale = self.root:FindFirstChildOfClass("UIScale")
	local s = scale and scale.Scale or 1
	return Vector2.new(p.X / s, p.Y / s)
end

-- Координаты холста → координаты корня.
function WindowBase:canvasToRoot(v: Vector2): Vector2
	local rootSize = self.root.AbsoluteSize
	local scale = self.root:FindFirstChildOfClass("UIScale")
	local s = scale and scale.Scale or 1
	local offset = (Vector2.new(rootSize.X, rootSize.Y) / s - PixelUi.DESIGN) / 2
	return v + offset
end

function WindowBase:onCleanup(fn)
	table.insert(self.cleanup, fn)
end

function WindowBase:destroy()
	if not self.alive then
		return
	end
	self.alive = false
	for _, fn in ipairs(self.cleanup) do
		pcall(fn)
	end
	local gui = self.gui
	-- быстрое исчезание
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.Interactable = false
		end
	end
	PixelUi.tween(self.canvas, 0.15, { Position = UDim2.new(0.5, 0, 0.5, 30) })
	if self.intro then
		UiSound.play("page_back", { volume = 0.6 })
		UiMotion.fadeOut(self.root, 0.15)
	end
	task.delay(0.16, function()
		gui:Destroy()
	end)
end

return WindowBase
