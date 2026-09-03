@description ReaClassical
@author chmaha
@version 27.0.54
@changelog
  Snapshot-to-automation: respect deactivated recall parameters, dedupe conversion logic
  Add Toggle RCMASTER Hardware Output Mute script
  Replace Prepare Takes with Auto-color project + Fix Crossfade Sequence Edits
  Add marker number to announcement
  DDP Metadata Editor: live red-outline + tooltip for Latin-1/control-char issues
  DDP metadata validation: report embedded control chars separately from Latin-1
  Fix DDP re-import crash and missing waveform/peaks
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
