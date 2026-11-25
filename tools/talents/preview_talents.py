# Превью вкладки «Древо» книги героя (v2): те же координаты и цвета, что в
# Windows/TalentPage.lua и CharacterWindow.lua; арт — assets/paper (бумажный UI книги)
# и assets/talents (древо). Данные древа — из Config/Talents через luau (dump_talents.lua).
# Запуск: python3 tools/talents/preview_talents.py [LUAU=…/luau]
#   → docs/shots/talents_warrior.png, talents_mage.png
import os, re, math, json, subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CFG = f'{ROOT}/src/ReplicatedStorage/Shared/Config'
atlas = Image.open(f'{ROOT}/assets/paper/paper_ui.png').convert('RGBA')
desk = Image.open(f'{ROOT}/assets/paper/paper_desk.png').convert('RGBA')
tatlas = Image.open(f'{ROOT}/assets/talents/talent_atlas.png').convert('RGBA')
BG = {k: Image.open(f'{ROOT}/assets/talents/talent_bg_{k}.png').convert('RGBA') for k in ('warrior', 'mage', 'assassin')}

def parse_atlas(path):
    out = {}
    for m in re.finditer(r'^\s*([A-Za-z_0-9]+) = \{ x = (\d+), y = (\d+), w = (\d+), h = (\d+)(?:, slice = \{ (\d+), (\d+), (\d+), (\d+) \})?', open(path, encoding='utf-8').read(), re.M):
        sl = tuple(map(int, m.group(6, 7, 8, 9))) if m.group(6) else None
        out[m.group(1)] = (*map(int, m.group(2, 3, 4, 5)), sl)
    return out
P = parse_atlas(f'{CFG}/PaperAtlas.lua')
TP = parse_atlas(f'{CFG}/TalentAtlas.lua')

def load_talents():
    luau = os.environ.get('LUAU', '/data/klinok-f45/bin/luau')
    out = subprocess.run(['node', f'{ROOT}/tools/run-luau.js', f'{ROOT}/tools/talents/dump_talents.lua'],
                         env=dict(os.environ, LUAU=luau), capture_output=True, text=True, check=True).stdout
    return json.loads(out[out.index('{'):])
DATA = load_talents()
LAYOUT = DATA['layout']

# ---- шрифты и цвета (PaperUi.colors) ----
F = '/usr/share/fonts/msttcore/'
def font(size, bold=False, italic=False):
    name = 'georgiaz.ttf' if bold and italic else 'georgiab.ttf' if bold else 'georgiai.ttf' if italic else 'georgia.ttf'
    return ImageFont.truetype(F + name, int(size * 0.86))
C = dict(ink=(66, 48, 32), ink2=(106, 83, 58), faint=(150, 128, 98), green=(35, 101, 78), red=(150, 52, 44), gold=(156, 100, 34), paper=(236, 222, 192))
GOLD = (214, 160, 60); LOCKED_RING = (184, 170, 142); LOCKED_BASE = (222, 212, 192)

def nine(img, sl, w, h, scale):
    sw, sh = img.size
    l, t, r, b = sl
    L, T, R, B = [max(0, round(v * scale)) for v in (l, t, r, b)]
    out = Image.new('RGBA', (max(w, 1), max(h, 1)))
    for sx0, sx1, dx0, dx1 in [(0, l, 0, L), (l, sw - r, L, w - R), (sw - r, sw, w - R, w)]:
        for sy0, sy1, dy0, dy1 in [(0, t, 0, T), (t, sh - b, T, h - B), (sh - b, sh, h - B, h)]:
            if sx1 > sx0 and sy1 > sy0 and dx1 > dx0 and dy1 > dy0:
                out.paste(img.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST), (dx0, dy0))
    return out

def tint(img, rgb, alpha=1.0):
    r, g, b, a = img.split()
    return Image.merge('RGBA', (r.point(lambda v: v * rgb[0] // 255), g.point(lambda v: v * rgb[1] // 255),
                                b.point(lambda v: v * rgb[2] // 255), a.point(lambda v: int(v * alpha))))

class Canvas:
    def __init__(s):
        s.im = Image.new('RGBA', (1600, 900))
        g = ImageDraw.Draw(s.im)
        for y in range(900):
            k = y / 900
            g.line([(0, y), (1600, y)], fill=(int(58 - 20 * k), int(70 - 22 * k), int(52 - 16 * k), 255))
        s.d = ImageDraw.Draw(s.im)
    def paste(s, im, x, y, rot=0):
        if rot:
            big = im.rotate(-rot, resample=Image.BICUBIC, expand=True)
            x -= (big.width - im.width) / 2; y -= (big.height - im.height) / 2
            im = big
        s.im.alpha_composite(im, (int(round(x)), int(round(y))))
    def img(s, name, x, y, w=None, h=None, scale=1, noslice=False, rgb=None, alpha=1.0, rot=0, src='paper'):
        px, py, pw, ph, sl = (P if src == 'paper' else TP)[name]
        im = (atlas if src == 'paper' else tatlas).crop((px, py, px + pw, py + ph))
        w = w or pw; h = h or ph
        im = nine(im, sl, int(w), int(h), scale) if sl and not noslice else im.resize((int(w), int(h)), Image.NEAREST)
        if rgb or alpha < 1:
            im = tint(im, rgb or (255, 255, 255), alpha)
        s.paste(im, x, y, rot)
    def text(s, t, x, y, w, h, size, color=C['ink'], bold=False, italic=False, align='left', valign='center', wrap=False, stroke=None):
        f = font(size, bold, italic)
        lines = [t]
        if wrap:
            lines, cur = [], ''
            for word in t.split():
                test = (cur + ' ' + word).strip()
                if s.d.textlength(test, font=f) > w and cur:
                    lines.append(cur); cur = word
                else:
                    cur = test
            if cur: lines.append(cur)
        lh = size * 1.15
        ty = y + (h - lh * len(lines)) / 2 if valign == 'center' else y
        for line in lines:
            if not wrap and s.d.textlength(line, font=f) > w:  # TextTruncate.AtEnd
                while line and s.d.textlength(line + '…', font=f) > w: line = line[:-1]
                line += '…'
            tw = s.d.textlength(line, font=f)
            tx = x + (w - tw) / 2 if align == 'center' else (x + w - tw if align == 'right' else x)
            if '✓' in line:
                sf = ImageFont.truetype('/usr/share/fonts/google-noto-cjk/NotoSansSC-Medium.otf', int(size * 0.9))
                s.d.text((tx, ty + (lh - size) / 2 - 2), '✓', font=sf, fill=color)
                tx += s.d.textlength('✓', font=sf); line = line.replace('✓', '')
            if stroke:
                s.d.text((tx, ty + (lh - size) / 2), line, font=f, fill=color, stroke_width=2, stroke_fill=stroke)
            else:
                s.d.text((tx, ty + (lh - size) / 2), line, font=f, fill=color)
            ty += lh
    def sheet(s, x, y, w, h, kind, tilt=-1.2):
        s.img('sheetBack', x + 2 + 6, y + 3 + 8, w - 4, h - 6, rot=tilt)
        s.img(kind, x, y, w, h)
    def strip(s, x, y, w, h, text, active=False, knobText=None, ts=19):
        sc = h / 32
        s.img('stripRed' if active else 'strip', x, y, w, h, scale=sc)
        if knobText:
            k = int(h * 0.5); s.text(knobText, x + 7.5 * sc - k / 2, y + h / 2 - k / 2 - 1, k, k, int(h * 0.3), C['paper'], bold=True, align='center')
        left = int(30 * sc)
        s.text(text, x + left, y, w - left - 34 * sc, h - 2, ts, C['red'] if active else C['ink'], bold=True)
    def button(s, x, y, w, h, text, tone='green', disabled=False, ts=22):
        s.img('btn', x, y, w, h, scale=2, rgb=(205, 196, 180) if disabled else None)
        s.text(text, x + 8, y - 3, w - 16, h, ts, C['faint'] if disabled else (C['red'] if tone == 'red' else C['green']), bold=True, align='center')

def points_word(n):
    m10, m100 = n % 10, n % 100
    if m10 == 1 and m100 != 11: return 'очко'
    if 2 <= m10 <= 4 and not 12 <= m100 <= 14: return 'очка'
    return 'очков'

def chrome(c, free, title):
    c.paste(nine(desk, (24, 24, 24, 40), 1568, 784, 2), 16, 100)
    for i, (tid, name, key) in enumerate([('gear', 'Снаряжение', 'I'), ('hero', 'Герой', 'C'), ('journal', 'Журнал', 'J'), ('talents', 'Древо', 'T')]):
        c.strip(24 + i * 190, 26, 182, 48, name, active=tid == 'talents', knobText=key)
    # лента заголовка
    c.img('ribbon', 784, 10, 388, 76, scale=76 / 80)
    c.text(title, 784, 10 - 76 * 0.08, 388, 76, 28, C['green'], bold=True, align='center')
    # красная печать со свободными очками на закладке «Древо»
    if free > 0:
        tx = 24 + 3 * 190 + 182 - 14; ty = 26 + 4
        c.d.ellipse([tx - 15, ty - 15, tx + 15, ty + 15], fill=C['paper'])
        c.d.ellipse([tx - 13, ty - 13, tx + 13, ty + 13], fill=C['red'])
        c.text('9+' if free > 9 else str(free), tx - 14, ty - 14 - 1, 28, 28, 16, (255, 255, 255), bold=True, align='center')
    c.img('plate', 1180, 24, 306, 60, scale=2)
    for i, (ic, val) in enumerate([('it_coinStack', '1 240'), ('it_ingot', '18'), ('it_dust', '86')]):
        x = 1192 + i * 98
        c.img(ic, x, 38, 28, 28, noslice=True)
        c.text(val, x + 32, 38, 64, 30, 21, C['ink'], bold=True)
    c.img('btnRoundBig', 1498, 20, 64, 64, noslice=True)
    c.img('icClose', 1498 + 16, 20 + 14, 32, 32, noslice=True)


# ---- древо v2: те же числа, что в Windows/TalentPage.lua ----
TREE = dict(x=40, y=118, w=1120, h=748); SIDE = dict(x=1176, y=118, w=384, h=748)
PATH_X = [200, 560, 920]; STEP = 105
SIZE = dict(minor=26, normal=46, key=58); ICON = dict(minor=14, normal=32, key=32)
ROOT_POS = (560, 712); ROOT_SIZE = 46
SC = 2
GOLD = (214, 160, 72); GOLD_ICON = (238, 206, 142)
BONE = (184, 172, 152); BONE_ICON = (222, 212, 194)
ASH = (112, 104, 94); ASH_ICON = (128, 120, 110)
DARK = (66, 60, 55); DARK_ICON = (76, 69, 64); DARK_BASE = (160, 160, 160)
LINE = dict(locked=(58, 52, 48), open=(150, 140, 124), learned=(204, 152, 70))
TXT = dict(name=(206, 192, 166), dim=(124, 113, 99), gold=(226, 180, 96))

def tpiece(name):
    x, y, w, h, _ = TP[name]
    return tatlas.crop((x, y, x + w, y + h))

def tart(c, name, cx, cy, size=None, rgb=None, alpha=1.0, rot=0):
    im = tpiece(name)
    w, h = (size, size) if size else (im.width * SC, im.height * SC)
    im = im.resize((int(w), int(h)), Image.NEAREST)
    if rot:
        im = im.rotate(-rot, expand=True)
    if rgb or alpha < 1:
        im = tint(im, rgb or (255, 255, 255), alpha)
    c.paste(im, cx - im.width / 2, cy - im.height / 2)

def node_pos(n, bi):
    lay = LAYOUT[n['slot']]
    return PATH_X[bi] + lay['x'] * STEP, lay['y']

def status(n, learned, free):
    if n['id'] in learned: return 'learned', None
    if n['needs'] and not any(x in learned for x in n['needs']): return 'locked', 'locked'
    if free < n['cost']: return 'short', 'points'
    return 'available', None

FRAME = dict(minor=('frame_m_base', 'frame_m_ring'), normal=('frame_n_base', 'frame_n_ring'), key=('frame_k_base', 'frame_k_ring'))
TONE = dict(learned=(GOLD, GOLD_ICON), available=(BONE, BONE_ICON), short=(ASH, ASH_ICON), locked=(DARK, DARK_ICON))

def dashes(c, pts, color, size=4, step=8, start=0, stop=0):
    # пунктир по ломаной pts (дизайн-px листа), отступы от концов start/stop
    segs = list(zip(pts, pts[1:]))
    total = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in segs)
    d = start
    while d <= total - stop:
        acc = 0
        for a, b in segs:
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            if d <= acc + L:
                t = (d - acc) / L
                px, py = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
                c.d.rectangle([TREE['x'] + round(px) - size // 2, TREE['y'] + round(py) - size // 2,
                               TREE['x'] + round(px) - size // 2 + size - 1, TREE['y'] + round(py) - size // 2 + size - 1], fill=color)
                break
            acc += L
        d += step

def render(cid, level, learned, selected, resets, out, hover=None):
    tree = DATA['classes'][cid]
    branches = tree['branches']
    allnodes = {n['id']: (n, bi) for bi, b in enumerate(branches) for n in b['nodes']}
    points = max(0, min(level, DATA['maxLevel']) - 1)
    spent = sum(allnodes[i][0]['cost'] for i in learned)
    by_branch = [sum(n['cost'] for n in b['nodes'] if n['id'] in learned) for b in branches]
    free = points - spent
    c = Canvas()
    chrome(c, free, tree['title'])
    X, Y = TREE['x'], TREE['y']
    # тень и тёмный лист древа
    c.d.rectangle([X + 6, Y + 8, X + TREE['w'] + 6, Y + TREE['h'] + 8], fill=(18, 14, 10))
    c.paste(BG[cid].resize((TREE['w'], TREE['h']), Image.NEAREST), X, Y)
    # шапки путей
    for i, b in enumerate(branches):
        cx = PATH_X[i]
        c.text(b['name'].upper(), X + cx - 150, Y + 24, 300, 28, 22, TXT['name'], bold=True, align='center')
        c.text(b['text'], X + cx - 160, Y + 54, 320, 20, 14, TXT['dim'], italic=True, align='center')
        sp = by_branch[i]
        c.text(f"{sp} / {b['cost']}", X + cx - 60, Y + 76, 120, 20, 15, TXT['gold'] if sp > 0 else TXT['dim'], bold=True, align='center')
    # корень → входы путей
    rx, ry = ROOT_POS
    for i, b in enumerate(branches):
        a1 = b['nodes'][0]
        ax, ay = node_pos(a1, i)
        col = LINE['learned'] if a1['id'] in learned else LINE['open']
        pts = [(rx, ry), (ax, ry), (ax, ay)] if ax != rx else [(rx, ry), (ax, ay)]
        dashes(c, pts, col, start=ROOT_SIZE / 2 + 4 if ax == rx else ROOT_SIZE / 2 + 4, stop=SIZE['minor'] / 2 + 4)
    # связи
    for i, b in enumerate(branches):
        by_id = {n['id']: n for n in b['nodes']}
        for n in b['nodes']:
            for need in n['needs']:
                f = by_id[need]
                a = node_pos(f, i); z = node_pos(n, i)
                if f['id'] in learned and n['id'] in learned: col = LINE['learned']
                elif f['id'] in learned: col = LINE['open']
                else: col = LINE['locked']
                dashes(c, [a, z], col, start=SIZE[f['kind']] / 2 + 4, stop=SIZE[n['kind']] / 2 + 4)
    # корень
    tart(c, 'root_base', X + rx, Y + ry)
    tart(c, 'root_ring', X + rx, Y + ry, rgb=GOLD if spent > 0 else BONE)
    tart(c, 'cls_' + tree['item'], X + rx, Y + ry, rgb=GOLD_ICON if spent > 0 else BONE_ICON)
    # узлы
    for i, b in enumerate(branches):
        for n in b['nodes']:
            st, _ = status(n, learned, free)
            kind = n['kind']; size = SIZE[kind]
            px, py = node_pos(n, i); cx, cy = X + px, Y + py
            ring, icol = TONE[st]
            if st == 'available':
                tart(c, 'glow', cx, cy, size + 30, rgb=BONE, alpha=0.5)
            elif st == 'learned' and kind == 'key':
                tart(c, 'glow', cx, cy, size + 34, rgb=GOLD, alpha=0.55)
            fb, fr = FRAME[kind]
            tart(c, fb, cx, cy, rgb=DARK_BASE if st == 'locked' else None)
            tart(c, fr, cx, cy, rgb=ring)
            tart(c, n['icon'], cx, cy, rgb=icol)
            if kind == 'key' and st != 'learned':
                bx, by = cx, cy + size / 2 + 2
                tart(c, 'badge', bx, by, 22, rgb=BONE if st == 'available' else ASH if st == 'short' else DARK)
                c.text(str(n['cost']), bx - 11, by - 11 - 1, 22, 22, 13, TXT['name'] if st == 'available' else TXT['dim'], bold=True, align='center')
            if n['id'] == selected:
                half = size / 2 + 7
                for j, rot in enumerate((0, 90, 180, 270)):
                    sx = 1 if j in (1, 2) else -1; sy = 1 if j in (2, 3) else -1
                    tart(c, 'sel', cx + sx * (half - 3), cy + sy * (half - 3), 12, rgb=GOLD_ICON, rot=rot)
    # правый лист
    SX, SY, SW = SIDE['x'], SIDE['y'], SIDE['w']
    c.sheet(SX, SY, SW, SIDE['h'], 'sheetAlt', tilt=1.4)
    def centered(t, size, color, y, bold=False, italic=False):
        c.text(t, SX + 20, SY + y, SW - 40, size + 8, size, color, bold=bold, italic=italic, align='center')
    centered('ОЧКИ ДРЕВА', 22, C['green'], 18, bold=True)
    c.img('ring80', SX + 152, SY + 50, 80, 80, noslice=True)
    c.text(str(free), SX + 152, SY + 50, 80, 76, 34, C['green'] if free > 0 else C['ink'], bold=True, align='center')
    centered(f'{points_word(free)} свободно' if free > 0 else 'все очки вложены', 16, C['ink2'], 132, italic=True)
    centered(f'Уровень {level} · всего {points} · вложено {spent}', 16, C['ink2'], 156)
    c.img('divider', SX + 24, SY + 188, 336, 16)
    n, bi = allnodes[hover or selected]; b = branches[bi]
    st, reason = status(n, learned, free)
    kind = n['kind']
    fb, fr = FRAME[kind]
    cs = 4 if kind == 'minor' else 3
    _, _, fw, fh, _ = TP[fb]; _, _, iw, ih, _ = TP[n['icon']]
    ring, icol = TONE[st]
    tart(c, fb, SX + 192, SY + 252, fw * cs)
    tart(c, fr, SX + 192, SY + 252, fw * cs, rgb=ring)
    tart(c, n['icon'], SX + 192, SY + 252, iw * cs, rgb=icol)
    centered(n['name'], 25, C['ink'], 300, bold=True)
    kinds = dict(minor='Малый узел', normal='Узел', key='Ключевой узел')
    centered(f"{kinds[kind]} · {n['cost']} {points_word(n['cost'])} · {b['name']}", 16, C['gold'], 332, italic=True)
    c.text(n['text'], SX + 28, SY + 362, 328, 84, 18, C['ink'], align='center', valign='top', wrap=True)
    if st == 'learned': stt, scol = '✓ Изучено', C['green']
    elif st == 'available': stt, scol = 'Можно изучить', C['green']
    elif reason == 'points': stt, scol = f"Не хватает очков: нужно {n['cost']}, свободно {free}", C['red']
    else:
        stt, scol = 'Сначала: ' + ' или '.join('«%s»' % allnodes[x][0]['name'] for x in n['needs']), C['red']
    centered(stt, 16, scol, 450, bold=True)
    c.button(SX + 42, SY + 484, 300, 58, 'Изучено' if st == 'learned' else f"Изучить · {n['cost']} {points_word(n['cost'])}", disabled=st != 'available', ts=21)
    c.img('divider', SX + 24, SY + 562, 336, 16)
    cost = 0 if resets == 0 else max(50, 25 * spent)
    c.button(SX + 42, SY + 582, 300, 54, 'Сбросить древо', tone='red', disabled=spent <= 0, ts=19)
    price = f'{cost} золота' if cost > 0 else 'бесплатно'
    hint = (f'Вернёт {spent} {points_word(spent)} · цена {price} (25 за очко)' if cost > 0
            else f'Первый сброс бесплатно · вернёт {spent} {points_word(spent)}')
    c.text(hint, SX + 28, SY + 642, 328, 42, 15, C['ink2'], italic=True, align='center', valign='top', wrap=True)
    centered('Клик — выбрать, второй клик — изучить', 14, C['faint'], 694, italic=True)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    c.im.convert('RGB').save(out)
    print(out, f'{cid}: уровень {level}, очков {points}, вложено {spent}, свободно {free}')

def path(cid, bi, slots):
    b = DATA['classes'][cid]['branches'][bi]
    by = {n['slot']: n['id'] for n in b['nodes']}
    return {by[s] for s in slots}

if __name__ == '__main__':
    shots = f'{ROOT}/docs/shots'
    # Воин 34 ур. (33 очка): «Защита» до «Ответного удара» и левый край до «Щитовой стены»,
    # «Натиск» начат; выбран ключевой «Мастер оружия» — путь к нему ещё не открыт.
    w = path('warrior', 0, ['a1', 'a2', 'N1', 'l1', 'N2', 'l2', 'K1', 'l3', 'l4', 'N4', 'r1', 'N3'])
    w |= path('warrior', 1, ['a1', 'a2', 'N1', 'r1', 'N3'])
    w |= path('warrior', 2, ['a1'])
    render('warrior', 34, w, 'w_master', 0, f'{shots}/talents_warrior.png')
    # Маг 48 ур.: «Посох» до «Расщепления», «Чары» до «Быстрого чтения», «Источник» начат.
    m = path('mage', 1, ['a1', 'a2', 'N1', 'l1', 'N2', 'l3', 'l4', 'N4', 'l5', 'l6', 'K2', 'r1', 'N3', 'l2', 'K1'])
    m |= path('mage', 2, ['a1', 'a2', 'N1', 'l1', 'N2', 'l2', 'K1', 'r1'])
    m |= path('mage', 0, ['a1', 'a2', 'N1'])
    render('mage', 48, m, 'm_edge', 1, f'{shots}/talents_mage.png')
