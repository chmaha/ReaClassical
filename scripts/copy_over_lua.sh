#!/bin/sh
# copy over changed lua files from REAPER scripts folder

SRC="$HOME/.config/REAPER/Scripts/chmaha Scripts/ReaClassical"
DEST="ReaClassical"

cp "$SRC"/*.lua "$DEST"
