"""Превью сцены «Клинок читает память» (ChestRevealController) → MP4.

Повторяет тайминги контроллера: падение сундука, сборка Клинка Памяти,
удар в замок, крышка, пульсы редкостей, проявление находки и карточка.
Рендер — пиксельный (800×450, ×2 nearest), сундук — тот же софт-растеризатор,
что и атлас (chestlib). Оружие на превью — пиксельный спрайт-заглушка:
в игре на его месте вращается 3D-модель (Ui.weaponView).

    python3 tools/chests/preview_reveal.py            # оба примера
    python3 tools/chests/preview_reveal.py f1_gold    # один
"""
import math
import os
import random
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
import chestlib as C  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'previews')
W, H = 800, 450          # внутреннее разрешение (дизайн 1600×900 × 0.5)
UP = 2                   # ×2 nearest → 1600×900
FPS = 30
K = 0.5                  # дизайн → внутренние пиксели

RARITY = [
    ('common', 'ОБЫЧНОЕ', (170, 176, 184)),
    ('rare', 'РЕДКОЕ', (88, 200, 92)),
    ('epic', 'ЭПИЧЕСКОЕ', (176, 106, 244)),
    ('legendary', 'ЛЕГЕНДАРНОЕ', (255, 176, 46)),
    ('mythic', 'МИФИЧЕСКОЕ', (240, 80, 84)),
    ('secret', 'СЕКРЕТНОЕ', (120, 232, 255)),
]
MEM = (120, 232, 255)
GOLD = (255, 204, 84)
BONE = (248, 240, 222)
GREY = (160, 150, 140)
GREEN = (120, 220, 110)
WHITE = (255, 255, 255)

EXAMPLES = {
    'f1_gold': dict(
        design='f1_gold', floor=1, gold=True, rarity='legendary',
        title='ЗОЛОТОЙ СУНДУК ПРИВРАТНИКА', sub='Этаж 1 · Привратный двор',
        colors=['#3A2E2A', '#7A5C48', '#C98B4A', '#D9D2C5'],
        whisper='«звон ключей и шаги караула»',
        item='ПЛАМЕННЫЙ КЛИНОК', kind='Меч', sprite='sword', power=118, diff='+22%',
        ability='Способность: Огненный след',
        extras=[('armor', 'Броня: Шлем привратной стражи', (88, 200, 92)),
                ('flask', 'Припасы: Настой памяти ×2, Хлеб ×1', BONE)],
        gold_amount=180, material='Ржавое железо +6', remaining=0,
        chest_name='ЗОЛОТОЙ СУНДУК ПРИВРАТНИКА',
    ),
    'f5_common': dict(
        design='f5_common', floor=5, gold=False, rarity='secret',
        title='СУНДУК-ФОЛИАНТ', sub='Этаж 5 · Зал хроник',
        colors=['#1D1B3A', '#4A3F8F', '#8E7CE0', '#B8E3FF'],
        whisper='«шелест страниц и скрип пера»',
        item='ПОСОХ НЕДРЕМЛЮЩЕГО ОКА', kind='Посох', sprite='staff', power=141, diff='+35%',
        ability='Способность: Страница забвения',
        extras=[('ring', 'Аксессуар: Кольцо закладки', (176, 106, 244)),
                ('flask', 'Припасы: Отвар эха ×1', BONE)],
        gold_amount=240, material='Чернильная пыль +4', remaining=2,
        chest_name='СУНДУК-ФОЛИАНТ',
    ),
}


def hx(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
    return a + (b - a) * t


def lerpc(a, b, t):
    return tuple(int(lerp(a[i], b[i], t)) for i in range(3))


def clamp01(x):
    return max(0.0, min(1.0, x))


def e_quad(a):
    return 1 - (1 - a) ** 2


def e_quart(a):
    return 1 - (1 - a) ** 4


def e_back(a, s=1.70158):
    a -= 1
    return a * a * ((s + 1) * a + s) + 1


def font(size, bold=True):
    cands = ['/usr/share/fonts/liberation-sans/LiberationSans-Bold.ttf' if bold else
             '/usr/share/fonts/liberation-sans/LiberationSans-Regular.ttf']
    for p in cands:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    import glob
    g = glob.glob('/usr/share/fonts/**/LiberationSans-Bold.ttf', recursive=True)
    return ImageFont.truetype(g[0], size)


FONTS = {}


def F(size, bold=True):
    key = (size, bold)
    if key not in FONTS:
        FONTS[key] = font(size, bold)
    return FONTS[key]


def text(img, xy, s, size, color, anchor='mm', alpha=1.0, stroke=2):
    if alpha <= 0.01 or not s:
        return
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.fontmode = '1'  # без сглаживания — пиксельно
    d.text(xy, s, font=F(size), fill=color + (255,), anchor=anchor, stroke_width=stroke, stroke_fill=(14, 9, 6, 255))
    if alpha < 1:
        a = np.array(layer)
        a[..., 3] = (a[..., 3] * alpha).astype('uint8')
        layer = Image.fromarray(a)
    img.alpha_composite(layer)


def radial(size, color, alpha):
    w, h = size
    y, x = np.mgrid[0:h, 0:w]
    d = np.sqrt(((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2)
    a = np.clip(1 - d, 0, 1) ** 2 * alpha
    arr = np.zeros((h, w, 4), dtype='uint8')
    arr[..., 0], arr[..., 1], arr[..., 2] = color
    arr[..., 3] = (a * 255).astype('uint8')
    return Image.fromarray(arr, 'RGBA')


def paste_center(img, layer, cx, cy):
    img.alpha_composite(layer, (int(cx - layer.width / 2), int(cy - layer.height / 2)))


# ---------- спрайты ----------

BLADE_ROWS = None
BLADE_COLORS = {k: hx(v) for k, v in C.BLADE_COLORS.items()}


def blade_rows():
    global BLADE_ROWS
    if BLADE_ROWS is None:
        BLADE_ROWS = C.blade_bitmap()
    return BLADE_ROWS


SWORD = [
    "....k....", "...kwk...", "...kwk...", "..kwsdk..", "..kwsdk..", "..kwsdk..", "..kwsdk..", "..kwsdk..",
    "..kwsdk..", "..kwsdk..", "..kwsdk..", "..kwsdk..", "..kwsdk..", "..kwsdk..", "..kwsdk..", "..kwsdk..",
    "..kwsdk..", "..kwsdk..", "..kwsdk..", ".kkwsdkk.", "kgggggggk", "kgyggygk.", ".kkkkkkk.", "...kbk...",
    "...kbk...", "...kbk...", "...kbk...", "..kgggk..", "...kkk...",
]
STAFF = [
    "...kkk...", "..kcwck..", ".kcwccck.", ".kcwccck.", ".kcccccdk", "..kccdk..", "..kgkgk..", ".kg...gk.",
    ".kgkkkgk.", "..kgbgk..", "...kbk...", "...kbk...", "...kbk...", "...kbk...", "...kgk...", "...kbk...",
    "...kbk...", "...kbk...", "...kbk...", "...kbk...", "...kgk...", "...kbk...", "...kbk...", "...kbk...",
    "...kbk...", "...kgk...", "...kkk...",
]


def sprite(kind, rarity_color):
    rows = SWORD if kind == 'sword' else STAFF
    light = lerpc(rarity_color, WHITE, 0.55)
    dark = lerpc(rarity_color, (20, 14, 12), 0.45)
    pal = {'k': (20, 14, 12), 'w': lerpc(light, WHITE, 0.6), 's': light, 'd': dark, 'g': (230, 180, 70),
           'y': (255, 236, 150), 'b': (92, 58, 36), 'c': lerpc(rarity_color, WHITE, 0.25)}
    h, w = len(rows), len(rows[0])
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                px[x, y] = pal[ch] + (255,)
    return im


# ---------- сундук ----------

class ChestArt:
    """Рендер сундука в фиксированном масштабе; точки замка/проёма/дна в кадре."""

    def __init__(self, design_id):
        self.d = next(d for d in C.all_designs() if d.id == design_id)
        self.cam = C.Camera()
        self.size = (230, 200)
        r = math.sqrt(self.d.W ** 2 + self.d.D ** 2 + (self.d.H * 1.6) ** 2) / 2
        self.scale = 150 / (2 * r) * 1.25
        lo, hi = C.bounds2d(self.d, self.cam, 0)
        cx, cy = (lo + hi) / 2
        self.offset = (self.size[0] / 2 - cx * self.scale, self.size[1] / 2 + 24 + cy * self.scale)
        self.cache = {}

    def image(self, lid=0.0, yaw=0.0):
        key = (round(lid, 1), round(yaw, 2))
        if key not in self.cache:
            tf = None
            if yaw:
                M = C.rot(0, yaw, 0)
                tf = (lambda v, M=M: v @ M.T)
            arr, _ = C.render(self.d, self.size, lid_angle=lid, cam=self.cam, scale=self.scale, offset=self.offset, transform=tf)
            self.cache[key] = Image.fromarray((arr.clip(0, 1) * 255).astype('uint8'), 'RGBA')
        return self.cache[key]

    def point(self, p, at):
        x, y = C.project_point(p, self.cam, self.scale, self.offset)
        return (at[0] - self.size[0] / 2 + x, at[1] - self.size[1] / 2 + y)


# ---------- сцена ----------

VIEW = (400, 287)        # центр витрины сундука (дизайн 800, 575)
ITEM = (400, 135)        # находка (дизайн 800, 270)
PX = 3                   # пиксель клинка
BW, BH = 15 * PX, 50 * PX
HOVER_TIP = (ITEM[0], ITEM[1] + BH / 2)


def timeline(ex):
    """Ключевые моменты (с) — как в ChestRevealController."""
    t = {}
    t['drop'] = 0.3
    t['land'] = t['drop'] + 0.5
    t['hop_end'] = t['land'] + 0.28
    t['blade'] = t['hop_end'] + 0.15
    t['blade_done'] = t['blade'] + 1.0
    t['strike'] = t['blade_done'] + 0.25
    t['wind_end'] = t['strike'] + 0.22
    t['hit_start'] = t['wind_end'] + 0.06
    t['hit'] = t['hit_start'] + 0.08
    t['lid'] = t['hit'] + 0.32
    t['lid_end'] = t['lid'] + 0.6
    t['read'] = t['lid_end']
    idx = [r[0] for r in RARITY].index(ex['rarity']) + 1
    secret = ex['rarity'] == 'secret'
    last = 5 if secret else idx
    pulses = []
    x = t['read'] + 0.35
    for i in range(1, last + 1):
        pulses.append((x, i))
        x += 0.22 + 0.06 * i
    if secret:
        t['glitch'] = x
        x += 0.42 + 0.15
        pulses.append((x, 6))
        t['secret'] = x
    t['pulses'] = pulses
    t['reveal'] = x + 0.5
    t['item'] = t['reveal'] + 0.55
    t['card'] = t['item'] + 0.7
    t['end'] = t['card'] + 2.6
    return t


class Scene:
    def __init__(self, ex, seed=7):
        self.ex = ex
        self.rng = random.Random(seed)
        self.t = timeline(ex)
        self.chest = ChestArt(ex['design'])
        cols = [hx(c) for c in ex['colors']]
        self.floor = cols[0]
        self.palette = [MEM, lerpc(cols[0], WHITE, 0.25), cols[2], cols[3]]
        self.accent = GOLD if ex['gold'] else cols[2]
        self.rarity = next(r for r in RARITY if r[0] == ex['rarity'])
        self.lock = self.chest.point(self.chest.d.lock, VIEW)
        self.mouth = self.chest.point((0, self.chest.d.hinge[0], 0), VIEW)
        self.base = self.chest.point((0, 0, self.chest.d.D / 2), VIEW)
        left = self.chest.point((-self.chest.d.W / 2, 0, self.chest.d.D / 2), VIEW)
        right = self.chest.point((self.chest.d.W / 2, 0, self.chest.d.D / 2), VIEW)
        self.base_w = max(abs(right[0] - left[0]), 60)
        # клинок
        rows = blade_rows()
        self.cells = []
        for r in range(50):
            row = rows[r]
            for c in range(15):
                ch = row[c]
                if ch != '.':
                    a = self.rng.random() * math.tau
                    dist = (240 + self.rng.random() * 340) * K
                    home = (c * PX, (49 - r) * PX)
                    start = (BW / 2 + math.cos(a) * dist, BH / 2 + math.sin(a) * dist * 0.7)
                    delay = (50 - (r + 1)) / 50 * 0.6 + self.rng.random() * 0.15
                    self.cells.append(dict(home=home, start=start, delay=delay, ch=ch, row=r + 1,
                                           color=BLADE_COLORS[ch], out=self.rng.random(), keep=(len(self.cells) % 2 == 0),
                                           jx=self.rng.uniform(-30, 30) * K, jy=self.rng.uniform(-30, 30) * K))
        # пылинки
        self.motes = [dict(t0=self.rng.uniform(-4, 12), x=self.rng.uniform(40, 760), y=self.rng.uniform(310, 460),
                           rise=self.rng.uniform(80, 180), drift=self.rng.uniform(-20, 20), life=self.rng.uniform(2.6, 4.2),
                           s=self.rng.choice([1, 2]), c=self.rng.choice(self.palette)) for _ in range(70)]
        # пыль при падении
        self.dust = []
        for _ in range(26 if ex['gold'] else 18):
            side = self.rng.choice([-1, 1])
            self.dust.append(dict(x=self.base[0] + side * self.base_w * self.rng.uniform(0.2, 0.55),
                                  y=self.base[1] + self.rng.uniform(-2, 3), vx=side * self.rng.uniform(30, 110),
                                  vy=-self.rng.uniform(10, 30), life=self.rng.uniform(0.5, 0.9),
                                  s=self.rng.choice([2, 3, 4]), c=lerpc(self.rng.choice(self.palette[1:]), (180, 170, 160), 0.5)))
        # искры (burst)
        self.bursts = []
        self.add_burst(self.t['hit'], self.lock, [WHITE, MEM, self.accent], 30, 170 * K)
        self.add_burst(self.t['lid_end'], self.mouth, self.palette, 24, 160 * K)
        if ex['gold']:
            self.add_burst(self.t['land'], (self.base[0], self.base[1] - 30), [GOLD, WHITE, self.floor], 22, 180 * K)
        self.add_burst(self.t['item'], ITEM, [self.rarity[2], WHITE, MEM], 34, 240 * K)
        # память по спирали
        self.stream = []
        tt = self.t['read']
        while tt < self.t['reveal']:
            for _ in range(2):
                a0 = self.rng.random() * math.tau
                self.stream.append(dict(t0=tt, life=self.rng.uniform(0.8, 1.3), fx=self.mouth[0] + self.rng.uniform(-30, 30),
                                        fy=self.mouth[1] + self.rng.uniform(-4, 4), k=self.rng.uniform(0.25, 0.65),
                                        a0=a0, r=self.rng.uniform(25, 60), s=self.rng.choice([2, 3, 3, 4]),
                                        rc=self.rng.random() < 0.5, c=self.rng.choice(self.palette)))
            tt += 1 / 30
        # кольца
        self.rings = [(self.t['blade_done'], (HOVER_TIP[0], 0), MEM, 60, 340, 0.5, 'blade'),
                      (self.t['hit'], self.lock, MEM, 30, 260, 0.4, None),
                      (self.t['hit'], self.lock, self.accent, 20, 160, 0.3, None),
                      (self.t['item'], ITEM, self.rarity[2], 60, 520, 0.6, None)]
        for (tp, i) in self.t['pulses']:
            final = (i == 6) or (RARITY[i - 1][0] == ex['rarity'])
            self.rings.append((tp, None, RARITY[i - 1][2], 50, 420 if final else 260, 0.45, 'pulse'))
        if 'secret' in self.t:
            for k in range(3):
                self.rings.append((self.t['secret'] + k * 0.14, None, MEM, 40, 520 + k * 120, 0.6, 'pulse'))
        self.rays_chest = [dict(base=-58 + i * (116 / 8), len=self.rng.uniform(0.75, 1.15) * 520 * K,
                                w=30 * K * (0.6 + 0.4 * ((i + 1) % 3) / 2), ph=self.rng.random() * 6) for i in range(9)]
        self.rays_item = [dict(base=i * 30, len=self.rng.uniform(0.75, 1.15) * 460 * K,
                               w=40 * K * (0.6 + 0.4 * ((i + 1) % 3) / 2), ph=self.rng.random() * 6) for i in range(12)]

    def add_burst(self, t0, c, colors, n, r):
        for _ in range(n):
            a = self.rng.random() * math.tau
            d = r * (0.4 + self.rng.random() * 0.8)
            self.bursts.append(dict(t0=t0, c=c, a=a, d=d, life=0.45 + self.rng.random() * 0.4,
                                    s=self.rng.choice([2, 3, 3, 4]), col=self.rng.choice(colors)))

    # --- состояния ---
    def blade_tip(self, t):
        T = self.t
        hover0 = (self.lock[0], self.lock[1] - 90 * K)
        wind = (self.lock[0], self.lock[1] - 150 * K)
        hit = (self.lock[0], self.lock[1] + 8 * K)
        bob = 0
        if t < T['strike']:
            p = hover0
            if t > T['blade_done']:
                bob = math.sin(t * 2.4) * 5 * K
        elif t < T['wind_end']:
            a = e_quad((t - T['strike']) / 0.22)
            p = (lerp(hover0[0], wind[0], a), lerp(hover0[1], wind[1], a))
        elif t < T['hit_start']:
            p = wind
        elif t < T['hit']:
            a = ((t - T['hit_start']) / 0.08) ** 2
            p = (wind[0], lerp(wind[1], hit[1], a))
        elif t < T['lid']:
            p = hit
        elif t < T['lid_end']:
            a = e_back((t - T['lid']) / 0.6)
            p = (lerp(hit[0], HOVER_TIP[0], a), lerp(hit[1], HOVER_TIP[1], a))
        else:
            p = HOVER_TIP
            bob = math.sin(t * 2.4) * 5 * K
        jitter = 0
        if 'glitch' in self.t and self.t['glitch'] <= t < self.t['glitch'] + 0.42:
            jitter = 3 * K
        return (p[0] + self.rng.uniform(-jitter, jitter), p[1] + bob + self.rng.uniform(-jitter, jitter))

    def pulse_state(self, t):
        """(цвет дола, индекс редкости, время с последнего пульса)"""
        cur = None
        for (tp, i) in self.t['pulses']:
            if t >= tp:
                cur = (tp, i)
        if 'glitch' in self.t and self.t['glitch'] <= t < self.t['glitch'] + 0.42:
            k = int((t - self.t['glitch']) / 0.07)
            return (MEM if k % 2 else WHITE), (cur[1] if cur else 5), 1.0
        if not cur:
            return None, 0, 9
        return RARITY[cur[1] - 1][2], cur[1], t - cur[0]

    def shake(self, t):
        best = (0, 0)
        for (t0, amt, dur) in [(self.t['land'], 14 if self.ex['gold'] else 9, 0.3), (self.t['hit'], 16, 0.35),
                               (self.t['item'], 6, 0.25)] + self.final_shake():
            if t0 <= t < t0 + dur:
                k = (t0 + dur - t) / dur
                best = (self.rng.uniform(-1, 1) * amt * k * K, self.rng.uniform(-1, 1) * amt * k * K)
        return best

    def final_shake(self):
        out = []
        if self.ex['rarity'] in ('legendary', 'mythic', 'secret'):
            tp = self.t['pulses'][-1][0]
            out.append((tp, 8, 0.3))
        return out

    def flash(self, t):
        fl = [(self.t['hit'], WHITE, 0.55, 0.3), (self.t['item'], self.rarity[2], 0.45, 0.4)]
        if self.ex['rarity'] in ('legendary', 'mythic', 'secret'):
            fl.append((self.t['pulses'][-1][0], self.rarity[2], 0.35, 0.35))
        if 'secret' in self.t:
            fl.append((self.t['secret'], MEM, 0.5, 0.5))
        for (t0, col, s, dur) in fl:
            if t0 <= t < t0 + dur:
                return col, s * (1 - e_quad((t - t0) / dur))
        return None, 0

    # --- кадр ---
    def frame(self, t):
        T = self.t
        img = Image.new('RGBA', (W, H), (0, 0, 0, 255))
        # мир за затемнением (размытые пятна «долины»)
        world = getattr(self, 'world', None)
        if world is None:
            world = Image.new('RGBA', (W, H), (54, 72, 58, 255))
            dw = ImageDraw.Draw(world)
            for i in range(9):
                dw.rectangle([i * 95 - 20, 230 + (i % 3) * 18, i * 95 + 60, 450], fill=(70 + i * 4, 88, 66, 255))
            dw.rectangle([0, 0, W, 150], fill=(96, 122, 140, 255))
            world = world.filter(ImageFilter.GaussianBlur(24))
            self.world = world
        img.alpha_composite(world)
        dim = clamp01(t / 0.35) * 0.82
        img.alpha_composite(Image.new('RGBA', (W, H), (6, 5, 10, int(dim * 255))))

        sx, sy = self.shake(t)
        layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        # сияние этажа
        g = 0.18 * clamp01((t - 0.0) / 0.6) + (0.12 * clamp01((t - T['lid']) / 0.6))
        paste_center(layer, radial((700, 500), lerpc(self.floor, WHITE, 0.25), g * 1.4), 400, 280)
        # пылинки
        d = ImageDraw.Draw(layer)
        for m in self.motes:
            e = ((t - m['t0']) % m['life']) / m['life']
            x, y = m['x'] + m['drift'] * e, m['y'] - m['rise'] * e
            a = 0.65 * (1 - max(0, e - 0.4) / 0.6)
            d.rectangle([x, y, x + m['s'], y + m['s']], fill=m['c'] + (int(a * 255),))

        card_t = clamp01((t - T['card']) / 0.4)
        # лучи сундука
        if t >= T['lid']:
            grow = e_quart(clamp01((t - T['lid']) / 0.6))
            fade = 1 - clamp01((t - T['reveal']) / 0.5)
            col, idx, _ = self.pulse_state(t)
            rc = lerpc(self.floor, WHITE, 0.3) if col is None else lerpc(self.floor, col, 0.7)
            self.draw_rays(layer, self.mouth, self.rays_chest, rc, 0.65 * grow * fade, grow, t, sway=5)
        # тень
        if t >= T['drop'] and card_t < 1:
            k = clamp01((t - T['drop']) / 0.5)
            sw = self.base_w * 1.15 * (0.3 + 0.7 * k * k)
            sh = 22 * K * 2 * (0.3 + 0.7 * k * k)
            sl = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            ImageDraw.Draw(sl).ellipse([self.base[0] - sw / 2, self.base[1] + 3 - sh / 2, self.base[0] + sw / 2, self.base[1] + 3 + sh / 2],
                                       fill=(0, 0, 0, int(0.45 * k * 255 * (1 - card_t))))
            layer.alpha_composite(sl)
        # сундук
        if t >= T['drop'] and card_t < 1:
            lid = 0.0
            if t >= T['lid']:
                lid = self.chest.d.lid_max * e_quart(clamp01((t - T['lid']) / 0.6 * 1.3))
            yaw = 0.0
            dy = 0.0
            if t < T['land']:
                e = ((t - T['drop']) / 0.5) ** 2
                dy = -(1 - e) * 560 * K
                yaw = (1 - e) * 1.4
            elif t < T['hop_end']:
                dy = -math.sin((t - T['land']) / 0.28 * math.pi) * 14 * K
            dy += card_t * 380 * K * e_quad(card_t)
            im = self.chest.image(lid, yaw)
            if card_t > 0:
                a = np.array(im)
                a[..., 3] = (a[..., 3] * (1 - card_t)).astype('uint8')
                im = Image.fromarray(a)
            layer.alpha_composite(C_glow(im), (int(VIEW[0] - im.width / 2), int(VIEW[1] - im.height / 2 + dy)))
            layer.alpha_composite(im, (int(VIEW[0] - im.width / 2), int(VIEW[1] - im.height / 2 + dy)))
        # пыль
        d = ImageDraw.Draw(layer)
        for p in self.dust:
            e = (t - T['land']) / p['life']
            if 0 <= e < 1:
                k = 1 - (1 - e) ** 2
                x, y = p['x'] + p['vx'] * k, p['y'] + p['vy'] * k + 20 * e * e
                a = 1 - max(0, e - 0.5) / 0.5
                d.rectangle([x, y, x + p['s'], y + p['s']], fill=p['c'] + (int(a * 255),))
        # столб света и лучи находки
        if t >= T['item']:
            k = e_quart(clamp01((t - T['item']) / 0.5))
            a = 1 - 0.55 * clamp01((t - T['card']) / 0.6)
            pw = int(220 * K * k)
            if pw > 2:
                col = self.rarity[2]
                xs = np.linspace(-1, 1, pw)
                al = np.clip(1 - np.abs(xs), 0, 1) ** 1.6 * 0.85 * a
                arr = np.zeros((H, pw, 4), dtype='uint8')
                arr[..., 0], arr[..., 1], arr[..., 2] = col
                arr[..., 3] = (al[None, :] * 255).astype('uint8')
                layer.alpha_composite(Image.fromarray(arr, 'RGBA'), (int(ITEM[0] - pw / 2), 0))
            self.draw_rays(layer, ITEM, self.rays_item, self.rarity[2], 0.45 * k, k, t, spin=10)
        # карточка (под находкой)
        if t >= T['card']:
            self.draw_card(layer, t)
        # клинок
        if T['blade'] <= t < T['reveal']:
            self.draw_blade(layer, t)
        # осколки клинка → находка
        if T['reveal'] <= t < T['item'] + 0.1:
            self.draw_shatter(layer, t)
        # находка
        if t >= T['item']:
            k = clamp01((t - T['item']) / 0.5)
            scale = 0.15 + (1 - 0.15) * e_back(k)
            spr = sprite(self.ex['sprite'], self.rarity[2])
            spin = math.cos((t - T['item']) * 0.8)
            w = max(1, int(spr.width * 5 * abs(spin) * scale))
            h = max(1, int(spr.height * 5 * scale))
            s = spr.resize((w, h), Image.NEAREST)
            if spin < 0:
                s = s.transpose(Image.FLIP_LEFT_RIGHT)
            s = s.rotate(-45 if self.ex['sprite'] == 'sword' else -30, resample=Image.NEAREST, expand=True)
            paste_center(layer, radial((200, 200), self.rarity[2], 0.5 * k), ITEM[0], ITEM[1])
            layer.alpha_composite(C_glow(s), (int(ITEM[0] - s.width / 2), int(ITEM[1] - s.height / 2)))
            paste_center(layer, s, ITEM[0], ITEM[1])
        # кольца, искры, поток памяти
        self.draw_fx(layer, t)
        # тексты
        self.draw_texts(layer, t)

        img.alpha_composite(layer.transform(layer.size, Image.AFFINE, (1, 0, -sx, 0, 1, -sy)))
        col, s = self.flash(t)
        if col and s > 0:
            img.alpha_composite(Image.new('RGBA', (W, H), col + (int(s * 255),)))
        return img.convert('RGB').resize((W * UP, H * UP), Image.NEAREST)

    def draw_rays(self, layer, origin, rays, color, alpha, grow, t, sway=0, spin=0):
        if alpha <= 0.01:
            return
        rl = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(rl)
        for r in rays:
            ang = math.radians(r['base'] + t * spin + math.sin(t * 0.9 + r['ph']) * sway)
            L = r['len'] * grow
            dx, dy = math.sin(ang), -math.cos(ang)
            px, py = -dy, dx
            hw = r['w'] / 2
            for seg in range(6):
                a0, a1 = seg / 6, (seg + 1) / 6
                al = (1 - a0) * 0.9
                pts = [(origin[0] + dx * L * a0 + px * hw, origin[1] + dy * L * a0 + py * hw),
                       (origin[0] + dx * L * a1 + px * hw, origin[1] + dy * L * a1 + py * hw),
                       (origin[0] + dx * L * a1 - px * hw, origin[1] + dy * L * a1 - py * hw),
                       (origin[0] + dx * L * a0 - px * hw, origin[1] + dy * L * a0 - py * hw)]
                d.polygon(pts, fill=color + (int(al * alpha * 255),))
        layer.alpha_composite(rl.filter(ImageFilter.GaussianBlur(1.5)))

    def draw_blade(self, layer, t):
        T = self.t
        tip = self.blade_tip(t)
        ox, oy = tip[0] - BW / 2, tip[1] - BH
        col, idx, since = self.pulse_state(t)
        # сияние за клинком
        ga = 0.0
        if t > T['blade'] + 0.5:
            ga = 0.45 * clamp01((t - T['blade'] - 0.5) / 0.6)
        gcol = MEM
        if col is not None:
            gcol = col
            ga = max(ga, 0.85 * (1 - clamp01(since / 0.35)) + 0.4)
        if ga > 0:
            paste_center(layer, radial((int(BW * 3.2), int(BH * 1.5)), gcol, ga), tip[0], tip[1] - BH / 2)
        d = ImageDraw.Draw(layer)
        for c in self.cells:
            a = clamp01((t - T['blade'] - c['delay']) / 0.4)
            if a <= 0:
                continue
            e = e_quart(a)
            x = lerp(c['start'][0], c['home'][0], e)
            y = lerp(c['start'][1], c['home'][1], e)
            base = c['color']
            if c['ch'] in 'fG' and col is not None:
                base = col
            color = lerpc(MEM, base, e)
            d.rectangle([ox + x, oy + y, ox + x + PX - 1, oy + y + PX - 1], fill=color + (int(e * 255),))

    def draw_shatter(self, layer, t):
        T = self.t
        tip = HOVER_TIP
        ox, oy = tip[0] - BW / 2, tip[1] - BH
        d = ImageDraw.Draw(layer)
        for c in self.cells:
            if not c['keep']:
                continue
            life = 0.55 + c['out'] * 0.2
            e = (t - T['reveal']) / life
            if not 0 <= e < 1:
                continue
            sx, sy = ox + c['home'][0] + PX / 2, oy + c['home'][1] + PX / 2
            vx, vy = sx - ITEM[0], sy - ITEM[1]
            n = math.hypot(vx, vy) or 1
            dist = (40 + c['out'] * 120) * K
            outp = (sx + vx / n * dist + c['jx'], sy + vy / n * dist + c['jy'])
            if e < 0.45:
                k = e_quad(e / 0.45)
                x, y = lerp(sx, outp[0], k), lerp(sy, outp[1], k)
            else:
                k = ((e - 0.45) / 0.55) ** 4
                x, y = lerp(outp[0], ITEM[0], k), lerp(outp[1], ITEM[1], k)
            a = 1 - max(0, e - 0.8) / 0.2
            col = lerpc(c['color'], self.rarity[2], 0.5)
            d.rectangle([x - 1, y - 1, x + PX - 2, y + PX - 2], fill=col + (int(a * 255),))

    def draw_fx(self, layer, t):
        d = ImageDraw.Draw(layer)
        # поток памяти
        col, idx, _ = self.pulse_state(t)
        for p in self.stream:
            e = (t - p['t0']) / p['life']
            if not 0 <= e < 1:
                continue
            tip = self.blade_tip(t)
            target = (tip[0], tip[1] - BH * p['k'])
            k = e * e * (3 - 2 * e)
            bx, by = lerp(p['fx'], target[0], k), lerp(p['fy'], target[1], k)
            r = p['r'] * math.sin(e * math.pi) * (1 - e * 0.5)
            ang = p['a0'] + e * 7
            x, y = bx + math.cos(ang) * r, by + math.sin(ang) * r * 0.45
            c = (col or MEM) if p['rc'] else p['c']
            a = 1 - max(0, e - 0.75) / 0.25
            d.rectangle([x, y, x + p['s'] - 1, y + p['s'] - 1], fill=c + (int(a * 255),))
        # искры
        for b in self.bursts:
            e = (t - b['t0']) / b['life']
            if not 0 <= e < 1:
                continue
            k = e_quart(e)
            x = b['c'][0] + math.cos(b['a']) * b['d'] * k
            y = b['c'][1] + math.sin(b['a']) * b['d'] * k + 15 * k
            d.rectangle([x, y, x + b['s'] - 1, y + b['s'] - 1], fill=b['col'] + (int((1 - e) * 255),))
        # кольца
        for (t0, c, color, r0, r1, dur, kind) in self.rings:
            e = (t - t0) / dur
            if not 0 <= e < 1:
                continue
            if c is None:
                tip = self.blade_tip(t)
                c = (tip[0], tip[1] - BH * 0.45)
            elif kind == 'blade':
                tip = self.blade_tip(t)
                c = (tip[0], tip[1] - BH * 0.5)
            r = lerp(r0, r1, e_quart(e)) * K / 2
            th = max(1, int(lerp(3, 1, e)))
            d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], outline=color + (int((1 - e) * 255),), width=th)

    def draw_texts(self, layer, t):
        T = self.t
        ex = self.ex
        a = clamp01(t / 0.4)
        text(layer, (28, 17), ex['title'], 12, GOLD if ex['gold'] else BONE, anchor='lm', alpha=a)
        text(layer, (28, 34), ex['sub'], 9, GREY, anchor='lm', alpha=a, stroke=1)
        if t < T['card']:
            text(layer, (780, 438), 'КЛИК / ПРОБЕЛ — ПРОПУСТИТЬ', 8, GREY, anchor='rm', alpha=0.7 * a, stroke=1)
        # редкость
        col, idx, since = self.pulse_state(t)
        if idx and t < T['glitch' if False else 'end']:
            name = RARITY[idx - 1][1]
            if 'glitch' in T and T['glitch'] <= t < T['secret']:
                name = RARITY[4][1]
            scale = 1 + 0.3 * (1 - clamp01(since / 0.22))
            text(layer, (400, 30), name, int(20 * scale), RARITY[idx - 1][2] if col is None or idx else col, alpha=1, stroke=3)
        # шёпот
        if T['read'] <= t:
            fade = 1 - clamp01((t - T['card']) / 0.3)
            ta = clamp01((t - T['read']) / 0.3) * fade
            title = 'ТАКОГО КЛИНОК ЕЩЁ НЕ ПОМНИЛ' if ('secret' in T and t >= T['secret']) else 'КЛИНОК ЧИТАЕТ ПАМЯТЬ'
            text(layer, (400, 397), title, 8, MEM, alpha=ta, stroke=1)
            n = int((t - T['read']) * 34)
            text(layer, (400, 414), ex['whisper'][:n] if t < T['reveal'] else ex['whisper'], 12, BONE, alpha=fade, stroke=2)

    def draw_card(self, layer, t):
        T = self.t
        ex = self.ex
        k = clamp01((t - T['card']) / 0.45)
        e = e_back(k)
        scale = 0.86 + 0.14 * e
        alpha = clamp01(k / 0.55)
        cw, ch = 300, 380
        card = Image.new('RGBA', (cw + 40, ch + 40), (0, 0, 0, 0))
        d = ImageDraw.Draw(card)
        col = self.rarity[2]
        card.alpha_composite(radial((cw + 40, ch + 40), col, 0.35))
        x0, y0 = 20, 20
        d.rectangle([x0 + 3, y0 + 4, x0 + cw + 3, y0 + ch + 4], fill=(0, 0, 0, 120))
        d.rectangle([x0, y0, x0 + cw, y0 + ch], fill=(30, 22, 19, 245), outline=(122, 86, 54, 255), width=2)
        for (cx, cy) in ((x0, y0), (x0 + cw, y0), (x0, y0 + ch), (x0 + cw, y0 + ch)):
            d.rectangle([cx - 5, cy - 5, cx + 5, cy + 5], fill=(214, 160, 70, 255), outline=(26, 16, 10, 255))
        # витрина
        d.rectangle([x0 + 30, y0 + 18, x0 + cw - 30, y0 + 152], fill=lerpc(col, (20, 14, 12), 0.72) + (255,), outline=col + (255,), width=2)
        text(card, (x0 + cw / 2, y0 + 9), 'НАХОДКА · ' + ex['chest_name'], 7, GREY, stroke=1)
        text(card, (x0 + cw / 2, y0 + 166), ex['item'], 14, col, stroke=2)
        text(card, (x0 + cw / 2, y0 + 186), ('%s · %s' % (self.rarity[1], ex['kind'])).upper(), 8, GREY, stroke=1)
        text(card, (x0 + cw / 2, y0 + 202), 'МОЩЬ', 8, BONE, stroke=1)
        p = int(ex['power'] * (1 - (1 - clamp01((t - T['card']) / 0.7)) ** 3))
        text(card, (x0 + cw / 2 - 4, y0 + 220), str(p), 20, GOLD, anchor='rm', stroke=2)
        text(card, (x0 + cw / 2 + 6, y0 + 221), ex['diff'], 12, GREEN, anchor='lm', stroke=2)
        text(card, (x0 + cw / 2, y0 + 242), ex['ability'], 8, GOLD, stroke=1)
        y = y0 + 262
        icons = {'armor': (150, 160, 175), 'ring': (220, 190, 90), 'flask': (214, 70, 60)}
        for (ic, s, c) in ex['extras']:
            d.rectangle([x0 + 22, y - 6, x0 + 34, y + 6], fill=icons[ic] + (255,), outline=(14, 9, 6, 255))
            text(card, (x0 + 42, y), s, 8, c, anchor='lm', stroke=1)
            y += 16
        # золото и материал: значки рисуем (в шрифте нет пиктограмм)
        g_txt, m_txt = '+%d' % ex['gold_amount'], ex['material']
        gw = d.textlength(g_txt, font=F(8))
        mw = d.textlength(m_txt, font=F(8))
        total = 14 + gw + 18 + 14 + mw
        rx = x0 + cw / 2 - total / 2
        ry = y + 6
        d.ellipse([rx, ry - 5, rx + 10, ry + 5], fill=(255, 204, 84, 255), outline=(120, 70, 20, 255))
        text(card, (rx + 14, ry), g_txt, 8, GOLD, anchor='lm', stroke=1)
        rx += 14 + gw + 18
        d.polygon([(rx, ry + 4), (rx + 3, ry - 3), (rx + 11, ry - 3), (rx + 14, ry + 4)], fill=(170, 160, 150, 255), outline=(40, 30, 26, 255))
        text(card, (rx + 18, ry), m_txt, 8, BONE, anchor='lm', stroke=1)
        if ex['remaining'] > 0:
            text(card, (x0 + cw / 2, y0 + 326), 'В сумке ещё: %d' % ex['remaining'], 8, MEM, stroke=1)
        btns = [('НАДЕТЬ', (230, 170, 60), (52, 36, 24)), ('В СУМКУ', (130, 90, 56), BONE)]
        if ex['remaining'] > 0:
            btns.append(('ОТКРЫТЬ ЕЩЁ', (70, 180, 220), WHITE))
        gap = 7
        bw = (cw - 28 - gap * (len(btns) - 1)) / len(btns)
        for i, (label, fill, tc) in enumerate(btns):
            bx = x0 + 14 + i * (bw + gap)
            by = y0 + ch - 45
            d.rectangle([bx, by, bx + bw, by + 30], fill=fill + (255,), outline=(26, 16, 10, 255), width=2)
            d.rectangle([bx + 2, by + 2, bx + bw - 2, by + 6], fill=lerpc(fill, WHITE, 0.3) + (255,))
            text(card, (bx + bw / 2, by + 15), label, 9, tc, stroke=1 if tc != (52, 36, 24) else 0)
        w2, h2 = int(card.width * scale), int(card.height * scale)
        card = card.resize((w2, h2), Image.NEAREST)
        if alpha < 1:
            a = np.array(card)
            a[..., 3] = (a[..., 3] * alpha).astype('uint8')
            card = Image.fromarray(a)
        cx, cy = 400, 50 + 190 + (1 - e) * 20
        layer.alpha_composite(card, (int(cx - w2 / 2), int(cy - h2 / 2)))


def C_glow(im):
    arr = np.array(im).astype(float) / 255
    bright = (arr[..., :3].max(axis=2) > 0.8) & (arr[..., 3] > 0)
    g = np.zeros_like(arr)
    g[bright] = arr[bright]
    return Image.fromarray((g * 255).astype('uint8'), 'RGBA').filter(ImageFilter.GaussianBlur(4))


def render(name):
    ex = EXAMPLES[name]
    scene = Scene(ex)
    total = scene.t['end']
    frames_dir = os.path.join('/tmp', 'reveal_' + name)
    os.makedirs(frames_dir, exist_ok=True)
    n = int(total * FPS)
    for i in range(n):
        t = i / FPS
        scene.frame(t).save(os.path.join(frames_dir, 'f%04d.png' % i))
    os.makedirs(OUT, exist_ok=True)
    mp4 = os.path.join(OUT, 'reveal_%s.mp4' % name)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(FPS), '-i', os.path.join(frames_dir, 'f%04d.png'),
                    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', '-preset', 'medium', mp4], check=True)
    # кадры-превью для документации
    for key in ('hit', 'pulse', 'card'):
        tt = {'hit': scene.t['hit'] + 0.03, 'pulse': scene.t['pulses'][-1][0] + 0.12, 'card': scene.t['end'] - 0.2}[key]
        scene.frame(tt).save(os.path.join(OUT, 'reveal_%s_%s.png' % (name, key)))
    return mp4, total


if __name__ == '__main__':
    names = sys.argv[1:] or list(EXAMPLES)
    for nm in names:
        path, total = render(nm)
        print('%s: %.1f с → %s' % (nm, total, path))
