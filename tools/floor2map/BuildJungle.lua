--[[
	BuildJungle — джунгли вокруг этажа 2 «Затопленные сады» (Terrain + лес).
	Запуск: Studio, режим Edit, Command Bar (вставить весь файл, Enter). Потом Ctrl+S:
	Terrain и папка Workspace.Jungle живут в файле места. Повторный запуск
	перезаписывает тот же участок и пересобирает Workspace.Jungle.

	Решение Артёма 29.10.2026: этаж открытый, вокруг — джунгли, как пустыня у этажа 1.
	  • Земля (трава, мох, грязь) вровень с полом сада (верх ≈ 0) у стен, дальше —
	    холмы, к горизонту — гряда до ~50 стад, чтобы не было видно края мира.
	  • Озёра в низинах (вода Terrain), не ближе ~50 стад к саду.
	  • Внутрь сада Terrain не кладётся: маска ниже — след всех деталей зон
	    (сгенерирована f2/map/kit/jungle.py из той же сборки, что и карта).
	  • Лес — простые детали в стиле карты (ствол, корни, плоские кроны, лианы),
	    без коллизий и лучей: дальний план. Ближнее кольцо деревьев уже в мешах карты.
	Пустыня этажа 1 (x −1100..1100) и хаб не трогаются: участок x 2080..3120.
]]

local Workspace = game:GetService("Workspace")
local terrain = Workspace.Terrain

local OFF_X = 2600 -- мир = локальные + (2600, 0, 0), как Floor2.Offset
local MIN_X, MAX_X = -520, 520 -- локально
local MIN_Z, MAX_Z = -1060, 460
local V = 4
local LOW_Y, HIGH_Y = -16, 64
local WATER_Y = -1.2

-- ===== Маска сада (локальные клетки 2×2 стада; ряды по z, пары «начало, длина» по x) =====
local MX0, MZ0, MNX, MNZ, MC = -320, -760, 300, 500, 2
local MASK = {
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{76,18},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{57,56},
	{60,50},
	{60,50},
	{60,50},
	{60,51},
	{60,50},
	{60,50},
	{60,50},
	{60,50},
	{59,51},
	{60,50},
	{60,50},
	{60,50},
	{60,50},
	{60,50},
	{60,50},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{36,78},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{56,58},
	{69,29},
	{69,29},
	{69,29},
	{69,29},
	{69,29},
	{69,29},
	{69,29},
	{69,29},
	{69,29},
	{69,29},
	{69,29},
	{69,29},
	{69,29},
	{69,29},
	{69,29},
	{69,29},
	{69,29},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44},
	{63,44,137,8},
	{63,44,137,9,163,8},
	{63,115},
	{63,115},
	{63,115},
	{63,115},
	{63,115},
	{63,115},
	{63,170},
	{63,169},
	{63,208},
	{63,208},
	{63,208},
	{63,208},
	{63,208},
	{63,208},
	{63,208},
	{63,208},
	{63,208},
	{63,208},
	{63,208},
	{63,208},
	{63,208},
	{63,208},
	{63,208},
	{63,208},
	{63,208},
	{63,208},
	{63,208},
	{100,171},
	{100,171},
	{100,171},
	{100,171},
	{100,171},
	{100,171},
	{100,171},
	{100,171},
	{176,95},
	{176,95},
	{176,95},
	{176,95},
	{176,95},
	{176,95},
	{176,95},
	{176,95},
	{176,95},
	{176,95},
	{176,95},
	{176,95},
	{176,96},
	{176,95},
	{176,95},
	{176,56},
	{176,56},
	{176,56},
	{176,56},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{150,80},
	{150,80},
	{150,80},
	{150,80},
	{150,80},
	{150,80},
	{150,80},
	{150,80},
	{150,99},
	{150,99},
	{150,99},
	{150,99},
	{150,99},
	{150,99},
	{150,100},
	{150,100},
	{150,100},
	{150,100},
	{150,100},
	{150,100},
	{150,99},
	{150,99},
	{150,99},
	{150,99},
	{150,98},
	{150,99},
	{150,99},
	{150,99},
	{150,89,245,3},
	{150,80},
	{150,80},
	{150,80},
	{150,80},
	{150,80},
	{150,80},
	{150,80},
	{150,80},
	{150,80},
	{150,80},
	{150,80},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{190,40},
	{197,27},
	{197,27},
	{197,27},
	{197,27},
	{197,27},
	{197,27},
	{197,27},
	{197,27},
	{197,27},
	{197,27},
	{197,27},
	{197,27},
	{197,27},
	{197,27},
	{197,27},
	{197,27},
	{197,27},
	{185,52},
	{185,52},
	{185,52},
	{185,52},
	{185,52},
	{185,52},
	{185,52},
	{155,10,185,52},
	{135,102},
	{135,102},
	{135,102},
	{135,102},
	{135,102},
	{135,102},
	{135,102},
	{135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,144},
	{93,144},
	{93,144},
	{93,144},
	{93,144},
	{93,144},
	{93,144},
	{93,144},
	{93,144},
	{93,144},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{93,36,135,102},
	{135,102},
	{135,102},
	{135,50},
	{135,50},
	{135,50},
	{135,50},
	{135,50},
	{135,50},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{150,20},
	{147,26},
	{147,26},
	{147,27},
	{147,26},
	{147,26},
	{147,26},
	{147,26},
	{147,26},
	{147,26},
	{147,26},
	{147,26},
	{147,26},
	{147,26},
	{147,26},
	{147,26},
	{147,26},
	{147,26},
	{147,26},
	{148,24},
	{148,24},
	{148,24},
	{148,24},
	{148,24},
	{148,24},
	{148,24},
	{148,24},
	{148,24},
	{148,24},
	{148,24},
	{148,24},
	{148,24},
	{148,24},
	{148,24},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{},
	{}
}

local function masked(x: number, z: number): boolean
	local j = math.floor((z - MZ0) / MC)
	if j < 0 or j >= MNZ then
		return false
	end
	local i = math.floor((x - MX0) / MC)
	if i < 0 or i >= MNX then
		return false
	end
	local row = MASK[j + 1]
	for k = 1, #row, 2 do
		local s = row[k]
		if i < s then
			return false
		end
		if i < s + row[k + 1] then
			return true
		end
	end
	return false
end

local NX = (MAX_X - MIN_X) / V
local NZ = (MAX_Z - MIN_Z) / V
local function idx(i, j)
	return j * NX + i + 1
end

-- 1. Доля «снаружи сада» в каждой колонне (4 пробы).
local share = table.create(NX * NZ, 1)
for i = 0, NX - 1 do
	local x = MIN_X + i * V
	for j = 0, NZ - 1 do
		local z = MIN_Z + j * V
		local free = 0
		for _, o in ipairs({ { 1, 1 }, { 3, 1 }, { 1, 3 }, { 3, 3 } }) do
			if not masked(x + o[1], z + o[2]) then
				free += 1
			end
		end
		share[idx(i, j)] = free / 4
	end
	if i % 20 == 0 then
		task.wait()
	end
end

-- 2. Расстояние до сада (шаги по 4 стада).
local dist = table.create(NX * NZ, math.huge)
local queue, head = {}, 1
for k = 1, NX * NZ do
	if share[k] < 1 then
		dist[k] = 0
		table.insert(queue, k - 1)
	end
end
while head <= #queue do
	local k = queue[head]
	head += 1
	local i, j = k % NX, k // NX
	local d = dist[k + 1] + V
	for _, n in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		local ni, nj = i + n[1], j + n[2]
		if ni >= 0 and ni < NX and nj >= 0 and nj < NZ then
			local nk = idx(ni, nj)
			if dist[nk] > d then
				dist[nk] = d
				table.insert(queue, nk - 1)
			end
		end
	end
end
task.wait()

-- 3. Рельеф.
local function smooth(e0, e1, x)
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end
local function lakeAt(x, z, d)
	return smooth(0.22, 0.38, math.noise(x / 130, z / 130, 21.7)) * smooth(50, 95, d) * (1 - smooth(170, 230, d))
end
local function heightAt(x, z, d)
	local n1 = math.noise(x / 210, z / 210, 3.3)
	local n2 = math.noise(x / 70, z / 70, 7.9)
	local ridge = 1 - math.abs(math.noise(x / 160 + n1 * 0.5, z / 160, 11.2)) * 2
	local hills = math.max(0, 3 + 14 * (n1 + 0.35) + 6 * n2 + 8 * ridge * ridge)
	local h = -0.15 + smooth(10, 90, d) * hills + smooth(170, 420, d) * (22 + 14 * ridge)
	local lake = lakeAt(x, z, d)
	return h * (1 - lake) - 6.5 * lake, lake
end
local function materialAt(x, z, d, h, lake)
	if lake > 0.25 and h < 1.5 then
		return Enum.Material.Mud
	end
	if h > 24 and math.noise(x / 40, z / 40, 31.5) > -0.1 then
		return Enum.Material.Rock
	end
	local n = math.noise(x / 55, z / 55, 17.1)
	if n > 0.22 then
		return Enum.Material.LeafyGrass
	elseif n < -0.38 and d > 8 then
		return Enum.Material.Ground
	end
	return Enum.Material.Grass
end

local hcache = table.create(NX * NZ, 0)
local lcache = table.create(NX * NZ, 0)
for i = 0, NX - 1 do
	local x = MIN_X + i * V + V / 2
	for j = 0, NZ - 1 do
		local z = MIN_Z + j * V + V / 2
		local k = idx(i, j)
		hcache[k], lcache[k] = heightAt(x, z, dist[k])
	end
end
task.wait()

-- 4. Запись Terrain кусками 32×32 колонны.
local CH = 32
local layers = (HIGH_Y - LOW_Y) / V
local written = 0
for ci = 0, NX - 1, CH do
	for cj = 0, NZ - 1, CH do
		local w = math.min(CH, NX - ci)
		local l = math.min(CH, NZ - cj)
		local mats, occs = {}, {}
		for a = 1, w do
			mats[a], occs[a] = {}, {}
			for b = 1, layers do
				mats[a][b], occs[a][b] = {}, {}
			end
		end
		for a = 1, w do
			local i = ci + a - 1
			local x = MIN_X + i * V + V / 2
			for c = 1, l do
				local j = cj + c - 1
				local z = MIN_Z + j * V + V / 2
				local k = idx(i, j)
				local fill = share[k]
				local h, lake = hcache[k], lcache[k]
				local material = materialAt(x, z, dist[k], h, lake)
				local wet = lake > 0.05 and h < WATER_Y and fill >= 1
				for b = 1, layers do
					local bottom = LOW_Y + (b - 1) * V
					local occ = math.clamp((h - bottom) / V, 0, 1) * fill
					if occ > 0.02 then
						mats[a][b][c] = material
						occs[a][b][c] = occ
					elseif wet and bottom < WATER_Y then
						mats[a][b][c] = Enum.Material.Water
						occs[a][b][c] = math.clamp((WATER_Y - bottom) / V, 0.05, 1)
					else
						mats[a][b][c] = Enum.Material.Air
						occs[a][b][c] = 0
					end
				end
			end
		end
		local x0 = OFF_X + MIN_X + ci * V
		local z0 = MIN_Z + cj * V
		terrain:WriteVoxels(Region3.new(Vector3.new(x0, LOW_Y, z0), Vector3.new(x0 + w * V, HIGH_Y, z0 + l * V)), V, mats, occs)
		written += 1
		task.wait()
	end
end

-- Цвета земли в палитре этажа 2 (#1F3A33 / #3F7A5C / #9CC48A). Пустыня и хаб их не используют.
terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromHex("#2F5E46"))
terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromHex("#264A3A"))
terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromHex("#2E2A20"))
terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromHex("#3A3424"))
terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromHex("#40524B"))

-- ===== 5. Лес: Workspace.Jungle =====
local old = Workspace:FindFirstChild("Jungle")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Jungle"
root.Parent = Workspace

local rng = Random.new(29)
local GREENS = { "#1F3A33", "#2A5040", "#2F6B4E", "#3F7A5C", "#45855A" }
local LIGHT = { "#5A9466", "#6FA36B", "#9CC48A" }
local TRUNK = { "#2B231B", "#46382A", "#66503A" }
local STONE = { "#4A5F57", "#667C73", "#8A9E95", "#33463F" }

local function jit(hex: string, k: number?): Color3
	local c = Color3.fromHex(hex)
	local f = 1 + rng:NextNumber(-(k or 0.08), k or 0.08)
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end
local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local count = 0
local function piece(parent, cf: CFrame, size: Vector3, color: Color3, class: string?, shadow: boolean?)
	local p = Instance.new(class or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = shadow ~= false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Parent = parent
	count += 1
	return p
end
local function group(name: string)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = root
	return m
end
local trees, palms, ferns, rocks, ruins = group("Trees"), group("Palms"), group("Ferns"), group("Rocks"), group("Ruins")

local function tree(base: Vector3, h: number, s: number)
	local m = Instance.new("Model")
	m.Name = "Tree"
	m.Parent = trees
	local yaw = rng:NextNumber(0, 30)
	piece(m, CFrame.new(base + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(0, math.rad(yaw), 0), Vector3.new(2.6 * s, h + 2, 2.6 * s), jit(pick(TRUNK)))
	for k = 0, 3 do
		local a = math.rad(k * 90 + yaw + rng:NextNumber(-15, 15))
		piece(m, CFrame.new(base) * CFrame.Angles(0, a, 0) * CFrame.new(0, 1.4 * s, -2.2 * s), Vector3.new(0.7 * s, 2.8 * s, 2.6 * s), jit(TRUNK[1]), "WedgePart", false)
	end
	for _ = 1, 5 do
		local r = rng:NextNumber(4, 7) * s
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, 3.5) * s
		local pos = base + Vector3.new(math.cos(a) * d, h - 1 + rng:NextNumber(-1.5, 2), math.sin(a) * d)
		piece(m, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Vector3.new(r * 2, rng:NextNumber(1.6, 3), r * 2), jit(pick(GREENS)))
	end
	for _ = 1, 2 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(3, 6) * s
		local len = rng:NextNumber(3, 8)
		piece(m, CFrame.new(base + Vector3.new(math.cos(a) * d, h - 2 - len / 2, math.sin(a) * d)), Vector3.new(0.25, len, 0.25), jit(pick(GREENS)), nil, false)
	end
end

local function palm(base: Vector3, h: number)
	local m = Instance.new("Model")
	m.Name = "Palm"
	m.Parent = palms
	local lean = math.rad(rng:NextNumber(-12, 12))
	local dir = rng:NextNumber(0, math.pi * 2)
	local tip = base
	for k = 0, 4 do
		local y = (k + 0.5) * h / 5
		local off = math.sin(lean) * y * 0.5
		tip = base + Vector3.new(math.cos(dir) * off, y, math.sin(dir) * off)
		piece(m, CFrame.new(tip), Vector3.new(0.9, h / 5 + 0.1, 0.9), jit(pick(TRUNK), 0.1), nil, false)
	end
	tip += Vector3.new(0, h / 10, 0)
	for k = 0, 6 do
		local a = math.rad(k * 51 + rng:NextNumber(-10, 10))
		local frame = CFrame.new(tip) * CFrame.Angles(0, a, 0)
		piece(m, frame * CFrame.new(0, -0.4, -2.4) * CFrame.Angles(math.rad(20), 0, 0), Vector3.new(1.2, 0.2, 4.8), jit(pick(LIGHT)))
		piece(m, frame * CFrame.new(0, -1.6, -5.2) * CFrame.Angles(math.rad(45), 0, 0), Vector3.new(0.9, 0.2, 2.4), jit(pick(GREENS)), nil, false)
	end
end

local function fern(base: Vector3)
	local m = Instance.new("Model")
	m.Name = "Fern"
	m.Parent = ferns
	local n = rng:NextInteger(4, 6)
	for k = 1, n do
		local a = math.rad(k * 360 / n + rng:NextNumber(-20, 20))
		local L = rng:NextNumber(1.8, 3.2)
		piece(m, CFrame.new(base) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.5, -L / 2) * CFrame.Angles(math.rad(rng:NextNumber(15, 35)), 0, 0), Vector3.new(0.7, 0.15, L), jit(pick(k % 2 == 0 and LIGHT or GREENS)), nil, false)
	end
end

local function rock(base: Vector3)
	local m = Instance.new("Model")
	m.Name = "Rock"
	m.Parent = rocks
	local s = rng:NextNumber(2, 6)
	piece(m, CFrame.new(base + Vector3.new(0, s * 0.3, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-15, 15)), rng:NextNumber(0, 3), math.rad(rng:NextNumber(-15, 15))), Vector3.new(s, s * 0.8, s * 1.1), jit(pick(STONE)))
	piece(m, CFrame.new(base + Vector3.new(0, s * 0.68, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Vector3.new(s * 0.8, 0.3, s * 0.8), jit("#4E6B3A"), nil, false)
	if rng:NextNumber() < 0.5 then
		local t = s * 0.5
		piece(m, CFrame.new(base + Vector3.new(s * 0.6, t * 0.3, rng:NextNumber(-1, 1))) * CFrame.Angles(0, rng:NextNumber(0, 3), math.rad(12)), Vector3.new(t, t * 0.8, t), jit(pick(STONE)), nil, false)
	end
end

local function ruin(base: Vector3)
	local m = Instance.new("Model")
	m.Name = "Ruin"
	m.Parent = ruins
	local yaw = rng:NextNumber(0, math.pi)
	local frame = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	for k = 0, rng:NextInteger(1, 3) do
		local h = rng:NextNumber(4, 10)
		local col = frame * CFrame.new(k * 6 - 6, h / 2, 0) * CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), 0, math.rad(rng:NextNumber(-6, 6)))
		piece(m, col, Vector3.new(1.8, h, 1.8), jit(pick(STONE)))
		piece(m, frame * CFrame.new(k * 6 - 6, 0.4, 0), Vector3.new(2.6, 0.8, 2.6), jit(STONE[1]), nil, false)
		piece(m, col * CFrame.new(0, h / 2 - 1.5, 0.95), Vector3.new(1.0, 3, 0.15), jit("#4E6B3A"), nil, false) -- плющ
	end
	piece(m, frame * CFrame.new(rng:NextNumber(-4, 4), 0.9, rng:NextNumber(3, 5)) * CFrame.Angles(0, rng:NextNumber(0, 3), math.rad(90)), Vector3.new(1.8, 7, 1.8), jit(pick(STONE)))
end

local function columnAt(x: number, z: number)
	local i = math.clamp(math.floor((x - MIN_X) / V), 0, NX - 1)
	local j = math.clamp(math.floor((z - MIN_Z) / V), 0, NZ - 1)
	return idx(i, j)
end

local G = 16
local stats = { tree = 0, palm = 0, fern = 0, rock = 0, ruin = 0 }
for gx = MIN_X, MAX_X - G, G do
	for gz = MIN_Z, MAX_Z - G, G do
		local x, z = gx + rng:NextNumber(0, G), gz + rng:NextNumber(0, G)
		local k = columnAt(x, z)
		local d = dist[k]
		if d >= 28 and share[k] >= 1 and lcache[k] < 0.05 then
			local h = heightAt(x, z, d)
			local base = Vector3.new(OFF_X + x, h - 0.3, z)
			local r = rng:NextNumber()
			local pTree = d < 200 and 0.13 or 0.05
			if r < pTree then
				tree(base, rng:NextNumber(16, 30), rng:NextNumber(1.0, 1.7))
				stats.tree += 1
			elseif r < pTree + 0.03 then
				palm(base, rng:NextNumber(10, 17))
				stats.palm += 1
			elseif r < pTree + 0.06 and d < 300 then
				rock(base)
				stats.rock += 1
			elseif r < pTree + 0.07 and d > 40 and d < 260 then
				ruin(base)
				stats.ruin += 1
			elseif r < pTree + 0.3 and d < 130 then
				fern(base)
				stats.fern += 1
			end
		elseif d >= 6 and d < 28 and share[k] >= 1 and rng:NextNumber() < 0.3 then
			-- у самых стен — только папоротники и камни (деревья там уже в мешах карты)
			local h = heightAt(x, z, d)
			local base = Vector3.new(OFF_X + x, h - 0.2, z)
			if rng:NextNumber() < 0.8 then
				fern(base)
				stats.fern += 1
			else
				rock(base)
				stats.rock += 1
			end
		end
	end
	if gx % 64 == 0 then
		task.wait()
	end
end

local msg = ("[BuildJungle] готово: Terrain %d кусков; лес — деревья %d, пальмы %d, папоротники %d, камни %d, руины %d (%d деталей). Ctrl+S.")
	:format(written, stats.tree, stats.palm, stats.fern, stats.rock, stats.ruin, count)
print(msg)
return msg
