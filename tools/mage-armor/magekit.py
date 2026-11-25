"""magekit — воксельная броня мага (шляпы, накидки, плащи) для героя R15.
Каждая деталь — Piece: воксели в осях части тела R15 (X вправо, Y вверх, перед −Z), ребро V стадов,
ячейка n занимает [n·V, (n+1)·V), центр (n+0.5)·V. Сначала деталь заполняется «материалами»
(fill), затем shade() раскрашивает материалы по рампам (тёмный/средний/светлый/блик) с освещением
по нормали из соседей и лёгким дизерингом; deco() — роспись поверх (звёзды, руны, кант).
Свечение — материал, начинающийся с «!», становится отдельным неоновым мешем."""
import math, hashlib
import numpy as np

V = 0.125
LIGHT = np.array([0.42, 0.72, -0.55]); LIGHT = LIGHT / np.linalg.norm(LIGHT)


def H(*a):
    h = hashlib.blake2b(repr(a).encode(), digest_size=4).digest()
    return int.from_bytes(h, 'little') / 2 ** 32


def cen(n):
    return (n + 0.5) * V


def crange(lo, hi):
    return range(math.ceil(lo / V - 0.5), math.floor(hi / V - 0.5) + 1)


def lerp_hex(a, b, t):
    a = [int(a[i:i + 2], 16) for i in (1, 3, 5)]; b = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return '#%02X%02X%02X' % tuple(round(a[k] + (b[k] - a[k]) * t) for k in range(3))


class Piece:
    def __init__(s, name, part, slot):
        s.name = name; s.part = part; s.slot = slot   # slot: helm | armor | cape
        s.m = {}        # (i,j,k) -> материал
        s.c = {}        # (i,j,k) -> '#hex' | '!#hex' (после shade)
        s.hinge = None  # для плаща: шарнир в осях UpperTorso (стады)
        s.order = 0
        s.face = set()  # ячейки лица (не поднимаются вместе со шляпой)

    def lift(s, n):
        """Поднять всё, кроме лица, на n вокселей (шляпа выше — глаза под полями видны)."""
        for attr in ('m', 'c'):
            d = getattr(s, attr)
            keep = {key: v for key, v in d.items() if key in s.face}
            moved = {(i, j + n, k): v for (i, j, k), v in d.items() if (i, j, k) not in s.face}
            keep.update(moved)
            setattr(s, attr, keep)

    # ---------- заполнение
    def fill(s, lo, hi, inside, mat):
        """inside(x, y, z) → bool | материал (str); mat — материал по умолчанию или fn(x,y,z)->str."""
        for i in crange(lo[0], hi[0]):
            x = cen(i)
            for j in crange(lo[1], hi[1]):
                y = cen(j)
                for k in crange(lo[2], hi[2]):
                    z = cen(k)
                    r = inside(x, y, z)
                    if not r:
                        continue
                    m = r if isinstance(r, str) else (mat(x, y, z) if callable(mat) else mat)
                    if m:
                        s.m[(i, j, k)] = m

    def carve(s, fn):
        for key in list(s.m):
            if fn(cen(key[0]), cen(key[1]), cen(key[2])):
                del s.m[key]

    def recolor(s, fn):
        """fn(x,y,z,mat) → новый материал | None."""
        for key, m in list(s.m.items()):
            r = fn(cen(key[0]), cen(key[1]), cen(key[2]), m)
            if r:
                s.m[key] = r

    def cell(s, x, y, z, mat):
        s.m[(math.floor(x / V), math.floor(y / V), math.floor(z / V))] = mat

    # ---------- раскраска
    def shade(s, ramps, light=LIGHT, contrast=1.0, dither=0.12, seed=0):
        occ = set(s.m)
        out = {}
        for key, m in s.m.items():
            if m.startswith('!'):
                out[key] = m; continue
            if m.startswith('#'):
                out[key] = m; continue
            name, _, bias = m.partition('@')
            bias = float(bias) if bias else 0.0
            ramp = ramps[name]
            i, j, k = key
            n = np.zeros(3)
            for di in (-2, -1, 0, 1, 2):
                for dj in (-2, -1, 0, 1, 2):
                    for dk in (-2, -1, 0, 1, 2):
                        if (di or dj or dk) and (i + di, j + dj, k + dk) not in occ:
                            w = 1.0 / (abs(di) + abs(dj) + abs(dk))
                            n += np.array([di, dj, dk]) * w
            ln = np.linalg.norm(n)
            if ln < 1e-6:
                lv = 0.3
            else:
                lv = float(np.dot(n / ln, light))
            lv = lv * contrast + bias + (H(seed, s.name, i, j, k) - 0.5) * 2 * dither
            idx = 0 if lv < -0.25 else 1 if lv < 0.22 else 2 if lv < 0.62 else 3
            idx = min(idx, len(ramp) - 1)
            out[key] = ramp[idx]
        s.c = out

    def deco(s, fn):
        """Роспись после shade: fn(x, y, z, i, j, k, hex, normals) → hex | None. normals — открытые стороны."""
        occ = s.c
        for key, c in list(occ.items()):
            i, j, k = key
            nb = [d for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
                  if (i + d[0], j + d[1], k + d[2]) not in occ]
            if not nb:
                continue
            r = fn(cen(i), cen(j), cen(k), i, j, k, c, nb)
            if r:
                occ[key] = r


# ---------- формы (стады, оси детали)

def bezier(p0, p1, p2, p3, t):
    a = (1 - t) ** 3; b = 3 * (1 - t) ** 2 * t; c = 3 * (1 - t) * t ** 2; d = t ** 3
    return np.array(p0) * a + np.array(p1) * b + np.array(p2) * c + np.array(p3) * d


def tube(spine, radius, samples=140):
    """Объединение сфер вдоль кривой spine(t)→xyz с радиусом radius(t). → inside(x,y,z) и габарит."""
    ts = np.linspace(0, 1, samples)
    P = np.array([spine(t) for t in ts]); R = np.array([radius(t) for t in ts])
    lo = (P - R[:, None]).min(0) - V; hi = (P + R[:, None]).max(0) + V

    def inside(x, y, z):
        d = np.sqrt(((P - np.array([x, y, z])) ** 2).sum(1))
        return bool((d <= R).any())
    return inside, lo, hi, P, R


def tube_t(P, x, y, z):
    """Параметр t ближайшей точки кривой (0..1)."""
    d = ((P - np.array([x, y, z])) ** 2).sum(1)
    return float(np.argmin(d)) / (len(P) - 1)


def box(x0, x1, y0, y1, z0, z1):
    return lambda x, y, z: x0 <= x <= x1 and y0 <= y <= y1 and z0 <= z <= z1
