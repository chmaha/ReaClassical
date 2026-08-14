@description ReaClassical
@author chmaha
@version 27.0.45
@changelog
  feeder_core: wire PARAMBASE + enable ReaControlMIDI's CC Enable on creation
  chunk_link: PARAMBASE needs the parameter's real native-units minimum, not 0
  Guard every real BR_EnvAlloc call site against SWS not being installed
  BR_Envelope_Properties: fix real crash - GetSetObjectState isn't Lua-scriptable
  wip_fx_feeder: reuse freed MIDI channels instead of climbing forever
  Accessible Smart Import: offer Import Takes vs Import Polywav, matching the sighted GUI's tab
  Accessible Preferences: Backspace resets the current field, add Reset All to Defaults
  ReaClassical_Update ReaClassical.lua: use MB() instead of say() for user-facing errors
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
