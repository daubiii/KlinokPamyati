"""Посохи этажа 2 «Затопленные сады»: камыш, мох, плавник, тернии, лотос, грибы, посох Садовницы.
Неон — по стилю снаряда: water, poison, thorn, lotus, spore."""
import math
from staffs_common import *

MD, MG, ML = '#1F3A33', '#3F7A5C', '#9CC48A'
MS1, MS2, MS3 = '#2B4A32', '#4C8A4F', '#86BA6C'
MUD, MUD2 = '#3A2E22', '#54402C'
RW, RWL = '#8A9C7A', '#B7C8A5'
ST1, ST2, ST3 = '#2C4F52', '#3F7A7A', '#78B5B0'
FOAM = '#E6F4EE'
SW, SWL, SWH = '#6E8F86', '#9BC4B8', '#CFE8DF'
RS, RSL = '#B04A5A', '#D97A88'
LP1, LP2, LP3 = '#C24F9A', '#E27DBA', '#F6B8DA'                 # лотос
CAP1, CAP2, CAP3 = '#5A2A22', '#8A3E2A', '#B8603A'               # шляпка гриба
STEM1, STEM2 = '#CDBE9A', '#E8DCC0'                              # ножка гриба

WAT, WAT2 = '!#4FD6FF', '!#EFFFFF'
POI, POI2 = '!#8EE04A', '!#F4FFC8'
THO, THO2 = '!#6FCF5A', '!#EAFFD6'
LOT, LOT2 = '!#FF8FD0', '!#FFF2FB'
SPO, SPO2 = '!#C8E04A', '!#FFFBD6'

shades({MG: MD, ML: MG, MD: OUT, MS3: MS2, MS2: MS1, MS1: OUT, MUD2: MUD, MUD: OUT, RWL: RW, RW: MS1,
        ST3: ST2, ST2: ST1, ST1: OUT, SWH: SWL, SWL: SW, SW: ID, FOAM: SWH, RSL: RS, RS: OUT,
        LP3: LP2, LP2: LP1, LP1: OUT, CAP3: CAP2, CAP2: CAP1, CAP1: OUT, STEM2: STEM1, STEM1: BD})


def mossy(v, seed, amount, ymin=-999, ymax=999, cell=3):
    for key in list(v.v):
        i, j, k = key; c = v.v[key]
        if c.startswith('!') or c == OUT or not (ymin <= j <= ymax): continue
        n = nz(i, j, k, cell, seed)
        if n < amount * 0.5: v.v[key] = MS2
        elif n < amount: v.v[key] = MS3 if nz(i, j, k, 1, seed + 5) < 0.45 else MS1


def reed_wand():
    """Камышовый жезл: коленчатый стебель, початок рогоза и парящая капля воды."""
    v = staff_vox()
    bend = lambda y: 0.9 * math.sin(y / 14.0)
    pole(v, 0, 44, lambda x, y, z: (MS1 if y % 7 == 0 else (RWL if (x + z + y // 3) % 3 == 0 else RW)), bend=bend)
    wrap(v, 19, 25, MUD2, MUD)
    ellipsoid(v, 0.5 + bend(48), 48, 0.5, 1.8, 4.2, 1.8, lambda x, y, z: MUD2 if nz(x, y, z, 1, 3) > 0.4 else MUD)
    pole(v, 52, 54, RWL, bend=bend)
    v = finish(v)
    leaf_xy(v, 1, 36, 0, 1.0, 1.8, 10, 2.6, MS3, MS2)
    leaf_xy(v, 0, 32, 1, -1.0, 2.2, 9, 2.2, MS2, MS1)
    teardrop(v, 0.5 + bend(58), 57.5, 0.5, 1.6, 2.6, lambda x, y, z, t: WAT2 if t < 0.4 else WAT)
    motes(v, [(-2, 60, 0), (3, 56, 1)], WAT)
    return v


def mossy_staff():
    """Замшелый посох: кривой сук в мху, нарост-кап с ядовито-зелёным дуплом и нитями мха."""
    v = staff_vox()
    bend = lambda y: 1.2 * math.sin(y / 8.0) * (y / 44)
    bendz = lambda y: 0.6 * math.cos(y / 11.0)
    pole(v, 0, 46, wood(WM, WD, DWL, seed=6), bend=bend, bendz=bendz)
    wrap(v, 19, 26, MS1, MUD)
    ellipsoid(v, 0.5 + bend(48), 49, 0.5 + bendz(48), 3.4, 4.0, 3.0, wood(WL, WM, seed=7), rough=0.6, seed=4)
    rod(v, [(0.5, 50, 0.5), (-3, 55, 0.5), (-3.5, 58, 0)], wood(WM, WD, seed=8), cube=2)
    rod(v, [(1.5, 51, 0.5), (4, 54, 1), (4.5, 56, 1.5)], WM)
    mossy(v, 13, 0.55, ymin=30)
    # нити мха свисают
    for (x, z, h) in ((-3, 0, 4), (3, 1, 3), (0, -2, 5)):
        for k in range(h):
            put(v, x, 46 - k, z, MS2 if k % 2 else MS3)
    v = finish(v)
    fx = 0.5 + bend(49)
    for x in range(int(fx) - 1, int(fx) + 3):
        for y in range(48, 52):
            if math.hypot(x - fx - 0.5, y - 49.5) <= 1.7:
                put(v, x, y, 4, POI2 if (x, y) == (int(fx), 50) else POI)
    for (x, y, z) in ((-4, 59, 0), (5, 57, 1), (2, 60, -1)):
        put(v, x, y, z, POI)
    return v


def tide_staff():
    """Посох прилива: светлый плавник, навершие — раковина-завиток, в устье — водяной шар."""
    v = staff_vox()
    pole(v, 0, 44, lambda x, y, z: SWL if nz(x, y // 2, z, 1, 3) > 0.5 else SW, bend=lambda y: 0.5 * math.sin(y / 6.0))
    wrap(v, 19, 26, ST1, ST2)
    band(v, 40, 42, 1.6, ST2)
    # раковина: спираль в плоскости XY толщиной 4
    pts = []
    for i in range(46):
        a = i * 0.16
        r = 6.4 * math.exp(-0.17 * a)
        pts.append((0.5 + r * math.cos(a + 1.4), 51 + r * math.sin(a + 1.4) * 0.95, 0.5))
    for i, (x, y, z) in enumerate(pts):
        w = 1.5 * (1 - i / 46) + 0.6
        for dx in range(-3, 4):
            for dy in range(-3, 4):
                if dx * dx + dy * dy <= w * w:
                    for zz in range(-1, 3):
                        cc = FOAM if (i // 4) % 3 == 0 else (ST3 if (i // 4) % 3 == 1 else ST2)
                        setc(v, x + dx, y + dy, zz, cc)
    rod(v, [(0.5, 43, 0.5), (0.5, 46, 0.5)], ST2, cube=2)
    v = finish(v)
    orb(v, 0.5, 51.0, 0.5, 1.9, WAT, WAT2)
    motes(v, [(5, 50, 2), (-1, 46, 3), (6, 45, 0)], WAT)
    return v


def thorn_rod():
    """Терновый жезл: две лозы винтом, шипы наружу, на макушке — светящийся бутон в короне шипов."""
    v = staff_vox()
    pole(v, 0, 44, MD)
    helix(v, 2, 46, 1.3, 4.5, MG, phase=0.0)
    helix(v, 2, 46, 1.3, 4.5, MS1, phase=math.pi)
    for i in range(14):
        y = 4 + i * 3
        if 18 <= y <= 27: continue
        a = i * 2.3
        rod(v, [(0.5 + math.cos(a) * 1.4, y, 0.5 + math.sin(a) * 1.4), (0.5 + math.cos(a) * 3.0, y + 1.2, 0.5 + math.sin(a) * 3.0)],
            BM if i % 2 else BL)
    wrap(v, 19, 26, MUD, MUD2)
    for i in range(5):
        a = i * 2 * math.pi / 5
        rod(v, [(0.5 + math.cos(a) * 1.0, 45, 0.5 + math.sin(a) * 1.0), (0.5 + math.cos(a) * 3.2, 50, 0.5 + math.sin(a) * 3.2),
                (0.5 + math.cos(a) * 2.6, 55, 0.5 + math.sin(a) * 2.6)], MG, seg=lambda ii, f: BL if ii == 1 and f > 0.6 else MG)
    v = finish(v)
    teardrop(v, 0.5, 50.5, 0.5, 2.5, 6.5, lambda x, y, z, t: THO2 if t < 0.3 else THO)
    motes(v, [(-3, 58, 0), (4, 60, 1), (0, 61, -2)], THO)
    return v


def lotus_staff():
    """Посох лотоса: стебель из сине-зелёного камня в золоте, лист кувшинки и раскрытый лотос с сиянием."""
    v = staff_vox()
    pole(v, 0, 44, lambda x, y, z: ST3 if (y // 3) % 2 else ST2)
    ferrule(v, 0, GM, GL)
    wrap(v, 19, 26, ST1, GM)
    for y in (12, 33, 40):
        band(v, y, y, 1.4, GM)
    # лист кувшинки с вырезом
    for x in range(-6, 8):
        for z in range(-6, 8):
            d = math.hypot(x - 0.5, z - 0.5)
            ang = math.degrees(math.atan2(z - 0.5, x - 0.5))
            if 1.0 <= d <= 6.2 and not (-20 < ang < 20):
                put(v, x, 44, z, MS3 if (int(d) + int(ang // 30)) % 3 else MS2)
    v = finish(v)
    # лепестки: внешний круг пологий, внутренний — торчком
    for i in range(8):
        petal(v, 0.5, 45, 0.5, i * 45 + 22, 6.0, 3.4, 18, 55, lambda t, s: LP3 if t > 0.7 else (LP2 if abs(s - 0.5) < 0.3 else LP1) if 0.08 < s < 0.92 else LP1, r0=1.0)
    for i in range(6):
        petal(v, 0.5, 45.5, 0.5, i * 60, 5.5, 2.8, 55, 80, lambda t, s: LP3 if t > 0.6 else LP2, r0=0.6)
    orb(v, 0.5, 48.5, 0.5, 1.9, LOT, LOT2)
    motes(v, [(-4, 54, 0), (5, 55, 1), (1, 57, -2), (-1, 56, 3)], LOT)
    return v


def spore_staff():
    """Споровый посох: светлая ножка-древко с кольцом, большая пятнистая шляпка и грибки поменьше, светящиеся споры."""
    v = staff_vox()
    pole(v, 0, 46, lambda x, y, z: STEM2 if nz(x, y // 2, z, 1, 4) > 0.45 else STEM1, bend=lambda y: 0.6 * math.sin(y / 10.0))
    wrap(v, 19, 26, MUD2, MUD)
    ring_xz(v, 41, 2.4, 0.5, STEM1)
    # большая шляпка — сплюснутый купол
    for x in range(-7, 9):
        for z in range(-7, 9):
            d = math.hypot(x - 0.5, z - 0.5)
            if d <= 6.4:
                top = 52 + int(4.2 * math.sqrt(max(0.0, 1 - (d / 6.4) ** 2)))
                bottom = 49 if d > 4.5 else 50
                for y in range(bottom, top + 1):
                    if y == bottom and d < 5.6:
                        cc = STEM1 if int(math.degrees(math.atan2(z - 0.5, x - 0.5)) // 15) % 2 else STEM2
                    else:
                        cc = CAP3 if y == top else (CAP2 if nz(x, y, z, 2, 2) > 0.3 else CAP1)
                    put(v, x, y, z, cc)
    pole(v, 46, 50, STEM2)
    # грибки на древке
    for (y, side) in ((36, 1), (31, -1)):
        x0 = 0.5 + side * 2.5
        rod(v, [(0.5 + side * 0.8, y, 0.5), (x0, y + 1.5, 0.5)], STEM2)
        sphere(v, x0, y + 2.5, 0.5, 1.8, lambda x, yy, z, d: CAP2 if yy > y + 2 else None)
    v = finish(v)
    for (x, z) in ((-3, -2), (4, -1), (1, 4), (-2, 3), (3, 3), (-4, 1), (1, -4)):
        d = math.hypot(x - 0.5, z - 0.5)
        y = 52 + int(4.2 * math.sqrt(max(0.0, 1 - (d / 6.4) ** 2)))
        put(v, x, y, z, SPO2 if (x + z) % 3 == 0 else SPO)
    for (x, z) in ((0, 0), (1, 0), (0, 1), (1, 1)):
        put(v, x, 57, z, SPO)
    motes(v, [(-6, 59, 0), (7, 61, 2), (2, 63, -3), (-3, 62, 4), (5, 58, -4), (-8, 55, 1)], SPO, None)
    return v


def gardener_crook():
    """Посох Садовницы: пастуший крюк в лозах и листьях, розы на изгибе, с конца крюка свисает светящаяся капля-плод."""
    v = staff_vox()
    pole(v, 0, 48, wood(WL, WM, seed=9))
    ferrule(v, 0, GM, GL)
    wrap(v, 19, 26, MS1, GM)
    band(v, 16, 17, 1.4, GL); band(v, 27, 28, 1.4, GL)
    hook = [(0.5, 47, 0.5)] + arc_pts(5.0, 49, 0.5, 4.5, 180, -40, n=28)
    rod(v, hook, wood(WL, WM, seed=10), cube=2)
    helix(v, 28, 48, 1.5, 2.2, MG, phase=0.5)
    rod(v, arc_pts(5.0, 49, 1.8, 4.5, 175, 20, n=20), MG)
    for (x, y) in ((2.0, 53.0), (6.5, 53.5), (0.0, 50.5)):
        sphere(v, x, y, 1.5, 1.4, lambda xx, yy, zz, d: RSL if d < 0.5 else RS)
    v = finish(v)
    for i, y in enumerate(range(30, 48, 3)):
        leaf_xy(v, 0.5 + (1.5 if i % 2 else -0.5), y, 0 + (i % 2), (1 if i % 2 else -1), 1.2, 4, 2.0, MS3, MS2)
    for (x, y, dx, dy) in ((3.5, 54, 1, 0.6), (8, 52, 1, -0.4), (-0.5, 52, -1, 0.5), (5, 55, -0.3, 1)):
        leaf_xy(v, x, y, 2, dx, dy, 3.5, 2.0, MS3, MS2)
    end = hook[-1]
    rod(v, [(end[0], end[1] - 1, 0.5), (end[0] + 0.2, end[1] - 3, 0.5)], MG)
    teardrop(v, end[0] + 0.3, end[1] - 5.2, 0.5, 1.9, 2.4, lambda x, y, z, t: THO2 if t < 0.25 else THO)
    inlay(v, [(0, y) for y in range(6, 15, 2)] + [(1, y) for y in range(31, 41, 3)], THO)
    motes(v, [(-4, 52, 0), (11, 47, 1), (3, 58, -1), (10, 40, 0)], THO, None)
    return v


WEAPONS = [
    ('reed_wand', reed_wand, 'common'),
    ('mossy_staff', mossy_staff, 'common'),
    ('tide_staff', tide_staff, 'rare'),
    ('thorn_rod', thorn_rod, 'rare'),
    ('lotus_staff', lotus_staff, 'epic'),
    ('spore_staff', spore_staff, 'epic'),
    ('gardener_crook', gardener_crook, 'legendary'),
]
GUARD = {'lotus_staff': 44, 'spore_staff': 48, 'gardener_crook': 46}
FOCUS = {'gardener_crook': (8, 41, 0)}
