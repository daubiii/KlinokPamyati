--!nonstrict
-- TutorialService — слайды-справка после вступительного ролика (вариант 2,
-- решение владельца: физическая полоса обучения заменена справкой).
-- Никакой геометрии и телепортов: сервис помечает новичка атрибутом
-- ShowSlides (клиент показывает слайды после ролика) и принимает событие
-- закрытия справки — после неё tutorialDone = true (один раз, DataStore).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TutorialService = {}

local DataService = require(script.Parent.DataService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Classes"))

local doneRemote = nil

-- Новичок без метки получит справку после ролика (клиент следит за FilmPlaying).
function TutorialService.onCharacter(player)
	local profile = DataService.get(player)
	if not profile or profile.tutorialDone == true then
		print(("[Tutorial] %s: справка пропущена (уже пройдено или профиль не готов)"):format(player.Name))
		return
	end
	player:SetAttribute("ShowSlides", true)
	print(("[Tutorial] %s: покажем справку-знакомство"):format(player.Name))
end

function TutorialService.start()
	doneRemote = Instance.new("RemoteEvent")
	doneRemote.Name = "TutorialSlidesDone"
	doneRemote.Parent = ReplicatedStorage
	doneRemote.OnServerEvent:Connect(function(player)
		if not RemoteGuard.allow(player, "TutorialSlidesDone") then
			return
		end
		-- защита от повторов: метка снимается один раз
		if player:GetAttribute("ShowSlides") ~= true then
			return
		end
		player:SetAttribute("ShowSlides", nil)
		local profile = DataService.get(player)
		if profile then
			profile.tutorialDone = true
			pcall(function() DataService.requestSave(player) end)
			-- После справки — выбор класса (если ещё не выбран).
			if profile.classChosen ~= true then
				player:SetAttribute("ShowClassSelect", true)
			end
		end
		print(("[Tutorial] %s: справка закрыта, tutorialDone = true"):format(player.Name))
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.1)
			TutorialService.onCharacter(player)
		end)
		if player.Character then
			TutorialService.onCharacter(player)
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		TutorialService.onCharacter(player)
	end

	-- Выбор класса: RemoteFunction вызывается кнопкой карточки (клиент).
	-- Применяет класс по той же цепочке, что DebugCommands.class: броня класса,
	-- стартовое оружие, публикация мага, уровень, мана. Один раз (classChosen).
	function TutorialService.applyClassChoice(player, classId)
		local profile = DataService.get(player)
		if not profile or DataService.status(player) ~= "ready" then
			return { ok = false, err = "Профиль ещё не загружен" }
		end
		if typeof(classId) ~= "string" or not Classes.get(classId) or Classes.Hidden[classId] then
			return { ok = false, err = "Нет такого класса" }
		end
		local ArmorService = require(script.Parent.ArmorService)
		local EquipmentService = require(script.Parent.EquipmentService)
		local ProgressionService = require(script.Parent.ProgressionService)

		profile.className = classId
		profile.classChosen = true
		player:SetAttribute("ShowClassSelect", nil)
		ArmorService.onClassChanged(player)
		EquipmentService.ensureClassWeapon(player)
		pcall(function()
			local MageService = require(script.Parent.MageService)
			if MageService.publishClass then
				MageService.publishClass(player)
			end
		end)
		ProgressionService.applyLevel(player, true)
		pcall(function()
			local ManaService = require(script.Parent.ManaService)
			ManaService.recalc(player, true)
		end)
		pcall(function()
			DataService.requestSave(player, 5)
		end)
		print(("[Tutorial] %s: выбран класс %s"):format(player.Name, classId))
		return { ok = true, className = classId }
	end

	local selectRemote = Instance.new("RemoteFunction")
	selectRemote.Name = "RequestClassSelect"
	selectRemote.Parent = ReplicatedStorage
	selectRemote.OnServerInvoke = RemoteGuard.wrap("RequestClassSelect", function(player, classId)
		return TutorialService.applyClassChoice(player, classId)
	end)

	-- Игрок зашёл, справку уже закрыл, а класс не выбрал (перезаход) — окно снова.
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataService.get(player)
		if profile and profile.classChosen ~= true and player:GetAttribute("ShowSlides") ~= true then
			player:SetAttribute("ShowClassSelect", true)
		end
	end
	print("[TutorialService] слайды-справка готовы (вариант 2)")
end

return TutorialService
