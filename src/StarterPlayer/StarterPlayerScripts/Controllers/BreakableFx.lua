--!nonstrict
-- BreakableFx (клиент)
-- Ломаемые декорации этажей 4–5: картинка и звук по BreakableEvent
-- (BreakableService). Логики нет — прочность и коллайдеры на сервере.
--
--   hit     предмет вздрагивает (локально), щепа цвета материала, звук удара
--   broke   целая модель уже скрыта сервером; здесь — обломки из
--           ReplicatedStorage.BreakableMeshes.<тип>.<тип>_fragN (физика только у
--           себя, живут Settings.debrisLife с, последние debrisFade — тают),
--           облако пыли, звук разрушения. Нет мешей обломков — кубики-заглушки.
--
-- Предел одновременно летящих обломков — Settings.debrisMax; дальше
-- Settings.fxRange — только звук.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local Breakables = require(Shared.Config.Breakables)

local Bus = require(script.Parent.Parent.Lib.Bus)
local TEX = require(script.Parent.Parent.Lib.FxTex)

local BreakableFx = {}

local Settings = Breakables.Settings
local V3 = Vector3.new
local random = Random.new()
local player = Players.LocalPlayer

local function sfx(name: string, position: Vector3?)
	Bus.emit("sfx", { name = name, position = position })
end

local folderRef
local function folder()
	if folderRef and folderRef.Parent then
		return folderRef
	end
	folderRef = Workspace:FindFirstChild("BreakableFx")
	if not folderRef then
		folderRef = Instance.new("Folder")
		folderRef.Name = "BreakableFx"
		folderRef.Parent = Workspace
	end
	return folderRef
end

local function inRange(position: Vector3): boolean
	local camera = Workspace.CurrentCamera
	return camera == nil or (camera.CFrame.Position - position).Magnitude <= (Settings.fxRange or 140)
end

local function modelOf(id: string, floorId: number?)
	local mapName = floorId and ("Floor" .. floorId .. "Map")
	local map = mapName and Workspace:FindFirstChild(mapName)
	local holder = map and map:FindFirstChild("Breakables") or Workspace:FindFirstChild("Breakables")
	return holder and holder:FindFirstChild(id)
end

-- ===== Обломки =====

local flying = {} -- { part, bornAt, life }

local function trim()
	local max = Settings.debrisMax or 120
	while #flying > max do
		local oldest = table.remove(flying, 1)
		if oldest.part then
			oldest.part:Destroy()
		end
	end
end

local function fragTemplate(typeId: string, name: string)
	local root = ReplicatedStorage:FindFirstChild("BreakableMeshes")
	local holder = root and root:FindFirstChild(typeId)
	local mesh = holder and holder:FindFirstChild(name)
	if mesh and mesh:IsA("BasePart") then
		return mesh
	end
	return nil
end

local function launch(p: BasePart, from: Vector3, center: Vector3, dir: Vector3?)
	p.Anchored = false
	p.CanCollide = true
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = false
	p.CastShadow = false
	p.Parent = folder()
	local away = Vector3.new(center.X - from.X, 0, center.Z - from.Z)
	if away.Magnitude < 0.01 then
		away = V3(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1))
	end
	away = away.Unit
	if dir and dir.Magnitude > 0.01 then
		away = (away + Vector3.new(dir.X, 0, dir.Z).Unit * 0.8).Unit
	end
	local kick = Settings.kick or 18
	local spread = V3(random:NextNumber(-0.5, 0.5), 0, random:NextNumber(-0.5, 0.5))
	pcall(function()
		p.AssemblyLinearVelocity = (away + spread) * kick * random:NextNumber(0.5, 1) + V3(0, (Settings.kickUp or 14) * random:NextNumber(0.6, 1.1), 0)
		p.AssemblyAngularVelocity = V3(random:NextNumber(-10, 10), random:NextNumber(-10, 10), random:NextNumber(-10, 10))
	end)
	local life = (Settings.debrisLife or 2.6) * random:NextNumber(0.85, 1.15)
	local fade = math.min(Settings.debrisFade or 0.8, life)
	table.insert(flying, { part = p, bornAt = os.clock(), life = life })
	trim()
	task.delay(life - fade, function()
		if p.Parent then
			p.Anchored = false
			TweenService:Create(p, TweenInfo.new(fade, Enum.EasingStyle.Sine), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(p, life + 0.05)
end

local function dust(position: Vector3, size: Vector3, color: Color3, amount: number)
	local anchor = Instance.new("Part")
	anchor.Name = "Dust"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = V3(math.max(size.X, 0.5), math.max(size.Y * 0.6, 0.5), math.max(size.Z, 0.5))
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = folder()
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX.smoke
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.05
	e.LightInfluence = 1
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = NumberRange.new(1.5, 4.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 2.5
	e.Acceleration = V3(0, 1.2, 0)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-30, 30)
	local s = math.clamp(math.max(size.X, size.Z), 1, 4)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.45), NumberSequenceKeypoint.new(1, s * 1.3) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Enabled = false
	e.Parent = anchor
	e:Emit(amount)
	Debris:AddItem(anchor, 2)
end

local function chips(position: Vector3, color: Color3, count: number, dir: Vector3?)
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Name = "Chip"
		local s = random:NextNumber(0.12, 0.26)
		p.Size = V3(s, s, s)
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = CFrame.new(position + V3(random:NextNumber(-0.3, 0.3), random:NextNumber(-0.2, 0.3), random:NextNumber(-0.3, 0.3)))
		local from = dir and (position - dir) or (position - V3(0, 0, 1))
		launch(p, from, position, dir)
	end
end

-- ===== Дрожь целого предмета =====

local shaking = {} -- [mesh] = { base, untilT, amount }

local function shakeModel(model, amount: number)
	local mesh = model and model:FindFirstChild("Mesh")
	if not mesh or not mesh:IsA("BasePart") then
		return
	end
	local entry = shaking[mesh]
	if not entry then
		entry = { base = mesh.CFrame }
		shaking[mesh] = entry
	end
	entry.untilT = os.clock() + 0.18
	entry.amount = amount
end

local function stepShake()
	local t = os.clock()
	for mesh, entry in pairs(shaking) do
		if not mesh.Parent then
			shaking[mesh] = nil
		elseif t >= entry.untilT then
			mesh.CFrame = entry.base
			shaking[mesh] = nil
		else
			local k = (entry.untilT - t) / 0.18
			local a = entry.amount * k
			mesh.CFrame = entry.base * CFrame.new(math.sin(t * 90) * a, 0, math.cos(t * 77) * a) * CFrame.Angles(0, math.sin(t * 60) * a * 0.2, 0)
		end
	end
end

-- ===== События =====

local function onHit(payload, cfg, mat)
	local model = modelOf(payload.id, payload.floorId)
	local center = payload.position + cfg.center
	sfx(mat.hit, center)
	if not inRange(center) then
		return
	end
	shakeModel(model, Settings.hitShake or 0.12)
	chips(center + V3(0, cfg.size.Y * 0.1, 0), mat.chip, 4, payload.dir)
	dust(center, cfg.size * 0.5, mat.dust, 3)
end

local function onBroke(payload, cfg, mat)
	local pivot = CFrame.new(payload.position) * CFrame.Angles(0, payload.rotation or 0, 0)
	local center = (pivot * CFrame.new(cfg.center)).Position
	sfx(mat.broke, center)
	local model = modelOf(payload.id, payload.floorId)
	local mesh = model and model:FindFirstChild("Mesh")
	if mesh and shaking[mesh] then
		mesh.CFrame = shaking[mesh].base
		shaking[mesh] = nil
	end
	if not inRange(center) then
		return
	end
	local from = typeof(payload.from) == "Vector3" and payload.from or (center - pivot.LookVector * 2)
	for _, frag in ipairs(cfg.frags or {}) do
		local template = fragTemplate(payload.type, frag.name)
		local p
		if template then
			p = template:Clone()
		else
			p = Instance.new("Part")
			p.Color = mat.chip
			p.Material = Enum.Material.SmoothPlastic
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
		end
		p.Name = frag.name
		p.Size = V3(math.max(frag.size.X, 0.1), math.max(frag.size.Y, 0.1), math.max(frag.size.Z, 0.1))
		p.CFrame = pivot * CFrame.new(frag.offset)
		p.Transparency = 0
		launch(p, from, p.Position, payload.dir)
	end
	chips(center, mat.chip, 8, payload.dir)
	dust(center, cfg.size, mat.dust, 14)
	if model and player.Character then
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - center).Magnitude < 10 then
			Bus.emit("shake", { amount = 0.08, time = 0.12 })
		end
	end
end

local function onEvent(payload)
	if type(payload) ~= "table" or type(payload.kind) ~= "string" then
		return
	end
	if payload.kind ~= "hit" and payload.kind ~= "broke" then
		return
	end
	local cfg = Breakables.get(payload.type)
	if not cfg or typeof(payload.position) ~= "Vector3" then
		return
	end
	local mat = Breakables.Materials[cfg.material] or Breakables.Materials.wood
	if payload.kind == "hit" then
		onHit(payload, cfg, mat)
	else
		onBroke(payload, cfg, mat)
	end
end

function BreakableFx.start()
	folder()
	local remote = Net.get("BreakableEvent")
	if remote then
		remote.OnClientEvent:Connect(onEvent)
	else
		warn("[BreakableFx] нет BreakableEvent (Net.Remotes)")
	end
	RunService.RenderStepped:Connect(stepShake)
	print("[BreakableFx] обломки декораций этажей 4–5")
end

return BreakableFx
