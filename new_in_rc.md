# New in ReaClassical 26

## Long-Term Support Release

ReaClassical 26 is what you might call a "long-term support" release. On official release, there will be no new features for a year. This means there is no real need for a complicated update mechanism. In the event of bugfixes, you can run shift+U as before but it will simply update the functions without touching keymaps and other settings. 

## Remove almost all SWS dependencies

Most of the dependency on SWS has been removed from key ReaClassical functions. Only a few necessary ones remain.

## 2026 artwork

Lots of creative options here but I have decided to go with a blue sky style modified from https://pixabay.com/illustrations/pink-orange-peach-scrapbook-design-794507/.  Simple and classy. 

## More xfade editor actions (including top and bottom lane auditioning)

When xfade editor is open, you can play just the top lane via E and bottom via C. A plays all. S plays just the left, and D plays just the right. Add shift modifier for A, S or D for variable playrate.

## Smart import audio

Bring your audio into the media subfolder and run the function to smartly import the audio matching track names, take number order and optional session name by folder or by adding generic named markers.

## Mission Control

Press C to open a dialog window to rename tracks, add track to all folders, delete tracks, reorder tracks, set inputs (automatically or manually), adjust pan/volume, set routing, add “special” tracks etc. Automatically opens when setting up a new project via Ctrl+N. This is the official way to do any and all track manipulation and a gateway to all sorts of other ReaClassical functions. 

## Source audition marker system

Press the source audition button in Mission Control or  Z to enter source audition marker mode. Use the mouse to set razor selections and press Z again to set some source audition markers. Use the dedicated source audition marker manager to audition, add ranking, type notes and delete marker pairs. You can re-order the table by timeline, marker name or ranking. Once happy, click on one of the convert icons to convert those markers to a real source IN/OUT pair. You can also delete all markers at once and abandon the mode by clicking the dedicated button.

## Remove empty items before prepare takes

Automatically happens as part of pressing T.

## Live bounce track

A new option when adding special tracks via Mission Control. Automatically armed and records the live output from RCMASTER. 

## Remove all item fades

Shift+F to remove start and end fades from items. Ignores crossfades. Useful when you have recorded in 4GB chunks or similar and you need to adjoin after import to prevent short dips in the sound.

## Force prepare take run before first S-D edit

Just so everyone starts editing with the most robust item grouping (better than vanilla REAPER!). Press T to prepare takes before trying to do any S-D edit.

## Auto add generic album metadata by splitting final item (or using last unnamed item)

When you run Y to create CD markers, the function will automatically add some generic album metadata to an unnamed item in your album or failing any available, make an invisible split. As noted later, all DDP/album metadata is now added via the new reaimgui-based window.


## Set recording primary and secondary

An automatic occurrence as part of a new project setup. If you set a secondary recording path in Mission Control, it will record to it without the user having to open every track routing dialog.

## Force strict mixer order

When syncing, mix order will be rearranged if out of order.

## Allow finding takes via item name

Set this option in F5 preferences to find takes via the item name vs the more robust file name approach (useful if your original files were named randomly!).

## Graded color scheme

ReaClassical 26 boosts a standard, repeatable graded color scheme to help users know where their edits are coming from. Set the unedited items color to checked in F5 preferences if you want unedited material to be the default REAPER item color. 

## Find Source material

In addition to the graded color scheme, users can find source material by selecting an edit and pressing Ctrl+F. The source group is selected and source IN/OUT markers placed around the material.

## Edited items use source coloring whenever possible

Again, as part of the graded color scheme, if the user adds a new folder, the colors will be automatically adjusted so that whenever possible, edits match the source material folder color.

## Ensure correct order for destination and sources

Similar to the strict mix order, destination and source folders are automatically re-ordered whenever sync is run behind the scenes.

## Allow Promotion of any source folder to destination

Press Ctrl+Alt+P to promote any source folder to be the destination.

## Heal edit

Select an edit and press Ctrl+H to heal the edit – it’s as if the edit never happened! This can be done at any time even if subsequent edits have occurred. This only works if there was underlying material (perfect for 4-point editing).

## Notes app

Press N to open a brand-new ReaClassical notes app for adding notes to the project, tracks or items. You can also add ranking and also override take numbering from filename (reset via the button).

## Allow xfade editing on any group

With the new REAPER xfade editor, I have removed the restriction on only being able to edit on the destination folder. 

## Allow S-D editing anywhere to anywhere

Set destination IN and OUT markers (1 and 2) in the same way as source IN and OUT. Select your folder first! Alternatively, set “Add S-D marker at mouse hover” to “1” and forego the initial folder selection. As the title says, this feature now allows for complete freedom on where you build your edits (although much can be said for continuing to stick with the destination folder!).

## DDP Metadata Editor

One of the "crown jewels" of the new release which automatically opens when Y (Create CD Markers) is run. A user-friendly approach to adding all necessary DDP metadata (and silently generating album reports, metadata reports and CUE files (for use with continuous WAV or FLAC export). See render presets for options. Reports and CUE file are written on close or when switching to another folder track. Note that each produced file starts with a prefix identifying it with the folder.

## Multi-Disc Albums

With combined power of the new DDP metadata editor and S-D editing from anywhere to anywhere comes the ability to produce multi-disc albums! Add track names to any folder track and press Y. Quickly jump from one disc to another by simply selecting another folder track you have set up with item names.

## Meterbridge

Press B to visualize recording levels by peak hold or vertical meter. When rec-armed, the display shows numbered channels. When auditioning, the display shows mixer tracks and any other “special” tracks.

## Microphone Indicator

Alt+R. A great way for conductors and performers to check the recording status on a monitor in the venue. Offline (grey), standby (green, rec-armed), recording (red) and paused (yellow) modes.

## ReaVision Metering Suite

A new entry to the RCPlugs JSFX collection. All the metering you could want in a single window – loudness and true peak read-outs (reset by clicking on any of the numbers), K-meter (cycle through K-20, K-14 and K-12), goniometer (with visual boosts by clicking on the label), phase correlation, bit meter, spectrum analyzer and spectrogram!

## CD Marker Offsets

For situations where, for example, a string soloist might accidentally touch a string just before the down beat in an otherwise stellar capture, this allows you to offset the CD marker – perfect when you have some recorded or generated room tone on the dedicated room tone track. To offset one or more markers, select the folder associated with the markers, move the maker(s) to where you want (audition so it feels musical!) and then press Shift+O. Offset values are added to the item name and are relative to the item starts so that the placement is always repeatable. Press Alt+O to remove all offsets.

## Record Panel (formerly Take Counter)

Open via Ctrl+Enter or F9. The take counter has been upgraded to include transport buttons and take ranking and notes. The ranking and notes are applied to the item created when recording is stopped.

## Mixer Snapshots Manager

Shift+M. The very latest addition to ReaClassical 26. Mixer scenes for humans! Set snaphots on named items (aka album track starts) with auto recall during playback and changing edit cursor position during transport stop. 4 independent banks with copy between functionality. Disable auto-recall to turn the manager into a simple manual recall by clicking on a table row.

## Quick and Easy Volume Automation

I. Add quick volume automation with optional ramps at edit cursor or within time selection. 

Plus many more small fixes/improvements...

See https://github.com/chmaha/ReaClassical/commits/main/ for the entire commit history…
