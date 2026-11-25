--!nonstrict
-- BossIntroController (клиент)
-- Сцены появления боссов.
--
-- Пять главных боссов (Config/BossIntros + Controllers/BossIntroScenes):
-- режиссёр сцены. Время сцены τ отсчитывается от EnemyStateAt модели — от
-- того же момента, что и анимация IntroScene, поэтому кадры камеры, звуки и
-- декорации совпадают с анимацией и у опоздавших, и в короткой версии
-- (сервер сдвигает EnemyStateAt на full − short). Режиссёр ведёт полосы,
-- оттенок, цитату, титр в стиле босса, тряску, вспышки и плавный выход
-- камеры к игроку (CameraController.release).
--
-- Мини-боссы и боссы без своей сцены — прежняя общая сцена (legacyPlay):
-- общий план сверху, низкий ракурс к лицу, титр на маркер Roar.
-- Всё время сцены босс неуязвим и не атакует (сервер), ввод заблокирован.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anim = require(Shared.Util.Anim)
local ClientState = require(Shared.Util.ClientState)
local Palette = require(Shared.Config.Palette)
local BossIntros = require(Shared.Config.BossIntros)

local Bus = require(script.Parent.Parent.Lib.Bus)
local Ui = require(script.Parent.Parent.Lib.Ui)
local Kit = require(script.Parent.Parent.Lib.BossFxKit)
local CameraController = require(script.Parent.CameraController)
local EnemyVisualController = require(script.Parent.EnemyVisualController)
local BossIntroScenes = require(script.Parent.BossIntroScenes)

local BossIntroController = {}

local V3 = Vector3.new
local UP = V3(0, 1, 0)
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local STEP_NAME = "KlinokBossIntro"
local LINE_W = 560

local ui: any = {}
local BAR = 110
local pendingRoar = nil -- { model, show }
local current = nil -- идущая сцена режиссёра

local function setText(label, transparency: number)
	label.TextTransparency = transparency
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = transparency
	end
end

local function fade(label, goal: number, time: number)
	Ui.tween(label, time, { TextTransparency = goal })
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		Ui.tween(stroke, time, { Transparency = goal })
	end
end

local function build()
	local gui = Ui.screen("KlinokBossIntro", 8)
	ui.top = Ui.frame(gui, {
		Size = UDim2.new(1, 0, 0, BAR),
		Position = UDim2.new(0, 0, 0, -BAR),
		BackgroundColor3 = Palette.Env.void,
	})
	ui.bottom = Ui.frame(gui, {
		Size = UDim2.new(1, 0, 0, BAR),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Palette.Env.void,
	})
	ui.flash = Ui.frame(gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		ZIndex = 5,
	})
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -BAR - 30)
	holder.Size = UDim2.fromOffset(1000, 130)
	holder.ZIndex = 6
	holder.Parent = gui
	ui.scale = Instance.new("UIScale")
	ui.scale.Parent = holder
	ui.decor = Instance.new("Frame")
	ui.decor.Name = "Decor"
	ui.decor.BackgroundTransparency = 1
	ui.decor.Size = UDim2.fromScale(1, 1)
	ui.decor.ZIndex = 6
	ui.decor.Parent = holder
	ui.title = Ui.text(holder, {
		Size = UDim2.new(1, 0, 0, 28),
		Text = "",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Palette.Env.gold,
		ZIndex = 6,
	})
	-- Свечение имени: та же строка с широкой полупрозрачной обводкой позади.
	ui.glow = Ui.pixel(holder, {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 70),
		Text = "",
		TextSize = 54,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = WHITE,
		ZIndex = 5,
		stroke = 9,
	})
	ui.name = Ui.pixel(holder, {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 70),
		Text = "",
		TextSize = 54,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Palette.Material.bladeEdge,
		ZIndex = 6,
		stroke = 4,
	})
	ui.line = Ui.frame(holder, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 112),
		Size = UDim2.fromOffset(0, 6),
		BackgroundColor3 = Palette.UI.danger,
		ZIndex = 6,
	})
	Ui.outline(ui.line, 2)
	ui.gradient = Instance.new("UIGradient")
	ui.gradient.Enabled = false
	ui.gradient.Parent = ui.line
	-- Цитата босса — в нижней полосе, печатается по буквам.
	ui.quote = Ui.text(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -BAR / 2),
		Size = UDim2.new(0.8, 0, 0, 40),
		Text = "",
		TextSize = 22,
		FontFace = Ui.F.bold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = WHITE,
		ZIndex = 7,
	})
	setText(ui.title, 1)
	setText(ui.name, 1)
	setText(ui.glow, 1)
	setText(ui.quote, 1)
end

local function barsIn(time: number)
	Ui.tween(ui.top, time, { Position = UDim2.fromOffset(0, 0) })
	Ui.tween(ui.bottom, time, { Position = UDim2.new(0, 0, 1, -BAR) })
end

local function barsOut(time: number)
	Ui.tween(ui.top, time, { Position = UDim2.new(0, 0, 0, -BAR) })
	Ui.tween(ui.bottom, time, { Position = UDim2.new(0, 0, 1, 0) })
end

local function hideTitle(time: number)
	fade(ui.name, 1, time)
	fade(ui.title, 1, time)
	fade(ui.glow, 1, time)
	Ui.tween(ui.line, time, { Size = UDim2.fromOffset(0, 6) })
	-- Гасим и заливки, И обводки: у заклёпок и скоб декора есть UIStroke,
	-- и он оставался на экране после реплики босса — пустые ромбы и скобы
	-- по бокам (баг с прогона 11.11.2026).
	for _, d in ipairs(ui.decor:GetDescendants()) do
		if d:IsA("GuiObject") then
			Ui.tween(d, time, { BackgroundTransparency = 1 })
		elseif d:IsA("UIStroke") then
			Ui.tween(d, time, { Transparency = 1 })
		end
	end
	-- Подстраховка: после затухания декор убирается совсем, чтобы никакой
	-- прерванный твин не оставил остатков. Если уже началась новая сцена —
	-- её свежий декор не трогаем.
	task.delay(time + 0.1, function()
		if not current and ui.decor.Parent then
			ui.decor:ClearAllChildren()
		end
	end)
end

-- ===== Титр в стиле босса =====

local function dot(size: number, color: Color3, x: number, y: number, round: boolean, rotation: number?)
	local f = Ui.frame(ui.decor, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		Rotation = rotation or 0,
		ZIndex = 6,
	})
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
	else
		Ui.outline(f, 2)
	end
	return f
end

local function decorate(style)
	ui.decor:ClearAllChildren()
	ui.gradient.Enabled = false
	if not style then
		return
	end
	local kind = style.kind
	local cx, ly = 500, 115
	if kind == "iron" then
		-- Заклёпки на концах полосы и кованые скобы у имени.
		for _, sign in ipairs({ -1, 1 }) do
			local r = dot(16, style.line, cx + sign * (LINE_W / 2 + 4), ly, false, 45)
			r.Size = UDim2.fromOffset(0, 0)
			Ui.tween(r, 0.3, { Size = UDim2.fromOffset(16, 16) }, Enum.EasingStyle.Back)
			local brace = Ui.frame(ui.decor, {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx + sign * 330, 67),
				Size = UDim2.fromOffset(8, 56), BackgroundColor3 = style.glow, ZIndex = 6,
			})
			Ui.outline(brace, 2)
		end
	elseif kind == "vines" then
		-- Бутоны роз распускаются вдоль полосы.
		for index = 0, 8 do
			local x = cx - 240 + index * 60
			local d = dot(0, index % 2 == 0 and style.glow or style.line, x, ly + (index % 2 == 0 and -1 or 1) * 9, true)
			task.delay(0.15 + index * 0.05, function()
				Ui.tween(d, 0.3, { Size = UDim2.fromOffset(12, 12) }, Enum.EasingStyle.Back)
			end)
		end
	elseif kind == "claws" then
		-- Три следа когтей по бокам имени.
		for _, sign in ipairs({ -1, 1 }) do
			for index = 1, 3 do
				local slash = Ui.frame(ui.decor, {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx + sign * (318 + index * 14), 67),
					Size = UDim2.fromOffset(5, 0), BackgroundColor3 = style.line, Rotation = sign * 20, ZIndex = 6,
				})
				task.delay(0.1 + index * 0.06, function()
					Ui.tween(slash, 0.15, { Size = UDim2.fromOffset(5, 58) })
				end)
			end
		end
	elseif kind == "molten" then
		-- Раскалённая полоса и угольки, всплывающие над именем.
		ui.gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, style.line),
			ColorSequenceKeypoint.new(0.5, style.glow),
			ColorSequenceKeypoint.new(1, style.line),
		})
		ui.gradient.Enabled = true
		for index = 1, 10 do
			local x = cx + Kit.random:NextNumber(-260, 260)
			local d = dot(Kit.random:NextInteger(4, 7), index % 2 == 0 and style.glow or style.line, x, 100, true)
			Ui.tween(d, Kit.random:NextNumber(1.2, 2.0), { Position = UDim2.fromOffset(x + Kit.random:NextNumber(-20, 20), Kit.random:NextNumber(-10, 30)), BackgroundTransparency = 1 })
		end
	elseif kind == "ink" then
		-- Кляксы у концов полосы.
		for index = 1, 6 do
			local sign = index % 2 == 0 and 1 or -1
			local d = dot(Kit.random:NextInteger(6, 16), style.line, cx + sign * Kit.random:NextNumber(LINE_W / 2 - 30, LINE_W / 2 + 26), ly + Kit.random:NextNumber(-10, 12), true)
			d.BackgroundTransparency = 0.15
		end
	end
end

-- Титр: имя (с печатью букв у летописца), прозвание, полоса, декор.
local function showTitle(data, style)
	local name = (data.name or ""):upper()
	ui.title.Text = data.title or ""
	ui.name.Text = name
	ui.glow.Text = name
	ui.title.TextColor3 = style and style.title or Palette.Env.gold
	ui.name.TextColor3 = style and style.name or Palette.Material.bladeEdge
	ui.line.BackgroundColor3 = style and style.line or Palette.UI.danger
	local nameStroke = ui.name:FindFirstChildOfClass("UIStroke")
	if nameStroke then
		nameStroke.Color = style and style.line:Lerp(BLACK, 0.7) or Ui.colors.outline
	end
	local glowStroke = ui.glow:FindFirstChildOfClass("UIStroke")
	ui.glow.MaxVisibleGraphemes = -1
	ui.name.MaxVisibleGraphemes = -1
	ui.scale.Scale = 1.5
	fade(ui.name, 0, 0.2)
	if style and glowStroke then
		glowStroke.Color = style.glow
		ui.glow.TextTransparency = 1
		glowStroke.Transparency = 1
		Ui.tween(glowStroke, 0.4, { Transparency = 0.72 })
	end
	Ui.tween(ui.scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.25, fade, ui.title, 0, 0.5)
	ui.line.Size = UDim2.fromOffset(0, 6)
	Ui.tween(ui.line, 0.6, { Size = UDim2.fromOffset(LINE_W, 6) })
	decorate(style)
	if style and style.kind == "ink" then
		-- Печать: буквы проступают по одной.
		ui.scale.Scale = 1
		local count = utf8.len(name) or #name
		ui.name.MaxVisibleGraphemes = 0
		ui.glow.MaxVisibleGraphemes = 0
		task.spawn(function()
			for index = 1, count do
				if ui.name.Text ~= name then
					return
				end
				ui.name.MaxVisibleGraphemes = index
				ui.glow.MaxVisibleGraphemes = index
				task.wait(0.045)
			end
			ui.name.MaxVisibleGraphemes = -1
			ui.glow.MaxVisibleGraphemes = -1
		end)
	end
	Bus.emit("sfx", { name = "bossIntro" })
end

-- ===== Прежняя общая сцена (мини-боссы и боссы без своей сцены) =====

local function legacyPlay(data)
	local duration = data.duration or 4.2
	local model = data.model
	local startedAt = os.clock()
	ClientState.lockInput("cutscene", true)
	barsIn(0.5)

	local spawn = data.position or V3(0, 0, 0)
	local function bossPosition(): Vector3
		local rig = EnemyVisualController.rigOf(model)
		return rig and rig.pos or spawn
	end

	CameraController.setOverride(function()
		local t = os.clock() - startedAt
		local boss = bossPosition()
		if t < duration * 0.42 then
			-- Общий план сверху: кубики слетаются в фигуру.
			local k = Anim.ease.sine(t / (duration * 0.42))
			local position = boss + V3(6 - 10 * k, 30 - 10 * k, 38 - 10 * k)
			return CFrame.lookAt(position, boss + V3(0, 6, 0)), 60
		end
		-- Низкий ракурс: камера скользит снизу вверх к забралу.
		local k = Anim.ease.quadInOut(math.clamp((t - duration * 0.42) / (duration * 0.58), 0, 1))
		local angle = math.rad(-25 + 40 * k)
		local position = boss + V3(math.sin(angle) * 18, 2 + 3 * k, math.cos(angle) * 18)
		local target = boss + V3(0, 6 + 5 * k, 0)
		return CFrame.lookAt(position, target), 58 - 10 * k
	end)

	-- Рёв (маркер Roar анимации Intro): вспышка, удар, титр. Если маркер не
	-- пришёл (нет префаба), титр выходит по времени.
	local shown = false
	local function show()
		if shown then
			return
		end
		shown = true
		ui.flash.BackgroundColor3 = WHITE
		ui.flash.BackgroundTransparency = 0.2
		Ui.tween(ui.flash, 0.5, { BackgroundTransparency = 1 })
		showTitle(data, nil)
	end
	pendingRoar = { model = model, show = show }
	task.delay(math.min(3.3, duration - 0.6), show)

	task.delay(duration - 0.1, function()
		CameraController.release(0.6, bossPosition() + V3(0, 4, 0))
		ClientState.lockInput("cutscene", false)
		barsOut(0.5)
		hideTitle(0.6)
	end)
end

-- ===== Режиссёр сцены =====

local Ctx = {}
Ctx.__index = Ctx

function Ctx:at(a: number, s: number, y: number): Vector3
	return self.B + self.F * a + self.R * s + UP * y
end

function Ctx:add(instance)
	if instance then
		table.insert(self.props, instance)
	end
	return instance
end

function Ctx:rig()
	if not self.rigRef and self.model then
		self.rigRef = EnemyVisualController.rigOf(self.model)
	end
	return self.rigRef
end

local PART_NAMES = {
	head = { "Head" },
	chest = { "UpperTorso", "Torso", "Chest" },
	root = { "LowerTorso", "HumanoidRootPart", "Torso" },
}
local PART_FALLBACK = { head = 0.9, chest = 0.6, root = 0.5 }

function Ctx:part(ref: string): Vector3
	local rig = self:rig()
	local model = rig and rig.model
	if model then
		for _, name in ipairs(PART_NAMES[ref] or {}) do
			local part = model:FindFirstChild(name, true)
			if part and part:IsA("BasePart") then
				return part.Position
			end
		end
	end
	local offset = rig and rig.introOffset or Vector3.zero
	return self.B + offset + UP * self.H * (PART_FALLBACK[ref] or 0.5)
end

-- Отметка сцены: fired — один раз, когда τ дошло до неё; late — отметка
-- была до начала просмотра (короткая сцена, поздний вход): без звука/удара.
function Ctx:beat(name: string)
	local at = self.cfg.beats[name]
	if not at or self.fired[name] or self.tau < at then
		return false, false
	end
	self.fired[name] = true
	return true, at < self.start - 0.05
end

function Ctx:shake(amount: number, time: number)
	Kit.shake(amount, time)
end

function Ctx:flash(color: Color3, from: number, time: number)
	ui.flash.BackgroundColor3 = color
	ui.flash.BackgroundTransparency = from
	Ui.tween(ui.flash, time, { BackgroundTransparency = 1 })
end

function Ctx:punch(delta: number, time: number)
	Bus.emit("fov", { amount = delta, time = time })
end

function Ctx:sfx(name: string, position: Vector3?)
	Kit.sfx(name, position)
end

local function resolve(ctx, spec): Vector3
	local base = spec.ref and ctx:part(spec.ref) or ctx.B
	return base + ctx.F * spec[1] + ctx.R * spec[2] + UP * spec[3]
end

local function sine(k: number): number
	k = math.clamp(k, 0, 1)
	return (1 - math.cos(math.pi * k)) / 2
end

-- Кадр камеры на время τ: ключ ≤ τ; fn — свой ход; иначе плавно к
-- следующему ключу, если тот не склейка.
local function track(ctx, tau: number)
	local shots = ctx.shots
	local index = 1
	for i, key in ipairs(shots) do
		if key.t <= tau then
			index = i
		else
			break
		end
	end
	local key = shots[index]
	if key.fn then
		return key.fn(ctx, tau)
	end
	local pos, look, fov = resolve(ctx, key.pos), resolve(ctx, key.look), key.fov or 60
	local nextKey = shots[index + 1]
	if nextKey and not nextKey.cut and not nextKey.fn and tau > key.t then
		local e = sine((tau - key.t) / math.max(nextKey.t - key.t, 1e-3))
		pos = pos:Lerp(resolve(ctx, nextKey.pos), e)
		look = look:Lerp(resolve(ctx, nextKey.look), e)
		fov += ((nextKey.fov or fov) - fov) * e
	end
	return pos, look, fov
end

-- Камера не уходит за стены: от точки взгляда к камере, мимо персонажей,
-- декораций сцены, моделей врагов и невидимых зон.
local function protect(ctx, pos: Vector3, look: Vector3): Vector3
	local offset = pos - look
	if offset.Magnitude < 0.5 then
		return pos
	end
	local exclude = { Kit.folder() }
	local visuals = Workspace:FindFirstChild("EnemyVisuals")
	if visuals then
		table.insert(exclude, visuals)
	end
	if ctx.model then
		table.insert(exclude, ctx.model)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	for _ = 1, 4 do
		params.FilterDescendantsInstances = exclude
		local hit = Workspace:Raycast(look, offset, params)
		if not hit then
			return pos
		end
		local part = hit.Instance
		if part.Transparency >= 0.95 or not part.CanCollide then
			table.insert(exclude, part)
		else
			local distance = math.max((hit.Position - look).Magnitude - 0.6, 1.5)
			return look + offset.Unit * distance
		end
	end
	return pos
end

-- Персонажи игроков на время сцены прячем (не загораживают кадр).
local function hideCharacters(hidden: boolean)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			for _, d in ipairs(character:GetDescendants()) do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = hidden and 1 or 0
				end
			end
		end
	end
end

local function finish(run)
	if run.done then
		return
	end
	run.done = true
	if current == run then
		current = nil
	end
	RunService:UnbindFromRenderStep(STEP_NAME)
	local ctx = run.ctx
	if run.scene.cleanup then
		local ok, err = pcall(run.scene.cleanup, ctx)
		if not ok then
			warn("[BossIntroController] cleanup:", err)
		end
	end
	pcall(BossIntroScenes.setHidden, ctx, 0)
	pcall(BossIntroScenes.eyes, ctx, true)
	local rig = ctx:rig()
	if rig then
		rig.introOffset = nil
		rig.introFacing = nil
	end
	local highlight = ctx.state.highlight
	if highlight and highlight.Parent then
		highlight:Destroy()
	end
	for _, instance in ipairs(ctx.props) do
		if instance.Parent then
			if instance:IsA("BasePart") then
				Kit.fade(instance, 0.5)
			else
				instance:Destroy()
			end
		end
	end
	CameraController.release(0.9, ctx:part("chest"))
	ClientState.lockInput("cutscene", false)
	Bus.emit("hud", { visible = true })
	hideCharacters(false)
	barsOut(0.6)
	fade(ui.quote, 1, 0.3)
	if run.tint then
		local tint = run.tint
		Kit.tween(tint, 0.8, { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = WHITE })
		task.delay(0.9, function()
			tint:Destroy()
		end)
	end
	task.delay(1.0, hideTitle, 0.6)
end

local function scenePlay(data, cfg, scene)
	local model = data.model
	local stateName = model and model:GetAttribute("EnemyState")
	if stateName ~= nil and stateName ~= "spawning" then
		return -- сцена уже закончилась (поздний вход)
	end
	local stateAt = model and model:GetAttribute("EnemyStateAt")
	local sceneStart = typeof(stateAt) == "number" and stateAt or (Kit.serverNow() - (data.skip or 0))
	local tau0 = Kit.serverNow() - sceneStart
	if tau0 >= cfg.full - 0.3 then
		return
	end
	if current then
		finish(current)
	end
	local run = { scene = scene, cfg = cfg, sceneStart = sceneStart, startedClock = os.clock(), done = false, broken = false, ctx = nil, tint = nil }
	current = run
	ClientState.lockInput("cutscene", true)

	-- Модель могла ещё не обзавестись визуалом: ждём его немного.
	local rig = model and EnemyVisualController.rigOf(model)
	local waited = os.clock()
	while model and not rig and os.clock() - waited < 0.6 and current == run do
		task.wait()
		rig = EnemyVisualController.rigOf(model)
	end
	if current ~= run then
		return
	end

	-- Система координат: ноги босса, взгляд — к игроку.
	local p = data.position or V3(0, 0, 0)
	local B = rig and rig.pos or V3(p.X, Kit.groundY(p + UP * 2, p.Y - 3), p.Z)
	local F
	local root = Kit.localRoot()
	if root then
		local d = (root.Position - B) * V3(1, 0, 1)
		F = d.Magnitude > 1 and d.Unit or nil
	end
	if not F and rig and rig.facing then
		F = rig.facing
	end
	F = F or V3(0, 0, -1)
	local ctx = setmetatable({
		typeId = data.typeId, cfg = cfg, model = model, data = data,
		B = B, F = F, R = F:Cross(UP), H = scene.H or 10, shots = scene.shots,
		start = math.max(Kit.serverNow() - sceneStart, 0), short = data.short, state = {}, props = {}, fired = {}, tau = 0,
	}, Ctx)
	ctx.tau = ctx.start
	run.ctx = ctx

	-- Полосы, оттенок, интерфейс.
	barsIn(0.5)
	Bus.emit("hud", { visible = false })
	hideCharacters(true)
	ui.flash.BackgroundTransparency = 1
	if cfg.tint then
		local tint = Instance.new("ColorCorrectionEffect")
		tint.Name = "BossIntroTint"
		tint.Parent = Lighting
		Kit.tween(tint, 0.6, { Brightness = cfg.tint.brightness or 0, Contrast = cfg.tint.contrast or 0, Saturation = cfg.tint.saturation or 0, TintColor = cfg.tint.color or WHITE })
		run.tint = tint
	end
	local style = cfg.style
	local roarAt = cfg.beats.roar or (cfg.full - 2)
	-- Цитата: печатается до рёва; в короткой сцене — быстрее или никак.
	local quote = cfg.quote
	local quoteAt = math.max(ctx.start, 0.4) + 0.2
	local quoteEnd = roarAt - 0.25
	local quoteLen = quote and (utf8.len(quote) or #quote) or 0
	local quoteCps = math.max(30, quoteLen / math.max((quoteEnd - quoteAt) * 0.55, 0.3))
	local quoteOn = quote and quoteEnd - quoteAt >= 1.0
	if quoteOn then
		ui.quote.Text = quote
		ui.quote.TextColor3 = style and style.title or WHITE
		local stroke = ui.quote:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = style and style.line:Lerp(BLACK, 0.75) or Ui.colors.outline
		end
		ui.quote.MaxVisibleGraphemes = 0
	end
	local quoteShown, quoteHidden, titleShown = false, false, false

	local ok, err = pcall(scene.setup, ctx)
	if not ok then
		warn("[BossIntroController] setup:", err)
		run.broken = true
	end

	CameraController.setOverride(function()
		if run.done then
			return nil
		end
		local tau = Kit.serverNow() - run.sceneStart
		local okTrack, pos, look, fov = pcall(track, ctx, tau)
		if not okTrack or typeof(pos) ~= "Vector3" or typeof(look) ~= "Vector3" then
			pos, look, fov = ctx:at(14, -4, 5), ctx:at(0, 0, ctx.H * 0.5), 60
		end
		pos = protect(ctx, pos, look)
		if (look - pos).Magnitude < 0.05 then
			look = pos + ctx.F * -1
		end
		return CFrame.lookAt(pos, look), fov
	end)

	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value - 1, function(dt)
		if run.done then
			return
		end
		local tau = Kit.serverNow() - run.sceneStart
		ctx.tau = tau
		local alive = not model or model.Parent ~= nil
		if tau >= cfg.full or not alive or os.clock() - run.startedClock > cfg.full + 3 then
			finish(run)
			return
		end
		local r = ctx:rig()
		if r and r.introFacing == nil then
			r.introFacing = ctx.F
		end
		if not run.broken then
			local okUpdate, errUpdate = pcall(scene.update, ctx, tau, dt)
			if not okUpdate then
				warn("[BossIntroController] update:", errUpdate)
				run.broken = true
			end
		end
		-- Цитата.
		if quoteOn and not quoteHidden then
			if tau >= quoteAt then
				if not quoteShown then
					quoteShown = true
					setText(ui.quote, 0)
				end
				ui.quote.MaxVisibleGraphemes = math.clamp(math.floor((tau - quoteAt) * quoteCps), 0, quoteLen)
			end
			if tau >= quoteEnd then
				quoteHidden = true
				fade(ui.quote, 1, 0.3)
			end
		end
		-- Титр — на рёв.
		if not titleShown and tau >= roarAt then
			titleShown = true
			showTitle(data, style)
		end
	end)
end

local function play(data)
	local cfg = not data.miniBoss and BossIntros.get(data.typeId)
	local scene = cfg and BossIntroScenes.get(data.typeId)
	if cfg and scene then
		scenePlay(data, cfg, scene)
	else
		legacyPlay(data)
	end
end

function BossIntroController.start()
	build()
	Bus.on("bossIntro", function(data)
		task.spawn(play, data)
	end)
	Bus.on("bossRoar", function(data)
		if pendingRoar and (data.model == nil or data.model == pendingRoar.model) then
			pendingRoar.show()
			pendingRoar = nil
		end
	end)
	print("[BossIntroController] сцены появления боссов")
end

return BossIntroController
