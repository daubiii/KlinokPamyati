# Рендер ASCII-иконок в RGBA 16×16: автотон и контур.
from PIL import Image

OUTLINE = (0, 48, 59, 255)
# материал: (светлый, средний, тёмный)
PAL = {
    's': ((228, 238, 243), (171, 195, 206), (107, 131, 144)),  # сталь
    'k': ((136, 149, 167), (90, 96, 103), (47, 61, 69)),        # тёмное железо / камень
    'g': ((255, 226, 120), (250, 196, 54), (196, 120, 28)),     # золото
    'y': ((255, 244, 170), (250, 214, 84), (214, 150, 40)),     # свет / песок / молния
    'r': ((236, 70, 74), (176, 42, 54), (112, 26, 40)),         # красный
    'h': ((255, 128, 128), (220, 56, 64), (150, 30, 44)),       # сердце
    'b': ((138, 172, 217), (78, 112, 186), (48, 66, 128)),      # синий
    'v': ((190, 142, 232), (132, 82, 196), (82, 48, 136)),      # фиолетовый
    't': ((110, 226, 200), (32, 170, 150), (14, 110, 104)),     # бирюза
    'c': ((200, 246, 255), (120, 216, 240), (64, 150, 196)),    # циан / стекло магии
    'n': ((110, 210, 110), (40, 150, 90), (20, 96, 70)),        # зелень
    'w': ((198, 154, 108), (158, 116, 80), (104, 76, 60)),      # дерево
    'l': ((196, 136, 90), (150, 92, 58), (96, 58, 40)),         # кожа
    'p': ((252, 244, 222), (236, 221, 192), (196, 174, 138)),   # бумага
    'e': ((255, 255, 255), (232, 240, 246), (186, 210, 224)),   # белый
    'f': ((255, 196, 84), (240, 120, 40), (190, 60, 30)),       # огонь
    'q': ((255, 222, 184), (238, 186, 140), (194, 134, 96)),    # кожа рук
}

def render(rows, size=16, outline=True, center=True):
    h = len(rows); w = max(len(r) for r in rows)
    grid = [[(rows[y][x] if x < len(rows[y]) else '.') for x in range(w)] for y in range(h)]
    def mat(x, y):
        if 0 <= y < h and 0 <= x < w:
            c = grid[y][x]
            return None if c == '.' else c.lower()
        return None
    # рамка: bbox → центр
    xs = [x for y in range(h) for x in range(w) if grid[y][x] != '.']
    ys = [y for y in range(h) for x in range(w) if grid[y][x] != '.']
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    bw, bh = x1 - x0 + 1, y1 - y0 + 1
    ox = (size - bw) // 2 - x0 if center else 1
    oy = (size - bh) // 2 - y0 if center else 1
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    px = img.load()
    filled = set()
    for y in range(h):
        for x in range(w):
            c = grid[y][x]
            if c == '.':
                continue
            m = c.lower()
            light, mid, dark = PAL[m]
            if c.isupper():
                col = dark
            else:
                up = mat(x, y - 1) != m
                left = mat(x - 1, y) != m
                down = mat(x, y + 1) != m
                right = mat(x + 1, y) != m
                hi = up or left
                lo = down or right
                if hi and not lo:
                    col = light
                elif lo and not hi:
                    col = dark
                else:
                    col = mid
            X, Y = x + ox, y + oy
            if 0 <= X < size and 0 <= Y < size:
                px[X, Y] = col + (255,)
                filled.add((X, Y))
    if outline:
        for (X, Y) in list(filled):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = X + dx, Y + dy
                if 0 <= nx < size and 0 <= ny < size and (nx, ny) not in filled and px[nx, ny][3] == 0:
                    px[nx, ny] = OUTLINE
    return img
