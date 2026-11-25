--!nonstrict
-- WeaponAbilitiesChronicle (сервер)
-- Способности и пассивки оружия этажа 5 «Архив Хроник»:
--   Перо хрониста       — «Строка»: строка рун по земле, руны взрываются по очереди (оглушение);
--   Печать              — «Опечатать»: враги в круге застывают во времени (+уязвимость), печать ломается;
--   Молот Песочных часов — «Безвременье»: купол-замедление, удары внутри отдаются эхом, обвал песка;
--                         пассивка «Песок времени»: удары сокращают перезарядку «Безвременья»;
--   Чернильный клинок   — «Разлить чернила»: веер чернил, пятна на врагах усиливают урон;
--                         пассивка «Пятна»: удары ставят пятна (до 4);
--   Коса Забвения       — «Стереть»: широкий взмах, слабых стирает; пассивка «Забвение»: финал −броня, +урон;
--   Клинок Памяти (секрет) — «Вспомнить»: два эхо-двойника повторяют удары последних 4 с;
--                         пассивка «Послеобраз»: каждый 4-й попавший удар повторяется эхом.
-- Числа — Config.LootFloor5. Клиент (AbilityFxChronicle) рисует по AbilityFx kind = "chron".
-- Удары героя запоминает swingHook (MeleeService.swingHooks, подключает WeaponAbilities.swingHook).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loot = require(Shared.Config.Loot)
local DebugState = require(Shared.Net.DebugState)

local EnemyService = require(script.Parent.EnemyService)
local DataService = require(script.Parent.DataService)

local WeaponAbilitiesChronicle = {}

local H -- помощники WeaponAbilities (см. install)

local domes = {} -- [player] = { center, radius, untilT, echo }
local memory = {} -- [player] = { {t, forward, range, arc, damage, combo}, ... }
local afterimage = {} -- [player] = { count, hitT }
local sandSwing = {} -- [player] = время последнего засчитанного взмаха

local function isObject(enemy): boolean
	return enemy.stats.role == "object"
end

local function feetOf(root): Vector3
	return root.Position - Vector3.new(0, H.FEET, 0)
end

local function equipped(player)
	local ok, profile = pcall(DataService.get, player)
	return ok and profile and profile.equippedWeapon or nil
end

-- ===== Строка =====

local function castInscribe(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)

	task.delay(ability.writeAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local origin = feetOf(current)
		local direction = H.lookOf(current)
		local length = H.clearLength(origin, direction, ability.length)
		local runes = {}
		for i = 1, ability.runes do
			table.insert(runes, origin + direction * (length * (i - 0.5) / ability.runes))
		end
		H.fx({
			kind = "chron",
			phase = "inscribeWrite",
			caster = player,
			position = origin,
			direction = direction,
			length = length,
			runes = runes,
			writeTime = ability.writeTime,
			detonateDelay = ability.detonateDelay,
			interval = ability.runeInterval,
		})
		local struck = {}
		local hits = 0
		local step = length / ability.runes
		for i, point in ipairs(runes) do
			task.delay(ability.writeTime + ability.detonateDelay + ability.runeInterval * (i - 1), function()
				for _, enemy in ipairs(H.enemiesOnSegment(point - direction * (step * 0.5), direction, step, ability.halfWidth)) do
					if enemy.alive and not struck[enemy] then
						struck[enemy] = true
						if H.hit(player, enemy, power * ability.damage, ability.id) then
							hits += 1
						end
						EnemyService.stun(enemy, ability.stun)
					end
				end
				H.fx({ kind = "chron", phase = "runeBurst", caster = player, position = point, index = i, radius = ability.halfWidth + 0.6 })
				if i == #runes then
					DebugState.set("Ability", "LastHits", hits)
				end
			end)
		end
	end)
	return { ok = true }
end

-- ===== Опечатать =====

local function castSeal(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)

	task.delay(ability.stampAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local center = feetOf(current)
		local hits = 0
		local models = {}
		for _, enemy in ipairs(H.enemiesInRadius(center, ability.radius)) do
			if enemy.alive then
				if H.hit(player, enemy, power * ability.damage, ability.id) then
					hits += 1
				end
				if enemy.alive and not isObject(enemy) then
					local freeze = enemy.stats.isBoss and ability.bossFreeze or ability.freeze
					EnemyService.stun(enemy, freeze)
					EnemyService.setVulnerable(enemy, ability.vulnerable, freeze)
					enemy.model:SetAttribute("TimeFrozenUntil", H.now() + freeze)
					table.insert(models, enemy.model)
					task.delay(freeze, function()
						if enemy.alive then
							H.hit(player, enemy, power * ability.breakDamage, ability.id, { crit = true })
							H.fx({ kind = "chron", phase = "sealBreak", caster = player, model = enemy.model, position = enemy.position })
						end
						if enemy.model then
							enemy.model:SetAttribute("TimeFrozenUntil", nil)
						end
					end)
				end
			end
		end
		DebugState.set("Ability", "LastHits", hits)
		H.fx({ kind = "chron", phase = "sealStamp", caster = player, position = center, radius = ability.radius, targets = models, freeze = ability.freeze })
	end)
	return { ok = true }
end

-- ===== Безвременье =====

local function castTimeless(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)

	task.delay(ability.turnAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local center = feetOf(current)
		local dome = { center = center, radius = ability.radius, untilT = H.now() + ability.duration, echo = ability.echo }
		domes[player] = dome
		player:SetAttribute("TimelessUntil", dome.untilT)
		H.fx({ kind = "chron", phase = "domeStart", caster = player, position = center, radius = ability.radius, duration = ability.duration })
		local pulses = math.floor(ability.duration / ability.pulse)
		for _ = 1, pulses do
			for _, enemy in ipairs(H.enemiesInRadius(center, ability.radius)) do
				if enemy.alive and not isObject(enemy) then
					EnemyService.slow(enemy, ability.slow, ability.pulse + 0.15)
				end
			end
			task.wait(ability.pulse)
		end
		if domes[player] == dome then
			domes[player] = nil
		end
		local hits = 0
		for _, enemy in ipairs(H.enemiesInRadius(center, ability.radius)) do
			if enemy.alive and H.hit(player, enemy, power * ability.collapseDamage, ability.id) then
				hits += 1
			end
		end
		DebugState.set("Ability", "LastHits", hits)
		H.fx({ kind = "chron", phase = "domeCollapse", caster = player, position = center, radius = ability.radius, hits = hits })
	end)
	return { ok = true }
end

-- ===== Разлить чернила =====

local function stainsOf(player, enemy): number
	local mark = enemy.inkStains and enemy.inkStains[player]
	if not mark or H.now() > mark.untilT then
		return 0
	end
	return mark.count
end

local function castInkSplash(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)

	task.delay(ability.splashAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local origin = feetOf(current)
		local direction = H.lookOf(current)
		local hits = 0
		local models = {}
		for _, enemy in ipairs(H.enemiesInCone(origin, direction, ability.radius, ability.halfAngle)) do
			if enemy.alive then
				local stains = stainsOf(player, enemy)
				if enemy.inkStains then
					enemy.inkStains[player] = nil
				end
				enemy.model:SetAttribute("InkStains", 0)
				if H.hit(player, enemy, power * (ability.damage + ability.perStain * stains), ability.id, { crit = stains >= 3 }) then
					hits += 1
				end
				if enemy.alive and not isObject(enemy) then
					EnemyService.slow(enemy, ability.slow, ability.slowTime)
				end
				table.insert(models, { model = enemy.model, stains = stains })
			end
		end
		DebugState.set("Ability", "LastHits", hits)
		H.fx({ kind = "chron", phase = "inkSplash", caster = player, position = origin, direction = direction, radius = ability.radius, halfAngle = ability.halfAngle, targets = models })
	end)
	return { ok = true }
end

-- ===== Стереть =====

local function castErase(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)

	task.delay(ability.swingAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local origin = feetOf(current)
		local direction = H.lookOf(current)
		local hits = 0
		local erased = {}
		for _, enemy in ipairs(H.enemiesInCone(origin, direction, ability.radius, ability.halfAngle)) do
			if enemy.alive then
				local amount = power * ability.damage
				if enemy.stats.isBoss then
					amount *= 1 + ability.bossBonus
				end
				if H.hit(player, enemy, amount, ability.id) then
					hits += 1
				end
				-- Казнь: не боссы и не объекты ниже порога здоровья.
				if enemy.alive and not enemy.stats.isBoss and not isObject(enemy)
					and enemy.health / math.max(1, enemy.maxHealth) < ability.executeBelow then
					table.insert(erased, enemy.model)
					H.fx({ kind = "chron", phase = "erased", caster = player, model = enemy.model, position = enemy.position })
					EnemyService.kill(enemy, player)
				end
			end
		end
		DebugState.set("Ability", "LastHits", hits)
		H.fx({ kind = "chron", phase = "eraseSwing", caster = player, position = origin, direction = direction, radius = ability.radius, halfAngle = ability.halfAngle, erased = #erased })
	end)
	return { ok = true }
end

-- ===== Эхо-удар (для «Вспомнить» и «Послеобраза») =====
-- Конус удара из произвольной точки; onMeleeHit не вызывается (эхо не копит пассивки).
local function echoSwing(player, origin: Vector3, forward: Vector3, range: number, arc: number, damage: number, source: string)
	local hits = 0
	for _, enemy in ipairs(H.enemiesInCone(origin, forward, range, arc / 2)) do
		if enemy.alive and H.hit(player, enemy, damage, source) then
			hits += 1
		end
	end
	return hits
end

-- ===== Вспомнить =====

local function castRecall(player, weapon, ability, root)
	H.setCasting(player, ability.castTime)
	local t = H.now()
	local swings = {}
	for _, swing in ipairs(memory[player] or {}) do
		if t - swing.t <= ability.memory then
			table.insert(swings, swing)
		end
	end
	while #swings > ability.maxSwings do
		table.remove(swings, 1)
	end
	-- Переделка 07.11.2026: память короче minSwings — двойники добивают полной серией
	-- (удар, удар, финал ×1,3), так способность сильна и сразу, без разгона.
	local power = H.power(player, weapon)
	local minSwings = ability.minSwings or 1
	local combo = (#swings > 0 and swings[#swings].combo or 0)
	while #swings < minSwings do
		combo = combo % H.comboLength + 1
		local finisher = combo == H.comboLength
		table.insert(swings, { t = t, range = 7, arc = 120, damage = power * (finisher and 1.3 or 1), combo = combo })
	end

	task.delay(ability.summonAt, function()
		if not H.rootOf(player) then
			return
		end
		local count = #swings
		player:SetAttribute("RecallUntil", H.now() + ability.replayStart + ability.replayGap * count + 0.4)
		local combos = {}
		for i, swing in ipairs(swings) do
			combos[i] = swing.combo
		end
		H.fx({
			kind = "chron",
			phase = "recallSummon",
			caster = player,
			echoes = ability.echoes,
			offset = ability.echoOffset,
			start = ability.replayStart,
			gap = ability.replayGap,
			combos = combos,
		})
		local total = 0
		for i, swing in ipairs(swings) do
			task.delay(ability.replayStart + ability.replayGap * (i - 1), function()
				local current = H.rootOf(player)
				if not current then
					return
				end
				local look = H.lookOf(current)
				local right = look:Cross(Vector3.yAxis).Unit
				local feet = feetOf(current)
				for e = 1, ability.echoes do
					local side = (e % 2 == 1) and -1 or 1
					local origin = feet + right * (side * ability.echoOffset) - look * 0.8
					total += echoSwing(player, origin, look, swing.range, swing.arc, swing.damage * ability.replayScale, ability.id)
				end
				H.fx({ kind = "chron", phase = "recallSwing", caster = player, index = i, combo = swing.combo })
				if i == count then
					DebugState.set("Ability", "LastHits", total)
				end
			end)
		end
		-- Финал «Сшивка»: двойники рывком крест-накрест сквозь врагов впереди, взрыв памяти в точке встречи.
		if ability.dashLength then
			local finaleAt = ability.replayStart + ability.replayGap * count + (ability.finaleGap or 0.3)
			player:SetAttribute("RecallUntil", H.now() + finaleAt + ability.dashTime + 0.6)
			task.delay(finaleAt, function()
				local current = H.rootOf(player)
				if not current then
					return
				end
				local look = H.lookOf(current)
				local right = look:Cross(Vector3.yAxis).Unit
				local feet = feetOf(current)
				local meet = feet + look * ability.burstAhead
				local dashes = {}
				for side = -1, 1, 2 do
					local from = feet + right * (side * ability.echoOffset) - look * 0.8
					local dir = (meet + right * (-side * ability.dashLength * 0.35) - from)
					dir = Vector3.new(dir.X, 0, dir.Z).Unit
					table.insert(dashes, { from = from, dir = dir, length = ability.dashLength })
				end
				H.fx({ kind = "v2", phase = "recallStitch", caster = player, dashes = dashes, meet = meet, time = ability.dashTime, radius = ability.burstRadius })
				local struck = {}
				for _, dash in ipairs(dashes) do
					for _, enemy in ipairs(H.enemiesOnSegment(dash.from, dash.dir, dash.length, ability.dashHalfWidth)) do
						if enemy.alive then
							struck[enemy] = (struck[enemy] or 0) + 1
							H.hit(player, enemy, power * ability.dashDamage, ability.id)
						end
					end
				end
				task.delay(ability.dashTime, function()
					for _, enemy in ipairs(H.enemiesInRadius(meet, ability.burstRadius)) do
						if enemy.alive then
							H.hit(player, enemy, power * ability.burstDamage, ability.id, { crit = true })
						end
					end
				end)
			end)
		end
	end)
	return { ok = true }
end

-- ===== Удар героя: память и «Послеобраз» =====
-- MeleeService.swingHooks: (player, origin, forward, range, arc, damage, combo) после урона по целям.
-- Ничего не ломает и всегда возвращает 0 (счётчик попаданий по разрушаемым).
local function swingHook(player, origin: Vector3, forward: Vector3, range: number, arc: number, damage: number, combo: number)
	local weapon = equipped(player)
	if not weapon or weapon.id ~= "memory_blade" then
		memory[player] = nil
		return 0
	end
	local t = H.now()
	local list = memory[player] or {}
	memory[player] = list
	table.insert(list, { t = t, forward = forward, range = range, arc = arc, damage = damage, combo = combo })
	local ability = Loot.Abilities.recall
	while #list > 0 and (t - list[1].t > ability.memory or #list > ability.maxSwings) do
		table.remove(list, 1)
	end

	local _, passive = Loot.abilityOf(weapon)
	local state = afterimage[player]
	if passive and passive.id == "afterimage" and state and state.hitT and t - state.hitT < 0.05 then
		state.hitT = nil
		state.count += 1
		if state.count >= passive.every then
			state.count = 0
			local feet = origin - Vector3.new(0, H.FEET, 0)
			H.fx({ kind = "chron", phase = "afterimage", caster = player, position = feet, direction = forward, combo = combo, delay = passive.delay })
			task.delay(passive.delay, function()
				if H.rootOf(player) then
					echoSwing(player, feet, forward, range, arc, damage * passive.damage, "afterimage")
				end
			end)
		end
	end
	return 0
end

-- ===== Пассивки на ударе =====

local function onMeleeHit(player, weapon, enemy, combo: number, baseDamage: number)
	local t = H.now()

	-- Купол «Безвременья»: удары по врагам внутри — эхо.
	local dome = domes[player]
	if dome and dome.untilT > t and enemy.alive and H.flat(enemy.position - dome.center).Magnitude <= dome.radius + enemy.stats.radius then
		H.hit(player, enemy, baseDamage * dome.echo, "timeless")
		H.fx({ kind = "chron", phase = "timeEcho", caster = player, model = enemy.model, position = enemy.position })
	end

	local _, passive = Loot.abilityOf(weapon)
	if not passive then
		return
	end

	if passive.id == "sand" then
		local last = sandSwing[player]
		if not last or t - last > 0.1 then
			sandSwing[player] = t
			local amount = passive.perHit + (combo == H.comboLength and passive.perFinisher or 0)
			H.reduceCooldown(player, "timeless", amount)
		end
	elseif passive.id == "ink_stain" then
		if not enemy.alive or isObject(enemy) then
			return
		end
		enemy.inkStains = enemy.inkStains or {}
		local mark = enemy.inkStains[player]
		if not mark or t > mark.untilT then
			mark = { count = 0, untilT = 0 }
		end
		mark.count = math.min(passive.maxStains, mark.count + 1)
		mark.untilT = t + passive.stainTime
		enemy.inkStains[player] = mark
		enemy.model:SetAttribute("InkStains", mark.count)
		enemy.model:SetAttribute("InkStainsUntil", mark.untilT)
		H.fx({ kind = "chron", phase = "inkStain", caster = player, model = enemy.model, count = mark.count })
	elseif passive.id == "oblivion" then
		if combo ~= H.comboLength or not enemy.alive or isObject(enemy) then
			return
		end
		EnemyService.breakArmor(enemy, passive.armorBreak, passive.armorBreakDuration)
		EnemyService.setVulnerable(enemy, passive.vulnerable, passive.vulnerableTime)
		H.fx({ kind = "chron", phase = "oblivionMark", caster = player, model = enemy.model, position = enemy.position })
	elseif passive.id == "afterimage" then
		-- Отметка «этот взмах попал»: счёт ведёт swingHook (он вызывается после урона по целям).
		local state = afterimage[player] or { count = 0 }
		afterimage[player] = state
		state.hitT = t
	end
end

Players.PlayerRemoving:Connect(function(player)
	domes[player] = nil
	memory[player] = nil
	afterimage[player] = nil
	sandSwing[player] = nil
end)

function WeaponAbilitiesChronicle.install(helpers)
	H = helpers
	return {
		casts = {
			inscribe = castInscribe,
			seal_time = castSeal,
			timeless = castTimeless,
			ink_splash = castInkSplash,
			erase = castErase,
			recall = castRecall,
		},
		onMeleeHit = onMeleeHit,
		swingHook = swingHook,
	}
end

return WeaponAbilitiesChronicle
