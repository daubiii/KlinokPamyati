"""Воксельная модель для генераторов оружия (weapons3d*.py).
Vox.v — словарь {(x, y, z): '#RRGGBB' или '!#RRGGBB' (неон)}; size — ребро вокселя в стадах.
faces() — жадное слияние граней одного цвета в прямоугольники (меньше треугольников в меше):
выдаёт (quad, normal, color), quad — 4 угла в координатах вокселей (угол вокселя (x,y,z) — его минимум)."""


class Vox:
    def __init__(self, size=0.125):
        self.size = size
        self.v = {}

    def carve(self, cond, bbox=None):
        """Удалить воксели, для которых cond(x, y, z) истинно (в пределах bbox ((x0,y0,z0),(x1,y1,z1)), если задан)."""
        for key in list(self.v):
            if bbox:
                (x0, y0, z0), (x1, y1, z1) = bbox
                if not (x0 <= key[0] <= x1 and y0 <= key[1] <= y1 and z0 <= key[2] <= z1):
                    continue
            if cond(*key):
                del self.v[key]

    def bounds(self):
        xs = [k[0] for k in self.v]; ys = [k[1] for k in self.v]; zs = [k[2] for k in self.v]
        return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))

    def faces(self):
        v = self.v
        out = []
        for axis in range(3):
            u_ax, w_ax = [a for a in range(3) if a != axis]
            for sign in (1, -1):
                # плоскости: для каждой открытой грани — слой (координата грани по axis), ячейка (u, w), цвет
                layers = {}
                for key, c in v.items():
                    nb = list(key); nb[axis] += sign
                    if tuple(nb) in v:
                        continue
                    plane = key[axis] + (1 if sign > 0 else 0)
                    layers.setdefault(plane, {})[(key[u_ax], key[w_ax])] = c
                for plane, cells in layers.items():
                    used = set()
                    for (u, w) in sorted(cells):
                        if (u, w) in used:
                            continue
                        c = cells[(u, w)]
                        # растим по u, затем по w
                        u1 = u
                        while (u1 + 1, w) in cells and (u1 + 1, w) not in used and cells[(u1 + 1, w)] == c:
                            u1 += 1
                        w1 = w
                        while True:
                            nxt = w1 + 1
                            if all((uu, nxt) in cells and (uu, nxt) not in used and cells[(uu, nxt)] == c for uu in range(u, u1 + 1)):
                                w1 = nxt
                            else:
                                break
                        for uu in range(u, u1 + 1):
                            for ww in range(w, w1 + 1):
                                used.add((uu, ww))
                        corners = []
                        for (cu, cw) in ((u, w), (u1 + 1, w), (u1 + 1, w1 + 1), (u, w1 + 1)):
                            p = [0, 0, 0]; p[axis] = plane; p[u_ax] = cu; p[w_ax] = cw
                            corners.append(tuple(p))
                        d = [0, 0, 0]; d[axis] = sign
                        out.append((corners, tuple(d), c))
        return out
