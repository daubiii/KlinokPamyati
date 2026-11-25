"""Рендер одного оружия на прозрачном фоне (для карточек): python3 render_one.py <id> <out.png> [px]"""
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, mathutils
import render_bl as RB, vox
import weapons3d as WP
from rbx import rot
wid, out = sys.argv[1], sys.argv[2]; px = int(sys.argv[3]) if len(sys.argv) > 3 else 900
RB.setup(res=(px, px), samples=48, sky=(0.07, 0.06, 0.06), sun_dir=(0.35, -0.55, -0.75), sun=4.0, amb=0.9)
bpy.context.scene.render.film_transparent = True
v = dict((w[0], w[1]) for w in WP.WEAPONS)[wid]()
lo, hi = v.bounds(); mid = (lo + hi) / 2 * WP.VS
R = rot(-25, 0, -45)
M = np.eye(4); M[:3, :3] = R; M[:3, 3] = -R @ np.array([mid[0], mid[1], mid[2]])
vox.to_blender(v, M, name=wid)
ext = (hi - lo + 1) * WP.VS
cd = bpy.data.cameras.new('cam'); cd.type = 'ORTHO'; cd.ortho_scale = max(ext[0], ext[1]) * 0.86
co = bpy.data.objects.new('cam', cd); bpy.context.scene.collection.objects.link(co); bpy.context.scene.camera = co
co.location = RB.P @ np.array([0, 0, 40.0])
co.rotation_euler = mathutils.Vector(RB.P @ np.array([0, 0, -1.0])).to_track_quat('-Z', 'Y').to_euler()
ld = bpy.data.lights.new('fill', 'AREA'); ld.energy = 600; ld.size = 20
ob = bpy.data.objects.new('fill', ld); ob.location = RB.P @ np.array([-8, 10, 25.0])
ob.rotation_euler = mathutils.Vector(RB.P @ np.array([8, -10, -25.0])).to_track_quat('-Z', 'Y').to_euler()
bpy.context.scene.collection.objects.link(ob)
bpy.context.scene.render.filepath = out; bpy.context.scene.render.image_settings.file_format = 'PNG'
bpy.context.scene.render.image_settings.color_mode = 'RGBA'
bpy.ops.render.render(write_still=True)
