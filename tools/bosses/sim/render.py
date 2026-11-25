#!/usr/bin/env python3
# Раскадровка сцен: простой растеризатор деталей (z-буфер, неон с ореолом).
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 480, 270
FONT = "/usr/share/fonts/liberation-sans/LiberationSans-Bold.ttf"
import glob
cands = glob.glob("/usr/share/fonts/**/LiberationSans-Bold.ttf", recursive=True) + glob.glob("/usr/share/fonts/**/NotoSans-Bold.ttf", recursive=True)
FONT = cands[0] if cands else None
LIGHT = np.array([-0.4, 0.85, 0.45]); LIGHT /= np.linalg.norm(LIGHT)

def mesh(shape, sx, sy, sz):
    if shape == "Cylinder":
        n = 14; r = min(sy, sz) / 2; L = sx / 2
        tris = []
        for i in range(n):
            a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
            p0 = (math.cos(a0) * r, math.sin(a0) * r); p1 = (math.cos(a1) * r, math.sin(a1) * r)
            A = (-L, p0[0], p0[1]); Bv = (L, p0[0], p0[1]); C = (L, p1[0], p1[1]); D = (-L, p1[0], p1[1])
            tris += [(A, Bv, C), (A, C, D), ((L, 0, 0), Bv, C), ((-L, 0, 0), D, A)]
        return np.array(tris, dtype=float)
    if shape == "Ball":
        r = min(sx, sy, sz) / 2; n, m = 10, 7
        tris = []
        def pt(i, j):
            th = math.pi * j / m; ph = 2 * math.pi * i / n
            return (r * math.sin(th) * math.cos(ph), r * math.cos(th), r * math.sin(th) * math.sin(ph))
        for i in range(n):
            for j in range(m):
                a, b, c, d = pt(i, j), pt(i + 1, j), pt(i + 1, j + 1), pt(i, j + 1)
                tris += [(a, b, c), (a, c, d)]
        return np.array(tris, dtype=float)
    x, y, z = sx / 2, sy / 2, sz / 2
    v = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z), (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
    f = [(0, 1, 2), (0, 2, 3), (4, 6, 5), (4, 7, 6), (0, 4, 5), (0, 5, 1), (3, 2, 6), (3, 6, 7), (0, 3, 7), (0, 7, 4), (1, 5, 6), (1, 6, 2)]
    return np.array([[v[a], v[b], v[c]] for a, b, c in f], dtype=float)

def render(fr):
    c = fr["cam"]; cp = np.array(c[0:3])
    M = np.array(c[3:12]).reshape(3, 3)
    right, up, back = M[:, 0], M[:, 1], M[:, 2]
    fov = math.radians(fr["fov"]); f = 1 / math.tan(fov / 2) * H / 2
    img = np.zeros((H, W, 3)); z = np.full((H, W), 1e9)
    # фон
    yy = np.linspace(0, 1, H)[:, None]
    img[:] = (np.array([0.05, 0.05, 0.07]) * (1 - yy) + np.array([0.12, 0.11, 0.12]) * yy)[:, :, None].transpose(0, 2, 1) if False else 0
    for i in range(H):
        k = i / H
        img[i, :] = np.array([0.06, 0.06, 0.08]) * (1 - k) + np.array([0.13, 0.12, 0.13]) * k
    # пол: плоскость y = B.y, клетка 4 стада
    By = fr["B"][1]
    px, py = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
    dx = (px - W / 2) / f; dy = -(py - H / 2) / f
    dirs = right[None, None, :] * dx[..., None] + up[None, None, :] * dy[..., None] - back[None, None, :]
    t = (By - cp[1]) / np.where(np.abs(dirs[..., 1]) < 1e-6, -1e-6, dirs[..., 1])
    hit = t > 0
    P = cp[None, None, :] + dirs * t[..., None]
    chk = ((np.floor(P[..., 0] / 4) + np.floor(P[..., 2] / 4)) % 2 == 0)
    dist = np.linalg.norm(P - cp, axis=2)
    fog = np.clip(dist / 90, 0, 1)[..., None]
    floor = np.where(chk[..., None], np.array([0.24, 0.22, 0.21]), np.array([0.2, 0.19, 0.18]))
    floor = floor * (1 - fog) + img * fog
    img = np.where(hit[..., None], floor, img)
    z = np.where(hit, t, z)  # t ~ глубина вдоль оси (dirs имеет -back единичную компоненту)
    glow = np.zeros((H, W, 3))
    trans = []
    for p in fr["parts"]:
        shape, sx, sy, sz = p[0], p[1], p[2], p[3]
        pos = np.array(p[4:7]); R = np.array(p[7:16]).reshape(3, 3)
        col = np.array(p[16:19]); tr = p[19]; neon = p[20]
        tris = mesh(shape, sx, sy, sz) @ R.T + pos
        if tr < 0.05:
            raster(tris, col, neon, 1.0, img, z, glow, cp, right, up, back, f, True)
        else:
            trans.append((tris, col, neon, 1 - tr))
    for tris, col, neon, a in trans:
        raster(tris, col, neon, a, img, z, glow, cp, right, up, back, f, False)
    g = Image.fromarray((np.clip(glow, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5))
    img = np.clip(img + np.asarray(g) / 255 * 0.9, 0, 1)
    return Image.fromarray((img * 255).astype(np.uint8))

def raster(tris, col, neon, alpha, img, z, glow, cp, right, up, back, f, zwrite):
    d = tris - cp
    xc = d @ right; yc = d @ up; zc = -(d @ back)
    for i in range(len(tris)):
        zz = zc[i]
        if zz.min() < 0.2:
            continue
        sx = W / 2 + xc[i] / zz * f; sy = H / 2 - yc[i] / zz * f
        x0, x1 = int(max(min(sx.min(), W), 0)), int(min(max(sx.max(), 0), W - 1)) + 1
        y0, y1 = int(max(min(sy.min(), H), 0)), int(min(max(sy.max(), 0), H - 1)) + 1
        if x0 >= x1 or y0 >= y1:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        (ax, bx, cx), (ay, by, cy) = sx, sy
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9:
            continue
        w0 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
        w1 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den
        w2 = 1 - w0 - w1
        inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
        if not inside.any():
            continue
        depth = 1 / (w0 / zz[0] + w1 / zz[1] + w2 / zz[2])
        zs = z[y0:y1, x0:x1]
        m = inside & (depth < zs)
        if not m.any():
            continue
        n = np.cross(tris[i][1] - tris[i][0], tris[i][2] - tris[i][0])
        nl = np.linalg.norm(n)
        n = n / nl if nl > 0 else n
        if np.dot(n, cp - tris[i][0]) < 0:
            n = -n
        shade = 1.0 if neon else 0.32 + 0.68 * max(0.0, float(np.dot(n, LIGHT)))
        c = np.clip(col * shade * (1.25 if neon else 1.0), 0, 1)
        reg = img[y0:y1, x0:x1]
        reg[m] = reg[m] * (1 - alpha) + c * alpha
        if neon:
            glow[y0:y1, x0:x1][m] = np.maximum(glow[y0:y1, x0:x1][m], col * alpha)
        if zwrite:
            zs[m] = depth[m]

def overlay(im, fr):
    d = ImageDraw.Draw(im)
    bar = int(H * 0.137)
    if fr["bars"]:
        d.rectangle([0, 0, W, bar], fill=(20, 15, 13)); d.rectangle([0, H - bar, W, H], fill=(20, 15, 13))
    if FONT:
        if fr["quote"]:
            fq = ImageFont.truetype(FONT, 11)
            tc = tuple(int(v * 255) for v in fr["titleColor"])
            tw = d.textlength(fr["quote"], font=fq)
            d.text(((W - tw) / 2, H - bar / 2 - 7), fr["quote"], font=fq, fill=tc)
        if fr["name"]:
            fn = ImageFont.truetype(FONT, 24); ft = ImageFont.truetype(FONT, 10)
            nc = tuple(int(v * 255) for v in fr["nameColor"]); lc = tuple(int(v * 255) for v in fr["lineColor"]); tc = tuple(int(v * 255) for v in fr["titleColor"])
            tw = d.textlength(fr["name"], font=fn)
            y = H - bar - 52
            d.text(((W - tw) / 2, y + 14), fr["name"], font=fn, fill=nc, stroke_width=2, stroke_fill=(0, 0, 0))
            tw2 = d.textlength(fr["title"], font=ft)
            d.text(((W - tw2) / 2, y), fr["title"], font=ft, fill=tc)
            d.rectangle([W / 2 - 130, y + 45, W / 2 + 130, y + 47], fill=lc)
        fs = ImageFont.truetype(FONT, 11)
        d.text((6, 4 if not fr["bars"] else bar + 4), "τ %.1f" % fr["tau"], font=fs, fill=(255, 255, 255))

frames = [json.loads(l) for l in open(sys.argv[1]) if l.startswith("{")]
by = {}
for fr in frames:
    by.setdefault(fr["boss"], []).append(fr)
for boss, lst in by.items():
    cols = 4; rows = math.ceil(len(lst) / cols)
    sheet = Image.new("RGB", (cols * W + (cols + 1) * 6, rows * H + (rows + 1) * 6 + 30), (12, 12, 14))
    dd = ImageDraw.Draw(sheet)
    if FONT:
        dd.text((8, 6), boss, font=ImageFont.truetype(FONT, 18), fill=(240, 230, 210))
    for i, fr in enumerate(lst):
        im = render(fr); overlay(im, fr)
        sheet.paste(im, (6 + (i % cols) * (W + 6), 36 + (i // cols) * (H + 6)))
    sheet.save(os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "sheet_%s.png" % boss))
    print("ok", boss, len(lst))
