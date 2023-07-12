#!/bin/bash
# by chmaha (April 2023)

# Script to install ReaClassical on Linux
# Works for both x86_64 and aarch64 architectures
# Change the pkgver number below to download an alternative version of REAPER.

###########
pkgver=6.81
rcver=23Q3
###########

echo "Welcome to ReaClassical installer..."
sleep 2
arch=`uname -m`

echo "Downloading REAPER $pkgver from reaper.fm..."
sleep 2
wget -q --show-progress --progress=bar:force https://reaper.fm/files/${pkgver::1}.x/reaper${pkgver//.}_linux_$arch.tar.xz
echo "Extracting files from REAPER archive to ReaClassical_$rcver folder"
tar -xf reaper${pkgver//.}_linux_$arch.tar.xz
mv reaper_linux_$arch/ ReaClassical_$rcver/
rm reaper${pkgver//.}_linux_$arch.tar.xz
cd ReaClassical_$rcver
mv REAPER/* .
rmdir REAPER
echo "Downloading ReaClassical files from Github..."
sleep 2
wget -q --show-progress --progress=bar:force https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/Resource_Folder_Base.zip
wget -q --show-progress --progress=bar:force https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/UserPlugins/UP_Linux-${arch}.zip
echo "Extracting files from archives..."
sleep 2
unzip -q Resource_Folder_Base.zip
rm Resource_Folder_Base.zip
unzip -q UP_Linux-${arch}.zip -d ./UserPlugins/
rm UP_Linux-${arch}.zip

echo "Portable ReaClassical Installation complete!"


