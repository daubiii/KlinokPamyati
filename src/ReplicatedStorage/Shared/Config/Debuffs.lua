--!nonstrict
-- Debuffs
-- Аффиксы врагов и дебафы на игроке (решение владельца, 15.11.2026).
-- Три вида: мороз (замедление), огонь (урон), яд (долго + лёгкое замедление).
--
-- Как работает:
--   * Враг при спавне с шансом (зависит от этажа и ПРОДОЛЖИТЕЛЬНОСТИ забега —
--     чем дольше идёт этаж, тем чаще) становится носителем аффикса:
--     иконка над моделью + лёгкое цветное свечение.
--   * Если носитель атакует игрока и урон прошёл (не парирование/уворот) —
--     игрок получает дебаф: небольшой урон тиками, замедление, цветной
--     тон экрана, частицы на персонаже, иконка с таймером у полосы HP.
--   * Урон НАМЕРЕННО маленький (главный дискомфорт — замедление и толпа).
--   * Снимается: по времени, при смерти, при возврате в долину.

local Debuffs = {}

-- Иконки (залиты в Creator Hub, 64×64): снежинка / уголёк / капля яда.
Debuffs.Atlas = {
	frost = "rbxassetid://74688127771844",
	burn = "rbxassetid://95475424266011",
	poison = "rbxassetid://98733426162570",
}

Debuffs.Kinds = {
	frost = {
		name = "Мороз",
		duration = 6,
		dps = 1, -- урон в секунду: мороз почти не жжёт, он МЕДЛИТ
		slow = 0.62, -- множитель скорости бега
		color = Color3.fromRGB(150, 215, 255),
		screen = Color3.fromRGB(110, 170, 255),
		screenTransparency = 0.82,
	},
	burn = {
		name = "Огонь",
		duration = 5,
		dps = 4, -- самый больной урон, но короткий
		slow = 0.9,
		color = Color3.fromRGB(255, 150, 60),
		screen = Color3.fromRGB(255, 120, 40),
		screenTransparency = 0.86,
	},
	poison = {
		name = "Яд",
		duration = 9, -- самый долгий: дискомфорт тянется
		dps = 2.5,
		slow = 0.85,
		color = Color3.fromRGB(140, 220, 90),
		screen = Color3.fromRGB(110, 200, 80),
		screenTransparency = 0.84,
	},
}

Debuffs.order = { "frost", "burn", "poison" }

-- Шанс аффикса у обычного врага при спавне: base + минуты забега × perMinute,
-- потолок cap. Растёт и с глубиной этажа, и с временем — «чем дольше, тем злее».
Debuffs.floors = {
	[1] = { base = 0.05, perMinute = 0.04, cap = 0.15 },
	[2] = { base = 0.08, perMinute = 0.05, cap = 0.20 },
	[3] = { base = 0.10, perMinute = 0.06, cap = 0.25 },
	[4] = { base = 0.12, perMinute = 0.07, cap = 0.30 },
	[5] = { base = 0.14, perMinute = 0.08, cap = 0.35 },
}

function Debuffs.chanceFor(floorId: number, runSeconds: number): number
	local cfg = Debuffs.floors[floorId]
	if not cfg then
		return 0
	end
	local minutes = runSeconds / 60
	return math.min(cfg.cap, cfg.base + cfg.perMinute * minutes)
end

return Debuffs
