--!nonstrict
-- Anim/Drowned — Утопленник (этаж 2). Сутулый, руки висят; удар сцепленными руками сверху, бросок тины правой.
-- Сгенерировано из f2/anim/sets.py (ClaudeToolkit): правки — там, затем gen.py.

return {
	Idle = { length = 2.6, loop = true, priority = "Idle", keys = {
		{ t = 0, e = "linear", LT = {0,0,2}, UT = {-16,0,0}, HD = {-12,0,4}, RUA = {18,0,6}, RLA = {22,0,0}, LUA = {14,0,-4}, LLA = {26,0,0}, RUL = {6,0,4}, RLL = {-10,0,0}, LUL = {-2,0,-4}, LLL = {-6,0,0} },
		{ t = 1.3, e = "sine", LT = {0,0,-2}, UT = {-19,0,-2}, HD = {-16,0,-4}, RUA = {22,0,4}, RLA = {22,0,0}, LUA = {18,0,-6}, LLA = {26,0,0}, RUL = {6,0,4}, RLL = {-10,0,0}, LUL = {-2,0,-4}, LLL = {-6,0,0}, LTp = {0,-0.08,0} },
		{ t = 2.6, e = "sine", LT = {0,0,2}, UT = {-16,0,0}, HD = {-12,0,4}, RUA = {18,0,6}, RLA = {22,0,0}, LUA = {14,0,-4}, LLA = {26,0,0}, RUL = {6,0,4}, RLL = {-10,0,0}, LUL = {-2,0,-4}, LLL = {-6,0,0} },
	} },
	Walk = { inherit = "Base.Walk", amp = 0.65, speed = 0.8, override = { UT = {-16,0,0}, HD = {-10,0,0}, RUA = {30,0,6}, RLA = {24,0,0}, LUA = {24,0,-6}, LLA = {30,0,0} } },
	Strafe = { inherit = "Base.Strafe", amp = 0.75, override = { UT = {-16,0,0}, HD = {-10,0,0}, RUA = {30,0,6}, RLA = {24,0,0}, LUA = {24,0,-6}, LLA = {30,0,0} } },
	Pound_Windup = { length = 0.85, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.85, e = "quadOut", UT = {14,0,0}, HD = {10,0,0}, RUA = {168,0,-18}, RLA = {25,0,0}, RH = {-20,0,0}, LUA = {168,0,18}, LLA = {25,0,0}, LH = {-20,0,0}, RUL = {8,0,0}, RF = {-12,0,0}, LUL = {-10,0,0}, LF = {-12,0,0}, LTp = {0,0.15,0.1} },
	} },
	Pound_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.1, e = "snap", UT = {-42,0,0}, HD = {-18,0,0}, RUA = {48,0,-14}, RLA = {10,0,0}, RH = {-40,0,0}, LUA = {48,0,14}, LLA = {10,0,0}, LH = {-40,0,0}, RUL = {45,0,0}, RLL = {-55,0,0}, LUL = {-10,0,0}, LLL = {-20,0,0}, LTp = {0,-0.55,-0.35} },
		{ t = 0.3, e = "linear", UT = {-42,0,0}, HD = {-18,0,0}, RUA = {48,0,-14}, RLA = {10,0,0}, RH = {-40,0,0}, LUA = {48,0,14}, LLA = {10,0,0}, LH = {-40,0,0}, RUL = {45,0,0}, RLL = {-55,0,0}, LUL = {-10,0,0}, LLL = {-20,0,0}, LTp = {0,-0.55,-0.35} },
	}, markers = { { t = 0.1, name = "Hit" } } },
	Pound_Recover = { length = 1, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.35, e = "linear", UT = {-36,0,0}, HD = {-18,0,0}, RUA = {48,0,-14}, RLA = {10,0,0}, RH = {-40,0,0}, LUA = {48,0,14}, LLA = {10,0,0}, LH = {-40,0,0}, RUL = {45,0,0}, RLL = {-55,0,0}, LUL = {-10,0,0}, LLL = {-20,0,0}, LTp = {0,-0.55,-0.35} },
		{ t = 1, e = "sine", LT = {0,0,2}, UT = {-16,0,0}, HD = {-12,0,4}, RUA = {18,0,6}, RLA = {22,0,0}, LUA = {14,0,-4}, LLA = {26,0,0}, RUL = {6,0,4}, RLL = {-10,0,0}, LUL = {-2,0,-4}, LLL = {-6,0,0} },
	} },
	MudThrow_Windup = { length = 0.9, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.35, e = "quadOut", LT = {0,28,0}, UT = {-30,10,0}, HD = {-20,-10,0}, RUA = {10,0,20}, RLA = {40,0,0}, RH = {-30,0,0}, LUA = {70,-20,-10}, LLA = {20,0,0}, RUL = {-12,0,0}, RLL = {-14,0,0}, LUL = {22,0,0}, LLL = {-18,0,0}, LTp = {0,-0.15,0.15} },
		{ t = 0.9, e = "quadOut", LT = {0,28,0}, UT = {8,22,0}, HD = {0,-40,0}, RUA = {-55,0,25}, RLA = {70,0,0}, RH = {-30,0,0}, LUA = {70,-20,-10}, LLA = {20,0,0}, RUL = {-12,0,0}, RLL = {-14,0,0}, LUL = {22,0,0}, LLL = {-18,0,0}, LTp = {0,-0.15,0.15} },
	} },
	MudThrow_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.08, e = "snap", LT = {0,-24,0}, UT = {-24,-22,0}, HD = {-6,30,0}, RUA = {105,-10,8}, RLA = {10,0,0}, RH = {-10,0,0}, LUA = {-20,0,-18}, LLA = {30,0,0}, RUL = {-20,0,0}, RLL = {-30,0,0}, LUL = {36,0,0}, LLL = {-10,0,0}, LTp = {0,-0.2,-0.35} },
		{ t = 0.3, e = "linear", LT = {0,-24,0}, UT = {-24,-22,0}, HD = {-6,30,0}, RUA = {105,-10,8}, RLA = {10,0,0}, RH = {-10,0,0}, LUA = {-20,0,-18}, LLA = {30,0,0}, RUL = {-20,0,0}, RLL = {-30,0,0}, LUL = {36,0,0}, LLL = {-10,0,0}, LTp = {0,-0.2,-0.35} },
	}, markers = { { t = 0.06, name = "Hit" } } },
	MudThrow_Recover = { length = 0.8, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.8, e = "sine", LT = {0,0,2}, UT = {-16,0,0}, HD = {-12,0,4}, RUA = {18,0,6}, RLA = {22,0,0}, LUA = {14,0,-4}, LLA = {26,0,0}, RUL = {6,0,4}, RLL = {-10,0,0}, LUL = {-2,0,-4}, LLL = {-6,0,0} },
	} },
}
