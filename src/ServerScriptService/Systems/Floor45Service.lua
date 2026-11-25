--!nonstrict
-- Floor45Service
-- Поведение врагов этажей 4 «Литейные» и 5 «Зал хроник» (Config/Enemies45).
-- Подключение — как у Floor2Service: хук EnemyService.spawnHooks вешает на
-- врага onWindup / onStrike / onDamage / brain / onKilled. Числа — в
-- Enemies45 и Floor4/Floor5 (Traps). Клиенту — EnemyEvent с kind f45*
-- (Controllers/Floor45Fx).
--
--   лужи       molten (расплав: урон за тик + ожог), ink (чернила: вязко),
--              erase (стирание: урон за тик) — addHazard / sendHazardsTo
--   статусы    ожог (burn) — свой; замедление и корни — Floor2Service
--   броня      нагрудник автомата и книга-щит чтеца: спереди урон режется
--   конусы     выдох жара автомата, разлив ковша литейщика
--   веера      страницы хранителя полок и Хрониста
--   печати     маг неуязвим, пока цела его печать (ward_seal)
--   призыв     кляксы писаря; нити и рывок-стежок Переплётчика; луч Хрониста
--
-- Фазы боссов, завязанные на карту (жёлоба горна, печати купола, стирание
-- краёв) — в Floor4World / Floor5World: им нужны точки зон.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enemies = require(Shared.Config.Enemies)
local Floor4 = require(Shared.Config.Floor4)
local Floor5 = require(Shared.Config.Floor5)
local FloorGeo = require(Shared.Floor.FloorGeo)
local Net = require(Shared.Net.Net)

local EnemyService = require(script.Parent.EnemyService)
local ProjectileService = require(script.Parent.ProjectileService)
local CombatService = require(script.Parent.CombatService)
local Floor2Service = require(script.Parent.Floor2Service)
-- «Стойкость» (древо воина): дебафы на герое короче на 20%.
local TalentMods = require(script.Parent.TalentMods)

local Floor45Service = {}

local FEET = 3.0
local TICK = 0.1

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function unitOr(v: Vector3, fallback: Vector3): Vector3
	local f = flat(v)
	if f.Magnitude < 0.001 then
		return fallback
	end
	return f.Unit
end

local function fire(payload)
	EnemyService.fireEvent(payload)
end

local function groundY(x: number, z: number, nearY: number): number
	return FloorGeo.groundAt(x, z, nearY + 1) or nearY
end

local function playersIn(test)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = EnemyService.livingRoot(player)
		if root and test(root) then
			table.insert(list, { player = player, root = root })
		end
	end
	return list
end

-- ======================================================================
-- Ожог (свой статус): доля MaxHealth в секунду, тик 0,5 с, не добивает
-- ======================================================================

local burns = {} -- [player] = { pct, untilT, nextTick }

function Floor45Service.burn(player, pct: number, duration: number)
	if not player or not pct or pct <= 0 then
		return
	end
	duration *= TalentMods.debuffScale(player)
	local t = now()
	local entry = burns[player]
	if not entry then
		entry = { pct = 0, untilT = 0, nextTick = t + 0.5 }
		burns[player] = entry
	end
	entry.pct = math.max(t < entry.untilT and entry.pct or 0, pct)
	entry.untilT = math.max(entry.untilT, t + duration)
	player:SetAttribute("BurnUntil", entry.untilT)
end

local function stepBurns(t: number)
	for player, entry in pairs(burns) do
		if not player.Parent then
			burns[player] = nil
			continue
		end
		if t >= entry.untilT then
			burns[player] = nil
			continue
		end
		if t >= entry.nextTick then
			entry.nextTick = t + 0.5
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and not player:GetAttribute("DebugGod") then
				humanoid.Health = math.max(1, humanoid.Health - humanoid.MaxHealth * entry.pct * 0.5)
			end
		end
	end
end

-- Последствия попадания атаки (ожог, корни, замедление).
local function applyOnHit(enemy, attack, player)
	if not player then
		return
	end
	if attack and attack.burn then
		Floor45Service.burn(player, attack.burn.pct, attack.burn.time)
	end
	if attack and attack.root then
		Floor2Service.root(player, attack.root)
	end
	if attack and attack.slow then
		Floor2Service.slow(player, attack.slow.mul, attack.slow.time)
	end
	local traits = enemy.stats.traits
	if traits and traits.burnOnHit then
		Floor45Service.burn(player, traits.burnOnHit.pct, traits.burnOnHit.time)
	end
end

-- Свой многоцелевой удар: последствия накладываем сами, сигнал «hit» глушим.
local function resolveMany(enemy, attack, targets)
	local any = "out-of-range"
	enemy.suppressHitFx = true
	for _, target in ipairs(targets) do
		local result = EnemyService.resolveOnPlayer(enemy, attack, target.player)
		if result == "hit" then
			applyOnHit(enemy, attack, target.player)
			any = "hit"
		elseif any ~= "hit" then
			any = result
		end
	end
	enemy.suppressHitFx = false
	enemy.model:SetAttribute("LastAttackResult", any)
	return any
end

-- ======================================================================
-- Лужи: расплав, чернила, стирание
-- ======================================================================

local HAZARD_TICK = {
	molten = Floor4.Traps.molten.tick,
	ink = 0.25,
	erase = Floor5.Traps.erase.tick,
}

local HAZARD = {
	molten = function(player, hazard)
		local cfg = Floor4.Traps.molten
		CombatService.damagePlayer(player, cfg.damage, { source = "Расплав", position = hazard.center })
		Floor45Service.burn(player, cfg.burn.pct, cfg.burn.time)
	end,
	ink = function(player)
		local cfg = Floor5.Traps.ink
		Floor2Service.slowFromPuddle(player, cfg.slow)
	end,
	erase = function(player, hazard)
		CombatService.damagePlayer(player, hazard.damage or Floor5.Traps.erase.damage, { source = "Стирание", position = hazard.center })
	end,
}

local hazards = {}
local hazardId = 0

-- life — сколько живёт лужа, с. extra: damage (для erase), floorId.
function Floor45Service.addHazard(kind: string, center: Vector3, radius: number, life: number, extra)
	life = math.min(life, 1e6)
	hazardId += 1
	local y = groundY(center.X, center.Z, center.Y)
	local hazard = {
		id = hazardId,
		kind = kind,
		center = Vector3.new(center.X, y, center.Z),
		radius = radius,
		untilT = now() + life,
		nextTick = {},
		damage = extra and extra.damage,
	}
	table.insert(hazards, hazard)
	fire({ kind = "f45hazard", id = hazard.id, hazard = kind, position = hazard.center, radius = radius, life = life })
	return hazard
end

function Floor45Service.removeHazard(hazard)
	for index, h in ipairs(hazards) do
		if h == hazard then
			table.remove(hazards, index)
			fire({ kind = "f45hazardEnd", id = hazard.id })
			return
		end
	end
end

local function stepHazards(t: number)
	for index = #hazards, 1, -1 do
		local hazard = hazards[index]
		if t >= hazard.untilT then
			table.remove(hazards, index)
		else
			local apply = HAZARD[hazard.kind]
			local every = HAZARD_TICK[hazard.kind] or 0.5
			if apply then
				for _, hit in ipairs(playersIn(function(root)
					return flat(root.Position - hazard.center).Magnitude <= hazard.radius
						and math.abs(root.Position.Y - FEET - hazard.center.Y) < 3
				end)) do
					local nextAt = hazard.nextTick[hit.player] or 0
					if t >= nextAt then
						hazard.nextTick[hit.player] = t + every
						apply(hit.player, hazard)
					end
				end
			end
		end
	end
end

function Floor45Service.sendHazardsTo(player)
	local remote = Net.get("EnemyEvent")
	if not remote then
		return
	end
	local t = now()
	for _, hazard in ipairs(hazards) do
		remote:FireClient(player, {
			kind = "f45hazard",
			id = hazard.id,
			hazard = hazard.kind,
			position = hazard.center,
			radius = hazard.radius,
			life = math.max(hazard.untilT - t, 0.1),
		})
	end
end

-- Убрать лужи этажа (при пересборке): по полосе X вокруг смещения этажа.
function Floor45Service.clearHazards(offsetX: number?)
	for index = #hazards, 1, -1 do
		local hazard = hazards[index]
		if not offsetX or math.abs(hazard.center.X - offsetX) < 600 then
			table.remove(hazards, index)
		end
	end
	fire({ kind = "f45hazardClear", offsetX = offsetX })
end

-- Убрать лужи внутри бокса зоны { x0, y0, z0, x1, y1, z1 } (сброс арены, смерть босса).
function Floor45Service.clearHazardsIn(box)
	for index = #hazards, 1, -1 do
		local hazard = hazards[index]
		local c = hazard.center
		if c.X >= box[1] and c.X <= box[4] and c.Y >= box[2] - 2 and c.Y <= box[5] and c.Z >= box[3] and c.Z <= box[6] then
			table.remove(hazards, index)
			fire({ kind = "f45hazardEnd", id = hazard.id })
		end
	end
end

-- ======================================================================
-- Призыв: через зону этажа (FloorService.spawnEnemy), иначе напрямую
-- ======================================================================

local spawners = {} -- function(zone, typeId, position) → enemy | nil

function Floor45Service.registerSpawner(fn)
	table.insert(spawners, fn)
end

function Floor45Service.spawnMinion(owner, typeId: string, position: Vector3)
	if owner.room then
		for _, spawner in ipairs(spawners) do
			local ok, enemy = pcall(spawner, owner.room, typeId, position)
			if ok and enemy then
				enemy.summoned = true
				return enemy
			end
		end
	end
	local stats = Enemies.stats(typeId, owner.stats.difficulty)
	local enemy = EnemyService.spawn(stats, position, { parent = owner.model.Parent, room = owner.room, bounds = owner.bounds })
	enemy.summoned = true
	return enemy
end

-- Свободная точка рядом с врагом (не за стеной).
local function pointNear(enemy, distance: number, preferDir: Vector3?): Vector3
	local origin = enemy.position + Vector3.new(0, 1.5, 0)
	local base = math.random() * math.pi * 2
	if preferDir then
		base = math.atan2(preferDir.Z, preferDir.X)
	end
	for attempt = 0, 7 do
		local angle = base + attempt * (math.pi / 4) * ((attempt % 2 == 0) and 1 or -1)
		local d = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local wall = FloorGeo.raycast(origin, d * (distance + 1.5))
		if not wall then
			return enemy.position + d * distance
		end
	end
	return enemy.position
end

-- ======================================================================
-- Общие удары
-- ======================================================================

-- Лужи в центрах зон атаки (бросок шлака, брызги, стирание).
local function puddlesAtZones(enemy, attack)
	local puddle = attack.puddle
	if not puddle then
		return
	end
	for _, center in ipairs(enemy.zoneCenters or {}) do
		Floor45Service.addHazard(puddle.kind, center, puddle.radius or attack.radius, puddle.life)
	end
end

-- Конус перед врагом (выдох жара, разлив ковша): один удар всем внутри.
local function coneStrike(enemy, attack, t: number, kindName: string)
	local dir = enemy.coneDir or enemy.facing
	enemy.coneDir = nil
	local cosHalf = math.cos(math.rad(attack.cone / 2))
	local targets = playersIn(function(root)
		local rel = flat(root.Position - enemy.position)
		local distance = rel.Magnitude
		if distance > attack.length + 0.8 or math.abs(root.Position.Y - FEET - enemy.position.Y) > 4 then
			return false
		end
		return distance < 1.5 or dir:Dot(rel.Unit) >= cosHalf
	end)
	resolveMany(enemy, attack, targets)
	enemy.model:SetAttribute("F45Cone", nil)
	fire({ kind = "f45cone", model = enemy.model, cone = kindName, origin = enemy.position, direction = dir, angle = attack.cone, length = attack.length })
	if attack.puddle and (attack.puddles or 0) > 0 then
		for index = 1, attack.puddles do
			local distance = attack.length * (index / (attack.puddles + 0.5))
			local spread = (index % 2 == 0) and 1 or -1
			local side = Vector3.new(-dir.Z, 0, dir.X) * spread * math.min(distance * 0.25, 2.5)
			Floor45Service.addHazard(attack.puddle.kind, enemy.position + dir * distance + side, attack.puddle.radius, attack.puddle.life)
		end
	end
	EnemyService.startRecover(enemy, t)
	return true
end

local function markCone(enemy, attack, root)
	enemy.coneDir = root and unitOr(root.Position - enemy.position, enemy.facing) or enemy.facing
	enemy.model:SetAttribute("F45Cone", ("%d,%.1f,%.3f,%.3f"):format(attack.cone, attack.length, enemy.coneDir.X, enemy.coneDir.Z))
end

-- Веер снарядов по зафиксированному прицелу.
local function fireSpread(enemy, attack, root)
	local origin = enemy.position + Vector3.new(0, enemy.stats.height * 0.6, 0) + enemy.facing * 0.8
	local target = enemy.aimPoint or root.Position
	enemy.aimPoint = nil
	local direction = target - origin
	if direction.Magnitude < 0.5 then
		return
	end
	direction = direction.Unit
	local count = attack.spread or 1
	local step = math.rad(attack.spreadAngle or 10)
	for index = 1, count do
		local angle = (index - (count + 1) / 2) * step
		local d = CFrame.Angles(0, angle, 0):VectorToWorldSpace(direction)
		ProjectileService.fire(enemy.model, origin, d, {
			speed = attack.projectileSpeed,
			damage = attack.damage,
			parryable = attack.telegraph == "parryable",
			source = enemy.stats.name,
			shooter = enemy,
			kind = attack.projectileKind,
		})
	end
	enemy.model:SetAttribute("LastAttackResult", "projectile")
end

-- Броня спереди (нагрудник автомата, книга-щит чтеца).
local function attachFrontArmor(enemy, cfg)
	local cosArc = math.cos(math.rad(cfg.arc / 2))
	local previous = enemy.onDamage
	enemy.onDamage = function(e, amount, attacker, info)
		if previous then
			amount = previous(e, amount, attacker, info) or amount
			if amount <= 0 then
				return 0
			end
		end
		local character = attacker and attacker.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or e.state == "stunned" then
			return amount
		end
		local to = unitOr(root.Position - e.position, e.facing)
		if e.facing:Dot(to) >= cosArc then
			fire({ kind = "f45armor", model = e.model, position = e.position + Vector3.new(0, e.stats.height * 0.55, 0) + to * e.stats.radius })
			return amount * (1 - cfg.block)
		end
		return amount
	end
end

-- Линии (нити Переплётчика): как корни Садовницы этажа 2.
local function markLines(enemy, attack, root)
	local base = unitOr(root.Position - enemy.position, enemy.facing)
	local origin = enemy.position + Vector3.new(0, 1.5, 0)
	local lines, encoded = {}, {}
	for index = 1, attack.lines do
		local angle = math.rad((index - (attack.lines + 1) / 2) * attack.lineSpread)
		local d = flat(CFrame.Angles(0, angle, 0):VectorToWorldSpace(base)).Unit
		local length = attack.lineLength
		local wall = FloorGeo.raycast(origin, d * length)
		if wall then
			length = math.max(3, flat(wall.Position - origin).Magnitude - 0.5)
		end
		table.insert(lines, { dir = d, length = length })
		table.insert(encoded, ("%.3f,%.3f,%.1f"):format(d.X, d.Z, length))
	end
	enemy.lines = lines
	enemy.linesOrigin = enemy.position
	enemy.model:SetAttribute("F45LinesOrigin", enemy.position)
	enemy.model:SetAttribute("F45LinesWidth", attack.lineWidth)
	enemy.model:SetAttribute("F45Lines", table.concat(encoded, ";"))
end

local function strikeLines(enemy, attack, t: number, kindName: string)
	local lines, origin = enemy.lines or {}, enemy.linesOrigin or enemy.position
	local targets = playersIn(function(root)
		local rel = flat(root.Position - origin)
		if math.abs(root.Position.Y - FEET - origin.Y) >= 4 then
			return false
		end
		for _, line in ipairs(lines) do
			local along = rel:Dot(line.dir)
			local side = (rel - line.dir * along).Magnitude
			if along > 0 and along < line.length + 0.6 and side <= attack.lineWidth / 2 + 0.8 then
				return true
			end
		end
		return false
	end)
	resolveMany(enemy, attack, targets)
	enemy.model:SetAttribute("F45Lines", nil)
	fire({ kind = "f45lines", model = enemy.model, lines = lines, origin = origin, width = attack.lineWidth, style = kindName })
	enemy.lines = nil
	EnemyService.startRecover(enemy, t)
	return true
end

-- Луч (Хронист): прямая от врага, направление — с начала замаха.
local function markBeam(enemy, attack, root)
	local dir = unitOr(root.Position - enemy.position, enemy.facing)
	local origin = enemy.position + Vector3.new(0, 1.5, 0)
	local length = attack.beam.length
	local wall = FloorGeo.raycast(origin, dir * length)
	if wall then
		length = math.max(4, flat(wall.Position - origin).Magnitude - 0.3)
	end
	enemy.beam = { dir = dir, length = length, origin = enemy.position }
	enemy.model:SetAttribute("F45Beam", ("%.3f,%.3f,%.3f,%.3f,%.3f,%.1f,%.2f"):format(
		enemy.position.X, enemy.position.Y, enemy.position.Z, dir.X, dir.Z, length, attack.beam.width))
end

local function strikeBeam(enemy, attack, t: number)
	local beam = enemy.beam
	enemy.beam = nil
	enemy.model:SetAttribute("F45Beam", nil)
	if not beam then
		EnemyService.startRecover(enemy, t)
		return true
	end
	local targets = playersIn(function(root)
		local rel = flat(root.Position - beam.origin)
		local along = rel:Dot(beam.dir)
		local side = (rel - beam.dir * along).Magnitude
		return along > -1 and along < beam.length + 0.5 and side <= attack.beam.width / 2 + 0.8
			and math.abs(root.Position.Y - FEET - beam.origin.Y) < 5
	end)
	resolveMany(enemy, attack, targets)
	fire({ kind = "f45beam", model = enemy.model, origin = beam.origin, direction = beam.dir, length = beam.length, width = attack.beam.width })
	EnemyService.startRecover(enemy, t)
	return true
end

-- Отскок от игрока (хранитель полок), как у следопыта этажа 2.
local function hopBrain(enemy, hop)
	return function(e, t, player, root, distance)
		if player and root and distance and distance < hop.range and t >= (e.hopReadyAt or 0) and e.state ~= "windup" then
			e.hopReadyAt = t + hop.cooldown
			local away = unitOr(e.position - root.Position, -e.facing)
			if EnemyService.shove(e, away, hop.distance, hop.time) then
				fire({ kind = "f45hop", model = e.model, position = e.position })
			end
		end
		return false
	end
end

-- ======================================================================
-- Поведение по типам
-- ======================================================================

local attachers = {}
local active = {} -- враги с покадровой логикой

attachers.forge_automaton = function(enemy)
	local traits = enemy.stats.traits
	attachFrontArmor(enemy, traits.frontArmor)
	enemy.onWindup = function(e, attack, _, root)
		if attack.id == "blast" then
			markCone(e, attack, root)
		end
	end
	enemy.onStrike = function(e, attack, t)
		if attack.id == "blast" then
			return coneStrike(e, attack, t, "blast")
		end
		if attack.id == traits.vent.after then
			-- После сотрясения: клапаны стравливают пар, автомат открыт.
			task.delay(0.35, function()
				if e.alive then
					EnemyService.setVulnerable(e, traits.vent.vulnerable, traits.vent.time)
					e.model:SetAttribute("F45VentUntil", now() + traits.vent.time)
					fire({ kind = "f45vent", model = e.model, position = e.position, duration = traits.vent.time })
				end
			end)
		end
		return false
	end
end

attachers.fire_spirit = function(_) end -- ожог от когтей — через сигнал попадания (traits.burnOnHit)

attachers.slag_thrower = function(enemy)
	enemy.onStrike = function(e, attack)
		if attack.id == "lob" then
			puddlesAtZones(e, attack)
			fire({ kind = "f45lob", model = e.model, from = e.position + Vector3.new(0, e.stats.height * 0.7, 0), positions = e.zoneCenters })
		end
		return false
	end
end

attachers.smolder = function(enemy)
	enemy.onKilled = function(e)
		local puddle = e.stats.traits.deathPuddle
		Floor45Service.addHazard(puddle.kind, e.position, puddle.radius, puddle.life)
	end
end

attachers.elder_founder = function(enemy)
	enemy.home = enemy.position
	enemy.onWindup = function(e, attack, _, root)
		if attack.id == "pour" then
			markCone(e, attack, root)
		end
	end
	enemy.onStrike = function(e, attack, t)
		if attack.id == "pour" then
			return coneStrike(e, attack, t, "pour")
		end
		if attack.id == "splash" then
			puddlesAtZones(e, attack)
			fire({ kind = "f45lob", model = e.model, from = e.position + Vector3.new(0, e.stats.height * 0.6, 0), positions = e.zoneCenters, big = true })
			return false
		end
		if attack.id == "leap" then
			e.landing = { at = e.attackCenter, attack = attack }
			return false
		end
		return false
	end
	active[enemy] = true
end

attachers.stone_reader = function(enemy)
	attachFrontArmor(enemy, enemy.stats.traits.frontArmor)
	enemy.onStrike = function(e, attack)
		if attack.id == "recital" then
			fire({ kind = "f45recital", model = e.model, position = e.position, radius = attack.radius })
		end
		return false
	end
end

attachers.seal_mage = function(enemy)
	local ward = enemy.stats.traits.ward
	local mage = enemy
	task.defer(function()
		if not mage.alive or not mage.model.Parent then
			return
		end
		local seal = Floor45Service.spawnMinion(mage, ward.typeId, pointNear(mage, ward.offset))
		mage.ward = seal
		seal.wardOwner = mage
		mage.model:SetAttribute("F45WardAt", seal.position + Vector3.new(0, 2.2, 0))
		fire({ kind = "f45ward", model = mage.model, seal = seal.model, position = seal.position })
	end)
	enemy.onDamage = function(e, amount)
		if e.ward and e.ward.alive then
			fire({ kind = "f45wardBlock", model = e.model, position = e.position + Vector3.new(0, e.stats.height * 0.55, 0) })
			return 0
		end
		return amount
	end
	enemy.onKilled = function(e)
		e.model:SetAttribute("F45WardAt", nil)
		if e.ward and e.ward.alive then
			EnemyService.kill(e.ward, nil)
		end
	end
end

attachers.ward_seal = function(enemy)
	enemy.onKilled = function(e)
		fire({ kind = "f45sealBreak", model = e.model, position = e.position })
		local owner = e.wardOwner
		if owner and owner.alive then
			owner.model:SetAttribute("F45WardAt", nil)
			EnemyService.stun(owner, owner.stats.traits.ward.stun, true)
		end
		if e.onSealBroken then
			e.onSealBroken(e)
		end
	end
end

attachers.ink_scribe = function(enemy)
	enemy.minions = {}
	enemy.onStrike = function(e, attack, t)
		if attack.id == "summon" then
			local alive = 0
			for index = #e.minions, 1, -1 do
				if e.minions[index].alive then
					alive += 1
				else
					table.remove(e.minions, index)
				end
			end
			local summon = attack.summon
			local count = math.min(summon.count, math.max(summon.limit - alive, 0))
			local positions = {}
			for _ = 1, count do
				local position = pointNear(e, 3.5)
				table.insert(positions, position)
				local blot = Floor45Service.spawnMinion(e, summon.typeId, position)
				table.insert(e.minions, blot)
			end
			e.model:SetAttribute("LastAttackResult", "summon")
			fire({ kind = "f45summon", model = e.model, positions = positions })
			EnemyService.startRecover(e, t)
			return true
		end
		if attack.id == "splash" then
			puddlesAtZones(e, attack)
			fire({ kind = "f45lob", model = e.model, from = e.position + Vector3.new(0, e.stats.height * 0.6, 0), positions = e.zoneCenters, ink = true })
		end
		return false
	end
end

attachers.ink_blot = function(enemy)
	enemy.onKilled = function(e)
		local puddle = e.stats.traits.deathPuddle
		Floor45Service.addHazard(puddle.kind, e.position, puddle.radius, puddle.life)
	end
end

attachers.shelf_warden = function(enemy)
	enemy.onStrike = function(e, attack, t, _, root)
		if attack.id == "fan" and root then
			fireSpread(e, attack, root)
			EnemyService.startRecover(e, t)
			return true
		end
		return false
	end
	enemy.brain = hopBrain(enemy, enemy.stats.traits.hop)
end

attachers.bookbinder = function(enemy)
	enemy.home = enemy.position
	enemy.onWindup = function(e, attack, _, root)
		if attack.id == "threads" and root then
			markLines(e, attack, root)
		end
	end
	enemy.onStrike = function(e, attack, t)
		if attack.id == "threads" then
			return strikeLines(e, attack, t, "threads")
		end
		return false
	end
	-- Запасной призыв (в Скриптории его заменяет Floor5World своими точками).
	enemy.onPhase = function(e, _, phase)
		local summon = phase and phase.summon
		if not summon then
			return
		end
		for _ = 1, summon.count do
			Floor45Service.spawnMinion(e, summon.typeId, pointNear(e, 6))
		end
	end
end

attachers.chief_chronicler = function(enemy)
	enemy.home = enemy.position
	enemy.onWindup = function(e, attack, _, root)
		if attack.id == "beam" and root then
			markBeam(e, attack, root)
		end
	end
	enemy.onStrike = function(e, attack, t, _, root)
		if attack.id == "volley" and root then
			fireSpread(e, attack, root)
			EnemyService.startRecover(e, t)
			return true
		end
		if attack.id == "beam" then
			return strikeBeam(e, attack, t)
		end
		if attack.id == "erase" then
			puddlesAtZones(e, attack)
		end
		return false
	end
	-- Печати II фазы (Floor5World): пока стоят — удары отбиты.
	enemy.onDamage = function(e, amount)
		if e.sealsUp and e.sealsUp > 0 then
			fire({ kind = "f45wardBlock", model = e.model, position = e.position + Vector3.new(0, e.stats.height * 0.55, 0), boss = true })
			return 0
		end
		return amount
	end
end

-- Покадрово: приземление литейщика оставляет расплав.
local function stepLanding(e)
	local landing = e.landing
	if landing and e.state ~= "dash" and e.state ~= "windup" then
		e.landing = nil
		local puddle = landing.attack.puddle
		if puddle and landing.at and e.alive then
			Floor45Service.addHazard(puddle.kind, landing.at, puddle.radius, puddle.life)
		end
	end
end

-- ======================================================================
-- Цикл и подключение
-- ======================================================================

local accum = 0
local function heartbeat(dt: number)
	accum += dt
	if accum < TICK then
		return
	end
	accum = 0
	local t = now()
	stepBurns(t)
	stepHazards(t)
	for enemy in pairs(active) do
		if not enemy.model or not enemy.model.Parent then
			active[enemy] = nil
		elseif enemy.frozenAt then
			-- «Дары Эха»: время стоит — особые действия врага тоже ждут
		else
			local ok, err = pcall(stepLanding, enemy)
			if not ok then
				warn("[Floor45Service] " .. tostring(enemy.stats.typeId) .. ": " .. tostring(err))
			end
		end
	end
end

-- Сигнал попадания: LastAttackResult → «hit» (сбрасываем в «none» на замахе).
local function watchHits(enemy)
	local previousWindup = enemy.onWindup
	enemy.onWindup = function(e, attack, player, root, t)
		e.model:SetAttribute("LastAttackResult", "none")
		if previousWindup then
			previousWindup(e, attack, player, root, t)
		end
	end
	enemy.model:GetAttributeChangedSignal("LastAttackResult"):Connect(function()
		if enemy.suppressHitFx or not enemy.alive then
			return
		end
		if enemy.model:GetAttribute("LastAttackResult") == "hit" then
			applyOnHit(enemy, enemy.attack, enemy.targetPlayer)
		end
	end)
end

local started = false
function Floor45Service.start()
	if started then
		return
	end
	started = true
	table.insert(EnemyService.spawnHooks, function(enemy)
		local attach = attachers[enemy.stats.typeId]
		if attach then
			attach(enemy)
			watchHits(enemy)
			enemy.model:SetAttribute("Floor45", true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		burns[player] = nil
	end)
	local function hook(player)
		player.CharacterAdded:Connect(function()
			burns[player] = nil
			player:SetAttribute("BurnUntil", 0)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
	RunService.Heartbeat:Connect(heartbeat)
	print("[Floor45Service] враги этажей 4–5: броня, конусы, лужи, печати, призыв, луч")
end

-- Для миров этажей.
Floor45Service.fireSpread = fireSpread
Floor45Service.resolveMany = resolveMany
Floor45Service.playersIn = playersIn
Floor45Service.applyOnHit = applyOnHit

return Floor45Service
