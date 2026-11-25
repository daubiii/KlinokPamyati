--!nonstrict
-- StatsService — пожизненные счётчики игрока (квесты-достижения, PLAN квесты).
--   parries      — удачные парирования (CombatService.resolveIncomingAttack);
--   damageDealt  — урон, фактически снятый с врагов (EnemyService.applyDamage);
--   enemiesKilled— победы над врагами (считает ProgressionService).
-- Счётчики растут всегда, без «взять задание», и живут в профиле:
-- reconcile DataService дописывает их профилям старых версий. Сохраняются
-- обычным автосейвом. Каждое изменение — сигнал statChanged: на нём висит
-- QuestService, автозакрывающий тиры достижений.
local StatsService = {}

local DataService = require(script.Parent.DataService)

local statChanged = Instance.new("BindableEvent")
StatsService.statChanged = statChanged.Event

local function add(player, key: string, amount: number)
	if not player.Parent then
		return
	end
	-- На незагруженном профиле не считаем: записи в заглушку выбрасываются
	-- при загрузке настоящего профиля (DataService.get никогда не nil).
	if DataService.status(player) ~= "ready" then
		return
	end
	local profile = DataService.get(player)
	if type(profile.stats) ~= "table" then
		return
	end
	profile.stats[key] = (profile.stats[key] or 0) + amount
	statChanged:Fire(player, key)
end

-- Удачное парирование (серверная проверка окна, CombatService).
function StatsService.addParry(player)
	add(player, "parries", 1)
end

-- Урон, фактически снятый с врага (после брони), только от игрока.
function StatsService.addDamage(player, amount: number)
	if amount and amount > 0 then
		add(player, "damageDealt", math.floor(amount))
	end
end

-- Произвольный счётчик с уведомлением слушателей (отладка qstat и будущие
-- источники): возвращает новое значение.
function StatsService.addCount(player, key: string, amount: number): number
	amount = math.floor(amount or 0)
	local profile = DataService.get(player)
	if profile and type(profile.stats) == "table" and amount ~= 0 then
		profile.stats[key] = (profile.stats[key] or 0) + amount
		statChanged:Fire(player, key, amount)
	end
	return profile and profile.stats and profile.stats[key] or 0
end

function StatsService.start()
	-- Тело сервиса — два вызова из боевых систем; старту нечего делать.
	print("[StatsService] счётчики достижений запущены")
end

return StatsService
