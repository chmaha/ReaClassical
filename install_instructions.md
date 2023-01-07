### Instructions for installing ReaClassical
#### Tested with REAPER v6.73

#### Quick Install on Linux, MacOS & Windows

Download the script for your system and run where you want to download a portable install of ReaClassical:
##### Linux
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

The script will pull the REAPER binary archive, resource folder base archive + required userplugins and do the required magic.

NOTE: Change the **`pkgver=`** line to download a different version of REAPER.

##### Scripts and executables

- [ReaClassical_Linux.sh](https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_Linux.sh) (both x86_64 and aarch64)
- [ReaClassical_macOS.sh](https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_macOS.sh) (all architectures and OS versions compatible with REAPER)
- [ReaClassical_Win.sh](https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_Win.ps1) (64-bit)
- [ReaClassical_Win.exe](https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_Win.exe) (64-bit)

#### Manual Method 1: Portable Install
* __Windows__: Download REAPER and check the "Portable Install" box when installing. Download the Resource_Folder_Base.zip into the top level of the portable install directory e.g. C:/REAPER and unzip contents. Download UP_Windows-x64.zip and unzip into the newly created UserPlugins subfolder.
* __MacOS__: Create a REAPER folder ("ReaClassical" or whatever name you like), download the Resource_Folder_Base.zip into it and unzip contents. Download the appropriate userplugins zip (starting with "UP_MacOS-") for your system and unzip into the newly created UserPlugins subfolder, mount the DMG and drag REAPER64.APP into the same folder.
* __Linux__: Download and extract REAPER. Download the resource folder into the REAPER subdirectory and and unzip contents. Download the appropriate userplugins zip (starting with "UP_Linux-") for your system and unzip into the UserPlugins subfolder.

Start REAPER and Sync ReaPack (to get latest ReaClassical scripts)

##### Resource Folder archive

- [Resource_Folder_Base.zip](https://github.com/chmaha/ReaClassical/blob/main/Resource%20Folders/Resource_Folder_Base.zip) (compatible with all systems)

##### UserPlugins archives

- [UP_Linux-x86_64.zip](https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/UserPlugins/UP_Linux-x86_64.zip)
- [UP_Linux-aarch64.zip](https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/UserPlugins/UP_Linux-aarch64.zip) (Raspberry Pi)
- [UP_Windows-x64.zip](https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/UserPlugins/UP_Windows-x64.zip)
- [UP_MacOS-x86_64.zip](https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/UserPlugins/UP_MacOS-x86_64.zip) (64-bit Intel)
- [UP_MacOS-arm64.zip](https://github.com/chmaha/ReaClassical/raw/main/Resource%20Folders/UserPlugins/UP_MacOS-arm64.zip) (M1 chip)



or...

#### Manual Method 2: Overwrite your existing install (caution!)
1. Rename/backup the contents of your existing resource folder (important!).
2. Create a replacement REAPER resource folder, download the resource folder archive to this location and unzip.
3. Start REAPER
4. Sync ReaPack (to get latest ReaClassical scripts)

### Notes

On MacOS, due to security settings, you might need to right-click on the binaries in the UserPlugins subfolder and click open. Then you need to approve. Once you click yes on all three, you can then start REAPER.

The Raspberry Pi (and anything else that uses an 64-bit ARM chip) should run my tools perfectly. The only thing missing is juliansader's JS Reascript API plugin that doesn't currently have an arm64 binary. However, that's only there in the other zips in case you wanted to use an included MPL script for making CUE files from markers. My own tools are unaffected by the omission.



