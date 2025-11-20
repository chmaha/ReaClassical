#!/bin/sh
# copy over changed lua files from REAPER scripts folder

SRC="$HOME/Desktop/ReaClassical_26/Scripts/chmaha Scripts/ReaClassical"
DEST="$HOME/code/chmaha/ReaClassical/ReaClassical/Scripts/chmaha Scripts/ReaClassical"

cp "$SRC"/*.lua "$DEST"
