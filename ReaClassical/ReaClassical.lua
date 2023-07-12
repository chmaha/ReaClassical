@description ReaClassical
@author chmaha
@version 23.21
@changelog
  Room Tone: Add rudimentary dedicated room tone track
  Classical Take Record: Force user to select parent track
  Duplicate Folder: Force user to select a parent track
  Duplicate Folder: Fix selection of track after function has completed
  Edit Classical Crossfade: Add return line when function is tried outside of fade editor mode
  Prepare Takes: Provide cancel option on initial dialog
  RoomTone: Prepare existing functions for RoomTone function
  Various: Move local variable creation inside of main function (again!) and pass to other functions
  Various: Add missing arguments and parameters
  Bugfix: Fade editor, Reposition CD Tracks & Create CD Markers
  Various: Use for key in pairs(reaper) do _G[key] = reaper[key] end
  Various: Remove commented out code
  Various: Replace any reaper prefixes with r
  Whole Project View (Horizontal): Move edit cursor to start of project to make sure zoom works as expected
  Create CD Markers: Add Redbook standard checks for number of tracks (<= 99) and length of CD (< 79.57 minutes)
  Classical Crossfade Editor: Only enter mode if user selects an item on track 1
  Create CD Markers: Add ReaClassical metadata via MESSAGE key
  S-D Edit: Prematurely end function by cleaning up if there are no source media items to select
  Whole Project View Vertical: Respect child track visibility
  Shift CD Track Left/Right: Don't allow moving CD tracks whose start overlaps with previous item
  Move CD Track Left/Right: Treat crossfaded CD track starts as part of same group
  Move CD Track Left/Right: Use better variable names for current item position
  NO-OP: Code beautification part 3
  NO-OP: Code beautification part 2
  NO-OP: Revise previous commit to use 4-space indentation
  S-D functions: NO-OP code beautification
  Classical Take Record: Keep next folder group rec-armed for continued monitoring
  Classical Take Record: Show only folder track as selected
  Classical Take Record: Always show next rec-armed folder group in mixer
  Classical Take Record: Allow for pausing and then returning to original start position for next recording
  Create Folder: Add track grouping
  PDF Guide: Various tweaks
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

