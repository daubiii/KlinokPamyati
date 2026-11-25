#!/usr/bin/env python3
# build_paper_atlas.py — бумажный атлас интерфейса персонажа из набора
# «Humble Gift — Paper UI System v1.1» (@Humblepixel).
#
#   python tools/paperui/build_paper_atlas.py "<путь к Humble Gift - Paper UI System v1.1>"
#
# Пишет:
#   assets/paper/paper_ui.png    — атлас 1024×1024 (бумага, ленты, кнопки, слоты,
#                                  полосы, предметы, портреты, печать, свои иконки)
#   assets/paper/paper_desk.png  — подложка-стол (Book Desk 4), 768×560
#   src/ReplicatedStorage/Shared/Config/PaperAtlas.lua — прямоугольники и 9-slice
#
# Лицензия набора разрешает коммерческое использование и правку, но не
# перераспространение самих исходников: в репозиторий кладём только
# собранные атласы для загрузки в Roblox.
import os, sys
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = sys.argv[1] if len(sys.argv) > 1 else '/data/inv/paperui/Humble Gift - Paper UI System v1.1'
SP = os.path.join(SRC, 'Sprites')
C = os.path.join(SP, 'Content')
PACK = os.path.join(SP, 'Paper UI Pack', 'Plain')
OUT = os.path.join(ROOT, 'assets', 'paper')
LUA = os.path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared', 'Config', 'PaperAtlas.lua')


def img(*parts):
    return Image.open(os.path.join(*parts)).convert('RGBA')


def row(ims):
    w = sum(i.width for i in ims); h = max(i.height for i in ims)
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0)); x = 0
    for i in ims:
        out.alpha_composite(i, (x, 0)); x += i.width
    return out


def grid3(tiles):  # 9 тайлов 32×32 → 96×96
    t = tiles[0].width
    out = Image.new('RGBA', (t * 3, t * 3), (0, 0, 0, 0))
    for k, tile in enumerate(tiles):
        out.alpha_composite(tile, ((k % 3) * t, (k // 3) * t))
    return out


pieces = {}   # name -> (Image, slice | None)


def add(name, im, slice_=None):
    pieces[name] = (im, slice_)


# ---------- бумага: 9-slice из тайлов 1 Paper ----------
P = os.path.join(PACK, '1 Paper')
paper = [img(P, f'{i}.png') for i in range(1, 54)]
front = grid3(paper[0:9])
back = grid3(paper[17:26])
ornate = front.copy()
# рамка с завитками: 11 TL, 12 T, 13 TR, 10 L, 14 R, 17 BL, 16 B, 15 BR
for tile, (gx, gy) in ((11, (0, 0)), (12, (1, 0)), (13, (2, 0)), (10, (0, 1)), (14, (2, 1)),
                       (17, (0, 2)), (16, (1, 2)), (15, (2, 2))):
    ornate.alpha_composite(paper[tile - 1], (gx * 32, gy * 32))
alt = front.copy()
# вторая рамка (28 TL, 29 T, 30 TR, 27 L, 31 R, 34 BL, 33 B, 32 BR)
for tile, (gx, gy) in ((28, (0, 0)), (29, (1, 0)), (30, (2, 0)), (27, (0, 1)), (31, (2, 1)),
                       (34, (0, 2)), (33, (1, 2)), (32, (2, 2))):
    alt.alpha_composite(paper[tile - 1], (gx * 32, gy * 32))
add('sheet', ornate, (32, 32, 32, 32))
add('sheetAlt', alt, (32, 32, 32, 32))
add('sheetPlain', front, (32, 32, 32, 32))
add('sheetBack', back, (32, 32, 32, 32))
add('pin', paper[52])

# ---------- ленты и закладки ----------
B = os.path.join(C, '10 Banners & Headers', 'Plain')
if not os.path.isdir(B):
    B = os.path.join(C, '10 Banners & Headers')
    B = os.path.join(B, sorted(os.listdir(B))[0]) if not os.path.exists(os.path.join(B, '1.png')) else B
ban = {i: img(B, f'{i}.png') for i in range(1, 21)}
add('ribbon', row([ban[6], ban[7], ban[8]]), (112, 0, 112, 0))
add('headerArc', ban[1])
add('headerWave', ban[2])
for n, i in (('bookmark', 11), ('bookmarkUp', 14), ('bookmarkTwin', 17), ('bookmarkLow', 20)):
    tag = Image.new('RGBA', (64, 128), (0, 0, 0, 0))
    tag.alpha_composite(ban[10], (0, 0)); tag.alpha_composite(ban[i], (0, 64))
    add(n, tag, (0, 16, 0, 64))

# ---------- кнопки ----------
BS = os.path.join(C, '4 Buttons', 'Sliced')
bs = {i: img(BS, f'{i}.png') for i in range(1, 34)}
add('btn', row([bs[10], bs[11], bs[12]]), (16, 4, 16, 6))
add('btnDown', row([bs[13], bs[14], bs[15]]), (16, 4, 16, 6))
add('btnRound', bs[3]); add('btnRoundDown', bs[4])
add('btnRoundBig', bs[8]); add('btnRoundBigDown', bs[9])
add('knob', bs[1]); add('knobDark', bs[2])
add('chevronL', bs[5]); add('chevronD', bs[6]); add('chevronS', bs[7])
for n, a in (('strip', 16), ('stripRed', 19), ('stripSoft', 22), ('stripSoftRed', 25), ('stripBack', 28), ('stripBackRed', 31)):
    add(n, row([bs[a], bs[a + 1], bs[a + 2]]), (32, 8, 32, 8))
# стрипы без кнопки-шарика: середина + конец (для строк без иконки)
add('stripPlain', row([bs[17], bs[17], bs[18]]), (32, 8, 32, 8))
add('stripPlainRed', row([bs[20], bs[20], bs[21]]), (32, 8, 32, 8))

# ---------- полосы ----------
PB = os.path.join(C, '3 Progress Bars')
pb = {i: img(PB, f'{i}.png') for i in range(1, 16)}
add('barHp', row([pb[1], pb[2], pb[3]]), (16, 3, 16, 3))
add('barXp', row([pb[4], pb[5], pb[6]]), (16, 3, 16, 3))
add('barFrame', row([pb[7], pb[8], pb[9]]), (16, 4, 16, 4))
add('barSeg', row([pb[10], pb[11], pb[13]]), (16, 4, 16, 4))

# ---------- держатели ----------
H = os.path.join(C, '5 Holders')
ho = {i: img(H, f'{i}.png') for i in range(1, 26)}
add('ring224', ho[1]); add('ring112', ho[2]); add('ring80', ho[3]); add('ring64', ho[23]); add('ring32', ho[24])
add('dot32', ho[4]); add('dot32b', ho[6])
add('square', ho[25], (10, 10, 10, 10)); add('squareB', ho[5], (10, 10, 10, 10))
add('plate', ho[12], (6, 6, 6, 6)); add('plateB', ho[13], (6, 6, 6, 6)); add('plateC', ho[14], (6, 6, 6, 6))
add('divider', ho[19], (24, 0, 24, 0)); add('dividerPlain', ho[20], (8, 0, 8, 0))
add('dot', ho[21]); add('dotRing', ho[22])
add('greenTick', ho[16])

# ---------- выделение ----------
HL = os.path.join(C, '6 Highlighter')
hl = {i: img(HL, f'{i}.png') for i in range(1, 9)}
for n, i in (('hlTL', 1), ('hlTR', 2), ('hlBR', 3), ('hlBL', 4), ('hlBox', 5), ('hlCross', 6), ('heart', 7), ('heartDark', 8)):
    add(n, hl[i])

# ---------- экипировка (пустые слоты и иконки) ----------
E = os.path.join(C, '8 Equipment')
eq = {i: img(E, f'{i}.png') for i in range(1, 19)}
names = ['helm', 'chest', 'legs', 'glove', 'belt', 'boots']
for k, n in enumerate(names):
    add('eqEmpty_' + n, eq[1 + k])
    add('eqIron_' + n, eq[7 + k])
    add('eqLeather_' + n, eq[13 + k])

# ---------- иконки, портреты, книги ----------
I = os.path.join(C, '2 Icons')
ic = {i: img(I, f'{i}.png') for i in range(1, 27)}
for n, i in (('icGear', 1), ('icMinus', 2), ('icPlus', 3), ('icSlash', 4), ('icCheckS', 5), ('icLockS', 6), ('icHomeS', 7),
             ('icCrossS', 8), ('icPlusS', 9), ('icCheck', 10), ('icCross', 11), ('icLock', 12), ('icHome', 13),
             ('icClose', 14), ('icPlusB', 15), ('hero1', 16), ('hero2', 17), ('npc1', 18), ('npc2', 19), ('npc3', 20),
             ('coins', 21), ('scroll', 22), ('book', 23), ('bookMark', 24), ('npc4', 25), ('npc5', 26)):
    add(n, ic[i])

# ---------- предметы ----------
IT = os.path.join(C, '1 Items')
it = {i: img(IT, f'{i}.png') for i in range(1, 28)}
small = {1: 'bookBlue', 2: 'egg', 3: 'fish', 4: 'candy', 5: 'bookRed', 6: 'log', 7: 'meat', 8: 'ingot', 9: 'goldOre',
         10: 'leaf', 11: 'bread', 12: 'feather', 13: 'star', 14: 'coinStack', 27: 'bookGreen'}
big = {15: 'feather', 16: 'log', 17: 'bookBlue', 18: 'egg', 19: 'fish', 20: 'candy', 21: 'bookRed', 22: 'meat',
       23: 'ingot', 24: 'goldOre', 25: 'leaf', 26: 'bread'}
for i, n in small.items():
    add('it_' + n, it[i])
for i, n in big.items():
    add('itL_' + n, it[i])

# ---------- печать ----------
ST = os.path.join(C, '9 Stamp', 'Stamp', 'Stamped')
for k in range(1, 21):
    add(f'stamp{k}', img(ST, f'{k}.png'))
add('stampIdle', img(C, '9 Stamp', 'Stamp', 'idle', '1.png'))
add('stampMark', img(C, '9 Stamp', 'Stamp Mark', '1.png'))

# ---------- свои иконки в стиле набора (16×16, обводка как у предметов) ----------
OUTL = (0, 48, 59, 255)


def sprite(draw_fn, shade=None):
    """draw_fn(px) красит пиксели {(x,y): rgba}; обводка — снаружи по 4 соседям."""
    px = {}
    draw_fn(px)
    out = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for (x, y), c in px.items():
        if 0 <= x < 16 and 0 <= y < 16:
            out.putpixel((x, y), c)
    for y in range(16):
        for x in range(16):
            if (x, y) in px:
                continue
            if any((x + dx, y + dy) in px and px[(x + dx, y + dy)] != OUTL for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.putpixel((x, y), OUTL)
    return out


def disc(cx, cy, r):
    return [(x, y) for y in range(16) for x in range(16) if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r]


def potion(light, mid, dark):
    def fn(px):
        glass = (214, 232, 236, 255); glassD = (150, 182, 196, 255)
        cork = (190, 128, 74, 255); corkD = (120, 72, 40, 255)
        body = disc(8, 10.5, 4.6)
        for p in body:
            x, y = p
            if y < 8:
                px[p] = glass
            elif x + y > 19:
                px[p] = dark
            elif y == 8:
                px[p] = light
            else:
                px[p] = mid
        for y in range(4, 7):
            for x in range(7, 9 + 0):
                px[(x, y)] = glass if x == 7 else glassD
        for x in range(6, 10):
            px[(x, 3)] = cork
            px[(x, 2)] = corkD if x in (6, 9) else cork
        px[(5, 10)] = (255, 255, 255, 255); px[(5, 11)] = (255, 255, 255, 255); px[(6, 9)] = (255, 255, 255, 255)
    return sprite(fn)


add('it_potionRed', potion((255, 150, 130, 255), (222, 58, 62, 255), (150, 28, 44, 255)))
add('it_potionBlue', potion((150, 230, 255, 255), (56, 150, 230, 255), (30, 78, 160, 255)))
add('it_potionGreen', potion((190, 250, 150, 255), (96, 196, 92, 255), (40, 116, 62, 255)))
add('it_potionGold', potion((255, 240, 160, 255), (250, 190, 50, 255), (190, 116, 22, 255)))

GOLD = (250, 196, 54, 255); GOLDD = (196, 120, 28, 255); GOLDL = (255, 240, 160, 255)
SIL = (176, 186, 206, 255); SILD = (108, 118, 146, 255); SILL = (236, 240, 248, 255)


def amulet(gem, gemL, metal=(GOLD, GOLDD, GOLDL)):
    def fn(px):
        m, md, ml = metal
        for t in range(0, 6):  # цепочка V
            px[(2 + t, 1 + t)] = md if t % 2 else m
            px[(13 - t, 1 + t)] = md if t % 2 else m
        for p in disc(8, 10.5, 4.2):
            x, y = p
            px[p] = md if x + y > 19 else m
        for p in disc(8, 10.5, 2.2):
            px[p] = gem
        px[(7, 9)] = gemL; px[(6, 8)] = ml; px[(5, 9)] = ml
    return sprite(fn)


def ring(gem, gemL, metal=(GOLD, GOLDD, GOLDL)):
    def fn(px):
        m, md, ml = metal
        outer = set(disc(8, 10, 5.2)); inner = set(disc(8, 10, 3.0))
        for p in outer - inner:
            x, y = p
            px[p] = md if x + y > 19 else m
        for p in disc(8, 3.6, 2.4):
            px[p] = gem
        px[(7, 2)] = gemL; px[(4, 8)] = ml; px[(4, 9)] = ml
    return sprite(fn)


CY = (120, 232, 255, 255); CYL = (220, 250, 255, 255); CYD = (40, 140, 200, 255)
RED = (236, 70, 74, 255); REDL = (255, 180, 170, 255)
GRN = (96, 210, 110, 255); GRNL = (210, 255, 200, 255)
PUR = (176, 106, 244, 255); PURL = (232, 210, 255, 255)
add('it_amulet', amulet(CY, CYL))
add('it_amuletRed', amulet(RED, REDL))
add('it_amuletSilver', amulet(GRN, GRNL, (SIL, SILD, SILL)))
add('it_ring', ring(CY, CYL))
add('it_ringRed', ring(RED, REDL))
add('it_ringSilver', ring(PUR, PURL, (SIL, SILD, SILL)))


def soul_fn(px):
    for p in disc(8, 10.5, 4.0):
        x, y = p
        px[p] = CYD if x + y > 19 else CY
    for y, (a, b) in enumerate(((8, 8), (7, 9), (7, 9), (6, 10), (6, 10), (5, 11)), start=1):
        for x in range(a, b + 1):
            px[(x, y + 0)] = CY
    for p in disc(8, 10.5, 1.8):
        px[p] = CYL
    px[(6, 5)] = CYL


add('it_soul', sprite(soul_fn))


def dust_fn(px):
    for (x, y) in ((4, 11), (6, 9), (8, 12), (10, 8), (11, 11), (7, 6), (9, 4), (5, 13), (12, 13)):
        px[(x, y)] = CY
        px[(x + 1, y)] = CYD
    for (x, y) in ((7, 6), (10, 8), (4, 11)):
        px[(x, y)] = CYL


add('it_dust', sprite(dust_fn))


def key_fn(px):
    for p in set(disc(5, 5, 3.4)) - set(disc(5, 5, 1.4)):
        px[p] = GOLD
    for t in range(0, 8):
        px[(7 + t, 7 + t)] = GOLD if t % 2 == 0 else GOLDD
        if t < 7:
            px[(8 + t, 7 + t)] = GOLDD
    px[(11, 13)] = GOLD; px[(12, 12)] = GOLD; px[(13, 11)] = GOLDD
    px[(3, 3)] = GOLDL


add('it_key', sprite(key_fn))


def sword_fn(px):
    blade = SIL; edge = SILL; dark = SILD
    for t in range(0, 9):
        px[(13 - t, 2 + t)] = edge
        px[(13 - t, 3 + t)] = blade
        px[(12 - t, 3 + t)] = dark if t > 0 else blade
    for t in range(-2, 3):
        px[(5 + t, 10 + t)] = GOLD
    px[(3, 12)] = (150, 94, 57, 255); px[(2, 13)] = (101, 60, 30, 255); px[(4, 11)] = (150, 94, 57, 255)


add('it_sword', sprite(sword_fn))

# ---------- упаковка ----------
order = sorted(pieces.items(), key=lambda kv: (-kv[1][0].height, -kv[1][0].width, kv[0]))
W = 1024
atlas = Image.new('RGBA', (W, W), (0, 0, 0, 0))
rects = {}
x = y = 0; shelf = 0; PAD = 2
for name, (im, sl) in order:
    if x + im.width + PAD > W:
        x = 0; y += shelf + PAD; shelf = 0
    if y + im.height > W:
        raise SystemExit(f'атлас переполнен на {name}')
    atlas.alpha_composite(im, (x, y))
    rects[name] = (x, y, im.width, im.height, sl)
    x += im.width + PAD; shelf = max(shelf, im.height)
used = y + shelf
os.makedirs(OUT, exist_ok=True)
atlas.save(os.path.join(OUT, 'paper_ui.png'))
desk = img(SP, 'Book Desk', '4.png')
desk.save(os.path.join(OUT, 'paper_desk.png'))

lines = ['--!nonstrict', '-- PaperAtlas (сгенерировано tools/paperui/build_paper_atlas.py — не править руками)',
         '-- Куски атласа assets/paper/paper_ui.png: x, y, w, h в пикселях атласа и поля 9-slice (l, t, r, b).',
         '-- Источник арта — Humble Gift «Paper UI System v1.1» (@Humblepixel).', '', 'return {',
         f'\tSize = {W},', '\tDesk = { w = 768, h = 560, slice = { 24, 24, 24, 40 } },', '\tPieces = {']
for name in sorted(rects):
    x0, y0, w, h, sl = rects[name]
    s = f', slice = {{ {sl[0]}, {sl[1]}, {sl[2]}, {sl[3]} }}' if sl else ''
    lines.append(f'\t\t{name} = {{ x = {x0}, y = {y0}, w = {w}, h = {h}{s} }},')
lines += ['\t},', '}', '']
with open(LUA, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
print(f'кусков: {len(rects)}, занято по высоте: {used}/{W}')
