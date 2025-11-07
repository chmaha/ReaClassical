![logo](https://github.com/chmaha/ReaClassical/raw/main/docs/images/reaclassical_os.png)

[![Discord](https://img.shields.io/discord/1289215811613102207.svg?label=Discord&logo=discord&logoColor=ffffff&color=7389D8&labelColor=6A7EC2)](https://discord.gg/Gu2m9ccHGS)

Everything you need to do professional classical music recording, editing, mixing and mastering in REAPER for free. Please begin by visiting the [website](https://reaclassical.org), and reading the [quick start guide](https://reaclassical.org/quick_start_guide.html), [online manual](https://reaclassical.org/manual) and latest [release notes](https://github.com/chmaha/ReaClassical/raw/main/release_notes.pdf).

Download an official release for Linux, MacOS or Windows visit https://github.com/chmaha/ReaClassical/releases

**To build for all systems (currently requires Linux):**

Dependencies: makeself (Linux, Mac), go (Windows), 7z (Mac & Windows)

1. git clone the repo
2. Open a terminal in the `Installers` folder
3. Run `sh pull_reaper.sh [REAPER ver]` to grab REAPER install binaries and SWS plugin for all platforms _e.g._ `sh pull_reaper.sh 7.52` _to download REAPER 7.52_
4. Run `sh build_all.sh` to build for all platforms or individual scripts for a single OS (e.g. `sh build_linux.sh` etc)

To just use the functions, jsfx plugins, theme, and default template but without keymaps, toolbar etc, follow the [basic install](https://github.com/chmaha/ReaClassical/blob/main/install_instructions.md#basic-manual-install-inside-your-existing-reaper-install) instructions.

If you find these tools useful, please consider donating via [PayPal](https://www.paypal.com/donate/?hosted_button_id=PKJLC3E2UPW6C).
