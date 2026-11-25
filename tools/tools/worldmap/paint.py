# Покраска карты: море, земля регионов, уступы. Используется build_map.py.
import numpy as np, cv2
from terrain import W, H, fbm, REGIONS

BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0) - 0.5

def bayer(h=H, w=W):
    return np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]

def hexc(s):
    s = s.lstrip('#'); return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))

SEA = dict(deep=(20, 27, 50), sea=(26, 35, 62), sea2=(31, 42, 72), shallow=(38, 60, 96), shallow2=(50, 80, 120),
           wave=(58, 80, 122), foam=(150, 185, 210), foam2=(205, 225, 236))

# земля: 4 тона от тёмного к светлому; face — 3 тона уступа; rim — светлый край
PAL = {
    1: dict(ground=[(70, 57, 50), (86, 70, 59), (101, 83, 68), (118, 96, 76)], face=[(58, 46, 41), (72, 58, 50), (46, 36, 33)], rim=(150, 126, 102)),
    2: dict(ground=[(40, 88, 64), (50, 104, 74), (62, 120, 86), (82, 142, 98)], face=[(36, 66, 54), (46, 80, 64), (27, 50, 42)], rim=(140, 190, 126)),
    3: dict(ground=[(74, 44, 33), (90, 54, 38), (106, 64, 42), (124, 78, 48)], face=[(66, 36, 31), (82, 46, 37), (50, 27, 25)], rim=(170, 110, 64)),
    4: dict(ground=[(34, 31, 39), (44, 40, 50), (55, 50, 63), (68, 62, 77)], face=[(32, 29, 36), (42, 38, 47), (22, 20, 26)], rim=(96, 88, 106)),
    5: dict(ground=[(41, 37, 84), (50, 44, 100), (60, 53, 118), (72, 62, 140)], face=[(35, 31, 72), (45, 40, 90), (26, 23, 55)], rim=(120, 106, 200)),
    9: dict(ground=[(78, 74, 66), (92, 86, 74), (106, 98, 84), (120, 112, 96)], face=[(62, 58, 52), (76, 70, 62), (48, 44, 40)], rim=(150, 140, 120)),
}

def quantize(n, pal, dither, amount=0.22):
    k = len(pal)
    idx = np.clip(((n + dither * amount) * k).astype(int), 0, k - 1)
    out = np.zeros(n.shape + (3,), np.uint8)
    for i, c in enumerate(pal):
        out[idx == i] = c
    return out, idx

def face_thickness(la, lb):
    if lb == 0:
        return 4 + (la + 1) // 2
    return 3 + 2 * (la - lb)

def faces(t):
    """Уступы: каждая колонка сверху вниз; ниже края высокого плато — его стена."""
    land, region, level = t['land'], t['region'], t['level']
    face_region = np.zeros((H, W), np.int8)   # чей уступ
    face_pos = np.zeros((H, W), np.int8)      # строка уступа сверху (0..T-1)
    face_len = np.zeros((H, W), np.int8)
    for x in range(W):
        y = 0
        while y < H - 1:
            la = level[y, x] if land[y, x] else 0
            lb = level[y + 1, x] if land[y + 1, x] else 0
            if la > lb and la > 0:
                T = face_thickness(la, lb)
                ra = region[y, x]
                for d in range(T):
                    yy = y + 1 + d
                    if yy >= H:
                        break
                    lc = level[yy, x] if land[yy, x] else 0
                    if lc >= la:
                        break
                    face_region[yy, x] = ra; face_pos[yy, x] = d; face_len[yy, x] = T
                y += 1
            else:
                y += 1
    return face_region, face_pos, face_len

def paint_sea(t, rng):
    land = t['land']
    n = fbm(W, H, 22, rng, 3)
    d = bayer()
    img, _ = quantize(n * 0.9 + 0.05, [SEA['deep'], SEA['sea'], SEA['sea'], SEA['sea2']], d, 0.35)
    return img

def paint_ground(t, rng):
    region = t['region']
    img = np.zeros((H, W, 3), np.uint8)
    d = bayer()
    for k, pal in PAL.items():
        n = fbm(W, H, 9, rng, 3) * 0.75 + rng.random((H, W)) * 0.25
        tex, _ = quantize(n * 1.1 - 0.05, pal['ground'], d, 0.3)
        m = region == k
        img[m] = tex[m]
    return img

def lighten(c, f):
    return tuple(int(min(255, v + (255 - v) * f)) for v in c)

def darken(c, f):
    return tuple(int(v * (1 - f)) for v in c)

def finish_relief(t, img, rng):
    """Стены уступов, светлый край плато, тени, мелководье и пена."""
    land, region, level = t['land'], t['region'], t['level']
    fr, fp, fl = faces(t)
    t['face_region'], t['face_pos'], t['face_len'] = fr, fp, fl
    solid = land | (fr > 0)
    # мелководье и пена вокруг суши и стен
    k3 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    d1 = cv2.dilate(solid.astype(np.uint8), k3, iterations=1).astype(bool) & ~solid
    d2 = cv2.dilate(solid.astype(np.uint8), k3, iterations=3).astype(bool) & ~solid & ~d1
    d3 = cv2.dilate(solid.astype(np.uint8), k3, iterations=6).astype(bool) & ~solid & ~d1 & ~d2
    by = bayer()
    yy, xx = np.mgrid[0:H, 0:W]
    m = d3 & (by > 0.05); img[m] = SEA['sea2']
    img[d2] = SEA['shallow']
    m = d2 & (by > 0.25); img[m] = SEA['shallow2']
    img[d1] = SEA['shallow2']
    foam = d1 & (((xx + yy * 2) % 5) != 0)
    img[foam] = SEA['foam']
    m = d1 & (((xx * 3 + yy) % 7) == 0); img[m] = SEA['foam2']
    # стены
    for k, pal in PAL.items():
        face = pal['face']
        ys, xs = np.nonzero(fr == k)
        for y, x in zip(ys, xs):
            p, L = fp[y, x], fl[y, x]
            h = (x * 73 + (x // 2) * 31) % 9
            c = face[1] if h < 5 else face[0]
            if h == 8:
                c = face[2]
            if p == 0:
                c = lighten(face[1], 0.12)
            elif p >= L - 1:
                c = face[2]
            elif L >= 7 and p == L // 2:
                c = face[2] if (x % 3) else face[0]
            img[y, x] = c
    # светлый край: верх плато над своей стеной и северные края
    top = land & (fr == 0)
    south_is_face = np.zeros((H, W), bool); south_is_face[:-1] = (fr[1:] > 0) & top[:-1]
    north_lower = np.zeros((H, W), bool)
    lv = np.where(land, level, 0)
    north_lower[1:] = top[1:] & (lv[:-1] < lv[1:]) & (fr[:-1] == 0)
    for k, pal in PAL.items():
        mk = region == k
        img[(south_is_face | north_lower) & mk] = pal['rim']
    # тень под стеной на нижней земле
    bottom = np.zeros((H, W), bool)
    bottom[1:] = (fr[:-1] > 0) & (fr[1:] == 0)
    shade = bottom.copy(); shade[1:] |= bottom[:-1] & (by[1:] > 0)
    for y, x in zip(*np.nonzero(shade & land)):
        img[y, x] = darken(tuple(img[y, x]), 0.28)
    # боковые границы: тёмная линия на нижней стороне
    for dx in (-1, 1):
        nb = np.roll(lv, dx, 1)
        edge = top & (nb > lv) & (np.roll(fr, dx, 1) == 0)
        for y, x in zip(*np.nonzero(edge)):
            img[y, x] = darken(tuple(img[y, x]), 0.35)
    return img
