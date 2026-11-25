--[[
	AssembleArmorFloors — меши брони этажей 2–5 (воин и маг) → ReplicatedStorage.HeroArmorMeshes.
	Запускает Артём сам: Studio, Command Bar, режим Edit (НЕ во время Play).
	Один раз после импорта. Повторный запуск безопасен (можно по одному этажу).

	До запуска:
	1. ReplicatedStorage.Shared.Config.ArmorFloorsMeshData — пришёл из src через Rojo.
	2. File → Import 3D → tools/armor-floors/assets/armor_floor2.glb (и 3, 4, 5), настройки не менять.
	   В Workspace появятся модели armor_floor2…5: HA_<комплект>_<деталь> (с палитрой)
	   и HG_<комплект>_<деталь>_<n> (свечение: глаза, руны, угли, камни).

	Что делает: переносит MeshPart в ReplicatedStorage.HeroArmorMeshes (туда же,
	где броня воина; имена не пересекаются), ставит размер из MageArmorMeshData,
	отключает коллизии; у свечения убирает текстуру (Neon и цвет ставит
	HeroArmorBuilder). Каждому мешу — атрибут ImportYaw = MESH_YAW: меши уже
	повёрнуты при экспорте (как броня мага этажа 1), поэтому 0. Если шлемы
	смотрят назад — поставьте MESH_YAW = 180 и запустите ещё раз.
	Пустую модель импорта удаляет. После — Ctrl+S: папка живёт только в файле места.

	Проверка в Play (сервер, Command Bar):
	  print(game.ServerStorage.KlinokDebug.Cmd:Invoke("armor rose_warden"))
	  print(game.ServerStorage.KlinokDebug.PreviewArmor:Invoke("warrior", 2))
	  print(game.ServerStorage.KlinokDebug.PreviewArmor:Invoke("mage", 5))
]]
local MESH_YAW = 0

local RS = game:GetService("ReplicatedStorage")
local DATA = require(RS.Shared.Config.ArmorFloorsMeshData)

local folder = RS:FindFirstChild("HeroArmorMeshes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "HeroArmorMeshes"
	folder.Parent = RS
end

local sources = {}
for floor = 2, 5 do
	local model = workspace:FindFirstChild("armor_floor" .. floor)
	if model then
		table.insert(sources, model)
	end
end

local function findMesh(name: string): MeshPart?
	local roots = table.clone(sources)
	table.insert(roots, folder)
	for _, root in ipairs(roots) do
		local fallback = nil
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("MeshPart") then
				if d.Name == name then
					return d
				end
				-- Импортер иногда дописывает имя материала: "HA_novice_Hat_palette".
				if not fallback and string.sub(d.Name, 1, #name + 1) == name .. "_" and not string.match(string.sub(d.Name, #name + 2), "^%d") then
					fallback = d
				end
			end
		end
		if fallback then
			return fallback
		end
	end
	return nil
end

-- Все объекты комплекта: helm, armor и сегменты плаща с их свечением.
local objects = {}
for setId, set in pairs(DATA.sets) do
	for _, slot in ipairs({ "helm", "armor" }) do
		for _, o in ipairs(set[slot] or {}) do
			table.insert(objects, { setId = setId, name = o.name, size = o.size, glow = o.glow })
		end
	end
	for _, segment in ipairs(set.cape or {}) do
		table.insert(objects, { setId = setId, name = segment.name, size = segment.size })
		for _, g in ipairs(segment.glows or {}) do
			table.insert(objects, { setId = setId, name = g.name, size = g.size, glow = g.glow })
		end
	end
end

local placed, missing = 0, 0
for _, o in ipairs(objects) do
	local mp = findMesh(o.name)
	if not mp then
		missing += 1
		warn(("[AssembleArmorFloors] %s: нет MeshPart %s"):format(o.setId, o.name))
		continue
	end
	local old = folder:FindFirstChild(o.name)
	if old and old ~= mp then
		old:Destroy()
	end
	mp.Name = o.name
	mp.Anchored = true
	mp.CanCollide = false
	mp.CanQuery = false
	mp.CanTouch = false
	mp.Massless = true
	mp.CastShadow = false
	mp.Size = o.size
	mp.CFrame = CFrame.new(0, -500, 0)
	pcall(function()
		mp.CollisionFidelity = Enum.CollisionFidelity.Box
	end)
	for _, c in ipairs(mp:GetChildren()) do
		if c:IsA("JointInstance") or c:IsA("WeldConstraint") then
			c:Destroy()
		end
	end
	if o.glow then
		mp.TextureID = ""
		mp.Material = Enum.Material.Neon
		mp.Color = o.glow
		for _, c in ipairs(mp:GetChildren()) do
			if c:IsA("SurfaceAppearance") then
				c:Destroy()
			end
		end
	end
	mp:SetAttribute("ImportYaw", MESH_YAW)
	mp:SetAttribute("ArmorFloor", DATA.sets[o.setId].floor or 0)
	mp.Parent = folder
	placed += 1
end

for _, source in ipairs(sources) do
	local left = 0
	for _, d in ipairs(source:GetDescendants()) do
		if d:IsA("MeshPart") then
			left += 1
		end
	end
	if left == 0 then
		source:Destroy()
	end
end

print(("[AssembleArmorFloors] готово: %d из %d MeshPart в ReplicatedStorage.HeroArmorMeshes, не найдено %d (импортировано этажей: %d). Сохраните место (Ctrl+S).")
	:format(placed, #objects, missing, #sources))
