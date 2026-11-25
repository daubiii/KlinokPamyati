#!/usr/bin/env node
// ui_shots_b.js — батч B: диалог жителя, этаж (бой + дебаф + дары),
// сцена сундука, отряд/настройки/класс, 7 слайдов справки.
'use strict';
const http = require('http');
const SID = process.argv[2];

function tool(name, args, timeoutMs = 150000) {
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
		await sleep(1200);
	}
	console.log('  (клиент-маркер не пойман)');
	return '';
}

async function serverExec(code, marker, tries = 4) {
	for (let i = 1; i <= tries; i++) {
		const r = await tool('execute_luau', { code, datamodel_type: 'Server' });
		const text = String(r.text || '');
		if (text.indexOf(marker) >= 0) {
			return text;
		}
		await sleep(1200);
	}
	console.log('  (сервер-маркер не пойман)');
	return '';
}

async function shot(name, studioId) {
	const cap = await tool('screen_capture', { capture_id: 'ui_' + name, studio_id: studioId });
	const file = cap && cap.images && cap.images[0];
	console.log('  скрин:', file);
	return file;
}

const closeStation = [
	'local p = game.Players.LocalPlayer',
	'local SC = require(p.PlayerScripts.Controllers.StationController)',
	'SC.close(true)',
	'return "closed"',
].join('\n');

(async () => {
	console.log('== Диалог жителя (телепорт к Ольгерду + talk)');
	await serverExec([
		'local p = game.Players:GetPlayers()[1]',
		'if not p then return "НЕТ ИГРОКА" end',
		'local VS = require(game.ServerScriptService.Hub.VillagerService)',
		'local MG = require(game.ServerScriptService.Systems.MotionGuard)',
		'local pos = VS.position("Olgerd")',
		'if not pos then return "нет позиции жителя" end',
		'local char = p.Character',
		'local root = char and char:FindFirstChild("HumanoidRootPart")',
		'if root then',
		'\troot.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))',
		'\tMG.markLegal(p, 4)',
		'end',
		'return "у жителя"',
	].join('\n'), 'у жителя');
	await sleep(1500);
	const payload = await serverExec([
		'local p = game.Players:GetPlayers()[1]',
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
		await clientExec(closeStation, 'closed');
		await sleep(800);
	} else {
		console.log('  (диалог пропущен — реплика не получена)');
	}

	console.log('== Этаж 1: вход + враги + боевой HUD');
	await serverExec([
		'local p = game.Players:GetPlayers()[1]',
		'local Hub = require(game.ServerScriptService.Hub.HubService)',
		'Hub.enterFloor(p, 1, "normal")',
		'return "на этаже"',
	].join('\n'), 'на этаже');
	await sleep(4000);
	await serverExec([
		'local Cmd = game:GetService("ServerStorage"):FindFirstChild("KlinokDebug")',
		'local cmdFn = Cmd and Cmd:FindFirstChild("Cmd")',
		'if cmdFn then cmdFn:Invoke("spawn guard 5") return "враги заспавнены" end',
		'return "нет Cmd"',
	].join('\n'), 'враги заспавнены');
	await sleep(2500);
	await shot('floor_combat', SID);
	await sleep(600);

	console.log('== Дебаф мороз на игроке');
	await serverExec([
		'local Cmd = game:GetService("ServerStorage"):FindFirstChild("KlinokDebug")',
		'local cmdFn = Cmd and Cmd:FindFirstChild("Cmd")',
		'if cmdFn then cmdFn:Invoke("debuff frost") return "дебаф висит" end',
		'return "нет Cmd"',
	].join('\n'), 'дебаф висит');
	await sleep(2500);
	await shot('floor_debuff', SID);

	console.log('== Дары Эха');
	await serverExec([
		'local Cmd = game:GetService("ServerStorage"):FindFirstChild("KlinokDebug")',
		'local cmdFn = Cmd and Cmd:FindFirstChild("Cmd")',
		'if cmdFn then cmdFn:Invoke("boon 1") return "дары предложены" end',
		'return "нет Cmd"',
	].join('\n'), 'дары предложены');
	await sleep(2500);
	await shot('boon_cards', SID);
	await sleep(400);

	console.log('== Возврат в долину + сцена сундука');
	await serverExec([
		'local p = game.Players:GetPlayers()[1]',
		'local DS = require(game.ServerScriptService.Systems.DataService)',
		'local prof = DS.get(p)',
		'prof.chests = prof.chests or {}',
		'prof.chests["f1_common"] = (prof.chests["f1_common"] or 0) + 1',
		'return "сундук в сумке"',
	].join('\n'), 'сундук в сумке');
	await serverExec([
		'local p = game.Players:GetPlayers()[1]',
		'local Hub = require(game.ServerScriptService.Hub.HubService)',
		'Hub.returnToHub(p)',
		'return "в долине"',
	].join('\n'), 'в долине');
	await sleep(2500);
	await serverExec([
		'local p = game.Players:GetPlayers()[1]',
		'local UiNet = require(game.ReplicatedStorage.Shared.Net.UiNet)',
		'local open = UiNet.ensure("ChestsOpen")',
		'local res = open:InvokeClient(p, "f1_common")',
		'return "сундук открыт: " .. tostring(res ~= nil)',
	].join('\n'), 'сундук открыт');
	await sleep(4500);
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

	console.log('== батч B готов');
})().catch((e) => {
	console.log('ERR', e.message);
	process.exit(1);
});
