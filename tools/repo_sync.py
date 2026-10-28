"""Kopiert die fürs Spiel nötigen Dateien ins GitHub-Repo (ohne Rohmodelle, .godot, Testbilder)."""
import os, shutil, glob
SRC='/home/claude/radeberg-godot'; DST='/home/claude/radeberg'
KEEP={'.git','.github','export_presets.cfg','README.md','.gitignore'}
for n in os.listdir(DST):
    if n in KEEP: continue
    p=os.path.join(DST,n)
    shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
for n in ['project.godot','CREDITS.md','icon.png','icon.png.import']:
    if os.path.exists(os.path.join(SRC,n)): shutil.copy2(os.path.join(SRC,n),DST)
for d in ['scripts','scenes','shaders','tools']:
    shutil.copytree(os.path.join(SRC,d),os.path.join(DST,d),ignore=shutil.ignore_patterns('__pycache__'))
A=['buildings/einzeln','buildings/ghetto','buildings/house','buildings/stash','props/tree','props/polyhaven','textures','ui','data','cache','animations',
   'characters/joe','characters/biker','characters/daya','characters/female','characters/police','characters/woman','characters/aiman','characters/hqman',
   'weapons','props/neu/bank','props/neu/muelleimer','props/neu/container','props/neu/stapler','props/neu/hubwagen','props/neu/lagerhalle','props/neu/park','props/neu/bruecke','props/neu/harley','staedte/kowloon','staedte/canyon','staedte/citybuilding','staedte/realbuilding','staedte/marino']
for d in A:
    shutil.copytree(os.path.join(SRC,'assets',d),os.path.join(DST,'assets',d))
# Fahrzeuge: nur Texturen (Meshes stecken fertig vorbereitet in assets/cache/autos/*.scn)
V='trabant bmw_e30 small_car hudson dodge audi_rs7 bmw_m8 audi_r8 porsche911 bugatti hoonicorn police_ford armored ambulance firetruck mercedes supra f100 jdm bus cartrailer container_truck'.split()
for v in V:
    shutil.copytree(os.path.join(SRC,'assets/vehicles',v),os.path.join(DST,'assets/vehicles',v),ignore=shutil.ignore_patterns('*.gltf','*.bin','*.gltf.import','*.glb','*.glb.import'))
for f in glob.glob(SRC+'/assets/characters/michelle*'):shutil.copy2(f,DST+'/assets/characters/')
tot=0
for r,_,fs in os.walk(DST):
    if '/.git' in r: continue
    for f in fs: tot+=os.path.getsize(os.path.join(r,f))
print('Größe MB',tot//2**20)
