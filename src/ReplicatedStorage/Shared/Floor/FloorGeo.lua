--!nonstrict
-- FloorGeo
-- Геометрия этажей для логики: лучи по коллизиям карт (Workspace.Floor1Map,
-- Workspace.Floor2Map: невидимые Collision и настоящие Dynamic — доски,
-- баррикады, решётки). Видимые меши (Visual) в лучи не попадают: у них
-- CanQuery = false. Карты этажей стоят в мире порознь (этаж 2 смещён на
-- x +2600), поэтому один луч по обеим картам видит только ближнюю.
--
-- Используют: EnemyService (земля под ногами, стены, прямая видимость),
-- FloorService (зоны), MiniBossService (укрытия, цепной болт).

local Workspace = game:GetService("Workspace")

local FloorGeo = {}

FloorGeo.MapName = "Floor1Map" -- старое имя (этаж 1), для совместимости
FloorGeo.MapNames = { "Floor1Map", "Floor2Map", "Floor3Map", "Floor4Map", "Floor5Map" }
FloorGeo.StepUp = 1.8 -- на столько враг поднимается за шаг (ступени, пандус)
FloorGeo.DropDown = 3.2 -- с уступа выше этого враг не спрыгивает
FloorGeo.WallNormalY = 0.6 -- нормаль круче — стена, положе — пол

local params = nil
local cachedList = {}
local cachedAt = -math.huge

-- Карты в Workspace (список обновляется раз в секунду: лучей много, а карты
-- появляются и пропадают только при сборке в Studio).
local function maps()
	local t = os.clock()
	if t - cachedAt < 1 then
		return cachedList
	end
	cachedAt = t
	local list = {}
	for _, name in ipairs(FloorGeo.MapNames) do
		local found = Workspace:FindFirstChild(name)
		if found then
			table.insert(list, found)
		end
	end
	local changed = #list ~= #cachedList
	for index, m in ipairs(list) do
		if cachedList[index] ~= m then
			changed = true
		end
	end
	if changed or not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = list
		params.IgnoreWater = true
	end
	cachedList = list
	return list
end

local function map()
	return #maps() > 0
end

function FloorGeo.params()
	maps()
	return params
end

-- Луч по карте. Без карты (хаб, старый этаж) — nil.
function FloorGeo.raycast(origin: Vector3, direction: Vector3)
	if not map() then
		return nil
	end
	return Workspace:Raycast(origin, direction, FloorGeo.params())
end

-- Высота пола под точкой (x, z) не выше fromY + StepUp. nil — пусто (дыра, край).
function FloorGeo.groundAt(x: number, z: number, fromY: number): number?
	if not map() then
		return 0
	end
	local top = fromY + FloorGeo.StepUp + 0.25
	local result = Workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -(FloorGeo.StepUp + 40), 0), FloorGeo.params())
	if not result then
		return nil
	end
	return result.Position.Y
end

-- Есть ли стена между точками (прямая видимость). true — заслонено.
function FloorGeo.blocked(from: Vector3, to: Vector3): boolean
	local delta = to - from
	if delta.Magnitude < 0.05 then
		return false
	end
	return FloorGeo.raycast(from, delta) ~= nil
end

-- Сдвиг по полу со скольжением вдоль стен. Возвращает новый (x, z) и упёрся ли.
-- feet — ноги (Y — пол), radius — радиус тела.
function FloorGeo.slide(feet: Vector3, delta: Vector3, radius: number)
	if not map() then
		return feet + delta, false
	end
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	local length = flatDelta.Magnitude
	if length < 1e-4 then
		return feet, false
	end
	local origin = feet + Vector3.new(0, FloorGeo.StepUp + 0.2, 0)
	local hit = FloorGeo.raycast(origin, flatDelta.Unit * (length + radius))
	local blocked = false
	if hit and hit.Normal.Y < FloorGeo.WallNormalY then
		blocked = true
		local normal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
		if normal.Magnitude > 1e-3 then
			normal = normal.Unit
			flatDelta -= normal * flatDelta:Dot(normal)
			length = flatDelta.Magnitude
			if length > 1e-4 then
				local again = FloorGeo.raycast(origin, flatDelta.Unit * (length + radius))
				if again and again.Normal.Y < FloorGeo.WallNormalY then
					flatDelta = Vector3.zero
				end
			end
		else
			flatDelta = Vector3.zero
		end
	end
	return feet + flatDelta, blocked
end

return FloorGeo
