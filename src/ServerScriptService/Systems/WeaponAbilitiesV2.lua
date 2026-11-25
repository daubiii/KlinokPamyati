--!nonstrict
-- WeaponAbilitiesV2 (сервер) — переделанные способности мечей и молотов (07.11.2026, концепты одобрены
-- Артёмом: документ «Способности оружия — переделка»). Подключается в WeaponAbilities ПОСЛЕ модулей
-- этажей и заменяет их касты с теми же id. Числа — Config.LootWeaponsV2 (поверх LootFloor2–5).
-- Клиент рисует по AbilityFx kind = "v2" (Controllers/AbilityFxV2).
--
--   С нуля:     erase «Забвение», forge_breath «Горнило», pour «Первая отливка», dive «Соколиная охота»;
--   Доработка:  flood «Прилив», prune «Обрезка» (лозы + «чик»), last_hunt «Последний гон» (гон по меткам),
--               slag_reap «Шлаковый смерч», inscribe «Строка» крестом, ink_splash «Чернильный прилив»,
--               spill (струя металла поверх старого каста), overheat (+ финал-взрыв).
--   «Вспомнить» Клинка Памяти — в WeaponAbilitiesChronicle (там память ударов).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loot = require(Shared.Config.Loot)
local DebugState = require(Shared.Net.DebugState)

local EnemyService = require(script.Parent.EnemyService)

local WeaponAbilitiesV2 = {}

local H -- помощники WeaponAbilities
local M -- модули этажей: { Garden, Forge, Hunt, Chronicle, old = старые касты }

local burningBlade = {} -- [player] = untilT («Горнило»)
local falconHunts = {} -- [player] = { untilT, dives, nextT, weapon, power }
local swingGuard = {} -- [player] = { [ключ] = время } — одно срабатывание на взмах

local V3 = Vector3.new

local function isObject(enemy): boolean
	return enemy.stats.role == "object"
end

local function feetOf(root): Vector3
	return root.Position - V3(0, H.FEET, 0)
end

local function fx(payload)
	payload.kind = "v2"
	H.fx(payload)
end

local function rotate(dir: Vector3, degrees: number): Vector3
	local r = math.rad(degrees)
	local c, s = math.cos(r), math.sin(r)
	return V3(dir.X * c - dir.Z * s, 0, dir.X * s + dir.Z * c)
end

local function once(player, key: string, gap: number): boolean
	local t = H.now()
	local store = swingGuard[player] or {}
	swingGuard[player] = store
	if store[key] and t - store[key] < gap then
		return false
	end
	store[key] = t
	return true
end

-- Зона на земле: каждые tick секунд fn(enemy) для врагов в круге; живёт time секунд.
local function zone(center: Vector3, radius: number, time: number, tick: number, fn)
	task.spawn(function()
		local untilT = H.now() + time
		while H.now() < untilT do
			for _, enemy in ipairs(H.enemiesInRadius(center, radius)) do
				if enemy.alive then
					fn(enemy)
				end
			end
			task.wait(tick)
		end
	end)
end

-- ===================== С НУЛЯ =====================

-- ===== Коса Забвения: «Забвение» =====
local function castErase(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)
	task.delay(ability.drawAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local center = feetOf(current)
		fx({ phase = "eraseField", caster = player, position = center, radius = ability.radius, duration = ability.fieldTime })
		local ticks = math.floor(ability.fieldTime / ability.tick + 0.5)
		for i = 1, ticks do
			task.delay(i * ability.tick, function()
				for _, enemy in ipairs(H.enemiesInRadius(center, ability.radius)) do
					if enemy.alive then
						if not isObject(enemy) then
							EnemyService.slow(enemy, ability.slow, ability.tick + 0.15)
							local share = 1 - (enemy.health / math.max(1, enemy.maxHealth))
							enemy.model:SetAttribute("EraseFade", math.clamp(i / ticks, 0, 1) * 0.6 + share * 0.2)
						end
						H.hit(player, enemy, power * ability.tickDamage, ability.id, { dot = true })
					end
				end
			end)
		end
		task.delay(ability.fieldTime + 0.05, function()
			local erased = {}
			local hits = 0
			for _, enemy in ipairs(H.enemiesInRadius(center, ability.radius)) do
				if enemy.alive then
					local amount = power * ability.finalDamage
					if enemy.stats.isBoss then
						amount *= 1 + ability.bossBonus
					end
					if H.hit(player, enemy, amount, ability.id, { crit = true }) then
						hits += 1
					end
					if enemy.alive and enemy.model then
						enemy.model:SetAttribute("EraseFade", nil)
					end
					if enemy.alive and not enemy.stats.isBoss and not isObject(enemy)
						and enemy.health / math.max(1, enemy.maxHealth) < ability.executeBelow then
						table.insert(erased, { model = enemy.model, position = enemy.position })
						EnemyService.kill(enemy, player)
					end
				end
			end
			DebugState.set("Ability", "LastHits", hits)
			fx({ phase = "eraseFinal", caster = player, position = center, radius = ability.radius, erased = erased })
		end)
	end)
	return { ok = true, radius = ability.radius }
end

-- ===== Клинок горна: «Горнило» =====
local function castForgeHeart(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)
	task.delay(ability.plungeAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local origin = feetOf(current)
		local look = H.lookOf(current)
		local fissures = {}
		for i = 1, ability.fissures do
			local angle = -ability.fan / 2 + ability.fan * (i - 1) / math.max(1, ability.fissures - 1)
			local dir = rotate(look, angle)
			table.insert(fissures, { dir = dir, length = H.clearLength(origin, dir, ability.length) })
		end
		fx({ phase = "heartPlunge", caster = player, position = origin, fissures = fissures, eruptIn = ability.eruptAt - ability.plungeAt, gap = ability.eruptGap })
		local struck = {}
		for i, f in ipairs(fissures) do
			task.delay(ability.eruptAt - ability.plungeAt + (i - 1) * ability.eruptGap, function()
				fx({ phase = "heartErupt", caster = player, position = origin, direction = f.dir, length = f.length, index = i })
				for _, enemy in ipairs(H.enemiesOnSegment(origin, f.dir, f.length, ability.halfWidth)) do
					if enemy.alive and not struck[enemy] then
						struck[enemy] = true
						H.hit(player, enemy, power * ability.eruptDamage, ability.id)
						if enemy.alive then
							EnemyService.launch(enemy, ability.launchHeight, ability.launchTime)
						end
					end
				end
			end)
		end
		task.delay(ability.eruptAt - ability.plungeAt + ability.fissures * ability.eruptGap, function()
			if not H.rootOf(player) then
				return
			end
			local untilT = H.now() + ability.bladeTime
			burningBlade[player] = untilT
			player:SetAttribute("BurningBladeUntil", untilT)
			fx({ phase = "heartBlade", caster = player, duration = ability.bladeTime })
		end)
	end)
	return { ok = true, radius = ability.length }
end

-- ===== Незавершённая отливка: «Первая отливка» =====
local function castFirstCast(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)
	local state = M.Forge.castingState and M.Forge.castingState(player) or { stage = 0, metal = 0 }
	local stage = state.stage or 0
	local bonus = 1 + ability.stageBonus * stage
	local origin = feetOf(root)
	local look = H.lookOf(root)
	fx({ phase = "pourRaise", caster = player, position = origin, stage = stage, until_ = ability.cleaveAt })

	local struck = {}
	for i, radius in ipairs(ability.rings) do
		task.delay(ability.ringAt + (i - 1) * ability.ringGap, function()
			local current = H.rootOf(player)
			if not current then
				return
			end
			local center = feetOf(current)
			fx({ phase = "pourRing", caster = player, position = center, radius = radius, index = i })
			struck[i] = {}
			for _, enemy in ipairs(H.enemiesInRadius(center, radius)) do
				-- кольцо бьёт тех, кого не задело прошлое кольцо (волна расходится)
				if enemy.alive and not (struck[i - 1] and struck[i - 1][enemy]) then
					struck[i][enemy] = true
					H.hit(player, enemy, power * ability.ringDamage, ability.id)
				end
			end
		end)
	end

	task.delay(ability.cleaveAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		origin = feetOf(current)
		look = H.lookOf(current)
		local length = H.clearLength(origin, look, ability.cleaveLength)
		fx({ phase = "pourCleave", caster = player, position = origin, direction = look, length = length, stage = stage })
		local hits = 0
		for _, enemy in ipairs(H.enemiesOnSegment(origin, look, length, ability.cleaveHalfWidth)) do
			if enemy.alive then
				if H.hit(player, enemy, power * ability.cleaveDamage * bonus, ability.id, { crit = true }) then
					hits += 1
				end
				if enemy.alive then
					EnemyService.launch(enemy, ability.launchHeight, ability.launchTime)
				end
			end
		end
		DebugState.set("Ability", "LastHits", hits)
	end)

	task.delay(ability.steamAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local center = feetOf(current) + H.lookOf(current) * 4
		fx({ phase = "pourSteam", caster = player, position = center, radius = ability.steamRadius })
		for _, enemy in ipairs(H.enemiesInRadius(center, ability.steamRadius)) do
			if enemy.alive then
				H.hit(player, enemy, power * ability.steamDamage * bonus, ability.id)
			end
		end
		-- ступени отливки сгорают
		if M.Forge.setStage and M.Forge.castingState then
			local s = M.Forge.castingState(player)
			s.metal = 0
			M.Forge.setStage(player, s)
		end
	end)
	return { ok = true, radius = ability.steamRadius }
end

-- ===== Клинок сокольничего: «Соколиная охота» =====
local function falconDive(player, enemyPosition: Vector3, radius: number, damage: number, final: boolean)
	local hunt = falconHunts[player]
	if not hunt then
		return
	end
	local ability = Loot.Abilities.dive
	fx({ phase = "falconDive", caster = player, position = enemyPosition, radius = radius, final = final, time = ability.diveTime })
	task.delay(ability.diveTime, function()
		local hits = 0
		for _, enemy in ipairs(H.enemiesInRadius(enemyPosition, radius)) do
			if enemy.alive then
				if H.hit(player, enemy, hunt.power * damage, "dive", { crit = final }) then
					hits += 1
				end
				if enemy.alive then
					EnemyService.launch(enemy, ability.launchHeight * (final and 1.2 or 1), ability.launchTime)
				end
			end
		end
		DebugState.set("Ability", "LastHits", hits)
	end)
end

local function finishFalcon(player)
	local hunt = falconHunts[player]
	if not hunt or hunt.finished then
		return
	end
	hunt.finished = true
	local ability = Loot.Abilities.dive
	local root = H.rootOf(player)
	local best
	if root then
		local feet = feetOf(root)
		local bestScore = -1
		for _, enemy in ipairs(H.enemiesInRadius(feet, ability.finalRange)) do
			if enemy.alive and not isObject(enemy) then
				local score = (enemy.stats.isBoss and 1e6 or 0) + (enemy.maxHealth or 0)
				if score > bestScore then
					bestScore = score
					best = enemy
				end
			end
		end
	end
	if best then
		falconDive(player, best.position, ability.finalRadius, ability.finalDamage, true)
	else
		fx({ phase = "falconLeave", caster = player })
	end
	task.delay(ability.diveTime + 0.6, function()
		if falconHunts[player] == hunt then
			falconHunts[player] = nil
			player:SetAttribute("FalconHuntUntil", nil)
		end
	end)
end

local function castFalconHunt(player, weapon, ability, root)
	H.setCasting(player, ability.castTime)
	local hunt = { untilT = H.now() + ability.callAt + ability.huntTime, dives = 0, nextT = 0, power = H.power(player, weapon) }
	falconHunts[player] = hunt
	task.delay(ability.callAt, function()
		if falconHunts[player] ~= hunt or not H.rootOf(player) then
			return
		end
		player:SetAttribute("FalconHuntUntil", hunt.untilT)
		fx({ phase = "falconCall", caster = player, duration = ability.huntTime })
	end)
	task.delay(ability.callAt + ability.huntTime, function()
		if falconHunts[player] == hunt then
			finishFalcon(player)
		end
	end)
	return { ok = true }
end

-- ===================== ДОРАБОТКА =====================

-- ===== Приливный молот: «Прилив» =====
local function castTide(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)
	task.delay(ability.slamAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local origin = feetOf(current)
		local dir = H.lookOf(current)
		local length = H.clearLength(origin, dir, ability.waveLength)
		fx({ phase = "tideWave", caster = player, position = origin, direction = dir, length = length, width = ability.waveHalfWidth * 2, time = ability.waveTime })
		local struck = {}
		local steps = 6
		for i = 1, steps do
			task.delay(ability.waveTime * (i - 1) / steps, function()
				local reach = length * i / steps
				for _, enemy in ipairs(H.enemiesOnSegment(origin, dir, reach, ability.waveHalfWidth)) do
					if enemy.alive and not struck[enemy] then
						struck[enemy] = true
						H.hit(player, enemy, power * ability.waveDamage, ability.id)
						if enemy.alive then
							EnemyService.shove(enemy, dir, ability.push * (1 - (i - 1) / steps * 0.5), 0.35)
						end
					end
				end
			end)
		end
		task.delay(ability.waveTime, function()
			local center = origin + dir * length
			fx({ phase = "tideCrash", caster = player, position = center, radius = ability.puddleRadius, time = ability.puddleTime })
			zone(center, ability.puddleRadius, ability.puddleTime, ability.puddleTick, function(enemy)
				if not isObject(enemy) then
					EnemyService.slow(enemy, ability.slow, ability.puddleTick + 0.2)
					EnemyService.setVulnerable(enemy, ability.soaked, ability.puddleTick + 0.2)
				end
				H.hit(player, enemy, power * ability.puddleDamage, ability.id, { dot = true })
			end)
		end)
	end)
	return { ok = true }
end

-- ===== Секатор Садовницы: «Обрезка» (срезы → лозы → «чик») =====
local function castPrune(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)
	local cut = {} -- задетые срезами
	for index, at in ipairs(ability.cuts) do
		task.delay(at, function()
			local current = H.rootOf(player)
			if not current then
				return
			end
			local origin = feetOf(current)
			local dir = H.lookOf(current)
			fx({ phase = "pruneCut", caster = player, position = origin, direction = dir, radius = ability.radius, index = index })
			for _, enemy in ipairs(H.enemiesInCone(origin, dir, ability.radius, ability.halfAngle)) do
				if enemy.alive then
					H.hit(player, enemy, power * ability.cutDamage, ability.id)
					if enemy.alive and not isObject(enemy) then
						cut[enemy] = true
						EnemyService.breakArmor(enemy, ability.armorBreak, ability.armorBreakDuration)
						EnemyService.setVulnerable(enemy, ability.vulnerable, ability.vulnerableTime)
					end
				end
			end
		end)
	end
	task.delay(ability.vineAt, function()
		local models = {}
		for enemy in pairs(cut) do
			if enemy.alive then
				EnemyService.stun(enemy, enemy.stats.isBoss and ability.bossVineTime or ability.vineTime)
				table.insert(models, enemy.model)
			end
		end
		fx({ phase = "pruneVines", caster = player, targets = models, time = ability.snipAt - ability.vineAt })
	end)
	task.delay(ability.snipAt, function()
		local models = {}
		for enemy in pairs(cut) do
			if enemy.alive then
				table.insert(models, { model = enemy.model, position = enemy.position })
				H.hit(player, enemy, power * ability.snipDamage, ability.id, { crit = true })
				-- +2 шипа к «Цветению» (пассивка Секатора)
				if enemy.alive and M.Garden and M.Garden.onMeleeHit then
					for _ = 1, ability.blooms do
						pcall(M.Garden.onMeleeHit, player, weapon, enemy, 0, power)
					end
				end
			end
		end
		fx({ phase = "pruneSnip", caster = player, targets = models })
	end)
	return { ok = true, radius = ability.radius }
end

-- ===== Коса ловчего: «Последний гон» =====
local function castLastHunt(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)
	local origin = feetOf(root)
	-- добыча: ближайшие враги в радиусе рога
	local candidates = {}
	for _, enemy in ipairs(H.enemiesInRadius(origin, ability.hornRadius)) do
		if enemy.alive and not isObject(enemy) then
			table.insert(candidates, { enemy = enemy, d = H.flat(enemy.position - origin).Magnitude })
		end
	end
	table.sort(candidates, function(a, b)
		return a.d < b.d
	end)
	local prey = {}
	for i = 1, math.min(ability.targets, #candidates) do
		table.insert(prey, candidates[i].enemy)
	end

	if #prey == 0 then
		-- нет добычи: обычный рывок вперёд, урон по полосе
		local dir = H.lookOf(root)
		local length = H.clearLength(origin, dir, ability.dashDistance)
		fx({ phase = "huntDash", caster = player, position = origin, direction = dir, length = length })
		task.delay(ability.hornAt, function()
			for _, enemy in ipairs(H.enemiesOnSegment(origin, dir, length, ability.halfWidth)) do
				if enemy.alive then
					H.hit(player, enemy, power * ability.hopDamage, ability.id)
				end
			end
		end)
		return {
			ok = true,
			move = { direction = dir, distance = length, time = ability.hopTime, delay = ability.hornAt },
		}
	end

	-- путь: от героя к добыче по ближайшей следующей
	local path = {}
	local from = origin
	local left = table.clone(prey)
	while #left > 0 do
		local bestI, bestD = 1, math.huge
		for i, enemy in ipairs(left) do
			local d = H.flat(enemy.position - from).Magnitude
			if d < bestD then
				bestI, bestD = i, d
			end
		end
		local enemy = table.remove(left, bestI)
		local rel = H.flat(enemy.position - from)
		local dir = rel.Magnitude > 0.1 and rel.Unit or H.lookOf(root)
		-- проскочить сквозь цель на 2 стада
		local to = V3(enemy.position.X, from.Y, enemy.position.Z) + dir * 2
		table.insert(path, { enemy = enemy, from = from, to = to })
		from = to
	end

	local models = {}
	for _, enemy in ipairs(prey) do
		table.insert(models, enemy.model)
		enemy.model:SetAttribute("PreyMarkUntil", H.now() + 3)
		enemy.model:SetAttribute("PreyMarkBy", player.UserId)
	end
	local hops = {}
	for _, hop in ipairs(path) do
		table.insert(hops, { from = hop.from, to = hop.to })
	end
	fx({ phase = "huntHorn", caster = player, position = origin, radius = ability.hornRadius, targets = models, hops = hops,
		start = ability.hornAt, hopTime = ability.hopTime, hopGap = ability.hopGap })
	H.setCasting(player, ability.hornAt + #path * (ability.hopTime + ability.hopGap) + 0.3)

	for i, hop in ipairs(path) do
		task.delay(ability.hornAt + (i - 1) * (ability.hopTime + ability.hopGap) + ability.hopTime * 0.8, function()
			if not H.rootOf(player) then
				return
			end
			local enemy = hop.enemy
			if enemy.alive then
				H.hit(player, enemy, power * ability.hopDamage * (1 + ability.preyBonus), ability.id, { crit = true })
			end
			-- задеть и тех, кто на пути
			local seg = hop.to - hop.from
			if seg.Magnitude > 0.5 then
				for _, other in ipairs(H.enemiesOnSegment(hop.from, seg.Unit, seg.Magnitude, ability.halfWidth * 0.6)) do
					if other ~= enemy and other.alive then
						H.hit(player, other, power * ability.hopDamage * 0.5, ability.id)
					end
				end
			end
			fx({ phase = "huntHop", caster = player, position = hop.to, model = enemy.model, index = i })
		end)
	end
	local finaleAt = ability.hornAt + #path * (ability.hopTime + ability.hopGap) + 0.05
	task.delay(finaleAt, function()
		local last = path[#path].to
		fx({ phase = "huntFinale", caster = player, position = last, radius = ability.finaleRadius })
		for _, enemy in ipairs(H.enemiesInRadius(last, ability.finaleRadius)) do
			if enemy.alive then
				H.hit(player, enemy, power * ability.finaleDamage, ability.id)
				if enemy.alive then
					EnemyService.slow(enemy, ability.slow, ability.slowTime)
				end
			end
		end
		for _, enemy in ipairs(prey) do
			if enemy.alive and enemy.model then
				enemy.model:SetAttribute("PreyMarkUntil", nil)
			end
		end
	end)
	return { ok = true, radius = ability.hornRadius }
end

-- ===== Шлаковая коса: «Шлаковый смерч» =====
local function castSlagCyclone(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)
	fx({ phase = "slagCyclone", caster = player, duration = ability.spinTime, radius = ability.radius, start = ability.spinStart })
	local gap = ability.spinTime / ability.spins
	for i = 1, ability.spins do
		task.delay(ability.spinStart + (i - 1) * gap, function()
			local current = H.rootOf(player)
			if not current then
				return
			end
			local center = feetOf(current)
			for _, enemy in ipairs(H.enemiesInRadius(center, ability.radius)) do
				if enemy.alive then
					H.hit(player, enemy, power * ability.spinDamage, ability.id)
				end
			end
			-- комья шлака: падают вокруг и застывают лужами
			local points = {}
			for g = 1, ability.globsPerSpin do
				local angle = math.random() * math.pi * 2
				local r = ability.globDistance * (0.6 + math.random() * 0.4)
				table.insert(points, center + V3(math.cos(angle) * r, 0, math.sin(angle) * r))
			end
			fx({ phase = "slagGlobs", caster = player, position = center, points = points, flight = ability.globFlight, radius = ability.globRadius, time = ability.globTime, index = i })
			task.delay(ability.globFlight, function()
				for _, point in ipairs(points) do
					zone(point, ability.globRadius, ability.globTime, ability.globTick, function(enemy)
						if not isObject(enemy) then
							EnemyService.slow(enemy, ability.slow, ability.slowTime)
						end
						H.hit(player, enemy, power * ability.globDamage, ability.id, { dot = true })
					end)
				end
			end)
		end)
	end
	task.delay(ability.slamAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local center = feetOf(current)
		fx({ phase = "slagSlam", caster = player, position = center, radius = ability.slamRadius })
		local hits = 0
		for _, enemy in ipairs(H.enemiesInRadius(center, ability.slamRadius)) do
			if enemy.alive then
				if H.hit(player, enemy, power * ability.slamDamage, ability.id, { crit = true }) then
					hits += 1
				end
				if enemy.alive and not isObject(enemy) then
					EnemyService.breakArmor(enemy, ability.armorBreak, ability.armorBreakDuration)
					EnemyService.launch(enemy, ability.launchHeight, ability.launchTime)
				end
			end
		end
		DebugState.set("Ability", "LastHits", hits)
	end)
	return { ok = true, radius = ability.radius }
end

-- ===== Перо хрониста: «Строка» крестом =====
local function castInscribeCross(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)
	task.delay(ability.writeAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local feet = feetOf(current)
		local look = H.lookOf(current)
		local center = feet + look * H.clearLength(feet, look, ability.crossAhead)
		local lines = {}
		for _, angle in ipairs({ ability.crossAngle, -ability.crossAngle }) do
			local dir = rotate(look, angle)
			local half = ability.length / 2
			local from = center - dir * half
			local runes = {}
			for r = 1, ability.runes do
				table.insert(runes, from + dir * (ability.length * (r - 0.5) / ability.runes))
			end
			table.insert(lines, { from = from, dir = dir, length = ability.length, runes = runes })
		end
		fx({ phase = "quillWrite", caster = player, lines = lines, center = center, writeTime = ability.writeTime, detonateDelay = ability.detonateDelay, interval = ability.runeInterval })
		local struck = {}
		local hits = 0
		local step = ability.length / ability.runes
		for li, line in ipairs(lines) do
			for r = 1, ability.runes do
				task.delay(ability.writeTime + ability.detonateDelay + (r - 1) * ability.runeInterval + (li - 1) * 0.03, function()
					local point = line.runes[r]
					for _, enemy in ipairs(H.enemiesOnSegment(point - line.dir * step / 2, line.dir, step, ability.halfWidth)) do
						if enemy.alive and not struck[enemy] then
							struck[enemy] = true
							if H.hit(player, enemy, power * ability.damage, ability.id) then
								hits += 1
							end
							if enemy.alive then
								EnemyService.stun(enemy, ability.stun)
							end
						end
					end
				end)
			end
		end
		task.delay(ability.writeTime + ability.detonateDelay + ability.runes * ability.runeInterval + 0.1, function()
			fx({ phase = "quillCenter", caster = player, position = center, radius = ability.centerRadius })
			for _, enemy in ipairs(H.enemiesInRadius(center, ability.centerRadius)) do
				if enemy.alive then
					H.hit(player, enemy, power * ability.centerDamage, ability.id, { crit = true })
				end
			end
			DebugState.set("Ability", "LastHits", hits)
		end)
	end)
	return { ok = true }
end

-- ===== Чернильный клинок: «Чернильный прилив» =====
local function stainsOf(player, enemy): number
	local mark = enemy.inkStains and enemy.inkStains[player]
	if not mark or H.now() > mark.untilT then
		return 0
	end
	return mark.count
end

local function addStain(player, enemy)
	local passive = Loot.Passives.ink_stain
	enemy.inkStains = enemy.inkStains or {}
	local mark = enemy.inkStains[player]
	if not mark or H.now() > mark.untilT then
		mark = { count = 0, untilT = 0 }
	end
	mark.count = math.min(passive and passive.maxStains or 4, mark.count + 1)
	mark.untilT = H.now() + (passive and passive.stainTime or 6)
	enemy.inkStains[player] = mark
	enemy.model:SetAttribute("InkStains", mark.count)
	enemy.model:SetAttribute("InkStainsUntil", mark.untilT)
end

local function castInkTide(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)
	local point
	task.delay(ability.splashAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local origin = feetOf(current)
		local dir = H.lookOf(current)
		point = origin + dir * H.clearLength(origin, dir, ability.pullAhead)
		fx({ phase = "inkFan", caster = player, position = origin, direction = dir, radius = ability.radius, halfAngle = ability.halfAngle })
		for _, enemy in ipairs(H.enemiesInCone(origin, dir, ability.radius, ability.halfAngle)) do
			if enemy.alive then
				H.hit(player, enemy, power * ability.damage, ability.id)
				if enemy.alive and not isObject(enemy) then
					addStain(player, enemy)
				end
			end
		end
	end)
	local pulled = {}
	task.delay(ability.pullAt, function()
		if not point or not H.rootOf(player) then
			return
		end
		local models = {}
		for _, enemy in ipairs(H.enemiesInRadius(point, ability.pullRadius)) do
			if enemy.alive and not isObject(enemy) and stainsOf(player, enemy) > 0 then
				local rel = H.flat(point - enemy.position)
				if rel.Magnitude > 1 then
					EnemyService.shove(enemy, rel.Unit, math.max(0, rel.Magnitude - 1.5), ability.pullTime)
				end
				table.insert(pulled, enemy)
				table.insert(models, enemy.model)
			end
		end
		fx({ phase = "inkPull", caster = player, position = point, targets = models, time = ability.pullTime })
	end)
	task.delay(ability.burstAt, function()
		if not point then
			return
		end
		fx({ phase = "inkBurst", caster = player, position = point, radius = ability.burstRadius })
		local hits = 0
		for _, enemy in ipairs(H.enemiesInRadius(point, ability.burstRadius)) do
			if enemy.alive then
				local stains = stainsOf(player, enemy)
				if enemy.inkStains then
					enemy.inkStains[player] = nil
				end
				enemy.model:SetAttribute("InkStains", 0)
				if H.hit(player, enemy, power * (ability.burstDamage + ability.perStain * stains), ability.id, { crit = stains >= 3 }) then
					hits += 1
				end
				if enemy.alive and not isObject(enemy) then
					EnemyService.slow(enemy, ability.slow, ability.slowTime)
				end
			end
		end
		DebugState.set("Ability", "LastHits", hits)
	end)
	return { ok = true, radius = ability.radius }
end

-- ===== Молот-тигель и Раскалённый клинок: поверх старых кастов =====
local function castSpillPlus(player, weapon, ability, root)
	local result = M.old.spill(player, weapon, ability, root)
	if result and result.ok then
		fx({ phase = "crucibleTip", caster = player, pourAt = ability.pourAt, time = 0.7 })
	end
	return result
end

local function castOverheatPlus(player, weapon, ability, root)
	local result = M.old.overheat(player, weapon, ability, root)
	if result and result.ok then
		task.delay(ability.novaAt or 0.2, function()
			fx({ phase = "searingBlade", caster = player, duration = ability.buffTime })
		end)
	end
	return result
end

-- ===================== ПАССИВНЫЕ ЧАСТИ (на ударе) =====================

local function onMeleeHit(player, weapon, enemy, combo: number, baseDamage: number)
	if not weapon then
		return
	end
	local t = H.now()

	-- «Горнило»: горящий клинок — по 2 угля на удар, финал серии — огненная дуга
	local burning = burningBlade[player]
	if burning and burning > t and weapon.id == "forge_heart_blade" then
		if M.Forge.addEmber and enemy.alive then
			pcall(M.Forge.addEmber, player, enemy, baseDamage)
		end
		if combo == H.comboLength and once(player, "fireArc", 0.4) then
			local root = H.rootOf(player)
			local ability = Loot.Abilities.forge_breath
			if root then
				local origin = feetOf(root)
				local dir = H.lookOf(root)
				local length = H.clearLength(origin, dir, ability.arcLength)
				fx({ phase = "heartArc", caster = player, position = origin, direction = dir, length = length })
				for _, other in ipairs(H.enemiesOnSegment(origin, dir, length, ability.arcHalfWidth)) do
					if other.alive then
						H.hit(player, other, H.power(player, weapon) * ability.arcDamage, "forge_breath")
					end
				end
			end
		end
	elseif burning and burning <= t then
		burningBlade[player] = nil
	end

	-- «Перекал»: финал серии во время перекала — большой взрыв
	if weapon.id == "searing_blade" and combo == H.comboLength and (player:GetAttribute("OverheatUntil") or 0) > t
		and once(player, "searingFinale", 0.4) then
		local ability = Loot.Abilities.overheat
		local center = enemy.position
		fx({ phase = "searingFinale", caster = player, position = center, radius = ability.finaleRadius })
		for _, other in ipairs(H.enemiesInRadius(center, ability.finaleRadius)) do
			if other.alive then
				H.hit(player, other, baseDamage * ability.finaleDamage, "overheat", { crit = true })
			end
		end
	end

	-- «Соколиная охота»: попадание посылает сокола в пике
	local hunt = falconHunts[player]
	if hunt and not hunt.finished and enemy.alive and t < hunt.untilT and t >= hunt.nextT then
		local ability = Loot.Abilities.dive
		hunt.dives += 1
		hunt.nextT = t + ability.diveGap
		falconDive(player, enemy.position, ability.diveRadius, ability.diveDamage, false)
		if hunt.dives >= ability.dives then
			task.delay(ability.diveTime + 0.3, function()
				finishFalcon(player)
			end)
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	burningBlade[player] = nil
	falconHunts[player] = nil
	swingGuard[player] = nil
end)

-- helpers — те же, что у модулей этажей 3–5; mods = { Garden, Forge, Hunt, Chronicle, old }.
function WeaponAbilitiesV2.install(helpers, mods)
	H = helpers
	M = mods
	return {
		casts = {
			erase = castErase,
			forge_breath = castForgeHeart,
			pour = castFirstCast,
			dive = castFalconHunt,
			flood = castTide,
			prune = castPrune,
			last_hunt = castLastHunt,
			slag_reap = castSlagCyclone,
			inscribe = castInscribeCross,
			ink_splash = castInkTide,
			spill = castSpillPlus,
			overheat = castOverheatPlus,
		},
		onMeleeHit = onMeleeHit,
	}
end

return WeaponAbilitiesV2
