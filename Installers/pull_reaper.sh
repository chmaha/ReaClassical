#!/bin/sh

# Usage: ./pull_reaper.sh 7.52
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

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
        # Keep only files containing the desired version
        case "$f" in
            *"$ver_no_dot"*) ;;      # keep matching version
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

echo "✅ Completed successfully!"
