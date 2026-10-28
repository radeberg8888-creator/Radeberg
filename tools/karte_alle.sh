#!/bin/bash
# Kartendaten erzeugen und alle Kartenbilder rendern (Spielkarte + Vorschau)
cd "$(dirname "$0")/.."
SP=${1:-/tmp}
J=/root/.local/share/godot/app_userdata/Radeberg/kartendaten.json
python3 - <<'PY'
import json
f='/root/.local/share/godot/app_userdata/Radeberg/kartendaten.json';d=json.load(open(f))
w=[l for l in d['laeden'] if l[0]=='werkstatt'][0]
d['story']=[[-250,620,'R',[242,190,40]],[w[1],w[2]-40,'M',[242,90,150]],[500,2050,'V',[76,190,242]],[-150,120,'J',[100,242,115]],[-150,-1500,'I',[215,215,242]],
 [250,-350,'K',[115,140,255]],[1750,-5900,'B',[215,115,50]],[2700,600,'P',[190,100,242]]]
json.dump(d,open(f,'w'))
PY
python3 tools/karte_2d.py $J assets/ui/karte_basis.png 0.27 spiel >/dev/null
python3 tools/karte_2d.py $J $SP/karte_gross.png 0.4
python3 -c "
from PIL import Image;im=Image.open('$SP/karte_gross.png');P=lambda x,z:(int((x+4400)*0.4),int((z+11300)*0.4))
im.resize((int(im.width*2000/im.height),2000),Image.LANCZOS).save('$SP/karte_uebersicht.jpg',quality=88)
for n,a,b in [('stadt',(-2900,-1700),(3600,2700)),('norden',(-3400,-10200),(3600,-4300)),('mitte',(-3000,-5000),(3800,-1300))]:
    im.crop(P(*a)+P(*b)).save('$SP/karte_'+n+'.jpg',quality=90)"
