--!nonstrict
-- FloorBuilder (сервер)
-- Строит этаж 1 «Привратный двор»: пустынная крепость в руинах на пути к
-- главным воротам башни Хранилища.
--   * Комната 0 — двор крепости: когда-то здесь кипела жизнь (рынок,
--     колодец, телеги, тренировочные чучела), теперь всё занесено пылью;
--     главные ворота башни открываются, когда игрок подходит.
--   * Боевые комнаты — открытые дворы (спецификация владельца 21.10.2026):
--     пол из тёмного сланца, светлая дорожка от входа к выходу, по
--     периметру скопления обломков и остатки стен, над руинами парят
--     кубики, у входа и выхода — маяки с оранжевым огнём.
--   * Между комнатами — закрытые коридоры с факелами: этаж ощущается
--     длиннее, а следующая комната не видна за деревянной дверью.
--   * Арена босса — круг с рунной печатью, жаровнями и вратами Хранилища.
-- Логика боя и состояния комнат — в FloorService, реквизит — FloorProps,
-- небо и дальний план — FloorScenery.
--
-- Правила:
--  * цвета только из Palette (Ruin, Env и цвета этажа);
--  * комнаты идут цепочкой к −Z, вход на +Z краю (Shared/Floor/FloorLayout);
--  * декор детерминирован: этаж выглядит одинаково при каждом запуске;
--  * за пределы комнаты не выйти: по периметру невидимый барьер до
--    Rooms.BarrierHeight, проёмы закрыты дверями.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Config.Palette)
local Rooms = require(Shared.Config.Rooms)
local FloorLayout = require(Shared.Floor.FloorLayout)

local Props = require(script.Parent.FloorProps)
local FloorScenery = require(script.Parent.FloorScenery)

local FloorBuilder = {}

local Env = Palette.Env
local Ruin = Palette.Ruin
local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local SLATE = Enum.Material.Slate

local ROW = 3 -- высота ряда кладки
local RUBBLE = { { Ruin.floor, 3 }, { Ruin.rubble, 3 }, { Env.stoneDeep, 1 } }

-- ===== Кладка =====

local function stoneColor(rng, row: number)
	local list
	if row <= 2 then
		list = { { Ruin.floor, 3 }, { Env.stoneDeep, 2 }, { Ruin.rubble, 1 } }
	else
		list = { { Ruin.rubble, 3 }, { Env.stoneDark, 2 }, { Ruin.floor, 1 } }
	end
	return Props.vary(Props.pick(rng, list), rng, 0.07)
end

local function block(folder, name: string, size: Vector3, cframe: CFrame, color: Color3, collide: boolean?)
	return Props.part(folder, name, size, cframe, color, SLATE, { collide = collide })
end

-- Сплошная стена рядами блоков разной длины (коридоры, ворота).
-- axis "x" — стена вдоль X на z = fixed; "z" — вдоль Z на x = fixed.
local function masonry(folder, rng, axis: string, fixed: number, from: number, to: number, height: number, thickness: number, opts)
	local rows = math.ceil(height / ROW)
	for row = 1, rows do
		local y0 = (row - 1) * ROW
		local h = math.min(ROW, height - y0)
		local cursor = from - (row % 2 == 0 and 1.5 or 0)
		while cursor < to do
			local width = 2.5 + rng:NextInteger(0, 3)
			local s = math.max(cursor, from)
			local e = math.min(cursor + width, to)
			cursor += width
			local length = e - s
			local skipTop = opts and opts.ragged and row == rows and rng:NextNumber() < 0.35
			if length > 0.2 and not skipTop then
				local inset = (rng:NextNumber() - 0.5) * 0.3
				local mid = (s + e) / 2
				local cf = axis == "x" and CF(mid, y0 + h / 2, fixed + inset) or CF(fixed + inset, y0 + h / 2, mid)
				local size = axis == "x" and V3(length - 0.06, h, thickness) or V3(thickness, h, length - 0.06)
				block(folder, "WallStone", size, cf, stoneColor(rng, row), opts and opts.collide)
			end
		end
	end
end

-- Невидимый барьер: от пола до BarrierHeight, с проёмом gap = {from, to, height}.
local function barrier(folder, axis: string, fixed: number, from: number, to: number, gap)
	local top = Rooms.BarrierHeight
	local function slab(a: number, b: number, y0: number, y1: number)
		if b - a <= 0.05 or y1 - y0 <= 0.05 then
			return
		end
		local size = axis == "x" and V3(b - a, y1 - y0, 2) or V3(2, y1 - y0, b - a)
		local position = axis == "x" and V3((a + b) / 2, (y0 + y1) / 2, fixed) or V3(fixed, (y0 + y1) / 2, (a + b) / 2)
		Props.part(folder, "Barrier", size, CF(position), Env.stone, nil, { collide = true, query = false, shadow = false, transparency = 1 })
	end
	if gap then
		slab(from, gap.from, 0, top)
		slab(gap.to, to, 0, top)
		slab(gap.from, gap.to, gap.height, top)
	else
		slab(from, to, 0, top)
	end
end

-- ===== Пол =====

-- Плита тёмного сланца, редкие плиты другого тона и светлая дорожка от
-- входа к выходу (спецификация: пол #3A2E2A, дорожка 8 стадов #D9D2C5).
local function buildFloor(folder, rng, layout, opts)
	local size = layout.size
	local half = size / 2
	local centerZ = layout.centerZ
	local circle = opts and opts.circle

	Props.part(folder, "Floor", V3(size + 4, 1, size + 4), CF(0, -0.5, centerZ), Ruin.floor, SLATE, { collide = true })

	-- Плиты-заплаты: пол не выглядит одной плоскостью.
	local patches = math.floor(size * size / 150)
	for _ = 1, patches do
		local x = (rng:NextNumber() - 0.5) * (size - 6)
		local z = centerZ + (rng:NextNumber() - 0.5) * (size - 6)
		local inside = not circle or math.sqrt(x * x + (z - centerZ) ^ 2) < circle - 3
		if inside and math.abs(x) > 5 then
			local w = 4 * rng:NextInteger(1, 2)
			local d = 4 * rng:NextInteger(1, 2)
			local tone = Ruin.floor:Lerp(Ruin.rubble, 0.12 + rng:NextNumber() * 0.25)
			Props.part(folder, "FloorPatch", V3(w - 0.2, 0.1, d - 0.2), CF(x, 0.03, z), Props.vary(tone, rng, 0.05), SLATE, { shadow = false })
		end
	end

	-- Дорожка из светлых плит: два ряда по 4 стада, плиты 2–3 в длину.
	local zEnd = opts and opts.pathEnd or layout.exitZ
	local z = layout.entryZ
	while z > zEnd + 0.5 do
		local length = math.min(2 + rng:NextNumber(), z - zEnd)
		for _, x in ipairs({ -2, 2 }) do
			if rng:NextNumber() > 0.04 then
				local color = Ruin.path
				if rng:NextNumber() < 0.18 then
					color = color:Lerp(Ruin.rubble, 0.25 + rng:NextNumber() * 0.2)
				end
				local tilt = rng:NextNumber() < 0.08 and ANG(0, 0, (rng:NextNumber() - 0.5) * 0.08) or CFrame.identity
				Props.part(folder, "PathStone", V3(3.85, 0.12, length - 0.12), CF(x, 0.06, z - length / 2) * tilt, Props.vary(color, rng, 0.04), nil, { shadow = false })
			end
		end
		z -= length
	end
end

-- Каменное «дно» острова под комнатой.
local function islandUnderside(folder, rng, layout)
	local w = layout.size + 4
	local y = -1
	for layer = 1, 4 do
		w *= 0.74
		local h = 4 + layer * 2
		Props.part(folder, "IslandRock", V3(w, h, w * 0.9), CF((rng:NextNumber() - 0.5) * 4, y - h / 2, layout.centerZ + (rng:NextNumber() - 0.5) * 4),
			Props.vary(layer < 3 and Ruin.rubble or Ruin.floor, rng, 0.05), SLATE, { shadow = false })
		y -= h
	end
end

-- ===== Руины по периметру =====

-- Остаток стены: ряды блоков, верх рваный (высота по шуму). Возвращает
-- самую высокую точку для кубиков над руинами.
local function wallRemnant(folder, rng, axis: string, fixed: number, from: number, to: number, maxHeight: number)
	local seed = rng:NextNumber() * 100
	local thickness = 2.4
	local x = from
	local peak = 0
	while x < to do
		local width = math.min(2 + rng:NextInteger(0, 2), to - x)
		local mid = x + width / 2
		local n = (math.noise(mid * 0.18, seed) + 0.5)
		local h = math.clamp(math.floor(n * maxHeight / ROW + 0.5) * ROW, ROW, maxHeight)
		local y = 0
		local row = 1
		while y < h do
			local rh = math.min(ROW, h - y)
			local inset = (rng:NextNumber() - 0.5) * 0.35
			local cf = axis == "x" and CF(mid, y + rh / 2, fixed + inset) or CF(fixed + inset, y + rh / 2, mid)
			local size = axis == "x" and V3(width - 0.06, rh, thickness) or V3(thickness, rh, width - 0.06)
			block(folder, "WallStone", size, cf, stoneColor(rng, row), true)
			y += rh
			row += 1
		end
		-- Выпавший камень у подножия.
		if rng:NextNumber() < 0.18 then
			local s = 1 + rng:NextNumber()
			local side = rng:NextNumber() < 0.5 and -1 or 1
			local p = axis == "x" and V3(mid, s / 2, fixed + side * 2.2) or V3(fixed + side * 2.2, s / 2, mid)
			block(folder, "FallenStone", V3(s, s, s), CF(p) * ANG(rng:NextNumber(), rng:NextNumber(), rng:NextNumber()), stoneColor(rng, 3))
		end
		peak = math.max(peak, h)
		x += width
	end
	return peak
end

-- Периметр квадратной комнаты: остатки стен, скопления обломков, башенки в
-- углах, парящие кубики, невидимый барьер. doors = { entry = bool, exit = bool }.
local function ruinPerimeter(folder, rng, layout, doors, opts)
	local half = layout.size / 2
	local centerZ = layout.centerZ
	local gapHalf = Rooms.Doorway.width / 2 + 4
	local maxWall = (opts and opts.wallHeight) or 14

	local hoverFolder = Instance.new("Folder")
	hoverFolder.Name = "Hover"
	hoverFolder.Parent = folder

	local function hoverAbove(position: Vector3, top: number)
		if rng:NextNumber() < 0.55 then
			for _ = 1, rng:NextInteger(1, 3) do
				local y = math.max(5, top) + 1.5 + rng:NextNumber() * 3
				Props.hoverCube(hoverFolder, V3(position.X + (rng:NextNumber() - 0.5) * 3, y, position.Z + (rng:NextNumber() - 0.5) * 3), Props.vary(Ruin.rubble, rng, 0.06), rng)
			end
		end
	end

	-- Линия периметра: участки по 6–10 стадов — остаток стены или обломки.
	local function line(axis: string, fixed: number, from: number, to: number, inward: number, gap: boolean)
		local cursor = from
		while cursor < to do
			local length = math.min(6 + rng:NextInteger(0, 4), to - cursor)
			local a, b = cursor, cursor + length
			cursor = b
			if gap and b > -gapHalf and a < gapHalf then
				-- Проём двери: здесь маяки и рама, руин нет.
				if a < -gapHalf then
					b = -gapHalf
				elseif b > gapHalf then
					a = gapHalf
				else
					continue
				end
			end
			if b - a < 1 then
				continue
			end
			local mid = (a + b) / 2
			local position = axis == "x" and V3(mid, 0, fixed) or V3(fixed, 0, mid)
			if rng:NextNumber() < 0.5 then
				local top = wallRemnant(folder, rng, axis, fixed + inward * 0.4, a, b, rng:NextInteger(2, math.floor(maxWall / ROW)) * ROW)
				hoverAbove(position, top)
			else
				-- Скопления на 22–24 стадах от центра (в масштабе комнаты — у края).
				local count = math.max(1, math.floor((b - a) / 3.5))
				local top = 0
				for k = 1, count do
					local along = a + (k - 0.5) * (b - a) / count + (rng:NextNumber() - 0.5)
					local depth = fixed + inward * (rng:NextNumber() * 2.5)
					local p = axis == "x" and V3(along, 0, depth) or V3(depth, 0, along)
					top = math.max(top, Props.ruinCluster(folder, p, rng, RUBBLE, 8))
				end
				-- За обломками всё равно невысокая кладка: двор не «дырявый».
				wallRemnant(folder, rng, axis, fixed - inward * 1.2, a, b, ROW * 2)
				hoverAbove(position, top)
			end
		end
	end

	line("z", -half, centerZ - half, centerZ + half, 1, false)
	line("z", half, centerZ - half, centerZ + half, -1, false)
	if not (opts and opts.noEntryWall) then
		line("x", layout.entryZ, -half, half, -1, doors.entry)
	end
	if not (opts and opts.noExitWall) then
		line("x", layout.exitZ, -half, half, 1, doors.exit)
	end

	-- Угловые башенки — самые высокие остатки.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local x, z = sx * (half - 1), centerZ + sz * (half - 1)
			local h = 12 + rng:NextInteger(0, 2) * ROW
			local y = 0
			local row = 1
			while y < h do
				local w = 5.4 - row * 0.12
				block(folder, "CornerTower", V3(w, ROW, w), CF(x, y + ROW / 2, z) * ANG(0, (rng:NextNumber() - 0.5) * 0.06, 0), stoneColor(rng, row), true)
				y += ROW
				row += 1
			end
			hoverAbove(V3(x, 0, z), h)
		end
	end

	-- Невидимый барьер по контуру (проёмы дверей открыты — их закрывают двери).
	local gap = { from = -Rooms.Doorway.width / 2, to = Rooms.Doorway.width / 2, height = Rooms.Doorway.height }
	barrier(folder, "z", -half - 1.5, centerZ - half - 2, centerZ + half + 2)
	barrier(folder, "z", half + 1.5, centerZ - half - 2, centerZ + half + 2)
	barrier(folder, "x", layout.entryZ + 1.5, -half - 2, half + 2, doors.entry and gap or nil)
	barrier(folder, "x", layout.exitZ - 1.5, -half - 2, half + 2, doors.exit and gap or nil)
end

-- ===== Двери и маяки =====

-- Маяк у проёма: столб 3×15×3 из сланца, сверху неоновый куб #C98B4A со
-- светом (яркость 3, радиус 20).
local function beacon(folder, rng, x: number, z: number)
	local y = 0
	local row = 1
	while y < 15 do
		local h = math.min(ROW, 15 - y)
		block(folder, "BeaconStone", V3(3 + (row % 2) * 0.2, h, 3 + (row % 2) * 0.2), CF(x, y + h / 2, z), Props.vary(Ruin.rubble, rng, 0.06), true)
		y += h
		row += 1
	end
	block(folder, "BeaconCap", V3(3.6, 0.5, 3.6), CF(x, 15.25, z), Props.vary(Ruin.floor, rng, 0.05))
	local cube = Props.part(folder, "BeaconLight", V3(2, 2, 2), CF(x, 16.5, z), Ruin.beacon, Enum.Material.Neon, { shadow = false })
	local light = Instance.new("PointLight")
	light.Color = Ruin.beacon
	light.Brightness = 3
	light.Range = 20
	light.Shadows = false
	light.Parent = cube
	return cube
end

-- Рама проёма: маяки по бокам, перемычка, порог.
local function doorway(folder, rng, z: number, inward: number)
	local width = Rooms.Doorway.width
	local height = Rooms.Doorway.height
	for _, sx in ipairs({ -1, 1 }) do
		beacon(folder, rng, sx * (width / 2 + 1.5), z + inward * 0.2)
	end
	block(folder, "DoorLintel", V3(width + 6, 2, 3.4), CF(0, height + 1, z), Props.vary(Ruin.floor, rng, 0.05), true)
	block(folder, "DoorLintelTop", V3(width + 2, 1, 3), CF(0, height + 2.5, z), Props.vary(Ruin.rubble, rng, 0.05))
	Props.part(folder, "DoorStep", V3(width + 2, 0.2, 3.4), CF(0, 0.1, z), Props.vary(Ruin.path, rng, 0.04), SLATE, { shadow = false })
end

-- Двустворчатая деревянная дверь в железной оковке: доски, три полосы с
-- заклёпками, диагональные распорки, кольца-ручки. Сквозь неё ничего не
-- видно. Створки распахиваются в сторону swing (±Z, в коридор), физику
-- даёт невидимый блокер.
local function makeDoor(parent, rng, z: number, swing: number)
	local width = Rooms.Doorway.width
	local height = Rooms.Doorway.height
	local leafW = width / 2
	local model = Instance.new("Model")
	model.Name = "Door"

	local blocker = Props.part(model, "Blocker", V3(width, height, 1.4), CF(0, height / 2, z), Env.wood, nil, { collide = true, query = true, transparency = 1, shadow = false })

	local leaves = {}
	for _, side in ipairs({ -1, 1 }) do
		local leaf = Instance.new("Model")
		leaf.Name = "Leaf"
		local cx = side * leafW / 2
		local planks = 4
		local pw = leafW / planks
		for index = 1, planks do
			local x = cx - leafW / 2 + (index - 0.5) * pw
			local color = Props.vary(Props.pick(rng, { { Env.wood, 3 }, { Env.woodDark, 2 }, { Env.woodLight, 1 } }), rng, 0.05)
			Props.part(leaf, "Plank", V3(pw - 0.08, height - 0.1, 0.7), CF(x, height / 2, z), color, Enum.Material.Wood)
		end
		-- Диагональная распорка между нижней и средней полосами (с обеих сторон).
		local y0, y1 = 1.6, height * 0.5
		local diagonal = math.sqrt((leafW - 0.8) ^ 2 + (y1 - y0) ^ 2)
		local angle = math.atan2(leafW - 0.8, y1 - y0) * side
		for _, face in ipairs({ -1, 1 }) do
			Props.part(leaf, "Brace", V3(0.55, diagonal, 0.2), CF(cx, (y0 + y1) / 2, z + face * 0.42) * ANG(0, 0, angle), Env.woodDark, Enum.Material.Wood, { shadow = false })
		end
		-- Железные полосы с заклёпками.
		for _, y in ipairs({ 1.6, height * 0.5, height - 1.6 }) do
			Props.part(leaf, "Band", V3(leafW - 0.06, 0.6, 0.9), CF(cx, y, z), Env.iron, Enum.Material.Metal)
			for k = 0, 3 do
				Props.part(leaf, "Rivet", V3(0.24, 0.24, 1.02), CF(cx - leafW / 2 + 0.5 + k * (leafW - 1) / 3, y, z), Env.ironLight, Enum.Material.Metal, { shadow = false })
			end
		end
		-- Оковка по краю створки.
		Props.part(leaf, "EdgeIron", V3(0.3, height - 0.1, 0.85), CF(side * (leafW - 0.15), height / 2, z), Env.iron, Enum.Material.Metal, { shadow = false })
		-- Кольцо-ручка у середины.
		for _, face in ipairs({ -1, 1 }) do
			Props.part(leaf, "HandlePlate", V3(0.7, 0.7, 0.12), CF(side * 0.9, height * 0.42, z + face * 0.41), Env.ironLight, Enum.Material.Metal, { shadow = false })
			Props.part(leaf, "Handle", V3(0.18, 1.0, 0.18), CF(side * 0.9, height * 0.42 - 0.55, z + face * 0.55), Env.ironLight, Enum.Material.Metal, { shadow = false })
		end
		leaf.Parent = model
		local hinge = CF(side * leafW, 0, z)
		table.insert(leaves, { model = leaf, side = side, hinge = hinge, relative = hinge:ToObjectSpace(leaf:GetPivot()) })
	end
	model.PrimaryPart = blocker
	model:SetAttribute("Open", false)

	local alpha = Instance.new("NumberValue")
	alpha.Name = "Alpha"
	alpha.Parent = model
	alpha.Changed:Connect(function(value)
		for _, leaf in ipairs(leaves) do
			-- Внутренний край створки уходит в сторону swing.
			local angle = swing * leaf.side * (math.pi / 2) * value
			leaf.model:PivotTo(leaf.hinge * ANG(0, angle, 0) * leaf.relative)
		end
		blocker.CanCollide = value < 0.5
		blocker.CanQuery = value < 0.5
	end)

	local door = { model = model, open = false, locked = false, x = 0, z = z }

	function door.set(open: boolean, instant: boolean?)
		door.open = open
		model:SetAttribute("Open", open)
		local goal = open and 1 or 0
		if instant then
			alpha.Value = goal
		else
			TweenService:Create(alpha, TweenInfo.new(open and 0.6 or 0.45, open and Enum.EasingStyle.Back or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = goal }):Play()
		end
	end

	model.Parent = parent
	return door
end

-- ===== Коридор =====

-- Закрытый коридор между комнатами: стены из кладки, потолок на балках,
-- факелы, светлая дорожка. Камера упирается в потолок (CanQuery).
local function buildCorridor(parent, rng, index: number, fromZ: number, toZ: number)
	local C = Rooms.Corridor
	local folder = Instance.new("Folder")
	folder.Name = ("Corridor_%02d"):format(index)
	local length = fromZ - toZ
	local centerZ = (fromZ + toZ) / 2
	local inner = C.width / 2
	local wallX = inner + 1.2

	Props.part(folder, "Floor", V3(C.width + 6, 1, length + 0.2), CF(0, -0.5, centerZ), Ruin.floor, SLATE, { collide = true })
	local z = fromZ
	while z > toZ + 0.5 do
		local l = math.min(2 + rng:NextNumber(), z - toZ)
		for _, x in ipairs({ -2, 2 }) do
			Props.part(folder, "PathStone", V3(3.85, 0.12, l - 0.12), CF(x, 0.06, z - l / 2), Props.vary(Ruin.path:Lerp(Ruin.rubble, 0.15), rng, 0.05), nil, { shadow = false })
		end
		z -= l
	end

	for _, sx in ipairs({ -1, 1 }) do
		masonry(folder, rng, "z", sx * wallX, toZ, fromZ, C.height, 2.4, { collide = true })
		-- Плинтус из крупных камней.
		Props.part(folder, "Plinth", V3(1, 1, length), CF(sx * (inner + 0.1), 0.5, centerZ), Props.vary(Ruin.floor, rng, 0.04), SLATE, { shadow = false })
	end
	-- Потолок и балки.
	Props.part(folder, "Roof", V3(C.width + 6, 2, length), CF(0, C.height + 1, centerZ), Ruin.floor, SLATE, { collide = true })
	local beamZ = fromZ - 2
	while beamZ > toZ + 1 do
		Props.part(folder, "Beam", V3(C.width + 0.4, 0.9, 0.9), CF(0, C.height - 0.45, beamZ), Props.vary(Env.woodDark, rng, 0.05), Enum.Material.Wood, { shadow = false })
		for _, sx in ipairs({ -1, 1 }) do
			Props.part(folder, "BeamPost", V3(0.8, C.height - 0.9, 0.8), CF(sx * (inner - 0.2), (C.height - 0.9) / 2, beamZ), Props.vary(Env.woodDark, rng, 0.05), Enum.Material.Wood)
		end
		beamZ -= 7
	end
	-- Факелы попеременно слева и справа.
	local torchIndex = 0
	local torchZ = fromZ - 5
	while torchZ > toZ + 3 do
		torchIndex += 1
		local sx = torchIndex % 2 == 0 and 1 or -1
		Props.torch(folder, V3(sx * (inner - 0.1), 8, torchZ), V3(-sx, 0, 0))
		torchZ -= 9
	end
	-- Обломки и паутина времени: немного мусора у стен.
	for _ = 1, 4 do
		local sx = rng:NextNumber() < 0.5 and -1 or 1
		Props.rubble(folder, V3(sx * (inner - 1.2), 0, toZ + 2 + rng:NextNumber() * (length - 4)), rng, 3)
	end
	folder.Parent = parent
	return folder
end

-- ===== Ловушка: шипы =====

local function makeSpikePlate(parent, rng, position: Vector3)
	local plate = Props.part(parent, "SpikePlate", V3(5, 0.3, 5), CF(position.X, 0.2, position.Z), Env.iron, Enum.Material.Metal)
	Props.part(parent, "SpikeFrame", V3(5.6, 0.25, 5.6), CF(position.X, 0.14, position.Z), Env.ironLight, Enum.Material.Metal, { shadow = false })
	local needles = {}
	for ix = -1, 1 do
		for iz = -1, 1 do
			Props.part(parent, "SpikeHole", V3(0.7, 0.05, 0.7), CF(position.X + ix * 1.35, 0.36, position.Z + iz * 1.35), Env.void, nil, { shadow = false })
			local needle = Props.part(parent, "Needle", V3(0.4, 2.0, 0.4), CF(position.X + ix * 1.35, -1.3, position.Z + iz * 1.35), Env.ironLight, Enum.Material.Metal, { shadow = false })
			table.insert(needles, needle)
		end
	end
	return { plate = plate, needles = needles, position = V3(position.X, 0, position.Z), phase = "idle" }
end

-- idle: убраны, warn: плита тлеет и иглы дрожат, active: выехали.
function FloorBuilder.setSpikePhase(trap, phase: string)
	if trap.phase == phase then
		return
	end
	trap.phase = phase
	trap.plate:SetAttribute("Phase", phase)
	local plateColor = phase == "warn" and Env.flame or Env.iron
	TweenService:Create(trap.plate, TweenInfo.new(0.15), { Color = plateColor }):Play()
	trap.plate.Material = phase == "warn" and Enum.Material.Neon or Enum.Material.Metal
	for _, needle in ipairs(trap.needles) do
		local height = phase == "active" and 0.9 or (phase == "warn" and -0.65 or -1.3)
		local time = phase == "active" and 0.08 or 0.2
		TweenService:Create(needle, TweenInfo.new(time, Enum.EasingStyle.Quad), {
			Position = V3(needle.Position.X, height, needle.Position.Z),
			Color = phase == "active" and Env.bone or Env.ironLight,
		}):Play()
	end
end

-- ===== Костёр =====

local function makeCampfire(parent, rng, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "Campfire"

	local ring = Props.part(model, "Ring", V3(5.2, 0.4, 5.2), CF(position.X, 0.2, position.Z), Env.stoneDark)
	for index = 1, 10 do
		local angle = (index / 10) * math.pi * 2
		Props.part(model, "Stone", V3(1.2, 0.9 + rng:NextNumber() * 0.4, 1.2),
			CF(position.X + math.cos(angle) * 2.4, 0.5, position.Z + math.sin(angle) * 2.4) * ANG(0, -angle, 0),
			Props.vary(Env.stoneLight, rng), nil, { collide = true })
	end
	for index = 1, 4 do
		local angle = (index / 4) * math.pi * 2 + 0.3
		Props.part(model, "Log", V3(0.6, 0.6, 3.0),
			CF(position.X, 0.75, position.Z) * ANG(0, angle, 0) * ANG(math.rad(-22), 0, 0),
			Props.vary(Env.wood, rng), Enum.Material.Wood)
	end
	Props.part(model, "Coals", V3(2.4, 0.3, 2.4), CF(position.X, 0.45, position.Z), Env.flame, Enum.Material.Neon, { shadow = false })
	local _, light = Props.flame(model, V3(position.X, 0.8, position.Z), 2.2, { range = 26, brightness = 1.8, shadows = true })
	light.Name = "CampLight"

	-- Взаимодействие: удерживать E три секунды (приложение Е).
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CampfirePrompt"
	prompt.ActionText = "Отдохнуть у костра"
	prompt.ObjectText = "Костёр"
	prompt.HoldDuration = Rooms.Campfire.interact
	prompt.MaxActivationDistance = Rooms.Campfire.distance + 2
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = ring

	model.PrimaryPart = ring
	model:SetAttribute("IsCampfire", true)
	model.Parent = parent
	return model, prompt
end

-- ===== Сундук =====

-- Три редкости сундуков: у каждой своя оковка. Сейчас в игре — обычный.
FloorBuilder.ChestTiers = {
	common = { trim = Env.iron, trimLight = Env.ironLight, lock = Env.ironLight, glow = Env.ember },
	rare = { trim = Palette.Material.steelDark, trimLight = Palette.Material.guard, lock = Palette.Material.guard, glow = Palette.Memory },
	epic = { trim = Env.gold:Lerp(Env.iron, 0.35), trimLight = Env.gold, lock = Env.gold, glow = Env.gold },
}

-- Обычный сундук: дощатый короб и выпуклая крышка, железная оковка по
-- рёбрам, полосы с заклёпками, накладной замок, боковые ручки.
-- Крышка — модель Lid, её откидывает openChestVisual вокруг заднего ребра.
function FloorBuilder.makeChest(parent, position: Vector3, tierId: string?)
	local tier = FloorBuilder.ChestTiers[tierId or "common"] or FloorBuilder.ChestTiers.common
	local model = Instance.new("Model")
	model.Name = "Chest"
	local rng = Random.new(31)
	local W, D, H = 3.8, 2.5, 1.8 -- короб
	local x, z = position.X, position.Z
	local function wood(rowIndex)
		local base = rowIndex % 2 == 0 and Env.wood or Env.woodLight:Lerp(Env.wood, 0.45)
		return Props.vary(base, rng, 0.05)
	end

	local base = Props.part(model, "Base", V3(W - 0.2, H - 0.1, D - 0.2), CF(x, H / 2 + 0.05, z), Env.woodDark, Enum.Material.Wood, { collide = true })
	-- Доски короба: три ряда по периметру (спереди и сзади, по бокам).
	for row = 0, 2 do
		local y = 0.15 + row * 0.55 + 0.275
		for _, sz in ipairs({ -1, 1 }) do
			Props.part(model, "Board", V3(W, 0.5, 0.18), CF(x, y, z + sz * D / 2), wood(row), Enum.Material.Wood, { shadow = false })
		end
		for _, sx in ipairs({ -1, 1 }) do
			Props.part(model, "Board", V3(0.18, 0.5, D), CF(x + sx * W / 2, y, z), wood(row + 1), Enum.Material.Wood, { shadow = false })
		end
	end
	-- Ножки-полозья.
	for _, sx in ipairs({ -1, 1 }) do
		Props.part(model, "Foot", V3(0.5, 0.18, D + 0.1), CF(x + sx * (W / 2 - 0.35), 0.09, z), tier.trim, Enum.Material.Metal, { shadow = false })
	end
	-- Оковка рёбер: вертикальные уголки и горизонтальные пояса.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			Props.part(model, "CornerIron", V3(0.32, H + 0.02, 0.32), CF(x + sx * W / 2, H / 2 + 0.05, z + sz * D / 2), tier.trim, Enum.Material.Metal, { shadow = false })
			Props.part(model, "CornerCap", V3(0.4, 0.3, 0.4), CF(x + sx * W / 2, H - 0.1, z + sz * D / 2), tier.trimLight, Enum.Material.Metal, { shadow = false })
		end
	end
	for _, y in ipairs({ 0.22, H - 0.05 }) do
		Props.part(model, "BandFront", V3(W + 0.08, 0.22, 0.1), CF(x, y, z + D / 2 + 0.08), tier.trim, Enum.Material.Metal, { shadow = false })
		Props.part(model, "BandBack", V3(W + 0.08, 0.22, 0.1), CF(x, y, z - D / 2 - 0.08), tier.trim, Enum.Material.Metal, { shadow = false })
		for _, sx in ipairs({ -1, 1 }) do
			Props.part(model, "BandSide", V3(0.1, 0.22, D + 0.08), CF(x + sx * (W / 2 + 0.08), y, z), tier.trim, Enum.Material.Metal, { shadow = false })
		end
	end
	-- Две вертикальные полосы спереди с заклёпками.
	for _, sx in ipairs({ -1, 1 }) do
		local bx = x + sx * W * 0.28
		Props.part(model, "Strap", V3(0.34, H, 0.1), CF(bx, H / 2 + 0.05, z + D / 2 + 0.1), tier.trim, Enum.Material.Metal, { shadow = false })
		for k = 0, 2 do
			Props.part(model, "Rivet", V3(0.14, 0.14, 0.1), CF(bx, 0.4 + k * 0.55, z + D / 2 + 0.16), tier.trimLight, Enum.Material.Metal, { shadow = false })
		end
		-- Ручка сбоку: скоба на пластине.
		Props.part(model, "HandlePlate", V3(0.08, 0.5, 0.8), CF(x + sx * (W / 2 + 0.14), H * 0.6, z), tier.trim, Enum.Material.Metal, { shadow = false })
		Props.part(model, "Handle", V3(0.12, 0.12, 0.9), CF(x + sx * (W / 2 + 0.32), H * 0.6 - 0.25, z), tier.trimLight, Enum.Material.Metal, { shadow = false })
	end

	-- Крышка: три ступени «свода» из досок + оковка, вращается целиком.
	local lid = Instance.new("Model")
	lid.Name = "Lid"
	local lidBase = H + 0.05
	local layers = { { W, 0.4, D }, { W, 0.3, D * 0.78 }, { W, 0.25, D * 0.45 } }
	local y = lidBase
	for index, size in ipairs(layers) do
		local part = Props.part(lid, index == 1 and "LidCore" or "LidBoard", V3(size[1] - 0.04, size[2], size[3]), CF(x, y + size[2] / 2, z), wood(index), Enum.Material.Wood)
		if index == 1 then
			lid.PrimaryPart = part
		end
		y += size[2]
	end
	for _, sx in ipairs({ -1, 1 }) do
		-- Торцы крышки обиты железом, полосы через свод — продолжение передних.
		Props.part(lid, "LidEnd", V3(0.14, 0.95, D + 0.04), CF(x + sx * (W / 2 + 0.03), lidBase + 0.45, z), tier.trim, Enum.Material.Metal, { shadow = false })
		local bx = x + sx * W * 0.28
		local yy = lidBase
		for _, size in ipairs(layers) do
			Props.part(lid, "LidStrap", V3(0.34, size[2] + 0.04, size[3] + 0.06), CF(bx, yy + size[2] / 2, z), tier.trim, Enum.Material.Metal, { shadow = false })
			yy += size[2]
		end
	end
	Props.part(lid, "LidRim", V3(W + 0.1, 0.16, 0.12), CF(x, lidBase + 0.08, z + D / 2 + 0.06), tier.trimLight, Enum.Material.Metal, { shadow = false })
	-- Накладной замок: пластина, скважина, петля на крышке.
	Props.part(lid, "Hasp", V3(0.36, 0.55, 0.1), CF(x, lidBase - 0.05, z + D / 2 + 0.14), tier.trimLight, Enum.Material.Metal, { shadow = false })
	lid.Parent = model
	local lock = Props.part(model, "Lock", V3(0.75, 0.75, 0.2), CF(x, H - 0.45, z + D / 2 + 0.16), tier.lock, Enum.Material.Metal)
	Props.part(model, "Keyhole", V3(0.14, 0.3, 0.06), CF(x, H - 0.5, z + D / 2 + 0.28), Env.void, nil, { shadow = false })

	-- Лицевая сторона смотрит в +Z (к входу на арену); крышку откидывает
	-- openChestVisual вокруг заднего верхнего ребра (−Z).
	model:SetAttribute("HingeZ", z - D / 2)
	model:SetAttribute("HingeY", lidBase)
	lock.Name = "Lock"

	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = tier.glow
	glow.Brightness = 1.4
	glow.Range = 14
	glow.Shadows = false
	glow.Parent = base

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChestPrompt"
	prompt.ActionText = "Открыть"
	prompt.ObjectText = "Сундук"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = base

	model.PrimaryPart = base
	model:SetAttribute("IsChest", true)
	model:SetAttribute("Opened", false)
	model:SetAttribute("FloorId", 1)
	model:SetAttribute("Tier", tierId or "common")
	model.Parent = parent
	return model, prompt
end

-- ===== Общий декор =====

local function scatterGround(folder, rng, layout, count: number, kinds)
	local half = layout.size / 2 - 5
	for _ = 1, count do
		local x = (rng:NextNumber() - 0.5) * 2 * half
		local z = layout.centerZ + (rng:NextNumber() - 0.5) * 2 * half
		if math.abs(x) < 4.5 then
			x = x < 0 and x - 5 or x + 5 -- дорожку не засоряем
		end
		local kind = Props.pick(rng, kinds)
		if kind == "grass" then
			Props.grass(folder, V3(x, 0, z), rng)
		elseif kind == "rubble" then
			Props.rubble(folder, V3(x, 0, z), rng, 3)
		elseif kind == "stain" then
			Props.stain(folder, V3(x, 0, z), rng)
		elseif kind == "sword" then
			Props.fallenSword(folder, V3(x, 0, z), rng)
		elseif kind == "ruin" then
			Props.ruinCluster(folder, V3(x, 0, z), rng, RUBBLE, 3)
		end
	end
end

-- Деревянная рама с цепями: два столба и перекладина.
local function chainFrame(folder, rng, x: number, z: number, height: number, span: number)
	for _, sx in ipairs({ -1, 1 }) do
		Props.part(folder, "FramePost", V3(0.9, height, 0.9), CF(x + sx * span / 2, height / 2, z), Props.vary(Env.woodDark, rng), Enum.Material.Wood, { collide = true })
	end
	Props.part(folder, "FrameBeam", V3(span + 1.6, 0.9, 1), CF(x, height + 0.2, z), Props.vary(Env.woodDark, rng), Enum.Material.Wood)
	for k = 1, 3 do
		local cx = x - span / 2 + k * span / 4
		Props.chain(folder, V3(cx, height - 0.3, z), 3 + rng:NextNumber() * 5, rng)
	end
end

-- Знамя на шесте.
local function bannerPole(folder, rng, x: number, z: number, facing: Vector3)
	Props.part(folder, "BannerPole", V3(0.5, 11, 0.5), CF(x, 5.5, z), Env.woodDark, Enum.Material.Wood, { collide = true })
	Props.part(folder, "BannerTop", V3(0.8, 0.8, 0.8), CF(x, 11.2, z), Env.iron, Enum.Material.Metal)
	Props.banner(folder, CFrame.lookAt(V3(x, 10.4, z), V3(x, 10.4, z) + facing) * CF(0, 0, -0.35), 6, Env.cloth, rng)
end

-- ===== Тематика комнат (по id из Rooms.Floor1) =====

local Themes = {}

-- Колодец во дворе: каменное кольцо, ворот и обломанная крыша.
local function well(folder, rng, position: Vector3)
	for index = 1, 12 do
		local angle = index / 12 * math.pi * 2
		block(folder, "WellStone", V3(1.6, 1.6 + rng:NextNumber() * 0.4, 1.1), CF(position + V3(math.cos(angle) * 2.4, 0.8, math.sin(angle) * 2.4)) * ANG(0, -angle, 0), stoneColor(rng, 2), true)
	end
	Props.part(folder, "WellDark", V3(3.6, 0.1, 3.6), CF(position + V3(0, 1.2, 0)), Env.void, nil, { shadow = false })
	for _, sx in ipairs({ -1, 1 }) do
		Props.part(folder, "WellPost", V3(0.5, 4.5, 0.5), CF(position + V3(sx * 2.4, 2.25, 0)), Env.woodDark, Enum.Material.Wood)
	end
	Props.part(folder, "WellAxle", V3(5.4, 0.35, 0.35), CF(position + V3(0, 3.8, 0)), Env.wood, Enum.Material.Wood)
	Props.part(folder, "WellRoof", V3(3.4, 0.3, 3.2), CF(position + V3(-0.6, 4.9, 0)) * ANG(0, 0, math.rad(-18)), Env.woodDark, Enum.Material.Wood)
	Props.part(folder, "WellBucket", V3(0.8, 0.8, 0.8), CF(position + V3(0.4, 2.6, 0)), Env.wood, Enum.Material.Wood)
end

-- Брошенная телега: короб, колесо отвалилось, борт сломан.
local function cart(folder, rng, cf: CFrame)
	Props.part(folder, "CartBed", V3(3.4, 0.4, 5.6), cf * CF(0, 1.3, 0) * ANG(0, 0, math.rad(8)), Env.wood, Enum.Material.Wood, { collide = true })
	Props.part(folder, "CartSide", V3(0.3, 1, 5.6), cf * CF(1.6, 1.9, 0) * ANG(0, 0, math.rad(8)), Env.woodDark, Enum.Material.Wood)
	Props.part(folder, "CartSide", V3(0.3, 0.8, 3.2), cf * CF(-1.5, 1.7, 1) * ANG(0, 0, math.rad(8)), Env.woodDark, Enum.Material.Wood)
	Props.part(folder, "CartWheel", V3(0.3, 2.4, 2.4), cf * CF(1.9, 1.2, -1.5) * ANG(0, 0, 0), Env.woodDark, Enum.Material.Wood, { shape = Enum.PartType.Cylinder })
	Props.part(folder, "CartWheel", V3(0.3, 2.4, 2.4), cf * CF(-3.0, 0.15, 1.4) * ANG(0, 0, math.rad(90)), Env.woodDark, Enum.Material.Wood, { shape = Enum.PartType.Cylinder })
	Props.part(folder, "CartShaft", V3(0.3, 0.3, 4.2), cf * CF(0.6, 0.4, -4.4) * ANG(math.rad(-10), 0.2, 0), Env.wood, Enum.Material.Wood)
	Props.crate(folder, (cf * CF(0.3, 1.5, 1.2)).Position, rng, 1.4)
end

-- Тренировочное чучело: столб, перекладина, мешок; часть сломана.
local function dummy(folder, rng, position: Vector3, broken: boolean)
	local tilt = broken and ANG(math.rad(25), rng:NextNumber() * 3, 0) or CFrame.identity
	local base = CF(position) * tilt
	Props.part(folder, "DummyPost", V3(0.5, 5, 0.5), base * CF(0, 2.5, 0), Env.woodDark, Enum.Material.Wood, { collide = true })
	Props.part(folder, "DummyArms", V3(3.2, 0.4, 0.4), base * CF(0, 3.8, 0), Env.wood, Enum.Material.Wood)
	Props.part(folder, "DummyBody", V3(1.6, 2, 1.1), base * CF(0, 3.2, 0), Env.sand:Lerp(Env.wood, 0.3), Enum.Material.Fabric)
	Props.part(folder, "DummyHead", V3(1, 1, 1), base * CF(0, 4.8, 0), Env.sand:Lerp(Env.wood, 0.2), Enum.Material.Fabric)
end

-- Рыночный прилавок: стойки, столешница, порванный навес.
local function stall(folder, rng, cf: CFrame)
	for _, c in ipairs({ { -2.4, -1.2 }, { 2.4, -1.2 }, { -2.4, 1.2 }, { 2.4, 1.2 } }) do
		local h = c[2] < 0 and 4.6 or 3.8
		Props.part(folder, "StallPost", V3(0.4, h, 0.4), cf * CF(c[1], h / 2, c[2]), Env.woodDark, Enum.Material.Wood)
	end
	Props.part(folder, "StallTable", V3(5.4, 0.35, 2.4), cf * CF(0, 1.7, 0), Env.wood, Enum.Material.Wood, { collide = true })
	for strip = -2, 2 do
		if rng:NextNumber() > 0.3 then
			local color = strip % 2 == 0 and Env.cloth or Env.sandLight
			Props.part(folder, "StallCloth", V3(1.05, 0.12, 3.0), cf * CF(strip * 1.05, 4.25, 0) * ANG(math.rad(15), 0, 0), Props.vary(color, rng, 0.06), Enum.Material.Fabric, { shadow = false })
		end
	end
	for _ = 1, 3 do
		local s = 0.4 + rng:NextNumber() * 0.4
		Props.part(folder, "Pot", V3(s, s * 1.2, s), cf * CF((rng:NextNumber() - 0.5) * 4, 1.9 + s * 0.6, (rng:NextNumber() - 0.5) * 1.4), Props.vary(Env.rust:Lerp(Env.sand, 0.4), rng), nil, { shadow = false })
	end
end

-- Поваленная статуя стража: блочная фигура лежит на боку у постамента.
local function fallenStatue(folder, rng, position: Vector3, yaw: number)
	local base = CF(position) * ANG(0, yaw, 0)
	block(folder, "Plinth", V3(4, 2, 4), base * CF(0, 1, 0), stoneColor(rng, 1), true)
	block(folder, "PlinthTop", V3(3.4, 0.6, 3.4), base * CF(0, 2.3, 0), stoneColor(rng, 4), true)
	block(folder, "StatueLegs", V3(1.6, 1.2, 1.6), base * CF(0, 3.2, 0), Env.stoneLight)
	local lying = base * CF(4.6, 0.9, 0.5) * ANG(0, 0.3, math.rad(90))
	block(folder, "StatueBody", V3(2.4, 3.2, 1.6), lying, Env.stoneLight, true)
	block(folder, "StatueHead", V3(1.3, 1.4, 1.3), lying * CF(0, 2.4, 0), Env.stoneLight:Lerp(Env.bone, 0.2))
	block(folder, "StatueSword", V3(0.4, 4.2, 0.3), lying * CF(1.6, 0.6, 0.4) * ANG(0, 0, 0.3), Env.stoneLight)
	block(folder, "StatueArm", V3(0.8, 2, 0.8), base * CF(-3, 0.4, 2.2) * ANG(0.4, 0.2, math.rad(80)), Env.stoneLight)
end

-- Главные ворота башни: высокий фасад во всю ширину двора, две башни по
-- бокам проёма, арка, знамёна. Сама дверь — общая makeDoor.
local function mainGate(folder, rng, layout)
	local half = layout.size / 2
	local z = layout.exitZ
	local door = Rooms.Doorway
	local towerX = door.width / 2 + 7
	-- Фасад: кладка 20 стадов с проёмом, верх рваный.
	for _, side in ipairs({ -1, 1 }) do
		local from, to = side < 0 and -half - 2 or towerX + 4, side < 0 and -towerX - 4 or half + 2
		masonry(folder, rng, "x", z - 1.6, from, to, 20, 3, { collide = true, ragged = true })
	end
	masonry(folder, rng, "x", z - 1.6, -towerX - 4, towerX + 4, 26, 3, { collide = true })
	-- Над проёмом кладку убираем: проём + арка.
	for _, part in ipairs(folder:GetChildren()) do
		if part:IsA("BasePart") and part.Name == "WallStone" and math.abs(part.Position.Z - (z - 1.6)) < 0.6
			and math.abs(part.Position.X) < door.width / 2 + 1.4 and part.Position.Y < door.height + 2 then
			part:Destroy()
		end
	end
	block(folder, "GateArch", V3(door.width + 4, 2.4, 4), CF(0, door.height + 1.2, z - 1.2), Props.vary(Ruin.path:Lerp(Ruin.rubble, 0.35), rng, 0.04), true)
	block(folder, "GateKeystone", V3(2.4, 3.2, 4.4), CF(0, door.height + 1.8, z - 1), Ruin.path:Lerp(Ruin.rubble, 0.2))
	-- Башни.
	for _, sx in ipairs({ -1, 1 }) do
		local tx = sx * towerX
		local y = 0
		local row = 1
		while y < 30 do
			block(folder, "GateTower", V3(8 - (row > 7 and 0.6 or 0), ROW, 8 - (row > 7 and 0.6 or 0)), CF(tx, y + ROW / 2, z - 2) * ANG(0, (rng:NextNumber() - 0.5) * 0.03, 0), stoneColor(rng, row), true)
			y += ROW
			row += 1
		end
		-- Зубцы.
		for _, c in ipairs({ { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }) do
			if rng:NextNumber() < 0.8 then
				block(folder, "Merlon", V3(2, 2, 2), CF(tx + c[1], 31, z - 2 + c[2]), stoneColor(rng, 5))
			end
		end
		Props.flame(folder, V3(tx, 31.2, z - 2), 2.2, { range = 40, brightness = 2.4 })
		-- Знамя на башне, к двору.
		Props.banner(folder, CFrame.lookAt(V3(tx, 24, z + 2.1), V3(tx, 24, z + 20)), 14, Env.cloth, rng)
		-- Разлом в башне: несколько камней у подножия.
		for _ = 1, 4 do
			local s = 1.2 + rng:NextNumber() * 1.5
			block(folder, "FallenStone", V3(s, s, s), CF(tx + (rng:NextNumber() - 0.5) * 9, s / 2, z + 3 + rng:NextNumber() * 4) * ANG(rng:NextNumber(), rng:NextNumber(), rng:NextNumber()), stoneColor(rng, 3), true)
		end
	end
end

-- 0. Двор крепости.
Themes[0] = function(folder, rng, layout)
	local half = layout.size / 2
	local cz = layout.centerZ
	mainGate(folder, rng, layout)

	-- Внешняя стена за спиной игрока: заваленные внешние ворота.
	masonry(folder, rng, "x", layout.entryZ + 1.6, -half - 2, half + 2, 15, 3, { collide = true, ragged = true })
	-- Завал по бокам от ворот: дорожка к старту свободна.
	for index = 1, 10 do
		local side = index % 2 == 0 and 1 or -1
		Props.ruinCluster(folder, V3(side * (7 + rng:NextNumber() * 12), 0, layout.entryZ - 2 - rng:NextNumber() * 3), rng, RUBBLE, 6)
	end
	Props.part(folder, "OuterGateBar", V3(12, 0.8, 0.8), CF(0, 7, layout.entryZ + 0.2) * ANG(0, 0, 0.3), Env.woodDark, Enum.Material.Wood)
	Props.part(folder, "OuterGateBar", V3(10, 0.8, 0.8), CF(1, 5, layout.entryZ + 0.1) * ANG(0, 0, -0.25), Env.woodDark, Enum.Material.Wood)

	-- Площадь: колодец в центре, рынок слева, телеги, плац с чучелами справа.
	well(folder, rng, V3(-11, 0, cz + 4))
	stall(folder, rng, CF(-half + 9, 0, cz + 14) * ANG(0, math.rad(90), 0))
	stall(folder, rng, CF(-half + 9, 0, cz + 2) * ANG(0, math.rad(90), 0))
	stall(folder, rng, CF(-half + 9, 0, cz - 10) * ANG(0, math.rad(80), 0))
	cart(folder, rng, CF(-16, 0, cz - 16) * ANG(0, 0.5, 0))
	cart(folder, rng, CF(19, 0, cz + 20) * ANG(0, -1.2, 0))
	for index, p in ipairs({ V3(16, 0, cz - 4), V3(21, 0, cz - 2), V3(18, 0, cz + 3), V3(24, 0, cz + 5) }) do
		dummy(folder, rng, p, index % 2 == 0)
	end
	Props.weaponRack(folder, CFrame.lookAt(V3(half - 3, 0, cz - 2), V3(0, 0, cz - 2)), rng)
	fallenStatue(folder, rng, V3(11, 0, cz + 15), 0.4)
	Props.deadTree(folder, V3(-half + 8, 0, cz - half + 14), rng, 1.6)
	Props.deadTree(folder, V3(half - 9, 0, cz - half + 16), rng, 1.3)
	Props.tent(folder, CF(half - 10, 0, cz + half - 12) * ANG(0, math.rad(-90), 0), rng)
	for _ = 1, 4 do
		Props.barrel(folder, V3(-half + 5 + rng:NextNumber() * 4, 0, cz + 18 + rng:NextNumber() * 6), rng)
	end
	for _ = 1, 5 do
		Props.crate(folder, V3(half - 5 - rng:NextNumber() * 5, 0, cz - 18 - rng:NextNumber() * 6), rng, 1.2 + rng:NextNumber() * 0.6)
	end
	-- Остывшее кострище и брошенные доспехи — следы последних защитников.
	Props.part(folder, "AshPit", V3(4, 0.1, 4), CF(6, 0.04, cz - 10), Env.void:Lerp(Ruin.floor, 0.4), nil, { shadow = false })
	for index = 1, 7 do
		local a = index / 7 * math.pi * 2
		block(folder, "AshStone", V3(0.9, 0.6, 0.9), CF(6 + math.cos(a) * 2.2, 0.3, cz - 10 + math.sin(a) * 2.2), stoneColor(rng, 2))
	end
	Props.armorPile(folder, V3(9, 0, cz - 13), rng)
	Props.armorPile(folder, V3(-6, 0, cz + 20), rng)
	bannerPole(folder, rng, -8.5, layout.exitZ + 12, V3(1, 0, 0))
	bannerPole(folder, rng, 8.5, layout.exitZ + 12, V3(-1, 0, 0))
	-- Песок, занёсший плиты: светлые наносы.
	for _ = 1, 14 do
		local x = (rng:NextNumber() - 0.5) * (layout.size - 10)
		local z = cz + (rng:NextNumber() - 0.5) * (layout.size - 10)
		Props.part(folder, "SandDrift", V3(3 + rng:NextNumber() * 5, 0.15, 2 + rng:NextNumber() * 4), CF(x, 0.07, z) * ANG(0, rng:NextNumber() * 3, 0), Props.vary(Env.sand, rng, 0.05), Enum.Material.Sand, { shadow = false })
	end
	scatterGround(folder, rng, layout, 30, { { "grass", 4 }, { "rubble", 3 }, { "stain", 1 }, { "sword", 1 }, { "ruin", 2 } })
end

-- 1. Двор стражи: мёртвое дерево, брошенные доспехи.
Themes[1] = function(folder, rng, layout)
	local half = layout.size / 2
	Props.deadTree(folder, V3(half - 9, 0, layout.centerZ + half - 10), rng, 1.4)
	Props.armorPile(folder, V3(-14, 0, layout.centerZ - 4), rng)
	Props.armorPile(folder, V3(16, 0, layout.centerZ + 12), rng)
	Props.crate(folder, V3(-half + 6, 0, layout.centerZ + half - 7), rng)
	Props.crate(folder, V3(-half + 8.2, 0, layout.centerZ + half - 6.5), rng, 1.6)
	scatterGround(folder, rng, layout, 22, { { "grass", 4 }, { "rubble", 3 }, { "stain", 2 }, { "sword", 1 }, { "ruin", 1 } })
end

-- 2. Тёмный проход: рамы с цепями, обломанные тумбы.
Themes[2] = function(folder, rng, layout)
	local half = layout.size / 2
	chainFrame(folder, rng, -half + 9, layout.centerZ + 10, 10, 6)
	chainFrame(folder, rng, half - 9, layout.centerZ - 10, 10, 6)
	for _, side in ipairs({ -1, 1 }) do
		for index = 1, 3 do
			local z = layout.centerZ + (index - 2) * 18
			local h = 2 + rng:NextNumber() * 4
			block(folder, "BrokenPillar", V3(3, h, 3), CF(side * (half - 7), h / 2, z) * ANG(0, rng:NextNumber(), 0.06), stoneColor(rng, 2), true)
		end
	end
	Props.deadTree(folder, V3(-half + 8, 0, layout.centerZ - half + 9), rng, 1.1)
	scatterGround(folder, rng, layout, 26, { { "rubble", 4 }, { "stain", 3 }, { "grass", 2 }, { "sword", 1 }, { "ruin", 1 } })
end

-- 3. Оружейная: стойки с оружием, наковальни, ящики, колонны.
Themes[3] = function(folder, rng, layout)
	local half = layout.size / 2
	for _, side in ipairs({ -1, 1 }) do
		for index = -1, 1 do
			local z = layout.centerZ + index * 14 + 7
			Props.weaponRack(folder, CFrame.lookAt(V3(side * (half - 5), 0, z), V3(0, 0, z)), rng)
		end
	end
	Props.anvil(folder, V3(-half + 8, 0, layout.centerZ - half + 8), rng)
	Props.anvil(folder, V3(half - 9, 0, layout.centerZ + half - 11), rng)
	for index = 1, 4 do
		Props.crate(folder, V3(half - 6 - (index % 2) * 2.4, 0, layout.centerZ - half + 6 + index * 2.2), rng)
	end
	Props.barrel(folder, V3(-half + 6, 0, layout.centerZ + half - 7), rng)
	Props.barrel(folder, V3(-half + 8.5, 0, layout.centerZ + half - 6.2), rng)
	scatterGround(folder, rng, layout, 16, { { "rubble", 2 }, { "grass", 2 }, { "sword", 2 }, { "stain", 1 } })
end

-- 4. Отдых. Костёр: лавки вокруг огня, шатёр с ящиками, фонари, ковёр.
Themes[4] = function(folder, rng, layout, room)
	local half = layout.size / 2
	local c = V3(0, 0, layout.centerZ)
	room.campfire, room.campfirePrompt = makeCampfire(folder, rng, c)
	for index = 0, 3 do
		local angle = index * math.pi / 2 + math.pi / 4
		local position = c + V3(math.cos(angle) * 7.5, 0, math.sin(angle) * 7.5)
		Props.bench(folder, CFrame.lookAt(position, c), rng)
	end
	Props.tent(folder, CF(-half + 9, 0, layout.centerZ - half + 8), rng)
	Props.crate(folder, V3(-half + 6, 0, layout.centerZ - half + 6), rng)
	Props.crate(folder, V3(-half + 8.3, 0, layout.centerZ - half + 6.5), rng, 1.5)
	Props.crate(folder, V3(-half + 6, 2.2, layout.centerZ - half + 6), rng, 1.3)
	Props.barrel(folder, V3(half - 6, 0, layout.centerZ + half - 8), rng)
	Props.barrel(folder, V3(half - 8.4, 0, layout.centerZ + half - 6.5), rng)
	Props.lanternPost(folder, V3(half - 5, 0, layout.centerZ - half + 5), V3(-1, 0, 1), rng)
	Props.lanternPost(folder, V3(-half + 5, 0, layout.centerZ + half - 5), V3(1, 0, -1), rng)
	Props.rug(folder, V3(0, 0, layout.centerZ + half - 9))
	bannerPole(folder, rng, -half + 5, layout.centerZ + 2, V3(1, 0, 0))
	scatterGround(folder, rng, layout, 8, { { "grass", 4 }, { "rubble", 1 } })
end

-- 5. Цепной зал: рамы с тяжёлыми цепями, шипы, колонны.
Themes[5] = function(folder, rng, layout)
	local half = layout.size / 2
	for _, p in ipairs({ { -half + 9, 18 }, { half - 9, 6 }, { -half + 9, -8 }, { half - 9, -20 } }) do
		chainFrame(folder, rng, p[1], layout.centerZ + p[2], 11, 7)
	end
	scatterGround(folder, rng, layout, 18, { { "rubble", 3 }, { "stain", 3 }, { "grass", 1 }, { "ruin", 1 } })
end

-- 6. Последние ворота: кромка рассыпается, кубики летят вверх.
Themes[6] = function(folder, rng, layout)
	local half = layout.size / 2
	Props.deadTree(folder, V3(-half + 9, 0, layout.centerZ + 6), rng, 1.5)
	Props.armorPile(folder, V3(10, 0, layout.centerZ - 18), rng)
	for _ = 1, 30 do
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local position = V3(side * (half + 2 + rng:NextNumber() * 10), 8 + rng:NextNumber() * 22, layout.centerZ + (rng:NextNumber() - 0.5) * layout.size)
		Props.floatCube(folder, position, 0.8 + rng:NextNumber() * 2.4, stoneColor(rng, 4), rng)
	end
	for _ = 1, 16 do
		local side = rng:NextNumber() < 0.5 and -1 or 1
		Props.riseCube(folder, V3(side * (half - 1), 3 + rng:NextNumber() * 6, layout.centerZ + (rng:NextNumber() - 0.5) * layout.size), 0.8 + rng:NextNumber(), stoneColor(rng, 3), rng)
	end
	scatterGround(folder, rng, layout, 26, { { "rubble", 4 }, { "grass", 2 }, { "stain", 2 }, { "sword", 1 }, { "ruin", 2 } })
end

-- ===== Комната =====

local function newRoom(spec, layout, folder)
	return {
		index = layout.index,
		id = spec.id,
		kind = layout.kind,
		name = spec.name,
		size = layout.size,
		centerZ = layout.centerZ,
		entryZ = layout.entryZ,
		exitZ = layout.exitZ,
		folder = folder,
		waves = spec.waves or {},
		bossTypeId = spec.bossTypeId,
		state = "idle",
		waveIndex = 0,
		enemies = {},
		obstacles = {},
		spikes = nil,
	}
end

local function buildRoom(rootFolder, spec, layout, ctx)
	local rng = Random.new(7919 * layout.index)
	local isBoss = layout.kind == "boss"
	local isCourtyard = layout.kind == "courtyard"

	local folder = Instance.new("Folder")
	folder.Name = ("Room_%02d_%s"):format(layout.index, layout.kind)
	local room = newRoom(spec, layout, folder)

	local hasEntry = layout.index > 1
	local hasExit = ctx.layouts[layout.index + 1] ~= nil
	if hasEntry then
		room.entranceDoor = makeDoor(folder, rng, layout.entryZ, 1)
	end
	if hasExit and not isBoss then
		room.exitDoor = makeDoor(folder, rng, layout.exitZ, -1)
	end

	if isBoss then
		FloorBuilder.buildArena(folder, rng, layout, room)
		folder.Parent = rootFolder
		return room
	end

	buildFloor(folder, rng, layout)
	islandUnderside(folder, rng, layout)
	ruinPerimeter(folder, rng, layout, { entry = hasEntry, exit = hasExit }, {
		noEntryWall = isCourtyard,
		noExitWall = isCourtyard,
		wallHeight = layout.kind == "rest" and 9 or 14,
	})
	if isCourtyard then
		-- Двор замкнут фасадами (Themes[0]), барьер — по их линиям.
		barrier(folder, "x", layout.entryZ + 1.5, -layout.size / 2 - 2, layout.size / 2 + 2)
		local gap = { from = -Rooms.Doorway.width / 2, to = Rooms.Doorway.width / 2, height = Rooms.Doorway.height }
		barrier(folder, "x", layout.exitZ - 1.5, -layout.size / 2 - 2, layout.size / 2 + 2, gap)
	end
	if hasEntry then
		doorway(folder, rng, layout.entryZ, -1)
	end
	if hasExit then
		doorway(folder, rng, layout.exitZ, 1)
	end

	-- Колонны 3×3 блокируют и врагов, и снаряды.
	if spec.pillars then
		for pillarIndex, point in ipairs(Rooms.Pillars) do
			local worldX, worldZ = FloorLayout.toWorld(layout, point.X, point.Y)
			local face = V3(worldX > 0 and -1 or 1, 0, 0)
			Props.pillar(folder, worldX, worldZ, 14, rng, { banner = pillarIndex % 2 == 1 and face or nil })
			table.insert(room.obstacles, { cx = worldX, cz = worldZ, hx = Rooms.PillarSize / 2, hz = Rooms.PillarSize / 2 })
		end
	end

	-- Шипы.
	if spec.spikes then
		room.spikes = {}
		for _, point in ipairs(Rooms.Spikes.points) do
			local worldX, worldZ = FloorLayout.toWorld(layout, point.X, point.Y)
			table.insert(room.spikes, makeSpikePlate(folder, rng, V3(worldX, 0, worldZ)))
		end
	end

	local theme = Themes[spec.id]
	if theme then
		theme(folder, rng, layout, room)
	end

	folder.Parent = rootFolder
	return room
end

-- ===== Арена босса =====

-- Цепь по прямой между двумя точками (ворота Хранилища).
local function chainBetween(folder, rng, a: Vector3, b: Vector3)
	local direction = b - a
	local links = math.floor(direction.Magnitude / 0.7)
	for index = 0, links do
		local position = a + direction * (index / links)
		local frame = CFrame.lookAt(position, b) * ANG(0, 0, index % 2 == 0 and 0 or math.pi / 2)
		Props.part(folder, "ChainLink", V3(0.5, 0.18, 0.8), frame, Props.vary(Env.iron, rng, 0.06), Enum.Material.Metal, { shadow = false })
	end
end

-- Рунная печать на полу: кольца, крест, ромбы. Клиент пульсирует ею
-- (тег KlinokRune), во второй фазе босса она разгорается.
local function runeCircle(folder, center: Vector3)
	local runes = Instance.new("Model")
	runes.Name = "RuneCircle"
	local color = Env.flame:Lerp(Env.ember, 0.3)
	local function seg(cf: CFrame, size: Vector3)
		local part = Props.part(runes, "Rune", size, cf, color, Enum.Material.Neon, { shadow = false })
		part.Transparency = 0.35
		CollectionService:AddTag(part, "KlinokRune")
	end
	for _, radius in ipairs({ 5, 14, 22 }) do
		local count = math.floor(radius * 2.4)
		for index = 1, count do
			local angle = (index / count) * math.pi * 2
			local position = center + V3(math.sin(angle) * radius, 0.22, math.cos(angle) * radius)
			seg(CFrame.lookAt(position, center + V3(0, 0.22, 0)), V3((2 * math.pi * radius / count) + 0.05, 0.05, 0.35))
		end
	end
	for _, angle in ipairs({ 0, math.pi / 2 }) do
		seg(CF(center + V3(0, 0.22, 0)) * ANG(0, angle, 0), V3(0.35, 0.05, 28))
	end
	for index = 0, 7 do
		local angle = index * math.pi / 4
		local position = center + V3(math.sin(angle) * 18, 0.22, math.cos(angle) * 18)
		for _, s in ipairs({ { 1.6, 0.3 }, { 0.3, 1.6 } }) do
			seg(CF(position) * ANG(0, angle + math.pi / 4, 0), V3(s[1], 0.05, s[2]))
		end
		seg(CF(position) * ANG(0, angle + math.pi / 4, 0), V3(1.1, 0.05, 1.1))
	end
	runes.Parent = folder
end

function FloorBuilder.buildArena(folder, rng, layout, room)
	local centerZ = layout.centerZ
	local center = V3(0, 0, centerZ)
	local wallR = layout.size / 2 -- внутренняя грань стены
	local height = Rooms.WallHeight + 4
	local doorHalf = Rooms.Doorway.width / 2 + 3

	buildFloor(folder, rng, layout, { circle = wallR, pathEnd = centerZ + 23 })
	islandUnderside(folder, rng, layout)
	runeCircle(folder, center)
	doorway(folder, rng, layout.entryZ, -1)

	-- Круглая стена из блоков, у входа проём под дверь, сзади — врата.
	local thick = 3.5
	local radius = wallR + thick / 2
	local rows = math.ceil(height / ROW)
	for row = 1, rows do
		local count = math.floor(2 * math.pi * radius / 4.2)
		local offset = row % 2 == 0 and 0.5 or 0
		for k = 0, count - 1 do
			local angle = ((k + offset) / count) * math.pi * 2
			local x = math.sin(angle) * radius
			local zLocal = math.cos(angle) * radius
			local front = zLocal > 0 and math.abs(x) < doorHalf and (row - 1) * ROW < Rooms.Doorway.height + 3
			local back = zLocal < 0 and math.abs(x) < 15
			local fromTop = rows - row
			local skip = front or back or (fromTop == 0 and rng:NextNumber() < 0.25) or (fromTop == 1 and rng:NextNumber() < 0.08)
			if not skip then
				local position = center + V3(x, (row - 1) * ROW + ROW / 2, zLocal)
				local width = 2 * math.pi * radius / count + 0.25
				local inset = rng:NextNumber() * 0.3
				block(folder, "WallStone", V3(width, ROW, thick), CFrame.lookAt(position, V3(center.X, position.Y, center.Z)) * CF(0, 0, inset), stoneColor(rng, row))
				if fromTop == 0 and rng:NextNumber() < 0.3 then
					block(folder, "WallStone", V3(width * 0.7, ROW, thick), CFrame.lookAt(position, V3(center.X, position.Y, center.Z)) * CF(0, ROW, 0.1), stoneColor(rng, row))
				end
			end
		end
	end

	-- Барьер по кругу: многоугольник из невидимых плит до BarrierHeight.
	local segments = 40
	for k = 0, segments - 1 do
		local angle = (k / segments) * math.pi * 2
		local x = math.sin(angle) * (wallR + 1)
		local zLocal = math.cos(angle) * (wallR + 1)
		if not (zLocal > 0 and math.abs(x) < 8) then
			local position = center + V3(x, Rooms.BarrierHeight / 2, zLocal)
			local width = 2 * math.pi * (wallR + 1) / segments + 1
			Props.part(folder, "Barrier", V3(width, Rooms.BarrierHeight, 2), CFrame.lookAt(position, V3(center.X, position.Y, center.Z)), Env.stone, nil, { collide = true, query = false, transparency = 1, shadow = false })
			Props.part(folder, "WallBody", V3(width, height, 2), CFrame.lookAt(center + V3(x, height / 2, zLocal), center + V3(0, height / 2, 0)), Env.stone, nil, { query = true, transparency = 1, shadow = false })
		end
	end
	-- У входа круг барьера вырезан: прямой барьер с проёмом двери.
	barrier(folder, "x", layout.entryZ + 1.5, -16, 16, { from = -Rooms.Doorway.width / 2, to = Rooms.Doorway.width / 2, height = Rooms.Doorway.height })

	-- Жаровни на колоннах по кругу, знамёна на стене между ними.
	local braziers = { 40, 90, 140, -40, -90, -140 }
	for index, degrees in ipairs(braziers) do
		local angle = math.rad(degrees)
		local position = center + V3(math.sin(angle) * (wallR - 5), 0, math.cos(angle) * (wallR - 5))
		local toCenter = (center - position) * V3(1, 0, 1)
		local face = toCenter.Unit
		local snapped = math.abs(face.X) > math.abs(face.Z) and V3(math.sign(face.X), 0, 0) or V3(0, 0, math.sign(face.Z))
		Props.pillar(folder, position.X, position.Z, 9, rng, { banner = snapped })
		Props.flame(folder, position + V3(0, 9.9, 0), 1.6, { range = 34, brightness = 2.6 })
		table.insert(room.obstacles, { cx = position.X, cz = position.Z, hx = 1.5, hz = 1.5 })

		local bannerAngle = math.rad(degrees + (degrees > 0 and 25 or -25))
		if index ~= 3 and index ~= 6 then
			local mount = center + V3(math.sin(bannerAngle) * (wallR - 0.3), height - 4, math.cos(bannerAngle) * (wallR - 0.3))
			Props.banner(folder, CFrame.lookAt(mount, V3(center.X, mount.Y, center.Z)), 11, Env.cloth, rng)
		end
	end

	-- Врата Хранилища за спиной босса: башни, решётка, ступени, цепи.
	local gateZ = layout.exitZ + 1
	for _, sx in ipairs({ -1, 1 }) do
		local towerX = sx * 11
		local y = 0
		while y < height + 8 do
			block(folder, "GateTower", V3(7, 3, 7), CF(towerX, y + 1.5, gateZ - 1) * ANG(0, (rng:NextNumber() - 0.5) * 0.04, 0), stoneColor(rng, math.floor(y / 3) + 1))
			y += 3
		end
		block(folder, "GateTowerCap", V3(8.4, 1.4, 8.4), CF(towerX, y + 0.7, gateZ - 1), Ruin.path:Lerp(Ruin.rubble, 0.35))
		Props.flame(folder, V3(towerX, y + 1.6, gateZ - 1), 1.8, { range = 36 })
		Props.banner(folder, CFrame.lookAt(V3(towerX, height - 2, gateZ + 2.6), V3(towerX, height - 2, gateZ + 20)), 13, Env.cloth, rng)
		chainBetween(folder, rng, V3(towerX - sx * 3.3, height - 4, gateZ + 2), V3(sx * 4.5, 6, gateZ + 1.2))
		table.insert(room.obstacles, { cx = towerX, cz = gateZ - 1, hx = 3.5, hz = 3.5 })
	end
	for row = 0, math.floor((height + 6) / ROW) do
		local y0 = row * ROW
		if y0 >= 18 then
			block(folder, "GateWall", V3(15, ROW, 3), CF(0, y0 + ROW / 2, gateZ - 2), stoneColor(rng, row + 1))
		end
	end
	block(folder, "GateArch", V3(16, 2.4, 3.6), CF(0, 19, gateZ - 1.4), Ruin.path:Lerp(Ruin.rubble, 0.35))
	block(folder, "GateKeystone", V3(3, 3.4, 4), CF(0, 19.6, gateZ - 1.2), Ruin.path:Lerp(Ruin.rubble, 0.2))
	Props.part(folder, "GateDark", V3(15, 18, 1), CF(0, 9, gateZ - 3.2), Env.void, nil, { shadow = false })
	for index = -5, 5 do
		Props.part(folder, "GateBar", V3(0.6, 18, 0.6), CF(index * 1.35, 9, gateZ - 2.2), index % 3 == 0 and Env.rustDark or Env.iron, Enum.Material.Metal)
	end
	for _, y in ipairs({ 3, 8, 13, 17 }) do
		Props.part(folder, "GateRail", V3(15, 0.6, 0.8), CF(0, y, gateZ - 2.2), Env.ironLight, Enum.Material.Metal)
	end
	for step = 1, 3 do
		Props.part(folder, "GateStep", V3(18 - step * 1.5, step * 0.5, 2), CF(0, step * 0.25, gateZ + 5 - step * 2), Props.vary(Ruin.path, rng), SLATE, { collide = true })
	end
	Props.part(folder, "Barrier", V3(34, Rooms.BarrierHeight, 2), CF(0, Rooms.BarrierHeight / 2, gateZ - 3), Env.stone, nil, { collide = true, query = false, transparency = 1, shadow = false })
	Props.part(folder, "WallBody", V3(34, height, 2), CF(0, height / 2, gateZ - 3), Env.stone, nil, { query = true, transparency = 1, shadow = false })

	-- Обломки у стен и парящие над ними кубики.
	local hoverFolder = Instance.new("Folder")
	hoverFolder.Name = "Hover"
	hoverFolder.Parent = folder
	for _ = 1, 22 do
		local angle = rng:NextNumber() * math.pi * 2
		local r = wallR - 2.5 - rng:NextNumber() * 3
		local position = center + V3(math.sin(angle) * r, 0, math.cos(angle) * r)
		local nearFront = math.cos(angle) > 0.8
		local nearGate = math.cos(angle) < -0.85
		if not nearFront and not nearGate then
			local top = Props.ruinCluster(folder, position, rng, RUBBLE, 6)
			if rng:NextNumber() < 0.5 then
				Props.hoverCube(hoverFolder, position + V3(0, math.max(5, top) + 2 + rng:NextNumber() * 3, 0), Props.vary(Ruin.rubble, rng, 0.06), rng)
			end
		end
	end
	for _ = 1, 20 do
		local angle = rng:NextNumber() * math.pi * 2
		local r = wallR - 2 - rng:NextNumber() * 4
		Props.grass(folder, center + V3(math.sin(angle) * r, 0, math.cos(angle) * r), rng)
	end
	for _ = 1, 8 do
		local angle = rng:NextNumber() * math.pi * 2
		local r = 8 + rng:NextNumber() * 30
		Props.stain(folder, center + V3(math.sin(angle) * r, 0, math.cos(angle) * r), rng)
	end
	for _ = 1, 30 do
		local angle = rng:NextNumber() * math.pi * 2
		local r = wallR + 4 + rng:NextNumber() * 14
		Props.floatCube(folder, center + V3(math.sin(angle) * r, 4 + rng:NextNumber() * 30, math.cos(angle) * r), 1 + rng:NextNumber() * 3, stoneColor(rng, 4), rng)
	end
end

-- ===== Этаж =====

-- Построить этаж. Возвращает { folder, rooms }.
function FloorBuilder.build(parent, specs)
	local layouts = FloorLayout.build(specs, Rooms.Size, Rooms.Corridor.length)

	local folder = Instance.new("Folder")
	folder.Name = "Floor"

	local ctx = { layouts = layouts }
	local rooms = {}
	for index, layout in ipairs(layouts) do
		rooms[index] = buildRoom(folder, specs[index], layout, ctx)
		local nextLayout = layouts[index + 1]
		if nextLayout then
			buildCorridor(folder, Random.new(613 * index), index, layout.exitZ, nextLayout.entryZ)
		end
		task.wait() -- не держим сервер одним большим кадром
	end
	for _, room in ipairs(rooms) do
		for _, door in pairs({ room.entranceDoor or false, room.exitDoor or false }) do
			if door then
				door.set(false, true)
			end
		end
	end

	local last = layouts[#layouts]
	FloorScenery.build(folder, last and -last.exitZ or 400)

	folder.Parent = parent
	return folder, rooms
end

-- Анимация открытия сундука: крышка откидывается, вспышка цветом редкости.
function FloorBuilder.openChestVisual(chest, color: Color3)
	local lid = chest:FindFirstChild("Lid")
	local base = chest.PrimaryPart
	if lid and lid:IsA("Model") then
		local hingeZ = chest:GetAttribute("HingeZ")
		local hingeY = chest:GetAttribute("HingeY")
		local start = lid:GetPivot()
		local pivot = CF(start.Position.X, hingeY, hingeZ)
		local relative = pivot:ToObjectSpace(start)
		local value = Instance.new("NumberValue")
		value.Parent = chest
		value.Changed:Connect(function(angle)
			lid:PivotTo(pivot * ANG(-angle, 0, 0) * relative)
		end)
		local tween = TweenService:Create(value, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = math.rad(105) })
		tween:Play()
		tween.Completed:Once(function()
			value:Destroy()
		end)
	end
	local glow = base and base:FindFirstChild("Glow")
	if glow then
		glow.Color = color
		glow.Brightness = 5
		TweenService:Create(glow, TweenInfo.new(1.4), { Brightness = 1.2 }):Play()
	end
	if base then
		local burst = Instance.new("ParticleEmitter")
		burst.Rate = 0
		burst.Lifetime = NumberRange.new(0.6, 1.2)
		burst.Speed = NumberRange.new(8, 16)
		burst.SpreadAngle = Vector2.new(40, 40)
		burst.EmissionDirection = Enum.NormalId.Top
		burst.Acceleration = V3(0, -18, 0)
		burst.LightEmission = 1
		burst.Color = ColorSequence.new(color)
		burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		burst.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		burst.Parent = base
		burst:Emit(40)
		task.delay(1.5, function()
			burst:Destroy()
		end)
		local pillar = Props.part(chest, "LootBeam", V3(1.6, 40, 1.6), base.CFrame * CF(0, 20, 0), color, Enum.Material.Neon, { shadow = false })
		pillar.Transparency = 0.35
		TweenService:Create(pillar, TweenInfo.new(2.0, Enum.EasingStyle.Quad), { Transparency = 1, Size = V3(0.2, 40, 0.2) }):Play()
		task.delay(2.1, function()
			pillar:Destroy()
		end)
	end
end

return FloorBuilder
