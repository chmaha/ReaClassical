#!/bin/sh
# by chmaha (December 2023)

# Script to install ReaClassical on MacOS
# Works for all architectures and OS versions that are compatible with REAPER.
# Change the pkgver number below to download an alternative REAPER version.

###########
pkgver=6.83
rcver=23Q4
###########

echo "Welcome to ReaClassical installer..."
sleep 2
arch=`uname -m`
osver=`sw_vers -productVersion`
major=$(echo "$osver" | cut -d. -f1)
minor=$(echo "$osver" | cut -d. -f2)
dmgtype="universal"
if [ "$major" -lt 10 ] || ([ "$major" -eq 10 ] && [ "$minor" -lt 15 ]); then
    dmgtype="x86_64"
    echo "Using x86_64 dmg file..."
else
    echo "Using universal dmg file..."
fi

echo "Downloading REAPER $pkgver from reaper.fm"
sleep 2
curl https://reaper.fm/files/${pkgver::1}.x/reaper${pkgver//.}_$dmgtype.dmg -L -o reaper.dmg
echo "Converting and mounting DMG..."
sleep 2
hdiutil convert -quiet reaper.dmg -format UDTO -o reaper_temp
hdiutil attach -quiet -nobrowse -noverify -noautoopen -mountpoint ./reaper_temp  reaper_temp.cdr
echo "Downloading ReaClassical resource folder base and userplugins for MacOS"
sleep 2
curl -O https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/Resource_Folder_Base.zip -L
curl -O https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/UserPlugins/UP_MacOS-$arch.zip -L
echo "Extracting files into ReaClassical_$rcver folder..."
sleep 2
unzip -q Resource_Folder_Base.zip -d ReaClassical_$rcver/
unzip -q UP_MacOS-$arch.zip -d ReaClassical_$rcver/UserPlugins/
echo "Adding ReaClassical splash screen reference to reaper.ini"
sleep 2
abspath=`pwd ReaClassical_$rcver`
sed -i'.original' -e "s,reaclassical-splash.png,${abspath}/ReaClassical_$rcver/reaclassical-splash.png," ReaClassical_$rcver/reaper.ini
rm ReaClassical_$rcver/*.original
echo "Copying REAPER.app into ReaClassical folder..."
sleep 2
cp -R reaper_temp/REAPER.app ReaClassical_$rcver/
echo "Unmounting image and deleting temporary files..."
sleep 2
hdiutil detach reaper_temp
rm reaper.dmg reaper_temp.cdr Resource_Folder_Base.zip UP_MacOS-$arch.zip
echo "Portable ReaClassical Installation complete!"
