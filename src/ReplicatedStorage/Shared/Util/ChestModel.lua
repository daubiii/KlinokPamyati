--!nonstrict
-- ChestModel
-- Модель сундука этажа v3 из блоков Config/ChestDesigns (10 дизайнов:
-- f<этаж>_common / f<этаж>_gold). Строится на клиенте: полёт сундука к герою
-- (ChestFlyController), сцена раскрытия (ChestRevealController), витрина в сумке.
--
--   local chest = ChestModel.build("f2_gold", { scale = 1, parent = workspace })
--   chest.model:PivotTo(CFrame.new(...))   -- опора — центр дна, лицо в +Z
--   ChestModel.setLid(chest, 60)           -- крышка, градусы (0 — закрыт)
--   ChestModel.lockPoint(chest)            -- мировая точка замка
--   chest.model:Destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChestDesigns = require(Shared.Config.ChestDesigns)

local ChestModel = {}

local materialCache = {}
local function material(code: string)
	local cached = materialCache[code]
	if cached then
		return cached
	end
	local name = ChestDesigns.Materials[code] or "SmoothPlastic"
	local ok, value = pcall(function()
		return Enum.Material[name]
	end)
	cached = ok and value or Enum.Material.SmoothPlastic
	materialCache[code] = cached
	return cached
end

function ChestModel.designId(floorId, grade: string): string
	local floor = math.clamp(math.floor(tonumber(floorId) or 1), 1, 5)
	return ("f%d_%s"):format(floor, grade == "gold" and "gold" or "common")
end

function ChestModel.design(designId: string)
	return ChestDesigns.Designs[designId] or ChestDesigns.Designs.f1_common
end

local function blockCFrame(entry, s: number): CFrame
	local cf = CFrame.new(entry[1] * s, entry[2] * s, entry[3] * s)
	if entry[9] then
		cf *= CFrame.Angles(math.rad(entry[9]), math.rad(entry[10] or 0), math.rad(entry[11] or 0))
	end
	return cf
end

local function makePart(parent, entry, s: number, index: number)
	local part = Instance.new("Part")
	part.Name = entry[8] == "N" and "Glow" or "Block"
	part.Size = Vector3.new(math.max(entry[4] * s, 0.02), math.max(entry[5] * s, 0.02), math.max(entry[6] * s, 0.02))
	part.Color = Color3.fromHex(entry[7])
	part.Material = material(entry[8])
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("Index", index)
	part.Parent = parent
	return part
end

-- opts: scale (1), parent, light (true — PointLight цвета design.glow), at (CFrame опоры)
function ChestModel.build(designId: string, opts)
	opts = opts or {}
	local design = ChestModel.design(designId)
	local s = opts.scale or 1
	local model = Instance.new("Model")
	model.Name = "Chest_" .. designId
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local handle = {
		model = model,
		root = root,
		design = design,
		designId = designId,
		scale = s,
		base = {},
		lid = {},
		glows = {},
		angle = 0,
	}
	for index, entry in ipairs(design.base) do
		local part = makePart(model, entry, s, index)
		local local_ = blockCFrame(entry, s)
		part.CFrame = local_
		table.insert(handle.base, { part = part, cf = local_ })
		if entry[8] == "N" then
			table.insert(handle.glows, part)
		end
	end
	local lidModel = Instance.new("Model")
	lidModel.Name = "Lid"
	lidModel.Parent = model
	for index, entry in ipairs(design.lid) do
		local part = makePart(lidModel, entry, s, index)
		local local_ = blockCFrame(entry, s)
		part.CFrame = local_
		table.insert(handle.lid, { part = part, cf = local_ })
		if entry[8] == "N" then
			table.insert(handle.glows, part)
		end
	end
	if opts.light ~= false then
		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Color = Color3.fromHex(design.glow)
		light.Brightness = 0
		light.Range = 10 * s
		light.Shadows = false
		light.Parent = root
		handle.light = light
	end
	model:SetAttribute("ChestDesign", designId)
	if opts.at then
		ChestModel.place(handle, opts.at)
	end
	if opts.parent then
		model.Parent = opts.parent
	end
	return handle
end

-- Поставить опору (центр дна) в мировой CFrame; scale — доп. множитель
-- размера (полёт: сундук уменьшается, не пересобираясь).
function ChestModel.place(handle, at: CFrame, scale: number?)
	local k = scale or 1
	handle.at = at
	handle.k = k
	local function placeList(list, lidRotation)
		for _, item in ipairs(list) do
			local cf = lidRotation and (lidRotation * item.cf) or item.cf
			if k ~= 1 then
				cf = CFrame.new(cf.Position * k) * cf.Rotation
			end
			item.part.CFrame = at * cf
		end
	end
	handle.root.CFrame = at
	placeList(handle.base, nil)
	placeList(handle.lid, ChestModel.lidRotation(handle, handle.angle))
	if k ~= 1 or handle.sized ~= k then
		-- размеры частей при уменьшении
		for _, list in ipairs({ handle.base, handle.lid }) do
			for _, item in ipairs(list) do
				local baseSize = item.size
				if not baseSize then
					baseSize = item.part.Size
					item.size = baseSize
				end
				item.part.Size = baseSize * k
			end
		end
		handle.sized = k
	end
end

function ChestModel.lidRotation(handle, angle: number): CFrame
	if not angle or angle == 0 then
		return CFrame.new()
	end
	local s = handle.scale
	local hinge = CFrame.new(0, handle.design.hinge[1] * s, handle.design.hinge[2] * s)
	return hinge * CFrame.Angles(-math.rad(angle), 0, 0) * hinge:Inverse()
end

-- Крышка: angle в градусах (0 — закрыт, design.lidMax — открыт до упора).
function ChestModel.setLid(handle, angle: number)
	handle.angle = math.clamp(angle, 0, handle.design.lidMax or 105)
	local at = handle.at or handle.root.CFrame
	local k = handle.k or 1
	local rotation = ChestModel.lidRotation(handle, handle.angle)
	for _, item in ipairs(handle.lid) do
		local cf = rotation * item.cf
		if k ~= 1 then
			cf = CFrame.new(cf.Position * k) * cf.Rotation
		end
		item.part.CFrame = at * cf
	end
end

-- Свечение неоновых деталей и света (0..1).
function ChestModel.setGlow(handle, amount: number)
	if handle.light then
		handle.light.Brightness = amount * 3
	end
	for _, part in ipairs(handle.glows) do
		part.Transparency = 0
		part:SetAttribute("Glow", amount)
	end
end

-- Прозрачность всей модели (проявление / исчезновение).
function ChestModel.setTransparency(handle, value: number)
	for _, list in ipairs({ handle.base, handle.lid }) do
		for _, item in ipairs(list) do
			item.part.Transparency = value
		end
	end
end

function ChestModel.lockPoint(handle): Vector3
	local lock = handle.design.lock
	local s = handle.scale * (handle.k or 1)
	local at = handle.at or handle.root.CFrame
	return at * Vector3.new(lock[1] * s, lock[2] * s, lock[3] * s)
end

-- Габариты (с крышкой) в студах при scale = 1.
function ChestModel.extent(designId: string): Vector3
	local design = ChestModel.design(designId)
	local top = 0
	for _, entry in ipairs(design.lid) do
		top = math.max(top, entry[2] + entry[5] / 2)
	end
	return Vector3.new(design.size[1], math.max(top, design.size[3]), design.size[2])
end

return ChestModel
