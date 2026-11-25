"""Этаж 1 v3: расширение, руины без крыш, новый двор башни. Запуск: python3 build.py <out>"""
import sys, os, math, random, re, json
import numpy as np
import engine as E, gen as G, f1lib

OUT = sys.argv[1] if len(sys.argv) > 1 else 'out'
w = E.World()
HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(HERE, 'base') + '/'   # конфиги до v3 (вход сборки)
FMD = open(BASE + 'FloorMapData.lua', encoding='utf-8').read()
GLOW = {m.group(1): m.group(2) for m in re.finditer(r'name = "(\w+)", role = "glow".*?fromHex\("(#\w+)"\)', FMD)}
PT_OPS = []  # преобразования точек по порядку

def in_xz(k, x0, z0, x1, z1):
    return k.lo[0] >= x0 and k.hi[0] <= x1 and k.lo[2] >= z0 and k.hi[2] <= z1
def c_in_xz(k, x0, z0, x1, z1):
    c = (k.lo + k.hi) / 2
    return x0 <= c[0] <= x1 and z0 <= c[2] <= z1
def p_box(p):
    lo, hi = p.aabb(); return np.array(lo), np.array(hi)

def beam(k, L=14):
    d = k.hi - k.lo
    return max(d[0], d[2]) >= L and min(d[0], d[2]) <= 2.6 and d[1] <= 2.6
# ---------- шаблоны из старой башни ----------
BRAZIER = G.grab_template(w, 'tower', GLOW, lambda k: math.hypot((k.lo[0] + k.hi[0]) / 2 + 21.65, (k.lo[2] + k.hi[2]) / 2 + 277.5) < 1.9
                          and k.hi[1] < 5.5, (-21.65, 0, -277.5))
print('жаровня:', len(BRAZIER), 'компонентов')

# ================= 1. удаление =================
# башня: всё, кроме решётки выхода (переедет)
E.delete(w, pred_mesh=lambda z, k: True, zones=['tower'], tag='tower mesh')
E.delete(w, pred_part=lambda p: w.model_of(p) != 'Gate_TowerExit', zones=['tower'], tag='tower parts')
# мост к залу на высоте 24 (если часть мешей в зоне зала)
E.delete(w, pred_mesh=lambda z, k: k.lo[1] >= 19 and in_xz(k, 8, -296, 46.2, -284), zones=['hall'], tag='hall bridge')

# Арсенал: балки, крыша, колонны → обломки
ARM = (-27.5, -166, 27.5, -115.5)
COLS = [(-12, -128), (12, -128), (-12, -152), (12, -152), (-14, -140), (14, -140)]
def near_col(c, r=2.6):
    return any(math.hypot(c[0] - x, c[2] - z) < r for x, z in COLS)
E.delete(w, pred_mesh=lambda z, k: ((in_xz(k, *ARM) and k.lo[1] >= 8.5) or (c_in_xz(k, *ARM) and k.lo[1] >= 7 and beam(k, 10))) and not (near_col((k.lo + k.hi) / 2, 3.2) and max(k.hi[0] - k.lo[0], k.hi[2] - k.lo[2]) < 5), zones=['armory'], tag='armory roof')
rng = random.Random(11)
COL_H = {c: rng.choice([1.6, 2.2, 2.6, 3.0]) for c in COLS}
def col_h(c):
    best = min(COLS, key=lambda q: math.hypot(c[0] - q[0], c[2] - q[1])); return COL_H[best]
E.clamp_top(w, col_h, lambda z, k: near_col((k.lo + k.hi) / 2, 2.8) and (k.hi[0] - k.lo[0]) < 5 and (k.hi[2] - k.lo[2]) < 5,
            pred_part=lambda p: p.folder == 'Collision' and near_col((p_box(p)[0] + p_box(p)[1]) / 2, 2.8) and p.size[0] < 5 and p.size[2] < 5,
            zones=['armory'], tag='armory columns')
E.delete(w, pred_part=lambda p: p.folder == 'Collision' and p_box(p)[0][1] >= 8.5 and in_xz(type('k', (), {'lo': p_box(p)[0], 'hi': p_box(p)[1]}), -26, -164, 26, -116), zones=['armory'], tag='armory roof col')

# Склад и кузня: руины — стропила и подвесное прочь, стены 8..9,6 зубцами
def jag(seed):
    def f(c):
        q = (math.floor(c[0] / 3.0), math.floor(c[2] / 3.0))
        return 8.0 + 0.4 * random.Random(f'{seed}{q}').randint(0, 4)
    return f
for zone, inner in (('warehouse', (-67, -38, -43, -1)), ('forge', (42, -150, 63, -128))):
    E.delete(w, pred_mesh=lambda z, k, b=inner: (in_xz(k, *b) and k.lo[1] >= 6.5) or (c_in_xz(k, *b) and k.lo[1] >= 6 and beam(k, 8)), zones=[zone], tag=zone + ' rafters')
    E.clamp_top(w, jag(zone), lambda z, k: True, zones=[zone], tag=zone + ' walls')
    E.clamp_top(w, lambda c: 8.0, lambda z, k: False, pred_part=lambda p: p.folder == 'Collision', zones=[zone], tag=zone + ' walls col')

# Привал: плоская крыша
E.delete(w, pred_mesh=lambda z, k: k.lo[1] >= 14.8, pred_part=lambda p: p.folder == 'Collision' and p_box(p)[0][1] >= 14.8, zones=['rest1'], tag='rest1 roof')
# Часовня: двускатная крыша
E.delete(w, pred_mesh=lambda z, k: k.hi[1] > 15.2 or (in_xz(k, 100, -303, 131, -275) and k.lo[1] >= 12.8), pred_part=lambda p: p.folder == 'Collision' and p_box(p)[0][1] >= 14.5, zones=['chapel'], tag='chapel roof')
# Зал лебёдки: потолочные балки
E.delete(w, pred_mesh=lambda z, k: in_xz(k, 47, -316, 99, -263) and k.lo[1] >= 20 and beam(k), zones=['hall'], tag='hall beams')

# ================= 2. расширение =================
# Улица: южная половина (двор, вход) уезжает на +8 по Z
PT_OPS.append(('street', E.widen(w, 2, 26.0, 8.0, tag='street')))
# Мост: северный край −8, только между привалом и арсеналом
def bridge_name(m):
    a, b = m.split('_')[1:]
    return f'Bridge_{a}_{int(b) + 2}'
PT_OPS.append(('bridge', E.widen(w, 2, -142.0, -8.0, R={0: (-107, -26)}, zones=['bridge'], rename_dup=bridge_name, tag='bridge')))
# Галерея: 8 → 20 (по 6 в каждую сторону, двумя шагами по 3)
RG = {0: (-20, 20), 2: (-252.05, -176.95)}
for _ in range(2):
    PT_OPS.append(('gallery', E.widen(w, 0, 0.5, 3.0, R=RG, tag='gallery E')))
    PT_OPS.append(('gallery', E.widen(w, 0, -0.5, -3.0, R=RG, tag='gallery W')))

for l in w.log:
    print(l)
import pickle
pickle.dump(w, open('stage1.pkl', 'wb'))

# ================= 3. новая геометрия =================
OX, OZ = 0.0, -292.0          # центр двора
RIN, ROUT, WALLH = 30.0, 32.5, 12.0
TX, TZ, TR, TH = 0.0, -329.0, 11.0, 26.0   # башня
def ang_xz(a, r, cx=OX, cz=OZ):
    return cx + math.cos(a) * r, cz - math.sin(a) * r
def yawR(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]
COLS_STONE = (92, 86, 104)
def col(zone, pos, size, a=None, name='Col', folder='Collision', **kw):
    return w.new_part(zone, folder, name, pos, size, color=COLS_STONE, transparency=1.0 if folder == 'Collision' else 0.0,
                      rot=yawR(a) if a is not None else None, **kw)

# старый пандус галереи к башне (z < −252) — прочь
E.delete(w, pred_mesh=lambda z, k: (k.lo[2] + k.hi[2]) / 2 < -252.2, pred_part=lambda p: (p_box(p)[0][2] + p_box(p)[1][2]) / 2 < -252.2,
         zones=['gallery'], tag='old gallery ramp')

mb = G.MeshBuilder(w, 'tower', random.Random(5))
GLOWC = {}
# --- земля: плита и плитняк двора
mb.box((0, -0.65, -297), (84, 1.0, 96), cell=(0, 1))
ring_r = 1.0
while ring_r < RIN + 0.6:
    n = max(6, int(2 * math.pi * ring_r / 2.6))
    off = mb.rng.uniform(0, 2 * math.pi)
    for i in range(n):
        a = off + i * 2 * math.pi / n
        x, z = ang_xz(a, ring_r)
        L = 2 * math.pi * ring_r / n - 0.12
        mb.box((x, -0.1 + mb.rng.uniform(-0.04, 0.03), z), (1.9, 0.26, L), yaw=a, cell=mb.rng.choice(['floor'] * 8 + ['moss', 'dirt', 'stone']))
    ring_r += 2.0
for i in range(70):  # мусор, мох
    r = math.sqrt(mb.rng.uniform(4, RIN * RIN * 0.95)); a = mb.rng.uniform(0, 2 * math.pi)
    x, z = ang_xz(a, r)
    s = mb.rng.uniform(0.3, 0.9)
    mb.box((x, 0.08 + s * 0.15, z), (s, s * 0.35, s * mb.rng.uniform(0.6, 1.4)), yaw=mb.rng.uniform(0, 3), cell=mb.rng.choice(['moss', 'dirt', 'floor', 'stone']))
col('tower', (0, -0.5, -296), (72, 1.0, 84))
# --- стена двора
def skip_ring(a):
    da = lambda t: abs((a - t + math.pi) % (2 * math.pi) - math.pi)
    if da(-math.pi / 2) < math.radians(19.5):
        return True   # юг: лестница с галереи
    if da(0) < math.radians(10.5):
        return True   # восток: выход к залу
    x, z = ang_xz(a, (RIN + ROUT) / 2)
    return math.hypot(x - TX, z - TZ) < TR - 0.3
n, da = G.ring_wall(mb, OX, OZ, RIN, ROUT, 0, WALLH, seg=3.6, skip=skip_ring)
for i in range(n):
    a = i * da + da / 2
    if skip_ring(a):
        continue
    x, z = ang_xz(a, (RIN + ROUT) / 2)
    col('tower', (x, WALLH / 2, z), (ROUT - RIN, WALLH, 2 * ((RIN + ROUT) / 2) * math.sin(da / 2) + 0.15), a)
    if i % 2 == 0:
        mb.box((x, WALLH + 0.65, z), (ROUT - RIN - 0.2, 1.3, 1.6), yaw=a, cell='stone_lit')
# --- башня
G.ring_wall(mb, TX, TZ, TR - 2.2, TR, 0, TH, seg=3.0, course=1.3)
nt = 28
for i in range(nt):
    a = (i + 0.5) * 2 * math.pi / nt
    x, z = ang_xz(a, TR - 1.1, TX, TZ)
    if math.hypot(x - OX, z - OZ) < RIN + 4:
        col('tower', (x, TH / 2, z), (2.2, TH, 2 * (TR - 1.1) * math.sin(math.pi / nt) + 0.2), a)
    if i % 2 == 0:
        mb.box((x, TH + 0.75, z), (2.0, 1.5, 1.7), yaw=a, cell='stone_lit')
mb.box((TX, TH - 0.6, TZ), (2 * TR - 3.6, 0.8, 2 * TR - 3.6), cell=(1, 1))
for h in (7.0, 14.0, 20.5):   # окна-бойницы
    for a in (math.radians(-60), math.radians(-90), math.radians(-120)):
        x, z = ang_xz(a + (0.35 if h == 14.0 else 0), TR + 0.02, TX, TZ)
        mb.box((x, h, z), (0.3, 2.2, 0.8), yaw=a + (0.35 if h == 14.0 else 0), cell=(7, 0))
for a in (math.radians(-60), math.radians(-120), math.radians(-90)):   # жаровни наверху
    x, z = ang_xz(a, TR - 4.5, TX, TZ)
    mb.template(BRAZIER, (x, TH - 0.2, z))
# знамя на башне над насестом B
mb.box((TX, 17.5, TZ + TR + 0.12), (3.2, 8.0, 0.15), cell=(14, 4))

# --- насесты A, B, C (Dynamic: доски, подкосы, подпора со светящимися обручами)
WOOD = [(122, 92, 72), (107, 78, 61), (98, 74, 52), (113, 85, 59)]
PERCH = {}
def perch(name, cx, cz, a, wall_r_dir):
    """a — направление «к центру двора» (рад, наша система углов); насест 7×5, верх на 8"""
    m = w.new_model('tower', 'Dynamic', 'Perch_' + name, attrs={'Perch': name})
    ux, uz = math.cos(a), -math.sin(a)          # к центру двора
    tx, tz = -uz, ux                            # вдоль стены
    R = yawR(a)
    rr = random.Random(name)
    for i in range(7):                          # доски поперёк, вдоль радиуса
        o = -3.0 + i
        w.new_part('tower', '', f'Plank', (cx + tx * o, 7.8 + rr.uniform(-0.03, 0.03), cz + tz * o), (5.0, 0.4, 0.94),
                   color=rr.choice(WOOD), rot=R, material=528, parent=m)
    for s in (-1, 1):                           # балки под настилом и подкосы к стене
        w.new_part('tower', '', 'Joist', (cx + tx * 3.1 * s, 7.3, cz + tz * 3.1 * s), (5.2, 0.6, 0.6), color=(84, 66, 50), rot=R, material=512, parent=m)
        bx, bz = cx - ux * 1.2 + tx * 3.1 * s, cz - uz * 1.2 + tz * 3.1 * s
        w.new_part('tower', '', 'Brace', (bx, 5.4, bz), (0.5, 4.2, 0.5), color=(84, 66, 50), material=512, parent=m, can_collide=False,
                   rot=[[R[0][0], 0.0, R[0][2]], [0, 1, 0], [R[2][0], 0, R[2][2]]])
        w.new_part('tower', '', 'Post', (cx + ux * 2.2 + tx * 3.2 * s, 8.7, cz + uz * 2.2 + tz * 3.2 * s), (0.4, 1.4, 0.4), color=(84, 66, 50), material=512, parent=m)
    sx, sz = cx + ux * 1.7, cz + uz * 1.7       # подпора у переднего края
    sup = w.new_part('tower', '', 'Support', (sx, 3.7, sz), (1.6, 7.4, 1.6), color=(113, 85, 59), material=512, parent=m,
                     attrs={'PerchSupport': name})
    for h in (1.6, 3.9, 6.2):
        w.new_part('tower', '', 'Glow', (sx, h, sz), (1.85, 0.32, 1.85), color=(255, 179, 71), material=288, parent=m, can_collide=False)
    PERCH[name] = dict(stand=(cx - ux * 0.4, 8.0, cz - uz * 0.4), support=(sx, 0.0, sz), dirIn=(ux, 0, uz))
for name, bearing in (('A', 240), ('C', 120)):
    a = math.radians(90 - bearing)
    x, z = ang_xz(a, RIN - 2.5)
    perch(name, x, z, a + math.pi, None)
perch('B', TX, TZ + TR + 2.5, -math.pi / 2, None)
# под насестами — кронштейны в стене (меш)
for nm, p in PERCH.items():
    sx, _, sz = p['support']; ux, _, uz = p['dirIn']
    mb.box((sx - ux * 3.6, 6.9, sz - uz * 3.6), (1.2, 0.9, 6.6), yaw=math.atan2(uz, ux) * -1 + math.pi / 2, cell='wood_dark')

# --- пандус с галереи во двор (z −252 → −264, верх 8)
for i in range(16):
    z0 = -252.0 - 0.75 * i; top = 8.0 - 0.5 * (i + 1)
    mb.box((0, (top - 0.6) / 2, z0 - 0.375), (19.9, top + 0.6, 0.78), cell='stone' if i % 2 else 'stone_lit')
w.new_part('tower', 'Collision', 'Ramp', (0, 4, -258), (20, 8, 12), cls='WedgePart', transparency=1.0)
for s in (-1, 1):
    x = s * 10.6
    for i in range(8):
        z0 = -252.0 - 1.5 * i
        top = 8.0 - 1.0 * i + 4.0
        G.brick_wall(mb, z0 - 1.5, z0, -0.5, top, x, 1.2, axis='z', course=1.2)
        col('tower', (x, (top - 0.5) / 2 - 0.25 + 0.25, z0 - 0.75), (1.2, top + 0.5, 1.5))
    mb.box((x, 12.65, -252.75), (1.3, 1.3, 1.5), cell='stone_lit')

# --- проход к залу (восток)
for z0, z1 in ((-299.6, -297.0), (-287.0, -284.4)):
    zc = (z0 + z1) / 2
    G.brick_wall(mb, 31.0, 45.8, 0, 10, zc, z1 - z0, axis='x')
    col('tower', (38.4, 5, zc), (14.8, 10, z1 - z0))
    for x in np.arange(32.0, 45.0, 2.6):
        mb.box((x, 10.6, zc), (1.4, 1.2, z1 - z0 - 0.2), cell='stone_lit')
for x in np.arange(30.0, 46.2, 2.0):
    for z in np.arange(-296.5, -287.4, 2.0):
        mb.box((x + 1.0, -0.1, z + 1.0), (1.9, 0.26, 1.9), cell='floor')
col('tower', (38.0, -0.5, -292), (17.0, 1.0, 10.0))

def place_gate(model, cx, cz, ylo, width=10.0, height=8.0):
    ps = [p for p in w.alive_parts() if w.model_of(p) == model]
    lo = np.min([p.aabb()[0] for p in ps], 0); hi = np.max([p.aabb()[1] for p in ps], 0)
    c0 = (lo + hi) / 2; ax = 2 if (hi[2] - lo[2]) > (hi[0] - lo[0]) else 0
    kw = width / (hi[ax] - lo[ax]); kh = height / (hi[1] - lo[1])
    for p in ps:
        q = list(p.cf['p']); sz = list(p.size)
        Rm = np.array(p.cf['R'])
        new = [cx if ax == 2 else cx + (q[0] - c0[0]) * kw, ylo + (q[1] - lo[1]) * kh, cz + (q[2] - c0[2]) * (kw if ax == 2 else 1)]
        jy = int(np.argmax(np.abs(Rm[1]))); jw = int(np.argmax(np.abs(Rm[ax])))
        sz[jy] *= kh
        if sz[jw] > 1.0:
            sz[jw] *= kw
        w.part_set(p, pos=new, size=sz)
# вход во двор: копия решётки арсенала, 20 шириной, у подножия пандуса
_src = [p for p in w.alive_parts() if w.model_of(p) == 'Gate_ArmoryN'][0]
_mi = w.model_dup(w.parent[_src.item], (0, 0, 0), rename='Gate_TowerIn')
_par = w.parent[_mi]; _par.remove(_mi)
_tzone = [it for it in [x for x in w.tree.getroot().iter('Item') if f1lib.name_of(x) == 'tower' and x.get('class') == 'Folder'][0].findall('Item') if f1lib.name_of(it) == 'Dynamic'][0]
_tzone.append(_mi); w.parent[_mi] = _tzone
for _p in w.parts:
    if not getattr(_p, 'dead', False) and len(_p.path) > 3 and _p.path[3] == 'Gate_TowerIn':
        _p.path = ['Floor1Map', 'tower', 'Dynamic', 'Gate_TowerIn']
place_gate('Gate_TowerIn', 0.0, -264.6, 0.0, width=20.4, height=8.0)
place_gate('Gate_TowerExit', 38.0, -292.0, 0.0)
place_gate('Gate_HallIn', 46.8, -292.0, 0.0)

# --- проём в западной стене зала (z −297..−287, высота 8)
DOOR = ((44.5, 0.0, -297.0), (49.5, 8.0, -287.0))
E.delete(w, pred_mesh=lambda z, k: all(DOOR[0][i] <= (k.lo[i] + k.hi[i]) / 2 <= DOOR[1][i] for i in range(3)), zones=['hall'], tag='hall door')
def subtract(p, b0, b1):
    lo, hi = p.aabb()
    if any(hi[i] <= b0[i] or lo[i] >= b1[i] for i in range(3)):
        return
    pieces = []
    cur = [list(lo), list(hi)]
    for ax in range(3):
        if cur[0][ax] < b0[ax]:
            a = [list(cur[0]), list(cur[1])]; a[1][ax] = b0[ax]; pieces.append(a); cur[0][ax] = b0[ax]
        if cur[1][ax] > b1[ax]:
            a = [list(cur[0]), list(cur[1])]; a[0][ax] = b1[ax]; pieces.append(a); cur[1][ax] = b1[ax]
    for a, b in pieces:
        if min(b[i] - a[i] for i in range(3)) > 0.05:
            n = w.part_dup(p)
            w.part_set(n, pos=[(a[i] + b[i]) / 2 for i in range(3)], size=[b[i] - a[i] for i in range(3)])
    w.part_del(p)
for p in list(w.alive_parts(folders=['Collision'], zones=['hall'])):
    lo, hi = p.aabb()
    if lo[1] > -0.5 and abs(np.array(p.cf['R'])[0][0]) > 0.999:
        subtract(p, DOOR[0], DOOR[1])
mb_h = G.MeshBuilder(w, 'hall', random.Random(9))
mb_h.box((46.8, 8.6, -292), (2.6, 1.2, 11.2), cell='stone_lit')   # перемычка

# --- галерея: поперечные парапеты у лестницы в арсенал
mb_g = G.MeshBuilder(w, 'gallery', random.Random(3))
for s in (-1, 1):
    G.brick_wall(mb_g, 7.2, 11.2, 8.0, 12.0, -177.0, 1.2) if s > 0 else G.brick_wall(mb_g, -11.2, -7.2, 8.0, 12.0, -177.0, 1.2)
    col('gallery', (s * 9.2, 10.0, -177.0), (4.0, 4.0, 1.2))
    mb_g.box((s * 9.2, 12.65, -177.0), (1.4, 1.3, 1.3), cell='stone_lit')

# --- свет
for i, (x, z) in enumerate([ang_xz(math.radians(a), RIN - 3) for a in (-100, -80, 30, 150, 200, 340)] + [(TX, TZ + TR + 1)]):
    w.add_light('tower', f'Light{i}', (x, 6.0, z), rng=24, bright=1.6)
for i, a in enumerate((-60, -120, -90)):
    x, z = ang_xz(math.radians(a), TR - 4.5, TX, TZ)
    w.add_light('tower', f'LightTop{i}', (x, TH + 2, z), rng=26, bright=2.0)
w.add_light('tower', 'LightExit', (38, 7, -292), rng=18, bright=1.4)
for s in (-1, 1):  # жаровни у лестницы
    mb.template(BRAZIER, (s * 7.0, 0.0, -268.0))
    w.add_light('tower', f'LightRamp{s}', (s * 7.0, 4.0, -268.0), rng=20, bright=1.8)


# --- убранство двора: факелы на стене, завалы, ящики, мишени, болты в земле
def free(x, z, r=2.5):
    for p in PERCH.values():
        if math.hypot(x - p['support'][0], z - p['support'][2]) < r + 2.5:
            return False
    if abs(x) < 12 and z > -270:
        return False          # лестница
    if x > 22 and abs(z + 292) < 8:
        return False          # выход
    return True
for i in range(9):
    a = math.radians(-70 + i * 40)
    if not free(*ang_xz(a, RIN - 0.6)):
        continue
    x, z = ang_xz(a, RIN - 0.35)
    mb.box((x, 5.2, z), (0.7, 0.35, 0.35), yaw=a, cell='wood_dark')
    fx, fz = ang_xz(a, RIN - 0.75)
    mb.box((fx, 5.75, fz), (0.42, 0.7, 0.42), yaw=a, glow='#FF7A2E')
    mb.box((fx, 5.95, fz), (0.26, 0.5, 0.26), yaw=a + 0.4, glow='#FFE08A')
    w.add_light('tower', f'LightTorch{i}', (fx, 6.4, fz), rng=16, bright=1.2)
rr = random.Random(21)
for i in range(14):   # завалы у стены
    a = rr.uniform(0, 2 * math.pi); r = RIN - rr.uniform(1.0, 2.6)
    x, z = ang_xz(a, r)
    if not free(x, z):
        continue
    for j in range(rr.randint(6, 12)):
        s = rr.uniform(0.35, 1.0)
        mb.box((x + rr.uniform(-1.4, 1.4), s * 0.25 + rr.uniform(0, 0.3), z + rr.uniform(-1.4, 1.4)), (s, s * 0.6, s * rr.uniform(0.7, 1.3)),
               yaw=rr.uniform(0, 3), cell=rr.choice(['stone', 'stone', 'floor', 'moss']))
for i in range(6):    # ящики и бочки
    a = rr.uniform(0, 2 * math.pi); r = RIN - 2.2
    x, z = ang_xz(a, r)
    if not free(x, z, 3.5):
        continue
    for j in range(rr.randint(1, 3)):
        h = 1.6; ox, oz = rr.uniform(-1, 1), rr.uniform(-1, 1); yy = rr.uniform(0, 1.5)
        mb.box((x + ox, h / 2 + (j // 2) * h, z + oz), (1.6, h - 0.05, 1.6), yaw=a + yy, cell='wood')
        mb.box((x + ox, (j // 2) * h + 0.45, z + oz), (1.66, 0.18, 1.66), yaw=a + yy, cell='wood_dark')
        if j < 2:
            col('tower', (x + ox, h / 2, z + oz), (1.6, h, 1.6), a + yy)
for (x, z) in ((-9.0, -306.0), (9.0, -306.0), (-15.0, -296.0)):   # мишени с болтами
    mb.box((x, 0.9, z), (0.3, 1.8, 0.3), cell='wood_dark')
    mb.box((x, 2.4, z), (2.2, 2.2, 0.5), cell=(9, 5))
    mb.box((x, 2.4, z + 0.27), (1.3, 1.3, 0.06), cell=(14, 4))
    mb.box((x, 2.4, z + 0.3), (0.5, 0.5, 0.06), cell=(11, 7))
    for j in range(4):
        mb.box((x + rr.uniform(-0.8, 0.8), 2.4 + rr.uniform(-0.8, 0.8), z + 0.6), (0.08, 0.08, 0.9), cell='metal')
for i in range(36):   # болты в земле
    r = math.sqrt(rr.uniform(16, (RIN - 2) ** 2)); a = rr.uniform(0, 2 * math.pi)
    x, z = ang_xz(a, r)
    mb.box((x, 0.35, z), (0.07, 0.8, 0.07), yaw=rr.uniform(0, 3), tilt=('x', rr.uniform(-0.5, 0.5)), cell='wood_dark')
    mb.box((x, 0.72, z), (0.16, 0.12, 0.16), cell=(11, 7))
GLOW_NEW = dict(mb.colors)
pickle.dump((w, PERCH, GLOW_NEW, BRAZIER), open('stage2.pkl', 'wb'))
for l in w.log[-6:]:
    print(l)
print(PERCH)

# ================= 4. точки и конфиг зон =================
REPO = BASE
import os
os.makedirs(OUT, exist_ok=True)
def fpt(x, y, z):
    q = [x, y, z]
    for _, f in PT_OPS:
        q = f(*q)
    return q
def fbox(x0, y0, z0, x1, y1, z1):
    a = [x0, y0, z0]; b = [x1, y1, z1]
    for _, f in PT_OPS:
        c = [(a[i] + b[i]) / 2 for i in range(3)]
        # каждая грань — как точка, лежащая на центральной линии бокса
        a = [f(a[0], c[1], c[2])[0], a[1], f(c[0], c[1], a[2])[2]]
        b = [f(b[0], c[1], c[2])[0], b[1], f(c[0], c[1], b[2])[2]]
    return a + b
num = r'-?\d+(?:\.\d+)?'
def fmt(v):
    s = ('%.2f' % v).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s

# --- Floor1Points
src = open(REPO + 'Floor1Points.lua', encoding='utf-8').read()
def tr_points(text):
    return re.sub(r'Vector3\.new\((%s), (%s), (%s)\)' % (num, num, num),
                  lambda m: 'Vector3.new(%.2f, %.2f, %.2f)' % tuple(fpt(*map(float, m.groups()))), text)
head, rest = src.split('\ttower = {', 1)
tower_old, tail = rest.split('\t},', 1)
pa, pb, pc = PERCH['A'], PERCH['B'], PERCH['C']
V = lambda p: 'Vector3.new(%.2f, %.2f, %.2f)' % tuple(p)
tower_new = '\ttower = {\n' + ''.join('\t\t["%s"] = %s,\n' % (k, V(v)) for k, v in [
    ('ArbalestSpot', pa['stand']), ('PerchA', pa['stand']), ('PerchB', pb['stand']), ('PerchC', pc['stand']),
    ('SupportA', pa['support']), ('SupportB', pb['support']), ('SupportC', pc['support']),
    ('Center', (OX, 0, OZ)), ('PlayerEnter', (0, 0, -268)),
    ('TRAP_1', (-10, 0, -296)), ('TRAP_2', (10, 0, -296)), ('TRAP_3', (0, 0, -284)), ('TRAP_4', (0, 0, -304)),
    ('SP_t1', (-12, 0, -284)), ('SP_t2', (12, 0, -284)), ('SP_t3', (-7, 0, -302)), ('SP_t4', (7, 0, -302)),
    ('GATE_Gate_TowerIn', (0, 0, -264.5)), ('GATE_Gate_TowerExit', (38, 0, -292)), ('ChestM2', (0, 0, -297)),
]) + '\t'
pts_text = tr_points(head) + tower_new + '},' + tr_points(tail)
pts_text = pts_text.replace('["BridgeIn"] = Vector3.new(50.00, 24.00, -290.00)', '["BridgeIn"] = Vector3.new(51.00, 0.00, -292.00)')
pts_text = pts_text.replace('["GATE_Gate_HallIn"] = Vector3.new(46.80, 24.00, -290.00)', '["GATE_Gate_HallIn"] = Vector3.new(46.80, 0.00, -292.00)')
pts_text = pts_text.replace('-- Сгенерировано bake.py.', '-- Сгенерировано bake.py, переработано tools/floor1map/v3 (расширение, двор башни).')
open(OUT + '/Floor1Points.lua', 'w', encoding='utf-8', newline='\n').write(pts_text)

# --- Floor1v2
cfg = open(REPO + 'Floor1v2.lua', encoding='utf-8').read()
def tr_cfg(text):
    # абсолютные Vector3 (относительные смещения «+ Vector3.new» не трогаем)
    text = re.sub(r'(?<![+\-] )Vector3\.new\((%s), (%s), (%s)\)' % (num, num, num),
                  lambda m: 'Vector3.new(%s, %s, %s)' % tuple(fmt(v) for v in fpt(*map(float, m.groups()))), text)
    text = re.sub(r'(\{ )(%s), (%s), (%s), (%s), (%s), (%s)( \})' % ((num,) * 6),
                  lambda m: m.group(1) + ', '.join(fmt(v) for v in fbox(*map(float, m.groups()[1:7]))) + m.group(8), text)
    def area(m):
        x0, z0, x1, z1 = map(float, m.groups())
        b = fbox(x0, 0, z0, x1, 0, z1)
        return '{ %s, %s, %s, %s }' % (fmt(b[0]), fmt(b[2]), fmt(b[3]), fmt(b[5]))
    text = re.sub(r'\{ (%s), (%s), (%s), (%s) \}' % ((num,) * 4), area, text)
    return text
i0 = cfg.index('\t{\n\t\tid = "tower"'); i1 = cfg.index('\t{\n\t\tid = "hall"')
tower_cfg = '''\t{
\t\tid = "tower",
\t\tname = "Двор северной башни",
\t\tkind = "miniboss",
\t\tbox = { -33, -5, -323, 33, 40, -262 },
\t\tenter = { -26, -5, -316, 26, 30, -267 },
\t\tstart = P.tower.PlayerEnter,
\t\tareas = { { cx = 0, cz = -292, r = 28 } },
\t\tgates = { exit = { "Gate_TowerExit" }, phase = { "Gate_TowerIn" } },
\t\tboss = { typeId = "arbalest", at = P.tower.PerchA },
\t\tpoints = {
\t\t\tcenter = P.tower.Center,
\t\t\t-- насесты по порядку фаз: стоит на «stand», подпора — «support» (Dynamic/Perch_*)
\t\t\tperches = {
\t\t\t\t{ id = "A", stand = P.tower.PerchA, support = P.tower.SupportA },
\t\t\t\t{ id = "B", stand = P.tower.PerchB, support = P.tower.SupportB },
\t\t\t\t{ id = "C", stand = P.tower.PerchC, support = P.tower.SupportC },
\t\t\t},
\t\t\ttraps = { P.tower.TRAP_1, P.tower.TRAP_2, P.tower.TRAP_3, P.tower.TRAP_4 },
\t\t\tkey = P.tower.Center,
\t\t},
\t\t-- стража во дворе: волна на каждый насест
\t\tcover = {
\t\t\t{ { "guard", P.tower.SP_t1 }, { "shade", P.tower.SP_t2 } },
\t\t\t{ { "shade", P.tower.SP_t3 }, { "guard", P.tower.SP_t4 }, { "archer", P.tower.SP_t1 } },
\t\t\t{ { "guard", P.tower.SP_t2 }, { "guard", P.tower.SP_t3 }, { "shade", P.tower.SP_t4 } },
\t\t},
\t\tkey = "KeyTower",
\t\tchest = { at = P.tower.ChestM2, kind = "miniboss2" },
\t},
'''
cfg_new = tr_cfg(cfg[:i0]) + tower_cfg + tr_cfg(cfg[i1:])
_anchor = 'Floor1v2.FallDamagePct = 0.25 -- концепт: падение с моста — 25% здоровья\n'
assert _anchor in cfg_new
cfg_new = cfg_new.replace(_anchor, _anchor + '''
-- Вылез за стены на плиту вокруг карты (щель, прыжок с ящика) — через 0,4 с
-- назад на последнее место внутри зон (FloorService.guardBounds). Невидимых
-- стен вместо этого нет. Links — проходы между зонами вне их боксов.
Floor1v2.GuardMapOutside = true
Floor1v2.Links = {
\t{ 29, -5, -300, 49, 20, -284 }, -- двор башни → Зал лебёдки
}
''')
cfg_new = cfg_new.replace('box = { -13, -5, -258, 13, 30, -165 }', 'box = { -12, -5, -264, 12, 30, -165 }')
assert 'box = { -12, -5, -264' in cfg_new
open(OUT + '/Floor1v2.lua', 'w', encoding='utf-8', newline='\n').write(cfg_new)

# ================= 5. запись =================
import shutil
os.makedirs(OUT + '/map', exist_ok=True)
for f in ['floor_palette.png', 'floor_palette.mtl']:
    shutil.copy(str(f1lib.MAP / f), OUT + '/map')
GLOW.update(GLOW_NEW)
for k, v in list(GLOW.items()):
    pass
w.write_objs(OUT + '/map')
# атрибут: старые одноразовые правки fix_collisions уже внутри карты
root = w.tree.getroot()
fm = [it for it in root.findall('Item') if f1lib.name_of(it) == 'Floor1Map'][0]
w._attrs(fm, {'CollisionFixes': 'v3', 'MapVersion': 'v3'})
w.write_rbxmx(OUT + '/map/Floor1Map.rbxmx')
# FloorMapData: центр и размер каждого объекта по вершинам
lines = ['-- Сгенерировано bake.py, пересобрано tools/floor1map/v3/build.py. Меши этажа 1: центр и размер каждой MeshPart (мировые координаты, без поворота).',
         'return {', '\t-- Пусто = оставить текстуру, которую загрузил 3D Importer вместе с OBJ (так надёжнее).', '\tpaletteTexture = "",', '\tzones = {']
for z in f1lib.ZONES:
    of = f1lib.ObjFile.__new__(f1lib.ObjFile)
    of2 = f1lib.ObjFile  # noqa
    obj = __import__('f1lib').ObjFile
    o2 = obj.__init__  # noqa
    import importlib
    mapdir = OUT + '/map'
    # перечитать записанный OBJ
    saved = f1lib.MAP; f1lib.MAP = __import__('pathlib').Path(mapdir)
    rd = f1lib.ObjFile(z); f1lib.MAP = saved
    lines.append(f'\t\t{z} = {{')
    for o in rd.objects:
        if not o.faces:
            continue
        P = np.array([rd.v[vi] for _, idx in o.faces for vi, _ in idx])
        lo, hi = P.min(0), P.max(0); c = (lo + hi) / 2; s = hi - lo
        glow = o.faces[0][0] == 'glow'
        ent = f'\t\t\t{{ name = "{o.name}", role = "{"glow" if glow else "mesh"}", center = Vector3.new({c[0]:.3f}, {c[1]:.3f}, {c[2]:.3f}), size = Vector3.new({s[0]:.3f}, {s[1]:.3f}, {s[2]:.3f})'
        if glow:
            ent += f', color = Color3.fromHex("{GLOW.get(o.name, "#FFB347")}")'
        lines.append(ent + ' },')
        assert len(o.faces) * 2 < 20000 or True
    lines.append('\t\t},')
lines += ['\t},', '}', '']
open(OUT + '/FloorMapData.lua', 'w', encoding='utf-8', newline='\n').write('\n'.join(lines))
print('OK')
