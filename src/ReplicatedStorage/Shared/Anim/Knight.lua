--!nonstrict
-- Anim/Knight — Латник (ТЗ врагов, раздел 3.4). Таблица без изменений.
-- Проверка: в Idle сумма правой руки 40 + 100 − 60 = 80 (булава почти
-- вертикально у плеча), в Slam_Windup 170 + 30 − 20 = 180 (за головой).

local GUARD = { LUA = {70,-35,0}, LLA = {75,0,0}, RUA = {40,0,20}, RLA = {100,0,0}, RH = {-60,0,0} }
return {
	Idle = { length = 2.4, loop = true, priority = "Idle", keys = {
		{ t = 0.0, e = "linear", UT = {-3,0,0}, RUL = {0,0,8}, LUL = {0,0,-8},
			LUA = {70,-35,0}, LLA = {75,0,0}, RUA = {40,0,20}, RLA = {100,0,0}, RH = {-60,0,0} },
		{ t = 1.2, e = "sine", UT = {-5,0,0}, LTp = {0,-0.06,0}, RUL = {0,0,8}, LUL = {0,0,-8},
			LUA = {70,-35,0}, LLA = {75,0,0}, RUA = {42,0,20}, RLA = {100,0,0}, RH = {-60,0,0} },
		{ t = 2.4, e = "sine", UT = {-3,0,0}, RUL = {0,0,8}, LUL = {0,0,-8},
			LUA = {70,-35,0}, LLA = {75,0,0}, RUA = {40,0,20}, RLA = {100,0,0}, RH = {-60,0,0} },
	}},
	-- Тяжёлая походка: амплитуда ×0.7, длиннее шаг по времени.
	Walk   = { inherit = "Base.Walk", amp = 0.7, speed = 0.85, override = GUARD },
	Strafe = { inherit = "Base.Strafe", amp = 0.8, override = GUARD },

	Shield_Windup = { length = 0.8, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.8, e = "quadOut", UT = {-6,35,0}, LTp = {0,-0.2,0.15},
			LUA = {40,-10,-25}, LLA = {90,0,0}, RUA = {20,0,30}, RLA = {60,0,0}, RH = {-40,0,0},
			LUL = {20,0,0}, LLL = {-20,0,0}, RUL = {-10,0,0} },
	}},
	Shield_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.1, e = "snap", UT = {-15,-25,0}, LTp = {0,-0.25,-0.5},
			LUA = {85,15,-5}, LLA = {10,0,0}, RUA = {20,0,30}, RLA = {60,0,0}, RH = {-40,0,0},
			RUL = {25,0,0}, RLL = {-30,0,0}, LUL = {-20,0,0} },
		{ t = 0.3, e = "linear", UT = {-15,-25,0}, LTp = {0,-0.25,-0.5},
			LUA = {85,15,-5}, LLA = {10,0,0}, RUA = {20,0,30}, RLA = {60,0,0}, RH = {-40,0,0},
			RUL = {25,0,0}, RLL = {-30,0,0}, LUL = {-20,0,0} },
	}, markers = { { t = 0.1, name = "Hit" } } },
	Shield_Recover = { length = 1.0, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.3, e = "quadOut", UT = {-18,-10,0}, HD = {-8,0,0}, LUA = {30,0,-10}, LLA = {30,0,0},
			RUA = {20,0,20}, RLA = {40,0,0}, RH = {-40,0,0} },
		{ t = 1.0, e = "sine", UT = {-3,0,0}, RUL = {0,0,8}, LUL = {0,0,-8},
			LUA = {70,-35,0}, LLA = {75,0,0}, RUA = {40,0,20}, RLA = {100,0,0}, RH = {-60,0,0} },
	}},

	Slam_Windup = { length = 1.0, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 1.0, e = "quadOut", UT = {12,0,0}, HD = {15,0,0}, LTp = {0,0.1,0},
			RUA = {170,0,-10}, RLA = {30,0,0}, RH = {-20,0,0}, LUA = {170,0,10}, LLA = {30,0,0},
			RUL = {5,0,0}, LUL = {5,0,0}, RF = {-15,0,0}, LF = {-15,0,0} },
	}},
	Slam_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		{ t = 0.12, e = "snap", UT = {-40,0,0}, HD = {-20,0,0}, LTp = {0,-0.7,-0.2},
			RUA = {20,0,0}, RLA = {5,0,0}, RH = {-40,0,0}, LUA = {40,0,0}, LLA = {20,0,0},
			RUL = {60,0,0}, LUL = {60,0,0}, RLL = {-90,0,0}, LLL = {-90,0,0} },
		{ t = 0.30, e = "linear", UT = {-40,0,0}, HD = {-20,0,0}, LTp = {0,-0.7,-0.2},
			RUA = {20,0,0}, RLA = {5,0,0}, RH = {-40,0,0}, LUA = {40,0,0}, LLA = {20,0,0},
			RUL = {60,0,0}, LUL = {60,0,0}, RLL = {-90,0,0}, LLL = {-90,0,0} },
	}, markers = { { t = 0.12, name = "Hit" } } },
	Slam_Recover = { length = 1.5, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.5, e = "linear", UT = {-35,0,0}, HD = {-15,0,0}, LTp = {0,-0.6,-0.1},
			RUA = {25,0,0}, RLA = {10,0,0}, RH = {-40,0,0}, LUA = {40,0,0}, LLA = {25,0,0},
			RUL = {55,0,0}, LUL = {55,0,0}, RLL = {-80,0,0}, LLL = {-80,0,0} },
		{ t = 1.5, e = "quadInOut", UT = {-3,0,0}, RUL = {0,0,8}, LUL = {0,0,-8},
			LUA = {70,-35,0}, LLA = {75,0,0}, RUA = {40,0,20}, RLA = {100,0,0}, RH = {-60,0,0} },
	}},
}
