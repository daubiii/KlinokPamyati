--!nonstrict
-- Loot
-- Сундук, пул оружия этажа 1 и душа босса — по приложению Е.
--
-- Сундук этажа 1: 1 оружие, 150 золота, 3-5 Ржавого железа.
-- Первые два сундука аккаунта всегда дают обычное оружие.
-- Дальше редкость по весам 70/22/7/1, внутри редкости оружие случайно.
-- Пул для MVP — только оружие воина (меч и молот).

local Rarities = require(script.Parent.Rarities)

local Loot = {}

Loot.ChestWeights = {
	common = 70,
	rare = 22,
	epic = 7,
	legendary = 1,
}

Loot.Chest = {
	gold = 150,
	iron = { 3, 5 },
	firstChestsCommon = 2,
}

Loot.IronMaterial = "rusty_iron"

-- Способности оружия (клавиша «1»). Согласовано с Артёмом 24.10.2026.
-- Проценты — от урона оружия (урон класса × множитель предмета × ★ эха).
-- Логика — ServerScriptService/Systems/WeaponAbilities, эффекты —
-- клиентский AbilityFx. Сервер считает, клиент только показывает.
Loot.Abilities = {
	-- Вихревой клинок: кружение 1 с, три удара по кругу со стягиванием,
	-- затем режущая волна наружу с отбрасыванием.
	vortex = {
		id = "vortex",
		name = "Вихрь-воронка",
		icon = "whirl",
		description = "Кружение 1 с: 3 удара по 70% вокруг и стягивание врагов, затем волна 90% с отбросом",
		cooldown = 13,
		castTime = 1.0,
		ticks = { 0.2, 0.5, 0.8 },
		tickDamage = 0.7,
		radius = 5.5,
		pull = 1.6, -- стады за тик к герою
		waveAt = 1.0,
		waveDamage = 0.9,
		waveRadius = 7,
		knockback = 3,
		damageMultiplier = 3.0, -- суммарно, для подсказок и сравнения
	},
	-- Расколотый молот (правка 25.10.2026, без прыжка): удар в землю на месте,
	-- три трещины вперёд замедляют, через 0,6 с из них бьют каменные шипы и
	-- подбрасывают врагов.
	rift = {
		id = "rift",
		name = "Разлом",
		icon = "split",
		description = "Удар в землю 200% (оглушение 1 с, −5 брони); 3 трещины вперёд: 60% и замедление 40%; через 0,6 с шипы 120% с подбросом",
		cooldown = 15,
		castTime = 0.65,
		slamAt = 0.3, -- молот касается земли (анимация riftSlam)
		slamDamage = 2.0,
		radius = 4,
		stun = 1.0,
		armorBreak = 5,
		armorBreakDuration = 6,
		cracks = 3,
		crackSpread = 30, -- градусы между трещинами
		crackLength = 11,
		crackHalfWidth = 1.3,
		crackTime = 0.25, -- трещина добегает до конца
		crackDamage = 0.6,
		slow = 0.4,
		slowTime = 1.5,
		eruptDelay = 0.6,
		eruptDamage = 1.2,
		launchHeight = 3.5,
		launchTime = 0.7,
		damageMultiplier = 3.8,
	},
	-- Ключ Привратника (правка 25.10.2026): ключ летит вперёд и втыкается в
	-- землю (или у первого врага на пути); печать R10 сковывает врагов
	-- цепями на 1 с (+25% урона по ним), цепи взрываются, ключ возвращается.
	unlock = {
		id = "unlock",
		name = "Отпереть",
		icon = "key",
		description = "Бросок ключа: печать радиусом 10 сковывает врагов на 1 с (+25% урона по ним), затем взрыв 240% с отбросом",
		cooldown = 18,
		castTime = 0.45,
		releaseAt = 0.2, -- ключ уходит из руки (анимация unlockThrow)
		throwRange = 16,
		throwHalfWidth = 1.5, -- ширина «коридора», в котором ключ цепляет врага
		radius = 10,
		bindTime = 1.0,
		bossBindTime = 1.0,
		vulnerable = 0.25,
		blastDamage = 2.4,
		knockback = 3.5,
		damageMultiplier = 2.4,
	},

	-- Старые способности: остались для старых сохранений и для витрины.
	whirl = {
		id = "whirl",
		name = "Вихрь клинка",
		icon = "whirl",
		damageMultiplier = 1.8,
		radius = 5,
		cooldown = 12,
	},
	sunder = {
		id = "sunder",
		name = "Раскол",
		icon = "split",
		damageMultiplier = 2.5,
		radius = 6,
		stun = 1.0,
		armorBreak = 5,
		armorBreakDuration = 6,
		cooldown = 15,
	},
}

-- Пассивки легендарного оружия (работают, пока оружие в руке).
Loot.Passives = {
	-- Каждый 3-й удар серии ставит на врага «скважину»; на третьей —
	-- бонусный удар ключом 100%.
	keyhole = {
		id = "keyhole",
		name = "Скважина",
		description = "Каждый 3-й удар серии ставит на врага скважину; на 3-й — удар ключом 100%",
		marks = 3,
		markTime = 8, -- метки гаснут без обновления
		damage = 1.0,
	},
}

-- Пул оружия этажа 1 (приложение Е, таблица сундука).
Loot.Weapons = {
	{ id = "rusty_sword", name = "Ржавый меч", typeId = "sword", rarity = "common" },
	{ id = "iron_falchion", name = "Железный палаш", typeId = "sword", rarity = "common" },
	{ id = "forge_hammer", name = "Кузнечный молот", typeId = "hammer", rarity = "common" },
	{ id = "guard_blade", name = "Клинок стража", typeId = "sword", rarity = "rare" },
	{ id = "guard_hammer", name = "Молот стража", typeId = "hammer", rarity = "rare" },
	{
		id = "vortex_blade",
		name = "Вихревой клинок",
		typeId = "sword",
		rarity = "epic",
		ability = "vortex",
	},
	{
		id = "shattered_hammer",
		name = "Расколотый молот",
		typeId = "hammer",
		rarity = "epic",
		ability = "rift",
	},
	{
		id = "gatekeeper_key",
		name = "Ключ Привратника",
		typeId = "sword",
		rarity = "legendary",
		ability = "unlock",
		passive = "keyhole",
		-- Легендарка (план, прил. Б): +15% к урону способности, −8% к перезарядке.
		damageBonus = 0.15,
		cooldownReduction = 0.08,
	},
}

-- Души босса Привратника: первая гарантирована, дальше по весам §прил. Е.
Loot.BossSouls = {
	common = {
		id = "rusty_stance",
		name = "Ржавая стойка",
		rarity = "common",
		kind = "passive",
		armorBonus = 15,
		duration = 5,
		description = "+15 брони на 5 с после удачного парирования",
	},
	epic = {
		id = "gate_barrier",
		name = "Барьер ворот",
		rarity = "epic",
		kind = "active",
		description = "щит на 4 с, поглощает до 200 урона, перезарядка 18 с",
	},
	legendary = {
		id = "guard_verdict",
		name = "Приговор стража",
		rarity = "legendary",
		kind = "active",
		description = "удар по линии 300% урона, оглушение 1,5 с, перезарядка 22 с",
	},
}

Loot.BossSoulWeights = {
	common = 70,
	epic = 25,
	legendary = 5,
}

-- Этаж 2 «Затопленные сады»: оружие, способности и пассивка из Config.LootFloor2.
-- У оружия этажа 2 стоит floor = 2: сундук этажа 1 его не выдаёт (пул выбирается по этажу).
local LootFloor2 = require(script.Parent.LootFloor2)
for abilityId, ability in pairs(LootFloor2.Abilities) do
	Loot.Abilities[abilityId] = ability
end
for passiveId, passive in pairs(LootFloor2.Passives) do
	Loot.Passives[passiveId] = passive
end
for _, weapon in ipairs(LootFloor2.Weapons) do
	weapon.floor = 2
	table.insert(Loot.Weapons, weapon)
end
-- Веса редкостей сундука по этажу; этаж без записи берёт веса этажа 1.
Loot.ChestWeightsByFloor = {
	[1] = Loot.ChestWeights,
	[2] = LootFloor2.ChestWeights,
}

-- Маг: посохи этажей 1–5, заклинания и пассивки (Config.LootMage). У посохов class = "mage":
-- сундук мага выдаёт только посохи, сундук воина — только оружие воина.
local LootMage = require(script.Parent.LootMage)
for abilityId, ability in pairs(LootMage.Abilities) do
	Loot.Abilities[abilityId] = ability
end
for passiveId, passive in pairs(LootMage.Passives) do
	Loot.Passives[passiveId] = passive
end
for _, weapon in ipairs(LootMage.Weapons) do
	table.insert(Loot.Weapons, weapon)
end
Loot.ChestWeightsByClass = { mage = LootMage.ChestWeights }
Loot.StarterWeapons = { warrior = "rusty_sword", mage = LootMage.StarterWeapon }

-- Этажи 3–5 «Псарни охоты», «Кузня Основателя», «Архив Хрониста».
-- Пакеты обновлений — ветки от разных баз: эта связка терялась при наложении,
-- и оружие этажей 3–5 не находилось по id (give отвечал «нет оружия»), а сундуки
-- этих этажей не имели пула.
local FLOOR_LOOT = {
	[3] = require(script.Parent.LootFloor3),
	[4] = require(script.Parent.LootFloor4),
	[5] = require(script.Parent.LootFloor5),
}
for floor = 3, 5 do
	local data = FLOOR_LOOT[floor]
	for abilityId, ability in pairs(data.Abilities) do
		Loot.Abilities[abilityId] = ability
	end
	for passiveId, passive in pairs(data.Passives) do
		Loot.Passives[passiveId] = passive
	end
	for _, weapon in ipairs(data.Weapons) do
		weapon.floor = floor
		table.insert(Loot.Weapons, weapon)
	end
end

-- Переделка способностей мечей и молотов (07.11.2026): поля поверх способностей этажей 2–5.
-- Последним — чтобы ни одно подмешивание выше не затёрло правку.
do
	local LootWeaponsV2 = require(script.Parent.LootWeaponsV2)
	for abilityId, patch in pairs(LootWeaponsV2.Patches) do
		local ability = Loot.Abilities[abilityId]
		if ability then
			for key, value in pairs(patch) do
				ability[key] = value
			end
			ability.v2 = true
		end
	end
end

Loot.ChestWeightsByFloor[3] = FLOOR_LOOT[3].ChestWeights
Loot.ChestWeightsByFloor[4] = FLOOR_LOOT[4].ChestWeights
Loot.ChestWeightsByFloor[5] = FLOOR_LOOT[5].ChestWeights

-- Золото и материал сундука по этажу. Раньше rollChest знал только этаж 2,
-- и сундуки 3–5 выдавали 150 золота и «Ржавое железо» этажа 1.
local CHEST_INFO = {
	[1] = { gold = Loot.Chest.gold, material = Loot.IronMaterial, materialName = "Ржавое железо", materialRange = Loot.Chest.iron },
	[2] = LootFloor2.Chest,
	[3] = FLOOR_LOOT[3].Chest,
	[4] = FLOOR_LOOT[4].Chest,
	[5] = FLOOR_LOOT[5].Chest,
}

function Loot.chestInfo(floor: number?)
	return CHEST_INFO[floor or 1] or CHEST_INFO[1]
end

-- Материал этажа: падает из сундуков и с врагов, им кузнец улучшает броню этого этажа.
function Loot.materialOf(floor: number?): string
	return Loot.chestInfo(floor).material
end

function Loot.materialName(floor: number?): string
	return Loot.chestInfo(floor).materialName
end

-- Имена материалов по id (сумка, окно снаряжения — EchoService.gearState).
Loot.MaterialNames = {}
for _, info in pairs(CHEST_INFO) do
	Loot.MaterialNames[info.material] = info.materialName
end

-- Класс оружия: из шаблона (class), посохи без шаблона — маг, остальное — воин.
function Loot.weaponClass(weapon): string
	if not weapon then
		return "warrior"
	end
	local template = weapon.id and Loot.template(weapon.id)
	if template and template.class then
		return template.class
	end
	return weapon.typeId == "staff" and "mage" or "warrior"
end

local function poolFor(rarityId: string, floor: number?, className: string?)
	local list = {}
	local wanted = className == "mage" and "mage" or "warrior"
	for _, weapon in ipairs(Loot.Weapons) do
		if weapon.rarity == rarityId and (weapon.floor or 1) == (floor or 1) and (weapon.class or "warrior") == wanted then
			table.insert(list, weapon)
		end
	end
	return list
end

-- Веса редкостей сундука этажа для класса (маг — свои, остальным — по этажу).
-- Общие для броска и для витрины лута во Вратах (Config.ChestPreview).
function Loot.chestWeights(floor: number?, className: string?)
	local byClass = className and Loot.ChestWeightsByClass[className]
	return (byClass and (byClass[floor or 1] or byClass[1])) or Loot.ChestWeightsByFloor[floor or 1] or Loot.ChestWeights
end

-- Пул оружия, из которого сундук этажа выдаёт предмет выбранной редкости:
-- нет такой редкости — обычное этажа, нет и его — этажи ниже.
function Loot.chestPool(rarityId: string, floor: number?, className: string?)
	local pool = poolFor(rarityId, floor, className)
	if #pool == 0 then
		pool = poolFor("common", floor, className)
	end
	local lower = (floor or 1) - 1
	while #pool == 0 and lower >= 1 do
		pool = poolFor(rarityId, lower, className)
		if #pool == 0 then
			pool = poolFor("common", lower, className)
		end
		lower -= 1
	end
	return pool
end

function Loot.rollRarity(chestsOpened: number, random, floor: number?, className: string?)
	local rng = random or Random.new()
	local weights = Loot.chestWeights(floor, className)
	-- Первые два сундука аккаунта — всегда обычное.
	if (chestsOpened or 0) < Loot.Chest.firstChestsCommon then
		return "common"
	end

	local total = 0
	for _, rarityId in ipairs(Rarities.order) do
		local weight = weights[rarityId]
		if weight then
			total += weight
		end
	end
	if total <= 0 then
		return "common"
	end

	local roll = rng:NextNumber() * total
	local cumulative = 0
	for _, rarityId in ipairs(Rarities.order) do
		local weight = weights[rarityId]
		if weight then
			cumulative += weight
			if roll <= cumulative then
				return rarityId
			end
		end
	end
	return "common"
end

-- Шаблон оружия по id (rusty_sword, vortex_blade, …).
function Loot.template(id: string?)
	if not id then
		return nil
	end
	for _, weapon in ipairs(Loot.Weapons) do
		if weapon.id == id then
			return weapon
		end
	end
	return nil
end

-- Способность и пассивка предмета. Берём из шаблона: у старых сохранений в
-- профиле записаны прежние способности (whirl/sunder) — шаблон их заменяет.
function Loot.abilityOf(weapon)
	if not weapon then
		return nil, nil
	end
	local template = Loot.template(weapon.id)
	local abilityId, passiveId
	if template then
		abilityId, passiveId = template.ability, template.passive
	else
		abilityId, passiveId = weapon.ability, weapon.passive
	end
	return abilityId and Loot.Abilities[abilityId] or nil, passiveId and Loot.Passives[passiveId] or nil
end

-- Редкость сундука с гарантией (Config.FloorN.Chests[вид]: minRarity, epicChance).
-- Сундуки ответвлений, тайников и мини-боссов дают оружие «редкое и выше»,
-- epicChance — шанс поднять его до эпического. Касается только оружия:
-- броня бросается отдельно и честно (решение Артёма 06.11.2026).
function Loot.applyTier(rarityId: string, tier, rng): string
	if type(tier) ~= "table" then
		return rarityId
	end
	if tier.epicChance and rng:NextNumber() < tier.epicChance and not Rarities.atLeast(rarityId, "epic") then
		rarityId = "epic"
	end
	if tier.minRarity and Rarities.get(tier.minRarity) and not Rarities.atLeast(rarityId, tier.minRarity) then
		rarityId = tier.minRarity
	end
	return rarityId
end

-- className — класс игрока ("warrior" | "mage"): из чьего пула оружие.
-- tier — гарантия сундука (см. Loot.applyTier), nil — обычный бросок.
function Loot.rollWeapon(chestsOpened: number, random, floor: number?, className: string?, tier)
	local rng = random or Random.new()
	local rarityId = Loot.rollRarity(chestsOpened, rng, floor, className)
	-- Первые сундуки аккаунта остаются обычными: гарантия начинается после них.
	if (chestsOpened or 0) >= Loot.Chest.firstChestsCommon then
		rarityId = Loot.applyTier(rarityId, tier, rng)
	end
	local pool = Loot.chestPool(rarityId, floor, className)
	local template = pool[rng:NextInteger(1, #pool)]

	return {
		kind = "weapon",
		id = template.id,
		name = template.name,
		typeId = template.typeId,
		rarityId = template.rarity,
		ability = template.ability,
		passive = template.passive,
		damageBonus = template.damageBonus,
		cooldownReduction = template.cooldownReduction,
		sharpening = 0,
		source = "chest",
	}
end

function Loot.rollChest(chestsOpened: number, random, floor: number?, className: string?, tier)
	local rng = random or Random.new()
	local weapon = Loot.rollWeapon(chestsOpened, rng, floor, className, tier)
	local info = Loot.chestInfo(floor)
	local materialRange = info.materialRange or Loot.Chest.iron
	local materialCount = rng:NextInteger(materialRange[1], materialRange[2])
	return {
		weapon = weapon,
		gold = info.gold or Loot.Chest.gold,
		-- iron — старое поле карточки находки (этаж 1), на других этажах пусто.
		iron = info.material == Loot.IronMaterial and materialCount or nil,
		materialId = info.material,
		materialName = info.materialName,
		materialCount = materialCount,
	}
end

-- Новый предмет оружия из шаблона (стартовый посох при смене класса, отладка).
function Loot.newWeapon(id: string, source: string?)
	local template = Loot.template(id)
	if not template then
		return nil
	end
	return {
		kind = "weapon",
		id = template.id,
		name = template.name,
		typeId = template.typeId,
		rarityId = template.rarity,
		ability = template.ability,
		passive = template.passive,
		damageBonus = template.damageBonus,
		cooldownReduction = template.cooldownReduction,
		sharpening = 0,
		level = 1,
		echoes = 0,
		source = source or "starter",
	}
end

-- Душа босса: первая гарантирована обычная, дальше по весам.
function Loot.rollBossSoul(bossKills: number, random)
	if (bossKills or 0) <= 0 then
		return Loot.BossSouls.common
	end
	local rng = random or Random.new()
	local total = 0
	for _, weight in pairs(Loot.BossSoulWeights) do
		total += weight
	end
	local roll = rng:NextNumber() * total
	local cumulative = 0
	for _, rarityId in ipairs({ "common", "epic", "legendary" }) do
		cumulative += Loot.BossSoulWeights[rarityId]
		if roll <= cumulative then
			return Loot.BossSouls[rarityId]
		end
	end
	return Loot.BossSouls.common
end

return Loot
