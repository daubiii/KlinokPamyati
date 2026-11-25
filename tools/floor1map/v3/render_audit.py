import numpy as np, hf, json, re
OCC=None
from PIL import Image, ImageDraw, ImageFont
CFG=None
def zones_from_cfg(path=None):
    path=path or CFG
    s=open(path,encoding='utf-8').read(); out=[]
    for m in re.finditer(r'id = "(\w+)",\s*name = "([^"]+)",\s*kind = "(\w+)",\s*box = \{ ([-\d., ]+) \}',s):
        b=[float(x) for x in m.group(4).split(',')]
        out.append((m.group(1),m.group(2),m.group(3),b))
    return out
def render(out, scale=2, crop=None, W=None, VC=None, wt=None, inv=None, walk=None, top=None, labels=True, marks=None):
    occ2=(OCC if OCC is not None else np.load('occ.npy')).any(2)
    img=np.zeros((hf.NZ,hf.NX,3),dtype=np.float32); img[:]=(18,16,22)
    img[occ2.T]=(62,58,64)
    h=(top.T*hf.DY+hf.Y0)
    t=np.clip((h+2)/30,0,1)
    base=np.stack([70+60*t,120+30*t,140-40*t],-1)
    w=walk.T
    img[w]=base[w]
    if W is not None:
        n=w&(W.T<16); img[n]=img[n]*0.35+np.array([235,70,60])*0.65
        n=w&(W.T>=16)&(W.T<20); img[n]=img[n]*0.6+np.array([235,170,60])*0.4
    if VC is not None:
        c=w&(VC.T<14)
        yy,xx=np.nonzero(c); hatch=((yy+xx)%4)<2
        img[yy[hatch],xx[hatch]]=(190,90,230)
    if wt is not None:
        c=w&wt.T; img[c]=img[c]*0.5+np.array([250,240,120])*0.5
    im=Image.fromarray(img.astype(np.uint8)).resize((hf.NX*scale,hf.NZ*scale),Image.NEAREST)
    d=ImageDraw.Draw(im)
    f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',12)
    if labels:
        for zid,name,kind,b in zones_from_cfg():
            x0,z0,x1,z1=b[0],b[2],b[3],b[5]
            d.rectangle([(x0-hf.X0)*scale,(z0-hf.Z0)*scale,(x1-hf.X0)*scale,(z1-hf.Z0)*scale],outline=(255,255,255))
            d.text(((x0-hf.X0)*scale+3,(z0-hf.Z0)*scale+2),zid,fill=(255,255,255),font=f)
    for (x,y,z) in inv or []:
        px,pz=(x-hf.X0)*scale,(z-hf.Z0)*scale; d.rectangle([px-2,pz-2,px+2,pz+2],fill=(60,240,255))
    for (name,(x,y,z),c) in marks or []:
        px,pz=(x-hf.X0)*scale,(z-hf.Z0)*scale; d.ellipse([px-3,pz-3,px+3,pz+3],fill=c,outline=(0,0,0))
    if crop: im=im.crop([v*scale for v in crop])
    im.save(out)
