--!nonstrict
-- test_stage3_client.lua — прогон боя этапа 3 из клиентского контекста.
--
-- Зачем из клиента: execute_luau живёт в отдельной VM со своим кэшем require,
-- поэтому require(...) в проверке даёт КОПИЮ модулей, а не живую игру.
-- Живую игру можно проверить только через реальные пути: ремоуты и атрибуты
-- DataModel, которые публикует настоящий сервер.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net.Net)

local player = Players.LocalPlayer
local attackRemote = Net.get("RequestAttack")
local parryRemote = Net.get("RequestParry")
local dodgeRemote = Net.get("RequestDodge")

local out = {}
local failures = 0

local function check(label, actual, expected)
	local ok
	if type(expected) == "number" and type(actual) == "number" then
		ok = math.abs(actual - expected) < 0.02
	else
		ok = actual == expected
	end
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %-44s факт=%s ожидание=%s"):format(
		ok and "OK  " or "FAIL",
		label,
		tostring(actual),
		tostring(expected)
	)
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function dummy()
	return Workspace:FindFirstChild("TrainingDummy", true)
end

local function waitFor(predicate, timeout: number, interval: number?)
	local deadline = os.clock() + (timeout or 5)
	while os.clock() < deadline do
		local ok, value = pcall(predicate)
		if ok and value then
			return value
		end
		task.wait(interval or 0.02)
	end
	return nil
end

local function enemyState()
	local model = dummy()
	return model and model:GetAttribute("EnemyState")
end

local function telegraph()
	local model = dummy()
	return model and model:GetAttribute("EnemyTelegraph")
end

local character = player.Character
if not character then
	return "нет персонажа"
end
local root = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- Ставим игрока вплотную к манекену (камера смотрит в −Z, манекен на −9).
root.CFrame = CFrame.new(0, 3.5, -4)
task.wait(0.4)

local model = dummy()
if not model then
	return "манекен не найден в Workspace"
end

out[#out + 1] = ("манекен: %s, HP %s/%s, состояние %s"):format(
	model.Name,
	tostring(model:GetAttribute("EnemyHealth")),
	tostring(model:GetAttribute("EnemyMaxHealth")),
	tostring(enemyState())
)

out[#out + 1] = "\n1. Комбо из 3 ударов и урон"
local healthBefore = model:GetAttribute("EnemyHealth")
local r1 = attackRemote:InvokeServer()
task.wait(0.55)
local r2 = attackRemote:InvokeServer()
task.wait(0.55)
local r3 = attackRemote:InvokeServer()
task.wait(0.55)
local r4 = attackRemote:InvokeServer()
task.wait(0.2)

check("удар 1: комбо", r1.combo, 1)
check("удар 2: комбо", r2.combo, 2)
check("удар 3: комбо", r3.combo, 3)
check("удар 4: комбо сначала", r4.combo, 1)
check("урон меча (воин ур.1, обычное)", r1.damage, 20)
check("попаданий на удар", r1.hits, 1)
check("HP манекена упал на 80", healthBefore - model:GetAttribute("EnemyHealth"), 80)

local early = attackRemote:InvokeServer()
check("удар в перезарядке отклонён", early.ok, false)
check("причина", early.reason, "cooldown")

out[#out + 1] = "\n2. Парирование: успех против замаха манекена"
humanoid.Health = humanoid.MaxHealth
task.wait(0.2)
local sawWindupParryable = waitFor(function()
	return enemyState() == "windup" and telegraph() == "parryable"
end, 12)
check("манекен начал белый замах", sawWindupParryable, true)

if sawWindupParryable then
	local baseline = player:GetAttribute("ParrySuccesses") or 0
	-- Замах 0.6 с, окно воина 0.35 с: жмём за 0.3 с до удара.
	task.wait(0.3)
	local parryResponse = parryRemote:InvokeServer()
	check("окно парирования открыто", parryResponse.ok, true)
	check("окно воина", parryResponse.window, 0.35)

	local parried = waitFor(function()
		return (player:GetAttribute("ParrySuccesses") or 0) > baseline
	end, 1.0)
	check("удар манекена спарирован", parried, true)
	check("манекен оглушён", waitFor(function()
		return enemyState() == "stunned"
	end, 3), true)
	check("последняя входящая атака", player:GetAttribute("LastIncoming"), "parried")
	check("контратака заряжена", player:GetAttribute("CounterCharged"), true)

	out[#out + 1] = "\n3. Контратака ×2"
	task.wait(0.5)
	local counter = attackRemote:InvokeServer()
	check("урон контратаки", counter.damage, 40)
	check("флаг контратаки в ответе", counter.counter, true)
	check("флаг снят после удара", player:GetAttribute("CounterCharged"), false)
end

out[#out + 1] = "\n4. Парирование: штраф за промах"
humanoid.Health = humanoid.MaxHealth
local readyToMiss = waitFor(function()
	return enemyState() == "recover"
end, 12)
if readyToMiss then
	local miss = parryRemote:InvokeServer()
	check("окно открыто в неудачный момент", miss.ok, true)
	task.wait(0.45)
	local blocked = attackRemote:InvokeServer()
	check("удар во время штрафа", blocked.ok, false)
	check("причина", blocked.reason, "recovering")
	task.wait(1.2)
	local recovered = attackRemote:InvokeServer()
	check("после штрафа удар снова проходит", recovered.ok, true)
end

out[#out + 1] = "\n5. Красный замах: только уклонение"
local sawRed = waitFor(function()
	return enemyState() == "windup" and telegraph() == "dodgeOnly"
end, 12)
check("манекен показал красный замах", sawRed, true)
if sawRed then
	local hpBeforeDodge = humanoid.Health
	task.wait(0.18)
	local dodgeResponse = dodgeRemote:InvokeServer(Vector3.new(0, 0, 1))
	check("рывок разрешён", dodgeResponse.ok, true)
	local dodged = waitFor(function()
		return player:GetAttribute("LastIncoming") == "dodged"
	end, 1.2)
	check("красная атака ушла в уклонение", dodged, true)
	check("урон не прошёл", humanoid.Health, hpBeforeDodge)
end

out[#out + 1] = ("\nИТОГО: %s"):format(failures == 0 and "все проверки пройдены" or (failures .. " провалов"))
return table.concat(out, "\n")
