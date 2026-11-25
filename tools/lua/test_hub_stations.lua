--!nonstrict
-- test_hub_stations.lua — проверка станций, жителей и задания «Голоса долины» (Client, Play).
-- Игрок переносится к каждой станции, ждёт подгрузки (стриминг), смотрит
-- подсказку и открывает станцию тем же ремоутом, что и клавиша E.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Hub = require(ReplicatedStorage.Shared.Config.Hub)
local HubLayout = require(ReplicatedStorage.Shared.Config.HubLayout)

local player = Players.LocalPlayer
local net = ReplicatedStorage:WaitForChild(Hub.NetFolder)
local RequestStation = net.RequestStation
local RequestQuest = net.RequestQuest

local out = {}
local function log(ok, text)
	table.insert(out, (ok and "OK  " or "ERR ") .. text)
end

local function goTo(position: Vector3)
	player.Character:PivotTo(CFrame.new(position + Vector3.new(0, 3.5, 0)))
	task.wait(5) -- стриминг и пересчёт ближайшей станции
end

local function hint(): string
	local gui = player.PlayerGui:FindFirstChild("KlinokHub")
	local button = gui and gui:FindFirstChild("TextButton", true)
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("TextButton") and d.Visible and d.Text:sub(1, 1) == "[" then
			return d.Text
		end
	end
	return button and "" or "нет интерфейса"
end

-- Станции.
for id, station in pairs(Hub.Stations) do
	local point = HubLayout.world(HubLayout.Points[station.point])
	if station.point == "Archive" or station.point == "Altar" then
		goTo(HubLayout.world(HubLayout.Points.QuestBoard))
	end
	goTo(point + Vector3.new(2, 0, 2))
	task.wait(0.2)
	local response = RequestStation:InvokeServer(id)
	task.wait(0.45) -- троттлинг станций 0,4 с
	local ok = type(response) == "table" and response.ok == true and response.kind == station.kind
	log(ok, ("%s (%s): kind=%s, подсказка «%s»"):format(id, station.name, tostring(response and response.kind), hint()))
end

-- Задание «Голоса долины».
local snapshot = RequestQuest:InvokeServer("get")
task.wait(0.5)
local take = RequestQuest:InvokeServer("take", "voices")
log(type(take) == "table" and take.ok, "взять «Голоса долины»: " .. tostring(take and (take.err or take.ok)))
local completed = nil
net.QuestUpdate.OnClientEvent:Connect(function(_, done)
	if done then
		completed = done
	end
end)

-- Разговоры: пять разных жителей + Кузнец-Эхо (первая реплика — К-1).
local talked = 0
for _, id in ipairs({ "SmithEcho", "Olgerd", "Marta", "Efim", "Ivga", "Feofan" }) do
	local model = workspace.HubVillagers:FindFirstChild(id)
	if not model then
		goTo(HubLayout.world(HubLayout.Points.Square))
		model = workspace.HubVillagers:WaitForChild(id, 5)
	end
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if root then
		goTo(root.Position + Vector3.new(3, -3, 0))
		local response = RequestStation:InvokeServer("villager:" .. id)
		task.wait(0.45)
		local ok = type(response) == "table" and response.ok and response.kind == "talk"
		if ok then
			talked += 1
		end
		log(ok, ("житель %s: %s"):format(id, ok and (response.name .. " — " .. response.line) or "нет ответа"))
	else
		log(false, "житель " .. id .. " не найден у клиента")
	end
end
task.wait(1)
log(completed ~= nil, "задание выполнено: " .. tostring(completed and (completed.completed .. " / " .. completed.reward)))
log(player:GetAttribute("Gold") ~= nil, "золото после награды: " .. tostring(player:GetAttribute("Gold")))
return table.concat(out, "\n")
