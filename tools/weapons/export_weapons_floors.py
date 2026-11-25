"""Экспорт оружия этажей 3–5 в Roblox (тот же формат, что export_weapons_floor2.py):
  python3 export_weapons_floors.py 3 <папка>   (3 | 4 | 5)
  weapons_floorN.obj/.mtl + weapons_palette_floorN.png — каждый объект = будущая MeshPart (оружие и его неон отдельно);
  weapons_floorN.glb — для Studio Import 3D (узел на объект, вершины повёрнуты на 180°, как у этажа 2);
  WeaponMeshDataFloorN.lua — смещения и размеры деталей относительно хвата (Grip), точки клинка.
Масштаб и точка кисти — SPEC в weapons3d_floorN.py. Оси Roblox: хват в (0,0,0), клинок вверх по +Y."""
import os, sys, json, importlib
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vox

FLOOR = int(sys.argv[1]) if len(sys.argv) > 1 else 3
WP = importlib.import_module(f'weapons3d_floor{FLOOR}')
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), f'export_floor{FLOOR}')
os.makedirs(OUT, exist_ok=True)
TAG = f'floor{FLOOR}'
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
    im.save(os.path.join(OUT, f'weapons_palette_{TAG}.png'))
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


def build():
    from weapons3d_common345 import drop_islands
    out = {}
    for wid, fn, _ in WP.WEAPONS:
        v = fn(); n = drop_islands(v)
        if n: print(f'{wid}: убрано {n} парящих вокселей')
        out[wid] = v
    return out


def main():
    models = build()
    colors = sorted({c.upper() for v in models.values() for c in v.v.values() if not c.startswith('!')})
    uv = palette(colors)
    obj = [f'# Клинок Памяти — оружие этажа {FLOOR}. Хват в (0,0,0), клинок по +Y. Единицы — стады.', f'mtllib weapons_{TAG}.mtl']
    vi = vti = vni = 1
    lua = [f'-- Сгенерировано export_weapons_floors.py {FLOOR}. Меши оружия этажа {FLOOR}: MeshPart из weapons_{TAG}.glb.',
           '-- offset/size — в стадах относительно хвата (Attachment Grip у Root). Клинок по +Y.',
           f'-- Сборщик AssembleWeaponsFloors345.lua кладёт импортированные меши в ReplicatedStorage.WeaponMeshes;',
           '-- VoxelWeaponBuilder строит модель из них, а без них — по-старому из вокселей.',
           'return {']
    stats = {}; glow_names = {}
    for wid, fn, rarity in WP.WEAPONS:
        v = models[wid]; scale, gy = WP.SPEC[wid]
        origin = np.array([1.0, gy + 0.5, 1.0])
        base, glows = split(v)
        parts = [('mesh', f'W_{wid}', base, None)]
        for i, (gc, gv) in enumerate(sorted(glows.items())):
            parts.append(('glow', f'G{i + 1}_{wid}', gv, gc)); glow_names[f'G{i + 1}_{wid}'] = '#' + gc.lstrip('#')
        lo_all, hi_all = v.bounds()
        tip = (hi_all[1] + 1 - origin[1]) * v.size * scale
        bottom = (lo_all[1] - origin[1]) * v.size * scale
        guard_y = getattr(WP, 'GUARD', {}).get(wid)
        if guard_y is None:
            for y in range(gy, hi_all[1] + 1):
                xs = [k[0] for k in v.v if k[1] == y]
                if xs and max(xs) - min(xs) >= 5: guard_y = y; break
        base_y = ((guard_y if guard_y is not None else gy + 4) + 1 - origin[1]) * v.size * scale
        lua.append(f'\t{wid} = {{')
        lua.append(f'\t\tscale = {scale}, rarity = "{rarity}",')
        lua.append(f'\t\tbladeBase = {base_y:.3f}, bladeTip = {tip:.3f}, bottom = {bottom:.3f},')
        # Объём ауры: габарит вокселей выше гарды (клинок/боёк/полотно) — в нём VoxelWeaponBuilder
        # рассыпает частицы ауры (шаблоны FX.Weapon.<id> с shape = Box).
        gl = guard_y if guard_y is not None else gy + 4
        bk = np.array([k for k in v.v if k[1] > gl] or list(v.v.keys()), dtype=float)
        alo = (bk.min(0) - origin) * v.size * scale; ahi = (bk.max(0) + 1 - origin) * v.size * scale
        ac = (alo + ahi) / 2; asz = ahi - alo
        lua.append(f'\t\taura = {{ offset = Vector3.new({ac[0]:.4f}, {ac[1]:.4f}, {ac[2]:.4f}), size = Vector3.new({asz[0]:.4f}, {asz[1]:.4f}, {asz[2]:.4f}) }},')
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
        stats[wid] = dict(tris=tris, length=round(tip - bottom, 2), objects=len(parts), voxels=len(v.v))
    lua += ['}', '']
    open(os.path.join(OUT, f'weapons_{TAG}.obj'), 'w').write('\n'.join(obj) + '\n')
    open(os.path.join(OUT, f'weapons_{TAG}.mtl'), 'w').write(f'newmtl palette\nKd 1 1 1\nmap_Kd weapons_palette_{TAG}.png\n')
    open(os.path.join(OUT, f'WeaponMeshDataFloor{FLOOR}.lua'), 'w', newline='\r\n').write('\n'.join(lua))
    json.dump(stats, open(os.path.join(OUT, 'stats.json'), 'w'), indent=1)
    json.dump(glow_names, open(os.path.join(OUT, f'weapons_{TAG}_glow.json'), 'w'), indent=1)
    json.dump([w for w, _, _ in WP.WEAPONS], open(os.path.join(OUT, 'order.json'), 'w'))
    import obj_to_glb as G
    objs = G.read_obj(os.path.join(OUT, f'weapons_{TAG}.obj'))
    png = open(os.path.join(OUT, f'weapons_palette_{TAG}.png'), 'rb').read()
    G.write_glb(os.path.join(OUT, f'weapons_{TAG}.glb'), [(o['name'], o['pos'], o['nrm'], o['uv'], o['idx']) for o in objs], png, scene=f'weapons_{TAG}')
    print(json.dumps(stats), 'colors', len(colors))


if __name__ == '__main__':
    main()
