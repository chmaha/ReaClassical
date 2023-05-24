@description ReaClassical
@author chmaha
@version 23.20
@changelog
  Create CD Markers: Add default 200ms marker/region offset
  PDF Guide: Reference 35ms crossfades in manual set-up and editing sections
  New: ReaClassical Preferences (see screenshot above)
  S-D edits: All S-D editing scripts use xfade value from RC Preferences
  Create CD Markers: Better CD frame snapping to account for decimal values
  Create CD Markers: Warning if any CD audio tracks are less than 4 seconds in length
  Create CD Markers: Enforce 1-second minimum for INDEX0 before a # track
  S-D Edit: Fix 3-point right-hand crossfading using new API
  S-D Edit: Further code clean-up
  Create CD Markers: Add space at start of project if not enough room for chosen offset
  Create CD Markers: Refine adding space at start of project for offset
  ReaClassical Preferences: Make project-based
  ReaClassical Preferences: Add album lead-out (postgap) as a customizable value
  Create CD Markers: Place metadata marker relative to =END marker
  S-D editing scripts: Use project extstate for S-D edit length
  Create CD Markers: Use project extstate for custom lengths
  New: Rearrange CD Tracks (left/right)
  Rearrange CD Tracks: Add guard clause for no selected item
  New themes: Sequoia Blue, Sequoia Green and Pyramix
  New themes: Make selected item color #ff7608
  New Theme: SaDiE
  New Function: Explode Multi-Channel Item(s)
  SaDiE theme: adjust colors to blend with arrange window and add black peak edges
  New Theme: Sonic Solutions
  New: Colorize (add a custom color to an item and those in the same group)
  Colorize: Unselect item(s) at the end of the function
  Colorize: Add undo block
  Move Track Right: Select only first item of the track before dialog appears
  Add Aux/Submix: Scroll to top of project after adding track
  Retain muted guide tracks during fade editor auditioning
  Split Whole Project View function into separate horizontal and vertical zoom functions
  Whole Project View functions: Remove superfluous undo blocks etc
  S-D Edit function: Respect existing edits contained within the source markers
  Insert with time-stretching: Respect existing edits contained within the source markers by gluing
  Insert with time-stretching: Remove superfluous functions and variables
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
  [rpp] ReaClassical.RPP
  [theme] ReaClassical.ReaperThemeZip
  [theme] Pyramix.ReaperThemeZip
  [theme] Sequoia.ReaperThemeZip
  [theme] SaDiE.ReaperThemeZip
  [theme] Sonic Solutions.ReaperThemeZip
  ../PDF_Guide/ReaClassical User Guide.pdf > ReaClassical_PDF_Guide.pdf
@about
  These scripts, along with the included custom project template and theme, provide everything you need for professional classical music editing, mixing and mastering in REAPER.

