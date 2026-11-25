--!nonstrict
-- FloorBoonState (сервер) — взятые «Дары Эха» и их влияние на статы.
-- Чистый модуль без зависимостей от боёвки: его читают CombatService (здоровье,
-- броня, скорость атаки и бега, урон оружия, уклонение), MeleeService (урон от
-- душ), ProgressionService (предел душ, лечение за убийство), EnemyService
-- (вампиризм). Выбор и остановку времени ведёт FloorBoonService.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FloorBoons = require(ReplicatedStorage:WaitForChild("Shared").Config.FloorBoons)

local FloorBoonState = {}

-- [player] = { floor = id, owned = { [cardId] = { total, count, best } }, list = { {id, rarity} } }
local data = {}

local function entry(player)
	local d = data[player]
	if not d then
		d = { floor = nil, owned = {}, list = {} }
		data[player] = d
	end
	return d
end

local function publish(player)
	local d = entry(player)
	local list = {}
	for _, item in ipairs(d.list) do
		table.insert(list, { item.id, item.rarity })
	end
	player:SetAttribute("FloorBoons", HttpService:JSONEncode(list))
	player:SetAttribute("SoulCapBonus", FloorBoonState.soulCapBonus(player))
end

function FloorBoonState.owned(player)
	return entry(player).owned
end

function FloorBoonState.total(player, cardId: string): number
	local d = data[player]
	local have = d and d.owned[cardId]
	return have and have.total or 0
end

function FloorBoonState.count(player, cardId: string): number
	local d = data[player]
	local have = d and d.owned[cardId]
	return have and have.count or 0
end

-- Добавить дар. Возвращает новое суммарное значение.
function FloorBoonState.add(player, cardId: string, rarity: number): number
	local card = FloorBoons.ById[cardId]
	if not card then
		return 0
	end
	local d = entry(player)
	local have = d.owned[cardId] or { total = 0, count = 0, best = 0, extra = 0 }
	d.owned[cardId] = have
	if card.kind == "mult" then
		have.total = math.max(have.total, 1) * card.values[rarity]
	else
		have.total += card.values[rarity]
	end
	if card.cap then
		have.total = math.min(have.total, card.cap)
	end
	have.count += 1
	have.best = math.max(have.best, rarity)
	if card.extra then
		have.extra += card.extra[rarity]
	end
	table.insert(d.list, { id = cardId, rarity = rarity })
	publish(player)
	return have.total
end

-- Сбросить все дары (новый этаж, выход в долину, новый забег).
function FloorBoonState.reset(player, floorId)
	data[player] = { floor = floorId, owned = {}, list = {} }
	if player.Parent then
		publish(player)
	end
end

function FloorBoonState.floorOf(player)
	local d = data[player]
	return d and d.floor
end

-- ===== Чтение для боёвки =====

-- CombatService.getStats: здоровье, броня, скорость атаки и бега, урон оружия.
function FloorBoonState.applyStats(player, stats)
	local d = data[player]
	if not d or next(d.owned) == nil then
		return stats
	end
	local o = d.owned
	if o.vitality then
		local before = stats.maxHealth
		stats.maxHealth = stats.maxHealth * (1 + o.vitality.total)
		stats.boonHealth = stats.maxHealth - before
	end
	if o.bulwark then
		stats.armor += o.bulwark.total
		stats.boonArmor = o.bulwark.total
	end
	if o.haste then
		stats.attackSpeed += o.haste.total
	end
	if o.swift then
		stats.walkSpeed = stats.walkSpeed * (1 + o.swift.total)
	end
	if o.might then
		stats.weaponDamage = stats.weaponDamage * (1 + o.might.total)
	end
	return stats
end

-- Множитель урона от душ («Голод душ»).
function FloorBoonState.soulDamageMult(player): number
	return 1 + FloorBoonState.total(player, "soul_hunger")
end

-- Надбавка к пределу душ («Прилив душ»).
function FloorBoonState.soulCapBonus(player): number
	local d = data[player]
	local have = d and d.owned.soul_surge
	return have and have.extra or 0
end

function FloorBoonState.evasion(player): number
	return FloorBoonState.total(player, "evasion")
end

function FloorBoonState.lifesteal(player): number
	return FloorBoonState.total(player, "leech")
end

function FloorBoonState.killHeal(player): number
	return FloorBoonState.total(player, "reaper")
end

Players.PlayerRemoving:Connect(function(player)
	data[player] = nil
end)

return FloorBoonState
