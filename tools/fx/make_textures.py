"""Текстуры эффектов способностей (ReplicatedStorage.FX).

Все текстуры белые/серые с альфой: цвет задаётся в Studio (Color у
ParticleEmitter/Beam/Trail), поэтому одну текстуру можно красить как угодно.

    python make_textures.py [папка]     # по умолчанию ./textures

Загрузка в Roblox — upload_image (см. README.md рядом), id — в BuildFx.lua.
"""

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "textures")
rng = np.random.default_rng(7)


def grid(n, m=None):
    m = m or n
    y, x = np.mgrid[0:m, 0:n].astype(np.float32)
    return (x + 0.5) / n * 2 - 1, (y + 0.5) / m * 2 - 1  # -1..1


def save(name, alpha, value=None):
    """alpha, value: float-массивы 0..1. value — яркость (по умолчанию 1)."""
    a = np.clip(alpha, 0, 1)
    v = np.ones_like(a) if value is None else np.clip(value, 0, 1)
    rgba = np.stack([v, v, v, a], axis=-1)
    Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"))
    print("  " + name)


def fbm(n, m=None, octaves=5, base=4, tile_x=False):
    """Фрактальный шум 0..1 (тайлится по X, если tile_x)."""
    m = m or n
    total = np.zeros((m, n), np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        cells = base * 2**o
        cx = cells
        cy = max(2, int(round(cells * m / n)))
        g = rng.random((cy + 1, cx + 1)).astype(np.float32)
        if tile_x:
            g[:, -1] = g[:, 0]
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((n, m), Image.BICUBIC)
        total += np.asarray(img, np.float32) / 255 * amp
        norm += amp
        amp *= 0.5
    return total / norm


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# ===== Общие =====

def glow():
    x, y = grid(256)
    r = np.sqrt(x * x + y * y)
    a = np.exp(-(r**2) * 5.5) * (1 - smooth(0.85, 1.0, r))
    save("glow", a)


def spark():
    # Вертикальный штрих: ориентация VelocityParallel тянет его по скорости.
    x, y = grid(128, 256)
    core = np.exp(-(x / 0.10) ** 2) * np.exp(-(y / 0.75) ** 2)
    halo = np.exp(-(x / 0.35) ** 2) * np.exp(-(y / 0.95) ** 2) * 0.35
    save("spark", core + halo)


def star():
    x, y = grid(256)
    r = np.sqrt(x * x + y * y)
    rays = np.exp(-np.abs(x) * 26) * np.exp(-np.abs(y) * 2.6) + np.exp(-np.abs(y) * 26) * np.exp(-np.abs(x) * 2.6)
    diag = (np.exp(-np.abs(x - y) * 30) + np.exp(-np.abs(x + y) * 30)) * np.exp(-r * 4.5) * 0.45
    core = np.exp(-(r**2) * 40)
    a = (rays + diag + core) * (1 - smooth(0.9, 1.0, r))
    save("star", a)


def ring():
    # Ударная волна: яркая кромка, мягкое свечение внутрь.
    x, y = grid(512)
    r = np.sqrt(x * x + y * y)
    edge = np.exp(-((r - 0.9) / 0.035) ** 2)
    inner = smooth(0.35, 0.9, r) * (1 - smooth(0.9, 0.93, r)) * 0.35
    save("ring", edge + inner)


def smoke():
    x, y = grid(256)
    r = np.sqrt(x * x + y * y)
    n = fbm(256, octaves=5, base=3)
    a = (1 - smooth(0.25, 1.0, r + (n - 0.5) * 0.55)) * (0.55 + 0.45 * n)
    a *= 1 - smooth(0.8, 0.98, r)  # к краю картинки — ноль, иначе у больших частиц видны рамки
    v = 0.75 + 0.25 * n
    save("smoke", a, v)


def rock():
    # Осколок камня: неровный многоугольник с гранями.
    s = 256
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = []
    k = 7
    for i in range(k):
        ang = i / k * math.tau + rng.uniform(-0.25, 0.25)
        rad = rng.uniform(0.62, 0.92) * s / 2
        pts.append((s / 2 + math.cos(ang) * rad, s / 2 + math.sin(ang) * rad))
    for i in range(k):
        shade = int(150 + 100 * (0.5 + 0.5 * math.cos(i / k * math.tau - 0.8)))
        d.polygon([(s / 2, s / 2), pts[i], pts[(i + 1) % k]], fill=(shade, shade, shade, 255))
    img.save(os.path.join(OUT, "rock.png"))
    print("  rock")


# ===== Вихрь =====

def swirl():
    # Три рукава спирали, сходятся к центру; ярче у центра.
    x, y = grid(512)
    r = np.sqrt(x * x + y * y) + 1e-6
    th = np.arctan2(y, x)
    arms = 3
    phase = th * arms + np.log(r) * 7.0
    band = np.cos(phase) * 0.5 + 0.5
    band = band**6
    fade = (1 - smooth(0.7, 1.0, r)) * smooth(0.03, 0.18, r)
    n = fbm(512, octaves=4, base=4)
    a = band * fade * (0.6 + 0.6 * n) + np.exp(-(r**2) * 30) * 0.5
    save("swirl", a)


def wind():
    # Полоса ветра вдоль U (для Beam-рукавов воронки), тайлится по X.
    w, h = 512, 128
    n = fbm(w, h, octaves=4, base=6, tile_x=True)
    _, y = grid(w, h)
    streak = np.exp(-(y / 0.45) ** 2)
    lines = smooth(0.45, 0.8, n)
    save("wind", streak * (0.25 + 0.9 * lines))


def slash():
    # Серп: тонкий полумесяц, яркая кромка, хвост гаснет. Выпуклостью вверх
    # (+Y текстуры смотрит по скорости при VelocityParallel).
    x, y = grid(512)
    cy = 0.55
    r1 = np.sqrt(x * x + (y - cy) ** 2)  # внешний круг
    r2 = np.sqrt(x * x + (y - cy - 0.22) ** 2)  # вырез
    outer = 1 - smooth(0.86, 0.9, r1)
    cut = smooth(0.9, 0.96, r2)
    body = outer * cut * (y < 0.45)
    tail = 1 - smooth(0.25, 0.95, np.abs(x))  # концы гаснут
    edge = np.exp(-((r1 - 0.86) / 0.03) ** 2) * (y < 0.45)
    a = np.clip(body * tail * 0.75 + edge * tail, 0, 1)
    a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5)), np.float32) / 255
    save("slash", a)


def trail():
    # Для Trail/Beam: U — вдоль следа (0 — свежий край), V — поперёк.
    w, h = 256, 128
    x, y = grid(w, h)
    u = (x + 1) / 2
    n = fbm(w, h, octaves=4, base=8, tile_x=True)
    across = np.exp(-(y / 0.55) ** 2) + np.exp(-((np.abs(y) - 0.92) / 0.06) ** 2) * 0.6
    streaks = 0.55 + 0.6 * smooth(0.4, 0.75, n)
    save("trail", across * streaks * (1 - u * 0.35))


# ===== Разлом =====

def crack():
    # Тёмная рваная трещина вдоль U (тайлится): края зубчатые.
    w, h = 512, 128
    _, y = grid(w, h)
    n = fbm(w, h, octaves=5, base=6, tile_x=True)
    n2 = fbm(w, h, octaves=4, base=10, tile_x=True)
    half = 0.45 + (n - 0.5) * 0.7
    a = 1 - smooth(half - 0.08, half, np.abs(y + (n2 - 0.5) * 0.25))
    v = 0.18 + 0.25 * n2
    save("crack", a, v)


def magma():
    # Светящаяся сердцевина: течёт по U (TextureSpeed), тайлится.
    w, h = 512, 128
    _, y = grid(w, h)
    n = fbm(w, h, octaves=5, base=5, tile_x=True)
    core = np.exp(-(y / (0.18 + 0.2 * n)) ** 2)
    hot = smooth(0.35, 0.8, n)
    save("magma", core * (0.45 + 0.75 * hot), 0.7 + 0.3 * hot)


# ===== Отпереть =====

def chain():
    # Звенья цепи вдоль U: кольцо плашмя, кольцо ребром; тайлится (2 звена).
    w, h = 512, 128
    s = 4
    img = Image.new("L", (w * s, h * s), 0)
    d = ImageDraw.Draw(img)
    link = w * s / 2
    for i in range(2):
        cx = link * i + link / 2
        # плашмя: овал с дыркой
        d.ellipse([cx - link * 0.42, h * s * 0.18, cx + link * 0.42, h * s * 0.82], fill=235)
        d.ellipse([cx - link * 0.26, h * s * 0.36, cx + link * 0.26, h * s * 0.64], fill=0)
        # ребром: перемычка к следующему
        ex = cx + link / 2
        d.rounded_rectangle([ex - link * 0.2, h * s * 0.42, ex + link * 0.2, h * s * 0.58], radius=int(h * s * 0.08), fill=180)
    img = img.resize((w, h), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.8))
    a = np.asarray(img, np.float32) / 255
    _, y = grid(w, h)
    shade = 0.75 + 0.25 * (1 - np.abs(y))
    save("chain", np.clip(a * 1.3, 0, 1), shade)


def seal():
    # Печать на земле: двойное кольцо, руны, лучи, скважина в центре.
    s = 1024
    img = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(img)
    c = s / 2

    def circle(r, width):
        d.ellipse([c - r, c - r, c + r, c + r], outline=255, width=width)

    circle(s * 0.48, 10)
    circle(s * 0.44, 4)
    circle(s * 0.30, 6)
    circle(s * 0.27, 3)
    # Руны между кольцами.
    glyph_rng = np.random.default_rng(3)
    for i in range(16):
        ang = i / 16 * math.tau
        r = s * 0.37
        gx, gy = c + math.cos(ang) * r, c + math.sin(ang) * r
        for _ in range(3):
            a0 = glyph_rng.uniform(0, math.tau)
            l = s * glyph_rng.uniform(0.012, 0.03)
            ox, oy = glyph_rng.uniform(-1, 1) * s * 0.015, glyph_rng.uniform(-1, 1) * s * 0.015
            d.line(
                [gx + ox, gy + oy, gx + ox + math.cos(a0) * l, gy + oy + math.sin(a0) * l],
                fill=255,
                width=5,
            )
    # Лучи-засечки.
    for i in range(48):
        ang = i / 48 * math.tau
        r0, r1 = s * (0.44 if i % 4 else 0.41), s * 0.48
        d.line([c + math.cos(ang) * r0, c + math.sin(ang) * r0, c + math.cos(ang) * r1, c + math.sin(ang) * r1], fill=255, width=4)
    # Ромбы-«замки» на четырёх сторонах.
    for i in range(4):
        ang = i / 4 * math.tau + math.pi / 4
        px, py = c + math.cos(ang) * s * 0.30, c + math.sin(ang) * s * 0.30
        q = s * 0.03
        d.polygon([(px, py - q), (px + q, py), (px, py + q), (px - q, py)], fill=255)
    # Скважина.
    d.ellipse([c - s * 0.07, c - s * 0.13, c + s * 0.07, c + s * 0.01], fill=255)
    d.polygon([(c - s * 0.04, c - s * 0.02), (c + s * 0.04, c - s * 0.02), (c + s * 0.075, c + s * 0.15), (c - s * 0.075, c + s * 0.15)], fill=255)
    lines = np.asarray(img, np.float32) / 255
    blur = np.asarray(img.filter(ImageFilter.GaussianBlur(14)), np.float32) / 255
    a = np.clip(lines + blur * 0.8, 0, 1)
    save("seal", np.asarray(Image.fromarray((a * 255).astype(np.uint8)).resize((512, 512), Image.LANCZOS), np.float32) / 255)


def keyhole():
    # Значок метки «Скважины» (BillboardGui).
    s = 512
    img = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(img)
    c = s / 2
    d.ellipse([c - s * 0.45, c - s * 0.45, c + s * 0.45, c + s * 0.45], outline=255, width=26)
    d.ellipse([c - s * 0.13, c - s * 0.27, c + s * 0.13, c - s * 0.01], fill=255)
    d.polygon([(c - s * 0.07, c - s * 0.05), (c + s * 0.07, c - s * 0.05), (c + s * 0.14, c + s * 0.28), (c - s * 0.14, c + s * 0.28)], fill=255)
    lines = np.asarray(img, np.float32) / 255
    blur = np.asarray(img.filter(ImageFilter.GaussianBlur(10)), np.float32) / 255
    a = np.clip(lines + blur * 0.6, 0, 1)
    save("keyhole", np.asarray(Image.fromarray((a * 255).astype(np.uint8)).resize((256, 256), Image.LANCZOS), np.float32) / 255)


# ===== Враги =====

def chevron():
    # Шевроны «>» вдоль U (стрелка рывка, коридор выстрела), два на тайл.
    w, h = 256, 128
    x, y = grid(w, h)
    u = ((x + 1) / 2 * 2) % 1
    d = u - (0.62 - 0.42 * np.abs(y))
    band = np.exp(-((d / 0.1) ** 2))
    edge = 1 - smooth(0.82, 1.0, np.abs(y))
    save("chevron", band * edge)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(OUT, exist_ok=True)
    print("Текстуры ->", OUT)
    for fn in (glow, spark, star, ring, smoke, rock, swirl, wind, slash, trail, crack, magma, chain, seal, keyhole, chevron):
        fn()
