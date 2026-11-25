// fix-waveindex.js — исправляет баг «в комнате нет врагов, дверь не открывается».
//
// Причина: у комнаты не был инициализирован waveIndex. В activateRoom стоит
// условие room.waveIndex == 0, а nil == 0 — ложь, поэтому первая волна
// не спавнилась никогда: комната оставалась active без врагов, дверь заперта.
'use strict';
const fs = require('fs');
const path = require('path');

const SYSTEMS = 'C:\\Users\\artem\\KlinokPamyati\\src\\ServerScriptService\\Systems';

function patch(file, replacements) {
  const full = path.join(SYSTEMS, file);
  let text = fs.readFileSync(full, 'utf8');
  const out = [];
  for (const { from, to, label } of replacements) {
    if (text.includes(to) && !text.includes(from)) {
      out.push(`  уже: ${label}`);
      continue;
    }
    if (!text.includes(from)) {
      out.push(`  НЕ НАЙДЕНО: ${label}`);
      continue;
    }
    text = text.split(from).join(to);
    out.push(`  ok: ${label}`);
  }
  fs.writeFileSync(full, text, 'utf8');
  return out;
}

const report = [];

report.push('FloorBuilder.lua');
report.push(...patch('FloorBuilder.lua', [
  {
    label: 'waveIndex = 0 в записи комнаты',
    from: `		state = "idle",
		enemies = {},`,
    to: `		state = "idle",
		waveIndex = 0,
		enemies = {},`,
  },
]));

report.push('FloorService.lua');
report.push(...patch('FloorService.lua', [
  {
    label: 'защита в activateRoom',
    from: 'if room.state == "active" and room.waveIndex == 0 then',
    to: 'if room.state == "active" and (room.waveIndex or 0) == 0 then',
  },
  {
    label: 'защита в roomAdvance',
    from: 'if room.waveIndex < #room.waves then',
    to: 'if (room.waveIndex or 0) < #room.waves then',
  },
]));

console.log(report.join('\n'));
