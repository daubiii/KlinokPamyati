#!/usr/bin/env node
// check-weapons345.js — сверка оружия этажей 3–5 между сервером, клиентом и данными.
// Сканирует исходники (фазы сервера, обработчики клиента, пути FX, звуки,
// анимации), передаёт найденное в tools/lua/test_weapons345.lua и запускает
// его через run-luau.js (данные Loot/Sfx/FxWeapons345/AbilityIcons345).
//   node tools/check-weapons345.js
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'src');
const read = (p) => fs.readFileSync(path.join(SRC, p), 'utf8');
const CTRL = 'StarterPlayer/StarterPlayerScripts/Controllers/';
const SYS = 'ServerScriptService/Systems/';
const KINDS = { hunt: ['WeaponAbilitiesHunt', 'AbilityFxHunt'], forge: ['WeaponAbilitiesForge', 'AbilityFxForge'], chron: ['WeaponAbilitiesChronicle', 'AbilityFxChronicle'] };
const uniq = (a) => [...new Set(a)].sort();
const all = (re, text) => [...text.matchAll(re)].map((m) => m[1]);

const scan = { phases: {}, handlers: {}, fx: [], sounds: [], anims: {}, actions: [] };
const clientText = [];
for (const [kind, [server, client]] of Object.entries(KINDS)) {
  scan.phases[kind] = uniq(all(/phase = "(\w+)"/g, read(SYS + server + '.lua')));
  const text = read(CTRL + client + '.lua');
  clientText.push(text);
  const block = text.slice(text.indexOf('.handlers = {'));
  const inner = block.slice(block.indexOf(kind + ' = {'), block.indexOf('}'));
  scan.handlers[kind] = uniq(all(/(\w+) = \w+,/g, inner));
}
clientText.push(read(CTRL + 'AbilityFx345Kit.lua'));
const joined = clientText.join('\n');
scan.fx = uniq(all(/"((?:Hunt|Forge|Chron)\/[A-Za-z0-9\/]+)"/g, joined));
scan.sounds = uniq(all(/K\.sound\("(\w+)"/g, joined));
const anim = read(CTRL + 'PlayerAnimWeapons.lua');
const aa = anim.slice(anim.indexOf('PlayerAnimWeapons.AbilityAnimations = {'));
for (const m of aa.slice(0, aa.indexOf('\n}')).matchAll(/(\w+) = \{ "(\w+)", ([\d.]+) \}/g)) scan.anims[m[1]] = m[2];
scan.actions = uniq(all(/^A\.(\w+) = \{/gm, anim));

const lua = (v) => Array.isArray(v) ? '{' + v.map(lua).join(', ') + '}'
  : typeof v === 'object' ? '{' + Object.entries(v).map(([k, x]) => `[${JSON.stringify(k)}] = ${lua(x)}`).join(', ') + '}'
  : JSON.stringify(v);
const test = fs.readFileSync(path.join(__dirname, 'lua', 'test_weapons345.lua'), 'utf8');
const tmp = path.join(os.tmpdir(), `weapons345-${process.pid}.lua`);
fs.writeFileSync(tmp, `local SCAN = ${lua(scan)}\n` + test.replace(/^--!nonstrict\n/, '').replace('local SCAN = nil', ''));
const r = spawnSync(process.execPath, [path.join(__dirname, 'run-luau.js'), tmp], { stdio: 'inherit', env: process.env });
fs.unlinkSync(tmp);
process.exit(r.status ?? 2);
