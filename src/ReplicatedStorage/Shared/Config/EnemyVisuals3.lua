--!nonstrict
-- EnemyVisuals3
-- Внешний вид и анимации врагов этажа 3 «Псарни охоты»: набор анимаций
-- (Shared/Anim/<set>, сгенерированы tools/anim/anims3.py), звуки (ключи
-- Config/Sfx — только существующие), глаза, тяжёлые шаги. Подмешивается в
-- EnemyVisuals.Types (см. конец EnemyVisuals.lua). Формат — как у этажей 4–5.
--
-- Свои поля этажа 3:
--   states     свои состояния сервера → анимация (horn загонщика, howl
--              Вожака, perch ловчего на насесте)
--   oneShots   анимации по событиям Floor3EnemyService (hop — отскок,
--              spearThrow — бросок копий с насеста); играет Floor3EnemyFx
--   bird       имя меша сокола на перчатке сокольника (прячется, пока сокол в полёте)
--   hover      парение над землёй (сокол), как у пчелы этажа 2
-- Элиты (beater_elite, bear_hunter_elite) — префаб обычного моба с масштабом.

local EnemyVisuals3 = {}

local rgb = Color3.fromRGB

local function atk(prefix: string, windupSound: string?, hitSound: any?, extra)
	local entry = {
		windup = prefix .. "_Windup",
		strike = prefix .. "_Strike",
		recover = prefix .. "_Recover",
		windupSound = windupSound or "enemyWindup",
		hitSound = hitSound,
	}
	for key, value in pairs(extra or {}) do
		entry[key] = value
	end
	return entry
end

local EYE_HUNT = rgb(255, 179, 71) -- янтарь охоты
local EYE_ELITE = rgb(255, 92, 72)

local beater = {
	set = "Beater",
	scale = 1,
	role = "melee",
	eyeColor = EYE_HUNT,
	sounds = { step = "guardStep", death = "enemyDeath" },
	states = { horn = "Horn" },
	markerSounds = { Horn = "bossRoar" },
	attacks = {
		thrust = atk("Thrust", "enemyWindup", "swing2", { strikeDouble = "Thrust_StrikeDouble" }),
	},
	animIds = {},
}

local bearHunter = {
	set = "BearHunter",
	scale = 1,
	role = "tank",
	eyeColor = EYE_HUNT,
	heavySteps = { shake = 0.05, range = 15, dust = 7 },
	sounds = { step = "knightStep", death = "enemyDeath" },
	attacks = {
		bash = atk("Bash", "enemyWindup", "hitHeavy"),
		chop = atk("Chop", "enemyWindup", "slam"),
	},
	animIds = {},
}

local function elite(base, prefab: string, scale: number)
	local copy = table.clone(base)
	copy.prefab = prefab
	copy.scale = scale
	copy.elite = true
	copy.eyeColor = EYE_ELITE
	return copy
end

EnemyVisuals3.Types = {
	hound = {
		set = "Hound",
		scale = 1,
		role = "melee",
		eyeColor = EYE_HUNT,
		sounds = { death = "enemyDeath" },
		attacks = {
			lunge = atk("Lunge", "shadeWhisper", { "swing1", "swing2" }, { strikeDouble = "Lunge_StrikeDouble", dash = "Lunge_Dash", dashSound = "dash" }),
			leap = atk("Leap", "enemyWindup", "slam", { dash = "Leap_Dash", dashSound = "dash" }),
		},
		animIds = {},
	},
	beater = beater,
	beater_elite = elite(beater, "beater", 1.07),
	crossbowman = {
		set = "Crossbow",
		scale = 1,
		role = "ranged",
		eyeColor = EYE_HUNT,
		sounds = { step = "guardStep", death = "enemyDeath" },
		attacks = {
			bolt = atk("Bolt", "bowDraw", "bowRelease", { aim = true }),
		},
		animIds = {},
	},
	trapper = {
		set = "Trapper",
		scale = 1,
		role = "ranged",
		eyeColor = EYE_HUNT,
		sounds = { death = "enemyDeath", hop = "rangerHop" },
		oneShots = { hop = "Hop" },
		attacks = {
			bolas = atk("Bolas", "unlockThrow", "swing2", { aim = true }),
			snare = atk("Snare", "chainRattle", "chains"),
		},
		animIds = {},
	},
	falconer = {
		set = "Falconer",
		scale = 1,
		role = "ranged",
		eyeColor = EYE_HUNT,
		bird = "LeftHand__weaponbird",
		sounds = { death = "enemyDeath", hop = "rangerHop" },
		oneShots = { hop = "Hop" },
		markerSounds = { Catch = "unlockThrow" },
		attacks = {
			release = atk("Release", "enemyWindup", "dash", { aim = true }),
			knife = atk("Knife", "enemyWindup", "swing1"),
		},
		animIds = {},
	},
	falcon = {
		set = "Falcon",
		scale = 1,
		role = "melee",
		eyeColor = rgb(255, 214, 92),
		hover = 2.2,
		sounds = { death = "enemyDeath" },
		attacks = {
			dive = atk("Dive", "unlockThrow", "swing3", { dash = "Dive_Dash", dashSound = "dash" }),
			talons = atk("Talons", "enemyWindup", { "swing1", "swing2" }),
		},
		animIds = {},
	},
	bear_hunter = bearHunter,
	bear_hunter_elite = elite(bearHunter, "bear_hunter", 1.06),
	torchbearer = {
		set = "Torchbearer",
		scale = 1,
		role = "disruptor",
		eyeColor = rgb(255, 154, 60),
		sounds = { death = "explode" },
		markerSounds = { Ignite = "fuseBeep" },
		attacks = {
			keg = atk("Keg", "fuseBeep", "explode"),
		},
		animIds = {},
	},
	skinner = {
		set = "Skinner",
		scale = 1,
		role = "melee",
		eyeColor = EYE_HUNT,
		heavySteps = { shake = 0.04, range = 14, dust = 6 },
		sounds = { step = "knightStep", death = "enemyDeath" },
		attacks = {
			cleave = atk("Cleave", "enemyWindup", "swing3"),
			tarPot = atk("TarPot", "enemyWindup", "mudSplash"),
		},
		animIds = {},
	},
	tanner = {
		set = "Tanner",
		scale = 1,
		role = "disruptor",
		eyeColor = EYE_HUNT,
		sounds = { step = "guardStep", death = "enemyDeath" },
		markerSounds = { PourStart = "pourRot" },
		attacks = {
			pour = atk("Pour", "valveTurn", nil),
			paddle = atk("Paddle", "enemyWindup", "hitHeavy"),
		},
		animIds = {},
	},
	trophy_bear = {
		set = "TrophyBear",
		scale = 1,
		role = "tank",
		eyeColor = rgb(255, 120, 72),
		heavySteps = { shake = 0.07, range = 18, dust = 8 },
		sounds = { step = "treantStep", death = "statueCrack" },
		markerSounds = { EyesOn = "statueCrack", Roar = "bossRoar" },
		attacks = {
			maul = atk("Maul", "enemyWindup", "hitHeavy"),
			trap = atk("Trap", "chainRattle", "chainSlam"),
		},
		animIds = {},
	},

	-- Мини-босс Псарни: появление — Intro (3 с, вой), фаза «Сорвался с цепи» — Phase2,
	-- вой со сворой — своё состояние howl.
	pack_leader = {
		set = "PackLeader",
		scale = 1,
		role = "boss",
		eyeColor = rgb(255, 200, 87),
		spawn = "Intro",
		phase = "Phase2",
		states = { howl = "Howl" },
		heavySteps = { shake = 0.06, range = 18, dust = 8 },
		sounds = { step = "knightStep", death = "enemyDeath", roar = "bossRoar", phase = "chainSlam" },
		markerSounds = { Howl = "bossRoar", ChainBreak = "chainSlam", Slam = "slam" },
		attacks = {
			bite = atk("Bite", "enemyWindup", "swing3"),
			rush = atk("Rush", "bossCharge", "slam", { dash = "Rush_Dash", dashSound = "dash" }),
			pounce = atk("Pounce", "bossCharge", "slam", { dash = "Pounce_Dash", dashSound = "dash" }),
			maul = atk("Maul", "enemyWindup", "hitHeavy"),
		},
		animIds = {},
	},

	-- Босс Ристалища: Intro 5 с, сцены фаз II («Гон») и III («Последний гон»),
	-- на насесте — Perch, броски копий — SpearThrow (событие f3spear).
	royal_huntsman = {
		set = "Huntsman",
		scale = 1,
		role = "boss",
		eyeColor = rgb(255, 200, 87),
		spawn = "Intro",
		phase = { [2] = "Phase2", [3] = "Phase3" },
		states = { perch = "Perch" },
		oneShots = { spearThrow = "SpearThrow" },
		stunAmp = 1.2,
		heavySteps = { shake = 0.12, range = 25, dust = 10 },
		sounds = { step = "bossStep", death = "enemyDeath", roar = "bossRoar", phase = "bossRoar", wallHit = "bossWallHit" },
		markerSounds = { Horn = "bossRoar", Slam = "slam", Whistle = "shadeWhisper", Throw = "unlockThrow" },
		attacks = {
			sweep = atk("Sweep", "enemyWindup", "swing3", { strikeDouble = "Sweep_StrikeDouble" }),
			thrust = atk("Thrust", "enemyWindup", "swing2"),
			spin = atk("Spin", "bossCharge", "bossSpin"),
			nets = atk("Nets", "chainRattle", "chains"),
			charge = atk("Charge", "bossCharge", "slam", { dash = "Charge_Dash", dashSound = "dash" }),
			leap = atk("Leap", "bossCharge", "slam", { dash = "Leap_Dash", dashSound = "dash" }),
		},
		animIds = {},
	},
}

return EnemyVisuals3
