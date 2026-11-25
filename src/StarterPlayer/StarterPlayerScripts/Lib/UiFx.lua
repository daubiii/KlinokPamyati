--!nonstrict
-- UiFx (клиент)
-- Эффекты наград и действий: тряска камеры, вспышка экрана, взрыв пиксельных
-- искр, полёт иконки по дуге, всплывающие цифры, счёт «по одной» (звёзды).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PixelUi = require(script.Parent.PixelUi)
local Bus = require(script.Parent.Bus)

local UiFx = {}

local fxRoot
local function layer()
	if fxRoot and fxRoot.Parent then
		return fxRoot
	end
	local _gui
	_gui, fxRoot = PixelUi.screen("KlinokFx", 50)
	return fxRoot
end

-- Тряска камеры. Окна-сцены держат камеру сами и прибавляют UiFx.shakeOffset()
-- каждый кадр; в обычной игре тряску делает CameraController по событию Bus "shake".
local shakeUntil, shakeStart, shakePower = 0, 0, 0
local inScene = false

function UiFx.setSceneCamera(on: boolean)
	inScene = on
end

function UiFx.shake(amount: number?, time: number?)
	if not inScene then
		Bus.emit("shake", { amount = amount or 0.25, time = time or 0.18 })
		return
	end
	shakeStart = os.clock()
	shakeUntil = shakeStart + (time or 0.18)
	shakePower = amount or 0.25
end

function UiFx.shakeOffset(): CFrame
	local now = os.clock()
	if now >= shakeUntil then
		return CFrame.new()
	end
	local k = shakePower * (shakeUntil - now) / math.max(shakeUntil - shakeStart, 0.01)
	return CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * k * 0.05)
end

-- Вспышка всего экрана цветом.
function UiFx.flash(color: Color3?, time: number?, strength: number?)
	local root = layer()
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color or Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 1 - (strength or 0.6)
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = 100
	frame.Parent = root
	local t = TweenService:Create(frame, TweenInfo.new(time or 0.35), { BackgroundTransparency = 1 })
	t:Play()
	t.Completed:Once(function()
		frame:Destroy()
	end)
end

-- Затемнение (для перехода камеры в отдельную сцену). Возвращает функцию «открыть».
function UiFx.fadeOut(time: number?, color: Color3?)
	local root = layer()
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color or Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = 99
	frame.Parent = root
	TweenService:Create(frame, TweenInfo.new(time or 0.25), { BackgroundTransparency = 0 }):Play()
	task.wait(time or 0.25)
	return function(back: number?)
		local t = TweenService:Create(frame, TweenInfo.new(back or 0.35), { BackgroundTransparency = 1 })
		t:Play()
		t.Completed:Once(function()
			frame:Destroy()
		end)
	end
end

-- Взрыв пиксельных искр вокруг точки (в дизайн-координатах parent).
function UiFx.burst(parent, center: Vector2, colors, count: number?, radius: number?)
	local n = count or 24
	local r = radius or 140
	for _ = 1, n do
		local a = math.random() * math.pi * 2
		local d = r * (0.4 + math.random() * 0.8)
		local s = ({ 4, 6, 6, 8 })[math.random(1, 4)]
		local p = PixelUi.piece(parent, "pixel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(center.X, center.Y),
			Size = UDim2.fromOffset(s, s),
			ImageColor3 = colors[math.random(1, #colors)],
			ZIndex = 60,
		})
		if p.Image == "" then
			p.BackgroundColor3 = p.ImageColor3
		end
		local time = 0.45 + math.random() * 0.4
		TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(center.X + math.cos(a) * d, center.Y + math.sin(a) * d + 30),
			ImageTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
		task.delay(time, function()
			p:Destroy()
		end)
	end
end

-- Иконка летит по дуге из точки A в точку B (эхо → клинок, награда → кошелёк).
function UiFx.flyIcon(parent, iconName: string, from: Vector2, to: Vector2, time: number?, onArrive)
	local icon = PixelUi.icon(parent, iconName, UDim2.fromOffset(from.X - 20, from.Y - 20), 40, { ZIndex = 70 })
	local glow = PixelUi.glow(icon, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(90, 90), PixelUi.colors.mem, 0.5)
	glow.ZIndex = 69
	local duration = time or 0.6
	local started = os.clock()
	local lift = math.min(220, (to - from).Magnitude * 0.5)
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - started) / duration, 0, 1)
		local e = t * t * (3 - 2 * t)
		local p = from:Lerp(to, e) - Vector2.new(0, math.sin(t * math.pi) * lift)
		icon.Position = UDim2.fromOffset(p.X - 20, p.Y - 20)
		icon.Rotation = t * 360
		if t >= 1 then
			connection:Disconnect()
			icon:Destroy()
			if onArrive then
				onArrive()
			end
		end
	end)
end

-- Всплывающий текст (+150, ★3 и т.п.).
function UiFx.floatText(parent, text: string, pos: Vector2, color: Color3?, size: number?)
	local label = PixelUi.label(parent, text, size or 24, color or PixelUi.colors.gold, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		Size = UDim2.fromOffset(400, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 80,
	})
	PixelUi.pop(label)
	TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad), {
		Position = UDim2.fromOffset(pos.X, pos.Y - 70),
		TextTransparency = 1,
	}):Play()
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(1.1), { Transparency = 1 }):Play()
	end
	task.delay(1.2, function()
		label:Destroy()
	end)
end

-- Число «набегает» от a до b.
function UiFx.countUp(label, a: number, b: number, time: number?, fmt: string?)
	local duration = time or 0.6
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - started) / duration, 0, 1)
		local v = math.floor(a + (b - a) * (1 - (1 - t) ^ 3) + 0.5)
		label.Text = fmt and fmt:format(v) or tostring(v)
		if t >= 1 then
			connection:Disconnect()
		end
	end)
end

-- Пиксельный слой эффектов поверх всего (для burst без окна).
function UiFx.layer()
	return layer()
end

UiFx.player = Players.LocalPlayer

return UiFx
