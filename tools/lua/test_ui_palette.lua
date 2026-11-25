--!nonstrict
-- test_ui_palette.lua — палитра звуков интерфейса v3 (UiAssets.Palette / PaletteFor):
--   * каждый ключ замены ведёт на существующий звук палитры;
--   * каждый заменяемый ключ реально есть в игре (UiAssets.Sounds, UiSound.Mix или Config/Sfx);
--   * боевые звуки не заменяются.
--   LUAU=путь/к/luau node tools/run-luau.js tools/lua/test_ui_palette.lua
local Shared = (_G :: any).KlinokShared or game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local UiAssets = require(Shared.Config.UiAssets)
local Sfx = require(Shared.Config.Sfx)

local out, failures = {}, 0
local function check(label, ok, detail)
	if not ok then
		failures += 1
	end
	out[#out + 1] = ("  %s %s%s"):format(ok and "OK  " or "FAIL", label, detail and (" — " .. tostring(detail)) or "")
end

-- ключи UiSound.Mix (клиентский модуль) — списком, чтобы не тянуть клиент
local MIX = { "page_turn", "page_back", "paper_slide", "tab_select", "stamp", "dialog_open", "dialog_close", "dialog_next", "talk_blip",
	"choice_hover", "choice_pick", "new_topic", "forge_heat", "forge_anvil", "forge_spark", "forge_reveal", "forge_quench", "echo_socket",
	"star_on", "list_tick", "confirm", "stone_slab", "stone_tick", "medal", "candle", "gate_rumble", "floor_pick", "coin_tick", "chest_appear",
	"chest_fly", "chest_pickup", "chest_land", "blade_form", "blade_strike", "lid_open", "memory_tick", "memory_secret", "item_reveal", "mana_empty" }
local known = {}
for _, k in ipairs(MIX) do
	known[k] = true
end
for k in pairs(UiAssets.Sounds) do
	known[k] = true
end
local COMBAT = { hit = true, hitHeavy = true, parry = true, parryFail = true, dash = true, hurt = true, hurtHeavy = true, armorBlock = true,
	enemyWindup = true, enemyDeath = true, bossHit = true, bossIntro = true, slam = true, ability = true }

local bad, unknown, combat, n = {}, {}, {}, 0
for key, target in pairs(UiAssets.PaletteFor) do
	n += 1
	if not UiAssets.Palette[target] then
		table.insert(bad, key .. "→" .. target)
	end
	local inSfx = Sfx.layers and Sfx.layers(key) ~= nil
	if not known[key] and not inSfx then
		table.insert(unknown, key)
	end
	if COMBAT[key] then
		table.insert(combat, key)
	end
end
check(("%d замен ведут на звуки палитры"):format(n), #bad == 0, table.concat(bad, ", "))
check("заменяемые ключи есть в игре", #unknown == 0, table.concat(unknown, ", "))
check("боёвка не тронута", #combat == 0, table.concat(combat, ", "))
local palette = 0
for _, p in pairs(UiAssets.Palette) do
	palette += 1
	check("громкость в 0,2–0,45", p.volume >= 0.2 and p.volume <= 0.45, p.volume)
end
check("27 звуков палитры", palette == 27, palette)
out[#out + 1] = ("ИТОГО: %d провалов"):format(failures)
return table.concat(out, "\n")
