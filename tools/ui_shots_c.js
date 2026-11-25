#!/usr/bin/env node
// ui_shots_c.js — батч C: всё через РЕАЛЬНЫЕ ремоуты (никаких параллельных
// модулей): диалог жителя, этаж с боем, дебаф, дары, сцена сундука.
'use strict';
const http = require('http');
const SID = process.argv[2];

function tool(name, args, timeoutMs = 120000) {
	return new Promise((resolve, reject) => {
		const data = Buffer.from(JSON.stringify({ name, arguments: args }));
		const req = http.request({ host: '127.0.0.1', port: 8799, path: '/tool', method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': data.length } }, (res) => {
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
		});
		req.on('error', reject);
		req.setTimeout(timeoutMs, () => req.destroy(new Error('timeout')));
		req.write(data);
		req.end();
	});
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function clientExec(code, marker, tries = 4) {
	for (let i = 1; i <= tries; i++) {
		const r = await tool('execute_luau', { code, datamodel_type: 'Client' });
		const text = String(r.text || '');
		if (text.indexOf(marker) >= 0) {
			return text;
		}
		await sleep(1000);
	}
	console.log('  (клиент: маркер не пойман)');
	return '';
}

async function serverExec(code, marker, tries = 4) {
	for (let i = 1; i <= tries; i++) {
		const r = await tool('execute_luau', { code, datamodel_type: 'Server' });
		const text = String(r.text || '');
		if (text.indexOf(marker) >= 0) {
			return text;
		}
		await sleep(1000);
	}
	console.log('  (сервер: маркер не пойман — ' + code.slice(0, 60).replace(/\n/g, ' ') + '...)');
	return '';
}

async function shot(name, studioId) {
	const cap = await tool('screen_capture', { capture_id: 'ui_' + name, studio_id: studioId });
	const file = cap && cap.images && cap.images[0];
	console.log('  скрин:', file);
	return file;
}

(async () => {
	console.log('== Диалог жителя: телепорт + реальный RequestStation');
	await serverExec([
		'local p = game.Players:GetPlayers()[1]',
		'if not p then return "НЕТ ИГРОКА" end',
		'local VS = require(game.ServerScriptService.Hub.VillagerService)',
		'local MG = require(game.ServerScriptService.Systems.MotionGuard)',
		'local pos = VS.position("Olgerd")',
		'if not pos then return "нет позиции" end',
		'local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")',
		'if root then',
		'\troot.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))',
		'\tMG.markLegal(p, 4)',
		'\treturn "у жителя"',
		'end',
		'return "нет персонажа"',
	].join('\n'), 'у жителя');
	await sleep(1200);
	await clientExec([
		'local net = game.ReplicatedStorage:FindFirstChild("KlinokHubNet")',
		'local rf = net and net:FindFirstChild("RequestStation")',
		'if not rf then return "нет ремоута" end',
		'local res = rf:InvokeServer("villager:Olgerd")',
		'return "dialog: " .. tostring(res and res.ok)',
	].join('\n'), 'dialog:');
	await sleep(2200);
	await shot('dialog_villager', SID);
	await clientExec([
		'local net = game.ReplicatedStorage:FindFirstChild("KlinokHubNet")',
		'local rf = net and net:FindFirstChild("RequestReturnHub")',
		'if rf then rf:InvokeServer() end',
		'return "закрыто"',
	].join('\n'), 'закрыто');
	await sleep(1200);

	console.log('== Этаж 1: телепорт к вратам + реальный вход');
	await serverExec([
		'local p = game.Players:GetPlayers()[1]',
		'if not p then return "НЕТ ИГРОКА" end',
		'local MG = require(game.ServerScriptService.Systems.MotionGuard)',
		'local anchors = game.Workspace:FindFirstChild("HubStations")',
		'local gate = anchors and anchors:FindFirstChild("Station_Gate")',
		'local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")',
		'if not (gate and root) then return "нет врат или персонажа" end',
		'root.CFrame = CFrame.new(gate.Position + Vector3.new(0, 3, 0))',
		'MG.markLegal(p, 4)',
		'return "у врат"',
	].join('\n'), 'у врат');
	await sleep(1200);
	await clientExec([
		'local net = game.ReplicatedStorage:FindFirstChild("KlinokHubNet")',
		'local rf = net and net:FindFirstChild("RequestEnterFloor")',
		'if not rf then return "нет ремоута" end',
		'local res = rf:InvokeServer(1, "normal")',
		'return "floor: " .. tostring(res and res.ok)',
	].join('\n'), 'floor:');
	await sleep(5000);
	await serverExec([
		'local Cmd = game:GetService("ServerStorage"):FindFirstChild("KlinokDebug")',
		'local cmdFn = Cmd and Cmd:FindFirstChild("Cmd")',
		'if cmdFn then cmdFn:Invoke("spawn guard 5") return "враги: ок" end',
		'return "нет Cmd"',
	].join('\n'), 'враги: ок');
	await sleep(3000);
	await shot('floor_combat', SID);
	await sleep(400);

	console.log('== Дебаф мороз');
	await serverExec([
		'local Cmd = game:GetService("ServerStorage"):FindFirstChild("KlinokDebug")',
		'local cmdFn = Cmd and Cmd:FindFirstChild("Cmd")',
		'if cmdFn then cmdFn:Invoke("debuff frost") return "дебаф: ок" end',
		'return "нет Cmd"',
	].join('\n'), 'дебаф: ок');
	await sleep(2500);
	await shot('floor_debuff', SID);
	await sleep(300);

	console.log('== Дары Эха');
	await serverExec([
		'local Cmd = game:GetService("ServerStorage"):FindFirstChild("KlinokDebug")',
		'local cmdFn = Cmd and Cmd:FindFirstChild("Cmd")',
		'if cmdFn then cmdFn:Invoke("boon 1") return "дары: ок" end',
		'return "нет Cmd"',
	].join('\n'), 'дары: ок');
	await sleep(2500);
	await shot('boon_cards', SID);
	await sleep(300);

	console.log('== Возврат в долину + сцена сундука');
	await clientExec([
		'local net = game.ReplicatedStorage:FindFirstChild("KlinokHubNet")',
		'local rf = net and net:FindFirstChild("RequestReturnHub")',
		'if rf then rf:InvokeServer() end',
		'return "возврат"',
	].join('\n'), 'возврат');
	await sleep(3000);
	await serverExec([
		'local p = game.Players:GetPlayers()[1]',
		'local ChestService = require(game.ServerScriptService.Systems.ChestService)',
		'ChestService.grantAll({ p }, 1, "common", { kind = "quest" })',
		'return "сундук выдан"',
	].join('\n'), 'сундук выдан');
	await sleep(5000);
	await shot('chest_reveal', SID);
	await sleep(2000);

	console.log('== батч C готов');
})().catch((e) => {
	console.log('ERR', e.message);
	process.exit(1);
});
