#!/usr/bin/env node
// push_source.js — залить исходники Lua прямо в Studio через мост (Edit-режим),
// когда rojo-синк недоступен (плагин отвязался от serve). Не создавать новые
// скрипты — только обновлять Source существующих.
//   node tools/push_source.js <путь/в/плея=файл.lua> ...
'use strict';
const fs = require('fs');
const http = require('http');


function getStudioId() {
	return new Promise((resolve) => {
		const req = http.request({ host: '127.0.0.1', port: 8799, path: '/status', method: 'GET' }, (res) => {
			let out = '';
			res.setEncoding('utf8');
			res.on('data', (c) => (out += c));
			res.on('end', () => {
				try {
					const d = JSON.parse(out);
					resolve(d.studios && d.studios[0] && d.studios[0].id);
				} catch (e) {
					resolve(undefined);
				}
			});
		});
		req.on('error', () => resolve(undefined));
		req.end();
	});
}

function bridge(body, timeoutMs = 120000) {
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

function wrap(source) {
	let level = 1;
	while (source.includes(']' + '='.repeat(level) + ']') && level < 8) level += 1;
	const eq = '='.repeat(level);
	return '[' + eq + '[\n' + source + '\n]' + eq + ']';
}

(async () => {
	const pairs = process.argv.slice(2);
	if (pairs.length === 0) {
		console.log('укажи пары InstancePath=файл.lua');
		process.exit(1);
	}
	let failed = 0;
	for (const pair of pairs) {
		const eq = pair.indexOf('=');
		const instancePath = pair.slice(0, eq);
		const file = pair.slice(eq + 1);
		const source = fs.readFileSync(file, 'utf8');
		const code = 'local inst = ' + instancePath + '\ninst.Source = ' + wrap(source) + '\nreturn "OK: " .. inst.Name';
		const r = await bridge({ name: 'execute_luau', arguments: { code, datamodel_type: 'Edit' } });
		const ok = String(r.text || '').indexOf('OK:') === 0;
		console.log((ok ? 'OK      ' : 'ОШИБКА  ') + instancePath + '  <-  ' + file + (ok ? '' : '  | ' + String(r.text || '').slice(0, 150)));
		if (!ok) failed += 1;
	}
	process.exit(failed ? 1 : 0);
})().catch((e) => {
	console.log('ошибка: ' + e.message);
	process.exit(1);
});
