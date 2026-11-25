"""Сундуки этажей v3: процедурные дизайны (10 штук) и софт-растеризатор.

Каждый дизайн — набор блоков (как Part в Roblox): центр, размер, цвет,
материал, поворот (градусы, порядок CFrame.Angles = Rx*Ry*Rz) и слой:
  base — короб, lid — крышка (откидывается вокруг заднего верхнего ребра).
Система координат как в Roblox: Y вверх, лицо сундука смотрит в +Z,
начало — центр дна. Тот же список уходит в Config/ChestDesigns.lua.
"""
import math
import numpy as np

# ---------- цвета ----------

def hx(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) / 255 for i in (0, 2, 4))


def to_hex(c):
    return '#%02X%02X%02X' % tuple(max(0, min(255, round(v * 255))) for v in c)


def mix(a, b, t):
    a, b = hx(a), hx(b)
    return to_hex(tuple(a[i] + (b[i] - a[i]) * t for i in range(3)))


MEM = '#6FE3FF'  # «чистая память» — свечение всех золотых сундуков

MATERIALS = {
    'W': 'Wood', 'P': 'WoodPlanks', 'M': 'Metal', 'N': 'Neon', 'F': 'Fabric',
    'L': 'Leather', 'G': 'Grass', 'S': 'Slate', 'C': 'CorrodedMetal',
    'D': 'DiamondPlate', 'T': 'SmoothPlastic', 'A': 'Marble', 'R': 'Granite',
}


class Design:
    def __init__(self, did, title, W, D, H, glow, lid_max=105, hinge=None, lock=None):
        self.id = did
        self.title = title
        self.W, self.D, self.H = W, D, H
        self.glow = glow
        self.lid_max = lid_max
        self.hinge = hinge or (H, -D / 2)  # (y, z)
        self.lock = lock or (0, H - 0.42, D / 2 + 0.22)
        self.parts = []

    def box(self, layer, c, s, col, m='W', r=(0, 0, 0)):
        if min(s) <= 0:
            return
        self.parts.append({'layer': layer, 'c': tuple(float(v) for v in c), 's': tuple(float(v) for v in s),
                           'col': col.upper(), 'm': m, 'r': tuple(float(v) for v in r)})

    def b(self, *a, **k):
        self.box('base', *a, **k)

    def l(self, *a, **k):
        self.box('lid', *a, **k)


# ---------- общие куски ----------

def plank_body(d, y0, y1, woods, core, rows=3, m='W', inset=0.0, z_off=0.0):
    """Короб из досок: сердцевина + ряды досок по периметру."""
    W, D = d.W - inset, d.D - inset
    d.b((0, (y0 + y1) / 2, z_off), (W - 0.2, y1 - y0, D - 0.2), core, m)
    h = (y1 - y0) / rows
    for r in range(rows):
        y = y0 + h * (r + 0.5)
        ca, cb = woods[r % len(woods)], woods[(r + 1) % len(woods)]
        for sz in (-1, 1):
            d.b((0, y, z_off + sz * (D / 2 - 0.08)), (W, h - 0.04, 0.17), ca, m)
        for sx in (-1, 1):
            d.b((sx * (W / 2 - 0.08), y, z_off), (0.17, h - 0.04, D - 0.04), cb, m)


def corner_irons(d, y0, y1, col, cap=None, size=0.3, capsize=0.38, m='M'):
    for sx in (-1, 1):
        for sz in (-1, 1):
            d.b((sx * d.W / 2, (y0 + y1) / 2, sz * d.D / 2), (size, y1 - y0, size), col, m)
            if cap:
                d.b((sx * d.W / 2, y1 - capsize * 0.35, sz * d.D / 2), (capsize, capsize * 0.7, capsize), cap, m)


def bands(d, ys, col, thick=0.2, m='M'):
    for y in ys:
        for sz in (-1, 1):
            d.b((0, y, sz * (d.D / 2 + 0.06)), (d.W + 0.06, thick, 0.08), col, m)
        for sx in (-1, 1):
            d.b((sx * (d.W / 2 + 0.06), y, 0), (0.08, thick, d.D + 0.06), col, m)


def front_straps(d, xs, y0, y1, col, rivet=None, n=3, m='M', w=0.32):
    z = d.D / 2 + 0.09
    for x in xs:
        d.b((x, (y0 + y1) / 2, z), (w, y1 - y0, 0.08), col, m)
        if rivet:
            for k in range(n):
                y = y0 + (y1 - y0) * (k + 0.5) / n
                d.b((x, y, z + 0.06), (0.13, 0.13, 0.06), rivet, m)


def stepped_lid(d, steps, cols, m='W', y0=None, z_off=0.0, width=None):
    """Свод крышки ступенями: steps = [(высота, доля глубины), ...]. Возвращает верх."""
    y = d.H if y0 is None else y0
    W = width or d.W
    for i, (h, frac) in enumerate(steps):
        dd = d.D * frac
        z = z_off + (d.D - dd) / 2 * 0 if frac == 1 else z_off
        d.l((0, y + h / 2, z), (W - 0.04, h, dd), cols[i % len(cols)], m)
        y += h
    return y


def lid_straps(d, xs, steps, col, m='M', w=0.32, y0=None):
    for x in xs:
        y = d.H if y0 is None else y0
        for h, frac in steps:
            d.l((x, y + h / 2, 0), (w, h + 0.04, d.D * frac + 0.06), col, m)
            y += h


def lid_ends(d, steps, col, m='M', y0=None):
    y = d.H if y0 is None else y0
    for h, frac in steps:
        for sx in (-1, 1):
            d.l((sx * (d.W / 2 + 0.02), y + h / 2, 0), (0.12, h + 0.02, d.D * frac + 0.04), col, m)
        y += h


def lock_plate(d, y, col, hole='#140E0C', size=(0.78, 0.78), glow=None, hasp=None):
    z = d.D / 2 + 0.14
    d.b((0, y, z), (size[0], size[1], 0.18), col, 'M')
    d.b((0, y - 0.05, z + 0.1), (0.14, 0.3, 0.05), glow or hole, 'N' if glow else 'T')
    if hasp:
        d.l((0, d.H - 0.04, z + 0.02), (0.34, 0.5, 0.09), hasp, 'M')
    d.lock = (0, y, z + 0.12)


def feet(d, col, kind='runner', m='M'):
    if kind == 'runner':
        for sx in (-1, 1):
            d.b((sx * (d.W / 2 - 0.35), 0.09, 0), (0.5, 0.18, d.D + 0.1), col, m)
    else:
        for sx in (-1, 1):
            for sz in (-1, 1):
                d.b((sx * (d.W / 2 - 0.25), 0.13, sz * (d.D / 2 - 0.25)), (0.55, 0.26, 0.55), col, m)


# ---------- 10 дизайнов ----------

def f1_common():
    d = Design('f1_common', 'Сундук стражи', 3.8, 2.5, 1.8, '#C98B4A')
    oak = ['#7A5C48', '#6A4E3C', '#82634D']
    iron, iron2, ironL = '#4B4442', '#3A3432', '#7A6E66'
    feet(d, iron2)
    plank_body(d, 0.15, d.H, oak, '#3A2E2A', rows=3)
    corner_irons(d, 0.12, d.H, iron, cap=ironL)
    bands(d, [0.28, d.H - 0.06], iron)
    front_straps(d, [-d.W * 0.28, d.W * 0.28], 0.15, d.H, iron, rivet=ironL)
    for sx in (-1, 1):  # ручки
        d.b((sx * (d.W / 2 + 0.14), d.H * 0.6, 0), (0.08, 0.5, 0.8), iron, 'M')
        d.b((sx * (d.W / 2 + 0.3), d.H * 0.6 - 0.25, 0), (0.12, 0.12, 0.9), ironL, 'M')
    steps = [(0.4, 1.0), (0.3, 0.78), (0.25, 0.45)]
    stepped_lid(d, steps, ['#7A5C48', '#86684F', '#6E523F'])
    lid_ends(d, steps, iron)
    lid_straps(d, [-d.W * 0.28, d.W * 0.28], steps, iron)
    d.l((0, d.H + 0.08, d.D / 2 + 0.05), (d.W + 0.1, 0.16, 0.12), ironL, 'M')
    # щит стражи с ключом на втором ярусе
    zf = d.D * 0.39 + 0.03
    d.l((0, d.H + 0.55, zf), (0.62, 0.36, 0.07), '#D9D2C5', 'M')
    d.l((0, d.H + 0.44, zf), (0.4, 0.14, 0.07), '#D9D2C5', 'M')
    d.l((0, d.H + 0.55, zf + 0.04), (0.1, 0.42, 0.04), '#C98B4A', 'M')
    d.l((0, d.H + 0.6, zf + 0.04), (0.36, 0.08, 0.04), '#C98B4A', 'M')
    lock_plate(d, d.H - 0.45, ironL, hasp=ironL)
    return d


def f1_gold():
    d = Design('f1_gold', 'Золотой сундук Привратника', 4.4, 2.9, 2.0, '#F5D27A', lid_max=108)
    wood = ['#4A2F26', '#56382C', '#3F2820']
    gold, goldL, goldD = '#D9A441', '#F5D27A', '#9C7130'
    iron = '#2A2224'
    feet(d, goldD, kind='paw')
    plank_body(d, 0.22, d.H, wood, '#24181A', rows=3)
    corner_irons(d, 0.2, d.H, gold, cap=goldL, size=0.36, capsize=0.46)
    bands(d, [0.32, d.H - 0.07], gold, thick=0.22)
    # решётка ворот спереди
    z = d.D / 2 + 0.1
    d.b((0, 1.1, z), (1.9, 1.3, 0.08), iron, 'M')
    for i in range(5):
        x = -0.76 + i * 0.38
        d.b((x, 1.1, z + 0.06), (0.1, 1.3, 0.07), gold, 'M')
        d.b((x, 0.4, z + 0.06), (0.14, 0.16, 0.08), goldL, 'M')  # пики решётки
    for y in (0.72, 1.48):
        d.b((0, y, z + 0.09), (1.9, 0.1, 0.06), gold, 'M')
    d.b((0, 1.78, z + 0.03), (2.1, 0.14, 0.1), goldL, 'M')
    for sx in (-1, 1):
        d.b((sx * 1.55, d.H * 0.55, z), (0.34, d.H - 0.4, 0.08), gold, 'M')
        for k in range(3):
            d.b((sx * 1.55, 0.55 + k * 0.48, z + 0.06), (0.14, 0.14, 0.06), goldL, 'M')
    lock_plate(d, 1.12, goldL, size=(0.7, 0.8), glow=MEM)
    steps = [(0.36, 1.0), (0.3, 0.86), (0.26, 0.64), (0.2, 0.4)]
    top = stepped_lid(d, steps, ['#4A2F26', '#56382C', '#4F3328', '#5C3D2F'])
    lid_ends(d, steps, gold)
    lid_straps(d, [-1.55, 1.55], steps, gold, w=0.34)
    d.l((0, d.H + 0.08, d.D / 2 + 0.05), (d.W + 0.12, 0.16, 0.12), goldL, 'M')
    d.l((0, d.H + 0.05, d.D / 2 + 0.14), (0.44, 0.5, 0.09), goldL, 'M')  # петля замка
    d.l((0, top + 0.05, 0), (d.W * 0.7, 0.1, 0.16), goldL, 'M')  # гребень
    # скрещённые ключи на своде
    for sgn in (-1, 1):
        d.l((0, top + 0.16, 0), (2.0, 0.12, 0.16), gold, 'M', r=(0, sgn * 28, 0))
        a = math.radians(sgn * 28)
        bx, bz = math.cos(a) * 1.0, -math.sin(a) * 1.0
        d.l((bx, top + 0.18, bz), (0.42, 0.14, 0.42), goldL, 'M', r=(0, sgn * 28, 0))
        d.l((bx, top + 0.24, bz), (0.18, 0.06, 0.18), MEM, 'N', r=(0, sgn * 28, 0))
        tx, tz = -math.cos(a) * 0.9, math.sin(a) * 0.9
        d.l((tx, top + 0.16, tz + 0.12 * sgn * 0), (0.14, 0.12, 0.34), gold, 'M', r=(0, sgn * 28, 0))
    for sx in (-1, 1):  # шипы на углах крышки
        for sz in (-1, 1):
            d.l((sx * (d.W / 2 - 0.1), d.H + 0.42, sz * (d.D / 2 - 0.1)), (0.34, 0.12, 0.34), goldL, 'M')
    return d


def f2_common():
    d = Design('f2_common', 'Замшелый сундук', 3.8, 2.5, 1.75, '#9CC48A')
    wood = ['#5B5A44', '#6E6B50', '#53523E']
    verd, verdL = '#4F8F7D', '#7CC0A8'
    moss, moss2, mossL = '#3F7A5C', '#4E8C5E', '#9CC48A'
    feet(d, '#3A3A2C', m='W')
    plank_body(d, 0.15, d.H, wood, '#2E2D22', rows=3)
    corner_irons(d, 0.12, d.H, verd, cap=verdL, m='C')
    bands(d, [0.28], verd, m='C')
    front_straps(d, [-1.05, 1.05], 0.15, d.H, verd, rivet=verdL, m='C')
    steps = [(0.36, 1.0), (0.3, 0.8), (0.22, 0.5)]
    top = stepped_lid(d, steps, ['#5E5C45', '#6E6B50', '#625F48'])
    lid_ends(d, steps, verd, m='C')
    lid_straps(d, [-1.05, 1.05], steps, verd, m='C')
    # мох на крышке
    rng = np.random.default_rng(21)
    for i in range(9):
        x = rng.uniform(-1.6, 1.6)
        z = rng.uniform(-0.5, 0.5)
        sx, sz = rng.uniform(0.5, 1.1), rng.uniform(0.4, 0.8)
        d.l((x, top + 0.04, z), (sx, 0.1 + rng.uniform(0, 0.08), sz), [moss, moss2, mossL][i % 3], 'G', r=(0, rng.uniform(-30, 30), 0))
    for x in (-1.5, -0.4, 0.7, 1.4):  # мох свисает с края свода
        d.l((x, d.H + 0.22, d.D / 2 + 0.04), (0.6, 0.34, 0.1), moss2, 'G')
    for sx in (-1, 1):  # мох у дна
        d.b((sx * 1.6, 0.2, d.D / 2 + 0.05), (0.8, 0.26, 0.2), moss, 'G')
    # лоза по фасаду и листья
    z = d.D / 2 + 0.13
    for (x, y, rz) in [(-0.55, 0.75, 38), (0.55, 0.75, -38), (-1.45, 1.2, -50), (1.5, 0.55, 55)]:
        d.b((x, y, z), (1.1, 0.08, 0.06), '#2E5A38', 'G', r=(0, 0, rz))
    for (x, y) in [(-0.9, 0.42), (-0.2, 1.05), (0.3, 1.05), (0.95, 0.42), (-1.3, 1.45), (1.35, 0.85)]:
        d.b((x, y, z + 0.03), (0.2, 0.12, 0.05), mossL, 'G', r=(0, 0, 30))
    for (x, y, c) in [(-0.95, 0.5, '#F0A0B0'), (0.92, 0.5, '#E8D8F0'), (-1.35, 1.52, '#F0A0B0')]:
        d.b((x, y, z + 0.06), (0.12, 0.12, 0.05), c, 'T')
    # грибы сбоку
    for (zz, h) in [(0.4, 0.3), (0.0, 0.2)]:
        d.b((d.W / 2 + 0.12, 0.2 + h / 2, zz), (0.08, h, 0.08), '#D9D2C5', 'T')
        d.b((d.W / 2 + 0.12, 0.22 + h, zz), (0.26, 0.08, 0.26), '#B85C3C', 'T')
    lock_plate(d, d.H - 0.45, verdL, hasp=verdL)
    return d


def f2_gold():
    d = Design('f2_gold', 'Золотой сундук Садовницы', 4.3, 2.8, 1.95, '#5FD0C0', lid_max=108)
    paint = ['#2D5B50', '#356A5D', '#2A5247']
    gold, goldL, goldD = '#D9A441', '#F5D27A', '#9C7130'
    leaf, leafL = '#3F7A5C', '#9CC48A'
    feet(d, goldD, kind='paw')
    plank_body(d, 0.22, d.H, paint, '#1F3A33', rows=3)
    corner_irons(d, 0.2, d.H, gold, cap=goldL, size=0.34, capsize=0.44)
    bands(d, [0.32, d.H - 0.07], gold)
    # решётка-шпалера на фасаде
    z = d.D / 2 + 0.1
    d.b((0, 1.05, z - 0.01), (2.6, 1.3, 0.05), '#1F3A33', 'T')
    for i in range(-3, 4):
        for sgn in (-1, 1):
            d.b((i * 0.38, 1.05, z + 0.03 + (0.01 if sgn > 0 else 0)), (0.07, 1.25, 0.04), gold, 'M', r=(0, 0, sgn * 40))
    for y in (0.4, 1.7):
        d.b((0, y, z + 0.06), (2.7, 0.1, 0.06), goldL, 'M')
    for sx in (-1, 1):
        d.b((sx * 1.35, 1.05, z + 0.06), (0.1, 1.4, 0.06), goldL, 'M')
    lock_plate(d, 1.1, goldL, size=(0.66, 0.74), glow=MEM)
    d.b((0, 1.5, z + 0.16), (0.16, 0.16, 0.06), '#5FD0C0', 'N')  # капля
    steps = [(0.34, 1.0), (0.28, 0.84), (0.24, 0.62), (0.18, 0.38)]
    top = stepped_lid(d, steps, ['#2D5B50', '#356A5D', '#30604F', '#3A7062'])
    lid_ends(d, steps, gold)
    d.l((0, d.H + 0.08, d.D / 2 + 0.05), (d.W + 0.12, 0.16, 0.12), goldL, 'M')
    d.l((0, d.H + 0.05, d.D / 2 + 0.14), (0.4, 0.46, 0.09), goldL, 'M')
    # золотые розы: центр свода и углы
    def rose(layer, x, y, z, s=1.0):
        box = d.l if layer == 'lid' else d.b
        for k, rot in enumerate((0, 45)):
            box((x, y + 0.05 * k, z), (0.36 * s, 0.14 * s, 0.36 * s), gold if k == 0 else goldL, 'M', r=(0, rot, 0))
        box((x, y + 0.14 * s, z), (0.16 * s, 0.1 * s, 0.16 * s), '#FFE7A8', 'M')
        for a in (20, 140, 260):
            ra = math.radians(a)
            box((x + math.cos(ra) * 0.3 * s, y - 0.02, z + math.sin(ra) * 0.3 * s), (0.3 * s, 0.05, 0.12 * s), leaf, 'G', r=(0, -a, 0))
    rose('lid', 0, top + 0.06, 0, 1.4)
    for sx in (-1, 1):
        rose('lid', sx * 1.45, d.H + 0.66, 1.02, 1.0)
    # лоза золотом по своду
    for sx in (-1, 1):
        d.l((sx * 0.8, top - 0.02, 0.1), (1.1, 0.07, 0.07), '#7FA85A', 'G', r=(0, sx * 20, 0))
        for k in range(3):
            d.l((sx * (0.45 + k * 0.32), top + 0.02, 0.18 - k * 0.08), (0.18, 0.05, 0.1), leafL, 'G', r=(0, sx * 35, 0))
    return d


def f3_common():
    d = Design('f3_common', 'Охотничий сундук', 3.8, 2.4, 1.7, '#D9A441')
    leather, leatherD, leatherL = '#8C3B2E', '#6E2E24', '#A04A38'
    strap, brass, brassL = '#3B1E1E', '#D9A441', '#F0C870'
    fur, furD = '#E8DCC0', '#8A6A4A'
    feet(d, '#2A1614', m='W')
    d.b((0, 0.15 + (d.H - 0.15) / 2, 0), (d.W, d.H - 0.15, d.D), leather, 'L')
    for y in (0.22, d.H - 0.05):  # прошитые канты
        for sz in (-1, 1):
            d.b((0, y, sz * (d.D / 2 + 0.02)), (d.W + 0.02, 0.08, 0.05), leatherL, 'F')
    for sx in (-1, 1):
        for sz in (-1, 1):
            d.b((sx * d.W / 2, d.H / 2 + 0.08, sz * d.D / 2), (0.22, d.H - 0.12, 0.22), leatherD, 'L')
    steps = [(0.36, 1.0), (0.28, 0.8), (0.2, 0.52)]
    top = stepped_lid(d, steps, [leather, leatherL, leather], m='L')
    # ремни через крышку и фасад с пряжками
    for x in (-1.2, 0.0, 1.2):
        if x == 0.0:
            continue
        d.b((x, d.H / 2 + 0.08, d.D / 2 + 0.05), (0.3, d.H - 0.12, 0.06), strap, 'L')
        y = d.H
        for h, frac in steps:
            d.l((x, y + h / 2, 0), (0.3, h + 0.03, d.D * frac + 0.08), strap, 'L')
            y += h
        d.b((x, d.H - 0.3, d.D / 2 + 0.1), (0.42, 0.3, 0.06), brass, 'M')
        d.b((x, d.H - 0.3, d.D / 2 + 0.14), (0.22, 0.14, 0.04), strap, 'L')
    # мех по гребню
    rng = np.random.default_rng(7)
    for i in range(12):
        x = -1.65 + i * 0.3
        d.l((x, top + 0.05, rng.uniform(-0.15, 0.15)), (0.36, 0.18 + rng.uniform(0, 0.1), 0.5), fur if i % 3 else furD, 'F',
            r=(0, rng.uniform(-20, 20), rng.uniform(-10, 10)))
    # отпечаток лапы
    z = d.D / 2 + 0.06
    d.b((0, 0.75, z), (0.42, 0.34, 0.05), brass, 'M')
    for (x, y) in [(-0.24, 1.05), (-0.08, 1.14), (0.08, 1.14), (0.24, 1.05)]:
        d.b((x, y, z), (0.13, 0.15, 0.05), brass, 'M')
    lock_plate(d, d.H - 0.42, brassL, size=(0.6, 0.6), hasp=brass)
    return d


def f3_gold():
    d = Design('f3_gold', 'Золотой сундук Ловчего', 4.3, 2.7, 1.9, '#FFD27A', lid_max=108)
    leather, leatherL = '#5E1F1C', '#7A2A24'
    gold, goldL, goldD = '#D9A441', '#F5D27A', '#9C7130'
    fur, furD = '#F2EAD8', '#C9B48E'
    bone = '#E8DCC0'
    feet(d, goldD, kind='paw')
    d.b((0, 0.22 + (d.H - 0.22) / 2, 0), (d.W, d.H - 0.22, d.D), leather, 'L')
    corner_irons(d, 0.2, d.H, gold, cap=goldL, size=0.34, capsize=0.44)
    bands(d, [0.32, d.H - 0.07], gold)
    for x in (-1.0, -0.5, 0.5, 1.0):  # золотые гвозди
        for y in (0.6, 1.0, 1.4):
            if abs(x) < 0.6 and y > 0.7:
                continue
            d.b((x * 1.45, y, d.D / 2 + 0.04), (0.11, 0.11, 0.06), goldL, 'M')
    # золотая гончая (голова в профиль) на фасаде
    z = d.D / 2 + 0.08
    d.b((0, 1.12, z - 0.02), (1.2, 1.0, 0.06), '#3B1E1E', 'L')
    d.b((-0.1, 1.15, z + 0.04), (0.5, 0.42, 0.08), gold, 'M')  # голова
    d.b((0.28, 1.06, z + 0.04), (0.42, 0.22, 0.08), gold, 'M')  # морда
    d.b((0.47, 1.1, z + 0.08), (0.08, 0.08, 0.05), '#2A1614', 'T')  # нос
    d.b((-0.28, 1.4, z + 0.04), (0.18, 0.3, 0.08), goldD, 'M', r=(0, 0, -25))  # ухо
    d.b((-0.32, 0.86, z + 0.04), (0.36, 0.3, 0.08), gold, 'M', r=(0, 0, 15))  # шея
    d.b((0.02, 1.22, z + 0.09), (0.08, 0.08, 0.04), MEM, 'N')  # глаз
    d.b((0.0, 0.62, z + 0.04), (1.0, 0.14, 0.08), goldL, 'M')  # ошейник-полка
    d.lock = (0.0, 1.15, z + 0.12)
    steps = [(0.34, 1.0), (0.28, 0.82), (0.22, 0.58)]
    top = stepped_lid(d, steps, [leather, leatherL, leather], m='L')
    lid_ends(d, steps, gold)
    d.l((0, d.H + 0.07, d.D / 2 + 0.05), (d.W + 0.12, 0.14, 0.12), goldL, 'M')
    # меховой валик по краю крышки
    for i in range(14):
        x = -2.0 + i * 0.31
        d.l((x, d.H + 0.2, d.D / 2 + 0.12), (0.34, 0.3, 0.24), fur if i % 2 else furD, 'F', r=(0, 0, (i % 3 - 1) * 12))
    # рога на своде
    for sx in (-1, 1):
        bx = sx * 0.75
        d.l((bx, top + 0.18, -0.1), (0.16, 0.42, 0.16), bone, 'A', r=(0, 0, sx * -20))
        d.l((bx + sx * 0.28, top + 0.52, -0.1), (0.14, 0.5, 0.14), bone, 'A', r=(0, 0, sx * -42))
        d.l((bx + sx * 0.62, top + 0.84, -0.1), (0.12, 0.42, 0.12), bone, 'A', r=(0, 0, sx * -15))
        d.l((bx + sx * 0.12, top + 0.62, -0.1), (0.1, 0.36, 0.1), bone, 'A', r=(0, 0, sx * 18))
        d.l((bx + sx * 0.46, top + 0.98, -0.1), (0.09, 0.3, 0.09), bone, 'A', r=(0, 0, sx * 8))
        d.l((bx, top + 0.02, -0.1), (0.3, 0.1, 0.3), gold, 'M')
    d.l((0, top + 0.08, -0.1), (0.36, 0.16, 0.36), goldL, 'M')
    d.l((0, top + 0.18, -0.1), (0.14, 0.08, 0.14), MEM, 'N')
    return d


def f4_common():
    d = Design('f4_common', 'Литейный сундук', 3.8, 2.5, 1.7, '#E2672B')
    iron, ironD, ironL = '#4A4350', '#2E2A31', '#6B6370'
    melt = '#E2672B'
    d.b((0, 0.12, 0), (d.W + 0.2, 0.24, d.D + 0.2), ironD, 'M')  # плинт
    d.b((0, 0.24 + (d.H - 0.24) / 2, 0), (d.W, d.H - 0.24, d.D), iron, 'M')
    # плиты с тлеющими швами
    z = d.D / 2
    for y in (0.72, 1.22):
        d.b((0, y, z + 0.01), (d.W - 0.3, 0.06, 0.04), melt, 'N')
        d.b((d.W / 2 + 0.01, y, 0), (0.04, 0.06, d.D - 0.3), melt, 'N')
    for (y0, y1) in [(0.26, 0.7), (0.74, 1.2), (1.24, d.H - 0.02)]:
        for sx in (-1, 1):
            d.b((sx * (d.W / 2 - 0.35), (y0 + y1) / 2, z + 0.06), (0.5, y1 - y0 - 0.04, 0.08), ironL, 'M')
            d.b((sx * (d.W / 2 - 0.35), (y0 + y1) / 2, z + 0.12), (0.14, 0.14, 0.05), '#8A8290', 'M')
    corner_irons(d, 0.24, d.H, ironD, cap=ironL, size=0.32, capsize=0.4)
    # решётка-отдушина
    d.b((0, 0.5, z + 0.06), (1.2, 0.36, 0.06), ironD, 'M')
    for i in range(4):
        d.b((-0.42 + i * 0.28, 0.5, z + 0.08), (0.12, 0.24, 0.04), melt, 'N')
    lock_plate(d, d.H - 0.5, ironL, size=(0.7, 0.62), glow=melt, hasp=ironL)
    # крышка: плоская плита с рёбрами и ручкой
    d.l((0, d.H + 0.18, 0), (d.W + 0.06, 0.36, d.D + 0.06), iron, 'M')
    d.l((0, d.H + 0.03, d.D / 2 + 0.04), (d.W - 0.3, 0.05, 0.04), melt, 'N')
    for x in (-1.1, 1.1):
        d.l((x, d.H + 0.44, 0), (0.36, 0.16, d.D), ironL, 'M')
        for zz in (-0.8, 0, 0.8):
            d.l((x, d.H + 0.54, zz), (0.13, 0.06, 0.13), '#8A8290', 'M')
    for x in (-0.45, 0.45):
        d.l((x, d.H + 0.55, 0), (0.12, 0.38, 0.12), ironD, 'M')
    d.l((0, d.H + 0.76, 0), (1.06, 0.12, 0.14), ironD, 'M')
    d.l((0, d.H + 0.38, 0.5), (0.6, 0.06, 0.3), melt, 'N')  # тлеющий слиток-клеймо
    return d


def f4_gold():
    d = Design('f4_gold', 'Золотой сундук Литейщика', 4.3, 2.8, 1.9, '#FFC857', lid_max=105)
    iron, ironD = '#2F2B33', '#24212A'
    gold, goldL = '#C9962E', '#FFC857'
    melt = '#FF9A3C'
    d.b((0, 0.14, 0), (d.W + 0.26, 0.28, d.D + 0.26), ironD, 'M')
    d.b((0, 0.28 + (d.H - 0.28) / 2, 0), (d.W, d.H - 0.28, d.D), iron, 'M')
    corner_irons(d, 0.28, d.H, gold, cap=goldL, size=0.34, capsize=0.44)
    bands(d, [0.34, d.H - 0.07], gold)
    z = d.D / 2
    for y in (0.78, 1.3):  # швы золотого жара
        d.b((0, y, z + 0.01), (d.W - 0.4, 0.07, 0.04), melt, 'N')
        d.b((d.W / 2 + 0.01, y, 0), (0.04, 0.07, d.D - 0.4), melt, 'N')
    # скрещённые молоты на фасаде
    for sgn in (-1, 1):
        d.b((0, 1.0, z + 0.06), (0.14, 1.6, 0.07), '#7A5A2E', 'W', r=(0, 0, sgn * 40))
        ax = math.radians(sgn * 40)
        hx_, hy_ = -math.sin(ax) * 0.8, math.cos(ax) * 0.8
        d.b((hx_, 1.0 + hy_, z + 0.1), (0.54, 0.3, 0.14), goldL, 'M', r=(0, 0, sgn * 40))
        d.b((hx_, 1.0 + hy_, z + 0.18), (0.36, 0.07, 0.04), gold, 'M', r=(0, 0, sgn * 40))
    lock_plate(d, 0.82, goldL, size=(0.56, 0.56), glow=MEM)
    # крышка: плита в золотой раме + наковальня
    d.l((0, d.H + 0.2, 0), (d.W + 0.08, 0.4, d.D + 0.08), iron, 'M')
    d.l((0, d.H + 0.03, d.D / 2 + 0.05), (d.W - 0.3, 0.05, 0.04), melt, 'N')
    for sz in (-1, 1):
        d.l((0, d.H + 0.42, sz * (d.D / 2 - 0.05)), (d.W + 0.1, 0.06, 0.16), gold, 'M')
    for sx in (-1, 1):
        d.l((sx * (d.W / 2 - 0.05), d.H + 0.42, 0), (0.16, 0.06, d.D + 0.1), gold, 'M')
    d.l((0, d.H + 0.22, d.D / 2 + 0.06), (d.W + 0.1, 0.12, 0.06), goldL, 'M')
    y = d.H + 0.4
    d.l((0, y + 0.14, 0), (1.7, 0.28, 1.05), ironD, 'M')  # основание
    d.l((0, y + 0.45, 0), (0.95, 0.36, 0.62), iron, 'M')  # талия
    d.l((0.15, y + 0.8, 0), (2.1, 0.36, 0.82), '#3B3640', 'M')  # лицо наковальни
    d.l((0.15, y + 0.99, 0), (2.0, 0.04, 0.72), goldL, 'M')
    d.l((-1.25, y + 0.78, 0), (0.7, 0.26, 0.54), '#3B3640', 'M')  # рог
    d.l((-1.7, y + 0.76, 0), (0.42, 0.16, 0.32), '#3B3640', 'M')
    d.l((0.55, y + 1.04, 0.0), (0.6, 0.08, 0.34), melt, 'N')  # раскалённая заготовка
    d.l((0.55, y + 1.09, 0.0), (0.36, 0.04, 0.2), '#FFE2A0', 'N')
    return d


def f5_common():
    d = Design('f5_common', 'Сундук-фолиант', 3.9, 2.8, 1.25, '#B8E3FF', lid_max=110)
    cover, coverD = '#3A3170', '#2A2358'
    page, pageD = '#E6DCC0', '#C9BC98'
    metal, metalL = '#8E7CE0', '#B4A8F0'
    d.b((0, 0.1, 0), (d.W, 0.2, d.D), cover, 'L')  # нижняя обложка
    d.b((0.06, 0.2 + (d.H - 0.2) / 2, 0.06), (d.W - 0.3, d.H - 0.2, d.D - 0.3), page, 'T')  # блок страниц
    for k in range(5):  # обрез страниц
        y = 0.32 + k * 0.19
        d.b((0.06, y, (d.D - 0.3) / 2 + 0.065), (d.W - 0.34, 0.03, 0.02), pageD, 'T')
        d.b(((d.W - 0.3) / 2 + 0.065, y, 0.06), (0.02, 0.03, d.D - 0.34), pageD, 'T')
    d.b((0, d.H / 2 + 0.05, -d.D / 2 + 0.12), (d.W + 0.02, d.H + 0.18, 0.3), coverD, 'L')  # корешок
    for x in (-1.2, 0, 1.2):
        d.b((x, d.H / 2 + 0.05, -d.D / 2 - 0.02), (0.22, d.H + 0.2, 0.06), metal, 'M')
    d.hinge = (d.H, -d.D / 2 + 0.12)
    # верхняя обложка (крышка)
    d.l((0, d.H + 0.11, 0), (d.W, 0.22, d.D), cover, 'L')
    for sx in (-1, 1):  # уголки
        for sz in (-1, 1):
            d.l((sx * (d.W / 2 - 0.22), d.H + 0.24, sz * (d.D / 2 - 0.22)), (0.5, 0.06, 0.5), metal, 'M')
            d.b((sx * (d.W / 2 - 0.22), 0.22, sz * (d.D / 2 - 0.22)), (0.5, 0.06, 0.5), metal, 'M')
    d.l((0, d.H + 0.25, 0), (1.6, 0.04, 1.4), coverD, 'L')
    # руна памяти
    d.l((0, d.H + 0.28, 0), (0.12, 0.04, 0.9), '#B8E3FF', 'N')
    d.l((0, d.H + 0.28, 0), (0.7, 0.04, 0.12), '#B8E3FF', 'N')
    d.l((0, d.H + 0.29, 0), (0.36, 0.04, 0.36), '#B8E3FF', 'N', r=(0, 45, 0))
    d.l((0, d.H + 0.3, 0), (0.2, 0.04, 0.2), coverD, 'L', r=(0, 45, 0))
    # застёжки
    for x in (-1.0, 1.0):
        d.l((x, d.H + 0.12, d.D / 2 + 0.03), (0.34, 0.2, 0.06), coverD, 'L')
        d.b((x, d.H - 0.25, d.D / 2 - 0.05), (0.34, 0.56, 0.06), coverD, 'L')
        d.b((x, d.H - 0.42, d.D / 2 - 0.0), (0.4, 0.2, 0.06), metalL, 'M')
    d.lock = (0, d.H + 0.05, d.D / 2 + 0.05)
    return d


def f5_gold():
    d = Design('f5_gold', 'Золотой сундук Хрониста', 4.4, 3.1, 1.45, '#B8E3FF', lid_max=110)
    cover, coverD = '#241F4A', '#1A1638'
    page, pageD = '#EFE6CC', '#CDBF96'
    gold, goldL = '#D9A441', '#F5D27A'
    d.b((0, 0.12, 0), (d.W, 0.24, d.D), cover, 'L')
    d.b((0.06, 0.24 + (d.H - 0.24) / 2, 0.06), (d.W - 0.32, d.H - 0.24, d.D - 0.32), page, 'T')
    for k in range(6):
        y = 0.36 + k * 0.19
        d.b((0.06, y, (d.D - 0.32) / 2 + 0.065), (d.W - 0.36, 0.03, 0.02), pageD, 'T')
        d.b(((d.W - 0.32) / 2 + 0.065, y, 0.06), (0.02, 0.03, d.D - 0.36), pageD, 'T')
    d.b((0, d.H / 2 + 0.06, -d.D / 2 + 0.13), (d.W + 0.04, d.H + 0.22, 0.32), coverD, 'L')
    for x in (-1.5, -0.5, 0.5, 1.5):
        d.b((x, d.H / 2 + 0.06, -d.D / 2 - 0.02), (0.2, d.H + 0.24, 0.06), gold, 'M')
    d.hinge = (d.H, -d.D / 2 + 0.13)
    # закладки-ленты
    for (x, c) in [(-0.7, '#B03040'), (-0.45, '#3AA0A0')]:
        d.b((x, d.H - 0.4, d.D / 2 - 0.02), (0.14, 0.9, 0.04), c, 'F')
        d.b((x, d.H - 0.9, d.D / 2 - 0.02), (0.14, 0.12, 0.04), c, 'F', r=(0, 0, 45))
    # обложка с окладом
    d.l((0, d.H + 0.13, 0), (d.W, 0.26, d.D), cover, 'L')
    for sz in (-1, 1):
        d.l((0, d.H + 0.28, sz * (d.D / 2 - 0.12)), (d.W - 0.1, 0.06, 0.16), gold, 'M')
    for sx in (-1, 1):
        d.l((sx * (d.W / 2 - 0.12), d.H + 0.28, 0), (0.16, 0.06, d.D - 0.1), gold, 'M')
        for sz in (-1, 1):
            d.l((sx * (d.W / 2 - 0.3), d.H + 0.3, sz * (d.D / 2 - 0.3)), (0.62, 0.08, 0.62), goldL, 'M', r=(0, 45, 0))
            d.l((sx * (d.W / 2 - 0.3), d.H + 0.35, sz * (d.D / 2 - 0.3)), (0.14, 0.05, 0.14), '#8E7CE0', 'N')
            d.b((sx * (d.W / 2 - 0.25), 0.26, sz * (d.D / 2 - 0.25)), (0.56, 0.06, 0.56), gold, 'M')
    # недремлющее око
    d.l((0, d.H + 0.3, 0.05), (1.5, 0.06, 0.76), gold, 'M')
    d.l((0, d.H + 0.3, 0.05), (1.06, 0.07, 0.76), gold, 'M', r=(0, 0, 0))
    d.l((0, d.H + 0.33, 0.05), (1.2, 0.05, 0.5), '#F2F0E6', 'T')
    d.l((0, d.H + 0.36, 0.05), (0.42, 0.05, 0.42), MEM, 'N')
    d.l((0, d.H + 0.39, 0.05), (0.16, 0.04, 0.16), '#0E1A2A', 'T')
    for sgn in (-1, 1):  # лучи ока
        for k in range(3):
            a = math.radians(-60 + k * 60)
            d.l((math.sin(a) * 0.95 * sgn * 0 + (k - 1) * 0.42, d.H + 0.3, 0.05 + sgn * 0.6), (0.08, 0.05, 0.3), goldL, 'M', r=(0, (k - 1) * 30 * sgn, 0))
    # застёжки с камнями
    for x in (-1.2, 1.2):
        d.l((x, d.H + 0.14, d.D / 2 + 0.04), (0.4, 0.22, 0.08), gold, 'M')
        d.b((x, d.H - 0.28, d.D / 2 - 0.04), (0.4, 0.62, 0.07), gold, 'M')
        d.b((x, d.H - 0.32, d.D / 2 + 0.0), (0.18, 0.18, 0.05), '#8E7CE0', 'N')
    d.l((0, d.H + 0.14, d.D / 2 + 0.05), (0.5, 0.24, 0.08), goldL, 'M')
    d.l((0, d.H + 0.14, d.D / 2 + 0.1), (0.16, 0.12, 0.04), MEM, 'N')
    d.lock = (0, d.H + 0.12, d.D / 2 + 0.12)
    return d


BUILDERS = [f1_common, f1_gold, f2_common, f2_gold, f3_common, f3_gold, f4_common, f4_gold, f5_common, f5_gold]


def all_designs():
    return [f() for f in BUILDERS]


# ---------- геометрия ----------

def rot(rx, ry, rz):
    rx, ry, rz = (math.radians(v) for v in (rx, ry, rz))
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rx @ Ry @ Rz


CORNERS = np.array([[(1 if i & 4 else -1), (1 if i & 2 else -1), (1 if i & 1 else -1)] for i in range(8)], dtype=float) / 2
FACES = [[4, 5, 7, 6], [0, 2, 3, 1], [2, 6, 7, 3], [0, 1, 5, 4], [1, 3, 7, 5], [0, 4, 6, 2]]


def part_world(p, design, lid_angle=0.0, transform=None):
    M = rot(*p['r'])
    v = np.array(p['c']) + (CORNERS * np.array(p['s'])) @ M.T
    if p['layer'] == 'lid' and lid_angle:
        hy, hz = design.hinge
        R = rot(-lid_angle, 0, 0)
        v = (v - np.array([0, hy, hz])) @ R.T + np.array([0, hy, hz])
    if transform is not None:
        v = transform(v)
    return v


class Camera:
    def __init__(self, yaw=32, pitch=24):
        y, p = math.radians(yaw), math.radians(pitch)
        self.d = np.array([math.sin(y) * math.cos(p), math.sin(p), math.cos(y) * math.cos(p)])
        f = -self.d
        up = np.array([0.0, 1.0, 0.0])
        r = np.cross(f, up)
        self.r = r / np.linalg.norm(r)
        self.u = np.cross(self.r, f)

    def project(self, v):
        return np.stack([v @ self.r, v @ self.u, v @ self.d], axis=-1)


LIGHT = np.array([-0.35, 0.85, 0.45])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def geometry(design, cam, lid_angle=0.0, transform=None):
    """Список видимых граней: (2D-точки в «студах», глубины, цвет, неон, id)."""
    faces = []
    for pid, p in enumerate(design.parts):
        v = part_world(p, design, lid_angle, transform)
        pv = cam.project(v)
        col = np.array(hx(p['col']))
        neon = p['m'] == 'N'
        for f in FACES:
            a, b, c = v[f[0]], v[f[1]], v[f[2]]
            n = np.cross(b - a, c - a)
            ln = np.linalg.norm(n)
            if ln < 1e-9:
                continue
            n = n / ln
            # нормаль наружу: от центра блока
            center = v.mean(axis=0)
            if np.dot(n, a - center) < 0:
                n = -n
            if np.dot(n, cam.d) <= 1e-4:
                continue
            if neon:
                shade = col * 0.85 + 0.25
            else:
                lam = max(0.0, float(np.dot(n, LIGHT)))
                k = 0.5 + 0.5 * lam
                if p['m'] == 'M':
                    k = 0.42 + 0.68 * lam ** 1.4
                shade = col * k
            faces.append((pv[f], shade.clip(0, 1), neon, pid))
    return faces


def raster(faces, size, scale, offset, supersample=1):
    """Z-буфер. size=(w,h) пикселей; 1 студ = scale пикселей; offset — центр в пикселях."""
    w, h = size[0] * supersample, size[1] * supersample
    s = scale * supersample
    ox, oy = offset[0] * supersample, offset[1] * supersample
    zbuf = np.full((h, w), -1e9)
    cbuf = np.zeros((h, w, 3))
    ibuf = np.full((h, w), -1, dtype=int)
    nbuf = np.zeros((h, w), dtype=bool)
    for pts, color, neon, pid in faces:
        X = pts[:, 0] * s + ox
        Y = oy - pts[:, 1] * s
        Z = pts[:, 2]
        for tri in ((0, 1, 2), (0, 2, 3)):
            xs, ys, zs = X[list(tri)], Y[list(tri)], Z[list(tri)]
            x0, x1 = int(max(0, math.floor(xs.min()))), int(min(w - 1, math.ceil(xs.max())))
            y0, y1 = int(max(0, math.floor(ys.min()))), int(min(h - 1, math.ceil(ys.max())))
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            area = (xs[1] - xs[0]) * (ys[2] - ys[0]) - (ys[1] - ys[0]) * (xs[2] - xs[0])
            if abs(area) < 1e-9:
                continue
            w0 = ((xs[1] - gx) * (ys[2] - gy) - (ys[1] - gy) * (xs[2] - gx)) / area
            w1 = ((xs[2] - gx) * (ys[0] - gy) - (ys[2] - gy) * (xs[0] - gx)) / area
            w2 = 1 - w0 - w1
            inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
            if not inside.any():
                continue
            z = w0 * zs[0] + w1 * zs[1] + w2 * zs[2]
            sub = zbuf[y0:y1 + 1, x0:x1 + 1]
            mask = inside & (z > sub)
            sub[mask] = z[mask]
            cbuf[y0:y1 + 1, x0:x1 + 1][mask] = color
            ibuf[y0:y1 + 1, x0:x1 + 1][mask] = pid
            nbuf[y0:y1 + 1, x0:x1 + 1][mask] = neon
    return zbuf, cbuf, ibuf, nbuf


OUTLINE = np.array(hx('#140E0B'))


def stylize(zbuf, cbuf, ibuf, nbuf, edge_depth=0.22, outline=True):
    """Пиксель-арт: тёмный контур силуэта и затемнение внутренних рёбер. → RGBA float."""
    h, w = ibuf.shape
    filled = ibuf >= 0
    rgb = cbuf.copy()
    # внутренние рёбра: сосед ближе на edge_depth → этот пиксель темнее
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        nb_id = np.full_like(ibuf, -1)
        nb_z = np.full_like(zbuf, -1e9)
        ys = slice(max(0, dy), h + min(0, dy))
        yd = slice(max(0, -dy), h + min(0, -dy))
        xs = slice(max(0, dx), w + min(0, dx))
        xd = slice(max(0, -dx), w + min(0, -dx))
        nb_id[yd, xd] = ibuf[ys, xs]
        nb_z[yd, xd] = zbuf[ys, xs]
        edge = filled & (nb_id >= 0) & (nb_id != ibuf) & (nb_z - zbuf > edge_depth) & ~nbuf
        rgb[edge] = rgb[edge] * 0.62
    alpha = filled.astype(float)
    if outline:
        ring = np.zeros_like(filled)
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            shifted = np.zeros_like(filled)
            ys = slice(max(0, dy), h + min(0, dy))
            yd = slice(max(0, -dy), h + min(0, -dy))
            xs = slice(max(0, dx), w + min(0, dx))
            xd = slice(max(0, -dx), w + min(0, -dx))
            shifted[yd, xd] = filled[ys, xs]
            ring |= shifted
        ring &= ~filled
        rgb[ring] = OUTLINE
        alpha[ring] = 1.0
    return np.dstack([rgb, alpha])


def bounds2d(design, cam, lid_angle=0.0, transform=None):
    pts = []
    for p in design.parts:
        v = part_world(p, design, lid_angle, transform)
        pts.append(cam.project(v)[:, :2])
    pts = np.concatenate(pts)
    return pts.min(axis=0), pts.max(axis=0)


def render(design, size, lid_angle=0.0, cam=None, pad=2, scale=None, offset=None, transform=None, outline=True):
    cam = cam or Camera()
    lo, hi = bounds2d(design, cam, lid_angle, transform)
    if scale is None:
        bw, bh = hi - lo
        scale = min((size[0] - 2 * pad) / bw, (size[1] - 2 * pad) / bh)
    if offset is None:
        cx, cy = (lo + hi) / 2
        offset = (size[0] / 2 - cx * scale, size[1] / 2 + cy * scale)
    faces = geometry(design, cam, lid_angle, transform)
    z, c, i, n = raster(faces, size, scale, offset)
    return stylize(z, c, i, n, outline=outline), (scale, offset)


def project_point(point, cam, scale, offset):
    p = cam.project(np.array([point]))[0]
    return (p[0] * scale + offset[0], offset[1] - p[1] * scale)


# ---------- Клинок Памяти (пиксель-арт, общий для сцены и превью) ----------

BLADE_COLORS = {
    'k': '#0E1A24',  # контур
    's': '#E8F6FF',  # кромка
    'S': '#A9C7D8',  # клинок
    'd': '#7FA2B8',  # тень клинка
    'f': '#6FE3FF',  # дол — чистая память
    'g': '#C9D4E2',  # гарда
    'G': '#6FE3FF',  # камни
    'w': '#3B3458',  # обмотка рукояти
    'W': '#5A4F82',
    'p': '#C9D4E2',  # навершие
}


def blade_bitmap():
    W, H = 15, 50
    g = [['.'] * W for _ in range(H)]
    # клинок: колонки 5..9, кончик сужается
    for y in range(0, 34):
        if y < 6:
            half = (y + 1) // 2  # 0..3
        else:
            half = 3
        for x in range(7 - half, 7 + half + 1):
            g[y][x] = 'S'
        if half >= 1:
            g[y][7 - half] = 'k'
            g[y][7 + half] = 'k'
        if half >= 2:
            g[y][7 - half + 1] = 's'
            g[y][7 + half - 1] = 'd'
        if y == 0:
            g[y][7] = 'k'
        if 8 <= y <= 31:
            g[y][7] = 'f'
    # гарда
    for y in (34, 35, 36):
        for x in range(0, W):
            g[y][x] = 'g' if y != 36 else 'k'
        g[y][0] = 'k'
        g[y][W - 1] = 'k'
    for x in range(W):
        g[33][x] = 'k' if (x < 5 or x > 9) and 0 < x < W - 1 else g[33][x]
    g[33][0] = '.'
    g[33][W - 1] = '.'
    g[35][2] = 'G'
    g[35][12] = 'G'
    g[35][7] = 'G'
    g[34][1] = 'k'
    g[34][13] = 'k'
    # рукоять
    for y in range(37, 45):
        for x in range(6, 9):
            g[y][x] = 'w' if (y % 2) else 'W'
        g[y][5] = 'k'
        g[y][9] = 'k'
    # навершие
    for y, (a, b) in zip(range(45, 50), [(5, 9), (4, 10), (4, 10), (5, 9), (6, 8)]):
        for x in range(a, b + 1):
            g[y][x] = 'p'
        g[y][a] = 'k'
        g[y][b] = 'k'
    g[46][7] = 'G'
    g[47][7] = 'G'
    g[46][6] = 'G'
    g[46][8] = 'G'
    return [''.join(r) for r in g]
