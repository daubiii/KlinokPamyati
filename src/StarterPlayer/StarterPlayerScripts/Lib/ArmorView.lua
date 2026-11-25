--!nonstrict
-- ArmorView (клиент) — 3D-витрина комплекта брони в окне.
--
-- Модель собирает сервер (Systems/ArmorPreviewService → ReplicatedStorage.
-- KlinokArmorPreviews.<setId>) тем же AppearanceService, что одевает героя, —
-- здесь она только клонируется во ViewportFrame и медленно покачивается,
-- чтобы был виден и перед, и плечо. Пока модели нет (сервер ещё собирает),
-- витрина пустая и ждёт до WAIT секунд.
--
-- ArmorView.new(parent, setId, props) → ViewportFrame

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Config.Palette)

local ArmorView = {}

local FOLDER = "KlinokArmorPreviews"
local WAIT = 8

function ArmorView.new(parent, setId: string?, props)
	local view = Instance.new("ViewportFrame")
	view.Name = "ArmorView"
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromOffset(200, 240)
	view.Ambient = Palette.Env.bone:Lerp(Color3.new(1, 1, 1), 0.35)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(0.8, -2, 1.4) -- свет спереди-сверху (модель смотрит в −Z)
	for key, value in pairs(props or {}) do
		view[key] = value
	end
	view.Parent = parent

	local camera = Instance.new("Camera")
	camera.FieldOfView = 26
	camera.Parent = view
	view.CurrentCamera = camera

	if type(setId) ~= "string" then
		return view
	end
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild(FOLDER, WAIT)
		local source = folder and folder:WaitForChild(setId, WAIT)
		if not source or not view.Parent then
			return
		end
		local model = source:Clone()
		model.Parent = view
		local cf, size = model:GetBoundingBox()
		local center = cf.Position
		local base = CFrame.new(-center) -- центр рамки — в начало координат
		model:PivotTo(base * model:GetPivot())
		local pivot0 = model:GetPivot()
		-- Камера спереди (модель смотрит в −Z): вся фигура в кадре с запасом.
		local aspect = math.max(view.AbsoluteSize.X, 1) / math.max(view.AbsoluteSize.Y, 1)
		local half = math.tan(math.rad(camera.FieldOfView / 2))
		local fitH = size.Y / 2 / half
		local fitW = math.max(size.X, size.Z) / 2 / (half * aspect)
		local distance = math.max(fitH, fitW) * 1.12 + size.Z / 2
		camera.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.04, -distance), Vector3.zero)
		local t = 0
		local connection
		connection = RunService.RenderStepped:Connect(function(dt)
			if not view.Parent or not model.Parent then
				connection:Disconnect()
				return
			end
			t += dt
			-- покачивание ±32° вокруг трёх четвертей — перед всегда читается
			local yaw = math.rad(-18) + math.sin(t * 0.7) * math.rad(32)
			model:PivotTo(CFrame.Angles(0, yaw, 0) * pivot0)
		end)
	end)
	return view
end

return ArmorView
