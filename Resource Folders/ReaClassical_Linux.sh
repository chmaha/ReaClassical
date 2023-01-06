#!/bin/bash

# Install script to install ReaClassical on Linux
# Works for both x86_64 and aarch64 architectures

echo "Welcome to ReaClassical installer..."
sleep 2
pkgver=6.73
arch=`uname -m`

echo "Downloading REAPER $pkgver from reaper.fm..."
sleep 2
wget -q --show-progress --progress=bar:force https://reaper.fm/files/${pkgver::1}.x//reaper${pkgver//.}_linux_$arch.tar.xz
echo "Extracting files from REAPER archive"
tar -xf reaper${pkgver//.}_linux_$arch.tar.xz
rm reaper${pkgver//.}_linux_$arch.tar.xz
cd reaper_linux_${arch}/REAPER
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
sleep 2
read -p "Would you like to run REAPER now? (y/n)" yn
case $yn in
    [yY]) echo ok, starting REAPER...
            ./reaper;;
    *) echo exiting...;;
esac


