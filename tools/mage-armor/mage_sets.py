"""Пять комплектов мага (Хронисты — «читают память как книги»): шляпа (helm) + накидка (armor) с плащом.
Под накидкой виден основной облик героя (BODY): ноги, кисти, большая часть рук."""
import math
import numpy as np
import magekit as K
from magekit import Piece, V, H, cen
import mage_parts as M

MEMORY = '!#6FE3FF'
BODY = {'cloth': '#5A5048', 'leather': '#4A3426', 'skin': '#B8A58E'}   # основной облик героя (как у странника)

COMMON = {
    'shadow': ['#120E10', '#1A1418', '#221A1E', '#2A2024'],
    'hair': ['#1E1816', '#2C2420', '#3C302A', '#4A3C34'],
    'leather': ['#2E2018', '#4A3426', '#6A4C36', '#8A6648'],
    'brass': ['#6E5420', '#A07C2E', '#D4AA48', '#F2D27A'],
    'silver': ['#4E5868', '#7C8698', '#AEB8C6', '#E4E8EE'],
    'gold': ['#6E4E10', '#A07418', '#D4A02C', '#F6D472'],
    'paper': ['#9C8E6E', '#C8B990', '#E6DAB4', '#FBF3D8'],
    'red': ['#4E1A16', '#7E2A24', '#A83C32', '#CC5A4C'],
    'rope': ['#5E4E32', '#86724A', '#AA9466', '#C8B486'],
}


def ramps(**kw):
    r = dict(COMMON); r.update(kw); return r


def piece(name, part, slot):
    return Piece(name, part, slot)


def finish(pieces, R, contrast=1.0):
    for p in pieces:
        p.shade(R, contrast=contrast)
    return pieces


# ---------- роспись

def stars(p, R, color, n=10, seed=1, region=None, big=0.35, glow=None, glow_share=0.0):
    """Звёзды-крестики на внешней поверхности (по нормалям), region(x,y,z) → bool."""
    cells = [k for k in p.c if not p.c[k].startswith('!')]
    occ = p.c
    rnd = [H(seed, *k) for k in cells]
    chosen = [k for k, r in zip(cells, rnd) if r < n / max(1, len(cells)) * 3]
    placed = 0
    for (i, j, k) in chosen:
        x, y, z = cen(i), cen(j), cen(k)
        if region and not region(x, y, z):
            continue
        nb = [d for d in ((1, 0, 0), (-1, 0, 0), (0, 0, 1), (0, 0, -1)) if (i + d[0], j, k + d[2]) not in occ]
        if not nb or (i, j + 1, k) not in occ or (i, j - 1, k) not in occ:
            continue
        d = nb[0]
        col = glow if glow and H(seed + 9, i, j, k) < glow_share else color
        occ[(i, j, k)] = col
        if H(seed + 3, i, j, k) < big:
            u = (0, 0, 1) if d[0] else (1, 0, 0)
            for s in (-1, 1):
                for key in ((i + u[0] * s, j, k + u[2] * s), (i, j + s, k)):
                    if key in occ and not occ[key].startswith('!'):
                        occ[key] = col if col.startswith('!') else R[color_ramp(R, color)][2]
        placed += 1
        if placed >= n:
            break


def color_ramp(R, hexc):
    for name, ramp in R.items():
        if hexc in ramp:
            return name
    return 'silver'


def rim(p, color, test):
    """Кант по краю: ячейки, у которых открыт верх или низ и есть открытая боковая сторона, если test(x,y,z,m)."""
    occ = p.c
    for (i, j, k), c in list(occ.items()):
        if c.startswith('!'):
            continue
        if not test(cen(i), cen(j), cen(k)):
            continue
        side = any((i + d[0], j, k + d[1]) not in occ for d in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if side:
            occ[(i, j, k)] = color


def runes(p, glow, test, density=0.45, seed=4, normals=((0, 0, -1), (0, 0, 1), (1, 0, 0), (-1, 0, 0))):
    """Светящиеся руны: прерывистые «знаки» на открытых гранях там, где test(x, y, z)."""
    occ = p.c
    for (i, j, k), c in list(occ.items()):
        if c.startswith('!') or not test(cen(i), cen(j), cen(k)):
            continue
        if not any((i + d[0], j + d[1], k + d[2]) not in occ for d in normals):
            continue
        g = (i * 7 + k * 13 + j * 3) % 5
        if H(seed, i // 2, j, k // 2) < density and g != 0:
            occ[(i, j, k)] = glow


# =====================================================================
# 1. ПОСЛУШНИКА (обычный, стартовый)
# =====================================================================
def novice():
    R = ramps(felt=['#3A302A', '#584A3E', '#776552', '#94816A'], brim=['#342A24', '#524438', '#716050', '#8C7A64'],
              band=COMMON['leather'], mantle=['#2A323E', '#3F4C5A', '#586878', '#748696'],
              trim=['#7E7460', '#A89C80', '#CBC0A2', '#E6DDC2'], hood=['#262E3A', '#3A4654', '#526272', '#6C7E8E'],
              wrap=['#6E6450', '#968A70', '#B8AC90', '#D4CAAE'], cape=['#283040', '#3C4858', '#546476', '#6E8092'])
    hat = piece('Hat', 'Head', 'helm')
    M.brim(hat, 1.12, 0.30, droop=0.13, wave=0.045, waves=5, phase=0.7, tilt=0.05, mat='brim')
    M.crown(hat, 0.30, 0.52, 0.72, 0.5, bend=(0.02, 0.1), mat='felt')
    M.tip(hat, [(0.02, 0.8, 0.1), (0.06, 1.22, 0.18), (0.3, 1.42, 0.52), (0.52, 1.18, 0.86)], 0.5, 0.08, mat='felt')
    M.band(hat, 0.28, 0.44, 'band')
    M.face(hat)
    finish([hat], R)
    # латка на тулье и пряжка на ленте
    for (i, j, k), c in list(hat.c.items()):
        x, y, z = cen(i), cen(j), cen(k)
        if 0.52 < y < 0.84 and x > 0.5 and -0.3 < z < 0.1 and (i + 1, j, k) not in hat.c:
            hat.c[(i, j, k)] = R['wrap'][2] if (j + k) % 3 else R['band'][0]
        if 0.3 < y < 0.43 and -0.05 < x < 0.32 and z < -0.55 and (i, j, k - 1) not in hat.c:
            hat.c[(i, j, k)] = R['brass'][2] if (i + j) % 2 == 0 or abs(x - 0.13) > 0.1 else R['band'][0]
    rim(hat, R['brim'][3], lambda x, y, z: math.hypot(x, z) > 1.0 and y < 0.4)

    man = piece('Mantle', 'UpperTorso', 'armor')
    M.mantle(man, front=0.6, back=0.62, side=0.3, vpoint=0.1, mat='mantle')
    M.hood(man, y=0.72, z=0.66, rx=0.66, ry=0.32, rz=0.27, mat='hood')
    M.outline_bottom(man, 'trim', 'mantle')
    M.clasp(man, 0.52, mat='rope', w=2)
    finish([man], R)
    sh = []
    for side in ('Right', 'Left'):
        d = piece('Shoulder' + side[0], side + 'UpperArm', 'armor')
        M.drape(d, side, L=0.4, mat='mantle', trim='trim')
        sh.append(d)
        c = piece('Wrap' + side[0], side + 'LowerArm', 'armor')
        M.cuff(c, y0=-0.5, y1=-0.22, r0=0.6, r1=0.62, mat='wrap', bell=False)
        c.recolor(lambda x, y, z, m: 'wrap@-0.5' if m == 'wrap' and round(y / V) % 2 == 0 else None)
        sh.append(c)
    finish(sh, R)
    belt = piece('Belt', 'LowerTorso', 'armor')
    M.sash(belt, y0=-0.08, y1=0.1, mat='rope', knot=(-0.42, 'rope@0.3'), tails=[(-0.5, 0.34, 0.11, 'rope'), (-0.34, 0.26, 0.11, 'rope')])
    M.pouch(belt, 1.12, -0.12, 0.05, mat='leather', button='brass')
    # свиток за поясом сзади
    belt.fill((-0.6, -0.05, 0.6), (0.2, 0.12, 0.78), lambda x, y, z: (y - 0.03) ** 2 + (z - 0.69) ** 2 <= 0.075 ** 2 * 1.6, 'paper')
    belt.recolor(lambda x, y, z, m: 'red' if m == 'paper' and abs(x + 0.2) < 0.07 else None)
    finish([belt], R)
    cp = M.cape('novice', y_top=0.7, y_bot=-0.5, segs=2, w_top=0.84, w_bot=0.96, z0=0.68, fold=0.05, folds=6, hem='round', mat='cape')
    M.outline_bottom(cp, 'trim', 'cape')
    finish([cp], R)
    return dict(id='novice', rarity='common', body=BODY, pieces=[hat, man] + sh + [belt] + M.split_cape(cp))


# =====================================================================
# 2. ЧТЕЦА (обычный)
# =====================================================================
def reader():
    R = ramps(crown=['#18302E', '#264A46', '#356660', '#4C847C'], brim=['#162A28', '#22423E', '#305C56', '#467A72'],
              band=COMMON['red'], feather=['#8A8A8E', '#B6B6BA', '#D8D8DC', '#F2F2F4'], vane=['#3A3A40', '#55555C', '#6E6E76', '#8A8A92'],
              scarf=['#6A4E1C', '#946E28', '#BC9238', '#DDB65A'], stripe=['#1E3A36', '#2C524C', '#3C6C64', '#548A80'],
              mantle=['#1A2E2C', '#284644', '#38605C', '#4E7C76'], cover=['#3A1614', '#5C2420', '#7E3630', '#A04A40'],
              strap=COMMON['leather'], cape=['#182C2A', '#264240', '#365C58', '#4A7872'])
    hat = piece('Hat', 'Head', 'helm')
    M.brim(hat, 1.04, 0.32, droop=0.04, wave=0.02, waves=3, mat='brim')
    M.crown(hat, 0.32, 0.92, 0.7, 0.17, bend=(0.0, 0.06), w0=4.5, mat='crown')
    M.tip(hat, [(0.0, 1.2, 0.06), (0.0, 1.45, 0.1), (0.03, 1.62, 0.2), (0.08, 1.72, 0.36)], 0.17, 0.05, mat='crown')
    M.band(hat, 0.3, 0.44, 'band')
    # закладка-ленточка свисает сзади
    hat.fill((0.25, -0.2, 0.68), (0.43, 0.34, 0.82), lambda x, y, z: True if not (y < -0.1 and abs(x - 0.34) < 0.05) else False, 'band')
    # перо за лентой
    M.tip(hat, [(-0.7, 0.38, 0.05), (-0.78, 0.7, 0.18), (-0.86, 0.98, 0.32), (-0.9, 1.22, 0.5)], 0.075, 0.03, mat='feather')
    hat.recolor(lambda x, y, z, m: 'vane' if m == 'feather' and abs(z - (0.05 + (y - 0.38) * 0.52)) < 0.05 and y > 0.45 else None)
    M.face(hat)
    finish([hat], R)
    rim(hat, R['brim'][3], lambda x, y, z: math.hypot(x, z) > 0.95 and y < 0.42)

    man = piece('Mantle', 'UpperTorso', 'armor')
    M.mantle(man, front=0.4, back=0.52, side=0.26, scallop=0.05, scallops=5, mat='mantle')
    M.collar(man, h=0.22, ri=0.38, ro=0.64, open_front=0.0, flare=0.04, mat='scarf')
    # концы шарфа на груди слева
    man.fill((-0.62, -0.42, -0.82), (-0.18, 0.86, -0.5), lambda x, y, z: abs(x + 0.4 + 0.06 * (0.86 - y)) < 0.13 and z < -0.54 + 0.0 and z > -0.8 and y > -0.38 + 0.05 * (x + 0.4), 'scarf')
    man.recolor(lambda x, y, z, m: 'stripe' if m == 'scarf' and (round(y / V) % 4 == 0) else None)
    man.recolor(lambda x, y, z, m: 'stripe' if m == 'scarf' and y < -0.3 else None)
    # ремень сумки через грудь (правое плечо → левый бок), спереди и сзади
    for zf in (-1, 1):
        man.fill((-1.2, -0.85, -0.8), (1.2, 0.95, 0.8),
                 lambda x, y, z, zf=zf: abs((y - 0.75) + (x - 0.8) * 0.9) < 0.1 and abs(z * zf - (M.TZ + 0.08)) < 0.08 and abs(x) < M.TX + 0.05 and y > -0.82, 'strap')
    M.clasp(man, 0.12, mat='brass', w=2, z=-(M.TZ + 0.24))
    finish([man], R)
    sh = []
    for side in ('Right', 'Left'):
        d = piece('Shoulder' + side[0], side + 'UpperArm', 'armor')
        M.drape(d, side, L=0.3, scallop=0.04, mat='mantle')
        M.outline_bottom(d, 'scarf', 'mantle')
        sh.append(d)
        c = piece('Cuff' + side[0], side + 'LowerArm', 'armor')
        M.cuff(c, y0=-0.5, y1=-0.2, r0=0.6, r1=0.68, mat='mantle', trim='scarf')
        sh.append(c)
    finish(sh, R)
    belt = piece('Belt', 'LowerTorso', 'armor')
    M.sash(belt, y0=-0.12, y1=0.08, mat='strap')
    belt.recolor(lambda x, y, z, m: 'brass' if m == 'strap' and abs(x - 0.0) < 0.14 and z < -0.5 else None)
    # сумка-книга на левом боку и книга справа
    M.book(belt, -1.16, -0.26, 0.05, w=0.5, h=0.5, d=0.22, cover='cover', pages='paper', corner='brass')
    M.book(belt, 1.14, -0.2, -0.02, w=0.38, h=0.42, d=0.16, cover='stripe', pages='paper', corner='brass')
    finish([belt], R)
    cp = M.cape('reader', y_top=0.74, y_bot=-0.95, segs=3, w_top=0.72, w_bot=0.8, z0=0.66, fold=0.04, folds=5, hem='swallow', hem_depth=0.32, mat='cape')
    M.outline_bottom(cp, 'scarf', 'cape')
    finish([cp], R)
    return dict(id='reader', rarity='common', body=BODY, pieces=[hat, man] + sh + [belt] + M.split_cape(cp))


# =====================================================================
# 3. ХРОНИСТА (редкий)
# =====================================================================
def chronicler():
    R = ramps(crown=['#121A3E', '#1C2A60', '#2A3E86', '#4058AC'], brim=['#10183A', '#1A2758', '#273A7C', '#3A529E'],
              band=COMMON['silver'], mantle=['#141E44', '#1F2E66', '#2E4288', '#4660AE'],
              collar=['#121A3E', '#1C2A60', '#2A3E86', '#4058AC'], lining=['#7C7490', '#A49CBA', '#C8C2DA', '#E6E2F2'],
              cape=['#131C42', '#1E2C62', '#2C4084', '#4258A8'], cover=['#141E44', '#24366E', '#34509A', '#4A6CC0'])
    hat = piece('Hat', 'Head', 'helm')
    M.brim(hat, 1.2, 0.30, droop=0.1, wave=0.035, waves=4, phase=1.2, mat='brim')
    M.crown(hat, 0.30, 0.68, 0.72, 0.32, bend=(0.04, 0.14), pinch=0.03, mat='crown')
    M.tip(hat, [(0.04, 0.96, 0.14), (0.06, 1.3, 0.2), (0.22, 1.6, 0.4), (0.48, 1.66, 0.7)], 0.32, 0.05, mat='crown', curl=0.8)
    M.band(hat, 0.28, 0.42, 'band')
    M.face(hat)
    finish([hat], R)
    runes(hat, MEMORY, lambda x, y, z: 0.31 < y < 0.4, density=0.5, seed=11)
    stars(hat, R, R['band'][3], n=9, seed=3, region=lambda x, y, z: y > 0.5, glow=MEMORY, glow_share=0.25)
    rim(hat, R['band'][2], lambda x, y, z: math.hypot(x, z) > 1.06 and y < 0.4)

    man = piece('Mantle', 'UpperTorso', 'armor')
    M.mantle(man, front=0.66, back=0.7, side=0.34, scallop=0.07, scallops=6, mat='mantle')
    M.collar(man, h=0.38, ri=0.38, ro=0.6, open_front=0.22, flare=0.14, mat='collar')
    M.outline_bottom(man, 'band', 'mantle')
    man.recolor(lambda x, y, z, m: 'lining' if m == 'collar' and z < -0.1 and y > M.TY + 0.05 else None)
    M.clasp(man, 0.5, mat='band', w=3, glow=MEMORY)
    finish([man], R)
    rim(man, R['band'][2], lambda x, y, z: y > M.TY + 0.3)
    stars(man, R, R['band'][3], n=5, seed=8, region=lambda x, y, z: y < 0.5 and z > 0)
    sh = []
    for side in ('Right', 'Left'):
        d = piece('Shoulder' + side[0], side + 'UpperArm', 'armor')
        M.drape(d, side, L=0.48, scallop=0.05, mat='mantle', trim='band')
        sh.append(d)
        c = piece('Cuff' + side[0], side + 'LowerArm', 'armor')
        M.cuff(c, y0=-0.52, y1=-0.12, r0=0.6, r1=0.76, mat='mantle', trim='band')
        sh.append(c)
    finish(sh, R)
    for c in sh:
        if c.name.startswith('Cuff'):
            runes(c, MEMORY, lambda x, y, z: -0.3 < y < -0.2, density=0.5, seed=21)
    belt = piece('Belt', 'LowerTorso', 'armor')
    M.sash(belt, y0=-0.12, y1=0.1, mat='leather')
    belt.recolor(lambda x, y, z, m: 'band' if m == 'leather' and abs(x) < 0.15 and z < -0.5 else None)
    # закладки-ленты свисают спереди справа, книга на цепочке слева
    for n, (tx, ln, col) in enumerate(((0.42, 0.42, 'paper'), (0.6, 0.34, 'red'), (0.76, 0.46, 'paper'))):
        belt.fill((tx - 0.07, -0.12 - ln, -0.8), (tx + 0.07, -0.12, -0.6), lambda x, y, z: z > -0.7 and z < -0.62, col)
        belt.cell(tx, -0.12 - ln + 0.03, -0.66, 'gold')
    M.book(belt, -1.14, -0.3, 0.0, w=0.44, h=0.48, d=0.2, cover='cover', pages='paper', corner='band', gem=MEMORY)
    belt.fill((-1.2, -0.08, -0.08), (-1.06, 0.1, 0.08), lambda x, y, z: (round(y / V) + round(z / V)) % 2 == 0, 'band')
    finish([belt], R)
    cp = M.cape('chronicler', y_top=0.76, y_bot=-2.1, segs=4, w_top=0.94, w_bot=1.16, z0=0.68, fold=0.07, folds=7, hem='point', hem_depth=0.34, mat='cape')
    M.outline_bottom(cp, 'band', 'cape', rows=1)
    finish([cp], R)
    stars(cp, R, R['band'][3], n=16, seed=5, region=lambda x, y, z: y < 0.3, glow=MEMORY, glow_share=0.3)
    # серебряный узор у подола: ряд ромбов
    for (i, j, k), c in list(cp.c.items()):
        x, y = cen(i), cen(j)
        yb = -2.1 + 0.34 * abs(x) / 1.16
        if 0.13 < y - yb < 0.4 and (i, j, k + 1) not in cp.c and (abs((i % 4) - 1.5) + abs(((j - round(yb / V)) % 3) - 1)) < 1.6:
            cp.c[(i, j, k)] = R['band'][2]
    return dict(id='chronicler', rarity='rare', body=BODY, pieces=[hat, man] + sh + [belt] + M.split_cape(cp))


# =====================================================================
# 4. ЗАБВЕНИЯ (эпический) — «мир их забыл»
# =====================================================================
VIOLET = '!#B48CFF'


def oblivion():
    R = ramps(crown=['#120E18', '#1E1828', '#2C2238', '#3E304E'], brim=['#100C16', '#1A1424', '#281E34', '#382A48'],
              band=['#1E1626', '#30243C', '#463454', '#5E486E'], veil=['#16121E', '#221A2C', '#30263C', '#42344E'],
              mantle=['#141018', '#211A28', '#30263A', '#42364E'], feather=['#0E0C12', '#1A161E', '#28222E', '#3A3242'],
              cloak=['#131018', '#1E1A26', '#2C2636', '#3C344A'], mist=['#3E3850', '#585070', '#787090', '#A09ABA'],
              chain=['#3A3A44', '#5A5A66', '#80808C', '#AEAEB8'])
    hat = piece('Hat', 'Head', 'helm')
    M.brim(hat, 1.3, 0.28, droop=0.22, wave=0.06, waves=6, phase=0.3, ragged=0.16, rough=0.08, seed=41, mat='brim')
    M.crown(hat, 0.28, 0.5, 0.72, 0.44, bend=(-0.08, 0.14), pinch=0.05, mat='crown')
    M.tip(hat, [(-0.08, 0.76, 0.14), (-0.14, 1.08, 0.24), (-0.34, 1.22, 0.62), (-0.44, 0.9, 0.98)], 0.44, 0.07, mat='crown')
    M.band(hat, 0.26, 0.4, 'band')
    # вуаль за полями
    hat.fill((-0.85, -0.62, 0.82), (0.85, 0.24, 1.0), lambda x, y, z: abs(z - (0.9 + 0.03 * math.sin(x * 9))) < 0.065 and y > -0.55 + 0.25 * H(43, round(x / V)) + 0.25 * abs(x), 'veil')
    M.face(hat, eyes=VIOLET)
    finish([hat], R)
    runes(hat, VIOLET, lambda x, y, z: 0.45 < y < 1.1 and (x * 3 + y * 5) % 1.0 < 0.18, density=0.7, seed=44)
    runes(hat, VIOLET, lambda x, y, z: 0.28 < y < 0.38, density=0.35, seed=45)

    man = piece('Mantle', 'UpperTorso', 'armor')
    M.mantle(man, front=0.74, back=0.76, side=0.38, ragged=0.28, seed=47, vpoint=0.1, mat='mantle')
    # ворот из тёмных перьев: зубчатый
    M.collar(man, h=0.34, ri=0.38, ro=0.66, open_front=0.2, flare=0.16, mat='feather')
    man.carve(lambda x, y, z: y > M.TY + 0.12 and H(48, round(math.atan2(z, x) * 7)) < 0.4 + (y - M.TY) * 1.6)
    M.clasp(man, 0.48, mat='chain', w=2, glow=VIOLET)
    finish([man], R)
    sh = []
    for side in ('Right', 'Left'):
        d = piece('Shoulder' + side[0], side + 'UpperArm', 'armor')
        M.drape(d, side, L=0.5, ragged=0.24, seed=49 if side == 'Right' else 50, mat='mantle')
        sh.append(d)
        c = piece('Wrap' + side[0], side + 'LowerArm', 'armor')
        M.cuff(c, y0=-0.52, y1=-0.08, r0=0.6, r1=0.64, mat='cloak', bell=False)
        c.carve(lambda x, y, z: y > -0.2 and H(51, round(x / V), round(z / V)) < 0.5)
        sh.append(c)
    finish(sh, R)
    for c in sh:
        if c.name.startswith('Wrap'):
            runes(c, VIOLET, lambda x, y, z: -0.4 < y < -0.3, density=0.6, seed=52)
    belt = piece('Belt', 'LowerTorso', 'armor')
    M.sash(belt, y0=-0.1, y1=0.08, mat='cloak', tails=[(0.36, 0.5, 0.16, 'cloak'), (0.56, 0.38, 0.12, 'mantle')])
    # фонарь забвения на левом боку: рамка из цепи, внутри фиолетовый огонь
    belt.fill((-1.32, -0.62, -0.16), (-1.02, -0.18, 0.16), K.box(-1.3, -1.04, -0.6, -0.2, -0.14, 0.14), 'chain')
    belt.carve(lambda x, y, z: -1.24 < x < -1.1 and -0.52 < y < -0.28)
    belt.fill((-1.24, -0.52, -0.08), (-1.1, -0.28, 0.08), lambda x, y, z: True, VIOLET)
    belt.fill((-1.2, -0.2, -0.04), (-1.12, 0.0, 0.04), lambda x, y, z: True, 'chain')
    finish([belt], R)
    def cloakmat(x, y, z):
        t = (y + 2.25) / 0.9       # 0 у подола … 1 на 0.9 выше
        if t < 1 and H(53, round(x / V), round(y / V)) > t:
            return 'mist'
        return 'cloak'
    cp = M.cape('oblivion', y_top=0.78, y_bot=-2.25, segs=4, w_top=0.96, w_bot=1.2, z0=0.7, fold=0.08, folds=8, hem='tattered', hem_depth=0.5,
                ragged=0.35, seed=54, mat='cloak', matfn=cloakmat)
    finish([cp], R)
    # «уходящие» искры: фиолетовые штрихи у подола
    runes(cp, VIOLET, lambda x, y, z: y < -1.3 and abs((x * 2.3) % 0.9 - 0.45) < 0.07, density=0.6, seed=55, normals=((0, 0, 1),))
    return dict(id='oblivion', rarity='epic', body=BODY, pieces=[hat, man] + sh + [belt] + M.split_cape(cp))


# =====================================================================
# 5. АРХИВАРИУСА (легендарный) — Главный хронист
# =====================================================================
def archivist():
    R = ramps(crown=['#8A7E68', '#B4A88E', '#D8CEB4', '#F4ECD8'], brim=['#827660', '#AC9F84', '#D2C6AA', '#EEE6CE'],
              band=COMMON['gold'], mantle=['#86795F', '#B0A385', '#D6CAAC', '#F2EAD2'], collar=['#86795F', '#B0A385', '#D6CAAC', '#F2EAD2'],
              crimson=['#3E1018', '#621A26', '#862636', '#AA3A4A'], cape=['#857860', '#AEA186', '#D3C7AB', '#EFE7CF'],
              ink=['#14202E', '#20344A', '#2E4A66', '#426888'])
    hat = piece('Hat', 'Head', 'helm')
    M.brim(hat, 1.16, 0.32, droop=0.06, wave=0.02, waves=6, mat='brim')
    M.crown(hat, 0.32, 1.08, 0.72, 0.24, bend=(0.0, -0.02), w0=5, pinch=0.02, mat='crown')
    M.tip(hat, [(0.0, 1.36, -0.02), (0.0, 1.5, -0.02), (0.0, 1.62, 0.0), (0.0, 1.72, 0.02)], 0.2, 0.12, mat='band')
    # камень памяти на вершине
    hat.fill((-0.2, 1.68, -0.2), (0.2, 2.02, 0.2), lambda x, y, z: x * x + (y - 1.85) ** 2 + z * z <= 0.14 ** 2 * 1.3, MEMORY)
    hat.fill((-0.3, 1.6, -0.3), (0.3, 1.72, 0.3), lambda x, y, z: abs(x) + abs(z) < 0.26, 'band')
    M.band(hat, 0.3, 0.48, 'band')
    hat.recolor(lambda x, y, z, m: 'crimson' if m.startswith('crown') and 0.48 < y < 0.56 else None)
    # раскрытая книга на тулье спереди
    hat.fill((-0.34, 0.6, -0.86), (0.34, 0.96, -0.6), lambda x, y, z: z < -0.62 - 0.12 * (1 - abs(x) / 0.34) * 0 and abs(x) <= 0.32 and z > -0.84 and y < 0.94 - 0.08 * abs(x) / 0.32, 'paper')
    hat.recolor(lambda x, y, z, m: 'band' if m == 'paper' and (abs(x) > 0.24 or y < 0.66 or y > 0.88 or abs(x) < 0.04) else None)
    # ленты-закладки сзади
    for tx, col in ((-0.2, 'crimson'), (0.12, 'ink')):
        hat.fill((tx - 0.07, -0.35, 0.66), (tx + 0.07, 0.34, 0.84), lambda x, y, z, tx=tx: y > -0.3 + 0.25 * (tx > 0), col)
    M.face(hat, beard=None)
    finish([hat], R)
    runes(hat, MEMORY, lambda x, y, z: 0.33 < y < 0.45, density=0.5, seed=61)
    # строки на страницах книги
    for (i, j, k), c in list(hat.c.items()):
        x, y, z = cen(i), cen(j), cen(k)
        if c in R['paper'] and z < -0.7 and 0.68 < y < 0.86 and j % 2 == 0 and 0.06 < abs(x) < 0.22:
            hat.c[(i, j, k)] = R['ink'][1]
    rim(hat, R['band'][2], lambda x, y, z: math.hypot(x, z) > 1.02 and y < 0.42)

    man = piece('Mantle', 'UpperTorso', 'armor')
    M.mantle(man, front=0.72, back=0.72, side=0.36, vpoint=0.14, scallop=0.04, scallops=8, mat='mantle')
    M.collar(man, h=0.44, ri=0.38, ro=0.6, open_front=0.24, flare=0.2, mat='collar')
    man.recolor(lambda x, y, z, m: 'crimson' if m == 'collar' and z < -0.05 and y > M.TY + 0.06 else None)
    M.outline_bottom(man, 'band', 'mantle', rows=2)
    M.clasp(man, 0.46, mat='band', w=3, glow=MEMORY)
    finish([man], R)
    rim(man, R['band'][2], lambda x, y, z: y > M.TY + 0.36)
    runes(man, MEMORY, lambda x, y, z: z > 0.5 and 0.05 < y < 0.25 and abs(x) < 0.7, density=0.4, seed=62, normals=((0, 0, 1),))
    sh = []
    for side in ('Right', 'Left'):
        sx = 1 if side == 'Right' else -1
        d = piece('Shoulder' + side[0], side + 'UpperArm', 'armor')
        M.drape(d, side, L=0.36, mat='mantle', trim='band')
        # наплечник-переплёт: книга, лежащая на плече (обложка, торец страниц, золотые уголки)
        d.fill((-0.9, 0.56, -0.72), (0.9, 0.86, 0.72),
               lambda x, y, z, sx=sx: -0.2 <= x * sx <= 0.72 and abs(z) <= 0.68 and 0.6 <= y <= 0.82 - 0.1 * max(0, x * sx - 0.3), 'crimson')
        d.recolor(lambda x, y, z, m, sx=sx: 'paper' if m == 'crimson' and 0.66 < y < 0.76 and (x * sx > 0.6 or abs(z) > 0.6) else None)
        d.recolor(lambda x, y, z, m, sx=sx: 'band' if m == 'crimson' and (abs(z) > 0.52 and x * sx > 0.5) else None)
        sh.append(d)
        c = piece('Cuff' + side[0], side + 'LowerArm', 'armor')
        M.cuff(c, y0=-0.52, y1=-0.1, r0=0.6, r1=0.78, mat='mantle', trim='band')
        sh.append(c)
    finish(sh, R)
    for c in sh:
        if c.name.startswith('Cuff'):
            runes(c, MEMORY, lambda x, y, z: -0.28 < y < -0.18, density=0.55, seed=63)
        else:
            runes(c, MEMORY, lambda x, y, z: y > 0.76, density=0.25, seed=64, normals=((0, 1, 0),))
    belt = piece('Belt', 'LowerTorso', 'armor')
    M.sash(belt, y0=-0.14, y1=0.1, mat='crimson', tails=[(-0.42, 0.44, 0.16, 'crimson'), (-0.24, 0.36, 0.12, 'band')])
    belt.recolor(lambda x, y, z, m: 'band' if m == 'crimson' and (y > 0.05 or y < -0.1) and y > -0.15 else None)
    M.book(belt, 1.18, -0.36, 0.0, w=0.48, h=0.56, d=0.22, cover='crimson', pages='paper', corner='band', gem=MEMORY)
    # золотая цепь от пояса к книге
    for n in range(4):
        belt.cell(1.12 + 0.02 * n, 0.0 - 0.07 * n, -0.2 + 0.05 * (n % 2), 'band')
    # тубус со свитками сзади слева
    belt.fill((-0.9, -0.5, 0.56), (-0.5, 0.3, 0.9), lambda x, y, z: (x + 0.7) ** 2 + (z - 0.73) ** 2 <= 0.13 ** 2 and -0.45 < y < 0.25, 'ink')
    belt.recolor(lambda x, y, z, m: 'band' if m == 'ink' and (y > 0.17 or y < -0.37) else None)
    belt.fill((-0.86, 0.25, 0.6), (-0.54, 0.42, 0.86), lambda x, y, z: (x + 0.7) ** 2 + (z - 0.73) ** 2 <= 0.09 ** 2, 'paper')
    finish([belt], R)
    cp = M.cape('archivist', y_top=0.78, y_bot=-2.25, segs=4, w_top=0.96, w_bot=1.22, z0=0.7, fold=0.07, folds=7, hem='point', hem_depth=0.4, mat='cape')
    M.outline_bottom(cp, 'band', 'cape', rows=2)
    finish([cp], R)
    # колонка рун по центру и золотые «строки страниц» по бокам
    runes(cp, MEMORY, lambda x, y, z: abs(x) < 0.1 and -1.6 < y < 0.4, density=0.75, seed=65, normals=((0, 0, 1),))
    for (i, j, k), c in list(cp.c.items()):
        x, y = cen(i), cen(j)
        if (i, j, k + 1) in cp.c or c.startswith('!'):
            continue
        if 0.3 < abs(x) < 0.95 and -1.7 < y < 0.2 and j % 5 == 0 and H(66, i, j) < 0.7:
            cp.c[(i, j, k)] = R['band'][1]
        if abs(abs(x) - 0.2) < 0.07 and -1.7 < y < 0.4:
            cp.c[(i, j, k)] = R['band'][2]
    return dict(id='archivist', rarity='legendary', body=BODY, pieces=[hat, man] + sh + [belt] + M.split_cape(cp))


HAT_LIFT = 2  # вокселей: поля выше линии глаз


def build_all():
    sets = [novice(), reader(), chronicler(), oblivion(), archivist()]
    for st in sets:
        for p in st['pieces']:
            if p.slot == 'helm' and p.face:
                p.lift(HAT_LIFT)
    return sets
