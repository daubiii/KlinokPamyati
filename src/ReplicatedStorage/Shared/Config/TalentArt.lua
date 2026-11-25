--!nonstrict
-- TalentArt
-- Картинки древа талантов v2 (assets/talents, собраны tools/talents/build_talent_art.py).
-- Загрузить четыре PNG через Asset Manager (Bulk Import) и вписать сюда rbxassetid —
-- как PaperAtlas в UiAssets, только отдельным файлом (UiAssets не трогаем).
-- Пока id пустой, вкладка «Древо» рисует заглушки (тёмный лист, кружки UICorner/UIStroke, буквы).
--
--   Atlas       talent_atlas.png        256×128  иконки, глифы малых узлов, рамки (оттенки серого)
--   BgWarrior   talent_bg_warrior.png   560×374  фон древа воина: печать со шлемом
--   BgMage      talent_bg_mage.png      560×374  фон древа мага: печать со шляпой колдуна
--   BgAssassin  talent_bg_assassin.png  560×374  фон древа ассасина (на будущее): печать с клинком
--
-- Всё нарисовано в родных пикселях и показывается ×2 (Pixelated): фон 560×374 → 1120×748.

local TalentArt = {}

TalentArt.Atlas = "rbxassetid://108258774224049"
TalentArt.BgWarrior = "rbxassetid://134354485933824"
TalentArt.BgMage = "rbxassetid://128284221473649"
TalentArt.BgAssassin = "rbxassetid://120498531444703"

TalentArt.Scale = 2
TalentArt.BgSize = { w = 560, h = 374 }

-- Talents.Classes[класс].background → поле с id.
TalentArt.Backgrounds = { bg_warrior = "BgWarrior", bg_mage = "BgMage", bg_assassin = "BgAssassin" }

function TalentArt.has(id): boolean
	return typeof(id) == "string" and id ~= "" and not id:match("://0$")
end

function TalentArt.background(name: string?): string?
	local field = name and TalentArt.Backgrounds[name]
	local id = field and TalentArt[field]
	return TalentArt.has(id) and id or nil
end

return TalentArt
