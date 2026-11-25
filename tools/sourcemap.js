#!/usr/bin/env node
// sourcemap.js — sourcemap.json в формате Rojo для luau-lsp.
// Те же правила имён, что в sync.js: *.server.lua -> Script,
// *.client.lua -> LocalScript, *.lua -> ModuleScript, папка -> Folder.
//
//   node tools/sourcemap.js                 пишет sourcemap.json в корень
//   luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'src');

const SERVICES = {
  ReplicatedStorage: 'ReplicatedStorage',
  ServerScriptService: 'ServerScriptService',
  StarterPlayer: 'StarterPlayer',
  StarterPlayerScripts: 'StarterPlayerScripts',
  ServerStorage: 'ServerStorage',
  Workspace: 'Workspace',
};

function classify(fileName) {
  if (fileName.endsWith('.server.lua')) return { className: 'Script', name: fileName.slice(0, -'.server.lua'.length) };
  if (fileName.endsWith('.client.lua')) return { className: 'LocalScript', name: fileName.slice(0, -'.client.lua'.length) };
  if (fileName.endsWith('.lua')) return { className: 'ModuleScript', name: fileName.slice(0, -'.lua'.length) };
  return null;
}

function walk(dir, depth) {
  const children = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      const className = (depth === 0 || (depth === 1 && entry.name === 'StarterPlayerScripts')) ? (SERVICES[entry.name] || 'Folder') : 'Folder';
      children.push({ name: entry.name, className, children: walk(full, depth + 1) });
    } else {
      const kind = classify(entry.name);
      if (kind) children.push({ name: kind.name, className: kind.className, filePaths: [path.relative(ROOT, full).split(path.sep).join('/')] });
    }
  }
  return children;
}

const map = { name: 'KlinokPamyati', className: 'DataModel', children: walk(SRC, 0) };
fs.writeFileSync(path.join(ROOT, 'sourcemap.json'), JSON.stringify(map, null, 1));
console.log('sourcemap.json готов');
