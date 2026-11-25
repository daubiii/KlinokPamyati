--!nonstrict
--!nolint SameLineStatement
-- Anim/Martyr — Треснувший (ТЗ врагов, раздел 3.4). Таблица без изменений.
-- Процедурно поверх (EnemyAnimator): рывки головы в Idle и дрожь корпуса
-- в Explode_Windup.

local HUNCH = { UT = {-30,0,0}, HD = {25,0,0}, LTp = {0,-0.3,0},
	RUA = {30,0,15}, RLA = {40,0,0}, LUA = {30,0,-15}, LLA = {40,0,0},
	RUL = {15,0,0}, LUL = {15,0,0}, RLL = {-25,0,0}, LLL = {-25,0,0} }
local function with(base, extra) local t = table.clone(base) for k, v in pairs(extra) do t[k] = v end return t end
return {
	Idle = { length = 1.2, loop = true, priority = "Idle", keys = {
		with(HUNCH, { t = 0.0, e = "linear" }),
		with(HUNCH, { t = 0.6, e = "sine", HD = {25,15,10}, UT = {-28,0,-5} }),
		with(HUNCH, { t = 1.2, e = "sine" }),
	}},
	-- Бег рывками: руки тянутся вперёд, корпус раскачивается.
	Walk = { inherit = "Base.Walk", amp = 1.2, speed = 1.3,
		override = { UT = {-35,0,0}, HD = {30,0,0}, RUA = {70,0,10}, LUA = {70,0,-10}, RLA = {20,0,0}, LLA = {20,0,0} } },

	Explode_Windup = { length = 1.2, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.3, e = "quadOut", UT = {-5,0,0}, HD = {30,0,0}, LTp = {0,0.1,0},
			RUA = {150,0,40}, LUA = {150,0,-40}, RLA = {20,0,0}, LLA = {20,0,0} },
		{ t = 1.2, e = "linear", UT = {-10,0,0}, HD = {35,0,0}, LTp = {0,0.1,0},
			RUA = {155,0,45}, LUA = {155,0,-45}, RLA = {25,0,0}, LLA = {25,0,0} },
	}},
	-- Ударной анимации нет: на "strike" сразу взрыв и распад (маркер Shatter в 0).
}
