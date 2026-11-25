--!nonstrict
-- AbilityIcons345
-- Иконки способностей оружия этажей 3–5 (Охота, Горн, Летопись).
-- Атлас: assets/abilities345_atlas.png (90x90, клетки 20x20, сгенерирован tools/icons/icons345.py).
-- Загрузите PNG в Roblox и впишите id в atlas. Пока atlas пустой — PixelUi
-- рисует запасную иконку из основного атласа (fallback).

return {
	atlas = "rbxassetid://122076395053918", -- abilities345_atlas.png
	rects = {
		hunt_pack = { x = 2, y = 2, w = 20, h = 20 },
		hunt_snare = { x = 24, y = 2, w = 20, h = 20 },
		hunt_spear = { x = 46, y = 2, w = 20, h = 20 },
		hunt_dive = { x = 68, y = 2, w = 20, h = 20 },
		forge_spill = { x = 2, y = 24, w = 20, h = 20 },
		forge_overheat = { x = 24, y = 24, w = 20, h = 20 },
		forge_anvil = { x = 46, y = 24, w = 20, h = 20 },
		forge_breath = { x = 68, y = 24, w = 20, h = 20 },
		forge_scythe = { x = 2, y = 46, w = 20, h = 20 },
		forge_pour = { x = 24, y = 46, w = 20, h = 20 },
		chron_line = { x = 46, y = 46, w = 20, h = 20 },
		chron_seal = { x = 68, y = 46, w = 20, h = 20 },
		chron_hourglass = { x = 2, y = 68, w = 20, h = 20 },
		chron_ink = { x = 24, y = 68, w = 20, h = 20 },
		chron_erase = { x = 46, y = 68, w = 20, h = 20 },
		chron_memory = { x = 68, y = 68, w = 20, h = 20 },
	},
	fallback = {
		hunt_pack = "split",
		hunt_snare = "split",
		hunt_spear = "dagger",
		hunt_dive = "split",
		forge_spill = "whirl",
		forge_overheat = "whirl",
		forge_anvil = "hammer",
		forge_breath = "whirl",
		forge_scythe = "whirl",
		forge_pour = "ingot",
		chron_line = "scroll",
		chron_seal = "lock",
		chron_hourglass = "candle",
		chron_ink = "key",
		chron_erase = "key",
		chron_memory = "soul",
	},
}
