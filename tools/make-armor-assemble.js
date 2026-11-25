#!/usr/bin/env node
// make-armor-assemble.js — готовит сборочный скрипт брони, которому не нужен
// require: поток MCP не может требовать модули с Capabilities: Network.
// Данные ArmorFloorsMeshData встраиваются текстом и грузятся через loadstring.
'use strict';
const fs = require('fs');
const path = require('path');

const PROJ = 'C:\\Users\\artem\\KlinokPamyati';
const SOURCE = path.join(PROJ, 'tools', 'armor-floors', 'AssembleArmorFloors.lua');
const DATA = path.join(PROJ, 'src', 'ReplicatedStorage', 'Shared', 'Config', 'ArmorFloorsMeshData.lua');
const OUT = path.join(PROJ, 'tools', 'armor-floors', 'AssembleArmorFloors_run.lua');

function longString(source) {
  for (let level = 1; level <= 6; level += 1) {
    const eq = '='.repeat(level);
    if (!source.includes(`]${eq}]`)) return `[${eq}[\n${source}\n]${eq}]`;
  }
  throw new Error('не подобрать разделитель');
}

const original = fs.readFileSync(SOURCE, 'utf8');
const dataSource = fs.readFileSync(DATA, 'utf8');

const requireLine = 'local DATA = require(RS.Shared.Config.ArmorFloorsMeshData)';
if (!original.includes(requireLine)) {
  throw new Error('не нашёл строку require в AssembleArmorFloors.lua');
}

const body = original.replace(
  requireLine,
  `local __DATA_SRC = ${longString(dataSource)}
local __chunk = assert(loadstring(__DATA_SRC, "ArmorFloorsMeshData"))
local DATA = __chunk()`
);

const header = `-- СГЕНЕРИРОВАНО tools/make-armor-assemble.js
-- Оригинал требует модуль конфига через require; в потоке MCP это запрещено
-- (Capabilities: Network), поэтому исходник встроен и грузится loadstring.

`;

fs.writeFileSync(OUT, header + body, 'utf8');
console.log(`готово: ${OUT} (${Math.round((header + body).length / 1024)} КБ)`);
