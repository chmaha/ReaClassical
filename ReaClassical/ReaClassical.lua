@description ReaClassical
@author chmaha
@version 26.7pre12
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
  [main] *.lua
  [main=crossfade_editor] crossfade_editor/*.lua
  [jsfx] *.jsfx
  [rpp] *.RPP
  [theme] ReaClassical*.ReaperThemeZip
  [www] ReaClassical_remote.html
  *.ini
  lib/*.lua
  *.png
  ReaClassical-*.html
@about
  These functions, along with the included custom project template and theme, provide everything you need for professional classical music editing, mixing and mastering in REAPER.

