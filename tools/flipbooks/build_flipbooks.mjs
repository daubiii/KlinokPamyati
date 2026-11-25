#!/usr/bin/env node
// Листы-флипбуки для частиц Roblox из эффектов pixelfx (MIT, https://github.com/patch-gg/pixelfx).
//   node tools/flipbooks/build_flipbooks.mjs <путь к pixelfx> <out> [имя…]
// Каждый лист — 1024×1024: сетка 4×4 (16 кадров по 256) или 8×8 (64 кадра по 128), кадры слева
// направо, сверху вниз — как ждёт ParticleEmitter.FlipbookLayout. Кадры берутся равномерно из окна
// [from, to] секунд эффекта, обрезаются по общей рамке и вписываются в квадрат без сглаживания.
// Цвета — из палитры эффекта (тинт частицы в игре — белый). Список листов — SHEETS ниже.
import { join } from "node:path";
import { mkdirSync, writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const [, , PFX, OUT, ...only] = process.argv;
if (!PFX || !OUT) {
  console.error("usage: build_flipbooks.mjs <pixelfx dir> <out dir> [name…]");
  process.exit(1);
}
const lib = await import(pathToFileURL(join(PFX, "tools/lib/fxlib.mjs")).href);
const { encodePNG } = await import(pathToFileURL(join(PFX, "tools/lib/png.mjs")).href);

const INK = ["#07060f", "#1d1b3a", "#3b2f86", "#7a5cff", "#d8ccff"];
const MEMORY = ["#04161c", "#0f4f63", "#1f8fa8", "#6fe3ff", "#effcff"];
const SLAG = ["#1a0f0c", "#54362a", "#c2381a", "#ff7a2b", "#ffd68a"];
const FIRE = ["#2a0a05", "#8c1d0c", "#e2572b", "#ffb347", "#fff1c2"];
const GOLD = ["#2a1c08", "#7a5418", "#d6a23a", "#ffd45a", "#fff6d8"];
const BLOOD = ["#1a0507", "#5e0f16", "#b8242e", "#ff5a4a", "#ffe0d8"];
const WATER = ["#041824", "#0c4a6e", "#1e7fc2", "#4fd6ff", "#effcff"];
const THORN = ["#08140a", "#1f4a22", "#3e8a2a", "#8ee04a", "#eaffd6"];
const STEEL = ["#121418", "#3a4048", "#8a96a6", "#d6e0ee", "#ffffff"];

// name: имя листа (= ключ текстуры в FxWeaponsV2), id: эффект pixelfx, grid: 4 | 8,
// from/to: окно времени (с), opts: опции эффекта (palette, seed…), what: для чего.
export const SHEETS = [
  { name: "fb_scythe", from: 0, to: 1.5, id: "melee/scythe-reap", grid: 4, opts: { palette: STEEL }, what: "серп косы: Жатва, Шлаковый смерч, Гон, Забвение" },
  { name: "fb_slash", from: 0, to: 0.42, id: "melee/sword-slash", grid: 4, opts: { palette: STEEL }, what: "разрез клинка: срезы, рывки" },
  { name: "fb_cleave", from: 0.15, to: 1.4, id: "melee/heavy-cleave", grid: 4, opts: { palette: SLAG }, what: "раскалённый клинок-призрак Первой отливки" },
  { name: "fb_hit", from: 0, to: 0.32, id: "impacts/hit-spark", grid: 4, opts: { palette: STEEL }, what: "искра попадания" },
  { name: "fb_crit", from: 0, to: 0.6, id: "impacts/crit-hit", grid: 4, opts: { palette: GOLD }, what: "сильное попадание: финалы" },
  { name: "fb_slam", from: 0, to: 2.0, id: "impacts/ground-slam", grid: 4, opts: { palette: SLAG }, what: "удар в землю: тигель, смерч, отливка" },
  { name: "fb_wave", from: 0, to: 2.4, id: "water/wave-crash", grid: 4, opts: { palette: WATER }, what: "гребень волны Прилива" },
  { name: "fb_splash", from: 0.1, to: 1.6, id: "water/splash", grid: 4, opts: { palette: WATER }, what: "всплеск и лужа" },
  { name: "fb_pillar", from: 0, to: 4.4, id: "fire/flame-pillar", grid: 8, opts: { palette: FIRE }, what: "огненный столб Горнила" },
  { name: "fb_feathers", from: 0, to: 2.4, id: "holy/feather-burst", grid: 4, opts: { palette: GOLD }, what: "взрыв перьев сокола" },
  { name: "fb_bird", id: "critters/bird", grid: 4, opts: { palette: GOLD }, what: "сокол в полёте (петля)" },
  { name: "fb_thorns", from: 0, to: 2.2, id: "nature/thorns", grid: 4, opts: { palette: THORN }, what: "лозы Секатора" },
  { name: "fb_roots", from: 0, to: 2.2, id: "nature/root-snare", grid: 4, opts: { palette: THORN }, what: "корни держат врага" },
  { name: "fb_tendrils", from: 0.2, to: 2.8, id: "shadow/shadow-tendrils", grid: 4, opts: { palette: INK }, what: "чернильные жгуты" },
  { name: "fb_inkburst", from: 0, to: 2.6, id: "shadow/dark-explosion", grid: 4, opts: { palette: INK }, what: "клякса-взрыв" },
  { name: "fb_runes", id: "arcane/rune-circle", grid: 4, opts: { palette: INK }, what: "буквы Строки, печать" },
  { name: "fb_erase", from: 0, to: 2.6, id: "spawn/disintegrate", grid: 4, opts: { palette: ["#0c0b10", "#3a3848", "#9a98aa", "#e8e6f0", "#ffffff"] }, what: "враг стирается обрывками" },
  { name: "fb_memory", from: 0, to: 1.2, id: "arcane/blink-in", grid: 4, opts: { palette: MEMORY }, what: "двойник Клинка Памяти появляется" },
  { name: "fb_bite", from: 0, to: 0.5, id: "melee/claw-swipe", grid: 4, opts: { palette: BLOOD }, what: "укус гончей" },
  { name: "fb_jaws", from: 0, to: 0.6, id: "impacts/blunt-hit", grid: 4, opts: { palette: STEEL }, what: "захлоп капкана" },
];

const CELL = { 4: 256, 8: 128 };

function alphaBox(frames, w, h) {
  let x0 = w, y0 = h, x1 = -1, y1 = -1;
  for (const f of frames) {
    const d = f.clear;
    for (let y = 0; y < h; y++)
      for (let x = 0; x < w; x++)
        if (d[(y * w + x) * 4 + 3] > 8) {
          if (x < x0) x0 = x;
          if (x > x1) x1 = x;
          if (y < y0) y0 = y;
          if (y > y1) y1 = y;
        }
  }
  return x1 < 0 ? [0, 0, w - 1, h - 1] : [x0, y0, x1, y1];
}

mkdirSync(OUT, { recursive: true });
const manifest = [];
for (const spec of SHEETS) {
  if (only.length && !only.includes(spec.name)) continue;
  const fx = await lib.loadEffect(spec.id, join(PFX, "src", "fx"));
  const n = spec.grid * spec.grid;
  const dur = fx.meta.duration;
  const from = spec.from ?? 0, to = spec.to ?? dur;
  const fps = Math.max(fx.meta.fps ?? 30, Math.ceil((n + 1) / Math.max(to - from, 0.05)));
  const r = lib.renderFrames(fx, { fps, bg: "none", actor: false, options: spec.opts, seed: spec.seed ?? 3 });
  const picked = [];
  for (let i = 0; i < n; i++) {
    const t = from + (to - from) * (fx.meta.loop ? i / n : i / (n - 1));
    const k = Math.min(r.n - 1, Math.round(t * r.fps));
    picked.push(r.frames[k]);
  }
  const [x0, y0, x1, y1] = alphaBox(picked, r.w, r.h);
  const bw = x1 - x0 + 1, bh = y1 - y0 + 1, side = Math.max(bw, bh) + 2;
  const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
  const cell = CELL[spec.grid], size = cell * spec.grid;
  const scale = cell / side;
  const sheet = new Uint8ClampedArray(size * size * 4);
  picked.forEach((f, i) => {
    const gx = (i % spec.grid) * cell, gy = Math.floor(i / spec.grid) * cell;
    for (let y = 0; y < cell; y++)
      for (let x = 0; x < cell; x++) {
        const sx = Math.floor(cx - side / 2 + x / scale + 0.5), sy = Math.floor(cy - side / 2 + y / scale + 0.5);
        if (sx < 0 || sy < 0 || sx >= r.w || sy >= r.h) continue;
        const s = (sy * r.w + sx) * 4, d = ((gy + y) * size + gx + x) * 4;
        for (let c = 0; c < 4; c++) sheet[d + c] = f.clear[s + c];
      }
  });
  writeFileSync(join(OUT, `${spec.name}.png`), encodePNG(size, size, sheet));
  // где «опора» эффекта (origin) внутри кадра: доля от центра, -0.5..0.5 (для ног столба)
  const [ox, oy] = fx.meta.origin;
  manifest.push({
    name: spec.name, id: spec.id, grid: spec.grid, frames: n, loop: !!fx.meta.loop, duration: +(to - from).toFixed(2),
    pivot: [+((ox - cx) / side).toFixed(3), +((oy - cy) / side).toFixed(3)], what: spec.what,
  });
  console.log(`${spec.name.padEnd(13)} ${spec.id.padEnd(24)} ${n} кадров, ${(to - from).toFixed(2)} с, рамка ${bw}×${bh}`);
}
writeFileSync(join(OUT, "flipbooks.json"), JSON.stringify(manifest, null, 1));
