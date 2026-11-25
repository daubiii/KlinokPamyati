import numpy as np, hf, audit, render_audit as RA, math
from PIL import Image, ImageDraw, ImageFont
seen=np.load('orig_seen.npy'); walk,top=audit.floor_level(seen)
SC=2; CX0,CZ0,CX1,CZ1=-165,-480,175,150
RA.render('plan/base.png',scale=SC,crop=[CX0-hf.X0,CZ0-hf.Z0,CX1-hf.X0,CZ1-hf.Z0],walk=walk,top=top,labels=False)
base=Image.open('plan/base.png').convert('RGB')
# приглушить
base=Image.blend(base,Image.new('RGB',base.size,(18,16,22)),0.35)
W,H=base.size
PANEL=560
im=Image.new('RGB',(W+PANEL,H),(24,21,28)); im.paste(base,(0,0))
d=ImageDraw.Draw(im,'RGBA')
F=lambda s,b=True: ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf'%('-Bold' if b else ''),s)
def P(x,z): return ((x-CX0)*SC,(z-CZ0)*SC)
def rect(x0,z0,x1,z1,fill,outline=None,w=2):
    a=P(x0,z0); b=P(x1,z1); d.rectangle([a,b],fill=fill,outline=outline,width=w)
def tag(n,x,z,col):
    px,pz=P(x,z); r=13
    d.ellipse([px-r,pz-r,px+r,pz+r],fill=col,outline=(0,0,0),width=2)
    t=str(n); f=F(15); w=d.textlength(t,font=f); d.text((px-w/2,pz-9),t,fill=(0,0,0),font=f)
GREEN=(90,220,120,90); BLUE=(80,170,255,90); ORANGE=(255,160,60,110); RED=(255,80,80,120); VIOLET=(200,120,255,90)
# 1 улица: расширение (южная часть уезжает на +8)
rect(-150,12.5,15,31.5,GREEN,(90,220,120),2)
d.line([P(-150,26),P(15,26)],fill=(90,220,120),width=1)
for x in(-120,-60,0): 
    a=P(x,40); b=P(x,52); d.line([a,b],fill=(90,220,120),width=3); d.polygon([P(x-3,48),P(x+3,48),P(x,54)],fill=(90,220,120))
tag(1,-40,22,(90,220,120))
# 2 склад, 6 кузня, 4 привал, 5 арсенал, 10 часовня, 11 последние ворота, 12 зал — без крыш
for n,(x0,z0,x1,z1) in [(2,(-69,-40,-40,0)),(4,(-135,-157,-105,-125)),(5,(-29,-168,29,-113)),(6,(30,-152,66,-124)),(10,(98,-306,135,-272)),(11,(110,-372,148,-328)),(12,(46,-317,100,-263))]:
    rect(x0,z0,x1,z1,BLUE,(80,170,255),2); tag(n,(x0+x1)/2,(z0+z1)/2,(80,170,255))
# колонны арсенала → обломки
for x,z in[(-12,-128),(12,-128),(-12,-152),(12,-152),(-14,-140),(14,-140)]:
    px,pz=P(x,z); d.rectangle([px-4,pz-4,px+4,pz+4],outline=(255,240,120),width=2)
# 3 мост 12 → 20
rect(-104,-154,-31,-134,GREEN,(90,220,120),2); tag(3,-67,-144,(90,220,120))
# 7 галерея 7 → 19
rect(-9.5,-252,9.5,-181,GREEN,(90,220,120),2); tag(7,0,-216,(90,220,120))
# 8 двор башни (новый)
cx,cz,R=0,-292,30
a=P(cx-R,cz-R); b=P(cx+R,cz+R)
d.rectangle([P(-42,-334),P(42,-250)],fill=(18,16,22,235))
d.ellipse([a,b],fill=(150,110,70,200),outline=(230,200,150),width=3)
t=P(0,-327); r=11*SC; d.ellipse([t[0]-r,t[1]-r,t[0]+r,t[1]+r],fill=(90,86,100),outline=(230,200,150),width=3)
for i,bear in enumerate((240,0,120)):
    ang=math.radians(bear); rr=R-2.5 if bear else 13.5
    if bear==0: x,z=0,-327+13.5
    else: x,z=cx+math.sin(ang)*rr,cz-math.cos(ang)*rr
    px,pz=P(x,z); d.rectangle([px-8,pz-8,px+8,pz+8],fill=(255,150,40),outline=(0,0,0),width=2)
    d.text((px-5,pz-9),'ABC'[i],fill=(0,0,0),font=F(14))
rect(-9.5,-262,9.5,-252,(150,110,70,200),(230,200,150),2)   # лестница с галереи
rect(30,-297,47,-287,(150,110,70,200),(230,200,150),2)       # проход в зал по земле
d.rectangle([P(16,-293),P(46,-287)],outline=(255,80,80),width=3); d.line([P(16,-293),P(46,-287)],fill=(255,80,80),width=3); d.line([P(16,-287),P(46,-293)],fill=(255,80,80),width=3)
tag(8,-20,-300,(255,160,60)); tag(9,40,-282,(255,160,60))
# легенда
x0=W+24; y=20
d.text((x0,y),'Этаж 1 — план правок',fill=(240,230,215),font=F(26)); y+=44
items=[
 ((90,220,120),'1','Улица 12–18 → 20–26. Двор и вход уезжают на 8 к югу,\nнавесы над улицей убраны'),
 ((80,170,255),'2','Склад: стропила убраны, стены — руины ~8'),
 ((90,220,120),'3','Мост 12 → 20 (северный край уезжает на 8)'),
 ((80,170,255),'4','Привал: плоская крыша убрана'),
 ((80,170,255),'5','Арсенал: балки убраны, колонны → обломки ≤3\n(жёлтые квадраты)'),
 ((80,170,255),'6','Кузня: руины без крыши, стены ~8'),
 ((90,220,120),'7','Галерея 7 → 19, низкий парапет'),
 ((255,160,60),'8','Двор башни (новый): круг R30, башня на севере,\nнасесты A, B, C на высоте 8 на подпорах'),
 ((255,160,60),'9','Выход в зал по земле, новый западный проём.\nМост на высоте 24 (красный) убран'),
 ((80,170,255),'10','Часовня: крыша убрана'),
 ((80,170,255),'11','Последние ворота: крыша убрана'),
 ((80,170,255),'12','Зал лебёдки: балки убраны'),
]
for col,n,txt in items:
    px,pz=x0+13,y+12; d.ellipse([px-13,pz-13,px+13,pz+13],fill=col,outline=(0,0,0),width=2)
    f=F(13); w=d.textlength(n,font=f); d.text((px-w/2,pz-8),n,fill=(0,0,0),font=f)
    d.multiline_text((x0+36,y),txt,fill=(225,220,210),font=F(16,False),spacing=4)
    y+=26+22*txt.count('\n')+14
y+=10
d.multiline_text((x0,y),'Везде:\n• коллизия = видимая геометрия, невидимые стены\n  только по краю мира;\n• дыры наружу закрываются видимыми стенами;\n• арки и перемычки дверей не дёргают камеру;\n• точки врагов ≥ 3 стад от стен (проверка тестом).',fill=(225,220,210),font=F(16,False),spacing=5)
im.save('plan/plan_map.png')
print(im.size)
