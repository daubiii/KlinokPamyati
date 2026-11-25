# Спрайты карты: деревья, башни, дома, горны, библиотеки. Рисуются прямо в массив.
import numpy as np
from paint import lighten, darken

OUT = (24, 18, 20)

class Canvas:
    def __init__(self, img, land_top):
        self.img = img
        self.h, self.w = img.shape[:2]
        self.top = land_top          # где можно ставить (верх плато, не стена)
        self.occ = np.zeros((self.h, self.w), bool)

    def put(self, x, y, c, force=True):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            if len(c) == 4:
                a = c[3] / 255.0
                old = self.img[y, x].astype(float)
                self.img[y, x] = (old * (1 - a) + np.array(c[:3]) * a).astype(np.uint8)
            else:
                self.img[y, x] = c

    def get(self, x, y):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            return tuple(int(v) for v in self.img[y, x])
        return (0, 0, 0)

    def shade(self, x, y, f):
        self.put(x, y, darken(self.get(x, y), f))

    def glow(self, x, y, c, f):
        g = self.get(x, y)
        self.put(x, y, tuple(int(g[i] + (c[i] - g[i]) * f) for i in range(3)))

    def free(self, x0, y0, x1, y1):
        x0, y0 = max(0, int(x0)), max(0, int(y0))
        x1, y1 = min(self.w, int(x1)), min(self.h, int(y1))
        if x1 <= x0 or y1 <= y0:
            return False
        return (not self.occ[y0:y1, x0:x1].any()) and self.top[y0:y1, x0:x1].all()

    def claim(self, x0, y0, x1, y1):
        x0, y0 = max(0, int(x0)), max(0, int(y0))
        self.occ[y0:int(y1), x0:int(x1)] = True

    def template(self, x, y, rows, pal):
        """rows — строки, pal — символ → цвет (None/'.' — пусто). x,y — левый верх."""
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                c = pal.get(ch)
                if c is not None:
                    self.put(x + i, y + j, c)

# ===== растительность =====

def tree(cv, x, y, r, pal, trunk=(70, 46, 30)):
    """Круглая крона: x,y — точка у земли (низ ствола). pal: [тень, тёмный, средний, светлый]."""
    cx, cy = x, y - r - 1
    # тень на земле
    for dx in range(-r, r + 2):
        cv.shade(x + dx, y, 0.35)
        if abs(dx) < r:
            cv.shade(x + dx + 1, y + 1, 0.2)
    cv.put(x, y, trunk); cv.put(x, y - 1, trunk)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d2 = dx * dx + dy * dy
            if d2 <= r * r + r * 0.6:
                s = dx * 0.7 + dy
                if d2 >= (r - 0.6) ** 2 and (dy > 0 or dx > 0):
                    c = pal[0]
                elif s < -r * 0.55:
                    c = pal[3]
                elif s < r * 0.15:
                    c = pal[2]
                else:
                    c = pal[1]
                cv.put(cx + dx, cy + dy, c)
    # пара бликов
    cv.put(cx - r // 2, cy - r // 2, lighten(pal[3], 0.25))

def pine(cv, x, y, h, pal, trunk=(60, 40, 28)):
    for dx in range(-2, 3):
        cv.shade(x + dx, y, 0.3)
    cv.put(x, y, trunk)
    for j in range(h):
        yy = y - 1 - j
        half = max(0, (j % 3) + (h - j) // 3 - 1)
        half = min(half, 3)
        for dx in range(-half, half + 1):
            c = pal[2] if dx < 0 else pal[1]
            if dx == half:
                c = pal[0]
            cv.put(x + dx, yy, c)
    cv.put(x, y - h, pal[3])

def bush(cv, x, y, pal, w=3, flowers=None, rng=None):
    for dx in range(w):
        cv.put(x + dx, y, pal[1]); cv.put(x + dx, y - 1, pal[2])
        cv.shade(x + dx + 1, y + 1, 0.25)
    cv.put(x, y - 1, pal[3])
    if flowers and rng is not None:
        for _ in range(2):
            cv.put(x + int(rng.integers(0, w)), y - int(rng.integers(0, 2)), flowers[int(rng.integers(0, len(flowers)))])

def rock(cv, x, y, base=(120, 114, 108)):
    cv.put(x, y, darken(base, 0.3)); cv.put(x + 1, y, darken(base, 0.4))
    cv.put(x, y - 1, lighten(base, 0.2)); cv.put(x + 1, y - 1, base)
    cv.shade(x + 2, y, 0.3); cv.shade(x, y + 1, 0.25); cv.shade(x + 1, y + 1, 0.25)

def tuft(cv, x, y, c):
    cv.put(x, y, c); cv.put(x + 1, y - 1, c); cv.put(x + 2, y, c)

# ===== постройки =====

def block_shade(cv, x0, y0, w, h, light, mid, dark):
    for j in range(h):
        for i in range(w):
            c = mid
            if i == 0:
                c = light
            elif i == w - 1:
                c = dark
            cv.put(x0 + i, y0 + j, c)

def shadow_right(cv, x0, y0, w, h, f=0.35, n=2):
    for j in range(h):
        for i in range(n):
            cv.shade(x0 + w + i, y0 + j + i + 1, f)
    for i in range(w):
        cv.shade(x0 + i + 1, y0 + h, f * 0.8)

def tower(cv, x, y, w=5, h=9, stone=((190, 182, 170), (150, 140, 128), (104, 96, 88)), roof=None, broken=False, window=(30, 24, 26), rng=None):
    """x,y — низ-центр. Каменная башня с зубцами (или крышей)."""
    x0 = x - w // 2; y0 = y - h + 1
    shadow_right(cv, x0, y0, w, h)
    block_shade(cv, x0, y0, w, h, *stone)
    for i in range(w):  # каменная кладка
        for j in range(2, h, 3):
            if (i + j) % 4 == 0:
                cv.put(x0 + i, y0 + j, darken(stone[1], 0.15))
    cv.put(x, y0 + h // 2 - 1, window); cv.put(x, y0 + h // 2, window)
    if roof:
        rh = w // 2 + 2
        for j in range(rh):
            half = (j * (w + 1)) // (2 * rh)
            for i in range(-half, half + 1):
                c = roof[0] if i < 0 else roof[1]
                if i == half:
                    c = roof[2]
                cv.put(x + i, y0 - rh + j, c)
        cv.put(x, y0 - rh - 1, roof[0])
    else:
        for i in range(w):
            if i % 2 == 0 and not (broken and i > w // 2):
                cv.put(x0 + i, y0 - 1, stone[0] if i == 0 else stone[1])
        cv.put(x0 - 1, y0, stone[2]); cv.put(x0 + w, y0, OUT)
        if broken:
            for i in range(w // 2, w):
                for j in range(0, 2 + (i % 2)):
                    cv.put(x0 + i, y0 + j, cv.get(x0 + i, y0 - 3) if False else None)
                cv.put(x0 + i, y0 + (i % 2), darken(stone[2], 0.2))

def wall(cv, x0, x1, y, h=3, stone=((176, 168, 156), (138, 128, 118), (96, 88, 82)), gaps=()):
    for x in range(x0, x1 + 1):
        if any(a <= x <= b for a, b in gaps):
            continue
        for j in range(h):
            c = stone[1]
            if j == 0:
                c = stone[0]
            if (x + j * 2) % 4 == 0 and j > 0:
                c = stone[2]
            cv.put(x, y - j, c)
        if (x - x0) % 2 == 0:
            cv.put(x, y - h, stone[0])
        cv.shade(x + 1, y + 1, 0.35)

def house(cv, x, y, w=5, h=3, wall_c=((200, 170, 120), (160, 128, 88)), roof=((150, 58, 44), (110, 40, 34), (70, 24, 22)), door=(40, 26, 20), window=None):
    """x,y — низ-центр. Домик с двускатной крышей (вид сверху-спереди)."""
    x0 = x - w // 2
    shadow_right(cv, x0, y - h - 2, w, h + 3, 0.3)
    for j in range(h):
        for i in range(w):
            cv.put(x0 + i, y - j, wall_c[0] if i < w - 1 else wall_c[1])
    cv.put(x, y, door)
    if window:
        cv.put(x0 + 1, y - 1, window)
        if w > 4:
            cv.put(x0 + w - 2, y - 1, window)
    rh = 3
    for j in range(rh):
        for i in range(-1, w + 1):
            c = roof[0] if j == 0 else roof[1]
            if i in (-1, w):
                c = roof[2]
            cv.put(x0 + i, y - h - j, c if j < rh - 1 or 0 <= i < w else None)
    for i in range(w):
        cv.put(x0 + i, y - h - rh, lighten(roof[0], 0.2) if i < w - 1 else roof[1])

def smoke(cv, x, y, n, rng, c=((120, 116, 126), (150, 146, 154))):
    px, py = x, y
    for k in range(n):
        px += int(rng.integers(-1, 2)) + (1 if k % 2 else 0)
        py -= 2
        r = 1 if k < 2 else 2
        for dy in range(-r + 1, 1):
            for dx in range(-r + 1, r):
                cv.put(px + dx, py + dy, (*c[k % 2], 210 - k * 25))

def flame(cv, x, y):
    cv.put(x, y, (255, 200, 87)); cv.put(x, y - 1, (226, 103, 43))
    for dx, dy in ((-1, 0), (1, 0), (0, 1), (0, -2)):
        cv.glow(x + dx, y + dy, (226, 120, 50), 0.4)

def glowdot(cv, x, y, c, r=2, f=0.35):
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d = abs(dx) + abs(dy)
            if 0 < d <= r:
                cv.glow(x + dx, y + dy, c, f * (1 - (d - 1) / r))
    cv.put(x, y, lighten(c, 0.3))
