--[[
	AssembleWeaponsFloors345 — меши оружия этажей 3, 4, 5 → ReplicatedStorage.WeaponMeshes.
	Запускает Артём сам: Studio, Command Bar, режим Edit (НЕ во время Play).
	Повторный запуск безопасен; можно импортировать и собрать этажи по одному.

	До запуска:
	1. ReplicatedStorage.Shared.Config.WeaponMeshDataFloor3/4/5 — пришли из src через Rojo.
	2. File → Import 3D → weapons_floor3.glb, weapons_floor4.glb, weapons_floor5.glb (настройки не менять).
	   В Workspace появятся модели weapons_floor3 / weapons_floor4 / weapons_floor5:
	   W_<оружие> (с палитрой) у каждого оружия + G1_…G5_<оружие> (свечение) у эпиков, легендарок и секреток.

	Что делает: переносит MeshPart в ReplicatedStorage.WeaponMeshes, ставит размер из данных,
	отключает коллизии; у свечения убирает текстуру (цвет и Neon ставит VoxelWeaponBuilder).
	Пустые модели импорта удаляет. После — Ctrl+S: папка живёт только в файле места.
]]
local RS = game:GetService("ReplicatedStorage")
local Config = RS.Shared.Config

local folder = RS:FindFirstChild("WeaponMeshes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WeaponMeshes"
	folder.Parent = RS
end
if folder:GetAttribute("ImportYaw") == nil then
	folder:SetAttribute("ImportYaw", 0)
end

local function findMesh(roots, name: string): MeshPart?
	for _, root in ipairs(roots) do
		local fallback = nil
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("MeshPart") then
				if d.Name == name then
					return d
				end
				-- Импортер иногда дописывает имя материала: "W_paper_knife_palette".
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

local grand = { placed = 0, total = 0, missing = 0 }
for floor = 3, 5 do
	local module = Config:FindFirstChild("WeaponMeshDataFloor" .. floor)
	if not module then
		warn(("[AssembleWeaponsFloors345] нет модуля WeaponMeshDataFloor%d — этаж пропущен"):format(floor))
		continue
	end
	local DATA = require(module)
	local source = workspace:FindFirstChild("weapons_floor" .. floor)
	local roots = { folder }
	if source then
		table.insert(roots, 1, source)
	end
	local placed, missing, total = 0, 0, 0
	for weaponId, weapon in pairs(DATA) do
		for _, o in ipairs(weapon.objects) do
			total += 1
			local mp = findMesh(roots, o.name)
			if not mp then
				missing += 1
				warn(("[AssembleWeaponsFloors345] этаж %d, %s: нет MeshPart %s"):format(floor, weaponId, o.name))
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
			if o.role == "glow" then
				mp.TextureID = ""
				mp.Material = Enum.Material.Neon
				mp.Color = o.glow or Color3.fromRGB(255, 181, 54)
				for _, c in ipairs(mp:GetChildren()) do
					if c:IsA("SurfaceAppearance") then
						c:Destroy()
					end
				end
			end
			mp.Parent = folder
			placed += 1
		end
	end
	if source then
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
	print(("[AssembleWeaponsFloors345] этаж %d: %d из %d MeshPart, не найдено %d%s"):format(
		floor, placed, total, missing, source and "" or " (модели импорта weapons_floor" .. floor .. " нет — взяты уже лежащие в WeaponMeshes)"))
	grand.placed += placed
	grand.total += total
	grand.missing += missing
end
print(("[AssembleWeaponsFloors345] готово: %d из %d, не найдено %d. Сохраните место (Ctrl+S)."):format(grand.placed, grand.total, grand.missing))
