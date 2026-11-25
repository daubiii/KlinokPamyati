--!nonstrict
-- UiNet
-- Ремоуты окон-сцен (папка ReplicatedStorage.KlinokUiNet). Сервер создаёт
-- нужные RemoteFunction через UiNet.ensure; клиент ищет через UiNet.find и,
-- если ремоута нет, StationApi показывает пример данных.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UiNet = {}
UiNet.FolderName = "KlinokUiNet"

local function folder(wait: boolean?)
	local existing = ReplicatedStorage:FindFirstChild(UiNet.FolderName)
	if existing then
		return existing
	end
	if RunService:IsServer() then
		local created = Instance.new("Folder")
		created.Name = UiNet.FolderName
		created.Parent = ReplicatedStorage
		return created
	end
	if wait then
		return ReplicatedStorage:WaitForChild(UiNet.FolderName, 3)
	end
	return nil
end

-- Сервер: создать (или найти) ремоут.
function UiNet.ensure(name: string, className: string?)
	local parent = folder()
	local remote = parent:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className or "RemoteFunction")
		remote.Name = name
		remote.Parent = parent
	end
	return remote
end

-- Клиент: ремоут или nil. Ждём конкретный ремоут до 10 с: сервер создаёт их
-- при старте систем, а окно игрок может открыть раньше (PLAN_DORABOTKI P1-3).
-- Раньше 3 с ждали один раз на ВСЕ ремоуты — не повезло с таймингом, и окно
-- получало nil навсегда, без объяснения. Теперь первое обращение к каждому
-- ремоуту ждёт и предупреждает, повторные возвращают nil без блокировки.
local waited = {} -- [name] — уже ждали этот ремоут
function UiNet.find(name: string)
	local parent = folder(true)
	if not parent then
		if not waited[name] then
			waited[name] = true
			warn("[UiNet] папка " .. UiNet.FolderName .. " не приехала за 3 с — сервер ещё не стартовал?")
		end
		return nil
	end
	local remote = parent:FindFirstChild(name)
	if remote then
		return remote
	end
	if waited[name] then
		return nil -- уже ждали и предупреждали: окно не тормозим повторно
	end
	waited[name] = true
	remote = parent:WaitForChild(name, 10)
	if not remote then
		warn("[UiNet] ремоут " .. name .. " не создан за 10 с — окно будет пустым. Проверь Output: не упала ли серверная система")
	end
	return remote
end

return UiNet
