@description ReaClassical
@author chmaha
@version 27.0.28
@changelog
  Quick export: prefix filename with Gxxx global take number when enabled
  Find take: accept G-prefexed input
  Add destination only and show all folders actions; share folder vis logic with MC
  Add note at cursor: add an empty note item on NOTES track and open its notes
  Mark Blemish: use 2s down-rank action
  Play Edit after making it: dual-tab improvements
  Play edit after making it: Add pre-roll pref and skip pre-roll before first edit
  Allow project and transport functions in regular REAPER projects
  Convert REAPER proj:choose microphones or separate material
  Guard ImGui window centering against an invalid viewport
@metapackage
@provides
  [main] ReaClassical_*.lua
  [main=crossfade_editor] crossfade_editor/*.lua
  [nomain] lib/*.lua
  [jsfx] *.jsfx
  [rpp] *.RPP
  [theme] ReaClassical*.ReaperThemeZip
  [www] ReaClassical_remote.html
  *.ini
  *.png
  ReaClassical-*.html
@about
  These functions, along with the included custom project template and theme, provide everything you need for professional classical music editing, mixing and mastering in REAPER.
