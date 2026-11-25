--!nonstrict
-- apply_armor_meshes.lua — шаг 5: заменить заглушки префабов мешами брони.
-- ФАЙЛ СОБРАН ГЕНЕРАТОРОМ (tools/enemy-armor/build_armor.py) из
-- tools/enemy-armor/apply_template.lua — правьте шаблон, а не этот файл.
--
-- Что делает (режим Edit):
--   1. Ищет импортированные меши (MeshPart с именем <enemy>_<деталь>) в
--      ServerStorage.EnemyArmorMeshes (можно вложенными моделями).
--   2. В каждом префабе ReplicatedStorage.EnemyPrefabs.<enemy> ставит меш на
--      место заглушки-якоря (смещение и размер — из манифеста, с учётом
--      ScaleTo префаба), переносит на меш суставы (WeaponGrip, ShieldGrip,
--      Tabard, Cloak, Crest, Crown, ChainR/L), сварку с телом, точки FX_*,
--      тетиву, частицы и атрибуты (Body, Role, Phase + Colors для распада).
--   3. Удаляет заменённые заглушки.
-- Повторный запуск ничего не ломает: уже заменённые детали пропускаются.
-- После — Ctrl+S.
--
-- Запуск: node C:\Users\artem\.dsh-roblox\s.js exec tools/lua/apply_armor_meshes.lua Edit
-- или вставить в Command Bar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Палитра из импорта enemy_armor.glb (22.10.2026; картинка, загруженная
-- отдельно как Image, текстурой не рисуется). Пусто — текстура меша как есть.
local PALETTE_TEXTURE = "rbxassetid://85494384872386"

local VOXEL = --@@VOXEL@@

-- Import 3D разворачивает glTF на 180° вокруг Y (перед glTF +Z → перед
-- Roblox −Z; сверено по вершинам archer_Jacket, зеркала нет). Возвращаем.
local IMPORT_FIX = CFrame.Angles(0, math.pi, 0)

local MANIFEST = {
--@@MANIFEST@@
}

local report = {}
local function log(text)
	table.insert(report, text)
end

local meshFolder = ServerStorage:FindFirstChild("EnemyArmorMeshes")
if not meshFolder then
	return "Нет ServerStorage.EnemyArmorMeshes — положи туда импортированные меши (см. tools/enemy-armor/README.md)"
end

local templates = {}
for _, d in ipairs(meshFolder:GetDescendants()) do
	if d:IsA("MeshPart") then
		templates[d.Name] = templates[d.Name] or d
	end
end

-- Позиции заглушек запоминаем заранее: якорь может уйти раньше (заряды
-- Треснувшего ставятся по связке зарядов, которую тоже меняют).
local stubCFrames = {}
local prefabs = ReplicatedStorage:FindFirstChild("EnemyPrefabs")
if not prefabs then
	return "Нет ReplicatedStorage.EnemyPrefabs — сначала tools/lua/build_enemy_prefabs.lua"
end
for _, prefab in ipairs(prefabs:GetChildren()) do
	local map = {}
	for _, d in ipairs(prefab:GetDescendants()) do
		if d:IsA("BasePart") then
			map[d.Name] = d.CFrame
		end
	end
	stubCFrames[prefab.Name] = map
end

local function findPart(model: Instance, name: string): BasePart?
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == name then
			return d
		end
	end
	return nil
end

local done, skipped, missing = 0, 0, {}

for _, entry in ipairs(MANIFEST) do
	local prefab = prefabs:FindFirstChild(entry.enemy)
	local template = templates[entry.mesh]
	if not prefab then
		table.insert(missing, entry.mesh .. " (нет префаба)")
	elseif findPart(prefab, entry.mesh) then
		skipped += 1
	elseif not template then
		table.insert(missing, entry.mesh)
	else
		local scale = prefab:GetScale()
		local unit = VOXEL * scale
		local anchorCF = stubCFrames[entry.enemy][entry.anchor]
		local stubs = {}
		for _, name in ipairs(entry.replaces) do
			local stub = findPart(prefab, name)
			if stub then
				table.insert(stubs, stub)
			end
		end
		if not anchorCF or #stubs == 0 then
			table.insert(missing, entry.mesh .. " (нет заглушки " .. entry.anchor .. ")")
		else
			local first = stubs[1]
			local offset = CFrame.new(entry.offset[1] * unit, entry.offset[2] * unit, entry.offset[3] * unit)
			local mesh = template:Clone()
			mesh.Name = entry.mesh
			mesh.Size = Vector3.new(entry.size[1] * unit, entry.size[2] * unit, entry.size[3] * unit)
			mesh.CFrame = anchorCF * offset * IMPORT_FIX
			mesh.Anchored = false
			mesh.CanCollide = false
			mesh.CanQuery = false
			mesh.CanTouch = false
			mesh.Massless = true
			mesh.Reflectance = 0
			mesh.Material = first.Material
			mesh.Color = first.Color
			mesh.Transparency = first.Transparency
			mesh.CastShadow = first.CastShadow
			if PALETTE_TEXTURE ~= "" then
				mesh.TextureID = PALETTE_TEXTURE
				-- Импорт может положить текстуру в SurfaceAppearance — она бы
				-- перекрыла TextureID.
				for _, child in ipairs(mesh:GetChildren()) do
					if child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end
			end
			for key, value in pairs(first:GetAttributes()) do
				mesh:SetAttribute(key, value)
			end
			mesh:SetAttribute("Colors", entry.colors)
			mesh.Parent = first.Parent

			local replaced = {}
			for _, stub in ipairs(stubs) do
				replaced[stub] = true
			end
			local welded = {}
			for _, stub in ipairs(stubs) do
				for _, d in ipairs(prefab:GetDescendants()) do
					if d:IsA("Motor6D") then
						if d.Part1 == stub then
							-- Сустав детали (хват, табард, цепь…): C1 — от меша.
							d.C1 = mesh.CFrame:ToObjectSpace(stub.CFrame * d.C1)
							d.Part1 = mesh
							d.Parent = mesh
						elseif d.Part0 == stub then
							d.C0 = mesh.CFrame:ToObjectSpace(stub.CFrame * d.C0)
							d.Part0 = mesh
						end
					elseif d:IsA("WeldConstraint") and (d.Part0 == stub or d.Part1 == stub) then
						local other = d.Part0 == stub and d.Part1 or d.Part0
						if other and not replaced[other] and not welded[other] then
							welded[other] = true
							local weld = Instance.new("WeldConstraint")
							weld.Part0 = other
							weld.Part1 = mesh
							weld.Parent = mesh
						end
						d:Destroy()
					end
				end
				-- Точки эффектов, тетива, свет, частицы — на меш, на тех же местах.
				for _, child in ipairs(stub:GetChildren()) do
					if child:IsA("Attachment") then
						local world = child.WorldCFrame
						child.Parent = mesh
						child.WorldCFrame = world
					elseif not child:IsA("WeldConstraint") and not child:IsA("Motor6D") then
						child.Parent = mesh
					end
				end
			end
			for _, stub in ipairs(stubs) do
				stub:Destroy()
			end
			done += 1
		end
	end
end

log(("заменено: %d, уже было: %d, не найдено: %d"):format(done, skipped, #missing))
if #missing > 0 then
	log("нет мешей: " .. table.concat(missing, ", "))
end
log("Не забудь Ctrl+S.")
return table.concat(report, "\n")
