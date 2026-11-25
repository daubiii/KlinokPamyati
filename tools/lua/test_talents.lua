-- Проверка древа талантов v2 (Config/Talents, TalentAtlas, TalentArt, Classes).
--   LUAU=… node tools/run-luau.js tools/lua/test_talents.lua
-- Игрок видит одно древо своего класса: три пути по 22 узла (14 малых × 1 очко,
-- 5 узлов × 1 очко, 3 ключевых × 5 очков) — путь 34, древо 102. Очко за каждый
-- уровень после первого, потолок 60 → 59 очков; статы растут только до 30-го.
local Shared = (_G :: any).KlinokShared
local Talents = require(Shared.Config.Talents)
local TalentAtlas = require(Shared.Config.TalentAtlas)
local TalentArt = require(Shared.Config.TalentArt)
local Classes = require(Shared.Config.Classes)

local fails, checks, out = 0, 0, {}
local function check(ok, text)
	checks += 1
	if not ok then
		fails += 1
		table.insert(out, "ПРОВАЛ: " .. text)
	end
end
local function near(a, b)
	return math.abs((a or 0) - (b or 0)) < 1e-6
end

check(Talents.Version == 2, "версия древа " .. tostring(Talents.Version))
check(Talents.MaxLevel == 60 and Classes.MaxLevel == 60, "потолок уровня 60")
check(Classes.StatLevel == 30, "статы растут до 30-го")
check(Talents.Costs.minor == 1 and Talents.Costs.normal == 1 and Talents.Costs.key == 5, "цены 1 / 1 / 5")

-- ===== раскладка =====
local orderPos = {}
for i, slot in ipairs(Talents.Order) do
	check(not orderPos[slot], "слот дважды в Order: " .. slot)
	orderPos[slot] = i
end
check(#Talents.Order == 22, "слотов в Order: " .. #Talents.Order)
local minorSlots, keySlots, normalSlots = 0, 0, 0
for slot, pos in pairs(Talents.Layout) do
	check(orderPos[slot] ~= nil, "слот раскладки не в Order: " .. slot)
	check(Talents.Needs[slot] ~= nil, "у слота нет Needs: " .. slot)
	check(type(pos.x) == "number" and math.abs(pos.x) <= 1 and type(pos.y) == "number", "координаты слота " .. slot)
	if Talents.MinorPattern[slot] then
		minorSlots += 1
	elseif string.sub(slot, 1, 1) == "K" then
		keySlots += 1
	else
		normalSlots += 1
	end
end
check(minorSlots == 14 and normalSlots == 5 and keySlots == 3, ("слотов: малых %d, узлов %d, ключевых %d"):format(minorSlots, normalSlots, keySlots))
local pattern = { A = 0, B = 0, C = 0 }
for slot, kindOf in pairs(Talents.MinorPattern) do
	check(Talents.Layout[slot] ~= nil, "малый слот без раскладки: " .. slot)
	pattern[kindOf] = (pattern[kindOf] or 0) + 1
end
check(pattern.A == 5 and pattern.B == 5 and pattern.C == 4, "шаблон малых A×5 B×5 C×4")
for slot, needs in pairs(Talents.Needs) do
	for _, need in ipairs(needs) do
		check(orderPos[need] ~= nil and orderPos[need] < orderPos[slot], slot .. ": нужен " .. need .. ", а он позже в Order (цикл?)")
		check(Talents.Layout[need] and Talents.Layout[need].y > Talents.Layout[slot].y, slot .. ": предшественник " .. need .. " не ниже по листу")
	end
end
check(#Talents.Needs.a1 == 0, "a1 — вход без зависимостей")
check(#Talents.Needs.K1 == 2, "K1 открывается любым из двух")

-- ===== структура =====
local classes = 0
for _ in pairs(Talents.Classes) do
	classes += 1
end
check(classes == 2, "классов с древом: " .. classes .. " (воин и маг)")

local total = 0
for _ in pairs(Talents.Nodes) do
	total += 1
end
check(total == 132, "узлов в индексе: " .. total .. " (2 × 3 × 22)")

local ITEMS = { warrior = "helm", mage = "hat" }
local TITLES = { warrior = "ДРЕВО ВОИНА", mage = "ДРЕВО МАГА" }
local PATHS = { warrior = { "Защита", "Натиск", "Парирование" }, mage = { "Источник", "Посох", "Чары" } }
for classId, tree in pairs(Talents.Classes) do
	check(tree.id == classId, classId .. ": id древа")
	check(tree.title == TITLES[classId], classId .. ": заголовок " .. tostring(tree.title))
	check(tree.item == ITEMS[classId], classId .. ": предмет на печати " .. tostring(tree.item))
	check(TalentAtlas.Pieces["cls_" .. tostring(tree.item)] ~= nil, classId .. ": нет cls_" .. tostring(tree.item) .. " в атласе")
	check(tree.prefix == string.sub(classId, 1, 1), classId .. ": префикс " .. tostring(tree.prefix))
	check(tree.background == "bg_" .. classId, classId .. ": фон " .. tostring(tree.background))
	check(TalentArt.Backgrounds[tree.background] ~= nil, classId .. ": фон не описан в TalentArt")
	check(#tree.branches == 3, classId .. ": путей " .. #tree.branches)
	local names, icons = {}, {}
	for bi, branch in ipairs(tree.branches) do
		local tag = classId .. "/" .. branch.id
		check(branch.index == bi, tag .. ": index")
		check(branch.name == PATHS[classId][bi], tag .. ": имя пути " .. tostring(branch.name))
		check(type(branch.text) == "string" and #branch.text > 0, tag .. ": описание пути")
		check(#branch.nodes == 22, tag .. ": узлов " .. #branch.nodes)
		for _, kindOf in ipairs({ "A", "B", "C" }) do
			local m = branch.minor and branch.minor[kindOf]
			check(m ~= nil, tag .. ": нет малого вида " .. kindOf)
			if m then
				local rect = TalentAtlas.Pieces[m.icon]
				check(string.sub(m.icon, 1, 2) == "g_" and rect ~= nil and rect.w == 7 and rect.h == 7, tag .. ": глиф 7×7 — " .. tostring(m.icon))
			end
		end
		local cost, kinds, seen = 0, { minor = 0, normal = 0, key = 0 }, {}
		for _, slot in ipairs(Talents.Order) do
			check(branch.bySlot[slot] ~= nil, tag .. ": нет слота " .. slot)
		end
		for i, n in ipairs(branch.nodes) do
			local ntag = tag .. "/" .. n.id
			check(n.slot == Talents.Order[i], ntag .. ": узлы не в порядке Order")
			check(not seen[n.slot], ntag .. ": слот повторяется " .. n.slot)
			seen[n.slot] = true
			check(Talents.Nodes[n.id] == n, ntag .. ": нет в индексе")
			check(n.classId == classId and n.branchId == branch.id and n.branchIndex == bi, ntag .. ": обратные ссылки")
			check(string.sub(n.id, 1, 2) == tree.prefix .. "_", ntag .. ": префикс id")
			check(type(n.text) == "string" and #n.text > 6, ntag .. ": описание")
			check(n.source == "plan" or n.source == "changed" or n.source == "new", ntag .. ": source " .. tostring(n.source))
			check(n.source ~= "changed" or (type(n.plan) == "string" and #n.plan > 0), ntag .. ": изменён, но нет числа из плана")
			check(Talents.Kinds[n.kind] ~= nil and n.cost == Talents.Costs[n.kind], ntag .. ": вид/цена " .. tostring(n.kind) .. "/" .. tostring(n.cost))
			kinds[n.kind] = (kinds[n.kind] or 0) + 1
			local rect = TalentAtlas.Pieces[n.icon]
			if n.kind == "minor" then
				check(n.minorKind == Talents.MinorPattern[n.slot], ntag .. ": вид малого узла")
				check(n.id == ("%s_%s_%s"):format(tree.prefix, branch.id, n.slot), ntag .. ": id малого узла")
				check(n.source == "new", ntag .. ": малые узлы помечены new")
				check(rect ~= nil and rect.w == 7 and rect.h == 7, ntag .. ": глиф 7×7 — " .. tostring(n.icon))
			else
				check(string.sub(n.slot, 1, 1) == (n.kind == "key" and "K" or "N"), ntag .. ": слот " .. n.slot .. " не для " .. n.kind)
				check(not names[n.name], ntag .. ": имя повторяется в древе — " .. n.name)
				names[n.name] = true
				check(not icons[n.icon], ntag .. ": иконка повторяется в древе — " .. n.icon)
				icons[n.icon] = true
				local prefix = n.kind == "key" and "k_" or "i_"
				check(string.sub(n.icon, 1, 2) == prefix and rect ~= nil and rect.w == 16 and rect.h == 16, ntag .. ": иконка 16×16 — " .. tostring(n.icon))
			end
			local effects = 0
			for k, v in pairs(n.effects) do
				effects += 1
				check(Talents.Effects[k] ~= nil, ntag .. ": эффект не описан — " .. k)
				check(type(v) == "number" and v ~= 0, ntag .. ": эффект " .. k .. " = " .. tostring(v))
			end
			check(effects > 0, ntag .. ": нет эффектов")
			check(#n.needs == #Talents.Needs[n.slot], ntag .. ": число зависимостей")
			for _, need in ipairs(n.needs) do
				local m = Talents.Nodes[need]
				check(m ~= nil and m.branchId == branch.id and m.classId == classId, ntag .. ": зависимость из другого пути " .. tostring(need))
			end
			cost += n.cost
		end
		check(kinds.minor == 14 and kinds.normal == 5 and kinds.key == 3, tag .. (": малых %d, узлов %d, ключевых %d"):format(kinds.minor, kinds.normal, kinds.key))
		check(cost == 34 and branch.cost == 34 and Talents.branchCost(branch) == 34, tag .. ": путь стоит " .. cost)
	end
	check(Talents.treeCost(classId) == 102, classId .. ": древо стоит " .. Talents.treeCost(classId))
end
check(Talents.treeCost("nope") == 0, "нет древа — 0 очков")
check(Talents.tree("assassin") == nil, "у ассасина древа пока нет (фон заготовлен)")

-- ===== атлас =====
for _, piece in ipairs({ "frame_m_base", "frame_m_ring", "frame_n_base", "frame_n_ring", "frame_k_base", "frame_k_ring",
	"root_base", "root_ring", "glow", "badge", "sel", "cls_helm", "cls_hat", "cls_dagger" }) do
	check(TalentAtlas.Pieces[piece] ~= nil, "нет куска атласа " .. piece)
end
local P = TalentAtlas.Pieces
check(TalentArt.Scale == 2, "арт показывается ×2")
check(P.frame_m_base.w * TalentArt.Scale == 26, "рамка малого узла 13 → 26")
check(P.frame_n_base.w * TalentArt.Scale == 46, "рамка узла 23 → 46")
check(P.frame_k_base.w * TalentArt.Scale == 58, "рамка ключевого узла 29 → 58")
check(P.root_base.w * TalentArt.Scale == 46, "корень 23 → 46")
for _, item in ipairs({ "helm", "hat", "dagger" }) do
	check(P["cls_" .. item].w == 16 and P["cls_" .. item].h == 16, "cls_" .. item .. " 16×16")
end
for name, rect in pairs(P) do
	check(rect.x >= 0 and rect.y >= 0 and rect.x + rect.w <= TalentAtlas.Size.w and rect.y + rect.h <= TalentAtlas.Size.h, "кусок вне атласа: " .. name)
end
local names = {}
for name in pairs(P) do
	table.insert(names, name)
end
for i = 1, #names do
	local a = P[names[i]]
	for j = i + 1, #names do
		local b = P[names[j]]
		local overlap = a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
		check(not overlap, "куски атласа налезают: " .. names[i] .. " / " .. names[j])
	end
end

-- ===== очки =====
check(Talents.pointsAt(1) == 0, "уровень 1 → 0 очков")
check(Talents.pointsAt(5) == 4, "уровень 5 → 4 очка")
check(Talents.pointsAt(30) == 29, "уровень 30 → 29")
check(Talents.pointsAt(60) == 59, "уровень 60 → 59")
check(Talents.pointsAt(75) == 59, "выше 60 очков не прибавляется")
check(Talents.pointsAt(nil) == 0, "без уровня — 0")

-- ===== статы до 30-го =====
for classId in pairs(Talents.Classes) do
	local s1, s30, s60 = Classes.statsAtLevel(classId, 1), Classes.statsAtLevel(classId, 30), Classes.statsAtLevel(classId, 60)
	check(s60.level == 60 and s30.level == 30, classId .. ": уровень в статах")
	check(s30.maxHealth > s1.maxHealth, classId .. ": здоровье растёт до 30-го")
	for _, key in ipairs({ "maxHealth", "armor", "weaponDamage", "maxMana" }) do
		check(s60[key] == s30[key], classId .. ": " .. key .. " на 60-м = на 30-м (" .. tostring(s60[key]) .. " / " .. tostring(s30[key]) .. ")")
	end
	check(Classes.statsAtLevel(classId, 99).level == 60, classId .. ": уровень клампится в 60")
end

-- ===== canLearn =====
local function can(classId, learned, id, level, bonus)
	local ok, reason = Talents.canLearn(classId, learned, id, level, bonus)
	return ok and "ok" or reason
end
local function set(...)
	local t = {}
	for _, id in ipairs({ ... }) do
		t[id] = true
	end
	return t
end
local G = function(slot)
	return "w_guard_" .. slot
end
check(Talents.Nodes.w_guard_a1.cost == 1 and Talents.Nodes.w_temper.cost == 1 and Talents.Nodes.w_retaliate.cost == 5, "цены: малый 1, узел 1, ключевой 5")
check(can("warrior", {}, G "a1", 2) == "ok", "a1 на 2-м уровне")
check(can("warrior", {}, G "a1", 1) == "points", "на 1-м уровне очков нет")
check(can("warrior", {}, G "a1", 1, 1) == "ok", "отладочное очко (bonus) работает")
check(can("warrior", {}, G "a2", 10) == "locked", "a2 без a1 закрыт")
check(can("warrior", set(G "a1"), "w_temper", 10) == "locked", "N1 без a2 закрыт")
check(can("warrior", set(G "a1", G "a2"), "w_temper", 10) == "ok", "N1 после a1 → a2")
local left = set(G "a1", G "a2", "w_temper", G "l1", "w_plates")
check(can("warrior", left, "w_retaliate", 60) == "locked", "K1 без l2/r2 закрыт")
left[G "l2"] = true
check(can("warrior", left, "w_retaliate", 60) == "ok", "K1 через l2")
check(can("warrior", left, "w_retaliate", 11) == "points", "K1 стоит 5: на 11-м (10 очков, 6 вложено) не хватает")
check(can("warrior", left, "w_retaliate", 12) == "ok", "K1 на 12-м (11 очков, 6 вложено)")
local right = set(G "a1", G "a2", "w_temper", G "r1", "w_stamina", G "r2")
check(can("warrior", right, "w_retaliate", 60) == "ok", "K1 через r2")
check(can("warrior", left, G "l3", 60) == "ok", "l3 после N2")
check(can("warrior", left, "w_steadfast", 60) == "locked", "N5 нужен r4, а не левая сторона")
check(can("warrior", left, "w_livingfort", 60) == "locked", "K2 без l6 закрыт")
check(can("warrior", set(G "a1"), G "a1", 10) == "learned", "повторно не изучить")
check(can("warrior", {}, "m_source_a1", 10) == "class", "узел мага воину нельзя")
check(can("mage", {}, G "a1", 10) == "class", "узел воина магу нельзя")
check(can("mage", {}, "m_source_a1", 2) == "ok", "маг: вход в «Источник»")
check(can("warrior", {}, "nope", 10) == "unknown", "неизвестный узел")
check(select(1, Talents.spent("warrior", set(G "a1", "m_ink", "m_well"))) == 1, "spent считает только свой класс")
do
	local spent, by = Talents.spent("warrior", set(G "a1", G "a2", "w_temper", "w_retaliate", "w_sharp"))
	check(spent == 9 and by.guard == 8 and by.blade == 1, "spent по путям: " .. spent)
end
for _, reason in ipairs({ "unknown", "class", "learned", "locked", "points", "gold", "hub", "empty", "busy" }) do
	check(type(Talents.Reasons[reason]) == "string", "нет подписи причины " .. reason)
end

-- На 60-м: путь целиком (34) + 25 очков во втором — оба конца второго пути не взять.
for classId, tree in pairs(Talents.Classes) do
	local learned = {}
	local function learnBranch(branch, level)
		for _ = 1, 22 do
			for _, n in ipairs(branch.nodes) do
				if Talents.canLearn(classId, learned, n.id, level) then
					learned[n.id] = true
				end
			end
		end
	end
	learnBranch(tree.branches[1], 60)
	local spent = Talents.spent(classId, learned)
	check(spent == 34, classId .. ": первый путь целиком = " .. spent)
	learnBranch(tree.branches[2], 60)
	local spent2, by = Talents.spent(classId, learned)
	local b2 = tree.branches[2]
	check(by[b2.id] == 24 and spent2 == 58, classId .. ": во второй путь вошло " .. tostring(by[b2.id]) .. " (ждём 24: всё, кроме K2 и K3)")
	check(not learned[b2.bySlot.K2.id] and not learned[b2.bySlot.K3.id], classId .. ": концы второго пути не по карману")
	check(learned[b2.bySlot.K1.id] == true, classId .. ": K1 второго пути взят")
	local a1 = tree.branches[3].bySlot.a1.id
	check(Talents.canLearn(classId, learned, a1, 60), classId .. ": 59-е очко — в третий путь")
	learned[a1] = true
	check(select(1, Talents.spent(classId, learned)) == 59, classId .. ": на 60-м все 59 очков")
	check(not Talents.canLearn(classId, learned, tree.branches[3].bySlot.a2.id, 60), classId .. ": 60-го очка нет")
	check(not Talents.canLearn(classId, learned, tree.branches[3].bySlot.a2.id, 75), classId .. ": и на 75-м нет")
	-- на 30-м путь целиком ещё не собрать (29 < 34)
	local early = {}
	for _ = 1, 22 do
		for _, n in ipairs(tree.branches[1].nodes) do
			if Talents.canLearn(classId, early, n.id, 30) then
				early[n.id] = true
			end
		end
	end
	check(select(1, Talents.spent(classId, early)) <= 29, classId .. ": на 30-м не больше 29")
end

-- ===== aggregate =====
local function branchAll(classId, index)
	local all = {}
	for _, n in ipairs(Talents.tree(classId).branches[index].nodes) do
		all[n.id] = true
	end
	return all
end
do
	local all = branchAll("warrior", 1)
	all.m_ink = true -- чужой класс не складывается
	local mods = Talents.aggregate("warrior", all)
	check(near(mods.maxHealthPct, 0.175), "Защита: здоровье 6 + 4 + 5 × 1,5 = 17,5%, есть " .. tostring(mods.maxHealthPct))
	check(near(mods.armor, 12), "Защита: броня 3 + 4 + 5 × 1 = 12, есть " .. tostring(mods.armor))
	check(near(mods.healPct, 0.09), "Защита: лечение 5 + 4 × 1 = +9%, есть " .. tostring(mods.healPct))
	check(near(mods.debuffTime, -0.2), "Защита: дебафы −20%")
	check(mods.maxManaPct == nil, "мана мага не попала воину")

	local blade = Talents.aggregate("warrior", branchAll("warrior", 2))
	check(near(blade.weaponDamagePct, 0.135), "Натиск: урон 6 + 5 × 1,5 = 13,5%, есть " .. tostring(blade.weaponDamagePct))
	check(near(blade.attackSpeed, 0.10), "Натиск: скорость атаки 5 + 5 × 1 = 10%")
	check(near(blade.finisherBonus, 0.27), "Натиск: третий удар 15 + 4 × 3 = 27%")

	local parry = Talents.aggregate("warrior", branchAll("warrior", 3))
	check(near(parry.parryWindow, 0.055), "Парирование: окно 0,03 + 5 × 0,005 = 0,055 с")
	check(near(parry.counterBonus, 0.35), "Парирование: контратака 0,2 + 5 × 0,03 = 0,35")
	check(near(parry.moveSpeed, 0.04), "Парирование: бег 4 × 1% = 4%")

	local source = Talents.aggregate("mage", branchAll("mage", 1))
	check(near(source.maxManaPct, 0.18) and near(source.maxMana, 60), "Источник: мана +18% и +60")
	check(near(source.manaRegen, 1.35), "Источник: восстановление 0,6 + 5 × 0,15 = 1,35")
	check(near(source.maxHealthPct, 0.06), "Источник: здоровье 4 × 1,5 = 6%")
	check(near(source.lowManaRegen, 1) and near(source.killMana, 5) and near(source.spellCost, -0.1), "Источник: второе дыхание, конспект, поля")

	local staff = Talents.aggregate("mage", branchAll("mage", 2))
	check(near(staff.projectileSpeed, 0.30) and near(staff.projectileRange, 0.10), "Посох: снаряды +30% скорости и +10% дальности")
	check(near(staff.weaponDamagePct, 0.135), "Посох: урон 6 + 5 × 1,5 = 13,5%")
	check(near(staff.critChance, 0.04), "Посох: крит 4 × 1% = 4%")
	check(near(staff.homing, 90) and near(staff.pierce, 1) and near(staff.splitEvery, 4), "Посох: наводка, пробитие, расщепление")

	local spells = Talents.aggregate("mage", branchAll("mage", 3))
	check(near(spells.abilityCooldown, -0.225), "Чары: перезарядка −15 − 5 × 1,5 = −22,5%")
	check(near(spells.abilityDamage, 0.38), "Чары: урон заклинаний 8 + 20 + 5 × 2 = 38%")
	check(near(spells.veilCooldown, -3), "Чары: «Покров» −2 − 4 × 0,25 = −3 с")
	check(near(spells.empower, 0.25) and near(spells.castTime, -0.15), "Чары: резкость, скоропись")
	check(spells.maxHealthPct == nil, "здоровье воина не попало магу")
end

-- ===== сброс =====
check(Talents.resetCost(0, 0) == 0 and Talents.resetCost(0, 3) == 0, "пустое древо — сброс 0")
check(Talents.resetCost(8, 0) == 0, "первый сброс бесплатно")
check(Talents.resetCost(1, 1) == 50, "минимум 50 золота")
check(Talents.resetCost(8, 1) == 200, "8 очков → 200 золота")
check(Talents.resetCost(59, 4) == 1475, "59 очков → 1475 золота")
check(Talents.Reset.hubOnly == true, "сброс только в долине")

-- ===== арт =====
check(not TalentArt.has("") and not TalentArt.has(nil) and not TalentArt.has("rbxassetid://0"), "пустой id — нет арта")
check(TalentArt.has("rbxassetid://123456"), "заполненный id — есть арт")
check(TalentArt.BgSize.w == 560 and TalentArt.BgSize.h == 374, "фон 560×374")
for _, field in pairs(TalentArt.Backgrounds) do
	check(TalentArt[field] ~= nil, "нет поля TalentArt." .. field)
end

-- ===== отчёт: деревья (малые узлы — одной строкой на путь) =====
local report = { "# Древо талантов v2", "" }
for _, classId in ipairs({ "warrior", "mage" }) do
	local tree = Talents.tree(classId)
	table.insert(report, "## " .. tree.title .. (" — %d очков"):format(Talents.treeCost(classId)))
	for _, branch in ipairs(tree.branches) do
		table.insert(report, ("### %s (%d)%s — %s"):format(branch.name, branch.cost, branch.plan and (" [план: " .. branch.plan .. "]") or "", branch.text))
		local m = branch.minor
		table.insert(report, ("малые: A %s (%s) · B %s (%s) · C %s (%s)"):format(m.A.name, m.A.text, m.B.name, m.B.text, m.C.name, m.C.text))
		for _, slot in ipairs(Talents.Order) do
			local n = branch.bySlot[slot]
			if n.kind ~= "minor" then
				table.insert(report, ("%s %s | %s | %d | %s%s"):format(slot, n.id, n.name, n.cost, n.text,
					n.source == "changed" and (" (план: " .. n.plan .. ")") or (n.source == "new" and " (новое)" or "")))
			end
		end
	end
	table.insert(report, "")
end
for _, line in ipairs(out) do
	table.insert(report, line)
end
table.insert(report, ("ИТОГО: %d проверок, %d провалов"):format(checks, fails))
return table.concat(report, "\n")
