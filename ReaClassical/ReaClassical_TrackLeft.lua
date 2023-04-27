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
local r = reaper
local takename_check, check_position, get_track_info, select_CD_track_items, calc_postgap, select_and_cut, paste, go_to_previous, shift, get_grouped_items
---------------------------------------------------------------------------------------
function Main()
    r.Undo_BeginBlock()

    local ret, selected_item = takename_check()
    if ret then
        r.ShowMessageBox('Please select an item that starts a CD track', "Select CD track start", 0)
        return
    end

    local ret, item_number = check_position(selected_item)
    if ret then
        r.ShowMessageBox('The selected track is already in first position', "Select CD track start", 0)
        return
    end

    local first_track, num_of_items = get_track_info()

    local count = select_CD_track_items(item_number, num_of_items, first_track)

    local new_track_item, postgap = calc_postgap(count, num_of_items, first_track, selected_item)

    -- shift all future tracks back length of selected track postgap
    if item_number ~= num_of_items - 1 then
        shift(first_track, new_track_item, postgap, 0, "left")
    end

    select_and_cut()

    go_to_previous(item_number, first_track)

    paste()

    selected_item = r.GetSelectedMediaItem(0,0)

    -- shift forward all future tracks the length of track postgap
    shift(first_track, selected_item, postgap, count, "right")

    r.Main_OnCommand(40769,0) -- unselect all
    r.SetMediaItemSelected(selected_item, true)

    r.Undo_EndBlock("Move Track Left", -1)
end

---------------------------------------------------------------------------------------
function takename_check()
    local item = r.GetSelectedMediaItem(0, 0)
    local take = r.GetActiveTake(item)
    local _, take_name = r.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    return take_name == "", item
end

---------------------------------------------------------------------------------------
function check_position(item)
    local item_number = r.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
    return item_number == 0, item_number
end

---------------------------------------------------------------------------------------
function get_track_info()
    local first_track = r.GetTrack(0, 0)
    return first_track, r.GetTrackNumMediaItems(first_track)
end

---------------------------------------------------------------------------------------
function paste()
    r.Main_OnCommand(42398, 0)
end

---------------------------------------------------------------------------------------
function select_and_cut()
    r.Main_OnCommand(40034, 0) -- select all items in groups
    r.Main_OnCommand(40699, 0) -- paste items
end

---------------------------------------------------------------------------------------
function go_to_previous(item_number, track)
    for i = item_number - 1, 0, -1 do
        local prev_item = r.GetTrackMediaItem(track, i)
        local take = r.GetActiveTake(prev_item)
        local _, take_name = r.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        if take_name ~= "" then
            local prev_item_pos = r.GetMediaItemInfo_Value(prev_item, "D_POSITION")
            r.SetEditCurPos(prev_item_pos, false, false)
            break
        end
    end
end

---------------------------------------------------------------------------------------
function shift(track, item, shift_amount, items_in_track, direction)
    local num_of_items = r.GetTrackNumMediaItems(track)
    local item_number = r.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
    local items_to_move = {}
    if direction == "right" then
        item_number = item_number + items_in_track + 1
        shift_amount = -shift_amount
    end
    for i = item_number, num_of_items - 1, 1 do
        items_to_move[#items_to_move + 1] = r.GetTrackMediaItem(track, i)
    end
    for _, v in pairs(items_to_move) do
        local later_item_pos = r.GetMediaItemInfo_Value(v, "D_POSITION")
        r.SetMediaItemInfo_Value(v, "D_POSITION", later_item_pos - shift_amount)
    end
end

---------------------------------------------------------------------------------------
function select_CD_track_items(item_number, num_of_items, track)
    local count = 0
    local added_item
    if item_number ~= num_of_items - 1 then
        for i = item_number + 1, num_of_items - 1, 1 do
            added_item = r.GetTrackMediaItem(track, i)
            local take = r.GetActiveTake(added_item)
            local _, take_name = r.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            if take_name == "" then
                r.SetMediaItemSelected(added_item, true)
                count = count + 1
            else
                break
            end
        end
    end
    return count
end

---------------------------------------------------------------------------------------
function calc_postgap(count, num_of_items, track, selected_item)
    local last_item_of_track = r.GetSelectedMediaItem(0, 0 + count)
    local last_item_of_track_pos = r.GetMediaItemInfo_Value(last_item_of_track, "D_POSITION")
    local last_item_of_track_length = r.GetMediaItemInfo_Value(last_item_of_track, "D_LENGTH")
    local last_item_of_track_end = last_item_of_track_pos + last_item_of_track_length

    local _, last_item_number = check_position(last_item_of_track)
    local postgap
    local new_track_item
    if last_item_number ~= num_of_items - 1 then
        new_track_item = r.GetTrackMediaItem(track, last_item_number + 1)
        local new_track_pos = r.GetMediaItemInfo_Value(new_track_item, "D_POSITION")
        postgap = new_track_pos - last_item_of_track_end
    else
        new_track_item = selected_item
        postgap = 4
    end
    return new_track_item, postgap
end

---------------------------------------------------------------------------------------
function get_grouped_items(item)
    r.Main_OnCommand(40289,0) -- unselect all items
    r.SetMediaItemSelected(item, true)
    r.Main_OnCommand(40034,0) -- Item grouping: Select all items in groups
    
    Selected_item_count = r.CountSelectedMediaItems(0)
    
    Selected_items = {}
    
    for i=1,Selected_item_count - 1 do
      Selected_items[i] = r.GetSelectedMediaItem(0, i)
    end
    return Selected_items
   end
---------------------------------------------------------------------------------------
Main()
