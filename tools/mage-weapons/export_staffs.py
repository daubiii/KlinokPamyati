"""Экспорт посохов мага в Roblox (тот же формат, что export_weapons_floors.py у оружия воина):
  python3 export_staffs.py [папка] [id ...]   (без id — все 37 посохов)
  staffs_mage.obj/.mtl + staffs_palette_mage.png — каждый объект = будущая MeshPart (посох и его неон отдельно);
  staffs_mage.glb — для Studio Import 3D (узел на объект, вершины повёрнуты на 180°, как у оружия этажей 2–5);
  WeaponMeshDataMage.lua — смещения и размеры деталей относительно хвата (Grip), точки посоха:
    bladeBase — низ навершия, bladeTip — верх, focus — центр светящегося «камня» навершия
    (отсюда срываются снаряды: VoxelWeaponBuilder ставит туда BladeTip), bottom — подток.
Масштаб и точка кисти — SPEC в staffs3d.py. Оси Roblox: хват в (0,0,0), посох вверх по +Y."""
import os, sys, json
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vox
import staffs3d as WP

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'export')
ONLY = set(sys.argv[2:])
os.makedirs(OUT, exist_ok=True)
TAG = 'mage'
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
    im.save(os.path.join(OUT, f'staffs_palette_{TAG}.png'))
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


def components(keys):
    left = set(keys); comps = []
    while left:
        start = left.pop(); stack = [start]; comp = [start]
        while stack:
            x, y, z = stack.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    for dz in (-1, 0, 1):
                        n = (x + dx, y + dy, z + dz)
                        if n in left:
                            left.remove(n); stack.append(n); comp.append(n)
        comps.append(comp)
    comps.sort(key=len, reverse=True)
    return comps


def focus_of(wid, v, guard_y):
    """Центр «камня» навершия: FOCUS[id] (воксели) или центр самого крупного неона выше низа навершия."""
    if wid in getattr(WP, 'FOCUS', {}):
        x, y, z = WP.FOCUS[wid]
        return np.array([x + 0.5, y + 0.5, z + 0.5])
    glow = [k for k, c in v.v.items() if c.startswith('!') and k[1] >= guard_y]
    if glow:
        comp = components(glow)[0]
        return np.array(comp, float).mean(0) + 0.5
    (x0, y0, z0), (x1, y1, z1) = v.bounds()
    return np.array([1.0, y1 + 1.0, 1.0])


def drop_specks(v, limit=4):
    """Убрать только мелкие оторванные крошки без неона (меньше limit вокселей). Парящий неон
    (капли, искры, шары в клетках) — часть навершия: остаётся в своей MeshPart свечения."""
    dropped = 0
    for comp in components(list(v.v))[1:]:
        if len(comp) < limit and not any(v.v[k].startswith('!') for k in comp):
            for k in comp: del v.v[k]
            dropped += len(comp)
    return dropped


def build():
    out = {}
    for wid, fn, _ in WP.WEAPONS:
        if ONLY and wid not in ONLY: continue
        v = fn(); n = drop_specks(v)
        if n: print(f'{wid}: убрано {n} оторванных вокселей')
        out[wid] = v
    return out


def main():
    models = build()
    order = [w for w, _, _ in WP.WEAPONS if w in models]
    colors = sorted({c.upper() for v in models.values() for c in v.v.values() if not c.startswith('!')})
    uv = palette(colors)
    obj = ['# Клинок Памяти — посохи мага (этажи 1–5). Хват в (0,0,0), посох по +Y. Единицы — стады.', f'mtllib staffs_{TAG}.mtl']
    vi = vti = vni = 1
    lua = ['-- Сгенерировано tools/mage-weapons/export_staffs.py. Меши посохов мага: MeshPart из staffs_mage.glb.',
           '-- offset/size — в стадах относительно хвата (Attachment Grip у Root). Посох по +Y.',
           '-- bladeBase — низ навершия, bladeTip — верх посоха, focus — центр светящегося камня навершия',
           '-- (VoxelWeaponBuilder ставит туда BladeTip: оттуда срываются снаряды и заклинания).',
           '-- Сборщик tools/mage-weapons/AssembleMageWeapons.lua кладёт импортированные меши в',
           '-- ReplicatedStorage.WeaponMeshes; без них VoxelWeaponBuilder строит запасной воксельный посох.',
           'return {']
    stats = {}; glow_names = {}
    rarity_of = {w: r for w, _, r in WP.WEAPONS}
    for wid in order:
        rarity = rarity_of[wid]
        v = models[wid]; scale, gy = WP.SPEC[wid]
        origin = np.array([1.0, gy + 0.5, 1.0])
        base, glows = split(v)
        parts = [('mesh', f'W_{wid}', base, None)]
        for i, (gc, gv) in enumerate(sorted(glows.items())):
            parts.append(('glow', f'G{i + 1}_{wid}', gv, gc)); glow_names[f'G{i + 1}_{wid}'] = '#' + gc.lstrip('#')
        lo_all, hi_all = v.bounds()
        s = v.size * scale
        tip = (hi_all[1] + 1 - origin[1]) * s
        bottom = (lo_all[1] - origin[1]) * s
        guard_y = WP.GUARD[wid]
        base_y = (guard_y - origin[1]) * s
        f = (focus_of(wid, v, guard_y) - origin) * s
        lua.append(f'\t{wid} = {{')
        lua.append(f'\t\tscale = {scale}, rarity = "{rarity}",')
        lua.append(f'\t\tbladeBase = {base_y:.3f}, bladeTip = {tip:.3f}, bottom = {bottom:.3f},')
        lua.append(f'\t\tfocus = Vector3.new({f[0]:.4f}, {f[1]:.4f}, {f[2]:.4f}),')
        bk = np.array([k for k in v.v if k[1] >= guard_y] or list(v.v.keys()), dtype=float)
        alo = (bk.min(0) - origin) * s; ahi = (bk.max(0) + 1 - origin) * s
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
        stats[wid] = dict(tris=tris, length=round(tip - bottom, 2), tip=round(tip, 2), bottom=round(bottom, 2),
                          objects=len(parts), voxels=len(v.v))
    lua += ['}', '']
    open(os.path.join(OUT, f'staffs_{TAG}.obj'), 'w').write('\n'.join(obj) + '\n')
    open(os.path.join(OUT, f'staffs_{TAG}.mtl'), 'w').write(f'newmtl palette\nKd 1 1 1\nmap_Kd staffs_palette_{TAG}.png\n')
    open(os.path.join(OUT, 'WeaponMeshDataMage.lua'), 'w', newline='\n').write('\n'.join(lua))
    json.dump(stats, open(os.path.join(OUT, 'stats.json'), 'w'), indent=1)
    json.dump(glow_names, open(os.path.join(OUT, f'staffs_{TAG}_glow.json'), 'w'), indent=1)
    json.dump(order, open(os.path.join(OUT, 'order.json'), 'w'))
    json.dump(rarity_of, open(os.path.join(OUT, 'rarity.json'), 'w'))
    import obj_to_glb as G
    objs = G.read_obj(os.path.join(OUT, f'staffs_{TAG}.obj'))
    png = open(os.path.join(OUT, f'staffs_palette_{TAG}.png'), 'rb').read()
    G.write_glb(os.path.join(OUT, f'staffs_{TAG}.glb'), [(o['name'], o['pos'], o['nrm'], o['uv'], o['idx']) for o in objs], png, scene=f'staffs_{TAG}')
    tot = sum(s_['tris'] for s_ in stats.values())
    print(f'посохов {len(order)}, треугольников {tot}, цветов {len(colors)}, мешей {sum(s_["objects"] for s_ in stats.values())}')


if __name__ == '__main__':
    main()
