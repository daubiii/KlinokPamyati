# Пиксельные иконки способностей этажей 3–5: 20x20, контур #24160F, атлас 4x4.
from PIL import Image, ImageDraw
import json, math

OUT = (36, 22, 15, 255)
P = {
 'bone': (248, 240, 222), 'grey': (160, 150, 140), 'dgrey': (98, 92, 88), 'steel': (196, 204, 212),
 'dsteel': (120, 128, 140), 'wood': (150, 100, 56), 'dwood': (104, 66, 36), 'red': (240, 90, 80),
 'dred': (160, 40, 36), 'gold': (255, 204, 84), 'orange': (255, 140, 40), 'yellow': (255, 236, 120),
 'mem': (120, 232, 255), 'dmem': (60, 150, 200), 'ink': (64, 54, 118), 'ink2': (112, 98, 184),
 'parch': (238, 222, 182), 'dparch': (196, 168, 120), 'green': (120, 220, 110), 'brown': (120, 84, 48),
 'wax': (196, 48, 52), 'dwax': (130, 24, 32), 'white': (255, 255, 255),
}

def C(n):
    return P[n] + (255,)

def new():
    im = Image.new('RGBA', (20, 20), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)

def px(d, pts, col):
    for x, y in pts:
        d.point((x, y), fill=C(col))

def outline(im):
    a = im.load()
    out = im.copy(); o = out.load()
    for y in range(20):
        for x in range(20):
            if a[x, y][3] == 0:
                for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    nx, ny = x+dx, y+dy
                    if 0 <= nx < 20 and 0 <= ny < 20 and a[nx, ny][3] > 0 and a[nx, ny][:3] != OUT[:3]:
                        o[x, y] = OUT; break
    return out

def thick_line(d, p0, p1, col, w=1):
    d.line([p0, p1], fill=C(col), width=w)

icons = {}

# --- Охота ---
def hunt_pack():
    im, d = new()
    # голова волка
    d.polygon([(3,3),(7,7),(12,7),(16,3),(16,10),(14,14),(10,17),(9,17),(5,14),(3,10)], fill=C('grey'))
    d.polygon([(4,5),(6,7),(4,8)], fill=C('dgrey')); d.polygon([(15,5),(13,7),(15,8)], fill=C('dgrey'))
    d.polygon([(7,11),(12,11),(11,16),(8,16)], fill=C('bone'))
    px(d, [(6,10),(7,10)], 'red'); px(d, [(12,10),(13,10)], 'red')
    px(d, [(9,15),(10,15)], 'dred'); px(d, [(9,12),(10,12)], 'dgrey')
    return im
def hunt_snare():
    im, d = new()
    d.arc([2,3,17,22], 180, 360, fill=C('steel'), width=2)
    for x in (5,8,11,14):
        px(d, [(x,7),(x,8)], 'bone')
    d.rectangle([2,12,17,13], fill=C('steel'))
    for x in (4,7,10,13,16):
        px(d, [(x,11)], 'bone')
    d.rectangle([3,14,16,15], fill=C('dsteel'))
    px(d, [(9,16),(10,17),(9,18)], 'dgrey')
    return im
def hunt_spear():
    im, d = new()
    thick_line(d, (3,17), (12,8), 'wood', 2)
    d.polygon([(11,7),(17,2),(13,9)], fill=C('steel'))
    d.polygon([(12,6),(16,3),(13,8)], fill=C('bone'))
    px(d, [(10,10),(11,9),(9,10),(10,11)], 'red')  # тесьма
    return im
def hunt_dive():
    im, d = new()
    d.polygon([(2,3),(9,10),(10,10),(17,3),(13,10),(10,16),(9,16),(6,10)], fill=C('brown'))
    d.polygon([(8,9),(11,9),(10,13),(9,13)], fill=C('bone'))
    px(d, [(9,16),(10,16)], 'gold'); px(d, [(9,17)], 'gold')
    px(d, [(5,1),(5,2),(14,1),(14,2)], 'bone')
    return im

# --- Горн ---
def crucible(d, tilt=False):
    if tilt:
        d.polygon([(3,6),(12,3),(15,10),(7,14)], fill=C('dgrey'))
        d.polygon([(4,6),(12,4),(13,6),(5,9)], fill=C('orange'))
    else:
        d.polygon([(3,4),(14,4),(12,12),(5,12)], fill=C('dgrey'))
        d.rectangle([4,5,13,6], fill=C('orange'))
def forge_spill():
    im, d = new()
    crucible(d, True)
    d.polygon([(3,8),(1,12),(4,12)], fill=C('orange'))
    d.ellipse([3,14,16,18], fill=C('orange')); d.ellipse([6,15,12,17], fill=C('yellow'))
    return im
def forge_overheat():
    im, d = new()
    d.polygon([(9,2),(12,6),(11,14),(8,14),(7,6)], fill=C('red'))
    d.polygon([(9,5),(10,6),(10,12),(9,12)], fill=C('yellow'))
    d.rectangle([5,14,14,15], fill=C('dwood')); d.rectangle([8,16,11,18], fill=C('wood'))
    for x, y in ((3,4),(3,8),(16,5),(16,9)):
        px(d, [(x,y),(x,y+1)], 'orange')
    return im
def forge_anvil():
    im, d = new()
    d.polygon([(2,9),(15,9),(17,8),(17,11),(14,12),(5,12),(3,11)], fill=C('dsteel'))
    d.rectangle([7,12,12,15], fill=C('dsteel')); d.rectangle([5,16,14,17], fill=C('dsteel'))
    d.line([(3,9),(15,9)], fill=C('steel'))
    d.polygon([(8,1),(11,1),(11,4),(13,4),(9,7),(6,4),(8,4)], fill=C('gold'))
    return im
def forge_breath():
    im, d = new()
    d.polygon([(2,8),(6,6),(6,12),(2,11)], fill=C('dwood'))
    d.polygon([(6,8),(13,3),(18,9),(13,16),(6,11)], fill=C('red'))
    d.polygon([(7,9),(12,6),(15,9),(12,13),(7,10)], fill=C('orange'))
    d.polygon([(8,9),(11,8),(12,9),(11,11)], fill=C('yellow'))
    return im
def forge_scythe():
    im, d = new()
    thick_line(d, (5,18), (11,2), 'wood', 1)
    d.line([(4,17),(10,1)], fill=C('dwood'))
    d.polygon([(10,2),(17,4),(18,9),(14,6),(11,5)], fill=C('orange'))
    d.line([(12,3),(16,5)], fill=C('yellow'))
    px(d, [(16,11),(13,9)], 'orange')
    return im
def forge_pour():
    im, d = new()
    d.polygon([(2,2),(10,2),(11,6),(3,8)], fill=C('dgrey'))
    d.line([(3,3),(10,3)], fill=C('orange'))
    d.rectangle([10,6,11,13], fill=C('orange')); px(d, [(10,7),(10,9)], 'yellow')
    d.polygon([(5,14),(16,14),(15,18),(6,18)], fill=C('dsteel'))
    d.rectangle([6,14,15,15], fill=C('orange'))
    return im

# --- Летопись ---
def chron_line():
    im, d = new()
    d.polygon([(16,1),(18,3),(8,13),(6,13),(6,11)], fill=C('bone'))
    d.line([(15,3),(8,11)], fill=C('dparch'))
    px(d, [(5,14),(4,15)], 'ink')
    d.line([(2,17),(17,17)], fill=C('mem')); d.line([(2,18),(10,18)], fill=C('dmem'))
    return im
def chron_seal():
    im, d = new()
    d.ellipse([2,2,17,17], fill=C('wax')); d.ellipse([4,4,15,15], fill=C('dwax'))
    d.ellipse([5,5,14,14], fill=C('wax'))
    d.line([(9,6),(9,10)], fill=C('gold')); d.line([(9,10),(12,12)], fill=C('gold'))
    px(d, [(15,1),(17,3),(1,16)], 'wax')
    return im
def chron_hourglass():
    im, d = new()
    d.rectangle([3,1,16,2], fill=C('wood')); d.rectangle([3,17,16,18], fill=C('wood'))
    d.polygon([(4,3),(15,3),(10,9),(10,10),(15,16),(4,16),(9,10),(9,9)], fill=C('mem'))
    d.polygon([(6,4),(13,4),(10,8),(9,8)], fill=C('gold'))
    d.polygon([(6,15),(13,15),(10,12),(9,12)], fill=C('gold'))
    px(d, [(9,10),(9,11)], 'gold')
    return im
def chron_ink():
    im, d = new()
    d.ellipse([4,6,15,17], fill=C('ink'))
    for (x,y,r) in ((3,4,1),(16,5,1),(2,13,1),(17,14,1),(10,2,1)):
        d.ellipse([x-r,y-r,x+r,y+r], fill=C('ink'))
    d.ellipse([6,8,10,11], fill=C('ink2'))
    px(d, [(7,9)], 'mem')
    return im
def chron_erase():
    im, d = new()
    d.rectangle([3,2,14,17], fill=C('parch'))
    for y in (5,8,11,14):
        d.line([(5,y),(12,y)], fill=C('dparch'))
    d.polygon([(10,12),(15,7),(18,10),(13,15)], fill=C('red'))
    d.polygon([(10,12),(12,10),(15,13),(13,15)], fill=C('bone'))
    return im
def chron_memory():
    im, d = new()
    # силуэт-эхо и настоящий
    d.ellipse([2,3,7,8], fill=C('dmem')); d.polygon([(1,9),(8,9),(8,17),(1,17)], fill=C('dmem'))
    d.ellipse([10,2,16,8], fill=C('mem')); d.polygon([(9,9),(17,9),(17,18),(9,18)], fill=C('mem'))
    px(d, [(12,5),(14,5)], 'white')
    d.line([(9,12),(17,12)], fill=C('bone'))
    return im

order = ['hunt_pack','hunt_snare','hunt_spear','hunt_dive','forge_spill','forge_overheat','forge_anvil','forge_breath',
         'forge_scythe','forge_pour','chron_line','chron_seal','chron_hourglass','chron_ink','chron_erase','chron_memory']
atlas = Image.new('RGBA', (90, 90), (0,0,0,0))
rects = {}
for i, name in enumerate(order):
    im = outline(globals()[name]())
    x, y = 2 + (i % 4) * 22, 2 + (i // 4) * 22
    atlas.paste(im, (x, y))
    rects[name] = (x, y)
atlas.save('assets/abilities345_atlas.png')
json.dump(rects, open('tools/icons/rects.json','w'))
# превью x8 на тёмной плашке с подписями
from PIL import ImageFont
S = 6
pv = Image.new('RGBA', (4*(20*S+20)+20, 4*(20*S+40)+20), (30,22,19,255))
dd = ImageDraw.Draw(pv)
try:
    font = ImageFont.truetype('/usr/share/fonts/liberation/LiberationSans-Regular.ttf', 13)
except Exception:
    font = ImageFont.load_default()
for i, name in enumerate(order):
    x, y = rects[name]
    tile = atlas.crop((x, y, x+20, y+20)).resize((20*S, 20*S), Image.NEAREST)
    cx, cy = 20 + (i % 4) * (20*S+20), 20 + (i // 4) * (20*S+40)
    dd.rectangle([cx-4, cy-4, cx+20*S+3, cy+20*S+3], fill=(52,36,24,255))
    pv.alpha_composite(tile, (cx, cy))
    dd.text((cx, cy+20*S+6), name, fill=(248,240,222,255), font=font)
pv.save('tools/icons/abilities345_preview.png')
print(rects)
