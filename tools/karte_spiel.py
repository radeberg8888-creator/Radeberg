"""Gesamtkarte der Insel im Comic-Stil (Gelände, Küste, Straßen, Stadtflächen, Ortsnamen).
Eingaben: hoehen.bin + strassen_alt.txt + karte.json (aus der alten Welt exportiert)."""
import struct,sys,json,math
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from scipy import ndimage
S=sys.argv[1]
OUT=sys.argv[2] if len(sys.argv)>2 else S
b=open(S+'hoehen.bin','rb').read()
nx,nz=struct.unpack('<ii',b[:8]);x0,z0,st=struct.unpack('<fff',b[8:20])
H=np.frombuffer(b[20:20+nx*nz*4],dtype=np.float32).reshape(nz,nx)
X0,X1,Z0,Z1=-4400,4710,-11300,3510
W=2460;sc=W/(X1-X0);Hh=int((Z1-Z0)*sc)
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
# Bodenarten aus dem Geländeraster (gelaende.bin: Gras, Wald, Sand, Fels; Rest Trockengras/Wüste)
gb=open('assets/cache/gelaende.bin','rb').read()
grx,grz=struct.unpack('<ii',gb[4:12]);off=24+grx*grz*8
bo=np.frombuffer(gb[off:off+grx*grz*4],dtype=np.uint8).reshape(grz,grx,4)/255.0
bo=bo[iz][:,ix]
gras,wald,sand,fels=bo[...,0],bo[...,1],bo[...,2],bo[...,3]
trocken=np.clip(1-gras-wald-sand-fels,0,1)
C_GRAS=np.array([0.5,0.78,0.34]);C_WALD=np.array([0.24,0.52,0.24]);C_SAND=np.array([0.96,0.83,0.52]);C_FELS=np.array([0.62,0.55,0.47]);C_TROCKEN=np.array([0.86,0.74,0.42])
mix=gras[...,None]*C_GRAS+wald[...,None]*C_WALD+sand[...,None]*C_SAND+fels[...,None]*C_FELS+trocken[...,None]*C_TROCKEN
# Comic: in wenige Stufen quantisieren (welche Bodenart überwiegt)
art=np.argmax(np.stack([gras,wald,sand,fels,trocken],-1),-1)
pal=np.array([C_GRAS,C_WALD,C_SAND,C_FELS,C_TROCKEN])
flaeche=pal[art]*0.75+mix*0.25
schnee=h>620
flaeche[schnee]=[0.95,0.96,0.98]
img[landm]=flaeche[landm]
# Kontur zwischen Bodenarten
grenz=np.zeros_like(landm)
grenz[:-1]|=art[:-1]!=art[1:];grenz[:,:-1]|=art[:,:-1]!=art[:,1:]
grenz=grenz&landm
img[grenz]*=0.82
# Wald: kleine Baumtupfer
rng=np.random.default_rng(3)
img[landm&(dl<7)&(h<6)]=[0.96,0.87,0.6]
img[landm]*=(0.78+0.3*shade[landm])[:,None]
for lv in [60,150,300,500]:
    e=(h>=lv)&~ndimage.binary_erosion(h>=lv)
    img[e]*=0.6
kl=landm&~ndimage.binary_erosion(landm,iterations=2)
img[kl]=[0.08,0.06,0.07]
im=Image.fromarray((np.clip(img,0,1)*255).astype(np.uint8));d=ImageDraw.Draw(im)
ww=np.argwhere((art==1)&landm)
for (y,x) in ww[rng.choice(len(ww),size=min(len(ww),9000),replace=False)]:
    r=rng.integers(3,6);d.ellipse((x-r,y-r,x+r,y+r),fill=(60,125,55),outline=(25,55,25))
FB='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
f1=ImageFont.truetype(FB,40);f2=ImageFont.truetype(FB,24)
namen=[("Wüste",-350,-6350,f1)]
for n,x,z,f in namen:
    p=P(x,z);bb=d.textbbox(p,n,font=f,anchor='mm')
    d.rounded_rectangle((bb[0]-12,bb[1]-7,bb[2]+12,bb[3]+7),radius=12,fill=(255,250,235),outline=(25,20,22),width=3)
    d.text(p,n,font=f,fill=(25,20,22),anchor='mm')
im.save(OUT);print(im.size)
