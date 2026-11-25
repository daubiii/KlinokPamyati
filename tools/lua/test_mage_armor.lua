--!nonstrict
-- test_mage_armor.lua — броня и мана мага (Config/Armor, MageArmorMeshData, Mana, Classes):
-- комплекты мага носит только маг, сундук не смешивает классы, у каждого комплекта
-- есть меши шляпы, накидки и плаща, мана растёт по уровню и от брони.
--   LUAU=путь/к/luau node tools/run-luau.js tools/lua/test_mage_armor.lua

local Shared = (_G :: any).KlinokShared or game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Armor = require(Shared.Config.Armor)
local Classes = require(Shared.Config.Classes)
local Mana = require(Shared.Config.Mana)
local MeshData = require(Shared.Config.MageArmorMeshData)
local HeroData = require(Shared.Config.HeroArmorMeshData)
local FloorsData = require(Shared.Config.ArmorFloorsMeshData)

local out = {}
local failures = 0
local function check(label, ok, detail)
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %s%s"):format(ok and "OK  " or "FAIL", label, detail and (" — " .. tostring(detail)) or "")
end

local mageSets = Armor.SetOrderByClass.mage
check("у мага 21 комплект (5 этажа 1 + 16 этажей 2–5)", #mageSets == 21, #mageSets)
local rarities = {}
for _, setId in ipairs(mageSets) do
	local set = Armor.Sets[setId]
	check(setId .. ": есть в Armor.Sets и class = mage", set ~= nil and set.class == "mage")
	if set then
		rarities[set.rarity] = (rarities[set.rarity] or 0) + 1
		check(setId .. ": стиль мага для запасного облика", Armor.Styles[setId] ~= nil and Armor.Styles[setId].mage == true)
			-- Комплект — один предмет; старые id «_helm/_armor» читаются как набор.
			local t = Armor.template(setId)
			check(setId .. ": шаблон комплекта с маной", t ~= nil and (t.mana or 0) > 0 and t.class == "mage" and Armor.template(setId .. "_helm").id == setId, t and t.mana)
		local mesh = MeshData.sets[setId] or FloorsData.sets[setId]
		check(setId .. ": меши шляпы/накидки/плаща", mesh ~= nil and #mesh.helm > 0 and #mesh.armor > 0 and #mesh.cape > 0)
		check(setId .. ": редкость совпадает с мешами", mesh ~= nil and mesh.rarity == set.rarity)
		check(setId .. ": не пересекается с воином", HeroData.sets[setId] == nil)
	end
end
check("редкости: этаж 1 — 2 обычных, далее по одному каждой на этаж",
	rarities.common == 6 and rarities.rare == 5 and rarities.epic == 5 and rarities.legendary == 5)

check("маг носит своё", Armor.canWear("mage", "chronicler") and Armor.canWear("mage"))
check("маг не носит латы", not Armor.canWear("mage", "gatekeeper"))
check("воин не носит шляпы", not Armor.canWear("warrior", "archivist") and Armor.canWear("warrior", "gatekeeper"))
check("ассасин без брони", not Armor.canWear("assassin"))
check("стартовые: странник и послушник", Armor.starterFor("warrior") == "wanderer" and Armor.starterFor("mage") == "novice")
check("слоты мага: шляпа и накидка", Armor.slotName("helm", "mage") == "Шляпа" and Armor.slotName("armor", "mage") == "Накидка")
check("слоты воина: шлем и доспех", Armor.slotName("helm", "warrior") == "Шлем" and Armor.slotName("armor") == "Доспех")

local function poolClasses(className)
	local seen = {}
	for _, r in ipairs({ "common", "rare", "epic", "legendary" }) do
		for _, pick in ipairs(Armor.pool(r, 1, className)) do
			seen[Armor.classOf(pick[1])] = true
			if pick[1] == Armor.starterFor(className) then
				seen.starter = true
			end
		end
	end
	return seen
end
local mp, wp = poolClasses("mage"), poolClasses("warrior")
check("сундук мага — только маг", mp.mage and not mp.warrior and not mp.starter)
check("сундук воина — только воин", wp.warrior and not wp.mage and not wp.starter)
check("старый вызов pool без класса — воин", #Armor.pool("rare", 1) == 1 and Armor.pool("rare", 1)[1][1] == "gate_guard")

local s1, s30 = Classes.statsAtLevel("mage", 1), Classes.statsAtLevel("mage", 30)
check("мана мага 100 на 1 ур.", s1.maxMana == 100, s1.maxMana)
check("мана мага растёт +8/ур.", s30.maxMana == 100 + 8 * 29, s30.maxMana)
check("у воина маны нет", Classes.statsAtLevel("warrior", 5).maxMana == nil)
check("масштаб способностей +1% за 10 маны", math.abs(Mana.abilityScale(160) - 1.16) < 1e-9, Mana.abilityScale(160))

check("легенда этажа 1 даёт +60 маны", Armor.template("archivist").mana == 60, Armor.template("archivist").mana)

out[#out + 1] = ("ИТОГО: %d проверок, %d провалов"):format(#out, failures)
return table.concat(out, "\n")
