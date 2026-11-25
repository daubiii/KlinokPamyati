--!nonstrict
--!nolint SameLineStatement
-- Anim/Gatekeeper — Привратник (ТЗ врагов, раздел 3.4). Таблица без изменений.
-- Сумма углов правой руки −90 означает меч остриём вниз (упёрт в пол).
-- Атаки, которых в ТЗ нет (выпад, прыжок, двойной рубящий), — в
-- GatekeeperExtra, помечены (доп.).

local PLANT = { UT = {-6,0,0}, HD = {-5,0,0},
	RUA = {50,35,0}, RLA = {20,0,0}, RH = {-160,0,0},
	LUA = {50,-35,0}, LLA = {20,0,0}, LH = {-160,0,0},
	RUL = {0,0,6}, LUL = {0,0,-6} }
local function with(base, extra) local t = table.clone(base) for k, v in pairs(extra) do t[k] = v end return t end
return {
	Idle = { length = 3.0, loop = true, priority = "Idle", keys = {
		with(PLANT, { t = 0.0, e = "linear" }),
		with(PLANT, { t = 1.5, e = "sine", UT = {-9,0,0}, LTp = {0,-0.1,0}, RUA = {53,35,0}, LUA = {53,-35,0} }),
		with(PLANT, { t = 3.0, e = "sine" }),
	}},
	-- Меч волочится по земле правой рукой (сумма 10 + 10 − 115 = −95).
	Walk = { inherit = "Base.Walk", amp = 0.8, speed = 0.67,
		override = { UT = {-8,0,0}, RUA = {10,0,15}, RLA = {10,0,0}, RH = {-115,0,0} } },

	Intro = { length = 4.2, loop = false, priority = "Action4", keys = {
		{ t = 0.0, e = "linear", LTp = {0,-1.6,0}, UT = {-50,0,0}, HD = {-40,0,0},
			RUL = {90,0,0}, LUL = {90,0,0}, RLL = {-110,0,0}, LLL = {-110,0,0},
			RUA = {60,30,0}, RLA = {30,0,0}, RH = {-180,0,0}, LUA = {60,-30,0}, LLA = {30,0,0}, LH = {-180,0,0} },
		{ t = 2.0, e = "linear", LTp = {0,-1.6,0}, UT = {-50,0,0}, HD = {-40,0,0},
			RUL = {90,0,0}, LUL = {90,0,0}, RLL = {-110,0,0}, LLL = {-110,0,0},
			RUA = {60,30,0}, RLA = {30,0,0}, RH = {-180,0,0}, LUA = {60,-30,0}, LLA = {30,0,0}, LH = {-180,0,0} },
		{ t = 2.6, e = "quadOut", LTp = {0,-0.3,0}, UT = {-10,0,0}, HD = {0,0,0},
			RUL = {20,0,0}, LUL = {20,0,0}, RLL = {-30,0,0}, LLL = {-30,0,0},
			RUA = {50,35,0}, RLA = {20,0,0}, RH = {-160,0,0}, LUA = {50,-35,0}, LLA = {20,0,0}, LH = {-160,0,0} },
		{ t = 3.2, e = "backOut", UT = {15,0,0}, HD = {25,0,0},
			RUA = {120,0,60}, RLA = {20,0,0}, RH = {-60,0,0}, LUA = {120,0,-60}, LLA = {20,0,0} },
		with(PLANT, { t = 4.2, e = "sine" }),
	}, markers = { { t = 2.1, name = "EyesOn" }, { t = 3.2, name = "Roar" } } },

	Slash_Windup = { length = 0.8, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.8, e = "quadOut", UT = {8,-35,0}, HD = {0,25,0}, LTp = {0,-0.2,0.2},
			RUA = {160,-20,30}, RLA = {40,0,0}, RH = {-20,0,0}, LUA = {140,-40,0}, LLA = {50,0,0}, LH = {-20,0,0},
			RUL = {15,0,0}, RLL = {-15,0,0}, LUL = {-15,0,0} },
	}},
	Slash_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		{ t = 0.12, e = "snap", UT = {-20,25,0}, HD = {-10,-15,0}, LTp = {0,-0.4,-0.6},
			RUA = {30,20,-10}, RLA = {10,0,0}, RH = {-40,0,0}, LUA = {25,10,0}, LLA = {15,0,0}, LH = {-40,0,0},
			RUL = {-15,0,0}, RLL = {-35,0,0}, LUL = {35,0,0}, LLL = {-15,0,0} },
		{ t = 0.30, e = "linear", UT = {-22,27,0}, HD = {-10,-15,0}, LTp = {0,-0.4,-0.6},
			RUA = {26,20,-12}, RLA = {10,0,0}, RH = {-40,0,0}, LUA = {22,10,0}, LLA = {15,0,0}, LH = {-40,0,0},
			RUL = {-15,0,0}, RLL = {-35,0,0}, LUL = {35,0,0}, LLL = {-15,0,0} },
	}, markers = { { t = 0.12, name = "Hit" } } },
	-- Пауза после любой атаки (1,5 с, уязвим): меч воткнут, тяжело дышит.
	Recover = { length = 1.5, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.3, e = "quadOut", UT = {-30,15,0}, HD = {-20,0,0}, LTp = {0,-0.3,0},
			RUA = {25,10,0}, RLA = {10,0,0}, RH = {-125,0,0}, LUA = {20,0,-10}, LLA = {20,0,0} },
		{ t = 0.9, e = "sine", UT = {-26,15,0}, HD = {-16,0,0}, LTp = {0,-0.32,0},
			RUA = {25,10,0}, RLA = {10,0,0}, RH = {-125,0,0}, LUA = {20,0,-10}, LLA = {20,0,0} },
		with(PLANT, { t = 1.5, e = "sine" }),
	}},

	Spin_Windup = { length = 1.0, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 1.0, e = "quadOut", LTp = {0,-0.5,0}, UT = {-10,-70,0}, HD = {0,50,0},
			RUA = {80,-70,0}, RLA = {5,0,0}, RH = {-80,0,0}, LUA = {60,-60,0}, LLA = {20,0,0},
			RUL = {40,0,0}, LUL = {30,0,0}, RLL = {-50,0,0}, LLL = {-40,0,0} },
	}},
	-- Полный оборот: 4 кадра по 120° (для AnimationId нельзя шагать на 180° — неоднозначно).
	Spin_Strike = { length = 0.4, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.1, e = "linear", LT = {0,120,0}, LTp = {0,-0.5,0}, UT = {-10,-20,0}, RUA = {85,0,0}, RLA = {5,0,0}, RH = {-85,0,0}, LUA = {40,0,-30}, RUL = {30,0,0}, LUL = {30,0,0}, RLL = {-40,0,0}, LLL = {-40,0,0} },
		{ t = 0.2, e = "linear", LT = {0,240,0}, LTp = {0,-0.5,0}, UT = {-10,-20,0}, RUA = {85,0,0}, RLA = {5,0,0}, RH = {-85,0,0}, LUA = {40,0,-30}, RUL = {30,0,0}, LUL = {30,0,0}, RLL = {-40,0,0}, LLL = {-40,0,0} },
		{ t = 0.3, e = "linear", LT = {0,360,0}, LTp = {0,-0.5,0}, UT = {-10,-20,0}, RUA = {85,0,0}, RLA = {5,0,0}, RH = {-85,0,0}, LUA = {40,0,-30}, RUL = {30,0,0}, LUL = {30,0,0}, RLL = {-40,0,0}, LLL = {-40,0,0} },
		{ t = 0.4, e = "quadOut", LT = {0,360,0}, LTp = {0,-0.4,0}, UT = {-18,0,0}, RUA = {40,0,10}, RLA = {10,0,0}, RH = {-90,0,0} },
	}, markers = { { t = 0.15, name = "Hit" } } },

	Chains_Windup = { length = 1.0, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 1.0, e = "quadOut", UT = {15,0,0}, HD = {20,0,0}, LTp = {0,0.15,0},
			RUA = {175,0,5}, RLA = {10,0,0}, RH = {-80,0,0}, LUA = {175,0,-5}, LLA = {10,0,0}, LH = {-80,0,0},
			RUL = {60,0,0}, RLL = {-70,0,0} },
	}},
	Chains_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.1, e = "snap", UT = {-35,0,0}, HD = {-25,0,0}, LTp = {0,-0.6,-0.2},
			RUA = {40,0,0}, RLA = {10,0,0}, RH = {-140,0,0}, LUA = {40,0,0}, LLA = {10,0,0}, LH = {-140,0,0} },
		{ t = 0.3, e = "linear", UT = {-35,0,0}, HD = {-25,0,0}, LTp = {0,-0.6,-0.2},
			RUA = {40,0,0}, RLA = {10,0,0}, RH = {-140,0,0}, LUA = {40,0,0}, LLA = {10,0,0}, LH = {-140,0,0} },
	}, markers = { { t = 0.1, name = "Hit" }, { t = 0.1, name = "Step" } } },

	Charge_Windup = { length = 1.2, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 1.2, e = "quadOut", LTp = {0,-0.7,0.3}, UT = {-50,0,0}, HD = {40,0,0},
			RUA = {-40,0,20}, RLA = {10,0,0}, RH = {-100,0,0}, LUA = {60,0,-20}, LLA = {90,0,0},
			RUL = {70,0,0}, RLL = {-90,0,0}, LUL = {-20,0,0}, LLL = {-30,0,0}, RF = {20,0,0} },
	}, markers = { { t = 0.3, name = "Scrape" }, { t = 0.6, name = "Scrape" }, { t = 0.9, name = "Scrape" } } },
	-- Состояние сервера "dash" (таран): тяжёлый бег, плечо вперёд.
	Charge = { inherit = "Base.Walk", amp = 1.4, speed = 2.0,
		override = { UT = {-45,0,0}, HD = {35,0,0}, LUA = {60,0,-20}, LLA = {90,0,0}, RUA = {-40,0,20}, RLA = {10,0,0}, RH = {-100,0,0} } },
	-- Удар в стену: отдача, затем общая Stun с амплитудой ×1.3.
	WallHit = { length = 0.3, loop = false, priority = "Action2", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.1, e = "snap", UT = {25,0,0}, HD = {30,0,0}, LTp = {0,-0.2,0.6}, RUA = {-30,0,30}, LUA = {-30,0,-30} },
		{ t = 0.3, e = "quadOut", UT = {10,0,0}, HD = {10,0,0}, LTp = {0,-0.3,0.4} },
	}},

	Phase2 = { length = 2.0, loop = false, priority = "Action4", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.4, e = "quadOut", LTp = {0,-1.2,0}, UT = {-40,0,0}, HD = {-30,0,0},
			RUL = {90,0,0}, RLL = {-90,0,0}, LUL = {20,0,0}, LLL = {-110,0,0},
			RUA = {50,35,0}, RLA = {20,0,0}, RH = {-160,0,0}, LUA = {50,-35,0}, LLA = {20,0,0}, LH = {-160,0,0} },
		{ t = 1.2, e = "linear", LTp = {0,-1.2,0}, UT = {-42,0,0}, HD = {-32,0,0},
			RUL = {90,0,0}, RLL = {-90,0,0}, LUL = {20,0,0}, LLL = {-110,0,0},
			RUA = {50,35,0}, RLA = {20,0,0}, RH = {-160,0,0}, LUA = {50,-35,0}, LLA = {20,0,0}, LH = {-160,0,0} },
		{ t = 1.6, e = "backOut", UT = {20,0,0}, HD = {30,0,0},
			RUA = {110,0,70}, RLA = {20,0,0}, RH = {-60,0,0}, LUA = {110,0,-70}, LLA = {20,0,0} },
		with(PLANT, { t = 2.0, e = "sine" }),
	}, markers = { { t = 0.6, name = "Crack" }, { t = 1.6, name = "Roar" } } },

	Death = { length = 1.2, loop = false, priority = "Action4", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.5, e = "quadOut", LTp = {0,-1.2,0}, UT = {-30,0,0}, HD = {-25,0,0},
			RUL = {90,0,0}, RLL = {-90,0,0}, LUL = {20,0,0}, LLL = {-110,0,0},
			RUA = {50,35,0}, RLA = {20,0,0}, RH = {-160,0,0}, LUA = {-10,0,-20} },
		{ t = 1.2, e = "quadIn", LTp = {0,-2.0,-0.8}, UT = {-70,0,10}, HD = {-40,0,10},
			RUL = {90,0,0}, RLL = {-100,0,0}, LUL = {80,0,0}, LLL = {-110,0,0},
			RUA = {-20,0,40}, LUA = {-20,0,-40} },
	}, markers = { { t = 1.2, name = "Shatter" } } },
}
