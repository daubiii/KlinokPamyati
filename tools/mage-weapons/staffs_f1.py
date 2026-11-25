"""Посохи этажа 1 «Порог»: ржавое железо, бронза, золото Привратника, огонь маяка.
Неон — по стилю снаряда (LootMage.Styles): arcane, rust, ember, light, gate, fire."""
import math
from staffs_common import *

ARC, ARC2 = '!#8C6CFF', '!#F0EBFF'
RUSTG = '!#D9772F'
EMB, EMB2 = '!#FF7A1F', '!#FFF0B0'
LIT, LIT2 = '!#FFD45A', '!#FFFDEE'
GATE, GATE2 = '!#6FB8FF', '!#E4F4FF'
FIRE, FIRE2 = '!#FF5A1F', '!#FFF4C0'
FIRE3 = '!#FFB536'
FIRE4 = '!#B8200F'


def apprentice_staff():
    """Посох послушника: простое древко, развилка держит фиолетовый кристалл."""
    v = staff_vox()
    pole(v, 0, 45, wood(WM, WL, WD, seed=1))
    ferrule(v, 0, IM, IL)
    wrap(v, 19, 26, LM, LD)
    band(v, 40, 41, 1.3, BR)
    for side in (-1, 1):
        x0 = 0.5 + side * 0.5
        rod(v, [(x0, 44, 0.5), (0.5 + side * 2.2, 47, 0.5), (0.5 + side * 3.0, 51, 0.5), (0.5 + side * 2.4, 55, 0.5),
                (0.5 + side * 1.4, 57, 0.5)], wood(WL, WM, seed=2), cube=2)
    crystal(v, 0.5, 46, 56, 2.0, ARC, ARC2)
    return finish(v)


def rusted_rod():
    """Ржавый жезл: железный прут с заклёпками, навершие — шар-набалдашник с поясом и щёткой ржавых осколков."""
    v = staff_vox()
    pole(v, 0, 44, lambda x, y, z: IM if (y // 2 + x + z) % 3 else ID)
    for y in (8, 17, 30, 38):
        band(v, y, y, 1.4, IL)
    wrap(v, 19, 27, RD, RM)
    band(v, 43, 44, 1.8, IL)
    sphere(v, 0.5, 48.5, 0.5, 3.4, lambda x, y, z, d: ID if nz(x, y, z, 2, 4) > 0.6 else IM)
    ring_xz(v, 48, 3.9, 2.4, IL, h=1)
    for (x, z) in ((-3, 0), (4, 1), (0, -3), (1, 4)):
        put(v, x, 48, z, IH)
    speckle(v, 9, 0.4, (RM, RL), ymin=0, ymax=52, only=(IM, ID))
    crystal(v, 0.5, 51, 58, 1.5, RL, RM)
    crystal(v, -0.8, 50, 55, 1.1, RM, None, tx=-0.35)
    crystal(v, 2.0, 50, 54, 1.0, RL, None, tx=0.4, tz=0.2)
    v = finish(v)
    for (x, y) in ((0, 46), (1, 47), (1, 48), (0, 49), (1, 50)):
        put(v, x, y, 4, RUSTG); put(v, x, y, -3, RUSTG)
    crystal(v, 0.5, 55, 59, 0.9, RUSTG)
    return v


def ember_staff():
    """Посох углей: тёмное древко, железная жаровня с углями и языком пламени, кованые зубцы."""
    v = staff_vox()
    pole(v, 0, 44, wood(DWM, DW, DWL, seed=3), bend=lambda y: 0.6 * math.sin(y / 9.0))
    ferrule(v, 0, ID, IM)
    wrap(v, 19, 26, LM, LD)
    band(v, 36, 37, 1.4, IM)
    band(v, 42, 43, 1.6, IL)
    bowl(v, 44, 4, 1.6, 3.6, IM, rim=IL, fill=EMB)
    prongs(v, 47, 56, 4, 3.6, 3.9, ID, phase=math.pi / 4, curl=1.25, tip=IL)
    v = finish(v)
    flame(v, 0.5, 46, 10, 2.4, EMB, EMB2, seed=1, tongues=3)
    motes(v, [(-3, 55, 0), (4, 58, 1), (2, 60, 0)], EMB)
    return v


def warden_rod():
    """Жезл дозорного: бронзовые обоймы, на макушке — фонарь стражи с тёплым светом."""
    v = staff_vox()
    pole(v, 0, 43, wood(WM, WD, seed=4))
    ferrule(v, 0, BR, BRL)
    wrap(v, 19, 26, BRD, BR, every=1)
    for y in (12, 33):
        band(v, y, y + 1, 1.4, BR)
    band(v, 42, 44, 2.6, BRD)
    # каркас фонаря: стойки по углам, донце и крыша-пирамида
    for (x, z) in ((-2, -2), (-2, 3), (3, -2), (3, 3)):
        for y in range(45, 54):
            put(v, x, y, z, BR if y % 3 else BRL)
    for x in range(-2, 4):
        for z in range(-2, 4):
            put(v, x, 45, z, BRD)
    for k, y in enumerate(range(54, 58)):
        for x in range(-2 + k, 4 - k):
            for z in range(-2 + k, 4 - k):
                put(v, x, y, z, BRL if k % 2 else BR)
    band(v, 58, 59, 0.8, BRL)
    ring_xz(v, 60, 1.8, 0.9, BR)
    v = finish(v)
    orb(v, 0.5, 49.5, 0.5, 2.3, LIT, LIT2)
    return v


def gate_staff():
    """Посох Заставы: каменное древко в железе, навершие — арка ворот с голубым порталом."""
    v = staff_vox()
    pole(v, 0, 43, lambda x, y, z: SM if (y // 3) % 2 else SD)
    ferrule(v, 0, IM, IL)
    wrap(v, 19, 26, ID, IM)
    for y in (10, 30, 38):
        band(v, y, y + 1, 1.4, IM)
    # перекладина-порог
    box(v, -5, 6, 43, 44, -1, 2, IM)
    # столбы ворот
    for x0 in (-5, 5):
        box(v, x0, x0 + 1, 45, 52, -1, 2, lambda x, y, z: SL if (y + x) % 4 else SM)
    # свод
    ring_xy(v, 0.5, 52, 6.2, 4.0, lambda x, y, z: SM if y < 52 else (SL if (x + y) % 3 else SM), z0=-1, z1=2)
    for x in range(-6, 8):
        for y in range(45, 52):
            if x < -5 or x > 6:
                v.v.pop((x, y, -1), None); v.v.pop((x, y, 2), None); v.v.pop((x, y, 0), None); v.v.pop((x, y, 1), None)
    # ключевой камень и зубцы
    box(v, -1, 2, 57, 59, -1, 2, GM)
    for x in (-4, 5):
        box(v, x, x, 57, 58, 0, 1, IM)
    # створки ворот внутри свода: дерево в железных полосах, посередине — щель со светом
    for x in range(-4, 6):
        for y in range(45, 57):
            d = math.hypot(x - 0.5, y - 52) if y > 52 else abs(x - 0.5)
            if d <= 4.2 and (x, y, 0) not in v.v and x not in (0, 1):
                cc = IM if y in (47, 52) else (WM if (x + y) % 5 else WL)
                put(v, x, y, 0, cc); put(v, x, y, 1, cc)
    for (x, y) in ((-3, 47), (4, 47), (-3, 52), (4, 52)):
        put(v, x, y, 2, IH); put(v, x, y, -1, IH)
    v = finish(v)
    for y in range(45, 57):
        if (0, y, 0) not in v.v:
            for x in (0, 1):
                put(v, x, y, 0, GATE2 if 47 <= y <= 54 else GATE); put(v, x, y, 1, GATE)
    for (x, y, z) in ((0, 50, 2), (1, 51, 2), (0, 53, -1), (1, 48, -1), (0, 55, 2)):
        put(v, x, y, z, GATE)
    motes(v, [(-1, 58, 3), (2, 60, -2), (0, 62, 0)], GATE)
    return v


def beacon_staff():
    """Маячный посох: высокое кованое древко, чаша маяка на трёх распорках и большое пламя."""
    v = staff_vox()
    pole(v, 0, 43, lambda x, y, z: ID if (y // 4) % 2 else IM)
    ferrule(v, 0, IM, IL)
    wrap(v, 19, 26, RD, LM)
    for y in (12, 32):
        band(v, y, y + 1, 1.4, IL)
    # распорки от древка к чаше
    for i in range(3):
        a = i * 2 * math.pi / 3 + 0.3
        rod(v, [(0.5 + math.cos(a) * 0.8, 36, 0.5 + math.sin(a) * 0.8), (0.5 + math.cos(a) * 4.2, 45, 0.5 + math.sin(a) * 4.2)], IL)
    bowl(v, 42, 5, 2.0, 4.6, lambda x, y, z: IM if (x + z) % 3 else IL, rim=BRL, fill=FIRE)
    v = finish(v)
    flame(v, 0.5, 46, 14, 3.4, FIRE, FIRE3, seed=2, tongues=4, tip=FIRE4)
    motes(v, [(-4, 58, 0), (5, 61, 1), (1, 63, 0), (-2, 62, 2)], FIRE3)
    return v


def gatekeeper_scepter():
    """Скипетр Привратника: золотое древко с бородкой ключа, кольцо-ушко с сияющей скважиной, корона."""
    v = staff_vox()
    pole(v, 0, 43, lambda x, y, z: GM if (y // 2) % 3 else GD)
    ferrule(v, 0, GD, GL)
    wrap(v, 18, 26, PD, PM)
    for y in (16, 27, 36):
        band(v, y, y + 1, 1.5, GL)
    # бородка ключа (зубцы на +X)
    for (y0, y1, w) in ((37, 39, 4), (40, 41, 3), (42, 43, 5)):
        box(v, 2, 1 + w, y0, y1, 0, 1, lambda x, y, z: GL if x == 1 + w else GM)
    band(v, 43, 44, 2.0, GD)
    # кольцо-ушко
    ring_xy(v, 0.5, 51, 6.0, 3.6, lambda x, y, z: GL if (x + y) % 4 == 0 else GM, z0=-1, z1=2)
    # корона: три зубца с камнями
    for (x, h) in ((-3, 3), (0.5, 5), (4, 3)):
        for k in range(h):
            for xx in (int(math.floor(x)), int(math.floor(x)) + 1):
                put(v, xx, 57 + k, 0, GM); put(v, xx, 57 + k, 1, GM)
    v = finish(v)
    # скважина: круг + клин, светится
    for x in range(-3, 5):
        for y in range(47, 56):
            d = math.hypot(x - 0.5, y - 52.5)
            if d <= 3.5 and (x, y, 0) not in v.v:
                key = (d <= 1.6) or (abs(x - 0.5) <= 0.6 + (52 - y) * 0.25 and y <= 52)
                put(v, x, y, 0, LIT2 if key else LIT)
                put(v, x, y, 1, LIT2 if key else LIT)
    for (x, y) in ((-3, 60), (0, 62), (1, 62), (4, 60)):
        put(v, x, y, 0, LIT2); put(v, x, y, 1, LIT)
    motes(v, [(-7, 47, 0), (8, 55, 1), (-6, 58, 0), (7, 44, 0), (9, 50, 1)], LIT)
    inlay(v, [(1, y) for y in range(28, 36, 2)], LIT)
    return v


WEAPONS = [
    ('apprentice_staff', apprentice_staff, 'common'),
    ('rusted_rod', rusted_rod, 'common'),
    ('ember_staff', ember_staff, 'rare'),
    ('warden_rod', warden_rod, 'rare'),
    ('gate_staff', gate_staff, 'epic'),
    ('beacon_staff', beacon_staff, 'epic'),
    ('gatekeeper_scepter', gatekeeper_scepter, 'legendary'),
]
