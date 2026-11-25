--!nonstrict
-- Binds
-- Раскладка управления по умолчанию. Всё, что читает клавиши, берёт их
-- отсюда: будущий экран переназначения (раздел 20 плана) будет менять только
-- эту таблицу, а не контроллеры.
--
-- Сейчас значения статические. Когда появится экран настроек, он станет
-- писать переопределения в профиль игрока, а Binds.get — сначала смотреть
-- в профиль, потом в defaults.

local Binds = {}

Binds.defaults = {
	Attack = Enum.UserInputType.MouseButton1,
	Parry = Enum.UserInputType.MouseButton2,
	Dash = Enum.KeyCode.Q,
	Heal = Enum.KeyCode.F,
	Interact = Enum.KeyCode.E,

	-- Способности: оружие и души. Раскладка цифрами — решение владельца
	-- проекта; конкретные слоты разведём, когда появятся сами способности
	-- (этап 7), чтобы не занимать клавиши впустую.
	Inventory = Enum.KeyCode.I,
	-- Книга героя: вкладки «Герой» и «Журнал»; быстрый предмет из сумки.
	Hero = Enum.KeyCode.C,
	Journal = Enum.KeyCode.J,
	-- Древо талантов — вкладка книги героя (приложение В).
	Talents = Enum.KeyCode.T,
	UseItem = Enum.KeyCode.G,
	Ability1 = Enum.KeyCode.One,
	Ability2 = Enum.KeyCode.Two,
	Ability3 = Enum.KeyCode.Three,
	Ability4 = Enum.KeyCode.Four,
	-- Свободный курсор ↔ боевой режим (камера за мышью). Переключатель:
	-- нажал — курсор виден (задания, кнопки HUD), нажал ещё раз — снова бой.
	Cursor = Enum.KeyCode.LeftAlt,
}

-- Дополнительные клавиши к основной. Пробел — прыжок (решение владельца,
-- 21.10.2026), поэтому рывок только Q и Shift.
Binds.extra = {
	Dash = { Enum.KeyCode.LeftShift },
	Inventory = { Enum.KeyCode.Tab },
	-- Ctrl — как привычный в Roblox «Shift Lock» (Shift у нас занят рывком).
	Cursor = { Enum.KeyCode.LeftControl, Enum.KeyCode.RightAlt },
}

-- Все входы действия одним списком: основной + дополнительные.
function Binds.all(action: string)
	local list = {}
	local main = Binds.defaults[action]
	if main then
		table.insert(list, main)
	end
	for _, extra in ipairs(Binds.extra[action] or {}) do
		table.insert(list, extra)
	end
	return list
end

function Binds.get(action: string)
	local binding = Binds.defaults[action]
	if not binding then
		warn("Binds: неизвестное действие '" .. tostring(action) .. "'")
	end
	return binding
end

function Binds.isKeyCode(action: string): boolean
	return typeof(Binds.get(action)) == "EnumItem"
		and Binds.get(action).EnumType == Enum.KeyCode
end

return Binds
