--!nonstrict
-- MageService (сервер)
-- Класс мага в бою: удары посохом — снаряды (MageBolts), дебафы на врагах, вампиризм
-- посохов, пассивки легендарок и секреток, «Барьер» (парирование за ману) и «Покров»
-- (невидимость, клавиша 3). Числа — Config.LootMage, мана — ManaService.
--
-- Подключение — хуками, без правки логики воина:
--   MeleeService.rangedAttack     — удар посохом вместо дуги меча;
--   CombatService.hooks.parryGate — барьер стоит маны;
--   CombatService.hooks.parrySuccess (цепочкой) — удачный барьер: мана и отброс;
--   AbilityService.hooks.slot3    — «Покров»;
--   CombatService.hooks.classApplied (цепочкой) — атрибут ClassAbility для HUD.
-- Враги не видят игрока с атрибутом VeiledUntil > сейчас (EnemyService.nearestPlayer).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loot = require(Shared.Config.Loot)
local LootMage = require(Shared.Config.LootMage)
local Weapons = require(Shared.Config.Weapons)
local FloorGeo = require(Shared.Floor.FloorGeo)
local DebugState = require(Shared.Net.DebugState)

local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)
local ManaService = require(script.Parent.ManaService)
local MageBolts = require(script.Parent.MageBolts)
local TalentMods = require(script.Parent.TalentMods)

local MageService = {}

local FEET = 3.0
local DEFAULT_ITEM = LootMage.Items[LootMage.StarterWeapon]

local debuffs = {} -- [enemy] = { [kind] = { untilT, base, owner, at, nextTick } }
local zones = {} -- активные зоны заклинаний и пассивок
local passiveState = {} -- [player] = { dew, heat, heatAt, shots, footnotes, resonance = {[enemy]=...} }
local healFxAt = {} -- [player] = время последней вспышки лечения
local loop = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rootOf(player)
	if not player or not player.Parent then
		return nil, nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return root, humanoid
end
MageService.rootOf = rootOf

function MageService.fx(payload)
	MageBolts.fx(payload)
end
local fx = MageService.fx

function MageService.isMage(player): boolean
	local profile = DataService.get(player)
	return profile ~= nil and profile.className == LootMage.Class
end

local function stateOf(player)
	local state = passiveState[player]
	if not state then
		state = { dew = 0, heat = 0, heatAt = 0, shots = 0, hits = 0, resonance = {} }
		passiveState[player] = state
	end
	return state
end

local function itemOf(weapon)
	local item = weapon and Weapons.Items[weapon.id or ""]
	if item and item.bolt then
		return item
	end
	return DEFAULT_ITEM
end
MageService.itemOf = itemOf

-- ===== Поиск врагов =====

local function sameLevel(enemy, feetY: number): boolean
	return math.abs(enemy.position.Y - feetY) <= math.max(4.5, enemy.stats.height * 0.7)
end

function MageService.enemiesInRadius(center: Vector3, radius: number, exclude)
	local list = {}
	for _, enemy in ipairs(EnemyService.all()) do
		if enemy.alive and not (exclude and exclude[enemy]) and sameLevel(enemy, center.Y) then
			if flat(enemy.position - center).Magnitude - enemy.stats.radius <= radius then
				table.insert(list, enemy)
			end
		end
	end
	return list
end

-- Враги в секторе: центр на уровне ног, полуугол halfAngle (градусы).
function MageService.enemiesInCone(origin: Vector3, direction: Vector3, radius: number, halfAngle: number)
	local list = {}
	local half = math.rad(halfAngle)
	for _, enemy in ipairs(MageService.enemiesInRadius(origin, radius)) do
		local rel = flat(enemy.position - origin)
		if rel.Magnitude < 0.6 then
			table.insert(list, enemy)
		else
			local angle = math.acos(math.clamp(rel.Unit:Dot(direction), -1, 1))
			if angle - math.atan2(enemy.stats.radius, rel.Magnitude) <= half then
				table.insert(list, enemy)
			end
		end
	end
	return list
end

-- Враги на отрезке (луч, строка, разлом): полуширина halfWidth.
function MageService.enemiesOnSegment(origin: Vector3, direction: Vector3, length: number, halfWidth: number)
	local list = {}
	for _, enemy in ipairs(EnemyService.all()) do
		if enemy.alive and sameLevel(enemy, origin.Y) then
			local rel = flat(enemy.position - origin)
			local along = rel:Dot(direction)
			local side = (rel - direction * along).Magnitude
			local r = enemy.stats.radius
			if along > -r and along < length + r and side <= halfWidth + r then
				table.insert(list, enemy)
			end
		end
	end
	return list
end

-- Ближайшие враги к точке (для цепей и дуг), не больше max.
function MageService.nearestEnemies(position: Vector3, radius: number, max: number, exclude)
	local list = MageService.enemiesInRadius(position, radius, exclude)
	table.sort(list, function(a, b)
		return flat(a.position - position).Magnitude < flat(b.position - position).Magnitude
	end)
	while #list > max do
		table.remove(list)
	end
	return list
end

-- Лучшая цель для автоприцела: ближе к линии взгляда, на виду (без стены).
function MageService.bestTarget(origin: Vector3, forward: Vector3, range: number, halfAngle: number, feetY: number?)
	local best, bestScore = nil, math.huge
	local feet = feetY or (origin.Y - LootMage.BoltHeight)
	for _, enemy in ipairs(EnemyService.all()) do
		if enemy.alive and sameLevel(enemy, feet) then
			local rel = flat(enemy.position - origin)
			local distance = rel.Magnitude
			if distance <= range + enemy.stats.radius and distance > 0.3 then
				local angle = math.deg(math.acos(math.clamp(rel.Unit:Dot(forward), -1, 1)))
				local slack = math.deg(math.atan2(enemy.stats.radius, distance))
				if angle - slack <= halfAngle then
					local eye = Vector3.new(enemy.position.X, origin.Y, enemy.position.Z)
					if not FloorGeo.blocked(origin, eye) then
						local score = math.max(angle - slack, 0) / halfAngle + distance / range * 0.35
						if score < bestScore then
							best, bestScore = enemy, score
						end
					end
				end
			end
		end
	end
	return best
end

-- Высота пола под точкой (для навесных снарядов и кругов).
function MageService.groundAt(position: Vector3): Vector3
	local y = FloorGeo.groundAt(position.X, position.Z, position.Y + 1)
	if y then
		return Vector3.new(position.X, y, position.Z)
	end
	return position
end

-- ===== Урон и лечение =====

function MageService.heal(player, amount: number)
	local _, humanoid = rootOf(player)
	if not humanoid or amount <= 0 then
		return 0
	end
	local before = humanoid.Health
	humanoid.Health = math.min(humanoid.Health + amount, humanoid.MaxHealth)
	local healed = humanoid.Health - before
	if healed > 0.5 and (now() - (healFxAt[player] or 0)) > 0.45 then
		healFxAt[player] = now()
		fx({ kind = "heal", caster = player, amount = healed })
	end
	return healed
end

local onEnemyDeath -- ниже

-- Урон мага по врагу. info: { crit, counter, ability, leech, noLeech }.
function MageService.hit(player, enemy, amount: number, info)
	if not enemy or not enemy.alive or amount <= 0 then
		return false, 0
	end
	local taken, status = EnemyService.applyDamage(enemy, amount, player, {
		crit = info and info.crit == true or false,
		counter = info and info.counter == true or false,
		ability = info and info.ability or "staff",
	})
	local applied = status == "applied"
	if applied and info and info.leech and info.leech > 0 and not info.noLeech then
		MageService.heal(player, taken * info.leech)
	end
	if applied and not enemy.alive then
		onEnemyDeath(enemy, player)
	end
	return applied, taken
end

-- ===== Дебафы =====

local function countDebuffs(list): number
	local n = 0
	for _ in pairs(list) do
		n += 1
	end
	return n
end

local function clearDebuffEffect(enemy, kind: string, entry)
	if kind == "slow" and enemy.slow and math.abs(enemy.slow.untilT - entry.untilT) < 0.05 then
		enemy.slow = nil
		enemy.model:SetAttribute("EnemySlowedUntil", 0)
	elseif kind == "sunder" and enemy.armorBreak and math.abs(enemy.armorBreak.untilT - entry.untilT) < 0.05 then
		enemy.armorBreak = nil
		enemy.model:SetAttribute("EnemyArmorBreakUntil", 0)
	end
end

local function publishDebuffs(enemy, list)
	local names = {}
	for kind in pairs(list) do
		table.insert(names, kind)
	end
	table.sort(names)
	if enemy.model then
		enemy.model:SetAttribute("MageDebuffs", table.concat(names, ","))
	end
end

-- Наложить дебаф мага. base — урон удара посоха (горение и яд бьют его % в секунду).
function MageService.applyDebuff(player, enemy, kind: string, base: number)
	local def = LootMage.Debuffs[kind]
	if not def or not enemy or not enemy.alive or enemy.stats.role == "object" then
		return false
	end
	local t = now()
	local list = debuffs[enemy]
	if not list then
		list = {}
		debuffs[enemy] = list
	end
	if not list[kind] and countDebuffs(list) >= LootMage.MaxDebuffs then
		-- Самый старый дебаф уступает место новому.
		local oldestKind, oldest = nil, nil
		for otherKind, entry in pairs(list) do
			if not oldest or entry.at < oldest.at then
				oldestKind, oldest = otherKind, entry
			end
		end
		if oldestKind then
			clearDebuffEffect(enemy, oldestKind, oldest)
			list[oldestKind] = nil
			fx({ kind = "debuff", model = enemy.model, debuff = oldestKind, untilT = 0 })
		end
	end
	local entry = list[kind]
	if entry then
		entry.untilT = t + def.duration
		entry.base = math.max(entry.base, base or 0)
		entry.owner = player
	else
		entry = { untilT = t + def.duration, base = base or 0, owner = player, at = t, nextTick = t + LootMage.DebuffTick }
		list[kind] = entry
	end
	if kind == "slow" then
		EnemyService.slow(enemy, def.amount, def.duration)
		if enemy.slow then
			entry.untilT = enemy.slow.untilT
		end
	elseif kind == "sunder" then
		EnemyService.breakArmor(enemy, def.armor, def.duration)
	end
	publishDebuffs(enemy, list)
	fx({ kind = "debuff", model = enemy.model, debuff = kind, untilT = entry.untilT })
	DebugState.bump("Mage", "Debuff_" .. kind)
	return true
end

function MageService.debuffsOf(enemy)
	return debuffs[enemy] or {}
end

local function tickDebuffs(t: number)
	for enemy, list in pairs(debuffs) do
		if not enemy.alive then
			debuffs[enemy] = nil
		else
			local changed = false
			for kind, entry in pairs(list) do
				local def = LootMage.Debuffs[kind]
				if t >= entry.untilT then
					list[kind] = nil
					changed = true
				elseif def.dps and t >= entry.nextTick then
					entry.nextTick += LootMage.DebuffTick
					local amount = entry.base * def.dps * LootMage.DebuffTick
					MageService.hit(entry.owner, enemy, amount, { ability = kind, noLeech = true })
					if not enemy.alive then
						break
					end
				end
			end
			if changed and enemy.alive then
				publishDebuffs(enemy, list)
			end
			if next(list) == nil then
				debuffs[enemy] = nil
			end
		end
	end
end

-- ===== Зоны (круги, столбы, лава, стена огня, клякса) =====
-- spec: owner, center (уровень ног), radius | segment = { dir, length, halfWidth },
--       duration, tick, onTick(enemies, zone), onEnd(zone).
function MageService.zone(spec)
	local t = now()
	local zone = {
		owner = spec.owner,
		center = spec.center,
		radius = spec.radius or 4,
		segment = spec.segment,
		untilT = t + (spec.delay or 0) + (spec.duration or 3),
		startT = t + (spec.delay or 0),
		tick = spec.tick or 0.5,
		nextTick = t + (spec.delay or 0) + (spec.firstTick or spec.tick or 0.5),
		onTick = spec.onTick,
		onEnd = spec.onEnd,
	}
	table.insert(zones, zone)
	return zone
end

local function zoneEnemies(zone)
	if zone.segment then
		return MageService.enemiesOnSegment(zone.center, zone.segment.dir, zone.segment.length, zone.segment.halfWidth)
	end
	return MageService.enemiesInRadius(zone.center, zone.radius)
end
MageService.zoneEnemies = zoneEnemies

local function tickZones(t: number)
	local keep = {}
	for _, zone in ipairs(zones) do
		local alive = zone.owner == nil or zone.owner.Parent ~= nil
		while alive and t >= zone.nextTick and zone.nextTick <= zone.untilT + 1e-3 do
			zone.nextTick += zone.tick
			if zone.onTick then
				local ok, err = pcall(zone.onTick, zoneEnemies(zone), zone)
				if not ok then
					warn("[MageService] зона: " .. tostring(err))
				end
			end
		end
		if alive and t < zone.untilT then
			table.insert(keep, zone)
		elseif zone.onEnd then
			pcall(zone.onEnd, zone)
		end
	end
	zones = keep
end

local function heartbeat()
	local t = now()
	tickDebuffs(t)
	tickZones(t)
end

-- ===== Покров =====

function MageService.isVeiled(player): boolean
	return (player:GetAttribute("VeiledUntil") or 0) > now()
end

-- Снять покров (первый удар или заклинание): множитель засады или 1.
function MageService.consumeVeil(player): number
	if not MageService.isVeiled(player) then
		return 1
	end
	player:SetAttribute("VeiledUntil", 0)
	fx({ kind = "veil", phase = "off", caster = player, ambush = true })
	-- Древо (Покров): «Плащ забвения» — щит, конец бафа скорости.
	TalentMods.onVeilEnd(player)
	-- «Тихий шаг»: засада ×1,8 вместо ×1,5.
	return TalentMods.ambush(player, LootMage.Veil.ambush)
end

local AbilityService -- подставляется в start (циклическая зависимость через WeaponAbilities)

function MageService.veil(player)
	if not MageService.isMage(player) then
		return { ok = false, reason = "no-ability" }
	end
	local root = rootOf(player)
	if not root then
		return { ok = false, reason = "no-character" }
	end
	local veil = LootMage.Veil
	local left = AbilityService and AbilityService.cooldownLeft(player, veil.id) or 0
	if left > 0 then
		return { ok = false, reason = "cooldown", remaining = left }
	end
	if not ManaService.spend(player, veil.cost) then
		return { ok = false, reason = "no-mana", need = veil.cost }
	end
	-- Древо: «Безмолвие» (+2 с), «Тихий уход» (−2 с КД), «Быстрое чтение» (−15% КД).
	local duration = TalentMods.veilDuration(player, veil.duration)
	local cooldown = TalentMods.veilCooldown(player, veil.cooldown)
	local untilT = now() + duration
	player:SetAttribute("VeiledUntil", untilT)
	if AbilityService then
		AbilityService.startCooldown(player, veil.id, cooldown)
	end
	-- «Лёгкий шаг»: +15% скорости бега под покровом.
	local speed = TalentMods.get(player).veilSpeed
	if speed then
		TalentMods.addSpeed(player, "veil", speed, duration)
	end
	fx({ kind = "veil", phase = "on", caster = player, untilT = untilT, position = root.Position })
	task.delay(duration + 0.05, function()
		if player.Parent and (player:GetAttribute("VeiledUntil") or 0) == untilT then
			player:SetAttribute("VeiledUntil", 0)
			fx({ kind = "veil", phase = "off", caster = player })
			TalentMods.onVeilEnd(player)
		end
	end)
	DebugState.bump("Mage", "Veils")
	return { ok = true, ability = veil.id, name = veil.name, cooldown = cooldown, castTime = 0.25, duration = duration }
end

-- ===== Пассивки =====

local function passiveOf(player)
	local profile = DataService.get(player)
	local _, passive = Loot.abilityOf(profile and profile.equippedWeapon)
	if passive and passive.school == "mage" then
		return passive
	end
	return nil
end
MageService.passiveOf = passiveOf

-- Множитель урона снаряда от пассивок (метка ловчего, закалка).
local function passiveMultiplier(player, enemy, passive): number
	if not passive then
		return 1
	end
	local t = now()
	if passive.id == "hunter_mark" then
		local mark = enemy.mageMark
		if mark and mark.owner == player and t < mark.untilT then
			return 1 + passive.bonus
		end
	elseif passive.id == "tempering" then
		local state = stateOf(player)
		if t - state.heatAt > passive.decay then
			state.heat = 0
		end
		return 1 + state.heat * passive.step
	end
	return 1
end

local function splashAt(player, position: Vector3, radius: number, amount: number, exclude, info)
	local hits = 0
	for _, enemy in ipairs(MageService.enemiesInRadius(position, radius, exclude)) do
		if MageService.hit(player, enemy, amount, info) then
			hits += 1
		end
	end
	return hits
end
MageService.splashAt = splashAt

local function onPassiveHit(ctx, enemy, passive)
	local player = ctx.player
	local t = now()
	local state = stateOf(player)
	local base = ctx.strikeBase
	if passive.id == "key_resonance" then
		local mark = state.resonance[enemy]
		if not mark or t > mark.untilT then
			mark = { count = 0, untilT = 0 }
		end
		mark.count += 1
		mark.untilT = t + passive.window
		state.resonance[enemy] = mark
		if mark.count >= passive.hits then
			mark.count = 0
			local targets = MageService.nearestEnemies(enemy.position, passive.arcRange, passive.arcs, { [enemy] = true })
			local points = {}
			for _, other in ipairs(targets) do
				table.insert(points, other.position)
			end
			fx({ kind = "passive", id = passive.id, caster = player, position = enemy.position, model = enemy.model, targets = points })
			task.delay(0.12, function()
				MageService.hit(player, enemy, base * passive.damage, { crit = true, ability = passive.id })
				for _, other in ipairs(targets) do
					MageService.hit(player, other, base * passive.damage, { ability = passive.id })
				end
			end)
		end
	elseif passive.id == "dew" then
		state.dew += 1
		player:SetAttribute("MageDew", state.dew)
		if state.dew >= passive.drops then
			state.dew = 0
			player:SetAttribute("MageDew", 0)
			local _, humanoid = rootOf(player)
			if humanoid then
				MageService.heal(player, humanoid.MaxHealth * passive.heal)
			end
			ManaService.gain(player, passive.mana)
			fx({ kind = "passive", id = passive.id, caster = player })
		end
	elseif passive.id == "hunter_mark" then
		local mark = enemy.mageMark
		if not mark or mark.owner ~= player or t > mark.untilT then
			mark = { owner = player, untilT = 0, hits = 0 }
			enemy.mageMark = mark
		end
		mark.untilT = t + passive.markTime
		mark.hits += 1
		enemy.model:SetAttribute("MageMarkUntil", mark.untilT)
		if mark.hits % passive.every == 0 then
			fx({ kind = "passive", id = passive.id, phase = "falcon", caster = player, model = enemy.model, position = enemy.position })
			task.delay(0.4, function()
				MageService.hit(player, enemy, base * passive.falcon, { crit = true, ability = passive.id })
			end)
		elseif mark.hits == 1 then
			fx({ kind = "passive", id = passive.id, phase = "mark", caster = player, model = enemy.model, untilT = mark.untilT })
		end
	elseif passive.id == "tempering" then
		if t - state.heatAt > passive.decay then
			state.heat = 0
		end
		state.heatAt = t
		state.heat += 1
		if state.heat >= passive.max then
			state.heat = 0
			fx({ kind = "passive", id = passive.id, phase = "blast", caster = player, position = enemy.position, radius = passive.radius })
			splashAt(player, enemy.position, passive.radius, base * passive.blast, nil, { ability = passive.id })
		end
		player:SetAttribute("MageHeat", state.heat)
	elseif passive.id == "footnote" then
		state.hits += 1
		if state.hits % passive.every == 0 then
			fx({ kind = "passive", id = passive.id, phase = "mark", caster = player, model = enemy.model, delay = passive.delay })
			task.delay(passive.delay, function()
				if enemy.alive then
					fx({ kind = "passive", id = passive.id, phase = "burst", caster = player, model = enemy.model, position = enemy.position })
					MageService.hit(player, enemy, base * passive.damage, { crit = true, ability = passive.id })
				end
			end)
		end
	elseif passive.id == "blot" then
		if math.random() < passive.chance then
			local center = enemy.position
			fx({ kind = "passive", id = passive.id, caster = player, position = center, radius = passive.radius, time = passive.time })
			MageService.zone({
				owner = player,
				center = center,
				radius = passive.radius,
				duration = passive.time,
				tick = passive.tick,
				onTick = function(list)
					for _, other in ipairs(list) do
						MageService.hit(player, other, base * passive.damage, { ability = passive.id, noLeech = true })
						EnemyService.slow(other, passive.slow, passive.tick + 0.2)
					end
				end,
			})
		end
	end
end

-- Смерть врага от мага: «Угли» (горящие взрываются), чистка дебафов.
function onEnemyDeath(enemy, killer)
	if enemy.mageDeathHandled then
		return
	end
	enemy.mageDeathHandled = true
	local list = debuffs[enemy]
	local burn = list and list.burn
	if burn and burn.owner and burn.owner.Parent then
		local passive = passiveOf(burn.owner)
		if passive and passive.id == "cinders" then
			local owner = burn.owner
			local center = enemy.position
			fx({ kind = "passive", id = passive.id, caster = owner, position = center, radius = passive.radius })
			task.delay(0.1, function()
				for _, other in ipairs(MageService.enemiesInRadius(center, passive.radius)) do
					MageService.hit(owner, other, burn.base * passive.damage, { ability = passive.id })
					MageService.applyDebuff(owner, other, "burn", burn.base)
				end
			end)
		end
	end
	debuffs[enemy] = nil
	if enemy.model then
		enemy.model:SetAttribute("MageDebuffs", "")
	end
	local _ = killer
end

-- ===== Удар посохом: снаряды =====

-- Ломаемые декорации на пути снаряда (этаж 3 — MeleeService, этажи 4–5 — BreakableService).
local MeleeService -- подставляется в start
local function propStep(player, damage: number)
	return function(bolt, from: Vector3, to: Vector3)
		if not MeleeService then
			return false
		end
		local delta = flat(to - from)
		local reach = delta.Magnitude + bolt.size
		local forward = delta.Magnitude > 0.01 and delta.Unit or bolt.dir
		local origin = Vector3.new(from.X, bolt.feetY + FEET, from.Z)
		local hits = 0
		if MeleeService.hitDestructibleProps then
			local ok, n = pcall(MeleeService.hitDestructibleProps, player, origin, forward, reach, 50)
			hits += ok and type(n) == "number" and n or 0
		end
		for _, hook in ipairs(MeleeService.swingHooks or {}) do
			local ok, n = pcall(hook, player, origin, forward, reach, 50, damage, 1)
			hits += ok and type(n) == "number" and n or 0
		end
		return hits > 0
	end
end

-- Попадание снаряда удара: урон, вампиризм, дебаф, пассивка, взрыв, раскол, цепь.
local function boltHit(ctx, bolt, enemy, spec)
	local player = ctx.player
	local passive = not bolt.echo and ctx.passive or nil
	local amount = bolt.data.damage * passiveMultiplier(player, enemy, ctx.passive)
	-- «Насквозь» (древо мага): враги после своих пробитий посоха — доля урона.
	local talent = ctx.talent
	if talent and talent.pierce > 0 and bolt.hits > (bolt.data.nativePierce or 0) then
		amount *= talent.pierceShare
	end
	local applied = MageService.hit(player, enemy, amount, {
		crit = ctx.crit and bolt.data.primary,
		counter = ctx.counter and bolt.data.primary,
		ability = "staff",
		leech = ctx.leech,
	})
	if not applied then
		return
	end
	ctx.hits += 1
	local debuff = spec.debuff
	if debuff and not bolt.echo and enemy.alive then
		local chance = ctx.combo >= 3 and 1 or debuff[2]
		if math.random() < chance then
			MageService.applyDebuff(player, enemy, debuff[1], ctx.strikeBase)
		end
	end
	if passive then
		onPassiveHit(ctx, enemy, passive)
	end
	-- Раскол на осколки (кость, фолиант): летят веером дальше, мимо задетого врага.
	local split = spec.split
	-- «Расщепление» (древо мага): каждое N-е попадание раскалывает снаряд
	-- (у посохов со своим расколом — на 2 осколка больше).
	if talent and talent.splitEvery and not bolt.data.child and not bolt.echo and TalentMods.rollSplit(player) then
		if split then
			split = { split[1] + 2, split[2], split[3] + 20 }
		else
			split = { talent.splitShards, talent.splitShare, 40 }
		end
		DebugState.bump("Talents", "Splits")
	end
	if split and not bolt.data.child and not bolt.echo then
		local n, share, spread = split[1], split[2], split[3]
		for i = 1, n do
			local angle = (i - (n + 1) / 2) * (spread / math.max(n - 1, 1))
			local dir = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(bolt.dir)
			MageService.spawnBolt(ctx, spec, {
				origin = Vector3.new(enemy.position.X, bolt.pos.Y, enemy.position.Z) + flat(dir).Unit * (enemy.stats.radius + 0.3),
				dir = dir,
				damage = ctx.damage * share,
				size = (spec.size or 0.45) * 0.65,
				speed = (spec.speed or 60) * 0.9,
				range = 11,
				child = true,
				exclude = { enemy },
				visual = "shard",
			})
		end
	end
	-- Цепная молния: прыжки к соседям.
	local chain = spec.chain
	if chain and not bolt.data.child and not bolt.echo then
		local jumps, range, share = chain[1], chain[2], chain[3]
		local visited = { [enemy] = true }
		local points = { enemy.position }
		local from = enemy
		local targets = {}
		for _ = 1, jumps do
			local nextEnemy = MageService.nearestEnemies(from.position, range, 1, visited)[1]
			if not nextEnemy then
				break
			end
			visited[nextEnemy] = true
			table.insert(points, nextEnemy.position)
			table.insert(targets, nextEnemy)
			from = nextEnemy
		end
		if #targets > 0 then
			fx({ kind = "chain", caster = player, style = spec.style, points = points })
			for index, target in ipairs(targets) do
				task.delay(0.06 * index, function()
					MageService.hit(player, target, bolt.data.damage * share, { ability = "chain", leech = ctx.leech })
				end)
			end
		end
	end
end

-- Взрыв снаряда в точке (навес, «большой» снаряд, огненные посохи).
local function boltBlast(ctx, bolt, position: Vector3, splash, directTarget)
	local radius, share = splash[1], splash[2]
	local exclude = directTarget and { [directTarget] = true } or nil
	local center = Vector3.new(position.X, bolt.feetY, position.Z)
	for _, enemy in ipairs(MageService.enemiesInRadius(center, radius, exclude)) do
		local close = flat(enemy.position - center).Magnitude <= enemy.stats.radius + 1.2
		local amount = bolt.data.damage * ((bolt.lob and close) and 1 or share)
		local applied = MageService.hit(ctx.player, enemy, amount, { ability = "staffSplash", leech = ctx.leech and ctx.leech * 0.5 })
		if applied and bolt.lob then
			ctx.hits += 1
			local debuff = ctx.spec.debuff
			if debuff and not bolt.echo and enemy.alive and math.random() < (ctx.combo >= 3 and 1 or debuff[2]) then
				MageService.applyDebuff(ctx.player, enemy, debuff[1], ctx.strikeBase)
			end
			if close and ctx.passive and not bolt.echo then
				onPassiveHit(ctx, enemy, ctx.passive)
			end
		end
	end
end

-- Запустить снаряд удара. over — поля поверх спеки посоха (origin, dir, damage, lob…).
function MageService.spawnBolt(ctx, spec, over)
	local splash = over.splash or spec.splash
	local speed = over.speed or spec.speed or 60
	local range = over.range or ctx.range
	local homing = over.homing or spec.homing
	local pierce = over.pierce or spec.pierce
	local nativePierce = pierce or 0
	-- Древо мага (путь «Посох»): скорость и дальность, «Наводка», «Насквозь».
	local talent = ctx.talent
	if talent and not over.lob then
		speed *= talent.speed
		range *= talent.range
		if talent.homing then
			homing = math.max(homing or 0, talent.homing)
		end
		if talent.pierce > 0 and not over.child then
			pierce = nativePierce + talent.pierce
		end
	end
	local bolt
	bolt = MageBolts.spawn({
		owner = ctx.player,
		origin = over.origin,
		dir = over.dir,
		feetY = ctx.feetY,
		speed = speed,
		size = over.size or spec.size or 0.45,
		range = range,
		style = spec.style,
		visual = over.visual,
		homing = homing,
		pierce = pierce,
		lob = over.lob,
		echo = over.echo,
		delay = over.delay,
		exclude = over.exclude,
		splashRadius = splash and splash[1] or nil,
		data = { damage = over.damage, primary = over.primary, child = over.child, nativePierce = nativePierce },
		onHit = not over.lob and function(b, enemy)
			boltHit(ctx, b, enemy, spec)
			b.data.lastTarget = enemy
			return true
		end or nil,
		onEnd = function(b, position, reason)
			if splash and (b.lob or reason ~= "range") then
				boltBlast(ctx, b, position, splash, not b.lob and b.data.lastTarget or nil)
			end
		end,
		onStep = not over.lob and propStep(ctx.player, over.damage) or nil,
	})
	return bolt
end

-- Волна-конус (вой, прилив, мехи): расходится со скоростью speed, бьёт всех в секторе.
local function fireWave(ctx, origin: Vector3, forward: Vector3, pattern, damage: number, echo: boolean?)
	local speed = 34
	local feetOrigin = Vector3.new(origin.X, ctx.feetY, origin.Z)
	fx({ kind = "wave", caster = ctx.player, style = ctx.spec.style, origin = feetOrigin, dir = forward,
		radius = pattern.radius, angle = pattern.angle, speed = speed, echo = echo })
	for _, enemy in ipairs(MageService.enemiesInCone(feetOrigin, forward, pattern.radius, pattern.angle / 2)) do
		local distance = flat(enemy.position - feetOrigin).Magnitude
		task.delay(math.max(distance - 1, 0) / speed, function()
			local applied = MageService.hit(ctx.player, enemy, damage, { crit = ctx.crit, counter = ctx.counter, ability = "staffWave", leech = ctx.leech })
			if applied and not echo then
				ctx.hits += 1
				local debuff = ctx.spec.debuff
				if debuff and enemy.alive then
					MageService.applyDebuff(ctx.player, enemy, debuff[1], ctx.strikeBase)
				end
				EnemyService.shove(enemy, flat(enemy.position - feetOrigin), 1.6, 0.18)
				if ctx.passive then
					onPassiveHit(ctx, enemy, ctx.passive)
				end
			end
		end)
	end
end

-- Луч (лунный, песочный, памяти): мгновенно по линии до стены, пробивает всех.
local function fireBeam(ctx, origin: Vector3, forward: Vector3, pattern, damage: number, echo: boolean?)
	local length = ctx.range * 0.8
	local wall = FloorGeo.raycast(origin, forward * length)
	if wall then
		length = math.max(flat(wall.Position - origin).Magnitude - 0.2, 2)
	end
	local feetOrigin = Vector3.new(origin.X, ctx.feetY, origin.Z)
	fx({ kind = "beam", caster = ctx.player, style = ctx.spec.style, origin = origin, dir = forward, length = length,
		width = pattern.width, echo = echo })
	for _, enemy in ipairs(MageService.enemiesOnSegment(feetOrigin, forward, length, pattern.width)) do
		local applied = MageService.hit(ctx.player, enemy, damage, { crit = ctx.crit, counter = ctx.counter, ability = "staffBeam", leech = ctx.leech })
		if applied and not echo then
			ctx.hits += 1
			local debuff = ctx.spec.debuff
			if debuff and enemy.alive then
				MageService.applyDebuff(ctx.player, enemy, debuff[1], ctx.strikeBase)
			end
			if ctx.passive then
				onPassiveHit(ctx, enemy, ctx.passive)
			end
		end
	end
	if MeleeService then
		propStep(ctx.player, damage)({ size = pattern.width, dir = forward, feetY = ctx.feetY }, origin, origin + forward * length)
	end
end

-- Кольцо вокруг мага (часовой посох).
local function fireNova(ctx, origin: Vector3, pattern, damage: number, echo: boolean?)
	local center = Vector3.new(origin.X, ctx.feetY, origin.Z)
	fx({ kind = "nova", caster = ctx.player, style = ctx.spec.style, position = center, radius = pattern.radius, echo = echo })
	for _, enemy in ipairs(MageService.enemiesInRadius(center, pattern.radius)) do
		local applied = MageService.hit(ctx.player, enemy, damage, { crit = ctx.crit, counter = ctx.counter, ability = "staffNova", leech = ctx.leech })
		if applied and not echo then
			ctx.hits += 1
			local debuff = ctx.spec.debuff
			if debuff and enemy.alive then
				MageService.applyDebuff(ctx.player, enemy, debuff[1], ctx.strikeBase)
			end
			EnemyService.shove(enemy, flat(enemy.position - center), 2, 0.18)
			if ctx.passive then
				onPassiveHit(ctx, enemy, ctx.passive)
			end
		end
	end
end

-- Точка падения навесного снаряда: враг под прицелом или lobRange вперёд.
local function lobPoint(ctx, origin: Vector3, dir: Vector3, target)
	local point
	if target and target.alive then
		local rel = flat(target.position - origin)
		local along = rel:Dot(dir)
		if along > 2 then
			point = origin + dir * math.min(along, ctx.range)
		end
	end
	point = point or (origin + dir * 12)
	local ground = MageService.groundAt(Vector3.new(point.X, ctx.feetY, point.Z))
	return Vector3.new(ground.X, ground.Y + 0.3, ground.Z)
end

-- Выпустить паттерн удара (и эхо копией для «Эха»).
local function firePattern(ctx, echo: boolean?)
	local root = rootOf(ctx.player)
	if not root then
		return 0
	end
	local spec = ctx.spec
	local pattern = ctx.pattern
	local forward = ctx.forward
	local right = Vector3.new(-forward.Z, 0, forward.X)
	ctx.feetY = root.Position.Y - FEET
	local height = ctx.feetY + LootMage.BoltHeight
	local origin = Vector3.new(root.Position.X, height, root.Position.Z) + forward * 1.3 + right * 0.45
	local echoMul = echo and (ctx.echoShare or 0.4) or 1
	local damage = ctx.damage * pattern.share * echoMul

	if pattern.wave then
		fireWave(ctx, origin, forward, pattern, damage, echo)
		return 1
	elseif pattern.beam then
		fireBeam(ctx, origin, forward, pattern, damage, echo)
		return 1
	elseif pattern.nova then
		fireNova(ctx, origin, pattern, damage, echo)
		return 1
	end

	local shots = pattern.shots or 1
	for i = 1, shots do
		local offset = i - (shots + 1) / 2
		local dir = forward
		if pattern.spread then
			dir = CFrame.Angles(0, math.rad(offset * pattern.spread), 0):VectorToWorldSpace(forward)
		end
		local start = origin
		if pattern.offset then
			start += right * offset * pattern.offset
		end
		local over = {
			origin = start,
			dir = dir,
			damage = damage,
			primary = i == math.ceil(shots / 2) and not echo,
			size = (spec.size or 0.45) * (pattern.size or 1) * (echo and 0.85 or 1),
			speed = (spec.speed or 60) * (pattern.speed or 1),
			delay = pattern.interval and (i - 1) * pattern.interval or nil,
			splash = pattern.splash and {
				math.max(pattern.splash[1], spec.splash and spec.splash[1] or 0),
				math.max(pattern.splash[2], spec.splash and spec.splash[2] or 0),
			} or nil,
			echo = echo,
			visual = echo and "echo" or (pattern.size and "big" or nil),
		}
		-- Финал серии посоха всегда взрывается (баланс 07.11: маг сильнее по толпе, тяжёлый финал).
		local finisher = LootMage.FinisherSplash
		if finisher and ctx.combo >= 3 and not echo then
			local own = over.splash or spec.splash
			over.splash = {
				math.max(finisher[1], own and own[1] or 0),
				math.max(finisher[2], own and own[2] or 0),
			}
		end
		if pattern.lob then
			local to = lobPoint(ctx, start, flat(dir).Unit, pattern.spread == nil and ctx.target or nil)
			local distance = flat(to - start).Magnitude
			over.lob = {
				to = to,
				time = math.clamp(distance / ((spec.speed or 50) * 0.75), 0.35, 0.95),
				height = 2.5 + distance * 0.18,
			}
			over.splash = over.splash or spec.splash or { 2.4, 0.6 }
		end
		MageService.spawnBolt(ctx, spec, over)
	end
	return shots
end

-- MeleeService.rangedAttack: удар посохом. ctx от MeleeService: origin, forward, damage,
-- strikeBase, combo, counter, crit, item, cooldown. Возвращает число снарядов.
function MageService.rangedAttack(player, weapon, attack)
	local item = itemOf(weapon)
	local spec = item.bolt
	local combo = math.clamp(attack.combo or 1, 1, 3)
	local patternId = (item.combo and item.combo[combo]) or "single"
	local pattern = LootMage.Patterns[patternId] or LootMage.Patterns.single
	local _, passive = Loot.abilityOf(weapon)
	if passive and passive.school ~= "mage" then
		passive = nil
	end
	local root = rootOf(player)
	if not root then
		return 0
	end
	local forward = attack.forward
	local feetY = root.Position.Y - FEET
	local eye = Vector3.new(attack.origin.X, feetY + LootMage.BoltHeight, attack.origin.Z)
	local target = MageService.bestTarget(eye, forward, item.range or 28, item.arc or LootMage.AimAssist, feetY)
	if target then
		local want = flat(target.position - eye)
		if want.Magnitude > 0.5 then
			forward = want.Unit
		end
	end
	local ambush = MageService.consumeVeil(player)
	local ctx = {
		player = player,
		weapon = weapon,
		spec = spec,
		pattern = pattern,
		patternId = patternId,
		passive = passive,
		combo = combo,
		forward = forward,
		target = target,
		damage = attack.damage * ambush,
		strikeBase = attack.strikeBase or attack.damage,
		crit = attack.crit,
		counter = attack.counter,
		leech = item.leech,
		range = item.range or 28,
		feetY = feetY,
		hits = 0,
		talent = TalentMods.boltMods(player), -- снаряды посоха по древу (или nil)
	}
	-- Снаряд срывается с навершия в такт взмаху (PlayerAnimMage.STRIKE_AT).
	local release = math.min((attack.cooldown or 0.5) * 1.15 * (LootMage.StrikeAt[combo] or 0.3), 0.32)
	local shots = pattern.shots or 1
	task.delay(release, function()
		if not rootOf(player) then
			return
		end
		firePattern(ctx, false)
		-- «Жар отливки»: каждый 5-й снаряд — расплавленная капля навесом.
		if passive and passive.id == "casting_heat" then
			local state = stateOf(player)
			state.shots += shots
			if state.shots >= passive.every then
				state.shots -= passive.every
				local r = rootOf(player)
				if r then
					local start = Vector3.new(r.Position.X, ctx.feetY + LootMage.BoltHeight + 0.6, r.Position.Z) + ctx.forward
					local to = lobPoint(ctx, start, ctx.forward, ctx.target)
					local distance = flat(to - start).Magnitude
					fx({ kind = "passive", id = passive.id, caster = player })
					MageService.spawnBolt(ctx, spec, {
						origin = start,
						dir = ctx.forward,
						damage = ctx.strikeBase * passive.damage,
						lob = { to = to, time = math.clamp(distance / 40, 0.35, 0.8), height = 3 + distance * 0.2 },
						splash = { passive.radius, 1 },
						visual = "molten",
						size = 0.8,
					})
				end
			end
		end
		-- «Эхо»: копия выстрела через 0,35 с.
		if passive and passive.id == "echo" then
			ctx.echoShare = passive.damage
			task.delay(passive.delay, function()
				firePattern(ctx, true)
			end)
		end
	end)
	DebugState.bump("Mage", "Attacks")
	DebugState.set("Mage", "LastPattern", patternId)
	return shots
end

-- ===== Барьер =====

local function parryGate(player)
	if not MageService.isMage(player) then
		return true
	end
	if ManaService.spend(player, LootMage.Barrier.cost) then
		return true
	end
	return false, "no-mana"
end

local function onBarrierSuccess(player)
	if not MageService.isMage(player) then
		return
	end
	local barrier = LootMage.Barrier
	-- «Отдача» (Разрыв): удачный барьер возвращает ещё +5 маны.
	ManaService.gain(player, TalentMods.barrierRefund(player, barrier.refund))
	local root = rootOf(player)
	if not root then
		return
	end
	local center = root.Position - Vector3.new(0, FEET, 0)
	for _, enemy in ipairs(MageService.enemiesInRadius(center, barrier.pushRadius)) do
		local away = flat(enemy.position - center)
		if away.Magnitude < 0.1 then
			away = root.CFrame.LookVector
		end
		EnemyService.shove(enemy, away, barrier.push, barrier.pushTime)
	end
	fx({ kind = "barrier", phase = "block", caster = player, position = root.Position, radius = barrier.pushRadius })
	DebugState.bump("Mage", "Barriers")
end

-- ===== Класс =====

local function publishClass(player)
	local mage = MageService.isMage(player)
	player:SetAttribute("ClassAbility", mage and LootMage.Veil.id or "")
	player:SetAttribute("ClassAbilityIcon", mage and LootMage.Veil.icon or "")
	if not mage then
		player:SetAttribute("VeiledUntil", 0)
	end
end
MageService.publishClass = publishClass

function MageService.start()
	MeleeService = require(script.Parent.MeleeService)
	AbilityService = require(script.Parent.AbilityService)

	-- Удар посохом — снаряды (MeleeService зовёт для typeId == "staff").
	MeleeService.rangedAttack = MageService.rangedAttack

	-- Барьер: окно парирования мага стоит маны; удачный — возврат и отброс.
	CombatService.hooks.parryGate = parryGate
	local parrySuccess = CombatService.hooks.parrySuccess
	CombatService.hooks.parrySuccess = function(player)
		if parrySuccess then
			pcall(parrySuccess, player)
		end
		onBarrierSuccess(player)
	end
	local requestParry = MeleeService.requestParry
	MeleeService.requestParry = function(player, ...)
		local response = requestParry(player, ...)
		if type(response) == "table" and response.ok and MageService.isMage(player) then
			fx({ kind = "barrier", phase = "open", caster = player, window = response.window })
		end
		return response
	end

	-- Покров — третий слот способностей.
	AbilityService.hooks.slot3 = MageService.veil

	local classApplied = CombatService.hooks.classApplied
	CombatService.hooks.classApplied = function(player, refill)
		if classApplied then
			classApplied(player, refill)
		end
		publishClass(player)
	end

	local function hook(player)
		task.spawn(function()
			local waited = 0
			while not player:GetAttribute("ProfileVersion") and waited < 60 and player.Parent do
				waited += task.wait(0.1)
			end
			if player.Parent then
				publishClass(player)
			end
		end)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("VeiledUntil", 0)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		passiveState[player] = nil
		healFxAt[player] = nil
		for _, list in pairs(debuffs) do
			for kind, entry in pairs(list) do
				if entry.owner == player then
					list[kind] = nil
				end
			end
		end
	end)

	if not loop then
		loop = RunService.Heartbeat:Connect(heartbeat)
	end
	print("[MageService] маг: снаряды посохов, барьер, покров, дебафы")
end

return MageService
