--[[
	assemble_enemies3d — сборка объёмных врагов (пакет Enemies3D) из одного импорта enemies3d.glb.
	Это AssembleEnemies.lua из пакета, переделанный под glb: OBJ импортёр сливал в одну MeshPart "default".

	До запуска:
	1. ReplicatedStorage.EnemyPrefabs — из EnemyPrefabs.rbxmx (node tools/import-rbxmx.js … --into ReplicatedStorage).
	2. ReplicatedStorage.Shared.Config.EnemyArmorData — модуль из пакета.
	3. Import 3D → tools/enemy-armor/out3d/enemies3d.glb (модель в Workspace или ServerStorage, не распаковывать).
	   MeshPart называются "<id>__<объект>" (guard__Head__helmet), см. tools/enemy-armor/obj_to_glb.py.

	Текстура палитры — та, что импорт загрузил вместе с glb (Image, загруженный отдельно, мешем не рисуется);
	если её нет — EnemyArmorData.paletteTexture. Импорт удаляется, только если нашлись все детали.
	Повторный запуск безопасен: детали с тем же именем заменяются.
]]
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local DATA = require(RS.Shared.Config.EnemyArmorData)
local prefabs = RS:WaitForChild("EnemyPrefabs")

local FOLDER = {
	armor = "Armor", shield = "Armor", cloak = "Armor", key = "Armor", banner = "Armor",
	weapon = "Weapon", glow = "Glow", glow2 = "Glow", bomb = "Glow",
}

-- Все импортированные детали: имя → MeshPart, плюс модели-источники
local meshes, sources = {}, {}
for _, container in ipairs({ workspace, SS }) do
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("MeshPart") and d.Name:find("__", 1, true) and not d:IsDescendantOf(prefabs) then
			local eid = d.Name:match("^(%w+)__")
			if eid and DATA.enemies[eid] then
				meshes[d.Name] = d
				local top = d
				while top.Parent ~= container do
					top = top.Parent
				end
				sources[top] = true
			end
		end
	end
end

local palette = DATA.paletteTexture
for _, mp in pairs(meshes) do
	if mp.TextureID ~= "" then
		palette = mp.TextureID
		break
	end
end
print("[Assemble] палитра: " .. palette)

local missing, total = 0, 0
for id, def in pairs(DATA.enemies) do
	local prefab = prefabs:FindFirstChild(id) :: Model?
	if not prefab then
		warn(("[Assemble] %s: нет префаба в EnemyPrefabs — пропуск"):format(id))
		missing += #def.objects
		continue
	end
	if prefab:GetScale() ~= 1 then
		prefab:ScaleTo(1)
	end
	local placed = 0
	for _, o in ipairs(def.objects) do
		local mp = meshes[id .. "__" .. o.name]
		local part = prefab:FindFirstChild(o.part) :: BasePart?
		if not mp or not part then
			warn(("[Assemble] %s: не найдено %s / %s"):format(id, o.name, o.part))
			missing += 1
			continue
		end
		local folder = prefab:FindFirstChild(FOLDER[o.role] or "Armor")
		local old = folder:FindFirstChild(o.name)
		if old then
			old:Destroy()
		end
		for _, c in ipairs(mp:GetChildren()) do
			if c:IsA("JointInstance") or c:IsA("WeldConstraint") or c:IsA("SurfaceAppearance") then
				c:Destroy()
			end
		end
		mp.Name = o.name
		mp.Size = o.size
		mp.CFrame = part.CFrame * CFrame.new(o.offset)
		mp.Anchored = false
		mp.CanCollide = false
		mp.CanQuery = false
		mp.CanTouch = false
		mp.Massless = true
		mp.Reflectance = 0
		if o.role == "glow" or o.role == "glow2" then
			mp.Material = Enum.Material.Neon
			mp.Color = o.glow
			mp.TextureID = ""
			mp.CastShadow = false
			-- glow2 — свечение второй фазы: скрыто, клиент показывает его на фазе 2 (Transparency 1 → 0)
			mp.Transparency = (o.role == "glow2") and 1 or 0
		else
			mp.Material = Enum.Material.SmoothPlastic
			mp.Color = Color3.new(1, 1, 1)
			mp.TextureID = palette
			mp.CastShadow = (o.role ~= "key")
			mp.Transparency = 0
		end
		mp:SetAttribute("Role", o.role)
		mp.Parent = folder
		if o.role == "weapon" then
			local m = Instance.new("Motor6D")
			m.Name = "WeaponGrip"
			m.Part0 = part
			m.Part1 = mp
			m.C0 = part.CFrame:ToObjectSpace(mp.CFrame)
			m.C1 = CFrame.new()
			m.Parent = mp
		else
			local w = Instance.new("WeldConstraint")
			w.Part0 = part
			w.Part1 = mp
			w.Parent = mp
		end
		placed += 1
	end
	for i, wf in ipairs(def.weaponFx or {}) do
		local mp = prefab.Weapon:FindFirstChild(wf.object)
		if mp then
			local suffix = (i > 1) and tostring(i) or ""
			for _, n in ipairs({ "FX_WeaponBase" .. suffix, "FX_WeaponTip" .. suffix }) do
				local a = mp:FindFirstChild(n)
				if a then
					a:Destroy()
				end
			end
			local b = Instance.new("Attachment")
			b.Name = "FX_WeaponBase" .. suffix
			b.Position = wf.base
			b.Parent = mp
			local t = Instance.new("Attachment")
			t.Name = "FX_WeaponTip" .. suffix
			t.Position = wf.tip
			t.Parent = mp
		end
	end
	prefab:SetAttribute("TypeId", id)
	prefab:SetAttribute("Scale", def.scale)
	prefab:SetAttribute("RigVersion", 2)
	prefab:ScaleTo(def.scale)
	total += placed
	print(("[Assemble] %s: готово, деталей %d/%d, масштаб %.2f"):format(id, placed, #def.objects, def.scale))
	task.wait()
end

if missing == 0 then
	for src in pairs(sources) do
		src:Destroy()
	end
end
game:GetService("ChangeHistoryService"):SetWaypoint("assemble enemies3d")
return ("поставлено: %d, не найдено: %d%s"):format(total, missing, missing == 0 and ", импорт удалён" or ", импорт оставлен")
