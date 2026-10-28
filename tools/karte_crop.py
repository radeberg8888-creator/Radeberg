# Schneidet assets/ui/karte_basis.png auf den Bereich x0..x1 zu und schreibt karte_bereich.json neu (offline, kein get_image() am Handy)
import json,sys
from PIL import Image
X0=float(sys.argv[1]) if len(sys.argv)>1 else -1850; X1=float(sys.argv[2]) if len(sys.argv)>2 else 1850
b=json.load(open('assets/ui/karte_bereich.json')); im=Image.open('assets/ui/karte_basis.png')
W=im.width; px0=int((X0-b['x0'])/(b['x1']-b['x0'])*W); px1=int((X1-b['x0'])/(b['x1']-b['x0'])*W)
px0=max(px0,0);px1=min(px1,W)
x0=b['x0']+px0/W*(b['x1']-b['x0']); x1=b['x0']+px1/W*(b['x1']-b['x0'])
im.crop((px0,0,px1,im.height)).save('assets/ui/karte_basis.png')
json.dump({'x0':x0,'x1':x1,'z0':b['z0'],'z1':b['z1']},open('assets/ui/karte_bereich.json','w'))
print(px0,px1,x0,x1)
