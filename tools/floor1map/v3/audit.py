import numpy as np, hf
from scipy import ndimage
def floor_level(seen):
    """индекс слоя пола (верхний достижимый) и маска"""
    walk=seen.any(2)
    top=np.where(walk, seen.shape[2]-1-np.argmax(seen[:,:,::-1],axis=2), -1)
    return walk, top
def visual_ceiling(walk, top, mdown, lo=2.5, hi=30):
    C=np.full(walk.shape,np.inf,dtype=np.float32)
    L0=int(lo/hf.DY); L1=int(hi/hf.DY)
    A,B=np.nonzero(walk)
    for a,b in zip(A,B):
        t=top[a,b]
        col=mdown[a,b,t+L0:t+L1]
        nz=np.nonzero(col)[0]
        if len(nz): C[a,b]=(nz[0]+L0)*hf.DY
    return C
def invisible_walls(walk, top, occ, mocc, body=(1.0,4.5), near=1):
    """клетки-стены у края прохода: коллизия на высоте тела есть, видимого меша рядом нет"""
    res=[]
    b0=int(body[0]/hf.DY); b1=int(body[1]/hf.DY)
    mbody=None
    A,B=np.nonzero(walk)
    seen=set()
    for a,b in zip(A,B):
        t=top[a,b]
        for da,db in((1,0),(-1,0),(0,1),(0,-1)):
            na,nb=a+da,b+db
            if (na,nb) in seen or walk[na,nb] and abs(top[na,nb]-t)<=4: continue
            if not occ[na,nb,t+b0:t+b1].any(): continue
            a0,a1=max(0,na-near),na+near+1; c0,c1=max(0,nb-near),nb+near+1
            if mocc[a0:a1,c0:c1,t+b0-1:t+b1+2].any(): continue
            seen.add((na,nb)); res.append((na+hf.X0+0.5, (t+b0)*hf.DY+hf.Y0, nb+hf.Z0+0.5))
    return res
def walkthrough_meshes(walk, top, mocc, body=(1.2,4.0)):
    """видимые меши на высоте тела внутри прохода (сквозь них можно пройти)"""
    b0=int(body[0]/hf.DY); b1=int(body[1]/hf.DY)
    out=np.zeros(walk.shape,dtype=bool)
    A,B=np.nonzero(walk)
    for a,b in zip(A,B):
        t=top[a,b]
        if mocc[a,b,t+b0:t+b1].any(): out[a,b]=True
    return out
