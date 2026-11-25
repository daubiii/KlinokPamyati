"""Посохи этажа 3 «Охотничьи угодья»: кость, рога, мех, капканы, тотем стаи, луна Королевского ловчего.
Неон — по стилю снаряда: bone, spirit, moon."""
import math
from staffs_common import *

FU1, FU2, FU3 = '#4A4640', '#6E6A62', '#9A958A'                  # мех
MO1, MO2, MO3 = '#6A7690', '#9AA8C0', '#C8D4E8'                  # лунное серебро
FE1, FE2 = '#5A3A26', '#E8E0D0'                                  # перо: бурое и белое

BONG, BONG2 = '!#E2D6B8', '!#FFF8E8'
SPI, SPI2 = '!#6FFFD0', '!#EAFFF8'
MOON, MOON2 = '!#A8C8FF', '!#F6F9FF'

shades({FU3: FU2, FU2: FU1, FU1: OUT, MO3: MO2, MO2: MO1, MO1: OUT, FE2: BL, FE1: OUT})


def bone_col(x, y, z):
    return BL if nz(x, y // 2, z, 1, 2) > 0.35 else BM


def fur(v, y0, y1, r=2.2, seed=0):
    """Меховой воротник: клочья неровной длины."""
    for y in range(y0, y1 + 1):
        for x in range(-3, 5):
            for z in range(-3, 5):
                d = math.hypot(x - AX, z - AZ)
                rr = r * (1 - 0.35 * (y - y0) / max(1, y1 - y0)) + (nz(x, y, z, 1, seed) - 0.5) * 1.2
                if d <= rr:
                    put(v, x, y, z, FU3 if nz(x, y, z, 1, seed + 1) > 0.6 else (FU2 if d > rr - 1 else FU1))


def fang(v, x, y, z, dx, dy, length, c=BH, c2=BL):
    rod(v, [(x, y, z), (x + dx * length, y + dy * length, z)], c, seg=lambda i, f: c if f > 0.5 else c2)


def bone_wand():
    """Костяной жезл: бедренная кость с мыщелками, навершие — три клыка вокруг тусклого костяного огонька."""
    v = staff_vox()
    pole(v, 0, 45, bone_col)
    sphere(v, 0.0, 1.5, 0.5, 1.8, BM); sphere(v, 1.5, 1.8, 0.5, 1.6, BL)
    wrap(v, 19, 26, LD, LM)
    band(v, 30, 30, 1.4, LM); band(v, 34, 34, 1.4, LM)
    sphere(v, -0.3, 46.5, 0.5, 2.3, lambda x, y, z, d: bone_col(x, y, z)); sphere(v, 1.6, 47.0, 0.7, 2.1, lambda x, y, z, d: bone_col(x, y, z))
    for i in range(3):
        a = i * 2 * math.pi / 3 + 0.4
        fang(v, 0.5 + math.cos(a) * 2.0, 48.5, 0.5 + math.sin(a) * 2.0, math.cos(a) * 0.2, 1.0, 6.5)
    v = finish(v)
    orb(v, 0.5, 52.0, 0.5, 1.5, BONG, BONG2)
    return v


def antler_staff():
    """Рогатый посох: древко в ремнях, навершие — ветвистые рога, между ними дух-огонёк."""
    v = staff_vox()
    pole(v, 0, 44, wood(DWL, DWM, seed=12))
    ferrule(v, 0, BM, BL)
    wrap(v, 19, 26, LM, LD)
    band(v, 42, 44, 1.6, LM)
    for side in (-1, 1):
        main = [(0.5, 44, 0.5), (0.5 + side * 2.0, 47, 0.5), (0.5 + side * 4.0, 51, 0.5), (0.5 + side * 4.6, 55, 0.5),
                (0.5 + side * 3.8, 59, 0.5)]
        rod(v, main, bone_col, cube=2)
        rod(v, [(0.5 + side * 2.6, 48.5, 0.5), (0.5 + side * 6.4, 50.5, 0.5), (0.5 + side * 7.4, 53, 0.5)], BL)
        rod(v, [(0.5 + side * 4.3, 53, 0.5), (0.5 + side * 7.0, 56, 0.5), (0.5 + side * 7.0, 58, 0.5)], BL)
        rod(v, [(0.5 + side * 4.3, 56, 0.5), (0.5 + side * 2.2, 59.5, 0.5)], BH)
    v = finish(v)
    teardrop(v, 0.5, 50, 0.5, 1.6, 3.2, lambda x, y, z, t: SPI2 if t < 0.35 else SPI, lean=(0.4, 0.0))
    return v


def howl_staff():
    """Посох воя: тёмное древко с меховым воротником, навершие — разинутая костяная пасть, в ней дух-пламя."""
    v = staff_vox()
    pole(v, 0, 44, wood(DWM, DW, seed=13))
    ferrule(v, 0, IM, IL)
    wrap(v, 19, 26, FU1, FU2)
    fur(v, 38, 44, 2.6, seed=3)
    # челюсти: нижняя и верхняя дуги в плоскости XY с зубами внутрь
    lower = arc_pts(0.5, 50, 0.5, 4.6, 200, 340, n=14)
    upper = arc_pts(0.5, 51, 0.5, 4.8, 25, 155, n=14)
    rod(v, lower, bone_col, cube=2)
    rod(v, upper, bone_col, cube=2)
    rod(v, [(0.5, 44, 0.5), (0.5, 46.5, 0.5)], BM, cube=2)
    for a in (215, 245, 295, 325):
        r = math.radians(a)
        fang(v, 0.5 + 4.2 * math.cos(r), 50 + 4.2 * math.sin(r), 0.5, -math.cos(r) * 0.3, 0.9, 2.2)
    for a in (40, 70, 110, 140):
        r = math.radians(a)
        fang(v, 0.5 + 4.4 * math.cos(r), 51 + 4.4 * math.sin(r), 0.5, -math.cos(r) * 0.3, -0.9, 2.2)
    for x0, side in ((-4.3, -1), (5.3, 1)):
        rod(v, [(x0, 49, 0.5), (x0 + side * 0.4, 52, 0.5)], BM, cube=2)
    v = finish(v)
    flame(v, 0.5, 47.5, 7, 1.8, SPI, SPI2, seed=4, tongues=3)
    return v


def trap_rod():
    """Жезл ловчего: железо и кость, навершие — раскрытый капкан с цепью, в пасти — костяной заряд."""
    v = staff_vox()
    pole(v, 0, 44, lambda x, y, z: IM if (y // 3) % 2 else ID)
    ferrule(v, 0, IM, IL)
    wrap(v, 19, 26, LM, LD)
    band(v, 36, 37, 1.5, BM)
    box(v, -1, 2, 43, 45, -1, 2, IM)
    # раскрытый капкан анфас: две полудуги-челюсти (зазор сверху и снизу), зубья внутрь
    for side in (-1, 1):
        jaw = arc_pts(0.5, 50.5, 0.5, 5.6, 105, 255, n=16) if side < 0 else arc_pts(0.5, 50.5, 0.5, 5.6, -75, 75, n=16)
        rod(v, jaw, IL, cube=2)
        for k in range(1, len(jaw) - 1, 3):
            x, y, _ = jaw[k]
            ang = math.atan2(y - 50.5, x - 0.5)
            rod(v, [(x - math.cos(ang) * 0.8, y - math.sin(ang) * 0.8, 0.5), (x - math.cos(ang) * 2.2, y - math.sin(ang) * 2.2, 0.5)], IH)
    rod(v, [(0.5, 45, 0.5), (0.5, 45.5, 0.5)], IM, cube=2)
    # пружины по бокам
    for x in (-6, 7):
        for y in range(47, 54):
            put(v, x, y, 0 if y % 2 else 1, ID)
    # цепь вниз
    for i in range(4):
        y = 41 - i * 2
        ring_xy(v, 3.5, y, 1.1, 0.4, IL, z0=0, z1=0) if i % 2 == 0 else ring_xz(v, y, 1.1, 0.4, IL, cx=3.5)
    v = finish(v)
    orb(v, 0.5, 50.5, 0.5, 1.7, BONG, BONG2)
    return v


def pack_staff():
    """Посох стаи: резной тотем из трёх волчьих голов, глаза светятся духом; на вершине — дух-шар в вихре."""
    v = staff_vox()
    pole(v, 0, 34, wood(WM, WD, seed=14))
    ferrule(v, 0, BM, BL)
    wrap(v, 18, 25, FU1, LM)
    eyes = []
    for k, y0 in enumerate((34, 40, 46)):
        w = 2 if k < 2 else 3
        box(v, 0 - w + 1, w, y0, y0 + 5, -1, 2, lambda x, y, z: WL if (x + y) % 3 else WM)
        box(v, 0, 1, y0 + 1, y0 + 2, 3, 3, WH)                                       # морда
        for x in (-w + 1, w):
            put(v, x, y0 + 6, 0, WM); put(v, x, y0 + 6, 1, WM)                       # уши
            put(v, x, y0 + 7, 1, WD)
        eyes += [(0 - w + 2, y0 + 4), (w - 1, y0 + 4)]
        band(v, y0, y0, 1.2, BM)
    v = finish(v)
    for (x, y) in eyes:
        put(v, x, y, 3, SPI); put(v, x, y, -2, SPI)
    orb(v, 0.5, 57.0, 0.5, 2.0, SPI, SPI2)
    helix(v, 53, 62, 3.6, 1.1, SPI, phase=0.0)
    for (x, y, z) in ((-3, 60, 0), (4, 63, 1), (1, 64, -1)):
        put(v, x, y, z, SPI2)
    return v


def moon_staff():
    """Лунный посох: серебряное древко, навершие — серп луны, обнимающий светящийся лунный шар, и звёзды."""
    v = staff_vox()
    pole(v, 0, 44, lambda x, y, z: MO2 if (y // 2) % 3 else MO1)
    ferrule(v, 0, MO2, MO3)
    wrap(v, 19, 26, PD, PM)
    for y in (14, 31, 38):
        band(v, y, y, 1.4, MO3)
    band(v, 43, 44, 1.8, MO2)
    # серп: разность двух кругов
    for x in range(-7, 9):
        for y in range(44, 61):
            d1 = math.hypot(x - 0.5, y - 52)
            d2 = math.hypot(x - 3.3, y - 53.5)
            if d1 <= 6.8 and d2 > 5.6:
                for z in range(-1, 3):
                    if z in (-1, 2) and d1 > 6.0: continue
                    put(v, x, y, z, MO3 if d1 > 5.8 else MO2)
    v = finish(v)
    orb(v, 2.6, 52.6, 0.5, 2.2, MOON, MOON2)
    for (x, y, z) in ((6, 60, 0), (-5, 61, 1), (7, 47, 0)):
        for (dx, dy) in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            put(v, x + dx, y + dy, z, MOON2 if (dx, dy) == (0, 0) else MOON)
    return v


def huntmaster_staff():
    """Посох Королевского ловчего: древко в золоте и мехе, золотой серп с лунным шаром, рога с золотыми концами, перья сокола."""
    v = staff_vox()
    pole(v, 0, 44, wood(DWL, DWM, seed=15))
    ferrule(v, 0, GM, GL)
    wrap(v, 18, 26, PD, GM)
    for y in (12, 30):
        band(v, y, y + 1, 1.5, GL)
    fur(v, 36, 42, 2.4, seed=5)
    band(v, 43, 44, 2.0, GD)
    # рога
    for side in (-1, 1):
        rod(v, [(0.5, 45, 0.5), (0.5 + side * 3.5, 48, 0.5), (0.5 + side * 6.5, 53, 0.5), (0.5 + side * 7.0, 58, 0.5)], bone_col, cube=2)
        rod(v, [(0.5 + side * 5.0, 50.5, 0.5), (0.5 + side * 8.5, 51.5, 0.5)], BL)
        rod(v, [(0.5 + side * 6.8, 56, 0.5), (0.5 + side * 9.0, 59, 0.5)], GL)
        rod(v, [(0.5 + side * 7.0, 57.5, 0.5), (0.5 + side * 7.0, 60, 0.5)], GL)
    # золотой серп
    for x in range(-5, 7):
        for y in range(45, 58):
            d1 = math.hypot(x - 0.5, y - 51.5)
            d2 = math.hypot(x - 0.5, y - 54.2)
            if d1 <= 5.2 and d2 > 4.4:
                for z in range(-1, 3):
                    put(v, x, y, z, GL if d1 > 4.4 else GM)
    v = finish(v)
    orb(v, 0.5, 53.0, 0.5, 2.3, MOON, MOON2)
    # перья на шнурах
    for (x0, side) in ((-2, -1), (3, 1)):
        rod(v, [(x0, 43, 0.5), (x0 + side * 0.8, 39, 0.5)], LM)
        leaf_xy(v, x0 + side * 0.8, 39, 0, side * 0.25, -1, 8, 2.4, FE1, FE2)
    motes(v, [(-8, 47, 0), (9, 45, 1), (-5, 62, 0), (6, 63, 1)], MOON)
    inlay(v, [(0, y) for y in range(28, 35, 2)], MOON)
    return v


WEAPONS = [
    ('bone_wand', bone_wand, 'common'),
    ('antler_staff', antler_staff, 'common'),
    ('howl_staff', howl_staff, 'rare'),
    ('trap_rod', trap_rod, 'rare'),
    ('pack_staff', pack_staff, 'epic'),
    ('moon_staff', moon_staff, 'epic'),
    ('huntmaster_staff', huntmaster_staff, 'legendary'),
]
GUARD = {'pack_staff': 34, 'bone_wand': 45}
