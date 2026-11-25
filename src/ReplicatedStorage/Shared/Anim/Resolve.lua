--!nonstrict
-- Anim/Resolve
-- Превращает таблицы анимаций врагов (Anim/Base, Guard, Shade…) в плоский
-- формат для Util/Anim.sample. Раскрывает:
--   inherit = "Base.Walk"  — взять кадры чужой анимации;
--   amp                    — умножить углы и LTp унаследованных кадров;
--   speed                  — ускорить по времени (длина и маркеры делятся);
--   override               — во всех кадрах заменить суставы постоянной позой
--                            (после amp: оружие держится одинаково);
--   from = "pose"          — первый кадр берётся из текущей позы: флаг
--                            fromPose, значения подставляет EnemyAnimator.
--
-- Плоский кадр: { t, ease, RUA_x, RUA_y, RUA_z, …, LTp_x, LTp_y, LTp_z }.
-- Сустава нет в кадре — он равен нулю (поза покоя R15), как в Anim.sample.
--
-- Результат на анимацию:
--   { name, set, length, loop, priority, fromPose, frames, markers }
-- markers отсортированы по времени: { { t, name }, … }.

local Anim = require(script.Parent.Parent.Util.Anim)

local Resolve = {}

Resolve.JOINTS = { "LT", "UT", "HD", "RUA", "RLA", "RH", "LUA", "LLA", "LH", "RUL", "RLL", "RF", "LUL", "LLL", "LF" }
Resolve.POSITION = "LTp"

-- Плоские имена полей: FIELDS.RUA = { "RUA_x", "RUA_y", "RUA_z" }.
Resolve.FIELDS = {}
Resolve.KEYS = {}
do
	local codes = table.clone(Resolve.JOINTS)
	table.insert(codes, Resolve.POSITION)
	for _, code in ipairs(codes) do
		local fields = { code .. "_x", code .. "_y", code .. "_z" }
		Resolve.FIELDS[code] = fields
		for _, field in ipairs(fields) do
			table.insert(Resolve.KEYS, field)
		end
	end
end
local CODES = {}
for code in pairs(Resolve.FIELDS) do
	table.insert(CODES, code)
end

-- Наборы анимаций (модули рядом) и дополнения к ним.
Resolve.SETS = { "Base", "Guard", "Shade", "Knight", "Archer", "Martyr", "Gatekeeper", "Centurion", "Arbalest",
	"Treant", "Bee", "Drowned", "Gardener", "Ranger", "Rosewarden", -- этаж 2
	"Automaton", "FireSpirit", "SlagThrower", "Smolder", "Founder", -- этаж 4
	"Reader", "SealMage", "WardSeal", "Scribe", "InkBlot", "Warden", "Binder", "Chronicler",
	"Hound", "Beater", "Trapper", "Falconer", "Falcon", "Crossbow", "Torchbearer", "Skinner", "Tanner",
	"BearHunter", "TrophyBear", "PackLeader", "Huntsman" } -- этаж 3
-- Дополнение — имя модуля или список. *Moves — фирменные атаки боссов и
-- сцены появления (Config/BossMoves, Config/BossIntros).
Resolve.EXTRA = {
	Gatekeeper = { "GatekeeperExtra", "GatekeeperMoves" },
	Rosewarden = "RosewardenMoves",
	Huntsman = "HuntsmanMoves",
	Founder = "FounderMoves",
	Chronicler = "ChroniclerMoves",
}

local function extrasOf(setName: string): { string }
	local extra = Resolve.EXTRA[setName]
	if type(extra) == "table" then
		return extra
	end
	return extra and { extra } or {}
end
Resolve.extrasOf = extrasOf
-- Чего нет в наборе врага, берётся из Base (раздел 3.4).
Resolve.FALLBACK = { "Idle", "Walk", "Strafe", "Hit", "Stun", "Death", "Spawn" }

local folder = script.Parent
local rawSets = {}
local resolvedSets = {}

local function rawSet(name: string)
	local cached = rawSets[name]
	if cached == nil then
		local module = folder:FindFirstChild(name)
		cached = module and require(module) or false
		rawSets[name] = cached
	end
	return cached or nil
end

-- Определение анимации из набора (с учётом дополнения).
local function definition(setName: string, animName: string)
	local set = rawSet(setName)
	local def = set and set[animName]
	if def then
		return def
	end
	for _, extraName in ipairs(extrasOf(setName)) do
		local extra = rawSet(extraName)
		if extra and extra[animName] then
			return extra[animName]
		end
	end
	return nil
end

local function parseRef(ref: string)
	local setName, animName = string.match(ref, "^(%w+)%.(%w+)$")
	assert(setName, "Resolve: ссылка должна быть вида Набор.Анимация, а не '" .. tostring(ref) .. "'")
	return setName, animName
end

local function copyTriple(value, scale: number)
	return { (value[1] or 0) * scale, (value[2] or 0) * scale, (value[3] or 0) * scale }
end

-- Раскрыть inherit: вернуть { length, loop, priority, keys, markers } с
-- кадрами в исходном (вложенном) виде.
local function expand(def, depth: number)
	assert(depth < 8, "Resolve: слишком глубокое наследование")
	if not def.inherit then
		return {
			length = def.length,
			loop = def.loop == true,
			priority = def.priority or "Action",
			keys = def.keys,
			markers = def.markers or {},
		}
	end

	local setName, animName = parseRef(def.inherit)
	local parentDef = definition(setName, animName)
	assert(parentDef, "Resolve: нет анимации " .. def.inherit)
	local base = expand(parentDef, depth + 1)
	local amp = def.amp or 1
	local speed = def.speed or 1
	assert(speed > 0, "Resolve: speed должен быть больше нуля")

	local keys = {}
	for _, key in ipairs(base.keys) do
		local copy = { t = key.t / speed, e = key.e, from = key.from }
		for _, code in ipairs(CODES) do
			if key[code] then
				copy[code] = copyTriple(key[code], amp)
			end
		end
		for code, value in pairs(def.override or {}) do
			copy[code] = copyTriple(value, 1)
		end
		table.insert(keys, copy)
	end

	local markers = {}
	for _, marker in ipairs(base.markers) do
		table.insert(markers, { t = marker.t / speed, name = marker.name })
	end

	local loop = base.loop
	if def.loop ~= nil then
		loop = def.loop == true
	end
	return {
		length = def.length or base.length / speed,
		loop = loop,
		priority = def.priority or base.priority,
		keys = keys,
		markers = markers,
	}
end

local function flatten(key)
	local frame = { t = key.t, ease = key.e or "linear" }
	for _, code in ipairs(CODES) do
		local value = key[code]
		if value then
			local fields = Resolve.FIELDS[code]
			frame[fields[1]] = value[1] or 0
			frame[fields[2]] = value[2] or 0
			frame[fields[3]] = value[3] or 0
		end
	end
	return frame
end

-- Одна анимация из определения.
function Resolve.resolve(def, setName: string, animName: string)
	local expanded = expand(def, 0)
	local frames = {}
	for _, key in ipairs(expanded.keys) do
		table.insert(frames, flatten(key))
	end
	local markers = table.clone(expanded.markers)
	table.sort(markers, function(a, b)
		return a.t < b.t
	end)
	local first = expanded.keys[1]
	return {
		name = animName,
		set = setName,
		length = expanded.length,
		loop = expanded.loop,
		priority = expanded.priority,
		fromPose = first ~= nil and first.from == "pose",
		frames = frames,
		markers = markers,
	}
end

-- Все анимации набора, с базовыми вместо отсутствующих. Кэшируется.
function Resolve.forSet(setName: string)
	local cached = resolvedSets[setName]
	if cached then
		return cached
	end
	local result = {}
	local set = rawSet(setName)
	assert(set, "Resolve: нет набора анимаций " .. tostring(setName))
	local sources = { set }
	for _, extraName in ipairs(extrasOf(setName)) do
		local extra = rawSet(extraName)
		if extra then
			table.insert(sources, extra)
		end
	end
	for _, source in ipairs(sources) do
		for animName, def in pairs(source) do
			if result[animName] == nil then
				result[animName] = Resolve.resolve(def, setName, animName)
			end
		end
	end
	if setName ~= "Base" then
		local base = Resolve.forSet("Base")
		for _, animName in ipairs(Resolve.FALLBACK) do
			if result[animName] == nil then
				result[animName] = base[animName]
			end
		end
	end
	resolvedSets[setName] = result
	return result
end

-- Проверка анимации: список ошибок (пустой — всё в порядке).
function Resolve.validate(anim): { string }
	local problems = {}
	local function fail(text: string)
		table.insert(problems, ("%s.%s: %s"):format(anim.set or "?", anim.name or "?", text))
	end
	local frames = anim.frames
	if #frames == 0 then
		fail("нет кадров")
		return problems
	end
	if math.abs(frames[1].t) > 1e-6 then
		fail(("первый кадр в %.3f, а не в 0"):format(frames[1].t))
	end
	for index = 2, #frames do
		if frames[index].t <= frames[index - 1].t then
			fail(("время кадра %d (%.3f) не больше предыдущего (%.3f)"):format(index, frames[index].t, frames[index - 1].t))
		end
	end
	for index, frame in ipairs(frames) do
		if not Anim.ease[frame.ease] then
			fail(("кадр %d: неизвестное сглаживание '%s'"):format(index, tostring(frame.ease)))
		end
	end
	local last = frames[#frames].t
	if math.abs(anim.length - last) > 1e-6 then
		fail(("длина %.3f не совпадает с последним кадром %.3f"):format(anim.length, last))
	end
	for _, marker in ipairs(anim.markers) do
		if marker.t < -1e-6 or marker.t > anim.length + 1e-6 then
			fail(("маркер %s в %.3f вне длины"):format(marker.name, marker.t))
		end
	end
	return problems
end

return Resolve
