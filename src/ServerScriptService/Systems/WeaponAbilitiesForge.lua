--!nonstrict
-- WeaponAbilitiesForge (сервер)
-- Способности и пассивки оружия этажа 4 «Кузня Основателя»:
--   Молот-тигель        — «Разлив»: три лужи расплава по линии вспыхивают (подброс) и горят (замедление);
--   Раскалённый клинок  — «Перекал»: волна жара и 5 с перекала — каждый удар взрывается и поджигает;
--   Молот-наковальня    — «Наковальня с небес»: метка → падение наковальни (оглушение) + ударная волна;
--                         пассивка «Закалка»: заряды за удары, на 5 зарядах финал звенит кольцом;
--   Клинок горна        — «Дыхание горна»: струя пламени конусом, каждый тик — уголь;
--                         пассивка «Угли»: на 3-м угле враг вспыхивает;
--   Шлаковая коса       — «Шлаковый серп»: два оборота + шесть луж шлака; пассивка «Окалина»;
--   Незавершённая отливка (секрет) — «Заливка»: волны расплава по числу ступеней, на 3-й — взрыв пара;
--                         пассивка «Отливка»: удары доливают металл (атрибуты игрока CastStage, CastMetal).
-- Числа — Config.LootFloor4. Клиент (AbilityFxForge) рисует по AbilityFx kind = "forge".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loot = require(Shared.Config.Loot)
local DebugState = require(Shared.Net.DebugState)

local EnemyService = require(script.Parent.EnemyService)
local DataService = require(script.Parent.DataService)

local WeaponAbilitiesForge = {}

local H -- помощники WeaponAbilities (см. install)

local temper = {} -- [player] = { stacks, untilT, lastT }
local casting = {} -- [player] = { metal, lastT, stage }
local overheat = {} -- [player] = untilT

local function isObject(enemy): boolean
	return enemy.stats.role == "object"
end

local function feetOf(root): Vector3
	return root.Position - Vector3.new(0, H.FEET, 0)
end

-- Ожог: тики урона по времени. Новый ожог того же источника заменяет старый.
local function burn(player, enemy, perTick: number, ticks: number, interval: number, source: string)
	if not enemy.alive or isObject(enemy) then
		return
	end
	enemy.burns = enemy.burns or {}
	local id = (enemy.burns[source] or 0) + 1
	enemy.burns[source] = id
	enemy.model:SetAttribute("BurningUntil", H.now() + ticks * interval)
	task.spawn(function()
		for _ = 1, ticks do
			task.wait(interval)
			if not enemy.alive or enemy.burns[source] ~= id then
				return
			end
			H.hit(player, enemy, perTick, source, { dot = true })
		end
	end)
end

-- ===== Разлив =====

local function castSpill(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)

	task.delay(ability.pourAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local origin = feetOf(current)
		local direction = H.lookOf(current)
		local reach = H.clearLength(origin, direction, ability.poolStart + ability.poolSpacing * (ability.pools - 1) + ability.poolRadius)
		H.fx({ kind = "forge", phase = "spillPour", caster = player, position = origin, direction = direction })
		for i = 1, ability.pools do
			local along = math.min(ability.poolStart + ability.poolSpacing * (i - 1), math.max(1.5, reach - ability.poolRadius * 0.5))
			local center = origin + direction * along
			task.delay(ability.poolDelay * (i - 1), function()
				local hits = 0
				for _, enemy in ipairs(H.enemiesInRadius(center, ability.poolRadius)) do
					if enemy.alive then
						if H.hit(player, enemy, power * ability.eruptDamage, ability.id) then
							hits += 1
						end
						EnemyService.launch(enemy, ability.launchHeight, ability.launchTime)
					end
				end
				DebugState.set("Ability", "LastHits", hits)
				H.fx({ kind = "forge", phase = "spillErupt", caster = player, position = center, radius = ability.poolRadius, index = i, burnTime = ability.burnTime })
				local ticks = math.floor(ability.burnTime / ability.burnTick)
				for _ = 1, ticks do
					task.wait(ability.burnTick)
					for _, enemy in ipairs(H.enemiesInRadius(center, ability.poolRadius)) do
						if enemy.alive and not isObject(enemy) then
							H.hit(player, enemy, power * ability.burnDamage, ability.id, { dot = true })
							EnemyService.slow(enemy, ability.slow, ability.slowTime)
						end
					end
				end
				H.fx({ kind = "forge", phase = "spillEnd", position = center, radius = ability.poolRadius, index = i })
			end)
		end
	end)
	return { ok = true }
end

-- ===== Перекал =====

local function castOverheat(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)

	task.delay(ability.novaAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local center = feetOf(current)
		local hits = 0
		for _, enemy in ipairs(H.enemiesInRadius(center, ability.novaRadius)) do
			if enemy.alive and H.hit(player, enemy, power * ability.novaDamage, ability.id) then
				hits += 1
			end
		end
		local untilT = H.now() + ability.buffTime
		overheat[player] = untilT
		player:SetAttribute("OverheatUntil", untilT)
		DebugState.set("Ability", "LastHits", hits)
		H.fx({ kind = "forge", phase = "overheatNova", caster = player, position = center, radius = ability.novaRadius, duration = ability.buffTime })
	end)
	return { ok = true }
end

-- ===== Наковальня с небес =====

local function castAnvil(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)

	task.delay(ability.markAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local origin = feetOf(current)
		local look = H.lookOf(current)
		local target, best = nil, math.huge
		for _, enemy in ipairs(H.enemiesInCone(origin, look, ability.range, 40)) do
			local distance = H.flat(enemy.position - origin).Magnitude
			if enemy.alive and distance < best then
				target, best = enemy, distance
			end
		end
		local point = target and Vector3.new(target.position.X, origin.Y, target.position.Z)
			or origin + look * H.clearLength(origin, look, ability.range * 0.55)
		H.fx({ kind = "forge", phase = "anvilMark", caster = player, position = point, radius = ability.radius, time = ability.fallTime })

		task.delay(ability.fallTime, function()
			local hits = 0
			local inner = {}
			for _, enemy in ipairs(H.enemiesInRadius(point, ability.radius)) do
				if enemy.alive then
					inner[enemy] = true
					if H.hit(player, enemy, power * ability.damage, ability.id) then
						hits += 1
					end
					EnemyService.stun(enemy, enemy.stats.isBoss and ability.bossStun or ability.stun)
				end
			end
			for _, enemy in ipairs(H.enemiesInRadius(point, ability.ringRadius)) do
				if enemy.alive and not inner[enemy] then
					H.hit(player, enemy, power * ability.ringDamage, ability.id)
					local away = H.flat(enemy.position - point)
					if away.Magnitude > 0.1 then
						EnemyService.shove(enemy, away, 1.6, 0.18)
					end
				end
			end
			DebugState.set("Ability", "LastHits", hits)
			H.fx({ kind = "forge", phase = "anvilImpact", caster = player, position = point, radius = ability.radius, ringRadius = ability.ringRadius, hits = hits })
		end)
	end)
	return { ok = true }
end

-- ===== Угли (пассивка) =====

local function addEmber(player, enemy, baseDamage: number)
	local passive = Loot.Passives.embers
	if not passive or not enemy.alive or isObject(enemy) then
		return
	end
	local t = H.now()
	enemy.embers = enemy.embers or {}
	local mark = enemy.embers[player]
	if not mark or t > mark.untilT then
		mark = { count = 0, untilT = 0 }
	end
	mark.count += 1
	mark.untilT = t + passive.stackTime
	enemy.embers[player] = mark
	if mark.count >= passive.stacks then
		mark.count = 0
		enemy.model:SetAttribute("Embers", 0)
		local center = enemy.position
		H.fx({ kind = "forge", phase = "emberBurst", caster = player, model = enemy.model, position = center, radius = passive.radius })
		for _, other in ipairs(H.enemiesInRadius(center, passive.radius)) do
			if other.alive then
				H.hit(player, other, baseDamage * passive.burstDamage, "embers", { crit = true })
			end
		end
		burn(player, enemy, baseDamage * passive.burnDamage, passive.burnTicks, passive.burnInterval, "embers")
	else
		enemy.model:SetAttribute("Embers", mark.count)
		enemy.model:SetAttribute("EmbersUntil", mark.untilT)
		H.fx({ kind = "forge", phase = "ember", caster = player, model = enemy.model, count = mark.count })
	end
end

-- ===== Дыхание горна =====

local function castBreath(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)
	local _, passive = Loot.abilityOf(weapon)
	local withEmbers = passive and passive.id == "embers"

	task.delay(ability.startAt, function()
		if not H.rootOf(player) then
			return
		end
		H.fx({
			kind = "forge",
			phase = "breathStart",
			caster = player,
			radius = ability.radius,
			halfAngle = ability.halfAngle,
			duration = ability.ticks * ability.tickInterval,
		})
		local total = 0
		for index = 1, ability.ticks do
			local current = H.rootOf(player)
			if not current then
				break
			end
			local origin = feetOf(current)
			local look = H.lookOf(current)
			local hits = 0
			for _, enemy in ipairs(H.enemiesInCone(origin, look, ability.radius, ability.halfAngle)) do
				if enemy.alive then
					if H.hit(player, enemy, power * ability.tickDamage, ability.id) then
						hits += 1
					end
					if withEmbers then
						addEmber(player, enemy, power)
					end
				end
			end
			total += hits
			H.fx({ kind = "forge", phase = "breathTick", caster = player, index = index, hits = hits })
			task.wait(ability.tickInterval)
		end
		DebugState.set("Ability", "LastHits", total)
	end)
	return { ok = true }
end

-- ===== Шлаковый серп =====

local function castSlagReap(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)

	for index, at in ipairs(ability.hits) do
		task.delay(at, function()
			local current = H.rootOf(player)
			if not current then
				return
			end
			local center = feetOf(current)
			local hits = 0
			for _, enemy in ipairs(H.enemiesInRadius(center, ability.radius)) do
				if enemy.alive and H.hit(player, enemy, power * ability.hitDamage, ability.id) then
					hits += 1
				end
			end
			DebugState.set("Ability", "LastHits", hits)
			H.fx({ kind = "forge", phase = "slagSpin", caster = player, position = center, radius = ability.radius, index = index })

			if index ~= #ability.hits then
				return
			end
			-- Шлак разлетается веером и застывает лужами.
			local look = H.lookOf(current)
			local points = {}
			for i = 1, ability.globs do
				local angle = math.rad((i - 1) * 360 / ability.globs + 30)
				local direction = (CFrame.Angles(0, angle, 0) * CFrame.lookAt(Vector3.zero, look)).LookVector
				direction = H.flat(direction).Unit
				local distance = H.clearLength(center, direction, ability.globDistance * (0.8 + 0.4 * ((i * 37) % 10) / 10))
				table.insert(points, center + direction * distance)
			end
			H.fx({ kind = "forge", phase = "slagGlobs", caster = player, position = center, points = points, flight = ability.globFlight, radius = ability.globRadius, time = ability.globTime })
			task.delay(ability.globFlight, function()
				local ticks = math.floor(ability.globTime / ability.globTick)
				for _ = 1, ticks do
					local struck = {}
					for _, point in ipairs(points) do
						for _, enemy in ipairs(H.enemiesInRadius(point, ability.globRadius)) do
							if enemy.alive and not struck[enemy] and not isObject(enemy) then
								struck[enemy] = true
								H.hit(player, enemy, power * ability.globDamage, ability.id, { dot = true })
								EnemyService.slow(enemy, ability.slow, ability.slowTime)
							end
						end
					end
					task.wait(ability.globTick)
				end
			end)
		end)
	end
	return { ok = true }
end

-- ===== Отливка (пассивка секретки) и Заливка =====

local function setStage(player, state)
	local passive = Loot.Passives.casting
	local stage = math.min(passive.stages, math.floor(state.metal / passive.perStage))
	player:SetAttribute("CastMetal", math.floor(state.metal * 10 + 0.5) / 10)
	if stage ~= state.stage then
		local grew = stage > state.stage
		state.stage = stage
		player:SetAttribute("CastStage", stage)
		H.fx({ kind = "forge", phase = "castStage", caster = player, stage = stage, grew = grew })
	end
end

local function castingState(player)
	local state = casting[player]
	if not state then
		state = { metal = 0, lastT = 0, stage = 0 }
		casting[player] = state
	end
	return state
end

local function castPour(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)
	local state = castingState(player)
	local stage = state.stage
	local waves = math.max(1, stage)

	task.delay(ability.waveAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local center = feetOf(current)
		H.fx({ kind = "forge", phase = "pourStart", caster = player, position = center, waves = waves, stage = stage, interval = ability.waveInterval })
		local total = 0
		for wave = 1, waves do
			local radius = ability.waveRadius + ability.waveGrow * (wave - 1)
			for _, enemy in ipairs(H.enemiesInRadius(center, radius)) do
				if enemy.alive and H.hit(player, enemy, power * ability.waveDamage, ability.id) then
					total += 1
				end
			end
			H.fx({ kind = "forge", phase = "pourWave", caster = player, position = center, radius = radius, index = wave })
			if wave < waves then
				task.wait(ability.waveInterval)
			end
		end
		-- Ступени сгорают — клинок снова короткий.
		state.metal = 0
		setStage(player, state)
		if stage >= 3 then
			task.wait(ability.steamDelay)
			for _, enemy in ipairs(H.enemiesInRadius(center, ability.steamRadius)) do
				if enemy.alive then
					if H.hit(player, enemy, power * ability.steamDamage, ability.id, { crit = true }) then
						total += 1
					end
					EnemyService.launch(enemy, ability.launchHeight, ability.launchTime)
				end
			end
			H.fx({ kind = "forge", phase = "pourSteam", caster = player, position = center, radius = ability.steamRadius })
		end
		DebugState.set("Ability", "LastHits", total)
	end)
	return { ok = true }
end

-- Металл остывает без боя; снятая «Незавершённая отливка» — сразу 0.
task.spawn(function()
	while true do
		local dt = task.wait(0.5)
		local passive = Loot.Passives.casting
		local t = H and H.now() or 0
		for player, state in pairs(casting) do
			if not player.Parent then
				casting[player] = nil
			elseif state.metal > 0 then
				local ok, profile = pcall(DataService.get, player)
				local weapon = ok and profile and profile.equippedWeapon
				local _, current = Loot.abilityOf(weapon)
				if not current or current.id ~= "casting" then
					state.metal = 0
				elseif t - state.lastT > passive.decayDelay then
					state.metal = math.max(0, state.metal - passive.decayRate * dt)
				end
				setStage(player, state)
			end
		end
	end
end)

-- Один заряд на взмах, даже если задеты несколько врагов.
local function newSwing(store, player, t: number): boolean
	local last = store[player]
	if last and t - last < 0.1 then
		return false
	end
	store[player] = t
	return true
end
local swingTemper, swingCast = {}, {}

-- ===== Пассивки на ударе =====

local function onMeleeHit(player, weapon, enemy, combo: number, baseDamage: number)
	local t = H.now()

	-- «Перекал» (способность, а не пассивка): удары взрываются, пока горит бафф.
	if (overheat[player] or 0) > t then
		local ability = Loot.Abilities.overheat
		local center = enemy.position
		H.fx({ kind = "forge", phase = "overheatBurst", caster = player, position = center, radius = ability.burstRadius })
		for _, other in ipairs(H.enemiesInRadius(center, ability.burstRadius)) do
			if other.alive then
				H.hit(player, other, baseDamage * ability.hitBurst, "overheat")
			end
		end
		burn(player, enemy, baseDamage * ability.burnDamage, ability.burnTicks, ability.burnInterval, "overheat")
	end

	local _, passive = Loot.abilityOf(weapon)
	if not passive then
		return
	end

	if passive.id == "temper" then
		local state = temper[player] or { stacks = 0, untilT = 0 }
		temper[player] = state
		if t > state.untilT then
			state.stacks = 0
		end
		if newSwing(swingTemper, player, t) then
			if combo == H.comboLength and state.stacks >= passive.maxStacks then
				state.stacks = 0
				local root = H.rootOf(player)
				local center = root and feetOf(root) or enemy.position
				H.fx({ kind = "forge", phase = "temperRing", caster = player, position = center, radius = passive.radius })
				for _, other in ipairs(H.enemiesInRadius(center, passive.radius)) do
					if other.alive then
						H.hit(player, other, baseDamage * passive.damage, "temper", { crit = true })
						EnemyService.stun(other, passive.stun)
					end
				end
			else
				state.stacks = math.min(passive.maxStacks, state.stacks + 1)
				H.fx({ kind = "forge", phase = "temperStack", caster = player, count = state.stacks })
			end
			state.untilT = t + passive.stackTime
			player:SetAttribute("TemperStacks", state.stacks)
			player:SetAttribute("TemperUntil", state.untilT)
		end
	elseif passive.id == "embers" then
		addEmber(player, enemy, baseDamage)
	elseif passive.id == "slag_crust" then
		if not enemy.alive or isObject(enemy) then
			return
		end
		EnemyService.slow(enemy, passive.slow, passive.slowTime)
		enemy.crust = enemy.crust or {}
		local count = (enemy.crust[player] or 0) + 1
		if count >= passive.every then
			count = 0
			EnemyService.breakArmor(enemy, passive.armorBreak, passive.armorBreakDuration)
			H.fx({ kind = "forge", phase = "crust", caster = player, model = enemy.model, position = enemy.position })
		end
		enemy.crust[player] = count
	elseif passive.id == "casting" then
		local state = castingState(player)
		state.lastT = t
		if newSwing(swingCast, player, t) then
			state.metal = math.min(passive.perStage * passive.stages, state.metal + 1)
			setStage(player, state)
		end
		-- Бонус ступеней — отдельным ударом, чтобы не трогать формулу MeleeService.
		if state.stage > 0 and enemy.alive then
			H.hit(player, enemy, baseDamage * passive.bonusPerStage * state.stage, "casting")
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	temper[player] = nil
	casting[player] = nil
	overheat[player] = nil
	swingTemper[player] = nil
	swingCast[player] = nil
end)

function WeaponAbilitiesForge.install(helpers)
	H = helpers
	return {
		casts = {
			spill = castSpill,
			overheat = castOverheat,
			anvil_drop = castAnvil,
			forge_breath = castBreath,
			slag_reap = castSlagReap,
			pour = castPour,
		},
		onMeleeHit = onMeleeHit,
		-- для переделанных способностей (WeaponAbilitiesV2): угли «Горнила», ступени «Первой отливки»
		addEmber = addEmber,
		castingState = castingState,
		setStage = setStage,
	}
end

return WeaponAbilitiesForge
