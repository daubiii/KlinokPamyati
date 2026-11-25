--!nonstrict
-- SfxMage
-- Звуки мага: удары посохом, попадания снарядов по стихиям, барьер, «Покров», дебафы,
-- пассивки и 19 заклинаний. Подмешиваются в Config/Sfx (блок в конце Sfx.lua), играются
-- через Bus "sfx" { name, position } (AudioController). Источники — только официальная
-- библиотека Roblox: Pro Sound Effects (91xxxxxxxx), APM Music и звуки движка.
-- Заменить звук = поменять id здесь. Варианты на слух — Sfx.candidates (команда «sfx <имя> <N>»).

local SfxMage = {}

local PSE = {
	magicZoom = "rbxassetid://9125648149", -- Magic Spell Zoom: короткий взлёт заряда
	magicShimmer = "rbxassetid://9125647212", -- Magic Spell Shimmer: мерцание
	magicGrowly = "rbxassetid://9125646252", -- Magic Spell Growly: низкий рык магии
	fallingShimmer = "rbxassetid://9116418035", -- Falling Shimmer: спадающий перелив
	fairyDust = "rbxassetid://9114369623", -- Fairy Dust: искристая пыльца
	ghostWind = "rbxassetid://9114574159", -- Ghost Wind: призрачный ветер
	sparkleBell = "rbxassetid://9126073001", -- Sparkle Bell: звонкий колокольчик
	energyWhoosh = "rbxassetid://9125517884", -- Electric Whoosh Low End Synth Buzz
	magicChime = "rbxassetid://9116394545", -- Magic Glows Soft Clusters Of Chiming Hits
	iceFreeze = "rbxassetid://9125611419", -- Ice Freeze: хруст замерзания
	iceChunks = "rbxassetid://9114865805", -- Ice Chunks: осколки льда
	fireWhoosh = "rbxassetid://9114446852", -- Fire Whoosh 15
	searing = "rbxassetid://9118882814", -- Searing 11: шипение огня
	sizzle = "rbxassetid://9119165650", -- Sizzle 4
	bubbling = "rbxassetid://9125498766", -- Bubbling: бульканье
	airyHiss = "rbxassetid://9113079144", -- Airy Hiss
	heavyWhoosh = "rbxassetid://9113077334", -- Heavy Whoosh
	wolfHowl = "rbxassetid://9120790529", -- Wolf Howl
	hawkScreech = "rbxassetid://9125598512", -- Hawk Screech
	wingsFlap = "rbxassetid://9114787449", -- Wings Flap
	anvilRing = "rbxassetid://9125361455", -- Anvil Ring 1
	pages = "rbxassetid://9118835414", -- Pages 1: шелест страниц
	tick = "rbxassetid://9114069409", -- Tick 1: тик часов
	timerBell = "rbxassetid://9126102079", -- Timer Bell
	glassSplat = "rbxassetid://9114615719", -- Glass Splat
	waterImpact = "rbxassetid://9119481909", -- Splash Thunking Impact 1
	rockCrunch = "rbxassetid://9118633662", -- Rock Impacts Deep Crunchy Hits 10
}

local APM = {
	massiveHit = "rbxassetid://9045192152", -- Neurosis Massive Hit
	percHit = "rbxassetid://9045209987", -- Vindictive Raid Perc Hit
}

local ENGINE = {
	bass = "rbxasset://sounds/bass.wav",
	ping = "rbxasset://sounds/electronicpingshort.wav",
	snap = "rbxasset://sounds/snap.mp3",
	splash = "rbxasset://sounds/impact_water.mp3",
}

local function layer(id: string, volume: number, pitchMin: number, pitchMax: number?, delay: number?, length: number?)
	return { id = id, volume = volume, pitch = { pitchMin, pitchMax or pitchMin }, delay = delay, length = length }
end

-- Стиль снаряда (LootMage.Styles) → звук попадания.
SfxMage.HitByStyle = {
	arcane = "boltArcane", light = "boltArcane", gate = "boltArcane", moon = "boltArcane",
	rust = "boltEarth", bone = "boltEarth", slag = "boltEarth", sand = "boltEarth", forge = "boltEarth",
	ember = "boltFire", fire = "boltFire", magma = "boltFire",
	water = "boltWater", lotus = "boltWater",
	poison = "boltNature", thorn = "boltNature", spore = "boltNature",
	spirit = "boltSpirit", memory = "boltSpirit", time = "boltSpirit",
	lightning = "boltLightning",
	ink = "boltInk", page = "boltInk",
}

SfxMage.sounds = {
	-- Попадания снарядов посоха по стихиям.
	boltArcane = { layer(PSE.magicShimmer, 0.28, 1.25, 1.45, nil, 0.35), layer(APM.percHit, 0.18, 1.8, 2.0, nil, 0.2) },
	boltEarth = { layer(PSE.rockCrunch, 0.3, 1.3, 1.5, nil, 0.3), layer(APM.percHit, 0.2, 1.5, 1.7, nil, 0.2) },
	boltFire = { layer(PSE.fireWhoosh, 0.3, 1.3, 1.5, nil, 0.35), layer(PSE.sizzle, 0.12, 1.2, 1.4, 0.05, 0.3) },
	boltWater = { layer(PSE.waterImpact, 0.3, 1.3, 1.5, nil, 0.3), layer(ENGINE.splash, 0.15, 1.3, 1.5) },
	boltNature = { layer(PSE.glassSplat, 0.22, 1.3, 1.5, nil, 0.3), layer(PSE.bubbling, 0.12, 1.4, 1.6, nil, 0.3) },
	boltSpirit = { layer(PSE.ghostWind, 0.22, 1.5, 1.7, nil, 0.35), layer(PSE.magicChime, 0.15, 1.6, 1.8, nil, 0.3) },
	boltLightning = { layer(PSE.energyWhoosh, 0.3, 1.6, 1.8, nil, 0.3), layer(ENGINE.snap, 0.25, 1.4, 1.6) },
	boltInk = { layer(PSE.bubbling, 0.22, 1.1, 1.3, nil, 0.3), layer(PSE.pages, 0.15, 1.3, 1.5, nil, 0.25) },
	-- Взрыв навесного снаряда (огненные посохи, «большой» шар).
	boltBlast = { layer(APM.massiveHit, 0.32, 1.5, 1.7, nil, 0.45), layer(PSE.fireWhoosh, 0.25, 0.9, 1.0, nil, 0.4) },
	-- Барьер.
	barrierOpen = { layer(PSE.magicZoom, 0.35, 1.3, 1.4, nil, 0.4), layer(PSE.sparkleBell, 0.14, 1.5, 1.6, nil, 0.5) },
	barrierBlock = { layer(PSE.sparkleBell, 0.45, 1.0, 1.1, nil, 0.8), layer(APM.percHit, 0.4, 1.2, 1.3, nil, 0.3), layer(PSE.heavyWhoosh, 0.25, 1.3, 1.4, 0.03, 0.4) },
	barrierNoMana = { layer(ENGINE.ping, 0.2, 0.6, 0.65), layer(PSE.airyHiss, 0.15, 1.6, 1.8, nil, 0.3) },
	-- Покров.
	veilOn = { layer(PSE.ghostWind, 0.4, 1.0, 1.1, nil, 1.0), layer(PSE.fallingShimmer, 0.25, 1.2, 1.3, nil, 0.9) },
	veilOff = { layer(PSE.airyHiss, 0.25, 1.2, 1.3, nil, 0.4) },
	veilAmbush = { layer(PSE.magicGrowly, 0.4, 1.3, 1.4, nil, 0.5), layer(APM.percHit, 0.35, 1.0, 1.1, nil, 0.3) },
	-- Дебафы.
	debuffBurn = { layer(PSE.searing, 0.18, 1.2, 1.4, nil, 0.4) },
	debuffPoison = { layer(PSE.bubbling, 0.18, 1.4, 1.6, nil, 0.4) },
	debuffSlow = { layer(PSE.iceFreeze, 0.18, 1.4, 1.6, nil, 0.35) },
	debuffSunder = { layer(PSE.rockCrunch, 0.2, 1.5, 1.7, nil, 0.3) },
	-- Пассивки легендарок.
	passiveProc = { layer(PSE.sparkleBell, 0.3, 1.3, 1.5, nil, 0.5), layer(PSE.magicZoom, 0.18, 1.6, 1.8, nil, 0.3) },
	passiveBlast = { layer(APM.massiveHit, 0.3, 1.6, 1.8, nil, 0.4), layer(PSE.magicShimmer, 0.2, 1.1, 1.2, nil, 0.4) },
	-- Заклинания: общий заряд и стихии.
	spellCharge = { layer(PSE.magicZoom, 0.35, 0.9, 1.0, nil, 0.6), layer(PSE.magicShimmer, 0.2, 1.0, 1.1, nil, 0.6) },
	spellRunes = { layer(PSE.magicChime, 0.35, 1.0, 1.1, nil, 1.2), layer(PSE.magicGrowly, 0.25, 0.8, 0.9, nil, 0.8) },
	spellBurst = { layer(APM.massiveHit, 0.4, 1.2, 1.3, nil, 0.6), layer(PSE.sparkleBell, 0.25, 0.9, 1.0, nil, 0.6) },
	spellLight = { layer(PSE.sparkleBell, 0.4, 0.8, 0.85, nil, 1.2), layer(PSE.energyWhoosh, 0.35, 0.7, 0.8, nil, 0.8) },
	spellFireLaunch = { layer(PSE.fireWhoosh, 0.45, 0.9, 1.0, nil, 0.6) },
	spellFireBlast = { layer(APM.massiveHit, 0.5, 1.0, 1.1, nil, 0.8), layer(PSE.fireWhoosh, 0.4, 0.7, 0.8, nil, 0.7) },
	spellFireLoop = { layer(PSE.searing, 0.3, 0.8, 0.9, nil, 1.5) },
	spellMeteorFall = { layer(PSE.heavyWhoosh, 0.45, 0.6, 0.7, nil, 1.0), layer(PSE.fireWhoosh, 0.3, 0.6, 0.65, nil, 1.0) },
	spellMeteorImpact = { layer(APM.massiveHit, 0.75, 0.75, 0.8, nil, 1.4), layer(PSE.rockCrunch, 0.55, 0.6, 0.7, nil, 1.0), layer(ENGINE.bass, 0.45, 0.5, 0.55) },
	spellLava = { layer(PSE.sizzle, 0.3, 0.7, 0.8, nil, 1.5), layer(PSE.bubbling, 0.2, 0.6, 0.7, nil, 1.5) },
	spellWater = { layer(PSE.waterImpact, 0.5, 0.8, 0.9, nil, 0.8), layer(ENGINE.splash, 0.35, 0.8, 0.9) },
	spellPetals = { layer(PSE.fairyDust, 0.35, 1.1, 1.2, nil, 1.0) },
	spellSpores = { layer(PSE.airyHiss, 0.3, 0.9, 1.0, nil, 0.5), layer(PSE.fairyDust, 0.2, 0.8, 0.9, nil, 0.6) },
	spellPop = { layer(PSE.glassSplat, 0.3, 0.9, 1.1, nil, 0.4), layer(ENGINE.snap, 0.2, 0.7, 0.8) },
	spellThorns = { layer(PSE.rockCrunch, 0.4, 1.1, 1.2, nil, 0.6), layer(ENGINE.snap, 0.35, 0.6, 0.7) },
	spellHowl = { layer(PSE.wolfHowl, 0.45, 1.0, 1.1, nil, 2.0), layer(PSE.ghostWind, 0.25, 0.8, 0.9, nil, 1.2) },
	spellBite = { layer(APM.percHit, 0.3, 1.4, 1.6, nil, 0.25), layer(ENGINE.snap, 0.25, 1.0, 1.2) },
	spellMoon = { layer(PSE.fallingShimmer, 0.4, 0.7, 0.8, nil, 1.6), layer(PSE.magicGrowly, 0.25, 0.6, 0.7, nil, 1.0) },
	spellMoonBeam = { layer(PSE.energyWhoosh, 0.3, 1.2, 1.4, nil, 0.4), layer(PSE.sparkleBell, 0.18, 1.3, 1.5, nil, 0.4) },
	spellCrescent = { layer(PSE.heavyWhoosh, 0.5, 0.8, 0.9, nil, 0.6), layer(PSE.magicShimmer, 0.3, 0.8, 0.9, nil, 0.6) },
	spellFalcon = { layer(PSE.hawkScreech, 0.35, 1.0, 1.15, nil, 1.0), layer(PSE.wingsFlap, 0.25, 1.0, 1.2, nil, 0.6) },
	spellDive = { layer(PSE.heavyWhoosh, 0.25, 1.4, 1.6, nil, 0.3), layer(APM.percHit, 0.25, 1.3, 1.5, nil, 0.25) },
	spellLightning = { layer(APM.massiveHit, 0.45, 1.3, 1.4, nil, 0.6), layer(PSE.energyWhoosh, 0.45, 1.3, 1.4, nil, 0.5), layer(ENGINE.snap, 0.4, 0.8, 0.9) },
	spellChain = { layer(PSE.energyWhoosh, 0.3, 1.7, 1.9, nil, 0.4), layer(ENGINE.snap, 0.25, 1.3, 1.5) },
	spellAnvil = { layer(PSE.anvilRing, 0.45, 0.9, 1.0, nil, 1.2), layer(APM.percHit, 0.3, 0.9, 1.0, nil, 0.3) },
	spellRift = { layer(PSE.rockCrunch, 0.45, 0.7, 0.8, nil, 0.8), layer(PSE.fireWhoosh, 0.3, 0.8, 0.9, nil, 0.6) },
	spellNova = { layer(APM.massiveHit, 0.8, 0.6, 0.65, nil, 1.6), layer(PSE.magicGrowly, 0.5, 0.5, 0.55, nil, 1.2), layer(ENGINE.bass, 0.5, 0.45, 0.5) },
	spellPages = { layer(PSE.pages, 0.45, 0.9, 1.0, nil, 1.0), layer(PSE.magicChime, 0.2, 1.1, 1.2, nil, 1.0) },
	spellGlyph = { layer(PSE.magicZoom, 0.18, 1.6, 1.9, nil, 0.25) },
	spellTick = { layer(PSE.tick, 0.45, 0.9, 1.0, nil, 0.4) },
	spellTimeStop = { layer(PSE.iceFreeze, 0.45, 0.6, 0.7, nil, 1.2), layer(PSE.timerBell, 0.4, 0.7, 0.75, nil, 1.5) },
	spellTimeStrike = { layer(PSE.timerBell, 0.45, 1.0, 1.05, nil, 1.0), layer(APM.massiveHit, 0.45, 1.1, 1.2, nil, 0.6), layer(PSE.iceChunks, 0.35, 1.0, 1.1, nil, 0.6) },
	spellScribe = { layer(PSE.pages, 0.35, 1.2, 1.3, nil, 0.8), layer(PSE.magicShimmer, 0.25, 0.9, 1.0, nil, 0.8) },
	spellFate = { layer(PSE.energyWhoosh, 0.5, 0.8, 0.9, nil, 0.8), layer(PSE.sparkleBell, 0.35, 0.7, 0.75, nil, 1.0), layer(APM.massiveHit, 0.35, 1.3, 1.4, nil, 0.4) },
	spellInk = { layer(PSE.bubbling, 0.45, 0.6, 0.7, nil, 2.0), layer(PSE.ghostWind, 0.3, 0.6, 0.7, nil, 2.0) },
	spellInkBlast = { layer(PSE.glassSplat, 0.5, 0.6, 0.7, nil, 0.6), layer(APM.massiveHit, 0.45, 0.9, 1.0, nil, 0.8) },
	spellEcho = { layer(PSE.ghostWind, 0.4, 1.2, 1.3, nil, 1.0), layer(PSE.magicChime, 0.3, 0.8, 0.9, nil, 1.2) },
	spellEchoBeam = { layer(PSE.energyWhoosh, 0.4, 1.0, 1.1, nil, 0.5), layer(PSE.magicShimmer, 0.3, 1.4, 1.5, nil, 0.4) },
	spellStorm = { layer(PSE.fallingShimmer, 0.45, 1.0, 1.1, nil, 1.4), layer(PSE.heavyWhoosh, 0.35, 0.9, 1.0, nil, 0.8) },
}

-- Удары посохом: варианты на слух (по умолчанию 1).
SfxMage.candidates = {
	mageCast1 = {
		{ label = "короткий взлёт заряда", layers = { layer(PSE.magicZoom, 0.32, 1.35, 1.5, nil, 0.35), layer(PSE.airyHiss, 0.12, 1.6, 1.8, nil, 0.25) } },
		{ label = "мерцание", layers = { layer(PSE.magicShimmer, 0.3, 1.4, 1.6, nil, 0.35) } },
		{ label = "электрический свист", layers = { layer(PSE.energyWhoosh, 0.28, 1.5, 1.7, nil, 0.3) } },
	},
	mageCast2 = {
		{ label = "взлёт заряда, выше", layers = { layer(PSE.magicZoom, 0.32, 1.5, 1.65, nil, 0.35), layer(PSE.airyHiss, 0.12, 1.8, 2.0, nil, 0.25) } },
		{ label = "мерцание, выше", layers = { layer(PSE.magicShimmer, 0.3, 1.6, 1.8, nil, 0.35) } },
	},
	mageCast3 = {
		{ label = "тяжёлый свист + рык магии", layers = { layer(PSE.heavyWhoosh, 0.4, 1.1, 1.2, nil, 0.5), layer(PSE.magicGrowly, 0.3, 1.1, 1.2, 0.04, 0.5) } },
		{ label = "взлёт + колокольчик", layers = { layer(PSE.magicZoom, 0.4, 1.0, 1.1, nil, 0.5), layer(PSE.sparkleBell, 0.2, 1.2, 1.3, 0.05, 0.5) } },
	},
}

SfxMage.picked = {
	mageCast1 = 1,
	mageCast2 = 1,
	mageCast3 = 1,
}

return SfxMage
