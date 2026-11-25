--!nonstrict
-- Anim/WardSeal — Защитная печать (этаж 5): медленно вращается и покачивается.
-- Сгенерировано anims45.py (этажи 4–5): правки — там, затем перегенерировать.

return {
	Idle = { length = 4, loop = true, priority = "Idle", keys = {
		{ t = 0, e = "linear", LTp = {0,0,0} },
		{ t = 1, e = "linear", UT = {0,90,0}, LTp = {0,0.15,0} },
		{ t = 2, e = "linear", UT = {0,180,0}, LTp = {0,0,0} },
		{ t = 3, e = "linear", UT = {0,270,0}, LTp = {0,0.15,0} },
		{ t = 4, e = "linear", UT = {0,360,0}, LTp = {0,0,0} },
	} },
	Hit = { length = 0.3, loop = false, priority = "Action", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.06, e = "snap", UT = {10,0,8}, LTp = {0,-0.1,0} },
		{ t = 0.3, e = "sine",  },
	} },
	Death = { length = 0.6, loop = false, priority = "Action4", keys = {
		{ t = 0, e = "linear", from = "pose" },
		{ t = 0.3, e = "quadOut", UT = {0,0,30}, LTp = {0,0.6,0} },
		{ t = 0.6, e = "quadIn", UT = {60,0,40}, LTp = {0,-1.2,0} },
	}, markers = { { t = 0.55, name = "Shatter" } } },
	Spawn = { length = 0.8, loop = false, priority = "Action4", keys = {
		{ t = 0, e = "linear", LTp = {0,-1.5,0} },
		{ t = 0.8, e = "quadOut", LTp = {0,0,0} },
	} },
	Stun = { length = 0.8, loop = true, priority = "Action2", keys = {
		{ t = 0, e = "linear", UT = {8,0,6} },
		{ t = 0.4, e = "sine", UT = {-8,0,-6} },
		{ t = 0.8, e = "sine", UT = {8,0,6} },
	} },
}
