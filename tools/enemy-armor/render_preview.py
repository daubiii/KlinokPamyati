#!/usr/bin/env python3
"""render_preview.py — превью врагов с мешами брони без Studio.

Берёт раскладку префабов в покое (prefab_layout.json — выгружает
tools/lua/export_prefab_layout.lua), ставит меши из armor.json на места
заглушек по тому же правилу, что и apply_armor_meshes.lua (якорь + смещение
из манифеста × воксель × масштаб префаба), остальное (тело, глаза, трещины)
рисует коробками и сохраняет PNG.

    python tools/enemy-armor/render_preview.py               out/preview.png, все враги
    python tools/enemy-armor/render_preview.py --only guard --yaw 160   сзади

Нужен numpy.
"""

import argparse
import json
import math
import os
import struct
import sys
import zlib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_armor as B  # noqa: E402

ORDER = ["guard", "shade", "archer", "knight", "martyr", "gatekeeper"]
BACKGROUND = (0x1E, 0x1B, 0x1F)


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def cframe(comp):
    """12 компонент CFrame -> (позиция, матрица 3×3 по строкам)."""
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = comp
    return np.array([x, y, z]), np.array([[r00, r01, r02], [r10, r11, r12], [r20, r21, r22]])


def box_tris(center, rot, size, color):
    """Коробка детали: 12 треугольников (вершины в мире, нормаль, цвет)."""
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    out = []
    for axis in range(3):
        for sign in (-1, 1):
            n = np.zeros(3)
            n[axis] = sign
            u_axis, v_axis = [a for a in range(3) if a != axis]
            h = [hx, hy, hz]
            corners = []
            for cu, cv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                p = np.zeros(3)
                p[axis] = sign * h[axis]
                p[u_axis] = cu * h[u_axis]
                p[v_axis] = cv * h[v_axis]
                corners.append(center + rot @ p)
            nw = rot @ n
            out.append((corners[0], corners[1], corners[2], nw, color))
            out.append((corners[0], corners[2], corners[3], nw, color))
    return out


def mesh_tris(vols, center_cf, rot, unit):
    """Треугольники меша детали, поставленного центром в center_cf."""
    quads = B.faces_of(vols)
    positions, normals, uvs, indices = B.quads_to_geometry(quads)
    pos = np.array(positions, dtype=float)
    mid = (pos.min(axis=0) + pos.max(axis=0)) / 2
    world = (pos - mid) * unit
    world = world @ rot.T + center_cf
    out = []
    for q in range(len(indices) // 6):
        i0 = indices[q * 6]
        color = hex_rgb(B.HEX[B.ORDER[int(uvs[i0][0] * 16)]])
        n = rot @ np.array(normals[i0], dtype=float)
        a, b, c, d = (world[indices[q * 6 + k]] for k in (0, 1, 2, 5))
        out.append((a, b, c, n, color))
        out.append((a, c, d, n, color))
    return out


def rasterize(tris, width, height, yaw, pitch, scale, center):
    image = np.zeros((height, width, 3), dtype=float)
    image[:] = BACKGROUND
    depth = np.full((height, width), np.inf)
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    # Камера смотрит на врагов спереди (из −Z): поворот по Y, затем наклон.
    ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    view = rx @ ry
    light = np.array([0.45, 0.8, -0.4])
    light /= np.linalg.norm(light)
    xs, ys = np.meshgrid(np.arange(width), np.arange(height))
    for a, b, c, n, color in tris:
        pts = []
        for p in (a, b, c):
            v = view @ (p - center)
            # Экран: x вправо (из −Z правая сторона врага видна слева), y вниз.
            pts.append((width / 2 - v[0] * scale, height * 0.62 - v[1] * scale, v[2]))
        nv = view @ n
        if nv[2] > 0:  # от камеры (камера в −Z смотрит в +Z)
            continue
        x0 = int(max(min(p[0] for p in pts), 0))
        x1 = int(min(max(p[0] for p in pts) + 1, width - 1))
        y0 = int(max(min(p[1] for p in pts), 0))
        y1 = int(min(max(p[1] for p in pts) + 1, height - 1))
        if x1 < x0 or y1 < y0:
            continue
        px = xs[y0:y1 + 1, x0:x1 + 1] + 0.5
        py = ys[y0:y1 + 1, x0:x1 + 1] + 0.5
        (ax, ay, az), (bx, by, bz), (cx, cyy, cz) = pts
        den = (by - cyy) * (ax - cx) + (cx - bx) * (ay - cyy)
        if abs(den) < 1e-9:
            continue
        w0 = ((by - cyy) * (px - cx) + (cx - bx) * (py - cyy)) / den
        w1 = ((cyy - ay) * (px - cx) + (ax - cx) * (py - cyy)) / den
        w2 = 1 - w0 - w1
        inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
        z = w0 * az + w1 * bz + w2 * cz
        region = depth[y0:y1 + 1, x0:x1 + 1]
        mask = inside & (z < region)
        if not mask.any():
            continue
        shade = 0.55 + 0.45 * max(0.0, float(n @ light))
        rgb = np.array(color, dtype=float) * shade
        region[mask] = z[mask]
        image[y0:y1 + 1, x0:x1 + 1][mask] = rgb
    return np.clip(image, 0, 255).astype(np.uint8)


def write_png(path, image):
    h, w, _ = image.shape
    raw = b"".join(b"\x00" + image[y].tobytes() for y in range(h))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    ap.add_argument("--yaw", type=float, default=-20)
    ap.add_argument("--pitch", type=float, default=-12)
    ap.add_argument("--stubs", action="store_true", help="без мешей: как в Studio сейчас")
    ap.add_argument("--out", default=os.path.join(HERE, "out", "preview.png"))
    args = ap.parse_args()

    with open(os.path.join(HERE, "prefab_layout.json"), encoding="utf-8") as f:
        layout = json.load(f)
    with open(os.path.join(HERE, "armor.json"), encoding="utf-8") as f:
        data = json.load(f)
    voxel = data["voxel"]
    with open(os.path.join(HERE, "out", "manifest.json"), encoding="utf-8") as f:
        manifest = json.load(f)

    # Объёмы деталей (как в генераторе).
    built = {}
    by_key = {"%s_%s" % (d["enemy"], d["name"]): d for d in data["details"]}
    for d in data["details"]:
        key = "%s_%s" % (d["enemy"], d["name"])
        if "mirror" in d:
            built[key] = B.mirror_vols(built["%s_%s" % (d["enemy"], d["mirror"])])
        elif "copyOf" in d:
            built[key] = built["%s_%s" % (d["enemy"], d["copyOf"])]
        elif "copyFrom" in d:
            built[key] = built.get(d["copyFrom"]) or B.build_detail(by_key[d["copyFrom"]])
        else:
            built[key] = B.build_detail(d)

    enemies = [args.only] if args.only else ORDER
    tris = []
    x_cursor = 0.0
    for typeId in enemies:
        entry = layout[typeId]
        scale = entry["scale"]
        unit = voxel * scale
        parts = {p["name"]: p for p in entry["parts"]}
        # Раскладка — от HumanoidRootPart (центр в 2,6 × масштаб над ступнями).
        shift = np.array([x_cursor, entry["hrp"] * 1.3, 0])
        replaced = set()
        if not args.stubs:
            for m in manifest:
                if m["enemy"] != typeId:
                    continue
                anchor = parts.get(m["anchor"])
                if not anchor:
                    continue
                pos, rot = cframe(anchor["cf"])
                center = pos + rot @ (np.array(m["offset"]) * unit)
                tris_m = mesh_tris(built[m["mesh"]], center, rot, unit)
                for a, b, c, n, color in tris_m:
                    tris.append((a + shift, b + shift, c + shift, n, color))
                replaced.update(m["replaces"])
        for p in entry["parts"]:
            if p["name"] in replaced or p["transparency"] >= 1:
                continue
            pos, rot = cframe(p["cf"])
            color = hex_rgb(p["color"])
            if p["transparency"] > 0:
                color = tuple(int(c * (1 - p["transparency"]) + b * p["transparency"]) for c, b in zip(color, BACKGROUND))
            for t in box_tris(pos + shift, rot, p["size"], color):
                tris.append(t)
        x_cursor -= 4.2 * scale + 1.5  # следующий — левее в кадре (правее по −X)

    # Центр кадра — середина ряда.
    center = np.array([x_cursor / 2 + 2, 4.5, 0])
    span = abs(x_cursor) + 6
    width, height = 1800, 820
    image = rasterize(tris, width, height, args.yaw, args.pitch, width / span, center)
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    write_png(args.out, image)
    print("превью:", args.out, "треугольников:", len(tris))


if __name__ == "__main__":
    main()
