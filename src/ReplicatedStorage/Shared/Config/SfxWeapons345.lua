--!nonstrict
-- SfxWeapons345
-- Звуки способностей оружия этажей 3–5: Охота (hunt*), Горн (forge*),
-- Летопись (chron*). Источники те же, что в Sfx: Pro Sound Effects
-- (загрузки 91xxxxxxxx), APM и встроенные звуки движка. Sfx.lua подмешивает
-- эту таблицу в Sfx.sounds / Sfx.candidates / Sfx.picked.
--
-- Для ключевых звуков есть 2–3 варианта (candidates). Прослушать в Studio:
--   sfx <имя> <N>   — например «sfx huntPackHowl 2».
-- Понравившийся номер записать в picked ниже.

local M = {}

local PSE = {
	-- уже используемые в Sfx
	airWhoosh = "rbxassetid://9126283272",
	energyWhoosh = "rbxassetid://9125517884",
	waterImpact = "rbxassetid://9119481909",
	rockCrunch = "rbxassetid://9118633662",
	magicChime = "rbxassetid://9116394545",
	shieldClang1 = "rbxassetid://9119072660",
	metalClatter = "rbxassetid://9116524438",
	manacles = "rbxassetid://9116460113",
	metalRattle = "rbxassetid://9116797354",
	-- Охота
	wolfHowl = "rbxassetid://9120790529", -- Wolf Howl Two Versions 1
	wolfHowlBay = "rbxassetid://9120789309", -- Wolf Howl Bay 1
	wolfSnarl1 = "rbxassetid://9120790555", -- Wolf Snarl 1
	wolfSnarl2 = "rbxassetid://9120790847", -- Wolf Snarl 2
	biteCrunch = "rbxassetid://9125466770", -- Creature Bite Pterodactyl Crunch
	hawkScreech = "rbxassetid://9125598512", -- Hawk Screech
	wingsFlap = "rbxassetid://9114787449", -- Hawk Wings Flap
	metalPop2 = "rbxassetid://9116776395", -- Metal Pop Snap Stress 2
	metalPop3 = "rbxassetid://9116776425", -- Metal Pop Snap Stress 3
	chains1 = "rbxassetid://9113764330", -- Chains And Metal Impacts
	chains2 = "rbxassetid://9113764229",
	heavyWhoosh = "rbxassetid://9113077334", -- Air Whoosh Heavy Impacts
	-- Горн
	anvilRing1 = "rbxassetid://9125361455", -- Anvil Hits Ringing
	anvilRing2 = "rbxassetid://9113133597",
	anvilHammer1 = "rbxassetid://9113447467", -- Blacksmith Anvil Hammer Hits
	anvilHammer2 = "rbxassetid://9113445305",
	anvilClank = "rbxassetid://9113132828", -- Anvil Hit Sharp Clanks
	searing11 = "rbxassetid://9118882814", -- Searing Bursts 11
	searing5 = "rbxassetid://9118884046",
	searing7 = "rbxassetid://9118884310",
	airyHiss = "rbxassetid://9113079144", -- Airy Hiss Burst
	fireWhoosh15 = "rbxassetid://9114446852", -- Fire Whoosh 15
	fireWhoosh6 = "rbxassetid://9114446277",
	fireWhoosh13 = "rbxassetid://9114446802",
	fireWhoosh5 = "rbxassetid://9114444052",
	sizzle4 = "rbxassetid://9119165650", -- Sizzle Short Explosive Sear 4
	sizzle10 = "rbxassetid://9119166195",
	iceSizzle = "rbxassetid://9114858178", -- Ice Crack And Sizzle
	bubbling = "rbxassetid://9125498766", -- Drain Bubbling
	bubbles = "rbxassetid://9125409840",
	metalClunk1 = "rbxassetid://9116673678", -- Metal Impact Heavy Clunking
	metalClunk2 = "rbxassetid://9116673944",
	robotClang = "rbxassetid://9118269317", -- Robot Impact Clangy Heavy
	sandSilt = "rbxassetid://9118770617", -- Sand Silt 2
	-- Летопись
	pages1 = "rbxassetid://9118835414", -- Scrapbook Pages
	pages2 = "rbxassetid://9118835650",
	penScribble = "rbxassetid://9117286784", -- Pen Write Scribble
	pencil = "rbxassetid://9117277763", -- Pencil Scribbling
	glassSplat = "rbxassetid://9114615719", -- Glass Splat
	wetHit1 = "rbxassetid://9113520514", -- Body Hit Wet
	wetHit2 = "rbxassetid://9113520180",
	stamp1 = "rbxassetid://9114026047", -- Date Stamp Big Office Impact
	stamp2 = "rbxassetid://9125482971",
	iceFreeze = "rbxassetid://9125611419", -- Ice Freeze Crackles
	iceChunks = "rbxassetid://9114865805", -- Ice Hammer Chunks
	magicZoom = "rbxassetid://9125648149", -- Magic Zoom Up Whoosh
	magicShimmer = "rbxassetid://9125647212", -- Magic Whooshes Shimmering
	magicGrowly = "rbxassetid://9125646252", -- Magic Whooshes Growly
	tick1 = "rbxassetid://9114069409", -- Dial Switch Ticking
	tick2 = "rbxassetid://9114071134",
	deskBell = "rbxassetid://9125485591", -- Desk Bell
	sparkleBell = "rbxassetid://9126073001", -- Synth Sparkle Bell
	timerBell = "rbxassetid://9126102079", -- Timer Bell
	fallingShimmer = "rbxassetid://9116418035", -- Magic Tone Falling Shimmer
	fairyDust = "rbxassetid://9114369623", -- Fairy Dust 1
	ghostWind = "rbxassetid://9114574159", -- Ghost Wind (длинный, режем)
}

local APM = {
	massiveHit = "rbxassetid://9045192152",
	percHit = "rbxassetid://9045209987",
}

local ENGINE = {
	slash = "rbxasset://sounds/swordslash.wav",
	lunge = "rbxasset://sounds/swordlunge.wav",
	bass = "rbxasset://sounds/bass.wav",
	ping = "rbxasset://sounds/electronicpingshort.wav",
	click = "rbxasset://sounds/clickfast.wav",
	snap = "rbxasset://sounds/snap.mp3",
	splash = "rbxasset://sounds/impact_water.mp3",
}

local function layer(id: string, volume: number, pitchMin: number, pitchMax: number?, delay: number?, length: number?)
	return { id = id, volume = volume, pitch = { pitchMin, pitchMax or pitchMin }, delay = delay, length = length }
end

M.sounds = {
	-- ===== Охота =====
	huntPackHowl = { layer(PSE.wolfHowl, 0.45, 0.95, 1.05, nil, 2.2) },
	huntHoundSnarl = { layer(PSE.wolfSnarl1, 0.35, 1.0, 1.15, nil, 0.8) },
	huntBite = { layer(PSE.biteCrunch, 0.4, 1.05, 1.2, nil, 0.4), layer(APM.percHit, 0.25, 1.6, 1.8, nil, 0.2) },
	huntSnareOpen = { layer(PSE.metalRattle, 0.3, 1.3, 1.45, nil, 0.4), layer(PSE.chains1, 0.2, 1.1, 1.2, 0.05, 0.4) },
	huntSnareSnap = { layer(PSE.metalPop2, 0.5, 0.95, 1.05, nil, 0.5), layer(PSE.manacles, 0.3, 1.0, 1.1, 0.04, 0.6), layer(ENGINE.snap, 0.3, 0.8, 0.85) },
	huntDash = { layer(PSE.airWhoosh, 0.55, 1.0, 1.15, nil, 0.45), layer(ENGINE.lunge, 0.25, 1.1, 1.2) },
	huntPierce = { layer(PSE.shieldClang1, 0.25, 1.4, 1.6, nil, 0.3), layer(APM.percHit, 0.4, 1.3, 1.45, nil, 0.3) },
	-- рога у PSE нет: низкий синт-гул + бас + тяжёлый удар хвостом
	huntHorn = { layer(PSE.energyWhoosh, 0.45, 0.42, 0.45, nil, 1.6), layer(ENGINE.bass, 0.5, 0.45, 0.48, 0.05), layer(APM.massiveHit, 0.3, 0.7, 0.75, 0.1, 1.2) },
	huntFalconCry = { layer(PSE.hawkScreech, 0.4, 1.0, 1.1, nil, 1.4) },
	huntFalcon = { layer(PSE.wingsFlap, 0.35, 1.05, 1.2, nil, 0.6) },
	huntDiveImpact = { layer(PSE.heavyWhoosh, 0.5, 0.95, 1.05, nil, 0.8), layer(PSE.rockCrunch, 0.45, 0.85, 0.95, 0.05, 0.6), layer(ENGINE.bass, 0.35, 0.7, 0.75) },
	huntPreyMark = { layer(ENGINE.ping, 0.25, 0.85, 0.9), layer(PSE.wolfSnarl2, 0.15, 1.2, 1.3, 0.05, 0.4) },
	huntPreyKill = { layer(PSE.wolfHowlBay, 0.35, 1.1, 1.2, 0.05, 1.2), layer(APM.percHit, 0.4, 1.0, 1.1, nil, 0.35) },
	huntTalon = { layer(ENGINE.slash, 0.35, 1.35, 1.5), layer(PSE.biteCrunch, 0.2, 1.4, 1.6, nil, 0.25) },

	-- ===== Горн =====
	forgeSpillPour = { layer(PSE.bubbling, 0.35, 0.8, 0.9, nil, 1.0), layer(PSE.searing5, 0.3, 0.9, 1.0, 0.05, 0.8) },
	forgePourStart = { layer(PSE.fireWhoosh6, 0.4, 0.9, 1.0, nil, 0.8), layer(PSE.bubbles, 0.25, 0.7, 0.8, 0.1, 0.8) },
	forgePourWave = { layer(PSE.fireWhoosh13, 0.45, 0.85, 0.95, nil, 0.9), layer(PSE.searing7, 0.3, 0.95, 1.05, 0.05, 0.6) },
	forgeErupt = { layer(PSE.fireWhoosh15, 0.5, 0.8, 0.9, nil, 1.0), layer(PSE.rockCrunch, 0.35, 0.7, 0.8, 0.05, 0.6), layer(ENGINE.bass, 0.3, 0.6, 0.65) },
	forgeSteamSoft = { layer(PSE.airyHiss, 0.2, 1.1, 1.25, nil, 0.6) },
	forgeSteam = { layer(PSE.airyHiss, 0.35, 0.9, 1.0, nil, 1.0), layer(PSE.sizzle10, 0.2, 0.8, 0.9, 0.05, 0.6) },
	forgeOverheat = { layer(PSE.searing11, 0.4, 0.9, 1.0, nil, 1.0), layer(PSE.metalRattle, 0.2, 0.6, 0.7, nil, 0.8) },
	forgeBurst = { layer(PSE.fireWhoosh5, 0.55, 0.9, 1.0, nil, 0.9), layer(APM.massiveHit, 0.4, 1.1, 1.2, nil, 0.7), layer(PSE.sizzle4, 0.25, 0.9, 1.0, 0.08, 0.6) },
	forgeAnvilWhistle = { layer(PSE.airWhoosh, 0.45, 0.55, 0.6, nil, 0.8), layer(PSE.energyWhoosh, 0.2, 0.9, 1.0, nil, 0.8) },
	forgeAnvilImpact = { layer(PSE.anvilRing1, 0.55, 0.85, 0.95, nil, 1.4), layer(APM.massiveHit, 0.45, 0.9, 1.0, nil, 0.9), layer(PSE.rockCrunch, 0.35, 0.8, 0.9, 0.02, 0.5) },
	forgeBreath = { layer(PSE.fireWhoosh15, 0.5, 0.75, 0.85, nil, 1.3), layer(PSE.searing11, 0.25, 0.8, 0.9, 0.1, 1.0) },
	forgeSizzle = { layer(PSE.sizzle4, 0.25, 1.0, 1.15, nil, 0.5) },
	forgeEmberHigh = { layer(PSE.sizzle10, 0.2, 1.3, 1.45, nil, 0.4), layer(ENGINE.ping, 0.12, 1.6, 1.7) },
	forgeEmberBurst = { layer(PSE.searing7, 0.4, 1.0, 1.1, nil, 0.6), layer(APM.percHit, 0.3, 1.3, 1.4, nil, 0.3) },
	forgeSlagSpin = { layer(PSE.heavyWhoosh, 0.45, 0.85, 0.95, nil, 0.7), layer(PSE.fireWhoosh6, 0.25, 1.0, 1.1, 0.05, 0.6) },
	forgeSlagLand = { layer(PSE.metalClunk1, 0.45, 0.85, 0.95, nil, 0.6), layer(PSE.sizzle4, 0.3, 0.85, 0.95, 0.05, 0.6) },
	forgeTemperStack = { layer(PSE.anvilClank, 0.3, 1.2, 1.35, nil, 0.4) },
	forgeTemper = { layer(PSE.anvilHammer1, 0.45, 1.0, 1.1, nil, 0.7), layer(PSE.iceSizzle, 0.3, 1.0, 1.1, 0.08, 0.8) },
	forgeCrust = { layer(PSE.sandSilt, 0.3, 0.8, 0.9, nil, 0.6), layer(PSE.rockCrunch, 0.25, 1.1, 1.2, nil, 0.4) },
	forgeStageUp = { layer(PSE.anvilClank, 0.4, 1.1, 1.15, nil, 0.6), layer(ENGINE.ping, 0.2, 1.2, 1.25, 0.06) },
	forgeStageDown = { layer(PSE.metalClunk2, 0.35, 0.7, 0.8, nil, 0.6), layer(PSE.airyHiss, 0.2, 0.7, 0.8, 0.05, 0.6) },

	-- ===== Летопись =====
	chronQuill = { layer(PSE.penScribble, 0.35, 1.05, 1.2, nil, 0.6), layer(PSE.airWhoosh, 0.2, 1.4, 1.5, nil, 0.3) },
	chronRuneBurst = { layer(PSE.magicShimmer, 0.4, 1.0, 1.1, nil, 0.9), layer(APM.percHit, 0.3, 1.2, 1.3, nil, 0.3) },
	chronSealStamp = { layer(PSE.stamp1, 0.55, 0.85, 0.95, nil, 0.6), layer(PSE.magicChime, 0.2, 0.8, 0.85, 0.05, 0.8) },
	chronFreeze = { layer(PSE.iceFreeze, 0.35, 1.0, 1.1, nil, 1.0) },
	chronSealBreak = { layer(PSE.iceChunks, 0.45, 1.0, 1.1, nil, 0.7), layer(PSE.pages1, 0.25, 1.2, 1.3, 0.04, 0.5) },
	chronDomeStart = { layer(PSE.magicZoom, 0.45, 0.8, 0.85, nil, 1.2), layer(PSE.timerBell, 0.3, 0.75, 0.8, 0.1, 1.5), layer(ENGINE.bass, 0.3, 0.5, 0.55) },
	chronTick = { layer(PSE.tick1, 0.25, 1.0, 1.05, nil, 0.25) },
	chronDomeCollapse = { layer(PSE.fallingShimmer, 0.45, 0.9, 1.0, nil, 1.2), layer(APM.massiveHit, 0.35, 1.0, 1.1, 0.05, 0.8) },
	chronTimeEcho = { layer(PSE.magicShimmer, 0.25, 1.3, 1.4, nil, 0.6), layer(ENGINE.slash, 0.15, 0.6, 0.65, 0.05) },
	chronInkSplash = { layer(PSE.glassSplat, 0.35, 0.7, 0.8, nil, 0.6), layer(PSE.waterImpact, 0.35, 0.9, 1.0, 0.03, 0.6) },
	chronInkHit = { layer(PSE.wetHit1, 0.35, 1.0, 1.15, nil, 0.4) },
	chronInkStain = { layer(PSE.wetHit2, 0.25, 0.75, 0.85, nil, 0.5), layer(PSE.bubbles, 0.15, 1.2, 1.3, 0.05, 0.5) },
	chronErase = { layer(PSE.pencil, 0.35, 1.1, 1.25, nil, 0.5), layer(PSE.airWhoosh, 0.3, 0.9, 1.0, nil, 0.4) },
	chronErased = { layer(PSE.fallingShimmer, 0.35, 1.2, 1.3, nil, 0.8), layer(PSE.pages2, 0.25, 1.0, 1.1, 0.05, 0.6) },
	chronOblivion = { layer(PSE.ghostWind, 0.3, 0.9, 1.0, nil, 1.2), layer(PSE.magicGrowly, 0.25, 0.8, 0.9, 0.05, 0.8) },
	chronRecall = { layer(PSE.pages1, 0.4, 0.9, 1.0, nil, 0.8), layer(PSE.sparkleBell, 0.3, 0.9, 1.0, 0.1, 1.2) },
	chronEchoSwing = { layer(ENGINE.slash, 0.3, 0.75, 0.85), layer(PSE.magicShimmer, 0.15, 1.4, 1.5, nil, 0.4) },
	chronAfterimage = { layer(PSE.fairyDust, 0.2, 1.1, 1.2, nil, 0.6) },
	-- ===== Находки (слышат все игроки) =====
	-- Легендарка из сундука: удар-гонг, звон и искристый колокол.
	legendDrop = { layer(APM.massiveHit, 0.35, 0.6, 0.65, nil, 1.4), layer(PSE.magicChime, 0.4, 1.0, 1.05, 0.05, 1.2), layer(PSE.sparkleBell, 0.35, 1.0, 1.05, 0.2, 1.4) },
	-- Секретка: ниже и дольше, со «взлётом» и басом.
	secretDrop = { layer(ENGINE.bass, 0.5, 0.42, 0.45), layer(APM.massiveHit, 0.4, 0.5, 0.55, nil, 1.6), layer(PSE.magicZoom, 0.4, 0.85, 0.9, 0.05, 1.2), layer(PSE.sparkleBell, 0.4, 0.8, 0.85, 0.3, 1.6) },
}

-- Варианты для ключевых звуков (первый = M.sounds).
M.candidates = {
	huntPackHowl = {
		{ label = "Wolf Howl Two Versions 1", layers = M.sounds.huntPackHowl },
		{ label = "Wolf Howl Bay 1", layers = { layer(PSE.wolfHowlBay, 0.45, 0.95, 1.05, nil, 2.0) } },
		{ label = "Вой + рык стаи", layers = { layer(PSE.wolfHowl, 0.35, 1.05, 1.1, nil, 1.8), layer(PSE.wolfSnarl2, 0.3, 0.9, 1.0, 0.25, 0.8) } },
	},
	huntHorn = {
		{ label = "Синт-гул + бас + APM", layers = M.sounds.huntHorn },
		{ label = "APM massive hit низко", layers = { layer(APM.massiveHit, 0.5, 0.55, 0.6, nil, 1.6), layer(ENGINE.bass, 0.4, 0.4, 0.42) } },
		{ label = "Гул + вой вдали", layers = { layer(PSE.energyWhoosh, 0.4, 0.38, 0.4, nil, 1.6), layer(PSE.wolfHowlBay, 0.2, 0.7, 0.75, 0.2, 1.6) } },
	},
	forgeAnvilImpact = {
		{ label = "Anvil Ringing + APM", layers = M.sounds.forgeAnvilImpact },
		{ label = "Blacksmith Hammer + Clunk", layers = { layer(PSE.anvilHammer2, 0.55, 0.8, 0.9, nil, 1.0), layer(PSE.metalClunk2, 0.45, 0.8, 0.9, nil, 0.7), layer(ENGINE.bass, 0.35, 0.6, 0.65) } },
		{ label = "Robot Clangy Heavy", layers = { layer(PSE.robotClang, 0.55, 0.8, 0.9, nil, 1.0), layer(PSE.anvilRing2, 0.35, 0.9, 1.0, 0.03, 1.2) } },
	},
	forgeBreath = {
		{ label = "Fire Whoosh 15 + Searing", layers = M.sounds.forgeBreath },
		{ label = "Fire Whoosh 13 долгий", layers = { layer(PSE.fireWhoosh13, 0.5, 0.7, 0.75, nil, 1.4), layer(PSE.airyHiss, 0.25, 0.8, 0.9, 0.1, 1.0) } },
	},
	chronDomeStart = {
		{ label = "Zoom Up + Timer Bell", layers = M.sounds.chronDomeStart },
		{ label = "Shimmering + Desk Bell", layers = { layer(PSE.magicShimmer, 0.45, 0.75, 0.8, nil, 1.2), layer(PSE.deskBell, 0.35, 0.6, 0.65, 0.15, 1.5) } },
		{ label = "Growly + бас", layers = { layer(PSE.magicGrowly, 0.45, 0.7, 0.75, nil, 1.2), layer(ENGINE.bass, 0.4, 0.45, 0.5) } },
	},
	chronTick = {
		{ label = "Dial Switch Ticking 1", layers = M.sounds.chronTick },
		{ label = "Dial Switch Ticking 2", layers = { layer(PSE.tick2, 0.25, 1.0, 1.05, nil, 0.25) } },
		{ label = "Клик движка", layers = { layer(ENGINE.click, 0.3, 0.55, 0.6) } },
	},
	chronRecall = {
		{ label = "Pages + Sparkle Bell", layers = M.sounds.chronRecall },
		{ label = "Pages + Timer Bell", layers = { layer(PSE.pages2, 0.4, 0.9, 1.0, nil, 0.8), layer(PSE.timerBell, 0.3, 1.1, 1.2, 0.1, 1.2) } },
		{ label = "Falling Shimmer наоборот (высоко)", layers = { layer(PSE.fallingShimmer, 0.4, 1.4, 1.5, nil, 1.0), layer(PSE.magicChime, 0.25, 1.0, 1.1, 0.1, 0.8) } },
	},
}

M.picked = {
	huntPackHowl = 1,
	huntHorn = 1,
	forgeAnvilImpact = 1,
	forgeBreath = 1,
	chronDomeStart = 1,
	chronTick = 1,
	chronRecall = 1,
}

return M
