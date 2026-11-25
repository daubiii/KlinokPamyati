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

local VOXEL = 0.125

-- Import 3D разворачивает glTF на 180° вокруг Y (перед glTF +Z → перед
-- Roblox −Z; сверено по вершинам archer_Jacket, зеркала нет). Возвращаем.
local IMPORT_FIX = CFrame.Angles(0, math.pi, 0)

local MANIFEST = {
	{ mesh = "guard_Helmet", enemy = "guard", replaces = { "Helmet", "HelmetBrim" }, anchor = "Helmet", size = { 16, 12, 16 }, offset = { 0, 0, 0 }, colors = "KDR" },
	{ mesh = "guard_Cuirass", enemy = "guard", replaces = { "Cuirass" }, anchor = "Cuirass", size = { 18, 14, 10 }, offset = { 0, 0, 0 }, colors = "KLG" },
	{ mesh = "guard_PauldronR", enemy = "guard", replaces = { "PauldronR" }, anchor = "PauldronR", size = { 11, 5, 11 }, offset = { 0, 0, 0 }, colors = "KGR" },
	{ mesh = "guard_PauldronL", enemy = "guard", replaces = { "PauldronL" }, anchor = "PauldronL", size = { 11, 5, 11 }, offset = { 0, 0, 0 }, colors = "KGR" },
	{ mesh = "guard_BracerR", enemy = "guard", replaces = { "BracerR" }, anchor = "BracerR", size = { 10, 5, 10 }, offset = { 0, 0, 0 }, colors = "KRD" },
	{ mesh = "guard_BracerL", enemy = "guard", replaces = { "BracerL" }, anchor = "BracerL", size = { 10, 5, 10 }, offset = { 0, 0, 0 }, colors = "KRD" },
	{ mesh = "guard_Tabard", enemy = "guard", replaces = { "Tabard" }, anchor = "Tabard", size = { 8, 12, 1 }, offset = { 0, 0, 0 }, colors = "KDA" },
	{ mesh = "guard_GreaveR", enemy = "guard", replaces = { "GreaveR" }, anchor = "GreaveR", size = { 10, 9, 10 }, offset = { 0, 0, 0 }, colors = "KSG" },
	{ mesh = "guard_GreaveL", enemy = "guard", replaces = { "GreaveL" }, anchor = "GreaveL", size = { 10, 9, 10 }, offset = { 0, 0, 0 }, colors = "KSG" },
	{ mesh = "guard_BootR", enemy = "guard", replaces = { "BootR" }, anchor = "BootR", size = { 10, 3, 12 }, offset = { 0, 0, 0 }, colors = "KDB" },
	{ mesh = "guard_BootL", enemy = "guard", replaces = { "BootL" }, anchor = "BootL", size = { 10, 3, 12 }, offset = { 0, 0, 0 }, colors = "KDB" },
	{ mesh = "guard_Buckler", enemy = "guard", replaces = { "Buckler" }, anchor = "Buckler", size = { 12, 12, 2 }, offset = { 0, 0, 0 }, colors = "KSR" },
	{ mesh = "guard_Sword", enemy = "guard", replaces = { "Grip", "Blade", "Guard", "Pommel" }, anchor = "Grip", size = { 7, 30, 3 }, offset = { 0, 10.5, 0 }, colors = "KLW" },
	{ mesh = "shade_Hood", enemy = "shade", replaces = { "Hood", "HoodTail" }, anchor = "Hood", size = { 13, 13, 17 }, offset = { 0, 0, 2 }, colors = "KSD" },
	{ mesh = "shade_Pelerine", enemy = "shade", replaces = { "Pelerine" }, anchor = "Pelerine", size = { 18, 8, 10 }, offset = { 0, 0, 0 }, colors = "KSD" },
	{ mesh = "shade_Cloak", enemy = "shade", replaces = { "Cloak" }, anchor = "Cloak", size = { 16, 27, 1 }, offset = { 0, 0, 0 }, colors = "SKD" },
	{ mesh = "shade_WrapLegR", enemy = "shade", replaces = { "WrapLegR" }, anchor = "WrapLegR", size = { 9, 9, 9 }, offset = { 0, 0, 0 }, colors = "KDS" },
	{ mesh = "shade_WrapLegL", enemy = "shade", replaces = { "WrapLegL" }, anchor = "WrapLegL", size = { 9, 9, 9 }, offset = { 0, 0, 0 }, colors = "KDS" },
	{ mesh = "shade_WrapArmR", enemy = "shade", replaces = { "WrapArmR" }, anchor = "WrapArmR", size = { 9, 7, 9 }, offset = { 0, 0, 0 }, colors = "KDS" },
	{ mesh = "shade_WrapArmL", enemy = "shade", replaces = { "WrapArmL" }, anchor = "WrapArmL", size = { 9, 7, 9 }, offset = { 0, 0, 0 }, colors = "KDS" },
	{ mesh = "shade_DaggerR", enemy = "shade", replaces = { "DaggerGripR", "DaggerBladeR", "DaggerGuardR" }, anchor = "DaggerGripR", size = { 5, 16, 2 }, offset = { 0, 5, 0 }, colors = "KWH" },
	{ mesh = "shade_DaggerL", enemy = "shade", replaces = { "DaggerGripL", "DaggerBladeL", "DaggerGuardL" }, anchor = "DaggerGripL", size = { 5, 16, 2 }, offset = { 0, 5, 0 }, colors = "KWH" },
	{ mesh = "knight_Helmet", enemy = "knight", replaces = { "Helmet" }, anchor = "Helmet", size = { 13, 14, 13 }, offset = { 0, 0, 0 }, colors = "KSG" },
	{ mesh = "knight_Crest", enemy = "knight", replaces = { "Crest" }, anchor = "Crest", size = { 3, 6, 8 }, offset = { 0, 0, 0 }, colors = "KDW" },
	{ mesh = "knight_Cuirass", enemy = "knight", replaces = { "Cuirass" }, anchor = "Cuirass", size = { 18, 14, 10 }, offset = { 0, 0, 0 }, colors = "KGS" },
	{ mesh = "knight_PauldronR", enemy = "knight", replaces = { "PauldronR" }, anchor = "PauldronR", size = { 13, 6, 13 }, offset = { 0, 0, 0 }, colors = "KGL" },
	{ mesh = "knight_PauldronL", enemy = "knight", replaces = { "PauldronL" }, anchor = "PauldronL", size = { 13, 6, 13 }, offset = { 0, 0, 0 }, colors = "KGL" },
	{ mesh = "knight_Faulds", enemy = "knight", replaces = { "Faulds" }, anchor = "Faulds", size = { 18, 4, 10 }, offset = { 0, 0, 0 }, colors = "KSG" },
	{ mesh = "knight_GreaveR", enemy = "knight", replaces = { "GreaveR" }, anchor = "GreaveR", size = { 10, 9, 10 }, offset = { 0, 0, 0 }, colors = "KSG" },
	{ mesh = "knight_GreaveL", enemy = "knight", replaces = { "GreaveL" }, anchor = "GreaveL", size = { 10, 9, 10 }, offset = { 0, 0, 0 }, colors = "KSG" },
	{ mesh = "knight_BootR", enemy = "knight", replaces = { "BootR" }, anchor = "BootR", size = { 10, 3, 12 }, offset = { 0, 0, 0 }, colors = "KDB" },
	{ mesh = "knight_BootL", enemy = "knight", replaces = { "BootL" }, anchor = "BootL", size = { 10, 3, 12 }, offset = { 0, 0, 0 }, colors = "KDB" },
	{ mesh = "knight_BracerR", enemy = "knight", replaces = { "BracerR" }, anchor = "BracerR", size = { 10, 6, 10 }, offset = { 0, 0, 0 }, colors = "KGR" },
	{ mesh = "knight_BracerL", enemy = "knight", replaces = { "BracerL" }, anchor = "BracerL", size = { 10, 6, 10 }, offset = { 0, 0, 0 }, colors = "KGR" },
	{ mesh = "knight_TowerShield", enemy = "knight", replaces = { "TowerShield" }, anchor = "TowerShield", size = { 16, 26, 2 }, offset = { 0, 0, 0 }, colors = "SKG" },
	{ mesh = "knight_Mace", enemy = "knight", replaces = { "MaceShaft", "MaceHead", "MacePommel" }, anchor = "MaceShaft", size = { 8, 26, 8 }, offset = { 0, 2.5, 0 }, colors = "KGS" },
	{ mesh = "archer_Hood", enemy = "archer", replaces = { "Hood", "Mask" }, anchor = "Hood", size = { 12, 12, 12 }, offset = { 0, 0, 0 }, colors = "KDS" },
	{ mesh = "archer_Jacket", enemy = "archer", replaces = { "Jacket" }, anchor = "Jacket", size = { 18, 14, 10 }, offset = { 0, 0, 0 }, colors = "KDR" },
	{ mesh = "archer_Quiver", enemy = "archer", replaces = { "Quiver" }, anchor = "Quiver", size = { 5, 22, 5 }, offset = { 0, 3, 0 }, colors = "KNB" },
	{ mesh = "archer_BracerR", enemy = "archer", replaces = { "BracerR" }, anchor = "BracerR", size = { 9, 6, 9 }, offset = { 0, 0, 0 }, colors = "KBA" },
	{ mesh = "archer_BracerL", enemy = "archer", replaces = { "BracerL" }, anchor = "BracerL", size = { 9, 6, 9 }, offset = { 0, 0, 0 }, colors = "KBA" },
	{ mesh = "archer_BootR", enemy = "archer", replaces = { "BootR" }, anchor = "BootR", size = { 10, 4, 11 }, offset = { 0, 0, 0 }, colors = "KDB" },
	{ mesh = "archer_BootL", enemy = "archer", replaces = { "BootL" }, anchor = "BootL", size = { 10, 4, 11 }, offset = { 0, 0, 0 }, colors = "KDB" },
	{ mesh = "archer_Bow", enemy = "archer", replaces = { "BowGrip", "BowLimbTop", "BowLimbBottom" }, anchor = "BowGrip", size = { 2, 34, 6 }, offset = { 0, 0, 2 }, colors = "NDW" },
	{ mesh = "martyr_Mask", enemy = "martyr", replaces = { "Mask" }, anchor = "Mask", size = { 12, 12, 12 }, offset = { 0, 0, 0 }, colors = "KRD" },
	{ mesh = "martyr_ChargePack", enemy = "martyr", replaces = { "ChargePack" }, anchor = "ChargePack", size = { 18, 14, 3 }, offset = { 0, 0, 0 }, colors = "KDR" },
	{ mesh = "martyr_Bombs", enemy = "martyr", replaces = { "Bomb1", "Bomb2", "Bomb3" }, anchor = "ChargePack", size = { 12, 4, 1 }, offset = { 0, -1, -1 }, colors = "XK" },
	{ mesh = "martyr_BracerR", enemy = "martyr", replaces = { "BracerR" }, anchor = "BracerR", size = { 9, 8, 9 }, offset = { 0, 0, 0 }, colors = "KRD" },
	{ mesh = "martyr_BracerL", enemy = "martyr", replaces = { "BracerL" }, anchor = "BracerL", size = { 9, 8, 9 }, offset = { 0, 0, 0 }, colors = "KRD" },
	{ mesh = "gatekeeper_Helmet", enemy = "gatekeeper", replaces = { "Helmet" }, anchor = "Helmet", size = { 15, 15, 13 }, offset = { 0, 0, 0 }, colors = "KGS" },
	{ mesh = "gatekeeper_Crown", enemy = "gatekeeper", replaces = { "Crown" }, anchor = "Crown", size = { 15, 10, 13 }, offset = { 0, 1.5, 0 }, colors = "ADH" },
	{ mesh = "gatekeeper_Cuirass", enemy = "gatekeeper", replaces = { "Cuirass" }, anchor = "Cuirass", size = { 18, 14, 10 }, offset = { 0, 0, 0 }, colors = "KGS" },
	{ mesh = "gatekeeper_TowerR", enemy = "gatekeeper", replaces = { "TowerR" }, anchor = "TowerR", size = { 12, 8, 12 }, offset = { 0, 0, 0 }, colors = "KGS" },
	{ mesh = "gatekeeper_TowerL", enemy = "gatekeeper", replaces = { "TowerL" }, anchor = "TowerL", size = { 12, 8, 12 }, offset = { 0, 0, 0 }, colors = "KGS" },
	{ mesh = "gatekeeper_Skirt", enemy = "gatekeeper", replaces = { "Skirt" }, anchor = "Skirt", size = { 18, 6, 10 }, offset = { 0, 0, 0 }, colors = "KDR" },
	{ mesh = "gatekeeper_BracerR", enemy = "gatekeeper", replaces = { "BracerR" }, anchor = "BracerR", size = { 10, 7, 10 }, offset = { 0, 0, 0 }, colors = "KGR" },
	{ mesh = "gatekeeper_BracerL", enemy = "gatekeeper", replaces = { "BracerL" }, anchor = "BracerL", size = { 10, 7, 10 }, offset = { 0, 0, 0 }, colors = "KGR" },
	{ mesh = "gatekeeper_ChainR", enemy = "gatekeeper", replaces = { "ChainR" }, anchor = "ChainR", size = { 3, 12, 3 }, offset = { 0, 0, 0 }, colors = "GK" },
	{ mesh = "gatekeeper_ChainL", enemy = "gatekeeper", replaces = { "ChainL" }, anchor = "ChainL", size = { 3, 12, 3 }, offset = { 0, 0, 0 }, colors = "GK" },
	{ mesh = "gatekeeper_GreaveR", enemy = "gatekeeper", replaces = { "GreaveR" }, anchor = "GreaveR", size = { 11, 10, 11 }, offset = { 0, 0, 0 }, colors = "KLS" },
	{ mesh = "gatekeeper_GreaveL", enemy = "gatekeeper", replaces = { "GreaveL" }, anchor = "GreaveL", size = { 11, 10, 11 }, offset = { 0, 0, 0 }, colors = "KLS" },
	{ mesh = "gatekeeper_BootR", enemy = "gatekeeper", replaces = { "BootR" }, anchor = "BootR", size = { 11, 4, 13 }, offset = { 0, 0, 0 }, colors = "KGS" },
	{ mesh = "gatekeeper_BootL", enemy = "gatekeeper", replaces = { "BootL" }, anchor = "BootL", size = { 11, 4, 13 }, offset = { 0, 0, 0 }, colors = "KGS" },
	{ mesh = "gatekeeper_BoltSword", enemy = "gatekeeper", replaces = { "BoltHilt", "BoltBlade" }, anchor = "BoltHilt", size = { 13, 44, 3 }, offset = { 0, 15.5, 0 }, colors = "KLA" },
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
