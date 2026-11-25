"""Экспорт брони этажей 2–5: python3 export_floors.py <out> [этаж ...] [--only id,id]
  armor_floor<N>.glb + armor_floor<N>_palette.png — для Studio Import 3D (по файлу на этаж,
      узел = будущая MeshPart: HA_* палитра, HG_* неон; вершины повёрнуты на 180°, как у мага);
  ArmorFloorsMeshData.lua — смещения/размеры в стадах в осях частей R15 (формат HeroArmorMeshData);
  preview_<set>.obj + glow.json — комплект на манекене для render_floors.py.
Без аргументов этажей — все 2–5."""
import os, sys, json
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'mage-armor'))
args = [a for a in sys.argv[1:]]
OUT = args[0] if args and not args[0].startswith('-') and not args[0].isdigit() else os.path.join(HERE, 'assets')
only = None
if '--only' in args:
    only = set(args[args.index('--only') + 1].split(','))
floors = [int(a) for a in args if a.isdigit()] or [2, 3, 4, 5]
os.makedirs(OUT, exist_ok=True)

_argv = sys.argv
sys.argv = [sys.argv[0], OUT]
import export_mage as E   # helpers: faces/quads/Obj/palette/split/bbox/body_color/PART_SIZE/LAYOUT/V3/C3
sys.argv = _argv
import magekit as K
import floor_sets as S


def piece_lines(lua, obj, prev, st, uv, glow_json):
    sid = st['id']
    tris = 0
    for slot in ('helm', 'armor'):
        lua.append(f'\t\t\t{slot} = {{')
        for p in [p for p in st['pieces'] if p.slot == slot]:
            base, glows = E.split(p)
            items = [(f'HA_{sid}_{p.name}', base, None)] + [(f'HG_{sid}_{p.name}_{n + 1}', g, gc) for n, (gc, g) in enumerate(sorted(glows.items()))]
            for name, cells, gc in items:
                if not cells:
                    continue
                ctr, size = E.bbox(cells)
                qs = E.quads(cells)
                tris += 2 * len(qs)
                obj.add(name, qs, None if gc else uv)
                prev.add(name if not gc else 'G' + name, E.quads(cells, E.LAYOUT[p.part]), None if gc else uv)
                g = f', glow = {E.C3(gc)}' if gc else ''
                lua.append(f'\t\t\t\t{{ name = "{name}", part = "{p.part}", offset = {E.V3(ctr)}, size = {E.V3(size)}{g} }},')
                if gc:
                    glow_json[name] = gc; glow_json['G' + name] = gc
        lua.append('\t\t\t},')
    lua.append('\t\t\tcape = {')
    for p in sorted([p for p in st['pieces'] if p.slot == 'cape'], key=lambda q: q.order):
        base, glows = E.split(p)
        name = f'HA_{sid}_{p.name}'
        ctr, size = E.bbox(base)
        qs = E.quads(base); tris += 2 * len(qs)
        obj.add(name, qs, uv); prev.add(name, E.quads(base, E.LAYOUT['UpperTorso']), uv)
        lua.append(f'\t\t\t\t{{ name = "{name}", offset = {E.V3(ctr)}, size = {E.V3(size)}, hinge = {E.V3(p.hinge)}, glows = {{')
        for n, (gc, g) in enumerate(sorted(glows.items())):
            gname = f'HG_{sid}_{p.name}_{n + 1}'
            gctr, gsize = E.bbox(g)
            gq = E.quads(g); tris += 2 * len(gq)
            obj.add(gname, gq); prev.add('G' + gname, E.quads(g, E.LAYOUT['UpperTorso']))
            glow_json[gname] = gc; glow_json['G' + gname] = gc
            lua.append(f'\t\t\t\t\t{{ name = "{gname}", offset = {E.V3(gctr)}, size = {E.V3(gsize)}, glow = {E.C3(gc)} }},')
        lua.append('\t\t\t\t} },')
    lua.append('\t\t\t},')
    return tris


def body_box(prev, b, uv):
    for part, size in E.PART_SIZE.items():
        sz = np.array((1.15, 1.15, 1.15)) if part == 'Head' else np.array(size) * np.array((1.04, 1, 1.04))
        c = E.body_color(part, b)
        lo = np.array(E.LAYOUT[part]) - sz / 2; hi = lo + sz
        P8 = lambda x, y, z: np.array([(lo, hi)[x][0], (lo, hi)[y][1], (lo, hi)[z][2]])
        qs = []
        for d, idxs in (((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]), ((-1, 0, 0), [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)]),
                        ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]), ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
                        ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]), ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)])):
            qs.append(([P8(*t) for t in idxs], d, c))
        prev.add('Body_' + part, qs, uv)


def main():
    import obj_to_glb as G
    glow_json = {}
    lua = ['-- Сгенерировано tools/armor-floors/export_floors.py. Не править руками: правки — в генераторе (floor_sets.py).',
           '-- Броня этажей 2–5 из мешей (armor_floor<N>.glb): воин — шлем (helm) и латы (armor) с плащом,',
           '-- маг — шляпа (helm) и накидка (armor) с плащом. Формат как у HeroArmorMeshData: offset/size — в стадах',
           '-- в осях части тела R15 (X вправо, Y вверх, перед −Z) при Part.Size.Y = refY.',
           '-- HeroArmorBuilder подмешивает эти комплекты к броне этажа 1.',
           'return {', f'\tvoxel = {K.V:.4f},', '\tsets = {']
    report = []
    for floor in floors:
        sets = S.build_floor(floor, only)
        if not sets:
            continue
        colors = sorted({c for st in sets for p in st['pieces'] for c in E.split(p)[0].values()}
                        | {c for st in sets for c in st['body'].values()})
        pal = os.path.join(OUT, f'armor_floor{floor}_palette.png')
        uv = E.palette(colors, pal)
        obj = E.Obj([f'# Клинок Памяти — броня этажа {floor}. Оси частей R15, стады.', f'mtllib armor_floor{floor}.mtl'])
        for st in sets:
            sid = st['id']
            lua.append(f'\t\t{sid} = {{')
            lua.append(f'\t\t\trarity = "{st["rarity"]}",')
            lua.append(f'\t\t\tfloor = {floor},')
            if st.get('class') == 'mage':
                lua.append('\t\t\tclass = "mage",')
            b = st['body']
            lua.append(f'\t\t\tbody = {{ cloth = {E.C3(b["cloth"])}, leather = {E.C3(b["leather"])}, skin = {E.C3(b["skin"])} }},')
            prev = E.Obj(['# preview ' + sid, f'mtllib armor_floor{floor}.mtl'])
            body_box(prev, b, uv)
            tris = piece_lines(lua, obj, prev, st, uv, glow_json)
            lua.append('\t\t},')
            open(os.path.join(OUT, f'preview_{sid}.obj'), 'w').write('\n'.join(prev.lines) + '\n')
            report.append(f'этаж {floor} {sid}: деталей {len(st["pieces"])}, треугольников {tris}')
        open(os.path.join(OUT, f'armor_floor{floor}.obj'), 'w').write('\n'.join(obj.lines) + '\n')
        open(os.path.join(OUT, f'armor_floor{floor}.mtl'), 'w').write(f'newmtl palette\nKd 1 1 1\nmap_Kd armor_floor{floor}_palette.png\n')
        objs = G.read_obj(os.path.join(OUT, f'armor_floor{floor}.obj'))
        G.write_glb(os.path.join(OUT, f'armor_floor{floor}.glb'), [(o['name'], o['pos'], o['nrm'], o['uv'], o['idx']) for o in objs],
                    open(pal, 'rb').read(), scene=f'armor_floor{floor}')
        report.append(f'этаж {floor}: цветов {len(colors)}, мешей {len(objs)}')
    lua += ['\t},', '}', '']
    if only is None and floors == [2, 3, 4, 5]:
        open(os.path.join(OUT, 'ArmorFloorsMeshData.lua'), 'w').write('\n'.join(lua))
    old = {}
    gj = os.path.join(OUT, 'glow.json')
    if os.path.exists(gj):
        old = json.load(open(gj))
    old.update(glow_json)
    json.dump(old, open(gj, 'w'), indent=1)
    print('\n'.join(report))


if __name__ == '__main__':
    main()
