--!nonstrict
-- FloorEndVoteController (клиент)
-- Конец пати-забега (решение владельца, 14.11):
--   * смерть в отряде — наблюдение за выжившим: своя камера следует за ним
--     (камера того, кто играет, не трогается), кнопка «ВЕРНУТЬСЯ В ЛОББИ»;
--     пока наблюдатель досматривает, ему идут те же награды этажа
--     (вернулся раньше конца — финального сундука нет, решает сервер);
--   * этаж пройден/провален в отряде — голосование «играть снова / в лобби»:
--     побеждает большинство, поровну — всех в лобби (сервер).
-- Логика вся на сервере (FloorService); здесь только камера и окна.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local Lib = script.Parent.Parent.Lib
local PixelUi = require(Lib.PixelUi)
local Ui = require(Lib.Ui)
local UiSound = require(Lib.UiSound)

local FloorEvent = Net.get("FloorEvent")
local FloorVote = Net.get("FloorVote")

local CameraController
do
	local ok, module = pcall(function()
		return require(script.Parent.CameraController)
	end)
	if ok then
		CameraController = module
	end
end

local FloorEndVote = {}

-- Вся сборка — в start(): модуль требует Bootstrap.
function FloorEndVote.start()

-- ===== экран =====
local gui, root = PixelUi.screen("KlinokFloorEnd", 60)
local canvas = PixelUi.canvas(root)
canvas.Visible = false

local P = Ui.colors

-- Плашка наблюдения: кто мы смотрим и выход в лобби.
local spectateFrame = Instance.new("Frame")
spectateFrame.Name = "Spectate"
spectateFrame.AnchorPoint = Vector2.new(0.5, 1)
spectateFrame.Position = UDim2.new(0.5, 0, 1, -24)
spectateFrame.Size = UDim2.fromOffset(560, 96)
spectateFrame.BackgroundColor3 = P.panel
spectateFrame.BackgroundTransparency = 0.08
spectateFrame.BorderSizePixel = 0
spectateFrame.ZIndex = 5
spectateFrame.Parent = canvas
do
	local stroke = Instance.new("UIStroke")
	stroke.Color = P.frame
	stroke.Thickness = 3
	stroke.Parent = spectateFrame
end

local spectateLabel = PixelUi.text(spectateFrame, "НАБЛЮДЕНИЕ", 16, P.accent, {
	Position = UDim2.fromOffset(18, 12),
	Size = UDim2.fromOffset(320, 24),
	ZIndex = 6,
})
PixelUi.text(spectateFrame, "досматривай бой — награды идут, вышел раньше — без финального сундука", 12, P.textMuted, {
	Name = "Hint",
	Position = UDim2.fromOffset(18, 40),
	Size = UDim2.fromOffset(330, 44),
	TextWrapped = true,
	ZIndex = 6,
})
local leaveButton = PixelUi.button(spectateFrame, "red", UDim2.new(1, -206, 0, 18), UDim2.fromOffset(188, 60), "ВЕРНУТЬСЯ В ЛОББИ", nil, {
	z = 7,
	textSize = 14,
})

-- Голосование конца забега.
local voteFrame = Instance.new("Frame")
voteFrame.Name = "Vote"
voteFrame.AnchorPoint = Vector2.new(0.5, 0.5)
voteFrame.Position = UDim2.new(0.5, 0, 0.4, 0)
voteFrame.Size = UDim2.fromOffset(640, 220)
voteFrame.BackgroundColor3 = P.panel
voteFrame.BackgroundTransparency = 0.06
voteFrame.BorderSizePixel = 0
voteFrame.ZIndex = 8
voteFrame.Parent = canvas
do
	local stroke = Instance.new("UIStroke")
	stroke.Color = P.accent
	stroke.Thickness = 3
	stroke.Parent = voteFrame
end
PixelUi.header(voteFrame, "ЭТАЖ ПРОЙДЕН", 10, P.gold)
local voteStatus = PixelUi.text(voteFrame, "", 15, P.textMuted, {
	Name = "Status",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 56),
	Size = UDim2.fromOffset(600, 24),
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 9,
})
local againButton = PixelUi.button(voteFrame, "gold", UDim2.new(0.5, -220, 0, 96), UDim2.fromOffset(200, 64), "ИГРАТЬ СНОВА", nil, {
	z = 9,
	textSize = 16,
})
local lobbyButton = PixelUi.button(voteFrame, "wood", UDim2.new(0.5, 20, 0, 96), UDim2.fromOffset(200, 64), "В ЛОББИ", nil, {
	z = 9,
	textSize = 16,
})

-- ===== состояние =====
local spectateTargetId = nil
local spectateCFrame = nil
local voteDeadline = 0
local voteTotal = 0
local myVote = nil

local function releaseCamera()
	spectateTargetId = nil
	spectateCFrame = nil
	if CameraController and CameraController.release then
		pcall(CameraController.release, 0.6)
	end
end

local function hideAll()
	canvas.Visible = false
	releaseCamera()
	myVote = nil
end

-- Камера наблюдателя: своя, следует за живым союзником.
local function spectateCamera()
	if not spectateTargetId then
		return nil
	end
	local target = Players:GetPlayerByUserId(spectateTargetId)
	local character = target and target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and humanoid and humanoid.Health > 0) then
		return spectateCFrame -- цель умерла/ушла: держим последний кадр
	end
	local look = root.Position + Vector3.new(0, 2, 0)
	local flat = root.CFrame.LookVector
	local flatDir = Vector3.new(flat.X, 0, flat.Z)
	if flatDir.Magnitude < 0.05 then
		flatDir = Vector3.new(0, 0, -1)
	else
		flatDir = flatDir.Unit
	end
	local position = look - flatDir * 11 + Vector3.new(0, 6, 0)
	spectateCFrame = CFrame.lookAt(position, look)
	return spectateCFrame
end

leaveButton.hit.Activated:Connect(function()
	canvas.Visible = false
	releaseCamera()
	UiSound.play("paper_slide", { volume = 0.5 })
	pcall(function()
		Net.get("RequestLeaveFloor"):InvokeServer()
	end)
end)

againButton.hit.Activated:Connect(function()
	if myVote then
		return
	end
	myVote = "again"
	FloorVote:FireServer("again")
	UiSound.play("ui_click")
end)

lobbyButton.hit.Activated:Connect(function()
	if myVote then
		return
	end
	myVote = "lobby"
	FloorVote:FireServer("lobby")
	UiSound.play("ui_click")
end)

-- Тик: таймер голосования и подстраховка камеры наблюдателя.
local clock = 0
game:GetService("RunService").Heartbeat:Connect(function(dt)
	clock += dt
	if clock < 0.25 then
		return
	end
	clock = 0
	if canvas.Visible and voteDeadline > 0 then
		local left = math.max(0, math.ceil(voteDeadline - workspace:GetServerTimeNow()))
		voteStatus.Text = ("Голосуют: %d из %d · ещё %d с · поровну — всех в лобби"):format(math.min(voteTotal, voteTotal), voteTotal, left)
	end
	if spectateTargetId then
		-- Цель пропала (вышел с сервера) — отпускаем камеру.
		local target = Players:GetPlayerByUserId(spectateTargetId)
		if not target then
			spectateTargetId = nil
			spectateCFrame = nil
		end
	end
end)

FloorEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	if kind == "spectate" then
		spectateTargetId = payload.target
		spectateCFrame = nil
		canvas.Visible = true
		spectateFrame.Visible = true
		voteFrame.Visible = false
		spectateLabel.Text = "НАБЛЮДЕНИЕ · " .. tostring(payload.name or "союзник")
		if CameraController and CameraController.setOverride then
			pcall(CameraController.setOverride, spectateCamera)
		end
	elseif kind == "endVote" then
		canvas.Visible = true
		spectateFrame.Visible = spectateTargetId ~= nil
		voteFrame.Visible = true
		voteDeadline = payload.deadline or 0
		voteTotal = payload.total or 0
		myVote = payload.mine or nil
		PixelUi.header(voteFrame, (payload.voteKind == "fail") and "ОТРЯД ПАЛ" or "ЭТАЖ ПРОЙДЕН", 10, (payload.voteKind == "fail") and P.danger or P.gold)
		voteStatus.Text = ("Голосуют: %d из %d"):format(payload.votes or 0, voteTotal)
	elseif kind == "endVoteResult" then
		voteFrame.Visible = false
		releaseCamera()
		spectateFrame.Visible = false
		canvas.Visible = false
		if payload.result == "again" then
			-- newRun придёт отдельным событием — там камера и окна гаснут.
		else
			UiSound.play("paper_slide", { volume = 0.5 })
		end
	elseif kind == "newRun" then
		hideAll()
	end
end)
end

return FloorEndVote
