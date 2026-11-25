--!nonstrict
-- HubBoot (сервер)
-- Самостоятельный запуск хаба: основной Bootstrap проекта не правим.
-- Ждём папку Systems, чтобы FloorService и DataService уже существовали.

local ServerScriptService = game:GetService("ServerScriptService")

ServerScriptService:WaitForChild("Systems")
local HubService = require(script.Parent:WaitForChild("HubService"))
HubService.start()
