#!/usr/bin/env node
// probe_sources.js — plain-проверка маркеров в Source работающих скриптов (Server datamodel).
'use strict';
const http = require('http');
const SID = process.argv[2] || '4dae45df-9d33-48c6-8545-62bbd8954adb';

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
		'local qs = game.ServerScriptService.Hub.QuestService.Source',
		'local ds = game.ServerScriptService.Systems.DataService.Source',
		'local fs = game.ServerScriptService.Systems.FloorService.Source',
		'local ps = game.ServerScriptService.Systems.PartyService.Source',
		'local function has(src, marker)',
		'\treturn tostring(string.find(src, marker, 1, true) ~= nil)',
		'end',
		'return "QS.statConn=" .. has(qs, "statChanged:Connect") .. " QS.achvOpen=" .. has(qs, "achvOpen")',
		'\t.. " DS.backup=" .. has(ds, "KlinokPamyati_backup_v1")',
		'\t.. " FS.endVote=" .. has(fs, "startEndVote") .. " PS.onMemberLeaving=" .. has(ps, "onMemberLeaving")',
	].join('\n');
	const r = await bridge({ name: 'execute_luau', arguments: { code: lua, datamodel_type: 'Server' } });
	console.log(String(r.text || ''));
})().catch((e) => console.log('ERR', e.message));
