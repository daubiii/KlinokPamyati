--!nonstrict
-- Rarities
-- Редкости и связанные с ними числа. Раздел 8 и приложение Б плана.
-- Редкость даёт способность и стиль, а не голые цифры: разница в уроне
-- между обычным и секретным всего +25%.

local Palette = require(script.Parent.Palette)

local Rarities = {}

-- Порядок важен: используется для сортировки и для «>= эпическая».
Rarities.order = {
	"common",
	"rare",
	"epic",
	"legendary",
	"mythic",
	"secret",
}

Rarities.data = {
	common = {
		id = "common",
		index = 1,
		name = "Обычное",
		color = Color3.fromHex("#9AA0A6"),
		damageMultiplier = 1.00,
		hasWeaponAbility = false,
	},
	rare = {
		id = "rare",
		index = 2,
		name = "Редкое",
		color = Color3.fromHex("#4CAF50"),
		damageMultiplier = 1.06,
		hasWeaponAbility = false,
	},
	epic = {
		id = "epic",
		index = 3,
		name = "Эпическое",
		color = Color3.fromHex("#9C5BE0"),
		damageMultiplier = 1.12,
		hasWeaponAbility = true,
	},
	legendary = {
		id = "legendary",
		index = 4,
		name = "Легендарное",
		color = Color3.fromHex("#F5A524"),
		damageMultiplier = 1.18,
		hasWeaponAbility = true,
	},
	mythic = {
		id = "mythic",
		index = 5,
		name = "Мифическое",
		color = Color3.fromHex("#E5484D"),
		damageMultiplier = 1.22,
		hasWeaponAbility = true,
	},
	secret = {
		id = "secret",
		index = 6,
		name = "Секретное",
		color = Palette.Memory,
		damageMultiplier = 1.25,
		hasWeaponAbility = true,
	},
}

function Rarities.get(id: string)
	return Rarities.data[id]
end

function Rarities.atLeast(id: string, threshold: string): boolean
	local a = Rarities.data[id]
	local b = Rarities.data[threshold]
	if not a or not b then
		return false
	end
	return a.index >= b.index
end

function Rarities.color(id: string): Color3
	local rarity = Rarities.data[id]
	return rarity and rarity.color or Palette.UI.textMuted
end

return Rarities
