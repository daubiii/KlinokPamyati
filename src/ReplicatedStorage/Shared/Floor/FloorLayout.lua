--!nonstrict
-- FloorLayout
-- Чистая геометрия этажа без Instance: где стоит каждая комната и как
-- перевести локальные координаты из приложения Е в мировые.
-- Вынесено отдельно, чтобы проверяться обычными тестами вне Studio.
--
-- Комнаты идут цепочкой в сторону −Z. Вход комнаты на её +Z краю (там
-- дверь), выход — на −Z краю, он же вход следующей комнаты.
-- Локальная ось Y (приложение Е) растёт от входа к выходу:
--     мировой Z = centerZ − localY.

local FloorLayout = {}

-- specs: список { kind = ... }, sizes: { combat = 50, rest = 30, boss = 80 },
-- gap — длина коридора между комнатами (0 — комнаты вплотную).
-- Возвращает список { index, kind, size, centerZ, entryZ, exitZ }.
function FloorLayout.build(specs, sizes, gap: number?)
	local rooms = {}
	local cursor = 0
	for index, spec in ipairs(specs) do
		local size = sizes[spec.kind] or 50
		local centerZ = cursor - size / 2
		table.insert(rooms, {
			index = index,
			kind = spec.kind,
			size = size,
			centerZ = centerZ,
			entryZ = cursor,
			exitZ = cursor - size,
		})
		cursor -= size + (gap or 0)
	end
	return rooms
end

-- Старт игрока в комнате (локальные x, y): у входной стены.
function FloorLayout.startPoint(room, back: number)
	return 0, -(room.size / 2 - back)
end

-- Локальная точка (x, y) → мировые (x, z).
function FloorLayout.toWorld(room, localX: number, localY: number)
	return localX, room.centerZ - localY
end

-- Мировая точка → локальная (x, y).
function FloorLayout.toLocal(room, worldX: number, worldZ: number)
	return worldX, room.centerZ - worldZ
end

-- Внутри ли точка комнаты. depth — отступ от входной стены (чтобы стоящий в
-- дверях не считался вошедшим); margin — отступ от остальных стен.
function FloorLayout.contains(room, worldX: number, worldZ: number, depth: number?, margin: number?)
	local half = room.size / 2
	local m = margin or 0
	if math.abs(worldX) > half - m then
		return false
	end
	if worldZ > room.entryZ - (depth or 0) then
		return false
	end
	return worldZ >= room.exitZ + m
end

-- Какая комната содержит точку (или nil).
function FloorLayout.roomAt(rooms, worldX: number, worldZ: number, depth: number?)
	for _, room in ipairs(rooms) do
		if FloorLayout.contains(room, worldX, worldZ, depth) then
			return room
		end
	end
	return nil
end

-- Границы для передвижения врагов внутри комнаты (отступ 2 от стен).
-- У круглой арены босса есть ещё radius и center: враг не уходит за круг.
function FloorLayout.bounds(room, margin: number?)
	local m = margin or 2
	local half = room.size / 2
	local bounds = {
		xHalf = half - m,
		zMin = room.exitZ + m,
		zMax = room.entryZ - m,
	}
	if room.kind == "boss" then
		bounds.radius = half - m - 1
		bounds.cx = 0
		bounds.cz = room.centerZ
	end
	return bounds
end

-- Этаж v2: границы — объединение областей (прямоугольники и круги).
-- areas = { { x0, z0, x1, z1 } | { cx, cz, r } }. Точка внутри любой — не трогаем,
-- иначе — ближайшая точка ближайшей области.
local function clampAreas(areas, x: number, z: number)
	local bestX, bestZ, bestD = x, z, math.huge
	for _, area in ipairs(areas) do
		local px, pz
		if area.r then
			local dx, dz = x - area.cx, z - area.cz
			local d = math.sqrt(dx * dx + dz * dz)
			if d <= area.r then
				return x, z
			end
			px, pz = area.cx + dx / d * area.r, area.cz + dz / d * area.r
		else
			px, pz = math.clamp(x, area.x0, area.x1), math.clamp(z, area.z0, area.z1)
			if px == x and pz == z then
				return x, z
			end
		end
		local d = (px - x) ^ 2 + (pz - z) ^ 2
		if d < bestD then
			bestX, bestZ, bestD = px, pz, d
		end
	end
	return bestX, bestZ
end
FloorLayout.clampAreas = clampAreas

-- Зажать точку (x, z) в границы: прямоугольник, а для арены ещё и круг.
function FloorLayout.clampToBounds(bounds, x: number, z: number)
	if bounds.areas then
		return clampAreas(bounds.areas, x, z)
	end
	local cx = math.clamp(x, -bounds.xHalf, bounds.xHalf)
	local cz = math.clamp(z, bounds.zMin, bounds.zMax)
	if bounds.radius then
		local dx, dz = cx - bounds.cx, cz - bounds.cz
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance > bounds.radius then
			cx = bounds.cx + dx / distance * bounds.radius
			cz = bounds.cz + dz / distance * bounds.radius
		end
	end
	return cx, cz
end

return FloorLayout
