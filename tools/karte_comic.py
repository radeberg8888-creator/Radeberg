"""Gesamtkarte der Insel im Comic-Stil (Gelände, Küste, Straßen, Stadtflächen, Ortsnamen).
Eingaben: hoehen.bin + strassen_alt.txt + karte.json (aus der alten Welt exportiert)."""
import struct,sys,json,math
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from scipy import ndimage
S=sys.argv[1]
b=open(S+'hoehen.bin','rb').read()
nx,nz=struct.unpack('<ii',b[:8]);x0,z0,st=struct.unpack('<fff',b[8:20])
H=np.frombuffer(b[20:20+nx*nz*4],dtype=np.float32).reshape(nz,nx)
X0,X1,Z0,Z1=-4300,4300,-11000,3600
W=2400;sc=W/(X1-X0);Hh=int((Z1-Z0)*sc)
def P(x,z):return ((x-X0)*sc,(z-Z0)*sc)
xs=np.linspace(X0,X1,W);zs=np.linspace(Z0,Z1,Hh)
ix=np.clip(((xs-x0)/st).astype(int),0,nx-1);iz=np.clip(((zs-z0)/st).astype(int),0,nz-1)
h=H[iz][:,ix]
gy,gx=np.gradient(ndimage.gaussian_filter(h,1.5))
shade=np.round(np.clip(0.6+(-gx*0.6-gy*0.8)/3.0,0,1)*3)/3
img=np.zeros((Hh,W,3));wasser=h<0.5;landm=~wasser
tief=np.clip(-h/12,0,1)
img[wasser]=np.array([0.33,0.67,0.86])*(1-tief[wasser,None]*0.3)
dw=ndimage.distance_transform_edt(wasser)
img[(dw>0)&(dw<5)]=[0.88,0.96,1.0]
img[(dw>10)&(dw<13)]=[0.46,0.77,0.92]
img[(dw>22)&(dw<24)]=[0.42,0.73,0.9]
dl=ndimage.distance_transform_edt(landm)
done=np.zeros_like(landm)
for m,c in [(h<25,[0.56,0.8,0.36]),(h<120,[0.44,0.72,0.3]),(h<300,[0.36,0.6,0.28]),(h<550,[0.58,0.52,0.42]),(h<5000,[0.94,0.95,0.97])]:
    mm=landm&m&~done;img[mm]=c;done|=mm
img[landm&(dl<7)&(h<6)]=[0.96,0.87,0.6]
# Stadtflächen aus den Hauspositionen
k=json.load(open(S+'karte.json'))
city=Image.new('L',(W,Hh),0);dc=ImageDraw.Draw(city)
for t,x,z,yaw,skk in k['houses']:
    p=P(x,z);r=9*sc*1.6+2
    dc.ellipse((p[0]-r,p[1]-r,p[0]+r,p[1]+r),fill=255)
cm=np.array(city)>0
cm=ndimage.binary_closing(cm,iterations=6)&landm
img[cm]=[0.95,0.88,0.76]
img[landm]*=(0.78+0.3*shade[landm])[:,None]
for lv in [60,150,300,500]:
    e=(h>=lv)&~ndimage.binary_erosion(h>=lv)&~cm
    img[e]*=0.6
kl=landm&~ndimage.binary_erosion(landm,iterations=2)
img[kl]=[0.08,0.06,0.07]
ce=cm&~ndimage.binary_erosion(cm,iterations=2)
img[ce]=[0.55,0.45,0.38]
im=Image.fromarray((np.clip(img,0,1)*255).astype(np.uint8));d=ImageDraw.Draw(im)
# Häuserblöcke als kleine Dächer
pal=[(205,95,72),(236,198,110),(140,180,205),(232,160,140),(180,205,150),(200,180,225)]
for t,x,z,yaw,skk in k['houses']:
    c=math.cos(yaw);s=math.sin(yaw);hx=6*skk[0];hz=6*skk[1]
    pts=[P(x+lx*c+lz*s,z-lx*s+lz*c) for lx,lz in [(-hx,-hz),(hx,-hz),(hx,hz),(-hx,hz)]]
    d.polygon(pts,fill=pal[(int(x)*7+int(z)*13)%len(pal)])
roads=[]
for line in open(S+'strassen_alt.txt'):
    a=line.split();pts=[tuple(map(int,q.split(','))) for q in a[2:]]
    if len(pts)>1:roads.append((a[0],float(a[1]),pts))
rang={'autobahn':9,'schiene':1,'land':3,'allee':5,'strasse':4,'rampe':4,'gasse':2,'piste':2,'runway':6,'taxi':6}
roads.sort(key=lambda r:rang.get(r[0],0))
def breite(typ,w):return {'autobahn':9,'allee':6,'land':5,'strasse':4,'rampe':4,'gasse':2,'piste':2,'runway':10,'taxi':4}.get(typ,3)
for typ,w,pts in roads:
    xy=[P(p[0],p[1]) for p in pts]
    if typ=='schiene':
        d.line(xy,fill=(70,55,50),width=5);d.line(xy,fill=(235,225,210),width=2);continue
    d.line(xy,fill=(25,20,22),width=breite(typ,w)+4,joint='curve')
for typ,w,pts in roads:
    if typ=='schiene':continue
    col={'autobahn':(252,196,60),'allee':(255,250,240),'land':(250,240,215),'runway':(130,130,135),'taxi':(150,150,155)}.get(typ,(250,250,248))
    for i in range(len(pts)-1):
        a,e=pts[i],pts[i+1]
        c=(120,120,125) if a[3]&1 else col
        d.line([P(a[0],a[1]),P(e[0],e[1])],fill=c,width=breite(typ,w))
FB='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
f1=ImageFont.truetype(FB,40);f2=ImageFont.truetype(FB,24)
namen=[("RADEBERG",-100,430,f1),("Downtown",250,-350,f2),("Grove",-250,700,f2),("Altstadt",-150,150,f2),("Südstadt",250,1500,f2),("Oststadt",2750,700,f2),("Hafen",400,2150,f2),
 ("Strand",-2080,-80,f2),("Kowloon",-2050,-1150,f2),("Sterndorf",1080,-520,f2),("Sandufer",880,-5900,f2),("Staubwinkel",1750,-5950,f2),("Kornfeld",1720,-7550,f2),
 ("Fischerdorf",-840,-6680,f2),("Nordbucht",-2150,-8700,f2),("Ost-Vorort",2500,-1050,f2),("Flugplatz",-2620,-5150,f2),("Rennstrecke",-660,-2380,f2),("Flughafen",-2100,2280,f2)]
for n,x,z,f in namen:
    p=P(x,z);bb=d.textbbox(p,n,font=f,anchor='mm')
    d.rounded_rectangle((bb[0]-12,bb[1]-7,bb[2]+12,bb[3]+7),radius=12,fill=(255,250,235),outline=(25,20,22),width=3)
    d.text(p,n,font=f,fill=(25,20,22),anchor='mm')
d.rounded_rectangle((30,30,600,130),radius=20,fill=(252,196,60),outline=(25,20,22),width=6)
d.text((315,80),"INSEL RADEBERG",font=ImageFont.truetype(FB,50),fill=(25,20,22),anchor='mm')
L=1000*sc;d.rectangle((40,Hh-70,40+L,Hh-52),fill=(255,255,255),outline=(25,20,22),width=3);d.text((40+L/2,Hh-95),"1 km",font=f2,fill=(25,20,22),anchor='mm')
im.save(S+'gesamtkarte_comic.png');print(im.size)
