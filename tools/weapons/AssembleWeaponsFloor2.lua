--[[
	AssembleWeaponsFloor2 — меши оружия этажа 2 → ReplicatedStorage.WeaponMeshes.
	Запускает Артём сам: Studio, Command Bar, режим Edit (НЕ во время Play).
	Один раз после импорта. Повторный запуск безопасен.

	До запуска:
	1. ReplicatedStorage.Shared.Config.WeaponMeshDataFloor2 — пришёл из src через Rojo.
	2. File → Import 3D → weapons_floor2.glb, настройки не менять.
	   В Workspace появится модель weapons_floor2 с 14 MeshPart:
	   W_<оружие> (с палитрой) у всех восьми и G1_/G2_<оружие> (свечение) у Клинка жатвы,
	   Приливного молота и Секатора Садовницы.

	Что делает: переносит MeshPart в ReplicatedStorage.WeaponMeshes, ставит
	размер из WeaponMeshData, отключает коллизии; у свечения убирает текстуру
	(цвет и Neon ставит VoxelWeaponBuilder). Пустую модель импорта удаляет.
	После — Ctrl+S: папка живёт только в файле места.
]]
local RS = game:GetService("ReplicatedStorage")
local DATA = require(RS.Shared.Config.WeaponMeshDataFloor2)

local folder = RS:FindFirstChild("WeaponMeshes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WeaponMeshes"
	folder.Parent = RS
end
if folder:GetAttribute("ImportYaw") == nil then
	folder:SetAttribute("ImportYaw", 0)
end

local source = workspace:FindFirstChild("weapons_floor2")

local function findMesh(name: string): MeshPart?
	local roots = { folder }
	if source then
		table.insert(roots, 1, source)
	end
	for _, root in ipairs(roots) do
		local fallback = nil
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("MeshPart") then
				if d.Name == name then
					return d
				end
				-- Импортер иногда дописывает имя материала: "W_rusty_sword_palette".
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

local placed, missing, total = 0, 0, 0
for weaponId, weapon in pairs(DATA) do
	for _, o in ipairs(weapon.objects) do
		total += 1
		local mp = findMesh(o.name)
		if not mp then
			missing += 1
			warn(("[AssembleWeaponsFloor2] %s: нет MeshPart %s"):format(weaponId, o.name))
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

if source and #source:GetDescendants() == 0 then
	source:Destroy()
elseif source then
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

print(("[AssembleWeaponsFloor2] готово: %d из %d MeshPart в ReplicatedStorage.WeaponMeshes, не найдено %d. Сохраните место (Ctrl+S)."):format(placed, total, missing))
