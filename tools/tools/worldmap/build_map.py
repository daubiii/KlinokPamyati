#!/usr/bin/env python3
# Пиксельная карта этажей для Врат Печатей (GateWindow v2).
#   python3 tools/worldmap/build_map.py  → assets/worldmap/*.png + Config/WorldMapAtlas.lua
import os, sys, numpy as np, cv2
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import terrain
from terrain import W, H
import paint, sprites, features

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SEED = 4

def render():
    t = terrain.build(SEED)
    rng = np.random.default_rng(SEED * 31 + 1)
    img = paint.paint_sea(t, rng)
    ground = paint.paint_ground(t, rng)
    land = t['land']
    img[land] = ground[land]
    img = paint.finish_relief(t, img, rng)
    top = land & (t['face_region'] == 0)
    cv = sprites.Canvas(img, top)
    lm = features.landmarks(t)
    t['landmarks'] = lm
    segs = features.road_path(t, lm)
    t['road'] = segs
    # ориентиры сначала занимают место, дорога — следом
    for k, (x, y) in lm.items():
        cv.claim(x - 16, y - 14, x + 17, y + 8)
    cv.occ[:] = False
    features.draw_road(cv, t, segs, rng)
    for k, fn in ((1, features.deco_r1), (2, features.deco_r2), (3, features.deco_r3), (4, features.deco_r4), (5, features.deco_r5)):
        fn(cv, t, np.random.default_rng(SEED * 100 + k), lm[k])
    features.deco_islets(cv, t, rng)
    sea = ~(land | (t['face_region'] > 0))
    cv.top = sea
    crng = np.random.default_rng(77)
    for (cx, cy, w) in ((92, 22, 26), (420, 16, 30), (470, 96, 22), (18, 160, 20), (230, 226, 24), (478, 210, 18), (130, 228, 16)):
        features.cloud(cv, cx, cy, w, crng)
    features.compass(cv, 34, 34)
    return t, cv.img


FOG = [(44, 50, 76), (62, 70, 100), (86, 94, 126), (116, 124, 156), (152, 160, 190)]

def visual_masks(t):
    top = t['land'] & (t['face_region'] == 0)
    out = {}
    for k in range(1, 6):
        out[k] = ((t['region'] == k) & top) | (t['face_region'] == k)
    return out

def bbox(mask, margin):
    ys, xs = np.nonzero(mask)
    x0 = max(0, xs.min() - margin); y0 = max(0, ys.min() - margin)
    x1 = min(W, xs.max() + 1 + margin); y1 = min(H, ys.max() + 1 + margin)
    return int(x0), int(y0), int(x1 - x0), int(y1 - y0)

def dil(mask, n):
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    return cv2.dilate(mask.astype(np.uint8), k, iterations=n).astype(bool)

def fog_reach(vms, k):
    """Маска тумана этажа k: сам этаж + то, что его постройки и кроны заслоняют сверху."""
    vm = vms[k]
    lower = np.zeros_like(vm)
    for j in range(1, k):
        lower |= vms[j]
    up = vm.copy()
    for d in range(1, 13):
        sh = np.zeros_like(vm); sh[:-d] = vm[d:]
        up |= sh
    return dil(vm, 2) | (up & ~lower)

def fog_piece(img, vms, k, box):
    x0, y0, w, h = box
    vm = vms[k]
    rng = np.random.default_rng(504)  # один узор на все этажи: соседние туманы стыкуются
    n = terrain.fbm(W, H, 16, rng, 3)
    luma = img.astype(float) @ np.array([0.3, 0.55, 0.15]) / 255.0
    v = 0.78 * n + 0.22 * luma
    # клубы: светлый верх, тёмный низ (разность со сдвинутым шумом)
    n2 = np.roll(n, 3, 0)
    v += (n - n2) * 1.4
    q, idx = paint.quantize(np.clip(v * 1.2 - 0.2, 0, 0.999), FOG, paint.bayer(), 0.12)
    by = paint.bayer()
    core = fog_reach(vms, k)
    ring = dil(vm, 5) & ~core
    alpha = np.zeros((H, W), np.uint8)
    alpha[core] = 255
    alpha[ring & (by > -0.1)] = 235
    alpha[ring & (by > 0.25)] = 0
    rgba = np.dstack([q, alpha])
    return rgba[y0:y0 + h, x0:x0 + w]

def hi_piece(vm, box):
    x0, y0, w, h = box
    inner = vm & ~dil(~vm, 1)
    edge = vm & ~inner
    outer = dil(vm, 1) & ~vm
    outer2 = dil(vm, 2) & ~vm & ~outer
    a = np.zeros((H, W), np.uint8)
    by = paint.bayer()
    a[inner & (by > 0.2)] = 46
    a[inner & (by <= 0.2)] = 22
    a[edge] = 255
    a[outer] = 170
    a[outer2 & (by > 0)] = 70
    rgba = np.zeros((H, W, 4), np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = a
    return rgba[y0:y0 + h, x0:x0 + w]

def sprite_cloud(w, h, seed, fogish=False):
    rng = np.random.default_rng(seed)
    img = np.zeros((h, w, 4), np.uint8)
    cvs = sprites.Canvas(np.zeros((h, w, 3), np.uint8), np.ones((h, w), bool))
    pts = features.cloud(cvs, 2, h - 3, w - 6, rng)
    cols = (FOG[4], FOG[3], FOG[2]) if fogish else ((214, 222, 238), (176, 188, 214), (128, 140, 176))
    for (px, py) in pts:
        if 0 <= px < w and 0 <= py < h:
            c = cols[1]
            if (px, py - 1) not in pts:
                c = cols[0]
            elif (px, py + 1) not in pts:
                c = cols[2]
            img[py, px, :3] = c
            img[py, px, 3] = 200 if fogish else 230
    return img

def pin_sprite():
    rows = [
        "..###..",
        ".#####.",
        "##...##",
        "##...##",
        ".#####.",
        "..###..",
        "...#...",
        "...#...",
        "..###..",
    ]
    img = np.zeros((len(rows), len(rows[0]), 4), np.uint8)
    for j, r in enumerate(rows):
        for i, ch in enumerate(r):
            if ch == '#':
                img[j, i] = (255, 255, 255, 255)
    return img

def pack(pieces, width=1024):
    order = sorted(pieces.items(), key=lambda kv: -kv[1].shape[0])
    x = y = shelf = 0
    rects = {}
    for name, im in order:
        h, w = im.shape[:2]
        if x + w + 2 > width:
            x = 0; y += shelf + 2; shelf = 0
        rects[name] = (x, y, w, h)
        x += w + 2; shelf = max(shelf, h)
    total_h = y + shelf
    atlas = np.zeros((total_h, width, 4), np.uint8)
    for name, (px, py, w, h) in rects.items():
        im = pieces[name]
        if im.shape[2] == 3:
            im = np.dstack([im, np.full(im.shape[:2], 255, np.uint8)])
        atlas[py:py + h, px:px + w] = im
    return atlas, rects

def grid(vm, cell=4):
    gw, gh = W // cell, H // cell
    rows = []
    for gy in range(gh):
        row = []
        for gx in range(gw):
            best, bk = 0, '0'
            for k in range(1, 6):
                c = vm[k][gy * cell:(gy + 1) * cell, gx * cell:(gx + 1) * cell].sum()
                if c > best:
                    best, bk = c, str(k)
            row.append(bk if best >= 4 else '0')
        rows.append(''.join(row))
    return gw, gh, rows

def runs(rows):
    out = []
    for gy, r in enumerate(rows):
        gx = 0
        while gx < len(r):
            ch = r[gx]; n = 1
            while gx + n < len(r) and r[gx + n] == ch:
                n += 1
            if ch != '0':
                out.append((int(ch), gx, gy, n))
            gx += n
    return out

def lua_atlas(size, rects, meta, gw, gh, rows, cell, scale, fb_runs):
    L = []
    L.append('--!nonstrict')
    L.append('-- WorldMapAtlas (сгенерировано tools/worldmap/build_map.py — не править руками)')
    L.append('-- Куски assets/worldmap/worldmap_atlas.png в родных пикселях; окно Врат показывает их ×3 (Pixelated).')
    L.append('--   map — вся карта; fog<N> — туман над закрытым этажом N; hi<N> — белая обводка этажа (красится ImageColor3);')
    L.append('--   cloud1..3 — облака над морем, puff1..2 — клубы тумана, pin — флажок «ты здесь».')
    L.append('local WorldMapAtlas = {}')
    L.append('WorldMapAtlas.Size = { w = %d, h = %d }' % size)
    L.append('WorldMapAtlas.MapSize = { w = %d, h = %d }' % (W, H))
    L.append('WorldMapAtlas.Scale = %d' % scale)
    L.append('WorldMapAtlas.Pieces = {')
    for name in sorted(rects):
        x, y, w, h = rects[name]
        L.append('\t%s = { x = %d, y = %d, w = %d, h = %d },' % (name, x, y, w, h))
    L.append('}')
    L.append('-- Этажи на карте (родные пиксели карты): box — рамка этажа (там же fog/hi), label — точка плашки,')
    L.append('-- landmark — ориентир (ворота, беседка, дом ловчего, горн, шпиль), center — середина.')
    L.append('WorldMapAtlas.Regions = {')
    for k in range(1, 6):
        m = meta[k]
        L.append('\t[%d] = { box = { x = %d, y = %d, w = %d, h = %d }, label = { x = %d, y = %d }, landmark = { x = %d, y = %d }, center = { x = %d, y = %d }, fog = { x = %d, y = %d } },' % (
            k, *m['box'], *m['label'], *m['landmark'], *m['center'], *m['fogpos']))
    L.append('}')
    L.append('-- Сетка попаданий: клетка %d×%d пикселей карты, символ — этаж (0 — море).' % (cell, cell))
    L.append('WorldMapAtlas.Grid = { cell = %d, w = %d, h = %d, rows = {' % (cell, gw, gh))
    for r in rows:
        L.append('\t"%s",' % r)
    L.append('} }')
    L.append('-- Заглушка без картинки: полосы сетки { этаж, x, y, длина } в клетках.')
    L.append('WorldMapAtlas.Fallback = {')
    line = []
    for (k, gx, gy, n) in fb_runs:
        line.append('{%d,%d,%d,%d}' % (k, gx, gy, n))
        if len(line) == 16:
            L.append('\t' + ','.join(line) + ','); line = []
    if line:
        L.append('\t' + ','.join(line) + ',')
    L.append('}')
    L.append('')
    L.append('function WorldMapAtlas.regionAt(x: number, y: number): number')
    L.append('\tlocal g = WorldMapAtlas.Grid')
    L.append('\tlocal gx, gy = math.floor(x / g.cell), math.floor(y / g.cell)')
    L.append('\tlocal row = g.rows[gy + 1]')
    L.append('\tif not row or gx < 0 or gx >= g.w then')
    L.append('\t\treturn 0')
    L.append('\tend')
    L.append('\treturn tonumber(string.sub(row, gx + 1, gx + 1)) or 0')
    L.append('end')
    L.append('')
    L.append('return WorldMapAtlas')
    return '\n'.join(L) + '\n'

if __name__ == '__main__':
    t, img = render()
    vm = visual_masks(t)
    pieces = {'map': img}
    meta = {}
    for k in range(1, 6):
        box = bbox(fog_reach(vm, k), 6)
        pieces['fog%d' % k] = fog_piece(img, vm, k, box)
        pieces['hi%d' % k] = hi_piece(vm[k], box)
        lx, ly = t['landmarks'][k]
        ys, xs = np.nonzero(vm[k])
        meta[k] = dict(box=box, landmark=(lx, ly), label=(lx, min(H - 8, ly + 10)), center=(int(xs.mean()), int(ys.mean())), fogpos=(box[0], box[1]))
    pieces['cloud1'] = sprite_cloud(40, 13, 1)
    pieces['cloud2'] = sprite_cloud(28, 11, 2)
    pieces['cloud3'] = sprite_cloud(52, 15, 3)
    pieces['puff1'] = sprite_cloud(34, 14, 4, True)
    pieces['puff2'] = sprite_cloud(24, 11, 5, True)
    pieces['pin'] = pin_sprite()
    atlas, rects = pack(pieces)
    assert atlas.shape[0] <= 1024, atlas.shape
    out = os.path.join(ROOT, 'assets', 'worldmap')
    os.makedirs(out, exist_ok=True)
    Image.fromarray(atlas, 'RGBA').save(os.path.join(out, 'worldmap_atlas.png'), optimize=True)
    cell = 4
    gw, gh, rows = grid(vm, cell)
    lua = lua_atlas((atlas.shape[1], atlas.shape[0]), rects, meta, gw, gh, rows, cell, 3, runs(rows))
    with open(os.path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared', 'Config', 'WorldMapAtlas.lua'), 'w') as f:
        f.write(lua)
    np.save('/tmp/worldmap_img.npy', img)
    import pickle
    pickle.dump(dict(meta=meta, rects=rects), open('/tmp/worldmap_meta.pkl', 'wb'))
    print('atlas', atlas.shape, 'pieces', len(rects), 'grid', gw, gh, 'runs', len(runs(rows)))
