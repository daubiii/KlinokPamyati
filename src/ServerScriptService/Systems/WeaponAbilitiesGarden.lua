--!nonstrict
-- WeaponAbilitiesGarden (сервер)
-- Способности и пассивка оружия этажа 2 «Затопленные сады» (воин, мечи и молоты):
--   Клинок жатвы     — «Жатва»: серповидная волна вперёд (пробивает), цели гниют;
--   Приливный молот  — «Паводок»: волна воды конусом с отбросом + разлив (замедление, урон);
--   Секатор Садовницы — «Обрезка»: два перекрёстных среза, −броня и уязвимость;
--                       пассивка «Цветение»: шипы на врагах, на 5-м распускается цветок.
-- Числа — Config.Loot (Abilities, Passives; туда их подмешивает Config.LootFloor2). Сервер решает, кто задет;
-- клиент (AbilityFxGarden) рисует по событию AbilityFx (kind = "garden").
-- Подключается из WeaponAbilities.lua одной вставкой (patches/floor2.patch): модуль получает
-- его помощников и отдаёт касты и хук удара. Враги: EnemyService (stun/slow/shove/applyDamage…).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loot = require(Shared.Config.Loot)
local FloorGeo = require(Shared.Floor.FloorGeo)
local DebugState = require(Shared.Net.DebugState)

local EnemyService = require(script.Parent.EnemyService)

local WeaponAbilitiesGarden = {}

local H -- помощники WeaponAbilities (см. install)

local function isObject(enemy): boolean
	return enemy.stats.role == "object"
end

-- Конец линии с учётом стен (как crackLength в «Разломе»).
local function clearLength(origin: Vector3, direction: Vector3, length: number): number
	local from = origin + Vector3.new(0, 1.2, 0)
	local result = FloorGeo.raycast(from, direction * length)
	if result then
		return math.max(1.5, H.flat(result.Position - from).Magnitude - 0.4)
	end
	return length
end

-- Враги в секторе: радиус и половина угла от направления direction.
local function enemiesInCone(origin: Vector3, direction: Vector3, radius: number, halfAngle: number)
	local list = {}
	local cosLimit = math.cos(math.rad(halfAngle))
	for _, enemy in ipairs(H.enemiesInRadius(origin, radius)) do
		local rel = H.flat(enemy.position - origin)
		if rel.Magnitude < 0.5 then
			table.insert(list, enemy)
		else
			-- Поправка на ширину врага: чем он толще, тем шире допуск по углу.
			local angle = math.acos(math.clamp(rel.Unit:Dot(direction), -1, 1))
			local slack = math.atan2(enemy.stats.radius, rel.Magnitude)
			if angle - slack <= math.rad(halfAngle) or rel.Unit:Dot(direction) >= cosLimit then
				table.insert(list, enemy)
			end
		end
	end
	return list
end

-- ===== Гниль (урон по времени) =====
-- Новая гниль заменяет старую (не складывается): перезапуск таймера.

local function applyRot(player, enemy, ability, power: number)
	if not enemy.alive or isObject(enemy) then
		return
	end
	enemy.rotId = (enemy.rotId or 0) + 1
	local id = enemy.rotId
	local total = ability.rotTicks * ability.rotInterval
	enemy.model:SetAttribute("Rot", H.now() + total)
	H.fx({ kind = "garden", phase = "rot", model = enemy.model, duration = total })
	task.spawn(function()
		for _ = 1, ability.rotTicks do
			task.wait(ability.rotInterval)
			if not enemy.alive or enemy.rotId ~= id then
				return
			end
			H.hit(player, enemy, power * ability.rotDamage, ability.id, { dot = true })
		end
		if enemy.rotId == id and enemy.model then
			enemy.model:SetAttribute("Rot", nil)
		end
	end)
end

-- ===== Жатва =====

local function castReap(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)

	task.delay(ability.releaseAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local origin = current.Position - Vector3.new(0, H.FEET, 0)
		local direction = H.lookOf(current)
		local length = clearLength(origin, direction, ability.waveRange)

		H.fx({
			kind = "garden",
			phase = "reapStart",
			caster = player,
			position = origin,
			direction = direction,
			length = length,
			waveTime = ability.waveTime,
		})

		-- Волна пробегает за waveTime: каждый враг на пути получает урон один раз, когда волна его достигла.
		local struck = {}
		local hits = 0
		local steps = 5
		for i = 1, steps do
			task.delay(ability.waveTime * i / steps, function()
				local reach = length * i / steps
				for _, enemy in ipairs(H.enemiesOnSegment(origin, direction, reach, ability.waveHalfWidth)) do
					if not struck[enemy] and enemy.alive then
						struck[enemy] = true
						if H.hit(player, enemy, power * ability.waveDamage, ability.id) then
							hits += 1
						end
						H.fx({ kind = "garden", phase = "reapHit", position = enemy.position, model = enemy.model })
						applyRot(player, enemy, ability, power)
					end
				end
				if i == steps then
					DebugState.set("Ability", "LastHits", hits)
				end
			end)
		end
	end)

	return { ok = true }
end

-- ===== Паводок =====

local function castFlood(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)

	task.delay(ability.slamAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local origin = current.Position - Vector3.new(0, H.FEET, 0)
		local direction = H.lookOf(current)

		local hits = 0
		for _, enemy in ipairs(enemiesInCone(origin, direction, ability.coneRadius, ability.coneHalfAngle)) do
			if H.hit(player, enemy, power * ability.waveDamage, ability.id) then
				hits += 1
			end
			local away = H.flat(enemy.position - origin)
			if away.Magnitude < 0.1 then
				away = direction
			end
			EnemyService.shove(enemy, away, ability.knockback, 0.25)
		end

		local center = origin + direction * clearLength(origin, direction, ability.puddleDistance)
		H.fx({
			kind = "garden",
			phase = "floodSlam",
			caster = player,
			position = origin,
			direction = direction,
			radius = ability.coneRadius,
			halfAngle = ability.coneHalfAngle,
			hits = hits,
		})
		H.fx({
			kind = "garden",
			phase = "floodPuddle",
			caster = player,
			position = center,
			radius = ability.puddleRadius,
			time = ability.puddleTime,
		})
		DebugState.set("Ability", "LastHits", hits)

		-- Разлив: тики урона и замедления, пока он не высохнет.
		local ticks = math.floor(ability.puddleTime / ability.puddleTick)
		task.spawn(function()
			for _ = 1, ticks do
				task.wait(ability.puddleTick)
				for _, enemy in ipairs(H.enemiesInRadius(center, ability.puddleRadius)) do
					if enemy.alive and not isObject(enemy) then
						H.hit(player, enemy, power * ability.puddleDamage, ability.id, { dot = true })
						EnemyService.slow(enemy, ability.slow, ability.slowTime)
					end
				end
			end
			H.fx({ kind = "garden", phase = "floodEnd", position = center, radius = ability.puddleRadius })
		end)
	end)

	return { ok = true }
end

-- ===== Обрезка =====

local function castPrune(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)

	local struck = {}
	for index, at in ipairs(ability.cuts) do
		task.delay(at, function()
			local current = H.rootOf(player)
			if not current then
				return
			end
			local feet = current.Position - Vector3.new(0, H.FEET, 0)
			local direction = H.lookOf(current)
			local models = {}
			local hits = 0
			for _, enemy in ipairs(enemiesInCone(feet, direction, ability.radius, ability.halfAngle)) do
				if enemy.alive then
					if H.hit(player, enemy, power * ability.cutDamage, ability.id) then
						hits += 1
					end
					table.insert(models, enemy.model)
					-- Броня и уязвимость ставятся один раз на врага за применение.
					if not struck[enemy] and not isObject(enemy) then
						struck[enemy] = true
						EnemyService.breakArmor(enemy, ability.armorBreak, ability.armorBreakDuration)
						EnemyService.setVulnerable(enemy, ability.vulnerable, ability.vulnerableTime)
					end
				end
			end
			H.fx({
				kind = "garden",
				phase = "pruneCut",
				caster = player,
				position = feet,
				direction = direction,
				radius = ability.radius,
				halfAngle = ability.halfAngle,
				index = index,
				targets = models,
				hits = hits,
			})
			DebugState.set("Ability", "LastHits", hits)
		end)
	end
	return { ok = true }
end

-- ===== Пассивка «Цветение» =====
-- Вызывается из WeaponAbilities.onMeleeHit после каждого удара.
-- baseDamage — урон удара без финала, крита и контратаки.

local function onMeleeHit(player, weapon, enemy, combo: number, baseDamage: number)
	if not enemy.alive or isObject(enemy) then
		return
	end
	local _, passive = Loot.abilityOf(weapon)
	if not passive or passive.id ~= "bloom" then
		return
	end
	local t = H.now()
	enemy.blooms = enemy.blooms or {}
	local mark = enemy.blooms[player]
	if not mark or t > mark.untilT then
		mark = { count = 0, untilT = 0 }
	end
	mark.count += 1
	mark.untilT = t + passive.stackTime
	enemy.blooms[player] = mark

	if mark.count >= passive.stacks then
		mark.count = 0
		local center = enemy.position
		H.fx({ kind = "garden", phase = "bloom", caster = player, model = enemy.model, position = center, radius = passive.radius })
		task.delay(0.2, function()
			for _, other in ipairs(H.enemiesInRadius(center, passive.radius)) do
				if other.alive then
					H.hit(player, other, baseDamage * passive.damage, "bloom", { crit = true })
					EnemyService.slow(other, passive.slow, passive.slowTime)
				end
			end
		end)
	else
		H.fx({ kind = "garden", phase = "thorn", caster = player, model = enemy.model, position = enemy.position, count = mark.count })
	end
end

-- helpers: fx, hit, power, setCasting, rootOf, lookOf, flat, enemiesInRadius, enemiesOnSegment, FEET, now.
function WeaponAbilitiesGarden.install(helpers)
	H = helpers
	return {
		casts = { reap = castReap, flood = castFlood, prune = castPrune },
		onMeleeHit = onMeleeHit,
	}
end

return WeaponAbilitiesGarden
