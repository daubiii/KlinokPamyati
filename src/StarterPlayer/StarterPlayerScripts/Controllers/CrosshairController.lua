--!nonstrict
-- CrosshairController (клиент): прицел в режиме боя.
--
-- Камера за плечом, корпус смотрит по взгляду камеры — центр экрана и есть
-- направление удара и выстрела посоха. Прицел:
--   * виден только в бою: камера зафиксирована, нет окон, сцен и свободного
--     курсора (в долине — бледнее, там некого бить);
--   * краснеет и сжимается, когда враг в досягаемости удара (у посоха —
--     на линии выстрела);
--   * при попадании — короткая засечка по диагоналям, при крите крупнее;
--   * на телефоне тусклее: там работает доводка удара (CombatController).
-- Враги собираются так же, как в EnemyBarsController (DescendantAdded + атрибуты),
-- проверка досягаемости — 10 раз в секунду.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientState = require(Shared.Util.ClientState)
local Net = require(Shared.Net.Net)

local Bus = require(script.Parent.Parent.Lib.Bus)
local CameraController = require(script.Parent.CameraController)
local TouchControls = require(script.Parent.TouchControls)

local CrosshairController = {}

local player = Players.LocalPlayer

local MELEE_REACH = 7.5 -- как у выпада CombatController (LUNGE_SEEK) с запасом
local STAFF_RANGE = 46
local STAFF_WIDTH = 3.2
local GAP_IDLE = 6
local GAP_TARGET = 4

local COLORS = {
	idle = Color3.fromRGB(244, 236, 218),
	target = Color3.fromRGB(240, 82, 64),
	hit = Color3.fromRGB(255, 220, 130),
	crit = Color3.fromRGB(255, 128, 56),
}

local enemies = {} -- [Model] = true
local ui = {}
local hudVisible = true
local targeted = false
local hitAt = -10
local hitCrit = false

local function track(instance: Instance)
	if enemies[instance] or not instance:IsA("Model") then
		return
	end
	if instance:GetAttribute("EnemyType") or instance:GetAttribute("EnemyMaxHealth") then
		enemies[instance] = true
		return
	end
	-- атрибуты могут прийти кадром позже
	task.defer(function()
		if instance.Parent and (instance:GetAttribute("EnemyType") or instance:GetAttribute("EnemyMaxHealth")) then
			enemies[instance] = true
		end
	end)
end

local function newBar(parent: Instance, width: number, height: number, rotation: number?): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(width, height)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundColor3 = COLORS.idle
	frame.BorderSizePixel = 0
	frame.Rotation = rotation or 0
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1
	stroke.Transparency = 0.35
	stroke.Parent = frame
	frame.Parent = parent
	return frame
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "KlinokCrosshair"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- центр экрана = центр камеры
	gui.DisplayOrder = 2
	gui.Enabled = false

	local holder = Instance.new("Frame")
	holder.Name = "Crosshair"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(64, 64)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	ui.gui = gui
	ui.dot = newBar(holder, 2, 2)
	ui.ticks = {
		{ frame = newBar(holder, 2, 6), dir = Vector2.new(0, -1) },
		{ frame = newBar(holder, 2, 6), dir = Vector2.new(0, 1) },
		{ frame = newBar(holder, 6, 2), dir = Vector2.new(-1, 0) },
		{ frame = newBar(holder, 6, 2), dir = Vector2.new(1, 0) },
	}
	ui.marks = {}
	for _, corner in ipairs({ Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) }) do
		local rotation = corner.X * corner.Y > 0 and 45 or -45
		local mark = newBar(holder, 2, 8, rotation)
		mark.Visible = false
		table.insert(ui.marks, { frame = mark, dir = corner })
	end
	ui.gap = GAP_IDLE
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function wantVisible(): boolean
	if player:GetAttribute("FilmPlaying") == true then
		return false -- идёт вступительный ролик: прицел не должен попасть в кадр
	end
	if not hudVisible or player:GetAttribute("Zone") == nil then
		return false
	end
	if ClientState.wantsCursor() or ClientState.isInputBlocked() then
		return false
	end
	local camera = CameraController.state()
	if not camera.locked or camera.cursorFree then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function targetInReach(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if not root or not camera then
		return false
	end
	local look = camera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.01 then
		return false
	end
	flatLook = flatLook.Unit
	local staff = player:GetAttribute("WeaponType") == "staff"
	for model in pairs(enemies) do
		if model.Parent == nil then
			enemies[model] = nil
		elseif (model:GetAttribute("EnemyHealth") or 0) > 0 then
			local part = model.PrimaryPart
			if part then
				local offset = part.Position - root.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local radius = model:GetAttribute("EnemyBodyRadius") or 1
				if staff then
					local along = flat:Dot(flatLook)
					if along > 0 and along < STAFF_RANGE and math.abs(offset.Y) < 10 then
						if (flat - flatLook * along).Magnitude < STAFF_WIDTH + radius then
							return true
						end
					end
				elseif flat.Magnitude > 0.1 and math.abs(offset.Y) < 8 then
					if flat.Magnitude - radius < MELEE_REACH and flatLook:Dot(flat.Unit) > 0.6 then
						return true
					end
				end
			end
		end
	end
	return false
end

local accumulator = 0
local function render(dt: number)
	local visible = wantVisible()
	if ui.gui.Enabled ~= visible then
		ui.gui.Enabled = visible
	end
	if not visible then
		return
	end

	accumulator += dt
	if accumulator >= 0.1 then
		accumulator = 0
		targeted = targetInReach()
	end

	local base = 0
	if TouchControls.isTouch() then
		base = 0.45
	elseif player:GetAttribute("Zone") == "Hub" then
		base = 0.5
	end
	local color = targeted and COLORS.target or COLORS.idle
	local goal = targeted and GAP_TARGET or GAP_IDLE
	ui.gap += (goal - ui.gap) * math.clamp(dt * 18, 0, 1)
	ui.dot.BackgroundColor3 = color
	ui.dot.BackgroundTransparency = base
	for _, tick in ipairs(ui.ticks) do
		local offset = tick.dir * (ui.gap + 3)
		tick.frame.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
		tick.frame.BackgroundColor3 = color
		tick.frame.BackgroundTransparency = base
	end

	-- Засечка попадания: вспыхивает и расходится за 0.22 с.
	local k = (os.clock() - hitAt) / 0.22
	local showMarks = k >= 0 and k < 1
	for _, mark in ipairs(ui.marks) do
		mark.frame.Visible = showMarks
		if showMarks then
			local spread = (hitCrit and 9 or 7) + k * 5
			mark.frame.Position = UDim2.new(0.5, mark.dir.X * spread, 0.5, mark.dir.Y * spread)
			mark.frame.Size = UDim2.fromOffset(2, hitCrit and 10 or 8)
			mark.frame.BackgroundColor3 = hitCrit and COLORS.crit or COLORS.hit
			mark.frame.BackgroundTransparency = k * k
		end
	end
end

function CrosshairController.start()
	build()

	Workspace.DescendantAdded:Connect(track)
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") then
			track(descendant)
		end
	end

	local attack = Net.get("AttackPerformed")
	if attack then
		attack.OnClientEvent:Connect(function(payload)
			if type(payload) == "table" and (payload.hits or 0) > 0 then
				hitAt = os.clock()
				hitCrit = payload.crit == true
			end
		end)
	end

	Bus.on("hud", function(data)
		hudVisible = not (type(data) == "table" and data.visible == false)
	end)

	RunService.RenderStepped:Connect(render)
	print("[CrosshairController] прицел в бою: цель в досягаемости, засечка попадания")
end

-- Внешний сигнал попадания (например, снаряд посоха или способность).
function CrosshairController.flashHit(crit: boolean?)
	hitAt = os.clock()
	hitCrit = crit == true
end

return CrosshairController
