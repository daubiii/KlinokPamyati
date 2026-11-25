--!nonstrict
-- ArmorMigrate — перевод брони в профиле из формата 1 (слоты шлема и доспеха)
-- в формат 2 (комплект одним предметом, 06.11.2026). Чистая функция над
-- таблицей профиля: её зовёт ArmorService.ensureProfile, проверяет
-- tools/lua/test_armor_sets.lua без Studio.
--
-- Правила: каждая старая часть становится комплектом своего набора;
-- шлем и доспех одного набора сливаются в один комплект (★ — больший,
-- эхо — сумма). Надетым остаётся набор надетого доспеха (корпус виднее),
-- если доспеха нет — набор шлема. Запас других классов — так же.

local Armor = require(script.Parent.Parent.Config.Armor)
local Echo = require(script.Parent.Parent.Config.Echo)

local ArmorMigrate = {}

-- Слить предмет b в a (одинаковый комплект из старых шлема и доспеха).
local function merge(a, b)
	a.level = math.max(a.level or 1, b.level or 1)
	a.echoes = (a.echoes or 0) + (b.echoes or 0)
	return a
end

-- Формат 1 (слоты helm/armor) → формат 2 (комплект).
function ArmorMigrate.run(profile)
	if profile.armorFormat == 2 then
		return
	end
	local equippedOld = profile.armorEquipped or {}
	local stashOld = profile.armorStash or {}
	local pool = {} -- [setId] = item
	local order = {}
	local function take(old)
		if type(old) ~= "table" then
			return nil
		end
		local setId = Armor.parse(old.id) or Armor.parse(old.setId)
		if not setId then
			return nil
		end
		local item = Armor.newItem(setId, nil, old.source or "migrated")
		item.level = old.level or 1
		item.echoes = old.echoes or 0
		item.level = math.clamp(item.level or 1, 1, Echo.maxLevel(item.rarityId or "common"))
		local existing = pool[setId]
		if existing then
			merge(existing, item)
			return existing
		end
		pool[setId] = item
		table.insert(order, setId)
		return item
	end
	-- Надетое: комплект по доспеху (корпус виднее), иначе по шлему.
	local wornChest = take(equippedOld.armor)
	local wornHelm = take(equippedOld.helm)
	local worn = wornChest or wornHelm or (equippedOld.set and take(equippedOld.set))
	local stash = {}
	for className, slots in pairs(stashOld) do
		if type(slots) == "table" then
			local a = take(slots.armor)
			local h = take(slots.helm)
			local s = slots.set and take(slots.set)
			local kept = a or h or s or nil
			-- Тот же комплект уже надет (слился с надетым) — в запас не кладём.
			if kept ~= worn then
				stash[className] = kept
			end
		end
	end
	for _, old in ipairs(profile.armorItems or {}) do
		take(old)
	end
	local items = {}
	local used = {}
	if worn then
		used[worn] = true
	end
	for _, item in pairs(stash) do
		used[item] = true
	end
	for _, setId in ipairs(order) do
		local item = pool[setId]
		if not used[item] then
			table.insert(items, item)
		end
	end
	profile.armorEquipped = { [Armor.Slot] = worn }
	profile.armorStash = stash
	profile.armorItems = items
	profile.armorFormat = 2
end

return ArmorMigrate
