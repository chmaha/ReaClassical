#!/bin/sh

# Self-contained ReaClassical installer for MacOS (makeself bundle)
# Works for all architectures and OS versions compatible with REAPER
# Automatically selects the correct UserPlugins and resources

rcver="26"
arch=$(uname -m)
rcfolder="ReaClassical_${rcver}"

printf "Welcome to the ReaClassical installer...\n\n"
sleep 1

# Check if target folder exists in $USER_PWD
if [ -d "$USER_PWD/$rcfolder" ]; then
    date_suffix=$(date +%s | shasum -a 256 | cut -c1-5)
    rcfolder="${rcfolder}_${date_suffix}"
    echo "Folder already exists. Installing to ${rcfolder} instead."
fi

# Determine DMG type based on architecture / macOS version
osver=$(sw_vers -productVersion)
major=$(echo "$osver" | cut -d. -f1)
minor=$(echo "$osver" | cut -d. -f2)
dmgtype="universal"

if [ "$arch" = "i386" ]; then
    dmgtype="i386"
    echo "Using i386 dmg file..."
elif [ "$major" -lt 10 ] || ([ "$major" -eq 10 ] && [ "$minor" -lt 15 ]); then
    dmgtype="x86_64"
    echo "Using x86_64 dmg file..."
else
    echo "Using universal dmg file..."
fi

# Temporary folder for mounting DMG
date_suffix=$(date +%s | shasum -a 256 | cut -c1-5)
temp_dir=$(mktemp -d 2>/dev/null)
if [ -z "$temp_dir" ]; then
    temp_dir="/tmp/ReaClassical_${date_suffix}"
    mkdir -p "$temp_dir"
fi

mount_dir="$temp_dir/reaper_mount"
mkdir -p "$mount_dir"

# Mount bundled REAPER DMG
reaper_dmg="./REAPER_${dmgtype}.dmg"
if [ ! -f "$reaper_dmg" ]; then
    echo "Error: REAPER DMG missing from bundle."
    exit 1
fi

echo "Mounting REAPER DMG..."
hdiutil convert -quiet "$reaper_dmg" -format UDTO -o "$temp_dir/reaper_temp"
hdiutil attach -quiet -nobrowse -noverify -noautoopen -mountpoint "$mount_dir" "$temp_dir/reaper_temp.cdr"

# Extract bundled ReaClassical resources
res_zip="./Resource_Folder_Base.zip"
up_file="./reaper_sws-"$arch".dylib"

if [ ! -f "$res_zip" ] || [ ! -f "$up_file" ]; then
    echo "Error: Resource_Folder_Base.zip or reaper_sws-${arch}.dylib missing from bundle."
    exit 1
fi

echo "Extracting ReaClassical resources into $rcfolder..."
mkdir -p "$rcfolder"
unzip -q "$res_zip" -d "$rcfolder/"
mkdir -p "$rcfolder/UserPlugins"
cp -f "$up_file" "$rcfolder/UserPlugins/"

# Absolute path for configuration
rcfolder_path=$(realpath "$rcfolder")

# Configure ReaClassical theme and splash
echo "Adding theme and splash references to reaper.ini..."
sed -i '' -e "/^\[REAPER\]/a\\
lastthemefn5=${rcfolder_path}/ColorThemes/ReaClassical.ReaperTheme" "$rcfolder/reaper.ini"
sed -i '' -e "/^\[REAPER\]/a\\
splashimage=${rcfolder_path}/Scripts/chmaha Scripts/ReaClassical/reaclassical-splash.png" "$rcfolder/reaper.ini"

# Copy REAPER.app into rcfolder
echo "Copying REAPER.app into $rcfolder..."
cp -R "$mount_dir/REAPER.app" "$rcfolder/"

# Unmount and clean up
hdiutil detach "$mount_dir" >/dev/null 2>&1
rm -rf "$temp_dir"

# Move the final folder to the directory where the .run was executed
mv "$rcfolder" "$USER_PWD/"

echo "Portable ReaClassical Installation complete!"
