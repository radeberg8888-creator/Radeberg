# Planungsbild: Gelände + Straßen-Layout, markiert Straßen über Wasser / steil
import numpy as np, struct, json, sys
from PIL import Image, ImageDraw
d=open('assets/cache/gelaende.bin','rb').read()
nx,nz,x0,z0,st=struct.unpack('<iifff',d[4:24]);o=24
H=np.frombuffer(d,np.float32,nx*nz,o).reshape(nz,nx);o+=nx*nz*4
KD=np.frombuffer(d,np.float32,nx*nz,o).reshape(nz,nx);o+=nx*nz*4
B=np.frombuffer(d,np.uint8,nx*nz*4,o).reshape(nz,nx,4)
S=float(sys.argv[2]) if len(sys.argv)>2 else 1.0   # Pixel pro Zelle
t=np.clip(H/700.0,0,1)[:,:,None]
img=np.array([110,150,80])*(1-t)+np.array([235,235,235])*t
wu=(B[:,:,0]>120)[:,:,None] if False else None
sh=np.clip(1+(np.gradient(H,axis=1)-np.gradient(H,axis=0))*0.08,0.5,1.4)
img=img*sh[:,:,None]
img[H<0.0]=[40,80,140]
im=Image.fromarray(np.clip(img,0,255).astype(np.uint8)).resize((int(nx*S),int(nz*S)))
dr=ImageDraw.Draw(im)
for gx in range(-4000,4701,500):
    dr.line([((gx-x0)/st*S,0),((gx-x0)/st*S,nz*S)],fill=(0,0,0),width=1);dr.text(((gx-x0)/st*S+2,2),str(gx),fill=(0,0,0))
for gz in range(-11000,3501,500):
    dr.line([(0,(gz-z0)/st*S),(nx*S,(gz-z0)/st*S)],fill=(0,0,0),width=1);dr.text((2,(gz-z0)/st*S+2),str(gz),fill=(0,0,0))
P=lambda x,z:((x-x0)/st*S,(z-z0)/st*S)
def h(x,z):
    i=int(round((z-z0)/st));j=int(round((x-x0)/st))
    if 0<=i<nz and 0<=j<nx:return H[i,j]
    return -99
col={"autobahn":(255,140,0),"rampe":(255,200,60),"allee":(255,255,255),"strasse":(230,230,230),"gasse":(200,200,200),"land":(250,230,150),"piste":(190,150,100),"runway":(60,60,60),"taxi":(90,90,90),"schiene":(120,60,60)}
wid={"autobahn":4,"allee":3,"runway":4}
L=json.load(open(sys.argv[1]));bad=[]
for r in L:
    p=r['p']+([r['p'][0]] if r['closed'] else [])
    dr.line([P(*q) for q in p],fill=col.get(r['typ'],(255,0,255)),width=wid.get(r['typ'],2))
    for a,b in zip(p,p[1:]):
        n=max(2,int(np.hypot(b[0]-a[0],b[1]-a[1])/20))
        for k in range(n):
            x=a[0]+(b[0]-a[0])*k/n;z=a[1]+(b[1]-a[1])*k/n
            if h(x,z)<0.0 and r['typ'] not in('schiene',):
                bad.append((r['typ'],r['name'],int(x),int(z)));dr.ellipse([P(x,z)[0]-3,P(x,z)[1]-3,P(x,z)[0]+3,P(x,z)[1]+3],outline=(255,0,0))
im.save(sys.argv[3] if len(sys.argv)>3 else 'layout.png')
from collections import Counter
c=Counter((t,n) for t,n,_,_ in bad)
for k,v in c.most_common(40):
    pts=[(x,z) for t,n,x,z in bad if (t,n)==k]
    print(k,v,pts[0],pts[-1])
