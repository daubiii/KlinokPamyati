--!nonstrict
-- EnemyVisuals
-- Всё, что клиент знает о внешнем виде врагов (ТЗ врагов этажа 1, разделы
-- 2.3–2.7 и 3.5). Сервер этот модуль не читает.
--
-- По typeId:
--   set        набор анимаций (Shared/Anim/<set>)
--   scale      Model:ScaleTo у префаба (равномерный, раздел 2.0 п. 4)
--   role       кольцо под ногами: melee L, tank A, ranged R, disruptor X
--   eyeColor   цвет неоновых глаз
--   sounds     ключи Config/Sfx: шаг (маркер Step), смерть
--   attacks    EnemyAttack → анимации по состояниям сервера и звуки:
--              windup / dash / strike / strikeDouble / recover — имена
--              анимаций; windupSound, hitSound — звуки начала замаха и
--              маркера Hit
--   animIds    запасной путь: AnimationId по имени анимации (раздел 3.0 п. 3).
--              Пусто — играются таблицы.

local Palette = require(script.Parent.Palette)

local V = Palette.Voxel

local EnemyVisuals = {}

-- Общие числа эффектов (раздел 2.3).
EnemyVisuals.Fx = {
	ringScale = 2.4, -- диаметр кольца = радиус хитбокса × 2,4
	ringTransparency = 0.6,
	spawnCubes = 40,
	spawnCubesBoss = 120,
	spawnRadius = 3,
	spawnRadiusBoss = 6,
	debrisMax = 80,
	debrisMaxBoss = 220,
	soulCubes = 30,
	soulTime = 0.6,
	soulArc = 3,
	hitKick = 0.45,
	hitKickBoss = 0.12,
	-- LOD (раздел 2.3): дальше lodSlow — поза 15 раз в секунду, дальше
	-- lodFx — без частиц и подсветки, дальше lodHide — модель скрыта.
	lodSlow = 60,
	lodFx = 80,
	lodHide = 120,
	lodSlowRate = 15,
	-- Одновременно видимых Highlight в Roblox не больше 31: берём из пула.
	highlightPool = 24,
}

-- Цвета кольца по роли (раздел 2.3).
EnemyVisuals.RoleColors = {
	melee = V.L,
	tank = V.A,
	ranged = V.R,
	disruptor = V.X,
}

-- Анимации состояний, общие для всех: spawning → Spawn, stunned → Stun…
-- (раздел 3.5). Свои — в полях конкретного врага.
EnemyVisuals.Defaults = {
	spawn = "Spawn",
	idle = "Idle",
	walk = "Walk",
	strafe = "Strafe",
	hit = "Hit",
	stun = "Stun",
	death = "Death",
	walkBaseSpeed = 10, -- стад/с, под которые сделана Base.Walk
}

EnemyVisuals.Types = {
	guard = {
		set = "Guard",
		scale = 1.05,
		role = "melee",
		eyeColor = V.A,
		sounds = { step = "guardStep", death = "enemyDeath" },
		attacks = {
			slash = { windup = "Slash_Windup", strike = "Slash_Strike", recover = "Slash_Recover", windupSound = "enemyWindup", hitSound = "swing1" },
		},
		animIds = {},
	},

	shade = {
		set = "Shade",
		scale = 1.0,
		role = "melee",
		eyeColor = V.W,
		sounds = { death = "enemyDeath" },
		attacks = {
			dash_combo = {
				windup = "Dash_Windup",
				dash = "Dash",
				strike = "Combo_Strike",
				recover = "Combo_Recover",
				windupSound = "shadeWhisper",
				dashSound = "dash",
				hitSound = { "swing1", "swing2" },
			},
		},
		animIds = {},
	},

	knight = {
		set = "Knight",
		scale = 1.2,
		role = "tank",
		eyeColor = V.A,
		heavySteps = { shake = 0.04, range = 15, dust = 6 },
		sounds = { step = "knightStep", death = "enemyDeath" },
		attacks = {
			shield = { windup = "Shield_Windup", strike = "Shield_Strike", recover = "Shield_Recover", windupSound = "enemyWindup", hitSound = "hitHeavy" },
			slam = { windup = "Slam_Windup", strike = "Slam_Strike", recover = "Slam_Recover", windupSound = "enemyWindup", hitSound = "explode" },
		},
		animIds = {},
	},

	archer = {
		set = "Archer",
		scale = 1.0,
		role = "ranged",
		aimNock = true, -- объёмный префаб без FX_BowNock: точка на луке
		eyeColor = V.A,
		sounds = { death = "enemyDeath" },
		attacks = {
			shot = { windup = "Shot_Windup", strike = "Shot_Strike", recover = "Shot_Recover", windupSound = "bowDraw", hitSound = "bowRelease" },
		},
		animIds = {},
	},

	martyr = {
		set = "Martyr",
		scale = 0.95,
		role = "disruptor",
		eyeColor = V.X,
		sounds = { death = "enemyDeath", idle = "martyrGroan", loop = "fuseHiss" },
		attacks = {
			-- Ударной анимации нет: на strike сразу взрыв и распад.
			explode = { windup = "Explode_Windup" },
		},
		animIds = {},
	},

	gatekeeper = {
		set = "Gatekeeper",
		scale = 1.8,
		role = "boss",
		eyeColor = V.A,
		spawn = "Intro",
		phase = "Phase2",
		wallHit = "WallHit",
		stunAmp = 1.3, -- после удара в стену общая Stun с амплитудой ×1.3
		heavySteps = { shake = 0.12, range = 25, dust = 10 },
		sounds = { step = "bossStep", death = "enemyDeath", roar = "bossRoar", phase = "gateCreak", wallHit = "bossWallHit" },
		attacks = {
			slash = {
				windup = "Slash_Windup",
				strike = "Slash_Strike",
				strikeDouble = "SlashDouble_Strike", -- (доп.) двойной рубящий II фазы
				recover = "Recover",
				windupSound = "enemyWindup",
				hitSound = "swing3",
			},
			spin = { windup = "Spin_Windup", strike = "Spin_Strike", recover = "Recover", windupSound = "enemyWindup", hitSound = "bossSpin" },
			chains = { windup = "Chains_Windup", strike = "Chains_Strike", recover = "Recover", windupSound = "chainRattle", hitSound = "chainSlam" },
			charge = { windup = "Charge_Windup", dash = "Charge", recover = "Recover", windupSound = "bossCharge" },
			-- (доп.) атаки, которых нет в ТЗ, но есть на сервере.
			thrust = { windup = "Thrust_Windup", strike = "Thrust_Strike", recover = "Recover", windupSound = "enemyWindup", hitSound = "swing2" },
			leap = { windup = "Leap_Windup", dash = "Leap", strike = "Leap_Strike", recover = "Recover", windupSound = "bossCharge", hitSound = "slam" },
		},
		animIds = {},
	},

	-- ===== Этаж 1 v2: элита и мини-боссы =====
	-- prefab — чей префаб клонировать (EnemyPrefabs.<prefab>), если своего нет.

	guard_elite = {
		set = "Guard",
		prefab = "guard",
		scale = 1.15,
		role = "melee",
		eyeColor = V.H,
		elite = true,
		sounds = { step = "guardStep", death = "enemyDeath" },
		attacks = {
			slash = { windup = "Slash_Windup", strike = "Slash_Strike", recover = "Slash_Recover", windupSound = "enemyWindup", hitSound = "swing1" },
		},
		animIds = {},
	},

	knight_elite = {
		set = "Knight",
		prefab = "knight",
		scale = 1.32,
		role = "tank",
		eyeColor = V.H,
		elite = true,
		heavySteps = { shake = 0.05, range = 15, dust = 7 },
		sounds = { step = "knightStep", death = "enemyDeath" },
		attacks = {
			shield = { windup = "Shield_Windup", strike = "Shield_Strike", recover = "Shield_Recover", windupSound = "enemyWindup", hitSound = "hitHeavy" },
			slam = { windup = "Slam_Windup", strike = "Slam_Strike", recover = "Slam_Recover", windupSound = "enemyWindup", hitSound = "explode" },
		},
		animIds = {},
	},

	centurion = {
		set = "Centurion",
		scale = 1.45,
		role = "boss",
		eyeColor = V.A,
		phase = "Horn", -- состояние phase у Сотника — это рог (EnemyAttack = "horn")
		heavySteps = { shake = 0.07, range = 18, dust = 8 },
		sounds = { step = "knightStep", death = "enemyDeath", roar = "bossRoar", phase = "gateCreak" },
		attacks = {
			bash = { windup = "Bash_Windup", strike = "Bash_Strike", recover = "Bash_Recover", windupSound = "enemyWindup", hitSound = "hitHeavy" },
			rush = { windup = "Rush_Windup", dash = "Rush", recover = "Rush_Recover", windupSound = "bossCharge", dashSound = "dash", hitSound = "slam" },
			bannerSweep = { windup = "Sweep_Windup", strike = "Sweep_Strike", recover = "Sweep_Recover", windupSound = "chainRattle", hitSound = "bossSpin" },
			pick = { windup = "Pick_Windup", strike = "Pick_Strike", recover = "Pick_Recover", windupSound = "enemyWindup", hitSound = "swing3" },
		},
		animIds = {},
	},

	arbalest = {
		set = "Arbalest",
		scale = 1.25,
		role = "boss",
		eyeColor = V.A,
		aimNock = true, -- прицельный луч от арбалета (FX_BowNock создаётся на оружии)
		sounds = { death = "enemyDeath" },
		states = { reload = "Reload" },
		markerSounds = { Crank = "chainRattle" },
		attacks = {
			aimedBolt = { windup = "Aim_Windup", strike = "Aim_Strike", recover = "Aim_Recover", windupSound = "bowDraw", hitSound = "bowRelease", aim = true },
			volley = { windup = "Volley_Windup", strike = "Volley_Strike", recover = "Volley_Recover", windupSound = "bowDraw", hitSound = "bowRelease" },
			chainBolt = { windup = "Chain_Windup", strike = "Chain_Strike", recover = "Chain_Recover", windupSound = "chainRattle", hitSound = "bowRelease", aim = true },
			stock = { windup = "Stock_Windup", strike = "Stock_Strike", recover = "Stock_Recover", windupSound = "enemyWindup", hitSound = "hitHeavy" },
			leapShot = { windup = "Leap_Windup", strike = "Leap_Strike", recover = "Leap_Recover", windupSound = "dash", hitSound = "bowRelease", aim = true },
			traps = { windup = "Traps_Windup", strike = "Traps_Strike", recover = "Traps_Recover", windupSound = "chainRattle", hitSound = "chains" },
			lastBolt = { windup = "Last_Windup", strike = "Last_Strike", recover = "Last_Recover", windupSound = "bossCharge", hitSound = "bowRelease", aim = true, aimWide = true },
		},
		animIds = {},
	},

	-- ===== Этаж 2 «Затопленные сады» (28.10.2026) =====
	-- Префабы — свои R15-скелеты по анатомии моба (EnemyPrefabs2, RigVersion 3),
	-- масштаб 1: рост задан моделью. Анимации — Anim/<set> (из f2/anim/sets.py).

	treant = {
		set = "Treant",
		scale = 1,
		role = "tank",
		eyeColor = Color3.fromRGB(216, 242, 90),
		heavySteps = { shake = 0.05, range = 16, dust = 7 },
		sounds = { step = "treantStep", death = "enemyDeath" },
		attacks = {
			smash = { windup = "Smash_Windup", strike = "Smash_Strike", recover = "Smash_Recover", windupSound = "enemyWindup", hitSound = "slam" },
			roots = { windup = "Roots_Windup", strike = "Roots_Strike", recover = "Roots_Recover", windupSound = "bossCharge", hitSound = "rootsBurst" },
		},
		animIds = {},
	},

	bee = {
		set = "Bee",
		scale = 1,
		role = "melee",
		eyeColor = Color3.fromRGB(255, 194, 74),
		hover = 0.6, -- парит (Enemies.traits.hover): подъём в EnemyAnimator
		sounds = { death = "enemyDeath" },
		attacks = {
			sting = { windup = "Sting_Windup", dash = "Sting_Dash", strike = "Sting_Strike", recover = "Sting_Recover", windupSound = "beeBuzz", dashSound = "dash", hitSound = "swing3" },
			claws = { windup = "Claws_Windup", strike = "Claws_Strike", recover = "Claws_Recover", windupSound = "beeBuzz", hitSound = { "swing1", "swing2" } },
		},
		animIds = {},
	},

	drowned = {
		set = "Drowned",
		scale = 1,
		role = "melee",
		eyeColor = Color3.fromRGB(182, 245, 154),
		sounds = { step = "gardenStep", death = "mudSplash" },
		attacks = {
			pound = { windup = "Pound_Windup", strike = "Pound_Strike", recover = "Pound_Recover", windupSound = "enemyWindup", hitSound = "hitHeavy" },
			mudThrow = { windup = "MudThrow_Windup", strike = "MudThrow_Strike", recover = "MudThrow_Recover", windupSound = "martyrGroan", hitSound = "dash" },
		},
		animIds = {},
	},

	gardener = {
		set = "Gardener",
		scale = 1,
		role = "disruptor",
		eyeColor = Color3.fromRGB(255, 210, 122),
		sounds = { step = "gardenStep", death = "enemyDeath" },
		attacks = {
			pour = { windup = "Pour_Windup", strike = "Pour_Strike", recover = "Pour_Recover", windupSound = "enemyWindup" },
			canBash = { windup = "Bash_Windup", strike = "Bash_Strike", recover = "Bash_Recover", windupSound = "enemyWindup", hitSound = "hitHeavy" },
		},
		animIds = {},
	},

	ranger = {
		set = "Ranger",
		scale = 1,
		role = "ranged",
		eyeColor = Color3.fromRGB(79, 224, 198),
		sounds = { death = "enemyDeath" },
		attacks = {
			-- aim: прицельная линия от ладони (FX_BowNock на RightHand префаба).
			thorns = { windup = "Thorns_Windup", strike = "Thorns_Strike", recover = "Thorns_Recover", windupSound = "bowDraw", hitSound = "thornShot", aim = true },
		},
		animIds = {},
	},

	rosewarden = {
		set = "Rosewarden",
		scale = 1,
		role = "boss",
		eyeColor = Color3.fromRGB(124, 242, 176),
		spawn = "Intro",
		phase = "Phase",
		wallHit = "WallHit",
		stunAmp = 1.2,
		heavySteps = { shake = 0.12, range = 25, dust = 10 },
		sounds = { step = "bossStep", death = "enemyDeath", roar = "bossRoar", phase = "statueCrack", wallHit = "bossWallHit" },
		attacks = {
			lash = { windup = "Lash_Windup", strike = "Lash_Strike", recover = "Lash_Recover", windupSound = "enemyWindup", hitSound = "swing3" },
			thornRing = { windup = "ThornRing_Windup", strike = "ThornRing_Strike", recover = "ThornRing_Recover", windupSound = "bossCharge", hitSound = "slam" },
			roseVolley = { windup = "Volley_Windup", strike = "Volley_Strike", recover = "Volley_Recover", windupSound = "bowDraw", hitSound = "thornShot", aim = true },
			rootLines = { windup = "Lines_Windup", strike = "Lines_Strike", recover = "Lines_Recover", windupSound = "bossCharge", hitSound = "riftSlam" },
			ram = { windup = "Ram_Windup", dash = "Ram", recover = "Ram_Recover", windupSound = "bossCharge", dashSound = "dash" },
		},
		animIds = {},
	},
}

function EnemyVisuals.get(typeId: string)
	return EnemyVisuals.Types[typeId]
end

-- Все имена анимаций, которые нужны врагу по таблице раздела 3.5.
function EnemyVisuals.requiredAnimations(typeId: string): { string }
	local config = EnemyVisuals.Types[typeId]
	local defaults = EnemyVisuals.Defaults
	local names = {
		config.spawn or defaults.spawn,
		defaults.idle,
		defaults.walk,
		defaults.strafe,
		defaults.hit,
		defaults.stun,
		defaults.death,
	}
	if type(config.phase) == "table" then
		for _, name in pairs(config.phase) do
			table.insert(names, name)
		end
	elseif config.phase then
		table.insert(names, config.phase)
	end
	if config.wallHit then
		table.insert(names, config.wallHit)
	end
	for _, name in pairs(config.states or {}) do
		table.insert(names, name)
	end
	for _, attack in pairs(config.attacks) do
		for _, field in ipairs({ "windup", "dash", "strike", "strikeDouble", "channel", "recover" }) do
			if attack[field] then
				table.insert(names, attack[field])
			end
		end
	end
	return names
end

-- Этажи 4–5 добавляют свои визуальные конфиги, не заменяя врагов этажей 1–3.
do
	local EnemyVisuals45 = require(script.Parent.EnemyVisuals45)
	for id, config in pairs(EnemyVisuals45.Types) do
		EnemyVisuals.Types[id] = config
	end
end

do
	local EnemyVisuals3 = require(script.Parent.EnemyVisuals3)
	for id, config in pairs(EnemyVisuals3.Types) do
		EnemyVisuals.Types[id] = config
	end
end

-- Фирменные атаки боссов (Config/BossMoves) и их сцены появления
-- (Config/BossIntros): анимации windup / strike / channel / recover, звуки
-- маркеров, своя анимация появления IntroScene вместо сборки из кубиков.
do
	local BossMoves = require(script.Parent.BossMoves)
	local BossIntros = require(script.Parent.BossIntros)
	for typeId, moves in pairs(BossMoves.Visuals) do
		local config = EnemyVisuals.Types[typeId]
		if config then
			for id, entry in pairs(moves) do
				config.attacks[id] = entry
			end
			config.markerSounds = config.markerSounds or {}
			for name, sound in pairs(BossMoves.MarkerSounds[typeId] or {}) do
				if config.markerSounds[name] == nil then
					config.markerSounds[name] = sound
				end
			end
			local scene = BossIntros.get(typeId)
			if scene then
				config.legacySpawn = config.spawn
				config.spawn = scene.anim
				config.introScene = true
			end
		end
	end
end

return EnemyVisuals
