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
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local humanize_track_name = require("ReaClassical_Track_Naming")
local smart_import_scan = require("ReaClassical_Smart_Import_Scan")
local mixer_core = require("ReaClassical_Mixer_Core")
local track_setup_commands = require("ReaClassical_Track_Setup_Commands")

local workflow = ""

local terminal_interactive = true

local say = require("ReaClassical_Announce")

function trim(s)
    return s:match("^%s*(.-)%s*$")
end

function get_start_folder_idx_from_selection()
    local track = GetSelectedTrack(0, 0)
    if not track then return 2 end

    while track and GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") ~= 1 do
        track = GetParentTrack(track)
    end
    if not track then return 2 end

    local idx = 0
    for i = 0, CountTracks(0) - 1 do
        local tr = GetTrack(0, i)
        if GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1 then
            idx = idx + 1
            if tr == track then return idx end
        end
    end
    return 2
end

function try_mute_solo(cmd)
    local word_target, word_op = mixer_core.split_word_target(cmd)
    if word_target then
        local tracks, err = mixer_core.resolve_target_list(word_target)
        if #tracks == 0 then
            say(err or "No matching tracks")
            return true
        end

        if word_op == "xs" then
            local group_names
            tracks, group_names = mixer_core.expand_with_groups(tracks, "solo")
            for _, track in ipairs(mixer_core.get_mixer_tracks()) do
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            end
            for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "I_SOLO", 2) end
            say("Soloed " .. mixer_core.track_names_str(tracks) .. mixer_core.group_names_suffix(group_names))
            return true
        elseif word_op == "m" or word_op == "um" or word_op == "s" or word_op == "us" then
            local aspect = (word_op == "m" or word_op == "um") and "mute" or "solo"
            local group_names
            tracks, group_names = mixer_core.expand_with_groups(tracks, aspect)
            local op_word
            if word_op == "m" then
                for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "B_MUTE", 1) end
                op_word = "Muted"
            elseif word_op == "um" then
                for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "B_MUTE", 0) end
                op_word = "Unmuted"
            elseif word_op == "s" then
                for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "I_SOLO", 2) end
                op_word = "Soloed"
            else
                for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "I_SOLO", 0) end
                op_word = "Unsoloed"
            end
            say(op_word .. " " .. mixer_core.track_names_str(tracks) .. mixer_core.group_names_suffix(group_names))
            return true
        elseif word_op == "i=y" or word_op == "i=n" then
            local group_names
            tracks, group_names = mixer_core.expand_with_groups(tracks, "polarity")
            local pol_val = word_op:match("i=([yn])")
            for _, track in ipairs(tracks) do
                SetMediaTrackInfo_Value(track, "B_PHASE", pol_val == "y" and 1 or 0)
            end
            say((pol_val == "y" and "Inverted" or "Normal") .. " polarity: "
                .. mixer_core.track_names_str(tracks) .. mixer_core.group_names_suffix(group_names))
            return true
        elseif word_op == "i?" then
            for _, track in ipairs(tracks) do
                local phase = GetMediaTrackInfo_Value(track, "B_PHASE")
                local prefix = mixer_core.label_prefix(mixer_core.query_label(track, #tracks), " ")
                say(prefix .. "polarity: " .. (phase == 1 and "inverted" or "normal"))
            end
            return true
        elseif word_op == "m?" or word_op == "s?" then
            for _, track in ipairs(tracks) do
                local prefix = mixer_core.label_prefix(mixer_core.query_label(track, #tracks), " ")
                if word_op == "m?" then
                    local muted = GetMediaTrackInfo_Value(track, "B_MUTE") > 0
                    say(prefix .. "mute: " .. (muted and "on" or "off"))
                else
                    local soloed = GetMediaTrackInfo_Value(track, "I_SOLO") > 0
                    say(prefix .. "solo: " .. (soloed and "on" or "off"))
                end
            end
            return true
        end
    end

    local xs_target = cmd:match("^([%d,%-%*@#%s]+)xs$")
    if xs_target then
        local tracks, err = mixer_core.resolve_target_list((xs_target:gsub("%s+", "")))
        if #tracks == 0 then
            say(err or "No matching tracks")
            return true
        end
        local group_names
        tracks, group_names = mixer_core.expand_with_groups(tracks, "solo")
        for _, track in ipairs(mixer_core.get_mixer_tracks()) do
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
        end
        for _, track in ipairs(tracks) do
            SetMediaTrackInfo_Value(track, "I_SOLO", 2)
        end
        say("Soloed " .. mixer_core.track_names_str(tracks) .. mixer_core.group_names_suffix(group_names))
        return true
    end

    local target_str, op = cmd:match("^([%d,%-%*@#%s]+)(u?[ms])$")
    if target_str then
        local tracks, err = mixer_core.resolve_target_list((target_str:gsub("%s+", "")))
        if #tracks == 0 then
            say(err or "No matching tracks")
            return true
        end
        local group_names
        tracks, group_names = mixer_core.expand_with_groups(tracks, (op == "m" or op == "um") and "mute" or "solo")

        local op_word
        if op == "m" then
            for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "B_MUTE", 1) end
            op_word = "Muted"
        elseif op == "um" then
            for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "B_MUTE", 0) end
            op_word = "Unmuted"
        elseif op == "s" then
            for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "I_SOLO", 2) end
            op_word = "Soloed"
        elseif op == "us" then
            for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "I_SOLO", 0) end
            op_word = "Unsoloed"
        end
        say(op_word .. " " .. mixer_core.track_names_str(tracks) .. mixer_core.group_names_suffix(group_names))
        return true
    end

    local pol_target, pol_val = cmd:match("^([%d,%-%*@#%s]+)i=([yn])$")
    if pol_target then
        local tracks, err = mixer_core.resolve_target_list((pol_target:gsub("%s+", "")))
        if #tracks == 0 then
            say(err or "No matching tracks")
            return true
        end
        local group_names
        tracks, group_names = mixer_core.expand_with_groups(tracks, "polarity")

        for _, track in ipairs(tracks) do
            SetMediaTrackInfo_Value(track, "B_PHASE", pol_val == "y" and 1 or 0)
        end
        say((pol_val == "y" and "Inverted" or "Normal") .. " polarity: "
            .. mixer_core.track_names_str(tracks) .. mixer_core.group_names_suffix(group_names))
        return true
    end

    local pol_query_str = cmd:match("^([%d,%-%*@#%s]+)i%?$")
    if pol_query_str then
        local tracks, err = mixer_core.resolve_target_list((pol_query_str:gsub("%s+", "")))
        if #tracks == 0 then
            say(err or "No matching tracks")
            return true
        end
        for _, track in ipairs(tracks) do
            local phase = GetMediaTrackInfo_Value(track, "B_PHASE")
            local prefix = mixer_core.label_prefix(mixer_core.query_label(track, #tracks), " ")
            say(prefix .. "polarity: " .. (phase == 1 and "inverted" or "normal"))
        end
        return true
    end

    local query_str, query_op = cmd:match("^([%d,%-%*@#%s]+)([ms])%?$")
    if query_str then
        local tracks, err = mixer_core.resolve_target_list((query_str:gsub("%s+", "")))
        if #tracks == 0 then
            say(err or "No matching tracks")
            return true
        end

        for _, track in ipairs(tracks) do
            local prefix = mixer_core.label_prefix(mixer_core.query_label(track, #tracks), " ")
            if query_op == "m" then
                local muted = GetMediaTrackInfo_Value(track, "B_MUTE") > 0
                say(prefix .. "mute: " .. (muted and "on" or "off"))
            else
                local soloed = GetMediaTrackInfo_Value(track, "I_SOLO") > 0
                say(prefix .. "solo: " .. (soloed and "on" or "off"))
            end
        end
        return true
    end

    return false
end

function try_pan(cmd)
    local target_str, rest = mixer_core.split_word_target(cmd)
    if not target_str then
        target_str, rest = cmd:match("^([%#@]?[%d,%-%*%s]*)(.+)$")
        if not target_str then return false end
        target_str = target_str:gsub("%s+", "")
    end

    local delta = rest:match("^p([+-]%d+)$")
    if delta then
        local tracks, err = mixer_core.resolve_target_list(target_str)
        if #tracks == 0 then
            say(err or ("Unknown target: " .. target_str))
            return true
        end
        local group_names
        tracks, group_names = mixer_core.expand_with_groups(tracks, "pan")
        local suffix = mixer_core.group_names_suffix(group_names)
        for _, track in ipairs(tracks) do
            local pan = GetMediaTrackInfo_Value(track, "D_PAN")
            pan = mixer_core.clamp(pan + tonumber(delta) / 100, -1, 1)
            SetMediaTrackInfo_Value(track, "D_PAN", pan)
            local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            say(humanize_track_name(name) .. " pan: " .. mixer_core.format_pan(pan) .. suffix)
        end
        return true
    end

    local abs_val = rest:match("^p=([+-]?%d+)$")
    if abs_val then
        local tracks, err = mixer_core.resolve_target_list(target_str)
        if #tracks == 0 then
            say(err or ("Unknown target: " .. target_str))
            return true
        end
        local group_names
        tracks, group_names = mixer_core.expand_with_groups(tracks, "pan")
        local pan = mixer_core.pct_to_pan(abs_val)
        for _, track in ipairs(tracks) do
            SetMediaTrackInfo_Value(track, "D_PAN", pan)
        end
        say("Pan set to " .. mixer_core.format_pan(pan) .. ": " .. mixer_core.track_names_str(tracks) .. mixer_core.group_names_suffix(group_names))
        return true
    end

    if rest == "p?" then
        local tracks, err = mixer_core.resolve_target_list(target_str)
        if #tracks == 0 then
            say(err or ("Unknown target: " .. target_str))
            return true
        end
        for _, track in ipairs(tracks) do
            local prefix = mixer_core.label_prefix(mixer_core.query_label(track, #tracks), ": ")
            say(prefix .. mixer_core.format_pan(GetMediaTrackInfo_Value(track, "D_PAN")))
        end
        return true
    end

    return false
end

function try_fader(cmd)
    local target_str, rest = mixer_core.split_word_target(cmd)
    if not target_str then
        target_str, rest = cmd:match("^([%#@]?[%d,%-%*%s]*)(.+)$")
        if not target_str then return false end
        target_str = target_str:gsub("%s+", "")
    end

    local delta = rest:match("^f([+-]%d+)$")
    if delta then
        local tracks, err = mixer_core.resolve_target_list(target_str)
        if #tracks == 0 then
            say(err or ("Unknown target: " .. target_str))
            return true
        end
        local group_names
        tracks, group_names = mixer_core.expand_with_groups(tracks, "fader")
        local suffix = mixer_core.group_names_suffix(group_names)
        for _, track in ipairs(tracks) do
            local db = mixer_core.linear_to_db(GetMediaTrackInfo_Value(track, "D_VOL")) + tonumber(delta)
            SetMediaTrackInfo_Value(track, "D_VOL", mixer_core.db_to_linear(db))
            local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            say(string.format("%s: %.1f dB", humanize_track_name(name), db) .. suffix)
        end
        return true
    end

    local abs_db = rest:match("^f=([+-]?%d+)$")
    if abs_db then
        local tracks, err = mixer_core.resolve_target_list(target_str)
        if #tracks == 0 then
            say(err or ("Unknown target: " .. target_str))
            return true
        end
        local group_names
        tracks, group_names = mixer_core.expand_with_groups(tracks, "fader")
        for _, track in ipairs(tracks) do
            SetMediaTrackInfo_Value(track, "D_VOL", mixer_core.db_to_linear(tonumber(abs_db)))
        end
        say("Volume set to " .. abs_db .. " dB: " .. mixer_core.track_names_str(tracks) .. mixer_core.group_names_suffix(group_names))
        return true
    end

    if rest == "f?" then
        local tracks, err = mixer_core.resolve_target_list(target_str)
        if #tracks == 0 then
            say(err or ("Unknown target: " .. target_str))
            return true
        end
        for _, track in ipairs(tracks) do
            local prefix = mixer_core.label_prefix(mixer_core.query_label(track, #tracks), ": ")
            local db = mixer_core.linear_to_db(GetMediaTrackInfo_Value(track, "D_VOL"))
            say(string.format("%s%.1f dB", prefix, db))
        end
        return true
    end

    return false
end

function try_peak(cmd)
    local target_str, rest = mixer_core.split_word_target(cmd)
    if not target_str then
        target_str, rest = cmd:match("^([%#@]?[%d,%-%*%s]*)(.+)$")
        if not target_str then return false end
        target_str = target_str:gsub("%s+", "")
    end

    if rest ~= "pk?" then return false end

    local tracks, err = mixer_core.resolve_target_list(target_str)
    if #tracks == 0 then
        say(err or ("Unknown target: " .. target_str))
        return true
    end
    for _, track in ipairs(tracks) do
        local prefix = mixer_core.label_prefix(mixer_core.query_label(track, #tracks), ": ")
        say(prefix .. mixer_core.format_track_peak(track))
    end
    return true
end

function try_misc(cmd)
    if cmd == "help" then
        if not APIExists("CF_ShellExecute") then
            say("SWS/S&M extension required to open the guide")
            return true
        end
        local resource_path = GetResourcePath()
        local pathseparator = package.config:sub(1, 1)
        local html = table.concat({
            resource_path, "Scripts", "chmaha Scripts", "ReaClassical", "ReaClassical-Terminal-Guide.html"
        }, pathseparator)
        local file = io.open(html, "r")
        if file then
            io.close(file)
            CF_ShellExecute(html)
        else
            say("Re-install ReaClassical metapackage via ReaPack first")
        end
        return true
    end

    local debug_val = cmd:match("^debug=(%a+)$")
    if debug_val == "on" or debug_val == "off" then
        SetProjExtState(0, "ReaClassical", "DebugAnnounce", debug_val)
        if debug_val == "on" then
            if APIExists("clara_outputMessage") then
                say("Debug announcements on")
            else
                ShowConsoleMsg("Debug announcements on\n")
            end
        elseif APIExists("clara_outputMessage") then
            say("Debug announcements off")
        end
        return true
    end

    if cmd == "debug?" then
        local _, debug_str = GetProjExtState(0, "ReaClassical", "DebugAnnounce")
        say(debug_str == "on" and "Debug announcements on" or "Debug announcements off")
        return true
    end

    local nudge_ms = cmd:match("^nudge=([%d%.]+)$")
    if nudge_ms then
        local ms = tonumber(nudge_ms)
        if not ms or ms <= 0 then
            say("nudge= requires a positive number of milliseconds")
            return true
        end
        SetProjExtState(0, "ReaClassical", "NudgeMs", tostring(ms))
        say("Nudge amount set to " .. ms .. " milliseconds")
        return true
    end

    if cmd == "nudge?" then
        local _, stored = GetProjExtState(0, "ReaClassical", "NudgeMs")
        local ms = tonumber(stored) or 5
        say("Nudge amount: " .. ms .. " milliseconds")
        return true
    end

    local mod_val = cmd:match("^mod=([%d%.]+)$")
    if mod_val then
        local n = tonumber(mod_val)
        if not n or n <= 0 then
            say("mod= requires a positive number")
            return true
        end
        SetProjExtState(0, "ReaClassical", "ModifierFactor", tostring(n))
        say("Modifier set to " .. n)
        return true
    end

    if cmd == "mod?" then
        local _, stored = GetProjExtState(0, "ReaClassical", "ModifierFactor")
        local n = tonumber(stored) or 5
        say("Modifier: " .. n)
        return true
    end

    if cmd == "import" then
        _G.RC_SCRIPT_ARGS = { start_folder_idx = get_start_folder_idx_from_selection() }
        dofile(script_path .. "ReaClassical_Smart Import Audio.lua")
        _G.RC_SCRIPT_ARGS = nil
        return true
    end

    local smart_mode, smart_rest = cmd:match("^import=smart,([123])(.*)$")
    if smart_mode then
        smart_mode = tonumber(smart_mode)
        local args = {}

        if smart_mode == 3 then
            local folder_count = smart_rest:match("^,(%d+)$")
            if not folder_count then
                say("import=smart,3 requires a folder count, e.g. import=smart,3,5")
                return true
            end
            args.robin_folder_count = tonumber(folder_count)
        else
            if smart_rest ~= "" then
                say("Unknown command: " .. cmd)
                return true
            end
            if smart_mode == 2 then
                args.robin_folder_count = "current"
            end
        end

        args.start_folder_idx = get_start_folder_idx_from_selection()
        _G.RC_SCRIPT_ARGS = args
        dofile(script_path .. "ReaClassical_Smart Import Audio.lua")
        _G.RC_SCRIPT_ARGS = nil
        return true
    end

    local import_rest = cmd:match("^import=(%d.*)$")
    if import_rest then
        local take_segments, session_segments, in_session = {}, {}, false
        for seg in (import_rest .. ","):gmatch("([^,]*),") do
            if not in_session and (seg:match("^%d+$") or seg:match("^%d+%-%d+$")) then
                take_segments[#take_segments + 1] = seg
            else
                in_session = true
                session_segments[#session_segments + 1] = seg
            end
        end

        local take_set = #take_segments > 0
            and smart_import_scan.parse_take_range(table.concat(take_segments, ","))
            or nil
        if not take_set then
            say("Please enter a valid take number, range, or list, e.g. import=4 or import=1-3,5,11-15")
            return true
        end

        local take_session = #session_segments > 0 and trim(table.concat(session_segments, ",")) or ""
        _G.RC_SCRIPT_ARGS = {
            start_folder_idx = get_start_folder_idx_from_selection(),
            at_cursor = true,
            filter = {
                take_set = take_set,
                session = take_session ~= "" and take_session or "default",
            },
        }
        dofile(script_path .. "ReaClassical_Smart Import Audio.lua")
        _G.RC_SCRIPT_ARGS = nil
        return true
    end

    return false
end

function restart_reaper()
    Main_OnCommand(40886, 0)
    if IsProjectDirty(0) == 0 then
        Main_OnCommand(40063, 0)
        Main_OnCommand(40004, 0)
    else
        MB("Restart cancelled due to unsaved changes.", "ReaClassical", 0)
    end
end

function windows_arch()
    local arch = os.getenv("PROCESSOR_ARCHITEW6432") or os.getenv("PROCESSOR_ARCHITECTURE") or ""
    return arch:upper()
end

local CLARA_BASE_URL = "https://github.com/chmaha/ReaClassical_Clara/releases/latest/download/"

local CLARA_RELEASES_API = "https://api.github.com/repos/chmaha/ReaClassical_Clara/releases/latest"

local OSARA_FILENAMES = {
    "reaper_osara32.dll", "reaper_osara64.dll", "reaper_osara_arm64ec.dll", "reaper_osara.dylib",
}

function remove_old_osara(userplugins_path, separator)
    local removed_any = false
    for _, filename in ipairs(OSARA_FILENAMES) do
        local path = userplugins_path .. separator .. filename
        local existing = io.open(path, "rb")
        if existing then
            existing:close()
            os.remove(path)
            removed_any = true
        end
    end
    return removed_any
end

function get_latest_clara_version(system)
    local separator = package.config:sub(1, 1)
    local tmp_file = GetResourcePath() .. separator .. "reaclassical_clara_latest.json"
    os.remove(tmp_file)

    local exec_cmd
    if string.find(system, "^Win") then
        exec_cmd = string.format(
            'powershell -NoProfile -ExecutionPolicy Bypass -Command "' ..
            "$ProgressPreference='SilentlyContinue'; " ..
            "Invoke-WebRequest -Uri '%s' -UserAgent 'ReaClassical' -OutFile '%s'" ..
            '"',
            CLARA_RELEASES_API, tmp_file)
    else
        exec_cmd = string.format("curl -fsSL -A 'ReaClassical' -o '%s' '%s'", tmp_file, CLARA_RELEASES_API)
    end

    local ok = os.execute(exec_cmd)
    if not ok then
        os.remove(tmp_file)
        return nil
    end

    local file = io.open(tmp_file, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    os.remove(tmp_file)

    local tag = content:match('"tag_name"%s*:%s*"([^"]+)"')
    return tag and tag:gsub("^v", "") or nil
end

function try_clara_install(cmd)
    if cmd ~= "clara" then return false end

    local system = GetOS()
    local separator = package.config:sub(1, 1)
    local resource_path = GetResourcePath()
    local userplugins_path = resource_path .. separator .. "UserPlugins"

    local exec_cmd, plugin_file
    if string.find(system, "^Win") then
        local filename
        if system == "Win32" then
            filename = "reaper_clara32.dll"
        elseif windows_arch():find("ARM64") then
            filename = "reaper_clara_arm64ec.dll"
        else
            filename = "reaper_clara64.dll"
        end
        local url = CLARA_BASE_URL .. filename
        plugin_file = userplugins_path .. separator .. filename
        exec_cmd = string.format(
            'powershell -NoProfile -ExecutionPolicy Bypass -Command "' ..
            "$ProgressPreference='SilentlyContinue'; " ..
            "Invoke-WebRequest -Uri '%s' -OutFile '%s'" ..
            '"',
            url, plugin_file)
    elseif system == "OSX64" or string.find(system, "^macOS") then
        local url = CLARA_BASE_URL .. "reaper_clara.dylib"
        plugin_file = userplugins_path .. separator .. "reaper_clara.dylib"
        exec_cmd = string.format("curl -fsSL -o '%s' '%s'", plugin_file, url)
    elseif system == "OSX32" then
        say("Clara is not supported on 32-bit Intel macOS")
        return true
    else
        say("Clara is only supported on Windows and macOS")
        return true
    end

    local function do_install()
        say("Downloading and installing Clara, please wait...")
        local ok = os.execute(exec_cmd)
        if not ok then
            say("Failed to download/install Clara. Check your internet connection and try again.")
            return
        end

        local osara_removed = remove_old_osara(userplugins_path, separator)

        local msg = "Clara installed"
        if osara_removed then
            msg = msg .. ", old OSARA plugin removed"
        end
        say(msg .. ". Restarting REAPER...")
        restart_reaper()
    end

    if APIExists("clara_getVersion") then
        local installed_version = reaper.clara_getVersion()
        local latest_version = get_latest_clara_version(system)
        if latest_version and installed_version == latest_version then
            local prompt = string.format(
                "Clara is already up to date (version %s)." ..
                "\n\nForce reinstall anyway? REAPER will restart afterwards.",
                installed_version)
            local response = MB(prompt, "Install Clara", 4)
            if response ~= 6 then return true end
            do_install()
            return true
        end
    end

    local already_installed = false
    local existing = io.open(plugin_file, "rb")
    if existing then
        existing:close()
        already_installed = true
    end

    local prompt
    if already_installed then
        prompt = "Clara already appears to be installed in UserPlugins." ..
            "\n\nReinstall it anyway? REAPER will restart afterwards."
    else
        prompt = "This will download Clara and install it into REAPER's" ..
            "\nUserPlugins folder, then restart REAPER to load it." ..
            "\n\nAre you sure you want to continue?"
    end

    local response = MB(prompt, "Install Clara", 4)
    if response ~= 6 then return true end

    do_install()
    return true
end

function try_update_reaper(cmd)
    if cmd ~= "reaper" and not cmd:match("^reaper=") then return false end

    local version = cmd:match("^reaper=(.+)$")
    local mode = "recommended"
    if version then
        local lower = version:lower()
        if lower == "rec" or lower == "recommended" then
            mode = "recommended"
        elseif lower == "latest" then
            mode = "latest"
        else
            mode = "version"
        end
    end
    SetExtState("ReaClassical_UpdateReaper", "mode", mode, false)
    if mode == "version" then
        SetExtState("ReaClassical_UpdateReaper", "version", version, false)
    end

    local update_cid = AddRemoveReaScript(true, 0,
        script_path .. "lib/ReaClassical_Update REAPER.lua", true)
    if update_cid == 0 then
        say("Update REAPER script not found")
        return true
    end
    Main_OnCommand(update_cid, 0)
    return true
end

function is_unrepeatable_command(full_input)
    local first = trim(full_input:match("^([^;]+)") or "")
    if first == "help" or first == "clara"
        or first == "reaper" or first:match("^reaper=") then
        return true
    end
    return false
end

local POWER_MIXER_OPS = {
    ["m"] = true, ["um"] = true, ["s"] = true, ["us"] = true, ["xs"] = true,
    ["m?"] = true, ["s?"] = true,
    ["i=y"] = true, ["i=n"] = true, ["i?"] = true,
    ["p?"] = true, ["f?"] = true, ["pk?"] = true,
}

local function is_power_mixer_command(cmd)
    local target_str, rest = mixer_core.split_word_target(cmd)
    if not target_str then
        target_str, rest = cmd:match("^([%#@]?[%d,%-%*%s]*)(.+)$")
    end
    if not target_str or not rest or rest == "" then return false end
    if POWER_MIXER_OPS[rest] then return true end
    if rest:match("^p[+-]%d+$") or rest:match("^p=[+-]?%d+$") then return true end
    if rest:match("^f[+-]%d+$") or rest:match("^f=[+-]?%d+$") then return true end
    return false
end

local function is_allowed_interactive(cmd)
    if cmd == "help" then return true end
    if cmd == "clara" then return true end
    if cmd == "reaper" or cmd:match("^reaper=") then return true end
    if cmd == "import" or cmd:match("^import=") then return true end
    if cmd:match("^nudge=") or cmd == "nudge?" then return true end
    if cmd:match("^mod=") or cmd == "mod?" then return true end
    if cmd == "convert=h" or cmd == "convert=v" then return true end
    if cmd:match("^debug=") or cmd == "debug?" then return true end
    return is_power_mixer_command(cmd)
end

function execute_command(cmd)
    if cmd == "" then return end

    if terminal_interactive and not is_allowed_interactive(cmd) then
        say("Unknown command: " .. cmd)
        return
    end

    if track_setup_commands.try_project_setup(cmd) then return end
    if track_setup_commands.try_input_config(cmd) then return end
    if try_mute_solo(cmd) then return end
    if try_pan(cmd) then return end
    if try_fader(cmd) then return end
    if try_peak(cmd) then return end
    if track_setup_commands.try_reorder(cmd) then return end
    if track_setup_commands.try_add_remove(cmd) then return end
    if track_setup_commands.try_routing_fx(cmd) then return end
    if try_misc(cmd) then return end
    if try_clara_install(cmd) then return end
    if try_update_reaper(cmd) then return end

    say("Unknown command: " .. cmd)
end

function main()
    local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
    workflow = wf

    local input
    local repeating = _G.RC_REPEAT_LAST == true or _G.RC_RUN_COMMAND ~= nil
    terminal_interactive = _G.RC_RUN_COMMAND == nil

    if _G.RC_RUN_COMMAND then
        input = _G.RC_RUN_COMMAND
    elseif _G.RC_REPEAT_LAST == true then
        local _, last = GetProjExtState(0, "ReaClassical", "LastTerminalCommand")
        if last == "" then
            say("No previous command to repeat")
            return
        end
        input = last
    else
        local retval, user_input = GetUserInputs("ReaClassical Terminal", 1, "Command:,extrawidth=300", "")
        if not retval then return end
        input = trim(user_input)

        if input == "!" then
            local _, last = GetProjExtState(0, "ReaClassical", "LastTerminalCommand")
            if last == "" then
                say("No previous command to repeat")
                return
            end
            input = last
        elseif input ~= "" and not is_unrepeatable_command(input) then
            SetProjExtState(0, "ReaClassical", "LastTerminalCommand", input)
        end
    end

    local commands = {}
    for raw_cmd in input:gmatch("[^;]+") do
        local c = trim(raw_cmd)
        if c ~= "" then table.insert(commands, c) end
    end
    if #commands == 0 then return end

    local dialog_closed_time = time_precise()
    local function run_commands()
        if not repeating and time_precise() - dialog_closed_time < 0.2 then
            defer(run_commands)
            return
        end

        if workflow == "" then
            local first = commands[1]
            if not (first == "clara" or first == "help"
                    or first == "reaper" or first:match("^reaper=")
                    or first == "debug=on" or first == "debug=off") then
                say("Please create a ReaClassical project first via Ctrl+N (Cmd+N on macOS)")
                return
            end
        end

        Undo_BeginBlock()
        for _, c in ipairs(commands) do
            execute_command(c)
        end
        Undo_EndBlock("ReaClassical Terminal: " .. input, -1)
        UpdateArrange()
    end
    run_commands()
end

main()
