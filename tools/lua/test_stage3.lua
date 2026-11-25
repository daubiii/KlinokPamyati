--!nonstrict
-- test_stage3.lua — прогон боевых проверок этапа 3 в Play (контекст Server).
-- Проверяем: комбо из 3 ударов, урон с бронёй, парирование, штраф,
-- контратаку ×2, уклонение от красной атаки.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CS = require(game.ServerScriptService.Systems.CombatService)
local MS = require(game.ServerScriptService.Systems.MeleeService)
local ES = require(game.ServerScriptService.Systems.EnemyService)
local Combat = require(game.ReplicatedStorage.Shared.Config.Combat)

local player = Players:GetPlayers()[1]
if not player or not player.Character then
	return "нет игрока"
end

local out = {}
local failures = 0

local function check(label, actual, expected)
	local ok
	if type(expected) == "number" and type(actual) == "number" then
		ok = math.abs(actual - expected) < 0.01
	else
		ok = actual == expected
	end
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %-42s факт=%s ожидание=%s"):format(
		ok and "OK  " or "FAIL",
		label,
		tostring(actual),
		tostring(expected)
	)
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local dummy = ES.all()[1]
local root = player.Character.HumanoidRootPart
local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

-- Игрок сбрасывается и ставится вплотную к манекену, манекен оглушён на минуту,
-- чтобы его собственные атаки не мешали проверкам урона.
CS.reset(player)
CS.applyClass(player, "warrior", 1)
root.CFrame = CFrame.new(0, 3.5, -4)
dummy.stunUntil = now() + 60
humanoid.Health = humanoid.MaxHealth
task.wait(0.3)

out[#out + 1] = "1. Комбо и урон"
local hit1 = MS.requestAttack(player)
task.wait(0.55)
local hit2 = MS.requestAttack(player)
task.wait(0.55)
local hit3 = MS.requestAttack(player)
task.wait(0.55)
local hit4 = MS.requestAttack(player)

check("удар 1: комбо", hit1.combo, 1)
check("удар 2: комбо", hit2.combo, 2)
check("удар 3: комбо", hit3.combo, 3)
check("удар 4: комбо снова с 1", hit4.combo, 1)
check("урон удара (меч, обычное, ур.1)", hit1.damage, 20)
check("попаданий в манекене на первом ударе", hit1.hits, 1)
check("HP манекена после 4 ударов", dummy.health, 10)

local early = MS.requestAttack(player)
check("удар вне перезарядки отклонён", early.ok, false)
check("причина отказа", early.reason, "cooldown")

out[#out + 1] = "\n2. Парирование: успех и контратака"
humanoid.Health = humanoid.MaxHealth
local parryRequest = CS.requestParry(player)
check("окно парирования открыто", parryRequest.ok, true)
check("окно воина 0.35 с", parryRequest.window, 0.35)
task.wait(0.1)
local result, taken = CS.resolveIncomingAttack(player, { damage = 20, parryable = true, source = "Test" })
check("белая атака в окне", result, "parried")
check("урон при парировании", taken, 0)
check("контратака заряжена", CS.getState(player).counterCharged, true)
check("HP не изменился", humanoid.Health, humanoid.MaxHealth)
check("шкала способностей +1", CS.getState(player).abilityCharge, 1)

task.wait(0.55)
local counterHit = MS.requestAttack(player)
check("контратака ×2 по урону", counterHit.damage, 40)
check("флаг контратаки снят", counterHit.counter, true)

out[#out + 1] = "\n3. Парирование: штраф за промах"
task.wait(1.2)
humanoid.Health = humanoid.MaxHealth
local miss = CS.requestParry(player)
check("окно открыто", miss.ok, true)
task.wait(parryRequest.window + 0.12)
check("состояние восстановления", CS.isRecovering(player), true)
local blocked = MS.requestAttack(player)
check("удар во время штрафа", blocked.ok, false)
check("причина отказа", blocked.reason, "recovering")
check("счётчик промахов", CS.getState(player).parryFailures, 1)
task.wait(Combat.Parry.failPause + 0.15)
check("штраф закончился", CS.isRecovering(player), false)

out[#out + 1] = "\n4. Уклонение от красной атаки"
local dodgeOk, dodgeResponse = CS.requestDodge(player, Vector3.new(0, 0, -1))
check("рывок разрешён", dodgeOk, true)
local redResult, redTaken = CS.resolveIncomingAttack(player, { damage = 40, parryable = false, source = "Test" })
check("красная атака во время рывка", redResult, "dodged")
check("урон", redTaken, 0)
task.wait(0.5)
local redAfter = CS.resolveIncomingAttack(player, { damage = 40, parryable = false, source = "Test" })
check("та же атака после рывка", redAfter, "hit")

out[#out + 1] = "\n5. Манекен: замах, парирование, оглушение"
CS.reset(player)
humanoid.Health = humanoid.MaxHealth
dummy.stunUntil = 0
dummy.health = dummy.maxHealth
dummy.alive = true

local parriedInTime = false
local sawParryable = false
local sawDodgeOnly = false
local deadline = os.clock() + 10
while os.clock() < deadline do
	local state = dummy.model:GetAttribute("EnemyState")
	local telegraph = dummy.model:GetAttribute("EnemyTelegraph")
	if state == "windup" and telegraph == "parryable" then
		sawParryable = true
		-- Замах 0.6 с, окно парирования 0.35 с: ждём 0.3 и парируем под удар.
		task.wait(0.3)
		CS.requestParry(player)
		local parryDeadline = os.clock() + 0.5
		while os.clock() < parryDeadline do
			if CS.getState(player).parrySuccesses > 0 then
				parriedInTime = true
				break
			end
			task.wait(0.02)
		end
		if parriedInTime then
			break
		end
	end
	if state == "windup" and telegraph == "dodgeOnly" then
		sawDodgeOnly = true
	end
	task.wait(0.02)
end

check("манекен показал белый (парируемый) замах", sawParryable, true)
check("манекен показал красный замах", sawDodgeOnly, true)
check("парирование удара манекена", parriedInTime, true)
check("манекен оглушён", dummy.model:GetAttribute("EnemyState"), "stunned")
check("HP игрока не пострадал", humanoid.Health, humanoid.MaxHealth)

out[#out + 1] = ("\nИТОГО: %s"):format(failures == 0 and "все проверки пройдены" or (failures .. " провалов"))
return table.concat(out, "\n")
