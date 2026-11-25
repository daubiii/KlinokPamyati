--!nonstrict
-- Anim/Guard — Ржавый страж (ТЗ врагов, раздел 3.4). Таблица без изменений.
-- Проверка по клинку: в конце замаха 155 + 45 − 20 = 180 (меч за спиной),
-- в кадре удара 35 + 10 − 45 = 0 (меч горизонтально вперёд).

local READY = { RUA = {25,0,8}, RLA = {35,0,0}, RH = {-55,0,0}, LUA = {30,-20,-6}, LLA = {70,0,0} }
return {
	Idle = { length = 2.0, loop = true, priority = "Idle", keys = {
		{ t = 0.0, e = "linear", UT = {-4,0,0}, RUA = {25,0,8}, RLA = {35,0,0}, RH = {-55,0,0},
			LUA = {30,-20,-6}, LLA = {70,0,0}, RUL = {8,0,0}, RLL = {-8,0,0}, LUL = {-6,0,0}, LLL = {-6,0,0} },
		{ t = 1.0, e = "sine", UT = {-6,0,0}, LTp = {0,-0.05,0}, RUA = {27,0,8}, RLA = {35,0,0}, RH = {-55,0,0},
			LUA = {30,-20,-6}, LLA = {70,0,0}, RUL = {8,0,0}, RLL = {-8,0,0}, LUL = {-6,0,0}, LLL = {-6,0,0} },
		{ t = 2.0, e = "sine", UT = {-4,0,0}, RUA = {25,0,8}, RLA = {35,0,0}, RH = {-55,0,0},
			LUA = {30,-20,-6}, LLA = {70,0,0}, RUL = {8,0,0}, RLL = {-8,0,0}, LUL = {-6,0,0}, LLL = {-6,0,0} },
	}},
	Walk   = { inherit = "Base.Walk",   override = READY },
	Strafe = { inherit = "Base.Strafe", override = READY },

	Slash_Windup = { length = 0.6, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.6, e = "quadOut", UT = {-6,-25,0}, HD = {0,20,0},
			RUA = {155,0,25}, RLA = {45,0,0}, RH = {-20,0,0}, LUA = {50,-30,-10}, LLA = {60,0,0},
			RUL = {18,0,0}, RLL = {-15,0,0}, LUL = {-12,0,0}, LLL = {-8,0,0}, LTp = {0,-0.15,0.1} },
	}},
	Slash_Strike = { length = 0.25, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		{ t = 0.10, e = "snap", UT = {-14,20,0}, HD = {-6,-10,0},
			RUA = {35,0,-15}, RLA = {10,0,0}, RH = {-45,0,0}, LUA = {-10,0,-15}, LLA = {30,0,0},
			RUL = {-20,0,0}, RLL = {-30,0,0}, LUL = {25,0,0}, LLL = {-10,0,0}, LTp = {0,-0.25,-0.3} },
		{ t = 0.25, e = "linear", UT = {-16,24,0}, HD = {-6,-10,0},
			RUA = {28,0,-20}, RLA = {10,0,0}, RH = {-45,0,0}, LUA = {-10,0,-15}, LLA = {30,0,0},
			RUL = {-20,0,0}, RLL = {-30,0,0}, LUL = {25,0,0}, LLL = {-10,0,0}, LTp = {0,-0.25,-0.3} },
	}, markers = { { t = 0.10, name = "Hit" } } },
	Slash_Recover = { length = 0.8, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		{ t = 0.25, e = "quadOut", UT = {-22,10,0}, HD = {-10,0,0}, LTp = {0,-0.2,0},
			RUA = {10,0,5}, RLA = {15,0,0}, RH = {-20,0,0}, LUA = {0,0,-10}, LLA = {20,0,0} },
		{ t = 0.80, e = "sine", UT = {-4,0,0}, RUA = {25,0,8}, RLA = {35,0,0}, RH = {-55,0,0},
			LUA = {30,-20,-6}, LLA = {70,0,0}, RUL = {8,0,0}, RLL = {-8,0,0}, LUL = {-6,0,0}, LLL = {-6,0,0} },
	}},
}
