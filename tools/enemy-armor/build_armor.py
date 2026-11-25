#!/usr/bin/env python3
"""build_armor.py — генератор мешей брони и оружия врагов (шаг 5 конвейера).

Читает armor.json (сетки ТЗ врагов этажа 1) и пишет в out/:
  * <enemy>_<detail>.glb — по файлу на деталь: greedy meshing по граням,
    текстура-палитра 16 клеток, UV каждой грани — в центре клетки своего цвета,
    воксель 0,125 стада, начало координат — центр коробки меша;
  * enemy_armor.glb — все детали одним файлом (для Import 3D);
  * palette.png — та же палитра отдельно (16 клеток по CELL px);
  * manifest.json — размеры мешей, их смещение от заглушки-якоря, три
    самых частых цвета (атрибут Colors) — для скрипта замены в Studio;
  * ../lua/apply_armor_meshes.lua — скрипт замены заглушек (манифест внутри).

Только стандартная библиотека Python 3.

Оси (как в Roblox): +Y вверх, враг смотрит в −Z, +X — его правая сторона.
Колонка 1 сетки «вид спереди» — правая сторона врага (+X).

    python tools/enemy-armor/build_armor.py            собрать всё
    python tools/enemy-armor/build_armor.py --only guard
"""

import argparse
import json
import math
import os
import struct
import sys
import zlib
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

# Палитра (Palette.Voxel, порядок Palette.VoxelOrder). Позиции 13–16 пустые.
ORDER = "KSGLWHDRABNX"
CELL = 16  # пикселей на цвет в palette.png
HEX = {
    "K": "1E1B1F", "S": "4A4350", "G": "6B6F73", "L": "9AA0A6", "W": "D9D2C5", "H": "F2EDE3",
    "D": "3A2E2A", "R": "7A5C48", "A": "C98B4A", "B": "4A3A2C", "N": "8C6A45", "X": "E5484D",
}
# На тон темнее (теневая сторона −X, свет сверху-слева-спереди) — по рампам ТЗ:
# сталь K→S→G→L→W→H, ржавчина K→D→R→A→W.
DARKER = {"H": "W", "W": "L", "L": "G", "G": "S", "S": "K", "K": "K", "A": "R", "R": "D", "D": "K", "B": "D", "N": "B", "X": "D"}
OUTLINE = set("Kec.")

DIRS = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]


def letter(ch):
    """e и c (места неона) в меше — K."""
    return "K" if ch in "ec" else ch


# ===== Объём =====

class Vol:
    """Набор целых клеток со своим смещением и правилом цвета граней.

    color(cell, d) -> буква палитры для открытой грани клетки cell в
    направлении d. offset — смещение (может быть дробным: оружие).
    """

    def __init__(self, cells, color, offset=(0, 0, 0)):
        self.cells = set(cells)
        self.color = color
        self.offset = offset

    def integer(self):
        return all(float(v).is_integer() for v in self.offset)


def parse_rows(spec):
    """Строки сетки: сверху вниз. Повторы ('#' + repeat) раскрываются."""
    grid = list(spec["grid"]) if "grid" in spec else []
    rep = spec.get("repeat")
    if rep:
        lo, hi = [int(v) for v in rep["rows"].split("-")]
        pattern = rep["pattern"]
        k = 0
        for i in range(len(grid)):
            if grid[i] == "#":
                grid[i] = pattern[k % len(pattern)]
                k += 1
        assert k == hi - lo + 1, "repeat: число '#' не совпало с диапазоном"
    return grid


def interior(row_chars, from_left):
    """Первый «материальный» цвет строки с края (не контур)."""
    seq = row_chars if from_left else row_chars[::-1]
    for ch in seq:
        if ch not in OUTLINE:
            return ch
    return "K"


def extrude(spec, grid=None, depth=None, offset=(0, 0, 0)):
    """Выдавленная сетка «вид спереди» (тип по умолчанию)."""
    grid = grid or parse_rows(spec)
    H = len(grid)
    W = len(grid[0])
    D = depth or spec.get("depth", 1)
    for row in grid:
        assert len(row) == W, "строки сетки разной длины: %r" % row
    only = spec.get("onlyLetters")
    holes = spec.get("frontHoles")

    def at(x, y):
        """Буква сетки по клетке (x — от −X к +X, y — снизу)."""
        return grid[H - 1 - y][W - 1 - x]

    cells = set()
    for y in range(H):
        for x in range(W):
            ch = at(x, y)
            if ch == ".":
                continue
            if only and ch not in only:
                continue
            for z in range(D):
                if holes and ch in holes and z == 0:
                    continue
                cells.add((x, y, z))
    cav = spec.get("cavity")
    cavity = set()
    if cav:
        cw, ch_, cd = cav["size"]
        ox, oy, oz = cav["offset"]
        for x in range(ox, ox + cw):
            for y in range(oy, oy + ch_):
                for z in range(oz, oz + cd):
                    cavity.add((x, y, z))
        cells -= cavity

    back = build_back(spec, grid)
    wrap = spec.get("wrap", False)
    side_color = spec.get("sideColor")

    def row_of(y):
        return grid[H - 1 - y]

    def color(cell, d):
        x, y, z = cell
        n = (x + d[0], y + d[1], z + d[2])
        if n in cavity:
            return "K"
        ch = letter(at(x, y))
        if d == (0, 0, -1):  # лицо
            if holes and z > 0:
                return "K"
            return ch if z == 0 else DARKER[ch]
        if d == (0, 0, 1):  # спина
            if z != D - 1:
                return "K"
            return letter(back[H - 1 - y][W - 1 - x]) if back else ch
        row = row_of(y)
        if d[0] != 0:  # бока
            if wrap:
                # Труба (наручи, обмотки): бок повторяет лицо по глубине.
                col = min(max(z, 0), W - 1)
                c = letter(row[col] if d[0] < 0 else row[W - 1 - col])
                if c == ".":
                    c = "K"
            else:
                if z == 0 or z == D - 1:
                    return "K"  # контур грани
                c = interior(row, from_left=(d[0] > 0))
                if side_color and c != "K":
                    c = side_color
            return c if d[0] > 0 else DARKER[c]
        if d[1] > 0:  # верх
            if wrap:
                return ch
            if z == 0 or z == D - 1:
                return ch if ch != "K" else "K"
            # Цвет столбца сверху вниз — первый материальный.
            for yy in range(y, -1, -1):
                c = at(x, yy)
                if c not in OUTLINE:
                    return side_color or c
            return "K"
        return "K" if not wrap else DARKER[ch]  # низ

    return Vol(cells, color, offset)


def build_back(spec, grid):
    """Спина детали: сетка, заливка или правило из ТЗ."""
    H = len(grid)
    W = len(grid[0])
    if "back" in spec:
        return spec["back"]
    fill = spec.get("backFill")
    rule = spec.get("backRule")
    if fill == "auto":
        fill = None
        rule = {"from": "front", "map": {"H": "L"}}
    if fill:
        out = []
        for r, row in enumerate(grid):
            line = ""
            for c, ch in enumerate(row):
                if ch == ".":
                    line += "."
                    continue
                edge = (c == 0 or c == W - 1 or r == 0 or r == H - 1 or row[c - 1] == "." or row[c + 1] == "."
                        or grid[r - 1][c] == "." or grid[r + 1][c] == ".")
                line += "K" if edge else fill
            out.append(line)
        return out
    if not rule:
        return None
    if "fill" in rule:
        base = build_back({"backFill": rule["fill"]}, grid)
    else:
        mapping = rule.get("map", {})
        base = ["".join(mapping.get(ch, ch) for ch in row) for row in grid]
    base = [list(row) for row in base]
    keep = set(rule.get("keepRows", []))
    if keep:
        for r in keep:
            base[r - 1] = list(grid[r - 1])
    rust = rule.get("rustBelow")
    if rust:
        for r in range(rust, H):
            if (r + 1) in keep:
                continue
            for c in range(W):
                if base[r][c] not in ("K", "."):
                    base[r][c] = "R" if r < H - 2 else "D"
    if rule.get("straps"):
        # Два ремня крест-накрест от плеч к поясу (страж, ТЗ 2.4.1).
        s = rule["straps"]
        top, bottom = 1, H - 4
        for r in range(top, bottom + 1):
            t = (r - top) / max(bottom - top, 1)
            for c in (round(2 + t * (W - 5)), round(W - 3 - t * (W - 5))):
                if base[r][c] not in (".",):
                    base[r][c] = s
    if rule.get("handles"):
        # Две ручки на тыльной стороне щита.
        h = rule["handles"]
        for r in (H // 3, H // 3 + 1, 2 * H // 3, 2 * H // 3 + 1):
            for c in range(W // 2 - 3, W // 2 + 3):
                base[r][c] = h
    return ["".join(row) for row in base]


def box(size, color_fn, offset=(0, 0, 0), hole=None):
    w, h, d = size
    cells = set()
    for x in range(w):
        for y in range(h):
            for z in range(d):
                cells.add((x, y, z))
    if hole:
        hw, hd = hole
        x0, z0 = (w - hw) // 2, (d - hd) // 2
        for x in range(x0, x0 + hw):
            for y in range(h):
                for z in range(z0, z0 + hd):
                    cells.discard((x, y, z))
    return Vol(cells, color_fn, offset)


# ===== Детали, описанные в ТЗ словами =====

def build_ring(p):
    """Поля шлема: кольцо, основной цвет и тёмный контур."""
    w, h, d = p["size"]
    main, ring = p["color"], p["ring"]

    def color(cell, dd):
        x, y, z = cell
        edge = x in (0, w - 1) or z in (0, d - 1)
        if dd[1] > 0:
            return ring if edge else main
        if dd[1] < 0:
            return ring
        return ring if dd[0] != 0 or dd[2] != 0 else main

    return [box((w, h, d), color, tuple(p["offset"]), tuple(p["hole"]))]


def build_steps(p):
    """Ступенчатый наплечник: снизу вверх, по центру нижней ступени."""
    vols = []
    base_w = p["steps"][0]["size"][0]
    base_d = p["steps"][0]["size"][2]
    y = 0
    for step in p["steps"]:
        w, h, d = step["size"]
        spec = {"grid": step["grid"], "depth": d, "sideColor": step.get("sideColor")}
        vols.append(extrude(spec, depth=d, offset=((base_w - w) // 2, y, (base_d - d) // 2)))
        y += h
    return vols


def build_bands(p):
    """Обмотки и наручи: ряды цветов сверху вниз, труба с полостью."""
    w, h, d = p["size"]
    grid = ["K" + c * (w - 2) + "K" for c in p["rows"]]
    cw, ch, cd = p["cavity"]
    spec = {"grid": grid, "depth": d, "wrap": True,
            "cavity": {"size": [cw, ch, cd], "offset": [(w - cw) // 2, 0, (d - cd) // 2]}}
    return [extrude(spec, grid=grid, depth=d)]


def build_quiver(p):
    """Колчан 5×16×5: корпус N, пояски B (строки 4 и 12), три стрелы:
    древко N 1×4, оперение W 1×2 с бликом H."""
    rows = []
    for r in range(1, 17):
        c = "B" if r in (4, 12) else "N"
        rows.append(("K" + c * 3 + "K") if r not in (1, 16) else "KKKKK")
    vols = [extrude({"grid": rows, "depth": 5, "wrap": True}, grid=rows, depth=5)]
    for (x, z) in ((1, 1), (3, 2), (2, 3)):
        def color(cell, d):
            y = cell[1] - 16
            if y >= 4:
                return "H" if (y == 5 and d[1] > 0) else "W"
            return "N"
        cells = {(x, 16 + y, z) for y in range(6)}
        vols.append(Vol(cells, color))
    return vols


def build_bow(p):
    """Лук: 34 вокселя по +Y, хват посередине. Плечи — дуга толщиной 2:
    x(y) = 4 − 4·((y − 17)/17)² вперёд от хвата (вперёд — −Z). Плечи N с
    контуром D, хват y = 15…19 обмотка B с полоской A на 17, концы по 3 W."""
    cells = {}
    for i in range(34):
        yc = i + 0.5
        forward = 4 - 4 * ((yc - 17) / 17) ** 2
        z0 = int(round(4 - forward))
        if i < 3 or i > 30:
            c = "W"
        elif 14 <= i <= 18:
            c = "A" if i == 16 else "B"
        else:
            c = "N"
        for x in range(2):
            for z in (z0, z0 + 1):
                cells[(x, i, z)] = c

    def color(cell, d):
        c = cells[cell]
        if d[0] != 0:
            return "D" if c == "N" else DARKER[c] if d[0] < 0 else c
        return c

    return [Vol(set(cells), color)]


def build_crown(p):
    """Корона Привратника: обод 15×2×13 (KAAA…AK) по периметру шлема и
    зубцы-ключи на x = 2, 5, 8, 11, 14 высотой 3, 4, 5, 4, 3; на вершине
    каждого — кольцо ключа 3×3 с дыркой. Цвет A, контур D, блик H у центра."""
    w, h, d = p["size"]
    W = w
    rim = {}
    for x in range(w):
        for y in range(h):
            for z in range(d):
                if x in (0, w - 1) or z in (0, d - 1):
                    rim[(x, y, z)] = "K" if x in (0, w - 1) else "A"
    teeth = {}
    for col, th in zip(p["teethX"], p["teethH"]):
        x = W - col  # колонка 1 = +X
        for y in range(h, h + th):
            teeth[(x, y, 0)] = "A"
        top = h + th
        for dx in (-1, 0, 1):
            for dy in (0, 1, 2):
                if dx == 0 and dy == 1:
                    continue
                xx = x + dx
                if 0 <= xx < W:
                    teeth[(xx, top + dy, 0)] = "H" if (col == 8 and dy == 2 and dx == 0) else "A"
    allcells = dict(rim)
    allcells.update(teeth)

    def color(cell, dd):
        c = allcells[cell]
        if c == "K":
            return "D"
        if dd[0] != 0 or dd[2] > 0:
            return "D" if dd[0] < 0 else "A"
        return c

    return [Vol(set(allcells), color)]


def build_tower(p):
    """Наплечник-башня 12×8×12: зубцы (2 S / 2 пусто по периметру) сверху,
    корпус G с кладкой: горизонтальные швы K через 3 строки, вертикальные со
    смещением; спереди бойница K 1×3; нижний ряд R."""
    w, h, d = p["size"]
    body_h = h - 2
    cells = {}
    for x in range(w):
        for y in range(body_h):
            for z in range(d):
                cells[(x, y, z)] = "G"
    # Зубцы по периметру.
    perim = []
    for x in range(w):
        perim.append((x, 0))
    for z in range(1, d):
        perim.append((w - 1, z))
    for x in range(w - 2, -1, -1):
        perim.append((x, d - 1))
    for z in range(d - 2, 0, -1):
        perim.append((0, z))
    for i, (x, z) in enumerate(perim):
        if (i // 2) % 2 == 0:
            for y in (body_h, body_h + 1):
                cells[(x, y, z)] = "S"

    def masonry(u, y):
        """Цвет кладки на грани: u — координата вдоль грани."""
        if y == 0:
            return "R"
        row_from_top = body_h - 1 - y
        if row_from_top % 3 == 2:
            return "K"
        course = row_from_top // 3
        if (u + course * 2) % 4 == 0:
            return "K"
        return "G"

    mid = w // 2

    def color(cell, dd):
        x, y, z = cell
        c = cells[cell]
        if c == "S":
            return "S" if dd[0] >= 0 else "K"
        if dd[1] > 0:
            return "G"
        if dd[1] < 0:
            return "K"
        if dd[2] < 0:
            if x == mid and 1 <= body_h - 1 - y <= 3:
                return "K"
            return masonry(x, y)
        if dd[2] > 0:
            return masonry(x, y)
        m = masonry(z, y)
        return m if dd[0] > 0 else DARKER[m]

    return [Vol(set(cells), color)]


def build_chain(p):
    """Цепь: звенья 3×3×1 с дыркой 1×1, через одно повёрнуты на 90°.
    Цвет G, контур K."""
    cells = set()
    n = p["links"]
    for i in range(n):
        y0 = (n - 1 - i) * 3
        for a in range(3):
            for b in range(3):
                if a == 1 and b == 1:
                    continue
                if i % 2 == 0:
                    cells.add((a, y0 + b, 1))
                else:
                    cells.add((1, y0 + b, a))

    def color(cell, d):
        return "G" if d[2] != 0 or d[0] != 0 else "K"

    return [Vol(cells, color)]


def bolt_sword_grid():
    """Меч-засов Привратника 13×44 (ТЗ 2.4.6), строки сверху вниз."""
    link = ["..KHLLLLLGK..", "..KHLWWLLGK..", "..KHLWWLLGK..", "..KHLLLLLGK..", "..KHLLLLLGK..", "..KHAGGGAGK.."]
    rows = ["..KKKKKKKKK.."]
    for i in range(5):
        block = [list(r) for r in link]
        if i >= 3:  # два нижних звена с ржавчиной
            for r in block:
                for col, src, dst in ((5, "L", "R"), (9, "L", "R"), (10, "G", "D")):
                    if r[col - 1] == src:
                        r[col - 1] = dst
        rows += ["".join(r) for r in block]
    rows += [
        "KKKKKKKKKKKKK",
        "KAAAAAAAAAAAK",
        "KDAAAKKKAAADK",
        "KKKKKKKKKKKKK",
        ".....KBK.....",
        ".....KDK.....",
        ".....KBK.....",
        ".....KDK.....",
        ".....KBK.....",
        ".....KDK.....",
        "....KAAAK....",
        "....KAWAK....",
        "....KKKKK....",
    ]
    assert len(rows) == 44
    return rows


def build_side(p):
    """Оружие «вид сбоку»: у каждой строки своя толщина (depths — строки
    от низа), по центру рамки frame."""
    grid = bolt_sword_grid() if p.get("boltSword") else parse_rows(p)
    H = len(grid)
    frame = p["frame"]
    depth_of = {}
    for key, value in p["depths"].items():
        if "-" in key:
            lo, hi = [int(v) for v in key.split("-")]
        else:
            lo = hi = int(key)
        for r in range(lo, hi + 1):
            depth_of[r] = value
    vols = []
    # Группы подряд идущих строк с одинаковой толщиной — отдельные объёмы.
    r = 1
    while r <= H:
        dep = depth_of[r]
        r2 = r
        while r2 + 1 <= H and depth_of[r2 + 1] == dep:
            r2 += 1
        sub = grid[H - r2:H - r + 1]
        vol = extrude({"grid": sub, "depth": dep, "backFill": None}, grid=sub, depth=dep,
                      offset=(0, r - 1, (frame - dep) / 2))
        vols.append(vol)
        r = r2 + 1
    return vols


def build_flanges(p, frame, width):
    """Фланцы головки булавы спереди и сзади (по бокам их уже дала сетка)."""
    lo, hi = [int(v) for v in p["rows"].split("-")]
    vols = []
    for z in (-1, frame):
        cells = {(x, y, z) for x in (width // 2 - 1, width // 2) for y in range(lo - 1, hi)}

        def color(cell, d):
            return p["color"] if d[2] != 0 else p["ring"]

        vols.append(Vol(cells, color))
    return vols


BUILDERS = {
    "ring": build_ring,
    "steps": build_steps,
    "bands": build_bands,
    "quiver": build_quiver,
    "bow": build_bow,
    "crown": build_crown,
    "tower": build_tower,
    "chain": build_chain,
    "side": build_side,
}


def build_detail(detail):
    vols = []
    frame, width = None, None
    for part in detail["parts"]:
        kind = part.get("type")
        if kind == "flanges":
            vols += build_flanges(part, frame, width)
            continue
        if kind in BUILDERS:
            built = BUILDERS[kind](part)
            if kind == "side":
                frame = part["frame"]
                width = len(bolt_sword_grid()[0]) if part.get("boltSword") else len(part["grid"][0])
            vols += built
        else:
            vols.append(extrude(part, offset=tuple(part.get("offset", (0, 0, 0)))))
    return vols


def mirror_vols(vols):
    """Зеркало по X (левая деталь из правой)."""
    xs = []
    for v in vols:
        for c in v.cells:
            xs.append(c[0] + v.offset[0])
    max_x = max(xs)
    out = []
    for v in vols:
        cells = {(-c[0], c[1], c[2]) for c in v.cells}

        # Зеркальная деталь берёт цвета граней исходной (теневая сторона
        # при этом тоже отражается — для пар деталей это незаметно).
        def color(cell, d, v=v):
            return v.color((-cell[0], cell[1], cell[2]), (-d[0], d[1], d[2]))

        out.append(Vol(cells, color, (max_x - v.offset[0], v.offset[1], v.offset[2])))
    return out


# ===== Грани и greedy meshing =====

def faces_of(vols):
    """Открытые грани: [(dir, plane, u, v, color)] в координатах вокселей."""
    occupied = set()
    for v in vols:
        if v.integer():
            ox, oy, oz = (int(c) for c in v.offset)
            for c in v.cells:
                occupied.add((c[0] + ox, c[1] + oy, c[2] + oz))
    quads = []
    for v in vols:
        ox, oy, oz = v.offset
        integer = v.integer()
        for d in DIRS:
            # Слои по оси направления: (plane) -> {(u, v): color}
            axis = 0 if d[0] else (1 if d[1] else 2)
            slices = {}
            for c in v.cells:
                n = (c[0] + d[0], c[1] + d[1], c[2] + d[2])
                if n in v.cells:
                    continue
                if integer and (n[0] + int(ox), n[1] + int(oy), n[2] + int(oz)) in occupied:
                    continue
                col = v.color(c, d)
                if col not in HEX:
                    col = "K"
                plane = c[axis] + (1 if d[axis] > 0 else 0)
                u_axis, v_axis = [a for a in range(3) if a != axis]
                slices.setdefault(plane, {})[(c[u_axis], c[v_axis])] = col
            for plane, cellmap in slices.items():
                for rect in greedy(cellmap):
                    quads.append((d, axis, plane, rect, (ox, oy, oz)))
    return quads


def greedy(cellmap):
    """Жадное слияние клеток одного цвета в прямоугольники."""
    done = set()
    rects = []
    keys = sorted(cellmap)
    for (u, v) in keys:
        if (u, v) in done:
            continue
        col = cellmap[(u, v)]
        w = 1
        while (u + w, v) in cellmap and (u + w, v) not in done and cellmap[(u + w, v)] == col:
            w += 1
        h = 1
        while True:
            ok = True
            for k in range(w):
                key = (u + k, v + h)
                if key not in cellmap or key in done or cellmap[key] != col:
                    ok = False
                    break
            if not ok:
                break
            h += 1
        for a in range(w):
            for b in range(h):
                done.add((u + a, v + b))
        rects.append((u, v, w, h, col))
    return rects


def quads_to_geometry(quads):
    """Вершины, нормали, UV, индексы (в вокселях, ещё без центрирования)."""
    positions, normals, uvs, indices = [], [], [], []
    for d, axis, plane, (u, v, w, h, col), off in quads:
        u_axis, v_axis = [a for a in range(3) if a != axis]
        corners = [(u, v), (u + w, v), (u + w, v + h), (u, v + h)]
        pts = []
        for cu, cv in corners:
            p = [0.0, 0.0, 0.0]
            p[axis] = plane
            p[u_axis] = cu
            p[v_axis] = cv
            pts.append([p[0] + off[0], p[1] + off[1], p[2] + off[2]])
        # Обход против часовой стрелки, если смотреть с нормали.
        e1 = [pts[1][i] - pts[0][i] for i in range(3)]
        e2 = [pts[2][i] - pts[0][i] for i in range(3)]
        cross = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
        if cross[0] * d[0] + cross[1] * d[1] + cross[2] * d[2] < 0:
            pts = [pts[0], pts[3], pts[2], pts[1]]
        base = len(positions)
        uv = ((ORDER.index(col) + 0.5) / 16.0, 0.5)
        for pt in pts:
            positions.append(pt)
            normals.append(list(d))
            uvs.append(uv)
        indices += [base, base + 1, base + 2, base, base + 2, base + 3]
    return positions, normals, uvs, indices


# ===== PNG и GLB =====

def palette_png():
    """Палитра 16 клеток по CELL пикселей: UV стоят в центрах клеток, и даже
    уменьшенные мипмапы (на расстоянии) не смешивают соседние цвета."""
    row = b"\x00"
    for i in range(16):
        hx = HEX[ORDER[i]] if i < len(ORDER) else "000000"
        row += (bytes.fromhex(hx) + b"\xff") * CELL
    raw = row * CELL

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", 16 * CELL, CELL, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def write_glb(path, meshes, png):
    """meshes — список (имя, позиции, нормали, uv, индексы); по узлу на меш,
    материал и палитра общие."""
    def pad(b, fill=b"\x00"):
        return b + fill * ((4 - len(b) % 4) % 4)

    chunks, views, accessors, nodes, gltf_meshes = [], [], [], [], []
    total = 0

    def view(data, target=None):
        nonlocal total
        v = {"buffer": 0, "byteOffset": total, "byteLength": len(data)}
        if target:
            v["target"] = target
        chunks.append(pad(data))
        total += len(chunks[-1])
        views.append(v)
        return len(views) - 1

    for name, positions, normals, uvs, indices in meshes:
        pos_v = view(b"".join(struct.pack("<3f", *p) for p in positions), 34962)
        nor_v = view(b"".join(struct.pack("<3f", *n) for n in normals), 34962)
        uv_v = view(b"".join(struct.pack("<2f", *t) for t in uvs), 34962)
        idx_v = view(b"".join(struct.pack("<I", i) for i in indices), 34963)
        a = len(accessors)
        accessors += [
            {"bufferView": pos_v, "componentType": 5126, "count": len(positions), "type": "VEC3",
             "min": [min(p[i] for p in positions) for i in range(3)],
             "max": [max(p[i] for p in positions) for i in range(3)]},
            {"bufferView": nor_v, "componentType": 5126, "count": len(normals), "type": "VEC3"},
            {"bufferView": uv_v, "componentType": 5126, "count": len(uvs), "type": "VEC2"},
            {"bufferView": idx_v, "componentType": 5125, "count": len(indices), "type": "SCALAR"},
        ]
        gltf_meshes.append({"name": name, "primitives": [{
            "attributes": {"POSITION": a, "NORMAL": a + 1, "TEXCOORD_0": a + 2},
            "indices": a + 3, "material": 0}]})
        nodes.append({"mesh": len(gltf_meshes) - 1, "name": name})
    png_v = view(png)
    binary = b"".join(chunks)
    gltf = {
        "asset": {"version": "2.0", "generator": "KlinokPamyati build_armor.py"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": gltf_meshes,
        "materials": [{"name": "palette", "pbrMetallicRoughness": {
            "baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 1.0}}],
        "textures": [{"sampler": 0, "source": 0}],
        "samplers": [{"magFilter": 9728, "minFilter": 9728, "wrapS": 33071, "wrapT": 33071}],
        "images": [{"bufferView": png_v, "mimeType": "image/png", "name": "palette"}],
        "buffers": [{"byteLength": len(binary)}],
        "bufferViews": views,
        "accessors": accessors,
    }
    js = pad(json.dumps(gltf, separators=(",", ":")).encode("utf-8"), b" ")
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(binary))
    out += struct.pack("<II", len(js), 0x4E4F534A) + js
    out += struct.pack("<II", len(binary), 0x004E4942) + binary
    with open(path, "wb") as f:
        f.write(out)


# ===== Сборка =====

def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="только детали врага (typeId)")
    args = ap.parse_args()

    with open(os.path.join(HERE, "armor.json"), encoding="utf-8") as f:
        data = json.load(f)
    voxel = data["voxel"]
    outdir = os.path.join(HERE, "out")
    os.makedirs(outdir, exist_ok=True)
    png = palette_png()
    with open(os.path.join(outdir, "palette.png"), "wb") as f:
        f.write(png)

    details = data["details"]
    by_key = {}
    for d in details:
        by_key["%s_%s" % (d["enemy"], d["name"])] = d
    built = {}
    combined = []
    manifest = []
    total_tris = 0
    for d in details:
        key = "%s_%s" % (d["enemy"], d["name"])
        if "mirror" in d:
            vols = mirror_vols(built["%s_%s" % (d["enemy"], d["mirror"])])
        elif "copyOf" in d:
            vols = built["%s_%s" % (d["enemy"], d["copyOf"])]
        elif "copyFrom" in d:
            vols = built.get(d["copyFrom"]) or build_detail(by_key[d["copyFrom"]])
        else:
            vols = build_detail(d)
        built[key] = vols
        if args.only and d["enemy"] != args.only:
            continue

        quads = faces_of(vols)
        positions, normals, uvs, indices = quads_to_geometry(quads)
        mins = [min(p[i] for p in positions) for i in range(3)]
        maxs = [max(p[i] for p in positions) for i in range(3)]
        center = [(mins[i] + maxs[i]) / 2 for i in range(3)]
        size = [maxs[i] - mins[i] for i in range(3)]
        scaled = [[(p[i] - center[i]) * voxel for i in range(3)] for p in positions]
        write_glb(os.path.join(outdir, key + ".glb"), [(key, scaled, normals, uvs, indices)], png)
        combined.append((key, scaled, normals, uvs, indices))

        # Три самых частых цвета по площади граней (атрибут Colors для распада).
        area = Counter()
        for q in quads:
            _, _, _, (u, v, w, h, col), _ = q
            area[col] += w * h
        top3 = "".join(c for c, _ in area.most_common(3))

        anchor = d["anchor"]
        a_center = [anchor["min"][i] + anchor["size"][i] / 2 for i in range(3)]
        manifest.append({
            "mesh": key,
            "enemy": d["enemy"],
            "replaces": d["replaces"],
            "anchor": anchor["part"],
            "size": size,
            "offset": [center[i] - a_center[i] for i in range(3)],
            "colors": top3,
            "triangles": len(indices) // 3,
        })
        total_tris += len(indices) // 3
        print("%-24s %3d×%3d×%3d вокселей  %5d треуг.  цвета %s" % (key, size[0], size[1], size[2], len(indices) // 3, top3))

    with open(os.path.join(outdir, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
    if not args.only:
        write_glb(os.path.join(outdir, "enemy_armor.glb"), combined, png)
    write_apply_script(manifest, voxel)
    print("мешей: %d, треугольников: %d -> %s" % (len(manifest), total_tris, outdir))


def lua_value(v):
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, (int, float)):
        return ("%.4f" % v).rstrip("0").rstrip(".") if isinstance(v, float) else str(v)
    if isinstance(v, list):
        return "{ " + ", ".join(lua_value(x) for x in v) + " }"
    raise TypeError(v)


def write_apply_script(manifest, voxel):
    template_path = os.path.join(HERE, "apply_template.lua")
    with open(template_path, encoding="utf-8") as f:
        template = f.read()
    lines = []
    for m in manifest:
        lines.append("\t{ mesh = %s, enemy = %s, replaces = %s, anchor = %s, size = %s, offset = %s, colors = %s }," % (
            lua_value(m["mesh"]), lua_value(m["enemy"]), lua_value(m["replaces"]), lua_value(m["anchor"]),
            lua_value(m["size"]), lua_value(m["offset"]), lua_value(m["colors"])))
    script = template.replace("--@@MANIFEST@@", "\n".join(lines)).replace("--@@VOXEL@@", str(voxel))
    out = os.path.join(ROOT, "tools", "lua", "apply_armor_meshes.lua")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(script)


if __name__ == "__main__":
    main()
