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

local main, markers, add_source_marker
local get_track_length, select_matching_folder, copy_source, split_at_dest_in
local create_crossfades, clean_up, lock_items, unlock_items
local ripple_lock_mode, return_xfade_length, xfade
local get_first_last_items, get_color_table, get_path, mark_as_edit
local move_to_project_tab, find_second_folder_track
local check_overlapping_items, count_selected_media_items, get_selected_media_item_at
local move_destination_folder_to_top, move_destination_folder

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    Main_OnCommand(41121, 0) -- Options: Disable trim content behind media items when editing
    local group_state = GetToggleCommandState(1156)
    if group_state ~= 1 then
        Main_OnCommand(1156, 0) -- Enable item grouping
    end

    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    local moveable_dest = 0
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[12] then moveable_dest = tonumber(table[12]) or 0 end
    end

    if moveable_dest == 1 then move_destination_folder_to_top() end

    local proj_marker_count, source_proj, dest_proj, dest_in, dest_out, dest_count, source_in,
    source_out, source_count, pos_table, track_number = markers()

    if proj_marker_count == 1 then
        MB("Only one S-D project marker was found."
            .. "\nUse zero for regular single project S-D editing"
            .. "\nor use two for multi-tab S-D editing.", "Source-Destination Edit", 0)
        if moveable_dest == 1 then move_destination_folder(track_number) end
        return
    end

    if proj_marker_count == -1 or proj_marker_count == 1 then
        MB(
            "Source or destination markers should be paired with " ..
            "the corresponding source or destination project marker.",
            "Multi-tab Source-Destination Edit", 0)
        if moveable_dest == 1 then move_destination_folder(track_number) end
        return
    end

    ripple_lock_mode()
    local colors = get_color_table()
    if dest_count + source_count == 3 and pos_table ~= nil then -- add one extra marker for 3-point editing
        local distance
        local pos
        if dest_in == 0 then
            pos = pos_table[2]
            distance = pos_table[4] - pos_table[3]
            move_to_project_tab(dest_proj)
            AddProjectMarker2(0, false, pos - distance, 0, "DEST-IN", 996, colors.dest_marker)
        elseif dest_out == 0 then
            pos = pos_table[1]
            distance = pos_table[4] - pos_table[3]
            move_to_project_tab(dest_proj)
            AddProjectMarker2(0, false, pos + distance, 0, "DEST-OUT", 997, colors.dest_marker)
        elseif source_in == 0 then
            pos = pos_table[4]
            distance = pos_table[1] - pos_table[2]
            move_to_project_tab(source_proj)
            add_source_marker(pos, distance, track_number, "SOURCE-IN", 998)
        elseif source_out == 0 then
            pos = pos_table[3]
            distance = pos_table[2] - pos_table[1]
            move_to_project_tab(source_proj)
            add_source_marker(pos, distance, track_number, "SOURCE-OUT", 999)
        end
    elseif dest_count == 1 and source_count == 1 then -- add two extra markers 2-point editing
        if dest_in == 1 and source_in == 1 then
            move_to_project_tab(dest_proj)
            local source_end
            if proj_marker_count == 2 then
                source_end = GetProjectLength(0)
            else
                source_end = get_track_length(track_number)
            end
            move_to_project_tab(source_proj)
            add_source_marker(source_end, 0, track_number, "SOURCE-OUT", 999)
            local dest_end = GetProjectLength(0)
            move_to_project_tab(dest_proj)
            AddProjectMarker2(0, false, dest_end, 0, "DEST-OUT", 997, colors.dest_marker)
        elseif dest_out == 1 and source_out == 1 then
            move_to_project_tab(source_proj)
            add_source_marker(0, 0, track_number, "SOURCE-IN", 998)
            move_to_project_tab(dest_proj)
            AddProjectMarker2(0, false, 0, 0, "DEST-IN", 996, colors.dest_marker)
        elseif source_in == 1 and dest_out == 1 then
            move_to_project_tab(dest_proj)
            local source_end
            if proj_marker_count == 2 then
                source_end = GetProjectLength(0)
            else
                source_end = get_track_length(track_number)
            end
            move_to_project_tab(source_proj)
            add_source_marker(source_end, 0, track_number, "SOURCE-OUT", 999)
            move_to_project_tab(dest_proj)
            AddProjectMarker2(0, false, 0, 0, "DEST-IN", 996, colors.dest_marker)
        elseif source_out == 1 and dest_in == 1 then
            move_to_project_tab(source_proj)
            add_source_marker(0, 0, track_number, "SOURCE-IN", 998)
            local dest_end = GetProjectLength(0)
            move_to_project_tab(dest_proj)
            AddProjectMarker2(0, false, dest_end, 0, "DEST-OUT", 997, colors.dest_marker)
        end
    elseif source_count == 2 and dest_count == 0 and pos_table ~= nil and proj_marker_count == 0 then
        AddProjectMarker2(0, false, pos_table[3], 0, "DEST-IN", 996, colors.dest_marker)
        AddProjectMarker2(0, false, pos_table[4], 0, "DEST-OUT", 997, colors.dest_marker)
    end

    local _, _, _, _, _, new_dest_count, _, _, new_source_count, _, _ = markers()
    if new_dest_count + new_source_count == 4 then -- final check we actually have 4 S-D markers
        move_to_project_tab(dest_proj)
        lock_items()
        move_to_project_tab(source_proj)
        local _, is_selected = copy_source()
        if is_selected == false then
            clean_up(is_selected, proj_marker_count, source_count, source_in, source_out)
            return
        end
        Main_OnCommand(40020, 0) -- remove time selection
        move_to_project_tab(dest_proj)
        split_at_dest_in()
        Main_OnCommand(40625, 0) -- Time Selection: Set start point
        GoToMarker(0, 997, false)
        Main_OnCommand(40289, 0)
        Main_OnCommand(40626, 0) -- Time Selection: Set end point
        Main_OnCommand(40718, 0) -- Select all items on selected tracks in current time selection
        Main_OnCommand(40034, 0) -- Item Grouping: Select all items in group(s)
        Main_OnCommand(40630, 0) -- Go to start of time selection

        if workflow == "Horizontal" then
            Main_OnCommand(40311, 0) -- Set ripple-all-tracks
        else
            Main_OnCommand(40310, 0) -- Set ripple-per-track
        end

        local delete = NamedCommandLookup("_XENAKIOS_TSADEL")
        Main_OnCommand(delete, 0) -- Adaptive Delete
        local paste = NamedCommandLookup("_SWS_AWPASTE")
        Main_OnCommand(paste, 0)  -- SWS_AWPASTE
        mark_as_edit()
        unlock_items()
        create_crossfades()

        if moveable_dest == 1 then move_destination_folder(track_number) end

        clean_up(is_selected, proj_marker_count, source_count, source_in, source_out)
        Main_OnCommand(40289, 0) -- Item: Unselect all items
        Main_OnCommand(40310, 0) -- Toggle ripple editing per-track
    else
        MB(
            "Please add at least 2 valid source-destination markers: \n" ..
            "2-point edit: Either 1 DEST and 1 SOURCE marker (any combination) " ..
            "or both SOURCE markers (when not in multi-tab mode)\n" ..
            "3-point edit: Any combination of 3 markers \n 4-point edit: DEST-IN, DEST-OUT, SOURCE-IN and SOURCE-OUT"
            , "Source-Destination Edit", 0)
        if moveable_dest == 1 then move_destination_folder(track_number) end
        return
    end

    Undo_EndBlock('S-D Edit', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function markers()
    local marker_labels = { "DEST-IN", "DEST-OUT", "SOURCE-IN", "SOURCE-OUT" }
    local sd_markers = {}
    for _, label in ipairs(marker_labels) do
        sd_markers[label] = { count = 0, proj = nil }
    end

    local num = 0
    local source_proj, dest_proj
    local proj_marker_count = 0
    local pos_table = {}
    local active_proj = EnumProjects(-1)
    local track_number = 1
    while true do
        local proj = EnumProjects(num)
        if proj == nil then
            break
        end
        local _, num_markers, num_regions = CountProjectMarkers(proj)
        for i = 0, num_markers + num_regions - 1, 1 do
            local _, _, pos, _, raw_label, _ = EnumProjectMarkers2(proj, i)
            local number = string.match(raw_label, "(%d+):.+")
            local label = string.match(raw_label, "%d*:?(.+)") or ""

            if label == "DEST-IN" then
                sd_markers[label].count = 1
                sd_markers[label].proj = proj
                pos_table[1] = pos
            elseif label == "DEST-OUT" then
                sd_markers[label].count = 1
                sd_markers[label].proj = proj
                pos_table[2] = pos
            elseif label == "SOURCE-IN" then
                track_number = number
                sd_markers[label].count = 1
                sd_markers[label].proj = proj
                pos_table[3] = pos
            elseif label == "SOURCE-OUT" then
                track_number = number
                sd_markers[label].count = 1
                sd_markers[label].proj = proj
                pos_table[4] = pos
            elseif string.match(label, "SOURCE PROJECT") then
                source_proj = proj
                proj_marker_count = proj_marker_count + 1
            elseif string.match(label, "DEST PROJECT") then
                dest_proj = proj
                proj_marker_count = proj_marker_count + 1
            end
        end
        num = num + 1
    end

    if proj_marker_count == 0 then
        for _, marker in pairs(sd_markers) do
            if marker.proj ~= active_proj then
                marker.count = 0
            end
        end
    end

    local source_in = sd_markers["SOURCE-IN"].count
    local source_out = sd_markers["SOURCE-OUT"].count
    local dest_in = sd_markers["DEST-IN"].count
    local dest_out = sd_markers["DEST-OUT"].count

    local sin = sd_markers["SOURCE-IN"].proj
    local sout = sd_markers["SOURCE-OUT"].proj
    local din = sd_markers["DEST-IN"].proj
    local dout = sd_markers["DEST-OUT"].proj


    local source_count = source_in + source_out
    local dest_count = dest_in + dest_out

    if (source_count == 2 and sin ~= sout) or (dest_count == 2 and din ~= dout) then proj_marker_count = -1 end

    if source_proj and ((sin and sin ~= source_proj) or (sout and sout ~= source_proj)) then
        proj_marker_count = -1
    end
    if dest_proj and ((din and din ~= dest_proj) or (dout and dout ~= dest_proj)) then
        proj_marker_count = -1
    end

    return proj_marker_count, source_proj, dest_proj, dest_in, dest_out, dest_count,
        source_in, source_out, source_count, pos_table, track_number
end

---------------------------------------------------------------------

function add_source_marker(pos, distance, track_number, label, num)
    local colors = get_color_table()
    DeleteProjectMarker(NULL, num, false)
    AddProjectMarker2(0, false, pos + distance, 0, track_number .. ":" .. label, num, colors.source_marker)
end

---------------------------------------------------------------------

function get_track_length(track_number)
    local track = GetTrack(0, track_number)
    local num_of_items = GetTrackNumMediaItems(track)
    local item = GetTrackMediaItem(track, num_of_items - 1)
    local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local item_length = GetMediaItemInfo_Value(item, "D_LENGTH")
    local end_of_track = item_pos + item_length
    return end_of_track
end

---------------------------------------------------------------------

function select_matching_folder()
    local cursor = GetCursorPosition()
    local marker_id, _ = GetLastMarkerAndCurRegion(0, cursor)
    local _, _, _, _, label, _, _ = EnumProjectMarkers3(0, marker_id)
    local folder_number = tonumber(string.match(label, "(%d*):SOURCE*"))
    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") == folder_number then
            SetOnlyTrackSelected(track)
            break
        end
    end
end

---------------------------------------------------------------------

function copy_source()
    local is_selected = true
    local focus = NamedCommandLookup("_BR_FOCUS_ARRANGE_WND")
    Main_OnCommand(focus, 0) -- BR_FOCUS_ARRANGE_WND
    Main_OnCommand(40311, 0) -- Set ripple-all-tracks
    Main_OnCommand(40289, 0) -- Item: Unselect all items
    GoToMarker(0, 998, false)
    select_matching_folder()
    local left_overlap = check_overlapping_items()
    Main_OnCommand(40625, 0) -- Time Selection: Set start point
    GoToMarker(0, 999, false)
    local right_overlap = check_overlapping_items()
    Main_OnCommand(40626, 0) -- Time Selection: Set end point
    local start_time, end_time = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    local sel_length = end_time - start_time
    Main_OnCommand(40718, 0) -- Select all items on selected tracks in current time selection
    local selected_items = count_selected_media_items()
    if left_overlap then
        local first_item = get_selected_media_item_at(0)
        SetMediaItemSelected(first_item, false)
        selected_items = selected_items - 1
    end
    if right_overlap then
        local last_item = get_selected_media_item_at(selected_items - 1)
        SetMediaItemSelected(last_item, false)
        selected_items = selected_items - 1
    end
    if selected_items == 0 then
        is_selected = false
    end
    Main_OnCommand(40034, 0) -- Item Grouping: Select all items in group(s)
    Main_OnCommand(41383, 0) -- Edit: Copy items/tracks/envelope points (depending on focus) within time selection
    Main_OnCommand(40289, 0) -- Item: Unselect all items
    return sel_length, is_selected
end

---------------------------------------------------------------------

function split_at_dest_in()
    Main_OnCommand(40769, 0) -- unselect all items/tracks etc
    Main_OnCommand(40927, 0) -- Options: Enable auto-crossfade on split
    Main_OnCommand(40939, 0) -- Track: Select track 01
    GoToMarker(0, 996, false)
    local select_under = NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    Main_OnCommand(select_under, 0) -- Xenakios/SWS: Select items under edit cursor on selected tracks
    Main_OnCommand(40034, 0)        -- Item grouping: Select all items in groups
    local selected_items = CountSelectedMediaItems(0)
    Main_OnCommand(40912, 0)        -- Options: Toggle auto-crossfade on split (OFF)
    if selected_items > 0 then
        Main_OnCommand(40186, 0)    -- Item: Split items at edit or play cursor (ignoring grouping)
    end
    Main_OnCommand(40289, 0)        -- Item: Unselect all items
end

---------------------------------------------------------------------

function create_crossfades()
    local first_sel_item, last_sel_item = get_first_last_items()
    Main_OnCommand(40289, 0) -- Item: Unselect all items
    SetMediaItemSelected(first_sel_item, true)
    Main_OnCommand(41173, 0) -- Item navigation: Move cursor to start of items
    Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups
    local xfade_len = return_xfade_length()
    MoveEditCursor(-xfade_len, false)
    Main_OnCommand(41305, 0) -- Item edit: Trim left edge of item to edit cursor
    MoveEditCursor(xfade_len, false)
    MoveEditCursor(-0.0001, false)
    xfade(xfade_len)
    Main_OnCommand(40289, 0) -- Item: Unselect all items
    SetMediaItemSelected(last_sel_item, true)
    Main_OnCommand(41174, 0) -- Item navigation: Move cursor to end of items
    Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups
    Main_OnCommand(41311, 0) -- Item edit: Trim right edge of item to edit cursor
    MoveEditCursor(0.001, false)
    local select_under = NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    Main_OnCommand(select_under, 0)
    if CountSelectedMediaItems(0) == 0 then return end
    MoveEditCursor(-0.001, false)
    MoveEditCursor(-xfade_len, false)
    Main_OnCommand(41305, 0) -- Item edit: Trim left edge of item to edit cursor
    MoveEditCursor(xfade_len, false)
    MoveEditCursor(-0.0001, false)
    xfade(xfade_len)
    Main_OnCommand(40912, 0) -- Options: Toggle auto-crossfade on split (OFF)
end

---------------------------------------------------------------------

function clean_up(is_selected, proj_marker_count, source_count, source_in, source_out)
    Main_OnCommand(40020, 0) -- Time Selection: Remove time selection and loop point selection
    if is_selected then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then
                break
            end
            if proj_marker_count ~= 2 then
                DeleteProjectMarker(project, 996, false)
                DeleteProjectMarker(project, 997, false)
                DeleteProjectMarker(project, 998, false)
                DeleteProjectMarker(project, 999, false)
            else
                if source_count == 1 then
                    if source_in == 0 then
                        DeleteProjectMarker(project, 998, false) -- Delete SOURCE-IN marker
                    elseif source_out == 0 then
                        DeleteProjectMarker(project, 999, false) -- Delete SOURCE-OUT marker
                    end
                end
                DeleteProjectMarker(project, 996, false) -- Delete DEST-IN marker
                DeleteProjectMarker(project, 997, false) -- Delete DEST-OUT marker
            end

            i = i + 1
        end
    else
        unlock_items()
        MB("Please make sure there is material to copy between your source markers...",
            "Source-Destination Edit", 0)
    end
end

---------------------------------------------------------------------

function lock_items()
    local second_folder_track = find_second_folder_track()

    if second_folder_track == nil then
        return
    end

    local total_tracks = CountTracks(0)

    for track_idx = second_folder_track, total_tracks - 1 do
        local track = GetTrack(0, track_idx)

        local num_items = CountTrackMediaItems(track)

        for item_idx = 0, num_items - 1 do
            local item = GetTrackMediaItem(track, item_idx)
            SetMediaItemInfo_Value(item, "C_LOCK", 1)
        end
    end
end

---------------------------------------------------------------------

function unlock_items()
    local total_items = CountMediaItems(0)
    for i = 0, total_items - 1, 1 do
        local item = GetMediaItem(0, i)
        SetMediaItemInfo_Value(item, "C_LOCK", 0)
    end
end

---------------------------------------------------------------------

function ripple_lock_mode()
    local _, original_ripple_lock_mode = get_config_var_string("ripplelockmode")
    original_ripple_lock_mode = tonumber(original_ripple_lock_mode)
    if original_ripple_lock_mode ~= 2 then
        SNM_SetIntConfigVar("ripplelockmode", 2)
    end
end

---------------------------------------------------------------------

function return_xfade_length()
    local xfade_len = 0.035
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[1] then xfade_len = table[1] / 1000 end
    end
    return xfade_len
end

---------------------------------------------------------------------

function xfade(xfade_len)
    local select_items = NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    Main_OnCommand(select_items, 0) -- Xenakios/SWS: Select items under edit cursor on selected tracks
    MoveEditCursor(-xfade_len, false)
    Main_OnCommand(40625, 0)        -- Time selection: Set start point
    MoveEditCursor(xfade_len, false)
    Main_OnCommand(40626, 0)        -- Time selection: Set end point
    Main_OnCommand(40916, 0)        -- Item: Crossfade items within time selection
    Main_OnCommand(40635, 0)        -- Time selection: Remove time selection
    MoveEditCursor(0.001, false)
    Main_OnCommand(select_items, 0)
    MoveEditCursor(-0.001, false)
end

---------------------------------------------------------------------

function get_first_last_items()
    local num_of_items = CountSelectedMediaItems(0)
    local first_sel_item
    local last_sel_item

    for i = 0, num_of_items - 1 do
        local item = GetSelectedMediaItem(0, i)
        local track = GetMediaItem_Track(item)
        local track_num = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")

        if track_num == 1 then
            if not first_sel_item then
                first_sel_item = item
            end
            last_sel_item = item
        end
    end

    return first_sel_item, last_sel_item
end

---------------------------------------------------------------------

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

function mark_as_edit()
    local selected_items = CountSelectedMediaItems(0)
    for i = 0, selected_items - 1, 1 do
        local item = GetSelectedMediaItem(0, i)
        GetSetMediaItemInfo_String(item, "P_EXT:SD", "y", true)
    end
end

---------------------------------------------------------------------

function move_to_project_tab(proj_type)
    SelectProjectInstance(proj_type)
end

---------------------------------------------------------------------

function find_second_folder_track()
    local total_tracks = CountTracks(0)
    local folder_count = 0

    for track_idx = 0, total_tracks - 1 do
        local track = GetTrack(0, track_idx)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        if folder_depth == 1 then
            folder_count = folder_count + 1

            if folder_count == 2 then
                return track_idx
            end
        end
    end

    return nil
end

---------------------------------------------------------------------

function check_overlapping_items()
    local track = GetSelectedTrack(0, 0)
    if not track then
        ShowMessageBox("No track selected!", "Error", 0)
        return
    end

    local cursor_pos = GetCursorPosition()
    local num_items = CountTrackMediaItems(track)
    local overlapping = false

    for i = 0, num_items - 1 do
        local item1 = GetTrackMediaItem(track, i)
        local start1 = GetMediaItemInfo_Value(item1, "D_POSITION")
        local length1 = GetMediaItemInfo_Value(item1, "D_LENGTH")
        local end1 = start1 + length1

        if cursor_pos >= start1 and cursor_pos <= end1 then
            for j = i + 1, num_items - 1 do
                local item2 = GetTrackMediaItem(track, j)
                local start2 = GetMediaItemInfo_Value(item2, "D_POSITION")

                if start2 < end1 and cursor_pos >= start2 then
                    overlapping = true
                    break
                end
            end
        end
        if overlapping then break end
    end

    return overlapping
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

function move_destination_folder_to_top()
    local destination_folder = nil
    local track_count = CountTracks(0)

    -- Find the first folder with a parent that has the "Destination" extstate set to "y"
    for i = 0, track_count - 1 do
        local track = GetTrack(0, i)
        if track then
            local _, track_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            if track_name:find("^D:") and GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                destination_folder = track
                break
            end
        end
    end

    if not destination_folder then return end -- No matching folder found

    -- Move the folder to the top
    local destination_index = GetMediaTrackInfo_Value(destination_folder, "IP_TRACKNUMBER") - 1
    if destination_index > 0 then
        SetOnlyTrackSelected(destination_folder)
        ReorderSelectedTracks(0, 0)
    end
end

---------------------------------------------------------------------

function move_destination_folder(track_number)
    local destination_folder = nil
    local track_count = CountTracks(0)

    for i = 0, track_count - 1 do
        local track = GetTrack(0, i)
        if track then
            local _, track_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            if track_name:find("^D:") and GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                destination_folder = track
                break
            end
        end
    end

    if not destination_folder then return end

    local target_track = GetTrack(0, track_number - 1)
    if not target_track then return end

    local destination_index = GetMediaTrackInfo_Value(destination_folder, "IP_TRACKNUMBER") - 1
    local target_index = track_number - 1

    if destination_index ~= target_index then
        SetOnlyTrackSelected(destination_folder)
        ReorderSelectedTracks(target_index, 0)
    end
end

---------------------------------------------------------------------

main()
