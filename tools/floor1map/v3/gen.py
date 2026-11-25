"""Генератор геометрии в стиле карты: боксы с ячейками палитры floor_palette.png (16×16),
шаблоны (копии готовых предметов), детали коллизии. Грани CCW снаружи, низ не рисуется."""
import math, random
import numpy as np
import comps as CM

CELL = {
    'stone': [(7, 3), (6, 3), (8, 3), (14, 3), (9, 3), (15, 3), (2, 2)],
    'stone_lit': [(14, 3), (15, 3), (9, 3), (8, 3)],
    'floor': [(0, 2), (15, 1), (1, 2), (2, 2), (1, 1), (3, 1), (0, 2), (15, 1)],
    'wood': [(9, 5), (11, 3), (12, 1), (1, 4), (6, 4), (10, 3), (13, 1), (5, 3)],
    'wood_dark': [(12, 1), (13, 1), (10, 3), (5, 3)],
    'metal': [(11, 4), (3, 6)],
    'moss': [(9, 1)],
    'dirt': [(6, 1), (4, 1), (12, 1)],
    'void': [(7, 0), (15, 0), (0, 1)],
}

def uv_of(cell):
    i, j = cell
    return ((8 + 16 * i) / 256.0, 1.0 - (8 + 16 * j) / 256.0)

class MeshBuilder:
    """добавляет геометрию в зону: объекты <zone>_n<k> (палитра) и <zone>_x<k> (свечение)"""
    MAXF = 8500  # граней на объект (×2 треугольника < 20 000)

    def __init__(self, w, zone, rng=None):
        self.w = w; self.zone = zone; self.of = w.objs[zone]
        self.uvi = {}
        self.cur = None; self.k = 0
        self.glow = {}  # цвет -> (Obj, oi)
        self.colors = {}  # имя объекта свечения -> цвет
        self.rng = rng or random.Random(7)

    def _obj(self, name):
        from f1lib import Obj
        o = Obj(name); self.of.objects.append(o)
        return o, len(self.of.objects) - 1

    def _target(self, glow=None):
        if glow:
            g = self.glow.get(glow)
            if not g or len(g[0].faces) > self.MAXF:
                n = sum(1 for _ in self.colors) + 1
                name = f'{self.zone}_x{n}'
                g = self._obj(name); self.glow[glow] = g; self.colors[name] = glow
            return g
        if not self.cur or len(self.cur[0].faces) > self.MAXF:
            self.k += 1; self.cur = self._obj(f'{self.zone}_n{self.k}')
        return self.cur

    def _vt(self, uv):
        key = (round(uv[0], 6), round(uv[1], 6))
        if key not in self.uvi:
            self.uvi[key] = len(self.of.vt); self.of.vt.append([uv[0], uv[1]])
        return self.uvi[key]

    def pick(self, kind):
        c = CELL[kind] if isinstance(kind, str) else kind
        if isinstance(c, tuple):
            return c
        return self.rng.choice(c)

    def polys(self, polys, mat='palette', glow=None):
        """polys: [[(pos, uv)]] — грани (против часовой снаружи)"""
        o, oi = self._target(glow)
        verts = []
        faces = []
        for poly in polys:
            idx = []
            for pos, uv in poly:
                vi = len(self.of.v); self.of.v.append([float(pos[0]), float(pos[1]), float(pos[2])])
                verts.append(vi)
                idx.append((vi, self._vt(uv) if uv is not None else -1))
            o.faces.append(('glow' if glow else mat, idx)); faces.append(len(o.faces) - 1)
        c = CM.Comp(); c.zone = self.zone; c.obj = oi; c.faces = faces; c.verts = np.array(verts)
        P = np.array([self.of.v[i] for i in verts]); c.lo = P.min(0); c.hi = P.max(0)
        self.w.comps[self.zone].append(c)
        return c

    def box(self, center, size, yaw=0.0, cell='stone', glow=None, bottom=False, tilt=None):
        """yaw — поворот вокруг Y (рад, против часовой при взгляде сверху: +X → −Z);
        tilt=(ось 'x'|'z', рад) — наклон после yaw (для обломков)"""
        cx, cy, cz = center; sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
        c, s = math.cos(yaw), math.sin(yaw)
        def T(x, y, z):
            if tilt:
                ax, a = tilt; ca, sa = math.cos(a), math.sin(a)
                if ax == 'x':
                    y, z = y * ca - z * sa, y * sa + z * ca
                else:
                    x, y = x * ca - y * sa, x * sa + y * ca
            return (cx + x * c + z * s, cy + y, cz - x * s + z * c)
        p = [T(x, y, z) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
        # индексы: 0(-,-,-) 1(-,-,+) 2(-,+,-) 3(-,+,+) 4(+,-,-) 5(+,-,+) 6(+,+,-) 7(+,+,+)
        quads = [(4, 6, 7, 5), (0, 1, 3, 2), (2, 3, 7, 6), (1, 5, 7, 3), (0, 2, 6, 4)]
        if bottom:
            quads.append((0, 4, 5, 1))
        uv = uv_of(self.pick(cell)) if not glow else None
        return self.polys([[(p[i], uv) for i in q] for q in quads], glow=glow)

    def template(self, tpl, at, yaw=0.0):
        """tpl: [(glow|None, [[(pos, uv)]])] с началом координат в нуле"""
        c, s = math.cos(yaw), math.sin(yaw)
        for glow, polys in tpl:
            out = []
            for poly in polys:
                out.append([((at[0] + p[0] * c + p[2] * s, at[1] + p[1], at[2] - p[0] * s + p[2] * c), uv) for p, uv in poly])
            self.polys(out, glow=glow)

def grab_template(w, zone, glow_colors, pred, origin):
    """копия компонентов зоны (pred(comp)) в шаблон относительно origin.
    glow_colors: имя объекта → цвет (для объектов свечения)"""
    of = w.objs[zone]; out = []
    for k in w.comps[zone]:
        if not k.faces or not pred(k):
            continue
        o = of.objects[k.obj]
        glow = glow_colors.get(o.name)
        polys = []
        for fi in k.faces:
            mat, idx = o.faces[fi]
            polys.append([((of.v[vi][0] - origin[0], of.v[vi][1] - origin[1], of.v[vi][2] - origin[2]),
                           tuple(of.vt[ti]) if ti >= 0 else None) for vi, ti in idx])
        out.append((glow, polys))
    return out

# ---------------- кирпичная кладка ----------------
def brick_wall(mb, x0, x1, y0, y1, z, thick, axis='x', course=1.2, brick=(2.2, 3.4), jitter=0.06, cell='stone', face_only=False):
    """прямая стена из кирпичей вдоль axis ('x' — стена тянется по X на уровне z)"""
    rng = mb.rng
    y = y0; row = 0
    while y < y1 - 1e-3:
        h = min(course, y1 - y)
        t = x0 + (rng.uniform(0, brick[0]) if row % 2 else 0)
        if t > x0:
            seg = [(x0, t)]
        else:
            seg = []
        while t < x1 - 1e-3:
            L = rng.uniform(*brick); e = min(t + L, x1)
            seg.append((t, e)); t = e
        for a, b in seg:
            if b - a < 0.05:
                continue
            j = rng.uniform(-jitter, jitter)
            if axis == 'x':
                mb.box(((a + b) / 2, y + h / 2, z + j), (b - a - 0.04, h - 0.04, thick), cell=cell)
            else:
                mb.box((z + j, y + h / 2, (a + b) / 2), (thick, h - 0.04, b - a - 0.04), cell=cell)
        y += h; row += 1

def ring_wall(mb, cx, cz, r0, r1, y0, y1, a0=0, a1=2 * math.pi, seg=4.0, course=1.2, skip=None, cell='stone', jitter=0.08):
    """кольцевая стена (r0 — внутренний радиус); skip(angle) → True — проём.
    Углы: a=0 → +X, a=π/2 → −Z (север)."""
    rng = mb.rng
    rm = (r0 + r1) / 2; th = r1 - r0
    n = max(3, int((a1 - a0) * rm / seg))
    da = (a1 - a0) / n
    y = y0; row = 0
    while y < y1 - 1e-3:
        h = min(course, y1 - y)
        off = 0.5 * da if row % 2 else 0
        for i in range(n + (1 if off else 0)):
            aa = a0 + i * da - off; bb = aa + da
            aa = max(aa, a0); bb = min(bb, a1)
            if bb - aa < 1e-3:
                continue
            am = (aa + bb) / 2
            if skip and skip(am):
                continue
            L = 2 * rm * math.sin((bb - aa) / 2) + 0.12
            j = rng.uniform(-jitter, jitter)
            x = cx + math.cos(am) * (rm + j); z = cz - math.sin(am) * (rm + j)
            mb.box((x, y + h / 2, z), (th, h - 0.04, L), yaw=am, cell=cell)
        y += h; row += 1
    return n, da

def merlons(mb, pts_yaw, y, size=(1.4, 1.3, 2.0), cell='stone_lit'):
    for (x, z, yaw) in pts_yaw:
        mb.box((x, y + size[1] / 2, z), size, yaw=yaw, cell=cell)
