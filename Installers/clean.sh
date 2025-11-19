#!/bin/sh

# Usage: ./clean_reaper.sh
# This will remove downloaded Reaper installers, SWS archives, and extracted plugin binaries.

linux_dir="src/linux"
macos_dir="src/macos"
win_dir="src/windows"

# Function to safely delete files matching a pattern
clean_dir() {
    dir="$1"
    pattern="$2"
    [ -d "$dir" ] || return
    for f in "$dir"/$pattern; do
        [ -e "$f" ] || continue
        echo "Deleting $f"
        rm -f "$f"
    done
}

echo "🔹 Cleaning Linux folder..."
clean_dir "$linux_dir" "reaper*.tar.xz"
clean_dir "$linux_dir" "reaper_sws*.so"
clean_dir "$linux_dir" "reaper_imgui*.so"

echo "🔹 Cleaning macOS folder..."
clean_dir "$macos_dir" "reaper*.dmg"
clean_dir "$macos_dir" "reaper_sws*.dylib"
clean_dir "$macos_dir" "reaper_imgui*.dylib"

echo "🔹 Cleaning Windows folder..."
clean_dir "$win_dir" "reaper*-install.exe"
clean_dir "$win_dir" "reaper_sws*.dll"
clean_dir "$win_dir" "reaper_imgui*.dll"

echo "✅ Cleanup completed!"
