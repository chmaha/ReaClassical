#!/bin/sh

# POSIX-compliant script to copy ReaClassical Lua scripts from $SRC to $DEST

SRC="$HOME/Desktop/ReaClassical_26/Scripts/chmaha Scripts/ReaClassical"
DEST="$HOME/code/chmaha/ReaClassical/ReaClassicalCore"

# Ensure DEST directory exists
mkdir -p "$DEST"

# List of file mappings (source -> destination)
FILES="
3-point Insert Edit
Add Destination IN marker
Add Destination OUT Marker
Add Source IN marker
Add Source OUT marker
Delete All S-D markers
Delete Leaving Silence
Delete S-D Project Markers
Delete With Ripple
Destination Markers to Item Edge
Find Take
Insert with timestretching
Move to Destination IN marker
Move to Destination OUT marker
Move to Source IN marker
Move to Source OUT marker
Preferences
Prepare Takes
S-D Edit
Set Dest Project Marker
Set Source Project Marker
Source Markers to Item Edge
Zoom to Destination IN marker
Zoom to Destination OUT marker
Zoom to Source IN marker
Zoom to Source OUT marker
"

printf '%s\n' "$FILES" | while IFS= read -r name; do
    # Skip empty lines
    [ -z "$name" ] && continue

    src_file="$SRC/ReaClassical_${name}.lua"
    dest_file="$DEST/ReaClassical Core_${name}.lua"

    if [ -f "$src_file" ]; then
        cp -f "$src_file" "$dest_file"
        echo "Copied: $src_file -> $dest_file"
    else
        echo "Warning: Source file not found: $src_file"
    fi
done

echo "All files processed."
