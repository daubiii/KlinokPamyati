--!nonstrict
-- AbilityIconsMage
-- Иконки 19 заклинаний посохов (08.11.2026).
-- Атлас: tools/icons/mage_spells_atlas.png (112x90, клетки 20x20, сгенерирован tools/icons/icons_mage.py).
-- Загрузите PNG в Roblox (как картинки интерфейса) и впишите id в atlas. Пока atlas пустой — PixelUi
-- рисует прежнюю иконку из основного атласа (fallback), ничего не ломается.

return {
	atlas = "rbxassetid://111935821969642", -- mage_spells_atlas.png
	rects = {
		mage_ward = { x = 2, y = 2, w = 20, h = 20 },
		mage_signal = { x = 24, y = 2, w = 20, h = 20 },
		mage_gate = { x = 46, y = 2, w = 20, h = 20 },
		mage_lotus = { x = 68, y = 2, w = 20, h = 20 },
		mage_spore = { x = 90, y = 2, w = 20, h = 20 },
		mage_thorn = { x = 2, y = 24, w = 20, h = 20 },
		mage_pack = { x = 24, y = 24, w = 20, h = 20 },
		mage_moon = { x = 46, y = 24, w = 20, h = 20 },
		mage_net = { x = 68, y = 24, w = 20, h = 20 },
		mage_firerain = { x = 90, y = 24, w = 20, h = 20 },
		mage_lightning = { x = 2, y = 46, w = 20, h = 20 },
		mage_heart = { x = 24, y = 46, w = 20, h = 20 },
		mage_meteor = { x = 46, y = 46, w = 20, h = 20 },
		mage_firstcast = { x = 68, y = 46, w = 20, h = 20 },
		mage_tome = { x = 90, y = 46, w = 20, h = 20 },
		mage_clock = { x = 2, y = 68, w = 20, h = 20 },
		mage_fate = { x = 24, y = 68, w = 20, h = 20 },
		mage_inkhole = { x = 46, y = 68, w = 20, h = 20 },
		mage_recall = { x = 68, y = 68, w = 20, h = 20 },
	},
	fallback = {
		mage_ward = "barrier",
		mage_signal = "candle",
		mage_gate = "key",
		mage_lotus = "flask",
		mage_spore = "dust",
		mage_thorn = "split",
		mage_pack = "soul",
		mage_moon = "star",
		mage_net = "trophy",
		mage_firerain = "dust",
		mage_lightning = "hammer",
		mage_heart = "split",
		mage_meteor = "ingot",
		mage_firstcast = "star",
		mage_tome = "scroll",
		mage_clock = "ring",
		mage_fate = "quest",
		mage_inkhole = "whirl",
		mage_recall = "soul",
	},
}
