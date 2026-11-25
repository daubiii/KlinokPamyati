"""Рендер моделей rbx.Model в Blender Cycles (тени, мягкий свет, bloom неона)."""
import math, sys
import numpy as np
import bpy, bmesh
from PIL import Image, ImageFilter, ImageChops

P = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]], float)   # Roblox(Y-up) -> Blender(Z-up)

def srgb2lin(h):
    h = h.lstrip('#'); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]

def _box_geo(sx, sy, sz):
    v = [(x * sx / 2, y * sy / 2, z * sz / 2) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return v, f

def _wedge_geo(sx, sy, sz):
    a, b, c = sx / 2, sy / 2, sz / 2
    v = [(-a, -b, -c), (a, -b, -c), (a, -b, c), (-a, -b, c), (-a, b, c), (a, b, c)]
    f = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
    return v, f

def _cyl_geo(L, d, n=20):
    r = d / 2; v = []
    for x in (-L / 2, L / 2):
        for i in range(n):
            a = 2 * math.pi * i / n; v.append((x, r * math.cos(a), r * math.sin(a)))
    f = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n; f.append((i, j, n + j, n + i))
    return v, f

def _ball_geo(d, nu=16, nv=10):
    r = d / 2; v = [(0, -r, 0)]
    for j in range(1, nv):
        t = math.pi * j / nv - math.pi / 2
        for i in range(nu):
            a = 2 * math.pi * i / nu
            v.append((r * math.cos(t) * math.cos(a), r * math.sin(t), r * math.cos(t) * math.sin(a)))
    v.append((0, r, 0)); top = len(v) - 1; f = []
    for i in range(nu): f.append((0, 1 + (i + 1) % nu, 1 + i))
    for j in range(nv - 2):
        for i in range(nu):
            a = 1 + j * nu + i; b = 1 + j * nu + (i + 1) % nu
            f.append((a, b, b + nu, a + nu))
    base = 1 + (nv - 2) * nu
    for i in range(nu): f.append((base + i, base + (i + 1) % nu, top))
    return v, f

def geo(p):
    sx, sy, sz = p.size
    if p.cls == 'WedgePart': return _wedge_geo(sx, sy, sz)
    if p.shape == 'Cylinder': return _cyl_geo(sx, min(sy, sz))
    if p.shape == 'Ball': return _ball_geo(min(sx, sy, sz))
    return _box_geo(sx, sy, sz)

_mats = {}
def material(hexc, kind, transp):
    key = (hexc, kind, round(transp, 2))
    if key in _mats: return _mats[key]
    m = bpy.data.materials.new(f'{hexc}_{kind}_{transp}'); m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    lin = srgb2lin(hexc)
    bs.inputs['Base Color'].default_value = (*lin, 1)
    bs.inputs['Roughness'].default_value = 0.55
    if 'Specular IOR Level' in bs.inputs: bs.inputs['Specular IOR Level'].default_value = 0.25
    if kind == 'Neon':
        bs.inputs['Emission Color'].default_value = (*lin, 1)
        lum = max(lin)
        bs.inputs['Emission Strength'].default_value = (0.5 if transp > 0 else 1.5) * min(1.0, 0.55 / max(lum, 0.05)) ** 0.5
    if kind == 'Metal':
        bs.inputs['Metallic'].default_value = 0.6; bs.inputs['Roughness'].default_value = 0.4
    if kind == 'Glass':
        bs.inputs['Roughness'].default_value = 0.05
        bs.inputs['Alpha'].default_value = 0.55
    if transp > 0:
        bs.inputs['Alpha'].default_value = 1 - transp
    _mats[key] = m; return m

def build(placed):
    """placed: список (model, pos, yaw) -> меши в сцене."""
    from rbx import rot
    groups = {}
    for (m, pos, yaw) in placed:
        R0 = rot(yaw); t0 = np.array(pos, float)
        for p in m.parts:
            if p.transp >= 0.99: continue
            kind = 'Neon' if p.mat == 'Neon' else ('Glass' if p.mat == 'Glass' else ('Metal' if p.mat == 'Metal' else 'S'))
            key = (p.color, kind, round(p.transp, 2))
            g = groups.setdefault(key, ([], []))
            v, f = geo(p)
            k_ = len(g[0]) % 13 + 1
            v = [(a * (1 + 0.0007 * k_) , b * (1 + 0.0007 * k_), c * (1 + 0.0007 * k_)) for (a, b, c) in v]
            R = R0 @ p.R; t = R0 @ p.pos + t0
            vv = (P @ (R @ np.array(v).T + t[:, None])).T
            o = len(g[0]); g[0].extend(vv.tolist()); g[1].extend([tuple(i + o for i in ff) for ff in f])
        for (lp, rng, br, c, sh) in m.lights:
            w = P @ (R0 @ lp + t0)
            ld = bpy.data.lights.new('pl', 'POINT'); ld.energy = br * rng * 9; ld.color = [x / 255 for x in c]
            ld.shadow_soft_size = 0.3; ld.use_shadow = True
            if hasattr(ld, 'use_custom_distance'): ld.use_custom_distance = True; ld.cutoff_distance = rng * 1.3
            ob = bpy.data.objects.new('pl', ld); ob.location = w; bpy.context.scene.collection.objects.link(ob)
    for key, (V, F) in groups.items():
        me = bpy.data.meshes.new('m'); me.from_pydata(V, [], F); me.update()
        bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new('o', me); me.materials.append(material(*key))
        bpy.context.scene.collection.objects.link(ob)

def setup(res=(1600, 1000), samples=40, sky=(0.56, 0.75, 0.98), sun_dir=(0.45, -0.72, 0.5), sun=3.8, amb=0.72, sun_color=(1.0, 0.96, 0.9)):
    bpy.ops.wm.read_factory_settings(use_empty=True); _mats.clear()
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = samples
    sc.cycles.use_denoising = True; sc.cycles.max_bounces = 4; sc.cycles.diffuse_bounces = 2
    sc.cycles.glossy_bounces = 1; sc.cycles.transparent_max_bounces = 4
    sc.render.resolution_x, sc.render.resolution_y = res; sc.render.resolution_percentage = 100
    try:
        sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
    except Exception as e:
        print('VT', e); sc.view_settings.view_transform = 'Standard'
    sc.render.film_transparent = False
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes['Background']; bg.inputs[0].default_value = (*srgb2lin('#%02X%02X%02X' % tuple(int(c * 255) for c in sky)), 1)
    bg.inputs[1].default_value = amb
    sd = bpy.data.lights.new('sun', 'SUN'); sd.energy = sun; sd.angle = math.radians(3); sd.color = sun_color
    so = bpy.data.objects.new('sun', sd); sc.collection.objects.link(so)
    import mathutils
    d = P @ np.array(sun_dir, float)
    so.rotation_euler = mathutils.Vector(d).to_track_quat('-Z', 'Y').to_euler()
    return sc

def camera(pos_rbx, target_rbx, lens=32):
    sc = bpy.context.scene
    cd = bpy.data.cameras.new('cam'); cd.lens = lens; cd.clip_end = 2000
    co = bpy.data.objects.new('cam', cd); sc.collection.objects.link(co); sc.camera = co
    p = P @ np.array(pos_rbx, float); t = P @ np.array(target_rbx, float)
    co.location = p
    d = t - p
    import mathutils
    co.rotation_euler = mathutils.Vector(d).to_track_quat('-Z', 'Y').to_euler()

def render(out, bloom=True):
    sc = bpy.context.scene; sc.render.filepath = out; sc.render.image_settings.file_format = 'PNG'
    bpy.ops.render.render(write_still=True)
    if bloom:
        im = Image.open(out).convert('RGB'); a = np.asarray(im).astype(np.float32) / 255
        lum = a.max(axis=2); mask = np.clip((lum - 0.96) / 0.04, 0, 1)[..., None] * a
        m = Image.fromarray((mask * 255).astype(np.uint8))
        b1 = np.asarray(m.filter(ImageFilter.GaussianBlur(6))).astype(np.float32) / 255
        b2 = np.asarray(m.filter(ImageFilter.GaussianBlur(22))).astype(np.float32) / 255
        o = np.clip(a + b1 * 0.45 + b2 * 0.55, 0, 1)
        Image.fromarray((o * 255).astype(np.uint8)).save(out)


def render_depth(out, maxd=400.0):
    """Глубина (расстояние до камеры / maxd) в 16-бит PNG — для тумана в пост-обработке."""
    sc = bpy.context.scene
    m = bpy.data.materials.new('depth'); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    cam = nt.nodes.new('ShaderNodeCameraData'); div = nt.nodes.new('ShaderNodeMath'); div.operation = 'DIVIDE'
    div.inputs[1].default_value = maxd
    em = nt.nodes.new('ShaderNodeEmission'); outn = nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(cam.outputs['View Distance'], div.inputs[0]); nt.links.new(div.outputs[0], em.inputs['Color'])
    nt.links.new(em.outputs[0], outn.inputs['Surface'])
    vl = sc.view_layers[0]; vl.material_override = m
    w = sc.world; bgn = w.node_tree.nodes['Background']; old = (tuple(bgn.inputs[0].default_value), bgn.inputs[1].default_value)
    bgn.inputs[0].default_value = (1, 1, 1, 1); bgn.inputs[1].default_value = 1.0
    hidden = []
    for ob in sc.objects:
        if ob.type == 'LIGHT': ob.hide_render = True; hidden.append(ob)
    sc.cycles.samples = 1; sc.cycles.use_denoising = False
    sc.render.image_settings.color_depth = '16'
    sc.view_settings.view_transform = 'Standard'
    try: sc.display_settings.display_device = 'None'
    except Exception: pass
    old_s = sc.cycles.samples
    sc.render.filepath = out; bpy.ops.render.render(write_still=True)
    # вернуть сцену как была (несколько камер подряд)
    vl.material_override = None
    bgn.inputs[0].default_value = old[0]; bgn.inputs[1].default_value = old[1]
    for ob in hidden: ob.hide_render = False
    sc.render.image_settings.color_depth = '8'
    return old_s

def restore_samples(n):
    sc = bpy.context.scene; sc.cycles.samples = n; sc.cycles.use_denoising = True

def fog(img_path, depth_path, out, color=(30, 26, 40), density=0.9, start=0.08, bloom=True):
    im = np.asarray(Image.open(img_path).convert('RGB')).astype(np.float32)
    dp = np.asarray(Image.open(depth_path)).astype(np.float32)
    if dp.ndim == 3: dp = dp[..., 0]
    dp = dp / (65535.0 if dp.max() > 255 else 255.0)
    f = 1 - np.exp(-np.clip(dp - start, 0, None) * density * 4)
    f = np.clip(f, 0, 0.92)[..., None]
    o = im * (1 - f) + np.array(color, np.float32) * f
    Image.fromarray(np.clip(o, 0, 255).astype(np.uint8)).save(out)
