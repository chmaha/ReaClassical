#!/bin/sh
# by chmaha (April 2024)

# Script to install ReaClassical on Linux
# Works for all architectures that are compatible with REAPER

cleanup() {
    if [ -n "$temp_dir" ] && [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
    fi
}

# Trap exit signals to ensure cleanup
trap cleanup EXIT

ver_txt="https://raw.githubusercontent.com/chmaha/ReaClassical/main/tested_reaper_ver.txt"
ver=$(curl -sS "$ver_txt" | awk '/====/{getline; print}')

rcver_txt="https://raw.githubusercontent.com/chmaha/ReaClassical/main/ReaClassical/ReaClassical.lua"
rcver=$(curl -sS "$rcver_txt" | awk '/@version/{split($2, version, "."); print version[1]}')

major=$(echo $ver | awk -F. '{print $1}')
minor=$(echo $ver | awk -F. '{print $2}')
rcfolder="ReaClassical_${rcver}"
arch=$(uname -m)

printf "Welcome to the ReaClassical installer...\n\n"
sleep 2
printf "Versions: REAPER $ver ($arch), ReaClassical $rcver\n\n"
sleep 2


date_suffix=$(date +%s | sha256sum | cut -c1-5)

# Try to create a temporary directory using mktemp
temp_dir=$(mktemp -d 2>/dev/null)
# Check if mktemp was successful
if [ -z "$temp_dir" ]; then
    # Fallback option: use /tmp as temporary directory
    temp_dir="/tmp/ReaClassical_${date_suffix}"
    mkdir -p "$temp_dir"
fi

echo "Downloading REAPER from reaper.fm..."
sleep 2
reaper_output="$temp_dir/reaper${major}${minor}_linux_${arch}.tar.xz"
reaper_url="https://reaper.fm/files/${major}.x/reaper${major}${minor}_linux_${arch}.tar.xz"
curl -L -o "$reaper_output" --progress-bar "$reaper_url"

# Check if a ReaClassical folder already exists
if [ -d "ReaClassical_${rcver}" ]; then
    # If it exists, create a folder with a date suffix
    rcfolder="ReaClassical_${rcver}_${date_suffix}"
    sleep 2
    echo "Folder ReaClassical_${rcver} already exists. Adding unique identifier as suffix."
fi
sleep 2
echo "Extracting files from REAPER archive to ${rcfolder} folder"
tar -xf "$reaper_output" -C "$temp_dir"
mv "$temp_dir/reaper_linux_${arch}/" "${rcfolder}/"
mv "${rcfolder}/REAPER/"* "${rcfolder}/"
rmdir "${rcfolder}/REAPER"

echo "Downloading ReaClassical files from Github..."
sleep 2
res_output="$temp_dir/Resource_Folder_Base.zip"
res_url="https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folder/Resource_Folder_Base.zip"
curl -L -o "$res_output" --progress-bar "$res_url"
up_output="$temp_dir/UP_Linux-${arch}.zip"
up_url="https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folder/UserPlugins/UP_Linux-${arch}.zip"
curl -L -o "$up_output" --progress-bar "$up_url"
sleep 2
unzip -q "$temp_dir/Resource_Folder_Base.zip" -d "${rcfolder}/"
unzip -q "$temp_dir/UP_Linux-${arch}.zip" -d "${rcfolder}/UserPlugins/"

# Get the realpath of $rcfolder
rcfolder_path=$(realpath "${rcfolder}")
sleep 2
# Add the line to reaper.ini under the [REAPER] section
echo "Adding the ReaClassical theme reference to reaper.ini"
sed -i "/^\[REAPER\]/a lastthemefn5=${rcfolder_path}/ColorThemes/ReaClassical.ReaperTheme" "${rcfolder}/reaper.ini"
sleep 2
echo "Adding the ReaClassical splash to reaper.ini"
sed -i "/^\[REAPER\]/a splashimage=Scripts/chmaha Scripts/ReaClassical/reaclassical-splash.png" "${rcfolder}/reaper.ini"
sleep 2
echo "Portable ReaClassical Installation complete!"

cleanup