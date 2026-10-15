# ReaClassical

A complete recording, editing, mixing and mastering solution for classical music engineers,
built on [REAPER](https://www.reaper.fm/). Source-destination editing, take-aware recording,
a two-lane crossfade editor, album-ready DDP/CUE mastering and mastering-grade plugins, with
every feature fully available to blind engineers.

Free and open source under the GNU General Public License v3 (see `LICENSE`).

- Website and downloads: https://reaclassical.com
- Manual: https://reaclassical.com/manual/
- Support and discussion: the ReaClassical subforum on the [REAPER forum](https://forum.cockos.com/forumdisplay.php?f=57)

## Install ReaClassical

The install script is the supported way to install ReaClassical. It downloads the REAPER version
ReaClassical was tested with (see `tested_reaper_ver.txt`), the ReaClassical resource folder and the
right plugins for your system, and sets everything up in a self-contained folder. Nothing is installed
system-wide.

- **macOS** (Terminal): `curl --proto '=https' --tlsv1.2 -sSf https://reaclassical.com/macos | sh`
- **Windows** (PowerShell): `irm "https://reaclassical.com/win" | iex`
- **Linux, including Raspberry Pi** (terminal): `curl --proto '=https' --tlsv1.2 -sSf https://reaclassical.com/linux | sh`

Updates come through ReaClassical itself (the Update action), which uses the ReaPack index below.

## ReaPack indexes

ReaClassical, ReaEdit and RCPlugs each have their own [ReaPack](https://reapack.com) index. Use
Extensions > ReaPack > Import repositories and paste the URL:

| Package | Index |
|---|---|
| ReaClassical | `https://raw.githubusercontent.com/chmaha/ReaClassical/main/index.xml` |
| ReaEdit | `https://raw.githubusercontent.com/chmaha/ReaClassical/main/ReaEdit/index.xml` |
| RCPlugs | `https://raw.githubusercontent.com/chmaha/ReaClassical/main/RCPlugs/index.xml` |

ReaEdit (source-destination editing) and RCPlugs (the JSFX plugins) can be installed this way on any
REAPER setup. Installing ReaClassical through ReaPack alone is unsupported; use the install script.

## Repository layout

- `ReaClassical/` the scripts, theme, project templates and offline help (ReaPack package)
- `ReaEdit/` ReaEdit, the free source-destination editing package
- `RCPlugs/` the ReaClassical JSFX plugins
- `Installers/` resources the install scripts download (resource folder, extensions, 7-Zip)
- `docs/` the website and manual (GitHub Pages)

## Contributing

Bug reports and ideas are welcome on the REAPER forum or as GitHub issues. Code contributions are
not accepted: ReaClassical is developed by a single author.
