--!nonstrict
-- test_enemy_anims.lua — шаг 1 конвейера врагов: данные анимаций.
-- Загружает все наборы Shared/Anim через Resolve и проверяет:
--   * время кадров растёт, первый кадр в 0, длина = время последнего кадра;
--   * сглаживания и маркеры корректны;
--   * все анимации из таблицы раздела 3.5 есть у каждого врага;
--   * проверочные суммы клинка из ТЗ (страж, латник);
--   * inherit / amp / speed / override раскрываются как описано в 3.2.
-- Запуск: в Studio (Edit/Client) через s.js exec, или без Studio:
--   node tools/run-luau.js tools/lua/test_enemy_anims.lua

local Shared = (_G :: any).KlinokShared or game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Resolve = require(Shared.Anim.Resolve)
local EnemyVisuals = require(Shared.Config.EnemyVisuals)

local out = {}
local failures = 0

local function check(label: string, ok: boolean, detail: string?)
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %s%s"):format(ok and "OK  " or "FAIL", label, detail and ("  — " .. detail) or "")
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

-- 1. Все наборы раскрываются и проходят проверку.
out[#out + 1] = "Наборы анимаций:"
local total = 0
for _, setName in ipairs(Resolve.SETS) do
	local ok, set = pcall(Resolve.forSet, setName)
	check(("набор %s загружается"):format(setName), ok, not ok and tostring(set) or nil)
	if ok then
		local names = {}
		for name in pairs(set) do
			table.insert(names, name)
		end
		table.sort(names)
		local problems = {}
		for _, name in ipairs(names) do
			total += 1
			for _, problem in ipairs(Resolve.validate(set[name])) do
				table.insert(problems, problem)
			end
		end
		check(("%s: %d анимаций без ошибок"):format(setName, #names), #problems == 0, #problems > 0 and table.concat(problems, "; ") or nil)
	end
end

-- 2. Таблица 3.5: всё, что нужно аниматору, существует.
out[#out + 1] = "Таблица 3.5 (состояние → анимация):"
for typeId, config in pairs(EnemyVisuals.Types) do
	local set = Resolve.forSet(config.set)
	local missing = {}
	for _, name in ipairs(EnemyVisuals.requiredAnimations(typeId)) do
		if not set[name] then
			table.insert(missing, name)
		end
	end
	check(("%s (%s): все анимации на месте"):format(typeId, config.set), #missing == 0, #missing > 0 and ("нет: " .. table.concat(missing, ", ")) or nil)
end

-- 3. Проверочные суммы клинка из ТЗ.
out[#out + 1] = "Направление клинка (RUA.x + RLA.x + RH.x):"
local function bladeAt(setName: string, animName: string, frameIndex: number): number
	local frame = Resolve.forSet(setName)[animName].frames[frameIndex]
	return (frame.RUA_x or 0) + (frame.RLA_x or 0) + (frame.RH_x or 0)
end
check("страж: конец замаха = 180", near(bladeAt("Guard", "Slash_Windup", 2), 180))
check("страж: кадр удара = 0", near(bladeAt("Guard", "Slash_Strike", 2), 0))
check("латник: Idle = 80", near(bladeAt("Knight", "Idle", 1), 80))
check("латник: Slam_Windup = 180", near(bladeAt("Knight", "Slam_Windup", 2), 180))
check("привратник: Walk = −95", near(bladeAt("Gatekeeper", "Walk", 1), -95))

-- 4. Раскрытие наследования.
out[#out + 1] = "Раскрытие inherit / amp / speed / override:"
local shadeWalk = Resolve.forSet("Shade").Walk
local baseWalk = Resolve.forSet("Base").Walk
check("Тень.Walk: длина 0,8 / 1,6 = 0,5", near(shadeWalk.length, 0.5), tostring(shadeWalk.length))
check("Тень.Walk: колено ×1,3 (−65 → −84,5)", near(shadeWalk.frames[2].LLL_x, -84.5), tostring(shadeWalk.frames[2].LLL_x))
check("Тень.Walk: override UT −25 во всех кадрах", near(shadeWalk.frames[1].UT_x, -25) and near(shadeWalk.frames[3].UT_x, -25))
check("Тень.Walk: маркер Step на 0,25", #shadeWalk.markers == 2 and near(shadeWalk.markers[2].t, 0.25))
check("Base.Walk не изменилась после наследования", near(baseWalk.frames[2].LLL_x, -65))
local charge = Resolve.forSet("Gatekeeper").Charge
check("Привратник.Charge: длина 0,4, цикл", near(charge.length, 0.4) and charge.loop == true)
check("from = pose: Slash_Windup", Resolve.forSet("Guard").Slash_Windup.fromPose == true)
check("без from: Stun", Resolve.forSet("Base").Stun.fromPose == false)
check("Мартир берёт Strafe из Base", Resolve.forSet("Martyr").Strafe == Resolve.forSet("Base").Strafe)

out[#out + 1] = ("\nВсего анимаций: %d"):format(total)
out[#out + 1] = ("ИТОГО: %s"):format(failures == 0 and "все проверки пройдены" or (failures .. " провалов"))
return table.concat(out, "\n")
