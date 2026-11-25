#!/usr/bin/env node
// import-rbxmx.js — вставить простую модель .rbxmx в открытую Studio через мост.
// Studio не пускает скрипты к InsertService:LoadLocalAsset, поэтому файл
// разбирается здесь и собирается в Studio кодом (Edit-режим).
//
//   node tools/import-rbxmx.js файл.rbxmx                       → в Workspace
//   node tools/import-rbxmx.js файл.rbxmx --replace Workspace.Hub.Village.DailyChest
//        (новая модель встаёт в pivot старой, старая удаляется, родитель тот же)
//   node tools/import-rbxmx.js файл.rbxmx --pivot-to Workspace.Hub.Village.ShardShop
//        (новая модель в pivot указанной, родитель — её родитель)
//   node tools/import-rbxmx.js файл.rbxmx --into ReplicatedStorage
//        (в указанный контейнер; ребёнок с тем же именем заменяется)
//
// Понимает только то, что лежит в моделях UI v2: Part/WedgePart/Model/
// Attachment/PointLight и свойства string, bool, float, token, Color3,
// Color3uint8, Vector3, CoordinateFrame, Ref (PrimaryPart). Скрипты не вставляет.
'use strict';

const fs = require('fs');
const http = require('http');

const BRIDGE = { host: '127.0.0.1', port: Number(process.env.BRIDGE_PORT || 8799) };
const args = process.argv.slice(2);
const file = args[0];
const opt = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : null;
};
if (!file) {
  console.error('укажи файл .rbxmx');
  process.exit(2);
}

// ===== разбор XML (без библиотек: формат Roblox простой и предсказуемый) =====
const xml = fs.readFileSync(file, 'utf8');
let pos = 0;

function decode(text) {
  return text.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&amp;/g, '&');
}

function readProperties(body) {
  const props = {};
  const re = /<(\w+) name="(\w+)">([\s\S]*?)<\/\1>/g;
  let m;
  while ((m = re.exec(body))) {
    const [, type, name, raw] = m;
    const field = (tag) => {
      const r = new RegExp(`<${tag}>([^<]*)</${tag}>`).exec(raw);
      return r ? Number(r[1]) : 0;
    };
    let value;
    switch (type) {
      case 'string': value = decode(raw); break;
      case 'bool': value = raw.trim() === 'true'; break;
      case 'float': case 'double': case 'int': value = Number(raw); break;
      case 'token': value = Number(raw); break;
      case 'Color3uint8': {
        const n = Number(raw) >>> 0;
        value = [(n >> 16) & 255, (n >> 8) & 255, n & 255];
        break;
      }
      case 'Color3': value = [field('R'), field('G'), field('B')]; break;
      case 'Vector3': value = [field('X'), field('Y'), field('Z')]; break;
      case 'CoordinateFrame':
        value = ['X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22'].map(field);
        break;
      case 'Ref': value = raw.trim(); break;
      case 'BinaryString':
        if (raw.trim() !== '') throw new Error(`непустой BinaryString ${name} не поддержан`);
        continue;
      default:
        throw new Error(`неизвестный тип свойства ${type} (${name})`);
    }
    props[name] = { t: type, v: value };
  }
  return props;
}

function readItem() {
  const open = /<Item class="(\w+)" referent="(\w+)">/y;
  open.lastIndex = pos;
  const m = open.exec(xml);
  if (!m) throw new Error('ожидался <Item> на позиции ' + pos);
  pos = open.lastIndex;
  const node = { c: m[1], r: m[2], p: {}, k: [] };
  if (/Script$/.test(node.c)) throw new Error('в модели есть скрипт — этот импорт их не ставит');
  for (;;) {
    while (/\s/.test(xml[pos])) pos++;
    if (xml.startsWith('<Properties>', pos)) {
      const end = xml.indexOf('</Properties>', pos);
      node.p = readProperties(xml.slice(pos + 12, end));
      pos = end + 13;
    } else if (xml.startsWith('<Item ', pos)) {
      node.k.push(readItem());
    } else if (xml.startsWith('</Item>', pos)) {
      pos += 7;
      return node;
    } else {
      throw new Error('непонятный фрагмент: ' + xml.slice(pos, pos + 60));
    }
  }
}

const start = xml.indexOf('<Item ');
pos = start;
const roots = [];
while (xml.startsWith('<Item ', pos)) {
  roots.push(readItem());
  while (/\s/.test(xml[pos])) pos++;
}
if (roots.length !== 1) throw new Error('ожидалась одна корневая модель, найдено ' + roots.length);
let count = 0;
(function walk(n) { count++; n.k.forEach(walk); })(roots[0]);

// ===== сборка в Studio =====
const LUA = `
local HttpService = game:GetService("HttpService")
local tree = HttpService:JSONDecode(__PAYLOAD__)
local mode, target = __MODE__, __TARGET__

local function resolve(path)
	local node = game
	for part in string.gmatch(path, "[^%.]+") do
		if node == game then
			node = game:GetService(part)
		else
			node = node:FindFirstChild(part)
		end
		if not node then return nil end
	end
	return node
end

local refs, pending = {}, {}
local renames = { size = "Size", shape = "Shape", Color3uint8 = "Color" }
local built = 0
local function build(node, parent)
	local inst = Instance.new(node.c)
	refs[node.r] = inst
	for name, prop in pairs(node.p) do
		local key = renames[name] or name
		local t, v = prop.t, prop.v
		if t == "Ref" then
			table.insert(pending, { inst = inst, key = key, ref = v })
		elseif t == "Color3uint8" then
			inst[key] = Color3.fromRGB(v[1], v[2], v[3])
		elseif t == "Color3" then
			inst[key] = Color3.new(v[1], v[2], v[3])
		elseif t == "Vector3" then
			inst[key] = Vector3.new(v[1], v[2], v[3])
		elseif t == "CoordinateFrame" then
			inst[key] = CFrame.new(table.unpack(v))
		elseif t == "token" then
			local ok = pcall(function() inst[key] = v end)
			if not ok then warn("token " .. key .. " = " .. tostring(v)) end
		else
			inst[key] = v
		end
	end
	for _, child in ipairs(node.k) do
		build(child, inst)
	end
	inst.Parent = parent
	built += 1
	if built % 400 == 0 then task.wait() end
	return inst
end

local model = build(tree, nil)
for _, p in ipairs(pending) do
	p.inst[p.key] = refs[p.ref]
end

local report = {}
local parent = workspace
if mode == "replace" or mode == "pivot" then
	local old = resolve(target)
	if not old then
		model:Destroy()
		return "нет " .. target
	end
	parent = old.Parent
	model:PivotTo(old:GetPivot())
	table.insert(report, "pivot = " .. tostring(old:GetPivot().Position))
	if mode == "replace" then
		old:Destroy()
		table.insert(report, "старая " .. target .. " удалена")
	end
elseif mode == "into" then
	parent = resolve(target)
	if not parent then
		model:Destroy()
		return "нет " .. target
	end
	local same = parent:FindFirstChild(model.Name)
	if same then
		same:Destroy()
		table.insert(report, ("прежняя %s.%s заменена"):format(target, model.Name))
	end
else
	local same = workspace:FindFirstChild(model.Name)
	if same then
		same:Destroy()
		table.insert(report, "прежняя Workspace." .. model.Name .. " заменена")
	end
end
model.Parent = parent
game:GetService("ChangeHistoryService"):SetWaypoint("import " .. model.Name)
table.insert(report, ("%s → %s, экземпляров %d"):format(model.Name, model:GetFullName(), built))
return table.concat(report, "\\n")
`;

function post(pathname, body) {
  return new Promise((resolve, reject) => {
    const data = Buffer.from(JSON.stringify(body));
    const req = http.request(
      pathname === '/status'
        ? { host: BRIDGE.host, port: BRIDGE.port, path: pathname, method: 'GET' }
        : { host: BRIDGE.host, port: BRIDGE.port, path: pathname, method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': data.length } },
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
    if (pathname !== '/status') req.write(data);
    req.end();
  });
}

(async () => {
  const status = await post('/status', {});
  const studio = process.env.STUDIO_ID || (status.studios && status.studios[0] && status.studios[0].id);
  if (!studio) throw new Error('Studio не подключена к мосту');
  const replace = opt('--replace');
  const pivotTo = opt('--pivot-to');
  const into = opt('--into');
  const mode = replace ? 'replace' : pivotTo ? 'pivot' : into ? 'into' : 'workspace';
  const code = LUA
    .replace('__PAYLOAD__', JSON.stringify(JSON.stringify(roots[0])))
    .replace('__MODE__', JSON.stringify(mode))
    .replace('__TARGET__', JSON.stringify(replace || pivotTo || into || ''));
  console.log(`${file}: экземпляров ${count}, режим ${mode}`);
  const result = await post('/tool', {
    name: 'execute_luau',
    arguments: { code, datamodel_type: 'Edit', studio_id: studio },
    timeoutMs: 300000,
  });
  if (result.error) throw new Error('bridge: ' + JSON.stringify(result.error));
  if (result.isError) throw new Error('Luau: ' + result.text);
  console.log(result.text);
})().catch((e) => {
  console.error('ОШИБКА: ' + String((e && e.message) || e));
  process.exit(1);
});
