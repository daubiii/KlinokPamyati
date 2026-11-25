--!nonstrict
-- test_weapons345.lua — оружие этажей 3–5 (Охота, Горн, Летопись):
--   * у оружия этажей есть способность и пассивка в Loot;
--   * иконки способностей есть в AbilityIcons345 (и запасная — в UiAtlas.Icons);
--   * все звуки клиента есть в Sfx (с вариантами), у слоёв есть id;
--   * все пути FX клиента есть в FxWeapons345.Templates;
--   * каждая фаза сервера имеет обработчик клиента, у способностей есть анимация.
-- Запуск: node tools/check-weapons345.js (SCAN — результат сканирования исходников).
-- Без сканера (node tools/run-luau.js …) проверяются только данные.
local SCAN = nil

local Shared = (_G :: any).KlinokShared or game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Loot = require(Shared.Config.Loot)
local Sfx = require(Shared.Config.Sfx)
local UiAtlas = require(Shared.Config.UiAtlas)
local Icons = require(Shared.Config.AbilityIcons345)
local IconsMage = require(Shared.Config.AbilityIconsMage)
local Fx = require(Shared.Fx.FxWeapons345)

local out = {}
local failures = 0
local function check(label, ok, detail)
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %s%s"):format(ok and "OK  " or "FAIL", label, detail and ("  — " .. detail) or "")
end
local function list(t)
	table.sort(t)
	return table.concat(t, ", ")
end

-- 1. Оружие → способности и пассивки
out[#out + 1] = "Оружие этажей 3–5:"
local abilities, perFloor, bad = {}, { [3] = 0, [4] = 0, [5] = 0 }, {}
for _, weapon in ipairs(Loot.Weapons) do
	if weapon.floor and weapon.floor >= 3 then
		perFloor[weapon.floor] += 1
		-- простое оружие (обычное/редкое) — без способности
		if weapon.ability and not Loot.Abilities[weapon.ability] then
			table.insert(bad, weapon.id .. ".ability=" .. tostring(weapon.ability))
		elseif weapon.ability then
			abilities[weapon.ability] = true
		end
		if weapon.passive and not Loot.Passives[weapon.passive] then
			table.insert(bad, weapon.id .. ".passive=" .. weapon.passive)
		end
	end
end
check(("оружие: этаж 3 — %d, 4 — %d, 5 — %d"):format(perFloor[3], perFloor[4], perFloor[5]), perFloor[3] > 0 and perFloor[4] > 0 and perFloor[5] > 0)
check("способности и пассивки оружия существуют", #bad == 0, #bad > 0 and list(bad) or nil)
local abilityIds, warriorCount = {}, 0
for id in pairs(abilities) do
	table.insert(abilityIds, id)
	if Loot.Abilities[id].school ~= "mage" then
		warriorCount += 1
	end
end
check(("%d способностей воина этажей 3–5"):format(warriorCount), warriorCount == 16, list(abilityIds))

-- 2. Иконки
out[#out + 1] = "Иконки:"
bad = {}
for _, id in ipairs(abilityIds) do
	local icon = Loot.Abilities[id].icon
	local set = Loot.Abilities[id].school == "mage" and IconsMage or Icons
	if not icon or not set.rects[icon] then
		table.insert(bad, id .. ": нет rect " .. tostring(icon))
	elseif not UiAtlas.Icons[set.fallback[icon] or ""] then
		table.insert(bad, id .. ": запасная " .. tostring(set.fallback[icon]))
	end
end
check("у каждой способности есть иконка и запасная", #bad == 0, #bad > 0 and list(bad) or nil)
local seenRect, overlap = {}, {}
for name, r in pairs(Icons.rects) do
	local key = r.x .. ":" .. r.y
	if seenRect[key] then
		table.insert(overlap, name .. "/" .. seenRect[key])
	end
	seenRect[key] = name
	if r.x + r.w > 90 or r.y + r.h > 90 then
		table.insert(overlap, name .. " за краем атласа")
	end
end
check("клетки атласа 90x90 не пересекаются", #overlap == 0, #overlap > 0 and list(overlap) or nil)

-- 3. Звуки
out[#out + 1] = "Звуки:"
local function layersOk(layers)
	if type(layers) ~= "table" or #layers == 0 then
		return false
	end
	for _, l in ipairs(layers) do
		if type(l.id) ~= "string" or not (l.id:match("^rbxassetid://%d+$") or l.id:match("^rbxasset://")) or not (l.volume > 0) then
			return false
		end
	end
	return true
end
bad = {}
local pickBad = {}
for name, options in pairs(Sfx.candidates) do
	local pick = Sfx.picked[name] or 1
	if not options[pick] then
		table.insert(pickBad, name .. "#" .. pick)
	end
	for index, option in ipairs(options) do
		if not layersOk(option.layers) then
			table.insert(pickBad, name .. "/" .. index)
		end
	end
end
check("варианты звуков и выбранные номера корректны", #pickBad == 0, #pickBad > 0 and list(pickBad) or nil)

-- 4–6. Сверка с исходниками (только через check-weapons345.js)
if SCAN then
	bad = {}
	for _, name in ipairs(SCAN.sounds) do
		if not layersOk(Sfx.layers(name)) then
			table.insert(bad, name)
		end
	end
	check(("%d звуков клиента есть в Sfx"):format(#SCAN.sounds), #bad == 0, #bad > 0 and list(bad) or nil)

	out[#out + 1] = "FX:"
	bad = {}
	for _, p in ipairs(SCAN.fx) do
		if not Fx.Templates[p] then
			table.insert(bad, p)
		end
	end
	check(("%d путей FX клиента есть в FxWeapons345.Templates"):format(#SCAN.fx), #bad == 0, #bad > 0 and list(bad) or nil)

	out[#out + 1] = "Сервер ↔ клиент:"
	for _, kind in ipairs({ "hunt", "forge", "chron" }) do
		local handlers, phases, missing, unused = {}, {}, {}, {}
		for _, h in ipairs(SCAN.handlers[kind]) do
			handlers[h] = true
		end
		for _, p in ipairs(SCAN.phases[kind]) do
			phases[p] = true
			if not handlers[p] then
				table.insert(missing, p)
			end
		end
		for h in pairs(handlers) do
			if not phases[h] then
				table.insert(unused, h)
			end
		end
		check(("%s: %d фаз сервера имеют обработчик"):format(kind, #SCAN.phases[kind]), #missing == 0, #missing > 0 and ("нет: " .. list(missing)) or nil)
		check(("%s: обработчики клиента вызываются сервером"):format(kind), #unused == 0, #unused > 0 and ("лишние: " .. list(unused)) or nil)
	end

	out[#out + 1] = "Анимации:"
	local actions = {}
	for _, a in ipairs(SCAN.actions) do
		actions[a] = true
	end
	bad = {}
	for _, id in ipairs(abilityIds) do
		local animName = SCAN.anims[id]
		if not animName then
			table.insert(bad, id .. ": нет в AbilityAnimations")
		elseif not actions[animName] then
			table.insert(bad, id .. ": нет A." .. animName)
		end
	end
	check("у каждой способности есть анимация в PlayerAnimWeapons", #bad == 0, #bad > 0 and list(bad) or nil)
else
	out[#out + 1] = "  (сверка с исходниками пропущена: запуск без tools/check-weapons345.js)"
end

out[#out + 1] = ("ИТОГО: %s"):format(failures == 0 and "все проверки пройдены" or (failures .. " провалов"))
return table.concat(out, "\n")
