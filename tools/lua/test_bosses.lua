--!nonstrict
-- test_bosses.lua — фирменные атаки боссов (Config/BossMoves) и сцены
-- появления (Config/BossIntros): данные, вливание в Enemies, анимации
-- *Moves, звуки, геометрия Util/BossGeo.
--   LUAU=путь/к/luau node tools/run-luau.js tools/lua/test_bosses.lua

local Shared = (_G :: any).KlinokShared or game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BossMoves = require(Shared.Config.BossMoves)
local BossIntros = require(Shared.Config.BossIntros)
local Enemies = require(Shared.Config.Enemies)
local EnemyVisuals = require(Shared.Config.EnemyVisuals)
local Sfx = require(Shared.Config.Sfx)
local Resolve = require(Shared.Anim.Resolve)
local BossGeo = require(Shared.Util.BossGeo)

local out = {}
local failures = 0
local function check(label, ok, detail)
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %s%s"):format(ok and "OK  " or "FAIL", label, detail and (" — " .. tostring(detail)) or "")
end
local function isColor(v)
	return v ~= nil and type(v.R) == "number" and type(v.G) == "number" and type(v.B) == "number"
end
local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

local BOSSES = { "gatekeeper", "rosewarden", "royal_huntsman", "elder_founder", "chief_chronicler" }

-- ===== атаки: данные =====
out[#out + 1] = "Атаки:"
local seenIds = {}
for _, typeId in ipairs(BOSSES) do
	local list = BossMoves.list(typeId)
	check(typeId .. ": две фирменные атаки", #list == 2, #list)
	for _, entry in ipairs(list) do
		local a = entry.attack
		local label = typeId .. "." .. tostring(a.id)
		check(label .. ": id, имя, фаза", type(a.id) == "string" and type(a.name) == "string" and #a.name > 0
			and (entry.phase == 1 or entry.phase == 2 or entry.phase == 3))
		check(label .. ": тайминги > 0", (a.windup or 0) > 0 and (a.recover or 0) > 0 and (a.cooldown or 0) > 0
			and (a.damage or 0) > 0 and (a.every or 0) > 0 and (a.reach or 0) > 0)
		check(label .. ": move.kind = id", type(a.move) == "table" and a.move.kind == a.id)
		check(label .. ": id уникален", not seenIds[a.id], a.id)
		seenIds[a.id] = true
		check(label .. ": find", BossMoves.find(typeId, a.id) == entry)
		for phaseIndex = 1, 3 do
			local p = BossMoves.params(a.move, phaseIndex)
			local t = BossMoves.channelTime(p)
			check(("%s: канал в фазе %d — 0.2..8 с"):format(label, phaseIndex), type(t) == "number" and t >= 0.2 and t <= 8, t)
			check(("%s: params(%d) без byPhase"):format(label, phaseIndex), p.byPhase == nil)
		end
		-- byPhase накапливается: правка фазы n видна в n и дальше
		for index, patch in pairs(a.move.byPhase or {}) do
			for key, value in pairs(patch) do
				check(("%s: byPhase[%d].%s применяется"):format(label, index, key), BossMoves.params(a.move, 3)[key] ~= nil
					and BossMoves.params(a.move, index)[key] == value)
			end
		end
	end
end
check("find: чужой id → nil", BossMoves.find("gatekeeper", "flood") == nil)
check("list: не босс → пусто", #BossMoves.list("rat") == 0)

-- bookSlam: два удара обложки, второй после первого
do
	local entry = BossMoves.find("chief_chronicler", "bookSlam")
	if entry then
		local p = BossMoves.params(entry.attack.move, 1)
		local t1, t2 = BossMoves.bookImpact(p, 1), BossMoves.bookImpact(p, 2)
		check("bookSlam: удар 2 позже удара 1 и раньше конца канала", t1 > 0 and t2 > t1 and t2 < BossMoves.channelTime(p))
	else
		check("bookSlam найден", false)
	end
end

-- ===== вливание в Enemies =====
out[#out + 1] = "Enemies:"
local function findAttack(list, id)
	for _, a in ipairs(list or {}) do
		if a.id == id then
			return a
		end
	end
	return nil
end
for _, typeId in ipairs(BOSSES) do
	local enemyType = Enemies.Types[typeId]
	check(typeId .. ": тип врага есть", enemyType ~= nil)
	if enemyType then
		for _, entry in ipairs(BossMoves.list(typeId)) do
			local id = entry.attack.id
			local where
			if entry.phase <= 1 or not (enemyType.phases and enemyType.phases[entry.phase - 1]) then
				where = enemyType.attacks
			else
				where = enemyType.phases[entry.phase - 1].attacks
			end
			local a = findAttack(where, id)
			check(("%s.%s: влита в фазу %d"):format(typeId, id, entry.phase), a ~= nil and a.bossMove == true)
			check(("%s.%s: влита один раз"):format(typeId, id), a ~= entry.attack)
			local count = 0
			for _, list in ipairs({ enemyType.attacks, enemyType.phases and enemyType.phases[1] and enemyType.phases[1].attacks,
				enemyType.phases and enemyType.phases[2] and enemyType.phases[2].attacks }) do
				for _, x in ipairs(list or {}) do
					if x.id == id then
						count += 1
					end
				end
			end
			check(("%s.%s: без дублей"):format(typeId, id), count == 1, count)
		end
	end
end
BossMoves.inject(Enemies.Types) -- повторный вызов ничего не добавляет
do
	local n = 0
	for _, a in ipairs(Enemies.Types.gatekeeper.attacks) do
		if a.id == "gridDrop" then
			n += 1
		end
	end
	check("inject идемпотентен", n == 1, n)
end

-- ===== визуал и анимации =====
out[#out + 1] = "Анимации и звуки:"
local function soundOk(name)
	return type(name) == "string" and Sfx.sounds[name] ~= nil
end
for _, typeId in ipairs(BOSSES) do
	local vis = EnemyVisuals.Types[typeId]
	check(typeId .. ": визуал есть", vis ~= nil)
	if vis then
		local okSet, set = pcall(Resolve.forSet, vis.set)
		check(typeId .. ": набор " .. tostring(vis.set) .. " раскрывается", okSet, not okSet and tostring(set) or nil)
		set = okSet and set or {}
		check(typeId .. ": дополнение *Moves подключено", table.find(Resolve.extrasOf(vis.set), BossMoves.AnimSets[vis.set]) ~= nil,
			tostring(BossMoves.AnimSets[vis.set]))
		for id, v in pairs(BossMoves.Visuals[typeId] or {}) do
			check(("%s.%s: визуал атаки влит"):format(typeId, id), vis.attacks[id] == v)
			for _, field in ipairs({ "windup", "strike", "channel", "recover" }) do
				local anim = set[v[field]]
				check(("%s.%s: анимация %s (%s)"):format(typeId, id, field, tostring(v[field])), anim ~= nil)
				if anim then
					local problems = Resolve.validate(anim)
					check(("%s: %s проходит validate"):format(typeId, v[field]), #problems == 0, table.concat(problems, "; "))
				end
			end
			check(("%s.%s: windup длиной с замах"):format(typeId, id), set[v.windup] ~= nil
				and near(set[v.windup].length, BossMoves.find(typeId, id).attack.windup, 0.05),
				set[v.windup] and set[v.windup].length)
			local channelNeed = BossMoves.channelTime(BossMoves.params(BossMoves.find(typeId, id).attack.move, 1))
			check(("%s.%s: канал зациклен или покрывает %.2f с"):format(typeId, id, channelNeed), set[v.channel] ~= nil
				and (set[v.channel].loop == true or set[v.channel].length >= channelNeed - 0.1), set[v.channel] and set[v.channel].length)
			check(("%s.%s: звуки замаха и удара"):format(typeId, id), soundOk(v.windupSound) and soundOk(v.hitSound),
				tostring(v.windupSound) .. "/" .. tostring(v.hitSound))
		end
		for marker, sound in pairs(BossMoves.MarkerSounds[typeId] or {}) do
			check(("%s: маркер %s → звук %s"):format(typeId, marker, sound), soundOk(vis.markerSounds and vis.markerSounds[marker]))
		end
		-- все обязательные анимации врага (включая новые) есть
		local missing = {}
		for _, name in ipairs(EnemyVisuals.requiredAnimations(typeId)) do
			if set[name] == nil then
				table.insert(missing, name)
			end
		end
		check(typeId .. ": все обязательные анимации есть", #missing == 0, table.concat(missing, ", "))
	end
end

-- ===== сцены появления =====
out[#out + 1] = "Сцены появления:"
local STYLES = { iron = true, vines = true, claws = true, molten = true, ink = true }
local styleSeen = {}
for _, typeId in ipairs(BOSSES) do
	local scene = BossIntros.get(typeId)
	check(typeId .. ": сцена есть", scene ~= nil)
	if scene then
		check(typeId .. ": full 6..10 с, short 2..full", scene.full >= 6 and scene.full <= 10 and scene.short >= 2 and scene.short < scene.full)
		check(typeId .. ": duration/skip", BossIntros.duration(typeId) == scene.full and BossIntros.duration(typeId, true) == scene.short
			and near(BossIntros.skip(typeId, true), scene.full - scene.short) and BossIntros.skip(typeId, false) == 0)
		local inside = true
		local sorted = {}
		for name, t in pairs(scene.beats) do
			table.insert(sorted, { name = name, t = t })
			inside = inside and t >= 0 and t < scene.full
		end
		table.sort(sorted, function(a, b) return a.t < b.t end)
		check(typeId .. ": отметки внутри сцены", inside)
		check(typeId .. ": рёв — последняя отметка", sorted[#sorted] and sorted[#sorted].name == "roar")
		check(typeId .. ": рёв попадает в короткую версию", scene.beats.roar > scene.full - scene.short + 0.5)
		check(typeId .. ": после рёва ≥ 1 с на титр", scene.full - scene.beats.roar >= 1)
		check(typeId .. ": цитата", type(scene.quote) == "string" and #scene.quote > 0)
		check(typeId .. ": стиль титра " .. tostring(scene.style and scene.style.kind), scene.style and STYLES[scene.style.kind]
			and isColor(scene.style.name) and isColor(scene.style.line) and isColor(scene.style.glow))
		if scene.style then
			check(typeId .. ": стиль не повторяется", not styleSeen[scene.style.kind])
			styleSeen[scene.style.kind] = true
		end
		check(typeId .. ": тонировка", scene.tint ~= nil and isColor(scene.tint.color))
		local vis = EnemyVisuals.Types[typeId]
		check(typeId .. ": визуал играет сцену", vis and vis.introScene == true and vis.spawn == scene.anim and vis.legacySpawn ~= nil)
		local set = vis and select(2, pcall(Resolve.forSet, vis.set)) or {}
		local anim = type(set) == "table" and set[scene.anim]
		check(typeId .. ": анимация " .. tostring(scene.anim) .. " длиной full", anim and near(anim.length, scene.full, 0.01), anim and anim.length)
		if anim then
			local problems = Resolve.validate(anim)
			check(typeId .. ": IntroScene проходит validate", #problems == 0, table.concat(problems, "; "))
			check(typeId .. ": IntroScene не зациклена", anim.loop == false)
			local markers = {}
			for _, m in ipairs(anim.markers or {}) do
				markers[m.name] = markers[m.name] or m.t
			end
			check(typeId .. ": маркер Roar на отметке рёва", near(markers.Roar, scene.beats.roar, 0.05), markers.Roar)
			if scene.beats.eyes and markers.EyesOn then
				check(typeId .. ": маркер EyesOn на отметке глаз", near(markers.EyesOn, scene.beats.eyes, 0.05), markers.EyesOn)
			end
		end
		check(typeId .. ": атрибут «видел»", BossIntros.seenAttribute(typeId) == "BossIntroSeen_" .. typeId)
	end
end
check("не босс → без сцены", BossIntros.get("rat") == nil and BossIntros.duration("rat") == nil and BossIntros.skip("rat", true) == 0)
check("legacy-появление у мини-боссов не тронуто", (function()
	for typeId, vis in pairs(EnemyVisuals.Types) do
		if vis.introScene and not BossIntros.get(typeId) then
			return false
		end
	end
	return true
end)())

-- ===== геометрия =====
out[#out + 1] = "BossGeo:"
do
	local a = BossGeo.angleOf(1, 0)
	local dx, dz = BossGeo.dirOf(a)
	check("angleOf/dirOf обратимы", near(dx, 1, 1e-6) and near(dz, 0, 1e-6))
	check("angleDiff через 0 — короткий путь", near(math.abs(BossGeo.angleDiff(math.rad(350), math.rad(10))), math.rad(20), 1e-6))
	local ux, uz = BossGeo.unit(0, 0, 0, 1)
	check("unit нулевого → запасной", near(ux, 0) and near(uz, 1))
	local along, side = BossGeo.toLocal(3, 7, 1, 2, 0, 1)
	local bx, bz = BossGeo.fromLocal(along, side, 1, 2, 0, 1)
	check("toLocal/fromLocal обратимы", near(bx, 3, 1e-6) and near(bz, 7, 1e-6))
	local cx, cz = BossGeo.clampCircle(100, 0, 0, 0, 20, 2)
	check("clampCircle держит в круге", math.sqrt(cx * cx + cz * cz) <= 18 + 1e-6)
	-- шахматка: соседние клетки в одной волне — разные, в следующей — меняются
	check("cellDrops: шахматка", BossGeo.cellDrops(1, 1, 1) ~= BossGeo.cellDrops(1, 2, 1)
		and BossGeo.cellDrops(1, 1, 1) ~= BossGeo.cellDrops(1, 1, 2))
	local cells = BossGeo.gridCells(0, 0, 0, 1, 7, 5, nil)
	check("gridCells: 25 клеток 5×5", #cells == 25, #cells)
	check("ringHit: на фронте волны", BossGeo.ringHit(10, 10.2, 1) and not BossGeo.ringHit(5, 10, 1))
	check("inGap: в проёме и мимо", BossGeo.inGap(math.rad(10), { 0 }, math.rad(15)) and not BossGeo.inGap(math.rad(90), { 0 }, math.rad(15)))
	local lanes = BossGeo.laneOffsets(5, 4)
	check("laneOffsets: 5 дорожек симметрично", #lanes == 5 and near(lanes[1] + lanes[5], 0, 1e-6))
	local safe = BossGeo.safeLanes(5, 7)
	local nSafe = 0
	for _ in pairs(safe) do
		nSafe += 1
	end
	check("safeLanes: есть и опасные, и безопасные", nSafe >= 1 and nSafe < 5, nSafe)
end

out[#out + 1] = ("ИТОГО: %d проверок, %d провалов"):format(#out, failures)
return table.concat(out, "\n")
