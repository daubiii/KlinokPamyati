--!nonstrict
-- balance_classes.lua — калькулятор баланса «воин против мага» (07.11.2026).
-- Урон за 30 с боя на каждом этаже по редкостям: обычные удары + способность оружия
-- (перезарядка; у мага ещё мана и масштаб от максимума маны). Два случая:
--   «один»  — одна цель (босс, элитник);
--   «толпа» — 4 врага кучкой (R4) в 6–9 стадах перед героем.
-- Числа берутся из настоящих конфигов (Classes, Weapons, Loot, LootMage, Echo, Mana),
-- поэтому калькулятор живой: поменял число заклинания — перезапусти.
--   LUAU=путь/к/luau node tools/run-luau.js tools/lua/balance_classes.lua
--
-- Допущения (одинаковые для обоих классов, чтобы сравнение было честным):
--   уровень героя на этаже 4 / 10 / 16 / 22 / 28, оружие ★1 (эхо 1), без талантов, брони и душ;
--   «время в бою» 85%: воин отходит от замахов, маг уворачивается и перебегает;
--   крит — по редкости (×1,5); пассивки легендарок не считаются (у обоих есть свои);
--   способность готова в начале боя (1 + ⌊29 / перезарядка⌋ применений).
-- Попадания способности по толпе и одной цели — оценка по форме зоны (таблицы ниже):
-- для мага она считается из чисел заклинания, для воина — из суммарного множителя × охват.

local Shared = (_G :: any).KlinokShared
local Classes = require(Shared.Config.Classes)
local Combat = require(Shared.Config.Combat)
local Echo = require(Shared.Config.Echo)
local Loot = require(Shared.Config.Loot)
local LootMage = require(Shared.Config.LootMage)
local Mana = require(Shared.Config.Mana)
local Weapons = require(Shared.Config.Weapons)

local FIGHT = 30
local UPTIME = 0.85
local LEVEL = { 4, 10, 16, 22, 28 }
local BURN = LootMage.Debuffs.burn.dps * LootMage.Debuffs.burn.duration
local POISON = LootMage.Debuffs.poison.dps * LootMage.Debuffs.poison.duration

-- ===== Обычные удары =====

-- Узор серии посоха: доля урона по одной цели и сумма по толпе из 4.
local PATTERN = {
	single = { 1.0, 1.0 }, twin = { 1.2, 1.4 }, fan3 = { 0.9, 1.35 }, fan5 = { 0.9, 1.4 },
	volley2 = { 1.2, 1.2 }, volley3 = { 1.26, 1.26 }, big = { 1.0, 1.0 }, lob = { 1.0, 1.0 },
	lob3 = { 1.0, 1.5 }, wave = { 1.0, 3.0 }, beam = { 1.15, 2.3 }, nova = { 0.85, 2.0 },
}

local function cycle(item, attackSpeed)
	local interval = Combat.Attack.hitInterval / (item.speed * attackSpeed)
	return 3 * interval + Combat.Attack.comboRecovery * item.recovery
end

local function critFactor(rarity)
	return 1 + 0.5 * (Echo.BaseCrit[rarity] or 0)
end

-- Урон обычных ударов в секунду в единицах «урон класса» (умножить на weaponDamage).
local function warriorBasic(item, rarity)
	local t = cycle(item, Classes.data.warrior.attackSpeed)
	local perCycle = (2 + Combat.Attack.finisherMultiplier) * item.damage * critFactor(rarity)
	local hits = 1 + 3 * math.min(item.arc or 100, 180) / 360 -- сколько из 4 задевает дуга
	return perCycle / t, perCycle * hits / t
end

local function mageBasic(item, rarity)
	local t = cycle(item, Classes.data.mage.attackSpeed)
	local single, pack = 0, 0
	for i, patternId in ipairs(item.combo or { "single", "single", "single" }) do
		local p = PATTERN[patternId] or PATTERN.single
		local k = i == 3 and Combat.Attack.finisherMultiplier or 1
		local pattern = LootMage.Patterns[patternId] or {}
		local s, q = p[1], p[2]
		local bolt = item.bolt or {}
		local splash = pattern.splash or bolt.splash
		-- финал серии посоха всегда взрывается (LootMage.FinisherSplash), кроме волны/луча/новы
		local fin = LootMage.FinisherSplash
		if i == 3 and fin and not (pattern.wave or pattern.beam or pattern.nova) then
			splash = { math.max(fin[1], splash and splash[1] or 0), math.max(fin[2], splash and splash[2] or 0) }
		end
		if splash then
			q += q * splash[2] * 1.5
		end
		if bolt.pierce then
			q += math.min(q, 1) * 0.5 * bolt.pierce
		end
		if bolt.split then
			q += bolt.split[1] * bolt.split[2] * 0.5
		end
		if bolt.chain then
			q += bolt.chain[1] * bolt.chain[3] * 0.8
		end
		single += s * k
		pack += q * k
	end
	local base = item.damage * critFactor(rarity)
	local dps, dpsPack = single * base / t, pack * base / t
	-- Горение/яд посоха почти всегда висит на цели (шанс за удар + финал серии всегда).
	local debuff = item.bolt and item.bolt.debuff
	if debuff and (debuff[1] == "burn" or debuff[1] == "poison") then
		local def = LootMage.Debuffs[debuff[1]]
		local uptime = math.min(1, (3 / t) * (debuff[2] + 1 / 3) * def.duration)
		dps += def.dps * item.damage * uptime
		dpsPack += def.dps * item.damage * uptime * 2.5
	end
	return dps, dpsPack
end

-- ===== Способности =====

-- Воин: охват толпы из 4 (сколько врагов получает полный множитель) и блокировка, с.
local WARRIOR = {
	vortex = { 3.6, 1.0 }, rift = { 3, 0.7 }, unlock = { 2.5, 0.6 }, reap = { 2.6, 0.55 },
	flood = { 3, 0.7 }, prune = { 3, 1.2 }, pack = { 1.6, 0.5 }, snare = { 3.6, 0.7 },
	dive = { 1.6, 0.5 }, last_hunt = { 3.2, 1.6 }, spill = { 3, 1.0 }, overheat = { 2, 0.4 },
	anvil_drop = { 3.4, 0.9 }, forge_breath = { 3, 0.9 }, slag_reap = { 3.4, 2.2 }, pour = { 3, 1.6 },
	inscribe = { 2.6, 0.7 }, seal_time = { 3.6, 0.8 }, timeless = { 3.6, 0.8 }, ink_splash = { 3.2, 1.0 },
	erase = { 3.6, 2.4 }, recall = { 2.2, 1.0 },
}

-- Маг: доли силы заклинания по одной цели и по толпе — из чисел самого заклинания.
local MAGE = {}
MAGE.ward_circle = function(a)
	local ticks = a.tickDamage * a.duration / a.tick * 0.7
	return a.burst + ticks, (a.burst + ticks) * 3
end
MAGE.signal_fire = function(a)
	local ticks = a.tickDamage * a.pillarTime / a.tick
	return a.blast + ticks * 0.6 + BURN, a.blast * 3.5 + ticks * 0.5 * 2.5 + BURN * 3.5
end
MAGE.light_gate = function(a)
	return a.surge + a.close * 0.7, a.surge * 3 + a.close * 2
end
MAGE.lotus_bloom = function(a)
	return a.geyser * 0.6 + a.petals * a.petal, a.geyser * 2 + a.petals * a.petal
end
MAGE.mycelium = function(a)
	if not a.cloudTick then -- до переделки: 6 спор + грибы
		return a.spores * a.spore * 0.6 + POISON + a.pop, a.spores * a.spore + POISON * 3 + a.pop * 3
	end
	local cloud = a.cloudTick * a.cloudTime / a.tick
	local spores = a.spores * a.spore
	return spores * 0.5 + cloud * 0.75 + a.burst + POISON,
		spores + cloud * 0.75 * 3.5 + a.burst * 3.5 + POISON * 3.5
end
MAGE.thorn_garden = function(a)
	local garden = a.tickDamage * a.gardenTime / a.tick * 0.6
	return a.ring + POISON + garden, (a.ring + POISON + garden) * 3.5
end
MAGE.spirit_pack = function(a)
	if not a.bites then -- до переделки: 4 волка-самонавода
		return a.wolves * a.bite * 0.75, a.wolves * (a.bite + a.secondBite)
	end
	local single = a.bites * a.bite + a.pounce
	return single, single + a.howl * 3
end
MAGE.hunters_moon = function(a)
	return a.beams * a.beam + a.crescent, a.beams * a.beam + a.crescent * 3.5
end
MAGE.royal_hunt = function(a)
	local spears = a.spears * a.spear
	return a.net + spears + a.tear, a.net * 3.5 + spears * 1.8 + a.tear * 3.5
end
MAGE.fire_rain = function(a)
	return a.meteors * a.meteor * 0.65 * 0.8 + BURN, a.meteors * a.meteor * (0.65 * 2 + 0.35 * 0.6) + BURN * 3.5
end
MAGE.forged_lightning = function(a)
	local pack, share = a.strike, a.strike
	for _ = 1, math.min(a.jumps, 3) do
		share *= a.decay
		pack += share
	end
	return a.strike, pack
end
MAGE.forge_heart = function(a)
	local wall = a.tickDamage * a.wallTime / a.tick * 0.5
	return a.pillar + BURN + wall, (a.pillar + BURN + wall) * 3
end
MAGE.meteor = function(a)
	local lava = a.tickDamage * a.lavaTime / a.tick * 0.6
	return a.impact * 0.85 + lava + BURN, a.impact * 0.8 * 4 + lava * 3 + BURN * 4
end
MAGE.first_cast = function(a)
	local single = a.rift * 0.5 + a.nova * 0.7 + BURN
	return single, single * 4
end
MAGE.open_tome = function(a)
	return a.glyphs * a.glyph + a.storm * 0.5, a.glyphs * a.glyph + a.storm * 2
end
MAGE.time_stop = function(a)
	if not a.sweeps then
		return a.strike, a.strike * 3.5
	end
	local single = a.sweep * a.sweeps + a.strike
	return single, single * 3.5
end
MAGE.fate_line = function(a)
	return a.beam, a.beam * 2.5
end
MAGE.ink_hole = function(a)
	local single = a.tickDamage * a.pullTime / a.tick + a.blast
	return single, single * 4
end
MAGE.total_recall = function(a)
	local beams = #a.beamAt * a.echoes * a.beam
	return beams + a.orbs * a.orb, beams * 1.3 + a.orbs * a.orb
end

local function castsIn(cooldown)
	return 1 + math.floor((FIGHT - 1) / cooldown)
end

-- ===== Подсчёт =====

local function itemOf(id)
	return Weapons.Items[id]
end

local function evaluate(weapon, floor)
	local level = LEVEL[floor]
	local isMage = weapon.class == "mage"
	local class = Classes.statsAtLevel(isMage and "mage" or "warrior", level)
	local wd = class.weaponDamage
	local item = itemOf(weapon.id)
	local basic, basicPack
	if isMage then
		basic, basicPack = mageBasic(item, weapon.rarity)
	else
		basic, basicPack = warriorBasic(item, weapon.rarity)
	end
	local abilitySingle, abilityPack, lock, casts = 0, 0, 0, 0
	local ability = weapon.ability and Loot.Abilities[weapon.ability]
	if ability then
		local power = item.damage * (1 + (weapon.damageBonus or 0))
		local cooldown = ability.cooldown * (1 - (weapon.cooldownReduction or 0))
		casts = castsIn(cooldown)
		local s, q
		if isMage and ability.school == "mage" then
			local f = MAGE[ability.id]
			assert(f, "нет формулы для " .. tostring(ability.id))
			s, q = f(ability)
			power *= Mana.abilityScale(class.maxMana or 0)
			-- мана: запас + реген за бой (посох добавляет реген)
			local pool = (class.maxMana or 0) + FIGHT * ((class.manaRegen or 0) + (item.manaRegen or 0))
			casts = math.min(casts, math.floor(pool / math.max(ability.mana or 1, 1)))
			lock = ability.castTime or 0.5
		else
			local w = WARRIOR[ability.id] or { 3, 0.7 }
			s = ability.damageMultiplier or 0
			q = s * w[1]
			lock = w[2]
		end
		abilitySingle = s * power * casts
		abilityPack = q * power * casts
	end
	local attackTime = FIGHT * UPTIME - lock * casts
	local single = wd * (basic * attackTime + abilitySingle)
	local pack = wd * (basicPack * attackTime + abilityPack)
	return {
		single = single,
		pack = pack,
		basicSum = wd * (basic + basicPack) * attackTime,
		abilitySum = wd * (abilitySingle + abilityPack),
		abilityShare = (abilitySingle * wd) / math.max(single, 1),
		casts = casts,
	}
end

local RARITIES = { "common", "rare", "epic", "legendary", "secret" }
local rows = {}
local spells = {}
for floor = 1, 5 do
	for _, rarity in ipairs(RARITIES) do
		local sum = { warrior = { 0, 0, 0 }, mage = { 0, 0, 0 } }
		for _, weapon in ipairs(Loot.Weapons) do
			if (weapon.floor or 1) == floor and weapon.rarity == rarity and itemOf(weapon.id) then
				local r = evaluate(weapon, floor)
				local key = weapon.class == "mage" and "mage" or "warrior"
				sum[key][1] += r.single
				sum[key][2] += r.pack
				sum[key][3] += 1
				if weapon.ability then
					table.insert(spells, { basicSum = r.basicSum, abilitySum = r.abilitySum, floor = floor, rarity = rarity, class = key, id = weapon.id, ability = weapon.ability,
						single = r.single, pack = r.pack, share = r.abilityShare, casts = r.casts })
				end
			end
		end
		if sum.warrior[3] > 0 and sum.mage[3] > 0 then
			local ws, wp = sum.warrior[1] / sum.warrior[3], sum.warrior[2] / sum.warrior[3]
			local ms, mp = sum.mage[1] / sum.mage[3], sum.mage[2] / sum.mage[3]
			table.insert(rows, { floor = floor, rarity = rarity, ws = ws, wp = wp, ms = ms, mp = mp })
		end
	end
end

local RU = { common = "обычн.", rare = "редк.", epic = "эпик", legendary = "легенд.", secret = "секрет" }
local function pct(a, b)
	return ("%+d%%"):format(math.floor((a / b - 1) * 100 + 0.5))
end

print("Урон за 30 с (воин / маг), один враг и толпа из 4; итог = среднее двух случаев")
print("эт  редкость | один: воин   маг   разн. | толпа: воин   маг   разн. | итог")
local worst = 0
for _, r in ipairs(rows) do
	local total = (r.ms + r.mp) / (r.ws + r.wp)
	worst = math.max(worst, math.abs(total - 1))
	print(("%d   %-8s | %10d %5d %6s | %11d %5d %6s | %s"):format(r.floor, RU[r.rarity], r.ws, r.ms, pct(r.ms, r.ws), r.wp,
		r.mp, pct(r.mp, r.wp), pct(r.ms + r.mp, r.ws + r.wp)))
end
print(("Наибольший разрыв по итогу: %.0f%% (цель — до 10%%)"):format(worst * 100))

print("")
print("Оружие со способностью: урон за 30 с (один / толпа), доля способности, применений")
table.sort(spells, function(a, b)
	if a.floor ~= b.floor then
		return a.floor < b.floor
	end
	if a.class ~= b.class then
		return a.class > b.class
	end
	return a.id < b.id
end)
for _, s in ipairs(spells) do
	print(("%d %-7s %-20s %-17s %6d / %6d  способн. %2d%%  ×%d"):format(s.floor, s.class == "mage" and "маг" or "воин",
		s.id, s.ability, s.single, s.pack, math.floor(s.share * 100 + 0.5), s.casts))
end

-- Подбор: множитель урона посоха (обычные/редкие/эпики) или долей заклинания (легенд./секрет),
-- чтобы итог оружия = TARGET × средний итог воина того же этажа и редкости.
if (_G :: any).BALANCE_SOLVE then
	local TARGET = 0.98
	local warriorAvg = {}
	local all = {}
	for _, weapon in ipairs(Loot.Weapons) do
		if itemOf(weapon.id) then
			local r = evaluate(weapon, weapon.floor or 1)
			local key = (weapon.floor or 1) .. weapon.rarity
			if weapon.class ~= "mage" then
				local a = warriorAvg[key] or { 0, 0 }
				a[1] += r.single + r.pack
				a[2] += 1
				warriorAvg[key] = a
			else
				table.insert(all, { weapon = weapon, r = r, key = key })
			end
		end
	end
	print("")
	print("SOLVE id itemFactor spellFactor")
	for _, e in ipairs(all) do
		local a = warriorAvg[e.key]
		if a then
			local target = TARGET * a[1] / a[2]
			local total = e.r.single + e.r.pack
			local itemF = target / total
			local spellF = e.r.abilitySum > 0 and (target - e.r.basicSum) / e.r.abilitySum or 0
			print(("SOLVE %s %s %.3f %.3f"):format(e.weapon.id, e.weapon.rarity, itemF, spellF))
		end
	end
end

return { rows = rows, worst = worst }
