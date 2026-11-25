import numpy as np, hf
from scipy import ndimage
def disk(r):
    y,x=np.ogrid[-r:r+1,-r:r+1]; return x*x+y*y<=r*r
def width_map(walk, rmax=16):
    D=ndimage.distance_transform_edt(walk)
    W=np.zeros(walk.shape,dtype=np.float32)
    for r in range(1,rmax+1):
        core=D>=r
        if not core.any(): break
        M=ndimage.binary_dilation(core,structure=disk(r))
        W[M&walk]=2*r
    return W
def ceiling_map(seen, occ):
    """высота до потолка над полом достижимой клетки (стады), inf если открыто"""
    NX,NZ,NY=seen.shape
    C=np.full((NX,NZ),np.inf,dtype=np.float32)
    idx=np.argwhere(seen)
    for a,b,c in idx:
        col=occ[a,b,c+1:]
        nz=np.nonzero(col)[0]
        if len(nz):
            h=(nz[0])*hf.DY
            if h<C[a,b]: C[a,b]=h
    return C
