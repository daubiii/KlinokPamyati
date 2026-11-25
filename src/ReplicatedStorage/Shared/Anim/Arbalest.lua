--!nonstrict
-- Anim/Arbalest — Арбалетчица башни (мини-босс Северной башни).
-- Тяжёлый арбалет двумя руками: приклад у правого плеча, левая рука держит
-- ложе снизу. Порядок поворота суставов как у EnemyAnimator:
-- Angles(0,y,0)·Angles(x,0,z).
--
-- Атаки сервера (Config/Enemies.arbalest): aimedBolt, volley, chainBolt —
-- фаза «подъём» (с вершины по пандусу); stock, leapShot, traps, lastBolt —
-- фаза «вершина». Перезарядка — состояние reload (Reload).
-- Маркеры: AimLine — прицельный луч, Release — выстрел, Hit — удар
-- прикладом, Step — шаг.

-- Арбалет у бедра (покой, ходьба).
local HIP = { RUA = {30,0,12}, RLA = {70,0,0}, LUA = {45,25,-5}, LLA = {75,0,0} }
-- Прицел: ложе на уровне глаз, обе руки вперёд.
local AIM = { UT = {0,-10,0}, HD = {-5,10,0},
	RUA = {88,-15,15}, RLA = {35,0,0}, LUA = {85,20,0}, LLA = {15,0,0} }

local function aim(extra)
	local key = {}
	for code, value in pairs(AIM) do
		key[code] = value
	end
	for code, value in pairs(extra or {}) do
		key[code] = value
	end
	return key
end

local function at(t: number, e: string, pose)
	local key = table.clone(pose)
	key.t = t
	key.e = e
	return key
end

return {
	Idle = { length = 2.2, loop = true, priority = "Idle", keys = {
		{ t = 0.0, e = "linear", UT = {-3,0,0}, HD = {0,-12,0}, RUA = {30,0,12}, RLA = {70,0,0}, LUA = {45,25,-5}, LLA = {75,0,0} },
		{ t = 1.1, e = "sine", UT = {-4,0,0}, HD = {0,12,0}, LTp = {0,-0.04,0}, RUA = {32,0,12}, RLA = {72,0,0}, LUA = {46,25,-5}, LLA = {75,0,0} },
		{ t = 2.2, e = "sine", UT = {-3,0,0}, HD = {0,-12,0}, RUA = {30,0,12}, RLA = {70,0,0}, LUA = {45,25,-5}, LLA = {75,0,0} },
	}},
	Walk   = { inherit = "Base.Walk", amp = 0.9, override = HIP },
	Strafe = { inherit = "Base.Strafe", override = HIP },

	-- Прицельный болт (парируемый, отражается). Луч — последние 0,35 с.
	Aim_Windup = { length = 1.0, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		at(0.35, "quadOut", aim({ RUL = {0,0,8}, LUL = {-10,0,-8} })),
		at(1.00, "linear", aim({ UT = {-2,-12,0}, RUL = {0,0,8}, LUL = {-10,0,-8} })),
	}, markers = { { t = 0.65, name = "AimLine" } } },
	Aim_Strike = { length = 0.25, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		at(0.05, "snap", aim({ UT = {-12,-12,0}, HD = {-12,10,0}, RUA = {100,-15,15}, LUA = {98,20,0} })),
		at(0.25, "quadOut", aim({ UT = {-6,-10,0} })),
	}, markers = { { t = 0.0, name = "Release" } } },
	Aim_Recover = { length = 0.4, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.4, e = "sine", UT = {-3,0,0}, RUA = {30,0,12}, RLA = {70,0,0}, LUA = {45,25,-5}, LLA = {75,0,0} },
	}},

	-- Залп: арбалет вверх под 50°, болты падают по зонам.
	Volley_Windup = { length = 1.3, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.6, e = "quadOut", UT = {25,-5,0}, HD = {30,5,0}, LTp = {0,-0.1,0.1},
			RUA = {140,-15,15}, RLA = {35,0,0}, LUA = {138,20,0}, LLA = {15,0,0}, RUL = {-10,0,6}, LUL = {15,0,-6} },
		{ t = 1.3, e = "linear", UT = {28,-5,0}, HD = {32,5,0}, LTp = {0,-0.12,0.12},
			RUA = {142,-15,15}, RLA = {35,0,0}, LUA = {140,20,0}, LLA = {15,0,0}, RUL = {-10,0,6}, LUL = {15,0,-6} },
	}},
	Volley_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.06, e = "snap", UT = {18,-5,0}, HD = {25,5,0}, LTp = {0,-0.2,0.2},
			RUA = {150,-15,15}, RLA = {35,0,0}, LUA = {148,20,0}, LLA = {15,0,0} },
		{ t = 0.3, e = "quadOut", UT = {20,-5,0}, HD = {25,5,0}, RUA = {135,-15,15}, RLA = {35,0,0}, LUA = {132,20,0}, LLA = {15,0,0} },
	}, markers = { { t = 0.0, name = "Release" } } },
	Volley_Recover = { length = 0.6, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.6, e = "sine", UT = {-3,0,0}, RUA = {30,0,12}, RLA = {70,0,0}, LUA = {45,25,-5}, LLA = {75,0,0} },
	}},

	-- Цепной болт: тот же прицел, но ниже — в пандус перед игроком.
	Chain_Windup = { length = 1.0, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		at(0.40, "quadOut", aim({ UT = {-18,-10,0}, HD = {-20,10,0}, RUA = {70,-15,15}, LUA = {68,20,0}, LTp = {0,-0.2,0} })),
		at(1.00, "linear", aim({ UT = {-20,-12,0}, HD = {-22,10,0}, RUA = {70,-15,15}, LUA = {68,20,0}, LTp = {0,-0.22,0} })),
	}, markers = { { t = 0.65, name = "AimLine" } } },
	Chain_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		at(0.06, "snap", aim({ UT = {-26,-12,0}, HD = {-24,10,0}, RUA = {80,-15,15}, LUA = {78,20,0}, LTp = {0,-0.3,0.2} })),
		at(0.30, "quadOut", aim({ UT = {-16,-10,0}, RUA = {70,-15,15}, LUA = {68,20,0} })),
	}, markers = { { t = 0.0, name = "Release" } } },
	Chain_Recover = { length = 0.5, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.5, e = "sine", UT = {-3,0,0}, RUA = {30,0,12}, RLA = {70,0,0}, LUA = {45,25,-5}, LLA = {75,0,0} },
	}},

	-- Удар прикладом на вершине (парируемый).
	Stock_Windup = { length = 0.6, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.6, e = "quadOut", LT = {0,25,0}, UT = {-5,35,0}, HD = {0,-40,0},
			RUA = {60,40,30}, RLA = {90,0,0}, LUA = {70,50,0}, LLA = {60,0,0},
			RUL = {-15,0,0}, LUL = {20,0,0}, LLL = {-20,0,0} },
	}},
	Stock_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.1, e = "snap", LT = {0,-25,0}, UT = {-15,-30,0}, HD = {0,25,0}, LTp = {0,-0.2,-0.4},
			RUA = {95,-20,10}, RLA = {20,0,0}, LUA = {90,-10,0}, LLA = {30,0,0},
			RUL = {30,0,0}, RLL = {-35,0,0}, LUL = {-20,0,0} },
		{ t = 0.3, e = "linear", LT = {0,-25,0}, UT = {-15,-30,0}, HD = {0,25,0}, LTp = {0,-0.2,-0.4},
			RUA = {95,-20,10}, RLA = {20,0,0}, LUA = {90,-10,0}, LLA = {30,0,0},
			RUL = {30,0,0}, RLL = {-35,0,0}, LUL = {-20,0,0} },
	}, markers = { { t = 0.1, name = "Hit" } } },
	Stock_Recover = { length = 0.8, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.8, e = "sine", UT = {-3,0,0}, RUA = {30,0,12}, RLA = {70,0,0}, LUA = {45,25,-5}, LLA = {75,0,0} },
	}},

	-- Прыжок назад с выстрелом: присед, отскок (сервер двигает на backstep),
	-- выстрел в верхней точке.
	Leap_Windup = { length = 0.8, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		at(0.20, "quadOut", aim({ UT = {-15,-10,0}, LTp = {0,-0.55,0}, RUL = {50,0,6}, LUL = {45,0,-6},
			RLL = {-80,0,0}, LLL = {-80,0,0}, RF = {30,0,0}, LF = {30,0,0} })),
		at(0.50, "quadOut", aim({ UT = {12,-10,0}, HD = {-10,10,0}, LTp = {0,0.9,0.3}, RUL = {20,0,6}, LUL = {-10,0,-6},
			RLL = {-50,0,0}, LLL = {-20,0,0}, RF = {-20,0,0}, LF = {-20,0,0} })),
		at(0.80, "quadIn", aim({ UT = {5,-10,0}, LTp = {0,0.4,0.1}, RUL = {25,0,6}, LUL = {5,0,-6},
			RLL = {-40,0,0}, LLL = {-30,0,0} })),
	}, markers = { { t = 0.45, name = "AimLine" } } },
	Leap_Strike = { length = 0.35, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		at(0.05, "snap", aim({ UT = {-8,-12,0}, RUA = {100,-15,15}, LUA = {98,20,0}, LTp = {0,0.1,0.1} })),
		at(0.35, "quadOut", aim({ UT = {-12,-10,0}, LTp = {0,-0.4,0}, RUL = {40,0,6}, LUL = {35,0,-6},
			RLL = {-60,0,0}, LLL = {-60,0,0} })),
	}, markers = { { t = 0.0, name = "Release" }, { t = 0.3, name = "Step" } } },
	Leap_Recover = { length = 0.9, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.9, e = "sine", UT = {-3,0,0}, RUA = {30,0,12}, RLA = {70,0,0}, LUA = {45,25,-5}, LLA = {75,0,0} },
	}},

	-- Ловушки: правая рука бросает капканы веером, арбалет в левой.
	Traps_Windup = { length = 0.9, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.9, e = "quadOut", LT = {0,30,0}, UT = {-10,25,0}, HD = {0,-30,0},
			RUA = {-30,20,40}, RLA = {60,0,0}, LUA = {40,25,-5}, LLA = {75,0,0},
			RUL = {-15,0,0}, LUL = {25,0,0}, LLL = {-30,0,0} },
	}},
	Traps_Strike = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.12, e = "snap", LT = {0,-25,0}, UT = {-15,-25,0}, HD = {0,20,0},
			RUA = {110,-30,30}, RLA = {10,0,0}, LUA = {40,25,-5}, LLA = {75,0,0},
			RUL = {25,0,0}, RLL = {-30,0,0}, LUL = {-15,0,0} },
		{ t = 0.3, e = "linear", LT = {0,-25,0}, UT = {-15,-25,0}, HD = {0,20,0},
			RUA = {105,-30,30}, RLA = {10,0,0}, LUA = {40,25,-5}, LLA = {75,0,0},
			RUL = {25,0,0}, RLL = {-30,0,0}, LUL = {-15,0,0} },
	}, markers = { { t = 0.12, name = "Release" } } },
	Traps_Recover = { length = 0.7, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.7, e = "sine", UT = {-3,0,0}, RUA = {30,0,12}, RLA = {70,0,0}, LUA = {45,25,-5}, LLA = {75,0,0} },
	}},

	-- Последний болт: 2 с на колене, луч разгорается. Прерывается уроном.
	Last_Windup = { length = 2.0, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		at(0.40, "quadOut", aim({ LTp = {0,-0.9,0}, UT = {-6,-12,0},
			RUL = {80,0,8}, RLL = {-80,0,0}, RF = {0,0,0}, LUL = {-10,0,-8}, LLL = {-90,0,0}, LF = {10,0,0} })),
		at(1.40, "linear", aim({ LTp = {0,-0.92,0}, UT = {-8,-13,0}, HD = {-8,12,0},
			RUL = {80,0,8}, RLL = {-80,0,0}, LUL = {-10,0,-8}, LLL = {-90,0,0}, LF = {10,0,0} })),
		at(2.00, "linear", aim({ LTp = {0,-0.95,0}, UT = {-10,-14,0}, HD = {-10,12,0},
			RUL = {80,0,8}, RLL = {-80,0,0}, LUL = {-10,0,-8}, LLL = {-90,0,0}, LF = {10,0,0} })),
	}, markers = { { t = 0.4, name = "AimLine" } } },
	Last_Strike = { length = 0.4, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		at(0.05, "snap", aim({ LTp = {0,-0.85,0.3}, UT = {-22,-14,0}, HD = {-18,12,0}, RUA = {105,-15,15}, LUA = {102,20,0},
			RUL = {80,0,8}, RLL = {-80,0,0}, LUL = {-10,0,-8}, LLL = {-90,0,0} })),
		at(0.40, "quadOut", aim({ LTp = {0,-0.8,0.2}, UT = {-14,-12,0},
			RUL = {80,0,8}, RLL = {-80,0,0}, LUL = {-10,0,-8}, LLL = {-90,0,0} })),
	}, markers = { { t = 0.0, name = "Release" } } },
	Last_Recover = { length = 1.2, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.5, e = "linear", LTp = {0,-0.6,0}, UT = {-12,0,0}, RUL = {60,0,8}, RLL = {-70,0,0}, LLL = {-60,0,0},
			RUA = {30,0,12}, RLA = {70,0,0}, LUA = {45,25,-5}, LLA = {75,0,0} },
		{ t = 1.2, e = "quadInOut", UT = {-3,0,0}, RUA = {30,0,12}, RLA = {70,0,0}, LUA = {45,25,-5}, LLA = {75,0,0} },
	}},

	-- Перезарядка: упор арбалета в пол, правая рука крутит ворот (петля).
	-- Окно для атаки — сервер держит состояние reload 2 с (reloadTime).
	Reload = { length = 0.8, loop = true, priority = "Action", keys = {
		{ t = 0.0, e = "linear", UT = {-30,0,0}, HD = {-15,0,0}, LTp = {0,-0.35,0},
			LUA = {50,10,-10}, LLA = {40,0,0}, RUA = {60,-20,30}, RLA = {90,0,0},
			RUL = {40,0,6}, RLL = {-45,0,0}, LUL = {-10,0,-6} },
		{ t = 0.2, e = "sine", UT = {-30,0,0}, HD = {-15,0,0}, LTp = {0,-0.35,0},
			LUA = {50,10,-10}, LLA = {40,0,0}, RUA = {40,-20,50}, RLA = {60,0,0},
			RUL = {40,0,6}, RLL = {-45,0,0}, LUL = {-10,0,-6} },
		{ t = 0.4, e = "sine", UT = {-30,0,0}, HD = {-15,0,0}, LTp = {0,-0.35,0},
			LUA = {50,10,-10}, LLA = {40,0,0}, RUA = {20,-20,30}, RLA = {90,0,0},
			RUL = {40,0,6}, RLL = {-45,0,0}, LUL = {-10,0,-6} },
		{ t = 0.6, e = "sine", UT = {-30,0,0}, HD = {-15,0,0}, LTp = {0,-0.35,0},
			LUA = {50,10,-10}, LLA = {40,0,0}, RUA = {40,-20,10}, RLA = {110,0,0},
			RUL = {40,0,6}, RLL = {-45,0,0}, LUL = {-10,0,-6} },
		{ t = 0.8, e = "sine", UT = {-30,0,0}, HD = {-15,0,0}, LTp = {0,-0.35,0},
			LUA = {50,10,-10}, LLA = {40,0,0}, RUA = {60,-20,30}, RLA = {90,0,0},
			RUL = {40,0,6}, RLL = {-45,0,0}, LUL = {-10,0,-6} },
	}, markers = { { t = 0.0, name = "Crank" }, { t = 0.4, name = "Crank" } } },
}
