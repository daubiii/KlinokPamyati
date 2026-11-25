#!/usr/bin/env node
// merge-packages.js — трёхстороннее слияние пакетов обновлений.
//
// Проблема: пакеты — ветки от разных баз. Последовательное копирование
// перезаписывало файлы целиком, и правки ранних пакетов терялись (аудит нашёл
// 29 файлов из 35).
//
// Решение: для каждого файла берём
//   base   — версия проекта ДО наложения пакетов (коммит BASE_COMMIT),
//   ours   — то, что сейчас в проекте,
//   theirs — версия из очередного пакета,
// и сливаем через `git merge-file`. Так сохраняются правки всех пакетов.
//
//   node tools/merge-packages.js           — слить и записать
//   node tools/merge-packages.js --dry     — только отчёт, без записи
'use strict';
const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const ROOT = 'C:\\Users\\artem\\Desktop\\Новая папка (3)';
const PROJECT = 'C:\\Users\\artem\\KlinokPamyati';
const SRC = path.join(PROJECT, 'src');
const BASE_COMMIT = 'ad7a163';
const DRY = process.argv.includes('--dry');
const UNION = process.argv.includes('--union');

const PACKAGES = [
  'klinok_weapons_345_v2',
  'klinok_ui_studio',
  'klinok_mage_full',
  'klinok_talents_v2',
  'Новая папка',
  'Новая папка (2)',
];

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (entry.name.endsWith('.lua')) out.push(full);
  }
  return out;
}

function gitBase(rel) {
  try {
    return execFileSync('git', ['show', `${BASE_COMMIT}:src/${rel.replace(/\\/g, '/')}`], {
      cwd: PROJECT,
      encoding: 'utf8',
      maxBuffer: 64 * 1024 * 1024,
    });
  } catch (error) {
    return ''; // файла в базе не было — считаем пустым
  }
}

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'kl-merge-'));
let counter = 0;

function mergeFile(ours, base, theirs) {
  counter += 1;
  const oursPath = path.join(tmp, `ours${counter}.lua`);
  const basePath = path.join(tmp, `base${counter}.lua`);
  const theirsPath = path.join(tmp, `theirs${counter}.lua`);
  fs.writeFileSync(oursPath, ours, 'utf8');
  fs.writeFileSync(basePath, base, 'utf8');
  fs.writeFileSync(theirsPath, theirs, 'utf8');

  let merged = '';
  let conflicts = 0;
  try {
    merged = execFileSync(
      'git',
      ['merge-file', '--diff3', ...(UNION ? ['--union'] : []), '-p', oursPath, basePath, theirsPath],
      { cwd: PROJECT, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }
    );
  } catch (error) {
    merged = error.stdout || '';
    conflicts = typeof error.status === 'number' ? error.status : 1;
  }
  return { merged, conflicts };
}

const report = [];
const conflicted = [];

for (const pack of PACKAGES) {
  const dir = path.join(ROOT, pack, 'src');
  if (!fs.existsSync(dir)) continue;

  let changed = 0;
  let conflictedInPack = 0;

  for (const file of walk(dir)) {
    const rel = path.relative(dir, file);
    const target = path.join(SRC, rel);
    const theirs = fs.readFileSync(file, 'utf8');
    const ours = fs.existsSync(target) ? fs.readFileSync(target, 'utf8') : '';
    if (ours === theirs) continue;

    const base = gitBase(rel);
    // Файла не было в базе — пакет приносит его целиком. Сливать нечего,
    // иначе union задублирует содержимое и в модуле окажется два return.
    let merged;
    let conflicts = 0;
    if (!base) {
      merged = theirs;
    } else {
      const result = mergeFile(ours, base, theirs);
      merged = result.merged;
      conflicts = result.conflicts;
    }

    if (conflicts > 0) {
      conflictedInPack += 1;
      conflicted.push(rel);
    }
    changed += 1;
    if (!DRY) {
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.writeFileSync(target, merged, 'utf8');
    }
  }

  report.push(`${pack}: изменено файлов ${changed}, с конфликтами ${conflictedInPack}`);
}

console.log(report.join('\n'));
if (conflicted.length) {
  console.log('\nконфликты (нужна ручная проверка):');
  for (const rel of conflicted) console.log('  ' + rel);
}
console.log(`\nвременная папка: ${tmp}`);
if (DRY) console.log('режим --dry: файлы не изменены');
