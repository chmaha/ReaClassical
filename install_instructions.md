### Instructions for installing ReaClassical

To just use the scripts and jsfx plugins without any customization of keymaps, toolbar etc, install both ReaPack (https://reapack.com/)and latest bleeding edge SWS Extensions (https://www.sws-extension.org/download/pre-release/), import my repository into ReaPack by copying and pasting [this link](https://github.com/chmaha/ReaClassical/raw/main/index.xml). Search for "ReaClassical" and install the main ReaClassical package and any jsfx plugins. Use the ReaClassical project template for your new projects (you can set this in the REAPER preferences) and change to the ReaClassical theme (Options > Themes).

For the complete and recommended experience on Linux, MacOS and Windows you can download and run a single install script that does everything for you...

#### Quick Full Portable Install on Linux, MacOS & Windows

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
Download [ReaClassical_Win.exe](https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_Win.exe) (64-bit) where you want to install ReaClassical and double-click.

or...

```
curl -O https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_Win.ps1
powershell -executionpolicy bypass -File .\ReaClassical_Win.ps1
```

The executable or script will pull the REAPER binary archive, resource folder base archive + appropriate userplugins and do the required magic.

NOTE: Change the **`pkgver=`** line to download a different version of REAPER.

##### Scripts and executables

- [ReaClassical_Linux.sh](https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_Linux.sh) (both x86_64 and aarch64)
- [ReaClassical_macOS.sh](https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_macOS.sh) (all architectures and OS versions compatible with REAPER)
- [ReaClassical_Win.sh](https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_Win.ps1) (64-bit)
- [ReaClassical_Win.exe](https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_Win.exe) (64-bit)

##### Resource Folder archive

- [Resource_Folder_Base.zip](https://github.com/chmaha/ReaClassical/blob/main/Resource%20Folders/Resource_Folder_Base.zip) (compatible with all systems)

##### UserPlugins archives

- [UP_Linux-x86_64.zip](https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/UserPlugins/UP_Linux-x86_64.zip)
- [UP_Linux-aarch64.zip](https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/UserPlugins/UP_Linux-aarch64.zip) (Raspberry Pi)
- [UP_Windows-x64.zip](https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/UserPlugins/UP_Windows-x64.zip)
- [UP_MacOS-x86_64.zip](https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/UserPlugins/UP_MacOS-x86_64.zip) (64-bit Intel)
- [UP_MacOS-arm64.zip](https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/UserPlugins/UP_MacOS-arm64.zip) (M1 chip)


#### For updating an existing install of ReaClassical:

1. Download the latest portable install as per the instructions above (it will create a new ReaClassical folder with a year + quarter suffix e.g. "ReaClassical_23Q2").
2. Copy across any desired files/settings including the latest SWS Extensions from UserPlugins, custom toolbar etc.

### Notes

On MacOS, due to security settings, you might need to right-click on the binaries in the UserPlugins subfolder and click open. Then you need to approve. Once you click yes on all three, you can then start REAPER.



