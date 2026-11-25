#!/usr/bin/env python3
# Превью окна карты (как его соберёт GateWindow): карта ×3, туман, подсветка, плашки.
#   python3 tools/worldmap/preview.py [открыто_этажей] [выбранный] → assets/worldmap/worldmap_preview.png
import os, sys, pickle, numpy as np
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
open_n = int(sys.argv[1]) if len(sys.argv) > 1 else 1
sel = int(sys.argv[2]) if len(sys.argv) > 2 else 1
out = sys.argv[3] if len(sys.argv) > 3 else os.path.join(ROOT, 'assets', 'worldmap', 'worldmap_preview.png')
atlas = Image.open(os.path.join(ROOT, 'assets', 'worldmap', 'worldmap_atlas.png')).convert('RGBA')
meta = pickle.load(open('/tmp/worldmap_meta.pkl', 'rb'))
R, M = meta['rects'], meta['meta']
S = 3
def piece(name):
    x, y, w, h = R[name]
    return atlas.crop((x, y, x + w, y + h))
names = {1: 'Привратный двор', 2: 'Затопленные сады', 3: 'Псарни охоты', 4: 'Литейные', 5: 'Зал хроник'}
nums = {1: 'I', 2: 'II', 3: 'III', 4: 'IV', 5: 'V'}
canvas = Image.new('RGBA', (1600, 900), (16, 14, 22, 255))
d = ImageDraw.Draw(canvas)
# рамка карты
mx, my = 44, 124
d.rectangle([mx - 10, my - 10, mx + 504 * S + 9, my + 236 * S + 9], fill=(30, 22, 19), outline=(122, 86, 54), width=4)
base = piece('map').copy()
for k in range(1, 6):
    if k > open_n:
        fx, fy = M[k]['fogpos']
        base.alpha_composite(piece('fog%d' % k), (fx, fy))
for k, (cx, cy, pn) in {1: (300, 30, 'cloud1'), 2: (130, 170, 'cloud2'), 3: (380, 200, 'cloud3')}.items():
    base.alpha_composite(piece(pn), (cx, cy))
for k in range(1, 6):
    if k > open_n:
        bx, by, bw, bh = M[k]['box']
        base.alpha_composite(piece('puff1'), (bx + bw // 3, by + bh // 3))
        base.alpha_composite(piece('puff2'), (bx + bw // 2, by + bh // 2))
hi = piece('hi%d' % sel)
tint = np.array(hi).astype(float)
col = (120, 232, 255)
tint[..., 0] = col[0]; tint[..., 1] = col[1]; tint[..., 2] = col[2]
base.alpha_composite(Image.fromarray(tint.astype(np.uint8), 'RGBA'), M[sel]['fogpos'])
big = base.resize((504 * S, 236 * S), Image.NEAREST)
canvas.alpha_composite(big, (mx, my))
font = ImageFont.truetype('/usr/share/fonts/liberation-sans/LiberationSans-Bold.ttf', 18)
small = ImageFont.truetype('/usr/share/fonts/liberation-sans/LiberationSans-Bold.ttf', 14)
for k in range(1, 6):
    lx, ly = M[k]['label']
    locked = k > open_n
    text = '%s · %s' % (nums[k], names[k] if (not locked or k == open_n + 1) else '???')
    tw = d.textlength(text, font=font)
    w = int(tw) + 56
    x = mx + lx * S - w // 2; y = my + ly * S
    on = k == sel
    d.rectangle([x, y, x + w, y + 34], fill=(26, 19, 16), outline=(120, 232, 255) if on else ((110, 104, 100) if locked else (122, 86, 54)), width=3)
    d.ellipse([x + 8, y + 7, x + 28, y + 27], fill=(24, 22, 26), outline=(110, 104, 100) if locked else (120, 232, 255), width=3)
    d.text((x + 42, y + 7), text, font=font, fill=(150, 144, 138) if locked else ((200, 240, 255) if on else (255, 204, 84)))
d.text((mx, 852), 'Нажми на открытый этаж — летопись, хранитель и сундуки этажа', font=small, fill=(200, 236, 250))
d.rectangle([600, 12, 1000, 80], fill=(150, 100, 60), outline=(26, 16, 10), width=4)
d.text((800, 46), 'Врата Печатей', font=ImageFont.truetype('/usr/share/fonts/liberation-sans/LiberationSans-Bold.ttf', 30), fill=(255, 204, 84), anchor='mm')
canvas.convert('RGB').save(out)
print(out)
