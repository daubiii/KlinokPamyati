--!nonstrict
-- WeaponAbilitiesMage (сервер)
-- Заклинания посохов мага (клавиша «1»): 19 штук, по 2–3 на этаж (Config.LootMage.Abilities).
-- Подключается из WeaponAbilities.lua одной вставкой (как WeaponAbilitiesGarden): модуль получает
-- его помощников (power, setCasting, lookOf, FEET, now) и отдаёт касты.
--
-- Каждое заклинание: тратит ману (нет — { ok = false, reason = "no-mana" }, перезарядка не идёт),
-- сила = урон оружия × ★ эха × бонус редкости × масштаб маны × засада «Покрова» (×1,5, покров
-- снимается). Сервер считает попадания и тайминги (падения метеоров, пике соколов, вспышки),
-- клиент рисует по событию MageFx { kind = "spell", id, phase, cast, caster, … }
-- (Controllers/MageSpellFx). Самонаводящиеся снаряды (лепестки, споры, волки, глифы, сферы)
-- летят через MageBolts — клиент рисует их полёт по { kind = "bolt", visual = … } (MageFx).
--
-- Фазы (сервер → клиент), для сверки с MageSpellFx.PHASES:
--   ward_circle      cast · burst · end
--   signal_fire      cast · blast · end
--   light_gate       cast · surge · close
--   lotus_bloom      cast · geyser
--   mycelium         cast · seed · glade · exhale · burst
--   thorn_garden     cast · ring · garden · end
--   spirit_pack      cast · surround · howl · bite · pounce
--   hunters_moon     cast · beam · crescent
--   royal_hunt       cast · net · spear · tear
--   fire_rain        cast · meteor · end
--   forged_lightning cast · strike · chain
--   forge_heart      cast · pillar · wall · end
--   meteor           cast · impact · end
--   first_cast       cast · rift · nova
--   open_tome        cast · storm
--   time_stop        cast · freeze · sweep · strike · rewind
--   fate_line        cast · ignite
--   ink_hole         cast · open · blast
--   total_recall     cast · beams · storm

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LootMage = require(Shared.Config.LootMage)
local FloorGeo = require(Shared.Floor.FloorGeo)
local DebugState = require(Shared.Net.DebugState)

local EnemyService = require(script.Parent.EnemyService)
local ManaService = require(script.Parent.ManaService)
local MageBolts = require(script.Parent.MageBolts)
local MageService = require(script.Parent.MageService)
local TalentMods = require(script.Parent.TalentMods)

local WeaponAbilitiesMage = {}

local H -- помощники WeaponAbilities (см. install)
local CASTS = {}
local serial = 0

WeaponAbilitiesMage.PHASES = {
	ward_circle = { "cast", "burst", "end" },
	signal_fire = { "cast", "blast", "end" },
	light_gate = { "cast", "surge", "close" },
	lotus_bloom = { "cast", "geyser" },
	mycelium = { "cast", "seed", "glade", "exhale", "burst" },
	thorn_garden = { "cast", "ring", "garden", "end" },
	spirit_pack = { "cast", "surround", "howl", "bite", "pounce" },
	hunters_moon = { "cast", "beam", "crescent" },
	royal_hunt = { "cast", "net", "spear", "tear" },
	fire_rain = { "cast", "meteor", "end" },
	forged_lightning = { "cast", "strike", "chain" },
	forge_heart = { "cast", "pillar", "wall", "end" },
	meteor = { "cast", "impact", "end" },
	first_cast = { "cast", "rift", "nova" },
	open_tome = { "cast", "storm" },
	time_stop = { "cast", "freeze", "sweep", "strike", "rewind" },
	fate_line = { "cast", "ignite" },
	ink_hole = { "cast", "open", "blast" },
	total_recall = { "cast", "beams", "storm" },
}

-- ===== Помощники =====

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rotate(dir: Vector3, degrees: number): Vector3
	return CFrame.Angles(0, math.rad(degrees), 0):VectorToWorldSpace(dir)
end

local function awayFrom(enemy, center: Vector3, fallback: Vector3): Vector3
	local away = flat(enemy.position - center)
	if away.Magnitude < 0.1 then
		return fallback
	end
	return away.Unit
end

local function isObject(enemy): boolean
	return enemy.stats.role == "object"
end

local function living(list)
	local out = {}
	for _, enemy in ipairs(list) do
		if enemy.alive and not isObject(enemy) then
			table.insert(out, enemy)
		end
	end
	return out
end

-- Сколько свободно по линии до стены (как clearLength у «Жатвы»).
local function clearLength(from: Vector3, dir: Vector3, length: number): number
	local start = from + Vector3.new(0, 1.2, 0)
	local result = FloorGeo.raycast(start, dir * length)
	if result then
		return math.max(1.5, flat(result.Position - start).Magnitude - 0.6)
	end
	return length
end

local function noMana()
	return { ok = false, reason = "no-mana" }
end

local function spellFx(c, phase: string, data)
	local payload = data or {}
	payload.kind = "spell"
	payload.id = c.id
	payload.phase = phase
	payload.caster = c.player
	payload.cast = c.serial
	payload.t = H.now()
	MageService.fx(payload)
end

local function later(c, delay: number, fn)
	task.delay(delay, function()
		if not c.player.Parent then
			return
		end
		local ok, err = pcall(fn)
		if not ok then
			warn("[WeaponAbilitiesMage] " .. c.id .. ": " .. tostring(err))
		end
	end)
end

local function hit(c, enemy, share: number): boolean
	local applied = MageService.hit(c.player, enemy, c.power * share, { ability = c.id })
	if applied then
		c.hits += 1
	end
	return applied
end

local function debuff(c, enemy, kind: string)
	if enemy.alive then
		MageService.applyDebuff(c.player, enemy, kind, c.power)
	end
end

-- Текущие ноги мага (он мог сдвинуться за время заклинания).
local function feetNow(c): Vector3
	local root = MageService.rootOf(c.player)
	if root then
		return root.Position - Vector3.new(0, H.FEET, 0)
	end
	return c.feet
end

-- Навершие посоха: откуда летят снаряды заклинаний.
local function tipOf(c): Vector3
	return feetNow(c) + c.aim * 1.3 + Vector3.new(0, LootMage.BoltHeight + 0.5, 0)
end

-- Точка «впереди»: враг под прицелом (если ближе distance + slack) или distance по взгляду, до стены.
local function pointAhead(c, distance: number, slack: number?): Vector3
	local length = distance
	if c.target and c.target.alive then
		local rel = flat(c.target.position - c.feet)
		if rel.Magnitude <= distance + (slack or 0) then
			length = math.max(rel.Magnitude, 2)
		end
	end
	length = clearLength(c.feet, c.aim, length)
	return MageService.groundAt(c.feet + c.aim * length)
end

local function randomInCircle(center: Vector3, radius: number): Vector3
	local angle = math.random() * math.pi * 2
	local r = math.sqrt(math.random()) * radius
	return MageService.groundAt(center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r))
end

-- Начало заклинания: мана, сила, каст. nil — не хватило маны.
local function begin(player, weapon, ability, root)
	-- Древо мага: «Тонкие поля» (−10% маны), «Эхо заклинаний» (каждое 4-е даром).
	local cost, free = TalentMods.spellCost(player, ability.mana or 0)
	if not ManaService.spend(player, cost) then
		return nil
	end
	TalentMods.noteSpell(player)
	if free then
		DebugState.bump("Talents", "FreeSpells")
	end
	serial += 1
	local feet = root.Position - Vector3.new(0, H.FEET, 0)
	local look = H.lookOf(root)
	local power = H.power(player, weapon) * ManaService.abilityScale(player) * MageService.consumeVeil(player)
	-- «Скоропись»: каст на 15% короче.
	H.setCasting(player, (ability.castTime or 0.5) * TalentMods.castTimeScale(player))
	local c = {
		player = player,
		weapon = weapon,
		ability = ability,
		id = ability.id,
		root = root,
		feet = feet,
		look = look,
		aim = look,
		power = power,
		hits = 0,
		serial = serial,
	}
	-- Автоприцел, как у ударов посоха: ближайший к линии взгляда враг на виду.
	local target = MageService.bestTarget(feet + Vector3.new(0, LootMage.BoltHeight, 0), look, 24, 35, feet.Y)
	if target and not isObject(target) then
		c.target = target
		local rel = flat(target.position - feet)
		if rel.Magnitude > 0.8 then
			c.aim = rel.Unit
		end
	end
	DebugState.bump("Mage", "Spell_" .. ability.id)
	DebugState.set("Mage", "LastSpell", ability.id)
	return c
end

-- Снаряд заклинания (самонаведение, свой вид). o: origin, dir, speed, size, range, style, visual,
-- homing, pierce, target, delay, share, debuff, data, onHit(b, enemy), onEnd(b, position, reason).
local function spellBolt(c, o)
	return MageBolts.spawn({
		owner = c.player,
		origin = o.origin,
		dir = o.dir,
		feetY = c.feet.Y,
		speed = o.speed or 30,
		size = o.size or 0.5,
		range = o.range or 20,
		style = o.style,
		visual = o.visual,
		homing = o.homing,
		pierce = o.pierce,
		target = o.target,
		delay = o.delay,
		data = o.data or {},
		onHit = function(b, enemy)
			if o.onHit then
				return o.onHit(b, enemy)
			end
			hit(c, enemy, o.share or 0.3)
			if o.debuff then
				debuff(c, enemy, o.debuff)
			end
			return true
		end,
		onEnd = o.onEnd,
	})
end

local function pickFrom(list, i: number)
	if #list == 0 then
		return nil
	end
	return list[(i - 1) % #list + 1]
end

-- ===== Этаж 1 =====

-- Сторожевой круг: круг рун у ног, вспышка с отбросом, затем жжёт и замедляет.
CASTS.ward_circle = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local center = c.feet
	local burstAt = 0.3
	spellFx(c, "cast", { position = center, radius = ability.radius, duration = ability.duration, burstAt = burstAt })
	later(c, burstAt, function()
		spellFx(c, "burst", { position = center, radius = ability.radius })
		for _, enemy in ipairs(MageService.enemiesInRadius(center, ability.radius)) do
			if hit(c, enemy, ability.burst) then
				EnemyService.shove(enemy, awayFrom(enemy, center, c.look), ability.push, 0.2)
			end
		end
	end)
	MageService.zone({
		owner = player,
		center = center,
		radius = ability.radius,
		delay = burstAt,
		duration = ability.duration,
		tick = ability.tick,
		onTick = function(enemies)
			for _, enemy in ipairs(enemies) do
				hit(c, enemy, ability.tickDamage)
				EnemyService.slow(enemy, ability.slow, ability.tick + 0.25)
			end
		end,
		onEnd = function()
			spellFx(c, "end", { position = center })
		end,
	})
	return { ok = true, radius = ability.radius }
end

-- Сигнальный огонь: маяк навесом, взрыв с горением, столб огня.
CASTS.signal_fire = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local to = pointAhead(c, ability.range, 2)
	local from = tipOf(c)
	spellFx(c, "cast", { from = from, to = to, flight = ability.flight, delay = 0.12 })
	MageBolts.spawn({
		owner = player,
		origin = from,
		dir = c.aim,
		feetY = c.feet.Y,
		style = "fire",
		visual = "beacon",
		size = 0.9,
		delay = 0.12,
		lob = { to = to + Vector3.new(0, 0.4, 0), time = ability.flight, height = 3.5 },
		onEnd = function(_, position)
			if not player.Parent then
				return
			end
			local ground = MageService.groundAt(position)
			spellFx(c, "blast", { position = ground, radius = ability.radius, pillarRadius = ability.pillarRadius,
				duration = ability.pillarTime })
			for _, enemy in ipairs(MageService.enemiesInRadius(ground, ability.radius)) do
				if hit(c, enemy, ability.blast) then
					debuff(c, enemy, "burn")
				end
			end
			MageService.zone({
				owner = player,
				center = ground,
				radius = ability.pillarRadius,
				duration = ability.pillarTime,
				tick = ability.tick,
				onTick = function(enemies)
					for _, enemy in ipairs(enemies) do
						hit(c, enemy, ability.tickDamage)
					end
				end,
				onEnd = function()
					spellFx(c, "end", { position = ground })
				end,
			})
		end,
	})
	return { ok = true, radius = ability.radius }
end

-- Врата света: врата в 8 стадах, волна света по линии (оглушение), затем врата схлопываются.
CASTS.light_gate = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local dir = c.aim
	local gateDistance = clearLength(c.feet, dir, ability.distance)
	local gate = MageService.groundAt(c.feet + dir * gateDistance)
	local origin = c.feet + dir * 1.2
	local length = clearLength(origin, dir, ability.surgeLength)
	spellFx(c, "cast", { position = gate, dir = dir, width = ability.gateWidth, surgeAt = ability.surgeAt,
		closeAt = ability.closeAt, origin = origin, length = length, halfWidth = ability.surgeHalfWidth })
	later(c, ability.surgeAt, function()
		spellFx(c, "surge", { origin = origin, dir = dir, length = length, halfWidth = ability.surgeHalfWidth, position = gate })
		for _, enemy in ipairs(MageService.enemiesOnSegment(origin, dir, length, ability.surgeHalfWidth)) do
			if hit(c, enemy, ability.surge) and enemy.alive then
				EnemyService.stun(enemy, ability.stun)
			end
		end
	end)
	later(c, ability.closeAt, function()
		spellFx(c, "close", { position = gate, radius = ability.closeRadius, dir = dir })
		for _, enemy in ipairs(MageService.enemiesInRadius(gate, ability.closeRadius)) do
			hit(c, enemy, ability.close)
		end
	end)
	return { ok = true, radius = ability.surgeLength }
end

-- ===== Этаж 2 =====

-- Цветение лотоса: гейзер у ног (подброс), лечение, 8 лепестков-самонаводов.
CASTS.lotus_bloom = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local center = c.feet
	spellFx(c, "cast", { position = center, radius = ability.radius, geyserAt = ability.geyserAt, petals = ability.petals })
	later(c, ability.geyserAt, function()
		spellFx(c, "geyser", { position = center, radius = ability.radius })
		for _, enemy in ipairs(MageService.enemiesInRadius(center, ability.radius)) do
			if hit(c, enemy, ability.geyser) and enemy.alive then
				EnemyService.launch(enemy, ability.launch, 0.8)
			end
		end
		local _, humanoid = MageService.rootOf(player)
		if humanoid then
			MageService.heal(player, humanoid.MaxHealth * ability.heal)
		end
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				local otherRoot, otherHumanoid = MageService.rootOf(other)
				if otherRoot and flat(otherRoot.Position - center).Magnitude <= ability.radius then
					MageService.heal(other, otherHumanoid.MaxHealth * ability.allyHeal)
				end
			end
		end
		local targets = living(MageService.nearestEnemies(center, 20, ability.petals))
		for i = 1, ability.petals do
			local dir = rotate(c.look, (i - 1) * 360 / ability.petals)
			spellBolt(c, {
				origin = center + dir * 1.6 + Vector3.new(0, LootMage.BoltHeight, 0),
				dir = dir,
				speed = 28,
				size = 0.5,
				range = 20,
				style = "lotus",
				visual = "petal",
				homing = 300,
				target = pickFrom(targets, i),
				delay = 0.12 + i * 0.03,
				share = ability.petal,
			})
		end
	end)
	return { ok = true, radius = ability.radius }
end

-- Грибница (переделка 07.11): споры навесом засевают поляну R7 → поляна выдыхает ядовитое облако
-- (тики, яд, замедление) → грибы лопаются. Зона видна с момента посева.
CASTS.mycelium = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local center = pointAhead(c, ability.distance, 3)
	local radius = ability.radius
	local from = tipOf(c)
	spellFx(c, "cast", { position = center, radius = radius, from = from, spores = ability.spores, flight = ability.flight,
		gladeAt = ability.gladeAt, exhaleAt = ability.exhaleAt, cloudTime = ability.cloudTime })
	for i = 1, ability.spores do
		local angle = (i - 1) * math.pi * 2 / ability.spores + math.random() * 0.6
		local r = (i == 1) and 0 or radius * (0.35 + math.random() * 0.4)
		local to = MageService.groundAt(center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r))
		MageBolts.spawn({
			owner = player,
			origin = from,
			dir = c.aim,
			feetY = c.feet.Y,
			style = "spore",
			visual = "spore",
			size = 0.6,
			delay = 0.05 + (i - 1) * 0.06,
			lob = { to = to + Vector3.new(0, 0.4, 0), time = ability.flight, height = 4 + i * 0.4 },
			onEnd = function(_, position)
				if not player.Parent then
					return
				end
				local ground = MageService.groundAt(position)
				spellFx(c, "seed", { position = ground, index = i, radius = ability.seedRadius })
				for _, enemy in ipairs(MageService.enemiesInRadius(ground, ability.seedRadius)) do
					if hit(c, enemy, ability.spore) then
						debuff(c, enemy, "poison")
					end
				end
			end,
		})
	end
	later(c, ability.gladeAt, function()
		spellFx(c, "glade", { position = center, radius = radius, exhaleAt = ability.exhaleAt - ability.gladeAt })
	end)
	later(c, ability.exhaleAt, function()
		spellFx(c, "exhale", { position = center, radius = radius, duration = ability.cloudTime })
	end)
	MageService.zone({
		owner = player,
		center = center,
		radius = radius,
		delay = ability.exhaleAt,
		duration = ability.cloudTime,
		tick = ability.tick,
		onTick = function(enemies)
			for _, enemy in ipairs(enemies) do
				if hit(c, enemy, ability.cloudTick) and enemy.alive then
					EnemyService.slow(enemy, ability.slow, ability.tick + 0.3)
					debuff(c, enemy, "poison")
				end
			end
		end,
		onEnd = function()
			spellFx(c, "burst", { position = center, radius = radius })
			for _, enemy in ipairs(MageService.enemiesInRadius(center, radius)) do
				hit(c, enemy, ability.burst)
			end
		end,
	})
	return { ok = true, radius = radius }
end

-- Сад шипов: три кольца шипов расходятся от мага (яд, корни), затем сад замедляет и колет.
CASTS.thorn_garden = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local center = c.feet
	local gardenAt = ability.ringAt[#ability.ringAt]
	spellFx(c, "cast", { position = center, rings = ability.rings, ringAt = ability.ringAt, gardenAt = gardenAt,
		gardenTime = ability.gardenTime, radius = ability.radius })
	local struck = {}
	for i, radius in ipairs(ability.rings) do
		later(c, ability.ringAt[i], function()
			spellFx(c, "ring", { position = center, index = i, radius = radius })
			for _, enemy in ipairs(MageService.enemiesInRadius(center, radius, struck)) do
				struck[enemy] = true
				if hit(c, enemy, ability.ring) and enemy.alive then
					EnemyService.stun(enemy, ability.root)
					debuff(c, enemy, "poison")
				end
			end
		end)
	end
	later(c, gardenAt, function()
		spellFx(c, "garden", { position = center, radius = ability.radius, duration = ability.gardenTime })
	end)
	MageService.zone({
		owner = player,
		center = center,
		radius = ability.radius,
		delay = gardenAt,
		duration = ability.gardenTime,
		tick = ability.tick,
		onTick = function(enemies)
			for _, enemy in ipairs(enemies) do
				hit(c, enemy, ability.tickDamage)
				EnemyService.slow(enemy, ability.slow, ability.tick + 0.25)
			end
		end,
		onEnd = function()
			spellFx(c, "end", { position = center })
		end,
	})
	return { ok = true, radius = ability.radius }
end

-- ===== Этаж 3 =====

-- Призрачная стая (переделка 07.11): 4 волка окружают одну цель → вой: соседи в страхе бегут
-- (отброс + оглушение), цель прижата → укусы по очереди → общий прыжок с замедлением.
-- Цель погибла — стая переходит на ближайшего врага.
local function packTarget(c, near: Vector3, range: number, exclude)
	if c.target and c.target.alive and not (exclude and exclude[c.target]) then
		return c.target
	end
	return living(MageService.nearestEnemies(near, range, 3, exclude))[1]
end

CASTS.spirit_pack = function(player, weapon, ability, root)
	local first = (function()
		local feet = root.Position - Vector3.new(0, H.FEET, 0)
		local pick = MageService.bestTarget(feet + Vector3.new(0, LootMage.BoltHeight, 0), H.lookOf(root), ability.range, 60, feet.Y)
		if pick and not isObject(pick) then
			return pick
		end
		return living(MageService.nearestEnemies(feet, ability.range, 3))[1]
	end)()
	if not first then
		return { ok = false, reason = "no-target" }
	end
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	c.target = first
	local prey = first
	spellFx(c, "cast", { position = c.feet, dir = c.aim, model = prey.model, target = prey.position, wolves = ability.wolves,
		runTime = ability.runTime })
	later(c, ability.runTime, function()
		prey = packTarget(c, prey.position, 12) or prey
		spellFx(c, "surround", { model = prey.model, position = prey.position, wolves = ability.wolves })
	end)
	later(c, ability.howlAt, function()
		prey = packTarget(c, prey.position, 12) or prey
		if not prey.alive then
			return
		end
		local center = prey.position
		local feared = {}
		for _, enemy in ipairs(living(MageService.enemiesInRadius(center, ability.fearRadius, { [prey] = true }))) do
			if hit(c, enemy, ability.howl) and enemy.alive and not enemy.stats.isBoss then
				EnemyService.stun(enemy, ability.fear)
				EnemyService.shove(enemy, awayFrom(enemy, center, c.aim), ability.fearPush, ability.fear * 0.8)
				table.insert(feared, enemy.model)
			end
		end
		EnemyService.stun(prey, prey.stats.isBoss and ability.bossHold or ability.hold)
		spellFx(c, "howl", { position = center, model = prey.model, radius = ability.fearRadius, feared = feared, fear = ability.fear })
	end)
	for i = 1, ability.bites do
		later(c, ability.biteAt + (i - 1) * ability.biteEvery, function()
			local visited = {}
			if not prey.alive then
				visited[prey] = true
				prey = packTarget(c, prey.position, 10, visited) or prey
			end
			if not prey.alive then
				return
			end
			spellFx(c, "bite", { model = prey.model, position = prey.position, index = i, wolf = (i - 1) % ability.wolves + 1 })
			hit(c, prey, ability.bite)
		end)
	end
	later(c, ability.biteAt + ability.bites * ability.biteEvery + 0.15, function()
		if not prey.alive then
			prey = packTarget(c, prey.position, 10, { [prey] = true }) or prey
		end
		if not prey.alive then
			spellFx(c, "pounce", { position = prey.position })
			return
		end
		spellFx(c, "pounce", { model = prey.model, position = prey.position })
		if hit(c, prey, ability.pounce) and prey.alive then
			EnemyService.slow(prey, ability.slow, 3)
		end
	end)
	return { ok = true, radius = ability.range }
end

-- Охотничья луна: луна над полем, 8 лучей по врагам (по очереди), затем серп-волна.
CASTS.hunters_moon = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local center = pointAhead(c, ability.distance, 3)
	local firstAt = 0.35
	local crescentAt = firstAt + ability.beams * ability.beamEvery + 0.1
	spellFx(c, "cast", { position = center, height = ability.height, radius = ability.radius, beams = ability.beams,
		beamEvery = ability.beamEvery, firstAt = firstAt, crescentAt = crescentAt })
	local counts = {}
	for i = 1, ability.beams do
		later(c, firstAt + (i - 1) * ability.beamEvery, function()
			-- Луч в того, кого били реже всех; врагов нет — в случайную точку круга.
			local pick, best = nil, math.huge
			for _, enemy in ipairs(living(MageService.enemiesInRadius(center, ability.radius))) do
				local score = (counts[enemy] or 0) + math.random() * 0.5
				if score < best then
					pick, best = enemy, score
				end
			end
			local point
			if pick then
				counts[pick] = (counts[pick] or 0) + 1
				point = pick.position
			else
				point = randomInCircle(center, ability.radius * 0.8)
			end
			spellFx(c, "beam", { position = point, index = i, from = center + Vector3.new(0, ability.height, 0) })
			for _, enemy in ipairs(MageService.enemiesInRadius(point, 1.8)) do
				hit(c, enemy, ability.beam)
			end
		end)
	end
	later(c, crescentAt, function()
		spellFx(c, "crescent", { position = center, radius = ability.crescentRadius, dir = c.aim })
		for _, enemy in ipairs(MageService.enemiesInRadius(center, ability.crescentRadius)) do
			if hit(c, enemy, ability.crescent) then
				EnemyService.shove(enemy, awayFrom(enemy, center, c.aim), 2, 0.2)
			end
		end
	end)
	return { ok = true, radius = ability.radius }
end

-- Королевская ловля (посох Королевского ловчего, 07.11; было общее с косой воина имя last_hunt):
-- сеть навесом → R6 держит пойманных и подтягивает к центру → 3 копья с неба по самым живучим
-- (удар R2,5) → сеть рвётся. Своё заклинание, косой воина больше не рубит.
CASTS.royal_hunt = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local center = pointAhead(c, ability.distance, 4)
	local from = tipOf(c)
	local radius = ability.radius
	spellFx(c, "cast", { from = from, to = center, flight = ability.flight, radius = radius })
	MageBolts.spawn({
		owner = player,
		origin = from,
		dir = c.aim,
		feetY = c.feet.Y,
		style = "moon",
		visual = "big",
		size = 0.8,
		delay = 0.1,
		lob = { to = center + Vector3.new(0, 0.4, 0), time = ability.flight, height = 5 },
		onEnd = function(_, position)
			if not player.Parent then
				return
			end
			local ground = MageService.groundAt(position)
			local caught, models = {}, {}
			for _, enemy in ipairs(living(MageService.enemiesInRadius(ground, radius))) do
				table.insert(caught, enemy)
				table.insert(models, enemy.model)
				if hit(c, enemy, ability.net) and enemy.alive then
					EnemyService.stun(enemy, enemy.stats.isBoss and ability.bossHold or ability.hold)
					local toCenter = flat(ground - enemy.position)
					local room = toCenter.Magnitude - enemy.stats.radius - 0.8
					if room > 0.3 then
						EnemyService.shove(enemy, toCenter, math.min(ability.pull, room), 0.3)
					end
				end
			end
			spellFx(c, "net", { position = ground, radius = radius, models = models, hold = ability.hold })
			-- копья: по самым живучим пойманным, по кругу; никого — в центр сети
			table.sort(caught, function(a, b)
				return (a.health or 0) > (b.health or 0)
			end)
			for i = 1, ability.spears do
				later(c, ability.spearAt + (i - 1) * ability.spearEvery, function()
					local alive = living(caught)
					local enemy = pickFrom(alive, i)
					local point = enemy and enemy.position or randomInCircle(ground, radius * 0.4)
					spellFx(c, "spear", { position = point, model = enemy and enemy.model or nil, index = i,
						from = point + Vector3.new(0, 18, 0) - c.aim * 5, fall = 0.18, radius = ability.spearRadius })
					later(c, 0.18, function()
						for _, other in ipairs(MageService.enemiesInRadius(point, ability.spearRadius)) do
							hit(c, other, ability.spear)
						end
					end)
				end)
			end
			later(c, ability.tearAt, function()
				spellFx(c, "tear", { position = ground, radius = radius })
				for _, enemy in ipairs(MageService.enemiesInRadius(ground, radius)) do
					if hit(c, enemy, ability.tear) and enemy.alive then
						EnemyService.slow(enemy, ability.slow, 2.5)
						EnemyService.shove(enemy, awayFrom(enemy, ground, c.aim), 2, 0.2)
					end
				end
			end)
		end,
	})
	return { ok = true, radius = radius }
end

-- ===== Этаж 4 =====

-- Огненный дождь: круг впереди, метеоры падают по врагам и вокруг, горение.
CASTS.fire_rain = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local center = pointAhead(c, ability.distance, 4)
	local startAt = 0.25
	local fall = 0.45
	local every = ability.duration / ability.meteors
	spellFx(c, "cast", { position = center, radius = ability.radius, duration = ability.duration, startAt = startAt })
	for i = 1, ability.meteors do
		later(c, startAt + (i - 1) * every, function()
			local enemies = living(MageService.enemiesInRadius(center, ability.radius))
			local point
			if #enemies > 0 and math.random() < 0.65 then
				local enemy = enemies[math.random(#enemies)]
				point = randomInCircle(enemy.position, 1.2)
			else
				point = randomInCircle(center, ability.radius * 0.9)
			end
			local side = rotate(c.aim, 90) * (math.random() * 6 - 3)
			local from = point + Vector3.new(0, 22, 0) - c.aim * 7 + side
			spellFx(c, "meteor", { from = from, position = point, fall = fall, radius = ability.meteorRadius, index = i })
			later(c, fall, function()
				for _, enemy in ipairs(MageService.enemiesInRadius(point, ability.meteorRadius)) do
					if hit(c, enemy, ability.meteor) then
						debuff(c, enemy, "burn")
					end
				end
			end)
		end)
	end
	later(c, startAt + ability.duration + fall + 0.2, function()
		spellFx(c, "end", { position = center })
	end)
	return { ok = true, radius = ability.radius }
end

-- Кованая молния: удар с неба в цель и цепь по соседям. Без цели не тратится.
CASTS.forged_lightning = function(player, weapon, ability, root)
	local feet = root.Position - Vector3.new(0, H.FEET, 0)
	local look = H.lookOf(root)
	local first = MageService.bestTarget(feet + Vector3.new(0, LootMage.BoltHeight, 0), look, ability.range, 60, feet.Y)
	if not first or isObject(first) then
		first = living(MageService.nearestEnemies(feet, ability.range, 4))[1]
	end
	if not first then
		return { ok = false, reason = "no-target" }
	end
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local strikeAt = 0.25
	spellFx(c, "cast", { position = first.position, model = first.model, strikeAt = strikeAt })
	later(c, strikeAt, function()
		local target = first
		if not target.alive then
			target = living(MageService.nearestEnemies(first.position, ability.jumpRange, 2))[1]
			if not target then
				return
			end
		end
		spellFx(c, "strike", { position = target.position, model = target.model })
		if hit(c, target, ability.strike) and target.alive then
			EnemyService.stun(target, ability.stun)
		end
		local visited = { [target] = true }
		local points = { target.position }
		local links = {}
		local from, share = target, ability.strike
		for _ = 1, ability.jumps do
			local nextEnemy = living(MageService.nearestEnemies(from.position, ability.jumpRange, 2, visited))[1]
			if not nextEnemy then
				break
			end
			visited[nextEnemy] = true
			share *= ability.decay
			table.insert(points, nextEnemy.position)
			table.insert(links, { enemy = nextEnemy, share = share })
			from = nextEnemy
		end
		if #links > 0 then
			spellFx(c, "chain", { points = points })
			for index, link in ipairs(links) do
				later(c, 0.07 * index, function()
					if hit(c, link.enemy, link.share) and link.enemy.alive then
						EnemyService.stun(link.enemy, ability.stun)
					end
				end)
			end
		end
	end)
	return { ok = true, radius = ability.range }
end

-- Сердце горна: разлом по линии, огненные столбы с подбросом, стена огня.
CASTS.forge_heart = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local dir = c.aim
	local origin = c.feet + dir * 1.5
	local length = clearLength(origin, dir, ability.length)
	local wallAt = ability.crackTime + ability.pillars * 0.1 + 0.1
	spellFx(c, "cast", { origin = origin, dir = dir, length = length, crackTime = ability.crackTime, pillars = ability.pillars,
		wallAt = wallAt, wallTime = ability.wallTime, halfWidth = ability.wallHalfWidth })
	local struck = {}
	for i = 1, ability.pillars do
		local point = MageService.groundAt(origin + dir * (length * (i - 0.5) / ability.pillars))
		later(c, ability.crackTime + (i - 1) * 0.1, function()
			spellFx(c, "pillar", { position = point, radius = ability.pillarRadius, index = i })
			for _, enemy in ipairs(MageService.enemiesInRadius(point, ability.pillarRadius, struck)) do
				struck[enemy] = true
				if hit(c, enemy, ability.pillar) and enemy.alive then
					EnemyService.launch(enemy, ability.launch, 0.8)
					debuff(c, enemy, "burn")
				end
			end
		end)
	end
	later(c, wallAt, function()
		spellFx(c, "wall", { origin = origin, dir = dir, length = length, halfWidth = ability.wallHalfWidth, duration = ability.wallTime })
	end)
	MageService.zone({
		owner = player,
		center = origin,
		segment = { dir = dir, length = length, halfWidth = ability.wallHalfWidth },
		delay = wallAt,
		duration = ability.wallTime,
		tick = ability.tick,
		onTick = function(enemies)
			for _, enemy in ipairs(enemies) do
				hit(c, enemy, ability.tickDamage)
			end
		end,
		onEnd = function()
			spellFx(c, "end", { origin = origin })
		end,
	})
	return { ok = true, radius = ability.length }
end

-- Звезда горна: круг-прицел, через 1 с гигантский метеор (к краю слабее), лава.
CASTS.meteor = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local center = pointAhead(c, ability.distance, 4)
	local from = center + Vector3.new(0, 60, 0) - c.aim * 28
	spellFx(c, "cast", { position = center, radius = ability.radius, impactAt = ability.impactAt, from = from })
	later(c, ability.impactAt, function()
		spellFx(c, "impact", { position = center, radius = ability.radius, lavaRadius = ability.lavaRadius, lavaTime = ability.lavaTime })
		for _, enemy in ipairs(MageService.enemiesInRadius(center, ability.radius)) do
			local k = math.clamp(flat(enemy.position - center).Magnitude / ability.radius, 0, 1)
			if hit(c, enemy, ability.impact * (1 + (ability.edge - 1) * k)) and enemy.alive then
				EnemyService.shove(enemy, awayFrom(enemy, center, c.aim), ability.knockback * (1 - k * 0.5), 0.25)
				debuff(c, enemy, "burn")
			end
		end
	end)
	MageService.zone({
		owner = player,
		center = center,
		radius = ability.lavaRadius,
		delay = ability.impactAt,
		duration = ability.lavaTime,
		tick = ability.tick,
		onTick = function(enemies)
			for _, enemy in ipairs(enemies) do
				hit(c, enemy, ability.tickDamage)
			end
		end,
		onEnd = function()
			spellFx(c, "end", { position = center })
		end,
	})
	return { ok = true, radius = ability.radius }
end

-- Первая плавка (секретка): круг R14, 8 разломов с лучами по кругу, затем сверхновая.
CASTS.first_cast = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local center = c.feet
	spellFx(c, "cast", { position = center, radius = ability.radius, rifts = ability.rifts, riftAt = ability.riftAt,
		riftEvery = ability.riftEvery, novaAt = ability.novaAt, dir = c.look })
	for i = 1, ability.rifts do
		local dir = rotate(c.look, (i - 1) * 360 / ability.rifts)
		local origin = center + dir * ability.riftFrom
		local length = clearLength(origin, dir, ability.radius - ability.riftFrom)
		later(c, ability.riftAt + (i - 1) * ability.riftEvery, function()
			spellFx(c, "rift", { origin = origin, dir = dir, length = length, index = i, halfWidth = ability.riftHalfWidth })
			for _, enemy in ipairs(MageService.enemiesOnSegment(origin, dir, length, ability.riftHalfWidth)) do
				hit(c, enemy, ability.rift)
			end
		end)
	end
	later(c, ability.novaAt, function()
		spellFx(c, "nova", { position = center, radius = ability.radius })
		for _, enemy in ipairs(MageService.enemiesInRadius(center, ability.radius)) do
			local k = math.clamp(flat(enemy.position - center).Magnitude / ability.radius, 0, 1)
			if hit(c, enemy, ability.nova * (1 + (ability.edge - 1) * k)) and enemy.alive then
				debuff(c, enemy, "burn")
				EnemyService.launch(enemy, ability.launch, 0.9)
			end
		end
	end)
	return { ok = true, radius = ability.radius }
end

-- ===== Этаж 5 =====

-- Раскрытая книга: фолиант над магом выпускает самонаводящиеся глифы, затем буря страниц.
CASTS.open_tome = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local startAt = 0.3
	spellFx(c, "cast", { glyphs = ability.glyphs, glyphEvery = ability.glyphEvery, startAt = startAt,
		stormAt = ability.stormAt, radius = ability.stormRadius })
	for i = 1, ability.glyphs do
		later(c, startAt + (i - 1) * ability.glyphEvery, function()
			local r = MageService.rootOf(player)
			if not r then
				return
			end
			local feet = r.Position - Vector3.new(0, H.FEET, 0)
			local look = H.lookOf(r)
			local targets = living(MageService.nearestEnemies(feet, 20, 6))
			local side = rotate(look, 90) * (((i % 3) - 1) * 0.9)
			spellBolt(c, {
				origin = feet + Vector3.new(0, 6, 0) + side - look * 0.4,
				dir = rotate(look, (math.random() * 2 - 1) * 70),
				speed = 30,
				size = 0.45,
				range = 22,
				style = "page",
				visual = "glyph",
				homing = 360,
				target = pickFrom(targets, i),
				share = ability.glyph,
			})
		end)
	end
	later(c, ability.stormAt, function()
		local center = feetNow(c)
		spellFx(c, "storm", { position = center, radius = ability.stormRadius })
		for _, enemy in ipairs(MageService.enemiesInRadius(center, ability.stormRadius)) do
			hit(c, enemy, ability.storm)
		end
	end)
	return { ok = true, radius = ability.stormRadius }
end

-- Остановка времени (доработка 07.11): циферблат R10 — враги замирают (боссы короче), стрелка дважды
-- обходит круг и режет всех, удар стрелок; затем стрелки идут назад — маг возвращает часть
-- здоровья, потерянного за последние секунды. Отличие от «Печати» воина — откат времени.
local damageLog = {} -- [player] = { { t, amount } }

local function trackDamage(player)
	local function watch(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		local last = humanoid.Health
		humanoid.HealthChanged:Connect(function(health)
			if health < last then
				local log = damageLog[player]
				if not log then
					log = {}
					damageLog[player] = log
				end
				table.insert(log, { t = H.now(), amount = last - health })
				if #log > 40 then
					table.remove(log, 1)
				end
			end
			last = health
		end)
	end
	if player.Character then
		task.spawn(watch, player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

local function damageSince(player, seconds: number): number
	local total, from = 0, H.now() - seconds
	for _, entry in ipairs(damageLog[player] or {}) do
		if entry.t >= from then
			total += entry.amount
		end
	end
	return total
end
WeaponAbilitiesMage.damageSince = damageSince

CASTS.time_stop = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local center = c.feet
	local freezeAt = 0.3
	spellFx(c, "cast", { position = center, radius = ability.radius, freezeAt = freezeAt, freeze = ability.freeze, dir = c.look })
	later(c, freezeAt, function()
		local frozen, models = {}, {}
		for _, enemy in ipairs(living(MageService.enemiesInRadius(center, ability.radius))) do
			local duration = enemy.stats.isBoss and ability.bossFreeze or ability.freeze
			EnemyService.stun(enemy, duration, true)
			if enemy.model then
				enemy.model:SetAttribute("MageFrozenUntil", H.now() + duration)
			end
			frozen[enemy] = true
			table.insert(models, enemy.model)
		end
		spellFx(c, "freeze", { position = center, radius = ability.radius, models = models, duration = ability.freeze })
		local sweepTime = ability.freeze / (ability.sweeps + 1)
		for i = 1, ability.sweeps do
			later(c, sweepTime * i, function()
				spellFx(c, "sweep", { position = center, radius = ability.radius, index = i, time = sweepTime * 0.8, dir = c.look })
				for _, enemy in ipairs(MageService.enemiesInRadius(center, ability.radius)) do
					hit(c, enemy, ability.sweep)
				end
			end)
		end
		later(c, ability.freeze, function()
			spellFx(c, "strike", { position = center, radius = ability.radius, dir = c.look })
			for enemy in pairs(frozen) do
				hit(c, enemy, ability.strike)
			end
			for _, enemy in ipairs(MageService.enemiesInRadius(center, ability.radius, frozen)) do
				hit(c, enemy, ability.strike)
			end
			-- откат: часть урона, полученного за rewindWindow секунд до удара стрелок
			local lost = damageSince(player, ability.rewindWindow)
			local amount = lost * ability.rewind
			if amount > 0 then
				MageService.heal(player, amount)
			end
			spellFx(c, "rewind", { position = feetNow(c), radius = ability.radius, amount = math.floor(amount + 0.5) })
		end)
	end)
	return { ok = true, radius = ability.radius }
end

-- Строка судьбы: строка письмен по линии, через 0,8 с вспыхивает лучом, цели уязвимы.
CASTS.fate_line = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local dir = c.aim
	local origin = c.feet + dir * 1.0
	local length = clearLength(origin, dir, ability.length)
	spellFx(c, "cast", { origin = origin, dir = dir, length = length, halfWidth = ability.halfWidth, igniteAt = ability.igniteAt })
	later(c, ability.igniteAt, function()
		spellFx(c, "ignite", { origin = origin, dir = dir, length = length, halfWidth = ability.halfWidth })
		for _, enemy in ipairs(MageService.enemiesOnSegment(origin, dir, length, ability.halfWidth)) do
			if hit(c, enemy, ability.beam) and enemy.alive then
				EnemyService.setVulnerable(enemy, ability.vulnerable, ability.vulnerableTime)
			end
		end
	end)
	return { ok = true, radius = ability.length }
end

-- Чёрная клякса: капля чернил навесом, воронка стягивает и жжёт, затем взрыв.
CASTS.ink_hole = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local to = pointAhead(c, ability.distance, 3)
	local from = tipOf(c)
	spellFx(c, "cast", { from = from, to = to, flight = ability.flight, delay = 0.15 })
	MageBolts.spawn({
		owner = player,
		origin = from,
		dir = c.aim,
		feetY = c.feet.Y,
		style = "ink",
		visual = "inkdrop",
		size = 0.9,
		delay = 0.15,
		lob = { to = to + Vector3.new(0, 0.4, 0), time = ability.flight, height = 3 },
		onEnd = function(_, position)
			if not player.Parent then
				return
			end
			local center = MageService.groundAt(position)
			spellFx(c, "open", { position = center, radius = ability.radius, pullTime = ability.pullTime, blastRadius = ability.blastRadius })
			MageService.zone({
				owner = player,
				center = center,
				radius = ability.radius,
				duration = ability.pullTime,
				tick = ability.tick,
				onTick = function(enemies)
					for _, enemy in ipairs(enemies) do
						hit(c, enemy, ability.tickDamage)
						local toCenter = flat(center - enemy.position)
						local room = toCenter.Magnitude - enemy.stats.radius - 0.6
						if room > 0.2 then
							EnemyService.shove(enemy, toCenter, math.min(ability.pull, room), ability.tick * 0.9)
						end
					end
				end,
				onEnd = function()
					spellFx(c, "blast", { position = center, radius = ability.blastRadius })
					for _, enemy in ipairs(MageService.enemiesInRadius(center, ability.blastRadius)) do
						if hit(c, enemy, ability.blast) and enemy.alive then
							EnemyService.shove(enemy, awayFrom(enemy, center, c.aim), 2.5, 0.22)
						end
					end
				end,
			})
		end,
	})
	return { ok = true, radius = ability.radius }
end

-- Вспомнить всё (секретка): 3 эха мага бьют лучами (2 залпа), затем шторм сфер памяти.
CASTS.total_recall = function(player, weapon, ability, root)
	local c = begin(player, weapon, ability, root)
	if not c then
		return noMana()
	end
	local center = c.feet
	local echoes = {}
	for i = 1, ability.echoes do
		local dir = rotate(c.look, 180 + (i - (ability.echoes + 1) / 2) * 75)
		local length = clearLength(center, dir, ability.echoRadius)
		echoes[i] = MageService.groundAt(center + dir * length)
	end
	spellFx(c, "cast", { position = center, echoes = echoes, beamAt = ability.beamAt, stormAt = ability.stormAt, dir = c.look })
	for salvo, at in ipairs(ability.beamAt) do
		later(c, at, function()
			local used, beams = {}, {}
			for _, pos in ipairs(echoes) do
				local target = living(MageService.nearestEnemies(pos, ability.beamRange, 4, used))[1]
					or living(MageService.nearestEnemies(pos, ability.beamRange, 2))[1]
				local dir = c.look
				if target then
					used[target] = true
					local rel = flat(target.position - pos)
					if rel.Magnitude > 0.5 then
						dir = rel.Unit
					end
				end
				local length = clearLength(pos, dir, ability.beamRange)
				table.insert(beams, { from = pos, dir = dir, length = length })
				for _, enemy in ipairs(MageService.enemiesOnSegment(pos, dir, length, 1.3)) do
					hit(c, enemy, ability.beam)
				end
			end
			spellFx(c, "beams", { salvo = salvo, beams = beams })
		end)
	end
	later(c, ability.stormAt, function()
		local feet = feetNow(c)
		spellFx(c, "storm", { position = feet, radius = ability.stormRadius, orbs = ability.orbs })
		local targets = living(MageService.nearestEnemies(feet, ability.stormRadius, 8))
		for i = 1, ability.orbs do
			local dir = rotate(c.look, (i - 1) * 360 / ability.orbs)
			spellBolt(c, {
				origin = feet + dir * 1.2 + Vector3.new(0, LootMage.BoltHeight + 0.4, 0),
				dir = dir,
				speed = 22,
				size = 0.5,
				range = ability.stormRadius + 4,
				style = "memory",
				visual = "orb",
				homing = 260,
				target = pickFrom(targets, i),
				delay = (i % 4) * 0.05,
				share = ability.orb,
			})
		end
	end)
	return { ok = true, radius = ability.stormRadius }
end

function WeaponAbilitiesMage.install(helpers)
	H = helpers
	for _, player in ipairs(Players:GetPlayers()) do
		trackDamage(player)
	end
	Players.PlayerAdded:Connect(trackDamage)
	Players.PlayerRemoving:Connect(function(player)
		damageLog[player] = nil
	end)
	return { casts = CASTS }
end

WeaponAbilitiesMage.casts = CASTS

return WeaponAbilitiesMage
