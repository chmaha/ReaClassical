# Instructions for installing ReaClassical

For the complete and recommended experience on Linux, MacOS and Windows you can download and run a single install script that does everything for you...

## Quick Full Portable Install on Linux, MacOS & Windows

Download the script for your system and run where you want to download a portable install of ReaClassical:
##### Linux (including Raspberry Pi)
```
wget https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_Linux.sh
sh ReaClassical_Linux.sh
```
or
##### MacOS
``` 
curl -O https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_macOS.sh
sh ReaClassical_macOS.sh
```
or
##### Windows
Download [ReaClassical_Win.exe](https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_Win.exe) (64-bit) where you want to install ReaClassical and double-click. It *might* require Win10 or higher.

or...

```
curl -O https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_Win.ps1
powershell -executionpolicy bypass -File .\ReaClassical_Win.ps1
```

The executable or script will pull the REAPER binary archive, resource folder base archive + appropriate userplugins and do the required magic.

NOTE: Change the **`pkgver=`** line to download a different version of REAPER.

For those who only want access to the scripts and jsfx plugins:

## Basic Manual Install Inside Your Existing REAPER Install

To just use the scripts and jsfx plugins without any customization of keymaps, toolbar etc:
1. Install both ReaPack (https://reapack.com/) and latest bleeding edge SWS Extensions (https://www.sws-extension.org/download/pre-release/) if you haven't already
2. Import my repository into ReaPack by copying and pasting [this link](https://github.com/chmaha/ReaClassical/raw/main/index.xml). 
3. Search for "ReaClassical" and install the main ReaClassical package and any jsfx plugins (my "RCPlugs" are highly recommended for classical work). 
4. Use the ReaClassical project template for your new projects (you can set this in the REAPER preferences) and change to the ReaClassical theme (Options > Themes).
5. Set up keyboard shortcuts in the actions list (? shortcut) as desired.

## For updating an existing install of ReaClassical:

1. Download the latest portable install as per the instructions above (it will create a new ReaClassical folder with a year + quarter suffix e.g. "ReaClassical_23Q2").
2. Copy across any desired files/settings to your previous install including the latest SWS Extensions from UserPlugins, custom toolbar from MenuSets, contents of Data/Toolbar_icons, import either the "ReaClassical" or "Full_Classical_DAW" keymap from KeyMaps (if you like the ReaClassical defaults) etc.

### Notes

On MacOS, due to security settings, you might need to right-click on the binaries in the UserPlugins subfolder and click open. Then you need to approve. Once you click yes on all three, you can then start REAPER.



