--[[
	AssembleFloor45 — сборка карт этажей 4 «Литейные» и 5 «Зал хроник» из glb.
	Запускать в Studio, в Command Bar (режим Edit, НЕ во время Play). Повторный
	запуск безопасен: карта пересобирается из данных, лишнее удаляется.

	До запуска:
	1. В ReplicatedStorage.Shared.Config лежат модули Floor4MapData / Floor5MapData
	   (и Floor4Points / Floor5Points, Floor4Breakables / Floor5Breakables) — их
	   ставит Rojo из пакета (src/ReplicatedStorage/Shared/Config).
	2. File → Import 3D: floor4_a.glb, floor4_b.glb, floor4_c.glb (и floor5_*.glb)
	   как есть, без «Merge»/«Unify». В Workspace появятся модели floor4_a … floor5_c.
	   Палитра (текстура) встроена в glb.

	Что делает (для каждого этажа, у которого нашлись данные):
	• Workspace.Floor<N>Map / <зона> / { Visual, Collision, Lights, Dynamic };
	• Visual — MeshPart из импорта (имена f<N>_<зона>_[mgw]<k>), центр и размер
	  из данных; без коллизий и лучей; glow → Neon нужного цвета, glass → Glass;
	• Collision — невидимые Part (пол, стены, ступени, пандусы), по ним ходят
	  игроки и бегают лучи врагов (FloorGeo);
	• Lights — невидимые опоры с PointLight (цвет, дальность, яркость, тени);
	• Dynamic — решётки, внутренняя решётка клети, створки ворот: Model с
	  невидимым коллайдером (PrimaryPart) и мешами f<N>dyn_<имя>;
	• Signs — надписи (SurfaceGui) у входа и над воротами.
	Пустые модели импорта удаляются. В конце — Ctrl+S.

	Что можно поменять: FLOORS (какие этажи собирать).
]]
local FLOORS = { 4, 5 }

local RS = game:GetService("ReplicatedStorage")
local Config = RS:WaitForChild("Shared"):WaitForChild("Config")

local function folderOf(parent: Instance, name: string, class: string?): Instance
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new(class or "Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function clear(f: Instance)
	for _, c in ipairs(f:GetChildren()) do
		c:Destroy()
	end
end

-- Импорт иногда дописывает к имени хвост («f4_adit_m1.001», «…_palette»).
-- Совпадение — точное имя или имя + не-буквенно-цифровой символ.
local function finder(index)
	return function(name: string)
		local exact = index[name]
		if exact then
			return exact
		end
		for key, part in pairs(index) do
			-- хвост, который дописывает импорт: ".001", " (1)", "_001"
			local tail = #key > #name and string.sub(key, 1, #name) == name and string.sub(key, #name + 1)
			if tail and (string.match(tail, "^%.%d+$") or string.match(tail, "^%s*%(%d+%)$") or string.match(tail, "^_%d%d%d$")) then
				return part
			end
		end
		return nil
	end
end

local function prepMesh(mp: BasePart)
	for _, c in ipairs(mp:GetChildren()) do
		if c:IsA("JointInstance") or c:IsA("WeldConstraint") then
			c:Destroy()
		end
	end
	mp.Anchored = true
	mp.CanCollide = false
	mp.CanQuery = false
	mp.CanTouch = false
	mp.Massless = true
	mp.Reflectance = 0
	pcall(function()
		mp.CollisionFidelity = Enum.CollisionFidelity.Box
	end)
	pcall(function()
		mp.RenderFidelity = Enum.RenderFidelity.Automatic
	end)
end

local function styleMesh(mp: BasePart, o)
	if o.role == "glow" then
		mp.Material = Enum.Material.Neon
		mp.Color = o.color or Color3.fromRGB(255, 200, 87)
		if mp:IsA("MeshPart") then
			mp.TextureID = ""
		end
		mp.CastShadow = false
		mp.Transparency = 0
	elseif o.role == "glass" then
		mp.Material = Enum.Material.Glass
		if mp:IsA("MeshPart") then
			mp.TextureID = ""
		end
		mp.Color = o.color or Color3.fromRGB(184, 227, 255)
		mp.Transparency = math.clamp(o.transparency or 0.35, 0.1, 0.8)
		mp.CastShadow = false
	else
		mp.Material = Enum.Material.SmoothPlastic
		mp.Color = Color3.new(1, 1, 1) -- цвет даёт текстура-палитра из glb
		mp.CastShadow = true
		mp.Transparency = 0
	end
	mp:SetAttribute("Role", o.role)
end

local function colPart(parent: Instance, c, index: number)
	local p = Instance.new("Part")
	p.Name = "C" .. index
	p.Anchored = true
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(c[4], c[5], c[6])
	if #c >= 15 then
		p.CFrame = CFrame.new(c[1], c[2], c[3], c[7], c[8], c[9], c[10], c[11], c[12], c[13], c[14], c[15])
	else
		p.CFrame = CFrame.new(c[1], c[2], c[3])
	end
	p.Parent = parent
	return p
end

local function lightPart(parent: Instance, l, index: number)
	local p = Instance.new("Part")
	p.Name = "L" .. index
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.4, 0.4, 0.4)
	p.CFrame = CFrame.new(l[1], l[2], l[3])
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex(l[4])
	light.Range = l[5]
	light.Brightness = l[6]
	light.Shadows = l[7] == true
	light.Parent = p
	p.Parent = parent
end

local function sign(parent: Instance, t)
	local board = Instance.new("Part")
	board.Name = t.name
	board.Anchored = true
	board.CanCollide = false
	board.CanQuery = false
	board.CanTouch = false
	board.CastShadow = false
	board.Transparency = 1
	board.Size = t.size
	-- ry — поворот по Y (рад); текст на задней грани: смотрит на игрока,
	-- идущего по этажу к −Z.
	board.CFrame = CFrame.new(t.center) * CFrame.Angles(0, t.ry or 0, 0)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = board
	local main = Instance.new("TextLabel")
	main.BackgroundTransparency = 1
	main.Size = UDim2.fromScale(1, (t.sub and t.sub ~= "") and 0.68 or 1)
	main.Font = Enum.Font.Arcade
	main.TextScaled = true
	main.Text = t.text
	main.TextColor3 = t.color or Color3.new(1, 1, 1)
	main.TextStrokeTransparency = 0.4
	main.Parent = gui
	if t.sub and t.sub ~= "" then
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromScale(0, 0.68)
		sub.Size = UDim2.fromScale(1, 0.32)
		sub.Font = Enum.Font.SourceSansItalic
		sub.TextScaled = true
		sub.Text = t.sub
		sub.TextColor3 = (t.color or Color3.new(1, 1, 1)):Lerp(Color3.new(1, 1, 1), 0.35)
		sub.TextTransparency = 0.15
		sub.Parent = gui
	end
	board.Parent = parent
end

local report = {}

for _, floorId in ipairs(FLOORS) do
	local module = Config:FindFirstChild("Floor" .. floorId .. "MapData")
	if not module then
		warn(("[AssembleFloor45] нет Config.Floor%dMapData — пропуск этажа %d"):format(floorId, floorId))
		continue
	end
	local DATA = require(module)
	local prefix = "f" .. floorId
	local mapName = "Floor" .. floorId .. "Map"
	local map = workspace:FindFirstChild(mapName)
	if not map then
		map = Instance.new("Model")
		map.Name = mapName
		map.Parent = workspace
	end

	-- Индекс MeshPart импорта floor<N>_a/b/c (и уже собранной карты — повтор).
	local glbModels, index = {}, {}
	for _, m in ipairs(workspace:GetChildren()) do
		if string.match(m.Name, "^floor" .. floorId .. "_%a") then
			table.insert(glbModels, m)
		end
	end
	for _, container in ipairs({ map, table.unpack(glbModels) }) do
		for _, d in ipairs(container:GetDescendants()) do
			if d:IsA("MeshPart") and string.sub(d.Name, 1, #prefix) == prefix and not index[d.Name] then
				index[d.Name] = d
			end
		end
	end
	local find = finder(index)
	if #glbModels == 0 then
		warn(("[AssembleFloor45] этаж %d: в Workspace нет моделей floor%d_a/b/c — меши берутся из уже собранной карты"):format(floorId, floorId))
	end

	local placed, missing, total, cols, lights, dyns = 0, 0, 0, 0, 0, 0
	local zoneIds = {}
	for zoneId in pairs(DATA.zones) do
		zoneIds[zoneId] = true
	end
	for zoneId in pairs(DATA.collision or {}) do
		zoneIds[zoneId] = true
	end

	for zoneId in pairs(zoneIds) do
		local zoneFolder = folderOf(map, zoneId)
		local visual = folderOf(zoneFolder, "Visual")
		local collision = folderOf(zoneFolder, "Collision")
		local lightsFolder = folderOf(zoneFolder, "Lights")
		local dynamic = folderOf(zoneFolder, "Dynamic")

		-- Visual
		local wanted = {}
		for _, o in ipairs(DATA.zones[zoneId] or {}) do
			wanted[o.name] = true
		end
		for _, o in ipairs(DATA.zones[zoneId] or {}) do
			total += 1
			local mp = find(o.name)
			if not mp then
				missing += 1
				warn(("[AssembleFloor45] %s/%s: нет MeshPart %s"):format(mapName, zoneId, o.name))
				continue
			end
			prepMesh(mp)
			mp.Name = o.name
			mp.Size = o.size
			mp.CFrame = CFrame.new(o.center)
			styleMesh(mp, o)
			mp.Parent = visual
			placed += 1
		end
		for _, c in ipairs(visual:GetChildren()) do
			if not wanted[c.Name] then
				c:Destroy()
			end
		end

		-- Collision
		clear(collision)
		for i, c in ipairs((DATA.collision or {})[zoneId] or {}) do
			colPart(collision, c, i)
			cols += 1
		end

		-- Lights
		clear(lightsFolder)
		for i, l in ipairs((DATA.lights or {})[zoneId] or {}) do
			lightPart(lightsFolder, l, i)
			lights += 1
		end

		-- Dynamic: меши сначала спасаем из старых моделей (повторный запуск).
		for _, old in ipairs(dynamic:GetChildren()) do
			for _, d in ipairs(old:GetDescendants()) do
				if d:IsA("MeshPart") then
					d.Parent = map
					index[d.Name] = d
				end
			end
			old:Destroy()
		end
		for _, dyn in ipairs((DATA.dynamic or {})[zoneId] or {}) do
			local model = Instance.new("Model")
			model.Name = dyn.name
			model:SetAttribute("Kind", dyn.kind)
			local col = Instance.new("Part")
			col.Name = "Collider"
			col.Anchored = true
			col.CanCollide = true
			col.CanQuery = true
			col.CanTouch = false
			col.CastShadow = false
			col.Transparency = 1
			col.Size = dyn.collider.size
			col.CFrame = CFrame.new(dyn.collider.center)
			col.Parent = model
			model.PrimaryPart = col
			for _, o in ipairs(dyn.parts or {}) do
				total += 1
				local mp = find(o.name)
				if not mp then
					missing += 1
					warn(("[AssembleFloor45] %s/%s: нет MeshPart %s (%s)"):format(mapName, zoneId, o.name, dyn.name))
					continue
				end
				prepMesh(mp)
				mp.Name = o.name
				mp.Size = o.size
				mp.CFrame = CFrame.new(o.center)
				styleMesh(mp, o)
				mp.Parent = model
				placed += 1
			end
			model.Parent = dynamic
			dyns += 1
		end
	end
	-- Остатки спасённых мешей, которых нет в данных.
	for _, c in ipairs(map:GetChildren()) do
		if c:IsA("MeshPart") then
			c:Destroy()
		end
	end

	-- Надписи
	local signs = folderOf(map, "Signs")
	clear(signs)
	for _, t in ipairs(DATA.texts or {}) do
		sign(signs, t)
	end

	for _, m in ipairs(glbModels) do
		local left = 0
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				left += 1
			end
		end
		if left == 0 then
			m:Destroy()
		else
			warn(("[AssembleFloor45] в %s осталось %d деталей (не из данных) — проверьте вручную"):format(m.Name, left))
		end
	end
	table.insert(report, ("этаж %d: мешей %d/%d (нет %d), коллизий %d, света %d, динамики %d"):format(floorId, placed, total, missing, cols, lights, dyns))
end

pcall(function()
	game:GetService("ChangeHistoryService"):SetWaypoint("AssembleFloor45")
end)
local msg = "[AssembleFloor45] " .. table.concat(report, "; ") .. ". Ctrl+S."
print(msg)
return msg
