--!nonstrict
-- ChestVisual (клиент)
-- Сундук этажа v3 в интерфейсе:
--   ChestVisual.image(parent, designId, kind, props) — картинка из атласа
--     (Config/ChestArt + ChestAtlas; kind = "icon" | "art" | "open"); если атлас
--     ещё не загружен — живая 3D-модель во ViewportFrame (ChestModel);
--   ChestVisual.viewport(parent, designId, props, opts) — ViewportFrame с моделью
--     и камерой 3/4 (как у арта); opts.spin — медленно вращать.
--   ChestVisual.frame(handle, camera, opts) — поставить камеру так, чтобы сундук
--     целиком влез в кадр.
-- designId: "f<этаж>_common" | "f<этаж>_gold" (ChestModel.designId(floor, grade)).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChestArt = require(Shared.Config.ChestArt)
local ChestAtlas = require(Shared.Config.ChestAtlas)
local ChestModel = require(Shared.Util.ChestModel)

local ChestVisual = {}

ChestVisual.YAW = 32
ChestVisual.PITCH = 24
ChestVisual.FOV = 28

local function apply(object, props)
	if props then
		for key, value in pairs(props) do
			object[key] = value
		end
	end
	return object
end

-- Камера 3/4: сундук целиком в кадре. fill — доля кадра (0.86 по умолчанию).
function ChestVisual.frame(handle, camera, opts)
	opts = opts or {}
	local extent = ChestModel.extent(handle.designId) * handle.scale
	local center = Vector3.new(0, extent.Y * 0.5, 0)
	local yaw, pitch = math.rad(opts.yaw or ChestVisual.YAW), math.rad(opts.pitch or ChestVisual.PITCH)
	local dir = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
	local radius = extent.Magnitude * 0.5
	local fov = opts.fov or ChestVisual.FOV
	local distance = radius / math.tan(math.rad(fov) / 2) / (opts.fill or 0.86)
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(center + dir * distance + (opts.offset or Vector3.zero), center + (opts.offset or Vector3.zero))
	return camera.CFrame
end

function ChestVisual.viewport(parent, designId: string, props, opts)
	opts = opts or {}
	local view = Instance.new("ViewportFrame")
	view.Name = "ChestView"
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(150, 140, 130)
	view.LightColor = Color3.fromRGB(255, 244, 228)
	view.LightDirection = Vector3.new(0.35, -0.85, -0.45)
	apply(view, props)
	view.Parent = parent
	local camera = Instance.new("Camera")
	camera.Parent = view
	view.CurrentCamera = camera
	local handle = ChestModel.build(designId, { light = false })
	if opts.lid then
		ChestModel.setLid(handle, opts.lid)
	end
	handle.model.Parent = view
	ChestVisual.frame(handle, camera, opts)
	local spin
	if opts.spin then
		local started = os.clock()
		spin = RunService.RenderStepped:Connect(function()
			if not view.Parent then
				spin:Disconnect()
				return
			end
			local a = math.sin((os.clock() - started) * 0.8) * 0.35
			ChestModel.place(handle, CFrame.Angles(0, a, 0))
		end)
	end
	return view, handle, camera
end

-- Картинка сундука: атлас (если загружен) или 3D-модель.
-- kind: "icon" (32×32) | "art" (112×96) | "open" (112×96, крышка откинута).
function ChestVisual.image(parent, designId: string, kind: string?, props, opts)
	local kindName: string = kind or "icon"
	local piece = ChestAtlas.Pieces[designId .. "_" .. kindName]
	if ChestArt.has() and piece then
		local label = Instance.new("ImageLabel")
		label.Name = "ChestArt"
		label.BackgroundTransparency = 1
		label.Image = ChestArt.Atlas
		label.ImageRectOffset = Vector2.new(piece.x, piece.y)
		label.ImageRectSize = Vector2.new(piece.w, piece.h)
		label.ResampleMode = Enum.ResamplerMode.Pixelated
		label.ScaleType = Enum.ScaleType.Fit
		label.Size = UDim2.fromOffset(piece.w * ChestArt.Scale, piece.h * ChestArt.Scale)
		apply(label, props)
		label.Parent = parent
		return label
	end
	opts = opts or {}
	local view = ChestVisual.viewport(parent, designId, props, {
		lid = kindName == "open" and 100 or nil,
		spin = opts.spin,
		fill = kindName == "icon" and 0.98 or 0.9,
	})
	return view
end

return ChestVisual
