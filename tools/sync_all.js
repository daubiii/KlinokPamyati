#!/usr/bin/env node
// sync_all.js — полный ресинк изменённых файлов в Studio через мост:
// обновляет Source существующих скриптов и СОЗДАЁТ отсутствующие (LocalScript/
// ModuleScript/Script по суффиксу .client.lua/.server.lua/остальное).
// Запускать при остановленном плее.
'use strict';
const fs = require('fs');
const http = require('http');
const path = require('path');

const SID = process.argv[2] || '4dae45df-9d33-48c6-8545-62bbd8954adb';

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

function bridge(body, timeoutMs = 150000) {
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

// InstancePath (без game: prefix) = файл
const JOBS = [
	['ServerScriptService.Systems.DataService', 'src/ServerScriptService/Systems/DataService.lua'],
	['ServerScriptService.Systems.FloorService', 'src/ServerScriptService/Systems/FloorService.lua'],
	['ServerScriptService.Systems.PartyService', 'src/ServerScriptService/Systems/PartyService.lua'],
	['ServerScriptService.Systems.SpecialMobs', 'src/ServerScriptService/Systems/SpecialMobs.lua'],
	['ServerScriptService.Systems.EnemyDebuffs', 'src/ServerScriptService/Systems/EnemyDebuffs.lua'],
	['ServerScriptService.Systems.PlayerSettings', 'src/ServerScriptService/Systems/PlayerSettings.lua'],
	['ServerScriptService.Systems.TutorialService', 'src/ServerScriptService/Systems/TutorialService.lua'],
	['ServerScriptService.Systems.StatsService', 'src/ServerScriptService/Systems/StatsService.lua'],
	['ServerScriptService.Hub.QuestService', 'src/ServerScriptService/Hub/QuestService.lua'],
	['ServerScriptService.Bootstrap', 'src/ServerScriptService/Bootstrap.server.lua'],
	['ReplicatedStorage.Shared.Net.Net', 'src/ReplicatedStorage/Shared/Net/Net.lua'],
	['ReplicatedStorage.Shared.Config.Quests', 'src/ReplicatedStorage/Shared/Config/Quests.lua'],
	['ReplicatedStorage.Shared.Config.UiAssets', 'src/ReplicatedStorage/Shared/Config/UiAssets.lua'],
	['ReplicatedStorage.Shared.Config.Debuffs', 'src/ReplicatedStorage/Shared/Config/Debuffs.lua'],
	['StarterPlayer.StarterPlayerScripts.Bootstrap', 'src/StarterPlayer/StarterPlayerScripts/Bootstrap.client.lua'],
	['StarterPlayer.StarterPlayerScripts.Controllers.PartyController', 'src/StarterPlayer/StarterPlayerScripts/Controllers/PartyController.lua'],
	['StarterPlayer.StarterPlayerScripts.Controllers.FloorEndVoteController', 'src/StarterPlayer/StarterPlayerScripts/Controllers/FloorEndVoteController.lua'],
	['StarterPlayer.StarterPlayerScripts.Controllers.LoadingScreenController', 'src/StarterPlayer/StarterPlayerScripts/Controllers/LoadingScreenController.lua'],
	['StarterPlayer.StarterPlayerScripts.Controllers.SettingsController', 'src/StarterPlayer/StarterPlayerScripts/Controllers/SettingsController.lua'],
	['StarterPlayer.StarterPlayerScripts.Controllers.EnemyDebuffFx', 'src/StarterPlayer/StarterPlayerScripts/Controllers/EnemyDebuffFx.lua'],
	['StarterPlayer.StarterPlayerScripts.TutorialController', 'src/StarterPlayer/StarterPlayerScripts/TutorialController.client.lua'],
];

(async () => {
	let failed = 0;
	for (const [instancePath, file] of JOBS) {
		const source = fs.readFileSync(file, 'utf8');
		const className = file.includes('Controllers' + path.sep) || file.includes('Controllers/')
			? 'ModuleScript' // всё в Controllers/ — требуемые модули (Bootstrap.start)
			: file.endsWith('.client.lua') ? 'LocalScript'
			: file.endsWith('.server.lua') ? 'Script'
			: 'ModuleScript';
		const name = path.basename(file).replace(/\.client\.lua$|\.server\.lua$|\.lua$/, '');
		const lua = [
			'local parent = game.' + instancePath.split('.').slice(0, -1).join('.'),
			'local inst = parent:FindFirstChild("' + name + '")',
			'if not inst or not inst:IsA("' + className + '") then',
			'\tlocal old = parent:FindFirstChild("' + name + '")',
			'\tif old then old:Destroy() end',
			'\tinst = Instance.new("' + className + '")',
			'\tinst.Name = "' + name + '"',
			'\tinst.Parent = parent',
			'end',
			'inst.Source = ' + wrap(source),
			'return "OK " .. "' + instancePath + '"',
		].join('\n');
		const r = await bridge({ name: 'execute_luau', arguments: { code: lua, datamodel_type: 'Edit' } });
		const ok = String(r.text || '').indexOf('OK ') === 0;
		console.log((ok ? 'OK      ' : 'ОШИБКА  ') + instancePath + (ok ? '' : '  | ' + String(r.text || '').slice(0, 140)));
		if (!ok) failed += 1;
	}
	console.log(failed === 0 ? 'ВСЕ СКРИПТЫ СИНХРОНИЗИРОВАНЫ' : 'ОШИБОК: ' + failed);
	process.exit(failed ? 1 : 0);
})().catch((e) => {
	console.log('ошибка: ' + e.message);
	process.exit(1);
});
