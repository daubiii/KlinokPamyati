--!nonstrict
-- Anim/Gardener — Садовник (этаж 2). Лейка в правой руке; «Полив» — 3 с канала (strike растягивается), удар лейкой наотмашь.
-- Сгенерировано из f2/anim/sets.py (ClaudeToolkit): правки — там, затем gen.py.

return {
	Idle = { length = 2.4, loop = true, priority = "Idle", keys = {
		{ t = 0, e = "linear", UT = {-10,0,0}, HD = {-6,0,0}, RUA = {12,0,10}, RLA = {38,0,0}, RH = {-20,0,0}, LUA = {10,0,-6}, LLA = {34,0,0}, RUL = {4,0,4}, RLL = {-8,0,0}, LUL = {-2,0,-4}, LLL = {-4,0,0} },
		{ t = 1.2, e = "sine", UT = {-12,0,0}, HD = {-2,6,0}, RUA = {12,0,10}, RLA = {42,0,0}, RH = {-20,0,0}, LUA = {10,0,-6}, LLA = {34,0,0}, RUL = {4,0,4}, RLL = {-8,0,0}, LUL = {-2,0,-4}, LLL = {-4,0,0}, LTp = {0,-0.05,0} },
		{ t = 2.4, e = "sine", UT = {-10,0,0}, HD = {-6,0,0}, RUA = {12,0,10}, RLA = {38,0,0}, RH = {-20,0,0}, LUA = {10,0,-6}, LLA = {34,0,0}, RUL = {4,0,4}, RLL = {-8,0,0}, LUL = {-2,0,-4}, LLL = {-4,0,0} },
	} },
	Walk = { inherit = "Base.Walk", amp = 0.8, override = { UT = {-10,0,0}, RUA = {12,0,10}, RLA = {38,0,0}, RH = {-20,0,0} } },
	Strafe = { inherit = "Base.Strafe", override = { UT = {-10,0,0}, RUA = {12,0,10}, RLA = {38,0,0}, RH = {-20,0,0} } },
	Pour_Windup = { length = 0.8, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.8, e = "quadOut", UT = {4,0,0}, HD = {-12,0,0}, RUA = {78,0,-6}, RLA = {52,0,0}, RH = {-30,0,0}, LUA = {64,0,22}, LLA = {80,0,0}, RUL = {-8,0,0}, LUL = {14,0,0}, LLL = {-10,0,0}, LTp = {0,0.05,0.1} },
	} },
	Pour_Strike = { length = 1, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.08, e = "quadOut", UT = {-14,0,0}, HD = {-20,0,0}, RUA = {84,0,-4}, RLA = {18,0,0}, RH = {40,0,0}, LUA = {58,0,24}, LLA = {70,0,0}, RUL = {18,0,0}, RLL = {-20,0,0}, LUL = {-10,0,0}, LLL = {-8,0,0}, LTp = {0,-0.1,-0.1} },
		{ t = 0.3, e = "sine", UT = {-14,14,0}, HD = {-20,0,0}, RUA = {84,12,-4}, RLA = {18,0,0}, RH = {40,0,0}, LUA = {58,0,24}, LLA = {70,0,0}, RUL = {18,0,0}, RLL = {-20,0,0}, LUL = {-10,0,0}, LLL = {-8,0,0}, LTp = {0,-0.1,-0.1} },
		{ t = 0.55, e = "sine", UT = {-14,-14,0}, HD = {-20,0,0}, RUA = {84,-12,-4}, RLA = {18,0,0}, RH = {40,0,0}, LUA = {58,0,24}, LLA = {70,0,0}, RUL = {18,0,0}, RLL = {-20,0,0}, LUL = {-10,0,0}, LLL = {-8,0,0}, LTp = {0,-0.1,-0.1} },
		{ t = 0.8, e = "sine", UT = {-14,10,0}, HD = {-20,0,0}, RUA = {84,8,-4}, RLA = {18,0,0}, RH = {40,0,0}, LUA = {58,0,24}, LLA = {70,0,0}, RUL = {18,0,0}, RLL = {-20,0,0}, LUL = {-10,0,0}, LLL = {-8,0,0}, LTp = {0,-0.1,-0.1} },
		{ t = 1, e = "sine", UT = {-14,0,0}, HD = {-20,0,0}, RUA = {84,0,-4}, RLA = {18,0,0}, RH = {40,0,0}, LUA = {58,0,24}, LLA = {70,0,0}, RUL = {18,0,0}, RLL = {-20,0,0}, LUL = {-10,0,0}, LLL = {-8,0,0}, LTp = {0,-0.1,-0.1} },
	} },
	Pour_Recover = { length = 0.9, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.9, e = "sine", UT = {-10,0,0}, HD = {-6,0,0}, RUA = {12,0,10}, RLA = {38,0,0}, RH = {-20,0,0}, LUA = {10,0,-6}, LLA = {34,0,0}, RUL = {4,0,4}, RLL = {-8,0,0}, LUL = {-2,0,-4}, LLL = {-4,0,0} },
	} },
	Bash_Windup = { length = 0.6, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.6, e = "quadOut", LT = {0,28,0}, UT = {4,30,0}, HD = {0,-40,0}, RUA = {-30,0,45}, RLA = {40,0,0}, RH = {-10,0,0}, LUA = {50,0,-20}, LLA = {60,0,0}, RUL = {-10,0,0}, LUL = {18,0,0}, LTp = {0,-0.1,0.1} },
	} },
	Bash_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.09, e = "snap", LT = {0,-26,0}, UT = {-22,-30,0}, HD = {-8,36,0}, RUA = {85,-50,-20}, RLA = {15,0,0}, RH = {-20,0,0}, LUA = {-10,0,-30}, LLA = {30,0,0}, RUL = {30,0,0}, RLL = {-30,0,0}, LUL = {-18,0,0}, LTp = {0,-0.25,-0.35} },
		{ t = 0.3, e = "linear", LT = {0,-26,0}, UT = {-22,-30,0}, HD = {-8,36,0}, RUA = {85,-50,-20}, RLA = {15,0,0}, RH = {-20,0,0}, LUA = {-10,0,-30}, LLA = {30,0,0}, RUL = {30,0,0}, RLL = {-30,0,0}, LUL = {-18,0,0}, LTp = {0,-0.25,-0.35} },
	}, markers = { { t = 0.09, name = "Hit" } } },
	Bash_Recover = { length = 0.8, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.3, e = "linear", LT = {0,-26,0}, UT = {-18,-24,0}, HD = {-8,36,0}, RUA = {85,-50,-20}, RLA = {15,0,0}, RH = {-20,0,0}, LUA = {-10,0,-30}, LLA = {30,0,0}, RUL = {30,0,0}, RLL = {-30,0,0}, LUL = {-18,0,0}, LTp = {0,-0.25,-0.35} },
		{ t = 0.8, e = "sine", UT = {-10,0,0}, HD = {-6,0,0}, RUA = {12,0,10}, RLA = {38,0,0}, RH = {-20,0,0}, LUA = {10,0,-6}, LLA = {34,0,0}, RUL = {4,0,4}, RLL = {-8,0,0}, LUL = {-2,0,-4}, LLL = {-4,0,0} },
	} },
}
