--!nonstrict
-- SfxWeaponsV2 — звуки переделанных способностей мечей и молотов (07.11.2026, Controllers/AbilityFxV2).
-- Слои из той же лицензированной библиотеки, что у эталонов (Наковальня, Разлом): Pro Sound Effects,
-- APM и звуки движка. На каждый такт способности — свой звук (стандарт V2).
-- Спорные звуки (сокол) — с вариантами на прослушивание: команда «sfx <имя> <номер>» в Studio,
-- выбранный номер вписывается в picked.
-- Подмешивается в Config/Sfx (блок V2 в конце).

local M = {}

local PSE = {
	airWhoosh = "rbxassetid://9126283272",
	energyWhoosh = "rbxassetid://9125517884",
	waterImpact = "rbxassetid://9119481909",
	rockCrunch = "rbxassetid://9118633662",
	magicChime = "rbxassetid://9116394545",
	shieldClang1 = "rbxassetid://9119072660",
	metalClatter = "rbxassetid://9116524438",
	metalRattle = "rbxassetid://9116797354",
	biteCrunch = "rbxassetid://9125466770",
	hawkScreech = "rbxassetid://9125598512",
	wingsFlap = "rbxassetid://9114787449",
	heavyWhoosh = "rbxassetid://9113077334",
	anvilRing1 = "rbxassetid://9125361455",
	anvilHammer2 = "rbxassetid://9113445305",
	searing11 = "rbxassetid://9118882814",
	searing5 = "rbxassetid://9118884046",
	searing7 = "rbxassetid://9118884310",
	airyHiss = "rbxassetid://9113079144",
	fireWhoosh15 = "rbxassetid://9114446852",
	fireWhoosh6 = "rbxassetid://9114446277",
	fireWhoosh13 = "rbxassetid://9114446802",
	fireWhoosh5 = "rbxassetid://9114444052",
	sizzle4 = "rbxassetid://9119165650",
	sizzle10 = "rbxassetid://9119166195",
	bubbling = "rbxassetid://9125498766",
	bubbles = "rbxassetid://9125409840",
	metalClunk2 = "rbxassetid://9116673944",
	pages1 = "rbxassetid://9118835414",
	pages2 = "rbxassetid://9118835650",
	pencil = "rbxassetid://9117277763",
	glassSplat = "rbxassetid://9114615719",
	wetHit1 = "rbxassetid://9113520514",
	wetHit2 = "rbxassetid://9113520180",
	magicZoom = "rbxassetid://9125648149",
	magicShimmer = "rbxassetid://9125647212",
	magicGrowly = "rbxassetid://9125646252",
	sparkleBell = "rbxassetid://9126073001",
	fallingShimmer = "rbxassetid://9116418035",
	fairyDust = "rbxassetid://9114369623",
	ghostWind = "rbxassetid://9114574159",
}
local APM = {
	massiveHit = "rbxassetid://9045192152",
	percHit = "rbxassetid://9045209987",
}
local ENGINE = {
	slash = "rbxasset://sounds/swordslash.wav",
	lunge = "rbxasset://sounds/swordlunge.wav",
	bass = "rbxasset://sounds/bass.wav",
	snap = "rbxasset://sounds/snap.mp3",
	splash = "rbxasset://sounds/impact_water.mp3",
}

local function layer(id: string, volume: number, pitchMin: number, pitchMax: number?, delay: number?, length: number?)
	return { id = id, volume = volume, pitch = { pitchMin, pitchMax or pitchMin }, delay = delay, length = length }
end

M.sounds = {
	-- ===== «Забвение» =====
	v2EraseDraw = { layer(PSE.pencil, 0.4, 0.8, 0.9, nil, 0.7), layer(PSE.ghostWind, 0.35, 0.7, 0.75, 0.05, 1.6), layer(ENGINE.bass, 0.25, 0.5, 0.55) },
	v2EraseTick = { layer(PSE.pages2, 0.18, 1.3, 1.45, nil, 0.25), layer(PSE.fallingShimmer, 0.12, 1.6, 1.7, nil, 0.3) },
	v2EraseSweep = { layer(PSE.heavyWhoosh, 0.6, 0.75, 0.8, nil, 0.9), layer(PSE.pages1, 0.45, 0.8, 0.85, 0.05, 0.7), layer(APM.massiveHit, 0.45, 1.1, 1.15, 0.08, 1.2) },
	v2Erased = { layer(PSE.fallingShimmer, 0.4, 0.9, 1.0, nil, 1.0), layer(PSE.pages2, 0.3, 0.7, 0.75, 0.05, 0.7) },

	-- ===== «Горнило» =====
	v2HeartPlunge = { layer(PSE.anvilHammer2, 0.5, 0.75, 0.8, nil, 0.8), layer(PSE.rockCrunch, 0.45, 0.7, 0.75, 0.02, 0.6), layer(ENGINE.bass, 0.4, 0.5, 0.55) },
	v2HeartErupt = { layer(PSE.fireWhoosh15, 0.5, 0.8, 0.95, nil, 1.0), layer(PSE.searing11, 0.3, 0.9, 1.0, 0.05, 0.8), layer(PSE.rockCrunch, 0.25, 0.9, 1.0, nil, 0.4) },
	v2HeartBlade = { layer(PSE.fireWhoosh6, 0.45, 1.0, 1.1, nil, 0.9), layer(PSE.sizzle10, 0.25, 1.0, 1.1, 0.1, 0.6) },
	v2HeartArc = { layer(PSE.fireWhoosh13, 0.45, 1.1, 1.25, nil, 0.6), layer(ENGINE.slash, 0.3, 0.8, 0.9) },

	-- ===== «Первая отливка» =====
	v2PourSky = { layer(PSE.bubbling, 0.4, 0.7, 0.75, nil, 1.2), layer(PSE.fireWhoosh5, 0.35, 0.6, 0.65, 0.1, 1.2), layer(PSE.magicGrowly, 0.25, 0.6, 0.65, 0.2, 1.0) },
	v2PourRing = { layer(PSE.fireWhoosh13, 0.45, 0.9, 1.0, nil, 0.7), layer(PSE.searing7, 0.3, 0.95, 1.05, 0.03, 0.5) },
	v2PourCleave = { layer(APM.massiveHit, 0.65, 0.85, 0.9, nil, 1.8), layer(PSE.anvilRing1, 0.4, 0.7, 0.75, 0.04, 1.4), layer(PSE.fireWhoosh15, 0.45, 0.7, 0.75, nil, 1.0), layer(ENGINE.bass, 0.5, 0.45, 0.5) },
	v2PourSteam = { layer(PSE.airyHiss, 0.55, 0.75, 0.85, nil, 1.4), layer(PSE.sizzle4, 0.35, 0.8, 0.9, 0.05, 0.8) },

	-- ===== «Соколиная охота» (звуки целиком новые: варианты — в candidates) =====
	v2FalconCall = { layer(PSE.wingsFlap, 0.45, 0.95, 1.05, nil, 0.7), layer(PSE.hawkScreech, 0.22, 0.85, 0.9, 0.15, 0.7) },
	v2FalconDive = { layer(PSE.magicZoom, 0.35, 1.2, 1.3, nil, 0.45), layer(PSE.airWhoosh, 0.4, 1.3, 1.45, 0.05, 0.4) },
	v2FalconHit = { layer(PSE.biteCrunch, 0.35, 1.2, 1.35, nil, 0.35), layer(APM.percHit, 0.35, 1.15, 1.25, nil, 0.35), layer(PSE.wingsFlap, 0.2, 1.3, 1.4, 0.05, 0.4) },
	v2FalconFinalDive = { layer(PSE.hawkScreech, 0.3, 0.75, 0.8, nil, 0.9), layer(PSE.magicZoom, 0.4, 1.0, 1.05, 0.05, 0.6), layer(PSE.heavyWhoosh, 0.35, 1.0, 1.1, 0.1, 0.5) },
	v2FalconFinalHit = { layer(APM.massiveHit, 0.55, 1.15, 1.2, nil, 1.2), layer(PSE.rockCrunch, 0.4, 0.95, 1.05, 0.03, 0.6), layer(PSE.wingsFlap, 0.35, 0.9, 1.0, 0.1, 0.6) },

	-- ===== «Прилив» =====
	v2TideSlam = { layer(APM.percHit, 0.5, 0.85, 0.9, nil, 0.5), layer(PSE.waterImpact, 0.5, 0.8, 0.9, 0.02, 0.8), layer(ENGINE.bass, 0.35, 0.6, 0.65) },
	v2TideRoll = { layer(PSE.energyWhoosh, 0.35, 0.55, 0.6, nil, 0.8), layer(ENGINE.splash, 0.4, 0.6, 0.7, 0.1, 0.8) },
	v2TideCrash = { layer(PSE.waterImpact, 0.6, 0.65, 0.75, nil, 1.1), layer(ENGINE.splash, 0.5, 0.5, 0.55, 0.03, 1.0), layer(PSE.rockCrunch, 0.25, 0.8, 0.9, nil, 0.4) },

	-- ===== «Обрезка» =====
	v2PruneCut = { layer(ENGINE.slash, 0.4, 1.2, 1.35), layer(PSE.shieldClang1, 0.2, 1.6, 1.75, nil, 0.3) },
	v2PruneVines = { layer(PSE.rockCrunch, 0.3, 1.3, 1.45, nil, 0.5), layer(ENGINE.snap, 0.35, 0.6, 0.7, 0.05) },
	v2PruneSnip = { layer(PSE.shieldClang1, 0.45, 1.5, 1.6, nil, 0.35), layer(ENGINE.snap, 0.5, 1.1, 1.2), layer(PSE.wetHit1, 0.35, 1.1, 1.2, 0.04, 0.4) },

	-- ===== «Последний гон» =====
	v2PreyMarked = { layer(PSE.metalRattle, 0.25, 1.4, 1.5, nil, 0.4), layer(PSE.magicChime, 0.2, 0.7, 0.75, 0.05, 0.6) },
	v2HuntFinale = { layer(PSE.heavyWhoosh, 0.55, 0.9, 1.0, nil, 0.8), layer(APM.percHit, 0.45, 0.9, 1.0, 0.05, 0.4), layer(ENGINE.bass, 0.3, 0.6, 0.65) },

	-- ===== «Шлаковый смерч» =====
	v2CycloneStart = { layer(PSE.fireWhoosh5, 0.45, 0.75, 0.8, nil, 1.2), layer(PSE.heavyWhoosh, 0.35, 0.7, 0.75, 0.05, 0.8) },
	v2CycloneSpin = { layer(PSE.airWhoosh, 0.35, 0.85, 1.0, nil, 0.4), layer(PSE.sizzle4, 0.15, 1.1, 1.3, nil, 0.3) },
	v2CycloneSlam = { layer(APM.massiveHit, 0.6, 0.9, 0.95, nil, 1.5), layer(PSE.metalClunk2, 0.45, 0.7, 0.8, 0.02, 0.8), layer(PSE.searing5, 0.35, 0.8, 0.9, 0.05, 0.8), layer(ENGINE.bass, 0.45, 0.5, 0.55) },

	-- ===== «Строка» крестом =====
	v2QuillCenter = { layer(PSE.magicGrowly, 0.45, 0.85, 0.9, nil, 0.9), layer(APM.percHit, 0.4, 1.0, 1.1, nil, 0.35), layer(PSE.pages1, 0.3, 1.0, 1.1, 0.05, 0.5) },

	-- ===== «Чернильный прилив» =====
	v2InkPull = { layer(PSE.bubbling, 0.4, 0.6, 0.65, nil, 1.0), layer(PSE.magicGrowly, 0.35, 0.55, 0.6, 0.05, 1.0) },
	v2InkBurst = { layer(PSE.glassSplat, 0.5, 0.55, 0.6, nil, 0.9), layer(APM.massiveHit, 0.45, 1.1, 1.2, 0.03, 1.0), layer(PSE.wetHit2, 0.4, 0.7, 0.75, 0.05, 0.6) },

	-- ===== «Перекал», «Вспомнить» =====
	v2SearingFinale = { layer(PSE.searing11, 0.5, 0.9, 1.0, nil, 0.9), layer(APM.percHit, 0.45, 0.95, 1.05, nil, 0.4), layer(PSE.fireWhoosh6, 0.3, 1.1, 1.2, 0.03, 0.6) },
	v2MemoryBurst = { layer(PSE.sparkleBell, 0.45, 0.8, 0.85, nil, 1.4), layer(APM.massiveHit, 0.5, 1.2, 1.25, nil, 1.0), layer(PSE.magicShimmer, 0.35, 0.9, 1.0, 0.05, 1.0) },

	-- ===== Посохи (MageSpellFxV2, 07.11) =====
	-- «Королевская ловля»: бросок сети, хлопок сети о землю, свист и удар копья, разрыв
	mHuntThrow = { layer(PSE.heavyWhoosh, 0.4, 1.1, 1.2, nil, 0.6), layer(PSE.metalRattle, 0.2, 1.2, 1.3, 0.05, 0.4) },
	mHuntNet = { layer(PSE.metalRattle, 0.4, 0.85, 0.95, nil, 0.6), layer(ENGINE.snap, 0.35, 0.7, 0.8), layer(PSE.rockCrunch, 0.25, 1.2, 1.3, 0.02, 0.35) },
	mHuntSpearFall = { layer(PSE.magicZoom, 0.3, 1.3, 1.4, nil, 0.3) },
	mHuntSpear = { layer(APM.percHit, 0.5, 0.85, 0.95, nil, 0.45), layer(PSE.rockCrunch, 0.4, 0.9, 1.0, 0.02, 0.5), layer(PSE.shieldClang1, 0.2, 0.8, 0.85, 0.03, 0.4) },
	mHuntTear = { layer(ENGINE.snap, 0.5, 0.55, 0.6), layer(PSE.heavyWhoosh, 0.35, 0.9, 1.0, 0.03, 0.5), layer(PSE.metalRattle, 0.25, 0.75, 0.8, 0.05, 0.5) },
	-- «Призрачная стая»: призыв (ветер духов), общий прыжок
	mPackSummon = { layer(PSE.ghostWind, 0.4, 1.0, 1.1, nil, 1.0), layer(PSE.energyWhoosh, 0.3, 1.1, 1.2, 0.05, 0.6) },
	mPackPounce = { layer(PSE.biteCrunch, 0.5, 0.8, 0.9, nil, 0.5), layer(APM.massiveHit, 0.45, 1.15, 1.25, 0.02, 0.9), layer(PSE.ghostWind, 0.3, 1.3, 1.4, 0.05, 0.6) },
	-- «Грибница»: шлепок споры, рост поляны, выдох облака, лопающиеся грибы
	mSporeSeed = { layer(PSE.wetHit1, 0.3, 1.3, 1.5, nil, 0.3), layer(PSE.bubbles, 0.2, 1.2, 1.4, nil, 0.4) },
	mGladeGrow = { layer(PSE.magicGrowly, 0.4, 0.75, 0.8, nil, 1.0), layer(PSE.rockCrunch, 0.25, 0.6, 0.65, 0.05, 0.5) },
	mExhale = { layer(PSE.airyHiss, 0.5, 0.6, 0.65, nil, 1.6), layer(PSE.bubbling, 0.3, 0.7, 0.75, 0.1, 1.4) },
	mExhalePuff = { layer(PSE.airyHiss, 0.2, 0.9, 1.0, nil, 0.4) },
	mSporeBurst = { layer(PSE.glassSplat, 0.4, 0.9, 1.0, nil, 0.5), layer(PSE.wetHit2, 0.35, 0.8, 0.9, 0.03, 0.4), layer(ENGINE.bass, 0.3, 0.7, 0.75) },
	-- «Остановка времени»: обход стрелки, откат
	mClockSweep = { layer(PSE.airWhoosh, 0.4, 1.0, 1.1, nil, 0.5), layer(PSE.magicChime, 0.25, 1.3, 1.4, 0.05, 0.6), layer(APM.percHit, 0.3, 1.3, 1.4, 0.1, 0.3) },
	mRewind = { layer(PSE.magicShimmer, 0.45, 0.7, 0.75, nil, 1.0), layer(PSE.sparkleBell, 0.3, 1.2, 1.3, 0.05, 1.0) },
}

-- Сокол — на выбор Артёма (звуки у Клинка сокольничего переделываются целиком).
M.candidates = {
	v2FalconCall = {
		{ label = "Крылья + крик вдали", layers = M.sounds.v2FalconCall },
		{ label = "Только крылья, двойной взмах", layers = { layer(PSE.wingsFlap, 0.5, 0.9, 1.0, nil, 0.6), layer(PSE.wingsFlap, 0.35, 1.05, 1.1, 0.25, 0.6) } },
		{ label = "Крылья + звон", layers = { layer(PSE.wingsFlap, 0.45, 0.95, 1.05, nil, 0.7), layer(PSE.magicChime, 0.2, 1.1, 1.2, 0.1, 0.8) } },
	},
	v2FalconDive = {
		{ label = "Свист нарастает", layers = M.sounds.v2FalconDive },
		{ label = "Тяжёлый свист", layers = { layer(PSE.heavyWhoosh, 0.45, 1.2, 1.3, nil, 0.45) } },
	},
	v2FalconHit = {
		{ label = "Хруст + удар + крылья", layers = M.sounds.v2FalconHit },
		{ label = "Удар клинком", layers = { layer(ENGINE.slash, 0.45, 1.3, 1.4), layer(APM.percHit, 0.4, 1.1, 1.2, nil, 0.35) } },
	},
}

M.picked = {
	v2FalconCall = 1,
	v2FalconDive = 1,
	v2FalconHit = 1,
}

return M
