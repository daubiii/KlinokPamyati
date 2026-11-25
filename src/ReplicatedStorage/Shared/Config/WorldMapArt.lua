--!nonstrict
-- WorldMapArt
-- Картинка острова для Врат Печатей: assets/worldmap/worldmap_atlas.png
-- (1024×488, собирает tools/worldmap/build_map.py; куски — Config.WorldMapAtlas).
-- Загрузить PNG через Asset Manager и вписать сюда rbxassetid://…
-- Пока id пустой, окно рисует остров заглушкой из полос сетки
-- (WorldMapAtlas.Fallback): та же форма этажей, только без деталей.
--
-- Всё нарисовано в родных пикселях и показывается ×3 (ResampleMode Pixelated).

local WorldMapArt = {}

WorldMapArt.Atlas = "rbxassetid://116706452008347"

function WorldMapArt.has(): boolean
	local id = WorldMapArt.Atlas
	return typeof(id) == "string" and id ~= "" and not id:match("://0$")
end

return WorldMapArt
