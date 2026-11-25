#!/usr/bin/env node
// build-weapons-table.js — полная таблица оружия из конфигов проекта:
// воин (этажи 1–5) и маг (посохи, этажи 1–5). Пишет Markdown в docs/ОРУЖИЕ.md
// и печатает короткую версию в консоль.
'use strict';
const fs = require('fs');
const path = require('path');

const CONFIG = 'C:\\Users\\artem\\KlinokPamyati\\src\\ReplicatedStorage\\Shared\\Config';
const OUT = 'C:\\Users\\artem\\KlinokPamyati\\docs\\ОРУЖИЕ.md';

const RARITY = {
  common: 'обычное',
  rare: 'редкое',
  epic: 'эпическое',
  legendary: 'легендарное',
  secret: 'секретное',
};

const TYPE = {
  sword: 'меч',
  hammer: 'молот',
  dagger: 'кинжал',
  staff: 'посох',
};

function read(name) {
  return fs.readFileSync(path.join(CONFIG, name), 'utf8');
}

// Блок `Name = { ... }` с учётом вложенности скобок.
function block(text, name) {
  const start = text.indexOf(name + ' = {');
  if (start < 0) return '';
  let depth = 0;
  for (let i = start + name.length + 3; i < text.length; i += 1) {
    const ch = text[i];
    if (ch === '{') depth += 1;
    else if (ch === '}') {
      depth -= 1;
      if (depth === 0) return text.slice(start, i + 1);
    }
  }
  return '';
}

// key -> name для таблиц вида `key = { ... name = "..." }` (и однострочных тоже).
function nameMap(blockText) {
  const map = new Map();
  const startRe = /(\w+)\s*=\s*\{/g;
  let m;
  while ((m = startRe.exec(blockText)) !== null) {
    const key = m[1];
    const openIndex = startRe.lastIndex - 1;
    let depth = 0;
    let end = -1;
    for (let i = openIndex; i < blockText.length; i += 1) {
      const ch = blockText[i];
      if (ch === '{') depth += 1;
      else if (ch === '}') {
        depth -= 1;
        if (depth === 0) {
          end = i;
          break;
        }
      }
    }
    if (end < 0) break;
    // Abilities = {, Passives = { — это заголовок таблицы, а не запись:
    // продолжаем искать внутри, иначе вся таблица схлопнется в один ключ.
    if (['Abilities', 'Passives', 'Weapons', 'Items', 'Spells'].includes(key)) {
      startRe.lastIndex = openIndex + 1;
      continue;
    }
    const body = blockText.slice(openIndex, end + 1);
    const nameMatch = /\bname\s*=\s*"([^"]+)"/.exec(body);
    if (nameMatch && !map.has(key)) map.set(key, nameMatch[1]);
    startRe.lastIndex = end + 1;
  }
  return map;
}

// Записи `{ id = "...", name = "...", ... }`.
function entryList(blockText) {
  const list = [];
  const parts = blockText.split(/\{\s*id\s*=\s*"/).slice(1);
  for (const part of parts) {
    const id = part.slice(0, part.indexOf('"'));
    const cut = part.split(/\n\t\t?\},/)[0];
    const pick = (key) => {
      const m = new RegExp(`\\b${key}\\s*=\\s*"([^"]+)"`).exec(cut);
      return m ? m[1] : '';
    };
    list.push({
      id,
      name: pick('name'),
      typeId: pick('typeId'),
      rarity: pick('rarity'),
      ability: pick('ability'),
      passive: pick('passive'),
    });
  }
  return list;
}

// Записи мага: weapon("id", "Имя", "rarity", floor, "ability", "passive").
function mageList(blockText) {
  const list = [];
  const re = /weapon\("([^"]+)",\s*"([^"]+)",\s*"([^"]+)",\s*(\d+)(?:,\s*"([^"]*)")?(?:,\s*"([^"]*)")?\)/g;
  let m;
  while ((m = re.exec(blockText)) !== null) {
    list.push({
      id: m[1],
      name: m[2],
      typeId: 'staff',
      rarity: m[3],
      floor: Number(m[4]),
      ability: m[5] || '',
      passive: m[6] || '',
    });
  }
  return list;
}

function rarityLabel(id) {
  return RARITY[id] || id || '—';
}

function typeLabel(id) {
  return TYPE[id] || id || '—';
}

// ---------- воин ----------
const loot = read('Loot.lua');
const warrior = [];
const floor1 = entryList(block(loot, 'Loot.Weapons'));
for (const w of floor1) {
  warrior.push({ ...w, floor: 1 });
}

const floorAbilities = new Map();
const floorPassives = new Map();
// Этаж 1: способности и пассивки лежат в самом Loot.lua.
for (const [key, name] of nameMap(block(loot, 'Loot.Abilities'))) floorAbilities.set(key, name);
for (const [key, name] of nameMap(block(loot, 'Loot.Passives'))) floorPassives.set(key, name);

for (const floor of [2, 3, 4, 5]) {
  const text = read(`LootFloor${floor}.lua`);
  const abilities = nameMap(block(text, `LootFloor${floor}.Abilities`));
  const passives = nameMap(block(text, `LootFloor${floor}.Passives`));
  for (const [key, name] of abilities) floorAbilities.set(key, name);
  for (const [key, name] of passives) floorPassives.set(key, name);
  for (const w of entryList(block(text, `LootFloor${floor}.Weapons`))) {
    warrior.push({ ...w, floor });
  }
}

// ---------- маг ----------
const mageText = read('LootMage.lua');
// У мага способности объявлены вызовом spell("id", "Имя", ...), а не таблицей.
const mageAbilities = nameMap(block(mageText, 'LootMage.Abilities'));
{
  const re = /(\w+)\s*=\s*spell\("([^"]+)",\s*"([^"]+)"/g;
  let m;
  while ((m = re.exec(mageText)) !== null) {
    if (!mageAbilities.has(m[1])) mageAbilities.set(m[1], m[3]);
  }
}
const magePassives = nameMap(block(mageText, 'LootMage.Passives'));
const mage = mageList(block(mageText, 'LootMage.Weapons'));

// ---------- вывод ----------
const lines = [];
lines.push('# Оружие «Клинка Памяти» — полная таблица');
lines.push('');
lines.push('Собрано из конфигов: `Loot.lua`, `LootFloor2–5.lua`, `LootMage.lua`.');
lines.push('Выдать в Studio (Command Bar, Play): `game.ServerStorage.KlinokDebug.Cmd:Invoke("give <id>")`.');
lines.push('Способность — клавиша **1**, пассивка работает сама.');
lines.push('');

function table(items, abilityMap, passiveMap) {
  const rows = [];
  rows.push('| id (give) | Название | Тип | Редкость | Способность | Пассивка |');
  rows.push('|---|---|---|---|---|---|');
  for (const w of items) {
    const ability = w.ability ? abilityMap.get(w.ability) || w.ability : '—';
    const passive = w.passive ? passiveMap.get(w.passive) || w.passive : '—';
    rows.push(
      `| \`${w.id}\` | ${w.name} | ${typeLabel(w.typeId)} | ${rarityLabel(w.rarity)} | ${ability} | ${passive} |`
    );
  }
  return rows;
}

lines.push('## Воин');
lines.push('');
for (const floor of [1, 2, 3, 4, 5]) {
  const items = warrior.filter((w) => w.floor === floor);
  lines.push(`### Этаж ${floor} — ${items.length} видов`);
  lines.push('');
  lines.push(...table(items, floorAbilities, floorPassives));
  lines.push('');
}
lines.push(`Всего воинского оружия: **${warrior.length}**.`);
lines.push('');

lines.push('## Маг (посохи)');
lines.push('');
for (const floor of [1, 2, 3, 4, 5]) {
  const items = mage.filter((w) => w.floor === floor);
  if (items.length === 0) continue;
  lines.push(`### Этаж ${floor} — ${items.length} видов`);
  lines.push('');
  lines.push(...table(items, mageAbilities, magePassives));
  lines.push('');
}
lines.push(`Всего посохов: **${mage.length}**.`);
lines.push('');
lines.push('---');
lines.push('');
lines.push('Стартовое оружие: воин — `rusty_sword`, маг — `apprentice_staff`.');
lines.push('Секретки этажей 4–5 падают только из сундука своего этажа.');

const markdown = lines.join('\n') + '\n';
fs.writeFileSync(OUT, markdown, 'utf8');

// Короткая версия в консоль.
const brief = [];
brief.push(`воин: ${warrior.length} видов, маг: ${mage.length} посохов — записано в ${OUT}`);
for (const w of warrior) {
  const ability = w.ability ? floorAbilities.get(w.ability) || w.ability : '—';
  const passive = w.passive ? floorPassives.get(w.passive) || w.passive : '—';
  brief.push(`Э${w.floor} ${w.id.padEnd(18)} ${w.name.padEnd(28)} ${rarityLabel(w.rarity).padEnd(11)} ${ability} / ${passive}`);
}
for (const w of mage) {
  const ability = w.ability ? mageAbilities.get(w.ability) || w.ability : '—';
  const passive = w.passive ? magePassives.get(w.passive) || w.passive : '—';
  brief.push(`М${w.floor} ${w.id.padEnd(18)} ${w.name.padEnd(28)} ${rarityLabel(w.rarity).padEnd(11)} ${ability} / ${passive}`);
}
console.log(brief.join('\n'));
