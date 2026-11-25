--!nonstrict
-- dump_studio_scripts.lua — печатает пути всех скриптов в Studio
-- в формате ReplicatedStorage/Shared/Config/Loot (через слэши).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local roots = {
	{ prefix = "ReplicatedStorage", inst = ReplicatedStorage },
	{ prefix = "ServerScriptService", inst = ServerScriptService },
	{ prefix = "StarterPlayer/StarterPlayerScripts", inst = StarterPlayer:FindFirstChild("StarterPlayerScripts") },
}

local out = {}
for _, root in ipairs(roots) do
	if root.inst then
		for _, d in ipairs(root.inst:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
				local node, parts = d, {}
				while node and node ~= root.inst do
					table.insert(parts, 1, node.Name)
					node = node.Parent
				end
				table.insert(out, root.prefix .. "/" .. table.concat(parts, "/"))
			end
		end
	end
end
table.sort(out)
return table.concat(out, "\n")
