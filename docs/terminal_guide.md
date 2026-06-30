# ReaClassical Terminal — Complete Command Guide

The Terminal is a single text-entry dialog (run the "ReaClassical Terminal" script/action) that lets you type one or more ReaClassical commands instead of using the mouse or ImGui windows. It is built for screen-reader use: every command speaks a confirmation through OSARA (or prints to the console if OSARA isn't installed).

## How to use the Terminal

- Run the script. A single-line input box appears: "Command:".
- Type a command and press Enter.
- You can run several commands in one go by separating them with a semicolon: `1m;2m;3s` mutes tracks 1 and 2 and solos track 3.
- Commands are case-sensitive and must match the patterns below exactly (no extra spaces inside tokens, though spaces around commas/dashes in lists are tolerated, e.g. `1, 3` and `1 - 3` both work).
- The very first command in a brand-new project must be a project-setup command (`Nv`, `Nh`, `newtab`, `update`, `installosara`, or `updatereaper`) — everything else requires an existing ReaClassical project.
- Type `help` to open this guide (published as HTML at https://reaclassical.org/rcterminal.html) in your default browser. (Separately, the `H` keyboard shortcut normally opens the full ReaClassical PDF manual, but switches to the HTML version at reaclassical.org/manual when OSARA is installed, since HTML reads far better with a screen reader than a PDF.)
- Type `!` on its own to repeat whatever command(s) you last ran. The "ReaClassical Repeat Last Terminal Command" reascript does the same thing from a keyboard shortcut without opening the Terminal dialog at all. One-shot setup/destructive commands aren't remembered for this — `Nv`/`Nh`, `newtab`, `help`, `factoryreset`, `installosara`, `update`, and `updatereaper`/`updatereaper=...` are never saved as the repeat target, so `!` always falls back to the last "real" command instead.

### Target syntax used throughout

Many commands take a `<target>` — this is resolved consistently everywhere:
- A plain number `N` = mixer track N (e.g. `3`).
- A list: `1,3` / `4-6` / `1,4-6` / `*` (all mixer tracks).
- `@N` = aux track N; `@` alone = the only aux track (if there's exactly one); `@1,2` / `@*` etc. for lists of auxes.
- `#N` = submix track N; same rules as aux but with `#`.
- `rcm` = the RCMASTER track.
- `refN` = reference track N; `ref` alone = the only reference track (if there's exactly one); `ref1,2` for a list of references. Note: dash ranges (`ref1-3`) aren't supported — use a comma list instead.
- `rt` = the RoomTone track.
- `live` = the LIVE track.
- `lb` = the Listenback track.

### Command shape: when the target leads, when the verb leads

Once you know which of these three shapes a command uses, you can usually guess its name:

- **`<target><keyword>[=value]`** — the most common shape, for a setting a track already has: mute (`m`/`um`), solo (`s`/`us`), exclusive solo (`xs`), pan (`p`), fader (`f`), polarity (`i`), peak (`pk`, read-only), record-arm/input, the full `<target>?` summary, and the FX sub-resource commands (`fx=`, `fx?`, `r?`, `rmfx=`, `mvfx=`, `fxon=`/`fxoff=`). The target leads because you're naming *whose* setting you're reading or changing — the same way you'd say "track 1's pan" before describing it.
- **`<verb><target...>`** — for actions that create, remove, or relocate a track itself, rather than adjusting one of its settings: `add`/`add@`/`add#`/`addlb=`/`addlive`/`addpb=`, `rmN`/`rm@N`/`rm#N`/`rmrefN`/`rmrt`/`rmlb`/`rmlive`/`rmpb`, `mvNu`/`mvNd`. There's no existing target-slot to lead with in the same sense here — the verb names the structural change up front.
- **`<target>=value`** (no keyword at all) — for configuring a slot that already exists, where the value itself says what's being configured: `N=mono`/`N=stereo` (input format), `N=y`/`N=n` (record-arm). No verb is needed because assigning into an existing slot is the unmarked default action — the same reasoning lets `1fx=ReaEQ` add an FX without needing a separate `addfx=`.

Removing or moving an existing **FX** sits at the boundary of the first two: FX live inside a track's chain, so the target still has to lead (to say whose chain), but the action verb (`rm`, `mv`) leads the noun within that — `1rmfx=2`, not `1fxrm=2`.

### Query naming convention

Any `<target>?`-style query (mute/solo/polarity/pan/fader/peak/record-input state) speaks just the value when it resolves to a single track — you already know which one you asked about. If the target expands to several tracks (a list, range, or `*`), each line is prefixed with that track's name so you can tell the results apart, e.g. `1m?` → `"mute: on"`, but `1,3m?` → `"Mixer track Violin mute: on"` / `"Mixer track Cello mute: off"`.

### Folder/position syntax (vertical/horizontal workflows)

- `D` = the Destination folder; `S1`, `S2`, … = Source folders.
- Within a folder, a position is `1` (the folder/parent track itself) or `2`, `3`, … (its child tracks, matching mixer-track position order).

---

## 1. Project Setup

| Command | Effect |
|---|---|
| `Nv` | Start a brand-new project using the **Vertical** workflow with N tracks per folder, e.g. `8v`. If a ReaClassical project is already open, you'll be asked to save first. N must be at least 2 (each folder needs a minimum of 2 tracks) — `1v` announces an error instead of silently doing nothing. |
| `Nv=Name1,Name2,...` | Same as `Nv`, also naming each mixer track in one step, e.g. `2v=Violin,Cello`. |
| `Nh` | Start a brand-new project using the **Horizontal** workflow with N tracks, e.g. `4h`. Same N ≥ 2 minimum as `Nv`. |
| `Nh=Name1,Name2,...` | Same as `Nh`, also naming each mixer track in one step, e.g. `2h=Violin,Cello`. |
| `convert=h` | Convert the current (vertical) project to Horizontal workflow. |
| `convert=v` | Convert the current (horizontal) project to Vertical workflow. |

Typical first step in any session: `6v` (six mixer tracks, vertical/classical session workflow) or `4h=Violin,Viola,Cello,Bass` (horizontal/quick setup with names).

### Other examples

- `6v` — Start a new Vertical-workflow project with 6 mixer tracks per folder. Use this for a multi-take classical recording session.
- `6v=Violin,Viola,Cello,Bass,Horn,Oboe` — Same, also naming all 6 mixer tracks in one step.
- `6h` — Start a new Horizontal-workflow project with 6 tracks, left unnamed for now.
- `4h=Violin,Viola,Cello,Bass` — Start a new Horizontal-workflow project with 4 named tracks in one step. Good for a quick quartet setup where every take lives on the same 4 tracks.
- `convert=v` — You started in Horizontal (quick setup) but the session turned into a multi-take recording project, so you switch to Vertical without losing existing work.

---

## 2. Naming Tracks, Items, and Notes

| Command | Effect |
|---|---|
| `n=Name1,Name2,...` | Rename mixer tracks 1, 2, 3… in order, all at once, e.g. `n=Oboe,Clarinet,Bassoon`. |
| `Nn=Name` | Rename only mixer track N, e.g. `3n=Cello`. |
| `#Nn=Name` (or `#n=Name` if only one submix) | Rename submix N, e.g. `#2n=Strings`. |
| `@Nn=Name` (or `@n=Name` if only one aux) | Rename aux N, e.g. `@1n=Reverb`. |
| `refNn=Name` | Rename reference track N, e.g. `ref1n=Conductor Mix`. |
| `pn?` | Speak the project notes. |
| `pn=text` | Set the project notes, e.g. `pn=Hall is dry, consider close mics`. |
| `tn?` | Speak notes on the currently selected track. |
| `tn=text` | Set notes on the currently selected track, e.g. `tn=Slight room rumble at the start`. |
| `in=Title` | Rename the active take of the selected item (no comma — for plain renames; see DDP section for comma form), e.g. `in=Allegro`. |
| `ino?` | Speak the selected item's notes. |
| `ino=text` | Set the selected item's notes, e.g. `ino=Slight breath noise at 0:42`. |
| `ir?` | Speak the selected item's rank (Excellent/Very Good/Good/OK/Below Average/Poor/Unusable/False Start/None). |
| `ir=letter` | Set the item's rank: `e`=Excellent, `v`=Very Good, `g`=Good, `o`=OK, `b`=Below Average, `p`=Poor, `u`=Unusable, `f`=False Start, `n`=None, e.g. `ir=v`. |
| `itn?` | Speak the selected item's take number. |
| `itn=N` | Set the selected item's take number (`itn=0` clears it), e.g. `itn=3`. |

### Other examples

- `n=Violin,Viola,Cello,Bass` — Rename all four mixer tracks in one command right after project setup.
- `3n=2nd Violin` — You realize track 3 should say "2nd Violin" instead of whatever it's currently called; rename just that one.
- `ir=g` — Mark the take you just listened to as "Good".
- `ir?` — Before deciding whether to keep recording, check the rank already assigned to the selected take.
- `tn=Close mic clipped at bar 12, used room mic instead` — Leave a note on a track explaining an editorial decision for future reference.

---

## 3. Recording Setup — Inputs

| Command | Effect |
|---|---|
| `N=mono,X` | Set the track at position N in every folder to mono, recording from hardware input X, e.g. `1=mono,3`. X is always required — there's no bare `N=mono` form; use `ai`/`ai=N` (below) for automatic placement. Fails with "There are only Y tracks per folder" if position N doesn't exist (e.g. only 2 tracks per folder and you ask for position 3). |
| `N=stereo,X` | Set the track at position N in every folder to a stereo pair starting at hardware input X, e.g. `2=stereo,7`. X is always required, same reasoning as `N=mono,X`. Same position-N-must-exist check. |
| `N=y` / `N=n` | Disable / enable record-arming for mixer track N, e.g. `3=y`. Joins the same bare `<target>=value` family as `N=mono`/`N=stereo` above, rather than a separate `rd=` keyword. |
| `*=y` / `*=n` | Disable / enable record-arming for **all** mixer tracks, e.g. `*=y`. |
| `<target>input?` | Speak the input (mono/stereo) then record-enabled state for one or more mixer tracks, e.g. `2input?`. Needs the explicit noun (unlike the bare `=y`/`=n` setter) since a query has no value to infer meaning from. Always needs a numeric/list target prefix — bare `in?` with no prefix is the unrelated CD-metadata query, see §10. |
| `ai` | Auto-assign inputs starting at hardware input 1, guessing mono/stereo and L/R pan from track names (recognizes "L"/"R"/"stereo"/"pair" in many languages). |
| `ai=N` | Auto-assign inputs starting at hardware input N, e.g. `ai=9`. |

### Other examples

- `ai` — Your interface's inputs are plugged in order matching your track order; auto-assign everything starting at input 1 instead of configuring each track by hand.
- `ai=5` — The first 4 hardware inputs are already used by another rig; auto-assign all tracks starting at input 5 instead.
- `1=stereo,3` — Track 1 ("Main Pair") should record a stereo pair starting at hardware inputs 3/4.
- `2=mono,5` — Track 2 ("Spot Mic") is a single mic plugged into hardware input 5.
- `*=n` — Before a playback-only rehearsal pass, disable record-arming on every track so nothing accidentally records.
- `1input?` — Confirm what input track 1 is listening to and whether it's actually armed before you start a take.
- `1-3input?` — Same check across the first three tracks at once.

---

## 4. Recording — Transport & Takes (Record Panel)

F9 (the Classical Take Record reascript) still works as a single toggle button: first press arms the selected folder, second press starts recording, and pressing it again while recording stops the take — no change there. `rec.arm` and `rec.start` give the Terminal the same two steps with precision instead of a toggle: each only ever does its own job, and announces the current state ("Already armed for take 6", "Already recording", "Not armed yet") rather than silently doing nothing or the wrong thing. If OSARA is installed, F9 also starts the headless Record Panel daemon itself (the same daemon-start step as `rec.open`) the first time it's pressed and the daemon isn't already running, so you get its background take/level tracking even if you jump straight to F9 without ever running `rec.open`. `rec.arm` and `rec.start` do the same daemon auto-start regardless of whether OSARA is installed, since they're explicitly the precision/headless entry points into recording.

| Command | Effect |
|---|---|
| `rec.open` | Start the headless Record Panel daemon and arm the selected folder (first F9 press equivalent). |
| `rec.close` | Stop the Record Panel daemon. |
| `rec.arm` | Arm the selected folder without starting recording, announcing the upcoming take number (e.g. "Armed for take 6"). If it's already armed (or already recording), just announces that instead of changing anything. |
| `rec.start` | Start recording on the already-armed folder. If nothing is armed yet (or already recording), just announces that instead of arming it for you — run `rec.arm` first. |
| `rec.stop` | Press F9 to stop the current recording, announcing the take number that was just recorded (e.g. "Stopped recording take 6"). In Vertical workflow, also announces which folder is now armed (e.g. "Stopped recording take 6. Source 4 folder armed") — F9 itself announces the same thing when used to stop. |
| `rec.pause` | Toggle pause/resume while recording. The Record Panel daemon announces "Paused recording take 6" / "Recording take 6" on its own a moment later, regardless of whether pause was triggered here, by the Record Panel's button, or by its keyboard shortcut. |
| `rec.next` | Move to the next recording section (Vertical workflow only; must be stopped first). |
| `rec.split` | Stop and immediately start a new take (Shift+F9 equivalent — increments take number / moves to next folder). |
| `rec.daemon?` | Report whether the Record Panel daemon is running. |
| `rec?` | Speak a full summary of all recording settings (session, take, time window, overlap, horizontal, clip reporting, daemon status). |
| `rec.session=name` | Set the session name (scans disk for the correct next take number), e.g. `rec.session=Beethoven9`. |
| `rec.session?` | Speak the current session name. |
| `rec.rmsession` | Clear the session name. |
| `rec.take=N` | Manually set the upcoming take number (rejected if lower than the highest take already on disk), e.g. `rec.take=12`. |
| `rec.take=auto` | Revert to automatic take-number detection. |
| `rec.take?` | Speak the upcoming take number and whether it's manual or auto. |
| `rec.latest?` | Scan disk and report the highest take number actually found (for the current session). |
| `rec.inctake` | Manually increment the take number by 1. |
| `rec.rank=letter` | Set the rank (same letters as `ir=`) for the take currently recording (or the last one, if stopped), e.g. `rec.rank=e`. |
| `rec.note=text` | Set notes for the take currently recording (or the last one, if stopped), e.g. `rec.note=Slight breath noise`. |
| `rec.start=HH:MM` | Set a scheduled recording start time, e.g. `rec.start=19:30`. |
| `rec.start?` | Speak the scheduled start time. |
| `rec.end=HH:MM` | Set a scheduled recording end time, e.g. `rec.end=21:00`. |
| `rec.end?` | Speak the scheduled end time. |
| `rec.duration=HH:MM` | Set a target recording duration, e.g. `rec.duration=01:30`. |
| `rec.duration?` | Speak the target duration. |
| `rec.rmtime` | Clear start/end/duration all at once. |
| `rec.overlap=y` / `=n` | Allow / disallow overlapping takes. |
| `rec.overlap?` | Query the overlap setting. |
| `rec.horizontal=y` / `=n` | Record takes horizontally even in a Vertical-workflow project. |
| `rec.horizontal?` | Query that setting. |
| `rec.clip=y` / `=n` | Turn OSARA clip (overload) announcements on/off for rec-armed tracks. |
| `rec.clip?` | Query the clip-reporting setting. |
| `rec.levels?` | Speak the current peak-hold level (dB) for every rec-armed track. |
| `rec.rmlevels` | Clear all peak/RMS hold values. |
| `td=on` | Open the take-number companion display — a small gfx window showing the current take number colour-coded by transport state (green: stopped/playing; red: recording; yellow: paused-recording), for a sighted engineer co-present with the blind user. Closed automatically when `rec.close` is called. (Note: bare `td` with no suffix is the album-track-down command in §10.) |
| `td=off` | Close the companion display manually. |

### Other examples

- `rec.open` — At the start of a session, open the Record Panel daemon and arm the selected folder, ready to go.
- `rec.session=MahlerSym5_Mvt1` — Name the session so every take is filed and numbered consistently on disk.
- `rec.arm` — Get the folder armed and confirmed (e.g. "Armed: Source 2") before telling a performer you're ready.
- `rec.start` — Once armed, start the take precisely on cue.
- `rec.split` — Mid-take, the conductor stops and restarts; split here instead of stopping and re-arming manually so the next take number increments automatically.
- `rec.rank=g` — Right after a take finishes, rank it "Good" without leaving the Terminal.
- `rec.stop` — End the recording.
- `rec.levels?` — Between takes, check whether any mic clipped by reviewing the peak hold on every armed track.

---

## 5. Importing Audio

| Command | Effect |
|---|---|
| `import` | Smart Import: scan the project media folder for new audio files and import them, one folder per take. |
| `import=dest` | Same, but also duplicate each session's takes onto the Destination folder. |
| `import=smart,1` | Same as plain `import` (one folder per take). |
| `import=smart,2` | Round-robin distribute new takes across the current number of source folders. |
| `import=smart,3,N` | Round-robin distribute across N folders (creating folders as needed), e.g. `import=smart,3,4`. |
| Add `,dest` to any of the above | Also includes the Destination folder in the distribution, e.g. `import=smart,2,dest`. |
| `import=N` | Import only take number N, placed at the edit cursor, e.g. `import=20`. |
| `import=N,session` | Same, restricted to the named session, e.g. `import=20,Beethoven9`. |
| `import=N-M` | Import takes N through M, e.g. `import=3-5`. |
| `import=N-M,session` | Same, restricted to the named session, e.g. `import=3-5,Beethoven9`. |
| `find=N` | Locate take N on disk (default/most-recent session) and report it, e.g. `find=20`. |
| `find=N,session` | Locate take N within a named session, e.g. `find=20,Beethoven9`. |
| `find=,session` | Locate take 1 within a named session, e.g. `find=,Beethoven9`. |

### Other examples

- `import` — You recorded several takes that landed in the project media folder; pull them all in, one folder per take.
- `import=smart,2,dest` — Distribute newly recorded takes round-robin across your existing source folders, and also copy them onto the Destination folder for comping.
- `import=12,MahlerSym5_Mvt1` — Only take 12 from the "MahlerSym5_Mvt1" session is missing from the timeline; import just that one at the edit cursor.
- `find=7` — You remember take 7 sounded great but can't recall which folder it landed in; locate it.

---

## 6. Selection

| Command | Effect |
|---|---|
| `sel?` | Speak the currently selected tracks and items. |
| `time?` | Speak the current edit-cursor position. |
| `sel=D,positions` | Exclusively select track(s) at the given position(s) within folder D (Destination), e.g. `sel=D,2,3`. Positions: `1` (folder track), `2`,`3`,… (children), or a list/range/`*`. |
| `sel=S1,positions` | Same, for Source folder 1 (and `S2`, `S3`… for further source folders), e.g. `sel=S1,2`. |
| `sel=+D,positions` | **Add** to the current selection instead of replacing it, e.g. `sel=+D,1`. |
| `sel=positions` / `sel=+positions` | Folder-less shorthand — only works in **Horizontal** workflow (which has exactly one folder), e.g. `sel=2,4`. |
| `tr=text` | Jump to (select) the first track in the **current** folder — the one containing the currently selected track — whose name contains `text` (case-insensitive), e.g. `tr=violin`. Expands a collapsed folder first if needed. |

### Other examples

- `sel=D,*` — Select every track in the Destination folder before running `prepare` or applying automation to the whole comp.
- `sel=S2,3` — Select just the cello track (position 3) within Source folder 2, to check that specific take.
- `sel=+S1,1` — Add Source folder 1's parent track to whatever's already selected, so you can compare two takes' folder tracks together.
- `sel=1,3` — In a Horizontal-workflow project (one folder, so the folder prefix can be dropped), select tracks 1 and 3 directly.
- `sel?` — After clicking around, confirm exactly what's currently selected before running a destructive command like `rmauto`.
- `tr=cello` — From anywhere in the current folder, jump straight to the track named "Cello" without counting positions.

---

## 7. Editing Tools

### Markers & regions
| Command | Effect |
|---|---|
| `mk=Name` | Add a marker named "Name" at the edit cursor, e.g. `mk=Coda`. |
| `mk?` | Speak the name and position of the nearest marker at-or-before the cursor. |
| `rg=NameA,NameB` | Create a region spanning from marker "NameA" to marker "NameB", e.g. `rg=Coda,End`. |

### Undo / redo
| Command | Effect |
|---|---|
| `z` / `Nz` | Undo one step / N steps, e.g. `5z`. |
| `y` / `Ny` | Redo one step / N steps, e.g. `5y`. |

### Reordering mixer tracks
| Command | Effect |
|---|---|
| `mvNu` | Move mixer track N up one position, e.g. `mv3u`. |
| `mvNuC` | Move mixer track N up C positions, e.g. `mv4u3`. |
| `mvNd` / `mvNdC` | Move mixer track N down one / C positions, e.g. `mv3d` / `mv4d3`. |
| `mv<positions>u` / `mv<positions>uC` | Move a **contiguous block** of mixer tracks up one / C positions, keeping their relative order — `positions` is a list/range like `6,7` or `1-3`, e.g. `mv4,5u2`. |
| `mv<positions>d` / `mv<positions>dC` | Same, moving the block down, e.g. `mv2-4d`. |

### Adding / removing tracks
| Command | Effect |
|---|---|
| `add` | Add a new mixer track (and matching child track in every folder), named "Track N". |
| `add=Name` | Same, with a chosen name, e.g. `add=Conductor Mic`. |
| `rmN` | Remove mixer track N (and its counterpart in every folder), e.g. `rm7`. Won't go below the minimum 2-track folder size. |
| `add@` | Add a new aux track. |
| `add@=Name` | Same, with a chosen name, e.g. `add@=Reverb`. |
| `add#` | Add a new submix track. |
| `add#=Name` | Same, with a chosen name, e.g. `add#=Strings`. |
| `rm@N` (or `rm@`) | Remove aux track N (or the only aux track), e.g. `rm@2`. |
| `rm#N` (or `rm#`) | Remove submix track N (or the only submix track), e.g. `rm#1`. |
| `addlb=N` | Add a Listenback (cue/foldback) track armed on hardware input N — or just retune the input if one already exists, e.g. `addlb=7`. |
| `rmlb` | Remove the Listenback track. |
| `rmrefN` (or `rmref`) | Remove reference track N (or the only one), e.g. `rmref2`. |
| `rmrt` | Remove the RoomTone track. |
| `addlive` | Add a LIVE bounce track (receives from RCMASTER, output-record mode). Only one allowed per project. |
| `rmlive` | Remove the LIVE track. |
| `addpb=N` | Add a PLAYBACK track routed from RCMASTER to hardware stereo pair starting at output N (1-based), or retune its output if it already exists. Default muted. |
| `rmpb` | Remove the PLAYBACK track. |

### Playback rate & pitch (selected item)
| Command | Effect |
|---|---|
| `pr=N` | Change the selected item's playback rate by N% relative to its current rate (timestretch; ripples subsequent items in the folder), e.g. `pr=3`. |
| `pr=a,N` | Set an absolute rate change of N% from normal speed, e.g. `pr=a,98`. |
| `pr=0` | Reset playback rate to normal. |
| `pr?` | Speak the current playback rate. |
| `pt=N` | Set pitch to N semitones (`pt=0` resets to normal), e.g. `pt=-2`. |
| `pt?` | Speak the current pitch. |

### Prepare Takes
| Command | Effect |
|---|---|
| `prepare` | Run "Prepare Takes" headlessly over all items in the project. |

### Other examples

- `mk=Movement II Start` — Drop a marker at the cursor so you can navigate straight back to this spot later.
- `rg=Movement II Start,Movement II End` — Turn two markers you've already placed into a region, e.g. for looping playback over that movement.
- `z` — Undo the last action; `3z` undoes the last three in one go.
- `mv3u2` — Mixer track 3 ("Cello") should sit two slots higher in the mixer order (e.g. above the violins); move it up 2 positions.
- `mv6,7u2` / `mv1-3d` — Move the cello+bass pair (mixer tracks 6 and 7) up two slots together, or shift the violins block (1-3) down one slot, without breaking up their order.
- `add=Room Mic L` — A room mic pair wasn't part of the original setup; add a new mixer track (and matching child track in every folder) for it.
- `rm5` — Track 5 turned out to be unused; remove it from every folder and the mixer.
- `pr=-5` — The selected take is a hair too fast compared to the other takes you're comping against; slow it by 5% to match.
- `pt=0` — Reset a pitch-shifted item back to normal after an experiment.
- `prepare` — Once all takes for the piece are imported and ranked, run Prepare Takes to get them into editable shape.

---

## 8. Mixing

### Mute / solo
| Command | Effect |
|---|---|
| `<target>m` | Mute the target(s), e.g. `2m`. |
| `<target>um` | Unmute, e.g. `2um`. |
| `<target>s` | Solo (in addition to anything already soloed), e.g. `3s`. |
| `<target>us` | Unsolo, e.g. `3us`. |
| `<target>xs` | **Exclusive** solo: clears mute/solo on every mixer track first, then solos only the given target(s), e.g. `5xs`. |
| `<target>m?` | Speak mute state, e.g. `2m?`. |
| `<target>s?` | Speak solo state, e.g. `3s?`. |

### Pan
| Command | Effect |
|---|---|
| `<target>p+N` / `<target>p-N` | Nudge pan by N percentage points toward right/left, e.g. `3p-10`. |
| `<target>p=N` | Set pan to an absolute percent, -100 (full left) to +100 (full right), e.g. `2p=15`. |
| `<target>p?` | Speak current pan (e.g. "25L", "C", "10R"), e.g. `2p?`. |

### Fader (volume)
| Command | Effect |
|---|---|
| `<target>f+N` / `<target>f-N` | Nudge volume by N dB, e.g. `3f-1`. |
| `<target>f=N` | Set volume to an absolute N dB, e.g. `4f=-6`. |
| `<target>f?` | Speak current volume in dB, e.g. `2f?`. |

### Peak
| Command | Effect |
|---|---|
| `<target>pk?` | Speak the peak hold level (dB, or "silence") for one or more tracks, e.g. `4pk?`. Read-only — there's no setter, only the query. |

### Polarity / phase
| Command | Effect |
|---|---|
| `<target>i=y` | Invert polarity, e.g. `2i=y`. |
| `<target>i=n` | Normal polarity, e.g. `2i=n`. |
| `<target>i?` | Speak polarity state, e.g. `2i?`. |

### Full single-track summary
| Command | Effect |
|---|---|
| `N?` / `@N?` / `#N?` / `rcm?` / `refN?` / `rt?` / `live?` / `lb?` | Speak a complete property-by-property report for one track — mute, solo, fader, pan, phase, peak, (record input, for mixer tracks), routing chain to RCMASTER, and FX chain — with no track-name header (see "Query naming convention" above), e.g. `2?`. |
| `<ref>r?` | Speak just the routing-to-RCMASTER line from that summary, for any single target, e.g. `4r?`. RCMASTER itself (`rcmr?`) reports that it's the mix bus terminus instead of a routing chain. |
| `<ref>fx?` | Speak just the FX-chain lines from that summary, for any single target, e.g. `2fx?` — including whether the whole chain is bypassed (`track FX: enabled`/`disabled`, REAPER's master per-track FX bypass) ahead of each individual FX's own on/off state. |

### Routing
| Command | Effect |
|---|---|
| `<list>-rcm` | Connect the given mixer track(s) (or `ref`/`ref<list>`) to RCMASTER, e.g. `4-6-rcm`. |
| `<list>/rcm` | Disconnect the given mixer track(s) (or `ref`/`ref<list>`) from RCMASTER, e.g. `4-6/rcm`. |
| `<ref>-rcm?` | Query whether a single target (including `refN`, `rt`, `live`, `lb`) is connected to RCMASTER, e.g. `1-rcm?`. |
| `*/*#` | Remove all sends from every mixer track to every submix. |
| `*/*@` | Remove all sends from every mixer track to every aux. |
| `A-B` | Create a send from target A to target B (any two single targets — mixer/aux/submix/rcm/refN/rt/live/lb), e.g. `2-@1`. |
| `A/B` | Remove the send from A to B, e.g. `2/@1`. |

### FX
An existing FX on a target's chain is selected by `selector`: either its 1-based chain position (`2`), or a case-insensitive substring of its name (`eq` matches "ReaEQ") — whichever the selector parses as. The first match wins for name substrings.

All of these commands take a single target only (no lists/ranges/`*`), so — like the single-track query forms above — their spoken confirmation doesn't repeat the track name back to you: `1fx=ReaEQ` says `"FX added: ReaEQ"`, not `"FX added to Mixer track Violin: ReaEQ"`.

| Command | Effect |
|---|---|
| `<ref>fx=PluginName` | Add an FX plugin by name to a single target (mixer/aux/submix/rcm/refN/rt/live/lb), appended at the end of the chain, e.g. `2fx=ReaComp`. |
| `<ref>fx=PluginName,N` | Same, but move the new FX to chain position N, e.g. `2fx=ReaVerb,1`. |
| `<ref>rmfx=selector` | Remove an existing FX from the chain, e.g. `2rmfx=3`. |
| `<ref>mvfx=selector,N` | Move an existing FX directly to chain position N (clamped in-range), e.g. `2mvfx=1,3`. N is required. |
| `<ref>fxon=selector` | Enable (un-bypass) an existing FX without removing it from the chain, e.g. `2fxon=3`. |
| `<ref>fxoff=selector` | Disable (bypass) an existing FX without removing it from the chain, e.g. `2fxoff=3`. |
| `<ref>fxon` (no `=selector`) | Enable the **entire** FX chain at once (REAPER's master per-track bypass, the same as the bypass button at the top of the FX chain window) — leaves every individual FX's own on/off state untouched, e.g. `2fxon`. |
| `<ref>fxoff` (no `=selector`) | Disable (bypass) the entire FX chain at once, same scope as `<ref>fxon`, e.g. `2fxoff`. |

### Automation (envelopes)
Requires a time selection and at least one selected track.

| Command | Effect |
|---|---|
| `addauto=param,value` | Write automation for `param` (one of `vol`,`pan`,`width`,`mute`,`trimvol`,`prevol`,`prepan`,`prewidth`) to `value` across the time selection, on all selected tracks, e.g. `addauto=vol,-3`. `value` is dB for volume-type params, -1..1 for pan/width, 0/1 for mute. |
| `addauto=param,value,rampIn` | Same, with a ramp-in of `rampIn` seconds before the selection, e.g. `addauto=vol,-3,1`. |
| `addauto=param,value,rampIn,rampOut` | Same, plus a ramp-out after the selection, e.g. `addauto=vol,-3,1,1`. |
| `addautoitem=...` | Same arguments as `addauto=`, but wraps the change in an automation **item** (movable/resizable as a unit) instead of plain points, e.g. `addautoitem=vol,-3,1,1`. |
| `rmauto` | Delete ALL built-in automation (points and items) on selected tracks within the time selection (including any ramps from the most recent `addauto`/`addautoitem` on that exact selection). |
| `rmauto=param` (or `param1,param2,...`) | Delete only the named envelope(s), e.g. `rmauto=pan`. |
| `rmauto=*` | Same as bare `rmauto`. |

### Other examples

- `1m`, `1,3m`, `4-6m`, `*m`, `@1m`, `#m`, `refm`, `rtm`, `livem`, `lbm`, `rcmm` — every flavor of target syntax works the same way for mute (and equally for solo/pan/fader/polarity/peak): a single mixer track, a comma list, a range, all mixer tracks, an aux, a submix, the only reference/RoomTone/LIVE/Listenback track, and RCMASTER.
- `1,3m` — Mute the first violin and cello sections to check what the rest of the ensemble sounds like alone.
- `4-6xs` — Exclusive-solo the back-row tracks (4 through 6), clearing any other mute/solo state first, to spot-check that section in isolation.
- `1p+10` — Nudge the first violins 10% further right, a small adjustment relative to wherever they're already panned.
- `1p=-30` — Pan the first violins to an absolute 30% left, regardless of where they were panned before, to widen the stereo image.
- `rcmp=0` — Recenter RCMASTER's pan after an experiment.
- `2f+2` — Nudge the second violins up 2 dB, a small relative adjustment.
- `2f=-2.5` — Pull the second violins down to an absolute -2.5 dB relative to the rest of the mix.
- `rcmf?` — Check RCMASTER's current fader level before deciding whether to trim it.
- `1i=y` — Invert polarity on track 1 because it's out of phase with a spot mic.
- `1i=n` — Revert it back to normal polarity once the phase issue is fixed elsewhere.
- `1pk?` — Check track 1's peak hold level after a take, without opening Meterbridge.
- `1?` — Get a full spoken status report (mute/solo/fader/pan/phase/peak/routing/FX) on track 1 before deciding what to change.
- `3r?` — Just confirm where track 3 is routed to, without the rest of the full `3?` report.
- `1fx?` — Just check track 1's FX chain, without the rest of the full `1?` report.
- `1-3-rcm` — Connect the first three tracks to RCMASTER in one go after adding them, since new tracks aren't routed there automatically.
- `1-rcm` — Same, for a single newly-added track.
- `1-@1` — Send track 1 to aux 1 (e.g. a reverb bus) without otherwise altering its routing to RCMASTER.
- `*/*@` — Strip every mixer track's send to the auxes in one shot, e.g. before rebuilding a reverb bus from scratch.
- `1fx=ReaEQ` — Add an EQ plugin to track 1.
- `rcmfx=ReaComp,1` — Add a compressor to RCMASTER and place it first in the chain (e.g. ahead of an existing limiter).
- `1rmfx=2` — Pull the 2nd FX off track 1's chain by its chain position.
- `1rmfx=eq` — Same, but selecting it by name instead — pull the EQ off track 1's chain after deciding it isn't needed.
- `1mvfx=3,2` — Move the 3rd FX on track 1 to position 2, e.g. so it runs before a compressor it was accidentally placed after.
- `rcmfxoff=2` — Temporarily bypass the 2nd FX on RCMASTER (e.g. a limiter) to A/B against the unlimited mix, without losing its settings.
- `rcmfxon=2` — Switch it back on afterward.
- `1fxoff` — Bypass every plugin on track 1's chain at once to hear the dry signal, without losing each plugin's individual settings or on/off state.
- `1fxon` — Bring the whole chain back in afterward.
- `addauto=vol,-6,2,2` — With a time selection over a too-loud passage, pull volume down 6 dB with 2-second ramps in and out.
- `rmauto=vol` — Remove just the volume automation you added over the current time selection, leaving pan/mute automation intact.

---

## 9. Mixer Snapshot Manager (headless)

Snapshots capture the full mixer state (volume/pan/mute/solo/phase/width/FX/sends/routing) tied to a specific media item, for instant recall during playback (e.g. switching mic perspective mid-take).

| Command | Effect |
|---|---|
| `snap.add` | Create (or update) a snapshot from the current mixer state, tied to the selected item. |
| `snap?` | List all snapshots in the current bank, in timeline order. |
| `snap.recall=N` | Recall snapshot N, e.g. `snap.recall=5`. |
| `snap.rm=N` | Delete snapshot N, e.g. `snap.rm=4`. |
| `snap.recall` (no `=N`) | Recall whichever snapshot matches the selected item (or, failing that, the edit cursor position). |
| `snap.rm` (no `=N`) | Delete all snapshots in the current bank — the whole-collection counterpart to `snap.rm=N`. |
| `snap.bank?` | Speak the active bank (A/B/C/D). |
| `snap.bank=X` | Switch the active bank, e.g. `snap.bank=B`. |
| `snap.copy=X` | Copy bank X's snapshots into the current bank, e.g. `snap.copy=B`. |
| `snap.ar?` | Query auto-recall (whether snapshots fire automatically during playback) for the current bank. |
| `snap.ar=y` / `=n` | Turn auto-recall on/off. |
| `snap.gapfolder?` | Show which folder is used for gap/mid-point detection in this bank. |
| `snap.gapfolder=all` / `=TrackName` | Set gap-detection scope to all tracks or one named folder, e.g. `snap.gapfolder=Destination`. |
| `snap.addauto` | Convert every snapshot in the current bank into real automation lanes. The daemon is no longer needed once automation is driving recall, so this also stops it if it's running. |
| `snap.rmauto` | Clear all automation previously created from snapshots. Recall now depends on the snapshots again, so this also starts the daemon if it isn't already running. |
| `snap.open` | Start the Mixer Snapshot daemon (needed for auto-recall during playback). |
| `snap.close` | Stop the daemon. |
| `snap.daemon?` | Report whether the daemon is running. |

### Other examples

- `snap.add` — With the selected item being a passage where you want to switch from the main pair to a spot mic balance, capture the current mixer state as a snapshot tied to that item.
- `snap.ar=y` then `snap.open` — Turn on auto-recall and start the daemon so snapshots fire automatically as playback crosses each tagged item.
- `snap?` — Before a playback run-through, review every snapshot you've created and where they land on the timeline.
- `snap.recall=3` — Manually jump to snapshot 3's mixer state without needing playback to reach it.
- `snap.addauto` — Once you're happy with how the snapshots sound, bake them into real automation lanes; the daemon stops automatically since the project no longer depends on it.
- `snap.rm=2` — Delete snapshot 2 because that perspective change is no longer needed.

---

## 10. Album / DDP / CD Metadata

| Command | Effect |
|---|---|
| `in?` | Speak the CD-marker / take metadata for the selected item. |
| `in=Title,pf=...,sw=...,cp=...,ar=...,msg=...,isrc=...` | Set CD-track metadata for the selected item: title, performer, songwriter, composer, arranger, message, ISRC, e.g. `in=Allegro,pf=Jane Smith`. Omit any field to leave it unchanged; set a field to `0` to clear it. |
| `album?` | Speak album-level metadata for the project. |
| `album=Title,cat=...,pf=...,sw=...,cp=...,ar=...,id=...,msg=...,lg=...` | Set album metadata: title, catalog number, performer, songwriter, composer, arranger, identification, message, language (must match a valid language name), e.g. `album=My Recital,cp=Bach`. |
| `createcd` | (Re)build CD/DDP markers for the selected folder track. |
| `digital=y` / `=n` | Toggle "Digital Release Only" mode (no pregap/frame-snap offsets, for streaming-only releases). |
| `digital?` | Query that setting. |
| `isrc=y` / `=n` | Toggle Manual ISRC Entry (on: enter every ISRC independently; off: auto-increment from the first track). |
| `isrc?` | Query that setting. |
| `addoffsets` | Record current CD marker positions as manual offsets (preserved on future `createcd` runs). |
| `rmoffsets` | Clear all manual marker offsets, reverting to automatic placement. |
| `offsets?` | Report whether manual offsets are active on the selected track. |
| `tu` / `td` | Move the selected album track up/down in running order (markers re-sync automatically). |
| `repos=N` | Reposition CD track groups on the selected folder, leaving N seconds of gap between each, e.g. `repos=3`. |
| `buildlist=source` | Build an HTML edit list using source-file timing. |
| `buildlist=bwf` | Build an HTML edit list using BWF (Broadcast Wave) start-offset timing. |

### Other examples

- `album=Beethoven Piano Sonatas,cp=Beethoven,pf=Jane Smith` — Set the album title, composer, and performer for the whole release before building CD markers.
- `in=Sonata No. 14 "Moonlight" I. Adagio,pf=Jane Smith,isrc=USS122600001` — Tag the selected track item with its title, performer, and ISRC code.
- `createcd` — After finishing edits on a folder, (re)build the CD/DDP markers so track boundaries reflect the current arrangement.
- `tu` — The selected album track should come earlier in the running order; nudge it up one slot.
- `repos=2` — Space out CD track groups with a 2-second gap between each, e.g. after reordering several movements.
- `digital=y` — This release is streaming-only, so turn off pregap/frame-snapping before building markers.
- `addoffsets` — You manually nudged a marker's position and want future `createcd` runs to preserve it instead of recalculating automatically.

---

## 11. Rendering / Export

| Command | Effect |
|---|---|
| `render=ddp` | Build CD markers, then render a DDP image. |
| `render=cue` | Build CD markers, then render a CUE sheet + audio. |
| `render=wav` | Build CD markers, then render WAV. |
| `render=flac` | Build CD markers, then render FLAC. |
| `render=opus` | Build CD markers, then render Opus. |
| `render=mp3` | Build CD markers, then render MP3. |
| `render=custom` (or plain `render`) | Build CD markers, then open REAPER's normal Render dialog. |

### Other examples

- `render=wav` — Bounce a quick WAV of the album for a reference listen before committing to a final master.
- `render=ddp` — Deliver a manufacturing-ready DDP image once the album is finalized.
- `render=mp3` — Export an MP3 to send the client a quick preview by email.
- `render=custom` — You need a non-standard render configuration (e.g. a specific sample rate); open the full Render dialog instead of a preset.

---

## 12. Stats, Diagnostics & Preferences

| Command | Effect |
|---|---|
| `stats?` | Speak a full project report: workflow, REAPER/ReaClassical versions, album length, CD marker count, project age, session time, total/source length, item/folder/track counts, edits (S-D/splits), FX/automation counts, and a list of every mixer/aux/submix/RCMASTER track. |
| `stats.key?` | Query a single stat. Keywords: `ver` (REAPER/ReaClassical versions), `albumlen` (final album length), `cdmarkers`, `age` (project age), `session` (session time), `projlen` (total project length), `srclen` (total source material length), `items`, `folders` (folder count, tracks per group), `special` (special track count), `regions`, `edits` (S-D edits, item splits), `fx` (FX count, automation lanes), `tracks` (mixer/aux/submix/RCMASTER listing), `sel` (selected tracks/items, cursor position), e.g. `stats.albumlen?`. |
| `stats.session` | Start/reset the session timer. |
| `stats.cp` | Copy the full `stats?` report text to the clipboard (requires the SWS extension). |
| `stats.cpver` | Copy just the REAPER/ReaClassical version line to the clipboard (requires the SWS extension). |
| `hitake?` | Speak the highest take number found across all items currently in the project (by scanning item names for `_TNNN` and pure-numeric patterns). Useful for checking how far a session has progressed without opening the Record Panel. Compare with `rec.latest?`, which scans audio files on disk for the current session. |
| `peak?` | Scan all unmuted tracks and jump the edit cursor to the loudest point. |
| `overs?` | Scan all unmuted tracks for peak level and any "overs" above the saved threshold. |
| `overs=N` | Same scan, using N dB as the over threshold (also saved as the new default), e.g. `overs=-2`. |
| `pref?` | List all 15 ReaClassical preferences with their current values. |
| `pref.key?` | Query a single preference (by keyword or 1–15 index). Keywords: `xfade`, `offset`, `index0`, `leadout`, `nocolor`, `norank`, `refguide`, `sdmarkers`, `altrate`, `year`, `cuefmt`, `floatdest`, `itemnames`, `takenums`, `srcmode`, e.g. `pref.offset?`. |
| `pref.key=value` | Set a single preference (validated — numeric ranges, 0/1 booleans, or WAV/FLAC/MP3/AIFF for `cuefmt`), e.g. `pref.offset=10`. |

### Other examples

- `stats?` — Get a full spoken overview of the project (length, item/track counts, FX/automation, mixer layout) to orient yourself in an unfamiliar or long-running session.
- `stats.session?` — Just check how long you've been working this session, without the full report.
- `stats.session` — Start a fresh session clock at the top of a new working block.
- `stats.fx?` — Quickly check FX/automation counts mid-session without the full report.
- `stats.cp` — Paste the full project report into an email to a client or collaborator.
- `stats.cpver` — Paste just the version info into a bug report.
- `overs?` — Before rendering, scan for any clipped peaks across all unmuted tracks.
- `overs=-3` — Tighten the over-detection threshold to -3 dB for a stricter check ahead of a critical master.
- `hitake?` — After a long session, quickly confirm the highest take number in the project before deciding what number to record next.
- `peak?` — Jump straight to the single loudest moment in the project to check it by ear.
- `pref.xfade=50` — Increase the default S-D crossfade length to 50 ms for a smoother edit style.
- `pref.cuefmt=FLAC` — Switch the CUE sheet's audio format from the default WAV to FLAC.
- `pref?` — Review every current preference value before changing one, so you know what you're starting from.

---

## 13. Miscellaneous / Setup Utilities

| Command | Effect |
|---|---|
| `newtab` | Open a new REAPER project tab. |
| `help` | Open this guide (the published HTML version, at https://reaclassical.org/rcterminal.html) in your default browser. |
| `factoryreset` | Run the ReaClassical Factory Reset script. |
| `update` | Trigger a ReaPack synchronization (checks for updates). |
| `installosara` | Download and install the OSARA screen-reader accessibility plugin (Windows/macOS only), then restart REAPER. |
| `updatereaper` | Download and install the REAPER version ReaClassical currently recommends/tests against. Closes all open projects (you'll be prompted to save unsaved work) and restarts REAPER once the install finishes. Same as `updatereaper=rec`. |
| `updatereaper=latest` | Install the latest public (main-release) REAPER version rather than the recommended one. |
| `updatereaper=VERSION` | Install a specific (main-release) REAPER version, e.g. `updatereaper=752` or `updatereaper=7.52` (both mean 7.52; the dot is optional). Searches the full version archive with no cutoff, so older versions work too (provided they are recommended version or higher). |
| `updatereaper=rec` | Synonym for the bare `updatereaper` command (also accepts `updatereaper=recommended`). |
| `allowgui=y` / `allowgui=n` | Allow/block ReaImGui windows (Mission Control, Notes, Preferences, etc.) from opening while OSARA is installed — they're blocked by default in that case, since they're unusable with a screen reader. |
| `allowgui?` | Speak whether GUI windows are currently allowed or blocked. |
| `debug=on` / `debug=off` | Display console messages in addition to OSARA announcements. Stored per project, so a new project always starts with debug off. |
| `debug?` | Speak whether debug announcements are currently on or off for this project. |
| `nudge=ms` | Set the ReaClassical project-level nudge amount, in milliseconds, used by the "Nudge Marker Left"/"Right" and "Nudge Item Left"/"Right" reascripts, e.g. `nudge=20`. REAPER's own item-nudge amount/unit isn't exposed to ReaScript, so this is tracked independently per project. Defaults to 5 ms if never set. |
| `nudge?` | Speak the current nudge amount. |
| `mod=n` | Set the multiplier applied by the "+ modifier" scripts (Nudge Marker Left/Right + modifier, XFM Shift Crossfade Left/Right + modifier), e.g. `mod=10`. These scripts move by nudge amount × modifier, so with `nudge=5` and `mod=10` each press moves 50 ms. Defaults to 5 if never set. |
| `mod?` | Speak the current modifier value. |

### Other examples

- `installosara` — Setting up a brand-new machine; install the screen-reader plugin before doing anything else.
- `updatereaper` — Match REAPER to the version ReaClassical is actually tested against (the safe default).
- `updatereaper=latest` — Keep REAPER itself current with the latest public release.
- `update` — Check ReaPack for newer versions of ReaClassical at the start of a session.
- `newtab` — Start a second, unrelated project (e.g. a different concert) without closing the current one.
- `help` — Open this guide in your browser to look something up.
- `allowgui=y` — A sighted collaborator needs to use Mission Control on this OSARA-enabled machine; let GUI windows open again.
- `nudge=10` — Switch to 10 ms steps for fine-tuning a marker position, then nudge it with the "Nudge Marker Left"/"Right" reascripts (these select a marker automatically after auditioning from/to it). The same amount also drives "Nudge Item Left"/"Right", which shift the selected item (and its synced peers across tracks in the same folder) and ripple every later item in that folder along with it.

---

## Suggested learning order for a new user

1. **Setup**: `6v` (or `4h=Violin,Viola,Cello,Bass`) → confirm with `stats?`.
2. **Inputs**: `ai` or manual `1=stereo,1`, `2=mono,3` → check with `1input?`.
3. **Recording**: `rec.session=Take1`, `rec.arm` then `rec.start` (or just press F9 twice), `rec.stop` to stop, `rec?` to review.
4. **Importing** (if recorded outside the session, or doing a second pass): `import` or `import=smart,2,dest`.
5. **Selecting & editing**: `sel=D,*`, `mk=Start`, `pr=-5` to slow a passage, `prepare` once takes are gathered.
6. **Mixing**: `1f=-3`, `2p=-20`, `1-rcm`, `1fx=ReaEQ`, `addauto=vol,-6,2,2`.
7. **Mixer snapshots** (for live perspective switches): `snap.add`, `snap.ar=y`, `snap.open`.
8. **Album assembly**: `createcd`, `album=My Recital,cp=Bach,pf=Various`.
9. **Rendering**: `render=ddp` or `render=wav`.
10. **Check anytime**: `stats?`, `overs?`, `peak?`.
