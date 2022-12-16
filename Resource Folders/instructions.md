### Instructions for installing ReaClassical
#### Tested with REAPER v6.71

##### Scripts

- reaclassical_Linux.sh (both x86_64 and aarch64)
<!--- reaclassical_MacOS-x86_64.sh
- reaclassical_MacOS-arm64.sh
- reaclassical_Windows-x64.ps1-->

##### Resource Folder archives

- Linux-x86_64.zip
- Linux-aarch64.zip (Raspberry Pi)
- Windows-x64.zip
- MacOS-x86_64.zip (64-bit Intel)
- MacOS-arm64.zip (M1 chip)

#### Quick Install on Linux

Download the [script](https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_Linux.sh) for your system and run where you want to download a portable install of ReaClassical. For example:

```
wget https://raw.githubusercontent.com/chmaha/ReaClassical/main/Resource%20Folders/ReaClassical_Linux.sh
sh ReaClassical_Linux.sh
```

The script will pull both the REAPER binary archive and resource folder archive and do the required magic. NOTE: Change the `pkgver=` line to download a different version of REAPER.

#### Manual Method 1: Portable Install
* Windows: Download REAPER and check the "Portable Install" box when installing. Download the required resource folder into the top level of the portable install directory e.g. C:/REAPER and unzip contents.
* MacOS: Create a REAPER folder (whatever name you like), download the resource folder archive into it and unzip contents. Download REAPER, mount the DMG and drag REAPER64.APP into the same folder.
* Linux: Download and extract REAPER. Download the resource folder into the REAPER subdirectory and and unzip contents.

Start REAPER and Sync ReaPack (to get latest ReaClassical scripts)

or...

#### Manual Method 2: Overwrite your existing install (caution!)
1. Rename/backup the contents of your existing resource folder (important!).
2. Create a replacement REAPER resource folder, download the resource folder archive to this location and unzip.
3. Start REAPER
4. Sync ReaPack (to get latest ReaClassical scripts)

### Notes

On MacOS, due to security settings, you'll need to right-click on the binaries in the UserPlugins subfolder and click open. Then you need to approve. Once you click yes on all three, you can then start REAPER.

The Raspberry Pi (and anything else that uses an 64-bit ARM chip) should run my tools perfectly. The only thing missing is juliansader's JS Reascript API plugin that doesn't currently have an arm64 binary. However, that's only there in the other zips in case you wanted to use an included MPL script for making CUE files from markers. My own tools are unaffected by the omission.



