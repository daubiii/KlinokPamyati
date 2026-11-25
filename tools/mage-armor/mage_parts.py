"""Детали одежды мага (стады, оси частей R15). Тело-блоки: голова ±0.575; UpperTorso x±1.04 y±0.8 z±0.52;
LowerTorso x±1.04 y±0.2 z±0.52; UpperArm ±0.52, y±0.585; LowerArm ±0.52, y±0.526."""
import math
import numpy as np
import magekit as K
from magekit import Piece, V, H, cen

HEAD = 0.575
TX, TY, TZ = 1.04, 0.8, 0.52


def sel(r, w):
    """Суперэллипс: «радиус» точки (x, z) со степенью w (2 — круг, 4+ — скруглённый квадрат)."""
    return (abs(r[0]) ** w + abs(r[1]) ** w) ** (1 / w)


# ===================== ШЛЯПА =====================

def brim(p, R, y0, th=0.25, droop=0.0, wave=0.0, waves=5, phase=0.0, tilt=0.0, zoff=0.0, rough=0.0, mat='brim', ragged=0.0, seed=1):
    """Поля: диск радиуса R(θ) на высоте y0, края опускаются на droop, волна wave по краю, наклон tilt (перед ниже)."""
    def inside(x, y, z):
        r = math.hypot(x, z - zoff)
        th_ = math.atan2(z - zoff, x)
        Rt = R * (1 + wave * math.sin(waves * th_ + phase)) * (1 - ragged * H(seed, round(th_ * 9)))
        if r > Rt:
            return False
        q = (r / R) ** 2
        yb = y0 - droop * q + wave * 0.6 * math.sin(waves * th_ + phase) * q + tilt * (-(z - zoff)) * (r / R) + rough * (H(seed, round(x / V), round(z / V)) - 0.5) * q
        return yb - th / 2 <= y <= yb + th / 2
    p.fill((-R * 1.2, y0 - droop - 0.5, -R * 1.2 + zoff), (R * 1.2, y0 + 0.5, R * 1.2 + zoff), inside, mat)


def crown(p, y0, h, r0, r1, bend=(0.0, 0.0), w0=4.5, w1=2.0, mat='crown', zoff=0.0, bend_pow=2.0, pinch=0.0):
    """Тулья ломтями: от y0 вверх на h, радиус r0 → r1, сечение — суперэллипс (у основания квадратнее),
    центр уходит на bend (dx, dz) по кривой t^bend_pow. pinch — «вмятина» посередине (сужение)."""
    def inside(x, y, z):
        t = (y - y0) / h
        if t < 0 or t > 1:
            return False
        r = r0 + (r1 - r0) * t - pinch * math.sin(math.pi * t)
        cx = bend[0] * t ** bend_pow; cz = zoff + bend[1] * t ** bend_pow
        w = w0 + (w1 - w0) * min(1, t * 2.5)
        return sel((x - cx, z - cz), w) <= r
    m = max(abs(bend[0]), abs(bend[1])) + r0 + 0.2
    p.fill((-m, y0, -m + zoff), (m, y0 + h, m + zoff), inside, mat)


def tip(p, pts, r0, r1, mat='crown', samples=120, curl=1.0):
    """Кончик шляпы — трубка по Безье pts (4 точки) с радиусом r0 → r1."""
    sp = lambda t: K.bezier(*pts, t)
    rd = lambda t: r0 + (r1 - r0) * t ** curl
    inside, lo, hi, P, R = K.tube(sp, rd, samples)
    p.fill(lo, hi, inside, mat)
    return P


def band(p, y0, y1, mat='band', rmin=0.0):
    """Перекрасить пояс тульи (y0..y1) в материал ленты."""
    p.recolor(lambda x, y, z, m: mat if y0 <= y <= y1 and m.startswith('crown') and math.hypot(x, z) >= rmin else None)


def face(p, shadow='shadow', eyes='!#6FE3FF', hair='hair', rows=(0, 2), eye_row=0, eye_x=(-2, 1), hair_len=-2, bangs=True, beard=None):
    """Лицо под полями: тень полей на лбу, светящиеся глаза, волосы по бокам и сзади.
    Координаты — ячейки головы (центры ±0.5625), слой лица k = −6 (z ≈ −0.69)."""
    k = -6
    before = dict(p.m)
    for j in range(rows[0], rows[1] + 1):
        for i in range(-5, 5):
            if j == eye_row and i in eye_x:
                p.m[(i, j, k)] = eyes
            else:
                p.m[(i, j, k)] = shadow if (j > eye_row or abs(i + 0.5) > 1.5 or bangs) else shadow
    # нижний ряд тени — через одну (дизеринг) по краям
    j = rows[0] - 1
    for i in (-5, -4, 3, 4):
        if (i + j) % 2 == 0:
            p.m[(i, j, k)] = shadow
    # волосы: бока и затылок
    for j in range(hair_len, rows[1] + 1):
        for kk in range(-4, 6):
            if kk < -3 and j < rows[0]:
                continue
            p.m[(-6, j, kk)] = hair; p.m[(5, j, kk)] = hair
        for i in range(-5, 5):
            p.m[(i, j, 5)] = hair
    if beard:
        for j in range(-5, -1):
            for i in range(-3, 3):
                if j == -5 and abs(i + 0.5) > 1.5:
                    continue
                p.m[(i, j, k)] = beard
    p.face = {key for key, v in p.m.items() if before.get(key) != v}


# ===================== НАКИДКА =====================

def mantle(p, front=0.7, back=0.62, side=0.32, out=0.14, top=0.13, scallop=0.0, scallops=6, vpoint=0.0, mat='mantle', seed=3,
           ragged=0.0, xmax=None):
    """Пелерина на UpperTorso: оболочка поверх торса от плеч вниз. Длина спереди front, сзади back,
    у плеча side; scallop — фестоны по краю, vpoint — мысок спереди по центру; ragged — рваный край."""
    xm = xmax or (TX + out)

    def bottom(x, z):
        a = min(1, abs(x) / TX)
        L = (front if z < 0 else back) * (1 - a ** 3) + side * a ** 3
        if z < 0:
            L += vpoint * max(0, 1 - abs(x) / 0.45)
        if scallop:
            L += scallop * (0.5 + 0.5 * math.cos(x / (2 * TX) * scallops * 2 * math.pi))
        if ragged:
            L += ragged * (H(seed, round(x / V), z > 0) - 0.5)
        return TY - L

    def inside(x, y, z):
        if abs(x) > xm or abs(z) > TZ + out or y > TY + top:
            return False
        if y < bottom(x, z):
            return False
        if abs(x) < TX - 0.13 and abs(z) < TZ - 0.13 and y < TY - 0.13:
            return False
        # плечо скруглено: верхний внешний угол срезан
        if abs(x) > TX - 0.05 and y > TY + top - 0.13 and abs(z) > TZ - 0.1:
            return False
        return True
    p.fill((-xm, TY - 2, -TZ - out), (xm, TY + top, TZ + out), inside, mat)


def collar(p, h=0.32, ri=0.36, ro=0.6, zc=0.06, open_front=0.24, flare=0.12, mat='collar'):
    """Высокий ворот вокруг шеи, спереди разрез."""
    def inside(x, y, z):
        if y < TY or y > TY + h:
            return False
        t = (y - TY) / h
        r = sel((x, z - zc), 3)
        if r < ri or r > ro + flare * t:
            return False
        if z < -0.1 and abs(x) < open_front * (0.4 + t):
            return False
        return True
    p.fill((-1, TY, -1), (1, TY + h, 1), inside, mat)


def hood(p, y=0.74, z=0.64, rx=0.62, ry=0.3, rz=0.26, mat='hood'):
    """Сложенный капюшон на спине (под ним — плащ)."""
    def inside(x, yy, zz):
        if zz < TZ - 0.02:
            return False
        return (x / rx) ** 2 + ((yy - y) / ry) ** 2 + ((zz - z) / rz) ** 2 <= 1
    p.fill((-rx, y - ry, z - rz), (rx, y + ry, z + rz), inside, mat)
    # складка-провал в середине
    p.recolor(lambda x, yy, zz, m: mat + '@-0.6' if m == mat and abs(x) < 0.2 and yy < y and zz > z else None)


def clasp(p, y, mat='metal', glow=None, w=2, z=None):
    """Застёжка спереди: w×w ячеек на груди (+ светящийся камень)."""
    k = math.floor((z if z is not None else -(TZ + 0.14)) / V)
    j0 = math.floor(y / V)
    for i in range(-w // 2, w - w // 2):
        for j in range(j0, j0 + w):
            p.m[(i, j, k)] = mat
            p.m[(i, j, k + 1)] = mat
    if glow:
        p.m[(-1 if w > 2 else 0, j0 + w // 2 - (1 if w > 2 else 0), k - 1)] = glow
        if w > 2:
            p.m[(0, j0 + 1, k - 1)] = glow


def drape(p, side, L=0.5, out=0.14, top=0.12, scallop=0.0, mat='mantle', trim=None, ragged=0.0, seed=5):
    """Ткань на верх плеча (часть UpperArm), мягкий край снизу."""
    sx = 1 if side == 'Right' else -1
    yt = 0.585

    def inside(x, y, z):
        lx = x * sx
        if abs(x) > 0.52 + out or abs(z) > 0.52 + out or y > yt + top:
            return False
        a = math.atan2(z, lx)
        Ly = L * (0.75 + 0.25 * math.cos(a)) + scallop * (0.5 + 0.5 * math.cos(4 * a))
        if ragged:
            Ly += ragged * (H(seed, round(a * 6)) - 0.5)
        if y < yt - Ly:
            return False
        if abs(x) < 0.52 - 0.12 and abs(z) < 0.52 - 0.12 and y < yt - 0.1:
            return False
        if lx < -0.36 and y < yt:  # со стороны тела не надо — там торс
            return False
        return True
    p.fill((-0.8, yt - 1.2, -0.8), (0.8, yt + top, 0.8), inside, mat)
    if trim:
        edge(p, trim, mat)


def cuff(p, y0=-0.52, y1=-0.16, r0=0.62, r1=0.7, mat='cuff', trim=None, bell=True):
    """Обшлаг на предплечье (у запястья), раструбом вниз."""
    def inside(x, y, z):
        if y < y0 or y > y1:
            return False
        t = (y1 - y) / (y1 - y0)
        r = r0 + (r1 - r0) * t if bell else r0
        s = sel((x, z), 5)
        return 0.4 <= s <= r
    p.fill((-0.9, y0, -0.9), (0.9, y1, 0.9), inside, mat)
    if trim:
        p.recolor(lambda x, y, z, m: trim if m == mat and y < y0 + 0.13 else None)


def sash(p, y0=-0.2, y1=0.16, out=0.14, mat='sash', knot=None, tails=None):
    """Кушак/пояс на LowerTorso. knot = (x, mat) узел; tails = [(x, length, w, mat)] свисающие концы спереди."""
    def inside(x, y, z):
        if y < y0 or y > y1 or abs(x) > TX + out or abs(z) > TZ + out:
            return False
        return not (abs(x) < TX - 0.13 and abs(z) < TZ - 0.13)
    p.fill((-TX - out, y0, -TZ - out), (TX + out, y1, TZ + out), inside, mat)
    if knot:
        kx, km = knot
        p.fill((kx - 0.2, y0 - 0.04, -TZ - 0.3), (kx + 0.2, y1 + 0.04, -TZ), lambda x, y, z: (x - kx) ** 2 / 0.04 + (y - (y0 + y1) / 2) ** 2 / 0.05 + (z + TZ + 0.12) ** 2 / 0.03 <= 1, km)
    for (tx, length, w, tm) in tails or []:
        def ins(x, y, z, tx=tx, length=length, w=w):
            if y > y0 or y < y0 - length:
                return False
            t = (y0 - y) / length
            return abs(x - tx - 0.05 * t) <= w / 2 and -TZ - 0.27 <= z <= -TZ - 0.14 + 0.0 * t
        p.fill((tx - 0.5, y0 - length, -TZ - 0.3), (tx + 0.5, y0, -TZ), ins, tm)


def pouch(p, x, y, z, w=0.36, h=0.38, d=0.26, mat='leather', flap='leather@0.4', button='metal'):
    p.fill((x - w / 2, y - h / 2, z - d / 2), (x + w / 2, y + h / 2, z + d / 2), K.box(x - w / 2, x + w / 2, y - h / 2, y + h / 2, z - d / 2, z + d / 2), mat)
    p.recolor(lambda xx, yy, zz, m: flap if m == mat and yy > y + h / 2 - 0.14 else None)
    if button:
        p.cell(x, y + h / 2 - 0.19, z - d / 2 - 0.01 - V, button)


def book(p, x, y, z, w=0.34, h=0.44, d=0.18, cover='cover', pages='paper', corner='metal', rot_axis='x', gem=None):
    """Книга: обложка, торец страниц, уголки. Корешок — к телу (−x для правого бока)."""
    lo = (x - d / 2, y - h / 2, z - w / 2) if rot_axis == 'x' else (x - w / 2, y - h / 2, z - d / 2)
    hi = (x + d / 2, y + h / 2, z + w / 2) if rot_axis == 'x' else (x + w / 2, y + h / 2, z + d / 2)
    p.fill(lo, hi, K.box(*[v for pair in zip(lo, hi) for v in pair]), cover)
    # страницы — внутренняя часть, видна с торцов
    def pg(xx, yy, zz, m):
        if m != cover:
            return None
        if rot_axis == 'x':
            inner = lo[0] + V < xx < hi[0] - V and lo[1] + V < yy < hi[1] - V
            return pages if inner and (zz < lo[2] + V or zz > hi[2] - V or yy > hi[1] - 2 * V or yy < lo[1] + 2 * V) and lo[1] + V < yy < hi[1] - V else None
        inner = lo[2] + V < zz < hi[2] - V and lo[1] + V < yy < hi[1] - V
        return pages if inner and (xx < lo[0] + V or xx > hi[0] - V) else None
    p.recolor(pg)
    if corner:
        for cy in (lo[1] + V / 2, hi[1] - V / 2):
            for cz in ((lo[2] + V / 2, hi[2] - V / 2) if rot_axis == 'x' else (lo[0] + V / 2, hi[0] - V / 2)):
                for cx in ((lo[0] + V / 2, hi[0] - V / 2) if rot_axis == 'x' else (lo[2] + V / 2, hi[2] - V / 2)):
                    if rot_axis == 'x':
                        p.cell(cx, cy, cz, corner)
                    else:
                        p.cell(cz, cy, cx, corner)
    if gem:
        if rot_axis == 'x':
            p.cell(hi[0] + V / 2 if x > 0 else lo[0] - V / 2, y, z, gem)
        else:
            p.cell(x, y, lo[2] - V / 2, gem)


def edge(p, trim, mat=None):
    """Кант: ячейки материала mat на нижней кромке (под ними пусто) → trim."""
    occ = set(p.m)
    for (i, j, k), m in list(p.m.items()):
        if mat and not m.startswith(mat):
            continue
        if (i, j - 1, k) not in occ:
            p.m[(i, j, k)] = trim


def outline_bottom(p, trim, mat, rows=1):
    occ = set(p.m)
    for (i, j, k), m in list(p.m.items()):
        if m.split('@')[0] != mat:
            continue
        if any((i, j - d, k) not in occ for d in range(1, rows + 1)):
            p.m[(i, j, k)] = trim


# ===================== ПЛАЩ =====================

def cape(sid, y_top=0.78, y_bot=-1.3, segs=3, w_top=0.92, w_bot=1.06, z0=0.66, th=0.13, fold=0.06, folds=7, hem='round',
         hem_depth=0.18, mat='cape', ragged=0.0, seed=7, split=0.0, notch=0.0, matfn=None):
    """Плащ на спине: лист шириной w_top → w_bot, складки (волна по z), подол: round | point | tattered | swallow.
    → целый лист (Piece); после shade/deco — split_cape() режет на сегменты Cape1..N с шарнирами."""
    def hem_y(x):
        a = abs(x) / w_bot
        if hem == 'round':
            return y_bot + hem_depth * a ** 2
        if hem == 'point':
            return y_bot + hem_depth * a
        if hem == 'swallow':
            return y_bot + hem_depth * (1 - a)
        if hem == 'tattered':
            return y_bot + hem_depth * H(seed, round(x / V / 1.5)) + hem_depth * 0.5 * a
        return y_bot

    def inside(x, y, z):
        t = (y_top - y) / (y_top - y_bot)
        if t < 0:
            return False
        w = w_top + (w_bot - w_top) * min(1, max(0, t))
        if abs(x) > w:
            return False
        if y < hem_y(x):
            return False
        if split and abs(x) < split * min(1, max(0, (t - 0.55) / 0.45)):
            return False
        if notch and y > y_top - notch and abs(x) < 0.18:
            return False
        zc = z0 + th / 2 + fold * math.sin(x / w * folds * math.pi / 2) * min(1, t * 1.5) + 0.06 * t
        return abs(z - zc) <= th / 2
    full = Piece('CapeFull', 'UpperTorso', 'cape')
    full.fill((-w_bot - 0.1, y_bot - 0.1, z0 - 0.3), (w_bot + 0.1, y_top, z0 + 0.5), inside, matfn or (lambda x, y, z: mat))
    if ragged:
        full.carve(lambda x, y, z: y < hem_y(x) + ragged and H(seed + 1, round(x / V), round(y / V)) < 0.35)
    full.split = (y_top, y_bot, segs)
    return full


def split_cape(full):
    """Разрезать раскрашенный плащ на сегменты Cape1..N (цвета — из целого листа, без «швов» освещения)."""
    y_top, y_bot, segs = full.split
    step = (y_top - y_bot) / segs
    pieces = []
    for n in range(segs):
        top = y_top - n * step
        bot = y_top - (n + 1) * step if n < segs - 1 else y_bot - 1
        p = Piece(f'Cape{n + 1}', 'UpperTorso', 'cape')
        p.order = n
        for (i, j, k), c in full.c.items():
            if bot < cen(j) <= top:
                p.c[(i, j, k)] = c
        zs = [cen(k) for (_, j, k) in p.c]
        p.hinge = np.array([0.0, top, (min(zs) + max(zs)) / 2 if zs else 0.7])
        if p.c:
            pieces.append(p)
    return pieces
