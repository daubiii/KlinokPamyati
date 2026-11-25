--!nonstrict
-- Anim/Treant — Древесный страж (этаж 2). Тяжёлый: шаг ×0,75, удар двумя руками сверху, «Корни» — ладони в землю.
-- Сгенерировано из f2/anim/sets.py (ClaudeToolkit): правки — там, затем gen.py.

return {
	Idle = { length = 3, loop = true, priority = "Idle", keys = {
		{ t = 0, e = "linear", UT = {-6,0,0}, HD = {-4,0,0}, RUA = {8,0,10}, RLA = {18,0,0}, LUA = {8,0,-10}, LLA = {18,0,0}, RUL = {4,0,6}, RLL = {-6,0,0}, LUL = {4,0,-6}, LLL = {-6,0,0} },
		{ t = 1.5, e = "sine", UT = {-9,0,2}, HD = {-2,0,0}, RUA = {10,0,12}, RLA = {18,0,0}, LUA = {10,0,-12}, LLA = {18,0,0}, RUL = {4,0,6}, RLL = {-6,0,0}, LUL = {4,0,-6}, LLL = {-6,0,0}, LTp = {0,-0.06,0} },
		{ t = 3, e = "sine", UT = {-6,0,0}, HD = {-4,0,0}, RUA = {8,0,10}, RLA = {18,0,0}, LUA = {8,0,-10}, LLA = {18,0,0}, RUL = {4,0,6}, RLL = {-6,0,0}, LUL = {4,0,-6}, LLL = {-6,0,0} },
	} },
	Walk = { inherit = "Base.Walk", amp = 0.75, speed = 0.85, override = { UT = {-8,0,0}, HD = {-4,0,0} } },
	Strafe = { inherit = "Base.Strafe", amp = 0.8, override = { UT = {-8,0,0} } },
	Smash_Windup = { length = 0.9, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.9, e = "quadOut", UT = {14,0,0}, HD = {12,0,0}, RUA = {165,0,-14}, RLA = {35,0,0}, RH = {-20,0,0}, LUA = {165,0,14}, LLA = {35,0,0}, LH = {-20,0,0}, RUL = {12,0,0}, RLL = {-10,0,0}, LUL = {-14,0,0}, LLL = {-6,0,0}, LTp = {0,0.05,0.15} },
	} },
	Smash_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.1, e = "snap", UT = {-38,0,0}, HD = {-14,0,0}, RUA = {55,0,-6}, RLA = {8,0,0}, RH = {-30,0,0}, LUA = {55,0,6}, LLA = {8,0,0}, LH = {-30,0,0}, RUL = {48,0,0}, RLL = {-62,0,0}, RF = {14,0,0}, LUL = {-16,0,0}, LLL = {-18,0,0}, LTp = {0,-0.55,-0.45} },
		{ t = 0.3, e = "linear", UT = {-38,0,0}, HD = {-14,0,0}, RUA = {55,0,-6}, RLA = {8,0,0}, RH = {-30,0,0}, LUA = {55,0,6}, LLA = {8,0,0}, LH = {-30,0,0}, RUL = {48,0,0}, RLL = {-62,0,0}, RF = {14,0,0}, LUL = {-16,0,0}, LLL = {-18,0,0}, LTp = {0,-0.55,-0.45} },
	}, markers = { { t = 0.1, name = "Hit" } } },
	Smash_Recover = { length = 1.1, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.4, e = "linear", UT = {-30,0,0}, HD = {-14,0,0}, RUA = {55,0,-6}, RLA = {8,0,0}, RH = {-30,0,0}, LUA = {55,0,6}, LLA = {8,0,0}, LH = {-30,0,0}, RUL = {48,0,0}, RLL = {-62,0,0}, RF = {14,0,0}, LUL = {-16,0,0}, LLL = {-18,0,0}, LTp = {0,-0.45,-0.3} },
		{ t = 1.1, e = "sine", UT = {-6,0,0}, HD = {-4,0,0}, RUA = {8,0,10}, RLA = {18,0,0}, LUA = {8,0,-10}, LLA = {18,0,0}, RUL = {4,0,6}, RLL = {-6,0,0}, LUL = {4,0,-6}, LLL = {-6,0,0} },
	} },
	Roots_Windup = { length = 1.1, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.7, e = "quadOut", UT = {10,0,0}, HD = {22,0,0}, RUA = {120,0,48}, RLA = {40,0,0}, RH = {-40,0,0}, LUA = {120,0,-48}, LLA = {40,0,0}, LH = {-40,0,0}, RUL = {0,0,10}, LUL = {0,0,-10}, LTp = {0,0.08,0} },
		{ t = 1.1, e = "linear", UT = {10,0,0}, HD = {26,0,0}, RUA = {128,0,50}, RLA = {40,0,0}, RH = {-40,0,0}, LUA = {128,0,-50}, LLA = {40,0,0}, LH = {-40,0,0}, RUL = {0,0,10}, LUL = {0,0,-10}, LTp = {0,0.08,0} },
	} },
	Roots_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.1, e = "snap", UT = {-52,0,0}, HD = {-20,0,0}, RUA = {62,0,22}, RLA = {10,0,0}, RH = {-50,0,0}, LUA = {62,0,-22}, LLA = {10,0,0}, LH = {-50,0,0}, RUL = {70,0,8}, RLL = {-95,0,0}, RF = {25,0,0}, LUL = {70,0,-8}, LLL = {-95,0,0}, LF = {25,0,0}, LTp = {0,-1,-0.2} },
		{ t = 0.3, e = "linear", UT = {-52,0,0}, HD = {-20,0,0}, RUA = {62,0,22}, RLA = {10,0,0}, RH = {-50,0,0}, LUA = {62,0,-22}, LLA = {10,0,0}, LH = {-50,0,0}, RUL = {70,0,8}, RLL = {-95,0,0}, RF = {25,0,0}, LUL = {70,0,-8}, LLL = {-95,0,0}, LF = {25,0,0}, LTp = {0,-1,-0.2} },
	}, markers = { { t = 0.1, name = "Hit" } } },
	Roots_Recover = { length = 1, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.35, e = "linear", UT = {-52,0,0}, HD = {-20,0,0}, RUA = {62,0,22}, RLA = {10,0,0}, RH = {-50,0,0}, LUA = {62,0,-22}, LLA = {10,0,0}, LH = {-50,0,0}, RUL = {70,0,8}, RLL = {-95,0,0}, RF = {25,0,0}, LUL = {70,0,-8}, LLL = {-95,0,0}, LF = {25,0,0}, LTp = {0,-1,-0.2} },
		{ t = 1, e = "sine", UT = {-6,0,0}, HD = {-4,0,0}, RUA = {8,0,10}, RLA = {18,0,0}, LUA = {8,0,-10}, LLA = {18,0,0}, RUL = {4,0,6}, RLL = {-6,0,0}, LUL = {4,0,-6}, LLL = {-6,0,0} },
	} },
}
