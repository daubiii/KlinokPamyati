--!nonstrict
-- WeaponAbilitiesHunt (сервер)
-- Способности и пассивки оружия этажа 3 «Псарни охоты»:
--   Клык вожака        — «Свора»: три призрачные гончие веером бросаются к врагам и грызут (замедление);
--   Молот-капкан       — «Капкан»: кольцо челюстей вокруг героя схлопывается — урон, прижатие, −броня;
--   Коса ловчего       — «Последний гон»: рывок-пронзание (move клиенту), рог в конце замедляет;
--                        пассивка «Метка добычи»: финал метит врага (+18% урона), убийство добычи
--                        возвращает 30% перезарядки «Последнего гона»;
--   Клинок сокольничего — «Пикирование»: сокол падает на врага впереди, подброс;
--                        пассивка «Сокол»: раз в 5 с сокол добивает врага, которого вы ударили.
-- Числа — Config.LootFloor3 (Abilities, Passives). Клиент (AbilityFxHunt) рисует по AbilityFx kind = "hunt".
-- Подключается из WeaponAbilities.lua тем же install-паттерном, что WeaponAbilitiesGarden.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loot = require(Shared.Config.Loot)
local DebugState = require(Shared.Net.DebugState)

local EnemyService = require(script.Parent.EnemyService)

local WeaponAbilitiesHunt = {}

local H -- помощники WeaponAbilities (см. install)

local prey = {} -- [player] = { enemy, untilT }
local falconReady = {} -- [player] = время, когда сокол снова готов

local function isObject(enemy): boolean
	return enemy.stats.role == "object"
end

local function feetOf(root): Vector3
	return root.Position - Vector3.new(0, H.FEET, 0)
end

-- Добыча убита (любым ударом героя) — вернуть часть перезарядки «Последнего гона».
local function checkPreyKill(player, enemy)
	local mark = prey[player]
	if not mark or mark.enemy ~= enemy or enemy.alive then
		return
	end
	prey[player] = nil
	local passive = Loot.Passives.prey_mark
	local length = player:GetAttribute("CdLen_last_hunt") or 0
	if passive and length > 0 then
		H.reduceCooldown(player, "last_hunt", length * passive.refund)
	end
	H.fx({ kind = "hunt", phase = "preyKill", caster = player, position = enemy.position })
end

local function huntHit(player, enemy, amount: number, abilityId: string, extra)
	local applied, taken = H.hit(player, enemy, amount, abilityId, extra)
	checkPreyKill(player, enemy)
	return applied, taken
end

local function isPreyOf(player, enemy): boolean
	local mark = prey[player]
	return mark ~= nil and mark.enemy == enemy and mark.untilT > H.now() and enemy.alive
end

-- ===== Свора =====

local function nearestFree(center: Vector3, radius: number, taken)
	local best, bestDistance = nil, math.huge
	for _, enemy in ipairs(H.enemiesInRadius(center, radius)) do
		if enemy.alive and not taken[enemy] then
			local distance = H.flat(enemy.position - center).Magnitude
			if distance < bestDistance then
				best, bestDistance = enemy, distance
			end
		end
	end
	return best
end

local function castPack(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)

	task.delay(ability.summonAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local origin = feetOf(current)
		local look = H.lookOf(current)
		local taken = {}
		local hounds = {}
		for i = 1, ability.hounds do
			local angle = math.rad((i - (ability.hounds + 1) / 2) * ability.fanAngle)
			local direction = (CFrame.Angles(0, angle, 0) * CFrame.new(Vector3.zero, look)).LookVector
			-- Сначала свободная цель; если врагов меньше, чем гончих, — вдвоём на одного.
			local target = nearestFree(origin, ability.seekRadius, taken) or nearestFree(origin, ability.seekRadius, {})
			if target then
				taken[target] = true
			end
			hounds[i] = { index = i, direction = H.flat(direction).Unit, target = target }
		end
		local summary = {}
		for _, hound in ipairs(hounds) do
			table.insert(summary, {
				index = hound.index,
				direction = hound.direction,
				model = hound.target and hound.target.model or nil,
			})
		end
		H.fx({
			kind = "hunt",
			phase = "packSummon",
			caster = player,
			position = origin,
			hounds = summary,
			speed = ability.houndSpeed,
			lifetime = ability.lifetime,
		})

		local totalHits = 0
		for _, hound in ipairs(hounds) do
			task.spawn(function()
				local target = hound.target
				if not target then
					return
				end
				local travel = math.clamp(H.flat(target.position - origin).Magnitude / ability.houndSpeed, 0.08, 0.6)
				task.wait(travel)
				local startedAt = H.now()
				for bite = 1, ability.bites do
					if H.now() - startedAt > ability.lifetime then
						return
					end
					if not target.alive then
						-- Цель пала — гончая ищет новую рядом.
						target = nearestFree(target.position, 6, {})
						if not target then
							return
						end
						H.fx({ kind = "hunt", phase = "packRetarget", caster = player, index = hound.index, model = target.model })
						task.wait(0.18)
					end
					if target.alive then
						if huntHit(player, target, power * ability.biteDamage, ability.id) then
							totalHits += 1
						end
						if target.alive and not isObject(target) then
							EnemyService.slow(target, ability.slow, ability.slowTime)
						end
						H.fx({ kind = "hunt", phase = "packBite", caster = player, index = hound.index, bite = bite, model = target.model, position = target.position })
					end
					task.wait(ability.biteInterval)
				end
				H.fx({ kind = "hunt", phase = "packFade", caster = player, index = hound.index, position = target and target.position })
				DebugState.set("Ability", "LastHits", totalHits)
			end)
		end
	end)
	return { ok = true }
end

-- ===== Капкан =====

local function castSnare(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)

	task.delay(ability.slamAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local center = feetOf(current)
		H.fx({ kind = "hunt", phase = "snareOpen", caster = player, position = center, radius = ability.radius, snapDelay = ability.snapDelay })

		task.delay(ability.snapDelay, function()
			local hits = 0
			local models = {}
			for _, enemy in ipairs(H.enemiesInRadius(center, ability.radius)) do
				if enemy.alive then
					if huntHit(player, enemy, power * ability.snapDamage, ability.id) then
						hits += 1
					end
					table.insert(models, enemy.model)
					if enemy.alive and not isObject(enemy) then
						local toCenter = H.flat(center - enemy.position)
						local room = toCenter.Magnitude - enemy.stats.radius - 1.2
						if room > 0.2 then
							EnemyService.shove(enemy, toCenter, math.min(ability.pull, room), 0.12)
						end
						EnemyService.stun(enemy, enemy.stats.isBoss and ability.bossRoot or ability.root)
						EnemyService.breakArmor(enemy, ability.armorBreak, ability.armorBreakDuration)
						enemy.model:SetAttribute("SnaredUntil", H.now() + (enemy.stats.isBoss and ability.bossRoot or ability.root))
					end
				end
			end
			DebugState.set("Ability", "LastHits", hits)
			H.fx({ kind = "hunt", phase = "snareSnap", caster = player, position = center, radius = ability.radius, targets = models, hits = hits, root = ability.root })
		end)
	end)
	return { ok = true }
end

-- ===== Последний гон =====

local function castLastHunt(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)

	local origin = feetOf(root)
	local direction = H.lookOf(root)
	local distance = H.clearLength(origin, direction, ability.dashDistance)

	task.delay(ability.windup, function()
		if not H.rootOf(player) then
			return
		end
		H.fx({
			kind = "hunt",
			phase = "dash",
			caster = player,
			position = origin,
			direction = direction,
			length = distance,
			halfWidth = ability.halfWidth,
			time = ability.dashTime,
		})
	end)

	-- Пронзание считаем по всему пути рывка в его середине (клиент двигает героя сам).
	task.delay(ability.windup + ability.dashTime * 0.6, function()
		if not H.rootOf(player) then
			return
		end
		local hits = 0
		local models = {}
		for _, enemy in ipairs(H.enemiesOnSegment(origin, direction, distance, ability.halfWidth)) do
			if enemy.alive then
				local amount = power * ability.damage
				local isPrey = isPreyOf(player, enemy)
				if isPrey then
					amount *= 1 + ability.preyBonus
				end
				if huntHit(player, enemy, amount, ability.id, { crit = isPrey }) then
					hits += 1
				end
				table.insert(models, enemy.model)
			end
		end
		DebugState.set("Ability", "LastHits", hits)
		H.fx({ kind = "hunt", phase = "dashHit", caster = player, targets = models, hits = hits })
	end)

	task.delay(ability.windup + ability.dashTime + 0.05, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local center = feetOf(current)
		for _, enemy in ipairs(H.enemiesInRadius(center, ability.hornRadius)) do
			if enemy.alive and not isObject(enemy) then
				EnemyService.slow(enemy, ability.slow, ability.slowTime)
			end
		end
		H.fx({ kind = "hunt", phase = "horn", caster = player, position = center, radius = ability.hornRadius })
	end)

	return {
		ok = true,
		move = { direction = direction, distance = distance, time = ability.dashTime, delay = ability.windup },
	}
end

-- ===== Пикирование =====

local function castDive(player, weapon, ability, root)
	local power = H.power(player, weapon)
	H.setCasting(player, ability.castTime)

	task.delay(ability.releaseAt, function()
		local current = H.rootOf(player)
		if not current then
			return
		end
		local origin = feetOf(current)
		local look = H.lookOf(current)
		-- Цель: ближайший враг в конусе впереди, иначе точка перед героем.
		local target, best = nil, math.huge
		for _, enemy in ipairs(H.enemiesInCone(origin, look, ability.range, ability.coneHalfAngle)) do
			local distance = H.flat(enemy.position - origin).Magnitude
			if enemy.alive and distance < best then
				target, best = enemy, distance
			end
		end
		local point
		if target then
			point = Vector3.new(target.position.X, origin.Y, target.position.Z)
		else
			point = origin + look * H.clearLength(origin, look, ability.range * 0.6)
		end
		H.fx({
			kind = "hunt",
			phase = "diveStart",
			caster = player,
			from = current.Position + Vector3.new(0, 6, 0) - look * 2,
			position = point,
			time = ability.diveTime,
			radius = ability.radius,
		})

		task.delay(ability.diveTime, function()
			local hits = 0
			for _, enemy in ipairs(H.enemiesInRadius(point, ability.radius)) do
				if enemy.alive then
					if huntHit(player, enemy, power * ability.damage, ability.id) then
						hits += 1
					end
					EnemyService.launch(enemy, ability.launchHeight, ability.launchTime)
				end
			end
			DebugState.set("Ability", "LastHits", hits)
			H.fx({ kind = "hunt", phase = "diveImpact", caster = player, position = point, radius = ability.radius, hits = hits })
		end)
	end)
	return { ok = true }
end

-- ===== Пассивки «Метка добычи» и «Сокол» =====
-- Вызывается из WeaponAbilities.onMeleeHit после каждого попавшего удара.

local function onMeleeHit(player, weapon, enemy, combo: number, baseDamage: number)
	checkPreyKill(player, enemy)
	local _, passive = Loot.abilityOf(weapon)
	if not passive then
		return
	end
	local t = H.now()

	if passive.id == "prey_mark" then
		if combo ~= H.comboLength or not enemy.alive or isObject(enemy) then
			return
		end
		local old = prey[player]
		if old and old.enemy ~= enemy and old.enemy.model then
			old.enemy.model:SetAttribute("PreyMarkUntil", nil)
		end
		prey[player] = { enemy = enemy, untilT = t + passive.markTime }
		EnemyService.setVulnerable(enemy, passive.vulnerable, passive.markTime)
		enemy.model:SetAttribute("PreyMarkUntil", t + passive.markTime)
		enemy.model:SetAttribute("PreyMarkBy", player.UserId)
		H.fx({ kind = "hunt", phase = "preyMark", caster = player, model = enemy.model, duration = passive.markTime })
	elseif passive.id == "falcon" then
		if not enemy.alive or t < (falconReady[player] or 0) then
			return
		end
		falconReady[player] = t + passive.interval
		player:SetAttribute("FalconReadyAt", falconReady[player])
		H.fx({ kind = "hunt", phase = "falconStrike", caster = player, model = enemy.model, position = enemy.position, delay = passive.delay })
		task.delay(passive.delay, function()
			if enemy.alive then
				huntHit(player, enemy, baseDamage * passive.damage, "falcon", { crit = true })
				if enemy.alive and not isObject(enemy) then
					EnemyService.breakArmor(enemy, passive.armorBreak, passive.armorBreakDuration)
				end
			end
		end)
	end
end

Players.PlayerRemoving:Connect(function(player)
	prey[player] = nil
	falconReady[player] = nil
end)

-- helpers: fx, hit, power, setCasting, rootOf, lookOf, flat, enemiesInRadius, enemiesOnSegment, enemiesInCone,
-- clearLength, reduceCooldown, comboLength, FEET, now.
function WeaponAbilitiesHunt.install(helpers)
	H = helpers
	return {
		casts = { pack = castPack, snare = castSnare, last_hunt = castLastHunt, dive = castDive },
		onMeleeHit = onMeleeHit,
	}
end

return WeaponAbilitiesHunt
