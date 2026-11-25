"""Оружие этажа 4 «Кузня Основателя» в объёмных вокселях (0,125 стада), формат weapons3d.py.
Палитра этажа: #1E1B1F (сажа), #4A4350 (окалина), #E2672B (расплав), #FFC857 (жар).
Тема: литьё и ковка — литой тесак, закалка цветами побежалости, молот подмастерья, тигель, раскалённый клинок,
наковальня, сердце горна, шлаковая коса и секретная «Незавершённая отливка» (растёт ступенями — неон G по цветам STAGE).
Голубой #6FE3FF — только кристалл памяти секретки."""
import math
from weapons3d import W, nz, outline, bevel, OUT, LIGHTER
from weapons3d_common345 import shades, put, shaft, collar, ellipsoid, blade, motes, line, speckle, inlay, gem, branch

DK, SL, ORG, YL = '#1E1B1F', '#4A4350', '#E2672B', '#FFC857'
IR1, IR2 = '#2C2830', '#3A3540'
SL2, SL3, SLH = '#6A6272', '#8E8696', '#B9B0BE'
BZ1, BZ2, BZ3 = '#6E4220', '#A0622C', '#CC8A3E'
SG1, SG2, SG3 = '#33241F', '#54362A', '#7A4A30'          # шлак
WD1, WD2, WD3 = '#3A251A', '#5A3B28', '#7C5538'
LE1, LE2 = '#3E2620', '#5E3A2C'
QB, QP, QBR, QS = '#3E5C9A', '#6B4E8A', '#B07A3A', '#D9B66A'   # цвета побежалости
CLY1, CLY2 = '#6E3E2E', '#8E5440'                          # глина тигля
MEM = '#6FE3FF'
NO, NY, NW = '!#FF7A2B', '!#FFC857', '!#FFF1C2'
# ступени секретки (G-объекты по цвету; клиент показывает их по атрибуту CastStage)
STAGE = ['!#FF6A1A', '!#FF8A2A', '!#FFA63A']
NCORE = '!#FFB347'

shades({SLH: SL3, SL3: SL2, SL2: SL, SL: IR2, IR2: IR1, IR1: OUT, DK: OUT, BZ3: BZ2, BZ2: BZ1, BZ1: OUT,
        SG3: SG2, SG2: SG1, SG1: OUT, WD3: WD2, WD2: WD1, WD1: OUT, LE2: LE1, LE1: OUT, QS: QBR, QBR: QP, QP: QB, QB: IR2,
        CLY2: CLY1, CLY1: OUT, YL: ORG, ORG: SG3})

LIGHTER[IR2] = SL                     # иначе фаска +X у окалины уходила в синий (QB → IR2)

IRON = dict(back=IR2, mid=SL, ridge=SL2, light=SL3, edge=SLH)


# ======================= ОБЫЧНОЕ =======================
def cast_cleaver():
    """Литой тесак: толстый грубый клинок с литейным швом и обрубком литника, рукоять в железных кольцах."""
    v = W()
    collar(v, -13, -12, 1.8, IR2, SL)
    shaft(v, -11, -1, LE2, LE1, band=SL2, every=4)
    v.box(-3, 4, 0, 1, -1, 2, IR2)
    def prof(t):
        hi = 5.0 - (0 if t < 0.75 else (t - 0.75) * 12)
        lo = 4.0 - (0 if t < 0.9 else (t - 0.9) * 10)
        return (0.5, lo, hi - 0.5)
    blade(v, 2, 19, prof, dict(back=IR1, mid=SL, ridge=SL, light=SL2, edge=SL3), thick=lambda t, k: 3 if k >= 3 else (2 if k >= 1 else 1))
    for y in range(2, 19):
        put(v, 0, y, 2, SL2 if y % 3 else SL3)                # литейный шов
        put(v, 0, y, -1, SL2 if y % 3 else SL3)
    v.box(-4, -3, 19, 21, 0, 1, IR2)                          # обрубок литника
    speckle(v, 401, 0.18, (DK, IR2), 2, 21, only={SL, SL2}, cell=2)
    outline(v); bevel(v)
    return v


# ======================= РЕДКОЕ =======================
def quench_blade():
    """Закалённый клинок: прямой меч, клинок в полосах побежалости — от синего у гарды до соломенного к острию."""
    v = W()
    ellipsoid(v, 0.5, -13, 0.5, 1.7, 1.4, 1.7, lambda x, y, z: SL2)
    shaft(v, -11, -1, LE2, LE1, band=SL2, every=3)
    for x in range(-4, 6):
        v.col(x, 0, 3, SL2 if abs(x - 0.5) < 4 else SL3); v.col(x, 1, 2, SL)
    TEMPER = [QB, QB, QP, QP, QBR, QBR, QS, QS, SL3]

    def mid(x, y, t):
        return TEMPER[min(len(TEMPER) - 1, int(t * len(TEMPER)))]
    def prof(t):
        w = 2.4 if t < 0.85 else 2.4 * (1 - (t - 0.85) / 0.15) + 0.1
        return (0.5, w, w)
    blade(v, 2, 34, prof, dict(back=mid, mid=mid, ridge=mid, light=SL3, edge=SLH),
          thick=lambda t, k: 3 if k >= 2 else (2 if k == 1 else 1))
    outline(v); bevel(v)
    return v


def apprentice_hammer():
    """Молот подмастерья: кузнечный молоток — боёк с одной стороны, клин с другой, клинья в проушине."""
    v = W()
    collar(v, -16, -15, 1.6, WD1, WD2)
    for y in range(-14, 14):
        c = WD3 if y % 2 else WD2
        if -9 <= y <= -3: c = LE2 if y % 2 else LE1
        v.box(0, 1, y, y, 0, 1, c)
    cy = 18
    for x in range(-9, 11):
        for y in range(cy - 3, cy + 4):
            for z in range(-3, 5):
                ax = x - 0.5
                if ax > 0:                                      # боёк: квадрат с фаской
                    if abs(y - cy) == 3 and abs(z - 0.5) >= 3.5: continue
                    c = SL3 if x >= 9 else (SL2 if (x + y) % 5 else SL)
                else:                                           # клин: сужается к −X
                    k = (-ax) / 9.5
                    if abs(y - cy) > 3 - k * 2.6: continue
                    c = SLH if x <= -8 else (SL2 if (x + z) % 4 else SL)
                v.v[(x, y, z)] = c
    v.box(0, 1, cy + 4, cy + 4, 0, 1, WD3); put(v, 0, cy + 4, 2, SL3)   # клинья в проушине
    speckle(v, 421, 0.16, (DK, IR2), 14, 23, only={SL, SL2}, cell=2)
    outline(v); bevel(v)
    return v


# ======================= ЭПИЧЕСКОЕ =======================
def crucible_maul():
    """Молот-тигель: глиняный тигель в железной обойме на древке, расплав переливается через край."""
    v = W()
    collar(v, -17, -15, 1.9, IR2, SL)
    for y in range(-14, 13):
        c = IR2 if y % 2 else SL
        if -10 <= y <= -2: c = LE2 if y % 2 else LE1
        v.box(0, 1, y, y, 0, 1, c)
    cy0, cy1 = 15, 28
    for y in range(cy0, cy1 + 1):
        t = (y - cy0) / (cy1 - cy0)
        r = 4.5 + 2.6 * math.sin(t * math.pi * 0.8)
        v.disc_xz(0.5, 0, 0.5, r, y, y, lambda x, yy, z: CLY2 if nz(x, yy, z, 2, 41) > 0.35 else CLY1)
    v.disc_xz(0.5, 0, 0.5, 6.6, cy1 + 1, cy1 + 1, IR2)        # край
    for y in (18, 24):                                          # обойма
        v.disc_xz(0.5, 0, 0.5, 7.2, y, y, SL2)
    for s in (-1, 1):                                           # дужка-коромысло
        v.box(s * 7 + (1 if s > 0 else 0), s * 7 + (1 if s > 0 else 0), 14, 26, 0, 1, SL)
    v.carve(lambda x, y, z: y == cy1 + 1 and math.hypot(x - 0.5, z - 0.5) < 5.2, ((-8, cy1, -8), (9, cy1 + 2, 9)))
    speckle(v, 441, 0.16, (SG1, DK), cy0, cy1 + 1, only={CLY1, CLY2}, cell=2)
    outline(v)
    v.disc_xz(0.5, 0, 0.5, 5.2, cy1, cy1, lambda x, y, z: NW if math.hypot(x - 0.5, z - 0.5) < 2.2 else NY)   # зеркало расплава
    for (x, z, n) in [(-6, 0, 7), (6, 1, 5), (0, -6, 6), (2, 7, 4)]:   # подтёки
        for k in range(n):
            put(v, x, cy1 - k, z, NO if k < n - 1 else NY)
    motes(v, [(-4, 34, 0), (5, 36, 1), (0, 39, 0), (-10, 26, 1), (11, 22, 0)], NO, NY)
    return v


def searing_blade():
    """Раскалённый клинок: широкий, остывший у гарды и всё горячее к острию, кромки светятся."""
    v = W()
    collar(v, -13, -12, 1.7, IR2, SL)
    shaft(v, -11, -1, LE2, LE1, band=BZ2, every=3)
    v.box(-4, 5, 0, 1, -2, 3, IR2); v.box(-5, -5, 0, 2, -1, 2, SL); v.box(6, 6, 0, 2, -1, 2, SL)
    def prof(t):
        w = 3.3 if t < 0.8 else 3.3 * (1 - (t - 0.8) / 0.2) + 0.2
        return (0.5, w, w)
    def heat(x, y, t):
        return IR2 if t < 0.25 else (SL if t < 0.45 else SG3)
    blade(v, 2, 34, prof, dict(back=heat, mid=heat, ridge=heat, light=SL3, edge=SLH),
          thick=lambda t, k: 3 if k >= 2 else (2 if k == 1 else 1))
    outline(v); bevel(v)
    for y in range(12, 35):                                     # жар от середины к острию
        t = (y - 2) / 32; w = 3.3 if t < 0.8 else 3.3 * (1 - (t - 0.8) / 0.2) + 0.2
        for x in range(int(round(0.5 - w)) + 1, int(round(0.5 + w))):
            if t > 0.6 or (abs(x - 0.5) < 1.2 and t > 0.35):
                for z in (-1, 2):
                    if (x, y, z) in v.v or t > 0.6:
                        put(v, x, y, z if t < 0.85 else (0 if z < 0 else 1), NW if t > 0.82 else (NY if t > 0.6 else NO))
        put(v, int(round(0.5 + w)), y, 0, NO if t < 0.7 else NY)
    motes(v, [(-7, 28, 0), (8, 33, 1), (-5, 38, 0), (6, 40, 1), (9, 20, 0), (-8, 15, 1)], NO, NY)
    return v


# ======================= ЛЕГЕНДАРНОЕ =======================
def anvil_hammer():
    """Наковальня: боёк — тяжёлая наковальня (рог, лицо, пятка) в бронзовых обручах; сквозь трещины в боках
    светится расплав, на лице — раскалённая добела заготовка, с рога и пятки стекают капли, в центре — сердце-самоцвет."""
    v = W()
    for y in range(-18, -14):
        v.disc_xz(0.5, 0, 0.5, 1.2 + (y + 18) * 0.3, y, y, BZ3 if y % 2 else BZ2)
    for y in range(-14, 15):
        c = SL if y % 2 else IR2
        if -10 <= y <= -2: c = LE2 if y % 2 else LE1
        v.box(0, 1, y, y, 0, 1, c)
    for y in (1, 6, 11): collar(v, y, y, 1.6, BZ3)
    Y0, Y1 = 15, 34
    for y in range(Y0, Y1 + 1):
        if y <= 21:                                                   # подставка с талией
            half_x = 7.0 - (y - Y0) * 0.65; half_z = 4.6 - (y - Y0) * 0.3
        else:
            half_x = 9.5; half_z = 5.0
        for x in range(int(-half_x), int(half_x) + 2):
            for z in range(int(-half_z), int(half_z) + 2):
                c = IR2 if y < Y1 - 3 else (SL2 if y < Y1 else SL3)
                if nz(x, y, z, 2, 51) < 0.2 and y < Y1 - 1: c = SL
                v.v[(x, y, z)] = c
    for i in range(14):                                               # рог
        x = 11 + i; r = 3.8 * (1 - i / 14) + 0.4; yc = Y1 - 3.5 + i * 0.15
        for y in range(int(yc - r), int(yc + r) + 1):
            for z in range(int(-r), int(r) + 2):
                if math.hypot(y - yc, z - 0.5) <= r: v.v[(x, y, z)] = SL2 if y < yc + r - 1 else SL3
    v.box(-13, -9, Y1 - 6, Y1, -4, 5, IR2); v.box(-13, -9, Y1, Y1, -4, 5, SL3)   # пятка
    v.carve(lambda x, y, z: x in (-10, -11) and y in (Y1 - 2, Y1 - 1) and z in (0, 1))
    for y in (Y1 - 9, Y1 - 4):                                        # бронзовые обручи
        for x in range(-10, 12):
            for z in (-6, 6):
                if (x, y, z - (1 if z > 0 else -1)) in v.v: put(v, x, y, z, BZ3 if x % 3 else BZ2)
    outline(v)
    cracks = []                                                       # трещины расплава на обеих гранях
    for x in range(-9, 11):
        y = int(round(Y1 - 7 + 2.2 * math.sin(x * 0.55) + (1 if nz(x, 0, 0, 2, 52) > 0.6 else 0)))
        cracks.append((x, y))
        if x % 4 == 0:
            for k in range(1, 3): cracks.append((x + (k if x > 0 else -k) // 2, y - k))
    zf = {}
    for (x, y, z) in v.v: zf.setdefault((x, y), []).append(z)
    for (x, y) in cracks:
        zs = zf.get((x, y))
        if zs and max(zs) >= 4:
            v.v[(x, y, max(zs))] = NO; v.v[(x, y, min(zs))] = NO
    v.box(-8, 10, Y1 + 1, Y1 + 1, -2, 3, NY)                          # раскалённая заготовка
    v.box(-6, 8, Y1 + 1, Y1 + 1, 0, 1, NW)
    v.box(-3, 5, Y1 + 2, Y1 + 2, 0, 1, NW)
    for (x, n) in [(22, 3), (18, 4), (-12, 4), (-10, 3), (4, 3)]:     # капли расплава
        ybot = min(k[1] for k in v.v if k[0] == x) if any(k[0] == x for k in v.v) else Y0
        for k in range(1, n + 1): put(v, x, ybot - k, 0, NO if k < n else NY)
    for s in (-1, 1):                                                 # сердце-самоцвет на гранях
        for x in range(-2, 4):
            for y in range(Y1 - 8, Y1 - 3):
                d = math.hypot(x - 0.5, y - (Y1 - 5.5))
                if d <= 2.6:
                    zz = 6 if s > 0 else -5
                    put(v, x, y, zz, BZ3 if d > 1.7 else (NW if d < 0.9 else NY))
                    if d <= 1.7: put(v, x, y, zz + s, NY)
    return v


def forge_heart_blade():
    """Клинок горна: широкий фламберг с жилой расплава во всю длину и огненными кромками; в гарде — клетка
    с раскалённым сердцем, по бокам — языки пламени; навершие — уголь в бронзе."""
    v = W()
    ellipsoid(v, 0.5, -13.5, 0.5, 2.3, 2.0, 2.3, lambda x, y, z: BZ2 if y > -14 else BZ1)
    shaft(v, -11, -2, LE2, LE1, band=BZ3, every=3)
    cy = 1
    for a in range(0, 360, 24):                                       # клетка сердца
        r = math.radians(a)
        for y in range(cy - 4, cy + 5):
            rr = 5.0 * math.cos((y - cy) / 5.2 * math.pi / 2)
            put(v, round(0.5 + math.cos(r) * rr - 0.5), y, round(0.5 + math.sin(r) * rr - 0.5), BZ3 if a % 48 == 0 else BZ1)
    for s in (-1, 1):                                                 # языки пламени по бокам гарды
        for (dx, h) in ((5, 7), (7, 10), (9, 6)):
            x0 = 0.5 + s * dx
            pts = [(x0, cy), (x0 + s * 1.5, cy + h * 0.5), (x0 + s * 0.5, cy + h)]
            branch(v, pts, BZ2, tip=BZ3, t=2)
    y0, y1 = 7, 48
    def prof(t):
        w = (3.4 + 1.0 * math.sin(t * math.pi * 6)) * (1 if t < 0.82 else (1 - (t - 0.82) / 0.18)) + 0.25
        return (0.5, w, w)
    blade(v, y0, y1, prof, dict(back=IR2, mid=SL, ridge=SL2, light=SL3, edge=SLH), thick=lambda t, k: 3 if k >= 2 else (2 if k == 1 else 1))
    v.box(-1, 2, 5, 6, -1, 2, BZ2)
    outline(v); bevel(v)
    ellipsoid(v, 0.5, cy, 0.5, 3.0, 3.2, 3.0, lambda x, y, z: NW if abs(x - 0.5) + abs(z - 0.5) < 2.4 and abs(y - cy) < 2 else NO)
    core, edges = [], []
    for y in range(y0 + 1, y1):
        t = (y - y0) / (y1 - y0); _, w, _ = prof(t)
        cw = max(0.6, w * 0.38)
        for x in range(int(round(0.5 - cw)), int(round(0.5 + cw)) + 1): core.append((x, y))
        edges += [(int(round(0.5 + w)), y), (int(round(0.5 - w)), y)]
    inlay(v, core, lambda x, y: NW if (abs(x - 0.5) < 0.6 and y % 5 == 0) else (NY if abs(x - 0.5) < 1 else NO))
    for (x, y) in edges:
        for z in range(-1, 2):
            if (x, y, z) in v.v: v.v[(x, y, z)] = NO if y % 3 else NY
    for s in (-1, 1):                                                 # кончики пламени светятся
        for (dx, h) in ((5, 7), (7, 10), (9, 6)):
            x0 = int(round(0.5 + s * dx + s * 0.5 - 0.5)); inlay(v, [(x0, cy + h), (x0, cy + h - 1)], NY)
    gem(v, 0.5, -13.5, 1.4, NY, BZ3, depth=1, zlo=-2, zhi=3)
    return v


def slag_scythe():
    """Шлаковая коса: длинное древко с двумя ручками; огромное полотно из застывшего шлака с сеткой раскалённых
    трещин, по обуху — шипы окалины, с кромки свисают капли расплава, в пятке — тлеющее ядро."""
    v = W()
    collar(v, -15, -14, 1.7, IR2, SL)
    for y in range(-13, 46):
        c = WD2 if y % 2 else WD1
        if (y // 3) % 5 == 0: c = SG2
        v.box(0, 1, y, y, 0, 1, c)
    for (yh, s) in ((-2, 1), (21, -1)):
        for k in range(1, 5):
            v.box(s * k + (1 if s > 0 else 0), s * k + (1 if s > 0 else 0), yh, yh + 1, 0, 1, WD3 if k < 4 else SG3)
    collar(v, 40, 42, 1.9, IR2, SL2)
    v.box(-2, 3, 43, 48, -2, 3, IR2)                                  # пятка-обойма
    L = 32
    def edge(i):
        t = i / L
        return 51 - (t ** 1.6) * 18, 9.0 * (1 - t ** 1.25) + 0.8
    for i in range(L + 1):
        t = i / L; x = -2 - i
        top, width = edge(i); bot = top - width
        for y in range(int(math.floor(bot)), int(math.ceil(top)) + 1):
            k = (y - bot) / max(0.5, width)
            if k < 0.15: c = SLH if t > 0.08 else SL3
            elif k < 0.3: c = SL2
            else: c = SG2 if nz(x, y, 0, 2, 61) > 0.4 else (SG1 if nz(x, y, 1, 1, 62) > 0.5 else SG3)
            tz = 4 if k > 0.45 and t < 0.6 else (3 if k > 0.25 and t < 0.8 else (2 if k > 0.1 else 1))
            v.col(x, y, tz, c)
        if i % 4 == 1 and t < 0.85:                                   # шипы окалины по обуху
            for kk in range(1, 4 - int(t * 2)): v.col(x + (kk // 2), int(math.ceil(top)) + kk, 1, SG3 if kk < 3 else SL)
    outline(v); bevel(v)
    cracks = []
    for i in range(1, L - 1):
        top, width = edge(i); x = -2 - i
        for (ph, amp, base) in ((0.0, 0.12, 0.55), (2.1, 0.1, 0.78)):
            y = int(round(top - width * (base + amp * math.sin(i * 0.8 + ph))))
            if (i + int(ph)) % 7 != 6: cracks.append((x, y))
        if i % 5 == 2:
            yb = int(round(top - width * 0.55))
            for k in range(1, int(width * 0.3)): cracks.append((x + (k % 2), yb + k))
    inlay(v, cracks, lambda x, y: NY if (x + y) % 5 == 0 else NO)
    for i in (5, 11, 17, 23):                                         # капли с кромки
        top, width = edge(i); x = -2 - i; yb = int(math.floor(top - width))
        for k in range(1, 4): put(v, x, yb - k, 0, NO if k < 3 else NY)
    gem(v, 0.5, 45.5, 2.4, NW, SL2, mid=NY, depth=1, zlo=-2, zhi=3)
    return v


def unfinished_blade():
    """Незавершённая отливка: массивная литейная форма на болтах сжимает основание клинка, по шву течёт
    расплав, литники-воронки на гарде, в навершии — кристалл памяти. Клинок «доливается» в бою: ступени STAGE —
    неоновые объекты (G2–G4), клиент показывает их по атрибуту CastStage."""
    v = W()
    ellipsoid(v, 0.5, -13.5, 0.5, 2.3, 2.0, 2.3, lambda x, y, z: SL if y < -13 else IR2)
    for y in range(-19, -14):                                         # кристалл памяти (неон G1)
        r = 1.6 * (1 - abs(y + 16.5) / 3.0) + 0.3
        v.disc_xz(0.5, 0, 0.5, r, y, y, '!' + MEM)
    shaft(v, -11, -1, LE2, LE1, band=SL2, every=4)
    for x in range(-7, 9):                                            # гарда — половинки формы
        v.col(x, 0, 4 if abs(x - 0.5) < 5 else 3, SG2 if abs(x - 0.5) > 4 else IR2); v.col(x, 1, 3, SG1)
    for s in (-1, 1):                                                 # литники-воронки
        xc = 0.5 + s * 6.5
        for y in range(2, 7):
            v.disc_xz(xc, 0, 0.5, 0.8 + (y - 2) * 0.35, y, y, SG3 if y < 6 else SL2)
    def prof(t):
        return (0.5, 3.4, 3.4)
    blade(v, 2, 19, prof, dict(back=IR1, mid=SL, ridge=SL, light=SL2, edge=SL3), thick=lambda t, k: 3 if k >= 2 else 2)
    for y in range(3, 20):                                            # литейная форма (половинки на болтах)
        for x in (-4, -5, 5, 6):
            for z in range(-2, 4): put(v, x, y, z, IR2 if y % 4 else SL2)
        for x in range(-4, 6):
            put(v, x, y, -2, IR1 if (x + y) % 5 else SG3); put(v, x, y, 3, IR1 if (x + y) % 5 else SG3)
    for y in (5, 10, 15):
        for x in (-5, 6):
            put(v, x, y, -3, BZ3); put(v, x, y, 4, BZ3)
    speckle(v, 471, 0.22, (SG1, DK), 2, 19, only={SL, SL2, IR1}, cell=2)
    outline(v); bevel(v)
    for y in range(3, 20):                                            # шов расплава вдоль формы
        put(v, 0, y, -2, NCORE); put(v, 1, y, 3, NCORE)
        if y % 3 == 0: put(v, -1, y, -2, NCORE); put(v, 2, y, 3, NCORE)
    v.box(-3, 4, 20, 20, -1, 2, NCORE)                                # зеркало расплава у края формы
    for s in (-1, 1): put(v, int(0.5 + s * 6.5 - (0.5 if s > 0 else -0.5)), 6, 0, NW)
    veins = []
    for y in range(4, 19):                                            # трещины памяти на форме
        x = int(round(0.5 + 2.6 * math.sin(y * 0.7)))
        if y % 5 != 4: veins.append((x, y))
    for (x, y) in veins:
        for z in (-2, 3):
            if (x, y, z) in v.v and not v.v[(x, y, z)].startswith('!'): v.v[(x, y, z)] = '!' + MEM
    seg = [(21, 28), (29, 37), (38, 48)]
    for si, (ya, yb) in enumerate(seg):
        for y in range(ya, yb + 1):
            t = (y - 21) / 27
            w = 3.6 * (1 - t ** 2.0) + 0.25 + (0.7 if (y % 4 == 0 and t < 0.8) else 0)
            for x in range(int(round(0.5 - w)), int(round(0.5 + w)) + 1):
                d = abs(x - 0.5)
                tz = 3 if d < w - 1.2 else (2 if d < w - 0.4 else 1)
                for z in v.zs(tz): put(v, x, y, z, STAGE[si])
    return v


WEAPONS = [
    ('cast_cleaver', cast_cleaver, 'common'),
    ('quench_blade', quench_blade, 'rare'),
    ('apprentice_hammer', apprentice_hammer, 'rare'),
    ('crucible_maul', crucible_maul, 'epic'),
    ('searing_blade', searing_blade, 'epic'),
    ('anvil_hammer', anvil_hammer, 'legendary'),
    ('forge_heart_blade', forge_heart_blade, 'legendary'),
    ('slag_scythe', slag_scythe, 'legendary'),
    ('unfinished_blade', unfinished_blade, 'secret'),
]

SPEC = {
    'cast_cleaver': (1.0, -6),
    'quench_blade': (0.86, -6),
    'apprentice_hammer': (0.9, -5),
    'crucible_maul': (0.82, -5),
    'searing_blade': (0.82, -6),
    'anvil_hammer': (0.84, -5),
    'forge_heart_blade': (0.84, -6),
    'slag_scythe': (0.82, -4),
    'unfinished_blade': (0.88, -6),
}
GUARD = {'crucible_maul': 14, 'anvil_hammer': 15, 'slag_scythe': 43, 'apprentice_hammer': 14, 'forge_heart_blade': 6,
         'unfinished_blade': 1}
