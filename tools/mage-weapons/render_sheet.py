"""Лист превью оружия (Blender 4.2, EEVEE): blender -b -P render_sheet.py -- <obj> <out.png> <iso|side> <cols> [rarity.json]
Каждое оружие — объект W_<id> (+ неон G*_<id>), ставим в сетку, ортокамера, неон — Emission."""
import bpy, sys, os, json, math
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
obj_path, out_path, view, cols = argv[0], argv[1], argv[2], int(argv[3])
order = json.loads(open(argv[4]).read()) if len(argv) > 4 else None

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
bpy.ops.wm.obj_import(filepath=obj_path, forward_axis='NEGATIVE_Z', up_axis='Y')
objs = [o for o in scene.objects if o.type == 'MESH']
groups = {}
for o in objs:
    wid = o.name.split('_', 1)[1].split('.')[0]
    groups.setdefault(wid, []).append(o)
ids = [w for w in (order or sorted(groups)) if w in groups]

# материалы: палитра без сглаживания, неон — эмиссия по цвету из имени mtl не знаем → берём из Kd? задаём по объекту
glow_colors = json.loads(open(os.path.splitext(obj_path)[0] + '_glow.json').read()) if os.path.exists(os.path.splitext(obj_path)[0] + '_glow.json') else {}
for o in objs:
    if o.name.startswith('G'):
        hexc = glow_colors.get(o.name.split('.')[0], '#FFB536').lstrip('#')
        rgb = [int(hexc[i:i + 2], 16) / 255 for i in (0, 2, 4)]
        m = bpy.data.materials.new('glow_' + o.name); m.use_nodes = True
        nt = m.node_tree; nt.nodes.clear()
        em = nt.nodes.new('ShaderNodeEmission'); em.inputs['Color'].default_value = (*[c ** 2.2 for c in rgb], 1); em.inputs['Strength'].default_value = 2.2
        out = nt.nodes.new('ShaderNodeOutputMaterial'); nt.links.new(em.outputs[0], out.inputs[0])
        o.data.materials.clear(); o.data.materials.append(m)
    else:
        for m in o.data.materials:
            if m and m.use_nodes:
                for n in m.node_tree.nodes:
                    if n.type == 'TEX_IMAGE': n.interpolation = 'Closest'
                    if n.type == 'BSDF_PRINCIPLED':
                        n.inputs['Roughness'].default_value = 0.9
                        if 'Specular IOR Level' in n.inputs: n.inputs['Specular IOR Level'].default_value = 0.1

# по одному оружию в кадре: прячем остальные, камера под рамку оружия
import tempfile
tmp = tempfile.mkdtemp()
world = bpy.data.worlds.new('w'); scene.world = world; world.use_nodes = True
bg = world.node_tree.nodes['Background']; bg.inputs[0].default_value = (0.012, 0.016, 0.016, 1); bg.inputs[1].default_value = 1.0
for rot, e in (((math.radians(50), 0, math.radians(30)), 3.2), ((math.radians(70), 0, math.radians(-140)), 1.2)):
    ld = bpy.data.lights.new('sun', 'SUN'); ld.energy = e
    lo_ = bpy.data.objects.new('sun', ld); lo_.rotation_euler = rot; scene.collection.objects.link(lo_)
scene.view_settings.view_transform = 'Standard'
try:
    scene.eevee.taa_render_samples = 6
except Exception:
    pass
cam_data = bpy.data.cameras.new('cam'); cam_data.type = 'ORTHO'
cam = bpy.data.objects.new('cam', cam_data); scene.collection.objects.link(cam); scene.camera = cam
CW, CH = int(os.environ.get("CW", "380")), int(os.environ.get("CH", "640"))
scene.render.resolution_x, scene.render.resolution_y = CW, CH
d = Vector((1.0, -1.6, 0.55)).normalized() if view == 'iso' else Vector((0, -1, 0))
frames = []
for wid in ids:
    for o in objs:
        o.hide_render = o not in groups[wid]
    lo = Vector((1e9, 1e9, 1e9)); hi = -lo
    for o in groups[wid]:
        for c in o.bound_box:
            p = o.matrix_world @ Vector(c); lo = Vector(map(min, lo, p)); hi = Vector(map(max, hi, p))
    ctr = (lo + hi) / 2
    if os.environ.get('HEAD'):
        ctr = Vector((ctr.x, ctr.y, hi.z - float(os.environ['HEAD'])))
    cam.location = ctr + d * 40
    cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam_data.ortho_scale = float(os.environ.get("ORTHO", "9.0"))
    scene.render.filepath = os.path.join(tmp, wid + '.png')
    bpy.ops.render.render(write_still=True)
    frames.append((wid, scene.render.filepath))
json.dump({'frames': frames, 'cols': cols, 'w': CW, 'h': CH}, open(out_path + '.json', 'w'))
