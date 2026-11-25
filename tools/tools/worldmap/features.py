# Наполнение карты: ориентиры этажей, дорога, деревья, постройки, лава, каналы, компас.
import heapq, numpy as np, cv2
from terrain import W, H, fbm, REGIONS
from paint import lighten, darken, SEA
import sprites as S

def region_top(t, k):
    return (t['region'] == k) & (t['face_region'] == 0)

def dist_inside(mask):
    return cv2.distanceTransform(mask.astype(np.uint8), cv2.DIST_L2, 3)

def landmarks(t):
    out = {}
    yy, xx = t['yy'], t['xx']
    for k, v in REGIONS.items():
        m = region_top(t, k)
        d = dist_inside(m)
        sx, sy = v['seed']
        score = d - 0.06 * np.sqrt((xx - sx) ** 2 + ((yy - sy) * 1.6) ** 2)
        y, x = np.unravel_index(np.argmax(score), score.shape)
        out[k] = (int(x), int(y + 4))
    return out

def poisson(rng, mask, spacing, tries=4000, avoid=None):
    pts = []
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return pts
    grid = {}
    cell = spacing
    for _ in range(tries):
        i = int(rng.integers(0, len(xs)))
        x, y = int(xs[i]), int(ys[i])
        gx, gy = x // cell, y // cell
        ok = True
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                for (px, py) in grid.get((gx + ox, gy + oy), ()):
                    if (px - x) ** 2 + (py - y) ** 2 < spacing * spacing:
                        ok = False
                        break
        if ok:
            pts.append((x, y))
            grid.setdefault((gx, gy), []).append((x, y))
    return pts

# ===== дорога =====

def astar(cost, a, b):
    h, w = cost.shape
    INF = 1e18
    g = np.full((h, w), INF); g[a[1], a[0]] = 0
    prev = {}
    pq = [(0, a)]
    nb = [(-1, 0, 1), (1, 0, 1), (0, -1, 1), (0, 1, 1), (-1, -1, 1.414), (1, -1, 1.414), (-1, 1, 1.414), (1, 1, 1.414)]
    while pq:
        f, (x, y) = heapq.heappop(pq)
        if (x, y) == b:
            break
        gc = g[y, x]
        for dx, dy, s in nb:
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and cost[ny, nx] < 1e9:
                ng = gc + s * cost[ny, nx]
                if ng < g[ny, nx]:
                    g[ny, nx] = ng; prev[(nx, ny)] = (x, y)
                    hh = abs(nx - b[0]) + abs(ny - b[1])
                    heapq.heappush(pq, (ng + hh, (nx, ny)))
    path = [b]
    while path[-1] != a and path[-1] in prev:
        path.append(prev[path[-1]])
    return path[::-1]

def road_path(t, lm):
    land = t['land']; region = t['region']; fr = t['face_region']
    base = np.where(land | (fr > 0), 1.0, 1e10)
    pts = []
    # старт — южный берег 1-го этажа, под воротами
    x1, y1 = lm[1]
    ys = [y for y in range(y1, H) if land[y, x1] or fr[y, x1]]
    start = (x1 - 6, max(ys) - 1 if ys else y1 + 20)
    order = [start, lm[1], lm[2], lm[3], lm[4], lm[5]]
    segs = []
    for i in range(len(order) - 1):
        a, b = order[i], order[i + 1]
        ka = region[a[1], a[0]]; kb = region[b[1], b[0]]
        cost = base.copy()
        other = ~np.isin(region, [ka, kb]) & land
        cost[other] = 9.0
        cost[fr > 0] = 2.5
        n = fbm(W, H, 12, np.random.default_rng(100 + i), 2)
        cost = cost * (0.7 + n * 0.6)
        segs.append(astar(cost, a, b))
    return segs

def smooth(path, it=2):
    p = [np.array(q, float) for q in path]
    for _ in range(it):
        if len(p) < 3:
            break
        q = [p[0]]
        for i in range(len(p) - 1):
            q.append(p[i] * 0.75 + p[i + 1] * 0.25)
            q.append(p[i] * 0.25 + p[i + 1] * 0.75)
        q.append(p[-1])
        p = q
    return p

def draw_road(cv, t, segs, rng):
    fr = t['face_region']
    dots = []
    for seg in segs:
        pts = smooth(seg[::3] + [seg[-1]], 3)
        acc = 0.0
        for i in range(1, len(pts)):
            a, b = pts[i - 1], pts[i]
            L = float(np.hypot(*(b - a)))
            steps = max(1, int(L * 2))
            for s in range(steps):
                p = a + (b - a) * (s / steps)
                acc += L / steps
                x, y = int(round(p[0])), int(round(p[1]))
                # грунт дороги
                for dx, dy in ((0, 0), (1, 0), (0, 1)):
                    if fr[min(y + dy, H - 1), min(x + dx, W - 1)] == 0:
                        cv.put(x + dx, y + dy, darken(cv.get(x + dx, y + dy), 0.12))
                cv.occ[max(0, y - 2):y + 3, max(0, x - 2):x + 3] = True
                if acc >= 3.0:
                    acc = 0.0
                    dots.append((x, y))
    for (x, y) in dots:
        if fr[y, x] > 0:  # ступени на уступе
            cv.put(x - 1, y, (200, 188, 160)); cv.put(x, y, (226, 214, 186)); cv.put(x + 1, y, (200, 188, 160))
            cv.put(x, y + 1, darken(cv.get(x, y + 1), 0.4))
        else:
            cv.put(x, y, (232, 220, 190)); cv.put(x + 1, y, (196, 182, 150))
            cv.shade(x, y + 1, 0.35); cv.shade(x + 1, y + 1, 0.3)
    return dots

# ===== компас и облака =====

GLYPHS = {
    'С': ['.##', '#..', '#..', '#..', '.##'],
    'Ю': ['#..#.', '#.#.#', '###.#', '#.#.#', '#..#.'],
    'З': ['##.', '..#', '.#.', '..#', '##.'],
    'В': ['##.', '#.#', '##.', '#.#', '##.'],
}

def glyph(cv, x, y, ch, c, sh=(10, 12, 24)):
    rows = GLYPHS[ch]
    for j, row in enumerate(rows):
        for i, v in enumerate(row):
            if v == '#':
                cv.put(x + i + 1, y + j + 1, sh)
    for j, row in enumerate(rows):
        for i, v in enumerate(row):
            if v == '#':
                cv.put(x + i, y + j, c)

def compass(cv, cx, cy):
    light = (226, 214, 186); dark = (140, 128, 104); gold = (217, 164, 65); ink = (14, 16, 30)
    # кольцо
    for a in np.linspace(0, 2 * np.pi, 90, endpoint=False):
        x = cx + int(round(np.cos(a) * 12)); y = cy + int(round(np.sin(a) * 12))
        cv.put(x, y, (96, 108, 140))
    for a in np.linspace(0, 2 * np.pi, 16, endpoint=False):
        x = cx + int(round(np.cos(a) * 14)); y = cy + int(round(np.sin(a) * 14))
        cv.put(x, y, (120, 134, 170))
    def ray(dx, dy, L, wdt):
        # луч-ромб: светлая и тёмная половинки
        for s in range(L):
            half = int(round(wdt * (1 - s / L)))
            for o in range(-half, half + 1):
                px = cx + dx * s + (-dy) * o
                py = cy + dy * s + dx * o
                cv.put(px, py, light if o <= 0 else dark)
        cv.put(cx + dx * L, cy + dy * L, light)
    for dx, dy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        for s in range(1, 9):
            cv.put(cx + dx * s, cy + dy * s, dark if s > 2 else light)
            cv.put(cx + dx * s + (1 if dx > 0 else -1) * 0, cy + dy * s + dy, (100, 92, 76))
    ray(0, -1, 18, 3); ray(0, 1, 18, 3); ray(1, 0, 18, 3); ray(-1, 0, 18, 3)
    # север — красный наконечник
    for s in range(10, 18):
        half = int(round(3 * (1 - s / 18)))
        for o in range(-half, half + 1):
            cv.put(cx + o, cy - s, (200, 70, 60) if o <= 0 else (150, 44, 40))
    cv.put(cx, cy, gold); cv.put(cx - 1, cy, gold); cv.put(cx + 1, cy, (160, 110, 40)); cv.put(cx, cy - 1, gold); cv.put(cx, cy + 1, (160, 110, 40))
    glyph(cv, cx - 1, cy - 26, 'С', light)
    glyph(cv, cx - 2, cy + 22, 'Ю', light)
    glyph(cv, cx - 27, cy - 2, 'З', light)
    glyph(cv, cx + 24, cy - 2, 'В', light)

def cloud(cv, x, y, w, rng, alpha=255):
    light = (176, 188, 214); mid = (138, 150, 182); dark = (98, 110, 146)
    blobs = []
    n = max(2, w // 5)
    for i in range(n):
        bx = x + int(i * w / n) + int(rng.integers(-1, 2))
        r = int(rng.integers(2, 4)) + (1 if 0 < i < n - 1 else 0)
        blobs.append((bx, y - r // 2, r))
    pts = set()
    for (bx, by, r) in blobs:
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r and by + dy <= y + 1:
                    pts.add((bx + dx, by + dy))
    for (px, py) in pts:
        c = mid
        if (px, py - 1) not in pts:
            c = light
        elif (px, py + 1) not in pts:
            c = dark
        cv.put(px, py, (*c, alpha))
    return pts

# ===== этажи =====
STONE = ((196, 188, 174), (152, 142, 130), (104, 96, 88))
TORCH = (240, 170, 80)

def ridge_mask(rng, scale, width, mask):
    n = fbm(W, H, scale, rng, 3)
    return (np.abs(n - 0.5) < width) & mask

def deco_r1(cv, t, rng, lm):
    """Привратный двор: ворота с башнями, руины стен, щебень, сухая трава."""
    m = region_top(t, 1)
    inner = dist_inside(m) > 3
    x, y = lm
    # мостовая перед воротами
    for dy in range(-3, 10):
        for dx in range(-15, 16):
            if (dx / 15.0) ** 2 + ((dy - 3) / 7.0) ** 2 < 1 and m[y + dy, x + dx]:
                c = (128, 116, 104) if ((x + dx) // 2 + (y + dy)) % 2 else (146, 134, 120)
                if (x + dx + (y + dy) * 3) % 5 == 0:
                    c = (98, 88, 80)
                cv.put(x + dx, y + dy, c)
    # ворота: стена + две башни + арка с решёткой
    gy = y - 2
    S.wall(cv, x - 14, x + 14, gy, 4, STONE, gaps=((x - 2, x + 2),))
    for i in range(-2, 3):  # арка
        for j in range(0, 5):
            cv.put(x + i, gy - j, (26, 20, 22) if j < 4 or abs(i) < 2 else STONE[2])
    for i in (-1, 1):
        for j in range(0, 4):
            cv.put(x + i, gy - j, (90, 80, 70))
    for j in (1, 3):
        for i in range(-2, 3):
            cv.put(x + i, gy - j, (90, 80, 70))
    cv.put(x, gy - 5, (217, 164, 65))  # печать над аркой
    S.tower(cv, x - 6, gy, 6, 11, STONE)
    S.tower(cv, x + 7, gy, 6, 11, STONE)
    S.tower(cv, x - 15, gy + 1, 5, 8, STONE)
    S.tower(cv, x + 15, gy + 1, 5, 8, STONE, broken=True)
    S.flame(cv, x - 3, gy - 3); S.flame(cv, x + 3, gy - 3)
    for fx in (x - 6, x + 7):  # знамёна
        cv.put(fx, gy - 14, (90, 70, 50)); cv.put(fx, gy - 13, (90, 70, 50))
        cv.put(fx + 1, gy - 14, (170, 50, 44)); cv.put(fx + 2, gy - 14, (170, 50, 44)); cv.put(fx + 1, gy - 13, (130, 36, 32))
    cv.claim(x - 18, y - 18, x + 19, y + 10)
    # старые мостовые пятнами
    pav = (fbm(W, H, 14, np.random.default_rng(13), 3) > 0.6) & inner & ~cv.occ
    for y0, x0 in zip(*np.nonzero(pav)):
        c = (118, 106, 94) if (x0 // 2 + y0) % 2 else (132, 120, 106)
        if (x0 + y0 * 3) % 5 == 0:
            c = (92, 82, 74)
        cv.put(x0, y0, c)
    grass = (fbm(W, H, 11, np.random.default_rng(14), 3) > 0.62) & inner & ~cv.occ & ~pav
    for y0, x0 in zip(*np.nonzero(grass)):
        if (x0 * 7 + y0 * 3) % 3:
            cv.put(x0, y0, (98, 96, 58) if (x0 + y0) % 2 else (112, 108, 64))
    # руины: стены с проломами, разбитые башни
    for (px, py) in poisson(rng, inner & ~cv.occ, 18, 1500):
        L = int(rng.integers(6, 13))
        if not cv.free(px - L // 2 - 1, py - 11, px + L // 2 + 5, py + 2):
            continue
        gap = int(rng.integers(2, max(3, L - 2)))
        S.wall(cv, px - L // 2, px + L // 2, py, int(rng.integers(3, 5)), STONE, gaps=((px - L // 2 + gap, px - L // 2 + gap + 1),))
        if rng.random() < 0.8:
            S.tower(cv, px + L // 2 + 2, py + 1, 5, 7 + int(rng.integers(0, 4)), STONE, broken=rng.random() < 0.6)
        if rng.random() < 0.5:
            S.rock(cv, px - L // 2 - 2, py + 1, (150, 140, 128))
        cv.claim(px - L // 2 - 2, py - 9, px + L // 2 + 5, py + 3)
    for (px, py) in poisson(rng, inner & ~cv.occ, 6, 3000):
        r = rng.random()
        if r < 0.4:
            S.rock(cv, px, py, (128, 120, 112) if rng.random() < 0.5 else (150, 140, 128))
        elif r < 0.72:
            S.tuft(cv, px, py, (128, 118, 70) if rng.random() < 0.5 else (104, 98, 58))
        elif r < 0.86 and cv.free(px - 2, py - 6, px + 3, py + 1):
            c = (84, 64, 50)
            for j in range(5):
                cv.put(px, py - j, c)
            cv.put(px - 1, py - 3, c); cv.put(px - 2, py - 4, c); cv.put(px + 1, py - 4, c); cv.put(px + 2, py - 5, c)
            cv.shade(px + 1, py, 0.3); cv.shade(px + 2, py, 0.25)
            cv.claim(px - 2, py - 6, px + 3, py + 1)
        elif r < 0.93 and cv.free(px - 1, py - 4, px + 2, py + 1):
            # сломанный столб с факелом
            cv.put(px, py, (120, 110, 100)); cv.put(px, py - 1, (150, 140, 128)); S.flame(cv, px, py - 2)
            cv.claim(px - 1, py - 4, px + 2, py + 1)
        else:
            S.glowdot(cv, px, py, TORCH, 1, 0.25)

GREEN = [(24, 52, 40), (40, 96, 62), (62, 132, 78), (120, 178, 100)]
GREEN2 = [(22, 48, 40), (34, 84, 66), (52, 116, 86), (100, 168, 120)]
WATER = [(30, 90, 100), (48, 140, 144), (95, 208, 192), (180, 240, 230)]

def pond(cv, x, y, rx, ry, rng):
    for dy in range(-ry - 1, ry + 2):
        for dx in range(-rx - 1, rx + 2):
            e = (dx / rx) ** 2 + (dy / ry) ** 2
            if e <= 1.0:
                c = WATER[1] if e > 0.55 else WATER[2]
                if dy < -ry * 0.4 and e > 0.5:
                    c = WATER[0]
                cv.put(x + dx, y + dy, c)
            elif e <= 1.35 and dy > 0:
                cv.put(x + dx, y + dy, (58, 110, 80))
    for _ in range(max(2, rx // 2)):
        px = x + int(rng.integers(-rx + 2, rx - 1)); py = y + int(rng.integers(-ry + 1, ry))
        cv.put(px, py, (70, 150, 80)); cv.put(px + 1, py, (90, 170, 90))
        if rng.random() < 0.5:
            cv.put(px, py - 1, (250, 160, 190))
    cv.put(x - rx // 2, y - 1, WATER[3]); cv.put(x - rx // 2 + 1, y - 1, WATER[3])

def deco_r2(cv, t, rng, lm):
    """Затопленные сады: каналы, пруды, живые изгороди, розы, белый мрамор, беседка."""
    m = region_top(t, 2)
    inner = dist_inside(m) > 3
    canals = ridge_mask(np.random.default_rng(21), 30, 0.012, inner)
    for y, x in zip(*np.nonzero(canals)):
        cv.put(x, y, WATER[2] if (x + y) % 3 else WATER[3])
        cv.put(x, y + 1, WATER[1])
        cv.shade(x, y - 1, 0.15)
    cv.occ |= cv2.dilate(canals.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
    x, y = lm
    pond(cv, x, y - 3, 13, 6, rng)
    # беседка-ротонда в пруду
    bx, by = x, y - 3
    for i in (-3, -1, 1, 3):
        for j in range(4):
            cv.put(bx + i, by - j, (230, 230, 220) if i < 0 else (186, 190, 184))
    for i in range(-4, 5):
        cv.put(bx + i, by - 4, (210, 214, 206)); cv.put(bx + i, by + 1, (150, 156, 150))
    for j, half in enumerate((4, 4, 3, 2, 1)):
        for i in range(-half, half + 1):
            cv.put(bx + i, by - 5 - j, (95, 208, 192) if i < 1 else (48, 140, 144))
    cv.put(bx, by - 10, (230, 245, 240))
    cv.claim(x - 15, y - 16, x + 16, y + 6)
    # пруды
    for (px, py) in poisson(rng, inner & ~cv.occ, 30, 400)[:5]:
        rx, ry = int(rng.integers(4, 8)), int(rng.integers(2, 4))
        if cv.free(px - rx - 1, py - ry - 1, px + rx + 2, py + ry + 2):
            pond(cv, px, py, rx, ry, rng)
            cv.claim(px - rx - 1, py - ry - 2, px + rx + 2, py + ry + 2)
    # партер — прямоугольники живой изгороди
    for (px, py) in poisson(rng, inner & ~cv.occ, 28, 400)[:4]:
        w, h = int(rng.integers(8, 13)), int(rng.integers(5, 7))
        if not cv.free(px, py - h, px + w + 1, py + 2):
            continue
        for i in range(w):
            for j in (0, h - 1):
                cv.put(px + i, py - j, GREEN[1]); cv.put(px + i, py - j - 1, GREEN[2])
        for j in range(h):
            for i in (0, w - 1):
                cv.put(px + i, py - j, GREEN[1])
        cv.put(px + w // 2, py - h // 2, (220, 90, 120)); cv.put(px + w // 2 + 1, py - h // 2, (250, 150, 170))
        cv.claim(px, py - h - 1, px + w + 1, py + 2)
    pts = poisson(rng, inner & ~cv.occ, 6, 3000)
    for (px, py) in pts:
        r = rng.random()
        if r < 0.42 and cv.free(px - 3, py - 7, px + 4, py + 1):
            S.tree(cv, px, py, int(rng.integers(2, 4)), GREEN if rng.random() < 0.6 else GREEN2)
            cv.claim(px - 3, py - 7, px + 4, py + 1)
        elif r < 0.66:
            S.bush(cv, px, py, GREEN, 3, [(220, 90, 120), (250, 150, 170), (240, 220, 120)], rng)
        elif r < 0.74 and cv.free(px - 1, py - 4, px + 2, py + 1):
            # мраморная колонна (обломок)
            h = int(rng.integers(2, 5))
            for j in range(h):
                cv.put(px, py - j, (230, 230, 220)); cv.put(px + 1, py - j, (180, 184, 178))
            cv.shade(px + 2, py, 0.3)
            cv.claim(px - 1, py - 4, px + 2, py + 1)
        else:
            S.tuft(cv, px, py, (120, 178, 100))

AUTUMN = [
    [(59, 30, 30), (140, 59, 46), (180, 82, 52), (220, 120, 70)],
    [(70, 34, 24), (176, 92, 40), (214, 132, 50), (240, 180, 90)],
    [(76, 50, 26), (190, 136, 50), (217, 164, 65), (240, 210, 120)],
]
WOOD = ((176, 124, 80), (132, 88, 56))
ROOF3 = ((150, 58, 44), (112, 40, 34), (70, 24, 22))

def fence(cv, x0, x1, y):
    for x in range(x0, x1 + 1):
        if (x - x0) % 2 == 0:
            cv.put(x, y - 1, (150, 104, 64)); cv.put(x, y, (110, 74, 46))
        else:
            cv.put(x, y - 1, (126, 86, 54))
        cv.shade(x + 1, y + 1, 0.25)

def deco_r3(cv, t, rng, lm):
    """Псарни охоты: осенний лес, поляны с псарнями, загоны, охотничий дом."""
    m = region_top(t, 3)
    inner = dist_inside(m) > 2
    x, y = lm
    # большая поляна + дом ловчего
    for dy in range(-12, 8):
        for dx in range(-17, 18):
            if (dx / 17) ** 2 + (dy / 10) ** 2 < 1:
                cv.occ[y + dy, x + dx] = True
    S.house(cv, x, y - 2, 11, 4, WOOD, ROOF3, (40, 26, 20), (255, 200, 110))
    # рога на коньке
    for (ax, ay) in ((x - 2, y - 11), (x + 2, y - 11)):
        cv.put(ax, ay, (232, 220, 192)); cv.put(ax - 1 if ax < x else ax + 1, ay - 1, (232, 220, 192))
        cv.put(ax, ay - 2, (232, 220, 192))
    S.house(cv, x - 11, y + 2, 5, 2, WOOD, ((120, 80, 50), (96, 62, 40), (60, 38, 26)))
    S.house(cv, x + 12, y + 2, 5, 2, WOOD, ((120, 80, 50), (96, 62, 40), (60, 38, 26)))
    fence(cv, x - 16, x - 7, y + 5); fence(cv, x + 7, x + 16, y + 5)
    S.flame(cv, x + 4, y + 3)
    # малые поляны с псарнями
    clear = []
    for (px, py) in poisson(rng, inner & ~cv.occ, 34, 500)[:5]:
        if cv.free(px - 8, py - 7, px + 9, py + 4):
            clear.append((px, py))
            cv.claim(px - 9, py - 8, px + 10, py + 5)
            S.house(cv, px - 2, py, 5, 2, WOOD, ((120, 80, 50), (96, 62, 40), (60, 38, 26)))
            fence(cv, px + 2, px + 8, py + 2)
            if rng.random() < 0.6:
                S.house(cv, px + 5, py - 2, 3, 2, WOOD, ROOF3)
    # густой лес
    pts = poisson(rng, inner & ~cv.occ, 4, 6000)
    pts.sort(key=lambda p: p[1])
    for (px, py) in pts:
        if rng.random() < 0.88:
            r = int(rng.integers(2, 4)) + (1 if rng.random() < 0.2 else 0)
            S.tree(cv, px, py, r, AUTUMN[int(rng.integers(0, 3))], (60, 36, 24))
        else:
            S.pine(cv, px, py, int(rng.integers(5, 8)), [(30, 44, 32), (46, 70, 46), (62, 92, 56), (90, 120, 70)])

LAVA = [(130, 44, 28), (226, 103, 43), (255, 200, 87), (255, 244, 200)]
BASALT_HOUSE = ((86, 80, 96), (60, 56, 70))
BASALT_ROOF = ((70, 64, 80), (50, 46, 58), (30, 27, 34))

def deco_r4(cv, t, rng, lm):
    """Литейные: лавовые реки, трещины, кузни с трубами, кучи шлака, Великий горн."""
    m = region_top(t, 4)
    inner = dist_inside(m) > 2
    cracks = ridge_mask(np.random.default_rng(41), 9, 0.018, inner)
    for y, x in zip(*np.nonzero(cracks)):
        cv.put(x, y, (24, 21, 27))
    x, y = lm
    lava = np.zeros((H, W), bool)
    lrng = np.random.default_rng(43)
    dmap = dist_inside(m)
    srcs = [(x, y - 2, a) for a in (-2.6, -0.5, 1.9, 0.9)] + [(q[0], q[1], float(lrng.uniform(-3.1, 3.1))) for q in poisson(np.random.default_rng(45), inner, 40, 300)[:4]]
    for (sx0, sy0, ang) in srcs:
        px, py = float(sx0), float(sy0)
        a = ang
        for step in range(400):
            a += float(lrng.normal(0, 0.28))
            px += np.cos(a); py += np.sin(a) * 0.6
            ix, iy = int(px), int(py)
            if not (0 <= ix < W and 0 <= iy < H) or not m[iy, ix]:
                break
            if step > (14 if (sx0, sy0) == (x, y - 2) else 0):
                lava[iy, ix] = True
                if step % 3 == 0:
                    lava[iy, min(W - 1, ix + 1)] = True
    lava2 = cv2.dilate(lava.astype(np.uint8), np.ones((2, 2), np.uint8)).astype(bool) & m
    pools = poisson(np.random.default_rng(44), inner, 30, 300)[:6]
    for (qx, qy) in pools:
        for dy in range(-2, 3):
            for dx in range(-4, 5):
                if (dx / 4.2) ** 2 + (dy / 2.2) ** 2 < 1 and 0 <= qy + dy < H and 0 <= qx + dx < W and m[qy + dy, qx + dx]:
                    lava2[qy + dy, qx + dx] = True
                    if (dx / 2.5) ** 2 + (dy / 1.2) ** 2 < 1:
                        lava[qy + dy, qx + dx] = True
    glow = cv2.dilate(lava2.astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))).astype(bool) & m & ~lava2
    for yy0, xx0 in zip(*np.nonzero(glow)):
        cv.glow(xx0, yy0, (200, 70, 30), 0.3)
    for yy0, xx0 in zip(*np.nonzero(lava2)):
        cv.put(xx0, yy0, LAVA[1] if (xx0 * 3 + yy0) % 4 else LAVA[0])
    for yy0, xx0 in zip(*np.nonzero(lava)):
        cv.put(xx0, yy0, LAVA[2] if (xx0 + yy0) % 5 else LAVA[3])
    cv.occ |= cv2.dilate(lava2.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
    x, y = lm
    # Великий горн: купол с пылающим зевом и две трубы
    for dy in range(-12, 6):
        for dx in range(-16, 17):
            if (dx / 16) ** 2 + (dy / 11) ** 2 < 1:
                cv.occ[y + dy, x + dx] = True
    for dy in range(-9, 1):
        half = int(round(np.sqrt(max(0, 1 - (dy / 10.0) ** 2)) * 12))
        for dx in range(-half, half + 1):
            c = (96, 88, 106) if dx < -half // 2 else ((70, 64, 80) if dx < half // 2 else (46, 42, 54))
            if dy == -9 or abs(dx) == half:
                c = (36, 32, 42)
            cv.put(x + dx, y - 2 + dy, c)
    for dx in range(-4, 5):  # зев
        for dy in range(0, 4):
            cv.put(x + dx, y - 2 - dy, LAVA[3] if abs(dx) < 2 and dy < 2 else (LAVA[2] if abs(dx) < 3 else LAVA[1]))
    for dx in range(-12, 13):  # обод купола
        if dx % 3 == 0:
            cv.put(x + dx, y - 2 - int(round(np.sqrt(max(0, 1 - (dx / 12.5) ** 2)) * 6)), (226, 103, 43))
    for dx in range(-10, 11):
        cv.glow(x + dx, y + 1, (226, 103, 43), 0.4 * (1 - abs(dx) / 11))
        cv.glow(x + dx // 2, y + 2, (226, 103, 43), 0.3)
    for cxp, h in ((x - 7, 10), (x + 6, 13)):
        for j in range(h):
            cv.put(cxp - 1, y - 9 - j, (80, 74, 90)); cv.put(cxp, y - 9 - j, (60, 56, 70)); cv.put(cxp + 1, y - 9 - j, (40, 37, 48))
        cv.put(cxp - 1, y - 9 - h, LAVA[2]); cv.put(cxp, y - 9 - h, LAVA[1]); cv.put(cxp + 1, y - 9 - h, LAVA[0])
        S.glowdot(cv, cxp, y - 10 - h, (226, 103, 43), 3, 0.35)
        S.smoke(cv, cxp, y - 11 - h, 6, rng)
    # наковальня
    for i in range(-2, 3):
        cv.put(x + 11 + i, y - 1, (150, 146, 160))
    cv.put(x + 11, y, (100, 96, 110)); cv.put(x + 10, y + 1, (90, 86, 100)); cv.put(x + 12, y + 1, (90, 86, 100))
    # кузни
    for (px, py) in poisson(rng, inner & ~cv.occ, 18, 1500):
        if not cv.free(px - 5, py - 14, px + 7, py + 3):
            continue
        S.house(cv, px, py, 7, 4, BASALT_HOUSE, BASALT_ROOF, (255, 170, 70), (255, 200, 87))
        for j in range(8, 12):
            cv.put(px + 2, py - j, (60, 56, 70)); cv.put(px + 3, py - j, (40, 37, 48))
        cv.put(px + 2, py - 12, LAVA[1])
        S.smoke(cv, px + 2, py - 13, 4, rng)
        for dx in range(-3, 4):
            cv.glow(px + dx, py + 1, (226, 103, 43), 0.2)
        cv.claim(px - 5, py - 14, px + 7, py + 3)
    for (px, py) in poisson(rng, inner & ~cv.occ, 7, 2500):
        r = rng.random()
        if r < 0.35:  # шлак
            for dx in range(-2, 3):
                cv.put(px + dx, py, (36, 32, 40))
            for dx in range(-1, 2):
                cv.put(px + dx, py - 1, (58, 52, 64))
            cv.put(px, py - 2, (80, 74, 88)); cv.shade(px + 3, py, 0.3)
        elif r < 0.6:
            S.rock(cv, px, py, (86, 80, 96))
        elif r < 0.75:
            S.glowdot(cv, px, py, (226, 103, 43), 2, 0.3)  # тлеющие угли
        elif r < 0.85 and cv.free(px - 1, py - 4, px + 2, py + 1):
            for j in range(4):  # остывшая отливка-шип
                cv.put(px, py - j, (110, 104, 120) if j < 3 else (150, 144, 160))
            cv.shade(px + 1, py, 0.3)

LIB_WALL = ((120, 104, 200), (88, 76, 160), (60, 52, 118))
LIB_ROOF = ((142, 124, 224), (100, 86, 180), (52, 44, 104))
GLOW5 = (184, 227, 255)

def lib_tower(cv, x, y, w, h):
    x0 = x - w // 2
    S.shadow_right(cv, x0, y - h + 1, w, h, 0.35)
    S.block_shade(cv, x0, y - h + 1, w, h, *LIB_WALL)
    for j in range(2, h - 1, 3):
        cv.put(x, y - j, GLOW5)
        cv.glow(x - 1, y - j, GLOW5, 0.3)
    rh = w // 2 + 3
    for j in range(rh):
        half = (j * (w // 2 + 1)) // rh
        for i in range(-half, half + 1):
            cv.put(x + i, y - h - rh + j + 1, LIB_ROOF[0] if i < 0 else (LIB_ROOF[1] if i < half else LIB_ROOF[2]))
    cv.put(x, y - h - rh, GLOW5)

def shelf(cv, x, y, w):
    cols = [(170, 60, 70), (60, 110, 170), (200, 160, 80), (90, 150, 90), (150, 90, 170)]
    for i in range(w):
        c = cols[(x + i) % len(cols)]
        cv.put(x + i, y, c); cv.put(x + i, y - 1, lighten(c, 0.15))
    for i in range(-1, w + 1):
        cv.put(x + i, y - 2, (70, 50, 40)); cv.put(x + i, y + 1, (50, 36, 30))
    cv.shade(x + w + 1, y, 0.3)

def deco_r5(cv, t, rng, lm):
    """Зал хроник: плиты, башни-библиотеки, полки, круги рун, страницы, шпиль Хранилища."""
    m = region_top(t, 5)
    inner = dist_inside(m) > 2
    x, y = lm
    # площадь из плит вокруг шпиля
    for dy in range(-12, 9):
        for dx in range(-20, 21):
            if (dx / 20) ** 2 + (dy / 9) ** 2 < 1 and m[y + dy, x + dx]:
                px, py = x + dx, y + dy
                c = (66, 58, 128) if ((px + py) // 3 + (px - py) // 3) % 2 else (58, 51, 114)
                if (px + py) % 6 == 0 or (px - py) % 6 == 0:
                    c = (84, 74, 156)
                cv.put(px, py, c)
                cv.occ[py, px] = True
    # круг рун
    for a in np.linspace(0, 2 * np.pi, 64, endpoint=False):
        px = x + int(round(np.cos(a) * 14)); py = y + int(round(np.sin(a) * 6))
        cv.glow(px, py, GLOW5, 0.55)
    # шпиль Хранилища: ярусы-кольца памяти
    w0 = 13
    for tier in range(6):
        w = max(3, w0 - tier * 2)
        h = 5 if tier < 5 else 7
        yb = y - 1 - tier * 5
        x0 = x - w // 2
        S.block_shade(cv, x0, yb - h + 1, w, h, *LIB_WALL)
        for i in range(-1, w + 1):
            cv.put(x0 + i, yb - h + 1, LIB_ROOF[0] if i < w // 2 else LIB_ROOF[2])
        cv.put(x, yb - 2, GLOW5)
        S.shadow_right(cv, x0, yb - h + 1, w, h, 0.25, 1)
    tip = y - 1 - 6 * 5 - 3
    for j in range(4):
        cv.put(x, tip - j, GLOW5 if j < 3 else (255, 255, 255))
    S.glowdot(cv, x, tip - 4, GLOW5, 4, 0.5)
    # библиотечные башни
    for (px, py) in poisson(rng, inner & ~cv.occ, 17, 1500):
        hh = int(rng.integers(9, 15))
        ww = 5 if rng.random() < 0.65 else 7
        if not cv.free(px - ww // 2 - 1, py - hh - 6, px + ww // 2 + 3, py + 2):
            continue
        lib_tower(cv, px, py, ww, hh)
        if rng.random() < 0.5:
            lib_tower(cv, px + ww // 2 + 3, py + 1, 3, hh - 4)
        cv.claim(px - ww // 2 - 2, py - hh - 7, px + ww // 2 + 6, py + 3)
    for (px, py) in poisson(rng, inner & ~cv.occ, 8, 2500):
        r = rng.random()
        if r < 0.12 and cv.free(px - 1, py - 3, px + 7, py + 2):
            shelf(cv, px, py, int(rng.integers(3, 5)))
            cv.claim(px - 1, py - 3, px + 7, py + 2)
        elif r < 0.4:  # страница
            cv.put(px, py - 3, (236, 236, 250)); cv.put(px + 1, py - 3, (200, 200, 230))
            cv.shade(px + 1, py, 0.3)
        elif r < 0.68:  # кристалл
            cv.put(px, py, (120, 200, 240)); cv.put(px, py - 1, GLOW5); cv.put(px, py - 2, (235, 250, 255))
            cv.put(px + 1, py, (80, 140, 200)); cv.shade(px + 2, py, 0.3)
        elif r < 0.8:
            S.glowdot(cv, px, py, (142, 124, 224), 2, 0.35)
        else:
            S.rock(cv, px, py, (96, 86, 150))

def deco_islets(cv, t, rng):
    region = t['region']
    lab = t.get('islet_labels')
    ys, xs = np.nonzero(region == 9)
    if len(xs) == 0:
        return
    n, labels = cv2.connectedComponents((region == 9).astype(np.uint8))
    sizes = [(labels == i).sum() for i in range(1, n)]
    biggest = int(np.argmax(sizes)) + 1 if sizes else -1
    for i in range(1, n):
        yy, xx = np.nonzero(labels == i)
        cx, cy = int(xx.mean()), int(yy.mean())
        size = len(xx)
        if i == biggest:
            S.house(cv, cx, cy + 1, 5, 2, ((176, 124, 80), (132, 88, 56)), ((90, 80, 70), (70, 62, 56), (40, 36, 32)), (255, 190, 90), None)
            S.smoke(cv, cx + 1, cy - 6, 3, rng)
            S.glowdot(cv, cx - 3, cy + 1, (240, 170, 80), 2, 0.3)
        elif size > 25:
            S.tree(cv, cx - 1, cy + 1, 2, GREEN); S.rock(cv, cx + 2, cy + 1, (120, 114, 104))
        else:
            S.rock(cv, cx, cy, (120, 114, 104))
