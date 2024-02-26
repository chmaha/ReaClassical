#!/bin/sh
# by chmaha (February 2024)

# Script to install ReaClassical on Linux
# Works for both x86_64 and aarch64 architectures
# Change the pkgver number below to download an alternative version of REAPER.

###########
ver=7.11
rcver=24
###########

echo "Welcome to ReaClassical installer..."
sleep 2

major=$(echo $ver | awk -F. '{print $1}')
minor=$(echo $ver | awk -F. '{print $2}')
rcfolder="ReaClassical_${rcver}"
arch=$(uname -m)

echo "Downloading REAPER ${major}.${minor} from reaper.fm..."
sleep 2
curl -L -O --progress-bar https://reaper.fm/files/${major}.x/reaper${major}${minor}_linux_${arch}.tar.xz

# Check if a ReaClassical folder already exists
if [ -d "ReaClassical_${rcver}" ]; then
    # If it exists, create a folder with a date suffix
    date_suffix=$(date +%s | sha256sum | cut -c1-5)
    rcfolder="ReaClassical_${rcver}_${date_suffix}"
    sleep 2
    echo "Folder ReaClassical_${rcver} already exists. Adding unique identifier as suffix."
fi
sleep 2
echo "Extracting files from REAPER archive to ${rcfolder} folder"
tar -xf reaper${major}${minor}_linux_${arch}.tar.xz
mv reaper_linux_${arch}/ "${rcfolder}/"
rm reaper${major}${minor}_linux_${arch}.tar.xz
mv "${rcfolder}/REAPER/"* "${rcfolder}/"
rmdir "${rcfolder}/REAPER"

echo "Downloading ReaClassical files from Github..."
sleep 2
curl -L -O --progress-bar https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folder/Resource_Folder_Base.zip
curl -L -O --progress-bar https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folder/UserPlugins/UP_Linux-${arch}.zip
echo "Extracting files from archives..."
sleep 2
unzip -q Resource_Folder_Base.zip -d "${rcfolder}/"
rm Resource_Folder_Base.zip
unzip -q UP_Linux-${arch}.zip -d "${rcfolder}/UserPlugins/"
rm UP_Linux-${arch}.zip

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
