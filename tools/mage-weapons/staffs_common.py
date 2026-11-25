"""Общие детали посохов мага (поверх weapons3d.py / weapons3d_common345.py).
Формат тот же, что у оружия воина: воксель 0,125 стада (масштаб — SPEC в staffs3d.py),
Y — вдоль посоха (кисть около SPEC[id][1]), X — поперёк, Z — толщина, '!#hex' — неон.
Ось древка — между вокселями 0 и 1 по X и Z (центр 0,5; 0,5), как у рукоятей оружия.
Навершие — объёмное (сферы, кристаллы, чаши), а не плоское, как клинок."""
import math
from weapons3d import W, nz, outline, bevel, VS, OUT, DARKER, LIGHTER
from weapons3d_common345 import shades, put, ellipsoid, motes, speckle, inlay, gem, drop_islands

AX, AZ = 0.5, 0.5

# --- общая палитра посохов ---
WD, WM, WL, WH = '#3B2618', '#5C3A22', '#7A4E2C', '#9A6A3E'        # дерево
DW, DWM, DWL = '#2A1C14', '#3E2A1E', '#56402E'                     # тёмное дерево
ID, IM, IL, IH = '#3E3833', '#6A6058', '#8E8378', '#B5A894'        # железо
RD, RM, RL = '#6B3418', '#A4521F', '#CF7A2F'                       # ржавчина
BRD, BR, BRL = '#5E3C1E', '#8A5A2A', '#B87A36'                     # бронза
GD, GM, GL = '#9C6A1E', '#D9A03A', '#F0C766'                       # золото
LD, LM, LL = '#3A2418', '#5E3A26', '#80553A'                       # кожа обмотки
SD, SM, SL = '#3A3A44', '#5A5A66', '#80808C'                       # камень
BD, BM, BL, BH = '#8A7A60', '#B8A888', '#DCCFB0', '#F2EAD4'        # кость
PD, PM, PL = '#2C2440', '#4A3C6A', '#6E5C96'                       # фиолетовая отделка (тайное)

shades({WH: WL, WL: WM, WM: WD, WD: OUT, DWL: DWM, DWM: DW, DW: OUT, IH: IL, IL: IM, IM: ID, ID: OUT,
        RL: RM, RM: RD, RD: OUT, BRL: BR, BR: BRD, BRD: OUT, GL: GM, GM: GD, GD: BRD,
        LL: LM, LM: LD, LD: OUT, SL: SM, SM: SD, SD: OUT, BH: BL, BL: BM, BM: BD, BD: OUT,
        PL: PM, PM: PD, PD: OUT})


def staff_vox():
    return W()


def rnd(x):
    return int(math.floor(x + 0.5))


def setc(v, x, y, z, c):
    v.v[(rnd(x), rnd(y), rnd(z))] = c


def col_of(c, x, y, z):
    return c(x, y, z) if callable(c) else c


# ---------- древко ----------
def wood(a, b, knot=None, seed=0, stretch=3):
    """Цвет древесины: продольные волокна (полосы вдоль Y), редкие сучки."""
    def f(x, y, z):
        n = nz(x * 3 + z, y // stretch, 0, 1, seed)
        if knot and nz(x, y, z, 2, seed + 11) > 0.93:
            return knot
        return a if n > 0.42 else b
    return f


def pole(v, y0, y1, c, bend=None, bendz=None, r=None):
    """Древко 2×2 (r=None) или круглое радиуса r вокруг оси; bend(y)/bendz(y) — сдвиг оси (кривой сук)."""
    for y in range(y0, y1 + 1):
        dx = rnd(bend(y)) if bend else 0
        dz = rnd(bendz(y)) if bendz else 0
        if r is None:
            cells = ((0, 0), (0, 1), (1, 0), (1, 1))
        else:
            cells = [(x, z) for x in range(-3, 5) for z in range(-3, 5) if math.hypot(x - AX, z - AZ) <= r]
        for (x, z) in cells:
            v.v[(x + dx, y, z + dz)] = col_of(c, x + dx, y, z + dz)


def band(v, y0, y1, r, c, cx=AX, cz=AZ):
    """Кольцо/обойма вокруг оси (заполненный диск радиуса r на высотах y0..y1)."""
    for y in range(y0, y1 + 1):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            for z in range(int(cz - r) - 1, int(cz + r) + 2):
                if math.hypot(x - cx, z - cz) <= r:
                    v.v[(x, y, z)] = col_of(c, x, y, z)


def wrap(v, y0, y1, a, b, r=1.25, every=2):
    """Обмотка хвата: чуть толще древка, полосы a/b."""
    for y in range(y0, y1 + 1):
        band(v, y, y, r, a if ((y - y0) // every) % 2 == 0 else b)


def ferrule(v, y0, c, c2=None, h=3, r=1.3):
    """Наконечник-подток снизу: обойма и острый носик."""
    band(v, y0 + 1, y0 + h, r, c)
    if c2:
        band(v, y0 + h, y0 + h, r + 0.4, c2)
    for (x, z) in ((0, 0), (0, 1), (1, 0), (1, 1)):
        v.v[(x, y0, z)] = c


# ---------- объёмные формы ----------
def sphere(v, cx, cy, cz, r, c, shell=None):
    """Шар; c(x, y, z, d) — цвет по расстоянию d от центра (0..1), shell — только оболочка толщины shell."""
    for x in range(int(cx - r) - 1, int(cx + r) + 2):
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for z in range(int(cz - r) - 1, int(cz + r) + 2):
                d = math.sqrt((x - cx) ** 2 + (y - cy) ** 2 + (z - cz) ** 2)
                if d <= r and (shell is None or d >= r - shell):
                    cc = c(x, y, z, d / r) if callable(c) else c
                    if cc:
                        v.v[(x, y, z)] = cc


def orb(v, cx, cy, cz, r, outer, core, mid=None):
    """Светящаяся сфера: ядро core, середина mid, оболочка outer (всё — неон или камень)."""
    def f(x, y, z, d):
        if d < 0.45:
            return core
        if mid and d < 0.75:
            return mid
        return outer
    sphere(v, cx, cy, cz, r, f)


def crystal(v, cx, y0, y1, r, outer, core=None, cz=AZ, sides=4, peak=0.32, twist=0.0, tx=0.0, tz=0.0):
    """Кристалл-бипирамида от y0 до y1: самый широкий на доле peak высоты.
    sides=4 — ромб в сечении, 6 — шестигранник (по L∞/L1 смеси), twist — поворот сечения по высоте."""
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        k = t / peak if t < peak else (1 - t) / (1 - peak)
        rr = r * max(0.0, k) + 0.35
        ang = twist * t
        ox, oz = cx + tx * (y - y0), cz + tz * (y - y0)
        for x in range(int(ox - r) - 2, int(ox + r) + 3):
            for z in range(int(oz - r) - 2, int(oz + r) + 3):
                dx, dz = x - ox, z - oz
                if ang:
                    dx, dz = dx * math.cos(ang) - dz * math.sin(ang), dx * math.sin(ang) + dz * math.cos(ang)
                d = abs(dx) + abs(dz) if sides == 4 else max(abs(dx) * 0.87 + abs(dz) * 0.5, abs(dz))
                if d <= rr:
                    v.v[(x, y, z)] = core if (core and d <= rr - 1.2) else outer


def rod(v, pts, c, r=0.0, step=0.35, cube=1, seg=None):
    """Прут по 3D-точкам [(x, y, z)]; r — радиус (0 — один воксель), cube=2 — сечение 2×2×2;
    c — цвет или c(x, y, z); seg(i, f) — цвет по номеру отрезка и доле (важнее c)."""
    for i in range(len(pts) - 1):
        p0, p1 = pts[i], pts[i + 1]
        L = math.dist(p0, p1)
        n = max(1, int(L / step))
        for k in range(n + 1):
            f = k / n
            p = [p0[j] + (p1[j] - p0[j]) * f for j in range(3)]
            cc = seg(i, f) if seg else (c(rnd(p[0]), rnd(p[1]), rnd(p[2])) if callable(c) else c)
            if r <= 0.01:
                h = (cube - 1) * 0.5
                bx, by, bz = rnd(p[0] - h), rnd(p[1] - h), rnd(p[2] - h)
                for dx in range(cube):
                    for dy in range(cube):
                        for dz in range(cube):
                            v.v[(bx + dx, by + dy, bz + dz)] = cc
            else:
                for dx in range(-int(r) - 1, int(r) + 2):
                    for dy in range(-int(r) - 1, int(r) + 2):
                        for dz in range(-int(r) - 1, int(r) + 2):
                            if dx * dx + dy * dy + dz * dz <= r * r:
                                setc(v, p[0] + dx, p[1] + dy, p[2] + dz, cc)


def arc_pts(cx, cy, cz, r, a0, a1, n=12, plane='xy', ry=None):
    """Точки дуги окружности (углы в градусах, 0 — +X, 90 — +Y/+Z)."""
    out = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        if plane == 'xy':
            out.append((cx + r * math.cos(a), cy + (ry or r) * math.sin(a), cz))
        else:
            out.append((cx + r * math.cos(a), cy, cz + r * math.sin(a)))
    return out


def helix(v, y0, y1, r, turns, c, phase=0.0, cx=AX, cz=AZ, thick=0.0):
    pts = []
    n = max(8, (y1 - y0) * 2)
    for i in range(n + 1):
        t = i / n
        a = phase + t * turns * 2 * math.pi
        pts.append((cx + r * math.cos(a), y0 + (y1 - y0) * t, cz + r * math.sin(a)))
    rod(v, pts, c, thick)


def prongs(v, y0, y1, n, r0, r1, c, phase=0.0, curl=1.6, cx=AX, cz=AZ, tip=None, thick=0.0):
    """n когтей-зубцов вокруг навершия: от радиуса r0 на y0 изгибаются до r1 (≈ вокруг шара) и
    сходятся к оси на вершине по доле curl (1 — до y1 снаружи, >1 — загибаются внутрь)."""
    for i in range(n):
        a = phase + i * 2 * math.pi / n
        pts = []
        for k in range(9):
            t = k / 8
            rr = r0 + (r1 - r0) * math.sin(min(1.0, t * curl) * math.pi / 2) - (max(0.0, t * curl - 1.0)) * r1 * 0.9
            pts.append((cx + rr * math.cos(a), y0 + (y1 - y0) * t, cz + rr * math.sin(a)))
        rod(v, pts, c, thick, seg=(lambda ii, f, n=len(pts): tip if (tip and ii >= n - 3) else c))


def bowl(v, cy, h, r0, r1, c, cx=AX, cz=AZ, rim=None, fill=None):
    """Чаша (жаровня): от радиуса r0 внизу до r1 вверху высотой h, стенка 1 воксель, дно сплошное.
    fill — цвет содержимого (угли) до h-1."""
    for k in range(h + 1):
        y = cy + k
        r = r0 + (r1 - r0) * k / max(1, h)
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            for z in range(int(cz - r) - 1, int(cz + r) + 2):
                d = math.hypot(x - cx, z - cz)
                if d <= r and (k == 0 or d >= r - 1.1):
                    v.v[(x, y, z)] = rim if (rim and k == h) else col_of(c, x, y, z)
                elif fill and d < r - 1.1 and k < h:
                    v.v[(x, y, z)] = col_of(fill, x, y, z)


def teardrop(v, cx, cy, cz, r, htop, c, lean=(0.0, 0.0)):
    """Капля: шар радиуса r внизу (центр cy), вверх сужается конусом на htop; lean — снос вершины (x, z).
    c(x, y, z, t) — цвет по доле высоты t (0 — низ капли, 1 — кончик)."""
    y0, y1 = int(cy - r) - 1, int(cy + htop) + 1
    for y in range(y0, y1 + 1):
        if y <= cy:
            rr = math.sqrt(max(0.0, r * r - (y - cy) ** 2))
            ox, oz = cx, cz
        else:
            f = (y - cy) / htop
            rr = r * (1 - f) ** 1.1 if f < 1 else 0
            ox, oz = cx + lean[0] * f * f, cz + lean[1] * f * f
        if rr <= 0:
            continue
        t = (y - (cy - r)) / (r + htop)
        for x in range(int(ox - rr) - 1, int(ox + rr) + 2):
            for z in range(int(oz - rr) - 1, int(oz + rr) + 2):
                if math.hypot(x - ox, z - oz) <= rr + 0.3:
                    cc = c(x, y, z, t) if callable(c) else c
                    if cc:
                        v.v[(x, y, z)] = cc


def flame(v, cx, y0, h, r, outer, core, cz=AZ, seed=0, tongues=3, tip=None):
    """Пламя: большая капля по центру и tongues капель поменьше по кругу (ниже и с наклоном наружу) —
    силуэт с несколькими языками. Цвет по высоте: низ — core, середина — outer, кончики — tip."""
    def colour(x, y, z, t):
        if t < 0.3:
            return core
        if tip and t > 0.78:
            return tip
        return outer
    teardrop(v, cx, y0 + r, cz, r, h - r, colour, lean=(math.sin(seed) * 0.8, math.cos(seed) * 0.4))
    for i in range(tongues):
        a = seed * 1.7 + i * 2 * math.pi / tongues
        rr = r * (0.55 + 0.12 * ((i + seed) % 2))
        hh = (h - r) * (0.55 + 0.15 * ((i * 5 + seed) % 3) / 2)
        teardrop(v, cx + math.cos(a) * r * 0.55, y0 + r * 0.9, cz + math.sin(a) * r * 0.55, rr, hh, colour,
                 lean=(math.cos(a) * 1.4, math.sin(a) * 1.4))


def sheet(v, fn, nt, ns, c, thick=1):
    """Поверхность-лист: fn(t, s) → (x, y, z), t, s ∈ [0, 1]; c(t, s) или цвет. thick — слои по Z."""
    for i in range(nt + 1):
        for j in range(ns + 1):
            t, s = i / nt, j / ns
            p = fn(t, s)
            if p is None:
                continue
            cc = c(t, s) if callable(c) else c
            if cc is None:
                continue
            for dz in range(thick):
                setc(v, p[0], p[1], p[2] + dz, cc)


def petal(v, cx, cy, cz, angle, length, width, tilt0, tilt1, c, r0=0.8):
    """Лепесток вокруг оси: из точки на радиусе r0 под углом angle (°) уходит наружу и вверх,
    наклон от tilt0 до tilt1 (° над горизонтом); ширина по синусу. c(t, s)."""
    a = math.radians(angle)
    ux, uz = math.cos(a), math.sin(a)
    tx, tz = -uz, ux

    def fn(t, s):
        phi = math.radians(tilt0 + (tilt1 - tilt0) * t)
        L = length * t
        # интеграл направления упрощённо: средний наклон до t
        phm = math.radians(tilt0 + (tilt1 - tilt0) * t * 0.5)
        rad = r0 + L * math.cos(phm)
        y = cy + L * math.sin(phm)
        w = (s - 0.5) * width * math.sin(math.pi * min(1.0, t * 0.92 + 0.08))
        return (cx + ux * rad + tx * w, y, cz + uz * rad + tz * w)
    sheet(v, fn, max(6, int(length * 3)), max(4, int(width * 3)), c)


def leaf_xy(v, x0, y0, z, dx, dy, length, width, c, mid=None):
    """Лист в плоскости XY: от (x0, y0) по направлению (dx, dy), прожилка mid."""
    n = math.hypot(dx, dy) or 1
    ux, uy = dx / n, dy / n
    px, py = -uy, ux

    def fn(t, s):
        w = (s - 0.5) * width * math.sin(math.pi * t)
        return (x0 + ux * length * t + px * w, y0 + uy * length * t + py * w, z)
    sheet(v, fn, max(6, int(length * 3)), max(4, int(width * 3)),
          (lambda t, s: mid if (mid and abs(s - 0.5) < 0.12) else c))


def ring_xy(v, cx, cy, r_out, r_in, c, z0=0, z1=1):
    """Кольцо в плоскости XY (обод, циферблат) толщиной z0..z1."""
    for x in range(int(cx - r_out) - 1, int(cx + r_out) + 2):
        for y in range(int(cy - r_out) - 1, int(cy + r_out) + 2):
            d = math.hypot(x - cx, y - cy)
            if r_in <= d <= r_out:
                for z in range(z0, z1 + 1):
                    v.v[(x, y, z)] = col_of(c, x, y, z)


def disc_xy(v, cx, cy, r, c, z0=0, z1=1):
    ring_xy(v, cx, cy, r, -1, c, z0, z1)


def ring_xz(v, cy, r_out, r_in, c, cx=AX, cz=AZ, h=0):
    """Горизонтальное кольцо (нимб, обруч) вокруг оси на высоте cy."""
    for x in range(int(cx - r_out) - 1, int(cx + r_out) + 2):
        for z in range(int(cz - r_out) - 1, int(cz + r_out) + 2):
            d = math.hypot(x - cx, z - cz)
            if r_in <= d <= r_out:
                for y in range(cy, cy + h + 1):
                    v.v[(x, y, z)] = col_of(c, x, y, z)


def cage(v, y0, y1, r, n, c, cx=AX, cz=AZ, phase=0.0, bulge=True, thick=0.0):
    """Клетка-фонарь из n прутьев: выпуклые дуги от оси внизу до оси вверху."""
    for i in range(n):
        a = phase + i * 2 * math.pi / n
        pts = []
        for k in range(11):
            t = k / 10
            rr = r * (math.sin(math.pi * t) if bulge else 1.0)
            rr = max(rr, 0.6)
            pts.append((cx + rr * math.cos(a), y0 + (y1 - y0) * t, cz + rr * math.sin(a)))
        rod(v, pts, c, thick)


def box(v, x0, x1, y0, y1, z0, z1, c):
    for x in range(min(x0, x1), max(x0, x1) + 1):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            for z in range(min(z0, z1), max(z0, z1) + 1):
                v.v[(x, y, z)] = col_of(c, x, y, z)


def shell_box(v, x0, x1, y0, y1, z0, z1, c):
    """Только стенки коробки (фонарь, рамка)."""
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            for z in range(z0, z1 + 1):
                if x in (x0, x1) or y in (y0, y1) or z in (z0, z1):
                    v.v[(x, y, z)] = col_of(c, x, y, z)


def finish(v, rough_outline=True):
    """Фаска + обводка (как у оружия воина). Неон не трогается."""
    bevel(v)
    if rough_outline:
        outline(v)
    return v
