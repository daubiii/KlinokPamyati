--!nonstrict
--!nolint SameLineStatement
-- Anim/Shade — Тень (ТЗ врагов, раздел 3.4). Таблица без изменений.
-- Атака идёт по состояниям сервера windup → dash → strike → recover:
-- Dash_Windup, Dash, Combo_Strike, Combo_Recover (раздел 3.5).

local LOW = { LTp = {0,-0.35,0}, UT = {-18,0,0}, HD = {12,0,0},
	RUL = {30,0,0}, LUL = {20,0,0}, RLL = {-45,0,0}, LLL = {-35,0,0}, RF = {15,0,0}, LF = {15,0,0},
	RUA = {20,0,25}, RLA = {60,0,0}, RH = {-40,0,0}, LUA = {20,0,-25}, LLA = {60,0,0}, LH = {-40,0,0} }
local function with(base, extra) local t = table.clone(base) for k, v in pairs(extra) do t[k] = v end return t end
return {
	Idle = { length = 1.6, loop = true, priority = "Idle", keys = {
		with(LOW, { t = 0.0, e = "linear" }),
		with(LOW, { t = 0.8, e = "sine", UT = {-20,6,0}, LTp = {0,-0.4,0}, HD = {14,-6,0} }),
		with(LOW, { t = 1.6, e = "sine" }),
	}},
	-- Бег «ниндзя»: базовая ходьба, амплитуда ×1.3, быстрее, корпус вперёд, руки назад.
	Walk = { inherit = "Base.Walk", amp = 1.3, speed = 1.6,
		override = { UT = {-25,0,0}, RUA = {-45,0,20}, LUA = {-45,0,-20}, RLA = {10,0,0}, LLA = {10,0,0} } },
	Strafe = { inherit = "Base.Strafe", amp = 1.2,
		override = { UT = {-18,0,0}, LTp = {0,-0.3,0}, RUA = {20,0,25}, RLA = {60,0,0}, LUA = {20,0,-25}, LLA = {60,0,0} } },

	Dash_Windup = { length = 0.4, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.4, e = "quadOut", LTp = {0,-0.6,0.2}, UT = {-30,25,0}, HD = {20,-20,0},
			RUL = {55,0,0}, RLL = {-80,0,0}, LUL = {-15,0,0}, LLL = {-40,0,0}, RF = {20,0,0},
			RUA = {-60,0,35}, RLA = {50,0,0}, RH = {-30,0,0}, LUA = {-60,0,-35}, LLA = {50,0,0}, LH = {-30,0,0} },
	}},
	-- Состояние сервера "dash": держим одну позу, ноги чуть дрожат.
	Dash = { length = 0.15, loop = true, priority = "Action", keys = {
		{ t = 0.00, e = "linear", LTp = {0,-0.3,0}, UT = {-45,0,0}, HD = {35,0,0},
			RUL = {40,0,0}, LUL = {-40,0,0}, RLL = {-30,0,0}, LLL = {-60,0,0},
			RUA = {-75,0,30}, LUA = {-75,0,-30}, RLA = {10,0,0}, LLA = {10,0,0} },
		{ t = 0.15, e = "linear", LTp = {0,-0.3,0}, UT = {-45,0,0}, HD = {35,0,0},
			RUL = {40,0,0}, LUL = {-40,0,0}, RLL = {-30,0,0}, LLL = {-60,0,0},
			RUA = {-75,0,30}, LUA = {-75,0,-30}, RLA = {10,0,0}, LLA = {10,0,0} },
	}},
	-- Два взмаха: длина подгоняется под EnemyStateDur состояния "strike".
	Combo_Strike = { length = 0.36, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		{ t = 0.08, e = "snap", UT = {-15,30,0}, RUA = {80,55,0}, RLA = {10,0,0}, RH = {-80,0,0},
			LUA = {-30,0,-30}, LLA = {10,0,0}, LTp = {0,-0.3,0}, RUL = {30,0,0}, RLL = {-40,0,0} },
		{ t = 0.18, e = "linear", UT = {-15,34,0}, RUA = {78,65,0}, RLA = {10,0,0}, RH = {-80,0,0},
			LUA = {40,-60,0}, LLA = {20,0,0}, LH = {-60,0,0}, LTp = {0,-0.3,0}, RUL = {30,0,0}, RLL = {-40,0,0} },
		{ t = 0.26, e = "snap", UT = {-15,-30,0}, RUA = {-20,0,30}, RLA = {20,0,0},
			LUA = {80,-55,0}, LLA = {10,0,0}, LH = {-80,0,0}, LTp = {0,-0.3,0}, LUL = {30,0,0}, LLL = {-40,0,0} },
		{ t = 0.36, e = "linear", UT = {-15,-34,0}, RUA = {-20,0,30}, RLA = {20,0,0},
			LUA = {78,-65,0}, LLA = {10,0,0}, LH = {-80,0,0}, LTp = {0,-0.3,0}, LUL = {30,0,0}, LLL = {-40,0,0} },
	}, markers = { { t = 0.08, name = "Hit" }, { t = 0.26, name = "Hit" } } },
	Combo_Recover = { length = 1.0, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.3, e = "quadOut", LTp = {0,-0.5,0}, UT = {-35,0,0}, HD = {-15,0,0},
			RUA = {-5,0,20}, LUA = {-5,0,-20}, RLA = {20,0,0}, LLA = {20,0,0},
			RUL = {40,0,0}, LUL = {30,0,0}, RLL = {-60,0,0}, LLL = {-50,0,0} },
		with(LOW, { t = 1.0, e = "sine" }),
	}},
}
