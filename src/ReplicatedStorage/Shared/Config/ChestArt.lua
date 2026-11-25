--!nonstrict
-- ChestArt
-- Картинки сундуков для интерфейса (assets/chests/chest_atlas.png, собран
-- tools/chests/build_chest_art.py). Загрузить PNG через Asset Manager и вписать
-- сюда rbxassetid. Пока id пустой, сумка и лента «Получен сундук» показывают
-- живую 3D-модель сундука во ViewportFrame (Lib/ChestVisual) — тоже красиво,
-- просто дороже: картинка нужна для телефонов.
--
--   Atlas   chest_atlas.png   572×430   <id>_icon 32×32, <id>_art / <id>_open 112×96
--
-- Всё нарисовано в родных пикселях и показывается ×2 (ResampleMode Pixelated).

local ChestArt = {}

ChestArt.Atlas = "rbxassetid://73385458916915"
ChestArt.Scale = 2

function ChestArt.has(): boolean
	local id = ChestArt.Atlas
	return typeof(id) == "string" and id ~= "" and not id:match("://0$")
end

return ChestArt
