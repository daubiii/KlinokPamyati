"""Превью брони мага: blender -b -P render_mage.py -- <out_dir> set1 set2 ...
Каждый набор: preview_<set>.obj, виды front/back/34; Body_* — манекен, G* — эмиссия."""
import bpy, sys, os, json, math
from mathutils import Vector
argv = sys.argv[sys.argv.index('--') + 1:]
out_dir, sets = argv[0], argv[1:]
HEAD = sets[0] == 'head'
if HEAD: sets = sets[1:]
OUT = os.environ.get('MAGE_OUT') or os.path.join(os.path.dirname(os.path.abspath(__file__)), 'assets')
glow = json.load(open(os.path.join(OUT, 'glow.json')))
CW, CH = 420, 560
VIEWS = {'front': Vector((0.15, 1, 0.15)), 'q34': Vector((-0.9, 1.0, 0.45)), 'back': Vector((0, -1, 0.12)), 'side': Vector((1, 0, 0.1))}
for sid in sets:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    engs = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    scene.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in engs else 'BLENDER_EEVEE'
    bpy.ops.wm.obj_import(filepath=os.path.join(OUT, f'preview_{sid}.obj'), forward_axis='NEGATIVE_Z', up_axis='Y')
    objs = [o for o in scene.objects if o.type == 'MESH']
    for o in objs:
        n = o.name.split('.')[0]
        if n.startswith('G'):
            hexc = glow.get(n, '#6FE3FF').lstrip('#')
            rgb = [int(hexc[i:i + 2], 16) / 255 for i in (0, 2, 4)]
            m = bpy.data.materials.new('g_' + n); m.use_nodes = True
            nt = m.node_tree; nt.nodes.clear()
            em = nt.nodes.new('ShaderNodeEmission'); em.inputs['Color'].default_value = (*[c ** 2.2 for c in rgb], 1); em.inputs['Strength'].default_value = 2.5
            ou = nt.nodes.new('ShaderNodeOutputMaterial'); nt.links.new(em.outputs[0], ou.inputs[0])
            o.data.materials.clear(); o.data.materials.append(m)
        else:
            for m in o.data.materials:
                if m and m.use_nodes:
                    for nd in m.node_tree.nodes:
                        if nd.type == 'TEX_IMAGE': nd.interpolation = 'Closest'
                        if nd.type == 'BSDF_PRINCIPLED':
                            nd.inputs['Roughness'].default_value = 0.9
                            if 'Specular IOR Level' in nd.inputs: nd.inputs['Specular IOR Level'].default_value = 0.1
    world = bpy.data.worlds.new('w'); scene.world = world; world.use_nodes = True
    bg = world.node_tree.nodes['Background']; bg.inputs[0].default_value = (0.03, 0.035, 0.045, 1); bg.inputs[1].default_value = 1.0
    for rot, e in (((math.radians(50), 0, math.radians(25)), 3.0), ((math.radians(65), 0, math.radians(-150)), 1.3), ((math.radians(80), 0, math.radians(180)), 0.8)):
        ld = bpy.data.lights.new('sun', 'SUN'); ld.energy = e
        lo_ = bpy.data.objects.new('sun', ld); lo_.rotation_euler = rot; scene.collection.objects.link(lo_)
    scene.view_settings.view_transform = 'Standard'
    try: scene.eevee.taa_render_samples = 8
    except Exception: pass
    cd = bpy.data.cameras.new('cam'); cd.type = 'ORTHO'
    cam = bpy.data.objects.new('cam', cd); scene.collection.objects.link(cam); scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = CW, CH
    lo = Vector((1e9,) * 3); hi = -lo
    for o in objs:
        for c in o.bound_box:
            p = o.matrix_world @ Vector(c); lo = Vector(map(min, lo, p)); hi = Vector(map(max, hi, p))
    ctr = (lo + hi) / 2
    cd.ortho_scale = max(hi.z - lo.z, (hi.x - lo.x) * CH / CW) * 1.12
    if HEAD:
        ctr = Vector((0, 0, 5.4)); cd.ortho_scale = 3.2
        bpy.data.objects  # noqa
    for vn, d in (VIEWS.items() if not HEAD else [('hfront', Vector((0, 1, 0.12))), ('hhigh', Vector((0.5, 1, 0.6)))]):
        d = d.normalized()
        cam.location = ctr + d * 60
        cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = os.path.join(out_dir, f'{sid}_{vn}.png')
        bpy.ops.render.render(write_still=True)
