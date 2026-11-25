#!/usr/bin/env node
// sync.js — односторонняя синхронизация src/ -> DataModel в открытом Roblox Studio.
// Диск — источник правды. Studio — зеркало.
//
//   node tools/sync.js            синхронизировать всё
//   node tools/sync.js --dry      показать, что будет сделано
//   node tools/sync.js --only Config   только пути, содержащие подстроку
//
// Правила имён:
//   src/ReplicatedStorage/Shared/Config/Palette.lua        -> ModuleScript  ReplicatedStorage.Shared.Config.Palette
//   src/ServerScriptService/Main.server.lua                -> Script        ServerScriptService.Main
//   src/StarterPlayer/.../Hud.client.lua                   -> LocalScript   ...
'use strict';

const fs = require('fs');
const path = require('path');
const http = require('http');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'src');
const BRIDGE = { host: '127.0.0.1', port: Number(process.env.BRIDGE_PORT || 8799) };
const STUDIO_ID_ENV = process.env.STUDIO_ID || '';
let STUDIO_ID = STUDIO_ID_ENV;

// Идентификатор Studio меняется при каждом перезапуске — спрашиваем у моста.
function getStatus() {
  return new Promise((resolve, reject) => {
    const req = http.request({ host: BRIDGE.host, port: BRIDGE.port, path: '/status', method: 'GET' }, (res) => {
      let out = '';
      res.setEncoding('utf8');
      res.on('data', (c) => { out += c; });
      res.on('end', () => { try { resolve(JSON.parse(out)); } catch (e) { reject(e); } });
    });
    req.on('error', reject);
    req.end();
  });
}

const args = process.argv.slice(2);
const dry = args.includes('--dry');
const onlyIdx = args.indexOf('--only');
const only = onlyIdx >= 0 ? args[onlyIdx + 1] : null;

function classify(fileName) {
  if (fileName.endsWith('.server.lua')) return { cls: 'Script', name: fileName.slice(0, -'.server.lua'.length) };
  if (fileName.endsWith('.client.lua')) return { cls: 'LocalScript', name: fileName.slice(0, -'.client.lua'.length) };
  if (fileName.endsWith('.lua')) return { cls: 'ModuleScript', name: fileName.slice(0, -'.lua'.length) };
  return null;
}

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else out.push(full);
  }
  return out;
}

function buildOps() {
  const files = walk(SRC).filter((f) => f.endsWith('.lua'));
  const ops = [];
  for (const file of files) {
    const rel = path.relative(SRC, file).split(path.sep);
    const kind = classify(rel[rel.length - 1]);
    if (!kind) continue;
    const segments = rel.slice(0, -1).concat(kind.name);
    const dataModelPath = segments.join('.');
    if (only && !dataModelPath.toLowerCase().includes(only.toLowerCase())) continue;
    ops.push({ path: dataModelPath, className: kind.cls, source: fs.readFileSync(file, 'utf8'), file: rel.join('/') });
  }
  return ops;
}

const LUA_TEMPLATE = `
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local payload = HttpService:JSONDecode(__PAYLOAD__)
local ops = payload.ops or {}

local recordId
do
	local ok, id = pcall(function()
		return ChangeHistoryService:TryBeginRecording("KlinokPamyati sync")
	end)
	if ok then
		recordId = id
	end
end

local function splitPath(pathString)
	local parts = {}
	for segment in string.gmatch(pathString, "[^%.]+") do
		table.insert(parts, segment)
	end
	return parts
end

local function resolveRoot(name)
	local ok, service = pcall(function()
		return game:GetService(name)
	end)
	if ok and service then
		return service
	end
	return game:FindFirstChild(name)
end

local function resolvePath(parts, leafClass)
	local node = resolveRoot(parts[1])
	if not node then
		error("нет корня: " .. tostring(parts[1]))
	end
	for index = 2, #parts do
		local name = parts[index]
		local isLeaf = (index == #parts)
		local child = node:FindFirstChild(name)
		if not child then
			child = Instance.new(isLeaf and leafClass or "Folder")
			child.Name = name
			child.Parent = node
		elseif isLeaf and not child:IsA(leafClass) then
			error(("узел %s имеет класс %s, ожидался %s"):format(name, child.ClassName, leafClass))
		end
		node = child
	end
	return node
end

local report = {}
for _, op in ipairs(ops) do
	local ok, result = pcall(function()
		local parts = splitPath(op.path)
		local instance = resolvePath(parts, op.className)
		local existed = instance.Source ~= nil and instance.Source ~= ""
		instance.Source = op.source
		return existed and "updated" or "created"
	end)
	if ok then
		table.insert(report, ("ok %s %s (%d bytes)"):format(result, op.path, #op.source))
	else
		table.insert(report, ("FAIL %s: %s"):format(op.path, tostring(result)))
	end
end

if recordId then
	pcall(function()
		ChangeHistoryService:FinishRecording(recordId, Enum.FinishRecordingOperation.Commit)
	end)
end

return table.concat(report, "\\n")
`;

function post(pathname, body) {
  return new Promise((resolve, reject) => {
    const data = Buffer.from(JSON.stringify(body));
    const req = http.request(
      { host: BRIDGE.host, port: BRIDGE.port, path: pathname, method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': data.length } },
      (res) => {
        let out = '';
        res.setEncoding('utf8');
        res.on('data', (c) => { out += c; });
        res.on('end', () => {
          try { resolve(JSON.parse(out)); } catch (e) { reject(new Error('bad bridge response: ' + out.slice(0, 300))); }
        });
      }
    );
    req.on('error', reject);
    req.setTimeout(600000, () => req.destroy(new Error('bridge timeout')));
    req.write(data);
    req.end();
  });
}

(async () => {
  if (!STUDIO_ID) {
    const status = await getStatus();
    const list = (status && status.studios) || [];
    STUDIO_ID = (list[0] && list[0].id) || '';
  }
  if (!STUDIO_ID) {
    throw new Error('Studio не подключена к мосту (порт 8799)');
  }
  const ops = buildOps();
  if (ops.length === 0) {
    console.log('Нечего синхронизировать.');
    return;
  }
  console.log(`Файлов: ${ops.length}`);
  for (const op of ops) console.log(`  ${op.file}  ->  ${op.className} game.${op.path}`);
  if (dry) { console.log('\n--dry: изменения не отправлены.'); return; }

  // Батчим по 8 файлов, чтобы не упереться в лимит размера кода.
  const batches = [];
  for (let i = 0; i < ops.length; i += 8) batches.push(ops.slice(i, i + 8));

  for (const [index, batch] of batches.entries()) {
    const json = JSON.stringify({ ops: batch.map(({ path: p, className, source }) => ({ path: p, className, source })) });
    if (/\\u00[0-9a-f]{2}/i.test(json)) {
      throw new Error('В исходниках есть управляющие символы (\\u00XX) — Luau их не понимает. Батч ' + index);
    }
    const literal = JSON.stringify(json);
    const code = LUA_TEMPLATE.replace('__PAYLOAD__', literal);
    const result = await post('/tool', {
      name: 'execute_luau',
      arguments: { code, datamodel_type: 'Edit', studio_id: STUDIO_ID },
      timeoutMs: 300000,
    });
    if (result.error) throw new Error('bridge: ' + JSON.stringify(result.error));
    if (result.isError) throw new Error('Luau: ' + result.text);
    console.log(`\n[батч ${index + 1}/${batches.length}]`);
    console.log(result.text || '(пустой ответ)');
  }
})().catch((e) => {
  console.error('ОШИБКА: ' + String((e && e.message) || e));
  process.exit(1);
});
