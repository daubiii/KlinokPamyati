--!nonstrict
-- TalentService (сервер)
-- Древо талантов v2 (приложение В): очки, изучение, сброс, события узлов.
--
-- Очки не хранятся: всего = уровень − 1 (Talents.pointsAt, до 59 на 60-м),
-- свободно = всего − потрачено. Изученное — profile.talents[класс].nodes; игрок
-- видит только древо своего класса. Узлы старой версии древа (v1) TalentMods.entry
-- снимает бесплатно — очки возвращаются (см. docs/README_TALENTS.md).
--
-- Ремоуты (KlinokUiNet, RemoteFunction):
--   TalentsGet()        → state
--   TalentsLearn(id)    → { ok, reason?, state }
--   TalentsReset()      → { ok, reason?, cost?, state }
-- state = { classId, className, level, points, spent, free, byBranch, learned,
--           resets, resetCost, canReset, hubOnly, gold }
--
-- Атрибуты игрока (HUD, книга героя): TalentPoints (всего), TalentFree (свободно).
--
-- Здесь же события, которым нужны враги и мана: «Эхо щита» (парирование),
-- «Боевой раж» и «Конспект» (убийство), обновление скорости бега от бафов.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteGuard = require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("RemoteGuard"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Talents = require(Shared.Config.Talents)
local Classes = require(Shared.Config.Classes)
local Progression = require(Shared.Config.Progression)
local UiNet = require(Shared.Net.UiNet)
local DebugState = require(Shared.Net.DebugState)

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)
local ProgressionService = require(script.Parent.ProgressionService)
local EnemyService = require(script.Parent.EnemyService)
local ManaService = require(script.Parent.ManaService)
local TalentMods = require(script.Parent.TalentMods)
local FloorBoonState = require(script.Parent.FloorBoonState)

local TalentService = {}

-- Отладка Studio: лишние очки сверх уровня (не сохраняются).
TalentService.bonus = {}

local lastCall = {}
local THROTTLE = 0.12

local function guard(player): boolean
	local t = os.clock()
	if lastCall[player] and t - lastCall[player] < THROTTLE then
		return false
	end
	lastCall[player] = t
	return true
end

local function classOf(profile): string
	local id = profile.className or "warrior"
	if not Talents.tree(id) then
		return "warrior"
	end
	return id
end

-- Сброс разрешён вне этажа (в долине; в Studio без хаба Zone пустой).
local function inHub(player): boolean
	return player:GetAttribute("Zone") ~= "Floor"
end

function TalentService.state(player)
	local profile = DataService.get(player)
	local classId = classOf(profile)
	local entry = TalentMods.entry(profile, classId)
	local spent, byBranch = Talents.spent(classId, entry.nodes)
	local points = Talents.pointsAt(profile.level) + (TalentService.bonus[player] or 0)
	local learned = {}
	for id in pairs(entry.nodes) do
		if Talents.Nodes[id] and Talents.Nodes[id].classId == classId then
			learned[id] = true
		end
	end
	local classData = Classes.get(classId)
	return {
		classId = classId,
		className = classData and classData.name or classId,
		level = profile.level,
		points = points,
		spent = spent,
		free = points - spent,
		byBranch = byBranch,
		learned = learned,
		resets = entry.resets,
		resetCost = Talents.resetCost(spent, entry.resets),
		canReset = inHub(player),
		hubOnly = Talents.Reset.hubOnly,
		gold = profile.gold or 0,
	}
end

function TalentService.publish(player)
	local ok, state = pcall(TalentService.state, player)
	if not ok then
		return
	end
	player:SetAttribute("TalentPoints", state.points)
	player:SetAttribute("TalentFree", state.free)
	player:SetAttribute("TalentSpent", state.spent)
	DebugState.set("Talents", "Free", state.free)
	DebugState.set("Talents", "Spent", state.spent)
end

-- Изменилось древо: кэш эффектов, здоровье/броня, мана, скорость.
local function applyChanges(player)
	TalentMods.invalidate(player)
	ProgressionService.applyLevel(player)
	pcall(ManaService.recalc, player)
	TalentService.publish(player)
end

function TalentService.learn(player, nodeId: string, force: boolean?)
	local profile = DataService.get(player)
	local classId = classOf(profile)
	local entry = TalentMods.entry(profile, classId)
	if not force then
		local ok, reason = Talents.canLearn(classId, entry.nodes, nodeId, profile.level, TalentService.bonus[player])
		if not ok then
			return { ok = false, reason = reason, text = Talents.Reasons[reason], state = TalentService.state(player) }
		end
	elseif not Talents.Nodes[nodeId] or Talents.Nodes[nodeId].classId ~= classId then
		return { ok = false, reason = "unknown", text = Talents.Reasons.unknown, state = TalentService.state(player) }
	end
	entry.nodes[nodeId] = true
	applyChanges(player)
	local node = Talents.Nodes[nodeId]
	DebugState.set("Talents", "Last", nodeId)
	print(("[Talents] %s изучил «%s» (%s)"):format(player.Name, node.name, classId))
	return { ok = true, id = nodeId, state = TalentService.state(player) }
end

function TalentService.reset(player, free: boolean?)
	local profile = DataService.get(player)
	local classId = classOf(profile)
	local entry = TalentMods.entry(profile, classId)
	local spent = Talents.spent(classId, entry.nodes)
	if spent <= 0 then
		return { ok = false, reason = "empty", text = Talents.Reasons.empty, state = TalentService.state(player) }
	end
	if not free and Talents.Reset.hubOnly and not inHub(player) then
		return { ok = false, reason = "hub", text = Talents.Reasons.hub, state = TalentService.state(player) }
	end
	local cost = free and 0 or Talents.resetCost(spent, entry.resets)
	if cost > 0 and not DataService.spendGold(player, cost) then
		return { ok = false, reason = "gold", text = Talents.Reasons.gold, cost = cost, state = TalentService.state(player) }
	end
	entry.nodes = {}
	if not free then
		entry.resets += 1
	end
	applyChanges(player)
	print(("[Talents] %s сбросил древо (%s), цена %d"):format(player.Name, classId, cost))
	return { ok = true, cost = cost, refunded = spent, state = TalentService.state(player) }
end

-- ===== события узлов =====

-- Скорость бега после бафа «Опоры» / «Лёгкого шага» (как ProgressionService.applyLevel,
-- без пересчёта здоровья). Замедление/корни этажей подхватят новую базу сами.
local function refreshSpeed(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or humanoid.WalkSpeed <= 0 then
		return
	end
	local profile = DataService.get(player)
	local stats = CombatService.getStats(player)
	local bonuses = Progression.stackBonuses(profile.soulStacks or 0, FloorBoonState.soulCapBonus(player))
	humanoid.WalkSpeed = stats.walkSpeed * (1 + bonuses.moveSpeed)
end

-- «Эхо щита»: удачное парирование оглушает врагов рядом (кроме боссов).
local function shieldEcho(player, _attack, mods)
	local radius = mods.parryEchoRadius
	if not radius or radius <= 0 then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local center = root.Position
	local count = 0
	for _, enemy in ipairs(EnemyService.all()) do
		if enemy.alive and not enemy.stats.isBoss and enemy.stats.role ~= "object" then
			local offset = enemy.position - center
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if flat <= radius + (enemy.stats.radius or 1) then
				EnemyService.stun(enemy, mods.parryEchoStun or 1)
				count += 1
			end
		end
	end
	if count > 0 then
		EnemyService.fireEvent({ kind = "talentEcho", position = center, radius = radius, count = count })
		DebugState.bump("Talents", "EchoStuns", count)
	end
end

-- Убийство: «Боевой раж» (скорость атаки) и «Конспект» (мана).
local function onKilled(player, _typeId)
	if not TalentMods.isPlayer(player) then
		return
	end
	local mods = TalentMods.get(player)
	if mods.killHaste then
		TalentMods.addHaste(player, mods.killHaste, mods.killHasteTime or 5)
	end
	if mods.killMana then
		ManaService.gain(player, mods.killMana)
	end
end

function TalentService.start()
	TalentMods.hooks.refreshSpeed = refreshSpeed
	table.insert(TalentMods.parryListeners, shieldEcho)

	UiNet.ensure("TalentsGet").OnServerInvoke = function(player)
		if not RemoteGuard.allow(player, "TalentsGet") then return RemoteGuard.BUSY end
		return TalentService.state(player)
	end
	UiNet.ensure("TalentsLearn").OnServerInvoke = function(player, nodeId)
		if not RemoteGuard.allow(player, "TalentsLearn", nodeId) then return RemoteGuard.BUSY end
		if typeof(nodeId) ~= "string" or #nodeId > 40 then
			return { ok = false, reason = "unknown", text = Talents.Reasons.unknown }
		end
		if not guard(player) then
			return { ok = false, reason = "busy", text = Talents.Reasons.busy, state = TalentService.state(player) }
		end
		return TalentService.learn(player, nodeId)
	end
	UiNet.ensure("TalentsReset").OnServerInvoke = function(player)
		if not RemoteGuard.allow(player, "TalentsReset") then return RemoteGuard.BUSY end
		if not guard(player) then
			return { ok = false, reason = "busy", text = Talents.Reasons.busy, state = TalentService.state(player) }
		end
		return TalentService.reset(player)
	end

	ProgressionService.Killed:Connect(onKilled)

	-- Новый уровень — новое очко: обновить атрибуты.
	local leveled = ProgressionService.hooks.leveled
	ProgressionService.hooks.leveled = function(player, level)
		if leveled then
			leveled(player, level)
		end
		TalentService.publish(player)
	end

	-- Смена класса (у каждого класса своё древо) и спавн: сбросить кэш эффектов.
	local classApplied = CombatService.hooks.classApplied
	CombatService.hooks.classApplied = function(player, refill)
		TalentMods.invalidate(player)
		if classApplied then
			classApplied(player, refill)
		end
		TalentService.publish(player)
	end

	local function onPlayer(player)
		task.spawn(function()
			local waited = 0
			while not player:GetAttribute("ProfileVersion") and waited < 60 and player.Parent do
				waited += task.wait(0.1)
			end
			if player.Parent then
				TalentService.publish(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
		TalentService.bonus[player] = nil
	end)

	print("[TalentService] запущен")
end

return TalentService
