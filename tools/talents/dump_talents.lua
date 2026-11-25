-- Выгрузка Config/Talents в JSON для tools/talents/preview_talents.py и build_talent_art.py.
--   LUAU=… node tools/run-luau.js tools/talents/dump_talents.lua > /tmp/talents.json
local Shared = (_G :: any).KlinokShared
local Talents = require(Shared.Config.Talents)

local function enc(v): string
	local t = type(v)
	if t == "string" then
		return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
	elseif t == "number" or t == "boolean" then
		return tostring(v)
	elseif t == "table" then
		if #v > 0 or next(v) == nil then
			local parts = {}
			for _, x in ipairs(v) do
				table.insert(parts, enc(x))
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local keys = {}
		for k in pairs(v) do
			table.insert(keys, tostring(k))
		end
		table.sort(keys)
		local parts = {}
		for _, k in ipairs(keys) do
			table.insert(parts, enc(k) .. ":" .. enc(v[k]))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "null"
end

local out = { version = Talents.Version, maxLevel = Talents.MaxLevel, costs = Talents.Costs, layout = Talents.Layout, classes = {} }
for classId, tree in pairs(Talents.Classes) do
	local c = { id = classId, name = tree.name, title = tree.title, item = tree.item, branches = {} }
	for _, branch in ipairs(tree.branches) do
		local b = { id = branch.id, name = branch.name, text = branch.text, cost = branch.cost, nodes = {} }
		for _, n in ipairs(branch.nodes) do
			table.insert(b.nodes, { id = n.id, slot = n.slot, name = n.name, text = n.text, icon = n.icon,
				kind = n.kind, cost = n.cost, needs = n.needs })
		end
		table.insert(c.branches, b)
	end
	out.classes[classId] = c
end
return enc(out)
