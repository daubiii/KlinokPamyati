"""Модели из деталей Roblox (Part/WedgePart/Cylinder/Ball) с поворотами.
Координаты — Roblox: X вправо, Y вверх, фасад модели смотрит в −Z. 1 единица = 1 стад."""
import math, itertools, random
from contextlib import contextmanager
import numpy as np

def rot(yaw=0, pitch=0, roll=0):
    y, p, r = map(math.radians, (yaw, pitch, roll))
    cy, sy, cp, sp, cr, sr = math.cos(y), math.sin(y), math.cos(p), math.sin(p), math.cos(r), math.sin(r)
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    Rz = np.array([[cr, -sr, 0], [sr, cr, 0], [0, 0, 1]])
    return Ry @ Rx @ Rz

PAL = {}
def col(c):
    return PAL.get(c, c)

class Part:
    __slots__ = ('cls', 'shape', 'size', 'R', 'pos', 'color', 'mat', 'transp', 'name', 'collide', 'shadow')

class Model:
    def __init__(s, name):
        s.name = name; s.parts = []; s.lights = []; s.marks = []
        s._R = np.eye(3); s._t = np.zeros(3); s._stack = []

    # ---- трансформации ----
    @contextmanager
    def at(s, pos=(0, 0, 0), yaw=0, pitch=0, roll=0):
        s._stack.append((s._R, s._t))
        s._t = s._R @ np.array(pos, float) + s._t
        s._R = s._R @ rot(yaw, pitch, roll)
        try:
            yield s
        finally:
            s._R, s._t = s._stack.pop()

    def _add(s, cls, shape, pos, size, c, mat, R, name, transp, collide):
        p = Part(); p.cls = cls; p.shape = shape
        p.size = np.array(size, float); p.R = s._R @ R
        p.pos = s._R @ np.array(pos, float) + s._t
        p.color = col(c); p.mat = mat; p.transp = transp; p.name = name or 'Part'
        if collide is None:
            v = p.size.prod()
            collide = v >= 2.0 and mat != 'Neon' and transp < 0.3
        p.collide = collide; p.shadow = True
        s.parts.append(p); return p

    def box(s, pos, size, c, mat='SmoothPlastic', yaw=0, pitch=0, roll=0, name=None, transp=0.0, collide=None):
        return s._add('Part', 'Block', pos, size, c, mat, rot(yaw, pitch, roll), name, transp, collide)

    def boxr(s, x0, y0, z0, x1, y1, z1, c, **kw):
        """Блок по двум углам (без поворота)."""
        return s.box(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), c, **kw)

    def wedge(s, pos, size, c, mat='SmoothPlastic', yaw=0, pitch=0, roll=0, name=None, transp=0.0, collide=None):
        """Клин Roblox: высокая сторона сзади (+Z), скат смотрит вперёд-вверх (−Z)."""
        return s._add('WedgePart', 'Wedge', pos, size, c, mat, rot(yaw, pitch, roll), name, transp, collide)

    def cyl(s, pos, length, diam, c, mat='SmoothPlastic', yaw=0, pitch=0, roll=0, name=None, transp=0.0, collide=None):
        """Цилиндр, ось — локальная X."""
        return s._add('Part', 'Cylinder', pos, (length, diam, diam), c, mat, rot(yaw, pitch, roll), name, transp, collide)

    def ball(s, pos, d, c, mat='SmoothPlastic', name=None, collide=False):
        return s._add('Part', 'Ball', pos, (d, d, d), c, mat, np.eye(3), name, 0.0, collide)

    def beam(s, p1, p2, w, h, c, mat='SmoothPlastic', ext=0.0, name=None, up=(0, 1, 0), collide=None):
        """Брус от p1 до p2 (длина по локальной Z), сечение w×h."""
        p1 = s._R @ np.array(p1, float) + s._t; p2 = s._R @ np.array(p2, float) + s._t
        d = p2 - p1; L = np.linalg.norm(d); z = d / L
        upv = np.array(up, float)
        if abs(np.dot(upv, z)) > 0.98: upv = np.array([1.0, 0, 0])
        x = np.cross(upv, z); x /= np.linalg.norm(x); y = np.cross(z, x)
        R = np.column_stack([x, y, z])
        p = Part(); p.cls = 'Part'; p.shape = 'Block'; p.size = np.array([w, h, L + 2 * ext]); p.R = R
        p.pos = (p1 + p2) / 2; p.color = col(c); p.mat = mat; p.transp = 0.0; p.name = name or 'Beam'
        p.collide = collide if collide is not None else (w * h * L >= 2.0)
        p.shadow = True
        s.parts.append(p); return p

    def light(s, pos, rng=16, bright=1.2, c=(255, 200, 120), shadows=False):
        s.lights.append((s._R @ np.array(pos, float) + s._t, rng, bright, c, shadows))

    def mark(s, name, pos):
        s.marks.append((name, s._R @ np.array(pos, float) + s._t))

    def add(s, other, pos=(0, 0, 0), yaw=0):
        """Вставить другую модель (копию деталей) с поворотом вокруг Y."""
        R = s._R @ rot(yaw); t = s._R @ np.array(pos, float) + s._t
        for q in other.parts:
            p = Part()
            for k in Part.__slots__: setattr(p, k, getattr(q, k))
            p.R = R @ q.R; p.pos = R @ q.pos + t
            s.parts.append(p)
        for (lp, a, b, c, sh) in other.lights: s.lights.append((R @ lp + t, a, b, c, sh))
        for (n, mp) in other.marks: s.marks.append((n, R @ mp + t))

    # ---- пиксельный спрайт (вывески) ----
    def sprite(s, rows, pal, px=0.6, depth=0.6, outline=None, glow=(), back_depth=None, name=None, two_sided=None):
        """rows: список строк, верхняя строка — верх. Локальная плоскость XY, центр в (0,0), лицо к −Z.
        Одинаковые горизонтальные прогоны сливаются, затем сливаются одинаковые прогоны в соседних строках."""
        H = len(rows); W = max(len(r) for r in rows)
        grid = [[(rows[r][c] if c < len(rows[r]) else '.') for c in range(W)] for r in range(H)]
        def runs(g):
            out = []
            for r in range(H):
                c = 0
                while c < W:
                    ch = g[r][c]
                    if ch in '. ':
                        c += 1; continue
                    c2 = c
                    while c2 + 1 < W and g[r][c2 + 1] == ch: c2 += 1
                    out.append([r, r, c, c2, ch]); c = c2 + 1
            # вертикальное слияние одинаковых прогонов
            merged = []
            for run in out:
                for m in merged:
                    if m[1] == run[0] - 1 and m[2] == run[2] and m[3] == run[3] and m[4] == run[4]:
                        m[1] = run[1]; break
                else:
                    merged.append(run)
            return merged
        for (r0, r1, c0, c1, ch) in runs(grid):
            x = ((c0 + c1 + 1) / 2 - W / 2) * px
            y = (H / 2 - (r0 + r1 + 1) / 2) * px
            k = pal[ch]
            s.box((x, y, 0), ((c1 - c0 + 1) * px, (r1 - r0 + 1) * px, depth), k,
                  mat='Neon' if ch in glow else 'SmoothPlastic', collide=False, name=(name if ch in glow and name else None))
        if outline:
            # контур: клетки, соседние с заполненными, — чуть глубже сзади
            og = [['.'] * (W + 2) for _ in range(H + 2)]
            for r in range(H):
                for c in range(W):
                    if grid[r][c] not in '. ':
                        for dr in (-1, 0, 1):
                            for dc in (-1, 0, 1):
                                og[r + 1 + dr][c + 1 + dc] = 'o'
            bd = back_depth or depth
            HH, WW = H + 2, W + 2
            save = (H, W)
            H, W = HH, WW
            for (r0, r1, c0, c1, ch) in runs(og):
                x = ((c0 + c1 + 1) / 2 - W / 2) * px
                y = (H / 2 - (r0 + r1 + 1) / 2) * px
                s.box((x, y, depth / 2 + bd / 2 - 0.01), ((c1 - c0 + 1) * px, (r1 - r0 + 1) * px, bd), outline, collide=False)
            H, W = save
        if two_sided is None: two_sided = bool(outline)
        if two_sided:
            bd = (back_depth or depth) if outline else 0.0
            with s.at((0, 0, depth + bd), yaw=180):
                s.sprite(rows, pal, px=px, depth=depth, outline=None, glow=glow, name=name, two_sided=False)

# ---------------- экспорт rbxmx ----------------
_ref = itertools.count(1)
def _r(): return 'RBX%08X' % next(_ref)
MAT = {'Plastic': 256, 'SmoothPlastic': 272, 'Neon': 288, 'Wood': 512, 'WoodPlanks': 528, 'Marble': 784,
       'Slate': 800, 'Concrete': 816, 'Granite': 832, 'Brick': 848, 'Cobblestone': 880, 'Snow': 896,
       'Metal': 1088, 'Grass': 1280, 'Sand': 1296, 'Fabric': 1312, 'Ice': 1536, 'Glass': 1568}
SHAPE = {'Ball': 0, 'Block': 1, 'Cylinder': 2}

def _u8(h):
    h = h.lstrip('#'); r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return (0xFF << 24) | (r << 16) | (g << 8) | b

def _cf(pos, R):
    x, y, z = pos
    return (f'<X>{x:.4f}</X><Y>{y:.4f}</Y><Z>{z:.4f}</Z>' +
            ''.join(f'<R{i}{j}>{R[i, j]:.6f}</R{i}{j}>' for i in range(3) for j in range(3)))

def part_xml(p, children='', ref=None):
    shape = f'<token name="shape">{SHAPE[p.shape]}</token>' if p.cls == 'Part' else ''
    return (f'<Item class="{p.cls}" referent="{ref or _r()}"><Properties>'
            f'<string name="Name">{p.name}</string><bool name="Anchored">true</bool>'
            f'<CoordinateFrame name="CFrame">{_cf(p.pos, p.R)}</CoordinateFrame>'
            f'<Color3uint8 name="Color3uint8">{_u8(p.color)}</Color3uint8>'
            f'<token name="Material">{MAT[p.mat]}</token>{shape}'
            f'<Vector3 name="size"><X>{p.size[0]:.4f}</X><Y>{p.size[1]:.4f}</Y><Z>{p.size[2]:.4f}</Z></Vector3>'
            f'<token name="TopSurface">0</token><token name="BottomSurface">0</token>'
            f'<bool name="CanCollide">{"true" if p.collide else "false"}</bool><bool name="CanTouch">false</bool>'
            f'<bool name="CastShadow">{"false" if (p.mat == "Neon" or not getattr(p, "shadow", True)) else "true"}</bool>'
            f'<float name="Transparency">{p.transp}</float></Properties>{children}</Item>')

def _xf(p, R0, t0):
    q = Part()
    for k in Part.__slots__: setattr(q, k, getattr(p, k, True if k == 'shadow' else None))
    q.R = R0 @ p.R; q.pos = R0 @ p.pos + t0
    return q

def export(m, pos=(0, 0, 0), yaw=0, streaming=None, extra=''):
    """Модель в мир: части и Base поворачиваются вокруг Y на yaw и переносятся в pos.
    Attachments — в локальных координатах Base. streaming: None | 'Atomic' | 'Persistent'."""
    R0 = rot(yaw); t0 = np.array(pos, float)
    items = [part_xml(_xf(p, R0, t0)) for p in m.parts]
    for (lp, rng, br, c, sh) in m.lights:
        L = (f'<Item class="PointLight" referent="{_r()}"><Properties>'
             f'<Color3 name="Color"><R>{c[0]/255:.3f}</R><G>{c[1]/255:.3f}</G><B>{c[2]/255:.3f}</B></Color3>'
             f'<float name="Range">{rng:.2f}</float><float name="Brightness">{br:.2f}</float>'
             f'<bool name="Shadows">{"true" if sh else "false"}</bool></Properties></Item>')
        q = Part(); q.cls = 'Part'; q.shape = 'Block'; q.size = np.array([.2, .2, .2]); q.R = np.eye(3); q.pos = R0 @ lp + t0
        q.color = '#FFFFFF'; q.mat = 'SmoothPlastic'; q.transp = 1.0; q.name = 'Light'; q.collide = False; q.shadow = False
        items.append(part_xml(q, L))
    pts = np.array([p.pos for p in m.parts]) if m.parts else np.zeros((1, 3))
    w = float(np.ptp(pts[:, 0]) + 2); d = float(np.ptp(pts[:, 2]) + 2)
    att = ''.join(f'<Item class="Attachment" referent="{_r()}"><Properties><string name="Name">{n}</string>'
                  f'<CoordinateFrame name="CFrame">{_cf((mp[0], mp[1] - 0.05, mp[2]), np.eye(3))}</CoordinateFrame></Properties></Item>'
                  for n, mp in m.marks)
    bref = _r()
    base = (f'<Item class="Part" referent="{bref}"><Properties><string name="Name">Base</string><bool name="Anchored">true</bool>'
            f'<CoordinateFrame name="CFrame">{_cf(R0 @ np.array([0, 0.05, 0]) + t0, R0)}</CoordinateFrame>'
            f'<Vector3 name="size"><X>{min(w, 2048):.2f}</X><Y>0.1</Y><Z>{min(d, 2048):.2f}</Z></Vector3><float name="Transparency">1</float>'
            f'<bool name="CanCollide">false</bool><bool name="CanQuery">false</bool><bool name="CanTouch">false</bool></Properties>{att}</Item>')
    sm = {'Atomic': 1, 'Persistent': 2}.get(streaming)
    smx = f'<token name="ModelStreamingMode">{sm}</token>' if sm else ''
    return (f'<Item class="Model" referent="{_r()}"><Properties><string name="Name">{m.name}</string>'
            f'<Ref name="PrimaryPart">{bref}</Ref>{smx}</Properties>{base}{"".join(items)}{extra}</Item>')

def folder(name, body):
    return f'<Item class="Folder" referent="{_r()}"><Properties><string name="Name">{name}</string></Properties>{body}</Item>'
