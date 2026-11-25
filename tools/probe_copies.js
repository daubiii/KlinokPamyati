#!/usr/bin/env node
// probe_copies.js — найти все копии скриптов в плейсе и проверить, свежие ли их Source.
'use strict';
const http = require('http');
const SID = process.argv[2] || '4dae45df-9d33-48c6-8545-62bbd8954adb';
const NAMES = (process.argv[3] || 'QuestService,DataService').split(',');

function bridge(body, timeoutMs = 90000) {
	return new Promise((resolve, reject) => {
		const data = Buffer.from(JSON.stringify(body));
		const req = http.request(
			{ host: '127.0.0.1', port: 8799, path: '/tool', method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': data.length } },
			(res) => {
				let out = '';
				res.setEncoding('utf8');
				res.on('data', (c) => (out += c));
				res.on('end', () => {
					try {
						resolve(JSON.parse(out));
					} catch (e) {
						resolve({ text: out });
					}
				});
			}
		);
		req.on('error', reject);
		req.setTimeout(timeoutMs, () => req.destroy(new Error('timeout')));
		req.write(data);
		req.end();
	});
}

(async () => {
	const lua = [
		'local out = {}',
		'local names = { ' + NAMES.map((n) => '"' + n + '"').join(', ') + ' }',
		'local markers = { QuestService = "specialKilled", DataService = "бэкап-стор", FloorService = "startEndVote" }',
		'local function walk(inst, path)',
		'\tfor _, child in ipairs(inst:GetChildren()) do',
		'\t\tlocal isMatch = false',
		'\t\tfor _, n in ipairs(names) do',
		'\t\t\tif child.Name == n then isMatch = true end',
		'\t\tend',
		'\t\tif isMatch and (child:IsA("ModuleScript")) then',
		'\t\t\tlocal marker = markers[child.Name]',
		'\t\t\tlocal src = child.Source or ""',
		'\t\t\ttable.insert(out, path .. "." .. child.Name .. " fresh=" .. tostring(marker == nil or string.find(src, marker) ~= nil))',
		'\t\tend',
		'\t\tif child:IsA("Folder") then walk(child, path .. "." .. child.Name) end',
		'\tend',
		'end',
		'walk(game:GetService("ServerScriptService"), "SSS")',
		'walk(game:GetService("ReplicatedStorage"), "RS")',
		'return table.concat(out, "\\n")',
	].join('\n');
	const r = await bridge({ name: 'execute_luau', arguments: { code: lua, datamodel_type: 'Server' } });
	console.log(String(r.text || ''));
})().catch((e) => console.log('ERR', e.message));
