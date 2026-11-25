--!nonstrict
-- ProgressionService (сервер)
-- Опыт, уровни, стаки душ и награды за убийства — по приложению Е.
--
-- Опыт до следующего уровня = 100 × текущий уровень.
-- Стаки душ мобов временные: +1 за обычного врага, сбрасываются при смерти.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loot = require(Shared.Config.Loot)
local Progression = require(Shared.Config.Progression)
local DebugState = require(Shared.Net.DebugState)
local Net = require(Shared.Net.Net)

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)
local TalentMods = require(script.Parent.TalentMods)
local FloorBoonState = require(script.Parent.FloorBoonState)

local ProgressionService = {}

-- Убийство врага игроком: (player, typeId). Слушает QuestService хаба.
local killedEvent = Instance.new("BindableEvent")
ProgressionService.Killed = killedEvent.Event
-- leveled(player, level) — TalentService публикует очки древа.
ProgressionService.hooks = { leveled = nil }

local function publish(player)
	local profile = DataService.get(player)
	player:SetAttribute("Level", profile.level)
	player:SetAttribute("Xp", profile.xp)
	player:SetAttribute("XpToNext", Progression.xpToNext(profile.level))
	player:SetAttribute("SoulStacks", profile.soulStacks or 0)
	player:SetAttribute("SoulStacksMax", Progression.maxStacks(FloorBoonState.soulCapBonus(player)))
	player:SetAttribute("BossKills", profile.bossKills or 0)
	player:SetAttribute("NewWeapons", profile.newWeapons or 0)
	player:SetAttribute("SoulCount", #profile.souls)
	-- Блок душ в HUD (SoulHudController) показывает, откуда растёт урон: базу стаков
	-- клиент считает сам (Progression.stackBonuses), а древо и дар — отсюда, как в MeleeService.
	local okTalent, talentBonus = pcall(TalentMods.soulDamage, player, player:GetAttribute("SoulStacks") or 0)
	player:SetAttribute("SoulDmgTalent", okTalent and type(talentBonus) == "number" and talentBonus or 0)
	local okMult, soulMult = pcall(FloorBoonState.soulDamageMult, player)
	player:SetAttribute("SoulDmgMult", okMult and type(soulMult) == "number" and soulMult or 1)

	local bonuses = Progression.stackBonuses(profile.soulStacks or 0, FloorBoonState.soulCapBonus(player))
	DebugState.set("Progress", "Level", profile.level)
	DebugState.set("Progress", "Xp", profile.xp)
	DebugState.set("Progress", "Stacks", profile.soulStacks or 0)
	DebugState.set("Progress", "DamageBonus", bonuses.damage)
end

-- refill = true только при спавне и повышении уровня: обычное убийство не лечит.
function ProgressionService.applyLevel(player, refill: boolean?)
	local profile = DataService.get(player)
	CombatService.applyClass(player, profile.className, profile.level, refill)
	-- Скорость движения зависит от стаков душ.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local stats = CombatService.getStats(player)
		local bonuses = Progression.stackBonuses(profile.soulStacks or 0, FloorBoonState.soulCapBonus(player))
		humanoid.WalkSpeed = stats.walkSpeed * (1 + bonuses.moveSpeed)
	end
	publish(player)
end

function ProgressionService.addXp(player, amount: number)
	local profile = DataService.get(player)
	profile.xp += amount

	local leveled = false
	while profile.level < Progression.MaxLevel and profile.xp >= Progression.xpToNext(profile.level) do
		profile.xp -= Progression.xpToNext(profile.level)
		profile.level += 1
		leveled = true
		print(("[Progression] %s получил уровень %d"):format(player.Name, profile.level))
	end

	ProgressionService.applyLevel(player, leveled)
	if leveled then
		local notify = Net.get("Notify")
		if notify then
			notify:FireClient(player, { kind = "levelUp", text = ("Уровень %d"):format(profile.level) })
			-- Древо талантов: очко за каждый уровень (книга героя, клавиша T).
			notify:FireClient(player, { kind = "talent", text = "+1 очко древа талантов (T)" })
		end
		if ProgressionService.hooks.leveled then
			pcall(ProgressionService.hooks.leveled, player, profile.level)
		end
	end
	return profile.level
end

function ProgressionService.addStacks(player, count: number)
	local profile = DataService.get(player)
	profile.soulStacks = math.min((profile.soulStacks or 0) + count, Progression.maxStacks(FloorBoonState.soulCapBonus(player)))
	ProgressionService.applyLevel(player)
	return profile.soulStacks
end

function ProgressionService.resetStacks(player)
	local profile = DataService.get(player)
	profile.soulStacks = 0
	-- Новый забег: «Несгибаемый» и счётчики древа снова доступны.
	TalentMods.onRunReset(player)
	ProgressionService.applyLevel(player)
end

-- Награда за убийство: золото, опыт, стаки, шанс на материал.
function ProgressionService.rewardKill(player, stats)
	local profile = DataService.get(player)
	local rewards = stats.rewards or {}

	DataService.addGold(player, rewards.gold or 0)
	ProgressionService.addXp(player, rewards.xp or 0)
	ProgressionService.addStacks(player, rewards.stacks or 0)
	-- «Жатва» (дар этажа): убийство лечит долю здоровья.
	local killHeal = FloorBoonState.killHeal(player)
	if killHeal > 0 then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = math.min(humanoid.Health + humanoid.MaxHealth * killHeal, humanoid.MaxHealth)
		end
	end

	-- Материал — того этажа, где идёт бой (раньше везде падало «Ржавое железо»).
	-- rewards.iron — гарантированная доля мини-босса и босса (раньше не выдавалась).
	local material = Loot.materialOf(player:GetAttribute("FloorId") or 1)
	local rng = Random.new()
	local count = rewards.iron or 0
	if rng:NextNumber() < (rewards.ironChance or 0) then
		count += 1
	end
	if count > 0 then
		DataService.addMaterial(player, material, count)
	end
	profile.stats.enemiesKilled += 1
	publish(player)
	killedEvent:Fire(player, stats.typeId)
end

-- Душа босса: первая гарантированно обычная, дальше по весам.
function ProgressionService.rewardBossSoul(player)
	local profile = DataService.get(player)
	local soul = Loot.rollBossSoul(profile.bossKills or 0)

	table.insert(profile.souls, {
		id = soul.id,
		name = soul.name,
		rarity = soul.rarity,
		kind = soul.kind,
	})
	profile.bossKills = (profile.bossKills or 0) + 1

	player:SetAttribute("LastSoul", soul.name)
	DebugState.set("Progress", "LastSoul", soul.name)
	publish(player)

	local remote = game:GetService("ReplicatedStorage"):FindFirstChild("KlinokNet")
	if remote then
		local event = remote:FindFirstChild("SoulReceived")
		if event and event:IsA("RemoteEvent") then
			event:FireClient(player, { name = soul.name, rarity = soul.rarity })
		end
	end

	local notify = Net.get("Notify")
	if notify then
		notify:FireClient(player, { kind = "soul", text = ("Душа: %s"):format(soul.name), rarity = soul.rarity })
	end

	print(("[Progression] %s получил душу «%s»"):format(player.Name, soul.name))
	return soul
end

function ProgressionService.start()
	-- Уровень из профиля применяется после спавна персонажа: CombatService
	-- выставляет базовые статы, прогресс уточняет их по уровню (5 на этаже 1).
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.3)
			ProgressionService.applyLevel(player, true)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			task.spawn(function()
				task.wait(0.3)
				ProgressionService.applyLevel(player, true)
			end)
		end
	end

	print("[ProgressionService] запущен")
end

return ProgressionService
