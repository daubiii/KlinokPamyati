"""Компоненты OBJ (≈ исходные боксы генератора): union-find по вершинам граней."""
import numpy as np, f1lib, pickle, os
class Comp:
    __slots__=('zone','obj','faces','verts','lo','hi')
def components(of):
    out=[]
    V=np.array(of.v)
    for oi,o in enumerate(of.objects):
        parent={}
        def find(a):
            while parent[a]!=a:
                parent[a]=parent[parent[a]]; a=parent[a]
            return a
        for _,idx in o.faces:
            vs=[vi for vi,_ in idx]
            for v in vs: parent.setdefault(v,v)
            r=find(vs[0])
            for v in vs[1:]:
                rv=find(v)
                if rv!=r: parent[rv]=r
        groups={}
        for fi,(_,idx) in enumerate(o.faces):
            r=find(idx[0][0]); groups.setdefault(r,[]).append(fi)
        for r,fl in groups.items():
            c=Comp(); c.zone=of.zone; c.obj=oi; c.faces=fl
            vs=sorted({vi for fi in fl for vi,_ in o.faces[fi][1]}); c.verts=np.array(vs)
            P=V[c.verts]; c.lo=P.min(0); c.hi=P.max(0)
            out.append(c)
    return out
def load_all():
    objs=f1lib.load_objs()
    comps={z:components(objs[z]) for z in objs}
    return objs,comps
