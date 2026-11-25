--!nonstrict
-- PlayerAnimator (клиент)
-- Процедурные анимации игрока: удары комбо (по типам оружия), парирование,
-- рывок, лечение, способности, получение урона, своя походка и хват оружия.
--
-- Походка (28.10.2026): ноги, взмах свободной руки и покачивание корпуса —
-- свой цикл шага поверх штатной ходьбы (она остаётся только в покое).
-- Правая рука всегда держит оружие сами: в бою — у груди, клинок вперёд;
-- вне боя (CARRY_AFTER с без ударов, парирований, способностей и урона)
-- молоты и мечи закинуты на плечо под углом. Кинжалы и посохи — позже
-- (CARRY по типу оружия).
--
-- Почему кодом, а не KeyframeSequence: анимацию, собранную скриптом, нельзя
-- загрузить в Roblox без Studio и аккаунта автора; процедурная работает у
-- любого игрока сразу. Когда появятся настоящие анимации, достаточно
-- заменить play() — остальной код про позы не знает.
--
-- Как это работает. Каждый кадр после движка анимаций (PreSimulation идёт
-- ПОСЛЕ аниматора и ДО физики) мы переписываем Transform суставов R15
-- (Motor6D или AnimationConstraint — у физического рига):
--   руки    — смешиваем штатный Transform с нашей позой по весу blend;
--   корпус  — добавляем наш поворот поверх штатного (аддитивно).
-- Углы в градусах. Рука R15 висит вниз; +X поднимает её вперёд, +Y ведёт
-- влево, +Z — в сторону. Клинок в руке направлен «вперёд и чуть вверх»
-- (EquipmentService), поэтому суммарный угол rs_x+re_x+rw_x ≈ 0 держит
-- клинок горизонтально вперёд, ≈ 90 — вертикально вверх.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anim = require(Shared.Util.Anim)

-- Маг: серия посоха, хват посоха, барьер, «Покров», позы заклинаний.
local PlayerAnimMage = require(script.Parent.PlayerAnimMage)

local PlayerAnimator = {}

local player = Players.LocalPlayer

-- ===== Хват оружия: доворот вокруг древка =====
-- Косы: полотно висит перпендикулярно древку, поэтому в покое торчит в бок.
-- В покое доворачиваем на WeaponHold.Roll (лезвие к игроку), в замахе — на
-- SwingRoll (полотно боком, «как траву косит»). Сварка GripWeld — обычный Weld,
-- поэтому C0 можно менять плавно, без пересборки модели.
local GRIP_TIME = 0.16 -- сколько длится плавный доворот
local grip = { weld = nil, base = nil, idle = 0, swing = 0, tween = nil }

local function findGripWeld()
	local character = player.Character
	local model = character and character:FindFirstChild("EquippedWeapon")
	local root = model and model.PrimaryPart
	local weld = root and root:FindFirstChild("GripWeld")
	if weld and weld:IsA("Weld") then
		return weld
	end
	return nil
end

local function setGrip(roll: number, time: number)
	local weld = grip.weld
	if not weld or not weld.Parent or not grip.base then
		return
	end
	if grip.tween then
		grip.tween:Cancel()
		grip.tween = nil
	end
	local goal = grip.base * CFrame.Angles(0, math.rad(roll), 0)
	if time <= 0 then
		weld.C0 = goal
		return
	end
	grip.tween = TweenService:Create(
		weld,
		TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ C0 = goal }
	)
	grip.tween:Play()
end

local function bindGrip()
	local weld = findGripWeld()
	if not weld or weld == grip.weld then
		return
	end
	grip.weld = weld
	grip.base = weld:GetAttribute("BaseC0")
	if typeof(grip.base) ~= "CFrame" then
		grip.base = weld.C0
	end
	grip.idle = weld:GetAttribute("IdleRoll") or 0
	grip.swing = weld:GetAttribute("SwingRoll") or grip.idle
	setGrip(grip.idle, 0)
end

-- Держим сварку под наблюдением: оружие пересобирается при каждой смене.
RunService.Heartbeat:Connect(bindGrip)

-- Замах: довернуть оружие в боевое положение и плавно вернуть после серии.
function PlayerAnimator.weaponSwing(weaponId: string?, duration: number)
	bindGrip()
	if not grip.weld or (grip.idle == 0 and grip.swing == 0) then
		return
	end
	setGrip(grip.swing, GRIP_TIME)
	task.delay(math.max((duration or 0.5) * 0.85, 0.1), function()
		setGrip(grip.idle, GRIP_TIME)
	end)
end

-- ===== Кривые =====
-- Кадры нормированы: t от 0 до 1. Ключ, которого нет в кадре, равен нулю.

local function frame(t: number, ease: string, pose)
	local copy = table.clone(pose)
	copy.t = t
	copy.ease = ease
	return copy
end

local Curves = {}

-- Мечи и всё остальное «по умолчанию». Короткий замах (0.16), резкий удар
-- всем телом (разворот бёдер rt_y, наклон rt_x) и долгий «дожим» — удар
-- читается весом, а не одной рукой.
Curves.sword = {
	-- 1: справа налево (горизонтальный).
	{
		frame(0, "linear", {}),
		frame(0.16, "quadOut", { rs_x = 70, rs_y = -82, re_x = 42, rw_x = -82, wa_y = -46, rt_y = -16, ls_x = 25, nk_y = 10 }),
		frame(0.34, "snap", { rs_x = 84, rs_y = 76, re_x = 10, rw_x = -82, wa_y = 52, rt_y = 20, rt_x = -8, ls_x = -36, wa_x = -6, nk_y = -10 }),
		frame(0.62, "quadOut", { rs_x = 74, rs_y = 96, re_x = 18, rw_x = -72, wa_y = 60, rt_y = 24, rt_x = -6, ls_x = -40, nk_y = -10 }),
		frame(1, "sine", {}),
	},
	-- 2: обратный (слева направо), с подшагом.
	{
		frame(0, "linear", {}),
		frame(0.16, "quadOut", { rs_x = 72, rs_y = 86, re_x = 46, rw_x = -86, wa_y = 46, rt_y = 16, ls_x = 22, nk_y = -8 }),
		frame(0.34, "snap", { rs_x = 86, rs_y = -72, re_x = 10, rw_x = -86, wa_y = -54, rt_y = -22, rt_x = -8, ls_x = -32, wa_x = -6, nk_y = 10 }),
		frame(0.62, "quadOut", { rs_x = 76, rs_y = -92, re_x = 15, rw_x = -78, wa_y = -62, rt_y = -26, rt_x = -6, ls_x = -34 }),
		frame(1, "sine", {}),
	},
	-- 3: рубящий сверху в прыжке — финал серии.
	{
		frame(0, "linear", {}),
		frame(0.22, "quadOut", { rs_x = 178, rs_y = -10, re_x = 55, rw_x = -15, wa_x = 20, wa_y = -12, ls_x = 160, le_x = 50, rt_x = 12, nk_x = -12 }),
		frame(0.4, "snap", { rs_x = 22, rs_y = 4, re_x = 8, rw_x = -52, wa_x = -32, wa_y = 6, ls_x = 22, rt_x = -18, nk_x = 12 }),
		frame(0.72, "quadOut", { rs_x = 18, rs_y = 4, re_x = 8, rw_x = -42, wa_x = -34, ls_x = 20, rt_x = -18, nk_x = 10 }),
		frame(1, "sine", {}),
	},
}

Curves.dagger = {
	{
		frame(0, "linear", {}),
		frame(0.18, "quadOut", { rs_x = 45, rs_y = -34, re_x = 105, rw_x = -45, wa_y = -22, ls_x = 25 }),
		frame(0.4, "snap", { rs_x = 88, rs_y = -4, re_x = 6, rw_x = -85, wa_y = 18, wa_x = -10, ls_x = -20 }),
		frame(0.62, "quadOut", { rs_x = 84, rs_y = 2, re_x = 10, rw_x = -80, wa_y = 16, wa_x = -12 }),
		frame(1, "sine", {}),
	},
	{
		frame(0, "linear", {}),
		frame(0.18, "quadOut", { rs_x = 50, rs_y = 30, re_x = 105, rw_x = -45, wa_y = 22, ls_x = 25 }),
		frame(0.4, "snap", { rs_x = 88, rs_y = -10, re_x = 6, rw_x = -85, wa_y = -18, wa_x = -10, ls_x = -20 }),
		frame(0.62, "quadOut", { rs_x = 84, rs_y = -14, re_x = 10, rw_x = -80, wa_y = -16, wa_x = -12 }),
		frame(1, "sine", {}),
	},
	-- Финал: быстрый круговой взмах всем корпусом.
	{
		frame(0, "linear", {}),
		frame(0.2, "quadOut", { rs_x = 70, rs_y = -75, re_x = 30, rw_x = -80, wa_y = -55, ls_x = 30 }),
		frame(0.5, "snap", { rs_x = 80, rs_y = 95, re_x = 10, rw_x = -80, wa_y = 60, rt_y = 70 }),
		frame(0.72, "quadOut", { rs_x = 72, rs_y = 110, re_x = 14, rw_x = -76, wa_y = 62, rt_y = 90 }),
		frame(1, "sine", {}),
	},
}

Curves.hammer = {
	{
		frame(0, "linear", {}),
		frame(0.34, "quadOut", { rs_x = 175, rs_y = -6, re_x = 48, rw_x = -15, wa_x = 20, ls_x = 80, le_x = 40 }),
		frame(0.52, "snap", { rs_x = 26, rs_y = 4, re_x = 10, rw_x = -36, wa_x = -36, ls_x = -20, rt_x = -10 }),
		frame(0.8, "quadOut", { rs_x = 22, rs_y = 4, re_x = 10, rw_x = -34, wa_x = -36, ls_x = -20, rt_x = -10 }),
		frame(1, "sine", {}),
	},
	{
		frame(0, "linear", {}),
		frame(0.34, "quadOut", { rs_x = 70, rs_y = -90, re_x = 28, rw_x = -70, wa_y = -55, ls_x = 30 }),
		frame(0.54, "snap", { rs_x = 80, rs_y = 85, re_x = 12, rw_x = -76, wa_y = 58, wa_x = -8, ls_x = -24 }),
		frame(0.8, "quadOut", { rs_x = 76, rs_y = 100, re_x = 14, rw_x = -72, wa_y = 62, wa_x = -8 }),
		frame(1, "sine", {}),
	},
	{
		frame(0, "linear", {}),
		frame(0.38, "quadOut", { rs_x = 178, rs_y = -4, re_x = 55, rw_x = -10, wa_x = 24, ls_x = 90, le_x = 40 }),
		frame(0.56, "snap", { rs_x = 22, rs_y = 2, re_x = 8, rw_x = -32, wa_x = -40, ls_x = -24, rt_x = -12 }),
		frame(0.82, "quadOut", { rs_x = 18, rs_y = 2, re_x = 8, rw_x = -30, wa_x = -40, ls_x = -24, rt_x = -12 }),
		frame(1, "sine", {}),
	},
}

-- Время (доля кривой), когда клинок проходит перед игроком: отсюда включаем
-- след и вспышку. Совпадает со вторым кадром «snap».
local STRIKE_AT = {
	sword = { 0.25, 0.25, 0.32 },
	dagger = { 0.28, 0.28, 0.36 },
	hammer = { 0.45, 0.45, 0.48 },
}

-- Посох мага (PlayerAnimMage): серия из трёх выбросов снаряда.
Curves.staff = PlayerAnimMage.Curves.staff
STRIKE_AT.staff = PlayerAnimMage.STRIKE_AT.staff

local FLOOR2_STYLES = {
	garden_machete = { typeId = "sword", sweep = 1.14, drive = 1.02, body = 1.08, twist = 1.12 },
	reed_saber = { typeId = "sword", sweep = 0.78, drive = 0.9, body = 0.82, twist = 0.82 },
	mud_mallet = { typeId = "hammer", sweep = 0.88, drive = 1.08, body = 1.12, twist = 0.92 },
	thorn_blade = { typeId = "sword", sweep = 1.02, drive = 0.94, body = 0.9, twist = 0.96 },
	root_hammer = { typeId = "hammer", sweep = 1.04, drive = 1.1, body = 1.08, twist = 1.02 },
	reaper_blade = { typeId = "sword", sweep = 1.28, drive = 1.08, body = 1.08, twist = 1.2 },
	tidal_hammer = { typeId = "hammer", sweep = 1.12, drive = 1.14, body = 1.14, twist = 1.08 },
	gardener_shears = { typeId = "sword", sweep = 0.72, drive = 0.94, body = 0.84, twist = 0.82 },
}

-- Этажи 3–5: почерк, свои серии (косы), моменты удара и способности — PlayerAnimWeapons.
-- (Связка терялась при наложении пакета мага 05.11 — восстановлено 07.11.2026.)
local WeaponAnims = require(script.Parent.PlayerAnimWeapons)
for weaponId, style in pairs(WeaponAnims.Styles) do
	FLOOR2_STYLES[weaponId] = style
end

local FLOOR2_CURVES = {}
for weaponId, style in pairs(FLOOR2_STYLES) do
	local source = Curves[style.typeId]
	local set = {}
	for index, sourceFrames in ipairs(source) do
		local frames = {}
		for frameIndex, sourceFrame in ipairs(sourceFrames) do
			local styled = table.clone(sourceFrame)
			for key, value in pairs(sourceFrame) do
				local scale = nil
				if key == "rs_y" or key == "wa_y" then
					scale = style.sweep
				elseif key == "rt_y" then
					scale = style.twist
				elseif key == "wa_x" or key == "rt_x" or key == "nk_x" then
					scale = style.body
				elseif key == "rs_x" or key == "re_x" or key == "rw_x" or key == "ls_x" or key == "le_x" then
					scale = style.drive
				end
				if scale then
					styled[key] = value * scale
				end
			end
			frames[frameIndex] = styled
		end
		set[index] = frames
	end
	FLOOR2_CURVES[weaponId] = set
end
for weaponId, set in pairs(WeaponAnims.Curves) do
	FLOOR2_CURVES[weaponId] = set
end

local Actions = {}

-- Парирование: рывком поднять клинок перед собой и держать.
Actions.parry = {
	frames = {
		frame(0, "linear", {}),
		frame(0.22, "quadOut", { rs_x = 98, rs_y = 24, re_x = 70, rw_x = -105, wa_y = -12, ls_x = 78, ls_y = -10, le_x = 62, wa_x = 4 }),
		frame(1, "linear", { rs_x = 100, rs_y = 24, re_x = 72, rw_x = -105, wa_y = -12, ls_x = 78, ls_y = -10, le_x = 62, wa_x = 4 }),
	},
}

-- Удачное парирование: резкий отбив вперёд.
Actions.parryHit = {
	frames = {
		frame(0, "linear", { rs_x = 98, rs_y = 24, re_x = 70, rw_x = -105, wa_y = -12, ls_x = 78, le_x = 62 }),
		frame(0.25, "snap", { rs_x = 90, rs_y = -26, re_x = 20, rw_x = -90, wa_y = 22, wa_x = -10, ls_x = 40, le_x = 30 }),
		frame(1, "sine", {}),
	},
}

-- Промах парированием: «просел», пауза штрафа.
Actions.parryFail = {
	frames = {
		frame(0, "linear", {}),
		frame(0.15, "quadOut", { rs_x = -14, re_x = 14, rw_x = 8, wa_x = 16, rt_x = 8, ls_x = -10, nk_x = 10 }),
		frame(0.85, "linear", { rs_x = -10, re_x = 12, rw_x = 6, wa_x = 12, rt_x = 6, ls_x = -8, nk_x = 8 }),
		frame(1, "sine", {}),
	},
}

Actions.dash = {
	frames = {
		frame(0, "linear", {}),
		frame(0.25, "quadOut", { rt_x = -28, rs_x = -45, re_x = 20, ls_x = -45, le_x = 20, wa_x = -10, nk_x = 8 }),
		frame(0.6, "linear", { rt_x = -22, rs_x = -35, ls_x = -35, wa_x = -8 }),
		frame(1, "sine", {}),
	},
}

Actions.heal = {
	frames = {
		frame(0, "linear", {}),
		frame(0.25, "quadOut", { ls_x = 112, le_x = 118, ls_y = -18, nk_x = -14, wa_x = 6 }),
		frame(0.7, "linear", { ls_x = 112, le_x = 118, ls_y = -18, nk_x = -22, wa_x = 4 }),
		frame(1, "sine", {}),
	},
}

-- Вихрь: полный оборот корпуса с вытянутым клинком.
Actions.whirl = {
	frames = {
		frame(0, "linear", {}),
		frame(0.12, "quadOut", { rs_x = 78, rs_y = -30, re_x = 18, rw_x = -82, ls_x = 20, wa_x = -6 }),
		frame(0.8, "quadInOut", { rs_x = 80, rs_y = -30, re_x = 12, rw_x = -80, ls_x = 20, wa_x = -6, rt_y = 720 }),
		frame(1, "sine", { rt_y = 720 }),
	},
}

-- Вихрь-воронка (Вихревой клинок): клинок вытянут, два полных оборота
-- корпуса, к концу — разгон и режущий выброс наружу.
Actions.vortex = {
	frames = {
		frame(0, "linear", {}),
		frame(0.1, "quadOut", { rs_x = 82, rs_y = -40, re_x = 14, rw_x = -84, ls_x = 30, ls_z = -40, wa_x = -8, rt_x = -6 }),
		frame(0.85, "quadIn", { rs_x = 84, rs_y = -36, re_x = 10, rw_x = -84, ls_x = 30, ls_z = -40, wa_x = -8, rt_x = -6, rt_y = 720 }),
		frame(0.92, "snap", { rs_x = 88, rs_y = 70, re_x = 6, rw_x = -86, wa_y = 40, ls_x = -20, rt_y = 760 }),
		frame(1, "sine", { rt_y = 720 }),
	},
}

-- Разлом (Расколотый молот): молот над головой и удар в землю на месте
-- (доля 0.43 при 0.7 с ≈ slamAt 0.3), присед и дожим.
Actions.riftSlam = {
	frames = {
		frame(0, "linear", {}),
		frame(0.32, "quadOut", { rs_x = 178, re_x = 58, rw_x = -10, ls_x = 165, le_x = 52, wa_x = 24, rt_x = 8, nk_x = -12 }),
		frame(0.43, "snap", { rs_x = 18, re_x = 8, rw_x = -36, ls_x = 20, le_x = 10, wa_x = -48, rt_x = -22, nk_x = 14 }),
		frame(0.8, "linear", { rs_x = 20, re_x = 8, rw_x = -34, ls_x = 22, le_x = 10, wa_x = -44, rt_x = -18, nk_x = 12 }),
		frame(1, "sine", {}),
	},
}

-- Отпереть (Ключ Привратника): замах ключом из-за плеча и бросок вперёд
-- (доля 0.33 при 0.6 с ≈ releaseAt 0.2).
Actions.unlockThrow = {
	frames = {
		frame(0, "linear", {}),
		frame(0.2, "quadOut", { rs_x = 150, rs_y = -20, re_x = 70, rw_x = -30, rt_y = -25, ls_x = 40, wa_x = 10, nk_y = 10 }),
		frame(0.33, "snap", { rs_x = 60, rs_y = 10, re_x = 5, rw_x = -60, rt_y = 20, rt_x = -10, ls_x = -20, wa_x = -20, nk_y = -8 }),
		frame(0.7, "quadOut", { rs_x = 40, rs_y = 10, re_x = 10, rw_x = -40, rt_y = 15, rt_x = -6, ls_x = -15 }),
		frame(1, "sine", {}),
	},
}

-- Раскол / удар в землю: оба вверх и вниз.
Actions.slam = {
	frames = {
		frame(0, "linear", {}),
		frame(0.35, "quadOut", { rs_x = 176, re_x = 50, rw_x = -10, ls_x = 150, le_x = 40, wa_x = 24 }),
		frame(0.52, "snap", { rs_x = 24, re_x = 8, rw_x = -32, ls_x = 24, wa_x = -40, rt_x = -12 }),
		frame(0.85, "linear", { rs_x = 20, re_x = 8, rw_x = -30, ls_x = 24, wa_x = -40, rt_x = -12 }),
		frame(1, "sine", {}),
	},
}

Actions.reap = {
	frames = {
		frame(0, "linear", {}),
		frame(0.18, "quadOut", { rs_x = 88, rs_y = -48, re_x = 56, rw_x = -86, wa_y = -32, rt_y = -12, ls_x = 36, nk_y = 8 }),
		frame(0.48, "quadIn", { rs_x = 92, rs_y = -68, re_x = 42, rw_x = -84, wa_y = -38, rt_y = -16, ls_x = 30, nk_y = 10 }),
		frame(0.58, "snap", { rs_x = 78, rs_y = 84, re_x = 16, rw_x = -78, wa_y = 62, rt_y = 28, rt_x = -8, ls_x = -34, nk_y = -10 }),
		frame(0.82, "quadOut", { rs_x = 72, rs_y = 94, re_x = 18, rw_x = -70, wa_y = 66, rt_y = 30, ls_x = -38, nk_y = -10 }),
		frame(1, "sine", {}),
	},
}

Actions.flood = {
	frames = {
		frame(0, "linear", {}),
		frame(0.3, "quadOut", { rs_x = 178, rs_y = -8, re_x = 56, rw_x = -12, ls_x = 160, le_x = 48, wa_x = 22, rt_x = 8, nk_x = -10 }),
		frame(0.48, "snap", { rs_x = 20, rs_y = 4, re_x = 8, rw_x = -32, ls_x = 22, le_x = 8, wa_x = -50, rt_x = -22, nk_x = 14 }),
		frame(0.76, "linear", { rs_x = 22, rs_y = 4, re_x = 8, rw_x = -30, ls_x = 24, wa_x = -44, rt_x = -18, nk_x = 12 }),
		frame(1, "sine", {}),
	},
}

Actions.prune = {
	frames = {
		frame(0, "linear", {}),
		frame(0.2, "quadOut", { rs_x = 76, rs_y = -34, re_x = 60, rw_x = -68, ls_x = 70, ls_y = 34, le_x = 56, wa_y = -8, rt_y = -10 }),
		frame(0.4, "snap", { rs_x = 74, rs_y = 80, re_x = 16, rw_x = -80, ls_x = 78, ls_y = -72, le_x = 14, wa_y = 42, rt_y = 18, ls_z = -18 }),
		frame(0.68, "snap", { rs_x = 78, rs_y = -76, re_x = 14, rw_x = -82, ls_x = 72, ls_y = 82, le_x = 14, wa_y = -48, rt_y = -20, ls_z = 18 }),
		frame(0.86, "quadOut", { rs_x = 72, rs_y = -82, re_x = 18, rw_x = -74, ls_x = 68, ls_y = 88, le_x = 18, wa_y = -52, rt_y = -22 }),
		frame(1, "sine", {}),
	},
}

-- Выпад клинком вперёд (линия, звёздный залп, «Приговор»).
Actions.thrust = {
	frames = {
		frame(0, "linear", {}),
		frame(0.3, "quadOut", { rs_x = 55, rs_y = -20, re_x = 100, rw_x = -60, wa_y = -20, ls_x = 30 }),
		frame(0.5, "snap", { rs_x = 90, rs_y = 0, re_x = 4, rw_x = -88, wa_y = 14, wa_x = -14, ls_x = -20 }),
		frame(0.85, "linear", { rs_x = 88, rs_y = 0, re_x = 6, rw_x = -86, wa_y = 14, wa_x = -14 }),
		frame(1, "sine", {}),
	},
}

-- Барьер: руки скрещены перед собой.
Actions.barrier = {
	frames = {
		frame(0, "linear", {}),
		frame(0.3, "quadOut", { rs_x = 85, rs_y = 40, re_x = 100, rw_x = -20, ls_x = 85, ls_y = -40, le_x = 100, wa_x = 8 }),
		frame(0.8, "linear", { rs_x = 85, rs_y = 40, re_x = 100, rw_x = -20, ls_x = 85, ls_y = -40, le_x = 100, wa_x = 8 }),
		frame(1, "sine", {}),
	},
}

Actions.hurt = {
	frames = {
		frame(0, "linear", {}),
		frame(0.15, "snap", { wa_x = 18, rt_x = 8, nk_x = 14, rs_x = -18, ls_x = -18 }),
		frame(1, "sine", {}),
	},
	additive = true,
}

for name, action in pairs(WeaponAnims.Actions) do
	Actions[name] = action
end

-- Действия мага (барьер, покров, заклинания) — из PlayerAnimMage.
for name, action in pairs(PlayerAnimMage.Actions) do
	Actions[name] = action
end

-- ===== Хват оружия и походка =====

-- Правая рука без действия. ready — в бою, shoulder — на плече вне боя.
local HOLD = {
	ready = { rs_x = 28, rs_y = 8, rs_z = 0, re_x = 52, rw_x = -42 },
	shoulder = { rs_x = 40, rs_y = 0, rs_z = 15, re_x = 105, rw_x = 0 },
}
-- Какие типы оружия носят на плече (кинжалам и посохам — свой хват позже).
local CARRY = { sword = true, hammer = true }
local CARRY_AFTER = 2.0 -- секунд без боя до «на плечо»

local WALK = {
	stride = 6.5, -- стадов на полный цикл шага (два шага)
	hip = 34, -- размах бедра, градусы (на беге)
	knee = 58, -- сгиб колена в выносе ноги
	ankle = 14,
	arm = 30, -- взмах свободной руки
	twist = 7, -- поворот корпуса навстречу шагу
	bob = 0.18, -- вертикальная «пружина» корпуса, стады
}

-- ===== Состояние =====

local KEYS = {
	"rs_x", "rs_y", "rs_z", "re_x", "rw_x",
	"ls_x", "ls_y", "ls_z", "le_x", "lw_x",
	"wa_x", "wa_y", "wa_z", "rt_x", "rt_y", "nk_x", "nk_y",
}
-- Ноги и высота корпуса в действиях (выпады, приседы): rh_x, rk_x, lh_x, lk_x, rt_h.
for _, key in ipairs(WeaponAnims.LegKeys) do
	table.insert(KEYS, key)
end
local LEG_KEYS = { rh_x = true, rk_x = true, lh_x = true, lk_x = true, rt_h = true }

-- Есть ли у кадров действия ключи ног: только тогда действие перехватывает ноги у походки.
local function framesUseLegs(frames): boolean
	for _, f in ipairs(frames) do
		for key in pairs(f) do
			if LEG_KEYS[key] then
				return true
			end
		end
	end
	return false
end

local runtime = {
	joints = {},
	action = nil, -- { frames, t, duration, hold, additive, name }
	overlay = nil, -- отдельный слой для вспышки удара
	carry = {}, -- поза предыдущего действия для плавного перехода
	carryTime = 0,
	blend = 0,
	frozen = 0,
	pose = {},
	last = {},
	combo = 0,
	listeners = {},
	rootPosition = nil,
	speed = 0,
	clock = 0,
	combatAt = -100, -- когда было последнее боевое действие (часы runtime.clock)
	shoulder = 0, -- 0 — хват в бою, 1 — на плече
	phase = 0, -- фаза шага
	walk = 0, -- вес своей походки (0 — стоим)
	legs = {},
	legBlend = 0, -- вес ног действия (0 — ноги у походки/штатной анимации)
}

-- Сустав по имени. В новых аватарах Roblox суставы R15 — AnimationConstraint
-- (физический риг), в старых — Motor6D; у обоих есть Transform, поэтому
-- позы пишутся одинаково. Раньше искался только Motor6D, и на физическом
-- риге анимации ударов не играли вовсе.
local function jointOf(character, name: string)
	for _, descendant in ipairs(character:GetDescendants()) do
		if (descendant:IsA("Motor6D") or descendant:IsA("AnimationConstraint")) and descendant.Name == name then
			return descendant
		end
	end
	return nil
end

local function bindCharacter(character)
	runtime.joints = {
		rs = jointOf(character, "RightShoulder"),
		re = jointOf(character, "RightElbow"),
		rw = jointOf(character, "RightWrist"),
		ls = jointOf(character, "LeftShoulder"),
		le = jointOf(character, "LeftElbow"),
		lw = jointOf(character, "LeftWrist"),
		wa = jointOf(character, "Waist"),
		rt = jointOf(character, "Root"),
		nk = jointOf(character, "Neck"),
	}
	runtime.legs = {
		rh = jointOf(character, "RightHip"),
		rk = jointOf(character, "RightKnee"),
		ra = jointOf(character, "RightAnkle"),
		lh = jointOf(character, "LeftHip"),
		lk = jointOf(character, "LeftKnee"),
		la = jointOf(character, "LeftAnkle"),
	}
	runtime.action = nil
	runtime.blend = 0
	runtime.carry = {}
	runtime.rootPosition = nil
end

local function emit(name: string, data)
	for _, listener in ipairs(runtime.listeners) do
		task.spawn(listener, name, data)
	end
end

function PlayerAnimator.onEvent(listener)
	table.insert(runtime.listeners, listener)
end

local function start_(name: string, frames, duration: number, extra)
	-- Запоминаем позу, из которой уходим, чтобы не было «щелчка».
	runtime.carry = table.clone(runtime.last)
	runtime.carryTime = 0.09
	runtime.action = {
		name = name,
		frames = frames,
		t = 0,
		duration = math.max(duration, 0.05),
		additive = extra and extra.additive or false,
		legs = framesUseLegs(frames),
	}
end

-- Удар комбо. duration — время серии до следующего удара.
function PlayerAnimator.attack(combo: number, duration: number, typeId: string, weaponId: string?)
	runtime.combatAt = runtime.clock
	local set = (weaponId and FLOOR2_CURVES[weaponId]) or Curves[typeId] or Curves.sword
	local index = ((combo - 1) % #set) + 1
	runtime.combo = index
	start_("attack", set[index], duration * 1.15, nil)
	local strikeAt = ((weaponId and WeaponAnims.StrikeAt[weaponId]) or STRIKE_AT[typeId] or STRIKE_AT.sword)[index]
	emit("attack", {
		combo = index,
		duration = duration * 1.15,
		typeId = typeId,
		weaponId = weaponId,
		strikeDelay = duration * 1.15 * strikeAt,
	})
	-- Косы: в замахе полотно идёт боком, в покое — развёрнуто к игроку.
	PlayerAnimator.weaponSwing(weaponId, duration * 1.15)
end

function PlayerAnimator.play(name: string, duration: number?)
	-- С посохом парирование — барьер мага.
	if PlayerAnimMage.REMAP[name] and player:GetAttribute("WeaponType") == "staff" then
		name = PlayerAnimMage.REMAP[name]
	end
	local action = Actions[name]
	if not action then
		return
	end
	runtime.combatAt = runtime.clock
	if action.additive then
		-- Реакция на урон ложится поверх текущего действия.
		runtime.overlay = { frames = action.frames, t = 0, duration = duration or 0.35 }
		return
	end
	start_(name, action.frames, duration or 0.5, action)
	emit(name, { duration = duration })
end

-- Удержать позу (парирование): длительность окна.
function PlayerAnimator.stop()
	runtime.action = nil
end

function PlayerAnimator.current(): string?
	return runtime.action and runtime.action.name or nil
end

-- Микро-пауза при попадании: анимация замирает на пару кадров.
function PlayerAnimator.hitStop(duration: number)
	runtime.frozen = math.max(runtime.frozen, duration)
end

-- ===== Применение к суставам =====

local function rad(value: number?): number
	return math.rad(value or 0)
end

local function armCFrame(x, y, z)
	return CFrame.Angles(0, rad(y), 0) * CFrame.Angles(rad(x), 0, rad(z))
end

local function bodyCFrame(pose, scale: number)
	return CFrame.Angles(0, rad(pose.wa_y) * scale, 0)
		* CFrame.Angles(rad(pose.wa_x) * scale, 0, rad(pose.wa_z) * scale)
end

-- Движок не всегда переписывает Transform каждый кадр (сустав без ключей
-- остаётся как мы его оставили). Поэтому помним базу: если Transform равен
-- тому, что записали мы, считаем базой прежнюю, иначе — то, что дал движок.
local records = setmetatable({}, { __mode = "k" })

local function write(joint, compute)
	if not joint or not joint.Parent then
		return
	end
	local current = joint.Transform
	local record = records[joint]
	local base = current
	if record and record.written == current then
		base = record.base
	end
	joint.Transform = compute(base)
	records[joint] = { base = base, written = joint.Transform }
end

local function applyPose(pose, additivePose, blend: number, locomotion)
	local joints = runtime.joints

	-- Руки: поверх штатной анимации, по весу (без веса базу всё равно
	-- восстанавливаем, иначе рука застынет в последней позе).
	local function arm(joint, x, y, z, weight)
		write(joint, function(base)
			if weight <= 0.002 then
				return base
			end
			return base:Lerp(armCFrame(x, y, z), weight)
		end)
	end
	-- Правая рука всегда наша: хват (у груди / на плече), в действии — поза удара.
	local hold = locomotion.hold
	local function right(key)
		local h = hold[key] or 0
		return h + ((pose[key] or 0) - h) * blend
	end
	arm(joints.rs, right("rs_x"), right("rs_y"), right("rs_z"), 1)
	arm(joints.re, right("re_x"), 0, 0, 1)
	arm(joints.rw, right("rw_x"), 0, 0, 1)
	-- Левая: в действии — поза, иначе взмах в такт шагу.
	local swing = locomotion.leftSwing
	local leftWeight = math.max(blend, locomotion.walk)
	local function left(key, walkValue)
		if leftWeight <= 0.002 then
			return 0
		end
		return ((pose[key] or 0) * blend + walkValue * (1 - blend) * locomotion.walk) / leftWeight
	end
	arm(joints.ls, left("ls_x", swing), left("ls_y", 0), left("ls_z", -6), leftWeight)
	arm(joints.le, left("le_x", 18 + math.max(swing, 0) * 0.6), 0, 0, leftWeight)
	arm(joints.lw, left("lw_x", 0), 0, 0, leftWeight)

	-- Ноги: свой шаг поверх штатной ходьбы (в покое — штатная).
	-- Действие с ключами ног (выпад, присед) смешивается с шагом по весу legBlend.
	local legs = runtime.legs
	local actionLegs = blend * runtime.legBlend
	local legWeight = math.max(locomotion.walk, actionLegs)
	local function leg(joint, walkAngle, key)
		write(joint, function(base)
			if legWeight <= 0.002 then
				return base
			end
			local actionAngle = key and (pose[key] or 0) or 0
			local angle = (walkAngle * locomotion.walk * (1 - actionLegs) + actionAngle * actionLegs) / legWeight
			return base:Lerp(CFrame.Angles(rad(angle), 0, 0), legWeight)
		end)
	end
	local stepPose = locomotion.legs
	leg(legs.rh, stepPose.rh, "rh_x")
	leg(legs.rk, stepPose.rk, "rk_x")
	leg(legs.ra, stepPose.ra, nil)
	leg(legs.lh, stepPose.lh, "lh_x")
	leg(legs.lk, stepPose.lk, "lk_x")
	leg(legs.la, stepPose.la, nil)

	-- Корпус и голова: аддитивно (штатная ходьба сохраняется).
	write(joints.wa, function(base)
		return base * bodyCFrame(pose, blend) * bodyCFrame(additivePose, 1) * locomotion.waist
	end)
	write(joints.rt, function(base)
		-- Разворот корпуса сводим к −180…180: оборот на 360/1440 (смерч, финал косы) на выходе
		-- из действия не «раскручивается» обратно, пока гаснет вес позы.
		local yaw = ((pose.rt_y or 0) + 180) % 360 - 180
		local rootExtra = CFrame.Angles(rad(pose.rt_x) * blend + rad(additivePose.rt_x), rad(yaw) * blend, 0)
		local lift = CFrame.new(0, (pose.rt_h or 0) * blend, 0)
		return base * lift * rootExtra * locomotion.root
	end)
	write(joints.nk, function(base)
		return base * CFrame.Angles(rad(pose.nk_x) * blend + rad(additivePose.nk_x), rad(pose.nk_y) * blend, 0)
	end)
end

local sampled = {}
local overlayPose = {}

local function sampleAction(action): ()
	local normalized = math.clamp(action.t / action.duration, 0, 1)
	Anim.sample(action.frames, normalized, sampled)
end

local function step(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		runtime.action = nil
		runtime.blend = 0
		return
	end
	if not runtime.joints.rs or not runtime.joints.rs.Parent then
		bindCharacter(character)
	end

	runtime.clock += dt

	-- Скорость персонажа для наклона при беге.
	local position = root.Position
	if runtime.rootPosition then
		local flat = Vector3.new(position.X - runtime.rootPosition.X, 0, position.Z - runtime.rootPosition.Z)
		local speed = flat.Magnitude / math.max(dt, 1e-3)
		runtime.speed = Anim.damp(runtime.speed, speed, 12, dt)
	end
	runtime.rootPosition = position

	-- Время действия: замирает во время hitStop.
	local action = runtime.action
	local advance = dt
	if runtime.frozen > 0 then
		runtime.frozen -= dt
		advance = 0
	end

	for _, key in ipairs(KEYS) do
		overlayPose[key] = 0
	end

	local pose = sampled
	if action then
		action.t += advance
		sampleAction(action)
		if action.t >= action.duration then
			runtime.action = nil
		end
	else
		for key in pairs(pose) do
			pose[key] = nil
		end
	end

	-- Плавный выход из предыдущей позы.
	if runtime.carryTime > 0 and action then
		local k = 1 - runtime.carryTime / 0.09
		for _, key in ipairs(KEYS) do
			local from = runtime.carry[key] or 0
			local to = pose[key] or 0
			pose[key] = from + (to - from) * math.clamp(k, 0, 1)
		end
		runtime.carryTime -= dt
	end

	-- Вес: действие включает, отсутствие действия плавно выключает.
	local targetBlend = action and 1 or 0
	runtime.blend = Anim.damp(runtime.blend, targetBlend, targetBlend == 1 and 40 or 16, dt)
	local legTarget = (action and action.legs) and 1 or 0
	runtime.legBlend = Anim.damp(runtime.legBlend, legTarget, legTarget == 1 and 30 or 12, dt)

	-- Слой реакции на урон.
	if runtime.overlay then
		local overlay = runtime.overlay
		overlay.t += dt
		local normalized = math.clamp(overlay.t / overlay.duration, 0, 1)
		Anim.sample(overlay.frames, normalized, overlayPose)
		if normalized >= 1 then
			runtime.overlay = nil
		end
	end

	-- Запоминаем итоговую позу для переходов.
	for _, key in ipairs(KEYS) do
		runtime.last[key] = (pose[key] or 0) * runtime.blend
	end

	-- Своя походка: фаза шага по пройденному пути, вес — от скорости
	-- (в воздухе шаг замирает, рывок не «семенит»).
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local walkTarget = grounded and math.clamp((runtime.speed - 0.6) / 3, 0, 1) or 0
	runtime.walk = Anim.damp(runtime.walk, walkTarget, 10, dt)
	local run = math.clamp(runtime.speed / 16, 0.35, 1.15)
	if grounded then
		runtime.phase = (runtime.phase + runtime.speed * dt / WALK.stride * math.pi * 2) % (math.pi * 2)
	end
	local s = math.sin(runtime.phase)
	local c = math.cos(runtime.phase)
	local hip = WALK.hip * run
	-- Колено сгибается, когда нога идёт вперёд (выносится), и почти прямое на опоре.
	local kneeR = WALK.knee * run * math.max(0, c) ^ 1.5
	local kneeL = WALK.knee * run * math.max(0, -c) ^ 1.5
	local legsPose = {
		rh = hip * s,
		rk = -kneeR,
		ra = WALK.ankle * run * (s < 0 and -s or s * 0.3),
		lh = -hip * s,
		lk = -kneeL,
		la = WALK.ankle * run * (s > 0 and s or -s * 0.3),
	}

	-- Хват: вне боя (и если тип оружия носят на плече) — на плечо.
	local typeId = player:GetAttribute("WeaponType") or "sword"
	local calm = CARRY[typeId] and (runtime.clock - runtime.combatAt) > CARRY_AFTER and not action
	runtime.shoulder = Anim.damp(runtime.shoulder, calm and 1 or 0, calm and 5 or 14, dt)
	-- Только Studio: почему меч не уходит на плечо (проверка хвата).
	if RunService:IsStudio() then
		player:SetAttribute("AnimShoulder", math.floor(runtime.shoulder * 100) / 100)
		player:SetAttribute("AnimCalm", calm)
		player:SetAttribute("AnimAction", action and 1 or 0)
		player:SetAttribute("AnimIdleFor", math.floor((runtime.clock - runtime.combatAt) * 10) / 10)
	end
	local hold = {}
	local shoulderPose = HOLD.shoulder
	-- Только Studio: подбор позы атрибутом DebugHold «rs_x,rs_y,rs_z,re_x,rw_x».
	local debugHold = RunService:IsStudio() and player:GetAttribute("DebugHold")
	if type(debugHold) == "string" then
		local v = string.split(debugHold, ",")
		shoulderPose = { rs_x = tonumber(v[1]), rs_y = tonumber(v[2]), rs_z = tonumber(v[3]), re_x = tonumber(v[4]), rw_x = tonumber(v[5]) }
	end
	-- Посох держат вертикально у плеча (на плечо не закидывают: CARRY без staff).
	local readyPose = typeId == "staff" and PlayerAnimMage.HOLD_STAFF or HOLD.ready
	for key, value in pairs(readyPose) do
		local target = shoulderPose[key] or 0
		hold[key] = value + (target - value) * runtime.shoulder
	end
	-- Оружие в руке при ходьбе чуть покачивается с шагом, а не болтается.
	hold.rs_x += s * 4 * runtime.walk * (1 - runtime.shoulder)

	-- Наклон при беге, пружина шага и дыхание.
	local lean = math.clamp(runtime.speed / 24, 0, 1)
	local breath = math.sin(runtime.clock * 2.2) * 1.2
	local bob = -math.abs(c) * WALK.bob * runtime.walk
	local locomotion = {
		root = CFrame.new(0, bob, 0) * CFrame.Angles(-rad(lean * 9), 0, 0),
		waist = CFrame.Angles(rad(breath) * (1 - lean), rad(WALK.twist) * s * runtime.walk, 0),
		hold = hold,
		walk = runtime.walk,
		leftSwing = WALK.arm * run * s,
		legs = legsPose,
	}

	applyPose(pose, overlayPose, runtime.blend, locomotion)
end

function PlayerAnimator.start()
	local function onCharacter(character)
		character:WaitForChild("Humanoid")
		task.wait(0.1)
		bindCharacter(character)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	-- Пишем позы ПОСЛЕ штатного аниматора и ДО физики. На физическом риге
	-- (AnimationConstraint) поза берётся симуляцией, поэтому запись в
	-- Heartbeat (после физики) жила один кадр и затиралась аниматором.
	-- Для Motor6D PreSimulation тоже годится: рендер идёт после него.
	local ok = pcall(function()
		RunService.PreSimulation:Connect(step)
	end)
	if not ok then
		RunService.Heartbeat:Connect(step)
	end
	print("[PlayerAnimator] процедурные анимации игрока запущены")
end

return PlayerAnimator
