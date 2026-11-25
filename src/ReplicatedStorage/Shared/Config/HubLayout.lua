--!nonstrict
-- HubLayout
-- Ключевые точки хаба «Долина Последнего Эха» (сгенерировано из сборки Hub.rbxmx).
-- Модели уже стоят на местах; здесь — точки для скриптов (спавн, возврат,
-- станции), тексты указателей и свет.
--
-- Сборка сделана вокруг (0, 0), но там строится этаж (комнаты идут от Z = 0
-- в сторону −Z). Поэтому вся папка Workspace.Hub сдвинута на Origin, а точки
-- ниже остаются в координатах сборки: мировую точку даёт HubLayout.world().

local Palette = require(script.Parent.Palette)

local HubLayout = {}

-- Сдвиг папки Workspace.Hub относительно сборки. Менять только вместе с
-- переносом самой папки (tools/lua/install_hub.lua).
HubLayout.Origin = Vector3.new(0, 0, 1600)
-- Радиус, внутри которого игрок «в долине» (горы-кольцо до 430 стад).
HubLayout.Radius = 460

function HubLayout.world(point: Vector3): Vector3
	return HubLayout.Origin + point
end

HubLayout.Points = {
	Spawn = Vector3.new(-1.0, 11.1, 386.0),
	Ledge = Vector3.new(0.0, 40.3, 214.0),
	StairsBottom = Vector3.new(0.0, 0.0, 106.0),
	Fork = Vector3.new(8.0, 0.0, 92.0),
	Square = Vector3.new(150.0, 0.3, 40.0),
	Portal = Vector3.new(-169.3, 5.4, -18.1),
	ReturnFromFloor = Vector3.new(-169.3, 5.4, -18.1),
	CaveForge = Vector3.new(40.5, 26.0, 281.0),
	VillageForge = Vector3.new(120.0, 1.5, 77.5),
	DailyChest = Vector3.new(144.0, 0.0, 40.0),
	Shop = Vector3.new(193.8, 0.0, 51.8),
	QuestBoard = Vector3.new(128.4, 0.0, 7.4),
	Leaderboard = Vector3.new(176.0, 6.7, -46.7),
	Pond = Vector3.new(-6.0, 22.5, 279.0),
	Bridge = Vector3.new(6.0, 20.0, 326.0),
	TrainingYard = Vector3.new(36.0, 0.0, 130.0),
	Bell = Vector3.new(166.0, 29.0, -4.0),
	WaterfallSpray = Vector3.new(-128.0, 2.0, -298.0),
	-- Старые станции без своих моделей (решение владельца: встроить в деревню).
	Altar = Vector3.new(138.0, 1.0, -50.0), -- в глубине часовни
	Archive = Vector3.new(100.0, 1.2, 4.0), -- зал гильдии
	Lake = Vector3.new(-30.0, 0.0, -30.0),
}

-- Первый выход из пещеры: камера уходит от Уступа вперёд и вверх над долиной
-- (пары eye/look — координаты сборки, мировые даёт HubLayout.world).
HubLayout.Reveal = {
	To = { eye = Vector3.new(0, 140, 172), look = Vector3.new(20, 0, -60) },
	Duration = 1.5,
	Hold = 1.0,
	Back = 1.2,
}

-- Невидимые заплатки пола (координаты сборки). Найдены прогоном
-- tools/lua/test_hub_walk.lua: дыры и уступы на пути игрока.
--   { center, size } — плита; { from, to, width } — пандус (верх от from к to).
HubLayout.FloorPatches = {
	-- Пещера: щель 2 стада между площадкой над лестницей и платформой к мосту.
	{ center = Vector3.new(1, 19.5, 340.5), size = Vector3.new(2.4, 1, 8) },
	-- Пещера: уступ 2 стада из грота пруда к лестнице «к свету», без ступени.
	{ from = Vector3.new(2.5, 22, 266.6), to = Vector3.new(2.5, 24.2, 262.5), width = 13 },
}

-- Возврат с этажа: игрок «собирается» на столько стад перед Вратами,
-- по направлению взгляда модели SealGate.
HubLayout.ReturnDistance = 12

-- путь от папки Workspace.Hub до таблички → текст (SurfaceGui ставит HubController)
HubLayout.Signs = {
	{ path = "Signs.Signpost1.SignBoardA", text = "Колокольный Брод" },
	{ path = "Signs.Signpost1.SignBoardB", text = "Перевал Печатей" },
	{ path = "Signs.Signpost1.SignBoardC", text = "Озеро" },
	{ path = "Signs.Signpost2.SignBoardA", text = "Площадь" },
	{ path = "Signs.Signpost2.SignBoardB", text = "Мельница" },
	{ path = "Signs.Signpost2.SignBoardC", text = "Гора" },
	{ path = "Signs.Signpost3.SignBoardA", text = "Перевал Печатей" },
	{ path = "Signs.Signpost3.SignBoardB", text = "Колокольный Брод" },
	{ path = "Signs.Signpost3.SignBoardC", text = "Озеро" },
	{ path = "Cave.Ledge.SignBoardA", text = "Колокольный Брод" },
	{ path = "Cave.Ledge.SignBoardB", text = "Перевал Печатей" },
	{ path = "Cave.Ledge.SignBoardC", text = "Озеро" },
	{ path = "Cave.Cave.SignChamber1", text = "Наружу" },
	{ path = "Cave.Cave.SignGrotto1", text = "Кузня" },
	{ path = "Cave.Cave.SignGrotto2", text = "Наружу" },
}

-- Профили света (ТЗ 4.2). HubController переключает их при входе в часть
-- CaveLightingZone и возвращает свет этажа, когда игрок уходит из хаба.
local H = Palette.Hub
HubLayout.Lighting = {
	Valley = {
		lighting = {
			ClockTime = 13.5,
			Brightness = 2.2,
			Ambient = H.st2:Lerp(Color3.new(0, 0, 0), 0.5), -- #8A847C × 0.5
			OutdoorAmbient = H.st1,
			-- Не из ТЗ: с Brightness 2.2 в Future светлый камень уходит в белое;
			-- минус экспозиция и насыщенность ниже возвращают цвета превью.
			ExposureCompensation = -0.35,
			ColorShift_Top = Color3.new(0, 0, 0),
			ColorShift_Bottom = Color3.new(0, 0, 0),
			EnvironmentDiffuseScale = 1,
			EnvironmentSpecularScale = 0.5,
			GeographicLatitude = 30,
		},
		atmosphere = { Density = 0.28, Haze = 1, Offset = 0.1, Color = Color3.fromHex("#CFE3F5"), Decay = H.w2, Glare = 0.2 },
		bloom = { Intensity = 0.4, Threshold = 1.2, Size = 24 },
		sunRays = { Intensity = 0.06, Spread = 0.7 },
		grade = { Brightness = 0, Contrast = 0.12, Saturation = 0.18, TintColor = Color3.new(1, 1, 1) },
		clouds = { Cover = 0.45, Density = 0.6, Color = H.sn1 },
	},
	Cave = {
		lighting = {
			ClockTime = 13.5,
			Brightness = 0.4,
			Ambient = H.cv3,
			OutdoorAmbient = H.cv3,
			ExposureCompensation = -0.3,
			ColorShift_Top = Color3.new(0, 0, 0),
			ColorShift_Bottom = Color3.new(0, 0, 0),
			EnvironmentDiffuseScale = 0.3,
			EnvironmentSpecularScale = 0.3,
			GeographicLatitude = 30,
		},
		atmosphere = { Density = 0.45, Haze = 2, Offset = 0, Color = H.cv1, Decay = H.cv3, Glare = 0 },
		bloom = { Intensity = 0.7, Threshold = 1.1, Size = 24 },
		sunRays = { Intensity = 0, Spread = 0.7 },
		grade = { Brightness = 0, Contrast = 0.1, Saturation = 0, TintColor = Color3.new(1, 1, 1) },
		clouds = { Cover = 0.45, Density = 0.6, Color = H.sn1 },
	},
	tweenTime = 1.5,
}

-- Тёплые фонари внутри пещеры (Hub.Cave.Cave): в Roblox они при яркости
-- сборки 1,4 заливают светло-серые стены бежевым, и пещера выглядит дневной.
-- Клиент приглушает их до темноты с превью (ТЗ, раздел 3: «темно, свет
-- даёт только голубая память и тёплые фонари»). Горн и память не трогаем.
HubLayout.CaveLanterns = {
	color = "ffbe6e", -- цвет фонарей сборки
	brightness = 0.5,
	range = 14,
}

return HubLayout
