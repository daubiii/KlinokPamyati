--!nonstrict
-- Bootstrap (клиент)
-- Запуск клиентских контроллеров. Порядок важен: сначала камера и анимации
-- (на них опираются остальные), затем бой, враги, эффекты и экраны.

local StarterGui = game:GetService("StarterGui")

local Controllers = script.Parent:WaitForChild("Controllers")

-- Чат Roblox закрывает нижний левый угол и ловит клавиши боя.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
end)

-- Статус каждого контроллера — в DebugState (вкладка Data в отладке).
-- Ошибка больше не молчит: warn с traceback + метка FAILED (PLAN_DORABOTKI P1-2).
local DebugState = require(game:GetService("ReplicatedStorage").Shared.Net.DebugState)

local function start(name: string)
	local t0 = os.clock()
	local ok, module = xpcall(require, function(e)
		return debug.traceback(tostring(e), 2)
	end, Controllers[name])
	if not ok then
		warn(("[Bootstrap] %s не загрузился: %s"):format(name, tostring(module)))
		DebugState.set("Boot", name, "FAILED")
		return
	end
	local started, err = xpcall(function()
		module.start()
	end, function(e)
		return debug.traceback(tostring(e), 2)
	end)
	if started then
		DebugState.set("Boot", name, ("%dms"):format(math.floor((os.clock() - t0) * 1000)))
	else
		warn(("[Bootstrap] %s.start: %s"):format(name, tostring(err)))
		DebugState.set("Boot", name, "FAILED")
	end
end

for _, name in ipairs({
	"LoadingScreenController", -- заставка загрузки профиля: первой, поверх всего
	"CameraController",
	"EnvironmentController",
	"SandstormController",
	"PlayerAnimator",
	"CapeController",
	"DodgeController",
	"CombatController",
	"AbilityController",
	"EnemyVisualController",
	"EnemyBarsController",
	"AttackFxController",
	"AbilityFx",
	"MageFx", -- маг: снаряды посоха, барьер, покров, дебафы, пассивки; заклинания — MageSpellFx
	"AudioController",
	"PixelHudController",
	"CrosshairController", -- прицел в бою (засечка попадания, цель в досягаемости)
	"QuickItemController", -- быстрый предмет [G] и тосты находок (InventoryService)
	"SoulHudController", -- блок душ у HP: стаки, бонус урона, души боссов, анимации
	"FloorUiController",
	"MiniBossFx",
	"FloorBoonController", -- «Дары Эха»: остановка времени и карточки этажа
	"Floor2Fx", -- этаж 2: лужи, полив, корни, цветение, статусы
	"Floor2Atmosphere", -- этаж 2: свет «зелёные сумерки», морось, туман, светлячки, колёса
	"Floor3Atmosphere", -- этаж 3: осенний закат и пыль
	"Floor3Fx", -- этаж 3: трофеи, тайники, ловушки и босс
	"Floor45Fx", -- этажи 4–5: окружение и эффекты врагов
	"Floor45Atmosphere", -- этажи 4–5: пепел, искры, пыль и страницы
	"BreakableFx", -- этажи 4–5: обломки, пыль и звук разрушаемых предметов
	"Floor3EnemyFx", -- этаж 3: визуальные эффекты охотников и боссов
	"ChestController", -- карточка находки старых сундуков (открытие на этаже)
	"ChestFlyController", -- сундуки этажей v3: полёт в сумку и лента «ПОЛУЧЕН СУНДУК»
	"ChestRevealController", -- сундуки этажей v3: сцена «Клинок читает память» в долине
	"BossIntroController",
	"StationController",
	"WeaponPresence", -- легендарки/секретки: аура, пульс света, кольцо присутствия
	"BossMovesFx", -- фирменные атаки боссов: разметка, решётки, волны, книга
	"PartyController", -- отряд: HUD-кнопка «ОТРЯД» и перга-окно (приглашения, «К отряду»)
	"FloorEndVoteController", -- конец пати-забега: наблюдение за выжившим и голосование
	"EnemyDebuffFx", -- дебафы на игроке (мороз/огонь/яд): частицы, тон экрана, иконка-таймер
	"SettingsController", -- настройки: громкость музыки/звуков, чувствительность камеры
}) do
	start(name)
end
