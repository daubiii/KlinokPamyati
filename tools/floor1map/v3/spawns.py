import sys, re, numpy as np, hf
OUT=sys.argv[1]
occ=np.load(OUT+'/a_occ.npy')
pts=open(OUT+'/Floor1Points.lua',encoding='utf-8').read()
cfg=open(OUT+'/Floor1v2.lua',encoding='utf-8').read()
P={}
zone=None
for line in pts.splitlines():
    m=re.match(r'\t(\w+) = \{',line)
    if m: zone=m.group(1)
    m=re.search(r'\["(\w+)"\] = Vector3.new\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)',line)
    if m: P[(zone,m.group(1))]=tuple(map(float,m.groups()[1:]))
used=set(re.findall(r'\{ "\w+", P\.(\w+)\.(\w+)',cfg))
inline=[tuple(map(float,m)) for m in re.findall(r'\{ "\w+", Vector3\.new\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)',cfg)]
def clearance(x,y,z,R=6):
    ix,iz=int(np.floor(x-hf.X0)),int(np.floor(z-hf.Z0))
    y0=int((y+0.6-hf.Y0)/hf.DY); y1=int((y+4.5-hf.Y0)/hf.DY)
    best=99
    for dx in range(-R,R+1):
        for dz in range(-R,R+1):
            if occ[ix+dx,iz+dz,y0:y1].any():
                best=min(best,max(0,np.hypot(dx,dz)-0.7))
    return best
bad=[]
for key in sorted(used):
    if key not in P: print('нет точки',key); continue
    c=clearance(*P[key])
    if c<3: bad.append((key,P[key],round(c,1)))
for v in inline:
    c=clearance(*v)
    if c<3: bad.append((('inline',''),v,round(c,1)))
print('точек врагов:',len(used)+len(inline),'ближе 3 к стене:',len(bad))
for b in bad: print(' ',b)
