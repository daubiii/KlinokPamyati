"""OBJ (наш формат: o / v / vt / vn / f с квадами) → GLB для Studio Import 3D.
Каждый объект OBJ — отдельный узел (меш) в glb, палитра PNG встроена, фильтр «ближайший».
Вершины и нормали заранее повёрнуты на 180° вокруг Y (x → −x, z → −z) — как у weapons_floor2.glb
(Import 3D разворачивает модель; так меши встают по данным WeaponMeshData без ImportYaw)."""
import json, struct
import numpy as np


def read_obj(path):
    V, VT, VN = [], [], []
    objs = []; cur = None
    for line in open(path, encoding='utf-8'):
        if line.startswith('o '):
            cur = {'name': line.split()[1], 'pos': [], 'nrm': [], 'uv': [], 'idx': []}; objs.append(cur)
        elif line.startswith('v '):
            V.append([float(x) for x in line.split()[1:4]])
        elif line.startswith('vt '):
            VT.append([float(x) for x in line.split()[1:3]])
        elif line.startswith('vn '):
            VN.append([float(x) for x in line.split()[1:4]])
        elif line.startswith('f '):
            refs = line.split()[1:]
            base = len(cur['pos'])
            for r in refs:
                p = r.split('/')
                vi = int(p[0]) - 1
                ti = int(p[1]) - 1 if len(p) > 1 and p[1] else None
                ni = int(p[2]) - 1 if len(p) > 2 and p[2] else None
                x, y, z = V[vi]
                cur['pos'].append([-x, y, -z])
                n = VN[ni] if ni is not None else [0, 1, 0]
                cur['nrm'].append([-n[0], n[1], -n[2]])
                cur['uv'].append(VT[ti] if ti is not None else [0.5, 0.5])
            for k in range(1, len(refs) - 1):
                cur['idx'] += [base, base + k, base + k + 1]
    return objs


def write_glb(path, meshes, png_bytes, scene='weapons'):
    blob = bytearray(); views = []; accessors = []

    def add_view(data, target=None):
        while len(blob) % 4:
            blob.append(0)
        off = len(blob); blob.extend(data)
        view = {'buffer': 0, 'byteOffset': off, 'byteLength': len(data)}
        if target:
            view['target'] = target
        views.append(view)
        return len(views) - 1

    js_meshes = []; nodes = []
    for name, pos, nrm, uv, idx in meshes:
        P = np.array(pos, np.float32); N = np.array(nrm, np.float32)
        UV = np.array(uv, np.float32); UV[:, 1] = 1 - UV[:, 1]  # glTF: v сверху
        I = np.array(idx, np.uint32 if len(pos) > 65535 else np.uint16)
        a0 = len(accessors)
        accessors.append({'bufferView': add_view(P.tobytes(), 34962), 'componentType': 5126, 'count': len(P), 'type': 'VEC3',
                          'min': P.min(0).tolist(), 'max': P.max(0).tolist()})
        accessors.append({'bufferView': add_view(N.tobytes(), 34962), 'componentType': 5126, 'count': len(N), 'type': 'VEC3'})
        accessors.append({'bufferView': add_view(UV.tobytes(), 34962), 'componentType': 5126, 'count': len(UV), 'type': 'VEC2'})
        accessors.append({'bufferView': add_view(I.tobytes(), 34963), 'componentType': 5125 if I.dtype == np.uint32 else 5123,
                          'count': len(I), 'type': 'SCALAR'})
        js_meshes.append({'name': name, 'primitives': [{'attributes': {'POSITION': a0, 'NORMAL': a0 + 1, 'TEXCOORD_0': a0 + 2},
                                                        'indices': a0 + 3, 'material': 0}]})
        nodes.append({'name': name, 'mesh': len(js_meshes) - 1})
    img_view = add_view(png_bytes)
    while len(blob) % 4:
        blob.append(0)
    js = {'asset': {'version': '2.0', 'generator': 'obj_to_glb.py'}, 'scene': 0,
          'scenes': [{'name': scene, 'nodes': list(range(len(nodes)))}], 'nodes': nodes, 'meshes': js_meshes,
          'materials': [{'name': 'palette', 'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'metallicFactor': 0.0,
                                                                     'roughnessFactor': 1.0}}],
          'textures': [{'sampler': 0, 'source': 0}],
          'samplers': [{'magFilter': 9728, 'minFilter': 9728, 'wrapS': 33071, 'wrapT': 33071}],
          'images': [{'name': scene + '_palette', 'mimeType': 'image/png', 'bufferView': img_view}],
          'accessors': accessors, 'bufferViews': views, 'buffers': [{'byteLength': len(blob)}]}
    j = json.dumps(js, ensure_ascii=False).encode('utf-8')
    while len(j) % 4:
        j += b' '
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(blob))
    out += struct.pack('<II', len(j), 0x4E4F534A) + j + struct.pack('<II', len(blob), 0x004E4942) + bytes(blob)
    open(path, 'wb').write(out)
