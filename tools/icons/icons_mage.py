# Пиксельные иконки 19 заклинаний посохов (08.11.2026): 20x20, контур #24160F, атлас 5x4 (112x90).
# Тот же стиль, что icons345.py. Выход: tools/icons/mage_spells_atlas.png, tools/icons/mage_spells_preview.png,
# числа клеток печатаются в формате Config/AbilityIconsMage.lua.
#   python3 tools/icons/icons_mage.py
from PIL import Image, ImageDraw, ImageFont
import math

OUT = (36, 22, 15, 255)
P = {
 'bone': (248, 240, 222), 'grey': (160, 150, 140), 'dgrey': (98, 92, 88), 'steel': (196, 204, 212),
 'dsteel': (120, 128, 140), 'wood': (150, 100, 56), 'dwood': (104, 66, 36), 'red': (240, 90, 80),
 'dred': (160, 40, 36), 'gold': (255, 204, 84), 'orange': (255, 140, 40), 'yellow': (255, 236, 120),
 'mem': (120, 232, 255), 'dmem': (60, 150, 200), 'ink': (64, 54, 118), 'ink2': (112, 98, 184),
 'parch': (238, 222, 182), 'dparch': (196, 168, 120), 'green': (120, 220, 110), 'dgreen': (60, 130, 60),
 'lime': (200, 224, 74), 'pink': (255, 143, 208), 'dpink': (200, 80, 150), 'spirit': (111, 255, 208),
 'dspirit': (47, 168, 138), 'moon': (168, 200, 255), 'dmoon': (90, 120, 200), 'arcane': (190, 140, 255),
 'darcane': (120, 80, 200), 'white': (255, 255, 255),
}


def C(n):
    return P[n] + (255,)


def new():
    im = Image.new('RGBA', (20, 20), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def px(d, pts, col):
    for x, y in pts:
        d.point((x, y), fill=C(col))


def outline(im):
    a = im.load()
    out = im.copy(); o = out.load()
    for y in range(20):
        for x in range(20):
            if a[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < 20 and 0 <= ny < 20 and a[nx, ny][3] > 0 and a[nx, ny][:3] != OUT[:3]:
                        o[x, y] = OUT; break
    return out


def ring(d, cx, cy, r, col, w=1):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=C(col), width=w)


# --- Этаж 1 ---
def mage_ward():
    im, d = new()
    ring(d, 9, 10, 8, 'arcane', 2)
    for a in range(0, 360, 60):
        x = 9 + round(math.cos(math.radians(a)) * 8); y = 10 + round(math.sin(math.radians(a)) * 8)
        px(d, [(x, y)], 'white')
    d.polygon([(6, 6), (12, 6), (12, 11), (9, 15), (6, 11)], fill=C('steel'))
    d.polygon([(8, 7), (10, 7), (10, 11), (9, 13), (8, 11)], fill=C('arcane'))
    return im


def mage_signal():
    im, d = new()
    d.rectangle([7, 11, 11, 18], fill=C('dsteel')); d.rectangle([6, 10, 12, 11], fill=C('steel'))
    d.polygon([(9, 1), (13, 6), (12, 10), (6, 10), (5, 6)], fill=C('orange'))
    d.polygon([(9, 4), (11, 7), (10, 9), (8, 9), (7, 7)], fill=C('yellow'))
    px(d, [(3, 3), (15, 2), (16, 7)], 'orange')
    return im


def mage_gate():
    im, d = new()
    d.rectangle([2, 6, 5, 18], fill=C('steel')); d.rectangle([14, 6, 17, 18], fill=C('steel'))
    d.pieslice([2, 1, 17, 12], 180, 360, fill=C('steel'))
    d.rectangle([6, 7, 13, 18], fill=C('yellow'))
    d.pieslice([5, 3, 14, 11], 180, 360, fill=C('yellow'))
    d.line([(9, 6), (9, 18)], fill=C('white')); d.line([(7, 12), (12, 12)], fill=C('white'))
    return im


# --- Этаж 2 ---
def mage_lotus():
    im, d = new()
    d.ellipse([2, 14, 17, 18], fill=C('green'))
    d.polygon([(9, 2), (12, 9), (9, 14), (6, 9)], fill=C('pink'))
    d.polygon([(2, 7), (8, 11), (9, 14), (4, 13)], fill=C('dpink'))
    d.polygon([(17, 7), (11, 11), (9, 14), (15, 13)], fill=C('dpink'))
    d.line([(9, 4), (9, 11)], fill=C('white'))
    return im


def mage_spore():
    im, d = new()
    d.rectangle([4, 11, 6, 18], fill=C('bone')); d.pieslice([0, 6, 10, 15], 180, 360, fill=C('lime'))
    d.rectangle([12, 13, 13, 18], fill=C('bone')); d.pieslice([9, 10, 16, 16], 180, 360, fill=C('green'))
    px(d, [(2, 9), (6, 8), (12, 12)], 'yellow')
    for x, y in ((11, 3), (15, 5), (13, 7), (17, 2), (8, 2)):
        px(d, [(x, y)], 'lime')
    return im


def mage_thorn():
    im, d = new()
    ring(d, 9, 10, 8, 'dgreen', 1)
    ring(d, 9, 10, 5, 'green', 1)
    for a in range(0, 360, 45):
        r0, r1 = 3, 9
        x0 = 9 + math.cos(math.radians(a)) * r0; y0 = 10 + math.sin(math.radians(a)) * r0
        x1 = 9 + math.cos(math.radians(a)) * r1; y1 = 10 + math.sin(math.radians(a)) * r1
        d.line([(round(x0), round(y0)), (round(x1), round(y1))], fill=C('green'))
    d.ellipse([7, 8, 11, 12], fill=C('pink'))
    return im


# --- Этаж 3 ---
def mage_pack():
    im, d = new()
    d.polygon([(3, 2), (7, 6), (12, 6), (16, 2), (16, 10), (12, 16), (7, 16), (3, 10)], fill=C('spirit'))
    d.polygon([(7, 11), (12, 11), (11, 16), (8, 16)], fill=C('dspirit'))
    px(d, [(6, 9), (7, 9), (12, 9), (13, 9)], 'white')
    px(d, [(9, 13), (10, 13)], 'ink')
    px(d, [(2, 15), (17, 15), (1, 6)], 'spirit')
    return im


def mage_moon():
    im, d = new()
    d.ellipse([3, 1, 15, 13], fill=C('moon'))
    d.ellipse([7, 0, 18, 11], fill=(0, 0, 0, 0))
    for x in (5, 9, 13):
        d.line([(x, 13), (x - 2, 19)], fill=C('white'))
    px(d, [(16, 13), (2, 15)], 'moon')
    return im


def mage_net():
    im, d = new()
    for i in range(0, 18, 4):
        d.line([(1 + i, 6), (1 + i, 18)], fill=C('parch'))
    for j in range(6, 19, 4):
        d.line([(1, j), (17, j)], fill=C('parch'))
    d.line([(15, 0), (6, 13)], fill=C('wood'), width=2)
    d.polygon([(4, 12), (8, 12), (5, 17)], fill=C('gold'))
    return im


# --- Этаж 4 ---
def mage_firerain():
    im, d = new()
    for (x, y) in ((4, 2), (12, 5), (7, 10), (15, 12)):
        d.polygon([(x, y), (x + 3, y + 4), (x + 1, y + 6), (x - 1, y + 4)], fill=C('orange'))
        px(d, [(x, y + 3), (x + 1, y + 4)], 'yellow')
        d.line([(x - 1, y - 2), (x, y)], fill=C('red'))
    d.line([(1, 18), (18, 18)], fill=C('red'))
    return im


def mage_lightning():
    im, d = new()
    d.polygon([(11, 0), (5, 9), (9, 9), (6, 18), (14, 7), (10, 7), (13, 0)], fill=C('yellow'))
    d.line([(10, 2), (7, 8)], fill=C('white'))
    d.rectangle([13, 13, 18, 16], fill=C('dsteel')); d.line([(15, 16), (15, 19)], fill=C('wood'))
    return im


def mage_heart():
    im, d = new()
    d.polygon([(1, 18), (6, 14), (10, 15), (14, 11), (18, 9), (18, 11), (14, 13), (10, 17), (6, 16), (2, 19)], fill=C('orange'))
    for x, h in ((4, 8), (9, 11), (15, 7)):
        d.polygon([(x - 1, 16), (x + 2, 16), (x + 1, 16 - h), (x, 16 - h)], fill=C('red'))
        px(d, [(x, 16 - h + 1), (x + 1, 15 - h // 2)], 'yellow')
    return im


def mage_meteor():
    im, d = new()
    d.polygon([(1, 1), (10, 7), (8, 10)], fill=C('red'))
    d.polygon([(3, 1), (11, 8), (9, 9)], fill=C('orange'))
    d.ellipse([8, 7, 17, 16], fill=C('dgrey'))
    d.ellipse([10, 9, 14, 13], fill=C('orange'))
    px(d, [(11, 10)], 'yellow')
    d.line([(4, 18), (18, 18)], fill=C('orange'))
    return im


def mage_firstcast():
    im, d = new()
    for a in range(0, 360, 45):
        x = 9 + round(math.cos(math.radians(a)) * 9); y = 9 + round(math.sin(math.radians(a)) * 9)
        d.line([(9, 9), (x, y)], fill=C('orange'))
    d.polygon([(9, 3), (11, 7), (15, 9), (11, 11), (9, 15), (7, 11), (3, 9), (7, 7)], fill=C('yellow'))
    d.ellipse([7, 7, 11, 11], fill=C('white'))
    return im


# --- Этаж 5 ---
def mage_tome():
    im, d = new()
    d.polygon([(1, 9), (9, 7), (9, 18), (1, 17)], fill=C('parch'))
    d.polygon([(18, 9), (10, 7), (10, 18), (18, 17)], fill=C('parch'))
    d.line([(9, 7), (9, 18)], fill=C('dwood')); d.line([(10, 7), (10, 18)], fill=C('dwood'))
    for y in (11, 13, 15):
        d.line([(3, y), (7, y - 1)], fill=C('dparch')); d.line([(12, y - 1), (16, y)], fill=C('dparch'))
    for x, y in ((5, 2), (10, 1), (15, 3)):
        d.rectangle([x, y, x + 1, y + 1], fill=C('mem'))
    return im


def mage_clock():
    im, d = new()
    d.ellipse([1, 1, 18, 18], fill=C('mem')); d.ellipse([3, 3, 16, 16], fill=C('bone'))
    for a in range(0, 360, 90):
        x = 9 + round(math.cos(math.radians(a)) * 6); y = 9 + round(math.sin(math.radians(a)) * 6)
        px(d, [(x, y)], 'dmem')
    d.line([(9, 9), (9, 4)], fill=C('gold'), width=1); d.line([(9, 9), (13, 11)], fill=C('dwood'))
    d.polygon([(2, 4), (5, 1), (6, 5)], fill=C('dmem'))
    return im


def mage_fate():
    im, d = new()
    d.line([(0, 18), (19, 1)], fill=C('mem'), width=3)
    d.line([(0, 18), (19, 1)], fill=C('white'))
    d.ellipse([6, 6, 13, 13], fill=C('ink2'))
    d.ellipse([8, 8, 11, 11], fill=C('gold'))
    px(d, [(3, 4), (16, 15)], 'mem')
    return im


def mage_inkhole():
    im, d = new()
    d.ellipse([2, 2, 17, 17], fill=C('ink'))
    for r, col in ((6, 'ink2'), (3, 'darcane')):
        d.arc([9 - r, 9 - r, 10 + r, 10 + r], 200, 470, fill=C(col), width=2)
    d.ellipse([8, 8, 11, 11], fill=(20, 16, 40, 255))
    px(d, [(1, 9), (18, 12), (11, 0)], 'ink')
    return im


def mage_recall():
    im, d = new()
    for x, col in ((1, 'dmem'), (6, 'mem'), (11, 'white')):
        d.ellipse([x + 1, 2, x + 4, 5], fill=C(col))
        d.polygon([(x + 1, 8), (x + 4, 8), (x + 5, 10), (x + 5, 17), (x, 17), (x, 10)], fill=C(col))
    d.line([(17, 2), (17, 17)], fill=C('arcane'))
    px(d, [(16, 4), (18, 9)], 'arcane')
    return im


ORDER = [
    ('mage_ward', 'ward_circle', 'barrier'), ('mage_signal', 'signal_fire', 'candle'), ('mage_gate', 'light_gate', 'key'),
    ('mage_lotus', 'lotus_bloom', 'flask'), ('mage_spore', 'mycelium', 'dust'), ('mage_thorn', 'thorn_garden', 'split'),
    ('mage_pack', 'spirit_pack', 'soul'), ('mage_moon', 'hunters_moon', 'star'), ('mage_net', 'royal_hunt', 'trophy'),
    ('mage_firerain', 'fire_rain', 'dust'), ('mage_lightning', 'forged_lightning', 'hammer'), ('mage_heart', 'forge_heart', 'split'),
    ('mage_meteor', 'meteor', 'ingot'), ('mage_firstcast', 'first_cast', 'star'), ('mage_tome', 'open_tome', 'scroll'),
    ('mage_clock', 'time_stop', 'ring'), ('mage_fate', 'fate_line', 'quest'), ('mage_inkhole', 'ink_hole', 'whirl'),
    ('mage_recall', 'total_recall', 'soul'),
]

if __name__ == '__main__':
    COLS = 5
    atlas = Image.new('RGBA', (2 + COLS * 22, 2 + 4 * 22), (0, 0, 0, 0))
    rects = {}
    for i, (name, _, _) in enumerate(ORDER):
        im = outline(globals()[name]())
        x, y = 2 + (i % COLS) * 22, 2 + (i // COLS) * 22
        atlas.paste(im, (x, y))
        rects[name] = (x, y)
    atlas.save('tools/icons/mage_spells_atlas.png')
    S = 6
    pv = Image.new('RGBA', (COLS * (20 * S + 20) + 20, 4 * (20 * S + 40) + 20), (30, 22, 19, 255))
    dd = ImageDraw.Draw(pv)
    try:
        font = ImageFont.truetype('/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf', 13)
    except Exception:
        font = ImageFont.load_default()
    for i, (name, spell, _) in enumerate(ORDER):
        x, y = rects[name]
        tile = atlas.crop((x, y, x + 20, y + 20)).resize((20 * S, 20 * S), Image.NEAREST)
        cx, cy = 20 + (i % COLS) * (20 * S + 20), 20 + (i // COLS) * (20 * S + 40)
        dd.rectangle([cx - 4, cy - 4, cx + 20 * S + 3, cy + 20 * S + 3], fill=(52, 36, 24, 255))
        pv.alpha_composite(tile, (cx, cy))
        dd.text((cx, cy + 20 * S + 6), spell, fill=(248, 240, 222, 255), font=font)
    pv.save('tools/icons/mage_spells_preview.png')
    for name, _, _ in ORDER:
        x, y = rects[name]
        print('\t\t%s = { x = %d, y = %d, w = 20, h = 20 },' % (name, x, y))
