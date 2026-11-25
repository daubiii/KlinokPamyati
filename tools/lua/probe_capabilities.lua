--!nonstrict
-- probe_capabilities.lua — можно ли снять ограничение Capabilities у папок,
-- чтобы новые скрипты создавались из MCP-потока.
local out = {}

local targets = {
	{ "RS.Shared.Config", game.ReplicatedStorage.Shared:FindFirstChild("Config") },
	{ "RS.Shared.Anim", game.ReplicatedStorage.Shared:FindFirstChild("Anim") },
	{ "SS.Systems", game.ServerScriptService:FindFirstChild("Systems") },
	{ "SPS.Windows", game.StarterPlayer.StarterPlayerScripts:FindFirstChild("Windows") },
}

for _, pair in ipairs(targets) do
	local name, folder = pair[1], pair[2]
	if not folder then
		table.insert(out, name .. ": нет папки")
		continue
	end

	local probe = Instance.new("Folder")
	probe.Name = "__cap_probe"

	local assigned, assignError = pcall(function()
		folder.Capabilities = probe.Capabilities
	end)

	local test = Instance.new("ModuleScript")
	test.Name = "__cap_test"
	test.Source = "return 1"
	local parented, parentError = pcall(function()
		test.Parent = folder
	end)

	if parented then
		test:Destroy()
	end
	probe:Destroy()

	table.insert(out, ("%s: сброс %s, создание скрипта %s%s"):format(
		name,
		assigned and "ок" or ("нельзя (" .. tostring(assignError) .. ")"),
		parented and "ок" or "ЗАПРЕТ",
		parented and "" or (" (" .. tostring(parentError) .. ")")
	))
end

return table.concat(out, "\n")
