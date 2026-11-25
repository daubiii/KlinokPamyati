"""Вокселизатор мобов: 3D-модели по 8-ракурсным спрайтам из assets.

Идея — «оболочка по силуэтам» (visual hull): воксель (x, y, z) существует,
если он закрашен и на виде спереди/сзади (x, y), и на виде сбоку (z, y).
Цвет грани берётся с того вида, куда грань смотрит: передняя — со
«south», задняя — с «north», правая — с «east», левая — с «west».
Затем воксели раскладываются по узлам рига (ноги, торс, голова, руки с
оружием), чтобы EnemyVisualController мог их анимировать, а соседние
одноцветные воксели склеиваются в бруски.

Запуск: python -I tools/sprites/voxelize.py <папка assets> <папка выхода, по модулю на моба> [превью.png]
"""
import sys
from collections import Counter
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from analyze import load_views  # noqa: E402

# Рост моделей в стадах (как Enemies.Types[..].size.Y) и доли рига.
SPECS = {
    "guard": {"height": 5.4, "legs": 0.40, "torso": 0.34, "down": 1, "colors": 10},
    "shade": {"height": 4.8, "legs": 0.34, "torso": 0.38, "down": 1, "colors": 10},
    "knight": {"height": 6.4, "legs": 0.36, "torso": 0.36, "down": 1, "colors": 10},
    "archer": {"height": 5.2, "legs": 0.40, "torso": 0.34, "down": 1, "colors": 10},
    "martyr": {"height": 4.8, "legs": 0.40, "torso": 0.35, "down": 1, "colors": 10},
    # Алебарда на спрайте в левой руке, а удары анимирует правая: зеркалим.
    "gatekeeper": {"height": 13.0, "legs": 0.36, "torso": 0.36, "down": 1, "colors": 12, "mirror": True},
}

ALPHA = 110


def quantize(views, colors):
    """Общая палитра на все ракурсы моба: меньше цветов — длиннее бруски.
    Палитра строится только по закрашенным пикселям (иначе прозрачный фон
    тянет её в чёрный)."""
    opaque = []
    for img in views.values():
        for r, g, b, a in img.get_flattened_data():
            if a > ALPHA:
                opaque.append((r, g, b))
    swatch = Image.new("RGB", (len(opaque), 1))
    swatch.putdata(opaque)
    pal = swatch.quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    out = {}
    for name, img in views.items():
        q = img.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
        q.putalpha(img.getchannel("A"))
        out[name] = q
    return out


def downsample(img, k):
    """k×k блок → один пиксель: закрашен, если закрашена хотя бы половина."""
    w, h = img.width // k, img.height // k
    px = img.load()
    mask = [[False] * w for _ in range(h)]
    color = [[None] * w for _ in range(h)]
    for by in range(h):
        for bx in range(w):
            seen = Counter()
            opaque = 0
            for dy in range(k):
                for dx in range(k):
                    r, g, b, a = px[bx * k + dx, by * k + dy]
                    if a > ALPHA:
                        opaque += 1
                        seen[(r, g, b)] += 1
            if opaque * 2 >= k * k:
                mask[by][bx] = True
                # Тёмная обводка спрайта уступает «настоящему» цвету блока:
                # в 3D контур не нужен, а чёрные пятна делают модель грязной.
                ranked = seen.most_common()
                bright = [c for c, _ in ranked if luminance(c) > 38]
                color[by][bx] = bright[0] if bright else ranked[0][0]
    return mask, despeckle(mask, color)


def despeckle(mask, color, passes=2):
    """Одиночный пиксель среди однотонных соседей перекрашивается в цвет
    большинства: после уменьшения пиксель-арт иначе превращается в рябь."""
    h, w = len(mask), len(mask[0])
    for _ in range(passes):
        out = [row[:] for row in color]
        for y in range(h):
            for x in range(w):
                if not mask[y][x]:
                    continue
                seen = Counter()
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if (dx or dy) and 0 <= y + dy < h and 0 <= x + dx < w and mask[y + dy][x + dx]:
                            seen[color[y + dy][x + dx]] += 1
                if not seen:
                    continue
                best, count = seen.most_common(1)[0]
                if seen[color[y][x]] <= 1 and count >= 4 and best != color[y][x]:
                    out[y][x] = best
        color = out
    return color


def frame(mask):
    """Нижняя строка (земля) и центр ступней по нижней четверти силуэта."""
    h = len(mask)
    w = len(mask[0])
    rows = [y for y in range(h) if any(mask[y])]
    top, bottom = rows[0], rows[-1]
    feet = range(bottom - max((bottom - top) // 4, 1), bottom + 1)
    xs = [x for y in feet for x in range(w) if mask[y][x]]
    center = sum(xs) / len(xs)
    return top, bottom, center


def runs(row):
    """Непрерывные отрезки закрашенных пикселей строки: [(начало, конец)]."""
    out = []
    start = None
    for x, filled in enumerate(row + [False]):
        if filled and start is None:
            start = x
        elif not filled and start is not None:
            out.append((start, x - 1))
            start = None
    return out


def build(mob, views, spec):
    """Рельеф по виду спереди: силуэт и цвета south сохраняются попиксельно,
    каждый отрезок строки выдавливается в глубину. Глубина тела в строке —
    по виду сбоку (только отрезок у центра: оружие и плащ, торчащие на
    боковом виде, тело не раздувают), узкие отрезки (руки, оружие) — тонкие,
    края отрезка скруглены. Передняя половина красится с south, задняя — с
    north (зеркально)."""
    k = spec["down"]
    views = quantize(views, spec["colors"])
    data = {d: downsample(views[d], k) for d in ("south", "north", "east", "west")}
    frames = {d: frame(data[d][0]) for d in data}

    south_mask, south_color = data["south"]
    north_mask, north_color = data["north"]
    top, bottom, center = frames["south"]
    _, n_bottom, n_center = frames["north"]
    height_vox = bottom - top + 1
    depth_ratio = spec.get("depth", 0.6)

    def side_depth(v):
        """Глубина тела на высоте v по боковым видам (отрезок у центра)."""
        best = 0
        for view in ("east", "west"):
            mask, _ = data[view]
            _, b, c = frames[view]
            y = b - v
            if not (0 <= y < len(mask)):
                continue
            for x0, x1 in runs(mask[y]):
                if x0 - 1 <= c <= x1 + 1:
                    best = max(best, x1 - x0 + 1)
        return best

    def back_pixel(x, v):
        y = n_bottom - v
        px = int(round(n_center + x))
        if 0 <= y < len(north_mask) and 0 <= px < len(north_mask[0]) and north_mask[y][px]:
            return north_color[y][px]
        return None

    # Модель смотрит в −Z, правая рука в +X.
    # south (смотрим в лицо): пиксель вправо = левая рука модели (−X).
    # north (смотрим в спину): пиксель вправо = правая рука (+X).
    voxels = {}
    for v in range(height_vox):
        y = bottom - v
        row = south_mask[y]
        row_runs = runs(row)
        if not row_runs:
            continue
        total = sum(x1 - x0 + 1 for x0, x1 in row_runs)
        body = side_depth(v) or 3
        body = max(2, min(body, int(total * depth_ratio + 1), spec.get("max_depth", 99)))
        for x0, x1 in row_runs:
            width = x1 - x0 + 1
            depth = min(body, max(2, width + 1)) if width < 5 else body
            for px in range(x0, x1 + 1):
                d = depth
                edge = min(px - x0, x1 - px)
                if width >= 4 and edge == 0:
                    d = max(2, depth - 2)
                elif width >= 7 and edge == 1:
                    d = max(2, depth - 1)
                x = -int(round(px - center))
                front = south_color[y][px]
                back = back_pixel(x, v) or front
                for z in range(-(d - d // 2), d // 2):
                    voxels[(x, v, z)] = front if z < 0 else back

    # Сплошной объём: склейка тогда даёт бруски на всю глубину столбца.
    surface = voxels
    if spec.get("mirror"):
        surface = {(-x, y, z): c for (x, y, z), c in surface.items()}
    return surface, height_vox


def segment(surface, height_vox, spec):
    """Узлы рига по высоте и ширине силуэта."""
    leg_top = height_vox * spec["legs"]
    torso_top = leg_top + height_vox * spec["torso"]

    def half_width(rows):
        widths = []
        for y in rows:
            xs = [x for (x, yy, _z) in surface if yy == y]
            if xs:
                widths.append((max(xs) - min(xs)) / 2)
        widths.sort()
        return widths[len(widths) // 2] if widths else 2

    torso_rows = range(int(leg_top), int(torso_top))
    core = max(half_width(torso_rows) * 0.62, 1.5)
    feet_rows = range(0, max(int(leg_top * 0.5), 1))
    leg_span = max(half_width(feet_rows) + 0.5, core * 0.8)

    nodes = {}
    for (x, y, z), color in surface.items():
        side = "R" if x > 0 else "L"
        if y < leg_top:
            node = ("leg" + side) if abs(x) <= leg_span else ("hand" + side)
        elif y < torso_top:
            node = "torso" if abs(x) <= core else ("arm" + side)
        else:
            node = "head" if abs(x) <= core * 1.1 else ("arm" + side)
        nodes[(x, y, z)] = node
    return nodes, leg_top, torso_top, core


def luminance(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def role_for(mob, node, color, y, torso_top):
    r, g, b = color
    lum = luminance(color)
    hot = r > 170 and g > 70 and b < 90 and r - b > 110
    if mob == "martyr" and hot:
        return "crack"
    if mob == "knight" and hot:
        return "rune"
    if node == "head" and (lum > 175 or (hot and y > torso_top)):
        return "eye"
    if mob == "gatekeeper" and node == "head" and hot:
        return "eye"
    if node.startswith("hand") or node.startswith("arm"):
        return "weapon"
    return None


def merge(surface, nodes, roles):
    """Жадная склейка: одноцветные воксели одного узла и роли растут в бокс
    сначала по Z, потом по Y, потом по X — пока все клетки совпадают."""
    key_of = {p: (c, nodes[p], roles.get(p)) for p, c in surface.items()}
    used = set()
    boxes = []
    for start in sorted(surface, key=lambda p: (p[0], p[1], p[2])):
        if start in used:
            continue
        key = key_of[start]
        x0, y0, z0 = start

        def free(p):
            return p not in used and key_of.get(p) == key

        # Сначала в глубину (столбец пикселя), потом по высоте, потом вширь.
        z1 = z0
        while free((x0, y0, z1 + 1)):
            z1 += 1
        y1 = y0
        while all(free((x0, y1 + 1, z)) for z in range(z0, z1 + 1)):
            y1 += 1
        x1 = x0
        while all(free((x1 + 1, y, z)) for y in range(y0, y1 + 1) for z in range(z0, z1 + 1)):
            x1 += 1
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                for z in range(z0, z1 + 1):
                    used.add((x, y, z))
        color, node, role = key
        boxes.append({"x0": x0, "x1": x1, "y0": y0, "y1": y1, "z0": z0, "z1": z1,
                      "color": color, "node": node, "role": role})
    return boxes


def lua_mob(mob, boxes, spec, height_vox, leg_top, torso_top, core):
    voxel = spec["height"] / height_vox
    lines = [f'\t{mob} = {{', f'\t\tvoxel = {voxel:.4f},',
             f'\t\tlegs = {leg_top * voxel:.3f}, torso = {(torso_top - leg_top) * voxel:.3f},',
             f'\t\thead = {(height_vox - torso_top) * voxel:.3f}, core = {core * voxel:.3f},',
             '\t\tboxes = {']
    for b in boxes:
        cx = (b["x0"] + b["x1"]) / 2 * voxel
        cy = ((b["y0"] + b["y1"]) / 2 + 0.5) * voxel
        cz = (b["z0"] + b["z1"]) / 2 * voxel
        sx = (b["x1"] - b["x0"] + 1) * voxel
        sy = (b["y1"] - b["y0"] + 1) * voxel
        sz = (b["z1"] - b["z0"] + 1) * voxel
        color = "%02X%02X%02X" % b["color"]
        role = f', "{b["role"]}"' if b["role"] else ""
        lines.append(f'\t\t\t{{ "{b["node"]}", {cx:.3f}, {cy:.3f}, {cz:.3f}, {sx:.3f}, {sy:.3f}, {sz:.3f}, "{color}"{role} }},')
    lines.append('\t\t},')
    lines.append('\t},')
    return "\n".join(lines)


NODE_TINT = {"head": (255, 80, 80), "torso": (80, 200, 80), "armR": (80, 120, 255), "armL": (60, 200, 255),
             "handR": (160, 80, 255), "handL": (255, 80, 220), "legR": (255, 200, 60), "legL": (255, 140, 40)}


def preview(results, path):
    """Превью без Studio: вид спереди и сбоку цветами модели и разметкой узлов."""
    cell = 7
    tiles = []
    for mob, (surface, nodes) in results.items():
        xs = [p[0] for p in surface]
        ys = [p[1] for p in surface]
        zs = [p[2] for p in surface]
        w = (max(xs) - min(xs) + 1)
        d = (max(zs) - min(zs) + 1)
        h = max(ys) + 1
        img = Image.new("RGB", ((w * 2 + d * 2 + 6) * cell, (h + 2) * cell), (40, 40, 48))
        px = img.load()

        def put(u, v, color):
            for dy in range(cell):
                for dx in range(cell):
                    px[u * cell + dx, (h - v) * cell + dy] = color

        # Спереди: ближний к камере воксель (минимальный z).
        front = {}
        side = {}
        for (x, y, z), color in surface.items():
            key = (x, y)
            if key not in front or z < front[key][0]:
                front[key] = (z, color, nodes[(x, y, z)])
            key = (z, y)
            if key not in side or x > side[key][0]:
                side[key] = (x, color, nodes[(x, y, z)])
        for (x, y), (_, color, node) in front.items():
            put(-x - min(-p for p in xs) if False else (max(xs) - x), y, color)
            put(w + 2 + (max(xs) - x), y, NODE_TINT[node])
        for (z, y), (_, color, node) in side.items():
            put(2 * w + 4 + (max(zs) - z), y, color)
        tiles.append(img)
    total_w = max(t.width for t in tiles)
    total_h = sum(t.height for t in tiles)
    sheet = Image.new("RGB", (total_w, total_h), (30, 30, 36))
    y = 0
    for t in tiles:
        sheet.paste(t, (0, y))
        y += t.height
    sheet.save(path)


def main():
    root = Path(sys.argv[1])
    out = Path(sys.argv[2])
    views = load_views(root)
    chunks = []
    previews = {}
    stats = []
    for mob, spec in SPECS.items():
        surface, height_vox = build(mob, views[mob], spec)
        nodes, leg_top, torso_top, core = segment(surface, height_vox, spec)
        roles = {}
        for pos, color in surface.items():
            role = role_for(mob, nodes[pos], color, pos[1], torso_top)
            if role:
                roles[pos] = role
        boxes = merge(surface, nodes, roles)
        chunks.append(lua_mob(mob, boxes, spec, height_vox, leg_top, torso_top, core))
        previews[mob] = (surface, nodes)
        stats.append(f"{mob}: voxels={len(surface)} boxes={len(boxes)} height_vox={height_vox}")
    # По модулю на моба: Studio не принимает Source длиннее 200 000 символов.
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*.lua"):
        old.unlink()
    for mob, chunk in zip(SPECS, chunks):
        body = chunk.split("\n")
        body[0] = "return {"
        body[-1] = "}"
        header = (
            "--!nonstrict\n"
            f"-- MobVoxels.{mob} (СГЕНЕРИРОВАНО tools/sprites/voxelize.py — руками не править)\n"
            "-- 3D-модель моба по 8-ракурсным спрайтам из assets: оболочка по\n"
            "-- силуэтам, цвета граней с соответствующих ракурсов, разметка по узлам\n"
            "-- рига. Бокс: { узел, cx, cy, cz, sx, sy, sz, цвет, роль? } — центр от\n"
            "-- центра ступней (модель смотрит в −Z), размеры в стадах.\n\n"
        )
        text = "\n".join(line[1:] if line.startswith("\t") else line for line in body)
        (out / f"{mob}.lua").write_text(header + text + "\n", encoding="utf-8")
    if len(sys.argv) > 3:
        preview(previews, sys.argv[3])
    print("\n".join(stats))


if __name__ == "__main__":
    main()
