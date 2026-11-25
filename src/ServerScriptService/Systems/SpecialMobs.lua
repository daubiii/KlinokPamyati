--!nonstrict
-- SpecialMobs (сервер) — P6: особые варианты врагов (решение владельца,
-- план «Золотая гончая и особые варианты мобов»).
--
-- В забеге изредка (шанс CHANCE) один из обычных врагов приходит «особым»:
-- золотое сияние (Highlight), ×2.5 здоровья, имя «★ Особый: …». Кем добит —
-- тому и добыча: золото (растёт с этажом), 2 материала этажа, счётчик
-- specialKilled (кормит цепочку «Охота» в Quests, category achv).
-- Боссы, мини-боссы, объекты и спавны отладки (без room.floorId) не
-- превращаются. Золотая гончая — отдельная модель, будет позже
-- (см. PLAN_DORABOTKI P6, шаги приготовления).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)
local EnemyService = require(script.Parent.EnemyService)
local StatsService = require(script.Parent.StatsService)
local DataService = require(script.Parent.DataService)

local SpecialMobs = {}

local CHANCE = 0.12 -- шанс особого варианта у обычного врага этажа
local HEALTH_MULT = 2.5
local GOLD_BASE = 60 -- базовое золото за особого (этаж 1: 85, этаж 5: 185)
local GOLD_PER_FLOOR = 25
local MATERIAL_COUNT = 2

local function notify(player, text: string)
	local remote = Net.get("Notify")
	if remote then
		remote:FireClient(player, { kind = "info", text = text })
	end
end

-- Особые бывают только у боевых врагов на этажах: не босс, не объект,
-- не отладочный спавн (у того нет room.floorId).
local function eligible(enemy): boolean
	local room = enemy.room
	if not room or type(room.floorId) ~= "number" then
		return false
	end
	local role = enemy.stats.role
	if role == "boss" or role == "miniboss" or role == "object" then
		return false
	end
	return enemy.alive == true
end

-- Сделать врага особым (используется хуком спавна и отладкой).
function SpecialMobs.makeSpecial(enemy)
	if enemy.special then
		return
	end
	enemy.special = true
	local floorId = (enemy.room and enemy.room.floorId) or 1

	local humanoid = enemy.model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		enemy.maxHealth = math.floor(enemy.maxHealth * HEALTH_MULT)
		enemy.health = enemy.maxHealth
		humanoid.MaxHealth = enemy.maxHealth
		humanoid.Health = enemy.maxHealth
	end
	-- Атрибуты переопубликовать: spawn уже выставил старые значения.
	enemy.model:SetAttribute("EnemyHealth", enemy.health)
	enemy.model:SetAttribute("EnemyMaxHealth", enemy.maxHealth)
	enemy.model:SetAttribute("EnemyName", "★ Особый: " .. tostring(enemy.stats.name))
	enemy.model:SetAttribute("Special", true)

	local highlight = Instance.new("Highlight")
	highlight.Name = "SpecialGlow"
	highlight.FillColor = Color3.fromRGB(255, 196, 60)
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = Color3.fromRGB(255, 224, 130)
	highlight.OutlineTransparency = 0.1
	highlight.Parent = enemy.model

	-- Добыча тому, кто добил (поверх прежнего onDeath этажа).
	local previousDeath = enemy.onDeath
	enemy.onDeath = function(dead, attacker)
		if previousDeath then
			pcall(previousDeath, dead, attacker)
		end
		if typeof(attacker) ~= "Instance" or not attacker:IsA("Player") or not attacker.Parent then
			return
		end
		local gold = GOLD_BASE + GOLD_PER_FLOOR * floorId
		DataService.addGold(attacker, gold)
		local materialName = "материал"
		local okLoot, Loot = pcall(function()
			return require(game:GetService("ReplicatedStorage").Shared.Config.Loot)
		end)
		if okLoot and Loot and Loot.chestInfo then
			local info = Loot.chestInfo(floorId)
			if info and info.material then
				DataService.addMaterial(attacker, info.material, MATERIAL_COUNT)
				materialName = info.materialName or info.material
			end
		end
		StatsService.addCount(attacker, "specialKilled", 1)
		pcall(function()
			DataService.requestSave(attacker, 10)
		end)
		notify(attacker, ("★ Особая добыча: +%d золота, +%d × %s"):format(gold, MATERIAL_COUNT, materialName))
	end
end

function SpecialMobs.start()
	table.insert(EnemyService.spawnHooks, function(enemy)
		if not eligible(enemy) then
			return
		end
		if math.random() < CHANCE then
			SpecialMobs.makeSpecial(enemy)
		end
	end)
	print("[SpecialMobs] охота готова: шанс " .. math.floor(CHANCE * 100) .. "%, HP ×" .. HEALTH_MULT .. ", счётчик specialKilled")
end

return SpecialMobs
