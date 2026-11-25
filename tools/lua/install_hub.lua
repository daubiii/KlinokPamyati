--!nonstrict
-- install_hub.lua — разовая установка хаба «Долина Последнего Эха» (Edit-режим).
--
-- Перед запуском: Studio → правый клик по Workspace → Insert from File… →
-- Hub.rbxmx. В Workspace появятся папки Hub и HubAccessories.
--
-- Что делает (повторный запуск безопасен):
--   1. HubAccessories → ReplicatedStorage;
--   2. сдвигает Workspace.Hub на HubLayout.Origin (сборка сделана вокруг
--      (0, 0), где строится этаж); сдвиг помнит атрибут HubOffset;
--   3. помечает модели деревни и пещеры ModelStreamingMode = Atomic;
--   4. включает StreamingEnabled (ТЗ, раздел 11);
--   5. удаляет старый хаб «Кузня Эха», если он остался в файле места.
-- После запуска: Ctrl+S.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubLayout = require(ReplicatedStorage.Shared.Config.HubLayout)

local report = {}
local function note(text)
	table.insert(report, text)
end

-- 1. Аксессуары жителей.
local accessories = Workspace:FindFirstChild("HubAccessories")
if accessories then
	local old = ReplicatedStorage:FindFirstChild("HubAccessories")
	if old then
		old:Destroy()
	end
	accessories.Parent = ReplicatedStorage
	note("HubAccessories → ReplicatedStorage")
elseif ReplicatedStorage:FindFirstChild("HubAccessories") then
	note("HubAccessories уже в ReplicatedStorage")
else
	note("ВНИМАНИЕ: нет HubAccessories")
end

-- 2. Сдвиг долины.
local hub = Workspace:FindFirstChild("Hub")
if not hub then
	return "Нет Workspace.Hub: сначала Insert from File → Hub.rbxmx"
end
local current = hub:GetAttribute("HubOffset") or Vector3.zero
local delta = HubLayout.Origin - current
if delta.Magnitude > 0.001 then
	local moved = 0
	for index, child in ipairs(hub:GetDescendants()) do
		if child:IsA("Model") and not child:FindFirstAncestorOfClass("Model") then
			child:PivotTo(child:GetPivot() + delta)
			moved += 1
		elseif child:IsA("BasePart") and not child:FindFirstAncestorOfClass("Model") then
			child.CFrame += delta
			moved += 1
		end
		if index % 2000 == 0 then
			task.wait()
		end
	end
	hub:SetAttribute("HubOffset", HubLayout.Origin)
	note(("Сдвинуто объектов: %d на %s"):format(moved, tostring(delta)))
else
	note("Сдвиг уже сделан: " .. tostring(current))
end

-- 3. Атомарный стриминг домов и пещеры: не появляются по частям.
local atomic = 0
for _, folderName in ipairs({ "Village", "Cave", "Pass", "Lake", "Signs" }) do
	local folder = hub:FindFirstChild(folderName)
	if folder then
		for _, model in ipairs(folder:GetChildren()) do
			if model:IsA("Model") then
				model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
				atomic += 1
			end
		end
	end
end
note("Atomic-моделей: " .. atomic)

-- 4. Стриминг (карта большая).
Workspace.StreamingEnabled = true
-- В части сборок Studio радиусы скриптом не меняются: тогда руками в свойствах Workspace.
for property, value in pairs({ StreamingTargetRadius = 512, StreamingMinRadius = 128 }) do
	local ok = pcall(function()
		Workspace[property] = value
	end)
	note(("%s = %s%s"):format(property, tostring(value), ok and "" or " — НЕ ЗАДАНО, выставить руками"))
end

-- 5. Старый хаб в файле места (если остался от прошлых сохранений).
for _, name in ipairs({ "HubVillagers", "HubStations", "HubFx", "HubLife" }) do
	local leftover = Workspace:FindFirstChild(name)
	if leftover then
		leftover:Destroy()
		note("Удалено: Workspace." .. name)
	end
end

local parts = 0
for _, d in ipairs(hub:GetDescendants()) do
	if d:IsA("BasePart") then
		parts += 1
	end
end
note("Деталей в хабе: " .. parts)
return table.concat(report, "\n")
