-- Превью этажа в режиме редактирования (без Play).
-- Studio кэширует require модулей по экземпляру, поэтому берём свежие копии:
-- оригинальный Shared временно переименовываем, кладём клон, собираем этаж
-- и возвращаем всё как было. Этаж остаётся в Workspace.Floor — перед
-- сохранением плейса его нужно удалить (в Play FloorService строит свой).
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local original = RS:FindFirstChild("Shared")
original.Name = "Shared_orig"
local shared = original:Clone()
shared.Name = "Shared"
shared.Parent = RS

local tmp = SS:FindFirstChild("_preview")
if tmp then
	tmp:Destroy()
end
tmp = Instance.new("Folder")
tmp.Name = "_preview"
tmp.Parent = SS
for _, name in ipairs({ "FloorBuilder", "FloorProps", "FloorScenery" }) do
	game.ServerScriptService.Systems[name]:Clone().Parent = tmp
end

local ok, result = pcall(function()
	local old = workspace:FindFirstChild("Floor")
	if old then
		old:Destroy()
	end
	local started = os.clock()
	require(tmp.FloorScenery).setupLighting()
	local Rooms = require(shared.Config.Rooms)
	local folder, rooms = require(tmp.FloorBuilder).build(workspace, Rooms.floor1())
	local parts = 0
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return ("rooms %d, parts %d, %.2fs"):format(#rooms, parts, os.clock() - started)
end)

shared:Destroy()
original.Name = "Shared"
tmp:Destroy()
return ok and result or ("ERROR: " .. tostring(result))
