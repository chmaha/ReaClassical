--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2026 chmaha

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
]]

-- Headless REAPER self-updater, invoked by the Terminal's "updatereaper" /
-- "updatereaper=VERSION" commands. Announces progress/errors via say()
-- instead of a GUI, and is driven by a step-file defer loop (same pattern
-- as ReaClassical_Record Panel Daemon.lua) so a large download doesn't
-- block REAPER's UI thread.
--
-- The actual download/install shell commands below (curl/powershell setup,
-- dmg-mount-and-copy with administrator-privilege fallback on macOS, the
-- pkexec install script on Linux, the silent NSIS install on Windows) are
-- a deliberately near-verbatim port of FeedTheCat's "REAPER Update Utility"
-- (see FTC Tools/Various/REAPER Update Utility.lua) -- getting shell
-- quoting wrong here could leave REAPER half-installed, so this reuses the
-- exact, already-proven command strings rather than rewriting them.
--
-- Deliberately NOT ported from that tool: the GUI/settings/version-history
-- menu (replaced by the Terminal commands + unlimited archive search
-- below), the startup-hook/auto-check-on-launch feature, and the
-- "reopen projects after restart" option (it depends on a startup-hook
-- companion script we don't install, so it would be silently inert here;
-- REAPER reopens its last project per its own normal preference instead).

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")

local EXT_NS = "ReaClassical_UpdateReaper"

if GetExtState(EXT_NS, "busy") == "1" then
    say("An update is already in progress")
    return
end
SetExtState(EXT_NS, "busy", "1", false)

local function finish()
    DeleteExtState(EXT_NS, "busy", false)
end

atexit(finish)

local mode = GetExtState(EXT_NS, "mode") -- "latest" or "version"
local requested_version = GetExtState(EXT_NS, "version")
DeleteExtState(EXT_NS, "mode", false)
DeleteExtState(EXT_NS, "version", false)

---------------------------------------------------------------------
-- Platform / architecture / paths (verbatim from FTC's update utility)
---------------------------------------------------------------------

local platform = GetOS()
local app = GetAppVersion()
local curr_version = app:gsub("/.-$", "")

local arch = app:match("/(.-)$")
if arch then
    if arch:match("win") then arch = arch:match("64") and "x64" or arch end
    if arch:match("OSX") then
        arch = arch:match("64") and "x86_64" or arch
        arch = arch:match("32") and "i386" or arch
    end
    if arch:match("macOS") then arch = arch:match("arm") and "arm64" or arch end
    if arch:match("linux") then
        arch = arch:match("64") and "x86_64" or arch
        arch = arch:match("686") and "i686" or arch
        arch = arch:match("arm") and "armv7l" or arch
        arch = arch:match("aarch") and "aarch64" or arch
    end
end

if not arch then
    say("Could not determine your system architecture")
    finish()
    return
end

local main_dlink = "https://www.reaper.fm/download.php"
local dev_dlink = "https://www.landoleet.org/"
local old_dlink = "https://www.landoleet.org/old/"

local install_path = GetExePath()
local res_path = GetResourcePath()
local ini_file = get_ini_file()
local is_portable = res_path == install_path

local tmp_path = "/tmp/"
if platform:match("Win") then
    local pipe = io.popen("echo %TEMP%")
    tmp_path = pipe and (pipe:read("*l") or "") or ""
    if pipe then pipe:close() end
    if tmp_path == "" then
        say("Could not find a temporary directory")
        finish()
        return
    end
    tmp_path = tmp_path .. "\\"
end

local function fnv1a(str)
    local hash = 2166136261
    for i = 1, #str do
        hash = hash ~ string.byte(str, i)
        hash = (hash * 16777619) & 0xffffffff
    end
    return string.format("%08x", hash)
end

local install_id = fnv1a(install_path)
local step_path = tmp_path .. ("reaclassical_uutil_%s_step.txt"):format(install_id)
local main_path = tmp_path .. ("reaclassical_uutil_%s_main.html"):format(install_id)
local dev_path = tmp_path .. ("reaclassical_uutil_%s_dev.html"):format(install_id)
local old_path = tmp_path .. ("reaclassical_uutil_%s_old.html"):format(install_id)
local log_path = tmp_path .. ("reaclassical_uutil_%s_log.txt"):format(install_id)

os.remove(step_path)
os.remove(main_path)
os.remove(dev_path)
os.remove(old_path)

local chosen_link, chosen_version, dfile_name

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------

local function Log(...)
    local log_file = io.open(log_path, "a")
    if not log_file then return end
    local values = {...}
    for i = 1, #values do values[i] = tostring(values[i]) end
    if #values == 0 then values[1] = "nil" end
    log_file:write(table.concat(values, " "), "\n")
    log_file:close()
end

local function run_shell(cmd, timeout)
    if platform:match("Win") then
        cmd = 'cmd.exe /Q /C "' .. cmd .. '"'
    elseif platform:match("OS") then
        cmd = "/bin/sh -c '" .. cmd .. "'"
    else
        cmd = '/bin/sh -c "' .. cmd .. '"'
    end
    Log("\nExecuting command:\n" .. cmd)
    return ExecProcess(cmd, timeout or -2)
end

-- "752" and "7.52" both match a parsed version of "7.52"; REAPER's own
-- dev-build numbering ("596+dev1009") and RC numbering ("597rc1") need no
-- special-casing -- stripping dots is the only normalization needed.
local function normalize_version(v)
    return (v or ""):lower():gsub("%.", "")
end

local function display_version(raw)
    return (raw:gsub("^(%d)", "%1.", 1))
end

local function get_file_pattern()
    local file_pattern
    if platform:match("Win") then
        file_pattern = (arch and "_" .. arch or "") .. "%-install%.exe"
    end
    if platform:match("OSX") then file_pattern = "%d%a?_" .. arch .. "%.dmg" end
    if platform:match("macOS") then file_pattern = "_universal%.dmg" end
    if platform:match("Other") then
        file_pattern = "_linux_" .. arch .. "%.tar%.xz"
    end
    return 'href="([^_"]-reaper[^_"]-' .. file_pattern .. ')"'
end

-- Returns the FIRST matching download link in `html` (the newest release
-- on that page) plus its raw (undotted) version string.
local function parse_first_link(html, dlink)
    local href_pattern = get_file_pattern()
    for line in html:gmatch("[^\n]+") do
        local file_name = line:match(href_pattern)
        if file_name then
            local site = dlink:match("(.-%..-%..-/)")
            local link = site .. file_name
            local raw_version = file_name:match("reaper(.-)[_%-]")
            return link, raw_version
        end
    end
    return nil
end

-- Scans every matching download link in `html` for one whose raw version
-- normalizes to `target_norm`. No limit on how far back this searches --
-- unlike the GUI tool's version-history menu, the whole page is scanned.
local function find_link_for_version(html, dlink, target_norm)
    local href_pattern = get_file_pattern()
    for line in html:gmatch("[^\n]+") do
        local file_name = line:match(href_pattern)
        if file_name then
            local raw_version = file_name:match("reaper(.-)[_%-]")
            if raw_version and normalize_version(raw_version) == target_norm then
                local site = dlink:match("(.-%..-%..-/)")
                return site .. file_name, raw_version
            end
        end
    end
    return nil
end

local function read_file(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

---------------------------------------------------------------------
-- Install (near-verbatim port of FTC's ExecInstall + per-OS install
-- steps -- only the confirmation dialog and project-reopening bookkeeping
-- were removed; the shell command strings themselves are unchanged)
---------------------------------------------------------------------

local function exec_install(install_cmd)
    -- Get paths and state counts of open projects, to detect cancellation
    local state_cnts = {}
    local active_proj = EnumProjects(-1)
    local p = 0
    local proj
    repeat
        proj = EnumProjects(p)
        if proj then
            state_cnts[proj] = GetProjectStateChangeCount(proj)
        end
        p = p + 1
    until not proj

    -- File: Close all projects
    Main_OnCommand(40886, 0)

    -- If the user cancelled the save-changes dialog, the state count won't
    -- have changed for the still-open project.
    local curr_proj = EnumProjects(-1)
    local state_cnt = GetProjectStateChangeCount(curr_proj)
    local did_cancel = active_proj and state_cnt == state_cnts[curr_proj]

    if did_cancel then
        say("Update cancelled due to unsaved changes")
        finish()
        return
    end

    run_shell(install_cmd)
    Main_OnCommand(40004, 0) -- File: Quit REAPER
end

local function start_windows_install()
    local portable_str = is_portable and "/PORTABLE" or "/ADMIN"
    local dfile_path = tmp_path .. dfile_name

    local cmd = "timeout %d >> %s 2>&1"
    cmd = cmd:format(5, log_path)
    cmd = cmd .. ' & %s /S %s /D=%s >> %s 2>&1'
    cmd = cmd:format(dfile_path, portable_str, install_path, log_path)
    cmd = cmd .. ' & cd /D %s >> %s 2>&1'
    cmd = cmd:format(install_path, log_path)
    cmd = cmd .. ' & del %s >> %s 2>&1'
    cmd = cmd:format(dfile_path, log_path)
    cmd = cmd .. ' & start reaper.exe -cfgfile \"%s\"'
    cmd = cmd:format(ini_file)

    exec_install(cmd)
end

local function start_osx_install()
    -- Mount downloaded dmg file and get the mount directory (yes agrees to license)
    local cmd = 'mount_dir=$(yes | hdiutil attach \"%s%s\" '
    cmd = cmd .. '| grep Volumes | cut -f 3) >> \"%s\" 2>&1'
    cmd = cmd .. ' && echo \"mount_dir: $mount_dir\" >> \"%s\" 2>&1'
    cmd = cmd:format(tmp_path, dfile_name, log_path, log_path)
    -- Go to mount directory
    cmd = cmd .. ' && cd \"$mount_dir\" >> \"%s\" 2>&1'
    cmd = cmd:format(log_path)
    -- Get the .app name
    cmd = cmd .. ' && app_name=$(ls | grep REAPER)'
    cmd = cmd .. ' && echo \"app_name: $app_name\" >> \"%s\" 2>&1'
    cmd = cmd:format(log_path)
    cmd = cmd .. ' && cp_cmd=$(printf \"echo ROOT >> %%q 2>&1'
    cmd = cmd .. ' && ditto %%q %%q >> %%q 2>&1\"'
    cmd = cmd .. ' \"%s\" \"$app_name\" \"%s/$app_name\" \"%s\")'
    -- Copy .app to install path
    cmd = cmd .. ' && cp_output=$(ditto \"$app_name\" \"%s/$app_name\"'
    cmd = cmd .. ' 2>&1)'
    -- Copy failed: Attempt with root access
    cmd = cmd .. ' || osascript -e \"on run argv\ndo shell script '
    cmd = cmd .. '(item 1 of argv) with administrator privileges'
    cmd = cmd .. ' with prompt (item 2 of argv)\n'
    cmd = cmd .. 'end run\" \"$cp_cmd\" \"ReaClassical Update REAPER\n\n'
    cmd = cmd .. 'Could not copy files to installation directory...\n\n'
    cmd = cmd .. 'Error message:\n$cp_output\n\n'
    cmd = cmd .. 'Retry with elevated permissions?\n'
    cmd = cmd .. '(not recommended)\"'
    cmd = cmd .. ' ; echo $cp_output >> \"%s\" 2>&1'
    cmd = cmd:format(log_path, install_path, log_path, install_path, log_path)
    -- Unmount file (new command string due to %q)
    local e_cmd = ' ; cd && hdiutil eject \"$mount_dir\" >> \"%s\" 2>&1'
    e_cmd = e_cmd:format(log_path)
    -- Restart REAPER
    e_cmd = e_cmd .. ' ; echo \"Starting: %s/$app_name\" >> \"%s\" 2>&1'
    e_cmd = e_cmd .. ' ; open \"%s/$app_name\" --args -cfgfile \"%s\"'
    e_cmd = e_cmd:format(install_path, log_path, install_path, ini_file)

    exec_install(cmd .. e_cmd)
end

-- Extraction runs as its own async step (like FTC's 'linux_extract'), since
-- everything here is driven by the step-file/defer loop -- run_shell()'s
-- return value isn't a simple pass/fail boolean, success is only known via
-- the step file the shell command itself writes on completion.
local function start_linux_extract()
    local cmd = "tar -xf %s%s -C %s >> %s 2>&1"
    cmd = cmd:format(tmp_path, dfile_name, tmp_path, log_path)
    cmd = cmd .. " && echo linux_install > %s"
    cmd = cmd .. " || echo err_extract > %s"
    cmd = cmd:format(step_path, step_path)
    run_shell(cmd)
end

local function start_linux_install()
    local sh_path = "%sreaper_linux_%s/install-reaper.sh"
    sh_path = sh_path:format(tmp_path, arch)

    local function escape_path_for_shell(s)
        return s:gsub("([%s'\"\\|&;()<>!{}*%[%]?^$`#,])", "\\%1")
    end

    local installer_path = escape_path_for_shell(install_path)
    local create_symlink_cmd = ""
    local delete_symlink_cmd = ""
    -- When installer folder is not called REAPER, trick the
    -- installer by directing it to a symlink called REAPER
    if not installer_path:match("/REAPER$") then
        installer_path = installer_path .. "/uutil"
        local symcmd = "mkdir %s ; ln -s %s/.. %s/REAPER ;"
        create_symlink_cmd = symcmd:format(installer_path, installer_path, installer_path)
        local rmcmd = "; rm -R %s"
        delete_symlink_cmd = rmcmd:format(installer_path)
    else
        installer_path = installer_path:gsub("/REAPER$", "")
    end

    local options = "--integrate-desktop --usr-local-bin-symlink"
    if is_portable then options = "" end

    local root_cmd = "%s sh %s --install %s %s %s"
    root_cmd = root_cmd:format(create_symlink_cmd, sh_path, installer_path, options, delete_symlink_cmd)
    local cmd = "pkexec sh -c '" .. root_cmd .. "' >> %s 2>&1"
    cmd = cmd:format(log_path)
    cmd = cmd .. " ; '%s/reaper' -cfgfile '%s'"
    cmd = cmd:format(install_path, ini_file)

    exec_install(cmd)
end

---------------------------------------------------------------------
-- Step machine
---------------------------------------------------------------------

local dl_cmd = "curl -f -k -L %s -o %s"
if platform:match("Win") then
    local _, exit_code = run_shell("curl --version", 1000)
    if exit_code ~= 0 then
        dl_cmd = 'powershell.exe -windowstyle hidden (new-object \z
                System.Net.WebClient).DownloadFile(\'%s\', \'%s\')'
    end
end

local function begin_download_step()
    say("Downloading REAPER " .. display_version(chosen_version) .. ", please wait...")
    dfile_name = chosen_link:gsub(".-/", "")

    local next_step = "linux_extract"
    if platform:match("Win") then next_step = "windows_install" end
    if platform:match("OS") then next_step = "osx_install" end

    local cmd = dl_cmd .. " >> %s 2>&1"
    cmd = cmd:format(chosen_link, tmp_path .. dfile_name, log_path)
    cmd = cmd .. " && echo %s > %s"
    cmd = cmd .. " || echo err_internet > %s"
    cmd = cmd:format(next_step, step_path, step_path)
    run_shell(cmd)
end

local function proceed_with(link, raw_version)
    chosen_link = link
    chosen_version = raw_version

    if normalize_version(raw_version) == normalize_version(curr_version) then
        say("REAPER is already on version " .. display_version(raw_version))
        finish()
        return
    end

    begin_download_step()
end

local function announce_not_found()
    say("REAPER version " .. (requested_version or "?") .. " not found")
    finish()
end

local function Main()
    local step_file = io.open(step_path, "r")
    if step_file then
        local step = step_file:read("*a"):gsub("[^%w_]+", "")
        step_file:close()
        os.remove(step_path)

        Log("\n------------- Step", step, "---------------")

        if step == "after_live" then
            local main_html = read_file(main_path)
            os.remove(main_path)
            local dev_html = read_file(dev_path)
            os.remove(dev_path)

            if not main_html then
                say("Could not check for REAPER updates")
                finish()
                return
            end

            if mode == "latest" then
                local link, raw_version = parse_first_link(main_html, main_dlink)
                if not link then
                    say("Could not find a REAPER download link. The download page format may have changed.")
                    finish()
                    return
                end
                proceed_with(link, raw_version)
                return
            end

            local norm = normalize_version(requested_version)
            local link, raw_version = find_link_for_version(main_html, main_dlink, norm)
            if not link and dev_html then
                link, raw_version = find_link_for_version(dev_html, dev_dlink, norm)
            end
            if link then
                proceed_with(link, raw_version)
                return
            end

            -- Not on either live page -- search the full historical archive
            -- (no artificial limit, unlike the GUI tool's version menu).
            local cmd = dl_cmd .. " >> %s 2>&1"
            cmd = cmd:format(old_dlink, old_path, log_path)
            cmd = cmd .. " && echo after_history > %s"
            cmd = cmd .. " || echo err_internet > %s"
            cmd = cmd:format(step_path, step_path)
            run_shell(cmd)
        end

        if step == "after_history" then
            local old_html = read_file(old_path)
            os.remove(old_path)
            if not old_html then
                say("Could not check for REAPER updates")
                finish()
                return
            end
            local norm = normalize_version(requested_version)
            local link, raw_version = find_link_for_version(old_html, old_dlink, norm)
            if not link then
                announce_not_found()
                return
            end
            proceed_with(link, raw_version)
        end

        if step == "windows_install" then start_windows_install() end
        if step == "osx_install" then start_osx_install() end
        if step == "linux_extract" then start_linux_extract() end
        if step == "linux_install" then start_linux_install() end

        if step == "err_internet" then
            say("Could not download REAPER update. Check your internet connection.")
            finish()
            return
        end

        if step == "err_extract" then
            say("Failed to extract the REAPER update")
            finish()
            return
        end
    end
    defer(Main)
end

---------------------------------------------------------------------
-- Kick off: fetch both live pages (main release + current dev/rc build)
---------------------------------------------------------------------

say(mode == "latest" and "Checking for the latest REAPER version..."
    or ("Checking for REAPER version " .. (requested_version or "?") .. "..."))

do
    -- The dev/rc page fetch is best-effort and run as its own detached
    -- command (read_file() above already tolerates dev_path not existing),
    -- so it's never chained into the success/failure check below -- this
    -- sidesteps needing a "succeed regardless" operator that's spelled
    -- differently on cmd.exe ("&") vs /bin/sh ("; or "|| true").
    local dev_cmd = dl_cmd .. " >> %s 2>&1"
    dev_cmd = dev_cmd:format(dev_dlink, dev_path, log_path)
    run_shell(dev_cmd)

    local cmd = dl_cmd .. " >> %s 2>&1"
    cmd = cmd:format(main_dlink, main_path, log_path)
    cmd = cmd .. " && echo after_live > %s"
    cmd = cmd .. " || echo err_internet > %s"
    cmd = cmd:format(step_path, step_path)
    run_shell(cmd)
end

defer(Main)
