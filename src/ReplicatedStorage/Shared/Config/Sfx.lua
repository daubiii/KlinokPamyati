--!nonstrict
-- Sfx
-- Звуки и музыка игры. Источники — только лицензированные для Roblox:
--   * встроенные звуки движка (rbxasset://sounds/…);
--   * Pro Sound Effects (официальный партнёр Roblox, «Courtesy of Pro Sound
--     Effects», загрузки 91xxxxxxxx);
--   * APM Music (APMOfficial) — музыка и кинематографичные удары.
-- Звуки из чужих игр (Castle Crashers, Silksong, TF2…) не берём: это и
-- риск модерации, и чужие права (раздел 11 плана: проверять лицензию).
--
-- Каждый звук — один или несколько слоёв: удар по броне = звон металла +
-- глухой удар. pitch — диапазон случайной высоты, чтобы удары не звучали
-- одинаково. Заменить звук = поменять id здесь, код не трогаем.

local Sfx = {}

local PSE = {
	shieldClang1 = "rbxassetid://9119072660", -- Shield Clang As Hit Metal Sword 1
	shieldClang2 = "rbxassetid://9119072674", -- Shield Clang As Hit Metal Sword 2
	securityGate = "rbxassetid://9118900665", -- Security Gate: удар, дребезг, скрип
	metalClatter = "rbxassetid://9116524438", -- Metal Box Hits, второй со звоном
	manacles = "rbxassetid://9116460113", -- Manacles Metal Clangs: цепи
	metalRattle = "rbxassetid://9116797354", -- Metal Rattle Thick Shake
	airWhoosh = "rbxassetid://9126283272", -- Wood Swish Ruler Whoosh Fast Movement In Air 13
	energyWhoosh = "rbxassetid://9125517884", -- Electric Whoosh Bys Singles Low End Synth Buzz 1
	waterImpact = "rbxassetid://9119481909", -- Splash Thunking Impact 1
	rockCrunch = "rbxassetid://9118633662", -- Rock Impacts Deep Crunchy Hits 10
	magicChime = "rbxassetid://9116394545", -- Magic Glows Soft Clusters Of Chiming Hits 1
}

local APM = {
	massiveHit = "rbxassetid://9045192152", -- Neurosis Massive Hit
	percHit = "rbxassetid://9045209987", -- Vindictive Raid Perc Hit
}

local ENGINE = {
	slash = "rbxasset://sounds/swordslash.wav",
	lunge = "rbxasset://sounds/swordlunge.wav",
	unsheath = "rbxasset://sounds/unsheath.wav",
	bass = "rbxasset://sounds/bass.wav",
	ping = "rbxasset://sounds/electronicpingshort.wav",
	click = "rbxasset://sounds/clickfast.wav",
	button = "rbxasset://sounds/button.wav",
	victory = "rbxasset://sounds/victory.wav",
	snap = "rbxasset://sounds/snap.mp3",
	splash = "rbxasset://sounds/impact_water.mp3",
}

-- length — обрезать слой через столько секунд (у APM-ударов длинный хвост).
local function layer(id: string, volume: number, pitchMin: number, pitchMax: number?, delay: number?, length: number?)
	return { id = id, volume = volume, pitch = { pitchMin, pitchMax or pitchMin }, delay = delay, length = length }
end

Sfx.sounds = {
	-- Взмахи героя.
	swing1 = { layer(ENGINE.slash, 0.5, 0.95, 1.08) },
	swing2 = { layer(ENGINE.slash, 0.5, 1.08, 1.2) },
	swing3 = { layer(ENGINE.lunge, 0.65, 0.82, 0.9), layer(ENGINE.slash, 0.3, 0.7, 0.75) },
	-- Попадание: звон по ржавой броне + глухой удар.
	hit = { layer(PSE.shieldClang1, 0.35, 1.25, 1.45), layer(APM.percHit, 0.45, 1.5, 1.7, nil, 0.3) },
	hitHeavy = { layer(PSE.shieldClang2, 0.5, 0.75, 0.85), layer(APM.percHit, 0.6, 1.0, 1.1, nil, 0.4), layer(ENGINE.bass, 0.35, 0.8, 0.85) },
	-- Парирование: высокий чистый звон стали.
	parry = { layer(PSE.shieldClang1, 0.8, 1.05, 1.15), layer(ENGINE.ping, 0.25, 1.9, 2.0) },
	parryFail = { layer(ENGINE.click, 0.4, 0.6, 0.7) },
	-- Рывок: короткий воздушный свист (правка 21.10.2026 — был тяжёлый выпад).
	dash = { layer(PSE.airWhoosh, 0.6, 1.15, 1.35, nil, 0.4) },
	hurt = { layer(APM.percHit, 0.5, 1.2, 1.3, nil, 0.35), layer(PSE.shieldClang2, 0.2, 0.6, 0.7) },
	-- Тяжёлое попадание по герою (>15% здоровья): глухой удар + низ.
	hurtHeavy = { layer(APM.percHit, 0.7, 0.85, 0.95, nil, 0.5), layer(ENGINE.bass, 0.45, 0.55, 0.6), layer(PSE.shieldClang2, 0.25, 0.5, 0.55) },
	-- Удар пришёлся в доспех: короткий звон пластин поверх «hurt».
	armorBlock = { layer(PSE.shieldClang1, 0.22, 0.85, 1.0, nil, 0.35), layer(PSE.metalRattle, 0.15, 1.3, 1.5, 0.02, 0.25) },
	-- Броня надета / найдена: лязг пластин и застёжка.
	armorEquip = { layer(PSE.metalRattle, 0.4, 0.9, 1.0, nil, 0.6), layer(PSE.shieldClang2, 0.28, 1.1, 1.2, 0.12, 0.6), layer(ENGINE.click, 0.25, 0.7, 0.75, 0.3) },
	heal = { layer(ENGINE.ping, 0.35, 1.0, 1.0), layer(ENGINE.ping, 0.25, 1.5, 1.5, 0.12) },
	-- Враги.
	enemyWindup = { layer(ENGINE.unsheath, 0.3, 0.85, 1.05) },
	enemyDeath = { layer(PSE.metalClatter, 0.45, 0.85, 1.05), layer(ENGINE.snap, 0.3, 0.6, 0.7) },
	-- Душа впитывается в клинок: звон памяти, два тона.
	soul = { layer(ENGINE.ping, 0.3, 1.25, 1.3), layer(ENGINE.ping, 0.22, 1.68, 1.72, 0.08) },
	door = { layer(PSE.securityGate, 0.55, 0.7, 0.8) },
	chest = { layer(PSE.metalRattle, 0.4, 1.1, 1.1), layer(ENGINE.victory, 0.25, 1.4, 1.4, 0.25) },
	levelUp = { layer(ENGINE.victory, 0.45, 1.0, 1.0) },
	bossHit = { layer(APM.massiveHit, 0.9, 1.0, 1.0, nil, 3.0) },
	bossIntro = { layer(APM.massiveHit, 1.0, 0.9, 0.9, nil, 6.0), layer(PSE.metalRattle, 0.5, 0.6, 0.6, 0.15) },
	chains = { layer(PSE.manacles, 0.55, 0.8, 0.95) },
	explode = { layer(ENGINE.bass, 0.8, 0.6, 0.7), layer(PSE.metalClatter, 0.4, 0.6, 0.7), layer(ENGINE.splash, 0.3, 0.5, 0.55) },
	slam = { layer(ENGINE.bass, 0.7, 0.5, 0.55), layer(APM.percHit, 0.5, 1.0, 1.0, nil, 1.4) },
	ability = { layer(ENGINE.lunge, 0.7, 0.6, 0.7), layer(APM.percHit, 0.35, 1.2, 1.2, nil, 1.2) },
	-- Способности оружия (AbilityFx). Заглушки из слоёв выше: в комментарии —
	-- каким должен быть настоящий звук.
	vortexSpin = { layer(PSE.airWhoosh, 0.6, 0.6, 0.7, nil, 0.6), layer(PSE.airWhoosh, 0.45, 0.8, 0.9, 0.35, 0.6) }, -- гул воронки
	vortexWave = { layer(PSE.airWhoosh, 0.7, 1.2, 1.3, nil, 0.5), layer(APM.percHit, 0.5, 1.0, 1.1, nil, 0.8) }, -- режущий выброс
	riftSlam = { layer(APM.massiveHit, 0.6, 1.2, 1.3, nil, 1.2), layer(ENGINE.bass, 0.7, 0.5, 0.55) }, -- удар в камень, треск
	riftErupt = { layer(PSE.metalClatter, 0.35, 0.5, 0.6), layer(ENGINE.bass, 0.6, 0.7, 0.8), layer(APM.percHit, 0.4, 0.8, 0.9, nil, 0.6) }, -- шипы рвут землю
	unlockThrow = { layer(PSE.airWhoosh, 0.6, 0.9, 1.0, nil, 0.5) }, -- свист ключа
	unlockLock = { layer(PSE.securityGate, 0.6, 0.45, 0.5), layer(PSE.manacles, 0.55, 0.8, 0.95) }, -- скрежет двери и цепи
	unlockOpen = { layer(APM.massiveHit, 0.7, 1.3, 1.4, nil, 1.5), layer(PSE.manacles, 0.5, 1.1, 1.2), layer(ENGINE.bass, 0.6, 0.6, 0.7) }, -- цепи рвутся
	keyholeBurst = { layer(PSE.shieldClang1, 0.45, 1.4, 1.5), layer(ENGINE.ping, 0.25, 1.6, 1.6) },
	gardenReap = { layer(PSE.energyWhoosh, 0.62, 0.84, 0.92, nil, 0.8), layer(PSE.airWhoosh, 0.32, 1.25, 1.4, nil, 0.35) },
	gardenReapHit = { layer(PSE.shieldClang1, 0.3, 1.2, 1.35), layer(ENGINE.bass, 0.2, 0.8, 0.9) },
	gardenFlood = { layer(PSE.waterImpact, 0.72, 0.72, 0.82, nil, 1.1), layer(PSE.rockCrunch, 0.36, 0.72, 0.82, 0.03, 0.65) },
	gardenPrune = { layer(PSE.airWhoosh, 0.5, 1.15, 1.3, nil, 0.35), layer(PSE.shieldClang1, 0.34, 1.25, 1.4, 0.04, 0.4) },
	gardenPruneHit = { layer(PSE.shieldClang1, 0.28, 1.4, 1.55), layer(ENGINE.snap, 0.2, 1.4, 1.6) },
	gardenBloom = { layer(PSE.magicChime, 0.48, 0.78, 0.86, nil, 1.0), layer(ENGINE.bass, 0.32, 0.62, 0.7, nil, 0.5) },
	gardenThorn = { layer(ENGINE.snap, 0.22, 1.45, 1.6), layer(PSE.airWhoosh, 0.18, 1.5, 1.65, nil, 0.2) },
	-- Враги этажа 1 (ТЗ врагов, раздел 2.4). Пока заглушки из звуков выше:
	-- в комментарии — каким должен быть настоящий звук.
	guardStep = { layer(PSE.metalClatter, 0.12, 1.3, 1.5, nil, 0.15) }, -- глухой лязг ржавых лат
	knightStep = { layer(PSE.metalClatter, 0.25, 0.7, 0.8, nil, 0.25), layer(ENGINE.bass, 0.15, 1.2, 1.3) }, -- тяжёлый латный шаг
	bossStep = { layer(ENGINE.bass, 0.4, 0.5, 0.55), layer(PSE.metalRattle, 0.15, 0.5, 0.55, nil, 0.4) }, -- каменный гул шага
	shadeWhisper = { layer(PSE.airWhoosh, 0.3, 0.55, 0.65, nil, 0.4) }, -- шёпот на вдохе
	bowDraw = { layer(ENGINE.unsheath, 0.3, 0.6, 0.7) }, -- скрип тетивы, 0,6 с
	bowRelease = { layer(ENGINE.snap, 0.4, 1.4, 1.6), layer(PSE.airWhoosh, 0.3, 1.5, 1.7, nil, 0.25) }, -- щелчок и свист
	arrowHit = { layer(ENGINE.snap, 0.35, 0.8, 0.9) }, -- стук о камень
	martyrGroan = { layer(ENGINE.bass, 0.25, 0.35, 0.4) }, -- хриплый стон
	fuseBeep = { layer(ENGINE.ping, 0.2, 2.2, 2.3) }, -- писк фитиля
	bossRoar = { layer(APM.massiveHit, 0.8, 0.7, 0.7, nil, 2.5), layer(PSE.securityGate, 0.4, 0.5, 0.55) }, -- рёв со скрипом петель ворот
	chainRattle = { layer(PSE.manacles, 0.45, 0.9, 1.0) }, -- лязг цепей
	chainSlam = { layer(PSE.manacles, 0.5, 0.7, 0.8), layer(ENGINE.bass, 0.4, 0.7, 0.8) },
	bossSpin = { layer(PSE.airWhoosh, 0.6, 0.55, 0.6, nil, 0.6) }, -- низкий свист засова
	bossCharge = { layer(ENGINE.bass, 0.5, 0.4, 0.5), layer(PSE.metalRattle, 0.3, 0.7, 0.7) }, -- нарастающий гул
	bossWallHit = { layer(APM.massiveHit, 0.9, 1.1, 1.1, nil, 2.0) },
	gateCreak = { layer(PSE.securityGate, 0.6, 0.45, 0.5) }, -- скважина открывается
	ui = { layer(ENGINE.button, 0.3, 1.0, 1.0) },
	uiHover = { layer(ENGINE.click, 0.15, 1.6, 1.6) },
	-- Хаб «Долина Последнего Эха». Заглушки из слоёв выше: в комментарии —
	-- каким должен быть настоящий звук.
	hubAwaken = { layer(ENGINE.ping, 0.3, 0.8, 0.8), layer(ENGINE.ping, 0.25, 1.2, 1.2, 0.15), layer(ENGINE.ping, 0.2, 1.6, 1.6, 0.3) }, -- кубики памяти собираются
	hubChime = { layer(ENGINE.ping, 0.22, 0.9, 0.9), layer(ENGINE.ping, 0.16, 1.35, 1.35, 0.2) }, -- тихий звон у Озера Памяти
	hubBell = { layer(PSE.shieldClang2, 0.5, 0.42, 0.45), layer(ENGINE.bass, 0.25, 0.5, 0.5) }, -- колокол Звонницы, глуховатый
	hubTalk = { layer(ENGINE.click, 0.2, 1.1, 1.3) }, -- житель отвечает
	hubQuest = { layer(ENGINE.victory, 0.35, 1.2, 1.2) }, -- задание выполнено
	hubPortal = { layer(ENGINE.ping, 0.3, 0.6, 0.6), layer(PSE.airWhoosh, 0.4, 0.6, 0.7, 0.1, 0.5) }, -- Врата: голубая вспышка
	-- Этаж 2 «Затопленные сады». Заглушки из слоёв выше: в комментарии —
	-- каким должен быть настоящий звук.
	gardenStep = { layer(ENGINE.splash, 0.12, 1.4, 1.7, nil, 0.25) }, -- мокрый шаг по тине
	treantStep = { layer(ENGINE.bass, 0.35, 0.45, 0.5), layer(ENGINE.snap, 0.15, 0.4, 0.5) }, -- тяжёлый деревянный шаг
	barkBlock = { layer(ENGINE.snap, 0.45, 0.45, 0.55), layer(PSE.shieldClang2, 0.15, 0.45, 0.5) }, -- клинок вязнет в коре
	rootsBurst = { layer(ENGINE.snap, 0.5, 0.35, 0.45), layer(ENGINE.bass, 0.5, 0.6, 0.7) }, -- корни рвут землю
	beeBuzz = { layer(PSE.airWhoosh, 0.25, 2.2, 2.6, nil, 0.35) }, -- жужжание перед жалом
	mudSplash = { layer(ENGINE.splash, 0.55, 0.7, 0.85), layer(ENGINE.bass, 0.2, 0.9, 1.0) }, -- шлепок тины
	pourRot = { layer(ENGINE.splash, 0.35, 1.3, 1.5, nil, 0.7) }, -- плеск гнили из лейки (повторяется)
	thornShot = { layer(ENGINE.snap, 0.35, 1.8, 2.0), layer(PSE.airWhoosh, 0.25, 1.8, 2.0, nil, 0.2) }, -- щелчок шипов из ладони
	rangerHop = { layer(PSE.airWhoosh, 0.35, 1.0, 1.2, nil, 0.3) }, -- шорох листвы при отскоке
	statueCrack = { layer(APM.massiveHit, 0.5, 1.4, 1.5, nil, 1.0), layer(ENGINE.snap, 0.45, 0.35, 0.4) }, -- мрамор трескается
	bloom = { layer(ENGINE.ping, 0.3, 0.5, 0.5), layer(ENGINE.bass, 0.45, 0.45, 0.5) }, -- гнилое цветение раскрывается
	poisonTick = { layer(ENGINE.click, 0.12, 0.5, 0.6) }, -- гниль жжёт
	-- Карта этажа 2: шлюзы, тайники, ловушки.
	valveTurn = { layer(PSE.metalRattle, 0.4, 0.55, 0.6), layer(ENGINE.splash, 0.45, 0.6, 0.7, 0.3) }, -- скрип вентиля, вода уходит
	valveReady = { layer(ENGINE.ping, 0.25, 0.7, 0.7), layer(ENGINE.ping, 0.18, 1.05, 1.05, 0.15) }, -- вентиль освободился
	sluiceOpen = { layer(PSE.securityGate, 0.6, 0.4, 0.45), layer(ENGINE.splash, 0.6, 0.45, 0.5, 0.2), layer(ENGINE.bass, 0.4, 0.5, 0.5) }, -- решётка шлюза уходит вверх
	secretFound = { layer(ENGINE.snap, 0.4, 0.5, 0.6), layer(ENGINE.ping, 0.25, 1.2, 1.2, 0.2), layer(ENGINE.ping, 0.2, 1.6, 1.6, 0.35) }, -- лозы рвутся, тайник
	propHit = { layer(ENGINE.snap, 0.28, 0.75, 0.95) }, -- лёгкий треск дерева или соломы
	propBreak = { layer(ENGINE.snap, 0.55, 0.4, 0.55), layer(ENGINE.bass, 0.2, 0.75, 0.85) }, -- предмет разлетается
	plankCrack = { layer(ENGINE.snap, 0.4, 0.8, 1.0) }, -- гнилая доска трещит
	plankBreak = { layer(ENGINE.snap, 0.55, 0.45, 0.55), layer(ENGINE.splash, 0.45, 0.8, 0.9, 0.15) }, -- доска ломается в воду
	spanCrack = { layer(ENGINE.snap, 0.45, 0.35, 0.45), layer(ENGINE.bass, 0.3, 0.6, 0.7) }, -- камень пролёта трескается
	spanFall = { layer(APM.massiveHit, 0.55, 1.2, 1.3, nil, 1.2), layer(ENGINE.splash, 0.5, 0.5, 0.6, 0.4) }, -- пролёт рушится
	jetWarn = { layer(ENGINE.splash, 0.25, 1.5, 1.7, nil, 0.4) }, -- бульканье перед струёй
	jetBurst = { layer(ENGINE.splash, 0.55, 0.55, 0.65), layer(PSE.airWhoosh, 0.3, 0.7, 0.8, nil, 0.5) }, -- струя фонтана
	sporeBurst = { layer(PSE.airWhoosh, 0.35, 0.5, 0.6, nil, 0.6), layer(ENGINE.bass, 0.2, 1.1, 1.2) }, -- облако спор
	dartWarn = { layer(ENGINE.click, 0.3, 0.6, 0.7), layer(ENGINE.click, 0.25, 0.9, 0.9, 0.12) }, -- плита щёлкнула под ногой

	-- Этажи 4–5: эффекты врагов и ломаемых декораций.
	forgeStep = { layer(PSE.metalClatter, 0.22, 0.45, 0.55, nil, 0.3), layer(ENGINE.bass, 0.25, 0.75, 0.85) },
	forgeDeath = { layer(PSE.securityGate, 0.5, 0.6, 0.7, nil, 1.2), layer(PSE.metalClatter, 0.5, 0.7, 0.8) },
	forgeBellows = { layer(PSE.airWhoosh, 0.4, 0.45, 0.55, nil, 0.8), layer(ENGINE.bass, 0.2, 1.1, 1.2) },
	forgeBlast = { layer(PSE.energyWhoosh, 0.5, 0.6, 0.7, nil, 0.9), layer(ENGINE.splash, 0.25, 1.6, 1.8, nil, 0.5) },
	spiritHiss = { layer(PSE.energyWhoosh, 0.3, 1.4, 1.7, nil, 0.4) },
	spiritDeath = { layer(PSE.energyWhoosh, 0.4, 0.8, 0.9, nil, 0.6), layer(ENGINE.snap, 0.25, 1.4, 1.5) },
	slagLob = { layer(ENGINE.splash, 0.45, 0.4, 0.5), layer(PSE.rockCrunch, 0.35, 1.2, 1.3, nil, 0.6) },
	forgePour = { layer(ENGINE.splash, 0.5, 0.35, 0.42, nil, 1.0), layer(PSE.energyWhoosh, 0.35, 0.5, 0.55, nil, 0.8) },
	forgeRoar = { layer(APM.massiveHit, 0.7, 0.6, 0.65, nil, 2.2), layer(PSE.airWhoosh, 0.45, 0.35, 0.4, 0.2, 1.0) },
	moltenHiss = { layer(ENGINE.splash, 0.25, 1.8, 2.0, nil, 0.4) },
	ventHiss = { layer(PSE.airWhoosh, 0.45, 0.8, 0.9, nil, 0.9), layer(ENGINE.splash, 0.2, 2.0, 2.2, nil, 0.4) },
	cartRoll = { layer(PSE.metalRattle, 0.45, 0.4, 0.45, nil, 2.0), layer(ENGINE.bass, 0.3, 0.5, 0.55) },
	leverPull = { layer(PSE.metalRattle, 0.45, 0.7, 0.8, nil, 0.8), layer(ENGINE.click, 0.4, 0.5, 0.5, 0.25) },
	stoneDeath = { layer(PSE.rockCrunch, 0.6, 0.7, 0.8), layer(APM.massiveHit, 0.3, 1.5, 1.6, nil, 0.8) },
	chronicleChant = { layer(PSE.magicChime, 0.4, 0.5, 0.55, nil, 1.4), layer(ENGINE.bass, 0.25, 0.6, 0.65) },
	runeCharge = { layer(PSE.magicChime, 0.3, 0.9, 1.0, nil, 0.7) },
	runeShot = { layer(PSE.energyWhoosh, 0.35, 1.3, 1.5, nil, 0.4), layer(ENGINE.ping, 0.15, 1.4, 1.5) },
	sealShatter = { layer(ENGINE.snap, 0.5, 0.5, 0.6), layer(PSE.magicChime, 0.45, 1.3, 1.4, nil, 1.2) },
	sealHum = { layer(PSE.magicChime, 0.2, 0.4, 0.45, nil, 1.0) },
	inkSplash = { layer(ENGINE.splash, 0.45, 0.55, 0.65), layer(ENGINE.bass, 0.15, 1.2, 1.3) },
	pageRustle = { layer(PSE.airWhoosh, 0.3, 1.5, 1.8, nil, 0.4), layer(ENGINE.click, 0.15, 1.6, 1.8) },
	pageShot = { layer(PSE.airWhoosh, 0.3, 2.0, 2.3, nil, 0.25), layer(ENGINE.snap, 0.2, 2.0, 2.2) },
	chronicleBeam = { layer(PSE.energyWhoosh, 0.6, 0.45, 0.5, nil, 1.2), layer(PSE.magicChime, 0.3, 0.7, 0.75, 0.1, 1.0) },
	erasureHum = { layer(PSE.energyWhoosh, 0.3, 0.35, 0.4, nil, 1.5), layer(ENGINE.bass, 0.3, 0.4, 0.45) },
	vaultOpen = { layer(PSE.securityGate, 0.6, 0.35, 0.4, nil, 2.4), layer(ENGINE.bass, 0.45, 0.45, 0.5), layer(PSE.magicChime, 0.35, 0.6, 0.65, 0.6, 2.0) },
	epilogue = { layer(PSE.magicChime, 0.4, 0.5, 0.5, nil, 2.0), layer(PSE.magicChime, 0.3, 0.75, 0.75, 0.5, 2.0) },
	breakWoodHit = { layer(PSE.rockCrunch, 0.25, 1.6, 1.8, nil, 0.3), layer(ENGINE.snap, 0.2, 1.1, 1.3) },
	breakWood = { layer(ENGINE.snap, 0.55, 0.55, 0.7), layer(PSE.rockCrunch, 0.4, 1.3, 1.5, nil, 0.6) },
	breakMetalHit = { layer(PSE.shieldClang1, 0.3, 1.1, 1.3, nil, 0.5) },
	breakMetal = { layer(PSE.metalClatter, 0.55, 0.8, 0.95), layer(PSE.metalRattle, 0.3, 0.9, 1.0, 0.1, 0.8) },
	breakStoneHit = { layer(PSE.rockCrunch, 0.3, 1.2, 1.4, nil, 0.4) },
	breakStone = { layer(PSE.rockCrunch, 0.6, 0.8, 0.95), layer(ENGINE.bass, 0.25, 0.9, 1.0) },
	breakPaperHit = { layer(PSE.airWhoosh, 0.25, 1.9, 2.2, nil, 0.25) },
	breakPaper = { layer(PSE.airWhoosh, 0.4, 1.4, 1.7, nil, 0.5), layer(ENGINE.click, 0.2, 1.4, 1.6) },
	breakLeatherHit = { layer(ENGINE.bass, 0.25, 1.4, 1.6) },
	breakLeather = { layer(PSE.airWhoosh, 0.4, 0.6, 0.7, nil, 0.6), layer(ENGINE.snap, 0.3, 0.7, 0.8) },
}

-- ===== Прослушивание (решение Артёма 28.10.2026: выбирает на слух) =====
-- Кандидаты для звуков, которые звучали странно. Играет вариант
-- Sfx.picked[имя] (по умолчанию 1); в Studio переключается командой
-- «sfx <имя> <номер>» (DebugCommands) — звук сразу проигрывается.
-- Всё — официальная библиотека Roblox (Pro Sound Effects, APM Music).

local PSE_PICK = {
	chimes1 = "rbxassetid://9116394545", -- Magic Glows Soft Clusters Of Chiming Hits 1 (2,1 с)
	chimes2 = "rbxassetid://9116394876", -- … Chiming Hits 2 (2,4 с)
	chimes3 = "rbxassetid://9116394756", -- … Chiming Hits 3 (3,9 с)
	chimes4 = "rbxassetid://9116395089", -- … Chiming Hits 4 (2,9 с)
	chimes5 = "rbxassetid://9116395085", -- … Chiming Hits 5 (4,9 с)
	swish1 = "rbxassetid://9126283894", -- Wood Swish Ruler Whoosh 1 (0,8 с)
	swish2 = "rbxassetid://9126283906", -- … Whoosh 2 (0,6 с)
	swish5 = "rbxassetid://9126284094", -- … Whoosh 5 (0,6 с)
	swish12 = "rbxassetid://9126283275", -- … Whoosh 12 (0,8 с)
	swish17 = "rbxassetid://9126283592", -- … Whoosh 17 (0,7 с)
	shing1 = "rbxassetid://9119076604", -- Shing Ringy 1: металл клинка, звон (1,8 с)
	shing3 = "rbxassetid://9119076917", -- Shing Ringy 3 (1,3 с)
	knife402 = "rbxassetid://9116186866", -- Knife Blade 402: скольжение клинка
}
local APM_PICK = {
	hopefulPath = "rbxassetid://1838019098", -- Hopeful Path (sting)
}

Sfx.candidates = {
	-- Возрождение героя в хабе (было: три электронных писка).
	hubAwaken = {
		{ label = "мягкие колокольчики памяти", layers = { layer(PSE_PICK.chimes1, 0.45, 1.0, 1.0, nil, 2.0) } },
		{ label = "колокольчики, ниже и длиннее", layers = { layer(PSE_PICK.chimes2, 0.45, 0.85, 0.85, nil, 2.4) } },
		{ label = "колокольчики + глухой выдох", layers = { layer(PSE_PICK.chimes4, 0.4, 1.0, 1.0, nil, 2.6), layer(ENGINE.bass, 0.2, 0.45, 0.45) } },
	},
	-- Третий, сокрушающий удар серии.
	swing3 = {
		{ label = "тяжёлый свист + звон стали", layers = { layer(PSE_PICK.swish12, 0.6, 0.68, 0.74, nil, 0.6), layer(PSE_PICK.shing3, 0.22, 0.85, 0.95, 0.05, 0.6) } },
		{ label = "низкий свист + удар", layers = { layer(PSE_PICK.swish1, 0.65, 0.62, 0.68, nil, 0.6), layer(APM.percHit, 0.3, 1.3, 1.4, 0.08, 0.3) } },
		{ label = "только низкий свист", layers = { layer(PSE_PICK.swish17, 0.7, 0.6, 0.66, nil, 0.6) } },
	},
	-- Первый и второй удары серии (было: встроенный swordslash.wav — «пластиковый»).
	swing1 = {
		{ label = "резкий свист клинка", layers = { layer(PSE_PICK.swish5, 0.55, 1.0, 1.12, nil, 0.4), layer(PSE_PICK.knife402, 0.14, 1.2, 1.35, 0.02, 0.3) } },
		{ label = "свист, ниже", layers = { layer(PSE_PICK.swish2, 0.55, 0.9, 1.0, nil, 0.4) } },
		{ label = "как было", layers = { layer(ENGINE.slash, 0.5, 0.95, 1.08) } },
	},
	swing2 = {
		{ label = "обратный свист, выше", layers = { layer(PSE_PICK.swish2, 0.55, 1.12, 1.25, nil, 0.4), layer(PSE_PICK.knife402, 0.14, 1.35, 1.5, 0.02, 0.3) } },
		{ label = "свист 17", layers = { layer(PSE_PICK.swish17, 0.55, 1.05, 1.15, nil, 0.4) } },
		{ label = "как было", layers = { layer(ENGINE.slash, 0.5, 1.08, 1.2) } },
	},
	-- Попадание по врагу: больше «мяса», меньше звона.
	hit = {
		{ label = "глухой удар + сталь", layers = { layer(APM.percHit, 0.5, 1.35, 1.55, nil, 0.3), layer(PSE.shieldClang1, 0.22, 1.3, 1.5, nil, 0.3), layer(ENGINE.bass, 0.18, 1.1, 1.2) } },
		{ label = "звон клинка shing", layers = { layer(PSE_PICK.shing3, 0.3, 1.2, 1.35, nil, 0.4), layer(APM.percHit, 0.4, 1.5, 1.7, nil, 0.3) } },
		{ label = "как было", layers = { layer(PSE.shieldClang1, 0.35, 1.25, 1.45), layer(APM.percHit, 0.45, 1.5, 1.7, nil, 0.3) } },
	},
	-- Парирование: чистый «шинг» стали вместо электронного писка.
	parry = {
		{ label = "звонкий shing + удар щита", layers = { layer(PSE_PICK.shing1, 0.55, 1.05, 1.12, nil, 0.9), layer(PSE.shieldClang1, 0.6, 1.0, 1.1, nil, 0.5) } },
		{ label = "shing короче", layers = { layer(PSE_PICK.shing3, 0.6, 1.1, 1.2, nil, 0.6), layer(APM.percHit, 0.3, 1.6, 1.7, nil, 0.25) } },
		{ label = "как было", layers = { layer(PSE.shieldClang1, 0.8, 1.05, 1.15), layer(ENGINE.ping, 0.25, 1.9, 2.0) } },
	},
	-- Рывок.
	dash = {
		{ label = "короткий свист + шорох плаща", layers = { layer(PSE_PICK.swish1, 0.5, 1.25, 1.4, nil, 0.35), layer(PSE.metalRattle, 0.08, 1.6, 1.8, nil, 0.2) } },
		{ label = "как было", layers = { layer(PSE.airWhoosh, 0.6, 1.15, 1.35, nil, 0.4) } },
	},
	-- Парирование впустую.
	parryFail = {
		{ label = "короткий свист мимо", layers = { layer(PSE_PICK.swish5, 0.35, 1.15, 1.25, nil, 0.4) } },
		{ label = "скольжение клинка", layers = { layer(PSE_PICK.knife402, 0.3, 1.1, 1.2, nil, 0.45) } },
		{ label = "мягкий свист, ниже", layers = { layer(PSE_PICK.swish2, 0.3, 0.9, 0.95, nil, 0.4) } },
	},
	-- Лечение.
	heal = {
		{ label = "светлые колокольчики", layers = { layer(PSE_PICK.chimes1, 0.35, 1.3, 1.3, nil, 1.2) } },
		{ label = "колокольчики, длиннее", layers = { layer(PSE_PICK.chimes3, 0.32, 1.15, 1.15, nil, 1.6) } },
		{ label = "как было (два писка)", layers = { layer(ENGINE.ping, 0.35, 1.0, 1.0), layer(ENGINE.ping, 0.25, 1.5, 1.5, 0.12) } },
	},
	-- Новый уровень.
	levelUp = {
		{ label = "каскад колокольчиков", layers = { layer(PSE_PICK.chimes5, 0.45, 1.0, 1.0, nil, 2.5) } },
		{ label = "короткая музыкальная фраза APM", layers = { layer(APM_PICK.hopefulPath, 0.4, 1.0, 1.0, nil, 3.5) } },
		{ label = "как было", layers = { layer(ENGINE.victory, 0.45, 1.0, 1.0) } },
	},
	-- Душа впиталась в клинок.
	soul = {
		{ label = "высокий звон памяти", layers = { layer(PSE_PICK.chimes2, 0.28, 1.6, 1.7, nil, 0.8) } },
		{ label = "как было (два писка)", layers = { layer(ENGINE.ping, 0.3, 1.25, 1.3), layer(ENGINE.ping, 0.22, 1.68, 1.72, 0.08) } },
	},
}

-- Выбранный вариант (номер в Sfx.candidates). Поменять = вписать номер.
Sfx.picked = {
	swing1 = 1,
	swing2 = 1,
	hit = 1,
	parry = 1,
	dash = 1,
	hubAwaken = 1,
	swing3 = 1,
	parryFail = 1,
	heal = 1,
	levelUp = 1,
	soul = 1,
}

-- Маг (Config/SfxMage): удары посохом, барьер, «Покров», дебафы, заклинания.
do
	local okMage, SfxMage = pcall(require, script.Parent.SfxMage)
	if okMage and type(SfxMage) == "table" then
		for name, layers in pairs(SfxMage.sounds or {}) do
			Sfx.sounds[name] = layers
		end
		for name, options in pairs(SfxMage.candidates or {}) do
			Sfx.candidates[name] = options
		end
		for name, pick in pairs(SfxMage.picked or {}) do
			Sfx.picked[name] = pick
		end
		Sfx.mageHitByStyle = SfxMage.HitByStyle
	end
end

-- Оружие этажей 3–5 (Config/SfxWeapons345): hunt* / forge* / chron*. Без этого блока
-- AbilityFxHunt / Forge / Chronicle звали звуки, которых нет в Sfx, — и способности молчали.
do
	-- Уже существующие имена не перезаписываем: звуки врагов и боссов этажей (forgeStep, forgePour…)
	-- живут здесь же, оружие не должно их подменять.
	local okWeapons, SfxWeapons345 = pcall(require, script.Parent.SfxWeapons345)
	if okWeapons and type(SfxWeapons345) == "table" then
		local taken = {}
		for name, layers in pairs(SfxWeapons345.sounds or {}) do
			if Sfx.sounds[name] == nil and Sfx.candidates[name] == nil then
				Sfx.sounds[name] = layers
			else
				taken[name] = true
			end
		end
		for name, options in pairs(SfxWeapons345.candidates or {}) do
			if not taken[name] and Sfx.candidates[name] == nil then
				Sfx.candidates[name] = options
			end
		end
		for name, pick in pairs(SfxWeapons345.picked or {}) do
			if not taken[name] and Sfx.picked[name] == nil then
				Sfx.picked[name] = pick
			end
		end
	end
end

-- Продлённые фазы способностей (Config/SfxSkills): удары, хвосты, звон — поверх прежних звуков.
do
	local okSkills, SfxSkills = pcall(require, script.Parent.SfxSkills)
	if okSkills and type(SfxSkills) == "table" then
		for name, layers in pairs(SfxSkills.sounds or {}) do
			Sfx.sounds[name] = layers
		end
		for name, options in pairs(SfxSkills.candidates or {}) do
			Sfx.candidates[name] = options
		end
		for name, pick in pairs(SfxSkills.picked or {}) do
			Sfx.picked[name] = pick
		end
	end
end

-- Слои звука с учётом выбора; override — номер для прослушивания.
function Sfx.layers(name: string, override: number?)
	local options = Sfx.candidates[name]
	if options then
		local pick = options[override or Sfx.picked[name] or 1]
		if pick then
			return pick.layers
		end
	end
	return Sfx.sounds[name]
end

-- Переделанные способности мечей и молотов (Config/SfxWeaponsV2, имена v2*).
do
	local okV2, SfxWeaponsV2 = pcall(require, script.Parent.SfxWeaponsV2)
	if okV2 and type(SfxWeaponsV2) == "table" then
		for name, layers in pairs(SfxWeaponsV2.sounds or {}) do
			Sfx.sounds[name] = layers
		end
		for name, options in pairs(SfxWeaponsV2.candidates or {}) do
			Sfx.candidates[name] = options
		end
		for name, pick in pairs(SfxWeaponsV2.picked or {}) do
			Sfx.picked[name] = pick
		end
	end
end

-- Петли, привязанные к врагу (EnemyFx ставит Sound у точки эффекта).
Sfx.loops = {
	fuseHiss = { id = PSE.metalRattle, volume = 0.12, pitch = 2.4 }, -- шипение фитиля (заглушка)
}

-- Музыка: фон этажа и тема босса. Переход — плавный (AudioController).
Sfx.music = {
	floor = { id = "rbxassetid://1840777445", volume = 0.28 }, -- APM «Worlds Of Darkness»
	boss = { id = "rbxassetid://1836104000", volume = 0.4 }, -- APM «Determined Epic Theme (Alt 1)»
	-- Долина: спокойная тема. Пока трек не выбран — тишина (id пустой).
	hub = { id = "", volume = 0.25 },
}
Sfx.musicFade = 1.6

return Sfx
