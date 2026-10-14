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

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
local script_file = debug.getinfo(1, "S").source:sub(2)
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
    AddRemoveReaScript(false, 0, script_file, true)
end

atexit(finish)

local mode = GetExtState(EXT_NS, "mode")
local requested_version = GetExtState(EXT_NS, "version")
DeleteExtState(EXT_NS, "mode", false)
DeleteExtState(EXT_NS, "version", false)

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
local rec_dlink = "https://raw.githubusercontent.com/chmaha/ReaClassical/main/tested_reaper_ver.txt"

local main_site_root = "https://www.reaper.fm/"

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
local rec_path = tmp_path .. ("reaclassical_uutil_%s_rec.txt"):format(install_id)
local log_path = tmp_path .. ("reaclassical_uutil_%s_log.txt"):format(install_id)

os.remove(step_path)
os.remove(main_path)
os.remove(dev_path)
os.remove(old_path)
os.remove(rec_path)

local chosen_link, chosen_version, dfile_name

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

local function parse_first_link(html, site_root)
    local href_pattern = get_file_pattern()
    for line in html:gmatch("[^\n]+") do
        local file_name = line:match(href_pattern)
        if file_name then
            local raw_version = file_name:match("reaper(.-)_")
            return site_root .. file_name, raw_version
        end
    end
    return nil
end

local function find_link_for_version(html, site_root, target_norm)
    local href_pattern = get_file_pattern()
    for line in html:gmatch("[^\n]+") do
        local file_name = line:match(href_pattern)
        if file_name then
            local raw_version = file_name:match("reaper(.-)_")
            if raw_version and normalize_version(raw_version) == target_norm then
                return site_root .. file_name, raw_version
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

local function parse_recommended_version(content)
    local lines = {}
    for line in (content .. "\n"):gmatch("(.-)\r?\n") do
        lines[#lines + 1] = line
    end
    for i, line in ipairs(lines) do
        if line:match("====") then
            local nxt = lines[i + 1]
            if nxt then
                nxt = nxt:gsub("^%s+", ""):gsub("%s+$", "")
                if nxt ~= "" then return nxt end
            end
        end
    end
    return nil
end

local function exec_install(install_cmd)
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

    Main_OnCommand(40886, 0)

    local curr_proj = EnumProjects(-1)
    local state_cnt = GetProjectStateChangeCount(curr_proj)
    local did_cancel = active_proj and state_cnt == state_cnts[curr_proj]

    if did_cancel then
        say("Update cancelled due to unsaved changes")
        finish()
        return
    end

    run_shell(install_cmd)
    Main_OnCommand(40004, 0)
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
    local cmd = 'mount_dir=$(yes | hdiutil attach \"%s%s\" '
    cmd = cmd .. '| grep Volumes | cut -f 3) >> \"%s\" 2>&1'
    cmd = cmd .. ' && echo \"mount_dir: $mount_dir\" >> \"%s\" 2>&1'
    cmd = cmd:format(tmp_path, dfile_name, log_path, log_path)
    cmd = cmd .. ' && cd \"$mount_dir\" >> \"%s\" 2>&1'
    cmd = cmd:format(log_path)
    cmd = cmd .. ' && app_name=$(ls | grep REAPER)'
    cmd = cmd .. ' && echo \"app_name: $app_name\" >> \"%s\" 2>&1'
    cmd = cmd:format(log_path)
    cmd = cmd .. ' && cp_cmd=$(printf \"echo ROOT >> %%q 2>&1'
    cmd = cmd .. ' && ditto %%q %%q >> %%q 2>&1\"'
    cmd = cmd .. ' \"%s\" \"$app_name\" \"%s/$app_name\" \"%s\")'
    cmd = cmd .. ' && cp_output=$(ditto \"$app_name\" \"%s/$app_name\"'
    cmd = cmd .. ' 2>&1)'
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
    local e_cmd = ' ; cd && hdiutil eject \"$mount_dir\" >> \"%s\" 2>&1'
    e_cmd = e_cmd:format(log_path)
    e_cmd = e_cmd .. ' ; echo \"Starting: %s/$app_name\" >> \"%s\" 2>&1'
    e_cmd = e_cmd .. ' ; open \"%s/$app_name\" --args -cfgfile \"%s\"'
    e_cmd = e_cmd:format(install_path, log_path, install_path, ini_file)

    exec_install(cmd .. e_cmd)
end

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

local dl_cmd = "curl -f -k -L %s -o %s"
local has_curl = not platform:match("Win")
local head_cmd = "curl -f -k -L -I %s"
if platform:match("Win") then
    local _, exit_code = run_shell("curl --version", 1000)
    has_curl = exit_code == 0
    if not has_curl then
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

local function stable_direct_url(norm)
    if norm:match("[^%d]") then return nil end
    local major = norm:match("^(.-)%d%d$")
    if not major or major == "" then return nil end
    local base = "https://www.reaper.fm/files/" .. major .. ".x/"
    local fname
    if platform:match("Win") then
        fname = "reaper" .. norm .. "_" .. arch .. "-install.exe"
    elseif platform:match("OSX") then
        fname = "reaper" .. norm .. "_" .. arch .. ".dmg"
    elseif platform:match("macOS") then
        fname = "reaper" .. norm .. "_universal.dmg"
    elseif platform:match("Other") then
        fname = "reaper" .. norm .. "_linux_" .. arch .. ".tar.xz"
    end
    if not fname then return nil end
    return base .. fname, norm
end

local function fetch_live_pages()
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

local function Main()
    local step_file = io.open(step_path, "r")
    if step_file then
        local step = step_file:read("*a"):gsub("[^%w_]+", "")
        step_file:close()
        os.remove(step_path)

        Log("\n------------- Step", step, "---------------")

        if step == "after_rec" then
            local rec_content = read_file(rec_path)
            os.remove(rec_path)
            local parsed = rec_content and parse_recommended_version(rec_content)
            if not parsed then
                say("Could not determine the recommended REAPER version")
                finish()
                return
            end
            requested_version = parsed
            mode = "version"
            say("Recommended REAPER version is " .. parsed .. ". Checking...")
            fetch_live_pages()
        end

        if step == "after_rec_ver" then
            local rec_content = read_file(rec_path)
            os.remove(rec_path)
            local rec_ver = rec_content and parse_recommended_version(rec_content)
            if rec_ver then
                local norm_req = normalize_version(requested_version)
                local norm_rec = normalize_version(rec_ver)
                local req_num = tonumber(norm_req:match("^(%d+)"))
                local rec_num = tonumber(norm_rec:match("^(%d+)"))
                if req_num and rec_num and req_num < rec_num then
                    say("Cannot install REAPER " .. (requested_version or "?") ..
                        " -- older than the recommended version (" .. rec_ver .. ")")
                    finish()
                    return
                end
            end
            fetch_live_pages()
        end

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
                local link, raw_version = parse_first_link(main_html, main_site_root)
                if not link then
                    say("Could not find a REAPER download link. The download page format may have changed.")
                    finish()
                    return
                end
                proceed_with(link, raw_version)
            else
                local norm = normalize_version(requested_version)
                local is_dev_rc = norm:match("[^%d]") ~= nil
                local link, raw_version = find_link_for_version(main_html, main_site_root, norm)
                if not link and is_dev_rc and dev_html then
                    link, raw_version = find_link_for_version(dev_html, dev_dlink, norm)
                end
                if link then
                    proceed_with(link, raw_version)
                elseif is_dev_rc then
                    local cmd = dl_cmd .. " >> %s 2>&1"
                    cmd = cmd:format(old_dlink, old_path, log_path)
                    cmd = cmd .. " && echo after_history > %s"
                    cmd = cmd .. " || echo err_internet > %s"
                    cmd = cmd:format(step_path, step_path)
                    run_shell(cmd)
                else
                    local direct_link, direct_raw = stable_direct_url(norm)
                    if direct_link and has_curl then
                        chosen_link = direct_link
                        chosen_version = direct_raw
                        local cmd = head_cmd .. " >> %s 2>&1"
                        cmd = cmd:format(direct_link, log_path)
                        cmd = cmd .. " && echo after_stable_head > %s"
                        cmd = cmd .. " || echo err_no_stable > %s"
                        cmd = cmd:format(step_path, step_path)
                        run_shell(cmd)
                    elseif direct_link then
                        proceed_with(direct_link, direct_raw)
                    else
                        announce_not_found()
                        return
                    end
                end
            end
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

        if step == "after_stable_head" then
            proceed_with(chosen_link, chosen_version)
        end

        if step == "err_no_stable" then
            announce_not_found()
            return
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

if mode == "recommended" then
    say("Checking for the recommended REAPER version...")
    local cmd = dl_cmd .. " >> %s 2>&1"
    cmd = cmd:format(rec_dlink, rec_path, log_path)
    cmd = cmd .. " && echo after_rec > %s"
    cmd = cmd .. " || echo err_internet > %s"
    cmd = cmd:format(step_path, step_path)
    run_shell(cmd)
elseif mode == "version" then
    say("Checking for REAPER version " .. (requested_version or "?") .. "...")
    local cmd = dl_cmd .. " >> %s 2>&1"
    cmd = cmd:format(rec_dlink, rec_path, log_path)
    cmd = cmd .. " && echo after_rec_ver > %s"
    cmd = cmd .. " || echo after_rec_ver > %s"
    cmd = cmd:format(step_path, step_path)
    run_shell(cmd)
else
    say("Checking for the latest REAPER version...")
    fetch_live_pages()
end

defer(Main)
