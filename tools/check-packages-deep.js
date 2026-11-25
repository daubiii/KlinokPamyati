#!/usr/bin/env node
// check-packages-deep.js — ищет НАСТОЯЩИЕ потери: имена функций и полей,
// которые есть в пакете, но не встречаются больше нигде в проекте.
//
// Сравнение по строкам даёт ложные срабатывания: проект часто новее пакета, и
// блок просто переписан другими словами. А вот если имя функции из пакета
// нигде в проекте не встречается — значит функциональность действительно
// потеряна.
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = 'C:\\Users\\artem\\Desktop\\Новая папка (3)';
const SRC = 'C:\\Users\\artem\\KlinokPamyati\\src';

const PACKAGES = [
  ['1. weapons_345', 'klinok_weapons_345_v2'],
  ['2. ui_studio', 'klinok_ui_studio'],
  ['3. mage', 'klinok_mage_full'],
  ['4. talents', 'klinok_talents_v2'],
  ['5. chests v1', 'Новая папка'],
  ['6. bosses', 'Новая папка (2)'],
  ['7. skills_fx', 'klinok_skills_fx'],
  ['8. chests v3', 'klinok_chests'],
  ['9. worldmap', 'klinok_worldmap'],
  ['10. skills_fx_345', 'klinok_skills_fx_3451'],
];

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (/\.(lua|luau)$/.test(entry.name)) out.push(full);
  }
  return out;
}

// Все имена, объявленные в файле: функции и поля таблиц.
function declared(text) {
  const names = new Set();
  const patterns = [
    /function\s+([A-Za-z_][\w.]*)\s*\(/g, // function A.b.c(
    /local\s+function\s+([A-Za-z_]\w*)/g, // local function x
    /^\s*([A-Za-z_]\w*)\s*=\s*function/gm, // x = function
    /^\s*([A-Za-z_]\w*)\s*=\s*\{/gm, // x = {
    /\["([^"]+)"\]\s*=/g, // ["key"] =
  ];
  for (const re of patterns) {
    let m;
    while ((m = re.exec(text)) !== null) {
      const name = m[1].split('.').pop();
      if (name && name.length > 2) names.add(name);
    }
  }
  return names;
}

// Всё содержимое проекта одной строкой — для проверки «имя где-то есть».
let projectText = '';
for (const file of walk(SRC)) {
  projectText += fs.readFileSync(file, 'utf8') + '\n';
}

const rows = [];
for (const [label, folder] of PACKAGES) {
  const dir = path.join(ROOT, folder, 'src');
  if (!fs.existsSync(dir)) {
    rows.push(`${label}: папки нет`);
    continue;
  }
  const lost = new Set();
  for (const file of walk(dir)) {
    const text = fs.readFileSync(file, 'utf8');
    for (const name of declared(text)) {
      if (!projectText.includes(name)) lost.add(`${name} (${path.basename(file)})`);
    }
  }
  rows.push(
    lost.size === 0
      ? `${label}: потерь нет`
      : `${label}: не найдено имён ${lost.size}\n` + [...lost].slice(0, 12).map((n) => `    ${n}`).join('\n')
  );
}

console.log(rows.join('\n'));
