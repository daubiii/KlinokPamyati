import sys, numpy as np, hf, f1lib, audit, widthmap, render_audit as RA, re, copy, time
OUT=sys.argv[1]; STEP=float(sys.argv[2]) if len(sys.argv)>2 else 2.0
RA.CFG=OUT+'/Floor1v2.lua'
tree,parts=f1lib.load_rbxmx(OUT+'/map/Floor1Map.rbxmx')
sp=[]
for p in parts:
    if p.folder=='Collision': sp.append(p)
    elif p.folder=='Dynamic':
        m=p.path[3] if len(p.path)>3 else ''
        if m.startswith('Gate_') or m in('InnerGate','VaultDoorL','VaultDoorR'): continue
        t=p.item.find("Properties/bool[@name='CanCollide']")
        if t is not None and t.text=='false': continue
        sp.append(p)
# WallCaps (FloorMap.capWalls): тонкие стены ≥3,5 продлены вверх
caps=[]
for p in sp:
    if p.folder!='Collision' or p.cls!='Part' or p.size is None: continue
    R=np.array(p.cf['R'])
    if abs(R[1][1])>0.99 and p.size[1]>=3.5 and min(p.size[0],p.size[2])<=3.2 and p.cf["p"][1]+p.size[1]/2>1.5:
        q=copy.copy(p); q.cf=dict(p.cf); q.cf['p']=[p.cf['p'][0],p.cf['p'][1]+p.size[1]/2+17.6,p.cf['p'][2]]; q.size=[p.size[0],35,p.size[2]]; caps.append(q)
t=time.time()
occ=hf.build(sp+caps, folders=('Collision','Dynamic'))
from scipy import ndimage
DIL=int(sys.argv[3]) if len(sys.argv)>3 else 1
occd=ndimage.binary_dilation(occ,structure=np.ones((2*DIL+1,2*DIL+1,1),bool)) if DIL else occ
st,_=hf.standable(occd)
pts=open(OUT+'/Floor1Points.lua',encoding='utf-8').read()
m=re.search(r'"PlayerStart"\] = Vector3.new\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)',pts)
s=tuple(float(v) for v in m.groups())
seen=hf.flood(st,(s[0],s[1]+0.6,s[2]),step=STEP)
walk,top=audit.floor_level(seen)
W=widthmap.width_map(walk,rmax=14)
np.save(OUT+'/a_occ.npy',occ); np.save(OUT+'/a_seen.npy',seen); np.save(OUT+'/a_W.npy',W)
print('build+flood',round(time.time()-t,1),'walk',walk.sum())
RA.OCC=occ
RA.render(OUT+f'/audit_step{STEP:g}.png',scale=2,W=W,walk=walk,top=top)
