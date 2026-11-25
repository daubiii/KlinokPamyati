--!nonstrict
-- PlayerSettings (сервер)
-- Настройки игрока: громкость музыки/звуков, множитель чувствительности
-- камеры. Хранятся в профиле (profile.settings), клиент применяет сам —
-- SoundGroups и камера живут на клиенте.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local RemoteGuard = require(script.Parent.RemoteGuard)
local DataService = require(script.Parent.DataService)

local PlayerSettings = {}

local DEFAULTS = { music = 0.7, sfx = 1, sens = 1 }

-- Нормализовать таблицу настроек: только известные ключи, числа в границах.
local function sanitize(input): { music: number, sfx: number, sens: number }
	local source = type(input) == "table" and input or {}
	local function clampNum(value, min, max, fallback): number
		if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return fallback
		end
		return math.clamp(value, min, max)
	end
	return {
		music = clampNum(source.music, 0, 1, DEFAULTS.music),
		sfx = clampNum(source.sfx, 0, 1, DEFAULTS.sfx),
		sens = clampNum(source.sens, 0.3, 2.5, DEFAULTS.sens),
	}
end

function PlayerSettings.get(player)
	local profile = DataService.get(player)
	local settings = sanitize(profile and profile.settings)
	return settings
end

function PlayerSettings.apply(player, input)
	local profile = DataService.get(player)
	if not profile or DataService.status(player) ~= "ready" then
		return { ok = false, err = "Профиль не готов" }
	end
	profile.settings = sanitize(input)
	pcall(function()
		DataService.requestSave(player, 10)
	end)
	return { ok = true, settings = profile.settings }
end

function PlayerSettings.start()
	local remote = Net.get("RequestSettings")
	remote.OnServerInvoke = RemoteGuard.wrap("RequestSettings", function(player, payload)
		if typeof(payload) ~= "table" or payload.action ~= "set" then
			return { ok = true, settings = PlayerSettings.get(player) }
		end
		return PlayerSettings.apply(player, payload.settings)
	end)
	print("[PlayerSettings] настройки готовы (music/sfx/sens в профиле)")
end

return PlayerSettings
