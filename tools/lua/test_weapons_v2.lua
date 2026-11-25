--!nonstrict
-- test_weapons_v2.lua — переделка способностей мечей и молотов (07.11.2026), без Studio:
--   * правки LootWeaponsV2 легли поверх способностей этажей (поле v2, новые числа);
--   * у каждой способности V2 есть всё, что читает сервер (WeaponAbilitiesV2);
--   * шаблоны FX.V2/* есть, их текстуры известны (TEX / NEW / FALLBACK), флипбук — только у fb_*;
--   * звуки v2* подмешаны в Sfx.
--   LUAU=путь/к/luau node tools/run-luau.js tools/lua/test_weapons_v2.lua
local Shared = (_G :: any).KlinokShared or game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Loot = require(Shared.Config.Loot)
local Sfx = require(Shared.Config.Sfx)
local Fx = require(Shared.Fx.FxWeapons345)
local Patches = require(Shared.Config.LootWeaponsV2).Patches

local out, failures = {}, 0
local function check(label, ok, detail)
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %s%s"):format(ok and "OK  " or "FAIL", label, detail ~= nil and (" — " .. tostring(detail)) or "")
end

-- что читает сервер у каждой переделанной способности
local NEED = {
	erase = { "drawAt", "radius", "fieldTime", "tick", "tickDamage", "slow", "finalDamage", "executeBelow", "bossBonus" },
	forge_breath = { "plungeAt", "fissures", "fan", "length", "halfWidth", "eruptAt", "eruptGap", "eruptDamage", "bladeTime", "arcLength", "arcHalfWidth", "arcDamage" },
	pour = { "ringAt", "ringGap", "rings", "ringDamage", "cleaveAt", "cleaveLength", "cleaveHalfWidth", "cleaveDamage", "steamAt", "steamRadius", "steamDamage", "stageBonus" },
	dive = { "callAt", "huntTime", "dives", "diveGap", "diveTime", "diveRadius", "diveDamage", "finalRange", "finalRadius", "finalDamage" },
	flood = { "slamAt", "waveLength", "waveHalfWidth", "waveTime", "waveDamage", "push", "puddleRadius", "puddleTime", "puddleTick", "puddleDamage", "slow", "soaked" },
	prune = { "cuts", "radius", "halfAngle", "cutDamage", "armorBreak", "vulnerable", "vineAt", "vineTime", "snipAt", "snipDamage", "blooms" },
	last_hunt = { "hornAt", "hornRadius", "targets", "hopTime", "hopGap", "hopDamage", "preyBonus", "finaleRadius", "finaleDamage", "dashDistance" },
	slag_reap = { "spinTime", "spins", "spinStart", "spinDamage", "radius", "globsPerSpin", "globTime", "slamAt", "slamRadius", "slamDamage" },
	inscribe = { "writeAt", "writeTime", "length", "halfWidth", "crossAngle", "crossAhead", "runes", "runeInterval", "detonateDelay", "damage", "stun", "centerRadius", "centerDamage" },
	ink_splash = { "splashAt", "radius", "halfAngle", "damage", "pullAt", "pullRadius", "pullAhead", "pullTime", "burstAt", "burstRadius", "burstDamage", "perStain" },
	recall = { "minSwings", "replayScale", "dashLength", "dashHalfWidth", "dashDamage", "dashTime", "burstAhead", "burstRadius", "burstDamage" },
	reap = { "waveRange" },
	overheat = { "finaleDamage", "finaleRadius" },
	spill = { "pourAt" },
}
for id, fields in pairs(NEED) do
	local a = Loot.Abilities[id]
	local missing = {}
	for _, f in ipairs(fields) do
		if a == nil or a[f] == nil then
			table.insert(missing, f)
		end
	end
	check(("%s: поля на месте"):format(id), a ~= nil and #missing == 0, table.concat(missing, ","))
	if Patches[id] then
		check(("%s: правка V2 легла"):format(id), a ~= nil and a.v2 == true)
	end
end
check("коса ловчего — версия воина (рог), не посох", Loot.Abilities.last_hunt.hornRadius ~= nil and Loot.Abilities.last_hunt.mana == nil)
check("Жатва — дальность 16", Loot.Abilities.reap.waveRange == 16)
check("Шлаковый смерч длиннее 2 с", Loot.Abilities.slag_reap.spinTime >= 2)

-- шаблоны и текстуры
local known = {}
for k in pairs(Fx.TEX) do
	known[k] = true
end
for k in pairs(Fx.NEW) do
	known[k] = true
end
local v2, bad, flipBad = 0, {}, {}
for path, spec in pairs(Fx.Templates) do
	if string.sub(path, 1, 3) == "V2/" then
		v2 += 1
		for _, e in ipairs(spec.emitters or {}) do
			if not known[e.tex] then
				table.insert(bad, path .. ":" .. tostring(e.tex))
			end
			if e.flip and string.sub(e.tex, 1, 3) ~= "fb_" then
				table.insert(flipBad, path)
			end
			if string.sub(e.tex or "", 1, 3) == "fb_" and not Fx.FALLBACK[e.tex] then
				table.insert(bad, path .. ": нет FALLBACK " .. e.tex)
			end
		end
		if spec.trail and not Fx.Templates[spec.trail] then
			table.insert(bad, path .. ": нет следа " .. spec.trail)
		end
	end
end
check(("шаблонов V2: %d"):format(v2), v2 >= 40, v2)
check("текстуры шаблонов V2 известны", #bad == 0, table.concat(bad, ", "))
check("флипбук только у листов fb_*", #flipBad == 0, table.concat(flipBad, ", "))

-- звуки
local missing = {}
for _, name in ipairs({ "v2EraseDraw", "v2EraseSweep", "v2HeartErupt", "v2PourCleave", "v2FalconCall", "v2FalconDive", "v2FalconHit",
	"v2TideCrash", "v2PruneSnip", "v2HuntFinale", "v2CycloneSlam", "v2QuillCenter", "v2InkBurst", "v2SearingFinale", "v2MemoryBurst" }) do
	if not Sfx.layers(name) then
		table.insert(missing, name)
	end
end
check("звуки v2 в Sfx", #missing == 0, table.concat(missing, ","))
check("у сокола 3 варианта крика на выбор", Sfx.candidates.v2FalconCall and #Sfx.candidates.v2FalconCall == 3)

out[#out + 1] = ("ИТОГО: %d провалов"):format(failures)
return table.concat(out, "\n")
