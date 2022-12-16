#!/bin/bash

echo "Welcome to ReaClassical installer..."
sleep 2
pkgver=6.71
arch=aarch64

echo "Downloading REAPER from reaper.fm..."
sleep 2
wget –q --show-progress https://reaper.fm/files/${pkgver::1}.x//reaper${pkgver//.}_linux_$arch.tar.xz
echo "Extracting files from REAPER archive"
tar -xf reaper${pkgver//.}_linux_$arch.tar.xz
rm reaper${pkgver//.}_linux_$arch.tar.xz
cd reaper_linux_${arch}/REAPER
echo "Downloading ReaClassical files from Github..."
sleep 2
wget –q --show-progress https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/Linux-${arch}.zip
echo "Extracting files from archive..."
sleep 2
unzip -q Linux-${arch}.zip
rm Linux-${arch}.zip
echo "Portable ReaClassical Installation complete!"
sleep 2
read -p "Would you like to run REAPER now? (y/n)" yn
case $yn in
    [yY]) echo ok, starting REAPER...
            ./reaper;;
    *) echo exiting...;;
esac


