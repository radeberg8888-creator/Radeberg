"""Höhenraster eines Modells (für HeightMapShape3D-Kollision von Großmodellen wie Kowloon-Kachel, Canyon).
Dreiecke werden in Zellen gerastert (max. Höhe). Ausgabe JSON: {zelle, nx, nz, x0, z0, y0, h:[...]} in Modellkoordinaten*skala,
x/z relativ zur Bounding-Box-Mitte, y relativ zur Unterkante.
Aufruf: hoehenraster.py <gltf> <skala> <zelle> <out.json>"""
import json,os,sys,numpy as np
sys.path.insert(0,os.path.dirname(__file__))
from autorig import read_acc,node_mat
src,sc,cell,out=sys.argv[1],float(sys.argv[2]),float(sys.argv[3]),sys.argv[4]
d=os.path.dirname(src);j=json.load(open(src));binb=open(os.path.join(d,j['buffers'][0]['uri']),'rb').read()
W={}
def walk(i,M):
    W[i]=M@node_mat(j['nodes'][i])
    for c in j['nodes'][i].get('children',[]):walk(c,W[i])
for r in j['scenes'][j.get('scene',0)]['nodes']:walk(r,np.eye(4))
tris=[]
for ni,n in enumerate(j['nodes']):
    if 'mesh' not in n or ni not in W:continue
    for p in j['meshes'][n['mesh']]['primitives']:
        P=read_acc(j,binb,p['attributes']['POSITION']).astype(float);P=((W[ni][:3,:3]@P.T).T+W[ni][:3,3])*sc
        I=read_acc(j,binb,p['indices']).reshape(-1,3) if 'indices' in p else np.arange(len(P)).reshape(-1,3)
        tris.append(P[I])
T=np.concatenate(tris)
lo=T.reshape(-1,3).min(0);hi=T.reshape(-1,3).max(0);c=(lo+hi)/2
nx=int(np.ceil((hi[0]-lo[0])/cell))+1;nz=int(np.ceil((hi[2]-lo[2])/cell))+1
H=np.full((nz,nx),0.0)
# Dreiecke dicht abtasten (baryzentrisch) und Maximum je Zelle
for k in range(6):
    for l in range(6-k):
        a=k/5.0;b=l/5.0
        if a+b>1:continue
        Q=T[:,0]*(1-a-b)+T[:,1]*a+T[:,2]*b
        ix=np.clip(((Q[:,0]-lo[0])/cell).round().astype(int),0,nx-1);iz=np.clip(((Q[:,2]-lo[2])/cell).round().astype(int),0,nz-1)
        np.maximum.at(H,(iz,ix),Q[:,1]-lo[1])
json.dump({'zelle':cell,'nx':nx,'nz':nz,'x0':float(lo[0]-c[0]),'z0':float(lo[2]-c[2]),'groesse':[float(hi[0]-lo[0]),float(hi[1]-lo[1]),float(hi[2]-lo[2])],'h':[round(float(v),2) for v in H.reshape(-1)]},open(out,'w'))
print('ok',out,nx,nz,'max',H.max())
