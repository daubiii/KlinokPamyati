--[[
	BuildLake — Озеро Памяти и река хаба: живая вода Terrain неровной формы,
	берег и дно — блоки в стиле хаба, глубина ступенями.
	Запуск: Studio, режим Edit. Потом Ctrl+S (хаб живёт в файле места).

	Правка Артёма 28.10.2026: рельеф и трава — как были (плитки хаба), от
	Terrain — только вода; глубина — ступенчатый спуск из «пикселей».

	Что делает:
	  * вода — Terrain Water (волны, отражения), берег неровный (шум по углу),
	    река — по линии старых сегментов River;
	  * плитки травы хаба возвращаются; спрятаны только те, что легли бы на воду;
	  * где плитки нет (у кромки воды) — плоские блоки травы/песка вровень;
	  * дно — блоки, ступенями вниз к середине (Hub.World.Water.LakeBed);
	  * старые диски воды и берега, сегменты реки и диски на поворотах спрятаны
	    (атрибут KlinokLakeHidden); остров, причал, кувшинки, камыш остаются.
	Повторный запуск пересобирает всё заново.
]]

local Workspace = game:GetService("Workspace")
local terrain = Workspace.Terrain

local hub = Workspace:FindFirstChild("Hub")
assert(hub, "нет Workspace.Hub")
local waterFolder = hub.World:FindFirstChild("Water")
assert(waterFolder, "нет Hub.World.Water")
local ground = hub.World:FindFirstChild("Ground")

local V = 4 -- воксель Terrain
local G = 2 -- клетка блоков берега и дна
local CENTER = Vector3.new(-30, 0, 1570)
local LAKE_R = 48
local LAKE_WOBBLE = 8
local RIVER_HALF = 6.5
local SURFACE = -0.35 -- уровень воды (трава — на 0)
local LOW = -12
local STEP_RUN = 3 -- через сколько стадов от берега — следующая ступень
local STEP_DROP = 0.9 -- высота ступени
local STEPS = 6

local hex = Color3.fromHex
local COLORS = {
	grass = hex("#86A85E"),
	sand = hex("#D8BE8A"),
	shallow = hex("#B9A27A"),
	deep = hex("#4E6A6A"),
}

-- ===== Форма воды =====

local function lakeRadius(angle: number): number
	local x, z = math.cos(angle), math.sin(angle)
	return LAKE_R + LAKE_WOBBLE * math.noise(x * 1.3 + 4, z * 1.3 + 7, 0.5) + 3 * math.noise(x * 4, z * 4, 2.1)
end

local segments = {}
for _, part in ipairs(waterFolder:GetChildren()) do
	if part.Name == "River" and part:IsA("BasePart") and part.Size.Z > 4 then
		local half = part.CFrame.LookVector * (part.Size.Z / 2)
		table.insert(segments, { a = part.Position - half, b = part.Position + half })
	end
end

local function segmentDistance(p: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	return (ap - ab * t).Magnitude
end

-- Знаковое расстояние до кромки воды: < 0 — вода.
local function waterDistance(x: number, z: number): number
	local dx, dz = x - CENTER.X, z - CENTER.Z
	local lake = math.sqrt(dx * dx + dz * dz) - lakeRadius(math.atan2(dz, dx))
	local p = Vector3.new(x, 0, z)
	local river = math.huge
	for _, s in ipairs(segments) do
		river = math.min(river, segmentDistance(p, s.a, s.b))
	end
	river -= RIVER_HALF + 1.5 * math.noise(x / 18, z / 18, 3.3)
	local k = 6
	local h = math.clamp(0.5 + 0.5 * (river - lake) / k, 0, 1)
	return river + (lake - river) * h - k * h * (1 - h)
end

-- ===== Участок =====

local minX, maxX, minZ, maxZ = CENTER.X - 80, CENTER.X + 80, CENTER.Z - 80, CENTER.Z + 80
for _, s in ipairs(segments) do
	for _, p in ipairs({ s.a, s.b }) do
		minX, maxX = math.min(minX, p.X - 20), math.max(maxX, p.X + 20)
		minZ, maxZ = math.min(minZ, p.Z - 20), math.max(maxZ, p.Z + 20)
	end
end
minX, minZ = math.floor(minX / V) * V, math.floor(minZ / V) * V
maxX, maxZ = math.ceil(maxX / V) * V, math.ceil(maxZ / V) * V

-- ===== Старая вода и плитки =====

-- Исходные свойства запоминаются в атрибуте KlinokLakeOrig и
-- возвращаются как были (служебные невидимые плиты остаются невидимыми).
local function setHidden(part: BasePart, hidden: boolean)
	if hidden then
		if not part:GetAttribute("KlinokLakeHidden") then
			part:SetAttribute("KlinokLakeHidden", true)
			part:SetAttribute("KlinokLakeOrig", ("%g,%d,%d,%d"):format(part.Transparency, part.CanCollide and 1 or 0, part.CanQuery and 1 or 0, part.CastShadow and 1 or 0))
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
		end
	elseif part:GetAttribute("KlinokLakeHidden") then
		local orig = string.split(part:GetAttribute("KlinokLakeOrig") or "", ",")
		part:SetAttribute("KlinokLakeHidden", nil)
		part:SetAttribute("KlinokLakeOrig", nil)
		part.Transparency = tonumber(orig[1]) or 0
		part.CanCollide = orig[2] ~= "0"
		part.CanQuery = orig[3] ~= "0"
		part.CastShadow = orig[4] ~= "0"
	end
end

local hidden, restored = 0, 0
local holes = {} -- рамки спрятанных деталей, которые закрывали землю
for _, part in ipairs(waterFolder:GetChildren()) do
	local bendDisc = part:IsA("Part") and part.Name == "Part" and part.Shape == Enum.PartType.Cylinder and part.Size.X <= 0.3 and part.Size.Y >= 17
	if part:IsA("BasePart") and (bendDisc or part.Name == "Water" or part.Name == "Shore" or part.Name == "River" or part.Name == "RiverBank") then
		setHidden(part, true)
		hidden += 1
		if part.Name == "Shore" or part.Name == "RiverBank" or bendDisc then
			if part.Shape == Enum.PartType.Cylinder then
				table.insert(holes, { center = part.Position, radius = part.Size.Y / 2 })
			else
				table.insert(holes, { cf = part.CFrame, half = part.Size / 2 })
			end
		end
	end
end
-- Плитка травы прячется, только если легла бы на воду. Рамки спрятанных
-- плиток запоминаем: дыру на их месте целиком закрывают блоки.
if ground then
	for _, tile in ipairs(ground:GetDescendants()) do
		if tile:IsA("BasePart") and tile.Position.Y < 1 and tile.Size.Y <= 2 then
			local half = tile.Size / 2
			local wet = false
			for _, o in ipairs({ { 0, 0 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
				local p = tile.CFrame * Vector3.new(o[1] * half.X * 0.95, 0, o[2] * half.Z * 0.95)
				if waterDistance(p.X, p.Z) < 0.5 then
					wet = true
					break
				end
			end
			local was = tile:GetAttribute("KlinokLakeHidden")
			setHidden(tile, wet)
			if wet then
				hidden += 1
				table.insert(holes, { cf = tile.CFrame, half = half })
			elseif was then
				restored += 1
			end
		end
	end
end

local function inHole(x: number, z: number): boolean
	for _, h in ipairs(holes) do
		if h.radius then
			if (Vector3.new(x, 0, z) - Vector3.new(h.center.X, 0, h.center.Z)).Magnitude <= h.radius + 1 then
				return true
			end
		else
			local p = h.cf:PointToObjectSpace(Vector3.new(x, h.cf.Y, z))
			if math.abs(p.X) <= h.half.X + 1 and math.abs(p.Z) <= h.half.Z + 1 then
				return true
			end
		end
	end
	return false
end

-- Дороги, которые раньше прятались под плоской рекой (у моста), режем:
-- кусок над водой убираем, сухие концы остаются. Повторный запуск
-- возвращает оригиналы и режет заново.
local roads = hub.World:FindFirstChild("Roads")
local roadPieces = 0
if roads then
	for _, piece in ipairs(roads:GetChildren()) do
		if piece:GetAttribute("KlinokLakePiece") then
			piece:Destroy()
		end
	end
	for _, road in ipairs(roads:GetChildren()) do
		if road:IsA("Part") then
			setHidden(road, false)
		end
		-- Невидимые служебные плиты (Roads.Base) не трогаем.
		if road:IsA("Part") and road.Transparency < 0.99 then
			if road.Shape == Enum.PartType.Cylinder then
				if waterDistance(road.Position.X, road.Position.Z) < 1 then
					setHidden(road, true)
				end
			else
				-- Длинная ось дороги — X или Z детали.
				local alongX = road.Size.X >= road.Size.Z
				local length = alongX and road.Size.X or road.Size.Z
				local width = alongX and road.Size.Z or road.Size.X
				local axis = alongX and road.CFrame.RightVector or road.CFrame.LookVector
				local side = alongX and road.CFrame.LookVector or road.CFrame.RightVector
				local runs, runStart, wetAny = {}, nil, false
				local stepLen = 0.5
				for i = 0, math.floor(length / stepLen) do
					local s = -length / 2 + i * stepLen
					local wet = false
					for _, w in ipairs({ -0.5, 0, 0.5 }) do
						local p = road.Position + axis * s + side * (w * width)
						if waterDistance(p.X, p.Z) < 0.5 then
							wet = true
						end
					end
					wetAny = wetAny or wet
					if not wet and not runStart then
						runStart = s
					elseif wet and runStart then
						table.insert(runs, { runStart, s })
						runStart = nil
					end
				end
				if runStart then
					table.insert(runs, { runStart, length / 2 })
				end
				if wetAny then
					setHidden(road, true)
					for _, r in ipairs(runs) do
						local len = r[2] - r[1]
						if len > 0.6 then
							local piece = road:Clone()
							piece:SetAttribute("KlinokLakeHidden", nil)
							piece:SetAttribute("KlinokLakePiece", true)
							piece.Transparency = 0
							piece.CanCollide = true
							piece.CanQuery = true
							piece.Size = alongX and Vector3.new(len, road.Size.Y, road.Size.Z) or Vector3.new(road.Size.X, road.Size.Y, len)
							piece.CFrame = road.CFrame + axis * ((r[1] + r[2]) / 2)
							piece.Parent = roads
							roadPieces += 1
						end
					end
				end
			end
		end
	end
end

-- ===== Terrain: только вода =====

terrain:FillBlock(CFrame.new((minX + maxX) / 2, (LOW + 8) / 2, (minZ + maxZ) / 2), Vector3.new(maxX - minX, 8 - LOW, maxZ - minZ), Enum.Material.Air)
local layers = (math.ceil(SURFACE / V) * V - LOW) / V -- до слоя с поверхностью
local CH = 32
local NX, NZ = (maxX - minX) / V, (maxZ - minZ) / V
for ci = 0, NX - 1, CH do
	for cj = 0, NZ - 1, CH do
		local w, l = math.min(CH, NX - ci), math.min(CH, NZ - cj)
		local mats, occs = {}, {}
		for a = 1, w do
			mats[a], occs[a] = {}, {}
			for b = 1, layers do
				mats[a][b], occs[a][b] = {}, {}
			end
			local x = minX + (ci + a - 1) * V + V / 2
			for c = 1, l do
				local z = minZ + (cj + c - 1) * V + V / 2
				local wet = waterDistance(x, z) < 1 -- чуть шире кромки: вода заходит под край блоков
				for b = 1, layers do
					local bottom = LOW + (b - 1) * V
					if wet then
						mats[a][b][c] = Enum.Material.Water
						occs[a][b][c] = math.max(math.clamp((SURFACE - bottom) / V, 0, 1), 0.05)
					else
						mats[a][b][c] = Enum.Material.Air
						occs[a][b][c] = 0
					end
				end
			end
		end
		local x0, z0 = minX + ci * V, minZ + cj * V
		terrain:WriteVoxels(Region3.new(Vector3.new(x0, LOW, z0), Vector3.new(x0 + w * V, LOW + layers * V, z0 + l * V)), V, mats, occs)
		task.wait()
	end
end
terrain.WaterColor = hex("#2F6F7A")
terrain.WaterTransparency = 0.55
terrain.WaterReflectance = 0.6
terrain.WaterWaveSize = 0.12
terrain.WaterWaveSpeed = 8

-- ===== Блоки берега и дна =====

local bed = waterFolder:FindFirstChild("LakeBed")
if bed then
	bed:Destroy()
end
bed = Instance.new("Folder")
bed.Name = "LakeBed"

-- Что уже лежит на клетке (плитка травы, остров, причал): туда блок не нужен.
local probe = RaycastParams.new()
probe.FilterType = Enum.RaycastFilterType.Include
probe.FilterDescendantsInstances = { hub.World }
local function covered(x: number, z: number): boolean
	local hit = Workspace:Raycast(Vector3.new(x, 6, z), Vector3.new(0, -7, 0), probe)
	return hit ~= nil and hit.Instance.Transparency < 1 and hit.Position.Y > -0.2
end

-- Клетка → top, color или nil.
local function cellOf(x: number, z: number)
	local d = waterDistance(x, z)
	if d < 0 then
		local step = math.min(math.floor(-d / STEP_RUN), STEPS)
		return SURFACE - 0.5 - step * STEP_DROP, COLORS.shallow:Lerp(COLORS.deep, step / STEPS)
	end
	if d < 14 or inHole(x, z) then
		-- Клетка закрыта целиком (центр и углы) — блок не нужен; закрыта
		-- частично — блок чуть ниже плитки (без мерцания), щели не будет.
		local h = G / 2 - 0.05
		local open = 0
		for _, o in ipairs({ { 0, 0 }, { -h, -h }, { h, -h }, { -h, h }, { h, h } }) do
			if not covered(x + o[1], z + o[2]) then
				open += 1
			end
		end
		if open > 0 then
			-- Суша у кромки: ровно с травой; у самой воды — песок.
			return open == 5 and 0 or -0.03, d < 2.5 and COLORS.sand or COLORS.grass
		end
	end
	return nil
end

local blocks = 0
local function block(x0: number, x1: number, z: number, top: number, color: Color3)
	local p = Instance.new("Part")
	p.Name = top < 0 and "Bed" or "Bank"
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	local height = top - (LOW + 2)
	p.Size = Vector3.new(x1 - x0, height, G)
	p.CFrame = CFrame.new((x0 + x1) / 2, top - height / 2, z)
	p.CastShadow = top >= 0
	p.Parent = bed
	blocks += 1
end

-- Ряды по X: соседние клетки с той же высотой и цветом — один блок.
for z = minZ + G / 2, maxZ, G do
	local runStart, runTop, runColor = nil, nil, nil
	local x = minX
	while x <= maxX do
		local top, color = nil, nil
		if x < maxX then
			top, color = cellOf(x + G / 2, z)
		end
		if runStart and (top ~= runTop or color ~= runColor) then
			block(runStart, x, z, runTop, runColor)
			runStart = nil
		end
		if top and not runStart then
			runStart, runTop, runColor = x, top, color
		end
		x += G
	end
	if z % 20 < G then
		task.wait()
	end
end
bed.Parent = waterFolder

-- Кувшинки и цветки — на уровень воды.
for _, part in ipairs(waterFolder:GetChildren()) do
	if part:IsA("BasePart") and (part.Name == "LilyPad" or (part.Name == "Part" and part.Size.X < 0.5 and part.Size.Y < 0.5)) then
		local lift = part.Name == "LilyPad" and 0.07 or 0.22
		part.CFrame = part.CFrame - Vector3.new(0, part.Position.Y - (SURFACE + lift), 0)
	end
end

print(("[BuildLake] готово: спрятано %d, плиток возвращено %d, блоков %d, кусков дорог %d. Ctrl+S."):format(hidden, restored, blocks, roadPieces))
return ("спрятано %d, возвращено %d, блоков %d, кусков дорог %d"):format(hidden, restored, blocks, roadPieces)
