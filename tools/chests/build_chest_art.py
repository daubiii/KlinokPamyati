"""Сборка арта сундуков v3.

  python3 tools/chests/build_chest_art.py

Пишет:
  src/ReplicatedStorage/Shared/Config/ChestDesigns.lua — блоки 10 моделей (ChestModel строит Part'ы)
  src/ReplicatedStorage/Shared/Config/ChestAtlas.lua   — куски атласа
  assets/chests/chest_atlas.png                        — иконки 32×32 и арт 112×96 (закрыт / открыт)
  tools/chests/previews/chests_sheet.png               — лист всех сундуков для обзора
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
import chestlib as C  # noqa: E402

CONFIG = os.path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared', 'Config')
ASSETS = os.path.join(ROOT, 'assets', 'chests')
PREVIEWS = os.path.join(HERE, 'previews')

ICON = (32, 32)
ART = (112, 96)


def fmt(v):
    s = ('%.3f' % v).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


def lua_designs(designs):
    out = ['--!nonstrict',
           '-- ChestDesigns (сгенерировано tools/chests/build_chest_art.py — не править руками)',
           '-- 10 моделей сундуков этажей v3: f<этаж>_common / f<этаж>_gold.',
           '-- Блок: { cx, cy, cz, sx, sy, sz, "#RRGGBB", материал[, rx, ry, rz] } в студах,',
           '-- начало — центр дна, лицо в +Z, поворот в градусах (CFrame.Angles).',
           '-- base — короб, lid — крышка (откидывается вокруг hinge = { y, z }).',
           '-- lock — точка замка (сюда бьёт Клинок Памяти), glow — свет сундука.',
           'local ChestDesigns = {}',
           '',
           'ChestDesigns.Materials = {']
    for k, v in sorted(C.MATERIALS.items()):
        out.append('\t%s = "%s",' % (k, v))
    out.append('}')
    out.append('')
    out.append('-- Клинок Памяти: пиксель-арт (сцена раскрытия собирает его из квадратов).')
    out.append('ChestDesigns.BladeColors = {')
    for k, v in sorted(C.BLADE_COLORS.items()):
        out.append('\t%s = "%s",' % (k, v))
    out.append('}')
    out.append('ChestDesigns.Blade = {')
    for row in C.blade_bitmap():
        out.append('\t"%s",' % row)
    out.append('}')
    out.append('')
    out.append('ChestDesigns.Designs = {')
    for d in designs:
        out.append('\t%s = {' % d.id)
        out.append('\t\ttitle = "%s",' % d.title)
        out.append('\t\tsize = { %s, %s, %s },' % (fmt(d.W), fmt(d.D), fmt(d.H)))
        out.append('\t\thinge = { %s, %s },' % (fmt(d.hinge[0]), fmt(d.hinge[1])))
        out.append('\t\tlock = { %s, %s, %s },' % tuple(fmt(v) for v in d.lock))
        out.append('\t\tglow = "%s",' % d.glow.upper())
        out.append('\t\tlidMax = %s,' % fmt(d.lid_max))
        for layer in ('base', 'lid'):
            out.append('\t\t%s = {' % layer)
            for p in d.parts:
                if p['layer'] != layer:
                    continue
                vals = [fmt(v) for v in p['c'] + p['s']]
                item = '{ %s, "%s", "%s"' % (', '.join(vals), p['col'], p['m'])
                if any(abs(v) > 1e-6 for v in p['r']):
                    item += ', %s' % ', '.join(fmt(v) for v in p['r'])
                out.append('\t\t\t%s },' % item)
            out.append('\t\t},')
        out.append('\t},')
    out.append('}')
    out.append('')
    out.append('ChestDesigns.Order = { %s }' % ', '.join('"%s"' % d.id for d in designs))
    out.append('')
    out.append('return ChestDesigns')
    return '\n'.join(out) + '\n'


def to_img(arr):
    return Image.fromarray((arr.clip(0, 1) * 255).astype('uint8'), 'RGBA')


def build_atlas(designs):
    cols = 5
    gap = 2
    icon_row_h = ICON[1] + gap
    art_w, art_h = ART[0] + gap, ART[1] + gap
    W = max(cols * art_w, len(designs) * (ICON[0] + gap)) + gap
    rows = (len(designs) + cols - 1) // cols
    H = gap + icon_row_h + 2 * rows * art_h + gap
    atlas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    pieces = {}
    for i, d in enumerate(designs):
        img, _ = C.render(d, ICON, pad=1)
        x, y = gap + i * (ICON[0] + gap), gap
        atlas.alpha_composite(to_img(img), (x, y))
        pieces[d.id + '_icon'] = (x, y, ICON[0], ICON[1])
        for k, (suffix, ang) in enumerate((('art', 0), ('open', d.lid_max))):
            img, _ = C.render(d, ART, lid_angle=ang, pad=3)
            col, row = i % cols, i // cols + k * rows
            x, y = gap + col * art_w, gap + icon_row_h + row * art_h
            atlas.alpha_composite(to_img(img), (x, y))
            pieces[d.id + '_' + suffix] = (x, y, ART[0], ART[1])
    return atlas, pieces


def lua_atlas(size, pieces):
    out = ['--!nonstrict',
           '-- ChestAtlas (сгенерировано tools/chests/build_chest_art.py — не править руками)',
           '-- Куски assets/chests/chest_atlas.png в родных пикселях; игра показывает ×2 (Pixelated).',
           '--   <id>_icon 32×32 — сумка, лента «Получен сундук», HUD;',
           '--   <id>_art / <id>_open 112×96 — карточка в сумке (закрыт / открыт).',
           'local ChestAtlas = {}',
           'ChestAtlas.Size = { w = %d, h = %d }' % size,
           'ChestAtlas.Pieces = {']
    for k in sorted(pieces):
        x, y, w, h = pieces[k]
        out.append('\t%s = { x = %d, y = %d, w = %d, h = %d },' % (k, x, y, w, h))
    out.append('}')
    out.append('return ChestAtlas')
    return '\n'.join(out) + '\n'


def font(size, bold=False):
    for path in ['/usr/share/fonts/liberation-sans/LiberationSans-Bold.ttf' if bold else '/usr/share/fonts/liberation-sans/LiberationSans-Regular.ttf',
                 '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf']:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    import glob
    cands = glob.glob('/usr/share/fonts/**/LiberationSans-%s.ttf' % ('Bold' if bold else 'Regular'), recursive=True)
    return ImageFont.truetype(cands[0], size) if cands else ImageFont.load_default()


def glow_layer(img):
    """Свечение неона для превью: размытая копия ярких пикселей."""
    arr = np.array(img).astype(float) / 255
    bright = (arr[..., :3].max(axis=2) > 0.85) & (arr[..., 3] > 0)
    g = np.zeros_like(arr)
    g[bright] = arr[bright]
    gi = Image.fromarray((g * 255).astype('uint8'), 'RGBA').filter(ImageFilter.GaussianBlur(6))
    return gi


def sheet(designs, chests_cfg):
    up = 3
    cell = (150, 128)
    head = 70
    W = 4 * cell[0] * up
    H = 5 * (cell[1] * up + head) + 90
    img = Image.new('RGBA', (W, H), (20, 17, 22, 255))
    dr = ImageDraw.Draw(img)
    dr.text((24, 22), 'Сундуки этажей v3 — обычный (секретная комната / ответвление / мини-босс) и золотой (босс)', font=font(30, True), fill=(235, 225, 205))
    for i, d in enumerate(designs):
        floor = i // 2 + 1
        info = chests_cfg[floor]
        colors = info['colors']
        row = i // 2
        y0 = 90 + row * (cell[1] * up + head)
        xg = (i % 2) * 2 * cell[0] * up
        # фон этажа
        bg = Image.new('RGBA', (2 * cell[0] * up - 8, cell[1] * up + head - 10), C.hx(colors[0]) and tuple(int(v * 255 * 0.55) for v in C.hx(colors[0])) + (255,))
        img.alpha_composite(bg, (xg + 4, y0))
        title = d.title
        dr.text((xg + 22, y0 + 12), title, font=font(30, True), fill=tuple(int(v * 255) for v in C.hx(colors[3] if i % 2 == 0 else '#F5D27A')))
        dr.text((xg + 22, y0 + 46), '%d · %s' % (floor, info['name']), font=font(20), fill=(200, 190, 175))
        for j, ang in enumerate((0, d.lid_max)):
            arr, _ = C.render(d, cell, lid_angle=ang, pad=6)
            im = to_img(arr).resize((cell[0] * up, cell[1] * up), Image.NEAREST)
            pos = (xg + j * cell[0] * up, y0 + head - 6)
            img.alpha_composite(glow_layer(im), pos)
            img.alpha_composite(im, pos)
    return img


FLOOR_INFO = {
    1: {'name': 'Привратный двор', 'colors': ['#3A2E2A', '#7A5C48', '#C98B4A', '#D9D2C5']},
    2: {'name': 'Затопленные сады', 'colors': ['#1F3A33', '#3F7A5C', '#9CC48A', '#5FD0C0']},
    3: {'name': 'Псарни охоты', 'colors': ['#3B1E1E', '#8C3B2E', '#D9A441', '#E8DCC0']},
    4: {'name': 'Литейные', 'colors': ['#1E1B1F', '#4A4350', '#E2672B', '#FFC857']},
    5: {'name': 'Зал хроник', 'colors': ['#1D1B3A', '#4A3F8F', '#8E7CE0', '#B8E3FF']},
}


def main():
    designs = C.all_designs()
    os.makedirs(ASSETS, exist_ok=True)
    os.makedirs(PREVIEWS, exist_ok=True)
    with open(os.path.join(CONFIG, 'ChestDesigns.lua'), 'w', encoding='utf-8') as f:
        f.write(lua_designs(designs))
    atlas, pieces = build_atlas(designs)
    atlas.save(os.path.join(ASSETS, 'chest_atlas.png'))
    with open(os.path.join(CONFIG, 'ChestAtlas.lua'), 'w', encoding='utf-8') as f:
        f.write(lua_atlas(atlas.size, pieces))
    sheet(designs, FLOOR_INFO).convert('RGB').save(os.path.join(PREVIEWS, 'chests_sheet.png'))
    # иконки ×4 для проверки читаемости
    icons = Image.new('RGBA', (len(designs) * 36 * 4, 36 * 4), (40, 32, 28, 255))
    for i, d in enumerate(designs):
        x, y, w, h = pieces[d.id + '_icon']
        icons.alpha_composite(atlas.crop((x, y, x + w, y + h)).resize((w * 4, h * 4), Image.NEAREST), (i * 36 * 4 + 8, 8))
    icons.save(os.path.join(PREVIEWS, 'chests_icons.png'))
    print('atlas', atlas.size, 'pieces', len(pieces), 'parts', sum(len(d.parts) for d in designs))


if __name__ == '__main__':
    main()
