@description ReaClassical
@author chmaha
@version 27.0.48
@changelog
  Rename RC_TERMINAL_ARGS to RC_SCRIPT_ARGS; remove 3 dead headless branches
  DDP/CD-Text metadata validation, queued warnings, pinned render row
  Merge worktree-snapshot-engine-security-fix
  Cross-deselect media/automation items across Next/Previous navigation
  Accessible Peak and Overs Check: audition the peak, mark overs/peak
  Extract shared Snapshot Engine, fix injection/mute/GUID-matching bugs
  Remove requires left orphaned by the Terminal.lua command reduction
  Extract track-setup command handlers out of Terminal.lua into a shared library
  Extract shared mixer/routing helpers from Terminal.lua into ReaClassical_Mixer_Core.lua
  Delete all zero-dependent command families from Terminal
  Fix three O(n^2)/redundant-scan hotspots found while comparing against Cohler's lib
  Add browsable overs list to the accessible Peak and Overs Check
  Add accessible branch for Peak and Overs Check
  Combine Show/Hide Children into a single Toggle Children command
  Terminal clean part 1
  Regenerate docs (manual, terminal guide, shortcuts)
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
