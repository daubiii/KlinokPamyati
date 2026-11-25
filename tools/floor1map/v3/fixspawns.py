import sys, re, numpy as np, hf, audit
exec(open('spawns.py').read().split("bad=[]")[0])
seen=np.load(OUT+'/a_seen.npy'); walk,top=audit.floor_level(seen)
RMAX=float(sys.argv[2]) if len(sys.argv)>2 else 7
def relocate(x,y,z):
    best=None
    for r in np.arange(0.5,RMAX+0.01,0.5):
        for a in np.linspace(0,2*np.pi,24,endpoint=False):
            nx,nz=round(x+r*np.cos(a)*1,1),round(z+r*np.sin(a),1)
            i,k=int(np.floor(nx-hf.X0)),int(np.floor(nz-hf.Z0))
            if not walk[i,k] or abs(top[i,k]*hf.DY+hf.Y0-(y-0.5))>0.6: continue
            c=clearance(nx,y,nz)
            if c>=3.2: return (nx,y,nz),c
    return None,None
pts_text=open(OUT+'/Floor1Points.lua',encoding='utf-8',newline='').read()
cfg_text=open(OUT+'/Floor1v2.lua',encoding='utf-8',newline='').read()
moved=[]
for key in sorted(used):
    zone,name=key
    if name.startswith('ARCH_') or key not in P: continue
    v=P[key]; c=clearance(*v)
    if c>=3: continue
    nv,nc=relocate(*v)
    if not nv: print('не нашёл места',key,v); continue
    old='["%s"] = Vector3.new(%.2f, %.2f, %.2f)'%(name,*v); new='["%s"] = Vector3.new(%.2f, %.2f, %.2f)'%(name,*nv)
    # имя может повторяться в разных зонах — меняем внутри блока зоны
    zs=pts_text.index('\t%s = {'%zone); ze=pts_text.index('\t},',zs)
    blk=pts_text[zs:ze]; assert old in blk,(old)
    pts_text=pts_text[:zs]+blk.replace(old,new)+pts_text[ze:]
    moved.append((key,v,nv,round(c,1),nc))
for v in inline:
    c=clearance(*v)
    if c>=3: continue
    nv,nc=relocate(*v)
    if not nv: print('не нашёл места', v); continue
    f=lambda q: ('%.2f'%q).rstrip('0').rstrip('.')
    old='Vector3.new(%s, %s, %s)'%tuple(f(q) for q in v); new='Vector3.new(%s, %s, %s)'%tuple(f(q) for q in nv)
    assert old in cfg_text,old; cfg_text=cfg_text.replace(old,new)
    moved.append((('inline',''),v,nv,round(c,1),nc))
# ручные места там, где поиск выходит за стены комнаты
for a,b in [('["SP_f2"] = Vector3.new(53.80, 0.00, -158.20)','["SP_f2"] = Vector3.new(56.00, 0.00, -134.00)'),
            ('["SP_wa4"] = Vector3.new(-54.70, 0.00, -8.70)','["SP_wa4"] = Vector3.new(-55.00, 0.00, -20.00)')]:
    pts_text=pts_text.replace(a,b)
open(OUT+'/Floor1Points.lua','w',encoding='utf-8',newline='').write(pts_text)
open(OUT+'/Floor1v2.lua','w',encoding='utf-8',newline='').write(cfg_text)
for m in moved: print('перенос',m[0],m[1],'→',m[2],'зазор',m[3],'→',round(m[4],1))
