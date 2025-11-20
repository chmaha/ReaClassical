#!/bin/sh

# Usage: ./pull_reaper.sh 7.52
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

reaimgui_ver="0.10.0.2"

ver="$1"
major=$(echo "$ver" | cut -d. -f1)
ver_no_dot=$(echo "$ver" | tr -d '.')
resource_zip="$HOME/code/chmaha/ReaClassical/Resource Folder/Resource_Folder_Base.zip"

# Create directories
linux_dir="src/linux"
macos_dir="src/macos"
win_dir="src/windows"
mkdir -p "$linux_dir" "$macos_dir" "$win_dir"

# --- Clean up old Reaper binaries that don't match the version ---
echo "🔹 Removing old Reaper binaries not matching version $ver ..."
for dir in "$linux_dir" "$macos_dir" "$win_dir"; do
    [ -d "$dir" ] || continue
    for f in "$dir"/reaper*; do
        # Skip if no files match
        [ -e "$f" ] || continue

        case "$f" in
            *"$ver_no_dot"*) ;;          # keep matching version
            *.so|*.dylib|*.dll) ;;       # ignore shared libraries
            *)
                echo "Deleting old file: $f"
                rm -f "$f"
                ;;
        esac
    done
done

# --- Linux downloads ---
for arch in x86_64 i686 aarch64 armv7l; do
    file="$linux_dir/reaper${ver_no_dot}_linux_${arch}.tar.xz"
    url="https://reaper.fm/files/${major}.x/reaper${ver_no_dot}_linux_${arch}.tar.xz"

    if [ -f "$file" ]; then
        echo "Skipping existing Linux $arch installer: $file"
    else
        echo "Downloading Linux $arch: $url"
        curl -L -o "$file" "$url"
    fi
done

# --- macOS downloads ---
for macarch in universal x86_64 i386; do
    file="$macos_dir/reaper${ver_no_dot}_${macarch}.dmg"
    url="https://reaper.fm/files/${major}.x/reaper${ver_no_dot}_${macarch}.dmg"

    if [ -f "$file" ]; then
        echo "Skipping existing macOS $macarch installer: $file"
    else
        echo "Downloading macOS $macarch: $url"
        curl -L -o "$file" "$url"
    fi
done

# --- Windows downloads ---
# 64-bit
file="$win_dir/reaper${ver_no_dot}_x64-install.exe"
url="https://reaper.fm/files/${major}.x/reaper${ver_no_dot}_x64-install.exe"
if [ -f "$file" ]; then
    echo "Skipping existing Windows x64 installer: $file"
else
    echo "Downloading Windows x64: $url"
    curl -L -o "$file" "$url"
fi

# 32-bit
file="$win_dir/reaper${ver_no_dot}-install.exe"
url="https://reaper.fm/files/${major}.x/reaper${ver_no_dot}-install.exe"
if [ -f "$file" ]; then
    echo "Skipping existing Windows 32-bit installer: $file"
else
    echo "Downloading Windows 32-bit: $url"
    curl -L -o "$file" "$url"
fi

# ARM64 (Win11 beta)
file="$win_dir/reaper${ver_no_dot}_win11_arm64ec_beta-install.exe"
url="https://reaper.fm/files/${major}.x/reaper${ver_no_dot}_win11_arm64ec_beta-install.exe"
if [ -f "$file" ]; then
    echo "Skipping existing Windows ARM64 installer: $file"
else
    echo "Downloading Windows ARM64 (beta): $url"
    curl -L -o "$file" "$url"
fi

# --- SWS Plugin downloads ---

# URLs by platform
win_sws_urls="
https://standingwaterstudios.com/download/featured/sws-2.14.0.7-Windows-x86.exe
https://standingwaterstudios.com/download/featured/sws-2.14.0.7-Windows-x64.exe
"

mac_sws_urls="
https://standingwaterstudios.com/download/featured/sws-2.14.0.7-Darwin-i386.dmg
https://standingwaterstudios.com/download/featured/sws-2.14.0.7-Darwin-x86_64.dmg
https://standingwaterstudios.com/download/featured/sws-2.14.0.7-Darwin-arm64.dmg
"

linux_sws_urls="
https://standingwaterstudios.com/download/featured/sws-2.14.0.7-Linux-i686.tar.xz
https://standingwaterstudios.com/download/featured/sws-2.14.0.7-Linux-x86_64.tar.xz
https://standingwaterstudios.com/download/featured/sws-2.14.0.7-Linux-armv7l.tar.xz
https://standingwaterstudios.com/download/featured/sws-2.14.0.7-Linux-aarch64.tar.xz
"

# --- imgui Plugin downloads ---

# URLs by platform
win_imgui_urls="
https://github.com/cfillion/reaimgui/releases/download/v$reaimgui_ver/reaper_imgui-x86.dll
https://github.com/cfillion/reaimgui/releases/download/v$reaimgui_ver/reaper_imgui-x64.dll
"

mac_imgui_urls="
https://github.com/cfillion/reaimgui/releases/download/v$reaimgui_ver/reaper_imgui-i386.dylib
https://github.com/cfillion/reaimgui/releases/download/v$reaimgui_ver/reaper_imgui-x86_64.dylib
https://github.com/cfillion/reaimgui/releases/download/v$reaimgui_ver/reaper_imgui-arm64.dylib
"

linux_imgui_urls="
https://github.com/cfillion/reaimgui/releases/download/v$reaimgui_ver/reaper_imgui-i686.so
https://github.com/cfillion/reaimgui/releases/download/v$reaimgui_ver/reaper_imgui-x86_64.so
https://github.com/cfillion/reaimgui/releases/download/v$reaimgui_ver/reaper_imgui-armv7l.so
https://github.com/cfillion/reaimgui/releases/download/v$reaimgui_ver/reaper_imgui-aarch64.so
"

# Check if a final SWS file already exists for the given extension
sws_exists() {
    dir="$1"
    pattern="$2"
    find "$dir" -maxdepth 1 -type f -name "$pattern" | grep -q .
}

# Generic download function
download_file() {
    url="$1"
    dest="$2"

    if [ ! -f "$dest" ]; then
        echo "Downloading $url ..."
        curl -L -o "$dest" "$url"
    else
        echo "Skipping existing file: $dest"
    fi
}

# Extract Windows/macOS archives using 7z
extract_7z() {
    archive="$1"
    dest_dir="$2"
    pattern="$3"

    tmp_dir=$(mktemp -d)
    echo "Extracting $archive ..."
    7z x "$archive" -o"$tmp_dir" -y > /dev/null

    # Recursively find matching files
    find "$tmp_dir" -type f -name "$pattern" | while read -r file; do
        echo "Copying $(basename "$file") to $dest_dir"
        cp "$file" "$dest_dir"
    done

    rm -rf "$tmp_dir"
    rm -f "$archive"
}

# Extract Linux tar.xz archives
extract_tar_xz() {
    archive="$1"
    dest_dir="$2"
    pattern="$3"

    tmp_dir=$(mktemp -d)
    echo "Extracting $archive ..."
    tar -xJf "$archive" -C "$tmp_dir"

    # Recursively find matching files
    find "$tmp_dir" -type f -name "$pattern" | while read -r file; do
        echo "Copying $(basename "$file") to $dest_dir"
        cp "$file" "$dest_dir"
    done

    rm -rf "$tmp_dir"
    rm -f "$archive"
}

# --- Windows SWS DLLs ---
if sws_exists "$win_dir" "reaper_sws-*.dll"; then
    echo "Skipping Windows SWS download — final DLL already exists."
else
    for url in $win_sws_urls; do
        archive="$win_dir/$(basename "$url")"
        download_file "$url" "$archive"
        extract_7z "$archive" "$win_dir" "reaper_sws*.dll"
    done
fi

# --- macOS SWS dylibs ---
if sws_exists "$macos_dir" "reaper_sws-*.dylib"; then
    echo "Skipping macOS SWS download — final dylib already exists."
else
    for url in $mac_sws_urls; do
        archive="$macos_dir/$(basename "$url")"
        download_file "$url" "$archive"
        extract_7z "$archive" "$macos_dir" "reaper_sws*.dylib"
    done
fi

# --- Linux SWS shared objects ---
if sws_exists "$linux_dir" "reaper_sws-*.so"; then
    echo "Skipping Linux SWS download — final .so already exists."
else
    for url in $linux_sws_urls; do
        archive="$linux_dir/$(basename "$url")"
        download_file "$url" "$archive"
        extract_tar_xz "$archive" "$linux_dir" "reaper_sws*.so"
    done
fi

echo "✅ SWS extraction completed!"

# --- Windows imgui DLLs ---
for url in $win_imgui_urls; do
    archive="$win_dir/$(basename "$url")"
    download_file "$url" "$archive"
done

# --- macOS imgui dylibs ---
for url in $mac_imgui_urls; do
    archive="$macos_dir/$(basename "$url")"
    download_file "$url" "$archive"
done

# --- Linux imgui shared objects ---
for url in $linux_imgui_urls; do
    archive="$linux_dir/$(basename "$url")"
    download_file "$url" "$archive"
done

echo "✅ Reaimgui download completed!"
