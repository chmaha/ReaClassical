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

local _gm_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. _gm_path .. "?.lua;" .. _gm_path .. "lib/?.lua;"
local gui_mode = require("ReaClassical_GuiMode")

local _clara_or_debug = not _G.RC_SCRIPT_ARGS and gui_mode.accessible()
if _clara_or_debug then
    local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
    dofile(script_path .. "lib/ReaClassical_Accessible Distribute Takes.lua")
    return
end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")

local render_settings = require("ReaClassical_Render_Settings")
local enum_project_markers = require("ReaClassical_Marker_Enum")
local samplerate_list = render_settings.samplerate_list
local samplerate_labels = render_settings.samplerate_labels
local bitdepth_list = render_settings.bitdepth_list
local bitdepth_labels = render_settings.bitdepth_labels
local dither_list = render_settings.dither_list

local render_samplerate, render_bitdepth, render_dither = render_settings.load()

local main, run_distribute, is_special_track, get_rc_folders, get_folder_children
local clear_all_regions, create_regions_for_track
local save_render_settings, restore_render_settings
local save_track_mute_state, restore_track_mute_state
local solo_folder_for_render, ensure_dir
local get_export_subdir, apply_format_render_settings, render_export
local get_item_take_num, parse_take_list, build_take_filter

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists and not _G.RC_SCRIPT_ARGS then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
    local modifier = "Ctrl"
    local system = GetOS()
    if string.find(system, "^OSX") or string.find(system, "^macOS") then
        modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier
        .. "+N to use this function.", "ReaClassical Error", 0)
    return
end

set_action_options(2)

local ImGui, ctx
local window_open = true

if not _G.RC_SCRIPT_ARGS then
    package.path = ImGui_GetBuiltinPath() .. '/?.lua'
    ImGui = require 'imgui' '0.10'
    ctx = ImGui.CreateContext('ReaClassical Distribute Takes')
end

local EXPORT_FORMATS = {
    { key = "wav",  label = "WAV" },
    { key = "flac", label = "FLAC" },
    { key = "opus", label = "Opus 160" },
    { key = "mp3",  label = "MP3 320" },
}

local TAKE_MODES = {
    { key = "all",      label = "All takes",      tooltip = "Export every take" },
    { key = "list",     label = "Take list",      tooltip = "Export takes by number, e.g. 1,4-6,7" },
    { key = "selected", label = "Selected items", tooltip = "Export selected parent items" },
    { key = "time",     label = "Time selection", tooltip = "Export takes overlapping the time selection" },
}

local take_mode = "all"
local take_list_text = ""

function is_special_track(track)
    local keys = { "mixer", "aux", "submix", "roomtone", "live", "rcref", "listenback", "rcmaster", "playback" }
    for _, key in ipairs(keys) do
        local _, val = GetSetMediaTrackInfo_String(track, "P_EXT:" .. key, "", false)
        if val == "y" then return true end
    end
    return false
end

function get_rc_folders()
    local folders = {}
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 and not is_special_track(track) then
            table.insert(folders, track)
        end
    end
    return folders
end

function get_folder_children(parent_track)
    local children = {}
    if not parent_track then return children end
    local parent_idx = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local idx = parent_idx + 1
    local depth = 1
    while idx < num_tracks and depth > 0 do
        local tr = GetTrack(0, idx)
        if not tr then break end
        local folder_depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
        table.insert(children, tr)
        depth = depth + folder_depth
        if depth <= 0 then break end
        idx = idx + 1
    end
    return children
end

function clear_all_regions()
    local to_delete = {}
    local i = 0
    while true do
        local ret, isrgn, _, _, _, idx = enum_project_markers(0, i)
        if not ret then break end
        if isrgn then table.insert(to_delete, idx) end
        i = i + 1
    end
    for _, idx in ipairs(to_delete) do
        DeleteProjectMarker(0, idx, true)
    end
end

function get_item_take_num(item)
    local _, stored = GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", "", false)
    local num = tonumber(stored)
    if num then return num end
    local take = GetActiveTake(item)
    if not take then return nil end
    local filename = GetMediaSourceFileName(GetMediaItemTake_Source(take), "")
    num = tonumber(filename:match("_T?(%d+)%.[^%.]+$"))
    if num then return num end
    local _, raw_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    local clean = (raw_name:match("^(.-)%s*|") or raw_name):match("^%s*(.-)%s*$")
    return tonumber(clean:match("_T?(%d+)$") or clean:match("^(%d+)$"))
end

function parse_take_list(text)
    local set = {}
    local any = false
    for part in text:gmatch("[^,]+") do
        part = part:match("^%s*(.-)%s*$")
        if part ~= "" then
            local a, b = part:match("^(%d+)%s*%-%s*(%d+)$")
            if a then
                a, b = tonumber(a), tonumber(b)
                if a > b then a, b = b, a end
                for n = a, b do set[n] = true end
                any = true
            elseif part:match("^%d+$") then
                set[tonumber(part)] = true
                any = true
            else
                return nil, "Invalid take list entry: \"" .. part .. "\".\nUse numbers and ranges, e.g. 1,4-6,7"
            end
        end
    end
    if not any then return nil, "Please enter at least one take number, e.g. 1,4-6,7" end
    return set
end

function build_take_filter(mode, list_text)
    if mode == "list" then
        local set, err = parse_take_list(list_text or "")
        if not set then return nil, err end
        return function(item)
            local num = get_item_take_num(item)
            return num ~= nil and set[num] == true
        end
    elseif mode == "selected" then
        if CountSelectedMediaItems(0) == 0 then
            return nil, "Please select one or more parent items to export."
        end
        return function(item) return IsMediaItemSelected(item) end
    elseif mode == "time" then
        local ts_start, ts_end = GetSet_LoopTimeRange(false, false, 0, 0, false)
        if ts_end <= ts_start then
            return nil, "Please make a time selection covering the takes to export."
        end
        return function(item)
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local len = GetMediaItemInfo_Value(item, "D_LENGTH")
            return pos < ts_end and pos + len > ts_start
        end
    end
    return function() return true end
end

function create_regions_for_track(folder_track, name_prefix, filter)
    local count = 0
    local num_items = GetTrackNumMediaItems(folder_track)
    for i = 0, num_items - 1 do
        local item = GetTrackMediaItem(folder_track, i)
        local take = GetActiveTake(item)
        if take and filter(item) then
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local len = GetMediaItemInfo_Value(item, "D_LENGTH")
            local _, raw_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            local clean = (raw_name:match("^(.-)%s*|") or raw_name):match("^%s*(.-)%s*$")
            local region_name = (name_prefix ~= "" and clean ~= "")
                and (name_prefix .. " " .. clean)
                or (name_prefix ~= "" and name_prefix or clean)
            if region_name ~= "" then
                AddProjectMarker2(0, true, pos, pos + len, region_name, -1, 0)
                count = count + 1
            end
        end
    end
    return count
end

function save_render_settings()
    local proj = 0
    local s = {}
    local _, fmt = GetSetProjectInfo_String(proj, "RENDER_FORMAT", "", false)
    s.format = fmt
    s.srate       = GetSetProjectInfo(proj, "RENDER_SRATE", 0, false)
    s.channels    = GetSetProjectInfo(proj, "RENDER_CHANNELS", 0, false)
    s.boundsflag  = GetSetProjectInfo(proj, "RENDER_BOUNDSFLAG", 0, false)
    s.renderset   = GetSetProjectInfo(proj, "RENDER_SETTINGS", 0, false)
    s.dither      = GetSetProjectInfo(proj, "RENDER_DITHER", 0, false)
    local _, file = GetSetProjectInfo_String(proj, "RENDER_FILE", "", false)
    s.file = file
    local _, pat  = GetSetProjectInfo_String(proj, "RENDER_PATTERN", "", false)
    s.pattern = pat
    return s
end

function restore_render_settings(s)
    local proj = 0
    GetSetProjectInfo_String(proj, "RENDER_FORMAT", s.format, true)
    GetSetProjectInfo(proj, "RENDER_SRATE",      s.srate,      true)
    GetSetProjectInfo(proj, "RENDER_CHANNELS",   s.channels,   true)
    GetSetProjectInfo(proj, "RENDER_BOUNDSFLAG", s.boundsflag, true)
    GetSetProjectInfo(proj, "RENDER_SETTINGS",   s.renderset,  true)
    GetSetProjectInfo(proj, "RENDER_DITHER",     s.dither,     true)
    GetSetProjectInfo_String(proj, "RENDER_FILE",    s.file,    true)
    GetSetProjectInfo_String(proj, "RENDER_PATTERN", s.pattern, true)
end

function save_track_mute_state()
    local state = {}
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        state[i] = {
            mute = GetMediaTrackInfo_Value(track, "B_MUTE"),
            solo = GetMediaTrackInfo_Value(track, "I_SOLO"),
        }
    end
    return state
end

function restore_track_mute_state(state)
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if state[i] then
            SetMediaTrackInfo_Value(track, "B_MUTE", state[i].mute)
            SetMediaTrackInfo_Value(track, "I_SOLO", state[i].solo)
        end
    end
end

function solo_folder_for_render(folder_track)
    local children = get_folder_children(folder_track)
    local keep = { [folder_track] = true }
    for _, c in ipairs(children) do keep[c] = true end

    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if is_special_track(track) then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        elseif keep[track] then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        else
            SetMediaTrackInfo_Value(track, "B_MUTE", 1)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end
    end
end

function ensure_dir(abs_path)
    RecursiveCreateDirectory(abs_path, 0)
end

function get_export_subdir(format)
    if format == "wav" then return string.format("WAV_%d_%d", render_samplerate, render_bitdepth) end
    if format == "flac" then return string.format("FLAC_%d_%d", render_samplerate, render_bitdepth) end
    if format == "opus" then return "OPUS_160" end
    return "MP3_320"
end

function apply_format_render_settings(format)
    local proj = 0
    if format == "wav" then
        GetSetProjectInfo_String(proj, "RENDER_FORMAT", render_settings.build_wav_format(render_bitdepth), true)
        GetSetProjectInfo(proj, "RENDER_SRATE", render_samplerate, true)
        GetSetProjectInfo(proj, "RENDER_DITHER", render_settings.dither_value_for(render_bitdepth, render_dither), true)
    elseif format == "flac" then
        GetSetProjectInfo_String(proj, "RENDER_FORMAT", render_settings.build_flac_format(render_bitdepth), true)
        GetSetProjectInfo(proj, "RENDER_SRATE", render_samplerate, true)
        GetSetProjectInfo(proj, "RENDER_DITHER", render_settings.dither_value_for(render_bitdepth, render_dither), true)
    elseif format == "opus" then
        GetSetProjectInfo_String(proj, "RENDER_FORMAT", "U2dnTwAAIEMACgAAAAIAAAA=", true)
        GetSetProjectInfo(proj, "RENDER_SRATE", 48000, true)
        GetSetProjectInfo(proj, "RENDER_DITHER", 0, true)
    elseif format == "mp3" then
        GetSetProjectInfo_String(proj, "RENDER_FORMAT", "bDNwbUABAAAAAAAAAgAAAP////8EAAAAQAEAAAAAAAA=", true)
        GetSetProjectInfo(proj, "RENDER_SRATE", render_settings.mp3_samplerate_for(render_samplerate), true)
        GetSetProjectInfo(proj, "RENDER_DITHER", 0, true)
    end
    GetSetProjectInfo(proj, "RENDER_CHANNELS", 2, true)
    GetSetProjectInfo(proj, "RENDER_BOUNDSFLAG", 3, true)
    GetSetProjectInfo(proj, "RENDER_SETTINGS", 0, true)
end

function render_export(rel_dir)
    local proj = 0
    GetSetProjectInfo_String(proj, "RENDER_FILE", rel_dir, true)
    GetSetProjectInfo_String(proj, "RENDER_PATTERN", "$region", true)
    Main_OnCommand(42230, 0)
end

function run_distribute(format, mode, list_text)
    local slash = package.config:sub(1, 1)
    local proj_path = GetProjectPath()
    if proj_path == "" then
        return false, "Please save the project before distributing takes."
    end

    local filter, filter_err = build_take_filter(mode or "all", list_text)
    if not filter then return false, filter_err end
    local none_msg = (mode == nil or mode == "all") and "No items with takes found" or "No matching takes found"

    local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")

    local subdir = get_export_subdir(format)
    local base_rel = "Exports/Distribute_Takes/" .. subdir .. "/"
    local base_abs = proj_path .. slash .. "Exports" .. slash .. "Distribute_Takes" .. slash .. subdir
    ensure_dir(base_abs)

    local saved_render = save_render_settings()
    apply_format_render_settings(format)

    Undo_BeginBlock()
    PreventUIRefresh(1)

    clear_all_regions()

    local msg
    if wf == "Horizontal" then
        local folders = get_rc_folders()
        if #folders == 0 then
            msg = "No ReaClassical folders found"
        else
            local folder_track = folders[1]
            local count = create_regions_for_track(folder_track, "", filter)
            if count == 0 then
                msg = none_msg
                clear_all_regions()
            else
                render_export(base_rel)
                clear_all_regions()
                msg = count .. " take" .. (count == 1 and "" or "s") .. " distributed to " .. base_rel
            end
        end
    elseif wf == "Vertical" then
        local folders = get_rc_folders()
        if #folders == 0 then
            msg = "No ReaClassical folders found"
        else
            local mute_state = save_track_mute_state()
            local total = 0

            for _, folder_track in ipairs(folders) do
                solo_folder_for_render(folder_track)

                local count = create_regions_for_track(folder_track, "", filter)
                if count > 0 then
                    render_export(base_rel)
                    total = total + count
                end
                clear_all_regions()
            end

            restore_track_mute_state(mute_state)

            if total == 0 then
                msg = none_msg
            else
                msg = total .. " take" .. (total == 1 and "" or "s") .. " distributed to " .. base_rel
            end
        end
    else
        msg = "Unknown workflow"
    end

    PreventUIRefresh(-1)
    restore_render_settings(saved_render)
    Undo_EndBlock("Distribute Takes", -1)
    UpdateArrange()
    UpdateTimeline()

    return true, msg
end

function main()
    if not window_open then return end

    ImGui.SetNextWindowSizeConstraints(ctx, 480, 0, math.huge, math.huge)
    local opened, open_ref = ImGui.Begin(ctx, "ReaClassical Distribute Takes", window_open,
        ImGui.WindowFlags_AlwaysAutoResize)
    window_open = open_ref

    if opened then
        ImGui.Text(ctx, "Render settings:")
        ImGui.SameLine(ctx)

        local srate_preview = "44.1 kHz"
        for idx, sr in ipairs(samplerate_list) do
            if sr == render_samplerate then srate_preview = samplerate_labels[idx] end
        end
        ImGui.SetNextItemWidth(ctx, 100)
        if ImGui.BeginCombo(ctx, "##render_samplerate", srate_preview) then
            for idx, sr in ipairs(samplerate_list) do
                local is_sel = (render_samplerate == sr)
                if ImGui.Selectable(ctx, samplerate_labels[idx], is_sel) then
                    render_samplerate = sr
                    render_settings.save_samplerate(sr)
                end
                if is_sel then ImGui.SetItemDefaultFocus(ctx) end
            end
            ImGui.EndCombo(ctx)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Render sample rate (WAV / FLAC)")
        end

        ImGui.SameLine(ctx)
        local bitdepth_preview = "16-bit"
        for idx, bd in ipairs(bitdepth_list) do
            if bd == render_bitdepth then bitdepth_preview = bitdepth_labels[idx] end
        end
        ImGui.SetNextItemWidth(ctx, 100)
        if ImGui.BeginCombo(ctx, "##render_bitdepth", bitdepth_preview) then
            for idx, bd in ipairs(bitdepth_list) do
                local is_sel = (render_bitdepth == bd)
                if ImGui.Selectable(ctx, bitdepth_labels[idx], is_sel) then
                    render_bitdepth = bd
                    render_settings.save_bitdepth(bd)
                    if bd ~= 16 then
                        render_dither = "Off"
                        render_settings.save_dither("Off")
                    end
                end
                if is_sel then ImGui.SetItemDefaultFocus(ctx) end
            end
            ImGui.EndCombo(ctx)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Render bit depth (WAV / FLAC)")
        end

        ImGui.SameLine(ctx)
        local dither_disabled = render_bitdepth ~= 16
        if dither_disabled then ImGui.BeginDisabled(ctx) end
        ImGui.SetNextItemWidth(ctx, 120)
        if ImGui.BeginCombo(ctx, "##render_dither", render_dither) then
            for _, d in ipairs(dither_list) do
                local is_sel = (render_dither == d)
                if ImGui.Selectable(ctx, d, is_sel) then
                    render_dither = d
                    render_settings.save_dither(d)
                end
                if is_sel then ImGui.SetItemDefaultFocus(ctx) end
            end
            ImGui.EndCombo(ctx)
        end
        if dither_disabled then ImGui.EndDisabled(ctx) end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx,
                "Dither, 16-bit only (WAV / FLAC)\n"
                .. "Triangular: light dither, unshaped\n"
                .. "HP filtered: dither + noise shaping\n"
                .. "Noise shaping: noise shaping alone, no dither\n"
                .. "Off: neither")
        end

        ImGui.Dummy(ctx, 0, 10)
        ImGui.Separator(ctx)
        ImGui.Dummy(ctx, 0, 5)

        ImGui.Text(ctx, "Takes:")
        ImGui.SameLine(ctx)
        for i, m in ipairs(TAKE_MODES) do
            if i > 1 then ImGui.SameLine(ctx) end
            if ImGui.RadioButton(ctx, m.label, take_mode == m.key) then
                take_mode = m.key
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, m.tooltip)
            end
        end
        local list_disabled = take_mode ~= "list"
        if list_disabled then ImGui.BeginDisabled(ctx) end
        ImGui.SetNextItemWidth(ctx, -1)
        local _, new_text = ImGui.InputTextWithHint(ctx, "##take_list", "e.g. 1,4-6,7", take_list_text)
        take_list_text = new_text
        if list_disabled then ImGui.EndDisabled(ctx) end

        ImGui.Dummy(ctx, 0, 5)
        ImGui.Separator(ctx)
        ImGui.Dummy(ctx, 0, 5)

        ImGui.Text(ctx, "Export:")
        ImGui.SameLine(ctx)
        for i, f in ipairs(EXPORT_FORMATS) do
            if i > 1 then ImGui.SameLine(ctx) end
            if ImGui.Button(ctx, f.label) then
                local ok, msg = run_distribute(f.key, take_mode, take_list_text)
                if ok then
                    say(msg)
                else
                    MB(msg, "ReaClassical Error", 0)
                end
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Export takes as " .. f.label)
            end
        end

        if not ImGui.IsAnyItemActive(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
            window_open = false
        end
        if gui_mode.imgui_close_shortcut(ImGui, ctx) then window_open = false end

        ImGui.End(ctx)
    end

    if window_open then
        defer(main)
    end
end

if _G.RC_SCRIPT_ARGS then
    local args = _G.RC_SCRIPT_ARGS
    if args.action == "distribute" then
        local ok, msg = run_distribute(args.format, args.mode, args.takes)
        say(msg)
        if not ok then return end
    end
    return
end

defer(main)
