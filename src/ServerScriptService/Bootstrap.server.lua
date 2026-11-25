--!nonstrict
-- Bootstrap (сервер)
-- Точка входа серверных систем. Порядок важен: данные → боевое состояние
-- (создаёт ремоуты) → прогресс → удары → этаж → снаряжение → Кузня Эха →
-- броня → лут → способности.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Systems = ServerScriptService:WaitForChild("Systems")

-- Настроение этажа: закат над островами-руинами (FloorScenery).
require(Systems.FloorScenery).setupLighting()

-- Шаблоны эффектов оружия этажей 3–5 (ReplicatedStorage.FX.Hunt / Forge / Chron / Weapon) из
-- Shared/Fx/FxWeapons345: достраиваются только недостающие (правки, сохранённые в месте, не трогаются).
-- Без этого вызова клиент писал «нет шаблона FX/Hunt/...» и способности 3–5 были почти невидимы.
do
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ok, made, total = pcall(function()
		return require(ReplicatedStorage.Shared.Fx.FxBuilder345).build()
	end)
	if not ok then
		warn("[Bootstrap] шаблоны FX этажей 3–5: " .. tostring(made))
	elseif (made or 0) > 0 then
		print(string.format("[Bootstrap] шаблоны FX этажей 3–5: создано %d из %d", made, total or 0))
	end
end
Players.RespawnTime = 3

-- Стандартный скрипт восстановления здоровья Roblox ломает баланс
-- (лечит только заряды и костёр): убираем его из каждого персонажа.
local function stripDefaultRegen(character)
	local health = character:WaitForChild("Health", 3)
	if health then
		health:Destroy()
	end
end
local function hookPlayer(player)
	player.CharacterAdded:Connect(stripDefaultRegen)
	if player.Character then
		task.spawn(stripDefaultRegen, player.Character)
	end
end
Players.PlayerAdded:Connect(hookPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end

-- ===== Загрузчик систем (PLAN_DORABOTKI P1-1) =====
-- Раньше одна ошибка при старте обрывала все следующие системы: игроки
-- попадали в мёртвый мир. Теперь загрузка и старт каждой системы — в своём
-- xpcall: упавшая пишет одну понятную строку с traceback, остальные работают.
-- Порядок не трогаем: зависимости систем выражены им (хуки CombatService,
-- обёртка gearStats и т. п.).
local DebugState = require(game:GetService("ReplicatedStorage").Shared.Net.DebugState)

local function bootFail(name, err)
	warn(("[Bootstrap] %s: %s"):format(name, tostring(err)))
	pcall(function()
		-- Текст ошибки в атрибут: лог в Studio затапливается спамом контента,
		-- а атрибут живёт и читается через DebugState.get("Boot", name).
		DebugState.set("Boot", name, "FAILED: " .. tostring(err):sub(1, 300))
	end)
end

-- require с защитой: упавший модуль не роняет Bootstrap.
local function requireSystem(name)
	local ok, module = xpcall(function()
		return require(Systems[name])
	end, function(e)
		return debug.traceback(tostring(e), 2)
	end)
	if not ok then
		bootFail(name .. " (загрузка)", module)
		return nil
	end
	return module
end

-- start с защитой и замером времени в DebugState.
local function startSystem(name, module)
	if not module then
		return -- загрузка уже упала и написала warn
	end
	local t0 = os.clock()
	local ok, err = xpcall(function()
		module.start()
	end, function(e)
		return debug.traceback(tostring(e), 2)
	end)
	if ok then
		pcall(function()
			DebugState.set("Boot", name, ("%dms"):format(math.floor((os.clock() - t0) * 1000)))
		end)
	else
		bootFail(name .. " (старт)", err)
	end
end

-- require + start для систем, которые в исходнике подключались по месту —
-- их топ-уровень может опираться на уже стартовавшие предыдущие системы.
local function bootSystem(name)
	startSystem(name, requireSystem(name))
end

local DataService = requireSystem("DataService")
local CombatService = requireSystem("CombatService")
local ProgressionService = requireSystem("ProgressionService")
local MeleeService = requireSystem("MeleeService")
local FloorService = requireSystem("FloorService")
local EquipmentService = requireSystem("EquipmentService")
local EchoService = requireSystem("EchoService")
local ArmorService = requireSystem("ArmorService")
local ArmorPreviewService = requireSystem("ArmorPreviewService")
local InventoryService = requireSystem("InventoryService")
local AppearanceService = requireSystem("AppearanceService")
local LootService = requireSystem("LootService")
local AbilityService = requireSystem("AbilityService")
local ManaService = requireSystem("ManaService")

if FloorService and LootService then
	FloorService.setLoot(LootService)
	LootService.runStats = FloorService.runStats
end

startSystem("DataService", DataService)
-- Счётчики достижений: парирования и урон идут из Combat/EnemyService.
bootSystem("StatsService")
startSystem("CombatService", CombatService)
startSystem("ProgressionService", ProgressionService)
startSystem("MeleeService", MeleeService)
startSystem("AppearanceService", AppearanceService)
startSystem("EquipmentService", EquipmentService)
startSystem("EchoService", EchoService)
startSystem("ArmorService", ArmorService)
startSystem("ArmorPreviewService", ArmorPreviewService) -- модели комплектов для карточки сундука
-- Сумка и аксессуары: после брони (оборачивает её хук gearStats).
startSystem("InventoryService", InventoryService)
-- Мана мага: после брони и сумки (читает их хук gearStats).
startSystem("ManaService", ManaService)
startSystem("LootService", LootService)
-- Сундуки этажей v3: этаж кладёт их в сумку, открытие — в долине (сцена «Клинок читает память»).
bootSystem("ChestService")
startSystem("AbilityService", AbilityService)
-- Маг: удары посохом (снаряды), барьер, «Покров», дебафы. После ManaService и AbilityService:
-- цепляется к их хукам (parrySuccess, classApplied, slot3).
bootSystem("MageService")
-- Древо талантов: после MageService (цепляется к classApplied, парированию, убийствам).
bootSystem("TalentService")
startSystem("FloorService", FloorService)
bootSystem("FloorBoonService") -- «Дары Эха»: карточки этажа с остановкой времени
-- Этаж 2 «Затопленные сады»: поведение врагов (кора, корни, лужи, полив,
-- шипы, Садовница) через хуки EnemyService.
bootSystem("Floor2Service")
-- Этажи 4–5: логика врагов и ломаемых декораций.
bootSystem("Floor45Service")
bootSystem("BreakableService")
bootSystem("Floor3EnemyService")
-- Сторож перемещений: пока режим наблюдения (PLAN_DORABOTKI P1-4).
bootSystem("MotionGuard")
-- Лобби знакомства: строит остров, встречает новичков (после боевых систем).
bootSystem("TutorialService")
-- Отряды до 3 игроков: приглашения, телепорт к лидеру, групповые этажи,
-- HP-масштаб врагов (+35%/игрок). После боевых систем (хук EnemyService.spawnHooks).
bootSystem("PartyService")
-- Охота (P6): особые варианты врагов с золотым сиянием и добычей. Тоже хук
-- spawnHooks — после PartyService (который множит HP: сначала масштаб отряда,
-- потом особый ×2.5 — иначе особый потеряет множитель).
bootSystem("SpecialMobs")
-- Аффиксы врагов (мороз/огонь/яд): хук spawnHooks (после SpecialMobs — элита
-- и носитель дебафа могут совпасть) + хук урона по игроку.
bootSystem("EnemyDebuffs")
-- Настройки игрока (громкость/чувствительность в профиле) — после DataService.
bootSystem("PlayerSettings")

-- Только Studio: ServerStorage.KlinokDebug.Cmd (выдача оружия, враги, бессмертие).
if game:GetService("RunService"):IsStudio() then
	bootSystem("DebugCommands")
end
