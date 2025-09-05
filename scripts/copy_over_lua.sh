#!/bin/sh
# copy over changed lua files from REAPER scripts folder

SRC="$HOME/Desktop/ReaClassical_26/Scripts/chmaha Scripts/ReaClassical" -- change back to SRC="$HOME/.config/REAPER/Scripts/chmaha Scripts/ReaClassical" later!
DEST="ReaClassical"

cp "$SRC"/*.lua "$DEST"
