#!/usr/bin/env node
// count-features.js — сверяет заявленное в README с тем, что реально лежит
// в конфигах пакетов. Считает записи (пары name = "...") и ключи верхнего уровня.
'use strict';
const fs = require('fs');
const path = require('path');

const SRC = 'C:\\Users\\artem\\KlinokPamyati\\src';

function read(rel) {
  const full = path.join(SRC, rel);
  if (!fs.existsSync(full)) return null;
  return fs.readFileSync(full, 'utf8');
}

function countNames(text) {
  return (text.match(/\bname\s*=\s*"/g) || []).length;
}

function topKeys(text) {
  const keys = new Set();
  const re = /^\s*(?:\[\s*"([^"]+)"\s*\]|([A-Za-z_][A-Za-z0-9_]*))\s*=\s*\{/gm;
  let m;
  while ((m = re.exec(text)) !== null) keys.add(m[1] || m[2]);
  return [...keys];
}

const checks = [
  ['ReplicatedStorage/Shared/Config/WeaponMeshDataMage.lua', 'посохи мага: записей'],
  ['ReplicatedStorage/Shared/Config/MageArmorMeshData.lua', 'детали брони мага: записей'],
  ['ReplicatedStorage/Shared/Config/WeaponMeshDataFloor3.lua', 'оружие этажа 3: записей'],
  ['ReplicatedStorage/Shared/Config/WeaponMeshDataFloor4.lua', 'оружие этажа 4: записей'],
  ['ReplicatedStorage/Shared/Config/WeaponMeshDataFloor5.lua', 'оружие этажа 5: записей'],
  ['ReplicatedStorage/Shared/Config/Talents.lua', 'таланты: записей'],
  ['ReplicatedStorage/Shared/Config/ChestDesigns.lua', 'сундуки: записей'],
  ['ReplicatedStorage/Shared/Config/BossMoves.lua', 'боссы: записей'],
  ['ReplicatedStorage/Shared/Config/BossIntros.lua', 'сцены боссов: записей'],
  ['ReplicatedStorage/Shared/Config/Enemies.lua', 'враги: записей'],
];

for (const [rel, label] of checks) {
  const text = read(rel);
  if (text === null) {
    console.log(`${label.padEnd(34)} ФАЙЛА НЕТ (${rel})`);
    continue;
  }
  const names = countNames(text);
  const keys = topKeys(text);
  const keyPreview = keys.slice(0, 8).join(', ') + (keys.length > 8 ? '…' : '');
  console.log(`${label.padEnd(34)} ${String(names).padStart(4)}  | ключи: ${keyPreview}`);
}
