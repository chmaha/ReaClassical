--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2025 chmaha

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

local main, save_marker_data, load_marker_data, clean_up_orphans
local init_marker_data, get_sai, find_sao, monitor_playback
local move_to_marker, set_track_selected, play_from_marker
local convert_at_marker, solo, delete_all_sai_sao_markers

---------------------------------------------------------------------

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

package.path       = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui        = require 'imgui' '0.10'

local ctx          = ImGui.CreateContext('Source Audition Marker Manag')
local visible      = true
local window_flags = ImGui.WindowFlags_None

set_action_options(2)

-- Rank color options (slightly desaturated for better readability)
local COLORS            = {
    { name = "Excellent",     rgba = 0x39FF1499 }, -- Bright lime green
    { name = "Very Good",     rgba = 0x32CD3299 }, -- Lime green
    { name = "Good",          rgba = 0x00AD8399 }, -- Teal green
    { name = "OK",            rgba = 0xFFFFAA99 }, -- Soft yellow
    { name = "Below Average", rgba = 0xFFBF0099 }, -- Gold/amber
    { name = "Poor",          rgba = 0xFF753899 }, -- Orange
    { name = "Unusable",      rgba = 0xDC143C99 }, -- Crimson red
    { name = "No Rank",       rgba = 0x00000000 }  -- Transparent for default table color
}

-- Storage for marker data
local marker_data       = {}
local playback_monitor  = false
local current_sao_pos   = nil
local last_play_pos     = -1
local sort_mode         = "time" -- "time", "marker", or "rank"

-- ExtState keys for persistent storage
local EXT_STATE_SECTION = "ReaClassical_SAI_Manager"

---------------------------------------------------------------------

function main()
    if not ImGui.ValidatePtr(ctx, 'ImGui_Context*') then
        return
    end

    -- Monitor playback for auto-stop at SAO markers
    monitor_playback()
    ImGui.SetNextWindowSize(ctx, 750, 300, ImGui.Cond_FirstUseEver)
    visible, open = ImGui.Begin(ctx, 'Source Audition Manager', true, window_flags)

    if visible then
        -- Global stop button at the top
        if ImGui.Button(ctx, '■ Stop', 80, 0) then
            OnStopButton()
            playback_monitor = false
            current_sao_pos = nil
        end

        -- Delete all markers and exit button
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, 'Delete All Audition Pairs and Exit', 200, 0) then
            delete_all_sai_sao_markers()
            local razor_enabled = GetToggleCommandState(42618) == 1
            if razor_enabled then Main_OnCommand(42618, 0) end
            visible = false
        end

        ImGui.Separator(ctx)

        local markers = get_sai()

        if #markers == 0 then
            ImGui.Text(ctx, "No SAI markers found in project...")
        else
            -- Create table
            if ImGui.BeginTable(ctx, 'MarkerTable', 7, ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg) then
                -- Setup columns
                ImGui.TableSetupColumn(ctx, 'Audition',
                    ImGui.TableColumnFlags_WidthFixed | ImGui.TableColumnFlags_NoHeaderLabel, 60)
                ImGui.TableSetupColumn(ctx, 'Marker',
                    ImGui.TableColumnFlags_WidthFixed | ImGui.TableColumnFlags_NoHeaderLabel, 60)
                ImGui.TableSetupColumn(ctx, 'Time',
                    ImGui.TableColumnFlags_WidthFixed | ImGui.TableColumnFlags_NoHeaderLabel, 60)
                ImGui.TableSetupColumn(ctx, 'Rank',
                    ImGui.TableColumnFlags_WidthFixed | ImGui.TableColumnFlags_NoHeaderLabel, 120)
                ImGui.TableSetupColumn(ctx, 'Notes', ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableSetupColumn(ctx, 'Convert',
                    ImGui.TableColumnFlags_WidthFixed | ImGui.TableColumnFlags_NoHeaderLabel, 60)
                ImGui.TableSetupColumn(ctx, 'Delete',
                    ImGui.TableColumnFlags_WidthFixed | ImGui.TableColumnFlags_NoHeaderLabel, 50)
                ImGui.TableHeadersRow(ctx)

                -- Manually draw centered header for Audition
                ImGui.TableSetColumnIndex(ctx, 0)
                local avail = ImGui.GetContentRegionAvail(ctx)
                local text = "Audition"
                local text_width = ImGui.CalcTextSize(ctx, text)
                ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail - text_width) * 0.5)
                ImGui.Text(ctx, text)

                -- Clickable Marker header to sort by marker number
                ImGui.TableSetColumnIndex(ctx, 1)
                local marker_header = "Marker" .. (sort_mode == "marker" and " ▼" or "")
                if ImGui.Selectable(ctx, marker_header .. "##marker_sort", false) then
                    sort_mode = "marker"
                    save_marker_data() -- Save sort mode change
                end

                -- Clickable Time header to sort by timeline
                ImGui.TableSetColumnIndex(ctx, 2)
                local time_header = "Time" .. (sort_mode == "time" and " ▼" or "")
                if ImGui.Selectable(ctx, time_header .. "##time_sort", false) then
                    sort_mode = "time"
                    save_marker_data() -- Save sort mode change
                end

                -- Clickable Rank header to sort by rank
                ImGui.TableSetColumnIndex(ctx, 3)
                local rank_header = "Rank" .. (sort_mode == "rank" and " ▼" or "")
                if ImGui.Selectable(ctx, rank_header .. "##rank_sort", false) then
                    sort_mode = "rank"
                    save_marker_data() -- Save sort mode change
                end

                -- Manually draw centered header for Convert
                ImGui.TableSetColumnIndex(ctx, 5)
                avail = ImGui.GetContentRegionAvail(ctx)
                text = "Convert"
                text_width = ImGui.CalcTextSize(ctx, text)
                ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail - text_width) * 0.5)
                ImGui.Text(ctx, text)

                -- Manually draw centered header for Delete
                ImGui.TableSetColumnIndex(ctx, 6)
                avail = ImGui.GetContentRegionAvail(ctx)
                text = "Delete"
                text_width = ImGui.CalcTextSize(ctx, text)
                ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail - text_width) * 0.5)
                ImGui.Text(ctx, text)

                -- Display markers
                for i, marker in ipairs(markers) do
                    ImGui.TableNextRow(ctx)

                    -- Get marker data
                    local mdata = marker_data[marker.marker_num]
                    if not mdata then
                        mdata = { notes = "", color_idx = 8 }
                        marker_data[marker.marker_num] = mdata
                    end

                    -- Apply row background color if not default
                    if mdata.color_idx ~= 8 then
                        local color = COLORS[mdata.color_idx].rgba
                        ImGui.TableSetBgColor(ctx, ImGui.TableBgTarget_RowBg0, color)
                    end

                    -- Column 1: Play button
                    ImGui.TableNextColumn(ctx)
                    local avail_width = ImGui.GetContentRegionAvail(ctx)
                    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail_width - 30) * 0.5)
                    if ImGui.Button(ctx, '▶##play' .. marker.marker_num, 30, 0) then
                        play_from_marker(marker.pos, marker.name)
                    end

                    -- Column 2: Marker name (clickable)
                    ImGui.TableNextColumn(ctx)
                    if ImGui.Selectable(ctx, marker.name .. '##sel' .. marker.marker_num, false) then
                        move_to_marker(marker.pos)
                    end

                    -- Column 3: Time
                    ImGui.TableNextColumn(ctx)
                    ImGui.Text(ctx, marker.time_str)

                    -- Column 4: Rank picker
                    ImGui.TableNextColumn(ctx)
                    ImGui.SetNextItemWidth(ctx, -1)
                    if ImGui.BeginCombo(ctx, '##rank' .. marker.marker_num, COLORS[mdata.color_idx].name) then
                        for j, col in ipairs(COLORS) do
                            local is_selected = (mdata.color_idx == j)
                            if ImGui.Selectable(ctx, col.name, is_selected) then
                                mdata.color_idx = j
                                save_marker_data() -- Save when rank changes
                            end
                            if is_selected then
                                ImGui.SetItemDefaultFocus(ctx)
                            end
                        end
                        ImGui.EndCombo(ctx)
                    end

                    -- Column 5: Notes input
                    ImGui.TableNextColumn(ctx)
                    ImGui.SetNextItemWidth(ctx, -1)
                    local rv_notes, new_notes = ImGui.InputText(ctx, '##notes' .. marker.marker_num, mdata.notes)
                    if rv_notes then
                        mdata.notes = new_notes
                        save_marker_data() -- Save when notes change
                    end

                    -- Column 6: Convert button
                    ImGui.TableNextColumn(ctx)
                    local avail_width = ImGui.GetContentRegionAvail(ctx)
                    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail_width - 40) * 0.5)
                    if ImGui.Button(ctx, '⚡##convert' .. marker.marker_num, 40, 0) then
                        convert_at_marker(marker.pos, marker.name)
                    end

                    -- Column 7: Delete button
                    ImGui.TableNextColumn(ctx)
                    local avail_width = ImGui.GetContentRegionAvail(ctx)
                    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail_width - 30) * 0.5)
                    if ImGui.Button(ctx, '✕##delete' .. marker.marker_num, 30, 0) then
                        -- Delete this marker and its corresponding SAO marker
                        Undo_BeginBlock()

                        -- First, find the next SAI marker on the same track to establish upper bound
                        local next_sai_pos = nil
                        local sai_pattern = "^" .. marker.track_num .. ":SAI"
                        local num_markers = CountProjectMarkers(0)

                        for j = 0, num_markers - 1 do
                            local ok, isrgn, pos, rgnend, name, _ = EnumProjectMarkers2(0, j)
                            if ok and not isrgn and pos > marker.pos and name and name:match(sai_pattern) then
                                next_sai_pos = pos
                                break
                            end
                        end

                        -- Now find the SAO marker AFTER this SAI but BEFORE the next SAI (if any)
                        local sao_pattern = "^" .. marker.track_num .. ":SAO"
                        local sao_idx = nil

                        for j = 0, num_markers - 1 do
                            local ok, isrgn, pos, rgnend, name, _ = EnumProjectMarkers2(0, j)
                            if ok and not isrgn and pos > marker.pos and name and name:match(sao_pattern) then
                                -- Check if this SAO is before the next SAI (or there is no next SAI)
                                if not next_sai_pos or pos < next_sai_pos then
                                    sao_idx = j
                                    break
                                end
                            end
                        end

                        -- Delete SAO first if found (so SAI index stays valid)
                        if sao_idx then
                            DeleteProjectMarkerByIndex(0, sao_idx)
                        end

                        -- Now delete the SAI marker
                        DeleteProjectMarkerByIndex(0, marker.idx)

                        -- Remove from marker_data
                        marker_data[marker.marker_num] = nil

                        Undo_EndBlock("Delete SAI/SAO marker pair", -1)
                        UpdateArrange()
                    end
                end

                ImGui.EndTable(ctx)
            end
        end

        ImGui.End(ctx)
    end

    if open and visible then
        defer(main)
    else
        -- Window is closing, run cleanup before exit
        clean_up_orphans()
    end
end

---------------------------------------------------------------------

function delete_all_sai_sao_markers()
    Undo_BeginBlock()

    local i = 0
    while true do
        local project, _ = EnumProjects(i)
        if not project then break end
        local _, num_markers, num_regions = CountProjectMarkers(project)
        local total = num_markers + num_regions
        -- Loop backwards so indices remain valid when deleting
        for j = total - 1, 0, -1 do
            local ok, isrgn, _, _, name, _ = EnumProjectMarkers2(project, j)
            if ok and not isrgn and name then
                if name:match("^%d+:SAI") or name:match("^%d+:SAO") then
                    DeleteProjectMarkerByIndex(project, j)
                end
            end
        end
        i = i + 1
    end

    -- Clear marker data since all markers are deleted
    marker_data = {}

    Undo_EndBlock("Delete all SAI/SAO markers", -1)
    UpdateArrange()
end

---------------------------------------------------------------------

function save_marker_data()
    -- Save sort mode
    SetExtState(EXT_STATE_SECTION, "sort_mode", sort_mode, true)

    -- Save each marker's data using its GUID stored in P_EXT
    local num_markers = CountProjectMarkers(0)
    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers3(0, i)

        if not isrgn and name:match("^%d+:SAI") then
            -- Get the marker's GUID
            local ok, guid = GetSetProjectInfo_String(0, "MARKER_GUID:" .. tostring(i), "", false)

            if ok and guid ~= "" and marker_data[markrgnindexnumber] then
                local data = marker_data[markrgnindexnumber]
                -- Store data in the marker's P_EXT
                SetProjExtState(0, "sai_marker", guid .. "_NOTES", data.notes or "")
                SetProjExtState(0, "sai_marker", guid .. "_COLOR", tostring(data.color_idx or 8))
            end
        end
    end

    -- Mark project as dirty so changes get saved
    MarkProjectDirty(0)
end

---------------------------------------------------------------------

function load_marker_data()
    -- Load sort mode
    if HasExtState(EXT_STATE_SECTION, "sort_mode") then
        sort_mode = GetExtState(EXT_STATE_SECTION, "sort_mode")
    end

    -- We'll load marker-specific data as we encounter markers in init_marker_data
end

---------------------------------------------------------------------

function clean_up_orphans()
    -- Collect all current SAI marker GUIDs
    local current_guids = {}
    local num_markers = CountProjectMarkers(0)
    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers3(0, i)

        if not isrgn and name:match("^%d+:SAI") then
            local ok, guid = GetSetProjectInfo_String(0, "MARKER_GUID:" .. tostring(i), "", false)
            if ok and guid ~= "" then
                current_guids[guid] = true
            end
        end
    end

    -- Collect ALL keys first (don't delete while enumerating)
    local all_keys = {}
    local i = 0
    while true do
        local ok, key, value = EnumProjExtState(0, "sai_marker", i)
        if not ok then break end
        table.insert(all_keys, key)
        i = i + 1
    end

    -- Now check which ones to delete
    local deleted_count = 0
    for _, key in ipairs(all_keys) do
        -- Extract GUID from key
        local guid = key:match("^({.+})_NOTES$") or key:match("^({.+})_COLOR$")
        if guid and not current_guids[guid] then
            -- Delete by setting to empty AND using DeleteExtState
            SetProjExtState(0, "sai_marker", key, "")
            deleted_count = deleted_count + 1
        end
    end

    if deleted_count > 0 then
        MarkProjectDirty(0)
    end
end

---------------------------------------------------------------------

function init_marker_data()
    marker_data = {}
    local num_markers = CountProjectMarkers(0)

    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers3(0, i)

        if not isrgn then -- Only process markers, not regions
            -- Check if marker name matches pattern: number(s):SAI
            if name:match("^%d+:SAI") then
                -- Get the marker's GUID
                local ok, guid = GetSetProjectInfo_String(0, "MARKER_GUID:" .. tostring(i), "", false)

                local saved_notes = ""
                local saved_color = 8

                if ok and guid ~= "" then
                    -- Try to load saved data from P_EXT using GUID
                    local has_notes, notes = GetProjExtState(0, "sai_marker", guid .. "_NOTES")
                    local has_color, color = GetProjExtState(0, "sai_marker", guid .. "_COLOR")

                    if has_notes == 1 then
                        saved_notes = notes
                    end
                    if has_color == 1 then
                        saved_color = tonumber(color) or 8
                    end
                end

                marker_data[markrgnindexnumber] = {
                    notes = saved_notes,
                    color_idx = saved_color
                }
            end
        end
    end
end

---------------------------------------------------------------------

function get_sai()
    local markers = {}
    local num_markers = CountProjectMarkers(0)

    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers3(0, i)

        if not isrgn then -- Only process markers, not regions
            -- Check if marker name matches pattern: number(s):SAI
            if name:match("^%d+:SAI") then
                local track_num = tonumber(name:match("^(%d+):SAI"))

                -- Get or initialize marker data
                if not marker_data[markrgnindexnumber] then
                    marker_data[markrgnindexnumber] = {
                        notes = "",
                        color_idx = 8 -- Default color (No Rank)
                    }
                end

                table.insert(markers, {
                    idx = i,
                    marker_num = markrgnindexnumber,
                    pos = pos,
                    name = name,
                    track_num = track_num,
                    time_str = format_timestr(pos, ""),
                    color_idx = marker_data[markrgnindexnumber].color_idx
                })
            end
        end
    end

    -- Sort based on current sort mode
    if sort_mode == "time" then
        table.sort(markers, function(a, b) return a.pos < b.pos end)
    elseif sort_mode == "marker" then
        table.sort(markers, function(a, b) return a.track_num < b.track_num end)
    elseif sort_mode == "rank" then
        -- Rank order: Excellent (1) -> Very Good (2) -> Good (3) -> OK (4) -> Below Average (5) -> Poor (6) -> Unusable (7) -> No Rank (8)
        table.sort(markers, function(a, b)
            if a.color_idx == b.color_idx then
                return a.pos < b.pos                  -- Secondary sort by time
            end
            if a.color_idx == 8 then return false end -- No Rank goes last
            if b.color_idx == 8 then return true end
            return a.color_idx < b.color_idx          -- Lower number = better rank
        end)
    end

    return markers
end

---------------------------------------------------------------------

function find_sao(track_num, sai_pos)
    local num_markers = CountProjectMarkers(0)
    local sao_pattern = "^" .. track_num .. ":SAO"

    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers3(0, i)

        -- Only look for SAO markers that come AFTER the SAI marker
        if not isrgn and pos > sai_pos and name:match(sao_pattern) then
            return pos
        end
    end

    return nil
end

---------------------------------------------------------------------

function monitor_playback()
    if not playback_monitor then
        return
    end

    local play_state = GetPlayState()

    -- If playing and we have a target SAO position
    if play_state & 1 == 1 and current_sao_pos then
        local play_pos = GetPlayPosition()

        -- Check if we've reached or passed the SAO marker
        if play_pos >= current_sao_pos and last_play_pos < current_sao_pos then
            OnStopButton()
            playback_monitor = false
            current_sao_pos = nil
        end

        last_play_pos = play_pos
    else
        -- Playback stopped, reset monitoring
        if play_state & 1 == 0 then
            playback_monitor = false
            current_sao_pos = nil
        end
    end
end

---------------------------------------------------------------------

function move_to_marker(pos)
    SetEditCurPos(pos, true, true) -- move view and seek play
end

---------------------------------------------------------------------

function set_track_selected(marker_name)
    local track_num = tonumber(marker_name:match("^(%d+):SAI"))

    if track_num then
        -- Unselect all tracks first
        for i = 0, CountTracks(0) - 1 do
            local tr = GetTrack(0, i)
            SetTrackSelected(tr, false)
        end

        -- Select the parent track (track_num - 1 because tracks are 0-indexed)
        local track = GetTrack(0, track_num - 1)
        if track then
            SetTrackSelected(track, true)
            solo()
        end
        return track_num
    end
end

---------------------------------------------------------------------

function play_from_marker(pos, marker_name)
    local track_num = set_track_selected(marker_name)
    if track_num then
        -- Find the corresponding SAO marker AFTER this SAI position
        current_sao_pos = find_sao(track_num, pos)
        if current_sao_pos then
            playback_monitor = true
            last_play_pos = pos - 1 -- Set to before start position
        end
    end

    -- Move to position and play
    SetEditCurPos(pos, true, true)
    OnPlayButton()
end

---------------------------------------------------------------------

function convert_at_marker(pos, marker_name)
    SetEditCurPos(pos, true, true)
    Main_OnCommand(NamedCommandLookup("_RSfc71f5ffae31df8f6cf62977dc9fbdab58256522"), 0)
    set_track_selected(marker_name)
    -- Close the window
    -- visible = false
end

---------------------------------------------------------------------

function solo()
    Main_OnCommand(40491, 0) -- un-arm all tracks for recording
    local selected_track = GetSelectedTrack(0, 0)
    local parent = GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH")

    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        if mixer_state == "y" or aux_state == "y" or submix_state == "y" or rt_state == "y" or ref_state == "y" then
            local num_of_sends = GetTrackNumSends(track, 0)
            for j = 0, num_of_sends - 1, 1 do
                SetTrackSendInfo_Value(track, 0, j, "B_MUTE", 0)
            end
        end

        if not (mixer_state == "y" or aux_state == "y" or submix_state == "y" or rt_state == "y"
                or ref_state == "y" or rcmaster_state == "y") then
            if IsTrackSelected(track) and parent ~= 1 then
                SetMediaTrackInfo_Value(track, "I_SOLO", 2)
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) then
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) == false and GetParentTrack(track) ~= selected_track then
                SetMediaTrackInfo_Value(track, "B_MUTE", 1)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            else
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        if rt_state == "y" then
            if IsTrackSelected(track) then
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        if live_state == "y" then
            if IsTrackSelected(track) then
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        if ref_state == "y" then
            local is_selected = IsTrackSelected(track)
            local mute_state = 1
            local solo_state = 0

            if is_selected then
                Main_OnCommand(40340, 0) -- unsolo all tracks
                mute_state = 0
                solo_state = 1
            elseif ref_is_guide == 1 then
                mute_state = 0
                solo_state = 0
            end

            SetMediaTrackInfo_Value(track, "B_MUTE", mute_state)
            SetMediaTrackInfo_Value(track, "I_SOLO", solo_state)
        end

        if rcmaster_state == "y" then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end
    end
end

---------------------------------------------------------------------

-- Initialize and start
load_marker_data() -- Load saved data first
clean_up_orphans() -- Clean up any orphaned entries
init_marker_data()
defer(main)
