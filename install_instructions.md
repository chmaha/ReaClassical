# Instructions for installing ReaClassical

For the complete and recommended experience on Linux, MacOS and Windows you can run a single install script that does everything for you...

## Quick Full Portable Install on Linux, MacOS & Windows

Open a terminal, navigate to the folder where you want to download ReaClassical and paste the following according to your operating system:
##### Linux (including Raspberry Pi)
```bash
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_Linux.sh | sh
# or using wget
wget --secure-protocol=auto --https-only --secure-protocol=auto --https-only -O - https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_Linux.sh | sh
```
or
##### MacOS
``` 
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_macOS.sh | sh
```
or
##### Windows
Download [ReaClassical_Win.exe](https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_Win.exe) (64-bit) where you want to install ReaClassical and double-click. The source code for the installer is  [here](https://github.com/chmaha/ReaClassical/tree/main/Resource%20Folders/ReaClassical-Windows-Go-Installer).

The executable or script will pull the REAPER binary archive, resource folder base archive + appropriate userplugins and do the required magic.

For those who only want access to the scripts and jsfx plugins:

## Basic Manual Install Inside Your Existing REAPER Install

To just use the scripts and jsfx plugins without any customization of keymaps, toolbar etc:
1. Install both ReaPack (https://reapack.com/) and latest bleeding edge SWS Extensions (https://www.sws-extension.org/download/pre-release/) if you haven't already
2. Import my repository into ReaPack by copying and pasting [this link](https://github.com/chmaha/ReaClassical/raw/main/index.xml). If you need help with importing see https://reapack.com/user-guide#import-repositories.
3. Search for "ReaClassical" and install the main ReaClassical package and any jsfx plugins (my "RCPlugs" are highly recommended for classical work). 
4. Use the ReaClassical project template for your new projects (you can set this in the REAPER preferences) and change to the ReaClassical theme (Options > Themes).
5. Set up keyboard shortcuts in the actions list (? shortcut) as desired.

## For updating an existing install of ReaClassical:

1. Sync ReaPack to get the latest version of ReaClassical scripts.
2. Download the latest portable install as per the instructions above (it will create a new ReaClassical folder with a year + quarter suffix e.g. "ReaClassical_23Q2").
3. Copy across any updated files/settings to your previous install's resource path as described in the [release notes](https://raw.githubusercontent.com/chmaha/ReaClassical/main/release_notes.pdf).
4. Restart REAPER.

### Notes

On MacOS, due to security settings, you might need to right-click on the binaries in the UserPlugins subfolder and click open. Then you need to approve. Once you click yes on both, you can then start REAPER.



