--!nonstrict
-- Armor
-- Броня героя (переделка 06.11.2026, решения Артёма):
--   * комплект — ОДИН предмет: шлем и доспех (у мага шляпа и накидка) идут
--     вместе, отдельных слотов больше нет; статы — на весь комплект;
--   * у эпических и легендарных комплектов — пассивка (бывший «бонус набора»);
--   * сундук этажа всегда кладёт оружие И броню, редкость брони — свой
--     отдельный бросок по весам этажа (секретной брони нет);
--   * ★ брони поднимает кузнец: нужна повторка (эхо, как у оружия) и материал
--     этажа, с которого броня (Armor.MaterialCost).
-- Воин — комплекты этажей 1–5, маг — Хронисты этажа 1 и свои комплекты 2–5
-- (Config/ArmorFloors). Ассасин своей брони не имеет.
-- Только числа и облик — логика в ServerScriptService/Systems/ArmorService,
-- внешний вид собирает AppearanceService по полю style / мешам.
--
-- Защита комплекта:
--   * armor  — плоская броня, в формулу Combat.Armor.mitigate (урон / (1 + 0.06 × броня));
--   * health — плоское здоровье, растёт с ★: × Echo.armorHpMultiplier;
--   * снижение урона — от редкости и ★ (Echo.damageReduction), целиком
--     (раньше делилось на два слота по 0,5);
--   * у мага ещё mana (растёт с ★ как здоровье) и manaRegen.
-- Общий потолок снижения от брони и пассивки — 30%.
--
-- Цвета — только из Palette (правило проекта).

local Palette = require(script.Parent.Palette)
local Rarities = require(script.Parent.Rarities)
local ArmorFloors = require(script.Parent.ArmorFloors)

local Armor = {}

local Env = Palette.Env
local Floor1 = Palette.Floors[1].colors

-- Классы, у которых есть броня.
Armor.Classes = { warrior = true, mage = true }

-- Как называется комплект в окне. helm/armor — подписи двух клеток куклы:
-- комплект занимает обе сразу.
Armor.SlotNames = {
	warrior = { set = "Доспехи", helm = "Шлем", armor = "Доспех", hint = "Доспехи выпадают из каждого сундука этажа вместе с оружием." },
	mage = { set = "Облачение", helm = "Шляпа", armor = "Накидка", hint = "Облачения выпадают из каждого сундука этажа вместе с посохом." },
}

-- Один слот — комплект целиком. Старые id слотов helm/armor остались только
-- как клетки куклы в окне (обе показывают надетый комплект).
Armor.Slot = "set"
Armor.Slots = { { id = "set", name = "Комплект", icon = "armor" } }
Armor.DollSlots = { "helm", "armor" }

-- Совместимость: раньше снижение делилось на два слота.
Armor.ReductionShare = 1
-- Общий потолок снижения урона от брони и пассивки.
Armor.ReductionCap = 0.3

-- Сундук: броня всегда. Редкость — свой бросок (Armor.rollRarity).
Armor.ChestChance = { [1] = 1, [2] = 1, [3] = 1, [4] = 1, [5] = 1 }
Armor.BossChestGuaranteed = true
-- Редкости, которых у брони нет: бросок на них перекидывается в веса без них.
Armor.NoRarity = { secret = true, mythic = true }

-- Стартовый комплект по классу (новый профиль, смена класса).
Armor.StarterSet = "wanderer"
Armor.StarterSets = { warrior = "wanderer", mage = "novice" }

-- ===== Облик комплектов =====
-- steel/steelDark — металл, trim — отделка, cloth/clothLight — ткань
-- (плащ, шарф, табард), leather — ремни и сапоги, eye — глаза в визоре.
-- accent — яркие детали, sigil — пиксельный знак комплекта.
-- helm: "open" | "kettle" | "crested" | "horned" | "crown"
-- chest: "plate" | "riveted" | "tabard" | "spiked" | "keyhole"
-- cape: "tattered" | "long" | "none" | "short"
Armor.Styles = {
	wanderer = {
		steel = Env.ironLight:Lerp(Env.bone, 0.35),
		steelDark = Env.iron:Lerp(Env.ironLight, 0.4),
		trim = Env.gold,
		cloth = Palette.UI.panel:Lerp(Env.stoneDeep, 0.4),
		clothLight = Env.bone:Lerp(Env.sandLight, 0.3),
		leather = Env.woodDark,
		leatherLight = Env.wood,
		eye = Palette.Memory,
		accent = Env.gold,
		sigil = "memory",
		helm = "open",
		chest = "plate",
		cape = "tattered",
		pauldron = 1.0,
	},
	rusty_guard = {
		steel = Env.ironLight:Lerp(Env.rust, 0.35),
		steelDark = Env.iron:Lerp(Env.rustDark, 0.45),
		trim = Env.rust,
		cloth = Env.clothDark,
		clothLight = Env.cloth:Lerp(Env.sand, 0.25),
		leather = Env.woodDark,
		leatherLight = Env.wood,
		eye = Palette.Memory,
		accent = Env.ember,
		sigil = "anvil",
		helm = "kettle",
		chest = "riveted",
		cape = "short",
		pauldron = 1.1,
	},
	gate_guard = {
		steel = Env.ironLight:Lerp(Env.bone, 0.2),
		steelDark = Env.iron,
		trim = Floor1[3],
		cloth = Env.clothDark,
		clothLight = Env.cloth,
		leather = Env.woodDark,
		leatherLight = Env.woodLight,
		eye = Palette.Memory,
		accent = Floor1[3],
		sigil = "gate",
		helm = "crested",
		chest = "tabard",
		cape = "long",
		pauldron = 1.2,
	},
	shade_knight = {
		steel = Env.void:Lerp(Env.stoneDeep, 0.55),
		steelDark = Env.void,
		trim = Env.ironLight:Lerp(Env.bone, 0.25),
		cloth = Env.void,
		clothLight = Env.stoneDeep,
		leather = Env.void:Lerp(Env.woodDark, 0.5),
		leatherLight = Env.woodDark,
		eye = Palette.Memory,
		accent = Palette.Memory,
		sigil = "shard",
		helm = "horned",
		chest = "spiked",
		cape = "tattered",
		pauldron = 1.3,
	},
	gatekeeper = {
		steel = Env.stone:Lerp(Env.bone, 0.15),
		steelDark = Env.stoneDark,
		trim = Env.gold,
		cloth = Env.clothDark,
		clothLight = Env.gold:Lerp(Env.bone, 0.35),
		leather = Env.woodDark,
		leatherLight = Env.wood,
		eye = Palette.Memory,
		accent = Env.gold,
		sigil = "key",
		helm = "crown",
		chest = "keyhole",
		cape = "long",
		pauldron = 1.4,
	},
}

-- Облик мага из Part'ов (запасной, пока меши не импортированы):
-- hat — форма шляпы: "soft" | "tall" | "star" | "ragged" | "archive";
-- hatHeight — высота тульи в долях головы; capeLength — длина плаща в долях торса.
local Mage = Palette.Mage
local function mageStyle(id: string, hat: string, hatHeight: number, capeLength: number, eye: Color3, glow: Color3?)
	local c = Mage[id]
	return {
		mage = true,
		hat = hat,
		hatHeight = hatHeight,
		capeLength = capeLength,
		hatColor = c.hat,
		band = c.band,
		mantle = c.mantle,
		capeColor = c.cape,
		trim = c.trim,
		eye = eye,
		glow = glow,
		-- поля, которые читает общий код облика воина
		cloth = c.mantle,
		clothLight = c.cape,
		leather = Env.woodDark,
		leatherLight = Env.wood,
		steelDark = c.band,
		accent = c.trim,
	}
end
Armor.Styles.novice = mageStyle("novice", "soft", 0.75, 0.9, Palette.Memory)
Armor.Styles.reader = mageStyle("reader", "tall", 1.1, 1.2, Palette.Memory)
Armor.Styles.chronicler = mageStyle("chronicler", "star", 1.0, 1.75, Palette.Memory, Palette.Memory)
Armor.Styles.oblivion = mageStyle("oblivion", "ragged", 0.85, 1.75, Mage.violet, Mage.violet)
Armor.Styles.archivist = mageStyle("archivist", "archive", 1.3, 1.75, Palette.Memory, Palette.Memory)


-- ===== Комплекты этажа 1 =====
-- Статы — сумма прежних шлема и доспеха; плоский «бонус набора» обычных и
-- редких вошёл в статы, условные бонусы эпических и легендарных стали пассивкой.
Armor.Sets = {
	wanderer = {
		id = "wanderer", name = "Странника", title = "Доспехи странника", rarity = "common", floor = 1,
		armor = 1, health = 10,
		pieces = { helm = "Шлем странника", armor = "Доспех странника" },
	},
	rusty_guard = {
		id = "rusty_guard", name = "Ржавого стража", title = "Доспехи ржавого стража", rarity = "common", floor = 1,
		armor = 4, health = 13,
		pieces = { helm = "Ржавый шишак", armor = "Ржавые латы" },
	},
	gate_guard = {
		id = "gate_guard", name = "Стражи ворот", title = "Доспехи стражи ворот", rarity = "rare", floor = 1,
		armor = 6, health = 18,
		pieces = { helm = "Шлем стражи ворот", armor = "Кираса стражи ворот" },
	},
	shade_knight = {
		id = "shade_knight", name = "Теневого рыцаря", title = "Доспехи теневого рыцаря", rarity = "epic", floor = 1,
		armor = 5, health = 22,
		pieces = { helm = "Рогатый шлем тени", armor = "Латы теневого рыцаря" },
		passive = { kind = "afterDodge", reduction = 0.2, duration = 0.8, name = "Тень",
			description = "0,8 с после рывка −20% входящего урона" },
	},
	gatekeeper = {
		id = "gatekeeper", name = "Привратника", title = "Доспехи Привратника", rarity = "legendary", floor = 1,
		armor = 6, health = 26,
		pieces = { helm = "Венец Привратника", armor = "Засов Привратника" },
		passive = { kind = "steadfast", threshold = 0.6, reduction = 0.08, name = "Засов",
			description = "Пока здоровье выше 60%, −8% входящего урона" },
	},

	-- Маг, этаж 1 — Хронисты (меши: tools/mage-armor, MageArmorMeshData).
	novice = {
		id = "novice", class = "mage", name = "Послушника", title = "Облачение послушника", rarity = "common", floor = 1,
		armor = 0, health = 7, mana = 16, manaRegen = 0.2,
		pieces = { helm = "Шляпа послушника", armor = "Накидка послушника" },
	},
	reader = {
		id = "reader", class = "mage", name = "Чтеца", title = "Облачение чтеца", rarity = "common", floor = 1,
		armor = 1, health = 9, mana = 32, manaRegen = 0.3,
		pieces = { helm = "Шляпа чтеца", armor = "Накидка чтеца" },
	},
	chronicler = {
		id = "chronicler", class = "mage", name = "Хрониста", title = "Облачение Хрониста", rarity = "rare", floor = 1,
		armor = 2, health = 12, mana = 34, manaRegen = 1.6,
		pieces = { helm = "Звёздная шляпа Хрониста", armor = "Накидка Хрониста" },
	},
	oblivion = {
		id = "oblivion", class = "mage", name = "Забвения", title = "Облачение Забвения", rarity = "epic", floor = 1,
		armor = 3, health = 15, mana = 42, manaRegen = 0.8,
		pieces = { helm = "Шляпа Забвения", armor = "Рваная накидка Забвения" },
		passive = { kind = "manaOnDodge", amount = 12, name = "Пустота",
			description = "Рывок возвращает 12 маны" },
	},
	archivist = {
		id = "archivist", class = "mage", name = "Архивариуса", title = "Облачение Архивариуса", rarity = "legendary", floor = 1,
		armor = 4, health = 18, mana = 60, manaRegen = 1.4,
		pieces = { helm = "Венец-шляпа Архивариуса", armor = "Мантия Архивариуса" },
		passive = { kind = "manaWard", threshold = 0.5, reduction = 0.08, name = "Каталог",
			description = "Пока маны больше половины, −8% входящего урона" },
	},
}

Armor.SetOrderByClass = {
	warrior = { "wanderer", "rusty_guard", "gate_guard", "shade_knight", "gatekeeper" },
	mage = { "novice", "reader", "chronicler", "oblivion", "archivist" },
}

-- Этажи 2–5 (Config/ArmorFloors): данные + облик-заглушка до мешей.
local function addFloorSets(list, className)
	for _, set in ipairs(list) do
		assert(Armor.Sets[set.id] == nil, "Armor: повтор id комплекта " .. set.id)
		if className ~= "warrior" then
			set.class = className
		end
		Armor.Sets[set.id] = set
		if set.style then
			Armor.Styles[set.id] = set.style
		end
		table.insert(Armor.SetOrderByClass[className], set.id)
	end
end
addFloorSets(ArmorFloors.Warrior, "warrior")
addFloorSets(ArmorFloors.Mage, "mage")
Armor.SetOrder = Armor.SetOrderByClass.warrior

-- ===== Кузнец: ★ брони =====
-- Цена подъёма n → n+1: эхо (повторки) как у оружия (Echo.EchoCost[n]) и
-- материал этажа комплекта (Loot.materialOf(floor)) по этой таблице.
--
-- Доход материала за забег (tools/lua/calc_materials.lua, 06.11.2026):
--   этаж 1 ≈ 50 (68 врагов, 5 сундуков, 2 мини-босса и босс)
--   этаж 2 ≈ 50 (95 врагов, 5 сундуков, босс)
--   этаж 3 ≈ 63 (99 врагов, 5 сундуков, мини-босс и босс)
--   этаж 4 ≈ 37 (63 врага, 3 сундука, босс; мини-босс добавит ≈ +10)
--   этаж 5 ≈ 43 (58 врагов, 3 сундука, мини-босс и босс)
-- Цель — материала на весь потолок ★ комплекта:
--   обычный ≈ 1 забег (50), редкий ≈ 2 (110), эпический ≈ 4 (200), легендарный ≈ 7 (350).
-- Первые ★ упираются в материал (эха на них нужно 1–2), поздние — в эхо
-- (повторки той же редкости); материал копится, пока ждёшь повторку.
Armor.MaterialCost = {
	--          ★1→2 2→3 3→4 4→5 5→6 6→7 7→8   всего
	common = { 6, 10, 14, 20 }, --                50
	rare = { 8, 14, 20, 28, 40 }, --             110
	epic = { 10, 18, 26, 36, 48, 62 }, --        200
	legendary = { 12, 22, 32, 44, 60, 80, 100 }, -- 350
}
Armor.GoldFee = 0 -- золото кузнецу броня не тратит (решение 06.11.2026)

-- ===== функции =====

-- Совместимость: старые id предметов «<набор>_helm» / «<набор>_armor» → id набора.
function Armor.parse(itemId: string?)
	if type(itemId) ~= "string" then
		return nil
	end
	if Armor.Sets[itemId] then
		return itemId
	end
	local setId, slotId = itemId:match("^(.+)_(%a+)$")
	if setId and Armor.Sets[setId] and (slotId == "helm" or slotId == "armor") then
		return setId
	end
	return nil
end

-- id предмета = id комплекта (slotId оставлен для старых вызовов).
function Armor.itemId(setId: string, _slotId: string?): string
	return setId
end

-- Шаблон предмета: { id, setId, slot, class, name, rarity, floor, armor, health, mana, manaRegen, passive }.
function Armor.template(itemId: string?)
	local setId = Armor.parse(itemId)
	if not setId then
		return nil
	end
	local set = Armor.Sets[setId]
	return {
		id = setId,
		setId = setId,
		slot = Armor.Slot,
		class = set.class or "warrior",
		name = set.title or set.name,
		setName = set.name,
		rarity = set.rarity,
		floor = set.floor or 1,
		armor = set.armor or 0,
		health = set.health or 0,
		mana = set.mana or 0,
		manaRegen = set.manaRegen or 0,
		passive = set.passive,
		pieces = set.pieces,
	}
end

-- Новый предмет для профиля (slotId не нужен — оставлен для старых вызовов).
function Armor.newItem(setId: string, _slotId: string?, source: string?)
	local template = Armor.template(setId)
	if not template then
		return nil
	end
	return {
		kind = "armor",
		id = template.id,
		setId = template.setId,
		slot = Armor.Slot,
		name = template.name,
		rarityId = template.rarity,
		level = 1,
		echoes = 0,
		source = source or "chest",
	}
end

function Armor.classOf(setId: string?): string?
	local set = setId and Armor.Sets[setId]
	return set and (set.class or "warrior") or nil
end

function Armor.floorOf(setId: string?): number
	local set = setId and Armor.Sets[setId]
	return set and set.floor or 1
end

function Armor.starterFor(className: string?): string
	return Armor.StarterSets[className or "warrior"] or Armor.StarterSet
end

function Armor.slotName(slotId: string?, className: string?): string
	local names = Armor.SlotNames[className or "warrior"] or Armor.SlotNames.warrior
	return names[slotId or "set"] or names.set
end

function Armor.canWear(className: string?, setId: string?): boolean
	local class = className or "warrior"
	if Armor.Classes[class] ~= true then
		return false
	end
	return setId == nil or Armor.classOf(setId) == class
end

local starters = {}
for _, setId in pairs(Armor.StarterSets) do
	starters[setId] = true
end

-- Комплекты этажа нужной редкости для класса: { {setId}, ... }.
-- Стартовые в сундуках не попадаются. Элемент — таблица {setId} (как раньше
-- {setId, slotId}), чтобы старые вызовы pick[1] продолжали работать.
function Armor.pool(rarityId: string, floor: number?, className: string?)
	local list = {}
	local order = Armor.SetOrderByClass[className or "warrior"] or Armor.SetOrder
	for _, setId in ipairs(order) do
		local set = Armor.Sets[setId]
		if set.rarity == rarityId and (set.floor or 1) == (floor or 1) and not starters[setId] then
			table.insert(list, { setId })
		end
	end
	return list
end

-- Пул сундука: редкость этажа → та же редкость этажом ниже → … → лучшая
-- доступная ниже по редкости.
function Armor.chestPool(rarityId: string, floor: number?, className: string?)
	for f = floor or 1, 1, -1 do
		local pool = Armor.pool(rarityId, f, className)
		if #pool > 0 then
			return pool
		end
	end
	local rarity = Rarities.get(rarityId)
	for index = (rarity and rarity.index or 1) - 1, 1, -1 do
		local pool = Armor.pool(Rarities.order[index], floor, className)
		if #pool > 0 then
			return pool
		end
	end
	return {}
end

-- Веса редкости брони: веса сундука этажа (как у оружия) без редкостей,
-- которых у брони нет. weights — Loot.chestWeights(floor, class).
function Armor.rarityWeights(weights)
	local out = {}
	for rarityId, weight in pairs(weights or {}) do
		if not Armor.NoRarity[rarityId] then
			out[rarityId] = weight
		end
	end
	return out
end

-- Отдельный бросок редкости брони. chestsOpened < firstCommon → обычная
-- (как у оружия: первые сундуки аккаунта мягкие).
function Armor.rollRarity(weights, rng, chestsOpened: number?, firstCommon: number?): string
	if (chestsOpened or 0) < (firstCommon or 0) then
		return "common"
	end
	local list = Armor.rarityWeights(weights)
	local total = 0
	for _, rarityId in ipairs(Rarities.order) do
		total += list[rarityId] or 0
	end
	if total <= 0 then
		return "common"
	end
	local roll = rng:NextNumber() * total
	for _, rarityId in ipairs(Rarities.order) do
		local w = list[rarityId]
		if w then
			roll -= w
			if roll <= 0 then
				return rarityId
			end
		end
	end
	return "common"
end

-- Материалы на подъём ★ level → level+1 (nil — потолок или нет таблицы).
function Armor.materialCost(level: number, rarityId: string): number?
	local row = Armor.MaterialCost[rarityId]
	return row and row[level] or nil
end

-- Всего материала от ★1 до target.
function Armor.totalMaterials(rarityId: string, target: number): number
	local sum = 0
	for n = 1, target - 1 do
		sum += Armor.materialCost(n, rarityId) or 0
	end
	return sum
end

return Armor
