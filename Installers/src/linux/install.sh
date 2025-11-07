#!/bin/sh

# Self-contained ReaClassical installer for Linux (makeself bundle)
# Supports x86_64, i686, aarch64, and armv7l architectures
# Automatically selects the correct REAPER and UserPlugins files

rcver="26"
arch=$(uname -m)
rcfolder="ReaClassical_${rcver}"

printf "Welcome to the ReaClassical installer...\n\n"
sleep 1

# Check if target folder exists
if [ -d "$USER_PWD/$rcfolder" ]; then
    date_suffix=$(date +%s | sha256sum | cut -c1-5)
    rcfolder="${rcfolder}_${date_suffix}"
    echo "Folder already exists. Installing to ${rcfolder} instead.\n"
fi

# Select REAPER tarball based on architecture
reaper_tar=$(ls ./reaper*_linux_"$arch".tar.xz 2>/dev/null | head -n1)
if [ -z "$reaper_tar" ]; then
    echo "Error: No REAPER tarball found for architecture $arch"
    exit 1
fi

# Extract REAPER version from tarball filename (e.g., reaper752_linux_x86_64.tar.xz → 7.52)
tar_basename=$(basename "$reaper_tar")
ver_num=$(echo "$tar_basename" | sed -E 's/reaper([0-9]+)_linux_.*/\1/')
major=$(echo "$ver_num" | cut -c1)
minor=$(echo "$ver_num" | cut -c2-)
ver="${major}.${minor}"

# Find the shared library file
up_file=$(ls ./reaper_sws-"$arch".so 2>/dev/null | head -n1)
if [ -z "$up_file" ]; then
    echo "Error: No UserPlugins file found for architecture $arch"
    exit 1
fi

# Resource folder
res_zip="./Resource_Folder_Base.zip"
if [ ! -f "$res_zip" ]; then
    echo "Error: Resource_Folder_Base.zip missing from bundle."
    exit 1
fi

printf "Versions: REAPER %s (%s), ReaClassical %s\n\n" "$ver" "$arch" "$rcver"
sleep 1

# Extract REAPER
echo "Extracting REAPER files for $arch..."
sleep 1
tar -xf "$reaper_tar" -C .
mv "./reaper_linux_${arch}/" "${rcfolder}/"
mv "${rcfolder}/REAPER/"* "${rcfolder}/" 2>/dev/null || true
rmdir "${rcfolder}/REAPER" 2>/dev/null || true

# Extract ReaClassical resources
echo "Extracting ReaClassical resources..."
sleep 1
unzip -q "$res_zip" -d "${rcfolder}/"
mkdir -p "${rcfolder}/UserPlugins"
cp -f "$up_file" "${rcfolder}/UserPlugins/"

# Absolute path for configuration
rcfolder_path=$(realpath "${rcfolder}")

# Configure ReaClassical theme and splash
echo "Adding the ReaClassical theme reference to reaper.ini..."
sed -i "/^\[REAPER\]/a lastthemefn5=${rcfolder_path}/ColorThemes/ReaClassical.ReaperTheme" "${rcfolder}/reaper.ini"
sleep 1
echo "Adding the ReaClassical splash to reaper.ini..."
sed -i "/^\[REAPER\]/a splashimage=Scripts/chmaha Scripts/ReaClassical/reaclassical-splash.png" "${rcfolder}/reaper.ini"

mv "$rcfolder" "$USER_PWD/"

sleep 1
echo "Portable ReaClassical Installation complete!"
