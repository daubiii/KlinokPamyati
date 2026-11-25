#!/usr/bin/env node
// ui_shots_a.js — батч A: хаб-интерфейс (HUD, доска, книга×4, инвентарь,
// кузня, сундук дня, врата, стена, лавка, диалог). Скрины в tools/shots/.
'use strict';
const http = require('http');
const SID = process.argv[2];
const OUTDIR = 'tools/shots/ui';

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

// Клиентские exec с ретраями (мост иногда попадает в чужой датамодел).
async function clientExec(code, marker, tries = 4) {
	for (let i = 1; i <= tries; i++) {
		const r = await tool('execute_luau', { code, datamodel_type: 'Client' });
		const text = String(r.text || '');
		if (text.indexOf(marker) >= 0) {
			return text;
		}
		await sleep(1200);
	}
	console.log('  (клиент-маркер не пойман за ' + tries + ' попыток)');
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

(async () => {
	const fs = require('fs');
	fs.mkdirSync(OUTDIR, { recursive: true });

	await tool('start_stop_play', { is_start: false, studio_id: SID });
	await sleep(3000);
	await tool('start_stop_play', { is_start: true, studio_id: SID });
	console.log('плей: жду ролик и справку 46 с...');
	await sleep(46000);

	// закрываем справку и окно класса, чистый HUD
	await serverExec([
		'local p = game.Players:GetPlayers()[1]',
		'if not p then return "НЕТ ИГРОКА" end',
		'p:SetAttribute("ShowSlides", nil)',
		'p:SetAttribute("ShowClassSelect", nil)',
		'return "чисто"',
	].join('\n'), 'чисто');
	await sleep(1000);

	const hub = [
		'local p = game.Players:GetPlayers()[1]',
		'if not p then return "НЕТ ИГРОКА" end',
		'local SC = require(game.Players.LocalPlayer.PlayerScripts.Controllers.StationController)',
		'return "SC_OK"',
	].join('\n');
	await clientExec(hub, 'SC_OK');

	console.log('== HUD (полный, хаб)');
	await shot('hud_full', SID);
	await sleep(600);

	const openStation = (id) => [
		'local p = game.Players.LocalPlayer',
		'local SC = require(p.PlayerScripts.Controllers.StationController)',
		'SC.open("' + id + '")',
		'return "opened ' + id + '"',
	].join('\n');
	const closeStation = [
		'local p = game.Players.LocalPlayer',
		'local SC = require(p.PlayerScripts.Controllers.StationController)',
		'SC.close(true)',
		'return "closed"',
	].join('\n');

	console.log('== Доска заданий (сюжет)');
	await clientExec(openStation('Board'), 'opened Board');
	await sleep(2200);
	await shot('board_story', SID);
	await clientExec(closeStation, 'closed');
	await sleep(800);

	console.log('== Книга героя: снаряжение');
	await clientExec(openStation('Inventory'), 'opened Inventory');
	await sleep(2200);
	await shot('book_gear', SID);
	await clientExec([
		'local p = game.Players.LocalPlayer',
		'local CW = require(p.PlayerScripts.Windows.CharacterWindow)',
		'if CW.selectTab then CW.selectTab("hero") end',
		'return "tab hero"',
	].join('\n'), 'tab hero');
	await sleep(1200);
	console.log('== Книга: герой');
	await shot('book_hero', SID);
	await clientExec([
		'local p = game.Players.LocalPlayer',
		'local CW = require(p.PlayerScripts.Windows.CharacterWindow)',
		'if CW.selectTab then CW.selectTab("journal") end',
		'return "tab journal"',
	].join('\n'), 'tab journal');
	await sleep(1200);
	console.log('== Книга: журнал');
	await shot('book_journal', SID);
	await clientExec([
		'local p = game.Players.LocalPlayer',
		'local CW = require(p.PlayerScripts.Windows.CharacterWindow)',
		'if CW.selectTab then CW.selectTab("talents") end',
		'return "tab talents"',
	].join('\n'), 'tab talents');
	await sleep(1200);
	console.log('== Книга: таланты');
	await shot('book_talents', SID);
	await clientExec(closeStation, 'closed');
	await sleep(800);

	console.log('== Кузня Эха');
	await clientExec(openStation('Forge'), 'opened Forge');
	await sleep(2500);
	await shot('forge', SID);
	await clientExec(closeStation, 'closed');
	await sleep(1200);

	console.log('== Сундук дня');
	await clientExec(openStation('DailyChest'), 'opened DailyChest');
	await sleep(2200);
	await shot('daily_chest', SID);
	await clientExec(closeStation, 'closed');
	await sleep(1000);

	console.log('== Врата Печатей (этажи)');
	await clientExec(openStation('Gate'), 'opened Gate');
	await sleep(2200);
	await shot('gate_floors', SID);
	await clientExec(closeStation, 'closed');
	await sleep(1000);

	console.log('== Стена имён');
	await clientExec(openStation('Wall'), 'opened Wall');
	await sleep(2200);
	await shot('wall', SID);
	await clientExec(closeStation, 'closed');
	await sleep(800);

	console.log('== Лавка');
	await clientExec(openStation('Shop'), 'opened Shop');
	await sleep(2200);
	await shot('shop', SID);
	await clientExec(closeStation, 'closed');
	await sleep(800);

	console.log('== Диалог жителя (Ольгерд)');
	const payload = await serverExec([
		'local p = game.Players:GetPlayers()[1]',
		'local VS = require(game.ServerScriptService.Hub.VillagerService)',
		'local said = VS.talk(p, "Olgerd")',
		'if not said then return "нет реплики" end',
		'local HS = game:GetService("HttpService")',
		'return "TALK:" .. HS:JSONEncode({ villager = "Olgerd", name = said.name, title = said.title, line = said.line, first = said.first })',
	].join('\n'), 'TALK:', 3);
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
		await sleep(2000);
		await shot('dialog_villager', SID);
		await clientExec(closeStation, 'closed');
		await sleep(800);
	}

	console.log('== батч A готов — плей оставлен запущенным для батча B');
})().catch((e) => {
	console.log('ERR', e.message);
	process.exit(1);
});
