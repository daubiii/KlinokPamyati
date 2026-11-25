#!/usr/bin/env python3
# cut_generated_icons.py — нарезка сгенерированного листа иконок (7x4) в атлас UI.
#   python -I tools/icons/cut_generated_icons.py <лист.png>
# Лист: тёмный размытый фон, 28 иконок в порядке из docs/ICON_ATLAS_SPEC.md.
# Выход (tools/icons/out/):
#   cells/<имя>.png      — 20x20 с прозрачностью (по именам UiAtlas.Icons)
#   icons_atlas_new.png  — атлас 256x128, иконки на своих координатах из UiAtlas.lua
#   preview_dark.png / preview_paper.png — рендер 16/32/48 px на тёмном и бумаге
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

SHEET = sys.argv[1] if len(sys.argv) > 1 else "sheet.png"
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "icons", "out")

# Имена в порядке сетки 7x4 (совпадает с docs/ICON_ATLAS_SPEC.md).
NAMES = [
    ["coin", "soul", "dust", "ingot", "scroll", "quest", "chest"],
    ["trophy", "key", "lock", "sword", "staff", "helm", "armor"],
    ["shield", "flask", "dagger", "hammer", "ring", "amulet", "dash"],
    ["barrier", "candle", "star", "xp", "verdict", "whirl", "split"],
]

# Прямоугольники из src/ReplicatedStorage/Shared/Config/UiAtlas.lua (Icons).
RECTS = {
    "amulet": (222, 24), "armor": (2, 46), "barrier": (222, 2), "candle": (90, 46),
    "chest": (90, 24), "coin": (112, 2), "dagger": (156, 24), "dash": (46, 2),
    "dust": (112, 24), "flask": (68, 2), "hammer": (134, 24), "helm": (68, 24),
    "ingot": (134, 2), "key": (24, 46), "lock": (156, 2), "quest": (46, 46),
    "ring": (200, 24), "scroll": (24, 24), "shield": (24, 2), "soul": (90, 2),
    "split": (200, 2), "staff": (178, 24), "star": (46, 24), "sword": (2, 2),
    "trophy": (68, 46), "verdict": (2, 24), "whirl": (178, 2), "xp": (112, 46),
}
CELL = 20          # размер иконки в атласе
FIT = 18           # полезная площадь внутри ячейки (1px отступ)
BG_DIST = 24.0     # порог растущего фона (евклид по RGB)
DARK_LUMA = 40     # почти-чёрный контур в фон не превращается
MIN_PART = 12      # минимальный размер сторонней кляксы, px


def cut_cell(sheet: np.ndarray, col: int, row: int) -> np.ndarray:
    h, w = sheet.shape[:2]
    x0, x1 = round(col * w / 7), round((col + 1) * w / 7)
    y0, y1 = round(row * h / 4), round((row + 1) * h / 4)
    return sheet[y0:y1, x0:x1].astype(np.int16)


def remove_background(cell: np.ndarray) -> np.ndarray:
    """Фон убираем растущей от краёв областью: пиксель становится фоном,
    если близок к среднему своих фоновых соседей (тёмный градиент уходит,
    почти-чёрный контур и яркая иконка остаются)."""
    h, w = cell.shape[:2]
    bg = np.zeros((h, w), dtype=bool)
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            bg[y, x] = True
            queue.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            bg[y, x] = True
            queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        base = cell[y, x].astype(np.float64)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx]:
                dist = float(np.sqrt(np.sum((cell[ny, nx].astype(np.float64) - base) ** 2)))
                if dist <= BG_DIST:
                    bg[ny, nx] = True
                    queue.append((ny, nx))
    fg = ~bg
    # чистим одиночные тёмные кляксы фона, оставляя детали иконки
    seen = np.zeros((h, w), dtype=bool)
    for y in range(h):
        for x in range(w):
            if fg[y, x] and not seen[y, x]:
                comp = deque([(y, x)])
                seen[y, x] = True
                pixels = [(y, x)]
                while comp:
                    cy, cx = comp.popleft()
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            comp.append((ny, nx))
                            pixels.append((ny, nx))
                if len(pixels) < MIN_PART:
                    for py, px in pixels:
                        fg[py, px] = False
    return fg


def to_icon(cell: np.ndarray, fg: np.ndarray) -> Image.Image:
    ys, xs = np.where(fg)
    if len(ys) == 0:
        raise ValueError("иконка пустая после снятия фона")
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgba = np.zeros((y1 - y0, x1 - x0, 4), dtype=np.uint8)
    rgba[..., :3] = cell[y0:y1, x0:x1].astype(np.uint8)
    rgba[..., 3] = fg[y0:y1, x0:x1].astype(np.uint8) * 255
    img = Image.fromarray(rgba, "RGBA")
    # вписать в FIT x FIT, не растягивая пропорции
    scale = min(FIT / img.width, FIT / img.height, 1.0)
    if scale < 1.0:
        img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.BOX)
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    ox = (CELL - img.width) // 2
    oy = (CELL - img.height) // 2
    out.paste(img, (ox, oy))
    return out


def main() -> None:
    sheet = np.asarray(Image.open(SHEET).convert("RGB"))
    os.makedirs(OUT, exist_ok=True)
    cells_dir = os.path.join(OUT, "cells")
    os.makedirs(cells_dir, exist_ok=True)
    atlas = Image.new("RGBA", (256, 128), (0, 0, 0, 0))
    for row, names in enumerate(NAMES):
        for col, name in enumerate(names):
            cell = cut_cell(sheet, col, row)
            fg = remove_background(cell)
            icon = to_icon(cell, fg)
            icon.save(os.path.join(cells_dir, f"{name}.png"))
            x, y = RECTS[name]
            atlas.paste(icon, (x, y))
    atlas.save(os.path.join(OUT, "icons_atlas_new.png"))
    # превью: 16/32/48 px на тёмном и на бумаге
    for bg_name, bg_color in (("dark", (30, 27, 31)), ("paper", (239, 231, 207))):
        size = 6 * 48 + 5 * 16
        for scale in (1, 2, 3):
            pass
        canvas = Image.new("RGB", (28 * 56 + 8, 3 * 60 + 8), bg_color)
        for i, name in enumerate(RECTS):
            icon = Image.open(os.path.join(cells_dir, f"{name}.png"))
            for row, px in enumerate((16, 32, 48)):
                rendered = icon.resize((px, px), Image.NEAREST if px >= 32 else Image.BOX)
                canvas.paste(rendered, (8 + i * 56 + (48 - px) // 2, 8 + row * 60), rendered)
        canvas.save(os.path.join(OUT, f"preview_{bg_name}.png"))
    print("готово:", OUT)


if __name__ == "__main__":
    main()
