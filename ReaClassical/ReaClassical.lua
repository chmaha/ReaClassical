@description ReaClassical
@author chmaha
@version 26.6.8pre90
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
  NEW: Accessible Automation Navigator -- keyboard-navigable gfx window for adding track/FX automation or snapshot values (OSARA/debug mode; supports ramp in/out)
  NEW: Toggle Special Tracks -- jump between folder tracks and special tracks (mixer/aux/submix/ref/live/roomtone); envelope lane navigation works within special track context
  NEW: XFM (Accessible Fade Editor) -- headless crossfade editing mode with shortcuts for nudging, slipping, widening/narrowing, fade shape cycling, item volume, and auditioning; designed for blind engineers working without the Classical Crossfade Editor GUI
  NEW: Toggle record monitoring off and on
  NEW: Headless Record Panel daemon -- keeps F9/take-counting/clip-reporting working for OSARA users without opening the Record Panel GUI
  NEW: Headless Mixer Snapshots daemon -- same auto-recall as the GUI snapshot window, without needing it open
  NEW: Play/Stop replacement for Spacebar that announces transport state (plus an edit-cursor-following variant)
  NEW: Repeat Last Terminal Command shortcut
  NEW: Nudge Marker Left/Right shortcuts
  NEW: Hide/Show Automation Lanes commands
  NEW: Shortcuts guide
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
  NEW: Disarm All Tracks shortcut
  NEW: Update REAPER command/shortcut
  NEW: Move to Start/End of Selected Item shortcuts
  NEW: Announce Timeline Position shortcut
  NEW: Announce RC Master Peak shortcut
  Terminal: mute/pan batch commands for tracks and RC Master, with spoken confirmation
  Set pan at project creation; allow resetting a pan pair to center
  Terminal: vertical workflow track/folder creation now supports specifying names
  Terminal: more uniform command syntax
  Terminal: installosara/update now work from a blank REAPER window
  Headless Record Panel daemon: map remaining GUI Record Panel recording actions
  Announce take number on next/previous item and new take recording
@metapackage
@provides
  [main] ReaClassical_3-point Insert Edit.lua
  [main] ReaClassical_Accessible Edit Automation.lua
  [main] ReaClassical_Add CD Marker Offsets.lua
  [main] ReaClassical_Add Destination IN marker.lua
  [main] ReaClassical_Add Destination OUT Marker.lua
  [main] ReaClassical_Add Source IN marker.lua
  [main] ReaClassical_Add Source OUT marker.lua
  [main] ReaClassical_Announce Highest Take.lua
  [main] ReaClassical_Announce Items in Folder.lua
  [main] ReaClassical_Announce RCMASTER Peak.lua
  [main] ReaClassical_Announce Take Number.lua
  [main] ReaClassical_Announce Timeline Position.lua
  [main] ReaClassical_Audio Calculator.lua
  [main] ReaClassical_Audition Destination IN to OUT.lua
  [main] ReaClassical_Audition from Destination IN marker.lua
  [main] ReaClassical_Audition from Destination OUT marker.lua
  [main] ReaClassical_Audition from Source IN marker.lua
  [main] ReaClassical_Audition from Source OUT marker.lua
  [main] ReaClassical_Audition Source IN to OUT.lua
  [main] ReaClassical_Audition to Destination IN marker.lua
  [main] ReaClassical_Audition to Destination OUT marker.lua
  [main] ReaClassical_Audition to Source IN marker.lua
  [main] ReaClassical_Audition to Source OUT marker.lua
  [main] ReaClassical_Audition.lua
  [main] ReaClassical_Audition_with_playrate.lua
  [main] ReaClassical_Build Edit List using BWF offset.lua
  [main] ReaClassical_Build Edit List.lua
  [main] ReaClassical_Classical Crossfade Editor.lua
  [main] ReaClassical_Classical Crossfade.lua
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
  [main] ReaClassical_Delete With Ripple.lua
  [main] ReaClassical_Destination Markers to Item Edge.lua
  [main] ReaClassical_Disarm All Tracks.lua
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
  [main] ReaClassical_Increment Take Number While Recording.lua
  [main] ReaClassical_Insert Automation.lua
  [main] ReaClassical_Insert with timestretching.lua
  [main] ReaClassical_Jump To Time.lua
  [main] ReaClassical_Meterbridge.lua
  [main] ReaClassical_Microphone Indicator.lua
  [main] ReaClassical_Mission Control.lua
  [main] ReaClassical_Mixer Snapshots.lua
  [main] ReaClassical_Move Destination Material to Source.lua
  [main] ReaClassical_Move to Destination IN marker.lua
  [main] ReaClassical_Move to Destination OUT marker.lua
  [main] ReaClassical_Move to End of Selected Item.lua
  [main] ReaClassical_Move to First Item on Track.lua
  [main] ReaClassical_Move to Last Item on Track.lua
  [main] ReaClassical_Move to Next Marker.lua
  [main] ReaClassical_Move to Previous Marker.lua
  [main] ReaClassical_Move to Source IN marker.lua
  [main] ReaClassical_Move to Source OUT marker.lua
  [main] ReaClassical_Move to Start of Selected Item.lua
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
  [main] ReaClassical_Nudge Item Left x modifier.lua
  [main] ReaClassical_Nudge Item Right.lua
  [main] ReaClassical_Nudge Item Right x modifier.lua
  [main] ReaClassical_Nudge Marker Left x modifier.lua
  [main] ReaClassical_Nudge Marker Left.lua
  [main] ReaClassical_Nudge Marker Right x modifier.lua
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
  [main] ReaClassical_Regions from items.lua
  [main] ReaClassical_Remove All CD Marker Offsets.lua
  [main] ReaClassical_Remove All Item Fades.lua
  [main] ReaClassical_Remove Take Names.lua
  [main] ReaClassical_Repeat Last Terminal Command.lua
  [main] ReaClassical_Reposition_Album_Tracks.lua
  [main] ReaClassical_S-D Edit.lua
  [main] ReaClassical_Select All Items in Folder.lua
  [main] ReaClassical_Set Dest Project Marker.lua
  [main] ReaClassical_Set Item Playback Rate.lua
  [main] ReaClassical_Set Next Recording Section.lua
  [main] ReaClassical_Set Source Project Marker.lua
  [main] ReaClassical_Shortcuts.lua
  [main] ReaClassical_Show Automation Lanes.lua
  [main] ReaClassical_Show Children.lua
  [main] ReaClassical_Show Source Audition Table.lua
  [main] ReaClassical_Show Statistics.lua
  [main] ReaClassical_Smart Import Audio.lua
  [main] ReaClassical_Source Markers to Item Edge.lua
  [main] ReaClassical_Split Items at Markers.lua
  [main] ReaClassical_Take Region to Source Pair.lua
  [main] ReaClassical_Terminal.lua
  [main] ReaClassical_Toggle Monitor.lua
  [main] ReaClassical_Toggle Special Tracks.lua
  [main] ReaClassical_TrackLeft.lua
  [main] ReaClassical_TrackRight.lua
  [main] ReaClassical_Whole Project View Horizontal.lua
  [main] ReaClassical_Whole Project View Vertical.lua
  [main] ReaClassical_Whole Project View.lua
  [main] ReaClassical_XFM Audition Crossfade.lua
  [main] ReaClassical_XFM Audition Left Item.lua
  [main] ReaClassical_XFM Audition Right Item.lua
  [main] ReaClassical_XFM Cycle Fade Shape.lua
  [main] ReaClassical_XFM Grow Fade End x modifier.lua
  [main] ReaClassical_XFM Grow Fade End.lua
  [main] ReaClassical_XFM Grow Fade Start x modifier.lua
  [main] ReaClassical_XFM Grow Fade Start.lua
  [main] ReaClassical_XFM Item Volume Down 0.2dB.lua
  [main] ReaClassical_XFM Item Volume Down 1dB.lua
  [main] ReaClassical_XFM Item Volume Reset.lua
  [main] ReaClassical_XFM Item Volume Up 0.2dB.lua
  [main] ReaClassical_XFM Item Volume Up 1dB.lua
  [main] ReaClassical_XFM Match Left Item Fade.lua
  [main] ReaClassical_XFM Match Right Item Fade.lua
  [main] ReaClassical_XFM Mode Daemon.lua
  [main] ReaClassical_XFM Narrow Crossfade x modifier.lua
  [main] ReaClassical_XFM Narrow Crossfade.lua
  [main] ReaClassical_XFM Nudge Item Left x modifier.lua
  [main] ReaClassical_XFM Nudge Item Left.lua
  [main] ReaClassical_XFM Nudge Item Right x modifier.lua
  [main] ReaClassical_XFM Nudge Item Right.lua
  [main] ReaClassical_XFM Reset.lua
  [main] ReaClassical_XFM Select Both Items.lua
  [main] ReaClassical_XFM Select Left Item.lua
  [main] ReaClassical_XFM Select Right Item.lua
  [main] ReaClassical_XFM Shift Crossfade Left x modifier.lua
  [main] ReaClassical_XFM Shift Crossfade Left.lua
  [main] ReaClassical_XFM Shift Crossfade Right x modifier.lua
  [main] ReaClassical_XFM Shift Crossfade Right.lua
  [main] ReaClassical_XFM Shrink Fade End x modifier.lua
  [main] ReaClassical_XFM Shrink Fade End.lua
  [main] ReaClassical_XFM Shrink Fade Start x modifier.lua
  [main] ReaClassical_XFM Shrink Fade Start.lua
  [main] ReaClassical_XFM Slip Item Left x modifier.lua
  [main] ReaClassical_XFM Slip Item Left.lua
  [main] ReaClassical_XFM Slip Item Right x modifier.lua
  [main] ReaClassical_XFM Slip Item Right.lua
  [main] ReaClassical_XFM Widen Crossfade x modifier.lua
  [main] ReaClassical_XFM Widen Crossfade.lua
  [main] ReaClassical_Zoom to Destination IN marker.lua
  [main] ReaClassical_Zoom to Destination OUT marker.lua
  [main] ReaClassical_Zoom to Source IN marker.lua
  [main] ReaClassical_Zoom to Source OUT marker.lua
  [jsfx] ListenbackMicMonitor.jsfx
  [rpp] ReaClassical.RPP
  [rpp] Room_Tone_Gen.RPP
  [theme] ReaClassical.ReaperThemeZip
  [theme] ReaClassical Light.ReaperThemeZip
  [theme] ReaClassical WaveColors Dark.ReaperThemeZip
  [theme] ReaClassical WaveColors Light.ReaperThemeZip
  [www] ReaClassical_remote.html
  ReaClassical_Add Live Bounce Track.lua
  ReaClassical_Add Ref Track.lua
  ReaClassical_Add RoomTone Track.lua
  ReaClassical_Add Aux.lua
  ReaClassical_Colors_Table.lua
  ReaClassical_Track_Naming.lua
  ReaClassical_Time_Naming.lua
  ReaClassical_Announce.lua
  ReaClassical_XFM_Utils.lua
  ReaClassical_Folder_Naming.lua
  ReaClassical.ini
  ReaClassical-kb.ini
  ReaClassical-mouse.ini
  ReaClassical-menu.ini
  ReaClassical-render.ini
  ReaClassical-metadata.ini
  reaclassical-splash.png
  ReaClassical-Manual.html
  ReaClassical-Shortcuts.html
  ReaClassical-Terminal-Guide.html
  ReaClassical_Update REAPER.lua
  ReaClassical_Record Panel Daemon.lua
  ReaClassical_Mixer Snapshots Daemon.lua
  ReaClassical_Vertical Workflow.lua
  ReaClassical_Metadata Report.lua
  ReaClassical_Horizontal Workflow.lua
  ReaClassical_Delete Track From All Groups.lua
  ReaClassical_Add Submix.lua
@about
  These functions, along with the included custom project template and theme, provide everything you need for professional classical music editing, mixing and mastering in REAPER.

