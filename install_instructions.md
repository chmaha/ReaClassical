# Instructions for installing ReaClassical

For the complete and recommended experience on Linux, macOS, and Windows, simply run the single install script provided. You do not need to download or install REAPER separately — ReaClassical comes bundled with its own fully configured REAPER environment.

This means:
- One-step install — everything is set up automatically.
- Self-contained environment — ReaClassical comes with its own REAPER.
- Ready to use immediately — launch and start working right away.

⚠️ Important: Don’t install ReaClassical inside an existing REAPER setup. Let the installer create its own separate ReaClassical folder.

## Quick Full Portable Install on Linux, MacOS & Windows (for all nine architectures supported by REAPER)

##### Windows
Download [ReaClassical_Win64.exe](https://raw.githubusercontent.com/chmaha/ReaClassical/v25/Installers/ReaClassical_Win64.exe) (64-bit) or [ReaClassical_Win32.exe](https://raw.githubusercontent.com/chmaha/ReaClassical/v25/Installers/ReaClassical_Win32.exe) (32-bit) where you want to install ReaClassical and double-click. The source code for the installer is [here](https://github.com/chmaha/ReaClassical/tree/v25/Installers/ReaClassical-Windows-Go-Installer).

##### MacOS
Open a terminal, navigate to the folder where you want to download ReaClassical and paste the following:
``` sh
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/chmaha/ReaClassical/v25/Installers/ReaClassical_macOS.sh | sh
```
##### Linux (including Raspberry Pi)
Open a terminal, navigate to the folder where you want to download ReaClassical and paste the following:
```sh
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/chmaha/ReaClassical/v25/Installers/ReaClassical_Linux.sh | sh
```

The executable or script will pull the REAPER binary archive, resource folder base archive + appropriate userplugins and do the required magic. On first run, follow the update instructions below to get the latest and greatest ReaClassical functions, toolbar and keymap.

## For updating an existing portable install of ReaClassical:

1. Run the ReaClassical_Updater function (Shift+U). This will sync ReaPack to get the latest ReaClassical functions then offer to overwrite your toolbars and keymaps with the latest ReaClassical portable install defaults. **DON'T answer yes to either of these questions if you have your own custom toolbars or keyboard shortcuts as they will be overwritten!**
2. Run the REAPER Update Utility (Ctrl+U) to upgrade to the latest tested version of REAPER noted [here](https://raw.githubusercontent.com/chmaha/ReaClassical/v25/tested_reaper_ver.txt).

For those who only want access to the scripts and jsfx plugins you can install ReaClassical "Core":

## ReaClassical Core: Just the S-D editing tools inside your existing REAPER Install

To just use the S-D editing scripts and my jsfx plugins without any customization of keymaps, toolbar etc:
1. Install both ReaPack (https://reapack.com/) and latest bleeding edge SWS Extensions (https://www.sws-extension.org/download/pre-release/) if you haven't already
2. Import my repository into ReaPack by copying and pasting [this link](https://github.com/chmaha/ReaClassical/raw/v25/index.xml). If you need help with importing see https://reapack.com/user-guide#import-repositories.
3. Search for "ReaClassical Core" and install the main ReaClassical package and any jsfx plugins (my "RCPlugs" are highly recommended for classical work). 
5. Set up keyboard shortcuts in the actions list (? shortcut) as desired.

### Notes

On MacOS, due to security settings, you might need to right-click on the binaries in the UserPlugins subfolder and click open. Then you need to approve. Once you click yes on both, you can then start REAPER.



