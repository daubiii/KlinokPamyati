# Арт древа талантов v2 (мрачный пиксельный стиль, одно цвет): атлас иконок и рамок,
# фоны древа классов с печатью и фирменным предметом класса.
#   python3 tools/talents/build_talent_art.py
# → assets/talents/talent_atlas.png, talent_bg_warrior.png, talent_bg_mage.png,
#   talent_bg_assassin.png (на будущее), src/ReplicatedStorage/Shared/Config/TalentAtlas.lua.
# Всё в «родных» пикселях; игра показывает ×2 (Pixelated): малый узел 13 → 26 px,
# узел 23 → 46, ключевой 29 → 58, иконка 16 → 32, глиф 7 → 14, фон 560×374 → 1120×748.
# Иконки и кольца — оттенки серого: цвет (золото / кость / пепел) задаёт ImageColor3.
import math, os, random, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
from icons import ICONS as V1
from icons2 import GLYPHS, ICONS as V2, CLASS
from mono import render, OUTLINE

OUT = os.path.join(ROOT, 'assets', 'talents')
os.makedirs(OUT, exist_ok=True)

# Иконки узлов → силуэт v1 (icons.py) или новая маска (icons2.py).
FROM_V1 = {
    # воин · Защита
    'i_heart': 't_heart', 'i_plate': 't_plate', 'i_flask': 't_flask', 'i_towershield': 't_towershield',
    'i_anchor': 't_anchor', 'k_retaliate': 't_retaliate', 'k_fort': 't_fort', 'k_unbending': 't_unbending',
    # воин · Натиск
    'i_sword': 't_sword', 'i_gauntlet': 't_gauntlet', 'i_arc': 't_arc', 'i_soulflame': 't_soulflame',
    'i_target': 't_target', 'k_crossed': 't_crossed', 'k_fury': 't_fury', 'k_hammer': 't_hammer',
    # воин · Парирование
    'i_eye': 't_eye', 'i_buckler': 't_buckler', 'i_bash': 't_bash', 'i_boot': 't_boot',
    'i_counter': 't_counter', 'k_mirror': 't_mirror', 'k_helm': 't_helm', 'k_rings': 't_rings',
    # маг · Источник
    'i_inkwell': 't_inkwell', 'i_wind': 't_wind', 'i_scroll': 't_scroll', 'i_vial': 't_potion',
    'i_book': 't_book', 'k_well': 't_orb', 'k_twinrune': 't_twinrune', 'k_hood': 't_hood',
    # маг · Посох
    'i_crystal': 't_crystal', 'i_swift': 't_feather', 'i_hand': 't_hand', 'i_seek': 't_target',
    'k_beam': 't_beam', 'k_prism': 't_prism',
    # маг · Чары
    'i_quill': 't_quill', 'i_moon': 't_moon', 'i_edge': 't_bolt', 'i_dagger': 't_dagger',
    'k_hourglass': 't_hourglass', 'k_wave': 't_wave', 'k_closedeye': 't_closedeye',
}

# ---------------------------------------------------------------- рамки
def piece(size, fn):
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    px = im.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            col = fn(x - c, y - c)
            if col:
                px[x, y] = col if len(col) == 4 else col + (255,)
    return im

def oct_metric(dx, dy):
    return max(abs(dx), abs(dy), (abs(dx) + abs(dy)) * 0.72)

def shade(dx, dy, r, lo=138, hi=255):
    # свет сверху-слева, тень снизу-справа (серый — под тинт)
    t = -(dx + dy) / (r * 1.414)
    g = int(round((hi + lo) / 2 + (hi - lo) / 2 * max(-1, min(1, t * 1.6))))
    return (g, g, g)

FILL = (30, 26, 24)
HOLE = (19, 16, 15)
BEVEL = (11, 9, 8)

def minor_base(dx, dy):
    d = math.hypot(dx, dy)
    if d <= 6.45:
        return OUTLINE if d > 5.55 else (HOLE if d < 3.9 else FILL)

def minor_ring(dx, dy):
    d = math.hypot(dx, dy)
    if 4.0 <= d < 5.55:
        return shade(dx, dy, 5)

def normal_base(dx, dy):
    d = math.hypot(dx, dy)
    if d <= 11.45:
        if d > 10.6:
            return OUTLINE
        if d < 7.4:
            return HOLE
        if d < 8.0:
            return BEVEL
        return FILL

def normal_ring(dx, dy):
    d = math.hypot(dx, dy)
    if 8.7 <= d < 10.6:
        return shade(dx, dy, 10)
    if 8.0 <= d < 8.7:
        g = 92
        return (g, g, g)

def key_base(dx, dy):
    m = oct_metric(dx, dy)
    d = math.hypot(dx, dy)
    if m <= 14.4:
        if m > 13.5:
            return OUTLINE
        if d < 8.6:
            return HOLE
        if d < 9.3:
            return BEVEL
        return FILL

def key_ring(dx, dy):
    m = oct_metric(dx, dy)
    d = math.hypot(dx, dy)
    if 11.6 <= m < 13.5:
        return shade(dx, dy, 13)
    if 9.3 <= d < 10.3:
        return shade(dx, dy, 10, 110, 200)
    # заклёпки на гранях восьмиугольника
    for ax, ay in ((0, -1), (1, 0), (0, 1), (-1, 0)):
        rx, ry = ax * 12.55, ay * 12.55
        if abs(dx - rx) < 0.6 and abs(dy - ry) < 0.6:
            return (70, 70, 70)

def root_base(dx, dy):
    d = math.hypot(dx, dy)
    if d <= 11.45:
        if d > 10.6:
            return OUTLINE
        if d < 8.0:
            return HOLE
        return FILL

def root_ring(dx, dy):
    d = math.hypot(dx, dy)
    if 9.0 <= d < 10.6:
        return shade(dx, dy, 10)
    if 8.0 <= d < 9.0:
        a = math.degrees(math.atan2(dy, dx)) % 45
        if a < 9 or a > 36:
            return (150, 150, 150)

def glow(size=32):
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    px = im.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / (size / 2)
            if d < 1:
                # пиксельные ступени свечения
                a = int(round(((1 - d) ** 1.6) * 6)) * 30
                if a > 0:
                    px[x, y] = (255, 255, 255, min(a, 200))
    return im

def from_ascii(rows, pal):
    h = len(rows); w = max(len(r) for r in rows)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal:
                im.putpixel((x, y), pal[ch])
    return im

W_ = (255, 255, 255, 255); G_ = (170, 170, 170, 255); O_ = OUTLINE
# цена ключевого узла: тёмный ромб с кольцом (под тинт)
BADGE = from_ascii([
    '....o....',
    '...oWo...',
    '..oWfWo..',
    '.oWfffWo.',
    'oWfffffWo',
    '.oWfffWo.',
    '..oWfWo..',
    '...oWo...',
    '....o....',
], {'o': O_, 'W': W_, 'f': (36, 31, 29, 255)})
# уголок рамки выбора (поворачивается в игре на 0/90/180/270°)
SEL = from_ascii([
    'oooooo',
    'oWWWWo',
    'oWoooo',
    'oWo...',
    'oWo...',
    'ooo...',
], {'o': O_, 'W': W_})

# ---------------------------------------------------------------- атлас
pieces = {}
missing = []
for name, src in FROM_V1.items():
    if src not in V1:
        missing.append(src)
        continue
    pieces[name] = render(V1[src], 16, v1=True)
for name, rows in V2.items():
    pieces[name] = render(rows, 16)
for name, rows in GLYPHS.items():
    pieces[name] = render(rows, 7)
for name, rows in CLASS.items():
    pieces[name] = render(rows, 16)
assert not missing, missing
pieces.update({
    'frame_m_base': piece(13, minor_base), 'frame_m_ring': piece(13, minor_ring),
    'frame_n_base': piece(23, normal_base), 'frame_n_ring': piece(23, normal_ring),
    'frame_k_base': piece(29, key_base), 'frame_k_ring': piece(29, key_ring),
    'root_base': piece(23, root_base), 'root_ring': piece(23, root_ring),
    'glow': glow(32), 'badge': BADGE, 'sel': SEL,
})

def pack(pieces, width=256, pad=2):
    order = sorted(pieces, key=lambda n: (-pieces[n].height, n))
    x = y = pad
    shelf = 0
    rects = {}
    for n in order:
        im = pieces[n]
        if x + im.width + pad > width:
            x = pad
            y += shelf + pad
            shelf = 0
        rects[n] = (x, y, im.width, im.height)
        x += im.width + pad
        shelf = max(shelf, im.height)
    height = y + shelf + pad
    h2 = 1
    while h2 < height:
        h2 *= 2
    atlas = Image.new('RGBA', (width, h2), (0, 0, 0, 0))
    for n, (x, y, w, h) in rects.items():
        atlas.alpha_composite(pieces[n], (x, y))
    return atlas, rects

atlas, rects = pack(pieces)
atlas.save(os.path.join(OUT, 'talent_atlas.png'))

lua = ['--!nonstrict',
       '-- TalentAtlas (сгенерировано tools/talents/build_talent_art.py — не править руками)',
       '-- Куски assets/talents/talent_atlas.png в родных пикселях; игра показывает ×2.',
       '-- Всё в оттенках серого — цвет задаёт ImageColor3 (Windows/TalentPage):',
       '--   i_* / k_* — иконки узлов и ключевых узлов 16×16, g_* — глифы малых узлов 7×7,',
       '--   cls_* — предмет класса (корень древа), frame_m/n/k — рамки малого, обычного и',
       '--   ключевого узла (base — тёмная подложка, ring — кольцо под тинт), root — корень,',
       '--   glow — свечение, badge — ромб цены, sel — уголок рамки выбора.',
       'local TalentAtlas = {}',
       'TalentAtlas.Size = { w = %d, h = %d }' % atlas.size,
       'TalentAtlas.Pieces = {']
for n in sorted(rects):
    x, y, w, h = rects[n]
    lua.append('\t%s = { x = %d, y = %d, w = %d, h = %d },' % (n, x, y, w, h))
lua += ['}', '', 'return TalentAtlas', '']
open(os.path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared', 'Config', 'TalentAtlas.lua'), 'w', encoding='utf-8').write('\n'.join(lua))
print('atlas', atlas.size, len(rects), 'pieces')

# ---------------------------------------------------------------- фоны
W, H = 560, 374
BASE = (20, 17, 16)
PATHS = (100, 280, 460)          # центры путей в родных px (TalentPage: 200/560/920 ÷ 2)
SEAL = (280, 196)                # печать класса

def lift(k):
    return tuple(min(255, c + k) for c in BASE)

def draw_seal(d, kind, rng):
    cx, cy = SEAL
    def circle(r, col, width=1):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col, width=width)
    circle(132, lift(14), 2)
    circle(126, lift(9))
    circle(100, lift(9))
    # насечки между кольцами
    for i in range(72):
        a = math.radians(i * 5)
        r0, r1 = (127, 131) if i % 3 else (102, 125)
        col = lift(11) if i % 3 else lift(6)
        d.line([cx + math.cos(a) * r0, cy + math.sin(a) * r0, cx + math.cos(a) * r1, cy + math.sin(a) * r1], fill=col)
    # знаки по кругу (короткие «руны» — штрихи)
    for i in range(12):
        a = math.radians(i * 30 + 15)
        x, y = cx + math.cos(a) * 113, cy + math.sin(a) * 113
        for j in range(3):
            ox, oy = rng.randint(-3, 3), rng.randint(-3, 3)
            d.line([x + ox, y + oy, x - oy, y + ox], fill=lift(12))
    # семиконечная звезда во внутреннем круге
    pts = [(cx + math.cos(math.radians(-90 + k * 360 / 7)) * 98, cy + math.sin(math.radians(-90 + k * 360 / 7)) * 98) for k in range(7)]
    for k in range(7):
        d.line([pts[k], pts[(k + 3) % 7]], fill=lift(6))
    # предмет класса
    ITEMS[kind](d, cx, cy)

def helm(d, cx, cy):
    f, hi, lo, cut = lift(9), lift(16), lift(5), lift(0)
    # купол и личина
    body = [(cx - 42, cy + 52), (cx - 46, cy - 6), (cx - 40, cy - 40), (cx - 24, cy - 60), (cx, cy - 66),
            (cx + 24, cy - 60), (cx + 40, cy - 40), (cx + 46, cy - 6), (cx + 42, cy + 52), (cx, cy + 62)]
    d.polygon(body, fill=f)
    d.line(body[:6], fill=hi, width=2)
    d.line(body[5:] + [body[0]], fill=lo, width=2)
    # гребень
    d.rectangle([cx - 4, cy - 66, cx + 4, cy + 60], fill=hi)
    d.rectangle([cx + 1, cy - 66, cx + 4, cy + 60], fill=f)
    # смотровая щель и дыхальца
    d.rectangle([cx - 38, cy - 10, cx + 38, cy - 2], fill=cut)
    d.rectangle([cx - 4, cy - 10, cx + 4, cy - 2], fill=cut)
    for row in range(3):
        for col in range(3):
            x = cx + 12 + col * 8; y = cy + 14 + row * 9
            d.rectangle([x, y, x + 3, y + 3], fill=cut)
            d.rectangle([2 * cx - x - 3, y, 2 * cx - x, y + 3], fill=cut)
    # заклёпки по нижнему краю и крест над щелью
    for t in range(-4, 5):
        x = cx + t * 9
        d.rectangle([x - 1, cy + 50 - abs(t), x + 1, cy + 52 - abs(t)], fill=hi)
    d.rectangle([cx - 16, cy - 40, cx + 16, cy - 34], fill=hi)
    d.rectangle([cx - 16, cy - 37, cx + 16, cy - 34], fill=f)

def hat(d, cx, cy):
    f, hi, lo, cut = lift(9), lift(16), lift(5), lift(0)
    # поля
    d.ellipse([cx - 82, cy + 30, cx + 82, cy + 62], fill=f)
    d.arc([cx - 82, cy + 30, cx + 82, cy + 62], 180, 360, fill=hi, width=2)
    d.arc([cx - 82, cy + 30, cx + 82, cy + 62], 0, 180, fill=lo, width=2)
    # конус с заломом
    cone = [(cx - 44, cy + 44), (cx - 30, cy - 4), (cx - 14, cy - 44), (cx + 4, cy - 70), (cx + 30, cy - 86),
            (cx + 58, cy - 78), (cx + 40, cy - 70), (cx + 22, cy - 52), (cx + 30, cy - 4), (cx + 44, cy + 44)]
    d.polygon(cone, fill=f)
    d.line(cone[:6], fill=hi, width=2)
    d.line(cone[6:], fill=lo, width=2)
    # лента и пряжка
    d.polygon([(cx - 40, cy + 24), (cx + 40, cy + 24), (cx + 43, cy + 40), (cx - 43, cy + 40)], fill=cut)
    d.rectangle([cx - 10, cy + 22, cx + 10, cy + 42], outline=hi, width=2)
    # заплаты-стежки
    for i in range(4):
        d.line([cx - 18 + i * 4, cy - 20 + i * 2, cx - 14 + i * 4, cy - 24 + i * 2], fill=lo)

def dagger(d, cx, cy):
    f, hi, lo, cut = lift(9), lift(16), lift(5), lift(0)
    blade = [(cx, cy - 78), (cx + 13, cy - 52), (cx + 13, cy + 14), (cx - 13, cy + 14), (cx - 13, cy - 52)]
    d.polygon(blade, fill=f)
    d.line([(cx, cy - 78), (cx, cy + 12)], fill=hi, width=2)
    d.line([(cx + 13, cy - 52), (cx + 13, cy + 14)], fill=lo, width=2)
    d.rectangle([cx - 44, cy + 16, cx + 44, cy + 26], fill=hi)
    d.rectangle([cx - 44, cy + 22, cx + 44, cy + 26], fill=f)
    d.rectangle([cx - 7, cy + 28, cx + 7, cy + 58], fill=lo)
    for k in range(4):
        d.line([cx - 7, cy + 32 + k * 7, cx + 7, cy + 36 + k * 7], fill=cut)
    d.ellipse([cx - 11, cy + 58, cx + 11, cy + 78], fill=f, outline=hi)

ITEMS = {'warrior': helm, 'mage': hat, 'assassin': dagger}

def background(kind):
    rng = random.Random({'warrior': 11, 'mage': 23, 'assassin': 37}[kind])
    im = Image.new('RGBA', (W, H), BASE + (255,))
    px = im.load()
    for y in range(H):
        for x in range(W):
            vx = (x - W / 2) / (W / 2); vy = (y - H / 2) / (H / 2)
            k = -int(round(7 * min(1, (vx * vx * 0.8 + vy * vy) ** 1.4))) + rng.randint(-1, 2)
            if rng.random() < 0.004:
                k += 5
            px[x, y] = tuple(max(0, c + k) for c in BASE) + (255,)
    d = ImageDraw.Draw(im)
    draw_seal(d, kind, rng)
    # разделители путей — точечные столбцы
    for x in (190, 370):
        for y in range(24, 336, 4):
            d.point((x, y), fill=lift(8))
        d.polygon([(x, 18), (x + 3, 21), (x, 24), (x - 3, 21)], fill=lift(14))
    # шапки путей: черта с ромбом
    for cx in PATHS:
        d.line([cx - 74, 54, cx + 74, 54], fill=lift(16))
        d.line([cx - 60, 56, cx + 60, 56], fill=lift(6))
        d.polygon([(cx, 50), (cx + 4, 54), (cx, 58), (cx - 4, 54)], fill=lift(26))
        for sx in (-1, 1):
            d.point((cx + sx * 76, 54), fill=lift(16))
    # ствол и корни (UI рисует поверх пунктир от корня к входам путей)
    trunk = lift(7)
    d.rectangle([PATHS[0], 355, PATHS[2], 357], fill=trunk)
    for cx in PATHS:
        d.rectangle([cx - 1, 338, cx + 1, 357], fill=trunk)
    for i in range(7):
        x0 = 280 + rng.randint(-6, 6)
        pts = [(x0, 360)]
        x, y = x0, 360
        for _ in range(4):
            x += rng.randint(-14, 14); y += rng.randint(2, 4)
            pts.append((x, y))
        d.line(pts, fill=lift(6))
    # рамка: тёмный край, двойная линия, уголки
    d.rectangle([0, 0, W - 1, H - 1], outline=(8, 7, 6))
    d.rectangle([1, 1, W - 2, H - 2], outline=(11, 9, 8))
    d.rectangle([3, 3, W - 4, H - 4], outline=lift(30))
    d.rectangle([6, 6, W - 7, H - 7], outline=lift(12))
    for (x, y, sx, sy) in ((3, 3, 1, 1), (W - 4, 3, -1, 1), (3, H - 4, 1, -1), (W - 4, H - 4, -1, -1)):
        d.line([x, y, x + sx * 18, y], fill=lift(56), width=1)
        d.line([x, y + sy, x + sx * 12, y + sy], fill=lift(44))
        d.line([x, y, x, y + sy * 18], fill=lift(56))
        d.line([x + sx, y, x + sx, y + sy * 12], fill=lift(44))
        ox, oy = x + sx * 8, y + sy * 8
        d.polygon([(ox, oy - 3), (ox + 3, oy), (ox, oy + 3), (ox - 3, oy)], fill=lift(40))
    # ромбы посередине сторон
    for (x, y) in ((W // 2, 3), (W // 2, H - 4), (3, H // 2), (W - 4, H // 2)):
        d.polygon([(x, y - 3), (x + 3, y), (x, y + 3), (x - 3, y)], fill=lift(40))
    return im

for kind in ('warrior', 'mage', 'assassin'):
    background(kind).save(os.path.join(OUT, f'talent_bg_{kind}.png'))
    print('bg', kind, (W, H))
