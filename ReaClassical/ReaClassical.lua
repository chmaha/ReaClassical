@description ReaClassical
@author chmaha
@version 27.0.42
@changelog
  ReaClassical 27.0.42
  Scrub personal recent-file/folder history from the shipped ReaClassical.ini template
  Remove the C++ extension: binaries/ tree, its 2 submodules, and CI build workflows
  Revert Factory Reset's download_fresh_defaults() to its real pre-C++-extension behavior
@metapackage
@provides
  [main] ReaClassical_*.lua
  core.lua.rc
  [main=crossfade_editor] crossfade_editor/*.lua
  xfgui.lua.rc
  [nomain] lib/ReaClassical_Mixer Snapshots Daemon.lua
  [nomain] lib/ReaClassical_Record Panel Daemon.lua
  lib.lua.rc
  [jsfx] *.jsfx
  [rpp] *.RPP
  [theme] ReaClassical*.ReaperThemeZip
  [www] ReaClassical_remote.html
  *.ini
  *.png
  ReaClassical-*.html
@about
  These functions, along with the included custom project template and theme, provide everything you need for professional classical music editing, mixing and mastering in REAPER.
