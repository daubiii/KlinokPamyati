--!nonstrict
-- lower_sand_chunks.lua — то же, но кусками 64×64: большие FillRegion молча
-- не применяются, поэтому режем по частям и каждую проверяем.
local W = game.Workspace
local T = W.Terrain
local map = W:FindFirstChild("Floor1Map")
if not map then
	return "нет Floor1Map"
end
local out = {}

local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
for _, d in ipairs(map:GetDescendants()) do
	if d:IsA("BasePart") then
		local p = d.Position
		minX = math.min(minX, p.X)
		maxX = math.max(maxX, p.X)
		minZ = math.min(minZ, p.Z)
		maxZ = math.max(maxZ, p.Z)
	end
end
local pad = 60
minX -= pad; maxX += pad; minZ -= pad; maxZ += pad
local yBottom, yTop = -4.0, 8
local chunk = 64

local chunks = 0
local removedTotal = 0
for x = minX, maxX, chunk do
	for z = minZ, maxZ, chunk do
		local x1 = x
		local z1 = z
		local x2 = math.min(x + chunk, maxX)
		local z2 = math.min(z + chunk, maxZ)
		local region = Region3.new(Vector3.new(x1, yBottom, z1), Vector3.new(x2, yTop, z2))
		local ok, voxels = pcall(function()
			return T:ReadVoxels(region, 4)
		end)
		if ok then
			local removed = 0
			for xi = 1, voxels.Size.X do
				for yi = 1, voxels.Size.Y do
					for zi = 1, voxels.Size.Z do
						if voxels[xi][yi][zi] ~= Enum.Material.Air then
							removed += 1
						end
					end
				end
			end
			if removed > 0 then
				T:FillRegion(region, 4, Enum.Material.Air)
				removedTotal += removed
				chunks += 1
			end
		end
	end
end
table.insert(out, ("кусков с песком: %d, снято вокселей: %d"):format(chunks, removedTotal))

-- контрольная проверка через 1 секунду
task.wait(1)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { T }
local check = {}
for _, p in ipairs({ { -169, -50 }, { -109, 30 }, { 0, 0 }, { 100, -290 } }) do
	local hit = W:Raycast(Vector3.new(p[1], 40, p[2]), Vector3.new(0, -80, 0), params)
	table.insert(check, string.format("x=%d z=%d: %s", p[1], p[2],
		hit and string.format("песок y=%.1f", hit.Position.Y) or "чисто"))
end
table.insert(out, table.concat(check, "; "))
return table.concat(out, "\n")
