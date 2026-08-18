@description ReaClassical
@author chmaha
@version 27.0.49
@changelog
  Fix 6 "GUI blocked" guards to actually block under DebugAnnounce too
  Accessible Notes: reorder fields to Item Name/Note/Take Number first
  Select All Items in Folder: shift Delete's context to items, not tracks
  Fix 9 keymap entries registered with absolute dev path, drop dead wip_fx_feeder entries
  Add accessible Notes and Audio Calculator; Item Rank backspace-clear
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
