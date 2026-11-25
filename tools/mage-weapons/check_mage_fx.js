#!/usr/bin/env node
// check_mage_fx.js — сверка эффектов мага без Studio:
//  • фазы заклинаний: сервер (WeaponAbilitiesMage.PHASES и реальные вызовы spellFx в CASTS.<id>)
//    ↔ клиент (MageSpellFx.PHASES и обработчики H.<id>.<фаза>);
//  • у каждого заклинания LootMage.Abilities есть серверный CASTS, клиентский H и анимация SPELL_ANIM,
//    а анимация есть в PlayerAnimMage.Actions;
//  • каждое имя звука из MageFx / MageSpellFx / MageFxKit / CombatController / AbilityController
//    есть в SfxMage.sounds|candidates или Sfx.sounds|candidates.
//   node tools/mage-weapons/check_mage_fx.js        (из корня проекта)
const fs = require("fs");
const path = require("path");

const root = process.argv[2] || process.cwd();
const read = (p) => fs.readFileSync(path.join(root, p), "utf8").replace(/\r\n/g, "\n");
const P = {
  lootMage: "src/ReplicatedStorage/Shared/Config/LootMage.lua",
  sfxMage: "src/ReplicatedStorage/Shared/Config/SfxMage.lua",
  sfx: "src/ReplicatedStorage/Shared/Config/Sfx.lua",
  server: "src/ServerScriptService/Systems/WeaponAbilitiesMage.lua",
  spellFx: "src/StarterPlayer/StarterPlayerScripts/Controllers/MageSpellFx.lua",
  mageFx: "src/StarterPlayer/StarterPlayerScripts/Controllers/MageFx.lua",
  kit: "src/StarterPlayer/StarterPlayerScripts/Lib/MageFxKit.lua",
  anim: "src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerAnimMage.lua",
  combat: "src/StarterPlayer/StarterPlayerScripts/Controllers/CombatController.lua",
  ability: "src/StarterPlayer/StarterPlayerScripts/Controllers/AbilityController.lua",
};

let failures = 0;
let checks = 0;
const lines = [];
function check(label, ok, detail) {
  checks++;
  if (!ok) failures++;
  if (!ok || process.env.VERBOSE) lines.push(`  ${ok ? "OK  " : "FAIL"} ${label}${detail ? " — " + detail : ""}`);
}

// Блок «NAME = {» … первая строка «}» в начале строки.
function block(src, header) {
  const start = src.indexOf(header);
  if (start < 0) return null;
  const end = src.indexOf("\n}", start);
  return src.slice(start, end < 0 ? undefined : end + 2);
}
function topKeys(text) {
  const keys = new Set();
  for (const m of text.matchAll(/^\t(?:\["([A-Za-z0-9_]+)"\]|([A-Za-z_][A-Za-z0-9_]*))\s*=/gm)) keys.add(m[1] || m[2]);
  return keys;
}
function phasesOf(src, header) {
  const text = block(src, header);
  const map = {};
  if (!text) return map;
  for (const m of text.matchAll(/^\t([a-z_]+)\s*=\s*\{([^}]*)\}/gm)) {
    map[m[1]] = [...m[2].matchAll(/"([a-z_]+)"/g)].map((x) => x[1]);
  }
  return map;
}
// Куски файла между заголовками вида /^PREFIX(\w+) = / (до следующего заголовка верхнего уровня).
function sections(src, re) {
  const out = {};
  const marks = [...src.matchAll(re)];
  for (let i = 0; i < marks.length; i++) {
    const from = marks[i].index;
    let to = i + 1 < marks.length ? marks[i + 1].index : src.length;
    const tail = src.slice(from + 1, to);
    const stop = tail.search(/\n(?:function |local function |return )/);
    if (stop >= 0) to = from + 1 + stop;
    out[marks[i][1]] = src.slice(from, to);
  }
  return out;
}

const lootMage = read(P.lootMage);
const abilities = [...lootMage.matchAll(/^\t([a-z_]+)\s*=\s*spell\("([a-z_]+)"/gm)].map((m) => m[1]);
check("LootMage.Abilities: 19 заклинаний", abilities.length === 19, String(abilities.length));

const server = read(P.server);
const client = read(P.spellFx);
const serverPhases = phasesOf(server, "WeaponAbilitiesMage.PHASES = {");
const clientPhases = phasesOf(client, "MageSpellFx.PHASES = {");
const casts = sections(server, /^CASTS\.([a-z_]+)\s*=\s*function/gm);
const handlers = sections(client, /^H\.([a-z_]+)\s*=\s*\{/gm);

for (const id of abilities) {
  const sp = serverPhases[id];
  const cp = clientPhases[id];
  check(`${id}: PHASES на сервере`, !!sp);
  check(`${id}: PHASES на клиенте`, !!cp);
  if (sp && cp) check(`${id}: фазы совпадают`, sp.join(",") === cp.join(","), `сервер ${sp.join("·")} / клиент ${cp.join("·")}`);
  const cast = casts[id];
  check(`${id}: CASTS на сервере`, !!cast);
  if (cast && sp) {
    const emitted = new Set([...cast.matchAll(/spellFx\(\s*[a-z_]+\s*,\s*"([a-z_]+)"/g)].map((m) => m[1]));
    const missing = sp.filter((ph) => !emitted.has(ph));
    const extra = [...emitted].filter((ph) => !sp.includes(ph));
    check(`${id}: сервер шлёт все фазы`, missing.length === 0, missing.join(","));
    check(`${id}: сервер не шлёт лишних фаз`, extra.length === 0, extra.join(","));
  }
  const h = handlers[id];
  check(`${id}: обработчик H на клиенте`, !!h);
  if (h && sp) {
    const keys = topKeys(h.replace(/^H\.[a-z_]+\s*=\s*\{\n/, "\n"));
    const missing = sp.filter((ph) => !keys.has(ph));
    check(`${id}: обработчики всех фаз`, missing.length === 0, missing.join(","));
  }
}
for (const id of Object.keys(serverPhases)) check(`PHASES.${id}: есть в LootMage.Abilities`, abilities.includes(id));

// ===== Виды событий MageFx: всё, что шлёт сервер, клиент умеет рисовать =====
const mageFx = read(P.mageFx);
const kinds = topKeys(block(mageFx, "local HANDLERS = {") || "");
for (const file of ["src/ServerScriptService/Systems/MageService.lua", "src/ServerScriptService/Systems/MageBolts.lua", P.server]) {
  const src = read(file);
  for (const kind of new Set([...src.matchAll(/kind\s*=\s*"([a-zA-Z_]+)"/g)].map((m) => m[1]))) {
    check(`MageFx.${kind} (${path.basename(file)})`, kinds.has(kind), "нет обработчика в MageFx.HANDLERS");
  }
}

// ===== Анимации =====
const anim = read(P.anim);
const spellAnim = {};
for (const m of (block(anim, "PlayerAnimMage.SPELL_ANIM = {") || "").matchAll(/^\t([a-z_]+)\s*=\s*"([A-Za-z]+)"/gm)) spellAnim[m[1]] = m[2];
const actions = topKeys(block(anim, "PlayerAnimMage.Actions = {") || "");
for (const id of [...abilities, "veil"]) {
  check(`${id}: анимация SPELL_ANIM`, !!spellAnim[id]);
  if (spellAnim[id]) check(`${id}: ${spellAnim[id]} есть в Actions`, actions.has(spellAnim[id]));
}
for (const name of ["staffBarrier", "staffBarrierHit", "staffBarrierFail"]) check(`Actions.${name}`, actions.has(name));

// ===== Звуки =====
const sfxMage = read(P.sfxMage);
const sfx = read(P.sfx);
const known = new Set([
  ...topKeys(block(sfxMage, "SfxMage.sounds = {") || ""),
  ...topKeys(block(sfxMage, "SfxMage.candidates = {") || ""),
  ...topKeys(block(sfx, "Sfx.sounds = {") || ""),
  ...topKeys(block(sfx, "Sfx.candidates = {") || ""),
]);
check("реестр звуков не пуст", known.size > 50, String(known.size));
const used = new Map();
const note = (name, file) => {
  if (!used.has(name)) used.set(name, new Set());
  used.get(name).add(path.basename(file));
};
for (const file of [P.mageFx, P.spellFx, P.kit, P.combat, P.ability]) {
  const src = read(file);
  for (const m of src.matchAll(/\bsfx\(\s*"([A-Za-z0-9_]+)"(?!\s*\.\.)/gi)) note(m[1], file);
  for (const m of src.matchAll(/emit\(\s*"sfx"\s*,\s*\{\s*name\s*=\s*"([A-Za-z0-9_]+)"/g)) note(m[1], file);
  for (const m of src.matchAll(/(?:SOUND|Sound)[A-Z_]*\s*=\s*\{([^}]*)\}/g)) {
    for (const v of m[1].matchAll(/=\s*"([A-Za-z0-9_]+)"/g)) note(v[1], file);
  }
  if (/"mageCast"\s*\.\./.test(src)) ["mageCast1", "mageCast2", "mageCast3"].forEach((n) => note(n, file));
}
for (const m of (block(sfxMage, "SfxMage.HitByStyle = {") || "").matchAll(/=\s*"([A-Za-z0-9_]+)"/g)) note(m[1], P.sfxMage);
for (const [name, files] of [...used.entries()].sort()) check(`звук ${name}`, known.has(name), `нет в реестре (${[...files].join(", ")})`);

console.log(`check_mage_fx\n  заклинаний ${abilities.length}, звуков в коде ${used.size}, в реестре ${known.size}`);
if (lines.length) console.log(lines.join("\n"));
console.log(`ИТОГО: ${checks} проверок, ${failures} провалов`);
process.exit(failures ? 1 : 0);
