"""Экспорт оружия этажа 2 в Roblox:
  weapons_floor2.obj/.mtl + weapons_palette_floor2.png — каждый объект = будущая MeshPart (оружие и его неон отдельно);
  WeaponMeshDataFloor2.lua — смещения и размеры деталей относительно хвата (Grip), точки клинка;
  weapons_floor2.blend — те же модели в Blender (для правок руками).
Оси Roblox: хват в (0,0,0), клинок вверх по +Y, X поперёк, Z — толщина."""
import os, sys, json
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vox
import weapons3d_floor2 as WP

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'export_floor2')
os.makedirs(OUT, exist_ok=True)

# id: (масштаб, y-воксель кисти). Стартовые значения, подгоняются по месту, как на этаже 1.
SPEC = {
    'garden_machete': (1.0, -6),
    'reed_saber': (0.9, -6),
    'mud_mallet': (0.9, -5),
    'thorn_blade': (0.82, -6),
    'root_hammer': (0.88, -5),
    'reaper_blade': (0.78, -6),
    'tidal_hammer': (0.82, -5),
    'gardener_shears': (0.7, -8),
}
CELL = 16

def palette(colors):
    cols = 8; rows = (len(colors) + cols - 1) // cols
    W = cols * CELL; H = 1 << (rows * CELL - 1).bit_length()
    im = Image.new('RGB', (W, H), (255, 0, 255)); px = im.load(); uv = {}
    for i, c in enumerate(colors):
        cx, cy = i % cols, i // cols
        rgb = tuple(int(c[k:k + 2], 16) for k in (1, 3, 5))
        for x in range(CELL):
            for y in range(CELL): px[cx * CELL + x, cy * CELL + y] = rgb
        uv[c] = ((cx * CELL + CELL / 2) / W, 1 - (cy * CELL + CELL / 2) / H)
    im.save(os.path.join(OUT, 'weapons_palette_floor2.png'))
    return uv

def split(v):
    base = vox.Vox(v.size); glows = {}
    for k, c in v.v.items():
        if c.startswith('!'): glows.setdefault(c[1:].upper(), vox.Vox(v.size)).v[k] = 'x'
        else: base.v[k] = c.upper()
    return base, glows

def quads(v, origin, scale):
    s = v.size * scale; out = []
    for quad, d, c in v.faces():
        P = [(np.array(p, float) - origin) * s for p in quad]
        if np.dot(np.array(d, float), np.cross(P[1] - P[0], P[2] - P[0])) < 0: P = P[::-1]
        out.append((P, d, c))
    return out

def main():
    models = {wid: fn() for wid, fn, _ in WP.WEAPONS}
    colors = sorted({c.upper() for v in models.values() for c in v.v.values() if not c.startswith('!')})
    uv = palette(colors)
    obj = ['# Клинок Памяти — оружие этажа 1. Хват в (0,0,0), клинок по +Y. Единицы — стады.', 'mtllib weapons_floor2.mtl']
    vi = vti = vni = 1
    lua = ['-- Сгенерировано export_weapons_floor2.py (Claude). Меши оружия этажа 2: MeshPart из weapons_floor2.obj.',
           '-- offset/size — в стадах относительно хвата (Attachment Grip у Root). Клинок по +Y.',
           '-- Сборщик AssembleWeapons.lua кладёт импортированные меши в ReplicatedStorage.WeaponMeshes;',
           '-- VoxelWeaponBuilder строит модель из них, а без них — по-старому из вокселей.',
           'return {']
    stats = {}
    for wid, fn, rarity in WP.WEAPONS:
        v = models[wid]; scale, gy = SPEC[wid]
        origin = np.array([1.0, gy + 0.5, 1.0])          # центр рукояти 2×2 (x,z = 0..1)
        base, glows = split(v)
        parts = [('mesh', f'W_{wid}', base, None)]
        for i, (gc, gv) in enumerate(sorted(glows.items())):
            parts.append(('glow', f'G{i + 1}_{wid}', gv, gc))
        lo_all, hi_all = v.bounds()
        tip = (hi_all[1] + 1 - origin[1]) * v.size * scale
        bottom = (lo_all[1] - origin[1]) * v.size * scale
        # верх гарды / низ клинка: первый ряд выше кисти шире 4 вокселей
        guard_y = None
        for y in range(gy, hi_all[1] + 1):
            xs = [k[0] for k in v.v if k[1] == y]
            if xs and max(xs) - min(xs) >= 5: guard_y = y; break
        base_y = ((guard_y if guard_y is not None else gy + 4) + 1 - origin[1]) * v.size * scale
        lua.append(f'\t{wid} = {{')
        lua.append(f'\t\tscale = {scale}, rarity = "{rarity}",')
        lua.append(f'\t\tbladeBase = {base_y:.3f}, bladeTip = {tip:.3f}, bottom = {bottom:.3f},')
        lua.append('\t\tobjects = {')
        tris = 0
        for kind, name, vv, gc in parts:
            qs = quads(vv, origin, scale)
            allp = np.array([p for q in qs for p in q[0]]); lo, hi = allp.min(0), allp.max(0); ctr = (lo + hi) / 2
            obj.append(f'o {name}')
            if kind == 'mesh': obj.append('usemtl palette')
            for (P, d, c) in qs:
                idx = []
                for p in P:
                    obj.append(f'v {p[0]:.4f} {p[1]:.4f} {p[2]:.4f}'); idx.append(vi); vi += 1
                obj.append(f'vn {d[0]} {d[1]} {d[2]}')
                if kind == 'mesh':
                    u, w = uv[c]; obj.append(f'vt {u:.5f} {w:.5f}')
                    obj.append('f ' + ' '.join(f'{i}/{vti}/{vni}' for i in idx)); vti += 1
                else:
                    obj.append('f ' + ' '.join(f'{i}//{vni}' for i in idx))
                vni += 1
            tris += len(qs) * 2
            g = f', glow = Color3.fromHex("{gc}")' if gc else ''
            sz = hi - lo
            lua.append(f'\t\t\t{{ name = "{name}", role = "{kind}", offset = Vector3.new({ctr[0]:.4f}, {ctr[1]:.4f}, {ctr[2]:.4f}), '
                       f'size = Vector3.new({sz[0]:.4f}, {sz[1]:.4f}, {sz[2]:.4f}){g} }},')
        lua.append('\t\t},')
        lua.append('\t},')
        stats[wid] = dict(tris=tris, length=round(tip - bottom, 2), objects=len(parts))
    lua += ['}', '']
    open(os.path.join(OUT, 'weapons_floor2.obj'), 'w').write('\n'.join(obj) + '\n')
    open(os.path.join(OUT, 'weapons_floor2.mtl'), 'w').write('newmtl palette\nKd 1 1 1\nmap_Kd weapons_palette_floor2.png\n')
    open(os.path.join(OUT, 'WeaponMeshDataFloor2.lua'), 'w', newline='\r\n').write('\n'.join(lua))
    json.dump(stats, open(os.path.join(OUT, 'stats.json'), 'w'), indent=1)
    # glb для Import 3D (OBJ импорт сливает объекты в одну деталь): узел = объект OBJ
    import obj_to_glb as G
    objs = G.read_obj(os.path.join(OUT, 'weapons_floor2.obj'))
    png = open(os.path.join(OUT, 'weapons_palette_floor2.png'), 'rb').read()
    G.write_glb(os.path.join(OUT, 'weapons_floor2.glb'), [(o['name'], o['pos'], o['nrm'], o['uv'], o['idx']) for o in objs], png, scene='weapons_floor2')
    print('glb nodes', [o['name'] for o in objs])
    print(json.dumps(stats, indent=1), 'colors', len(colors))
    try:
        blend(models)
    except ImportError:
        print('bpy не установлен: .blend не создан (pip install bpy, затем запустить ещё раз). Остальные файлы готовы.')

def blend(models):
    """.blend с теми же моделями (материал на цвет, неон — Emission) для правок в Blender."""
    import bpy
    import render_bl as RB
    RB.setup(res=(1200, 800), samples=32, sky=(0.07, 0.06, 0.06), amb=0.8)
    x = 0.0
    for wid, fn, _ in WP.WEAPONS:
        scale, gy = SPEC[wid]
        M = np.eye(4); M[:3, :3] *= scale
        M[:3, 3] = np.array([x, 0, 0]) - np.array([1.0, gy + 0.5, 1.0]) * WP.VS * scale
        vox.to_blender(models[wid], M, name=wid)
        x += 4.0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'weapons_floor2.blend'))

if __name__ == '__main__':
    main()
