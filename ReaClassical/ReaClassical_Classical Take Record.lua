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

local main, solo, trackname_check, mixer, track_check
local load_prefs, save_prefs, get_color_table, get_path
local extract_take_number, check_parent_track
local get_selected_media_item_at, count_selected_media_items
local clear_all_rec_armed_except_live, get_item_guid
local select_children_of_selected_folders
local unselect_folder_children, set_rec_arm_for_selected_tracks
---------------------------------------------------------------------

local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
local _, mastering = GetProjExtState(0, "ReaClassical", "MasteringModeSet")
mastering = (mastering ~= "" and tonumber(mastering)) or 0
local ref_is_guide = 0
local use_only_take_num = 0
if input ~= "" then
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    if table[7] then ref_is_guide = tonumber(table[7]) or 0 end
    if table[14] then use_only_take_num = tonumber(table[14]) or 0 end
end

---------------------------------------------------------------------

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end
    if track_check() == 0 then
        MB("Please add at least one folder before running", "Classical Take Record", 0)
        return
    end
    PreventUIRefresh(1)
    local _, rec_wildcards = get_config_var_string("recfile_wildcards")

    local first_selected = GetSelectedTrack(0, 0)
    if not first_selected then return end
    if not check_parent_track(first_selected) then
        local parent_track = GetParentTrack(first_selected)
        if not parent_track then
            MB("Classical Take Record only works with groups", "Error", 0)
            return
        else
            SetOnlyTrackSelected(parent_track)
        end
    end

    Undo_BeginBlock()
    local rec_arm = GetMediaTrackInfo_Value(first_selected, "I_RECARM")

    Main_OnCommand(40339, 0) --unmute all tracks

    if GetPlayState() == 0 then
        local record_panel = NamedCommandLookup("_RSbd41ad183cae7b18bccb86b087f719e945278160")
        local state = GetToggleCommandState(record_panel)
        if state ~= 1 then
            Main_OnCommand(record_panel, 0)
        end
        select_children_of_selected_folders()
        mixer()
        local selected = solo()
        if not selected then
            MB("Please select a folder or track before running", "Classical Take Record", 0)
            return
        end
        clear_all_rec_armed_except_live()
        set_rec_arm_for_selected_tracks(1)
        unselect_folder_children()

        if rec_arm ~= 1 then
            TrackList_AdjustWindows(false)
            return
        end

        local cursor_pos = GetCursorPosition()
        save_prefs(cursor_pos)

        Main_OnCommand(1013, 0) -- Transport: Record
        Undo_EndBlock('Classical Take Record', 0)
    else
        Main_OnCommand(40667, 0) -- Transport: Stop (save all recorded media)
        local _, session_name = GetProjExtState(0, "ReaClassical", "TakeSessionName")
        session_name = (session_name ~= "" and session_name .. "_") or ""
        local take_number = extract_take_number(rec_wildcards)
        if take_number then
            --for each selected item rename take
            local padded_number = string.format("%03d", take_number)
            local take_prefix = (session_name == "") and "" or "T"
            local num_of_selected_items = count_selected_media_items()
            for i = 0, num_of_selected_items - 1 do
                local item = get_selected_media_item_at(i)
                local take = GetActiveTake(item)
                if use_only_take_num == 0 then
                    GetSetMediaItemTakeInfo_String(take, "P_NAME", session_name .. take_prefix .. padded_number, true)
                else
                    GetSetMediaItemTakeInfo_String(take, "P_NAME", padded_number, true)
                end
            end
        end

        --group last recorded items
        Main_OnCommand(40032, 0)
        --save recorded item guid
        local recorded_item = get_selected_media_item_at(0)
        local recorded_item_guid = get_item_guid(recorded_item)
        SetProjExtState(0, "ReaClassical", "LastRecordedItem", recorded_item_guid)
        Main_OnCommand(40289, 0) -- Unselect all items

        if workflow == "Vertical" then
            select_children_of_selected_folders()
            local ret, cursor_pos = load_prefs()
            if ret then
                SetEditCurPos(cursor_pos, true, false)
                SetProjExtState(0, "ReaClassical", "ClassicalTakeRecordCurPos", "")
            end
            set_rec_arm_for_selected_tracks(0)

            local num_tracks = CountTracks(0)
            local selected_track = GetSelectedTrack(0, 0)
            local current_num = GetMediaTrackInfo_Value(selected_track, 'IP_TRACKNUMBER')
            local bool = false
            for i = current_num, num_tracks - 1, 1 do
                local track = GetTrack(0, i)
                if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                    Main_OnCommand(40297, 0) -- deselect all tracks
                    SetTrackSelected(track, true)
                    select_children_of_selected_folders()
                    solo()
                    set_rec_arm_for_selected_tracks(1)
                    mixer()
                    unselect_folder_children()
                    Main_OnCommand(40913, 0) -- adjust scroll to selected tracks
                    bool = true
                    TrackList_AdjustWindows(false)
                    break
                end
            end
            if bool == false then
                local duplicate = NamedCommandLookup("_RS2c6e13d20ab617b8de2c95a625d6df2fde4265ff")
                Main_OnCommand(duplicate, 0)
                select_children_of_selected_folders()
                set_rec_arm_for_selected_tracks(1)
                solo()
                unselect_folder_children()
                Main_OnCommand(40913, 0) -- adjust scroll to selected tracks
            end
        end
        PreventUIRefresh(-1)
        Undo_EndBlock('Classical Take Record Stop', 0)
    end
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function solo()
    local track = GetSelectedTrack(0, 0)
    if not track then
        return false
    end

    for i = 0, CountTracks(0) - 1, 1 do
        track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        if IsTrackSelected(track) == false and mixer_state ~= "y" and aux_state ~= "y" and submix_state ~= "y"
            and rt_state ~= "y" and live_state ~= "y" and rcmaster_state ~= "y" then
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            SetMediaTrackInfo_Value(track, "B_MUTE", 1)
        end
        if live_state == "y" then
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            SetMediaTrackInfo_Value(track, "B_MUTE", 1)
        end
        if ref_state == "y" and ref_is_guide == 1 then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 1)
        end
    end
    return true
end

---------------------------------------------------------------------

function trackname_check(track, string)
    local _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, string)
end

---------------------------------------------------------------------

function mixer()
    local colors = get_color_table()
    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        if mixer_state == "y" then
            SetTrackColor(track, colors.mixer)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if aux_state == "y" then
            SetTrackColor(track, colors.aux)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if submix_state == "y" then
            SetTrackColor(track, colors.submix)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if rt_state == "y" then
            SetTrackColor(track, colors.roomtone)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if live_state == "y" then
            SetTrackColor(track, colors.live)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if ref_state == "y" then
            SetTrackColor(track, colors.ref)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if rcmaster_state == "y" then
            SetTrackColor(track, colors.rcmaster)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if mixer_state == "y" or aux_state == "y" or submix_state == "y" or rcmaster_state == "y"
            or rt_state == "y" or live_state == "y" or ref_state == "y" then
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 1)
        else
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
        end

        local _, source_track = GetSetMediaTrackInfo_String(track, "P_EXT:Source", "", false)
        if trackname_check(track, "^S%d+:") or source_track == "y" then
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", (mastering == 1) and 0 or 1)
        end
        if mixer_state == "y" or aux_state == "y" or submix_state == "y" or rcmaster_state == "y" then
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", (mastering == 1) and 1 or 0)
        end
        if mastering == 1 and i == 0 then
            Main_OnCommand(40727, 0) -- minimize all tracks
            SetTrackSelected(track, 1)
            Main_OnCommand(40723, 0) -- expand and minimize others
            SetTrackSelected(track, 0)
        end
    end
end

---------------------------------------------------------------------

function track_check()
    return CountTracks(0)
end

---------------------------------------------------------------------

function load_prefs()
    return GetProjExtState(0, "ReaClassical", "ClassicalTakeRecordCurPos")
end

---------------------------------------------------------------------

function save_prefs(cursor_position)
    SetProjExtState(0, "ReaClassical", "ClassicalTakeRecordCurPos", cursor_position)
end

-----------------------------------------------------------------------

function get_color_table()
    local resource_path = GetResourcePath()
    local relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical", "")
    package.path = package.path .. ";" .. resource_path .. relative_path .. "?.lua;"
    return require("ReaClassical_Colors_Table")
end

---------------------------------------------------------------------

function get_path(...)
    local pathseparator = package.config:sub(1, 1);
    local elements = { ... }
    return table.concat(elements, pathseparator)
end

---------------------------------------------------------------------

function check_parent_track(track)
    if not track or GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") ~= 1 then
        -- MB("Please select a parent track before running", "Classical Take Record", 0)
        return false
    end
    return true
end

---------------------------------------------------------------------

function extract_take_number(rec_wildcards)
    local number = rec_wildcards:match("T(%d+)$")
    return number and tonumber(number) or nil
end

---------------------------------------------------------------------

function count_selected_media_items()
    local selected_count = 0
    local total_items = CountMediaItems(0)

    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            selected_count = selected_count + 1
        end
    end

    return selected_count
end

---------------------------------------------------------------------

function get_selected_media_item_at(index)
    local selected_count = 0
    local total_items = CountMediaItems(0)

    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            if selected_count == index then
                return item
            end
            selected_count = selected_count + 1
        end
    end

    return nil
end

---------------------------------------------------------------------

function clear_all_rec_armed_except_live()
    local num_tracks = CountTracks(0)
    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        local _, live_flag = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)

        if live_flag ~= "y" then
            -- Disarm track
            SetMediaTrackInfo_Value(track, "I_RECARM", 0)
        else
            -- Optional: ensure LIVE track is armed
            SetMediaTrackInfo_Value(track, "I_RECARM", 1)
        end
    end
end

---------------------------------------------------------------------

function select_children_of_selected_folders()
    local track_count = CountTracks(0)

    for i = 0, track_count - 1 do
        local tr = GetTrack(0, i)
        if IsTrackSelected(tr) then
            local depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
            if depth == 1 then -- folder parent
                local j = i + 1
                while j < track_count do
                    local ch_tr = GetTrack(0, j)
                    SetTrackSelected(ch_tr, true) -- select child track

                    local ch_depth = GetMediaTrackInfo_Value(ch_tr, "I_FOLDERDEPTH")
                    if ch_depth == -1 then
                        break -- end of folder children
                    end

                    j = j + 1
                end
            end
        end
    end
end

---------------------------------------------------------------------

function unselect_folder_children()
    local num_tracks = CountTracks(0)
    local depth = 0
    local unselect_mode = false

    for i = 0, num_tracks - 1 do
        local tr = GetTrack(0, i)
        local folder_change = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        if IsTrackSelected(tr) and folder_change == 1 then
            -- We found a selected folder parent
            unselect_mode = true
        elseif unselect_mode then
            SetTrackSelected(tr, false)
        end

        -- Adjust folder depth
        if folder_change > 0 then
            depth = depth + folder_change
        elseif folder_change < 0 then
            depth = depth + folder_change
            if depth <= 0 then
                unselect_mode = false
                depth = 0
            end
        end
    end
end

---------------------------------------------------------------------

function set_rec_arm_for_selected_tracks(state)
    -- state: 0 = disarm, 1 = arm
    local num_tracks = CountTracks(0)

    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        if IsTrackSelected(track) then
            SetMediaTrackInfo_Value(track, "I_RECARM", state)
        end
    end

    UpdateArrange()
end

---------------------------------------------------------------------

function get_item_guid(item)
    if not item then
        return ""
    end

    -- Get GUID string from the item
    local retval, guid = GetSetMediaItemInfo_String(item, "GUID", "", false)
    if retval then
        return guid
    else
        return ""
    end
end

---------------------------------------------------------------------

main()
