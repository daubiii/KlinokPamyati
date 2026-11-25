"""Оружие этажа 1 в объёмных вокселях (0,125 стада) по пиксельным рефам Артёма.
Оси: Y — вдоль клинка (рукоять в 0, клинок вверх), X — поперёк (плоскость клинка), Z — толщина.
Цвет '!#hex' — неон (отдельный объект Glow). Общий стиль: тёмный контур на рёбрах, светлая
фаска с одной стороны клинка (+X), ржавчина пятнами."""
import math
from vox import Vox

VS = 0.125

# --- палитра оружия (тёплая ржавчина этажа 1) ---
OUT = '#24160F'
WD, WM, WL = '#3B2618', '#5C3A22', '#7A4E2C'           # дерево рукояти
RD, RM, RL, RO = '#6B3418', '#A4521F', '#CF7A2F', '#E59A48'   # ржавчина
ID, IM, IL, IH = '#3E3833', '#6A6058', '#8E8378', '#B5A894'   # железо
BN, BH = '#CDB596', '#E3D2B2'                               # кромка / блик
BRD, BR, BRL = '#5E3C1E', '#8A5A2A', '#B87A36'              # бронза
GD, GM, GLt = '#9C6A1E', '#D9A03A', '#F0C766'               # золото
SD, SM, SL = '#3A2A1E', '#5A4330', '#7C6046'                # тёмная бронза/камень (эпик, лег)
GLOW, GLOW2 = '!#FFB536', '!#FFE39A'                        # неон

def nz(i, j, k, s=2, seed=0):
    h = (int(i // s) * 73856093) ^ (int(j // s) * 19349663) ^ (int(k // s) * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0

class W(Vox):
    def __init__(s):
        super().__init__(VS)
    def box(s, x0, x1, y0, y1, z0, z1, c):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for y in range(min(y0, y1), max(y0, y1) + 1):
                for z in range(min(z0, z1), max(z0, z1) + 1):
                    s.v[(x, y, z)] = c(x, y, z) if callable(c) else c
    def zs(s, t):
        """Слои толщины t (1,2,3,4,5…) вокруг z=0 (чётная толщина — со сдвигом)."""
        lo = -(t // 2) if t % 2 else -(t // 2) + 1
        return range(lo, lo + t)
    def col(s, x, y, t, c):
        for z in s.zs(t):
            s.v[(x, y, z)] = c(x, y, z) if callable(c) else c
    def disc_xy(s, cx, cy, r_out, r_in, t, c):
        for x in range(int(cx - r_out) - 1, int(cx + r_out) + 2):
            for y in range(int(cy - r_out) - 1, int(cy + r_out) + 2):
                d = math.hypot(x - cx, y - cy)
                if r_in <= d <= r_out:
                    s.col(x, y, t, c)
    def disc_xz(s, cx, cy, cz, r, y0, y1, c):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            for z in range(int(cz - r) - 1, int(cz + r) + 2):
                if math.hypot(x - cx, z - cz) <= r:
                    for y in range(y0, y1 + 1):
                        s.v[(x, y, z)] = c(x, y, z) if callable(c) else c

def outline(v, cond=None):
    """Тёмный контур по силуэтным рёбрам (как обводка пиксель-арта): воксель с пустотой по двум осям темнеет."""
    keys = list(v.v); new = {}
    for (i, j, k) in keys:
        c = v.v[(i, j, k)]
        if c.startswith('!') or (cond and not cond(i, j, k)): continue
        e = [(i + 1, j, k) not in v.v or (i - 1, j, k) not in v.v,
             (i, j + 1, k) not in v.v or (i, j - 1, k) not in v.v,
             (i, j, k + 1) not in v.v or (i, j, k - 1) not in v.v]
        if sum(e) >= 3: new[(i, j, k)] = OUT
    v.v.update(new)

DARKER = {BH: BN, BN: IH, IH: IL, IL: IM, IM: ID, ID: OUT, RO: RL, RL: RM, RM: RD, RD: OUT, WL: WM, WM: WD, WD: OUT,
          BRL: BR, BR: BRD, BRD: OUT, GLt: GM, GM: GD, GD: BRD, SL: SM, SM: SD, SD: OUT}
LIGHTER = {v: k for k, v in DARKER.items() if v != OUT}

def bevel(v):
    """Пиксельная фаска по толщине: передняя/задняя грань (±Z) как есть, боковые −X темнее, +X светлее."""
    new = {}
    for (i, j, k), c in v.v.items():
        if c.startswith('!') or c == OUT: continue
        if (i - 1, j, k) not in v.v and (i + 1, j, k) in v.v: new[(i, j, k)] = DARKER.get(c, c)
        elif (i + 1, j, k) not in v.v and (i - 1, j, k) in v.v: new[(i, j, k)] = LIGHTER.get(c, c)
    v.v.update(new)

def rust_spots(v, seed, amount, ymin=-999, ymax=999, only=None):
    for key in list(v.v):
        i, j, k = key; c = v.v[key]
        if c.startswith('!') or c == OUT or not (ymin <= j <= ymax): continue
        if only and c not in only: continue
        n = nz(i, j, k, 2, seed)
        if n < amount * 0.45: v.v[key] = RD
        elif n < amount: v.v[key] = RM if nz(i, j, k, 1, seed + 3) < 0.6 else RL

# ---------------- общие детали ----------------
def grip(v, y0, y1, wrap=(WM, WD), band=None, every=3, t=2, w=(0, 1)):
    """Рукоять 2×2 вокселя (0,25 стада), обмотка полосами."""
    for y in range(y0, y1 + 1):
        c = wrap[0] if (y % 2) else wrap[1]
        if band and (y - y0) % every == 0: c = band
        for x in range(w[0], w[1] + 1):
            for z in (0, 1)[:t]:
                v.v[(x, y, z)] = c

def sword_blade(v, y0, y1, half, tip, mid=IM, light=BN, dark=ID, ridge=IL, edge=BH, t_mid=3, seed=1,
                chisel=True):
    """Прямой клинок: ширина 2·half+2 (x от −half до half+1), дол по центру, блик на +X, чеканный срез острия."""
    xa, xb = -half, half + 1
    for y in range(y0, y1 + tip + 1):
        if y <= y1:
            lo, hi = xa, xb
        else:
            k = y - y1
            if chisel:     # косой срез: острие уходит к +X (как на рефе)
                lo, hi = xa + k * (xb - xa) // (tip + 1) + 1, xb
            else:
                lo, hi = xa + k, xb - k
            if lo > hi: continue
        for x in range(lo, hi + 1):
            if x == hi: c = edge
            elif x == hi - 1: c = light
            elif x == lo: c = dark
            elif x in (0, 1): c = ridge
            else: c = mid
            t = t_mid if x in (0, 1) else (t_mid - 1 if lo < x < hi else 1)
            if y > y1 and x < hi - 1: t = max(1, t - 1)
            v.col(x, y, max(t, 1), c)

def crossguard(v, y, half, t=3, c=IM, h=2):
    for x in range(-half, half + 2):
        for yy in range(y, y + h):
            v.col(x, yy, t, c)

def hammer_head(v, y0, y1, half_x, half_z, face=BN, body=ID, edge=IM, band=RM, band_w=2, seed=3):
    """Боёк: тело + светлые торцевые бойки по ±X (скошенные), бандаж посередине."""
    for x in range(-half_x, half_x + 2):
        for y in range(y0, y1 + 1):
            for z in range(-half_z, half_z + 1):
                ax = abs(x - 0.5) / (half_x + 0.5); ay = abs(y - (y0 + y1) / 2) / ((y1 - y0) / 2 + 0.5)
                az = abs(z) / (half_z + 0.5)
                # скос углов
                if ax > 0.82 and (ay > 0.78 or az > 0.78): continue
                if ay > 0.86 and az > 0.86: continue
                if ax > 0.9: c = face
                elif ax > 0.78: c = edge
                elif abs(x - 0.5) <= band_w: c = band
                else: c = body if nz(x, y, z, 2, seed) > 0.25 else IM
                v.v[(x, y, z)] = c

# ======================= ОБЫЧНОЕ =======================
def rusty_sword():
    v = W()
    v.disc_xz(0.5, 0, 0.5, 1.7, -12, -10, lambda x, y, z: RL if y == -10 else RM)      # навершие-шишка
    v.box(0, 1, -12, -12, 0, 1, RD)
    grip(v, -9, -1, band=RD, every=3)
    crossguard(v, 0, 5, t=3, c=IM)
    v.box(-5, -4, 0, 1, -1, 1, RM); v.box(5, 6, 0, 1, -1, 1, RM)                        # ржавые концы
    sword_blade(v, 2, 24, 3, 4, seed=1)
    rust_spots(v, 11, 0.36, 0, 29, only={IM, IL, ID})
    rust_spots(v, 12, 0.5, 0, 1)
    outline(v); bevel(v)
    return v

def iron_falchion():
    v = W()
    v.disc_xy(0.5, -14, 2.6, 1.2, 2, lambda x, y, z: RM if (x + y) % 3 else RL)        # кольцо-навершие
    v.box(0, 1, -13, -12, 0, 1, BR)
    v.col(0, -14, 2, RD); v.col(1, -14, 2, RD)
    grip(v, -11, -1, band=RD, every=4)
    # тонкая крестовина с шишками на концах
    for x in range(-6, 8):
        v.col(x, 0, 2, IM)
    v.box(-1, 2, -1, 1, -1, 1, RM)
    for x in (-7, 8):
        v.box(x, x, -1, 1, -1, 1, IL)
    sword_blade(v, 2, 30, 2, 5, mid=IM, light=BN, ridge=IL, seed=2)
    rust_spots(v, 21, 0.26, 2, 35, only={IM, IL})
    outline(v); bevel(v)
    return v

def forge_hammer():
    v = W()
    v.disc_xz(0.5, 0, 0.5, 1.8, -16, -14, lambda x, y, z: RL if y == -14 else RM)
    for y in range(-13, 15):
        c = WM if y % 2 else WL
        if y in (-13, -12, -9, -8, 12, 13): c = RM if y % 2 else RL
        v.box(0, 1, y, y, 0, 1, c)
    hammer_head(v, 15, 25, 8, 4, band=RM, band_w=2, seed=4)
    rust_spots(v, 31, 0.22, 15, 25, only={ID, IM})
    outline(v)
    return v

# ======================= РЕДКОЕ =======================
def runes(v, y0, y1, x0, x1, z, c=RL, seed=0):
    """Зигзаг-узор (руны) по плоскости клинка на слое z."""
    for y in range(y0, y1 + 1):
        p = (y - y0) % 6
        xs = {0: (x0, x0 + 1), 1: (x0 + 1, x0 + 2), 2: (x0 + 2, x0 + 3), 3: (x0 + 2,), 4: (x0 + 1, x0 + 3), 5: (x0, x0 + 3)}[p]
        for x in xs:
            if x0 <= x <= x1: v.v[(x, y, z)] = c

def guard_blade():
    v = W()
    # навершие: диск с кольцами
    v.disc_xy(0.5, -13, 2.8, 0, 3, lambda x, y, z: RL if abs(math.hypot(x - 0.5, y + 13) - 1.8) < 0.7 else BR)
    v.col(0, -13, 3, GLt); v.col(1, -13, 3, GLt)
    grip(v, -10, -1, wrap=(WM, WD), band=RL, every=3)
    # гарда: квадрат с камнем + плечи, загнутые концами вверх/вниз
    v.box(-2, 3, -2, 3, -2, 2, BR)
    v.box(-1, 2, -1, 2, -2, 2, RL)
    v.box(0, 1, 0, 1, -3, 3, '#F2B04A')
    for s in (-1, 1):
        for d in range(3, 8):
            x = 0.5 + s * (d + 0.5) - 0.5
            v.col(int(x), 0, 3, BR); v.col(int(x), 1, 3, BR)
        xe = int(0.5 + s * 7.5 - 0.5)
        v.box(xe, xe + (1 if s > 0 else -1), -2, 3, -1, 1, BRL)
    sword_blade(v, 4, 31, 4, 5, mid=IM, light=BN, ridge=ID, seed=3)
    # медный узор по долу с обеих сторон
    for z in (-1, 1):
        runes(v, 6, 27, -2, 1, z, c=RL)
    rust_spots(v, 41, 0.14, 4, 36, only={IM})
    outline(v); bevel(v)
    return v

def guard_hammer():
    v = W()
    v.box(-1, 2, -17, -14, -1, 2, BR)
    v.box(0, 1, -16, -15, -2, 3, RL)
    for y in range(-13, 15):
        c = WM if y % 2 else WD
        if (y + 13) % 4 == 0: c = RL
        v.box(0, 1, y, y, 0, 1, c)
    hammer_head(v, 15, 27, 9, 5, face=BN, body=ID, edge=BR, band=BR, band_w=3, seed=5)
    # ромб-эмблема на обеих сторонах бойка
    for z in (-6, 6):
        for dx in range(-3, 5):
            for dy in range(-3, 4):
                if abs(dx - 0.5) + abs(dy) <= 3.5:
                    c = RL if abs(dx - 0.5) + abs(dy) > 2.2 else (GLt if abs(dx - 0.5) + abs(dy) < 1 else RM)
                    v.v[(dx, 21 + dy, z)] = c
    # медные кромки бойка
    for x in (-9, -8, 9, 10):
        for z in range(-5, 6):
            if (x, 15, z) in v.v: v.v[(x, 15, z)] = RL
            if (x, 27, z) in v.v: v.v[(x, 27, z)] = RL
    outline(v)
    return v

# ======================= ЭПИЧЕСКОЕ =======================
def vortex_blade():
    v = W()
    # навершие: кольцо с золотым центром
    v.disc_xy(0.5, -16, 2.6, 1.2, 3, lambda x, y, z: GM if (x + y) % 4 == 0 else SM)
    v.col(0, -16, 3, GLOW); v.col(1, -16, 3, GLOW)
    grip(v, -13, 3, wrap=(SM, SD), band=GM, every=4)
    v.box(-1, 2, -1, 0, -1, 2, GM)
    cx, cy = 0.5, 11.5
    # тёмный клубящийся «дым» вихря: объёмный ком с рваным краем
    for x in range(-9, 11):
        for y in range(2, 22):
            d = math.hypot(x - cx, y - cy)
            ang = math.atan2(y - cy, x - cx)
            edge = 6.4 + 1.2 * math.sin(ang * 3 + 0.8) + (nz(x, y, 0, 2, 5) - 0.5) * 1.6
            if d < edge:
                t = 4 if d < edge - 2 else (3 if d < edge - 1 else 2)
                c = SD if nz(x, y, 0, 2, 9) < 0.55 else SM
                if d > edge - 1.2 and nz(x, y, 1, 1, 4) < 0.5: c = SL
                v.col(x, y, t, c)
    # золотая спираль на гранях (обе стороны) + сияющий центр
    for step in range(0, 220):
        a = step * 0.05
        r = 0.6 + step * 0.026
        if r > 6.6: break
        x = int(round(cx + math.cos(a) * r - 0.5)); y = int(round(cy + math.sin(a) * r - 0.5))
        c = GLOW if r < 2.5 else (GM if step % 14 < 10 else GLt)
        for z in (-2, 3):
            v.v[(x, y, z)] = c
    v.box(0, 1, 11, 12, -2, 3, GLOW2)
    # серп: большая дуга справа от вихря, острием вверх-влево
    ox, oy = -1.5, 10.0
    for deg in range(-80, 122):
        a = math.radians(deg)
        thick = 3.4 * math.sin(math.radians((deg + 75) * 180 / 203)) + 0.4
        for r10 in range(95, 150, 2):
            r = r10 / 10
            if r > 10.0 + thick: continue
            x = int(round(ox + math.cos(a) * r)); y = int(round(oy + math.sin(a) * r * 1.12))
            f = (r - 10.0) / max(thick, 0.5)
            c = BN if f > 0.72 else (GLt if f > 0.4 else (GM if f > 0.15 else GD))
            t = 1 if f > 0.75 else (2 if f > 0.4 else 3)
            v.col(x, y, t, c)
    # кромка серпа светится
    for deg in range(-60, 120, 3):
        a = math.radians(deg); thick = 3.4 * math.sin(math.radians((deg + 75) * 180 / 203)) + 0.4
        r = 10.0 + thick
        x = int(round(ox + math.cos(a) * r)); y = int(round(oy + math.sin(a) * r * 1.12))
        if (x, y, 0) in v.v and deg % 9 == 0: v.v[(x, y, 0)] = GLOW2
    # парящие кубики
    for (x, y, z) in [(-9, 24, 0), (12, 22, 0), (13, 6, 1), (-11, 5, 0), (6, 27, 0), (-4, 26, 1), (-10, 15, 0)]:
        v.box(x, x, y, y, z, z, GLOW)
    outline(v, cond=lambda i, j, k: j > -16)
    return v

def shattered_hammer():
    v = W()
    # навершие-шар с двумя «глазами»
    v.disc_xz(0.5, 0, 0.5, 2.3, -17, -14, lambda x, y, z: SM if y in (-15, -16) else SD)
    for (x, z) in ((-1, -2), (2, -2), (-1, 3), (2, 3)):
        v.v[(x, -15, z if z < 0 else z - 1)] = GLOW
    for y in range(-13, 15):
        c = SM if y % 2 else SD
        if y in (-12, -6, 6, 13): c = GM
        v.box(0, 1, y, y, 0, 1, c)
    hammer_head(v, 15, 28, 9, 5, face=SL, body=SM, edge=SD, band=BR, band_w=2, seed=8)
    # светящиеся трещины по граням бойка (±Z) и по торцам
    crack = [(-7, 27), (-6, 26), (-6, 25), (-5, 24), (-5, 23), (-4, 22), (-3, 22), (-3, 21), (-4, 20), (-4, 19),
             (-3, 18), (-3, 17), (-2, 16), (4, 27), (4, 26), (3, 25), (3, 24), (4, 23), (5, 22), (5, 21), (6, 21),
             (6, 20), (5, 19), (5, 18), (6, 17), (7, 16), (-6, 20), (-7, 20), (-8, 19)]
    for z in (-5, 5):
        for (x, y) in crack:
            if (x, y, z) in v.v: v.v[(x, y, z)] = GLOW
            if (x, y, z + (1 if z > 0 else -1)) not in v.v: v.v[(x, y, z + (1 if z > 0 else -1))] = GLOW2 if (x + y) % 3 == 0 else GLOW
    for y in range(17, 27):
        if y % 3:
            for x in (-10, 11):
                for z in (-1, 0, 1):
                    if (x - (1 if x < 0 else -1), y, z) in v.v: v.v[(x, y, z)] = GLOW
    for (x, y, z) in [(-12, 30, 0), (12, 31, 1), (13, 14, 0), (-12, 12, 0), (2, 33, 0)]:
        v.v[(x, y, z)] = GLOW
    outline(v)
    return v

# ======================= ЛЕГЕНДАРНОЕ =======================
def gatekeeper_key():
    v = W()
    # навершие-трилистник (кольцо ключа) с сияющим ядром
    for (cx, cy) in ((-1.8, -18), (2.8, -18), (0.5, -21.6)):
        v.disc_xy(cx, cy, 2.3, 1.0, 3, lambda x, y, z: GM if (x + y) % 3 else BR)
    v.disc_xy(0.5, -18.6, 1.4, 0, 3, GLOW)
    v.box(0, 1, -16, -15, -1, 1, BR)
    # рукоять в рёбрах
    for y in range(-14, -2):
        if y % 3 == 0: v.box(-1, 2, y, y, -1, 2, GM)
        else: v.box(0, 1, y, y, 0, 1, SM if y % 3 == 1 else SD)
    # гарда: квадрат со светящимся камнем, плечи наискось с ромбами на концах
    v.box(-3, 4, -3, 4, -2, 3, BR)
    v.box(-2, 3, -2, 3, -2, 3, GM)
    v.box(-1, 2, -1, 2, -3, 4, GLOW2)
    for s_ in (-1, 1):
        for d in range(4, 10):
            x = (d if s_ > 0 else 1 - d)
            yo = -(d - 4) // 2
            for yy in (yo, yo + 1):
                v.col(x, yy, 3, BR if (d % 2) else BRD)
        xe = 10 if s_ > 0 else -9
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if abs(dx) + abs(dy) <= 1: v.col(xe + dx, -4 + dy, 3, GM)
        v.v[(xe, -4, 0)] = GLOW
        v.col(xe - s_, 3, 3, BRL); v.col(xe - s_, 4, 3, GM)
    # клинок: бронзовые блоки ступенями
    for y in range(5, 39):
        seg = y // 4
        lo = -3 - (1 if seg % 2 == 0 else 0)
        hi = 4 + (1 if seg % 3 == 1 else 0)
        for x in range(lo, hi + 1):
            if x <= lo + 1: c = SM
            elif x >= hi: c = BRL
            else: c = BR if nz(x, y, 0, 2, 17) > 0.22 else SL
            if (y % 4 == 0) and lo < x < hi: c = BRD
            v.col(x, y, 4 if lo < x < hi else 3, c)
    # светящийся канал зигзагом на обеих гранях
    x = 0
    for y in range(6, 37):
        if y % 6 == 0: x = 1 - x
        for z in (-2, 3):
            v.v[(x, y, z)] = GLOW
            if y % 6 == 0: v.v[(1 - x, y, z)] = GLOW
    # ромб-гнездо на клинке у гарды (золото + свет)
    for dx in range(-2, 4):
        for dy in range(-2, 3):
            d = abs(dx - 0.5) + abs(dy)
            if 1.5 <= d <= 2.5:
                for z in (-2, 3): v.v[(dx, 9 + dy, z)] = GM
    # бородка ключа: квадратная голова с отверстием и крюком
    for x in range(-4, 10):
        for y in range(37, 50):
            hole = 0 <= x <= 5 and 41 <= y <= 46
            if hole: continue
            c = BR if (x + 2 * y) % 5 else BRL
            if x <= -3: c = SM
            if y >= 48: c = BRL
            v.col(x, y, 4, c)
    for x in range(-1, 7):
        for y in range(40, 48):
            if (x in (-1, 6) or y in (40, 47)) and not (0 <= x <= 5 and 41 <= y <= 46):
                for z in (-2, 3): v.v[(x, y, z)] = GM
    # спираль-скважина в отверстии (тонкий свет)
    for (x, y) in [(2, 43), (3, 43), (3, 44), (2, 45), (1, 44), (1, 43), (1, 42), (2, 42), (3, 42), (4, 42), (4, 43), (4, 44), (4, 45)]:
        v.v[(x, y, 0)] = GLOW if (x, y) != (2, 43) else GLOW2
        v.v[(x, y, 1)] = GLOW
    # крюк сверху налево
    for y in range(47, 53): v.col(-4, y, 3, SM); v.col(-3, y, 3, BR)
    for x in range(-4, 2): v.col(x, 52, 3, BRL); v.col(x, 53, 3, BR)
    # прожилки света по бородке
    for (x, y) in [(8, 38), (8, 39), (7, 40), (8, 41), (8, 42), (7, 43), (-2, 48), (-1, 49), (0, 49)]:
        for z in (-2, 3): v.v[(x, y, z)] = GLOW
    # парящие золотые шарики
    for (x, y, z) in [(-8, 44, 0), (12, 52, 0), (11, 31, 0), (-8, 27, 0), (10, 18, 0), (-7, 14, 1), (5, 57, 0)]:
        v.box(x, x + 1, y, y + 1, z, z + 1, GLOW)
    outline(v)
    return v

WEAPONS = [
    ('rusty_sword', rusty_sword, 'common'),
    ('iron_falchion', iron_falchion, 'common'),
    ('forge_hammer', forge_hammer, 'common'),
    ('guard_blade', guard_blade, 'rare'),
    ('guard_hammer', guard_hammer, 'rare'),
    ('vortex_blade', vortex_blade, 'epic'),
    ('shattered_hammer', shattered_hammer, 'epic'),
    ('gatekeeper_key', gatekeeper_key, 'legendary'),
]


