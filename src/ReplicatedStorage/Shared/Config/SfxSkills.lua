--!nonstrict
-- SfxSkills
-- Звуки «продлённых» фаз способностей (Controllers/AbilityFxPlus + AbilityFxPlusHunt / Forge / Chronicle,
-- Controllers/MageSpellFxPlus):
-- раскат удара, звон, хвосты (обломки, угли, капли, ветер, колокола). Играют поверх прежних
-- звуков способностей. Подмешиваются в Config/Sfx (блок в конце Sfx.lua).
-- Источник — только Pro Sound Effects (официальный партнёр Roblox, загрузки 91xxxxxxxx),
-- каждый id проверен: создатель — ProSoundEffects.
--
-- Слой: layer(id, громкость, высотаОт, высотаДо, задержка, длина, затухание, начало)
--   длина — обрезать хвост через N секунд; затухание — за сколько секунд погасить (по
--   умолчанию 0,35); начало — с какой секунды файла играть (TimePosition).
-- Заменить звук = поменять id здесь. Варианты на слух — SfxSkills.candidates
-- (команда «sfx <имя> <N>», выбранный номер — SfxSkills.picked).

local SfxSkills = {}

local PSE = {
	-- Нарастание / всасывание
	windSuck = "rbxassetid://9120768752", -- Wind Suck: ветер втягивается
	whooshyMagicSuck = "rbxassetid://9120746491", -- Whooshy Magic Suck
	lightConeSuck = "rbxassetid://9125626498", -- Light Cone Suck
	risingWhoosh = "rbxassetid://9125805758", -- Rising Whoosh
	timeWarpBuildBoom = "rbxassetid://9120057085", -- Time Warp Build + Boom
	energyBuild = "rbxassetid://9118747824", -- Energy Build
	-- Удары
	powerBoom1 = "rbxassetid://9117876319", -- Power Boom 1
	powerBoom2 = "rbxassetid://9117876706", -- Power Boom 2
	explosion2 = "rbxassetid://9114361853", -- Explosion 2
	explosion8 = "rbxassetid://9114362114", -- Explosion 8
	kerosene = "rbxassetid://9125615451", -- Kerosene Ignite Burst
	timeWarpBoom = "rbxassetid://9126102254", -- Time Warp Boom
	deepHitBoom = "rbxassetid://9125484367", -- Deep Hit Boom
	boomDistant = "rbxassetid://9125402735", -- Boom Distant
	thunderCrack = "rbxassetid://9116282544", -- Thunder Crack
	thunderBig = "rbxassetid://9120016241", -- Thunder Big
	thunderDistant = "rbxassetid://9120018050", -- Thunder Distant Rumble
	synthCrack = "rbxassetid://9126067628", -- Synth Crack
	rockBurst = "rbxassetid://9113223786", -- Rock Burst
	quakeBurst = "rbxassetid://9114221862", -- Earthquake Burst
	rockCrackDebris = "rbxassetid://9125869107", -- Rock Crack Debris
	giantSplash = "rbxassetid://9114586590", -- Giant Splash
	waterExplosion = "rbxassetid://9120548819", -- Water Explosion
	splashDeep = "rbxassetid://9119476512", -- Splash Deep
	waterBurst = "rbxassetid://9120502958", -- Water Burst
	magicBurst = "rbxassetid://9116384485", -- Magic Burst
	magicPoof = "rbxassetid://9116405510", -- Magic Poof
	whooshExplosion = "rbxassetid://9120705982", -- Whoosh Explosion
	mrTwister = "rbxassetid://9117034654", -- Mr Twister: вихрь
	glassBreak = "rbxassetid://9114590297", -- Glass Break
	iceShatter = "rbxassetid://9114855870", -- Ice Shatter
	chainsImpact = "rbxassetid://9113764229", -- Chains Impact
	shackles = "rbxassetid://9119030151", -- Shackles
	lockClick = "rbxassetid://9116324156", -- Lock Click
	shingRingy = "rbxassetid://9119076604", -- Shing Ringy: звон клинка
	shears = "rbxassetid://9125570952", -- Shears Cut
	woodSnap = "rbxassetid://9113581977", -- Wood Snap
	woodCrackle = "rbxassetid://9120818895", -- Wood Crackle
	squish = "rbxassetid://9126208985", -- Squish
	liquidSquish = "rbxassetid://9116319322", -- Liquid Squish
	metalBoom = "rbxassetid://9125668892", -- Metal Boom (длинный хвост — режем)
	gong = "rbxassetid://9114630316", -- Gong
	-- Хвосты
	rockDebris = "rbxassetid://9118586292", -- Rock Debris
	debrisSprinkle = "rbxassetid://9114035253", -- Debris Sprinkle
	debrisRain = "rbxassetid://9114034724", -- Debris Rain
	crumbleDeep = "rbxassetid://9113218732", -- Crumble Deep
	fireplace = "rbxassetid://9112780193", -- Fireplace (36 с — режем)
	lavaRumble = "rbxassetid://9112823197", -- Lava Rumble
	lavaFire = "rbxassetid://9112822944", -- Lava Fire
	sizzleSear = "rbxassetid://9119165436", -- Sizzle Sear
	fry = "rbxassetid://9114542867", -- Fry
	iceSizzle = "rbxassetid://9114858178", -- Ice Sizzle: пар
	fallingShimmer2 = "rbxassetid://9116417884", -- Falling Shimmer 2
	sparkleExit = "rbxassetid://9125635266", -- Sparkle Exit
	windChimesTree = "rbxassetid://9119447936", -- Wind Chimes Tree
	windChimes = "rbxassetid://9120749869", -- Wind Chimes
	pixieTwinkle = "rbxassetid://9116396436", -- Pixie Twinkle
	heavenly = "rbxassetid://9125602386", -- Heavenly
	churchBellSting = "rbxassetid://9126005605", -- Church Bell Sting
	timeWaveSlow = "rbxassetid://9120059060", -- Time Wave Slow
	timeRipple = "rbxassetid://9120061266", -- Time Ripple
	windHowlTail = "rbxassetid://9120697823", -- Wind Howl Tail
	eerieWindSwell = "rbxassetid://9114229142", -- Eerie Wind Swell
	leavesFall = "rbxassetid://9116258037", -- Leaves Fall
	leavesSlide = "rbxassetid://9116258312", -- Leaves Slide
	dripCave = "rbxassetid://9126190246", -- Drip Cave
	dripDistant = "rbxassetid://9126179016", -- Drip Distant
	drain = "rbxassetid://9125498759", -- Drain
	waterMovement = "rbxassetid://9126195470", -- Water Movement
	thickBubbles = "rbxassetid://9119223551", -- Thick Bubbles
	owl = "rbxassetid://9117181540", -- Owl
	paperFlutter = "rbxassetid://9113726628", -- Paper Flutter
	bookClose = "rbxassetid://9113549320", -- Book Close
	paperCrumble = "rbxassetid://9117205895", -- Paper Crumble
	keysJingle = "rbxassetid://9113849492", -- Keys Jingle
	metalDebris = "rbxassetid://9116555190", -- Metal Debris
	chainRattleGlassy = "rbxassetid://9113763589", -- Chain Rattle Glassy
	spiritPass = "rbxassetid://9125988214", -- Spirit Pass
	whisperBurst = "rbxassetid://9126213744", -- Whisper Burst
	crystalOminous = "rbxassetid://9125718987", -- Crystal Ominous
	electricArc = "rbxassetid://9114237976", -- Electric Arc
	dischargeSizzle = "rbxassetid://9114235024", -- Discharge Sizzle
	swishSpin = "rbxassetid://9119706123", -- Swish Spin
	energyField = "rbxassetid://9114330786", -- Energy Field
	cloudsSwirl = "rbxassetid://9125443744", -- Clouds Swirl
	-- Этажи 3–5: те же проверенные Pro Sound Effects, что в Config/SfxWeapons345
	ghostWind = "rbxassetid://9114574159", -- Ghost Wind (длинный — режем)
	wolfHowlBay = "rbxassetid://9120789309", -- Wolf Howl Bay 1
	wolfSnarl2 = "rbxassetid://9120790847", -- Wolf Snarl 2
	biteCrunch = "rbxassetid://9125466770", -- Creature Bite Crunch
	wingsFlap = "rbxassetid://9114787449", -- Hawk Wings Flap
	heavyWhoosh = "rbxassetid://9113077334", -- Air Whoosh Heavy Impacts
	metalPop3 = "rbxassetid://9116776425", -- Metal Pop Snap Stress 3
	metalRattle = "rbxassetid://9116797354", -- Metal Rattle
	manacles = "rbxassetid://9116460113", -- Manacles
	chainsMetal = "rbxassetid://9113764330", -- Chains And Metal Impacts
	rockCrunch = "rbxassetid://9118633662", -- Rock Crunch
	anvilRing = "rbxassetid://9125361455", -- Anvil Hits Ringing
	anvilClank = "rbxassetid://9113132828", -- Anvil Hit Sharp Clanks
	robotClang = "rbxassetid://9118269317", -- Robot Impact Clangy Heavy
	searing11 = "rbxassetid://9118882814", -- Searing Bursts 11
	searing7 = "rbxassetid://9118884310", -- Searing Bursts 7
	sizzle4 = "rbxassetid://9119165650", -- Sizzle Short Explosive Sear 4
	sizzle10 = "rbxassetid://9119166195", -- Sizzle Short Explosive Sear 10
	airyHiss = "rbxassetid://9113079144", -- Airy Hiss Burst
	fireWhoosh5 = "rbxassetid://9114444052", -- Fire Whoosh 5
	fireWhoosh6 = "rbxassetid://9114446277", -- Fire Whoosh 6
	fireWhoosh15 = "rbxassetid://9114446852", -- Fire Whoosh 15
	bubbling = "rbxassetid://9125498766", -- Drain Bubbling
	penScribble = "rbxassetid://9117286784", -- Pen Write Scribble
	pages = "rbxassetid://9118835414", -- Scrapbook Pages
	glassSplat = "rbxassetid://9114615719", -- Glass Splat
	stampBig = "rbxassetid://9114026047", -- Date Stamp Big Office Impact
	stamp2 = "rbxassetid://9125482971", -- Date Stamp 2
	iceFreeze = "rbxassetid://9125611419", -- Ice Freeze Crackles
	iceChunks = "rbxassetid://9114865805", -- Ice Hammer Chunks
	magicZoom = "rbxassetid://9125648149", -- Magic Zoom Up Whoosh
	magicShimmer = "rbxassetid://9125647212", -- Magic Whooshes Shimmering
	sandSilt = "rbxassetid://9118770617", -- Sand Silt 2
	fallingShimmer = "rbxassetid://9116418035", -- Magic Tone Falling Shimmer
}
SfxSkills.PSE = PSE

local function layer(id: string, volume: number, pitchMin: number, pitchMax: number?, delay: number?, length: number?, fade: number?, from: number?)
	return { id = id, volume = volume, pitch = { pitchMin, pitchMax or pitchMin }, delay = delay, length = length, fade = fade, from = from }
end

SfxSkills.sounds = {
	-- ===== Воин =====
	-- Вихрь
	fxVortexSuck = { layer(PSE.windSuck, 0.3, 1.1, 1.2, nil, 1.4, 0.5), layer(PSE.whooshyMagicSuck, 0.16, 1.2, 1.3, 0.1, 1.2, 0.5) },
	fxVortexTail = { layer(PSE.windHowlTail, 0.24, 1.0, 1.1, 0.2, 3.0, 1.2), layer(PSE.leavesFall, 0.2, 1.0, 1.1, 0.4, 2.5, 1.0) },
	-- Разлом
	fxRiftSlam = { layer(PSE.deepHitBoom, 0.5, 0.95, 1.05, nil, 1.5, 0.6), layer(PSE.rockBurst, 0.34, 1.0, 1.1, nil, 1.0) },
	fxRiftRumble = { layer(PSE.rockCrackDebris, 0.2, 0.8, 0.85, nil, 1.4, 0.6) },
	fxSpikeCrumble = { layer(PSE.crumbleDeep, 0.3, 1.0, 1.15, nil, 1.6, 0.6), layer(PSE.debrisSprinkle, 0.24, 1.0, 1.1, 0.2, 1.6, 0.6) },
	fxRiftTail = { layer(PSE.rockDebris, 0.24, 1.0, 1.1, nil, 2.2, 0.8), layer(PSE.lavaRumble, 0.2, 1.0, 1.0, nil, 3.0, 1.2), layer(PSE.sizzleSear, 0.16, 1.0, 1.1, 0.5, 2.0, 1.0) },
	-- Отпереть / скважина
	fxKeyGlint = { layer(PSE.shingRingy, 0.28, 1.2, 1.3, nil, 0.8) },
	fxKeyLock = { layer(PSE.chainsImpact, 0.4, 1.0, 1.1, nil, 1.2), layer(PSE.lockClick, 0.4, 0.9, 0.95, 0.08) },
	fxKeyTail = { layer(PSE.chainRattleGlassy, 0.22, 1.0, 1.1, 0.2, 2.0, 0.8), layer(PSE.sparkleExit, 0.24, 1.0, 1.05, 0.3, 2.0, 0.8), layer(PSE.keysJingle, 0.2, 1.0, 1.1, 0.9, 1.2, 0.5) },
	fxKeyhole = { layer(PSE.lockClick, 0.3, 1.1, 1.2), layer(PSE.magicPoof, 0.3, 1.0, 1.1, nil, 0.8) },
	-- Сады: жатва, паводок, обрезка, цветение
	fxReap = { layer(PSE.shears, 0.35, 0.9, 0.95, nil, 0.8), layer(PSE.shingRingy, 0.24, 0.8, 0.85, nil, 1.0) },
	fxReapTail = { layer(PSE.leavesSlide, 0.22, 1.0, 1.1, nil, 2.0, 0.8), layer(PSE.whisperBurst, 0.16, 1.0, 1.1, 0.3, 1.5, 0.6) },
	fxRotTail = { layer(PSE.thickBubbles, 0.18, 1.0, 1.1, nil, 2.5, 1.0) },
	fxFloodTail = { layer(PSE.dripCave, 0.25, 1.0, 1.1, nil, 3.0, 1.2), layer(PSE.waterMovement, 0.2, 1.0, 1.0, nil, 2.5, 1.0) },
	fxFloodDrain = { layer(PSE.drain, 0.3, 1.0, 1.1, nil, 2.5, 1.0), layer(PSE.iceSizzle, 0.14, 1.0, 1.1, 0.3, 1.8, 0.8) },
	fxPruneTail = { layer(PSE.woodSnap, 0.28, 1.0, 1.15), layer(PSE.leavesFall, 0.22, 1.0, 1.1, 0.2, 2.5, 1.0) },
	fxBloom = { layer(PSE.magicBurst, 0.34, 1.0, 1.1, nil, 1.2), layer(PSE.windChimes, 0.25, 1.0, 1.05, 0.15, 2.5, 1.0) },
	fxBloomTail = { layer(PSE.pixieTwinkle, 0.22, 1.0, 1.1, nil, 2.0, 0.8), layer(PSE.leavesFall, 0.18, 1.1, 1.2, nil, 2.5, 1.0) },

	-- ===== Маг =====
	fxWardBuild = { layer(PSE.energyBuild, 0.24, 1.0, 1.1, nil, 1.2, 0.4) },
	fxWardBurst = { layer(PSE.magicBurst, 0.4, 1.0, 1.05, nil, 1.3), layer(PSE.powerBoom2, 0.28, 1.2, 1.3, nil, 1.0) },
	fxWardEnd = { layer(PSE.lightConeSuck, 0.26, 1.1, 1.2, nil, 1.0, 0.4), layer(PSE.sparkleExit, 0.24, 1.0, 1.05, 0.45, 1.8, 0.8) },
	fxSignalTail = { layer(PSE.fireplace, 0.22, 1.0, 1.05, 0.3, 4.0, 1.5), layer(PSE.fry, 0.14, 1.0, 1.1, nil, 3.0, 1.2) },
	fxSignalEnd = { layer(PSE.sizzleSear, 0.22, 1.0, 1.1, nil, 2.0, 0.8), layer(PSE.boomDistant, 0.18, 1.0, 1.0, nil, 2.5, 1.0) },
	fxGateSurge = { layer(PSE.risingWhoosh, 0.3, 1.0, 1.1, nil, 1.2), layer(PSE.heavenly, 0.3, 1.0, 1.0, nil, 2.5, 1.0) },
	fxGateClose = { layer(PSE.glassBreak, 0.3, 1.1, 1.2, nil, 1.2), layer(PSE.churchBellSting, 0.3, 1.0, 1.0, 0.05, 3.0, 1.2) },
	fxGateTail = { layer(PSE.fallingShimmer2, 0.24, 1.0, 1.05, nil, 2.5, 1.0), layer(PSE.windChimes, 0.18, 1.1, 1.15, 0.3, 2.5, 1.0) },
	fxLotusGeyser = { layer(PSE.waterExplosion, 0.45, 1.0, 1.05, nil, 1.8, 0.7), layer(PSE.giantSplash, 0.3, 1.05, 1.1, 0.05, 1.8, 0.7) },
	fxLotusTail = { layer(PSE.dripDistant, 0.25, 1.0, 1.1, nil, 3.0, 1.2), layer(PSE.windChimes, 0.2, 1.2, 1.25, 0.2, 2.5, 1.0) },
	fxMycelPop = { layer(PSE.squish, 0.34, 0.9, 1.05), layer(PSE.magicPoof, 0.28, 1.0, 1.15, nil, 0.8) },
	fxMycelTail = { layer(PSE.cloudsSwirl, 0.2, 1.0, 1.1, nil, 2.5, 1.0), layer(PSE.whisperBurst, 0.15, 1.1, 1.2, 0.2, 1.5, 0.6) },
	fxThornRing = { layer(PSE.woodCrackle, 0.3, 1.0, 1.15, nil, 1.2, 0.4) },
	fxThornGarden = { layer(PSE.rockBurst, 0.34, 1.1, 1.2, nil, 1.0), layer(PSE.woodSnap, 0.3, 0.9, 1.0) },
	fxThornEnd = { layer(PSE.woodCrackle, 0.3, 0.9, 1.0, nil, 1.8, 0.6), layer(PSE.crumbleDeep, 0.24, 1.1, 1.2, nil, 1.8, 0.6), layer(PSE.leavesFall, 0.2, 1.0, 1.1, 0.3, 2.5, 1.0) },
	fxMoonBeam = { layer(PSE.synthCrack, 0.24, 1.2, 1.3, nil, 0.8) },
	fxMoonTail = { layer(PSE.eerieWindSwell, 0.2, 1.0, 1.1, nil, 3.0, 1.2), layer(PSE.fallingShimmer2, 0.22, 0.9, 0.95, nil, 2.5, 1.0), layer(PSE.owl, 0.22, 1.0, 1.05, 0.6, 2.5, 1.0) },
	fxRainMeteor = { layer(PSE.explosion8, 0.16, 1.1, 1.3, nil, 1.0, 0.4) },
	fxRainEnd = { layer(PSE.sizzleSear, 0.24, 1.0, 1.1, nil, 2.5, 1.0), layer(PSE.fireplace, 0.18, 1.0, 1.0, nil, 3.5, 1.5), layer(PSE.boomDistant, 0.2, 1.0, 1.0, 0.1, 2.0, 0.8) },
	fxForgedChain = { layer(PSE.electricArc, 0.25, 1.1, 1.25, nil, 0.7) },
	fxForgedTail = { layer(PSE.thunderDistant, 0.3, 1.0, 1.0, 0.7, 4.0, 1.5), layer(PSE.dischargeSizzle, 0.2, 1.0, 1.1, nil, 2.0, 0.8) },
	fxForgePillar = { layer(PSE.lavaFire, 0.24, 1.0, 1.15, nil, 1.5, 0.6) },
	fxForgeWall = { layer(PSE.lavaRumble, 0.3, 1.0, 1.05, nil, 2.5, 1.0), layer(PSE.metalDebris, 0.2, 1.0, 1.1, 0.2, 1.2) },
	fxForgeEnd = { layer(PSE.metalBoom, 0.28, 0.9, 0.95, nil, 3.0, 1.5), layer(PSE.iceSizzle, 0.24, 1.0, 1.05, nil, 2.5, 1.0), layer(PSE.sizzleSear, 0.18, 1.0, 1.1, 0.3, 2.0, 0.8) },
	fxMeteorTail = { layer(PSE.lavaRumble, 0.25, 0.9, 0.95, nil, 4.0, 1.5), layer(PSE.fry, 0.18, 1.0, 1.05, nil, 3.0, 1.2), layer(PSE.crumbleDeep, 0.2, 1.0, 1.1, 1.0, 2.0, 0.8) },
	fxMeteorEnd = { layer(PSE.iceSizzle, 0.28, 0.9, 1.0, nil, 2.5, 1.0), layer(PSE.sizzleSear, 0.2, 1.0, 1.05, nil, 2.0, 0.8) },
	fxFirstRift = { layer(PSE.rockCrackDebris, 0.34, 1.0, 1.1, nil, 1.5, 0.6), layer(PSE.lavaFire, 0.24, 1.0, 1.1, nil, 1.5, 0.6) },
	fxFirstTail = { layer(PSE.lavaRumble, 0.22, 1.0, 1.05, nil, 3.0, 1.2), layer(PSE.metalDebris, 0.22, 1.0, 1.1, 0.3, 1.5), layer(PSE.sizzleSear, 0.15, 1.0, 1.1, 0.6, 2.0, 0.8) },
	fxTomeStorm = { layer(PSE.paperFlutter, 0.34, 1.0, 1.1, nil, 2.0, 0.8), layer(PSE.magicBurst, 0.3, 1.1, 1.2, nil, 1.2) },
	fxTomeEnd = { layer(PSE.paperCrumble, 0.22, 1.0, 1.1, nil, 1.5, 0.6), layer(PSE.bookClose, 0.45, 0.95, 1.0, 0.4, 1.2) },
	fxTimeCast = { layer(PSE.timeWaveSlow, 0.28, 1.0, 1.0, nil, 2.0, 0.8) },
	fxTimeFreeze = { layer(PSE.timeRipple, 0.34, 1.0, 1.0, nil, 2.0, 0.8), layer(PSE.crystalOminous, 0.24, 1.0, 1.05, nil, 2.5, 1.0) },
	fxTimeTail = { layer(PSE.churchBellSting, 0.28, 0.9, 0.9, 0.25, 3.5, 1.5), layer(PSE.fallingShimmer2, 0.2, 1.0, 1.05, nil, 2.5, 1.0) },
	fxFateTail = { layer(PSE.fireplace, 0.2, 1.05, 1.1, nil, 3.0, 1.2), layer(PSE.paperCrumble, 0.18, 1.0, 1.1, 0.4, 1.5, 0.6) },
	fxInkOpen = { layer(PSE.whooshyMagicSuck, 0.3, 0.9, 0.95, nil, 2.0, 0.8), layer(PSE.thickBubbles, 0.24, 0.9, 1.0, nil, 2.0, 0.8) },
	fxInkTail = { layer(PSE.dripCave, 0.22, 0.9, 1.0, nil, 3.0, 1.2), layer(PSE.iceSizzle, 0.15, 1.1, 1.2, 0.8, 2.0, 1.0) },
	fxRecallBeams = { layer(PSE.spiritPass, 0.3, 1.0, 1.1, nil, 1.5, 0.6) },
	fxRecallStorm = { layer(PSE.magicBurst, 0.4, 0.95, 1.0, nil, 1.4), layer(PSE.timeWarpBoom, 0.34, 1.0, 1.05, nil, 2.0, 0.8) },
	fxRecallTail = { layer(PSE.crystalOminous, 0.22, 1.0, 1.05, nil, 3.0, 1.2), layer(PSE.sparkleExit, 0.24, 1.0, 1.05, 0.3, 2.0, 0.8), layer(PSE.whisperBurst, 0.18, 1.0, 1.1, 0.6, 1.5, 0.6) },

	-- ===== Этаж 3: Охота (AbilityFxPlusHunt) =====
	-- Тихо, поверх huntPackHowl / huntBite / huntHorn…: эхо стаи, шорох листвы, хвосты.
	fxHuntHowlTail = { layer(PSE.wolfHowlBay, 0.14, 0.85, 0.9, 0.1, 2.4, 1.0), layer(PSE.ghostWind, 0.14, 1.0, 1.1, nil, 2.5, 1.0) },
	fxHuntBite = { layer(PSE.biteCrunch, 0.2, 1.25, 1.4, nil, 0.4), layer(PSE.wolfSnarl2, 0.1, 1.2, 1.3, nil, 0.5, 0.2) },
	fxHuntFade = { layer(PSE.spiritPass, 0.16, 1.1, 1.2, nil, 1.2, 0.5), layer(PSE.fallingShimmer2, 0.12, 1.1, 1.2, 0.05, 1.5, 0.6) },
	fxHuntSnareTense = { layer(PSE.chainRattleGlassy, 0.2, 0.8, 0.9, nil, 0.6, 0.2), layer(PSE.metalRattle, 0.14, 1.1, 1.2, 0.05, 0.5, 0.2) },
	fxHuntSnareTail = { layer(PSE.metalRattle, 0.16, 0.9, 0.95, 0.3, 1.2, 0.5), layer(PSE.debrisSprinkle, 0.18, 1.0, 1.1, nil, 1.6, 0.6), layer(PSE.leavesFall, 0.14, 1.0, 1.1, 0.4, 2.0, 0.8) },
	fxHuntChainDrop = { layer(PSE.chainsMetal, 0.2, 1.1, 1.2, nil, 0.8, 0.3) },
	fxHuntDashRush = { layer(PSE.heavyWhoosh, 0.28, 1.1, 1.2, nil, 0.8, 0.3), layer(PSE.windHowlTail, 0.14, 1.2, 1.3, 0.1, 1.0, 0.4) },
	fxHuntDashTail = { layer(PSE.leavesSlide, 0.2, 1.0, 1.1, nil, 2.0, 0.8), layer(PSE.windHowlTail, 0.16, 1.0, 1.1, 0.2, 2.5, 1.0) },
	fxHuntPierce = { layer(PSE.shingRingy, 0.22, 1.3, 1.4, nil, 0.6, 0.25), layer(PSE.powerBoom1, 0.16, 1.5, 1.6, nil, 0.5, 0.2) },
	fxHuntHornTail = { layer(PSE.windHowlTail, 0.2, 0.8, 0.85, nil, 3.0, 1.2), layer(PSE.leavesFall, 0.18, 1.0, 1.1, 0.3, 2.5, 1.0), layer(PSE.wolfHowlBay, 0.1, 0.75, 0.8, 0.6, 2.0, 1.0) },
	fxHuntDiveWind = { layer(PSE.risingWhoosh, 0.22, 1.1, 1.2, nil, 0.8, 0.3), layer(PSE.wingsFlap, 0.2, 1.0, 1.1, nil, 0.8) },
	fxHuntDiveTail = { layer(PSE.debrisSprinkle, 0.24, 1.0, 1.1, 0.15, 1.8, 0.7), layer(PSE.wingsFlap, 0.16, 0.9, 0.95, 0.5, 0.8), layer(PSE.leavesFall, 0.16, 1.0, 1.1, 0.4, 2.5, 1.0) },
	fxHuntMark = { layer(PSE.shingRingy, 0.12, 1.6, 1.7, nil, 0.5, 0.2) },
	fxHuntTrophy = { layer(PSE.sparkleExit, 0.2, 1.0, 1.05, nil, 1.8, 0.7), layer(PSE.whisperBurst, 0.14, 1.0, 1.1, 0.1, 1.2, 0.5) },
	fxHuntTalonTail = { layer(PSE.wingsFlap, 0.18, 1.1, 1.2, 0.05, 0.8), layer(PSE.paperFlutter, 0.1, 1.4, 1.5, 0.1, 0.8, 0.3) },

	-- ===== Этаж 4: Литейные (AbilityFxPlusForge) =====
	fxForgePourHiss = { layer(PSE.sizzleSear, 0.2, 1.0, 1.1, nil, 1.6, 0.6), layer(PSE.lavaFire, 0.16, 1.0, 1.1, nil, 1.5, 0.6) },
	fxForgePoolTail = { layer(PSE.fireplace, 0.14, 1.0, 1.05, nil, 3.0, 1.2), layer(PSE.fry, 0.12, 1.0, 1.1, 0.2, 2.5, 1.0) },
	fxForgeCool = { layer(PSE.iceSizzle, 0.22, 1.0, 1.1, nil, 1.8, 0.7), layer(PSE.airyHiss, 0.12, 1.0, 1.1, 0.2, 1.0, 0.4) },
	fxForgeHeatHum = { layer(PSE.lavaRumble, 0.16, 1.0, 1.05, nil, 3.0, 1.2) },
	fxForgeHandCool = { layer(PSE.iceSizzle, 0.2, 1.1, 1.2, nil, 1.4, 0.6), layer(PSE.airyHiss, 0.12, 1.1, 1.2, nil, 0.8, 0.3) },
	fxForgePop = { layer(PSE.sizzle4, 0.22, 1.0, 1.1, nil, 0.8, 0.3), layer(PSE.powerBoom1, 0.14, 1.4, 1.5, nil, 0.6, 0.25) },
	fxForgeAnvilFall = { layer(PSE.heavyWhoosh, 0.28, 0.8, 0.9, nil, 0.8, 0.3) },
	fxForgeAnvilTail = { layer(PSE.rockDebris, 0.24, 1.0, 1.1, 0.1, 2.2, 0.8), layer(PSE.lavaRumble, 0.18, 1.0, 1.05, nil, 3.0, 1.2), layer(PSE.metalDebris, 0.16, 1.0, 1.1, 1.0, 1.4, 0.5) },
	fxForgeBreathRoar = { layer(PSE.lavaFire, 0.2, 1.0, 1.1, nil, 1.6, 0.6), layer(PSE.fireplace, 0.14, 1.0, 1.05, 0.6, 2.5, 1.0) },
	fxForgeBreathEnd = { layer(PSE.fry, 0.16, 1.0, 1.1, nil, 2.0, 0.8), layer(PSE.airyHiss, 0.12, 0.9, 1.0, nil, 1.0, 0.4) },
	fxForgeEmberPop = { layer(PSE.kerosene, 0.2, 1.2, 1.3, nil, 0.8, 0.3), layer(PSE.sizzle10, 0.16, 1.0, 1.1, nil, 0.8, 0.3) },
	fxForgeSlagWhirl = { layer(PSE.swishSpin, 0.22, 1.0, 1.1, nil, 0.8, 0.3), layer(PSE.fireWhoosh6, 0.16, 1.2, 1.3, nil, 0.7, 0.3) },
	fxForgeSlagSplat = { layer(PSE.liquidSquish, 0.22, 0.75, 0.85), layer(PSE.sizzle10, 0.18, 1.0, 1.1, 0.05, 0.8, 0.3) },
	fxForgeSlagCool = { layer(PSE.iceSizzle, 0.18, 0.9, 1.0, nil, 1.6, 0.6), layer(PSE.crumbleDeep, 0.12, 1.2, 1.3, 0.2, 1.2, 0.5) },
	fxForgeCrustTail = { layer(PSE.rockCrackDebris, 0.16, 1.2, 1.3, nil, 1.0, 0.4), layer(PSE.debrisSprinkle, 0.14, 1.1, 1.2, 0.1, 1.2, 0.5) },
	fxForgeStage = { layer(PSE.anvilClank, 0.16, 1.2, 1.3, nil, 0.6, 0.25), layer(PSE.sparkleExit, 0.12, 1.2, 1.3, 0.05, 1.0, 0.4) },
	fxForgeStageLost = { layer(PSE.iceSizzle, 0.16, 1.1, 1.2, nil, 1.0, 0.4) },
	fxForgePourBuild = { layer(PSE.lavaRumble, 0.22, 1.0, 1.1, nil, 1.6, 0.6), layer(PSE.energyBuild, 0.14, 0.8, 0.85, nil, 1.0, 0.4) },
	fxForgeSteamTail = { layer(PSE.airyHiss, 0.2, 0.9, 1.0, nil, 1.5, 0.6), layer(PSE.iceSizzle, 0.18, 0.9, 1.0, 0.2, 2.0, 0.8), layer(PSE.bubbling, 0.12, 0.9, 1.0, 0.4, 1.6, 0.6) },

	-- ===== Этаж 5: Архив Хроник (AbilityFxPlusChronicle) =====
	fxChronScribe = { layer(PSE.penScribble, 0.2, 1.1, 1.2, nil, 0.8, 0.3), layer(PSE.paperFlutter, 0.14, 1.2, 1.3, 0.1, 0.8, 0.3) },
	fxChronRuneTail = { layer(PSE.whisperBurst, 0.16, 1.0, 1.1, nil, 1.5, 0.6), layer(PSE.paperCrumble, 0.14, 1.0, 1.1, 0.2, 1.2, 0.5), layer(PSE.fallingShimmer, 0.12, 1.0, 1.05, 0.3, 1.6, 0.6) },
	fxChronFreezeTail = { layer(PSE.iceFreeze, 0.18, 1.0, 1.05, nil, 2.0, 0.8), layer(PSE.crystalOminous, 0.14, 1.0, 1.05, nil, 2.5, 1.0) },
	fxChronShatter = { layer(PSE.glassBreak, 0.24, 1.1, 1.2, nil, 1.2, 0.5), layer(PSE.iceChunks, 0.16, 1.1, 1.2, nil, 0.8, 0.3) },
	fxChronDomeHum = { layer(PSE.timeWaveSlow, 0.2, 0.9, 0.95, nil, 2.5, 1.0), layer(PSE.energyField, 0.12, 0.8, 0.85, nil, 3.0, 1.2) },
	fxChronDomeTail = { layer(PSE.fallingShimmer2, 0.2, 1.0, 1.05, nil, 2.5, 1.0), layer(PSE.crystalOminous, 0.14, 1.0, 1.05, nil, 3.0, 1.2), layer(PSE.sandSilt, 0.16, 1.0, 1.1, 0.3, 2.0, 0.8) },
	fxChronEcho = { layer(PSE.timeRipple, 0.16, 1.2, 1.3, nil, 1.0, 0.4) },
	fxChronInkTail = { layer(PSE.dripCave, 0.18, 0.85, 0.9, nil, 2.5, 1.0), layer(PSE.thickBubbles, 0.1, 0.9, 1.0, nil, 2.0, 0.8) },
	fxChronStain = { layer(PSE.squish, 0.12, 1.2, 1.3, nil, 0.4) },
	fxChronErasedTail = { layer(PSE.whisperBurst, 0.18, 1.0, 1.1, nil, 1.5, 0.6), layer(PSE.paperCrumble, 0.16, 1.0, 1.1, nil, 1.2, 0.5), layer(PSE.sparkleExit, 0.12, 1.1, 1.2, 0.2, 1.6, 0.6) },
	fxChronEraseSweep = { layer(PSE.paperFlutter, 0.2, 1.1, 1.2, nil, 1.0, 0.4), layer(PSE.magicShimmer, 0.16, 1.1, 1.2, nil, 1.0, 0.4) },
	fxChronOblivionTail = { layer(PSE.whisperBurst, 0.14, 0.8, 0.85, nil, 1.6, 0.6), layer(PSE.eerieWindSwell, 0.12, 1.0, 1.1, nil, 2.0, 0.8) },
	fxChronRecallRise = { layer(PSE.magicZoom, 0.2, 1.0, 1.1, nil, 1.2, 0.5), layer(PSE.spiritPass, 0.16, 1.0, 1.1, 0.1, 1.4, 0.6) },
	fxChronEchoSlash = { layer(PSE.shingRingy, 0.14, 1.3, 1.4, nil, 0.6, 0.25) },
	fxChronMemoryTail = { layer(PSE.crystalOminous, 0.18, 1.0, 1.05, nil, 2.5, 1.0), layer(PSE.sparkleExit, 0.2, 1.0, 1.05, 0.3, 2.0, 0.8), layer(PSE.pages, 0.14, 1.0, 1.1, 0.5, 1.0, 0.4) },
	fxChronGhostSlash = { layer(PSE.magicShimmer, 0.14, 1.2, 1.3, nil, 0.8, 0.3) },
}

-- Ключевые удары — с вариантами на слух. «sfx fxVortexWave 2» — выбрать и проиграть.
SfxSkills.candidates = {
	fxVortexWave = {
		{ label = "силовой бум + взрыв-вихрь", layers = { layer(PSE.powerBoom1, 0.45, 1.0, 1.1, nil, 1.6, 0.6), layer(PSE.whooshExplosion, 0.34, 1.0, 1.1, nil, 1.2) } },
		{ label = "бум 2 + торнадо", layers = { layer(PSE.powerBoom2, 0.45, 1.0, 1.05, nil, 1.6, 0.6), layer(PSE.mrTwister, 0.3, 1.0, 1.1, nil, 1.6, 0.6) } },
		{ label = "глухой удар + взрыв-вихрь", layers = { layer(PSE.deepHitBoom, 0.5, 1.0, 1.1, nil, 1.5, 0.6), layer(PSE.whooshExplosion, 0.3, 1.1, 1.2, nil, 1.2) } },
	},
	fxRiftErupt = {
		{ label = "землетрясение + разлёт камней", layers = { layer(PSE.quakeBurst, 0.5, 1.0, 1.05, nil, 1.8, 0.7), layer(PSE.rockBurst, 0.4, 0.9, 1.0, nil, 1.2) } },
		{ label = "взрыв + треск камня", layers = { layer(PSE.explosion8, 0.4, 0.9, 1.0, nil, 1.8, 0.7), layer(PSE.rockCrackDebris, 0.35, 1.0, 1.1, nil, 1.5, 0.6) } },
		{ label = "силовой бум + землетрясение", layers = { layer(PSE.powerBoom2, 0.4, 0.9, 0.95, nil, 1.6, 0.6), layer(PSE.quakeBurst, 0.4, 1.0, 1.1, nil, 1.8, 0.7) } },
	},
	fxKeyOpen = {
		{ label = "цепи + бум + звон осколков", layers = { layer(PSE.chainsImpact, 0.45, 1.0, 1.05, nil, 1.4), layer(PSE.powerBoom2, 0.38, 1.0, 1.1, nil, 1.5, 0.6), layer(PSE.glassBreak, 0.24, 1.2, 1.3, nil, 1.2) } },
		{ label = "кандалы + магический взрыв", layers = { layer(PSE.shackles, 0.4, 1.0, 1.1, nil, 1.5), layer(PSE.magicBurst, 0.35, 1.0, 1.05, nil, 1.3) } },
		{ label = "металлический бум + цепи", layers = { layer(PSE.metalBoom, 0.32, 1.0, 1.05, nil, 2.0, 1.0), layer(PSE.chainsImpact, 0.4, 1.0, 1.1, nil, 1.4) } },
	},
	fxFloodSlam = {
		{ label = "гигантский всплеск + водяной взрыв", layers = { layer(PSE.giantSplash, 0.45, 1.0, 1.05, nil, 2.0, 0.8), layer(PSE.waterExplosion, 0.3, 1.0, 1.1, nil, 1.4) } },
		{ label = "всплеск-выброс + глубокий плеск", layers = { layer(PSE.waterBurst, 0.42, 1.0, 1.05, nil, 1.6), layer(PSE.splashDeep, 0.35, 1.0, 1.05, nil, 1.6) } },
		{ label = "водяной взрыв + глухой удар", layers = { layer(PSE.waterExplosion, 0.4, 1.0, 1.05, nil, 1.6), layer(PSE.deepHitBoom, 0.35, 1.1, 1.2, nil, 1.2) } },
	},
	fxPruneX = {
		{ label = "ножницы + звон + щелчок силы", layers = { layer(PSE.shears, 0.4, 1.1, 1.15, nil, 0.8), layer(PSE.shingRingy, 0.34, 1.0, 1.05, nil, 1.2), layer(PSE.powerBoom1, 0.24, 1.4, 1.5, nil, 0.6) } },
		{ label = "звон клинка, ниже", layers = { layer(PSE.shingRingy, 0.4, 0.85, 0.9, nil, 1.4), layer(PSE.woodSnap, 0.3, 1.0, 1.1) } },
	},
	fxSignalBlast = {
		{ label = "взрыв + вспышка керосина", layers = { layer(PSE.explosion2, 0.45, 1.0, 1.05, nil, 2.0, 0.8), layer(PSE.kerosene, 0.34, 1.0, 1.1, nil, 1.5, 0.6) } },
		{ label = "взрыв 8 + керосин", layers = { layer(PSE.explosion8, 0.42, 1.0, 1.05, nil, 2.0, 0.8), layer(PSE.kerosene, 0.3, 1.1, 1.2, nil, 1.5, 0.6) } },
		{ label = "силовой бум + костёр", layers = { layer(PSE.powerBoom1, 0.42, 0.9, 1.0, nil, 1.6, 0.6), layer(PSE.fireplace, 0.3, 1.0, 1.0, nil, 2.0, 0.8) } },
	},
	fxMoonCrescent = {
		{ label = "взрыв-вихрь + удар времени", layers = { layer(PSE.whooshExplosion, 0.4, 1.0, 1.05, nil, 1.4), layer(PSE.timeWarpBoom, 0.3, 1.1, 1.15, nil, 1.6, 0.6) } },
		{ label = "вихрь + синт-треск", layers = { layer(PSE.mrTwister, 0.34, 1.1, 1.2, nil, 1.4, 0.6), layer(PSE.synthCrack, 0.3, 0.9, 1.0, nil, 1.0) } },
	},
	fxForgedStrike = {
		{ label = "треск грома + синт-треск", layers = { layer(PSE.thunderCrack, 0.45, 1.0, 1.05, nil, 2.0, 0.8), layer(PSE.synthCrack, 0.3, 1.0, 1.1, nil, 0.8) } },
		{ label = "большой гром", layers = { layer(PSE.thunderBig, 0.45, 1.0, 1.05, nil, 2.5, 1.0) } },
		{ label = "дуга + треск грома", layers = { layer(PSE.electricArc, 0.3, 1.0, 1.1, nil, 0.8), layer(PSE.thunderCrack, 0.4, 1.05, 1.1, 0.03, 2.0, 0.8) } },
	},
	fxMeteorImpact = {
		{ label = "взрыв + землетрясение + дождь обломков", layers = { layer(PSE.explosion2, 0.5, 0.9, 0.95, nil, 2.5, 1.0), layer(PSE.quakeBurst, 0.45, 1.0, 1.05, nil, 2.0, 0.8), layer(PSE.debrisRain, 0.3, 1.0, 1.05, 0.4, 2.5, 1.0) } },
		{ label = "взрыв 8 + глухой удар + обломки", layers = { layer(PSE.explosion8, 0.5, 0.85, 0.9, nil, 2.5, 1.0), layer(PSE.deepHitBoom, 0.45, 0.9, 0.95, nil, 1.6, 0.6), layer(PSE.debrisRain, 0.3, 1.0, 1.05, 0.4, 2.5, 1.0) } },
		{ label = "силовой бум + землетрясение + камни", layers = { layer(PSE.powerBoom2, 0.5, 0.85, 0.9, nil, 2.0, 0.8), layer(PSE.quakeBurst, 0.45, 1.0, 1.05, nil, 2.0, 0.8), layer(PSE.rockDebris, 0.3, 1.0, 1.05, 0.35, 2.0, 0.8) } },
	},
	fxFirstNova = {
		{ label = "гонг + удар времени + бум", layers = { layer(PSE.gong, 0.4, 0.9, 0.9, nil, 4.0, 1.5), layer(PSE.timeWarpBoom, 0.4, 1.0, 1.0, nil, 2.0, 0.8), layer(PSE.powerBoom2, 0.34, 0.9, 0.95, nil, 1.5, 0.6) } },
		{ label = "нарастание + бум времени", layers = { layer(PSE.timeWarpBuildBoom, 0.45, 1.0, 1.0, nil, 2.6, 0.8, 0.0), layer(PSE.gong, 0.3, 0.8, 0.8, 0.1, 3.5, 1.5) } },
		{ label = "металлический бум + силовой", layers = { layer(PSE.metalBoom, 0.34, 0.85, 0.9, nil, 3.5, 1.5), layer(PSE.powerBoom1, 0.4, 0.9, 0.95, nil, 1.6, 0.6) } },
	},
	fxTimeStrike = {
		{ label = "стекло + лёд + удар времени", layers = { layer(PSE.glassBreak, 0.4, 1.0, 1.05, nil, 1.5), layer(PSE.iceShatter, 0.34, 1.0, 1.1, nil, 1.5), layer(PSE.timeWarpBoom, 0.4, 1.0, 1.0, nil, 2.0, 0.8) } },
		{ label = "лёд + колокол", layers = { layer(PSE.iceShatter, 0.4, 0.95, 1.0, nil, 1.5), layer(PSE.churchBellSting, 0.34, 1.0, 1.0, nil, 3.0, 1.2) } },
		{ label = "нарастание + бум времени", layers = { layer(PSE.timeWarpBoom, 0.45, 0.9, 0.95, nil, 2.0, 0.8), layer(PSE.glassBreak, 0.34, 0.9, 1.0, nil, 1.5) } },
	},
	fxFateIgnite = {
		{ label = "керосин + силовой бум", layers = { layer(PSE.kerosene, 0.4, 1.0, 1.05, nil, 1.5, 0.6), layer(PSE.powerBoom1, 0.34, 1.1, 1.15, nil, 1.4, 0.6) } },
		{ label = "взрыв-вихрь + керосин", layers = { layer(PSE.whooshExplosion, 0.4, 1.0, 1.1, nil, 1.4), layer(PSE.kerosene, 0.34, 1.1, 1.2, nil, 1.5, 0.6) } },
	},
	fxInkBlast = {
		{ label = "выброс воды + хлюп + взрыв-вихрь", layers = { layer(PSE.waterBurst, 0.4, 0.9, 0.95, nil, 1.5), layer(PSE.liquidSquish, 0.34, 0.85, 0.9), layer(PSE.whooshExplosion, 0.3, 0.9, 1.0, nil, 1.2) } },
		{ label = "густой хлюп + бум", layers = { layer(PSE.liquidSquish, 0.4, 0.8, 0.85), layer(PSE.deepHitBoom, 0.4, 1.0, 1.05, nil, 1.4, 0.6) } },
	},
	-- ===== Этажи 3–5 =====
	fxHuntSnap = {
		{ label = "цепи + металл + хруст камня", layers = { layer(PSE.chainsImpact, 0.38, 1.0, 1.05, nil, 1.2), layer(PSE.metalPop3, 0.3, 0.9, 1.0, nil, 0.6), layer(PSE.rockCrunch, 0.24, 1.0, 1.1, 0.03, 0.6) } },
		{ label = "кандалы + силовой щелчок", layers = { layer(PSE.shackles, 0.36, 1.0, 1.1, nil, 1.2), layer(PSE.powerBoom1, 0.28, 1.3, 1.4, nil, 0.8, 0.3) } },
		{ label = "наручники + глухой удар", layers = { layer(PSE.manacles, 0.36, 0.9, 1.0, nil, 0.8), layer(PSE.deepHitBoom, 0.3, 1.2, 1.3, nil, 1.0, 0.4) } },
	},
	fxHuntDashEnd = {
		{ label = "силовой бум + звон клинка", layers = { layer(PSE.powerBoom1, 0.32, 1.2, 1.3, nil, 1.0, 0.4), layer(PSE.shingRingy, 0.22, 1.0, 1.05, nil, 1.0, 0.4) } },
		{ label = "глухой удар + тяжёлый взмах", layers = { layer(PSE.deepHitBoom, 0.34, 1.2, 1.3, nil, 1.0, 0.4), layer(PSE.heavyWhoosh, 0.22, 1.2, 1.3, nil, 0.6) } },
	},
	fxHuntDiveBoom = {
		{ label = "глухой удар + разлёт камней", layers = { layer(PSE.deepHitBoom, 0.42, 1.0, 1.05, nil, 1.4, 0.6), layer(PSE.rockBurst, 0.3, 1.0, 1.1, nil, 1.0) } },
		{ label = "землетрясение + силовой бум", layers = { layer(PSE.quakeBurst, 0.38, 1.1, 1.2, nil, 1.5, 0.6), layer(PSE.powerBoom2, 0.28, 1.1, 1.2, nil, 1.2, 0.5) } },
		{ label = "взрыв + треск камня", layers = { layer(PSE.explosion8, 0.32, 1.0, 1.1, nil, 1.4, 0.6), layer(PSE.rockCrackDebris, 0.28, 1.0, 1.1, nil, 1.2, 0.5) } },
	},
	fxForgeSpill = {
		{ label = "керосин + шипение расплава", layers = { layer(PSE.kerosene, 0.3, 0.9, 1.0, nil, 1.2, 0.5), layer(PSE.searing11, 0.22, 1.0, 1.1, 0.05, 1.0, 0.4) } },
		{ label = "огненный взмах + треск", layers = { layer(PSE.fireWhoosh5, 0.3, 0.9, 1.0, nil, 1.0, 0.4), layer(PSE.sizzle4, 0.24, 0.9, 1.0, nil, 0.8, 0.3) } },
	},
	fxForgeNova = {
		{ label = "взрыв + керосин", layers = { layer(PSE.explosion2, 0.38, 1.0, 1.1, nil, 1.6, 0.6), layer(PSE.kerosene, 0.28, 1.0, 1.1, nil, 1.2, 0.5) } },
		{ label = "силовой бум + огненный взмах", layers = { layer(PSE.powerBoom2, 0.38, 1.0, 1.05, nil, 1.4, 0.6), layer(PSE.fireWhoosh15, 0.28, 1.0, 1.1, nil, 1.2, 0.5) } },
		{ label = "взрыв-вихрь + шипение", layers = { layer(PSE.whooshExplosion, 0.34, 1.0, 1.1, nil, 1.2, 0.5), layer(PSE.searing7, 0.28, 1.0, 1.1, nil, 1.0, 0.4) } },
	},
	fxForgeAnvilBoom = {
		{ label = "землетрясение + металлический бум (коротко)", layers = { layer(PSE.quakeBurst, 0.42, 1.0, 1.05, nil, 1.6, 0.6), layer(PSE.metalBoom, 0.22, 1.0, 1.05, nil, 1.6, 0.8) } },
		{ label = "глухой удар + звон наковальни", layers = { layer(PSE.deepHitBoom, 0.45, 0.9, 1.0, nil, 1.5, 0.6), layer(PSE.anvilRing, 0.2, 0.9, 1.0, 0.02, 1.2, 0.5) } },
		{ label = "взрыв + тяжёлый лязг", layers = { layer(PSE.explosion8, 0.38, 0.9, 1.0, nil, 1.6, 0.6), layer(PSE.robotClang, 0.28, 0.9, 1.0, nil, 1.0, 0.4) } },
	},
	fxForgeTemper = {
		{ label = "звон клинка + пар", layers = { layer(PSE.shingRingy, 0.24, 0.9, 0.95, nil, 1.2, 0.5), layer(PSE.iceSizzle, 0.2, 1.0, 1.1, nil, 1.6, 0.6) } },
		{ label = "наковальня (тихо) + шипение", layers = { layer(PSE.anvilRing, 0.18, 1.1, 1.2, nil, 0.9, 0.4), layer(PSE.airyHiss, 0.18, 1.0, 1.1, nil, 1.0, 0.4) } },
	},
	fxForgePourCrash = {
		{ label = "водяной взрыв низко + лава", layers = { layer(PSE.waterExplosion, 0.3, 0.6, 0.65, nil, 1.6, 0.6), layer(PSE.lavaFire, 0.26, 1.0, 1.1, nil, 1.6, 0.6) } },
		{ label = "взрыв + шипение расплава", layers = { layer(PSE.explosion2, 0.34, 1.0, 1.05, nil, 1.6, 0.6), layer(PSE.searing11, 0.24, 0.9, 1.0, nil, 1.2, 0.5) } },
	},
	fxChronStamp = {
		{ label = "штамп + удар времени", layers = { layer(PSE.stamp2, 0.38, 0.8, 0.85, nil, 0.8), layer(PSE.timeWarpBoom, 0.28, 1.0, 1.05, nil, 1.6, 0.6) } },
		{ label = "большой штамп + лёд", layers = { layer(PSE.stampBig, 0.38, 0.9, 0.95, nil, 0.8), layer(PSE.iceShatter, 0.22, 1.1, 1.2, nil, 1.2, 0.5) } },
		{ label = "глухой удар + рябь времени", layers = { layer(PSE.deepHitBoom, 0.34, 1.1, 1.2, nil, 1.2, 0.5), layer(PSE.timeRipple, 0.26, 1.0, 1.05, nil, 1.6, 0.6) } },
	},
	fxChronDomeShatter = {
		{ label = "стекло + удар времени", layers = { layer(PSE.glassBreak, 0.36, 0.9, 0.95, nil, 1.5, 0.6), layer(PSE.timeWarpBoom, 0.34, 1.0, 1.05, nil, 1.8, 0.7) } },
		{ label = "лёд + силовой бум", layers = { layer(PSE.iceShatter, 0.38, 0.95, 1.0, nil, 1.5, 0.6), layer(PSE.powerBoom2, 0.3, 1.1, 1.2, nil, 1.4, 0.6) } },
		{ label = "магический взрыв + стекло", layers = { layer(PSE.magicBurst, 0.34, 1.0, 1.05, nil, 1.3), layer(PSE.glassBreak, 0.28, 1.1, 1.2, nil, 1.2, 0.5) } },
	},
	fxChronInkSplat = {
		{ label = "хлюп + шлепок стекла", layers = { layer(PSE.liquidSquish, 0.3, 0.8, 0.85), layer(PSE.glassSplat, 0.22, 0.9, 1.0, nil, 0.8, 0.3) } },
		{ label = "выброс воды низко + хлюп", layers = { layer(PSE.waterBurst, 0.28, 0.7, 0.75, nil, 1.2, 0.5), layer(PSE.squish, 0.24, 0.8, 0.9) } },
	},
	fxChronRecallFinale = {
		{ label = "магический взрыв + удар времени", layers = { layer(PSE.magicBurst, 0.34, 1.0, 1.05, nil, 1.3), layer(PSE.timeWarpBoom, 0.28, 1.05, 1.1, nil, 1.6, 0.6) } },
		{ label = "силовой бум + звон стекла", layers = { layer(PSE.powerBoom2, 0.32, 1.1, 1.2, nil, 1.2, 0.5), layer(PSE.glassBreak, 0.2, 1.3, 1.4, nil, 1.0, 0.4) } },
	},
}

SfxSkills.picked = {}
for name in pairs(SfxSkills.candidates) do
	SfxSkills.picked[name] = 1
end

return SfxSkills
