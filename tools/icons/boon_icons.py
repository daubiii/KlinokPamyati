"""Пиксельные иконки «Даров Эха» (карточки этажа), 20×20.
Рисуем в коде → превью PNG + Lua (Config/BoonIcons.lua): строки символов и палитра.
Интерфейс собирает иконку из Frame-полос, загружать картинки в Roblox не нужно.
python3 tools/icons/boon_icons.py"""
import math, os
from PIL import Image, ImageDraw

N = 20
ROOT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(ROOT, '..', '..'))

class Icon:
    def __init__(self, name, pal):
        self.name = name; self.pal = pal  # символ -> (r,g,b)
        self.g = [['.'] * N for _ in range(N)]
    def px(self, x, y, c):
        if 0 <= x < N and 0 <= y < N: self.g[y][x] = c
    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1): self.px(x, y, c)
    def disc(self, cx, cy, r, c):
        for y in range(N):
            for x in range(N):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r: self.px(x, y, c)
    def ring(self, cx, cy, r0, r1, c):
        for y in range(N):
            for x in range(N):
                d = math.hypot(x - cx, y - cy)
                if r0 <= d <= r1: self.px(x, y, c)
    def line(self, x0, y0, x1, y1, c, w=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(n + 1):
            t = i / n; x = x0 + (x1 - x0) * t; y = y0 + (y1 - y0) * t
            for dx in range(w):
                for dy in range(w): self.px(int(round(x)) + dx, int(round(y)) + dy, c)
    def poly(self, pts, c):
        for y in range(N):
            for x in range(N):
                if inside(pts, x + 0.5, y + 0.5): self.px(x, y, c)
    def rows(self, text, x0, y0):
        for j, row in enumerate(text.strip('\n').split('\n')):
            for i, ch in enumerate(row):
                if ch != ' ': self.px(x0 + i, y0 + j, ch)
    def outline(self, c='k'):
        src = [r[:] for r in self.g]
        for y in range(N):
            for x in range(N):
                if src[y][x] == '.':
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < N and 0 <= yy < N and src[yy][xx] not in '.':
                            self.g[y][x] = c; break

def inside(pts, x, y):
    c = False; j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]; xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi: c = not c
        j = i
    return c

K = (22, 16, 20)
icons = []

# 1. Голод душ — пламя души с клыками
i = Icon('soul_hunger', {'k': K, 'a': (88, 44, 140), 'b': (150, 90, 220), 'c': (214, 170, 255), 'w': (250, 244, 255), 'r': (200, 40, 60)})
i.poly([(10, 1), (15, 8), (16, 13), (13, 18), (7, 18), (4, 13), (5, 8), (8, 6)], 'a')
i.poly([(10, 4), (14, 10), (13, 16), (7, 16), (6, 11), (9, 8)], 'b')
i.poly([(10, 8), (12, 12), (11, 15), (8, 15), (8, 12)], 'c')
i.rect(7, 11, 8, 12, 'k'); i.rect(12, 11, 13, 12, 'k')
i.px(8, 15, 'w'); i.px(12, 15, 'w'); i.px(8, 16, 'w'); i.px(12, 16, 'w')
i.px(15, 3, 'c'); i.px(4, 5, 'c'); i.px(16, 6, 'b')
i.outline(); icons.append(i)

# 2. Крепкое сердце
i = Icon('vitality', {'k': K, 'a': (130, 18, 34), 'b': (210, 44, 56), 'c': (255, 120, 120), 'w': (255, 230, 230), 's': (240, 210, 160)})
i.disc(6.5, 7, 4, 'b'); i.disc(13.5, 7, 4, 'b'); i.poly([(2.5, 8), (17.5, 8), (10, 17.5)], 'b')
i.poly([(10, 17.5), (17.5, 8), (17, 11)], 'a'); i.disc(13.5, 6.5, 1.6, 'c')
i.rect(5, 5, 6, 6, 'w'); i.px(4, 7, 'c')
for y in range(7, 15, 2): i.px(10, y, 's'); i.px(9, y + 1, 's'); i.px(11, y + 1, 's')
i.outline(); icons.append(i)

# 3. Тень — силуэт в капюшоне и его двойник
i = Icon('evasion', {'k': K, 'a': (38, 40, 70), 'b': (70, 78, 130), 'c': (130, 150, 220), 'e': (140, 230, 255), 'g': (70, 78, 130)})
i.poly([(12, 2), (17, 7), (18, 18), (7, 18), (8, 7)], 'b')
i.poly([(12, 4), (15, 8), (15, 11), (9, 11), (9, 8)], 'a')
i.px(10, 9, 'e'); i.px(13, 9, 'e')
for y in range(3, 18, 2): i.line(3, y, 6, y, 'g')
i.poly([(7, 4), (9, 6), (6, 18), (3, 18), (3, 8)], 'c')
i.outline(); icons.append(i)

# 4. Ярость клинка — меч и полосы скорости
i = Icon('haste', {'k': K, 'a': (150, 160, 175), 'b': (215, 225, 235), 'w': (255, 255, 255), 'h': (120, 80, 50), 'g': (240, 190, 60), 'y': (255, 220, 90)})
i.line(4, 15, 14, 5, 'b', 2); i.line(5, 15, 15, 5, 'a'); i.line(15, 3, 16, 4, 'w')
i.px(16, 3, 'w'); i.px(15, 4, 'b')
i.line(3, 13, 7, 17, 'g', 2); i.line(2, 17, 4, 15, 'h', 2); i.px(1, 18, 'g')
for (x, y, l) in ((9, 2, 3), (12, 15, 4), (15, 11, 3), (6, 6, 2)): i.line(x, y, x + l, y, 'y')
i.outline(); icons.append(i)

# 5. Прилив душ — три души поднимаются
i = Icon('soul_surge', {'k': K, 'a': (40, 120, 140), 'b': (80, 210, 220), 'c': (190, 255, 250), 'w': (255, 255, 255)})
for cx, cy, r in ((5, 13, 2.6), (14, 12, 2.6), (10, 6, 3.2)):
    i.disc(cx, cy, r, 'b'); i.poly([(cx - r + 0.5, cy), (cx + r - 0.5, cy), (cx + 1, cy + r + 4), (cx - 1, cy + r + 3)], 'a')
    i.disc(cx - 0.6, cy - 0.6, r * 0.45, 'c'); i.px(int(cx - 1), int(cy - 1), 'w')
i.px(17, 3, 'c'); i.px(2, 5, 'c'); i.px(16, 17, 'b')
i.outline(); icons.append(i)

# 6. Закалённая сталь — наковальня и искры
i = Icon('might', {'k': K, 'a': (70, 74, 88), 'b': (120, 126, 145), 'c': (175, 182, 200), 'o': (255, 150, 40), 'y': (255, 230, 120)})
i.rect(3, 9, 17, 11, 'b'); i.poly([(0, 9), (3, 9), (3, 11)], 'b'); i.rect(3, 9, 17, 9, 'c')
i.rect(7, 12, 13, 14, 'a'); i.rect(5, 15, 15, 17, 'b'); i.rect(5, 17, 15, 17, 'a')
i.rect(9, 5, 11, 8, 'o'); i.px(10, 4, 'y'); i.px(10, 6, 'y')
for x, y in ((6, 3), (14, 2), (16, 5), (4, 6), (12, 1)): i.px(x, y, 'y')
i.outline(); icons.append(i)

# 7. Кровавая жажда — капля крови с клыком
i = Icon('leech', {'k': K, 'a': (110, 10, 24), 'b': (190, 24, 40), 'c': (250, 90, 90), 'w': (250, 245, 235)})
i.poly([(10, 1), (15, 10), (15, 14), (12, 18), (8, 18), (5, 14), (5, 10)], 'b')
i.poly([(10, 18), (15, 13), (15, 10), (13, 15)], 'a'); i.rect(7, 9, 8, 12, 'c'); i.px(8, 8, 'c')
i.poly([(9, 12), (13, 12), (11, 17)], 'w'); i.px(11, 16, 'c')
i.outline(); icons.append(i)

# 8. Каменная кожа — щит
i = Icon('bulwark', {'k': K, 'a': (90, 84, 78), 'b': (150, 140, 128), 'c': (205, 196, 180), 'g': (200, 160, 70), 'y': (250, 215, 120)})
i.poly([(3, 2), (17, 2), (17, 10), (10, 18.5), (3, 10)], 'b')
i.poly([(10, 2), (17, 2), (17, 10), (10, 18.5)], 'a')
i.rect(9, 2, 10, 17, 'g'); i.rect(3, 7, 17, 8, 'g'); i.rect(9, 7, 10, 8, 'y')
i.rect(4, 3, 7, 5, 'c')
i.outline(); icons.append(i)

# 9. Лёгкая поступь — крылатый сапог
i = Icon('swift', {'k': K, 'a': (110, 70, 40), 'b': (160, 105, 60), 'c': (210, 160, 100), 'w': (245, 245, 255), 'v': (180, 200, 230)})
i.rect(8, 4, 12, 13, 'b'); i.rect(8, 13, 17, 16, 'b'); i.rect(8, 16, 17, 17, 'a'); i.rect(8, 4, 12, 5, 'c')
i.rect(11, 4, 12, 13, 'a'); i.rect(14, 13, 17, 14, 'c')
i.poly([(8, 7), (1, 3), (2, 6), (0, 7), (3, 9), (1, 11), (8, 11)], 'w'); i.line(2, 5, 7, 8, 'v'); i.line(2, 9, 7, 10, 'v')
i.outline(); icons.append(i)

# 10. Второе дыхание — флакон
i = Icon('second_wind', {'k': K, 'a': (60, 130, 70), 'b': (110, 200, 110), 'c': (190, 255, 180), 'g': (190, 210, 220), 'h': (120, 80, 50), 'w': (255, 255, 255)})
i.rect(8, 1, 12, 3, 'h'); i.rect(8, 4, 12, 6, 'g'); i.disc(10, 12.5, 6, 'g'); i.disc(10, 13, 5, 'b')
i.rect(5, 9, 15, 10, 'g'); i.disc(10, 13, 5, 'b'); i.poly([(5, 13), (15, 13), (14, 17), (6, 17)], 'a')
i.disc(8, 11, 1.4, 'c'); i.px(7, 10, 'w'); i.px(12, 15, 'c'); i.px(9, 15, 'c')
i.outline(); icons.append(i)

# 11. Жатва — коса над черепом
i = Icon('reaper', {'k': K, 'a': (150, 150, 165), 'b': (220, 225, 235), 'h': (100, 70, 45), 'w': (240, 235, 220), 'e': (120, 230, 140)})
i.line(15, 2, 6, 19, 'h', 2)
i.poly([(14, 2), (4, 1), (1, 3), (3, 4), (8, 3), (14, 4)], 'b'); i.line(3, 3, 13, 3, 'a')
i.disc(11, 12, 4, 'w'); i.rect(9, 15, 13, 17, 'w'); i.rect(9, 11, 10, 12, 'k'); i.rect(12, 11, 13, 12, 'k')
i.px(10, 11, 'e'); i.px(12, 11, 'e'); i.px(10, 16, 'k'); i.px(12, 16, 'k')
i.outline(); icons.append(i)

# ---- превью и Lua ----
S = 8
sheet = Image.new('RGBA', (len(icons) * (N * S + 16) + 16, N * S + 32), (34, 28, 30, 255))
for n, ic in enumerate(icons):
    im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    for y in range(N):
        for x in range(N):
            ch = ic.g[y][x]
            if ch != '.': im.putpixel((x, y), ic.pal[ch] + (255,))
    big = im.resize((N * S, N * S), Image.NEAREST); sheet.paste(big, (16 + n * (N * S + 16), 16), big)
sheet.save(os.path.join(ROOT, 'boon_icons_preview.png'))

def lua_color(c):
    return 'Color3.fromRGB(%d, %d, %d)' % c
out = ['--!nonstrict', '-- BoonIcons — пиксельные иконки «Даров Эха» 20×20 (tools/icons/boon_icons.py).',
       '-- Рисует Lib/BoonCard (Frame-полосами), картинки загружать не нужно.',
       '-- rows: строки сверху вниз, "." — прозрачно, остальные символы — цвета из pal.', '',
       'return {', '\tsize = %d,' % N]
for ic in icons:
    used = {ch for row in ic.g for ch in row if ch != '.'}
    out.append('\t%s = {' % ic.name)
    out.append('\t\tpal = { ' + ', '.join('%s = %s' % (k, lua_color(v)) for k, v in sorted(ic.pal.items()) if k in used) + ' },')
    out.append('\t\trows = {')
    for row in ic.g:
        out.append('\t\t\t"%s",' % ''.join(row))
    out.append('\t\t},')
    out.append('\t},')
out.append('}')
open(os.path.join(REPO, 'src/ReplicatedStorage/Shared/Config/BoonIcons.lua'), 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print('иконок', len(icons))
