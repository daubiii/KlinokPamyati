# Монохромный рендер пиксельных масок древа v2: оттенки серого (игра красит ImageColor3),
# автотон по материалу и тёмный контур. Понимает и маски v1 (icons.py, буквы материалов):
# светлые материалы → рамп HI, средние → MID, тёмное железо → LO.
from PIL import Image

OUTLINE = (16, 13, 12, 255)
RAMP = {
    'HI': (255, 222, 168),
    'MID': (214, 180, 134),
    'LO': (156, 124, 94),
}
# буквы v2
V2 = {'x': 'HI', 'z': 'LO'}
FIXED = {'o': 255, 'm': 200, 'd': 104}
# материалы v1 (pixel.PAL): яркие — HI, цветные — MID, тёмное железо — LO
V1 = {c: 'HI' for c in 'segycpeq'}
V1.update({c: 'MID' for c in 'rhbvtnwlf'})
V1['k'] = 'LO'

def _mat(c, v1):
    if c in FIXED or c == '#':
        return c
    return (V1 if v1 else V2).get(c.lower(), 'HI')

def render(rows, size, v1=False, outline=True):
    h = len(rows); w = max(len(r) for r in rows)
    grid = [[(rows[y][x] if x < len(rows[y]) else '.') for x in range(w)] for y in range(h)]
    def mat(x, y):
        if 0 <= y < h and 0 <= x < w and grid[y][x] != '.':
            return _mat(grid[y][x], v1) if grid[y][x] not in FIXED and grid[y][x] != '#' else grid[y][x]
        return None
    def raw(x, y):
        if 0 <= y < h and 0 <= x < w and grid[y][x] != '.':
            return grid[y][x].lower()
        return None
    xs = [x for y in range(h) for x in range(w) if grid[y][x] != '.']
    ys = [y for y in range(h) for x in range(w) if grid[y][x] != '.']
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    ox = (size - (x1 - x0 + 1)) // 2 - x0
    oy = (size - (y1 - y0 + 1)) // 2 - y0
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    px = img.load()
    filled = set()
    for y in range(h):
        for x in range(w):
            c = grid[y][x]
            if c == '.':
                continue
            if c == '#':
                v = OUTLINE[:3]
            elif c in FIXED:
                g = FIXED[c]; v = (g, g, g)
            else:
                light, mid, dark = RAMP[_mat(c, v1)]
                m = c.lower()
                if c.isupper() and v1:
                    g = dark
                else:
                    up = raw(x, y - 1) != m
                    left = raw(x - 1, y) != m
                    down = raw(x, y + 1) != m
                    right = raw(x + 1, y) != m
                    hi = up or left
                    lo = down or right
                    g = light if hi and not lo else dark if lo and not hi else mid
                v = (g, g, g)
            X, Y = x + ox, y + oy
            if 0 <= X < size and 0 <= Y < size:
                px[X, Y] = v + (255,)
                filled.add((X, Y))
    if outline:
        for (X, Y) in list(filled):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = X + dx, Y + dy
                if 0 <= nx < size and 0 <= ny < size and (nx, ny) not in filled and px[nx, ny][3] == 0:
                    px[nx, ny] = OUTLINE
    return img
