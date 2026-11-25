--!nonstrict
-- WeaponAbilities (сервер)
-- Способности эпического и легендарного оружия (клавиша «1») и пассивка
-- легендарки. Согласовано с Артёмом 24.10.2026:
--   Вихревой клинок  — «Вихрь-воронка»: кружение 1 с, 3 удара со стягиванием,
--                      затем режущая волна наружу с отбросом;
--   Расколотый молот — «Разлом» (правка 25.10.2026): удар в землю на месте
--                      (оглушение, −броня), три трещины вперёд замедляют,
--                      через 0,6 с из них бьют шипы и подбрасывают врагов;
--   Ключ Привратника — «Отпереть» (правка 25.10.2026): бросок ключа, печать
--                      R10 сковывает врагов цепями на 1 с (+25% урона по
--                      ним), цепи взрываются, ключ возвращается в руку;
--                      пассивка «Скважина»: 3-й удар серии ставит метку,
--                      на 3-й метке — удар ключом.
-- Этажи 2–5 — отдельные модули (WeaponAbilitiesGarden/Hunt/Forge/Chronicle), подключены ниже.
-- Числа — Config.Loot (Abilities, Passives). Сервер решает, кто задет;
-- клиент (AbilityFx) только рисует по событию AbilityFx (всем игрокам).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Echo = require(Shared.Config.Echo)
local Loot = require(Shared.Config.Loot)
local Weapons = require(Shared.Config.Weapons)
local FloorGeo = require(Shared.Floor.FloorGeo)
local Net = require(Shared.Net.Net)
local DebugState = require(Shared.Net.DebugState)

local CombatService = require(script.Parent.CombatService)
local EnemyService = require(script.Parent.EnemyService)
local TalentMods = require(script.Parent.TalentMods)

local WeaponAbilities = {}

local FEET = 3.0 -- R15: ноги ≈ корень − 3

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function rootOf(player)
	if not player or not player.Parent then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return root
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function lookOf(root): Vector3
	local look = flat(root.CFrame.LookVector)
	if look.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return look.Unit
end

local function fx(payload)
	local remote = Net.get("AbilityFx")
	if remote then
		remote:FireAllClients(payload)
	end
end

-- Тот же уровень (пандусы, балконы этажа v2): как у ударов в MeleeService.
local function sameLevel(enemy, feetY: number): boolean
	return math.abs(enemy.position.Y - feetY) <= math.max(4.5, enemy.stats.height * 0.7)
end

-- Враги в круге radius вокруг точки center (центр на уровне ног).
local function enemiesInRadius(center: Vector3, radius: number)
	local list = {}
	for _, enemy in ipairs(EnemyService.all()) do
		if enemy.alive and sameLevel(enemy, center.Y) then
			local distance = flat(enemy.position - center).Magnitude
			if distance - enemy.stats.radius <= radius then
				table.insert(list, enemy)
			end
		end
	end
	return list
end

-- Враги на отрезке (трещина): от origin по direction на length, полуширина halfWidth.
local function enemiesOnSegment(origin: Vector3, direction: Vector3, length: number, halfWidth: number)
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

-- Враги в секторе: радиус и половина угла от направления direction (как в WeaponAbilitiesGarden).
local function enemiesInCone(origin: Vector3, direction: Vector3, radius: number, halfAngle: number)
	local list = {}
	local cosLimit = math.cos(math.rad(halfAngle))
	for _, enemy in ipairs(enemiesInRadius(origin, radius)) do
		local rel = flat(enemy.position - origin)
		if rel.Magnitude < 0.5 then
			table.insert(list, enemy)
		else
			local angle = math.acos(math.clamp(rel.Unit:Dot(direction), -1, 1))
			local slack = math.atan2(enemy.stats.radius, rel.Magnitude)
			if angle - slack <= math.rad(halfAngle) or rel.Unit:Dot(direction) >= cosLimit then
				table.insert(list, enemy)
			end
		end
	end
	return list
end

-- Длина линии до стены (рывки, строки рун, точки падения).
local function clearLength(origin: Vector3, direction: Vector3, length: number): number
	local from = origin + Vector3.new(0, 1.2, 0)
	local result = FloorGeo.raycast(from, direction * length)
	if result then
		return math.max(1.5, flat(result.Position - from).Magnitude - 0.4)
	end
	return length
end

-- Сократить идущую перезарядку (пассивки «Песок времени», «Метка добычи»).
-- Саму таблицу перезарядок держит AbilityService: он подставляет функцию в start().
WeaponAbilities.cooldownApi = nil
local function reduceCooldown(player, abilityId: string, seconds: number)
	local api = WeaponAbilities.cooldownApi
	if api and api.reduce then
		api.reduce(player, abilityId, seconds)
	end
end

local function hit(player, enemy, amount: number, abilityId: string, extra)
	local info = { ability = abilityId }
	if extra then
		for k, v in pairs(extra) do
			info[k] = v
		end
	end
	local taken, status = EnemyService.applyDamage(enemy, amount, player, info)
	return status == "applied", taken
end

-- Урон оружия для способностей: урон класса × множитель предмета × ★ эха
-- (способностный множитель) × бонус легендарки.
function WeaponAbilities.power(player, weapon): number
	local stats = CombatService.getStats(player)
	local level = weapon.level or 1
	local base = Weapons.damage(stats.weaponDamage, weapon.typeId, weapon.rarityId, 0, weapon.id)
	base *= Echo.abilityMultiplier(level)
	local template = Loot.template(weapon.id)
	local bonus = weapon.damageBonus or (template and template.damageBonus)
	if bonus then
		base *= 1 + bonus
	end
	-- Древо: «Мастер оружия» (+25%), «Резонанс» (+20%). Терялось при наложении пакета 3–5 (05.11).
	return base * TalentMods.abilityDamageScale(player)
end

function WeaponAbilities.cooldown(weapon, ability): number
	local cooldown = ability.cooldown * Echo.cooldownMultiplier(weapon.level or 1)
	local template = Loot.template(weapon.id)
	local reduction = weapon.cooldownReduction or (template and template.cooldownReduction)
	if reduction then
		cooldown *= 1 - reduction
	end
	return cooldown
end

local function setCasting(player, duration: number)
	player:SetAttribute("CastingUntil", now() + duration)
end

-- ===== Вихрь-воронка =====

local function castVortex(player, weapon, ability, root)
	local power = WeaponAbilities.power(player, weapon)
	setCasting(player, ability.castTime)
	fx({
		kind = "vortex",
		phase = "start",
		caster = player,
		castTime = ability.castTime,
		radius = ability.radius,
		waveAt = ability.waveAt,
		waveRadius = ability.waveRadius,
	})

	local total = 0
	for index, at in ipairs(ability.ticks) do
		task.delay(at, function()
			local current = rootOf(player)
			if not current then
				return
			end
			local center = current.Position - Vector3.new(0, FEET, 0)
			local hits = 0
			for _, enemy in ipairs(enemiesInRadius(center, ability.radius)) do
				if hit(player, enemy, power * ability.tickDamage, ability.id) then
					hits += 1
				end
				-- Стягивание к герою, но не вплотную.
				local toCenter = flat(center - enemy.position)
				local room = toCenter.Magnitude - enemy.stats.radius - 1.4
				if room > 0.2 then
					EnemyService.shove(enemy, toCenter, math.min(ability.pull, room), 0.16)
				end
			end
			total += hits
			fx({ kind = "vortex", phase = "tick", caster = player, index = index, position = center, hits = hits })
		end)
	end

	task.delay(ability.waveAt, function()
		local current = rootOf(player)
		if not current then
			return
		end
		local center = current.Position - Vector3.new(0, FEET, 0)
		local hits = 0
		for _, enemy in ipairs(enemiesInRadius(center, ability.waveRadius)) do
			if hit(player, enemy, power * ability.waveDamage, ability.id) then
				hits += 1
			end
			local away = flat(enemy.position - center)
			if away.Magnitude < 0.1 then
				away = lookOf(current)
			end
			EnemyService.shove(enemy, away, ability.knockback, 0.2)
		end
		total += hits
		DebugState.set("Ability", "LastHits", total)
		fx({ kind = "vortex", phase = "wave", caster = player, position = center, radius = ability.waveRadius, hits = hits })
	end)

	return { ok = true }
end

-- ===== Разлом =====

-- Длина трещины: до стены (лучом по коллизиям карты на уровне колен).
local function crackLength(origin: Vector3, direction: Vector3, length: number): number
	local from = origin + Vector3.new(0, 1.2, 0)
	local result = FloorGeo.raycast(from, direction * length)
	if result then
		return math.max(1.5, flat(result.Position - from).Magnitude - 0.4)
	end
	return length
end

-- Удар в землю на месте: круг slam (урон, оглушение, −броня), три трещины
-- вперёд (урон, замедление), через eruptDelay из трещин бьют шипы (урон,
-- подброс). Каждый враг получает урон от трещины и от шипов не больше раза.
local function castRift(player, weapon, ability, root)
	local power = WeaponAbilities.power(player, weapon)
	setCasting(player, ability.castTime)

	task.delay(ability.slamAt, function()
		local current = rootOf(player)
		if not current then
			return
		end
		local center = current.Position - Vector3.new(0, FEET, 0)
		local look = lookOf(current)

		local hits = 0
		local slammed = {}
		for _, enemy in ipairs(enemiesInRadius(center, ability.radius)) do
			if hit(player, enemy, power * ability.slamDamage, ability.id) then
				hits += 1
			end
			EnemyService.stun(enemy, ability.stun)
			EnemyService.breakArmor(enemy, ability.armorBreak, ability.armorBreakDuration)
			slammed[enemy] = true
		end

		-- Трещины: веер вокруг взгляда.
		local cracks = {}
		local count = ability.cracks
		for i = 1, count do
			local angle = math.rad((i - (count + 1) / 2) * ability.crackSpread)
			local direction = flat(CFrame.Angles(0, angle, 0) * look).Unit
			table.insert(cracks, {
				direction = direction,
				length = crackLength(center, direction, ability.crackLength),
			})
		end
		fx({
			kind = "rift",
			phase = "slam",
			caster = player,
			position = center,
			radius = ability.radius,
			cracks = cracks,
			crackTime = ability.crackTime,
			eruptDelay = ability.eruptDelay,
			hits = hits,
		})

		-- Трещина добежала: урон и замедление тем, кто на ней.
		task.delay(ability.crackTime * 0.5, function()
			local cracked = {}
			for _, crack in ipairs(cracks) do
				for _, enemy in ipairs(enemiesOnSegment(center, crack.direction, crack.length, ability.crackHalfWidth)) do
					if not cracked[enemy] then
						cracked[enemy] = true
						if not slammed[enemy] and hit(player, enemy, power * ability.crackDamage, ability.id) then
							hits += 1
						end
						EnemyService.slow(enemy, ability.slow, ability.slowTime)
					end
				end
			end
		end)

		task.delay(ability.eruptDelay, function()
			local erupted = {}
			local eruptHits = 0
			for _, crack in ipairs(cracks) do
				for _, enemy in ipairs(enemiesOnSegment(center, crack.direction, crack.length, ability.crackHalfWidth)) do
					if not erupted[enemy] then
						erupted[enemy] = true
						if hit(player, enemy, power * ability.eruptDamage, ability.id) then
							eruptHits += 1
						end
						EnemyService.launch(enemy, ability.launchHeight, ability.launchTime)
					end
				end
			end
			DebugState.set("Ability", "LastHits", hits + eruptHits)
			fx({ kind = "rift", phase = "erupt", caster = player, position = center, cracks = cracks, hits = eruptHits })
		end)
	end)

	return { ok = true }
end

-- ===== Отпереть =====

-- Куда воткнётся ключ: вперёд до throwRange, у первого врага на пути;
-- стена обрезает бросок, над пропастью ключ падает ближе.
local function throwTarget(root, ability)
	local feet = root.Position - Vector3.new(0, FEET, 0)
	local look = lookOf(root)
	local distance = ability.throwRange
	local wall = FloorGeo.raycast(root.Position, look * (distance + 1))
	if wall then
		distance = math.max(1.5, flat(wall.Position - root.Position).Magnitude - 1)
	end
	local nearest = nil
	for _, enemy in ipairs(enemiesOnSegment(feet, look, distance, ability.throwHalfWidth)) do
		local along = flat(enemy.position - feet):Dot(look)
		if along > 0.5 and (not nearest or along < nearest) then
			nearest = along
		end
	end
	if nearest then
		distance = math.min(distance, nearest)
	end
	while distance > 0 do
		local point = feet + look * distance
		local ground = FloorGeo.groundAt(point.X, point.Z, feet.Y + 2)
		if ground and math.abs(ground - feet.Y) <= 4 then
			return Vector3.new(point.X, ground, point.Z), distance
		end
		distance -= 1
	end
	return feet, 0
end

local function castUnlock(player, weapon, ability, root)
	local power = WeaponAbilities.power(player, weapon)
	setCasting(player, ability.castTime)

	task.delay(ability.releaseAt, function()
		local current = rootOf(player)
		if not current then
			return
		end
		local target, distance = throwTarget(current, ability)
		local flight = 0.2 + distance * 0.022
		local hand = current.Position + lookOf(current) * 1 + Vector3.new(0, 1.2, 0)
		fx({ kind = "unlock", phase = "throw", caster = player, from = hand, target = target, flightTime = flight })

		task.delay(flight, function()
			-- Ключ в земле: печать и цепи.
			local bound = {}
			for _, enemy in ipairs(enemiesInRadius(target, ability.radius)) do
				if enemy.stats.role ~= "object" then
					local bind = enemy.stats.isBoss and ability.bossBindTime or ability.bindTime
					EnemyService.stun(enemy, bind)
					EnemyService.setVulnerable(enemy, ability.vulnerable, ability.bindTime + 0.2)
					table.insert(bound, enemy.model)
				end
			end
			fx({
				kind = "unlock",
				phase = "lock",
				caster = player,
				position = target,
				radius = ability.radius,
				bindTime = ability.bindTime,
				targets = bound,
			})

			task.delay(ability.bindTime, function()
				local hits = 0
				for _, enemy in ipairs(enemiesInRadius(target, ability.radius)) do
					if hit(player, enemy, power * ability.blastDamage, ability.id) then
						hits += 1
					end
					local away = flat(enemy.position - target)
					if away.Magnitude < 0.1 then
						away = Vector3.new(1, 0, 0)
					end
					EnemyService.shove(enemy, away, ability.knockback, 0.22)
				end
				DebugState.set("Ability", "LastHits", hits)
				fx({ kind = "unlock", phase = "open", caster = player, position = target, radius = ability.radius, hits = hits })
			end)
		end)
	end)

	return { ok = true }
end

-- ===== Старые способности (сохранения до 24.10.2026, витрина) =====

local function castRadial(player, weapon, ability, root)
	local power = WeaponAbilities.power(player, weapon)
	local center = root.Position - Vector3.new(0, FEET, 0)
	local hits = 0
	for _, enemy in ipairs(enemiesInRadius(center, ability.radius or 5)) do
		if hit(player, enemy, power * ability.damageMultiplier, ability.id) then
			hits += 1
		end
		if ability.stun then
			EnemyService.stun(enemy, ability.stun)
		end
		if ability.armorBreak then
			EnemyService.breakArmor(enemy, ability.armorBreak, ability.armorBreakDuration or 6)
		end
	end
	return { ok = true, hits = hits, radius = ability.radius, legacy = true }
end

local CASTS = {
	vortex = castVortex,
	rift = castRift,
	unlock = castUnlock,
	whirl = castRadial,
	sunder = castRadial,
}

-- Этаж 2 «Затопленные сады»: Жатва, Паводок, Обрезка и пассивка «Цветение» живут в WeaponAbilitiesGarden.
local Garden = require(script.Parent.WeaponAbilitiesGarden).install({
	fx = fx,
	hit = hit,
	power = WeaponAbilities.power,
	setCasting = setCasting,
	rootOf = rootOf,
	lookOf = lookOf,
	flat = flat,
	enemiesInRadius = enemiesInRadius,
	enemiesOnSegment = enemiesOnSegment,
	FEET = FEET,
	now = now,
})
for abilityId, cast in pairs(Garden.casts) do
	CASTS[abilityId] = cast
end

-- Этажи 3–5 (Псарни охоты, Кузня Основателя, Архив Хроник): те же помощники + конус, длина до стены,
-- сокращение перезарядки и длина серии.
local helpers345 = {
	fx = fx,
	hit = hit,
	power = WeaponAbilities.power,
	setCasting = setCasting,
	rootOf = rootOf,
	lookOf = lookOf,
	flat = flat,
	enemiesInRadius = enemiesInRadius,
	enemiesOnSegment = enemiesOnSegment,
	enemiesInCone = enemiesInCone,
	clearLength = clearLength,
	reduceCooldown = reduceCooldown,
	comboLength = Combat.Attack.comboLength,
	FEET = FEET,
	now = now,
}
local Hunt = require(script.Parent.WeaponAbilitiesHunt).install(helpers345)
local Forge = require(script.Parent.WeaponAbilitiesForge).install(helpers345)
local Chronicle = require(script.Parent.WeaponAbilitiesChronicle).install(helpers345)
for _, set in ipairs({ Hunt, Forge, Chronicle }) do
	for abilityId, cast in pairs(set.casts) do
		CASTS[abilityId] = cast
	end
end

-- Переделка способностей мечей и молотов (07.11.2026): касты V2 заменяют старые с теми же id.
-- Старые касты Тигля и Перекала остаются внутри новых (V2 добавляет поверх них).
local V2 = require(script.Parent.WeaponAbilitiesV2).install(helpers345, {
	Garden = Garden,
	Forge = Forge,
	Hunt = Hunt,
	Chronicle = Chronicle,
	old = { spill = CASTS.spill, overheat = CASTS.overheat },
})
for abilityId, cast in pairs(V2.casts) do
	CASTS[abilityId] = cast
end

-- Маг: 19 заклинаний посохов (клавиша «1») живут в WeaponAbilitiesMage. Подключение терялось
-- при наложении пакета оружия 3–5 (05.11) — заклинания отвечали «unknown-ability». Восстановлено 07.11.2026.
local Mage = require(script.Parent.WeaponAbilitiesMage).install({
	fx = fx,
	power = WeaponAbilities.power,
	setCasting = setCasting,
	rootOf = rootOf,
	lookOf = lookOf,
	flat = flat,
	FEET = FEET,
	now = now,
})
for abilityId, cast in pairs(Mage.casts) do
	-- общий id с воином (last_hunt) не перетираем: посоху ловчего — своё заклинание (этап мага)
	if not CASTS[abilityId] then
		CASTS[abilityId] = cast
	end
end

-- Хук взмаха для MeleeService.swingHooks: память ударов «Клинка Памяти» и «Послеобраз».
function WeaponAbilities.swingHook(player, origin, forward, range, arc, damage, combo)
	return Chronicle.swingHook(player, origin, forward, range, arc, damage, combo)
end

-- Применить способность. Перезарядку ставит AbilityService.
function WeaponAbilities.cast(player, weapon, ability)
	local root = rootOf(player)
	if not root then
		return { ok = false, reason = "no-character" }
	end
	if (player:GetAttribute("CastingUntil") or 0) > now() then
		return { ok = false, reason = "busy" }
	end
	local cast = CASTS[ability.id]
	if not cast then
		return { ok = false, reason = "unknown-ability" }
	end
	local result = cast(player, weapon, ability, root)
	DebugState.set("Ability", "LastUsed", ability.id)
	return result
end

function WeaponAbilities.isCasting(player): boolean
	return (player:GetAttribute("CastingUntil") or 0) > now()
end

-- ===== Пассивка «Скважина» =====

-- Вызывается из MeleeService после попадания удара серии.
-- baseDamage — урон удара без финала, крита и контратаки.
function WeaponAbilities.onMeleeHit(player, weapon, enemy, combo: number, baseDamage: number)
	Garden.onMeleeHit(player, weapon, enemy, combo, baseDamage) -- «Цветение»: на каждом ударе, не только на финале
	-- Этажи 3–5: каждый модуль сам проверяет свою пассивку (и баффы «Перекал», «Безвременье»);
	-- V2 — горящий клинок «Горнила», финал «Перекала», пике «Соколиной охоты».
	for _, set in ipairs({ Hunt, Forge, Chronicle, V2 }) do
		local ok, err = pcall(set.onMeleeHit, player, weapon, enemy, combo, baseDamage)
		if not ok then
			warn("[WeaponAbilities] onMeleeHit: " .. tostring(err))
		end
	end
	if combo ~= Combat.Attack.comboLength or not enemy.alive then
		return
	end
	local _, passive = Loot.abilityOf(weapon)
	if not passive or passive.id ~= "keyhole" then
		return
	end
	local t = now()
	enemy.keyholes = enemy.keyholes or {}
	local mark = enemy.keyholes[player]
	if not mark or t > mark.untilT then
		mark = { count = 0, untilT = 0 }
	end
	mark.count += 1
	mark.untilT = t + passive.markTime
	enemy.keyholes[player] = mark

	local model = enemy.model
	if mark.count >= passive.marks then
		mark.count = 0
		model:SetAttribute("Keyholes", 0)
		fx({ kind = "keyhole", phase = "burst", caster = player, model = model, position = enemy.position })
		task.delay(0.15, function()
			if enemy.alive then
				hit(player, enemy, baseDamage * passive.damage, "keyhole", { crit = true })
			end
		end)
	else
		model:SetAttribute("Keyholes", mark.count)
		model:SetAttribute("KeyholesUntil", mark.untilT)
		fx({ kind = "keyhole", phase = "mark", caster = player, model = model, count = mark.count, untilT = mark.untilT })
	end
end

Players.PlayerRemoving:Connect(function(player)
	for _, enemy in ipairs(EnemyService.all()) do
		if enemy.keyholes then
			enemy.keyholes[player] = nil
		end
	end
end)

return WeaponAbilities


