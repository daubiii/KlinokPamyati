#!/usr/bin/env node
// check-packages.js — для каждого пакета обновлений проверяет, установлен ли он
// в проект: есть ли все файлы и присутствуют ли «содержательные» строки пакета.
//
// «Строк нет» не всегда значит «не установлено»: проект может быть новее пакета
// (тогда строки пакета осознанно заменены). Поэтому отчёт показывает и число
// файлов, совпадающих с пакетом байт-в-байт.
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
  ['7. skills_fx (эт.1–2, маг)', 'klinok_skills_fx'],
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

function meaningful(text) {
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 22 && !line.startsWith('--'));
}

const rows = [];

for (const [label, folder] of PACKAGES) {
  const dir = path.join(ROOT, folder, 'src');
  if (!fs.existsSync(dir)) {
    rows.push({ label, state: 'ПАПКИ НЕТ' });
    continue;
  }

  const files = walk(dir);
  let missing = 0;
  let identical = 0;
  let differ = 0;
  let lostLines = 0;
  const missingNames = [];
  const differNames = [];

  for (const file of files) {
    const rel = path.relative(dir, file);
    const target = path.join(SRC, rel);
    if (!fs.existsSync(target)) {
      missing += 1;
      missingNames.push(rel);
      continue;
    }
    const theirs = fs.readFileSync(file, 'utf8');
    const ours = fs.readFileSync(target, 'utf8');
    if (theirs === ours) {
      identical += 1;
      continue;
    }
    differ += 1;
    const oursSet = new Set(meaningful(ours));
    const lost = meaningful(theirs).filter((line) => !oursSet.has(line));
    if (lost.length > 0) {
      lostLines += lost.length;
      differNames.push(`${rel} (нет ${lost.length} стр.)`);
    }
  }

  rows.push({ label, files: files.length, missing, missingNames, identical, differ, lostLines, differNames });
}

for (const row of rows) {
  if (row.state) {
    console.log(`${row.label}: ${row.state}`);
    continue;
  }
  const status = row.missing === 0 && row.lostLines === 0 ? 'УСТАНОВЛЕН' : 'ЕСТЬ ПРОБЕЛЫ';
  console.log(
    `${row.label}: ${status} — файлов ${row.files}, идентичных ${row.identical}, ` +
      `изменённых ${row.differ}, нет файлов ${row.missing}, строк пакета отсутствует ${row.lostLines}`
  );
  for (const name of row.missingNames.slice(0, 7)) console.log(`    нет файла: ${name}`);
  for (const name of row.differNames.slice(0, 7)) console.log(`    расхождение: ${name}`);
}
