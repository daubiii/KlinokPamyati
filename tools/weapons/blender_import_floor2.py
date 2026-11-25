"""Импорт оружия этажа 2 в Blender (если нужен .blend и ручная доводка).
Blender 3.6+ или 4.x: Scripting → Open этот файл → Run Script.
Файлы weapons_floor2.obj / .mtl / weapons_palette_floor2.png должны лежать рядом (папка map/).
Каждое оружие — отдельный объект: W_<id> (основной, с палитрой) и G1_/G2_<id> (неоновое свечение).
Палитру Blender подтянет из .mtl; фильтрацию ставим «Closest», чтобы пиксели не мылились.
Обратный путь в Roblox: File → Export → glTF 2.0 (.glb), Import 3D в Studio, затем AssembleWeaponsFloor2.lua."""
import os
import bpy

here = os.path.dirname(os.path.abspath(bpy.data.filepath or __file__))
path = os.path.join(here, 'weapons_floor2.obj')
if not os.path.exists(path):
    path = os.path.join(here, '..', '..', 'map', 'weapons_floor2.obj')

before = set(bpy.data.objects)
if hasattr(bpy.ops.wm, 'obj_import'):
    bpy.ops.wm.obj_import(filepath=path)
else:
    bpy.ops.import_scene.obj(filepath=path)
new = [o for o in bpy.data.objects if o not in before]

for mat in bpy.data.materials:
    if not mat.use_nodes:
        continue
    for node in mat.node_tree.nodes:
        if node.type == 'TEX_IMAGE':
            node.interpolation = 'Closest'

# выставить в ряд для осмотра
for i, obj in enumerate(sorted([o for o in new if o.name.startswith('W_')], key=lambda o: o.name)):
    obj.location.x = i * 1.2
print('импортировано объектов:', len(new))
