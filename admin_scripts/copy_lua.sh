#!/bin/sh
# copy over changed lua files from REAPER scripts folder

SRC="$HOME/Desktop/ReaClassical_26"
DEST="$HOME/code/chmaha/ReaClassical/ReaClassical"

cp "$SRC/Scripts/chmaha Scripts/ReaClassical/"* "$DEST"
cp "$SRC/ColorThemes/"* "$DEST"
cp "$SRC/ProjectTemplates/ReaClassical.RPP" "$DEST"
cp "$SRC/ProjectTemplates/Room_Tone_Gen.RPP" "$DEST"
