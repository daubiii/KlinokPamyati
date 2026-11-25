--[[
	AssembleEnemies45 — сборка объёмных врагов этажей 4–5 из enemies_f4.glb / enemies_f5.glb.
	Запускать в Studio, в Command Bar (режим Edit). Повторный запуск безопасен:
	префаб с тем же именем пересобирается с нуля.

	До запуска:
	1. ReplicatedStorage.Shared.Config.EnemyRig4 / EnemyRig5 — из пакета (Rojo).
	2. File → Import 3D: enemies_f4.glb и enemies_f5.glb как есть (без Merge).
	   MeshPart называются "<тип>__<часть>__<роль>" (forge_automaton__Head__eye).

	Что делает для каждого типа из EnemyRig4/5:
	• ReplicatedStorage.EnemyPrefabs.<тип> — Model: невидимые части R15 (центры и
	  размеры из рига), Motor6D с точками вращения из рига (их двигает
	  EnemyAnimator), AnimationController + Animator;
	• Armor — меши тела (WeldConstraint к части, атрибут Body), Weapon — оружие
	  (Motor6D "WeaponGrip"), Glow — глаза и свечение (Neon; glow2 скрыт до II фазы);
	• FX — Attachment FX_* в частях + ObjectValue-ссылки (точки эффектов EnemyFx);
	• атрибуты TypeId, Scale = 1, RigVersion = 2. Центр HumanoidRootPart — 2,6 над
	  ступнями (так ждёт EnemyVisualController).
	Импорт удаляется, только если нашлись все меши.
	Типы, чьих мешей нет в импорте, пропускаются (их префабы остаются как были) —
	так обновляется один моб: импортировать только его glb и запустить скрипт.
]]
local RS = game:GetService("ReplicatedStorage")
local Config = RS:WaitForChild("Shared"):WaitForChild("Config")
local RIGS = {}
for _, n in ipairs({ "EnemyRig4", "EnemyRig5" }) do
	local m = Config:FindFirstChild(n)
	if m then
		for id, def in pairs(require(m)) do
			RIGS[id] = def
		end
	else
		warn("[Enemies45] нет модуля Config." .. n)
	end
end

local prefabs = RS:FindFirstChild("EnemyPrefabs")
if not prefabs then
	prefabs = Instance.new("Folder")
	prefabs.Name = "EnemyPrefabs"
	prefabs.Parent = RS
end

-- Все импортированные меши врагов: имя → MeshPart; модели-источники.
local index, sources = {}, {}
for _, container in ipairs({ workspace, game:GetService("ServerStorage") }) do
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("MeshPart") and d.Name:find("__", 1, true) and not d:IsDescendantOf(prefabs) then
			local id = d.Name:match("^(.-)__")
			if id and RIGS[id] and not index[d.Name] then
				index[d.Name] = d
				local top = d
				while top.Parent ~= container do
					top = top.Parent
				end
				sources[top] = true
			end
		end
	end
end

local function find(name: string): MeshPart?
	if index[name] then
		return index[name]
	end
	for key, mp in pairs(index) do
		local tail = #key > #name and key:sub(1, #name) == name and key:sub(#name + 1)
		if tail and (tail:match("^%.%d+$") or tail:match("^%s*%(%d+%)$") or tail:match("^_%d%d%d$")) then
			return mp
		end
	end
	return nil
end

-- Палитра: TextureID любого меша того же типа (на случай, если у части меша он пуст).
local function paletteFor(id: string): string
	for key, mp in pairs(index) do
		if key:sub(1, #id + 2) == id .. "__" and mp.TextureID ~= "" then
			return mp.TextureID
		end
	end
	return ""
end

local ROLE_FOLDER = { body = "Armor", weapon = "Weapon", eye = "Glow", glow = "Glow", glow2 = "Glow" }

local total, missing = 0, 0
local skipped = 0
for id, def in pairs(RIGS) do
	-- Типы, чьих мешей нет в импорте, не трогаем: можно импортировать один
	-- обновлённый моб (seal_mage.glb), не ломая уже собранные префабы.
	local any = false
	for _, o in ipairs(def.meshes) do
		if find(o.name) then
			any = true
			break
		end
	end
	if not any then
		skipped += 1
		continue
	end
	local old = prefabs:FindFirstChild(id)
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = id
	local parts = {}
	for name, p in pairs(def.parts) do
		local part = Instance.new("Part")
		part.Name = name
		part.Size = p.s
		part.CFrame = CFrame.new(p.c)
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Massless = name ~= "HumanoidRootPart"
		part.Anchored = name == "HumanoidRootPart"
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		parts[name] = part
	end
	local hrp = parts.HumanoidRootPart
	if not hrp then
		warn(("[Enemies45] %s: нет HumanoidRootPart в риге — пропуск"):format(id))
		model:Destroy()
		continue
	end
	model.PrimaryPart = hrp
	for _, j in ipairs(def.joints) do
		local p0, p1 = parts[j[2]], parts[j[3]]
		if p0 and p1 then
			local m = Instance.new("Motor6D")
			m.Name = j[1]
			m.Part0 = p0
			m.Part1 = p1
			m.C0 = p0.CFrame:ToObjectSpace(CFrame.new(j[4]))
			m.C1 = p1.CFrame:ToObjectSpace(CFrame.new(j[4]))
			m.Parent = p1
		else
			warn(("[Enemies45] %s: сустав %s — нет части"):format(id, j[1]))
		end
	end
	local ac = Instance.new("AnimationController")
	ac.Parent = model
	Instance.new("Animator").Parent = ac
	local folders = {}
	for _, n in ipairs({ "Armor", "Weapon", "Glow", "FX" }) do
		local f = Instance.new("Folder")
		f.Name = n
		f.Parent = model
		folders[n] = f
	end

	local palette = paletteFor(id)
	local placed = 0
	for _, o in ipairs(def.meshes) do
		local src = find(o.name)
		local part = parts[o.part]
		if not src or not part then
			warn(("[Enemies45] %s: не найден меш %s (часть %s)"):format(id, o.name, o.part))
			missing += 1
			continue
		end
		local mp = src:Clone()
		for _, c in ipairs(mp:GetChildren()) do
			if c:IsA("JointInstance") or c:IsA("WeldConstraint") or c:IsA("SurfaceAppearance") then
				c:Destroy()
			end
		end
		-- короткое имя: часть + роль (как в объёмных префабах этажей 1–2)
		mp.Name = o.name:sub(#id + 3)
		mp.Size = o.size
		mp.CFrame = part.CFrame * CFrame.new(o.offset)
		mp.Anchored = false
		mp.CanCollide = false
		mp.CanQuery = false
		mp.CanTouch = false
		mp.Massless = true
		mp.Reflectance = 0
		if o.role == "eye" or o.role == "glow" or o.role == "glow2" then
			mp.Material = Enum.Material.Neon
			mp.Color = o.glow or Color3.fromRGB(255, 200, 87)
			mp.TextureID = ""
			mp.CastShadow = false
			mp.Transparency = (o.role == "glow2") and 1 or 0
		else
			mp.Material = Enum.Material.SmoothPlastic
			mp.Color = Color3.new(1, 1, 1)
			if mp.TextureID == "" then
				mp.TextureID = palette
			end
			mp.CastShadow = true
			mp.Transparency = 0
		end
		mp:SetAttribute("Role", o.role)
		mp:SetAttribute("Body", o.part)
		mp.Parent = folders[ROLE_FOLDER[o.role] or "Armor"]
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
	for _, f in ipairs(def.fx or {}) do
		local part = parts[f[2]]
		if part then
			local a = Instance.new("Attachment")
			a.Name = f[1]
			a.Position = f[3]
			a.Parent = part
			local link = Instance.new("ObjectValue")
			link.Name = f[1]
			link.Value = a
			link.Parent = folders.FX
		end
	end
	model:SetAttribute("TypeId", id)
	model:SetAttribute("Scale", 1)
	model:SetAttribute("RigVersion", 2)
	model:SetAttribute("Height", def.height)
	model.Parent = prefabs
	total += placed
	print(("[Enemies45] %s: деталей %d/%d"):format(id, placed, #def.meshes))
	task.wait()
end

if missing == 0 and next(sources) then
	for src in pairs(sources) do
		src:Destroy()
	end
end
game:GetService("ChangeHistoryService"):SetWaypoint("assemble enemies 4-5")
return ("поставлено мешей: %d, не найдено: %d, типов без мешей в импорте (не тронуты): %d%s"):format(
	total, missing, skipped, missing == 0 and ", импорт удалён" or ", импорт оставлен")
