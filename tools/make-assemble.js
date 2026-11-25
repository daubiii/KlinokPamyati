// make-assemble.js — готовит сборочные скрипты, которые не требуют `require`
// конфигов (Studio блокирует require модулей с Capabilities: Network).
//
// Данные модуля встраиваются текстом и загружаются через loadstring — это
// разрешено в потоке MCP. Результат кладётся в tools/assemble/.
'use strict';
const fs = require('fs');
const path = require('path');

const PROJ = 'C:\\Users\\artem\\KlinokPamyati';
const OUT = path.join(PROJ, 'tools', 'assemble');

function readConfig(name) {
  const file = path.join(PROJ, 'src', 'ReplicatedStorage', 'Shared', 'Config', name + '.lua');
  return fs.readFileSync(file, 'utf8');
}

function longString(source) {
  // Подбираем разделитель, которого нет в тексте.
  for (let level = 1; level <= 5; level += 1) {
    const eq = '='.repeat(level);
    if (!source.includes(`]${eq}]`)) {
      return `[${eq}[\n${source}\n]${eq}]`;
    }
  }
  throw new Error('не подобрать разделитель');
}

const header = `-- СГЕНЕРИРОВАНО tools/make-assemble.js
-- Оригинал требует модуль конфига через require; в потоке MCP это запрещено
-- (Capabilities: Network), поэтому исходник модуля встроен и грузится loadstring.
`;

fs.mkdirSync(OUT, { recursive: true });
const report = [];

// ---------- 1. Оружие этажей 3–5 ----------
{
  const original = fs.readFileSync(path.join(PROJ, 'tools', 'weapons', 'AssembleWeaponsFloors345.lua'), 'utf8');
  const floors = [3, 4, 5].map((floor) => ({ floor, name: 'WeaponMeshDataFloor' + floor }));
  const sources = floors
    .map(({ floor, name }) => `\t[${floor}] = ${longString(readConfig(name))},`)
    .join('\n');

  let body = original.replace('local DATA = require(module)', 'local DATA = __FLOOR_DATA[floor]');

  if (body === original) {
    report.push('оружие 3–5: ПАТЧ НЕ ПРИМЕНИЛСЯ');
  } else {
    const loader = `
local __RAW = {
${sources}
}
local __FLOOR_DATA = {}
for __floor, __src in pairs(__RAW) do
	local __ok, __data = pcall(loadstring, __src, "WeaponMeshDataFloor" .. __floor)
	if __ok and type(__data) == "function" then
		local __ran, __result = pcall(__data)
		if __ran then
			__FLOOR_DATA[__floor] = __result
		end
	end
end
`;
    const text = `${header}${loader}\n${body}`;
    fs.writeFileSync(path.join(OUT, 'AssembleWeaponsFloors345.lua'), text, 'utf8');
    report.push(`оружие 3–5: ок (${Math.round(text.length / 1024)} КБ)`);
  }
}

// ---------- 2. Броня мага ----------
{
  const original = fs.readFileSync(path.join(PROJ, 'tools', 'mage-armor', 'AssembleMageArmor.lua'), 'utf8');
  const marker = /local DATA = require\(([^)]*)\)/;
  const match = original.match(marker);
  if (!match) {
    report.push('броня мага: не нашёл local DATA = require(...)');
  } else {
    const body = original.replace(marker, 'local DATA = __DATA');
    const text = `${header}local __DATA = assert(loadstring(${longString(readConfig('MageArmorMeshData'))}, "MageArmorMeshData"))()\n\n${body}`;
    fs.writeFileSync(path.join(OUT, 'AssembleMageArmor.lua'), text, 'utf8');
    report.push(`броня мага: ок (${Math.round(text.length / 1024)} КБ)`);
  }
}

// ---------- 3. Посохи мага ----------
{
  const original = fs.readFileSync(path.join(PROJ, 'tools', 'mage-weapons', 'AssembleMageWeapons.lua'), 'utf8');
  const marker = /local DATA = require\(([^)]*)\)/;
  const match = original.match(marker);
  if (!match) {
    report.push('посохи мага: не нашёл local DATA = require(...)');
  } else {
    const body = original.replace(marker, 'local DATA = __DATA');
    const text = `${header}local __DATA = assert(loadstring(${longString(readConfig('WeaponMeshDataMage'))}, "WeaponMeshDataMage"))()\n\n${body}`;
    fs.writeFileSync(path.join(OUT, 'AssembleMageWeapons.lua'), text, 'utf8');
    report.push(`посохи мага: ок (${Math.round(text.length / 1024)} КБ)`);
  }
}

console.log(report.join('\n'));
