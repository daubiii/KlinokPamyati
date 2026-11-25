--!strict
-- Util/BossGeo
-- Геометрия фирменных атак боссов (Config/BossMoves). Только числа — без
-- Vector3 и экземпляров, поэтому одни и те же формулы считают попадания на
-- сервере (Systems/BossMoves), рисуют разметку на клиенте
-- (Controllers/BossMovesFx) и проверяются тестом tools/lua/test_bosses.lua.
--
-- Плоскость пола: x, z. Направление — единичный (dx, dz). Угол — радианы,
-- atan2(dx, dz): 0 смотрит на +Z, рост — к +X.

local BossGeo = {}

local TAU = math.pi * 2

function BossGeo.angleOf(dx: number, dz: number): number
	return math.atan2(dx, dz)
end

function BossGeo.dirOf(angle: number): (number, number)
	return math.sin(angle), math.cos(angle)
end

-- Разница углов в (−π, π].
function BossGeo.angleDiff(a: number, b: number): number
	local d = (a - b) % TAU
	if d > math.pi then
		d -= TAU
	end
	return d
end

function BossGeo.unit(dx: number, dz: number, fx: number?, fz: number?): (number, number)
	local m = math.sqrt(dx * dx + dz * dz)
	if m < 1e-4 then
		return fx or 0, fz or 1
	end
	return dx / m, dz / m
end

-- Локальные координаты точки в осях: вперёд f и вбок s = (fz, −fx)
-- (для взгляда вдоль +Z это +X). Возвращает (вдоль, вбок).
function BossGeo.toLocal(px: number, pz: number, ox: number, oz: number, fx: number, fz: number): (number, number)
	local dx, dz = px - ox, pz - oz
	return dx * fx + dz * fz, dx * fz - dz * fx
end

function BossGeo.fromLocal(along: number, side: number, ox: number, oz: number, fx: number, fz: number): (number, number)
	return ox + fx * along + fz * side, oz + fz * along - fx * side
end

-- ===== Арена =====

-- Круг арены из границ врага (enemy.bounds.areas: круги { cx, cz, r } или
-- прямоугольники { x0, z0, x1, z1 }). Берём область, в которой стоит босс;
-- без границ — круг radius вокруг дома.
function BossGeo.arena(bounds: any, hx: number, hz: number, fallbackRadius: number?): (number, number, number)
	local areas = bounds and bounds.areas
	if type(areas) == "table" then
		local best, bestD = nil, math.huge
		for _, area in ipairs(areas) do
			local cx, cz, r
			if area.r then
				cx, cz, r = area.cx, area.cz, area.r
			elseif area.x0 then
				cx, cz = (area.x0 + area.x1) / 2, (area.z0 + area.z1) / 2
				r = math.min(area.x1 - area.x0, area.z1 - area.z0) / 2
			elseif area[1] and area[4] then
				cx, cz = (area[1] + area[3]) / 2, (area[2] + area[4]) / 2
				r = math.min(math.abs(area[3] - area[1]), math.abs(area[4] - area[2])) / 2
			end
			if cx then
				local d = math.sqrt((hx - cx) ^ 2 + (hz - cz) ^ 2) - r
				if d < bestD then
					best, bestD = { cx, cz, r }, d
				end
			end
		end
		if best then
			return best[1], best[2], best[3]
		end
	end
	if bounds and bounds.radius and bounds.cx then
		return bounds.cx, bounds.cz, bounds.radius
	end
	return hx, hz, fallbackRadius or 30
end

-- Точку — внутрь круга (с отступом margin).
function BossGeo.clampCircle(x: number, z: number, cx: number, cz: number, r: number, margin: number?): (number, number)
	local limit = math.max(r - (margin or 0), 0)
	local dx, dz = x - cx, z - cz
	local d = math.sqrt(dx * dx + dz * dz)
	if d <= limit or d < 1e-6 then
		return x, z
	end
	return cx + dx / d * limit, cz + dz / d * limit
end

-- ===== Привратник: решётки (сетка grid × grid клеток по cell стад) =====

-- Клетки сетки вокруг (cx, cz), оси — вперёд (fx, fz). Индексы i, j от
-- −half до half. Клетки, чей центр вне круга арены, отбрасываются.
function BossGeo.gridCells(cx: number, cz: number, fx: number, fz: number, cell: number, grid: number, arena: { number }?)
	local cells = {}
	local half = (grid - 1) / 2
	for i = 0, grid - 1 do
		for j = 0, grid - 1 do
			local a, s = (i - half) * cell, (j - half) * cell
			local x, z = BossGeo.fromLocal(a, s, cx, cz, fx, fz)
			local inside = true
			if arena then
				inside = (x - arena[1]) ^ 2 + (z - arena[2]) ^ 2 <= (arena[3] - cell * 0.3) ^ 2
			end
			if inside then
				table.insert(cells, { x = x, z = z, i = i, j = j })
			end
		end
	end
	return cells
end

-- Шахматка: волна w (1, 2, 3…) роняет клетки с (i + j + w) чётным.
function BossGeo.cellDrops(i: number, j: number, wave: number): boolean
	return (i + j + wave) % 2 == 0
end

-- Точка внутри клетки (квадрат со стороной cell, отступ inset внутрь).
function BossGeo.inCell(px: number, pz: number, cellX: number, cellZ: number, fx: number, fz: number, cell: number, inset: number?): boolean
	local a, s = BossGeo.toLocal(px, pz, cellX, cellZ, fx, fz)
	local half = cell / 2 - (inset or 0)
	return math.abs(a) <= half and math.abs(s) <= half
end

-- ===== Привратник: засовы «Поворота ключа» =====

-- Засов — отрезок от центра длиной radius под углом angle, ширина width.
function BossGeo.boltHit(px: number, pz: number, cx: number, cz: number, angle: number, radius: number, width: number): boolean
	local fx, fz = BossGeo.dirOf(angle)
	local along, side = BossGeo.toLocal(px, pz, cx, cz, fx, fz)
	return along >= 0 and along <= radius and math.abs(side) <= width / 2
end

-- Углы засовов в момент k секунд вращения.
function BossGeo.boltAngles(start: number, count: number, speed: number, k: number): { number }
	local list = {}
	for index = 1, count do
		table.insert(list, start + (index - 1) * TAU / count + speed * k)
	end
	return list
end

-- ===== Садовница: кольцевая волна с просветами =====

-- Попала ли волна радиуса waveR (толщина thick) в точку на расстоянии d.
function BossGeo.ringHit(d: number, waveR: number, thick: number): boolean
	return math.abs(d - waveR) <= thick / 2
end

-- Угол в одном из просветов (gaps — углы середин, halfWidth — полуширина, рад).
function BossGeo.inGap(angle: number, gaps: { number }, halfWidth: number): boolean
	for _, gap in ipairs(gaps) do
		if math.abs(BossGeo.angleDiff(angle, gap)) <= halfWidth then
			return true
		end
	end
	return false
end

-- ===== Садовница: «Мраморный взгляд» =====

-- Смотрит ли игрок (взгляд lx, lz) на точку (bx, bz): косинус больше threshold.
function BossGeo.looksAt(lx: number, lz: number, px: number, pz: number, bx: number, bz: number, threshold: number): boolean
	local dx, dz = BossGeo.unit(bx - px, bz - pz)
	local ux, uz = BossGeo.unit(lx, lz)
	return dx * ux + dz * uz > threshold
end

-- ===== Ловчий: полосы травли =====

-- Полосы шириной width поперёк оси бега (dx, dz) с центром в (cx, cz):
-- count полос, смещения середин от центра. safe — номера пустых полос.
function BossGeo.laneOffsets(count: number, width: number): { number }
	local list = {}
	local half = (count - 1) / 2
	for index = 1, count do
		table.insert(list, (index - 1 - half) * width)
	end
	return list
end

-- Номер полосы точки (или nil, если вне полос) и координата вдоль бега.
function BossGeo.laneOf(px: number, pz: number, cx: number, cz: number, dx: number, dz: number, count: number, width: number): (number?, number)
	local along, side = BossGeo.toLocal(px, pz, cx, cz, dx, dz)
	local half = count * width / 2
	if side < -half or side > half then
		return nil, along
	end
	local index = math.floor((side + half) / width) + 1
	return math.clamp(index, 1, count), along
end

-- Пустые полосы: две, не соседние с краем, разведены (детерминированно от seed).
function BossGeo.safeLanes(count: number, seed: number): { [number]: boolean }
	local safe = {}
	local a = (seed % count) + 1
	local b = ((a - 1 + math.max(2, math.floor(count / 2))) % count) + 1
	safe[a] = true
	safe[b] = true
	return safe
end

-- ===== Литейщик: «блинчики» слитка =====

-- Точки касаний: distances — расстояния от броска вдоль направления (fx, fz).
-- Каждая точка зажимается в круг арены (слиток не улетает за стену).
function BossGeo.skipPoints(ox: number, oz: number, fx: number, fz: number, distances: { number }, arena: { number }?)
	local list = {}
	for _, d in ipairs(distances) do
		local x, z = ox + fx * d, oz + fz * d
		if arena then
			local cx, cz = BossGeo.clampCircle(x, z, arena[1], arena[2], arena[3], 2)
			if math.abs(cx - x) > 0.01 or math.abs(cz - z) > 0.01 then
				table.insert(list, { x = cx, z = cz, d = d, clamped = true })
				break
			end
		end
		table.insert(list, { x = x, z = z, d = d, clamped = false })
	end
	return list
end

-- ===== Хронист: «Глава закрыта» =====

-- Знаковое расстояние от линии корешка (через (cx, cz), направление (sx, sz)).
-- > 0 — половина по оси s = (sz, −sx).
function BossGeo.spineSide(px: number, pz: number, cx: number, cz: number, sx: number, sz: number): number
	local _, side = BossGeo.toLocal(px, pz, cx, cz, sx, sz)
	return side
end

-- Под обложкой: половина side (+1/−1), ширина обложки width, длина вдоль
-- корешка 2·halfLength, полоса корешка ±spine безопасна.
function BossGeo.underCover(px: number, pz: number, cx: number, cz: number, sx: number, sz: number, side: number, width: number, halfLength: number, spine: number): boolean
	local along, s = BossGeo.toLocal(px, pz, cx, cz, sx, sz)
	s *= side
	return s > spine and s <= width and math.abs(along) <= halfLength
end

return BossGeo
