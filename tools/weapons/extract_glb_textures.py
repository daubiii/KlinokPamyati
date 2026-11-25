#!/usr/bin/env python3
"""extract_glb_textures.py — вытаскивает вшитые в GLB палитровые PNG.

Roblox при импорте GLB сам загружает текстуры и выдаёт asset id; у части из них
представление всё ещё генерируется («Asset content representation is being
generated»). Чтобы не зависеть от этого, достаём палитры и заливаем сами.

    python extract_glb_textures.py <файл.glb> [<файл.glb> ...]
"""
import json
import struct
import sys
from pathlib import Path

from PIL import Image  # noqa: F401  (проверка, что Pillow на месте)


def read_glb(path: Path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise SystemExit(f"{path.name}: это не GLB")
    offset = 12
    gltf, binary = None, b""
    while offset < length:
        chunk_len, chunk_type = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8 : offset + 8 + chunk_len]
        if chunk_type == 0x4E4F534A:  # JSON
            gltf = json.loads(chunk.decode("utf-8"))
        elif chunk_type == 0x004E4942:  # BIN
            binary = chunk
        offset += 8 + chunk_len + ((4 - chunk_len % 4) % 4)
    return gltf, binary


def extract(path: Path, out_dir: Path):
    gltf, binary = read_glb(path)
    images = gltf.get("images", [])
    if not images:
        print(f"{path.name}: встроенных изображений нет")
        return []

    buffer_views = gltf.get("bufferViews", [])
    saved = []
    for index, image in enumerate(images):
        view_index = image.get("bufferView")
        if view_index is None:
            continue
        view = buffer_views[view_index]
        start = view.get("byteOffset", 0)
        end = start + view["byteLength"]
        payload = binary[start:end]
        mime = image.get("mimeType", "image/png")
        ext = ".png" if "png" in mime else ".jpg"
        name = image.get("name") or f"texture_{index}"
        safe = "".join(ch if ch.isalnum() or ch in "-_" else "_" for ch in name)
        target = out_dir / f"{path.stem}__{safe}{ext}"
        target.write_bytes(payload)
        saved.append(target)
        print(f"  {target.name}: {len(payload)} байт, {mime}")
    return saved


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    out_dir = Path.cwd() / "tools" / "weapons" / "palettes"
    out_dir.mkdir(parents=True, exist_ok=True)
    for arg in sys.argv[1:]:
        print(Path(arg).name)
        extract(Path(arg), out_dir)


if __name__ == "__main__":
    main()
