"""Экспорт брони мага: python3 export_mage.py <out>
  mage_armor.obj/.mtl + mage_armor_palette.png — объект = будущая MeshPart (HA_* палитра, HG_* неон);
  mage_armor.glb — для Studio Import 3D (вершины повёрнуты на 180°, как у оружия и брони воина);
  MageArmorMeshData.lua — смещения/размеры в стадах в осях частей R15 (как HeroArmorMeshData);
  preview_<set>.obj — комплект на манекене (для рендера в Blender)."""
import os, sys, json
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import magekit as K
import mage_sets as S

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'assets')
os.makedirs(OUT, exist_ok=True)
CELL = 16

PART_SIZE = {'Head': (1.2, 1.2, 1.2), 'UpperTorso': (2, 1.6, 1), 'LowerTorso': (2, 0.4, 1), 'RightUpperArm': (1, 1.169, 1),
             'LeftUpperArm': (1, 1.169, 1), 'RightLowerArm': (1, 1.052, 1), 'LeftLowerArm': (1, 1.052, 1), 'RightHand': (1, 0.3, 1),
             'LeftHand': (1, 0.3, 1), 'RightUpperLeg': (1, 1.217, 1), 'LeftUpperLeg': (1, 1.217, 1), 'RightLowerLeg': (1, 1.193, 1),
             'LeftLowerLeg': (1, 1.193, 1), 'RightFoot': (1, 0.3, 1), 'LeftFoot': (1, 0.3, 1)}
LAYOUT = {'Head': (0, 5.31, 0), 'UpperTorso': (0, 3.91, 0), 'LowerTorso': (0, 2.91, 0),
          'RightUpperArm': (1.52, 4.125, 0), 'LeftUpperArm': (-1.52, 4.125, 0), 'RightLowerArm': (1.52, 3.014, 0),
          'LeftLowerArm': (-1.52, 3.014, 0), 'RightHand': (1.52, 2.338, 0), 'LeftHand': (-1.52, 2.338, 0),
          'RightUpperLeg': (0.5, 2.1015, 0), 'LeftUpperLeg': (-0.5, 2.1015, 0), 'RightLowerLeg': (0.5, 0.8965, 0),
          'LeftLowerLeg': (-0.5, 0.8965, 0), 'RightFoot': (0.5, 0.15, 0), 'LeftFoot': (-0.5, 0.15, 0)}


def body_color(part, body):
    if part == 'Head':
        return body['skin']
    if part.endswith('Hand') or part.endswith('Foot') or part.endswith('LowerArm'):
        return body['leather']
    return body['cloth']


def faces(cells):
    """Жадное слияние граней одного цвета: (квад в ячейках, нормаль, цвет)."""
    out = []
    for axis in range(3):
        ua, wa = [a for a in range(3) if a != axis]
        for sign in (1, -1):
            layers = {}
            for key, c in cells.items():
                nb = list(key); nb[axis] += sign
                if tuple(nb) in cells:
                    continue
                plane = key[axis] + (1 if sign > 0 else 0)
                layers.setdefault(plane, {})[(key[ua], key[wa])] = c
            for plane, cl in layers.items():
                used = set()
                for (u, w) in sorted(cl):
                    if (u, w) in used:
                        continue
                    c = cl[(u, w)]
                    u1 = u
                    while (u1 + 1, w) in cl and (u1 + 1, w) not in used and cl[(u1 + 1, w)] == c:
                        u1 += 1
                    w1 = w
                    while all((uu, w1 + 1) in cl and (uu, w1 + 1) not in used and cl[(uu, w1 + 1)] == c for uu in range(u, u1 + 1)):
                        w1 += 1
                    for uu in range(u, u1 + 1):
                        for ww in range(w, w1 + 1):
                            used.add((uu, ww))
                    q = []
                    for (a, b) in ((u, w), (u1 + 1, w), (u1 + 1, w1 + 1), (u, w1 + 1)):
                        p = [0, 0, 0]; p[axis] = plane; p[ua] = a; p[wa] = b; q.append(p)
                    d = [0, 0, 0]; d[axis] = sign
                    out.append((q, d, c))
    return out


def quads(cells, shift=(0, 0, 0)):
    res = []
    for q, d, c in faces(cells):
        P = [np.array(p, float) * K.V + np.array(shift) for p in q]
        if np.dot(np.array(d, float), np.cross(P[1] - P[0], P[2] - P[0])) < 0:
            P = P[::-1]
        res.append((P, d, c))
    return res


def V3(v):
    return 'Vector3.new(%.4f, %.4f, %.4f)' % tuple(v)


def C3(h):
    h = h.lstrip('!').lstrip('#')
    return 'Color3.fromRGB(%d, %d, %d)' % tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def bbox(cells):
    a = np.array(list(cells), float)
    lo = a.min(0) * K.V; hi = (a.max(0) + 1) * K.V
    return (lo + hi) / 2, hi - lo


class Obj:
    def __init__(s, header):
        s.lines = list(header); s.vi = s.vti = s.vni = 1

    def add(s, name, qs, uv=None):
        s.lines.append(f'o {name}')
        if uv:
            s.lines.append('usemtl palette')
        for P, d, c in qs:
            idx = []
            for p in P:
                s.lines.append('v %.4f %.4f %.4f' % tuple(p)); idx.append(s.vi); s.vi += 1
            s.lines.append('vn %d %d %d' % tuple(d))
            if uv:
                u, w = uv[c]
                s.lines.append('vt %.5f %.5f' % (u, w))
                s.lines.append('f ' + ' '.join(f'{i}/{s.vti}/{s.vni}' for i in idx)); s.vti += 1
            else:
                s.lines.append('f ' + ' '.join(f'{i}//{s.vni}' for i in idx))
            s.vni += 1


def palette(colors, path):
    cols = 8; rows = (len(colors) + cols - 1) // cols
    W = cols * CELL; Hh = 1 << (rows * CELL - 1).bit_length()
    im = Image.new('RGB', (W, Hh), (255, 0, 255)); px = im.load(); uv = {}
    for i, c in enumerate(colors):
        cx, cy = i % cols, i // cols
        rgb = tuple(int(c[k:k + 2], 16) for k in (1, 3, 5))
        for x in range(CELL):
            for y in range(CELL):
                px[cx * CELL + x, cy * CELL + y] = rgb
        uv[c] = ((cx * CELL + CELL / 2) / W, 1 - (cy * CELL + CELL / 2) / Hh)
    im.save(path)
    return uv


def split(piece):
    base = {}; glows = {}
    for k, c in piece.c.items():
        if c.startswith('!'):
            glows.setdefault(c[1:].upper(), {})[k] = c[1:].upper()
        else:
            base[k] = c.upper()
    return base, glows


def main():
    sets = S.build_all()
    colors = sorted({c for st in sets for p in st['pieces'] for c in split(p)[0].values()}
                    | {c for st in sets for c in st['body'].values()})
    uv = palette(colors, os.path.join(OUT, 'mage_armor_palette.png'))
    obj = Obj(['# Клинок Памяти — броня мага. Оси частей R15, стады.', 'mtllib mage_armor.mtl'])
    glow_json = {}
    lua = ['-- Сгенерировано tools/mage-armor/export_mage.py. Не править руками: правки — в генераторе (mage_sets.py).',
           '-- Броня мага из мешей (mage_armor.glb): шляпы (слот helm) и накидки (слот armor) с плащами.',
           '-- Формат как у HeroArmorMeshData: offset/size — в стадах в осях части тела R15 (X вправо, Y вверх,',
           '-- перед −Z) при Part.Size.Y = refY. HeroArmorBuilder подмешивает эти комплекты к броне воина.',
           '-- Ноги, кисти и большая часть рук не закрыты — виден основной облик героя (body).',
           'return {', f'\tvoxel = {K.V:.4f},', '\tsets = {']
    report = []
    for st in sets:
        sid = st['id']
        lua.append(f'\t\t{sid} = {{')
        lua.append(f'\t\t\trarity = "{st["rarity"]}",')
        b = st['body']
        lua.append(f'\t\t\tbody = {{ cloth = {C3(b["cloth"])}, leather = {C3(b["leather"])}, skin = {C3(b["skin"])} }},')
        prev = Obj(['# preview ' + sid, 'mtllib mage_armor.mtl'])
        # манекен: блоки тела основного облика
        for part, size in PART_SIZE.items():
            sz = np.array((1.15, 1.15, 1.15)) if part == 'Head' else np.array(size) * np.array((1.04, 1, 1.04))
            c = body_color(part, b)
            lo = np.array(LAYOUT[part]) - sz / 2; hi = lo + sz
            P8 = lambda x, y, z: np.array([(lo, hi)[x][0], (lo, hi)[y][1], (lo, hi)[z][2]])
            qs = []
            for d, idxs in (((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]), ((-1, 0, 0), [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)]),
                            ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]), ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
                            ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]), ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)])):
                qs.append(([P8(*t) for t in idxs], d, c))
            prev.add('Body_' + part, qs, uv)
        tris = 0
        for slot in ('helm', 'armor'):
            lua.append(f'\t\t\t{slot} = {{')
            for p in [p for p in st['pieces'] if p.slot == slot]:
                base, glows = split(p)
                items = [(f'HA_{sid}_{p.name}', base, None)] + [(f'HG_{sid}_{p.name}_{n + 1}', g, gc) for n, (gc, g) in enumerate(sorted(glows.items()))]
                for name, cells, gc in items:
                    if not cells:
                        continue
                    ctr, size = bbox(cells)
                    qs = quads(cells)
                    tris += 2 * len(qs)
                    obj.add(name, qs, None if gc else uv)
                    prev.add(name if not gc else 'G' + name, quads(cells, LAYOUT[p.part]), None if gc else uv)
                    g = f', glow = {C3(gc)}' if gc else ''
                    lua.append(f'\t\t\t\t{{ name = "{name}", part = "{p.part}", offset = {V3(ctr)}, size = {V3(size)}{g} }},')
                    if gc:
                        glow_json[name] = gc; glow_json['G' + name] = gc
            lua.append('\t\t\t},')
        lua.append('\t\t\tcape = {')
        for p in sorted([p for p in st['pieces'] if p.slot == 'cape'], key=lambda q: q.order):
            base, glows = split(p)
            name = f'HA_{sid}_{p.name}'
            ctr, size = bbox(base)
            qs = quads(base); tris += 2 * len(qs)
            obj.add(name, qs, uv); prev.add(name, quads(base, LAYOUT['UpperTorso']), uv)
            lua.append(f'\t\t\t\t{{ name = "{name}", offset = {V3(ctr)}, size = {V3(size)}, hinge = {V3(p.hinge)}, glows = {{')
            for n, (gc, g) in enumerate(sorted(glows.items())):
                gname = f'HG_{sid}_{p.name}_{n + 1}'
                gctr, gsize = bbox(g)
                gq = quads(g); tris += 2 * len(gq)
                obj.add(gname, gq); prev.add('G' + gname, quads(g, LAYOUT['UpperTorso']))
                glow_json[gname] = gc; glow_json['G' + gname] = gc
                lua.append(f'\t\t\t\t\t{{ name = "{gname}", offset = {V3(gctr)}, size = {V3(gsize)}, glow = {C3(gc)} }},')
            lua.append('\t\t\t\t} },')
        lua.append('\t\t\t},')
        lua.append('\t\t},')
        open(os.path.join(OUT, f'preview_{sid}.obj'), 'w').write('\n'.join(prev.lines) + '\n')
        report.append(f'{sid}: деталей {len(st["pieces"])}, треугольников {tris}')
    lua += ['\t},', '}', '']
    open(os.path.join(OUT, 'mage_armor.obj'), 'w').write('\n'.join(obj.lines) + '\n')
    open(os.path.join(OUT, 'mage_armor.mtl'), 'w').write('newmtl palette\nKd 1 1 1\nmap_Kd mage_armor_palette.png\n')
    open(os.path.join(OUT, 'MageArmorMeshData.lua'), 'w').write('\n'.join(lua))
    json.dump(glow_json, open(os.path.join(OUT, 'glow.json'), 'w'), indent=1)
    import obj_to_glb as G
    objs = G.read_obj(os.path.join(OUT, 'mage_armor.obj'))
    png = open(os.path.join(OUT, 'mage_armor_palette.png'), 'rb').read()
    G.write_glb(os.path.join(OUT, 'mage_armor.glb'), [(o['name'], o['pos'], o['nrm'], o['uv'], o['idx']) for o in objs], png, scene='mage_armor')
    print('\n'.join(report)); print('цветов', len(colors), 'мешей', len(objs))


if __name__ == '__main__':
    main()
