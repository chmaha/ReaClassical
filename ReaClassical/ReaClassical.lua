@description ReaClassical
@author chmaha
@version 27.0.46
@changelog
  Item Rank: single circular list (No Rank, ranks, Item Notes), proper Up/Down
  Fix Item Rank Up/Down direction: Down always cycles ranks, Up jumps to notes
  Disarm All Tracks stops the record daemon; Item Rank gains note-taking; F5 nudge wording; Terminal import= comma lists; automation mode announces on silent auto-engage
  Add IEM item edge grow/shrink actions (left/right, plain + modifier)
  Add guard to toggle automation mode
  Insert Automation: redirect track-level automation off shared mixer tracks
  Add automation mode: lock+ripple-all sync, real AI tagging, snapshot-conversion rework
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
