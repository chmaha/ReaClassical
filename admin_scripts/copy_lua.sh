#!/bin/sh
# copy over changed lua files from REAPER scripts folder
SRC="$HOME/Desktop/ReaClassical_26"
DEST="$HOME/code/chmaha/ReaClassical/ReaClassical"

rsync -av --delete --exclude='ReaClassical.lua' "$SRC/Scripts/chmaha Scripts/ReaClassical/" "$DEST/"
cp "$SRC/ColorThemes/"* "$DEST"
cp "$SRC/ProjectTemplates/ReaClassical.RPP" "$DEST"
cp "$SRC/ProjectTemplates/Room_Tone_Gen.RPP" "$DEST"

cp $SRC/reaper.ini "$DEST/ReaClassical.ini"
cp $SRC/reaper-kb.ini "$DEST/ReaClassical-kb.ini"
cp $SRC/reaper-mouse.ini "$DEST/ReaClassical-mouse.ini"
cp $SRC/reaper-menu.ini "$DEST/ReaClassical-menu.ini"
cp $SRC/reaper-render.ini "$DEST/ReaClassical-render.ini"


