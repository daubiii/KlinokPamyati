--!nonstrict
-- BreakableService
-- Ломаемые декорации этажей 4–5 (механика по записке Артёма).
--
--   • Расстановка — Config/Floor4Breakables, Floor5Breakables (ID Brk_X_<зона>_NN),
--     прочность и материалы — Config/Breakables. Лута нет.
--   • Сервер при сборке этажа ставит каждую декорацию: модель <ID> в
--     Workspace.<Карта>.Breakables — невидимый бокс-коллайдер (габарит из
--     Breakables.Types) и целая MeshPart из ReplicatedStorage.BreakableMeshes.<тип>
--     (опора — центр низа). Нет меша — простой блок цвета материала.
--   • Попадание считает сервер по той же дуге, что и удар по врагам
--     (MeleeService.swingHooks): дальность оружия + hitSlop, угол дуги, высота.
--   • Прочность хранит сервер. Удар → BreakableEvent { kind = "hit" } (дрожь,
--     щепа, звук); ноль → коллайдер и лучи выключены, целая модель скрыта,
--     BreakableEvent { kind = "broke" } → клиент (BreakableFx) рассыпает обломки
--     (короткоживущие, только у себя), пыль, звук.
--   • Settings.respawn > 0 — предмет возвращается через N с; иначе до пересборки.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Breakables = require(Shared.Config.Breakables)
local Net = require(Shared.Net.Net)

local MeleeService = require(script.Parent.MeleeService)

local BreakableService = {}

local Settings = Breakables.Settings
local MAP_NAMES = { [4] = "Floor4Map", [5] = "Floor5Map" }

local floors = {} -- [floorId] = { folder, list = { record }, byId = { [id] = record } }

local function remote()
	return Net.get("BreakableEvent")
end

local function broadcast(payload)
	local r = remote()
	if r then
		r:FireAllClients(payload)
	end
end

local function meshTemplate(typeId: string, name: string?)
	local root = ReplicatedStorage:FindFirstChild("BreakableMeshes")
	local folder = root and root:FindFirstChild(typeId)
	local mesh = folder and folder:FindFirstChild(name or typeId)
	if mesh and mesh:IsA("BasePart") then
		return mesh
	end
	return nil
end

local function makePart(name: string, size: Vector3, cframe: CFrame)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local FALLBACK_MATERIAL = {
	wood = Enum.Material.Wood,
	metal = Enum.Material.Metal,
	stone = Enum.Material.Slate,
	paper = Enum.Material.SmoothPlastic,
	leather = Enum.Material.Fabric,
}

local function setIntact(record, intact: boolean)
	record.broken = not intact
	record.hp = intact and record.maxHp or 0
	if record.collider then
		record.collider.CanCollide = intact and Settings.collide
		record.collider.CanQuery = intact and Settings.collide
	end
	if record.visual then
		record.visual.Transparency = intact and 0 or 1
		record.visual.CastShadow = intact
	end
	if record.glow then
		record.glow.Transparency = intact and 0 or 1
		local light = record.glow:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = intact
		end
	end
	if record.model then
		record.model:SetAttribute("Broken", not intact)
		record.model:SetAttribute("Hp", record.hp)
	end
end

local function place(parent, entry, floorId: number)
	local cfg = Breakables.get(entry.type)
	if not cfg then
		warn("[BreakableService] нет типа " .. tostring(entry.type) .. " (" .. tostring(entry.id) .. ")")
		return nil
	end
	local pivot = CFrame.new(entry.position) * CFrame.Angles(0, math.rad(entry.rotation or 0), 0)
	local model = Instance.new("Model")
	model.Name = entry.id
	model:SetAttribute("BreakId", entry.id)
	model:SetAttribute("BreakType", entry.type)
	model:SetAttribute("Zone", entry.zone)

	local boxCFrame = pivot * CFrame.new(cfg.center)
	local collider = makePart("Collider", cfg.size, boxCFrame)
	collider.Transparency = 1
	collider.CanTouch = false
	collider.CastShadow = false
	collider.Parent = model
	model.PrimaryPart = collider

	local visual
	local template = meshTemplate(entry.type)
	if template then
		visual = template:Clone()
		visual.Name = "Mesh"
		visual.Size = cfg.size
		visual.CFrame = boxCFrame
	else
		-- Без меша (не собран AssembleBreakables) — заглушка цвета материала.
		local mat = Breakables.Materials[cfg.material] or Breakables.Materials.wood
		visual = makePart("Mesh", cfg.size * 0.96, boxCFrame)
		visual.Color = mat.chip
		visual.Material = FALLBACK_MATERIAL[cfg.material] or Enum.Material.Wood
	end
	visual.Anchored = true
	visual.CanCollide = false
	visual.CanQuery = false
	visual.CanTouch = false
	visual.Parent = model

	-- Светящаяся деталь (пламя свечей, кристалл): Neon, гаснет с предметом.
	local glow
	if cfg.glow then
		local glowTemplate = meshTemplate(entry.type, cfg.glow.name)
		glow = glowTemplate and glowTemplate:Clone() or makePart("Glow", cfg.glow.size, CFrame.identity)
		glow.Name = "Glow"
		glow.Size = cfg.glow.size
		glow.CFrame = pivot * CFrame.new(cfg.glow.offset)
		glow.Material = Enum.Material.Neon
		glow.Color = cfg.glow.color
		if glow:IsA("MeshPart") then
			glow.TextureID = ""
		end
		glow.Anchored = true
		glow.CanCollide = false
		glow.CanQuery = false
		glow.CanTouch = false
		glow.CastShadow = false
		local light = Instance.new("PointLight")
		light.Color = cfg.glow.color
		light.Range = 8
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = glow
		glow.Parent = model
	end
	model.Parent = parent

	local hp = math.max(1, math.floor(cfg.hp * (Settings.hpScale or 1) + 0.5))
	local record = {
		id = entry.id,
		type = entry.type,
		zone = entry.zone,
		cfg = cfg,
		floorId = floorId,
		pivot = pivot,
		center = boxCFrame.Position,
		bottom = pivot.Position.Y,
		top = pivot.Position.Y + cfg.size.Y,
		radius = math.max(cfg.size.X, cfg.size.Z) * 0.5,
		maxHp = hp,
		hp = hp,
		model = model,
		collider = collider,
		visual = visual,
		glow = glow,
		broken = false,
	}
	setIntact(record, true)
	return record
end

function BreakableService.clear(floorId: number)
	local floor = floors[floorId]
	if floor and floor.folder then
		floor.folder:Destroy()
	end
	floors[floorId] = nil
end

-- Расставить декорации этажа заново (FloorNWorld: hooks.build).
function BreakableService.build(floorId: number)
	BreakableService.clear(floorId)
	if not Settings.enabled or not Settings.floors[floorId] then
		return
	end
	local map = Workspace:FindFirstChild(MAP_NAMES[floorId] or "")
	local folder = Instance.new("Folder")
	folder.Name = "Breakables"
	folder:SetAttribute("FloorId", floorId)
	-- В карте: FloorGeo видит коллайдеры (враги обходят ящики, лучи упираются).
	folder.Parent = map or Workspace
	local floor = { folder = folder, list = {}, byId = {} }
	for _, entry in ipairs(Breakables.placements(floorId)) do
		local record = place(folder, entry, floorId)
		if record then
			table.insert(floor.list, record)
			floor.byId[record.id] = record
		end
	end
	floors[floorId] = floor
	broadcast({ kind = "reset", floorId = floorId })
	print(("[BreakableService] этаж %d: декораций %d"):format(floorId, #floor.list))
end

local function payloadOf(record, kind: string, from: Vector3?, dir: Vector3?)
	return {
		kind = kind,
		id = record.id,
		type = record.type,
		floorId = record.floorId,
		position = record.pivot.Position,
		rotation = select(2, record.pivot:ToEulerAnglesYXZ()),
		from = from,
		dir = dir,
		hp = record.hp,
		maxHp = record.maxHp,
	}
end

local function breakRecord(record, from: Vector3?, dir: Vector3?)
	setIntact(record, false)
	broadcast(payloadOf(record, "broke", from, dir))
	local respawn = Settings.respawn or 0
	if respawn > 0 then
		task.delay(respawn, function()
			local floor = floors[record.floorId]
			if floor and floor.byId[record.id] == record and record.broken then
				setIntact(record, true)
				broadcast(payloadOf(record, "restore"))
			end
		end)
	end
end

-- Урон по декорации (удар игрока; можно звать и из способностей).
function BreakableService.damage(record, amount: number, from: Vector3?, dir: Vector3?)
	if record.broken or amount <= 0 then
		return false
	end
	record.hp = math.max(0, record.hp - amount)
	if record.model then
		record.model:SetAttribute("Hp", record.hp)
	end
	if record.hp <= 0 then
		breakRecord(record, from, dir)
		return true
	end
	broadcast(payloadOf(record, "hit", from, dir))
	return false
end

-- Удар по площади (взрыв тлеющего, прыжок босса): всё в радиусе.
function BreakableService.areaHit(floorId: number, center: Vector3, radius: number, amount: number)
	local floor = floors[floorId]
	if not floor then
		return 0
	end
	local count = 0
	for _, record in ipairs(floor.list) do
		if not record.broken then
			local d = Vector3.new(record.center.X - center.X, 0, record.center.Z - center.Z).Magnitude
			if d - record.radius <= radius and math.abs(record.bottom - center.Y) < 6 then
				if BreakableService.damage(record, amount, center, nil) then
					count += 1
				end
			end
		end
	end
	return count
end

-- Дуга удара игрока (как MeleeService.findTargets, только по декорациям).
local function onSwing(player, origin: Vector3, forward: Vector3, range: number, arc: number, damage: number): number
	if player:GetAttribute("Zone") ~= "Floor" then
		return 0
	end
	local floor = floors[player:GetAttribute("FloorId") or 0]
	if not floor then
		return 0
	end
	local reach = range + (Settings.hitSlop or 0)
	local halfArc = math.rad(arc / 2)
	local feet = origin.Y - 3
	local hitCount = 0
	for _, record in ipairs(floor.list) do
		if not record.broken then
			local to = Vector3.new(record.center.X - origin.X, 0, record.center.Z - origin.Z)
			local distance = to.Magnitude
			if distance - record.radius <= reach and feet >= record.bottom - 4.5 and feet <= record.top + 1.5 then
				local inArc = true
				if distance > 0.01 then
					local slack = math.atan2(record.radius, distance)
					inArc = forward:Dot(to.Unit) >= math.cos(math.min(halfArc + slack, math.pi))
				end
				if inArc then
					BreakableService.damage(record, damage, origin, forward)
					hitCount += 1
				end
			end
		end
	end
	return hitCount
end

-- Новому игроку — какие уже разбиты (модели скрыты сервером, это для щепы).
local function sendState(player)
	local r = remote()
	if not r then
		return
	end
	for floorId, floor in pairs(floors) do
		local broken = {}
		for _, record in ipairs(floor.list) do
			if record.broken then
				table.insert(broken, record.id)
			end
		end
		r:FireClient(player, { kind = "state", floorId = floorId, broken = broken })
	end
end

function BreakableService.get(floorId: number, id: string)
	local floor = floors[floorId]
	return floor and floor.byId[id]
end

function BreakableService.list(floorId: number)
	local floor = floors[floorId]
	return floor and floor.list or {}
end

function BreakableService.start()
	Net.ensureAll()
	table.insert(MeleeService.swingHooks, onSwing)
	Players.PlayerAdded:Connect(function(player)
		task.delay(3, sendState, player)
	end)
	print("[BreakableService] запущен")
end

return BreakableService
