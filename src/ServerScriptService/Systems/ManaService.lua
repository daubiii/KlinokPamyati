--!nonstrict
-- ManaService (сервер)
-- Мана мага: максимум и восстановление из класса, брони и оружия
-- (Config/Mana), трата способностями. Обычные снаряды посоха бесплатны.
--
-- Атрибуты игрока (их читает HUD): Mana, MaxMana, ManaRegen,
-- ManaDeniedAt (время отказа — HUD мигает полосой «не хватает маны»).
--
-- Вызовы:
--   ManaService.recalc(player, refill?) — пересчитать максимум и реген
--       (смена класса, уровня, брони, оружия; зовут ArmorService и applyClass);
--   ManaService.spend(player, amount) -> bool — потратить (false — не хватает);
--   ManaService.gain(player, amount) — вернуть (удачный барьер, комплект);
--   ManaService.refill(player) — полная (спавн, костёр, хаб).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Classes = require(Shared.Config.Classes)
local Mana = require(Shared.Config.Mana)
local Weapons = require(Shared.Config.Weapons)
local DebugState = require(Shared.Net.DebugState)

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)
local TalentMods = require(script.Parent.TalentMods)

local ManaService = {}

local states = {} -- [player] = { mana, max, regen, pauseUntil, calmAt, sent }

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function stateOf(player)
	local state = states[player]
	if not state then
		state = { mana = 0, max = 0, regen = 0, pauseUntil = 0, calmAt = 0, sent = -1 }
		states[player] = state
	end
	return state
end

function ManaService.isMage(player): boolean
	local profile = DataService.get(player)
	return Mana.Classes[profile.className or "warrior"] == true
end

-- Мана и реген оружия в руке (посохи): Weapons.Items[id].mana / manaRegen.
local function weaponMana(profile)
	local weapon = profile.equippedWeapon
	local item = weapon and Weapons.Items[weapon.id or ""]
	if not item then
		return 0, 0
	end
	return item.mana or 0, item.manaRegen or 0
end

-- Максимум и реген прямо сейчас: класс по уровню + броня + оружие.
function ManaService.compute(player)
	local profile = DataService.get(player)
	local className = profile.className or "warrior"
	if not Mana.Classes[className] then
		return 0, 0, {}
	end
	local stats = Classes.statsAtLevel(className, profile.level) or {}
	local parts = { classMana = stats.maxMana or 0, classRegen = stats.manaRegen or 0, gearMana = 0, gearRegen = 0 }
	if CombatService.hooks.gearStats then
		local ok, gear = pcall(CombatService.hooks.gearStats, player)
		if ok and type(gear) == "table" then
			parts.gearMana = gear.mana or 0
			parts.gearRegen = gear.manaRegen or 0
		end
	end
	parts.weaponMana, parts.weaponRegen = weaponMana(profile)
	-- Древо мага (путь «Источник»): «Запас чернил», «Глубокий колодец», «Ровное дыхание», малые узлы.
	local mods = TalentMods.get(player)
	parts.talentMana = mods.maxMana or 0
	parts.talentRegen = mods.manaRegen or 0
	local max = (parts.classMana + parts.gearMana + parts.weaponMana + parts.talentMana) * (1 + (mods.maxManaPct or 0))
	local regen = parts.classRegen + parts.gearRegen + parts.weaponRegen + parts.talentRegen
	return math.max(math.floor(max + 0.5), 0), math.max(regen, 0), parts
end

local function publish(player, force: boolean?)
	local state = stateOf(player)
	local shown = math.floor(state.mana * 10 + 0.5) / 10
	if force or shown ~= state.sent then
		state.sent = shown
		player:SetAttribute("Mana", shown)
	end
	if force then
		player:SetAttribute("MaxMana", state.max)
		player:SetAttribute("ManaRegen", math.floor(state.regen * 100 + 0.5) / 100)
		DebugState.set("Mana", "Max", state.max)
		DebugState.set("Mana", "Regen", state.regen)
	end
end

-- Пересчитать максимум и реген. Без refill мана сохраняет долю от максимума.
function ManaService.recalc(player, refill: boolean?)
	local state = stateOf(player)
	local max, regen = ManaService.compute(player)
	local ratio = state.max > 0 and math.clamp(state.mana / state.max, 0, 1) or 1
	state.max = max
	state.regen = regen
	-- «Второе дыхание»: ниже 25% маны реген × (1 + lowManaRegen).
	state.lowRegen = TalentMods.get(player).lowManaRegen or 0
	state.mana = (refill or state.sent < 0) and max or math.min(max * ratio, max)
	publish(player, true)
end

function ManaService.refill(player)
	local state = stateOf(player)
	state.mana = state.max
	publish(player, true)
end

function ManaService.get(player): (number, number)
	local state = stateOf(player)
	return state.mana, state.max
end

function ManaService.canSpend(player, amount: number): boolean
	local state = stateOf(player)
	return state.max > 0 and state.mana + 1e-6 >= (amount or 0)
end

-- Потратить ману. Не хватает — false и сигнал HUD (ManaDeniedAt).
function ManaService.spend(player, amount: number): boolean
	local state = stateOf(player)
	amount = math.max(amount or 0, 0)
	if not ManaService.canSpend(player, amount) then
		player:SetAttribute("ManaDeniedAt", now())
		return false
	end
	state.mana -= amount
	state.pauseUntil = now() + Mana.RegenDelay
	state.calmAt = now() + Mana.RegenCalm
	publish(player)
	return true
end

function ManaService.gain(player, amount: number)
	local state = stateOf(player)
	if state.max <= 0 then
		return
	end
	state.mana = math.clamp(state.mana + (amount or 0), 0, state.max)
	publish(player)
end

-- «Второе дыхание» (древо мага): порог «мало маны», доля максимума.
ManaService.LowShare = 0.25

-- Масштаб способностей мага: +1% за 10 макс. маны.
function ManaService.abilityScale(player): number
	return Mana.abilityScale(stateOf(player).max)
end

local function step(dt: number)
	local t = now()
	for _, player in ipairs(Players:GetPlayers()) do
		local state = states[player]
		if state and state.max > 0 then
			if Mana.FullInHub and player:GetAttribute("Zone") ~= "Floor" then
				state.mana = state.max
			elseif t >= state.pauseUntil and state.mana < state.max then
				local rate = state.regen * (t >= state.calmAt and Mana.CalmMultiplier or 1)
				if (state.lowRegen or 0) > 0 and state.mana < state.max * ManaService.LowShare then
					rate *= 1 + state.lowRegen
				end
				state.mana = math.min(state.mana + rate * dt, state.max)
			end
			publish(player)
		end
	end
end

local function hookPlayer(player)
	stateOf(player)
	-- Урон по герою сбрасывает «спокойный» реген.
	player:GetAttributeChangedSignal("DamageTaken"):Connect(function()
		stateOf(player).calmAt = now() + Mana.RegenCalm
	end)
	-- Бонус комплекта «Забвения»: рывок возвращает ману.
	player:GetAttributeChangedSignal("LastDodgeAt"):Connect(function()
		local ok, ArmorService = pcall(require, script.Parent.ArmorService)
		local bonus = ok and ArmorService.setBonus and ArmorService.setBonus(player)
		if bonus and bonus.kind == "manaOnDodge" then
			ManaService.gain(player, bonus.amount or 0)
		end
	end)
	player.CharacterAdded:Connect(function()
		task.defer(ManaService.recalc, player, true)
	end)
	task.defer(ManaService.recalc, player, true)
end

function ManaService.start()
	-- Класс, уровень, спавн: CombatService.applyClass зовёт хук.
	CombatService.hooks.classApplied = function(player, refill)
		ManaService.recalc(player, refill)
	end
	-- Костёр и вход на этаж пополняют лечение — и ману.
	local refillHeals = CombatService.refillHeals
	CombatService.refillHeals = function(player, ...)
		refillHeals(player, ...)
		ManaService.refill(player)
	end

	Players.PlayerAdded:Connect(hookPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		hookPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= Mana.Tick then
			step(acc)
			acc = 0
		end
	end)
	print("[ManaService] мана мага")
end

return ManaService
