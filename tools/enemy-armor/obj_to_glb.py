"""obj_to_glb.py — пакет Enemies3D (<id>_armor.obj ×8) → один enemies3d.glb для Import 3D.

Зачем: 3D Importer Studio сливает все объекты OBJ в одну MeshPart "default",
а узлы glTF оставляет отдельными MeshPart со своими именами.

  python tools/enemy-armor/obj_to_glb.py <папка export пакета> [выход.glb]

Узел = деталь, имя "<id>__<объект OBJ>" (guard__Head__helmet). Палитра
enemy_palette.png встроена в glb: текстуру, которую загрузит импорт, скрипт
сборки берёт с любой детали (отдельно загруженный Image мешем не рисуется).
Import 3D разворачивает glTF на 180° вокруг Y — здесь вершины заранее
повёрнуты обратно (x, z → −x, −z), после импорта меш смотрит как в OBJ.
"""
import json
import os
import struct
import sys

ENEMIES = ["guard", "shade", "knight", "archer", "martyr", "gatekeeper", "centurion", "arbalest"]


def read_obj(path):
    """→ [(name, positions[], normals[], uvs[], indices[])], вершины развёрнуты по углам граней."""
    vs, vts, vns = [], [], []
    objects = []
    cur = None

    def new(name):
        o = {"name": name, "key": {}, "pos": [], "nrm": [], "uv": [], "idx": []}
        objects.append(o)
        return o

    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("v "):
                vs.append(tuple(float(x) for x in line.split()[1:4]))
            elif line.startswith("vt "):
                vts.append(tuple(float(x) for x in line.split()[1:3]))
            elif line.startswith("vn "):
                vns.append(tuple(float(x) for x in line.split()[1:4]))
            elif line.startswith("o "):
                cur = new(line[2:].strip())
            elif line.startswith("f "):
                if cur is None:
                    cur = new("default")
                corners = []
                for tok in line.split()[1:]:
                    parts = (tok.split("/") + ["", ""])[:3]
                    vi = int(parts[0]) - 1
                    ti = int(parts[1]) - 1 if parts[1] else -1
                    ni = int(parts[2]) - 1 if parts[2] else -1
                    k = (vi, ti, ni)
                    if k not in cur["key"]:
                        x, y, z = vs[vi]
                        cur["key"][k] = len(cur["pos"])
                        cur["pos"].append((-x, y, -z))
                        nx, ny, nz = vns[ni] if ni >= 0 else (0.0, 1.0, 0.0)
                        cur["nrm"].append((-nx, ny, -nz))
                        u, v = vts[ti] if ti >= 0 else (0.0, 0.0)
                        cur["uv"].append((u, 1.0 - v))
                    corners.append(cur["key"][k])
                for i in range(1, len(corners) - 1):
                    cur["idx"] += [corners[0], corners[i], corners[i + 1]]
    return [o for o in objects if o["idx"]]


def pad(b, fill=b"\0"):
    return b + fill * ((4 - len(b) % 4) % 4)


def write_glb(path, meshes, png, scene="enemies3d"):
    bin_parts, views, accessors, nodes, gmeshes = [], [], [], [], []
    offset = 0

    def add_view(data, target=None):
        nonlocal offset
        data = pad(data)
        v = {"buffer": 0, "byteOffset": offset, "byteLength": len(data)}
        if target:
            v["target"] = target
        views.append(v)
        bin_parts.append(data)
        offset += len(data)
        return len(views) - 1

    for name, pos, nrm, uv, idx in meshes:
        pb = b"".join(struct.pack("<3f", *p) for p in pos)
        nb = b"".join(struct.pack("<3f", *n) for n in nrm)
        ub = b"".join(struct.pack("<2f", *t) for t in uv)
        big = len(pos) > 65535
        ib = struct.pack(("<%dI" if big else "<%dH") % len(idx), *idx)
        mn = [min(p[i] for p in pos) for i in range(3)]
        mx = [max(p[i] for p in pos) for i in range(3)]
        a0 = len(accessors)
        accessors += [
            {"bufferView": add_view(pb, 34962), "componentType": 5126, "count": len(pos), "type": "VEC3", "min": mn, "max": mx},
            {"bufferView": add_view(nb, 34962), "componentType": 5126, "count": len(pos), "type": "VEC3"},
            {"bufferView": add_view(ub, 34962), "componentType": 5126, "count": len(pos), "type": "VEC2"},
            {"bufferView": add_view(ib, 34963), "componentType": 5125 if big else 5123, "count": len(idx), "type": "SCALAR"},
        ]
        gmeshes.append({"name": name, "primitives": [{
            "attributes": {"POSITION": a0, "NORMAL": a0 + 1, "TEXCOORD_0": a0 + 2},
            "indices": a0 + 3, "material": 0}]})
        nodes.append({"name": name, "mesh": len(gmeshes) - 1})

    img_view = add_view(png)
    gltf = {
        "asset": {"version": "2.0", "generator": "obj_to_glb.py"},
        "scene": 0,
        "scenes": [{"name": scene, "nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": gmeshes,
        "materials": [{"name": "palette", "pbrMetallicRoughness": {
            "baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 1.0}}],
        "textures": [{"sampler": 0, "source": 0}],
        "samplers": [{"magFilter": 9728, "minFilter": 9728, "wrapS": 33071, "wrapT": 33071}],
        "images": [{"name": "enemy_palette", "mimeType": "image/png", "bufferView": img_view}],
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": offset}],
    }
    js = pad(json.dumps(gltf, separators=(",", ":")).encode("utf-8"), b" ")
    bn = b"".join(bin_parts)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bn)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(bn), 0x004E4942) + bn)


def main():
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(src, "enemies3d.glb")
    with open(os.path.join(src, "enemy_palette.png"), "rb") as f:
        png = f.read()
    meshes, tris = [], 0
    for eid in ENEMIES:
        objs = read_obj(os.path.join(src, f"{eid}_armor.obj"))
        t = sum(len(o["idx"]) // 3 for o in objs)
        tris += t
        print(f"{eid}: деталей {len(objs)}, треугольников {t}")
        for o in objs:
            meshes.append((f"{eid}__{o['name']}", o["pos"], o["nrm"], o["uv"], o["idx"]))
    write_glb(out, meshes, png)
    print(f"=> {out}: узлов {len(meshes)}, треугольников {tris}, {os.path.getsize(out) // 1024} КБ")


if __name__ == "__main__":
    main()
