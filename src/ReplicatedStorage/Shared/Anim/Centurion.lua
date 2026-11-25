--!nonstrict
-- Anim/Centurion — Сотник ворот (мини-босс Барбакана).
-- Ростовой щит в левой руке, боевой клевец в правой; знамя на спине.
-- Позы построены от Латника (Anim/Knight): та же стойка «щит перед собой»,
-- но ниже и шире — щитовая стена. Порядок поворота суставов как у
-- EnemyAnimator: Angles(0,y,0)·Angles(x,0,z).
--
-- Атаки сервера (Config/Enemies.centurion): bash, rush, bannerSweep, pick;
-- рог (phase) — Horn. Маркеры: Hit — удар, Step — шаг, Roar — рёв рога.

local WALL = { LUA = {65,-40,0}, LLA = {80,0,0}, RUA = {35,0,22}, RLA = {95,0,0}, RH = {-55,0,0},
	RUL = {0,0,10}, LUL = {0,0,-10} }

return {
	Idle = { length = 2.6, loop = true, priority = "Idle", keys = {
		{ t = 0.0, e = "linear", UT = {-4,0,0}, LTp = {0,-0.12,0}, RUL = {0,0,10}, LUL = {0,0,-10},
			LUA = {65,-40,0}, LLA = {80,0,0}, RUA = {35,0,22}, RLA = {95,0,0}, RH = {-55,0,0} },
		{ t = 1.3, e = "sine", UT = {-6,0,0}, HD = {2,6,0}, LTp = {0,-0.18,0}, RUL = {0,0,10}, LUL = {0,0,-10},
			LUA = {66,-40,0}, LLA = {80,0,0}, RUA = {37,0,22}, RLA = {95,0,0}, RH = {-55,0,0} },
		{ t = 2.6, e = "sine", UT = {-4,0,0}, LTp = {0,-0.12,0}, RUL = {0,0,10}, LUL = {0,0,-10},
			LUA = {65,-40,0}, LLA = {80,0,0}, RUA = {35,0,22}, RLA = {95,0,0}, RH = {-55,0,0} },
	}},
	-- Медленный шаг за щитом: амплитуда ×0.6, темп ×0.8.
	Walk   = { inherit = "Base.Walk", amp = 0.6, speed = 0.8, override = WALL },
	Strafe = { inherit = "Base.Strafe", amp = 0.7, override = WALL },

	-- Удар щитом (парируемый): щит оттягивается к плечу и бьёт вперёд.
	Bash_Windup = { length = 0.8, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.8, e = "quadOut", UT = {-6,40,0}, LT = {0,10,0}, LTp = {0,-0.25,0.2},
			LUA = {40,-5,-28}, LLA = {95,0,0}, RUA = {20,0,30}, RLA = {60,0,0}, RH = {-40,0,0},
			LUL = {22,0,0}, LLL = {-22,0,0}, RUL = {-12,0,0} },
	}, markers = { { t = 0.45, name = "Step" } } },
	Bash_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.1, e = "snap", UT = {-15,-28,0}, LT = {0,-8,0}, LTp = {0,-0.3,-0.6},
			LUA = {88,15,-5}, LLA = {8,0,0}, RUA = {20,0,30}, RLA = {60,0,0}, RH = {-40,0,0},
			RUL = {28,0,0}, RLL = {-32,0,0}, LUL = {-22,0,0} },
		{ t = 0.3, e = "linear", UT = {-15,-28,0}, LT = {0,-8,0}, LTp = {0,-0.3,-0.6},
			LUA = {88,15,-5}, LLA = {8,0,0}, RUA = {20,0,30}, RLA = {60,0,0}, RH = {-40,0,0},
			RUL = {28,0,0}, RLL = {-32,0,0}, LUL = {-22,0,0} },
	}, markers = { { t = 0.1, name = "Hit" } } },
	Bash_Recover = { length = 1.0, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.35, e = "quadOut", UT = {-14,-10,0}, HD = {-6,0,0}, LUA = {45,-10,-12}, LLA = {45,0,0},
			RUA = {25,0,22}, RLA = {50,0,0}, RH = {-45,0,0} },
		{ t = 1.0, e = "sine", UT = {-4,0,0}, LTp = {0,-0.12,0}, RUL = {0,0,10}, LUL = {0,0,-10},
			LUA = {65,-40,0}, LLA = {80,0,0}, RUA = {35,0,22}, RLA = {95,0,0}, RH = {-55,0,0} },
	}},

	-- Таран: присел за щитом, рывок, удар всем корпусом.
	Rush_Windup = { length = 1.0, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.6, e = "quadOut", UT = {-28,0,0}, HD = {20,0,0}, LTp = {0,-0.6,0.3},
			LUA = {80,-20,0}, LLA = {60,0,0}, RUA = {30,0,25}, RLA = {90,0,0}, RH = {-50,0,0},
			RUL = {-30,0,0}, RLL = {-50,0,0}, LUL = {55,0,0}, LLL = {-70,0,0}, LF = {15,0,0} },
		{ t = 1.0, e = "linear", UT = {-32,0,0}, HD = {24,0,0}, LTp = {0,-0.7,0.35},
			LUA = {82,-20,0}, LLA = {58,0,0}, RUA = {30,0,25}, RLA = {90,0,0}, RH = {-50,0,0},
			RUL = {-32,0,0}, RLL = {-52,0,0}, LUL = {58,0,0}, LLL = {-72,0,0}, LF = {15,0,0} },
	}},
	Rush = { length = 0.42, loop = true, priority = "Action", keys = {
		{ t = 0.00, e = "linear", UT = {-30,0,0}, HD = {22,0,0}, LTp = {0,-0.4,0},
			LUA = {85,-15,0}, LLA = {50,0,0}, RUA = {25,0,25}, RLA = {90,0,0}, RH = {-50,0,0},
			RUL = {45,0,0}, RLL = {-20,0,0}, LUL = {-30,0,0}, LLL = {-40,0,0} },
		{ t = 0.21, e = "sine", UT = {-30,0,0}, HD = {22,0,0}, LTp = {0,-0.3,0},
			LUA = {85,-15,0}, LLA = {50,0,0}, RUA = {25,0,25}, RLA = {90,0,0}, RH = {-50,0,0},
			LUL = {45,0,0}, LLL = {-20,0,0}, RUL = {-30,0,0}, RLL = {-40,0,0} },
		{ t = 0.42, e = "sine", UT = {-30,0,0}, HD = {22,0,0}, LTp = {0,-0.4,0},
			LUA = {85,-15,0}, LLA = {50,0,0}, RUA = {25,0,25}, RLA = {90,0,0}, RH = {-50,0,0},
			RUL = {45,0,0}, RLL = {-20,0,0}, LUL = {-30,0,0}, LLL = {-40,0,0} },
	}, markers = { { t = 0.0, name = "Step" }, { t = 0.21, name = "Step" } } },
	Rush_Recover = { length = 0.9, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.25, e = "quadOut", UT = {-20,0,0}, LTp = {0,-0.5,-0.2},
			LUA = {80,-10,0}, LLA = {30,0,0}, RUA = {30,0,25}, RLA = {80,0,0}, RH = {-50,0,0},
			RUL = {35,0,0}, RLL = {-40,0,0}, LUL = {-15,0,0} },
		{ t = 0.9, e = "sine", UT = {-4,0,0}, LTp = {0,-0.12,0}, RUL = {0,0,10}, LUL = {0,0,-10},
			LUA = {65,-40,0}, LLA = {80,0,0}, RUA = {35,0,22}, RLA = {95,0,0}, RH = {-55,0,0} },
	}, markers = { { t = 0.05, name = "Hit" } } },

	-- Взмах древком знамени по кругу (только пока знамя на спине / в руке).
	Sweep_Windup = { length = 1.1, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 1.1, e = "quadOut", LT = {0,55,0}, UT = {-8,45,0}, HD = {0,-60,0}, LTp = {0,-0.3,0},
			RUA = {150,40,-20}, RLA = {35,0,0}, RH = {-30,0,0}, LUA = {40,-30,-20}, LLA = {70,0,0},
			RUL = {25,0,10}, RLL = {-30,0,0}, LUL = {-10,0,-15} },
	}},
	Sweep_Strike = { length = 0.45, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		{ t = 0.12, e = "quadIn", LT = {0,0,0}, UT = {-10,0,0}, HD = {0,0,0}, LTp = {0,-0.45,0},
			RUA = {95,0,40}, RLA = {10,0,0}, RH = {-30,0,0}, LUA = {40,-30,-20}, LLA = {70,0,0} },
		{ t = 0.30, e = "quadOut", LT = {0,-80,0}, UT = {-12,-50,0}, HD = {0,50,0}, LTp = {0,-0.5,0},
			RUA = {90,-60,60}, RLA = {5,0,0}, RH = {-30,0,0}, LUA = {40,-30,-20}, LLA = {70,0,0},
			RUL = {-10,0,15}, LUL = {25,0,-10}, LLL = {-30,0,0} },
		{ t = 0.45, e = "linear", LT = {0,-90,0}, UT = {-12,-55,0}, HD = {0,55,0}, LTp = {0,-0.5,0},
			RUA = {88,-65,62}, RLA = {5,0,0}, RH = {-30,0,0}, LUA = {40,-30,-20}, LLA = {70,0,0},
			RUL = {-10,0,15}, LUL = {25,0,-10}, LLL = {-30,0,0} },
	}, markers = { { t = 0.15, name = "Hit" }, { t = 0.3, name = "Scrape" } } },
	Sweep_Recover = { length = 1.3, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.5, e = "quadOut", LT = {0,-40,0}, UT = {-10,-20,0}, LTp = {0,-0.3,0},
			RUA = {50,-20,30}, RLA = {30,0,0}, RH = {-40,0,0}, LUA = {50,-30,-10}, LLA = {70,0,0} },
		{ t = 1.3, e = "sine", UT = {-4,0,0}, LTp = {0,-0.12,0}, RUL = {0,0,10}, LUL = {0,0,-10},
			LUA = {65,-40,0}, LLA = {80,0,0}, RUA = {35,0,22}, RLA = {95,0,0}, RH = {-55,0,0} },
	}},

	-- Клевец сверху вниз — добивание после тарана (comboOnly).
	Pick_Windup = { length = 0.7, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.7, e = "quadOut", UT = {10,15,0}, HD = {12,-10,0}, LTp = {0,0.05,0},
			RUA = {165,10,-10}, RLA = {50,0,0}, RH = {-30,0,0}, LUA = {60,-35,0}, LLA = {80,0,0},
			RUL = {-8,0,0}, LUL = {12,0,0}, RF = {-10,0,0} },
	}},
	Pick_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		{ t = 0.10, e = "snap", UT = {-35,-10,0}, HD = {-15,0,0}, LTp = {0,-0.5,-0.2},
			RUA = {50,0,10}, RLA = {5,0,0}, RH = {-50,0,0}, LUA = {55,-35,0}, LLA = {80,0,0},
			RUL = {40,0,0}, RLL = {-50,0,0}, LUL = {-15,0,0} },
		{ t = 0.30, e = "linear", UT = {-35,-10,0}, HD = {-15,0,0}, LTp = {0,-0.5,-0.2},
			RUA = {48,0,10}, RLA = {5,0,0}, RH = {-50,0,0}, LUA = {55,-35,0}, LLA = {80,0,0},
			RUL = {40,0,0}, RLL = {-50,0,0}, LUL = {-15,0,0} },
	}, markers = { { t = 0.10, name = "Hit" } } },
	Pick_Recover = { length = 1.0, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.35, e = "linear", UT = {-30,-5,0}, LTp = {0,-0.45,-0.1},
			RUA = {45,0,12}, RLA = {10,0,0}, RH = {-50,0,0}, LUA = {55,-35,0}, LLA = {80,0,0},
			RUL = {35,0,0}, RLL = {-45,0,0} },
		{ t = 1.0, e = "quadInOut", UT = {-4,0,0}, LTp = {0,-0.12,0}, RUL = {0,0,10}, LUL = {0,0,-10},
			LUA = {65,-40,0}, LLA = {80,0,0}, RUA = {35,0,22}, RLA = {95,0,0}, RH = {-55,0,0} },
	}},

	-- Рог: щит опущен, правая рука подносит рог ко рту, корпус откинут.
	-- Сервер держит фазу hornTime = 2 с; анимация 2 с, рёв на 0,6 с.
	Horn = { length = 2.0, loop = false, priority = "Action4", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.4, e = "quadOut", UT = {12,10,0}, HD = {25,0,0}, LTp = {0,-0.1,0.1},
			RUA = {140,-30,20}, RLA = {120,0,0}, RH = {0,0,0}, LUA = {30,-20,-20}, LLA = {40,0,0},
			RUL = {0,0,12}, LUL = {0,0,-12} },
		{ t = 1.5, e = "linear", UT = {16,10,0}, HD = {30,0,0}, LTp = {0,-0.05,0.12},
			RUA = {142,-30,20}, RLA = {122,0,0}, LUA = {30,-20,-20}, LLA = {40,0,0},
			RUL = {0,0,12}, LUL = {0,0,-12} },
		{ t = 2.0, e = "sine", UT = {-4,0,0}, LTp = {0,-0.12,0}, RUL = {0,0,10}, LUL = {0,0,-10},
			LUA = {65,-40,0}, LLA = {80,0,0}, RUA = {35,0,22}, RLA = {95,0,0}, RH = {-55,0,0} },
	}, markers = { { t = 0.6, name = "Roar" } } },


}
