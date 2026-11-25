--!nonstrict
-- check_disk_vs_studio.lua — сверяет скрипты на диске с тем, что в Studio.
-- Возвращает: сколько файлов на диске, сколько скриптов в Studio и расхождения.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local roots = {
	{ name = "ReplicatedStorage", path = "ReplicatedStorage", instance = ReplicatedStorage },
	{ name = "ServerScriptService", path = "ServerScriptService", instance = ServerScriptService },
	{ name = "StarterPlayerScripts", path = "StarterPlayer/StarterPlayerScripts", instance = StarterPlayer:FindFirstChild("StarterPlayerScripts") },
}

local inStudio = {}
for _, root in ipairs(roots) do
	if root.instance then
		for _, descendant in ipairs(root.instance:GetDescendants()) do
			if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
				local node = descendant
				local parts = {}
				while node and node ~= root.instance do
					table.insert(parts, 1, node.Name)
					node = node.Parent
				end
				table.insert(inStudio, root.path .. "/" .. table.concat(parts, "."))
			end
		end
	end
end

table.sort(inStudio)

-- Список файлов на диске приходит аргументом-текстом через _G (см. runner).
local onDisk = _G.__KLINOK_DISK_FILES or {}
local diskSet = {}
for _, path in ipairs(onDisk) do
	diskSet[path] = true
end

local studioOnly = {}
for _, path in ipairs(inStudio) do
	-- Studio-путь вида "ReplicatedStorage/Shared.Config.Loot"; на диске — со слэшами.
	local diskLike = path:gsub("%.", "/")
	if not diskSet[diskLike] then
		table.insert(studioOnly, path)
	end
end

return ("в Studio скриптов: %d; файлов на диске передано: %d; только в Studio: %d\n%s"):format(
	#inStudio,
	#onDisk,
	#studioOnly,
	table.concat(studioOnly, "\n")
)
