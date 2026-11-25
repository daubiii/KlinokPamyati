--!nonstrict
-- check_sand_point.lua — что за песок над точкой x=-169, z=-50.
local W = game.Workspace
local T = W.Terrain
local out = {}

local probes = { { -169, -50 }, { -109, 30 }, { -89, -30 }, { 0, 0 } }
for _, p in ipairs(probes) do
	local x, z = p[1], p[2]
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { T }
	local hit = W:Raycast(Vector3.new(x, 40, z), Vector3.new(0, -80, 0), params)
	if hit then
		table.insert(out, string.format("x=%d z=%d: террейн y=%.2f (%s)", x, z, hit.Position.Y, tostring(hit.Material)))
	else
		table.insert(out, string.format("x=%d z=%d: террейна нет", x, z))
	end
	-- воксель в этой колонке на высоте 2
	local region = Region3.new(Vector3.new(x - 2, -2, z - 2), Vector3.new(x + 2, 6, z + 2))
	local ok, mats = pcall(function()
		return T:ReadVoxels(region, 4)
	end)
	if ok then
		local found = {}
		for xi = 1, mats.Size.X do
			for yi = 1, mats.Size.Y do
				for zi = 1, mats.Size.Z do
					local m = mats[xi][yi][zi]
					if m ~= Enum.Material.Air then
						found[m.Name] = true
					end
				end
			end
		end
		local names = {}
		for name in pairs(found) do
			table.insert(names, name)
		end
		table.insert(out, "    воксели -2..6: " .. (#names > 0 and table.concat(names, ", ") or "воздух"))
	else
		table.insert(out, "    ReadVoxels: " .. tostring(mats))
	end
end
return table.concat(out, "\n")
