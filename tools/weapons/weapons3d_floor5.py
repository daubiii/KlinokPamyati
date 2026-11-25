"""Оружие этажа 5 «Архив Хроник» в объёмных вокселях (0,125 стада), формат weapons3d.py.
Палитра этажа: #1D1B3A (ночные чернила), #4A3F8F (фиолет переплёта), #8E7CE0 (лаванда), #B8E3FF (лёд).
Тема: книги, печати, перья, чернила и время — нож для бумаги, молот-фолиант, клинок-закладка, перо хрониста,
печать, песочные часы, чернильный клинок, коса забвения и секретный «Клинок Памяти» (единственный с #6FE3FF)."""
import math
from weapons3d import W, nz, outline, bevel, OUT
from weapons3d_common345 import shades, put, shaft, collar, ellipsoid, blade, motes, line, speckle, inlay, gem, branch

NT, VI, LV, IC = '#1D1B3A', '#4A3F8F', '#8E7CE0', '#B8E3FF'
NT2, VI2, LV2 = '#2A2650', '#5E52A8', '#A99AEA'
ST1, ST2, ST3, STH = '#3B3F5E', '#5D6488', '#8A91B4', '#C3C9E6'     # сталь с холодным отливом
PA1, PA2, PA3 = '#B9A983', '#D8CBA6', '#EFE6CC'                       # пергамент
LT1, LT2 = '#2E2448', '#45366A'                                       # кожа переплёта
BR1, BR2, BR3 = '#7A5A2A', '#A98242', '#D6B467'                       # латунь
BN1, BN2 = '#C8C0B0', '#E6E0D2'                                       # кость
WX1, WX2 = '#5A3C9A', '#7B5BC8'                                       # сургуч (фиолетовый)
GL1, GL2 = '#7FA6C8', '#A8CBE6'                                       # стекло
INK1, INK2 = '#14122A', '#232046'
MEM = '#6FE3FF'
NV, NL, NI, NW = '!#9B7BFF', '!#B49CFF', '!#B8E3FF', '!#F2F6FF'
NE = '!#7A68E6'                                                       # эхо-отпечаток      # неон: фиолет, лаванда, лёд, белый
NS = '!#FFD98A'                                                       # песок часов
NM, NM2 = '!#6FE3FF', '!#D6F8FF'                                      # память (только секретка)

shades({STH: ST3, ST3: ST2, ST2: ST1, ST1: NT, NT2: NT, NT: OUT, VI2: VI, VI: NT2, LV2: LV, LV: VI, IC: GL2,
        PA3: PA2, PA2: PA1, PA1: BR1, LT2: LT1, LT1: OUT, BR3: BR2, BR2: BR1, BR1: OUT, BN2: BN1, BN1: PA1,
        WX2: WX1, WX1: LT1, GL2: GL1, GL1: ST1, INK2: INK1, INK1: OUT})

STEEL = dict(back=ST1, mid=ST2, ridge=ST3, light=ST3, edge=STH)


# ======================= ОБЫЧНОЕ =======================
def paper_knife():
    """Нож для бумаги: тонкий узкий клинок с гравированной строкой, костяная рукоять с латунным колпачком."""
    v = W()
    ellipsoid(v, 0.5, -12, 0.5, 1.6, 1.3, 1.6, lambda x, y, z: BR2)
    shaft(v, -11, -1, BN2, BN1, band=BR2, every=5)
    v.box(-2, 3, 0, 1, 0, 1, BR2); v.box(-2, -2, 0, 2, 0, 1, BR3); v.box(3, 3, 0, 2, 0, 1, BR3)
    def prof(t):
        w = 1.6 if t < 0.7 else 1.6 * (1 - (t - 0.7) / 0.3) + 0.05
        return (0.5, w, w)
    blade(v, 2, 26, prof, dict(back=ST2, mid=ST2, ridge=ST3, light=ST3, edge=STH), thick=lambda t, k: 2 if t < 0.92 else 1)
    for y in range(4, 22, 3):
        put(v, 0, y, 1, ST1); put(v, 1, y + 1, 1, ST1)            # строка гравировки
    outline(v); bevel(v)
    return v


# ======================= РЕДКИЕ =======================
def tome_hammer():
    """Молот-фолиант: окованный толстый том на древке — кожаные крышки, обрез страниц, латунные уголки и застёжка."""
    v = W()
    collar(v, -16, -15, 1.6, BR1, BR2)
    for y in range(-14, 14):
        c = LT2 if y % 2 else LT1
        if (y + 14) % 6 == 0: c = BR2
        v.box(0, 1, y, y, 0, 1, c)
    x0, x1, y0, y1, z0, z1 = -6, 7, 14, 26, -3, 4
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            for z in range(z0, z1 + 1):
                cover = z in (z0, z1)
                spine = x == x0
                if cover or spine:
                    c = LT2 if nz(x, y, z, 2, 51) > 0.3 else LT1
                else:
                    c = PA3 if (y + z) % 2 else PA2
                    if x == x1 - 1 and y % 3 == 0: c = PA1
                put(v, x, y, z, c)
    for (cx, cy) in [(x1, y0), (x1, y1), (x0, y0), (x0, y1)]:       # уголки
        for z in (z0, z1):
            put(v, cx, cy, z, BR3); put(v, cx - (1 if cx == x1 else -1), cy, z, BR2); put(v, cx, cy + (1 if cy == y0 else -1), z, BR2)
    for x in range(x0, x1 + 2):                                      # застёжка
        put(v, x, 20, z1 + 1, BR2 if x < x1 else BR3); put(v, x, 20, z0 - 1, BR2)
    put(v, x1 + 1, 20, 0, BR3); put(v, x1 + 1, 20, 1, BR3); put(v, x1 + 1, 19, 1, BR2); put(v, x1 + 1, 21, 1, BR2)
    for y in range(y0 + 2, y1 - 1, 2):                               # бинты корешка
        put(v, x0 - 1, y, 0, BR1); put(v, x0 - 1, y, 1, BR1)
    for (x, y) in [(0, 17), (1, 17), (2, 18), (0, 23), (-1, 22), (2, 22), (3, 21)]:   # тиснение на крышке
        put(v, x, y, z1 + 1, BR2)
    outline(v); bevel(v)
    put(v, 1, 20, z1 + 1, NL)                                        # камень застёжки
    return v


def bookmark_blade():
    """Клинок-закладка: прямой меч с фиолетовой лентой-закладкой, свисающей с гарды, и латунной гардой-скрепкой."""
    v = W()
    ellipsoid(v, 0.5, -13, 0.5, 1.7, 1.4, 1.7, lambda x, y, z: BR2)
    shaft(v, -11, -1, LT2, LT1, band=BR2, every=3)
    for x in range(-4, 6):
        v.col(x, 0, 3, BR2 if abs(x - 0.5) < 4 else BR3); v.col(x, 1, 2, BR1)
    def prof(t):
        w = 2.2 if t < 0.82 else 2.2 * (1 - (t - 0.82) / 0.18) + 0.1
        return (0.5, w, w)
    blade(v, 2, 32, prof, STEEL, thick=lambda t, k: 3 if k >= 2 else (2 if k == 1 else 1))
    for y in range(3, 28):                                           # фуллер-строка
        put(v, 0, y, 2, VI if y % 4 else LV); put(v, 1, y, -1, VI if y % 4 else LV)
    # лента: от гарды вниз, волной вдоль рукояти, раздвоенный конец
    for i in range(0, 15):
        y = -i
        x = -4 + int(round(math.sin(i * 0.55) * 1.2))
        c = VI2 if i % 3 else VI
        put(v, x, y, 0, c); put(v, x - 1, y, 0, c); put(v, x, y, 1, c); put(v, x - 1, y, 1, c)
    put(v, -5 + int(round(math.sin(15 * 0.55) * 1.2)), -15, 0, VI); put(v, -2 + int(round(math.sin(15 * 0.55) * 1.2)) - 1, -15, 0, VI)
    outline(v); bevel(v)
    return v


# ======================= ЭПИЧЕСКИЕ =======================
def quill_blade():
    """Перо хрониста: клинок-перо — светлый стержень, опахало из зазубренных бородок, металлическое перо-острие с чернильной каплей."""
    v = W()
    ellipsoid(v, 0.5, -13, 0.5, 1.6, 1.4, 1.6, lambda x, y, z: BR2)
    shaft(v, -11, -1, NT2, NT, band=BR2, every=3)
    for x in range(-2, 4):
        v.col(x, 0, 2, BR2); v.col(x, 1, 2, BR1)
    put(v, -3, 1, 0, BR3); put(v, 4, 1, 1, BR3)
    y0, y1 = 2, 30
    for y in range(y0, y1 + 1):
        t = (y - y0) / (y1 - y0)
        w = 1.0 + 3.6 * math.sin(min(1.0, t * 1.15) * math.pi) ** 0.8
        lo, hi = int(round(0.5 - w)), int(round(0.5 + w))
        for x in range(lo, hi + 1):
            if x in (0, 1): continue
            edge = x in (lo, hi)
            notch = ((y + (x > 0)) % 4 == 0) and edge                 # зазубрины между бородками
            if notch: continue
            d = abs(x - 0.5) / max(1, w)
            c = LV2 if d > 0.75 else (LV if d > 0.4 else VI2)
            if (y - abs(x) // 2) % 3 == 0 and not edge: c = VI      # бородки наискось
            v.col(x, y, 2 if d < 0.6 else 1, c)
    for y in range(y0, y1 + 1):                                        # стержень
        put(v, 0, y, 0, IC); put(v, 1, y, 0, IC); put(v, 0, y, 1, GL2); put(v, 1, y, 1, IC)
    for y in range(y1 + 1, y1 + 7):                                    # перо-наконечник
        w = 1.6 * (1 - (y - y1 - 1) / 6) + 0.2
        for x in range(int(round(0.5 - w)), int(round(0.5 + w)) + 1):
            v.col(x, y, 2 if abs(x - 0.5) < w - 0.6 else 1, BR3 if x > 0 else BR2)
    outline(v); bevel(v)
    for y in range(y1 + 1, y1 + 6): put(v, 0, y, 2, NV); put(v, 1, y, -1, NV)        # прорезь пера
    for y in range(5, y1, 6):
        put(v, 0, y, 1, NV); put(v, 1, y, 0, NV)                                    # строка по стержню
    put(v, 0, y1 + 8, 0, NV); put(v, 0, y1 + 9, 0, NL)                                # капля чернил
    motes(v, [(-7, 18, 0), (8, 24, 1), (-5, 33, 0), (6, 12, 1)], NL)
    return v


def seal_hammer():
    """Печать: латунный штемпель-цилиндр поперёк древка — на ударной стороне светится оттиск-руна, капли сургуча."""
    v = W()
    collar(v, -16, -15, 1.6, BR1, BR2)
    for y in range(-14, 15):
        c = NT2 if y % 2 else NT
        if -9 <= y <= -3: c = LT2 if y % 2 else LT1
        v.box(0, 1, y, y, 0, 1, c)
    cy, cz, R = 19.5, 0.5, 4.2
    for x in range(-7, 9):
        r = R if x > -4 else R - 1.2 - (0.6 if x < -6 else 0)
        for y in range(int(cy - R) - 1, int(cy + R) + 2):
            for z in range(int(cz - R) - 1, int(cz + R) + 2):
                if math.hypot(y - cy, z - cz) <= r:
                    c = BR2 if nz(x, y, z, 2, 61) > 0.3 else BR1
                    if x in (-3, 2, 3): c = BR3 if x != 2 else BR1     # кольца штемпеля
                    if x == 8: c = WX2 if math.hypot(y - cy, z - cz) > R - 1.2 else WX1   # сургуч на лице
                    put(v, x, y, z, c)
    ellipsoid(v, -8.5, cy, cz, 1.6, 2.2, 2.2, lambda x, y, z: BR3)       # головка-набалдашник
    for (y, z, n) in [(16, 3, 2), (23, -2, 3), (17, -2, 1)]:              # подтёки сургуча
        for k in range(n): put(v, 9, y - k, z, WX1)
    outline(v); bevel(v)
    # оттиск-руна на ударной стороне: кольцо + «песочные часы»
    for y in range(int(cy - R), int(cy + R) + 1):
        for z in range(int(cz - R), int(cz + R) + 1):
            d = math.hypot(y - cy, z - cz)
            if 2.4 <= d <= 3.0: put(v, 9, y, z, NV)
    for k in range(-2, 3):
        put(v, 9, int(round(cy + k)), int(round(cz + abs(k) * 0.8 - 0.5)), NL)
        put(v, 9, int(round(cy + k)), int(round(cz - abs(k) * 0.8 + 0.5)), NL)
    motes(v, [(11, 24, 0), (12, 15, 1), (-11, 22, 0)], NL)
    return v


# ======================= ЛЕГЕНДАРНЫЕ =======================
def hourglass_maul():
    """Молот Песочных часов: боёк — песочные часы, лёгшие поперёк рукояти: латунные плиты-бойки с рунным кольцом,
    стеклянные колбы в рёбрах, светящийся песок пересыпается через талию; вокруг талии — кольцо циферблата."""
    v = W()
    collar(v, -15, -13, 1.9, BR1, BR2)
    for y in range(-12, 13):
        c = NT2 if y % 2 else NT
        if (y + 12) % 5 == 0: c = BR2
        v.box(0, 1, y, y, 0, 1, c)
    collar(v, 11, 13, 1.7, BR2, BR3)
    yc, zc = 20.5, 0.5
    def radius(u):                                                    # профиль колбы вдоль X
        if u < 1.5: return 1.2
        if u < 9.5: return 1.2 + 4.2 * math.sin(min(1.0, (u - 1.5) / 7.0) * math.pi * 0.75) ** 1.2
        return 3.6
    for x in range(-11, 13):
        u = abs(x - 0.5)
        if u > 10.5: continue
        r = radius(u)
        for y in range(int(yc - r) - 1, int(yc + r) + 2):
            for z in range(int(zc - r) - 1, int(zc + r) + 2):
                d = math.hypot(y - yc, z - zc)
                if r - 1.0 < d <= r:
                    a = math.atan2(z - zc, y - yc)
                    rib = (a * 6 / (2 * math.pi)) % 1.0 < 0.24
                    rim = u < 2.0 or u > 9.0
                    if rib or rim: put(v, x, y, z, GL2 if (x + y) % 4 else IC)
    for s in (-1, 1):                                                 # плиты-бойки
        for xx in ((11, 12, 13) if s > 0 else (-10, -11, -12)):
            outer = abs(xx - 0.5) > 11.6
            for y in range(int(yc - 7) - 1, int(yc + 7) + 2):
                for z in range(int(zc - 7) - 1, int(zc + 7) + 2):
                    d = math.hypot(y - yc, z - zc)
                    if d <= (6.0 if outer else 7.0): put(v, xx, y, z, BR3 if (outer and d < 4.5) else (BR2 if (y + z) % 3 else BR1))
        for (dy, dz) in ((-5, -5), (5, -5), (-5, 5), (5, 5)):         # колонны между плитами
            for x in range(-9, 11): put(v, x, int(yc + dy), int(zc + dz), NT2 if x % 3 else BR2)
    for y in range(int(yc - 1), int(yc + 2)):                         # талия
        for z in range(-1, 3): put(v, 0, y, z, BR2); put(v, 1, y, z, BR2)
    for y in range(13, int(yc - 1)): v.box(0, 1, y, y, 0, 1, BR2)     # шейка к рукояти
    for a in range(0, 360, 6):                                        # кольцо циферблата вокруг талии (плоскость YZ)
        r = math.radians(a)
        y = int(round(yc + math.cos(r) * 8.2)); z = int(round(zc + math.sin(r) * 8.2))
        for x in (0, 1): put(v, x, y, z, NV if a % 30 else BR3)      # светящееся кольцо, латунные метки часов
    outline(v, cond=lambda i, j, k: v.v[(i, j, k)] not in (GL1, GL2, IC)); bevel(v)
    for s in (-1, 1):                                                 # песок: горка в одной колбе, остаток в другой
        for x in range(-9, 11):
            u = abs(x - 0.5)
            if u < 1.5 or (x - 0.5) * s < 0: continue
            r = radius(u) - 1.0
            fill = 0.75 if s > 0 else 0.3
            for y in range(int(yc - r), int(yc + r) + 1):
                for z in range(int(zc - r), int(zc + r) + 1):
                    if math.hypot(y - yc, z - zc) <= r and (y - (yc - r)) <= 2 * r * fill:
                        put(v, x, y, z, NS)
    for x in range(-1, 3): put(v, x, int(yc), 0, NS); put(v, x, int(yc), 1, NS)   # струйка через талию
    for a in range(0, 360, 4):                                        # сплошной рунный круг в лицевой грани торцевых плит
        r = math.radians(a)
        y2 = int(round(yc + math.cos(r) * 4.6)); z2 = int(round(zc + math.sin(r) * 4.6))
        xs = [k[0] for k in v.v if k[1] == y2 and k[2] == z2]
        if xs: v.v[(min(xs), y2, z2)] = NL; v.v[(max(xs), y2, z2)] = NL
    xs = [k[0] for k in v.v if k[1] == int(yc) and k[2] == 0]
    if xs: v.v[(min(xs), int(yc), 0)] = NW; v.v[(max(xs), int(yc), 0)] = NW
    return v


def ink_blade():
    """Чернильный клинок: широкий, будто налитый чернилами клинок с фиолетовыми прожилками и неоновыми кромками;
    с обуха срываются чернильные языки, гарда — клякса с потёками, навершие — чернильница со светящимися чернилами."""
    v = W()
    ellipsoid(v, 0.5, -13.5, 0.5, 2.0, 1.8, 2.0, lambda x, y, z: GL2 if y > -14 else GL1)
    shaft(v, -11, -1, NT2, INK1, band=VI, every=3)
    ellipsoid(v, 0.5, 0.5, 0.5, 6.0, 2.0, 2.6, lambda x, y, z: INK2 if nz(x, y, z, 1, 71) > 0.3 else INK1, rough=0.6, seed=72)
    y0, y1 = 2, 46
    def prof(t):
        w = 3.5 if t < 0.74 else 3.5 * (1 - (t - 0.74) / 0.26) ** 0.9 + 0.1
        return (0.4 + 1.2 * math.sin(t * math.pi * 1.5) * 0.5, w, w)
    def body(x, y, t):
        return INK2 if nz(x, y, 0, 2, 73) > 0.45 else INK1
    blade(v, y0, y1, prof, dict(back=INK1, mid=body, ridge=NT2, light=NT2, edge=VI), thick=lambda t, k: 3 if k >= 2 else (2 if k == 1 else 1))
    tongues = []
    for y in range(6, 40, 6):                                         # чернильные языки с обуха
        t = (y - y0) / (y1 - y0); off, w, _ = prof(t)
        xb = int(round(off - w))
        pts = [(xb, y), (xb - 2.5, y + 2.5), (xb - 3.5, y + 5.5)]
        branch(v, pts, INK2, t=2); tongues.append(pts[-1])
    for (x, n) in [(-4, 5), (5, 4), (-1, 3), (3, 6)]:                 # потёки с кляксы
        for k in range(n): v.col(x, -2 - k, 1, INK2)
    outline(v); bevel(v)
    veins, edges = [], []
    for y in range(3, y1):
        t = (y - y0) / (y1 - y0); off, w, _ = prof(t)
        for (ph, f) in ((0.0, 0.45), (1.7, -0.45)):
            x = int(round(off + w * f * math.sin(y * 0.35 + ph)))
            veins.append((x, y))
        edges.append((int(round(off + w)), y)); edges.append((int(round(off - w)), y))
    inlay(v, veins, lambda x, y: NL if y % 6 == 0 else NV)
    for i, (x, y) in enumerate(edges):                                # сплошные кромки: лезвие белое, обух лавандовый
        for z in range(-1, 2):
            if (x, y, z) in v.v: v.v[(x, y, z)] = NW if i % 2 == 0 else NL
    v.disc_xz(0.5, 0, 0.5, 1.2, -14, -13, NV)                         # чернила в чернильнице
    return v


def oblivion_scythe():
    """Коса Забвения: тёмное древко с латунными кольцами и лентами-закладками, у пятки — раскрытый фолиант
    со светящимися страницами; огромное бледное полотно с ледяной кромкой и рунами растворяется к острию."""
    v = W()
    collar(v, -15, -14, 1.7, BR1, BR2)
    for y in range(-13, 46):
        c = NT2 if y % 2 else NT
        if (y // 3) % 5 == 0: c = VI
        v.box(0, 1, y, y, 0, 1, c)
    for (yh, s) in ((-2, 1), (21, -1)):
        for k in range(1, 5):
            v.box(s * k + (1 if s > 0 else 0), s * k + (1 if s > 0 else 0), yh, yh + 1, 0, 1, LT2 if k < 4 else BR2)
    collar(v, 40, 42, 1.9, BR2, BR3)
    v.box(-1, 2, 43, 48, -1, 2, BR2)
    for x in range(2, 10):                                            # раскрытый фолиант над пяткой (к +X)
        for y in range(44, 52):
            for z in range(-2, 4):
                spine = x == 2
                cover = z in (-2, 3)
                if cover and (x + y) % 9 == 0: continue
                put(v, x, y, z, LT2 if (cover or spine) else (PA3 if (y + z) % 2 else PA2))
    for s in (-1, 1):                                                 # ленты-закладки
        for i in range(10): put(v, (2 if s > 0 else -1), 40 - i, s * (1 + i // 5), VI2 if i < 8 else LV2)
    L = 34
    gone = set()
    def edge(i):
        t = i / L
        return 51 - (t ** 1.6) * 19, 9.5 * (1 - t ** 1.25) + 0.8
    for i in range(L + 1):
        t = i / L; x = -1 - i
        top, width = edge(i); bot = top - width
        for y in range(int(math.floor(bot)), int(math.ceil(top)) + 1):
            k = (y - bot) / max(0.5, width)
            if t > 0.62 and nz(x, y, 0, 1, 81) < (t - 0.62) * 1.5:
                gone.add((x, y)); continue
            if k < 0.16: c = STH
            elif k < 0.32: c = IC
            else: c = LV2 if nz(x, y, 0, 2, 82) > 0.45 else LV
            tz = 4 if k > 0.45 and t < 0.55 else (3 if k > 0.25 and t < 0.8 else (2 if k > 0.1 else 1))
            v.col(x, y, tz, c)
    outline(v); bevel(v)
    edgec, runes = [], []
    for i in range(1, L - 1):
        top, width = edge(i); x = -1 - i
        y = int(math.floor(top - width))
        if (x, y) not in gone: edgec += [(x, y), (x, y + 1)]
        if i % 3 != 2:
            yr = int(round(top - width * 0.6))
            if (x, yr) not in gone: runes.append((x, yr))
    inlay(v, edgec, NI)
    inlay(v, runes, lambda x, y: NW if x % 6 == 0 else NV)
    for x in range(3, 10):                                            # страницы светятся
        for y in range(45, 51):
            if (x + y) % 3: put(v, x, y, 0, NL); put(v, x, y, 1, NL)
    return v


def memory_blade():
    """Клинок Памяти: кристаллический двуручник с широкой сердцевиной памяти; за гардой — кольцо циферблата
    со светящимися делениями и стрелками, из кромок прорастают кристаллы-осколки, в навершии — кристалл."""
    v = W()
    for y in range(-19, -13):                                         # кристалл-навершие
        r = 1.9 * (1 - abs(y + 16) / 3.4) + 0.3
        v.disc_xz(0.5, 0, 0.5, r, y, y, GL2 if y % 2 else IC)
    shaft(v, -12, -1, NT2, NT, band=LV, every=3)
    for x in range(-9, 11):                                           # кольцо циферблата (плоскость XY)
        for y in range(-9, 12):
            d = math.hypot(x - 0.5, y - 1.5)
            if 7.6 <= d <= 9.2:
                v.col(x, y, 2, BR2 if (x + y) % 3 else BR3)
    for s in (-1, 1):                                                 # спицы к гарде
        for k in range(2, 8): v.col(int(round(0.5 + s * k - (0.5 if s > 0 else -0.5))), 1, 2, BR2)
    v.box(-2, 3, 0, 2, -1, 2, BR2)
    y0, y1 = 3, 50
    def prof(t):
        w = 3.6 if t < 0.78 else 3.6 * (1 - (t - 0.78) / 0.22) + 0.1
        return (0.5, w, w)
    def facet(x, y, t):
        return IC if (x * 2 + y) % 7 < 3 else (GL2 if (x + y) % 2 else LV2)
    blade(v, y0, y1, prof, dict(back=LV, mid=facet, ridge=IC, light=IC, edge='#E8F6FF'), thick=lambda t, k: 4 if k >= 3 else (3 if k >= 2 else (2 if k == 1 else 1)))
    shards = []
    for (y, s, ln) in ((10, 1, 4), (16, -1, 5), (23, 1, 5), (30, -1, 4), (37, 1, 4), (42, -1, 3)):
        t = (y - y0) / (y1 - y0); _, w, _ = prof(t)
        xb = int(round(0.5 + s * w))
        pts = [(xb, y), (xb + s * ln * 0.6, y + ln * 0.8), (xb + s * ln * 0.9, y + ln * 1.5)]
        branch(v, pts, GL2, tip=IC, t=2); shards.append(pts[-1])
    outline(v, cond=lambda i, j, k: v.v[(i, j, k)] not in (IC, GL2, LV2, '#E8F6FF')); bevel(v)
    core = []
    for y in range(y0 + 1, y1 - 2):
        t = (y - y0) / (y1 - y0); _, w, _ = prof(t)
        cw = max(0.6, w * 0.4)
        for x in range(int(round(0.5 - cw)), int(round(0.5 + cw)) + 1): core.append((x, y))
    inlay(v, core, lambda x, y: NM2 if (abs(x - 0.5) < 0.6 and y % 6 == 0) else NM)
    for (x, y) in shards: inlay(v, [(int(round(x)), int(round(y)))], NM2)
    for a in range(0, 360, 30):                                       # деления циферблата
        r = math.radians(a)
        x = int(round(0.5 + math.sin(r) * 8.4 - 0.5)); y = int(round(1.5 + math.cos(r) * 8.4))
        inlay(v, [(x, y)], NM if a % 90 else NM2)
    for k in range(2, 7): inlay(v, [(0 - k // 2, 1 + k)], NL)          # стрелки
    for k in range(2, 5): inlay(v, [(1 + k, 1 + k // 2)], NL)
    for y in range(-18, -14): put(v, 0, y, -1, NM); put(v, 1, y, 2, NM)
    return v


WEAPONS = [
    ('paper_knife', paper_knife, 'common'),
    ('tome_hammer', tome_hammer, 'rare'),
    ('bookmark_blade', bookmark_blade, 'rare'),
    ('quill_blade', quill_blade, 'epic'),
    ('seal_hammer', seal_hammer, 'epic'),
    ('hourglass_maul', hourglass_maul, 'legendary'),
    ('ink_blade', ink_blade, 'legendary'),
    ('oblivion_scythe', oblivion_scythe, 'legendary'),
    ('memory_blade', memory_blade, 'secret'),
]

SPEC = {
    'paper_knife': (1.0, -6),
    'tome_hammer': (0.86, -5),
    'bookmark_blade': (0.86, -6),
    'quill_blade': (0.84, -6),
    'seal_hammer': (0.84, -5),
    'hourglass_maul': (0.86, -5),
    'ink_blade': (0.84, -6),
    'oblivion_scythe': (0.82, -4),
    'memory_blade': (0.84, -6),
}
GUARD = {'tome_hammer': 14, 'seal_hammer': 15, 'hourglass_maul': 13, 'oblivion_scythe': 43, 'memory_blade': 2,
         'quill_blade': 1, 'ink_blade': 1}
