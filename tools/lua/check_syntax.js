#!/usr/bin/env node
// check_syntax.js — НАСТОЯЩАЯ проверка синтаксиса Lua/Luau через Luau в Studio
// (мост): исходник файла компилируется loadstring'ом. rojo build синтаксис не
// парсит, поэтому без этой проверки сломанный файл доезжает до Studio.
//   node tools/lua/check_syntax.js <файл.lua> [ещё...]
// Требует: Studio открыта, tools/studio-bridge.js запущен (порт 8799).
'use strict';
const fs = require('fs');
const http = require('http');

const PORT = Number(process.env.BRIDGE_PORT || 8799);

function bridge(body, timeoutMs = 120000) {
	return new Promise((resolve, reject) => {
		const data = Buffer.from(JSON.stringify(body));
		const req = http.request(
			{ host: '127.0.0.1', port: PORT, path: '/tool', method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': data.length } },
			(res) => {
				let out = '';
				res.setEncoding('utf8');
				res.on('data', (c) => (out += c));
				res.on('end', () => {
					try {
						resolve(JSON.parse(out));
					} catch (e) {
						resolve({ text: out, error: e.message });
					}
				});
			}
		);
		req.on('error', reject);
		req.setTimeout(timeoutMs, () => req.destroy(new Error('timeout')));
		if (data) req.write(data);
		req.end();
	});
}

function wrap(source) {
	// длинная строка уровнем выше: в исходниках не должно быть ']==]' — при
	// наличии добавляем ещё '=' (Luau поддерживает до 6+ уровней).
	let level = 1;
	while (source.includes(']' + '='.repeat(level) + ']') && level < 8) level += 1;
	const eq = '='.repeat(level);
	return 'local ok, err = loadstring([' + eq + '[\n' + source + '\n]' + eq + ']) '
		+ 'return ok and "СИНТАКСИС OK" or ("ОШИБКА: " .. tostring(err))';
}

(async () => {
	const files = process.argv.slice(2);
	if (files.length === 0) {
		console.log('укажи файлы: node tools/lua/check_syntax.js <файлы...>');
		process.exit(1);
	}
	let failed = 0;
	for (const file of files) {
		const source = fs.readFileSync(file, 'utf8');
		const response = await bridge({
			name: 'execute_luau',
			arguments: { code: wrap(source), datamodel_type: 'Edit' },
		});
		const text = String(response.text || '');
		if (text.indexOf('СИНТАКСИС OK') === 0) {
			console.log('OK      ' + file);
		} else {
			failed += 1;
			console.log('ОШИБКА  ' + file + '\n        ' + text.slice(0, 400));
		}
	}
	process.exit(failed ? 1 : 0);
})().catch((e) => {
	console.log('ошибка моста: ' + e.message);
	process.exit(1);
});
