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

# Use a while read loop to handle spaces correctly
printf '%s\n' "$FILES" | while IFS= read -r name; do
    # Skip empty lines
    [ -z "$name" ] && continue

    src_file="$SRC/ReaClassical_${name}.lua"
    dest_file="$DEST/ReaClassical Core_${name}.lua"

    if [ -f "$src_file" ]; then
        # Copy the file
        cp -f "$src_file" "$dest_file"

        # Replace the header text
        # Use a POSIX-compliant sed command
        sed -i \
            -e 's|"ReaClassical" package|"ReaClassical Core" package|' \
            -e 's|"ReaClassical.lua"|"ReaClassicalCore.lua"|' \
            "$dest_file"

        sed -i 's|ProjExtState(0, "ReaClassical"|ProjExtState(0, "ReaClassical Core"|g' "$dest_file"

        sed -i 's|local _, workflow = GetProjExtState(0, "ReaClassical Core", "Workflow")$|local workflow = "Horizontal"|' "$dest_file"

        sed -i 's#local marker_color = color_track and GetTrackColor(color_track) or 0#local marker_color = ColorToNative(23, 223, 143) | 0x1000000#' "$dest_file"
    else
        echo "Warning: Source file not found: $src_file"
    fi
done

echo "All files processed."
