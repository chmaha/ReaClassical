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

-- Headless Record Panel daemon.
-- Run once to start; run again to stop (toggle via set_action_options(1)).
-- Mirrors the take-counter, recfile_wildcards, item coloring, and track disarm
-- logic of ReaClassical_Record Panel.lua without any ImGui GUI.
-- When running, it sets the Record Panel's toggle state so F9 (Classical Take
-- Record) works without opening the Panel GUI.

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

set_action_options(1)

if not APIExists("SNM_SetStringConfigVar") then
    MB("Please install SWS/S&M extension before running this function", "Error: Missing Extension", 0)
    return
end

---------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------

local RECORD_PANEL_ID = NamedCommandLookup("_RSbd41ad183cae7b18bccb86b087f719e945278160")
local separator   = package.config:sub(1, 1)
local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
local _, prev_recfilename = get_config_var_string("recfile_wildcards")

local rec_color      = ColorToNative(255, 0, 0)    | 0x1000000
local recpause_color = ColorToNative(255, 255, 127) | 0x1000000

local RANKS = {
    { name = "Excellent",     rgba = 0x39FF1499, prefix = "Excellent" },
    { name = "Very Good",     rgba = 0x32CD3299, prefix = "Very Good" },
    { name = "Good",          rgba = 0x00AD8399, prefix = "Good" },
    { name = "OK",            rgba = 0xFFFFAA99, prefix = "OK" },
    { name = "Below Average", rgba = 0xFFBF0099, prefix = "Below Average" },
    { name = "Poor",          rgba = 0xFF753899, prefix = "Poor" },
    { name = "Unusable",      rgba = 0xDC143C99, prefix = "Unusable" },
    { name = "False Start",   rgba = 0x2A2A2AFF, prefix = "False Start" },
    { name = "No Rank",       rgba = 0x00000000, prefix = "" },
}

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------

local take_count         = 0
local take_text          = 0
local iterated_filenames = false
local session            = ""
local session_dir        = ""
local session_suffix     = ""
local last_session       = nil
local last_play_state    = nil
local last_project       = EnumProjects(-1)
local last_recorded_take = 0
local color_run_once     = false
local auto_color_pref    = 0
local ranking_color_pref = 0
local recording_rank     = ""
local recording_note     = ""

local _, _init_override = GetProjExtState(0, "ReaClassical", "TakeCounterOverride")
local last_override = _init_override

-- Re-arm any listenback tracks at startup (matches Record Panel startup behaviour)
do
    local n = CountTracks(0)
    for i = 0, n - 1 do
        local t = GetTrack(0, i)
        local _, lb = GetSetMediaTrackInfo_String(t, "P_EXT:listenback", "", false)
        if lb == "y" then SetMediaTrackInfo_Value(t, "I_RECARM", 1) end
    end
end

---------------------------------------------------------------------
-- Preference reader
---------------------------------------------------------------------

local function check_prefs()
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    if input ~= "" then
        local t = {}
        for entry in input:gmatch("([^,]+)") do t[#t + 1] = entry end
        if t[5] then auto_color_pref    = tonumber(t[5]) or 0 end
        if t[6] then ranking_color_pref = tonumber(t[6]) or 0 end
    end
end

check_prefs()

---------------------------------------------------------------------
-- Take count / wildcard helpers
---------------------------------------------------------------------

local function do_get_take_count(session_name)
    take_count = 0
    local media_path = GetProjectPath(0)
    local i = 0
    while true do
        local filename = EnumerateFiles(media_path .. separator .. session_name, i)
        if not filename then break end
        local n = tonumber(filename:match(".*[^%d](%d+)%)?%.%a+$"))
        if n and n > take_count then take_count = n end
        i = i + 1
    end
    local ps = GetPlayState()
    if (ps == 5 or ps == 6) and take_count > 0 then take_count = take_count - 1 end
    iterated_filenames = true
    return take_count
end

local function update_wildcards()
    local padded = string.format("%03d", math.max(1, tonumber(take_text) or 1))
    SNM_SetStringConfigVar("recfile_wildcards",
        session_dir .. session_suffix .. "$tracknameornumber_T" .. padded)
    SetProjExtState(0, "ReaClassical", "CurrentTakeNumber", tostring(take_text))
end

---------------------------------------------------------------------
-- Per-frame session / override checks
---------------------------------------------------------------------

local function check_session_change()
    local _, new_session = GetProjExtState(0, "ReaClassical", "TakeSessionName")
    if new_session ~= last_session then
        last_session       = new_session
        session            = new_session
        session_dir        = session ~= "" and (session .. separator) or ""
        session_suffix     = session ~= "" and (session .. "_")       or ""
        iterated_filenames = false
    end
end

local function check_override()
    local ps = GetPlayState()
    if ps == 5 or ps == 6 then return end

    local _, override = GetProjExtState(0, "ReaClassical", "TakeCounterOverride")

    if last_override == "1" and (override == "0" or override == "") then
        iterated_filenames = false
    end
    if override == "1" then
        local _, cur = GetProjExtState(0, "ReaClassical", "CurrentTakeNumber")
        local n = tonumber(cur)
        if n and n ~= take_text then
            take_count        = n - 1
            take_text         = n
            iterated_filenames = true
        end
    end

    last_override = override
end

---------------------------------------------------------------------
-- Item coloring helpers (mirrored from ReaClassical_Record Panel.lua)
---------------------------------------------------------------------

local function rgba_to_native(rgba)
    local r = (rgba >> 24) & 0xFF
    local g = (rgba >> 16) & 0xFF
    local b = (rgba >> 8) & 0xFF
    return ColorToNative(r, g, b)
end

local function pastel_color(index)
    local golden_ratio_conjugate = 0.61803398875
    local hue         = (index * golden_ratio_conjugate) % 1.0
    local saturation  = 0.45 + 0.15 * math.sin(index * 1.7)
    local lightness   = 0.70 + 0.1  * math.cos(index * 1.1)

    local function h2rgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1/6 then return p + (q - p) * 6 * t end
        if t < 1/2 then return q end
        if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
        return p
    end

    local q = lightness < 0.5 and (lightness * (1 + saturation))
              or (lightness + saturation - lightness * saturation)
    local p = 2 * lightness - q

    return ColorToNative(
        math.floor(h2rgb(p, q, hue + 1/3) * 255 + 0.5),
        math.floor(h2rgb(p, q, hue)       * 255 + 0.5),
        math.floor(h2rgb(p, q, hue - 1/3) * 255 + 0.5)
    ) | 0x1000000
end

local function get_color_table()
    package.path = package.path .. ";" .. script_path .. "?.lua;"
    return require("ReaClassical_Colors_Table")
end

local function get_item_color(item)
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    local colors      = get_color_table()
    local color_to_use

    local _, saved_guid = GetSetMediaItemInfo_String(item, "P_EXT:src_guid", "", false)
    if saved_guid ~= "" then
        local total = CountMediaItems(0)
        for i = 0, total - 1 do
            local test = GetMediaItem(0, i)
            local _, tg = GetSetMediaItemInfo_String(test, "GUID", "", false)
            if tg == saved_guid then
                color_to_use = GetMediaItemInfo_Value(test, "I_CUSTOMCOLOR")
                break
            end
        end
    end

    if workflow == "Horizontal" then
        local _, saved_color = GetSetMediaItemInfo_String(item, "P_EXT:saved_color", "", false)
        if saved_color ~= "" then
            color_to_use = tonumber(saved_color)
        else
            color_to_use = GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
        end
    elseif not color_to_use then
        local item_track  = GetMediaItemTrack(item)
        local num_tracks  = CountTracks(0)
        local folder_tracks = {}
        for t = 0, num_tracks - 1 do
            local tr = GetTrack(0, t)
            if GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") > 0 then
                folder_tracks[#folder_tracks + 1] = tr
            end
        end

        local parent_folder
        local track_idx = GetMediaTrackInfo_Value(item_track, "IP_TRACKNUMBER") - 1
        for t = track_idx, 0, -1 do
            local tr = GetTrack(0, t)
            if GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") > 0 then
                parent_folder = tr
                break
            end
        end

        if parent_folder then
            local folder_index = 0
            for i, tr in ipairs(folder_tracks) do
                if tr == parent_folder then folder_index = i - 2; break end
            end
            color_to_use = folder_index < 0 and colors.dest_items or pastel_color(folder_index)
        else
            color_to_use = colors.dest_items
        end
    end

    return color_to_use
end

local function update_take_name(item, rank)
    local take = GetActiveTake(item)
    if not take then return end
    local _, item_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    local all_prefixes = { "Excellent", "Very Good", "Good", "OK", "Below Average",
                           "Poor", "Unusable", "False Start" }
    for _, prefix in ipairs(all_prefixes) do
        item_name = item_name:gsub("^" .. prefix .. "%-", "")
        item_name = item_name:gsub("^" .. prefix .. "$", "")
    end
    if rank ~= "" then
        local rank_index = tonumber(rank)
        if rank_index and RANKS[rank_index] and RANKS[rank_index].prefix ~= "" then
            item_name = item_name ~= "" and (RANKS[rank_index].prefix .. "-" .. item_name)
                        or RANKS[rank_index].prefix
        end
    end
    GetSetMediaItemTakeInfo_String(take, "P_NAME", item_name, true)
end

local function apply_rank_and_notes_to_item(item)
    local _, colorized = GetSetMediaItemInfo_String(item, "P_EXT:colorized", "", false)
    local is_colorized = (colorized == "y")

    if recording_rank ~= "" then
        if is_colorized then GetSetMediaItemInfo_String(item, "P_EXT:colorized", "", true) end
        GetSetMediaItemInfo_String(item, "P_EXT:item_rank", recording_rank, true)
        if ranking_color_pref == 0 then
            local rank_index = tonumber(recording_rank)
            if rank_index and RANKS[rank_index] then
                SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR",
                    rgba_to_native(RANKS[rank_index].rgba) | 0x1000000)
            end
        end
        update_take_name(item, recording_rank)
    else
        GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", true)
        if not is_colorized then
            if auto_color_pref == 0 then
                local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
                local color_to_use
                if workflow == "Horizontal" then
                    color_to_use = take_text and pastel_color(take_text - 1)
                                   or get_item_color(item)
                else
                    color_to_use = get_item_color(item)
                end
                SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color_to_use)
            else
                SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", 0)
            end
        end
        update_take_name(item, "")
    end

    GetSetMediaItemInfo_String(item, "P_NOTES", recording_note, true)
    GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", tostring(take_text), true)
    UpdateItemInProject(item)
end

local function apply_rank_and_notes_by_guids()
    local _, guid_str = GetProjExtState(0, "ReaClassical", "LastRecordedItemGUIDs")
    if not guid_str or guid_str == "" then return end

    local target_guids = {}
    for guid in guid_str:gmatch("([^,]+)") do target_guids[guid] = true end

    local total = CountMediaItems(0)
    for i = 0, total - 1 do
        local item = GetMediaItem(0, i)
        local _, guid = GetSetMediaItemInfo_String(item, "GUID", "", false)
        if guid and target_guids[guid] then
            apply_rank_and_notes_to_item(item)
        end
    end
    UpdateArrange()
end

---------------------------------------------------------------------
-- Track disarm (mirrors Record Panel's disarm_all_tracks)
---------------------------------------------------------------------

local function disarm_all_tracks()
    if GetPlayState() == 5 or GetPlayState() == 6 then return end
    local n = CountTracks(0)
    for i = 0, n - 1 do
        local t = GetTrack(0, i)
        if GetMediaTrackInfo_Value(t, "I_RECARM") == 1 then
            SetMediaTrackInfo_Value(t, "I_RECARM", 0)
        end
    end
    for i = 0, n - 1 do
        local t = GetTrack(0, i)
        local _, lb = GetSetMediaTrackInfo_String(t, "P_EXT:listenback", "", false)
        if lb == "y" then SetMediaTrackInfo_Value(t, "I_RECARM", 1) end
    end
end

---------------------------------------------------------------------
-- Main defer loop
---------------------------------------------------------------------

local function main()
    -- Self-stop if terminal requested it via ext state
    local _, stop_sig = GetProjExtState(0, "ReaClassical", "rec_daemon_stop")
    if stop_sig == "1" then
        SetProjExtState(0, "ReaClassical", "rec_daemon_stop", "")
        if RECORD_PANEL_ID ~= 0 then SetToggleCommandState(1, RECORD_PANEL_ID, 0) end
        SNM_SetStringConfigVar("recfile_wildcards", prev_recfilename)
        SetThemeColor("ts_lane_bg",     -1)
        SetThemeColor("marker_lane_bg", -1)
        SetThemeColor("region_lane_bg", -1)
        disarm_all_tracks()
        return  -- no defer: daemon exits naturally
    end

    -- Reset state on project change
    local proj = EnumProjects(-1)
    if proj ~= last_project then
        last_project       = proj
        take_count         = 0
        take_text          = 0
        iterated_filenames = false
        session            = ""
        session_dir        = ""
        session_suffix     = ""
        last_session       = nil
        last_override      = nil
        last_play_state    = nil
        color_run_once     = false
        last_recorded_take = 0
        recording_rank     = ""
        recording_note     = ""
    end

    check_session_change()
    check_override()

    local playstate = GetPlayState()

    -- Timeline lane colors: only update on playstate change, then force repaint.
    -- (Unlike the Panel's ImGui loop, defer() is not tied to REAPER's render cycle,
    -- so SetThemeColor changes need an explicit UpdateTimeline() to appear immediately.)
    if playstate ~= last_play_state then
        if playstate == 0 or playstate == 1 then
            SetThemeColor("ts_lane_bg",     -1)
            SetThemeColor("marker_lane_bg", -1)
            SetThemeColor("region_lane_bg", -1)
        elseif playstate == 6 then
            SetThemeColor("ts_lane_bg",     recpause_color)
            SetThemeColor("marker_lane_bg", recpause_color)
            SetThemeColor("region_lane_bg", recpause_color)
        elseif playstate == 5 then
            SetThemeColor("ts_lane_bg",     rec_color)
            SetThemeColor("marker_lane_bg", rec_color)
            SetThemeColor("region_lane_bg", rec_color)
        end
        UpdateTimeline()
    end

    if playstate == 0 or playstate == 1 then
        -- Maintain wildcard for next recording
        if not iterated_filenames then
            take_text = do_get_take_count(session) + 1
        else
            take_text = take_count + 1
        end
        update_wildcards()

        -- Apply item colors once per recording stop
        if color_run_once then
            color_run_once = false
            check_prefs()
            local next_take = take_text
            take_text = last_recorded_take  -- coloring uses the take that just finished
            apply_rank_and_notes_by_guids()
            take_text = next_take
        end
    elseif playstate == 5 or playstate == 6 then
        -- Ensure take count is scanned
        if not iterated_filenames then do_get_take_count(session) end

        if last_play_state ~= 5 and last_play_state ~= 6 then
            -- Recording just started: lock in this take number
            take_count         = take_count + 1
            take_text          = take_count
            last_recorded_take = take_count
            color_run_once     = true
            SetProjExtState(0, "ReaClassical", "CurrentTakeNumber", tostring(take_text))
        end
    end

    -- Keep the Record Panel's toggle state active so F9 skips the GUI
    if RECORD_PANEL_ID ~= 0 then
        SetToggleCommandState(1, RECORD_PANEL_ID, 1)
    end

    last_play_state = playstate
    SetProjExtState(0, "ReaClassical", "rec_daemon_heartbeat", tostring(os.time()))
    defer(main)
end

---------------------------------------------------------------------
-- Cleanup on stop
---------------------------------------------------------------------

local function at_exit()
    if RECORD_PANEL_ID ~= 0 then SetToggleCommandState(1, RECORD_PANEL_ID, 0) end
    SNM_SetStringConfigVar("recfile_wildcards", prev_recfilename)
    SetThemeColor("ts_lane_bg",     -1)
    SetThemeColor("marker_lane_bg", -1)
    SetThemeColor("region_lane_bg", -1)
end

atexit(at_exit)
defer(main)
