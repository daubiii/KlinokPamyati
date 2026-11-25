--!nonstrict
-- test_stage4_client.lua — прогон этапа 4 «Враги».
-- Проверяем: числа типов врагов, правила состава комнат, броню танка,
-- красный замах мартира и снаряды стрелка. Всё через живую игру.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Enemies = require(ReplicatedStorage.Shared.Config.Enemies)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Net = require(ReplicatedStorage.Shared.Net.Net)

local player = Players.LocalPlayer
local attackRemote = Net.get("RequestAttack")
local dodgeRemote = Net.get("RequestDodge")
local parryRemote = Net.get("RequestParry")

local out = {}
local failures = 0

local function check(label, actual, expected)
	local ok
	if type(expected) == "number" and type(actual) == "number" then
		ok = math.abs(actual - expected) < 0.05
	else
		ok = actual == expected
	end
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %-46s факт=%s ожидание=%s"):format(
		ok and "OK  " or "FAIL",
		label,
		tostring(actual),
		tostring(expected)
	)
end

local function waitFor(predicate, timeout: number, interval: number?)
	local deadline = os.clock() + (timeout or 5)
	while os.clock() < deadline do
		local ok, value = pcall(predicate)
		if ok and value then
			return value
		end
		task.wait(interval or 0.03)
	end
	return nil
end

local function findEnemy(typeId: string)
	for _, instance in ipairs((Workspace:FindFirstChild("TestArena") or Workspace):GetDescendants()) do
		if instance:IsA("Model") and instance:GetAttribute("EnemyType") == typeId then
			return instance
		end
	end
	return nil
end

local character = player.Character
if not character then
	return "нет персонажа"
end

-- Персонаж может погибнуть и переродиться: держим ссылки свежими.
local root = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local function refresh()
	character = player.Character
	if not character then
		return false
	end
	root = character:FindFirstChild("HumanoidRootPart")
	humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return false
	end
	if humanoid.Health <= 0 then
		return false
	end
	humanoid.Health = humanoid.MaxHealth
	return true
end

local function placeAt(position: Vector3)
	for _ = 1, 20 do
		if refresh() then
			root.CFrame = CFrame.new(position)
			return true
		end
		task.wait(0.1)
	end
	return false
end

out[#out + 1] = "1. Числа из приложения Б (1 этаж, обычная сложность)"
local tank = Enemies.stats("tank", 1, "normal")
local archer = Enemies.stats("archer", 1, "normal")
local martyr = Enemies.stats("martyr", 1, "normal")
local shade = Enemies.stats("shade", 1, "normal")

check("танк: HP = 90 × 1.5", tank.health, 135)
check("танк: броня 10 + 3×0", tank.armor, 10)
check("танк: урон 20", tank.damage, 20)
check("стрелок: HP = 90 × 0.9", archer.health, 81)
check("стрелок: урон 18", archer.damage, 18)
check("мартир: HP = 90 × 0.8", martyr.health, 72)
check("тень: HP 90", shade.health, 90)
check("броня танка на 3 этаже", Enemies.stats("tank", 3, "normal").armor, 16)
check("ненормальный: HP × 1.8", Enemies.stats("shade", 1, "abnormal").health, 162)
check("невозможный: урон × 2.2", Enemies.stats("shade", 1, "impossible").damage, 44)

out[#out + 1] = "\n2. Правила состава комнат"
local function roleSet(composition)
	local set = {}
	for _, entry in ipairs(composition) do
		set[entry.stats.role] = true
	end
	return set
end

local firstRoom = Enemies.composeRoom(1, 1, "normal", Random.new(42))
local thirdRoom = Enemies.composeRoom(1, 3, "normal", Random.new(42))
local fifthFloor = Enemies.composeRoom(5, 5, "normal", Random.new(7))

local firstRoles = roleSet(firstRoom)
local firstRoleCount = 0
for _ in pairs(firstRoles) do
	firstRoleCount += 1
end
local thirdRoles = roleSet(thirdRoom)

check("комната 1 этажа 1: ровно две роли", firstRoleCount, 2)
check("комната 1: есть танк", firstRoles.tank, true)
check("комната 3: есть танк", thirdRoles.tank, true)
check("комната 3: есть дальний", thirdRoles.ranged, true)
check("комната 3: есть мешающий", thirdRoles.disruptor, true)
check("врагов в комнате 1 этажа 1 (3-4)", #firstRoom >= 3 and #firstRoom <= 4, true)
check("врагов в комнате 5 этажа 5 (5-8)", #fifthFloor >= 5 and #fifthFloor <= 8, true)

out[#out + 1] = "\n3. Враги на арене"
local spawnedTypes = {}
for _, instance in ipairs((Workspace:FindFirstChild("TestArena") or Workspace):GetDescendants()) do
	local typeId = instance:GetAttribute("EnemyType")
	if typeId and instance:IsA("Model") then
		spawnedTypes[typeId] = instance
	end
end
check("манекен", spawnedTypes.dummy ~= nil, true)
check("танк", spawnedTypes.tank ~= nil, true)
check("стрелок", spawnedTypes.archer ~= nil, true)
check("мартир", spawnedTypes.martyr ~= nil, true)
check("броня танка на арене", spawnedTypes.tank and spawnedTypes.tank:GetAttribute("EnemyArmor"), 10)

out[#out + 1] = "\n4. Броня танка: урон 20 превращается в 12.5"
local tankModel = spawnedTypes.tank
if tankModel then
	local hitLanded = false
	for attempt = 1, 4 do
		placeAt(Vector3.new(-11, 3.5, -10))
		task.wait(0.45)
		local hpBefore = tankModel:GetAttribute("EnemyHealth")
		local attack = attackRemote:InvokeServer()
		task.wait(0.3)
		local hpAfter = tankModel:GetAttribute("EnemyHealth")
		if attack.hits and attack.hits >= 1 then
			hitLanded = true
			check("удар попал (попытка " .. attempt .. ")", true, true)
			check("урон по танку с бронёй 10", hpBefore - hpAfter, 12.5)
			break
		end
	end
	if not hitLanded then
		check("удар попал", false, true)
	end
	check("формула: 20/(1+0.06×10)", 20 / (1 + 0.06 * 10), 12.5)
end

out[#out + 1] = "\n5. Мартир: только красный замах"
local martyrModel = spawnedTypes.martyr
if martyrModel then
	placeAt(Vector3.new(0, 3.5, -12))
	local telegraphs = {}
	local deadline = os.clock() + 10
	local lastPlace = 0
	while os.clock() < deadline do
		if os.clock() - lastPlace > 1 then
			placeAt(Vector3.new(0, 3.5, -12))
			lastPlace = os.clock()
		end
		local state = martyrModel:GetAttribute("EnemyState")
		local telegraph = martyrModel:GetAttribute("EnemyTelegraph")
		if state == "windup" and telegraph and telegraph ~= "none" then
			telegraphs[telegraph] = true
			task.wait(0.25)
		end
		task.wait(0.03)
	end
	check("мартир показывал красный", telegraphs.dodgeOnly == true, true)
	check("мартир не показывал белый", telegraphs.parryable == nil, true)
end

out[#out + 1] = "\n6. Стрелок: снаряд летит и попадает"
local archerModel = spawnedTypes.archer
if archerModel then
	local projectile = nil
	local deadline = os.clock() + 15
	local lastPlace = 0
	while os.clock() < deadline do
		if os.clock() - lastPlace > 0.6 then
			placeAt(Vector3.new(11, 3.5, -1))
			lastPlace = os.clock()
		end
		local folder = Workspace:FindFirstChild("Projectiles")
		local found = folder and folder:FindFirstChild("Projectile")
		if found then
			projectile = found
			break
		end
		task.wait(0.03)
	end

	check("снаряд появился", projectile ~= nil, true)
	if projectile then
		check("снаряд парируемый", projectile:GetAttribute("Parryable"), true)

		-- Снаряд уничтожается при попадании, поэтому итог читаем из атрибута
		-- игрока, который сервер выставляет в момент попадания.
		local resolved = waitFor(function()
			return player:GetAttribute("LastProjectileResult")
		end, 5)
		check("снаряд завершился", resolved ~= nil, true)
		out[#out + 1] = ("    результат снаряда: %s"):format(tostring(resolved))
		-- Стрелок может выпустить несколько снарядов: ждём, пока именно
		-- пойманный снаряд уйдёт из мира (попадание, стена или истечение).
		check("снаряд исчез из мира", waitFor(function()
			return projectile.Parent == nil
		end, 4), true)

		local incoming = waitFor(function()
			local value = player:GetAttribute("LastIncoming")
			return value and value ~= "none" and value
		end, 2)
		check("входящая атака зафиксирована", incoming ~= nil, true)
		out[#out + 1] = ("    последняя входящая: %s"):format(tostring(incoming))
	end
end

out[#out + 1] = ("\nИТОГО: %s"):format(failures == 0 and "все проверки пройдены" or (failures .. " провалов"))
return table.concat(out, "\n")
