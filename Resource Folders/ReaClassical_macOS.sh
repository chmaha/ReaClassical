#!/bin/bash

echo "Welcome to ReaClassical installer..."
sleep 2
pkgver=6.73
arch=`uname -m`
osver=`sw_vers -productVersion`
dmgtype="universal"
bool=`echo "$osver < 10.15" | bc`
if $bool == 1
then
dmgtype="x86_64"
echo "Using x86_64 dmg file..."
else
echo "Using universal dmg file..."
fi

echo "Downloading REAPER from reaper.fm"
sleep 2
curl https://reaper.fm/files/${pkgver::1}.x/reaper${pkgver//.}_$dmgtype.dmg -L -o reaper.dmg
echo "Converting and mounting DMG..."
sleep 2
hdiutil convert -quiet reaper.dmg -format UDTO -o reaper_temp
hdiutil attach -quiet -nobrowse -noverify -noautoopen -mountpoint ./reaper_temp  reaper_temp.cdr
echo "Downloading ReaClassical resource folder for MacOS"
sleep 2
curl https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/MacOS-$arch.zip -o resource_folder.zip -L
echo "Extracting files into ReaClassical folder..."
sleep 2
unzip -q resource_folder.zip -d ReaClassical/
echo "Copying REAPER.app into ReaClassical folder..."
sleep 2
cp -R reaper_temp/REAPER.app ReaClassical/
echo "Unmounting image and deleting temporary files..."
sleep 2
hdiutil detach reaper_temp
rm reaper.dmg reaper_temp.cdr resource_folder.zip
echo "Portable ReaClassical Installation complete!"
