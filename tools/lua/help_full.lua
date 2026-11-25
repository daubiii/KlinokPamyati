--!nonstrict
-- help_full.lua — полный текст справки отладочных команд.
local ServerStorage = game:GetService("ServerStorage")
local folder = ServerStorage:FindFirstChild("KlinokDebug")
local cmd = folder and folder:FindFirstChild("Cmd")
if not cmd then
	return "нет Cmd"
end
local ok, result = pcall(function()
	return cmd:Invoke("help")
end)
if not ok then
	return "ошибка: " .. tostring(result)
end
return tostring(result)
