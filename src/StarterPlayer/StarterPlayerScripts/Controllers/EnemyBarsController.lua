--!nonstrict
-- EnemyBarsController (клиент)
-- Над врагами: имя белым с толстой обводкой, сегментированная полоска с
-- «призраком» потерянного здоровья, значок угрозы и значки эффектов (ТЗ
-- врагов этажа 1, раздел 2.3).
--
-- Рисуются в экранном пространстве (ScreenGui + WorldToViewportPoint), а не
-- BillboardGui: в этой среде Studio BillboardGui над врагами не отображался
-- (проверено скриншотами), а ScreenGui рисуется всегда. Позиция берётся у
-- сглаженной клиентской модели врага (точка FX_HeadTop), поэтому полоска не
-- дёргается. У босса над головой полоски и имени нет (его здоровье — большая
-- полоса сверху), только значок угрозы.
--
-- Значок угрозы 20×20 над именем:
--   жёлтое «!»  — 0,6 с, когда враг впервые выбирает игрока (после сборки);
--   белое «!»   — мигает 6 Гц весь замах парируемой атаки;
--   красное «!!» — мигает 8 Гц весь замах непарируемой атаки или по зонам.
-- Значки эффектов 14×14 справа от имени: цветной квадрат с буквой (пока без
-- картинок) — О оглушён, Б снята броня.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Config.Palette)

local Ui = require(script.Parent.Parent.Lib.Ui)
local EnemyVisualController = require(script.Parent.EnemyVisualController)
local EnemyFx = require(script.Parent.EnemyFx)

local EnemyBarsController = {}

local MAX_DISTANCE = 75
local tracked = {} -- [model] = entry
local gui

local V = Palette.Voxel

-- Цвет полоски по роли врага.
local ROLE_COLORS = {
	melee = Palette.UI.danger,
	tank = Palette.Env.ember,
	ranged = Palette.UI.danger:Lerp(Palette.Env.gold, 0.25),
	disruptor = Palette.Env.flame,
}

-- Значки эффектов: атрибут «до какого серверного времени», буква, цвет.
local EFFECTS = {
	{ attribute = "EnemyStunnedUntil", letter = "О", color = V.A },
	{ attribute = "EnemyArmorBreakUntil", letter = "Б", color = V.R },
}

local MOVE_STATES = { idle = true, approach = true, retreat = true, circle = true }

local function create(model)
	if tracked[model] then
		return
	end
	local isBoss = model:GetAttribute("EnemyIsBoss") == true
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Size = UDim2.fromOffset(120, 34)
	holder.Visible = false
	holder.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Parent = holder

	local bar = nil
	if not isBoss then
		Ui.text(holder, {
			Size = UDim2.new(1, 0, 0, 16),
			Text = model:GetAttribute("EnemyName") or "",
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			stroke = 2,
		})
		bar = Ui.bar(holder, {
			Position = UDim2.fromOffset(6, 19),
			Size = UDim2.new(1, -12, 0, 11),
		}, {
			segments = 6,
			color = ROLE_COLORS[model:GetAttribute("EnemyRole")] or Palette.UI.danger,
			stroke = 2,
		})
	end

	local threat = Ui.text(holder, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -2),
		Size = UDim2.fromOffset(20, 20),
		Text = "!",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		stroke = 2,
	})

	local badges = {}
	for index, effect in ipairs(EFFECTS) do
		local square = Ui.frame(holder, {
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(1, 2 + (index - 1) * 16, 0, 1),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = effect.color,
			Visible = false,
		})
		Ui.outline(square, 1)
		Ui.text(square, {
			Size = UDim2.fromScale(1, 1),
			Text = effect.letter,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Center,
			stroke = 1,
		})
		badges[index] = square
	end

	tracked[model] = {
		holder = holder,
		scale = scale,
		bar = bar,
		threat = threat,
		badges = badges,
		lastState = nil,
		alertUntil = 0,
		isBoss = isBoss,
	}
end

local function remove(model)
	local entry = tracked[model]
	if entry then
		entry.holder:Destroy()
		tracked[model] = nil
	end
end

local function consider(instance)
	if instance:IsA("Model") and instance:GetAttribute("EnemyMaxHealth") and not tracked[instance] then
		task.defer(function()
			if instance.Parent and not tracked[instance] then
				create(instance)
				instance.AncestryChanged:Connect(function(_, parent)
					if not parent then
						remove(instance)
					end
				end)
			end
		end)
	end
end

-- Значок угрозы: что показывать сейчас.
local function updateThreat(entry, model, state: string, now: number)
	if entry.lastState == "spawning" and MOVE_STATES[state] then
		entry.alertUntil = now + 0.6
	end
	entry.lastState = state
	local threat = entry.threat
	local telegraph = model:GetAttribute("EnemyTelegraph")
	if state == "windup" and telegraph == "parryable" then
		threat.Text = "!"
		threat.TextColor3 = V.H
		threat.Visible = math.floor(now * 12) % 2 == 0 -- 6 Гц
	elseif state == "windup" and (telegraph == "dodgeOnly" or telegraph == "zones") then
		threat.Text = "!!"
		threat.TextColor3 = V.X
		threat.Visible = math.floor(now * 16) % 2 == 0 -- 8 Гц
	elseif now < entry.alertUntil then
		threat.Text = "!"
		threat.TextColor3 = V.A
		threat.Visible = true
	else
		threat.Visible = false
	end
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local now = os.clock()
	local serverTime = Workspace:GetServerTimeNow()
	local guiScale = gui:FindFirstChild("Scale")
	local s = guiScale and guiScale.Scale or 1
	for model, entry in pairs(tracked) do
		local health = model:GetAttribute("EnemyHealth") or 0
		local maxHealth = math.max(model:GetAttribute("EnemyMaxHealth") or 1, 1)
		local state = model:GetAttribute("EnemyState") or "idle"
		local rig = EnemyVisualController.rigOf(model)
		local root = model.PrimaryPart
		local height = model:GetAttribute("EnemyHeight") or 3
		local top = nil
		if rig and rig.fx and rig.pos then
			top = EnemyFx.headTop(rig) + Vector3.new(0, 0.2, 0)
		elseif rig and rig.pos then
			top = rig.pos + Vector3.new(0, height + 0.8, 0)
		elseif root then
			top = root.Position + Vector3.new(0, height / 2 + 0.8, 0)
		end
		updateThreat(entry, model, state, now)
		local visible = false
		if top and health > 0 and state ~= "spawning" then
			local distance = (top - eye).Magnitude
			if distance < MAX_DISTANCE then
				local point, onScreen = camera:WorldToViewportPoint(top)
				if onScreen and point.Z > 0 then
					visible = true
					entry.holder.Position = UDim2.fromOffset(point.X / s, point.Y / s)
					entry.scale.Scale = math.clamp(18 / math.max(distance, 1), 0.6, 1.15)
					entry.holder.ZIndex = math.floor(1000 - distance)
				end
			end
		end
		entry.holder.Visible = visible
		if entry.bar then
			entry.bar.set(health / maxHealth, dt)
		end
		for index, effect in ipairs(EFFECTS) do
			local untilT = model:GetAttribute(effect.attribute) or 0
			entry.badges[index].Visible = not entry.isBoss and untilT > serverTime
		end
	end
end

function EnemyBarsController.start()
	gui = Ui.screen("KlinokEnemyBars", 1)
	Workspace.DescendantAdded:Connect(consider)
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		consider(descendant)
	end
	RunService.RenderStepped:Connect(update)
	print("[EnemyBarsController] полоски, значки угрозы и эффектов над врагами (экранные)")
end

return EnemyBarsController
