"""floor_obj_to_glb.py — карта этажа 1 v2 (<зона>_vis.obj ×17) → три glb для Import 3D.

Зачем: Import 3D сливает OBJ в одну MeshPart, а Roblox режет меш до 20 000
треугольников — у двора, башни, зала и босса пропадала половина стен и пола.
В glb узел = объект OBJ (intro_m1, tower_g3…), каждый меньше 20 000.

  python tools/floor1map/floor_obj_to_glb.py <папка map пакета> [папка выхода]

Выход: floor1v2_a.glb (часть I), floor1v2_b.glb (часть II), floor1v2_c.glb (часть III).
Поворот glTF на 180° и палитра — как в tools/enemy-armor/obj_to_glb.py.

CUTS — проёмы, которых нет в мешах пакета (коллизия режется там же: fix_collisions.lua).
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "enemy-armor"))
from obj_to_glb import write_glb  # noqa: E402

GROUPS = {
    "a": ["intro", "yard", "street", "warehouse", "plaza", "barbican"],
    "b": ["rest1", "bridge", "armory", "forge", "gallery", "tower"],
    "c": ["hall", "chapel", "lastgates", "boss", "env"],
}
LIMIT = 20000
EPS = 1e-3

# зона → [(min, max, ось прохода)]: проём сквозь стену вдоль оси.
# v3 (08.11.2026): проём в зал по земле вырезан прямо в OBJ (tools/floor1map/v3),
# старый проём на высоте 24 больше не нужен — моста туда нет.
CUTS = {}


def read_polys(path):
    """→ [(имя, [полигон: [(pos, uv, nrm)]])] в координатах OBJ."""
    vs, vts, vns = [], [], []
    objects = []
    cur = None
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("v "):
                vs.append(tuple(float(x) for x in line.split()[1:4]))
            elif line.startswith("vt "):
                vts.append(tuple(float(x) for x in line.split()[1:3]))
            elif line.startswith("vn "):
                vns.append(tuple(float(x) for x in line.split()[1:4]))
            elif line.startswith("o "):
                cur = (line[2:].strip(), [])
                objects.append(cur)
            elif line.startswith("f "):
                if cur is None:
                    cur = ("default", [])
                    objects.append(cur)
                poly = []
                for tok in line.split()[1:]:
                    parts = (tok.split("/") + ["", ""])[:3]
                    p = vs[int(parts[0]) - 1]
                    t = vts[int(parts[1]) - 1] if parts[1] else (0.0, 0.0)
                    n = vns[int(parts[2]) - 1] if parts[2] else (0.0, 1.0, 0.0)
                    poly.append((p, t, n))
                cur[1].append(poly)
    return objects


def rect(axis, plane, a0, a1, b0, b1, uv, nrm):
    """Прямоугольник в плоскости axis = plane; a, b — две другие оси по порядку; обход против часовой к nrm."""
    other = [i for i in range(3) if i != axis]
    corners = []
    for a, b in ((a0, b0), (a1, b0), (a1, b1), (a0, b1)):
        p = [0.0, 0.0, 0.0]
        p[axis] = plane
        p[other[0]] = a
        p[other[1]] = b
        corners.append((tuple(p), uv, nrm))
    e1 = [corners[1][0][i] - corners[0][0][i] for i in range(3)]
    e2 = [corners[2][0][i] - corners[0][0][i] for i in range(3)]
    cr = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
    if sum(cr[i] * nrm[i] for i in range(3)) < 0:
        corners.reverse()
    return corners


def cut_polys(polys, bmin, bmax, through):
    """Вырезает проём: грани внутри убираются, большие грани стены режутся, добавляются откосы."""
    out, planes, uv = [], [], None
    for poly in polys:
        ps = [c[0] for c in poly]
        lo = [min(p[i] for p in ps) for i in range(3)]
        hi = [max(p[i] for p in ps) for i in range(3)]
        center = [(lo[i] + hi[i]) / 2 for i in range(3)]
        overlaps = all(lo[i] < bmax[i] - EPS and hi[i] > bmin[i] + EPS for i in range(3) if i != through)
        flat = hi[through] - lo[through] < EPS
        in_wall = bmin[through] - EPS <= lo[through] and hi[through] <= bmax[through] + EPS
        if flat and in_wall and overlaps and len(poly) == 4:
            # грань стены поперёк прохода: остаток вокруг проёма
            planes.append(lo[through])
            uv = poly[0][1]
            a, b = [i for i in range(3) if i != through]
            ca0, ca1 = max(lo[a], bmin[a]), min(hi[a], bmax[a])
            cb0, cb1 = max(lo[b], bmin[b]), min(hi[b], bmax[b])
            pieces = [
                (lo[a], ca0, lo[b], hi[b]),
                (ca1, hi[a], lo[b], hi[b]),
                (ca0, ca1, lo[b], cb0),
                (ca0, ca1, cb1, hi[b]),
            ]
            for a0, a1, b0, b1 in pieces:
                if a1 - a0 > EPS and b1 - b0 > EPS:
                    out.append(rect(through, lo[through], a0, a1, b0, b1, poly[0][1], poly[0][2]))
        elif all(bmin[i] - EPS <= center[i] <= bmax[i] + EPS for i in range(3)):
            continue  # кирпичи и ступени внутри проёма
        else:
            out.append(poly)
    if not planes:
        return out
    w0, w1 = min(planes), max(planes)
    a, b = [i for i in range(3) if i != through]
    # откосы: плоскости a = bmin/bmax (нормаль внутрь проёма) и b = bmin/bmax
    for axis, val, sign in ((a, bmin[a], 1), (a, bmax[a], -1), (b, bmin[b], 1), (b, bmax[b], -1)):
        nrm = [0.0, 0.0, 0.0]
        nrm[axis] = float(sign)
        rest = [i for i in range(3) if i != axis]
        r0 = (w0, w1) if rest[0] == through else (bmin[rest[0]], bmax[rest[0]])
        r1 = (w0, w1) if rest[1] == through else (bmin[rest[1]], bmax[rest[1]])
        out.append(rect(axis, val, r0[0], r0[1], r1[0], r1[1], uv, tuple(nrm)))
    return out


def to_mesh(polys):
    """Полигоны → вершины по углам, повёрнутые для glTF (x, z → −x, −z), треугольники веером."""
    key, pos, nrm, uv, idx = {}, [], [], [], []
    for poly in polys:
        corners = []
        for p, t, n in poly:
            k = (p, t, n)
            if k not in key:
                key[k] = len(pos)
                pos.append((-p[0], p[1], -p[2]))
                nrm.append((-n[0], n[1], -n[2]))
                uv.append((t[0], 1.0 - t[1]))
            corners.append(key[k])
        for i in range(1, len(corners) - 1):
            idx += [corners[0], corners[i], corners[i + 1]]
    return pos, nrm, uv, idx


def main():
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(src, "floor_palette.png"), "rb") as f:
        png = f.read()
    for key, zones in GROUPS.items():
        meshes, tris = [], 0
        for zone in zones:
            for name, polys in read_polys(os.path.join(src, f"{zone}_vis.obj")):
                for bmin, bmax, through in CUTS.get(zone, ()):
                    before = len(polys)
                    polys = cut_polys(polys, bmin, bmax, through)
                    if len(polys) != before:
                        print(f"  проём в {name}: граней {before} -> {len(polys)}")
                pos, nrm, uv, idx = to_mesh(polys)
                if not idx:
                    continue
                t = len(idx) // 3
                assert t < LIMIT, f"{name}: {t} треугольников — больше лимита меша"
                tris += t
                meshes.append((name, pos, nrm, uv, idx))
        path = os.path.join(out, f"floor1v2_{key}.glb")
        write_glb(path, meshes, png, f"floor1v2_{key}")
        print(f"{path}: узлов {len(meshes)}, треугольников {tris}, {os.path.getsize(path) // 1024} КБ")


if __name__ == "__main__":
    main()
