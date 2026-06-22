@description ReaClassical
@author chmaha
@version 26.6.8pre19
@changelog
  NEW: accessibility layer
  NEW: Terminal commands including complete domain-specific language
  NEW: Various reporting functions that announce via OSARA
  NEW: Peak and overs check
  NEW: Audition to/from source/destination IN/OUT
  NEW: Move to first item on track
  NEW: Move to last item on track
  NEW: Navigate to next/previous folder
  NEW: Navigate to next/previous track in folder
  NEW: Navigate to next/previous envelope lane (announces track and automation type)
  NEW: Toggle record monitoring off and on
  NEW: Headless Record Panel daemon -- keeps F9/take-counting/clip-reporting working for OSARA users without opening the Record Panel GUI
  NEW: Headless Mixer Snapshots daemon -- same auto-recall as the GUI snapshot window, without needing it open
  NEW: Play/Stop replacement for Spacebar that announces transport state (plus an edit-cursor-following variant)
  NEW: Repeat Last Terminal Command shortcut
  NEW: Nudge Marker Left/Right shortcuts
  NEW: Hide/Show Automation Lanes commands
  NEW: Humanized track/folder/time names in spoken announcements
  NEW: Online Terminal Guide (linked from Help for OSARA users), plain HTML build pipeline
  NEW: GUI windows blocked by default when OSARA is installed (allowgui= override)
  NEW: debug=on/off mode for testing announcements without OSARA installed
  Terminal: tr=<query> jumps to a track by name within the current folder
  Terminal: sel=+<folder>,<positions> adds tracks to selection by folder label/position
  Terminal: mixer reordering (Nu/Nd) now supports moving a contiguous block of tracks together
  Terminal: tolerate stray whitespace around commas/dashes in position lists
  Terminal: rec.latest? reports the highest take number found on disk
  Terminal: query inputs / basic autoinput command
  Allow factoryreset at any time, even outside a project
  Announce next armed folder automatically in Vertical workflow
  Ensure functions like Prepare Takes/Create CD Markers run headless (not silently skipped or popping a stray GUI) when triggered as a side effect of another command
  Clip reporting now factors in item volume (D_VOL)
  S-D edit functions: Unify scrubmode toggle
  Add generic lua high/medium risk error guards across many functions
  Move all files associated with exports into Exports folders
  Group exports by folder
  Mixer Snapshots: Select item when clicking on table row
  Meterbridge: Fix meters when listenback present
  Workflow sync: Auto-flatten nested folders
  Add OSARA install terminal command
  Add clip reporting
  Create CD Markers: Add automatic metadata to renders and push to custom button
  Automation: Limit inserting via time selection
  Automation: Auto overwrite overlapping automation items
  Combine prev/next item with move to and select previous/next envelope point/item while on envelope lane
  Add Shortcuts for Fast forward and rewind functions
  Add Shortcuts for Scrub left and right
  Add Shortcuts for delete/move nearest marker to cursor
  Add Shortcuts for Nudge item left/right
  Add Shortcuts for trim item edges to edit cursor
@metapackage
@provides
  [main] ReaClassical_3-point Insert Edit.lua
  [nomain] ReaClassical_Add Aux.lua
  [main] ReaClassical_Add CD Marker Offsets.lua
  [main] ReaClassical_Add Destination IN marker.lua
  [main] ReaClassical_Add Destination OUT Marker.lua
  [nomain] ReaClassical_Add Live Bounce Track.lua
  [nomain] ReaClassical_Add Ref Track.lua
  [nomain] ReaClassical_Add RoomTone Track.lua
  [main] ReaClassical_Add Source IN marker.lua
  [main] ReaClassical_Add Source OUT marker.lua
  [nomain] ReaClassical_Add Submix.lua
  [main] ReaClassical_Announce Take Number.lua
  [main] ReaClassical_Announce Timeline Position.lua
  [main] ReaClassical_Audio Calculator.lua
  [main] ReaClassical_Audition.lua
  [main] ReaClassical_Audition from Destination IN marker.lua
  [main] ReaClassical_Audition from Destination OUT marker.lua
  [main] ReaClassical_Audition from Source IN marker.lua
  [main] ReaClassical_Audition from Source OUT marker.lua
  [main] ReaClassical_Audition to Destination IN marker.lua
  [main] ReaClassical_Audition to Destination OUT marker.lua
  [main] ReaClassical_Audition to Source IN marker.lua
  [main] ReaClassical_Audition to Source OUT marker.lua
  [main] ReaClassical_Audition_with_playrate.lua
  [main] ReaClassical_Auto Solo Folder.lua
  [main] ReaClassical_Build Edit List.lua
  [main] ReaClassical_Build Edit List using BWF offset.lua
  [main] ReaClassical_Classical Crossfade.lua
  [main] ReaClassical_Classical Crossfade Editor.lua
  [main] ReaClassical_Classical Take Record.lua
  [main] ReaClassical_Colorize.lua
  [main] ReaClassical_Convert REAPER project.lua
  [main] ReaClassical_Copy Destination Material to Source.lua
  [main] ReaClassical_Create CD Markers.lua
  [main] ReaClassical_Create Project.lua
  [main] ReaClassical_Delete All S-AUD Markers.lua
  [main] ReaClassical_Delete All S-D markers.lua
  [main] ReaClassical_Delete Leaving Silence.lua
  [main] ReaClassical_Delete S-D Project Markers.lua
  [nomain] ReaClassical_Delete Track From All Groups.lua
  [main] ReaClassical_Delete With Ripple.lua
  [main] ReaClassical_Destination Markers to Item Edge.lua
  [main] ReaClassical_Duplicate folder (No items).lua
  [main] ReaClassical_Edit Automation.lua
  [main] ReaClassical_Editing Toolbar.lua
  [main] ReaClassical_ExplodeMultiChannel.lua
  [main] ReaClassical_Factory Reset.lua
  [main] ReaClassical_Find Source Material.lua
  [main] ReaClassical_Find Take.lua
  [main] ReaClassical_Heal Edit.lua
  [main] ReaClassical_Help.lua
  [main] ReaClassical_Hide Automation Lanes.lua
  [main] ReaClassical_Hide Children.lua
  [nomain] ReaClassical_Horizontal Workflow.lua
  [main] ReaClassical_Increment Take Number While Recording.lua
  [main] ReaClassical_Insert Automation.lua
  [main] ReaClassical_Insert with timestretching.lua
  [main] ReaClassical_Jump To Time.lua
  [nomain] ReaClassical_Metadata Report.lua
  [main] ReaClassical_Meterbridge.lua
  [main] ReaClassical_Microphone Indicator.lua
  [main] ReaClassical_Mixer Snapshots.lua
  [main] ReaClassical_Mission Control.lua
  [nomain] ReaClassical_Mixer Snapshots Daemon.lua
  [main] ReaClassical_Move Destination Material to Source.lua
  [main] ReaClassical_Move to Destination IN marker.lua
  [main] ReaClassical_Move to Destination OUT marker.lua
  [main] ReaClassical_Move to First Item on Track.lua
  [main] ReaClassical_Move to Last Item on Track.lua
  [main] ReaClassical_Move to Next Marker.lua
  [main] ReaClassical_Move to Previous Marker.lua
  [main] ReaClassical_Move to Source IN marker.lua
  [main] ReaClassical_Move to Source OUT marker.lua
  [main] ReaClassical_Navigate to First Folder.lua
  [main] ReaClassical_Navigate to Next Envelope Lane.lua
  [main] ReaClassical_Navigate to Next Folder.lua
  [main] ReaClassical_Navigate to Next Track in Folder.lua
  [main] ReaClassical_Navigate to Previous Envelope Lane.lua
  [main] ReaClassical_Navigate to Previous Folder.lua
  [main] ReaClassical_Navigate to Previous Track in Folder.lua
  [main] ReaClassical_Next Item or Fade.lua
  [main] ReaClassical_Notes.lua
  [main] ReaClassical_Nudge Item Left.lua
  [main] ReaClassical_Nudge Item Right.lua
  [main] ReaClassical_Nudge Marker Left.lua
  [main] ReaClassical_Nudge Marker Right.lua
  [main] ReaClassical_Peak and Overs Check.lua
  [main=crossfade_editor] ReaClassical_Play Both Items of Crossfade.lua
  [main=crossfade_editor] ReaClassical_Play Both Items of Crossfade with playrate.lua
  [main=crossfade_editor] ReaClassical_Play Bottom Lane Only.lua
  [main=crossfade_editor] ReaClassical_Play Left Crossfade Item.lua
  [main=crossfade_editor] ReaClassical_Play Left Crossfade Item with playrate.lua
  [main=crossfade_editor] ReaClassical_Play Right Crossfade Item.lua
  [main=crossfade_editor] ReaClassical_Play Right Crossfade Item with playrate.lua
  [main=crossfade_editor] ReaClassical_Play Top Lane Only.lua
  [main] ReaClassical_Play Stop Moving Edit Cursor.lua
  [main] ReaClassical_Play Stop.lua
  [main] ReaClassical_Preferences.lua
  [main] ReaClassical_Prepare Takes.lua
  [main] ReaClassical_Previous Item or Fade.lua
  [main] ReaClassical_Promote Source to Destination.lua
  [main] ReaClassical_Record Panel.lua
  [nomain] ReaClassical_Record Panel Daemon.lua
  [main] ReaClassical_Regions from items.lua
  [main] ReaClassical_Remove All CD Marker Offsets.lua
  [main] ReaClassical_Remove All Item Fades.lua
  [main] ReaClassical_Remove Take Names.lua
  [main] ReaClassical_Repeat Last Terminal Command.lua
  [main] ReaClassical_Reposition_Album_Tracks.lua
  [main] ReaClassical_S-D Edit.lua
  [main] ReaClassical_Set Dest Project Marker.lua
  [main] ReaClassical_Set Next Recording Section.lua
  [main] ReaClassical_Set Source Project Marker.lua
  [main] ReaClassical_Show Automation Lanes.lua
  [main] ReaClassical_Show Children.lua
  [main] ReaClassical_Show Source Audition Table.lua
  [main] ReaClassical_Show Statistics.lua
  [main] ReaClassical_Smart Import Audio.lua
  [main] ReaClassical_Source Markers to Item Edge.lua
  [main] ReaClassical_Split Items at Markers.lua
  [main] ReaClassical_Terminal.lua
  [main] ReaClassical_Toggle Monitor.lua
  [main] ReaClassical_TrackLeft.lua
  [main] ReaClassical_TrackRight.lua
  [nomain] ReaClassical_Vertical Workflow.lua
  [main] ReaClassical_Whole Project View.lua
  [main] ReaClassical_Whole Project View Horizontal.lua
  [main] ReaClassical_Whole Project View Vertical.lua
  [main] ReaClassical_Zoom to Destination IN marker.lua
  [main] ReaClassical_Zoom to Destination OUT marker.lua
  [main] ReaClassical_Zoom to Source IN marker.lua
  [main] ReaClassical_Zoom to Source OUT marker.lua
  [main] ReaClassical_Take Region to Source Pair.lua
  [main] ReaClassical_Set Item Playback Rate.lua
  [jsfx] ListenbackMicMonitor.jsfx
  [rpp] ReaClassical.RPP
  [rpp] Room_Tone_Gen.RPP
  [theme] ReaClassical.ReaperThemeZip
  [theme] ReaClassical Light.ReaperThemeZip
  [theme] ReaClassical WaveColors Dark.ReaperThemeZip
  [theme] ReaClassical WaveColors Light.ReaperThemeZip
  [www] ReaClassical_remote.html
  ReaClassical_Colors_Table.lua
  ReaClassical_Track_Naming.lua
  ReaClassical_Time_Naming.lua
  ReaClassical_Announce.lua
  ReaClassical_Folder_Naming.lua
  ReaClassical.ini
  ReaClassical-kb.ini
  ReaClassical-mouse.ini
  ReaClassical-menu.ini
  ReaClassical-render.ini
  ReaClassical-metadata.ini
  reaclassical-splash.png
  ReaClassical-Manual.html
  ReaClassical-Terminal-Guide.html
@about
  These functions, along with the included custom project template and theme, provide everything you need for professional classical music editing, mixing and mastering in REAPER.

