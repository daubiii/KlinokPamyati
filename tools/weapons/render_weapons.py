"""Рендер оружия: лист превью (Cycles) на тёмном фоне. python3 render_weapons.py out.png [ids] [spp] [w]"""
import sys, math, os
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import render_bl as RB, vox
import weapons3d as WP
from rbx import rot

def Mx(R, t):
    m = np.eye(4); m[:3, :3] = R; m[:3, 3] = t; return m

def main():
    out = sys.argv[1]
    ids = sys.argv[2].split(',') if len(sys.argv) > 2 and sys.argv[2] != 'all' else [w[0] for w in WP.WEAPONS]
    spp = int(sys.argv[3]) if len(sys.argv) > 3 else 48
    W = int(sys.argv[4]) if len(sys.argv) > 4 else 1800
    n = len(ids); cols = min(n, 4); rows = (n + cols - 1) // cols
    cell = 9.0
    H = int(W * rows / cols * 1.0)
    RB.setup(res=(W, H), samples=spp, sky=(0.07, 0.06, 0.06), sun_dir=(0.35, -0.55, -0.75), sun=4.0, amb=0.9)
    fns = dict((w[0], w[1]) for w in WP.WEAPONS)
    for idx, wid in enumerate(ids):
        v = fns[wid]()
        r, c = divmod(idx, cols)
        cx = (c - (cols - 1) / 2) * cell; cy = -(r - (rows - 1) / 2) * cell
        (lo, hi) = v.bounds(); mid = (lo + hi) / 2 * WP.VS
        R = rot(-25, 0, -42)       # наклон по диагонали + лёгкий поворот к камере
        t = np.array([cx, cy, 0]) - R @ np.array([mid[0], mid[1], 0])
        RB_ob = vox.to_blender(v, Mx(R, t), name=wid)
    span_x = cols * cell; span_y = rows * cell
    import mathutils
    cd = bpy.data.cameras.new('cam'); cd.type = 'ORTHO'; cd.ortho_scale = max(span_x, span_y * W / H) * 1.0
    co = bpy.data.objects.new('cam', cd); bpy.context.scene.collection.objects.link(co); bpy.context.scene.camera = co
    p = RB.P @ np.array([0, 0, 40.0]); co.location = p
    co.rotation_euler = mathutils.Vector(RB.P @ np.array([0, 0, -1.0])).to_track_quat('-Z', 'Y').to_euler()
    # мягкий заполняющий свет спереди
    ld = bpy.data.lights.new('fill', 'AREA'); ld.energy = 900; ld.size = 30
    ob = bpy.data.objects.new('fill', ld); ob.location = RB.P @ np.array([-10, 14, 30.0])
    ob.rotation_euler = mathutils.Vector(RB.P @ np.array([10, -14, -30.0])).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.collection.objects.link(ob)
    RB.render(out)

main()
