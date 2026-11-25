--!nonstrict
-- test_mage_weapons.lua — посохи мага (Config/LootMage, Loot, Weapons, SfxMage, WeaponMeshDataMage):
-- 37 посохов на этажах 1–5, у каждого есть числа удара (стиль, паттерны серии, дебаф),
-- шаблон класса mage, заклинание/пассивка у эпиков и легендарок, меш; сундук мага даёт
-- только посохи, сундук воина — ни одного посоха; звуки попаданий покрывают все стили.
--   LUAU=путь/к/luau node tools/run-luau.js tools/lua/test_mage_weapons.lua

local Shared = (_G :: any).KlinokShared or game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local LootMage = require(Shared.Config.LootMage)
local Loot = require(Shared.Config.Loot)
local Weapons = require(Shared.Config.Weapons)
local SfxMage = require(Shared.Config.SfxMage)
local meshModule = Shared.Config:FindFirstChild("WeaponMeshDataMage")
local MeshData = meshModule and require(meshModule) or nil

local out = {}
local failures = 0
local checks = 0
local function check(label, ok, detail)
	checks += 1
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %s%s"):format(ok and "OK  " or "FAIL", label, detail and (" — " .. tostring(detail)) or "")
end

-- Детерминированный генератор вместо Random (раннер без движка).
local function makeRng(seed)
	local state = seed
	local rng = {}
	function rng:NextNumber()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	function rng:NextInteger(a, b)
		return a + math.floor(self:NextNumber() * (b - a + 1))
	end
	return rng
end

-- ===== Список посохов =====
local weapons = LootMage.Weapons
check("37 посохов", #weapons == 37, #weapons)
local byFloor, seen, dupes = {}, {}, {}
for _, w in ipairs(weapons) do
	byFloor[w.floor] = (byFloor[w.floor] or 0) + 1
	if seen[w.id] then
		table.insert(dupes, w.id)
	end
	seen[w.id] = true
end
check("id без повторов", #dupes == 0, table.concat(dupes, ","))
local floorsLine = {}
for floor = 1, 5 do
	check(("этаж %d: есть посохи"):format(floor), (byFloor[floor] or 0) >= 7, byFloor[floor])
	floorsLine[#floorsLine + 1] = tostring(byFloor[floor] or 0)
end
out[#out + 1] = "  по этажам: " .. table.concat(floorsLine, " / ")
check("стартовый посох — apprentice_staff", LootMage.StarterWeapon == "apprentice_staff" and Loot.StarterWeapons.mage == "apprentice_staff")

local usedStyles, usedPatterns, usedAbilities, usedPassives = {}, {}, {}, {}
for _, w in ipairs(weapons) do
	local id = w.id
	local item = LootMage.Items[id]
	local problems = {}
	if not item then
		table.insert(problems, "нет LootMage.Items")
	else
		local bolt = item.bolt
		if not bolt or not LootMage.Styles[bolt.style] then
			table.insert(problems, "стиль " .. tostring(bolt and bolt.style))
		else
			usedStyles[bolt.style] = true
		end
		if bolt and bolt.debuff and not LootMage.Debuffs[bolt.debuff[1]] then
			table.insert(problems, "дебаф " .. tostring(bolt.debuff[1]))
		end
		if bolt and bolt.debuff and not (bolt.debuff[2] > 0 and bolt.debuff[2] <= 1) then
			table.insert(problems, "шанс дебафа " .. tostring(bolt.debuff[2]))
		end
		if bolt and not ((bolt.speed or 0) > 20 and (bolt.size or 0) > 0) then
			table.insert(problems, "скорость/размер снаряда")
		end
		if type(item.combo) ~= "table" or #item.combo ~= 3 then
			table.insert(problems, "серия не из 3 ударов")
		else
			for _, patternId in ipairs(item.combo) do
				if not LootMage.Patterns[patternId] then
					table.insert(problems, "паттерн " .. tostring(patternId))
				end
				usedPatterns[patternId] = true
			end
		end
		if not (item.damage > 0.5 and item.damage < 2) then
			table.insert(problems, "урон " .. tostring(item.damage))
		end
	end
	local stats = Weapons.Items[id]
	if not stats or not stats.bolt then
		table.insert(problems, "нет Weapons.Items с bolt")
	end
	local t = Loot.template(id)
	if not t or t.class ~= "mage" or t.typeId ~= "staff" then
		table.insert(problems, "шаблон класса")
	end
	if Loot.weaponClass({ id = id, typeId = "staff" }) ~= "mage" then
		table.insert(problems, "weaponClass")
	end
	local needsAbility = w.rarity == "epic" or w.rarity == "legendary" or w.rarity == "secret"
	local needsPassive = w.rarity == "legendary" or w.rarity == "secret"
	if needsAbility and not (w.ability and LootMage.Abilities[w.ability]) then
		table.insert(problems, "заклинание " .. tostring(w.ability))
	end
	if needsPassive and not (w.passive and LootMage.Passives[w.passive]) then
		table.insert(problems, "пассивка " .. tostring(w.passive))
	end
	if w.ability then
		usedAbilities[w.ability] = (usedAbilities[w.ability] or 0) + 1
		local ability = Loot.abilityOf({ id = id })
		if not ability or ability.id ~= w.ability then
			table.insert(problems, "Loot.abilityOf")
		end
	end
	if w.passive then
		usedPassives[w.passive] = (usedPassives[w.passive] or 0) + 1
	end
	if needsPassive and not (w.damageBonus and w.cooldownReduction) then
		table.insert(problems, "бонус редкости")
	end
	if MeshData then
		local mesh = MeshData[id]
		if not mesh or type(mesh.objects) ~= "table" or #mesh.objects == 0 then
			table.insert(problems, "нет меша")
		elseif not (mesh.bladeTip and mesh.bladeBase) then
			table.insert(problems, "нет bladeTip/bladeBase")
		elseif mesh.rarity ~= w.rarity then
			table.insert(problems, "редкость меша " .. tostring(mesh.rarity))
		elseif not mesh.focus or mesh.focus.Y < mesh.bottom or mesh.focus.Y > mesh.bladeTip + 0.5 then
			table.insert(problems, "focus навершия вне посоха")
		end
	end
	check(("%s (%s, эт.%d)"):format(id, w.rarity, w.floor), #problems == 0, table.concat(problems, "; "))
end

-- ===== Заклинания и пассивки =====
local abilityCount, passiveCount = 0, 0
for abilityId, ability in pairs(LootMage.Abilities) do
	abilityCount += 1
	local ok = ability.id == abilityId and (ability.mana or 0) > 0 and (ability.cooldown or 0) > 0
		and (ability.castTime or 0) > 0 and (ability.damageMultiplier or 0) > 0 and Loot.Abilities[abilityId] == ability
	check("заклинание " .. abilityId .. ": мана/перезарядка/каст", ok,
		("mana=%s cd=%s cast=%s"):format(tostring(ability.mana), tostring(ability.cooldown), tostring(ability.castTime)))
	check("заклинание " .. abilityId .. ": висит на посохе", usedAbilities[abilityId] == 1, usedAbilities[abilityId])
end
check("19 заклинаний", abilityCount == 19, abilityCount)
for passiveId, passive in pairs(LootMage.Passives) do
	passiveCount += 1
	check("пассивка " .. passiveId .. ": есть в Loot и на посохе",
		passive.id == passiveId and Loot.Passives[passiveId] == passive and usedPassives[passiveId] == 1, usedPassives[passiveId])
end
check("9 пассивок", passiveCount == 9, passiveCount)

-- ===== Паттерны и стили =====
for patternId, p in pairs(LootMage.Patterns) do
	check("паттерн " .. patternId .. ": доля урона", (p.share or 0) > 0 and p.share <= 1.5, p.share)
end
local unusedStyles = {}
for styleId, style in pairs(LootMage.Styles) do
	check("стиль " .. styleId .. ": форма и цвета", style.shape ~= nil and style.core ~= nil and style.glow ~= nil and style.trail ~= nil)
	local sound = SfxMage.HitByStyle[styleId]
	check("стиль " .. styleId .. ": звук попадания", sound ~= nil and SfxMage.sounds[sound] ~= nil, sound)
	if not usedStyles[styleId] then
		table.insert(unusedStyles, styleId)
	end
end
out[#out + 1] = "  стили без посоха (для заклинаний/пассивок): " .. (#unusedStyles > 0 and table.concat(unusedStyles, ", ") or "нет")
for _, name in ipairs({ "mageCast1", "mageCast2", "mageCast3" }) do
	check("кандидаты звука " .. name, SfxMage.candidates[name] ~= nil and SfxMage.candidates[name][SfxMage.picked[name] or 1] ~= nil)
end
check("тип staff в Weapons.Types", Weapons.Types.staff ~= nil)
check("StrikeAt на 3 удара", #LootMage.StrikeAt == 3)
check("покров: цена/длительность/перезарядка", LootMage.Veil.cost > 0 and LootMage.Veil.duration > 0 and LootMage.Veil.cooldown > LootMage.Veil.duration)
check("барьер: цена < возврата", LootMage.Barrier.cost < LootMage.Barrier.refund)

-- ===== Сундуки =====
local starter = Loot.newWeapon(LootMage.StarterWeapon, "starter")
check("newWeapon стартового посоха", starter ~= nil and starter.typeId == "staff" and starter.rarityId == "common" and starter.source == "starter")
for floor = 1, 5 do
	local rng = makeRng(1000 + floor)
	local mageOnlyStaff, warriorNoStaff, mageFloorOk = true, true, true
	local rarityHits = {}
	for i = 1, 400 do
		local mageChest = Loot.rollChest(10 + i, rng, floor, "mage")
		local mw = mageChest.weapon
		if mw.typeId ~= "staff" or Loot.weaponClass(mw) ~= "mage" then
			mageOnlyStaff = false
		end
		local t = Loot.template(mw.id)
		if not t or t.floor ~= floor then
			mageFloorOk = false
		end
		rarityHits[mw.rarityId] = (rarityHits[mw.rarityId] or 0) + 1
		local warriorChest = Loot.rollChest(10 + i, rng, floor, "warrior")
		if warriorChest.weapon.typeId == "staff" or Loot.weaponClass(warriorChest.weapon) ~= "warrior" then
			warriorNoStaff = false
		end
	end
	check(("этаж %d: сундук мага — только посохи этого этажа"):format(floor), mageOnlyStaff and mageFloorOk)
	check(("этаж %d: сундук воина — без посохов"):format(floor), warriorNoStaff)
	check(("этаж %d: выпадают обычные и редкие посохи"):format(floor), (rarityHits.common or 0) > 0 and (rarityHits.rare or 0) > 0,
		("common=%d rare=%d epic=%d legendary=%d secret=%d"):format(rarityHits.common or 0, rarityHits.rare or 0,
			rarityHits.epic or 0, rarityHits.legendary or 0, rarityHits.secret or 0))
end
local first = Loot.rollChest(0, makeRng(7), 1, "mage").weapon
check("первые сундуки мага — обычный посох", first.rarityId == "common" and first.typeId == "staff", first.id)
local oldCall = Loot.rollChest(10, makeRng(9), 1).weapon
check("старый вызов rollChest без класса — оружие воина", oldCall.typeId ~= "staff", oldCall.typeId)

-- ===== Меши =====
if MeshData then
	local extra = {}
	for id in pairs(MeshData) do
		if type(MeshData[id]) == "table" and MeshData[id].objects and not seen[id] then
			table.insert(extra, id)
		end
	end
	check("меши посохов без лишних id", #extra == 0, table.concat(extra, ","))
else
	check("Config.WeaponMeshDataMage есть", false, "модуль не найден")
end

return ("test_mage_weapons\n%s\nИТОГО: %d проверок, %d провалов"):format(table.concat(out, "\n"), checks, failures)
