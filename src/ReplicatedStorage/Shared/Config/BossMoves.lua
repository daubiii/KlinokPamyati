--!nonstrict
-- Config/BossMoves — фирменные атаки боссов: по две на босса, каждая — про
-- свой этаж (решение Артёма: «атаки, хорошо проработанные визуально»; урон —
-- черновой, ребаланс позже).
--
--   этаж 1  Привратник       «Решётки Хранилища» (I)   «Поворот ключа» (II)
--   этаж 2  Садовница        «Половодье» (I)           «Мраморный взгляд» (II)
--   этаж 3  Королевский ловчий «Королевская травля» (I) «Метка ловчего» (II)
--   этаж 4  Старший литейщик «Раскалённая заготовка» (I) «Дыхание горна» (II)
--   этаж 5  Главный хронист  «Переписать прошлое» (I)  «Глава закрыта» (II)
--
-- Атаки вливаются в Enemies.Types (BossMoves.inject в конце Config/Enemies):
-- phase = 1 — в базовый список, 2 — в первую фазу (II), 3 — во вторую (III).
-- Поля атаки — общие для EnemyService (windup, recover, cooldown, every,
-- reach/minRange — дальность выбора). Своих radius/zones/dash/leap нет
-- нарочно: всё поведение — в move, его исполняет Systems/BossMoves, рисует
-- Controllers/BossMovesFx. move.byPhase[n] — правки параметров в фазе n
-- (n — enemy.phaseIndex: 1 — до первого порога, 2 — II, 3 — III).
-- Канал (channel) — время после удара, пока босс стоит и «ведёт» атаку;
-- считается из параметров (BossMoves.channelTime).

local BossMoves = {}

BossMoves.Moves = {
	-- ===== Этаж 1: Привратник — ключи, решётки, засовы =====
	gatekeeper = {
		{
			phase = 1,
			attack = {
				id = "gridDrop", name = "Решётки Хранилища",
				windup = 1.1, telegraph = "dodgeOnly", damage = 34, recover = 1.3, cooldown = 1.6, every = 11, reach = 32,
				move = {
					kind = "gridDrop",
					cell = 7, grid = 5, -- сетка 5×5 клеток по 7 стад вокруг цели
					waves = 2, warn = 1.05, gap = 1.2, -- шахматка: волны чередуют клетки
					stay = 0.55, sink = 0.35, height = 22, inset = 0.5,
					byPhase = { [3] = { waves = 3, gap = 1.1 } },
				},
			},
		},
		{
			phase = 2,
			attack = {
				id = "keyTurn", name = "Поворот ключа",
				windup = 1.25, telegraph = "dodgeOnly", damage = 30, recover = 1.5, cooldown = 1.6, every = 13, reach = 18,
				move = {
					kind = "keyTurn",
					radius = 18, bolts = 2, width = 2.0,
					rise = 0.85, spin = 2.6, speed = 95, -- град/с
					jumpClear = 2.4, -- ноги выше засова на столько — перепрыгнул
					knock = 30, hitGap = 0.6,
					byPhase = { [3] = { bolts = 3, speed = 110 } },
				},
			},
		},
	},

	-- ===== Этаж 2: Садовница — вода, мрамор, розы =====
	rosewarden = {
		{
			phase = 1,
			attack = {
				id = "flood", name = "Половодье",
				windup = 1.15, telegraph = "dodgeOnly", damage = 28, recover = 1.1, cooldown = 1.6, every = 10, reach = 40,
				move = {
					kind = "flood",
					speed = 15, startR = 2.5, maxR = 44, thick = 2.6,
					gaps = 2, gapWidth = 40, -- просветы под розовыми арками, град
					waves = 1, waveGap = 1.4, channel = 1.0,
					slow = { mul = 0.6, time = 2.0 }, -- «Промок»
					byPhase = { [3] = { waves = 2 } },
				},
			},
		},
		{
			phase = 2,
			attack = {
				id = "gaze", name = "Мраморный взгляд",
				windup = 1.5, telegraph = "dodgeOnly", damage = 26, recover = 1.3, cooldown = 1.8, every = 14, reach = 45,
				move = {
					kind = "gaze",
					range = 45, cone = 0.35, -- косинус: смотрит на неё — окаменел
					petrify = 1.4, pulses = 1, pulseGap = 1.25,
					byPhase = { [3] = { pulses = 2 } },
				},
			},
		},
	},

	-- ===== Этаж 3: Королевский ловчий — гон, гончие, копьё =====
	royal_huntsman = {
		{
			phase = 1,
			attack = {
				id = "houndDrive", name = "Королевская травля",
				windup = 1.2, telegraph = "dodgeOnly", damage = 30, recover = 1.2, cooldown = 1.6, every = 11, reach = 40,
				move = {
					kind = "houndDrive",
					lanes = 6, laneWidth = 5, length = 64, -- полосы поперёк арены, две пустые
					warn = 1.1, speed = 38, pack = 3,
					waves = 1, waveGap = 1.5, -- II: вторая волна крест-накрест
					slow = { mul = 0.65, time = 1.5 },
					byPhase = { [2] = { waves = 2 }, [3] = { waves = 2, speed = 44 } },
				},
			},
		},
		{
			phase = 2,
			attack = {
				id = "huntMark", name = "Метка ловчего",
				windup = 0.9, telegraph = "dodgeOnly", damage = 36, recover = 1.0, cooldown = 1.6, every = 12, reach = 42, minRange = 5,
				move = {
					kind = "huntMark",
					marks = 2, period = 1.25, follow = 0.95, flight = 0.6,
					radius = 4.5, pin = 0.8, -- «пригвождён»: корни
					byPhase = { [3] = { marks = 3, period = 1.1 } },
				},
			},
		},
	},

	-- ===== Этаж 4: Старший литейщик — слиток, горн, расплав =====
	elder_founder = {
		{
			phase = 1,
			attack = {
				id = "ingot", name = "Раскалённая заготовка",
				windup = 1.2, telegraph = "dodgeOnly", damage = 30, recover = 1.2, cooldown = 1.6, every = 10, reach = 30, minRange = 4,
				move = {
					kind = "ingot",
					lock = 0.6, -- доля замаха: направление зафиксировано, точки видны
					speed = 26, skips = { 7, 13, 18.5, 23.5, 28 },
					radius = 3.0, lastRadius = 4.2,
					fan = 1, fanAngle = 22, channel = 0.6,
					puddle = { kind = "molten", radius = 2.6, life = 4.5 },
					burn = { pct = 0.02, time = 3 },
					byPhase = { [2] = { fan = 2 }, [3] = { fan = 3 } },
				},
			},
		},
		{
			phase = 2,
			attack = {
				id = "bellows", name = "Дыхание горна",
				windup = 0.9, telegraph = "dodgeOnly", damage = 34, recover = 1.4, cooldown = 1.8, every = 13, reach = 24,
				move = {
					kind = "bellows",
					inhale = 1.9, pullRadius = 26, pullSpeed = 8.5,
					novaRadius = 11, novaTime = 0.35,
					burn = { pct = 0.03, time = 3 },
					byPhase = { [3] = { novaRadius = 13, pullSpeed = 10 } },
				},
			},
		},
	},

	-- ===== Этаж 5: Главный хронист — чернила, страницы, переплёт =====
	chief_chronicler = {
		{
			phase = 1,
			attack = {
				id = "rewind", name = "Переписать прошлое",
				windup = 1.0, telegraph = "dodgeOnly", damage = 26, recover = 1.1, cooldown = 1.6, every = 11, reach = 40,
				move = {
					kind = "rewind",
					samples = 10, sampleGap = 0.3, -- след цели: метка каждые 0,3 с
					pause = 0.45, popGap = 0.18, radius = 3.2,
					slow = { mul = 0.7, time = 1.2 },
					byPhase = { [3] = { samples = 14, sampleGap = 0.24, popGap = 0.14 } },
				},
			},
		},
		{
			phase = 2,
			attack = {
				id = "bookSlam", name = "Глава закрыта",
				windup = 1.3, telegraph = "dodgeOnly", damage = 40, recover = 1.4, cooldown = 1.8, every = 14, reach = 46,
				move = {
					kind = "bookSlam",
					halfLength = 26, width = 24, spine = 1.6, -- обложка; полоса корешка безопасна
					lift = 1.25, hold = 0.25, slam = 0.35, between = 0.5,
					byPhase = { [3] = { lift = 1.0 } },
				},
			},
		},
	},
}

-- Визуал (EnemyVisuals: анимации windup/strike/channel/recover, звуки).
-- Анимации — Anim/<Набор>Moves (дополнение набора, Anim/Resolve.EXTRA).
local function vis(prefix: string, windupSound: string, hitSound: string)
	return {
		windup = prefix .. "_Windup",
		strike = prefix .. "_Strike",
		channel = prefix .. "_Channel",
		recover = prefix .. "_Recover",
		windupSound = windupSound,
		hitSound = hitSound,
	}
end

BossMoves.Visuals = {
	gatekeeper = {
		gridDrop = vis("GridDrop", "chainRattle", "bmGateSlam"),
		keyTurn = vis("KeyTurn", "gateCreak", "bmKeyStab"),
	},
	rosewarden = {
		flood = vis("Flood", "bossCharge", "gardenFlood"),
		gaze = vis("Gaze", "statueCrack", "bmGazeFlash"),
	},
	royal_huntsman = {
		houndDrive = vis("HoundDrive", "bossCharge", "bmHuntHorn"),
		huntMark = vis("HuntMark", "enemyWindup", "bmSpearThrow"),
	},
	elder_founder = {
		ingot = vis("Ingot", "forgeBellows", "bmIngotThrow"),
		bellows = vis("Bellows", "forgeBellows", "forgeBlast"),
	},
	chief_chronicler = {
		rewind = vis("Rewind", "pageRustle", "chronicleChant"),
		bookSlam = vis("BookSlam", "pageRustle", "bmBookSlam"),
	},
}

-- Звуки маркеров анимаций (EnemyVisuals.markerSounds).
BossMoves.MarkerSounds = {
	gatekeeper = { KeyStab = "bmKeyStab", Clank = "chainSlam" },
	rosewarden = { Splash = "gardenFlood", EyeOpen = "bmGazeFlash" },
	royal_huntsman = { Horn = "bmHuntHorn", Throw = "bmSpearThrow" },
	elder_founder = { Throw = "bmIngotThrow", Inhale = "bmInhale" },
	chief_chronicler = { Quill = "pageShot", Slam = "bmBookSlam" },
}

-- Набор анимаций с фирменными атаками (дополнение к основному).
BossMoves.AnimSets = {
	Gatekeeper = "GatekeeperMoves",
	Rosewarden = "RosewardenMoves",
	Huntsman = "HuntsmanMoves",
	Founder = "FounderMoves",
	Chronicler = "ChroniclerMoves",
}

-- Параметры атаки в фазе phaseIndex (move + byPhase до этой фазы включительно).
function BossMoves.params(move, phaseIndex: number?)
	local out = {}
	for key, value in pairs(move) do
		if key ~= "byPhase" then
			out[key] = value
		end
	end
	local byPhase = move.byPhase or {}
	for index = 1, phaseIndex or 1 do
		for key, value in pairs(byPhase[index] or {}) do
			out[key] = value
		end
	end
	return out
end

-- Сколько босс стоит после удара, «ведя» атаку (состояние channel).
function BossMoves.channelTime(p): number
	local kind = p.kind
	if kind == "gridDrop" then
		return p.warn + (p.waves - 1) * p.gap + 0.4
	elseif kind == "keyTurn" then
		return p.rise + p.spin + 0.2
	elseif kind == "flood" then
		return (p.channel or 1) + (p.waves - 1) * p.waveGap
	elseif kind == "gaze" then
		return (p.pulses - 1) * p.pulseGap + 0.5
	elseif kind == "houndDrive" then
		return p.warn + (p.waves - 1) * p.waveGap + 0.4
	elseif kind == "huntMark" then
		return (p.marks - 1) * p.period + p.follow + p.flight + 0.25
	elseif kind == "ingot" then
		return p.channel or 0.6
	elseif kind == "bellows" then
		return p.inhale + p.novaTime + 0.15
	elseif kind == "rewind" then
		return p.samples * p.sampleGap + 0.3
	elseif kind == "bookSlam" then
		local one = p.lift + p.hold + p.slam
		return one * 2 + p.between + 0.3
	end
	return 0.5
end

-- Время удара обложки k (1, 2) после начала (bookSlam).
function BossMoves.bookImpact(p, k: number): number
	local one = p.lift + p.hold + p.slam
	return one * k + p.between * (k - 1)
end

-- Все атаки босса (id → move) — для тестов и отладочных команд.
function BossMoves.list(typeId: string)
	local list = {}
	for _, entry in ipairs(BossMoves.Moves[typeId] or {}) do
		table.insert(list, entry)
	end
	return list
end

function BossMoves.find(typeId: string, attackId: string)
	for _, entry in ipairs(BossMoves.Moves[typeId] or {}) do
		if entry.attack.id == attackId then
			return entry
		end
	end
	return nil
end

-- Влить атаки в таблицу типов врагов (вызывается один раз из Config/Enemies).
local injected = false
function BossMoves.inject(types)
	if injected then
		return
	end
	injected = true
	for typeId, entries in pairs(BossMoves.Moves) do
		local enemyType = types[typeId]
		if enemyType then
			for _, entry in ipairs(entries) do
				local attack = table.clone(entry.attack)
				attack.bossMove = true
				if entry.phase <= 1 then
					table.insert(enemyType.attacks, attack)
				else
					local phase = enemyType.phases and enemyType.phases[entry.phase - 1]
					if phase then
						phase.attacks = phase.attacks or {}
						table.insert(phase.attacks, attack)
					else
						table.insert(enemyType.attacks, attack)
					end
				end
			end
		end
	end
end

return BossMoves
