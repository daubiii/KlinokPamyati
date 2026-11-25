#!/usr/bin/env node
// reapply-fixes.js — возвращает правки, которые новые пакеты (skills_fx,
// chests, worldmap) затёрли своими более старыми версиями файлов.
//
// Каждая правка идемпотентна: если уже стоит — пропускается.
'use strict';
const fs = require('fs');
const path = require('path');

const SRC = 'C:\\Users\\artem\\KlinokPamyati\\src';
const report = [];

function read(rel) {
  return fs.readFileSync(path.join(SRC, rel), 'utf8');
}
function write(rel, text) {
  fs.writeFileSync(path.join(SRC, rel), text, 'utf8');
}

// ---------- 1. Loot.lua: данные оружия этажей 3–5 ----------
{
  const rel = 'ReplicatedStorage/Shared/Config/Loot.lua';
  let text = read(rel);
  if (text.includes('LootFloor3')) {
    report.push('Loot.lua: уже есть');
  } else {
    const anchor = 'Loot.StarterWeapons = { warrior = "rusty_sword", mage = LootMage.StarterWeapon }';
    if (!text.includes(anchor)) {
      report.push('Loot.lua: НЕ НАЙДЕН якорь');
    } else {
      const block = `${anchor}

-- Этажи 3–5 «Псарни охоты», «Кузня Основателя», «Архив Хрониста».
-- Пакеты обновлений — ветки от разных баз: эта связка терялась при наложении,
-- и оружие этажей 3–5 не находилось по id (give отвечал «нет оружия»), а сундуки
-- этих этажей не имели пула.
local FLOOR_LOOT = {
	[3] = require(script.Parent.LootFloor3),
	[4] = require(script.Parent.LootFloor4),
	[5] = require(script.Parent.LootFloor5),
}
for floor = 3, 5 do
	local data = FLOOR_LOOT[floor]
	for abilityId, ability in pairs(data.Abilities) do
		Loot.Abilities[abilityId] = ability
	end
	for passiveId, passive in pairs(data.Passives) do
		Loot.Passives[passiveId] = passive
	end
	for _, weapon in ipairs(data.Weapons) do
		weapon.floor = floor
		table.insert(Loot.Weapons, weapon)
	end
end

Loot.ChestWeightsByFloor[3] = FLOOR_LOOT[3].ChestWeights
Loot.ChestWeightsByFloor[4] = FLOOR_LOOT[4].ChestWeights
Loot.ChestWeightsByFloor[5] = FLOOR_LOOT[5].ChestWeights`;
      text = text.replace(anchor, block);
      write(rel, text);
      report.push('Loot.lua: возвращены данные этажей 3–5');
    }
  }
}

// ---------- 2. DebugCommands: алиасы оружия 3–5 ----------
{
  const rel = 'ServerScriptService/Systems/DebugCommands.lua';
  let text = read(rel);
  if (text.includes('cleaver = "hunt_cleaver"')) {
    report.push('DebugCommands.lua: алиасы уже есть');
  } else {
    const anchor = '\tkey = "gatekeeper_key",';
    if (!text.includes(anchor)) {
      report.push('DebugCommands.lua: НЕ НАЙДЕН якорь');
    } else {
      const aliases = `\t-- этаж 3
\tcleaver = "hunt_cleaver",
\tbroad = "hunt_broadsword",
\tbear = "bear_mace",
\tfang = "pack_fang",
\ttrap = "trap_maul",
\troyal = "royal_scythe",
\tfalconer = "falconer_saber",
\t-- этаж 4
\tcast = "cast_cleaver",
\tquench = "quench_blade",
\tapprentice = "apprentice_hammer",
\tcrucible = "crucible_maul",
\tsearing = "searing_blade",
\tanvil = "anvil_hammer",
\theart = "forge_heart_blade",
\tslag = "slag_scythe",
\tunfinished = "unfinished_blade",
\t-- этаж 5
\tpaper = "paper_knife",
\ttome = "tome_hammer",
\tbookmark = "bookmark_blade",
\tquill = "quill_blade",
\tseal = "seal_hammer",
\thourglass = "hourglass_maul",
\tink = "ink_blade",
\toblivion = "oblivion_scythe",
\tmemory = "memory_blade",`;
      text = text.replace(anchor, `${anchor}\n${aliases}`);
      write(rel, text);
      report.push('DebugCommands.lua: возвращены алиасы 3–5');
    }
  }
}

// ---------- 3. Bootstrap.client: WeaponPresence и BossMovesFx ----------
{
  const rel = 'StarterPlayer/StarterPlayerScripts/Bootstrap.client.lua';
  let text = read(rel);
  const additions = [];
  if (!text.includes('WeaponPresence')) {
    additions.push('\t"WeaponPresence", -- легендарки/секретки: аура, пульс света, кольцо присутствия');
  }
  if (!text.includes('BossMovesFx')) {
    additions.push('\t"BossMovesFx", -- фирменные атаки боссов: разметка, решётки, волны, книга');
  }
  if (additions.length === 0) {
    report.push('Bootstrap.client: контроллеры уже есть');
  } else {
    const anchor = '\t"StationController",';
    if (!text.includes(anchor)) {
      report.push('Bootstrap.client: НЕ НАЙДЕН якорь');
    } else {
      text = text.replace(anchor, `${anchor}\n${additions.join('\n')}`);
      write(rel, text);
      report.push(`Bootstrap.client: добавлено ${additions.length} контроллеров`);
    }
  }
}

// ---------- 4. Ui.screen: respectInset + FloorUiController ----------
{
  const rel = 'StarterPlayer/StarterPlayerScripts/Lib/Ui.lua';
  let text = read(rel);
  if (text.includes('respectInset')) {
    report.push('Ui.lua: respectInset уже есть');
  } else {
    const sig = 'function Ui.screen(name: string, order: number?)';
    if (!text.includes(sig)) {
      report.push('Ui.lua: НЕ НАЙДЕНА сигнатура');
    } else {
      text = text.replace(
        sig,
        `-- respectInset = true — учитывать верхнюю панель Roblox.
function Ui.screen(name: string, order: number?, respectInset: boolean?)`
      );
      text = text.replace('\tgui.IgnoreGuiInset = true', '\tgui.IgnoreGuiInset = not respectInset');
      write(rel, text);
      report.push('Ui.lua: добавлен respectInset');
    }
  }

  const floorRel = 'StarterPlayer/StarterPlayerScripts/Controllers/FloorUiController.lua';
  let floorText = read(floorRel);
  if (floorText.includes('Ui.screen("KlinokFloorUi", 3, true)')) {
    report.push('FloorUiController: уже с учётом панели');
  } else if (floorText.includes('Ui.screen("KlinokFloorUi", 3)')) {
    floorText = floorText.replace('Ui.screen("KlinokFloorUi", 3)', 'Ui.screen("KlinokFloorUi", 3, true)');
    write(floorRel, floorText);
    report.push('FloorUiController: включён respectInset');
  } else {
    report.push('FloorUiController: вызов не найден');
  }
}

// ---------- 5. DialogueWindow: убрать «кинорамку» ----------
{
  const rel = 'StarterPlayer/StarterPlayerScripts/Windows/DialogueWindow.lua';
  let text = read(rel);
  if (text.includes('Кинорамка убрана')) {
    report.push('DialogueWindow: кинорамки уже нет');
  } else {
    const marker = '\t-- кинорамка';
    const start = text.indexOf(marker);
    const endMarker = '\trefs.barBottom = bar(false)';
    const end = text.indexOf(endMarker);
    if (start < 0 || end < 0) {
      report.push('DialogueWindow: НЕ НАЙДЕН блок кинорамки');
    } else {
      text = text.slice(0, start) +
        '\t-- Кинорамка убрана: при разговоре с жителями чёрные полосы мешали.\n' +
        '\trefs.barTop = nil\n\trefs.barBottom = nil' +
        text.slice(end + endMarker.length);
      write(rel, text);
      report.push('DialogueWindow: кинорамка убрана');
    }
  }
}

console.log(report.join('\n'));
