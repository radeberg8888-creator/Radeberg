"""Kopiert die fürs Spiel nötigen Dateien ins GitHub-Repo (ohne Rohmodelle, .godot, Testbilder)."""
import os, shutil, glob
SRC='/home/claude/radeberg-godot'; DST='/home/claude/radeberg'
KEEP={'.git','.github','export_presets.cfg','README.md','.gitignore'}
for n in os.listdir(DST):
    if n in KEEP: continue
    p=os.path.join(DST,n)
    shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
for n in ['project.godot','CREDITS.md','icon.svg']:
    if os.path.exists(os.path.join(SRC,n)): shutil.copy2(os.path.join(SRC,n),DST)
for d in ['scripts','scenes','shaders','tools']:
    shutil.copytree(os.path.join(SRC,d),os.path.join(DST,d),ignore=shutil.ignore_patterns('__pycache__'))
A=['buildings/einzeln','buildings/ghetto','buildings/house','buildings/stash','props/tree','props/polyhaven','textures','ui','data','cache','animations',
   'characters/joe','characters/biker','characters/daya','characters/female',
   'vehicles/small_car','vehicles/police_ford','vehicles/mercedes','vehicles/bmw_e30','vehicles/audi_rs7','vehicles/trabant','vehicles/porsche911',
   'vehicles/container_truck','vehicles/bus','vehicles/jdm','vehicles/audi_r8','vehicles/bmw_m8']
for d in A:
    shutil.copytree(os.path.join(SRC,'assets',d),os.path.join(DST,'assets',d))
for f in glob.glob(SRC+'/assets/characters/michelle*'):shutil.copy2(f,DST+'/assets/characters/')
tot=0
for r,_,fs in os.walk(DST):
    if '/.git' in r: continue
    for f in fs: tot+=os.path.getsize(os.path.join(r,f))
print('Größe MB',tot//2**20)
