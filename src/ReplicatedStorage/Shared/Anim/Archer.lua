--!nonstrict
-- Anim/Archer — Теневой стрелок (ТЗ врагов, раздел 3.4). Таблица без изменений.
-- Контрольная поза Shot_Windup в конце: левая рука смотрит на игрока, правая
-- кисть у подбородка. Если рука уходит мимо — крутить LUA.y и LT.y так, чтобы
-- их сумма оставалась около 25°.

local HOLD = { LUA = {25,0,-10}, LLA = {20,0,0}, RUA = {0,0,10}, RLA = {25,0,0} }
return {
	Idle = { length = 2.0, loop = true, priority = "Idle", keys = {
		{ t = 0.0, e = "linear", UT = {-4,0,0}, HD = {0,-10,0}, LUA = {25,0,-10}, LLA = {20,0,0}, RUA = {0,0,10}, RLA = {25,0,0} },
		{ t = 1.0, e = "sine", UT = {-4,0,0}, HD = {0,10,0}, LUA = {25,0,-10}, LLA = {20,0,0}, RUA = {0,0,10}, RLA = {25,0,0} },
		{ t = 2.0, e = "sine", UT = {-4,0,0}, HD = {0,-10,0}, LUA = {25,0,-10}, LLA = {20,0,0}, RUA = {0,0,10}, RLA = {25,0,0} },
	}},
	Walk   = { inherit = "Base.Walk",   override = HOLD },   -- отход: та же анимация со скоростью −1
	Strafe = { inherit = "Base.Strafe", override = HOLD },

	-- Стойка боком: левое плечо к цели, левая рука указывает на цель, правая тянет тетиву к подбородку.
	Shot_Windup = { length = 0.7, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		{ t = 0.25, e = "quadOut", LT = {0,-60,0}, UT = {0,-25,0}, HD = {0,80,0},
			LUA = {90,85,0}, LLA = {0,0,0}, RUA = {90,60,0}, RLA = {120,0,0},
			RUL = {0,0,10}, LUL = {0,0,-10} },
		{ t = 0.70, e = "linear", LT = {0,-60,0}, UT = {-5,-28,0}, HD = {0,82,0},
			LUA = {90,85,0}, LLA = {0,0,0}, RUA = {95,50,10}, RLA = {140,0,0},
			RUL = {0,0,10}, LUL = {0,0,-10} },
	}, markers = { { t = 0.35, name = "AimLine" } } },
	Shot_Strike = { length = 0.25, loop = false, priority = "Action", keys = {
		{ t = 0.00, e = "linear", from = "pose" },
		{ t = 0.05, e = "snap", LT = {0,-60,0}, UT = {-5,-28,0}, HD = {0,82,0},
			LUA = {90,85,0}, RUA = {70,40,30}, RLA = {40,0,0}, RUL = {0,0,10}, LUL = {0,0,-10} },
		{ t = 0.25, e = "quadOut", LT = {0,-40,0}, UT = {-4,-15,0}, HD = {0,50,0},
			LUA = {80,60,0}, RUA = {40,20,20}, RLA = {40,0,0} },
	}, markers = { { t = 0.0, name = "Release" } } },
	Shot_Recover = { length = 0.6, loop = false, priority = "Action", keys = {
		{ t = 0.0, e = "linear", from = "pose" },
		{ t = 0.6, e = "sine", UT = {-4,0,0}, LUA = {25,0,-10}, LLA = {20,0,0}, RUA = {0,0,10}, RLA = {25,0,0} },
	}},
}
