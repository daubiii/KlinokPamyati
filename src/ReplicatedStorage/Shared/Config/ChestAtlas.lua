--!nonstrict
-- ChestAtlas (сгенерировано tools/chests/build_chest_art.py — не править руками)
-- Куски assets/chests/chest_atlas.png в родных пикселях; игра показывает ×2 (Pixelated).
--   <id>_icon 32×32 — сумка, лента «Получен сундук», HUD;
--   <id>_art / <id>_open 112×96 — карточка в сумке (закрыт / открыт).
local ChestAtlas = {}
ChestAtlas.Size = { w = 572, h = 430 }
ChestAtlas.Pieces = {
	f1_common_art = { x = 2, y = 36, w = 112, h = 96 },
	f1_common_icon = { x = 2, y = 2, w = 32, h = 32 },
	f1_common_open = { x = 2, y = 232, w = 112, h = 96 },
	f1_gold_art = { x = 116, y = 36, w = 112, h = 96 },
	f1_gold_icon = { x = 36, y = 2, w = 32, h = 32 },
	f1_gold_open = { x = 116, y = 232, w = 112, h = 96 },
	f2_common_art = { x = 230, y = 36, w = 112, h = 96 },
	f2_common_icon = { x = 70, y = 2, w = 32, h = 32 },
	f2_common_open = { x = 230, y = 232, w = 112, h = 96 },
	f2_gold_art = { x = 344, y = 36, w = 112, h = 96 },
	f2_gold_icon = { x = 104, y = 2, w = 32, h = 32 },
	f2_gold_open = { x = 344, y = 232, w = 112, h = 96 },
	f3_common_art = { x = 458, y = 36, w = 112, h = 96 },
	f3_common_icon = { x = 138, y = 2, w = 32, h = 32 },
	f3_common_open = { x = 458, y = 232, w = 112, h = 96 },
	f3_gold_art = { x = 2, y = 134, w = 112, h = 96 },
	f3_gold_icon = { x = 172, y = 2, w = 32, h = 32 },
	f3_gold_open = { x = 2, y = 330, w = 112, h = 96 },
	f4_common_art = { x = 116, y = 134, w = 112, h = 96 },
	f4_common_icon = { x = 206, y = 2, w = 32, h = 32 },
	f4_common_open = { x = 116, y = 330, w = 112, h = 96 },
	f4_gold_art = { x = 230, y = 134, w = 112, h = 96 },
	f4_gold_icon = { x = 240, y = 2, w = 32, h = 32 },
	f4_gold_open = { x = 230, y = 330, w = 112, h = 96 },
	f5_common_art = { x = 344, y = 134, w = 112, h = 96 },
	f5_common_icon = { x = 274, y = 2, w = 32, h = 32 },
	f5_common_open = { x = 344, y = 330, w = 112, h = 96 },
	f5_gold_art = { x = 458, y = 134, w = 112, h = 96 },
	f5_gold_icon = { x = 308, y = 2, w = 32, h = 32 },
	f5_gold_open = { x = 458, y = 330, w = 112, h = 96 },
}
return ChestAtlas
