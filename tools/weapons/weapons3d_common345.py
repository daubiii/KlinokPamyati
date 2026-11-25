"""Общие детали оружия этажей 3–5 (поверх weapons3d.py). Формат тот же: воксель 0,125 стада,
Y — вдоль оружия (кисть около SPEC[id][1]), X — поперёк (плоскость клинка), Z — толщина, '!#hex' — неон."""
import math
from weapons3d import W, nz, outline, bevel, VS, OUT, DARKER, LIGHTER


def shades(pairs):
    """Добавить пары «цвет → темнее» для фаски и обводки (LIGHTER пересчитывается)."""
    DARKER.update(pairs)
    LIGHTER.clear(); LIGHTER.update({v: k for k, v in DARKER.items() if v != OUT})


def put(v, x, y, z, c):
    v.v[(int(x), int(y), int(z))] = c


def shaft(v, y0, y1, a, b, band=None, every=4, w=(0, 1), zz=(0, 1)):
    """Древко/рукоять 2×2: чередование a/b, полоса band каждые every."""
    for y in range(y0, y1 + 1):
        c = a if y % 2 else b
        if band and (y - y0) % every == 0: c = band
        for x in range(w[0], w[1] + 1):
            for z in range(zz[0], zz[1] + 1):
                v.v[(x, y, z)] = c


def collar(v, y0, y1, r, c, c2=None):
    """Кольцо-обойма вокруг оси рукояти (центр 0.5, 0.5)."""
    v.disc_xz(0.5, 0, 0.5, r, y0, y1, lambda x, y, z: (c2 if (c2 and y == y1) else c))


def ellipsoid(v, cx, cy, cz, rx, ry, rz, colorfn, rough=0.0, seed=0, power=2.0):
    for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for z in range(int(cz - rz) - 1, int(cz + rz) + 2):
                d = (abs(x - cx) / rx) ** power + (abs(y - cy) / ry) ** power + (abs(z - cz) / rz) ** power
                if rough: d += (nz(x, y, z, 2, seed) - 0.5) * rough
                if d <= 1.0:
                    c = colorfn(x, y, z)
                    if c: v.v[(x, y, z)] = c


def blade(v, y0, y1, prof, pal, thick=None):
    """Клинок по профилю: prof(t) → (off, lo_half, hi_half) — центр и полуширины к −X и +X.
    pal: dict back, mid, ridge, light, edge (кромка — на +X), можно fn(x, y, t) → цвет.
    thick(t, k) → толщина по Z; k = 0 у кромок, растёт к центру."""
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, (y1 - y0))
        off, a, b = prof(t)
        lo = int(round(off - a)); hi = int(round(off + b))
        if hi < lo: continue
        for x in range(lo, hi + 1):
            if x == hi: c = pal['edge']
            elif x == hi - 1 and hi - lo >= 2: c = pal['light']
            elif x == lo and hi - lo >= 2: c = pal['back']
            elif abs(x - off) <= 0.6: c = pal['ridge']
            else: c = pal['mid']
            if callable(c): c = c(x, y, t)
            k = min(x - lo, hi - x)
            tz = thick(t, k) if thick else (3 if k >= 2 else (2 if k == 1 else 1))
            v.col(x, y, max(1, tz), c)


def motes(v, pts, c, c2=None):
    """Парящие неоновые искры вокруг оружия (часть меша свечения)."""
    for (x, y, z) in pts:
        v.v[(x, y, z)] = c
        if c2: v.v[(x, y + 1, z)] = c2


def line(v, p0, p1, c, t=1, steps=None):
    (x0, y0), (x1, y1) = p0, p1
    n = steps or int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for i in range(n + 1):
        f = i / n
        v.col(int(round(x0 + (x1 - x0) * f)), int(round(y0 + (y1 - y0) * f)), t, c(i) if callable(c) else c)


def speckle(v, seed, amount, colors, ymin=-999, ymax=999, only=None, cell=2):
    """Пятна (ржавчина, сажа, патина): кластерами, а не шумом."""
    for key in list(v.v):
        i, j, k = key; c = v.v[key]
        if c.startswith('!') or c == OUT or not (ymin <= j <= ymax): continue
        if only and c not in only: continue
        n = nz(i, j, k, cell, seed)
        if n < amount:
            v.v[key] = colors[0] if nz(i, j, k, 1, seed + 3) < 0.55 or len(colors) == 1 else colors[1]


# ---------- легендарки и секретки (переделка 03.11.2026) ----------
def surface(v, x, y):
    """Крайние z столбца (x, y) — лицевая и тыльная грань."""
    zs = [k[2] for k in v.v if k[0] == x and k[1] == y]
    return (min(zs), max(zs)) if zs else None


def inlay(v, cells, c, both=True):
    """Неоновая инкрустация: перекрасить лицевую (и тыльную) грань в клетках cells [(x, y)].
    Ставить после outline/bevel, иначе контур перекрасит края."""
    cols = {}
    for (x, y, z) in v.v:
        cols.setdefault((x, y), []).append(z)
    for (x, y) in cells:
        zs = cols.get((x, y))
        if not zs: continue
        v.v[(x, y, max(zs))] = c(x, y) if callable(c) else c
        if both: v.v[(x, y, min(zs))] = c(x, y) if callable(c) else c


def gem(v, cx, cy, r, core, rim, mid=None, depth=1, zlo=-1, zhi=1):
    """Камень в оправе в плоскости XY: ободок по толщине zlo..zhi, неоновое ядро выступает на depth за обе грани."""
    for x in range(int(cx - r) - 1, int(cx + r) + 2):
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            d = math.hypot(x - cx, y - cy)
            if d <= r:
                inner = d <= r - 1.0
                c = rim if not inner else (core if d < r * 0.55 or not mid else mid)
                for z in range(zlo - (depth if inner else 0), zhi + 1 + (depth if inner else 0)):
                    v.v[(x, y, z)] = c


def branch(v, pts, c, tip=None, t=2):
    """Ветка (рог, языки пламени, отростки) по точкам [(x, y)] толщиной t; последний воксель — tip."""
    n = len(pts)
    for i in range(n - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for k in range(steps + 1):
            f = k / steps
            x, y = int(round(x0 + (x1 - x0) * f)), int(round(y0 + (y1 - y0) * f))
            cc = tip if (tip and i == n - 2 and f > 0.6) else c
            v.col(x, y, t if i < n - 2 else max(1, t - 1), cc)


def drop_islands(v, keep_min=0):
    """Убрать воксели, не связанные с основным телом (парящие искры, хлопья): связность по 26 соседям."""
    left = set(v.v); comps = []
    while left:
        start = left.pop(); stack = [start]; comp = [start]
        while stack:
            x, y, z = stack.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    for dz in (-1, 0, 1):
                        n = (x + dx, y + dy, z + dz)
                        if n in left:
                            left.remove(n); stack.append(n); comp.append(n)
        comps.append(comp)
    comps.sort(key=len, reverse=True)
    dropped = 0
    for comp in comps[1:]:
        # крупные детали без неона (рукоять с зазором до бойка) — часть оружия, оставляем
        if len(comp) > max(keep_min, 24) and not all(v.v[k].startswith('!') for k in comp): continue
        for k in comp: del v.v[k]
        dropped += len(comp)
    return dropped
