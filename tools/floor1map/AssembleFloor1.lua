--[[
	AssembleFloor1 — сборка карты этажа 1 v2 из импортированных OBJ.
	Запускать в Studio, в Command Bar (режим Edit, НЕ во время Play).
	Скрипт запускает сам разработчик, не агент и не игра: один раз после импорта.

	До запуска:
	1. Workspace.Floor1Map — модель из Floor1Map.rbxmx (правый клик по Workspace →
	   Insert from File…). В ней на каждую зону папки Collision / Lights / Dynamic / Visual.
	2. ReplicatedStorage.Shared.Config.FloorMapData — модуль (FloorMapData.lua из пакета кода).
	3. glb: tools/floor1map/out/floor1v2_a/b/c.glb (floor_obj_to_glb.py) импортированы через
	   Import 3D как есть — модели floor1v2_a, floor1v2_b, floor1v2_c в Workspace. Или (старый путь)
	   каждый <зона>_vis.obj (17 файлов) импортирован через 3D Importer (File → Import 3D)
	   в Workspace как модель с именем "<зона>_vis":
	     • галочку «Import as single mesh / Merge meshes» НЕ ставить — нужна MeshPart на объект OBJ;
	     • текстуру floor_palette.png импортер подхватит из .mtl сам (файлы лежат рядом).
	   Имена MeshPart = имена объектов OBJ (intro_m1, intro_g3…).

	Что делает: каждую MeshPart ставит на место (центр и размер из FloorMapData — импортер
	может сдвинуть модель), переносит в Floor1Map.<зона>.Visual, отключает коллизии и лучи
	(пол и стены — невидимые детали Collision), свечение делает Neon нужного цвета.
	Пустые модели "<зона>_vis" удаляет. Повторный запуск безопасен.
]]
local RS = game:GetService("ReplicatedStorage")
local DATA = require(RS.Shared.Config.FloorMapData)
local map = workspace:FindFirstChild("Floor1Map")
assert(map, "[AssembleFloor1] нет Workspace.Floor1Map — вставьте Floor1Map.rbxmx")

local function findMesh(root: Instance, name: string): MeshPart?
	local fallback = nil
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("MeshPart") then
			if d.Name == name then
				return d
			end
			-- Импортер иногда дописывает материал: "intro_m1_palette".
			if not fallback and string.sub(d.Name, 1, #name + 1) == name .. "_" and not string.match(string.sub(d.Name, #name + 2), "^%d") then
				fallback = d
			end
		end
	end
	return fallback
end

local function folderOf(parent: Instance, name: string): Instance
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

-- glb из tools/floor1map/floor_obj_to_glb.py импортируется моделями floor1v2_a/b/c
-- (узел = объект OBJ); OBJ напрямую — моделью <зона>_vis (импорт сливает её в один меш).
local glbModels = {}
for _, m in ipairs(workspace:GetChildren()) do
	if string.match(m.Name, "^floor1v2_%a$") then
		table.insert(glbModels, m)
	end
end
local function findAny(name: string): MeshPart?
	for _, m in ipairs(glbModels) do
		local mp = findMesh(m, name)
		if mp then
			return mp
		end
	end
	return nil
end

local placed, missing, total = 0, 0, 0
for zoneId, objects in pairs(DATA.zones) do
	local src = workspace:FindFirstChild(zoneId .. "_vis")
	local zoneFolder = folderOf(map, zoneId)
	local visual = folderOf(zoneFolder, "Visual")
	local wanted = {}
	for _, o in ipairs(objects) do
		wanted[o.name] = true
	end
	-- старые слитые меши (<зона>_vis целиком) — убрать
	for _, c in ipairs(visual:GetChildren()) do
		if not wanted[c.Name] then
			c:Destroy()
		end
	end
	for _, o in ipairs(objects) do
		total += 1
		local mp = findAny(o.name) or (src and findMesh(src, o.name)) or visual:FindFirstChild(o.name)
		if not mp or not mp:IsA("MeshPart") then
			missing += 1
			warn(("[AssembleFloor1] %s: нет MeshPart %s"):format(zoneId, o.name))
			continue
		end
		local old = visual:FindFirstChild(o.name)
		if old and old ~= mp then
			old:Destroy()
		end
		mp.Name = o.name
		mp.Anchored = true
		mp.CanCollide = false
		mp.CanQuery = false
		mp.CanTouch = false
		mp.Massless = true
		mp.Size = o.size
		mp.CFrame = CFrame.new(o.center)
		pcall(function()
			mp.CollisionFidelity = Enum.CollisionFidelity.Box
		end)
		mp.RenderFidelity = Enum.RenderFidelity.Automatic
		for _, c in ipairs(mp:GetChildren()) do
			if c:IsA("JointInstance") or c:IsA("WeldConstraint") then
				c:Destroy()
			end
		end
		if o.role == "glow" then
			mp.Material = Enum.Material.Neon
			mp.Color = o.color or Color3.fromRGB(255, 179, 71)
			mp.TextureID = ""
			mp.CastShadow = false
			mp.Transparency = 0
		elseif o.role == "glass" then
			mp.Material = Enum.Material.Glass
			mp.TextureID = ""
			mp.Color = o.color or Color3.fromRGB(111, 227, 255)
			mp.Transparency = 0.25
			mp.CastShadow = false
		else
			mp.Material = Enum.Material.SmoothPlastic
			mp.Color = Color3.new(1, 1, 1)
			if DATA.paletteTexture ~= "" then
				mp.TextureID = DATA.paletteTexture
			end
			mp.CastShadow = true
			mp.Transparency = 0
		end
		mp.Reflectance = 0
		mp:SetAttribute("Role", o.role)
		mp.Parent = visual
		placed += 1
	end
	if src and #src:GetDescendants() == 0 then
		src:Destroy()
	elseif src then
		local left = 0
		for _, d in ipairs(src:GetDescendants()) do
			if d:IsA("BasePart") then
				left += 1
			end
		end
		if left == 0 then
			src:Destroy()
		else
			warn(("[AssembleFloor1] в %s_vis осталось %d деталей (не из данных) — проверьте вручную"):format(zoneId, left))
		end
	end
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
		warn(("[AssembleFloor1] в %s осталось %d деталей (не из данных) — проверьте вручную"):format(m.Name, left))
	end
end

-- Пол и стены карты — только невидимые Collision; Visual в лучи не попадает.
for _, d in ipairs(map:GetDescendants()) do
	if d:IsA("BasePart") and d.Parent and d.Parent.Name == "Collision" then
		d.Transparency = 1
		d.CanCollide = true
		d.CanQuery = true
		d.Anchored = true
	end
end

print(("[AssembleFloor1] готово: %d из %d MeshPart на месте, не найдено %d"):format(placed, total, missing))
