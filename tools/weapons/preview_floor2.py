"""Предпросмотр оружия этажа 2 без Blender: изометрическая отрисовка вокселей (PIL)."""
import math, sys
from PIL import Image, ImageDraw, ImageFont
import weapons3d_floor2 as F

def hex2rgb(h):
    h = h.lstrip('!#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def render(v, yaw=35, pitch=22, s=7, size=(380, 640), bg=(31, 42, 40)):
    img = Image.new('RGB', size, bg); d = ImageDraw.Draw(img)
    ya, pa = math.radians(yaw), math.radians(pitch)
    def proj(x, y, z):
        x1 = x * math.cos(ya) + z * math.sin(ya); z1 = -x * math.sin(ya) + z * math.cos(ya)
        y1 = y * math.cos(pa) - z1 * math.sin(pa); z2 = y * math.sin(pa) + z1 * math.cos(pa)
        return x1, y1, z2
    lo, hi = v.bounds(); cy = (lo[1] + hi[1]) / 2; cx = (lo[0] + hi[0]) / 2
    items = []
    for (i, j, k), c in v.v.items():
        px, py, pz = proj(i + 0.5 - cx, j + 0.5 - cy, k + 0.5)
        items.append((pz, i, j, k, c))
    items.sort()
    faces = [((0, 1, 0), 1.0, [(0, 1, 0), (1, 1, 0), (1, 1, 1), (0, 1, 1)]),
             ((1, 0, 0), 0.8, [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
             ((-1, 0, 0), 0.62, [(0, 0, 0), (0, 1, 0), (0, 1, 1), (0, 0, 1)]),
             ((0, 0, 1), 0.88, [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]),
             ((0, 0, -1), 0.7, [(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)])]
    W_, H_ = size
    for pz, i, j, k, c in items:
        neon = c.startswith('!'); rgb = hex2rgb(c)
        for n, sh, quad in faces:
            nx, ny, nz_ = n
            vx, vy, vz = proj(nx, ny, nz_)
            if vz <= 0.02: continue          # грань смотрит от камеры
            col = rgb if neon else tuple(min(255, int(ch * sh)) for ch in rgb)
            pts = []
            for (a, b, c2) in quad:
                x, y, z = proj(i + a - cx, j + b - cy, k + c2)
                pts.append((W_ / 2 + x * s, H_ * 0.52 - y * s))
            d.polygon(pts, fill=col)
    return img

def sheet(path='preview_floor2.png'):
    names = [w[0] for w in F.WEAPONS]
    cell = (380, 640); cols = 4; rows = 2
    sh = Image.new('RGB', (cell[0] * cols, cell[1] * rows), (24, 32, 30))
    dr = ImageDraw.Draw(sh)
    for n, (wid, fn, rar) in enumerate(F.WEAPONS):
        v = fn(); img = render(v, s=7 if wid not in ('gardener_shears', 'reaper_blade') else 5.6, size=cell)
        sh.paste(img, ((n % cols) * cell[0], (n // cols) * cell[1]))
        dr.text(((n % cols) * cell[0] + 10, (n // cols) * cell[1] + 8), f'{wid} [{rar}]', fill=(230, 240, 235))
    sh.save(path); print('saved', path)

if __name__ == '__main__':
    sheet(sys.argv[1] if len(sys.argv) > 1 else 'preview_floor2.png')
