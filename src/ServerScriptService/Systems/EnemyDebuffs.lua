--!nonstrict
-- EnemyDebuffs (сервер) — аффиксы врагов и дебафы на игроке (решение
-- владельца 15.11.2026): мороз/огонь/яд.
--
-- * Спавн: обычный враг этажа с шансом (base + минуты забега × perMinute,
--   потолок cap — конфиг Config/Debuffs) становится носителем аффикса:
--   иконка над моделью (BillboardGui) + лёгкое цветное свечение (PointLight).
-- * Носитель атакует игрока и урон ПРОШЁЛ (не парирование/уворот) — игрок
--   получает дебаф: урон тиками (маленький!), замедление бега, атрибуты
--   DebuffKind/DebuffUntil для клиентского визуала и иконки у полосы HP.
-- * Снятие: время вышло, игрок умер, вернулся в долину.
-- Урон намеренно маленький: главный дискомфорт — замедление и толпа.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Debuffs = require(Shared.Config.Debuffs)
local EnemyService = require(script.Parent.EnemyService)

local EnemyDebuffs = {}

local TICK = 0.5
local active = {} -- [player] = { kind, until, baseWalk, tickAcc }

local function now(): number
	return workspace:GetServerTimeNow()
end

local function floorIdOf(enemy): number?
	local room = enemy.room
	if room and type(room.floorId) == "number" then
		return room.floorId
	end
	return nil
end

-- Годится ли враг под аффикс: боевой, на этаже, не босс/объект.
local function eligible(enemy): boolean
	local room = enemy.room
	if not room or type(room.floorId) ~= "number" then
		return false
	end
	local role = enemy.stats.role
	if role == "boss" or role == "miniboss" or role == "object" then
		return false
	end
	return enemy.alive == true
end

-- Пометить врага носителем аффикса: иконка над головой + цветное свечение.
function EnemyDebuffs.mark(enemy, kind: string)
	if enemy.affix or not Debuffs.Kinds[kind] then
		return
	end
	enemy.affix = kind
	local cfg = Debuffs.Kinds[kind]
	local model = enemy.model
	model:SetAttribute("Affix", kind)

	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "AffixIcon"
		billboard.Size = UDim2.fromOffset(44, 44)
		billboard.StudsOffset = Vector3.new(0, 3.4, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 70
		billboard.Adornee = root
		local image = Instance.new("ImageLabel")
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = Debuffs.Atlas[kind]
		image.ZIndex = 2
		image.Parent = billboard
		billboard.Parent = model

		local light = Instance.new("PointLight")
		light.Name = "AffixLight"
		light.Color = cfg.color
		light.Range = 7
		light.Brightness = 0.8
		light.Parent = root
	end
end

-- Дебаф на игроке: урон тиками + замедление + атрибуты для клиентского
-- визуала (частицы, тон экрана, иконка у HP).
local function applyToPlayer(player, kind: string)
	local cfg = Debuffs.Kinds[kind]
	if not cfg or not player.Parent then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local moment = now()
	local state = active[player]
	if state and state.kind == kind and state.until_ > moment then
		state.until_ = moment + cfg.duration -- освежаем тот же дебаф
		player:SetAttribute("DebuffUntil", state.until_)
		return
	end
	if state then
		-- другой вид поверх: снимаем старое замедление, базу берём заново
		if humanoid and state.baseWalk then
			humanoid.WalkSpeed = state.baseWalk
		end
	end
	active[player] = { kind = kind, until_ = moment + cfg.duration, baseWalk = humanoid.WalkSpeed, tickAcc = 0 }
	humanoid.WalkSpeed = math.max(4, humanoid.WalkSpeed * cfg.slow)
	player:SetAttribute("DebuffKind", kind)
	player:SetAttribute("DebuffUntil", state and active[player].until_ or moment + cfg.duration)
end

local function clearPlayer(player)
	local state = active[player]
	if not state then
		return
	end
	active[player] = nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if state.baseWalk then
			humanoid.WalkSpeed = state.baseWalk
		end
		if humanoid.Health <= 0 then
			return -- мёртвому нечего возвращать
		end
	end
	player:SetAttribute("DebuffKind", nil)
	player:SetAttribute("DebuffUntil", nil)
end

-- Урон игроку прошёл (не парирование/уворот) — передаём аффикс.
EnemyService.onPlayerHit = function(enemy, player, result, taken)
	if not enemy.affix or not player.Parent then
		return
	end
	if result == "parried" or result == "dodged" then
		return
	end
	if not taken or taken <= 0 then
		return
	end
	applyToPlayer(player, enemy.affix)
end

function EnemyDebuffs.apply(player, kind: string)
	applyToPlayer(player, kind)
end

function EnemyDebuffs.clear(player)
	clearPlayer(player)
end

function EnemyDebuffs.start()
	-- Ролл аффикса при спавне врага: шанс зависит от этажа и времени забега.
	table.insert(EnemyService.spawnHooks, function(enemy)
		if not eligible(enemy) then
			return
		end
		local floorId = floorIdOf(enemy)
		local F = require(script.Parent.FloorService)
		local state = F.state(floorId)
		local elapsed = state and state.runStartedAt and (workspace:GetServerTimeNow() - state.runStartedAt) or 0
		local chance = Debuffs.chanceFor(floorId, elapsed)
		if math.random() < chance then
			local kind = Debuffs.order[math.random(#Debuffs.order)]
			EnemyDebuffs.mark(enemy, kind)
		end
	end)

	-- Тик дебафов игроков: урон, снятие по времени/смерти/выходу из этажа.
	RunService.Heartbeat:Connect(function(dt)
		local moment = now()
		for player, state in pairs(active) do
			if not player.Parent then
				active[player] = nil
				continue
			end
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				clearPlayer(player)
				continue
			end
			-- вернулся в долину — долина чистая
			if player:GetAttribute("Zone") ~= "Floor" then
				clearPlayer(player)
				continue
			end
			if moment >= state.until_ then
				clearPlayer(player)
				continue
			end
			local cfg = Debuffs.Kinds[state.kind]
			if cfg and cfg.dps > 0 then
				state.tickAcc = (state.tickAcc or 0) + dt
				while state.tickAcc >= 1 do
					state.tickAcc -= 1
					humanoid:TakeDamage(cfg.dps)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		active[player] = nil
	end)

	print("[EnemyDebuffs] аффиксы готовы: мороз/огонь/яд (шанс растёт с этажом и временем забега)")
end

return EnemyDebuffs
