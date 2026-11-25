"""plate_parts — латная броня воина в том же воксельном стиле, что броня мага (magekit).
Все размеры — стады в осях частей R15 (X вправо, Y вверх, перед −Z), воксель 0.125.
Тело-блоки (как у мага): голова ±0.575; UpperTorso x±1.04 y±0.8 z±0.52; LowerTorso y±0.2;
UpperArm x,z ±0.52 y±0.585; LowerArm y±0.526; Hand y±0.15; UpperLeg y±0.6085;
LowerLeg y±0.5965; Foot y±0.15, z±0.52.

Принцип тот же, что у мага: деталь заполняется «материалами» (fill), потом shade()
красит их по рампам с освещением по нормали, затем роспись (кант, заклёпки, руны).
Материал с «!» — светящийся меш (глаза в визоре, руны, угли)."""
import math
import numpy as np
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'mage-armor'))
import magekit as K
from magekit import Piece, V, H, cen
import mage_parts as M

HEAD = 0.575
TX, TY, TZ = 1.04, 0.8, 0.52
ARM = 0.52


def sel(a, b, w):
    return (abs(a) ** w + abs(b) ** w) ** (1 / w)


# ===================== ШЛЕМ =====================

def helm(p, kind='sallet', R=0.8, top=0.82, bottom=-0.66, w=3.2, mat='steel', face_mat=None, slit=0.06,
         slit_w=(0.1, 0.36), eye='!#6FE3FF', brim=0.0, brim_y=0.1, nose=True, crest=0.0, open_face=False,
         neck=0.0, zback=0.0, seed=1, prow=0.0, holes=False):
    """Шлем-скорлупа поверх головы. kind: sallet (покатый с хвостом), great (горшок-топфхелм),
    kettle (с полями), cap (шапель/подшлемник — открытое лицо), hood (кожаный капюшон).
    R — полуширина, top/bottom — высота верха и низа, w — степень суперэллипса сечения.
    Визор: щель на высоте slit (светится eye), nose — наносник посередине."""
    def radius(y):
        # купол сверху, прямые стенки ниже экватора
        eq = 0.18
        if y <= eq:
            return R
        t = (y - eq) / max(top - eq, 1e-3)
        if t >= 1:
            return -1
        return R * math.sqrt(max(0.0, 1 - t ** (2.2 if kind != 'great' else 3.5)))

    def inside(x, y, z):
        if y < bottom or y > top:
            return False
        r = radius(y)
        if r <= 0:
            return False
        zz = z - (zback * max(0, (bottom + 0.4 - y)) if z > 0 else 0)
        if z < 0 and prow:
            # «нос» забрала: перед вытянут к центру
            zz = z / (1 + prow * max(0.0, 1 - (x / r) ** 2) * (1 if y < 0.4 else max(0, 1 - (y - 0.4) / 0.3)))
        s = sel(x, zz, w)
        # хвост салада: сзади стенка уходит ниже и наружу
        if kind == 'sallet' and z > 0 and y < bottom + 0.3:
            s = sel(x, z - 0.12 * (bottom + 0.3 - y) / 0.3, w)
        if s > r:
            return False
        # пустота под головой
        if abs(x) < HEAD + 0.02 and abs(z) < HEAD + 0.02 and y < HEAD + 0.02:
            return False
        return True
    lo_y = bottom - 0.3
    p.fill((-R - 0.3, lo_y, -R - 0.3), (R + 0.3, top, R + 0.3), inside, mat)
    if kind in ('cap', 'hood') or open_face:
        # открытое лицо: вырезать перед ниже линии лба, под ним — лицо героя (тень, глаза)
        p.carve(lambda x, y, z: z < -0.3 and y < 0.24 and abs(x) < 0.5 and y > bottom - 0.01)
        M.face(p, eyes=eye, hair='shadow')
    if brim:
        M.brim(p, R + brim, brim_y, th=0.13, droop=0.08, mat=mat)
        p.carve(lambda x, y, z: abs(x) < HEAD + 0.02 and abs(z) < HEAD + 0.02 and y < HEAD)
    if neck:
        # бармица/горжет: короткий раструб под шлемом
        def ins(x, y, z):
            if y > bottom + 0.02 or y < bottom - neck:
                return False
            s = sel(x, z, 3)
            return HEAD - 0.02 <= s <= R + 0.04 * (bottom - y) / max(neck, 0.01)
        p.fill((-R - 0.2, bottom - neck, -R - 0.2), (R + 0.2, bottom, R + 0.2), ins, face_mat or mat)
    if not (kind in ('cap', 'hood') or open_face):
        visor(p, slit, slit_w, eye, nose=nose, mat=face_mat)
        if holes:
            # дыхательные отверстия на правой щеке
            for (i, j, k) in list(p.m):
                x, y, z = cen(i), cen(j), cen(k)
                if 0.15 < x < 0.42 and -0.4 < y < -0.12 and (i + j) % 2 == 0 and (i, j, k - 1) not in p.m and z < -HEAD:
                    p.m[(i, j, k)] = 'shadow'
    if crest:
        def cr(x, y, z):
            if abs(x) > 0.07:
                return False
            r = radius(y - crest) if y > top - 0.1 else -1
            return sel(x, z, w) <= R * 0.95 and y > top - 0.25 and y < top + crest and z > -R * 0.9 + 0.6 * (y - top)
        p.fill((-0.1, top - 0.3, -R), (0.1, top + crest, R), lambda x, y, z: abs(x) <= 0.07 and top - 0.2 <= y <= top + crest * (1 - ((z + 0.1) / R) ** 2), face_mat or 'trim')


def visor(p, y, xs, eye, nose=True, mat=None):
    """Щель визора: передний слой на высоте y выбит, за ним — свечение глаз."""
    occ = p.m
    front = {}
    for (i, j, k) in list(occ):
        if j == math.floor(y / V) and xs[0] <= abs(cen(i)) <= xs[1]:
            if (i, j) not in front or k < front[(i, j)]:
                front[(i, j)] = k
    for (i, j), k in front.items():
        if cen(k) > -HEAD:
            continue
        del occ[(i, j, k)]
        occ[(i, j, k + 1)] = eye
    if nose:
        for (i, j, k) in list(occ):
            if abs(cen(i)) < 0.07 and -0.35 < cen(j) < y + 0.2 and cen(k) < -HEAD and (i, j, k - 1) not in occ:
                occ[(i, j, k - 1)] = mat or 'trim'
    if mat:
        # пластина лица чуть темнее/другого металла
        for key, m in list(occ.items()):
            if not m.startswith('!') and cen(key[2]) < -HEAD - 0.05 and cen(key[1]) < y + 0.3 and abs(cen(key[0])) < 0.5 and m == 'steel':
                occ[key] = mat


def horns(p, side_pts, r0, r1, mat='horn'):
    for sx in (1, -1):
        pts = [(x * sx, y, z) for (x, y, z) in side_pts]
        M.tip(p, pts, r0, r1, mat=mat)


def spikes(p, n, y0, R, h, r0=0.09, mat='trim', zf=None, phase=0.0, arc=math.pi):
    """Зубцы короны: n штук по дуге arc вокруг головы на высоте y0."""
    for a in range(n):
        th = phase + (a / max(1, n - 1) - 0.5) * arc if arc < 2 * math.pi else phase + a / n * 2 * math.pi
        x, z = R * math.sin(th), -R * math.cos(th)
        hh = h * (1.0 if a % 2 == 0 else 0.65)
        M.tip(p, [(x, y0, z), (x, y0 + hh * 0.4, z), (x * 1.02, y0 + hh * 0.75, z * 1.02), (x * 1.04, y0 + hh, z * 1.04)], r0, 0.04, mat=mat)


def plume(p, pts, r0, r1, mat='plume'):
    M.tip(p, pts, r0, r1, mat=mat, curl=0.7)


# ===================== КОРПУС =====================

def cuirass(p, out=0.14, top=0.1, bottom=-0.75, bulge=0.12, w=6, mat='steel', lames=3, lame_mat=None, back=True):
    """Кираса на UpperTorso: оболочка вокруг торса, грудь выпуклая, ниже — пояс из lames пластин."""
    def inside(x, y, z):
        if y > TY + top or y < bottom:
            return False
        zo = out + (bulge * (1 - (x / TX) ** 2) * (1 - ((y - 0.25) / 0.9) ** 2) if z < 0 else 0)
        if not back and z > 0:
            return False
        s = sel(x / (TX + out), z / (TZ + zo), w)
        if s > 1:
            return False
        # плечи скруглены
        if y > TY + top - 0.13 and abs(x) > TX - 0.08:
            return False
        if abs(x) < TX - 0.13 and abs(z) < TZ - 0.13 and y < TY - 0.13:
            return False
        if abs(x) < TX and abs(z) < TZ and y < TY:
            return False
        return True
    p.fill((-TX - out - 0.2, bottom, -TZ - out - bulge - 0.2), (TX + out + 0.2, TY + top, TZ + out + 0.2), inside, mat)
    # лепка: светлое ребро по центру груди, грудные пластины, тёмные бока
    def sculpt(x, y, z, m):
        if m != mat:
            return None
        if z < 0 and abs(x) < V and y > -0.3:
            return mat + '@0.45'
        if z < 0 and abs(y - (0.05 - 0.12 * abs(x))) < V / 2 and abs(x) < TX - 0.1:
            return mat + '@-0.6'
        if abs(x) > TX - 0.05:
            return mat + '@-0.25'
        return None
    p.recolor(sculpt)
    # пластины пояса: каждая следующая чуть шире, нижняя кромка темнее
    if lames:
        step = (0.0 - bottom) / lames
        for n in range(lames):
            y0 = bottom + n * step
            p.recolor(lambda x, y, z, m, y0=y0: (lame_mat or mat) + '@-0.7' if m.split('@')[0] in (mat, lame_mat) and y0 <= y < y0 + V else None)
            if lame_mat:
                p.recolor(lambda x, y, z, m, y0=y0, st=step: lame_mat if m == mat and y0 + V <= y < y0 + st and y < 0 else None)


def gorget(p, h=0.26, ri=0.4, ro=0.68, mat='steel', open_front=0.0):
    M.collar(p, h=h, ri=ri, ro=ro, open_front=open_front, flare=0.06, mat=mat)


def pauldron(p, side, R=0.8, top=0.86, lames=3, drop=0.95, out=0.2, mat='steel', trim=None, spike=0.0, spike_mat='trim',
             layered=True, sleeve='mail', sleeve_y=-0.585, inner=-0.5, step=0.05):
    """Наплечник на UpperArm: купол над плечом и ступени-пластины вниз по внешней стороне руки,
    каждая следующая чуть шире (step). Под ним — рукав sleeve (кольчуга/ткань) до sleeve_y.
    inner — насколько купол заходит на торс (по оси к телу)."""
    sx = 1 if side == 'Right' else -1
    cx, cy = 0.1, top - 0.42

    def inside(x, y, z):
        lx = x * sx
        if y > top or y < top - drop or lx < inner:
            return False
        if abs(x) < ARM + 0.01 and abs(z) < ARM + 0.01 and y < 0.585 + 0.01:
            return False
        t = (top - y) / drop
        layer = min(lames - 1, int(t * lames)) if layered else 0
        k = 1 + layer * step / R
        rx, rz = R * k, (R - 0.02) * k
        if y >= cy:
            ry = top - cy
            return ((lx - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + (z / rz) ** 2 <= 1
        # ниже экватора — стенки по внешней стороне, к телу открыто
        if lx < -0.1 + 0.25 * (cy - y):
            return False
        return ((lx - cx) / rx) ** 2 + (z / rz) ** 2 <= 1
    p.fill((-1.2, top - drop - 0.1, -1.2), (1.2, top + 0.05, 1.2), inside, mat)
    # ступени: нижний ряд каждой пластины — тень (@-0.6), над ним — кант
    if layered and lames > 1:
        for n in range(1, lames + 1):
            yb = top - drop * n / lames
            p.recolor(lambda x, y, z, m, yb=yb: (mat + '@-0.7') if m == mat and yb <= y < yb + V else None)
            if trim:
                p.recolor(lambda x, y, z, m, yb=yb: trim if m == mat and yb + V <= y < yb + 2 * V else None)
    elif trim:
        M.outline_bottom(p, trim, mat)
    if sleeve:
        def sl(x, y, z):
            if y > top - 0.2 or y < sleeve_y:
                return False
            s = sel(x, z, 5)
            return ARM - 0.01 <= s <= ARM + 0.09
        before = set(p.m)
        p.fill((-0.8, sleeve_y, -0.8), (0.8, top, 0.8), sl, sleeve)
        p.m = {k: v for k, v in p.m.items()}
    if spike:
        M.tip(p, [(sx * 0.25, top - 0.05, 0), (sx * 0.3, top + spike * 0.4, 0), (sx * 0.38, top + spike * 0.8, 0), (sx * 0.46, top + spike, 0)], 0.14, 0.03, mat=spike_mat)


def bracer(p, y0=-0.5, y1=0.32, r=0.64, flare=0.1, mat='steel', trim=None):
    """Наруч на LowerArm: трубка с раструбом у локтя."""
    def inside(x, y, z):
        if y < y0 or y > y1:
            return False
        t = (y - y0) / (y1 - y0)
        rr = r + flare * max(0, (t - 0.65) / 0.35)
        s = sel(x, z, 5)
        return s <= rr and s >= ARM - 0.02
    p.fill((-0.9, y0, -0.9), (0.9, y1, 0.9), inside, mat)
    if trim:
        p.recolor(lambda x, y, z, m: trim if m == mat and (y > y1 - V or y < y0 + V) else None)


def gauntlet(p, mat='steel', cuff='steel', r=0.6, knuckles=True):
    """Перчатка на Hand (блок 1×0.3×1): коробка + костяшки спереди."""
    def inside(x, y, z):
        if abs(y) > 0.24:
            return False
        s = sel(x, z, 6)
        return s <= r and not (abs(x) < ARM and abs(z) < ARM and abs(y) < 0.15)
    p.fill((-0.8, -0.3, -0.8), (0.8, 0.3, 0.8), inside, mat)
    p.recolor(lambda x, y, z, m: cuff if m == mat and y > 0.1 else None)
    if knuckles:
        for i in (-3, -1, 1, 3):
            p.cell(i * 0.1, -0.06, -r - V / 2, mat + '@0.4')


def faulds(p, mat='steel', y0=0.12, drop=0.72, front=True, back=True, plates=2, gap=0.08, out=0.16, belt_mat='leather', buckle='trim',
           tasset_mat=None, rounded=True):
    """Пояс на LowerTorso + набедренные пластины (тассеты) спереди и сзади."""
    M.sash(p, y0=-0.16, y1=y0, out=out - 0.02, mat=belt_mat)
    if buckle:
        p.fill((-0.18, -0.14, -TZ - out - 0.1), (0.18, y0 - 0.02, -TZ - out + 0.02), lambda x, y, z: abs(x) <= 0.17, buckle)
        p.carve(lambda x, y, z: abs(x) < 0.06 and -0.08 < y < y0 - 0.08 and z < -TZ - out - 0.02)
    tm = tasset_mat or mat
    w = (TX - gap * (plates - 1) / 2) / plates
    for zs in ((-1,) if front and not back else (1,) if back and not front else (-1, 1)):
        for n in range(plates):
            for sx in (1, -1):
                x0 = gap / 2 + n * (w + gap / 2)
                x1 = x0 + w

                def ins(x, y, z, x0=x0, x1=x1, sx=sx, zs=zs):
                    lx = x * sx
                    if lx < x0 or lx > x1:
                        return False
                    if y > -0.14 or y < -0.14 - drop:
                        return False
                    if rounded and y < -0.14 - drop + 0.13 and (lx < x0 + V or lx > x1 - V):
                        return False
                    zc = zs * (TZ + out - 0.04 + 0.06 * (-0.14 - y) / drop)
                    return abs(z - zc) <= 0.07
                p.fill((-TX - 0.2, -0.14 - drop, -TZ - 0.5), (TX + 0.2, -0.14, TZ + 0.5), ins, tm)
    # горизонтальные линии на тассетах
    p.recolor(lambda x, y, z, m: tm + '@-0.6' if m == tm and round((y + 0.14) / V) % 3 == 0 and y < -0.2 else None)


def cuisse(p, mat='steel', y0=-0.45, y1=0.5, out=0.12, wrap=0.7):
    """Набедренник: пластина спереди и по бокам UpperLeg (сзади открыто на wrap)."""
    def inside(x, y, z):
        if y < y0 or y > y1:
            return False
        s = sel(x, z, 4)
        if s > ARM + out or s < ARM - 0.02:
            return False
        return z < ARM * wrap
    p.fill((-0.8, y0, -0.8), (0.8, y1, 0.8), inside, mat)


def greave(p, mat='steel', y0=-0.55, y1=0.42, out=0.13, knee=0.22, knee_mat=None):
    """Поножь на LowerLeg + наколенник-купол спереди сверху."""
    def inside(x, y, z):
        if y < y0 or y > y1:
            return False
        s = sel(x, z, 4)
        return ARM - 0.02 <= s <= ARM + out
    p.fill((-0.8, y0, -0.8), (0.8, y1, 0.8), inside, mat)
    if knee:
        kc = (0.0, y1 + 0.02, -ARM - 0.06)
        p.fill((-0.5, y1 - 0.3, -ARM - 0.5), (0.5, y1 + 0.32, -ARM + 0.05),
               lambda x, y, z: (x / 0.36) ** 2 + ((y - kc[1]) / 0.3) ** 2 + ((z - kc[2]) / knee) ** 2 <= 1 and z < -ARM + 0.02, knee_mat or mat)


def boot(p, mat='leather', sole='sole', toe=0.28, cuff=0.0, cuff_mat=None, plate=None):
    """Сапог на Foot (y ±0.15, z ±0.52): оболочка + носок вперёд, подошва темнее."""
    def inside(x, y, z):
        if y < -0.24 or y > 0.3 + cuff:
            return False
        zx = 0.52 + (toe if z < 0 else 0.04)
        if abs(x) > 0.6 or abs(z) > zx:
            return False
        if z < -0.52 and y > 0.1 - (-0.52 - z) * 0.5:
            return False
        if abs(x) < ARM - 0.02 and abs(z) < ARM - 0.02 and -0.15 < y < 0.15:
            return False
        if y > 0.15 and (abs(x) < ARM - 0.02 and abs(z) < ARM - 0.02):
            return False
        return True
    p.fill((-0.7, -0.3, -0.9), (0.7, 0.4 + cuff, 0.7), inside, mat)
    p.recolor(lambda x, y, z, m: sole if m == mat and y < -0.15 else None)
    if cuff and cuff_mat:
        p.recolor(lambda x, y, z, m: cuff_mat if m == mat and y > 0.2 else None)
    if plate:
        p.recolor(lambda x, y, z, m: plate if m == mat and z < -0.4 and y > -0.12 else None)


# ===================== РОСПИСЬ (после shade) =====================

def rivets(p, color, test, step=3, seed=2):
    """Заклёпки: светлые точки на открытых гранях с шагом step."""
    occ = p.c
    for (i, j, k), c in list(occ.items()):
        if c.startswith('!') or not test(cen(i), cen(j), cen(k)):
            continue
        if (i + j * 2 + k) % step:
            continue
        if any((i + d[0], j + d[1], k + d[2]) not in occ for d in ((0, 0, -1), (1, 0, 0), (-1, 0, 0), (0, 0, 1))):
            occ[(i, j, k)] = color


def vines(p, color, test, seed=7, density=0.5, leaf=None):
    """Лоза: извилистые линии по открытым граням (листья — leaf)."""
    occ = p.c
    for (i, j, k), c in list(occ.items()):
        if c.startswith('!') or not test(cen(i), cen(j), cen(k)):
            continue
        wave = math.sin(cen(j) * 9 + cen(i) * 4 + seed) + math.sin(cen(k) * 7 - seed)
        if abs(wave) < 0.22 and H(seed, i, j, k) < density:
            occ[(i, j, k)] = color
            if leaf and H(seed + 1, i, j, k) < 0.25:
                for d in ((1, 0, 0), (0, 1, 0)):
                    key = (i + d[0], j + d[1], k + d[2])
                    if key in occ and not occ[key].startswith('!'):
                        occ[key] = leaf


def stripes(p, color, test, period=4, width=1, axis=1):
    occ = p.c
    for (i, j, k), c in list(occ.items()):
        if c.startswith('!') or not test(cen(i), cen(j), cen(k)):
            continue
        idx = (i, j, k)[axis]
        if idx % period < width:
            occ[(i, j, k)] = color


def cracks(p, glow, test, seed=5, density=0.5):
    """Светящиеся трещины (раскалённый металл): ломаные линии по граням."""
    occ = p.c
    for (i, j, k), c in list(occ.items()):
        if c.startswith('!') or not test(cen(i), cen(j), cen(k)):
            continue
        if not any((i + d[0], j + d[1], k + d[2]) not in occ for d in ((0, 0, -1), (0, 0, 1), (1, 0, 0), (-1, 0, 0))):
            continue
        v = math.sin(i * 1.7 + seed) * math.cos(j * 0.9 - seed) + math.sin(k * 1.3 + j * 0.5)
        if abs(v) < 0.12 and H(seed, i // 2, j // 2, k // 2) < density:
            occ[(i, j, k)] = glow
