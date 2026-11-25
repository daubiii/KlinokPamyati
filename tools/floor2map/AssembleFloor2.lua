--[[
	AssembleFloor2 — сборка карты этажа 2 «Затопленные сады» из импортированных glb.
	Запускать в Studio, в Command Bar (режим Edit, НЕ во время Play).
	Скрипт запускает сам разработчик: один раз после импорта (повторный запуск безопасен).

	До запуска:
	1. Workspace.Floor2Map — модель из Floor2Map.rbxmx (правый клик по Workspace →
	   Insert from File…). В ней на каждую зону папки Collision / Lights / Dynamic / Visual.
	2. ReplicatedStorage.Shared.Config.Floor2MapData — модуль (Floor2MapData.lua из пакета).
	3. floor2_a.glb, floor2_b.glb, floor2_c.glb импортированы через File → Import 3D как есть
	   (модели floor2_a, floor2_b, floor2_c в Workspace). Палитра встроена в glb.

	Что делает: каждую MeshPart ставит на место (центр и размер из Floor2MapData — импортер
	может сдвинуть модель), переносит в Floor2Map.<зона>.Visual, отключает коллизии и лучи
	(пол и стены — невидимые детали Collision), свечение делает Neon нужного цвета,
	воду — стеклом с прозрачностью. Пустые модели floor2_a/b/c удаляет.
]]
local RS = game:GetService("ReplicatedStorage")
local DATA = require(RS.Shared.Config.Floor2MapData)
local map = workspace:FindFirstChild("Floor2Map")
assert(map, "[AssembleFloor2] нет Workspace.Floor2Map — вставьте Floor2Map.rbxmx")

local function folderOf(parent: Instance, name: string): Instance
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

-- Индекс MeshPart всех импортированных моделей: имя → деталь. Импортер иногда
-- дописывает материал («f2_pier_m1_palette») — берём и такие.
local glbModels = {}
local index = {}
for _, m in ipairs(workspace:GetChildren()) do
	if string.match(m.Name, "^floor2_%a$") then
		table.insert(glbModels, m)
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("MeshPart") then
				local name = string.match(d.Name, "^(f2_[%w]+_[mgw]%d+)")
				if name and not index[name] then
					index[name] = d
				end
			end
		end
	end
end
if #glbModels == 0 then
	warn("[AssembleFloor2] в Workspace нет моделей floor2_a/b/c — сначала Import 3D трёх glb")
end

local placed, missing, total = 0, 0, 0
for zoneId, objects in pairs(DATA.zones) do
	local zoneFolder = folderOf(map, zoneId)
	local visual = folderOf(zoneFolder, "Visual")
	local wanted = {}
	for _, o in ipairs(objects) do
		wanted[o.name] = true
	end
	for _, c in ipairs(visual:GetChildren()) do
		if not wanted[c.Name] then
			c:Destroy()
		end
	end
	for _, o in ipairs(objects) do
		total += 1
		local mp = index[o.name] or visual:FindFirstChild(o.name)
		if not mp or not mp:IsA("MeshPart") then
			missing += 1
			warn(("[AssembleFloor2] %s: нет MeshPart %s"):format(zoneId, o.name))
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
			mp.Color = o.color or Color3.fromRGB(95, 208, 192)
			mp.TextureID = ""
			mp.CastShadow = false
			mp.Transparency = 0
		elseif o.role == "glass" then
			-- Вода и стекло оранжереи: цвет и прозрачность из кита.
			mp.Material = Enum.Material.Glass
			mp.TextureID = ""
			mp.Color = o.color or Color3.fromRGB(18, 66, 62)
			mp.Transparency = math.clamp(o.transparency or 0.25, 0.1, 0.8)
			mp.CastShadow = false
		else
			mp.Material = Enum.Material.SmoothPlastic
			mp.Color = Color3.new(1, 1, 1) -- цвет даёт текстура-палитра из glb
			mp.CastShadow = true
			mp.Transparency = 0
		end
		mp.Reflectance = 0
		mp:SetAttribute("Role", o.role)
		mp.Parent = visual
		placed += 1
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
		warn(("[AssembleFloor2] в %s осталось %d деталей (не из данных) — проверьте вручную"):format(m.Name, left))
	end
end

-- Пол и стены — только невидимые Collision; Dynamic (решётки, доски, пролёт, стены лоз)
-- остаются как в rbxmx: их двигает и прячет сервер.
for _, d in ipairs(map:GetDescendants()) do
	if d:IsA("BasePart") and d.Parent and d.Parent.Name == "Collision" then
		d.Transparency = 1
		d.CanCollide = true
		d.CanQuery = true
		d.Anchored = true
	end
end

local msg = ("[AssembleFloor2] готово: %d из %d MeshPart на месте, не найдено %d. Ctrl+S."):format(placed, total, missing)
print(msg)
return msg
