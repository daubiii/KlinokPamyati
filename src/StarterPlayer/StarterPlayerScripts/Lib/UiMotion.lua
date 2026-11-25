--!nonstrict
-- UiMotion (клиент)
-- Общая «режиссура» интерфейса: перелистывание страниц, каскадное появление,
-- плавное проявление/гашение целых веток, печатная машинка с «голосом»,
-- лёгкие толчки и покачивания. Всё на TweenService, без зависимостей от арта.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UiMotion = {}

local function tween(object, time: number, props, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end
UiMotion.tween = tween

-- ===== прозрачность целой ветки =====

-- Какие свойства прозрачности есть у объекта.
local function fields(object)
	if object:IsA("ImageLabel") or object:IsA("ImageButton") then
		return { "ImageTransparency", "BackgroundTransparency" }
	elseif object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		return { "TextTransparency", "BackgroundTransparency", "TextStrokeTransparency" }
	elseif object:IsA("ViewportFrame") then
		return { "ImageTransparency", "BackgroundTransparency" }
	elseif object:IsA("Frame") or object:IsA("ScrollingFrame") then
		return { "BackgroundTransparency" }
	elseif object:IsA("UIStroke") then
		return { "Transparency" }
	end
	return nil
end

-- Снимок текущей прозрачности ветки: { [object] = { prop = value } }.
local function capture(root)
	local snap = {}
	local function add(object)
		local list = fields(object)
		if list then
			local values = {}
			for _, prop in ipairs(list) do
				values[prop] = object[prop]
			end
			snap[object] = values
		end
	end
	add(root)
	for _, d in ipairs(root:GetDescendants()) do
		add(d)
	end
	return snap
end

local function applySnap(snap, alpha: number, time: number?)
	for object, values in pairs(snap) do
		if object.Parent then
			local goal = {}
			for prop, value in pairs(values) do
				goal[prop] = value + (1 - value) * alpha
			end
			if time and time > 0 then
				tween(object, time, goal)
			else
				for prop, value in pairs(goal) do
					object[prop] = value
				end
			end
		end
	end
end

-- Погасить ветку за time. → restore(): мгновенно вернуть как было.
function UiMotion.fadeOut(root, time: number?)
	local snap = capture(root)
	applySnap(snap, 1, time or 0.18)
	return function()
		applySnap(snap, 0, 0)
	end
end

-- Проявить ветку: сейчас она в «итоговом» виде, станет прозрачной и проявится.
function UiMotion.fadeIn(root, time: number?, delay: number?)
	local snap = capture(root)
	applySnap(snap, 1, 0)
	local function run()
		applySnap(snap, 0, time or 0.22)
	end
	if delay and delay > 0 then
		task.delay(delay, run)
	else
		run()
	end
	return snap
end

-- ===== перелистывание =====

local pages = setmetatable({}, { __mode = "k" })

local function home(object)
	local entry = pages[object]
	if not entry then
		entry = { pos = object.Position, rot = object.Rotation, token = 0 }
		pages[object] = entry
	end
	return entry
end
UiMotion.home = home

-- Страница уходит: сдвиг в сторону dir (-1 влево, 1 вправо), поворот и гашение.
function UiMotion.pageOut(page, dir: number, onDone)
	local entry = home(page)
	entry.token += 1
	local token = entry.token
	if entry.restore then
		entry.restore()
	end
	entry.restore = UiMotion.fadeOut(page, 0.16)
	tween(page, 0.18, {
		Position = entry.pos + UDim2.fromOffset(-dir * 110, -8),
		Rotation = entry.rot - dir * 2.2,
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.19, function()
		if entry.token ~= token then
			return
		end
		page.Visible = false
		page.Position = entry.pos
		page.Rotation = entry.rot
		if entry.restore then
			entry.restore()
			entry.restore = nil
		end
		if onDone then
			onDone()
		end
	end)
end

-- Страница приходит с другой стороны и «ложится» на стол.
function UiMotion.pageIn(page, dir: number, delay: number?)
	local entry = home(page)
	entry.token += 1
	if entry.restore then
		entry.restore()
		entry.restore = nil
	end
	page.Visible = true
	page.Position = entry.pos + UDim2.fromOffset(dir * 140, 16)
	page.Rotation = entry.rot + dir * 2.6
	UiMotion.fadeIn(page, 0.2, delay)
	task.delay(delay or 0, function()
		tween(page, 0.38, { Position = entry.pos, Rotation = entry.rot }, Enum.EasingStyle.Back)
	end)
end

-- Каскад: объекты по очереди въезжают со смещения offset (Vector2).
function UiMotion.cascade(objects, offset: Vector2?, step: number?, delay: number?, time: number?)
	local off = offset or Vector2.new(0, 24)
	for i, object in ipairs(objects) do
		local target = object.Position
		local rot = object.Rotation
		object.Position = target + UDim2.fromOffset(off.X, off.Y)
		local snap = capture(object)
		applySnap(snap, 1, 0)
		task.delay((delay or 0) + (i - 1) * (step or 0.04), function()
			if object.Parent then
				applySnap(snap, 0, (time or 0.28) * 0.7)
				tween(object, time or 0.28, { Position = target, Rotation = rot }, Enum.EasingStyle.Back)
			end
		end)
	end
end

-- ===== толчки и покачивания =====

local function scaleOf(object)
	local scale = object:FindFirstChild("MotionScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "MotionScale"
		scale.Parent = object
	end
	return scale
end

-- Короткий «тычок» масштабом: 1 → 1+amount → 1.
function UiMotion.punch(object, amount: number?, time: number?)
	local scale = scaleOf(object)
	local t = time or 0.16
	scale.Scale = 1 + (amount or 0.08)
	tween(scale, t, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Появление из точки (0 → 1) с перелётом.
function UiMotion.popIn(object, delay: number?, from: number?)
	local scale = scaleOf(object)
	scale.Scale = from or 0.4
	task.delay(delay or 0, function()
		tween(scale, 0.26, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
end

-- Бесконечное покачивание по Y (индикатор «дальше», маркеры). → stop().
function UiMotion.bob(object, amplitude: number?, period: number?)
	local base = object.Position
	local amp = amplitude or 4
	local per = period or 0.9
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not object.Parent then
			connection:Disconnect()
			return
		end
		local y = math.sin((os.clock() - started) / per * math.pi * 2) * amp
		object.Position = base + UDim2.fromOffset(0, math.floor(y + 0.5))
	end)
	return function()
		connection:Disconnect()
		if object.Parent then
			object.Position = base
		end
	end
end

-- Мягкое «дыхание» прозрачности (свечение, рамка выбора). → stop().
function UiMotion.breathe(object, prop: string, a: number, b: number, period: number?)
	local t = TweenService:Create(object, TweenInfo.new(period or 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { [prop] = b })
	object[prop] = a
	t:Play()
	return function()
		t:Cancel()
	end
end

-- Наведение: кнопка-полоска приподнимается (или сдвигается) и возвращается.
function UiMotion.hover(holder, hit, offset: UDim2?)
	local base = holder.Position
	local shift = offset or UDim2.fromOffset(0, -3)
	hit.MouseEnter:Connect(function()
		tween(holder, 0.1, { Position = base + shift })
	end)
	hit.MouseLeave:Connect(function()
		tween(holder, 0.12, { Position = base })
	end)
end

-- ===== печатная машинка =====

-- Печатает text в label (RichText допускается — считаем графемы).
-- opts: speed (символов/с), onChar(char, index), onDone(), pauses (true — паузы на знаках).
-- → { skip = fn, cancel = fn, done = bool }
function UiMotion.typewriter(label, text: string, opts)
	opts = opts or {}
	label.Text = text
	label.MaxVisibleGraphemes = 0
	local plain = text:gsub("<[^>]->", "")
	local chars = {}
	for _, code in utf8.codes(plain) do
		table.insert(chars, utf8.char(code))
	end
	local total = #chars
	local job: any = { done = false }
	local cancelled = false
	local function finish()
		if job.done then
			return
		end
		job.done = true
		label.MaxVisibleGraphemes = -1
		if opts.onDone then
			opts.onDone()
		end
	end
	function job.skip()
		finish()
	end
	function job.cancel()
		cancelled = true
		job.done = true
	end
	local speed = opts.speed or 48
	task.spawn(function()
		local shown = 0
		local wait = 0
		local last = os.clock()
		while not job.done and not cancelled and shown < total do
			RunService.RenderStepped:Wait()
			local now = os.clock()
			wait -= now - last
			last = now
			while wait <= 0 and shown < total and not job.done do
				shown += 1
				local ch = chars[shown]
				label.MaxVisibleGraphemes = shown
				if opts.onChar then
					opts.onChar(ch, shown)
				end
				local delay = 1 / speed
				if opts.pauses ~= false then
					if ch == "." or ch == "!" or ch == "?" or ch == "…" then
						delay *= 7
					elseif ch == "," or ch == "—" or ch == ":" or ch == ";" then
						delay *= 3.5
					end
				end
				wait += delay
			end
		end
		if not cancelled then
			finish()
		end
	end)
	return job
end

return UiMotion
