--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2023 chmaha

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

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local replace_toggle = NamedCommandLookup("_RSfb9968dc637180b9e9d1627a5be31048ae2034e9")
    ripple_lock_mode()
    if SDmarkers() == 4 then
        lock_items()
        local first_track_items = copy_source()
        split_at_dest_in()
        Main_OnCommand(40625, 0)  -- Time Selection: Set start point
        GoToMarker(0, 997, false)
        Main_OnCommand(40626, 0)  -- Time Selection: Set end point
        Main_OnCommand(40718, 0)  -- Select all items on selected tracks in current time selection
        Main_OnCommand(40034, 0)  -- Item Grouping: Select all items in group(s)
        Main_OnCommand(40630, 0)  -- Go to start of time selection
        Main_OnCommand(40309, 0)  -- ripple off
        local delete = NamedCommandLookup("_XENAKIOS_TSADEL")
        Main_OnCommand(delete, 0) -- Adaptive Delete
        Main_OnCommand(40289, 0)  -- Item: Unselect all items

        local state = GetToggleCommandState(1156)
        if state == 1 then
            Main_OnCommand(1156, 0) -- Options: Toggle item grouping and track media/razor edit grouping
        end
        Main_OnCommand(42398, 0)    -- Item: Paste items/tracks
        local xfade_len = return_xfade_length()
        GoToMarker(0, 996, false)
        MoveEditCursor(-xfade_len, false) -- move cursor back xfade length
        Main_OnCommand(40625, 0)          -- Time Selection: Set start point
        local selected_items = {}
        local num_of_items = CountSelectedMediaItems()
        for i = 0, num_of_items - 1, 1 do
            selected_items[i] = GetSelectedMediaItem(0, i)
        end
        Main_OnCommand(40289, 0) -- Item: Unselect all items
        local first_item = selected_items[0]

        local item_color = GetMediaItemInfo_Value(first_item, "I_CUSTOMCOLOR")


        SetMediaItemSelected(first_item, true)
        Main_OnCommand(40034, 0)         -- Item grouping: Select all items in groups
        Main_OnCommand(41305, 0)         -- Item edit: Trim left edge of item to edit cursor
        Main_OnCommand(40289, 0)         -- Item: Unselect all items
        MoveEditCursor(xfade_len, false) -- move cursor forward xfade length
        for _, v in pairs(selected_items) do
            SetMediaItemSelected(v, true)
            SetMediaItemInfo_Value(v, "C_LOCK", 0)
        end
        if first_track_items == 1 then
            Main_OnCommand(41206, 0) -- Item: Move and stretch items to fit time selection
        else
            Main_OnCommand(40362, 0) -- glue items
        end
        Main_OnCommand(41206, 0)     -- Item: Move and stretch items to fit time selection
        
        local num_of_items = CountSelectedMediaItems()
        for i = 0, num_of_items -1, 1 do
            local item = GetSelectedMediaItem(0, i)
            SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", item_color)
        end
        
        state = GetToggleCommandState(1156)
        if state == 0 then
            Main_OnCommand(1156, 0) -- Options: Toggle item grouping and track media/razor edit grouping
        end
        unlock_items()
        Main_OnCommand(40626, 0) -- Time Selection: Set end point
        local cur_pos = create_crossfades()
        clean_up()
        Main_OnCommand(40289, 0) -- Item: Unselect all items
        Main_OnCommand(40310, 0) -- Toggle ripple editing per-track
    else
        ShowMessageBox("Please add 4 markers: DEST-IN, DEST-OUT, SOURCE-IN and SOURCE-OUT", "Insert with timestretching",
            0)
    end

    Undo_EndBlock('Insert with timestretching', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function markers()
    local retval, num_markers, num_regions = CountProjectMarkers(0)
    local source_count = 0
    local dest_in = 0
    local dest_out = 0
    for i = 0, num_markers + num_regions - 1, 1 do
        local retval, isrgn, pos, rgnend, label, markrgnindexnumber = EnumProjectMarkers(i)
        if label == "DEST-IN" then
            dest_in = 1
        elseif label == "DEST-OUT" then
            dest_out = 1
        elseif label == string.match(label, "%d+:SOURCE[-]IN") or string.match(label, "%d+:SOURCE[-]OUT") then
            source_count = source_count + 1
        end
    end
    return dest_in, dest_out, source_count
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
    local first_track_items = CountSelectedMediaItems()
    Main_OnCommand(40034, 0) -- Item Grouping: Select all items in group(s)
    Main_OnCommand(41383, 0) -- Edit: Copy items/tracks/envelope points (depending on focus) within time selection, if any (smart copy)
    Main_OnCommand(40289, 0) -- Item: Unselect all items
    return first_track_items
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
    MoveEditCursor(xfade_len, false)
    MoveEditCursor(-0.0001, false)
    xfade(xfade_len)
    Main_OnCommand(40289, 0) -- Item: Unselect all items
    SetMediaItemSelected(last_sel_item, true)
    Main_OnCommand(41174, 0) -- Item navigation: Move cursor to end of items
    --Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups
    Main_OnCommand(40289, 0) -- Item: Unselect all items
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
    Main_OnCommand(40020, 0) -- Time Selection: Remove time selection and loop point selection
    return cur_pos
end

---------------------------------------------------------------------

function clean_up()
    DeleteProjectMarker(NULL, 996, false)
    DeleteProjectMarker(NULL, 997, false)
    DeleteProjectMarker(NULL, 998, false)
    DeleteProjectMarker(NULL, 999, false)
    --Main_OnCommand(42395, 0) -- Clear tempo envelope
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
    first_sel_item = GetSelectedMediaItem(0, 0)
    last_sel_item = GetSelectedMediaItem(0, num_of_items - 1)
    return first_sel_item, last_sel_item
end

---------------------------------------------------------------------

function SDmarkers()
    local retval, num_markers, num_regions = CountProjectMarkers(0)
    local exists = 0
    for i = 0, num_markers + num_regions - 1, 1 do
        local retval, isrgn, pos, rgnend, label, markrgnindexnumber = EnumProjectMarkers(i)
        if label == "DEST-IN" or label == "DEST-OUT" or string.match(label, "%d+:SOURCE[-]IN") or string.match(label, "%d+:SOURCE[-]OUT")
        then
            exists = exists + 1
        end
    end
    return exists
end

---------------------------------------------------------------------

main()
