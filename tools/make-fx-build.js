#!/usr/bin/env node
// make-fx-build.js — собирает скрипт, который строит шаблоны FX этажей 3–5
// без require и без временной папки в ServerStorage (их блокирует sandbox).
//
// Приём тот же, что со сборочными скриптами оружия: исходники модулей
// встраиваются текстом и грузятся через loadstring (в Edit-режиме доступен).
'use strict';
const fs = require('fs');
const path = require('path');

const SRC = 'C:\\Users\\artem\\KlinokPamyati\\src\\ReplicatedStorage\\Shared\\Fx';
const OUT = 'C:\\Users\\artem\\KlinokPamyati\\tools\\fx\\BuildFx345_run.lua';

function longString(source) {
  for (let level = 1; level <= 6; level += 1) {
    const eq = '='.repeat(level);
    if (!source.includes(`]${eq}]`)) return `[${eq}[\n${source}\n]${eq}]`;
  }
  throw new Error('не подобрать разделитель');
}

const specSource = fs.readFileSync(path.join(SRC, 'FxWeapons345.lua'), 'utf8');
let builderSource = fs.readFileSync(path.join(SRC, 'FxBuilder345.lua'), 'utf8');

const requireLine = 'local Spec = require(script.Parent.FxWeapons345)';
if (!builderSource.includes(requireLine)) {
  throw new Error('не нашёл строку require в FxBuilder345 — правь генератор');
}
builderSource = builderSource.replace(requireLine, 'local Spec = __FX_SPEC__');

const script = `-- СГЕНЕРИРОВАНО tools/make-fx-build.js
-- Строит шаблоны FX этажей 3-5 в ReplicatedStorage.FX.
-- Оригинал требует модули через require и стейджит копии в ServerStorage —
-- и то и другое блокирует sandbox MCP-потока. Здесь исходники встроены
-- и грузятся loadstring, запись идёт прямо в ReplicatedStorage.FX.

local __SPEC_SRC = ${longString(specSource)}

local __BUILDER_SRC = ${longString(builderSource)}

local __spec, __specErr = loadstring(__SPEC_SRC, "FxWeapons345")
if not __spec then
	return "FxWeapons345 не загрузился: " .. tostring(__specErr)
end
local __BUILDER, __builderErr = loadstring(__BUILDER_SRC, "FxBuilder345")
if not __BUILDER then
	return "FxBuilder345 не загрузился: " .. tostring(__builderErr)
end

__FX_SPEC__ = __spec()
local FxBuilder345 = __BUILDER()

local made, total = FxBuilder345.build({ rebuild = true })

local fx = game.ReplicatedStorage:FindFirstChild("FX")
local report = {}
for _, name in ipairs({ "Hunt", "Forge", "Chron", "Weapon", "Presence" }) do
	local folder = fx and fx:FindFirstChild(name)
	local kids = 0
	if folder then
		for _ in ipairs(folder:GetChildren()) do
			kids += 1
		end
	end
	table.insert(report, name .. ": " .. (folder and tostring(kids) or "НЕТ"))
end
return ("шаблоны: создано %s из %s; итог — %s"):format(tostring(made), tostring(total), table.concat(report, ", "))
`;

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, script, 'utf8');
console.log(`готово: ${OUT} (${Math.round(script.length / 1024)} КБ)`);
