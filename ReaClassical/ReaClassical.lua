@description ReaClassical
@author chmaha
@version 26.1
@changelog
  Classical Take Record: Allow UI refresh before recording begins (fixes message to Arduino red light!)
  Record Panel: Set next recording section 1 second after last item in project
  Classical Take Record: check for empty saved cursor in vertical workflow
  Set Destination Markers to Item Edge: Allow for use on any folder
  Prepare Takes: Massively increase efficiency (Big O to quadratic to linear)
@metapackage
@provides
  [main] ReaClassical_3-point Insert Edit.lua
  [main] ReaClassical_Add Aux.lua
  [main] ReaClassical_Add CD Marker Offsets.lua
  [main] ReaClassical_Add Destination IN marker.lua
  [main] ReaClassical_Add Destination OUT Marker.lua
  [main] ReaClassical_Add Live Bounce Track.lua
  [main] ReaClassical_Add Ref Track.lua
  [main] ReaClassical_Add RoomTone Track.lua
  [main] ReaClassical_Add Source IN marker.lua
  [main] ReaClassical_Add Source OUT marker.lua
  [main] ReaClassical_Add Submix.lua
  [main] ReaClassical_Add Track To All Groups.lua
  [main] ReaClassical_Audio Calculator.lua
  [main] ReaClassical_Audition.lua
  [main] ReaClassical_Audition_with_playrate.lua
  [main] ReaClassical_Automation Mode.lua
  [main] ReaClassical_Build Edit List.lua
  [main] ReaClassical_Build Edit List using BWF offset.lua
  [main] ReaClassical_Classical Crossfade.lua
  [main] ReaClassical_Classical Crossfade Editor.lua
  [main] ReaClassical_Classical Take Record.lua
  [main] ReaClassical_Colorize.lua
  [main] ReaClassical_Convert Razor Area to Source Audition Markers.lua
  [main] ReaClassical_Convert REAPER project.lua
  [main] ReaClassical_Convert Source Audition markers.lua
  [main] ReaClassical_Copy Destination Material to Source.lua
  [main] ReaClassical_Create CD Markers.lua
  [main] ReaClassical_Create Project.lua
  [main] ReaClassical_DDP Metadata Editor.lua
  [main] ReaClassical_Delete All Audition Markers.lua
  [main] ReaClassical_Delete All S-D markers.lua
  [main] ReaClassical_Delete Leaving Silence.lua
  [main] ReaClassical_Delete S-D Project Markers.lua
  [main] ReaClassical_Delete Track From All Groups.lua
  [main] ReaClassical_Delete With Ripple.lua
  [main] ReaClassical_Destination Markers to Item Edge.lua
  [main] ReaClassical_Duplicate folder (No items).lua
  [main] ReaClassical_Editing Toolbar.lua
  [main] ReaClassical_Exclusive Audition.lua
  [main] ReaClassical_ExplodeMultiChannel.lua
  [main] ReaClassical_Factory Reset.lua
  [main] ReaClassical_Find Source Material.lua
  [main] ReaClassical_Find Take.lua
  [main] ReaClassical_Heal Edit.lua
  [main] ReaClassical_Help.lua
  [main] ReaClassical_Hide Children.lua
  [main] ReaClassical_Horizontal Workflow.lua
  [main] ReaClassical_Import Audio.lua
  [main] ReaClassical_Increment Take Number While Recording.lua
  [main] ReaClassical_Insert Automation.lua
  [main] ReaClassical_Insert with timestretching.lua
  [main] ReaClassical_Jump To Time.lua
  [main] ReaClassical_Mastering Mode.lua
  [main] ReaClassical_Metadata Report.lua
  [main] ReaClassical_Meterbridge.lua
  [main] ReaClassical_Microphone Indicator.lua
  [main] ReaClassical_Mixer Snapshots.lua
  [main] ReaClassical_Mission Control.lua
  [main] ReaClassical_Move Destination Material to Source.lua
  [main] ReaClassical_Move to Destination IN marker.lua
  [main] ReaClassical_Move to Destination OUT marker.lua
  [main] ReaClassical_Move to Next Marker.lua
  [main] ReaClassical_Move to Previous Marker.lua
  [main] ReaClassical_Move to Source IN marker.lua
  [main] ReaClassical_Move to Source OUT marker.lua
  [main] ReaClassical_Notes.lua
  [main=crossfade_editor] ReaClassical_Play Both Items of Crossfade.lua
  [main=crossfade_editor] ReaClassical_Play Both Items of Crossfade with playrate.lua
  [main=crossfade_editor] ReaClassical_Play Bottom Lane Only.lua
  [main=crossfade_editor] ReaClassical_Play Left Crossfade Item.lua
  [main=crossfade_editor] ReaClassical_Play Left Crossfade Item with playrate.lua
  [main=crossfade_editor] ReaClassical_Play Right Crossfade Item.lua
  [main=crossfade_editor] ReaClassical_Play Right Crossfade Item with playrate.lua
  [main=crossfade_editor] ReaClassical_Play Top Lane Only.lua
  [main] ReaClassical_Preferences.lua
  [main] ReaClassical_Prepare Takes.lua
  [main] ReaClassical_Previous Item or Fade.lua
  [main] ReaClassical_Promote Source to Destination.lua
  [main] ReaClassical_Record Panel.lua
  [main] ReaClassical_Regions from items.lua
  [main] ReaClassical_Remove All CD Marker Offsets.lua
  [main] ReaClassical_Remove All Item Fades.lua
  [main] ReaClassical_Remove Take Names.lua
  [main] ReaClassical_Reposition_Album_Tracks.lua
  [main] ReaClassical_S-D Edit.lua
  [main] ReaClassical_Set Dest Project Marker.lua
  [main] ReaClassical_Set Next Recording Section.lua
  [main] ReaClassical_Set Source Project Marker.lua
  [main] ReaClassical_Show Children.lua
  [main] ReaClassical_Show Source Audition Table.lua
  [main] ReaClassical_Show Statistics.lua
  [main] ReaClassical_Smart Import Audio.lua
  [main] ReaClassical_Source Markers to Item Edge.lua
  [main] ReaClassical_Split Items at Markers.lua
  [main] ReaClassical_TrackLeft.lua
  [main] ReaClassical_TrackRight.lua
  [main] ReaClassical_Vertical Workflow.lua
  [main] ReaClassical_Whole Project View.lua
  [main] ReaClassical_Whole Project View Horizontal.lua
  [main] ReaClassical_Whole Project View Vertical.lua
  [main] ReaClassical_Zoom to Destination IN marker.lua
  [main] ReaClassical_Zoom to Destination OUT marker.lua
  [main] ReaClassical_Zoom to Source IN marker.lua
  [main] ReaClassical_Zoom to Source OUT marker.lua
  [rpp] ReaClassical.RPP
  [rpp] Room_Tone_Gen.RPP
  [theme] ReaClassical.ReaperThemeZip
  [theme] ReaClassical Light.ReaperThemeZip
  [theme] ReaClassical WaveColors Dark.ReaperThemeZip
  [theme] ReaClassical WaveColors Light.ReaperThemeZip
  ReaClassical_Colors_Table.lua
  ReaClassical.ini
  ReaClassical-kb.ini
  ReaClassical-menu.ini
  ReaClassical-render.ini
  reaclassical-splash.png
@about
  These functions, along with the included custom project template and theme, provide everything you need for professional classical music editing, mixing and mastering in REAPER.

