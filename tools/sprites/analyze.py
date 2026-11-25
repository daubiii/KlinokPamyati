"""Разбор спрайтов мобов из assets: размеры, рамки непрозрачных пикселей.

Запуск: python -I tools/sprites/analyze.py <папка assets>
"""
import json
import sys
from pathlib import Path

from PIL import Image

DIRS = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]

# Папка -> враг (по metadata.json / промтам).
MOBS = {
    "shade": "Voxel_pixel_art_sprite_o-Idle",
    "martyr": "Voxel_pixel_art_sprite_of",
    "archer": "Voxel_pixel_art_sprite_of1",
    "knight": "Voxel_pixel_art_sprite_of_1",
    "gatekeeper": "Voxel_pixel_art_sprite_of_The_Gatekeeper",
}
GUARD_SHEET = "Voxel_pixel_art_sprite_o-Idle-spritesheet/Voxel_pixel_art_sprite_o-Idle.png"


def load_views(root: Path):
    views = {}
    for mob, folder in MOBS.items():
        views[mob] = {d: Image.open(root / folder / "Idle" / "rotations" / f"{d}.png").convert("RGBA") for d in DIRS}
    sheet = Image.open(root / GUARD_SHEET).convert("RGBA")
    cell = sheet.height
    views["guard"] = {d: sheet.crop((i * cell, 0, (i + 1) * cell, cell)) for i, d in enumerate(DIRS)}
    return views


def main():
    root = Path(sys.argv[1])
    views = load_views(root)
    for mob, dirs in views.items():
        print(f"== {mob}")
        for d in ("south", "east", "north", "west"):
            img = dirs[d]
            bbox = img.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
            print(f"  {d:6s} size={img.size} bbox={bbox}")


if __name__ == "__main__":
    main()
