# Рельеф карты этажей: шум, остров, регионы, высоты. Используется build_map.py.
import numpy as np

W, H = 504, 236

def value_noise(w, h, scale, rng):
    gw, gh = int(w / scale) + 3, int(h / scale) + 3
    g = rng.random((gh, gw))
    xs = np.arange(w) / scale
    ys = np.arange(h) / scale
    x0 = xs.astype(int); y0 = ys.astype(int)
    fx = xs - x0; fy = ys - y0
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
    a = g[np.ix_(y0, x0)]; b = g[np.ix_(y0, x0 + 1)]
    c = g[np.ix_(y0 + 1, x0)]; d = g[np.ix_(y0 + 1, x0 + 1)]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]

def fbm(w, h, scale, rng, octaves=4, gain=0.5):
    total = np.zeros((h, w)); amp = 1.0; norm = 0.0; s = scale
    for _ in range(octaves):
        total += value_noise(w, h, s, rng) * amp
        norm += amp; amp *= gain; s = max(s / 2, 1.0)
    return total / norm

# Пять регионов: этаж → центр лепестка, радиусы, высота (уровень уступа).
REGIONS = {
    1: dict(seed=(140, 182), r=(112, 54), level=1),
    2: dict(seed=(362, 184), r=(112, 54), level=2),
    3: dict(seed=(378, 112), r=(100, 48), level=3),
    4: dict(seed=(128, 112), r=(100, 48), level=4),
    5: dict(seed=(252, 44), r=(124, 38), level=5),
}

def build(seed=7):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    n1 = fbm(W, H, 40, rng, 5)
    n2 = fbm(W, H, 18, rng, 4)
    # Метаболы-лепестки + середина
    field = np.zeros((H, W))
    lwx = (fbm(W, H, 34, rng, 4) - 0.5) * 50
    lwy = (fbm(W, H, 34, rng, 4) - 0.5) * 34
    qx = xx + lwx; qy = yy + lwy
    blobs = [(v['seed'], v['r']) for v in REGIONS.values()] + [((252, 128), (96, 62)), ((252, 86), (70, 40))]
    for (sx, sy), (rx, ry) in blobs:
        field += np.exp(-(((qx - sx) / rx) ** 2 + ((qy - sy) / ry) ** 2) * 1.6)
    field += (n1 - 0.5) * 0.85 + (n2 - 0.5) * 0.45
    land = field > 0.6
    # поля по краям и угол под компас
    edge = 7
    land[:edge, :] = False; land[-edge:, :] = False; land[:, :edge] = False; land[:, -edge:] = False
    land &= ~(((xx - 34) ** 2 + (yy - 34) ** 2) < 40 ** 2)
    # островки
    islets = [(470, 30, 9, 5), (488, 150, 7, 5), (30, 200, 12, 7), (60, 222, 6, 3), (440, 222, 8, 4), (22, 120, 6, 4)]
    for (ix, iy, rx, ry) in islets:
        m = (((xx - ix) / rx) ** 2 + ((yy - iy) / ry) ** 2 + (n2 - 0.5) * 0.9) < 1
        land |= m
    land = keep_components(land, min_size=18)
    # Регионы: Вороной с искривлением
    wx = (fbm(W, H, 30, rng, 4) - 0.5) * 64
    wy = (fbm(W, H, 30, rng, 4) - 0.5) * 40
    px = xx + wx; py = yy + wy
    best = np.full((H, W), 1e9); region = np.zeros((H, W), np.int8)
    weights = {1: 1.0, 2: 1.0, 3: 1.02, 4: 1.0, 5: 0.92}
    for k, v in REGIONS.items():
        sx, sy = v['seed']
        d = np.sqrt(((px - sx) / 1.0) ** 2 + ((py - sy) * 1.55) ** 2) * weights[k]
        m = d < best
        best[m] = d[m]; region[m] = k
    region[~land] = 0
    # мелкие островки — регион ближайшего, но маленькие оставим «ничейными» (0 → свой код 9)
    lab = label(land)
    main = np.bincount(lab.ravel())
    main[0] = 0
    big = main.argmax()
    region[(lab != big) & land] = 9
    region = majority(region, land, 3)
    region = fix_connectivity(region)
    level = np.zeros((H, W), np.int8)
    for k, v in REGIONS.items():
        level[region == k] = v['level']
    level[region == 9] = 1
    return dict(land=land, region=region, level=level, n1=n1, n2=n2, rng=rng, xx=xx, yy=yy)

def label(mask):
    h, w = mask.shape
    lab = np.zeros((h, w), np.int32); cur = 0
    for y in range(h):
        for x in range(w):
            if mask[y, x] and lab[y, x] == 0:
                cur += 1
                stack = [(y, x)]; lab[y, x] = cur
                while stack:
                    cy, cx = stack.pop()
                    for ny, nx in ((cy+1,cx),(cy-1,cx),(cy,cx+1),(cy,cx-1)):
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and lab[ny, nx] == 0:
                            lab[ny, nx] = cur; stack.append((ny, nx))
    return lab

def keep_components(mask, min_size):
    lab = label(mask)
    counts = np.bincount(lab.ravel())
    keep = counts >= min_size; keep[0] = False
    return keep[lab]

def majority(region, land, iters):
    r = region.copy()
    for _ in range(iters):
        votes = np.zeros((10,) + r.shape, np.int16)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                s = np.roll(np.roll(r, dy, 0), dx, 1)
                for k in range(1, 10):
                    votes[k] += (s == k)
        best = votes.argmax(0)
        upd = land & (r != 9) & (best != 9) & (best != 0)
        r[upd] = best[upd]
    return r

def fix_connectivity(region):
    # у каждого региона остаётся одна связная часть; обрывки отдаются соседу
    r = region.copy()
    for k in range(1, 6):
        lab = label(r == k)
        counts = np.bincount(lab.ravel()); counts[0] = 0
        if counts.max() == 0:
            continue
        big = counts.argmax()
        stray = (lab != big) & (lab != 0)
        ys, xs = np.nonzero(stray)
        for y, x in zip(ys, xs):
            for d in range(1, 30):
                found = None
                for ny, nx in ((y-d,x),(y+d,x),(y,x-d),(y,x+d)):
                    if 0 <= ny < r.shape[0] and 0 <= nx < r.shape[1] and r[ny, nx] not in (0, k, 9):
                        found = r[ny, nx]; break
                if found:
                    r[y, x] = found; break
    return r
