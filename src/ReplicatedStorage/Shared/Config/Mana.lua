--!nonstrict
-- Mana
-- Мана мага (план: класс «Маг», Хронисты). Только числа — логика в
-- ServerScriptService/Systems/ManaService, полоса — PixelHudController.
--
-- Откуда мана:
--   класс  — Classes.mage.mana + manaPerLevel × (уровень − 1), реген manaRegen/с;
--   броня  — шляпа и накидка (Config/Armor: mana растёт с ★, manaRegen) и бонус комплекта;
--   оружие — посох: Weapons.Items[id].mana / manaRegen (появятся вместе с посохами).
-- Обычные удары посохом (снаряды) ману НЕ тратят — только способности и барьер.

local Mana = {}

-- Классы с маной (у остальных MaxMana = 0 и полоса скрыта).
Mana.Classes = { mage = true }

-- Пауза восстановления после траты, с: мана не течёт сразу после каста.
Mana.RegenDelay = 0.8
-- Вне боя (нет урона и трат RegenCalm секунд) реген ×CalmMultiplier.
Mana.RegenCalm = 4
Mana.CalmMultiplier = 2
-- В хабе мана всегда полная.
Mana.FullInHub = true

-- Шаг обновления, с.
Mana.Tick = 0.1

-- Цены (используют способности мага; здесь — чтобы баланс жил в одном месте).
Mana.Costs = {
	barrier = 10, -- барьер (парирование мага)
	barrierRefund = 15, -- удачный барьер возвращает
	invisibility = 25,
	weaponAbility = 30, -- способность посоха (Q), эпик и выше
}

-- Масштаб способностей: +1% за каждые 10 макс. маны (план, раздел мага).
function Mana.abilityScale(maxMana: number): number
	return 1 + math.floor((maxMana or 0) / 10) * 0.01
end

return Mana
