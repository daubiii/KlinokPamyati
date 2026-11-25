--!nonstrict
-- find_asset_ids.lua — ищет, где в DataModel сидят указанные asset id.
local IDS = { "106670614727124", "11605233518808", "120301517846126" }

local PROPS = { "TextureID", "Image", "SoundId", "MeshId", "Texture", "ColorMap", "MetaMap", "NormalMap", "RoughnessMap", "TextureId" }

local out = {}
local function check(instance, prop)
	local ok, value = pcall(function()
		return instance[prop]
	end)
	if not ok or type(value) ~= "string" or value == "" then
		return
	end
	for _, id in ipairs(IDS) do
		if string.find(value, id, 1, true) then
			local path = instance:GetFullName()
			table.insert(out, id .. "  <-  " .. path .. "." .. prop)
		end
	end
end

local roots = { game:GetService("ReplicatedStorage"), game:GetService("Workspace"), game:GetService("ServerStorage"), game:GetService("StarterPlayer") }
for _, root in ipairs(roots) do
	for _, instance in ipairs(root:GetDescendants()) do
		for _, prop in ipairs(PROPS) do
			check(instance, prop)
		end
	end
end

if #out == 0 then
	return "не найдено ни в одном свойстве"
end
return table.concat(out, "\n")
