--!nonstrict
-- EnemyVisuals45
-- Внешний вид и анимации врагов этажей 4–5: набор анимаций (Shared/Anim/<set>,
-- сгенерированы anim45.py), звуки, глаза, тяжёлые шаги. Подмешивается в
-- EnemyVisuals.Types (см. конец EnemyVisuals.lua). Формат — как у этажа 2.

local EnemyVisuals45 = {}

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

EnemyVisuals45.Types = {
	-- ===== Этаж 4 =====
	forge_automaton = {
		set = "Automaton",
		scale = 1,
		role = "tank",
		eyeColor = rgb(255, 181, 71),
		heavySteps = { shake = 0.06, range = 18, dust = 8 },
		sounds = { step = "forgeStep", death = "forgeDeath" },
		oneShots = { vent = "Vent" },
		attacks = {
			hammer = atk("Hammer", "enemyWindup", "hitHeavy"),
			quake = atk("Quake", "bossCharge", "slam"),
			blast = atk("Blast", "forgeBellows", "forgeBlast"),
		},
		animIds = {},
	},
	fire_spirit = {
		set = "FireSpirit",
		scale = 1,
		role = "melee",
		eyeColor = rgb(255, 241, 184),
		hover = 0.8,
		sounds = { death = "spiritDeath" },
		attacks = {
			claws = atk("Claws", "spiritHiss", { "swing1", "swing2" }),
			lunge = atk("Lunge", "spiritHiss", "swing3", { dash = "Lunge_Dash", dashSound = "dash" }),
		},
		animIds = {},
	},
	slag_thrower = {
		set = "SlagThrower",
		scale = 1,
		role = "ranged",
		eyeColor = rgb(255, 200, 87),
		sounds = { step = "guardStep", death = "enemyDeath" },
		attacks = {
			lob = atk("Lob", "enemyWindup", "slagLob"),
			ladle = atk("Ladle", "enemyWindup", "hitHeavy"),
		},
		animIds = {},
	},
	smolder = {
		set = "Smolder",
		scale = 1,
		role = "melee",
		eyeColor = rgb(255, 154, 60),
		sounds = { death = "explode" },
		attacks = {
			burst = atk("Burst", "fuseBeep", "explode"),
		},
		animIds = {},
	},
	elder_founder = {
		set = "Founder",
		scale = 1,
		role = "boss",
		eyeColor = rgb(255, 200, 87),
		spawn = "Intro",
		phase = "Phase",
		stunAmp = 1.2,
		heavySteps = { shake = 0.14, range = 26, dust = 11 },
		sounds = { step = "bossStep", death = "forgeDeath", roar = "bossRoar", phase = "forgeRoar" },
		attacks = {
			slam = atk("Slam", "enemyWindup", "slam"),
			pour = atk("Pour", "bossCharge", "forgePour"),
			splash = atk("Splash", "bossCharge", "slagLob"),
			spin = atk("Spin", "bossCharge", "bossSpin"),
			leap = atk("Leap", "bossCharge", "slam", { dash = "Leap_Air", dashSound = "dash" }),
		},
		animIds = {},
	},

	-- ===== Этаж 5 =====
	stone_reader = {
		set = "Reader",
		scale = 1,
		role = "tank",
		eyeColor = rgb(184, 227, 255),
		heavySteps = { shake = 0.06, range = 18, dust = 8 },
		sounds = { step = "treantStep", death = "stoneDeath" },
		attacks = {
			slam = atk("Slam", "enemyWindup", "slam"),
			recital = atk("Recital", "chronicleChant", "riftSlam"),
		},
		animIds = {},
	},
	seal_mage = {
		set = "SealMage",
		scale = 1,
		role = "ranged",
		eyeColor = rgb(184, 227, 255),
		sounds = { death = "enemyDeath" },
		attacks = {
			bolt = atk("Bolt", "runeCharge", "runeShot", { aim = true }),
			sigil = atk("Sigil", "runeCharge", "riftErupt"),
		},
		animIds = {},
	},
	ward_seal = {
		set = "WardSeal",
		scale = 1,
		role = "object",
		eyeColor = rgb(184, 227, 255),
		sounds = { death = "sealShatter" },
		attacks = {},
		animIds = {},
	},
	ink_scribe = {
		set = "Scribe",
		scale = 1,
		role = "disruptor",
		eyeColor = rgb(142, 124, 224),
		sounds = { death = "inkSplash" },
		attacks = {
			summon = atk("Summon", "chronicleChant", "inkSplash"),
			splash = atk("Splash", "enemyWindup", "inkSplash"),
			stab = atk("Stab", "enemyWindup", "swing3"),
		},
		animIds = {},
	},
	ink_blot = {
		set = "InkBlot",
		scale = 1,
		role = "melee",
		eyeColor = rgb(184, 227, 255),
		sounds = { death = "inkSplash" },
		attacks = {
			bite = atk("Bite", "enemyWindup", "swing1"),
		},
		animIds = {},
	},
	shelf_warden = {
		set = "Warden",
		scale = 1,
		role = "ranged",
		eyeColor = rgb(184, 227, 255),
		sounds = { death = "enemyDeath" },
		oneShots = { hop = "Hop" },
		attacks = {
			fan = atk("Fan", "pageRustle", "pageShot", { aim = true }),
		},
		animIds = {},
	},
	bookbinder = {
		set = "Binder",
		scale = 1,
		role = "boss",
		eyeColor = rgb(255, 200, 120),
		spawn = "Intro",
		phase = "Phase",
		heavySteps = { shake = 0.1, range = 22, dust = 9 },
		sounds = { step = "bossStep", death = "enemyDeath", roar = "bossRoar", phase = "pageRustle" },
		attacks = {
			cut = atk("Cut", "enemyWindup", "swing3"),
			stitch = atk("Stitch", "bossCharge", "swing2", { dash = "Stitch_Dash", dashSound = "dash" }),
			press = atk("Press", "bossCharge", "slam"),
			threads = atk("Threads", "bossCharge", "chainSlam"),
		},
		animIds = {},
	},
	chief_chronicler = {
		set = "Chronicler",
		scale = 1,
		role = "boss",
		eyeColor = rgb(184, 227, 255),
		spawn = "Intro",
		phase = { [2] = "Phase2", [3] = "Phase3" }, -- в наборе Chronicler нет общей Phase
		stunAmp = 1.2,
		heavySteps = { shake = 0.12, range = 26, dust = 10 },
		sounds = { step = "bossStep", death = "enemyDeath", roar = "bossRoar", phase = "chronicleChant" },
		attacks = {
			slash = atk("Slash", "enemyWindup", "swing3"),
			volley = atk("Volley", "pageRustle", "pageShot", { aim = true }),
			erase = atk("Erase", "chronicleChant", "riftErupt"),
			beam = atk("Beam", "bossCharge", "chronicleBeam"),
			rewrite = atk("Rewrite", "bossCharge", "slam", { dash = "Rewrite_Air", dashSound = "dash" }),
		},
		animIds = {},
	},
}

return EnemyVisuals45
