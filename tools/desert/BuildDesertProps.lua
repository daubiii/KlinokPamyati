--[[
	BuildDesertProps — кактусы, сухие деревья, камни и обломки стен в пустыне
	вокруг замка (Workspace.Desert). Запуск после BuildDesert.lua, Studio, Edit.
	Повторный запуск пересобирает папку. Потом Ctrl+S.

	Всё воксельное, из деталей; без коллизий и лучей (за стены игрок не выходит).
	Ставится только на песок (Terrain) и не ближе CLEAR стадов к замку.
]]

local Workspace = game:GetService("Workspace")

local SEED = 2810
local CLEAR = 16 -- от деталей замка
local RANGE = { min = 24, max = 900 } -- от центра ближайшей части замка
local COUNTS = { saguaro = 150, barrel = 90, deadTree = 90, rock = 150, ruin = 26, bones = 30 }

local rng = Random.new(SEED)
local map = Workspace:FindFirstChild("Floor1Map")
assert(map, "нет Workspace.Floor1Map")

local old = Workspace:FindFirstChild("Desert")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Desert"

local hex = Color3.fromHex
local COLORS = {
	cactus = { hex("#5E8A3A"), hex("#4F7A32"), hex("#6B9744") },
	cactusDark = hex("#3E6227"),
	flower = { hex("#E86A9A"), hex("#F2C14E"), hex("#E9884A") },
	wood = { hex("#6B4A34"), hex("#5A3E2C"), hex("#7A5A42") },
	rock = { hex("#B07A4E"), hex("#9C6A44"), hex("#C08A5A") },
	stone = { hex("#4A4350"), hex("#5A5160"), hex("#3E3844") },
	bone = hex("#E8DDC6"),
}

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local function block(parent, size, cf, color, material)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- ===== Формы (cf — точка на песке, ось Y вверх) =====

local function saguaro(model, cf)
	local s = rng:NextNumber(0.8, 1.35)
	local color = pick(COLORS.cactus)
	local h = 7 * s
	block(model, Vector3.new(1.6, h, 1.6) * Vector3.new(s, 1, s), cf * CFrame.new(0, h / 2 - 0.4, 0), color)
	-- Рёбра: тонкие тёмные полосы.
	block(model, Vector3.new(0.3, h - 0.6, 1.7 * s), cf * CFrame.new(0, h / 2 - 0.4, 0), COLORS.cactusDark)
	for arm = 1, rng:NextInteger(1, 2) do
		local side = (arm == 1) and 1 or -1
		local y = h * rng:NextNumber(0.35, 0.6)
		local out = 1.6 * s
		local up = h * rng:NextNumber(0.25, 0.4)
		block(model, Vector3.new(out, 1.1 * s, 1.1 * s), cf * CFrame.new(side * (0.8 * s + out / 2), y, 0), color)
		block(model, Vector3.new(1.1 * s, up, 1.1 * s), cf * CFrame.new(side * (0.8 * s + out - 0.55 * s), y + up / 2 - 0.5, 0), color)
	end
	if rng:NextNumber() < 0.35 then
		block(model, Vector3.new(0.7, 0.4, 0.7) * s, cf * CFrame.new(0, h - 0.2, 0), pick(COLORS.flower))
	end
end

local function barrel(model, cf)
	local s = rng:NextNumber(0.7, 1.3)
	local color = pick(COLORS.cactus)
	block(model, Vector3.new(1.8, 1.4, 1.8) * s, cf * CFrame.new(0, 0.5 * s, 0), color)
	block(model, Vector3.new(1.3, 0.5, 1.3) * s, cf * CFrame.new(0, 1.3 * s, 0), color)
	if rng:NextNumber() < 0.6 then
		block(model, Vector3.new(0.5, 0.3, 0.5) * s, cf * CFrame.new(0, 1.65 * s, 0), pick(COLORS.flower))
	end
end

local function deadTree(model, cf)
	local s = rng:NextNumber(0.8, 1.5)
	local wood = pick(COLORS.wood)
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), 0, math.rad(rng:NextNumber(-10, 10)))
	local h = 6 * s
	local trunk = cf * lean
	block(model, Vector3.new(0.9, h, 0.9) * Vector3.new(s, 1, s), trunk * CFrame.new(0, h / 2 - 0.5, 0), wood)
	for b = 1, rng:NextInteger(3, 5) do
		local y = h * rng:NextNumber(0.45, 0.95)
		local len = rng:NextNumber(1.8, 3.5) * s
		local yaw = rng:NextNumber(0, math.pi * 2)
		local tilt = math.rad(rng:NextNumber(25, 60))
		local branch = trunk * CFrame.new(0, y, 0) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, -tilt)
		block(model, Vector3.new(len, 0.45 * s, 0.45 * s), branch * CFrame.new(len / 2, 0, 0), wood)
		if rng:NextNumber() < 0.5 then
			local twig = branch * CFrame.new(len, 0, 0) * CFrame.Angles(0, rng:NextNumber(-1, 1), math.rad(35))
			block(model, Vector3.new(len * 0.5, 0.3 * s, 0.3 * s), twig * CFrame.new(len * 0.25, 0, 0), wood)
		end
	end
	-- Корни-кочки у основания.
	block(model, Vector3.new(2, 0.5, 2) * s, cf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), wood)
end

local function rock(model, cf)
	local s = rng:NextNumber(0.6, 2.4)
	local color = pick(COLORS.rock)
	for _ = 1, rng:NextInteger(2, 4) do
		local size = Vector3.new(rng:NextNumber(1.5, 3), rng:NextNumber(1, 2.5), rng:NextNumber(1.5, 3)) * s
		local offset = Vector3.new(rng:NextNumber(-1.2, 1.2), size.Y * 0.3, rng:NextNumber(-1.2, 1.2)) * s
		local rot = CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3))
		block(model, size, cf * CFrame.new(offset) * rot, color, Enum.Material.Sandstone)
	end
end

-- Обломок старой стены: тот же камень, что у замка, по пояс в песке.
local function ruin(model, cf)
	local s = rng:NextNumber(0.9, 1.6)
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local base = cf * yaw
	local length = rng:NextInteger(2, 5)
	for i = 1, length do
		local h = rng:NextNumber(1.5, 6) * s
		block(model, Vector3.new(2, h, 2) * s, base * CFrame.new((i - length / 2) * 2 * s, h / 2 - 1, 0), pick(COLORS.stone), Enum.Material.Slate)
	end
	if rng:NextNumber() < 0.5 then
		block(model, Vector3.new(2.2, 2.2, 2.2) * s, base * CFrame.new(length * s + 1, 0.4, 1.5) * CFrame.Angles(0.4, 0.7, 0.2), pick(COLORS.stone), Enum.Material.Slate)
	end
end

-- Кости: череп и пара рёбер.
local function bones(model, cf)
	local yaw = cf * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	block(model, Vector3.new(1.2, 0.9, 1.6), yaw * CFrame.new(0, 0.3, 0), COLORS.bone)
	block(model, Vector3.new(0.4, 0.3, 0.6), yaw * CFrame.new(0, 0.35, -1.05), COLORS.bone)
	for i = 1, 4 do
		block(model, Vector3.new(0.25, 0.25, 2.2), yaw * CFrame.new(-1.8 + i * 0.6, 0.15, 2.4) * CFrame.Angles(0, 0, math.rad(70)), COLORS.bone)
	end
end

local MAKERS = { saguaro = saguaro, barrel = barrel, deadTree = deadTree, rock = rock, ruin = ruin, bones = bones }

-- ===== Расстановка =====

local Floor1v2 = require(game:GetService("ReplicatedStorage").Shared.Config.Floor1v2)
local castleCenters = {}
for _, zone in ipairs(Floor1v2.Zones) do
	local b = zone.box
	if b then
		table.insert(castleCenters, Vector3.new((b[1] + b[4]) / 2, 0, (b[3] + b[6]) / 2))
	end
end

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { map }
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }

local placed = {}
local function spot()
	for _ = 1, 40 do
		local anchor = castleCenters[rng:NextInteger(1, #castleCenters)]
		-- Ближе к замку гуще: расстояние с квадратичным уклоном к малым.
		local d = RANGE.min + (RANGE.max - RANGE.min) * rng:NextNumber() ^ 2
		local a = rng:NextNumber(0, math.pi * 2)
		local x, z = anchor.X + math.cos(a) * d, anchor.Z + math.sin(a) * d
		if z < 740 then
			local hit = Workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -170, 0), rayParams)
			if hit and #Workspace:GetPartBoundsInRadius(hit.Position, CLEAR, overlap) == 0 then
				local ok = true
				for _, p in ipairs(placed) do
					if (p - hit.Position).Magnitude < 6 then
						ok = false
						break
					end
				end
				if ok then
					table.insert(placed, hit.Position)
					return hit
				end
			end
		end
	end
	return nil
end

local total = 0
for kind, count in pairs(COUNTS) do
	local folder = Instance.new("Folder")
	folder.Name = kind
	folder.Parent = root
	for n = 1, count do
		local hit = spot()
		if hit then
			local model = Instance.new("Model")
			model.Name = kind
			-- Чуть утопить в песок; на склоне — по нормали, но не круче 15°.
			local up = hit.Normal:Lerp(Vector3.yAxis, 0.6).Unit
			local cf = CFrame.lookAt(hit.Position - Vector3.new(0, 0.25, 0), hit.Position - Vector3.new(0, 0.25, 0) + up)
				* CFrame.Angles(-math.pi / 2, 0, 0)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			MAKERS[kind](model, cf)
			model.Parent = folder
			total += 1
		end
		if n % 20 == 0 then
			task.wait()
		end
	end
end
root.Parent = Workspace

print(("[BuildDesertProps] готово: %d предметов. Ctrl+S."):format(total))
return "предметов " .. total
