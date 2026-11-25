#!/usr/bin/env node
// patch-weapons-v2-ids.js — вписывает id загруженных ассетов:
//   • 20 флипбуков эффектов  → FxWeapons345.lua, таблица S.NEW
//   • 27 звуков интерфейса   → UiAssets.lua, таблица UiAssets.Palette
// Соответствие задано по именам (не по порядку) — так надёжнее.
'use strict';
const fs = require('fs');
const path = require('path');

const CONFIG = 'C:\\Users\\artem\\KlinokPamyati\\src\\ReplicatedStorage\\Shared\\Config';
const FX = 'C:\\Users\\artem\\KlinokPamyati\\src\\ReplicatedStorage\\Shared\\Fx';

const FLIPBOOKS = {
  fb_wave: '114504240666822',
  fb_thorns: '128907884774452',
  fb_tendrils: '131518957457699',
  fb_splash: '87054503454408',
  fb_slash: '108328207238386',
  fb_slam: '136391715674843',
  fb_scythe: '78840927727548',
  fb_runes: '137237369193769',
  fb_roots: '99475720108797',
  fb_pillar: '106690843062221',
  fb_memory: '105730462190244',
  fb_jaws: '97000089264632',
  fb_inkburst: '134436285851153',
  fb_hit: '112761525124613',
  fb_feathers: '76006890126602',
  fb_erase: '136522820819325',
  fb_crit: '135287832117287',
  fb_cleave: '71398688196557',
  fb_bite: '121458717567600',
  fb_bird: '129907541521573',
};

// Порядок на скриншотах — по убыванию имени (tab → … → anvil).
const SOUNDS = {
  tab: '88533869811344',
  star_on: '134795794729480',
  stamp: '129164759068459',
  spark: '87391787892597',
  reveal_rare: '137942812021877',
  reveal: '120028950946561',
  quench: '117475570706634',
  paper_slide: '136570631365713',
  page_turn: '86956085889857',
  memory_tick: '95978882371205',
  level_up: '85413528296397',
  item_get: '111762567324627',
  hover: '107736348949057',
  forge_success: '133343638842181',
  forge_heat: '114032638018319',
  forge_fail: '125635591584897',
  error: '82234121232217',
  echo: '112213372188276',
  coins: '74487280924066',
  coin_tick: '126752889147997',
  click: '95372400782300',
  chest_open: '75789937658440',
  chest_land: '108038579443928',
  chest_appear: '117415232035440',
  blade_strike: '71133138268401',
  armor_equip: '74761573467156',
  anvil: '95205046991817',
};

const report = [];

// ---------- флипбуки ----------
{
  const file = path.join(FX, 'FxWeapons345.lua');
  let text = fs.readFileSync(file, 'utf8');
  let replaced = 0;
  let missing = [];

  for (const [name, id] of Object.entries(FLIPBOOKS)) {
    const re = new RegExp(`(\\b${name}\\s*=\\s*)"[^"]*"`);
    if (!re.test(text)) {
      missing.push(name);
      continue;
    }
    text = text.replace(re, `$1"${id}"`);
    replaced += 1;
  }

  fs.writeFileSync(file, text, 'utf8');
  report.push(`флипбуки: вписано ${replaced} из ${Object.keys(FLIPBOOKS).length}${missing.length ? ', нет в таблице: ' + missing.join(', ') : ''}`);
}

// ---------- звуки ----------
{
  const file = path.join(CONFIG, 'UiAssets.lua');
  let text = fs.readFileSync(file, 'utf8');
  let replaced = 0;
  const missing = [];

  for (const [name, id] of Object.entries(SOUNDS)) {
    // запись вида: name = { id = "", volume = 0.25 },
    const re = new RegExp(`(\\b${name}\\s*=\\s*\\{\\s*id\\s*=\\s*)"[^"]*"`);
    if (!re.test(text)) {
      missing.push(name);
      continue;
    }
    text = text.replace(re, `$1"rbxassetid://${id}"`);
    replaced += 1;
  }

  fs.writeFileSync(file, text, 'utf8');
  report.push(`звуки: вписано ${replaced} из ${Object.keys(SOUNDS).length}${missing.length ? ', нет в таблице: ' + missing.join(', ') : ''}`);
}

console.log(report.join('\n'));
