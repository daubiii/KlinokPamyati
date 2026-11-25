// patch-atlas-ids.js — вписывает rbxassetid загруженных атласов в конфиги.
'use strict';
const fs = require('fs');
const path = require('path');

const CONFIG = 'C:\\Users\\artem\\KlinokPamyati\\src\\ReplicatedStorage\\Shared\\Config';

const patches = [
  ['ChestArt.lua', 'ChestArt.Atlas = ""', 'ChestArt.Atlas = "rbxassetid://73385458916915"'],
  ['TalentArt.lua', 'TalentArt.Atlas = ""', 'TalentArt.Atlas = "rbxassetid://108258774224049"'],
  ['TalentArt.lua', 'TalentArt.BgWarrior = ""', 'TalentArt.BgWarrior = "rbxassetid://134354485933824"'],
  ['TalentArt.lua', 'TalentArt.BgMage = ""', 'TalentArt.BgMage = "rbxassetid://128284221473649"'],
  ['TalentArt.lua', 'TalentArt.BgAssassin = ""', 'TalentArt.BgAssassin = "rbxassetid://120498531444703"'],
  ['UiAssets.lua', 'UiAssets.PaperAtlas = ""', 'UiAssets.PaperAtlas = "rbxassetid://130197875642411"'],
  ['UiAssets.lua', 'UiAssets.PaperDesk = ""', 'UiAssets.PaperDesk = "rbxassetid://97724648764340"'],
  ['AbilityIcons345.lua', 'atlas = "", -- rbxassetid://… после загрузки abilities345_atlas.png', 'atlas = "rbxassetid://122076395053918", -- abilities345_atlas.png'],
];

const report = [];
const byFile = new Map();
for (const [file, from, to] of patches) {
  if (!byFile.has(file)) byFile.set(file, []);
  byFile.get(file).push({ from, to });
}

for (const [file, list] of byFile) {
  const full = path.join(CONFIG, file);
  let text = fs.readFileSync(full, 'utf8');
  for (const { from, to } of list) {
    if (text.includes(to)) {
      report.push(`  уже стоит: ${file}`);
      continue;
    }
    if (!text.includes(from)) {
      report.push(`  НЕ НАЙДЕНО в ${file}: ${from.slice(0, 40)}`);
      continue;
    }
    text = text.split(from).join(to);
    report.push(`  ok ${file}: ${to.slice(0, 60)}`);
  }
  fs.writeFileSync(full, text, 'utf8');
}

console.log(report.join('\n'));
