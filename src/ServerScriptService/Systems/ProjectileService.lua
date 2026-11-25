--!nonstrict
-- ProjectileService (сервер)
-- Снаряды дальних врагов. Летят по серверу, попадание считает сервер.
-- Парирование ОТРАЖАЕТ снаряд обратно в стрелка (раздел 7: «стрелок —
-- парирование отражает снаряд, либо уклонение и сближение»), колонны снаряды
-- блокируют.
--
-- Все снаряды обновляет один цикл Heartbeat: ни сопрограмм, ни task.wait на
-- каждый снаряд.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DebugState = require(Shared.Net.DebugState)
local CombatService = require(script.Parent.CombatService)
local TalentMods = require(script.Parent.TalentMods)

local ProjectileService = {}

-- EnemyService подставляет сюда доступ к врагам (иначе была бы циклическая
-- зависимость модулей).
ProjectileService.enemyProvider = nil
ProjectileService.enemyDamage = nil
ProjectileService.enemyStun = nil

local folder
local active = {}
local loop

local function projectilesFolder()
	if folder and folder.Parent then
		return folder
	end
	folder = Workspace:FindFirstChild("Projectiles")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Projectiles"
		folder.Parent = Workspace
	end
	return folder
end

-- Снаряд на сервере — невидимая деталь: положение и атрибуты. Стрелу
-- (древко, наконечник, оперение, хвост) рисует клиент поверх неё (EnemyFx,
-- ТЗ врагов 2.4.4): сервер внешним видом не занимается.
local function makePart(origin: Vector3, size: number, parryable: boolean, reflected: boolean)
	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Size = Vector3.new(size * 0.6, size * 0.6, size * 3.2)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.CFrame = CFrame.new(origin)
	part:SetAttribute("Parryable", parryable)
	part:SetAttribute("Reflected", reflected)
	part:SetAttribute("ProjectileKind", "arrow")
	part:SetAttribute("ProjectileResult", "flying")
	part.Parent = projectilesFolder()
	return part
end

local function playerFromInstance(instance: Instance?)
	local node = instance
	while node and node ~= Workspace do
		local player = Players:GetPlayerFromCharacter(node)
		if player then
			return player
		end
		node = node.Parent
	end
	return nil
end

local function finish(projectile, result: string)
	projectile.part:SetAttribute("ProjectileResult", result)
	projectile.dead = true
	projectile.part:Destroy()
end

-- Отбить снаряд в сторону стрелка.
local function reflect(projectile, player, position: Vector3)
	local shooter = projectile.options.shooter
	local direction
	if shooter and shooter.alive then
		local target = shooter.position + Vector3.new(0, shooter.stats.height * 0.65, 0)
		direction = target - position
	else
		direction = -projectile.direction
	end
	if direction.Magnitude < 0.5 then
		return
	end
	ProjectileService.fire(projectile.options.ownerModel, position, direction.Unit, {
		speed = projectile.speed * 1.25,
		-- Болт Арбалетчицы отражается в неё долей её здоровья и оглушает.
		-- Обычный снаряд: «Отражение» (воин) / «Отражатель» (маг) усиливают отбитый снаряд.
		damage = projectile.options.reflectDamage or projectile.damage * TalentMods.reflectMultiplier(player),
		reflectStun = projectile.options.reflectStun,
		parryable = false,
		reflected = true,
		attacker = player,
		lifetime = 2,
		kind = projectile.options.kind,
	})
end

local function stepProjectile(projectile, dt: number)
	local part = projectile.part
	if projectile.dead or not part.Parent then
		projectile.dead = true
		return
	end

	projectile.elapsed += dt
	if projectile.elapsed >= projectile.lifetime then
		finish(projectile, "expired")
		return
	end

	local delta = projectile.direction * projectile.speed * dt
	local result = Workspace:Raycast(projectile.position, delta, projectile.raycastParams)

	-- Отражённый снаряд бьёт по врагам: ищем ближайшего у траектории.
	if projectile.options.reflected and ProjectileService.enemyProvider then
		local endPoint = projectile.position + delta
		for _, enemy in ipairs(ProjectileService.enemyProvider()) do
			if enemy.alive then
				local center = enemy.position + Vector3.new(0, enemy.stats.height * 0.5, 0)
				local reach = enemy.stats.radius + 0.7
				local toCenter = center - projectile.position
				local along = math.clamp(toCenter:Dot(projectile.direction), 0, delta.Magnitude)
				local closest = projectile.position + projectile.direction * along
				if (center - closest).Magnitude <= reach + enemy.stats.height * 0.35 then
					if ProjectileService.enemyDamage then
						ProjectileService.enemyDamage(enemy, projectile.damage, projectile.options.attacker)
					end
					if projectile.options.reflectStun and ProjectileService.enemyStun and enemy.alive then
						ProjectileService.enemyStun(enemy, projectile.options.reflectStun)
					end
					DebugState.set("Projectile", "LastResult", "reflected-hit")
					finish(projectile, "reflected-hit")
					return
				end
			end
		end
		if result then
			finish(projectile, "wall")
			return
		end
		projectile.position = endPoint
		part.CFrame = CFrame.lookAt(endPoint, endPoint + projectile.direction)
		return
	end

	if result then
		local hitPlayer = playerFromInstance(result.Instance)
		if hitPlayer then
			local outcome, taken = CombatService.resolveIncomingAttack(hitPlayer, {
				damage = projectile.damage,
				parryable = projectile.options.parryable ~= false,
				source = projectile.options.source or "Projectile",
				position = projectile.position,
			})
			part:SetAttribute("ProjectileDamage", taken or 0)
			-- Итог фиксируем в атрибутах игрока: снаряд сразу исчезает.
			hitPlayer:SetAttribute("LastProjectileResult", outcome)
			hitPlayer:SetAttribute("LastProjectileDamage", taken or 0)
			DebugState.set("Projectile", "LastResult", outcome)
			DebugState.set("Projectile", "LastDamage", taken or 0)
			DebugState.set("Projectile", "LastTarget", hitPlayer.Name)
			if outcome == "parried" then
				reflect(projectile, hitPlayer, result.Position)
			end
			finish(projectile, outcome)
			return
		end
		DebugState.set("Projectile", "LastResult", "wall")
		finish(projectile, "wall")
		return
	end

	projectile.position += delta
	part.CFrame = CFrame.lookAt(projectile.position, projectile.position + projectile.direction)
end

local function ensureLoop()
	if loop then
		return
	end
	loop = RunService.Heartbeat:Connect(function(dt: number)
		for index = #active, 1, -1 do
			local projectile = active[index]
			stepProjectile(projectile, dt)
			if projectile.dead then
				table.remove(active, index)
			end
		end
	end)
end

-- fire(ownerModel, origin, direction, options)
--   speed, damage, parryable, lifetime, color, source, shooter (враг),
--   reflected / attacker — отражённый снаряд.
function ProjectileService.fire(ownerModel, origin: Vector3, direction: Vector3, options)
	local opts = options or {}
	opts.ownerModel = ownerModel

	local parryable = opts.parryable ~= false
	local part = makePart(origin, opts.reflected and 0.7 or 0.5, parryable, opts.reflected == true)
	part.CFrame = CFrame.lookAt(origin, origin + direction.Unit)
	if opts.kind then
		part:SetAttribute("ProjectileKind", opts.kind)
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { ownerModel, projectilesFolder() }
	-- Отражённый снаряд рождается у игрока: его тело стеной считать нельзя.
	if opts.attacker and opts.attacker.Character then
		table.insert(ignore, opts.attacker.Character)
	end
	raycastParams.FilterDescendantsInstances = ignore
	raycastParams.IgnoreWater = true

	table.insert(active, {
		part = part,
		position = origin,
		direction = direction.Unit,
		speed = opts.speed or 40,
		damage = opts.damage or 10,
		lifetime = opts.lifetime or 3,
		elapsed = 0,
		options = opts,
		raycastParams = raycastParams,
		dead = false,
	})
	ensureLoop()
	return part
end

function ProjectileService.activeCount(): number
	return #active
end

-- Остановка времени: снаряды врагов этой папки (этажа) гаснут. Отражённые
-- игроком и выпущенные не врагами — не трогаем.
function ProjectileService.clearWithin(folder)
	local kept = {}
	for _, projectile in ipairs(active) do
		local owner = projectile.options and projectile.options.ownerModel
		if not projectile.dead and owner and owner:IsDescendantOf(folder) and not projectile.options.reflected then
			projectile.dead = true
			if projectile.part then
				projectile.part:Destroy()
			end
		else
			table.insert(kept, projectile)
		end
	end
	active = kept
end

function ProjectileService.clear()
	for _, projectile in ipairs(active) do
		projectile.dead = true
		if projectile.part then
			projectile.part:Destroy()
		end
	end
	active = {}
end

return ProjectileService
