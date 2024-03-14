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

local main, markers, add_source_marker
local GetTrackLength, select_matching_folder, copy_source, split_at_dest_in
local create_crossfades, clean_up, lock_items, unlock_items
local ripple_lock_mode, return_xfade_length, xfade
local get_first_last_items, get_color_table, get_path, mark_as_edit

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local dest_in, dest_out, dest_count, source_in, source_out, source_count, pos_table, track_number = markers()
    ripple_lock_mode()
    local colors = get_color_table()
    if dest_count + source_count == 3 and pos_table ~= nil then -- add one extra marker for 3-point editing
        local distance
        local pos
        if dest_in == 0 then
          pos = pos_table[2]
          distance = pos_table[4]- pos_table[3]
          AddProjectMarker2(0, false, pos - distance, 0, "DEST-IN", 996, colors.dest_marker)
        elseif dest_out == 0 then
          pos = pos_table[1]
          distance = pos_table[4]- pos_table[3]
          AddProjectMarker2(0, false,  pos + distance, 0, "DEST-OUT", 997, colors.dest_marker)
        elseif source_in == 0 then
          pos = pos_table[4]
          distance = pos_table[1]- pos_table[2]
          add_source_marker(pos, distance, track_number, "SOURCE-IN", 998)
        elseif source_out == 0 then
          pos = pos_table[3]
          distance = pos_table[2]- pos_table[1]
          add_source_marker(pos, distance, track_number, "SOURCE-OUT", 999)
        end
    elseif dest_count == 1 and source_count == 1 then -- add two extra markers 2-point editing
        if dest_in == 1 and source_in == 1 then
          local source_end = GetTrackLength(track_number)
          add_source_marker(source_end, 0, track_number, "SOURCE-OUT", 999)
          local dest_end = GetProjectLength(0)
          AddProjectMarker2(0, false,  dest_end, 0, "DEST-OUT", 997, colors.dest_marker)
        elseif dest_out == 1 and source_out == 1 then
          add_source_marker(0, 0, track_number, "SOURCE-IN", 998)
          AddProjectMarker2(0, false, 0, 0, "DEST-IN", 996, colors.dest_marker)
        elseif source_in == 1 and dest_out == 1 then
          local source_end = GetTrackLength(track_number)
          add_source_marker(source_end, 0, track_number, "SOURCE-OUT", 999)
          AddProjectMarker2(0, false, 0, 0, "DEST-IN", 996, colors.dest_marker)
        elseif source_out == 1 and dest_in == 1 then
          add_source_marker(0, 0, track_number, "SOURCE-IN", 998)
          local dest_end = GetProjectLength(0)
          AddProjectMarker2(0, false,  dest_end, 0, "DEST-OUT", 997, colors.dest_marker)
        end
    elseif source_count == 2 and dest_count == 0 and pos_table ~= nil then
        AddProjectMarker2(0, false, pos_table[3], 0, "DEST-IN", 996, colors.dest_marker)
        AddProjectMarker2(0, false,  pos_table[4], 0, "DEST-OUT", 997, colors.dest_marker)
    end
    
    local _, _, dest_count, _, _, source_count, _ = markers() 
    if dest_count + source_count == 4 then -- final check we actually have 4 S-D markers
        lock_items()
        local _, is_selected = copy_source()
        if is_selected == false then
            clean_up(is_selected)
            return
        end
        split_at_dest_in()
        Main_OnCommand(40625, 0)  -- Time Selection: Set start point
        GoToMarker(0, 997, false)
        Main_OnCommand(40289,0)
        Main_OnCommand(40626, 0)  -- Time Selection: Set end point
        Main_OnCommand(40718, 0)  -- Select all items on selected tracks in current time selection
        Main_OnCommand(40034, 0)  -- Item Grouping: Select all items in group(s)
        Main_OnCommand(40630, 0)  -- Go to start of time selection
   
        local delete = NamedCommandLookup("_XENAKIOS_TSADEL")
        Main_OnCommand(delete, 0) -- Adaptive Delete
        local paste = NamedCommandLookup("_SWS_AWPASTE")
        Main_OnCommand(paste, 0)  -- SWS_AWPASTE
        mark_as_edit()
        unlock_items()
        create_crossfades()
        clean_up(is_selected)
        Main_OnCommand(40289, 0) -- Item: Unselect all items
        Main_OnCommand(40310, 0) -- Toggle ripple editing per-track
    else
        ShowMessageBox(
            "Please add at least 2 valid source-destination markers: \n 2-point edit: Either 1 DEST and 1 SOURCE marker (any combination) or both SOURCE markers\n 3-point edit: Any combination of 3 markers \n 4-point edit: DEST-IN, DEST-OUT, SOURCE-IN and SOURCE-OUT"
            , "Source-Destination Edit", 0)
        return
    end

    Undo_EndBlock('S-D Edit', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function markers()
    local _, num_markers, num_regions = CountProjectMarkers(0)
    local dest_in, dest_out, source_in, source_out = 0, 0, 0, 0
    local pos_table = {}
    local track_number = 1
    for i = 0, num_markers + num_regions - 1, 1 do
        local _, _, pos, _, label, _ = EnumProjectMarkers(i)
        if label == "DEST-IN" then
            dest_in = 1
            pos_table[1] = pos
        elseif label == "DEST-OUT" then
            dest_out = 1
            pos_table[2] = pos
        elseif string.match(label, "%d+:SOURCE[-]IN") then
            track_number = string.match(label, "(%d+):.+")
            source_in = 1
            pos_table[3] = pos
        elseif string.match(label, "%d+:SOURCE[-]OUT") then
            track_number = string.match(label, "(%d+):.+")
            source_out = 1
            pos_table[4] = pos
        end
    end
    local source_count = source_in + source_out
    local dest_count = dest_in + dest_out
    return dest_in, dest_out, dest_count, source_in, source_out, source_count, pos_table, track_number
end

---------------------------------------------------------------------

function add_source_marker(pos, distance, track_number, label, num)
    local colors = get_color_table()
    DeleteProjectMarker(NULL, num, false)
    AddProjectMarker2(0, false,  pos + distance, 0, track_number .. ":" .. label, num, colors.source_marker)
end

---------------------------------------------------------------------

function GetTrackLength(track_number)
  local track = GetTrack(0, track_number)
  local numitems = reaper.GetTrackNumMediaItems(track)
  local item = reaper.GetTrackMediaItem(track,numitems-1)
  local item_pos = reaper.GetMediaItemInfo_Value(item,"D_POSITION")
  local item_length = reaper.GetMediaItemInfo_Value(item,"D_LENGTH")
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
    MoveEditCursor(0.001, false)
    local select_under = NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    Main_OnCommand(select_under, 0)
    if reaper.CountSelectedMediaItems(0) == 0 then return end
    MoveEditCursor(-0.001, false)
    MoveEditCursor(-xfade_len, false)
    Main_OnCommand(41305, 0) -- Item edit: Trim left edge of item to edit cursor
    MoveEditCursor(xfade_len, false)
    MoveEditCursor(-0.0001, false)
    xfade(xfade_len)
    Main_OnCommand(40912, 0) -- Options: Toggle auto-crossfade on split (OFF)
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
    local number_of_items = CountSelectedMediaItems(0)
    Main_OnCommand(select_items, 0) -- Xenakios/SWS: Select items under edit cursor on selected tracks
    local number_of_items = CountSelectedMediaItems(0)
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
    first_sel_item = GetSelectedMediaItem(0, 0)
    last_sel_item = GetSelectedMediaItem(0, num_of_items - 1)
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
