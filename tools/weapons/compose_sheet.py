"""Склейка кадров render_sheet.py в лист с подписями: python3 compose_sheet.py <out.png> [rarity.json]"""
import sys, json
from PIL import Image, ImageDraw, ImageFont
out = sys.argv[1]; meta = json.load(open(out + '.json'))
rar = json.load(open(sys.argv[2])) if len(sys.argv) > 2 else {}
cols = meta['cols']; W, H = meta['w'], meta['h']; fr = meta['frames']
rows = (len(fr) + cols - 1) // cols
sheet = Image.new('RGB', (cols * W, rows * H), (31, 37, 37)); dr = ImageDraw.Draw(sheet)
try: font = ImageFont.truetype('/usr/share/fonts/liberation-sans/LiberationSans-Regular.ttf', 14)
except Exception: font = ImageFont.load_default()
for i, (wid, path) in enumerate(fr):
    im = Image.open(path).convert('RGB'); x, y = (i % cols) * W, (i // cols) * H
    sheet.paste(im, (x, y)); dr.text((x + 10, y + 8), f'{wid} [{rar.get(wid, "")}]', fill=(230, 230, 230), font=font)
sheet.save(out); print(out, sheet.size)
