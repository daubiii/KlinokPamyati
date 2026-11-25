#!/usr/bin/env node
// audit-packages.js — ищет потерянные правки при последовательном наложении
// пакетов. Пакеты — ветки от разных баз: более поздний перезаписывает файл
// своей версией, и блоки из раннего могут исчезнуть (как случилось с Loot.lua).
//
// Для каждого файла, который есть в нескольких пакетах, сравниваем версию,
// которая сейчас лежит в проекте, с версиями каждого пакета и считаем, сколько
// «содержательных» строк пакета в проекте отсутствует.
'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = 'C:\\Users\\artem\\Desktop\\Новая папка (3)';
const SRC = 'C:\\Users\\artem\\KlinokPamyati\\src';

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

function meaningfulLines(text) {
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 22 && !line.startsWith('--'));
}

function sha(text) {
  return crypto.createHash('sha256').update(text).digest('hex').slice(0, 12);
}

// path -> { package: text }
const map = new Map();

for (const pack of PACKAGES) {
  const dir = path.join(ROOT, pack, 'src');
  if (!fs.existsSync(dir)) continue;
  for (const file of walk(dir)) {
    const rel = path.relative(dir, file);
    if (!map.has(rel)) map.set(rel, new Map());
    map.get(rel).set(pack, fs.readFileSync(file, 'utf8'));
  }
}

const report = [];
let shared = 0;
let suspicious = 0;

for (const [rel, versions] of map) {
  if (versions.size < 2) continue;
  shared += 1;

  const projectFile = path.join(SRC, rel);
  if (!fs.existsSync(projectFile)) {
    report.push(`ПРОПУЩЕН В ПРОЕКТЕ: ${rel}`);
    continue;
  }
  const current = fs.readFileSync(projectFile, 'utf8');
  const currentSet = new Set(meaningfulLines(current));

  const missingByPack = [];
  let currentMatches = [];
  for (const [pack, text] of versions) {
    if (sha(text) === sha(current)) currentMatches.push(pack);
    const lines = meaningfulLines(text);
    const missing = lines.filter((line) => !currentSet.has(line));
    if (missing.length > 0) missingByPack.push({ pack, count: missing.length, sample: missing[0] });
  }

  if (missingByPack.length > 0) {
    suspicious += 1;
    const from = currentMatches.length ? currentMatches.join('+') : 'смешанная версия';
    report.push(
      `${rel}\n    сейчас: ${from}` +
        missingByPack
          .map((item) => `\n    нет ${String(item.count).padStart(3)} строк из ${item.pack}: ${item.sample.slice(0, 70)}`)
          .join('')
    );
  }
}

console.log(`общих файлов между пакетами: ${shared}; с потерями: ${suspicious}\n`);
console.log(report.join('\n'));
