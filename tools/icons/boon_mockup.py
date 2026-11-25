"""Макет экрана «Дар Эха» v2 (бумага «Книги героя»): куски настоящего атласа
docs/updates/ui-studio/paper/paper_ui.png, раскладка как в FloorBoonController.
Шрифт Lora вместо Garamond. python3 tools/icons/boon_mockup.py <фон.png> <out.png>"""
import sys, math, re, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance
ATLAS = Image.open('docs/updates/ui-studio/paper/paper_ui.png').convert('RGBA')
PA = open('src/ReplicatedStorage/Shared/Config/PaperAtlas.lua', encoding='utf-8').read()
PIECES = {}
for m in re.finditer(r'(\w+) = \{ x = (\d+), y = (\d+), w = (\d+), h = (\d+)(?:, slice = \{ (\d+), (\d+), (\d+), (\d+) \})?', PA):
    n = m.group(1); v = [int(g) if g else None for g in m.groups()[1:]]
    PIECES[n] = v
def piece(name):
    x, y, w, h = PIECES[name][:4]; return ATLAS.crop((x, y, x + w, y + h))
def nine(name, W, H, scale=1):
    x, y, w, h, l, t, r, b = PIECES[name]
    src = piece(name)
    if l is None:
        return src.resize((W, H), Image.NEAREST)
    out = Image.new('RGBA', (W, H))
    xs = [0, l, w - r, w]; ys = [0, t, h - b, h]
    dx = [0, l * scale, W - r * scale, W]; dy = [0, t * scale, H - b * scale, H]
    for i in range(3):
        for j in range(3):
            sw, sh = xs[i + 1] - xs[i], ys[j + 1] - ys[j]; tw, th = dx[i + 1] - dx[i], dy[j + 1] - dy[j]
            if sw <= 0 or sh <= 0 or tw <= 0 or th <= 0: continue
            out.paste(src.crop((xs[i], ys[j], xs[i + 1], ys[j + 1])).resize((tw, th), Image.NEAREST), (dx[i], dy[j]))
    return out
def tint(img, col):
    r, g, b, a = img.split(); c = Image.new('RGBA', img.size, col + (255,))
    mul = Image.merge('RGBA', (*[Image.eval(ch, lambda v: v) for ch in (r, g, b)], a))
    from PIL import ImageChops
    out = ImageChops.multiply(mul.convert('RGB'), c.convert('RGB')).convert('RGBA'); out.putalpha(a); return out
LUA = open('src/ReplicatedStorage/Shared/Config/BoonIcons.lua', encoding='utf-8').read()
def icon(name, px):
    blk = LUA[LUA.index('\t%s = {' % name):]
    pal = {k: (int(r), int(g), int(b)) for k, r, g, b in re.findall(r'(\w) = Color3.fromRGB\((\d+), (\d+), (\d+)\)', blk[:blk.index('rows')])}
    rows = re.findall(r'"([^"]{20})"', blk)[:20]
    im = Image.new('RGBA', (20 * px, 20 * px))
    d = ImageDraw.Draw(im)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal: d.rectangle([x * px, y * px, x * px + px - 1, y * px + px - 1], fill=pal[ch])
    return im
def font(size, weight='Regular', italic=False):
    if italic:
        return ImageFont.truetype('/usr/share/fonts/truetype/google-fonts/Lora-Italic-Variable.ttf', size)
    f = ImageFont.truetype('/usr/share/fonts/truetype/google-fonts/Lora-Variable.ttf', size); f.set_variation_by_name(weight); return f
INK = (66, 48, 32); INK2 = (106, 83, 58); FAINT = (150, 128, 98); GREEN = (35, 101, 78)
RINK = {1: (110, 104, 96), 2: (46, 128, 60), 3: (184, 108, 18)}
RNAME = {1: 'обычный дар', 2: 'редкий дар', 3: 'легендарный дар'}
RGLOW = {1: (228, 232, 236), 2: (170, 245, 160), 3: (255, 226, 130)}
CARDS = [('haste', 'Ярость клинка', 1, 'Скорость атаки', '+20%', 'Новый дар', -2.0),
         ('soul_hunger', 'Голод душ', 2, 'Урон от накопленных душ', '+30%', 'Уже есть ×1 · станет +50%', 0.8),
         ('vitality', 'Крепкое сердце', 3, 'Максимум здоровья', '+55%', 'Новый дар', 2.2)]
W, H = 1600, 900
bg = Image.open(sys.argv[1]).convert('RGB').resize((W, H))
bg = ImageEnhance.Color(bg).enhance(0.25).filter(ImageFilter.GaussianBlur(6))
img = Image.blend(bg, Image.new('RGB', (W, H), (8, 10, 18)), 0.45).convert('RGBA')
d = ImageDraw.Draw(img, 'RGBA')
# часы
cx, cy, R = 800, 500, 300
d.ellipse([cx - R, cy - R, cx + R, cy + R], outline=(150, 200, 255, 70), width=6)
for i in range(12):
    a = math.radians(i * 30); L = 34 if i % 3 == 0 else 20; w = 10 if i % 3 == 0 else 6
    d.line([cx + math.sin(a) * (R - 15), cy - math.cos(a) * (R - 15), cx + math.sin(a) * (R - 15 - L), cy - math.cos(a) * (R - 15 - L)], fill=(150, 200, 255, 100), width=w)
for ang, ln, w in ((-50, 0.32, 10), (62, 0.42, 6)):
    a = math.radians(ang); d.line([cx, cy, cx + math.sin(a) * R * ln, cy - math.cos(a) * R * ln], fill=(150, 200, 255, 115), width=w)
random.seed(3)
for _ in range(42):
    x, y, s = random.random() * W, random.random() * H, random.choice([2, 4, 6]); d.rectangle([x, y, x + s, y + s], fill=(200, 225, 255, random.randint(60, 150)))
# заголовок: дуга книги
hdr = piece('headerArc').resize((432, 132), Image.NEAREST)
img.alpha_composite(hdr, (800 - 216, 34))
d = ImageDraw.Draw(img, 'RGBA')
d.text((800, 34 + 132 * 0.34), 'Дар Эха', font=font(34, 'Bold'), fill=GREEN, anchor='mm')
d.text((800, 178), 'Время замерло. Выбери один дар — до конца этажа', font=font(21, italic=True), fill=(232, 236, 250), anchor='mm', stroke_width=3, stroke_fill=(14, 12, 20))
CW, CH, GAP = 300, 430, 56
total = 3 * CW + 2 * GAP
for i, (iid, name, rar, d1, val, foot, rot) in enumerate(CARDS):
    x = 800 - total / 2 + CW / 2 + i * (CW + GAP); top = 500 - CH / 2 + (-16 if i == 1 else 0)
    if i == 1: rot = 0
    card = Image.new('RGBA', (CW + 80, CH + 110), (0, 0, 0, 0)); ox, oy = 40, 40
    cd = ImageDraw.Draw(card, 'RGBA')
    back = nine('sheetBack', CW - 4, CH - 6).rotate(-1.2, expand=True, resample=Image.NEAREST)
    card.alpha_composite(back, (ox + 6 + 2, oy + 8 + 3))
    card.alpha_composite(nine('sheet', CW, CH), (ox, oy))
    cd = ImageDraw.Draw(card, 'RGBA')
    if rar >= 2:
        cd.rectangle([ox + 16, oy + 16, ox + CW - 16, oy + CH - 16], outline=RINK[rar] + (150,), width=2)
        if rar == 3:
            cd.rectangle([ox + 21, oy + 21, ox + CW - 21, oy + CH - 21], outline=RINK[rar] + (110,), width=1)
    # лента с именем
    rib = nine('ribbon', CW + 44, 64, 1)
    rib = nine('ribbon', int((CW + 44) / 0.8), 80, 1).resize((CW + 44, 64), Image.NEAREST)
    card.alpha_composite(rib, (ox - 22, oy - 22))
    cd = ImageDraw.Draw(card, 'RGBA')
    cd.text((ox + CW / 2, oy - 22 + 27), name, font=font(23, 'Bold'), fill=GREEN, anchor='mm')
    # медальон
    ring = piece('ring80').resize((160, 160), Image.NEAREST)
    card.alpha_composite(ring, (int(ox + CW / 2 - 80), oy + 66))
    ic = icon(iid, 5)
    card.alpha_composite(ic, (int(ox + CW / 2 - 50), oy + 66 + 30))
    cd = ImageDraw.Draw(card, 'RGBA')
    # редкость
    cd.text((ox + CW / 2, oy + 246), RNAME[rar], font=font(19, 'SemiBold', italic=True), fill=RINK[rar], anchor='mm')
    for s in (-1, 1):
        cd.rectangle([ox + CW / 2 + s * 82 - 3, oy + 243, ox + CW / 2 + s * 82 + 3, oy + 249], fill=RINK[rar])
    dv = nine('divider', 200, 16)
    card.alpha_composite(dv, (int(ox + CW / 2 - 100), oy + 262))
    cd = ImageDraw.Draw(card, 'RGBA')
    cd.text((ox + CW / 2, oy + 306), d1, font=font(20, 'Medium'), fill=INK, anchor='mm')
    cd.text((ox + CW / 2, oy + 340), val, font=font(30, 'Bold'), fill=RINK[rar] if rar > 1 else INK, anchor='mm')
    cd.text((ox + CW / 2 - (18 if rar >= 2 else 0), oy + CH - 58), foot, font=font(16, italic=True), fill=GREEN if 'Уже' in foot else FAINT, anchor='mm')
    if rar >= 2:
        seal = tint(piece('stampMark').resize((56, 56), Image.NEAREST), RINK[rar]).rotate(-12, expand=True, resample=Image.NEAREST)
        card.alpha_composite(seal, (ox + CW - 44 - seal.width // 2, oy + CH - 40 - seal.height // 2))
    # клавиша
    pl = nine('plate', 40, 40)
    card.alpha_composite(pl, (int(ox + CW / 2 - 20), oy + CH + 14))
    cd = ImageDraw.Draw(card, 'RGBA')
    cd.text((ox + CW / 2, oy + CH + 34), str(i + 1), font=font(22, 'Bold'), fill=INK, anchor='mm')
    card = card.rotate(-rot, expand=False, resample=Image.BICUBIC)
    sh = Image.new('RGBA', card.size, (0, 0, 0, 0)); sh.putalpha(card.split()[3].point(lambda a: int(a * 0.45)))
    sh = sh.filter(ImageFilter.GaussianBlur(6))
    if rar >= 2:
        gl = Image.new('RGBA', card.size, RGLOW[rar] + (0,)); gl.putalpha(card.split()[3].point(lambda a: int(a * (0.55 if rar == 3 else 0.35))))
        img.alpha_composite(gl.filter(ImageFilter.GaussianBlur(22)), (int(x - CW / 2 - 40), int(top - 40)))
    img.alpha_composite(sh, (int(x - CW / 2 - 40 + 8), int(top - 40 + 12)))
    img.alpha_composite(card, (int(x - CW / 2 - 40), int(top - 40)))
# полоска даров
d = ImageDraw.Draw(img, 'RGBA')
for j, (iid, rar, n) in enumerate((('might', 1, 1), ('evasion', 2, 2))):
    y = 168 + j * 58
    img.alpha_composite(nine('square', 50, 50), (24, y))
    if rar > 1:
        d.rectangle([24 + 12, y + 50 - 9, 24 + 38, y + 50 - 5], fill=RINK[rar])
    img.alpha_composite(icon(iid, 2), (29, y + 4))
    if n > 1:
        d.text((24 + 50, y + 50), '×%d' % n, font=font(17, 'Bold'), fill=(248, 240, 222), anchor='rs', stroke_width=3, stroke_fill=(20, 14, 10))
img.convert('RGB').save(sys.argv[2])
print('ok')
