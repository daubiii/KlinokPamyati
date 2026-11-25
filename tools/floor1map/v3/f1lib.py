"""Этаж 1: загрузка мешей (OBJ) и коллизий/динамики (rbxmx) пакета KlinokFloor1v2."""
import re, math, xml.etree.ElementTree as ET
from pathlib import Path

import os
# папка map из пакета агента (KlinokFloor1v2/map): 17 OBJ, Floor1Map.rbxmx, палитра
MAP = Path(os.environ.get('F1_SRC_MAP', '/home/claude/src/floor1v2/KlinokFloor1v2/map'))
ZONES = ['intro','yard','street','warehouse','plaza','barbican','rest1','bridge','armory','forge','gallery','tower','hall','chapel','lastgates','boss','env']

class Obj:
    def __init__(self, name):
        self.name=name; self.faces=[]  # (mat, [(vi,ti)...])
class ObjFile:
    def __init__(self, zone):
        self.zone=zone; self.v=[]; self.vt=[]; self.objects=[]; self.header=[]
        cur=None; mat=None
        for line in open(MAP/f'{zone}_vis.obj',encoding='utf-8'):
            if line.startswith('v '):
                a=line.split(); self.v.append([float(a[1]),float(a[2]),float(a[3])])
            elif line.startswith('vt '):
                a=line.split(); self.vt.append([float(a[1]),float(a[2])])
            elif line.startswith('o '):
                cur=Obj(line[2:].strip()); self.objects.append(cur)
            elif line.startswith('usemtl'):
                mat=line.split()[1]
            elif line.startswith('f '):
                idx=[]
                for tok in line.split()[1:]:
                    p=tok.split('/'); idx.append((int(p[0])-1, int(p[1])-1 if len(p)>1 and p[1] else -1))
                cur.faces.append((mat,idx))
            elif line.startswith('#') or line.startswith('mtllib'):
                self.header.append(line.rstrip('\n'))
    def write(self, path):
        # пересобрать с компактными индексами
        out=[*self.header]
        vmap={}; tmap={}; vs=[]; ts=[]; body=[]
        for o in self.objects:
            if not o.faces: continue
            body.append(f'o {o.name}')
            lastmat=None
            for mat,idx in o.faces:
                if mat!=lastmat:
                    body.append(f'usemtl {mat}'); lastmat=mat
                toks=[]
                for vi,ti in idx:
                    if vi not in vmap: vmap[vi]=len(vs)+1; vs.append(self.v[vi])
                    if ti>=0:
                        if ti not in tmap: tmap[ti]=len(ts)+1; ts.append(self.vt[ti])
                        toks.append(f'{vmap[vi]}/{tmap[ti]}')
                    else: toks.append(f'{vmap[vi]}')
                body.append('f '+' '.join(toks))
        for v in vs: out.append('v %.3f %.3f %.3f'%tuple(v))
        for t in ts: out.append('vt %.6f %.6f'%tuple(t))
        out+=body
        Path(path).write_text('\n'.join(out)+'\n',encoding='utf-8')

def load_objs():
    return {z:ObjFile(z) for z in ZONES}

# ---------- rbxmx ----------
def cf_of(item):
    cf=item.find("Properties/CoordinateFrame[@name='CFrame']")
    if cf is None: return None
    g=lambda k: float(cf.find(k).text)
    return {'p':[g('X'),g('Y'),g('Z')],'R':[[g('R00'),g('R01'),g('R02')],[g('R10'),g('R11'),g('R12')],[g('R20'),g('R21'),g('R22')]],'el':cf}
def size_of(item):
    s=item.find("Properties/Vector3[@name='size']")
    if s is None: return None
    return [float(s.find('X').text),float(s.find('Y').text),float(s.find('Z').text)],s
def name_of(item):
    n=item.find("Properties/string[@name='Name']"); return n.text if n is not None else ''

class Part:
    def __init__(self, item, path):
        self.item=item; self.path=path; self.cls=item.get('class'); self.name=name_of(item)
        self.cf=cf_of(item); sz=size_of(item); self.size=sz[0] if sz else None
    @property
    def zone(self): return self.path[1] if len(self.path)>1 else ''
    @property
    def folder(self): return self.path[2] if len(self.path)>2 else ''
    def aabb(self):
        p=self.cf['p']; R=self.cf['R']; s=self.size
        ext=[sum(abs(R[i][j])*s[j]/2 for j in range(3)) for i in range(3)]
        return [p[i]-ext[i] for i in range(3)],[p[i]+ext[i] for i in range(3)]

def load_rbxmx(path=None):
    tree=ET.parse(path or (MAP/'Floor1Map.rbxmx')); root=tree.getroot()
    parts=[]
    def walk(item,path):
        nm=name_of(item)
        for ch in item.findall('Item'):
            cls=ch.get('class')
            if cls in('Part','WedgePart','MeshPart'):
                parts.append(Part(ch,path+[nm,name_of(ch)] if False else path+[nm]))
            walk(ch,path+[nm])
    for top in root.findall('Item'): walk(top,[])
    return tree,parts
