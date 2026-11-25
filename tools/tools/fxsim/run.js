#!/usr/bin/env node
// tools/fxsim/run.js — прогон клиентских эффектов способностей без Studio.
// Собирает движок-заглушку (engine.lua) + настоящие модули клиента и Shared/Config в один
// файл и запускает сценарии (scenarios.lua) в виртуальном времени.
//   LUAU=/путь/к/luau node tools/fxsim/run.js
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..', '..');
const PS = path.join(ROOT, 'src', 'StarterPlayer', 'StarterPlayerScripts');
const SH = path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared');
const luau = process.env.LUAU || 'luau';

const modules = {
  'Shared/Config/Sfx': path.join(SH, 'Config', 'Sfx.lua'),
  'Shared/Config/SfxMage': path.join(SH, 'Config', 'SfxMage.lua'),
  'Shared/Config/SfxSkills': path.join(SH, 'Config', 'SfxSkills.lua'),
  'PS/Lib/Bus': path.join(PS, 'Lib', 'Bus.lua'),
  'PS/Lib/FxTex': path.join(PS, 'Lib', 'FxTex.lua'),
  'PS/Lib/MageFxKit': path.join(PS, 'Lib', 'MageFxKit.lua'),
  'PS/Lib/FxAfter': path.join(PS, 'Lib', 'FxAfter.lua'),
  'PS/Controllers/MageSpellFx': path.join(PS, 'Controllers', 'MageSpellFx.lua'),
  'PS/Controllers/MageSpellFxPlus': path.join(PS, 'Controllers', 'MageSpellFxPlus.lua'),
  'PS/Controllers/AbilityFxPlus': path.join(PS, 'Controllers', 'AbilityFxPlus.lua'),
  'PS/Controllers/PlayerAnimator': path.join(__dirname, 'stub_animator.lua'),
};

let out = fs.readFileSync(path.join(__dirname, 'engine.lua'), 'utf8');
out += '\nlocal __SIM = SIM\nlocal function __VT() return VT end\n';
for (const [key, file] of Object.entries(modules)) {
  const src = fs.readFileSync(file, 'utf8').replace(/^--!\w+\s*$/m, '');
  out += `\nREGISTER(${JSON.stringify(key)}, function(script)\n${src}\nend)\n`;
}
out += '\n' + fs.readFileSync(path.join(__dirname, 'scenarios.lua'), 'utf8');
const tmp = path.join(os.tmpdir(), 'fxsim_bundle.lua');
fs.writeFileSync(tmp, out);
const res = spawnSync(luau, [tmp], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
process.stdout.write(res.stdout || '');
process.stderr.write(res.stderr || '');
if (res.status !== 0 || /ИТОГО: [1-9]\d* провал/.test(res.stdout || '')) process.exit(1);
