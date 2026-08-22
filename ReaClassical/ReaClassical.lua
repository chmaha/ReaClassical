@description ReaClassical
@author chmaha
@version 27.0.52
@changelog
  Allow delete with ripple to work on empty space
  Mixer Control FX param edit: Escape reverts live value
  Add New Project Tab wrapper that announces "New tab"
  Add named undo blocks to S-D and generic marker add/delete scripts
  Announce undone action; cycle FX dropdown params with Up/Down
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
