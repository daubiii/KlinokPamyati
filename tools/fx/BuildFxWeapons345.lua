--!nonstrict
-- BuildFxWeapons345 (Studio, команда в Command Bar или Script → Run)
-- Шаблоны эффектов оружия этажей 3–5 → ReplicatedStorage.FX.Hunt / Forge / Chron / Weapon.
-- Сервер и так достраивает недостающие шаблоны при старте; этот скрипт нужен, чтобы
-- увидеть и править их в Studio (Explorer → ReplicatedStorage.FX), а затем сохранить место.
-- REBUILD = true — пересоздать всё по Shared/Fx/FxWeapons345 (ваши правки в месте пропадут).
-- После загрузки своих PNG (tools/fx/textures_345) и вписывания id в FxWeapons345.NEW — запустить с REBUILD = true.

local REBUILD = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local module = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fx"):WaitForChild("FxBuilder345")
-- Свежая копия модулей (Command Bar кэширует require).
local fxFolder = module.Parent
local specCopy = fxFolder.FxWeapons345:Clone()
local builderCopy = module:Clone()
local temp = Instance.new("Folder")
temp.Name = "FxBuild345Temp"
specCopy.Parent = temp
builderCopy.Parent = temp
temp.Parent = game:GetService("ServerStorage")
local ok, made, total = pcall(function()
	return require(builderCopy).build({ rebuild = REBUILD })
end)
temp:Destroy()
if ok then
	print(string.format("[BuildFxWeapons345] готово: создано %d из %d шаблонов (REBUILD = %s)", made, total, tostring(REBUILD)))
else
	warn("[BuildFxWeapons345] ошибка: " .. tostring(made))
end
