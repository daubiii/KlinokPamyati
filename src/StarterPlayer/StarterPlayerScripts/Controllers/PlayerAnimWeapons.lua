--!nonstrict
-- PlayerAnimWeapons (клиент)
-- Анимации оружия этажей 3–5 для PlayerAnimator (подмешиваются в него одной вставкой):
--   Styles   — «почерк» обычных мечей и молотов (масштаб размаха/хода/корпуса/разворота, как FLOOR2_STYLES);
--   Curves   — свои серии ударов: косы (широкие махи, финал — оборот);
--   StrikeAt — когда клинок проходит перед героем в своих сериях (след и вспышка удара);
--   Actions  — 16 способностей (имена — AbilityController.ANIMATIONS).
-- Ключи поз — как в PlayerAnimator (градусы), плюс ноги: rh_x/rk_x/lh_x/lk_x (бедро вперёд +, колено сгиб −)
-- и rt_h — вертикальный сдвиг корпуса в стадах (присед −, подскок +).

local PlayerAnimWeapons = {}

local function frame(t: number, ease: string, pose)
	local copy = table.clone(pose)
	copy.t = t
	copy.ease = ease
	return copy
end

local CROUCH = { rt_h = -0.45, rh_x = 26, rk_x = -52, lh_x = 30, lk_x = -56 }
local function with(pose, extra)
	local copy = table.clone(pose)
	for k, v in pairs(extra) do
		copy[k] = v
	end
	return copy
end

-- ===== Почерк обычного оружия =====
PlayerAnimWeapons.Styles = {
	-- этаж 3
	hunt_cleaver = { typeId = "sword", sweep = 1.1, drive = 1.06, body = 1.04, twist = 1.0 },
	hunt_broadsword = { typeId = "sword", sweep = 1.14, drive = 1.1, body = 1.08, twist = 1.02 },
	bear_mace = { typeId = "hammer", sweep = 1.0, drive = 1.16, body = 1.14, twist = 1.0 },
	pack_fang = { typeId = "sword", sweep = 1.08, drive = 0.96, body = 0.92, twist = 1.18 },
	trap_maul = { typeId = "hammer", sweep = 1.06, drive = 1.1, body = 1.1, twist = 1.04 },
	falconer_saber = { typeId = "sword", sweep = 1.18, drive = 0.88, body = 0.86, twist = 1.1 },
	-- этаж 4
	cast_cleaver = { typeId = "sword", sweep = 1.0, drive = 1.12, body = 1.1, twist = 0.94 },
	quench_blade = { typeId = "sword", sweep = 0.92, drive = 0.96, body = 0.9, twist = 0.92 },
	apprentice_hammer = { typeId = "hammer", sweep = 0.94, drive = 1.0, body = 1.0, twist = 0.96 },
	crucible_maul = { typeId = "hammer", sweep = 1.1, drive = 1.16, body = 1.18, twist = 1.0 },
	searing_blade = { typeId = "sword", sweep = 1.12, drive = 1.0, body = 0.96, twist = 1.1 },
	anvil_hammer = { typeId = "hammer", sweep = 1.0, drive = 1.22, body = 1.2, twist = 0.96 },
	forge_heart_blade = { typeId = "sword", sweep = 1.16, drive = 1.06, body = 1.02, twist = 1.12 },
	unfinished_blade = { typeId = "sword", sweep = 1.04, drive = 1.04, body = 1.0, twist = 1.04 },
	-- этаж 5
	paper_knife = { typeId = "sword", sweep = 0.74, drive = 0.9, body = 0.8, twist = 0.8 },
	tome_hammer = { typeId = "hammer", sweep = 1.06, drive = 1.06, body = 1.1, twist = 1.06 },
	bookmark_blade = { typeId = "sword", sweep = 0.86, drive = 0.92, body = 0.86, twist = 0.88 },
	quill_blade = { typeId = "sword", sweep = 0.8, drive = 0.9, body = 0.84, twist = 0.86 },
	seal_hammer = { typeId = "hammer", sweep = 0.92, drive = 1.14, body = 1.1, twist = 0.9 },
	hourglass_maul = { typeId = "hammer", sweep = 1.12, drive = 1.12, body = 1.14, twist = 1.08 },
	ink_blade = { typeId = "sword", sweep = 1.2, drive = 1.0, body = 0.98, twist = 1.16 },
	memory_blade = { typeId = "sword", sweep = 1.06, drive = 1.0, body = 0.96, twist = 1.08 },
}

-- ===== Косы: широкие махи, финал — оборот =====
local SCYTHE = {
	-- 1: низкий мах справа налево.
	{
		frame(0, "linear", {}),
		frame(0.24, "quadOut", { rs_x = 62, rs_y = -96, re_x = 40, rw_x = -70, ls_x = 60, ls_y = -60, le_x = 40, wa_y = -52, rt_y = -26, rt_x = 4, nk_y = 12 }),
		frame(0.4, "snap", with(CROUCH, { rs_x = 70, rs_y = 92, re_x = 12, rw_x = -66, ls_x = 64, ls_y = 50, le_x = 20, wa_y = 60, wa_x = -10, rt_y = 32, rt_x = -10, rt_h = -0.3, nk_y = -12 })),
		frame(0.7, "quadOut", { rs_x = 66, rs_y = 108, re_x = 16, rw_x = -62, ls_x = 60, ls_y = 56, le_x = 22, wa_y = 66, wa_x = -8, rt_y = 36, rt_x = -8, nk_y = -12 }),
		frame(1, "sine", {}),
	},
	-- 2: восходящий обратный мах.
	{
		frame(0, "linear", {}),
		frame(0.24, "quadOut", with(CROUCH, { rs_x = 40, rs_y = 90, re_x = 30, rw_x = -60, ls_x = 40, ls_y = 50, le_x = 30, wa_y = 54, rt_y = 28, rt_x = -6, rt_h = -0.35 })),
		frame(0.4, "snap", { rs_x = 128, rs_y = -78, re_x = 10, rw_x = -70, ls_x = 110, ls_y = -40, le_x = 16, wa_y = -60, wa_x = 6, rt_y = -30, rt_x = 6, rt_h = 0.1, nk_y = 12, nk_x = -8 }),
		frame(0.7, "quadOut", { rs_x = 120, rs_y = -88, re_x = 14, rw_x = -66, ls_x = 104, ls_y = -44, le_x = 18, wa_y = -64, wa_x = 4, rt_y = -32, rt_x = 4, nk_y = 12 }),
		frame(1, "sine", {}),
	},
	-- 3: финал — полный оборот с косой.
	{
		frame(0, "linear", {}),
		frame(0.2, "quadOut", { rs_x = 70, rs_y = -90, re_x = 30, rw_x = -70, ls_x = 62, ls_y = -56, le_x = 34, wa_y = -50, rt_y = -30, nk_y = 12 }),
		frame(0.62, "quadIn", with(CROUCH, { rs_x = 76, rs_y = 40, re_x = 14, rw_x = -70, ls_x = 64, ls_y = 30, le_x = 20, wa_y = 30, wa_x = -8, rt_y = 330, rt_h = -0.35 })),
		frame(0.76, "snap", { rs_x = 72, rs_y = 96, re_x = 12, rw_x = -66, ls_x = 60, ls_y = 52, le_x = 22, wa_y = 60, wa_x = -10, rt_y = 380, rt_x = -10, rt_h = -0.2 }),
		frame(1, "sine", { rt_y = 360 }),
	},
}

PlayerAnimWeapons.Curves = {
	royal_scythe = SCYTHE,
	slag_scythe = SCYTHE,
	oblivion_scythe = SCYTHE,
}

PlayerAnimWeapons.StrikeAt = {
	royal_scythe = { 0.34, 0.34, 0.7 },
	slag_scythe = { 0.34, 0.34, 0.7 },
	oblivion_scythe = { 0.34, 0.34, 0.7 },
}

-- ===== Способности =====
-- Доли кадров подогнаны под castTime/«момент действия» из LootFloor3/4/5 (в комментарии — доля и секунды).
local A = {}

-- Свора (0,5 с; вой на 0,5 ≈ summonAt 0,25): клинок вверх, голова запрокинута — и указать вперёд.
A.packHowl = {
	frames = {
		frame(0, "linear", {}),
		frame(0.3, "quadOut", { rs_x = 168, rs_y = -8, re_x = 20, rw_x = -20, ls_x = 40, ls_z = -50, le_x = 30, wa_x = 14, rt_x = 8, nk_x = -30, rt_h = 0.1 }),
		frame(0.5, "snap", { rs_x = 96, rs_y = 10, re_x = 4, rw_x = -90, ls_x = 70, ls_z = -20, le_x = 10, wa_x = -12, rt_x = -10, nk_x = 8, lh_x = 20, lk_x = -14 }),
		frame(0.85, "linear", { rs_x = 92, rs_y = 10, re_x = 6, rw_x = -88, ls_x = 64, le_x = 12, wa_x = -10, rt_x = -8, nk_x = 6 }),
		frame(1, "sine", {}),
	},
}

-- Капкан (0,75 с; удар на 0,5 ≈ slamAt 0,38): молот за голову, присед и удар в землю.
A.snareSlam = {
	frames = {
		frame(0, "linear", {}),
		frame(0.36, "quadOut", { rs_x = 178, rs_y = -6, re_x = 56, rw_x = -12, ls_x = 165, le_x = 50, wa_x = 24, rt_x = 10, nk_x = -12, rt_h = 0.15 }),
		frame(0.5, "snap", with(CROUCH, { rs_x = 16, re_x = 8, rw_x = -36, ls_x = 18, le_x = 10, wa_x = -50, rt_x = -24, nk_x = 14, rt_h = -0.6, rk_x = -64, lk_x = -66 })),
		frame(0.84, "linear", with(CROUCH, { rs_x = 18, re_x = 8, rw_x = -34, ls_x = 20, le_x = 10, wa_x = -46, rt_x = -20, nk_x = 12 })),
		frame(1, "sine", {}),
	},
}

-- Последний гон (0,55 с; замах до 0,33 ≈ windup 0,18, рывок 0,22 с): коса заведена за спину —
-- рывок с низким махом справа налево, полотно проходит сквозь строй.
A.huntLunge = {
	frames = {
		frame(0, "linear", {}),
		frame(0.3, "quadOut", with(CROUCH, { rs_x = 60, rs_y = -100, re_x = 40, rw_x = -70, ls_x = 58, ls_y = -62, le_x = 40, wa_y = -56, rt_y = -30, rt_x = 8, nk_y = 12 })),
		frame(0.42, "snap", { rs_x = 70, rs_y = 96, re_x = 12, rw_x = -66, ls_x = 64, ls_y = 54, le_x = 20, wa_y = 62, wa_x = -16, rt_y = 34, rt_x = -24, rt_h = -0.3, lh_x = 50, lk_x = -32, rh_x = -40, rk_x = -22, nk_x = 12 }),
		frame(0.78, "linear", { rs_x = 66, rs_y = 108, re_x = 16, rw_x = -62, ls_x = 60, ls_y = 56, le_x = 22, wa_y = 64, wa_x = -12, rt_y = 36, rt_x = -20, rt_h = -0.2, lh_x = 44, lk_x = -28, rh_x = -36, rk_x = -18, nk_x = 10 }),
		frame(1, "sine", {}),
	},
}

-- Пикирование (0,5 с; пуск на 0,4 ≈ releaseAt 0,2): левая рука вскидывает сокола, клинок указывает цель.
A.falconCall = {
	frames = {
		frame(0, "linear", {}),
		frame(0.24, "quadOut", { ls_x = 170, ls_y = 10, le_x = 10, rs_x = 50, rs_y = -20, re_x = 60, rw_x = -60, wa_x = 10, nk_x = -22, rt_h = 0.1 }),
		frame(0.4, "snap", { ls_x = 120, ls_y = -10, le_x = 0, rs_x = 96, rs_y = 8, re_x = 2, rw_x = -94, wa_x = -10, wa_y = 10, rt_x = -8, nk_x = 4, lh_x = 18, lk_x = -12 }),
		frame(0.8, "linear", { ls_x = 60, le_x = 20, rs_x = 92, rs_y = 6, re_x = 4, rw_x = -90, wa_x = -8, wa_y = 8, rt_x = -6 }),
		frame(1, "sine", {}),
	},
}

-- Разлив (0,8 с; опрокидывание на 0,5 ≈ pourAt 0,4): тигель снизу-сзади рывком вперёд-вверх двумя руками.
A.crucibleTip = {
	frames = {
		frame(0, "linear", {}),
		frame(0.34, "quadOut", with(CROUCH, { rs_x = -30, rs_y = 10, re_x = 20, rw_x = -10, ls_x = -20, ls_y = -10, le_x = 30, wa_x = 18, rt_x = 10, rt_y = -16, nk_x = -6 })),
		frame(0.5, "snap", { rs_x = 120, rs_y = 6, re_x = 10, rw_x = -60, ls_x = 112, ls_y = -12, le_x = 16, wa_x = -18, rt_x = -14, rt_y = 8, rt_h = 0.1, lh_x = 26, lk_x = -18 }),
		frame(0.82, "linear", { rs_x = 104, rs_y = 6, re_x = 12, rw_x = -66, ls_x = 98, le_x = 18, wa_x = -16, rt_x = -12, rt_y = 6 }),
		frame(1, "sine", {}),
	},
}

-- Перекал (0,45 с; волна на 0,5 ≈ novaAt 0,22): клинок вертикально у лица, присед — руки в стороны.
A.overheatFlare = {
	frames = {
		frame(0, "linear", {}),
		frame(0.3, "quadOut", with(CROUCH, { rs_x = 70, rs_y = 30, re_x = 90, rw_x = -10, ls_x = 70, ls_y = -40, le_x = 100, wa_x = 10, nk_x = 8 })),
		frame(0.5, "snap", { rs_x = 60, rs_y = -10, rs_z = 60, re_x = 10, rw_x = -40, ls_x = 60, ls_z = -60, le_x = 10, wa_x = -12, nk_x = -14, rt_h = 0.15 }),
		frame(0.82, "linear", { rs_x = 56, rs_z = 50, re_x = 12, rw_x = -40, ls_x = 56, ls_z = -50, le_x = 12, wa_x = -10, nk_x = -10 }),
		frame(1, "sine", {}),
	},
}

-- Наковальня с небес (0,6 с; метка на 0,5 ≈ markAt 0,3): молот в небо — и рывком вниз, указать точку.
A.anvilCall = {
	frames = {
		frame(0, "linear", {}),
		frame(0.3, "quadOut", { rs_x = 180, rs_y = 0, re_x = 0, rw_x = 0, ls_x = 150, ls_z = -20, le_x = 20, wa_x = 18, rt_x = 10, nk_x = -26, rt_h = 0.2 }),
		frame(0.5, "snap", with(CROUCH, { rs_x = 70, rs_y = 4, re_x = 6, rw_x = -50, ls_x = 40, le_x = 30, wa_x = -30, rt_x = -16, nk_x = 10, rt_h = -0.35 })),
		frame(0.84, "linear", with(CROUCH, { rs_x = 66, re_x = 8, rw_x = -48, ls_x = 36, le_x = 30, wa_x = -26, rt_x = -14, nk_x = 8, rt_h = -0.3 })),
		frame(1, "sine", {}),
	},
}

-- Дыхание горна (1,3 с; струя с 0,15 ≈ startAt 0,2): клинок вперёд, левая ладонь на клинке, упор ногами, дрожь.
local breathHold = { rs_x = 92, rs_y = 14, re_x = 4, rw_x = -92, ls_x = 84, ls_y = -40, le_x = 30, wa_x = -12, rt_x = -10, lh_x = 30, lk_x = -26, rh_x = -24, rk_x = -12, rt_h = -0.3, nk_x = 8 }
A.breathChannel = {
	frames = {
		frame(0, "linear", {}),
		frame(0.15, "quadOut", with(breathHold, { rs_x = 70, rw_x = -70, wa_x = 4, rt_x = 4 })),
		frame(0.24, "snap", breathHold),
		frame(0.4, "sine", with(breathHold, { rs_y = 10, wa_y = -4, nk_y = 3 })),
		frame(0.56, "sine", with(breathHold, { rs_y = 18, wa_y = 4, nk_y = -3 })),
		frame(0.72, "sine", with(breathHold, { rs_y = 10, wa_y = -4, nk_y = 3 })),
		frame(0.88, "sine", with(breathHold, { rs_y = 16, wa_y = 2 })),
		frame(1, "sine", {}),
	},
}

-- Шлаковый серп (0,85 с; удары на 0,35 и 0,73): два оборота с косой.
A.scytheSpin2 = {
	frames = {
		frame(0, "linear", {}),
		frame(0.14, "quadOut", { rs_x = 70, rs_y = -90, re_x = 30, rw_x = -70, ls_x = 60, ls_y = -56, le_x = 34, wa_y = -46, rt_y = -30, nk_y = 12 }),
		frame(0.35, "quadIn", with(CROUCH, { rs_x = 74, rs_y = 60, re_x = 14, rw_x = -68, ls_x = 62, ls_y = 36, le_x = 20, wa_y = 40, wa_x = -8, rt_y = 360, rt_h = -0.3 })),
		frame(0.73, "linear", with(CROUCH, { rs_x = 74, rs_y = 60, re_x = 14, rw_x = -68, ls_x = 62, ls_y = 36, le_x = 20, wa_y = 40, wa_x = -8, rt_y = 720, rt_h = -0.3 })),
		frame(0.86, "quadOut", { rs_x = 70, rs_y = 100, re_x = 14, rw_x = -64, ls_x = 60, ls_y = 54, le_x = 22, wa_y = 62, wa_x = -8, rt_y = 750 }),
		frame(1, "sine", { rt_y = 720 }),
	},
}

-- Заливка (1,1 с; первая волна на 0,36 ≈ waveAt 0,4): клинок двумя руками над головой — вонзить в землю и держать.
A.pourRitual = {
	frames = {
		frame(0, "linear", {}),
		frame(0.26, "quadOut", { rs_x = 176, rs_y = 10, re_x = 20, rw_x = 90, ls_x = 172, ls_y = -10, le_x = 24, wa_x = 14, rt_x = 6, nk_x = -18, rt_h = 0.2 }),
		frame(0.36, "snap", with(CROUCH, { rs_x = 40, rs_y = 6, re_x = 30, rw_x = 100, ls_x = 40, ls_y = -6, le_x = 34, wa_x = -34, rt_x = -20, nk_x = 16, rt_h = -0.7, rk_x = -70, lk_x = -72 })),
		frame(0.86, "linear", with(CROUCH, { rs_x = 42, rs_y = 6, re_x = 28, rw_x = 100, ls_x = 42, ls_y = -6, le_x = 32, wa_x = -30, rt_x = -18, nk_x = 14, rt_h = -0.65, rk_x = -66, lk_x = -68 })),
		frame(1, "sine", {}),
	},
}

-- Строка (0,6 с; письмо 0,25–1,0 ≈ writeAt 0,15 + writeTime 0,45): присед, клинок низко «пишет» вперёд.
A.inscribeWrite = {
	frames = {
		frame(0, "linear", {}),
		frame(0.22, "quadOut", with(CROUCH, { rs_x = 40, rs_y = -30, re_x = 20, rw_x = -60, ls_x = 30, le_x = 40, wa_x = -24, rt_x = -14, nk_x = 12, rt_h = -0.5 })),
		frame(0.5, "sine", with(CROUCH, { rs_x = 30, rs_y = 10, re_x = 10, rw_x = -70, ls_x = 30, le_x = 40, wa_x = -28, wa_y = 10, rt_x = -16, nk_x = 14, rt_h = -0.55 })),
		frame(0.78, "sine", with(CROUCH, { rs_x = 50, rs_y = -10, re_x = 6, rw_x = -84, ls_x = 24, le_x = 40, wa_x = -22, wa_y = -6, rt_x = -12, nk_x = 10, rt_h = -0.45 })),
		frame(1, "sine", {}),
	},
}

-- Опечатать (0,7 с; печать на 0,51 ≈ stampAt 0,36): штемпель над головой — прямо вниз.
A.sealStamp = {
	frames = {
		frame(0, "linear", {}),
		frame(0.36, "quadOut", { rs_x = 172, rs_y = 0, re_x = 40, rw_x = -20, ls_x = 168, le_x = 44, wa_x = 18, rt_x = 8, nk_x = -16, rt_h = 0.25 }),
		frame(0.51, "snap", with(CROUCH, { rs_x = 30, re_x = 4, rw_x = -60, ls_x = 30, le_x = 4, wa_x = -44, rt_x = -22, nk_x = 14, rt_h = -0.55 })),
		frame(0.85, "linear", with(CROUCH, { rs_x = 30, re_x = 6, rw_x = -58, ls_x = 30, le_x = 6, wa_x = -40, rt_x = -20, nk_x = 12 })),
		frame(1, "sine", {}),
	},
}

-- Безвременье (0,8 с; переворот на 0,52 ≈ turnAt 0,42): часы-молот вверх, переворот кистью — рукоять в землю.
A.hourglassTurn = {
	frames = {
		frame(0, "linear", {}),
		frame(0.3, "quadOut", { rs_x = 150, rs_y = 10, re_x = 30, rw_x = -10, ls_x = 140, ls_y = -10, le_x = 40, wa_x = 12, nk_x = -18, rt_h = 0.15 }),
		frame(0.44, "quadInOut", { rs_x = 150, rs_y = 10, re_x = 30, rw_x = 170, ls_x = 140, ls_y = -10, le_x = 40, wa_x = 12, nk_x = -18, rt_h = 0.2 }),
		frame(0.52, "snap", with(CROUCH, { rs_x = 60, rs_y = 6, re_x = 20, rw_x = 160, ls_x = 56, le_x = 24, wa_x = -26, rt_x = -12, nk_x = 10, rt_h = -0.4 })),
		frame(0.86, "linear", with(CROUCH, { rs_x = 58, re_x = 20, rw_x = 158, ls_x = 54, le_x = 24, wa_x = -22, rt_x = -10, nk_x = 8 })),
		frame(1, "sine", {}),
	},
}

-- Разлить чернила (0,6 с; выплеск на 0,5 ≈ splashAt 0,3): широкий мах наотмашь слева направо с разворотом.
A.inkFling = {
	frames = {
		frame(0, "linear", {}),
		frame(0.32, "quadOut", { rs_x = 80, rs_y = 100, re_x = 60, rw_x = -70, wa_y = 54, rt_y = 30, ls_x = 30, ls_y = -30, nk_y = -12 }),
		frame(0.5, "snap", { rs_x = 96, rs_y = -96, re_x = 6, rw_x = -60, wa_y = -64, wa_x = -8, rt_y = -40, rt_x = -8, ls_x = 40, ls_z = -50, lh_x = 22, lk_x = -18, nk_y = 14 }),
		frame(0.8, "quadOut", { rs_x = 90, rs_y = -110, re_x = 10, rw_x = -60, wa_y = -70, wa_x = -6, rt_y = -44, ls_x = 36, ls_z = -46, nk_y = 14 }),
		frame(1, "sine", {}),
	},
}

-- Стереть (0,9 с; взмах на 0,55 ≈ swingAt 0,5): коса далеко за спину — огромный мах на 220°.
A.eraseSweep = {
	frames = {
		frame(0, "linear", {}),
		frame(0.44, "quadOut", { rs_x = 70, rs_y = -120, re_x = 30, rw_x = -70, ls_x = 60, ls_y = -80, le_x = 30, wa_y = -70, rt_y = -60, rt_x = 6, nk_y = 20, rt_h = 0.05 }),
		frame(0.58, "snap", with(CROUCH, { rs_x = 72, rs_y = 110, re_x = 10, rw_x = -66, ls_x = 60, ls_y = 70, le_x = 16, wa_y = 70, wa_x = -12, rt_y = 80, rt_x = -12, nk_y = -16, rt_h = -0.4 })),
		frame(0.86, "quadOut", with(CROUCH, { rs_x = 68, rs_y = 120, re_x = 14, rw_x = -62, ls_x = 56, ls_y = 74, le_x = 20, wa_y = 74, wa_x = -10, rt_y = 90, nk_y = -16, rt_h = -0.3 })),
		frame(1, "sine", {}),
	},
}

-- Вспомнить (0,5 с; призыв на 0,5 ≈ summonAt 0,25): клинок вертикально перед лицом, левая рука в сторону — эхо выходит.
A.recallSummon = {
	frames = {
		frame(0, "linear", {}),
		frame(0.3, "quadOut", { rs_x = 70, rs_y = 34, re_x = 96, rw_x = -6, ls_x = 30, ls_z = -40, le_x = 20, wa_x = 4, nk_x = 6 }),
		frame(0.5, "snap", { rs_x = 74, rs_y = 30, re_x = 96, rw_x = -6, ls_x = 70, ls_z = -80, le_x = 0, wa_x = -6, nk_x = -6, rt_h = 0.1 }),
		frame(0.84, "linear", { rs_x = 72, rs_y = 30, re_x = 94, rw_x = -6, ls_x = 60, ls_z = -70, le_x = 4, wa_x = -4 }),
		frame(1, "sine", {}),
	},
}

-- ===== Способности V2 (переделка 07.11.2026, Systems/WeaponAbilitiesV2) =====

-- Забвение (0,6 с; круг чертится на 0,35 ≈ 0,58): коса заведена за спину — низкий оборот по кругу.
A.eraseCircle = {
	frames = {
		frame(0, "linear", {}),
		frame(0.3, "quadOut", with(CROUCH, { rs_x = 60, rs_y = -100, re_x = 40, rw_x = -70, ls_x = 58, ls_y = -62, le_x = 40, wa_y = -56, rt_y = -40, rt_x = 8, nk_y = 12 })),
		frame(0.62, "quadIn", with(CROUCH, { rs_x = 74, rs_y = 60, re_x = 14, rw_x = -66, ls_x = 62, ls_y = 40, le_x = 20, wa_y = 40, wa_x = -8, rt_y = 280, rt_h = -0.4 })),
		frame(0.8, "snap", with(CROUCH, { rs_x = 72, rs_y = 96, re_x = 12, rw_x = -66, ls_x = 60, ls_y = 52, le_x = 22, wa_y = 60, wa_x = -10, rt_y = 360, rt_h = -0.3 })),
		frame(1, "sine", { rt_y = 360 }),
	},
}

-- Горнило (0,9 с; клинок в землю на 0,4 ≈ 0,45): клинок обеими руками над головой — присед и удар остриём вниз.
A.forgePlunge = {
	frames = {
		frame(0, "linear", {}),
		frame(0.3, "quadOut", { rs_x = 175, rs_y = -10, re_x = 30, rw_x = 60, ls_x = 170, ls_y = 10, le_x = 30, wa_x = 18, rt_x = 8, nk_x = -16, rt_h = 0.15 }),
		frame(0.45, "snap", with(CROUCH, { rs_x = 60, re_x = 4, rw_x = 80, ls_x = 58, le_x = 6, wa_x = -40, rt_x = -20, nk_x = 16, rt_h = -0.7, rk_x = -70, lk_x = -72 })),
		frame(0.85, "linear", with(CROUCH, { rs_x = 58, re_x = 6, rw_x = 78, ls_x = 56, le_x = 8, wa_x = -36, rt_x = -18, nk_x = 14, rt_h = -0.6 })),
		frame(1, "sine", {}),
	},
}

-- Первая отливка (1,6 с; клинок поднят до 0,78, удар на 1,25 ≈ 0,78): клинок над головой
-- «принимает» расплав, затем рубит вперёд всем корпусом.
A.pourRaise = {
	frames = {
		frame(0, "linear", {}),
		frame(0.15, "quadOut", { rs_x = 178, rs_y = 0, re_x = 6, rw_x = 0, ls_x = 60, ls_z = -60, le_x = 10, wa_x = 12, rt_x = 6, nk_x = -24 }),
		frame(0.7, "linear", { rs_x = 180, rs_y = 4, re_x = 4, rw_x = 0, ls_x = 70, ls_z = -70, le_x = 8, wa_x = 16, rt_x = 8, nk_x = -28, rt_h = 0.1 }),
		frame(0.78, "snap", with(CROUCH, { rs_x = 30, re_x = 6, rw_x = -40, ls_x = 30, le_x = 10, wa_x = -44, rt_x = -22, nk_x = 14, rt_h = -0.6, lh_x = 46, lk_x = -40 })),
		frame(0.95, "linear", with(CROUCH, { rs_x = 32, re_x = 8, rw_x = -38, ls_x = 32, le_x = 12, wa_x = -40, rt_x = -20, nk_x = 12 })),
		frame(1, "sine", {}),
	},
}

-- Шлаковый смерч (2,5 с): коса вытянута в стороны, четыре оборота, в конце — коса в землю.
A.slagCyclone = {
	frames = {
		frame(0, "linear", {}),
		frame(0.08, "quadOut", { rs_x = 90, rs_y = 70, re_x = 10, rw_x = -60, ls_x = 80, ls_y = -40, le_x = 20, wa_y = -20, rt_h = -0.2, rt_y = -30 }),
		frame(0.3, "linear", { rs_x = 88, rs_y = 76, re_x = 10, rw_x = -60, ls_x = 80, ls_y = -40, le_x = 20, wa_y = -10, rt_h = -0.2, rt_y = 360 }),
		frame(0.55, "linear", { rs_x = 88, rs_y = 76, re_x = 10, rw_x = -60, ls_x = 80, ls_y = -40, le_x = 20, wa_y = -10, rt_h = -0.25, rt_y = 760 }),
		frame(0.8, "linear", { rs_x = 88, rs_y = 76, re_x = 10, rw_x = -60, ls_x = 80, ls_y = -40, le_x = 20, wa_y = -10, rt_h = -0.25, rt_y = 1160 }),
		frame(0.88, "quadOut", { rs_x = 175, rs_y = 0, re_x = 20, rw_x = 40, ls_x = 165, le_x = 30, wa_x = 18, rt_x = 8, rt_h = 0.15, rt_y = 1440 }),
		frame(0.94, "snap", with(CROUCH, { rs_x = 40, re_x = 6, rw_x = 70, ls_x = 40, le_x = 8, wa_x = -40, rt_x = -20, rt_h = -0.7, rt_y = 1440, rk_x = -70, lk_x = -72 })),
		frame(1, "sine", { rt_y = 1440 }),
	},
}

-- Последний гон (0,4 с; рог на 0,3 ≈ 0,75): левая рука подносит рог ко рту, корпус выгнут.
A.huntHornCall = {
	frames = {
		frame(0, "linear", {}),
		frame(0.4, "quadOut", { ls_x = 120, ls_y = 40, ls_z = -20, le_x = 110, rs_x = 40, rs_y = -30, re_x = 40, rw_x = -60, wa_x = 12, rt_x = 6, nk_x = -20 }),
		frame(0.85, "linear", { ls_x = 124, ls_y = 40, ls_z = -20, le_x = 112, rs_x = 44, rs_y = -30, re_x = 40, rw_x = -60, wa_x = 16, rt_x = 8, nk_x = -26 }),
		frame(1, "sine", {}),
	},
}

PlayerAnimWeapons.Actions = A

-- Способность → { анимация, длительность } для AbilityController.ANIMATIONS (длительность = castTime).
PlayerAnimWeapons.AbilityAnimations = {
	pack = { "packHowl", 0.5 },
	snare = { "snareSlam", 0.75 },
	last_hunt = { "huntHornCall", 0.4 },
	dive = { "falconCall", 0.45 },
	spill = { "crucibleTip", 0.8 },
	overheat = { "overheatFlare", 0.45 },
	anvil_drop = { "anvilCall", 0.6 },
	forge_breath = { "forgePlunge", 0.9 },
	slag_reap = { "slagCyclone", 2.5 },
	pour = { "pourRaise", 1.6 },
	inscribe = { "inscribeWrite", 0.7 },
	seal_time = { "sealStamp", 0.7 },
	timeless = { "hourglassTurn", 0.8 },
	ink_splash = { "inkFling", 0.6 },
	erase = { "eraseCircle", 0.6 },
	recall = { "recallSummon", 0.5 },
}

-- Ключи ног и высоты корпуса (PlayerAnimator добавляет их в KEYS и пишет в суставы бёдер/колен).
PlayerAnimWeapons.LegKeys = { "rh_x", "rk_x", "lh_x", "lk_x", "rt_h" }

return PlayerAnimWeapons
