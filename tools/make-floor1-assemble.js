#!/usr/bin/env node
// make-floor1-assemble.js — вариант AssembleFloor1.lua без require:
// поток MCP не может требовать модули с Capabilities: Network, поэтому
// FloorMapData встраивается текстом и грузится через loadstring.
'use strict';
const fs = require('fs');
const path = require('path');

const PROJ = 'C:\\Users\\artem\\KlinokPamyati';
const SOURCE = path.join(PROJ, 'tools', 'floor1map', 'AssembleFloor1.lua');
const DATA = path.join(PROJ, 'tools', 'data', 'FloorMapData.lua');
const OUT = path.join(PROJ, 'tools', 'floor1map', 'AssembleFloor1_run.lua');

function longString(source) {
  for (let level = 1; level <= 6; level += 1) {
    const eq = '='.repeat(level);
    if (!source.includes(`]${eq}]`)) return `[${eq}[\n${source}\n]${eq}]`;
  }
  throw new Error('не подобрать разделитель');
}

const original = fs.readFileSync(SOURCE, 'utf8');
const dataSource = fs.readFileSync(DATA, 'utf8');
const requireLine = 'local DATA = require(RS.Shared.Config.FloorMapData)';

if (!original.includes(requireLine)) {
  throw new Error('не нашёл строку require в AssembleFloor1.lua');
}

const body = original.replace(
  requireLine,
  `local __DATA_SRC = ${longString(dataSource)}
local __chunk = assert(loadstring(__DATA_SRC, "FloorMapData"))
local DATA = __chunk()`
);

const header = `-- СГЕНЕРИРОВАНО tools/make-floor1-assemble.js
-- Оригинал требует модуль конфига через require; в потоке MCP это запрещено
-- (Capabilities: Network), поэтому исходник встроен и грузится loadstring.

`;

fs.writeFileSync(OUT, header + body, 'utf8');
console.log(`готово: ${OUT} (${Math.round((header + body).length / 1024)} КБ)`);
