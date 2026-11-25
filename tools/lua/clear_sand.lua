--!nonstrict
-- clear_sand.lua — убирает песок (террейн) над полом зон этажа 1.
-- Песчаная плита пустыни местами стоит на 2.6 стада выше пола карты и торчит
-- внутри зон. Вырезаем воздух в пределах габаритов зон от -0.6 до +8 по Y.
local T = game.Workspace.Terrain
local out = {}

-- Габариты зон из Config/Floor1v2 (box = x1, y1, z1, x2, y2, z2)
local boxes = {
	{ "intro", -16, 103, 16, 145 },
	{ "yard", -31, 42, 31, 100 },
	{ "street", -105, 12.5, 12, 39.5 },
	{ "warehouse", -69, -25, -39, 13 },
	{ "plaza", -155, -47, -93, 14 },
	{ "barbican", -157, -127, -83, -47 },
	{ "rest1", -135, -155, -105, -127 },
	{ "bridge", -106, -168, -28, -120 },
	{ "armory", -29, -167, 29, -113 },
	{ "forge", 29, -154, 68, -126 },
	{ "gallery", -12, -264, 12, -165 },
	{ "tower", -33, -323, 33, -262 },
	{ "hall", 46, -317, 100, -263 },
	{ "chapel", 98, -306, 135, -273 },
	{ "lastgates", 88, -367, 148, -305 },
	{ "boss", 70, -468, 166, -366 },
}

local yBottom, yTop = -0.6, 8
local total = 0
for _, b in ipairs(boxes) do
	local name, x1, z1, x2, z2 = b[1], b[2], b[3], b[4], b[5]
	local region = Region3.new(
		Vector3.new(math.min(x1, x2), yBottom, math.min(z1, z2)),
		Vector3.new(math.max(x1, x2), yTop, math.max(z1, z2))
	)
	local before = T:ReadVoxels(region, 4)
	local removed = 0
	for x = 1, before.Size.X do
		for y = 1, before.Size.Y do
			for z = 1, before.Size.Z do
				if before[x][y][z] ~= Enum.Material.Air then
					removed += 1
				end
			end
		end
	end
	T:FillRegion(region, 4, Enum.Material.Air)
	total += removed
	if removed > 0 then
		table.insert(out, string.format("%-11s воздух в %d вокселях", name, removed))
	end
end
table.insert(out, 1, ("зон обработано: %d, вокселей очищено: %d"):format(#boxes, total))
return table.concat(out, "\n")
