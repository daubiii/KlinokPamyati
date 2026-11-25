#!/usr/bin/env node
// restore-files.js — восстанавливает указанные файлы из САМОГО СВЕЖЕГО пакета,
// который их содержит. Нужно после того, как union-слияние повредило файлы
// (несбалансированные then/end). Ручные правки в перечисленных ниже файлах
// сохраняются отдельно — их не трогаем.
'use strict';
const fs = require('fs');
const path = require('path');

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

// Файлы, которые union испортил, и которые надо вернуть к версии одного пакета.
// Наши собственные правки (UI, Loot, Weapons, VoxelWeaponBuilder) в список НЕ входят.
const TARGETS = [
  'ReplicatedStorage/Shared/Config/AbilityIcons345.lua',
  'ServerScriptService/Systems/AbilityService.lua',
  'ServerScriptService/Bootstrap.server.lua',
  'ServerScriptService/Systems/CombatService.lua',
  'ServerScriptService/Systems/DebugCommands.lua',
  'ServerScriptService/Systems/InventoryService.lua',
  'ServerScriptService/Systems/LootService.lua',
  'ServerScriptService/Systems/MageService.lua',
  'ServerScriptService/Systems/ManaService.lua',
  'ServerScriptService/Systems/WeaponAbilities.lua',
  'ServerScriptService/Systems/WeaponAbilitiesMage.lua',
  'ServerScriptService/Systems/DataService.lua',
  'StarterPlayer/StarterPlayerScripts/Bootstrap.client.lua',
  'StarterPlayer/StarterPlayerScripts/Controllers/AbilityController.lua',
  'StarterPlayer/StarterPlayerScripts/Controllers/PlayerAnimator.lua',
  'StarterPlayer/StarterPlayerScripts/Lib/PaperUi.lua',
  'StarterPlayer/StarterPlayerScripts/Lib/UiSound.lua',
  'StarterPlayer/StarterPlayerScripts/Lib/StationApi.lua',
  'StarterPlayer/StarterPlayerScripts/Windows/CharacterWindow.lua',
  'StarterPlayer/StarterPlayerScripts/Controllers/StationController.lua',
  'ReplicatedStorage/Shared/Config/Binds.lua',
  'ReplicatedStorage/Shared/Config/UiAssets.lua',
  'ReplicatedStorage/Shared/Config/TalentArt.lua',
  'ReplicatedStorage/Shared/Config/ChestArt.lua',
];

const report = [];
for (const rel of TARGETS) {
  let newest = null;
  let newestPack = '';
  for (const pack of PACKAGES) {
    const candidate = path.join(ROOT, pack, 'src', rel);
    if (fs.existsSync(candidate)) {
      newest = candidate;
      newestPack = pack;
    }
  }
  if (!newest) {
    report.push(`нет в пакетах: ${rel}`);
    continue;
  }
  const target = path.join(SRC, rel);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(newest, target);
  const lines = fs.readFileSync(target, 'utf8').split(/\r?\n/).length;
  report.push(`ok ${rel} <- ${newestPack} (${lines} строк)`);
}

console.log(report.join('\n'));
