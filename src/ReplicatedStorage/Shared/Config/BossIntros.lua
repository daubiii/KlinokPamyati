--!nonstrict
-- Config/BossIntros — сцены появления боссов: у каждого своя, ~8 секунд
-- (решение Артёма: «уникальные кинематографичные сцены — устрашить, захватить
-- дух»). Вместо общей сцены «сборка из кубиков + рёв» (BossIntroController v1).
--
--   full    длительность полной сцены, с (босс неуязвим и не атакует)
--   short   повтор в той же сессии (все игроки этажа уже видели сцену):
--           только хвост сцены — подъём, удар, рёв и титр
--   anim    анимация появления (EnemyVisuals.spawn), длиной full; короткая
--           версия играет её с отметки full − short (сервер сдвигает
--           EnemyStateAt назад, клиент — сценарий)
--   beats   ключевые отметки сценария и анимации (секунды полной сцены)
--   quote   строка под титром (печатается)
--   style   оформление титра: kind (iron, vines, claws, molten, ink) и цвета
--
-- Сценарии камеры и эффекты — Controllers/BossIntroScenes, режиссёр —
-- Controllers/BossIntroController, анимации — Anim/<Набор>Moves (IntroScene).

local BossIntros = {}

local rgb = Color3.fromRGB

BossIntros.Scenes = {
	-- Ворота Хранилища захлопываются; страж спит на колене у ворот, ключи
	-- слетаются к нему в грудь, он встаёт, вонзает меч — пол раскалывается.
	gatekeeper = {
		full = 8.0, short = 3.4, anim = "IntroScene",
		beats = { slam = 0.35, keys = 1.7, eyes = 3.6, rise = 3.9, plant = 5.9, roar = 6.3 },
		quote = "Ни один ключ не уйдёт отсюда.",
		style = { kind = "iron", name = rgb(255, 214, 120), title = rgb(255, 238, 200), line = rgb(255, 170, 40), glow = rgb(255, 190, 60) },
		tint = { brightness = -0.08, contrast = 0.18, saturation = -0.35, color = rgb(255, 236, 210) },
	},
	-- Туман и лепестки; мраморную статую оплетают лозы, по мрамору бегут
	-- зелёные трещины, глаза загораются, статуя оживает, вокруг — кольцо роз.
	rosewarden = {
		full = 8.0, short = 3.4, anim = "IntroScene",
		beats = { vines = 1.9, crack = 3.7, eyes = 4.0, wake = 4.2, bloom = 5.8, roar = 6.2 },
		quote = "Мой сад не любит чужих корней.",
		style = { kind = "vines", name = rgb(170, 255, 200), title = rgb(255, 205, 220), line = rgb(124, 242, 176), glow = rgb(240, 90, 130) },
		tint = { brightness = -0.05, contrast = 0.12, saturation = -0.15, color = rgb(222, 255, 236) },
	},
	-- Темнота, рог вдалеке, по кругу загораются глаза гончих, затем факелы;
	-- ловчий на высоком пне прыгает вниз, свора стекается к нему, рог.
	royal_huntsman = {
		full = 8.5, short = 3.4, anim = "IntroScene",
		beats = { horn = 0.4, eyes = 1.8, torches = 3.4, leap = 4.6, land = 5.3, gather = 5.6, roar = 6.6 },
		quote = "Гон начался. Дичь — ты.",
		style = { kind = "claws", name = rgb(255, 210, 120), title = rgb(255, 228, 190), line = rgb(196, 36, 36), glow = rgb(255, 120, 40) },
		tint = { brightness = -0.06, contrast = 0.2, saturation = -0.2, color = rgb(255, 228, 200) },
		perch = { height = 13, back = 9 }, -- пень-насест: выше и позади точки появления
	},
	-- Ковш льёт расплав в литейную форму; форма трескается и разлетается,
	-- литейщик выходит раскалённым добела и остывает; удар — фонтан искр.
	elder_founder = {
		full = 8.0, short = 3.4, anim = "IntroScene",
		beats = { pour = 0.6, fill = 1.8, crack = 3.4, burst = 4.2, cool = 4.3, slam = 6.4, roar = 6.7 },
		quote = "Всё, что входит в горн, выходит иным.",
		style = { kind = "molten", name = rgb(255, 236, 190), title = rgb(255, 200, 150), line = rgb(226, 103, 43), glow = rgb(255, 200, 87) },
		tint = { brightness = -0.04, contrast = 0.2, saturation = 0.05, color = rgb(255, 226, 200) },
	},
	-- Вихрь страниц; из пола поднимается раскрытая хроника, Хрониста
	-- «вписывают» снизу вверх строкой света; корона загорается, книга
	-- захлопывается, страницы разлетаются.
	chief_chronicler = {
		full = 8.5, short = 3.4, anim = "IntroScene",
		beats = { vortex = 0.2, book = 2.0, scan = 3.2, scanEnd = 5.3, eyes = 5.4, spread = 5.7, slam = 6.4, roar = 6.8 },
		quote = "Твоя глава уже написана. Последняя строка — моя.",
		style = { kind = "ink", name = rgb(220, 212, 255), title = rgb(184, 227, 255), line = rgb(142, 124, 224), glow = rgb(184, 227, 255) },
		tint = { brightness = -0.06, contrast = 0.16, saturation = -0.25, color = rgb(226, 222, 255) },
	},
}

function BossIntros.get(typeId: string?)
	return typeId and BossIntros.Scenes[typeId] or nil
end

-- Длительность сцены (полной или короткой); nil — у босса нет своей сцены.
function BossIntros.duration(typeId: string?, short: boolean?): number?
	local scene = BossIntros.get(typeId)
	if not scene then
		return nil
	end
	return short and scene.short or scene.full
end

-- С какой секунды полной сцены начинается короткая.
function BossIntros.skip(typeId: string?, short: boolean?): number
	local scene = BossIntros.get(typeId)
	if not scene or not short then
		return 0
	end
	return scene.full - scene.short
end

-- Атрибут игрока: сцену этого босса уже видел (в этой сессии).
function BossIntros.seenAttribute(typeId: string): string
	return "BossIntroSeen_" .. typeId
end

return BossIntros
