@description ReaClassical
@author chmaha
@version 27.0.53
@changelog
  Add aria-live
  Add shortcut to force return of focus to arrange
  Add option for selective parameters and add accessible branch
  Use REAPER input boxes for text entry
  Use REAPER input box for text entry
  Announce crossfaded take numbers
  Auto-remove sliver edits
  Unselect all items before selecting items associated with CD track start
  Re-select previously selected item
  Unnecessary since folding into smart audio import
  Automatically and silently recalculate CD markers/regions if present
  Fix previous marker search when transport stopped
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
