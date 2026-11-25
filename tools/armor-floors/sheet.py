"""Лист превью: python3 sheet.py <renders_dir> <out.png> set1 set2 ... [--views front,q34,back]
Склеивает рендеры render_mage.py (MAGE_OUT=<assets>) в таблицу: столбец — комплект, строка — вид."""
import sys, os
from PIL import Image, ImageDraw, ImageFont

args = sys.argv[1:]
views = ['front', 'q34', 'back']
if '--views' in args:
    i = args.index('--views'); views = args[i + 1].split(','); del args[i:i + 2]
src, out, sets = args[0], args[1], args[2:]
W, Hh, top = 300, 400, 40
im = Image.new('RGB', (W * len(sets), top + Hh * len(views)), (34, 38, 46))
d = ImageDraw.Draw(im)
try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 18)
except Exception:
    font = ImageFont.load_default()
for c, sid in enumerate(sets):
    d.text((c * W + 10, 10), sid, fill=(230, 220, 190), font=font)
    for r, v in enumerate(views):
        p = os.path.join(src, f'{sid}_{v}.png')
        if os.path.exists(p):
            tile = Image.open(p).convert('RGB')
            tile = tile.resize((W, int(tile.height * W / tile.width)), Image.LANCZOS).crop((0, 0, W, Hh))
            im.paste(tile, (c * W, top + r * Hh))
im.save(out)
print(out)
