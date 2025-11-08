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

local main, get_grouped_items, copy_shift, empty_items_check
local get_selected_media_item_at, count_selected_media_items
---------------------------------------------------------------------

function main()
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    local first_track = GetTrack(0, 0)
    local num_of_items = 0
    if first_track then num_of_items = CountTrackMediaItems(first_track) end
    if not first_track or num_of_items == 0 then
        MB("Error: No media items found.", "Reposition Album Tracks", 0)
        return
    end
    local empty_count = empty_items_check(first_track, num_of_items)
    if empty_count > 0 then
        MB("Error: Empty items found on first track. Delete them to continue.", "Reposition Tracks", 0)
        return
    end

    local bool, gap = GetUserInputs('Reposition Tracks', 1, "No. of seconds between items?", ',')

    if not bool then
        return
    elseif gap == "" then
        MB("Please enter a number!", "Reposition Album Tracks", 0)
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
            local new_pos
            local grouped_items = get_grouped_items(current_item)
            local epsilon = 1e-7
            if take_name ~= "" and (current_item_start + shift > prev_end - epsilon) then
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
            MB("No item take names found.", "Reposition Album Tracks", 0)
            return
        end
    end
    local create_cd_markers = NamedCommandLookup("_RSa00edf5f46de174e455de2f03cf326ab3db034b9")
    local _, run = GetProjExtState(0, "ReaClassical", "CreateCDMarkersRun?")
    if run == "yes" then Main_OnCommand(create_cd_markers, 0) end
    Undo_EndBlock("Reposition Tracks", 0)
end

---------------------------------------------------------------------

function get_grouped_items(item)
    Main_OnCommand(40289, 0) -- unselect all items
    SetMediaItemSelected(item, true)
    Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

    local selected_item_count = count_selected_media_items()

    local selected_items = {}

    for i = 1, selected_item_count - 1 do
        selected_items[i] = get_selected_media_item_at(i)
    end
    return selected_items
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

function empty_items_check(first_track, num_of_items)
    local count = 0
    for i = 0, num_of_items - 1, 1 do
        local current_item = GetTrackMediaItem(first_track, i)
        local take = GetActiveTake(current_item)
        if not take then
            count = count + 1
        end
    end
    return count
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

main()
