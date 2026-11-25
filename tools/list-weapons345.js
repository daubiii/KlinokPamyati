#!/usr/bin/env node
// list-weapons345.js — печатает оружие этажей 3–5: id, имя, редкость,
// способность и пассивка (по данным Config/LootFloor3/4/5.lua).
'use strict';
const fs = require('fs');
const path = require('path');

const CONFIG = 'C:\\Users\\artem\\KlinokPamyati\\src\\ReplicatedStorage\\Shared\\Config';

// Возвращает блок `Name = { ... }` с учётом вложенности скобок.
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

// Пары id -> name внутри блока вида `key = { ... name = "..." }`.
function idNameMap(blockText) {
  const map = new Map();
  const re = /(\w+)\s*=\s*\{([\s\S]*?)\n\t\},?/g;
  let m;
  while ((m = re.exec(blockText)) !== null) {
    const key = m[1];
    if (key === 'Weapons' || key === 'Items') continue;
    const nameMatch = /name\s*=\s*"([^"]+)"/.exec(m[2]);
    if (nameMatch) map.set(key, nameMatch[1]);
  }
  return map;
}

// Записи оружия: режем по `id = "..."`.
function weapons(blockText) {
  const list = [];
  const parts = blockText.split(/\bid\s*=\s*"/).slice(1);
  for (const part of parts) {
    const id = part.slice(0, part.indexOf('"'));
    const rest = part.slice(part.indexOf('"') + 1);
    // до следующего `{ id =` или конца записи
    const cut = rest.split(/\n\t\},/)[0];
    const name = (/name\s*=\s*"([^"]+)"/.exec(cut) || [])[1] || '';
    const rarity = (/rarity\s*=\s*"([^"]+)"/.exec(cut) || [])[1] || '?';
    const ability = (/ability\s*=\s*"([^"]+)"/.exec(cut) || [])[1] || '';
    const passive = (/passive\s*=\s*"([^"]+)"/.exec(cut) || [])[1] || '';
    list.push({ id, name, rarity, ability, passive });
  }
  return list;
}

for (const floor of [3, 4, 5]) {
  const file = path.join(CONFIG, `LootFloor${floor}.lua`);
  const text = fs.readFileSync(file, 'utf8');
  const weaponBlock = block(text, `LootFloor${floor}.Weapons`);
  const abilities = idNameMap(block(text, `LootFloor${floor}.Abilities`));
  const passives = idNameMap(block(text, `LootFloor${floor}.Passives`));

  console.log(`\n=== ЭТАЖ ${floor} ===`);
  for (const w of weapons(weaponBlock)) {
    const ability = w.ability ? abilities.get(w.ability) || w.ability : '—';
    const passive = w.passive ? passives.get(w.passive) || w.passive : '—';
    console.log(
      `${w.id.padEnd(18)} ${w.name.padEnd(30)} ${w.rarity.padEnd(10)} способность: ${ability.padEnd(26)} пассивка: ${passive}`
    );
  }
}
