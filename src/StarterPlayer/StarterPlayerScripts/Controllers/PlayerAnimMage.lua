--!nonstrict
-- PlayerAnimMage (клиент, модуль без start)
-- Процедурные анимации мага для PlayerAnimator: серия посоха (3 удара), хват посоха
-- вертикально у плеча, барьер вместо парирования, «Покров» и пять поз заклинаний.
-- PlayerAnimator подмешивает отсюда Curves.staff, STRIKE_AT.staff и Actions; при
-- WeaponType == "staff" парирование подменяется барьером (REMAP), а AbilityController
-- берёт анимацию заклинания по SPELL_ANIM.
--
-- Углы как в PlayerAnimator: rs_x+re_x+rw_x ≈ 90 — посох вертикально, ≈ 0 — навершием вперёд.

local PlayerAnimMage = {}

local function frame(t: number, ease: string, pose)
	local copy = table.clone(pose)
	copy.t = t
	copy.ease = ease
	return copy
end

-- ===== Серия посоха =====
-- Удар — это выброс снаряда с навершия: момент «snap» совпадает с вылетом
-- (LootMage.StrikeAt = 0.3 / 0.3 / 0.42).
PlayerAnimMage.Curves = {
	staff = {
		-- 1: выпад-указание — навершие рывком вперёд на цель.
		{
			frame(0, "linear", {}),
			frame(0.18, "quadOut", { rs_x = 40, rs_y = 12, re_x = 96, rw_x = -22, wa_y = -18, rt_y = -8, ls_x = 22, nk_y = 6 }),
			frame(0.3, "snap", { rs_x = 94, rs_y = -6, re_x = 4, rw_x = -72, wa_y = 14, rt_y = 10, rt_x = -6, ls_x = -20, nk_y = -6 }),
			frame(0.62, "quadOut", { rs_x = 86, rs_y = -4, re_x = 10, rw_x = -66, wa_y = 12, rt_y = 8, ls_x = -16 }),
			frame(1, "sine", {}),
		},
		-- 2: боковой взмах — посох описывает дугу справа налево.
		{
			frame(0, "linear", {}),
			frame(0.16, "quadOut", { rs_x = 70, rs_y = -72, re_x = 40, rw_x = -60, wa_y = -40, rt_y = -14, ls_x = 26, nk_y = 8 }),
			frame(0.3, "snap", { rs_x = 82, rs_y = 62, re_x = 12, rw_x = -70, wa_y = 44, rt_y = 18, rt_x = -6, ls_x = -30, nk_y = -8 }),
			frame(0.62, "quadOut", { rs_x = 74, rs_y = 78, re_x = 16, rw_x = -64, wa_y = 50, rt_y = 20, ls_x = -34, nk_y = -8 }),
			frame(1, "sine", {}),
		},
		-- 3: над головой двумя руками — и удар навершием вперёд-вниз.
		{
			frame(0, "linear", {}),
			frame(0.28, "quadOut", { rs_x = 170, rs_y = -4, re_x = 30, rw_x = -22, wa_x = 16, ls_x = 150, le_x = 30, nk_x = -8 }),
			frame(0.42, "snap", { rs_x = 72, rs_y = 4, re_x = 4, rw_x = -52, wa_x = -26, rt_x = -10, ls_x = 40, le_x = 20 }),
			frame(0.75, "quadOut", { rs_x = 66, rs_y = 2, re_x = 6, rw_x = -48, wa_x = -24, rt_x = -8, ls_x = 30, le_x = 16 }),
			frame(1, "sine", {}),
		},
	},
}

PlayerAnimMage.STRIKE_AT = {
	staff = { 0.3, 0.3, 0.42 },
}

-- Хват в бою: посох вертикально у правого плеча (сумма углов ≈ 90).
PlayerAnimMage.HOLD_STAFF = { rs_x = 22, rs_y = 6, rs_z = 10, re_x = 62, rw_x = 6 }

-- ===== Действия =====
local BARRIER_POSE = { rs_x = 62, rs_y = 30, re_x = 40, rw_x = -12, ls_x = 92, ls_y = -18, le_x = 10, lw_x = -30, wa_y = -8, nk_x = -4 }

PlayerAnimMage.Actions = {
	-- Барьер: посох вертикально перед собой, левая ладонь вперёд — держать окно.
	staffBarrier = {
		frames = {
			frame(0, "linear", {}),
			frame(0.2, "quadOut", BARRIER_POSE),
			frame(1, "linear", BARRIER_POSE),
		},
	},
	-- Удачный барьер: толчок обеими руками — волна отбрасывает врагов.
	staffBarrierHit = {
		frames = {
			frame(0, "linear", BARRIER_POSE),
			frame(0.25, "snap", { rs_x = 96, rs_y = 10, re_x = 0, rw_x = -8, ls_x = 104, ls_y = -10, le_x = 0, lw_x = -40, wa_x = -10, wa_y = 6, rt_x = -6 }),
			frame(1, "sine", {}),
		},
	},
	-- Промах барьером (или нет маны): посох проседает, маг сгибается.
	staffBarrierFail = {
		frames = {
			frame(0, "linear", {}),
			frame(0.15, "quadOut", { rs_x = -8, re_x = 34, rw_x = 10, wa_x = 18, rt_x = 8, ls_x = -10, nk_x = 12 }),
			frame(0.85, "linear", { rs_x = -6, re_x = 30, rw_x = 8, wa_x = 14, rt_x = 6, ls_x = -8, nk_x = 10 }),
			frame(1, "sine", {}),
		},
	},
	-- Покров: левая рука накидывает капюшон-тень, маг пригибается.
	veil = {
		frames = {
			frame(0, "linear", {}),
			frame(0.25, "quadOut", { ls_x = 124, ls_y = -30, le_x = 110, lw_x = -20, rs_x = 30, re_x = 58, rw_x = 2, wa_x = 12, rt_x = 6, nk_x = 12 }),
			frame(0.7, "linear", { ls_x = 116, ls_y = -26, le_x = 104, lw_x = -18, rs_x = 28, re_x = 58, rw_x = 4, wa_x = 10, rt_x = 6, nk_x = 10 }),
			frame(1, "sine", {}),
		},
	},
	-- Посох вверх над головой (небесные заклинания: луна, метеоры, молния).
	castRaise = {
		frames = {
			frame(0, "linear", {}),
			frame(0.35, "quadOut", { rs_x = 166, rs_y = -6, re_x = 10, rw_x = -82, ls_x = 62, ls_y = -16, le_x = 40, wa_x = 12, nk_x = -16 }),
			frame(0.8, "linear", { rs_x = 170, rs_y = -6, re_x = 8, rw_x = -82, ls_x = 70, ls_y = -16, le_x = 36, wa_x = 14, nk_x = -18 }),
			frame(1, "sine", {}),
		},
	},
	-- Замах и удар пяткой посоха в землю (круги у ног).
	castSlam = {
		frames = {
			frame(0, "linear", {}),
			frame(0.35, "quadOut", { rs_x = 150, rs_y = -4, re_x = 20, rw_x = -60, ls_x = 60, le_x = 30, wa_x = 12, nk_x = -10 }),
			frame(0.5, "snap", { rs_x = 44, rs_y = 10, re_x = 40, rw_x = 6, wa_x = -22, rt_x = -8, ls_x = -12, nk_x = 6 }),
			frame(0.85, "linear", { rs_x = 42, rs_y = 10, re_x = 40, rw_x = 8, wa_x = -20, rt_x = -8, ls_x = -10, nk_x = 6 }),
			frame(1, "sine", {}),
		},
	},
	-- Навершие вперёд на цель, левая рука направляет (лучи, маяки, броски).
	castPoint = {
		frames = {
			frame(0, "linear", {}),
			frame(0.3, "quadOut", { rs_x = 40, rs_y = 10, re_x = 92, rw_x = -20, wa_y = -16, ls_x = 30, nk_y = 6 }),
			frame(0.45, "snap", { rs_x = 96, rs_y = -4, re_x = 2, rw_x = -80, wa_y = 12, rt_x = -6, ls_x = 72, ls_y = -22, le_x = 20, lw_x = -20 }),
			frame(0.85, "linear", { rs_x = 94, rs_y = -4, re_x = 4, rw_x = -80, wa_y = 12, rt_x = -6, ls_x = 70, ls_y = -22, le_x = 20, lw_x = -20 }),
			frame(1, "sine", {}),
		},
	},
	-- Широкий горизонтальный взмах (споры, веер).
	castSweep = {
		frames = {
			frame(0, "linear", {}),
			frame(0.25, "quadOut", { rs_x = 70, rs_y = -82, re_x = 30, rw_x = -70, wa_y = -44, rt_y = -14, ls_x = 30 }),
			frame(0.5, "snap", { rs_x = 80, rs_y = 82, re_x = 10, rw_x = -70, wa_y = 50, rt_y = 20, ls_x = -30 }),
			frame(0.85, "linear", { rs_x = 78, rs_y = 86, re_x = 12, rw_x = -68, wa_y = 50, rt_y = 20, ls_x = -30 }),
			frame(1, "sine", {}),
		},
	},
	-- Долгое заклинание: посох перед собой, левая рука вверх, корпус откинут.
	castChannel = {
		frames = {
			frame(0, "linear", {}),
			frame(0.25, "quadOut", { rs_x = 110, rs_y = 10, re_x = 20, rw_x = -40, ls_x = 112, ls_y = -22, le_x = 20, lw_x = -20, wa_x = 8, nk_x = -10 }),
			frame(0.85, "linear", { rs_x = 118, rs_y = 10, re_x = 18, rw_x = -42, ls_x = 124, ls_y = -22, le_x = 16, lw_x = -20, wa_x = 12, nk_x = -14 }),
			frame(1, "sine", {}),
		},
	},
}

-- При посохе в руке парирование — это барьер.
PlayerAnimMage.REMAP = {
	parry = "staffBarrier",
	parryHit = "staffBarrierHit",
	parryFail = "staffBarrierFail",
}

-- Анимация заклинания по id способности (AbilityController).
PlayerAnimMage.SPELL_ANIM = {
	ward_circle = "castSlam",
	signal_fire = "castPoint",
	light_gate = "castPoint",
	lotus_bloom = "castSlam",
	mycelium = "castSweep",
	thorn_garden = "castSlam",
	spirit_pack = "castPoint",
	hunters_moon = "castRaise",
	royal_hunt = "castSweep",
	fire_rain = "castRaise",
	forged_lightning = "castRaise",
	forge_heart = "castSlam",
	meteor = "castRaise",
	first_cast = "castChannel",
	open_tome = "castRaise",
	time_stop = "castSlam",
	fate_line = "castPoint",
	ink_hole = "castPoint",
	total_recall = "castChannel",
	veil = "veil",
}

function PlayerAnimMage.isStaff(typeId): boolean
	return typeId == "staff"
end

return PlayerAnimMage
