"""Оружие этажа 2 «Затопленные сады» в объёмных вокселях (0,125 стада), тот же формат, что weapons3d.py.
Оси: Y — вдоль оружия (рукоять около 0, клинок/боёк вверх), X — поперёк (плоскость клинка), Z — толщина.
Цвет '!#hex' — неон (отдельный объект Glow). Только мечи и молоты (класс «Воин»).
Тема: садовые орудия, потонувшие и проросшие: тесак, сабля из камыша, колотушка, тернии, корни, жатва, паводок, секатор.
Голубого #6FE3FF здесь нет: он только у души/секретной редкости."""
import math
from vox import Vox
import weapons3d as B
from weapons3d import (W, nz, outline, bevel, grip, VS, OUT, WD, WM, WL, ID, IM, IL, IH, BN, BH,
                       BRD, BR, BRL, GD, GM, GLt, DARKER, LIGHTER, sword_blade)

# --- палитра этажа 2 (из Palette.Floors[2] и производные) ---
MD, MG, ML, TL = '#102632', '#28674F', '#A5CE83', '#5FD0C0'      # глубокая холодная тень, зелень, бирюза
MS1, MS2, MS3 = '#142C29', '#38774A', '#8FC66B'                   # мох: контраст без новых пятен
MUD, MUD2 = '#1B1C23', '#49372D'                                  # ил
RW, RWL = '#52684F', '#BCCF9D'                                    # камыш
ST1, ST2, ST3 = '#102A3A', '#2C6875', '#8BC6C5'                   # холодная оправа ракушечника
FOAM = '#EFF7ED'                                                  # пена
SW, SWL, SWH = '#3D6468', '#8FBAB8', '#E4F4E9'                    # холодная сталь: тёмная грань / ясный блик
RS, RSL = '#852D48', '#E2889B'                                    # роза
TG, TG2 = '!#5FD0C0', '!#B8F2E6'                                  # неон: бирюза, ядро

DARKER.update({MG: MD, ML: MG, MS3: MS2, MS2: MS1, MS1: OUT, MUD2: MUD, MUD: OUT, RWL: RW, RW: MS1,
               ST3: ST2, ST2: ST1, ST1: OUT, SWH: SWL, SWL: SW, SW: ID, FOAM: SWH,
               RSL: RS, RS: OUT, TL: MG, MD: OUT})
LIGHTER.clear(); LIGHTER.update({v: k for k, v in DARKER.items() if v != OUT})

def moss(v, seed, amount, ymin=-999, ymax=999, only=None, cell=3):
    """Пятна мха поверх любого цвета, кроме неона и контура (крупные кластеры, а не камуфляж)."""
    for key in list(v.v):
        i, j, k = key; c = v.v[key]
        if c.startswith('!') or c == OUT or not (ymin <= j <= ymax): continue
        if only and c not in only: continue
        n = nz(i, j, k, cell, seed)
        if n < amount * 0.45: v.v[key] = MS2
        elif n < amount: v.v[key] = MS3 if nz(i, j, k, 1, seed + 5) < 0.45 else MS2

def mud(v, seed, amount, ymin=-999, ymax=999, cell=3):
    for key in list(v.v):
        i, j, k = key; c = v.v[key]
        if c.startswith('!') or c == OUT or not (ymin <= j <= ymax): continue
        n = nz(i, j, k, cell, seed)
        if n < amount: v.v[key] = MUD if nz(i, j, k, 1, seed + 7) < 0.55 else MUD2

def wrap_grip(v, y0, y1, a, b, band=None, every=3):
    for y in range(y0, y1 + 1):
        c = a if y % 2 else b
        if band and (y - y0) % every == 0: c = band
        for x in (0, 1):
            for z in (0, 1):
                v.v[(x, y, z)] = c

def leaf(v, x, y, z, c=MS3, c2=MS2, up=True):
    """Листик 3 вокселя на плоскости XY: ромб-зёрнышко."""
    for dx, dy, col in ((0, 0, c), (1, 1 if up else -1, c2), (-1, 1 if up else -1, c2)):
        v.v[(x + dx, y + dy, z)] = col

def vine(v, y0, y1, r, phase=0.0, turns=1.6, c=MG, c2=MS3, cx=0.5, cz=0.5, leaf_every=7):
    """Лоза спиралью вокруг оси рукояти."""
    n = max(1, y1 - y0)
    for i in range(n * 3 + 1):
        t = i / (n * 3)
        y = y0 + t * n
        a = phase + t * turns * math.tau
        x = int(round(cx + math.cos(a) * r - 0.5)); z = int(round(cz + math.sin(a) * r - 0.5))
        v.v[(x, int(round(y)), z)] = c if i % 5 else c2
        if i % (leaf_every * 3) == 0:
            v.v[(x + (1 if math.cos(a) > 0 else -1), int(round(y)) + 1, z)] = c2

# ======================= ОБЫЧНОЕ =======================
def garden_machete():
    """Садовый тесак: широкий однолезвийный, с петлёй-вырезом и косым срезом острия; обух толстый."""
    v = W()
    v.disc_xz(0.5, 0, 0.5, 1.9, -12, -11, lambda x, y, z: WL if y == -11 else WM)
    wrap_grip(v, -10, -1, WM, WD, band=MS2, every=3)
    v.box(-2, 3, 0, 1, -1, 2, ID)
    v.box(-3, -3, 0, 1, 0, 1, IM); v.box(4, 4, 0, 1, 0, 1, IM)
    for y in range(2, 22):
        lo, hi = -4, 5
        if y > 14: hi = 5 - (y - 14) * 5 // 8
        for x in range(lo, hi + 1):
            if x == hi: c = SWH
            elif x == hi - 1: c = SWL
            elif x <= lo + 1: c = ID
            elif x in (0, 1): c = SWL
            else: c = SW
            t = 3 if x <= lo + 1 else (2 if x < hi - 1 else 1)
            v.col(x, y, t, c)
    v.carve(lambda i, j, k: (i in (-2, -1) and j in (9, 10, 11)), ((-3, 8, -2), (0, 12, 3)))
    moss(v, 61, 0.30, 2, 12, only={ID, SW, SWL}, cell=3)
    mud(v, 62, 0.22, -12, 8, cell=3)
    outline(v); bevel(v)
    return v

def reed_saber():
    """Камышовая сабля: тонкий изогнутый клинок, оплётка рукояти из камыша, круглая гарда."""
    v = W()
    v.disc_xz(0.5, 0, 0.5, 1.6, -13, -12, lambda x, y, z: RWL if y == -12 else RW)
    wrap_grip(v, -11, -1, RW, MS2, band=RWL, every=2)
    v.disc_xz(0.5, 0, 0.5, 4.2, 0, 0, lambda x, y, z: IM if math.hypot(x - 0.5, z - 0.5) > 2.5 else IL)
    v.disc_xz(0.5, 0, 0.5, 3.0, 1, 1, lambda x, y, z: ID)
    for x in (-4, 5): v.box(x, x, 0, 0, 0, 1, MS3)
    y0, y1 = 2, 32
    for y in range(y0, y1 + 1):
        t = (y - y0) / (y1 - y0)
        off = int(round(t * t * 6))
        half = 2 if y < y1 - 6 else max(0, 2 - (y - (y1 - 6)) // 3)
        for x in range(-half + off, half + 2 + off):
            if x == half + 1 + off: c = SWH
            elif x == half + off: c = SWL
            elif x == -half + off: c = ID
            else: c = SWL if x == off else SW
            t_ = 3 if x in (off, off + 1) else (2 if -half + off < x < half + 1 + off else 1)
            v.col(x, y, t_ if y < y1 - 2 else 1, c)
    moss(v, 71, 0.22, 3, 14, only={SW, SWL, ID}, cell=3)
    outline(v); bevel(v)
    return v

def mud_mallet():
    """Колотушка садовника: бочонок-боёк на дощатой рукояти, железные обручи, ил и мох."""
    v = W()
    v.disc_xz(0.5, 0, 0.5, 1.8, -16, -14, lambda x, y, z: WL if y == -14 else WM)
    for y in range(-13, 15):
        c = WM if y % 2 else WL
        if y in (-12, -11, -6, 12, 13): c = MS2 if y != -6 else MS3
        v.box(0, 1, y, y, 0, 1, c)
    # боёк: горизонтальный бочонок вдоль X
    yc, r = 21, 6.2
    for x in range(-9, 11):
        rr = r - (0.9 if x in (-9, 10) else 0.0) - 0.7 * (abs(x - 0.5) / 9.5) ** 2 * 2
        for y in range(15, 28):
            for z in range(-7, 8):
                d = math.hypot(y - yc, z)
                if d <= rr:
                    if x in (-9, 10): c = ID                                        # торцевая плита
                    elif x in (-7, -6, 7, 8): c = IM if x in (-7, 8) else IL        # обручи
                    else: c = WM if int(math.atan2(z, y - yc) * 3) % 2 else WL        # доски
                    v.v[(x, y, z)] = c
    for x in (-8, 9):                                                                 # заклёпки
        for ang in range(0, 360, 60):
            y = int(round(yc + math.cos(math.radians(ang)) * 4.5)); z = int(round(math.sin(math.radians(ang)) * 4.5))
            if (x, y, z) in v.v: v.v[(x, y, z)] = IH
    moss(v, 81, 0.34, 15, 28, only={WM, WL})
    mud(v, 82, 0.34, -16, 30)
    outline(v)
    return v

# ======================= РЕДКОЕ =======================
def thorn_blade():
    """Терновый клинок: прямой, по кромкам шипы, лоза вокруг гарды, бирюзовый камень."""
    v = W()
    v.disc_xy(0.5, -13, 2.8, 0, 3, lambda x, y, z: MG if abs(math.hypot(x - 0.5, y + 13) - 1.8) < 0.7 else MD)
    v.col(0, -13, 3, TL); v.col(1, -13, 3, TL)
    wrap_grip(v, -10, -1, WM, WD, band=MS3, every=3)
    for s_ in (-1, 1):
        for d in range(2, 8):
            x = (d if s_ > 0 else 1 - d)
            yo = 0 if d < 5 else -(d - 4)
            v.col(x, yo, 3, MG if d % 2 else MS1); v.col(x, yo + 1, 3, MG if d % 2 else MS1)
        xe = 8 if s_ > 0 else -7
        v.box(xe, xe, -4, -2, 0, 1, MS3)
    v.box(-1, 2, -2, 3, -2, 2, MD)
    v.box(0, 1, 0, 1, -3, 3, TL)
    sword_blade(v, 4, 32, 3, 5, mid=SW, light=SWL, dark=ID, ridge=SWH, edge=SWH, seed=5)
    moss(v, 91, 0.2, 4, 14, only={SW, ID}, cell=3)
    outline(v); bevel(v)
    # шипы по кромкам и лоза добавляются после обводки, чтобы остались зелёными
    for y in range(9, 30, 5):
        for s_, x0 in ((-1, -4), (1, 5)):
            for k in range(1, 4):
                xx = x0 + k if s_ > 0 else x0 - k + 1
                v.col(xx, y + (k // 2), max(1, 3 - k), MS2 if k < 3 else ML)
        v.col(-3, y, 1, MD); v.col(5, y, 1, MD)
    vine(v, -1, 12, 2.6, phase=0.5, turns=1.2, c=MG, c2=MS3, leaf_every=5)
    return v

def root_hammer():
    """Корневой молот: боёк — клубок корней в железной обечайке, по рукояти ползёт лоза."""
    v = W()
    v.box(-1, 2, -17, -14, -1, 2, WD)
    v.box(0, 1, -16, -15, -2, 3, MS2)
    for y in range(-13, 15):
        v.box(0, 1, y, y, 0, 1, WM if y % 2 else WD)
    cx, cy = 0.5, 22
    for x in range(-10, 12):
        for y in range(14, 32):
            for z in range(-6, 7):
                dx, dy, dz = (x - cx) / 10.2, (y - cy) / 8.6, z / 6.2
                n = (nz(x, y, z, 3, 13) - 0.5) * 0.4
                if dx * dx + dy * dy + dz * dz + n <= 1.0:
                    ring = (int(math.atan2(z, x - cx) * 2.2 + y * 0.6)) % 3
                    c = WL if ring == 0 else (WM if ring == 1 else WD)
                    if nz(x, y, z, 2, 31) < 0.1: c = MS2
                    v.v[(x, y, z)] = c
    for (x, y, z) in list(v.v):
        if y >= 14 and (x <= -9 or x >= 10): v.v[(x, y, z)] = ID if (x <= -10 or x >= 11) else IM
    for (x, y, z) in list(v.v):
        if y >= 14 and x in (-6, -5, 7, 8) and v.v[(x, y, z)] not in (ID,): v.v[(x, y, z)] = IM if x in (-6, 8) else IL
    # корни, торчащие из бойка и огибающие обечайку
    for (sx, sy, sz) in [(-8, 28, 0), (6, 29, 1), (0, 30, -2), (-3, 15, 3), (5, 15, -3)]:
        for i in range(6):
            v.v[(sx + (i if sx < 3 else -i) // 2, sy + (1 if sy > 22 else -1) * (i + 1), sz + (i % 2)) ] = MS3 if i % 2 else MS2
    moss(v, 101, 0.28, 14, 32, only={WM, WL, WD}, cell=3)
    outline(v)
    vine(v, -12, 13, 1.9, phase=0.0, turns=2.0, c=MS2, c2=MS3, leaf_every=6)
    return v

def reaper_blade():
    """Клинок жатвы: длинное серповидное лезвие, кромка светится бирюзой, листья-гарда, парящие семена."""
    v = W()
    v.disc_xy(0.5, -14, 2.4, 0, 3, lambda x, y, z: MG if (x + y) % 3 else MD)
    v.col(0, -14, 3, TG); v.col(1, -14, 3, TG)
    wrap_grip(v, -11, 1, MD, MS1, band=MS3, every=3)
    for s_ in (-1, 1):
        for d in range(1, 8):
            x = d + 1 if s_ > 0 else -d
            yo = -(d // 3)
            w = max(1, 3 - abs(d - 4) // 2)
            for k in range(w):
                v.col(x, yo + k - 1, 3 if k == 1 else 2, ML if k == 1 else MG)
    v.box(-1, 2, -1, 2, -2, 3, ST1)
    y0, y1 = 3, 40
    for y in range(y0, y1 + 1):
        t = (y - y0) / (y1 - y0)
        off = int(round(t ** 2.0 * 12 - 1.5 * t))
        half = max(0, int(round(3.0 * (1 - t ** 1.6))))
        for x in range(off - half, off + half + 2):
            tip = (x == off + half + 1)
            if tip: c = SWH
            elif x == off + half: c = SWL
            elif x == off - half: c = ID
            else: c = SW if (x + y) % 5 else SWL
            t_ = 3 if abs(x - off) <= 1 and t < 0.7 else (2 if t < 0.9 else 1)
            v.col(x, y, t_, c)
    outline(v, cond=lambda i, j, k: j > -15)
    # неоновая кромка и прожилки — после обводки
    for y in range(6, 40):
        t = (y - y0) / (y1 - y0); off = int(round(t ** 2.0 * 12 - 1.5 * t))
        half = max(0, int(round(3.0 * (1 - t ** 1.6))))
        if y % 3 != 2 and y > 7: v.v[(off + half + 1, y, 0)] = TG2
        if y % 2 == 0:
            v.v[(off, y, -2 if t < 0.7 else -1)] = TG
            v.v[(off, y, 2 if t < 0.7 else 1)] = TG
    v.v[(0, 0, -2)] = TG; v.v[(1, 1, 3)] = TG2
    for (x, y, z) in [(-9, 20, 0), (-7, 30, 1), (14, 8, 0), (-10, 9, 0), (8, 45, 0), (-4, 40, 1)]:
        leaf(v, x, y, z, ML, MS2)
    for (x, y, z) in [(15, 20, 0), (-8, 36, 0), (5, 47, 1), (-11, 14, 1), (16, 30, 1)]:
        v.v[(x, y, z)] = TG
    return v

def tidal_hammer():
    """Приливный молот: округлый боёк из ракушечника с волнистыми прослойками, гребень-волна, неоновые прожилки."""
    v = W()
    v.disc_xz(0.5, 0, 0.5, 2.3, -17, -14, lambda x, y, z: ST2 if y in (-15, -16) else ST1)
    for y in range(-13, 15):
        c = ST2 if y % 2 else ST1
        if y in (-12, -6, 6, 13): c = SWL
        v.box(0, 1, y, y, 0, 1, c)
    cx, cy = 0.5, 22.0
    for x in range(-13, 14):
        for y in range(13, 32):
            for z in range(-7, 8):
                dx, dy, dz = abs(x - cx) / 11.5, abs(y - cy) / 8.0, abs(z) / 6.3
                if dx ** 4 + dy ** 3 + dz ** 3 <= 1.0:
                    band = int((y + 2.4 * math.sin(x * 0.55)) // 2) % 3
                    c = (ST1, ST2, ST3)[band]
                    if dx > 0.84: c = SWL if dx < 0.94 else SW           # металлические обечайки торцов
                    v.v[(x, y, z)] = c
    # гребень волны над бойком: изогнутый завиток
    for deg in range(185, 15, -5):
        a = math.radians(deg)
        for r10 in (42, 49, 56):
            r = r10 / 10
            x = int(round(1.5 + math.cos(a) * r)); y = int(round(30.5 + math.sin(a) * r * 0.95))
            c = FOAM if r10 >= 56 else (ST3 if r10 >= 49 else ST2)
            for z in (-3, -2, -1, 0, 1, 2, 3):
                if abs(z) <= 3 - (1 if r10 >= 56 else 0):
                    v.v[(x, y, z)] = c
    outline(v)
    # неоновые волновые прожилки на лицевых гранях и сверху
    for x in range(-9, 11):
        yy = int(round(22 + 3 * math.sin(x * 0.55)))
        for dz in (0, 1):
            z = -7 - dz if False else None
        for z in (-6, 6):
            for y in (yy, yy + 1):
                if (x, y, z) in v.v: v.v[(x, y, z)] = TG
                z2 = z + (1 if z > 0 else -1)
                if (x, y, z2) in v.v or True: v.v[(x, y, z2)] = TG2 if (x + y) % 3 == 0 else TG
    for (x, y, z) in [(-14, 33, 0), (14, 31, 1), (15, 14, 0), (-14, 12, 0), (4, 41, 0), (-6, 40, 1)]:
        v.v[(x, y, z)] = TG; v.v[(x, y + 1, z)] = TG2
    return v

def gardener_shears():
    """Секатор Садовницы: два длинных лезвия-«ножницы» на золотой оси, кольца-рукояти с розами и лозами."""
    v = W()
    px, py = 0, 8
    for sgn in (-1, 1):
        for y in range(py, 46):
            t = (y - py) / (46 - py)
            cx = px + sgn * (1.0 + t * 8.0)
            half = 2.2 * (1 - t ** 1.5) + 0.7
            for x in range(int(round(cx - half - 0.5)), int(round(cx + half + 0.5)) + 1):
                inner = (x == int(round(cx - sgn * half)))
                if inner: c = SWH
                elif abs(x - cx) <= 0.8: c = SWL
                else: c = SW if (x + y) % 4 else SWL
                v.col(x, y, 3 if t < 0.6 else (2 if t < 0.9 else 1), c)
    for sgn in (-1, 1):
        for d in range(0, 18):
            x = px + (-sgn) * (0.5 + d * 0.3)
            y = py - 1 - d
            v.col(int(round(x)), y, 3, BR if d % 3 else BRL)
    for sgn in (-1, 1):
        cx = px + (-sgn) * 6.0
        v.disc_xy(cx + 0.5, -15, 4.6, 2.5, 3, lambda x, y, z: GM if (x + y) % 3 else BRL)
    v.box(-1, 2, py - 1, py + 2, -3, 4, GD)
    v.box(0, 1, py, py + 1, -3, 4, TG2)
    outline(v)
    # золотые ободы, розы, лоза, лепестки и споры — после обводки
    for y in range(py + 5, 43, 7):
        for sgn in (-1, 1):
            cx = px + sgn * (1.0 + (y - py) / (46 - py) * 8.0)
            v.col(int(round(cx)), y, 3, GM)
    v.box(0, 1, py, py + 1, 0, 1, TG)
    for (x, y, z) in [(-8, -11, 2), (8, -11, 2), (-9, -17, -2), (9, -17, -2), (-7, -19, 3), (7, -19, 3)]:
        v.box(x, x + 1, y, y + 1, z, z + 1, RS)
        v.v[(x, y + 1, z + 1)] = RSL; v.v[(x + 1, y, z)] = RSL
        v.v[(x - 1, y, z)] = MS3; v.v[(x + 2, y + 1, z)] = MS2
    for sgn in (-1, 1):
        for y in range(py + 3, 38, 3):
            cx = px + sgn * (1.0 + (y - py) / (46 - py) * 8.0)
            xx = int(round(cx + sgn * 3.2))
            v.v[(xx, y, 0)] = MS2; v.v[(xx + sgn, y + 1, 1)] = MS3
            if (y // 3) % 2: v.v[(xx, y, -1)] = RS
    for (x, y, z) in [(-12, 30, 0), (14, 38, 1), (-13, 12, 1), (14, 20, 0), (3, 52, 0), (-4, 50, 1)]:
        v.box(x, x + 1, y, y + 1, z, z + 1, RSL)
    for (x, y, z) in [(-14, 40, 0), (16, 30, 0), (-15, 22, 1), (11, 48, 0), (0, 56, 1)]:
        v.v[(x, y, z)] = TG; v.v[(x, y + 1, z)] = TG2
    return v

WEAPONS = [
    ('garden_machete', garden_machete, 'common'),
    ('reed_saber', reed_saber, 'common'),
    ('mud_mallet', mud_mallet, 'common'),
    ('thorn_blade', thorn_blade, 'rare'),
    ('root_hammer', root_hammer, 'rare'),
    ('reaper_blade', reaper_blade, 'epic'),
    ('tidal_hammer', tidal_hammer, 'epic'),
    ('gardener_shears', gardener_shears, 'legendary'),
]
