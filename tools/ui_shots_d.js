#!/usr/bin/env node
// ui_shots_d.js — батч D: диалог (параллельный VS.talk → данные конфига),
// этаж через реальный RequestJourneyStart, бой, дебаф, дары, возврат,
// сцена сундука (реальные ремоуты от параллельного grant).
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
	console.log('  (клиент: маркер не пойман — ' + code.slice(0, 50).replace(/\n/g, ' ') + '...)');
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
	console.log('  (сервер: маркер не пойман — ' + code.slice(0, 50).replace(/\n/g, ' ') + '...)');
	return '';
}

async function shot(name, studioId) {
	const cap = await tool('screen_capture', { capture_id: 'ui_' + name, studio_id: studioId });
	const file = cap && cap.images && cap.images[0];
	console.log('  скрин:', file);
	return file;
}

(async () => {
	console.log('== Диалог жителя (параллельный talk → конфиг)');
	const payload = await serverExec([
		'local p = game.Players:GetPlayers()[1]',
		'if not p then return "НЕТ ИГРОКА" end',
		'local VS = require(game.ServerScriptService.Hub.VillagerService)',
		'local said = VS.talk(p, "Olgerd")',
		'if not said then return "нет реплики" end',
		'local HS = game:GetService("HttpService")',
		'return "TALK:" .. HS:JSONEncode({ villager = "Olgerd", name = said.name, title = said.title, line = said.line, first = said.first })',
	].join('\n'), 'TALK:', 2);
	const talkJson = String(payload.text || '').split('TALK:')[1] || '';
	if (talkJson) {
		await clientExec([
			'local p = game.Players.LocalPlayer',
			'local SC = require(p.PlayerScripts.Controllers.StationController)',
			'local HS = game:GetService("HttpService")',
			'local talk = HS:JSONDecode([==[' + talkJson.trim() + ']==])',
			'SC.open("Talk", { villager = "Olgerd", talk = talk })',
			'return "opened Talk"',
		].join('\n'), 'opened Talk');
		await sleep(2200);
		await shot('dialog_villager', SID);
		await clientExec(closeStation || 'return 0', 'closed', 1).catch(() => {});
		await clientExec([
			'local p = game.Players.LocalPlayer',
			'local SC = require(p.PlayerScripts.Controllers.StationController)',
			'SC.close(true)',
			'return "closed"',
		].join('\n'), 'closed', 1);
		await sleep(800);
	} else {
		console.log('  (диалог пропущен)');
	}

	console.log('== Этаж 1: реальный RequestJourneyStart');
	await clientExec([
		'local net = game.ReplicatedStorage:FindFirstChild("KlinokHubNet")',
		'local rf = net and net:FindFirstChild("RequestJourneyStart")',
		'if not rf then return "нет ремоута" end',
		'local res = rf:InvokeServer()',
		'return "journey: " .. tostring(res and res.ok)',
	].join('\n'), 'journey:');
	await sleep(6000);
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
	await sleep(3500);
	await serverExec([
		'local p = game.Players:GetPlayers()[1]',
		'local ChestService = require(game.ServerScriptService.Systems.ChestService)',
		'ChestService.grantAll({ p }, 1, "common", { kind = "quest" })',
		'return "сундук выдан"',
	].join('\n'), 'сундук выдан');
	await sleep(6000);
	await shot('chest_reveal', SID);
	await sleep(2000);

	console.log('== Отряд');
	await clientExec([
		'local g = game.Players.LocalPlayer.PlayerGui:FindFirstChild("KlinokParty")',
		'if g and g.Root then local c = g.Root:FindFirstChild("Canvas") if c then c.Visible = true return "открыто" end end',
		'return "нет гуи"',
	].join('\n'), 'открыто');
	await sleep(1500);
	await shot('party_window', SID);
	await clientExec([
		'local g = game.Players.LocalPlayer.PlayerGui:FindFirstChild("KlinokParty")',
		'if g and g.Root then local c = g.Root:FindFirstChild("Canvas") if c then c.Visible = false end end',
		'return "скрыто"',
	].join('\n'), 'скрыто');
	await sleep(400);

	console.log('== Настройки');
	await clientExec([
		'local g = game.Players.LocalPlayer.PlayerGui:FindFirstChild("KlinokSettings")',
		'if g and g.Root then local c = g.Root:FindFirstChild("Canvas") if c then c.Visible = true return "открыто" end end',
		'return "нет гуи"',
	].join('\n'), 'открыто');
	await sleep(1500);
	await shot('settings_window', SID);
	await clientExec([
		'local g = game.Players.LocalPlayer.PlayerGui:FindFirstChild("KlinokSettings")',
		'if g and g.Root then local c = g.Root:FindFirstChild("Canvas") if c then c.Visible = false end end',
		'return "скрыто"',
	].join('\n'), 'скрыто');
	await sleep(400);

	console.log('== Выбор пути');
	await serverExec([
		'local p = game.Players:GetPlayers()[1]',
		'p:SetAttribute("ShowClassSelect", true)',
		'return "открыто"',
	].join('\n'), 'открыто');
	await sleep(2000);
	await shot('class_select', SID);
	await serverExec([
		'local p = game.Players:GetPlayers()[1]',
		'p:SetAttribute("ShowClassSelect", nil)',
		'return "закрыто"',
	].join('\n'), 'закрыто');
	await sleep(600);

	console.log('== Справка: 7 слайдов');
	await serverExec([
		'local p = game.Players:GetPlayers()[1]',
		'p:SetAttribute("ShowSlides", true)',
		'return "справка открыта"',
	].join('\n'), 'справка открыта');
	await sleep(1200);
	for (let page = 1; page <= 7; page++) {
		await serverExec([
			'local p = game.Players:GetPlayers()[1]',
			'p:SetAttribute("TutorialSlidesPage", ' + page + ')',
			'return "страница ' + page + '"',
		].join('\n'), 'страница ' + page);
		await sleep(1400);
		await shot('slides_' + page, SID);
	}
	await serverExec([
		'local p = game.Players:GetPlayers()[1]',
		'p:SetAttribute("ShowSlides", nil)',
		'return "справка закрыта"',
	].join('\n'), 'справка закрыта');

	console.log('== батч D готов');
})().catch((e) => {
	console.log('ERR', e.message);
	process.exit(1);
});
