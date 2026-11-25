"""Посохи этажа 5 «Архив»: перо, страницы, песочные часы, фолиант, часы, Хронист, чернила, Память.
Неон — по стилю снаряда: ink, page, sand, arcane, time, memory."""
import math
from staffs_common import *

PA1, PA2, PA3 = '#A89870', '#CDBE9A', '#E8DCC0'                 # пергамент
BK1, BK2, BK3 = '#3A1A1E', '#5A2A2A', '#7A3A3A'                  # кожа переплёта
IK1, IK2, IK3 = '#14122A', '#2A2650', '#4A44A0'                  # чернила
SV1, SV2, SV3 = '#6A7080', '#A0A8B8', '#D8DEE8'                  # серебро
FW1, FW2 = '#D8D4CC', '#F4F2EC'                                  # перо: светлое

INK, INK2 = '!#6A58D8', '!#D2C4FF'
PAGE, PAGE2 = '!#EFE6CC', '!#FFFFF4'
SAND, SAND2 = '!#FFD98A', '!#FFF8DE'
ARC, ARC2 = '!#8C6CFF', '!#F0EBFF'
TIME, TIME2 = '!#6FE3FF', '!#F2FFFF'
MEM, MEM2, MEM3 = '!#6FE3FF', '!#FFFFFF', '!#B49CFF'

shades({PA3: PA2, PA2: PA1, PA1: BRD, BK3: BK2, BK2: BK1, BK1: OUT, IK3: IK2, IK2: IK1, IK1: OUT,
        SV3: SV2, SV2: SV1, SV1: OUT, FW2: FW1, FW1: SV2})


def feather(v, x0, y0, z, dx, dy, length, width, c1=FW2, c2=FW1, rachis=PA1, side=0):
    """Перо в плоскости XY: стержень и опахало (side: 0 — с обеих сторон, ±1 — одна сторона)."""
    n = math.hypot(dx, dy) or 1
    ux, uy = dx / n, dy / n
    px, py = -uy, ux

    def fn(t, s):
        w = width * math.sin(math.pi * min(1.0, t * 1.15)) * (0.6 + 0.4 * t)
        if side:
            off = s * w * side
        else:
            off = (s - 0.5) * 2 * w
        bendk = 0.12 * length * t * t
        return (x0 + ux * length * t + px * (off + bendk), y0 + uy * length * t + py * (off + bendk), z)
    sheet(v, fn, int(length * 3), int(width * 4), lambda t, s: rachis if (abs(s - (0.0 if side else 0.5)) < 0.08) else
          (c2 if int(t * length * 1.2) % 3 == 0 else c1))


def quill_wand():
    """Перо-жезл: древко с латунным пером-наконечником, с кончика — светящаяся капля чернил, сбоку привязано перо."""
    v = staff_vox()
    pole(v, 0, 46, wood(BK2, BK1, seed=17))
    ferrule(v, 0, BR, BRL)
    wrap(v, 19, 26, IK2, IK1)
    band(v, 44, 46, 1.4, BR)
    # латунное перо: клин, сходящийся к острию, с прорезью
    for y in range(47, 57):
        t = (y - 47) / 9
        hw = 2.2 * (1 - t) + 0.3
        for x in range(-3, 5):
            if abs(x - 0.5) <= hw:
                for z in (0, 1):
                    if not (x in (0, 1) and y > 50 and z == 1):
                        put(v, x, y, z, GL if x > 0.5 + hw - 1 else GM)
    v = finish(v)
    feather(v, 1.5, 34, 2, 0.35, 1, 16, 3.2, side=1)
    put(v, 0, 51, 1, INK); put(v, 1, 51, 1, INK)
    teardrop(v, 0.5, 58.6, 0.5, 1.1, 1.8, lambda x, y, z, t: INK2 if t < 0.3 else INK)
    return v


def page_staff():
    """Посох страниц: на вершине — свиток на поперечной оси, из него веером вылетают светящиеся страницы."""
    v = staff_vox()
    pole(v, 0, 44, wood(WM, WD, seed=18))
    ferrule(v, 0, BR, BRL)
    wrap(v, 19, 26, BK2, BK1)
    band(v, 42, 44, 1.5, BR)
    # крепление и свиток вдоль X
    box(v, 0, 1, 45, 47, 0, 1, BR)
    for x in range(-5, 7):
        for y in range(47, 52):
            for z in range(-2, 4):
                if math.hypot(y - 49.2, z - 0.5) <= 2.3:
                    put(v, x, y, z, BRL if x in (-5, 6) else (PA3 if (y + z) % 3 else PA2))
    for x in (-6, 7):
        band(v, 49, 49, 1.0, BR, cx=x, cz=0.5)
    # лист свитка свисает назад
    for x in range(-4, 6):
        for y in range(42, 48):
            put(v, x, y, -2, PA2 if (x + y) % 4 else PA1)
    v = finish(v)
    # страницы веером
    for i, (ang, dist) in enumerate(((-55, 6.0), (-20, 7.0), (15, 7.2), (50, 6.2))):
        a = math.radians(ang + 90)
        cx, cy = 0.5 + math.cos(a) * dist, 50 + math.sin(a) * dist
        for dx in range(-1, 3):
            for dy in range(-2, 2):
                xx = cx + dx * math.cos(a - math.pi / 2) - dy * math.sin(a - math.pi / 2) * 0.3
                yy = cy + dy + dx * 0.25
                put(v, rnd(xx), rnd(yy), (i % 2), PAGE2 if (dx + dy) % 3 == 0 else PAGE)
    for (x, y, z) in ((-1, 52, 3), (2, 53, -2)):
        put(v, x, y, z, PAGE)
    return v


def hourglass_rod():
    """Жезл песочных часов: латунная рама на трёх стойках, светящийся песок сыплется в нижнюю колбу."""
    v = staff_vox()
    pole(v, 0, 43, lambda x, y, z: BK2 if (y // 3) % 2 else BK3)
    ferrule(v, 0, BR, BRL)
    wrap(v, 19, 26, BRD, BR)
    band(v, 42, 43, 2.0, BR)
    for y in (44, 58):
        band(v, y, y + 1, 3.6, lambda x, yy, z: BRL if math.hypot(x - 0.5, z - 0.5) > 2.6 else BR)
    for i in range(3):
        a = i * 2 * math.pi / 3 + 0.5
        x, z = 0.5 + math.cos(a) * 3.0, 0.5 + math.sin(a) * 3.0
        rod(v, [(x, 46, z), (x, 57, z)], BRD, seg=lambda ii, f: BRL if 0.45 < f < 0.55 else BRD)
    put(v, 0, 60, 0, BRL); put(v, 1, 60, 1, BRL)
    v = finish(v)
    # колбы: стекло не рисуем (в Roblox — прозрачная часть), только песок
    for y in range(46, 58):
        t = abs(y - 51.5) / 5.5
        r = 2.4 * t + 0.4
        for x in range(-3, 5):
            for z in range(-3, 5):
                d = math.hypot(x - 0.5, z - 0.5)
                if y <= 50 and d <= r and y <= 49:
                    put(v, x, y, z, SAND if (x + y + z) % 3 else SAND2)
                elif y >= 54 and d <= r * 0.75 and y <= 55:
                    put(v, x, y, z, SAND)
    for y in range(50, 54):
        put(v, 0, y, 0, SAND2)
    return v


def tome_staff():
    """Посох фолианта: раскрытая книга парит над латунной подставкой, над страницами — кольцо тайных рун."""
    v = staff_vox()
    pole(v, 0, 44, wood(DWL, DWM, seed=19))
    ferrule(v, 0, BR, BRL)
    wrap(v, 19, 26, PD, PM)
    band(v, 40, 41, 1.5, BR)
    # подставка-аналой
    for side in (-1, 1):
        rod(v, [(0.5, 43, 0.5), (0.5 + side * 4.0, 46, 0.5)], BR, cube=2)
    # книга: две створки буквой V вдоль X, корешок по Z
    for side in (-1, 1):
        for k in range(8):
            x = 0.5 + side * (0.6 + k)
            y0 = 47 + k * 0.45
            for z in range(-3, 5):
                put(v, rnd(x), rnd(y0), z, BK2 if z in (-3, 4) or k == 7 else BK3)
                if k < 7 and -2 <= z <= 3:
                    put(v, rnd(x), rnd(y0) + 1, z, PA3 if (k + z) % 3 else PA2)
    v = finish(v)
    for side in (-1, 1):
        for k in (2, 4, 6):
            put(v, rnd(0.5 + side * (0.6 + k)), rnd(47 + k * 0.45) + 1, 0, ARC)
    ring_xz(v, 56, 5.2, 4.4, lambda x, y, z: ARC if (x + z) % 3 else ARC2)
    orb(v, 0.5, 54.0, 0.5, 1.6, ARC, ARC2)
    return v


def clock_staff():
    """Часовой посох: циферблат с зубчатым ободом и светящимися стрелками, колокольчик наверху, маятник."""
    v = staff_vox()
    pole(v, 0, 43, lambda x, y, z: SV2 if (y // 2) % 3 else SV1)
    ferrule(v, 0, BR, BRL)
    wrap(v, 19, 26, BK2, BK1)
    band(v, 41, 43, 1.6, BR)
    cy = 51.0
    for x in range(-8, 10):
        for y in range(42, 61):
            d = math.hypot(x - 0.5, y - cy)
            a = math.atan2(y - cy, x - 0.5)
            if d <= 6.0:
                for z in (0, 1):
                    put(v, x, y, z, PA3 if d < 5.0 else BR)
            elif d <= 7.0 and math.cos(a * 12) > 0.2:
                for z in (0, 1):
                    put(v, x, y, z, BRL)
    # деления
    for k in range(12):
        a = k * math.pi / 6
        put(v, rnd(0.5 + math.cos(a) * 4.2), rnd(cy + math.sin(a) * 4.2), 2, BK2 if k % 3 else IK2)
        put(v, rnd(0.5 + math.cos(a) * 4.2), rnd(cy + math.sin(a) * 4.2), -1, BK2 if k % 3 else IK2)
    # колокол
    for k, y in enumerate(range(58, 62)):
        band(v, y, y, 2.0 - k * 0.4, BRL if k % 2 else BR)
    v = finish(v)
    for z in (2, -1):
        rod(v, [(0.5, cy, z), (0.5 + 3.4 * math.cos(math.radians(60)), cy + 3.4 * math.sin(math.radians(60)), z)], TIME)
        rod(v, [(0.5, cy, z), (0.5 + 2.4 * math.cos(math.radians(-30)), cy + 2.4 * math.sin(math.radians(-30)), z)], TIME)
        put(v, 0, rnd(cy), z, TIME2)
    # маятник под циферблатом
    rod(v, [(0.5, 44, 2), (2.5, 39, 2)], SV3)
    sphere(v, 2.8, 38.2, 2, 1.1, TIME)
    return v


def chronicler_staff():
    """Посох Хрониста: чернильница-навершие с огромным пером, лента свитка по древку, светящиеся строки."""
    v = staff_vox()
    pole(v, 0, 44, wood(BK2, BK1, seed=20))
    ferrule(v, 0, SV2, SV3)
    wrap(v, 18, 26, IK2, SV2)
    for y in (12, 30):
        band(v, y, y + 1, 1.5, SV3)
    # чернильница: серебряная банка с горлом
    for k, y in enumerate(range(43, 50)):
        r = 3.6 if k < 5 else 2.0
        band(v, y, y, r, SV2 if k % 3 else SV3)
    v = finish(v)
    for x in range(-1, 3):
        for z in range(-1, 3):
            if math.hypot(x - 0.5, z - 0.5) <= 1.5:
                put(v, x, 50, z, INK)
    # огромное перо из чернильницы наискось
    rod(v, [(0.5, 47, 0.5), (3.5, 62, 0.5)], PA1)
    feather(v, 1.3, 51, 0, 0.21, 1, 13, 3.6, c1=FW2, c2=IK3)
    # лента свитка винтом по древку
    for i in range(70):
        t = i / 70
        a = t * 3 * 2 * math.pi
        y = 28 + t * 14
        for dy in (0, 1):
            setc(v, 0.5 + 1.8 * math.cos(a), y + dy, 0.5 + 1.8 * math.sin(a), PA3 if dy == 0 else PA2)
    for i in range(0, 70, 6):
        t = i / 70
        a = t * 3 * 2 * math.pi
        setc(v, 0.5 + 2.2 * math.cos(a), 28 + t * 14, 0.5 + 2.2 * math.sin(a), INK)
    motes(v, [(-4, 56, 0), (5, 52, 1), (-2, 61, 0), (7, 60, 1)], INK, None)
    return v


def ink_scepter():
    """Чернильный скипетр: чёрное серебро, когти держат пульсирующую кляксу чернил, капли стекают по древку."""
    v = staff_vox()
    pole(v, 0, 44, lambda x, y, z: IK2 if (y // 2) % 3 else IK1)
    ferrule(v, 0, SV2, SV3)
    wrap(v, 18, 26, SV1, IK2)
    for y in (14, 32):
        band(v, y, y + 1, 1.5, SV2)
    band(v, 42, 44, 2.0, SV2)
    prongs(v, 44, 57, 4, 2.2, 4.4, SV2, phase=math.pi / 4, curl=1.3, tip=SV3)
    v = finish(v)
    # клякса: шар с выростами-щупальцами
    sphere(v, 0.5, 51, 0.5, 3.2, lambda x, y, z, d: INK2 if d < 0.4 else INK)
    for i in range(6):
        a = i * math.pi / 3 + 0.3
        rod(v, [(0.5 + math.cos(a) * 2.8, 51 + math.sin(i * 1.7) * 1.5, 0.5 + math.sin(a) * 2.8),
                (0.5 + math.cos(a) * 4.8, 51 + math.sin(i * 1.7) * 3.0, 0.5 + math.sin(a) * 4.8)], INK)
    for (x, z, y0, h) in ((1, 2, 44, 5), (-1, 0, 41, 4), (2, -1, 36, 3)):
        for k in range(h):
            put(v, x, y0 - k, z, INK)
    motes(v, [(-5, 57, 0), (6, 58, 1), (0, 60, 3)], INK)
    return v


def memory_staff():
    """Посох Памяти: светлое серебро в голубых прожилках, нимб, вокруг сияющего шара памяти кружат осколки-воспоминания."""
    v = staff_vox()
    pole(v, 0, 44, lambda x, y, z: SV3 if (y // 2) % 3 else SV2)
    ferrule(v, 0, SV2, SV3)
    wrap(v, 18, 26, PM, PL)
    for y in (12, 30, 38):
        band(v, y, y + 1, 1.5, SV3)
    # чаша-оправа из лепестков-лезвий
    for i in range(6):
        petal(v, 0.5, 44, 0.5, i * 60 + 30, 5.0, 2.2, 40, 75, lambda t, s: SV3 if t > 0.6 else SV2, r0=1.0)
    v = finish(v)
    orb(v, 0.5, 51, 0.5, 2.8, MEM, MEM2)
    # нимб над шаром и осколки-воспоминания по кругу (наклонены наружу)
    ring_xz(v, 57, 4.2, 3.2, MEM3)
    for i in range(5):
        a = i * 2 * math.pi / 5 + 0.25
        x, z = 0.5 + math.cos(a) * 6.3, 0.5 + math.sin(a) * 6.3
        y0 = (45, 50, 47, 53, 48)[i]
        crystal(v, x, y0, y0 + 5, 1.0, MEM3 if i % 2 else MEM, None, tx=math.cos(a) * 0.2, tz=math.sin(a) * 0.2)
    inlay(v, [(0, y) for y in range(28, 44, 2)] + [(1, y) for y in range(4, 16, 3)], MEM)
    motes(v, [(-7, 59, 0), (8, 61, 1), (1, 63, 0)], MEM2)
    return v


WEAPONS = [
    ('quill_wand', quill_wand, 'common'),
    ('page_staff', page_staff, 'rare'),
    ('hourglass_rod', hourglass_rod, 'rare'),
    ('tome_staff', tome_staff, 'epic'),
    ('clock_staff', clock_staff, 'epic'),
    ('chronicler_staff', chronicler_staff, 'legendary'),
    ('ink_scepter', ink_scepter, 'legendary'),
    ('memory_staff', memory_staff, 'secret'),
]
GUARD = {'quill_wand': 46, 'page_staff': 45, 'clock_staff': 44, 'chronicler_staff': 43, 'tome_staff': 45}
FOCUS = {'quill_wand': (0, 58, 0), 'page_staff': (0, 52, 0), 'hourglass_rod': (0, 51, 0), 'clock_staff': (0, 51, 0),
         'chronicler_staff': (0, 51, 0), 'tome_staff': (0, 54, 0)}
