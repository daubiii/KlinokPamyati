--[[
	BuildDesert — пустыня вокруг замка этажа 1 (Terrain).
	Запуск: Studio, режим Edit (Command Bar или tools/fx/run_in_studio.py).
	Потом Ctrl+S: Terrain живёт в файле места.

	Замок стоит прямо на песке (решение Артёма 28.10.2026): песок вровень с
	полом (верх ≈ +0.5), внутри замка вырезан. «Внутри» = луч вниз попал в
	коллизию Floor1Map (полы, стены) или в яму под мостом. Дальше от стен
	начинаются дюны, к горизонту — до 35 стадов.

	Хаб (z ≥ 1000) не трогается: пустыня кончается на z = END_Z.
	Повторный запуск перезаписывает тот же участок.
]]

local Workspace = game:GetService("Workspace")
local terrain = Workspace.Terrain

local MIN_X, MAX_X = -1100, 1100
local MIN_Z, END_Z = -1500, 760
local V = 4 -- размер вокселя
local BASE_TOP = 0.5 -- верх песка у стен замка
local LOW_Y, HIGH_Y = -12, 40 -- слои Terrain

-- Где искать замок (с запасом вокруг Floor1Map).
local CX0, CX1, CZ0, CZ1 = -200, 200, -640, 172
-- Яма под мостом: дна-коллизии нет, поэтому вырезаем по контуру её стен.
local PIT = { x0 = -106.5, z0 = -179.5, x1 = -27.5, z1 = -102.5 }

local map = Workspace:FindFirstChild("Floor1Map")
assert(map, "нет Workspace.Floor1Map")

local collisions = {}
for _, zone in ipairs(map:GetChildren()) do
	-- Решётки ворот (Dynamic) в Edit закрыты: заливка не уйдёт в комнаты через проёмы.
	for _, name in ipairs({ "Collision", "Dynamic" }) do
		local folder = zone:FindFirstChild(name)
		if folder then
			table.insert(collisions, folder)
		end
	end
end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = collisions

local NX = (MAX_X - MIN_X) / V
local NZ = (END_Z - MIN_Z) / V

-- 1. Пробы каждые 2 стада: пусто / пол / стена. Пол вне игровых зон
-- (Floor1v2.Zones[].box: площадка перед «Порогом», тёмная плита у стен)
-- тоже засыпаем; пол комнат и стены — нет.
local Floor1v2 = require(game:GetService("ReplicatedStorage").Shared.Config.Floor1v2)
local function inZone(x, z)
	for _, zone in ipairs(Floor1v2.Zones) do
		local b = zone.box
		-- Пол всех зон, включая «Порог», остаётся чистым (правка Артёма 28.10.2026).
		if b and x >= b[1] - 1 and x <= b[4] + 1 and z >= b[3] - 1 and z <= b[6] + 1 then
			return true
		end
	end
	return false
end

local P = 2
local PX = (CX1 - CX0) / P
local PZ = (CZ1 - CZ0) / P
local FLOOR, SOLID, SAND = 1, 2, 3
local cell = table.create(PX * PZ, SAND)
local function pidx(a, b)
	return b * PX + a + 1
end
local probes, opened = 0, 0
for a = 0, PX - 1 do
	local px = CX0 + a * P + P / 2
	for b = 0, PZ - 1 do
		local pz = CZ0 + b * P + P / 2
		local k = pidx(a, b)
		if px > PIT.x0 and px < PIT.x1 and pz > PIT.z0 and pz < PIT.z1 then
			cell[k] = SOLID
		else
			local hit = Workspace:Raycast(Vector3.new(px, 95, pz), Vector3.new(0, -140, 0), params)
			if hit then
				if hit.Position.Y > 1 then
					cell[k] = SOLID -- стена, ящик, колонна
				elseif inZone(px, pz) then
					cell[k] = FLOOR -- пол комнаты
				else
					opened += 1 -- пол вне зон: засыпаем
				end
			end
		end
		probes += 1
	end
	if a % 10 == 0 then
		task.wait()
	end
end

-- Стены по периметру: песок можно класть и в них (внутри стены его не видно),
-- иначе Terrain сглаживает край вниз и вдоль стен выходит канавка. Стена —
-- «твёрдая» клетка, рядом с которой (до 2 проб) уже песок. Яму не трогаем.
local grow = {}
for a = 0, PX - 1 do
	for b = 0, PZ - 1 do
		local k = pidx(a, b)
		local px, pz = CX0 + a * P + P / 2, CZ0 + b * P + P / 2
		local inPit = px > PIT.x0 - 2 and px < PIT.x1 + 2 and pz > PIT.z0 - 2 and pz < PIT.z1 + 2
		if cell[k] == SOLID and not inPit then
			for da = -2, 2 do
				for db = -2, 2 do
					local na, nb = a + da, b + db
					if na >= 0 and na < PX and nb >= 0 and nb < PZ and cell[pidx(na, nb)] == SAND then
						grow[k] = true
					end
				end
			end
		end
	end
end
for k in pairs(grow) do
	cell[k] = SAND
end

-- Доля песка в каждой колонне вокселей (4 пробы 2×2 на колонну).
local outside = table.create(NX * NZ, 1)
local function idx(i, j)
	return j * NX + i + 1
end
for i = 0, NX - 1 do
	local x = MIN_X + i * V
	if x + V > CX0 and x < CX1 then
		for j = 0, NZ - 1 do
			local z = MIN_Z + j * V
			if z + V > CZ0 and z < CZ1 then
				local sand = 0
				for _, o in ipairs({ { 0, 0 }, { 2, 0 }, { 0, 2 }, { 2, 2 } }) do
					local a = math.floor((x + o[1] - CX0) / P)
					local b = math.floor((z + o[2] - CZ0) / P)
					if a < 0 or a >= PX or b < 0 or b >= PZ or cell[pidx(a, b)] == SAND then
						sand += 1
					end
				end
				outside[idx(i, j)] = sand / 4
			end
		end
	end
end

-- 2. Расстояние от замка (колонны со стенами/полом — источники), шаги по 4 стада.
local dist = table.create(NX * NZ, math.huge)
local queue, head = {}, 1
for i = 0, NX - 1 do
	for j = 0, NZ - 1 do
		if outside[idx(i, j)] < 1 then
			dist[idx(i, j)] = 0
			table.insert(queue, idx(i, j) - 1)
		end
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

-- 3. Высота песка: ровно у замка, дюны дальше.
local function smooth(e0, e1, x)
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end
local function heightAt(x, z, d)
	local n1 = math.noise(x / 260, z / 260, 1.7)
	local n2 = math.noise(x / 90, z / 90, 4.2)
	local ridge = 1 - math.abs(math.noise(x / 150 + n1 * 0.6, z / 150, 9.1)) * 2
	local dune = 3 + 14 * ridge * ridge + 10 * (n1 + 0.5) + 3 * n2
	local k = smooth(35, 220, d)
	return math.clamp(BASE_TOP + dune * k, BASE_TOP, HIGH_Y - 5)
end
local function materialAt(x, z, d)
	if d > 70 and math.noise(x / 70, z / 70, 13.3) > 0.32 then
		return Enum.Material.Sandstone
	end
	return Enum.Material.Sand
end

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
				local share = outside[k]
				local h = heightAt(x, z, dist[k])
				local material = materialAt(x, z, dist[k])
				for b = 1, layers do
					local bottom = LOW_Y + (b - 1) * V
					-- Ниже нуля краевые колонны заполняем почти целиком (верх −0.4,
					-- под полом не видно), иначе у стен Terrain проседает воронкой.
					local fill = share
					if bottom < 0 and share > 0 then
						fill = math.max(share, 0.9)
					end
					local occ = math.clamp((h - bottom) / V, 0, 1) * fill
					if occ > 0.02 then
						mats[a][b][c] = material
						occs[a][b][c] = occ
					else
						mats[a][b][c] = Enum.Material.Air
						occs[a][b][c] = 0
					end
				end
			end
		end
		local x0 = MIN_X + ci * V
		local z0 = MIN_Z + cj * V
		local region = Region3.new(Vector3.new(x0, LOW_Y, z0), Vector3.new(x0 + w * V, HIGH_Y, z0 + l * V))
		terrain:WriteVoxels(region, V, mats, occs)
		written += 1
		task.wait()
	end
end

-- Цвета песка (те же ставит FloorScenery): приглушённые, иначе закат их выжигает.
terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromHex("#5C4D42"))
terrain:SetMaterialColor(Enum.Material.Sandstone, Color3.fromHex("#4E3B30"))

print(("[BuildDesert] готово: %d проб замка, засыпано площадок %d, %d кусков Terrain. Ctrl+S."):format(probes, opened, written))
return ("проб %d, засыпано пола %d, кусков %d"):format(probes, opened, written)
