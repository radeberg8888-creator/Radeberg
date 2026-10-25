#!/bin/bash
# Kopiert die für das Spiel nötigen Dateien in das GitHub-Repo (ohne Rohmodelle, Testszenen-Ausgaben, .godot)
set -e
SRC=/home/claude/radeberg-godot
DST=/home/claude/radeberg
cd $SRC
rsync -a --delete --exclude '.git' --exclude '.godot' --exclude 'assets' --exclude 'build' $SRC/ $DST/ \
  --exclude '.github' --exclude 'export_presets.cfg' --exclude 'README.md' --exclude '.gitignore'
mkdir -p $DST/assets
for d in buildings/einzeln buildings/ghetto buildings/house buildings/stash props/tree props/polyhaven textures ui data cache animations \
         characters/joe characters/biker characters/daya characters/female \
         vehicles/small_car vehicles/police_ford vehicles/mercedes vehicles/bmw_e30 vehicles/audi_rs7 vehicles/trabant vehicles/porsche911 vehicles/container_truck vehicles/bus vehicles/jdm vehicles/audi_r8 vehicles/bmw_m8; do
  mkdir -p $DST/assets/$d; rsync -a --delete $SRC/assets/$d/ $DST/assets/$d/
done
cp $SRC/assets/characters/michelle.glb* $SRC/assets/characters/michelle_* $DST/assets/characters/ 2>/dev/null || true
du -sh $DST --exclude .git
