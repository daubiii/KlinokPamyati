"""Текстуры частиц этажа 2 «Затопленные сады»: лист, лепесток, капля.
Белые силуэты с альфой (цвет задаёт ParticleEmitter.Color), 128×128 PNG — как остальные текстуры эффектов.
Запуск: python make_textures_garden.py [папка_вывода]   (нужен Pillow)
Загрузить в Roblox: Creator Hub → Assets → Images (или Studio → Asset Manager → Bulk Import), взять id
и вписать в таблицу NEW в начале BuildFxGarden.lua. Пока id пустые, эффекты используют старые текстуры (glow/star)."""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'textures_garden')
os.makedirs(OUT, exist_ok=True)
S, N = 4, 128   # рисуем в 4× и уменьшаем

def canvas():
    return Image.new('L', (N * S, N * S), 0)

def finish(mask, name, blur=0.6):
    mask = mask.filter(ImageFilter.GaussianBlur(blur * S)).resize((N, N), Image.LANCZOS)
    img = Image.new('RGBA', (N, N), (255, 255, 255, 0)); img.putalpha(mask)
    img.save(os.path.join(OUT, name)); return img

def leaf():
    m = canvas(); d = ImageDraw.Draw(m); cx = N * S / 2
    pts = []
    for i in range(0, 101):
        t = i / 100
        y = N * S * (0.06 + 0.88 * t)
        w = math.sin(math.pi * t ** 0.85) * N * S * 0.30
        pts.append((cx + w, y))
    for i in range(100, -1, -1):
        t = i / 100
        y = N * S * (0.06 + 0.88 * t)
        w = math.sin(math.pi * t ** 0.85) * N * S * 0.30
        pts.append((cx - w, y))
    d.polygon(pts, fill=255)
    d.line([(cx, N * S * 0.10), (cx, N * S * 0.90)], fill=150, width=int(S * 2.2))     # прожилка
    for k in range(1, 5):                                                                # боковые жилки
        y = N * S * (0.2 + 0.14 * k)
        for s in (-1, 1):
            d.line([(cx, y), (cx + s * N * S * 0.17, y - N * S * 0.07)], fill=185, width=int(S * 1.4))
    return finish(m, 'leaf.png')

def petal():
    m = canvas(); d = ImageDraw.Draw(m); cx, cy = N * S / 2, N * S / 2
    pts = []
    for i in range(0, 361, 3):
        a = math.radians(i)
        r = N * S * 0.40 * (0.62 + 0.38 * math.sin(a / 2) ** 0.9)       # широкая округлая вершина, узкое основание
        pts.append((cx + math.sin(a) * r * 0.78, cy - math.cos(a) * r * 1.05 + N * S * 0.04))
    d.polygon(pts, fill=255)
    d.ellipse([cx - N * S * 0.10, cy - N * S * 0.30, cx + N * S * 0.10, cy + N * S * 0.02], fill=205)   # светлее в центре
    return finish(m, 'petal.png')

def drop():
    m = canvas(); d = ImageDraw.Draw(m); cx = N * S / 2
    r = N * S * 0.26; cy = N * S * 0.62
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    d.polygon([(cx - r * 0.93, cy - r * 0.36), (cx + r * 0.93, cy - r * 0.36), (cx, N * S * 0.08)], fill=255)
    d.ellipse([cx - r * 0.55, cy - r * 0.2, cx - r * 0.12, cy + r * 0.3], fill=200)               # блик
    return finish(m, 'drop.png')

if __name__ == '__main__':
    for f in (leaf, petal, drop): f()
    print('готово:', OUT, os.listdir(OUT))
