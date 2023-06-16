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
    Undo_BeginBlock()
    local first_track = GetTrack(0, 0)
    if first_track then NUM_OF_ITEMS = CountTrackMediaItems(first_track) end
    if not first_track or NUM_OF_ITEMS == 0 then
        ShowMessageBox("Error: No media items found.", "Reposition Album Tracks", 0)
        return
    end
    local empty_count = empty_items_check(first_track)
    if empty_count > 0 then
        ShowMessageBox("Error: Empty items found on first track. Delete them to continue.", "Reposition Tracks", 0)
        return
    end

    local bool, gap = GetUserInputs('Reposition Tracks', 1, "No. of seconds between items?", ',')

    if not bool then
        return
    elseif gap == "" then
        ShowMessageBox("Please enter a number!", "Reposition Album Tracks", 0)
        return
    else
        local track = GetTrack(0, 0)
        local track_items = {}
        local item_count = CountTrackMediaItems(track)
        for i = 0, item_count - 1 do
            track_items[i] = GetTrackMediaItem(track, i)
        end
        local shift = 0;
        local num_tracks = 0
        for i = 1, item_count - 1, 1 do
            local prev_item = track_items[i - 1]
            local prev_item_start = GetMediaItemInfo_Value(prev_item, "D_POSITION")
            local prev_length = GetMediaItemInfo_Value(prev_item, "D_LENGTH")
            local prev_end = prev_item_start + prev_length
            local current_item = track_items[i]
            local current_item_start = GetMediaItemInfo_Value(current_item, "D_POSITION")
            local take = GetActiveTake(current_item)
            local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            local new_pos = 0
            local grouped_items = get_grouped_items(current_item)
            if take_name ~= "" and (current_item_start + shift > prev_end) then
                new_pos = prev_end + gap
                SetMediaItemInfo_Value(current_item, "D_POSITION", new_pos)
                num_tracks = num_tracks + 1
            else
                new_pos = current_item_start + shift
                SetMediaItemInfo_Value(current_item, "D_POSITION", new_pos)
            end
            shift = new_pos - current_item_start
            copy_shift(grouped_items, shift)
        end
        if num_tracks == 0 then
            ShowMessageBox("No item take names found.", "Reposition Album Tracks", 0)
            return
        end
    end
    local create_cd_markers = NamedCommandLookup("_RSa00edf5f46de174e455de2f03cf326ab3db034b9")
    local _, run = GetProjExtState(0, "Create CD Markers", "Run?")
    if run == "yes" then Main_OnCommand(create_cd_markers, 0) end
    Undo_EndBlock("Reposition Tracks", 0)
end

---------------------------------------------------------------------

function get_grouped_items(item)
    Main_OnCommand(40289, 0) -- unselect all items
    SetMediaItemSelected(item, true)
    Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

    Selected_item_count = CountSelectedMediaItems(0)

    Selected_items = {}

    for i = 1, Selected_item_count - 1 do
        Selected_items[i] = GetSelectedMediaItem(0, i)
    end
    return Selected_items
end

---------------------------------------------------------------------

function copy_shift(grouped_items, shift)
    for _, v in pairs(grouped_items) do
        local start = GetMediaItemInfo_Value(v, "D_POSITION")
        SetMediaItemInfo_Value(v, "D_POSITION", start + shift)
    end
    Main_OnCommand(40289, 0) -- unselect all items
end

---------------------------------------------------------------------

function empty_items_check(first_track)
    local count = 0
    for i = 0, NUM_OF_ITEMS - 1, 1 do
        local current_item = GetTrackMediaItem(first_track, i)
        local take = GetActiveTake(current_item)
        if not take then
            count = count + 1
        end
    end
    return count
end

---------------------------------------------------------------------

main()
