--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2024 chmaha

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

for key in pairs(reaper) do _G[key] = reaper[key] end
local main, markers, select_matching_folder, split_at_dest_in, create_crossfades, clean_up
local lock_items, unlock_items, ripple_lock_mode, create_dest_in, return_xfade_length, xfade
local get_first_last_items, get_color_table, get_path, mark_as_edit
local copy_source
---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local dest_in, source_count = markers()
    ripple_lock_mode()
    if dest_in == 1 and source_count == 2 then
        lock_items()
        local _, is_selected = copy_source()
        if is_selected == false then
            clean_up(is_selected)
            return
        end
        split_at_dest_in()
        local paste = NamedCommandLookup("_SWS_AWPASTE")
        Main_OnCommand(paste, 0)  -- SWS_AWPASTE
        mark_as_edit()
        unlock_items()
        local cur_pos = create_crossfades()
        clean_up(is_selected)
        Main_OnCommand(40289, 0) -- Item: Unselect all items
        Main_OnCommand(40310, 0) -- Toggle ripple editing per-track
        create_dest_in(cur_pos)
    else
        ShowMessageBox(
            "Please add 3 valid source-destination markers: DEST-IN, SOURCE-IN and SOURCE-OUT"
            , "3-Point Insert Edit", 0)
        return
    end

    Undo_EndBlock('VERTICAL One-Window S-D Editing', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function markers()
    local _, num_markers, num_regions = CountProjectMarkers(0)
    local source_count = 0
    local dest_in = 0
    for i = 0, num_markers + num_regions - 1, 1 do
        local _, _, _, _, label, _ = EnumProjectMarkers(i)
        if label == "DEST-IN" then
            dest_in = 1
        elseif label == string.match(label, "%d+:SOURCE[-]IN") or string.match(label, "%d+:SOURCE[-]OUT") then
            source_count = source_count + 1
        end
    end
    return dest_in, source_count
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
    Main_OnCommand(40625, 0) -- Time Selection: Set start point
    GoToMarker(0, 999, false)
    Main_OnCommand(40626, 0) -- Time Selection: Set end point
    local start_time, end_time = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    local sel_length = end_time - start_time
    Main_OnCommand(40718, 0) -- Select all items on selected tracks in current time selection
    if CountSelectedMediaItems(0) == 0 then
        is_selected = false
    end
    Main_OnCommand(40034, 0) -- Item Grouping: Select all items in group(s)
    Main_OnCommand(41383, 0) -- Edit: Copy items/tracks/envelope points (depending on focus) within time selection, if any (smart copy)
    Main_OnCommand(40289, 0) -- Item: Unselect all items
    return sel_length, is_selected
end

---------------------------------------------------------------------

function split_at_dest_in()
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
    local cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    MoveEditCursor(0.001, false)
    local select_under = NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    Main_OnCommand(select_under, 0)
    MoveEditCursor(-0.001, false)
    MoveEditCursor(-xfade_len, false)
    Main_OnCommand(41305, 0) -- Item edit: Trim left edge of item to edit cursor
    MoveEditCursor(xfade_len, false)
    MoveEditCursor(-0.0001, false)
    xfade(xfade_len)
    Main_OnCommand(40912, 0) -- Options: Toggle auto-crossfade on split (OFF)
    return cur_pos
end

---------------------------------------------------------------------

function clean_up(is_selected)
    Main_OnCommand(40020, 0) -- Time Selection: Remove time selection and loop point selection
    if is_selected then
        DeleteProjectMarker(NULL, 996, false)
        DeleteProjectMarker(NULL, 997, false)
        DeleteProjectMarker(NULL, 998, false)
        DeleteProjectMarker(NULL, 999, false)
    else
        ShowMessageBox("Please make sure there is material to copy between your source markers...",
            "Source-Destination Edit", 0)
    end
end

---------------------------------------------------------------------

function lock_items()
    Main_OnCommand(40182, 0)           -- select all items
    Main_OnCommand(40939, 0)           -- select track 01
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- select children of track 1
    local unselect_items = NamedCommandLookup("_SWS_UNSELONTRACKS")
    Main_OnCommand(unselect_items, 0)  -- unselect items in first folder
    local total_items = CountSelectedMediaItems(0)
    for i = 0, total_items - 1, 1 do
        local item = GetSelectedMediaItem(0, i)
        SetMediaItemInfo_Value(item, "C_LOCK", 1)
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

function create_dest_in(cur_pos)
    SetEditCurPos(cur_pos, false, false)
    local colors = get_color_table()
    AddProjectMarker2(0, false, cur_pos, 0, "DEST-IN", 996, colors.dest_marker)
end

---------------------------------------------------------------------

function return_xfade_length()
    local xfade_len = 0.035
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        xfade_len = table[1] / 1000
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
    local num_of_items = CountSelectedMediaItems()
    local first_sel_item = GetSelectedMediaItem(0, 0)
    local last_sel_item = GetSelectedMediaItem(0, num_of_items - 1)
    return first_sel_item, last_sel_item
end

---------------------------------------------------------------------

function get_color_table()
    local resource_path = GetResourcePath()
    local relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical","")
    package.path = package.path .. ";" .. resource_path .. relative_path .. "?.lua;"
    return require("ReaClassical_Colors_Table")
end

---------------------------------------------------------------------

function get_path(...)
    local pathseparator = package.config:sub(1,1);
    local elements = {...}
    return table.concat(elements, pathseparator)
end

---------------------------------------------------------------------

function mark_as_edit()
    local selected_items = CountSelectedMediaItems(0)
    for i = 0, selected_items - 1, 1 do
        local item = GetSelectedMediaItem(0, i)
        GetSetMediaItemInfo_String(item, "P_EXT:SD", "y", 1)
    end
end

---------------------------------------------------------------------

main()

