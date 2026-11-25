"""Объёмная сетка коллизий этажа 1: клетка 1×1 стад, слой 0,5 по высоте."""
import numpy as np, math
X0,X1,Z0,Z1=-180,180,-590,165
Y0,Y1,DY=-36,114,0.5
NX,NZ,NY=X1-X0,Z1-Z0,int((Y1-Y0)/DY)

def part_samples(p, step=0.25):
    """точки следа детали на плоскости XZ (центр + оси R), с её интервалом по Y для каждой точки"""
    c=np.array(p.cf['p']); R=np.array(p.cf['R']); s=np.array(p.size)
    nx=max(2,int(math.ceil(s[0]/step))+1); ny=max(2,int(math.ceil(s[1]/step))+1); nz=max(2,int(math.ceil(s[2]/step))+1)
    tilt=abs(R[1][1]-1)>1e-3
    if not tilt:
        u=np.linspace(-s[0]/2,s[0]/2,nx); w=np.linspace(-s[2]/2,s[2]/2,nz)
        U,W=np.meshgrid(u,w,indexing='ij')
        pts=c[None,None,:]+U[...,None]*R[:,0][None,None,:]+W[...,None]*R[:,2][None,None,:]
        pts=pts.reshape(-1,3)
        ymin=np.full(len(pts),c[1]-s[1]/2); ymax=np.full(len(pts),c[1]+s[1]/2)
        if p.cls=='WedgePart':
            # клин: высота растёт по локальной Z (от −Z к +Z) — сверху наклон
            t=(W.reshape(-1)+s[2]/2)/s[2]
            ymax=c[1]-s[1]/2+s[1]*t
        return pts,ymin,ymax
    # наклонная деталь: облако точек объёма
    u=np.linspace(-s[0]/2,s[0]/2,nx); v=np.linspace(-s[1]/2,s[1]/2,max(2,ny)); w=np.linspace(-s[2]/2,s[2]/2,nz)
    U,V,W=np.meshgrid(u,v,w,indexing='ij')
    pts=c[None,:]+np.stack([U.reshape(-1),V.reshape(-1),W.reshape(-1)],1)@R.T
    return pts,pts[:,1]-0.25,pts[:,1]+0.25

def build(parts, folders=('Collision',), extra=None):
    occ=np.zeros((NX,NZ,NY),dtype=bool)
    owner={}
    for p in parts:
        if p.folder not in folders: continue
        pts,ymin,ymax=part_samples(p)
        ix=np.floor(pts[:,0]-X0).astype(int); iz=np.floor(pts[:,2]-Z0).astype(int)
        ok=(ix>=0)&(ix<NX)&(iz>=0)&(iz<NZ)
        y0=np.clip(np.floor((ymin-Y0)/DY).astype(int),0,NY-1); y1=np.clip(np.ceil((ymax-Y0)/DY).astype(int),0,NY)
        for a,b,c0,c1 in zip(ix[ok],iz[ok],y0[ok],y1[ok]):
            occ[a,b,c0:max(c1,c0+1)]=True
    return occ

def standable(occ, clear=5.0):
    """уровни, где можно стоять: верх занятого слоя, над ним clear свободно → bool[NX,NZ,NY] (индекс слоя пола)"""
    k=int(clear/DY)
    top=occ[:,:,:-1]&~occ[:,:,1:]   # слой занят, следующий свободен
    free=np.ones_like(occ)
    # свободно k слоёв выше
    acc=np.zeros_like(occ)
    run=np.zeros(occ.shape[:2],dtype=np.int32)
    freeAbove=np.zeros(occ.shape,dtype=np.int32)
    for y in range(NY-1,-1,-1):
        run=np.where(occ[:,:,y],0,run+1)
        freeAbove[:,:,y]=run
    st=np.zeros_like(occ)
    st[:,:,:-1]=top & (freeAbove[:,:,1:]>=k)
    return st, freeAbove

def flood(st, start, step=2.0, drop=40.0):
    """заливка проходимости от start (x,y,z): соседние клетки, подъём ≤ step"""
    from collections import deque
    sx,sy,sz=start
    ix,iz=int(sx-X0),int(sz-Z0)
    ys=np.nonzero(st[ix,iz])[0]
    if len(ys)==0: raise SystemExit('нет пола под стартом')
    y=ys[np.argmin(np.abs((ys*DY+Y0)-sy))]
    seen=np.zeros(st.shape,dtype=bool); q=deque([(ix,iz,y)]); seen[ix,iz,y]=True
    stepL=int(step/DY); dropL=int(drop/DY)
    levels={}
    while q:
        a,b,c=q.popleft()
        for da,db in((1,0),(-1,0),(0,1),(0,-1)):
            na,nb=a+da,b+db
            if not(0<=na<NX and 0<=nb<NZ): continue
            lo=max(0,c-dropL); hi=min(NY,c+stepL+1)
            col=st[na,nb,lo:hi]
            if not col.any(): continue
            for nc in np.nonzero(col)[0]+lo:
                if not seen[na,nb,nc]:
                    seen[na,nb,nc]=True; q.append((na,nb,nc))
    return seen
