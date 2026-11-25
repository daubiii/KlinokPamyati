--!nonstrict
-- Anim/Rosewarden — Садовница — ожившая статуя (босс этажа 2). Появление: статуя оживает; фазы: трещины мрамора.
-- Сгенерировано из f2/anim/sets.py (ClaudeToolkit): правки — там, затем gen.py.

return {
	Idle = { length = 3.2, loop = true, priority = "Idle", keys = {
		{ t = 0, e = "linear", UT = {-3,0,0}, HD = {-6,0,0}, RUA = {12,0,12}, RLA = {24,0,0}, RH = {-10,0,0}, LUA = {12,0,-12}, LLA = {24,0,0}, LH = {-10,0,0}, RUL = {2,0,3}, LUL = {-2,0,-3} },
		{ t = 1.6, e = "sine", UT = {-5,0,0}, HD = {-3,4,0}, RUA = {14,0,14}, RLA = {24,0,0}, RH = {-10,0,0}, LUA = {14,0,-14}, LLA = {24,0,0}, LH = {-10,0,0}, RUL = {2,0,3}, LUL = {-2,0,-3}, LTp = {0,-0.08,0} },
		{ t = 3.2, e = "sine", UT = {-3,0,0}, HD = {-6,0,0}, RUA = {12,0,12}, RLA = {24,0,0}, RH = {-10,0,0}, LUA = {12,0,-12}, LLA = {24,0,0}, LH = {-10,0,0}, RUL = {2,0,3}, LUL = {-2,0,-3} },
	} },
	Walk = { inherit = "Base.Walk", amp = 0.6, speed = 0.75, override = { UT = {-4,0,0}, RLA = {20,0,0}, LLA = {20,0,0} } },
	Strafe = { inherit = "Base.Strafe", amp = 0.7, speed = 0.8 },
	Intro = { length = 3, loop = false, priority = "Action4", keys = {
		{ t = 0, e = "linear", UT = {-4,0,0}, HD = {-18,0,0}, RUA = {55,0,-28}, RLA = {105,0,0}, RH = {-10,0,0}, LUA = {55,0,28}, LLA = {105,0,0}, LH = {-10,0,0} },
		{ t = 1.2, e = "linear", UT = {-4,0,0}, HD = {-18,0,0}, RUA = {55,0,-28}, RLA = {105,0,0}, RH = {-10,0,0}, LUA = {55,0,28}, LLA = {105,0,0}, LH = {-10,0,0} },
		{ t = 1.35, e = "snap", UT = {-6,4,0}, HD = {-16,6,0}, RUA = {55,0,-28}, RLA = {105,0,0}, RH = {-10,0,0}, LUA = {55,0,28}, LLA = {105,0,0}, LH = {-10,0,0} },
		{ t = 1.6, e = "linear", UT = {-4,-3,0}, HD = {-17,-4,0}, RUA = {55,0,-28}, RLA = {105,0,0}, RH = {-10,0,0}, LUA = {55,0,28}, LLA = {105,0,0}, LH = {-10,0,0} },
		{ t = 2.3, e = "quadInOut", UT = {18,0,0}, HD = {28,0,0}, RUA = {60,0,70}, RLA = {30,0,0}, RH = {-30,0,0}, LUA = {60,0,-70}, LLA = {30,0,0}, LH = {-30,0,0}, RUL = {10,0,12}, LUL = {10,0,-12}, LTp = {0,-0.2,0} },
		{ t = 3, e = "sine", UT = {-3,0,0}, HD = {-6,0,0}, RUA = {12,0,12}, RLA = {24,0,0}, RH = {-10,0,0}, LUA = {12,0,-12}, LLA = {24,0,0}, LH = {-10,0,0}, RUL = {2,0,3}, LUL = {-2,0,-3} },
	}, markers = { { t = 1.35, name = "EyesOn" }, { t = 2.2, name = "Roar" } } },
	Lash_Windup = { length = 0.8, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.8, e = "quadOut", LT = {0,30,0}, UT = {4,34,0}, HD = {0,-44,0}, RUA = {95,-10,75}, RLA = {30,0,0}, RH = {-20,0,0}, LUA = {40,30,-20}, LLA = {50,0,0}, RUL = {-12,0,0}, RLL = {-10,0,0}, LUL = {18,0,0}, LTp = {0,-0.2,0.2} },
	} },
	Lash_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.08, e = "snap", LT = {0,-30,0}, UT = {-18,-32,0}, HD = {-4,40,0}, RUA = {92,-40,-10}, RLA = {6,0,0}, RH = {-10,0,0}, LUA = {10,0,-40}, LLA = {30,0,0}, RUL = {34,0,0}, RLL = {-36,0,0}, LUL = {-20,0,0}, LTp = {0,-0.45,-0.5} },
		{ t = 0.3, e = "linear", LT = {0,-30,0}, UT = {-18,-32,0}, HD = {-4,40,0}, RUA = {92,-40,-10}, RLA = {6,0,0}, RH = {-10,0,0}, LUA = {10,0,-40}, LLA = {30,0,0}, RUL = {34,0,0}, RLL = {-36,0,0}, LUL = {-20,0,0}, LTp = {0,-0.45,-0.5} },
	}, markers = { { t = 0.08, name = "Hit" } } },
	Lash_Recover = { length = 1.3, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.45, e = "linear", LT = {0,-30,0}, UT = {-14,-28,0}, HD = {-4,40,0}, RUA = {92,-40,-10}, RLA = {6,0,0}, RH = {-10,0,0}, LUA = {10,0,-40}, LLA = {30,0,0}, RUL = {34,0,0}, RLL = {-36,0,0}, LUL = {-20,0,0}, LTp = {0,-0.45,-0.5} },
		{ t = 1.3, e = "sine", UT = {-3,0,0}, HD = {-6,0,0}, RUA = {12,0,12}, RLA = {24,0,0}, RH = {-10,0,0}, LUA = {12,0,-12}, LLA = {24,0,0}, LH = {-10,0,0}, RUL = {2,0,3}, LUL = {-2,0,-3} },
	} },
	ThornRing_Windup = { length = 1, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 1, e = "quadOut", UT = {16,0,0}, HD = {24,0,0}, RUA = {170,0,28}, RLA = {15,0,0}, RH = {-10,0,0}, LUA = {170,0,-28}, LLA = {15,0,0}, LH = {-10,0,0}, RF = {-14,0,0}, LF = {-14,0,0}, LTp = {0,0.2,0} },
	} },
	ThornRing_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.1, e = "snap", UT = {-26,0,0}, HD = {-14,0,0}, RUA = {20,0,70}, RLA = {10,0,0}, RH = {-50,0,0}, LUA = {20,0,-70}, LLA = {10,0,0}, LH = {-50,0,0}, RUL = {55,0,14}, RLL = {-80,0,0}, RF = {25,0,0}, LUL = {55,0,-14}, LLL = {-80,0,0}, LF = {25,0,0}, LTp = {0,-1,0} },
		{ t = 0.3, e = "linear", UT = {-26,0,0}, HD = {-14,0,0}, RUA = {20,0,70}, RLA = {10,0,0}, RH = {-50,0,0}, LUA = {20,0,-70}, LLA = {10,0,0}, LH = {-50,0,0}, RUL = {55,0,14}, RLL = {-80,0,0}, RF = {25,0,0}, LUL = {55,0,-14}, LLL = {-80,0,0}, LF = {25,0,0}, LTp = {0,-1,0} },
	}, markers = { { t = 0.1, name = "Hit" } } },
	ThornRing_Recover = { length = 1.4, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.5, e = "linear", UT = {-26,0,0}, HD = {-14,0,0}, RUA = {20,0,70}, RLA = {10,0,0}, RH = {-50,0,0}, LUA = {20,0,-70}, LLA = {10,0,0}, LH = {-50,0,0}, RUL = {55,0,14}, RLL = {-80,0,0}, RF = {25,0,0}, LUL = {55,0,-14}, LLL = {-80,0,0}, LF = {25,0,0}, LTp = {0,-1,0} },
		{ t = 1.4, e = "sine", UT = {-3,0,0}, HD = {-6,0,0}, RUA = {12,0,12}, RLA = {24,0,0}, RH = {-10,0,0}, LUA = {12,0,-12}, LLA = {24,0,0}, LH = {-10,0,0}, RUL = {2,0,3}, LUL = {-2,0,-3} },
	} },
	Volley_Windup = { length = 0.9, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.35, e = "quadOut", LT = {0,-35,0}, UT = {-4,-14,0}, HD = {0,46,0}, RUA = {70,40,25}, RLA = {115,0,0}, RH = {-40,0,0}, LUA = {80,70,-10}, LLA = {10,0,0}, RUL = {0,0,10}, LUL = {0,0,-10}, LTp = {0,-0.15,0.1} },
		{ t = 0.9, e = "quadOut", LT = {0,-35,0}, UT = {-4,-14,0}, HD = {0,46,0}, RUA = {92,46,0}, RLA = {6,0,0}, RH = {-70,0,0}, LUA = {30,20,-40}, LLA = {40,0,0}, RUL = {0,0,10}, LUL = {0,0,-10}, LTp = {0,-0.15,0.1} },
	}, markers = { { t = 0.4, name = "AimLine" } } },
	Volley_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.05, e = "snap", LT = {0,-35,0}, UT = {-12,-4,0}, HD = {0,46,0}, RUA = {96,64,-10}, RLA = {6,0,0}, RH = {-85,0,0}, LUA = {30,20,-40}, LLA = {40,0,0}, RUL = {0,0,10}, LUL = {0,0,-10}, LTp = {0,-0.2,-0.15} },
		{ t = 0.3, e = "quadOut", LT = {0,-35,0}, UT = {-12,-4,0}, HD = {0,46,0}, RUA = {96,64,-10}, RLA = {30,0,0}, RH = {-85,0,0}, LUA = {30,20,-40}, LLA = {40,0,0}, RUL = {0,0,10}, LUL = {0,0,-10}, LTp = {0,-0.2,-0.15} },
	}, markers = { { t = 0, name = "Release" } } },
	Volley_Recover = { length = 0.8, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.8, e = "sine", UT = {-3,0,0}, HD = {-6,0,0}, RUA = {12,0,12}, RLA = {24,0,0}, RH = {-10,0,0}, LUA = {12,0,-12}, LLA = {24,0,0}, LH = {-10,0,0}, RUL = {2,0,3}, LUL = {-2,0,-3} },
	} },
	Lines_Windup = { length = 1.1, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.5, e = "quadOut", UT = {12,0,0}, HD = {14,0,0}, RUA = {150,0,20}, RLA = {40,0,0}, RH = {-30,0,0}, LUA = {150,0,-20}, LLA = {40,0,0}, LH = {-30,0,0}, LTp = {0,0.1,0} },
		{ t = 1.1, e = "quadIn", UT = {-30,0,0}, HD = {-12,0,0}, RUA = {70,0,12}, RLA = {14,0,0}, RH = {-60,0,0}, LUA = {70,0,-12}, LLA = {14,0,0}, LH = {-60,0,0}, RUL = {90,0,6}, RLL = {-95,0,0}, RF = {5,0,0}, LUL = {5,0,-6}, LLL = {-90,0,0}, LF = {60,0,0}, LTp = {0,-1.4,-0.2} },
	} },
	Lines_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.08, e = "snap", UT = {-48,0,0}, HD = {-12,0,0}, RUA = {40,0,12}, RLA = {14,0,0}, RH = {-60,0,0}, LUA = {40,0,-12}, LLA = {14,0,0}, LH = {-60,0,0}, RUL = {90,0,6}, RLL = {-95,0,0}, RF = {5,0,0}, LUL = {5,0,-6}, LLL = {-90,0,0}, LF = {60,0,0}, LTp = {0,-1.9,-0.3} },
		{ t = 0.3, e = "linear", UT = {-48,0,0}, HD = {-12,0,0}, RUA = {40,0,12}, RLA = {14,0,0}, RH = {-60,0,0}, LUA = {40,0,-12}, LLA = {14,0,0}, LH = {-60,0,0}, RUL = {90,0,6}, RLL = {-95,0,0}, RF = {5,0,0}, LUL = {5,0,-6}, LLL = {-90,0,0}, LF = {60,0,0}, LTp = {0,-1.9,-0.3} },
	}, markers = { { t = 0.08, name = "Hit" } } },
	Lines_Recover = { length = 1.2, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.5, e = "linear", UT = {-48,0,0}, HD = {-12,0,0}, RUA = {40,0,12}, RLA = {14,0,0}, RH = {-60,0,0}, LUA = {40,0,-12}, LLA = {14,0,0}, LH = {-60,0,0}, RUL = {90,0,6}, RLL = {-95,0,0}, RF = {5,0,0}, LUL = {5,0,-6}, LLL = {-90,0,0}, LF = {60,0,0}, LTp = {0,-1.9,-0.3} },
		{ t = 1.2, e = "sine", UT = {-3,0,0}, HD = {-6,0,0}, RUA = {12,0,12}, RLA = {24,0,0}, RH = {-10,0,0}, LUA = {12,0,-12}, LLA = {24,0,0}, LH = {-10,0,0}, RUL = {2,0,3}, LUL = {-2,0,-3} },
	} },
	Ram_Windup = { length = 1.2, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.6, e = "quadOut", LT = {0,-18,0}, UT = {-34,12,0}, HD = {20,-10,0}, RUA = {-30,0,20}, RLA = {40,0,0}, LUA = {60,0,-10}, LLA = {80,0,0}, RUL = {40,0,6}, RLL = {-60,0,0}, RF = {20,0,0}, LUL = {-30,0,-6}, LLL = {-30,0,0}, LTp = {0,-0.7,0.2} },
		{ t = 1.2, e = "linear", LT = {0,-18,0}, UT = {-34,12,0}, HD = {20,-10,0}, RUA = {-30,0,20}, RLA = {40,0,0}, LUA = {60,0,-10}, LLA = {80,0,0}, RUL = {40,0,6}, RLL = {-60,0,0}, RF = {20,0,0}, LUL = {-30,0,-6}, LLL = {-30,0,0}, LTp = {0,-0.8,0.3} },
	}, markers = { { t = 1, name = "Scrape" } } },
	Ram = { length = 0.5, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.12, e = "quadOut", LT = {0,-12,0}, UT = {-38,10,0}, HD = {26,-8,0}, RUA = {-40,0,20}, RLA = {50,0,0}, LUA = {70,0,-10}, LLA = {80,0,0}, RUL = {55,0,0}, RLL = {-30,0,0}, LUL = {-35,0,0}, LLL = {-60,0,0}, LTp = {0,-0.4,0} },
		{ t = 0.25, e = "linear", LT = {0,-12,0}, UT = {-38,10,0}, HD = {26,-8,0}, RUA = {-40,0,20}, RLA = {50,0,0}, LUA = {70,0,-10}, LLA = {80,0,0}, RUL = {-35,0,0}, RLL = {-60,0,0}, LUL = {55,0,0}, LLL = {-30,0,0}, LTp = {0,-0.2,0} },
		{ t = 0.38, e = "linear", LT = {0,-12,0}, UT = {-38,10,0}, HD = {26,-8,0}, RUA = {-40,0,20}, RLA = {50,0,0}, LUA = {70,0,-10}, LLA = {80,0,0}, RUL = {55,0,0}, RLL = {-30,0,0}, LUL = {-35,0,0}, LLL = {-60,0,0}, LTp = {0,-0.4,0} },
		{ t = 0.5, e = "linear", LT = {0,-12,0}, UT = {-38,10,0}, HD = {26,-8,0}, RUA = {-40,0,20}, RLA = {50,0,0}, LUA = {70,0,-10}, LLA = {80,0,0}, RUL = {-35,0,0}, RLL = {-60,0,0}, LUL = {55,0,0}, LLL = {-30,0,0}, LTp = {0,-0.2,0} },
	}, markers = { { t = 0.12, name = "Step" }, { t = 0.25, name = "Step" }, { t = 0.38, name = "Step" }, { t = 0.5, name = "Step" } } },
	Ram_Recover = { length = 1.4, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.4, e = "quadOut", LT = {0,-18,0}, UT = {-24,0,0}, HD = {20,-10,0}, RUA = {-30,0,20}, RLA = {40,0,0}, LUA = {60,0,-10}, LLA = {80,0,0}, RUL = {40,0,6}, RLL = {-60,0,0}, RF = {20,0,0}, LUL = {-30,0,-6}, LLL = {-30,0,0}, LTp = {0,-0.5,0} },
		{ t = 1.4, e = "sine", UT = {-3,0,0}, HD = {-6,0,0}, RUA = {12,0,12}, RLA = {24,0,0}, RH = {-10,0,0}, LUA = {12,0,-12}, LLA = {24,0,0}, LH = {-10,0,0}, RUL = {2,0,3}, LUL = {-2,0,-3} },
	} },
	Phase = { length = 1.8, loop = false, priority = "Action4", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.35, e = "quadOut", UT = {-34,0,0}, HD = {-30,0,0}, RUA = {40,0,-30}, RLA = {110,0,0}, RH = {-20,0,0}, LUA = {40,0,30}, LLA = {110,0,0}, LH = {-20,0,0}, RUL = {70,0,8}, RLL = {-90,0,0}, LUL = {40,0,-8}, LLL = {-80,0,0}, LTp = {0,-1.2,0} },
		{ t = 0.55, e = "linear", UT = {-36,0,4}, HD = {-30,0,0}, RUA = {40,0,-30}, RLA = {110,0,0}, RH = {-20,0,0}, LUA = {40,0,30}, LLA = {110,0,0}, LH = {-20,0,0}, RUL = {70,0,8}, RLL = {-90,0,0}, LUL = {40,0,-8}, LLL = {-80,0,0}, LTp = {0,-1.25,0} },
		{ t = 0.75, e = "linear", UT = {-33,0,-4}, HD = {-30,0,0}, RUA = {40,0,-30}, RLA = {110,0,0}, RH = {-20,0,0}, LUA = {40,0,30}, LLA = {110,0,0}, LH = {-20,0,0}, RUL = {70,0,8}, RLL = {-90,0,0}, LUL = {40,0,-8}, LLL = {-80,0,0}, LTp = {0,-1.2,0} },
		{ t = 1.3, e = "backOut", UT = {18,0,0}, HD = {28,0,0}, RUA = {60,0,70}, RLA = {30,0,0}, RH = {-30,0,0}, LUA = {60,0,-70}, LLA = {30,0,0}, LH = {-30,0,0}, RUL = {10,0,12}, LUL = {10,0,-12}, LTp = {0,-0.2,0} },
		{ t = 1.8, e = "linear", UT = {18,0,0}, HD = {28,0,0}, RUA = {60,0,70}, RLA = {30,0,0}, RH = {-30,0,0}, LUA = {60,0,-70}, LLA = {30,0,0}, LH = {-30,0,0}, RUL = {10,0,12}, LUL = {10,0,-12}, LTp = {0,-0.2,0} },
	}, markers = { { t = 0.6, name = "Crack" }, { t = 1.3, name = "Roar" } } },
	WallHit = { length = 0.35, loop = false, priority = "Action2", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.1, e = "snap", UT = {28,0,0}, HD = {32,0,0}, RUA = {-30,0,40}, LUA = {-30,0,-40}, RUL = {-20,0,0}, LUL = {10,0,0}, LTp = {0,-0.3,0.8} },
		{ t = 0.35, e = "quadOut", UT = {12,0,0}, HD = {10,0,0}, LTp = {0,-0.4,0.5} },
	} },
}
