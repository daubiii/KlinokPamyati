--!nonstrict
-- DebugCommands (сервер, только Studio)
-- Команды для проверки оружия и способностей. Чат в игре выключен, а Command
-- Bar грузит свою копию модулей, поэтому команды идут через BindableFunction:
--   Command Bar в Play, контекст сервера:
--   print(game.ServerStorage.KlinokDebug.Cmd:Invoke("give key"))
-- Список команд — "help". Игрок — первый на сервере или "@Имя" в любом месте.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Echo = require(Shared.Config.Echo)
local Enemies = require(Shared.Config.Enemies)
local Loot = require(Shared.Config.Loot)
local Quests = require(Shared.Config.Quests)

local AbilityService = require(script.Parent.AbilityService)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)
local StatsService = require(script.Parent.StatsService)
local SpecialMobs = require(script.Parent.SpecialMobs)

local DebugCommands = {}

local WEAPON_ALIASES = {
	rusty = "rusty_sword",
	falchion = "iron_falchion",
	forge = "forge_hammer",
	gblade = "guard_blade",
	ghammer = "guard_hammer",
	vortex = "vortex_blade",
	rift = "shattered_hammer",
	key = "gatekeeper_key",
	-- этаж 3
	cleaver = "hunt_cleaver",
	broad = "hunt_broadsword",
	bear = "bear_mace",
	fang = "pack_fang",
	trap = "trap_maul",
	royal = "royal_scythe",
	falconer = "falconer_saber",
	-- этаж 4
	cast = "cast_cleaver",
	quench = "quench_blade",
	apprentice = "apprentice_hammer",
	crucible = "crucible_maul",
	searing = "searing_blade",
	anvil = "anvil_hammer",
	heart = "forge_heart_blade",
	slag = "slag_scythe",
	unfinished = "unfinished_blade",
	-- этаж 5
	paper = "paper_knife",
	tome = "tome_hammer",
	bookmark = "bookmark_blade",
	quill = "quill_blade",
	seal = "seal_hammer",
	hourglass = "hourglass_maul",
	ink = "ink_blade",
	oblivion = "oblivion_scythe",
	memory = "memory_blade",
}

local ENEMY_ALIASES = {
	boss = "gatekeeper",
	boss4 = "elder_founder",
	boss5 = "chief_chronicler",
	mini5 = "bookbinder",
}

local HELP = [[
floor <1-5>        вход на этаж без проверки прогресса; floor без номера = этаж 1
floor1..floor5     короткие команды входа на конкретный этаж; hub = вернуться в хаб
zone <id>          телепорт к зоне текущего этажа (id см. docs/STUDIO_DEBUG_COMMANDS.md)
boon [N]           «Дары Эха»: остановить время и выдать карточки сейчас (N — выборов подряд, 1..5)
spawn <тип> [N]    создать врагов перед игроком; N = 1..20; по умолчанию 1 (guard — 5)
clear              убрать врагов, созданных командой spawn
item <id|all> [N]  положить припас в сумку (без id — список); acc <id|all> — аксессуар
give <оружие>      выдать и надеть: rusty falchion forge gblade ghammer vortex rift key (или полный id)
give all           все 8 оружий в инвентарь, в руке — Ключ
star <N>           ★ уровень оружия в руке (1..потолок редкости)
cd                 сбросить перезарядки способностей
nocd [on|off]      включить/выключить мгновенный сброс перезарядки после каста
god [on|off]       включить/выключить бессмертие
heal               полное здоровье и заряды лечения
cam side|front|top|back|off   обзорная камера; off = обычная
class <warrior|mage>  сменить класс (броня класса, мана); выбор класса в игре — позже
mana [N|full|0]    мана мага: без числа — сколько сейчас; full — полная
magearmor <набор>  маг: выдать и надеть комплект (novice reader chronicler oblivion archivist)
camaudit [этаж]    теснота для камеры: ширина прохода и высота потолка у точек этажа (отчёт — в Output и ServerStorage.KlinokDebug.CamAudit)
armor [id] [N]     броня текущего класса: без id — список комплектов; id — выдать и надеть; N — ещё N−1 повторок (эхо)
mat [этаж|id] [N]  материал этажа (1–5) или по id: +N (по умолчанию 100); без аргументов — сколько есть
staff <id|спелл|floorN|all>  маг: выдать и надеть посох (без id — список); спелл — посох с ним (meteor, time_stop…)
veil               маг: «Покров» (клавиша 3) без проверки перезарядки
level <1-60>       уровень героя (очки древа = уровень − 1; статы растут до 30)
talents [list [all]|learn <id>|all|branch <1-3>|reset|free|points N]  древо талантов текущего класса
                   без аргументов — очки и изученное; list all — с малыми узлами;
                   all — изучить всё (без проверки очков); branch N — весь путь N;
                   points N — N лишних очков до выхода; reset — бесплатный сброс
chest [list|give [этаж] [common|gold] [N]|fly [этаж] [common|gold]|clear]  сундуки этажей v3 в сумке
                   give — положить N сундуков (по умолчанию этаж 1, обычный, 1), fly — то же с полётом
qstat <parries|damage|kills|chests|bosses> [N]  +N к пожизненному счётчику — двигает достижения и поручения (10)
quests            состояние поручений (день/неделя) и сюжета — список с прогрессом в Output
tutorial [reset|skip]  лобби знакомства: без аргумента — статус; reset — показать снова
special [тип]          P6 охота: заспавнить ОСОБОГО врага рядом (золото+материал+specialKilled при смерти)
killspecial            добить последнего особого боевым пайплайном (проверка награды охоты)
debuff [вид|clear]     P6 дебафы: frost/burn/poison — на себя (урон тиками, замедление); clear — снять
                   к герою и лентой; list — что в сумке; clear — убрать все. Открыть — сумка в долине
gate [N|all|reset] Врата Печатей: открыть этажи 1..N (предыдущие — пройдены на «Ненормальном»);
                   all — всё пройдено на всех сложностях; reset — как у нового героя; без числа — что открыто
valves             этаж 2: открыть все зоны вентилей без боёв
trophies [take]    этаж 3: зачистить зоны трофеев [и при take сразу получить все]
sfx [имя] [N]      список/прослушивание вариантов звука
@Имя               выбрать игрока (Test → 2 Players: @Player2)
Враги по этажам и примеры — docs/STUDIO_DEBUG_COMMANDS.md]]

local spawned = {}
local noCooldown = {} -- [player] = connection

local function folder()
	local f = Workspace:FindFirstChild("DebugEnemies")
	if not f then
		f = Instance.new("Folder")
		f.Name = "DebugEnemies"
		f.Parent = Workspace
	end
	return f
end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function toggle(arg, current: boolean): boolean
	if arg == "on" then
		return true
	elseif arg == "off" then
		return false
	end
	return not current
end

local function give(player, weaponId: string)
	local bindable = ServerStorage.KlinokDebug:FindFirstChild("GiveWeapon")
	if not bindable then
		return "нет GiveWeapon (EquipmentService не запущен?)"
	end
	return bindable:Invoke(player.Name, weaponId)
end

local commands = {}

function commands.help()
	return HELP
end

-- Оружие чужого класса не наденется (EquipmentService.requestEquip): сначала меняем класс.
local function ensureClassFor(player, weaponId: string)
	local template = Loot.template(weaponId)
	local profile = DataService.get(player)
	if template and Loot.weaponClass(template) ~= (profile.className or "warrior") then
		commands.class(player, Loot.weaponClass(template))
	end
end

function commands.give(player, arg)
	if not arg then
		return "give <оружие>, см. help"
	end
	if arg == "all" then
		ensureClassFor(player, "gatekeeper_key")
		local names = {}
		for _, weapon in ipairs(Loot.Weapons) do
			if weapon.id ~= "gatekeeper_key" and Loot.weaponClass(weapon) == "warrior" then
				give(player, weapon.id)
				table.insert(names, weapon.name)
			end
		end
		return give(player, "gatekeeper_key") .. "; в инвентаре: " .. table.concat(names, ", ")
	end
	local weaponId = WEAPON_ALIASES[arg] or arg
	ensureClassFor(player, weaponId)
	return give(player, weaponId)
end

-- Сумка (InventoryService): item <id|all> [n], acc <id|all>.
function commands.item(player, arg, countArg)
	local InventoryService = require(script.Parent.InventoryService)
	local Items = require(Shared.Config.Items)
	if not arg then
		local ids = {}
		for id in pairs(Items.List) do
			table.insert(ids, id)
		end
		table.sort(ids)
		return "item <id|all> [n]: " .. table.concat(ids, ", ")
	end
	local count = tonumber(countArg) or 1
	if arg == "all" then
		for id in pairs(Items.List) do
			InventoryService.addItem(player, id, count, true)
		end
		return ("в сумке всё по %d"):format(count)
	end
	if not Items.List[arg] then
		return "нет предмета " .. arg
	end
	return ("%s: %d"):format(arg, InventoryService.addItem(player, arg, count))
end

function commands.acc(player, arg)
	local InventoryService = require(script.Parent.InventoryService)
	local Items = require(Shared.Config.Items)
	if not arg then
		local ids = {}
		for id in pairs(Items.Accessories) do
			table.insert(ids, id)
		end
		table.sort(ids)
		return "acc <id|all>: " .. table.concat(ids, ", ")
	end
	if arg == "all" then
		for id in pairs(Items.Accessories) do
			InventoryService.addAccessory(player, id, true)
		end
		return "выданы все аксессуары"
	end
	local entry = InventoryService.addAccessory(player, arg)
	return entry and ("выдан %s (uid %d)"):format(arg, entry.uid) or ("нет аксессуара " .. arg)
end

-- Пожизненные счётчики достижений/поручений: +N одним движением.
local QSTAT_KEYS = { parries = "parries", damage = "damageDealt", kills = "enemiesKilled", chests = "chestsOpened", bosses = "bossesKilled" }

function commands.qstat(player, key, countArg)
	local stat = QSTAT_KEYS[key or ""]
	if not stat then
		return "ключи: parries, damage, kills, chests, bosses (N по умолчанию 10)"
	end
	local n = math.max(tonumber(countArg) or 10, 0)
	local value = StatsService.addCount(player, stat, n)
	return ("%s += %d (теперь %d) — достижения и поручения пересчитаны"):format(stat, n, value)
end

-- Лобби знакомства: статус / сброс / пометить пройденным.
function commands.tutorial(player, arg)
	local profile = DataService.get(player)
	if arg == "reset" then
		profile.tutorialDone = false
		return "обучение сброшено — при следующем появлении включится"
	elseif arg == "skip" then
		profile.tutorialDone = true
		return "обучение помечено пройденным"
	end
	return profile.tutorialDone == true and "обучение пройдено (tutorialDone = true)" or "обучение будет показано при входе"
end

-- Быстрый дамп поручений и сюжета — чтобы видеть, что закрылось.
function commands.quests(player)
	local profile = DataService.get(player)
	local q = profile.quests
	if type(q) ~= "table" then
		return "у профиля пока нет заданий"
	end
	local out = {}
	local doneStory = 0
	for _ in pairs(q.done or {}) do
		doneStory += 1
	end
	table.insert(out, ("сюжет: сдано %d из %d, активно: %s"):format(doneStory, #Quests.List, tostring(q.active or "—")))
	local stats = profile.stats or {}
	local function dumpPeriod(name, entries)
		if not entries then
			table.insert(out, ("%s: не сгенерированы (будут при входе)"):format(name))
			return
		end
		local done = 0
		for _, entry in ipairs(entries) do
			if entry.done then
				done += 1
			end
		end
		table.insert(out, ("%s: закрыто %d из %d"):format(name, done, #entries))
		for _, entry in ipairs(entries) do
			local p = math.clamp((stats[entry.stat] or 0) - ((entry.base or {})[entry.stat] or 0), 0, entry.goal)
			table.insert(out, ("  %s — %d/%d%s"):format(entry.title or entry.id, p, entry.goal, entry.done and " ✓" or ""))
		end
	end
	if q.daily and q.daily.day == math.floor(os.time() / 86400) then
		dumpPeriod("день", q.daily.entries)
	else
		dumpPeriod("день", nil)
	end
	if q.weekly and q.weekly.week == math.floor((os.time() - 345600) / 604800) then
		dumpPeriod("неделя", q.weekly.entries)
	else
		dumpPeriod("неделя", nil)
	end
	return table.concat(out, "\n")
end

function commands.spawn(player, arg, countArg)
	local root = rootOf(player)
	if not root then
		return "нет персонажа"
	end
	if arg and tonumber(arg) then
		arg, countArg = nil, arg
	end
	local typeId = ENEMY_ALIASES[arg] or arg or "guard"
	local count = math.clamp(tonumber(countArg) or (typeId == "guard" and 5 or 1), 1, 20)
	if not Enemies.Types[typeId] then
		return "нет врага: " .. typeId
	end
	local ok, stats = pcall(Enemies.stats, typeId, "normal")
	if not ok then
		return "Enemies.stats(" .. typeId .. "): " .. tostring(stats)
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local center = root.Position + look * 9
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local offset = count > 1 and Vector3.new(math.cos(angle), 0, math.sin(angle)) * 3.5 or Vector3.zero
		local enemy = EnemyService.spawn(stats, center + offset, { parent = folder(), name = typeId })
		table.insert(spawned, enemy)
	end
	return ("%s × %d"):format(stats.name, count)
end

-- P6 охота: заспавнить ОСОБОГО врага рядом (проверка цепочки «Охота»).
function commands.special(player, arg)
	local root = rootOf(player)
	if not root then
		return "нет персонажа"
	end
	local typeId = ENEMY_ALIASES[arg] or arg or "guard"
	if not Enemies.Types[typeId] then
		return "нет врага: " .. typeId
	end
	local ok, stats = pcall(Enemies.stats, typeId, "normal")
	if not ok then
		return "Enemies.stats(" .. typeId .. "): " .. tostring(stats)
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local enemy = EnemyService.spawn(stats, root.Position + look * 9, { parent = folder(), name = typeId })
	table.insert(spawned, enemy)
	SpecialMobs.makeSpecial(enemy)
	return "★ Особый заспавнен: " .. tostring(enemy.model:GetAttribute("EnemyName")) .. " (HP " .. tostring(enemy.maxHealth) .. ")"
end

-- Проверка награды охоты: добить особого боевым пайплайном (onDeath выдаёт
-- золото/материал и крутит счётчик specialKilled — REAL-контекст).
function commands.killspecial(player)
	for i = #spawned, 1, -1 do
		local enemy = spawned[i]
		if enemy.alive and enemy.special and enemy.model and enemy.model.Parent then
			EnemyService.kill(enemy, player)
			return "★ Особый добит боевым пайплайном — награда должна прийти"
		end
	end
	return "живого особого нет — сначала вызови special"
end

-- P6 дебафы: навесить вид на себя (проверка урона/замедления/визуала).
function commands.debuff(player, arg)
	local EnemyDebuffs = require(script.Parent.EnemyDebuffs)
	local kind = arg or "frost"
	if kind == "clear" then
		EnemyDebuffs.clear(player)
		return "дебаф снят"
	end
	if not ({ frost = true, burn = true, poison = true })[kind] then
		return "debuff [frost|burn|poison|clear]"
	end
	EnemyDebuffs.apply(player, kind)
	return "дебаф на игроке: " .. kind .. " (тик урона, замедление, частицы)"
end

function commands.clear()
	local n = 0
	for _, enemy in ipairs(spawned) do
		if enemy.model and enemy.model.Parent then
			n += 1
		end
		EnemyService.remove(enemy)
	end
	table.clear(spawned)
	return "убрано врагов: " .. n
end

function commands.cd(player)
	AbilityService.resetCooldowns(player)
	return "перезарядки сброшены"
end

function commands.nocd(player, arg)
	local on = toggle(arg, noCooldown[player] ~= nil)
	if noCooldown[player] then
		noCooldown[player]:Disconnect()
		noCooldown[player] = nil
	end
	if on then
		noCooldown[player] = player.AttributeChanged:Connect(function(name)
			if string.sub(name, 1, 3) == "Cd_" and (player:GetAttribute(name) or 0) > 0 then
				task.defer(AbilityService.resetCooldowns, player)
			end
		end)
		AbilityService.resetCooldowns(player)
	end
	return "без перезарядки: " .. (on and "вкл" or "выкл")
end

-- «Дары Эха» без прохождения комнат.
function commands.boon(player, arg)
	local FloorBoonService = require(script.Parent.FloorBoonService)
	local n = math.clamp(tonumber(arg) or 1, 1, 5)
	local ok = FloorBoonService.debugOffer(player, n)
	return ok and ("дары: выборов %d"):format(n) or "дары: сначала зайдите на этаж (floor 1)"
end

function commands.god(player, arg)
	local on = toggle(arg, player:GetAttribute("DebugGod") == true)
	player:SetAttribute("DebugGod", on or nil)
	if on then
		commands.heal(player)
	end
	return "бессмертие: " .. (on and "вкл" or "выкл")
end

function commands.heal(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
	CombatService.refillHeals(player)
	return "здоровье полное"
end

function commands.star(player, arg)
	local weapon = DataService.get(player).equippedWeapon
	local level = tonumber(arg)
	if not weapon or not level then
		return "star <N>"
	end
	weapon.level = math.clamp(math.floor(level), 1, Echo.maxLevel(weapon.rarityId))
	player:SetAttribute("WeaponLevel", weapon.level)
	return ("%s: ★%d (потолок %d)"):format(weapon.name, weapon.level, Echo.maxLevel(weapon.rarityId))
end

-- Смещение камеры в осях персонажа (X вправо, Y вверх, Z назад).
local CAMERAS = {
	side = Vector3.new(16, 7, -4),
	front = Vector3.new(3, 6, -18),
	top = Vector3.new(0, 24, 3),
	back = Vector3.new(2, 9, 14),
}

-- Вход на этаж и возврат в хаб без врат и проверки прогресса.
function commands.floor(player, which)
	local id = tonumber(which) or 1
	if id % 1 ~= 0 or id < 1 or id > 5 then
		return "floor <1-5>"
	end
	local HubService = require(game:GetService("ServerScriptService").Hub.HubService)
	task.spawn(HubService.enterFloor, player, id, "normal")
	return "на этаж " .. id
end

function commands.floor1(player)
	return commands.floor(player, "1")
end

function commands.floor2(player)
	return commands.floor(player, "2")
end

function commands.floor3(player)
	return commands.floor(player, "3")
end

function commands.floor4(player)
	return commands.floor(player, "4")
end

function commands.floor5(player)
	return commands.floor(player, "5")
end

function commands.trophies(player, arg)
	local FloorService = require(script.Parent.FloorService)
	local floor = FloorService.floors[3]
	if not floor then
		return "нет этажа 3"
	end
	for _, zone in ipairs(floor.ctx.state.rooms) do
		if zone.cfg.trophy and zone.state ~= "cleared" then
			floor.ctx.clearZone(zone)
		end
	end
	if arg == "take" and floor.ctx.debugTrophies then
		local count = floor.ctx.debugTrophies(true)
		return ("трофеи взяты: %d/3 — решётка Трофейных ворот поднимается"):format(count)
	end
	return "трофеи открыты — подойдите к постаменту и удерживайте E"
end

function commands.zone(player, id)
	local FloorService = require(script.Parent.FloorService)
	local floor = FloorService.floorOf(player)
	if not floor or not id then
		return "zone <id>"
	end
	local zone = floor.ctx.zoneById(id)
	if not zone then
		local ids = {}
		for _, zoneState in ipairs(floor.ctx.state.rooms) do
			table.insert(ids, zoneState.cfg.id)
		end
		return "нет зоны «" .. id .. "»: " .. table.concat(ids, " ")
	end
	floor.ctx.teleportToZone(player, zone)
	return "зона " .. zone.cfg.name
end

-- «valves» — этаж 2: зачистить зоны вентилей (беседка, купальня, мельница) —
-- вентили можно поворачивать без боя (проверка Розового двора).
function commands.valves(player)
	local FloorService = require(script.Parent.FloorService)
	local floor = FloorService.floors[2]
	if not floor then
		return "нет этажа 2"
	end
	local count = 0
	for _, zone in ipairs(floor.ctx.state.rooms) do
		if zone.cfg.valve then
			if zone.state ~= "cleared" then
				floor.ctx.clearZone(zone)
			end
			count += 1
		end
	end
	return "вентили открыты: " .. count .. " — подойдите к каждому и удерживайте E"
end

function commands.hub(player)
	local HubService = require(game:GetService("ServerScriptService").Hub.HubService)
	task.spawn(HubService.returnToHub, player)
	return "в хаб"
end

-- Прослушивание звуков (Sfx.candidates): «sfx» — список, «sfx swing3 2» —
-- выбрать вариант 2 и сразу проиграть, «sfx swing3» — повторить выбранный.
function commands.sfx(player, name, index)
	local Sfx = require(ReplicatedStorage.Shared.Config.Sfx)
	if not name then
		local lines = {}
		for soundName, options in pairs(Sfx.candidates) do
			local labels = {}
			for i, option in ipairs(options) do
				table.insert(labels, ("%d) %s"):format(i, option.label))
			end
			local current = player:GetAttribute("SfxPick_" .. soundName) or Sfx.picked[soundName] or 1
			table.insert(lines, ("%s [сейчас %d]: %s"):format(soundName, current, table.concat(labels, "; ")))
		end
		table.sort(lines)
		return table.concat(lines, "\n")
	end
	-- Команды приходят в нижнем регистре: hubawaken → hubAwaken.
	for soundName in pairs(Sfx.candidates) do
		if string.lower(soundName) == name then
			name = soundName
		end
	end
	local options = Sfx.candidates[name]
	if not options then
		return "нет кандидатов для «" .. name .. "» (см. sfx)"
	end
	local attribute = "SfxPick_" .. name
	local pick = tonumber(index) or player:GetAttribute(attribute) or Sfx.picked[name] or 1
	pick = math.clamp(math.floor(pick), 1, #options)
	player:SetAttribute(attribute, pick)
	-- SfxAudition меняется на каждый вызов: клиент проигрывает звук и повтор.
	player:SetAttribute("SfxAudition", ("%s#%d"):format(name, (player:GetAttribute("SfxAuditionN") or 0) + 1))
	player:SetAttribute("SfxAuditionN", (player:GetAttribute("SfxAuditionN") or 0) + 1)
	return ("%s → %d) %s"):format(name, pick, options[pick].label)
end

function commands.cam(player, arg)
	local offset = CAMERAS[arg or ""]
	player:SetAttribute("DebugCam", offset)
	return offset and ("камера: " .. arg) or "камера: обычная"
end

local CLASS_ALIASES = { warrior = "warrior", mage = "mage", wizard = "mage" }

function commands.class(player, arg)
	local className = CLASS_ALIASES[arg or ""]
	if not className then
		return "class <warrior|mage>; сейчас: " .. tostring(DataService.get(player).className)
	end
	local profile = DataService.get(player)
	profile.className = className
	profile.classChosen = true -- окно выбора класса больше не показывать
	local ArmorService = require(script.Parent.ArmorService)
	ArmorService.onClassChanged(player)
	-- Оружие под класс: лучшее своё из инвентаря или стартовое (посох послушника / ржавый меч).
	local EquipmentService = require(script.Parent.EquipmentService)
	EquipmentService.ensureClassWeapon(player)
	local okMage, MageService = pcall(require, script.Parent.MageService)
	if okMage and MageService.publishClass then
		MageService.publishClass(player)
	end
	local ProgressionService = require(script.Parent.ProgressionService)
	ProgressionService.applyLevel(player, true)
	local ManaService = require(script.Parent.ManaService)
	ManaService.recalc(player, true)
	local mana, maxMana = ManaService.get(player)
	return ("класс: %s · мана %d/%d"):format(className, mana, maxMana)
end

function commands.mana(player, arg)
	local ManaService = require(script.Parent.ManaService)
	if arg == "full" then
		ManaService.refill(player)
	elseif tonumber(arg) then
		local mana = ManaService.get(player)
		ManaService.gain(player, tonumber(arg) - mana)
	end
	local mana, maxMana = ManaService.get(player)
	local _, regen, parts = ManaService.compute(player)
	return ("мана %.1f/%d · реген %.2f/с (класс %d, броня +%d, посох +%d)"):format(mana, maxMana, regen,
		parts.classMana or 0, parts.gearMana or 0, parts.weaponMana or 0)
end

function commands.magearmor(player, arg)
	local give = ServerStorage.KlinokDebug:FindFirstChild("GiveArmor")
	if not give then
		return "нет GiveArmor (ArmorService не запущен?)"
	end
	if DataService.get(player).className ~= "mage" then
		commands.class(player, "mage")
	end
	return give:Invoke(player.Name, arg or "chronicler")
end

-- Аудит тесноты для камеры (06.11.2026): у каждой точки этажа (Config/FloorNPoints) лучи
-- по коллизиям карты (то же, во что упирается камера) — ширина прохода по самой
-- узкой оси и высота потолка (потолок без коллизии не виден — его ищем по мешам офлайн). Камере нужно ~12 стад позади и ~2 сбоку, поэтому тесно:
-- ширина < 16 или потолок < 11. Отчёт — самые тесные места, по зонам.
function commands.camaudit(player, which)
	local floorId = tonumber(which) or player:GetAttribute("FloorId") or 1
	local ok, points = pcall(function()
		return require(Shared.Config["Floor" .. floorId .. "Points"])
	end)
	if not ok or type(points) ~= "table" then
		return "нет точек этажа " .. tostring(floorId)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local function solid(part)
		return part.CanCollide and part.Name ~= "WallCap" and math.max(part.Size.X, part.Size.Y, part.Size.Z) >= 1.6
	end
	local function cast(from, dir)
		local exclude = {}
		for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
			if p.Character then
				table.insert(exclude, p.Character)
			end
		end
		for _ = 1, 8 do
			params.FilterDescendantsInstances = exclude
			local hit = workspace:Raycast(from, dir, params)
			if not hit then
				return dir.Magnitude
			end
			if solid(hit.Instance) then
				return hit.Distance
			end
			table.insert(exclude, hit.Instance)
		end
		return dir.Magnitude
	end
	local rows = {}
	for zone, list in pairs(points) do
		if type(list) == "table" then
			for name, pos in pairs(list) do
				if typeof(pos) == "Vector3" then
					local origin = pos + Vector3.new(0, 3.5, 0)
					local width = math.huge
					for a = 0, 7 do
						local th = a * math.pi / 8
						local d = Vector3.new(math.cos(th), 0, math.sin(th))
						width = math.min(width, cast(origin, d * 30) + cast(origin, -d * 30))
					end
					local ceiling = cast(pos + Vector3.new(0, 1, 0), Vector3.new(0, 40, 0)) + 1
					if width < 16 or ceiling < 11 then
						table.insert(rows, { zone = zone, name = name, pos = pos, width = width, ceiling = ceiling,
							score = math.min(width / 16, ceiling / 11) })
					end
				end
			end
		end
	end
	table.sort(rows, function(a, b)
		return a.score < b.score
	end)
	local lines = { ("Этаж %d: тесных точек %d (ширина < 16 или потолок < 11)"):format(floorId, #rows) }
	for _, r in ipairs(rows) do
		table.insert(lines, ("%-10s %-22s ширина %5.1f  потолок %5.1f  (%.0f, %.0f, %.0f)"):format(
			r.zone, r.name, r.width, r.ceiling >= 40 and 99 or r.ceiling, r.pos.X, r.pos.Y, r.pos.Z))
	end
	local text = table.concat(lines, "\n")
	print(text)
	local folder = ServerStorage:FindFirstChild("KlinokDebug")
	if folder then
		local value = folder:FindFirstChild("CamAudit") or Instance.new("StringValue")
		value.Name = "CamAudit"
		value.Value = text
		value.Parent = folder
	end
	return ("этаж %d: тесных точек %d — список в Output"):format(floorId, #rows)
end

-- Броня-комплекты (Config/Armor, ArmorFloors): armor [id] [повторок].
function commands.armor(player, id, copies)
	local Armor = require(Shared.Config.Armor)
	local className = DataService.get(player).className or "warrior"
	if not id then
		local lines = {}
		for _, setId in ipairs(Armor.SetOrderByClass[className] or {}) do
			local set = Armor.Sets[setId]
			table.insert(lines, ("э%d %-10s %-18s %s%s"):format(set.floor or 1, set.rarity, setId, set.title or set.name,
				set.passive and (" · " .. set.passive.name) or ""))
		end
		return table.concat(lines, "\n")
	end
	local give = ServerStorage.KlinokDebug:FindFirstChild("GiveArmor")
	if not give then
		return "нет GiveArmor (ArmorService не запущен?)"
	end
	return give:Invoke(player.Name, id, tonumber(copies) or 1)
end

-- Материалы для кузнеца: mat [этаж|id] [N].
function commands.mat(player, what, count)
	local Loot = require(Shared.Config.Loot)
	local profile = DataService.get(player)
	if not what then
		local lines = {}
		for floor = 1, 5 do
			local id = Loot.materialOf(floor)
			table.insert(lines, ("этаж %d · %s (%s): %d"):format(floor, Loot.materialName(floor), id, profile.materials[id] or 0))
		end
		return table.concat(lines, "\n")
	end
	local floor = tonumber(what)
	local id = floor and Loot.materialOf(floor) or what
	local total = DataService.addMaterial(player, id, tonumber(count) or 100)
	return ("%s: %d"):format(id, total)
end

-- Маг: посохи (Config.LootMage). staff <id|спелл|floorN|all>.
function commands.staff(player, arg)
	local LootMage = require(Shared.Config.LootMage)
	if DataService.get(player).className ~= "mage" then
		commands.class(player, "mage")
	end
	if not arg then
		local lines = {}
		for floor = 1, 5 do
			local ids = {}
			for _, weapon in ipairs(LootMage.Weapons) do
				if weapon.floor == floor then
					table.insert(ids, weapon.id .. (weapon.ability and ("(" .. weapon.ability .. ")") or ""))
				end
			end
			table.insert(lines, ("этаж %d: %s"):format(floor, table.concat(ids, " ")))
		end
		return "staff <id|спелл|floorN|all>\n" .. table.concat(lines, "\n")
	end
	local floor = tonumber(string.match(arg, "^floor(%d)$") or string.match(arg, "^f(%d)$") or "")
	if arg == "all" or floor then
		local names = {}
		local last = nil
		for _, weapon in ipairs(LootMage.Weapons) do
			if arg == "all" or weapon.floor == floor then
				if last then
					give(player, last.id)
					table.insert(names, last.name)
				end
				last = weapon
			end
		end
		if not last then
			return "нет посохов этажа " .. tostring(arg)
		end
		return give(player, last.id) .. "; в инвентаре: " .. table.concat(names, ", ")
	end
	-- Имя заклинания → посох с ним.
	for _, weapon in ipairs(LootMage.Weapons) do
		if weapon.ability == arg then
			return give(player, weapon.id) .. " (заклинание " .. arg .. ")"
		end
	end
	local id = Loot.template(arg) and arg or (Loot.template(arg .. "_staff") and arg .. "_staff") or arg
	return give(player, id)
end

function commands.veil(player)
	if DataService.get(player).className ~= "mage" then
		commands.class(player, "mage")
	end
	local MageService = require(script.Parent.MageService)
	AbilityService.resetCooldowns(player)
	local result = MageService.veil(player)
	if type(result) == "table" and result.ok then
		-- Фактические числа с учётом древа («Безмолвие», «Тихий уход», «Тихий шаг»).
		local veil = require(Shared.Config.LootMage).Veil
		local TalentMods = require(script.Parent.TalentMods)
		return ("покров: %.1f с, перезарядка %.1f с (засада ×%.1f)"):format(result.duration or veil.duration,
			result.cooldown or veil.cooldown, TalentMods.ambush(player, veil.ambush))
	end
	return "покров не вышел: " .. tostring(type(result) == "table" and result.reason or result)
end

-- Уровень героя (проверка баланса этажей и очков древа).
-- Сундуки этажей v3 (ChestService): выдать / показать / очистить.
function commands.chest(player, action, floorArg, gradeArg, countArg)
	local Chests = require(Shared.Config.Chests)
	local ChestService = require(script.Parent.ChestService)
	action = action or "list"
	if action == "give" or action == "fly" then
		local floorId = Chests.clampFloor(tonumber(floorArg) or 1)
		local grade = gradeArg == "gold" and "gold" or "common"
		local count = math.clamp(math.floor(tonumber(countArg) or 1), 1, 50)
		local root = rootOf(player)
		local position = root and (root.Position + root.CFrame.LookVector * 10 - Vector3.new(0, 3, 0)) or nil
		for i = 1, count do
			ChestService.grant(player, floorId, grade, {
				position = position,
				kind = "debug",
				silent = action == "give" and i < count,
			})
		end
		local info = Chests.info(floorId, grade)
		return ("+%d «%s» · всего сундуков %d"):format(count, info.name, ChestService.state(player).total)
	elseif action == "clear" then
		ChestService.clear(player)
		return "сундуки убраны"
	end
	local state = ChestService.state(player)
	if #state.stacks == 0 then
		return "сундуков нет (chest give 1 gold)"
	end
	local lines = {}
	for _, stack in ipairs(state.stacks) do
		table.insert(lines, ("%s ×%d (%s)"):format(stack.name, stack.count, stack.key))
	end
	table.insert(lines, state.canOpen and "открыть: сумка [I] → «Сундуки»" or "открыть можно в долине (hub)")
	return table.concat(lines, "\n")
end

-- Врата Печатей: какие этажи открыты на карте (profile.floorClears, как пишет FloorService).
function commands.gate(player, arg)
	local Hub = require(Shared.Config.Hub)
	local profile = DataService.get(player)
	profile.floorClears = profile.floorClears or {}
	local count = #Hub.Floors
	if arg == "reset" then
		profile.floorClears = {}
	elseif arg == "all" then
		for f = 1, count do
			local clears = {}
			for _, d in ipairs(Hub.Difficulties) do
				clears[d.id] = true
			end
			profile.floorClears[f] = clears
		end
	elseif tonumber(arg) then
		local open = math.clamp(math.floor(tonumber(arg)), 1, count)
		for f = 1, count do
			if f < open then
				local clears = profile.floorClears[f] or {}
				clears.normal = true
				clears[Hub.FloorUnlockDifficulty] = true
				profile.floorClears[f] = clears
			else
				profile.floorClears[f] = nil
			end
		end
	end
	local highest = 1
	local passed = {}
	for f = 1, count do
		local clears = profile.floorClears[f]
		if clears and clears[Hub.FloorUnlockDifficulty] and f + 1 <= count then
			highest = math.max(highest, f + 1)
		end
		if clears and next(clears) then
			local names = {}
			for _, d in ipairs(Hub.Difficulties) do
				if clears[d.id] then
					table.insert(names, d.id)
				end
			end
			table.insert(passed, ("%d: %s"):format(f, table.concat(names, "+")))
		end
	end
	player:SetAttribute("FloorsUnlocked", highest)
	return ("открыто этажей: %d · пройдено — %s · открой Врата заново"):format(highest, #passed > 0 and table.concat(passed, ", ") or "ничего")
end

function commands.level(player, arg)
	local Classes = require(Shared.Config.Classes)
	local level = math.clamp(math.floor(tonumber(arg) or 0), 1, Classes.MaxLevel)
	if not tonumber(arg) then
		return ("level <1-%d>; сейчас "):format(Classes.MaxLevel) .. tostring(DataService.get(player).level)
	end
	local profile = DataService.get(player)
	profile.level = level
	profile.xp = 0
	local ProgressionService = require(script.Parent.ProgressionService)
	ProgressionService.applyLevel(player, true)
	local TalentService = require(script.Parent.TalentService)
	TalentService.publish(player)
	local state = TalentService.state(player)
	return ("уровень %d · очков древа %d (свободно %d)"):format(level, state.points, state.free)
end

-- Древо талантов текущего класса (Config.Talents).
local function talentSummary(player)
	local Talents = require(Shared.Config.Talents)
	local TalentService = require(script.Parent.TalentService)
	local state = TalentService.state(player)
	local tree = Talents.tree(state.classId)
	local lines = { ("%s · ур. %d · очки %d, потрачено %d, свободно %d · сбросов %d (следующий %d з.)"):format(
		state.className, state.level, state.points, state.spent, state.free, state.resets, state.resetCost) }
	for _, branch in ipairs(tree.branches) do
		local names, minors = {}, 0
		for _, n in ipairs(branch.nodes) do
			if state.learned[n.id] then
				if n.kind == "minor" then
					minors += 1
				else
					table.insert(names, n.name)
				end
			end
		end
		table.insert(lines, ("  %s %d/%d · малых %d/14: %s"):format(branch.name, state.byBranch[branch.id] or 0,
			Talents.branchCost(branch), minors, #names > 0 and table.concat(names, ", ") or "—"))
	end
	return table.concat(lines, "\n")
end

function commands.talents(player, action, arg)
	local Talents = require(Shared.Config.Talents)
	local TalentService = require(script.Parent.TalentService)
	local classId = TalentService.state(player).classId
	local tree = Talents.tree(classId)
	if action == "list" then
		-- list — узлы и ключевые; list all — ещё и 14 малых узлов каждого пути.
		local lines = {}
		for i, branch in ipairs(tree.branches) do
			table.insert(lines, ("%d %s (%d очков): малые — %s / %s / %s"):format(i, branch.name, Talents.branchCost(branch),
				branch.minor.A.text, branch.minor.B.text, branch.minor.C.text))
			for _, n in ipairs(branch.nodes) do
				if n.kind ~= "minor" or arg == "all" then
					table.insert(lines, ("  %s %-16s %s (%d) — %s"):format(n.slot, n.id, n.name, n.cost, n.text))
				end
			end
		end
		return table.concat(lines, "\n")
	elseif action == "learn" and arg then
		local result = TalentService.learn(player, arg)
		if not result.ok then
			return ("не изучено: %s"):format(result.text or result.reason)
		end
	elseif action == "all" or action == "branch" then
		local index = tonumber(arg)
		for i, branch in ipairs(tree.branches) do
			if action == "all" or i == index then
				for _, n in ipairs(branch.nodes) do
					TalentService.learn(player, n.id, true)
				end
			end
		end
	elseif action == "reset" then
		TalentService.reset(player, true)
	elseif action == "free" then
		TalentService.bonus[player] = nil
		TalentService.publish(player)
	elseif action == "points" then
		TalentService.bonus[player] = math.clamp(math.floor(tonumber(arg) or 0), 0, 100)
		TalentService.publish(player)
	elseif action then
		return "talents [list [all]|learn <id>|all|branch <1-3>|reset|free|points N]"
	end
	return talentSummary(player)
end
commands.talent = commands.talents

function DebugCommands.run(line: string): string
	local words = {}
	local player = nil
	for word in string.gmatch(tostring(line), "%S+") do
		if string.sub(word, 1, 1) == "@" then
			player = Players:FindFirstChild(string.sub(word, 2))
			if not player then
				return "нет игрока " .. word
			end
		else
			table.insert(words, string.lower(word))
		end
	end
	player = player or Players:GetPlayers()[1]
	local name = table.remove(words, 1) or "help"
	local command = commands[name]
	if not command then
		return "нет команды '" .. name .. "'\n" .. HELP
	end
	if not player and name ~= "help" then
		return "на сервере нет игроков"
	end
	local ok, result = pcall(command, player, table.unpack(words))
	return ok and tostring(result) or ("ошибка: " .. tostring(result))
end

function DebugCommands.start()
	local debugFolder = ServerStorage:FindFirstChild("KlinokDebug") or Instance.new("Folder")
	debugFolder.Name = "KlinokDebug"
	debugFolder.Parent = ServerStorage
	local cmd = debugFolder:FindFirstChild("Cmd") or Instance.new("BindableFunction")
	cmd.Name = "Cmd"
	cmd.Parent = debugFolder
	cmd.OnInvoke = DebugCommands.run

	Players.PlayerRemoving:Connect(function(player)
		if noCooldown[player] then
			noCooldown[player]:Disconnect()
			noCooldown[player] = nil
		end
	end)

	print('[DebugCommands] Command Bar (сервер): print(game.ServerStorage.KlinokDebug.Cmd:Invoke("help"))')
end

return DebugCommands
