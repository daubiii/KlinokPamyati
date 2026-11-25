"""Редактор карты этажа 1: одни и те же операции над мешами (OBJ), деталями rbxmx,
точками (Floor1Points) и конфигом зон (Floor1v2). Координаты мировые, Y вверх."""
import copy, math, re, itertools
import numpy as np
import xml.etree.ElementTree as ET
import f1lib, comps as CM

_ref = itertools.count(1)
def new_ref():
    return 'RBXK%08X' % next(_ref)

def set_text(el, v, fmt='%.4f'):
    el.text = fmt % v

class World:
    def __init__(self):
        self.objs, self.comps = CM.load_all()
        self.tree, self.parts = f1lib.load_rbxmx()
        self.parent = {c: p for p in self.tree.iter() for c in p}
        self.dead_faces = {z: set() for z in self.objs}   # (obj, face)
        self.log = []

    # ---------- выборка ----------
    def mesh(self, zones=None):
        for z, cs in self.comps.items():
            if zones and z not in zones:
                continue
            for c in cs:
                if c.faces:
                    yield z, c

    def V(self, z):
        return self.objs[z].v

    # ---------- меши ----------
    def del_comp(self, z, c):
        for fi in c.faces:
            self.dead_faces[z].add((c.obj, fi))
        c.faces = []

    def comp_shift(self, z, c, d):
        v = self.objs[z].v
        for vi in c.verts:
            p = v[vi]; p[0] += d[0]; p[1] += d[1]; p[2] += d[2]
        c.lo = c.lo + np.array(d); c.hi = c.hi + np.array(d)

    def comp_update_box(self, z, c):
        P = np.array([self.objs[z].v[i] for i in c.verts])
        c.lo = P.min(0); c.hi = P.max(0)

    def comp_dup(self, z, c, d=(0, 0, 0), obj=None):
        """копия компонента (новые вершины, те же UV), сдвинутая на d"""
        of = self.objs[z]; o = of.objects[c.obj]
        vmap = {}
        for vi in c.verts:
            p = of.v[vi]
            vmap[vi] = len(of.v); of.v.append([p[0] + d[0], p[1] + d[1], p[2] + d[2]])
        newfaces = []
        for fi in c.faces:
            mat, idx = o.faces[fi]
            o.faces.append((mat, [(vmap[vi], ti) for vi, ti in idx])); newfaces.append(len(o.faces) - 1)
        n = CM.Comp(); n.zone = z; n.obj = c.obj; n.faces = newfaces
        n.verts = np.array(sorted(vmap.values())); n.lo = c.lo + np.array(d); n.hi = c.hi + np.array(d)
        self.comps[z].append(n)
        return n

    def comp_transform(self, z, c, fn):
        """fn([x,y,z]) -> [x,y,z] для каждой вершины"""
        v = self.objs[z].v
        for vi in c.verts:
            v[vi][:] = fn(list(v[vi]))
        self.comp_update_box(z, c)

    # ---------- детали rbxmx ----------
    def alive_parts(self, folders=None, zones=None):
        for p in self.parts:
            if getattr(p, 'dead', False):
                continue
            if folders and p.folder not in folders:
                continue
            if zones and p.zone not in zones:
                continue
            yield p

    def part_set(self, p, pos=None, size=None):
        if pos is not None:
            el = p.cf['el']
            for k, val in zip('XYZ', pos):
                set_text(el.find(k), val)
            p.cf['p'] = list(pos)
        if size is not None:
            el = p.item.find("Properties/Vector3[@name='size']")
            for k, val in zip('XYZ', size):
                set_text(el.find(k), val)
            p.size = list(size)

    def part_del(self, p):
        par = self.parent.get(p.item)
        if par is not None and p.item in list(par):
            par.remove(p.item)
        p.dead = True

    def part_dup(self, p, d=(0, 0, 0), rename=None):
        item = copy.deepcopy(p.item)
        for it in item.iter('Item'):
            it.set('referent', new_ref())
        par = self.parent[p.item]
        par.append(item)
        self.parent[item] = par
        for ch in item.iter():
            for g in ch:
                self.parent[g] = ch
        n = f1lib.Part(item, list(p.path))
        if rename:
            nm = item.find("Properties/string[@name='Name']"); nm.text = rename; n.name = rename
        self.parts.append(n)
        self.part_set(n, pos=[n.cf['p'][i] + d[i] for i in range(3)])
        return n

    def model_dup(self, mi, d, rename=None):
        item = copy.deepcopy(mi)
        for it in item.iter('Item'):
            it.set('referent', new_ref())
        par = self.parent[mi]; par.append(item); self.parent[item] = par
        for ch in item.iter():
            for g in ch:
                self.parent[g] = ch
        if rename:
            item.find("Properties/string[@name='Name']").text = rename
        base = [f1lib.name_of(x) for x in self._path(item)]
        for ch in item.findall('Item'):
            if ch.get('class') in ('Part', 'WedgePart', 'MeshPart'):
                n = f1lib.Part(ch, base)
                self.parts.append(n)
                self.part_set(n, pos=[n.cf['p'][i] + d[i] for i in range(3)])
        return item

    def model_of(self, p):
        return p.path[3] if len(p.path) > 3 else None

    def new_part(self, zone, folder, name, pos, size, color=(90, 86, 100), cls='Part', transparency=0.0,
                 can_collide=True, rot=None, material=256, attrs=None, parent=None, shape=None):
        """деталь в Floor1Map.<zone>.<folder> (папку создаёт при нужде)"""
        root = self.tree.getroot()
        fm = [it for it in root.findall('Item') if f1lib.name_of(it) == 'Floor1Map'][0]
        if parent is not None:
            par = parent
        else:
            zi = [it for it in fm.findall('Item') if f1lib.name_of(it) == zone]
            if not zi:
                zi = [self._folder(fm, zone)]
            zf = [it for it in zi[0].findall('Item') if f1lib.name_of(it) == folder]
            if not zf:
                zf = [self._folder(zi[0], folder)]
            par = zf[0]
        R = rot or [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
        col = 0xFF000000 | (color[0] << 16) | (color[1] << 8) | color[2]
        xml = (f'<Item class="{cls}" referent="{new_ref()}"><Properties><string name="Name">{name}</string>'
               f'<bool name="Anchored">true</bool><CoordinateFrame name="CFrame"><X>0</X><Y>0</Y><Z>0</Z>'
               + ''.join(f'<R{i}{j}>{R[i][j]:.6f}</R{i}{j}>' for i in range(3) for j in range(3)) +
               f'</CoordinateFrame><Color3uint8 name="Color3uint8">{col}</Color3uint8><token name="Material">{material}</token>'
               f'<Vector3 name="size"><X>1</X><Y>1</Y><Z>1</Z></Vector3><token name="TopSurface">0</token><token name="BottomSurface">0</token>'
               + (f'<token name="shape">{shape}</token>' if shape is not None else '') +
               f'<bool name="CanCollide">{"true" if can_collide else "false"}</bool><bool name="CastShadow">false</bool>'
               f'<float name="Transparency">{transparency}</float></Properties></Item>')
        item = ET.fromstring(xml)
        if attrs:
            self._attrs(item, attrs)
        par.append(item); self.parent[item] = par
        for ch in item.iter():
            for g in ch:
                self.parent[g] = ch
        p = f1lib.Part(item, [f1lib.name_of(x) for x in self._path(par)])
        self.parts.append(p)
        self.part_set(p, pos=pos, size=size)
        return p

    def new_model(self, zone, folder, name, attrs=None):
        root = self.tree.getroot()
        fm = [it for it in root.findall('Item') if f1lib.name_of(it) == 'Floor1Map'][0]
        zi = [it for it in fm.findall('Item') if f1lib.name_of(it) == zone][0]
        zf = [it for it in zi.findall('Item') if f1lib.name_of(it) == folder]
        par = zf[0] if zf else self._folder(zi, folder)
        it = ET.fromstring(f'<Item class="Model" referent="{new_ref()}"><Properties><string name="Name">{name}</string></Properties></Item>')
        if attrs:
            self._attrs(it, attrs)
        par.append(it); self.parent[it] = par
        for ch in it.iter():
            for g in ch:
                self.parent[g] = ch
        return it

    def add_light(self, zone, name, pos, color=(1.0, 0.588, 0.314), rng=20.0, bright=1.8):
        p = self.new_part(zone, 'Lights', name, pos, (0.2, 0.2, 0.2), transparency=1.0, can_collide=False)
        li = ET.fromstring(f'<Item class="PointLight" referent="{new_ref()}"><Properties><Color3 name="Color"><R>{color[0]:.3f}</R><G>{color[1]:.3f}</G><B>{color[2]:.3f}</B></Color3>'
                           f'<float name="Range">{rng:.2f}</float><float name="Brightness">{bright:.2f}</float><bool name="Shadows">false</bool></Properties></Item>')
        p.item.append(li); self.parent[li] = p.item
        return p

    def _attrs(self, item, attrs):
        """AttributesSerialize (base64) — только bool/строки/числа"""
        import base64, struct
        buf = struct.pack('<I', len(attrs))
        for k, v in attrs.items():
            kb = k.encode(); buf += struct.pack('<I', len(kb)) + kb
            if isinstance(v, bool):
                buf += bytes([3, 1 if v else 0])
            elif isinstance(v, (int, float)):
                buf += bytes([6]) + struct.pack('<d', float(v))
            else:
                vb = str(v).encode(); buf += bytes([2]) + struct.pack('<I', len(vb)) + vb
        props = item.find('Properties')
        el = ET.SubElement(props, 'BinaryString', {'name': 'AttributesSerialize'})
        el.text = base64.b64encode(buf).decode()

    def _folder(self, parent, name):
        it = ET.fromstring(f'<Item class="Folder" referent="{new_ref()}"><Properties><string name="Name">{name}</string></Properties></Item>')
        parent.append(it); self.parent[it] = parent
        for ch in it.iter():
            for g in ch:
                self.parent[g] = ch
        return it

    def _path(self, el):
        out = []
        while el is not None and el.tag == 'Item':
            out.append(el); el = self.parent.get(el)
        return list(reversed(out))

    # ---------- запись ----------
    def write_objs(self, outdir):
        for z, of in self.objs.items():
            dead = self.dead_faces[z]
            for oi, o in enumerate(of.objects):
                o.faces = [f for fi, f in enumerate(o.faces) if (oi, fi) not in dead]
            of.write(f'{outdir}/{z}_vis.obj')
        # после записи индексы граней сменились — мир больше не редактировать
        self.frozen = True

    def write_rbxmx(self, path):
        self.tree.write(path, encoding='utf-8', xml_declaration=False)


# ======================= операции =======================
def inside(lo, hi, R):
    """R: {ось: (a, b)} — объект целиком в пределах по этим осям"""
    if not R:
        return True
    return all(lo[a] >= r[0] and hi[a] <= r[1] for a, r in R.items())

def widen(w, axis, c, d, R=None, zones=None, keep_slab=None, pts=None, rename_dup=None, tag=''):
    """Раздвижка по плоскости axis=c: сторона за плоскостью (d>0: >c, d<0: <c) уезжает на d,
    пересекающие плоскость растягиваются, всё, чей центр в полосе шириной |d| перед плоскостью,
    копируется со сдвигом d (заполнить прореху). R — ограничение по другим осям."""
    s = 1 if d > 0 else -1
    D = [0, 0, 0]; D[axis] = d
    def beyond(lo, hi):
        return lo[axis] >= c if s > 0 else hi[axis] <= c
    def straddle(lo, hi):
        return lo[axis] < c < hi[axis] and hi[axis] - lo[axis] >= 6
    _beyond = beyond
    def beyond(lo, hi):
        if _beyond(lo, hi):
            return True
        # мелочь поперёк плоскости не растягивается: едет целиком, если центр за плоскостью
        if lo[axis] < c < hi[axis] and hi[axis] - lo[axis] < 6:
            return ((lo[axis] + hi[axis]) / 2 - c) * s > 0
        return False
    def in_slab(lo, hi):
        m = (lo[axis] + hi[axis]) / 2
        return (c - d <= m < c and hi[axis] <= c + 1e-6) if s > 0 else (c < m <= c - d and lo[axis] >= c - 1e-6)
    n = dict(shift=0, stretch=0, dup=0, pshift=0, pstretch=0, pdup=0, warn=0)
    # меши
    todo = []
    for z, k in list(w.mesh(zones)):
        if not inside(k.lo, k.hi, R):
            continue
        if beyond(k.lo, k.hi):
            w.comp_shift(z, k, D); n['shift'] += 1
        elif straddle(k.lo, k.hi):
            w.comp_transform(z, k, lambda p: [p[i] + (D[i] if (i == axis and (p[axis] - c) * s > 0) else 0) for i in range(3)])
            n['stretch'] += 1
        elif in_slab(k.lo, k.hi) and (keep_slab is None or keep_slab(z, k)):
            todo.append((z, k))
    for z, k in todo:
        w.comp_dup(z, k, D); n['dup'] += 1
    # детали
    dups = []
    for p in list(w.alive_parts(zones=zones)):
        lo, hi = p.aabb()
        if not inside(lo, hi, R):
            continue
        if beyond(lo, hi):
            w.part_set(p, pos=[p.cf['p'][i] + D[i] for i in range(3)]); n['pshift'] += 1
        elif straddle(lo, hi):
            if p.folder == 'Lights':
                continue
            Rm = np.array(p.cf['R'])
            j = int(np.argmax(np.abs(Rm[axis])))
            if abs(Rm[axis][j]) < 0.999:
                n['warn'] += 1; print('  ! наклонная деталь поперёк плоскости', tag, p.zone, p.name, [round(v, 1) for v in lo], [round(v, 1) for v in hi])
                continue
            size = list(p.size); size[j] += abs(d)
            w.part_set(p, pos=[p.cf['p'][i] + D[i] / 2 for i in range(3)], size=size); n['pstretch'] += 1
        elif in_slab(lo, hi) and p.folder != 'Lights':
            dups.append(p)
    # детали внутри моделей Dynamic копируются моделью целиком (один раз)
    done = set()
    for p in dups:
        m = w.model_of(p) if p.folder == 'Dynamic' else None
        if m:
            mi = w.parent[p.item]
            if id(mi) in done:
                continue
            done.add(id(mi))
            w.model_dup(mi, D, rename=rename_dup(m) if rename_dup else None); n['pdup'] += 1
        else:
            w.part_dup(p, D); n['pdup'] += 1
    w.log.append(('widen', tag, n))
    # функция для точек и боксов
    def fpt(x, y, zz):
        q = [x, y, zz]
        if R and not all(r[0] <= q[a] <= r[1] for a, r in R.items()):
            return q
        if (q[axis] - c) * s > 0:
            q[axis] += d
        return q
    return fpt

def delete(w, pred_mesh=None, pred_part=None, zones=None, tag=''):
    n = [0, 0]
    if pred_mesh:
        for z, k in list(w.mesh(zones)):
            if pred_mesh(z, k):
                w.del_comp(z, k); n[0] += 1
    if pred_part:
        for p in list(w.alive_parts(zones=zones)):
            if pred_part(p):
                w.part_del(p); n[1] += 1
    w.log.append(('delete', tag, n))
    return n

def clamp_top(w, ymax_fn, pred_mesh, pred_part=None, zones=None, tag=''):
    """срезать верх: вершины выше ymax(...) опускаются, целиком выше — удаляются"""
    n = [0, 0, 0, 0]
    for z, k in list(w.mesh(zones)):
        if not pred_mesh(z, k):
            continue
        ym = ymax_fn((k.lo + k.hi) / 2)
        if k.lo[1] >= ym - 0.05:
            w.del_comp(z, k); n[0] += 1
        elif k.hi[1] > ym:
            w.comp_transform(z, k, lambda p: [p[0], min(p[1], ym), p[2]]); n[1] += 1
    if pred_part:
        for p in list(w.alive_parts(zones=zones)):
            if not pred_part(p):
                continue
            lo, hi = p.aabb(); ym = ymax_fn((np.array(lo) + np.array(hi)) / 2)
            if lo[1] >= ym - 0.05:
                w.part_del(p); n[2] += 1
            elif hi[1] > ym:
                Rm = np.array(p.cf['R']); j = int(np.argmax(np.abs(Rm[1])))
                if abs(Rm[1][j]) < 0.999:
                    continue
                size = list(p.size); cut = hi[1] - ym; size[j] -= cut
                w.part_set(p, pos=[p.cf['p'][0], p.cf['p'][1] - cut / 2, p.cf['p'][2]], size=size); n[3] += 1
    w.log.append(('clamp', tag, n))
    return n
