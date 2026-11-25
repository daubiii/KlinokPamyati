#!/usr/bin/env node
// run-luau.js — прогон чистых проверок без Studio.
// Собирает модули src/ReplicatedStorage/Shared в один файл с поддельным
// деревом экземпляров (script.Parent, FindFirstChild, require по экземпляру)
// и запускает проверку через luau CLI. Модуль исполняется только при require,
// поэтому код с game:GetService в неиспользуемых модулях не мешает.
//
//   node tools/run-luau.js tools/lua/test_enemy_anims.lua
//   LUAU=путь/к/luau.exe node tools/run-luau.js ...
//
// Проверка должна возвращать строку отчёта; строка «ИТОГО: … провалов»
// превращается в код выхода 1.
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const SHARED = path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared');
const testFile = process.argv[2];
if (!testFile) {
  console.error('укажи файл проверки');
  process.exit(2);
}
const luau = process.env.LUAU || 'luau';

const lines = [];
lines.push(`
local Node = {}
local function newNode(name, parent)
	local node = setmetatable({ Name = name, Parent = parent, __children = {} }, Node)
	if parent then rawget(parent, "__children")[name] = node end
	return node
end
Node.__index = function(self, key)
	local method = rawget(Node, key)
	if method then return method end
	local child = rawget(self, "__children")[key]
	if child == nil then error("нет потомка " .. tostring(key) .. " у " .. rawget(self, "Name"), 2) end
	return child
end
function Node.FindFirstChild(self, name) return rawget(self, "__children")[name] end
function Node.WaitForChild(self, name) return Node.__index(self, name) end
function Node.GetChildren(self)
	local list = {}
	for _, child in pairs(rawget(self, "__children")) do table.insert(list, child) end
	return list
end
local loaded = {}
local function load(node)
	local cached = loaded[node]
	if cached ~= nil then return cached end
	local factory = rawget(node, "__factory")
	if not factory then error("не модуль: " .. rawget(node, "Name")) end
	local value = factory(node, load)
	loaded[node] = value
	return value
end
local Shared = newNode("Shared", newNode("ReplicatedStorage", nil))

-- Минимальные заглушки типов Roblox для конфигов (цвета, векторы).
local ColorMeta = {}
ColorMeta.__index = ColorMeta
local function color(r, g, b) return setmetatable({ R = r, G = g, B = b }, ColorMeta) end
function ColorMeta.Lerp(a, b, t) return color(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
function ColorMeta.ToHex(c)
	return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local Color3 = {
	new = color,
	fromRGB = function(r, g, b) return color(r / 255, g / 255, b / 255) end,
	fromHex = function(hex)
		hex = string.gsub(hex, "#", "")
		return color(tonumber(string.sub(hex, 1, 2), 16) / 255, tonumber(string.sub(hex, 3, 4), 16) / 255, tonumber(string.sub(hex, 5, 6), 16) / 255)
	end,
}
-- Арифметика векторов нужна конфигам точек (P.x + Vector3.new(...)).
local VecMeta = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, VecMeta) end
local function num(v) return type(v) == "number" and vec(v, v, v) or v end
VecMeta.__add = function(a, b) a, b = num(a), num(b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
VecMeta.__sub = function(a, b) a, b = num(a), num(b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
VecMeta.__mul = function(a, b) a, b = num(a), num(b) return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
VecMeta.__div = function(a, b) a, b = num(a), num(b) return vec(a.X / b.X, a.Y / b.Y, a.Z / b.Z) end
VecMeta.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
VecMeta.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	return nil
end
local Vector3 = {
	new = vec,
}
Vector3.zero = Vector3.new(0, 0, 0)
local Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0 } end }
Vector2.zero = Vector2.new(0, 0)
local Font = { fromEnum = function(e) return { enum = e } end, new = function(f) return { family = f } end }
local Enum = Enum or setmetatable({}, { __index = function(t, k) local e = setmetatable({}, { __index = function(_, n) return { Name = n, EnumType = k } end }); rawset(t, k, e); return e end })
`);

function walk(dir, parentVar, depth) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      const v = `d${depth}_${entry.name}`;
      lines.push(`local ${v} = newNode(${JSON.stringify(entry.name)}, ${parentVar})`);
      walk(full, v, depth + 1);
    } else if (entry.name.endsWith('.lua') && !entry.name.endsWith('.server.lua') && !entry.name.endsWith('.client.lua')) {
      const name = entry.name.slice(0, -4);
      const source = fs.readFileSync(full, 'utf8');
      lines.push(`do local m = newNode(${JSON.stringify(name)}, ${parentVar})`);
      lines.push(`rawset(m, "__factory", function(script, require)\n${source}\nend) end`);
    }
  }
}
walk(SHARED, 'Shared', 0);

lines.push('local _G = setmetatable({ KlinokShared = Shared }, { __index = _G })');
lines.push('local require = load');
lines.push('local report = (function()');
lines.push(fs.readFileSync(path.resolve(testFile), 'utf8'));
lines.push('end)()');
lines.push('print(report)');

const bundle = path.join(os.tmpdir(), `klinok-luau-${process.pid}.luau`);
fs.writeFileSync(bundle, lines.join('\n'));
const result = spawnSync(luau, [bundle], { encoding: 'utf8' });
fs.unlinkSync(bundle);
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
if (result.error) {
  console.error(String(result.error));
  process.exit(2);
}
const failed = result.status !== 0 || /ИТОГО: \d+ провал/.test(result.stdout || '');
process.exit(failed ? 1 : 0);
