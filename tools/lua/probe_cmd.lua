--!nonstrict
-- probe_cmd.lua — можно ли вызывать отладочные команды из потока MCP.
local ServerStorage = game:GetService("ServerStorage")
local folder = ServerStorage:FindFirstChild("KlinokDebug")
if not folder then
	return "KlinokDebug нет"
end
local cmd = folder:FindFirstChild("Cmd")
local preview = folder:FindFirstChild("PreviewArmor")
local out = { "Cmd: " .. (cmd and "есть" or "нет") .. ", PreviewArmor: " .. (preview and "есть" or "нет") }
if cmd then
	local ok, result = pcall(function()
		return cmd:Invoke("help")
	end)
	table.insert(out, "вызов help: " .. tostring(ok) .. " / " .. tostring(result and string.sub(tostring(result), 1, 120)))
end
return table.concat(out, "\n")
