@description ReaClassical
@author chmaha
@version 23.23
@changelog
  Add album length comment to CUE file to prepare the way for creation of automated ReaClassical album report
  Add ISRC to CUE file when present
  CUE generation: Ensure album metadata is surrounded by quotation marks
  Ensure that the final region doesn't include a "!" in the name if a pregap exists before it
  CUE generation: Add CATALOG to top of CUE file if present in the album metadata @ marker
  Create plaintext and HTML album reports when creating a CUE file
  Use snake case for all function names
  Add pregap lines to album reports
  Correct calculation of final track duration when preceeded by a pregap
  CUE and report generation: Use DDP @ album metadata if available
  CUE and report generation: Always use saved year if available
  CUE generation: Add REM line about ReaClassical
  CUE generation Bugfix: Use WAVE vs WAV as file type for WAV, FLAC and WavPack
  CUE generation: Add INDEX 00 lines if pre-gaps present in project
  CUE generation: Beautify HTML album report
  Generate CUE: Fix path slash match
  Generate CUE: A few no-op code changes
  Generate CUE: Allow for both RPP and rpp extensions (default depends on OS)
@metapackage
@provides
  [main] ReaClassical_Add Destination IN marker.lua
  [main] ReaClassical_Add Destination OUT Marker.lua
  [main] ReaClassical_Add Source IN marker.lua
  [main] ReaClassical_Add Source OUT marker.lua
  [main] ReaClassical_Classical Crossfade Editor.lua
  [main] ReaClassical_Classical Crossfade.lua
  [main] ReaClassical_Classical Take Record.lua
  [main] ReaClassical_Delete All S-D markers.lua
  [main] ReaClassical_Duplicate folder (No items).lua
  [main] ReaClassical_Edit Classical Crossfade.lua
  [main] ReaClassical_Prepare Takes.lua
  [main] ReaClassical_S-D Edit.lua
  [main] ReaClassical_Whole Project View Horizontal.lua
  [main] ReaClassical_Whole Project View Vertical.lua
  [main] ReaClassical_Create source groups (vertical).lua
  [main] ReaClassical_Audition.lua
  [main] ReaClassical_3-point edit replace.lua
  [main] ReaClassical_Delete Leaving Silence.lua
  [main] ReaClassical_Delete With Ripple.lua
  [main] ReaClassical_Insert with timestretching.lua
  [main] ReaClassical_Create Folder.lua
  [main] ReaClassical_Lock_toggle.lua
  [main] ReaClassical_Create CD Markers.lua
  [main] ReaClassical_Help.lua
  [main] ReaClassical_Next Item or Fade.lua
  [main] ReaClassical_Previous Item or Fade.lua
  [main] ReaClassical_Add Aux or Submix.lua
  [main] ReaClassical_Reposition_Album_Tracks.lua
  [main] ReaClassical_mpl_Markers to CUE.lua
  [main] ReaClassical_Preferences.lua
  [main] ReaClassical_TrackLeft.lua
  [main] ReaClassical_TrackRight.lua
  [main] ReaClassical_ExplodeMultiChannel.lua
  [main] ReaClassical_Colorize.lua
  [main] ReaClassical_Add RoomTone Track.lua
  [rpp] ReaClassical.RPP
  [theme] ReaClassical.ReaperThemeZip
  [theme] Pyramix.ReaperThemeZip
  [theme] Sequoia.ReaperThemeZip
  [theme] SaDiE.ReaperThemeZip
  [theme] Sonic Solutions.ReaperThemeZip
  ../PDF_Guide/ReaClassical User Guide.pdf > ReaClassical_PDF_Guide.pdf
@about
  These scripts, along with the included custom project template and theme, provide everything you need for professional classical music editing, mixing and mastering in REAPER.

