@description ReaClassical
@author chmaha
@version 23.19
@changelog
  Whole Project View: Switch back to original vertical zoom function for updated SWS
  Aux and submix: Allow for creation of aux and submix (@ track prefix) that stay visible
  Sync FX and routing: All child routing is now also copied from destination to source groups
  Classical Take Record: Add guard clause if no folder/track selected
  New Script: Add Aux/Submix @ track with color #4C9165 to end of tracklist
  Create Source Groups: Don't apply grouping for aux/submix tracks
  Various Scripts: Use Solo in Place (SIP) to allow for unmuted sends to aux/submixes
  Various scripts: Change color of @ aux/submix tracks if created manually
  New Script: Reposition Tracks
  Reposition Tracks: Now works with both prepared takes grouping (T) and newer media/razor editing grouping
  Create CD markers: If run save a key/value pair and change opening dialog to yes/no options.
  Reposition Tracks: Use key/value pair to automatically re-run Create CD Markers after repositioning
  Reposition Tracks: Add guard clauses to deal with zero track count, zero media items or presence of empty items
  Reposition Tracks: Rename to Reposition Album Tracks
  Add Aux/Submix @ track: Only allow use if a folder exists already
  Prepare Takes: Change messagebox to yes/no if edits present
  Prepare Takes: Improve wording of message when offering to remove item take names when edits present
  Prepare Takes: Always ask if user wants to remove item take names
  mpl Markers to CUE: Complete revision of code including correcting a cue file specification error, added width to dialog box, removal of external dependencies and simplifying the main function to use separated functions
  Added Markers to CUE script to ReaClassical repository with permission
  Remove JS API from UserPlugins
  Create Source Groups: Allow for creating lead/follow groups with existing manually-created folders
  Create CD Markers: Create pregap markers by prefixing take name with "!"
  Markers to CUE: Match CUE file name with audio filename given in dialog
  Markers to CUE: Save user-inputted metadata and recall on next run
  PDF Guide: Switch to sans serif font and add typesetting info on first page
  Update copyright year to 2023
  PDF Guide: Tidy up install/update procedures and add reference to release notes
  ReaClassical theme: Restore
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
  [main] ReaClassical_Whole Project View.lua
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
  [rpp] ReaClassical.RPP
  [theme] ReaClassical.ReaperThemeZip
  ../PDF_Guide/ReaClassical User Guide.pdf > ReaClassical_PDF_Guide.pdf
@about
  These scripts, along with the included custom project template and theme, provide everything you need for professional classical music editing, mixing and mastering in REAPER.

