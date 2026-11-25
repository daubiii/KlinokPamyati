"""Посохи этажа 4 «Кузня»: кочерга, меха, шлак, тигель, наковальня, сердце горна, расплавленный скипетр,
незаконченный посох. Неон — по стилю снаряда: fire, slag, magma, lightning, forge."""
import math
from staffs_common import *

SO1, SO2, SO3 = '#2A2624', '#403A36', '#5A524C'                 # сажа, кованое железо
BS1, BS2, BS3 = '#6E5420', '#B08A3E', '#D9B566'                  # латунь
CU1, CU2, CU3 = '#7A3A1E', '#B86A3A', '#D98A4E'                  # медь
OB1, OB2, OB3 = '#140F10', '#2A2022', '#43343A'                  # обсидиан
SL1, SL2 = '#3A2418', '#4A2A1E'                                  # шлак
HOT1, HOT2 = '#7A2A10', '#B8401A'                                # остывающий металл

FIRE, FIRE2, FIRE3 = '!#FF5A1F', '!#FFF4C0', '!#FFB536'
SLAG, SLAG2 = '!#FF8A2A', '!#FFE2A0'
MAG, MAG2 = '!#FF3A10', '!#FFE6A0'
LIG, LIG2 = '!#7FD8FF', '!#FFFFFF'
FOR, FOR2 = '!#FFE39A', '!#FFFFFF'

shades({SO3: SO2, SO2: SO1, SO1: OUT, BS3: BS2, BS2: BS1, BS1: OUT, CU3: CU2, CU2: CU1, CU1: OUT,
        OB3: OB2, OB2: OB1, OB1: OUT, SL2: SL1, SL1: OUT, HOT2: HOT1, HOT1: SO1})


def forged(x, y, z):
    return SO3 if (y // 2 + x) % 3 == 0 else SO2


def zigzag(v, p0, p1, c, kinks=4, amp=1.4, seed=0):
    """Молния ломаной линией от p0 до p1."""
    pts = [p0]
    for k in range(1, kinks):
        f = k / kinks
        side = 1 if (k + seed) % 2 else -1
        pts.append((p0[0] + (p1[0] - p0[0]) * f + side * amp, p0[1] + (p1[1] - p0[1]) * f, p0[2] + (p1[2] - p0[2]) * f))
    pts.append(p1)
    rod(v, pts, c)


def poker_rod():
    """Жезл-кочерга: кручёный железный прут, кольцо-ручка, раскалённый крюк на конце."""
    v = staff_vox()
    pole(v, 0, 46, lambda x, y, z: SO3 if ((y + (x * 2 + z) * 2) // 2) % 2 else SO1)
    ring_xy(v, 0.5, -2.5, 2.6, 1.4, SO2, z0=0, z1=1)
    wrap(v, 19, 26, LM, LD)
    band(v, 16, 16, 1.4, SO3); band(v, 29, 29, 1.4, SO3)
    v = finish(v)
    # раскалённый конец: остриё и боковой крюк
    for y in range(44, 52):
        c = HOT2 if y < 46 else (FIRE if y < 49 else FIRE3)
        for (x, z) in ((0, 0), (0, 1), (1, 0), (1, 1)):
            if y > 49 and (x, z) != (0, 0) and (x, z) != (1, 1): continue
            put(v, x, y, z, c)
    rod(v, [(1.5, 47, 0.5), (3.5, 48.5, 0.5), (4.0, 51, 0.5)], FIRE, cube=2)
    put(v, 0, 52, 0, FIRE2); put(v, 4, 52, 0, FIRE2)
    motes(v, [(-2, 54, 0), (3, 56, 1), (6, 53, 0)], FIRE3)
    return v


def bellows_staff():
    """Посох мехов: древко-ручка, навершие — кузнечные меха из досок и кожи, из сопла бьёт пламя."""
    v = staff_vox()
    pole(v, 0, 40, wood(WM, WD, seed=16))
    ferrule(v, 0, CU2, CU3)
    wrap(v, 19, 26, LM, LD)
    band(v, 38, 40, 1.5, CU2)
    # доски мехов — капли в плоскости XY, кожа гармошкой между ними
    for z, c in ((-2, WL), (3, WL)):
        for x in range(-5, 7):
            for y in range(40, 54):
                d = math.hypot((x - 0.5) / 5.0, (y - 46) / 6.0) if y < 46 else math.hypot((x - 0.5) / (5.0 * (1 - (y - 46) / 9.0) + 0.01), 0)
                if (y < 46 and d <= 1.0) or (y >= 46 and abs(x - 0.5) <= 5.0 * (1 - (y - 46) / 9.0)):
                    put(v, x, y, z, c if (x + y) % 4 else WM)
    for z in (-1, 0, 1, 2):
        for x in range(-4, 6):
            for y in range(41, 52):
                inside = math.hypot((x - 0.5) / 4.0, (y - 46) / 5.0) <= 1.0 if y < 46 else abs(x - 0.5) <= 4.0 * (1 - (y - 46) / 8.0)
                if inside:
                    put(v, x, y, z, LM if (y + z) % 2 else LL)
    # сопло
    for y in range(52, 57):
        band(v, y, y, 0.9 if y > 54 else 1.3, CU2 if y % 2 else CU3)
    v = finish(v)
    flame(v, 0.5, 57, 6, 1.5, FIRE, FIRE2, seed=3, tongues=2)
    return v


def slag_rod():
    """Шлаковый жезл: железо в потёках шлака, навершие — ком шлака с раскалёнными трещинами."""
    v = staff_vox()
    pole(v, 0, 44, forged)
    wrap(v, 19, 26, SO1, SO3)
    for y in (10, 34):
        band(v, y, y + 1, 1.5, SO3)
    ellipsoid(v, 0.5, 50, 0.5, 4.0, 5.2, 3.6, lambda x, y, z: SL2 if nz(x, y, z, 2, 6) > 0.4 else SL1, rough=0.7, seed=9)
    # потёки вниз по древку
    for (x, z, h) in ((-1, 0, 6), (2, 1, 9), (0, -1, 4), (1, 2, 7)):
        for k in range(h):
            put(v, x, 45 - k, z, SL1 if k % 3 else SL2)
    v = finish(v)
    # раскалённые трещины по поверхности кома
    for key in list(v.v):
        x, y, z = key
        if v.v[key] in (SL1, SL2, OUT) and y >= 46:
            n = nz(x * 2, y, z * 2, 1, 21)
            if abs(math.sin(x * 1.3 + y * 0.7 + z * 1.9)) < 0.18 and n > 0.3:
                v.v[key] = SLAG
    orb(v, 0.5, 55.5, 0.5, 1.3, SLAG, SLAG2)
    for (x, y, z) in ((2, 42, 1), (-1, 40, 0)):
        put(v, x, y, z, SLAG)
    return v


def crucible_staff():
    """Посох тигля: кованые клещи держат тигель с жидкой магмой, через край — огненные капли."""
    v = staff_vox()
    pole(v, 0, 42, forged)
    ferrule(v, 0, SO3, IL)
    wrap(v, 19, 26, LD, LM)
    band(v, 40, 42, 1.6, SO3)
    # клещи: два захвата снизу
    for side in (-1, 1):
        rod(v, [(0.5, 42, 0.5), (0.5 + side * 3.5, 45, 0.5), (0.5 + side * 4.6, 49, 0.5), (0.5 + side * 4.0, 51, 0.5)], SO3, cube=2)
    bowl(v, 45, 6, 2.6, 4.4, lambda x, y, z: CU2 if (x + y + z) % 4 else CU1, rim=CU3, fill=MAG)
    v = finish(v)
    # поверхность магмы и выплёски
    for x in range(-3, 5):
        for z in range(-3, 5):
            if math.hypot(x - 0.5, z - 0.5) <= 3.2:
                put(v, x, 51, z, MAG2 if nz(x, 0, z, 1, 3) > 0.65 else MAG)
    teardrop(v, 0.5, 52.5, 0.5, 1.2, 3.5, lambda x, y, z, t: MAG2 if t < 0.4 else MAG)
    for (x, z, h) in ((5, 0, 4), (-4, 1, 3)):
        for k in range(h):
            put(v, x, 50 - k, z, MAG)
    motes(v, [(-2, 57, 0), (3, 58, 1), (5, 55, -1)], MAG, None)
    return v


def anvil_rod():
    """Наковальный жезл: на древке — малая наковальня с рогом, с рога и пяты бьют молнии."""
    v = staff_vox()
    pole(v, 0, 42, lambda x, y, z: IM if (y // 3) % 2 else ID)
    ferrule(v, 0, IM, IL)
    wrap(v, 19, 26, LM, LD)
    for y in (14, 33):
        band(v, y, y + 1, 1.5, IL)
    # подставка и тело наковальни
    box(v, -2, 3, 43, 45, -1, 2, ID)
    box(v, -1, 2, 46, 47, -1, 2, IM)
    box(v, -4, 5, 48, 51, -2, 3, lambda x, y, z: IH if y == 51 else IM)
    # рог (+X) — конус, пята (−X) — уступ
    for k in range(6):
        r = 1.6 * (1 - k / 6) + 0.4
        for y in range(49, 52):
            for z in range(-2, 4):
                if math.hypot(y - 50.3, z - 0.5) <= r:
                    put(v, 6 + k, y, z, IH if y == 51 else IL)
    box(v, -6, -5, 49, 51, -1, 2, IM)
    v = finish(v)
    zigzag(v, (11.5, 50.5, 0.5), (8.5, 60, 0.5), LIG, kinks=4, amp=1.2)
    zigzag(v, (-6.5, 51.5, 0.5), (-4.5, 59, 0.5), LIG, kinks=3, amp=1.0, seed=1)
    zigzag(v, (0.5, 52, 0.5), (1.5, 62, 0.5), LIG2, kinks=4, amp=1.3, seed=2)
    motes(v, [(4, 58, 0), (-3, 61, 1), (10, 55, 0)], LIG)
    return v


def founder_staff():
    """Посох Основателя: латунь и медь, навершие — шестерня-обод с сердцем горна, молот и зубило накрест."""
    v = staff_vox()
    pole(v, 0, 44, lambda x, y, z: BS2 if (y // 2) % 3 else BS1)
    ferrule(v, 0, CU2, CU3)
    wrap(v, 18, 26, CU1, CU2)
    for y in (12, 30, 38):
        band(v, y, y + 1, 1.5, BS3)
    band(v, 43, 45, 2.2, CU2)
    # шестерня в плоскости XY
    for x in range(-8, 10):
        for y in range(44, 62):
            d = math.hypot(x - 0.5, y - 52.5)
            a = math.atan2(y - 52.5, x - 0.5)
            tooth = math.cos(a * 10) > 0.3
            if 4.6 <= d <= (6.8 if tooth else 5.8):
                for z in range(-1, 3):
                    put(v, x, y, z, BS3 if d > 5.8 else BS2)
            elif 1.8 < d < 4.6 and any(abs(math.sin(a - k * math.pi / 3)) < 0.18 for k in range(3)):
                for z in (0, 1):
                    put(v, x, y, z, BS1)
    # молот и зубило накрест за шестернёй
    rod(v, [(-5.5, 45.5, -2), (6.5, 59.5, -2)], WM, cube=2)
    box(v, 5, 8, 58, 61, -3, -1, SO3)
    rod(v, [(6.5, 45.5, -2), (-4.5, 58.5, -2)], IL, cube=2)
    v = finish(v)
    orb(v, 0.5, 52.5, 0.5, 2.6, FOR, FOR2)
    motes(v, [(-8, 62, 0), (9, 63, 1), (1, 64, 0), (-9, 50, 1), (10, 47, 0)], FOR)
    inlay(v, [(0, y) for y in range(28, 37, 2)] + [(1, y) for y in range(6, 15, 3)], FIRE3)
    return v


def molten_scepter():
    """Расплавленный скипетр: обсидиан с лавовыми прожилками, корона из обсидиановых шипов, в ней — шар магмы в корке."""
    v = staff_vox()
    pole(v, 0, 44, lambda x, y, z: OB2 if nz(x, y // 2, z, 1, 8) > 0.4 else OB1)
    ferrule(v, 0, OB3, BS2)
    wrap(v, 18, 26, OB1, BS1)
    for y in (14, 32):
        band(v, y, y + 1, 1.5, BS2)
    band(v, 42, 44, 2.2, OB3)
    for i in range(6):
        a = i * math.pi / 3 + 0.2
        h = 9 if i % 2 else 7
        rod(v, [(0.5 + math.cos(a) * 2.0, 44, 0.5 + math.sin(a) * 2.0), (0.5 + math.cos(a) * 4.4, 44 + h * 0.6, 0.5 + math.sin(a) * 4.4),
                (0.5 + math.cos(a) * 3.8, 44 + h + 1, 0.5 + math.sin(a) * 3.8)], OB3, seg=lambda ii, f: OB3 if ii == 0 else OB2)
    v = finish(v)
    sphere(v, 0.5, 51.5, 0.5, 3.2, lambda x, y, z, d: (OB2 if nz(x, y, z, 2, 4) > 0.62 else (MAG2 if d < 0.5 else MAG)))
    # лавовые прожилки по древку и капли
    for key in list(v.v):
        x, y, z = key
        if v.v[key] in (OB1, OB2) and 2 <= y <= 42 and abs(math.sin(y * 0.55 + x * 2.1 + z * 1.3)) < 0.12:
            v.v[key] = MAG
    for (x, z, h) in ((3, 0, 3), (-2, 1, 4)):
        for k in range(h):
            put(v, x, 47 - k, z, MAG)
    motes(v, [(-5, 58, 0), (6, 59, 1), (0, 61, -1)], MAG, None)
    return v


def unfinished_staff():
    """Незаконченный посох: низ отполирован и в латуни, верх — сырая заготовка: каркас навершия
    наполовину залит раскалённым металлом, следы молота, искры."""
    v = staff_vox()
    pole(v, 0, 30, lambda x, y, z: BS2 if (y // 2) % 2 else BS3)
    ferrule(v, 0, CU2, CU3)
    wrap(v, 18, 26, PD, PM)
    band(v, 30, 31, 1.5, CU3)
    # выше — заготовка: остывающая сталь, к верху всё горячее
    for y in range(32, 45):
        c = SO2 if y < 36 else (HOT1 if y < 40 else HOT2)
        for (x, z) in ((0, 0), (0, 1), (1, 0), (1, 1)):
            put(v, x, y, z, c if (y + x) % 5 else SO3)
    # каркас навершия: 4 ребра будущего кристалла (как у Посоха послушника, но в железе)
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        pts = []
        for k in range(9):
            t = k / 8
            r = 3.6 * math.sin(math.pi * min(1.0, t * 1.05))
            pts.append((0.5 + math.cos(a) * r, 45 + t * 14, 0.5 + math.sin(a) * r))
        rod(v, pts, SO3, seg=lambda ii, f: SO3 if ii < 4 else SO2)
    ring_xz(v, 49, 3.8, 2.8, SO3)
    v = finish(v)
    # залито наполовину: расплав снизу каркаса, ровная кромка-«уровень»
    for y in range(45, 52):
        t = (y - 45) / 14
        r = 3.6 * math.sin(math.pi * t) - 0.4
        for x in range(-4, 6):
            for z in range(-4, 6):
                if abs(x - 0.5) + abs(z - 0.5) <= r * 1.2 and (x, y, z) not in v.v:
                    put(v, x, y, z, FOR2 if y == 51 and nz(x, 0, z, 1, 2) > 0.5 else FOR)
    for (x, y, z) in ((-4, 56, 0), (5, 58, 1), (1, 61, -1), (-2, 63, 2), (4, 54, -3), (6, 61, 0), (-6, 52, 1)):
        put(v, x, y, z, FIRE3)
    inlay(v, [(0, y) for y in range(38, 44, 2)], FIRE)
    return v


WEAPONS = [
    ('poker_rod', poker_rod, 'common'),
    ('bellows_staff', bellows_staff, 'rare'),
    ('slag_rod', slag_rod, 'rare'),
    ('crucible_staff', crucible_staff, 'epic'),
    ('anvil_rod', anvil_rod, 'epic'),
    ('founder_staff', founder_staff, 'legendary'),
    ('molten_scepter', molten_scepter, 'legendary'),
    ('unfinished_staff', unfinished_staff, 'secret'),
]
GUARD = {'bellows_staff': 40, 'crucible_staff': 43, 'anvil_rod': 43, 'unfinished_staff': 45}
FOCUS = {'anvil_rod': (0, 54, 0), 'poker_rod': (0, 50, 0), 'bellows_staff': (0, 58, 0)}
