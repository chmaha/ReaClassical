#!/bin/sh
# by chmaha (April 2024)

# Script to install ReaClassical on MacOS
# Works for all architectures and OS versions that are compatible with REAPER

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

rcfolder="ReaClassical_${rcver}"
arch=`uname -m`
osver=`sw_vers -productVersion`
major=$(echo "$osver" | cut -d. -f1)
minor=$(echo "$osver" | cut -d. -f2)
dmgtype="universal"

printf "Welcome to the ReaClassical installer...\n\n"
sleep 2
printf "Versions: REAPER $ver ($arch), ReaClassical $rcver\n\n"
sleep 2


if [ "$arch" = "i386" ]; then
    dmgtype="i386"
    echo "Using i386 dmg file..."
elif [ "$major" -lt 10 ] || ([ "$major" -eq 10 ] && [ "$minor" -lt 15 ]); then
    dmgtype="x86_64"
    echo "Using x86_64 dmg file..."
else
    echo "Using universal dmg file..."
fi

date_suffix=$(date +%s | shasum -a 256 | cut -c1-5)

# Try to create a temporary directory using mktemp
temp_dir=$(mktemp -d 2>/dev/null)
# Check if mktemp was successful
if [ -z "$temp_dir" ]; then
    # Fallback option: use /tmp as temporary directory
    temp_dir="/tmp/ReaClassical_${date_suffix}"
    mkdir -p "$temp_dir"
fi

echo "Downloading REAPER $ver from reaper.fm"
sleep 2
reaper_url="https://reaper.fm/files/${ver::1}.x/reaper${ver//.}_$dmgtype.dmg"
curl -L -o "$temp_dir/reaper.dmg" "$reaper_url"
echo "Converting and mounting DMG..."
sleep 2
hdiutil convert -quiet "$temp_dir/reaper.dmg" -format UDTO -o "$temp_dir/reaper_temp"
hdiutil attach -quiet -nobrowse -noverify -noautoopen -mountpoint "$temp_dir/reaper_temp" "$temp_dir/reaper_temp.cdr"
echo "Downloading ReaClassical resource folder base and userplugins for MacOS"
sleep 2
res_output="$temp_dir/Resource_Folder_Base.zip"
res_url="https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folder/Resource_Folder_Base.zip"
curl -L -o "$res_output" "$res_url"
up_output="$temp_dir/UP_MacOS-$arch.zip"
up_url="https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folder/UserPlugins/UP_MacOS-$arch.zip"
curl -L -o "$up_output" "$up_url"

# Check if a ReaClassical folder already exists
if [ -d "ReaClassical_${rcver}" ]; then
    # If it exists, create a folder with a date suffix
    rcfolder="ReaClassical_${rcver}_${date_suffix}"
    sleep 2
    echo "Folder ReaClassical_${rcver} already exists. Adding unique identifier as suffix."
fi
sleep 2
echo "Extracting files into $rcfolder folder..."
sleep 2
unzip -q "$res_output" -d $rcfolder/
unzip -q "$up_output" -d $rcfolder/UserPlugins/
echo "Adding ReaClassical splash screen and theme references to reaper.ini"
sleep 2
abspath=`pwd $rcfolder`

sed -i'.bak' -e "/^\[REAPER\]/a\\
lastthemefn5=${abspath}\/$rcfolder\/ColorThemes\/ReaClassical.ReaperTheme" "$rcfolder/reaper.ini"
sed -i'.bak' -e "/^\[REAPER\]/a\\
splashimage=${abspath}\/$rcfolder\/Scripts\/chmaha Scripts\/ReaClassical\/reaclassical-splash.png" $rcfolder/reaper.ini
echo "Copying REAPER.app into ReaClassical folder..."
sleep 2
cp -R "$temp_dir/reaper_temp/REAPER.app" "$rcfolder/"
echo "Unmounting image and deleting temporary files..."
sleep 2
hdiutil detach "$temp_dir/reaper_temp"
echo "Portable ReaClassical Installation complete!"

cleanup
