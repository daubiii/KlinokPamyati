--!nonstrict
-- HubBoot (клиент)
-- Самостоятельный запуск клиентской части хаба: общий Bootstrap не правим.

local HubController = require(script.Parent:WaitForChild("HubController"))
HubController.start()
