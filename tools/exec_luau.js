#!/usr/bin/env node
// exec_luau.js — выполнить Luau в Studio через мост и напечатать результат.
//   node tools/exec_luau.js "<код>" [Edit|Client|Server]
'use strict';
const http = require('http');

const PORT = Number(process.env.BRIDGE_PORT || 8799);
const code = process.argv[2] || "print('ping')";
const mode = process.argv[3] || 'Edit';

function request(method, urlPath, body, timeoutMs = 120000) {
	return new Promise((resolve, reject) => {
		const data = Buffer.from(JSON.stringify(body));
		const req = http.request(
			{ host: '127.0.0.1', port: PORT, path: urlPath, method: method, headers: { 'Content-Type': 'application/json', 'Content-Length': data.length } },
			(res) => {
				let out = '';
				res.setEncoding('utf8');
				res.on('data', (c) => (out += c));
				res.on('end', () => {
					try {
						resolve(JSON.parse(out));
					} catch (e) {
						resolve({ raw: out });
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

(async () => {
	const status = await request('GET', '/status', null);
	const studio = (status.studios && status.studios[0]) || null;
	if (!studio) {
		console.log('Studio не подключена к мосту');
		process.exit(1);
	}
	const response = await request('POST', '/tool', {
		name: 'execute_luau',
		arguments: { code, datamodel_type: mode, studio_id: studio.id },
	});
	if (response.error) {
		console.log('ошибка: ' + JSON.stringify(response.error).slice(0, 400));
		process.exit(1);
	}
	console.log(JSON.stringify(response).slice(0, 1200));
})().catch((e) => {
	console.log('ошибка: ' + e.message);
	process.exit(1);
});
