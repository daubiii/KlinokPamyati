import sys, numpy as np, hf, audit, f1lib, base64, struct
import xml.etree.ElementTree as ET
OUT=sys.argv[1]
seen=np.load(OUT+'/a_seen.npy'); walk,top=audit.floor_level(seen)
tree,parts=f1lib.load_rbxmx(OUT+'/map/Floor1Map.rbxmx')
def floor_under(x,z):
    i=int(np.floor(x-hf.X0)); k=int(np.floor(z-hf.Z0))
    if 0<=i<hf.NX and 0<=k<hf.NZ and walk[i,k]: return top[i,k]*hf.DY+hf.Y0+0.5
def add_attr(item,k,v):
    props=item.find('Properties')
    old=props.find("BinaryString[@name='AttributesSerialize']")
    kb=k.encode(); body=struct.pack('<I',len(kb))+kb+bytes([3,1 if v else 0])
    if old is not None and old.text:
        raw=base64.b64decode(old.text); n=struct.unpack('<I',raw[:4])[0]
        raw=struct.pack('<I',n+1)+raw[4:]+body; old.text=base64.b64encode(raw).decode()
    else:
        el=ET.SubElement(props,'BinaryString',{'name':'AttributesSerialize'}); el.text=base64.b64encode(struct.pack('<I',1)+body).decode()
n=0; zones={}
for p in parts:
    if p.folder!='Collision' or p.size is None: continue
    lo,hi=p.aabb()
    if hi[1]-lo[1]>4.5: continue
    xs=np.linspace(lo[0]+.3,hi[0]-.3,5); zs=np.linspace(lo[2]+.3,hi[2]-.3,5)
    fl=[floor_under(x,z) for x in xs for z in zs]; fl=[f for f in fl if f is not None]
    if len(fl)>=3 and 3.5<=lo[1]-max(fl)<20:
        add_attr(p.item,'CameraIgnore',True); n+=1; zones[p.zone]=zones.get(p.zone,0)+1
tree.write(OUT+'/map/Floor1Map.rbxmx',encoding='utf-8',xml_declaration=False)
print('CameraIgnore:',n,zones)
