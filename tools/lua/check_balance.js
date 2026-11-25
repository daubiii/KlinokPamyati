#!/usr/bin/env node
// check_balance.js — грубый, но честный балансир блоков Lua/Luau.
// luau CLI в системе нет, а rojo build не парсит Lua (только упаковывает),
// поэтому тут свой счётчик: function/if/do открывают блок, end закрывает.
// Строки-литералы и комментарии (включая --[[ ]]) вырезаются перед подсчётом.
//   node tools/lua/check_balance.js <файл.lua> [ещё файлы...]
// Код 0 — баланс во всех файлах; 1 — есть расхождения (файл: строка).
'use strict';
const fs = require('fs');

function strip(code) {
	return code
		.replace(/--\[\[[\s\S]*?\]\]/g, ' ')
		.replace(/--[^\n]*/g, ' ')
		.replace(/"(\\.|[^"\\\n])*"/g, '""')
		.replace(/'(\\.|[^'\\\n])*'/g, "''")
		.replace(/\[\[[\s\S]*?\]\]/g, ' "" ');
}

function lineOf(map, index) {
	for (const [line, offset] of map) {
		if (offset > index) return line - 1;
	}
	return map[map.length - 1][0];
}

function check(file) {
	const code = strip(fs.readFileSync(file, 'utf8'));
	const map = [[1, 0]];
	for (let i = 0; i < code.length; i++) {
		if (code[i] === '\n') map.push([map.length + 1, i + 1]);
	}
	// Luau if-выражения (`x = if ... then ... else ...`, `f(if ...)`) не требуют
	// end — такой `if` не открывает блок: перед ним `=`, `(`, `,` или `return`.
	const re = /\b(function|if|do|end)\b/g;
	let depth = 0;
	let m;
	while ((m = re.exec(code))) {
		if (m[1] === 'if') {
			const head = code.slice(code.lastIndexOf('\n', m.index) + 1, m.index);
			if (/(?:=|return|,|\()\s*$/.test(head)) {
				continue;
			}
		}
		depth += m[1] === 'end' ? -1 : 1;
		if (depth < 0) {
			return { ok: false, line: lineOf(map, m.index), depth, extra: 'лишний end' };
		}
	}
	return { ok: depth === 0, line: lineOf(map, code.length), depth };
}

let failed = 0;
for (const file of process.argv.slice(2)) {
	const r = check(file);
	if (r.ok) {
		console.log(`OK      ${file}`);
	} else {
		failed++;
		console.log(`ОШИБКА  ${file}:${r.line} — глубина ${r.depth} (${r.extra || 'не закрыт блок'})`);
	}
}
process.exit(failed ? 1 : 0);
