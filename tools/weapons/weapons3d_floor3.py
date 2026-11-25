"""Оружие этажа 3 «Псарни охоты» в объёмных вокселях (0,125 стада), формат weapons3d.py.
Палитра этажа: #3B1E1E (запёкшаяся кровь), #8C3B2E (ржавь), #D9A441 (янтарь), #E8DCC0 (кость).
Тема: охотничий инвентарь — тесак, палаш, булава с когтями, клык вожака, капкан, коса ловчего, сокольничья сабля.
Голубого #6FE3FF здесь нет: он только у души и секретной редкости."""
import math
from weapons3d import W, nz, outline, bevel, OUT
from weapons3d_common345 import shades, put, shaft, collar, ellipsoid, blade, motes, line, speckle, inlay, gem, branch

BLD, RUS, AMB, BONE = '#3B1E1E', '#8C3B2E', '#D9A441', '#E8DCC0'
BONE2, BONE3 = '#C9B994', '#A39274'
LEA, LEA2, LEA3 = '#4A2A1F', '#6E4030', '#8F5A3E'
FUR, FUR2, FUR3 = '#5E5048', '#857669', '#AFA090'
ST, ST2, ST3, STH = '#4E4A48', '#77716C', '#A9A198', '#D8D0C2'
AMB0, AMB2 = '#9C6E22', '#F0C76A'
CRIM, CRIM2 = '#5E1A1E', '#9A2E34'
WD1, WD2, WD3 = '#3E281C', '#5E3E2A', '#80583A'
NA, NA2, NR, NG = '!#FFB347', '!#FFE2A0', '!#FF5A3C', '!#FFD08A'

shades({BONE: BONE2, BONE2: BONE3, BONE3: FUR, STH: ST3, ST3: ST2, ST2: ST, ST: OUT, LEA3: LEA2, LEA2: LEA, LEA: OUT,
        FUR3: FUR2, FUR2: FUR, FUR: OUT, AMB2: AMB, AMB: AMB0, AMB0: BLD, RUS: BLD, BLD: OUT, CRIM2: CRIM, CRIM: OUT,
        WD3: WD2, WD2: WD1, WD1: OUT})

STEEL = dict(back=ST, mid=ST2, ridge=ST3, light=ST3, edge=STH)


# ======================= ОБЫЧНОЕ =======================
def hunt_cleaver():
    """Охотничий тесак: широкий прямоугольный клинок с отверстием у обуха, костяная рукоять на заклёпках."""
    v = W()
    ellipsoid(v, 0.5, -12.5, 0.5, 1.9, 1.4, 1.9, lambda x, y, z: BONE2 if y >= -12 else BONE3)
    for y in range(-11, 0):
        for x in (0, 1):
            for z in (0, 1):
                v.v[(x, y, z)] = BONE if (y + x) % 4 else BONE2
    for y in (-9, -5, -2):
        for z in (-1, 2):
            put(v, 0, y, z, AMB); put(v, 1, y, z, AMB0)
    shaft(v, -8, -6, LEA2, LEA)
    v.box(-2, 3, 0, 1, -1, 2, ST)
    v.box(-3, -3, 0, 1, 0, 1, ST2); v.box(4, 4, 0, 1, 0, 1, ST2)

    def prof(t):
        hi = 5.0 if t < 0.82 else 5.0 - (t - 0.82) * 14
        return (0.5, 4.5, hi - 0.5)
    pal = dict(back=ST, mid=ST2, ridge=ST2, light=ST3, edge=STH)
    blade(v, 2, 20, prof, pal, thick=lambda t, k: 3 if k >= 6 else (2 if k >= 2 else 1))
    for y in range(2, 21):                       # толстый обух
        v.col(-4, y, 3, ST); v.col(-3, y, 3, ST2 if y % 5 else ST)
    v.carve(lambda i, j, k: (i in (-2, -1) and j in (16, 17)), ((-3, 15, -2), (0, 18, 3)))
    speckle(v, 301, 0.12, (BLD, RUS), 2, 20, only={ST2, ST3}, cell=3)
    outline(v); bevel(v)
    return v


# ======================= РЕДКОЕ =======================
def hunt_broadsword():
    """Охотничий палаш: широкий прямой клинок с долом, латунная гарда с загнутыми концами, рукоять в коже, навершие-клык."""
    v = W()
    ellipsoid(v, 0.5, -12.5, 0.5, 1.7, 1.5, 1.7, lambda x, y, z: AMB if y > -13 else AMB0)
    for k, c in ((-14, BONE), (-15, BONE2), (-16, BONE3)): put(v, 0, k, 0, c); put(v, 1, k, 1, c)
    shaft(v, -11, -1, LEA2, LEA, band=AMB0, every=4)
    for x in range(-6, 8):                                             # гарда, концы загнуты к клинку
        d = abs(x - 0.5)
        y = 0 + (1 if d > 4.5 else 0) + (1 if d > 5.5 else 0)
        v.col(x, y, 3 if d < 3 else 2, AMB if d < 5 else AMB2)
        if d <= 5: v.col(x, y - 1, 2, AMB0)
    v.box(-1, 2, -1, 1, -1, 2, AMB0)

    def prof(t):
        w = 3.1 if t < 0.8 else 3.1 * (1 - (t - 0.8) / 0.2) + 0.3
        return (0.5, w, w)
    blade(v, 2, 34, prof, STEEL, thick=lambda t, k: 3 if k >= 2 else (2 if k == 1 else 1))
    outline(v); bevel(v)
    inlay(v, [(x, y) for y in range(4, 27) for x in (0, 1)], ST)        # дол
    speckle(v, 311, 0.1, (BLD, RUS), 2, 34, only={ST2, ST3}, cell=3)
    return v



def bear_mace():
    """Медвежья булава: круглое навершие в железных обручах, меховой воротник, костяные когти."""
    v = W()
    collar(v, -17, -15, 1.9, ST, ST2)
    for y in range(-14, 13):
        c = WD2 if y % 2 else WD3
        if -10 <= y <= -2: c = LEA2 if y % 2 else LEA
        v.box(0, 1, y, y, 0, 1, c)
    # меховой воротник
    ellipsoid(v, 0.5, 14, 0.5, 4.2, 2.2, 4.2, lambda x, y, z: FUR2 if nz(x, y, z, 1, 31) > 0.45 else (FUR3 if y > 14 else FUR),
              rough=0.6, seed=32)
    cy = 21.5
    ellipsoid(v, 0.5, cy, 0.5, 6.3, 6.0, 6.3, lambda x, y, z: ST2 if nz(x, y, z, 2, 33) > 0.35 else (ST3 if nz(x, y, z, 1, 35) > 0.6 else ST))
    for (x, y, z) in list(v.v):                  # обручи
        if y > 15 and abs(y - cy) <= 0.6 and v.v[(x, y, z)] in (ST, ST2): v.v[(x, y, z)] = ST3
        if y > 15 and abs(x - 0.5) <= 0.6 and v.v[(x, y, z)] in (ST, ST2): v.v[(x, y, z)] = ST3
    speckle(v, 334, 0.2, (RUS, BLD), 16, 28, only={ST, ST2}, cell=2)
    outline(v)
    # когти: изогнутые костяные шипы из навершия
    claws = [(0, 1, 0), (1, 0.45, 0), (-1, 0.45, 0), (0, 0.45, 1), (0, 0.45, -1)]
    for (dx, dy, dz) in claws:
        n = math.sqrt(dx * dx + dy * dy + dz * dz)
        ux, uy, uz = dx / n, dy / n, dz / n
        for i in range(7):
            r = 6.0 + i * 0.8
            curl = (i / 6) ** 2 * 1.8
            x = 0.5 + ux * r + (curl if dx == 0 and dz == 0 else 0)
            y = cy + uy * r - (curl if dy < 0.9 else 0)
            z = 0.5 + uz * r
            c = BONE3 if i < 2 else (BONE2 if i < 5 else BONE)
            put(v, round(x - 0.5), round(y), round(z - 0.5), c)
            if i < 4:
                for (ax, az) in ((1, 0), (0, 1), (1, 1)):
                    put(v, round(x - 0.5) + ax, round(y), round(z - 0.5) + az, BONE3 if i < 2 else BONE2)
    return v


# ======================= ЭПИЧЕСКОЕ =======================
def pack_fang():
    """Клык вожака: клинок — огромный изогнутый клык с зазубринами по обуху, гарда из меха с клыками, янтарные трещины."""
    v = W()
    ellipsoid(v, 0.5, -13, 0.5, 2.2, 1.6, 2.2, lambda x, y, z: FUR2 if (x + y + z) % 3 else FUR)
    put(v, 0, -13, -2, NA); put(v, 1, -13, -2, NA)      # глаза волка в навершии
    shaft(v, -11, -1, LEA2, LEA, band=AMB0, every=4)
    ellipsoid(v, 0.5, 0.5, 0.5, 4.5, 1.6, 3.2, lambda x, y, z: FUR3 if nz(x, y, z, 1, 41) > 0.5 else FUR2, rough=0.7, seed=42)
    for s in (-1, 1):                                   # клыки-гарда
        for i in range(5):
            put(v, (5 + i // 2) if s > 0 else (-4 - i // 2), -i, 0, BONE2 if i < 3 else BONE)
    y0, y1 = 2, 40

    def prof(t):
        off = 0.5 + t ** 2.2 * 9 - 2.0 * t
        w = 3.8 * (1 - t ** 1.35) + 0.35
        return (off, w, w)

    def boneshade(x, y, t):
        return BONE3 if t < 0.2 else (BONE2 if t < 0.55 else BONE)
    pal = dict(back=BONE3, mid=boneshade, ridge=boneshade, light=BONE, edge=STH)
    blade(v, y0, y1, prof, pal, thick=lambda t, k: (4 if k >= 2 and t < 0.5 else (3 if k >= 1 else 2)) if t < 0.85 else 1)
    outline(v, cond=lambda i, j, k: j > -16)
    # зазубрины по обуху (−X) — вырезы после обводки
    for y in range(6, 34, 4):
        t = (y - y0) / (y1 - y0); off, w, _ = prof(t); lo = int(round(off - w))
        for z in range(-2, 3):
            v.v.pop((lo, y, z), None); v.v.pop((lo, y + 1, z), None); v.v.pop((lo + 1, y, z), None)
    # янтарные трещины-руны по середине клинка, раскалённый кончик
    for y in range(5, 37):
        t = (y - y0) / (y1 - y0); off = 0.5 + t ** 2.2 * 9 - 2.0 * t
        xx = int(round(off + math.sin(y * 0.9) * 0.8))
        if y % 4 != 0:
            put(v, xx, y, -2 if t < 0.5 else -1, NA); put(v, xx, y, 2 if t < 0.5 else 1, NA)
    for y in range(37, 41):
        t = (y - y0) / (y1 - y0); off = 0.5 + t ** 2.2 * 9 - 2.0 * t
        put(v, round(off), y, 0, NA2)
    motes(v, [(-8, 18, 0), (13, 14, 1), (-6, 32, 0), (14, 30, 0), (5, 45, 1), (-9, 6, 0)], NA, NA2)
    return v


def trap_maul():
    """Молот-капкан: боёк — раскрытый капкан: две дуги челюстей с зубьями, пружины и тарелка-приманка; цепь по рукояти."""
    v = W()
    collar(v, -17, -15, 1.8, ST, ST2)
    for y in range(-14, 13):
        v.box(0, 1, y, y, 0, 1, WD2 if y % 2 else WD1)
    for i, y in enumerate(range(-12, 12, 2)):            # цепь, намотанная спиралью
        a = i * 1.15
        x = round(0.5 + math.cos(a) * 1.6 - 0.5); z = round(0.5 + math.sin(a) * 1.6 - 0.5)
        put(v, x, y, z, ST3); put(v, x, y + 1, z, ST2)
    cy = 22
    v.box(-3, 4, 13, 15, -3, 4, ST)                      # основание
    v.box(-2, 3, 16, 20, -2, 3, ST2)                     # пружинная колонна
    for y in (17, 19):
        v.box(-3, 4, y, y, -3, 4, ST3)
    v.disc_xz(0.5, 0, 0.5, 3.6, 21, 21, ST3)             # тарелка
    # дуги челюстей в плоскости XY, раскрыты
    for s in (-1, 1):
        for deg in range(0, 181, 3):
            a = math.radians(deg)
            for rr in (8.6, 9.3, 10.0):
                x = 0.5 + s * (math.sin(a) * rr)
                y = cy + math.cos(a) * rr * 0.9
                if y < 14: continue
                v.col(round(x - 0.5), round(y), 3 if rr < 9.9 else 2, ST2 if rr < 9 else (ST if rr > 9.6 else ST3))
        for deg in range(12, 175, 14):                    # зубья внутрь
            a = math.radians(deg)
            for k in range(3):
                rr = 8.0 - k * 0.9
                x = 0.5 + s * math.sin(a) * rr; y = cy + math.cos(a) * rr * 0.9
                if y < 15: continue
                v.col(round(x - 0.5), round(y), 1 if k == 2 else 2, STH if k else ST3)
        v.box(s * 10 - (0 if s > 0 else 0), s * 10 + (1 if s > 0 else 1), cy - 1, cy + 1, -2, 2, ST)   # шарниры
    speckle(v, 351, 0.18, (RUS, BLD), 13, 32, only={ST, ST2}, cell=2)
    outline(v)
    # неон: раскалённые зубья и спусковой камень
    for s in (-1, 1):
        for deg in range(12, 175, 14):
            a = math.radians(deg); rr = 6.2
            x = 0.5 + s * math.sin(a) * rr; y = cy + math.cos(a) * rr * 0.9
            if y >= 15: put(v, round(x - 0.5), round(y), 0, NR)
    v.box(0, 1, 21, 22, 0, 1, NA2)
    put(v, 0, 22, -1, NR); put(v, 1, 22, 2, NR)
    motes(v, [(-13, 30, 0), (14, 28, 1), (-12, 15, 1), (13, 12, 0), (2, 37, 0)], NR, NA)
    return v


# ======================= ЛЕГЕНДАРНОЕ =======================
def antler(v, x0, y0, s, n=13, c=AMB, tipc=None):
    """Золотой олений рог от (x0, y0) в сторону s: ствол вверх-наружу, три отростка."""
    pts = []
    for i in range(n):
        t = i / (n - 1)
        pts.append((x0 + s * (6.5 * t - 2.0 * t * t), y0 + 13 * t - 1.5 * t * t))
    branch(v, pts, c, tip=tipc, t=3)
    for (f, ln) in ((0.3, 6), (0.62, 6), (0.88, 4)):
        bx, by = pts[int(f * (n - 1))]
        branch(v, [(bx, by), (bx + s * 2.0, by + ln * 0.6), (bx + s * 1.2, by + ln)], c, tip=tipc, t=2)


def royal_scythe():
    """Коса Королевского ловчего: багряное косовище в золотой спирали, у пятки — золотые оленьи рога и рубин,
    широкое стальное полотно с янтарной кромкой и золотой жилой, багряные кисти, подток-клык."""
    v = W()
    for y in range(-19, -15):                                          # подток
        v.disc_xz(0.5, 0, 0.5, 0.6 + (y + 19) * 0.35, y, y, AMB if y % 2 else AMB2)
    for y in range(-15, 46):
        v.box(0, 1, y, y, 0, 1, CRIM2 if y % 2 else CRIM)
    for i in range(0, 120):                                            # золотая спираль
        y = -14 + i * 0.46
        if y > 41: break
        a = i * 0.55
        put(v, round(0.5 + math.cos(a) * 1.25 - 0.5), round(y), round(0.5 + math.sin(a) * 1.25 - 0.5), AMB if i % 3 else AMB2)
    for y in range(-9, -3): v.box(0, 1, y, y, 0, 1, LEA2 if y % 2 else LEA)
    for (yh, s) in ((-1, 1), (21, -1)):                                # ручки косовища
        for k in range(1, 5):
            v.box(s * k + (1 if s > 0 else 0), s * k + (1 if s > 0 else 0), yh, yh + 1, 0, 1, LEA3 if k < 4 else AMB2)
    collar(v, 40, 42, 1.9, AMB, AMB2)
    v.box(-1, 2, 43, 48, -1, 2, AMB0)                                  # пятка полотна
    L = 34
    def edge(i):
        t = i / L
        top = 51 - (t ** 1.6) * 19
        width = 9.5 * (1 - t ** 1.25) + 0.8
        return top, width
    for i in range(L + 1):
        t = i / L; x = -1 - i
        top, width = edge(i); bot = top - width
        for y in range(int(math.floor(bot)), int(math.ceil(top)) + 1):
            k = (y - bot) / max(0.5, width)
            if k < 0.16: c = STH
            elif k < 0.3: c = ST3
            elif k > 0.86: c = AMB                                     # золотой обух
            else: c = ST2 if nz(x, y, 0, 2, 331) > 0.3 else ST3
            tz = 4 if k > 0.4 and t < 0.6 else (3 if k > 0.25 and t < 0.8 else (2 if k > 0.1 else 1))
            v.col(x, y, tz, c)
    antler(v, 2, 47, 1, n=13, c=AMB, tipc=AMB2)                        # рога над пяткой
    antler(v, -1, 49, -1, n=9, c=AMB, tipc=AMB2)
    for s in (-1, 1):                                                  # кисти у втулки
        for i in range(9):
            put(v, (2 if s > 0 else -1) + s * (i // 4), 40 - i, s, CRIM2 if i < 7 else AMB2)
    outline(v); bevel(v)
    cells_edge, cells_vein = [], []
    for i in range(1, L - 1):
        top, width = edge(i); x = -1 - i
        cells_edge.append((x, int(math.floor(top - width))))
        cells_edge.append((x, int(math.floor(top - width)) + 1))
        yv = int(round(top - width * (0.62 + 0.08 * math.sin(i * 0.7))))
        if i % 6 != 5: cells_vein.append((x, yv))
    inlay(v, cells_edge, NA)                                           # светящаяся кромка
    inlay(v, cells_vein, NA2)                                          # жила
    gem(v, 0.5, 45.5, 2.4, NR, AMB2, mid='!#FF8A5A', depth=1)          # рубин в пятке
    for y in range(-11, 38, 12): inlay(v, [(0, y), (1, y)], NA)         # огоньки на косовище
    return v


def falconer_saber():
    """Клинок сокольничего: широкая изогнутая сабля, гарда — расправленные крылья сокола с янтарными кончиками,
    навершие — голова сокола с горящими глазами, дол-перо светится, обух — зубцы-перья."""
    v = W()
    ellipsoid(v, 0.5, -13.5, 0.5, 2.1, 2.2, 2.1, lambda x, y, z: LEA3 if y > -14 else BONE2)
    for k in range(4):                                                 # клюв
        put(v, 0 + k, -12 - k // 2, 0, AMB); put(v, 0 + k, -12 - k // 2, 1, AMB if k < 3 else AMB2)
    shaft(v, -11, -1, LEA2, LEA, band=AMB, every=3)
    for s in (-1, 1):                                                  # крылья
        for i in range(13):
            xi = (2 + i) if s > 0 else (-1 - i)
            base = -1 + int(i * 0.55)
            hgt = 3 + int(i * 0.55) + (1 if i % 2 else 0)
            for k in range(hgt):
                c = BONE if k == hgt - 1 else (LEA3 if (i + k) % 2 else LEA2)
                if i >= 5 and k >= hgt - 2: c = AMB
                v.col(xi, base + k, 2, c)
    v.box(-1, 2, -1, 1, -2, 3, AMB0)
    y0, y1 = 2, 45
    def prof(t):
        off = 0.5 + t * t * 9.0
        w = 3.2 if t < 0.78 else 3.2 * (1 - (t - 0.78) / 0.22) + 0.2
        return (off, w, w + 0.5)
    blade(v, y0, y1, prof, STEEL, thick=lambda t, k: (3 if k >= 2 else (2 if k == 1 else 1)) if t < 0.92 else 1)
    for y in range(6, 40, 4):                                          # зубцы-перья по обуху
        t = (y - y0) / (y1 - y0); off, w, _ = prof(t)
        xb = int(round(off - w)) - 1
        for k in range(3): v.col(xb - k // 2, y + k, 1, BONE if k < 2 else BONE2)
    outline(v); bevel(v)
    for s in (-1, 1):                                                  # глаза и кончики крыльев
        put(v, -1 if s < 0 else 2, -13, 0, NR)
        for i in range(8, 13):
            x = (2 + i) if s > 0 else (-1 - i)
            base = -1 + int(i * 0.55); hgt = 3 + int(i * 0.55) + (1 if i % 2 else 0)
            inlay(v, [(x, base + hgt - 1)], NA2)
    fuller = []
    for y in range(5, 40):
        t = (y - y0) / (y1 - y0); off, w, _ = prof(t)
        fuller += [(int(round(off)), y)] + ([(int(round(off)) - 1, y)] if t < 0.7 else [])
    inlay(v, fuller, lambda x, y: NA2 if y % 7 == 0 else NA)           # светящийся дол
    gem(v, 0.5, 0, 1.8, NA2, AMB2, depth=1, zlo=-2, zhi=3)             # янтарь в гарде
    return v


WEAPONS = [
    ('hunt_cleaver', hunt_cleaver, 'common'),
    ('hunt_broadsword', hunt_broadsword, 'rare'),
    ('bear_mace', bear_mace, 'rare'),
    ('pack_fang', pack_fang, 'epic'),
    ('trap_maul', trap_maul, 'epic'),
    ('royal_scythe', royal_scythe, 'legendary'),
    ('falconer_saber', falconer_saber, 'legendary'),
]

# id: (масштаб, y-воксель кисти). Копья держат в нижней трети древка.
SPEC = {
    'hunt_cleaver': (1.0, -6),
    'hunt_broadsword': (0.86, -6),
    'bear_mace': (0.9, -5),
    'pack_fang': (0.8, -6),
    'trap_maul': (0.8, -5),
    'royal_scythe': (0.82, -4),
    'falconer_saber': (0.86, -6),
}
# Верх гарды (низ клинка) для точки BladeBase, где автоопределение по ширине ошибается.
GUARD = {'royal_scythe': 43, 'falconer_saber': 1, 'trap_maul': 13, 'bear_mace': 13}
