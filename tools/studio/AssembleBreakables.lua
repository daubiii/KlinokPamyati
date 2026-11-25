--[[
	AssembleBreakables — меши разрушаемых декораций этажей 4–5 из breakables_f45.glb.
	Запускать в Studio, в Command Bar (режим Edit). Повторный запуск безопасен.

	До запуска:
	1. ReplicatedStorage.Shared.Config.Breakables — из пакета (Rojo).
	2. File → Import 3D: breakables_f45.glb как есть (без Merge). MeshPart
	   называются Brk_<Тип>, Brk_<Тип>_fragN, Brk_<Тип>_glow (опора — центр низа).

	Результат: ReplicatedStorage.BreakableMeshes.<Тип> / { <Тип>, <Тип>_frag1…N, <Тип>_glow }.
	Меши без коллизий и лучей, Anchored; размер — из Breakables.Types. Позиции
	не важны: BreakableService и BreakableFx ставят их сами (опора + center/offset).
	Импорт удаляется, только если нашлись все меши.
]]
local RS = game:GetService("ReplicatedStorage")
local Breakables = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Breakables"))

local root = RS:FindFirstChild("BreakableMeshes")
if not root then
	root = Instance.new("Folder")
	root.Name = "BreakableMeshes"
	root.Parent = RS
end

local index, sources = {}, {}
for _, container in ipairs({ workspace, game:GetService("ServerStorage") }) do
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("MeshPart") and d.Name:match("^Brk_") and not d:IsDescendantOf(root) and not index[d.Name] then
			index[d.Name] = d
			local top = d
			while top.Parent ~= container do
				top = top.Parent
			end
			sources[top] = true
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

local function place(holder: Instance, name: string, size: Vector3, glowColor: Color3?): boolean
	local src = find(name)
	if not src then
		warn("[Breakables] не найден меш " .. name)
		return false
	end
	local old = holder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local mp = src:Clone()
	for _, c in ipairs(mp:GetChildren()) do
		if c:IsA("JointInstance") or c:IsA("WeldConstraint") or c:IsA("SurfaceAppearance") then
			c:Destroy()
		end
	end
	mp.Name = name
	mp.Size = size
	mp.CFrame = CFrame.new()
	mp.Anchored = true
	mp.CanCollide = false
	mp.CanQuery = false
	mp.CanTouch = false
	mp.Massless = true
	mp.Reflectance = 0
	pcall(function()
		mp.CollisionFidelity = Enum.CollisionFidelity.Box
	end)
	if glowColor then
		mp.Material = Enum.Material.Neon
		mp.Color = glowColor
		mp.TextureID = ""
		mp.CastShadow = false
		mp:SetAttribute("Role", "glow")
	else
		mp.Material = Enum.Material.SmoothPlastic
		mp.Color = Color3.new(1, 1, 1) -- цвет даёт текстура-палитра из glb
		mp.CastShadow = true
	end
	mp.Parent = holder
	return true
end

local placed, missing = 0, 0
for typeId, t in pairs(Breakables.Types) do
	local holder = root:FindFirstChild(typeId)
	if not holder then
		holder = Instance.new("Folder")
		holder.Name = typeId
		holder.Parent = root
	end
	local list = { { typeId, t.size } }
	for _, f in ipairs(t.frags or {}) do
		table.insert(list, { f.name, f.size })
	end
	for _, e in ipairs(list) do
		if place(holder, e[1], e[2]) then
			placed += 1
		else
			missing += 1
		end
	end
	if t.glow then
		if place(holder, t.glow.name, t.glow.size, t.glow.color) then
			placed += 1
		else
			missing += 1
		end
	end
end

if missing == 0 and next(sources) then
	for src in pairs(sources) do
		src:Destroy()
	end
end
game:GetService("ChangeHistoryService"):SetWaypoint("assemble breakables 4-5")
return ("мешей: %d, не найдено: %d%s"):format(placed, missing, missing == 0 and ", импорт удалён" or ", импорт оставлен")
